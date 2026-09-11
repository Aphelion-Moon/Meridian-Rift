# Dogmos DM Integration Implementation Plan

> For agentic workers: use `superpowers:executing-plans` to implement this plan task by task. Do not dispatch subagents without explicit user approval. Leave all changes uncommitted unless the user explicitly authorizes commits.

**Goal:** Repair the confirmed DM lifecycle, callback-budget, and reaction-identity defects; strengthen bounded-work evidence; and qualify any subsequent performance changes without changing the Dogmos protocol or service authority.

**Architecture:** Keep `dogmosd` authoritative for atmosphere state and keep DreamMaker responsible only for gameplay objects, exact handle translation, scheduling, and observability. Preserve a single service session across MC recovery. Charge synchronous callback work to SSair's existing budget. Treat stale reaction subjects as stage-fatal while retaining the documented stale-holder exception. Measure structural costs before optimizing them.

**Technology:** BYOND Dream Maker 516.1687, DreamDaemon unit tests, Meridian-MCP parse/diagnostics/Tracy tools, PowerShell-maintained Dogmos gates, and the existing generated Dogmos bindings.

**Source audit:** `docs/audits/2026-08-30-dogmos-dm-integration-audit.md`

## Global constraints

- Work in the existing `dogmos` checkout; do not create a worktree or change branches.
- Use Meridian-MCP for DM discovery, exact symbol inspection, references, parse, diagnostics, and Tracy. Use PowerShell for builds, tests, processes, and memory measurement.
- Do not edit protocol constants, generated bindings, native artifacts, dependencies, workflows, build/bootstrap files, Docker, TGS, or deployment configuration without separate explicit approval.
- Do not author or materially rewrite protected creative content or user-facing Kennel names/copy.
- Preserve all unrelated working-tree changes. Do not commit, push, reset, checkout, merge, or clean.
- Every DM edit follows the current STYLE, AUTODOC, STANDARDS, placement, and marker guides.
- A focused test is iteration evidence only. Apply the full completion ladder in Task 9.

## Task 1: Restore the maintained default compile gate

**Files:**

- Modify: `tools/dogmos/_common.ps1`
- Modify: `tools/dogmos/tests/ProcessHelpers.Tests.ps1`

1. Add a failing Pester case for `Resolve-DogmosToolPath()` where the first registry candidate is absent and a later candidate exposes `installpath`.
2. Run the focused PowerShell test and confirm the strict-mode property error is reproduced.
3. Change registry probing to test key/property existence before reading `installpath`; preserve explicit-path and environment-variable precedence.
4. Run `tools/dogmos/tests/ProcessHelpers.Tests.ps1` and then `tools/dogmos/test_compile_check.ps1` without an explicit compiler path.
5. Record the compiler version and require a fresh DMB with 0 errors. Do not weaken the runner's freshness or cleanup checks.

## Task 2: Preserve `SSdogmos` and the live service session across MC recovery

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/dogmos.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `code/modules/unit_tests/dogmos_ssair_recovery.dm`

1. Extend the recovery test so it creates and recovers a replacement `/datum/controller/subsystem/dogmos`, not only `SSair`. Seed representative mixture and holder slot/generation tables, gas/reaction registries, callback sequence and retained-batch cursors, topology queues/indexes/counters, and mixture-cache epoch/counters.
2. Before replacement, record `dogmos_service_pid()` and `dogmos_service_world_generation()`. Assert after recovery that both are unchanged and the service remains healthy.
3. Assert the replacement transfers every Dogmos-owned mutable field listed by `dm_get_type`, including list identity where live datums depend on shared registries. Assert the old service is neither stopped nor started again.
4. Implement `/datum/controller/subsystem/dogmos/Recover()` following existing subsystem recovery semantics: set `SS_NO_INIT`, preserve `initialized`, and transfer all service-session, identity, callback, topology, and cache state from the previous global `SSdogmos`.
5. Keep `Initialize()` as cold-start-only. Do not add reconnect, re-registration, or protocol behavior to recovery.
6. Re-run both Dogmos and SSair recovery tests. Then run a two-process boot and invoke the supported MC recovery route, checking durable logs for duplicate service startup, stale handles, callback sequence errors, and service PID/world-generation changes.

## Task 3: Enforce callback budget before setup and dispatch

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

1. Add `/datum/unit_test/dogmos_service_callback_budget`. Seed a syntactically valid retained general-callback batch and its cursor/count without relying on a new native test endpoint.
2. Call `/proc/process_atmos_callbacks(0)` and assert the pending index, sequence, stale counter, and gameplay target state do not advance.
3. Add multiple ordered events, allow a bounded positive budget, and assert partial progress retains the batch and resumes in exact sequence on the next call.
4. Move the tick-usage start point before `dogmos_callback_drain()`, response validation, and queue-remainder lookup. Check the available allowance before each dispatch, including the first.
5. Preserve retained-batch validation caching: do not re-walk an already validated batch on each resume.
6. Confirm a positive budget eventually drains the queue without reordering or starvation. Run the focused callback budget, callback identity, and callback delivery tests.

## Task 4: Fail closed on stale general-reaction mixtures

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`
- Verify against: `docs/agent/dogmos-gameplay-events.md`

1. Add a small deterministic validator/helper that distinguishes a stale reaction mixture from a stale holder. Keep fatal reporting in the dispatcher so the helper can be unit-tested without intentionally contaminating the unit-test runtime log.
2. Add a focused test with three cases: live mixture/live holder dispatches; live mixture/stale holder suppresses only holder-dependent effects and increments the documented stale telemetry; stale mixture is rejected as fatal before any gameplay handler runs.
3. Change `dispatch_general_reaction_callback()` to use the same fail-closed mixture-subject policy as `dispatch_reaction_callbacks()`. Include callback sequence, kind, slot, and generation in the durable diagnostic without exposing machine-specific data.
4. Preserve exact callback order and do not convert the stale-holder exception into a fatal error.
5. Run focused callback and reaction-equivalence tests, then a two-process callback delivery probe.

## Task 5: Prove topology deferral coalesces and drains under pressure

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`
- Modify only if evidence requires it: `modular_aphelion/modules/dogmos/code/service_backend.dm`

