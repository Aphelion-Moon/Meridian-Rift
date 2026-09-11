# Dogmos paired performance qualification, 2026-09-06

Native snapshot: `0bf856b37fb1d72f04ee0122c9c58bdc903ec254`
(`Optimize component storage and repair continuation lifecycle`). The native checkout was clean
when the release identity was generated. The game branch received this snapshot through the
maintained contract synchronizer. No push was performed.

Checkpoint at the user's requested stopping point: native work is committed; the additional game
repairs and this report remain uncommitted. The latest full suite reached 582 distinct PASS log
records, including 84 Dogmos cases, before a turf-meter destruction runtime stopped it. No final
unit-test JSON was produced, so this is partial log evidence, not a passing full-suite result.
The four focused diagonal/movement/stress tests passed on this source. Owned-process cleanup passed.
The final production soak is deferred.

## Changes and evidence boundaries

The native snapshot contains the continuation lifecycle, component storage, bounded publication,
and decompression loss-vector repairs documented in the native repository's
`docs/performance/2026-09-06-decompression-loss-storage.md` and preceding qualification reports.
The final vector change removed 32,850 allocations and 2,675,572 allocated bytes per 100,000-turf
corridor pass. Numerical and ordered-event comparisons matched. Three paired timing processes
had a median total wall-time change of -1.75% and calling-thread cycle change of -5.00%; wall-time
and tail results were mixed. These synthetic native observations do not establish live tick-time
or DreamDaemon memory improvements.

The previously blocked paired-release prerequisite is resolved. All four release binaries were
built with pinned Rust 1.98.0, locked offline dependencies, and the checked-in release target and
feature configuration. Generated bindings matched their tracked source. The manifest, generated
DM contract, bindings and four installed binaries passed the maintained contract verifier.
Feature fingerprint: `8691f3e1e88c5dba8ff06507bc1064823c18c09232b3000a5fc863893e35d1a0`.
ABI 2, protocol 13, workspace 2.3.0, BYOND 516.1687.

The committed-identity Windows i686-to-x64 IPC probe passed 1,030 lifecycle cycles, including five
expected stale-continuation rejections. Probe and service processes exited. Earlier final native
gates passed 447 Windows i686 tests, 322 Windows x64 tests, 321 Linux x64 tests, strict Clippy,
12 supported feature configurations on both i686 platforms, shim links and 42 Python tooling tests.
Linux i686 executable tests remain unrun because this environment previously rejected the executable
format; Linux i686 compile/link/static checks are separate evidence.

## Runtime-driven repairs

The first paired game gate exposed an oversized snapshot request during station initialization:
611 mixture handles produced 1,222 numeric fields, exceeding the shim's 762-field production limit.
The 64 KiB response window holds at most 381 compact 172-byte records plus the four-byte header.
DM prefetch now deduplicates mixture references, retains the bounded 2,048-input walk, and sends
chunks of at most 381 handles. It validates and caches every response through the existing path.

`dogmos_service_prefetch_chunking` exercises both 381 and 382 unique mixtures with each reference
repeated three times. It chooses noncolliding cache buckets, requires exactly one cached record per
unique mixture, and verifies literal per-mixture oxygen totals and zero cache misses. The old
small-machinery fixture did not exercise the production boundary.

The stage fixtures previously relied on general SSair progress or cumulative counters. They now
publish an isolated frontier, invoke only the named native stage, and restore the normal frontier.
Diffusion checks direction, no overshoot and closed-room oxygen conservation. Excited groups
checks the actual pressure precondition and both expected oxygen averages. Equalization verifies
gas movement and pressure callback cleanup. The helper drains preexisting callbacks before taking
measurements, drains fixture callbacks before restoration, and preserves pressure fields and queue
order. An unrecoverable boundary/stage failure records a failure, freezes atmos, skips unsafe gas
restoration and ends the suite, rather than allowing an unfinished fixture into subsequent tests.

## Game gate record

RIFT evidence is under ignored `data/rift-runs/<run-id>/`. Native release and orchestration evidence
is under ignored `tmp/paired-qualification/` in the native repository. Inspect `summary.json`,
`events.ndjson`, fresh unit-test JSON and collected logs; launcher exit codes alone are insufficient.

