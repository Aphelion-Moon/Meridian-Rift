/// A hooked leash draws its line from the holder to the leashed while the two are in reach, blanks it while a window
/// stands between them or the holder is inside a closet, draws it again once they are back in reach, and keeps that one
/// line until the unhook deletes it.
/datum/unit_test/leash_line

/datum/unit_test/leash_line/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	var/turf/beside = get_step(run_loc_floor_bottom_left, EAST)
	var/turf/behind_window = get_step(beside, EAST)
	var/turf/in_reach = get_step(behind_window, NORTH)
	var/mob/living/carbon/human/holder = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/leashed = allocate(/mob/living/carbon/human/consistent, beside)
	var/obj/item/clothing/erp_leash/leash = allocate(/obj/item/clothing/erp_leash)
	holder.put_in_hands(leash)

	leash.create_leash(holder, leashed)
	var/datum/component/leash/erp/hooked = leash.our_leash_component?.resolve()
	var/datum/beam/line = hooked?.line
	TEST_ASSERT(length(line?.elements), "A hooked leash drew no line to the leashed beside its holder.")

	allocate(/obj/structure/window/fulltile, beside)
	leashed.forceMove(behind_window)
	TEST_ASSERT(!length(hooked.line?.elements), "The leash line was still drawn through a window.")
	holder.forceMove(in_reach)
	TEST_ASSERT(length(hooked.line?.elements), "The leash line did not come back once the holder stepped into reach.")

	holder.forceMove(allocate(/obj/structure/closet, in_reach))
	TEST_ASSERT(!length(hooked.line?.elements), "The leash line was drawn from a holder inside a closet.")
	holder.forceMove(in_reach)
	TEST_ASSERT(length(hooked.line?.elements), "The leash line did not come back once the holder left the closet.")

	TEST_ASSERT_EQUAL(hooked.line, line, "The leash line was deleted and drawn anew while hooked.")
	leash.remove_leash(leashed)
	TEST_ASSERT(QDELETED(line), "The leash line outlived the unhook.")
