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
				if(first.GetPixel(x, y, direction) != second.GetPixel(x, y, direction))
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

/datum/unit_test/custom_sprite_hair_cache/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[human.hairstyle]
	var/icon/shared_before = icon(style.getCachedIcon())
	human.dna.custom_hair = custom_sprite_test_drawing()
	head.copy_appearance_from(human)
	var/icon/paint = head.get_custom_hair_paint(style)
	if(!paint || paint.GetPixel(16, 16, SOUTH) != "#ffffff")
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

#endif
