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
	human.dna.custom_markings = custom_sprite_test_drawing()
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance()
	human.update_body(is_creating = TRUE)
	var/list/bounds = custom_sprite_body_draw_bounds(human)
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT(bounds["[direction]"], "Body bounds must include every cardinal direction.")
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

/datum/unit_test/custom_sprite_hair_gradient_palette/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[/datum/sprite_accessory/hair/bedhead::name]
	head.hair_color = "#ffffff"
	head.fixed_hair_color = null
	head.override_hair_color = null
	var/list/source = custom_sprite_sample_palette(style.icon, style.icon_state)
	var/source_before = json_encode(source)
	human.set_hair_gradient_style(SPRITE_ACCESSORY_NONE, update = FALSE)
	human.set_hair_gradient_color("#12ABEF", update = FALSE)
	human.set_facial_hair_gradient_style(/datum/sprite_accessory/gradient/full::name, update = FALSE)
	human.set_facial_hair_gradient_color("#fedcba", update = FALSE)
	var/list/palette = custom_sprite_sample_hair_palette(style, head)
	TEST_ASSERT(json_encode(palette) == source_before, "Inactive hair gradients and facial-only gradients must not add hair palette colors.")
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/full::name, update = FALSE)
	palette = custom_sprite_sample_hair_palette(style, head)
	TEST_ASSERT(!(!("#12abef" in palette) || ("#fedcba" in palette)), "An active hair gradient must add its canonical color without the facial gradient.")
	TEST_ASSERT(!(json_encode(source) != source_before || json_encode(custom_sprite_sample_palette(style.icon, style.icon_state)) != source_before), "Adding gradient swatches must not modify shared source palette lists.")
	human.set_hair_gradient_color(source[1], update = FALSE)
	TEST_ASSERT(length(custom_sprite_sample_hair_palette(style, head)) == length(source), "Gradient colors already present among source shades must not be duplicated.")
	// Species presets use these same setters (for example the protean preview).
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/reflected_inverse::name, update = FALSE)
	human.set_hair_gradient_color("#685064", update = FALSE)
	TEST_ASSERT((head.get_hair_gradient_color(GRADIENT_HAIR_KEY) in custom_sprite_sample_hair_palette(style, head)), "The palette must use the active head gradient, including species preset values.")
	human.set_hair_gradient_style("invalid-gradient-fixture", update = FALSE)
	TEST_ASSERT(json_encode(custom_sprite_sample_hair_palette(style, head)) == source_before, "An unregistered gradient style must not add a color.")
	head.hair_color = "#804020"
	palette = custom_sprite_sample_hair_palette(null, head)
	TEST_ASSERT(!(palette[1] != "#804020" || ("#ffffff" in palette)), "Automatic hair swatches must contain the actual hair colors for literal painting.")
	head.fixed_hair_color = "#123456"
	palette = custom_sprite_sample_hair_palette(null, head)
	TEST_ASSERT(palette[1] == "#123456", "Automatic swatches must respect fixed species hair colors.")
	head.override_hair_color = "#abcdef"
	palette = custom_sprite_sample_hair_palette(null, head)
	TEST_ASSERT(palette[1] == "#abcdef", "Automatic swatches must respect hair color overrides.")

