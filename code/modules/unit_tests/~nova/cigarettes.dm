/** Verifies fire exposure can delete a match without continuing its ignition path. */
/datum/unit_test/match_fire_act_deletion

/datum/unit_test/match_fire_act_deletion/Run()
	var/obj/item/match/test_match = allocate(/obj/item/match)
	test_match.update_integrity(1)
	test_match.fire_act(1000, 100)
	TEST_ASSERT(QDELETED(test_match), "A match survived destructive fire exposure.")
