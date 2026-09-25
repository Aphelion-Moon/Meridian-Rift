/// Custom markings supply their own paint: their layer keys pick a limb silhouette, not an accessory icon state postfix.
/datum/bodypart_overlay/custom_marking/get_layer_postfixes()
	return list()

/proc/custom_sprite_test_drawing(shade = "1")
	var/list/dirs = list()
	for(var/direction in GLOB.cardinals)
		dirs["[direction]"] = custom_sprite_encode_grid(repeat_string(1024, shade))
	return custom_sprite_validate(list("version" = 1, "palette" = list("#ffffff", "#888888"), "tint" = null, "dirs" = dirs))

/proc/custom_sprite_test_same_pixels(icon/first, icon/second)
	if(!first || !second)
		return FALSE
	for(var/direction in GLOB.cardinals)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				if(first.GetPixel(x, y, "", direction) != second.GetPixel(x, y, "", direction))
					return FALSE
	return TRUE

/datum/unit_test/custom_sprite_paint_pixel_parity/Run()
	var/list/palette = list()
	for(var/index in 1 to 63)
		palette += rgb(index, 128, 64)
	var/list/directions = list()
	for(var/direction in list(SOUTH, EAST, WEST))
		var/grid = ""
		for(var/position in 1 to 1024)
			var/index = (position + direction) % 64
			grid += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, index + 1, index + 2)
		directions["[direction]"] = custom_sprite_encode_grid(grid, 63)
	var/icon/paint = custom_sprite_paint_icon(list("version" = 2, "palette" = palette, "dirs" = directions))
	var/list/states = icon_states(paint)
	TEST_ASSERT(!(paint.Width() != 32 || paint.Height() != 32 || length(states) != 1 || !("" in states)), "Raw paint must be a 32 by 32 icon with one default state, including when built in memory.")
	for(var/direction in GLOB.cardinals)
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/index = direction == NORTH ? 0 : ((y - 1) * 32 + x + direction) % 64
				TEST_ASSERT(paint.GetPixel(x, 33 - y, "", direction) == (index ? palette[index] : null), "Raw paint must preserve all 63 colors, transparent pixels, row orientation and missing directions.")

