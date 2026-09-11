# Dogmos Pipeline Temporary Registration Batching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Do not dispatch subagents without explicit user approval.

**Goal:** Replace per-mixture registration, initial-volume, and retirement IPC during pipeline rebuild storage with bounded calls to the existing lifecycle and mixture-state batch endpoints.

**Architecture:** Add one SSdogmos-owned factory that constructs deferred gas-mixture datums, reserves generation-qualified identities, publishes registrations in bounded batches, and initializes each empty mixture atomically through the existing state-batch binding. `temporarily_store_air()` requests all member mixtures from that factory, then retains its existing per-member copy/ratio behavior. As expansion consumes those temporaries, an invocation-local list publishes bounded unregistrations before each yield or completion and deletes only datums whose local identities were safely cleared. Rollback unregisters every published identity and clears every local handle before a failed factory call returns.

**Tech Stack:** BYOND 516.1687 Dream Maker, DM unit tests, existing Dogmos ABI 2/protocol 12 bindings, RIFT controller, Rust 1.98.0 contract verification.

**Spec:** `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

## Global Constraints

- Work directly in the existing Meridian-Rift checkout on branch `dogmos`; do not create a worktree.
- Preserve the user-owned `code/controllers/subsystem/air.dm` change setting `share_max_steps = 4`.
- Leave every change uncommitted and unpushed unless the user explicitly authorizes a commit.
- Do not edit `aphelion-dogmos`, protocol types, generated bindings, manifests, native artifacts, Cargo files, toolchains, workflows, or release tooling.
- Keep public gas-mixture proc paths compatible. The new constructor argument is optional and defaults to current registration behavior.
- Every accepted mixture identity remains slot-and-generation qualified. A failed batch must not leave a DM datum pointing at a service slot or make a published slot reusable before service unregistration succeeds.
- Initial state must match the current constructor path: revision 1 after volume initialization, `TCMB` temperature, requested non-negative volume, zero moles in all 32 protocol gas slots, and mutable state.
- Batch records are bounded to `DOGMOS_TURF_BATCH_OPERATIONS` (512) per DM chunk. The existing shim may use its atomic upload path for an oversized mixture-state payload.
- Preserve lifecycle-before-state and state-before-copy ordering. Reads, copies, and mutations remain ordering barriers.
- Use tabs in DM. Add AUTODOC to every new class-level variable and public proc.
- Performance acceptance still requires at least three identical controls and three identical candidates with numerical/event equivalence and separate DreamDaemon/`dogmosd` measurements.

---

## File map

- `code/modules/atmospherics/gasmixtures/gas_mixture.dm`: optional deferred-registration constructor argument; no batching policy.
- `modular_aphelion/modules/dogmos/code/service_backend.dm`: identity reservation, bounded registration/state publishing, rollback, and batch telemetry.
- `code/modules/atmospherics/machinery/datum_pipeline.dm`: pipeline-member volume collection and assignment of the returned registered mixtures.
- `modular_aphelion/modules/dogmos/code/service_backend_test.dm`: focused functional, batching, chunk-boundary, identity, and teardown regressions.
- `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`: verification results and matched-playtest boundary.

### Task 1: Lock the factory contract with a failing focused test

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm` after `/datum/unit_test/dogmos_service_pipeline_temporary_air`

**Interfaces:**
- Consumes: existing `SSdogmos.service_ready`, `SSdogmos.resolve_mixture()`, gas-mixture getters, and unit-test cleanup macros.
- Produces: the required interface `/datum/controller/subsystem/dogmos/proc/create_registered_mixture_batch(list/volumes)` and four shared batch telemetry variables named in the test.

- [ ] **Step 1: Add the failing factory test**

Add this datum after the existing pipeline-temporary test:

```dm
/** Verifies empty service mixtures are registered and initialized through bounded batches. */
/datum/unit_test/dogmos_service_mixture_batch_registration
	/// Mixtures released during teardown.
	var/list/datum/gas_mixture/test_mixtures

/datum/unit_test/dogmos_service_mixture_batch_registration/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	var/lifecycle_calls_before = SSdogmos.dogmos_mixture_batch_lifecycle_calls
	var/lifecycle_records_before = SSdogmos.dogmos_mixture_batch_lifecycle_records
	var/state_calls_before = SSdogmos.dogmos_mixture_batch_state_calls
	var/state_records_before = SSdogmos.dogmos_mixture_batch_state_records
	test_mixtures = SSdogmos.create_registered_mixture_batch(list(100, 200))
	if(length(test_mixtures) != 2)
		return Fail("Dogmos mixture batch factory did not return two mixtures.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_batch_lifecycle_calls != lifecycle_calls_before + 1 || SSdogmos.dogmos_mixture_batch_lifecycle_records != lifecycle_records_before + 2)
		return Fail("Dogmos mixture batch factory did not publish two identities in one lifecycle call.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_batch_state_calls != state_calls_before + 1 || SSdogmos.dogmos_mixture_batch_state_records != state_records_before + 2)
		return Fail("Dogmos mixture batch factory did not initialize two mixtures in one state call.", __FILE__, __LINE__)

	for(var/mixture_index in 1 to length(test_mixtures))
		var/datum/gas_mixture/mixture = test_mixtures[mixture_index]
		if(SSdogmos.resolve_mixture(mixture.dogmos_slot, mixture.dogmos_generation) != mixture)
			return Fail("Dogmos mixture batch factory did not publish a resolvable identity at index [mixture_index].", __FILE__, __LINE__)
		if(abs(mixture.return_volume() - mixture_index * 100) > DOGMOS_PIPELINE_TEST_EPSILON)
			return Fail("Dogmos mixture batch factory initialized the wrong volume at index [mixture_index].", __FILE__, __LINE__)
		if(abs(mixture.return_temperature() - TCMB) > DOGMOS_PIPELINE_TEST_EPSILON || mixture.total_moles() != 0)
			return Fail("Dogmos mixture batch factory did not preserve empty-mixture state at index [mixture_index].", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_mixture_batch_registration/Destroy()
	QDEL_LIST(test_mixtures)
	return ..()
```

- [ ] **Step 2: Run the focused test and retain the red evidence**

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_mixture_batch_registration --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected: DreamMaker fails because the four telemetry variables and `create_registered_mixture_batch()` do not exist. Save the RIFT run ID and exact compiler diagnostics in the audit.

- [ ] **Step 3: Review checkpoint**

Confirm the only source change is the failing test. Do not commit.

### Task 2: Add deferred construction and shared identity reservation

**Files:**
- Modify: `code/modules/atmospherics/gasmixtures/gas_mixture.dm:19-25`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm:150-230,414-459`

**Interfaces:**
- Consumes: existing slot/generation/free-slot lists and `finalize_mixture_registration()`.
- Produces: optional `defer_registration` constructor argument and `/datum/controller/subsystem/dogmos/proc/reserve_mixture_identity()` returning `list(slot, generation)`.

- [ ] **Step 1: Make deferred construction explicit and compatible**

Replace the constructor with:

```dm
/** Creates a gas mixture and optionally defers Dogmos identity publication to a batch factory.
 *
 * Arguments:
 * * volume - Initial service volume, or the type default when null.
 * * defer_registration - Whether the caller will publish and initialize this mixture in a bounded batch before use.
 */
/datum/gas_mixture/New(volume, defer_registration = FALSE)
	if(!isnull(volume))
		initial_volume = volume
	if(initial_volume <= 0)
		stack_trace("Created a gas mixture with zero volume!")
	if(!defer_registration)
		__gasmixture_register()
	reaction_results = new
