#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

#include "shift_start_performance_test.dm"

#define DOGMOS_WORLD_GENERATION_WORD_MAX 65535
#define DOGMOS_TEST_STAGE_EXCITED_GROUPS 1
#define DOGMOS_TEST_STAGE_EQUALIZE 2
#define DOGMOS_TEST_STAGE_TURF_HEAT 3
#define DOGMOS_TEST_STAGE_TURFS 4
#define DOGMOS_TEST_STAGE_REACTIONS 5
#define DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS 100
#define DOGMOS_TEST_STAGE_RESPONSE_FIELDS 13
#define DOGMOS_PIPELINE_TEST_EPSILON 0.001
#define DOGMOS_TEST_OVERSIZED_PIPELINE_MIXTURES 228
#define DOGMOS_TEST_IDLE_MC_SETTLE_TIME 30 SECONDS
#define DOGMOS_TEST_RESPONSE_APPLIED 1
#define DOGMOS_TEST_SNAPSHOT_REVISION_LOW 1
#define DOGMOS_TEST_SNAPSHOT_REVISION_HIGH 2

/** Returns a malformed frontier response without touching the production service. */
/proc/dogmos_test_reject_frontier_chunk(list/fields)
	return null

/** Verifies startup identity mismatches report exact expected and actual values. */
/datum/unit_test/dogmos_service_contract_identity

/datum/unit_test/dogmos_service_contract_identity/Run()
	var/abi_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION + 1, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(abi_error != "Dogmos ABI mismatch: expected [DOGMOS_CONTRACT_ABI_VERSION], actual [DOGMOS_CONTRACT_ABI_VERSION + 1].")
		return Fail("Dogmos startup did not report the exact ABI mismatch: [abi_error]", __FILE__, __LINE__)
	var/protocol_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION + 1, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(protocol_error != "Dogmos protocol mismatch: expected [DOGMOS_CONTRACT_PROTOCOL_VERSION], actual [DOGMOS_CONTRACT_PROTOCOL_VERSION + 1].")
		return Fail("Dogmos startup did not report the exact protocol mismatch: [protocol_error]", __FILE__, __LINE__)
	var/mismatched_revision = "[DOGMOS_CONTRACT_SOURCE_REVISION]-mismatch"
	var/revision_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, mismatched_revision, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(revision_error != "Dogmos source revision mismatch: expected [DOGMOS_CONTRACT_SOURCE_REVISION], actual [mismatched_revision].")
		return Fail("Dogmos startup did not report the exact source-revision mismatch: [revision_error]", __FILE__, __LINE__)
	var/mismatched_fingerprint = "[DOGMOS_CONTRACT_FEATURE_FINGERPRINT]-mismatch"
	var/fingerprint_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, mismatched_fingerprint)
	if(fingerprint_error != "Dogmos feature fingerprint mismatch: expected [DOGMOS_CONTRACT_FEATURE_FINGERPRINT], actual [mismatched_fingerprint].")
		return Fail("Dogmos startup did not report the exact feature-fingerprint mismatch: [fingerprint_error]", __FILE__, __LINE__)
	var/matching_error = dogmos_contract_identity_error(DOGMOS_CONTRACT_ABI_VERSION, DOGMOS_CONTRACT_PROTOCOL_VERSION, DOGMOS_CONTRACT_SOURCE_REVISION, DOGMOS_CONTRACT_FEATURE_FINGERPRINT)
	if(!isnull(matching_error))
		return Fail("Dogmos startup reported an identity mismatch for the synchronized contract: [matching_error]", __FILE__, __LINE__)

/** Verifies the production service reports its identity and preserves a sentinel mixture. */
/datum/unit_test/dogmos_service_lifecycle
	/// Sentinel mixture released during test teardown.
	var/datum/gas_mixture/sentinel

/datum/unit_test/dogmos_service_lifecycle/Run()
	if(!SSdogmos.service_ready || !dogmos_service_health())
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	var/service_pid = dogmos_service_pid()
	if(!isnum(service_pid) || service_pid <= 0 || round(service_pid) != service_pid)
		return Fail("dogmosd reported invalid service PID [service_pid].", __FILE__, __LINE__)

	var/list/world_generation_words = dogmos_service_world_generation()
	if(!islist(world_generation_words) || length(world_generation_words) != 2)
		return Fail("dogmosd reported malformed world-generation words.", __FILE__, __LINE__)
	for(var/world_generation_word in world_generation_words)
		if(!isnum(world_generation_word) || world_generation_word < 0 || world_generation_word > DOGMOS_WORLD_GENERATION_WORD_MAX || round(world_generation_word) != world_generation_word)
			return Fail("dogmosd reported invalid world-generation word [world_generation_word].", __FILE__, __LINE__)
	if(!world_generation_words[1] && !world_generation_words[2])
		return Fail("dogmosd reported a zero world generation.", __FILE__, __LINE__)

	var/expected_temperature = 321.5
	var/expected_oxygen_moles = 7.25
	sentinel = new(CELL_VOLUME)
	sentinel.set_temperature(expected_temperature)
	sentinel.set_moles(/datum/gas/oxygen, expected_oxygen_moles)
	var/sentinel_temperature = sentinel.return_temperature()
	var/sentinel_oxygen_moles = sentinel.get_moles(/datum/gas/oxygen)
	if(sentinel.dogmos_slot <= 0 || sentinel.dogmos_generation <= 0)
		return Fail("Dogmos assigned an invalid identity to the lifecycle sentinel mixture.", __FILE__, __LINE__)
	if(sentinel_temperature != expected_temperature || sentinel_oxygen_moles != expected_oxygen_moles)
		return Fail("dogmosd did not preserve the lifecycle sentinel mixture state.", __FILE__, __LINE__)

	log_world("DOGMOS SERVICE LIFECYCLE: pid=[service_pid] world_generation_words=[world_generation_words[1]]:[world_generation_words[2]] sentinel=[sentinel.dogmos_slot]:[sentinel.dogmos_generation] temperature=[sentinel_temperature] oxygen_moles=[sentinel_oxygen_moles]")

/datum/unit_test/dogmos_service_lifecycle/Destroy()
	QDEL_NULL(sentinel)
	return ..()

/** Verifies service-backed mixture identities are live, bounded, and generational. */
/datum/unit_test/dogmos_service_mixture_identity

/datum/unit_test/dogmos_service_mixture_identity/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the mixture identity test.", __FILE__, __LINE__)
	var/datum/gas_mixture/first = new(CELL_VOLUME)
	var/first_slot = first.dogmos_slot
	var/first_generation = first.dogmos_generation
	if(first_slot <= 0 || first_slot > 16777216)
		return Fail("Dogmos assigned an invalid mixture slot [first_slot].", __FILE__, __LINE__)
	if(first_generation <= 0 || first_generation > 16777216)
		return Fail("Dogmos assigned an invalid mixture generation [first_generation].", __FILE__, __LINE__)
	var/list/retired_snapshot = new/list(42)
	SSdogmos.store_mixture_snapshot_cache(first_slot, first_generation, retired_snapshot)
	first.__gasmixture_unregister()
	if(SSdogmos.lookup_mixture_snapshot_cache(first_slot, first_generation))
		return Fail("Unregistering a mixture retained its cached snapshot.", __FILE__, __LINE__)
	qdel(first)

	var/datum/gas_mixture/second = new(CELL_VOLUME)
	if(second.dogmos_slot != first_slot)
		return Fail("Dogmos did not reuse the released bounded mixture slot.", __FILE__, __LINE__)
	if(second.dogmos_generation <= first_generation)
		return Fail("Dogmos reused a mixture slot without advancing its generation.", __FILE__, __LINE__)
	if(SSdogmos.lookup_mixture_snapshot_cache(first_slot, first_generation))
		return Fail("A reused mixture slot resolved the retired generation's cached snapshot.", __FILE__, __LINE__)
	qdel(second)

/** Verifies the bounded direct-mapped mixture snapshot cache and mutation invalidation. */
/datum/unit_test/dogmos_service_mixture_snapshot_cache
	/// First service-backed mixture released during teardown.
	var/datum/gas_mixture/first
	/// Second service-backed mixture released during teardown.
	var/datum/gas_mixture/second

