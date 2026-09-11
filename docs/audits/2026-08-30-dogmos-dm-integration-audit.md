# Dogmos DM Integration Audit

Date: 2026-08-30

## Scope

This audit follows the complete DreamMaker-side path from `SSair` frontier creation through synchronous service stages, callback delivery, gameplay effects, mixture-cache invalidation, subsystem recovery, and Kennel reporting. It separates confirmed defects from structural costs and unqualified performance risks. No implementation changes were made.

The inspected Meridian-Rift revision is `dfd461a55f500ef20bab641b4908456ebd0ab7cf` on `dogmos`. The inspected standalone Dogmos revision is `1fa2abe68dc0675327efa53a7559c7f49445829f` on `master`; it is clean and 18 commits ahead of its configured upstream. The standalone revision has advanced beyond the handoff's recorded revision, so any later native qualification must lock the current source and artifact identity again.

## Baseline evidence

- Meridian-MCP parsed `tgstation.dme` successfully at analysis generation 1: 450,258 indexed symbols, 64,855 types, lexical index ready, dense index not configured. Parser success is discovery evidence, not compilation evidence.
- The cached SpacemanDMM snapshot contains a large repository baseline: 139 errors and 1 warning overall. Dogmos-focused changed-file checks found no diagnostics in `service_backend.dm` or `dogmos.dm`, one inherited hint in the SSair override, and one unconfigured static-type warning in `dogmos_kennel_events.dm`.
- `tools/dogmos/test_compile_check.ps1` fails before compilation with its default BYOND discovery path. Running the same maintained gate with an explicit compiler path produced a fresh `tgstation.dogmos-tests.dmb` with 0 errors and 2 expected warnings.
- A focused `tools/dogmos/run_tests.ps1` run recorded 4 passing tests, 0 failures, and 0 runtime signatures: `dogmos_ssair_recovery`, `dogmos_service_topology_stage_barrier`, `dogmos_service_callback_identity`, and `dogmos_kennel_process_metrics`.
- `tools/dogmos/sync_contract.ps1 -VerifyOnly` cannot run because the standalone checkout has no `dogmos-release-manifest.json` or `release-bundle`. Contract convergence is therefore unqualified, not failed.
- Two-process boot, the wider DM suite, three identity-matched control runs, Tracy comparison, and matched process-memory comparison were not run. This audit makes no measured performance or memory-improvement claim.

## Execution path

`/datum/controller/subsystem/air/fire()` processes the active-turf frontier first, then excited groups, high-pressure equalization, and the heat graph. `/datum/controller/subsystem/air/process_active_turfs()` performs the TURFS and REACTIONS service stages and then invokes `/proc/process_atmos_callbacks()`. Each `/datum/controller/subsystem/air/dogmos_run_stage()` call is synchronous and derives a work limit from the remaining tick budget. Later stage callbacks can remain queued until the next active-turf callback drain.

Runtime topology mutations are coalesced in `SSdogmos` and deferred while `SSair.dogmos_pending_frontier_epoch` is set. The heat-stage completion path clears the committed frontier and attempts the deferred topology flush.

The service owns mixture state. DreamMaker retains slot/generation identity tables, a direct-mapped snapshot cache, callback cursors, and gameplay object references. `SSair` owns stage/frontier and Kennel state. These ownership boundaries are correct in the ordinary path but incomplete during full subsystem recovery.

## Findings

### F-01 — P0: full subsystem recovery replaces `SSdogmos` with blank identity and lifecycle state

**Surface:** `/datum/controller/subsystem/dogmos`, `/proc/recover_all_SS_and_recreate_master()`, `/datum/controller/master/init_subsystem()`, and `/datum/unit_test/dogmos_ssair_recovery`.

`/datum/controller/subsystem/dogmos` has no local `Recover()`; it inherits the empty base implementation. Full MC recovery constructs every subsystem again and relies on each new instance's `Recover()`. The replacement Dogmos subsystem therefore starts with `service_ready = FALSE`, empty mixture/holder/gas/reaction identity registries, reset callback sequence and pending batches, empty topology queues, and a new cache epoch.

The master then initializes subsystems unless `SS_NO_INIT` or `initialized` suppresses initialization. A blank Dogmos replacement can consequently call `auxtools_atmos_init()` and start/reinitialize the service during a live round, while every extant gas mixture still carries handles issued by the previous identity tables.

The existing recovery test passed, but it constructs only a replacement `SSair`. It explicitly asserts that the original `SSdogmos`, service PID, and service world generation remain unchanged; it never replaces `SSdogmos` and never exercises the all-subsystem recovery contract.

**Boundary:** DM service lifecycle and all service-handle identity.

