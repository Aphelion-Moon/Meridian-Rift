#define DOGMOS_REQUIRED_PROTOCOL_VERSION 13
#define DOGMOS_MAX_EXACT_INTEGER 16777216
#define DOGMOS_PROCESS_METRICS_WORDS 28
#define DOGMOS_PROCESS_METRICS_LAYOUT_VERSION 1
#define DOGMOS_PROCESS_WORD_BASE 65536
#define DOGMOS_PROCESS_WORD_MAX 65535
#define DOGMOS_PROCESS_LAYOUT_WORD 1
#define DOGMOS_PROCESS_HOST_FLAGS_WORD 3
#define DOGMOS_PROCESS_SERVICE_FLAGS_WORD 5
#define DOGMOS_PROCESS_RESERVED_WORD 7
#define DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD 9
#define DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD 13
#define DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD 17
#define DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD 21
#define DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD 25
#define DOGMOS_DREAMDAEMON_PRIVATE_BYTES_AVAILABLE 1
#define DOGMOS_DREAMDAEMON_VIRTUAL_BYTES_AVAILABLE 2
#define DOGMOS_DREAMDAEMON_WORKING_SET_BYTES_AVAILABLE 4
#define DOGMOS_DREAMDAEMON_ALL_AVAILABLE 7
#define DOGMOS_SERVICE_RSS_BYTES_AVAILABLE 1
#define DOGMOS_SERVICE_CPU_MILLISECONDS_AVAILABLE 2
#define DOGMOS_SERVICE_ALL_AVAILABLE 3
#define DOGMOS_CALLBACK_BATCH_SIZE 256
#define DOGMOS_CALLBACK_HEADER_FIELDS 12
#define DOGMOS_CALLBACK_EVENT_FIELDS 36
#define DOGMOS_CALLBACK_EVENT_START 13
#define DOGMOS_CALLBACK_SCOPE_GENERAL 1
#define DOGMOS_CALLBACK_SCOPE_REACTION 2
#define DOGMOS_CALLBACK_TRANSACTION_WORD 4
#define DOGMOS_CALLBACK_SCOPE_FIELD 8
#define DOGMOS_CALLBACK_KIND_FIELD 9
#define DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD 11
#define DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD 13
#define DOGMOS_CALLBACK_TARGET_SLOT_FIELD 15
#define DOGMOS_CALLBACK_TARGET_GENERATION_FIELD 17
#define DOGMOS_CALLBACK_VALUES_FIELD 19
#define DOGMOS_CALLBACK_AUX_FIELD 23
#define DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD 26
#define DOGMOS_TURF_BATCH_OPERATIONS 512
#define DOGMOS_TURF_LIFECYCLE_FIELDS 6
#define DOGMOS_TURF_ADJACENCY_FIELDS 6
#define DOGMOS_TURF_HEAT_FIELDS 7
#define DOGMOS_TURF_HEAT_ADJACENCY_FIELDS 5
#define DOGMOS_MIXTURE_CACHE_BUCKETS 2048
#define DOGMOS_MIXTURE_SNAPSHOT_FIELDS 42
#define DOGMOS_MIXTURE_SNAPSHOT_REVISION_LOW 1
#define DOGMOS_MIXTURE_SNAPSHOT_REVISION_HIGH 2
#define DOGMOS_MIXTURE_SNAPSHOT_GAS_COUNT 3
#define DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE 4
#define DOGMOS_MIXTURE_SNAPSHOT_VOLUME 5
#define DOGMOS_MIXTURE_SNAPSHOT_TOTAL_MOLES 7
#define DOGMOS_MIXTURE_SNAPSHOT_PRESSURE 8
#define DOGMOS_MIXTURE_SNAPSHOT_HEAT_CAPACITY 9
#define DOGMOS_MIXTURE_SNAPSHOT_IMMUTABLE 10
#define DOGMOS_MIXTURE_SNAPSHOT_GASES_START 11
#define DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS (2 + DOGMOS_MIXTURE_SNAPSHOT_FIELDS)
// A prefetch cannot usefully load more mixtures than the snapshot cache has buckets: the cache is
// direct-mapped, so anything past that is guaranteed to evict something the same prefetch just
// stored. Capped here rather than at the service, which will happily return far more.
#define DOGMOS_MIXTURE_PREFETCH_LIMIT DOGMOS_MIXTURE_CACHE_BUCKETS
// The production IPC reply window is 64 KiB: 4 count bytes plus 172 bytes
// per compact snapshot. floor((65536 - 4) / 172) = 381 records per call.
#define DOGMOS_MIXTURE_SNAPSHOT_BATCH_LIMIT 381
// Mirrors dogmos-core's DEFAULT_MIXTURE_VOLUME_LITERS. A freshly registered mixture already has
// this volume on the service side.
#define DOGMOS_DEFAULT_MIXTURE_VOLUME 2500
// Mirrors Rust's MINIMUM_MOLES_DELTA_TO_MOVE (world.rs) exactly, as its own constant rather than
// reusing DM's similarly-named MINIMUM_MOLES_DELTA_TO_MOVE (atmos_core.dm) - that one is a
// derived, independently-tunable formula (MOLES_CELLSTANDARD * MINIMUM_AIR_RATIO_TO_MOVE) that
// does not evaluate to the same value. compare() must match Rust's threshold exactly, not DM's.
#define DOGMOS_COMPARE_MINIMUM_MOLES_DELTA 0.01032637
#define DOGMOS_COMPARE_MINIMUM_TEMPERATURE_DELTA 4.0

#define DOGMOS_LIFECYCLE_REGISTER 1
#define DOGMOS_LIFECYCLE_UNREGISTER 2

#define DOGMOS_RESPONSE_APPLIED 1
#define DOGMOS_RESPONSE_SCALAR 2
#define DOGMOS_RESPONSE_SCALARS 3
#define DOGMOS_RESPONSE_BOOLEAN 4
#define DOGMOS_RESPONSE_REACTION_PROGRESS 5

#define DOGMOS_COMMAND_SET_MOLES 1
#define DOGMOS_COMMAND_ADJUST_MOLES 2
#define DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE 3
#define DOGMOS_COMMAND_GET_MOLES 4
#define DOGMOS_COMMAND_TEMPERATURE 5
#define DOGMOS_COMMAND_VOLUME 6
#define DOGMOS_COMMAND_HEAT_CAPACITY 7
#define DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY 8
#define DOGMOS_COMMAND_TOTAL_MOLES 9
#define DOGMOS_COMMAND_PRESSURE 10
#define DOGMOS_COMMAND_THERMAL_ENERGY 11
#define DOGMOS_COMMAND_GET_MOLES_BY_FLAGS 12
#define DOGMOS_COMMAND_BURNABILITY 13
#define DOGMOS_COMMAND_SET_TEMPERATURE 14
#define DOGMOS_COMMAND_SET_VOLUME 15
#define DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY 16
#define DOGMOS_COMMAND_CLEAR 17
#define DOGMOS_COMMAND_ADD 18
#define DOGMOS_COMMAND_MULTIPLY 19
#define DOGMOS_COMMAND_COPY_FROM 20
#define DOGMOS_COMMAND_ADJUST_HEAT 21
#define DOGMOS_COMMAND_COMPARE 22
#define DOGMOS_COMMAND_EQUALIZE_WITH 23
#define DOGMOS_COMMAND_TEMPERATURE_SHARE 24
#define DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS 25
#define DOGMOS_COMMAND_MARK_IMMUTABLE 26
#define DOGMOS_COMMAND_IS_IMMUTABLE 27
#define DOGMOS_COMMAND_MERGE 28
#define DOGMOS_COMMAND_REMOVE_RATIO_INTO 29
#define DOGMOS_COMMAND_REMOVE_AMOUNT_INTO 30
#define DOGMOS_COMMAND_TRANSFER_GASES 31
#define DOGMOS_COMMAND_TRANSFER_AMOUNT 32
#define DOGMOS_COMMAND_TRANSFER_RATIO 33
#define DOGMOS_COMMAND_TRANSFER_BY_FLAGS 34
#define DOGMOS_COMMAND_SHARE_RATIO 35
#define DOGMOS_COMMAND_REACT 36

#define DOGMOS_CALLBACK_REACTION_FINISHED 2
#define DOGMOS_CALLBACK_PRESSURE_DIFFERENCE 3
#define DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP 4
#define DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION 5
#define DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST 6
#define DOGMOS_CALLBACK_RUN_DM_REACTION 7
#define DOGMOS_CALLBACK_REACTION_PROFILED 8

#define DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT 1

#define DOGMOS_REACTION_PLASMA 1
#define DOGMOS_REACTION_HYDROGEN 2
#define DOGMOS_REACTION_TRITIUM 3
#define DOGMOS_REACTION_FREON 4

#define DOGMOS_SIMULATION_EXCITED_GROUPS 1
#define DOGMOS_SIMULATION_TURF_EQUALIZE 2
#define DOGMOS_SIMULATION_TURF_HEAT 3
#define DOGMOS_SIMULATION_TURFS 4
#define DOGMOS_SIMULATION_REACTIONS 5
#define DOGMOS_STAGE_RESPONSE_FIELDS 13
#define DOGMOS_STAGE_RESPONSE_PENDING 5
#define DOGMOS_STAGE_RESPONSE_REMAINING_LOW 6
#define DOGMOS_STAGE_RESPONSE_REMAINING_HIGH 7
#define DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_LOW 8
#define DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_HIGH 9
#define DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_LOW 10
#define DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_HIGH 11
#define DOGMOS_STAGE_MINIMUM_BUDGET_MS 1
#define DOGMOS_STAGE_FULL_BUDGET_MS 10

/** Service-owned Dogmos state retained by Dream Maker only for identity translation. */
/datum/controller/subsystem/dogmos
	/// Whether the production service passed identity and health checks.
	var/service_ready = FALSE
	/// Whether the first authoritative service failure has already emitted its diagnostic.
	var/service_failure_latched = FALSE
	/// Weak mixture references indexed by bounded IPC slot.
	var/list/dogmos_mixture_slots = list()
	/// Current generation for every allocated mixture slot.
	var/list/dogmos_mixture_generations = list()
	/// Reusable mixture slots released by lifecycle unregister.
	var/list/dogmos_free_mixture_slots = list()
	/// Mixture unregister records deferred until the committed-frontier topology barrier.
	var/list/dogmos_pending_mixture_unregistrations = list()
	/// Dense numeric gas id keyed by DM gas path and native string id.
	var/list/dogmos_gas_ids = list()
	/// Gas paths indexed by numeric gas id plus one.
	var/list/dogmos_gas_paths = list()
	/// Reaction datums indexed by numeric reaction id plus one.
	var/list/dogmos_reaction_ids = list()
	/// Weak arbitrary-holder references indexed by bounded IPC slot.
	var/list/dogmos_holder_slots = list()
	/// Current generation for every arbitrary-holder slot.
	var/list/dogmos_holder_generations = list()
	/// Reusable arbitrary-holder slots.
	var/list/dogmos_free_holder_slots = list()
	/// Next expected callback sequence as four exact little-endian 16-bit words.
	var/list/dogmos_next_callback_sequence = list(1, 0, 0, 0)
	/// Callback batch retained across SSair fires when the current time budget expires.
	var/list/dogmos_pending_callback_batch
	/// Zero-based event index within the retained callback batch.
	var/dogmos_pending_callback_index = 0
	/// Event count validated when the retained batch was received, reused across resumes so
	/// process_atmos_callbacks() doesn't re-validate and re-walk the whole batch every call.
	var/dogmos_pending_callback_count = 0
	/// Number of callbacks still queued in dogmosd after the retained batch.
	var/dogmos_pending_service_callbacks = 0
	/// Number of stale turf callbacks rejected before invoking a gameplay proc.
	var/dogmos_stale_callback_count = 0
	/// Number of explicit health preflights performed by SSair fires.
	var/dogmos_health_preflight_count = 0
	/// Whether startup turf mutations are accumulating in bounded IPC batches.
	var/turf_registration_batching = FALSE
	/// Pending fixed-width turf lifecycle records keyed by turf slot.
	var/list/dogmos_pending_turf_lifecycle = list()
	/// Pending fixed-width turf adjacency records keyed by canonical slot pair.
	var/list/dogmos_pending_turf_adjacency = list()
	/// Reverse index: turf slot (string) -> set of dogmos_pending_turf_adjacency keys touching it.
	/// Lets discard_pending_turf_adjacencies() evict one turf's stale edges in O(its own degree)
	/// instead of scanning the entire pending batch - the scan cost otherwise multiplies against
	/// every register_dogmos_air() call in a startup/runtime rebuild, which is unnoticeable on a
	/// handful of test turfs but quadratic-ish and multi-minute on a real map's turf count.
	var/list/dogmos_pending_turf_adjacency_index = list()
	/// Pending fixed-width turf heat records keyed by turf slot.
	var/list/dogmos_pending_turf_heat = list()
	/// Pending fixed-width turf heat-adjacency records keyed by canonical slot pair.
	var/list/dogmos_pending_turf_heat_adjacency = list()
	/// Reverse index: turf slot (string) -> set of dogmos_pending_turf_heat_adjacency keys touching it.
	var/list/dogmos_pending_turf_heat_adjacency_index = list()
	/// Turfs whose adjacency pass must be retried after startup registration or a runtime stage barrier.
	var/list/dogmos_pending_adjacency_retry = list()
	/// Whether one runtime adjacency queue is coalescing repeated turf updates.
	var/runtime_topology_batching = FALSE
	/// Number of runtime topology records accepted by dogmosd.
	var/dogmos_runtime_topology_records = 0
	/// Number of runtime topology IPC calls accepted by dogmosd.
	var/dogmos_runtime_topology_calls = 0
	/// Maximum combined queued runtime topology mutations.
	var/dogmos_runtime_topology_max_queued = 0
	/// Number of topology flushes deferred behind a pending simulation stage.
	var/dogmos_runtime_topology_deferrals = 0
	/// Fixed-size direct-mapped cache of service mixture snapshots.
	var/list/dogmos_mixture_cache
	/// Exact integer epoch invalidating every cached snapshot in O(1).
	var/dogmos_mixture_cache_epoch = 1
	/// Number of mixture snapshot cache hits.
	var/dogmos_mixture_cache_hits = 0
	/// Number of mixture snapshot cache misses.
	var/dogmos_mixture_cache_misses = 0
	/// Number of live direct-mapped entries displaced by another handle.
	var/dogmos_mixture_cache_collisions = 0
	/// Number of stage-wide cache epoch invalidations.
	var/dogmos_mixture_cache_epoch_invalidations = 0

/** Starts bounded accumulation of startup turf mutations. */
/datum/controller/subsystem/dogmos/proc/begin_turf_registration_batch()
	if(turf_registration_batching)
		CRASH("Attempted to nest Dogmos turf registration batches.")
	turf_registration_batching = TRUE
	dogmos_pending_turf_lifecycle.Cut()
	dogmos_pending_turf_adjacency.Cut()
	dogmos_pending_turf_adjacency_index.Cut()
	dogmos_pending_turf_heat.Cut()
	dogmos_pending_turf_heat_adjacency.Cut()
	dogmos_pending_turf_heat_adjacency_index.Cut()
	dogmos_pending_adjacency_retry.Cut()