/datum/unit_test/dogmos_service_mixture_snapshot_cache/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	SSdogmos.reset_mixture_snapshot_cache()
	first = new(CELL_VOLUME)
	second = new(CELL_VOLUME)
	first.set_temperature(312.5)
	first.set_moles(/datum/gas/oxygen, 4)
	second.set_temperature(290)

	var/misses_before = SSdogmos.dogmos_mixture_cache_misses
	var/hits_before = SSdogmos.dogmos_mixture_cache_hits
	if(first.return_temperature() != 312.5)
		return Fail("The mixture snapshot cache changed the returned temperature.", __FILE__, __LINE__)
	if(first.total_moles() != 4)
		return Fail("The mixture snapshot cache changed the returned total moles.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before + 1 || SSdogmos.dogmos_mixture_cache_hits != hits_before + 1)
		return Fail("Repeated same-revision getters did not produce one cache miss followed by one hit.", __FILE__, __LINE__)

	first.set_temperature(315)
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before + 2)
		return Fail("A primary mixture mutation did not evict its cached snapshot.", __FILE__, __LINE__)

	var/misses_before_multi = SSdogmos.dogmos_mixture_cache_misses
	first.adjust_multi(/datum/gas/oxygen, 1, /datum/gas/nitrogen, 2)
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before_multi + 1)
		return Fail("A multi-gas mutation did not evict its cached snapshot.", __FILE__, __LINE__)

	second.return_temperature()
	var/misses_after_warm = SSdogmos.dogmos_mixture_cache_misses
	var/hits_after_warm = SSdogmos.dogmos_mixture_cache_hits
	first.equalize_with(second)
	first.return_temperature()
	second.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_after_warm + 1 || SSdogmos.dogmos_mixture_cache_hits != hits_after_warm + 1)
		return Fail("Equalizing from a mixture did not preserve its read-only source snapshot.", __FILE__, __LINE__)

	second.return_temperature()
	misses_after_warm = SSdogmos.dogmos_mixture_cache_misses
	hits_after_warm = SSdogmos.dogmos_mixture_cache_hits
	first.copy_from(second)
	first.return_temperature()
	second.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_after_warm + 1 || SSdogmos.dogmos_mixture_cache_hits != hits_after_warm + 1)
		return Fail("Copying from a mixture did not preserve its read-only source snapshot.", __FILE__, __LINE__)

	second.return_temperature()
	misses_after_warm = SSdogmos.dogmos_mixture_cache_misses
	hits_after_warm = SSdogmos.dogmos_mixture_cache_hits
	first.merge(second)
	first.return_temperature()
	second.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_after_warm + 1 || SSdogmos.dogmos_mixture_cache_hits != hits_after_warm + 1)
		return Fail("Merging a mixture did not preserve its read-only source snapshot.", __FILE__, __LINE__)

	first.return_temperature()
	second.return_temperature()
	misses_after_warm = SSdogmos.dogmos_mixture_cache_misses
	first.transfer_to(second, 0.1)
	first.return_temperature()
	second.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_after_warm + 2)
		return Fail("Transferring gas did not evict both mutated mixture snapshots.", __FILE__, __LINE__)

	var/list/fake_snapshot = new/list(42)
	SSdogmos.store_mixture_snapshot_cache(1, 7, fake_snapshot)
	var/collisions_before = SSdogmos.dogmos_mixture_cache_collisions
	// The current 2048-bucket cache maps these distinct slots to the same bucket.
	SSdogmos.store_mixture_snapshot_cache(2049, 9, fake_snapshot)
	if(SSdogmos.dogmos_mixture_cache_collisions != collisions_before + 1)
		return Fail("Direct-mapped cache collisions were not counted.", __FILE__, __LINE__)
	if(!isnull(SSdogmos.lookup_mixture_snapshot_cache(1, 7)))
		return Fail("A colliding slot retained the displaced cache entry.", __FILE__, __LINE__)
	if(SSdogmos.lookup_mixture_snapshot_cache(2049, 8))
		return Fail("The mixture snapshot cache accepted a mismatched generation.", __FILE__, __LINE__)

	var/invalidations_before = SSdogmos.dogmos_mixture_cache_epoch_invalidations
	SSdogmos.invalidate_mixture_snapshot_epoch()
	if(SSdogmos.dogmos_mixture_cache_epoch_invalidations != invalidations_before + 1 || SSdogmos.lookup_mixture_snapshot_cache(2049, 9))
		return Fail("Stage-wide epoch invalidation retained an old snapshot.", __FILE__, __LINE__)
	SSdogmos.dogmos_mixture_cache_epoch = 16777216
	SSdogmos.store_mixture_snapshot_cache(1, 1, fake_snapshot)
	SSdogmos.invalidate_mixture_snapshot_epoch()
	if(SSdogmos.dogmos_mixture_cache_epoch != 1 || SSdogmos.lookup_mixture_snapshot_cache(1, 1))
		return Fail("Exact-integer cache epoch rollover did not clear and reset the bounded cache.", __FILE__, __LINE__)

	first.return_temperature()
	var/misses_before_immutable = SSdogmos.dogmos_mixture_cache_misses
	first.mark_immutable()
	first.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before_immutable + 1)
		return Fail("Marking a mixture immutable did not evict its cached snapshot.", __FILE__, __LINE__)
	SSdogmos.evict_mixture_snapshot_cache(first.dogmos_slot, first.dogmos_generation)
	var/misses_before_local_immutable_check = SSdogmos.dogmos_mixture_cache_misses
	if(!first.is_immutable())
		return Fail("Dogmos did not retain the mixture's immutable state.", __FILE__, __LINE__)
	if(SSdogmos.dogmos_mixture_cache_misses != misses_before_local_immutable_check)
		return Fail("Checking a finalized mixture's immutable state fetched a service snapshot.", __FILE__, __LINE__)
	first.set_temperature(320)
	if(first.return_temperature() != 290)
		return Fail("Dogmos accepted a mutation after immutable finalization.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_mixture_snapshot_cache/Destroy()
	QDEL_NULL(first)
	QDEL_NULL(second)
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/** Verifies pipeline rebuild storage preserves state without repeatedly fetching its source. */
/datum/unit_test/dogmos_service_pipeline_temporary_air
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Pipeline-owned mixture released during teardown.
	var/datum/gas_mixture/pipeline_air
	/// First pipe detached before pipeline teardown.
	var/obj/machinery/atmospherics/pipe/first_pipe
	/// Second pipe detached before pipeline teardown.
	var/obj/machinery/atmospherics/pipe/second_pipe

/datum/unit_test/dogmos_service_pipeline_temporary_air/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	test_pipeline = new
	pipeline_air = new(300)
	pipeline_air.set_temperature(350)
	pipeline_air.set_moles(/datum/gas/oxygen, 30)
	pipeline_air.set_moles(/datum/gas/nitrogen, 15)
	test_pipeline.set_air(pipeline_air)

	first_pipe = allocate(/obj/machinery/atmospherics/pipe/smart/simple)
	second_pipe = allocate(/obj/machinery/atmospherics/pipe/smart/simple)
	first_pipe.volume = 100
	second_pipe.volume = 200
	test_pipeline.members = list(first_pipe, second_pipe)

	SSdogmos.reset_mixture_snapshot_cache()
	var/misses_before = SSdogmos.dogmos_mixture_cache_misses
	test_pipeline.temporarily_store_air()
	var/expected_snapshot_misses = 0
	var/actual_snapshot_misses = SSdogmos.dogmos_mixture_cache_misses - misses_before
	if(actual_snapshot_misses != expected_snapshot_misses)
		return Fail("Pipeline temporary storage used [actual_snapshot_misses] snapshots; expected direct native equalization without snapshots.", __FILE__, __LINE__)

	var/list/first_snapshot = first_pipe.air_temporary.dogmos_snapshot()
	var/list/second_snapshot = second_pipe.air_temporary.dogmos_snapshot()
	var/first_revision = SSdogmos.join_u32_words(first_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_LOW], first_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_HIGH])
	var/second_revision = SSdogmos.join_u32_words(second_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_LOW], second_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_HIGH])
	if(first_revision != 2 || second_revision != 2)
		return Fail("Pipeline temporary storage produced revisions [first_revision] and [second_revision]; expected constructor initialization plus one equalization command.", __FILE__, __LINE__)

	if(abs(first_pipe.air_temporary.return_volume() - 100) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_pipe.air_temporary.return_volume() - 200) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not preserve member volumes.", __FILE__, __LINE__)
	if(abs(first_pipe.air_temporary.return_temperature() - 350) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_pipe.air_temporary.return_temperature() - 350) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not preserve the source temperature.", __FILE__, __LINE__)
	if(abs(first_pipe.air_temporary.get_moles(/datum/gas/oxygen) - 10) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_pipe.air_temporary.get_moles(/datum/gas/oxygen) - 20) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not distribute oxygen by member volume.", __FILE__, __LINE__)
	if(abs(first_pipe.air_temporary.get_moles(/datum/gas/nitrogen) - 5) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_pipe.air_temporary.get_moles(/datum/gas/nitrogen) - 10) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not distribute nitrogen by member volume.", __FILE__, __LINE__)
	if(abs(first_pipe.air_temporary.get_moles(/datum/gas/oxygen) + second_pipe.air_temporary.get_moles(/datum/gas/oxygen) - 30) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not conserve total oxygen.", __FILE__, __LINE__)
	if(abs(first_pipe.air_temporary.get_moles(/datum/gas/nitrogen) + second_pipe.air_temporary.get_moles(/datum/gas/nitrogen) - 15) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline temporary storage did not conserve total nitrogen.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_pipeline_temporary_air/Destroy()
	test_pipeline?.members.Cut()
	if(first_pipe)
		QDEL_NULL(first_pipe.air_temporary)
		first_pipe.parent = null
	if(second_pipe)
		QDEL_NULL(second_pipe.air_temporary)
		second_pipe.parent = null
	QDEL_NULL(test_pipeline)
	QDEL_NULL(pipeline_air)
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/** Verifies one yielded pipeline expansion publishes its accumulated volume once. */
/datum/unit_test/dogmos_service_pipeline_expansion_volume_batch
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Pipeline mixture released during teardown.
	var/datum/gas_mixture/pipeline_air
	/// Allocated pipes detached from the pipeline and each other during teardown.
	var/list/obj/machinery/atmospherics/pipe/test_pipes

/datum/unit_test/dogmos_service_pipeline_expansion_volume_batch/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	test_pipeline = new
	pipeline_air = new(10)
	test_pipeline.set_air(pipeline_air)
	test_pipes = list()
	for(var/pipe_index in 1 to 4)
		var/obj/machinery/atmospherics/pipe/smart/simple/test_pipe = allocate(/obj/machinery/atmospherics/pipe/smart/simple)
		test_pipe.has_gas_visuals = FALSE
		test_pipe.volume = pipe_index * 10
		test_pipe.nodes = list()
		test_pipes += test_pipe

	var/obj/machinery/atmospherics/pipe/first_pipe = test_pipes[1]
	for(var/pipe_index in 2 to length(test_pipes))
		var/obj/machinery/atmospherics/pipe/connected_pipe = test_pipes[pipe_index]
		first_pipe.nodes += connected_pipe
		connected_pipe.nodes += first_pipe

	first_pipe.parent = test_pipeline
	test_pipeline.members = list(first_pipe)
	var/list/revision_before_snapshot = pipeline_air.dogmos_snapshot()
	var/revision_before = SSdogmos.join_u32_words(revision_before_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_LOW], revision_before_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_HIGH])

	SSdogmos.reset_mixture_snapshot_cache()
	var/misses_before = SSdogmos.dogmos_mixture_cache_misses
	var/list/border = list(first_pipe)
	SSair.expand_pipeline(test_pipeline, border)
	for(var/obj/machinery/atmospherics/pipe/test_pipe as anything in test_pipes)
		if(test_pipe.parent != test_pipeline || !(test_pipe in test_pipeline.members))
			return Fail("Pipeline expansion did not attach every discovered pipe.", __FILE__, __LINE__)

	var/list/final_snapshot = pipeline_air.dogmos_snapshot()
	var/final_revision = SSdogmos.join_u32_words(final_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_LOW], final_snapshot[DOGMOS_TEST_SNAPSHOT_REVISION_HIGH])
	if(final_revision != revision_before + 1)
		return Fail("Pipeline expansion advanced mixture revision from [revision_before] to [final_revision]; expected one accumulated volume mutation.", __FILE__, __LINE__)
	if(abs(pipeline_air.return_volume() - 100) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipeline expansion did not publish the summed member volume.", __FILE__, __LINE__)
	var/actual_snapshot_misses = SSdogmos.dogmos_mixture_cache_misses - misses_before
	if(actual_snapshot_misses != 2)
		return Fail("Pipeline expansion used [actual_snapshot_misses] snapshots; expected one initial volume read and one final verification snapshot.", __FILE__, __LINE__)

	SSdogmos.reset_mixture_snapshot_cache()
	var/empty_misses_before = SSdogmos.dogmos_mixture_cache_misses
	SSair.expand_pipeline(test_pipeline, list())
	if(SSdogmos.dogmos_mixture_cache_misses != empty_misses_before)
		return Fail("An empty pipeline expansion fetched mixture state.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_pipeline_expansion_volume_batch/Destroy()
	test_pipeline?.members.Cut()
	for(var/obj/machinery/atmospherics/pipe/test_pipe as anything in test_pipes)
		test_pipe.parent = null
		test_pipe.nodes = new(test_pipe.device_type)
	QDEL_NULL(test_pipeline)
	QDEL_NULL(pipeline_air)
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/** Verifies pipenet reconciliation caches one native response while conserving mixture state. */
/datum/unit_test/dogmos_service_pipeline_batch_reconcile
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// First service-backed mixture released during teardown.
	var/datum/gas_mixture/first
	/// Second service-backed mixture released during teardown.
	var/datum/gas_mixture/second

/datum/unit_test/dogmos_service_pipeline_batch_reconcile/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	first = new(100)
	second = new(300)
	first.set_volume(100)
	second.set_volume(300)
	first.set_temperature(300)
	second.set_temperature(600)
	first.set_moles(/datum/gas/oxygen, 4)
	second.set_moles(/datum/gas/nitrogen, 12)
	var/expected_temperature = (first.return_temperature() * first.heat_capacity() + second.return_temperature() * second.heat_capacity()) / (first.heat_capacity() + second.heat_capacity())

	test_pipeline = new
	test_pipeline.set_air(first)
	test_pipeline.other_airs = list(second)
	var/invalidations_before = SSdogmos.dogmos_mixture_cache_epoch_invalidations
	test_pipeline.reconcile_air()

	if(SSdogmos.dogmos_mixture_cache_epoch_invalidations != invalidations_before)
		return Fail("Pipenet reconciliation invalidated the entire mixture snapshot cache.", __FILE__, __LINE__)
	if(!SSdogmos.lookup_mixture_snapshot_cache(first.dogmos_slot, first.dogmos_generation) || !SSdogmos.lookup_mixture_snapshot_cache(second.dogmos_slot, second.dogmos_generation))
		return Fail("Pipenet reconciliation did not cache both returned service snapshots.", __FILE__, __LINE__)
	var/first_oxygen = first.get_moles(/datum/gas/oxygen)
	var/second_oxygen = second.get_moles(/datum/gas/oxygen)
	if(abs(first_oxygen - 1) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_oxygen - 3) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not distribute oxygen by volume ratio: [first_oxygen] / [second_oxygen].", __FILE__, __LINE__)
	var/first_nitrogen = first.get_moles(/datum/gas/nitrogen)
	var/second_nitrogen = second.get_moles(/datum/gas/nitrogen)
	if(abs(first_nitrogen - 3) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second_nitrogen - 9) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not distribute nitrogen by volume ratio: [first_nitrogen] / [second_nitrogen].", __FILE__, __LINE__)
	if(abs(first.return_temperature() - expected_temperature) > DOGMOS_PIPELINE_TEST_EPSILON || abs(second.return_temperature() - expected_temperature) > DOGMOS_PIPELINE_TEST_EPSILON)
		return Fail("Pipenet reconciliation did not conserve thermal energy.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_pipeline_batch_reconcile/Destroy()
	QDEL_NULL(test_pipeline)
	QDEL_NULL(first)
	QDEL_NULL(second)
	return ..()

/** Verifies pipenet reconciliation remains atomic beyond one control-frame payload. */
/datum/unit_test/dogmos_service_oversized_pipeline_batch_reconcile
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Service-backed mixtures released during teardown.
	var/list/test_mixtures

/datum/unit_test/dogmos_service_oversized_pipeline_batch_reconcile/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)

	test_mixtures = list()
	for(var/mixture_index in 1 to DOGMOS_TEST_OVERSIZED_PIPELINE_MIXTURES)
		var/datum/gas_mixture/mixture = new(100)
		mixture.set_temperature(300)
		mixture.set_moles(/datum/gas/oxygen, 1)
		test_mixtures += mixture

	test_pipeline = new
	test_pipeline.set_air(test_mixtures[1])
	test_pipeline.other_airs = test_mixtures.Copy(2)
	test_pipeline.reconcile_air()

	if(!SSdogmos.service_ready || !dogmos_service_health())
		return Fail("dogmosd became unavailable while reconciling an oversized pipeline batch.", __FILE__, __LINE__)
	for(var/datum/gas_mixture/mixture as anything in test_mixtures)
		if(abs(mixture.get_moles(/datum/gas/oxygen) - 1) > DOGMOS_PIPELINE_TEST_EPSILON || abs(mixture.return_temperature() - 300) > DOGMOS_PIPELINE_TEST_EPSILON)
			return Fail("Oversized pipenet reconciliation changed an equivalent mixture's conserved state.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_oversized_pipeline_batch_reconcile/Destroy()
	QDEL_NULL(test_pipeline)
	QDEL_LIST(test_mixtures)
	return ..()

/** Verifies non-conducting turfs remain absent from the service heat graph. */
/datum/unit_test/dogmos_service_turf_heat_absence
	/// Turf restored after the assertion run.
	var/turf/target
	/// Original thermal conductivity restored during teardown.
	var/original_thermal_conductivity
	/// Original heat capacity restored during teardown.
	var/original_heat_capacity

/datum/unit_test/dogmos_service_turf_heat_absence/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to 20)
		if(!SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the turf heat absence test.", __FILE__, __LINE__)
	target = run_loc_floor_bottom_left
	original_thermal_conductivity = target.thermal_conductivity
	original_heat_capacity = target.heat_capacity
	target.thermal_conductivity = 0
	target.heat_capacity = 0
	target.register_dogmos_air()
	target.sync_dogmos_adjacency()

	var/list/heat_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(length(heat_snapshot) != 5)
		return Fail("Dogmos returned a malformed turf heat snapshot with [length(heat_snapshot)] fields.", __FILE__, __LINE__)
	if(heat_snapshot[1] != FALSE)
		return Fail("Dogmos retained a heat-graph node for a turf with zero conductivity and heat capacity.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_turf_heat_absence/Destroy()
	if(target)
		target.thermal_conductivity = original_thermal_conductivity
		target.heat_capacity = original_heat_capacity
		target.register_dogmos_air()
	return ..()

/** Verifies startup turf mutations remain deferred until the bounded batch flush. */
/datum/unit_test/dogmos_service_turf_batching
	/// Turf restored after the assertion run.
	var/turf/target
	/// Adjacent turf restored after the assertion run.
	var/turf/neighbor
	/// Original thermal conductivity restored during teardown.
	var/original_thermal_conductivity
	/// Original heat capacity restored during teardown.
	var/original_heat_capacity
	/// Original adjacent-turf atmosphere initialization state restored during teardown.
	var/original_neighbor_init_air

/datum/unit_test/dogmos_service_turf_batching/Run()
	if(!SSdogmos.service_ready)
		return Fail("dogmosd did not pass startup identity and health checks.", __FILE__, __LINE__)
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to 20)
		if(!SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the turf batching test.", __FILE__, __LINE__)
	target = run_loc_floor_bottom_left
	original_thermal_conductivity = target.thermal_conductivity
	original_heat_capacity = target.heat_capacity
	target.thermal_conductivity = 0
	target.heat_capacity = 0
	target.register_dogmos_air()

	SSdogmos.begin_turf_registration_batch()
	target.thermal_conductivity = original_thermal_conductivity
	target.heat_capacity = original_heat_capacity
	target.register_dogmos_air()
	var/list/deferred_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(deferred_snapshot[1] != FALSE)
		return Fail("Dogmos applied a startup turf mutation before its explicit batch flush.", __FILE__, __LINE__)
	SSdogmos.finish_turf_registration_batch()
	var/list/flushed_snapshot = dogmos_turf_heat_snapshot(list(target.dogmos_service_slot(), target.dogmos_service_generation()))
	if(flushed_snapshot[1] != TRUE)
		return Fail("Dogmos did not apply a startup turf mutation during its explicit batch flush.", __FILE__, __LINE__)

	neighbor = get_step(target, EAST)
	if(!isopenturf(neighbor) || !neighbor.init_air)
		return Fail("The Dogmos batching test requires an atmosphere-enabled open turf to the east.", __FILE__, __LINE__)
	original_neighbor_init_air = neighbor.init_air
	neighbor.init_air = FALSE
	neighbor.register_dogmos_air(remove_uninitialized = TRUE)
	neighbor.init_air = original_neighbor_init_air
	target.sync_dogmos_adjacency()
	var/list/neighbor_snapshot = dogmos_turf_heat_snapshot(list(neighbor.dogmos_service_slot(), neighbor.dogmos_service_generation()))
	if(neighbor_snapshot[1] != TRUE)
		return Fail("Dogmos adjacency synchronization did not re-register an atmosphere-enabled endpoint.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_turf_batching/Destroy()
	if(SSdogmos.turf_registration_batching)
		SSdogmos.finish_turf_registration_batch()
	if(target)
		target.thermal_conductivity = original_thermal_conductivity
		target.heat_capacity = original_heat_capacity
		target.register_dogmos_air()
	if(neighbor)
		neighbor.init_air = original_neighbor_init_air
		neighbor.register_dogmos_air()
	return ..()

/** Verifies startup adjacency rebuilds do not re-register current turfs. */
/datum/unit_test/dogmos_service_startup_registration_deduplication

/datum/unit_test/dogmos_service_startup_registration_deduplication/Run()
	var/turf/target = run_loc_floor_bottom_left
	var/turf/neighbor = get_step(target, EAST)
	if(!target.init_air || isnull(target.dogmos_registration_generation) || !neighbor?.init_air || isnull(neighbor.dogmos_registration_generation))
		return Fail("The Dogmos startup registration test requires two registered atmosphere turfs.", __FILE__, __LINE__)

	var/original_batching = SSdogmos.turf_registration_batching
	var/list/original_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle
	var/list/original_adjacency = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_adjacency_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat = SSdogmos.dogmos_pending_turf_heat
	var/list/original_heat_adjacency = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_adjacency_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/list/original_retry = SSdogmos.dogmos_pending_adjacency_retry
	SSdogmos.turf_registration_batching = TRUE
	SSdogmos.dogmos_pending_turf_lifecycle = list()
	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.dogmos_pending_turf_heat = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.dogmos_pending_adjacency_retry = list()
	var/target_key = "[target.dogmos_service_slot()]"
	var/neighbor_key = "[neighbor.dogmos_service_slot()]"
	SSdogmos.dogmos_pending_turf_lifecycle[target_key] = list("target sentinel")
	SSdogmos.dogmos_pending_turf_lifecycle[neighbor_key] = list("neighbor sentinel")

	target.sync_dogmos_adjacency()

	var/list/target_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[target_key]
	var/list/neighbor_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[neighbor_key]
	var/failure_message
	if(target_lifecycle?[1] != "target sentinel")
		failure_message = "Dogmos re-registered the current turf during startup adjacency synchronization."
	else if(neighbor_lifecycle?[1] != "neighbor sentinel")
		failure_message = "Dogmos re-registered a current neighbor during startup adjacency synchronization."
	var/original_registered_mixture_slot = target.dogmos_registered_mixture_slot
	var/original_registered_mixture_generation = target.dogmos_registered_mixture_generation
	if(!failure_message)
		target.dogmos_registered_mixture_slot = null
		target.dogmos_registered_mixture_generation = null
		SSdogmos.dogmos_pending_turf_lifecycle[target_key] = list("stale target sentinel")
		target.sync_dogmos_adjacency()
		target_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[target_key]
		if(target_lifecycle?[1] == "stale target sentinel")
			failure_message = "Dogmos did not refresh a startup turf whose gas mixture became available."
	target.dogmos_registered_mixture_slot = original_registered_mixture_slot
	target.dogmos_registered_mixture_generation = original_registered_mixture_generation

	SSdogmos.turf_registration_batching = original_batching
	SSdogmos.dogmos_pending_turf_lifecycle = original_lifecycle
	SSdogmos.dogmos_pending_turf_adjacency = original_adjacency
	SSdogmos.dogmos_pending_turf_adjacency_index = original_adjacency_index
	SSdogmos.dogmos_pending_turf_heat = original_heat
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_adjacency
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_adjacency_index
	SSdogmos.dogmos_pending_adjacency_retry = original_retry
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies callback turf resolution rejects stale generations without invoking gameplay handlers. */
/datum/unit_test/dogmos_service_callback_identity

/datum/unit_test/dogmos_service_callback_identity/Run()
	var/turf/target = run_loc_floor_bottom_left
	var/original_generation = target.dogmos_registration_generation
	var/list/original_sequence = SSdogmos.dogmos_next_callback_sequence.Copy()
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	target.dogmos_registration_generation = 41
	var/slot = target.dogmos_service_slot()
	if(SSdogmos.resolve_turf(slot, 41) != target)
		target.dogmos_registration_generation = original_generation
		return Fail("Dogmos did not resolve a current turf identity.", __FILE__, __LINE__)
	if(!isnull(SSdogmos.resolve_turf(slot, 42)))
		target.dogmos_registration_generation = original_generation
		return Fail("Dogmos accepted a stale turf generation.", __FILE__, __LINE__)

	SSdogmos.dogmos_next_callback_sequence = list(1, 0, 0, 0)
	var/list/stale_callback = new/list(48)
	stale_callback[13] = 1
	stale_callback[14] = 0
	stale_callback[15] = 0
	stale_callback[16] = 0
	stale_callback[21] = 1
	stale_callback[22] = 4
	stale_callback[24] = slot % 65536
	stale_callback[25] = floor(slot / 65536)
	stale_callback[26] = 42
	SSdogmos.dispatch_general_callback(stale_callback, 13)
	if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
		target.dogmos_registration_generation = original_generation
		SSdogmos.dogmos_next_callback_sequence = original_sequence
		return Fail("Dogmos did not count a rejected stale callback.", __FILE__, __LINE__)

	target.dogmos_registration_generation = original_generation
	SSdogmos.dogmos_next_callback_sequence = original_sequence
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks

/** Verifies callback sequence mismatches are diagnosed without advancing the expected sequence. */
/datum/unit_test/dogmos_service_callback_sequence_mismatch

/datum/unit_test/dogmos_service_callback_sequence_mismatch/Run()
	if(!hascall(SSdogmos, "callback_sequence_error"))
		return Fail("Dogmos has no non-mutating callback sequence validator.", __FILE__, __LINE__)

	var/list/expected_sequence = list(1, 0, 0, 0)
	var/list/callback_batch = new/list(48)
	var/offset = 13
	callback_batch[offset] = 2
	var/error_message = call(SSdogmos, "callback_sequence_error")(callback_batch, offset, expected_sequence)
	if(error_message != "Dogmos callback sequence mismatch at offset 13: expected 1:0:0:0, received 2:0:0:0.")
		return Fail("Dogmos returned an incomplete callback sequence diagnostic: [error_message]", __FILE__, __LINE__)
	if(expected_sequence[1] != 1 || expected_sequence[2] || expected_sequence[3] || expected_sequence[4])
		return Fail("Dogmos mutated the expected sequence while diagnosing a mismatch.", __FILE__, __LINE__)

#define DOGMOS_TEST_CALLBACK_HEADER_FIELDS 12
#define DOGMOS_TEST_CALLBACK_EVENT_FIELDS 36
#define DOGMOS_TEST_CALLBACK_EVENT_START 13
#define DOGMOS_TEST_CALLBACK_SCOPE_GENERAL 1
#define DOGMOS_TEST_CALLBACK_SCOPE_FIELD 8
#define DOGMOS_TEST_CALLBACK_KIND_FIELD 9
#define DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD 11
#define DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD 13
#define DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST 4

/** Verifies exhausted SSair budget prevents the first retained callback from dispatching. */
/datum/unit_test/dogmos_service_callback_budget

/datum/unit_test/dogmos_service_callback_budget/Run()
	var/list/original_sequence = SSdogmos.dogmos_next_callback_sequence
	var/list/original_pending_batch = SSdogmos.dogmos_pending_callback_batch
	var/original_pending_index = SSdogmos.dogmos_pending_callback_index
	var/original_pending_count = SSdogmos.dogmos_pending_callback_count
	var/original_pending_service_callbacks = SSdogmos.dogmos_pending_service_callbacks
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	var/list/test_sequence = list(1, 0, 0, 0)
	var/list/callback_batch = new/list(DOGMOS_TEST_CALLBACK_HEADER_FIELDS + DOGMOS_TEST_CALLBACK_EVENT_FIELDS)
	var/offset = DOGMOS_TEST_CALLBACK_EVENT_START
	for(var/word_index in 1 to 4)
		callback_batch[offset + word_index - 1] = test_sequence[word_index]
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SCOPE_FIELD] = DOGMOS_TEST_CALLBACK_SCOPE_GENERAL
	callback_batch[offset + DOGMOS_TEST_CALLBACK_KIND_FIELD] = DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD + 1] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD] = 0
	callback_batch[offset + DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD + 1] = 0

	SSdogmos.dogmos_next_callback_sequence = test_sequence
	SSdogmos.dogmos_pending_callback_batch = callback_batch
	SSdogmos.dogmos_pending_callback_index = 0
	SSdogmos.dogmos_pending_callback_count = 1
	SSdogmos.dogmos_pending_service_callbacks = 0
	process_atmos_callbacks(0)

	var/failure_message
	if(SSdogmos.dogmos_pending_callback_batch != callback_batch)
		failure_message = "Dogmos discarded a retained callback batch without callback budget."
	else if(SSdogmos.dogmos_pending_callback_index != 0)
		failure_message = "Dogmos advanced the retained callback cursor without callback budget."
	else if(SSdogmos.dogmos_next_callback_sequence[1] != 1)
		failure_message = "Dogmos consumed a callback sequence without callback budget."
	else if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks)
		failure_message = "Dogmos dispatched a stale callback without callback budget."
	else
		process_atmos_callbacks(100)
		if(SSdogmos.dogmos_pending_callback_batch)
			failure_message = "Dogmos did not clear a retained callback batch after dispatch."
		else if(SSdogmos.dogmos_next_callback_sequence[1] != 2)
			failure_message = "Dogmos did not consume the retained callback in sequence."
		else if(SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
			failure_message = "Dogmos did not dispatch the retained stale callback with positive budget."

	SSdogmos.dogmos_next_callback_sequence = original_sequence
	SSdogmos.dogmos_pending_callback_batch = original_pending_batch
	SSdogmos.dogmos_pending_callback_index = original_pending_index
	SSdogmos.dogmos_pending_callback_count = original_pending_count
	SSdogmos.dogmos_pending_service_callbacks = original_pending_service_callbacks
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_TEST_CALLBACK_HEADER_FIELDS
#undef DOGMOS_TEST_CALLBACK_EVENT_FIELDS
#undef DOGMOS_TEST_CALLBACK_EVENT_START
#undef DOGMOS_TEST_CALLBACK_SCOPE_GENERAL
#undef DOGMOS_TEST_CALLBACK_SCOPE_FIELD
#undef DOGMOS_TEST_CALLBACK_KIND_FIELD
#undef DOGMOS_TEST_CALLBACK_SUBJECT_SLOT_FIELD
#undef DOGMOS_TEST_CALLBACK_SUBJECT_GENERATION_FIELD
#undef DOGMOS_TEST_CALLBACK_TURF_DESTRUCTION_REQUEST

#define DOGMOS_TEST_REACTION_EVENT_OFFSET 13
#define DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD 11
#define DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD 13
#define DOGMOS_TEST_CALLBACK_REACTION_FINISHED 2

/** Verifies general reaction callbacks reject stale mixture generations at the identity boundary. */
/datum/unit_test/dogmos_service_general_reaction_subject

/datum/unit_test/dogmos_service_general_reaction_subject/Run()
	var/turf/open/target = run_loc_floor_bottom_left
	var/datum/gas_mixture/mixture = target.air
	var/list/callback = new/list(48)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD] = mixture.dogmos_slot % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD + 1] = floor(mixture.dogmos_slot / 65536)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD] = mixture.dogmos_generation % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD + 1] = floor(mixture.dogmos_generation / 65536)
	var/target_slot = target.dogmos_service_slot()
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + 15] = target_slot % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + 16] = floor(target_slot / 65536)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + 17] = target.dogmos_registration_generation % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + 18] = floor(target.dogmos_registration_generation / 65536)
	var/list/live_subject = SSdogmos.decode_general_reaction_subject(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET)
	var/failure_message
	if(live_subject[1] != mixture)
		failure_message = "Dogmos rejected a live general-reaction mixture identity."
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD]++
	var/list/stale_subject = SSdogmos.decode_general_reaction_subject(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET)
	if(!failure_message && stale_subject[1])
		failure_message = "Dogmos accepted a stale general-reaction mixture generation."
	var/original_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	var/stale_dispatch_result = SSdogmos.dispatch_general_reaction_callback(callback, DOGMOS_TEST_REACTION_EVENT_OFFSET, DOGMOS_TEST_CALLBACK_REACTION_FINISHED)
	if(!failure_message && (!isnum(stale_dispatch_result) || stale_dispatch_result != FALSE))
		failure_message = "Dogmos did not explicitly discard a stale finished-reaction callback."
	if(!failure_message && SSdogmos.dogmos_stale_callback_count != original_stale_callbacks + 1)
		failure_message = "Dogmos did not count a discarded stale finished-reaction callback."
	SSdogmos.dogmos_stale_callback_count = original_stale_callbacks
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_TEST_REACTION_EVENT_OFFSET
#undef DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD
#undef DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD
#undef DOGMOS_TEST_CALLBACK_REACTION_FINISHED

/** Verifies runtime topology remains deferred for the full committed-frontier cycle. */
/datum/unit_test/dogmos_service_topology_stage_barrier

/datum/unit_test/dogmos_service_topology_stage_barrier/Run()
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/deferrals_before = SSdogmos.dogmos_runtime_topology_deferrals
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	var/flushed = SSdogmos.flush_turf_registration_batch()
	var/deferrals_after = SSdogmos.dogmos_runtime_topology_deferrals
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.dogmos_runtime_topology_deferrals = deferrals_before
	if(flushed)
		return Fail("Dogmos flushed runtime topology while a committed frontier remained pending.", __FILE__, __LINE__)
	if(deferrals_after != deferrals_before + 1)
		return Fail("Dogmos did not count a committed-frontier topology deferral.", __FILE__, __LINE__)

/** Verifies mixture slots remain retired until the committed-frontier topology barrier. */
/datum/unit_test/dogmos_service_mixture_retirement_stage_barrier
	/// Mixture retired while the committed frontier is pending.
	var/datum/gas_mixture/retired_mixture
	/// Mixture used to detect premature slot reuse.
	var/datum/gas_mixture/replacement_mixture

/datum/unit_test/dogmos_service_mixture_retirement_stage_barrier/Run()
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the mixture retirement test.", __FILE__, __LINE__)

	retired_mixture = new(CELL_VOLUME)
	var/retired_slot = retired_mixture.dogmos_slot
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	retired_mixture.__gasmixture_unregister()
	replacement_mixture = new(CELL_VOLUME)
	var/reused_pending_slot = replacement_mixture.dogmos_slot == retired_slot
	SSair.dogmos_pending_frontier_epoch = null
	SSdogmos.flush_turf_registration_batch()
	var/released_at_barrier = SSdogmos.dogmos_free_mixture_slots.Find(retired_slot)
	if(reused_pending_slot)
		return Fail("Dogmos reused a retired mixture slot while a committed frontier remained pending.", __FILE__, __LINE__)
	if(!released_at_barrier)
		return Fail("Dogmos did not release a retired mixture slot at the committed-frontier topology barrier.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_mixture_retirement_stage_barrier/Destroy()
	SSair.dogmos_pending_frontier_epoch = null
	SSdogmos.flush_turf_registration_batch()
	QDEL_NULL(retired_mixture)
	QDEL_NULL(replacement_mixture)
	return ..()

/** Verifies frontier identity includes the turf generation, not only the DM turf reference. */
/datum/unit_test/dogmos_service_frontier_generation_identity

/datum/unit_test/dogmos_service_frontier_generation_identity/Run()
	var/turf/open/target = run_loc_floor_bottom_left
	if(!istype(target) || isnull(target.dogmos_registration_generation))
		return Fail("The Dogmos frontier identity test requires a registered open turf.", __FILE__, __LINE__)
	var/list/current_pair = list(target.dogmos_service_slot(), target.dogmos_service_generation())
	if(!SSair.dogmos_frontier_pair_is_current(target, current_pair))
		return Fail("Dogmos rejected the turf's current frontier identity.", __FILE__, __LINE__)
	var/list/stale_pair = list(current_pair[1], current_pair[2] + 1)
	if(SSair.dogmos_frontier_pair_is_current(target, stale_pair))
		return Fail("Dogmos treated a mismatched turf generation as a current frontier identity.", __FILE__, __LINE__)

/** Verifies a rejected incremental frontier chunk cannot publish its candidate epoch. */
/datum/unit_test/dogmos_service_frontier_rejection_preserves_epoch

/datum/unit_test/dogmos_service_frontier_rejection_preserves_epoch/Run()
	var/list/original_epoch = SSair.dogmos_frontier_epoch
	var/list/start_epoch = list(41, 0, 0, 0)
	SSair.dogmos_frontier_epoch = start_epoch.Copy()
	var/accepted = SSair.dogmos_frontier_send_chunks(
		/proc/dogmos_test_reject_frontier_chunk,
		list(list(1, 1)),
		"test rejection",
	)
	var/epoch_changed = !SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, start_epoch)
	SSair.dogmos_frontier_epoch = original_epoch
	if(accepted)
		return Fail("Dogmos accepted a malformed incremental frontier response.", __FILE__, __LINE__)
	if(epoch_changed)
		return Fail("Dogmos published a frontier epoch before the service accepted its chunk.", __FILE__, __LINE__)

/** Verifies frontier changes wait without publication while an older stage remains resumable. */
/datum/unit_test/dogmos_service_frontier_mutation_waits_for_pending_stage

