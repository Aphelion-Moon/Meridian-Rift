# Dogmos post-fix playtest performance audit

## Scope and evidence boundary

This audit reviews `data/logs/2026/09/02/round-02.55.20/` and treats
`round-02.46.34/` as a six-sample initialization-only warm-up. The stress round is diagnostic,
not a matched one-pass candidate: the operator changed `SSair.share_max_steps` from 1 to 4, then
4 to 10, then 10 to 4 before and during the captured stress interval. No `.tracy` file was
produced. The working tree also contains an existing change from `share_max_steps = 1` to 4; this
audit does not modify it.

The built-in profiler counters are cumulative. All figures below group rows by exact proc name and
subtract `profiler-570.json` from `profiler-800.json`. The file timestamps span 283.0 seconds of
wall time. Inclusive times overlap and must not be summed.

## Checkout, contract, and versions

- Meridian-Rift: branch `dogmos`, `HEAD 4e2a69e24a2`.
- Existing working-tree changes at audit start: `code/controllers/subsystem/air.dm`,
  `docs/agent/README.md`, and the untracked performance handoff.
- aphelion-dogmos: clean `HEAD 7f5177fc3726a5c445491259d04a75a94a872006`.
- BYOND DreamMaker and DreamDaemon: 516.1687.
- Installed Dogmos contract: source `7f5177fc3726a5c445491259d04a75a94a872006`, Rust 1.98.0,
  ABI 2, protocol 12, release profile, expected feature fingerprint
  `5fb82b00e54717f3012486b7d3e34d1384f4d5438814859dd15fdee4b87480f5`.
- `verify_contract.py verify-installed --root .`: exit 0.
- Installed Windows hashes match `dogmos.lock.json`: shim
  `85a7deec2477a66536a82c671e1f94ca9601b958f6df2ae6be8ab7a1a0b3df0d`, service
  `e86d05606a6c6a49725ae41718987be219e864b8b8e3e483424bb2b8d409f268`.

## Workload and correctness

- MetaStation, 113 fusion-test canisters created.
- 41 recorded explosions, of which 37 were fusion-test-canister explosions.
- Seven recorded decompressions totaling 289.7 mol.
- Peak recorded fire group: 252 turfs.
- 72 performance samples. In the stress portion beginning at world time 5000, peak active turfs
  were 1,566, peak hotspots 296, peak pressure deltas 514, peak instantaneous Tidi 77.72, and peak
  averaged Tidi 24.83.
- The round recorded two non-Dogmos runtimes: `Cannot read null.loc` in movement handling and a
  turret taking damage after deletion. It recorded no Dogmos service panic, failure, malformed
  stage response, or lifecycle rejection.

Because the stress run changed FDM pass count and has no matched repetitions, it does not measure
the one-pass correction and cannot establish a control/candidate improvement.

## Process memory snapshot

The server was still running when sampled at 03:23 local time. These are single process-lifetime
observations, not repeated-run peaks attributable to Dogmos.

| Process | Working set | Peak working set | Private bytes | Virtual size |
| --- | ---: | ---: | ---: | ---: |
| DreamDaemon (32-bit) | 2,099,163,136 | 2,105,126,912 | 2,112,700,416 | 2,306,600,960 |
| `dogmosd` (64-bit) | 175,489,024 | 263,790,592 | 293,117,952 | 4,645,789,696 |

DreamDaemon's approximately 2.11 GiB private footprint is operationally important, but this run has
no clean matched baseline or sampled time series with which to assign the footprint to a specific
Dogmos allocation path. `dogmosd` remains a separate process and is not added to the 32-bit total.

## Dominant timing

