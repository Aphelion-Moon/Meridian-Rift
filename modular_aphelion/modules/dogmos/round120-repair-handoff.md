# Round 120 repair checkpoint

See [the current qualification report](qualification-2026-09-08.md) for the
condensed status and evidence boundaries. This file retains the chronological
investigation and earlier checkpoints.

The final local qualification passed 623/623 full DM tests, the production
300-second soak, and all six matched performance observations. The qualified native
release is `14f0a4c2cb1a6db9a7e1685e385e0fb3d3fd7ced`, with complete installed-contract
SHA-256 `19e3b533286741e3e2c195cd1712ce4f4366a75d2b2776143530c5b978d65b1f`.

Earlier game repair commits include `4547d77217ed7ce75e0caf0a82ab00127b148f34`,
listener repair `e89389ec769648d0d1650fed42a6fdca345a5dab`, and paired-artifact
installation `ff58181486a67f5b6b43bc89130869b3848d925f`. Those earlier checkpoints
used native `0b942d58cef15be73a2f6911ef50109fc846c25b`; the final qualified pair
supersedes it. Native rebuilding and complete-pair installation are authorized.
The chronological entries below retain superseded failures and diagnostic results.
No main-server deployment or capture has occurred in this task.

## Startup and shift-start evidence

| Initialization phase | Round 118, MetaStation, control | Round 120, Ice Box, Dogmos |
| --- | ---: | ---: |
| Atoms | 22.14 s | 171.54 s |
| Atmospherics | 2.78 s | 135.68 s |
| Total | 59.45 s | 348.367 s |

These are logged initialization intervals, not process-launch-to-ready measurements.
The maps differ, so the ratio is not an isolated Dogmos effect. The operator also reports
similarly poor initialization in earlier local tests; the regression remains a repair target.
The Dogmos subsystem's own initialization was only 0.03 s in round 120. That does not include
gas registration and topology work performed later by Atoms and Atmospherics.

The early gameplay performance samples show 1,685 -> 451 -> 739 -> 1,769 -> 3,505 ->
4,698 -> 5,770 active turfs, followed by a fall to 465 and another rise. This precedes
the later fusion-canister stress sequence. It is not explained away by that stress test.
The log lacks the changing turfs' identities and reasons for reactivation. The current
DM walk checks at most 100 turfs per atmosphere cycle; native stages process a separate
frontier. Its live-list cursor can delay revisiting entries after removals, but inspection
alone does not establish the source of repeated reactivation. Settlement remains unqualified.

The `profiler-720.json` dump contains early construction work and no inspected atmosphere
stage/snapshot procedures. It cannot apportion the slow Atoms/Atmospherics phases or rank
gameplay hotspots. Do not sum inclusive procedure times or treat this as a Tracy capture.

Local full MetaStation run `20260908T023932Z-72218193` reproduced the startup problem:
352.551 seconds total, Atoms 145.55 seconds, Atmospherics 110.6 seconds, Shuttle 33.07
seconds. This used BYOND 516.1687, the old native pair, current DM repairs, the full `ci`
profile and fixed test seed 29051994. The first sampler serialized that seed with rounded
JSON precision; the harness now writes it as exact text. This is one control, not a
measured speedup. The observation case passed with natural shutdown and no runtime signatures.

During the first three minutes of empty gameplay, active turfs ranged from 30 to 3,111
(median 168); the final minute's median was 46, maximum 170. This does not reproduce the
server's persistent oscillation. The test framework creates a fixture room during gameplay;
these observations need matching test-build controls and do not establish live-server acceptance.
DreamDaemon peak private bytes were 2,690,912,256 during initialization and 3,002,462,208
during gameplay. Separately, `dogmosd` peaked at 313,090,048 and 480,145,408 bytes.
Shuttle initialization produced tens of thousands of runtime topology calls; attribution
and safe batching boundaries remain under investigation.

The diagnostic procedure-profile run `20260908T025821Z-9797bdf6` also passed its observation
case, but exposed an important deployment flaw: RIFT omits module `.dmm` files. Missing condo
templates caused preview generation to allocate 27 unnecessary reserved z-levels during
gameplay. The first-three-minute and process-memory measurements above are therefore **not
representative full-content qualification**. Repeat them after correcting the deployment.
The slow Atoms/Atmospherics phases precede the condo preview work and remain reproduced.
The user approved the two-line `tools/rift/rift.ts` correction, which now includes both
modules' `.dmm` files in isolated deployments. The missing-map regression failed before
the correction; all 93 controller/deployment tests pass on pinned Bun 1.3.5 under the host
account. An initial sandbox run failed the unrelated descendant-process observation test;
the host rerun passed it. Fresh full-content measurements are underway.

The deployment fix is committed on game `dogmos` as `1cd9af5bb01d25152782b09b61ca35f5eb09798a`.
Full-content run `20260908T055127Z-751b5c0b` verified all 28 condo maps were deployed and
reached initialization in 313.216 seconds (Atoms 152.71, Atmospherics 59.91, Shuttle 33.19).
This is diagnostic evidence only: focusing the ordinary observation test inherited its focus
flag into the profiling subtype and unexpectedly enabled procedure profiling. The sampler now
gives the ordinary parent precedence. This disables explicit diagnostic profiling only;
the later automatic-profile investigation below supersedes the original expectation
that ordinary focus would prove `procedure_profiling = 0`.

That run stopped at about 128 seconds of gameplay on an existing fake-lava/decorative-object
runtime during condo preview generation. It remained at 14 z-levels, but its active-turf count
rose to 8,649 without advancing the recorded atmosphere cycle counter. Complete three-minute
coverage and a settled-frontier result remain unproven. Do not use this failed, profiled run as
an unprofiled control. Its separate report is `full-content-diagnostic-01.json` under the local
ignored performance-qualification directory.

Fake cafe lava has zero damage values but still inherited real lava's ignition and processing
path. A narrow Meridian-owned override now skips `burn_stuff()` on that subtype. Regression
`20260908T060608Z-6595b88e` failed on fake lava changing an object's resistance/ignition/processing,
with zero runtimes and clean shutdown. The first post-fix test passed that check but exposed a
fixture error: the second sheet stack auto-merged away before the ordinary-lava check. The
fixture now reuses the surviving object. Run `20260908T062031Z-0cdc7de9` passed both lava
assertions with zero test runtimes, but failed overall during shutdown: a suspended condo
preview resumed after Dogmos stopped and attempted new gas registration/copy commands.
Intentional service shutdown now closes native admission before teardown, separately from
the failure latch, and retains that state across subsystem recovery. Late producers receive
the existing inactive-service responses; unexpected live-service loss still raises its
diagnostic. Combined run `20260908T063050Z-862055e9` passed all four shutdown/failure-latch/lava
cases with zero runtimes, exit zero, natural shutdown, and complete owned-process/workspace
cleanup. No map artwork, layout, name, or description was edited.
The lava repair is committed on game `dogmos` at `2836d8ff38464b4cf3dcede7053fd6175a5e68ab`;
shutdown admission and its regression are committed at `e1e2b2c72b69ee6ffe3f9319bab99e59372ed6fa`.

The first ordinary-focus full-content attempt, `20260908T063846Z-d6a0e1dc`, disabled the
explicit diagnostic mode and initialized in 305.858 seconds. It stopped at 64 seconds of gameplay on a
duplicate context-handler registration when a public condo door replaced an earlier turf.
The three-control batch stopped immediately; controls two and three did not run. This attempt
is archived locally as `full-content-pre-context-01`, and is not a complete control.
Inspection traced the duplicate to self-owned screentip handlers surviving `ChangeTurf()`;
the replacement must retain external signal listeners but discard its former type's handler.
Focused red run `20260908T065419Z-61344e7c` reproduced the retained self-handler without
runtime errors. Green run `20260908T070213Z-719a48ca` passed the new turf-context regression,
`connect_loc_change_turf`, and the cafe-lava regression: three passes, zero runtimes, natural
shutdown, and clean owned-process/workspace cleanup. The narrow destruction hook removes only
the turf's own context subscription; the regression verifies external subscribers survive.
The tooling build had zero errors and its two expected test warnings. This is focused
iteration evidence, not a completed full-content control or production build.
The turf-context repair is committed on game `dogmos` at
`6e56a752387d604ce59561907b84b75455791493`.

First complete ordinary-focus full-content control `20260908T072049Z-dc33f797` passed with
180.928 seconds of gameplay, zero runtimes, natural shutdown and clean process/workspace
cleanup. Initialization was 303.612 seconds: Atoms 146.05, Atmospherics 59.48, Shuttle 33.31.
Gameplay active turfs ranged from 1,943 to 10,285 (median 6,345); the final minute's median
was 9,100. The atmosphere cycle counter advanced once. This reproduces poor shift-start
progress on MetaStation, but a single control does not establish a speedup or its cause.
Its separate 250 ms process sampler attached late after a PowerShell JSON date conversion
repair: DreamDaemon's first 85.9 seconds and the service's first 59.6 seconds are not covered
by that CSV. RIFT's sparser resource observations remain available. The dense sampler then
recorded both processes through shutdown, with a maximum observed gap of 277 ms. Treat this
run's dense initialization resource coverage as partial. Repeat controls attach during compile.

The three controls with startup resource coverage are complete:

| RIFT run | Initialization | Atoms | Atmospherics | Active peak | Final-minute active median | Air cycles advanced |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `20260908T073334Z-9cd84002` | 301.391 s | 142.98 s | 57.92 s | 11,464 | 11,173.5 | 3 |
| `20260908T074504Z-d66bb5ad` | 295.856 s | 136.95 s | 60.11 s | 11,337 | 10,682 | 1 |
| `20260908T075709Z-c38e0692` | 301.391 s | 144.93 s | 59.18 s | 10,147 | 9,758 | 8 |

