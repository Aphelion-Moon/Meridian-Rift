/// A carbon's zone map holds, for each zone of get_all_limbs() in its order, what get_bodypart() returns there: the limb, or
/// nothing where it has none.
/datum/unit_test/bodyparts_by_zones

/datum/unit_test/bodyparts_by_zones/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	check_map(body, "A whole body")
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_R_ARM)
	arm.drop_limb(special = TRUE)
	qdel(arm)
	check_map(body, "A body missing an arm")
	var/list/map = body.get_bodyparts_by_zones()
	TEST_ASSERT(BODY_ZONE_R_ARM in map, "A missing arm's zone must stay in the map")
	TEST_ASSERT_NULL(map[BODY_ZONE_R_ARM], "A missing arm's zone must hold nothing")

/// Compares a body's zone map with get_all_limbs() and get_bodypart(), zone by zone.
/datum/unit_test/bodyparts_by_zones/proc/check_map(mob/living/carbon/human/body, label)
	var/list/zones = body.get_all_limbs()
	var/list/map = body.get_bodyparts_by_zones()
	TEST_ASSERT_EQUAL(length(map), length(zones), "[label] must have one map entry per zone")
	for(var/index in 1 to length(zones))
		var/zone = zones[index]
		TEST_ASSERT_EQUAL(map[index], zone, "[label] must keep the zones in get_all_limbs() order")
		TEST_ASSERT_EQUAL(map[zone], body.get_bodypart(zone), "[label] must hold what get_bodypart() returns for [zone]")