**Failure mode:** duplicate or reset service lifecycle, orphaned DM handles, stale callback identity, lost pending topology, and cache identity discontinuity after MC recovery.

**Verification route:** add a full Dogmos replacement recovery test that seeds representative identity, callback, topology, and cache state; construct/recover the replacement; assert the service PID and world generation are unchanged; assert every transferred identity/cursor is preserved; then run focused recovery tests, a fresh compile, and a two-process boot/recovery probe.

### F-02 — P1: callback draining performs uncharged work and dispatches once with no budget

**Surface:** `/proc/process_atmos_callbacks(remaining)` and `/datum/controller/subsystem/air/finish_turf_processing_auxtools()`.

When no retained batch exists, `process_atmos_callbacks()` calls `dogmos_callback_drain()`, validates the complete returned batch, and queries queue remainder before capturing `start_tick_usage`. IPC, response-list construction, and validation therefore do not reduce the function's callback budget.

The dispatch loop checks elapsed budget only after dispatching an event. A call with `remaining <= 0` still dispatches one event when a batch is available. This violates the documented rule that Dogmos work consumes the same SSair tick budget as the work it replaces.

No focused unit test covers zero-budget entry, retained-batch resumption, or charging drain/validation setup against the callback allowance.

**Boundary:** SSair scheduling and typed gameplay callback delivery.

**Failure mode:** callback work escapes the assigned budget and can extend a tick after SSair has exhausted its allowance.

**Verification route:** seed a retained callback batch in a focused test, call with zero budget, and assert the cursor and gameplay-observable counters do not advance; add a resume-order assertion; place the timing boundary before drain/validation; then use repeated identity-matched Tracy controls before making a timing claim.

### F-03 — P1: stale general-reaction mixture identity is silently skipped instead of failing closed

**Surface:** `/datum/controller/subsystem/dogmos/dispatch_general_reaction_callback()` and `/datum/controller/subsystem/dogmos/dispatch_reaction_callbacks()`.

The general callback path resolves the mixture slot/generation and, on failure, increments `dogmos_stale_callback_count` and returns. The direct reaction transaction path instead crashes when the callback mixture is not the expected live mixture. The gameplay-event contract defines a stale reaction mixture as fatal to the stage; only a stale holder may suppress holder-dependent effects.

The passing `dogmos_service_callback_identity` test covers a stale turf generation only. It does not exercise a stale general-reaction mixture or distinguish stale mixture from stale holder behavior.

**Boundary:** typed callback identity, reaction ordering, and gameplay equivalence.

**Failure mode:** a committed service reaction can lose DM-side gameplay effects while the stage continues, leaving native mixture mutation and visible gameplay out of sync.

**Verification route:** factor deterministic subject validation from fatal handling, test stale mixture rejection and stale holder suppression separately, then run the reaction-focused suite, fresh compile, and two-process callback delivery probe.

### F-04 — P2: Kennel ordinary refresh repeats whole-list work per viewer

**Surface:** `/datum/dogmos_kennel/ui_data()`, `/datum/dogmos_kennel/build_machinery_browse_page()`, and `SStgui.update_uis(GLOB.dogmos_kennel)` from SSair.

Each UI data refresh samples process metrics, prunes pin history, and—outside slow mode—walks the complete `SSair.atmos_machinery` list once to count matches and again to materialize the requested page. SSair requests UI updates every cycle outside slow mode, so the same producer work is repeated per open viewer.

This is a confirmed scaling mechanism, not a measured bottleneck. The scan is over the atmosphere-machinery registry, not every world atom. The passing `dogmos_kennel_process_metrics` test checks decoded data, not refresh cadence, viewer multiplication, or browse scan count.

**Boundary:** admin observability and DreamDaemon memory/CPU only.

**Cost mechanism:** O(viewers × atmosphere machinery) filtering and repeated transient list construction during ordinary refresh.

**Verification route:** add producer counters and a focused multi-viewer cadence test before changing behavior; profile at least three matched controls; if material, cache sampled process metrics and maintain a bounded browse index invalidated by machinery lifecycle rather than rebuilding it per viewer.

### F-05 — P2: maintained compile gate's default compiler discovery throws under strict mode

**Surface:** `tools/dogmos/_common.ps1` `Resolve-DogmosToolPath()` as invoked by `tools/dogmos/test_compile_check.ps1`.

The resolver probes a missing registry key and immediately dereferences `(Get-ItemProperty ...).installpath` under `Set-StrictMode -Version 2.0`. The missing key yields an object without that property, so discovery throws before it reaches the valid alternate BYOND registry location.

An explicit compiler path bypasses the defect and the compile succeeds. Existing `tools/dogmos/tests/ProcessHelpers.Tests.ps1` does not cover missing-first/present-second registry probing.