/datum/unit_test/custom_sprite_rendering/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	for(var/obj/item/bodypart/limb as anything in human.bodyparts)
		LAZYSET(human.dna.custom_limb_markings, limb.body_zone, custom_sprite_test_drawing())
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance()
	human.update_body(is_creating = TRUE)
	var/list/bounds = custom_sprite_mask_bounds(custom_sprite_body_draw_mask(human, BODY_ZONE_CHEST))
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT(bounds["[direction]"], "Torso bounds must include every cardinal direction.")
	for(var/obj/item/bodypart/limb as anything in human.bodyparts)
		var/datum/bodypart_overlay/custom_marking/overlay = locate() in limb.bodypart_overlays
		TEST_ASSERT(overlay, "Every limb must receive its drawing snapshot.")
		var/image/clipped = overlay.get_image(limb, "", -BODYPARTS_LAYER)
		TEST_ASSERT(custom_sprite_test_same_pixels(icon(clipped.icon), custom_sprite_silhouette(limb)), "Solid paint must be clipped exactly to [limb.body_zone]'s silhouette in every direction.")
		var/first_key = json_encode(overlay.icon_render_key(limb))
		overlay.set_drawing(custom_sprite_test_drawing("2"), limb)
		TEST_ASSERT(first_key != json_encode(overlay.icon_render_key(limb)), "Different drawings collided in the limb cache.")
		var/image/different = overlay.get_image(limb, "", -BODYPARTS_LAYER)
		TEST_ASSERT(!custom_sprite_test_same_pixels(icon(clipped.icon), icon(different.icon)), "Different drawings reused another player's clipped pixels.")
		overlay.set_drawing(custom_sprite_test_drawing(), limb)
		if(limb.body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
			var/list/leg_overlays = overlay.get_all_overlays(limb)
			var/icon/recombined = icon(clipped.icon)
			recombined.Blend("#00000000", ICON_MULTIPLY)
			var/upper = FALSE
			var/lower = FALSE
			for(var/image/part as anything in leg_overlays)
				upper ||= part.layer == -BODYPARTS_LAYER
				lower ||= part.layer == -BODYPARTS_LOW_LAYER
				recombined.Blend(icon(part.icon), ICON_OVERLAY)
			TEST_ASSERT(!(!upper || !lower || !custom_sprite_test_same_pixels(recombined, icon(clipped.icon))), "The two leg layers must preserve the clipped drawing.")
		limb.is_husked = HUSKED_BURN
		TEST_ASSERT(!overlay.can_draw_on_bodypart(limb, human), "Custom markings must stay hidden on husks.")
		limb.is_husked = initial(limb.is_husked)
		var/shape = limb.bodyshape
		limb.bodyshape |= BODYSHAPE_TAUR
		TEST_ASSERT(!overlay.can_draw_on_bodypart(limb, human), "Taur limbs must not render unsupported markings.")
		limb.bodyshape = shape
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(special = TRUE)
	var/datum/bodypart_overlay/custom_marking/detached = locate() in arm.bodypart_overlays
	TEST_ASSERT(detached?.drawing, "Detached limbs must retain their own drawing.")
	human.regenerate_limb(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/regrown = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/regrown_overlay = locate() in regrown.bodypart_overlays
	TEST_ASSERT(regrown_overlay?.drawing, "Regenerated limbs must inherit DNA drawings.")

/datum/unit_test/custom_sprite_head_snapshot/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/list/snapshot = head.custom_hair
	TEST_ASSERT(!(!snapshot || snapshot == human.dna.custom_hair || json_encode(snapshot) != json_encode(human.dna.custom_hair)), "Synchronizing with a body refresh must create an independent head drawing snapshot.")
	human.dna.custom_hair["tint"] = "#ff0000"
	head.copy_appearance_from(human)
	TEST_ASSERT(!(head.custom_hair == snapshot || snapshot["tint"] || head.custom_hair["tint"] != "#ff0000"), "Changed DNA must replace the head snapshot without mutating the old data.")
	head.drop_limb(special = TRUE)
	human.dna.custom_hair["tint"] = "#0000ff"
	human.regenerate_limb(BODY_ZONE_HEAD)
	var/obj/item/bodypart/head/regrown = human.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!(regrown?.custom_hair?["tint"] != "#0000ff" || head.custom_hair["tint"] != "#ff0000" || regrown.custom_hair == human.dna.custom_hair), "Detached and regenerated heads must retain independent drawing ownership.")
	human.dna.custom_hair = null
	human.sync_custom_sprite_appearance()
	TEST_ASSERT(!regrown.custom_hair, "Synchronizing a cleared drawing must clear the head snapshot without a body refresh.")

/datum/unit_test/custom_sprite_directional_emission/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[human.hairstyle]
	var/list/drawing = custom_sprite_test_drawing()
	drawing["tint"] = "#ffffff"
	var/icon/paint = custom_sprite_paint_icon(drawing)
	var/obj/item/bodypart/leg = human.get_bodypart(BODY_ZONE_L_LEG)
	for(var/selected_direction in GLOB.cardinals)
		var/list/settings = custom_sprite_emissive_settings(FALSE)
		settings["[selected_direction]"] = TRUE
		drawing["emissive"] = settings
		head.custom_hair = deep_copy_list(drawing)
		var/list/hair_overlays = list()
		head.append_custom_hair_paint_overlays(hair_overlays, paint, style, FALSE)
		leg.apply_custom_marking(drawing)
		var/datum/bodypart_overlay/custom_marking/marking = locate() in leg.bodypart_overlays
		var/list/leg_overlays = marking.get_all_overlays(leg)
		for(var/list/overlays as anything in list(hair_overlays, leg_overlays))
			var/emitting_masks = 0
			var/blocking_masks = 0
			for(var/image/mask as anything in overlays)
				if(PLANE_TO_TRUE(mask.plane) != EMISSIVE_PLANE)
					continue
				var/glowing = json_encode(mask.color) == json_encode(GLOB.emissive_color)
				if(glowing)
					emitting_masks++
				else
					blocking_masks++
				var/image/visible
				for(var/image/candidate as anything in overlays)
					if(PLANE_TO_TRUE(candidate.plane) != EMISSIVE_PLANE && candidate.layer == mask.layer)
						visible = candidate
						break
				TEST_ASSERT(visible, "Directional masks need a matching visible paint layer.")
				var/icon/mask_icon = icon(mask.icon)
				var/icon/visible_icon = icon(visible.icon)
				for(var/direction in GLOB.cardinals)
					for(var/x in 1 to 32)
						for(var/y in 1 to 32)
							var/expected = ((direction == selected_direction) == glowing) ? visible_icon.GetPixel(x, y, "", direction) : null
							TEST_ASSERT(mask_icon.GetPixel(x, y, "", direction) == expected, "Hair and split-leg masks must emit only the selected facing and block only the other views.")
			TEST_ASSERT(!(!emitting_masks || emitting_masks != blocking_masks), "Mixed per-view settings must generate complementary emission and blocker masks.")
	// Attached upper/lower masks are warm. A dropped leg now needs its whole unsplit silhouette.
	leg.drop_limb(special = TRUE)
	var/datum/bodypart_overlay/custom_marking/detached = locate() in leg.bodypart_overlays
	var/list/dropped_overlays = detached.get_all_overlays(leg)
	var/image/dropped_visible
	var/image/dropped_glow
	for(var/image/overlay as anything in dropped_overlays)
		if(PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE)
			dropped_visible = overlay
		else if(json_encode(overlay.color) == json_encode(GLOB.emissive_color))
			dropped_glow = overlay
	TEST_ASSERT(!(!dropped_visible || !dropped_glow), "The detached leg fixture must retain visible paint and its selected emission.")
	var/icon/dropped_paint = icon(dropped_visible.icon)
	var/icon/dropped_mask = icon(dropped_glow.icon)
	for(var/direction in GLOB.cardinals)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				var/expected = detached.drawing["emissive"]["[direction]"] ? dropped_paint.GetPixel(x, y, "", direction) : null
				TEST_ASSERT(dropped_mask.GetPixel(x, y, "", direction) == expected, "A detached leg must not reuse its attached upper-half directional mask.")

/datum/unit_test/custom_sprite_hair_cache/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[human.hairstyle]
	var/icon/shared_before = icon(style.getCachedIcon())
	human.dna.custom_hair = custom_sprite_test_drawing()
	head.copy_appearance_from(human)
	var/icon/paint = head.get_custom_hair_paint(style)
	TEST_ASSERT(!(!paint || paint.GetPixel(16, 16, "", SOUTH) != "#ffffff"), "Stored paint must produce a directional icon.")
	head.get_hair_overlays()
	TEST_ASSERT(custom_sprite_test_same_pixels(shared_before, style.getCachedIcon()), "Drawing hair mutated the shared hairstyle cache.")
	var/datum/hair_mask/mask = allocate(/datum/hair_mask/standard_hat_low)
	human.hair_masks = list(mask)
	var/icon/expected = icon(paint)
	var/icon/mask_icon = icon(mask.icon, mask.icon_state)
	mask_icon.Shift(SOUTH, style.y_offset)
	expected.Blend(mask_icon, ICON_ADD)
	TEST_ASSERT(custom_sprite_test_same_pixels(expected, head.get_custom_hair_paint(style)), "Paint must receive the same hat mask as authored hair.")
	human.dna.custom_hair["tint"] = "#ff0000"
	TEST_ASSERT(!head.custom_hair["tint"], "Head snapshots must not alias mutable DNA data.")
	var/mob/living/carbon/human/clone = allocate(/mob/living/carbon/human/consistent)
	human.dna.copy_dna(clone.dna)
	TEST_ASSERT(json_encode(clone.dna.custom_hair) == json_encode(human.dna.custom_hair), "DNA copies must preserve hair drawings.")
	clone.dna.custom_hair["tint"] = "#0000ff"
	TEST_ASSERT(human.dna.custom_hair["tint"] == "#ff0000", "DNA copies must own independent drawing data.")

/datum/unit_test/custom_marking_zone_geometry/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	for(var/body_zone in GLOB.custom_marking_zone_labels)
		// Hands have their own restricted geometry, covered by the salon hand test.
		if(body_zone == CUSTOM_MARKING_ZONE_TAUR || (body_zone in GLOB.custom_marking_hand_arms))
			continue
		var/obj/item/bodypart/limb = human.get_bodypart(body_zone)
		var/list/mask = custom_sprite_body_draw_mask(human, body_zone)
		TEST_ASSERT(mask == custom_sprite_body_draw_mask(human, body_zone), "Unchanged limb geometry must reuse its cached mask.")
		var/icon/silhouette = custom_sprite_silhouette(limb)
		if(limb.aux_zone)
			silhouette.Blend(custom_sprite_silhouette(limb, TRUE), ICON_OVERLAY)
		var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ffffff"), custom_sprite_mask_bounds(mask), mask)
		for(var/direction in GLOB.cardinals)
			for(var/y in 0 to 31)
				for(var/x in 0 to 31)
					TEST_ASSERT(!!workspace.is_point_allowed(x, y, "[direction]") == !!silhouette.GetPixel(x + 1, 32 - y, "", direction), "Editor pixels must match [body_zone]'s rendered silhouette in direction [direction].")
	human.dna.custom_limb_markings = list(BODY_ZONE_L_ARM = custom_sprite_test_drawing("2"))
	human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["emissive"] = custom_sprite_emissive_settings(TRUE)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/zone_overlay = locate() in arm.bodypart_overlays
	TEST_ASSERT(zone_overlay, "A limb zone drawing needs its own overlay.")
	var/datum/dna/copied_dna = allocate(/datum/dna)
	human.dna.copy_dna(copied_dna)
	copied_dna.custom_limb_markings[BODY_ZONE_L_ARM]["tint"] = "#ff0000"
	TEST_ASSERT(!human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["tint"], "Copied DNA must own independent per-zone drawings.")
	arm.drop_limb(special = TRUE)
	human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["emissive"] = custom_sprite_emissive_settings(FALSE)
	human.regenerate_limb(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/regrown_arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/regrown_overlay = locate() in regrown_arm.bodypart_overlays
	TEST_ASSERT(!(!zone_overlay.drawing["emissive"]["2"] || !regrown_overlay || regrown_overlay.drawing["emissive"]["2"]), "Detached limb drawings keep their emission snapshot; regrowth inherits current DNA.")
	human.dna.custom_limb_markings = null
	human.sync_custom_sprite_appearance()
	TEST_ASSERT(!(locate(/datum/bodypart_overlay/custom_marking/zone) in regrown_arm.bodypart_overlays), "Clearing a limb drawing must remove its own overlay.")

/// The real external organ path, including its hidden leg slots and matrixed sprite layers.
/proc/custom_sprite_test_taur(mob/living/carbon/human/body)
	body.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part("Cow (Spotted)", list("#654321", "#321654", "#213456"))
	body.dna.species.regenerate_organs(body, visual_only = TRUE)
	body.update_body(is_creating = TRUE)
	return body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)

/proc/custom_sprite_test_wide_drawing(row = null)
	var/list/directions = list()
	for(var/direction in GLOB.cardinals)
		directions["[direction]"] = "f[repeat_string(32, row || repeat_string(64, "1"))]"
	return list("version" = 3, "palette" = list("#ffffff", "#123456"), "dirs" = directions)

/datum/unit_test/custom_sprite_taur_rendering/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(human)
	TEST_ASSERT(organ, "The rendering fixture needs a real taur organ.")
	human.dna.custom_limb_markings = list("taur" = custom_sprite_test_wide_drawing(repeat_string(64, "2")))
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/chest = human.get_bodypart(BODY_ZONE_CHEST)
	var/datum/bodypart_overlay/custom_marking/taur/zone/zone = locate() in chest.bodypart_overlays
	TEST_ASSERT(zone, "Taur-zone paint needs its own overlay on the taur organ's chest.")
	var/datum/bodypart_overlay/mutant/taur_body/native = organ.bodypart_overlay
	var/list/native_layers = list(EXTERNAL_FRONT = BODY_FRONT_LAYER, EXTERNAL_ADJACENT = BODY_ADJ_LAYER, EXTERNAL_BEHIND = BODY_BEHIND_LAYER, EXTERNAL_FRONT_UNDER_CLOTHES = UNDER_UNIFORM_LAYER, EXTERNAL_FRONT_OVER = ABOVE_BODY_FRONT_HEAD_LAYER)
	var/list/outer_pixels = list()
	var/list/painted_directions = list()
	for(var/layer_index, layer_number in native_layers)
		var/icon/expected = custom_sprite_blank_icon()
		expected.Crop(1, 1, 64, 32)
		for(var/image/native_image as anything in native.get_images(chest, layer_index, -layer_number))
			expected.Blend(icon(native_image.icon, native_image.icon_state), ICON_OVERLAY)
		expected.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, 1,1,1,0)
		var/image/zoned = zone.get_image(chest, layer_index, -layer_number)
		var/icon/zone_paint = icon(zoned.icon)
		var/icon/zone_expected = icon(expected)
		zone_expected.Blend("#123456", ICON_MULTIPLY)
		TEST_ASSERT(!(zone_paint.Width() != 64 || zone_paint.Height() != 32 || zoned.pixel_x + zoned.pixel_w != -16 || zoned.layer != -layer_number), "Taur paint must use each native layer and its 64 by 32 canvas at offset -16.")
		for(var/direction in GLOB.cardinals)
			for(var/y in 1 to 32)
				for(var/x in 1 to 64)
					TEST_ASSERT(zone_paint.GetPixel(x, y, "", direction) == zone_expected.GetPixel(x, y, "", direction), "Taur-zone pixels must match the actual organ geometry in every layer and direction.")
					if(expected.GetPixel(x, y, "", direction))
						painted_directions["[direction]"] = TRUE
						if(x <= 16 || x > 48)
							outer_pixels["[direction]"] = TRUE
	TEST_ASSERT(!(length(painted_directions) != 4 || !outer_pixels["[EAST]"] || !outer_pixels["[WEST]"]), "The taur fixture must exercise all four directions and the outer canvas on its wide side views.")

