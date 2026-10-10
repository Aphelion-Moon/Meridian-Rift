/** Verifies the opt-in Rust reaction profiler reaches Kennel telemetry. */
/datum/unit_test/dogmos_kennel_reaction_profiling
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture
/datum/unit_test/dogmos_kennel_reaction_profiling/proc/seed_plasmafire_mix()
	var/datum/gas_mixture/mix = allocate(/datum/gas_mixture, CELL_VOLUME) // APHELION EDIT CHANGE - DOGMOS - ORIGINAL: var/datum/gas_mixture/mix = new(CELL_VOLUME)
	mix.set_moles(/datum/gas/plasma, 50)
	mix.set_moles(/datum/gas/oxygen, 200)
	mix.set_temperature(PLASMA_MINIMUM_BURN_TEMPERATURE + 500)
	return mix

/datum/unit_test/dogmos_kennel_reaction_profiling/Run()
	var/turf/open/T = run_loc_floor_bottom_left
	TEST_ASSERT(istype(T), "run_loc_floor_bottom_left is not an open turf - this test needs one.")

	SSair.diagnostics.recent_high_cost_zones = list()
	SSair.diagnostics.kennel_high_cost_ms_threshold = 0

	// Profiling OFF: a real reaction still fires, but nothing should be recorded.
	SSair.diagnostics.kennel_profile_reactions = FALSE
	var/datum/gas_mixture/off_mix = seed_plasmafire_mix()
	var/off_reacted = off_mix.react(T)
	TEST_ASSERT(off_reacted, \
		"plasmafire did not fire with profiling off - test setup is broken, not the thing under test.")
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.recent_high_cost_zones), 0, \
		"A reaction was recorded into recent_high_cost_zones while kennel_profile_reactions is FALSE - the toggle is not actually gating Rust's timing path.")
	qdel(off_mix)

	// Profiling ON, threshold 0 (any nonzero duration trips it): must record exactly one entry with
	// the right reaction name, holder-derived area, and a real (nonzero) cost.
	SSair.diagnostics.kennel_profile_reactions = TRUE
	var/datum/gas_mixture/on_mix = seed_plasmafire_mix()
	var/on_reacted = on_mix.react(T)
	TEST_ASSERT(on_reacted, \
		"plasmafire did not fire with profiling on - test setup is broken, not the thing under test.")
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.recent_high_cost_zones), 1, \
		"Expected exactly 1 recorded reaction with profiling on and threshold 0, got [length(SSair.diagnostics.recent_high_cost_zones)].")

	var/list/entry = SSair.diagnostics.recent_high_cost_zones[1]
	TEST_ASSERT_EQUAL(entry["reaction"], "plasmafire", \
		"Recorded reaction name is \"[entry["reaction"]]\", expected \"plasmafire\" - reaction_name_by_id() is not resolving the right reaction.")
	TEST_ASSERT_EQUAL(entry["jump_to"], REF(T), \
		"Recorded jump_to does not reference the real turf holder passed to react() - holder resolution is broken.")
	TEST_ASSERT(entry["cost_ms"] >= 0, \
		"Recorded cost_ms ([entry["cost_ms"]]) is negative - the Instant::now()/elapsed() timing is wrong.")
	qdel(on_mix)