/datum/unit_test/dogmos_service_frontier_mutation_waits_for_pending_stage/Run()
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch)
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the pending-stage frontier test.", __FILE__, __LINE__)

	var/turf/open/target = run_loc_floor_bottom_left
	var/was_active = SSair.active_turfs.Find(target)
	var/list/original_pair = SSair.dogmos_committed_frontier[target]
	var/original_committed_count = length(SSair.dogmos_committed_frontier)
	var/list/original_epoch = SSair.dogmos_frontier_epoch.Copy()
	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	if(original_pair)
		SSair.active_turfs -= target
	else
		SSair.active_turfs |= target
	SSair.dogmos_pending_stage = DOGMOS_TEST_STAGE_EQUALIZE
	SSair.dogmos_pending_frontier_epoch = original_epoch.Copy()
	var/synced = SSair.sync_dogmos_frontier()
	var/epoch_changed = !SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, original_epoch)
	var/frontier_changed = length(SSair.dogmos_committed_frontier) != original_committed_count || SSair.dogmos_committed_frontier[target] != original_pair
	var/pending_changed = SSair.dogmos_pending_stage != DOGMOS_TEST_STAGE_EQUALIZE || !SSdogmos.equal_u64_words(SSair.dogmos_pending_frontier_epoch, original_epoch)
	if(was_active)
		SSair.active_turfs |= target
	else
		SSair.active_turfs -= target
	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	if(!synced)
		return Fail("Dogmos rejected a deferred frontier mutation while an older stage was pending.", __FILE__, __LINE__)
	if(epoch_changed || frontier_changed || pending_changed)
		return Fail("Dogmos published or changed frontier state while an older stage was pending.", __FILE__, __LINE__)

/** Verifies a queued turf heat write is readable before its deferred service flush. */
/datum/unit_test/dogmos_service_pending_turf_heat_read_after_write

/datum/unit_test/dogmos_service_pending_turf_heat_read_after_write/Run()
	var/turf/open/target = run_loc_floor_bottom_left
	var/slot = target.dogmos_service_slot()
	var/generation = target.dogmos_service_generation()
	var/slot_key = "[slot]"
	var/list/original_pending_heat = SSdogmos.dogmos_pending_turf_heat[slot_key]
	SSdogmos.dogmos_pending_turf_heat[slot_key] = list(slot, generation, TRUE, 777, target.thermal_conductivity, target.heat_capacity, FALSE)
	var/observed_temperature = target.return_temperature()
	if(original_pending_heat)
		SSdogmos.dogmos_pending_turf_heat[slot_key] = original_pending_heat
	else
		SSdogmos.dogmos_pending_turf_heat.Remove(slot_key)
	if(observed_temperature != 777)
		return Fail("Dogmos returned [observed_temperature]K instead of the queued 777K turf heat write.", __FILE__, __LINE__)

/** Verifies an explicit breath-sized removal preserves the requested amount. */
/datum/unit_test/dogmos_service_breath_sized_removal

/datum/unit_test/dogmos_service_breath_sized_removal/Run()
	var/obj/item/tank/internals/emergency_oxygen/tank = allocate(/obj/item/tank/internals/emergency_oxygen)
	var/source_moles = tank.air_contents.total_moles()
	var/source_pressure = tank.air_contents.return_pressure()
	var/source_temperature = tank.air_contents.return_temperature()
	var/requested_moles = tank.distribute_pressure * BREATH_VOLUME / (R_IDEAL_GAS_EQUATION * tank.air_contents.return_temperature())
	var/datum/gas_mixture/removed = tank.remove_air_volume(BREATH_VOLUME)
	var/observed_moles = removed?.get_moles(/datum/gas/oxygen)
	if(abs(observed_moles - QUANTIZE(requested_moles)) > MOLAR_ACCURACY)
		return Fail("Dogmos removed [observed_moles] mol instead of the requested [requested_moles] mol breath from [source_moles] mol at [source_pressure] kPa and [source_temperature]K.", __FILE__, __LINE__)

/** Verifies a stage request defers while another service stage remains pending. */
/datum/unit_test/dogmos_service_foreign_pending_stage_defers

/datum/unit_test/dogmos_service_foreign_pending_stage_defers/Run()
	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/list/sentinel_frontier = list(41, 0, 0, 0)
	SSair.dogmos_pending_stage = DOGMOS_TEST_STAGE_EXCITED_GROUPS
	SSair.dogmos_pending_frontier_epoch = sentinel_frontier.Copy()
	var/deferred = SSair.dogmos_run_stage(DOGMOS_TEST_STAGE_TURF_HEAT, 1)
	var/stage_changed = SSair.dogmos_pending_stage != DOGMOS_TEST_STAGE_EXCITED_GROUPS
	var/frontier_changed = !SSdogmos.equal_u64_words(SSair.dogmos_pending_frontier_epoch, sentinel_frontier)
	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	if(!deferred || stage_changed || frontier_changed)
		return Fail("Dogmos did not defer a foreign stage without changing the active stage identity.", __FILE__, __LINE__)

/** Verifies frontier preparation repairs an active turf whose normal registration was missed. */
/datum/unit_test/dogmos_service_frontier_registration_catchup

/datum/unit_test/dogmos_service_frontier_registration_catchup/Run()
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the frontier registration catch-up test.", __FILE__, __LINE__)

	var/turf/open/target = run_loc_floor_bottom_left
	if(!istype(target) || !target.air)
		return Fail("The Dogmos frontier registration catch-up test requires an atmosphere-enabled open turf.", __FILE__, __LINE__)
	var/list/original_epoch = SSair.dogmos_frontier_epoch.Copy()
	var/list/original_committed_frontier = SSair.dogmos_committed_frontier
	target.dogmos_registration_generation = null
	target.dogmos_registered_mixture_slot = null
	target.dogmos_registered_mixture_generation = null
	var/list/prepared = SSair.dogmos_prepare_frontier_pairs(list(target))
	var/list/pair = prepared?[target]
	if(!SSair.dogmos_frontier_pair_is_valid(pair))
		return Fail("Dogmos did not repair the active turf's missing service generation before frontier publication.", __FILE__, __LINE__)
	if(pair[2] != target.dogmos_registration_generation || !target.dogmos_air_registration_is_current())
		return Fail("Dogmos prepared a frontier pair that did not match the repaired turf registration.", __FILE__, __LINE__)
	if(!SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, original_epoch) || SSair.dogmos_committed_frontier != original_committed_frontier)
		return Fail("Dogmos published frontier state during registration catch-up.", __FILE__, __LINE__)

/** Verifies a latched service failure stops stage work without another FFI attempt. */
/datum/unit_test/dogmos_service_failure_latch_stops_stage

/datum/unit_test/dogmos_service_failure_latch_stops_stage/Run()
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/turf/open/target = run_loc_floor_bottom_left
	var/datum/gas_mixture/mixture = target.air
	var/mixture_slot = mixture.dogmos_slot
	var/mixture_generation = mixture.dogmos_generation
	var/mixture_slot_count = length(SSdogmos.dogmos_mixture_slots)
	var/turf_key = "[target.dogmos_service_slot()]"
	var/list/original_turf_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle[turf_key]
	SSdogmos.service_ready = FALSE
	SSdogmos.service_failure_latched = TRUE
	var/stage_stopped = SSair.dogmos_run_stage(DOGMOS_TEST_STAGE_EQUALIZE, 1)
	var/list/failed_response = SSdogmos.mixture_command(list(), DOGMOS_TEST_RESPONSE_APPLIED)
	SSdogmos.evict_mixture_snapshot_cache(mixture_slot, mixture_generation)
	var/list/failed_gases = mixture.__get_gases()
	SSdogmos.register_mixture(mixture)
	target.update_air_ref(DOGMOS_SIMULATION_ALL)
	var/stage_changed = SSair.dogmos_pending_stage != original_pending_stage || SSair.dogmos_pending_frontier_epoch != original_pending_frontier
	var/mixture_changed = mixture.dogmos_slot != mixture_slot || mixture.dogmos_generation != mixture_generation || length(SSdogmos.dogmos_mixture_slots) != mixture_slot_count
	var/turf_changed = SSdogmos.dogmos_pending_turf_lifecycle[turf_key] != original_turf_lifecycle
	SSdogmos.service_ready = original_service_ready
	SSdogmos.service_failure_latched = original_failure_latched
	if(!stage_stopped)
		return Fail("Dogmos reported a failed service stage as complete.", __FILE__, __LINE__)
	if(stage_changed)
		return Fail("Dogmos mutated stage state after the service failure latch was set.", __FILE__, __LINE__)
	if(!islist(failed_response) || length(failed_response) != 4 || failed_response[1] != DOGMOS_TEST_RESPONSE_APPLIED)
		return Fail("Dogmos returned a malformed inert mixture response after the service failure latch was set.", __FILE__, __LINE__)
	if(!islist(failed_gases) || length(failed_gases))
		return Fail("Dogmos failed gas enumeration did not return an empty list without a runtime.", __FILE__, __LINE__)
	if(mixture_changed)
		return Fail("Dogmos mutated mixture registration after the service failure latch was set.", __FILE__, __LINE__)
	if(turf_changed)
		return Fail("Dogmos queued a turf lifecycle mutation after the service failure latch was set.", __FILE__, __LINE__)

/** Late map-loading producers must not submit native work after intentional shutdown begins. */
/datum/unit_test/dogmos_service_shutdown_stops_producers/Run()
	var/original_service_ready = SSdogmos.service_ready
	var/original_shutdown_requested = SSdogmos.service_shutdown_requested
	var/original_failure_latched = SSdogmos.service_failure_latched
	var/slot_count = length(SSdogmos.dogmos_mixture_slots)
	var/turf/open/target = run_loc_floor_bottom_left
	var/datum/gas_mixture/source = target.air
	SSdogmos.begin_service_shutdown()
	var/datum/gas_mixture/late_copy = source.copy()
	var/list/gases = late_copy.__get_gases()
	var/stage_stopped = SSair.dogmos_run_stage(DOGMOS_TEST_STAGE_EQUALIZE, 1)
	target.update_air_ref(DOGMOS_SIMULATION_ALL)
	var/registration_blocked = !late_copy.dogmos_slot && length(SSdogmos.dogmos_mixture_slots) == slot_count
	var/admission_closed = SSdogmos.service_shutdown_requested && !SSdogmos.service_ready
	var/failure_unchanged = SSdogmos.service_failure_latched == original_failure_latched
	SSdogmos.service_ready = original_service_ready
	SSdogmos.service_shutdown_requested = original_shutdown_requested
	SSdogmos.service_failure_latched = original_failure_latched
	if(!admission_closed || !registration_blocked || !stage_stopped || !failure_unchanged)
		return Fail("Intentional shutdown did not close native admission independently of service failure.", __FILE__, __LINE__)
	if(!islist(gases) || length(gases))
		return Fail("A late shutdown producer did not receive an inert gas snapshot.", __FILE__, __LINE__)

/** Verifies failure blocks queued topology before any lifecycle or adjacency FFI call. */
/datum/unit_test/dogmos_service_failure_latch_stops_topology

/datum/unit_test/dogmos_service_failure_latch_stops_topology/Run()
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/list/queue_names = list("dogmos_pending_mixture_unregistrations", "dogmos_pending_turf_lifecycle", "dogmos_pending_turf_heat", "dogmos_pending_turf_adjacency", "dogmos_pending_turf_heat_adjacency", "dogmos_pending_adjacency_retry")
	var/list/saved_queues = list()
	for(var/queue_name in queue_names)
		saved_queues[queue_name] = SSdogmos.vars[queue_name]
		SSdogmos.vars[queue_name] = list()
	// An invalid sentinel must never reach dogmosd after the failure latch is set.
	var/list/sentinel = list(0, 0, 0, 0, TRUE)
	SSdogmos.dogmos_pending_turf_adjacency["failed-service-sentinel"] = sentinel
	SSdogmos.service_ready = FALSE
	SSdogmos.service_failure_latched = TRUE
	SSair.dogmos_pending_frontier_epoch = null
	var/flushed = SSdogmos.flush_turf_registration_batch()
	var/sentinel_preserved = SSdogmos.dogmos_pending_turf_adjacency["failed-service-sentinel"] == sentinel
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.service_ready = original_service_ready
	SSdogmos.service_failure_latched = original_failure_latched
	for(var/queue_name in queue_names)
		SSdogmos.vars[queue_name] = saved_queues[queue_name]
	if(flushed || !sentinel_preserved)
		return Fail("Dogmos consumed pending topology after the service failure latch was set.", __FILE__, __LINE__)

/** Verifies rejected mixture registration fails closed without publishing an invalid identity. */
/datum/unit_test/dogmos_service_rejected_mixture_registration_fails_closed

/datum/unit_test/dogmos_service_rejected_mixture_registration_fails_closed/Run()
	var/list/original_walk_state = list()
	for(var/field in list("dogmos_active_walk_complete", "active_turfs_walk_cursor", "dogmos_visual_refresh_cursor", "dogmos_visual_refresh_batch"))
		original_walk_state[field] = SSair.vars[field]
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	var/original_can_fire = SSair.can_fire
	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_remaining_estimate = SSair.dogmos_stage_remaining_estimate
	var/original_active_complete = SSair.dogmos_active_turf_stages_complete
	var/original_equalize_complete = SSair.dogmos_equalize_stage_complete
	var/original_fdm_steps = SSair.dogmos_fdm_steps_completed
	var/turf/open/target = run_loc_floor_bottom_left
	var/datum/gas_mixture/mixture = target.air
	var/original_slot = mixture.dogmos_slot
	var/original_generation = mixture.dogmos_generation
	var/original_pointer = mixture._extools_pointer_gasmixture
	var/accepted = SSdogmos.finalize_mixture_registration(
		mixture,
		length(SSdogmos.dogmos_mixture_slots) + 1,
		1,
		null,
		FALSE,
	)
	var/identity_changed = mixture.dogmos_slot != original_slot || mixture.dogmos_generation != original_generation || mixture._extools_pointer_gasmixture != original_pointer
	var/failed_closed = !SSair.can_fire && !SSdogmos.service_ready && SSdogmos.service_failure_latched
	SSdogmos.service_ready = original_service_ready
	SSdogmos.service_failure_latched = original_failure_latched
	SSair.can_fire = original_can_fire
	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSair.dogmos_stage_remaining_estimate = original_remaining_estimate
	SSair.dogmos_active_turf_stages_complete = original_active_complete
	SSair.dogmos_equalize_stage_complete = original_equalize_complete
	SSair.dogmos_fdm_steps_completed = original_fdm_steps
	for(var/field in original_walk_state)
		SSair.vars[field] = original_walk_state[field]
	if(accepted)
		return Fail("Dogmos accepted a rejected mixture lifecycle response.", __FILE__, __LINE__)
	if(identity_changed)
		return Fail("Dogmos published a mixture identity after the service rejected it.", __FILE__, __LINE__)
	if(!failed_closed)
		return Fail("Dogmos did not fail closed after the service rejected a mixture registration.", __FILE__, __LINE__)

/** Verifies an exhausted MC budget returns control without sleeping inside SSair. */
/datum/unit_test/dogmos_service_stage_budget_progress

/datum/unit_test/dogmos_service_stage_budget_progress/Run()
	var/original_work_limit = SSair.dogmos_stage_work_limit
	SSair.dogmos_stage_work_limit = 128
	var/zero_budget_limit = SSair.dogmos_work_limit_for_budget(0)
	var/overrun_budget_limit = SSair.dogmos_work_limit_for_budget(-1)
	SSair.dogmos_stage_work_limit = original_work_limit
	var/defer_start = world.time
	var/deferred = SSair.dogmos_defer_stage_for_budget()

	if(zero_budget_limit)
		return Fail("Dogmos scheduled service work despite an exhausted MC budget.", __FILE__, __LINE__)
	if(overrun_budget_limit)
		return Fail("Dogmos scheduled service work after an MC overrun.", __FILE__, __LINE__)
	if(!deferred)
		return Fail("Dogmos did not report an exhausted stage as deferred.", __FILE__, __LINE__)
	if(world.time != defer_start)
		return Fail("Dogmos slept inside SSair while deferring an exhausted stage.", __FILE__, __LINE__)

/** Verifies a positive fractional MC allocation can finish bounded native diffusion work. */
/datum/unit_test/dogmos_service_fractional_budget_progress

/datum/unit_test/dogmos_service_fractional_budget_progress/Run()
	if(!SSair.dogmos_work_limit_for_budget(0.25))
		return Fail("Dogmos refuses all native work for a positive 0.25 ms MC allocation.", __FILE__, __LINE__)
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/pair = allocate_turf_pair()
	var/turf/open/hot_turf = pair[1]
	var/turf/open/cold_turf = pair[2]
	hot_turf.air.set_moles(GAS_O2, 100)
	cold_turf.air.set_moles(GAS_O2, 10)
	// The active pair exchanges gas with passive neighbors. The sealed test room,
	// rather than just the active frontier, is the conserved volume.
	var/list/room_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/oxygen_before = 0
	for(var/turf/open/room_turf in room_turfs)
		oxygen_before += room_turf.air.get_moles(GAS_O2)
	var/original_work_limit = SSair.dogmos_stage_work_limit
	SSair.dogmos_stage_work_limit = 1
	var/completed = dogmos_run_fixture_stage(DOGMOS_TEST_STAGE_TURFS, pair, chunk_budget_ms = 0.25)
	SSair.dogmos_stage_work_limit = original_work_limit
	if(!completed)
		return
	var/hot_moles = hot_turf.air.get_moles(GAS_O2)
	var/cold_moles = cold_turf.air.get_moles(GAS_O2)
	if(hot_moles >= 100 || cold_moles <= 10)
		return Fail("Fractional-budget continuation did not diffuse the fixture's oxygen.", __FILE__, __LINE__)
	var/oxygen_after = 0
	for(var/turf/open/room_turf in room_turfs)
		oxygen_after += room_turf.air.get_moles(GAS_O2)
	if(abs(oxygen_after - oxygen_before) > DOGMOS_PIPELINE_TEST_EPSILON * length(room_turfs))
		return Fail("Fractional-budget continuation changed the sealed room's oxygen from [oxygen_before] to [oxygen_after] moles.", __FILE__, __LINE__)

/** Verifies native continuations consume the caller's remaining budget before yielding. */
/datum/unit_test/dogmos_service_stage_uses_remaining_budget

/datum/unit_test/dogmos_service_stage_uses_remaining_budget/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/pair = allocate_turf_pair()
	var/original_work_limit = SSair.dogmos_stage_work_limit
	SSair.dogmos_stage_work_limit = 1
	dogmos_run_fixture_stage(DOGMOS_TEST_STAGE_TURFS, pair, chunk_budget_ms = 100, require_budget_use = TRUE)
	SSair.dogmos_stage_work_limit = original_work_limit

/** Resuming after an exhausted entry budget must still start the equalizer. */
/datum/unit_test/dogmos_equalize_resume_after_empty_budget

/datum/unit_test/dogmos_equalize_resume_after_empty_budget/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/original_active = SSair.active_turfs
	var/list/original_pressure = SSair.high_pressure_delta
	var/list/original_samples = SSair.dogmos_stage_test_samples
	var/original_state = SSair.state
	var/original_tick_limit = Master.current_ticklimit
	var/list/fixture_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/list/original_pressure_fields = list()
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		original_pressure_fields[fixture_turf] = list(fixture_turf.pressure_difference, fixture_turf.pressure_direction)
	var/completion_field = "dogmos_equalize_stage_complete"
	var/original_completion = (completion_field in SSair.vars) ? SSair.vars[completion_field] : null
	var/failure
	var/restored = FALSE
	try
		SSair.active_turfs = fixture_turfs.Copy()
		SSair.high_pressure_delta = list()
		SSair.dogmos_stage_test_samples = list()
		if(!SSair.sync_dogmos_frontier())
			failure = "The equalizer-resume fixture could not publish its frontier."
		else
			SSair.state = SS_RUNNING
			Master.current_ticklimit = TICK_USAGE
			SSair.process_high_pressure_delta(FALSE)
			if(!isnull(SSair.dogmos_pending_stage))
				failure = "The exhausted initial budget unexpectedly started a native stage."
			else
				for(var/chunk in 1 to 4096)
					SSair.state = SS_RUNNING
					Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
					SSair.process_high_pressure_delta(TRUE)
					if(isnull(SSair.dogmos_pending_stage) || !SSdogmos.service_ready)
						break
				var/list/equalize_calls = SSair.dogmos_stage_test_samples["[DOGMOS_TEST_STAGE_EQUALIZE]"]
				if(!equalize_calls || !equalize_calls[1])
					failure = "The equalizer was skipped when resuming after an exhausted entry budget."
				else if(isnull(SSair.dogmos_pending_stage))
					var/completed_call_count = equalize_calls[1]
					var/turf/open/first_pressure_turf = fixture_turfs[1]
					var/turf/open/second_pressure_turf = fixture_turfs[2]
					first_pressure_turf.pressure_difference = 0
					second_pressure_turf.pressure_difference = 0
					SSair.high_pressure_delta = list(first_pressure_turf, second_pressure_turf)
					SSair.state = SS_RUNNING
					Master.current_ticklimit = TICK_USAGE - 1
					SSair.process_high_pressure_delta(TRUE)
					if(length(SSair.high_pressure_delta) != 1 || SSair.state != SS_PAUSED)
						failure = "The pressure queue fixture did not yield with one entry remaining."
					SSair.state = SS_RUNNING
					Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
					SSair.process_high_pressure_delta(TRUE)
					if(equalize_calls[1] != completed_call_count)
						failure = "A resumed pressure phase repeated an already completed equalizer."
					else if(length(SSair.high_pressure_delta))
						failure = "The resumed pressure phase left its final queue entry undrained."
		if(isnull(SSair.dogmos_pending_stage) && SSdogmos.service_ready && dogmos_drain_fixture_callbacks())
			SSair.active_turfs = original_active
			SSair.dogmos_pending_frontier_epoch = null
			restored = SSair.sync_dogmos_frontier()
			SSair.dogmos_pending_frontier_epoch = null
	catch(var/exception/error)
		failure = "The equalizer-resume fixture raised [error.name]."
	SSair.active_turfs = original_active
	SSair.high_pressure_delta = original_pressure
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		var/list/pressure_fields = original_pressure_fields[fixture_turf]
		fixture_turf.pressure_difference = pressure_fields[1]
		fixture_turf.pressure_direction = pressure_fields[2]
	SSair.dogmos_stage_test_samples = original_samples
	SSair.state = original_state
	Master.current_ticklimit = original_tick_limit
	if(completion_field in SSair.vars)
		SSair.vars[completion_field] = original_completion
	if(!restored)
		return dogmos_abort_fixture("The equalizer-resume fixture did not safely restore its frontier.")
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Matching neighboring gas is not sufficient to retire an unevaluated chemical reaction. */
/datum/unit_test/dogmos_uniform_reaction_before_settlement
	/// Second reactant and temperature select native fire or a continued non-fire DM reaction.
	var/second_gas = /datum/gas/oxygen
	var/seed_temperature = PLASMA_MINIMUM_BURN_TEMPERATURE + 500
	var/product_gas = /datum/gas/carbon_dioxide
	var/reaction_cycles = 1

/** BZ formation remains active across multiple identical-neighbor reaction cycles. */
/datum/unit_test/dogmos_uniform_reaction_before_settlement/slow_reaction
	second_gas = /datum/gas/nitrous_oxide
	seed_temperature = T20C
	product_gas = /datum/gas/bz
	reaction_cycles = 2

