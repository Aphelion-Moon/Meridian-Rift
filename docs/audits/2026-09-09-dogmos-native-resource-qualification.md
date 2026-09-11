# Dogmos native resource qualification

## Source and paired artifact authority

Native `master` includes the fast-forward merge of local `dogmos` to `14f0a4c`, then:

- `6274480`: direct independent topology-layer removal and deadline-aware expiry.
- `66b117f`: constant-time core continuation cardinality and conditional lifecycle cleanup.
- `27762739d6b3ead84c4438bf1f3232b712900b8e`: frontier reservation failure atomicity and no-op view retention.

The final native source is clean and committed. Game implementation starts at
`f4ee3bfd54fb637464c408194169fdce025a7169`; this qualification changes only the paired
native artifacts, generated contract, one focused-test fixture, two condo map
boundary definitions and this report. Generated bindings are byte-identical.
Production DM code was not changed; the map repair restores the existing condo
boundary behavior described below.
No branches were pushed.

The game fixture repair is committed as `46102ced8a14e986c39aaf3135dc3c0148a6e4ab`;
the condo boundary repair is `a337b61b459a99924738f12c5f462d33b1c006d0`.
Qualification snapshots recorded `f4ee3bfd` plus these then-uncommitted edits;
committing them did not change the tested source contents.

The paired checkout advanced from the initially inspected `fc9ec1d` to `f4ee3bfd`
before the full-build snapshot. That existing merge and its departmental-chat changes
were preserved; they are not part of this task's native artifact update. Runtime
records identify the actual game revision used rather than the earlier inspection.

The complete release bundle was generated and verified with the maintained native
`tools/dogmos_contract.py`, then installed and checked with
`tools/dogmos/sync_contract.ps1` and `-VerifyOnly`. The lock and generated defines
identify source `27762739d6b3ead84c4438bf1f3232b712900b8e`, Rust 1.98.0, BYOND
516.1687, ABI 2, protocol 13 and fingerprint
`8691f3e1e88c5dba8ff06507bc1064823c18c09232b3000a5fc863893e35d1a0`.

| Artifact | Target | SHA-256 |
| --- | --- | --- |
| `dogmos.dll` | i686 Windows | `2e7bb35d573c1d47b7d865d45890482931c35606e26c3f16c643ead44283362b` |
| `dogmosd.exe` | x64 Windows | `2b5e882e4e81df16d4eedf2119695097aeabd4bf2687f4cdb562eaa4675f6147` |
| `libdogmos.so` | i686 Linux | `ffc869a71f4e8a31d731c9a26a45bf0676585a6371c2d1ecaa62c8925aafede3` |
| `dogmosd` | x64 Linux | `e2f82a17721faa78292f8364cd9a69e6b513893f0c25da41ca90b9356fcb6a0d` |

Windows builds used MSVC; Linux builds used Ubuntu WSL with multilib and GNU symbol
tools. Both followed the release workflow's exact identity and platform targets.
The native bundle, including symbols, remains under
`target/audit-20260909/release-bundle/` in aphelion-dogmos. The prior installed
`14f0a4c` set was copied to `data/dogmos-audit-20260909/baseline-installed/` and passed
the installed-contract verifier before replacement.

## Rust and boundary evidence

All Cargo commands used Rust 1.98.0 and `--locked --offline`.

| Gate | Result |
| --- | --- |
| i686 Windows workspace tests | 470 passed, zero failed; two pre-existing ignored doc examples |
| x64 Windows core/server/protocol/perf tests | 341 passed, zero failed/ignored |
| i686 Linux workspace tests | 457 passed, zero failed; two pre-existing ignored doc examples |
| x64 Linux core/server/protocol/perf tests | 340 passed, zero failed/ignored |
| Strict i686 workspace/all-target Clippy | Passed on Windows and Linux |
| Windows supported feature matrix | All 12 configurations passed |
| Linux supported feature matrix | All 12 configurations passed through the maintained script and a WSL Cargo wrapper |
| Dependency direction, release contract and exact binding drift | 14 tooling tests passed |
| Formatting and whitespace | Passed |
| x86-to-x64 IPC probe | Passed; 1,030 continuation lifecycle cycles, queued/delivered targets, five replacement modes, no pending work |

Final native logs use `frontier-` and `final-` prefixes under
`target/audit-20260909/`. Rejected-request diagnostics in the IPC probe are deliberate
negative-test evidence. They are separate from runtime errors in a game server.
Independent Luna High source reviews found no actionable issues in the three changes.

