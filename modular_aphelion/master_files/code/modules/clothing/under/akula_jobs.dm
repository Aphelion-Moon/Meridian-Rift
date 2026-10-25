/// Fits the plain Shoredress family to digitigrade legs with the refit's drawn digi legs
/obj/item/clothing/under/akula_wetsuit/generate_digitigrade_icons(icon/base_icon, greyscale_colors)
	// update_worn_undersuit() draws icon_state, never the _f and _tail worn states, so the refit's plain state lines up
	var/icon/digi_legs = icon(DIGITIGRADE_UNIFORM_FILE, /obj/item/clothing/under/akula_wetsuit/refit::icon_state)
	// we only take the refit's legs, its torso is drawn a little differently from these suits'
	var/icon/legs_only = icon('icons/mob/clothing/under/masking_helpers.dmi', LEGS_MASK)
	legs_only.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,-1, 0,0,0,1) // flips the mask's alpha so it keeps the legs instead
	digi_legs.Blend(legs_only, ICON_SUBTRACT)
	return apply_icon_mask(base_icon, LEGS_MASK, digi_legs)