| Exact proc | Self delta | Inclusive delta | Call delta |
| --- | ---: | ---: | ---: |
| `/datum/controller/subsystem/air/fire` | 0.13 s | 151.90 s | 28,799 |
| `/datum/controller/subsystem/air/proc/process_rebuilds` | 0.12 s | 113.31 s | 4,035 |
| `/datum/controller/subsystem/air/proc/expand_pipeline` | 14.51 s | 113.08 s | 4,055 |
| `/proc/dogmos_mixture_lifecycle_batch` | 80.22 s | 80.23 s | 78,807 |
| `/datum/gas_mixture/Del` | 0.50 s | 76.72 s | 50,500 |
| `/datum/pipeline/proc/temporarily_store_air` | 0.51 s | 44.23 s | 24 |
| `/proc/dogmos_mixture_snapshot` | 38.62 s | 38.63 s | 311,941 |
| `/proc/dogmos_mixture_command` | 34.43 s | 34.46 s | 352,594 |
| `/proc/dogmos_simulation_stage` | 4.04 s | 4.04 s | 24,152 |
| `/datum/controller/subsystem/air/proc/process_turfs_auxtools` | 0.01 s | 1.30 s | 3,168 |
| `/datum/controller/subsystem/air/proc/process_pipenets` | 0.04 s | 1.29 s | 86 |

The service simulation stage was not the dominant crossing. Rebuild-driven mixture lifecycle work
was. Ordinary pipenet reconciliation remained cheap.

The maintained three-run cross-bitness IPC benchmark was also run from the matching clean
`aphelion-dogmos` revision with Rust 1.98.0, an i686 shim benchmark, an x86_64 service, 5,000
iterations per ordinary case, and 500 service-stage iterations. The 32-gas service snapshot p50 was
32.4-32.5 microseconds; p95 was 46.5-67.9 microseconds. Batch transport p50 was 31.5-31.8
microseconds for one record and 33.5-33.6 microseconds for 1,024 records. These are local mechanism
measurements rather than playtest acceptance evidence. They show that removing or batching IPC
crossings is materially stronger than micro-optimizing the per-request service dispatch.

## Root cause

`/datum/pipeline/Destroy()` calls `temporarily_store_air()` before disconnecting and rebuilding its
members. The inherited algorithm creates one temporary gas mixture per pipe so a later topology
split can conserve gas by volume. Under service-backed Dogmos, each former in-process field update
became synchronous lifecycle, command, or snapshot IPC:

1. `member.air_temporary = new` registers a service mixture and initializes its volume.
2. `set_volume(member.volume)` sends a second volume command.
3. `air.return_volume()` is evaluated inside the per-member loop.
4. `copy_from_ratio()` sends `copy_from` and `multiply` commands.
5. `set_temperature(air.return_temperature())` sends another command even though Dogmos
   `copy_from` already copies the giver's temperature.
6. `expand_pipeline()` merges each temporary mixture, clears its last pipe reference, and its
   eventual `Del()` unregisters the service slot.

The profiler supports this chain: the interval recorded 48,004 `copy_from_ratio()` calls, 50,498
`set_temperature()` calls, 52,339 mixture constructions, and 50,500 mixture deletions. The generic
command wrapper also evicts both receiver and secondary snapshot-cache entries for `copy_from`,
although Rust mutates only the receiver. Consequently the temperature read following each copy is
normally a fresh native snapshot.

The underlying need to preserve gas across topology splits is valid. The avoidable problem is the
redundant IPC layered onto every temporary mixture, not the safety checks or generation-qualified
retirement.

## Ranked repair plan

### 1. Bounded DM hot-path repair

In `temporarily_store_air()`:

- read the source pipeline volume once before the member loop;
- construct each temporary mixture with `member.volume`, avoiding a second volume command;
- call `copy_from_ratio()` with the cached pipeline volume;
- remove the redundant temperature command because `copy_from` already copies temperature.

This preserves the same temporary-mixture ownership and numerical state. Based on the observed
48,004 loop calls, it targets approximately 96,008 redundant commands and approximately 48,004
source snapshot fetches in this 283-second interval. Those are mechanism estimates, not an accepted
performance result; only matched repeated candidate runs can establish the realized gain.

Add a focused service-backed pipeline test before changing production code. It should build a
multi-member pipeline, observe the current repeated source snapshot misses, and verify after the
repair that temporary volumes, temperatures, total gas, and per-member ratios remain equivalent
with one source snapshot fetch for the store operation.

