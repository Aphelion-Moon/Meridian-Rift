# Dogmos Performance Audit Handoff

> **For the performance audit agent:** Work inspection-first. Do not implement a candidate until its cost and caller chain are demonstrated from a current post-fix playtest. Use the repository's test-first workflow for every behavioral change.

**Goal:** Measure the current Dogmos/SSair performance after restoring LINDA's original single equalization pass, identify the remaining dominant costs, and prepare evidence-backed repairs without changing atmosphere behavior.

**Scope:** Meridian-Rift DM integration is the primary target. The sibling `aphelion-dogmos` repository owns Rust domain and service code. Keep DreamDaemon and `dogmosd` measurements separate, preserve public DM proc paths, and do not hand-edit generated bindings or installed native artifacts.

## Start state to verify

This handoff was prepared on branch `dogmos` at `4e2a69e24a2`. The working tree was clean, `origin/dogmos` was one commit behind, and the sibling `aphelion-dogmos` checkout was clean at `7f5177f`. Re-run these checks; do not assume the state is unchanged:

```text
git status --short
git log -5 --oneline --decorate
git -C ..\aphelion-dogmos status --short
git -C ..\aphelion-dogmos log -3 --oneline --decorate
```

Read before editing:

- Root `AGENTS.md` and `.github/guides/{STYLE,AUTODOC,STANDARDS}.md`.
- `modular_nova/readme.md`; also read `HARDDELETES.md` before changing `Destroy()` or reference ownership.
- `docs/agent/{source-authority,dogmos-integration,dogmos-performance-and-memory,dogmos-verification,native-artifacts,rift-controller}.md`.
- The sibling repository's `docs/agent/README.md` and its routed performance, numerical-invariant, protocol, verification, and release guidance before changing Rust.

Do not dispatch subagents without explicit user approval. Protected native, dependency, workflow, release, transport, or deployment files require the exact approval described by the owning repository.

## Current implementation boundary

- `code/controllers/subsystem/air.dm` retains LINDA's `wait = 0.5 SECONDS` and now has `share_max_steps = 1`. The previous value of four multiplied the FDM stage count per SSair cycle.
- `modular_aphelion/modules/dogmos/code/service_backend.dm` executes the configured FDM passes through `process_turfs_auxtools()` and owns mixture registration, generation-safe lifecycle calls, snapshots, commands, and pipenet reconciliation.
- `code/controllers/subsystem/air.dm` owns rebuild scheduling through `process_rebuilds()` and `expand_pipeline()`.
- `code/modules/atmospherics/machinery/datum_pipeline.dm` owns pipeline teardown, `temporarily_store_air()`, and reconstruction/reconciliation behavior.
- The fixed idle `SSair.cost <= 2 ms` test was removed. It was not an upstream LINDA invariant. `dogmos_service_idle_cycle_progress` remains the liveness gate, and `dogmos_service_fdm_linda_cadence` enforces one FDM pass.

The one-pass correction has focused runtime evidence, but it has **no representative post-fix playtest profile yet**. Do not claim a 75% wall-time improvement: only the configured FDM pass count fell from four to one. Reactions, callbacks, rebuilds, lifecycle calls, and other stages do not scale identically.

## Pre-fix playtest evidence

The latest representative human stress log is `data/logs/2026/09/01/round-01.16.58/`. It predates the one-pass correction and is therefore a baseline, not current performance proof.

Workload indicators:

- 94 fusion-test-canister explosions.
- 12 recorded decompressions totaling 520 mol.
- Peak excited group size 256, peak active turfs 2,949, and peak hotspots 633.
- 92 `perf-NULL-MetaStation.csv` samples; Tidi reached 63.75.
- The round did not crash or record a Dogmos service panic/failure. It did record four identical match ignition runtimes, repaired separately and covered by `match_fire_act_deletion`.

For the cumulative built-in profiler interval `profiler-340.json` to `profiler-840.json` (approximately 590 seconds of wall time), group rows by exact proc name and subtract the earlier cumulative counters from the later counters:

| Procedure | Self delta | Inclusive delta | Call delta |
| --- | ---: | ---: | ---: |
| `/datum/controller/subsystem/air/fire` | 0.15 s | 281.96 s | 27,126 |
| `/datum/controller/subsystem/air/proc/process_rebuilds` | 0.21 s | 195.08 s | 8,013 |
| `/datum/controller/subsystem/air/proc/expand_pipeline` | 23.73 s | 194.68 s | 8,073 |
| `/proc/dogmos_mixture_lifecycle_batch` | 143.88 s | 143.89 s | 135,397 |
| `/datum/gas_mixture/Del` | 0.95 s | 138.21 s | 89,392 |
| `/proc/dogmos_mixture_snapshot` | 105.24 s | 105.31 s | 853,089 |
| `/proc/dogmos_mixture_command` | 58.84 s | 58.88 s | 600,736 |
| `/datum/pipeline/Destroy` | 0.22 s | 72.17 s | 45 |
| `/datum/pipeline/proc/temporarily_store_air` | 0.88 s | 71.80 s | 44 |
| `/datum/controller/subsystem/air/proc/process_pipenets` | 0.11 s | 2.66 s | 156 |
| `/proc/dogmos_reconcile_pipeline_mixtures` | 0.23 s | 1.27 s | 1,997 |

The key observation is that ordinary pipenet processing was cheap in this interval. Rebuild-driven mixture lifecycle and snapshot/command crossings dominated. The inclusive values overlap; never sum them into a total.

No file-backed Tracy capture was found for this playtest. The JSON profiler snapshots, Kennel log, runtime log, and perf CSV are valid evidence, but they are not Tracy percentiles.

