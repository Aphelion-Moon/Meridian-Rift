/**
 * A husk tones each limb sheet from a file once: the toned copy is drawn with the same pixels a fresh tone gives, every husk
 * drawn from that sheet reuses it, and a runtime icon, which could be any pixels, is toned afresh and never kept.
 */
/datum/unit_test/husk_icon_cache

/datum/unit_test/husk_icon_cache/Run()
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/chest/chest = first.get_bodypart(BODY_ZONE_CHEST)
	var/image/plain = chest.get_limb_icon(dropped = FALSE)[1]
	var/sheet = plain.icon
	TEST_ASSERT(isfile(sheet) && length("[sheet]"), "The fixture's chest must be drawn from an icon file")
	first.become_husk(BURN)
	first.update_body_parts(update_limb_data = TRUE)
	var/toned = GLOB.husk_toned_sheets[sheet]
	TEST_ASSERT(toned, "A husk must keep its limb sheet's toned copy")
	var/image/drawn = chest.get_limb_icon(dropped = FALSE)[1]
	TEST_ASSERT_EQUAL(drawn.icon, toned, "A husked limb must be drawn from its sheet's toned copy")

	// The same pixels the old per-render tone gave, on every direction of the chest state.
	var/icon/fresh = new(sheet)
	fresh.ColorTone(HUSK_COLOR_TONE)
	for(var/direction in GLOB.cardinals)
		var/icon/expected = icon(fresh, drawn.icon_state, direction)
		var/icon/actual = icon(toned, drawn.icon_state, direction)
		for(var/y in 1 to ICON_SIZE_Y)
			for(var/x in 1 to ICON_SIZE_X)
				TEST_ASSERT_EQUAL(actual.GetPixel(x, y), expected.GetPixel(x, y), "The toned sheet must match a fresh tone at [x],[y] facing [dir2text(direction)]")

	var/sheets_kept = length(GLOB.husk_toned_sheets)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	second.become_husk(BURN)
	second.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT_EQUAL(length(GLOB.husk_toned_sheets), sheets_kept, "Another husk of the same sheets must keep nothing new")

	var/icon/runtime_sheet = icon(sheet)
	var/runtime_resource = fcopy_rsc(runtime_sheet)
	TEST_ASSERT(husk_toned_sheet(runtime_resource), "A runtime icon must still be toned")
	TEST_ASSERT(husk_toned_sheet(runtime_sheet), "An /icon datum must still be toned")
	TEST_ASSERT_EQUAL(length(GLOB.husk_toned_sheets), sheets_kept, "A runtime icon's tone must never be kept")
