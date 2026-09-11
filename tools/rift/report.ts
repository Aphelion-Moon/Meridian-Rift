import fs from 'node:fs/promises';
import path from 'node:path';
import type { ProcessResult } from './process';

export const RIFT_SCHEMA_VERSION = 1 as const;

export type RiftStatus =
  | 'passed'
  | 'failed'
  | 'timed_out'
  | 'cancelled'
  | 'ready_then_stopped';

export type EvidenceClass =
  | 'inspection'
  | 'compiler'
  | 'full_build'
  | 'boot'
  | 'focused_test'
  | 'full_test'
  | 'soak';

export type RiftFailure = {
  code: string;
  stage: string;
  message: string;
};

export type RiftEvent = {
  schema_version: typeof RIFT_SCHEMA_VERSION;
  run_id: string;
  sequence: number;
  timestamp: string;
  kind:
    | 'run_started'
    | 'stage_started'
    | 'process_started'
    | 'process_output'
    | 'observation'
    | 'artifact'
    | 'stage_finished'
    | 'failure'
    | 'run_finished';
  stage: string;
  status?: RiftStatus;
  data: Record<string, unknown>;
};

export type RiftSummary = {
  schema_version: typeof RIFT_SCHEMA_VERSION;
  run_id: string;
  command: string;
  profile: string;
  status: RiftStatus;
  evidence: EvidenceClass;
  exit_code: number;
  started_at: string;
  finished_at: string;
  duration_ms: number;
  repository: { revision: string; dirty: boolean };
  tool_versions: Record<string, string>;
  network_mode: 'offline' | 'allow';
  phases: Array<Record<string, unknown>>;
  processes: Array<Record<string, unknown>>;
  tests: {
    recorded: number;
    passed: number;
    failed: number;
    skipped: number;
  } | null;
  runtime_signatures: Array<{
    signature: string;
    count: number;
    first_seen: string;
  }>;
  resource_maxima: Array<Record<string, unknown>>;
  artifacts: Array<Record<string, unknown>>;
  cleanup: { passed: boolean; leftovers: string[]; retained: string[] };
  failures: RiftFailure[];
};

export type RunRecorderOptions = {
  runDir: string;
  runId: string;
  command: string;
  profile: string;
  evidence: EvidenceClass;
  networkMode: 'offline' | 'allow';
};

export type ArtifactRecord = {
  path: string;
  size: number;
  sha256: string;
  stage: string;
  freshness: 'new' | 'rebuilt' | 'reused' | 'collected';
  modified_at?: string;
};

const pathEscapes = (relativePath: string) =>
  relativePath === '..' ||
  relativePath.startsWith(`..${path.sep}`) ||
  path.isAbsolute(relativePath);

const redactUserPaths = (value: string) =>
  value
    .replaceAll(/([A-Za-z]:\\Users\\)[^\\\r\n]+/g, '$1<profile>')
    .replaceAll(/(\/Users\/)[^/\r\n]+/g, '$1<profile>');

const redactStructuredValue = (value: unknown): unknown => {
  if (typeof value === 'string') {
    return redactUserPaths(value);
  }
  if (Array.isArray(value)) {
    return value.map(redactStructuredValue);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [
        key,
        redactStructuredValue(entry),
      ]),
    );
  }
  return value;
};

const redactRecord = (value: Record<string, unknown>) =>
  redactStructuredValue(value) as Record<string, unknown>;

export class RunRecorder {
  readonly stdoutPath: string;
  readonly stderrPath: string;
  readonly #eventsPath: string;
  readonly #summaryPath: string;
  readonly #startedAtMs: number;
  #sequence = 0;
  #writes: Promise<void> = Promise.resolve();
  #summary: RiftSummary;
  #finished: RiftSummary | null = null;
  #finishing = false;
  #finishPromise: Promise<RiftSummary> | null = null;