/** Flushes pending turf mutations in bounded batches while preserving lifecycle-before-topology ordering. */
/datum/controller/subsystem/dogmos/proc/flush_turf_registration_batch()
	if(SSair?.dogmos_pending_frontier_epoch)
		dogmos_runtime_topology_deferrals++
		return FALSE
	flush_pending_mixture_unregistrations()
	if(!turf_registration_batching)
		retry_pending_turf_adjacencies()
	while(length(dogmos_pending_turf_lifecycle))
		var/list/lifecycle_batch = list()
		var/list/lifecycle_keys = list()
		var/lifecycle_count = 0
		for(var/turf_slot in dogmos_pending_turf_lifecycle)
			var/list/lifecycle_records = dogmos_pending_turf_lifecycle[turf_slot]
			var/record_count = length(lifecycle_records) / DOGMOS_TURF_LIFECYCLE_FIELDS
			if(lifecycle_count && lifecycle_count + record_count > DOGMOS_TURF_BATCH_OPERATIONS)
				break
			lifecycle_batch += lifecycle_records
			lifecycle_keys += turf_slot
			lifecycle_count += record_count
		if(dogmos_turf_lifecycle_batch(lifecycle_batch) != lifecycle_count)
			CRASH("dogmosd rejected a turf lifecycle batch.")
		for(var/lifecycle_key in lifecycle_keys)
			dogmos_pending_turf_lifecycle.Remove(lifecycle_key)
	while(length(dogmos_pending_turf_heat))
		var/list/heat_batch = list()
		var/list/heat_keys = list()
		for(var/heat_turf_slot in dogmos_pending_turf_heat)
			heat_batch += dogmos_pending_turf_heat[heat_turf_slot]
			heat_keys += heat_turf_slot
			if(length(heat_keys) >= DOGMOS_TURF_BATCH_OPERATIONS)
				break
		var/heat_count = length(heat_keys)
		if(dogmos_turf_heat_batch(heat_batch) != heat_count)
			CRASH("dogmosd rejected a turf heat batch.")
		for(var/heat_key in heat_keys)
			dogmos_pending_turf_heat.Remove(heat_key)
	while(length(dogmos_pending_turf_adjacency))
		var/list/adjacency_batch = list()
		var/list/adjacency_keys = list()
		for(var/edge_key in dogmos_pending_turf_adjacency)
			adjacency_batch += dogmos_pending_turf_adjacency[edge_key]
			adjacency_keys += edge_key
			if(length(adjacency_keys) >= DOGMOS_TURF_BATCH_OPERATIONS)
				break
		var/adjacency_count = length(adjacency_keys)
		if(dogmos_turf_adjacency_batch(adjacency_batch) != adjacency_count)
			CRASH("dogmosd rejected a turf adjacency batch.")
		for(var/adjacency_key in adjacency_keys)
			remove_pending_gas_edge(adjacency_key)
		if(!turf_registration_batching)
			dogmos_runtime_topology_records += adjacency_count
			dogmos_runtime_topology_calls++
	while(length(dogmos_pending_turf_heat_adjacency))
		var/list/heat_adjacency_batch = list()
		var/list/heat_adjacency_keys = list()
		for(var/heat_edge_key in dogmos_pending_turf_heat_adjacency)
			heat_adjacency_batch += dogmos_pending_turf_heat_adjacency[heat_edge_key]
			heat_adjacency_keys += heat_edge_key
			if(length(heat_adjacency_keys) >= DOGMOS_TURF_BATCH_OPERATIONS)
				break
		var/heat_adjacency_count = length(heat_adjacency_keys)
		if(dogmos_turf_heat_adjacency_batch(heat_adjacency_batch) != heat_adjacency_count)
			CRASH("dogmosd rejected a turf heat-adjacency batch.")
		for(var/heat_adjacency_key in heat_adjacency_keys)
			remove_pending_heat_edge(heat_adjacency_key)
		if(!turf_registration_batching)
			dogmos_runtime_topology_records += heat_adjacency_count
			dogmos_runtime_topology_calls++
	return TRUE

/** Retires deferred mixture identities before applying dependent turf topology mutations. */
/datum/controller/subsystem/dogmos/proc/flush_pending_mixture_unregistrations()
	while(length(dogmos_pending_mixture_unregistrations))
		var/list/lifecycle_batch = list()
		var/list/retired_slots = list()
		for(var/slot_key in dogmos_pending_mixture_unregistrations)
			lifecycle_batch += dogmos_pending_mixture_unregistrations[slot_key]
			retired_slots += text2num(slot_key)
			if(length(retired_slots) >= DOGMOS_TURF_BATCH_OPERATIONS)
				break
		if(dogmos_mixture_lifecycle_batch(lifecycle_batch) != length(retired_slots))
			CRASH("dogmosd rejected a deferred mixture unregistration batch.")
		for(var/retired_slot in retired_slots)
			dogmos_pending_mixture_unregistrations.Remove("[retired_slot]")
			dogmos_free_mixture_slots += retired_slot

/** Rebuilds deferred turf adjacency records from current DM state without nested flushing. */
/datum/controller/subsystem/dogmos/proc/retry_pending_turf_adjacencies()
	if(!length(dogmos_pending_adjacency_retry))
		return
	var/list/retry_turfs = dogmos_pending_adjacency_retry.Copy()
	dogmos_pending_adjacency_retry.Cut()
	var/original_runtime_batching = runtime_topology_batching
	runtime_topology_batching = TRUE
	for(var/turf/retry_turf as anything in retry_turfs)
		if(!retry_turf)
			continue
		retry_turf.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	runtime_topology_batching = original_runtime_batching

/** Flushes a full startup turf batch before any wire payload can exceed its bound. */
/datum/controller/subsystem/dogmos/proc/flush_full_turf_registration_batch()
	if(length(dogmos_pending_turf_lifecycle) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_adjacency) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_heat) >= DOGMOS_TURF_BATCH_OPERATIONS \
		|| length(dogmos_pending_turf_heat_adjacency) >= DOGMOS_TURF_BATCH_OPERATIONS)
		flush_turf_registration_batch()

/** Adds one edge key to a slot's reverse-index bucket. Idempotent - a set, not a list of duplicates. */
/datum/controller/subsystem/dogmos/proc/index_pending_edge(list/index, slot_key, edge_key)
	var/list/entries = index[slot_key]
	if(!entries)
		entries = list()
		index[slot_key] = entries
	entries[edge_key] = TRUE

/** Removes one edge key from a slot's reverse-index bucket, dropping the bucket once empty. */
/datum/controller/subsystem/dogmos/proc/unindex_pending_edge(list/index, slot_key, edge_key)
	var/list/entries = index[slot_key]
	if(!entries)
		return
	entries -= edge_key
	if(!length(entries))
		index -= slot_key

/** Removes one pending gas-adjacency edge from both the batch and its reverse index. */
/datum/controller/subsystem/dogmos/proc/remove_pending_gas_edge(edge_key)
	var/list/edge = dogmos_pending_turf_adjacency[edge_key]
	if(!edge)
		return
	dogmos_pending_turf_adjacency.Remove(edge_key)
	unindex_pending_edge(dogmos_pending_turf_adjacency_index, "[edge[1]]", edge_key)
	unindex_pending_edge(dogmos_pending_turf_adjacency_index, "[edge[3]]", edge_key)

/** Removes one pending heat-adjacency edge from both the batch and its reverse index. */
/datum/controller/subsystem/dogmos/proc/remove_pending_heat_edge(edge_key)
	var/list/edge = dogmos_pending_turf_heat_adjacency[edge_key]
	if(!edge)
		return
	dogmos_pending_turf_heat_adjacency.Remove(edge_key)
	unindex_pending_edge(dogmos_pending_turf_heat_adjacency_index, "[edge[1]]", edge_key)
	unindex_pending_edge(dogmos_pending_turf_heat_adjacency_index, "[edge[3]]", edge_key)

/**
 * Removes pending topology that predates a turf's latest registration state.
 *
 * Looks up the reverse index instead of scanning the full pending batch - this runs on every
 * register_dogmos_air() call, so an O(pending batch size) scan here multiplies against every
 * turf touched during a startup or runtime adjacency rebuild. Unnoticeable at unit-test scale
 * (a handful of turfs), it cost minutes on a real map's turf count.
 */
/datum/controller/subsystem/dogmos/proc/discard_pending_turf_adjacencies(turf/target)
	var/slot = target.dogmos_service_slot()
	var/slot_key = "[slot]"
	var/list/gas_candidates = dogmos_pending_turf_adjacency_index[slot_key]
	if(gas_candidates)
		for(var/edge_key in gas_candidates.Copy())
			remove_pending_gas_edge(edge_key)
	var/list/heat_candidates = dogmos_pending_turf_heat_adjacency_index[slot_key]
	if(heat_candidates)
		for(var/heat_edge_key in heat_candidates.Copy())
			remove_pending_heat_edge(heat_edge_key)

/** Flushes and closes startup turf mutation accumulation. */
/datum/controller/subsystem/dogmos/proc/finish_turf_registration_batch()
	if(!turf_registration_batching)
		CRASH("Attempted to finish an inactive Dogmos turf registration batch.")
	// Every turf has now had its Initalize_Atmos() pass, so retry any turf whose own adjacency
	// pass bailed earlier on an unregistered self or neighbor - both sides should be registered
	// by now, so this is the last chance to pick up edges the slot-ordered boot walk dropped.
	retry_pending_turf_adjacencies()
	if(!flush_turf_registration_batch())
		CRASH("Dogmos startup turf mutations were blocked by an unexpected pending stage.")
	turf_registration_batching = FALSE

/** Publishes an accepted mixture registration or fails the atmosphere subsystem closed.
 *
 * Arguments:
 * * mixture - Mixture receiving the accepted service identity.
 * * slot - Allocated service slot.
 * * generation - Allocated service generation.
 * * response - Native lifecycle response for this registration.
 * * schedule_reboot - Whether rejection schedules the production reboot.
 */
/datum/controller/subsystem/dogmos/proc/finalize_mixture_registration(datum/gas_mixture/mixture, slot, generation, response, schedule_reboot = TRUE)
	if(response != 1)
		SSair.dogmos_fail_closed_stage("mixture registration", schedule_reboot)
		return FALSE
	dogmos_mixture_slots[slot] = WEAKREF(mixture)
	mixture.dogmos_slot = slot
	mixture.dogmos_generation = generation
	mixture._extools_pointer_gasmixture = TRUE
	return TRUE

/** Registers one gas mixture with a stale-handle-safe numeric identity. */
/datum/controller/subsystem/dogmos/proc/register_mixture(datum/gas_mixture/mixture)
	if(!service_ready)
		if(!service_failure_latched)
			CRASH("Attempted to register a gas mixture while dogmosd is unavailable.")
		return

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

	var/response = dogmos_mixture_lifecycle_batch(list(DOGMOS_LIFECYCLE_REGISTER, slot, generation))
	if(!finalize_mixture_registration(mixture, slot, generation, response))
		return
	// The service creates a mixture already at its own default volume, so sending that same value
	// back is a wasted round trip - and it is the common case, because every turf uses it.
	// Measured over initialization this removes about half of all mixture commands.
	if(mixture.initial_volume != DOGMOS_DEFAULT_MIXTURE_VOLUME)
		mixture.set_volume(mixture.initial_volume)

/** Unregisters one gas mixture and makes its slot eligible for generational reuse. */
/datum/controller/subsystem/dogmos/proc/unregister_mixture(datum/gas_mixture/mixture)
	var/slot = mixture.dogmos_slot
	var/generation = mixture.dogmos_generation
	var/datum/weakref/registered_mixture
	if(slot)
		registered_mixture = dogmos_mixture_slots[slot]
	if(!slot || registered_mixture?.reference != REF(mixture) || dogmos_mixture_generations[slot] != generation)
		CRASH("Attempted to unregister stale Dogmos mixture identity [slot]:[generation].")

	if(service_ready)
		if(SSair?.dogmos_pending_frontier_epoch)
			dogmos_pending_mixture_unregistrations["[slot]"] = list(DOGMOS_LIFECYCLE_UNREGISTER, slot, generation)
		else
			if(dogmos_mixture_lifecycle_batch(list(DOGMOS_LIFECYCLE_UNREGISTER, slot, generation)) != 1)
				CRASH("dogmosd rejected mixture unregistration for [slot]:[generation].")
			dogmos_free_mixture_slots += slot

	evict_mixture_snapshot_cache(slot, generation)
	dogmos_mixture_slots[slot] = null
	mixture.dogmos_slot = null
	mixture.dogmos_generation = null
	mixture._extools_pointer_gasmixture = null

/** Resolves a mixture identity without accepting stale generations. */
/datum/controller/subsystem/dogmos/proc/resolve_mixture(slot, generation)
	if(!slot || dogmos_mixture_generations[slot] != generation)
		return null
	var/datum/weakref/reference = dogmos_mixture_slots[slot]
	return reference?.resolve()

/** Resets the bounded mixture snapshot cache and its counters. */
/datum/controller/subsystem/dogmos/proc/reset_mixture_snapshot_cache()
	dogmos_mixture_cache = new/list(DOGMOS_MIXTURE_CACHE_BUCKETS)
	dogmos_mixture_cache_epoch = 1
	dogmos_mixture_cache_hits = 0
	dogmos_mixture_cache_misses = 0
	dogmos_mixture_cache_collisions = 0
	dogmos_mixture_cache_epoch_invalidations = 0

/** Returns the direct-mapped cache bucket for one positive mixture slot. */
/datum/controller/subsystem/dogmos/proc/mixture_snapshot_cache_bucket(slot)
	return (slot % DOGMOS_MIXTURE_CACHE_BUCKETS) + 1

/** Returns a cached snapshot only for the exact current handle and cache epoch. */
/datum/controller/subsystem/dogmos/proc/lookup_mixture_snapshot_cache(slot, generation)
	if(!dogmos_mixture_cache)
		reset_mixture_snapshot_cache()
	var/list/entry = dogmos_mixture_cache[mixture_snapshot_cache_bucket(slot)]
	if(!entry || entry[1] != slot || entry[2] != generation || entry[3] != dogmos_mixture_cache_epoch)
		return null
	var/list/cached = entry[4]
	// store_mixture_snapshot_cache() is the only writer and only runs after mixture_snapshot() has
	// validated length, so a malformed entry should be unreachable. Checked anyway because the failure
	// mode if it ever is reachable is silent and remote: a short list here is returned straight to
	// callers that index it by field constant, surfacing as "cannot read from list" in return_pressure()
	// and friends with nothing pointing back at the cache. Treated as a miss so the fresh-fetch path's
	// own validation produces the real diagnosis.
	if(!islist(cached) || length(cached) != DOGMOS_MIXTURE_SNAPSHOT_FIELDS)
		stack_trace("Discarded a malformed cached mixture snapshot for [slot]:[generation]: length [islist(cached) ? length(cached) : "not a list"], expected [DOGMOS_MIXTURE_SNAPSHOT_FIELDS].")
		dogmos_mixture_cache[mixture_snapshot_cache_bucket(slot)] = null
		return null
	dogmos_mixture_cache_hits++
	return cached

/** Stores one validated service snapshot in its direct-mapped cache bucket. */
/datum/controller/subsystem/dogmos/proc/store_mixture_snapshot_cache(slot, generation, list/snapshot)
	if(!dogmos_mixture_cache)
		reset_mixture_snapshot_cache()
	var/bucket = mixture_snapshot_cache_bucket(slot)
	var/list/displaced = dogmos_mixture_cache[bucket]
	if(displaced && displaced[3] == dogmos_mixture_cache_epoch && (displaced[1] != slot || displaced[2] != generation))
		dogmos_mixture_cache_collisions++
	dogmos_mixture_cache[bucket] = list(slot, generation, dogmos_mixture_cache_epoch, snapshot)
	return snapshot

/** Evicts a cached snapshot only when the direct-mapped entry matches the exact handle. */
/datum/controller/subsystem/dogmos/proc/evict_mixture_snapshot_cache(slot, generation)
	if(!dogmos_mixture_cache || !slot)
		return
	var/bucket = mixture_snapshot_cache_bucket(slot)
	var/list/entry = dogmos_mixture_cache[bucket]
	if(entry && entry[1] == slot && entry[2] == generation)
		dogmos_mixture_cache[bucket] = null

/** Invalidates every mixture snapshot in O(1), clearing once at exact-integer rollover. */
/datum/controller/subsystem/dogmos/proc/invalidate_mixture_snapshot_epoch()
	if(!dogmos_mixture_cache)
		reset_mixture_snapshot_cache()
	dogmos_mixture_cache_epoch_invalidations++
	if(dogmos_mixture_cache_epoch >= DOGMOS_MAX_EXACT_INTEGER)
		dogmos_mixture_cache = new/list(DOGMOS_MIXTURE_CACHE_BUCKETS)
		dogmos_mixture_cache_epoch = 1
		return
	dogmos_mixture_cache_epoch++

/** Returns one validated cached or freshly fetched service-owned mixture snapshot. */
/datum/controller/subsystem/dogmos/proc/mixture_snapshot(slot, generation)
	var/list/cached = lookup_mixture_snapshot_cache(slot, generation)
	if(cached)
		return cached
	if(!service_ready)
		var/list/failed_snapshot = new/list(DOGMOS_MIXTURE_SNAPSHOT_FIELDS)
		failed_snapshot[1] = slot || 0
		failed_snapshot[2] = generation || 0
		failed_snapshot[DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE] = T20C
		failed_snapshot[DOGMOS_MIXTURE_SNAPSHOT_VOLUME] = CELL_VOLUME
		return failed_snapshot
	dogmos_mixture_cache_misses++
	var/list/snapshot = dogmos_mixture_snapshot(list(slot, generation))
	if(!islist(snapshot) || length(snapshot) != DOGMOS_MIXTURE_SNAPSHOT_FIELDS)
		CRASH("dogmosd returned a malformed mixture snapshot for [slot]:[generation].")
	var/gas_count = snapshot[DOGMOS_MIXTURE_SNAPSHOT_GAS_COUNT]
	if(gas_count < 0 || gas_count > length(dogmos_gas_paths) || round(gas_count) != gas_count)
		// The actuals are the whole diagnosis here: this rejection aborts mixture_snapshot(), which then
		// returns null to every caller, so the visible symptom is a flood of downstream "cannot read from
		// list" runtimes in return_pressure()/return_volume() rather than this root cause. Without the
		// numbers there is no way to tell an out-of-range count from a non-integer one, or a genuine
		// service fault from dogmos_gas_paths not having been populated.
		CRASH("dogmosd returned an invalid mixture gas count for [slot]:[generation]: got [gas_count], registered gas paths [length(dogmos_gas_paths)].")
	return store_mixture_snapshot_cache(slot, generation, snapshot)