## Required next audit

- [ ] Recheck checkout state, installed Dogmos contract, and exact BYOND/native versions.
- [ ] Launch a fresh interactive server from current HEAD with `RUN_SERVER_PROFILE.cmd`. It creates `data/enable_tracy` only for the server lifetime and delegates to `RUN_SERVER.cmd`.
- [ ] Repeat the same map and stress sequence as closely as the human operator can reproduce. Record start/end markers for idle settlement, fusion/explosion stress, decompression, and recovery.
- [ ] Preserve the entire new round directory. Record whether a `.tracy` capture was actually produced; do not infer one from the marker or launcher name.
- [ ] Compare equal profiler windows and operation counts, not whole files with different durations. Report Tidi, active turfs, hotspots, groups, rebuilds, pipelines, lifecycle calls, snapshot calls, command calls, and callback pressure together.
- [ ] Separate DreamDaemon private/working-set measurements from `dogmosd` resident memory. A lower combined total is not an acceptance criterion.
- [ ] Run at least three identical controls and three identical candidates before accepting a performance change. If the human workload cannot be repeated, classify the result as diagnostic rather than comparative.

## Investigation order

### 1. Verify the one-pass result

Compare the post-fix profile with the pre-fix baseline. Confirm that `process_turfs_auxtools()` completes one pass per cycle and that atmosphere propagation, event output, fire behavior, pressure callbacks, and convergence remain correct. If active-turf cost does not fall, inspect call counts and pending-stage resumes before changing budgets or cadence.

### 2. Explain rebuild-induced mixture destruction

Use profiler caller arcs and source tracing to explain why 44 `temporarily_store_air()` calls coincided with 89,392 `gas_mixture/Del` calls. Identify the exact allocation/deletion loop and ownership transitions before proposing batching. Check:

- `process_rebuilds()` and `expand_pipeline()` in `code/controllers/subsystem/air.dm`.
- `Destroy()`, `temporarily_store_air()`, merge, build, and reconciliation in `datum_pipeline.dm`.
- `/datum/gas_mixture/New`, `Del`, `register_mixture()`, and `unregister_mixture()` in `service_backend.dm`.
- Whether slot reuse, generation changes, or temporary mixture construction accounts for the call volume.

Prefer removing redundant create/destroy work or reusing valid ownership over hiding it behind a larger batch.

### 3. Evaluate lifecycle batching only after ownership is proven

Registrations are immediately followed by commands such as volume initialization, so deferring registration can violate read-after-write ordering. Unregistration cannot release a slot for reuse until the service accepts the generation-qualified retirement. Any batching design must preserve:

- slot/generation identity and stale-handle rejection;
- command ordering and transaction visibility;
- stage/frontier mutation barriers;
- bounded queue size, age, and failure behavior;
- fail-closed service errors with caller-legible diagnostics.

Write a failing focused test for the demonstrated churn or ordering defect before implementation. Do not weaken lifecycle safety to improve a synthetic benchmark.

### 4. Reduce snapshots and commands only with equivalence evidence

The pre-fix window recorded 853,089 snapshots and 600,736 commands. Attribute them to exact DM callers. Reuse the existing revision-checked snapshot cache and atomic pipenet reconciliation where valid. Reject caches that can return stale data after native writes or callbacks. A fused command is acceptable only if it preserves the same numerical state and event transcript.

## Verification gates

Use checked-in entry points and keep evidence classes separate:

```text
RIFT.cmd compile --mode fast --profile dogmos --network offline
RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus <test-path> --shim dogmos.dll --service dogmosd.exe --network offline
RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json --run-seconds 300 --shim dogmos.dll --service dogmosd.exe --network offline
RIFT.cmd report <run-id> --format human
```

Required before reporting a repair complete:

- Focused red/green regression for the exact defect.
- DreamMaker compile with zero errors.
- Relevant Dogmos focused tests and numerical/event equivalence checks.
- Full MetaStation Dogmos CI suite or an explicit blocker report.
- Full RuntimeStation boot/soak with runtime, panic, service-child, cleanup, and resource artifacts inspected.
- Repeated matched human performance runs for performance claims.

Known full-suite blocker at handoff time: RIFT run `20260902T003644Z-cecde3c3` compiled successfully but stopped during map initialization on repeated unrelated `Cannot read null.x` runtimes in `/obj/proc/find_and_mount_on_atom` at `code/datums/components/atom_mounted.dm:201`. Keep this separate from Dogmos results unless a Dogmos change alters the signature or occurrence.

Focused evidence already obtained:

- `20260902T000833Z-c1cef67a`: `dogmos_service_fdm_linda_cadence` passed.
- `20260902T002506Z-d849abc0`: with the match guard intentionally absent, the corrected fixture reproduced the exact `Cannot execute null.pollute turf()` runtime.
- `20260902T003043Z-f3fbd2b1`: the match regression passed with the guard restored.

## Stop conditions and reporting

Stop and request direction before changing atmosphere coefficients, public DM contracts, generated bindings, native artifact pins, transport, dependencies, workflow/release files, or deployment tooling. Do not commit or push unless explicitly authorized for the current audit.

Report findings in this order:

1. Current checkout, artifacts, versions, and workload identity.
2. Correctness/runtime outcome.
3. DreamDaemon timing and memory.
4. `dogmosd` timing and memory, separately.
5. Dominant caller chains with counts and overlapping-time caveats.
6. Proposed repair, expected mechanism, tests, and rollback boundary.
7. Unrun or blocked gates.

The immediate deliverable is a measured post-fix audit and a ranked repair plan. Implementation begins only after the evidence identifies a bounded target and the user approves that resolution.
