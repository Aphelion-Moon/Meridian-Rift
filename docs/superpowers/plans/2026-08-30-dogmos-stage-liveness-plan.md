# Dogmos Stage Liveness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Do not dispatch subagents without explicit user approval. Leave changes uncommitted unless the user explicitly authorizes commits.

**Goal:** Eliminate the idle-round `StageConflict` cascade and the redundant startup turf-registration cost while preserving atmosphere correctness.

**Architecture:** Publish Equalize and ExcitedGroups work atomically per disconnected component and reuse the indexed transaction arena between components. Abort every resumable Rust stage state after a rejected request, stop the current Dream Maker SSair path on an invalid response, and skip already-current turf registrations only during startup batching.

**Tech Stack:** Rust 1.98.0 from the repository toolchain, BYOND Dream Maker/DreamDaemon, Meridian-MCP, and PowerShell-maintained Dogmos gates.

**Spec:** `docs/superpowers/specs/2026-08-30-dogmos-stage-liveness-design.md`

## Global Constraints

- Use Meridian-MCP for Dream Maker discovery and diagnostics; use PowerShell for builds and test entry points.
- Use only Runtime Station or MetaStation for DreamDaemon tests. Runtime Station is the primary acceptance map.
- Preserve unrelated working-tree changes in both repositories.
- Do not edit the protocol, generated bindings, native artifacts, dependencies, workflows, build/bootstrap files, Docker, TGS, or deployment configuration.
- Do not commit, push, reset, checkout, merge, clean, or change branches.
- A disconnected component is the atomic publication unit. Earlier completed components remain committed if a later component is cancelled or rejected.
- The same ordered inputs must retain the existing gas and heat formulas and deterministic publication order.

---

### Task 1: Reusable Per-Component Rust Transactions

**Files:**

- Modify: `<aphelion-dogmos>/crates/dogmos-core/src/transaction.rs`
- Modify: `<aphelion-dogmos>/crates/dogmos-core/src/world.rs`
- Test: `<aphelion-dogmos>/crates/dogmos-core/src/transaction.rs`
- Test: `<aphelion-dogmos>/crates/dogmos-core/tests/frontier_processing.rs`

**Interfaces:**

- Produces: `IndexedTransaction::clear(&mut self)`, which removes entries and resets dense indexes without releasing allocation.
- Produces: `DogmosWorld::commit_ready_stage_component(&mut self) -> Result<(u32, bool), WorldError>`, which validates and publishes the current component and reports callback-event count plus whether a component was published.
- Preserves: `DogmosWorld::process_stage_chunk_cancellable(StageChunkRequest, should_cancel) -> Result<StageChunkResult, WorldError>`.

- [ ] **Step 1: Write the failing transaction-arena test**

Add a unit test that touches two handles, records `capacity_bytes_lower_bound()`, calls `clear()`, asserts both handles are absent and `len() == 0`, then touches a new generation in the same slots and asserts capacity is unchanged.

- [ ] **Step 2: Run the focused test and observe the missing method failure**

Run:

```powershell
cargo test -p dogmos-core transaction::tests::clear_reuses_allocated_indexes_and_entries
```

Expected: compilation fails because `IndexedTransaction::clear` does not exist.

- [ ] **Step 3: Implement allocation-preserving clear**

Implement `clear()` by draining all entries, resetting each corresponding `slot_to_index` element to `UNUSED_INDEX`, and clearing its bit in `touched_bits`. Do not replace any backing `Vec`.

- [ ] **Step 4: Add the failing cross-chunk component test**

Create two disconnected two-turf components in `frontier_processing.rs`. Run Equalize with a work limit small enough to finish the first component while the stage remains pending, mutate a mixture in the second component through the public mixture command API, then resume the same stage request. Assert the stage completes, the first component remains published, and the second component computes from the new revision rather than returning `WorldError::StageConflict`.

- [ ] **Step 5: Run the cross-chunk test and confirm the stale whole-stage transaction failure**

Run:

```powershell
cargo test -p dogmos-core --test frontier_processing component_stage_commits_disconnected_components_before_resume
```

Expected: failure with `WorldError::StageConflict` on the resumed/final chunk.

- [ ] **Step 6: Publish and clear after each ready component**

