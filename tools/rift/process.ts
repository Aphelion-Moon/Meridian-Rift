import fs from 'node:fs/promises';
import path from 'node:path';

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

const readPipe = async (pipe: ReadableStream<Uint8Array> | number | null) => {
  if (!pipe || typeof pipe === 'number') {
    return '';
  }
  return new Response(pipe).text();
};

const runEncodedPowerShell = async (
  program: string,
  environment: Record<string, string> = {},
): Promise<{ exitCode: number; stdout: string; stderr: string }> => {
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
  const [stdout, stderr, exitCode] = await Promise.all([
    readPipe(child.stdout),
    readPipe(child.stderr),
    child.exited,
  ]);
  return { exitCode, stdout, stderr };
};

const parseJsonArray = <T>(text: string): T[] => {
  if (!text.trim()) {
    return [];
  }
  const value = JSON.parse(text) as T | T[];
  return Array.isArray(value) ? value : [value];
};

const readProcessTable = async (): Promise<CimProcess[]> => {
  const tableResult = await runEncodedPowerShell(CIM_PROGRAM);
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

export const snapshotDescendants = async (
  rootPid: number,
  rootRole = 'process',
): Promise<ProcessSnapshot[]> => {
  if (!Number.isInteger(rootPid) || rootPid <= 0) {
    throw new Error('root PID must be a positive integer');
  }
  const table = await readProcessTable();
  const rowsByParent = new Map<number, CimProcess[]>();
  for (const row of table) {
    const children = rowsByParent.get(row.ParentProcessId) ?? [];
    children.push(row);
    rowsByParent.set(row.ParentProcessId, children);
  }

  const selected = new Map<number, CimProcess>();
  const root = table.find((row) => row.ProcessId === rootPid);
  if (root) {
    selected.set(rootPid, root);
  }
  const pending = [rootPid];
  while (pending.length > 0) {
    const parent = pending.shift()!;
    for (const child of rowsByParent.get(parent) ?? []) {
      if (!selected.has(child.ProcessId)) {
        selected.set(child.ProcessId, child);
        pending.push(child.ProcessId);
      }
    }
  }
  if (selected.size === 0) {
    return [];
  }

  const resourceResult = await runEncodedPowerShell(RESOURCE_PROGRAM, {
    RIFT_PROCESS_IDS: [...selected.keys()].join(','),
  });
  if (resourceResult.exitCode !== 0) {
    throw new Error(
      `resource snapshot failed: ${resourceResult.stderr.trim()}`,
    );
  }
  const resources = new Map(
    parseJsonArray<ResourceProcess>(resourceResult.stdout).map((entry) => [
      entry.Id,
      entry,
    ]),
  );
  return [...selected.values()]
    .map((entry) => {
      const resource = resources.get(entry.ProcessId);
      return {
        pid: entry.ProcessId,
        parentPid: entry.ProcessId === rootPid ? null : entry.ParentProcessId,
        name: entry.Name,
        creationTime: entry.CreationTime,
        role:
          entry.ProcessId === rootPid
            ? rootRole
            : path.basename(entry.Name, path.extname(entry.Name)).toLowerCase(),
        privateBytes: resource?.PrivateMemorySize64 ?? 0,
        workingSetBytes: resource?.WorkingSet64 ?? 0,
      };
    })
    .sort((left, right) => left.pid - right.pid);
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
) => {
  const owned = [...new Set(ownedPids)].filter(
    (pid) => Number.isInteger(pid) && pid > 0,
  );
  const finalSnapshot = await snapshotDescendants(rootPid).catch(() => []);
  for (const sample of finalSnapshot) {
    if (!owned.includes(sample.pid)) {
      owned.push(sample.pid);
    }
    if (sample.creationTime && !ownedIdentities.has(sample.pid)) {
      ownedIdentities.set(sample.pid, {
        pid: sample.pid,
        parentPid: sample.parentPid,
        name: sample.name,
        creationTime: sample.creationTime,
      });
    }
  }
  if (child && processExists(rootPid)) {
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
    const remainingTable = await readProcessTable().catch(() => []);
    const remainingByPid = new Map(
      remainingTable.map((entry) => [entry.ProcessId, identityFromCim(entry)]),
    );
    const leftovers = identities.filter((expected) => {
      const pid = expected.pid;
      const current = remainingByPid.get(pid);
      return Boolean(current && sameProcessInstance(expected, current));
    });
    if (leftovers.length === 0) {
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
) => {
  if (!pipe || typeof pipe === 'number') {
    return;
  }
  const reader = pipe.getReader();
  const decoder = new TextDecoder();
  let buffered = '';
  for (;;) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    onBytes();
    buffered += decoder.decode(value, { stream: true });
    const lines = buffered.split(/\r?\n/);
    buffered = lines.pop() ?? '';
    for (const line of lines) {
      await onLine(stream, line);
    }
  }
  buffered += decoder.decode();
  if (buffered.length > 0) {
    await onLine(stream, buffered);
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
  const outputReaders = [
    consumeOutput(child.stdout, 'stdout', markActivity, hooks.onOutput),
    consumeOutput(child.stderr, 'stderr', markActivity, hooks.onOutput),
  ];

  const snapshot = async () => snapshotDescendants(rootPid, spec.role);
  const monitor = async () => {
    try {
      await hooks.onStart(rootPid);
      await hooks.onOwnedPids([rootPid]);
      let lastSnapshotMs = 0;
      let naturalExitCode: number | null = null;
      let naturalExited = false;
      void child.exited.then((exitCode) => {
        naturalExitCode = exitCode;
        naturalExited = true;
      });
      let termination: ProcessResult['termination'] = 'natural';

      for (;;) {
        if (requestedTermination) {
          termination = requestedTermination;
          await stopOwnedProcessTree(rootPid, owned, child, ownedIdentities);
          break;
        }
        if (naturalExited) {
          break;
        }

        const now = Date.now();
        if (now - lastSnapshotMs >= 250) {
          const samples = await snapshot().catch(() => []);
          const previousSize = owned.size;
          for (const sample of samples) {
            owned.add(sample.pid);
            if (sample.creationTime && !ownedIdentities.has(sample.pid)) {
              ownedIdentities.set(sample.pid, {
                pid: sample.pid,
                parentPid: sample.parentPid,
                name: sample.name,
                creationTime: sample.creationTime,
              });
            }
          }
          if (owned.size !== previousSize) {
            await hooks.onOwnedPids(
              [...owned].sort((left, right) => left - right),
            );
          }
          if (samples.length > 0) {
            await hooks.onSample(samples);
          }
          lastSnapshotMs = Date.now();
        }
        for (const activityPath of spec.activityPaths ?? []) {
          const size =
            (await fs.stat(activityPath).catch(() => null))?.size ?? 0;
          if (
            activitySizes.has(activityPath) &&
            activitySizes.get(activityPath) !== size
          ) {
            markActivity();
          }
          activitySizes.set(activityPath, size);
        }

        if (Date.now() - startedAtMs >= spec.wallTimeoutMs) {
          termination = 'wall_timeout';
          await stopOwnedProcessTree(rootPid, owned, child, ownedIdentities);
          break;
        }
        if (Date.now() - lastActivityMs >= spec.idleTimeoutMs) {
          termination = 'idle_timeout';
          await stopOwnedProcessTree(rootPid, owned, child, ownedIdentities);
          break;
        }
        await Bun.sleep(25);
      }

      await Promise.all(outputReaders);
      if (termination === 'natural') {
        naturalExitCode = await child.exited;
        const liveDescendants = [...owned].filter(
          (pid) => pid !== rootPid && processExists(pid),
        );
        if (liveDescendants.length > 0) {
          await stopOwnedProcessTree(
            rootPid,
            owned,
            undefined,
            ownedIdentities,
          );
        }
      } else {
        naturalExitCode = await child.exited;
      }
      const finishedAtMs = Date.now();
      const processResult: ProcessResult = {
        role: spec.role,
        rootPid,
        ownedPids: [...owned].sort((left, right) => left - right),
        exitCode: naturalExitCode,
        signal: null,
        termination,
        startedAt: new Date(startedAtMs).toISOString(),
        finishedAt: new Date(finishedAtMs).toISOString(),
        durationMs: finishedAtMs - startedAtMs,
      };
      await hooks.onFinish?.(processResult);
      resolveResult(processResult);
    } catch (error) {
      await stopOwnedProcessTree(rootPid, owned, child, ownedIdentities).catch(
        () => undefined,
      );
      rejectResult(error);
    }
  };
  void monitor();

  return {
    rootPid,
    result,
    stop: async (reason) => {
      requestedTermination = reason;
      return result;
    },
    snapshot,
    ownedPids: () => [...owned].sort((left, right) => left - right),
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
