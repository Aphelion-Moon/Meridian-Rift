/**
 * Character setup's drawn preview shows a tall or short body where the game draws it. A pixel on the head that height
 * stretches into place, as it does the head, and one that height lifts by an offset, as it does hair, eyes and hats,
 * land on the same row as in a round, for a plain body, a Big Legs taur and a taur whose body keeps its size.
 */
/datum/unit_test/character_preview_height

/datum/unit_test/character_preview_height/Run()
	for(var/taur_type in list(null, /datum/sprite_accessory/taur/biglegs, /datum/sprite_accessory/taur/feline))
		for(var/height in list(HUMAN_HEIGHT_SHORT, HUMAN_HEIGHT_TALLEST))
			check_markers(taur_type, height)

/**
 * Draws a preview body with the two marker pixels as character setup does, and checks where the page shows them.
 *
 * Arguments:
 * - taur_type: The body's taur kind, or null for none.
 * - height: The body's height.
 */
/datum/unit_test/character_preview_height/proc/check_markers(datum/sprite_accessory/taur/taur_type, height)
	var/mob/living/carbon/human/dummy/consistent/body = allocate(/mob/living/carbon/human/dummy/consistent)
	var/kind = taur_type ? "a [taur_type::name] taur" : "a plain body"
	if(taur_type)
		body.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part(taur_type::name)
		var/organ_type = taur_type::organ_type
		var/obj/item/organ/taur_body/organ = new organ_type
		organ.Insert(body, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	body.set_mob_height(height)
	// the head's row, above every cut a height map makes
	var/marker_y = 26
	var/image/stretched = marker_image("#fe01fd", 16, marker_y)
	body.apply_height(stretched, ENTIRE_BODY)
	var/image/lifted = marker_image("#01fefd", 17, marker_y)
	body.apply_height(lifted, UPPER_BODY)
	body.add_overlay(list(stretched, lifted))
	// last, as preferences do
	body.apply_height(body, ENTIRE_BODY)

	var/list/walk = character_preview_walk(body)
	var/frame_height = walk["height"]
	var/tile_y = walk["y"]
	var/list/rows = character_preview_effects(body, frame_height, tile_y)["rows"]
	var/datum/universal_icon/flat = character_preview_flatten(body, SOUTH, character_preview_stretches(body))
	var/icon/drawn = flat.to_icon()
	TEST_ASSERT_EQUAL(drawn.Height(), frame_height, "The south facing of [kind] at height [height] isn't the drawing's height")
	// in a round, both sit where height puts the head
	var/expected = frame_height - tile_y - (marker_y + GLOB.human_heights_to_offsets[height]["[UPPER_BODY]"])
	for(var/color in list("#fe01fd", "#01fefd"))
		var/what = color == "#fe01fd" ? "A pixel height stretches" : "A pixel height lifts, like hair,"
		var/source_row = find_marker_row(drawn, color)
		TEST_ASSERT_NOTNULL(source_row, "[what] isn't in the drawing of [kind] at height [height]")
		var/list/shown_at = list()
		for(var/frame_row in 0 to frame_height - 1)
			if(page_shows_row(rows, frame_row) == source_row)
				shown_at += frame_row
		if(length(shown_at) != 1 || shown_at[1] != expected)
			TEST_FAIL("[what] shows on frame rows [jointext(shown_at, ", ")] of [kind] at height [height], not on row [expected] as in a round")

/// A one-pixel image of `color` at (x, y) on a tile, drawn over everything else on the body.
/datum/unit_test/character_preview_height/proc/marker_image(color, x, y)
	var/icon/dot = icon('icons/blanks/32x32.dmi', "nothing")
	dot.DrawBox(color, x, y)
	return image(dot, layer = FLOAT_LAYER)

/// The row of the drawing, from its top, that holds the one pixel of `color`, or null.
/datum/unit_test/character_preview_height/proc/find_marker_row(icon/drawn, color)
	for(var/y in 1 to drawn.Height())
		for(var/x in 1 to drawn.Width())
			if(drawn.GetPixel(x, y) == color)
				return drawn.Height() - y

/// The drawing's row the page shows at `frame_row` in the tile's columns, once height's rows move, as drawPreviewFacing() does; -1 for none.
/datum/unit_test/character_preview_height/proc/page_shows_row(list/rows, frame_row)
	for(var/list/run as anything in rows)
		if(frame_row >= run[1] && frame_row < run[1] + run[2])
			return run[3] == -1 ? -1 : run[3] + frame_row - run[1]
	return frame_row
