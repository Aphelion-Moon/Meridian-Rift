/// A welding fuel spill must flare up, step down through medium flames and burn out in 45 to 90 seconds, while an oil spill lit with it burns on.
/datum/unit_test/liquid_fire_burnout

/datum/unit_test/liquid_fire_burnout/Run()
	var/turf/fuel_turf = run_loc_floor_bottom_left
	var/turf/oil_turf = run_loc_floor_top_right
	fuel_turf.add_liquid(/datum/reagent/fuel, 30, no_react = TRUE)
	oil_turf.add_liquid(/datum/reagent/fuel/oil, 30, no_react = TRUE)
	var/obj/effect/abstract/liquid_turf/fuel = fuel_turf.liquids
	var/obj/effect/abstract/liquid_turf/oil = oil_turf.liquids
	fuel.fire_act(1000, 125)
	oil.fire_act(1000, 125)
	TEST_ASSERT_EQUAL(fuel.fire_state, LIQUID_FIRE_STATE_INFERNO, "30u of welding fuel should ignite straight at the top fire state")
	TEST_ASSERT(oil.fire_state && oil.fire_state < LIQUID_FIRE_STATE_INFERNO, "30u of oil should ignite below an inferno, got fire state [oil.fire_state]")

	var/run_interval = REQUIRED_FIRE_PROCESSES * SSliquids.wait
	var/min_runs = ceil((45 SECONDS) / run_interval)
	var/max_runs = floor((90 SECONDS) / run_interval)
	var/list/seen_states = list()
	var/last_state = fuel.fire_state
	var/runs = 0
	while(!QDELETED(fuel) && runs < max_runs)
		seen_states |= fuel.fire_state
		fuel.process_fire()
		oil.process_fire()
		runs++
		if(QDELETED(fuel))
			break
		TEST_ASSERT(fuel.fire_state <= last_state, "The fuel fire grew from state [last_state] to [fuel.fire_state] on fire run [runs]")
		last_state = fuel.fire_state
	TEST_ASSERT(QDELETED(fuel) && isnull(fuel_turf.liquids), "30u of welding fuel should burn away within [max_runs] fire runs")
	TEST_ASSERT(runs >= min_runs, "30u of welding fuel burnt away in [runs] fire runs, short of the [min_runs] that 45 seconds takes")
	TEST_ASSERT(length(seen_states) >= 3, "The fuel fire should step down through at least 3 fire states, saw [jointext(seen_states, ", ")]")
	TEST_ASSERT(LIQUID_FIRE_STATE_MEDIUM in seen_states, "The fuel fire should pass through the medium fire state, saw [jointext(seen_states, ", ")]")
	TEST_ASSERT(!QDELETED(oil) && oil.fire_state, "30u of oil should still burn after the [runs] fire runs that burnt away the fuel")

/datum/unit_test/liquid_fire_burnout/Destroy()
	// The test room's cleanup qdels without force, which liquids ignore.
	for(var/turf/spilled_turf as anything in list(run_loc_floor_bottom_left, run_loc_floor_top_right))
		if(spilled_turf.liquids)
			qdel(spilled_turf.liquids, TRUE)
	return ..()
