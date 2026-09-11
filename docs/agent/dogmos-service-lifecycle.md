# Dogmos service lifecycle

The current audited `dogmos.dll` is in-process. The target process split adds a thin 32-bit shim and an adjacent 64-bit `dogmosd` service. Initialization is atomic:

1. Resolve the manifest-pinned service beside the shim.
2. Create an unpredictable per-world local endpoint and launch the child without a visible window.
3. Validate source revision, ABI, protocol, feature fingerprint, executable identity, process IDs, world nonce, and capacity limits.
4. Only after success register gases, reactions, mixtures, turfs, and adjacency.

A startup mismatch returns exact expected/actual diagnostics, cleans the child/transport, and fails `SSdogmos.Initialize()` before partial gas state exists. Startup retry is allowed only before registration.

After initialization, `dogmosd` is authoritative for atmosphere state. Timeout, corrupt response, service death, or protocol mismatch fails closed and initiates the approved controlled server-shutdown path. Never restart an empty service mid-round or fall back to an in-process arena. Safe restart requires a separately reviewed checksummed snapshot/journal design.

DreamDaemon shutdown closes the client and terminates the exact service process tree. On Windows use kill-on-close job containment when available plus validated parent-process monitoring; on Linux use parent-death signaling with a PID/start-identity check. Repeated shutdown is idempotent. Killing either process in a scratch fault test must not leave an orphan.

Master-controller recovery transfers DM-owned settings, histories, bounded queues, pins/weakrefs, counters, reaction ordering, and healthy service-session metadata. Rebuild derived overlays/cursors. Rebind to the same service PID/world generation; do not initialize a second world. An unhealthy session remains fatal.

Typed service events carry stable handles, generations, sequence order, and bounded payloads. Resolve them on DreamDaemon's main thread, reject stale targets, and drain within the remaining SSair budget. A DM reaction continuation is single-use and resumes only after the service released simulation locks.
