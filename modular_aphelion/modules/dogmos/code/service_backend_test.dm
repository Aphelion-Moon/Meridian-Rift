#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

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
	var/datum/gas_mixture/mixture = new(CELL_VOLUME)
	var/list/callback = new/list(48)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD] = mixture.dogmos_slot % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_SLOT_FIELD + 1] = floor(mixture.dogmos_slot / 65536)
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD] = mixture.dogmos_generation % 65536
	callback[DOGMOS_TEST_REACTION_EVENT_OFFSET + DOGMOS_TEST_REACTION_SUBJECT_GENERATION_FIELD + 1] = floor(mixture.dogmos_generation / 65536)
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
	qdel(mixture)
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
	if(mixture_changed)
		return Fail("Dogmos mutated mixture registration after the service failure latch was set.", __FILE__, __LINE__)
	if(turf_changed)
		return Fail("Dogmos queued a turf lifecycle mutation after the service failure latch was set.", __FILE__, __LINE__)

/** Verifies rejected mixture registration fails closed without publishing an invalid identity. */
/datum/unit_test/dogmos_service_rejected_mixture_registration_fails_closed

/datum/unit_test/dogmos_service_rejected_mixture_registration_fails_closed/Run()
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	var/original_can_fire = SSair.can_fire
	var/original_pending_stage = SSair.dogmos_pending_stage
	var/list/original_pending_frontier = SSair.dogmos_pending_frontier_epoch
	var/original_remaining_estimate = SSair.dogmos_stage_remaining_estimate
	var/original_active_complete = SSair.dogmos_active_turf_stages_complete
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
	SSair.dogmos_fdm_steps_completed = original_fdm_steps
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
	var/original_fdm_steps_completed = SSair.dogmos_fdm_steps_completed
	var/original_can_fire = SSair.can_fire
	var/original_service_ready = SSdogmos.service_ready
	var/original_failure_latched = SSdogmos.service_failure_latched
	SSair.dogmos_pending_stage = DOGMOS_TEST_STAGE_REACTIONS
	SSair.dogmos_pending_frontier_epoch = list(1, 0, 0, 0)
	SSair.dogmos_stage_remaining_estimate = 77
	SSair.dogmos_active_turf_stages_complete = TRUE
	SSair.dogmos_fdm_steps_completed = 3
	var/failure_pending = SSair.dogmos_fail_closed_stage(DOGMOS_TEST_STAGE_REACTIONS, FALSE)
	var/failure_message
	if(!failure_pending)
		failure_message = "Dogmos did not pause SSair after an irrecoverable stage response."
	else if(!isnull(SSair.dogmos_pending_stage) || !isnull(SSair.dogmos_pending_frontier_epoch))
		failure_message = "Dogmos retained failed stage state for another retry."
	else if(SSair.dogmos_stage_remaining_estimate || SSair.dogmos_active_turf_stages_complete || SSair.dogmos_fdm_steps_completed)
		failure_message = "Dogmos retained failed-cycle progress after the stage failure."
	else if(SSair.can_fire || SSdogmos.service_ready || !SSdogmos.service_failure_latched)
		failure_message = "Dogmos did not fail closed after the stage failure."

	SSair.dogmos_pending_stage = original_pending_stage
	SSair.dogmos_pending_frontier_epoch = original_pending_frontier
	SSair.dogmos_stage_remaining_estimate = original_remaining_estimate
	SSair.dogmos_active_turf_stages_complete = original_active_stages_complete
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
