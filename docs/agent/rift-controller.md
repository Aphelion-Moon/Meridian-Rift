# RIFT controller

Use `RIFT.cmd` for isolated compile, run, test and bounded soak workflows. Dogmos profiles verify the installed native artifact contract before launch. They require one native library and no companion process. An optional `--native dogmos.dll` overlay must match the installed contract and is copied only into the isolated workspace.

```powershell
.\RIFT.cmd run --profile dogmos --map _maps/runtimestation.json --format result
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_registration --format result
.\RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json --run-seconds 300 --format result
```

Profiles fail on runtime errors and native panic logs. Results report whole DreamDaemon memory and normalized runtime signatures. Compare identical artifacts, maps, duration, configuration and workload. A focused test or boot is not the full suite. See [RIFT tooling](../../tools/rift/README.md).
