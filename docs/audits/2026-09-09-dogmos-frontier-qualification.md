# Dogmos frontier execution qualification

Native source: `58430a71192060150ee1d2a04c42ce871b0d57d6` on `master`.
Game source before paired artifact replacement: `a76dd694b5caf588f1bf4f8eb64a81a9fee0fe53`
on `dogmos`. This follow-up changes the paired native artifacts and generated
identity contract. The regenerated bindings are byte-identical. Qualification also
exposed two incorrect condo map boundary definitions and a detached-surgery null
dereference. Their repairs and regressions are included below. No atmosphere
coefficients are changed.

## Change and focused native evidence

Bounded stage preparation now consumes ordered frontier storage directly, charging
removed entries against the work limit. Service telemetry reads live membership
without materializing a frontier copy. Dense inspection borrows existing storage;
fragmented contiguous inspection reserves one exact-sized copy. Re-add ordering,
generational identity, cancellation and retry behavior are preserved.

At 100,000 turfs, the first one-work-item stage chunk after removing 16 entries
requested 24 allocated bytes instead of 2,097,144 in the matched native probe.
The complete frontier-only stage requested 48 bytes instead of 2,097,168. All 90
control/candidate ordered-frontier cases agree. A separate fixture compares final
mixture snapshots, heat state and event transcripts for fragmented and dense
frontiers across all five stages and work limits 1, 7 and 4,096. Its reaction
registry is empty; existing reaction/callback gates provide separate coverage.

The tradeoff is explicit: tombstone inspection can add chunks. The 100,000-turf
burst case uses 1,563 chunks rather than 1,555 at work limit 64. The game schedules
from remaining wall time and uses the returned remaining count as a work estimate;
it continues to invalidate caches conservatively for non-diffusion pending work.

These measurements isolate service-side frontier overhead, with turfs that have no
mixtures. They are not whole-game performance, DreamDaemon memory savings, or SSair
speedup claims. The native report and raw CSVs live in aphelion-dogmos under
`docs/audits/2026-09-09-frontier-consumer-audit.md` and
`docs/performance/2026-09-09-frontier-lifecycle/`.

## Release identity and native gates

Both platform pairs were built from the same clean source with Rust 1.98.0,
`--locked --offline`, ABI 2, protocol 13, BYOND 516.1687 and the existing feature
fingerprint. The maintained native generator/verifier and game synchronizer
validated the complete manifest, four executable architectures, symbols, binding
digest, source revision and installed bytes. The old installed set was retained
as a local backup. Runtime consumers must restart to load a new pair.

| Installed file | Bytes | SHA-256 |
| --- | ---: | --- |
| `dogmos.dll` | 662,016 | `943b5b30884427bda95378c8ec6051ecba471bb6abb636085405e9e531d45f90` |
| `dogmosd.exe` | 932,352 | `35e5a96653e88fe6124980be4df296ff0b64fcbdaed3d74579b39413798cb98c` |
| `libdogmos.so` | 1,164,488 | `76f60bc6acba39f563798b5f2bc56f3c60de6c991a15cd284db5c6dc92daa612` |
| `dogmosd` | 1,225,688 | `678f9e76b76d3d46a2e5d71305bb59d690f6b2e981db0a06308db1407777bee2` |

| Native gate | Result |
| --- | --- |
| Windows x64 core/server/protocol/perf | 343 passed, zero failed/ignored |
| Windows i686 workspace | 472 passed, zero failed, two existing ignored doc examples |
| Linux x64 core/server/protocol/perf | 342 passed, zero failed/ignored |
| Linux i686 workspace | 459 passed, zero failed, two existing ignored doc examples |
| Strict i686 workspace/all-target Clippy | Passed on Windows and Linux |
| Supported features | 12/12 configurations on each platform |
| Dependency-direction and contract tooling | 13 tests passed |
| Exact generated binding drift | One test passed |
| Maintained x86 client/x64 service IPC | Passed, including ordered callbacks and 1,030 continuation lifecycle cycles |
| Formatting, whitespace and independent source review | Passed; no actionable source findings |