| Run | Gate | Result |
| --- | --- | --- |
| `20260906T105532Z-d6b82876` | Doctor | Passed |
| `20260906T105910Z-89626f6d` | Initial focused gate | Compile passed; initialization failed on oversized snapshot batch; no tests recorded |
| `20260906T111110Z-6623bf8f` | First regression fixture compile | Failed: assertion macros were outside their include scope; corrected to direct `Fail` calls |
| `20260906T112004Z-87c60c55` | Focused gate | 17 passed, 2 failed, no test-time runtimes; batching test passed |
| `20260906T113502Z-56c983f9` | Corrected 20-test gate | 20 passed, zero skipped, zero test-time runtimes; natural shutdown and clean process cleanup |
| `20260906T114352Z-c3acf4ed` | Deliberate fixture failure | Expected failure: exactly one recorded failure, zero runtimes, later sentinel test absent, natural shutdown and clean cleanup |
| `20260906T115034Z-36de4088` | Full DM suite | Compile passed; initialization failed on map-edge `null.x` in wall-mount diagnostic logging; no tests recorded |
| `20260906T115723Z-36fcb756` | Full DM suite after mount repair | Compile/initialization passed; map-content assertions failed, then the breach test hit synthetic epochs leaked by the recovery fixture; no final test JSON |
| `20260906T121225Z-4574d49c` | Six focused recovery/stage/mount tests | Six passed, zero runtimes/skips, natural shutdown and clean cleanup; before the subsequent sealed-control enhancement |
| `20260906T121910Z-26ac8ac2` | Full production build and 300-second soak | Passed: zero compile errors/warnings, zero runtime signatures, no reported failures, clean process cleanup; initialization completed in 226.172 seconds |
| `20260906T123831Z-880c0ecd` | Full DM suite with revised fixtures | Compile passed; infinite-heat fixture failed an incorrect transfer expectation; stopped on Mafia's missing arena before final test JSON; cleanup passed |
| `20260906T125952Z-b2a5e10d` | Corrected-profile build | Interrupted during compilation to correct the finite heat control before runtime; no result summary, excluded from qualification; all recorded owned processes verified exited |
| `20260906T130306Z-4fb71e04` | Full DM suite with supported profile | Compile/initialization and the repaired map/cargo/Mafia/heat/prefetch cases passed; later subsystem initialization, idle-cycle and firedoor-region assertions failed; stopped on a reagent-container teardown runtime before final test JSON; cleanup passed |
| `20260906T134026Z-6d3cd6e1` | Ten focused room/recovery/teardown checks | Ten passed, zero runtimes/skips, natural shutdown and clean cleanup; compiled before the diagonal lookup regression |
| `20260906T135352Z-13c586ff` | Full DM suite after room/recovery repairs | Compile passed; room/recovery integration cases passed; diagonal setup assertion failed on DM operator precedence; later stopped on a JPS deleted-loop runtime during monkey stress before final JSON; cleanup passed |
| `20260906T141741Z-3289e288` | Four focused diagonal/movement/stress checks | Four passed, zero runtimes/skips, natural shutdown and clean cleanup |
| `20260906T142811Z-8414132f` | Full DM suite at stopping checkpoint | Compile passed; 582 distinct PASS log records including 84 Dogmos cases; no assertion failures before a turf-meter teardown runtime in create-and-destroy; no final JSON; requested shutdown and clean cleanup |

The two failures in the 19-test gate were test setup errors: adding 5% oxygen exceeded the native
0.5 kPa excited-group pressure goal, and `dogmos_init_health` was a filename rather than a test type.
The actual initialization tests are `no_runtimes_during_init` and `station_turf_has_air`. The corrected
fixture adds 0.2 mole and asserts the pressure gap before running the stage.

The 20-test build compiled with zero errors and two expected CIBUILDING warnings. Subsequent review
extended the same abort policy to failures while establishing the initial boundary and added explicit
equalization assertions for pressure queue/order and fields. Those final test-only changes require
the later full-suite gate rather than inheriting the earlier focused result.

The temporary negative probe threw during callback draining after a real native stage completed.
It asserted local list/queue restoration and the latched service/SSair stop state after the exception.
Only the deliberate error appeared in the result; the subsequent selected sentinel did not execute.
RIFT correctly rejected the incomplete two-test selection. The probe source was restored byte-for-byte
after compilation and before the full-suite build. A final drain correction additionally requires an
observed empty batch because dispatching a DM reaction can enqueue events after the returned batch's
remaining count was sampled. Local `verify_game_evidence.py` checks the focused and negative result
JSON, shutdown/cleanup records, absence of probe source, and final game source hashes.