  private constructor(
    readonly runDir: string,
    options: RunRecorderOptions,
  ) {
    this.stdoutPath = path.join(runDir, 'stdout.log');
    this.stderrPath = path.join(runDir, 'stderr.log');
    this.#eventsPath = path.join(runDir, 'events.ndjson');
    this.#summaryPath = path.join(runDir, 'summary.json');
    this.#startedAtMs = Date.now();
    const startedAt = new Date(this.#startedAtMs).toISOString();
    this.#summary = {
      schema_version: RIFT_SCHEMA_VERSION,
      run_id: options.runId,
      command: options.command,
      profile: options.profile,
      status: 'failed',
      evidence: options.evidence,
      exit_code: 3,
      started_at: startedAt,
      finished_at: startedAt,
      duration_ms: 0,
      repository: { revision: 'unknown', dirty: false },
      tool_versions: {},
      network_mode: options.networkMode,
      phases: [],
      processes: [],
      tests: null,
      runtime_signatures: [],
      resource_maxima: [],
      artifacts: [],
      cleanup: { passed: true, leftovers: [], retained: [] },
      failures: [],
    };
  }

  static async create(options: RunRecorderOptions): Promise<RunRecorder> {
    await fs.mkdir(options.runDir, { recursive: true });
    const recorder = new RunRecorder(options.runDir, options);
    await Promise.all([
      fs.writeFile(recorder.#eventsPath, ''),
      fs.writeFile(recorder.stdoutPath, ''),
      fs.writeFile(recorder.stderrPath, ''),
    ]);
    await recorder.emit('run_started', 'run', {
      command: options.command,
      profile: options.profile,
      evidence: options.evidence,
      network_mode: options.networkMode,
    });
    return recorder;
  }

  #queue(action: () => Promise<void>): Promise<void> {
    const queued = this.#writes.then(action);
    this.#writes = queued.catch(() => undefined);
    return queued;
  }

