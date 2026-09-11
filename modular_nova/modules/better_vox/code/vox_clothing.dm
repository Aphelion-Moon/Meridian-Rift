/obj/item/clothing/under/color
	greyscale_config_worn_better_vox = /datum/greyscale_config/jumpsuit/worn/better_vox

/datum/greyscale_config/vox_primalis_pants
	name = "Vox Primalis Pants"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/pants_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_primalis_pants.json'

/datum/greyscale_config/vox_pants
	parent_type = /datum/greyscale_config/vox_primalis_pants
	name = "Vox Pants"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_pants.json'

/datum/greyscale_config/vox_feet
	name = "Vox Footwear"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/feet.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_feet.json'

/datum/greyscale_config/vox_feet/primalis
	name = "Vox Primalis Footwear"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/feet_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_primalis_feet.json'

/datum/greyscale_config/vox_hands
	name = "Vox Gloves"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/hands.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_hands.json'

/datum/greyscale_config/vox_hands/talon_out
	name = "Vox Gloves (Talons Bared)"
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_hands_talon.json'

/obj/item/clothing/under
	/// Vox Primalis always get generated pants for this uniform, even if a sprite exists for its state or it leaves the legs bare.
	var/vox_primalis_force_pants = FALSE
	/// Generate shorts rather than full trousers for this uniform, for garments that stop above the knee.
	var/vox_short_legs = FALSE

// Oversuits normally select generic digitigrade art before species art.
// Keep these fitted overalls on old Vox while other wearers retain their variants.
/obj/item/clothing/suit/apron/overalls/build_worn_icon(default_layer = 0, default_icon_file, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state, override_file, bodyshape = NONE)
	var/mob/living/carbon/human/wearer = loc
	if(!isinhands && istype(wearer) && wearer.wear_suit == src && wearer.dna.species.id == SPECIES_VOX && (bodyshape & BODYSHAPE_CUSTOM))
		override_file = worn_icon_vox
	return ..(default_layer, default_icon_file, isinhands, female_uniform, override_state, override_file, bodyshape)

// The fitted catsuits already include both body shapes and covered talons.
/obj/item/clothing/under/misc/latex_catsuit/build_worn_icon(default_layer = 0, default_icon_file, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state, override_file, bodyshape = NONE)
	var/fitted_file = override_file || worn_icon || default_icon_file
	var/is_vox_catsuit = !isinhands && (fitted_file == 'modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi' || fitted_file == 'modular_nova/modules/better_vox/icons/clothing/uniform.dmi')
	if(is_vox_catsuit)
		female_uniform = NO_FEMALE_UNIFORM
	return ..(default_layer, default_icon_file, isinhands, female_uniform, override_state, override_file, bodyshape)

/// Finish a uniform's appearance after wearer offsets, before caching and applying its overlays.
/obj/item/clothing/under/proc/get_worn_undersuit_appearances(mob/living/carbon/human/wearer, mutable_appearance/uniform_overlay, icon_file)
	return uniform_overlay

/// Hands need to be siblings of the uniform: nested float layers cannot cover bodypart hands.
/obj/item/clothing/under/misc/latex_catsuit/get_worn_undersuit_appearances(mob/living/carbon/human/wearer, mutable_appearance/uniform_overlay, icon_file)
	if(icon_file != 'modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi' && icon_file != 'modular_nova/modules/better_vox/icons/clothing/uniform.dmi')
		return ..()
	var/hand_state = "[worn_icon_state || icon_state]_hands"
	// Keep the suit below IDs and shoes, and its hand covers below equipped gloves.
	var/mutable_appearance/hands = mutable_appearance(icon_file, hand_state, -(GLOVES_LAYER + BODYPARTS_HIGH_LAYER) / 2)
	hands.alpha = alpha
	hands = color_atom_overlay(hands)
	wearer.apply_height(hands, ENTIRE_BODY)
	var/obj/item/bodypart/chest/chest = wearer.get_bodypart(BODY_ZONE_CHEST)
	chest?.worn_uniform_offset?.apply_offset(hands)
	return list(uniform_overlay, hands)

/datum/species/vox/generate_custom_worn_icon(item_slot, obj/item/item, mob/living/carbon/human/human_owner)
	// Use the wearer's current legs, not the species' unmodified bodypart type paths.
	if(item_slot == LOADOUT_ITEM_SHOES && human_owner && !(human_owner.bodyshape & BODYSHAPE_DIGITIGRADE))
		var/human_file = item.worn_icon || DEFAULT_SHOES_FILE
		return icon_exists(human_file, item.worn_icon_state || item.icon_state) ? human_file : null
	. = ..()
	if(.)
		return
	return generate_vox_clothing_icon(item_slot, item, /datum/greyscale_config/vox_pants, /datum/greyscale_config/vox_feet, /datum/greyscale_config/vox_hands, talon_hands_config = /datum/greyscale_config/vox_hands/talon_out)

