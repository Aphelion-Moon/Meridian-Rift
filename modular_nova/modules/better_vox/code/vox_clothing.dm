/obj/item/clothing/under/color
	greyscale_config_worn_better_vox = /datum/greyscale_config/jumpsuit/worn/better_vox

/datum/greyscale_config/vox_primalis_pants
	name = "Vox Primalis Pants"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/pants_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_primalis_pants.json'

/datum/greyscale_config/vox_pants
	parent_type = /datum/greyscale_config/vox_primalis_pants
	name = "Vox Pants"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/pants_template.dmi'

/datum/greyscale_config/vox_feet
	name = "Vox Footwear"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/feet_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_feet.json'

/datum/greyscale_config/vox_feet/primalis
	name = "Vox Primalis Footwear"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/feet_template.dmi'

/datum/greyscale_config/vox_hands
	name = "Vox Gloves"
	icon_file = 'modular_nova/master_files/icons/mob/clothing/species/vox/hands_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_hands.json'

/obj/item/clothing/under
	/// Vox Primalis always get generated pants for this uniform, even if a sprite exists for its state or it leaves the legs bare.
	var/vox_primalis_force_pants = FALSE

/datum/species/vox/generate_custom_worn_icon(item_slot, obj/item/item, mob/living/carbon/human/human_owner)
	// Use the wearer's current legs, not the species' unmodified bodypart type paths.
	if(item_slot == LOADOUT_ITEM_SHOES && human_owner && !(human_owner.bodyshape & BODYSHAPE_DIGITIGRADE))
		var/human_file = item.worn_icon || DEFAULT_SHOES_FILE
		return icon_exists(human_file, item.worn_icon_state || item.icon_state) ? human_file : null
	. = ..()
	if(.)
		return
	return generate_vox_clothing_icon(item_slot, item, /datum/greyscale_config/vox_pants, /datum/greyscale_config/vox_feet, /datum/greyscale_config/vox_hands)

/datum/species/vox_primalis/generate_custom_worn_icon(item_slot, obj/item/item, mob/living/carbon/human/human_owner)
	var/obj/item/clothing/under/uniform = item
	var/force_pants = item_slot == LOADOUT_ITEM_UNIFORM && istype(uniform) && uniform.vox_primalis_force_pants
	if(!force_pants)
		. = ..()
		if(.)
			return
	return generate_vox_clothing_icon(item_slot, item, /datum/greyscale_config/vox_primalis_pants, /datum/greyscale_config/vox_feet/primalis, force_pants = force_pants)

/**
 * Generate only missing Vox clothing. Call after the dedicated/shared species lookup.
 * Pants replace the same lower eleven rows as digitigrade masks; footwear and gloves
 * replace the whole worn sprite. Cache the file separately from item-specific icons so
 * recoloring and changing worn states can select a fresh fallback.
 */
/datum/species/proc/generate_vox_clothing_icon(item_slot, obj/item/item, pants_config, feet_config, hands_config, force_pants = FALSE)
	var/template_config
	var/template_state
	var/default_file
	switch(item_slot)
		if(LOADOUT_ITEM_UNIFORM)
			if(!istype(item, /obj/item/clothing/under) || (!force_pants && !(item.body_parts_covered & LEGS)))
				return null
			template_config = pants_config
			template_state = "pants"
			default_file = DEFAULT_UNIFORM_FILE
		if(LOADOUT_ITEM_SHOES)
			if(!istype(item, /obj/item/clothing/shoes))
				return null
			template_config = feet_config
			template_state = istype(item, /obj/item/clothing/shoes/sneakers) ? "sneakers_worn" : "boots_worn"
			default_file = DEFAULT_SHOES_FILE
		if(LOADOUT_ITEM_GLOVES)
			if(!istype(item, /obj/item/clothing/gloves) || !(item.body_parts_covered & HANDS))
				return null
			template_config = hands_config
			template_state = "gloves_worn"
			default_file = 'icons/mob/clothing/hands.dmi'
	if(!template_config)
		return null

	var/source_file = item.worn_icon || default_file
	var/source_state = item.worn_icon_state || item.icon_state
	if(!icon_exists(source_file, source_state))
		return null

	use_custom_worn_icon_cached()
	var/cache_key = "[template_config]-[template_state]-[item.type]-[item.icon_state]-[item.greyscale_colors]"
	var/icon/cached_icon = get_custom_worn_icon_cached(source_file, source_state, cache_key)
	if(cached_icon)
		return cached_icon

	var/icon/base_icon = icon(source_file, source_state)
	// Match digitigrade masks: keep a single GAGS color, otherwise sample the source.
	var/template_color = item.greyscale_colors
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