Local native build/test logs, matched binaries and the complete release bundle are
under `target/audit-20260909-frontier/` in aphelion-dogmos. They are distinct from
the older `target/audit-20260909/` checkpoint.

## Paired DM and runtime gates

| Gate | RIFT run | Result |
| --- | --- | --- |
| Focused MetaStation tests | `20260909T211325Z-29ef82d1` | 16/16 passed, zero skipped/failed, zero runtimes and runtime signatures |
| Initial full MetaStation suite | `20260909T212132Z-e786a59b` | 644/645 passed; one map-space validation failure; all 115 Dogmos tests passed |
| Production compile and 300-second RuntimeStation soak before map repair | `20260909T214428Z-26497897` | Passed; zero compiler errors/warnings, zero runtime signatures, successful cleanup |
| Full MetaStation suite after map repair | `20260909T215738Z-d0f3f71b` | Failed at a detached-surgery runtime; map-space test passed; no final test inventory |
| Detached-surgery regression before guard repair | `20260909T223148Z-c28a56cc` | Expected regression: detached test failed with one null-patient runtime; stasis test passed |
| Surgery focus after guard repair | `20260909T223743Z-dfcb4f5c` | 6/6 passed; zero runtimes; fresh compile with zero errors and two expected CI warnings; cleanup passed |
| Full suite after both repairs, interrupted | `20260909T224305Z-3b52faba` | Interrupted; no final summary or test inventory; retained workspace; not a completed gate |
| Resumed full suite after both repairs | `20260909T225910Z-459c3c1d` | 647/647 passed; zero failures/skips/runtimes; fresh compile with zero errors and two expected warnings; cleanup passed |
| Production compile and soak after both repairs | `20260909T232638Z-3fd27729` | Compile passed, zero errors/warnings; DreamDaemon exited naturally with code 255 before readiness; soak failed |
| Diagnostic rerun of the production 300-second soak | `20260909T233510Z-e59f9133` | Failed in offline preflight cleanup; no compilation or game process; cleanup reported no leftovers |
| Offline doctor after transient preflight failure | `20260909T234332Z-450d9b1e` | Passed, exit zero; inspection only |
| Further production 300-second soak | `20260909T235636Z-fdf89417` | Passed; zero runtime signatures, successful cleanup, diagnostic workspace deliberately retained; reused the exact earlier rebuilt DMB/RSC |

The focused run compiled a fresh DMB/RSC with zero errors and two expected CI
warnings (qdel reference tracking and disabled loop checks). Its DreamDaemon exited
naturally with code 32; all requested test records passed and RIFT cleanup left no
processes or retained scratch. Overall elapsed time was 486.770 seconds, including
compilation and initialization; it is not a simulation-performance measurement.

The `build_contract` helper's exit code 1 is the supported `BUILD.cmd --help` probe,
not a failed compile. `invokeTestBuildPrerequisites` explicitly accepts help exit 0
or 1 while requiring the advertised build targets. The real DreamMaker process
exited 0.

The full suite compiled a fresh DMB/RSC with zero errors and the same two expected
CI warnings. All 645 records were collected: 644 passed, one failed, none skipped,
and every record had zero runtimes. All 115 Dogmos records passed. The sole failure,
`/datum/unit_test/maptest_mapload_space_verification`, reported 69 ordinary
`/turf/open/space` cells in `/area/misc/condo` at x=90..103, y=40..52, z=4. This
is a failed run, regardless of the passing Dogmos subset. RIFT
reported no runtime signatures and successful cleanup with no leftovers or
retained workspace. DreamDaemon exited naturally with code 176; RIFT returned 5.
Overall elapsed time was 1,169.521 seconds, including compilation and initialization.