/datum/unit_test/dogmos_uniform_reaction_before_settlement/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/fixture_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	if(length(fixture_turfs) != 25)
		return Fail("The uniform reaction fixture needs its sealed 25-turf room.", __FILE__, __LINE__)
	var/list/saved_air = list()
	var/list/saved_turfs = list()
	for(var/field in list("active_turfs", "currentrun", "state", "times_fired", "high_pressure_delta", "active_turfs_walk_cursor", "dogmos_visual_refresh_batch", "dogmos_visual_refresh_cursor", "dogmos_active_walk_complete", "dogmos_active_turf_stages_complete", "dogmos_fdm_steps_completed", "dogmos_reacted_turfs", "dogmos_walk_prefetch_end", "dogmos_visual_prefetch_end", "kennel_reaction_magnitude_threshold", "kennel_fire_group_notable_size"))
		saved_air[field] = SSair.vars[field]
	var/saved_tick_limit = Master.current_ticklimit
	var/datum/gas_mixture/seed = allocate(/datum/gas_mixture, CELL_VOLUME)
	seed.set_moles(/datum/gas/plasma, 50)
	seed.set_moles(second_gas, 200)
	seed.set_temperature(seed_temperature)
	var/datum/gas_mixture/reference = seed.copy()
	allocated += reference
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		if(!fixture_turf.air || fixture_turf.active_hotspot || !fixture_turf.dogmos_air_registration_is_current())
			return Fail("The uniform reaction needs an open fixture without an existing hotspot.", __FILE__, __LINE__)
		for(var/turf/neighbor as anything in fixture_turf.atmos_adjacent_turfs)
			if(!(neighbor in fixture_turfs))
				return Fail("The uniform reaction fixture is not sealed from outside gas.", __FILE__, __LINE__)
			if(!(fixture_turf in neighbor.atmos_adjacent_turfs))
				return Fail("The uniform reaction fixture has asymmetric gas adjacency.", __FILE__, __LINE__)
		var/datum/gas_mixture/saved_mix = fixture_turf.air.copy()
		allocated += saved_mix
		saved_turfs[fixture_turf] = list(saved_mix, fixture_turf.excited, fixture_turf.excited_group, fixture_turf.current_cycle, fixture_turf.archived_cycle, fixture_turf.pressure_difference, fixture_turf.pressure_direction, fixture_turf.air.reaction_results?.Copy(), fixture_turf.kennel_last_reaction_results?.Copy())
	var/failure
	var/restored = FALSE
	try
		// Keep this numerical fixture out of the shared Kennel event/overlay history.
		SSair.kennel_reaction_magnitude_threshold = INFINITY
		SSair.kennel_fire_group_notable_size = INFINITY
		// A turf fire also creates a hotspot whose initialization reacts gas again.
		// Obtain the reference through the same real holder and callback behavior.
		var/turf/open/reference_turf = fixture_turfs[1]
		reference_turf.air.copy_from(seed)
		reference_turf.air.react(reference_turf)
		reference.copy_from(reference_turf.air)
		if(reference.get_moles(product_gas) <= 0)
			failure = "The uniform-reaction reference did not produce its expected gas."
		if(reference_turf.active_hotspot)
			qdel(reference_turf.active_hotspot)
		for(var/turf/open/fixture_turf as anything in fixture_turfs)
			fixture_turf.air.copy_from(seed)
			fixture_turf.air.reaction_results = list()
			fixture_turf.excited = TRUE
			fixture_turf.excited_group = null
			fixture_turf.archived_cycle = SSair.times_fired
		SSair.active_turfs = fixture_turfs.Copy()
		SSair.currentrun = list()
		SSair.high_pressure_delta = list()
		for(var/reaction_cycle in 1 to reaction_cycles)
			if(reaction_cycle > 1)
				// Each fixture phase finished its native cursor and callbacks. Release
				// its frontier token without rewinding the accepted service epoch.
				SSair.dogmos_pending_frontier_epoch = null
				SSair.times_fired++
				reference.react(null)
			for(var/chunk in 1 to 4096)
				SSair.state = SS_RUNNING
				Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
				SSair.process_active_turfs(chunk != 1)
				if(SSair.state == SS_RUNNING || !SSdogmos.service_ready)
					break
			if(SSair.state != SS_RUNNING)
				failure = "The uniform reaction phase did not finish within its bound."
				break
			for(var/turf/open/fixture_turf as anything in fixture_turfs)
				for(var/gas_id in list(/datum/gas/plasma, second_gas, product_gas, /datum/gas/water_vapor))
					if(abs(fixture_turf.air.get_moles(gas_id) - reference.get_moles(gas_id)) > 0.001)
						failure += " Gas [gas_id]: [fixture_turf.air.get_moles(gas_id)] versus [reference.get_moles(gas_id)] in cycle [reaction_cycle]."
				if(abs(fixture_turf.air.return_temperature() - reference.return_temperature()) > 0.1)
					failure += " Temperature [fixture_turf.air.return_temperature()] versus [reference.return_temperature()] in cycle [reaction_cycle]."
				if(reaction_cycle < reaction_cycles && (!fixture_turf.excited || !(fixture_turf in SSair.active_turfs)))
					failure = "A reacting turf was retired before its next chemical evaluation."
		if(isnull(SSair.dogmos_pending_stage) && SSdogmos.service_ready && dogmos_drain_fixture_callbacks())
			for(var/turf/open/fixture_turf as anything in fixture_turfs)
				var/list/restoring_turf_state = saved_turfs[fixture_turf]
				fixture_turf.air.copy_from(restoring_turf_state[1])
				fixture_turf.air.reaction_results = restoring_turf_state[8]
				fixture_turf.kennel_last_reaction_results = restoring_turf_state[9]
				if(fixture_turf.active_hotspot)
					qdel(fixture_turf.active_hotspot)
				fixture_turf.update_visuals()
			SSair.active_turfs = saved_air["active_turfs"]
			SSair.dogmos_pending_frontier_epoch = null
			restored = SSair.sync_dogmos_frontier()
			SSair.dogmos_pending_frontier_epoch = null
	catch(var/exception/error)
		failure = "The uniform-reaction fixture raised [error.name]."
	for(var/field in saved_air)
		SSair.vars[field] = saved_air[field]
	Master.current_ticklimit = saved_tick_limit
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		var/list/turf_state = saved_turfs[fixture_turf]
		fixture_turf.excited = turf_state[2]
		fixture_turf.excited_group = turf_state[3]
		fixture_turf.current_cycle = turf_state[4]
		fixture_turf.archived_cycle = turf_state[5]
		fixture_turf.pressure_difference = turf_state[6]
		fixture_turf.pressure_direction = turf_state[7]
	if(!restored)
		return dogmos_abort_fixture("The uniform-reaction fixture could not safely restore its native frontier.")
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** A recreated subsystem must enter its saved phase even when the scheduler calls fire(FALSE). */
/datum/unit_test/dogmos_ssair_recreated_phase_resume

/datum/unit_test/dogmos_ssair_recreated_phase_resume/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/original_state = SSair.state
	var/original_part = SSair.currentpart
	var/original_cycle = SSair.times_fired
	var/original_tick_limit = Master.current_ticklimit
	var/datum/controller/subsystem/air/recovery_test_copy/phase_probe/probe = new
	var/failure
	try
		SSair.state = SS_PAUSED
		SSair.currentpart = SSAIR_ACTIVETURFS
		SSair.times_fired = 37
		probe.Recover()
		// These queues precede the saved phase in fire(); isolate them from the real world.
		probe.adjacent_rebuild = list()
		probe.rebuild_queue = list()
		probe.expansion_queue = list()
		probe.state = SS_RUNNING
		Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
		probe.fire(FALSE)
		if(probe.entered_phase != SSAIR_ACTIVETURFS || !probe.received_resume || probe.times_fired != 37)
			failure = "A recreated SSair restarted the cycle instead of resuming its saved active phase and cycle id."
		else
			probe.state = SS_RUNNING
			probe.fire(FALSE)
			if(probe.entered_phase != SSAIR_PIPENETS || probe.received_resume)
				failure = "SSair reused its recovery resume override for a later new cycle."
	catch(var/exception/error)
		failure = "The recreated-phase fixture raised [error.name]."
	SSair.state = original_state
	SSair.currentpart = original_part
	SSair.times_fired = original_cycle
	Master.current_ticklimit = original_tick_limit
	qdel(probe)
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Observes scheduler routing without advancing native stages or mutating live queues. */
/datum/controller/subsystem/air/recovery_test_copy/phase_probe
	/// First phase chosen by the real fire() dispatcher.
	var/entered_phase
	/// Whether the dispatcher preserves a recovered continuation.
	var/received_resume

/datum/controller/subsystem/air/recovery_test_copy/phase_probe/process_pipenets(resumed = FALSE)
	entered_phase = SSAIR_PIPENETS
	received_resume = resumed
	pause()

/datum/controller/subsystem/air/recovery_test_copy/phase_probe/process_active_turfs(resumed = FALSE)
	entered_phase = SSAIR_ACTIVETURFS
	received_resume = resumed
	pause()

/** Every initially active turf must receive maintenance before the cycle publishes its frontier. */
/datum/unit_test/dogmos_active_walk_full_cycle
	/// Counts actual turf exposure signals, independently of the traversal cursor.
	var/list/exposures
	/// Force two budget pauses to check that resuming does not refill a shifted window.
	var/yield_count = 0

/datum/unit_test/dogmos_active_walk_full_cycle/proc/count_exposure(turf/source)
	SIGNAL_HANDLER
	exposures[source]++
	if(yield_count < 2)
		yield_count++
		Master.current_ticklimit = TICK_USAGE - 1

/datum/unit_test/dogmos_active_walk_full_cycle/Run()
	var/datum/turf_reservation/fixture = SSmapping.request_turf_block_reservation(11, 11, turf_type_override = /turf/open/floor/plating/airless)
	if(!fixture)
		return Fail("Could not reserve the 121-turf traversal fixture.", __FILE__, __LINE__)
	allocated += fixture
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/fixture_turfs = fixture.reserved_turfs.Copy()
	if(length(fixture_turfs) != 121)
		return Fail("The traversal fixture needs 121 distinct real turfs.", __FILE__, __LINE__)
	var/list/saved_fields = list()
	for(var/field in list("active_turfs", "currentrun", "state", "active_turfs_walk_cursor", "dogmos_visual_refresh_batch", "dogmos_active_walk_complete", "dogmos_visual_refresh_cursor", "dogmos_active_turf_stages_complete", "dogmos_fdm_steps_completed", "high_pressure_delta", "dogmos_reacted_turfs", "dogmos_walk_prefetch_end", "dogmos_visual_prefetch_end"))
		saved_fields[field] = SSair.vars[field]
	var/original_tick_limit = Master.current_ticklimit
	var/list/turf_states = list()
	exposures = list()
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		if(!fixture_turf.air || !fixture_turf.dogmos_air_registration_is_current())
			return Fail("A reserved traversal turf lacks its current native gas registration.", __FILE__, __LINE__)
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		turf_states[fixture_turf] = list(fixture_turf.atmos_adjacent_turfs, fixture_turf.excited, fixture_turf.excited_group, fixture_turf.current_cycle, fixture_turf.archived_cycle)
		fixture_turf.atmos_adjacent_turfs = list()
		fixture_turf.excited = TRUE
		fixture_turf.excited_group = null
		fixture_turf.archived_cycle = SSair.times_fired
		RegisterSignal(fixture_turf, COMSIG_TURF_EXPOSE, PROC_REF(count_exposure))
	var/failure
	var/restored = FALSE
	try
		SSair.active_turfs = fixture_turfs.Copy()
		SSair.currentrun = list()
		SSair.active_turfs_walk_cursor = 0
		SSair.high_pressure_delta = list()
		var/original_frontier_epoch = SSair.dogmos_frontier_epoch.Join(":")
		var/turf/open/prefetch_probe = fixture_turfs[50]
		var/list/retained_probe_snapshot
		for(var/chunk in 1 to 4096)
			SSair.state = SS_RUNNING
			Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
			SSair.process_active_turfs(chunk != 1)
			if(chunk == 1)
				if(SSair.state != SS_PAUSED || length(exposures) != 1 || SSair.active_turfs_walk_cursor != 1)
					failure = "The maintenance walk did not retain its position after the first exposure exhausted its budget."
				else if(SSair.dogmos_frontier_epoch.Join(":") != original_frontier_epoch || SSair.dogmos_active_walk_complete)
					failure = "The active frontier was published before the initial maintenance snapshot completed."
				retained_probe_snapshot = SSdogmos.lookup_mixture_snapshot_cache(prefetch_probe.air.dogmos_slot, prefetch_probe.air.dogmos_generation)
				if(!retained_probe_snapshot)
					failure = "The first chunk did not populate the untouched prefetch probe."
			if(chunk == 2 && retained_probe_snapshot != SSdogmos.lookup_mixture_snapshot_cache(prefetch_probe.air.dogmos_slot, prefetch_probe.air.dogmos_generation))
				failure = "Resuming after one exposure fetched a replacement snapshot for the untouched prefetch window."
			if(SSair.state == SS_RUNNING || !SSdogmos.service_ready)
				break
		if(SSair.state != SS_RUNNING)
			failure = "The full active phase did not finish within the fixture bound."
		for(var/turf/open/fixture_turf as anything in fixture_turfs)
			if(exposures[fixture_turf] != 1)
				failure = "A completed active phase exposed only [length(exposures)] of 121 initially active turfs exactly once."
				break
		if(!failure && length(SSair.active_turfs))
			failure = "Settled fixture turfs remained active after the full walk."
		// The current cycle's frontier remains frozen through equalization and heat.
		// All initial entries must have reached its reaction pass before retirement.
		if(!failure && length(SSair.dogmos_committed_frontier) != length(fixture_turfs))
			failure = "An initial fixture turf was retired before native reaction evaluation."
		if(!failure && (length(SSair.dogmos_visual_refresh_batch) || SSair.active_turfs_walk_cursor || SSair.dogmos_visual_refresh_cursor || SSair.dogmos_walk_prefetch_end || SSair.dogmos_visual_prefetch_end))
			failure = "The completed visual pass retained its snapshot or cursors."
		if(isnull(SSair.dogmos_pending_stage) && SSdogmos.service_ready && dogmos_drain_fixture_callbacks())
			SSair.active_turfs = saved_fields["active_turfs"]
			SSair.dogmos_pending_frontier_epoch = null
			restored = SSair.sync_dogmos_frontier()
			SSair.dogmos_pending_frontier_epoch = null
	catch(var/exception/error)
		failure = "The full-walk fixture raised [error.name]."
	for(var/field in saved_fields)
		SSair.vars[field] = saved_fields[field]
	Master.current_ticklimit = original_tick_limit
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		UnregisterSignal(fixture_turf, COMSIG_TURF_EXPOSE)
		var/list/turf_state = turf_states[fixture_turf]
		fixture_turf.atmos_adjacent_turfs = turf_state[1]
		fixture_turf.excited = turf_state[2]
		fixture_turf.excited_group = turf_state[3]
		fixture_turf.current_cycle = turf_state[4]
		fixture_turf.archived_cycle = turf_state[5]
	exposures = null
	if(!restored)
		return dogmos_abort_fixture("The full-walk fixture could not safely restore the native frontier.")
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Keeps the next maintenance batch fair when a settled entry leaves the live list. */
/datum/unit_test/dogmos_active_walk_removal_cursor
	/// Exposure counts for the four real fixture turfs, including repeated filler entries.
	var/list/exposures

/datum/unit_test/dogmos_active_walk_removal_cursor/proc/count_exposure(turf/source)
	SIGNAL_HANDLER
	exposures[source]++
	// Model a real callback removing a live entry while the initial snapshot is in use.
	if(source == run_loc_floor_bottom_left)
		SSair.remove_from_active(source)

/datum/unit_test/dogmos_active_walk_removal_cursor/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/turf/open/settler = run_loc_floor_bottom_left
	var/turf/open/filler = get_step(settler, EAST)
	var/turf/open/sentinel = get_step(filler, EAST)
	var/turf/open/tail = get_step(sentinel, EAST)
	var/list/fixture_turfs = list(settler, filler, sentinel, tail)
	var/list/original_turf_state = list()
	var/list/original_active = SSair.active_turfs
	var/list/original_run = SSair.currentrun
	var/list/original_visuals = SSair.dogmos_visual_refresh_batch
	var/original_prefetch_end = SSair.dogmos_walk_prefetch_end
	var/original_cursor = SSair.active_turfs_walk_cursor
	var/original_state = SSair.state
	var/original_tick_limit = Master.current_ticklimit
	var/original_oxygen = tail.air.get_moles(/datum/gas/oxygen)
	var/batch_limit = 100 // The public maintenance bound; air.dm's define is file-local.
	exposures = list()
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		original_turf_state[fixture_turf] = list(fixture_turf.atmos_adjacent_turfs, fixture_turf.excited, fixture_turf.excited_group, fixture_turf.current_cycle, fixture_turf.archived_cycle)
		fixture_turf.excited = TRUE
		fixture_turf.excited_group = null
		// This fixture checks traversal, so preserve the native archived air state.
		fixture_turf.archived_cycle = SSair.times_fired
		RegisterSignal(fixture_turf, COMSIG_TURF_EXPOSE, PROC_REF(count_exposure))
	settler.atmos_adjacent_turfs = list()
	filler.atmos_adjacent_turfs = list(tail)
	sentinel.atmos_adjacent_turfs = list(tail)
	tail.atmos_adjacent_turfs = list(filler)
	tail.excited = FALSE
	var/failure
	try
		tail.air.set_moles(/datum/gas/oxygen, filler.air.get_moles(/datum/gas/oxygen) + 100)
		var/list/queue = list(settler)
		for(var/index in 1 to batch_limit - 1)
			queue += filler
		queue += sentinel
		// The differing tail starts outside the queue and is appended by filler comparisons.
		SSair.active_turfs = queue
		SSair.currentrun = list()
		SSair.active_turfs_walk_cursor = 0
		SSair.dogmos_visual_refresh_batch = queue.Copy()
		SSair.dogmos_walk_prefetch_end = 0
		SSair.state = SS_RUNNING
		Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag
		SSair.walk_active_turfs_batch()
		if(exposures[settler] != 1 || exposures[filler] != batch_limit - 1 || exposures[sentinel] || exposures[tail])
			failure = "The first walk did not process exactly its bounded fixture batch."
		else if(settler in SSair.active_turfs)
			failure = "The isolated settled turf did not leave the active list."
		else if(!tail.excited || !(tail in SSair.active_turfs))
			failure = "The differing inactive tail was not appended during the first batch."
		else
			SSair.walk_active_turfs_batch()
			if(exposures[sentinel] != 1)
				failure = "Removing the first settled turf skipped the next unprocessed turf on the second walk."
			else if(exposures[tail])
				failure = "An activation outside the initial snapshot was exposed during the same cycle."
	catch(var/exception/error)
		failure = "The removal-cursor fixture raised [error.name]."

	SSair.active_turfs = original_active
	SSair.currentrun = original_run
	SSair.dogmos_visual_refresh_batch = original_visuals
	SSair.dogmos_walk_prefetch_end = original_prefetch_end
	SSair.active_turfs_walk_cursor = original_cursor
	SSair.state = original_state
	Master.current_ticklimit = original_tick_limit
	tail.air.set_moles(/datum/gas/oxygen, original_oxygen)
	for(var/turf/open/fixture_turf as anything in fixture_turfs)
		UnregisterSignal(fixture_turf, COMSIG_TURF_EXPOSE)
		var/list/saved_turf_state = original_turf_state[fixture_turf]
		fixture_turf.atmos_adjacent_turfs = saved_turf_state[1]
		fixture_turf.excited = saved_turf_state[2]
		fixture_turf.excited_group = saved_turf_state[3]
		fixture_turf.current_cycle = saved_turf_state[4]
		fixture_turf.archived_cycle = saved_turf_state[5]
	exposures = null
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Verifies atomic stage candidates do not invalidate warm snapshots before publication. */
/datum/unit_test/dogmos_service_atomic_stage_cache_boundary

/datum/unit_test/dogmos_service_atomic_stage_cache_boundary/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/original_active = SSair.active_turfs
	var/list/original_pressure_queue = SSair.high_pressure_delta.Copy()
	var/list/original_pressure = list()
	var/original_work_limit = SSair.dogmos_stage_work_limit
	var/list/room_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	var/turf/open/target = run_loc_floor_bottom_left
	for(var/turf/open/fixture_turf as anything in room_turfs)
		original_pressure[fixture_turf] = list(fixture_turf.pressure_difference, fixture_turf.pressure_direction)
	var/list/original_stage_samples = SSair.dogmos_stage_test_samples
	var/failure
	var/restored = FALSE
	var/pending = FALSE
	var/stage_complete = FALSE
	try
		SSair.dogmos_stage_test_samples = list()
		SSdogmos.reset_mixture_snapshot_cache()
		SSair.active_turfs = room_turfs.Copy()
		SSair.dogmos_pending_frontier_epoch = null
		if(!SSair.sync_dogmos_frontier())
			failure = "The atomic stage cache fixture could not publish its temporary frontier."
		else
			// Seed a real diffusion mutation, then warm the exact service snapshot that must remain
			// readable until the atomic candidate is finally published.
			var/seeded_oxygen = target.air.get_moles(/datum/gas/oxygen) + 100
			target.air.set_moles(/datum/gas/oxygen, seeded_oxygen)
			target.air.dogmos_snapshot()
			var/cache_epoch_before = SSdogmos.dogmos_mixture_cache_epoch
			SSair.dogmos_stage_work_limit = 1
			// A 0.01 ms allocation can be consumed by the DM entry checks before any
			// native request. Keep the fixture large enough that this positive allocation
			// must return a real bounded response with preparation work remaining.
			pending = SSair.dogmos_run_stage(DOGMOS_TEST_STAGE_TURFS, 0.25)
			var/list/first_sample = SSair.dogmos_stage_test_samples["[DOGMOS_TEST_STAGE_TURFS]"]
			if(!pending)
				failure = "The atomic diffusion fixture completed before exposing a pending native chunk."
			else if(!islist(first_sample) || first_sample[1] < 1 || first_sample[2] < 1 || SSair.dogmos_stage_remaining_estimate <= 0 || SSair.dogmos_stage_remaining_estimate >= length(room_turfs))
				failure = "The atomic diffusion fixture did not record native work in its first pending response."
			else if(SSdogmos.dogmos_mixture_cache_epoch != cache_epoch_before || !SSdogmos.lookup_mixture_snapshot_cache(target.air.dogmos_slot, target.air.dogmos_generation))
				failure = "An atomic diffusion chunk invalidated a warm snapshot before publication."
			if(pending)
				for(var/attempt in 1 to 4096)
					if(!pending)
						break
					pending = SSair.dogmos_run_stage(DOGMOS_TEST_STAGE_TURFS, 100)
			if(pending)
				failure = "The atomic diffusion fixture did not complete within its bounded retry count."
			else if(!isnull(SSair.dogmos_pending_stage))
				failure = "The atomic diffusion fixture reported completion while retaining a native cursor."
			else
				stage_complete = TRUE
				if(SSdogmos.lookup_mixture_snapshot_cache(target.air.dogmos_slot, target.air.dogmos_generation))
					failure = "The atomic diffusion publication left a stale warm snapshot readable."
				if(target.air.get_moles(/datum/gas/oxygen) >= seeded_oxygen)
					failure = "The atomic diffusion fixture did not publish a numeric gas change."
	catch(var/exception/error)
		failure = "The atomic stage cache fixture raised [error.name]."
	try
		if(stage_complete && SSdogmos.service_ready && !dogmos_drain_fixture_callbacks())
			failure = "The atomic stage cache fixture left callbacks pending after publication."
			stage_complete = FALSE
	catch(var/exception/drain_error)
		failure = "The atomic stage cache fixture callback drain raised [drain_error.name]."
		stage_complete = FALSE
	// Restore DM-local state for diagnostics even when the native cursor is
	// incomplete. Do not clear its frontier or call sync while that cursor is live;
	// there is no safe DM cancellation API for an in-flight native stage.
	var/native_cursor_open = !stage_complete || pending || !isnull(SSair.dogmos_pending_stage)
	SSair.dogmos_stage_work_limit = original_work_limit
	SSair.active_turfs = original_active
	SSair.high_pressure_delta.Cut()
	SSair.high_pressure_delta += original_pressure_queue
	for(var/turf/open/fixture_turf as anything in room_turfs)
		var/list/pressure = original_pressure[fixture_turf]
		fixture_turf.pressure_difference = pressure[1]
		fixture_turf.pressure_direction = pressure[2]
	if(!native_cursor_open && SSdogmos.service_ready)
		try
			SSair.dogmos_pending_frontier_epoch = null
			restored = SSair.sync_dogmos_frontier()
			SSair.dogmos_pending_frontier_epoch = null
		catch(var/exception/restore_error)
			failure = "The atomic stage cache fixture restoration raised [restore_error.name]."
	SSair.dogmos_stage_test_samples = original_stage_samples
	SSdogmos.reset_mixture_snapshot_cache()
	if(native_cursor_open)
		return dogmos_abort_fixture("The atomic stage cache fixture left a native stage pending; its frontier was not touched.")
	if(!restored)
		return dogmos_abort_fixture("The atomic stage cache fixture could not restore its normal frontier.")
	if(!isnull(SSair.dogmos_pending_stage) || SSair.dogmos_pending_frontier_epoch)
		return dogmos_abort_fixture("The atomic stage cache fixture left a native stage or frontier pending.")
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Verifies one Dogmos turf-processing cycle performs the configured FDM pass count. */
/datum/unit_test/dogmos_service_fdm_linda_cadence