/** Allocates a bounded ephemeral identity for an arbitrary reaction holder. */
/datum/controller/subsystem/dogmos/proc/register_holder(datum/holder)
	if(isnull(holder))
		return list(0, 0)

	var/slot
	if(length(dogmos_free_holder_slots))
		slot = pop(dogmos_free_holder_slots)
		dogmos_holder_generations[slot]++
	else
		slot = length(dogmos_holder_slots) + 1
		if(slot > DOGMOS_MAX_EXACT_INTEGER)
			CRASH("Dogmos holder identity capacity exhausted.")
		dogmos_holder_generations += 1
		dogmos_holder_slots.len = slot

	var/generation = dogmos_holder_generations[slot]
	if(generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Dogmos holder generation exhausted for slot [slot].")
	dogmos_holder_slots[slot] = WEAKREF(holder)
	return list(slot, generation)

/** Releases an ephemeral holder identity after its synchronous reaction completes. */
/datum/controller/subsystem/dogmos/proc/unregister_holder(list/handle)
	var/slot = handle[1]
	if(!slot)
		return
	dogmos_holder_slots[slot] = null
	dogmos_free_holder_slots += slot

/** Resolves an arbitrary holder identity without accepting stale generations. */
/datum/controller/subsystem/dogmos/proc/resolve_holder(slot, generation)
	if(!slot)
		return null
	if(dogmos_holder_generations[slot] != generation)
		return null
	var/datum/weakref/reference = dogmos_holder_slots[slot]
	return reference?.resolve()

/** Converts the shim's exact 16-bit word pair back into a 32-bit identity field. */
/datum/controller/subsystem/dogmos/proc/join_u32_words(low_word, high_word)
	return low_word + high_word * DOGMOS_PROCESS_WORD_BASE

/** Converts four exact 16-bit words into one unsigned process metric. */
/datum/controller/subsystem/dogmos/proc/join_u64_words(word_one, word_two, word_three, word_four)
	return word_one + DOGMOS_PROCESS_WORD_BASE * (word_two + DOGMOS_PROCESS_WORD_BASE * (word_three + DOGMOS_PROCESS_WORD_BASE * word_four))

/** Splits one bounded nonnegative integer into two exact little-endian 16-bit words. */
/datum/controller/subsystem/dogmos/proc/split_u32_words(value)
	if(!IS_FINITE(value) || value < 0 || value > DOGMOS_MAX_EXACT_INTEGER || round(value) != value)
		CRASH("Dogmos cannot encode invalid u32-compatible value [value].")
	return list(value % DOGMOS_PROCESS_WORD_BASE, floor(value / DOGMOS_PROCESS_WORD_BASE))

/** Advances one four-word exact epoch without converting it to an imprecise DM number. */
/datum/controller/subsystem/dogmos/proc/increment_u64_words(list/words)
	if(!islist(words) || length(words) != 4)
		CRASH("Dogmos received a malformed exact epoch.")
	var/list/advanced = words.Copy()
	for(var/word_index in 1 to 4)
		if(advanced[word_index] < DOGMOS_PROCESS_WORD_MAX)
			advanced[word_index]++
			return advanced
		advanced[word_index] = 0
	CRASH("Dogmos exact epoch capacity exhausted.")

/** Returns whether two exact four-word epochs are identical. */
/datum/controller/subsystem/dogmos/proc/equal_u64_words(list/left, list/right)
	if(!islist(left) || !islist(right) || length(left) != 4 || length(right) != 4)
		return FALSE
	for(var/word_index in 1 to 4)
		if(left[word_index] != right[word_index])
			return FALSE
	return TRUE

/** Returns whether a list is one exact unsigned 32-bit value encoded as two 16-bit words. */
/datum/controller/subsystem/dogmos/proc/u32_words_are_valid(list/words)
	if(!islist(words) || length(words) != 2)
		return FALSE
	for(var/word in words)
		if(!isnum(word) || !IS_FINITE(word) || word < 0 || word > DOGMOS_PROCESS_WORD_MAX || round(word) != word)
			return FALSE
	return TRUE

/** Validates and decodes one fixed-width process-metrics snapshot. */
/datum/controller/subsystem/dogmos/proc/decode_process_metrics(list/words)
	if(!islist(words) || length(words) != DOGMOS_PROCESS_METRICS_WORDS)
		return null
	for(var/word in words)
		if(!IS_FINITE(word) || word < 0 || word > DOGMOS_PROCESS_WORD_MAX || round(word) != word)
			return null

	var/layout_version = join_u32_words(words[DOGMOS_PROCESS_LAYOUT_WORD], words[DOGMOS_PROCESS_LAYOUT_WORD + 1])
	var/dreamdaemon_flags = join_u32_words(words[DOGMOS_PROCESS_HOST_FLAGS_WORD], words[DOGMOS_PROCESS_HOST_FLAGS_WORD + 1])
	var/service_flags = join_u32_words(words[DOGMOS_PROCESS_SERVICE_FLAGS_WORD], words[DOGMOS_PROCESS_SERVICE_FLAGS_WORD + 1])
	var/reserved = join_u32_words(words[DOGMOS_PROCESS_RESERVED_WORD], words[DOGMOS_PROCESS_RESERVED_WORD + 1])
	if(layout_version != DOGMOS_PROCESS_METRICS_LAYOUT_VERSION || dreamdaemon_flags > DOGMOS_DREAMDAEMON_ALL_AVAILABLE || service_flags > DOGMOS_SERVICE_ALL_AVAILABLE || reserved)
		return null

	var/private_bytes = join_u64_words(words[DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD], words[DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD + 1], words[DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD + 2], words[DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD + 3])
	var/virtual_bytes = join_u64_words(words[DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD], words[DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD + 1], words[DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD + 2], words[DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD + 3])
	var/working_set_bytes = join_u64_words(words[DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD], words[DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD + 1], words[DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD + 2], words[DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD + 3])
	var/service_rss_bytes = join_u64_words(words[DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD], words[DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD + 1], words[DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD + 2], words[DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD + 3])
	var/service_cpu_total_milliseconds = join_u64_words(words[DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD], words[DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD + 1], words[DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD + 2], words[DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD + 3])
	if(!(dreamdaemon_flags & DOGMOS_DREAMDAEMON_PRIVATE_BYTES_AVAILABLE) && private_bytes)
		return null
	if(!(dreamdaemon_flags & DOGMOS_DREAMDAEMON_VIRTUAL_BYTES_AVAILABLE) && virtual_bytes)
		return null
	if(!(dreamdaemon_flags & DOGMOS_DREAMDAEMON_WORKING_SET_BYTES_AVAILABLE) && working_set_bytes)
		return null
	if(!(service_flags & DOGMOS_SERVICE_RSS_BYTES_AVAILABLE) && service_rss_bytes)
		return null
	if(!(service_flags & DOGMOS_SERVICE_CPU_MILLISECONDS_AVAILABLE) && service_cpu_total_milliseconds)
		return null

	return list(
		"dreamdaemon" = list(
			"private_bytes" = private_bytes,
			"virtual_bytes" = virtual_bytes,
			"working_set_bytes" = working_set_bytes,
			"available" = dreamdaemon_flags == DOGMOS_DREAMDAEMON_ALL_AVAILABLE,
		),
		"dogmosd" = list(
			"rss_bytes" = service_rss_bytes,
			"cpu_total_milliseconds" = service_cpu_total_milliseconds,
			"available" = service_flags == DOGMOS_SERVICE_ALL_AVAILABLE,
		),
	)

/** Returns one validated on-demand snapshot of DreamDaemon and dogmosd process metrics. */
/proc/dogmos_process_metrics_snapshot()
	var/list/decoded = SSdogmos.decode_process_metrics(dogmos_process_metrics())
	if(!decoded)
		CRASH("dogmosd returned malformed process metrics.")
	return decoded

/** Resolves a coordinate-derived turf identity without accepting a stale generation. */
/datum/controller/subsystem/dogmos/proc/resolve_turf(slot, generation)
	if(slot <= 0 || slot > DOGMOS_MAX_EXACT_INTEGER || generation <= 0 || generation > DOGMOS_MAX_EXACT_INTEGER)
		return null
	var/zero_based_slot = slot - 1
	var/x_coordinate = (zero_based_slot % world.maxx) + 1
	zero_based_slot = floor(zero_based_slot / world.maxx)
	var/y_coordinate = (zero_based_slot % world.maxy) + 1
	var/z_coordinate = floor(zero_based_slot / world.maxy) + 1
	if(z_coordinate > world.maxz)
		return null
	var/turf/resolved = locate(x_coordinate, y_coordinate, z_coordinate)
	if(resolved?.dogmos_registration_generation != generation)
		return null
	return resolved

/** Returns a caller-legible diagnostic when a callback does not match the next expected sequence. */
/datum/controller/subsystem/dogmos/proc/callback_sequence_error(list/batch, offset, list/next_sequence)
	if(length(batch) < offset + DOGMOS_CALLBACK_EVENT_FIELDS - 1)
		return "Dogmos callback sequence at offset [offset] is truncated."
	for(var/word_index in 1 to 4)
		if(batch[offset + word_index - 1] != next_sequence[word_index])
			return "Dogmos callback sequence mismatch at offset [offset]: expected [next_sequence[1] || 0]:[next_sequence[2] || 0]:[next_sequence[3] || 0]:[next_sequence[4] || 0], received [batch[offset] || 0]:[batch[offset + 1] || 0]:[batch[offset + 2] || 0]:[batch[offset + 3] || 0]."
	return null

/** Advances one scope-local callback sequence after validating the current event. */
/datum/controller/subsystem/dogmos/proc/consume_callback_sequence(list/batch, offset, list/next_sequence)
	var/sequence_error = callback_sequence_error(batch, offset, next_sequence)
	if(sequence_error)
		return sequence_error
	for(var/word_index in 1 to 4)
		next_sequence[word_index]++
		if(next_sequence[word_index] <= DOGMOS_PROCESS_WORD_MAX)
			return null
		next_sequence[word_index] = 0
	return "Dogmos callback sequence exhausted after [batch[offset]]:[batch[offset + 1]]:[batch[offset + 2]]:[batch[offset + 3]]."

/** Validates the flattened callback batch and returns its event count. */
/datum/controller/subsystem/dogmos/proc/validate_callback_batch(list/batch, scope, list/transaction_words)
	if(!islist(batch) || length(batch) < DOGMOS_CALLBACK_HEADER_FIELDS)
		CRASH("dogmosd returned a malformed callback batch.")
	var/returned = join_u32_words(batch[1], batch[2])
	if(returned > DOGMOS_CALLBACK_BATCH_SIZE || length(batch) != DOGMOS_CALLBACK_HEADER_FIELDS + returned * DOGMOS_CALLBACK_EVENT_FIELDS)
		CRASH("dogmosd returned a callback batch with an invalid event count.")
	for(var/event_index in 0 to returned - 1)
		if(!returned)
			break
		var/offset = DOGMOS_CALLBACK_EVENT_START + event_index * DOGMOS_CALLBACK_EVENT_FIELDS
		if(batch[offset + DOGMOS_CALLBACK_SCOPE_FIELD] != scope)
			CRASH("dogmosd returned a callback event in the wrong scope.")
		for(var/word_index in 1 to 4)
			if(batch[offset + DOGMOS_CALLBACK_TRANSACTION_WORD + word_index - 1] != transaction_words[word_index])
				CRASH("dogmosd returned a callback event for the wrong transaction.")
	return returned

/** Records one stale callback while keeping the exported counter exactly representable by BYOND. */
/datum/controller/subsystem/dogmos/proc/record_stale_callback()
	dogmos_stale_callback_count = min(dogmos_stale_callback_count + 1, DOGMOS_MAX_EXACT_INTEGER)

/** Dispatches one non-reaction callback after validating sequence and turf generations. */
/datum/controller/subsystem/dogmos/proc/dispatch_general_callback(list/batch, offset)
	var/sequence_error = consume_callback_sequence(batch, offset, dogmos_next_callback_sequence)
	if(sequence_error)
		stack_trace(sequence_error)
		return FALSE
	var/kind = batch[offset + DOGMOS_CALLBACK_KIND_FIELD]

	// Reactions evaluated during turf-stage FDM processing (not a synchronous mixture.react()
	// call) have no open direct-reaction transaction to attach to, so dogmosd surfaces them here
	// instead. Their subject/target fields are a mixture + holder, not turfs - dispatch them
	// before the turf-only kind gate below ever tries to resolve_turf() them.
	if(kind == DOGMOS_CALLBACK_REACTION_FINISHED || kind == DOGMOS_CALLBACK_REACTION_PROFILED || kind == DOGMOS_CALLBACK_RUN_DM_REACTION)
		dispatch_general_reaction_callback(batch, offset, kind)
		return TRUE

	if(kind < DOGMOS_CALLBACK_PRESSURE_DIFFERENCE || kind > DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST)
		CRASH("Unexpected Dogmos callback kind [kind] during general callback processing.")

	var/subject_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD + 1])
	var/subject_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD + 1])
	var/turf/subject = resolve_turf(subject_slot, subject_generation)
	if(!subject)
		record_stale_callback()
		return TRUE

	var/turf/target
	if(kind == DOGMOS_CALLBACK_PRESSURE_DIFFERENCE || kind == DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION)
		var/target_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD + 1])
		var/target_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD + 1])
		target = resolve_turf(target_slot, target_generation)
		if(!target)
			record_stale_callback()
			return TRUE

	switch(kind)
		if(DOGMOS_CALLBACK_PRESSURE_DIFFERENCE)
			if(!isopenturf(subject))
				CRASH("Dogmos pressure callback referenced a non-open turf.")
			var/turf/open/open_subject = subject
			open_subject.consider_pressure_difference(target, batch[offset + DOGMOS_CALLBACK_VALUES_FIELD])
		if(DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP)
			subject.handle_decompression_floor_rip(batch[offset + DOGMOS_CALLBACK_VALUES_FIELD])
		if(DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION)
			subject.consider_firelocks(target)
		if(DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST)
			var/reason = join_u32_words(batch[offset + DOGMOS_CALLBACK_AUX_FIELD], batch[offset + DOGMOS_CALLBACK_AUX_FIELD + 1])
			if(reason != DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT)
				CRASH("Dogmos requested unknown turf destruction reason [reason].")
			subject.to_be_destroyed = TRUE
	return TRUE

/** Decodes a general reaction callback's exact mixture identity for fail-closed validation. */
/datum/controller/subsystem/dogmos/proc/decode_general_reaction_subject(list/batch, offset)
	var/subject_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD + 1])
	var/subject_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD + 1])
	return list(resolve_mixture(subject_slot, subject_generation), subject_slot, subject_generation)

/** Dispatches a REACTION_FINISHED, REACTION_PROFILED, or RUN_DM_REACTION callback surfaced from
 * turf-stage FDM processing instead of a synchronous direct-reaction transaction. Mirrors the
 * equivalent kind handling in dispatch_reaction_callbacks() - same finish handlers, same
 * telemetry call, same continuation-resume call for a pending DM reaction - but without that
 * path's transaction-scoped re-drain loop: a turf-stage continuation has no transaction (id 0),
 * so any further events its resume produces route into the general queue and surface on the next
 * ordinary callback drain instead of needing to be chased synchronously here.
 */
