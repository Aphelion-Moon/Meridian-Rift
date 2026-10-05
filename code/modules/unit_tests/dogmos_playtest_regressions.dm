// APHELION EDIT ADDITION START - DOGMOS_PLAYTEST_REGRESSIONS
/// A controlled atmosphere for testing slime stasis without changing shared map air.
/obj/effect/dogmos_slime_test_environment
	/// Mixture owned by the enclosing unit test.
	var/datum/gas_mixture/test_air

/obj/effect/dogmos_slime_test_environment/Destroy()
	test_air = null
	return ..()

/obj/effect/dogmos_slime_test_environment/return_air()
	return test_air

/// Vacuum and missing air must release BZ stasis; ordinary BZ still induces it.
/datum/unit_test/dogmos_slime_vacuum_stasis

/datum/unit_test/dogmos_slime_vacuum_stasis/Run()
	var/obj/effect/dogmos_slime_test_environment/container = allocate(/obj/effect/dogmos_slime_test_environment)
	container.test_air = allocate(/datum/gas_mixture)
	var/mob/living/basic/slime/slime = allocate(/mob/living/basic/slime, container)
	slime.bodytemperature = T20C
	container.test_air.set_moles(/datum/gas/bz, 1)
	container.test_air.set_moles(/datum/gas/nitrogen, 9)
	slime.handle_slime_stasis()
	TEST_ASSERT(slime.has_status_effect(/datum/status_effect/grouped/stasis), "Ten percent BZ must induce stasis.")
	container.test_air.clear()
	slime.handle_slime_stasis()
	TEST_ASSERT(!slime.has_status_effect(/datum/status_effect/grouped/stasis), "Vacuum must release BZ stasis without dividing by zero.")
	slime.apply_status_effect(/datum/status_effect/grouped/stasis, STASIS_SLIME_BZ)
	container.test_air = null
	slime.handle_slime_stasis()
	TEST_ASSERT(!slime.has_status_effect(/datum/status_effect/grouped/stasis), "Missing air must release BZ stasis.")

/// Zero-threshold pulses are legal, including when shielding fully absorbs them.
/datum/unit_test/dogmos_radiation_zero_threshold

/datum/unit_test/dogmos_radiation_zero_threshold/Run()
	var/datum/radiation_pulse_information/pulse = allocate(/datum/radiation_pulse_information)
	pulse.threshold = 0
	pulse.chance = 100
	TEST_ASSERT_EQUAL(get_perceived_radiation_danger(pulse, 0), PERCEIVED_RADIATION_DANGER_MEDIUM, "Fully blocked radiation must retain the shielded danger category.")
	TEST_ASSERT_EQUAL(get_perceived_radiation_danger(pulse, 1), PERCEIVED_RADIATION_DANGER_EXTREME, "Unshielded zero-threshold pulses remain dangerous.")
	pulse.threshold = 0.4
	TEST_ASSERT_EQUAL(get_perceived_radiation_danger(pulse, 0.1), PERCEIVED_RADIATION_DANGER_MEDIUM, "Positive-threshold shielding must retain its category.")
	TEST_ASSERT_EQUAL(get_perceived_radiation_danger(pulse, 0.3), PERCEIVED_RADIATION_DANGER_LOW, "Near-threshold shielding must retain its category.")
	pulse.chance = 10
	TEST_ASSERT_EQUAL(get_perceived_radiation_danger(pulse, 0.8), PERCEIVED_RADIATION_DANGER_HIGH, "Low-chance radiation must retain its category.")

/// At large mole counts the absolute pressure tolerance rounds away in DM floats.
/datum/unit_test/dogmos_pressure_boundary

/datum/unit_test/dogmos_pressure_boundary/Run()
	var/datum/gas_mixture/air = allocate(/datum/gas_mixture)
	// x * (x - 2**23) has an exact positive root at the lower bound.
	TEST_ASSERT_EQUAL(air.gas_pressure_quadratic(1, -8388608, 0, 8388608, 8389632), 8388608, "The quadratic solver must accept an exact boundary root.")
	TEST_ASSERT_EQUAL(air.gas_pressure_approximate(1, -8388608, 0, 8388608, 8389632), 8388608, "The fallback solver must accept an exact boundary root.")
	TEST_ASSERT_EQUAL(air.gas_pressure_quadratic(1, -3, -4, 0, 4), 4, "The upper boundary is inclusive too.")
	TEST_ASSERT_EQUAL(air.gas_pressure_quadratic(1, -3, -4, 0, 5), 4, "Ordinary interior roots must be unchanged.")
// APHELION EDIT ADDITION END

// APHELION EDIT ADDITION START - DOGMOS_PLAYTEST_REGRESSIONS
/// Cold fire spreading from valid floor-temperature gas must not emit a sub-TCMB exposure.
/datum/unit_test/dogmos_cold_fire_spread
	parent_type = /datum/unit_test/dogmos_hotspot_reignition
	/// Restrict this synchronous fixture to a single ordinary neighboring test turf.
	var/list/original_adjacency

/datum/unit_test/dogmos_cold_fire_spread/Run()
	fire_turf = run_loc_floor_bottom_left
	original_air = allocate(/datum/gas_mixture, CELL_VOLUME)
	original_air.copy_from(fire_turf.air)
	original_reaction_results = fire_turf.air.reaction_results
	original_reacted = SSair.dogmos_reacted_turfs[fire_turf]
	original_excited = fire_turf.excited
	original_adjacency = fire_turf.atmos_adjacent_turfs
	var/turf/open/neighbor = get_step(fire_turf, EAST)
	TEST_ASSERT(istype(neighbor) && !neighbor.active_hotspot, "Cold-fire fixture needs a clear adjacent turf.")
	TEST_ASSERT(neighbor.air.get_moles(/datum/gas/freon) < 0.5, "Neighbor must not sustain a cold hotspot.")
	fire_turf.atmos_adjacent_turfs = list(neighbor)
	fire_turf.air.clear()
	fire_turf.air.set_moles(/datum/gas/freon, 100)
	fire_turf.air.set_moles(/datum/gas/oxygen, 100)
	fire_turf.air.set_temperature(TCMB)
	fire_turf.hotspot_expose(TCMB, CELL_VOLUME)
	var/obj/effect/hotspot/cold_hotspot = fire_turf.active_hotspot
	TEST_ASSERT_NOTNULL(cold_hotspot, "Failed to create the cold hotspot.")
	cold_hotspot.just_spawned = FALSE
	cold_hotspot.volume = CELL_VOLUME
	cold_hotspot.process()
	TEST_ASSERT_EQUAL(fire_turf.air.return_temperature(), TCMB, "Spreading must not heat or cool the source mixture.")
	TEST_ASSERT(!neighbor.active_hotspot, "A neighbor without freon must not sustain cold fire.")

/datum/unit_test/dogmos_cold_fire_spread/Destroy()
	if(fire_turf)
		fire_turf.atmos_adjacent_turfs = original_adjacency
	original_adjacency = null
	return ..()
// APHELION EDIT ADDITION END