/// Two colors, split evenly, so a recolor can be checked on both the palette and the pixels.
/proc/custom_style_test_two_color_drawing(color_one, color_two)
	var/grid = repeat_string(512, "1") + repeat_string(512, "2")
	var/list/dirs = list()
	for(var/direction in GLOB.custom_style_directions)
		dirs[direction] = custom_sprite_encode_grid(grid, 2)
	return custom_sprite_validate(list("version" = 1, "palette" = list(color_one, color_two), "tint" = "#ffffff", "dirs" = dirs))

/datum/unit_test/custom_style_hair_recolor/Run()
	var/list/dark = custom_style_test_hair()
	var/list/bright = custom_style_test_hair()
	bright["color"] = "#c0d0e0"
	var/list/color_map = custom_style_hair_color_map(dark, bright, null)
	var/list/shades = custom_style_hair_shades(dark)
	TEST_ASSERT(!(!length(color_map) || !length(shades) || !color_map[shades[1]]), "Recoloring the same hairstyle must map its shades.")
	var/list/other_style = custom_style_test_hair(/datum/sprite_accessory/hair/bedhead::name)
	TEST_ASSERT(!custom_style_hair_color_map(dark, other_style, null), "A different hairstyle must leave painted colors alone.")
	var/list/protected = custom_style_hair_color_map(dark, bright, list(shades[1]))
	TEST_ASSERT(!protected?[shades[1]], "Saved custom colors must be excluded from recolors.")
	var/list/drawing = custom_style_test_two_color_drawing(shades[1], "#123456")
	var/list/recolored = custom_style_recolor_drawing(drawing, color_map)
	TEST_ASSERT(!(!recolored || recolored["palette"][1] != color_map[shades[1]] || recolored["palette"][2] != "#123456"), "A recolor must move hair shades and keep other colors.")
	TEST_ASSERT(json_encode(recolored["dirs"]) == json_encode(drawing["dirs"]), "A recolor must not move any pixels.")
	var/list/merged = custom_style_recolor_drawing(drawing, list("[shades[1]]" = "#112233", "#123456" = "#112233"))
	TEST_ASSERT(!(!merged || length(merged["palette"]) != 1 || custom_sprite_decode_grid(merged["dirs"]["2"], 1) != repeat_string(1024, "1")), "Colors that collide after a recolor must merge into one palette slot.")
	TEST_ASSERT(custom_style_recolor_drawing(drawing, list("#00ff00" = "#112233")) == drawing, "A map that touches nothing must leave the drawing untouched.")