/datum/controller/subsystem/dogmos/proc/dispatch_general_reaction_callback(list/batch, offset, kind)
	var/list/subject = decode_general_reaction_subject(batch, offset)
	var/datum/gas_mixture/mixture = subject[1]
	if(!mixture)
		record_stale_callback()
		return FALSE

	// Turf-stage reactions encode target as a turf handle (Rust's evaluate_reaction_sequence()
	// is called with target = turf.into()), not a holder handle - those are separate slot
	// registries. dispatch_reaction_callbacks() resolves target via resolve_holder() because its
	// caller is the synchronous single-mixture path, which registers a real holder; this path has
	// no holder registration and must resolve the turf directly. The finish procs below accept
	// any datum, so passing the turf through as "holder" is valid.
	var/target_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD + 1])
	var/target_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD + 1])
	var/datum/holder = resolve_turf(target_slot, target_generation)
	var/value_one = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD]
	var/value_two = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 1]
	var/value_three = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 2]
	var/value_four = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 3]
	var/aux = join_u32_words(batch[offset + DOGMOS_CALLBACK_AUX_FIELD], batch[offset + DOGMOS_CALLBACK_AUX_FIELD + 1])

	if(kind == DOGMOS_CALLBACK_REACTION_PROFILED)
		var/datum/gas_reaction/standard/profiled_reaction = dogmos_reaction_ids[aux + 1]
		if(!istype(profiled_reaction))
			CRASH("Dogmos profiled unknown reaction id [aux].")
		SSair.kennel_record_reaction_cost(profiled_reaction.id, holder, value_one)
		return TRUE

	if(kind == DOGMOS_CALLBACK_RUN_DM_REACTION)
		var/datum/gas_reaction/standard/reaction = dogmos_reaction_ids[aux + 1]
		if(!istype(reaction))
			CRASH("Dogmos requested unknown DM reaction id [aux].")
		var/reaction_result = reaction.react(mixture, holder)
		var/list/resume_fields = batch.Copy(offset + DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD, offset + DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD + 10)
		resume_fields += reaction_result
		var/list/progress = dogmos_continuation_resume(resume_fields)
		if(!islist(progress) || length(progress) != 8 || progress[1] != DOGMOS_RESPONSE_REACTION_PROGRESS)
			CRASH("dogmosd returned malformed continuation progress for a turf-stage DM reaction.")
		// Unlike dispatch_reaction_callbacks()'s transaction-scoped loop, no synchronous re-drain
		// is needed here: this continuation has no transaction (turf-stage origin), so any further
		// events the resume produces route back into the general queue (transaction id 0) and get
		// picked up by the next ordinary callback drain instead of needing to be chased here.
		return TRUE

	switch(aux)
		if(DOGMOS_REACTION_PLASMA)
			dogmos_aphelion_plasmafire_finish(mixture, holder, value_one, value_two)
		if(DOGMOS_REACTION_HYDROGEN)
			dogmos_aphelion_h2fire_finish(mixture, holder, value_one, value_two)
		if(DOGMOS_REACTION_TRITIUM)
			dogmos_aphelion_tritfire_finish(mixture, holder, value_one, value_two, value_three, value_four)
		if(DOGMOS_REACTION_FREON)
			dogmos_aphelion_freonfire_finish(mixture, holder, value_one, value_two, value_three)
		else
			CRASH("Dogmos returned unknown native reaction kind [aux].")
	return TRUE

/** Completes a retained general callback batch without a time limit before a synchronous reaction. */
/datum/controller/subsystem/dogmos/proc/flush_pending_general_callbacks()
	if(!dogmos_pending_callback_batch)
		return
	var/returned = validate_callback_batch(dogmos_pending_callback_batch, DOGMOS_CALLBACK_SCOPE_GENERAL, list(0, 0, 0, 0))
	while(dogmos_pending_callback_index < returned)
		var/offset = DOGMOS_CALLBACK_EVENT_START + dogmos_pending_callback_index * DOGMOS_CALLBACK_EVENT_FIELDS
		if(!dispatch_general_callback(dogmos_pending_callback_batch, offset))
			dogmos_pending_callback_batch = null
			dogmos_pending_callback_index = 0
			dogmos_pending_service_callbacks = 0
			SSair.dogmos_fail_closed_stage("callback sequence")
			return
		dogmos_pending_callback_index++
	dogmos_pending_callback_batch = null
	dogmos_pending_callback_index = 0
	dogmos_pending_service_callbacks = 0

/** Validates and returns a typed mixture-command response. */
/datum/controller/subsystem/dogmos/proc/mixture_command(list/fields, expected_response)
	if(!service_ready)
		if(!service_failure_latched)
			CRASH("dogmosd became unavailable; in-process atmosphere fallback is forbidden.")
		var/failed_length = expected_response == DOGMOS_RESPONSE_REACTION_PROGRESS ? 8 : 4
		var/list/failed_response = new/list(failed_length)
		failed_response[1] = expected_response
		return failed_response
	var/list/response = dogmos_mixture_command(fields)
	var/expected_length = expected_response == DOGMOS_RESPONSE_REACTION_PROGRESS ? 8 : 4
	if(!islist(response) || length(response) != expected_length || response[1] != expected_response)
		CRASH("dogmosd returned malformed mixture response [json_encode(response)].")
	return response

/** Dispatches the callback kinds required by synchronous mixture reactions. */
/datum/controller/subsystem/dogmos/proc/dispatch_reaction_callbacks(datum/gas_mixture/expected_mixture, list/progress, reaction_profile_threshold_ms)
	if(!islist(progress) || length(progress) != 8 || progress[1] != DOGMOS_RESPONSE_REACTION_PROGRESS)
		CRASH("dogmosd returned malformed reaction progress.")
	var/list/transaction_words = progress.Copy(5, 9)
	if(!transaction_words[1] && !transaction_words[2] && !transaction_words[3] && !transaction_words[4])
		CRASH("dogmosd returned a zero direct-reaction transaction.")
	var/list/next_sequence = list(1, 0, 0, 0)
	var/maximum_events
	var/events_processed = 0
	while(TRUE)
		var/list/drain_fields = list(DOGMOS_CALLBACK_SCOPE_REACTION)
		drain_fields += transaction_words
		drain_fields += split_u32_words(DOGMOS_CALLBACK_BATCH_SIZE)
		var/list/batch = dogmos_callback_drain(drain_fields)
		var/returned = validate_callback_batch(batch, DOGMOS_CALLBACK_SCOPE_REACTION, transaction_words)
		if(isnull(maximum_events))
			var/events_per_reaction = isnull(reaction_profile_threshold_ms) ? 1 : 2
			maximum_events = join_u32_words(batch[5], batch[6]) + length(dogmos_reaction_ids) * events_per_reaction + 1
		events_processed += returned
		if(events_processed > maximum_events || (!returned && progress[4]))
			CRASH("Dogmos reaction continuation exceeded the bounded callback capacity.")
		for(var/event_index in 0 to returned - 1)
			if(!returned)
				break
			var/offset = DOGMOS_CALLBACK_EVENT_START + event_index * DOGMOS_CALLBACK_EVENT_FIELDS
			var/kind = batch[offset + DOGMOS_CALLBACK_KIND_FIELD]
			if(kind != DOGMOS_CALLBACK_REACTION_FINISHED && kind != DOGMOS_CALLBACK_RUN_DM_REACTION && kind != DOGMOS_CALLBACK_REACTION_PROFILED)
				CRASH("Unexpected Dogmos callback kind [kind] during direct reaction processing.")
			var/sequence_error = consume_callback_sequence(batch, offset, next_sequence)
			if(sequence_error)
				CRASH(sequence_error)

			var/subject_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD + 1])
			var/subject_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD + 1])
			var/datum/gas_mixture/mixture = resolve_mixture(subject_slot, subject_generation)
			if(mixture != expected_mixture)
				CRASH("Dogmos reaction callback referenced a stale or unexpected gas mixture.")

			var/target_slot = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_SLOT_FIELD + 1])
			var/target_generation = join_u32_words(batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD], batch[offset + DOGMOS_CALLBACK_TARGET_GENERATION_FIELD + 1])
			var/datum/holder = resolve_holder(target_slot, target_generation)
			var/value_one = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD]
			var/value_two = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 1]
			var/value_three = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 2]
			var/value_four = batch[offset + DOGMOS_CALLBACK_VALUES_FIELD + 3]
			var/aux = join_u32_words(batch[offset + DOGMOS_CALLBACK_AUX_FIELD], batch[offset + DOGMOS_CALLBACK_AUX_FIELD + 1])
			if(kind == DOGMOS_CALLBACK_REACTION_PROFILED)
				var/datum/gas_reaction/standard/profiled_reaction = dogmos_reaction_ids[aux + 1]
				if(!istype(profiled_reaction))
					CRASH("Dogmos profiled unknown reaction id [aux].")
				SSair.kennel_record_reaction_cost(profiled_reaction.id, holder, value_one)
				continue

			if(kind == DOGMOS_CALLBACK_REACTION_FINISHED)
				switch(aux)
					if(DOGMOS_REACTION_PLASMA)
						dogmos_aphelion_plasmafire_finish(mixture, holder, value_one, value_two)
					if(DOGMOS_REACTION_HYDROGEN)
						dogmos_aphelion_h2fire_finish(mixture, holder, value_one, value_two)
					if(DOGMOS_REACTION_TRITIUM)
						dogmos_aphelion_tritfire_finish(mixture, holder, value_one, value_two, value_three, value_four)
					if(DOGMOS_REACTION_FREON)
						dogmos_aphelion_freonfire_finish(mixture, holder, value_one, value_two, value_three)
					else
						CRASH("Dogmos returned unknown native reaction kind [aux].")
				continue

			var/datum/gas_reaction/standard/reaction = dogmos_reaction_ids[aux + 1]
			if(!istype(reaction))
				CRASH("Dogmos requested unknown DM reaction id [aux].")
			var/reaction_started = isnull(reaction_profile_threshold_ms) ? null : TICK_USAGE_REAL
			var/reaction_result = reaction.react(mixture, holder)
			if(!isnull(reaction_started))
				var/reaction_cost_ms = TICK_DELTA_TO_MS(TICK_USAGE_REAL - reaction_started)
				if(reaction_cost_ms >= reaction_profile_threshold_ms)
					SSair.kennel_record_reaction_cost(reaction.id, holder, reaction_cost_ms)
			var/list/resume_fields = batch.Copy(offset + DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD, offset + DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD + 10)
			resume_fields += reaction_result
			progress = dogmos_continuation_resume(resume_fields)
			if(!islist(progress) || length(progress) != 8 || progress[1] != DOGMOS_RESPONSE_REACTION_PROGRESS || !equal_u64_words(progress.Copy(5, 9), transaction_words))
				CRASH("dogmosd returned malformed continuation progress.")

		if(!progress[4])
			if(join_u32_words(batch[3], batch[4]))
				continue
			return progress

/** Returns the loaded platform shim name for legacy diagnostics. */
/proc/__detect_dogmos()
	return world.system_type == UNIX ? "libdogmos" : "dogmos"

/** Returns the first exact mismatch between the loaded shim and generated contract.
 * Arguments:
 * * actual_abi_version - ABI reported by the loaded shim.
 * * actual_protocol_version - Protocol reported by the loaded shim.
 * * actual_source_revision - Source revision reported by the loaded shim.
 * * actual_feature_fingerprint - Feature fingerprint reported by the loaded shim.
 */
