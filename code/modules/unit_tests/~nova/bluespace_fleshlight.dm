/// The bluespace fleshlight catches a rod-form wizard's rod and sets the wizard down unharmed where the rod was, and
/// the rod's fling lands its user against a window without the impact.
/datum/unit_test/bluespace_fleshlight

/datum/unit_test/bluespace_fleshlight/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/turf/rod_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/mob/living/carbon/human/catcher = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/wizard = allocate(/mob/living/carbon/human/consistent)
	var/obj/effect/immovablerod/wizard/rod = allocate(/obj/effect/immovablerod/wizard, rod_turf)
	rod.set_wizard(wizard) // a rod made without a target stands still
	rod.setDir(NORTH) // the fling follows the rod's direction, into the window
	allocate(/obj/structure/window/fulltile, get_step(run_loc_floor_bottom_left, NORTH))
	catcher.put_in_active_hand(allocate(/obj/item/clothing/sextoy/fleshlight/bluespace))

	click_wrapper(catcher, rod)
	TEST_ASSERT(QDELETED(rod), "The bluespace fleshlight did not catch the wizard's rod.")
	if(QDELETED(wizard) || wizard.loc != rod_turf)
		TEST_FAIL("Catching a rod-form wizard's rod did not set the wizard down where the rod was.")
	if(catcher.get_brute_loss())
		TEST_FAIL("The rod's fling slammed its catcher into a window.")