/datum/unit_test/custom_sprite_tint_cache_reuse/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/list/drawing = custom_sprite_test_drawing()
	var/icon/raw = custom_sprite_paint_icon(drawing)
	var/obj/item/bodypart/leg = human.get_bodypart(BODY_ZONE_L_LEG)
	leg.apply_custom_marking(drawing)
	var/datum/bodypart_overlay/custom_marking/overlay = locate() in leg.bodypart_overlays
	overlay.blocks_emissive = EMISSIVE_BLOCK_NONE
	var/image/clipped = overlay.get_image(leg, "", -BODYPARTS_LAYER)
	var/list/split_before = overlay.get_all_overlays(leg)
	var/first_key = json_encode(overlay.icon_render_key(leg))
	leg.markings_alpha = 123
	var/opacity_key = json_encode(overlay.icon_render_key(leg))
	TEST_ASSERT(opacity_key != first_key, "Changing opacity alone must invalidate the final body render key.")
	drawing["tint"] = "#ff0000"
	overlay.set_drawing(drawing, leg)
	var/image/recolored = overlay.get_image(leg, "", -BODYPARTS_LAYER)
	overlay.color_image(recolored, leg, "")
	TEST_ASSERT(!(custom_sprite_paint_icon(drawing) != raw || recolored.icon != clipped.icon), "Tint and opacity changes must reuse the raw and clipped pixel caches.")
	TEST_ASSERT(!(json_encode(overlay.icon_render_key(leg)) == opacity_key || recolored.color != "#ff0000" || recolored.alpha != 123), "Reusing pixel caches must still update the final tint, opacity and render key.")
	var/list/split_after = overlay.get_all_overlays(leg)
	TEST_ASSERT(length(split_before) == length(split_after), "Tint changes must preserve the leg overlay layers.")
	for(var/i in 1 to length(split_before))
		var/image/before = split_before[i]
		var/image/after = split_after[i]
		TEST_ASSERT(!(before.icon != after.icon || after.color != "#ff0000" || after.alpha != 123), "Leg split icons must be reused while their final color and opacity update.")

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

/datum/unit_test/custom_sprite_hair_emissive/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	human.emissive_hair = TRUE
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[human.hairstyle]
	var/datum/hair_mask/hat = allocate(/datum/hair_mask/standard_hat_low)
	human.hair_masks = list(hat)
	head.hair_alpha = 123
	var/icon/paint = head.get_custom_hair_paint(style)
	var/icon/raw = custom_sprite_paint_icon(head.custom_hair)
	for(var/literal in list(FALSE, TRUE))
		head.blocks_emissive = EMISSIVE_BLOCK_NONE
		head.custom_hair["tint"] = literal ? "#ffffff" : null
		head.custom_hair["emissive"] = custom_sprite_emissive_settings(FALSE)
		var/list/off = list()
		head.append_custom_hair_paint_overlays(off, paint, style, FALSE)
		TEST_ASSERT(length(off) == (literal ? 2 : 1), "Both legacy and literal non-emissive paint must receive an independent blocker.")
		var/image/blocker = off[1]
		TEST_ASSERT(!(PLANE_TO_TRUE(blocker.plane) != EMISSIVE_PLANE || json_encode(blocker.color) != json_encode(_EM_BLOCK_COLOR(123 / 255))), "The OFF blocker must use the emissive plane and hair opacity.")
		TEST_ASSERT(custom_sprite_test_same_pixels(icon(blocker.icon), paint), "The OFF blocker must contain the exact masked painted pixels in every direction.")
		var/list/dropped_off = list()
		head.append_custom_hair_paint_overlays(dropped_off, paint, style, TRUE)
		var/image/dropped_blocker = dropped_off[1]
		var/mutable_appearance/fixed_blocker = make_mutable_appearance_directional(blocker, SOUTH)
		TEST_ASSERT(!(dropped_blocker.appearance != fixed_blocker.appearance || blocker.appearance == fixed_blocker.appearance), "Dropped hair blockers must fix their direction while attached blockers inherit the owner's facing.")
		head.custom_hair["emissive"] = custom_sprite_emissive_settings(TRUE)
		head.blocks_emissive = EMISSIVE_BLOCK_UNIQUE
		var/list/on = list()
		head.append_custom_hair_paint_overlays(on, paint, style, TRUE)
		TEST_ASSERT(length(on) == (literal ? 2 : 1), "Emitting paint must replace its blocker so partial opacity is applied only once.")
		var/image/glow = on[length(on)]
		TEST_ASSERT(!(PLANE_TO_TRUE(glow.plane) != EMISSIVE_PLANE || glow.dir != SOUTH || json_encode(glow.color) != json_encode(_EMISSIVE_COLOR(123 / 255))), "The ON mask must use the emissive plane, hair opacity and detached-head direction.")
		TEST_ASSERT(custom_sprite_test_same_pixels(icon(glow.icon), paint), "The ON mask must contain the exact masked painted pixels in every direction.")
		var/mutable_appearance/fixed_glow = make_mutable_appearance_directional(glow, SOUTH)
		TEST_ASSERT(glow.appearance == fixed_glow.appearance, "Dropped hair emission must preserve the visible paint's fixed South direction flag.")
		TEST_ASSERT(!(glow.pixel_x != blocker.pixel_x || glow.pixel_z != blocker.pixel_z || custom_sprite_paint_icon(head.custom_hair) != raw), "Changing custom emission must retain offsets and reuse raw pixel caches.")
	// The normal base hair emission must use authored pixels even when legacy paint is merged visually.
	head.custom_hair["tint"] = null
	head.custom_hair["emissive"] = custom_sprite_emissive_settings(TRUE)
	var/list/hair_overlays = head.get_hair_overlays()
	var/found_authored_emission = FALSE
	var/found_authored_blocker = FALSE
	for(var/image/overlay as anything in hair_overlays)
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && json_encode(overlay.color) == json_encode(_EM_BLOCK_COLOR(123 / 255)))
			found_authored_blocker = TRUE
			TEST_ASSERT(custom_sprite_test_same_pixels(icon(overlay.icon), style.getCachedIcon(human.hair_masks)), "The base blocker must not add another opacity mask for legacy custom paint.")
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && overlay.icon_state == "_e")
			found_authored_emission = TRUE
			TEST_ASSERT(custom_sprite_test_same_pixels(icon(overlay.icon), style.getCachedIcon(human.hair_masks)), "Base emissive hair must not inherit the legacy custom drawing pixels.")
	TEST_ASSERT(!(!found_authored_emission || !found_authored_blocker), "The fixture must exercise both authored base hair masks.")

