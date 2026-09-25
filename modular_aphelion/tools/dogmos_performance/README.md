# Native and baseline performance comparison

Use `compare-repository.ts` to stage the opt-in shared observer in an isolated RIFT workspace. The wrapper detects the installed platform native library and verifies its contract. Compare identical maps, workloads, duration, configuration and BYOND versions; report initialization and gameplay separately. The archived observation case is not part of the active unit suite.

For 250 ms process samples, start this read-only helper in another administrator PowerShell
session after RIFT creates its run directory, while compilation is still in progress:

```powershell
.\modular_aphelion\tools\dogmos_performance\Sample-RiftProcesses.ps1 `
    -RunDirectory data/rift-runs/<run-id>
```

It follows that run's reported process identities and writes `processes-250ms.csv` and
`processes-250ms.json` beside the RIFT events. It exits when RIFT publishes its summary,
or fails after its bounded timeout. It never starts or stops game processes. Inspect the
metadata for attachment delays, actual sample gaps and missing processes before accepting
coverage; memory allocated before discovery is not captured. Preserve these files with
each control and candidate. The analyzer retains the original peaks from RIFT events and
reports the denser CSV separately, including virtual size, actual sample gaps and CPU time
between the first and last sample in each phase. Process lifetimes remain separate even
if Windows reuses a PID. CPU before the first sample in a phase is not included.

Inspect initialization phase durations, first-three-minute turf activity, last-minute
activity, rolling stage costs, and sparse active coordinates. The analyzer reports
whole DreamDaemon memory, which includes all native engine allocations. It does not sum overlapping procedure costs
or infer CPU usage from private bytes. Record at least three matched controls and candidates
before reporting a performance change.

For diagnosis, focus `/datum/unit_test/dogmos_shift_start_performance/profile` instead.
This also records BYOND procedure profiles separately for initialization and gameplay.
Focusing the ordinary parent takes precedence and disables this explicit diagnostic mode, including when the
test framework inherits its focus flag into the diagnostic subtype. The report's
`diagnostic_procedure_profiling` field records this explicit mode only. The master
controller can also start profiling through a lag-triggered dump, even with AUTO_PROFILE
disabled: BYOND's PROFILE_REFRESH starts or continues profiling. The analyzer lists these
`procedure_profile_dumps` and sets `procedure_profiling` to true when either source is
present. This means profiling was active at some point, not throughout the whole window;
null means unknown. An ordinary focus alone does not establish an unprofiled run.
The added profiler overhead makes this a different workload; exclude these diagnostic
runs from unprofiled timing comparisons. The initialization profile begins at SSdogmos,
so it excludes earlier world and subsystem construction.

## Clean no-Dogmos comparison

Use `compare-repository.ts` to run the same focused 180-second observer against
an explicit checkout. Invoke it with the repository-pinned Bun from the checkout
under test, or with an equivalent pinned Bun selected by the RIFT preflight. The
wrapper uses the maintained RIFT workflow and CI profile, copies the original DME
to a run-owned scratch DME, and includes the generic observer by absolute path at
runtime. The tracked DME, build scripts, deployment files, and map files remain
unchanged.

```powershell
& "<RIFT_REPOSITORY_ROOT>\tools\bootstrap\.cache\bun-v<BUN_VERSION>-x64\bun.exe" `
    modular_aphelion/tools/dogmos_performance/compare-repository.ts `
    --repository <BASELINE_REPOSITORY_ROOT> `
    --map _maps/metastation.json
```

Repeat with `_maps/runtimestation.json` for the full Runtime Station map.
Keep the CI profile, map, fixed `UNIT_TESTS` seed, observer window, profiling
mode, and cache state identical between control and candidate runs. The wrapper
auto-detects a complete installed Dogmos pair and then verifies it against the
checkout contract; the candidate uses full CI map defines plus Dogmos fatal-log
and continuous-child rules. A checkout with partial Dogmos markers fails closed
instead of being treated as a baseline. Record the RIFT summary and
`dogmos-performance.jsonl` together; this is a matched control/candidate
measurement, not a production performance qualification.

The wrapper records hashes of the observer, wrapper, selected map, and candidate
native pair as run artifacts. It records the selected cache mode and provenance;
use `--cache-mode cold-isolated --cache-root <PREPROVISIONED_CACHE_ROOT>` when a
pre-provisioned isolated cache is required. The default `shared-pinned` mode
preserves the configured repository cache and does not warm or normalize it.
Procedure profiling is recorded as unknown for ordinary observations because
BYOND may start profiling through `PROFILE_REFRESH`; the diagnostic mode flag is
false. Profile dumps and runtime artifacts determine whether profiling occurred.
