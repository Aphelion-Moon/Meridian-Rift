/// Liquids must keep their blood type's colour, blend it by blood volume whichever order it's poured in, and carry it through flow.
/datum/unit_test/liquid_blood_color

/datum/unit_test/liquid_blood_color/Run()
	var/obj/item/reagent_containers/blood/lizard/lizard_pack = allocate(/obj/item/reagent_containers/blood/lizard)
	var/obj/item/reagent_containers/blood/o_minus/red_pack = allocate(/obj/item/reagent_containers/blood/o_minus)
	var/datum/reagent/lizard_blood = lizard_pack.reagents.has_reagent(/datum/reagent/blood)
	var/datum/reagent/red_blood = red_pack.reagents.has_reagent(/datum/reagent/blood)
	var/turf/pool_turf = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)

	pool_turf.add_liquid_from_reagents(lizard_pack.reagents, reagent_multiplier = 20 / lizard_pack.reagents.total_volume)
	var/obj/effect/abstract/liquid_turf/pool = pool_turf.liquids
	check_color(pool.blood_color, /datum/blood_type/lizard::color, 1, "A lone puddle of lizard blood's blood colour")
	check_color(mix_liquid_color(pool.reagent_list, pool.blood_color), /datum/blood_type/lizard::color, 1, "A lone puddle of lizard blood's colour")

	pool_turf.add_liquid_from_reagents(red_pack.reagents, reagent_multiplier = 30 / red_pack.reagents.total_volume)
	check_color(pool.blood_color, expected_mix(lizard_blood.color, 20, red_blood.color, 30), 2, "20u of lizard blood with 30u of red blood poured in")

	var/pool_blood_color = pool.blood_color
	var/list/room_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	for(var/flow_run in 1 to 4)
		for(var/turf/room_turf as anything in room_turfs)
			if(room_turf.liquids)
				room_turf.process_liquid_cell()
		var/datum/liquid_group/flowing_group = pool_turf.lgroup
		if(flowing_group?.dirty)
			flowing_group.share()
			flowing_group.dirty = FALSE
	var/datum/liquid_group/group = pool_turf.lgroup
	TEST_ASSERT(length(group?.members) >= 3, "The pool should flow across at least 3 tiles, reached [length(group?.members)]")
	check_color(group.cached_blood_color, pool_blood_color, 1, "The group's blood colour after the pool flowed")
	for(var/turf/member as anything in group.members)
		var/obj/effect/abstract/liquid_turf/member_liquid = member.liquids
		if(member_liquid?.color != pool_turf.liquids.color || member_liquid.blood_color != group.cached_blood_color)
			TEST_FAIL("The pool tile at [member.x],[member.y] shows [member_liquid?.color] with blood [member_liquid?.blood_color], not the group's [pool_turf.liquids.color] with blood [group.cached_blood_color]")
			break

	clear_room()
	var/datum/reagents/water = allocate(/datum/reagents, 100)
	water.add_reagent(/datum/reagent/water, 30)
	var/turf/blood_first_turf = room_turfs[1]
	var/turf/water_first_turf = room_turfs[3]
	var/turf/red_first_turf = room_turfs[5]
	var/turf/green_first_turf = room_turfs[11]
	// Spilled with no_react, so the water doesn't leave the floor wet for later tests.
	blood_first_turf.add_liquid_from_reagents(red_pack.reagents, no_react = TRUE, reagent_multiplier = 70 / red_pack.reagents.total_volume)
	blood_first_turf.add_liquid_from_reagents(water, no_react = TRUE)
	water_first_turf.add_liquid_from_reagents(water, no_react = TRUE)
	water_first_turf.add_liquid_from_reagents(red_pack.reagents, no_react = TRUE, reagent_multiplier = 70 / red_pack.reagents.total_volume)
	var/obj/effect/abstract/liquid_turf/blood_first = blood_first_turf.liquids
	var/obj/effect/abstract/liquid_turf/water_first = water_first_turf.liquids
	check_color(mix_liquid_color(water_first.reagent_list, water_first.blood_color), mix_liquid_color(blood_first.reagent_list, blood_first.blood_color), 1, "30u of water then 70u of blood (against blood then water)")

	red_first_turf.add_liquid_from_reagents(red_pack.reagents, no_react = TRUE, reagent_multiplier = 70 / red_pack.reagents.total_volume)
	red_first_turf.add_liquid_from_reagents(lizard_pack.reagents, no_react = TRUE, reagent_multiplier = 30 / lizard_pack.reagents.total_volume)
	green_first_turf.add_liquid_from_reagents(lizard_pack.reagents, no_react = TRUE, reagent_multiplier = 30 / lizard_pack.reagents.total_volume)
	green_first_turf.add_liquid_from_reagents(red_pack.reagents, no_react = TRUE, reagent_multiplier = 70 / red_pack.reagents.total_volume)
	check_color(green_first_turf.liquids.blood_color, red_first_turf.liquids.blood_color, 1, "30u of lizard blood then 70u of red blood (against red then lizard)")

/datum/unit_test/liquid_blood_color/Destroy()
	clear_room()
	return ..()

/// Deletes every liquid and liquid group in the test room. The room's own cleanup qdels without force, which liquids ignore.
/datum/unit_test/liquid_blood_color/proc/clear_room()
	var/list/room_turfs = block(run_loc_floor_bottom_left, run_loc_floor_top_right)
	for(var/turf/room_turf as anything in room_turfs)
		if(room_turf.liquids)
			qdel(room_turf.liquids, TRUE)
	for(var/turf/room_turf as anything in room_turfs)
		if(room_turf.lgroup)
			qdel(room_turf.lgroup)

/**
 * Fails the test unless two colours match on every RGB channel within a tolerance.
 *
 * Returns:
 * - TRUE/FALSE: Whether they matched.
 */
/datum/unit_test/liquid_blood_color/proc/check_color(actual, expected, tolerance, what)
	var/list/actual_channels = istext(actual) ? rgb2num(actual) : null
	var/list/expected_channels = rgb2num(expected)
	for(var/channel in 1 to 3)
		if(isnull(actual_channels) || abs(actual_channels[channel] - expected_channels[channel]) > tolerance)
			TEST_FAIL("[what] is [actual || "unset"], expected [expected] within [tolerance] per channel")
			return FALSE
	return TRUE

/// Returns two colours mixed by volume, worked out apart from the code under test.
/datum/unit_test/liquid_blood_color/proc/expected_mix(first_color, first_volume, second_color, second_volume)
	var/list/first_channels = rgb2num(first_color)
	var/list/second_channels = rgb2num(second_color)
	var/total_volume = first_volume + second_volume
	return rgb(
		round((first_channels[1] * first_volume + second_channels[1] * second_volume) / total_volume, 1),
		round((first_channels[2] * first_volume + second_channels[2] * second_volume) / total_volume, 1),
		round((first_channels[3] * first_volume + second_channels[3] * second_volume) / total_volume, 1),
	)
