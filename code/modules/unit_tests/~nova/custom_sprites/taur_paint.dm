/// A 64 by 32 taur-zone drawing painted solid in one color, in every view.
/proc/custom_sprite_taur_paint_test_drawing(color)
	var/list/dirs = list()
	for(var/direction in GLOB.custom_style_directions)
		dirs[direction] = custom_sprite_encode_grid(repeat_string(CUSTOM_SPRITE_TAUR_WIDTH * 32, "1"), 1, CUSTOM_SPRITE_TAUR_WIDTH * 32)
	return list("version" = 3, "palette" = list(color), "tint" = null, "dirs" = dirs)

/// Taur-zone paint draws over the taur body, including when the organ arrives after the paint, as organ regeneration and character setup's preview put it back.
/datum/unit_test/custom_sprite_taur_paint_on_top/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.dna.custom_limb_markings = list(CUSTOM_MARKING_ZONE_TAUR = custom_sprite_taur_paint_test_drawing("#12ab34"))
	human.sync_custom_sprite_appearance()
	human.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part("Cow (Spotted)", list("#654321", "#321654", "#213456"))
	human.dna.species.regenerate_organs(human, visual_only = TRUE)
	human.update_body(is_creating = TRUE)
	TEST_ASSERT(human.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), "The fixture needs a real taur organ")
	var/obj/item/bodypart/chest = human.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(locate(/datum/bodypart_overlay/custom_marking/taur/zone) in chest.bodypart_overlays, "Taur-zone paint needs its overlay on the chest")
	var/mutable_appearance/look = new(human.appearance)
	for(var/direction in GLOB.cardinals)
		var/icon/flat = custom_sprite_flat_icon(look, direction, CUSTOM_SPRITE_TAUR_WIDTH)
		var/painted = 0
		for(var/y in 1 to 32)
			for(var/x in 1 to CUSTOM_SPRITE_TAUR_WIDTH)
				if(LOWER_TEXT(flat.GetPixel(x, y)) == "#12ab34")
					painted++
		TEST_ASSERT(painted, "Taur paint should show over the taur body facing [dir2text(direction)]")
