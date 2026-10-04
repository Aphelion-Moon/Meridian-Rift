# Windows in-process play-test

The current candidate selects the root `dogmos` engine in 32-bit DreamDaemon.
The generated bindings define `DOGMOS_IN_PROCESS`; the game selects native
atmosphere calls while preserving newer machinery, recovery, reaction types,
resumable exposure/visual walks and topology callers. Service sources remain
available behind the alternate compile branch. No `dogmosd` is launched by this
backend. Its process metrics are unavailable in Kennel; host metrics remain live.

Build `aphelion-dogmos` with `tools/build_in_process.ps1`, then install its complete
bundle from this repository using:

```powershell
python -B tools/dogmos/sync_in_process.py --bundle <bundle> --native-root <aphelion-dogmos>
python -B tools/dogmos/verify_contract.py verify-installed --root .
tools/build/build.bat build
```

Synchronization verifies the native source snapshot, hashes, i686 architecture,
binding identity and feature selection before replacing the DLL, bindings, lock
and generated contract together. Failure restores the previous files. The
canonical lock explicitly identifies an **unqualified in-process play-test**;
service release validators do not accept it as a paired release. PDBs and the
source snapshot remain in the build bundle for debugging and provenance.

This candidate is Windows-only. Generated bindings select `libdogmos_in_process`
on Linux so the retained `libdogmos.so` service shim cannot be loaded accidentally.
No Linux in-process binary is shipped by this workflow.

The bundle remains unqualified: synchronization and compilation do not establish
runtime, numerical, performance or release acceptance. Run in-process integration
fixtures with the installed DLL through the ordinary `ci` profile, for example:

```powershell
RIFT.cmd test --profile ci --map _maps/runtimestation.json --focus /datum/unit_test/dogmos_gas_fdm_golden
```

The shared numerical, recovery and Kennel fixtures select the installed backend's
contract. Keep focused tests, native-load boot, the full suite and repeated
whole-DreamDaemon performance/memory comparisons as separate evidence.
Service-specific RIFT profiles require paired service artifacts and are not
applicable to this candidate.
