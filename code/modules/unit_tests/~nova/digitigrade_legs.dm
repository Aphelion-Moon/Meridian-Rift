/// The legs preference swaps a body's limbs in one render batch and draws the new legs when the batch ends; inside a caller's batch, drawing is left to the caller.
/datum/unit_test/digitigrade_legs_preference

/datum/unit_test/digitigrade_legs_preference/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/preference/choiced/digitigrade_legs/legs = GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs]
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(legs.apply_to_human(human, DIGITIGRADE_LEGS, preferences), "Humans should be able to take digitigrade legs")
	var/obj/item/bodypart/leg/left/leg = human.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg.bodyshape & BODYSHAPE_DIGITIGRADE, "The body should get digitigrade legs")
	TEST_ASSERT(!(human.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS), "The swap should end its render batch")
	TEST_ASSERT_EQUAL(human.icon_render_keys[BODY_ZONE_L_LEG], leg.get_cache_key(), "The body should be drawn with its new legs")
	human.living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	TEST_ASSERT(legs.apply_to_human(human, NORMAL_LEGS, preferences), "The legs should change back")
	TEST_ASSERT(human.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS, "A swap inside a caller's batch should leave the batch to the caller")
	human.living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