**Boundary:** local maintained verification tooling.

**Failure mode:** the documented default compile command fails on a normal 64-bit Windows BYOND installation.

**Verification route:** add a mocked registry-probe test, guard the property lookup, run the PowerShell tests, and rerun the compile gate without an explicit path.

### F-06 — P3: Kennel event code retains one static-type diagnostic

**Surface:** `/datum/controller/subsystem/air/kennel_pin_structure()` in `code/controllers/subsystem/dogmos_kennel_events.dm`.

DreamChecker reports `proc_call_static_type` at the optional `resolve()` call because the `structures_of_interest` loop entry is not statically annotated as a list. DreamMaker accepts the file, but the current source does not meet the repository's typed homogeneous-list convention.

**Boundary:** Kennel pin and overlay maintenance.

**Verification route:** add the list annotation and `as anything` iteration form, then reparse and require zero diagnostics in the changed file.

### F-07 — P3: superconduction documentation describes an obsolete asynchronous worker

**Surface:** `/datum/controller/subsystem/air/process_super_conductivity()` documentation and the current `process_turf_heat()` stage path.

The comment says the heat graph runs through an asynchronous Rust worker and does not consume SSair tick budget. The implementation synchronously invokes the Dogmos service stage, and SSair records `cost_superconductivity`. This is documentation drift, not a runtime defect.

**Boundary:** maintainer-facing scheduling documentation.

**Verification route:** replace the stale statement with the current synchronous, budgeted service-stage contract and run doc/style review.

## Structural risks requiring evidence

### R-01 — topology deferral is world-bounded but has no explicit producer capacity

`flush_turf_registration_batch()` defers while a frontier is committed. `flush_full_turf_registration_batch()` ignores a deferred `FALSE` result, so lifecycle and edge maps continue to coalesce. Duplicate keys are collapsed, which bounds growth by world topology rather than elapsed time, but there is no smaller producer-side capacity or test covering queue pressure and eventual drain after a long stage. Existing telemetry records the maximum queued count and deferrals; the focused test checks only the deferral barrier.

Do not add dropping or an arbitrary cap without evidence. First add a stress fixture that holds a frontier, generates repeated lifecycle/adjacency churn, verifies coalescing cardinality, clears the frontier, and proves complete ordered drain.

### R-02 — DM tests do not prove the native callback field-validation boundary

DM validates batch length/count/scope/transaction and sequence, then validates known kinds and object generations while dispatching. The contract assigns allowed flags and finite numeric-field validation to the shim. No DM fixture injects malformed flags or non-finite values and proves rejection before gameplay. This audit found no evidence that production accepts them; the gap is cross-boundary qualification coverage.

### R-03 — performance and memory qualification is absent

There are no current three-run matched DreamDaemon controls tied to this revision/artifact identity. Kennel scan work, callback setup cost, list construction, service-stage latency, DreamDaemon private bytes, service private bytes, callback depth, stale rejection, and topology queue pressure therefore remain unmeasured. Service RSS must remain separate from DreamDaemon's constrained address space.

## Mixture snapshot-cache inventory

The inspected cache path is internally consistent on ordinary command routes:

- `dogmos_snapshot()` fetches the exact slot/generation through `SSdogmos.mixture_snapshot()` and stores only validated fixed-length snapshots.
- Snapshot-backed scalar/gas readers and local `compare()` reuse that cache.
- `dogmos_command()` evicts both primary and secondary handles for every command not listed as read-only.
- `__adjust_multi()` and `__react()` bypass the generic wrapper but explicitly evict the mutated handle.
- `unregister_mixture()` evicts the exact retiring handle before slot reuse.
- Committed service-stage mutation invalidates the cache epoch in O(1); incomplete stage chunks do not expose intermediate mutation as committed DM state.

No specific read-after-write or stale-handle cache defect was confirmed in the inspected paths. Existing golden mixture tests provide broad behavior coverage, but the implementation plan adds focused aliasing, immutable-mixture, deletion/reuse, secondary-handle, and reaction-effect cases before treating this boundary as complete.

## Priority order

1. Restore `SSdogmos` recovery semantics and prove service/identity continuity.
2. Make callback draining obey its assigned budget, including setup cost and zero-budget entry.
3. Enforce fail-closed general-reaction subject identity while retaining stale-holder suppression.
4. Repair the default compile gate so subsequent work has a reliable maintained local command.
5. Add topology pressure and callback-validation qualification coverage.
6. Measure Kennel producer cost before optimizing it.
7. Clear the local static diagnostic and stale scheduling documentation.

The implementation sequence is specified separately in `docs/superpowers/plans/2026-08-30-dogmos-dm-integration-plan.md`.