The qualification wrapper stopped after this failure and shut down its disposable
database successfully. The production soak was subsequently started independently
on the same source and installed pair. That production build used `CBT` and passed
with zero errors and zero warnings; DMB/RSC were rebuilt. Initialization completed
in 134.525 seconds, followed by the requested 300-second interval. RIFT recorded no
runtime signatures or failures and cleaned up all owned processes and scratch.
DreamDaemon termination was requested by RIFT at the interval's end (exit 143),
not a natural shutdown. Overall elapsed time was 696.833 seconds. The 250 ms sampler
finished without errors: 1,778 DreamDaemon and 1,673 service samples, with maximum
gaps of 318 ms and 276 ms respectively. Independent process inspection confirmed
the wrapper, sampler, DreamDaemon and service had exited.

## Condo boundary repair found during qualification

The failing footprint matches the 69 exposed cells of key `E` in
`modular_nova/modules/condos/_maps/ship_bridge.dmm`. Its other ordinary-space key,
`a`, is used by 18 catwalk cells. These were the only ordinary-space definitions
among all 28 condo templates. Runtime logs identify the cell coordinates and area;
the template attribution comes from the matching source grid and counts rather
than an explicit template-name log.

Both definitions now use `/turf/open/space/bluespace`. This is the existing condo
exit type linked by `link_condo_turfs` to the room's parent object. Objects, catwalks,
areas, variable edits and the 16-by-15 grid are unchanged. Parsed comparison found
50 definitions and 196 content items on both sides, with only these two turf paths
changed. The runtime map-space test remains strict.

The new `tools/maplint/lints/condo_space_boundaries.yml` rejects ordinary space
sharing a tile with a condo area. The maintained linter was observed failing on
the original two definitions and passing on the correction. All 28 installed condo
maps pass this rule; the corrected map also passes every default map lint. The
source-wide condo-area search finds exactly these 28 DMMs. The repository's pinned
Python 3.11.0 bootstrap passed the corrected map's `mapmerge2.dmm_test`, every
default map lint on that map, and the boundary lint on all 28 maps.

Use UTF-8 mode and short map filenames with the Windows bootstrap. Initial ambient
interpreter attempts found a missing `bidict` dependency and a non-CP1252 character
in another template. A bootstrap invocation with all absolute map paths then hit
its existing 1,023-character window-title limit. Running the unchanged bootstrap
from the condo map directory with filenames resolved that launcher limit. These
failed attempts did not produce map-validation success; the subsequent pinned
checks did. Build/bootstrap implementation is unchanged.

The next full run (`20260909T215738Z-d0f3f71b`) compiled with zero errors and two
expected CI warnings, then passed `maptest_mapload_space_verification`. It later
hit `Cannot read null.buckled` in `surgery_operation/try_perform`, called by
`monkey_business` on a detached head. RIFT terminated DreamDaemon after this fatal
runtime; there is no final unit-test inventory (`summary.tests` is null). The
empty summary runtime-signature array does not negate the runtime log or the
explicit `runtime_error` failure. This run is incomplete and failed, not a full
suite pass. Its elapsed time was 1,473.578 seconds; process/scratch cleanup passed
and the wrapper shut down its disposable database successfully.

The detached-patient regression was then observed on the uncorrected guard in
`20260909T223148Z-c28a56cc`: its actual two-record inventory contains one failing
detached-patient test with one `Cannot read null.buckled` runtime and one passing
stasis test. After the guard correction, the six-test surgery focus
`20260909T223743Z-dfcb4f5c` passed every record with zero runtimes. Its fresh compile
had zero errors and two expected CI warnings; DreamDaemon exited naturally with
code 0 and cleanup passed. Elapsed time was 321.545 seconds including compilation.

