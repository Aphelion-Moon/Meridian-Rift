/**
 * Height stretches a Tallest taur's taur-fitted suit, and never the taur body under it or the paint on that body. At
 * every height but Average, each height map on the suit is at least as wide as the suit's sprite.
 */
/datum/unit_test/taur_height_stretch

/datum/unit_test/taur_height_stretch/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	// painted before the taur body goes in, as a regenerated body is, so the paint comes first on the chest
	taur.dna.custom_limb_markings = list(CUSTOM_MARKING_ZONE_TAUR = custom_sprite_taur_paint_test_drawing("#12ab34"))
	taur.sync_custom_sprite_appearance()
	give_feline_taur(taur)
	// an apron leaves the taur body in view, where an EVA suit hides it
	var/obj/item/clothing/suit/apron/suit = allocate(/obj/item/clothing/suit/apron)
	TEST_ASSERT(taur.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "A feline taur must be able to wear an apron")
	taur.set_mob_height(HUMAN_HEIGHT_TALLEST)
	taur.regenerate_icons()
	TEST_ASSERT(suit.worn_x_offset, "The apron must be drawn from its taur sheet for its stretch to be checked - if it has no paw sprite now, wear one that has")

	var/obj/item/bodypart/chest = taur.get_bodypart(BODY_ZONE_CHEST)
	var/datum/bodypart_overlay/custom_marking/taur/paint = chest.get_custom_marking(/datum/bodypart_overlay/custom_marking/taur/zone)
	TEST_ASSERT_NOTNULL(paint, "A painted feline taur has no taur paint on its chest")
	// paint draws at its own layers, just above the taur body's
	var/list/paint_layers = list()
	for(var/image/painted as anything in paint.get_all_overlays(chest))
		paint_layers |= painted.layer

	var/body_images = 0
	var/paint_images = 0
	for(var/layer_images in taur.overlays_standing)
		for(var/image/drawn as anything in (islist(layer_images) ? layer_images : list(layer_images)))
			if(!drawn)
				continue
			if(draws_taur_body(drawn))
				body_images++
				TEST_ASSERT(!length(displacement_maps(drawn)), "A Tallest taur's body image ([drawn.icon_state]) is stretched for height")
			else if(PLANE_TO_TRUE(drawn.plane) != EMISSIVE_PLANE && (drawn.layer in paint_layers))
				paint_images++
				TEST_ASSERT(!length(displacement_maps(drawn)), "A Tallest taur's paint at layer [drawn.layer] is stretched for height, though the taur body under it isn't")
	TEST_ASSERT(body_images, "No taur body image was found to check")
	TEST_ASSERT(paint_images, "No taur paint image was found to check")

	var/image/suit_drawn
	var/suit_standing = taur.overlays_standing[SUIT_LAYER]
	for(var/image/drawn as anything in (islist(suit_standing) ? suit_standing : list(suit_standing)))
		if(drawn.plane != EMISSIVE_PLANE)
			suit_drawn = drawn
			break
	TEST_ASSERT_NOTNULL(suit_drawn, "A taur's apron draws nothing")
	TEST_ASSERT(length(displacement_maps(suit_drawn)), "A Tallest taur's taur-fitted suit isn't stretched for height")

	for(var/height in list(HUMAN_HEIGHT_SHORTEST, HUMAN_HEIGHT_SHORT, HUMAN_HEIGHT_TALL, HUMAN_HEIGHT_TALLER, HUMAN_HEIGHT_TALLEST))
		taur.set_mob_height(height)
		check_maps_wide(taur, "height [height]")
	// a dwarf's height comes from the trait alone
	ADD_TRAIT(taur, TRAIT_DWARF, TRAIT_SOURCE_UNIT_TESTS)
	taur.update_mob_height()
	check_maps_wide(taur, "a dwarf's height")
	REMOVE_TRAIT(taur, TRAIT_DWARF, TRAIT_SOURCE_UNIT_TESTS)

/**
 * Checks that each height map on a taur's apron is at least as wide as the apron's sprite. Then the stretch reaches
 * the sprite's edges and leaves no step at either side of its middle.
 *
 * Arguments:
 * - taur: The taur in the apron.
 * - height_name: Its height, for the failure message.
 */
/datum/unit_test/taur_height_stretch/proc/check_maps_wide(mob/living/carbon/human/taur, height_name)
	var/image/root = bulge_drawn_root(taur.overlays_standing[SUIT_LAYER])
	var/image/sprite = bulge_drawn_leaf(root)
	var/list/size = sprite && get_icon_dimensions(sprite.icon)
	var/list/maps = root && displacement_maps(root)
	TEST_ASSERT(size?["width"] > ICON_SIZE_X && length(maps), "A taur's apron at [height_name] isn't drawn wider than a tile, or isn't stretched for height, so its maps' width can't be checked")
	for(var/icon/map as anything in maps)
		TEST_ASSERT(map.Width() >= size["width"], "A [map.Width()] px wide height map stretches a taur's [size["width"]] px wide apron at [height_name], so only its middle stretches")

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
