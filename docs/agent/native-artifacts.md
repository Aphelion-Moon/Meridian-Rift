# Native artifact contract

`dogmos.lock.json` selects the Windows source-bound in-process i686 bundle; `dogmos-linux.lock.json` selects its Linux counterpart. Both use the same source snapshot and generated bindings. Windows uses `dogmos.dll`; Linux uses `libdogmos_in_process.so`. The manifest includes the exact source revision and snapshot hash, pinned toolchain, selected features, build arguments and artifact hashes.

Generated `code/__DEFINES/dogmos_bindings.dm` and `code/__DEFINES/dogmos_contract.dm` must match the native library. Never hand-edit them. Build through Aphelion-Dogmos's maintained builder and install with `tools/dogmos/sync_in_process.py`; verification checks source inventory, architecture, hashes and deterministic defines. Installation restores prior files if validation fails.

Authorized implementation includes rebuilding and synchronizing local artifacts. Publication, live deployment and production restarts remain separate operations. A local playtest manifest does not assert release qualification.

## Separate qualification evidence

Build manifests deliberately retain `tests_run: false` and `runtime_qualified: false`.
Keep qualification in a separate JSON record beside its hashed evidence, then run
`python -B tools/dogmos/verify_contract.py verify-qualification --root . --record <record>`.
The schema is version 1, kind `dogmos-qualification`. Required fields are:

- `target`, `native_revision`, `source_sha256`, `binary_sha256`, `bindings_sha256`, and `features`, matching the installed target manifest exactly;
- `game_revision` (40 hex characters) and `game_binary_sha256` (the tested `tgstation.dmb`);
- `workload`, an object containing a nonempty `id` and the workload's map, population, duration and scenario details;
- `acceptance: "human-reviewed"`, recorded only after an operator reviews the actual workload and results;
- nonempty `evidence`, with record-relative `path` and `sha256` for each retained file. Paths cannot escape the record directory.

This command verifies identity and evidence integrity. It cannot establish that a
claimed human review happened or that the workload was representative. Record
focused/full tests, boot, gameplay, repeated performance comparisons and human
acceptance separately; successful build/synchronization does not fill those gates.
Keep records in the central verification archive, not in generated artifact locks.
