#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

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

/datum/unit_test/custom_sprite_rendering/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.dna.custom_markings = custom_sprite_test_drawing()
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance()
	human.update_body(is_creating = TRUE)
	var/list/bounds = custom_sprite_body_draw_bounds(human)
	for(var/direction in GLOB.cardinals)
		if(!bounds["[direction]"])
			Fail("Body bounds must include every cardinal direction.", __FILE__, __LINE__)
	for(var/obj/item/bodypart/limb as anything in human.bodyparts)
		var/datum/bodypart_overlay/custom_marking/overlay = locate() in limb.bodypart_overlays
		if(!overlay)
			Fail("Every limb must receive its drawing snapshot.", __FILE__, __LINE__)
			continue
		var/image/clipped = overlay.get_image(limb, "", -BODYPARTS_LAYER)
		if(!custom_sprite_test_same_pixels(icon(clipped.icon), custom_sprite_silhouette(limb)))
			Fail("Solid paint must be clipped exactly to [limb.body_zone]'s silhouette in every direction.", __FILE__, __LINE__)
		var/first_key = json_encode(overlay.icon_render_key(limb))
		overlay.set_drawing(custom_sprite_test_drawing("2"), limb)
		if(first_key == json_encode(overlay.icon_render_key(limb)))
			Fail("Different drawings collided in the limb cache.", __FILE__, __LINE__)
		var/image/different = overlay.get_image(limb, "", -BODYPARTS_LAYER)
		if(custom_sprite_test_same_pixels(icon(clipped.icon), icon(different.icon)))
			Fail("Different drawings reused another player's clipped pixels.", __FILE__, __LINE__)
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
			if(!upper || !lower || !custom_sprite_test_same_pixels(recombined, icon(clipped.icon)))
				Fail("The two leg layers must preserve the clipped drawing.", __FILE__, __LINE__)
		limb.is_husked = HUSKED_BURN
		if(overlay.can_draw_on_bodypart(limb, human))
			Fail("Custom markings must stay hidden on husks.", __FILE__, __LINE__)
		limb.is_husked = initial(limb.is_husked)
		var/shape = limb.bodyshape
		limb.bodyshape |= BODYSHAPE_TAUR
		if(overlay.can_draw_on_bodypart(limb, human))
			Fail("Taur limbs must not render unsupported markings.", __FILE__, __LINE__)
		limb.bodyshape = shape
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(special = TRUE)
	var/datum/bodypart_overlay/custom_marking/detached = locate() in arm.bodypart_overlays
	if(!detached?.drawing)
		Fail("Detached limbs must retain their own drawing.", __FILE__, __LINE__)
	human.regenerate_limb(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/regrown = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/regrown_overlay = locate() in regrown.bodypart_overlays
	if(!regrown_overlay?.drawing)
		Fail("Regenerated limbs must inherit DNA drawings.", __FILE__, __LINE__)

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
	if(json_encode(palette) != source_before)
		Fail("Inactive hair gradients and facial-only gradients must not add hair palette colors.", __FILE__, __LINE__)
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/full::name, update = FALSE)
	palette = custom_sprite_sample_hair_palette(style, head)
	if(!("#12abef" in palette) || ("#fedcba" in palette))
		Fail("An active hair gradient must add its canonical color without the facial gradient.", __FILE__, __LINE__)
	if(json_encode(source) != source_before || json_encode(custom_sprite_sample_palette(style.icon, style.icon_state)) != source_before)
		Fail("Adding gradient swatches must not modify shared source palette lists.", __FILE__, __LINE__)
	human.set_hair_gradient_color(source[1], update = FALSE)
	if(length(custom_sprite_sample_hair_palette(style, head)) != length(source))
		Fail("Gradient colors already present among source shades must not be duplicated.", __FILE__, __LINE__)
	// Species presets use these same setters (for example the protean preview).
	human.set_hair_gradient_style(/datum/sprite_accessory/gradient/reflected_inverse::name, update = FALSE)
	human.set_hair_gradient_color("#685064", update = FALSE)
	if(!(head.get_hair_gradient_color(GRADIENT_HAIR_KEY) in custom_sprite_sample_hair_palette(style, head)))
		Fail("The palette must use the active head gradient, including species preset values.", __FILE__, __LINE__)
	human.set_hair_gradient_style("invalid-gradient-fixture", update = FALSE)
	if(json_encode(custom_sprite_sample_hair_palette(style, head)) != source_before)
		Fail("An unregistered gradient style must not add a color.", __FILE__, __LINE__)
	head.hair_color = "#804020"
	palette = custom_sprite_sample_hair_palette(null, head)
	if(palette[1] != "#804020" || ("#ffffff" in palette))
		Fail("Automatic hair swatches must contain the actual hair colors for literal painting.", __FILE__, __LINE__)
	head.fixed_hair_color = "#123456"
	palette = custom_sprite_sample_hair_palette(null, head)
	if(palette[1] != "#123456")
		Fail("Automatic swatches must respect fixed species hair colors.", __FILE__, __LINE__)
	head.override_hair_color = "#abcdef"
	palette = custom_sprite_sample_hair_palette(null, head)
	if(palette[1] != "#abcdef")
		Fail("Automatic swatches must respect hair color overrides.", __FILE__, __LINE__)

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
	if(opacity_key == first_key)
		Fail("Changing opacity alone must invalidate the final body render key.", __FILE__, __LINE__)
	drawing["tint"] = "#ff0000"
	overlay.set_drawing(drawing, leg)
	var/image/recolored = overlay.get_image(leg, "", -BODYPARTS_LAYER)
	overlay.color_image(recolored, leg, "")
	if(custom_sprite_paint_icon(drawing) != raw || recolored.icon != clipped.icon)
		Fail("Tint and opacity changes must reuse the raw and clipped pixel caches.", __FILE__, __LINE__)
	if(json_encode(overlay.icon_render_key(leg)) == opacity_key || recolored.color != "#ff0000" || recolored.alpha != 123)
		Fail("Reusing pixel caches must still update the final tint, opacity and render key.", __FILE__, __LINE__)
	var/list/split_after = overlay.get_all_overlays(leg)
	if(length(split_before) != length(split_after))
		return Fail("Tint changes must preserve the leg overlay layers.", __FILE__, __LINE__)
	for(var/i in 1 to length(split_before))
		var/image/before = split_before[i]
		var/image/after = split_after[i]
		if(before.icon != after.icon || after.color != "#ff0000" || after.alpha != 123)
			Fail("Leg split icons must be reused while their final color and opacity update.", __FILE__, __LINE__)