The frontier regression was observed failing before the repair. A rejected replacement
upload left a two-handle upload backed by a 513-element staging slice. Tests now inject
failure at reservation boundaries and verify previous ranges, duplicate detection,
epochs and committed order remain usable. Injection is thread-local and test-only;
this is error-path coverage, not an operating-system exhaustion experiment.

## Measured performance scope

The native audit and raw CSVs are in aphelion-dogmos:
`docs/audits/2026-09-09-performance-resource-audit.md` and
`docs/performance/2026-09-09-{topology,continuation}-lifecycle/`.

At 100,000 turfs, no-op heat re-registration reduced allocation calls from 116,666
to 16,666; clearing already absent heat reduced 100,000 calls to zero. All 27
corresponding mixture/heat/ownership hashes matched. Topology/numerical behavior
was separately checked by Rust tests; those hashes are not gameplay transcripts.

For 100 idempotent mixture updates with 2,048 pending transactions, allocation calls
dropped from 20,200 to 200 and requested bytes from 7,070,800 to 20,400. All 27
canonical callback transcript hashes matched after normalizing wall-time deadlines;
all continuations were then cancelled. Each case used three fresh repetitions.

These are service-operation allocation results and local synthetic timing observations.
Requested bytes are not peak live bytes. No DreamDaemon memory reduction, SSair speedup,
or end-to-end performance acceptance is claimed. Effective frontier deltas still need
full-view rebuilding; pipenet request frequency and allocation impact remain targets
for a measured follow-up rather than speculative representation changes.

## Game gates

| Gate | Final result | RIFT run |
| --- | --- | --- |
| Forced full build | Passed; DM zero errors/warnings, asset-input limitation below | `20260909T131807Z-429ff23c` |
| Focused Dogmos tests | 9/9 passed; zero runtimes | `20260909T134032Z-7b2fe8e5` |
| Complete MetaStation suite | 645/645 passed; zero runtimes | `20260909T144139Z-02f7ab49` |
| Final-source full RuntimeStation soak | 300 seconds passed; zero runtime signatures; clean shutdown | `20260909T150215Z-b352ae0d` |

The forced full build passed in run
`20260909T131807Z-429ff23c` (282.366 seconds overall). DMB and RSC were rebuilt, the
build child exited naturally with zero, and cleanup passed with no leftovers.
DreamMaker reported zero errors and zero warnings. Hypnagogic separately reported
40 missing icon source inputs, including `kinaris_table.png`, but returned zero, so
the build continued. The matching DMI files are checked in and consumed by DM.
The table PNG was removed by earlier cleanup commit `8218b0e9e85` while its cutter
configuration remained. This does not invalidate DM compilation, but asset
regeneration is not fully reproducible: the green full-build result must retain
that limitation. No icon assets, cutter configurations or build scripts were edited.

RIFT's offline doctor passed after repairing
the ignored embedded Python cache's site configuration and installing the repository's
pinned requirements through the maintained bootstrap. No bootstrap source was edited.

The first nine-test focused run (`20260909T132324Z-bd706351`) produced eight passes
and one runtime failure. `dogmos_service_frontier_mutation_waits_for_pending_stage`
indexed the lazy, still-null committed frontier before the first SSair cycle. Its
probe now uses a private shallow snapshot (empty when uninitialized), then restores
the exact original snapshot with the pending fields. Assertions and production code
are unchanged. The failed run is retained as red evidence; its owned processes were
cleaned up, and it is not counted as a passing focused gate.

The corrected focused run (`20260909T134032Z-7b2fe8e5`) passed all nine requested
tests with zero failures, skips or recorded runtimes. Its fresh CI compile reported
zero errors and the two expected CI warnings (reference tracking and disabled loop
checks). The test JSON, empty runtime-signature list, natural DreamDaemon exit and
successful cleanup with no leftovers agree. DreamDaemon's natural exit code was
160; the test artifacts establish the result rather than assuming that launcher or
DreamDaemon exit codes alone express test success. The run took 531.578 seconds,
including compilation and initialization. This is qualification timing, not a
matched performance comparison.

