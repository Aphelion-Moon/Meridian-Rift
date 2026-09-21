# Native artifact contract

`dogmos.lock.json` selects the Windows source-bound in-process i686 bundle; `dogmos-linux.lock.json` selects its Linux counterpart. Both use the same source snapshot and generated bindings. Windows uses `dogmos.dll`; Linux uses `libdogmos_in_process.so`. The manifest includes the exact source revision and snapshot hash, pinned toolchain, selected features, build arguments and artifact hashes.

Generated `code/__DEFINES/dogmos_bindings.dm` and `code/__DEFINES/dogmos_contract.dm` must match the native library. Never hand-edit them. Build through Aphelion-Dogmos's maintained builder and install with `tools/dogmos/sync_in_process.py`; verification checks source inventory, architecture, hashes and deterministic defines. Installation restores prior files if validation fails.

Authorized implementation includes rebuilding and synchronizing local artifacts. Publication, live deployment and production restarts remain separate operations. A local playtest manifest does not assert release qualification.
