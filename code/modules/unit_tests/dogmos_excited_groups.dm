#define DOGMOS_EXCITED_TEST_STAGE 1

/** Verifies one native excited-group stage redistributes a low-pressure fixture. */
/datum/unit_test/dogmos_excited_groups

/datum/unit_test/dogmos_excited_groups/Run()
	TEST_ASSERT(dogmos_wait_for_stage_boundary(), "Dogmos did not reach a safe boundary before excited-group processing.")
	var/list/pair = allocate_turf_pair()
	TEST_ASSERT_EQUAL(length(pair), 2, "The excited-group fixture needs two gas-adjacent turfs.")
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]
	var/datum/gas_mixture/air_a = turf_a.air
	var/datum/gas_mixture/air_b = turf_b.air
#ifdef DOGMOS_IN_PROCESS // APHELION EDIT ADDITION - DOGMOS
	var/list/room_turfs = get_area_turfs(turf_a.loc)
	var/open_count = 0
	for(var/turf/open/room_turf in room_turfs)
		open_count++
		if(room_turf.air != air_b)
			room_turf.air.copy_from(air_b)
		TEST_ASSERT_EQUAL(room_turf.air.return_volume(), air_b.return_volume(), "The group fixture requires equal volumes.")
		for(var/turf/open/neighbor as anything in room_turf.atmos_adjacent_turfs)
			TEST_ASSERT(neighbor in room_turfs, "The group fixture must be closed to external gas flow.")
	TEST_ASSERT(open_count > 2 && open_count <= 2500, "The native group fixture must fit in one component.")
#endif
	air_a.copy_from(air_b)
	var/original_o2 = air_b.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(original_o2 > 0, "The excited-group fixture requires nonzero oxygen.")
	// At room temperature 0.2 mole adds about 0.195 kPa, below the native 0.5 kPa goal.
	air_a.set_moles(/datum/gas/oxygen, original_o2 + 0.2)
	var/pressure_gap = air_a.return_pressure() - air_b.return_pressure()
	TEST_ASSERT(pressure_gap > 0 && pressure_gap < 0.5, "The excited-group fixture must fit within the 0.5 kPa pressure goal ([pressure_gap]).")
#ifdef DOGMOS_IN_PROCESS // APHELION EDIT ADDITION - DOGMOS
	TEST_ASSERT(dogmos_run_fixture_stage(4, pair), "Preparatory diffusion did not publish group seeds.")
	var/oxygen_before = 0
	for(var/turf/open/room_turf in room_turfs)
		oxygen_before += room_turf.air.get_moles(/datum/gas/oxygen)
	var/expected_o2 = oxygen_before / open_count
#else
	var/processed_before = SSair.num_group_turfs_processed
	var/expected_o2 = original_o2 + 0.1
#endif
	var/a_before = air_a.get_moles(/datum/gas/oxygen)
	TEST_ASSERT(dogmos_run_fixture_stage(DOGMOS_EXCITED_TEST_STAGE, pair), "Native excited-group processing did not complete and restore its frontier within the fixture bound.")
	var/a_after = air_a.get_moles(/datum/gas/oxygen)
#ifdef DOGMOS_IN_PROCESS // APHELION EDIT ADDITION - DOGMOS
	TEST_ASSERT(SSair.num_group_turfs_processed > 0, "Native groups did not report a processed component.")
	for(var/turf/open/room_turf in room_turfs)
		TEST_ASSERT(abs(room_turf.air.get_moles(/datum/gas/oxygen) - expected_o2) < 0.001, "A connected turf did not receive the room oxygen average.")
#else
	TEST_ASSERT(SSair.num_group_turfs_processed > processed_before, "Native excited-group processing did not report a processed component.")
#endif
	TEST_ASSERT(a_after < a_before, "Excited-group processing did not redistribute the seeded oxygen ([a_before] -> [a_after]).")
	TEST_ASSERT(abs(a_after - expected_o2) < 0.001, "The fuller turf did not receive the component oxygen average.")
	TEST_ASSERT(abs(air_b.get_moles(/datum/gas/oxygen) - expected_o2) < 0.001, "The emptier turf did not receive the component oxygen average.")

/datum/unit_test/dogmos_excited_groups/Destroy()
	restore_atmos()
	return ..()

#undef DOGMOS_EXCITED_TEST_STAGE