The first full-suite attempt (`20260909T135005Z-5a279669`) was interrupted after
reaching `dogmos_del_cost`. Its controller and owned game/service processes were
confirmed absent, but no final summary or test JSON was written. Its partial logs
are retained and do not establish either a complete passing suite or a test failure.
The replacement run uses a hidden background wrapper around the same maintained
RIFT commands, preserving its own PID/start-time record and final wrapper result.
The RIFT test artifacts remain authoritative for the test outcome.

The completed full-suite run (`20260909T140419Z-3395e0eb`) recorded 645 tests:
644 passed, one failed, zero skipped and zero recorded runtimes. All 115 tests with
`dogmos` names passed. The failing `maptest_mapload_space_verification` reported
181 ordinary `/turf/open/space` turfs assigned to `/area/misc/condo` on reserved
level 4, beginning at `(180,25,4)`. The full-suite gate is **failed**, not qualified
by the Dogmos subset. Its DreamDaemon exited naturally, cleanup passed with no
leftovers, and runtime signatures were empty. Total duration was 1,002.533 seconds.
The deletion-cost test passed in 170.447 seconds; its reference-tracking baseline
cost is not a production performance measurement.

The map failure matches existing content exactly:
`modular_nova/modules/condos/_maps/ship_apartment.dmm` is 19 by 32 cells, with 181
instantiations of keys `qE` and `tq`. Both define `/turf/open/space/basic` in
`/area/misc/condo`; `tq` also places a window spawner. Loading this footprint at
`(180,25,4)` reproduces the reported coordinate set. `ChangeTurf` normalizes the
basic turf to ordinary space. Both faulty definitions originate in
`a5fb3660a99f3b76a70fbbe5aae77f26265f4369`, before this update.
Neither the native changes nor the private-frontier test fixture
edit map or area content. The strict validator correctly rejects these cells.
The two faulty definitions now use the existing `/turf/open/space/bluespace`
boundary type. The condo linker assigns these turfs their room's `parentSphere`,
and the inherited boundary `Entered()` returns occupants to that linked entrance.
The grid, areas, objects and window spawner are unchanged. This repairs the intended
condo boundary behavior without weakening the strict validator.

The repaired full-suite run (`20260909T144139Z-02f7ab49`) passed **645 of 645 tests**,
including all 115 Dogmos-named tests and `maptest_mapload_space_verification`.
There were zero failures, skips, recorded runtimes or runtime signatures. The fresh
CI compile reported zero errors and the same two expected CI warnings. DreamDaemon
exited naturally (native exit 48); the result JSON and clean-run artifact establish
success, and cleanup passed with no leftovers. Overall RIFT duration was 1,236.305
seconds, including waiting for the preceding soak's workflow lock. This is not a
matched performance measurement.

An initial reclamation hypothesis was rejected: mapping already moves released
turfs through the cached global area's contents list. A standalone BYOND 516.1687
language probe confirmed both tested turfs moved correctly. The mapped 181-cell
coordinate match, rather than that hypothesis, identifies this failure.

The first five-minute soak (`20260909T142212Z-73b331eb`) failed because the requested
300-second idle timeout collided with the silent 300-second post-initialization
window. DreamDaemon's process record reports `idle_timeout`, exit 143; its service
was present in the last sample at `14:32:10.571Z`. The final child check raced that
controller shutdown and reported `required_child_missing`. Runtime signatures were
empty and cleanup passed. This run is not counted as a passing soak. The retry
keeps the same 300-second window and uses a 600-second idle limit.

That retry (`20260909T143649Z-e30107da`) passed the complete 300-second observation
window with zero runtime signatures, continuous required-child checks and successful
cleanup. DreamDaemon ended by requested stop (exit 143), as a bounded soak should.
It took 507.704 seconds including build/deployment/initialization. Its deployment
predated the two-line condo map repair; the final-source suite and soak below
provide the later qualification boundary.

The final-source soak (`20260909T150215Z-b352ae0d`) passed all 300 seconds after
initialization, with the corrected map and unchanged native pair. Its full build
reported zero errors and zero warnings. Continuous required-child checks passed,
runtime signatures were empty, DreamDaemon ended by requested stop (exit 143),
and cleanup passed with no leftovers. Overall duration was 604.770 seconds.
This was initialization and a post-readiness lobby observation. No client workload
was driven; it is not an active-round performance comparison.

The maintained `Sample-RiftProcesses.ps1` started during compilation and completed
without errors. It discovered one stable PID/start-time identity for each role.
Its CSV and metadata are `processes-250ms.csv` and `processes-250ms.json` in that
RIFT run directory. The following are sampled maxima across discovery through
shutdown, not exact lifetime peaks; attachment followed process creation.