/datum/unit_test/custom_sprite_marking_emissive/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/list/drawing = custom_sprite_test_drawing()
	var/icon/raw = custom_sprite_paint_icon(drawing)
	for(var/zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/limb = human.get_bodypart(zone)
		limb.markings_alpha = 123
		limb.apply_custom_marking(drawing)
		var/datum/bodypart_overlay/custom_marking/overlay = locate() in limb.bodypart_overlays
		var/old_key = json_encode(overlay.icon_render_key(limb))
		var/list/off = overlay.get_all_overlays(limb)
		drawing["emissive"] = custom_sprite_emissive_settings(TRUE)
		overlay.set_drawing(drawing, limb)
		var/list/on = overlay.get_all_overlays(limb)
		TEST_ASSERT(!(json_encode(overlay.icon_render_key(limb)) == old_key || custom_sprite_paint_icon(drawing) != raw), "Emission must invalidate the final limb key without rebuilding paint pixels.")
		var/visible_count = 0
		var/mask_count = 0
		for(var/image/visible as anything in off)
			if(PLANE_TO_TRUE(visible.plane) == EMISSIVE_PLANE)
				continue
			visible_count++
			var/found = FALSE
			for(var/image/glow as anything in on)
				if(PLANE_TO_TRUE(glow.plane) != EMISSIVE_PLANE || json_encode(glow.color) != json_encode(_EMISSIVE_COLOR(123 / 255)))
					continue
				if(glow.icon == visible.icon && glow.layer == visible.layer)
					found = TRUE
					mask_count++
			TEST_ASSERT(found, "Every clipped or split [zone] overlay must reuse its exact icon and layer for emission.")
		TEST_ASSERT(!(!visible_count || mask_count != visible_count || length(on) != 2 * visible_count), "Emission must replace blockers with one mask per visible limb/leg layer.")
		for(var/image/mask as anything in on)
			TEST_ASSERT(!(PLANE_TO_TRUE(mask.plane) == EMISSIVE_PLANE && json_encode(mask.color) == json_encode(_EM_BLOCK_COLOR(123 / 255))), "Emitting markings must not retain a blocker that applies partial opacity twice.")
		drawing["emissive"] = custom_sprite_emissive_settings(FALSE)

/datum/unit_test/custom_sprite_emissive_grouping/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/icon/paint = custom_sprite_paint_icon(custom_sprite_test_drawing())
	var/image/visible = image(paint, layer = -HAIR_LAYER)
	visible.pixel_x = 5
	visible.pixel_z = -3
	visible.alpha = 123
	var/mutable_appearance/mask = custom_sprite_emissive_mask(visible, human, TRUE)
	var/mutable_appearance/inherited_mask = emissive_appearance(visible.icon, visible.icon_state, human, visible.layer, visible.alpha)
	inherited_mask.pixel_x = visible.pixel_x
	inherited_mask.pixel_z = visible.pixel_z
	// BYOND reports South for both; assigning dir changes hidden inheritance state.
	TEST_ASSERT(mask.appearance == inherited_mask.appearance, "Attached paint masks must inherit direction through the neutral group, not copy the image's default South.")
	for(var/cache_layer in list(HAIR_LAYER, BODYPARTS_LAYER))
		var/list/prepared = human.prepare_worn_emissive_overlays(cache_layer, list(visible, mask))
		var/mutable_appearance/group = prepared[2]
		TEST_ASSERT(!(length(prepared) != 2 || group.icon || length(group.overlays) != 1 || PLANE_TO_TRUE(group.plane) != EMISSIVE_PLANE || group.pixel_x || group.pixel_z), "Hair and marking masks must use the existing neutral plane boundary for standing/resting transforms.")
		var/mutable_appearance/inner = group.overlays[1]
		TEST_ASSERT(!(inner.icon != visible.icon || inner.pixel_x != visible.pixel_x || inner.pixel_z != visible.pixel_z || inner.plane != FLOAT_PLANE || (inner.appearance_flags & KEEP_APART)), "Paint placement must stay inside the shared emissive group so it rotates with the visible pixels.")
		TEST_ASSERT(!(mask.pixel_x != 5 || mask.pixel_z != -3 || PLANE_TO_TRUE(mask.plane) != EMISSIVE_PLANE), "Shared grouping must not mutate the cached source mask.")

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
				var/list/prepared = human.prepare_worn_emissive_overlays(overlays == hair_overlays ? HAIR_LAYER : BODYPARTS_LAYER, list(mask))
				var/mutable_appearance/group = prepared[1]
				TEST_ASSERT(!(length(prepared) != 1 || group.icon || length(group.overlays) != 1 || PLANE_TO_TRUE(group.plane) != EMISSIVE_PLANE), "Directional masks must retain one inner appearance inside the neutral emissive group.")
				var/mutable_appearance/inner = group.overlays[1]
				TEST_ASSERT(!(inner.plane != FLOAT_PLANE || !custom_sprite_test_same_pixels(icon(inner.icon), mask_icon)), "The prepared inner mask must preserve every selected and blank directional frame.")
				var/mutable_appearance/expected_inner = new(mask)
				expected_inner.plane = FLOAT_PLANE
				expected_inner.appearance_flags &= ~KEEP_APART
				TEST_ASSERT(inner.appearance == expected_inner.appearance, "Shared grouping must preserve the mask's directional inheritance, offsets and opacity.")
			TEST_ASSERT(!(!emitting_masks || emitting_masks != blocking_masks), "Mixed per-view settings must generate complementary emission and blocker masks.")
		var/icon/cached = custom_sprite_directional_mask(paint, "native-directional-cache", settings, TRUE)
		TEST_ASSERT(!(custom_sprite_directional_mask(paint, "native-directional-cache", settings, TRUE) != cached || custom_sprite_paint_icon(drawing) != paint), "Repeated masks must reuse directional caches without replacing visible paint pixels.")
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

/datum/unit_test/custom_sprite_emissive_ownership/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.dna.custom_markings = custom_sprite_test_drawing()
	human.dna.custom_hair["emissive"] = custom_sprite_emissive_settings(TRUE)
	human.dna.custom_markings["emissive"] = custom_sprite_emissive_settings(TRUE)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	head.drop_limb(special = TRUE)
	arm.drop_limb(special = TRUE)
	human.dna.custom_hair["emissive"] = custom_sprite_emissive_settings(FALSE)
	human.dna.custom_markings["emissive"] = custom_sprite_emissive_settings(FALSE)
	human.regenerate_limb(BODY_ZONE_HEAD)
	human.regenerate_limb(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/head/regrown_head = human.get_bodypart(BODY_ZONE_HEAD)
	var/obj/item/bodypart/regrown_arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/detached = locate() in arm.bodypart_overlays
	var/datum/bodypart_overlay/custom_marking/regrown = locate() in regrown_arm.bodypart_overlays
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT(!(!head.custom_hair?["emissive"]?["[direction]"] || !detached?.drawing?["emissive"]?["[direction]"] || regrown_head.custom_hair?["emissive"]?["[direction]"] || regrown?.drawing?["emissive"]?["[direction]"]), "Detached parts must retain their emission snapshots while regenerated parts inherit current DNA.")

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
		var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ffffff"), custom_sprite_body_draw_bounds(human, body_zone), mask)
		for(var/direction in GLOB.cardinals)
			for(var/y in 0 to 31)
				for(var/x in 0 to 31)
					TEST_ASSERT(!!workspace.is_point_allowed(x, y, "[direction]") == !!silhouette.GetPixel(x + 1, 32 - y, "", direction), "Editor pixels must match [body_zone]'s rendered silhouette in direction [direction].")
	human.dna.custom_markings = custom_sprite_test_drawing()
	human.dna.custom_limb_markings = list(BODY_ZONE_L_ARM = custom_sprite_test_drawing("2"))
	human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["emissive"] = custom_sprite_emissive_settings(TRUE)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/zone_overlay = locate() in arm.bodypart_overlays
	TEST_ASSERT(!(!zone_overlay || length(arm.bodypart_overlays) < 2), "A limb needs separate whole-body and zone overlays.")
	var/zone_hash = zone_overlay.drawing_hash
	human.dna.custom_markings = null
	human.sync_custom_sprite_appearance()
	TEST_ASSERT(!(QDELETED(zone_overlay) || zone_overlay.drawing_hash != zone_hash), "Removing whole-body paint must preserve the limb overlay.")
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
	human.dna.custom_markings = custom_sprite_test_wide_drawing()
	human.dna.custom_limb_markings = list("taur" = custom_sprite_test_wide_drawing(repeat_string(64, "2")))
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/chest = human.get_bodypart(BODY_ZONE_CHEST)
	var/datum/bodypart_overlay/custom_marking/whole
	var/datum/bodypart_overlay/custom_marking/zone
	for(var/datum/bodypart_overlay/custom_marking/marking in chest.bodypart_overlays)
		if(marking.type == text2path("/datum/bodypart_overlay/custom_marking/taur"))
			whole = marking
		if(marking.type == text2path("/datum/bodypart_overlay/custom_marking/taur/zone"))
			zone = marking
	TEST_ASSERT(!(!whole || !zone), "Whole-body and taur-zone paint need separate overlays on the taur organ's chest.")
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
		var/image/painted = whole.get_image(chest, layer_index, -layer_number)
		var/image/zoned = zone.get_image(chest, layer_index, -layer_number)
		var/icon/paint = icon(painted.icon)
		var/icon/zone_paint = icon(zoned.icon)
		var/icon/zone_expected = icon(expected)
		zone_expected.Blend("#123456", ICON_MULTIPLY)
		TEST_ASSERT(!(paint.Width() != 64 || paint.Height() != 32 || painted.pixel_x + painted.pixel_w != -16 || zoned.pixel_x + zoned.pixel_w != -16 || painted.layer != -layer_number), "Taur paint must use each native layer and its 64 by 32 canvas at offset -16.")
		for(var/direction in GLOB.cardinals)
			for(var/y in 1 to 32)
				for(var/x in 1 to 64)
					TEST_ASSERT(!(paint.GetPixel(x, y, "", direction) != expected.GetPixel(x, y, "", direction) || zone_paint.GetPixel(x, y, "", direction) != zone_expected.GetPixel(x, y, "", direction)), "Whole-body and taur-zone pixels must match the actual organ geometry in every layer and direction.")
					if(expected.GetPixel(x, y, "", direction))
						painted_directions["[direction]"] = TRUE
						if(x <= 16 || x > 48)
							outer_pixels["[direction]"] = TRUE
	TEST_ASSERT(!(length(painted_directions) != 4 || !outer_pixels["[EAST]"] || !outer_pixels["[WEST]"]), "The taur fixture must exercise all four directions and the outer canvas on its wide side views.")
	var/zone_hash = zone.drawing_hash
	human.dna.custom_markings = null
	human.sync_custom_sprite_appearance()
	TEST_ASSERT(!(QDELETED(zone) || zone.drawing_hash != zone_hash || !QDELETED(whole)), "Clearing whole-body paint must preserve the separate taur-zone snapshot.")

/datum/unit_test/custom_sprite_wide_limb_crop/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/list/drawing = custom_sprite_test_wide_drawing("[repeat_string(16, "2")][repeat_string(32, "1")][repeat_string(16, "2")]")
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	arm.apply_custom_marking(drawing)
	var/datum/bodypart_overlay/custom_marking/marking = locate() in arm.bodypart_overlays
	var/image/painted = marking.get_image(arm, "", -BODYPARTS_LAYER)
	var/icon/paint = icon(painted.icon)
	TEST_ASSERT(!(paint.Width() != 32 || paint.Height() != 32 || painted.pixel_x || painted.pixel_w || !custom_sprite_test_same_pixels(paint, custom_sprite_silhouette(arm))), "Ordinary limbs must crop columns 17 through 48 of wide paint before applying their unchanged 32-pixel masks.")

/datum/unit_test/custom_sprite_taur_emission/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(human)
	var/list/drawing = custom_sprite_test_wide_drawing()
	human.dna.custom_markings = drawing
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/chest = human.get_bodypart(BODY_ZONE_CHEST)
	var/datum/bodypart_overlay/custom_marking/taur/marking = locate() in chest.bodypart_overlays
	TEST_ASSERT(marking, "The emissive fixture needs a real taur marking overlay.")
	for(var/selected_direction in GLOB.cardinals)
		drawing["emissive"] = custom_sprite_emissive_settings(FALSE)
		drawing["emissive"]["[selected_direction]"] = TRUE
		marking.set_drawing(drawing, chest)
		var/list/overlays = marking.get_all_overlays(chest)
		var/mask_count = 0
		for(var/image/mask as anything in overlays)
			if(PLANE_TO_TRUE(mask.plane) != EMISSIVE_PLANE)
				continue
			mask_count++
			var/image/visible
			for(var/image/candidate as anything in overlays)
				if(PLANE_TO_TRUE(candidate.plane) != EMISSIVE_PLANE && candidate.layer == mask.layer)
					visible = candidate
					break
			var/icon/mask_icon = icon(mask.icon)
			var/icon/visible_icon = icon(visible?.icon)
			TEST_ASSERT(!(!visible || mask_icon.Width() != 64 || mask_icon.Height() != 32 || mask.pixel_w != visible.pixel_w || mask.pixel_w != -16), "Each taur emission/blocker layer must retain its visible layer's width and native offset.")
			var/glowing = json_encode(mask.color) == json_encode(GLOB.emissive_color)
			for(var/direction in GLOB.cardinals)
				for(var/y in 1 to 32)
					for(var/x in 1 to 64)
						var/expected = ((direction == selected_direction) == glowing) ? visible_icon.GetPixel(x, y, "", direction) : null
						TEST_ASSERT(mask_icon.GetPixel(x, y, "", direction) == expected, "Taur emission must preserve outer pixels and emit/block only the selected directions.")
		TEST_ASSERT(mask_count, "Taur paint must create directional emission and blocker masks.")
	organ.hide_self = TRUE
	TEST_ASSERT(!marking.can_draw_on_bodypart(chest, human), "Hidden taur bodies must also hide their custom paint.")


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
	for(var/name in SSaccessories.facial_hairstyles_list)
		var/datum/sprite_accessory/facial_hair/accessory = SSaccessories.facial_hairstyles_list[name]
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

/// Observe real hair rebuilds without replacing their rendering behavior.
/mob/living/carbon/human/consistent/custom_sprite_hair_update_probe
	/// Hair rebuild count since the test's last reset.
	var/hair_update_count = 0

/mob/living/carbon/human/consistent/custom_sprite_hair_update_probe/update_hair()
	hair_update_count++
	return ..()

/datum/unit_test/custom_sprite_hair_color_batching/Run()
	var/mob/living/carbon/human/consistent/custom_sprite_hair_update_probe/human = allocate(/mob/living/carbon/human/consistent/custom_sprite_hair_update_probe)
	for(var/target in list("hair", "facial_hair"))
		var/facial = target == "facial_hair"
		if(facial)
			human.set_facial_hairstyle(custom_style_test_facial_style(), update = FALSE)
		else
			human.set_hairstyle("Short Hair", update = FALSE)
		for(var/painted in list(FALSE, TRUE))
			if(facial)
				human.set_facial_haircolor("#583820", update = FALSE)
			else
				human.set_haircolor("#583820", update = FALSE)
			var/list/context = custom_style_live_hair_context(human, target)
			var/list/shades = custom_style_hair_shades(context, target)
			var/list/drawing = painted ? custom_style_test_two_color_drawing(shades[1], "#123456") : null
			if(facial)
				human.dna.custom_facial_hair = drawing
			else
				human.dna.custom_hair = drawing
			human.sync_custom_sprite_appearance()
			for(var/update in list(FALSE, TRUE))
				human.hair_update_count = 0
				var/color = update ? "#583820" : "#c0d0e0"
				if(facial)
					human.set_facial_haircolor(color, update = update)
				else
					human.set_haircolor(color, update = update)
				TEST_ASSERT(human.hair_update_count == (update ? 1 : 0), "[target] color changes with painted=[painted], update=[update] must perform exactly [update ? 1 : 0] hair rebuilds, got [human.hair_update_count].")
				var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
				var/list/snapshot = head.custom_head_drawing(target)
				TEST_ASSERT(!(painted && snapshot["palette"][1] == shades[1] && !update), "Batched [target] recoloring must still update the head drawing before its eventual redraw.")
				var/snapshot_before = json_encode(snapshot)
				human.hair_update_count = 0
				if(facial)
					human.set_facial_haircolor("#ff0000", override = TRUE, update = update)
				else
					human.set_haircolor("#ff0000", override = TRUE, update = update)
				TEST_ASSERT(!(human.hair_update_count != (update ? 1 : 0) || json_encode(head.custom_head_drawing(target)) != snapshot_before), "Temporary [target] overrides must honor batching without repainting the drawing.")

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

/datum/unit_test/custom_sprite_hair_ambiguous_recolor/Run()
	var/list/old_hair = custom_style_test_hair("Short Hair")
	old_hair["color"] = "#000000"
	var/list/new_hair = old_hair.Copy()
	new_hair["color"] = "#010101"
	var/list/old_shades = custom_style_hair_shades(old_hair)
	var/list/new_shades = custom_style_hair_shades(new_hair)
	TEST_ASSERT(!(length(old_shades) < 2 || !("#000000" in new_shades) || !("#010101" in new_shades)), "The fixture must contain collapsed black shades with both unchanged and changed destinations.")
	var/list/map = custom_style_hair_color_map(old_hair, new_hair, null)
	TEST_ASSERT(!map?["#000000"], "An unchanged shade must participate in ambiguity detection so collapsed black paint stays unchanged.")
	TEST_ASSERT(!custom_style_hair_color_map(old_hair, old_hair, null), "Identity-only shade maps must be omitted.")

/datum/unit_test/custom_sprite_hair_gradient_opacity/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.set_hairstyle(/datum/sprite_accessory/hair/bedhead::name, update = FALSE)
	human.set_facial_hairstyle(custom_style_test_facial_style(), update = FALSE)
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/full::name, update = FALSE)
	human.set_facial_hair_gradient_style(/datum/sprite_accessory/gradient/full::name, update = FALSE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	head.hair_alpha = 160
	head.facial_hair_alpha = 90
	for(var/target in list("hair", "facial_hair"))
		var/facial = target == "facial_hair"
		var/list/drawing = custom_sprite_test_drawing()
		drawing["tint"] = "#ffffff"
		drawing["emissive"] = custom_sprite_emissive_settings(TRUE)
		if(facial)
			head.custom_facial_hair = drawing
		else
			head.custom_hair = drawing
		var/datum/sprite_accessory/style = facial ? head.custom_sprite_facial_hair_accessory() : head.custom_sprite_hair_accessory()
		var/icon/paint = head.get_custom_hair_paint(style, target)
		for(var/dropped in list(FALSE, TRUE))
			var/list/overlays = list()
			head.append_custom_hair_paint_overlays(overlays, paint, style, dropped, target)
			var/list/visible = list()
			var/emissive_count = 0
			for(var/image/overlay as anything in overlays)
				if(PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE)
					visible += overlay
					continue
				emissive_count++
				TEST_ASSERT(json_encode(overlay.color) == json_encode(_EMISSIVE_COLOR((facial ? 90 : 160) / 255)), "The separate [target] emission mask must retain the target's opacity after grouping visible paint.")
			TEST_ASSERT(emissive_count == 1, "Grouped [target] paint must keep its emission mask outside the visible opacity group.")
			TEST_ASSERT(length(visible) == 1, "Translucent [target] paint and gradient must form one visible opacity group.")
			var/image/group = visible[1]
			TEST_ASSERT(!(!(group.appearance_flags & KEEP_TOGETHER) || group.alpha != (facial ? 90 : 160) || length(group.overlays) != 2), "[target] must apply its opacity once to the combined paint and gradient.")
			for(var/image/child as anything in group.overlays)
				TEST_ASSERT(child.alpha == 255, "Grouped [target] paint and gradient must remain opaque before group opacity is applied.")
	// Native scalp hair must use the same opacity as its paint, independently of beard opacity.
	head.custom_hair = null
	head.custom_facial_hair = null
	human.set_facial_hairstyle("Shaved", update = FALSE)
	var/found_native_group = FALSE
	for(var/image/group as anything in head.get_hair_overlays())
		if(!(group.appearance_flags & KEEP_TOGETHER) || PLANE_TO_TRUE(group.plane) == EMISSIVE_PLANE)
			continue
		found_native_group = TRUE
		TEST_ASSERT(group.alpha == 160, "Native scalp gradients must use scalp opacity, independently of facial hair opacity.")
	TEST_ASSERT(found_native_group, "The opacity fixture must exercise the native scalp gradient group.")

/datum/unit_test/custom_sprite_unpainted_beard_resource/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.set_facial_hairstyle(custom_style_test_facial_style(), update = FALSE)
	human.set_facial_hair_gradient_style(SPRITE_ACCESSORY_NONE, update = FALSE)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/style = head.custom_sprite_facial_hair_accessory()
	var/found_resource = FALSE
	for(var/image/overlay as anything in head.get_hair_overlays())
		if(PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE && overlay.icon == style.icon && overlay.icon_state == style.icon_state)
			found_resource = TRUE
	TEST_ASSERT(found_resource, "Unpainted beards must use their authored icon resource and state without allocating a mutable icon.")