/datum/unit_test/custom_sprite_hair_dye/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.set_hairstyle("Short Hair", update = TRUE)
	human.set_haircolor("#583820", update = TRUE)
	var/list/hair = custom_style_live_hair_context(human)
	var/list/shades = custom_style_hair_shades(hair)
	custom_sprite_apply_round_style(human, custom_style_package("hair", null, custom_style_test_two_color_drawing(shades[1], "#123456"), hair))
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	human.set_haircolor("#c0d0e0", update = TRUE)
	var/list/color_map = custom_style_hair_color_map(hair, custom_style_live_hair_context(human), null)
	TEST_ASSERT(color_map?[shades[1]], "The fixture must produce a real recolor.")
	TEST_ASSERT(!(human.dna.custom_hair?["palette"][1] != color_map[shades[1]] || human.dna.custom_hair?["palette"][2] != "#123456"), "Dyeing hair must carry painted hair shades and keep other colors.")
	TEST_ASSERT(head?.custom_hair?["palette"][1] == color_map[shades[1]], "The head's own paint snapshot must be recolored with it.")
	var/list/dyed = deep_copy_list(human.dna.custom_hair)
	human.set_haircolor("#ff0000", override = TRUE, update = TRUE)
	TEST_ASSERT(json_encode(human.dna.custom_hair) == json_encode(dyed), "A temporary color override must not repaint the drawing.")
	human.set_hairstyle(/datum/sprite_accessory/hair/bedhead::name, update = TRUE)
	TEST_ASSERT(json_encode(human.dna.custom_hair) == json_encode(dyed), "A new haircut must leave painted colors as they were drawn.")