Mean initialization: 299.546 seconds. Each run passed RIFT, covered at least 180 seconds,
had the explicit diagnostic mode disabled, retained MetaStation/seed 29051994/native revision 8456726, had no
runtime failures or native panic log, and shut down with clean process/workspace cleanup.
The read-only sampler attached within five seconds of each process starting and recorded
separate private bytes, working set, virtual size and CPU time at approximately 250 ms.
Reports and actual sample gaps are in `data/performance-qualification/controls-summary.json`.
Local hardware was an Intel Core i7-9750H (6 cores/12 logical processors), Windows 10 build
19045, BYOND 516.1687. These are local test-build controls, not production-server timings.

Correction to the earlier unprofiled description: the master controller's lag-triggered
`AttemptProfileDump()` calls `SSprofiler.DumpFile()`, whose `PROFILE_REFRESH` starts profiling
even when AUTO_PROFILE is disabled. The controls contain growing procedure-profile dumps
through gameplay. The helper's false flag describes only its own explicit diagnostic mode;
it does not establish that profiling stayed off. The analyzer now lists automatic profile
dumps and reports profiling evidence separately from that mode. These ordinary-focus runs
remain useful default-CI observations, with automatic profile activation as an additional
comparison limitation. Do not mix them with a future verified unprofiled series.
[BYOND documents PROFILE_REFRESH as starting or continuing profiling](https://www.byond.com/docs/ref/#/world/proc/Profile).

These clean deployments rendered cold condo previews during gameplay. Both supplied server
rounds initialized Condos in 0.13 seconds and show no post-initialization condo template loads.
Therefore the cold-preview backlog cannot establish the cause of the server's oscillation.
Slow Atoms/Atmospherics precede the preview work and remain independently reproduced. All 28
generated preview-cache images were exported after control four's measured window for a later
warm-cache diagnostic. No measured DM/native inputs changed during the control series.

The first new-native candidate, `20260908T084329Z-a150c7e6`, initialized in 269.822 seconds
(Atoms 116.21, Atmospherics 59.76, Shuttle 31.69). It failed at 168.369 seconds of gameplay:
the heat stage reported `StageConflict`, specifically `publish heat after a concurrent write`.
The service failed closed and RIFT cleaned all owned processes/workspace. Dense sampling
attached about 1.3 seconds after DreamDaemon and 1.1 seconds after the service started,
with maximum gaps of 280/285 ms and no sampler errors. This incomplete failed run is excluded
from accepted candidate measurements; no startup speedup or settled-frontier result is claimed.

The native heat regression reproduced that exact conflict after a single bounded yield.
Native commit `7b4fbabd61b65fae4f3fd978b7607572af6de509` retries the unpublished heat attempt on the next bounded request, retaining
the same frontier/stage identity and elapsed interval. It follows diffusion's existing retry
behavior. Ten focused heat cases pass, including writes at every yield point, repeated writes,
atomic temperatures/events, mole/energy conservation, and cancellation/identity/backpressure
fences. Full pinned Windows tests pass (457 i686 workspace, two ignored doctests; 314 x64
core/service/protocol), as do Linux x64 tests (314) and i686 shim tests (44). Strict Clippy
passes on Windows and Linux, and both supported 12-configuration feature matrices pass.
All four `7b4fbab` release targets, both 12-feature matrices and packaged Windows/Linux
cross-bit probes passed. Its complete pair is installed and verified in the development
workspace only. It has not passed the live DM gate: `20260908T092853Z-e8d22b4d` and the
instrumented rerun `20260908T094345Z-47fa2c32` each passed seven of eight focused cases,
with `dogmos_superconduction_golden` failing because its hot turf never cooled. Both
runs reported zero runtime signatures and clean owned-process/workspace cleanup.

The rerun's `dogmos-superconduction-progress.json` records the unchanged assertion window:
SSair first remained in machinery processing while adjacency queues repeatedly refilled,
then remained in diffusion until the window ended. Heat was not reached. Most sampled
SSair allocations were below one percent of a tick; the native helper currently declines
work below one millisecond. Template-border IPC batching and fractional-budget progress
are under investigation. The direct heat-conduction test passes, but that does not qualify
live scheduling. Production boot, full suite and matched candidate measurements for this
pair remain outstanding.

The focused baseline `20260908T095600Z-3e77524f` independently reproduced both DM
performance defects with no runtimes: a real 25-turf template finalization used 696
topology IPC calls, and a positive 0.25 ms budget was refused. The existing zero/negative
budget test passed. The template fixture's gas, heat, mixture identity and reciprocal
adjacency checks passed before its call-count assertion failed. A prior compile attempt
failed because this module precedes the `TEST_ASSERT` definition; it was corrected to the
module's existing `Fail` convention before collecting the baseline.

The development patch batches only the synchronous template border loop, preserving
wire bounds, outer batch ownership and frozen-frontier deferral. Positive fractional
budgets now receive proportionally bounded native work; zero/negative budgets still
defer. The configured FDM pass count, timestep and per-request maximum are unchanged.
Focused DM qualification is in progress; these changes are not yet performance-accepted.

Run `20260908T100445Z-25f06c78` passed both template batching cases and seven other cases,
but failed live heat progress and an incorrectly scoped conservation assertion. The latter
counted only the seeded pair although diffusion also reached passive neighbors. After
counting oxygen across the sealed 25-turf room, the fractional-budget case passed in
`20260908T101440Z-7d3f0a6f`; the template case also passed. That run independently reproduced
another scheduling defect: a pending native stage returned with 99.8776 ms of its 100 ms
allocation unused. Both runs had zero runtime signatures and clean cleanup.

The stage helper now continues bounded requests until completion or exhaustion of the
original allocation, including frontier publication time. Run `20260908T102422Z-868c0e72`
observed live heat transfer within the existing assertion window: after 5.5 world seconds,
the pair reached 689.081 K and 302.312 K from 700 K and 293.15 K. This is not a passing
gate: a later deferred topology drain raised `TurfMissingMixture` for its source turf,
and RIFT stopped the run before a complete test-result artifact was written. Cleanup
passed; shutdown was requested by the controller, not natural. Inspection found the
retry refreshes neighboring registrations but can emit edges from a source whose gas
datum appeared after heat-only registration. A separate late-air regression is being
run before repairing that path. No current pair or scheduling performance acceptance
is claimed.

The late-air regression failed as intended in `20260908T103407Z-4b6891cd`, with zero
runtimes, natural shutdown and clean cleanup. Both fractional-budget conservation and
remaining-budget progress passed in that run. The development patch now refreshes a
stale source registration before constructing adjacency records, after the frontier
deferral guard. Combined run `20260908T104137Z-4d730667` passed 15 of 16 cases with zero
runtimes and clean cleanup. The late-air regression, both budget regressions, conservation,
FDM cadence and topology/failure guards passed. The real template border used two topology
calls, compared with the baseline's 696. The live heat case still missed its deadline:
machinery/adjacency occupied the first four world seconds, then diffusion, reactions,
groups and equalization advanced; heat was pending at the final sample. Its small positive
allocations remained around 0.15-0.35 ms. Focused-test-only stage timing aggregates have
been added for the next diagnostic; production builds omit them. No time-budget policy
or physical coefficients have been changed beyond the already recorded continuation loop.

Native reaction-publication repair `14f0a4c2cb1a6db9a7e1685e385e0fb3d3fd7ced` is committed
on native `dogmos`. Like the heat repair, it discards unpublished work invalidated by
accepted gameplay writes and retries within the same stage identity; it preserves live
DM continuations and prevents duplicate events or reusable tokens. Four new regressions
cover retries, cancellation, existing continuations and exact state/event equivalence
with a reference that starts after the accepted write. Pinned Rust 1.98.0 gates passed:
Windows i686 workspace 461 tests (two ignored doctests), Windows x64 core/server/protocol
318, Linux x64 including perf 331, Linux i686 shim 44, strict Clippy for all four scopes,
formatting, dependency direction and both 12-configuration feature matrices. All four
release targets, generated bindings and complete manifest passed verification. Packaged
Windows/Linux cross-bit probes each passed 1,030 continuation cycles and five intentional
stale-token rejections without pending work. The first Linux probe was compiled without
its required identity; rebuilding that probe with the exact source/fingerprint resolved
`Missing(SourceRevision)`. The complete pair is installed and verified in the development
workspace; the main game checkout retains `0b942d5`.

Run `20260908T110045Z-57189019` stopped during Dogmos initialization: the packaged Windows
shim lacked its compile-time source identity. Manifest/hash checks and a rebuilt IPC probe
did not detect this, because that probe did not load the packaged DLL. No unit-test or
performance result was produced; cleanup passed. All four release targets were rebuilt
with identity variables set in the same process as each Cargo invocation. The corrected
bundle is `target/reaction-retry-release/14f0a4c-identity-fixed` in the native repository;
the failed bundle is retained separately. Both packaged IPC probes and contract checks
passed again. A tiny, isolated BYOND fixture then called the actual DLL metadata exports:
the earlier DLL returned null identities, while the corrected DLL returned the exact
revision and fingerprint with no runtime errors. This is metadata-load evidence only.
The corrected Windows DLL SHA-256 is
`ccfeb8673bc71d9bfec76bb08cfce2384369bc9185dee0a7837dfc3e9af313f9`.
The complete corrected pair is synchronized and verified in the development workspace.
Run `20260908T111205Z-4b8565e4` passed all 16 focused cases, with zero runtime
signatures, natural DreamDaemon shutdown and clean cleanup. This includes the template
border, late-air registration, fractional-budget conservation, remaining-budget use,
FDM cadence, topology barriers, failure handling and live heat regressions. The live
heat pair changed only on its twentieth and final sample, so this is a correctness
checkpoint rather than satisfactory performance.

The opt-in stage aggregates recorded 20,164 requests for 183,584 requested work items
during that heat observation. Each stage averaged about nine items per request and
0.09-0.12 ms per RPC, with mean available allocations around 0.37 ms. The fixed
10 ms scaling denominator rarely uses the existing 256-item maximum. This supports
investigating request amortization; it does not establish an accepted speedup or a
safe replacement policy. Native request deadlines currently cancel work rather than
yielding a resumable slice, so lowering transport deadlines is not a scheduling fix.

Architectural candidates remain under investigation:

- Amortize stage requests within the existing work cap. A measured per-stage cost
  estimate could replace the fixed scaling denominator without changing the wire
  contract. It predicts cost, however, and cannot guarantee a wall-time bound for
  unusually expensive publication work. A separate native cooperative execution
  budget would give more direct control, provided normal yields preserve tentative
  state and transport cancellation retains its existing failure semantics.
- Make retirement progress independent of the current small maintenance sample.
  `walk_active_turfs_batch()` examines at most 100 entries once per complete SSair
  cycle. Its pre-removal cursor can skip entries shifted by removals. A fair, resumable
  walk or native retirement candidates must preserve exposure, hotspot, immutable
  boundary and reactivation behavior; changing atmosphere coefficients is unnecessary.
- Batch startup mixture creation and seeded state at real ownership boundaries.
  The existing single-mixture registration path gives constructors immediate native
  read/write semantics. Any batching design must flush before the first dependent
  read or mutation, reject the whole failed publication appropriately, and preserve
  generation-safe non-owning references. A second mutable gas model in DM would add
  coherence risk and is not proposed.

These are design alternatives, not implemented or measured improvements. Prioritize
the request overhead and retirement backlog before committing to a larger protocol
or startup ownership change.

The diffusion cache regression failed as intended in `20260908T114133Z-4e2142e8`:
a real pending native chunk discarded a warm authoritative snapshot. Conservation and
FDM cadence controls passed, with no runtimes and clean natural shutdown. The earlier
`20260908T113746Z-8c61e262` attempt stopped on duplicate exception-variable declarations
in the new fixture; it was a compiler failure, not the behavioral RED.

Diffusion now preserves cached snapshots while pending and invalidates after actual
publication. Other stages retain conservative invalidation. All 17 focused cases
passed in `20260908T114851Z-ece300e0`, with zero runtimes, natural shutdown and clean
cleanup. Heat still changed only on sample 20. Its diagnostic recorded 20,994 native
requests; the largest RPC was 7.4322 ms. This establishes the cache repair but leaves
request amortization as the next performance experiment.

A per-stage cost estimator was tested and rejected. Its policy regression first
failed under the fixed mapping in `20260908T115706Z-a5bc4afb` (12 items remained 12
after a cheap-work observation). The implementation passed that policy regression but
failed live heat in `20260908T120451Z-a9aa34cb`: 17 of 18 cases passed, zero runtimes,
natural shutdown and clean cleanup. Average requested diffusion work fell to 4.75
items; groups averaged 3.14 and were still pending at the heat deadline. Charging
full request overhead per executed work item produces overly conservative feedback
on small responses. The estimator and its synthetic policy test have been removed
from the candidate source; ignored diagnostic copies retain the failed experiment.
The fixed 10 ms mapping passed all 17 cases in `20260908T121431Z-08fb19a4`, with
zero runtimes, natural shutdown and clean cleanup. Its opt-in executed-work counters
showed diffusion completing 29,324 of 29,359 requested items across 3,335 calls;
heat completed all 26,971 requested items across 2,937 calls. Groups and equalize
each had 1,895 short responses. Heat changed on sample 17. The next unqualified
experiment changes only the fixed budget denominator from 10 ms to 1 ms, retaining
the 256-item cap, remaining-budget checks and unchanged physics timestep/pass count.

The user supplied a fresh local no-Dogmos mirror at revision
`6786e9279186b18125176eb0f4f139aed36fc12a`. Its BYOND/Bun pins, MetaStation and
RuntimeStation map inputs, and CI configuration match this branch. The shared ancestor
is `b608d84c59ddbb462a7fad3311aca753a25975f0`; the mirror additionally contains the
Symphony integration and a changelog compile. Preserve that source difference in the
comparison report. A shared external observation helper runs both repositories on
this hardware without modifying either repository's protected build scripts. The
first no-Dogmos full-CI MetaStation run, `20260908T122715Z-9707b700`, compiled and
recorded initialization in 131.994 seconds (Atoms 59.25, Atmospherics 7.11, Shuttle
3.67). The shared observer began before atoms, and the 250 ms process sampler attached
0.996 seconds after DreamDaemon started. Its runtime data and condo-preview cache
started empty; dependency caches retained the same pinned tools. Automatic procedure
profile dumps were present. This run failed about eight seconds into gameplay on
`compare(null, 1)` / `Cannot read null.moles_archive` at lunar surface turfs on z=13;
RIFT stopped it and cleaned up. Its complete startup measurement is retained, but it
is not a passing three-minute gameplay baseline. The mirror remains unmodified.

The 1 ms batching experiment passed the same 17 focused cases as the fixed 10 ms
control in `20260908T123414Z-b7566494`, with zero runtimes, natural shutdown and
clean cleanup. Diffusion executed 59,112 items in 762 requests, and heat executed
26,672 in 334. The hot/cold result was again 689.081/302.312 K, observed on sample
11. These are diagnostic counts, not an accepted speedup: there were no recorded
equalizer requests. Source inspection found that an exhausted first entry budget
can leave the equalizer unstarted with `dogmos_pending_stage = null`; its resumed
entry then skips the native stage. An explicit completion-state repair and real
entrypoint regression are being qualified before accepting the batching change.

The maintenance walk also advances its cursor using a pre-removal list index.
Removing a settled entry shifts the next unprocessed entry left, so the following
batch skips it until a wrap. A separate regression checks actual exposure of that
shifted entry, preserving the 100-entry bound. It failed as intended with zero
per-case runtimes in `20260908T124804Z-9fc78478`; the immutable-boundary wake case
passed. The equalizer fixture in that run failed on its own unguarded read of the
not-yet-existing completion field, so it did not establish the intended RED.
That fixture guard is corrected. Run `20260908T125511Z-6477482e` recorded the intended
equalizer skip failure with zero runtimes; cursor and immutable-boundary tests passed.
It shut down naturally and cleaned up. The equalizer now retains an explicit completion
flag across pressure-drain resumes, copied by recovery and cleared on failure. The
cursor counts actual removals immediately around removal, excluding neighbor appends.
Run `20260908T130323Z-992f0cec` passed all 24 cases with zero runtimes, natural
shutdown and clean cleanup, including recovery/failure restoration, a real
pressure-queue pause/non-repeat check, and a cursor fixture that wakes an initially
inactive neighbor outside its original queue. Its heat diagnostic includes all five
native stages, including 2,406 equalizer requests; heat remained numerically
689.081/302.312 K. Timing is not comparable with the earlier 17-case run because
the expanded set includes the live recovery test before heat.

Full-CI MetaStation candidate `20260908T131046Z-eda43f93` completed the same shared
observer as the no-Dogmos startup, with the 1 ms batching denominator, both scheduler
repairs, the earlier cache/topology repairs and the corrected native `14f0a4c` pair.
It passed its 180.791-second observation with zero runtime signatures, natural shutdown
and clean cleanup. Initialization was 251.837 seconds (Atoms 104.2, Atmospherics 60.32,
Shuttle 25.27), versus the local mirror's 131.994-second startup. The last-minute
active median was 9,679, maximum 9,978, with 11 observed atmosphere cycles. It has
not settled and a single candidate does not establish a performance improvement.
Automatic profile dumps 50/90 show profiling was active during part of this run.
Dense sampling attached 1.253 seconds after DreamDaemon launch, with maximum gap
280 ms and no sampler errors. DreamDaemon private peaks were 2,708,803,584 bytes
during initialization and 2,872,356,864 during gameplay; service peaks were
287,367,168 and 366,493,696 bytes respectively. The processes remain separate.
Report: `data/performance-qualification/shared-dogmos-meta-01.json`.
An earlier attempt, `20260908T124344Z-d4dc5088`, failed compilation on a test-local
constant name and provides no runtime evidence.

The full-cycle maintenance repair is now under focused qualification. Its real
121-turf regression failed before the repair in `20260908T133440Z-6f55295c`: a
completed active phase exposed only 100 of 121 initial turfs. The case recorded zero
runtimes, natural shutdown and clean cleanup. An earlier sandbox launch
`20260908T132723Z-20d4a574` stalled before compiler work and its verified compiler
was stopped; cleanup passed. `20260908T133133Z-24de4890` caught two out-of-scope
assertion macros in the new modular fixture. Neither earlier attempt is runtime
regression evidence.

The candidate retains a fixed initial active snapshot, walks it in bounded chunks
with per-turf budget checks, publishes the resulting frontier, then retains the
snapshot through native stages and a resumable settlement/visual pass. Newly awakened
entries join the live frontier but receive exposure on the next cycle. The native
frontier remains frozen through the later equalization and heat stages; retirement
affects the next publication and does not unregister heat state. The 121-turf fixture
forces a pause after its first exposure and requires exactly one exposure per initial
turf, no early publication, and cleanup of the completed snapshot. Run
`20260908T134833Z-668085a8` passed traversal, removal, space-boundary and bloat cases,
and reproduced the separate recovery failure. Zero runtimes, natural shutdown and clean
cleanup apply to that earlier pre-reaction retirement implementation.

SSair recovery previously omitted `currentpart` and `times_fired`; the Master resets
scheduling state and may call the replacement's first `fire(FALSE)`. Recovery now
retains the phase, cycle, cursors and a one-shot resume latch without copying scheduler
queue ownership. The real fire-dispatch regression passed in
`20260908T140119Z-f92356fa`, alongside full traversal. That run also reproduced two
new correctness failures: matching hot plasma retired before native reaction evaluation,
and a failure callback clearing the snapshot caused a caught out-of-bounds read. It
recorded two passes, two expected failures, zero runtimes, natural shutdown and clean
cleanup.

The current source delays retirement until native reactions and all callback
continuations have drained. Successful reactions retain their turf through the next
cycle even when neighboring mixtures match, including volatile DM effects. A nonempty
general callback batch requires a subsequent observed-empty drain because resuming a
DM reaction can enqueue more callbacks. Exposure and visual work stop when the service
fails; local snapshot references avoid indexing a cleared replacement list. The new
uniform-gas regression compares actual native-stage plasma combustion and two cycles of
continued BZ formation with direct reactions. The failure fixture permits restoration
only after proving accepted native epochs, frontier, stage samples and callback counts
unchanged.

Expanded focused run `20260908T142110Z-912ab462` recorded 26 passes and three failures:
the natural recovery-cycle deadline, live heat deadline, and plasma reference parity.
The direct 121-turf traversal, two-cycle BZ continuation, recovery dispatch and failure
fence passed. The run then encountered 35 undefined-`air` runtimes when a retained
snapshot included a reserved turf replaced by `/turf/cordon`; RIFT requested termination
and cleanup passed. This was not a clean or naturally completed run.

Two continuation problems were repaired after that run. Both walk and visual passes
were prefetching a new shifted 100-entry window on every short-budget resume. They now
retain the prefetched end, including when the prefetch itself exhausts the budget, and
resume without refetching that window. Recovery copies both ends, and completion/failure
clears them. Snapshot and neighbor prefetch also checks the current open-turf type before
accessing `air`. Live diagnostics now include walk/visual cursors to distinguish slow
progress from a lost continuation. The snapshot cache is 2,048 buckets; it was not resized.

The plasma reference used `react(null)`, omitting the extra reaction performed immediately
by a new hotspot. Its reference now uses a real fixture turf and copies gas after the
same hotspot initialization; fixture cleanup suppresses both reaction and fire-group
event histories and restores gas, result caches and visuals. Run
`20260908T143800Z-ab314c3f` compiled with zero errors and the two expected test warnings;
29 of 30 cases passed with zero runtimes, natural shutdown and clean cleanup. Recovery's
natural-cycle check and both real-holder reaction references passed. The heat test failed
its setup assertion before temperature seeding: its wait accepted a topology flush while
22 adjacency rebuilds were still queued. The wait now requires that queue to be empty
before accepting the flush. Seven-case run `20260908T144606Z-2d21a716` passed all seven
cases with zero runtime signatures, natural shutdown and clean owned-process cleanup.
This includes recovery, traversal, reactions, the failure fence and closed snapshots.
The traversal check proves an untouched cached snapshot survives the second forced
exposure pause; prefetch does not increment the ordinary cache-hit counter.

The first shared-observer full-CI MetaStation comparison of this traversal repair,
`20260908T145356Z-a1721858`, completed 180.15 seconds with zero runtime signatures,
natural shutdown and clean cleanup. Its final-minute active count was median 80,
range 44-304, with 113 observed air cycles. The preceding matched-observer run had
median 9,679 and 11 cycles. This is exploratory single-run settling evidence, not a
repeated speedup qualification. Startup remains slow: 266.594 seconds total, Atoms
115.28 and Atmospherics 60.69. Dense sampling measured DreamDaemon gameplay private
peak 2,864,898,048 bytes and virtual peak 3,060,744,192 bytes; the separate service
private peak was 425,017,344 bytes. Sampling had no errors, but one initialization
DreamDaemon interval reached 977 ms. Complete correctness and repeated performance
gates remain outstanding.

### Startup snapshot and mixture identity repair in progress

Run `20260908T152109Z-a42895ae` compiled with zero errors and two expected test
warnings, then reproduced three intended failures with zero runtime signatures,
natural shutdown and clean cleanup: the missing own-mixture startup prefetch,
eager gas-mixture weak-reference creation, and recovery losing pending mixture
unregistrations. The cache test's global counters included unrelated readers during
`CHECK_TICK`; its bounded measurement now runs synchronously to isolate those counts.
Earlier fixture attempts are not optimization evidence: `150815Z-ba8ba995` failed
its adjacency selection; `151548Z-fd57b5c3` was cancelled after discovering an `in` /
`&&` precedence error. Host inspection confirmed its processes exited, but cancellation
did not write a normal controller summary. The fixture now builds real adjacency,
chooses a reciprocal pair, and explicitly groups both membership checks.

The `145356Z-a1721858` automatic profile includes 75,534 mixture registrations:
42.407 seconds inclusive, with 35.203 in finalization and 34.987 in `WEAKREF`.
The 78,599 lifecycle IPC calls total 6.842 seconds. These are captured-profile costs,
not an isolated startup speedup, but they prioritize identity work over preallocating
unused native mixtures.

The candidate replaces eager mixture weak references with an opaque empty-list token
shared by the mixture and slot registry. The token has no backlink and cannot retain
the mixture. General reaction events resolve their existing turf target and validate
its current air against the exact mixture slot, generation and token. Direct reaction
events validate their already-held expected mixture. `Del()` retains its native
unregistration path, including deferral behind a committed frontier. Recovery now
preserves that pending-unregistration queue. Native protocol and gas math are unchanged.
No datum tags or strong mixture registry references are introduced.

Startup initialization now prefetches each bounded window's own mixtures immediately
before `Initalize_Atmos`, preserving order, difference-check entries and negative cycle
stamps. Thirteen-case run `20260908T153024Z-2fe0cc85` passed all 13 cases with zero runtime
signatures, natural shutdown and clean cleanup. It covers GC, reuse, foreign identity,
stale turf/air callbacks, reaction continuations, recovery, traversal and heat. The
121-turf startup fixture measured 121 cold control reads and zero candidate misses,
with identical gas, visuals, adjacency and order. This is focused correctness and
batching evidence; matched full-map performance qualification remains outstanding.

Full-CI MetaStation run `20260908T153758Z-92725404` completed 180.981 gameplay seconds,
with zero runtime signatures, natural shutdown and clean cleanup. Initialization was
206.613 seconds (Atoms 70.8, Atmospherics 49.92, Shuttle 24.23), compared with 266.594
in the preceding traversal-only run. This remains a single-run result. The final-minute
active count was median 94.5, range 44-9,970, with 97 observed air cycles. The high
sample occurred at 120.17 seconds during the first cycle's settlement; counts fell to
172 by 122.17 seconds. SSair remained in its first phase for about 115 seconds before
that, with adjacency work recorded. Further queue diagnostics are needed to identify
that delay. Dense DreamDaemon private peaks were 2,680,020,992 bytes during startup and
2,884,034,560 during gameplay; gameplay virtual peak was 3,080,929,280 bytes. Separate
service private peaks were 273,387,520 and 479,854,592 bytes. Sampling attached to
DreamDaemon after 1.206 seconds, recorded 1,647 DD and 1,507 service samples with no
errors, and maximum gaps of 278/279 ms. No footprint reduction is established.

Repeat `20260908T155210Z-e9de7cb0` completed 180.756 seconds, zero runtime signatures,
natural shutdown and clean cleanup. Initialization was 224.587 seconds: Atoms 83.38,
Atmospherics 51.46, Shuttle 24.86. Final-minute active counts were median 42, range
0-228, with 115 observed cycles. Added observer queue lengths show 6,055 adjacency
entries and 57 pipe rebuild entries at first gameplay, before the unit-test room
loads. SSair first reached its machinery phase at 88.64 seconds after clearing both
queues. The lazy test room contains only 25 open turfs and an 81-turf border refresh;
it is a workload confound, but cannot explain the pre-existing startup backlog.
The production source and native pair match the preceding run; the observer added
only four queue-length fields. Timing noise remains material, and three matched
controls/candidates have not yet been completed for this revision.

### Runtime adjacency construction coalescing in progress

The initial backlog investigation found that runtime batching coalesced wire records,
but still rebuilt the same turf's adjacency each time a neighboring turf notified it.
`20260908T160337Z-c204e2af` reproduced 50 construction passes for 50 notifications,
with only two native batch calls. The intended regression failed with zero runtimes,
natural shutdown and clean cleanup. Its gas identity/state checks also ran.

The candidate extends the existing deferred-retry path to runtime topology batches.
Each batch retains unique touched turfs and rebuilds their final adjacency at its
existing flush. Registration, pending heat reads, stage barriers and the native
protocol remain unchanged. The regression now guards setup and restoration, aborting
the test suite if the service cannot accept cleanup. The first qualification attempt,
`20260908T161020Z-a8626274`, stopped at compilation due to a duplicate catch variable
in that test cleanup; it was renamed. `161441Z-e9ccaac5` failed preflight with a Windows
PowerShell process-cleanup error. Host inspection found no surviving compiler, game,
service or Bun process. Corrected run `161546Z-8da7cc3d` passed 17 of 18 cases with
zero runtimes, natural shutdown and clean cleanup. The coalescing fixture measured
one construction pass for 50 notifications, with unchanged gas identity/state and
two native calls. Flow, pressure, heat, recovery, frontier and identity cases passed.
The remaining ownership test assumed pending work was already encoded as edges.
It now accepts retained turf work and verifies that closing the owner publishes and
drains both gas and heat topology. The neighbor-state test explicitly executes its
deferred retry before inspecting registration, avoiding a vacuous early-return pass.
Those two checks and the coalescing regression passed in `162314Z-bf0ad175`: 3/3,
zero runtimes, natural shutdown and clean cleanup; compilation had zero errors and
two expected test-build warnings. This closes the focused ownership gap without
claiming a combined 18/18 run. Production boot `20260908T163006Z-c6ba1fa7`
then completed the full RuntimeStation build with zero errors and warnings, verified
the native contract, reached initialization without runtime signatures, and stopped
through the controller with clean process cleanup (`ready_then_stopped`, exit 0).
This is boot evidence, not natural gameplay shutdown or performance qualification.
Full-map measurement `20260908T163630Z-c9fa1e9c` completed 181.012 seconds of
gameplay, passed with zero runtimes, and shut down naturally with clean cleanup.
Initialization was 220.475 seconds (Atoms 77.17, Atmospherics 57.05, Shuttle 23.53).
The initial adjacency/pipe queues were 6,430/57; both first reached zero at 82.419
seconds, and the air-cycle counter first advanced at 100.694 seconds. The final
minute had median 102.5 active turfs, range 2–458, p95 383. These single-run values
do not establish a speedup over the prior candidate. Dense DreamDaemon peaks were
2,691,907,584 private / 2,893,234,176 virtual bytes during initialization and
2,854,031,360 private / 3,050,725,376 virtual bytes during gameplay; sampled CPU was
219.594 / 134.5 seconds respectively. Service private peaks were separately
468,967,424 / 438,284,288 bytes. Sampling had no reported errors, but one gameplay
gap approached 1.96 seconds; initialization gaps remained below 278 ms.

### Narrow shuttle atmosphere batch in progress

The startup profile attributed substantial time to `onShuttleMove`. Its two immediate
blocked-turf updates ran outside a runtime batch. Actual movement regression
`20260908T165006Z-90249a4b` measured 18 and 10 topology calls inside those two updates.
The intended cost assertion failed; intermediate callbacks observed source/destination
blocking in order and unchanged source oxygen, and the final signal saw copied gas.
The run had zero runtimes, natural shutdown and clean cleanup.

The candidate replaces only those four statements with a Meridian-owned synchronous
helper. It preserves destination-then-source blocking, per-turf adjacency signals and
liquid updates, restores the previous runtime batch owner even on an exception, and
uses the existing flush/frontier rules. `CopyOnTop`, the final gas copy and the shuttle
movement signal remain outside. Firedoor gas reads and `COPY_FROM` address mixture
handles directly; they do not require published turf lifecycle or adjacency state.
The regression now checks notification indexes and adds an outer-owner case, and
explicitly recalculates restored fixture adjacency before the normal test runner resets
room gas/temperature. Focused qualification `20260908T165803Z-b5a7c03a` passed all
11 cases with zero runtimes, natural DreamDaemon shutdown and clean cleanup. Both
shuttle cases measured `[0,0]` topology calls inside the updates, retained ordered
`[open,blocked]` then `[blocked,blocked]` observations, and preserved oxygen at 17.
The final signal observed the expected standalone/outer owner state. Gas, heat,
recovery and topology-barrier cases passed. Compilation had zero errors and the two
expected test-build warnings. Shuttle initialization was 9.9 seconds versus 17.83 in
the red run; this focused-map observation is not a full-map performance claim.
Production boot `20260908T170448Z-f5e20b5e` passed its full RuntimeStation build
with zero errors and warnings, verified the native pair, reached initialization with
zero runtime signatures, and stopped through RIFT with clean process cleanup
(`ready_then_stopped`, exit 0). Initialization was 138.4 seconds: Atoms 49.01,
Atmospherics 35.49, Shuttle 13.03. This production boot has different configuration
and map from the full MetaStation test observations. Frozen full-map candidate
`20260908T171115Z-5d07de3f` passed 180.425 seconds of gameplay with zero runtimes,
natural shutdown and clean cleanup. Initialization was 217.894 seconds: Atoms 83.31,
Atmospherics 52.67, Shuttle 13.43. Initial adjacency/pipe queues were 5,952/57; both
first emptied at 68.788 seconds, and the air-cycle counter advanced at 91.775 seconds.
The final minute had median 61 active turfs, range 43–223, p95 215; 126 air cycles
were observed. Dense DreamDaemon private/virtual peaks were 2,690,560,000 /
2,877,554,688 bytes during initialization and 2,850,267,136 / 3,048,439,808 during
gameplay, with sampled CPU 210.109 / 134.031 seconds. Separately, service private
peaks were 361,484,288 / 441,483,264 bytes. Sampling reported no errors; maximum
gaps were 443 ms for DreamDaemon and 312 ms for the service. This is the first frozen
candidate, not a completed repeated comparison. Preserved full-walk control
`20260908T172224Z-c9a3ca03` passed 180.512 seconds with the same native pair and
observer, zero runtime signatures, natural DreamDaemon shutdown and clean process
cleanup. Initialization was 268.056 seconds (Atoms 117.61, Atmospherics 62.59,
Shuttle 25.26). First air-cycle progress was 130.731 seconds; 89 cycles completed.
Final-minute active turfs were median 137, range 44–10,176, p95 5,530. Dense
DreamDaemon private/virtual peaks were 2,698,022,912/2,920,112,128 bytes during
initialization and 2,866,671,616/3,094,253,568 during gameplay. Its sampled CPU
was 259.109375/136.796875 seconds respectively. The separate service private
peaks were 469,012,480/442,134,528 bytes. Sampling reported no errors and gaps
below 286 ms. The control wrapper initially failed to restore a source file
because Windows held a transient mapped-file lock; all six candidate hashes
were subsequently restored and verified before the next run. This was a
post-run local restoration failure, not a game or controller failure. The
second candidate, `20260908T173404Z-3fa35ca9`, passed 180.663 seconds with zero
runtime signatures, natural shutdown and clean cleanup. Initialization was
215.694 seconds, including Atoms 80.46 seconds. Its queues first cleared at
80.0437 seconds and first air-cycle progress occurred at 104.456 seconds;
111 cycles completed. Final-minute active turfs were median 104, range 10–319,
p95 231. Its six live source hashes and common inputs were recorded during
compilation and verified again afterward.

Review then identified missing exception restoration of the global batching
flag in the template-border and adjacency-retry helpers. The focused regression
`20260908T174735Z-38092a56` failed on the retry ownership leak with zero runtimes,
natural shutdown and clean cleanup. Both helpers now restore the prior flag
before rethrowing the original exception. The unchanged regression and ten
related cases passed in `20260908T175430Z-ff52e380`: 11/11, zero runtime
signatures, natural DreamDaemon exit and clean cleanup. Coverage includes
template and shuttle outer ownership, runtime coalescing, native lifecycle,
stage/topology failure latches, intentional shutdown, rejected stage responses,
and SSair recovery. Compilation had zero errors and the two expected test-build
warnings. The two observations above therefore describe the pre-guard candidate. A separate
suggestion to include sleeping/pausing recovery states was retracted after
checking actual scheduler state assignments; no recovery edit is warranted.

The native test summary recorded its pre-commit HEAD, whereas the packaged
Windows/Linux IPC probes identify the current `14f0a4c` release. A fresh native
test refresh at clean committed `14f0a4c` passed with Rust/Cargo 1.98.0:
461 i686 Windows workspace tests (two ignored), 318 x64 Windows
core/server/protocol tests, 331 x64 Linux core/server/protocol/performance tests,
and 44 i686 Linux shim tests. All four commands used `--locked --offline` and
exited zero; source remained clean. The four Windows control-plane cases
passed, including authenticated-client disconnect, executable digest rejection,
duplicate/decreasing request rejection, and handshake/shutdown. This module is
gated to i686 and launches its Cargo-built service; it is separate from the
packaged x86-to-x64 IPC probe. An x64 Cargo result with zero tests is not evidence
for these cases. Logs use the native `target/committed-14f0a4c-` prefix.

Production run `20260908T180519Z-e0100177` passed its full RuntimeStation build
with zero errors/warnings and the complete installed native contract. Logged
initialization was 136.525 seconds: Atoms 48.07, Atmospherics 35.70, Shuttle
13.19. The controller observed readiness at 18:10:54.008 UTC and completed
the 300-second soak at 18:15:56.709 UTC with zero runtime signatures and clean
owned-process cleanup. DreamDaemon termination is recorded as `idle_timeout`
(exit 143), not natural shutdown. This is a bounded availability/production
boot gate, not a populated-gameplay timing comparison. Sparse private-byte
peaks were 1,897,852,928 for DreamDaemon and 135,823,360 for the separate service.

The first unfocused full MetaStation DM suite, `20260908T181633Z-df8ca273`,
used `--profile ci --minimum-tests 500`, the complete current pair, a 900-second
readiness bound and 3,600-second wall bound. All six guarded source hashes were
verified during compilation. It logged 136 passes, then reached the default
300-second output-idle timeout inside `dogmos_del_cost`, which performs 2,000
gas-mixture deletions and 2,000 plain-datum deletions under reference tracking.
DreamDaemon remained CPU-active with broadly steady memory. No assertion or
runtime error was reported, no final test inventory was produced, and controller
cleanup passed. This is an incomplete timed-out suite, not a pass. The unchanged
suite is being retried with the supported `--idle-timeout-seconds 900`, retaining
the one-hour wall bound. The separate 250 ms process sampler uses a 4,500-second
bound. Full-suite acceptance depends on the final inventory, runtime records
and cleanup; it is not established by the focused passes above.

The full-suite initialization interval (335.038 seconds in the first attempt)
is not comparable to the focused observer. `PERFORM_ALL_TESTS(maptest_log_mapping)`
in `code/modules/mapping/ruins.dm` sets ruin cost to zero and forces eligible
ruins to load when no test is focused. The full run loaded 46/49 lava ruins
and 113/113 space ruins, versus 32/49 and 19/113 in observer run `173404`.
Unfocused mode also enables DCS list-argument collection. The larger generated
world and extra test instrumentation are concrete input differences; the full
suite is a correctness gate, not another matched timing sample.

### Current published CI and listener repair

The published PR still points to `e2845174ee1dfb077e7c31e2750025d32cea24f4`. Its current
CI suite `34173336083` passes the inspected station integration jobs except SerenityStation.
Job `101898390984` reports one old-gibs hard delete; the reference search finds the decal in
a lava-land turf's `_listen_lookup[atom_entered]`. The codeowner job separately fails its
reviewer-request API call with `Resource not accessible by integration`; no workflow or
repository permission setting was changed.

Focused red run `20260908T081157Z-2754d127` reproduced deletion during replacement
construction followed by restoration of the obsolete subscription (`deleted=1, retained=1`).
It had zero runtimes and clean cleanup. On the newly installed native pair, the other six
cases passed: service lifecycle, excited groups, deferred mixture retirement, intentional
shutdown, own turf context replacement, and existing connect-loc turf replacement.
The restoration helper now filters deleted subscribers and preserves live subscriptions,
including the single-listener representation after filtering a shared bucket. Its extended
regression checks delivery to a surviving listener. The first green attempt stopped at a
missing datum annotation during compilation. After correction, green run
`20260908T082525Z-af41e258` passed all eight requested cases, including the cafe-lava regression:
zero runtimes, natural shutdown and clean owned-process/workspace cleanup. The tooling compile
had zero errors and two expected test warnings. DMB SHA-256:
`dc5862c3d2b0ab098b7fab5b3f95b14a4fc60d7bf425730de28905bdda849615`.
This is focused native/DM integration evidence; full-suite and matched candidate performance
remain separate gates.

Production full-build/native-load boot `20260908T083549Z-5a927b79` rebuilt with zero compiler
errors and warnings. Full RuntimeStation initialized in 184.291 seconds with no detected
runtime signatures; its map logged four missing-arrivals-shuttle warnings. RIFT requested
termination after the observation window (DreamDaemon exit 143) and confirmed no owned
process/workspace leftovers. This is successful boot/cleanup evidence, not natural game
shutdown or a matched MetaStation speedup. DMB SHA-256:
`5e0073eb18e905d3c3054af56aa309e20bd9387178cbfa617cf6389d96c97713`.

Initialization procedure costs from that diagnostic run include 33.422 seconds self time
in mixture lifecycle IPC, 33.08 seconds inclusive in weak-reference construction, and
71.292 seconds inclusive in turf adjacency updates (312,776 calls). These costs overlap;
do not add inclusive values or describe them as native service-internal timings.

## Repairs

- Native component publication: a gameplay write between bounded ExcitedGroups/Equalize
  chunks now invalidates the captured component and retries it from authoritative state.
  Earlier completed components remain published. Pending candidates and events from the
  abandoned attempt stay unpublished. Invalid handles, topology changes, cancellation and
  other stage errors retain their existing failure behavior.
- Native initialization: mixture and turf arenas use amortized reservation instead of
  requesting exact capacity on every registration. The regression reproduced 4,096
  capacity increases for 4,096 registrations before the change; the new bound is at most
  32. This removes pathological arena growth, but does not measure recovered startup time.
  Spare capacity belongs to the 64-bit service, separately from DreamDaemon memory.
- DM startup: the initial neighbor comparison pass uses the existing bounded mixture
  snapshot prefetch, avoiding one synchronous IPC per cold mixture when the working set fits
  the cache. Comparison tolerances, gas coefficients and simulation cadence are unchanged.
- DM startup: repeated adjacency visits coalesce to one pending turf while endpoint
  initialization is incomplete. The final drain emits its current gas/heat edges, preserving
  lifecycle-before-topology ordering and yielding during real subsystem initialization.
- DM failure handling: the inert snapshot explicitly supplies a zero gas count, preventing
  the `__get_gases()` bad-number cascade after the service failure latch is set.
- DM failure handling: queued topology stops before lifecycle/adjacency native calls when
  the service is unavailable, preventing follow-on submissions during controlled shutdown.

The native changes live in `aphelion-dogmos` under `crates/dogmos-core/src/world.rs`,
`world/versioned.rs`, `world/scratch.rs`, and `tests/component_contention.rs`.

## Verification

Exact Rust version: `rustc 1.98.0 (88d9e12ae 2026-08-18)`; all Cargo gates used `--locked`.

- Component contention test failed before repair with `StageConflict/TransactionRevision`
  during ExcitedGroups. The repaired test sweeps every yield point for both component stages
  and checks reported work limits, completion, total moles and energy. A second test exercises repeated
  writes and retention/counting of already completed components. Both pass on i686 and x64.
- i686 workspace: 453 tests passed, two doctests ignored, before adding the second contention
  case. The final two-case contention test passed separately.
- x64 core/server/protocol: 310 tests passed before adding the second contention case; the
  final contention test passed separately.
- Supported Windows feature matrix, i686 workspace and x64 core/server/protocol strict
  Clippy, formatting, and dependency-direction check passed.
- Fresh committed-revision i686 workspace: 454 tests passed, two doctests ignored.
  The x64 core/server/protocol run passed 311 tests.
  Windows and Linux cross-bitness probes both passed ordered reaction callbacks and
  1,030 continuation lifecycle cycles, including five expected stale-token rejections.
  Both probes also passed against the exact packaged release services. The first Windows
  release-probe attempt stopped before connecting because the full workspace test had
  rebuilt its example without source identity; rebuilding that probe with the pinned clean
  identity resolved the harness error without changing the release binaries.
  The maintained 12-configuration Linux i686 feature matrix passed through a temporary
  WSL Cargo adapter pinned to Rust 1.98.0. Formatting and dependency-direction checks passed.
  Final Linux x64 core/server/protocol and i686 shim tests passed 355 tests with no failures
  or ignored cases; strict x64 Clippy also passed.
- Production full build `20260908T013136Z-5bdca791`: zero errors/warnings. This includes the
  startup prefetch but predates the later failure-path edits.
- Final production full build `20260908T021441Z-2d8bbae5`: rebuilt, zero errors/warnings,
  including both failure-path repairs. DMB SHA-256:
  `d4d4e2b512e6aab6e3a1c0fdf998b240fc62ab1f852bdf3c0a4e3f7e476168df`.
- DM red run `20260908T015520Z-438b07dd`: reproduced `__get_gases()` bad number in
  `dogmos_service_failure_latch_stops_stage`; machinery prefetch and prefetch chunking passed.
  The controller classified the run as failed and cleaned up its owned processes/workspace.
- DM red run `20260908T020303Z-8dd2aca1`: gas-enumeration repair passed. The topology failure
  test demonstrated an unwanted FFI call and rejection after the latch was set; this was
  observed before adding the missing service-ready guard. Cleanup passed.
- Final combined DM run `20260908T021016Z-039335ea`: six requested cases passed, zero runtimes,
  natural shutdown, required clean-run artifact, and successful cleanup. Cases: failure latch
  for stages/gas enumeration, failure latch for topology, machinery prefetch, prefetch chunking,
  immutable mixture contract, and space-boundary frontier settlement. This uses the installed
  native pair, so it does not validate the uninstalled component/arena repairs in DreamDaemon.
- Startup-adjacency red run `20260908T031636Z-637efeb3` failed because intermediate edges
  were constructed during repeated visits. Green run `20260908T032413Z-80ccbec0` passed all
  six requested cases: startup coalescing, startup batching, heat absence, topology pressure,
  runtime neighbor preservation and space-boundary settlement. Zero runtime signatures;
  natural shutdown and clean process/workspace cleanup. This is focused iteration evidence
  on the old native pair and the incomplete RIFT module-map deployment, not performance
  acceptance or a full-suite result.
- Production full build after coalescing, `20260908T033154Z-5ca6245a`, rebuilt with zero
  errors and zero warnings. DMB SHA-256:
  `70bf2e22953846d641c9dbff438e3f13d4ff08a41eee6320b1b43d644d0565f8`.

Meridian-MCP semantic tools were unavailable in this session. Source inspection and real
DreamMaker/DreamDaemon runs are recorded separately; no parser result is claimed.

## Windows capture package

See [operator instructions](../../tools/dogmos_tracy/README.md). The portable bundle contains
the PowerShell source, hash manifest, pinned x86 `prof.dll`, x64 collector, provenance patches,
and complete license notices. It runs alongside TGS from administrator PowerShell.

Local Windows PowerShell 5.1/BYOND 516.1687 fixture evidence:

- One 5-second capture: valid, 100 complete frames, zero partial frames and zero dropped events.
- Two consecutive 5-second windows: both valid, 100 complete frames each, zero dropped events;
  the first window has one boundary partial frame, recorded by the validator.
- Unsupported executable rejected before installing/arming; supported version armed;
  duplicate arm rejected; absent listener produced bounded timeout and failure metadata.
- Final ZIP unpacked into a fresh directory; its PowerShell 5.1 hash verification passed.
- Final v2 collector startup preflight passed; a failing executable was refused before
  hook installation or marker creation. The final two-window capture also passed, with
  100 complete frames per window and zero partial frames or dropped events.
- Captures completed and the helper exited. These tests do not establish Windows Server 2022
  production acceptance or profile service-internal Rust work.

Redistribution notices cover Tracy BSD-3-Clause, byond-tracy/LZ4 BSD-2-Clause, the MIT helper,
Capstone and other embedded dependencies. The script is shipped as AGPL-3.0 source with the
game license. Microsoft runtime DLLs and BYOND are excluded. The operator installs the x64
Visual C++ v14 runtime from Microsoft's official download page; it must be at least as recent
as the collector's MSVC 14.44 build tools. Upstream links are in the operator instructions.

Bundle: `dogmos-windows-capture-v2.zip`, 1,692,996 bytes. Use v2, which adds the collector
startup preflight before profiling is armed.
SHA-256: `1a08b037bfbc5bbf97d32bfd97037f7e9e1d54444b53f704afaaeb2f7345de7a`.

## Gate checkpoint before the final qualification sequence

The game rejects mismatched native identities/hashes before gas registration. Its maintained
synchronizer also requires a clean native source revision. A separate script cannot make an
uncommitted core repair available to the real game through the installed contract.

The native commit and complete release build were prepared under the user's authorization.
The game contract remains the seven-file set: `dogmos.lock.json`, `dogmos.dll`, `dogmosd.exe`,
`libdogmos.so`, `dogmosd`, `code/__DEFINES/dogmos_bindings.dm`, and
`code/__DEFINES/dogmos_contract.dm`. Its authority and synchronizer implementations need no
changes. The `0b942d5` set was synchronized and verified in both game workspaces; the
newer `14f0a4c` pair is installed only in the development workspace. The earlier focused
DM and production native-load boot passes apply to `0b942d5`; the corrected `14f0a4c`
pair now has the separate 16-case focused pass above. Its production boot is being
qualified separately: `20260908T112826Z-51393228` completed a full RuntimeStation
production build with zero errors and warnings, reached initialization with no runtime
signatures, and stopped through the controller with clean owned-process cleanup
(`ready_then_stopped`, exit 0). Initialization was 185.809 seconds, including Atoms
74.95 seconds and Atmospherics 44.37 seconds. This is a native-load boot gate, not a
matched performance candidate or natural game shutdown. Remaining work:
cross-process lifecycle/fault tests, matched candidates, the full DM suite, and a bounded
full-map soak.
Example focused command from the game repository:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json `
    --focus /datum/unit_test/dogmos_service_failure_latch_stops_stage `
    --focus /datum/unit_test/dogmos_service_failure_latch_stops_topology `
    --focus /datum/unit_test/dogmos_service_machinery_prefetch `
    --focus /datum/unit_test/dogmos_service_prefetch_chunking `
    --focus /datum/unit_test/dogmos_space_boundary_frontier_settlement `
    --shim dogmos.dll --service dogmosd.exe --format result
```

Performance acceptance needs repeated matched controls/candidates with the same map, seed,
hardware, configuration, cadence and scenario. Record at least three of each. Capture from
startup through shift-start before stress actions, retaining round logs and the capture
directory. Record action timestamps separately. Report DreamDaemon resources separately from
`dogmosd`, and verify numerical/event behavior. No startup speedup, settled-frontier result,
fresh full-suite pass, hosted CI pass or production deployment is claimed at this checkpoint.

## Full-suite condo correction and third attempt

The second full suite (`20260908T183239Z-468414f7`) passed `dogmos_del_cost`
in 460.112 seconds. Gas deletion averaged 119.622 ms versus 110.165 ms for
plain datums under the full suite's reference tracking; the existing relative
assertion passed unchanged. The run then stopped on an asynchronous condo preview
runtime: the mapped wooden-crate vending machine inherited `lustwish-light-mask`,
which is absent from the crate icon. Its stack is condo preview initialization,
not the concurrently running Dogmos recovery test. The summary reported a runtime
failure and clean cleanup, without a final test inventory.

The mapped object in `apartment_dragonslair.dmm` now overrides `light_mask = null`.
This single technical variable override preserves its existing artwork and text.
Maplint passed. The third full suite, `20260908T190008Z-be9ccf06`, includes that
correction and the frozen guarded candidate, with source hashes recorded during
compile. It uses minimum 500 tests, idle 900 seconds and wall 3,600 seconds.

The third full suite initialized in 341.562 seconds (Atoms 149.93, Atmospherics
76.27). Deletion cost passed in 448.275 seconds. At 19:18:19 UTC the space-boundary
test failed with unchanged 104 moles after its ten one-second waits. Its original
message incorrectly equated those waits with ten completed SSair cycles; the
Master increments `times_fired` only after completing a subsystem fire. A focused
full-ruin reproduction (`20260908T192101Z-efb1187f`) records actual completed fires,
queue length and stage state before deciding on a correction.

The run then stopped on duplicate elevation signal registration during asynchronous
`station_arrivals` condo preview initialization. This is a separate error under
investigation. Controller, sampler and the gated repeat driver all exited; cleanup
passed with no leftovers, and no final timing repeats were launched.

### Space-boundary wait: diagnostic red and cycle-based green

`20260908T192101Z-efb1187f` reproduced the assertion with full ruin loading:
104 -> 104 moles, zero completed SSair fires, state 3, enabled, 13,356 queued
adjacency updates and no pending native stage. The test had waited ten seconds,
not ten completed atmosphere cycles. One of two tests passed; no runtimes,
natural shutdown and clean cleanup.

The test now counts completed SSair fires with a separate 180-second simulated
world-time bound and still requires actual gas loss. `20260908T193204Z-db8954b7`
passed both focused cases with zero runtimes and clean natural shutdown. Gas fell
104 -> 91 moles after 136.5 simulated seconds during the first in-progress fire
(zero completed fires). This is a corrected test scheduling assumption; it does
not establish fast full-ruin startup or reduce the gas-loss assertion.

Two new elevation fixtures are being qualified before any production signal
change: reserved-tile empty/reload cycles and constructor-time deletion of a
carried wooden table. Both retain an external turf-change listener and inspect
both sides of the elevation registration. Their table element lookup uses the
same named `pixel_shift` argument as the production table, matching the bespoke
DCS identity rather than accidentally looking up a different positional key.

### Constructor-time shared-element cleanup

New fixture compile `20260908T194640Z-e4005165` failed on a missing test callback
(three compiler errors); the callback was added before the next run. In runtime
reproduction `20260908T195100Z-b85e9fc6`, four cases passed: connect-loc, context
replacement, deleted subscriber filtering and ordinary reserved empty/reload.
The carried-table constructor fixture reproduced two stale shared-element
registrations (`give_turf_traits` and `footstep_override`). Elevation itself was
clean in this fixture; it is evidence of the cleanup mechanism, not yet proof of
the exact condo elevation failure. The controller reported runtime failure with
clean cleanup and no final inventory.

The production correction is a narrow turf-only fallback in `UnregisterSignal`
when the target lookup is temporarily absent. It retires the listener's requested
callbacks; restored lookup entries are then filtered against live subscriptions.
Turf-self entries retain the prior behavior because their outgoing table is restored
after the lookup. The shared helper lives in the existing Meridian turf-context
module; no global override warning suppression or signal-table merge rewrite was
introduced. Five focused cases are running in `20260908T200011Z-d71a974e`.

## Turf-listener regression and full-suite retry

Focused run `20260908T200011Z-d71a974e` passed all five requested turf lifecycle
checks with zero runtime signatures, natural DreamDaemon exit 112, and clean
cleanup. The constructor fixture was then strengthened to check the exact trait
and footstep element instances on both sides of their signal registrations,
including singleton registration after reloading the table.

Full MetaStation run `20260908T201016Z-0ed1e2bd` uses that strengthened fixture,
the complete native 14f0a4c pair, minimum 500 tests, idle 900 seconds and wall
3,600 seconds. Compilation passed with zero errors and two test warnings. The
full-ruin workload initialized in 343.331 seconds. Deletion cost passed:
112.976 ms per gas mixture versus 113.981 ms per plain datum under reference
tracking. The space-boundary test passed in 147.637 wall seconds, observing
104 to 81.25 moles after 126.5 simulated seconds during the first atmosphere fire.

The previously failing `station_arrivals` condo preview was newly rendered at
20:28:47 UTC without a runtime error. Its 105,944-byte generated DMI was retained
under the run's `evidence` directory, with metadata in `condo-preview-proof.json`;
SHA-256 `e0fb62d7e76998bcb74579ad4d94456b69cf44396ae2d86af433029b8f852a0b`.
This directly exercises the earlier preview failure path. The full-suite final
inventory and completion status are still pending at this checkpoint.

That full-suite retry finished **failed**, with 619 logged passes and no final
inventory. All four turf-context fixtures passed, including the new direct
trait/footstep assertions. During `create_and_destroy` over all 30,717 types,
catwalk deletions on the restored white floor emitted the lava-stopping trait
removal signal and hit four `bad index` runtimes in `_SendSignal`. Cleanup passed
with no leftovers. Lava initialization registers this self-listener, but its
Destroy only unregisters the separate atom-initialization listener. The next
focused regression isolates lava replacement and external-listener preservation;
no performance repeats were launched after this failure.

The narrow lava regression `20260908T204308Z-9dc34035` failed as intended:
initial self handler present, one stale self listener and stale handler after
replacement, while the external listener remained present and received one
catwalk trait-removal callback. The constructor shared-element fixture passed.
This red run recorded 1/2 passing tests, zero runtimes, natural DreamDaemon exit
112 and clean cleanup. The fixture removes only its captured stale self entry
before dispatching the catwalk event so a failed assertion cannot pollute later
tests. Lava Destroy now explicitly unregisters its lava-stopping trait-removal
callback; broad changes to turf self-signal persistence were not needed.

Green run `20260908T204938Z-66c4606b` passed all six requested turf listener
regressions, including lava, constructor-time deletion, reservation reuse,
context replacement, deleted-subscriber removal and existing connect-loc
preservation. There were zero runtime signatures, natural DreamDaemon exit 16,
and clean cleanup. The full MetaStation suite is being rerun as
`20260908T205538Z-2d56e54a`, retaining the same limits and complete native pair.
The lava source file is now included among the common input hashes for all
subsequent performance comparisons.

### Full inventory after lava cleanup and startup-cache oracle correction

`20260908T205538Z-2d56e54a` completed with 622 recorded tests: 621 passed, one failed, zero skipped, and no runtime errors. All 30,717 `create_and_destroy` types passed (123.287 seconds). DreamDaemon exited naturally (192), and cleanup left no owned processes. The remaining failure was the startup prefetch test: control 121 cold reads, candidate six, helper used.

The snapshot cache is direct mapped. Reused live slots can alias within a 100-entry prefetch window. Prefetch leaves the last alias resident, and ordered reads evict it before its turn; every distinct alias in that bucket therefore misses once. Collisions across separate prefetch windows do not count. The revised test records ordered slots, generations and buckets, requires 121 distinct live slots, asserts exactly the calculated candidate misses and exactly 121 control misses, and retains physical/visual/adjacency/epoch/callback parity. Pure accounting coverage includes two and three aliases, the partial tail, and an alias across the window boundary. Production cache behavior is unchanged. Focused verification is in progress.

The first oracle-focused retry, `20260908T213904Z-beb3ae9a`, compiled with zero errors and two expected test-build warnings. The pure collision accounting passed. The real fixture failed before measurement because its 100 half-second setup waits expired with the shift-start adjacency backlog still present; no runtime errors occurred, and cleanup passed. Its setup now waits for an actually empty adjacency queue for at most three simulated minutes, with the controller retaining a separate wall timeout. This matches the existing shift-start observation interval without weakening the empty-queue precondition. A prior compile-only attempt, `20260908T213557Z-724ce7ae`, rejected assertion macros outside their include scope; the checks now use the surrounding file's explicit `Fail()` convention.

`20260908T214909Z-e1b6470c` passed both focused startup-prefetch tests with zero runtime errors. The real fixture recorded control misses 121, candidate misses zero, expected candidate misses zero, and 242 total reads on each path. Both paths emitted zero topology calls within the measured interval. All physical/visual/adjacency/order/epoch/callback assertions passed. DreamDaemon exited naturally (208), and cleanup left no processes. Compile: zero errors, two test-build warnings. DMB SHA-256: `a4d5bba27430bd1c69f59cf6e338e22ea3d5d379f3b37cd5be4b7c45385da21f`. This focused boot initialized in 196.962 seconds; it is a diagnostic observation, not one of the final matched repetitions.

The final serial qualification sequence now runs the full MetaStation suite (minimum 500, output-idle 900 seconds, wall 3,600 seconds), a fresh full RuntimeStation production build and 300-second soak (output-idle 900 seconds), then three control/candidate pairs. It stops on failure. All six variant source files are frozen and hash-checked; common source hashes, map, seed, toolchain and cache mode are checked across repetitions. An independent read-only source review found no concrete ownership or ordering regression in the named Dogmos, shuttle, template and turf-listener changes; this does not substitute for runtime gates.

### Intentional condo boundary scope in map-space validation

`20260908T215744Z-2766c2ce` finished with 623 recorded tests: 622 passed, one failed, zero skipped, and zero runtime errors. Startup prefetch passed with exactly two predicted collision misses (control 121, candidate two; 242 total reads on each path). All 30,717 construction/deletion types passed in 115.4 seconds. DreamDaemon exited naturally (176); cleanup passed; dense sampling finished without errors. Full-suite initialization was 337.419 seconds, a separate forced-ruin workload.

The remaining test failure was `maptest_mapload_space_verification`: its all-world scan observed 452 intentional `/turf/open/space/bluespace` tiles in `/area/misc/condo` on a reserved level during asynchronous preview generation. Both preview and live-room creation allocate condo reservations on `ZTRAIT_RESERVED`; `link_condo_turfs` explicitly configures the bluespace boundary to return entrants to the parent object. Several built-in condo templates deliberately map this combination. The clean no-Dogmos mirror has identical versions of the test, preview loader, condo subsystem and Arrivals template.

The correction is test-only and requires all three conditions: the bluespace turf subtype, condo area, and reserved z-level. Ordinary space, unrelated areas, and bluespace accidentally mapped in a condo area on a station level remain subject to the existing check. Reservation ownership is not used as the predicate because `Release()` removes ownership before asynchronous turf reclamation finishes. The test records how many intentional boundaries it accepted. No map or gameplay behavior changes for this correction. The fresh serial sequence starts with `20260908T222913Z-c3e6d573`; production soak and all six timing repetitions remain queued behind its full-suite gate.

### Reviewer job permission and departed-owner correction

Read-only inspection of Codeowner Reviews run `34173330309`, job `101897765827`, confirmed that the `pull_request_target` job had read-only contents/metadata/packages permissions. Its reviewer-request API call failed with `Resource not accessible by integration`; a separate notice identified an owner who was no longer requestable. The maintainer explicitly approved adding job-scoped `contents: read` and `pull-requests: write` to `.github/workflows/codeowner_reviews.yml`, then requested removal of blocking references to the departed owner.

The workflow change is exactly those three YAML lines. `CODEOWNERS` lost seven rules whose only owner was the departed account; both shared map rules retain `sqnztb`. No empty-owner patterns were left. Remaining account-name matches are historical module author credits. YAML syntax, unchanged trigger, exact job permissions, and whitespace checks passed. No review request, workflow dispatch, repository permission change, push, or merge was performed. Since `pull_request_target` uses the base repository's default-branch workflow, this source correction requires reaching that branch before a hosted rerun can prove it.


## Final full-suite gate, 2026-09-08 22:59 UTC

Run `20260908T222913Z-c3e6d573` passed all 623 tests, with zero skipped tests,
zero runtime signatures, natural DreamDaemon shutdown (exit 144), and clean
controller cleanup with no leftover processes. The compile had zero errors and
two warnings. The complete 30,717-type construction/deletion sweep passed in
97.9375 seconds. Both startup-prefetch checks and the narrow condo-boundary
map-space validation passed. Initialization was 341.975 seconds in the full-suite
workload; it is not a matched performance sample. The separate 250 ms sampler
finished without errors, with maximum recorded gaps of 284 ms for DreamDaemon
and 286 ms for the service.

The production RuntimeStation soak started as `20260908T225913Z-57c98a18`.
Three alternating control/candidate pairs remain queued behind its successful
completion. The final report now rejects mismatched actual procedure-profiling
state, run identity, labels, and all six source-variant hashes, in addition to its
existing common-source, map, seed, toolchain, cache and diagnostic-mode checks.
Sampler failure cleanup now stops its own pending job before removing it.


### Final production soak passed

`20260908T225913Z-57c98a18` compiled the full production RuntimeStation build
with zero errors and zero warnings. Initialization completed in 132.762 seconds.
The requested 300-second post-readiness interval passed with zero runtime
signatures. DreamDaemon terminated on the controller's requested stop (exit 143),
and cleanup found no remaining owned processes. This is a bounded availability
check, not a populated gameplay or natural-shutdown result. The three alternating
MetaStation control/candidate pairs began after this gate passed.


### Reviewer maintenance committed separately

`a7406c6962330f8ebcd7269ec37b60adcea4a6bc` on the main game `dogmos` branch
contains only `.github/CODEOWNERS` and `.github/workflows/codeowner_reviews.yml`.
The explicitly approved permissions and requested departed-owner removal passed
YAML/trigger/permission checks, copied-file hash verification and `git diff --check`.
The branch was clean after committing. No push occurred. The final performance
transfer must use this new destination revision when refreshing its manifest.


### Additional requested CODEOWNERS removal

`ea89176c9a4b451d7a2425b6e5bac478278be5a9` removes all four `sqnztb` rules
and the empty Maptainers heading, following the operator's explicit request.
The five remaining `vinylspiders` rules were verified unchanged, with no empty
owner patterns introduced. The main `dogmos` checkout is clean; no push occurred.
This is now the expected destination revision for the final repair transfer.


## Final matched qualification completed, 2026-09-09

All eight final gates passed with zero runtime signatures and clean owned-process
cleanup: full DM suite `20260908T222913Z-c3e6d573` (623/623), production soak
`20260908T225913Z-57c98a18` (300 seconds), and the six runs in the current
qualification report. All six observation runs ended naturally. The complete
native contract and six restored source pairs verified after the sequence.

The control initialization median was 248.175 seconds (232.250–263.106), versus
204.535 seconds (200.594–204.600) for the final candidate: 17.58% lower in these
matched local observations. This control already contains the completed-frontier
repair and uses the same native pair; it is not the no-Dogmos mirror. Candidate
final-minute active-turf medians were 45–73.5, with maxima of 297–328. Median first
queue clearance was 70.062 seconds versus 117.456 for controls. DreamDaemon
private-memory peaks during gameplay overlap; no sustained footprint reduction
is established. Actual procedure profiling was present in all six observations.

Map, seed, BYOND/Bun versions, cache mode, actual profiling state, source labels,
all six variant hashes and common source hashes passed combined validation.
The nominal 250 ms samplers completed without errors; the largest recorded gap
was 481 ms. Four Python analysis tests and the checked-in deployment-assets
regression passed. Raw summaries and the generated comparison remain under
`data/performance-qualification/final-*.json` and the named RIFT run directories.

The remaining evidence boundaries are new hosted CI, Linux DreamDaemon, live
DreamDaemon/service-death injection and the Windows Server 2022 capture. The
capture bundle and administrator PowerShell commands are linked from the current
report. The no-Dogmos initialization reference remains 131.994 seconds, so the
remaining initialization gap is not claimed eliminated.
