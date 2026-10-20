/** Verifies native fire reactions and their codebase-specific byproducts. */
/datum/unit_test/dogmos_aphelion_reactions

/datum/unit_test/dogmos_aphelion_reactions/Run()
	// Stay below PLASMA_OXYGEN_FULLBURN to exercise the water-vapor branch. Missing water vapor is
	// exactly the divergence citadel_reactions' plasmafire formula has from this codebase's.
	test_reaction(/datum/gas/plasma, 50, PLASMA_MINIMUM_BURN_TEMPERATURE + 500, /datum/gas_reaction/standard/plasmafire, list(/datum/gas/carbon_dioxide, /datum/gas/water_vapor))
	// Tritfire must produce water vapor (this codebase's fuel/oxidizer model), not citadel's water-less "trit bomb".
	test_reaction(/datum/gas/tritium, 20, TRITIUM_MINIMUM_BURN_TEMPERATURE + 500, /datum/gas_reaction/standard/tritfire, list(/datum/gas/water_vapor))
	test_reaction(/datum/gas/hydrogen, 20, HYDROGEN_MINIMUM_BURN_TEMPERATURE + 500, /datum/gas_reaction/standard/h2fire, list(/datum/gas/water_vapor))
	// Freonfire only burns within [FREON_TERMINAL_TEMPERATURE, FREON_MAXIMUM_BURN_TEMPERATURE] = [20, 283]
	// and is ENDOTHERMIC: it requires already being cold and gets colder.
	test_reaction(/datum/gas/freon, 50, 150, /datum/gas_reaction/standard/freonfire, list(/datum/gas/carbon_dioxide), exothermic = FALSE)

/**
 * Burns one fuel with oxygen through the native reaction path and checks consumption, heat and products.
 *
 * Arguments:
 * * gas_type - The fuel gas.
 * * amount - Moles of fuel, burned against 200 moles of oxygen.
 * * temperature - Starting temperature; must be inside the reaction's burn window.
 * * reaction_type - The reaction whose reaction_results entry must be written.
 * * product - Gases the reaction must produce.
 * * exothermic - Whether the burn must heat the mixture rather than cool it.
 */
/datum/unit_test/dogmos_aphelion_reactions/proc/test_reaction(gas_type, amount, temperature, reaction_type, list/product, exothermic = TRUE)
	var/datum/gas_mixture/air = allocate(/datum/gas_mixture, CELL_VOLUME)
	air.set_moles(gas_type, amount)
	air.set_moles(/datum/gas/oxygen, 200)
	air.set_temperature(temperature)
	var/old_temp = air.return_temperature()

	TEST_ASSERT(air.react(null), 		"[reaction_type] did not report a reaction despite [gas_type] and oxygen within its burn window - the aphelion_reactions Rust port isn't firing.")
	TEST_ASSERT(air.get_moles(gas_type) < amount, 		"[gas_type] moles did not decrease after [reaction_type] ([amount] -> [air.get_moles(gas_type)]).")
	TEST_ASSERT(air.get_moles(/datum/gas/oxygen) < 200, 		"Oxygen moles did not decrease after [reaction_type] (200 -> [air.get_moles(/datum/gas/oxygen)]).")
	if(exothermic)
		TEST_ASSERT(air.return_temperature() > old_temp, 			"Temperature did not increase after [reaction_type] ([old_temp] -> [air.return_temperature()]) - energy release is missing.")
	else
		TEST_ASSERT(air.return_temperature() < old_temp, 			"Temperature did not decrease after endothermic [reaction_type] ([old_temp] -> [air.return_temperature()]).")
	for(var/gas_path in product)
		TEST_ASSERT(air.get_moles(gas_path) > 0, "[reaction_type] did not produce [gas_path].")
	TEST_ASSERT(air.reaction_results[reaction_type], 		"reaction_results wasn't populated for [reaction_type] - the native finish step isn't writing the typepath-keyed entry that hotspot-driven fire growth (LINDA_fire.dm) depends on.")
	qdel(air)