### 2. Re-measure before lifecycle redesign

The first repair does not remove the 78,807 lifecycle calls. Re-run three matched controls and
three matched candidates with a fixed `share_max_steps` value. If lifecycle retirement remains
dominant, investigate a topology-aware reuse or initialized-allocation batch that preserves slot
generation, read-after-write ordering, stage barriers, bounded queues, and fail-closed errors.

Any new native command, protocol change, generated binding change, artifact update, or lifecycle
batch contract requires separate approval under the protected native boundary.

The current protocol already exposes lifecycle and complete mixture-state batch operations. A
DM-side design can reserve all temporary mixture identities for one pipeline, register them in one
lifecycle batch, and initialize their volumes in one state batch. Expansion can then collect only
the temporaries it has successfully merged, unregister them in one bounded lifecycle call before
the invocation yields or completes, clear their local identities, and delete them without a second
`Del()` unregistration. This avoids changing the protocol while preserving explicit ownership,
atomic failure cleanup, stage barriers, and generation-safe reuse. Do not add a single-record native
fast path: the IPC evidence shows that it would retain the dominant synchronous crossing.

The captured counts make retirement material rather than incidental. There were 52,339
constructions, 50,500 deletions, and 78,807 lifecycle calls. Since each construction currently
registers in its own call, the remaining approximately 26,468 calls serviced the 50,500 deletion
records, with only partial grouping behind existing frontier barriers. Registration batching alone
would therefore leave a large successful-retirement call count. The plan now covers both explicit
pipeline retirement and uncertain-response cleanup.

The executable test-first design, including uncertain-publication rollback, 513-record chunk
coverage, integration gates, and matched-playtest acceptance, is recorded in
`docs/superpowers/plans/2026-09-02-dogmos-pipeline-temporary-batching.md`. It is a plan, not an
implemented or approved repair.

### 3. Attribute remaining general snapshots and commands

After rebuild churn falls, profile exact callers of the remaining snapshot and command traffic.
Do not broaden caching or fuse commands until the caller-specific revision and mutation semantics
are proven.

The existing `equalize_with()` command is a narrower follow-up candidate for the pipeline temporary
path. A fresh temporary mixture already has the member volume it must retain. In native Dogmos,
`equalize_with()` scales the source gases by receiver volume divided by source volume, copies the
source temperature, preserves receiver volume, applies the same floating-point multiplication and
minimum-moles cutoff as `multiply()`, and mutates only the receiver. It therefore replaces
`copy_from_ratio()`'s immutability snapshot plus `copy_from` plus `multiply` with one existing
command. The observed 48,004 `copy_from_ratio()` calls imply approximately 48,004 avoided snapshots
and 48,004 avoided commands beyond the implemented first repair. This is a mechanism estimate, not
a measured candidate result.

The revision difference is not a gameplay-state difference: the old normal path advances a fresh
temporary receiver once for `copy_from` and once for `multiply`, while `equalize_with()` advances it
once for the equivalent final mutation. Revisions are optimistic-concurrency tokens used by state
batches and stage transactions. No state batch or stage transaction captures these newly created,
pipeline-private mixtures between initialization and distribution. A test-first change must still
assert final volume, temperature, per-gas amounts, total conservation, zero snapshots inside the
temporary-store operation, and the single-command revision delta. This candidate uses the existing
DM proc and native command; it does not require a protocol, binding, artifact, or
`aphelion-dogmos` source change.

The same interval exposes a broader snapshot source: 116,289 `is_immutable()` calls consumed 13.43
seconds inclusive. They were dominated by 50,236 `merge()` calls and 48,004
`copy_from_ratio()` calls, with removal, reaction, and frontier-settling checks accounting for the
remainder. Dogmos already enforces immutability inside every native mutating command, but several DM
API wrappers must know the property before choosing their legacy return value, signal behavior, or
immutable-source branch.