/datum/species/vox_primalis/generate_custom_worn_icon(item_slot, obj/item/item, mob/living/carbon/human/human_owner)
	if(item_slot == LOADOUT_ITEM_GLOVES)
		var/glove_color = get_plain_glove_template_color(item)
		if(glove_color)
			. = generate_vox_clothing_icon(item_slot, item, hands_config = /datum/greyscale_config/vox_hands/primalis, template_color_override = glove_color)
			if(.)
				return
	var/obj/item/clothing/under/uniform = item
	var/force_pants = item_slot == LOADOUT_ITEM_UNIFORM && istype(uniform) && uniform.vox_primalis_force_pants
	if(!force_pants)
		. = ..()
		if(.)
			return
	return generate_vox_clothing_icon(item_slot, item, /datum/greyscale_config/vox_primalis_pants, /datum/greyscale_config/vox_feet/primalis, force_pants = force_pants)

/**
 * Generate missing Vox clothing after the species lookup, or explicitly opted-in plain gloves before it.
 * Pants replace the same lower eleven rows as digitigrade masks; footwear and gloves
 * replace the whole worn sprite. Cache the file separately from item-specific icons so
 * recoloring and changing worn states can select a fresh fallback.
 */
/datum/species/proc/generate_vox_clothing_icon(item_slot, obj/item/item, pants_config, feet_config, hands_config, force_pants = FALSE, template_color_override, talon_hands_config)
	var/template_config
	var/template_state
	var/default_file
	switch(item_slot)
		if(LOADOUT_ITEM_UNIFORM)
			var/obj/item/clothing/under/worn_uniform = item
			if(!istype(worn_uniform) || (!force_pants && !(worn_uniform.body_parts_covered & LEGS)))
				return null
			template_config = pants_config
			template_state = worn_uniform.vox_short_legs ? "shorts" : "pants"
			default_file = DEFAULT_UNIFORM_FILE
		if(LOADOUT_ITEM_SHOES)
			if(!istype(item, /obj/item/clothing/shoes))
				return null
			template_config = feet_config
			template_state = istype(item, /obj/item/clothing/shoes/sneakers) ? "sneakers_worn" : "boots_worn"
			default_file = DEFAULT_SHOES_FILE
		if(LOADOUT_ITEM_GLOVES)
			var/obj/item/clothing/gloves/worn_gloves = item
			if(!istype(worn_gloves) || !(worn_gloves.body_parts_covered & HANDS))
				return null
			template_config = hands_config
			if(talon_hands_config && (istype(worn_gloves, /obj/item/clothing/gloves/color) || istype(worn_gloves, /obj/item/clothing/gloves/recolorable)))
				template_config = talon_hands_config
			template_state = "gloves_worn"
			default_file = 'icons/mob/clothing/hands.dmi'
	if(!template_config)
		return null

	var/source_file = item.worn_icon || default_file
	var/source_state = item.worn_icon_state || item.icon_state
	if(!icon_exists(source_file, source_state))
		return null

	use_custom_worn_icon_cached()
	var/cache_key = "[template_config]-[template_state]-[item.type]-[item.icon_state]-[item.greyscale_colors]-[template_color_override]"
	var/icon/cached_icon = get_custom_worn_icon_cached(source_file, source_state, cache_key)
	if(cached_icon)
		return cached_icon

	var/icon/base_icon = icon(source_file, source_state)
	// Match digitigrade masks: keep a single GAGS color, otherwise sample the source.
	var/template_color = template_color_override || item.greyscale_colors
	if(isnull(template_color) || length(SSgreyscale.ParseColorString(template_color)) != 1)
		if(item_slot == LOADOUT_ITEM_GLOVES)
			template_color = get_vox_glove_color(base_icon)
		else
			template_color = item.get_general_color(base_icon)
	var/icon/replacement = icon(SSgreyscale.GetColoredIconByType(template_config, template_color), template_state)
	var/icon/result = icon()
	if(item_slot == LOADOUT_ITEM_UNIFORM)
		// build_worn_icon can request the item state even when worn_icon_state differs.
		var/list/states = list(source_state, "[source_state]_d", item.icon_state, "[item.icon_state]_d")
		for(var/state in states)
			var/state_to_copy = state
			if(!icon_exists(source_file, state_to_copy))
				state_to_copy = (state == "[item.icon_state]_d") ? "[source_state]_d" : source_state
			if(icon_exists(source_file, state_to_copy))
				result.Insert(replace_icon_legs(icon(source_file, state_to_copy), replacement), state)
	else
		result.Insert(replacement, source_state)
	// Like GAGS GenerateBundle(), finish lazy icon operations before caching the file.
	result.GetPixel(1, 1)
	result = fcopy_rsc(result)
	set_custom_worn_icon_cached(source_file, source_state, cache_key, result)
	return result

