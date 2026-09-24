import { dlopen, ptr } from 'bun:ffi';
import fs from 'node:fs/promises';
import path from 'node:path';

// Bun 1.3.5 reports only the low byte of Windows process exit codes. Keep a
// query-only handle while its live spawn handle still proves the PID identity.
const windowsProcessApi =
  process.platform === 'win32'
    ? dlopen('kernel32.dll', {
        OpenProcess: { args: ['u32', 'i32', 'u32'], returns: 'ptr' },
        GetExitCodeProcess: { args: ['ptr', 'ptr'], returns: 'i32' },
        CloseHandle: { args: ['ptr'], returns: 'i32' },
      }).symbols
    : null;

const captureWindowsExit = (pid: number) => {
  if (!windowsProcessApi) return null;
  const api = windowsProcessApi;
  const handle = api.OpenProcess(0x1000, 0, pid); // PROCESS_QUERY_LIMITED_INFORMATION
  if (!handle)
    throw new Error(`Cannot retain Windows exit handle for PID ${pid}`);
  let closed = false;
  return {
    read: () => {
      const code = new Uint32Array(1);
      if (!api.GetExitCodeProcess(handle, ptr(code)))
        throw new Error(`Cannot read Windows exit code for PID ${pid}`);
      return code[0];
    },
    close: () => {
      if (closed) return;
      closed = true;
      if (!api.CloseHandle(handle))
        throw new Error(`Cannot close Windows exit handle for PID ${pid}`);
    },
  };
};

export type ProcessSpec = {
  role: string;
  executable: string;
  args: string[];
  cwd: string;
  env: Record<string, string>;
  wallTimeoutMs: number;
  idleTimeoutMs: number;
  activityPaths?: string[];
};

export type ProcessResult = {
  role: string;
  rootPid: number;
  ownedPids: number[];
  exitCode: number | null;
  signal: string | null;
  termination:
    | 'natural'
    | 'requested'
    | 'wall_timeout'
    | 'idle_timeout'
    | 'cancelled';
  startedAt: string;
  finishedAt: string;
  durationMs: number;
  supervisionErrors?: string[];
  cleanupErrors?: string[];
};

export type ProcessSnapshot = {
  pid: number;
  parentPid: number | null;
  name: string;
  creationTime?: string;
  role: string;
  privateBytes: number;
  workingSetBytes: number;
};

export type ProcessHooks = {
  onStart: (pid: number) => Promise<void>;
  onOutput: (stream: 'stdout' | 'stderr', line: string) => Promise<void>;
  onOwnedPids: (pids: number[]) => Promise<void>;
  onSample: (samples: ProcessSnapshot[]) => Promise<void>;
  onFinish?: (result: ProcessResult) => Promise<void>;
};

export type OwnedProcess = {
  rootPid: number;
  result: Promise<ProcessResult>;
  stop: (reason: 'requested' | 'cancelled') => Promise<ProcessResult>;
  snapshot: () => Promise<ProcessSnapshot[]>;
  ownedPids: () => number[];
};

type CimProcess = {
  ProcessId: number;
  ParentProcessId: number;
  Name: string;
  CreationTime: string;
};

export type ProcessIdentity = {
  pid: number;
  parentPid: number | null;
  name: string;
  creationTime: string;
};

type ResourceProcess = {
  Id: number;
  PrivateMemorySize64: number;
  WorkingSet64: number;
};

const CIM_PROGRAM = `
$ErrorActionPreference = 'Stop'
@(Get-CimInstance Win32_Process | ForEach-Object {
  [pscustomobject]@{
    ProcessId = $_.ProcessId
    ParentProcessId = $_.ParentProcessId
    Name = $_.Name
    CreationTime = if ($null -eq $_.CreationDate) { '' } else { $_.CreationDate.ToUniversalTime().ToString('O') }
  }
}) |
  ConvertTo-Json -Compress
`;