/datum/unit_test/custom_sprite_head_snapshot/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	human.dna.custom_hair = custom_sprite_test_drawing()
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/list/snapshot = head.custom_hair
	if(!snapshot || snapshot == human.dna.custom_hair || json_encode(snapshot) != json_encode(human.dna.custom_hair))
		Fail("Synchronizing with a body refresh must create an independent head drawing snapshot.", __FILE__, __LINE__)
	human.dna.custom_hair["tint"] = "#ff0000"
	head.copy_appearance_from(human)
	if(head.custom_hair == snapshot || snapshot["tint"] || head.custom_hair["tint"] != "#ff0000")
		Fail("Changed DNA must replace the head snapshot without mutating the old data.", __FILE__, __LINE__)
	head.drop_limb(special = TRUE)
	human.dna.custom_hair["tint"] = "#0000ff"
	human.regenerate_limb(BODY_ZONE_HEAD)
	var/obj/item/bodypart/head/regrown = human.get_bodypart(BODY_ZONE_HEAD)
	if(regrown?.custom_hair?["tint"] != "#0000ff" || head.custom_hair["tint"] != "#ff0000" || regrown.custom_hair == human.dna.custom_hair)
		Fail("Detached and regenerated heads must retain independent drawing ownership.", __FILE__, __LINE__)
	human.dna.custom_hair = null
	human.sync_custom_sprite_appearance()
	if(regrown.custom_hair)
		Fail("Synchronizing a cleared drawing must clear the head snapshot without a body refresh.", __FILE__, __LINE__)

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
		head.append_custom_hair_tint_overlays(off, paint, style, FALSE)
		if(length(off) != (literal ? 2 : 1))
			Fail("Both legacy and literal non-emissive paint must receive an independent blocker.", __FILE__, __LINE__)
		var/image/blocker = off[1]
		if(PLANE_TO_TRUE(blocker.plane) != EMISSIVE_PLANE || json_encode(blocker.color) != json_encode(_EM_BLOCK_COLOR(123 / 255)))
			Fail("The OFF blocker must use the emissive plane and hair opacity.", __FILE__, __LINE__)
		if(!custom_sprite_test_same_pixels(icon(blocker.icon), paint))
			Fail("The OFF blocker must contain the exact masked painted pixels in every direction.", __FILE__, __LINE__)
		var/list/dropped_off = list()
		head.append_custom_hair_tint_overlays(dropped_off, paint, style, TRUE)
		var/image/dropped_blocker = dropped_off[1]
		var/mutable_appearance/fixed_blocker = make_mutable_appearance_directional(blocker, SOUTH)
		if(dropped_blocker.appearance != fixed_blocker.appearance || blocker.appearance == fixed_blocker.appearance)
			Fail("Dropped hair blockers must fix their direction while attached blockers inherit the owner's facing.", __FILE__, __LINE__)
		head.custom_hair["emissive"] = custom_sprite_emissive_settings(TRUE)
		head.blocks_emissive = EMISSIVE_BLOCK_UNIQUE
		var/list/on = list()
		head.append_custom_hair_tint_overlays(on, paint, style, TRUE)
		if(length(on) != (literal ? 2 : 1))
			Fail("Emitting paint must replace its blocker so partial opacity is applied only once.", __FILE__, __LINE__)
		var/image/glow = on[length(on)]
		if(PLANE_TO_TRUE(glow.plane) != EMISSIVE_PLANE || glow.dir != SOUTH || json_encode(glow.color) != json_encode(_EMISSIVE_COLOR(123 / 255)))
			Fail("The ON mask must use the emissive plane, hair opacity and detached-head direction.", __FILE__, __LINE__)
		if(!custom_sprite_test_same_pixels(icon(glow.icon), paint))
			Fail("The ON mask must contain the exact masked painted pixels in every direction.", __FILE__, __LINE__)
		var/mutable_appearance/fixed_glow = make_mutable_appearance_directional(glow, SOUTH)
		if(glow.appearance != fixed_glow.appearance)
			Fail("Dropped hair emission must preserve the visible paint's fixed South direction flag.", __FILE__, __LINE__)
		if(glow.pixel_x != blocker.pixel_x || glow.pixel_z != blocker.pixel_z || custom_sprite_paint_icon(head.custom_hair) != raw)
			Fail("Changing custom emission must retain offsets and reuse raw pixel caches.", __FILE__, __LINE__)
	// The normal base hair emission must use authored pixels even when legacy paint is merged visually.
	head.custom_hair["tint"] = null
	head.custom_hair["emissive"] = custom_sprite_emissive_settings(TRUE)
	var/list/hair_overlays = head.get_hair_overlays()
	var/found_authored_emission = FALSE
	var/found_authored_blocker = FALSE
	for(var/image/overlay as anything in hair_overlays)
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && json_encode(overlay.color) == json_encode(_EM_BLOCK_COLOR(123 / 255)))
			found_authored_blocker = TRUE
			if(!custom_sprite_test_same_pixels(icon(overlay.icon), style.getCachedIcon(human.hair_masks)))
				Fail("The base blocker must not add another opacity mask for legacy custom paint.", __FILE__, __LINE__)
		if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && overlay.icon_state == "_e")
			found_authored_emission = TRUE
			if(!custom_sprite_test_same_pixels(icon(overlay.icon), style.getCachedIcon(human.hair_masks)))
				Fail("Base emissive hair must not inherit the legacy custom drawing pixels.", __FILE__, __LINE__)
	if(!found_authored_emission || !found_authored_blocker)
		Fail("The fixture must exercise both authored base hair masks.", __FILE__, __LINE__)

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
		if(json_encode(overlay.icon_render_key(limb)) == old_key || custom_sprite_paint_icon(drawing) != raw)
			Fail("Emission must invalidate the final limb key without rebuilding paint pixels.", __FILE__, __LINE__)
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
			if(!found)
				Fail("Every clipped or split [zone] overlay must reuse its exact icon and layer for emission.", __FILE__, __LINE__)
		if(!visible_count || mask_count != visible_count || length(on) != 2 * visible_count)
			Fail("Emission must replace blockers with one mask per visible limb/leg layer.", __FILE__, __LINE__)
		for(var/image/mask as anything in on)
			if(PLANE_TO_TRUE(mask.plane) == EMISSIVE_PLANE && json_encode(mask.color) == json_encode(_EM_BLOCK_COLOR(123 / 255)))
				Fail("Emitting markings must not retain a blocker that applies partial opacity twice.", __FILE__, __LINE__)
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
	if(mask.appearance != inherited_mask.appearance)
		Fail("Attached paint masks must inherit direction through the neutral group, not copy the image's default South.", __FILE__, __LINE__)
	for(var/cache_layer in list(HAIR_LAYER, BODYPARTS_LAYER))
		var/list/prepared = human.prepare_worn_emissive_overlays(cache_layer, list(visible, mask))
		var/mutable_appearance/group = prepared[2]
		if(length(prepared) != 2 || group.icon || length(group.overlays) != 1 || PLANE_TO_TRUE(group.plane) != EMISSIVE_PLANE || group.pixel_x || group.pixel_z)
			Fail("Hair and marking masks must use the existing neutral plane boundary for standing/resting transforms.", __FILE__, __LINE__)
		var/mutable_appearance/inner = group.overlays[1]
		if(inner.icon != visible.icon || inner.pixel_x != visible.pixel_x || inner.pixel_z != visible.pixel_z || inner.plane != FLOAT_PLANE || (inner.appearance_flags & KEEP_APART))
			Fail("Paint placement must stay inside the shared emissive group so it rotates with the visible pixels.", __FILE__, __LINE__)
		if(mask.pixel_x != 5 || mask.pixel_z != -3 || PLANE_TO_TRUE(mask.plane) != EMISSIVE_PLANE)
			Fail("Shared grouping must not mutate the cached source mask.", __FILE__, __LINE__)

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
		head.append_custom_hair_tint_overlays(hair_overlays, paint, style, FALSE)
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
				if(!visible)
					Fail("Directional masks need a matching visible paint layer.", __FILE__, __LINE__)
					continue
				var/icon/mask_icon = icon(mask.icon)
				var/icon/visible_icon = icon(visible.icon)
				for(var/direction in GLOB.cardinals)
					for(var/x in 1 to 32)
						for(var/y in 1 to 32)
							var/expected = ((direction == selected_direction) == glowing) ? visible_icon.GetPixel(x, y, "", direction) : null
							if(mask_icon.GetPixel(x, y, "", direction) != expected)
								return Fail("Hair and split-leg masks must emit only the selected facing and block only the other views.", __FILE__, __LINE__)
				var/list/prepared = human.prepare_worn_emissive_overlays(overlays == hair_overlays ? HAIR_LAYER : BODYPARTS_LAYER, list(mask))
				var/mutable_appearance/group = prepared[1]
				if(length(prepared) != 1 || group.icon || length(group.overlays) != 1 || PLANE_TO_TRUE(group.plane) != EMISSIVE_PLANE)
					return Fail("Directional masks must retain one inner appearance inside the neutral emissive group.", __FILE__, __LINE__)
				var/mutable_appearance/inner = group.overlays[1]
				if(inner.plane != FLOAT_PLANE || !custom_sprite_test_same_pixels(icon(inner.icon), mask_icon))
					return Fail("The prepared inner mask must preserve every selected and blank directional frame.", __FILE__, __LINE__)
				var/mutable_appearance/expected_inner = new(mask)
				expected_inner.plane = FLOAT_PLANE
				expected_inner.appearance_flags &= ~KEEP_APART
				if(inner.appearance != expected_inner.appearance)
					return Fail("Shared grouping must preserve the mask's directional inheritance, offsets and opacity.", __FILE__, __LINE__)
			if(!emitting_masks || emitting_masks != blocking_masks)
				Fail("Mixed per-view settings must generate complementary emission and blocker masks.", __FILE__, __LINE__)
		var/icon/cached = custom_sprite_directional_mask(paint, "native-directional-cache", settings, TRUE)
		if(custom_sprite_directional_mask(paint, "native-directional-cache", settings, TRUE) != cached || custom_sprite_paint_icon(drawing) != paint)
			Fail("Repeated masks must reuse directional caches without replacing visible paint pixels.", __FILE__, __LINE__)
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
	if(!dropped_visible || !dropped_glow)
		return Fail("The detached leg fixture must retain visible paint and its selected emission.", __FILE__, __LINE__)
	var/icon/dropped_paint = icon(dropped_visible.icon)
	var/icon/dropped_mask = icon(dropped_glow.icon)
	for(var/direction in GLOB.cardinals)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				var/expected = detached.drawing["emissive"]["[direction]"] ? dropped_paint.GetPixel(x, y, "", direction) : null
				if(dropped_mask.GetPixel(x, y, "", direction) != expected)
					return Fail("A detached leg must not reuse its attached upper-half directional mask.", __FILE__, __LINE__)

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
		if(!head.custom_hair?["emissive"]?["[direction]"] || !detached?.drawing?["emissive"]?["[direction]"] || regrown_head.custom_hair?["emissive"]?["[direction]"] || regrown?.drawing?["emissive"]?["[direction]"])
			Fail("Detached parts must retain their emission snapshots while regenerated parts inherit current DNA.", __FILE__, __LINE__)