/// Gloves have no leg/foot sample point. Use their most common visible source color.
/proc/get_vox_glove_color(icon/base_icon)
	var/list/color_counts = list()
	var/most_common_color = COLOR_DARK
	var/highest_count = 0
	for(var/x in 1 to base_icon.Width())
		for(var/y in 1 to base_icon.Height())
			var/pixel_color = base_icon.GetPixel(x, y)
			if(!pixel_color)
				continue
			color_counts[pixel_color]++
			if(color_counts[pixel_color] > highest_count)
				highest_count = color_counts[pixel_color]
				most_common_color = pixel_color
	return most_common_color

// Custom Vox handwear: preserve patterns and separate recoloring channels.
/datum/greyscale_config/depgag_gloves/worn/vox
	name = "Guard Gloves (Vox)"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/hands.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/hands/vox_guard_gloves.json'

/datum/greyscale_config/maid_arm_covers/worn/vox
	name = "Maid Arm Covers (Vox)"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/hands.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/hands/vox_maid_covers.json'

/datum/greyscale_config/vox_hands/primalis
	name = "Vox Primalis Gloves"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/hands_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_primalis_hands.json'

/// Only reviewed full gloves may replace the shared, fixed-color Better Vox artwork.
/datum/species/vox_primalis/proc/get_plain_glove_template_color(obj/item/clothing/gloves/gloves)
	if(!istype(gloves) || !(gloves.body_parts_covered & HANDS))
		return null
	// The parent lookup can remember the shared sheet on the item. Dedicated art still wins.
	if(gloves.worn_icon_better_vox && gloves.worn_icon_better_vox != custom_worn_icons[LOADOUT_ITEM_GLOVES])
		return null
	if(gloves.greyscale_config_worn_better_vox)
		return null
	var/static/list/plain_states = list(
		/obj/item/clothing/gloves/color/white = "white",
		/obj/item/clothing/gloves/color/black = "black",
		/obj/item/clothing/gloves/color/blue = "blue",
		/obj/item/clothing/gloves/color/purple = "purple",
		/obj/item/clothing/gloves/color/green = "green",
		/obj/item/clothing/gloves/color/red = "red",
		/obj/item/clothing/gloves/color/red/insulated = "red",
		/obj/item/clothing/gloves/color/orange = "orange",
		/obj/item/clothing/gloves/color/grey = "gray",
		/obj/item/clothing/gloves/color/grey/protects_cold = "gray",
		/obj/item/clothing/gloves/color/brown = "brown",
		/obj/item/clothing/gloves/color/light_brown = "lightbrown",
		/obj/item/clothing/gloves/color/yellow = "yellow",
		/obj/item/clothing/gloves/color/yellow/heavy = "yellow",
		/obj/item/clothing/gloves/color/fyellow = "yellow",
		/obj/item/clothing/gloves/color/fyellow/old = "yellow",
		/obj/item/clothing/gloves/color/ffyellow = "yellow",
		/obj/item/clothing/gloves/recolorable = "gloves",
		/obj/item/clothing/gloves/latex = "latex",
		/obj/item/clothing/gloves/latex/nitrile = "nitrile",
		/obj/item/clothing/gloves/botanic_leather = "leather",
		/obj/item/clothing/gloves/combat = "combat",
		/obj/item/clothing/gloves/race = "black",
	)
	var/state = gloves.worn_icon_state || gloves.icon_state
	if(!plain_states[gloves.type] || state != plain_states[gloves.type])
		return null
	var/template_color = gloves.greyscale_colors
	if(template_color && length(SSgreyscale.ParseColorString(template_color)) != 1)
		return null
	// Preserve reskins even when they reuse a reviewed state name in another icon file.
	var/expected_source = initial(gloves.worn_icon)
	if(gloves.greyscale_config_worn)
		if(!template_color || gloves.greyscale_config_worn != initial(gloves.greyscale_config_worn))
			return null
		expected_source = SSgreyscale.GetColoredIconByType(gloves.greyscale_config_worn, gloves.greyscale_colors)
	if(gloves.worn_icon != expected_source)
		return null
	if(template_color)
		return template_color
	// These legacy items lack a configured tint; retain their reviewed species highlight.
	switch(state)
		if("yellow")
			return "#efb514"
		if("latex")
			return "#ffffff"
		if("leather")
			return "#71200e"
	return null