Immutability is monotonic over a mixture datum's lifetime. Registration creates a mutable native
record, and `mark_immutable()` is the only DM or native command that can set the property. No
lifecycle, state-batch, callback, reaction, or stage path clears or independently sets it. A
DM-owned boolean initialized false and set only after `mark_immutable()` receives a valid native
response can therefore make `is_immutable()` local without weakening native enforcement. This
removes the preflight snapshot while preserving the current branches and public return values. The
design must retain a native-state assertion after marking and a red/green cache-miss regression;
do not infer the optimization merely from datum type because planetary immutable mixtures defer
finalization while their initial gas is parsed.

Pipeline expansion has another independently measured crossing multiplier. The interval recorded
146,974 `set_volume()` calls, 52,339 mixture constructions, and 48,004 temporary-store iterations.
Subtracting constructor initialization and the explicit temporary-store volume command removed by
the first repair leaves 46,631 calls, close to the 46,500 recorded `pipeline_expansion()` calls.
The yielded `SSair.expand_pipeline()` path currently reads and sets the network mixture's volume for
every newly discovered pipe.

Volume can be accumulated locally for one invocation and published once before either
`MC_TICK_CHECK` returns or the invocation completes. This does not defer state across ticks:
`/datum/pipeline.building` prevents pipeline processing, `replace_pipenet()` only swaps parent
references, and temporary-mixture merge changes gases and temperature but not receiver volume. A
lazy accumulator also preserves the current zero-call behavior when an invocation discovers no new
pipe. Against 4,055 recorded `expand_pipeline()` invocations, the interval counts imply an upper
bound of approximately 42,576 avoided volume commands and the same number of volume snapshots, or
85,152 synchronous crossings. The exact count must be proven by a focused expansion regression and
matched candidate profiles.

The generic command wrapper also evicted 752,498 cache handles for 349,404 commands. It calls the
eviction proc for a zero secondary handle on every single-mixture command, and it evicts read-only
secondary mixtures for `copy_from`, `equalize_with`, and `merge` even though native Dogmos mutates
only their receiver. The interval contained 49,003 `copy_from` and 50,236 native merge calls. A
mutation-aware secondary eviction policy is source-correct, but it is lower priority: the first
pipeline repair no longer rereads the copied source inside the loop, and merged temporaries are
normally retired immediately. Treat this as wrapper overhead and future cache preservation, not as
an explanation for the dominant rebuild stall.

## Implemented repairs

The approved test-first follow-ups are implemented in the working tree:

1. `expand_pipeline()` now reads the network volume lazily, accumulates newly discovered pipe
   volumes locally, and publishes once before either a tick-budget return or normal completion.
   Empty expansions still perform no mixture read or write.
2. Gas-mixture immutability is stored as a monotonic DM datum property after the existing native
   mark command returns successfully. `is_immutable()` no longer fetches a service snapshot;
   native Dogmos remains authoritative for rejecting mutations.
3. `temporarily_store_air()` constructs each receiver at its final member volume and calls the
   existing `equalize_with()` operation. The method now performs zero mixture snapshots and one
   effective receiver mutation per temporary while preserving gas, temperature, and volume.
4. The generic mixture-command wrapper now evicts a secondary snapshot only when the native
   command can mutate that mixture. `copy_from`, `equalize_with`, and `merge` preserve their
   read-only source snapshots; transfers still invalidate both mutated mixtures. Commands without
   a secondary no longer call the eviction helper with a zero handle.

5. The snapshot cache increased from 512 to 2048 direct-mapped buckets. With approximately 2,300
   active turfs and hundreds of machinery, the prior 512-bucket cache suffered frequent collision
   evictions; the 4x increase reduces those while widening the batch prefetch limit.
6. `process_atmos_machinery()` now batch-prefetches the `airs[]` and turf air snapshots of every
   atmos component before the processing loop starts. One batch IPC call replaces one per unique
   mixture accessed, using the existing `prefetch_mixture_snapshots()` infrastructure.