/proc/dogmos_contract_identity_error(actual_abi_version, actual_protocol_version, actual_source_revision, actual_feature_fingerprint)
	if(actual_abi_version != DOGMOS_CONTRACT_ABI_VERSION)
		return "Dogmos ABI mismatch: expected [DOGMOS_CONTRACT_ABI_VERSION], actual [actual_abi_version]."
	if(actual_protocol_version != DOGMOS_CONTRACT_PROTOCOL_VERSION)
		return "Dogmos protocol mismatch: expected [DOGMOS_CONTRACT_PROTOCOL_VERSION], actual [actual_protocol_version]."
	if(actual_source_revision != DOGMOS_CONTRACT_SOURCE_REVISION)
		return "Dogmos source revision mismatch: expected [DOGMOS_CONTRACT_SOURCE_REVISION], actual [actual_source_revision]."
	if(actual_feature_fingerprint != DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
		return "Dogmos feature fingerprint mismatch: expected [DOGMOS_CONTRACT_FEATURE_FINGERPRINT], actual [actual_feature_fingerprint]."
	return null

/** Starts dogmosd, validates the generated contract, and installs metadata. */
/proc/auxtools_atmos_init(gas_data)
	SSdogmos.service_failure_latched = FALSE
	var/contract_protocol_version = DOGMOS_CONTRACT_PROTOCOL_VERSION
	if(contract_protocol_version != DOGMOS_REQUIRED_PROTOCOL_VERSION)
		stack_trace("Dogmos contract protocol [DOGMOS_CONTRACT_PROTOCOL_VERSION] is stale; protocol [DOGMOS_REQUIRED_PROTOCOL_VERSION] is required.")
		return FALSE
	var/identity_error = dogmos_contract_identity_error(
		dogmos_abi_version(),
		dogmos_protocol_version(),
		dogmos_source_revision(),
		dogmos_feature_fingerprint(),
	)
	if(identity_error)
		stack_trace(identity_error)
		return FALSE

	var/service_path = world.system_type == UNIX ? "./dogmosd" : "./dogmosd.exe"
	if(!dogmos_service_start(service_path) || !dogmos_service_health())
		stack_trace("dogmosd failed its startup health check.")
		return FALSE

	SSdogmos.service_ready = TRUE
	SSdogmos.dogmos_next_callback_sequence = list(1, 0, 0, 0)
	SSdogmos.dogmos_pending_callback_batch = null
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_service_callbacks = 0
	SSdogmos.dogmos_stale_callback_count = 0
	SSdogmos.dogmos_health_preflight_count = 0
	SSdogmos.dogmos_runtime_topology_records = 0
	SSdogmos.dogmos_runtime_topology_calls = 0
	SSdogmos.dogmos_runtime_topology_max_queued = 0
	SSdogmos.dogmos_runtime_topology_deferrals = 0
	SSdogmos.reset_mixture_snapshot_cache()
	SSdogmos.dogmos_gas_ids = list()
	SSdogmos.dogmos_gas_paths = list()
	var/list/numeric_records = list()
	var/list/keys = list()
	var/list/names = list()
	var/gas_id = 0
	for(var/gas_path in GLOB.gas_data.datums)
		var/datum/gas/gas = GLOB.gas_data.datums[gas_path]
		SSdogmos.dogmos_gas_ids[gas_path] = gas_id
		SSdogmos.dogmos_gas_ids[gas.id] = gas_id
		SSdogmos.dogmos_gas_paths += gas_path
		keys += gas.id
		names += gas.name
		numeric_records += list(gas_id, 0, 0, gas.specific_heat, gas.fusion_power, !isnull(gas.moles_visible), gas.moles_visible || 0, 0, 0, 0, 0, 0, 0)
		gas_id++

	if(dogmos_gas_metadata_install(numeric_records, keys, names, list()) != gas_id)
		stack_trace("dogmosd rejected the gas metadata registry.")
		dogmos_service_shutdown()
		SSdogmos.service_ready = FALSE
		return FALSE

	var/list/reaction_records = list()
	var/list/reaction_keys = list()
	var/list/requirement_records = list()
	SSdogmos.dogmos_reaction_ids = SSair.dogmos_reactions.Copy()
	for(var/reaction_id in 1 to length(SSair.dogmos_reactions))
		var/datum/gas_reaction/standard/reaction = SSair.dogmos_reactions[reaction_id]
		var/execution = 0
		switch(reaction.type)
			if(/datum/gas_reaction/standard/plasmafire)
				execution = DOGMOS_REACTION_PLASMA
			if(/datum/gas_reaction/standard/h2fire)
				execution = DOGMOS_REACTION_HYDROGEN
			if(/datum/gas_reaction/standard/tritfire)
				execution = DOGMOS_REACTION_TRITIUM
			if(/datum/gas_reaction/standard/freonfire)
				execution = DOGMOS_REACTION_FREON

		var/minimum_temperature = reaction.min_requirements["TEMP"]
		var/maximum_temperature = reaction.min_requirements["MAX_TEMP"]
		var/minimum_energy = reaction.min_requirements["ENER"]
		var/minimum_fire_reagents = reaction.min_requirements["FIRE_REAGENTS"]
		reaction_records += list(
			(reaction_id - 1) % 65536,
			floor((reaction_id - 1) / 65536),
			execution,
			reaction.priority,
			!isnull(minimum_temperature),
			minimum_temperature || 0,
			!isnull(maximum_temperature),
			maximum_temperature || 0,
			!isnull(minimum_energy),
			minimum_energy || 0,
			!isnull(minimum_fire_reagents),
			minimum_fire_reagents || 0,
		)
		reaction_keys += reaction.id
		for(var/requirement in reaction.min_requirements)
			if(requirement == "TEMP" || requirement == "MAX_TEMP" || requirement == "ENER" || requirement == "FIRE_REAGENTS")
				continue
			var/requirement_gas_id = SSdogmos.dogmos_gas_ids[requirement]
			if(isnull(requirement_gas_id))
				CRASH("Dogmos reaction [reaction.id] references unknown gas [requirement].")
			requirement_records += list(reaction_id - 1, requirement_gas_id, reaction.min_requirements[requirement])

	if(dogmos_reaction_metadata_install(reaction_records, reaction_keys, requirement_records) != length(SSair.dogmos_reactions))
		stack_trace("dogmosd rejected the reaction metadata registry.")
		dogmos_service_shutdown()
		SSdogmos.service_ready = FALSE
		return FALSE
	return TRUE

/** Stops the production service without attempting a mid-round restart. */
/proc/dogmos_shutdown()
	SSdogmos.service_ready = FALSE
	return dogmos_service_shutdown()

/// Returns whether dogmosd remains healthy.
/datum/controller/subsystem/air/proc/thread_running()
	return SSdogmos.service_ready && dogmos_service_health()

/// Registers this mixture in dogmosd.
/datum/gas_mixture/proc/__gasmixture_register()
	return SSdogmos.register_mixture(src)

/// Unregisters this mixture from dogmosd.
/datum/gas_mixture/proc/__gasmixture_unregister()
	return SSdogmos.unregister_mixture(src)

/// Numeric slot used only for bounded IPC identity translation.
/datum/gas_mixture/var/dogmos_slot
/// Generation paired with dogmos_slot to reject stale callbacks.
/datum/gas_mixture/var/dogmos_generation

/** Sends one canonical mixture command to dogmosd. */
/datum/gas_mixture/proc/dogmos_command(kind, flags = 0, datum/gas_mixture/secondary, scalar_one = 0, scalar_two = 0, scalar_three = 0, gas_id = 0, aux = 0, expected_response = DOGMOS_RESPONSE_APPLIED)
	var/secondary_slot = secondary?.dogmos_slot || 0
	var/secondary_generation = secondary?.dogmos_generation || 0
	var/list/response = SSdogmos.mixture_command(list(kind, flags, dogmos_slot, dogmos_generation, secondary_slot, secondary_generation, scalar_one, scalar_two, scalar_three, gas_id, aux), expected_response)
	if(!is_read_only_dogmos_command(kind))
		SSdogmos.evict_mixture_snapshot_cache(dogmos_slot, dogmos_generation)
		if(secondary_slot && !is_read_only_dogmos_secondary(kind))
			SSdogmos.evict_mixture_snapshot_cache(secondary_slot, secondary_generation)
	return response

/** Returns whether a canonical mixture command cannot change either mixture. */
/datum/gas_mixture/proc/is_read_only_dogmos_command(kind)
	switch(kind)
		if(DOGMOS_COMMAND_GET_MOLES, DOGMOS_COMMAND_TEMPERATURE, DOGMOS_COMMAND_VOLUME, DOGMOS_COMMAND_HEAT_CAPACITY, DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY, DOGMOS_COMMAND_TOTAL_MOLES, DOGMOS_COMMAND_PRESSURE, DOGMOS_COMMAND_THERMAL_ENERGY, DOGMOS_COMMAND_GET_MOLES_BY_FLAGS, DOGMOS_COMMAND_BURNABILITY, DOGMOS_COMMAND_COMPARE, DOGMOS_COMMAND_IS_IMMUTABLE)
			return TRUE
	return FALSE

/** Returns whether a mutating command only reads its secondary mixture. */
/datum/gas_mixture/proc/is_read_only_dogmos_secondary(kind)
	switch(kind)
		if(DOGMOS_COMMAND_COPY_FROM, DOGMOS_COMMAND_EQUALIZE_WITH, DOGMOS_COMMAND_MERGE)
			return TRUE
	return FALSE

/** Returns the common service snapshot for this exact mixture handle. */
/datum/gas_mixture/proc/dogmos_snapshot()
	return SSdogmos.mixture_snapshot(dogmos_slot, dogmos_generation)

/** Reconciles a pipenet's mixtures through one service-owned native transaction.
 *
 * Arguments:
 * * gas_mixture_list - Candidate mixtures gathered from the pipenet and custom reconcilers.
 */
/proc/dogmos_reconcile_pipeline_mixtures(list/datum/gas_mixture/gas_mixture_list)
	if(!SSdogmos.service_ready)
		return
	var/static/process_id = 0
	process_id = WRAP_UID(process_id + 1)
	var/list/datum/gas_mixture/unique_mixtures = list()
	var/list/request_fields = list()
	for(var/datum/gas_mixture/gas_mixture as anything in gas_mixture_list)
		if(gas_mixture.pipeline_cycle == process_id)
			continue
		gas_mixture.pipeline_cycle = process_id
		unique_mixtures += gas_mixture
		request_fields += gas_mixture.dogmos_slot
		request_fields += gas_mixture.dogmos_generation

	if(!length(unique_mixtures))
		return
	var/list/response_fields = dogmos_pipenet_reconcile(request_fields)
	var/expected_response_fields = length(unique_mixtures) * DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS
	if(!islist(response_fields) || length(response_fields) != expected_response_fields)
		CRASH("dogmosd returned a malformed pipenet reconciliation response: got [islist(response_fields) ? length(response_fields) : "not a list"] fields, expected [expected_response_fields].")

	for(var/mixture_index in 1 to length(unique_mixtures))
		var/datum/gas_mixture/gas_mixture = unique_mixtures[mixture_index]
		var/record_start = (mixture_index - 1) * DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS + 1
		var/slot = response_fields[record_start]
		var/generation = response_fields[record_start + 1]
		if(slot != gas_mixture.dogmos_slot || generation != gas_mixture.dogmos_generation)
			CRASH("dogmosd returned pipenet mixture [slot]:[generation] at index [mixture_index], expected [gas_mixture.dogmos_slot]:[gas_mixture.dogmos_generation].")
		var/list/snapshot = response_fields.Copy(record_start + 2, record_start + DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS)
		SSdogmos.store_mixture_snapshot_cache(slot, generation, snapshot)

/**
 * Warms the snapshot cache for a working set of mixtures with bounded service batches.
 *
 * mixture_snapshot() costs a round trip per cache miss, so reading N cold mixtures costs N round
 * trips. Naming them up front batches those reads, which is worth doing whenever the caller
 * already knows what it is about to read - a subsystem's turf frontier, a pipenet, an atmos
 * machine's connected mixtures.
 *
 * Only worth calling when the results will actually be read this tick: the cache is invalidated
 * wholesale by epoch, so a prefetch that nothing consumes is a wasted round trip. The request is
 * capped at DOGMOS_MIXTURE_PREFETCH_LIMIT because the cache is direct-mapped and a larger
 * prefetch would evict itself.
 *
 * The service omits handles it can no longer resolve rather than failing the whole batch, so
 * records are matched by the handle they carry and not by request position, and the returned
 * count may be lower than the number requested. Returns how many snapshots were cached.
 */
/datum/controller/subsystem/dogmos/proc/prefetch_mixture_snapshots(list/datum/gas_mixture/gas_mixture_list)
	if(!service_ready || !length(gas_mixture_list))
		return 0

	var/list/request_fields = list()
	var/list/seen = list()
	var/inspected = 0
	var/cached = 0
	for(var/datum/gas_mixture/gas_mixture as anything in gas_mixture_list)
		if(inspected >= DOGMOS_MIXTURE_PREFETCH_LIMIT)
			break
		inspected++
		if(!gas_mixture || seen[gas_mixture])
			continue
		seen[gas_mixture] = TRUE
		var/slot = gas_mixture.dogmos_slot
		var/generation = gas_mixture.dogmos_generation
		if(!slot || isnull(generation))
			continue
		request_fields += slot
		request_fields += generation
		if(length(request_fields) == DOGMOS_MIXTURE_SNAPSHOT_BATCH_LIMIT * 2)
			cached += prefetch_mixture_snapshot_chunk(request_fields)
			request_fields.Cut()
	if(length(request_fields))
		cached += prefetch_mixture_snapshot_chunk(request_fields)
	return cached

/** Fetches and validates one compact snapshot reply that fits the production IPC window. */
/datum/controller/subsystem/dogmos/proc/prefetch_mixture_snapshot_chunk(list/request_fields)
	var/requested = length(request_fields) / 2
	var/list/response_fields = dogmos_mixture_snapshot_batch(request_fields)
	if(!islist(response_fields))
		CRASH("dogmosd returned a malformed mixture snapshot batch: not a list.")
	var/field_count = length(response_fields)
	if(field_count % DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS)
		CRASH("dogmosd returned a truncated mixture snapshot batch: [field_count] fields is not a whole number of [DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS]-field records.")
	var/record_count = field_count / DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS
	// Records may be omitted, never invented. More back than went out means the service and this
	// caller disagree about the record layout, which would silently poison the cache.
	if(record_count > requested)
		CRASH("dogmosd returned [record_count] mixture snapshots for [requested] requested handles.")

	var/cached = 0
	for(var/record_index in 1 to record_count)
		var/record_start = (record_index - 1) * DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS + 1
		var/slot = response_fields[record_start]
		var/generation = response_fields[record_start + 1]
		// Keyed by the exact handle, so a snapshot that went stale between the request and now is
		// simply never matched by lookup_mixture_snapshot_cache() rather than being served.
		var/list/snapshot = response_fields.Copy(record_start + 2, record_start + DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS)
		store_mixture_snapshot_cache(slot, generation, snapshot)
		cached++

	return cached

/// Returns the numeric gas id installed for a native string id.
/datum/gas_mixture/proc/dogmos_gas_id(gas_id)
	var/numeric_id = SSdogmos.dogmos_gas_ids[gas_id]
	if(isnull(numeric_id))
		CRASH("Unknown Dogmos gas id [gas_id].")
	return numeric_id

/// Sets the moles of one native string gas id.
/datum/gas_mixture/proc/__set_moles(gas_id, amount)
	return dogmos_command(DOGMOS_COMMAND_SET_MOLES, gas_id = dogmos_gas_id(gas_id), scalar_one = amount)[2]

/// Adjusts the moles of one native string gas id.
/datum/gas_mixture/proc/__adjust_moles(gas_id, amount)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_MOLES, gas_id = dogmos_gas_id(gas_id), scalar_one = amount)[2]

/// Adjusts one gas while accounting for its source temperature.
/datum/gas_mixture/proc/__adjust_moles_temp(gas_id, amount, temperature)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE, gas_id = dogmos_gas_id(gas_id), scalar_one = amount, scalar_two = temperature)[2]

/// Returns the moles of one native string gas id.
/datum/gas_mixture/proc/__get_moles(gas_id)
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_GASES_START + dogmos_gas_id(gas_id)]

/// Returns one gas's partial heat capacity.
/datum/gas_mixture/proc/__partial_heat_capacity(gas_id)
	return dogmos_command(DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY, gas_id = dogmos_gas_id(gas_id), expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Applies native string gas id and delta pairs in one bounded request.
/datum/gas_mixture/proc/__adjust_multi(...)
	if(!SSdogmos.service_ready)
		return 0
	var/list/fields = list(dogmos_slot, dogmos_generation)
	for(var/index in 1 to length(args) step 2)
		fields += dogmos_gas_id(args[index])
		fields += args[index + 1]
	var/list/response = dogmos_mixture_adjust_multiple(fields)
	if(!islist(response) || response[1] != DOGMOS_RESPONSE_APPLIED)
		CRASH("dogmosd rejected a multi-gas adjustment.")
	SSdogmos.evict_mixture_snapshot_cache(dogmos_slot, dogmos_generation)
	return response[2]

/// Returns the native string ids currently present in this mixture.
/datum/gas_mixture/proc/__get_gases()
	var/list/snapshot = dogmos_snapshot()
	var/list/gases = list()
	for(var/gas_index in 1 to min(snapshot[DOGMOS_MIXTURE_SNAPSHOT_GAS_COUNT], length(SSdogmos.dogmos_gas_paths)))
		if(snapshot[DOGMOS_MIXTURE_SNAPSHOT_GASES_START + gas_index - 1] > 0)
			var/gas_path = SSdogmos.dogmos_gas_paths[gas_index]
			gases += GLOB.meta_gas_info[META_GAS_ID][gas_path]
	return gases

/// Sets the mixture temperature.
/datum/gas_mixture/proc/set_temperature(temperature)
	return dogmos_command(DOGMOS_COMMAND_SET_TEMPERATURE, scalar_one = temperature)[2]

/// Returns the mixture temperature.
/datum/gas_mixture/proc/return_temperature()
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE]

/// Sets the mixture volume.
/datum/gas_mixture/proc/set_volume(volume)
	return dogmos_command(DOGMOS_COMMAND_SET_VOLUME, scalar_one = volume)[2]

/// Returns the mixture volume.
/datum/gas_mixture/proc/return_volume()
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_VOLUME]

/// Returns the mixture heat capacity.
/datum/gas_mixture/proc/heat_capacity()
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_HEAT_CAPACITY]

/// Returns the mixture total moles.
/datum/gas_mixture/proc/total_moles()
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_TOTAL_MOLES]

/// Returns the mixture pressure.
/datum/gas_mixture/proc/return_pressure()
	return dogmos_snapshot()[DOGMOS_MIXTURE_SNAPSHOT_PRESSURE]

/// Returns the mixture thermal energy.
/datum/gas_mixture/proc/thermal_energy()
	var/list/snapshot = dogmos_snapshot()
	return snapshot[DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE] * snapshot[DOGMOS_MIXTURE_SNAPSHOT_HEAT_CAPACITY]

/// Sets the mixture minimum heat capacity.
/datum/gas_mixture/proc/set_min_heat_capacity(amount)
	return dogmos_command(DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY, scalar_one = amount)[2]

/// Clears all gases from this mixture.
/datum/gas_mixture/proc/clear()
	return dogmos_command(DOGMOS_COMMAND_CLEAR)[2]

/// Adds an amount to every present gas.
/datum/gas_mixture/proc/add(amount)
	return dogmos_command(DOGMOS_COMMAND_ADD, scalar_one = amount)[2]

/// Subtracts an amount from every present gas.
/datum/gas_mixture/proc/subtract(amount)
	return dogmos_command(DOGMOS_COMMAND_ADD, scalar_one = -amount)[2]

/// Multiplies all gases by a coefficient.
/datum/gas_mixture/proc/multiply(coefficient)
	return dogmos_command(DOGMOS_COMMAND_MULTIPLY, scalar_one = coefficient)[2]

/// Divides all gases by a coefficient.
/datum/gas_mixture/proc/divide(coefficient)
	return dogmos_command(DOGMOS_COMMAND_MULTIPLY, scalar_one = 1 / coefficient)[2]

/// Copies the giver mixture into this mixture.
/datum/gas_mixture/proc/copy_from(datum/gas_mixture/giver)
	return dogmos_command(DOGMOS_COMMAND_COPY_FROM, secondary = giver)[2]

/// Merges the giver mixture into this mixture.
/datum/gas_mixture/proc/__merge(datum/gas_mixture/giver)
	return dogmos_command(DOGMOS_COMMAND_MERGE, secondary = giver)[2]

/// Removes an amount into another mixture.
/datum/gas_mixture/proc/__remove(datum/gas_mixture/into, amount)
	return dogmos_command(DOGMOS_COMMAND_REMOVE_AMOUNT_INTO, secondary = into, scalar_one = amount)[2]

/// Removes a ratio into another mixture.
/datum/gas_mixture/proc/__remove_ratio(datum/gas_mixture/into, ratio)
	return dogmos_command(DOGMOS_COMMAND_REMOVE_RATIO_INTO, secondary = into, scalar_one = ratio)[2]

/// Transfers an amount into another mixture.
/datum/gas_mixture/proc/transfer_to(datum/gas_mixture/other, amount)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_AMOUNT, secondary = other, scalar_one = amount)[2]

/// Transfers a ratio into another mixture.
/datum/gas_mixture/proc/transfer_ratio_to(datum/gas_mixture/other, ratio)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_RATIO, secondary = other, scalar_one = ratio)[2]

/// Adds thermal energy to this mixture.
/datum/gas_mixture/proc/adjust_heat(heat)
	return dogmos_command(DOGMOS_COMMAND_ADJUST_HEAT, scalar_one = heat)[2]