const RESOURCE_PROGRAM = `
$ErrorActionPreference = 'Stop'
$tokens = @($env:RIFT_PROCESS_IDS -split ',')
$invalidTokens = @($tokens | Where-Object { $_ -notmatch '^[0-9]+$' })
if ($tokens.Count -eq 0 -or $invalidTokens.Count -ne 0) { exit 2 }
$ids = @($tokens | ForEach-Object { [int]$_ })
@(Get-Process -Id $ids -ErrorAction SilentlyContinue |
  Select-Object Id, PrivateMemorySize64, WorkingSet64) |
  ConvertTo-Json -Compress
`;

const STOP_IDENTITIES_PROGRAM = `
$ErrorActionPreference = 'Stop'
$expected = $env:RIFT_PROCESS_IDENTITIES | ConvertFrom-Json
$currentById = @{}
Get-CimInstance Win32_Process | ForEach-Object { $currentById[[int]$_.ProcessId] = $_ }
foreach ($identity in @($expected)) {
  $current = $currentById[[int]$identity.pid]
  if ($null -eq $current) { continue }
  $created = if ($null -eq $current.CreationDate) { '' } else { $current.CreationDate.ToUniversalTime().ToString('O') }
  if ($current.Name -ine $identity.name -or $created -ne $identity.creationTime) { continue }
  Stop-Process -Id $identity.pid -Force -ErrorAction SilentlyContinue
}
`;

const encodePowerShell = (program: string) =>
  Buffer.from(program, 'utf16le').toString('base64');

const HELPER_TIMEOUT_MS = 5_000;
const DRAIN_TIMEOUT_MS = 1_000;

const errorMessage = (error: unknown) =>
  error instanceof Error ? error.message : String(error);

/** Bounds helper execution and output independently of the supervised process. */
export const runEncodedPowerShell = async (
  program: string,
  environment: Record<string, string> = {},
  signal?: AbortSignal,
): Promise<{ exitCode: number; stdout: string; stderr: string }> => {
  signal?.throwIfAborted();
  const child = Bun.spawn({
    cmd: [
      'powershell.exe',
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-EncodedCommand',
      encodePowerShell(program),
    ],
    env: { ...process.env, ...environment },
    stdout: 'pipe',
    stderr: 'pipe',
    windowsHide: true,
  });
  const output = { stdout: '', stderr: '' };
  const readersAbort = new AbortController();
  const readers = (['stdout', 'stderr'] as const).map((stream) =>
    consumeOutput(
      child[stream],
      stream,
      () => {},
      async (_, line) => {
        output[stream] += `${line}\n`;
        if (output[stream].length > 4 * 1024 * 1024)
          throw new Error('process helper output exceeded 4 MiB');
      },
      readersAbort.signal,
      4 * 1024 * 1024,
    ),
  );
  let timer: ReturnType<typeof setTimeout>;
  let onAbort: () => void = () => {};
  const interrupted = new Promise<never>((_, reject) => {
    onAbort = () => reject(new Error('process helper cancelled'));
    signal?.addEventListener('abort', onAbort, { once: true });
    timer = setTimeout(
      () => reject(new Error('process helper timed out')),
      HELPER_TIMEOUT_MS,
    );
  });
  try {
    const [exitCode] = await Promise.race([
      Promise.all([child.exited, ...readers]),
      interrupted,
    ]);
    return { exitCode: exitCode as number, ...output };
  } finally {
    clearTimeout(timer!);
    signal?.removeEventListener('abort', onAbort);
    if (child.exitCode === null) child.kill();
    readersAbort.abort();
    await Promise.race([
      Promise.allSettled([child.exited, ...readers]),
      Bun.sleep(DRAIN_TIMEOUT_MS),
    ]);
  }
};

const parseJsonArray = <T>(text: string): T[] => {
  if (!text.trim()) {
    return [];
  }
  const value = JSON.parse(text) as T | T[];
  return Array.isArray(value) ? value : [value];
};

const readProcessTable = async (
  signal?: AbortSignal,
): Promise<CimProcess[]> => {
  const tableResult = await runEncodedPowerShell(CIM_PROGRAM, {}, signal);
  if (tableResult.exitCode !== 0) {
    throw new Error(`process snapshot failed: ${tableResult.stderr.trim()}`);
  }
  return parseJsonArray<CimProcess>(tableResult.stdout);
};