| Process | Private MiB | Working-set MiB | Virtual MiB | Samples | Largest sampling gap |
| --- | ---: | ---: | ---: | ---: | ---: |
| DreamDaemon | 1,788.594 | 1,783.746 | 1,997.613 | 1,694 | 281 ms |
| `dogmosd` | 130.074 | 119.945 | 4,285.969 | 1,602 | 277 ms |

MiB is 1,048,576 bytes. Virtual reservations are not committed/private bytes,
and the 64-bit service figures are not added to DreamDaemon's address-space use.
The sampler does not walk memory regions, measure the largest free range, or
attribute allocations to Dogmos. These observations therefore do not establish
a DreamDaemon footprint reduction or satisfy the separate matched-performance gate.

That first run also lacked the CI database and logged repeated connection refusals.
A disposable MariaDB 10.11.19 instance was subsequently initialized under the ignored
`data/dogmos-audit-20260909/` directory, bound only to `127.0.0.1:3306`, and loaded with
both CI schemas exactly as `.github/workflows/run_integration_tests.yml` specifies.
No Windows service, global database configuration or preexisting database data was
changed. The package's official SHA-256 matched
`398ea30e5036010bbebe01d2b1804280424dcc2626e36d8e95155c04d25a0490`.
The setup follows MariaDB's [portable ZIP installation instructions](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/installing-mariadb/binary-packages/installing-mariadb-windows-zip-packages).
After qualification, the exact process identity and SQL data directory were checked
before a clean administrative shutdown. The owned database process was gone and
port 3306 had no listener. The database, sampler and test helpers were not installed
as services. Local cleanup evidence is `data/dogmos-audit-20260909/database-cleanup.json`.

Commands run from the game root use the installed `dogmos.dll` and `dogmosd.exe` pair:

```powershell
.\RIFT.cmd compile --mode full --force --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 300
$focus = @(
    '/datum/unit_test/dogmos_service_contract_identity',
    '/datum/unit_test/dogmos_service_lifecycle',
    '/datum/unit_test/dogmos_service_turf_heat_absence',
    '/datum/unit_test/dogmos_service_callback_identity',
    '/datum/unit_test/dogmos_service_frontier_generation_identity',
    '/datum/unit_test/dogmos_service_frontier_rejection_preserves_epoch',
    '/datum/unit_test/dogmos_service_frontier_mutation_waits_for_pending_stage',
    '/datum/unit_test/dogmos_service_general_reaction_subject',
    '/datum/unit_test/dogmos_service_runtime_topology_batch_preserves_neighbor_state'
)
$focusArguments = foreach ($test in $focus) { '--focus'; $test }
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json @focusArguments --minimum-tests 9 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 300
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --minimum-tests 500 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 600
.\RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json --run-seconds 300 --shim dogmos.dll --service dogmosd.exe --network offline --format result --wall-timeout-seconds 1800 --idle-timeout-seconds 600
# In a second PowerShell during that run's compilation:
.\modular_aphelion\tools\dogmos_performance\Sample-RiftProcesses.ps1 -RunDirectory data/rift-runs/20260909T150215Z-b352ae0d -TimeoutSeconds 1800
```

RIFT records are retained under
`data/rift-runs/<run-id>/`, including `summary.json`, `events.ndjson`, compiler
logs and collected runtime/test artifacts. Meridian-MCP was unavailable in this
session, so no parser/cache diagnostic gate is claimed.

Hosted CI, Linux BYOND native-load, Docker/TGS deployment, human playtesting, and a
repeated matched full-game control/candidate performance workload are separate gates.
Runtime consumers must restart to load a changed shim/service pair.

The maintained full-game comparison entry is
`modular_aphelion/tools/dogmos_performance/compare-repository.ts`, with
`Sample-RiftProcesses.ps1` and `analyze.py` alongside it. It uses the full `ci`
MetaStation workload; the `dogmos-ci` qualification profile omits Lavaland/space
levels and must not be mixed into that comparison. The saved control installed set
is not a complete release bundle with symbols, so it cannot be installed through
the maintained atomic synchronization route as-is. Rebuild a complete control
bundle from its matching clean native revision before a six-run comparison.
The analyzer also lacks a numerical/gameplay-event equivalence comparator; supply
that witness before accepting a full-game performance claim. The synthetic native
hash comparisons above do not replace it.