7. `walk_active_turfs_batch()` now batch-prefetches the air snapshots of the walk batch turfs and
   their `atmos_adjacent_turfs` neighbors before the settling walk. `compare()` reads both the
   source and each neighbor's air; the prefetch collapses those first-access misses into one batch.

No native source, protocol, generated binding, installed artifact, manifest, Cargo file, workflow,
or release tool was changed. The sibling `aphelion-dogmos` checkout remains clean at
`7f5177fc3726a5c445491259d04a75a94a872006`.

## Verification and blocked gates

Initial bounded-repair evidence remains:

- Red `20260902T012930Z-d9a2cc57`, green `20260902T014215Z-8d786c87`, and adjacent
  `20260902T014822Z-ff5bbf91` established the constructor-volume and redundant-temperature repair.
- Full MetaStation run `20260902T015957Z-1410adab` remains blocked before tests by eleven existing
  `Cannot read null.x` runtimes from `code/datums/components/atom_mounted.dm:201`.
- RuntimeStation soak `20260902T020403Z-94eb5bef` passed the earlier repair with zero runtime
  signatures and clean owned-process cleanup.

Follow-up test-first evidence:

- Expansion batching red `20260902T083827Z-9fbe18b9` advanced the network mixture revision from 1
  to 4. Green `20260902T085010Z-47380ab3` advanced it once, preserved exact summed volume and
  membership, produced the expected two verification-inclusive snapshot misses, and emitted no
  runtime signatures.
- Local immutability red `20260902T085613Z-9650cbfb` proved that an evicted immutable check fetched
  a service snapshot. Green `20260902T090813Z-b749425e` retained native mutation rejection while
  making the check local, with no runtime signatures.
- Temporary equalization red `20260902T091441Z-e0a6ce41` produced revisions 3 and 3 through
  `copy_from` plus `multiply`. Green `20260902T092629Z-949aab93` produced revisions 2 and 2 through
  one equalization command, used zero method snapshots, and preserved both gases, temperature,
  member volumes, and total conservation.
- Combined run `20260902T093222Z-fb6c69b1` compiled and passed seven focused tests: mixture
  identity, snapshot cache, temporary storage, expansion batching, pipeline reconciliation,
  direct immutable behavior, and deferred planetary immutability through ashwalker lungs. All
  seven records have status 0 and zero runtimes; RIFT recorded no runtime signatures or leftovers.
- A final direct DreamMaker 516.1687 compile after marker validation completed with 0 errors and
  the repository's expected three warnings directing developers to the maintained build entrypoint.
- RuntimeStation soak `20260902T093848Z-44603bf1` compiled and sampled the full map for the bounded
  interval with zero runtime signatures. Across 47 samples DreamDaemon peaked at 1,881,366,528
  private bytes and 1,875,378,176 working-set bytes; `dogmosd` peaked separately at 140,804,096
  private bytes and 88,764,416 working-set bytes. The gate is formally failed, not passed: after
  `dogmosd` was present through 09:50:38.696, DreamDaemon hit RIFT's idle timeout following five
  minutes without new log output, and the terminal required-child check then observed zero
  `dogmosd` children. Cleanup passed with no leftovers. These maxima are qualification observations,
  not a matched performance comparison.

Source-aware cache invalidation evidence:

- Red `20260902T104703Z-14165fe0` failed because `copy_from()` caused two cache misses instead of
  preserving the unchanged source snapshot. Red `20260902T105324Z-52f82706` independently failed
  the same contract for `equalize_with()`.
- Green `20260902T110000Z-90c3006e` passed the focused snapshot-cache test, including source
  preservation for `copy_from`, `equalize_with`, and `merge`, plus two-handle invalidation for a
  real gas transfer. RIFT recorded no runtime signatures.
- Adjacent run `20260902T110618Z-a1247b3a` compiled and passed the same seven Dogmos
  mixture/pipeline tests as the earlier combined gate. All seven records have status 0 and zero
  runtimes; RIFT recorded no runtime signatures or leftovers.
