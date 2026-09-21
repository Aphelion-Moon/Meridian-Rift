# Dogmos performance and memory

Only DreamDaemon memory is the footprint target. Every in-process DLL allocation is a DreamDaemon allocation. Measure private bytes, virtual size, working set and largest free address-space region along with CPU, subsystem costs and callback backlog.

Use repeated identical maps, workloads, durations, artifact hashes and BYOND versions. Report numerical/event equivalence, noise and measurement cadence. Do not sum overlapping inclusive procedure times. Avoid whole-world scans in routine telemetry and keep expensive diagnostics opt-in.
