/**
 * A limb that lands somewhere carries its owner's blood; one with nowhere to land, or kept inside its owner, does not.
 */
/datum/unit_test/drop_limb_blood
	/// Blood DNA entries the deleted limb carried when its deletion began, or null before then.
	var/deleted_limb_blood

/datum/unit_test/drop_limb_blood/proc/on_limb_deleting(obj/item/bodypart/source)
	SIGNAL_HANDLER
	deleted_limb_blood = GET_ATOM_BLOOD_DNA_LENGTH(source)

/datum/unit_test/drop_limb_blood/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(length(body.get_blood_dna_list()), "The test body must have blood to leave on its limbs")

	var/obj/item/bodypart/arm/left/fallen = body.get_bodypart(BODY_ZONE_L_ARM)
	fallen.drop_limb()
	TEST_ASSERT_EQUAL(fallen.loc, body.loc, "A dropped arm must land where the body stands")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(fallen), "A limb dropped to the floor must carry its owner's blood")

	var/obj/item/bodypart/leg/left/pulled = body.get_bodypart(BODY_ZONE_L_LEG)
	pulled.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(isnull(pulled.owner), "A limb moved off its body must come off it")
	TEST_ASSERT(GET_ATOM_BLOOD_DNA_LENGTH(pulled), "A limb moved off its body onto the floor must carry its owner's blood")

	var/obj/item/bodypart/arm/right/kept = body.get_bodypart(BODY_ZONE_R_ARM)
	kept.drop_limb(special = TRUE, move_to_floor = FALSE)
	TEST_ASSERT(!GET_ATOM_BLOOD_DNA_LENGTH(kept), "A limb kept off the floor must take no blood")

	// With nowhere to drop to, as for the character preview's body in nullspace, the limb is deleted on the spot.
	body.moveToNullspace()
	var/obj/item/bodypart/leg/right/discarded = body.get_bodypart(BODY_ZONE_R_LEG)
	RegisterSignal(discarded, COMSIG_QDELETING, PROC_REF(on_limb_deleting))
	discarded.drop_limb(special = TRUE)
	TEST_ASSERT(QDELETED(discarded), "A limb with nowhere to drop to must be deleted")
	TEST_ASSERT_EQUAL(deleted_limb_blood, 0, "A limb with nowhere to drop to must be deleted without taking blood")
	body.forceMove(run_loc_floor_bottom_left)