/proc/custom_style_test_facial_style()
	for(var/name, accessory_untyped in SSaccessories.facial_hairstyles_list)
		var/datum/sprite_accessory/facial_hair/accessory = accessory_untyped
		if(accessory?.icon_state)
			return name
	return null

/datum/unit_test/custom_sprite_facial_hair/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	var/style = custom_style_test_facial_style()
	TEST_ASSERT(style, "The fixture needs a facial hairstyle with a sprite.")
	human.set_facial_hairstyle(style, update = TRUE)
	human.set_facial_haircolor("#583820", update = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/hair_overlays = length(head.get_hair_overlays())
	var/list/facial = custom_style_live_hair_context(human, "facial_hair")
	TEST_ASSERT(!(facial["style"] != style || facial["color"] != "#583820" || !isnull(facial["opacity"]) || facial["emissive"]), "A live facial hair look must read the head's own style and color.")
	var/list/drawing = custom_sprite_test_drawing()
	custom_sprite_apply_round_style(human, custom_style_package("facial_hair", null, drawing, facial))
	TEST_ASSERT(custom_sprite_hash(human.dna.custom_facial_hair) == custom_sprite_hash(custom_sprite_validate(custom_sprite_appearance_drawing(drawing, FALSE))), "Applying facial hair paint must set it on the character.")
	TEST_ASSERT(custom_sprite_hash(head.custom_facial_hair) == custom_sprite_hash(human.dna.custom_facial_hair), "The head must carry its own facial hair snapshot.")
	TEST_ASSERT(!human.dna.custom_hair, "Facial hair paint must stay separate from head hair paint.")
	TEST_ASSERT(length(head.get_hair_overlays()) > hair_overlays, "Facial hair paint must add overlays to the head.")
	// Shaved faces have no accessory datum, exactly like bald heads.
	human.set_facial_hairstyle("Shaved", update = TRUE)
	custom_sprite_apply_round_style(human, custom_style_package("facial_hair", null, drawing, custom_style_live_hair_context(human, "facial_hair")))
	TEST_ASSERT(length(head.get_hair_overlays()), "Facial hair paint must render on a shaved face.")
	var/list/exported = custom_style_parse(custom_style_export_text(custom_sprite_live_package(human, "facial_hair", null)))
	TEST_ASSERT(!(exported["error"] || exported["package"]["target"] != "facial_hair"), "Facial hair must export and import as its own target: [exported["error"]]")
	human.set_facial_hairstyle(style, update = TRUE)
	var/list/shades = custom_style_hair_shades(custom_style_live_hair_context(human, "facial_hair"), "facial_hair")
	custom_sprite_apply_round_style(human, custom_style_package("facial_hair", null, custom_style_test_two_color_drawing(shades[1], "#123456"), custom_style_live_hair_context(human, "facial_hair")))
	human.set_facial_haircolor("#c0d0e0", update = TRUE)
	var/list/color_map = custom_style_hair_color_map(facial, custom_style_live_hair_context(human, "facial_hair"), null, "facial_hair")
	TEST_ASSERT(!(color_map?[shades[1]] && human.dna.custom_facial_hair?["palette"][1] != color_map[shades[1]]), "Dyeing facial hair must carry its painted shades.")

/datum/unit_test/custom_sprite_legacy_hair_recolor/Run()
	var/list/legacy = custom_sprite_test_drawing()
	var/before = json_encode(legacy)
	TEST_ASSERT(!(custom_style_recolor_drawing(legacy, list("#ffffff" = "#583820")) != legacy || json_encode(legacy) != before), "Legacy no-tint paint must retain raw shades because native hair coloring already tints it.")
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.set_hairstyle("Short Hair", update = FALSE)
	human.set_facial_hairstyle(custom_style_test_facial_style(), update = FALSE)
	human.set_haircolor("#ffffff", update = FALSE)
	human.set_facial_haircolor("#ffffff", update = FALSE)
	human.dna.custom_hair = deep_copy_list(legacy)
	human.dna.custom_facial_hair = deep_copy_list(legacy)
	human.sync_custom_sprite_appearance()
	human.set_haircolor("#583820", update = TRUE)
	human.set_facial_haircolor("#583820", update = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	for(var/list/snapshot as anything in list(human.dna.custom_hair, human.dna.custom_facial_hair, head.custom_hair, head.custom_facial_hair))
		TEST_ASSERT(json_encode(snapshot) == before, "Dyeing must preserve legacy paint in both DNA and attached head snapshots.")

/datum/unit_test/custom_sprite_hand_over_arm/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	arm.apply_custom_marking(custom_sprite_test_drawing("2"), /datum/bodypart_overlay/custom_marking/zone/hand)
	arm.apply_custom_marking(custom_sprite_test_drawing(), /datum/bodypart_overlay/custom_marking/zone)
	var/hand_position = 0
	var/arm_position = 0
	for(var/position in 1 to length(arm.bodypart_overlays))
		var/datum/bodypart_overlay/overlay = arm.bodypart_overlays[position]
		if(overlay.type == /datum/bodypart_overlay/custom_marking/zone/hand)
			hand_position = position
		else if(overlay.type == /datum/bodypart_overlay/custom_marking/zone)
			arm_position = position
	TEST_ASSERT(!(!hand_position || !arm_position || hand_position < arm_position), "A hand overlay must stay after its arm's overlay, even when the arm's is created later.")
