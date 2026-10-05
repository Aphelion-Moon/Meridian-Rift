#ifdef UNIT_TESTS
/** Exercises the independent profile reference and actual registration choice. */
/datum/unit_test/dogmos_mixture_fusion_profile

/datum/unit_test/dogmos_mixture_fusion_profile/Run()
	TEST_ASSERT_EQUAL(dogmos_fusion_modulo(-1, 4), 3, "Negative toroidal coordinates must wrap positively.")
	var/datum/gas_mixture/air = allocate(/datum/gas_mixture, 2500)
	air.set_moles(/datum/gas/plasma, 500)
	air.set_moles(/datum/gas/carbon_dioxide, 500)
	air.set_moles(/datum/gas/tritium, 10)
	air.set_temperature(DOGMOS_FUSION_MIN_TEMPERATURE)
	var/list/result = air.dogmos_fusion_reference()
	TEST_ASSERT(islist(result), "Profile reference must produce a valid candidate.")
	TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), 10, "Reference mutated its source.")
	var/datum/gas_mixture/proposed = result["mixture"]
	TEST_ASSERT_EQUAL(proposed.get_moles(/datum/gas/tritium), 9, "Reference fuel accounting differs from profile.")
	TEST_ASSERT(dogmos_fusion_finite(proposed.return_temperature()), "Reference temperature must be finite.")
	qdel(proposed)
	air.set_temperature(DOGMOS_FUSION_MIN_TEMPERATURE - 1)
	TEST_ASSERT(isnull(air.dogmos_fusion_reference()), "Below-threshold mixture must not react.")
	var/registered = FALSE
	for(var/datum/gas_reaction/reaction as anything in SSair.dogmos_reactions)
		if(reaction.id == "meridian_fusion")
			registered = TRUE
	log_test("Mixture fusion startup selection: enabled=[SSdogmos.mixture_fusion_enabled], registered=[registered].")
	log_test("Loaded Dogmos capabilities: [dogmos_in_process_capabilities()]")
	TEST_ASSERT_EQUAL(registered, SSdogmos.mixture_fusion_enabled, "Fusion registration must follow startup configuration.")
	air.dogmos_fusion_excluded = TRUE
	TEST_ASSERT(!air.dogmos_fusion_admit(null), "HFR exclusion or missing ownership must reject admission.")

/** Bridge fixture: record acknowledged completion without irradiating the shared test map. */
/datum/gas_mixture/dogmos_fusion_fixture
	var/completions = 0

/datum/gas_mixture/dogmos_fusion_fixture/dogmos_fusion_finish(datum/holder, instability, energy_delta, temperature)
	if(!dogmos_fusion_location(holder))
		return FALSE
	completions++
	reaction_results[/datum/gas_reaction/standard/meridian_fusion] = instability
	dogmos_fusion_last_completion = world.time
	dogmos_fusion_instability = instability
	return TRUE

/** Isolate one registered reaction; exercise its actual native dispatch and DM admission. */
/datum/unit_test/dogmos_mixture_fusion_bridge
	var/list/original_registry
	var/original_enabled
	var/registry_replaced = FALSE