/datum/unit_test/dogmos_service_fdm_linda_cadence/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/pair = allocate_turf_pair()
	if(length(pair) != 2)
		return Fail("The FDM cadence fixture needs two adjacent turfs.", __FILE__, __LINE__)
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]
	turf_a.air.set_moles(/datum/gas/oxygen, turf_a.air.get_moles(/datum/gas/oxygen) * 3)
	var/a_before = turf_a.air.get_moles(/datum/gas/oxygen)
	var/b_before = turf_b.air.get_moles(/datum/gas/oxygen)
	var/expected_steps = max(1, round(SSair.share_max_steps))
	var/list/expected_stage_epoch = SSair.dogmos_stage_epoch.Copy()
	for(var/step in 1 to expected_steps)
		expected_stage_epoch = SSdogmos.increment_u64_words(expected_stage_epoch)
	var/original_fdm_steps_completed = SSair.dogmos_fdm_steps_completed
	SSair.dogmos_fdm_steps_completed = 0
	var/completed = dogmos_run_fixture_stage(DOGMOS_TEST_STAGE_TURFS, pair, use_fdm_cadence = TRUE)
	var/completed_steps = SSair.dogmos_fdm_steps_completed
	SSair.dogmos_fdm_steps_completed = original_fdm_steps_completed
	if(!completed)
		return
	if(completed_steps != expected_steps)
		return Fail("Dogmos completed [completed_steps] FDM passes instead of the configured [expected_steps].", __FILE__, __LINE__)
	for(var/word_index in 1 to 4)
		if(SSair.dogmos_stage_epoch[word_index] != expected_stage_epoch[word_index])
			return Fail("The reported FDM pass count did not match the number of native stage epochs.", __FILE__, __LINE__)
	if(turf_a.air.get_moles(/datum/gas/oxygen) >= a_before || turf_b.air.get_moles(/datum/gas/oxygen) <= b_before)
		return Fail("The configured FDM passes did not actually redistribute the seeded oxygen.", __FILE__, __LINE__)

/** Verifies malformed stage responses are rejected before SSair reads their fields. */
/datum/unit_test/dogmos_service_stage_response_failure

/datum/unit_test/dogmos_service_stage_response_failure/Run()
	var/list/valid_response = new/list(DOGMOS_TEST_STAGE_RESPONSE_FIELDS)
	for(var/field_index in 1 to DOGMOS_TEST_STAGE_RESPONSE_FIELDS)
		valid_response[field_index] = 0
	var/list/short_response = valid_response.Copy()
	short_response.Cut(length(short_response), length(short_response) + 1)
	var/list/non_numeric_response = valid_response.Copy()
	non_numeric_response[1] = "invalid"

	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, null))
		return Fail("Dogmos accepted a null stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, 1))
		return Fail("Dogmos accepted a scalar stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, short_response))
		return Fail("Dogmos accepted a short stage response.", __FILE__, __LINE__)
	if(SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, non_numeric_response))
		return Fail("Dogmos accepted a non-numeric stage response.", __FILE__, __LINE__)
	if(!SSair.dogmos_stage_response_is_valid(DOGMOS_TEST_STAGE_EQUALIZE, valid_response))
		return Fail("Dogmos rejected a fixed-width numeric stage response.", __FILE__, __LINE__)

	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_remaining_estimate = SSair.dogmos_stage_remaining_estimate
	var/original_active_stages_complete = SSair.dogmos_active_turf_stages_complete
	var/original_equalize_stages_complete = SSair.dogmos_equalize_stage_complete
	var/list/original_walk_state = list()
	for(var/field in list("dogmos_active_walk_complete", "active_turfs_walk_cursor", "dogmos_visual_refresh_cursor", "dogmos_visual_refresh_batch"))
		original_walk_state[field] = SSair.vars[field]
	var/original_fdm_steps_completed = SSair.dogmos_fdm_steps_completed
	var/original_can_fire = SSair.can_fire
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	SSair.dogmos_pending_stage = DOGMOS_TEST_STAGE_REACTIONS
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	SSair.dogmos_stage_remaining_estimate = 77
	SSair.dogmos_active_turf_stages_complete = TRUE
	SSair.dogmos_equalize_stage_complete = TRUE
	SSair.dogmos_fdm_steps_completed = 3
	SSair.dogmos_active_walk_complete = TRUE
	SSair.active_turfs_walk_cursor = 1
	SSair.dogmos_visual_refresh_cursor = 1
	SSair.dogmos_visual_refresh_batch = list(run_loc_floor_bottom_left)
	var/failure_pending = SSair.dogmos_fail_closed_stage(DOGMOS_TEST_STAGE_REACTIONS, FALSE)
	var/failure_message
	if(!failure_pending)
		failure_message = "Dogmos did not pause SSair after an irrecoverable stage response."
	else if(!isnull(SSair.dogmos_pending_stage) || !isnull(SSair.dogmos_pending_frontier_epoch))
		failure_message = "Dogmos retained failed stage state for another retry."
	else if(SSair.dogmos_stage_remaining_estimate || SSair.dogmos_active_turf_stages_complete || SSair.dogmos_equalize_stage_complete || SSair.dogmos_fdm_steps_completed)
		failure_message = "Dogmos retained failed-cycle progress after the stage failure."
	else if(SSair.can_fire || SSdogmos.service_ready || !SSdogmos.service_failure_latched)
		failure_message = "Dogmos did not fail closed after the stage failure."
	else if(SSair.dogmos_active_walk_complete || SSair.active_turfs_walk_cursor || SSair.dogmos_visual_refresh_cursor || length(SSair.dogmos_visual_refresh_batch))
		failure_message = "Dogmos retained a failed maintenance or visual continuation."

	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSair.dogmos_stage_remaining_estimate = original_remaining_estimate
	SSair.dogmos_active_turf_stages_complete = original_active_stages_complete
	SSair.dogmos_equalize_stage_complete = original_equalize_stages_complete
	for(var/field in original_walk_state)
		SSair.vars[field] = original_walk_state[field]
	SSair.dogmos_fdm_steps_completed = original_fdm_steps_completed
	SSair.can_fire = original_can_fire
	SSdogmos.service_ready = original_service_ready
	SSdogmos.service_failure_latched = original_failure_latched
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies a resumed SSair stage does not repeat the cycle health preflight. */
/datum/unit_test/dogmos_service_resumed_health_preflight

/datum/unit_test/dogmos_service_resumed_health_preflight/Run()
	if(SSair.dogmos_health_preflight_required(TRUE))
		return Fail("A resumed SSair stage repeated the Dogmos cycle health preflight.", __FILE__, __LINE__)
	if(!SSair.dogmos_health_preflight_required(FALSE))
		return Fail("A new SSair cycle skipped the Dogmos health preflight.", __FILE__, __LINE__)

/** Verifies SSair completes a real Runtime Station or MetaStation cycle after startup. */
/datum/unit_test/dogmos_service_idle_cycle_progress

/datum/unit_test/dogmos_service_idle_cycle_progress/Run()
	var/initial_fire_count = SSair.times_fired
	var/deadline = world.time + 30 SECONDS
	while(SSair.times_fired <= initial_fire_count && world.time < deadline)
		sleep(1 SECONDS)
	if(SSair.times_fired <= initial_fire_count)
		return Fail("Dogmos did not allow SSair to complete an idle cycle within 30 seconds.", __FILE__, __LINE__)

/** Verifies a dirty pipeline wakes an attached dormant atmosphere machine. */
/datum/unit_test/dogmos_idle_machinery_pipeline_wake
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Pipeline-owned mixture released during teardown.
	var/datum/gas_mixture/pipeline_air

/datum/unit_test/dogmos_idle_machinery_pipeline_wake/Run()
	var/obj/machinery/atmospherics/components/binary/pump/test_pump = allocate(/obj/machinery/atmospherics/components/binary/pump)
	SSair.stop_processing_machine(test_pump)
	test_pipeline = new
	pipeline_air = new(200)
	test_pipeline.set_air(pipeline_air)
	test_pipeline.other_atmos_machines |= test_pump
	test_pipeline.update = TRUE
	test_pipeline.process()
	if(!(test_pump in SSair.atmos_machinery))
		return Fail("A dirty pipeline did not wake its attached dormant atmosphere machine.", __FILE__, __LINE__)

/datum/unit_test/dogmos_idle_machinery_pipeline_wake/Destroy()
	test_pipeline?.other_atmos_machines.Cut()
	QDEL_NULL(test_pipeline)
	QDEL_NULL(pipeline_air)
	return ..()

/** Verifies component gas is preserved when its node outlives its destroyed pipenet. */
/datum/unit_test/dogmos_component_relocates_air_without_parent
	/// Destination mixture released during teardown.
	var/datum/gas_mixture/released_air

/datum/unit_test/dogmos_component_relocates_air_without_parent/Run()
	var/obj/machinery/atmospherics/components/unary/vent_pump/test_component = allocate(/obj/machinery/atmospherics/components/unary/vent_pump, run_loc_floor_bottom_left)
	released_air = new(200)
	test_component.nodes[1] = test_component
	test_component.parents[1] = null
	test_component.airs[1].set_moles(GAS_O2, 10)

	test_component.relocate_airs(released_air)

	if(released_air.get_moles(GAS_O2) != 10)
		return Fail("Component gas was not relocated after its node outlived the parent pipenet.", __FILE__, __LINE__)

/datum/unit_test/dogmos_component_relocates_air_without_parent/Destroy()
	QDEL_NULL(released_air)
	return ..()

/** Verifies a pump sleeps when its current gas state cannot produce a transfer. */
/datum/unit_test/dogmos_idle_machinery_pump_sleeps
	/// Input pipeline released during teardown.
	var/datum/pipeline/input_pipeline
	/// Output pipeline released during teardown.
	var/datum/pipeline/output_pipeline
	/// Input pipeline mixture released during teardown.
	var/datum/gas_mixture/input_pipeline_air
	/// Output pipeline mixture released during teardown.
	var/datum/gas_mixture/output_pipeline_air

/datum/unit_test/dogmos_idle_machinery_pump_sleeps/Run()
	var/obj/machinery/atmospherics/components/binary/pump/test_pump = allocate(/obj/machinery/atmospherics/components/binary/pump)
	input_pipeline = new
	output_pipeline = new
	input_pipeline_air = new(200)
	output_pipeline_air = new(200)
	input_pipeline.set_air(input_pipeline_air)
	output_pipeline.set_air(output_pipeline_air)
	test_pump.parents[1] = input_pipeline
	test_pump.parents[2] = output_pipeline
	test_pump.on = TRUE
	if(test_pump.process_atmos(SSair.wait * 0.1) != PROCESS_KILL)
		return Fail("A gas pump with no transferable gas did not return PROCESS_KILL.", __FILE__, __LINE__)

/datum/unit_test/dogmos_idle_machinery_pump_sleeps/Destroy()
	QDEL_NULL(input_pipeline)
	QDEL_NULL(output_pipeline)
	QDEL_NULL(input_pipeline_air)
	QDEL_NULL(output_pipeline_air)
	return ..()

/** Verifies turning on dormant atmosphere machinery wakes it immediately. */
/datum/unit_test/dogmos_idle_machinery_control_wake

/datum/unit_test/dogmos_idle_machinery_control_wake/Run()
	var/obj/machinery/atmospherics/components/binary/pump/test_pump = allocate(/obj/machinery/atmospherics/components/binary/pump)
	test_pump.set_on(FALSE)
	SSair.stop_processing_machine(test_pump)
	test_pump.set_on(TRUE)
	if(!(test_pump in SSair.atmos_machinery))
		return Fail("Turning on dormant atmosphere machinery did not wake it immediately.", __FILE__, __LINE__)

/** Verifies dormant enabled atmosphere machinery wakes when it becomes operational. */
/datum/unit_test/dogmos_idle_machinery_operational_wake

/datum/unit_test/dogmos_idle_machinery_operational_wake/Run()
	var/obj/machinery/atmospherics/components/binary/pump/test_pump = allocate(/obj/machinery/atmospherics/components/binary/pump)
	test_pump.on = TRUE
	test_pump.set_is_operational(FALSE)
	SSair.stop_processing_machine(test_pump)
	if(test_pump in SSair.atmos_machinery)
		return Fail("The operational wake test requires dormant machinery.", __FILE__, __LINE__)
	test_pump.set_is_operational(TRUE)
	if(!(test_pump in SSair.atmos_machinery))
		return Fail("Dormant enabled atmosphere machinery did not wake when it became operational.", __FILE__, __LINE__)

/** Verifies turf atmosphere activity wakes a dormant vent on that turf. */
/datum/unit_test/dogmos_idle_machinery_turf_wake

/datum/unit_test/dogmos_idle_machinery_turf_wake/Run()
	var/obj/machinery/atmospherics/components/unary/vent_pump/test_vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump)
	SSair.stop_processing_machine(test_vent)
	SSair.add_to_active(run_loc_floor_bottom_left)
	if(!(test_vent in SSair.atmos_machinery))
		return Fail("Turf atmosphere activity did not wake a dormant vent on that turf.", __FILE__, __LINE__)

/** Verifies turf meter deletion reaches parent cleanup without accessing pipe-only state. */
/datum/unit_test/dogmos_turf_meter_destroy

/datum/unit_test/dogmos_turf_meter_destroy/Run()
	var/obj/machinery/meter/turf/test_meter = allocate(/obj/machinery/meter/turf)
	if(test_meter.target != run_loc_floor_bottom_left)
		return Fail("The turf meter must attach to its turf.", __FILE__, __LINE__)
	qdel(test_meter, force = TRUE)
	if(!isnull(test_meter.target))
		return Fail("Deleting a turf meter must clear its target.", __FILE__, __LINE__)
	if(!isnull(test_meter.loc))
		return Fail("Deleting a turf meter must reach parent cleanup and leave the map.", __FILE__, __LINE__)
	if(test_meter in SSair.atmos_machinery)
		return Fail("Deleted turf meters must leave atmosphere processing.", __FILE__, __LINE__)

/** Verifies pipe meter deletion removes the pipeline's wakeup reference. */
/datum/unit_test/dogmos_pipe_meter_destroy

/datum/unit_test/dogmos_pipe_meter_destroy/Run()
	var/obj/machinery/atmospherics/pipe/test_pipe = allocate(/obj/machinery/atmospherics/pipe/smart/simple)
	var/obj/machinery/meter/test_meter = allocate(/obj/machinery/meter)
	if(test_meter.target != test_pipe)
		return Fail("The pipe meter must attach to the test pipe.", __FILE__, __LINE__)
	if(!(test_meter in test_pipe.dogmos_pipeline_meters))
		return Fail("The pipe must register the meter for pipeline wakeups.", __FILE__, __LINE__)
	qdel(test_meter, force = TRUE)
	if(test_meter in test_pipe.dogmos_pipeline_meters)
		return Fail("Deleting a pipe meter must remove its pipeline wakeup reference.", __FILE__, __LINE__)
	if(!isnull(test_meter.target))
		return Fail("Deleting a pipe meter must clear its target.", __FILE__, __LINE__)
	if(!isnull(test_meter.loc))
		return Fail("Deleting a pipe meter must reach parent cleanup and leave the map.", __FILE__, __LINE__)

/** Verifies a stable pipe meter sleeps and wakes on its pipeline's next change. */
/datum/unit_test/dogmos_idle_meter_scheduler
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Pipeline-owned mixture released during teardown.
	var/datum/gas_mixture/pipeline_air
	/// Pipe detached before pipeline teardown.
	var/obj/machinery/atmospherics/pipe/test_pipe
	/// Meter detached from the pipe before teardown.
	var/obj/machinery/meter/test_meter

/datum/unit_test/dogmos_idle_meter_scheduler/Run()
	test_pipe = allocate(/obj/machinery/atmospherics/pipe/smart/simple)
	test_meter = allocate(/obj/machinery/meter)
	test_pipeline = new
	pipeline_air = new(200)
	test_pipeline.set_air(pipeline_air)
	test_pipeline.members |= test_pipe
	test_pipe.parent = test_pipeline
	test_meter.target = test_pipe
	test_pipe.dogmos_pipeline_meters |= test_meter
	if(test_meter.process_atmos() != PROCESS_KILL)
		return Fail("A stable pipe meter did not return PROCESS_KILL.", __FILE__, __LINE__)
	SSair.stop_processing_machine(test_meter)
	test_pipeline.update = TRUE
	test_pipeline.process()
	if(!(test_meter in SSair.atmos_machinery))
		return Fail("A dirty pipeline did not wake its dormant pipe meter.", __FILE__, __LINE__)

/datum/unit_test/dogmos_idle_meter_scheduler/Destroy()
	if(test_meter && test_pipe)
		test_pipe.dogmos_pipeline_meters -= test_meter
		test_meter.target = null
	if(test_pipe)
		test_pipe.parent = null
	test_pipeline?.members.Cut()
	QDEL_NULL(test_pipeline)
	QDEL_NULL(pipeline_air)
	return ..()

/** Verifies a vent sleeps after reaching its configured pressure bound. */
/datum/unit_test/dogmos_idle_machinery_vent_sleeps

/datum/unit_test/dogmos_idle_machinery_vent_sleeps/Run()
	var/obj/machinery/atmospherics/components/unary/vent_pump/test_vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump)
	test_vent.nodes[1] = test_vent
	test_vent.on = TRUE
	test_vent.external_pressure_bound = run_loc_floor_bottom_left.return_air().return_pressure()
	if(test_vent.process_atmos(SSair.wait * 0.1) != PROCESS_KILL)
		return Fail("A vent at its configured pressure bound did not return PROCESS_KILL.", __FILE__, __LINE__)

/** Verifies a stable pressure tank sleeps until its pipeline changes. */
/datum/unit_test/dogmos_idle_machinery_tank_sleeps

/datum/unit_test/dogmos_idle_machinery_tank_sleeps/Run()
	var/obj/machinery/atmospherics/components/tank/test_tank = allocate(/obj/machinery/atmospherics/components/tank)
	if(test_tank.process_atmos(SSair.wait * 0.1) != PROCESS_KILL)
		return Fail("A stable under-pressure tank did not return PROCESS_KILL.", __FILE__, __LINE__)

/** Verifies an enabled filter sleeps when its input contains no transferable gas. */
/datum/unit_test/dogmos_idle_machinery_filter_sleeps

/datum/unit_test/dogmos_idle_machinery_filter_sleeps/Run()
	var/obj/machinery/atmospherics/components/trinary/filter/test_filter = allocate(/obj/machinery/atmospherics/components/trinary/filter)
	test_filter.nodes[1] = test_filter
	test_filter.nodes[2] = test_filter
	test_filter.nodes[3] = test_filter
	test_filter.on = TRUE
	if(test_filter.process_atmos(SSair.wait * 0.1) != PROCESS_KILL)
		return Fail("An enabled filter with empty input did not return PROCESS_KILL.", __FILE__, __LINE__)

/** Verifies a stable heat pipe wakes on pipeline changes and sleeps after convergence. */
/datum/unit_test/dogmos_idle_heat_pipe_scheduler
	/// Pipeline released during teardown.
	var/datum/pipeline/test_pipeline
	/// Pipeline-owned mixture released during teardown.
	var/datum/gas_mixture/pipeline_air
	/// Heat pipe detached before pipeline teardown.
	var/obj/machinery/atmospherics/pipe/heat_exchanging/test_pipe

/datum/unit_test/dogmos_idle_heat_pipe_scheduler/Run()
	test_pipe = allocate(/obj/machinery/atmospherics/pipe/heat_exchanging/simple)
	test_pipeline = new
	pipeline_air = new(200)
	pipeline_air.set_temperature(run_loc_floor_bottom_left.GetTemperature())
	test_pipeline.set_air(pipeline_air)
	test_pipeline.members |= test_pipe
	test_pipe.parent = test_pipeline
	SSair.stop_processing_machine(test_pipe)
	test_pipeline.update = TRUE
	test_pipeline.process()
	if(!(test_pipe in SSair.atmos_machinery))
		return Fail("A dirty pipeline did not wake its dormant heat-exchange pipe.", __FILE__, __LINE__)
	pipeline_air.set_temperature(run_loc_floor_bottom_left.GetTemperature())
	if(test_pipe.process_atmos(SSair.wait * 0.1) != PROCESS_KILL)
		return Fail("A stable heat-exchange pipe did not return PROCESS_KILL.", __FILE__, __LINE__)
	SSair.stop_processing_machine(test_pipe)
	SSair.add_to_active(run_loc_floor_bottom_left)
	if(!(test_pipe in SSair.atmos_machinery))
		return Fail("Turf atmosphere activity did not wake its dormant heat-exchange pipe.", __FILE__, __LINE__)
	SSair.stop_processing_machine(test_pipe)
	var/mob/living/test_mob = allocate(/mob/living/carbon/human/consistent)
	test_pipe.post_buckle_mob(test_mob)
	if(!(test_pipe in SSair.atmos_machinery))
		return Fail("Buckling a mob did not wake its dormant heat-exchange pipe.", __FILE__, __LINE__)

/datum/unit_test/dogmos_idle_heat_pipe_scheduler/Destroy()
	if(test_pipe)
		test_pipe.parent = null
	test_pipeline?.members.Cut()
	QDEL_NULL(test_pipeline)
	QDEL_NULL(pipeline_air)
	return ..()


/** Verifies startup coalesces repeated turf visits until all endpoints are initialized. */
/datum/unit_test/dogmos_service_startup_adjacency_coalesces

