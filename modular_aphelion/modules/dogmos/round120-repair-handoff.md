# Round 120 repair checkpoint

Game repairs are committed on `dogmos` at `4547d77217ed7ce75e0caf0a82ab00127b148f34`.
The native repairs are committed on the native repository's `dogmos` branch at
`0b942d58cef15be73a2f6911ef50109fc846c25b`; its `master` branch was left unchanged.
All four release targets build and their complete generated release contract verifies.
The installed pair remains `8456726ed1b69e4ae2ac41042b64ef179a68f84d` while controls
are measured. Native artifact rebuilding is authorized. No server deployment has occurred.

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

The native commit and complete release build are now prepared under the user's authorization.
The game contract remains the seven-file set: `dogmos.lock.json`, `dogmos.dll`, `dogmosd.exe`,
`libdogmos.so`, `dogmosd`, `code/__DEFINES/dogmos_bindings.dm`, and
`code/__DEFINES/dogmos_contract.dm`. Its authority and synchronizer implementations need no
changes. After collecting controls, synchronize atomically, then run native-load boot, cross-process
lifecycle/fault tests, focused DM cases, the full DM suite, and a bounded full-map soak.
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
