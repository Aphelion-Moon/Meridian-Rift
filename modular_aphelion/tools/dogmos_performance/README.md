# Initialization and first-three-minute measurements

Run only the opt-in observation case through the existing RIFT controller:

```powershell
.\RIFT.cmd test --profile ci --map _maps/metastation.json `
    --focus /datum/unit_test/dogmos_shift_start_performance `
    --shim dogmos.dll --service dogmosd.exe `
    --wall-timeout-seconds 1800 --readiness-timeout-seconds 900 --format result
python modular_aphelion/tools/dogmos_performance/analyze.py `
    data/rift-runs/<run-id> --output data/performance-qualification/<label>.json
```

The CI configuration needs its local database. The `ci` profile retains the full map's
auxiliary levels; `dogmos-ci` deliberately skips Lavaland and space levels, so it is a
different workload. Do not combine those profiles in a timing comparison.

The ordinary test build already fixes the random seed, disables offline suspension, and
starts actual gameplay. Only explicitly focusing this case starts the sampler. It observes
from Dogmos initialization through three wall-clock minutes after the first observed playing
state. Actual timestamps record scheduling delays. The record is streamed to the run's
`dogmos-performance.jsonl` log; no history is retained in DreamDaemon.

These are controlled test-build observations. The unit-test framework adds a fixture room
about ten seconds into gameplay, and its debug instrumentation differs from production.
Use identical builds, map, seed, population, configuration and sampling for each comparison.
They do not replace a production server Tracy capture. A passing observation case establishes
coverage and service availability, not acceptable speed or settled turfs.

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
DreamDaemon and `dogmosd` memory separately. It does not sum overlapping procedure costs
or infer CPU usage from private bytes. Record at least three matched controls and candidates
before reporting a performance change.

For diagnosis, focus `/datum/unit_test/dogmos_shift_start_performance/profile` instead.
This also records BYOND procedure profiles separately for initialization and gameplay.
Focusing the ordinary parent takes precedence and disables profiling, including when the
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