The first full-suite attempt exposed another path hidden by focused testing: mapping diagnostics
in `find_and_mount_on_atom()` dereferenced a null neighbor returned by a directional lookup at the
world boundary. The mount search now skips missing turf candidates and continues to valid fallback
supports. `wallmount_missing_neighbor` supplies a missing candidate followed by a real table support,
explicitly enables the diagnostic path even when focused, restores that setting after exceptions,
and checks successful attachment to the exact table. This protects the diagnostic path at a world
boundary; the resulting map assertions were retained and investigated as described below.

The next full run passed the revised FDM, excited-group and equalization cases, then exposed a
recovery-fixture leak: `dogmos_ssair_recovery` assigned synthetic four-word epochs and left them on
the replacement SSair. Its health-only checks passed, but the subsequent real heat stage requested
frontier epoch 1125912791875585 against native committed epoch 30. The fixture now snapshots all
altered fields at a safe boundary, suspends SSair while synthetic state is installed, restores state
before gas teardown even after assertions fail, and executes a real native stage after restoration.
The breach-cooling fixture additionally compares a sealed control with the breached case using equal
initial gas/turf temperatures, so ordinary gas coupling cannot supply a false pass for radiation.

The partial full-run map failures included unsupported edge wall mounts, disconnected/unpowered
cable powernets, and missing Medical/Science cargo delivery locations. Investigation of their
world-boundary coordinates identified an invalid test profile rather than establishing map-content
defects: `dogmos-ci` combined MetaStation with `MINIMAL_CENTCOM`, although
`tools/build/build_flags.json` restricts that flag to `runtimestation_minimal`. Centering the 255x255
station in the tiny base produced negative offsets and clipped station cells; automapper locations
were also unresolved before world expansion. The minimal base omitted the Mafia arena, causing
the later runtime. The profile now uses normal CentCom, retaining `SKIP_LAVALAND` and
`SKIP_SPACE_LEVELS`. Existing map/cargo/spawn and Mafia tests are the integration regressions.
A new RIFT profile assertion failed on the old flag combination before the configuration repair.
The RIFT suite also exposed an inherited-cache defect in its missing-Bun test: a shared
`TG_BOOTSTRAP_CACHE` let the fixture find the real executable after deleting its mock executable.
Launcher fixtures now explicitly select their own temporary cache, while retaining per-test
overrides. All 92 RIFT tooling tests passed with the same shared-cache environment after repair;
the changed profile and test file passed the repository formatter.

Final source review also corrected an obsolete snapshot-cache collision fixture (`1`/`513` no longer
collide in 2048 buckets; `1`/`2049` do). The infinite-capacity heat fixture now finishes each heat
stage. Its first revision incorrectly required heat loss from two infinite reservoirs; the native
conduction contract explicitly leaves both unchanged. The corrected test first requires actual
heat transfer across the same edge with finite capacities, then requires literal 1500K/1000K
reservoir temperatures after every infinite-capacity stage. Matching initial gas temperatures
exclude ordinary gas coupling as a false substitute, and cleanup restores both capacities.
The finite control seeds its cold turf at room temperature because the native stage also includes
heat neighbors beyond the requested pair. Seeding that control at 1000K would let its other cold
neighbors hide heat arriving from the hot turf; review caught this before its runtime gate.
The FDM cadence fixture uses the shared completed-stage
cleanup, verifies native epoch advances and actual oxygen movement as well as the configured pass
count, and no longer runs unrelated reaction/equalization stages or clears an unfinished barrier.
Read-only review found no further concrete issue in these final changes; runtime qualification is
reported separately below.

The supported-profile full run exposed two additional integration defects. `TURFS_CAN_SHARE`
tested adjacency flag truthiness, although ordinary Dogmos edges carry `NONE = 0`; room detection
therefore returned only the immediate ring around its origin. The helper now tests key membership.
The regression requires a real zero-flag reverse edge and traversal to a third turf two steps away.
The related diagonal lookup also confused flags with membership. It now counts connected routes
through the origin's original cardinal neighbors. The regression checks two ordinary zero-flag
routes, exclusion from cardinal-only results, and rejection when either side lacks its second route.
Temporary lookup lists are restored before assertions, without yielding or publishing a native graph.
The diagonal fixture covers a same-level square; multilevel traversal and exclusion of previously
appended diagonals from route counting were reviewed by inspection only.
Its first compound setup assertion was malformed: DM gives `in` lower precedence than `&&`.
A standalone BYOND 516.1687 probe returned false for the compound expression while both individual
memberships and the explicitly grouped conjunction returned true. The fixture now uses separate
assertions for each route. This was a fixture failure, not evidence of a missing production edge.