/datum/unit_test/dogmos_service_startup_adjacency_coalesces/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/turf/target = run_loc_floor_bottom_left
	SSdogmos.begin_turf_registration_batch()
	for(var/repetition in 1 to 3)
		target.sync_dogmos_adjacency()
	var/failure_message
	if(length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency))
		failure_message = "Startup constructed intermediate edges before the final adjacency drain."
	else if(length(SSdogmos.dogmos_pending_adjacency_retry) != 1 || !SSdogmos.dogmos_pending_adjacency_retry[target])
		failure_message = "Repeated startup adjacency visits did not coalesce to one turf."
	SSdogmos.finish_turf_registration_batch()
	if(length(SSdogmos.dogmos_pending_adjacency_retry) || length(SSdogmos.dogmos_pending_turf_adjacency) \
		|| length(SSdogmos.dogmos_pending_turf_heat_adjacency))
		failure_message = "Startup adjacency work remained queued after the final drain."
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies repeated deferred adjacency updates coalesce and drain completely. */
/datum/unit_test/dogmos_service_topology_pressure

/datum/unit_test/dogmos_service_topology_pressure/Run()
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Dogmos did not reach a safe stage boundary before the topology pressure test.", __FILE__, __LINE__)

	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	var/list/original_gas_edges = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_gas_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat_edges = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/list/original_adjacency_retry = SSdogmos.dogmos_pending_adjacency_retry
	var/original_max_queued = SSdogmos.dogmos_runtime_topology_max_queued
	var/turf/target = run_loc_floor_bottom_left

	SSdogmos.runtime_topology_batching = TRUE
	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.dogmos_pending_adjacency_retry = list()
	SSdogmos.dogmos_runtime_topology_max_queued = 0
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	var/first_gas_count = length(SSdogmos.dogmos_pending_turf_adjacency)
	var/first_heat_count = length(SSdogmos.dogmos_pending_turf_heat_adjacency)
	for(var/repetition in 1 to 20)
		target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)

	var/failure_message
	if(length(SSdogmos.dogmos_pending_turf_adjacency) != first_gas_count)
		failure_message = "Deferred gas adjacency work grew with repeated updates instead of coalescing."
	else if(length(SSdogmos.dogmos_pending_turf_heat_adjacency) != first_heat_count)
		failure_message = "Deferred heat adjacency work grew with repeated updates instead of coalescing."
	else if(length(SSdogmos.dogmos_pending_adjacency_retry) != 1)
		failure_message = "Deferred adjacency work did not coalesce to one unique turf retry."
	else if(SSdogmos.dogmos_runtime_topology_max_queued != first_gas_count + first_heat_count)
		failure_message = "Dogmos topology pressure telemetry did not retain the unique queued edge count."

	SSair.dogmos_pending_frontier_epoch = null
	if(!SSdogmos.flush_turf_registration_batch() && !failure_message)
		failure_message = "Dogmos did not flush deferred topology after the committed frontier cleared."
	if((length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency) \
			|| length(SSdogmos.dogmos_pending_turf_adjacency_index) || length(SSdogmos.dogmos_pending_turf_heat_adjacency_index)) && !failure_message)
		failure_message = "Dogmos retained topology queue or reverse-index entries after a successful flush."

	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.runtime_topology_batching = original_runtime_batching
	SSdogmos.dogmos_pending_turf_adjacency = original_gas_edges
	SSdogmos.dogmos_pending_turf_adjacency_index = original_gas_index
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_edges
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_index
	SSdogmos.dogmos_pending_adjacency_retry = original_adjacency_retry
	SSdogmos.dogmos_runtime_topology_max_queued = original_max_queued
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies a deferred adjacency retry refreshes its own late-created gas registration. */
/datum/unit_test/dogmos_service_adjacency_retry_late_air

/datum/unit_test/dogmos_service_adjacency_retry_late_air/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/pair = allocate_turf_pair()
	var/turf/open/target = pair[1]
	var/datum/gas_mixture/original_air = target.air
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	// Map construction can register a heat node before creating its gas datum.
	target.air = null
	target.register_dogmos_air()
	target.air = original_air
	SSdogmos.runtime_topology_batching = TRUE
	SSdogmos.dogmos_pending_adjacency_retry[target] = TRUE
	SSdogmos.retry_pending_turf_adjacencies()
	var/source_current = target.dogmos_air_registration_is_current()
	// Repair the fixture before flushing even on RED: stale edges must not reach the service.
	if(!source_current)
		target.register_dogmos_air()
		target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	SSdogmos.runtime_topology_batching = original_runtime_batching
	SSdogmos.flush_turf_registration_batch()
	if(!source_current)
		return Fail("Deferred adjacency rebuilt gas edges while its source still had a heat-only registration.", __FILE__, __LINE__)

/** Verifies the real template finalizer coalesces border edges without resetting live air or heat. */
/datum/unit_test/dogmos_template_border_batch

/datum/unit_test/dogmos_template_border_batch/Run()
	var/reached_stage_boundary = FALSE
	for(var/attempt in 1 to DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS)
		if(isnull(SSair.dogmos_pending_stage) && !SSair.dogmos_pending_frontier_epoch && SSdogmos.flush_turf_registration_batch())
			reached_stage_boundary = TRUE
			break
		sleep(SSair.wait)
	if(!reached_stage_boundary)
		return Fail("Template border fixture did not reach a safe stage boundary.", __FILE__, __LINE__)
	var/list/pair = allocate_turf_pair()
	var/turf/open/hot_turf = pair[1]
	var/turf/open/cold_turf = pair[2]
	var/original_hot_temperature = hot_turf.dogmos_heat_temperature()
	var/original_cold_temperature = cold_turf.dogmos_heat_temperature()
	hot_turf.air.set_moles(GAS_O2, 13)
	cold_turf.air.set_moles(GAS_O2, 29)
	hot_turf.set_temperature(420)
	cold_turf.set_temperature(333)
	var/hot_slot = hot_turf.dogmos_registered_mixture_slot
	var/cold_slot = cold_turf.dogmos_registered_mixture_slot
	var/datum/map_template/template = allocate(/datum/map_template)
	var/list/bounds = list(
		hot_turf.x + 1, hot_turf.y + 1, hot_turf.z,
		hot_turf.x + 3, hot_turf.y + 3, hot_turf.z,
	)
	var/original_can_fire = SSair.can_fire
	SSair.can_fire = FALSE
	var/calls_before = SSdogmos.dogmos_runtime_topology_calls
	template.initTemplateBounds(bounds)
	var/calls = SSdogmos.dogmos_runtime_topology_calls - calls_before
	file("[GLOB.log_directory]/dogmos-template-border.json") << json_encode(list("interior_bounds" = bounds, "topology_calls" = calls))
	var/failure_message
	if(hot_turf.dogmos_registered_mixture_slot != hot_slot || cold_turf.dogmos_registered_mixture_slot != cold_slot)
		failure_message = "Template finalization replaced an existing mixture identity."
	else if(hot_turf.air.get_moles(GAS_O2) != 13 || cold_turf.air.get_moles(GAS_O2) != 29)
		failure_message = "Template finalization changed existing gas quantities."
	else if(hot_turf.dogmos_heat_temperature() != 420 || cold_turf.dogmos_heat_temperature() != 333)
		failure_message = "Template finalization reset existing solid temperatures."
	else if(!(cold_turf in hot_turf.atmos_adjacent_turfs) || !(hot_turf in cold_turf.atmos_adjacent_turfs))
		failure_message = "Template finalization lost reciprocal border adjacency."
	else if(SSdogmos.runtime_topology_batching || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency))
		failure_message = "Template finalization leaked its batch ownership or unpublished edges."
	else if(calls > 4)
		failure_message = "A 25-turf template border used [calls] topology calls; its unique edges fit in at most four bounded batches."
	hot_turf.set_temperature(original_hot_temperature)
	cold_turf.set_temperature(original_cold_temperature)
	SSair.can_fire = original_can_fire
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies template border updates respect an outer batch and a frozen simulation frontier. */
/datum/unit_test/dogmos_template_border_batch_ownership

/datum/unit_test/dogmos_template_border_batch_ownership/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/pair = allocate_turf_pair()
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	var/list/original_frontier = SSair.dogmos_pending_frontier_epoch
	var/calls_before = SSdogmos.dogmos_runtime_topology_calls
	SSdogmos.runtime_topology_batching = TRUE
	SSdogmos.update_template_border(pair)
	var/failure_message
	var/retained_targets = (pair[1] in SSdogmos.dogmos_pending_adjacency_retry) && (pair[2] in SSdogmos.dogmos_pending_adjacency_retry)
	var/retained_edges = length(SSdogmos.dogmos_pending_turf_adjacency) && length(SSdogmos.dogmos_pending_turf_heat_adjacency)
	if(!SSdogmos.runtime_topology_batching || SSdogmos.dogmos_runtime_topology_calls != calls_before)
		failure_message = "Template border update drained or released its outer partial batch."
	else if(!retained_targets && !retained_edges)
		failure_message = "Template border update lost its outer owner's pending topology."
	SSdogmos.runtime_topology_batching = original_runtime_batching
	SSdogmos.flush_turf_registration_batch()
	if(!failure_message && (SSdogmos.dogmos_runtime_topology_calls - calls_before < 2 \
		|| length(SSdogmos.dogmos_pending_adjacency_retry) || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency)))
		failure_message = "Closing the outer batch did not publish and drain gas and heat topology."

	calls_before = SSdogmos.dogmos_runtime_topology_calls
	SSair.dogmos_pending_frontier_epoch = SSair.dogmos_frontier_epoch.Copy()
	SSdogmos.update_template_border(pair)
	if(!failure_message && (SSdogmos.runtime_topology_batching != original_runtime_batching || SSdogmos.dogmos_runtime_topology_calls != calls_before))
		failure_message = "Template border update bypassed a frozen simulation frontier."
	if(!failure_message && !length(SSdogmos.dogmos_pending_adjacency_retry))
		failure_message = "Template border update discarded topology deferred behind the frontier."
	SSair.dogmos_pending_frontier_epoch = original_frontier
	SSdogmos.flush_turf_registration_batch()
	if(!failure_message && (length(SSdogmos.dogmos_pending_adjacency_retry) || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency)))
		failure_message = "Template border topology did not drain after the frontier was released."
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies runtime topology coalescing does not re-register current neighbor state. */
/datum/unit_test/dogmos_service_runtime_topology_batch_preserves_neighbor_state

/datum/unit_test/dogmos_service_runtime_topology_batch_preserves_neighbor_state/Run()
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_runtime_batching = SSdogmos.runtime_topology_batching
	var/list/original_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle
	var/list/original_heat = SSdogmos.dogmos_pending_turf_heat
	var/list/original_gas_edges = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_gas_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat_edges = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/list/original_adjacency_retry = SSdogmos.dogmos_pending_adjacency_retry

	SSair.dogmos_pending_frontier_epoch = null
	SSdogmos.runtime_topology_batching = TRUE
	SSdogmos.dogmos_pending_turf_lifecycle = list()
	SSdogmos.dogmos_pending_turf_heat = list()
	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.dogmos_pending_adjacency_retry = list()
	run_loc_floor_bottom_left.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
	// Inspect actual edge construction even when notifications are deferred by the owner.
	SSdogmos.retry_pending_turf_adjacencies()
	var/requeued_neighbor_state = length(SSdogmos.dogmos_pending_turf_lifecycle) || length(SSdogmos.dogmos_pending_turf_heat)

	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSdogmos.runtime_topology_batching = original_runtime_batching
	SSdogmos.dogmos_pending_turf_lifecycle = original_lifecycle
	SSdogmos.dogmos_pending_turf_heat = original_heat
	SSdogmos.dogmos_pending_turf_adjacency = original_gas_edges
	SSdogmos.dogmos_pending_turf_adjacency_index = original_gas_index
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_edges
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_index
	SSdogmos.dogmos_pending_adjacency_retry = original_adjacency_retry
	if(requeued_neighbor_state)
		return Fail("Runtime topology batching re-registered current neighbor lifecycle or heat state.", __FILE__, __LINE__)

/** Verifies turf replacement discards queued topology from an older generation. */
/datum/unit_test/dogmos_service_stale_topology_discard

/datum/unit_test/dogmos_service_stale_topology_discard/Run()
	var/list/original_gas_edges = SSdogmos.dogmos_pending_turf_adjacency
	var/list/original_gas_index = SSdogmos.dogmos_pending_turf_adjacency_index
	var/list/original_heat_edges = SSdogmos.dogmos_pending_turf_heat_adjacency
	var/list/original_heat_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	var/turf/target = run_loc_floor_bottom_left
	var/target_slot = target.dogmos_service_slot()
	var/stale_generation = target.dogmos_service_generation() + 1
	var/neighbor_slot = target_slot + 1
	var/edge_key = "[target_slot]:[stale_generation]:[neighbor_slot]:1"

	SSdogmos.dogmos_pending_turf_adjacency = list()
	SSdogmos.dogmos_pending_turf_adjacency[edge_key] = list(target_slot, stale_generation, neighbor_slot, 1, TRUE, FALSE)
	SSdogmos.dogmos_pending_turf_adjacency_index = list()
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[target_slot]", edge_key)
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_adjacency_index, "[neighbor_slot]", edge_key)
	SSdogmos.dogmos_pending_turf_heat_adjacency = list()
	SSdogmos.dogmos_pending_turf_heat_adjacency[edge_key] = list(target_slot, stale_generation, neighbor_slot, 1, TRUE)
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = list()
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[target_slot]", edge_key)
	SSdogmos.index_pending_edge(SSdogmos.dogmos_pending_turf_heat_adjacency_index, "[neighbor_slot]", edge_key)

	SSdogmos.discard_pending_turf_adjacencies(target)
	var/failure_message
	if(length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_adjacency_index))
		failure_message = "Dogmos retained stale gas topology after a turf generation changed."
	else if(length(SSdogmos.dogmos_pending_turf_heat_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency_index))
		failure_message = "Dogmos retained stale heat topology after a turf generation changed."

	SSdogmos.dogmos_pending_turf_adjacency = original_gas_edges
	SSdogmos.dogmos_pending_turf_adjacency_index = original_gas_index
	SSdogmos.dogmos_pending_turf_heat_adjacency = original_heat_edges
	SSdogmos.dogmos_pending_turf_heat_adjacency_index = original_heat_index
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Verifies that machinery prefetch populates the snapshot cache in one batch IPC call. */
/datum/unit_test/dogmos_service_machinery_prefetch
	var/list/obj/machinery/atmospherics/components/test_components = list()
	var/list/datum/gas_mixture/test_mixtures = list()

/datum/unit_test/dogmos_service_machinery_prefetch/Run()
	var/obj/machinery/atmospherics/components/unary/vent_pump/vent = allocate(/obj/machinery/atmospherics/components/unary/vent_pump)
	test_components += vent
	for(var/datum/gas_mixture/mix as anything in vent.airs)
		if(mix)
			test_mixtures += mix
	var/turf/open/vent_turf = vent.loc
	if(istype(vent_turf) && vent_turf.air)
		test_mixtures += vent_turf.air

	if(!length(test_mixtures))
		return Fail("No prefetchable mixtures from allocated vent pump.", __FILE__, __LINE__)

	SSdogmos.reset_mixture_snapshot_cache()
	var/misses_before = SSdogmos.dogmos_mixture_cache_misses
	SSdogmos.prefetch_mixture_snapshots(test_mixtures)
	var/misses_after_prefetch = SSdogmos.dogmos_mixture_cache_misses
	if(misses_after_prefetch != misses_before)
		return Fail("Prefetch should not increment cache misses, but misses went from [misses_before] to [misses_after_prefetch].", __FILE__, __LINE__)

	for(var/datum/gas_mixture/mix as anything in test_mixtures)
		if(!mix.dogmos_slot)
			continue
		var/list/cached = SSdogmos.lookup_mixture_snapshot_cache(mix.dogmos_slot, mix.dogmos_generation)
		if(!cached)
			return Fail("Prefetch did not populate cache for slot [mix.dogmos_slot].", __FILE__, __LINE__)

	var/reads_misses_before = SSdogmos.dogmos_mixture_cache_misses
	for(var/datum/gas_mixture/mix as anything in test_mixtures)
		mix.return_pressure()
		mix.return_temperature()
	if(SSdogmos.dogmos_mixture_cache_misses != reads_misses_before)
		return Fail("Getters after prefetch caused [SSdogmos.dogmos_mixture_cache_misses - reads_misses_before] cache misses; expected zero.", __FILE__, __LINE__)

/** Verifies a prefetch spans the 381-record wire boundary without losing or duplicating snapshots. */
/datum/unit_test/dogmos_service_prefetch_chunking

/datum/unit_test/dogmos_service_prefetch_chunking/Run()
	var/list/datum/gas_mixture/mixtures = list()
	var/list/buckets = list()
	// Free mixture slots need not be contiguous. Select distinct direct-cache buckets
	// so this test measures batching rather than legitimate cache collisions.
	for(var/attempt in 1 to 4096)
		var/datum/gas_mixture/mixture = allocate(/datum/gas_mixture, CELL_VOLUME)
		var/bucket_key = "[SSdogmos.mixture_snapshot_cache_bucket(mixture.dogmos_slot)]"
		if(buckets[bucket_key])
			continue
		buckets[bucket_key] = TRUE
		mixtures += mixture
		mixture.set_moles(/datum/gas/oxygen, length(mixtures))
		if(length(mixtures) == 382)
			break
	if(length(mixtures) != 382)
		return Fail("Could not construct 382 non-colliding snapshot handles.", __FILE__, __LINE__)

	for(var/count in list(381, 382))
		var/list/request = list()
		for(var/index in 1 to count)
			// Duplicate producer references must not consume reply capacity or hide
			// the final unique handle behind the prefetch limit.
			request += mixtures[index]
			request += mixtures[index]
			request += mixtures[index]
		SSdogmos.reset_mixture_snapshot_cache()
		if(SSdogmos.prefetch_mixture_snapshots(request) != count)
			return Fail("Prefetch did not cache each unique requested handle exactly once.", __FILE__, __LINE__)
		for(var/index in 1 to count)
			var/datum/gas_mixture/mixture = mixtures[index]
			var/list/snapshot = SSdogmos.lookup_mixture_snapshot_cache(mixture.dogmos_slot, mixture.dogmos_generation)
			if(!islist(snapshot) || length(snapshot) != 42)
				return Fail("Prefetch omitted or truncated snapshot [index] at the batch boundary.", __FILE__, __LINE__)
			// Field 7 is total moles, independent of the production field macro.
			if(snapshot[7] != index)
				return Fail("Prefetch associated snapshot [index] with the wrong gas state.", __FILE__, __LINE__)
		if(SSdogmos.dogmos_mixture_cache_misses != 0)
			return Fail("Prefetch used singular snapshot reads.", __FILE__, __LINE__)

/datum/unit_test/dogmos_service_prefetch_chunking/Destroy()
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/datum/unit_test/dogmos_service_machinery_prefetch/Destroy()
	test_components.Cut()
	test_mixtures.Cut()
	SSdogmos.reset_mixture_snapshot_cache()
	return ..()

/// Measures native publications inside the two blocked-turf shuttle updates.
/turf/open/indestructible/plating/airless/dogmos_shuttle_probe
	/// Shared only for the synchronous test interval; contains numeric observations.
	var/static/list/dogmos_shuttle_samples

/turf/open/indestructible/plating/airless/dogmos_shuttle_probe/air_update_turf(update, remove)
	var/measuring = islist(dogmos_shuttle_samples) && blocks_air
	var/calls_before = SSdogmos.dogmos_runtime_topology_calls
	. = ..()
	if(measuring)
		dogmos_shuttle_samples += SSdogmos.dogmos_runtime_topology_calls - calls_before

/// Actual shuttle movement must publish a bounded batch and copy gas before its final signal.
/datum/unit_test/dogmos_shuttle_topology_batch
	/// Whether a surrounding operation owns publication throughout the move.
	var/outer_batch_owner = FALSE
	var/turf/open/moving_source
	var/turf/open/moving_destination
	var/list/adjacency_observations
	var/list/shuttle_observation

/datum/unit_test/dogmos_shuttle_topology_batch/outer_owner
	outer_batch_owner = TRUE

/datum/unit_test/dogmos_shuttle_topology_batch/proc/observe_adjacency(turf/source)
	SIGNAL_HANDLER
	adjacency_observations += list(list(moving_source.blocks_air, moving_destination.blocks_air, moving_source.air.get_moles(GAS_O2)))

/datum/unit_test/dogmos_shuttle_topology_batch/proc/observe_shuttle(turf/source, turf/open/destination)
	SIGNAL_HANDLER
	shuttle_observation = list(source.blocks_air, destination.blocks_air, destination.air.get_moles(GAS_O2), SSdogmos.runtime_topology_batching)

/datum/unit_test/dogmos_shuttle_topology_batch/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/original_batching = SSdogmos.runtime_topology_batching
	if(original_batching || SSdogmos.turf_registration_batching)
		return Fail("Shuttle fixture encountered another batch owner.", __FILE__, __LINE__)
	var/list/pair = allocate_turf_pair()
	var/list/restoration = list()
	for(var/turf/fixture_turf as anything in pair)
		restoration += list(list(fixture_turf.x, fixture_turf.y, fixture_turf.z, fixture_turf.type, islist(fixture_turf.baseturfs) ? fixture_turf.baseturfs.Copy() : fixture_turf.baseturfs))
	var/original_can_fire = SSair.can_fire
	SSair.can_fire = FALSE
	var/turf/open/indestructible/plating/airless/dogmos_shuttle_probe/probe
	var/list/measured_calls
	var/failure
	try
		moving_source = pair[1]
		moving_destination = pair[2]
		moving_source = moving_source.ChangeTurf(/turf/open/indestructible/plating/airless/dogmos_shuttle_probe)
		moving_destination = moving_destination.ChangeTurf(/turf/open/indestructible/plating/airless/dogmos_shuttle_probe)
		moving_source.baseturfs = list(/turf/open/space, /turf/baseturf_skipover/shuttle, moving_source.type)
		moving_source.air.clear()
		moving_source.air.set_moles(GAS_O2, 17)
		moving_destination.air.clear()
		moving_destination.air.set_moles(GAS_O2, 3)
		moving_source.air_update_turf(TRUE)
		moving_destination.air_update_turf(TRUE)
		if(!SSdogmos.flush_turf_registration_batch())
			CRASH("Shuttle fixture setup could not publish topology.")
		adjacency_observations = list()
		RegisterSignal(moving_source, COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, PROC_REF(observe_adjacency))
		RegisterSignal(moving_source, COMSIG_TURF_ON_SHUTTLE_MOVE, PROC_REF(observe_shuttle))
		probe = moving_source
		probe.dogmos_shuttle_samples = list()
		SSdogmos.runtime_topology_batching = outer_batch_owner
		if(!moving_source.onShuttleMove(moving_destination, list(), EAST, ignore_area_change = TRUE))
			CRASH("Shuttle fixture did not move its turf.")
		measured_calls = probe.dogmos_shuttle_samples
		probe.dogmos_shuttle_samples = null
		var/native_calls = 0
		for(var/call_count in measured_calls)
			native_calls += call_count
		if(length(measured_calls) != 2 || native_calls > 4)
			failure = "Two blocked shuttle updates published topology repeatedly ([length(measured_calls)] updates, [native_calls] native calls)."
		if(length(shuttle_observation) != 4 || !shuttle_observation[1] || !shuttle_observation[2] || shuttle_observation[3] != 17 || shuttle_observation[4] != outer_batch_owner)
			failure = "The shuttle signal did not see blocked turfs, copied gas and restored batch ownership."
		var/destination_blocked_index = 0
		var/both_blocked_index = 0
		var/observation_index = 0
		for(var/list/observation as anything in adjacency_observations)
			observation_index++
			if(observation[3] != 17)
				failure = "An intermediate adjacency callback read changed source gas."
			if(!destination_blocked_index && !observation[1] && observation[2])
				destination_blocked_index = observation_index
			if(!both_blocked_index && observation[1] && observation[2])
				both_blocked_index = observation_index
		if(!destination_blocked_index || !both_blocked_index || destination_blocked_index >= both_blocked_index)
			failure = "Shuttle movement did not preserve the ordered intermediate adjacency notifications."
		var/pending_topology = length(SSdogmos.dogmos_pending_adjacency_retry) + length(SSdogmos.dogmos_pending_turf_adjacency) + length(SSdogmos.dogmos_pending_turf_heat_adjacency)
		if(!outer_batch_owner && pending_topology)
			failure = "Shuttle movement retained topology after its final signal."
		if(outer_batch_owner && !pending_topology)
			failure = "Shuttle movement prematurely drained its outer owner's topology."
	catch(var/exception/error)
		failure = "Shuttle topology fixture raised [error]."
	if(probe)
		probe.dogmos_shuttle_samples = null
	if(moving_source)
		UnregisterSignal(moving_source, list(COMSIG_TURF_CALCULATED_ADJACENT_ATMOS, COMSIG_TURF_ON_SHUTTLE_MOVE))
	SSdogmos.runtime_topology_batching = original_batching
	file("[GLOB.log_directory]/dogmos-shuttle-topology.json") << json_encode(list("outer_owner" = outer_batch_owner, "calls_inside_updates" = measured_calls, "adjacency" = adjacency_observations, "shuttle" = shuttle_observation))
	moving_source = null
	moving_destination = null
	try
		if(!SSdogmos.flush_turf_registration_batch())
			return dogmos_abort_fixture("Shuttle cleanup could not reach the service.")
		for(var/list/saved_turf as anything in restoration)
			var/turf/current = locate(saved_turf[1], saved_turf[2], saved_turf[3])
			var/turf/restored = current.ChangeTurf(saved_turf[4])
			restored.baseturfs = saved_turf[5]
			if(!isopenturf(restored))
				return dogmos_abort_fixture("Shuttle cleanup did not restore an open floor.")
			restored.air_update_turf(TRUE, FALSE)
			if(saved_turf == restoration[1])
				run_loc_floor_bottom_left = restored
		if(!SSdogmos.flush_turf_registration_batch())
			return dogmos_abort_fixture("Shuttle cleanup could not publish restored topology.")
	catch(var/exception/cleanup_error)
		return dogmos_abort_fixture("Shuttle cleanup raised [cleanup_error].")
	// The normal test runner resets this room's gas and native temperature before Destroy().
	SSair.can_fire = original_can_fire
	if(failure)
		Fail(failure, __FILE__, __LINE__)