/** Returns whether another mixture differs enough to process.
 * Computed locally from the two mixtures' cached snapshots instead of a dogmosd round trip.
 * compare() is pure arithmetic over already-fetched scalar/gas data - routing it through
 * dogmos_command() correctly avoided evicting the read cache (it's in
 * is_read_only_dogmos_command()) but never actually served from it either, so every call paid a
 * full mutex acquire, two shim allocations, two channel handoffs, and a blocking pipe round trip.
 * turf_settled() calls this once per open neighbor of every active turf, every tick - at a few
 * hundred active turfs that's on the order of a thousand uncached round trips/tick, and eating
 * enough of the tick budget there that remove_from_active() (the only path that ever shrinks
 * active_turfs in steady-state play) got starved, which read as active_turfs never settling.
 * Mirrors Command::Compare in world.rs exactly: temperature check gates on total moles too, and
 * (unlike Rust, which always evaluates both regardless) short-circuits once either check finds a
 * difference, since OR doesn't care which side proved it.
 */
/datum/gas_mixture/proc/compare(datum/gas_mixture/other)
	var/list/snapshot = dogmos_snapshot()
	var/list/other_snapshot = other.dogmos_snapshot()
	if(abs(snapshot[DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE] - other_snapshot[DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE]) > DOGMOS_COMPARE_MINIMUM_TEMPERATURE_DELTA \
			&& snapshot[DOGMOS_MIXTURE_SNAPSHOT_TOTAL_MOLES] > DOGMOS_COMPARE_MINIMUM_MOLES_DELTA)
		return TRUE
	for(var/i in DOGMOS_MIXTURE_SNAPSHOT_GASES_START to DOGMOS_MIXTURE_SNAPSHOT_FIELDS)
		if(abs(snapshot[i] - other_snapshot[i]) >= DOGMOS_COMPARE_MINIMUM_MOLES_DELTA)
			return TRUE
	return FALSE

/// Makes this mixture identical to a volume-scaled total mixture.
/datum/gas_mixture/proc/equalize_with(datum/gas_mixture/total)
	return dogmos_command(DOGMOS_COMMAND_EQUALIZE_WITH, secondary = total)[2]

/// Returns whether this mixture is immutable.
/datum/gas_mixture/proc/is_immutable()
	return dogmos_immutable

/// Marks this mixture immutable.
/datum/gas_mixture/proc/mark_immutable()
	var/updated = dogmos_command(DOGMOS_COMMAND_MARK_IMMUTABLE)[2]
	dogmos_immutable = TRUE
	return updated

/// Returns the oxidation power at an optional temperature.
/datum/gas_mixture/proc/get_oxidation_power(temperature)
	var/has_temperature = !isnull(temperature)
	return dogmos_command(DOGMOS_COMMAND_BURNABILITY, flags = has_temperature, scalar_one = temperature || 0, expected_response = DOGMOS_RESPONSE_SCALARS)[2]

/// Returns the fuel amount at an optional temperature.
/datum/gas_mixture/proc/get_fuel_amount(temperature)
	var/has_temperature = !isnull(temperature)
	return dogmos_command(DOGMOS_COMMAND_BURNABILITY, flags = has_temperature, scalar_one = temperature || 0, expected_response = DOGMOS_RESPONSE_SCALARS)[3]

/// Shares temperature with either a mixture or a non-gas heat capacity.
/datum/gas_mixture/proc/temperature_share(...)
	if(istype(args[1], /datum/gas_mixture))
		return dogmos_command(DOGMOS_COMMAND_TEMPERATURE_SHARE, secondary = args[1], scalar_one = args[2], expected_response = DOGMOS_RESPONSE_SCALAR)[2]
	return dogmos_command(DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS, scalar_one = args[1], scalar_two = args[2], scalar_three = args[3], expected_response = DOGMOS_RESPONSE_SCALAR)[2]

/// Returns gas paths whose installed flags overlap the requested mask.
/datum/gas_mixture/proc/get_by_flag(flag)
	return list()

/// Transfers flagged gases into another mixture.
/datum/gas_mixture/proc/__remove_by_flag(datum/gas_mixture/into, flag, amount)
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_BY_FLAGS, flags = flag, secondary = into, scalar_one = amount)[2]

/// Transfers selected gas paths into another mixture.
/datum/gas_mixture/proc/scrub_into(datum/gas_mixture/into, ratio, list/gas_list)
	var/gas_mask = 0
	for(var/gas_path in gas_list)
		gas_mask |= 2 ** dogmos_gas_id(gas_string_id(gas_path))
	return dogmos_command(DOGMOS_COMMAND_TRANSFER_GASES, secondary = into, scalar_one = ratio, aux = gas_mask)[2]

/// Runs the complete native and DM reaction sequence through dogmosd.
/datum/gas_mixture/proc/__react(datum/holder)
	if(!SSdogmos.service_ready)
		return NO_REACTION
	if(get_moles(/datum/gas/hypernoblium) >= REACTION_OPPRESSION_THRESHOLD && return_temperature() > REACTION_OPPRESSION_MIN_TEMP)
		return STOP_REACTIONS
	var/reaction_profile_threshold_ms
	if(SSair.kennel_profile_reactions)
		if(!IS_FINITE(SSair.kennel_high_cost_ms_threshold) || SSair.kennel_high_cost_ms_threshold < 0)
			CRASH("Dogmos reaction profiling received an invalid cost threshold.")
		reaction_profile_threshold_ms = SSair.kennel_high_cost_ms_threshold
	var/list/holder_handle = SSdogmos.register_holder(holder)
	var/list/progress = SSdogmos.mixture_command(list(DOGMOS_COMMAND_REACT, !isnull(reaction_profile_threshold_ms), dogmos_slot, dogmos_generation, holder_handle[1], holder_handle[2], reaction_profile_threshold_ms || 0, 0, 0, 0, 0), DOGMOS_RESPONSE_REACTION_PROGRESS)
	progress = SSdogmos.dispatch_reaction_callbacks(src, progress, reaction_profile_threshold_ms)
	SSdogmos.evict_mixture_snapshot_cache(dogmos_slot, dogmos_generation)
	SSdogmos.unregister_holder(holder_handle)
	return progress[2]

/// Returns the number of registered mixture slots.
/datum/controller/subsystem/air/proc/get_max_gas_mixes()
	return length(SSdogmos.dogmos_mixture_slots)

/// Returns the number of live registered mixtures.
/datum/controller/subsystem/air/proc/get_amt_gas_mixes()
	return length(SSdogmos.dogmos_mixture_slots) - length(SSdogmos.dogmos_free_mixture_slots)

/// Returns the number of reactions accepted by dogmosd.
/proc/dogmos_reaction_count()
	return length(SSdogmos.dogmos_reaction_ids)

/// Returns the number of FFI panics exposed by the service adapter.
/proc/dogmos_ffi_panic_count()
	return 0

/// Returns callback rejection telemetry from dogmosd.
/proc/dogmos_callback_enqueue_failures()
	var/list/telemetry = dogmos_service_telemetry()
	return SSdogmos.join_u32_words(telemetry[25], telemetry[26])

/// Returns the number of stale turf callbacks rejected by the DM identity boundary.
/proc/dogmos_stale_callback_count()
	return SSdogmos.dogmos_stale_callback_count

/// Returns the bounded service telemetry list.
/proc/dogmos_perf_snapshot()
	return json_encode(dogmos_service_telemetry())

/// Detailed service telemetry is always bounded and cannot be disabled.
/proc/dogmos_perf_set_detailed(enabled)
	return TRUE

/** Publishes the full active-turf order as one atomic bounded service frontier. Used only for
 * the first-ever publish; every later call goes through sync_dogmos_frontier()'s incremental
 * add/remove path instead. See sync_dogmos_frontier() for why.
 */
/datum/controller/subsystem/air/proc/bootstrap_dogmos_frontier()
	if(dogmos_pending_frontier_epoch)
		CRASH("Attempted to replace the Dogmos frontier while a simulation cycle is pending.")
	var/list/frontier_pairs = dogmos_prepare_frontier_pairs(active_turfs)
	if(isnull(frontier_pairs))
		return FALSE
	var/list/candidate_epoch = SSdogmos.increment_u64_words(dogmos_frontier_epoch)
	var/list/count_words = SSdogmos.split_u32_words(length(active_turfs))
	var/list/begin_fields = candidate_epoch.Copy()
	begin_fields += count_words
	var/list/accepted_epoch = dogmos_frontier_begin(begin_fields)
	if(!SSdogmos.equal_u64_words(accepted_epoch, candidate_epoch))
		stack_trace("dogmosd rejected or returned a malformed active-frontier begin response.")
		return FALSE

	var/offset = 0
	var/list/append_fields = candidate_epoch.Copy()
	append_fields += SSdogmos.split_u32_words(offset)
	for(var/turf/open/active_turf as anything in active_turfs)
		var/list/pair = frontier_pairs[active_turf]
		append_fields += SSdogmos.split_u32_words(pair[1])
		append_fields += SSdogmos.split_u32_words(pair[2])
		offset++
		if((offset % DOGMOS_TURF_BATCH_OPERATIONS) != 0)
			continue
		var/list/accepted_count = dogmos_frontier_append(append_fields)
		if(!SSdogmos.u32_words_are_valid(accepted_count) || SSdogmos.join_u32_words(accepted_count[1], accepted_count[2]) != DOGMOS_TURF_BATCH_OPERATIONS)
			stack_trace("dogmosd rejected a full active-frontier append at offset [offset - DOGMOS_TURF_BATCH_OPERATIONS].")
			return FALSE
		append_fields = candidate_epoch.Copy()
		append_fields += SSdogmos.split_u32_words(offset)

	var/trailing_count = offset % DOGMOS_TURF_BATCH_OPERATIONS
	if(trailing_count)
		var/list/accepted_trailing = dogmos_frontier_append(append_fields)
		if(!SSdogmos.u32_words_are_valid(accepted_trailing) || SSdogmos.join_u32_words(accepted_trailing[1], accepted_trailing[2]) != trailing_count)
			stack_trace("dogmosd rejected the trailing active-frontier append at offset [offset - trailing_count].")
			return FALSE

	var/list/committed = dogmos_frontier_commit(candidate_epoch.Copy())
	if(!islist(committed) || length(committed) != 6 || !SSdogmos.equal_u64_words(committed.Copy(1, 5), candidate_epoch) || !SSdogmos.u32_words_are_valid(committed.Copy(5, 7)) || SSdogmos.join_u32_words(committed[5], committed[6]) != offset)
		stack_trace("dogmosd returned a malformed active-frontier commit for candidate epoch [json_encode(candidate_epoch)].")
		return FALSE
	dogmos_frontier_epoch = candidate_epoch
	dogmos_pending_frontier_epoch = dogmos_frontier_epoch.Copy()

	// Stores the exact (slot, generation) pair committed for each turf, not just TRUE - removals
	// need to send back the pair dogmosd actually has, not whatever the turf's identity happens
	// to be later (see sync_dogmos_frontier()'s removal comment).
	dogmos_committed_frontier = list()
	for(var/turf/open/active_turf as anything in active_turfs)
		dogmos_committed_frontier[active_turf] = frontier_pairs[active_turf]
	return TRUE

/** Registers stale active turfs, flushes their topology, and returns validated frontier pairs. */
/datum/controller/subsystem/air/proc/dogmos_prepare_frontier_pairs(list/frontier_turfs)
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	SSdogmos.runtime_topology_batching = TRUE
	for(var/turf/open/active_turf as anything in frontier_turfs)
		if(!active_turf || !active_turf.air)
			SSdogmos.runtime_topology_batching = original_runtime_batching
			stack_trace("SSair active frontier contains an invalid turf reference.")
			return null
		if(!dogmos_frontier_turf_registration_is_current(active_turf))
			active_turf.register_dogmos_air()
		active_turf.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	SSdogmos.runtime_topology_batching = original_runtime_batching
	if(!SSdogmos.flush_turf_registration_batch())
		stack_trace("Dogmos topology remained blocked before active-frontier publication.")
		return null

	var/list/frontier_pairs = list()
	for(var/turf/open/active_turf as anything in frontier_turfs)
		var/datum/gas_mixture/mixture = active_turf.air
		var/generation = active_turf.dogmos_registration_generation
		var/slot = active_turf.dogmos_service_slot()
		var/list/pair = list(slot, generation)
		if(!dogmos_frontier_pair_is_valid(pair) || !dogmos_frontier_turf_registration_is_current(active_turf))
			stack_trace("Dogmos active frontier turf [active_turf.type] at [active_turf.x],[active_turf.y],[active_turf.z] remained invalid after registration catch-up: init_air=[active_turf.init_air], air=[!isnull(mixture)], generation=[generation], registered_mixture=[active_turf.dogmos_registered_mixture_slot]:[active_turf.dogmos_registered_mixture_generation], current_mixture=[mixture?.dogmos_slot]:[mixture?.dogmos_generation].")
			return null
		frontier_pairs[active_turf] = pair
	return frontier_pairs

/** Returns whether a frontier pair contains two positive exact IPC identities. */
/datum/controller/subsystem/air/proc/dogmos_frontier_pair_is_valid(list/pair)
	if(!islist(pair) || length(pair) != 2)
		return FALSE
	for(var/field in pair)
		if(!isnum(field) || !IS_FINITE(field) || field <= 0 || field > DOGMOS_MAX_EXACT_INTEGER || round(field) != field)
			return FALSE
	return TRUE

/** Returns whether an active turf has a valid current service identity. */
/datum/controller/subsystem/air/proc/dogmos_frontier_turf_registration_is_current(turf/open/active_turf)
	var/generation = active_turf?.dogmos_registration_generation
	return active_turf?.air && isnum(generation) && IS_FINITE(generation) \
		&& generation > 0 && generation <= DOGMOS_MAX_EXACT_INTEGER && round(generation) == generation

/** Returns whether a committed frontier pair matches the turf's current service identity.
 *
 * Arguments:
 * * active_turf - Turf whose current slot and generation are authoritative.
 * * committed_pair - Previously committed slot and generation.
 */
/datum/controller/subsystem/air/proc/dogmos_frontier_pair_is_current(turf/open/active_turf, list/committed_pair)
	return dogmos_frontier_turf_registration_is_current(active_turf) \
		&& islist(committed_pair) && length(committed_pair) == 2 \
		&& committed_pair[1] == active_turf.dogmos_service_slot() \
		&& committed_pair[2] == active_turf.dogmos_registration_generation

/** Publishes the current active-turf set to dogmosd. The first call bootstraps the frontier via
 * the full begin/append/commit path above; every later call diffs active_turfs against
 * dogmos_committed_frontier (the last-known-committed snapshot) and sends only the delta via the
 * incremental frontier_add/frontier_remove ops. Re-uploading the entire active-turf set every
 * tick (the original design) made per-tick publish cost scale with active_turfs size on every
 * single fire() - with diffusion actually propagating turf-to-turf, active_turfs legitimately
 * reaches the hundreds, and that dominated Atmospherics MC cost.
 */
/datum/controller/subsystem/air/proc/sync_dogmos_frontier()
	if(isnull(dogmos_committed_frontier))
		return bootstrap_dogmos_frontier()

	var/list/active_set = list()
	for(var/turf/open/active_turf as anything in active_turfs)
		active_set[active_turf] = TRUE

	var/list/added = list()
	var/list/removed_pairs = list()
	var/list/removed_turfs = list()
	for(var/turf/open/active_turf as anything in active_set)
		var/list/committed_pair = dogmos_committed_frontier[active_turf]
		if(dogmos_frontier_pair_is_current(active_turf, committed_pair))
			continue
		added += active_turf
		if(committed_pair)
			removed_pairs += list(committed_pair)
			removed_turfs += active_turf

	// Removals must use the exact (slot, generation) pair captured when the turf was added, not
	// its current identity. This includes active turfs whose generation changed in place: remove
	// the committed pair before adding the replacement or dogmosd keeps processing the retired
	// handle while DM incorrectly treats the turf reference as unchanged.
	for(var/turf/open/committed_turf as anything in dogmos_committed_frontier)
		if(!active_set[committed_turf])
			removed_pairs += list(dogmos_committed_frontier[committed_turf])
			removed_turfs += committed_turf

	if(!length(added) && !length(removed_pairs))
		// Nothing changed since the last commit, so dogmosd's committed epoch is still whatever
		// dogmos_frontier_epoch already holds - but dogmos_pending_frontier_epoch was reset to
		// null by the previous pass's completion (process_turf_heat()), and dogmos_run_stage()
		// unconditionally appends it into the stage request fields. Leaving it null here sends a
		// null field into dogmos_simulation_stage_ffi and crashes with "Value is not a number".
		dogmos_pending_frontier_epoch = dogmos_frontier_epoch.Copy()
		return TRUE

	if(dogmos_pending_frontier_epoch)
		return TRUE
	var/list/added_pairs_by_turf = list()
	if(length(added))
		added_pairs_by_turf = dogmos_prepare_frontier_pairs(added)
		if(isnull(added_pairs_by_turf))
			return FALSE

	if(length(removed_pairs))
		if(!dogmos_frontier_send_chunks(/proc/dogmos_frontier_remove, removed_pairs, "remove"))
			return FALSE
		for(var/turf/open/removed_turf as anything in removed_turfs)
			dogmos_committed_frontier -= removed_turf
		dogmos_pending_frontier_epoch = dogmos_frontier_epoch.Copy()

	if(length(added))
		var/list/added_pairs = list()
		for(var/turf/open/added_turf as anything in added)
			added_pairs += list(added_pairs_by_turf[added_turf])
		if(!dogmos_frontier_send_chunks(/proc/dogmos_frontier_add, added_pairs, "add"))
			return FALSE
		for(var/index in 1 to length(added))
			dogmos_committed_frontier[added[index]] = added_pairs[index]
		dogmos_pending_frontier_epoch = dogmos_frontier_epoch.Copy()
	return TRUE