  #assertOpen() {
    if (this.#finishing || this.#finished) {
      throw new Error('run recorder is finished');
    }
  }

  #appendEvent(
    kind: RiftEvent['kind'],
    stage: string,
    data: Record<string, unknown>,
    status?: RiftStatus,
  ) {
    this.#sequence += 1;
    const event: RiftEvent = {
      schema_version: RIFT_SCHEMA_VERSION,
      run_id: this.#summary.run_id,
      sequence: this.#sequence,
      timestamp: new Date().toISOString(),
      kind,
      stage,
      data: redactRecord(data),
      ...(status ? { status } : {}),
    };
    return fs.appendFile(
      this.#eventsPath,
      `${JSON.stringify(event)}\n`,
      'utf8',
    );
  }

  emit(
    kind: RiftEvent['kind'],
    stage: string,
    data: Record<string, unknown>,
    status?: RiftStatus,
  ): Promise<void> {
    try {
      this.#assertOpen();
    } catch (error) {
      return Promise.reject(error);
    }
    return this.#queue(async () => {
      const redactedData = redactRecord(data);
      const now = Date.now();
      if (kind === 'stage_started') {
        this.#summary.phases.push({
          ...structuredClone(redactedData),
          stage,
          status: 'running',
          started_at: new Date(now).toISOString(),
          started_at_ms: now,
        });
      } else if (kind === 'stage_finished') {
        const phase = this.#summary.phases.findLast(
          (entry) => entry.stage === stage && entry.finished_at === undefined,
        );
        if (phase) {
          Object.assign(phase, structuredClone(redactedData));
          phase.stage = stage;
          phase.status = status ?? 'passed';
          phase.finished_at = new Date(now).toISOString();
          phase.duration_ms =
            typeof phase.started_at_ms === 'number'
              ? now - phase.started_at_ms
              : 0;
          delete phase.started_at_ms;
        }
      }
      await this.#appendEvent(kind, stage, redactedData, status);
    });
  }

  appendOutput(
    stage: string,
    role: string,
    stream: 'stdout' | 'stderr',
    line: string,
  ): Promise<void> {
    try {
      this.#assertOpen();
    } catch (error) {
      return Promise.reject(error);
    }
    return this.#queue(async () => {
      const outputPath =
        stream === 'stdout' ? this.stdoutPath : this.stderrPath;
      await fs.appendFile(outputPath, `${line}\n`, 'utf8');
      await this.#appendEvent('process_output', stage, {
        role,
        stream,
        line: redactUserPaths(line),
      });
    });
  }

  async addFailure(failure: RiftFailure): Promise<void> {
    this.#assertOpen();
    const redacted = {
      ...failure,
      message: redactUserPaths(failure.message),
    };
    await this.#queue(async () => {
      this.#summary.failures.push(redacted);
      await this.#appendEvent('failure', redacted.stage, redacted, 'failed');
    });
  }

  async addArtifact(record: ArtifactRecord): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      const redacted = redactRecord(
        record as unknown as Record<string, unknown>,
      );
      this.#summary.artifacts.push(redacted as unknown as ArtifactRecord);
      await this.#appendEvent('artifact', record.stage, redacted);
    });
  }

  async setTests(tests: NonNullable<RiftSummary['tests']>): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.tests = { ...tests };
    });
  }

  async setRepository(revision: string, dirty: boolean): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.repository = { revision, dirty };
    });
  }

  async setToolVersions(versions: Record<string, string>): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.tool_versions = { ...versions };
    });
  }

  async addPhase(phase: Record<string, unknown>): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.phases.push(structuredClone(redactRecord(phase)));
    });
  }

  async addProcess(result: ProcessResult): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.processes.push({
        role: result.role,
        root_pid: result.rootPid,
        owned_pids: [...result.ownedPids],
        exit_code: result.exitCode,
        signal: result.signal,
        termination: result.termination,
        started_at: result.startedAt,
        finished_at: result.finishedAt,
        duration_ms: result.durationMs,
      });
    });
  }

  async setRuntimeSignatures(
    signatures: RiftSummary['runtime_signatures'],
  ): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.runtime_signatures = structuredClone(signatures);
    });
  }

  async setResourceMaxima(
    maxima: Array<Record<string, unknown>>,
  ): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.resource_maxima = structuredClone(maxima);
    });
  }

  async setCleanup(cleanup: RiftSummary['cleanup']): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.cleanup = {
        passed: cleanup.passed,
        leftovers: [...cleanup.leftovers],
        retained: [...cleanup.retained],
      };
    });
  }

  async addCleanupLeftover(leftover: string): Promise<void> {
    this.#assertOpen();
    await this.#queue(async () => {
      this.#summary.cleanup.passed = false;
      if (!this.#summary.cleanup.leftovers.includes(leftover)) {
        this.#summary.cleanup.leftovers.push(leftover);
      }
    });
  }

  async finish(status: RiftStatus, exitCode: number): Promise<RiftSummary> {
    if (this.#finished) {
      return structuredClone(this.#finished);
    }
    if (!this.#finishPromise) {
      this.#finishing = true;
      this.#finishPromise = this.#finalize(status, exitCode);
    }
    return structuredClone(await this.#finishPromise);
  }

  async #finalize(status: RiftStatus, exitCode: number): Promise<RiftSummary> {
    await this.#queue(() =>
      this.#appendEvent('run_finished', 'run', { exit_code: exitCode }, status),
    );
    await this.#writes;

    const finishedAtMs = Date.now();
    for (const phase of this.#summary.phases) {
      if (phase.finished_at !== undefined) {
        continue;
      }
      phase.status = status;
      phase.finished_at = new Date(finishedAtMs).toISOString();
      phase.duration_ms =
        typeof phase.started_at_ms === 'number'
          ? finishedAtMs - phase.started_at_ms
          : 0;
      delete phase.started_at_ms;
    }
    this.#summary.status = status;
    this.#summary.exit_code = exitCode;
    this.#summary.finished_at = new Date(finishedAtMs).toISOString();
    this.#summary.duration_ms = finishedAtMs - this.#startedAtMs;
    const temporaryPath = `${this.#summaryPath}.${crypto.randomUUID()}.tmp`;
    await fs.writeFile(
      temporaryPath,
      `${JSON.stringify(this.#summary, null, 2)}\n`,
      'utf8',
    );
    await fs.rename(temporaryPath, this.#summaryPath);
    this.#finished = structuredClone(this.#summary);
    return structuredClone(this.#summary);
  }
}

export const hashArtifact = async (
  absolutePath: string,
  runDir: string,
  stage: string,
  freshness: ArtifactRecord['freshness'],
): Promise<ArtifactRecord> => {
  const resolvedRunDir = path.resolve(runDir);
  const resolvedArtifact = path.resolve(absolutePath);
  const relativePath = path.relative(resolvedRunDir, resolvedArtifact);
  if (pathEscapes(relativePath)) {
    throw new Error('artifact path escapes run directory');
  }

  const file = Bun.file(resolvedArtifact);
  const bytes = new Uint8Array(await file.arrayBuffer());
  const sha256 = new Bun.CryptoHasher('sha256').update(bytes).digest('hex');
  return {
    path: relativePath.replaceAll('\\', '/'),
    size: bytes.byteLength,
    sha256,
    stage,
    freshness,
  };
};

export const normalizeRuntimeSignature = (message: string): string =>
  message
    .replaceAll(/\[0x[0-9a-f]+\]/gi, '[ref]')
    .replaceAll(/\d+/g, 'N')
    .trim();

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const RIFT_STATUSES = new Set<RiftStatus>([
  'passed',
  'failed',
  'timed_out',
  'cancelled',
  'ready_then_stopped',
]);
const EVIDENCE_CLASSES = new Set<EvidenceClass>([
  'inspection',
  'compiler',
  'full_build',
  'boot',
  'focused_test',
  'full_test',
  'soak',
]);
const EVENT_KINDS = new Set<RiftEvent['kind']>([
  'run_started',
  'stage_started',
  'process_started',
  'process_output',
  'observation',
  'artifact',
  'stage_finished',
  'failure',
  'run_finished',
]);

const validateStoredSummary = (value: unknown): RiftSummary => {
  if (!isRecord(value)) {
    throw new Error('invalid stored summary');
  }
  if (value.schema_version !== RIFT_SCHEMA_VERSION) {
    throw new Error(
      `unsupported report schema: ${String(value.schema_version)}`,
    );
  }
  if (
    typeof value.run_id !== 'string' ||
    typeof value.command !== 'string' ||
    typeof value.profile !== 'string' ||
    !RIFT_STATUSES.has(value.status as RiftStatus) ||
    !EVIDENCE_CLASSES.has(value.evidence as EvidenceClass) ||
    !Number.isInteger(value.exit_code) ||
    typeof value.started_at !== 'string' ||
    typeof value.finished_at !== 'string' ||
    !Number.isInteger(value.duration_ms) ||
    !isRecord(value.repository) ||
    typeof value.repository.revision !== 'string' ||
    typeof value.repository.dirty !== 'boolean' ||
    !isRecord(value.tool_versions) ||
    (value.network_mode !== 'offline' && value.network_mode !== 'allow') ||
    !Array.isArray(value.phases) ||
    !Array.isArray(value.processes) ||
    !Array.isArray(value.runtime_signatures) ||
    !Array.isArray(value.resource_maxima) ||
    !Array.isArray(value.artifacts) ||
    !Array.isArray(value.failures) ||
    !isRecord(value.cleanup) ||
    typeof value.cleanup.passed !== 'boolean' ||
    !Array.isArray(value.cleanup.leftovers) ||
    (value.cleanup.retained !== undefined &&
      !Array.isArray(value.cleanup.retained))
  ) {
    throw new Error('invalid stored summary');
  }
  value.cleanup.retained ??= [];
  return value as unknown as RiftSummary;
};

const validateStoredEvent = (
  value: unknown,
  runId: string,
  expectedSequence: number,
): RiftEvent => {
  if (!isRecord(value)) {
    throw new Error(`invalid stored event at sequence ${expectedSequence}`);
  }
  if (value.schema_version !== RIFT_SCHEMA_VERSION) {
    throw new Error(
      `unsupported event schema: ${String(value.schema_version)}`,
    );
  }
  if (value.sequence !== expectedSequence) {
    throw new Error(
      `invalid event sequence: expected ${expectedSequence}, received ${String(value.sequence)}`,
    );
  }
  if (
    value.run_id !== runId ||
    typeof value.timestamp !== 'string' ||
    !EVENT_KINDS.has(value.kind as RiftEvent['kind']) ||
    typeof value.stage !== 'string' ||
    !isRecord(value.data) ||
    (value.status !== undefined &&
      !RIFT_STATUSES.has(value.status as RiftStatus))
  ) {
    throw new Error(`invalid stored event at sequence ${expectedSequence}`);
  }
  return value as unknown as RiftEvent;
};

export const readStoredRun = async (
  runDir: string,
): Promise<{ summary: RiftSummary; events: RiftEvent[] }> => {
  const summary = validateStoredSummary(
    await Bun.file(path.join(runDir, 'summary.json')).json(),
  );

  const eventText = await Bun.file(path.join(runDir, 'events.ndjson')).text();
  const events = eventText.trim()
    ? eventText
        .trim()
        .split('\n')
        .map((line, index) =>
          validateStoredEvent(JSON.parse(line), summary.run_id, index + 1),
        )
    : [];
  const terminal = events.at(-1);
  if (
    terminal?.kind !== 'run_finished' ||
    terminal.status !== summary.status ||
    terminal.data.exit_code !== summary.exit_code
  ) {
    throw new Error('stored run terminal event does not match summary');
  }
  return { summary, events };
};

export const renderHumanSummary = (summary: RiftSummary): string => {
  const lines = [
    `RIFT ${summary.command} ${summary.status}`,
    `run: ${summary.run_id}`,
    `evidence: ${summary.evidence}`,
    `exit: ${summary.exit_code}`,
    `duration_ms: ${summary.duration_ms}`,
    `repository: ${summary.repository.revision} dirty=${String(summary.repository.dirty)}`,
  ];
  for (const [tool, version] of Object.entries(summary.tool_versions).sort(
    ([left], [right]) => left.localeCompare(right),
  )) {
    lines.push(`tool: ${tool}=${version}`);
  }
  if (summary.tests) {
    lines.push(
      `tests: recorded=${summary.tests.recorded} passed=${summary.tests.passed} failed=${summary.tests.failed} skipped=${summary.tests.skipped}`,
    );
  }
  for (const phase of summary.phases) {
    if (phase.stage === 'doctor') {
      lines.push(
        `doctor: offline_ready=${String(phase.offline_ready)} lock=${String(phase.lock)} platform=${String(phase.platform)}`,
      );
      if (Array.isArray(phase.stale_scratch)) {
        for (const scratch of phase.stale_scratch) {
          lines.push(`stale_scratch: ${String(scratch)}`);
        }
      }
      continue;
    }
    const details = [
      typeof phase.status === 'string' ? `status=${phase.status}` : null,
      typeof phase.duration_ms === 'number'
        ? `duration_ms=${phase.duration_ms}`
        : null,
    ].filter((entry): entry is string => entry !== null);
    lines.push(
      `phase: ${String(phase.stage ?? 'unknown')}${details.length > 0 ? ` ${details.join(' ')}` : ''}`,
    );
  }
  for (const processResult of summary.processes) {
    const details = [
      `role=${String(processResult.role ?? 'unknown')}`,
      `termination=${String(processResult.termination ?? 'unknown')}`,
      `exit=${String(processResult.exit_code ?? 'null')}`,
      typeof processResult.duration_ms === 'number'
        ? `duration_ms=${processResult.duration_ms}`
        : null,
    ].filter((entry): entry is string => entry !== null);
    lines.push(`process: ${details.join(' ')}`);
  }
  for (const signature of summary.runtime_signatures) {
    lines.push(
      `runtime: count=${signature.count} signature=${signature.signature}`,
    );
  }
  for (const maximum of summary.resource_maxima) {
    lines.push(`resource: ${JSON.stringify(maximum)}`);
  }
  const visibleArtifacts = summary.artifacts.slice(0, 8);
  for (const artifact of visibleArtifacts) {
    lines.push(`artifact: ${String(artifact.path)}`);
  }
  if (summary.artifacts.length > visibleArtifacts.length) {
    lines.push(
      `artifacts: ${summary.artifacts.length} total, ${summary.artifacts.length - visibleArtifacts.length} omitted`,
    );
  }
  for (const failure of summary.failures.slice(0, 1)) {
    lines.push(
      `failure [${failure.code}] ${failure.stage}: ${failure.message}`,
    );
  }
  return redactUserPaths(lines.join('\n'));
};