/// Counts identity reads only while a bounded topology fixture is measuring work.
/turf/open/indestructible/plating/airless/dogmos_topology_probe
	/// Whether identity lookups belong to the measured interval.
	var/dogmos_probe_enabled = FALSE
	/// Identity lookups made by the measured topology rebuilds.
	var/dogmos_probe_slot_reads = 0
	/// Test-only fault injected at the identity-read boundary, after fixture setup.
	var/dogmos_probe_throw = FALSE

/turf/open/indestructible/plating/airless/dogmos_topology_probe/dogmos_service_slot()
	if(dogmos_probe_throw)
		throw "dogmos batch exception sentinel"
	if(dogmos_probe_enabled)
		dogmos_probe_slot_reads++
	return ..()

/// Repeated notifications in one runtime batch must rebuild the final topology once.
/datum/unit_test/dogmos_runtime_topology_coalesces_notifications

/datum/unit_test/dogmos_runtime_topology_coalesces_notifications/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/original_can_fire = SSair.can_fire
	var/original_batching = SSdogmos.runtime_topology_batching
	if(original_batching || SSdogmos.turf_registration_batching)
		return Fail("Topology fixture encountered another batch owner.", __FILE__, __LINE__)
	var/original_type = run_loc_floor_bottom_left.type
	var/list/original_position = list(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	SSair.can_fire = FALSE
	var/turf/open/indestructible/plating/airless/dogmos_topology_probe/target
	var/calls_before = SSdogmos.dogmos_runtime_topology_calls
	var/failure_message
	var/slot_reads
	try
		target = run_loc_floor_bottom_left.ChangeTurf(/turf/open/indestructible/plating/airless/dogmos_topology_probe)
		target.immediate_calculate_adjacent_turfs()
		if(!SSdogmos.flush_turf_registration_batch())
			CRASH("Topology fixture setup could not reach the service.")
		target.air.set_moles(GAS_O2, 17)
		target.air.set_temperature(321)
		var/original_mixture_slot = target.air.dogmos_slot
		var/original_mixture_generation = target.air.dogmos_generation
		calls_before = SSdogmos.dogmos_runtime_topology_calls
		SSdogmos.runtime_topology_batching = TRUE
		target.dogmos_probe_enabled = TRUE
		for(var/repetition in 1 to 50)
			target.__update_auxtools_turf_adjacency_info(world.maxx, world.maxy)
		SSdogmos.runtime_topology_batching = original_batching
		if(!SSdogmos.flush_turf_registration_batch())
			failure_message = "The runtime batch failed to publish its final topology."
		slot_reads = target.dogmos_probe_slot_reads
		target.dogmos_probe_enabled = FALSE
		if(!failure_message && slot_reads > 4)
			failure_message = "Fifty notifications rebuilt the same turf repeatedly ([slot_reads] identity reads)."
		if(!failure_message && (target.air.dogmos_slot != original_mixture_slot || target.air.dogmos_generation != original_mixture_generation))
			failure_message = "Coalescing topology replaced the gas mixture identity."
		if(!failure_message && (target.air.get_moles(GAS_O2) != 17 || target.air.return_temperature() != 321))
			failure_message = "Coalescing topology changed gas state."
		if(!failure_message && (length(SSdogmos.dogmos_pending_adjacency_retry) || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat_adjacency)))
			failure_message = "The runtime batch retained pending topology after publication."
	catch(var/exception/error)
		failure_message = "Runtime topology fixture raised [error]."
	if(istype(target))
		target.dogmos_probe_enabled = FALSE
	SSdogmos.runtime_topology_batching = original_batching
	file("[GLOB.log_directory]/dogmos-runtime-topology-coalescing.json") << json_encode(list("notifications" = 50, "identity_reads" = slot_reads, "topology_calls" = SSdogmos.dogmos_runtime_topology_calls - calls_before))
	try
		if(!SSdogmos.flush_turf_registration_batch())
			return dogmos_abort_fixture("Runtime topology cleanup could not reach the service.")
		var/turf/current = locate(original_position[1], original_position[2], original_position[3])
		var/turf/restored = current.ChangeTurf(original_type)
		if(!isopenturf(restored))
			return dogmos_abort_fixture("Runtime topology cleanup could not restore the test floor.")
		run_loc_floor_bottom_left = restored
		if(!SSdogmos.flush_turf_registration_batch())
			return dogmos_abort_fixture("Restored test floor topology did not reach the service.")
	catch(var/exception/cleanup_error)
		return dogmos_abort_fixture("Runtime topology cleanup raised [cleanup_error.name].")
	// The normal low-priority test runner restores this room's numeric atmosphere next.
	SSair.can_fire = original_can_fire
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

/** Exceptions must release only the batching scope owned by the failing helper. */
/datum/unit_test/dogmos_topology_batch_exception_ownership/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/original_can_fire = SSair.can_fire
	var/original_batching = SSdogmos.runtime_topology_batching
	if(original_batching || SSdogmos.turf_registration_batching)
		return Fail("Exception fixture encountered another batch owner.", __FILE__, __LINE__)
	var/original_type = run_loc_floor_bottom_left.type
	var/list/position = list(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z)
	var/turf/open/indestructible/plating/airless/dogmos_topology_probe/target
	var/failure_message
	SSair.can_fire = FALSE
	try
		target = run_loc_floor_bottom_left.ChangeTurf(/turf/open/indestructible/plating/airless/dogmos_topology_probe)
		target.immediate_calculate_adjacent_turfs()
		if(!SSdogmos.flush_turf_registration_batch())
			CRASH("Exception fixture setup could not reach the service.")
		for(var/outer_owner in list(FALSE, TRUE))
			for(var/helper in list("template", "retry"))
				SSdogmos.runtime_topology_batching = outer_owner
				target.dogmos_probe_throw = TRUE
				var/caught_expected = FALSE
				try
					if(helper == "template")
						SSdogmos.update_template_border(list(target))
					else
						SSdogmos.dogmos_pending_adjacency_retry[target] = TRUE
						SSdogmos.retry_pending_turf_adjacencies()
				catch(var/helper_error)
					caught_expected = helper_error == "dogmos batch exception sentinel"
				target.dogmos_probe_throw = FALSE
				if(!caught_expected)
					failure_message = "The [helper] helper did not propagate the injected exception unchanged."
				else if(SSdogmos.runtime_topology_batching != outer_owner)
					failure_message = "The [helper] helper leaked batching ownership after an exception (outer owner [outer_owner])."
				SSdogmos.runtime_topology_batching = original_batching
				// Reconcile the faulted turf from current DM state before the next case.
				target.immediate_calculate_adjacent_turfs()
				if(!SSdogmos.flush_turf_registration_batch())
					CRASH("Exception fixture could not reconcile topology.")
	catch(var/exception/error)
		failure_message = "Exception ownership fixture raised [error]."
	if(istype(target))
		target.dogmos_probe_throw = FALSE
	SSdogmos.runtime_topology_batching = original_batching
	try
		var/turf/current = locate(position[1], position[2], position[3])
		var/turf/restored = current.ChangeTurf(original_type)
		if(!isopenturf(restored))
			return dogmos_abort_fixture("Exception cleanup could not restore the test floor.")
		run_loc_floor_bottom_left = restored
		restored.immediate_calculate_adjacent_turfs()
		if(!SSdogmos.flush_turf_registration_batch())
			return dogmos_abort_fixture("Exception cleanup could not publish restored topology.")
	catch(var/exception/cleanup_error)
		return dogmos_abort_fixture("Exception cleanup raised [cleanup_error].")
	SSair.can_fire = original_can_fire
	if(failure_message)
		return Fail(failure_message, __FILE__, __LINE__)

#undef DOGMOS_WORLD_GENERATION_WORD_MAX
#undef DOGMOS_TEST_STAGE_EXCITED_GROUPS
#undef DOGMOS_TEST_STAGE_EQUALIZE
#undef DOGMOS_TEST_STAGE_TURF_HEAT
#undef DOGMOS_TEST_STAGE_REACTIONS
#undef DOGMOS_TEST_OVERSIZED_PIPELINE_MIXTURES
#undef DOGMOS_TEST_STAGE_BOUNDARY_ATTEMPTS
#undef DOGMOS_TEST_STAGE_RESPONSE_FIELDS
#undef DOGMOS_TEST_STAGE_TURFS
#undef DOGMOS_PIPELINE_TEST_EPSILON
#undef DOGMOS_TEST_IDLE_MC_SETTLE_TIME
#undef DOGMOS_TEST_RESPONSE_APPLIED
#undef DOGMOS_TEST_SNAPSHOT_REVISION_LOW
#undef DOGMOS_TEST_SNAPSHOT_REVISION_HIGH

#endif

#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

#define DOGMOS_FAILURE_FENCE_STAGE 4

/** Fixed snapshots may retain a turf that no longer has open-turf fields. */
/datum/unit_test/dogmos_walk_prefetch_closed_turf/Run()
	var/turf/open/interior = run_loc_floor_bottom_left
	var/turf/boundary = get_step(interior, WEST)
	if(!interior.air || !boundary || isopenturf(boundary))
		return Fail("The stale-snapshot fixture needs an open interior and a closed room boundary.", __FILE__, __LINE__)
	var/list/original_neighbors = interior.atmos_adjacent_turfs
	var/failure
	try
		// Exercise both a stale snapshot entry and a stale neighbor reference.
		interior.atmos_adjacent_turfs = list(boundary)
		SSair.dogmos_prefetch_walk_snapshots(list(boundary, interior))
	catch(var/exception/error)
		failure = "Prefetch accessed open-turf fields on a closed snapshot entry: [error.name]."
	interior.atmos_adjacent_turfs = original_neighbors
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/datum/unit_test/dogmos_active_walk_failure_fence
	var/list/exposure_count
	var/failed_once = FALSE

/datum/unit_test/dogmos_active_walk_failure_fence/proc/fail_from_exposure(turf/source)
	SIGNAL_HANDLER
	exposure_count[source]++
	if(!failed_once)
		failed_once = TRUE
		SSair.dogmos_fail_closed_stage(DOGMOS_FAILURE_FENCE_STAGE, FALSE)

/datum/unit_test/dogmos_active_walk_failure_fence/proc/count_exposure(turf/source)
	SIGNAL_HANDLER
	exposure_count[source]++

/datum/unit_test/dogmos_active_walk_failure_fence/proc/frontier_matches(list/before, list/after)
	if(isnull(before) || isnull(after))
		return isnull(before) && isnull(after)
	if(!islist(after) || length(before) != length(after))
		return FALSE
	for(var/turf/fixture_turf in before)
		var/list/before_pair = before[fixture_turf]
		var/list/after_pair = after[fixture_turf]
		if(!islist(before_pair) || !islist(after_pair) || length(before_pair) != length(after_pair))
			return FALSE
		for(var/index in 1 to length(before_pair))
			if(before_pair[index] != after_pair[index])
				return FALSE
	return TRUE

/datum/unit_test/dogmos_active_walk_failure_fence/proc/frontier_copy(list/frontier)
	if(isnull(frontier))
		return null
	var/list/result = list()
	for(var/turf/fixture_turf in frontier)
		var/list/pair = frontier[fixture_turf]
		result[fixture_turf] = islist(pair) ? pair.Copy() : pair
	return result

/datum/unit_test/dogmos_active_walk_failure_fence/Run()
	if(!dogmos_wait_for_stage_boundary())
		return

	var/list/pair = allocate_turf_pair()
	if(!islist(pair) || length(pair) != 2)
		return Fail("The failure-fence fixture needs exactly two real turfs.", __FILE__, __LINE__)
	var/turf/open/first = pair[1]
	var/turf/open/second = pair[2]
	if(!istype(first) || !istype(second) || !first.air || !second.air)
		return Fail("The failure-fence fixture did not receive two live open turfs with gas.", __FILE__, __LINE__)
	if(!first.dogmos_air_registration_is_current() || !second.dogmos_air_registration_is_current())
		return Fail("The failure-fence fixture did not receive current native gas registrations.", __FILE__, __LINE__)

	var/list/saved_fields = list()
	for(var/field in list(
		"active_turfs", "currentrun", "state", "can_fire",
		"active_turfs_walk_cursor", "dogmos_visual_refresh_batch",
		"dogmos_visual_refresh_cursor", "dogmos_active_walk_complete",
		"dogmos_active_turf_stages_complete", "dogmos_equalize_stage_complete",
		"dogmos_fdm_steps_completed", "high_pressure_delta",
		"dogmos_pending_stage", "dogmos_pending_frontier_epoch",
		"dogmos_stage_remaining_estimate", "dogmos_stage_test_samples", "dogmos_resume_recovered_cycle",
		"dogmos_reacted_turfs", "dogmos_walk_prefetch_end", "dogmos_visual_prefetch_end"))
		saved_fields[field] = SSair.vars[field]

	// These are accepted native state. Save copies for comparison only; never restore them.
	var/list/saved_frontier_epoch = SSair.dogmos_frontier_epoch.Copy()
	var/list/saved_stage_epoch = islist(SSair.dogmos_stage_epoch) ? SSair.dogmos_stage_epoch.Copy() : null
	var/list/saved_committed_frontier = frontier_copy(SSair.dogmos_committed_frontier)
	var/list/saved_pending_frontier = islist(SSair.dogmos_pending_frontier_epoch) ? SSair.dogmos_pending_frontier_epoch.Copy() : null
	var/saved_pending_stage = SSair.dogmos_pending_stage
	if(saved_pending_stage || length(saved_pending_frontier))
		return dogmos_abort_fixture("The failure-fence fixture did not start at a native stage boundary.")

	var/saved_service_ready = SSdogmos.service_ready
	var/saved_failure_latched = SSdogmos.service_failure_latched
	var/saved_shutdown_requested = SSdogmos.service_shutdown_requested
	var/saved_pending_callback_count = SSdogmos.dogmos_pending_callback_count
	var/saved_stale_callback_count = SSdogmos.dogmos_stale_callback_count
	var/saved_tick_limit = Master.current_ticklimit
	var/list/saved_turf_state = list()
	for(var/turf/open/fixture_turf as anything in pair)
		saved_turf_state[fixture_turf] = list(
			fixture_turf.atmos_adjacent_turfs, fixture_turf.excited, fixture_turf.excited_group,
			fixture_turf.current_cycle, fixture_turf.archived_cycle,
			fixture_turf.pressure_difference, fixture_turf.pressure_direction)

	exposure_count = list()
	exposure_count[first] = 0
	exposure_count[second] = 0
	failed_once = FALSE
	var/first_signal_registered = FALSE
	var/second_signal_registered = FALSE
	var/failure
	var/restore_allowed = FALSE

	try
		RegisterSignal(first, COMSIG_TURF_EXPOSE, PROC_REF(fail_from_exposure))
		first_signal_registered = TRUE
		RegisterSignal(second, COMSIG_TURF_EXPOSE, PROC_REF(count_exposure))
		second_signal_registered = TRUE

		SSair.active_turfs = pair.Copy()
		SSair.currentrun = list()
		SSair.high_pressure_delta = list()
		SSair.active_turfs_walk_cursor = 0
		SSair.dogmos_visual_refresh_batch = pair.Copy()
		SSair.dogmos_visual_refresh_cursor = 0
		SSair.dogmos_active_walk_complete = FALSE
		SSair.dogmos_active_turf_stages_complete = FALSE
		SSair.dogmos_fdm_steps_completed = 0
		SSair.dogmos_stage_remaining_estimate = 0
		SSair.dogmos_stage_test_samples = list()
		for(var/turf/open/fixture_turf as anything in pair)
			fixture_turf.excited = TRUE
			fixture_turf.excited_group = null
			fixture_turf.archived_cycle = SSair.times_fired

		SSair.state = SS_RUNNING
		Master.current_ticklimit = TICK_USAGE + max(1, 100 / world.tick_lag)
		SSair.process_active_turfs(FALSE)

		if(!failed_once || exposure_count[first] != 1)
			failure = "COMSIG_TURF_EXPOSE did not fail closed exactly once on the first real turf."
		else if(exposure_count[second] != 0)
			failure = "The second real turf was exposed after the failure fence fired."
		else if(SSair.can_fire || SSdogmos.service_ready || !SSdogmos.service_failure_latched)
			failure = "The failure fence did not leave SSair and the service unavailable."
		else if(SSair.dogmos_active_walk_complete || SSair.dogmos_active_turf_stages_complete || SSair.dogmos_equalize_stage_complete || SSair.dogmos_fdm_steps_completed || length(SSair.dogmos_visual_refresh_batch) || SSair.active_turfs_walk_cursor || SSair.dogmos_visual_refresh_cursor || SSair.dogmos_walk_prefetch_end || SSair.dogmos_visual_prefetch_end)
			failure = "The failure fence left active-walk snapshot state usable after closing the service."
		else if(!isnull(SSair.dogmos_pending_stage) || !isnull(SSair.dogmos_pending_frontier_epoch))
			failure = "The failure fence left a native stage or frontier pending."
		else if(!SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, saved_frontier_epoch) || !SSdogmos.equal_u64_words(SSair.dogmos_stage_epoch, saved_stage_epoch))
			failure = "The failure callback changed an accepted native epoch before frontier publication."
		else if(!frontier_matches(saved_committed_frontier, SSair.dogmos_committed_frontier))
			failure = "The failure callback changed the committed native frontier before publication."
		else if(length(SSair.dogmos_stage_test_samples))
			failure = "A native stage ran after the exposure failure fence."
		else if(SSdogmos.dogmos_pending_callback_count != saved_pending_callback_count || SSdogmos.dogmos_stale_callback_count != saved_stale_callback_count)
			failure = "Callback bookkeeping changed after the failure fence."
	catch(var/exception/error)
		failure = "The failure-fence walk raised [error.name] after its snapshot was cleared."

	var/native_epochs_unchanged = SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, saved_frontier_epoch) \
		&& SSdogmos.equal_u64_words(SSair.dogmos_stage_epoch, saved_stage_epoch)
	var/committed_frontier_unchanged = frontier_matches(saved_committed_frontier, SSair.dogmos_committed_frontier)
	var/no_pending_native_state = isnull(SSair.dogmos_pending_stage) && isnull(SSair.dogmos_pending_frontier_epoch)
	// Assertion failures and a pure DM indexing exception can be reported after a safe
	// restore when every accepted native value and pending boundary stayed unchanged.
	// Pending state, epoch changes, and frontier changes cannot be repaired by restoring
	// DM variables without hiding an accepted native mutation.
	restore_allowed = native_epochs_unchanged && committed_frontier_unchanged && no_pending_native_state \
		&& !length(SSair.dogmos_stage_test_samples) \
		&& SSdogmos.dogmos_pending_callback_count == saved_pending_callback_count \
		&& SSdogmos.dogmos_stale_callback_count == saved_stale_callback_count

	if(first_signal_registered)
		UnregisterSignal(first, COMSIG_TURF_EXPOSE)
	if(second_signal_registered)
		UnregisterSignal(second, COMSIG_TURF_EXPOSE)

	// No sync/republish is needed: the test proves the accepted epochs and committed
	// frontier never changed. A changed epoch, committed frontier, or pending value is
	// an actual mutation and must remain failed closed rather than being hidden by restore.
	if(!restore_allowed)
		SSair.dogmos_fail_closed_stage("failure-fence unit test", FALSE)
	else
		for(var/field in saved_fields)
			SSair.vars[field] = saved_fields[field]
		SSdogmos.service_ready = saved_service_ready
		SSdogmos.service_failure_latched = saved_failure_latched
		SSdogmos.service_shutdown_requested = saved_shutdown_requested
		Master.current_ticklimit = saved_tick_limit
		SSair.can_fire = saved_fields["can_fire"]

	for(var/turf/open/fixture_turf as anything in pair)
		var/list/turf_state = saved_turf_state[fixture_turf]
		fixture_turf.atmos_adjacent_turfs = turf_state[1]
		fixture_turf.excited = turf_state[2]
		fixture_turf.excited_group = turf_state[3]
		fixture_turf.current_cycle = turf_state[4]
		fixture_turf.archived_cycle = turf_state[5]
		fixture_turf.pressure_difference = turf_state[6]
		fixture_turf.pressure_direction = turf_state[7]
	exposure_count = null

	if(!restore_allowed)
		return dogmos_abort_fixture("The failure-fence fixture could not prove a safe synchronous restoration.")
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

#undef DOGMOS_FAILURE_FENCE_STAGE