1. Extend `dogmos_service_topology_stage_barrier` or add a dedicated pressure test. Hold a committed frontier, repeatedly register/unregister the same turfs and gas/heat edges, and assert the keyed queues coalesce instead of growing with operation count.
2. Record queue cardinality and `dogmos_runtime_topology_max_queued`; verify the maximum reflects retained unique work.
3. Clear the frontier, flush, and assert all final lifecycle and adjacency state reaches the service in order with no leftover queue/index entries.
4. Exercise a replacement generation for the same slot and prove old-generation pending edges are discarded through the reverse index.
5. Do not add dropping or an arbitrary producer cap unless the test or matched profile demonstrates world-cardinality growth is operationally unsafe. If a cap becomes necessary, stop and obtain design approval because overflow semantics affect correctness.

## Task 6: Complete mixture-cache boundary tests

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`
- Modify only for a reproduced defect: `modular_aphelion/modules/dogmos/code/service_backend.dm`

1. Add focused cases for a cached read followed by each mutation class: primary-only, primary-plus-secondary, `__adjust_multi`, direct reaction, committed service stage, unregister/reuse, and immutable mixture rejection.
2. For two-handle commands, prefill both cache entries, mutate, and assert neither handle can return its pre-mutation snapshot.
3. Reuse a retired slot with a new generation and assert the old generation never hits the cache or resolves as the new mixture.
4. Verify an incomplete service-stage chunk does not expose an intermediate cache epoch, while the committed chunk invalidates exactly once.
5. Run the new cache tests together with the existing gas-mixture golden tests. Change production cache code only if a test reproduces a real stale read or avoidable invalidation.

## Task 7: Measure Kennel producer work before optimizing it

**Files:**

- Modify for measurement/tests: `code/controllers/subsystem/dogmos_kennel.dm`
- Modify for lifecycle indexing only if measured: `code/controllers/subsystem/dogmos_kennel_events.dm`
- Modify tests: `code/modules/unit_tests/dogmos_kennel_process_metrics.dm`
- Add or modify a focused Kennel browse test under `code/modules/unit_tests/`

1. Add bounded producer telemetry for process-metric sampling cadence, machinery candidates inspected, browse pages built, and active Kennel viewers. Do not log per-item data.
2. Add a focused test proving two viewers currently multiply scan/build work and proving slow mode suppresses machinery browsing.
3. Establish at least three clean, identity-matched DreamDaemon controls with representative machinery count and one-, two-, and several-viewer phases. Capture Tracy, DreamDaemon private bytes, service private bytes, callback depth, stale rejections, and topology pressure separately.
4. Only if the cost exceeds control noise, cache process metrics at a subsystem-owned cadence and maintain a lifecycle-invalidated machinery browse index. Keep paging/search results and permissions identical.
5. Re-run the same matched phases at least three times. Report distributions and control noise; do not claim memory savings from lower stable service RSS.

## Task 8: Clear local diagnostics and scheduling documentation drift

**Files:**

- Modify: `code/controllers/subsystem/dogmos_kennel_events.dm`
- Modify: the file containing `/datum/controller/subsystem/air/process_super_conductivity()` after exact Meridian-MCP definition lookup

1. Update the `structures_of_interest` loop in `kennel_pin_structure()` to the repository's statically typed homogeneous-list iteration form.
2. Replace the obsolete asynchronous-worker statement with the current synchronous, SSair-budgeted Dogmos heat-stage behavior. Do not add discretionary commentary beyond the corrected API documentation.
3. Reparse `tgstation.dme` and require zero diagnostics in both changed files. Do not claim the repository-wide cached baseline is clean.

## Task 9: Completion ladder

1. Reparse `tgstation.dme` with Meridian-MCP after all DM edits.
2. Run changed-file diagnostics and exact symbol/reference checks for recovery, callback dispatch, cache invalidation, and Kennel producer changes.
3. Run all new focused tests plus existing Dogmos recovery, callback, topology, cache/golden-mixture, reaction, and Kennel tests.
4. Run `tools/dogmos/sync_contract.ps1 -VerifyOnly` only after a current identity-locked release manifest and bundle exist. If absent, report the gate unavailable and do not synthesize artifacts without authorization.
5. Run `tools/dogmos/test_compile_check.ps1` and require a fresh compile with 0 errors.
6. Run `tools/dogmos/boot_probe.ps1` with identity-matched shim and service artifacts; verify both processes, initialization completion, service health, and clean shutdown.
7. Run the wider maintained Dogmos/DM unit suite and require a final runner result with no runtime signatures.
8. For any performance or memory claim, collect at least three before and three after identity-matched runs with fixed map, config, seed, player/client conditions, warmup, and capture windows. Use Meridian-MCP control statistics before interpreting deltas.
9. Review `git diff --check`, inspect the full diff, scan tracked documents for machine/account identifiers, and leave changes uncommitted for user review.

## Review checkpoints

- After Task 2: review recovery ownership and every transferred field before proceeding.
- After Task 4: review fail-closed diagnostics and gameplay-equivalence coverage.
- After Task 7 controls: decide from evidence whether Kennel optimization is warranted.
- After Task 9: report every unrun gate and distinguish local evidence from production/CI acceptance.