- RuntimeStation soak `20260902T111530Z-165701d8` compiled and collected 38 samples with zero
  runtime signatures. DreamDaemon peaked at 1,887,399,936 private bytes and 1,881,661,440
  working-set bytes; `dogmosd` peaked separately at 140,656,640 private bytes and 88,666,112
  working-set bytes. Cleanup passed with no leftovers. The formal gate failed on the same known
  controller interaction: DreamDaemon reached the quiet-log idle timeout, after which the terminal
  required-child check observed zero `dogmosd` processes.

## Second post-fix playtest: `round-12.01.05`

The operator produced a new MetaStation capture in
`data/logs/2026/09/02/round-12.01.05/`. It contains five cumulative BYOND profiler snapshots and
no `.tracy` file. The 128 created fusion-test canisters correspond to 128 recorded fusion-test
explosions. One admin action also removed 660 firedoors immediately before the stress sequence.
The 121-row runtime log contains no Dogmos panic, service error, malformed response, or runtime
error signature; Dogmos initialized in 0.04 seconds.

The performance CSV contains 109 samples. From the first canister creation at world time 3257.5
through the end of the capture, 85 samples recorded peak instantaneous Tidi 46.69, peak averaged
Tidi 11.63, peak active turfs 2,323, peak hotspots 1,028, and peak pressure deltas 1,728. The final
sample returned to 9.88 Tidi with zero hotspots and zero pressure deltas. These values characterize
the workload; they are not a control/candidate comparison.

The most useful cumulative profile subtraction is `profiler-100.json` to
`profiler-400.json`, spanning 312.5 seconds by file timestamp. It is not a pure stress window: it
contains about 231 seconds before the first canister creation and about 81 seconds beginning with
the stress sequence. Inclusive times overlap and must not be summed.

| Exact proc | Self delta | Inclusive delta | Call delta |
| --- | ---: | ---: | ---: |
| `/proc/dogmos_mixture_snapshot` | 28.41 s | 28.43 s | 229,238 |
| `/proc/dogmos_mixture_lifecycle_batch` | 20.52 s | 20.52 s | 18,553 |
| `/datum/controller/subsystem/air/proc/process_atmos_machinery` | 14.54 s | 45.71 s | 1,867 |
| `/proc/dogmos_simulation_stage` | 10.88 s | 10.89 s | 94,407 |
| `/proc/dogmos_mixture_command` | 5.97 s | 5.97 s | 47,954 |
| `/datum/gas_mixture/proc/dogmos_snapshot` | 1.07 s | 35.73 s | 793,144 |
| `/datum/controller/subsystem/dogmos/proc/lookup_mixture_snapshot_cache` | 2.05 s | 2.32 s | 793,144 |
| `/obj/machinery/atmospherics/components/unary/vent_pump/process_atmos` | 0.46 s | 11.26 s | 45,434 |
| `/datum/controller/subsystem/air/proc/check_kennel_machine_cost` | 0.94 s | 1.56 s | 135,509 |

The cache served approximately 563,906 of the 793,144 snapshot requests without native snapshot
IPC. Getter traffic was nevertheless large: 303,226 temperature calls, 148,191 pressure calls,
144,179 per-gas mole calls, and 51,519 volume calls. Atmos machinery was the clearest exact caller,
led by vent pumps, binary pumps, passive vents, outlet injectors, and mixers.

The previous rebuild/lifecycle diagnosis does not apply to this interval. It recorded only two
`temporarily_store_air()` calls, two pipeline destructions, and three `process_rebuilds()` calls.
The 12,216 registrations and 6,572 deletions instead reflect broader round initialization and
gameplay churn. Implementing pipeline temporary lifecycle batching from this profile would optimize
a path that was nearly absent, so the prepared batching plan remains unimplemented.

