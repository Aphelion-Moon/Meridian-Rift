# Round 120 repair checkpoint

Initial performance repairs are committed on `dogmos` at `4547d77217ed7ce75e0caf0a82ab00127b148f34`.
Subsequent deployment, lava, and shutdown repair commits are recorded below.
The native repairs are committed on the native repository's `dogmos` branch at
`0b942d58cef15be73a2f6911ef50109fc846c25b`; its `master` branch was left unchanged.
All four release targets build and their complete generated release contract verifies.
The complete `0b942d58cef15be73a2f6911ef50109fc846c25b` pair is now installed and verified
in both the isolated development workspace and the main `dogmos` checkout, after collecting
the old-native controls below. The listener repair is committed at
`e89389ec769648d0d1650fed42a6fdca345a5dab`.
The paired artifact installation is committed at `ff58181486a67f5b6b43bc89130869b3848d925f`.
Native artifact rebuilding is authorized. No server deployment has occurred.

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
gives the ordinary parent precedence; a fresh ordinary run must verify `procedure_profiling = 0`.

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

## Remaining gates

The game rejects mismatched native identities/hashes before gas registration. Its maintained
synchronizer also requires a clean native source revision. A separate script cannot make an
uncommitted core repair available to the real game through the installed contract.

The native commit and complete release build were prepared under the user's authorization.
The game contract remains the seven-file set: `dogmos.lock.json`, `dogmos.dll`, `dogmosd.exe`,
`libdogmos.so`, `dogmosd`, `code/__DEFINES/dogmos_bindings.dm`, and
`code/__DEFINES/dogmos_contract.dm`. Its authority and synchronizer implementations need no
changes. The complete set has been synchronized and verified in both game workspaces.
Focused DM and production native-load boot gates passed as recorded above. Remaining work:
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