/// Counts cold reads caused by direct-cache aliases within each ordered 100-entry prefetch window.
/proc/dogmos_startup_prefetch_expected_misses(list/buckets)
	var/expected_misses = 0
	for(var/start = 1, start <= length(buckets), start += 100)
		var/list/bucket_counts = list()
		for(var/index in start to min(start + 99, length(buckets)))
			var/bucket = "[buckets[index]]"
			var/previous_count = bucket_counts[bucket] || 0
			bucket_counts[bucket] = previous_count + 1
			// Prefetch leaves the last alias resident. Reading the first alias evicts
			// it, so every distinct slot in a colliding bucket needs one cold read.
			if(previous_count == 1)
				expected_misses += 2
			else if(previous_count > 1)
				expected_misses++
	return expected_misses

/datum/unit_test/dogmos_startup_prefetch_collision_accounting

/datum/unit_test/dogmos_startup_prefetch_collision_accounting/Run()
	var/list/buckets = list()
	for(var/slot in 1 to 121)
		buckets += slot
	if(dogmos_startup_prefetch_expected_misses(buckets) != 0)
		return Fail("Unique buckets must stay warm.", __FILE__, __LINE__)
	buckets[2] = 1
	if(dogmos_startup_prefetch_expected_misses(buckets) != 2)
		return Fail("Both slots in a colliding bucket must miss.", __FILE__, __LINE__)
	buckets[3] = 1
	if(dogmos_startup_prefetch_expected_misses(buckets) != 3)
		return Fail("Every distinct alias must miss.", __FILE__, __LINE__)
	buckets[102] = buckets[101]
	if(dogmos_startup_prefetch_expected_misses(buckets) != 5)
		return Fail("Tail-window collisions must also count.", __FILE__, __LINE__)
	for(var/index in 1 to 121)
		buckets[index] = index
	buckets[101] = buckets[100]
	if(dogmos_startup_prefetch_expected_misses(buckets) != 0)
		return Fail("Aliases across separate prefetch windows must stay warm.", __FILE__, __LINE__)

/datum/unit_test/dogmos_startup_own_prefetch_regression

/// Captures one real turf without reading neighboring mixtures.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/capture_turf_state(turf/open/target, save_air_copy = FALSE)
	var/list/result = list()
	var/list/air_snapshot = target.air.dogmos_snapshot()
	result["air"] = air_snapshot?.Copy()
	if(save_air_copy)
		var/datum/gas_mixture/air_copy = target.air.copy()
		allocated += air_copy
		result["air_copy"] = air_copy
	result["visuals"] = target.atmos_overlay_types?.Copy()
	result["adjacency"] = target.atmos_adjacent_turfs?.Copy()
	result["excited"] = target.excited
	result["current_cycle"] = target.current_cycle
	result["archived_cycle"] = target.archived_cycle
	result["reaction_results"] = target.air.reaction_results?.Copy()
	return result

/// Compares ordered visual and difference-check lists by identity.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/list_matches(list/left, list/right)
	if(isnull(left) || isnull(right))
		return isnull(left) && isnull(right)
	if(length(left) != length(right))
		return FALSE
	for(var/index in 1 to length(left))
		if(left[index] != right[index])
			return FALSE
	return TRUE

/// Compares physical gas fields while excluding the first two revision words.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/air_matches(list/left, list/right)
	if(isnull(left) || isnull(right))
		return isnull(left) && isnull(right)
	if(length(left) < 3 || length(left) != length(right))
		return FALSE
	for(var/index in 3 to length(left))
		if(left[index] != right[index])
			return FALSE
	return TRUE

/// Compares keyed reaction bookkeeping without depending on list identity.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/associative_lists_match(list/left, list/right)
	if(isnull(left) || isnull(right))
		return isnull(left) && isnull(right)
	if(length(left) != length(right))
		return FALSE
	for(var/key in left)
		if(right[key] != left[key])
			return FALSE
	return TRUE

/// Compares reciprocal adjacency maps and their edge flags.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/adjacency_matches(list/left, list/right)
	if(isnull(left) || isnull(right))
		return isnull(left) && isnull(right)
	if(length(left) != length(right))
		return FALSE
	for(var/turf/neighbor as anything in left)
		if(right[neighbor] != left[neighbor])
			return FALSE
	return TRUE

/// Captures the ordered fixture state for control/candidate parity or restoration.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/capture_states(list/turfs, save_air_copy = FALSE)
	var/list/result = list()
	for(var/turf/open/target as anything in turfs)
		result[target] = capture_turf_state(target, save_air_copy)
	return result

/// Restores only owned real turfs from registered gas copies.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/restore_turfs(list/turfs, list/states)
	for(var/turf/open/target as anything in turfs)
		var/list/saved = states[target]
		var/datum/gas_mixture/saved_air = saved["air_copy"]
		if(!saved_air)
			return FALSE
		target.air.copy_from(saved_air)
		var/list/reaction_results = saved["reaction_results"]
		var/list/visuals = saved["visuals"]
		var/list/adjacency = saved["adjacency"]
		target.air.reaction_results = reaction_results?.Copy()
		target.apply_visual_overlays(visuals?.Copy())
		target.atmos_adjacent_turfs = adjacency?.Copy()
		target.excited = saved["excited"]
		target.current_cycle = saved["current_cycle"]
		target.archived_cycle = saved["archived_cycle"]
	return TRUE

/// Runs the existing setup ordering without any startup prefetch.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/run_control(list/turfs)
	var/list/difference_check = list()
	var/time = -1
	SSdogmos.begin_turf_registration_batch()
	for(var/turf/open/target as anything in turfs)
		target.Initalize_Atmos(time)
		difference_check += target
		if(CHECK_TICK)
			time--
	SSdogmos.finish_turf_registration_batch()
	return list(time, difference_check)

/// Runs the proposed own-mixture helper in the exact 100+21 windows.
/datum/unit_test/dogmos_startup_own_prefetch_regression/proc/run_candidate(list/turfs)
	var/list/difference_check = list()
	var/time = -1
	var/has_helper = hascall(SSair, "dogmos_initialize_turf_batch")
	SSdogmos.begin_turf_registration_batch()
	for(var/start in list(1, 101))
		var/end = min(start + 99, length(turfs))
		var/list/batch = turfs.Copy(start, end + 1)
		if(has_helper)
			var/result = call(SSair, "dogmos_initialize_turf_batch")(batch, difference_check, time)
			if(!isnum(result))
				return list(null, difference_check, FALSE, "The startup helper returned a nonnumeric time.")
			time = result
		else
			// Intentional RED fallback: it exercises the old actual path so the artifact
			// remains useful before the helper is inserted, but cannot claim a cache win.
			for(var/turf/open/target as anything in batch)
				target.Initalize_Atmos(time)
				difference_check += target
				if(CHECK_TICK)
					time--
	SSdogmos.finish_turf_registration_batch()
	return list(time, difference_check, has_helper, null)

/datum/unit_test/dogmos_startup_own_prefetch_regression/Run()
	var/datum/turf_reservation/fixture = SSmapping.request_turf_block_reservation(11, 11, turf_type_override = /turf/open/floor/plating/airless)
	if(!fixture)
		return Fail("Could not reserve the 121-turf startup prefetch fixture.", __FILE__, __LINE__)
	allocated += fixture
	for(var/turf/open/fixture_turf as anything in fixture.reserved_turfs)
		fixture_turf.immediate_calculate_adjacent_turfs()
	// Reservation itself queues native lifecycle/topology work; only now is the
	// boundary meaningful.
	var/adjacency_deadline = world.time + 180 SECONDS
	while(length(SSair.adjacent_rebuild) && world.time < adjacency_deadline)
		sleep(SSair.wait)
	if(length(SSair.adjacent_rebuild))
		return dogmos_abort_fixture("Startup fixture adjacency did not drain within three simulated minutes: [length(SSair.adjacent_rebuild)] turfs remain.")
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/turfs = fixture.reserved_turfs.Copy()
	if(length(turfs) != 121)
		return Fail("The startup prefetch fixture needs 121 reserved turfs.", __FILE__, __LINE__)
	for(var/turf/open/target as anything in turfs)
		if(!istype(target) || !target.air || !target.dogmos_air_registration_is_current())
			return Fail("The startup prefetch fixture contains an unregistered or non-open turf.", __FILE__, __LINE__)

	var/turf/open/boundary_left
	var/turf/open/boundary_right
	for(var/turf/open/left as anything in turfs)
		for(var/turf/open/right as anything in left.atmos_adjacent_turfs)
			if((right in turfs) && (left in right.atmos_adjacent_turfs))
				boundary_left = left
				boundary_right = right
				break
		if(boundary_left)
			break
	if(!boundary_left)
		return Fail("The startup prefetch fixture has no reciprocal real-turf boundary pair.", __FILE__, __LINE__)
	var/list/reordered_turfs = list()
	for(var/turf/open/target as anything in turfs)
		if(target != boundary_left && target != boundary_right)
			reordered_turfs += target
	reordered_turfs.Insert(100, boundary_left)
	reordered_turfs.Insert(101, boundary_right)
	turfs = reordered_turfs
	var/list/unique_turfs = list()
	for(var/turf/open/target as anything in turfs)
		if(unique_turfs[target])
			return Fail("The startup prefetch fixture reordered a turf more than once.", __FILE__, __LINE__)
		unique_turfs[target] = TRUE
	if(length(turfs) != 121 || length(unique_turfs) != 121)
		return Fail("The startup prefetch fixture lost a turf while placing its boundary pair.", __FILE__, __LINE__)
	if(!(boundary_left in boundary_right.atmos_adjacent_turfs) || !(boundary_right in boundary_left.atmos_adjacent_turfs))
		return Fail("The startup prefetch fixture did not place a reciprocal pair across the 100-entry boundary.", __FILE__, __LINE__)
	var/list/fixture_slots = list()
	var/list/fixture_generations = list()
	var/list/fixture_buckets = list()
	for(var/turf/open/target as anything in turfs)
		if(target.air.dogmos_slot in fixture_slots)
			return Fail("The startup prefetch fixture needs distinct live mixture slots.", __FILE__, __LINE__)
		fixture_slots += target.air.dogmos_slot
		fixture_generations += target.air.dogmos_generation
		fixture_buckets += SSdogmos.mixture_snapshot_cache_bucket(target.air.dogmos_slot)
	var/expected_candidate_misses = dogmos_startup_prefetch_expected_misses(fixture_buckets)

	var/list/saved_air_fields = list()
	for(var/field in list("active_turfs", "currentrun", "state", "can_fire", "times_fired", "dogmos_pending_stage", "dogmos_pending_frontier_epoch"))
		saved_air_fields[field] = SSair.vars[field]
	var/list/saved_frontier_epoch = SSair.dogmos_frontier_epoch.Copy()
	var/list/saved_stage_epoch = SSair.dogmos_stage_epoch.Copy()
	var/saved_pending_callbacks = SSdogmos.dogmos_pending_callback_count
	var/saved_stale_callbacks = SSdogmos.dogmos_stale_callback_count
	var/saved_tick_limit = Master.current_ticklimit
	var/saved_batching = SSdogmos.turf_registration_batching
	var/list/initial_states = capture_states(turfs, TRUE)
	var/list/seeded_states
	var/failure
	var/helper_used = FALSE
	var/control_misses = 0
	var/candidate_misses = 0
	var/control_hits = 0
	var/candidate_hits = 0
	var/control_topology_calls = 0
	var/candidate_topology_calls = 0
	var/list/control_result
	var/list/candidate_result

	try
		if(SSdogmos.turf_registration_batching || length(SSdogmos.dogmos_pending_turf_lifecycle) || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat) || length(SSdogmos.dogmos_pending_turf_heat_adjacency))
			return dogmos_abort_fixture("The startup prefetch fixture did not start with an empty registration batch.")
		SSair.can_fire = FALSE
		// Keep the bounded 121-turf counter measurement synchronous: unrelated subsystem
		// cache reads during CHECK_TICK would otherwise contaminate these deltas.
		Master.current_ticklimit = INFINITY
		for(var/index in 1 to length(turfs))
			var/turf/open/target = turfs[index]
			target.air.set_moles(/datum/gas/oxygen, 0)
			target.air.set_moles(/datum/gas/plasma, (index % 2) ? max(1, MOLES_GAS_VISIBLE * 2) : max(0.01, MOLES_GAS_VISIBLE * 0.25))
			target.air.set_temperature(T20C)
		seeded_states = capture_states(turfs, TRUE)

		SSdogmos.reset_mixture_snapshot_cache()
		var/control_misses_before = SSdogmos.dogmos_mixture_cache_misses
		var/control_hits_before = SSdogmos.dogmos_mixture_cache_hits
		var/control_topology_before = SSdogmos.dogmos_runtime_topology_calls
		control_result = run_control(turfs)
		control_misses = SSdogmos.dogmos_mixture_cache_misses - control_misses_before
		control_hits = SSdogmos.dogmos_mixture_cache_hits - control_hits_before
		control_topology_calls = SSdogmos.dogmos_runtime_topology_calls - control_topology_before
		var/list/control_states = capture_states(turfs)
		if(!restore_turfs(turfs, seeded_states))
			failure = "The startup prefetch control path could not restore its fixture state."

		if(!failure)
			SSdogmos.reset_mixture_snapshot_cache()
			var/candidate_misses_before = SSdogmos.dogmos_mixture_cache_misses
			var/candidate_hits_before = SSdogmos.dogmos_mixture_cache_hits
			var/candidate_topology_before = SSdogmos.dogmos_runtime_topology_calls
			candidate_result = run_candidate(turfs)
			if(!candidate_result || !isnum(candidate_result[1]))
				failure = candidate_result?[4] || "The startup prefetch candidate did not return a valid time."
			else
				helper_used = candidate_result[3]
				candidate_misses = SSdogmos.dogmos_mixture_cache_misses - candidate_misses_before
				candidate_hits = SSdogmos.dogmos_mixture_cache_hits - candidate_hits_before
				candidate_topology_calls = SSdogmos.dogmos_runtime_topology_calls - candidate_topology_before
				var/list/candidate_states = capture_states(turfs)
				if(length(control_result[2]) != length(candidate_result[2]))
					failure = "Control and candidate initialization returned different turf order lengths."
				else
					var/control_previous_cycle
					var/candidate_previous_cycle
					for(var/index in 1 to length(turfs))
						if(control_result[2][index] != turfs[index] || candidate_result[2][index] != turfs[index] || control_result[2][index] != candidate_result[2][index])
							failure = "Candidate initialization changed difference-check order at [index]."
							break
						var/list/control_state = control_states[turfs[index]]
						var/list/candidate_state = candidate_states[turfs[index]]
						var/control_cycle = control_state["current_cycle"]
						var/candidate_cycle = candidate_state["current_cycle"]
						if(!air_matches(control_state["air"], candidate_state["air"]) || !list_matches(control_state["visuals"], candidate_state["visuals"]) || !adjacency_matches(control_state["adjacency"], candidate_state["adjacency"]) || !associative_lists_match(control_state["reaction_results"], candidate_state["reaction_results"]) || control_state["excited"] != candidate_state["excited"] || control_state["archived_cycle"] != candidate_state["archived_cycle"] || !isnum(control_cycle) || !isnum(candidate_cycle) || control_cycle > -1 || candidate_cycle > -1 || (!isnull(control_previous_cycle) && control_cycle > control_previous_cycle) || (!isnull(candidate_previous_cycle) && candidate_cycle > candidate_previous_cycle))
							failure = "Candidate initialization changed gas, visual, or adjacency state at [index]."
							break
						control_previous_cycle = control_cycle
						candidate_previous_cycle = candidate_cycle
				if(!failure && (!helper_used || candidate_misses >= control_misses))
					failure = "Own-mixture startup prefetch did not reduce cold misses: control [control_misses], candidate [candidate_misses], helper [helper_used]."
				if(!failure && candidate_hits + candidate_misses != control_hits + control_misses)
					failure = "Startup prefetch changed the total number of snapshot reads."
				if(!failure && (candidate_misses != expected_candidate_misses || control_misses != length(turfs)))
					failure = "Startup cache misses differ from the fixture's bucket aliases: control [control_misses] (expected [length(turfs)]), candidate [candidate_misses] (expected [expected_candidate_misses])."
		if(!failure && (!SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, saved_frontier_epoch) || !SSdogmos.equal_u64_words(SSair.dogmos_stage_epoch, saved_stage_epoch) || SSdogmos.dogmos_pending_callback_count != saved_pending_callbacks || SSdogmos.dogmos_stale_callback_count != saved_stale_callbacks || SSair.dogmos_pending_stage || SSair.dogmos_pending_frontier_epoch))
			failure = "Initialization changed native stage, frontier epoch, or callback state."
	catch(var/exception/error)
		failure = "The startup prefetch fixture raised [error.name]."

	var/list/counter_report = list(
		"fixture_turfs" = length(turfs),
		"boundary_index" = 100,
		"control_misses" = control_misses,
		"candidate_misses" = candidate_misses,
		"expected_candidate_misses" = expected_candidate_misses,
		"fixture_slots" = fixture_slots,
		"fixture_generations" = fixture_generations,
		"fixture_buckets" = fixture_buckets,
		"control_hits" = control_hits,
		"candidate_hits" = candidate_hits,
		"control_topology_calls" = control_topology_calls,
		"candidate_topology_calls" = candidate_topology_calls,
		"helper_used" = helper_used)
	if(failure)
		counter_report["failure"] = failure
	file("[GLOB.log_directory]/dogmos-startup-own-prefetch.json") << json_encode(counter_report)

	if(SSdogmos.turf_registration_batching || length(SSdogmos.dogmos_pending_turf_lifecycle) || length(SSdogmos.dogmos_pending_turf_adjacency) || length(SSdogmos.dogmos_pending_turf_heat) || length(SSdogmos.dogmos_pending_turf_heat_adjacency))
		return dogmos_abort_fixture("The startup prefetch fixture left a registration batch pending after an initialization path.")
	if(!restore_turfs(turfs, initial_states))
		return dogmos_abort_fixture("The startup prefetch fixture could not restore its reserved turf state.")
	if(SSair.dogmos_pending_stage || SSair.dogmos_pending_frontier_epoch || !SSdogmos.equal_u64_words(SSair.dogmos_frontier_epoch, saved_frontier_epoch) || !SSdogmos.equal_u64_words(SSair.dogmos_stage_epoch, saved_stage_epoch))
		return dogmos_abort_fixture("The startup prefetch fixture changed accepted native state during restoration.")
	SSdogmos.reset_mixture_snapshot_cache()
	for(var/field in saved_air_fields)
		SSair.vars[field] = saved_air_fields[field]
	Master.current_ticklimit = saved_tick_limit
	SSdogmos.turf_registration_batching = saved_batching
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Registration must not allocate a reverse weak reference before any callback needs it. */
/datum/unit_test/dogmos_mixture_registration_without_weakref

/datum/unit_test/dogmos_mixture_registration_without_weakref/Run()
	var/datum/gas_mixture/mixture = new(CELL_VOLUME)
	var/allocated_weakref = !isnull(mixture.weak_reference)
	qdel(mixture)
	if(allocated_weakref)
		return Fail("Mixture registration allocated an eager reverse weak reference.", __FILE__, __LINE__)

/** Returns an ownership token after dropping the only reference to its mixture. */
/datum/unit_test/dogmos_identity_token_gc/proc/drop_temporary_mixture()
	var/datum/gas_mixture/temporary = new(CELL_VOLUME)
	var/list/result = list(temporary.dogmos_slot, temporary.dogmos_generation, temporary.dogmos_identity_token)
	temporary = null
	return result

/** Token retention must not prevent ordinary BYOND collection and native unregistration. */
/datum/unit_test/dogmos_identity_token_gc

/datum/unit_test/dogmos_identity_token_gc/Run()
	if(!dogmos_wait_for_stage_boundary())
		return
	var/list/identity = drop_temporary_mixture()
	var/slot = identity[1]
	if(!islist(identity[3]) || length(identity[3]))
		return Fail("Registration did not create an opaque empty ownership token.", __FILE__, __LINE__)
	if(!isnull(SSdogmos.dogmos_mixture_slots[slot]) || !(slot in SSdogmos.dogmos_free_mixture_slots))
		return Fail("The retained ownership token prevented mixture GC and native unregistration.", __FILE__, __LINE__)
	var/datum/gas_mixture/reused = new(CELL_VOLUME)
	var/failure
	if(reused.dogmos_slot != slot || reused.dogmos_generation != identity[2] + 1 || reused.dogmos_identity_token == identity[3])
		failure = "Collected mixture reuse did not advance generation and replace its ownership token."
	qdel(reused)
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Matching numeric handles cannot impersonate a different mixture's ownership token. */
/datum/unit_test/dogmos_identity_token_foreign

/datum/unit_test/dogmos_identity_token_foreign/Run()
	var/datum/gas_mixture/first = new(CELL_VOLUME)
	var/datum/gas_mixture/second = new(CELL_VOLUME / 2)
	var/second_slot = second.dogmos_slot
	var/second_generation = second.dogmos_generation
	var/failure
	try
		if(!SSdogmos.mixture_identity_matches(first, first.dogmos_slot, first.dogmos_generation) || second.return_volume() != CELL_VOLUME / 2)
			failure = "Registration changed live identity or non-default volume initialization."
		second.dogmos_slot = first.dogmos_slot
		second.dogmos_generation = first.dogmos_generation
		if(SSdogmos.mixture_identity_matches(second, first.dogmos_slot, first.dogmos_generation))
			failure = "A foreign token impersonated a registered mixture."
		if(SSdogmos.mixture_identity_matches(first, first.dogmos_slot, first.dogmos_generation + 1) || SSdogmos.mixture_identity_matches(first, 0, 0) || SSdogmos.mixture_identity_matches(first, length(SSdogmos.dogmos_mixture_slots) + 1, 1))
			failure = "An invalid slot or stale generation passed mixture validation."
	catch(var/exception/error)
		failure = "Identity validation raised [error.name]."
	second.dogmos_slot = second_slot
	second.dogmos_generation = second_generation
	qdel(first)
	qdel(second)
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Encodes only identity fields consumed by the real general-reaction decoder. */
/datum/unit_test/dogmos_identity_token_turf_context/proc/encode_subject(datum/gas_mixture/mixture, turf/target)
	var/list/batch = new/list(48)
	// Event offset 13; subject slot/generation at +11/+13, target at +15/+17.
	var/list/handles = list(mixture.dogmos_slot, mixture.dogmos_generation, target.dogmos_service_slot(), target.dogmos_registration_generation)
	for(var/index in 1 to 4)
		var/field = 24 + (index - 1) * 2
		batch[field] = handles[index] % 65536
		batch[field + 1] = floor(handles[index] / 65536)
	return batch

/** General callbacks must resolve the exact turf and its current mixture together. */
/datum/unit_test/dogmos_identity_token_turf_context

/datum/unit_test/dogmos_identity_token_turf_context/Run()
	var/turf/open/target = run_loc_floor_bottom_left
	var/datum/gas_mixture/original = target.air
	var/datum/gas_mixture/replacement = new(CELL_VOLUME)
	var/list/callback = encode_subject(original, target)
	var/failure
	try
		var/list/live = SSdogmos.decode_general_reaction_subject(callback, 13)
		if(live[1] != original)
			failure = "The callback decoder rejected the current turf and mixture."
		callback[30]++ // Stale target generation, leaving the live mixture handle unchanged.
		var/list/stale_target = SSdogmos.decode_general_reaction_subject(callback, 13)
		if(stale_target[1])
			failure = "The callback decoder accepted a stale turf generation."
		callback[30]--
		target.air = replacement
		var/list/changed_air = SSdogmos.decode_general_reaction_subject(callback, 13)
		if(changed_air[1])
			failure = "The callback decoder accepted air no longer owned by its target turf."
	catch(var/exception/error)
		failure = "The callback identity decoder raised [error.name]."
	target.air = original
	qdel(replacement)
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

#endif