/datum/unit_test/dogmos_mixture_fusion_bridge/Run()
	original_registry = SSair.dogmos_reactions
	original_enabled = SSdogmos.mixture_fusion_enabled
	SSdogmos.mixture_fusion_enabled = TRUE
	var/datum/gas_reaction/standard/meridian_fusion/reaction = allocate(/datum/gas_reaction/standard/meridian_fusion)
	var/list/groups = list()
	groups[/datum/gas/plasma] = list(list(reaction), list(), list(), list())
	SSair.dogmos_reactions = init_dogmos_reactions(groups)
	registry_replaced = TRUE
	SSair.auxtools_update_reactions()
	var/registered_refcount = refcount(reaction)
	SSair.auxtools_update_reactions()
	SSair.auxtools_update_reactions()
	TEST_ASSERT_EQUAL(refcount(reaction), registered_refcount, "Replacing an identical native registry retained extra reaction references.")
	var/obj/item/tank/owner = allocate(/obj/item/tank)
	QDEL_NULL(owner.air_contents)
	var/list/seeds = list(list(500, 500, 10, 10000), list(750, 450, 20, 50000), list(300, 600, 5, 100000))
	for(var/list/seed as anything in seeds)
		var/datum/gas_mixture/dogmos_fusion_fixture/air = allocate(/datum/gas_mixture/dogmos_fusion_fixture, 2500)
		owner.air_contents = air
		air.set_moles(/datum/gas/plasma, seed[1])
		air.set_moles(/datum/gas/carbon_dioxide, seed[2])
		air.set_moles(/datum/gas/tritium, seed[3])
		air.set_temperature(seed[4])
		TEST_ASSERT(!air.react(null), "An unowned scratch mixture must not execute fusion.")
		TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), seed[3], "Rejected owner consumed fuel.")
		air.set_moles(/datum/gas/hypernoblium, REACTION_OPPRESSION_THRESHOLD)
		TEST_ASSERT_EQUAL(air.react(owner), STOP_REACTIONS, "Hypernoblium must stop the reaction chain.")
		TEST_ASSERT_EQUAL(air.completions, 0, "Suppression emitted completion.")
		air.set_moles(/datum/gas/hypernoblium, 0)
		var/list/rows = air.dogmos_explain_reactions()
		TEST_ASSERT_EQUAL(length(rows), 1, "Isolated registry must contain exactly fusion.")
		var/list/row = rows[1]
		TEST_ASSERT_EQUAL(row[1], "meridian_fusion", "Unexpected registered reaction.")
		TEST_ASSERT_EQUAL(row[2], "native", "Fusion must select the Aphelion native implementation.")
		var/list/reference = air.dogmos_fusion_reference()
		TEST_ASSERT(islist(reference), "Commissioning seed must produce a reference candidate.")
		var/datum/gas_mixture/expected = reference["mixture"]
		TEST_ASSERT(air.react(owner), "Native fusion did not execute for an owned eligible mixture.")
		TEST_ASSERT_EQUAL(air.completions, 1, "One native step must acknowledge exactly one completion.")
		var/expected_status = expected.return_temperature() >= DOGMOS_FUSION_MIN_TEMPERATURE ? "active" : "not eligible"
		TEST_ASSERT_EQUAL(air.dogmos_fusion_status(owner), expected_status, "Analyzer status must reflect both current eligibility and recent completion.")
		TEST_ASSERT(abs(air.dogmos_fusion_instability - reference["instability"]) < 0.02, "Native and DM instability disagree.")
		// One-step tolerance only; chaotic multi-step trajectories require separate qualification.
		for(var/gas_id in (air.get_gases() | expected.get_gases()))
			TEST_ASSERT(abs(air.get_moles(gas_id) - expected.get_moles(gas_id)) <= max(0.001, abs(expected.get_moles(gas_id)) * 0.005), "Native and independent DM gas result disagree for [gas_id].")
		TEST_ASSERT(abs(air.return_temperature() - expected.return_temperature()) <= max(0.1, expected.return_temperature() * 0.005), "Native and DM reference temperatures disagree.")
		qdel(expected)
		var/fuel_after = air.get_moles(/datum/gas/tritium)
		air.react(owner)
		TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), fuel_after, "Repeated aliases in one opportunity consumed extra fuel.")
		TEST_ASSERT_EQUAL(air.completions, 1, "Repeated dispatch emitted duplicate completion.")
		// Transport changes gas ownership, not the existing owner's admission history.
		var/admitted_at = air.dogmos_fusion_last_step
		var/datum/gas_mixture/daughter = air.remove_ratio(0.1)
		allocated += daughter // The maintained split API creates this instance rather than allocate().
		TEST_ASSERT(isnull(daughter.dogmos_fusion_last_step), "New split mixture inherited a processing opportunity.")
		TEST_ASSERT(isnull(daughter.dogmos_fusion_last_completion), "New split mixture inherited an active analyzer marker.")
		TEST_ASSERT_EQUAL(air.dogmos_fusion_last_step, admitted_at, "Splitting reset the source cadence.")
		air.merge(daughter)
		TEST_ASSERT_EQUAL(air.dogmos_fusion_last_step, admitted_at, "Merging reset the destination cadence.")
		TEST_ASSERT(abs(air.get_moles(/datum/gas/tritium) - fuel_after) < 0.001, "Nonreactive split and merge lost fuel.")
		TEST_ASSERT_EQUAL(air.completions, 1, "Nonreactive transport emitted fusion effects.")
		qdel(daughter)
		// Reseed and make the next opportunity due without sleeping or changing subsystem cadence.
		air.set_moles(/datum/gas/plasma, seed[1])
		air.set_moles(/datum/gas/carbon_dioxide, seed[2])
		air.set_moles(/datum/gas/tritium, seed[3])
		air.set_temperature(seed[4])
		air.dogmos_fusion_last_step = world.time - DOGMOS_FUSION_STEP_DECISECONDS * 20
		air.dogmos_fusion_last_completion = air.dogmos_fusion_last_step
		air.react(owner)
		TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), seed[3] - DOGMOS_FUSION_FUEL_PER_STEP, "Deferred processing must perform one step without catch-up.")
		TEST_ASSERT_EQUAL(air.completions, 2, "Next opportunity did not complete exactly once.")
		owner.air_contents = null
		TEST_ASSERT_EQUAL(air.dogmos_fusion_status(owner), "unsupported holder", "A detached owner retained execution authority.")
		fuel_after = air.get_moles(/datum/gas/tritium)
		air.react(owner)
		TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), fuel_after, "Detached owner consumed fuel.")
		TEST_ASSERT_EQUAL(air.completions, 2, "Detached owner emitted fusion effects.")
		owner.air_contents = air
		air.dogmos_fusion_excluded = TRUE
		air.dogmos_fusion_last_step = null
		fuel_after = air.get_moles(/datum/gas/tritium)
		air.react(owner)
		TEST_ASSERT_EQUAL(air.get_moles(/datum/gas/tritium), fuel_after, "Excluded HFR internal mixture reacted.")
		TEST_ASSERT_EQUAL(air.completions, 2, "Excluded mixture emitted effects.")
		owner.air_contents = null

/datum/unit_test/dogmos_mixture_fusion_bridge/Destroy()
	if(registry_replaced)
		SSair.dogmos_reactions = original_registry
		SSdogmos.mixture_fusion_enabled = original_enabled
		SSair.auxtools_update_reactions()
	original_registry = null
	return ..()
#endif