/datum/unit_test/custom_sprite_hair_cache/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[human.hairstyle]
	var/icon/shared_before = icon(style.getCachedIcon())
	human.dna.custom_hair = custom_sprite_test_drawing()
	head.copy_appearance_from(human)
	var/icon/paint = head.get_custom_hair_paint(style)
	if(!paint || paint.GetPixel(16, 16, "", SOUTH) != "#ffffff")
		Fail("Stored paint must produce a directional icon.", __FILE__, __LINE__)
	head.get_hair_overlays()
	if(!custom_sprite_test_same_pixels(shared_before, style.getCachedIcon()))
		Fail("Drawing hair mutated the shared hairstyle cache.", __FILE__, __LINE__)
	var/datum/hair_mask/mask = allocate(/datum/hair_mask/standard_hat_low)
	human.hair_masks = list(mask)
	var/icon/expected = icon(paint)
	var/icon/mask_icon = icon(mask.icon, mask.icon_state)
	mask_icon.Shift(SOUTH, style.y_offset)
	expected.Blend(mask_icon, ICON_ADD)
	if(!custom_sprite_test_same_pixels(expected, head.get_custom_hair_paint(style)))
		Fail("Paint must receive the same hat mask as authored hair.", __FILE__, __LINE__)
	human.dna.custom_hair["tint"] = "#ff0000"
	if(head.custom_hair["tint"])
		Fail("Head snapshots must not alias mutable DNA data.", __FILE__, __LINE__)
	var/mob/living/carbon/human/clone = allocate(/mob/living/carbon/human/consistent)
	human.dna.copy_dna(clone.dna)
	if(json_encode(clone.dna.custom_hair) != json_encode(human.dna.custom_hair))
		Fail("DNA copies must preserve hair drawings.", __FILE__, __LINE__)
	clone.dna.custom_hair["tint"] = "#0000ff"
	if(human.dna.custom_hair["tint"] != "#ff0000")
		Fail("DNA copies must own independent drawing data.", __FILE__, __LINE__)