export const sameProcessInstance = (
  expected: ProcessIdentity,
  current: ProcessIdentity,
): boolean =>
  expected.creationTime.length > 0 &&
  current.creationTime.length > 0 &&
  expected.pid === current.pid &&
  expected.name.toLowerCase() === current.name.toLowerCase() &&
  expected.creationTime === current.creationTime;

const identityFromCim = (
  entry: CimProcess,
  rootPid?: number,
): ProcessIdentity => ({
  pid: entry.ProcessId,
  parentPid:
    rootPid !== undefined && entry.ProcessId === rootPid
      ? null
      : entry.ParentProcessId,
  name: entry.Name,
  creationTime: entry.CreationTime,
});

const stopMatchingProcesses = async (identities: ProcessIdentity[]) => {
  if (identities.length === 0) {
    return;
  }
  const result = await runEncodedPowerShell(STOP_IDENTITIES_PROGRAM, {
    RIFT_PROCESS_IDENTITIES: JSON.stringify(identities),
  });
  if (result.exitCode !== 0) {
    throw new Error(`owned process cleanup failed: ${result.stderr.trim()}`);
  }
};

/** Adopts descendants only while an authenticated parent instance is still in the snapshot. */
export const authenticatedDescendants = (
  table: ProcessIdentity[],
  known: Map<number, ProcessIdentity>,
): ProcessIdentity[] => {
  const selected = new Map<number, ProcessIdentity>();
  for (const current of table) {
    const expected = known.get(current.pid);
    if (expected && sameProcessInstance(expected, current))
      selected.set(current.pid, current);
  }
  let changed = true;
  while (changed) {
    changed = false;
    for (const current of table) {
      if (selected.has(current.pid) || known.has(current.pid)) continue;
      const parent = selected.get(current.parentPid ?? -1);
      if (
        parent &&
        current.creationTime &&
        Date.parse(current.creationTime) >= Date.parse(parent.creationTime)
      ) {
        selected.set(current.pid, current);
        changed = true;
      }
    }
  }
  return [...selected.values()];
};

export const snapshotDescendants = async (
  rootPid: number,
  rootRole = 'process',
  known?: Map<number, ProcessIdentity>,
  signal?: AbortSignal,
): Promise<ProcessSnapshot[]> => {
  if (!Number.isInteger(rootPid) || rootPid <= 0)
    throw new Error('root PID must be a positive integer');
  const table = (await readProcessTable(signal)).map((row) =>
    identityFromCim(row, rootPid),
  );
  const root = table.find((row) => row.pid === rootPid);
  const seeds = known ?? new Map(root ? [[rootPid, root]] : []);
  const selected = authenticatedDescendants(table, seeds);
  if (selected.length === 0) return [];
  const resourceResult = await runEncodedPowerShell(
    RESOURCE_PROGRAM,
    {
      RIFT_PROCESS_IDS: selected.map(({ pid }) => pid).join(','),
    },
    signal,
  );
  if (resourceResult.exitCode !== 0)
    throw new Error(
      `resource snapshot failed: ${resourceResult.stderr.trim()}`,
    );
  const resources = new Map(
    parseJsonArray<ResourceProcess>(resourceResult.stdout).map((entry) => [
      entry.Id,
      entry,
    ]),
  );
  return selected
    .map((entry) => ({
      ...entry,
      role:
        entry.pid === rootPid
          ? rootRole
          : path.basename(entry.name, path.extname(entry.name)).toLowerCase(),
      privateBytes: resources.get(entry.pid)?.PrivateMemorySize64 ?? 0,
      workingSetBytes: resources.get(entry.pid)?.WorkingSet64 ?? 0,
    }))
    .sort((a, b) => a.pid - b.pid);
};

/** Children first seen after an owned parent disappears require manual reconciliation. */
export const unresolvedDescendants = (
  table: ProcessIdentity[],
  known: Map<number, ProcessIdentity>,
  rootPid: number,
): ProcessIdentity[] => {
  const authenticated = new Set(
    authenticatedDescendants(table, known).map(({ pid }) => pid),
  );
  const observed = new Map(table.map((row) => [row.pid, row]));
  return table.filter((row) => {
    if (
      authenticated.has(row.pid) ||
      (row.parentPid !== rootPid && !known.has(row.parentPid ?? -1))
    )
      return false;
    const parent = observed.get(row.parentPid ?? -1);
    // A child born after a demonstrably reused parent belongs to the new instance.
    return (
      !parent || Date.parse(row.creationTime) < Date.parse(parent.creationTime)
    );
  });
};

