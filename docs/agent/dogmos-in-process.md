# In-process Dogmos

Dogmos runs inside 32-bit DreamDaemon. The root engine owns gas arenas, gas and heat graphs, numerical workers and callback queues. DM owns scheduling, identity and gameplay effects. Callbacks run on the main thread.

Use the matching native library, generated bindings and the platform lock (`dogmos.lock.json` on Windows, `dogmos-linux.lock.json` on Linux). Install a source-bound bundle with `python -B tools/dogmos/sync_in_process.py --bundle <bundle> --native-root <native-checkout>`. Windows uses `dogmos.dll`; Linux uses `libdogmos_in_process.so` and requires glibc 2.34 or newer; the container base provides 2.35. Verify with `python -B tools/dogmos/verify_contract.py verify-installed --root .`.

Compile via `BUILD.cmd`. Use the maintained test/boot tools and distinguish compilation, focused/full tests, runtime initialization and populated play. All native allocations consume DreamDaemon address space. A local playtest manifest is not release qualification.