/datum/unit_test/custom_marking_zone_geometry/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	for(var/body_zone in GLOB.custom_marking_zone_labels)
		var/obj/item/bodypart/limb = human.get_bodypart(body_zone)
		var/list/mask = custom_sprite_body_draw_mask(human, body_zone)
		if(mask != custom_sprite_body_draw_mask(human, body_zone))
			Fail("Unchanged limb geometry must reuse its cached mask.", __FILE__, __LINE__)
		var/icon/silhouette = custom_sprite_silhouette(limb)
		if(limb.aux_zone)
			silhouette.Blend(custom_sprite_silhouette(limb, TRUE), ICON_OVERLAY)
		var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ffffff"), custom_sprite_body_draw_bounds(human, body_zone), mask)
		for(var/direction in GLOB.cardinals)
			for(var/y in 0 to 31)
				for(var/x in 0 to 31)
					if(!!workspace.is_point_allowed(x, y, "[direction]") != !!silhouette.GetPixel(x + 1, 32 - y, "", direction))
						return Fail("Editor pixels must match [body_zone]'s rendered silhouette in direction [direction].", __FILE__, __LINE__)
	human.dna.custom_markings = custom_sprite_test_drawing()
	human.dna.custom_limb_markings = list(BODY_ZONE_L_ARM = custom_sprite_test_drawing("2"))
	human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["emissive"] = custom_sprite_emissive_settings(TRUE)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/zone_overlay = locate() in arm.bodypart_overlays
	if(!zone_overlay || length(arm.bodypart_overlays) < 2)
		return Fail("A limb needs separate whole-body and zone overlays.", __FILE__, __LINE__)
	var/zone_hash = zone_overlay.drawing_hash
	human.dna.custom_markings = null
	human.sync_custom_sprite_appearance()
	if(QDELETED(zone_overlay) || zone_overlay.drawing_hash != zone_hash)
		return Fail("Removing whole-body paint must preserve the limb overlay.", __FILE__, __LINE__)
	var/datum/dna/copied_dna = allocate(/datum/dna)
	human.dna.copy_dna(copied_dna)
	copied_dna.custom_limb_markings[BODY_ZONE_L_ARM]["tint"] = "#ff0000"
	if(human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["tint"])
		Fail("Copied DNA must own independent per-zone drawings.", __FILE__, __LINE__)
	arm.drop_limb(special = TRUE)
	human.dna.custom_limb_markings[BODY_ZONE_L_ARM]["emissive"] = custom_sprite_emissive_settings(FALSE)
	human.regenerate_limb(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/regrown_arm = human.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone/regrown_overlay = locate() in regrown_arm.bodypart_overlays
	if(!zone_overlay.drawing["emissive"]["2"] || !regrown_overlay || regrown_overlay.drawing["emissive"]["2"])
		Fail("Detached limb drawings keep their emission snapshot; regrowth inherits current DNA.", __FILE__, __LINE__)
	human.dna.custom_limb_markings = null
	human.sync_custom_sprite_appearance()
	if(locate(/datum/bodypart_overlay/custom_marking/zone) in regrown_arm.bodypart_overlays)
		Fail("Clearing a limb drawing must remove its own overlay.", __FILE__, __LINE__)

#endif