The profile did demonstrate the narrower command-cache issue. The wrapper executed 40,090 DM
commands and called the eviction helper 94,616 times. The interval included 521 `copy_from`, 6,546
native merge, and 4,694 `equalize_with` operations whose secondary mixtures are read-only. The new
mutation-aware policy removes those unnecessary source invalidations when a matching entry exists,
and also removes zero-secondary eviction calls. Counts are an upper bound on avoided invalidations,
not a measured wall-time improvement; a fresh matched candidate playtest is still required.

Kennel machinery timing remains a secondary investigation target. It called
`check_kennel_machine_cost()` 135,509 times and `kennel_pin_structure()` 5,077 times in this
interval. No sampling or enablement change is made here because background auto-pin behavior is a
user-visible diagnostic contract and the capture does not show whether a Kennel consumer was open.

The following gates remain:

1. run three matched controls and three matched candidates with fixed `share_max_steps`, map, seed,
   installed artifacts, scenario, duration, and workload before accepting a performance gain;
2. remeasure lifecycle, snapshot, and command callers in those runs, then approve lifecycle batching
   only if registration and retirement remain dominant beyond run-to-run noise;
3. resolve the RuntimeStation idle-timeout/terminal-child-check interaction and obtain a formally
   passing post-change soak;
4. resolve or explicitly accept the user-owned `share_max_steps = 4` cadence difference;
5. repair or separately accept the MetaStation `atom_mounted.dm:201` initialization blocker.

The original playtest processes have exited. Its capture produced no Tracy file, contains no fixed
one-pass stress window, and has no matched repetitions. No performance-improvement claim or
lifecycle-batching implementation is justified yet.

## Updated native artifact and next-playtest readiness

Aphelion-Dogmos source revision `6cc0e6a873ad449889eaa5948fec7415db655fe4` was rebuilt with
Rust 1.98.0 for the repository's Windows and Linux target pairs. The generated ABI and protocol
remain 2 and 12. `dogmos.lock.json`, `dogmos_contract.dm`, and all four installed binaries were
updated atomically and the installed-contract verifier passed. The Windows playtest pair is:

- `dogmos.dll`: `c559b13bce828ddc0fa0b5bceb7a553234fe082f8d718d0d7c467ab6f1e07266`
- `dogmosd.exe`: `ca0728a2844dbbe80e39b0d7583a15c1e6f9430e8d322a8920fcd8d92c1e8cdf`

The native Windows suites for `dogmos-core`, `dogmos-protocol`, `dogmos-server`, and the i686
`dogmos-byond` shim passed. Focused RIFT run `20260902T121643Z-b8906690` then compiled with
DreamMaker 516.1687 and passed all 12 selected integration tests with zero runtime signatures.
The gate includes contract identity, FDM and excited-groups behavior, high-pressure equalization,
superconduction, configured multi-pass cadence, stage progress, topology, snapshot-cache, pipeline,
and active-turf coverage.

The updated native scheduler made an existing test-order defect deterministic: the excited-groups
test could enter an unbounded loop when a previous test still owned a resumable service stage. The
test now waits for a safe stage boundary, drains its prerequisite turf stage, and fails after a
bounded number of chunks instead of hanging. The cadence test now checks the configured pass count;
the current user-owned `share_max_steps = 4` setting is therefore covered rather than rejected as
an assumed single-pass configuration.

RuntimeStation soak `20260902T122318Z-2757f76d` passed its 30-second bounded window with zero
runtime signatures and continuous `dogmosd` ownership. Across six steady-window samples,
DreamDaemon peaked at 1,781,891,072 private bytes and 1,777,618,944 working-set bytes; `dogmosd`
peaked separately at 140,705,792 private bytes and 88,694,784 working-set bytes. These are readiness
observations, not evidence of improvement over the prior artifact.

The next playtest should start through `RUN_SERVER_PROFILE.cmd`, keep `share_max_steps = 4`, and use
the same map, scenario, stress timing, and capture duration as the prior candidate. Retain every
profiler snapshot and the complete round log directory. A Tracy capture is preferred; if Tracy is
not attached, the BYOND snapshots still need fixed timestamps bracketing the stress window so the
updated native revision can be compared without mixing initialization and idle time.