After `process_ready_stage_component()` computes a component, validate only that component's transaction and staged events, publish entries in deterministic handle order, append its events, accumulate produced-component and callback counts, then call `transaction.clear()` and `staged_events.clear()` before advancing discovery. Remove the final whole-stage transaction publication; final completion reports the accumulated counters.

- [ ] **Step 7: Run focused and core regression tests**

Run:

```powershell
cargo test -p dogmos-core transaction::tests::clear_reuses_allocated_indexes_and_entries
cargo test -p dogmos-core --test frontier_processing component_stage_commits_disconnected_components_before_resume
cargo test -p dogmos-core
```

Expected: all tests pass.

### Task 2: Abort Poisoned Rust Stage State

**Files:**

- Modify: `<aphelion-dogmos>/crates/dogmos-core/src/world.rs`
- Test: `<aphelion-dogmos>/crates/dogmos-core/src/world.rs`
- Test: `<aphelion-dogmos>/crates/dogmos-core/tests/frontier_processing.rs`
- Verify: `<aphelion-dogmos>/crates/dogmos-server/src/state.rs`

**Interfaces:**

- Produces: private `DogmosWorld::abort_stage(&mut self)`, clearing `stage_cursor`, `stage_diffusion`, `stage_heat`, `stage_reactions`, `stage_components`, `stage_component_turfs`, and `use_committed_frontier`.
- Preserves: server error mapping to `ServiceErrorCode::StageConflict` and `ServiceErrorCode::Cancelled`.

- [ ] **Step 1: Replace the stale-state assertion with a failing recovery assertion**

Update `component_commit_revalidates_the_initial_mixture_revision` so a revision conflict is still returned but `pending_stage_epoch()` is `None`, all stage scratch options are `None`, and `use_committed_frontier` is false. Add an integration test that retries with a new stage epoch and completes.

- [ ] **Step 2: Add a failing cancellation cleanup test**

Start a component stage, cancel during component computation, and assert the same complete scratch-state reset. Retry using a new stage epoch and assert completion.

- [ ] **Step 3: Run both tests and observe retained scratch state**

Run:

```powershell
cargo test -p dogmos-core component_commit_revalidates_the_initial_mixture_revision
cargo test -p dogmos-core --test frontier_processing rejected_component_stage_aborts_and_retries_cleanly
```

Expected: the cleanup assertions fail because the current implementation restores `stage_components` and retains the cursor.

- [ ] **Step 4: Add a single error cleanup boundary**

Move the existing stage implementation behind a private inner method. The public `process_stage_chunk_cancellable()` calls it, invokes `abort_stage()` on every `Err`, and returns the original error unchanged. Keep successful pending results resumable.

- [ ] **Step 5: Run core and server regression tests**

Run:

```powershell
cargo test -p dogmos-core
cargo test -p dogmos-server
cargo clippy -p dogmos-core -p dogmos-server --all-targets -- -D warnings
```

Expected: all commands pass and server error codes remain unchanged.

### Task 3: Stop Dream Maker After an Invalid Stage Response

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

**Interfaces:**

- Produces: `/datum/controller/subsystem/air/proc/dogmos_stage_response_is_valid(stage, response)` returning a boolean without mutating stage state.
- Changes: `dogmos_run_stage()` returns `TRUE` immediately after logging an invalid response, leaving the DM stage pending for a later clean retry.

- [ ] **Step 1: Add the failing response-validation unit test**

Add `/datum/unit_test/dogmos_service_stage_response_failure`. Assert the validator rejects `null`, a scalar, and lists with the wrong field count, while accepting a fixed-width numeric response. Preserve and restore `SSair` pending-stage fields around the test.

- [ ] **Step 2: Run the focused Runtime Station test and observe the missing helper failure**

Run:

```powershell
.\tools\dogmos\run_tests.ps1 -Map RuntimeStation -Focus /datum/unit_test/dogmos_service_stage_response_failure
```

Expected: Dream Maker compilation fails because `dogmos_stage_response_is_valid` does not exist.

- [ ] **Step 3: Implement fail-stop control flow**

Add the documented validator next to `dogmos_run_stage()`. On validation failure, emit the existing `CRASH()` diagnostic and immediately `return TRUE`; do not read response fields, clear the pending stage, call the next stage, or flush lifecycle/topology work in that fire.

- [ ] **Step 4: Run focused scheduling tests**

Run:

```powershell
.\tools\dogmos\run_tests.ps1 -Map RuntimeStation -Focus /datum/unit_test/dogmos_service_stage_response_failure,/datum/unit_test/dogmos_service_stage_budget_progress,/datum/unit_test/dogmos_service_stage_cycle_health_preflight
```

Expected: all focused tests pass with zero runtime signatures.

### Task 4: Deduplicate Startup Turf Registration

**Files:**

- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `code/modules/atmospherics/environmental/LINDA_system.dm`
- Modify: `modular_aphelion/master_files/code/game/turfs/open/space/space.dm`
- Modify: `modular_aphelion/master_files/code/game/turfs/turf.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

**Interfaces:**

- Consumes: `/datum/controller/subsystem/dogmos/var/turf_registration_batching`, `/turf/var/dogmos_registration_generation`, and the last queued mixture identity.
- Preserves: unconditional runtime refresh behavior when `turf_registration_batching` is false.

- [ ] **Step 1: Add a failing startup-registration test**

During a controlled startup batch, register a target and neighbor once, record their registration generations and the pending lifecycle/cache counters, then invoke `sync_dogmos_adjacency()` and `__update_auxtools_turf_adjacency_info()` repeatedly. Assert generations and lifecycle/cache counters do not change. End the batch in teardown and restore both turfs.

- [ ] **Step 2: Run the focused Runtime Station test and confirm repeat registration**

Run:

```powershell
.\tools\dogmos\run_tests.ps1 -Map RuntimeStation -Focus /datum/unit_test/dogmos_service_startup_registration_deduplication
```

Expected: the counter or generation assertion fails because both paths call `register_dogmos_air()` again.

- [ ] **Step 3: Guard only startup registration paths**

In `sync_dogmos_adjacency()`, call `register_dogmos_air()` when startup batching is inactive or the queued turf generation and linked-mixture identity are not current. In `__update_auxtools_turf_adjacency_info()`, apply the same condition to initialized neighbors. Keep adjacency updates themselves unconditional, including the heat-only-to-gas transition when a mixture appears after the turf's first registration.

- [ ] **Step 4: Reparse and run focused DM gates**

Reparse `tgstation.dme`, inspect diagnostics for both changed production files and the test file, then run:

```powershell
.\tools\dogmos\run_tests.ps1 -Map RuntimeStation -Focus /datum/unit_test/dogmos_service_startup_registration_deduplication,/datum/unit_test/dogmos_service_turf_batching,/datum/unit_test/dogmos_service_topology_pressure
.\tools\dogmos\test_compile_check.ps1
```

Expected: zero changed-file errors, all focused tests pass with zero runtime signatures, and compilation reports 0 errors.

### Task 5: Integrated Qualification

**Files:**

- Verify all changed files in both repositories.
- Do not modify release artifacts or contract identity files.

**Interfaces:**

- Consumes: the current locally built i686 shim and x86_64 service only when their exact source identity can be established.
- Produces: numerical, runtime, scheduling, and initialization evidence without claiming protocol/release convergence.

- [ ] **Step 1: Run formatting and static gates**

Run the repository-pinned Rust formatter, full affected-package tests, Clippy with warnings denied, Meridian-MCP reparse/changed-file diagnostics, `git diff --check`, and the maintained Dream Maker compile gate.

- [ ] **Step 2: Run the wider Runtime Station Dogmos suite**

Run `tools/dogmos/run_tests.ps1 -Map RuntimeStation` and require the configured minimum test count, no failed tests, and zero runtime signatures.

- [ ] **Step 3: Run a no-player Runtime Station soak**

Use the maintained two-process launcher with Runtime Station. Allow initialization to complete and collect a bounded idle window long enough for repeated SSair cycles. Record initialization duration, SSair fire/cycle counts, `StageConflict` and malformed-response counts, active-turf samples, TIDI/overtime, DreamDaemon private bytes, and `dogmosd` private bytes separately.

- [ ] **Step 4: Apply acceptance criteria**

Require zero new runtime signatures and zero StageConflict cascades; repeated SSair cycle completion; no monotonic active-turf growth attributable to failed stages; and materially lower Atmospherics initialization time than the recorded 85.58-second control. If any condition fails, return to the first failing layer rather than extending an unstable playtest.

- [ ] **Step 5: Review and hand off**

Inspect the complete diffs in both repositories, confirm no machine/account identifiers entered tracked files, list every command and result, distinguish automated gates from live-soak evidence, and leave all changes uncommitted.