/** Sends one incremental frontier mutation (add or remove) to dogmosd in bounded chunks. Each
 * chunk is its own atomic add/remove call (no begin/append/commit two-phase for this path), and
 * dogmosd requires a strictly increasing epoch per call - so the epoch is bumped once per chunk,
 * not once for the whole added/removed list. Removing an already-absent handle is not an error
 * (dogmosd tolerates it - see FrontierState::remove()'s doc comment), so only the add path
 * enforces an exact accepted-count match; a short remove count is expected, not a fault.
 */
/datum/controller/subsystem/air/proc/dogmos_frontier_send_chunks(mutate_proc, list/pairs, label)
	for(var/list/pair as anything in pairs)
		if(!dogmos_frontier_pair_is_valid(pair))
			log_game("Dogmos rejected a malformed incremental frontier [label] pair before service mutation.")
			return FALSE
	var/offset = 0
	var/pair_total = length(pairs)
	var/list/fields = list()
	for(var/list/pair as anything in pairs)
		fields += SSdogmos.split_u32_words(pair[1])
		fields += SSdogmos.split_u32_words(pair[2])
		offset++
		if((offset % DOGMOS_TURF_BATCH_OPERATIONS) != 0 && offset != pair_total)
			continue
		var/chunk_size = offset % DOGMOS_TURF_BATCH_OPERATIONS
		if(!chunk_size)
			chunk_size = DOGMOS_TURF_BATCH_OPERATIONS
		var/list/candidate_epoch = SSdogmos.increment_u64_words(dogmos_frontier_epoch)
		var/list/chunk_fields = candidate_epoch.Copy()
		chunk_fields += fields
		var/list/response = call(mutate_proc)(chunk_fields)
		if(!SSdogmos.u32_words_are_valid(response))
			log_game("dogmosd returned a malformed incremental frontier [label] response at offset [offset - chunk_size].")
			return FALSE
		var/accepted = SSdogmos.join_u32_words(response[1], response[2])
		if(accepted > chunk_size || (mutate_proc == /proc/dogmos_frontier_add && accepted != chunk_size))
			log_game("dogmosd rejected an incremental frontier [label] chunk at offset [offset - chunk_size].")
			return FALSE
		dogmos_frontier_epoch = candidate_epoch
		fields = list()
	return TRUE

/** Returns the next bounded work limit for the remaining SSair budget. */
/datum/controller/subsystem/air/proc/dogmos_work_limit_for_budget(remaining_ms)
	if(remaining_ms < DOGMOS_STAGE_MINIMUM_BUDGET_MS)
		return 0
	var/budget_ratio = min(1, remaining_ms / DOGMOS_STAGE_FULL_BUDGET_MS)
	return max(1, min(dogmos_stage_work_limit, floor(dogmos_stage_work_limit * budget_ratio)))

/** Reports an exhausted Dogmos stage so the subsystem can pause after returning. */
/datum/controller/subsystem/air/proc/dogmos_defer_stage_for_budget()
	return TRUE

/** Returns whether a service stage response has the fixed-width numeric wire shape. */
/datum/controller/subsystem/air/proc/dogmos_stage_response_is_valid(stage, response)
	if(!isnum(stage) || !islist(response) || length(response) != DOGMOS_STAGE_RESPONSE_FIELDS)
		return FALSE
	for(var/field in response)
		if(!isnum(field))
			return FALSE
	return TRUE

/** Clears irrecoverable stage state, freezes SSair, and schedules controlled server shutdown.
 *
 * Arguments:
 * * stage - Simulation stage that failed.
 * * schedule_reboot - Whether to schedule the production reboot; FALSE is reserved for unit tests.
 */
/datum/controller/subsystem/air/proc/dogmos_fail_closed_stage(stage, schedule_reboot = TRUE)
	dogmos_pending_stage = null
	dogmos_pending_frontier_epoch = null
	dogmos_stage_remaining_estimate = 0
	dogmos_active_turf_stages_complete = FALSE
	dogmos_fdm_steps_completed = 0
	can_fire = FALSE
	SSdogmos.service_failure_latched = TRUE
	SSdogmos.service_ready = FALSE
	if(schedule_reboot)
		var/reason = "Dogmos atmosphere stage [stage] failed; authoritative atmosphere processing is unavailable."
		log_game(reason)
		SSticker.Reboot(reason, "dogmos service failure", 1 SECONDS)
	return TRUE

/** Runs or resumes one service simulation stage and returns TRUE while work remains. */
/datum/controller/subsystem/air/proc/dogmos_run_stage(stage, remaining_ms)
	if(!SSdogmos.service_ready)
		if(!SSdogmos.service_failure_latched)
			CRASH("dogmosd became unavailable during SSair processing.")
		return TRUE
	if(!isnull(dogmos_pending_stage) && dogmos_pending_stage != stage)
		return TRUE
	if(!dogmos_pending_frontier_epoch)
		if(!sync_dogmos_frontier())
			return dogmos_fail_closed_stage(stage)
	var/work_limit = dogmos_work_limit_for_budget(remaining_ms)
	if(!work_limit)
		dogmos_defer_stage_for_budget()
		return TRUE
	if(isnull(dogmos_pending_stage))
		dogmos_stage_epoch = SSdogmos.increment_u64_words(dogmos_stage_epoch)
		dogmos_pending_stage = stage
	var/list/request = list(stage)
	request += dogmos_pending_frontier_epoch
	request += dogmos_stage_epoch
	request += SSdogmos.split_u32_words(work_limit)
	request += wait * 0.1
	var/list/response = dogmos_simulation_stage(request)
	if(!dogmos_stage_response_is_valid(stage, response))
		stack_trace("dogmosd failed or returned a malformed response for stage [stage]; SSair is failing closed.")
		return dogmos_fail_closed_stage(stage)
	// Only invalidate the snapshot cache when this chunk actually committed mutations. Five
	// stages each running several bounded chunks means an unconditional invalidate here bumps
	// the whole 512-bucket cache ten to thirty times a tick, turning every DM-side gas_mixture
	// read (return_pressure(), total_moles(), heat_capacity(), atmos machinery, ...) back into a
	// synchronous IPC round trip for the rest of the tick - defeating the cache's entire purpose.
	if(SSdogmos.join_u32_words(response[1], response[2]))
		SSdogmos.invalidate_mixture_snapshot_epoch()
	// The wire response already carries how many equalize/group seeds dogmosd actually produced
	// this chunk - num_equalize_processed/num_group_turfs_processed exist specifically to surface
	// that (see dogmos_excited_groups.dm's unit test), but nothing was ever reading these fields.
	num_equalize_processed += SSdogmos.join_u32_words(response[DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_LOW], response[DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_HIGH])
	num_group_turfs_processed += SSdogmos.join_u32_words(response[DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_LOW], response[DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_HIGH])
	dogmos_stage_remaining_estimate = SSdogmos.join_u32_words(response[DOGMOS_STAGE_RESPONSE_REMAINING_LOW], response[DOGMOS_STAGE_RESPONSE_REMAINING_HIGH])
	if(response[DOGMOS_STAGE_RESPONSE_PENDING])
		return TRUE
	dogmos_pending_stage = null
	dogmos_stage_remaining_estimate = 0
	return FALSE

/**
 * Processes the configured number of active-turf FDM passes in dogmosd.
 *
 * Each pass is independently resumable. The remaining budget is reduced after every completed
 * pass so a more aggressive convergence setting cannot silently consume the next server tick.
 *
 * Arguments:
 * * remaining - Milliseconds remaining in the current SSair budget.
 */
/datum/controller/subsystem/air/proc/process_turfs_auxtools(remaining)
	var/start_tick_usage = TICK_USAGE
	var/remaining_ms = max(0, remaining)
	var/step_limit = max(1, round(share_max_steps))
	while(dogmos_fdm_steps_completed < step_limit)
		if(dogmos_run_stage(DOGMOS_SIMULATION_TURFS, remaining_ms))
			return TRUE
		dogmos_fdm_steps_completed++
		remaining_ms = max(0, remaining - TICK_DELTA_TO_MS(TICK_USAGE - start_tick_usage))
	return FALSE

/// Processes active-turf reactions in dogmosd.
/datum/controller/subsystem/air/proc/process_reactions_auxtools(remaining)
	return dogmos_run_stage(DOGMOS_SIMULATION_REACTIONS, remaining)

/// Processes equalization in dogmosd.
/datum/controller/subsystem/air/proc/process_turf_equalize_auxtools(remaining)
	return dogmos_run_stage(DOGMOS_SIMULATION_TURF_EQUALIZE, remaining)

/// Processes excited groups in dogmosd.
/datum/controller/subsystem/air/proc/process_excited_groups_auxtools(remaining)
	return dogmos_run_stage(DOGMOS_SIMULATION_EXCITED_GROUPS, remaining)

/// Processes the turf heat graph in dogmosd.
/datum/controller/subsystem/air/proc/process_turf_heat()
	var/pending = dogmos_run_stage(DOGMOS_SIMULATION_TURF_HEAT, TICK_DELTA_TO_MS(Master.current_ticklimit - TICK_USAGE))
	if(!pending)
		dogmos_pending_frontier_epoch = null
		dogmos_active_turf_stages_complete = FALSE
		SSdogmos.flush_turf_registration_batch()
	return pending

/// Drains one bounded callback batch after service processing.
/datum/controller/subsystem/air/proc/finish_turf_processing_auxtools(time_remaining)
	return process_atmos_callbacks(time_remaining)