const processExists = (pid: number) => {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    return (error as NodeJS.ErrnoException).code === 'EPERM';
  }
};

export const stopOwnedProcessTree = async (
  rootPid: number,
  ownedPids: Iterable<number>,
  child?: ReturnType<typeof Bun.spawn>,
  ownedIdentities: Map<number, ProcessIdentity> = new Map(),
  inspect = readProcessTable,
) => {
  const owned = [...new Set(ownedPids)].filter(
    (pid) => Number.isInteger(pid) && pid > 0,
  );
  const errors: string[] = [];
  try {
    const table = (await inspect()).map((row) => identityFromCim(row, rootPid));
    const root = table.find((row) => row.pid === rootPid);
    if (root && child?.exitCode === null && !ownedIdentities.has(rootPid)) {
      ownedIdentities.set(rootPid, root);
    }
    const unresolved = unresolvedDescendants(table, ownedIdentities, rootPid);
    if (unresolved.length) {
      errors.push(
        `cleanup ancestry unknown for unverified descendants: ${unresolved.map(({ pid }) => pid).join(',')}`,
      );
    }
    for (const identity of authenticatedDescendants(table, ownedIdentities)) {
      ownedIdentities.set(identity.pid, identity);
      if (!owned.includes(identity.pid)) owned.push(identity.pid);
    }
  } catch (error) {
    errors.push(`cleanup inspection unknown: ${errorMessage(error)}`);
  }
  if (child && child.exitCode === null) {
    child.kill();
    await Promise.race([child.exited, Bun.sleep(500)]);
  }

  const identities = owned
    .map((pid) => ownedIdentities.get(pid))
    .filter((identity): identity is ProcessIdentity => identity !== undefined)
    .toReversed();
  await stopMatchingProcesses(identities);

  const unverifiedPids = owned.filter(
    (pid) => !ownedIdentities.has(pid) && processExists(pid),
  );
  if (unverifiedPids.length > 0) {
    throw new Error(
      `owned process cleanup identity unavailable: ${unverifiedPids.join(',')}`,
    );
  }

  const deadline = Date.now() + 5_000;
  for (;;) {
    let remainingTable: CimProcess[];
    try {
      remainingTable = await inspect();
    } catch (error) {
      throw new Error(
        [
          ...errors,
          `cleanup verification unknown: ${errorMessage(error)}`,
        ].join('; '),
      );
    }
    const remainingByPid = new Map(
      remainingTable.map((entry) => [entry.ProcessId, identityFromCim(entry)]),
    );
    const leftovers = identities.filter((expected) => {
      const pid = expected.pid;
      const current = remainingByPid.get(pid);
      return Boolean(current && sameProcessInstance(expected, current));
    });
    if (leftovers.length === 0) {
      if (errors.length) throw new Error(errors.join('; '));
      return;
    }
    if (Date.now() >= deadline) {
      throw new Error(
        `owned process cleanup failed: ${leftovers.map(({ pid }) => pid).join(',')}`,
      );
    }
    await Bun.sleep(50);
  }
};

const consumeOutput = async (
  pipe: ReadableStream<Uint8Array> | number | null,
  stream: 'stdout' | 'stderr',
  onBytes: () => void,
  onLine: ProcessHooks['onOutput'],
  signal?: AbortSignal,
  maxLineLength = 64 * 1024,
) => {
  if (!pipe || typeof pipe === 'number') {
    return;
  }
  const reader = pipe.getReader();
  const decoder = new TextDecoder();
  let buffered = '';
  const cancel = () => {
    void reader.cancel().catch(() => undefined);
  };
  signal?.addEventListener('abort', cancel, { once: true });
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) {
        break;
      }
      onBytes();
      buffered += decoder.decode(value, { stream: true });
      const lines = buffered.split(/\r?\n/);
      buffered = lines.pop() ?? '';
      if (buffered.length > maxLineLength)
        throw new Error(
          `process output line exceeded ${maxLineLength} characters`,
        );
      for (const line of lines) {
        await onLine(stream, line);
      }
    }
    buffered += decoder.decode();
    if (buffered.length > 0) {
      await onLine(stream, buffered);
    }
  } finally {
    signal?.removeEventListener('abort', cancel);
    reader.releaseLock();
  }
};

