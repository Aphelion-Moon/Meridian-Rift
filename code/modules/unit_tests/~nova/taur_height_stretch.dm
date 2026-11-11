/**
 * Height stretches a taur's rider and a taur-fitted suit over its whole width, and never the taur body under them. Height
 * maps are 32 px wide and centred on what they stretch, so a taur body or suit once stretched in its middle 32 px only,
 * raising a hump on its back.
 */
/datum/unit_test/taur_height_stretch

/datum/unit_test/taur_height_stretch/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	give_feline_taur(taur)
	// an apron leaves the taur body in view, where an EVA suit hides it
	var/obj/item/clothing/suit/apron/suit = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(taur.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "A feline taur must be able to wear an apron")
	taur.set_mob_height(HUMAN_HEIGHT_TALLEST)
	taur.regenerate_icons()
	TEST_ASSERT(suit.worn_x_offset, "The apron must be drawn from its taur sheet for its stretch to be checked - if it has no paw sprite now, wear one that has")

	var/body_images = 0
	for(var/layer_images in taur.overlays_standing)
		for(var/image/drawn as anything in (islist(layer_images) ? layer_images : list(layer_images)))
			if(!drawn || !draws_taur_body(drawn))
				continue
			body_images++
			TEST_ASSERT(!length(displacement_maps(drawn)), "A Tallest taur's body image ([drawn.icon_state]) is stretched for height")
	TEST_ASSERT(body_images, "No taur body image was found to check")

	var/image/suit_drawn
	var/suit_standing = taur.overlays_standing[SUIT_LAYER]
	for(var/image/drawn as anything in (islist(suit_standing) ? suit_standing : list(suit_standing)))
		if(drawn.plane != EMISSIVE_PLANE)
			suit_drawn = drawn
			break
	TEST_ASSERT_NOTNULL(suit_drawn, "A taur's apron draws nothing")
	var/list/suit_maps = displacement_maps(suit_drawn)
	TEST_ASSERT(length(suit_maps), "A Tallest taur's taur-fitted suit isn't stretched for height")
	for(var/icon/map as anything in suit_maps)
		TEST_ASSERT_EQUAL(map.Width(), ICON_SIZE_X * 3, "A taur-fitted suit must be stretched by height maps covering its whole 64 px width")

/// Whether an image draws a taur body sprite, itself or in an image under it (a container holding its dirt)
/datum/unit_test/taur_height_stretch/proc/draws_taur_body(image/drawn)
	if(findtext("[drawn.icon]", "sprite_accessory/taur"))
		return TRUE
	for(var/image/child as anything in drawn.overlays)
		if(draws_taur_body(child))
			return TRUE
	return FALSE

/// The displacement maps of the height filters on an image. Its filters are read, not its filter_data, which the copy of
/// it kept for drawing leaves behind.
/datum/unit_test/taur_height_stretch/proc/displacement_maps(image/drawn)
	RETURN_TYPE(/list)
	. = list()
	for(var/dm_filter/height_filter as anything in drawn.filters)
		if(height_filter.type == "displace")
			. += icon(height_filter.icon)
