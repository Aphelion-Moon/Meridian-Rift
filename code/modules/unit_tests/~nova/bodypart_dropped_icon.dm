/**
 * A limb is drawn as a dropped limb wherever it can be seen: made where it lands, made in nullspace and then moved out
 * of it, or dropped off a body. One made in nullspace is left undrawn while it stays there.
 *
 * A drawn limb blanks its placeholder icon state and shows its limb images as overlays instead.
 */
/datum/unit_test/bodypart_dropped_icon

/datum/unit_test/bodypart_dropped_icon/Run()
	var/obj/item/bodypart/arm/right/placed = allocate(/obj/item/bodypart/arm/right)
	TEST_ASSERT_EQUAL(placed.icon_state, "", "A limb made on the floor must be drawn at once")

	var/obj/item/bodypart/arm/left/floating = new()
	allocated += floating
	TEST_ASSERT_EQUAL(floating.icon_state, initial(floating.icon_state), "A limb made in nullspace must not be drawn while nothing can see it")
	var/overlays_undrawn = length(floating.overlays)
	floating.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(floating.icon_state, "", "A limb must be drawn when it first leaves nullspace")
	TEST_ASSERT(length(floating.overlays) > overlays_undrawn, "A limb leaving nullspace must show its limb images")

	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/leg/left/attached = new()
	allocated += attached
	TEST_ASSERT(attached.replace_limb(body), "A new leg must attach to the body")
	attached.drop_limb()
	TEST_ASSERT_EQUAL(attached.loc, body.loc, "A dropped leg must land where the body stands")
	TEST_ASSERT_EQUAL(attached.icon_state, "", "A limb dropped off a body must be drawn")
