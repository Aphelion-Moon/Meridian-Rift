/// LINDA's MINIMUM_TEMPERATURE_START_SUPERCONDUCTION; the core define is removed under Dogmos.
#define LINDA_SUPERCONDUCTION_START (T20C + 400)

/** Cold turfs must not drain a room through TurfHeat; only LINDA-hot turfs start conduction. */
/datum/unit_test/dogmos_cold_reservoir_heat_gate

/datum/unit_test/dogmos_cold_reservoir_heat_gate/Run()
#ifdef DOGMOS_IN_PROCESS
	var/list/turfs = allocate_turf_pair(EAST)
	var/turf/open/room = turfs[1]
	var/turf/open/neighbor = turfs[2]
	// Open turfs that share air exchange heat through gas, so heat edges only cross blocked turfs.
	// A blocked neighbour stands in for the wall or mineral rock beside a room.
	neighbor.blocks_air = TRUE
	// The test room is indestructible flooring with infinite heat capacity; give the room an ordinary
	// floor's finite capacity so it can change, while the neighbour stays an infinite reservoir like rock.
	room.heat_capacity = 20000
	resync_turf_for_dogmos(neighbor)
	resync_turf_for_dogmos(room)
	TEST_ASSERT(dogmos_wait_for_stage_boundary(), "Native heat work did not settle before the fixture.")
	TEST_ASSERT(!isnull(room.dogmos_heat_temperature()) && !isnull(neighbor.dogmos_heat_temperature()), \
		"Both fixture floors need TurfHeat nodes for this test to exercise conduction.")

	// Regression: a 2.7 K neighbour (like an infinite-capacity mineral wall) cooled rooms at any temperature.
	room.set_temperature(T20C)
	neighbor.set_temperature(TCMB)
	for(var/pass in 1 to 4)
		TEST_ASSERT(dogmos_complete_fixture_heat(), "Native heat pass [pass] did not complete.")
	var/old_temp = room.dogmos_heat_temperature()

	// Control: a turf past the LINDA start threshold must still heat its neighbour.
	room.set_temperature(T20C)
	neighbor.set_temperature(LINDA_SUPERCONDUCTION_START + 100)
	for(var/pass in 1 to 4)
		TEST_ASSERT(dogmos_complete_fixture_heat(), "Native heat pass [pass] did not complete.")
	var/new_temp = room.dogmos_heat_temperature()
	dogmos_restore_fixture_scheduling()

	TEST_ASSERT(abs(old_temp - T20C) < 1, \
		"A room-temperature floor beside a [TCMB]K turf drifted to [old_temp]K; cold turfs must not start conduction.")
	TEST_ASSERT(new_temp > T20C + 1, \
		"A floor beside a [LINDA_SUPERCONDUCTION_START + 100]K turf stayed at [new_temp]K; hot turfs must still conduct.")
#endif

/datum/unit_test/dogmos_cold_reservoir_heat_gate/Destroy()
	var/turf/open/room = run_loc_floor_bottom_left
	var/turf/open/neighbor = get_step(room, EAST)
	if(istype(neighbor))
		neighbor.blocks_air = initial(neighbor.blocks_air)
	if(istype(room))
		room.heat_capacity = initial(room.heat_capacity)
	for(var/turf/open/target in list(room, neighbor))
		target.set_temperature(initial(target.temperature))
		target.air?.set_temperature(T20C)
		resync_turf_for_dogmos(target)
	return ..()

#undef LINDA_SUPERCONDUCTION_START