The following full run, `20260909T224305Z-3b52faba`, was interrupted. Its wrapper
stderr contains `^C`, its event stream stops without completion, and there is no
final inventory or summary. Host inspection confirmed its wrapper, disposable
database, DreamDaemon and service had exited, with no database listener. Its
workspace remains retained diagnostic scratch. Partial passing log lines do not
make this a completed full-suite gate.

The resumed full run `20260909T225910Z-459c3c1d` completed with an actual inventory
of 647 passed, zero failed/skipped, and zero runtimes. The summary reports no
failures or runtime signatures and successful cleanup with no leftover processes
or retained workspace. DreamDaemon exited naturally with code 0. Total elapsed
time was 1,647.723 seconds, including a fresh compile with zero errors and two
expected CI warnings. The disposable database remained alive only for the next
soak, then shut down successfully when that soak failed.

DreamChecker 1.11.0 (commit `0290db5c752fa292f9824521515b603a2afd11dc`), selected by
the checked-in `SpacemanDMM.toml`, completed with exit 0 and `Found 0 diagnostics`.
It was invoked without a positional DME argument. An earlier rejected positional
invocation is not gate evidence; the first completed analysis lacked a captured
numeric exit and was repeated once to record it explicitly.

The first post-repair soak `20260909T232638Z-3fd27729` compiled successfully through
production `BUILD.cmd` with `CBT`, zero errors and zero warnings. DreamDaemon then
exited with code 255 after 42 seconds, before readiness and before a service child
or game logs were recorded. RIFT reports `process_exited_before_ready`, successful
cleanup and no runtime signatures; the empty signature set does not explain the
early exit. The sampler recorded 145 DreamDaemon samples and no service samples.
Windows application-event inspection found no corresponding crash report, and
post-run memory availability does not establish conditions at the instant of exit.
The complete installed bundle was reverified against the preserved 58430a7 manifest.
The first diagnostic rerun failed before compilation: a separate PowerShell
cleanup helper returned nonzero, with only CLIXML progress in its stderr. No
workspace or DreamDaemon was created. A later offline doctor passed. An ignored
instrumented harness then ran the exact three offline-preflight probes; all
exited zero with no live descendants, so the failing cleanup path was not
exercised. No controller behavior was changed from this non-reproduction. A
further soak retains its workspace and samples resources from compilation onward.
Both earlier failures remain part of the qualification record. The further soak
passed with no failure or runtime signatures, DreamDaemon requested exit 143, and
no leftover processes. Its diagnostic workspace was deliberately retained.
The initialization marker records 284.131 seconds and is followed by the complete
300-second soak. Overall run duration is 763.332 seconds. Its DMB and RSC hashes
exactly match the fresh zero-error/zero-warning build in the failed 232638 run;
the final run reused those artifacts and is not another fresh-compile claim.

The independent sampler started during compilation and finished with no errors.
It recorded 2,374 DreamDaemon and 2,196 service samples, attaching 2.202 and 3.817
seconds after their respective starts. Maximum gaps were 12.545 and 7.419 seconds,
so these are observed sample maxima rather than guaranteed process peaks:

| Process | Private bytes | Working-set bytes | Virtual bytes | Last observed CPU seconds |
| --- | ---: | ---: | ---: | ---: |
| DreamDaemon | 1,901,953,024 | 1,894,514,688 | 2,100,604,928 | 254.203125 |
| dogmosd | 135,839,744 | 126,652,416 | 4,494,172,160 | 9.25 |

Native validation and other host work overlapped this qualification; it is not a
matched startup comparison. The runtime log contains RuntimeStation shuttle-ID
warnings during initialization; the controller reported no fatal/runtime signature.

## Detached surgery regression found during qualification

Detached body parts are valid targets for operations marked
`OPERATION_NO_PATIENT_REQUIRED`. A limb's patient is its owner, which is null after
detachment. The inherited Nova stasis-bed guard dereferences that patient after
availability has already accepted the detached target. The correction makes only
that guard null-safe, retaining the rejection for a real patient on an enabled
stasis bed. It belongs to the Nova-specific stasis restriction; remove the local
marked correction if that inherited guard receives an equivalent fix.

