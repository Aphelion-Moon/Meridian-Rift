/// Fits the plain Shoredress family to digitigrade legs with the refit's drawn digi legs
/obj/item/clothing/under/akula_wetsuit/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	// The refit has the same _f and _tail states, and its tail cut reaches below the waist, so we take the matching one
	var/suffix = worn_icon_state ? copytext(worn_icon_state, length(base_icon_state) + 1) : ""
	var/icon/digi_legs = icon(DIGITIGRADE_UNIFORM_FILE, "[/obj/item/clothing/under/akula_wetsuit/refit::icon_state][suffix]")
	// we only take the refit's legs, its torso is drawn a little differently from these suits'
	var/icon/legs_only = icon('icons/mob/clothing/under/masking_helpers.dmi', LEGS_MASK)
	legs_only.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,-1, 0,0,0,1) // flips the mask's alpha so it keeps the legs instead
	digi_legs.Blend(legs_only, ICON_SUBTRACT)
	return apply_icon_mask(base_icon, LEGS_MASK, digi_legs)

/// Draws the worn state check_physique() and add_tail_overlay() picked, as the uniform layer passes icon_state instead
/obj/item/clothing/under/akula_wetsuit/build_worn_icon(default_layer = 0, default_icon_file, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state, override_file, bodyshape = NONE)
	if(!isinhands && worn_icon_state)
		override_state = worn_icon_state
		// The _f states are drawn female already, so we don't crop them again
		if(findtextEx(worn_icon_state, "_f", length(base_icon_state) + 1))
			female_uniform = NO_FEMALE_UNIFORM
	return ..(default_layer, default_icon_file, isinhands, female_uniform, override_state, override_file, bodyshape)