The recovery test deleted the SSair object still held by the Master's cached scheduling lists.
Adding its replacement to `Master.subsystems` did not update those live lists, so direct native
stage tests passed while natural atmos cycles stopped. The fixture now invokes the actual recovery
procs on inert copies, preserving both scheduled globals and cleaning up copies before yielding.
It checks original identity, initialization state, Master membership, adjacency-queue identity,
native epoch validity and a naturally scheduled completed cycle. `SSair.Recover()` also retains
the original initialization status. The Dogmos copy clears its inherited no-init flag before recovery
so that asserting the flag is set actually tests recovery behavior.

The late monkey stress test reached a drop-sound callback after its drinking glass's reagent holder
had been destroyed. The shared sound handler now skips that teardown case. Its regression first
checks normal empty-glass sound behavior, then deletes the holder and verifies the guarded path.
The subsequent monkey stress run exposed a second teardown path: entering a turf deleted a mover
and its owned JPS loop while `Move()` was still executing. The resumed loop then requested a path
with the endpoints cleared by destruction. JPS now returns immediately after that deletion and
ignores repath callbacks on a deleted loop. Its regression uses the real movement manager and an
existing entry interceptor to delete the mover synchronously, preceded by a successful normal move.
It verifies mover/loop deletion, the failure result, no new path enqueue and an unchanged expired
repath cooldown, so the callback check cannot pass merely because an invalid request was rejected.
These production changes require a new final production soak; the earlier successful soak retains
its original source scope.

## Production soak observations

The maintained full production build rebuilt both the game and TGUI. RIFT completed the
300-second observation window after readiness, requested server shutdown, and reported no
remaining owned processes. The full-build artifact SHA-256 values were
`6a952d45069a6b03db969bf05d3399be37645bc73a177920a3847b2792f356bb` (DMB) and
`e08cf579ee620186b42a11f99ffa9f7da6f6127b36bd3d1a538ed62e90cad6de` (RSC).

| Process | Maximum private bytes | Maximum working-set bytes | Samples |
| --- | ---: | ---: | ---: |
| DreamDaemon | 1,771,319,296 | 1,766,928,384 | 46 |
| dogmosd | 177,537,024 | 125,063,168 | 46 |

These are separate process observations from a shared host, without a matched control. They do
not establish a memory reduction or live performance gain. Production builds exclude unit tests;
the successful soak does not qualify the final test-only changes.

## Remaining qualification

Resume at `code/modules/atmospherics/machinery/other/meter.dm:29`. The base meter destructor accesses
`target.dogmos_pipeline_meters`, which is defined on pipes. The turf-meter subtype's
`reattach_to_layer()` assigns `target = loc` instead, so forced destruction during create-and-destroy
accesses an undefined variable on an indestructible floor. The meter source was only inspected at
this checkpoint; it has not been repaired. Preserve pipe unregister behavior while separating turf
targets, add a regression covering destruction of both meter kinds, then repeat the focused and
full DM gates. The latest full run's DMB SHA-256 is
`cacebc2adf01fbfd3a815319ee80ef1432f0b0657befc053056211343ace6cf6`.

The fresh full production build and 300-second soak are also deferred; the earlier successful soak
predates the final production changes. Matched live performance acceptance
remains separate from correctness and soak evidence. Restart an
existing server to load the new shim/service pair; these runs launch their own isolated processes.

Reproduce from this game checkout with the pinned dependencies cached:

```powershell
python tools/dogmos/verify_contract.py verify-installed --root .
& .\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --minimum-tests 400 --readiness-timeout-seconds 900 --wall-timeout-seconds 3600 --idle-timeout-seconds 900 --shim dogmos.dll --service dogmosd.exe --network offline --format result
& .\RIFT.cmd soak --profile dogmos --compile-mode full --map _maps/runtimestation.json --run-seconds 300 --readiness-timeout-seconds 900 --wall-timeout-seconds 3600 --idle-timeout-seconds 900 --shim dogmos.dll --service dogmosd.exe --network offline --format result
```
