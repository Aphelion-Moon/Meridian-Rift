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

Inspect initialization phase durations, first-three-minute turf activity, last-minute
activity, rolling stage costs, and sparse active coordinates. The analyzer reports
DreamDaemon and `dogmosd` memory separately. It does not sum overlapping procedure costs
or infer CPU usage from private bytes. Record at least three matched controls and candidates
before reporting a performance change.

For diagnosis, focus `/datum/unit_test/dogmos_shift_start_performance/profile` instead.
This also records BYOND procedure profiles separately for initialization and gameplay.
The added profiler overhead makes this a different workload; exclude these diagnostic
runs from unprofiled timing comparisons. The initialization profile begins at SSdogmos,
so it excludes earlier world and subsystem construction.