/** Fresh combustion must rescue an exhausted hotspot without replacing its identity. */
/datum/unit_test/dogmos_hotspot_reignition
	/// Shared test turf whose atmosphere is restored even after an assertion fails.
	var/turf/open/fire_turf
	/// Original gas state; allocated with the test so cleanup owns it.
	var/datum/gas_mixture/original_air
	/// The previous reaction bookkeeping belongs to the shared turf, not this test.
	var/list/original_reaction_results
	/// Whether an earlier callback had already marked this turf as reacting.
	var/original_reacted
	/// Whether this turf was already scheduled before the fixture ignited it.
	var/original_excited

/datum/unit_test/dogmos_hotspot_reignition/Run()
	fire_turf = run_loc_floor_bottom_left
	original_air = allocate(/datum/gas_mixture, CELL_VOLUME)
	original_air.copy_from(fire_turf.air)
	original_reaction_results = fire_turf.air.reaction_results
	original_reacted = SSair.dogmos_reacted_turfs[fire_turf]
	original_excited = fire_turf.excited
	var/datum/gas_mixture/fuel = allocate(/datum/gas_mixture, CELL_VOLUME)
	fuel.set_moles(/datum/gas/plasma, 50)
	fuel.set_moles(/datum/gas/oxygen, 200)
	fuel.set_temperature(1000)
	fire_turf.air.copy_from(fuel)
	fire_turf.hotspot_expose(1000, CELL_VOLUME)
	var/obj/effect/hotspot/original_hotspot = fire_turf.active_hotspot
	TEST_ASSERT_NOTNULL(original_hotspot, "Fixture failed to ignite a real hotspot.")
	original_hotspot.just_spawned = FALSE
	// A previous exposure found no combustion. Before hotspot processing resumes,
	// diffusion replenishes the turf and its normal reaction callback burns again.
	original_hotspot.volume = 0
	fire_turf.air.copy_from(fuel)
	fire_turf.dogmos_react()
	TEST_ASSERT(fire_turf.air.reaction_results[/datum/gas_reaction/standard/plasmafire] > 0, "The replenished turf did not burn.")
	var/plasma_after_reaction = fire_turf.air.get_moles(/datum/gas/plasma)
	var/temperature_after_reaction = fire_turf.air.return_temperature()
	original_hotspot.process()
	TEST_ASSERT(!QDELETED(original_hotspot) && fire_turf.active_hotspot == original_hotspot, "Fresh combustion was followed by deletion of the existing hotspot.")
	TEST_ASSERT_EQUAL(fire_turf.air.get_moles(/datum/gas/plasma), plasma_after_reaction, "Refreshing a sustained fire burned an extra gas sample.")
	TEST_ASSERT_EQUAL(fire_turf.air.return_temperature(), temperature_after_reaction, "Refreshing a sustained fire changed its thermal state.")
	// Extinction must still work; a visual repair must not keep a dead fire alive.
	original_hotspot.volume = 0
	fire_turf.air.set_moles(/datum/gas/plasma, 0)
	fire_turf.air.set_moles(/datum/gas/tritium, 0)
	fire_turf.air.set_moles(/datum/gas/hydrogen, 0)
	fire_turf.dogmos_react()
	original_hotspot.process()
	TEST_ASSERT(QDELETED(original_hotspot) && !fire_turf.active_hotspot, "A genuinely exhausted hotspot remained alive.")

/datum/unit_test/dogmos_hotspot_reignition/Destroy()
	if(fire_turf && original_air)
		QDEL_NULL(fire_turf.active_hotspot)
		fire_turf.air.copy_from(original_air)
		fire_turf.air.reaction_results = original_reaction_results
		if(isnull(original_reacted))
			SSair.dogmos_reacted_turfs -= fire_turf
		else
			SSair.dogmos_reacted_turfs[fire_turf] = original_reacted
		fire_turf.update_visuals()
		if(!original_excited)
			SSair.remove_from_active(fire_turf)
	fire_turf = null
	original_air = null
	original_reaction_results = null
	return ..()