export const startOwnedProcess = (
  spec: ProcessSpec,
  hooks: ProcessHooks,
): OwnedProcess => {
  const child = Bun.spawn({
    cmd: [spec.executable, ...spec.args],
    cwd: spec.cwd,
    env: spec.env,
    stdout: 'pipe',
    stderr: 'pipe',
    windowsHide: true,
  });
  const rootPid = child.pid;
  let windowsExit: ReturnType<typeof captureWindowsExit> = null;
  let exitCaptureError: unknown;
  try {
    windowsExit = captureWindowsExit(rootPid);
  } catch (error) {
    exitCaptureError = error;
  }
  const owned = new Set([rootPid]);
  const ownedIdentities = new Map<number, ProcessIdentity>();
  const startedAtMs = Date.now();
  let lastActivityMs = startedAtMs;
  let requestedTermination: 'requested' | 'cancelled' | null = null;
  const activitySizes = new Map<string, number>();
  let resolveResult!: (result: ProcessResult) => void;
  let rejectResult!: (error: unknown) => void;
  const result = new Promise<ProcessResult>((resolve, reject) => {
    resolveResult = resolve;
    rejectResult = reject;
  });

  const markActivity = () => {
    lastActivityMs = Date.now();
  };
  const readersAbort = new AbortController();
  const samplingAbort = new AbortController();
  const supervisionErrors: string[] = exitCaptureError
    ? [errorMessage(exitCaptureError)]
    : [];
  const cleanupErrors: string[] = [];
  let outputFailure: unknown;
  const outputReaders = [
    consumeOutput(
      child.stdout,
      'stdout',
      markActivity,
      hooks.onOutput,
      readersAbort.signal,
    ),
    consumeOutput(
      child.stderr,
      'stderr',
      markActivity,
      hooks.onOutput,
      readersAbort.signal,
    ),
  ].map((reader) =>
    reader.catch((error) => {
      outputFailure = error;
    }),
  );

  let sampling: Promise<void> | null = null;
  let lastSnapshotMs = 0;
  let snapshotFlight: Promise<ProcessSnapshot[]> | null = null;
  const snapshot = () => {
    snapshotFlight ??= snapshotDescendants(
      rootPid,
      spec.role,
      ownedIdentities,
      samplingAbort.signal,
    ).finally(() => {
      snapshotFlight = null;
    });
    return snapshotFlight;
  };
  const sample = async () => {
    // The live spawn handle proves that the numeric root PID has not yet been reused.
    if (!ownedIdentities.has(rootPid) && child.exitCode === null) {
      const table = await readProcessTable(samplingAbort.signal);
      const root = table.find((entry) => entry.ProcessId === rootPid);
      if (root && child.exitCode === null)
        ownedIdentities.set(rootPid, identityFromCim(root, rootPid));
    }
    const samples = await snapshot();
    for (const row of samples) {
      if (row.creationTime)
        ownedIdentities.set(row.pid, {
          ...row,
          creationTime: row.creationTime,
        });
      owned.add(row.pid);
    }
    await hooks.onOwnedPids([...owned].sort((a, b) => a - b));
    if (samples.length) await hooks.onSample(samples);
  };
  const monitor = async () => {
    let termination: ProcessResult['termination'] = 'natural';
    let primaryError: unknown;
    try {
      await hooks.onStart(rootPid);
      await hooks.onOwnedPids([rootPid]);
      for (;;) {
        if (requestedTermination) {
          termination = requestedTermination;
          break;
        }
        if (outputFailure) throw outputFailure;
        if (child.exitCode !== null) break;
        const now = Date.now();
        if (now - startedAtMs >= spec.wallTimeoutMs) {
          termination = 'wall_timeout';
          break;
        }
        if (now - lastActivityMs >= spec.idleTimeoutMs) {
          termination = 'idle_timeout';
          break;
        }
        if (!sampling && now - lastSnapshotMs >= 250) {
          sampling = sample()
            .catch((error) => {
              if (!samplingAbort.signal.aborted)
                supervisionErrors.push(errorMessage(error));
            })
            .finally(() => {
              sampling = null;
              lastSnapshotMs = Date.now();
            });
        }
        for (const activityPath of spec.activityPaths ?? []) {
          const size =
            (await fs.stat(activityPath).catch(() => null))?.size ?? 0;
          if (
            activitySizes.has(activityPath) &&
            activitySizes.get(activityPath) !== size
          )
            markActivity();
          activitySizes.set(activityPath, size);
        }
        await Bun.sleep(25);
      }
    } catch (error) {
      primaryError = error;
    }

    samplingAbort.abort();
    if (sampling) await sampling;
    // Descendants must be stopped before draining inherited stdout/stderr handles.
    try {
      await stopOwnedProcessTree(rootPid, owned, child, ownedIdentities);
    } catch (error) {
      cleanupErrors.push(errorMessage(error));
    }
    for (const pid of ownedIdentities.keys()) owned.add(pid);
    let drained = false;
    await Promise.race([
      Promise.all(outputReaders).then(() => {
        drained = true;
      }),
      Bun.sleep(DRAIN_TIMEOUT_MS),
    ]);
    if (!drained) {
      readersAbort.abort();
      cleanupErrors.push('output drain timed out; readers cancelled');
      await Promise.race([
        Promise.all(outputReaders),
        Bun.sleep(DRAIN_TIMEOUT_MS),
      ]);
    }
    if (outputFailure) primaryError ??= outputFailure;
    if (primaryError) supervisionErrors.unshift(errorMessage(primaryError));
    let exitCode: number | null = null;
    try {
      if (child.exitCode !== null)
        exitCode = windowsExit ? windowsExit.read() : child.exitCode;
    } catch (error) {
      supervisionErrors.push(errorMessage(error));
    }
    try {
      windowsExit?.close();
    } catch (error) {
      cleanupErrors.push(errorMessage(error));
    }
    const finishedAtMs = Date.now();
    const processResult: ProcessResult = {
      role: spec.role,
      rootPid,
      ownedPids: [...owned].sort((a, b) => a - b),
      exitCode,
      signal: null,
      termination,
      startedAt: new Date(startedAtMs).toISOString(),
      finishedAt: new Date(finishedAtMs).toISOString(),
      durationMs: finishedAtMs - startedAtMs,
      supervisionErrors,
      cleanupErrors,
    };
    try {
      await hooks.onFinish?.(processResult);
      if (supervisionErrors.length || cleanupErrors.length) {
        throw new Error([...supervisionErrors, ...cleanupErrors].join('; '));
      }
      resolveResult(processResult);
    } catch (error) {
      rejectResult(error);
    }
  };
  void monitor()
    .finally(() => windowsExit?.close())
    .catch(rejectResult);
  return {
    rootPid,
    result,
    stop: async (reason) => {
      requestedTermination = reason;
      samplingAbort.abort();
      return result;
    },
    snapshot,
    ownedPids: () => [...owned].sort((a, b) => a - b),
  };
};

export const runProbeProcess = async (
  executable: string,
  args: string[],
  cwd: string,
  environment: Record<string, string>,
): Promise<{ exitCode: number; stdout: string; stderr: string }> => {
  const chunks = { stdout: '', stderr: '' };
  const limit = 1024 * 1024;
  const owned = startOwnedProcess(
    {
      role: 'probe',
      executable,
      args,
      cwd,
      env: environment,
      wallTimeoutMs: 120_000,
      idleTimeoutMs: 120_000,
    },
    {
      onStart: async () => {},
      onOwnedPids: async () => {},
      onSample: async () => {},
      onOutput: async (stream, line) => {
        chunks[stream] += `${line}\n`;
        if (Buffer.byteLength(chunks[stream]) > limit) {
          throw new Error(`probe ${stream} exceeded 1 MiB`);
        }
      },
    },
  );
  const result = await owned.result;
  if (result.termination !== 'natural') {
    throw new Error(`probe terminated: ${result.termination}`);
  }
  return { exitCode: result.exitCode ?? 1, ...chunks };
};