The regression uses a test-only, self-abstract incision subtype, excluded from the
global operation registry. Its supported `pre_preop` hook records entry and
cancels before timed surgery. The real `try_perform` and availability checks run:
a detached head must reach cancellation without a runtime, an enabled stasis bed
must block before the hook, and a disabled bed must reach it. Each invocation
supplies its actual body zone. Allocated fixtures use the unit-test cleanup path.

The completed RED, focused GREEN and final full-suite artifacts are listed above.
The final production soak also passed with the evidence and sampling limits above.

## Reproduction and limits

The 16 focused paths cover native identity/lifecycle, frontier identity/rejection,
pending-stage mutation and deferral, registration catch-up, integer/fractional
budgets, remaining-budget use, equalize resume, cache boundaries, malformed stage
responses and topology barriers:

```powershell
$focus = @(
    '/datum/unit_test/dogmos_service_contract_identity',
    '/datum/unit_test/dogmos_service_lifecycle',
    '/datum/unit_test/dogmos_service_turf_heat_absence',
    '/datum/unit_test/dogmos_service_callback_identity',
    '/datum/unit_test/dogmos_service_frontier_generation_identity',
    '/datum/unit_test/dogmos_service_frontier_rejection_preserves_epoch',
    '/datum/unit_test/dogmos_service_frontier_mutation_waits_for_pending_stage',
    '/datum/unit_test/dogmos_service_foreign_pending_stage_defers',
    '/datum/unit_test/dogmos_service_frontier_registration_catchup',
    '/datum/unit_test/dogmos_service_stage_budget_progress',
    '/datum/unit_test/dogmos_service_fractional_budget_progress',
    '/datum/unit_test/dogmos_service_stage_uses_remaining_budget',
    '/datum/unit_test/dogmos_equalize_resume_after_empty_budget',
    '/datum/unit_test/dogmos_service_atomic_stage_cache_boundary',
    '/datum/unit_test/dogmos_service_stage_response_failure',
    '/datum/unit_test/dogmos_service_topology_stage_barrier'
)
$focusArguments = foreach ($test in $focus) { '--focus'; $test }
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json @focusArguments --minimum-tests 16 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 600
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --minimum-tests 500 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 600
.\RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json --run-seconds 300 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 600
.\tools\bootstrap\python.bat -X utf8 -m mapmerge2.dmm_test modular_nova/modules/condos/_maps/ship_bridge.dmm
Push-Location modular_nova/modules/condos/_maps
try {
    $condoMaps = Get-ChildItem -Filter '*.dmm' -File | ForEach-Object Name
    & ../../../../tools/bootstrap/python.bat -X utf8 -m maplint.source @condoMaps --lints condo_space_boundaries
    & ../../../../tools/bootstrap/python.bat -X utf8 -m maplint.source ship_bridge.dmm
} finally {
    Pop-Location
}
```

The task's disposable MariaDB 10.11.19 data directory was reused, bound only to
127.0.0.1:3306. The schemas were populated before testing. No Windows service,
global database configuration or unrelated database data was changed. The wrapper
recorded database shutdown exit 0 and successful process exit. Independent process
inspection confirmed that its wrapper, database, DreamDaemon and service PIDs were
absent and port 3306 had no listener after the full suite. The standalone production
soak uses the repository configuration, where SQL is disabled.

Meridian-MCP was unavailable; no parser or Tracy gate is claimed. Hosted CI, Linux
BYOND native-load, Docker/TGS deployment, human playtesting and a repeated matched
full-game control/candidate performance workload remain separate unrun gates.
The bounded soak does not supply whole-game numerical/event equivalence or an
active gameplay performance claim. DreamDaemon and service resource measurements
must be reported separately.