/** Returns the deterministic numeric turf identity used across IPC. */
/turf/proc/dogmos_service_slot()
	var/slot = x + world.maxx * (y - 1 + world.maxy * (z - 1))
	if(slot <= 0 || slot > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Turf [x],[y],[z] exceeds Dogmos' exact IPC identity range.")
	return slot

/** Returns the turf generation after enforcing the exact IPC integer range. */
/turf/proc/dogmos_service_generation()
	if(isnull(dogmos_registration_generation) || dogmos_registration_generation <= 0 || dogmos_registration_generation > DOGMOS_MAX_EXACT_INTEGER)
		CRASH("Turf [x],[y],[z] has invalid Dogmos generation [dogmos_registration_generation].")
	return dogmos_registration_generation

/** Registers or removes this turf's service-owned gas and heat state. */
/turf/proc/update_air_ref(flag)
	if(!SSdogmos.service_ready)
		if(!SSdogmos.service_failure_latched)
			CRASH("Attempted to update a turf while dogmosd is unavailable.")
		return

	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	var/registered_heat_temperature
	if(!isnull(dogmos_registered_mixture_slot))
		registered_heat_temperature = __dogmos_heat_temperature()
	if(flag == DOGMOS_SIMULATION_REMOVE)
		var/list/removal = list(
			DOGMOS_LIFECYCLE_REGISTER, slot, generation, FALSE, 0, 0,
			DOGMOS_LIFECYCLE_UNREGISTER, slot, generation, FALSE, 0, 0,
		)
		SSdogmos.discard_pending_turf_adjacencies(src)
		SSdogmos.dogmos_pending_turf_lifecycle["[slot]"] = removal
		SSdogmos.dogmos_pending_turf_heat.Remove("[slot]")
		dogmos_registered_mixture_slot = null
		dogmos_registered_mixture_generation = null
		if(!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching)
			SSdogmos.flush_turf_registration_batch()
		mark_dogmos_turf_replacement()
		return

	var/turf/open/open_turf = isopenturf(src) ? src : null
	var/datum/gas_mixture/mixture = (flag != DOGMOS_SIMULATION_NONE) ? open_turf?.air : null
	var/mixture_present = !isnull(mixture)
	var/mixture_slot = mixture?.dogmos_slot || 0
	var/mixture_generation = mixture?.dogmos_generation || 0
	var/list/lifecycle = list(DOGMOS_LIFECYCLE_REGISTER, slot, generation, mixture_present, mixture_slot, mixture_generation)
	SSdogmos.dogmos_pending_turf_lifecycle["[slot]"] = lifecycle
	dogmos_registered_mixture_slot = mixture_slot
	dogmos_registered_mixture_generation = mixture_generation

	if(flag == DOGMOS_SIMULATION_SPACE_BOUNDARY)
		var/list/space_heat = list(slot, generation, FALSE, 0, 0, 0, FALSE)
		SSdogmos.discard_pending_turf_adjacencies(src)
		SSdogmos.dogmos_pending_turf_heat["[slot]"] = space_heat
		SSdogmos.flush_full_turf_registration_batch()
		if(!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching)
			SSdogmos.flush_turf_registration_batch()
		return

	var/heat_present = thermal_conductivity > 0 && heat_capacity > 0
	var/list/heat = list(
		slot,
		generation,
		heat_present,
		heat_present ? (isnull(registered_heat_temperature) ? initial_temperature : registered_heat_temperature) : 0,
		heat_present ? thermal_conductivity : 0,
		heat_present ? heat_capacity : 0,
		heat_present && should_conduct_to_space(),
	)
	SSdogmos.discard_pending_turf_adjacencies(src)
	SSdogmos.dogmos_pending_turf_heat["[slot]"] = heat
	SSdogmos.flush_full_turf_registration_batch()
	if(!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching)
		SSdogmos.flush_turf_registration_batch()

/** Updates this turf's service-owned heat temperature. */
/turf/proc/__set_temperature(new_temperature)
	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	var/heat_present = thermal_conductivity > 0 && heat_capacity > 0
	var/list/heat = list(
		slot,
		generation,
		heat_present,
		heat_present ? new_temperature : 0,
		heat_present ? thermal_conductivity : 0,
		heat_present ? heat_capacity : 0,
		heat_present && should_conduct_to_space(),
	)
	SSdogmos.dogmos_pending_turf_heat["[slot]"] = heat
	SSdogmos.flush_full_turf_registration_batch()
	if(!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching)
		SSdogmos.flush_turf_registration_batch()
	return new_temperature

/** Returns the service-owned turf temperature. */
/turf/proc/__dogmos_heat_temperature()
	if(!init_air || thermal_conductivity <= 0 || heat_capacity <= 0 || isnull(dogmos_registration_generation))
		return null
	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	var/list/pending_heat = SSdogmos.dogmos_pending_turf_heat["[slot]"]
	if(islist(pending_heat) && length(pending_heat) == 7 && pending_heat[2] == generation)
		return pending_heat[3] ? pending_heat[4] : null
	var/list/snapshot = dogmos_turf_heat_snapshot(list(slot, generation))
	if(length(snapshot) != 5)
		CRASH("dogmosd returned a malformed turf heat snapshot.")
	if(!snapshot[1])
		return null
	return snapshot[2]

/** Rebuilds this turf's gas and heat adjacency edges in dogmosd. */
/turf/proc/__update_auxtools_turf_adjacency_info(max_x, max_y)
	if(max_x != world.maxx || max_y != world.maxy)
		CRASH("Dogmos received stale world dimensions for turf adjacency.")
	if(isnull(dogmos_registration_generation))
		// Boot-time slot ordering means this turf's own registration can still be pending when its
		// pass runs. Queue a retry rather than dropping every edge this turf owns permanently.
		if(SSdogmos.turf_registration_batching)
			SSdogmos.dogmos_pending_adjacency_retry[src] = TRUE
		return
	if(SSair?.dogmos_pending_frontier_epoch && !SSdogmos.turf_registration_batching)
		SSdogmos.dogmos_pending_adjacency_retry[src] = TRUE
		return

	var/slot = dogmos_service_slot()
	var/generation = dogmos_service_generation()
	var/heat_present = thermal_conductivity > 0 && heat_capacity > 0
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(src, direction)
		if(!neighbor)
			continue
		var/neighbor_slot = neighbor.dogmos_service_slot()
		if((neighbor.init_air || isspaceturf(neighbor)) \
			&& ((!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching) \
				|| !neighbor.dogmos_air_registration_is_current(isspaceturf(neighbor))))
			neighbor.register_dogmos_air()
		if(isnull(neighbor.dogmos_registration_generation))
			// Same as above, but the neighbor is the one not yet registered - retry this turf's
			// whole pass later instead of silently dropping just this one edge.
			if(SSdogmos.turf_registration_batching)
				SSdogmos.dogmos_pending_adjacency_retry[src] = TRUE
			continue
		var/neighbor_generation = neighbor.dogmos_service_generation()
		var/turf/open/open_turf = isopenturf(src) ? src : null
		var/turf/open/open_neighbor = isopenturf(neighbor) ? neighbor : null
		var/source_has_gas = (init_air || isspaceturf(src)) && open_turf?.air
		var/neighbor_has_gas = (neighbor.init_air || isspaceturf(neighbor)) && open_neighbor?.air
		if(source_has_gas && neighbor_has_gas && open_turf.air != open_neighbor.air && !blocks_air && !neighbor.blocks_air)
			var/connected = (neighbor in atmos_adjacent_turfs)
			var/firelock = !!(connected && (atmos_adjacent_turfs[neighbor] & DOGMOS_ADJACENT_FIRELOCK))
			var/list/gas_edge = list(slot, generation, neighbor_slot, neighbor_generation, connected, firelock)
			var/gas_edge_key = slot < neighbor_slot ? "[slot]:[generation]:[neighbor_slot]:[neighbor_generation]" : "[neighbor_slot]:[neighbor_generation]:[slot]:[generation]"
			SSdogmos.dogmos_pending_turf_adjacency[gas_edge_key] = gas_edge
			SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[slot]", gas_edge_key)
			SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[neighbor_slot]", gas_edge_key)
		if(heat_present && neighbor.thermal_conductivity > 0 && neighbor.heat_capacity > 0 && init_air && neighbor.init_air && !isspaceturf(src) && !isspaceturf(neighbor))
			var/heat_connected = !(conductivity_blocked_directions & direction) && !(neighbor.conductivity_blocked_directions & turn(direction, 180))
			var/list/heat_edge = list(slot, generation, neighbor_slot, neighbor_generation, heat_connected)
			var/heat_edge_key = slot < neighbor_slot ? "[slot]:[generation]:[neighbor_slot]:[neighbor_generation]" : "[neighbor_slot]:[neighbor_generation]:[slot]:[generation]"
			SSdogmos.dogmos_pending_turf_heat_adjacency[heat_edge_key] = heat_edge
			SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[slot]", heat_edge_key)
			SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[neighbor_slot]", heat_edge_key)

	var/queued_topology = length(SSdogmos.dogmos_pending_turf_adjacency) + length(SSdogmos.dogmos_pending_turf_heat_adjacency)
	SSdogmos.dogmos_runtime_topology_max_queued = max(SSdogmos.dogmos_runtime_topology_max_queued, queued_topology)
	SSdogmos.flush_full_turf_registration_batch()
	if(!SSdogmos.turf_registration_batching && !SSdogmos.runtime_topology_batching)
		SSdogmos.flush_turf_registration_batch()
	return TRUE

/// Drains bounded Dogmos callbacks on the Dream Maker main thread.
/proc/process_atmos_callbacks(remaining)
	var/start_tick_usage = TICK_USAGE
	var/time_budget_ms = max(0, remaining)
	if(time_budget_ms <= 0)
		return TRUE
	if(!SSdogmos.dogmos_pending_callback_batch)
		var/list/drain_fields = list(DOGMOS_CALLBACK_SCOPE_GENERAL, 0, 0, 0, 0)
		drain_fields += SSdogmos.split_u32_words(DOGMOS_CALLBACK_BATCH_SIZE)
		SSdogmos.dogmos_pending_callback_batch = dogmos_callback_drain(drain_fields)
		SSdogmos.dogmos_pending_callback_index = 0
		// Validated once on receipt and reused on every resume below instead of re-validating and
		// re-walking the whole retained batch on every single invocation across ticks.
		SSdogmos.dogmos_pending_callback_count = SSdogmos.validate_callback_batch(SSdogmos.dogmos_pending_callback_batch, DOGMOS_CALLBACK_SCOPE_GENERAL, list(0, 0, 0, 0))
		SSdogmos.dogmos_pending_service_callbacks = SSdogmos.join_u32_words(
			SSdogmos.dogmos_pending_callback_batch[3],
			SSdogmos.dogmos_pending_callback_batch[4],
		)

	var/returned = SSdogmos.dogmos_pending_callback_count
	while(SSdogmos.dogmos_pending_callback_index < returned)
		if(TICK_DELTA_TO_MS(TICK_USAGE - start_tick_usage) >= time_budget_ms)
			return TRUE
		var/offset = DOGMOS_CALLBACK_EVENT_START + SSdogmos.dogmos_pending_callback_index * DOGMOS_CALLBACK_EVENT_FIELDS
		if(!SSdogmos.dispatch_general_callback(SSdogmos.dogmos_pending_callback_batch, offset))
			SSdogmos.dogmos_pending_callback_batch = null
			SSdogmos.dogmos_pending_callback_index = 0
			SSdogmos.dogmos_pending_service_callbacks = 0
			return SSair.dogmos_fail_closed_stage("callback sequence")
		SSdogmos.dogmos_pending_callback_index++

	var/service_callbacks_remain = SSdogmos.dogmos_pending_service_callbacks
	SSdogmos.dogmos_pending_callback_batch = null
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_service_callbacks = 0
	return service_callbacks_remain > 0

/// Equalizes a bounded list through service-owned mixture commands.
/proc/equalize_all_gases_in_list(list/gas_list)
	if(!length(gas_list))
		return
	var/datum/gas_mixture/total = new(CELL_VOLUME)
	for(var/datum/gas_mixture/mixture as anything in gas_list)
		total.merge(mixture)
	for(var/datum/gas_mixture/mixture as anything in gas_list)
		mixture.equalize_with(total)
	qdel(total)

/// Refreshes reaction metadata only during initialization in the service backend.
/datum/controller/subsystem/air/proc/auxtools_update_reactions()
	CRASH("Mid-round Dogmos reaction metadata replacement is unsupported.")

/// Legacy gas registration is replaced by the atomic metadata install.
/proc/_auxtools_register_gas(gas)
	CRASH("Per-gas Dogmos registration is unsupported; use atomic metadata install.")

/// Legacy gas reference finalization is replaced by the atomic metadata install.
/proc/finalize_gas_refs()
	return TRUE

/// Parsing gas strings remains blocked until its service command is added.
/datum/gas_mixture/proc/__auxtools_parse_gas_string(string)
	CRASH("Dogmos service gas-string parsing is not implemented.")

/// Heat graph cardinality is not yet exposed by protocol v6 telemetry.
/proc/dogmos_heat_graph_count()
	return 0

/// Heat graph registration totals are not yet exposed by protocol v6 telemetry.
/proc/dogmos_heat_registration_total()
	return 0

/// Space-boundary cardinality is not yet exposed by protocol v6 telemetry.
/proc/dogmos_space_boundary_count()
	return 0

#undef DOGMOS_REQUIRED_PROTOCOL_VERSION
#undef DOGMOS_MAX_EXACT_INTEGER
#undef DOGMOS_PROCESS_METRICS_WORDS
#undef DOGMOS_PROCESS_METRICS_LAYOUT_VERSION
#undef DOGMOS_PROCESS_WORD_BASE
#undef DOGMOS_PROCESS_WORD_MAX
#undef DOGMOS_PROCESS_LAYOUT_WORD
#undef DOGMOS_PROCESS_HOST_FLAGS_WORD
#undef DOGMOS_PROCESS_SERVICE_FLAGS_WORD
#undef DOGMOS_PROCESS_RESERVED_WORD
#undef DOGMOS_PROCESS_HOST_PRIVATE_BYTES_WORD
#undef DOGMOS_PROCESS_HOST_VIRTUAL_BYTES_WORD
#undef DOGMOS_PROCESS_HOST_WORKING_SET_BYTES_WORD
#undef DOGMOS_PROCESS_SERVICE_RSS_BYTES_WORD
#undef DOGMOS_PROCESS_SERVICE_CPU_MILLISECONDS_WORD
#undef DOGMOS_DREAMDAEMON_PRIVATE_BYTES_AVAILABLE
#undef DOGMOS_DREAMDAEMON_VIRTUAL_BYTES_AVAILABLE
#undef DOGMOS_DREAMDAEMON_WORKING_SET_BYTES_AVAILABLE
#undef DOGMOS_DREAMDAEMON_ALL_AVAILABLE
#undef DOGMOS_SERVICE_RSS_BYTES_AVAILABLE
#undef DOGMOS_SERVICE_CPU_MILLISECONDS_AVAILABLE
#undef DOGMOS_SERVICE_ALL_AVAILABLE
#undef DOGMOS_CALLBACK_BATCH_SIZE
#undef DOGMOS_CALLBACK_HEADER_FIELDS
#undef DOGMOS_CALLBACK_EVENT_FIELDS
#undef DOGMOS_CALLBACK_EVENT_START
#undef DOGMOS_CALLBACK_SCOPE_GENERAL
#undef DOGMOS_CALLBACK_SCOPE_REACTION
#undef DOGMOS_CALLBACK_TRANSACTION_WORD
#undef DOGMOS_CALLBACK_SCOPE_FIELD
#undef DOGMOS_CALLBACK_KIND_FIELD
#undef DOGMOS_CALLBACK_SUBJECT_SLOT_FIELD
#undef DOGMOS_CALLBACK_SUBJECT_GENERATION_FIELD
#undef DOGMOS_CALLBACK_TARGET_SLOT_FIELD
#undef DOGMOS_CALLBACK_TARGET_GENERATION_FIELD
#undef DOGMOS_CALLBACK_VALUES_FIELD
#undef DOGMOS_CALLBACK_AUX_FIELD
#undef DOGMOS_CALLBACK_CONTINUATION_TOKEN_FIELD
#undef DOGMOS_TURF_BATCH_OPERATIONS
#undef DOGMOS_TURF_LIFECYCLE_FIELDS
#undef DOGMOS_TURF_ADJACENCY_FIELDS
#undef DOGMOS_TURF_HEAT_FIELDS
#undef DOGMOS_TURF_HEAT_ADJACENCY_FIELDS
#undef DOGMOS_MIXTURE_CACHE_BUCKETS
#undef DOGMOS_MIXTURE_SNAPSHOT_FIELDS
#undef DOGMOS_MIXTURE_SNAPSHOT_REVISION_LOW
#undef DOGMOS_MIXTURE_SNAPSHOT_REVISION_HIGH
#undef DOGMOS_MIXTURE_SNAPSHOT_GAS_COUNT
#undef DOGMOS_MIXTURE_SNAPSHOT_TEMPERATURE
#undef DOGMOS_MIXTURE_SNAPSHOT_VOLUME
#undef DOGMOS_MIXTURE_SNAPSHOT_TOTAL_MOLES
#undef DOGMOS_MIXTURE_SNAPSHOT_PRESSURE
#undef DOGMOS_MIXTURE_SNAPSHOT_HEAT_CAPACITY
#undef DOGMOS_MIXTURE_SNAPSHOT_IMMUTABLE
#undef DOGMOS_MIXTURE_SNAPSHOT_GASES_START
#undef DOGMOS_DEFAULT_MIXTURE_VOLUME
#undef DOGMOS_MIXTURE_PREFETCH_LIMIT
#undef DOGMOS_MIXTURE_SNAPSHOT_BATCH_LIMIT
#undef DOGMOS_PIPENET_RECONCILE_RECORD_FIELDS
#undef DOGMOS_COMPARE_MINIMUM_MOLES_DELTA
#undef DOGMOS_COMPARE_MINIMUM_TEMPERATURE_DELTA
#undef DOGMOS_LIFECYCLE_REGISTER
#undef DOGMOS_LIFECYCLE_UNREGISTER
#undef DOGMOS_RESPONSE_APPLIED
#undef DOGMOS_RESPONSE_SCALAR
#undef DOGMOS_RESPONSE_SCALARS
#undef DOGMOS_RESPONSE_BOOLEAN
#undef DOGMOS_RESPONSE_REACTION_PROGRESS
#undef DOGMOS_COMMAND_SET_MOLES
#undef DOGMOS_COMMAND_ADJUST_MOLES
#undef DOGMOS_COMMAND_ADJUST_MOLES_TEMPERATURE
#undef DOGMOS_COMMAND_GET_MOLES
#undef DOGMOS_COMMAND_TEMPERATURE
#undef DOGMOS_COMMAND_VOLUME
#undef DOGMOS_COMMAND_HEAT_CAPACITY
#undef DOGMOS_COMMAND_PARTIAL_HEAT_CAPACITY
#undef DOGMOS_COMMAND_TOTAL_MOLES
#undef DOGMOS_COMMAND_PRESSURE
#undef DOGMOS_COMMAND_THERMAL_ENERGY
#undef DOGMOS_COMMAND_GET_MOLES_BY_FLAGS
#undef DOGMOS_COMMAND_BURNABILITY
#undef DOGMOS_COMMAND_SET_TEMPERATURE
#undef DOGMOS_COMMAND_SET_VOLUME
#undef DOGMOS_COMMAND_SET_MINIMUM_HEAT_CAPACITY
#undef DOGMOS_COMMAND_CLEAR
#undef DOGMOS_COMMAND_ADD
#undef DOGMOS_COMMAND_MULTIPLY
#undef DOGMOS_COMMAND_COPY_FROM
#undef DOGMOS_COMMAND_ADJUST_HEAT
#undef DOGMOS_COMMAND_COMPARE
#undef DOGMOS_COMMAND_EQUALIZE_WITH
#undef DOGMOS_COMMAND_TEMPERATURE_SHARE
#undef DOGMOS_COMMAND_TEMPERATURE_SHARE_NON_GAS
#undef DOGMOS_COMMAND_MARK_IMMUTABLE
#undef DOGMOS_COMMAND_IS_IMMUTABLE
#undef DOGMOS_COMMAND_MERGE
#undef DOGMOS_COMMAND_REMOVE_RATIO_INTO
#undef DOGMOS_COMMAND_REMOVE_AMOUNT_INTO
#undef DOGMOS_COMMAND_TRANSFER_GASES
#undef DOGMOS_COMMAND_TRANSFER_AMOUNT
#undef DOGMOS_COMMAND_TRANSFER_RATIO
#undef DOGMOS_COMMAND_TRANSFER_BY_FLAGS
#undef DOGMOS_COMMAND_SHARE_RATIO
#undef DOGMOS_COMMAND_REACT
#undef DOGMOS_CALLBACK_REACTION_FINISHED
#undef DOGMOS_CALLBACK_PRESSURE_DIFFERENCE
#undef DOGMOS_CALLBACK_DECOMPRESSION_FLOOR_RIP
#undef DOGMOS_CALLBACK_FIRELOCK_CONSIDERATION
#undef DOGMOS_CALLBACK_TURF_DESTRUCTION_REQUEST
#undef DOGMOS_CALLBACK_RUN_DM_REACTION
#undef DOGMOS_CALLBACK_REACTION_PROFILED
#undef DOGMOS_TURF_DESTRUCTION_SUPERCONDUCTIVE_HEAT
#undef DOGMOS_REACTION_PLASMA
#undef DOGMOS_REACTION_HYDROGEN
#undef DOGMOS_REACTION_TRITIUM
#undef DOGMOS_REACTION_FREON
#undef DOGMOS_SIMULATION_EXCITED_GROUPS
#undef DOGMOS_SIMULATION_TURF_EQUALIZE
#undef DOGMOS_SIMULATION_TURF_HEAT
#undef DOGMOS_SIMULATION_TURFS
#undef DOGMOS_SIMULATION_REACTIONS
#undef DOGMOS_STAGE_RESPONSE_FIELDS
#undef DOGMOS_STAGE_RESPONSE_PENDING
#undef DOGMOS_STAGE_RESPONSE_REMAINING_LOW
#undef DOGMOS_STAGE_RESPONSE_REMAINING_HIGH
#undef DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_LOW
#undef DOGMOS_STAGE_RESPONSE_EQUALIZE_SEEDS_HIGH
#undef DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_LOW
#undef DOGMOS_STAGE_RESPONSE_GROUP_SEEDS_HIGH
#undef DOGMOS_STAGE_MINIMUM_BUDGET_MS
#undef DOGMOS_STAGE_FULL_BUDGET_MS