```

- [ ] **Step 2: Extract identity reservation without changing single-registration behavior**

Add before `register_mixture()`:

```dm
/** Reserves one generation-qualified mixture identity without publishing it to dogmosd. */
/datum/controller/subsystem/dogmos/proc/reserve_mixture_identity()
	var/slot
	if(length(dogmos_free_mixture_slots))
		slot = pop(dogmos_free_mixture_slots)
		dogmos_mixture_generations[slot]++
	else
		slot = length(dogmos_mixture_slots) + 1
		if(slot > DOGMOS_MAX_EXACT_INTEGER)
			CRASH("Dogmos mixture identity capacity exhausted.")
		dogmos_mixture_generations += 1
		dogmos_mixture_slots.len = slot

	var/generation = dogmos_mixture_generations[slot]
	if(generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Dogmos mixture generation exhausted for slot [slot].")
	return list(slot, generation)
```

Replace lines 440-453 of `register_mixture()` with:

```dm
	var/list/identity = reserve_mixture_identity()
	var/slot = identity[1]
	var/generation = identity[2]
```

Keep its one-record lifecycle call, `finalize_mixture_registration()`, and `set_volume()` unchanged.

- [ ] **Step 3: Compile the existing focused pipeline test**

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_pipeline_temporary_air --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected: PASS, one test recorded, zero runtimes. This proves the refactor preserves the current single-registration path; Task 1's new test remains red until the factory exists.

- [ ] **Step 4: Review checkpoint**

Inspect `git diff -- code/modules/atmospherics/gasmixtures/gas_mixture.dm modular_aphelion/modules/dogmos/code/service_backend.dm`. Confirm no caller passes `defer_registration = TRUE` yet. Do not commit.

### Task 3: Implement bounded batch publication and rollback

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`

**Interfaces:**
- Consumes: `reserve_mixture_identity()`, `finalize_mixture_registration()`, `dogmos_mixture_lifecycle_batch()`, and `dogmos_mixture_state_batch()`.
- Produces: `create_registered_mixture_batch(list/volumes)`, batch counters, and private cleanup helpers.

- [ ] **Step 1: Add fixed-record constants and telemetry**

Add near the existing mixture constants:

```dm
#define DOGMOS_MIXTURE_STATE_GAS_FIELDS (DOGMOS_MIXTURE_SNAPSHOT_FIELDS - DOGMOS_MIXTURE_SNAPSHOT_GASES_START + 1)
#define DOGMOS_MIXTURE_STATE_FIELDS (6 + DOGMOS_MIXTURE_STATE_GAS_FIELDS)
```

Add to `/datum/controller/subsystem/dogmos`:

```dm
	/// Successful bounded mixture lifecycle IPC calls made by batch registration or retirement.
	var/dogmos_mixture_batch_lifecycle_calls = 0
	/// Mixture identities published or retired by successful bounded lifecycle calls.
	var/dogmos_mixture_batch_lifecycle_records = 0
	/// Successful state IPC calls made by create_registered_mixture_batch().
	var/dogmos_mixture_batch_state_calls = 0
	/// Empty mixture states initialized by successful factory state calls.
	var/dogmos_mixture_batch_state_records = 0
```

Add matching `#undef` directives at the bottom of the file.

- [ ] **Step 2: Add local identity cleanup**

Add before the batch factory:

```dm
/** Clears one locally published mixture identity after service retirement or rejected publication. */
/datum/controller/subsystem/dogmos/proc/clear_mixture_identity(datum/gas_mixture/mixture, slot, generation, make_reusable)
	evict_mixture_snapshot_cache(slot, generation)
	dogmos_mixture_slots[slot] = null
	mixture.dogmos_slot = null
	mixture.dogmos_generation = null
	mixture._extools_pointer_gasmixture = null
	if(make_reusable)
		dogmos_free_mixture_slots += slot
```

Refactor `unregister_mixture()` to use an explicit reuse decision after its service/deferred-unregistration branch. Preserve the existing rule that a slot deferred behind a frontier barrier becomes reusable only in `flush_pending_mixture_unregistrations()`:

```dm
	var/make_reusable = FALSE
	if(service_ready)
		if(SSair?.dogmos_pending_frontier_epoch)
			dogmos_pending_mixture_unregistrations["[slot]"] = list(DOGMOS_LIFECYCLE_UNREGISTER, slot, generation)
		else
			if(dogmos_mixture_lifecycle_batch(list(DOGMOS_LIFECYCLE_UNREGISTER, slot, generation)) != 1)
				CRASH("dogmosd rejected mixture unregistration for [slot]:[generation].")
			make_reusable = TRUE
	clear_mixture_identity(mixture, slot, generation, make_reusable)
```

- [ ] **Step 3: Add batch rollback**

Each entry in `identities` is `list(slot, generation, publication_possible)`. The flag becomes true before sending a lifecycle chunk because a missing or mismatched response cannot prove that the service rejected the request. Add:

```dm
/** Retires every service-published identity and releases unpublished reservations after factory failure. */
/datum/controller/subsystem/dogmos/proc/rollback_mixture_registration_batch(list/datum/gas_mixture/mixtures, list/identities)
	var/list/retired_slots = list()
	var/list/possibly_published_indices = list()
	for(var/mixture_index in 1 to length(identities))
		var/list/identity = identities[mixture_index]
		if(identity[3])
			possibly_published_indices += mixture_index
	if(service_ready)
		for(var/chunk_start in 1 to length(possibly_published_indices) step DOGMOS_TURF_BATCH_OPERATIONS)
			var/chunk_end = min(chunk_start + DOGMOS_TURF_BATCH_OPERATIONS - 1, length(possibly_published_indices))
			var/list/unregister_records = list()
			for(var/index_offset in chunk_start to chunk_end)
				var/list/identity = identities[possibly_published_indices[index_offset]]
				unregister_records += list(DOGMOS_LIFECYCLE_UNREGISTER, identity[1], identity[2])
			var/record_count = chunk_end - chunk_start + 1
			if(dogmos_mixture_lifecycle_batch(unregister_records) != record_count)
				SSair.dogmos_fail_closed_stage("mixture batch rollback")
				break
			for(var/index_offset in chunk_start to chunk_end)
				var/list/identity = identities[possibly_published_indices[index_offset]]
				retired_slots["[identity[1]]"] = TRUE

	for(var/mixture_index in 1 to length(identities))
		var/datum/gas_mixture/mixture = mixtures[mixture_index]
		var/list/identity = identities[mixture_index]
		var/slot = identity[1]
		var/generation = identity[2]
		var/make_reusable = !identity[3] || retired_slots["[slot]"]
		if(mixture.dogmos_slot)
			clear_mixture_identity(mixture, slot, generation, make_reusable)
		else if(make_reusable)
			dogmos_free_mixture_slots += slot
	return length(retired_slots) == length(possibly_published_indices)
```

- [ ] **Step 4: Add the bounded factory**

Implement:

```dm
/** Creates empty service mixtures through bounded lifecycle and state batches.
 *
 * Arguments:
 * * volumes - Initial volumes, one per returned mixture.
 */
/datum/controller/subsystem/dogmos/proc/create_registered_mixture_batch(list/volumes)
	if(!service_ready)
		if(!service_failure_latched)
			CRASH("Attempted to batch-register gas mixtures while dogmosd is unavailable.")
		return
	if(!length(volumes))
		return list()

	var/list/datum/gas_mixture/mixtures = list()
	var/list/identities = list()
	for(var/volume in volumes)
		var/datum/gas_mixture/mixture = new(volume, TRUE)
		var/list/identity = reserve_mixture_identity()
		mixtures += mixture
		identities += list(list(identity[1], identity[2], FALSE))

	for(var/chunk_start in 1 to length(mixtures) step DOGMOS_TURF_BATCH_OPERATIONS)
		var/chunk_end = min(chunk_start + DOGMOS_TURF_BATCH_OPERATIONS - 1, length(mixtures))
		var/list/lifecycle_records = list()
		for(var/mixture_index in chunk_start to chunk_end)
			var/list/identity = identities[mixture_index]
			identity[3] = TRUE
			lifecycle_records += list(DOGMOS_LIFECYCLE_REGISTER, identity[1], identity[2])
		var/record_count = chunk_end - chunk_start + 1
		if(dogmos_mixture_lifecycle_batch(lifecycle_records) != record_count)
			rollback_mixture_registration_batch(mixtures, identities)
			QDEL_LIST(mixtures)
			SSair.dogmos_fail_closed_stage("mixture batch registration")
			return
		dogmos_mixture_batch_lifecycle_calls++
		dogmos_mixture_batch_lifecycle_records += record_count

		var/list/state_records = list()
		for(var/mixture_index in chunk_start to chunk_end)
			var/datum/gas_mixture/mixture = mixtures[mixture_index]
			var/list/identity = identities[mixture_index]
			if(!finalize_mixture_registration(mixture, identity[1], identity[2], 1))
				rollback_mixture_registration_batch(mixtures, identities)
				QDEL_LIST(mixtures)
				return
			state_records += list(identity[1], identity[2], 0, 0, TCMB, mixture.initial_volume)
			for(var/gas_index in 1 to DOGMOS_MIXTURE_STATE_GAS_FIELDS)
				state_records += 0
		if(length(state_records) != record_count * DOGMOS_MIXTURE_STATE_FIELDS || dogmos_mixture_state_batch(state_records) != record_count)
			rollback_mixture_registration_batch(mixtures, identities)
			QDEL_LIST(mixtures)
			SSair.dogmos_fail_closed_stage("mixture batch initialization")
			return
		dogmos_mixture_batch_state_calls++
		dogmos_mixture_batch_state_records += record_count
	return mixtures
```
- [ ] **Step 5: Run the factory test green**

Run the Task 1 RIFT command.

Expected: compile succeeds; one test passes; counters report one lifecycle call/two records and one state call/two records; volumes are 100 and 200; both mixtures are `TCMB`, empty, and resolvable; zero runtimes.

- [ ] **Step 6: Review checkpoint**

Inspect every failure branch. Confirm no branch both queues deferred retirement and immediately reuses the same slot. Confirm `QDEL_LIST()` sees cleared pointers after rollback and therefore does not unregister twice. Do not commit.

### Task 4: Prove bounded chunking and generation-safe reuse

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`

**Interfaces:**
- Consumes: batch factory and telemetry from Task 3.
- Produces: an executable boundary regression covering 513 records and post-delete slot reuse.

- [ ] **Step 1: Add the chunk-boundary test**

Add `#define DOGMOS_TEST_MIXTURE_BATCH_BOUNDARY 513` with the other test constants at the top of the file and add its matching `#undef` before `#endif`.

```dm
/** Verifies mixture factory batches remain bounded and slot reuse advances generations. */
/datum/unit_test/dogmos_service_mixture_batch_boundary
	/// Mixtures released during teardown.
	var/list/datum/gas_mixture/test_mixtures

/datum/unit_test/dogmos_service_mixture_batch_boundary/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	var/list/volumes = new/list(DOGMOS_TEST_MIXTURE_BATCH_BOUNDARY)
	for(var/volume_index in 1 to length(volumes))
		volumes[volume_index] = volume_index
	var/lifecycle_calls_before = SSdogmos.dogmos_mixture_batch_lifecycle_calls
	var/state_calls_before = SSdogmos.dogmos_mixture_batch_state_calls
	test_mixtures = SSdogmos.create_registered_mixture_batch(volumes)
	if(length(test_mixtures) != DOGMOS_TEST_MIXTURE_BATCH_BOUNDARY)
		return Fail("Dogmos mixture factory truncated its chunk-boundary result.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_batch_lifecycle_calls != lifecycle_calls_before + 2 || SSdogmos.dogmos_mixture_batch_state_calls != state_calls_before + 2)
		return Fail("Dogmos mixture factory did not split 513 records into two bounded calls.", __FILE__, __LINE__)
	var/datum/gas_mixture/last_mixture = test_mixtures[length(test_mixtures)]
	if(abs(last_mixture.return_volume() - length(test_mixtures)) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Dogmos mixture factory corrupted the final chunk's state.", __FILE__, __LINE__)
```

Extend teardown with `QDEL_LIST(test_mixtures)`. Generation reuse is already covered by `/datum/unit_test/dogmos_service_mixture_identity`; run it alongside this boundary test instead of duplicating its stale-handle assertions.

- [ ] **Step 2: Run boundary and identity tests together**

Add a real-service rollback regression before running the group:

```dm
/** Verifies batch rollback retires published identities before their slots are reused. */
/datum/unit_test/dogmos_service_mixture_batch_rollback
	/// Mixtures whose cleared pointers make repeated teardown harmless.
	var/list/datum/gas_mixture/test_mixtures

/datum/unit_test/dogmos_service_mixture_batch_rollback/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	test_mixtures = list(new /datum/gas_mixture(100), new /datum/gas_mixture(200))
	var/list/original_generations = list()
	var/list/identities = list()
	for(var/datum/gas_mixture/mixture as anything in test_mixtures)
		original_generations["[mixture.dogmos_slot]"] = mixture.dogmos_generation
		identities += list(list(mixture.dogmos_slot, mixture.dogmos_generation, TRUE))
	if(!SSdogmos.rollback_mixture_registration_batch(test_mixtures, identities))
		return Fail("Dogmos mixture batch rollback did not retire every published identity.", __FILE__, __LINE__)
	for(var/datum/gas_mixture/mixture as anything in test_mixtures)
		if(mixture.dogmos_slot || mixture.dogmos_generation || mixture._extools_pointer_gasmixture)
			return Fail("Dogmos mixture batch rollback retained a local service identity.", __FILE__, __LINE__)

	var/list/datum/gas_mixture/replacements = list(new /datum/gas_mixture(100), new /datum/gas_mixture(200))
	for(var/datum/gas_mixture/replacement as anything in replacements)
		var/original_generation = original_generations["[replacement.dogmos_slot]"]
		if(isnull(original_generation) || replacement.dogmos_generation <= original_generation)
			return Fail("Dogmos mixture batch rollback reused slot [replacement.dogmos_slot] without advancing its generation.", __FILE__, __LINE__)
	test_mixtures += replacements

/datum/unit_test/dogmos_service_mixture_batch_rollback/Destroy()
	QDEL_LIST(test_mixtures)
	return ..()
```

Run:

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_mixture_batch_boundary --focus /datum/unit_test/dogmos_service_mixture_batch_rollback --focus /datum/unit_test/dogmos_service_mixture_identity --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected: three tests recorded, three passed, zero runtimes. Inspect RIFT's collected `unit_tests.json` rather than the live checkout's `data/unit_tests.json`.

- [ ] **Step 3: Review checkpoint**

Confirm the 513-mixture test does not leave owned processes or registered service slots after teardown. Do not commit.

### Task 5: Route pipeline temporary creation through the factory

**Files:**
- Modify: `code/modules/atmospherics/machinery/datum_pipeline.dm:213-219`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm` in `/datum/unit_test/dogmos_service_pipeline_temporary_air`

**Interfaces:**
- Consumes: `SSdogmos.create_registered_mixture_batch(volumes)`.
- Produces: one lifecycle and one state call per pipeline chunk while retaining existing `copy_from_ratio()` semantics.

- [ ] **Step 1: Strengthen the existing pipeline regression before changing production**

In the test, capture all four batch counters before `temporarily_store_air()` and assert after it:

```dm
	if(SSdogmos.dogmos_mixture_batch_lifecycle_calls != lifecycle_calls_before + 1 || SSdogmos.dogmos_mixture_batch_lifecycle_records != lifecycle_records_before + 2)
		return Fail("Pipeline temporary storage did not batch its mixture registrations.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_batch_state_calls != state_calls_before + 1 || SSdogmos.dogmos_mixture_batch_state_records != state_records_before + 2)
		return Fail("Pipeline temporary storage did not batch its initial mixture states.", __FILE__, __LINE__)
```

Run the focused pipeline test and retain the expected failure: the current code still calls `new(member.volume)` twice and never increments the batch counters.

- [ ] **Step 2: Replace only mixture creation/assignment**

Use:

```dm
/datum/pipeline/proc/temporarily_store_air()
	//Update individual gas_mixtures by volume ratio
	var/pipeline_volume = air.return_volume()
	var/list/member_volumes = list()
	for(var/obj/machinery/atmospherics/pipe/member as anything in members)
		member_volumes += member.volume
	var/list/datum/gas_mixture/temporary_mixtures = SSdogmos.create_registered_mixture_batch(member_volumes)
	if(length(temporary_mixtures) != length(members))
		SSair.dogmos_fail_closed_stage("pipeline temporary mixture registration")
		return

	var/mixture_index = 1
	for(var/obj/machinery/atmospherics/pipe/member as anything in members)
		member.air_temporary = temporary_mixtures[mixture_index++]
		member.air_temporary.copy_from_ratio(air, member.volume / pipeline_volume)
```

Do not include the separate `copy_from()` plus `multiply()` snapshot optimization in this task. Keeping `copy_from_ratio()` makes registration batching independently reviewable and independently revertible.

- [ ] **Step 3: Run the pipeline regression green**

Run the focused pipeline test command.

Expected: one test passes; one lifecycle batch/two records and one state batch/two records; the existing snapshot count, volume, temperature, oxygen, and nitrogen assertions all pass.

- [ ] **Step 4: Run adjacent Dogmos tests**

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --focus /datum/unit_test/dogmos_service_mixture_batch_registration --focus /datum/unit_test/dogmos_service_mixture_batch_boundary --focus /datum/unit_test/dogmos_service_mixture_batch_rollback --focus /datum/unit_test/dogmos_service_mixture_identity --focus /datum/unit_test/dogmos_service_mixture_snapshot_cache --focus /datum/unit_test/dogmos_service_pipeline_temporary_air --focus /datum/unit_test/dogmos_service_pipeline_batch_reconcile --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected: seven tests recorded, seven passed, zero runtimes.

- [ ] **Step 5: Review checkpoint**

Inspect `git diff --check` and every changed DM file. Confirm the factory result is assigned one-to-one in original member order and no temporary mixture remains held only by the local list after return. Do not commit.

### Task 6: Batch retirement at the explicit expansion ownership handoff

**Files:**
- Modify: `modular_aphelion/modules/dogmos/code/service_backend.dm`
- Modify: `modular_aphelion/modules/dogmos/code/service_backend_test.dm`
- Modify: `code/controllers/subsystem/air.dm` in `expand_pipeline()`

**Interfaces:**
- Consumes: `clear_mixture_identity()`, the existing bounded lifecycle endpoint, `dogmos_pending_mixture_unregistrations`, and the pipeline temporary ownership contract.
- Produces: `/datum/controller/subsystem/dogmos/proc/unregister_mixture_batch(list/datum/gas_mixture/mixtures)` and one bounded retirement call per non-empty expansion chunk when no frontier stage is pending.

- [ ] **Step 1: Add a failing bounded-retirement test**

Create three registered mixtures, retain their slot/generation pairs, record lifecycle counters, and call `unregister_mixture_batch()`. Assert:

- exactly one lifecycle call and three records were added;
- all three local service identities and weakref slots were cleared;
- deleting the cleared datums does not send another lifecycle record;
- three replacements may reuse the slots only with strictly greater generations.

Run the test and retain the expected compiler failure before adding the proc.

- [ ] **Step 2: Implement atomic validation and bounded retirement**

Validate every list entry and generation before mutating local state. If a frontier epoch is pending, add every record to `dogmos_pending_mixture_unregistrations`, clear each local identity without reuse, and let the existing post-stage flush retire and release the slots. Otherwise, send chunks of at most `DOGMOS_TURF_BATCH_OPERATIONS`; after each accepted chunk, clear those identities with reuse enabled.

Increment `dogmos_mixture_batch_lifecycle_calls` and `dogmos_mixture_batch_lifecycle_records` after every accepted explicit or deferred retirement chunk. Extend `flush_pending_mixture_unregistrations()` to update the same counters only after its native response is accepted. Registration tests continue to sample deltas before teardown, so later retirement accounting cannot change their assertions.

If a response is missing, malformed, or short, fail SSair closed. Clear successfully retired identities as reusable and every unresolved identity as non-reusable before returning failure so later `Del()` calls cannot double-unregister an uncertain handle. Do not make an uncertain slot reusable.

- [ ] **Step 3: Route only consumed pipeline temporaries through the batch**

In `expand_pipeline()`, retain each non-null `item.air_temporary` in an invocation-local typed list after `net.air.merge()` succeeds, then clear the pipe field. Before both the `MC_TICK_CHECK` return and normal completion:

1. call `unregister_mixture_batch()` for the retained list;
2. fail closed and return if retirement was not accepted or safely deferred;
3. delete the identity-cleared datums with `QDEL_LIST()`;
4. clear the local list.

Do not batch-retire the starting pipe's temporary mixture: `build_pipeline()` transfers ownership of that datum to `pipeline.air`. Do not globally defer unrelated gas-mixture destruction or introduce a timer.

- [ ] **Step 4: Integrate with invocation-local volume batching**

When the expansion-volume plan is also selected, use one local flush block before each yield/completion: publish accumulated volume first, then retire already-merged temporaries. This retains the original per-item order of volume growth before gas merge at every observable cooperative boundary.

- [ ] **Step 5: Run focused and boundary tests**

Run the retirement test, pipeline temporary test, pipeline expansion-volume test, mixture identity test, snapshot-cache test, and the 513-record lifecycle boundary test. Require exact lifecycle counter deltas, generation-safe reuse, zero runtimes, and no registered identities left after teardown.

- [ ] **Step 6: Review checkpoint**

Confirm every early return either retains valid ownership or clears identity before deletion. Confirm the existing pending-frontier path remains lifecycle-before-topology ordered and that no queued slot enters `dogmos_free_mixture_slots` before an accepted unregister response. Do not commit.

### Task 7: Run integration and soak gates

**Files:**
- Modify: `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

**Interfaces:**
- Consumes: the complete Task 1-6 implementation.
- Produces: compiler, focused-test, full-suite/blocker, RuntimeStation, cleanup, and process-memory evidence.

- [ ] **Step 1: Verify the installed native contract**

```powershell
python tools/dogmos/verify_contract.py verify-installed --root .
```

Expected: exit 0; ABI 2, protocol 12, Rust 1.98.0, source revision `7f5177fc3726a5c445491259d04a75a94a872006`, and installed hashes matching `dogmos.lock.json`.

- [ ] **Step 2: Run the full MetaStation suite**

```powershell
.\RIFT.cmd test --profile dogmos-ci --map _maps/metastation.json --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected current boundary: it may stop before unit tests on the separately documented `code/datums/components/atom_mounted.dm:201` map-border runtime. If so, record that blocker without attributing it to Dogmos. If it reaches tests, separately record the user-owned `share_max_steps = 4` cadence failure.

- [ ] **Step 3: Run a full RuntimeStation soak**

```powershell
.\RIFT.cmd soak --profile dogmos --map _maps/runtimestation.json --run-seconds 300 --shim dogmos.dll --service dogmosd.exe --network offline --format result
```

Expected: contract/full-build/soak pass, exactly one owned `dogmosd`, zero runtime signatures, separate DreamDaemon and service resource maxima, and cleanup with no leftovers.

- [ ] **Step 4: Record exact evidence**

Update the audit with every RIFT run ID, test count, runtime signature, cleanup result, and separate process maxima. State explicitly that these gates prove correctness/qualification, not a performance improvement.

- [ ] **Step 5: Review checkpoint**

Run `git diff --check`, inspect `git status --short` in both repositories, and confirm `aphelion-dogmos` remains clean. Do not commit.

### Task 8: Measure performance acceptance

**Files:**
- Modify: `docs/audits/2026-09-02-dogmos-post-fix-playtest-audit.md`

**Interfaces:**
- Consumes: the fixed workload, RIFT-qualified candidate, and the repository's process/performance tools.
- Produces: accepted or rejected matched-control evidence; no source change.

- [ ] **Step 1: Freeze comparable identities**

Record map, seed, BYOND 516.1687, Meridian-Rift revision plus dirty diff hash, Dogmos source revision, feature fingerprint, installed artifact hashes, `share_max_steps`, scenario, duration, and workload-file hash. Do not compare any run with a different identity.

- [ ] **Step 2: Run three clean controls and three clean candidates**

Use identical fusion/decompression actions and fixed `share_max_steps`. Capture built-in profiler intervals around the same stress window and use `tools/perf/Measure-DogmosProcesses.ps1` for exact DreamDaemon and service PIDs.

- [ ] **Step 3: Compare the targeted counters**

Report p50/p95/p99/max latency and deltas for:

- `/proc/dogmos_mixture_lifecycle_batch` calls and inclusive time;
- `/proc/dogmos_mixture_state_batch` calls and inclusive time;
- `/datum/pipeline/proc/temporarily_store_air` calls and inclusive time;
- `/datum/gas_mixture/New` and `Del` counts;
- lifecycle register/unregister records per bounded call;
- DreamDaemon private/working-set maxima;
- `dogmosd` private/RSS maxima separately;
- SSair budget overruns, active turfs, hotspots, explosions, decompressions, and numerical/event equivalence.

- [ ] **Step 4: Accept or reject without overclaiming**

Accept only if the candidate reduces lifecycle crossings outside measured noise, preserves all numerical/event outcomes, introduces no sustained tick-budget regression, and passes the existing process/runtime gates. Otherwise retain the correctness repair and mark batching as not performance-qualified.

- [ ] **Step 5: Final review checkpoint**

Ensure the audit distinguishes observed timings, mechanism counts, qualification gates, and matched acceptance. Leave all repository changes uncommitted.
