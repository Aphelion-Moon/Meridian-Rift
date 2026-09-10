/obj/item/clothing/under/color
	greyscale_config_worn_better_vox = /datum/greyscale_config/jumpsuit/worn/better_vox

/obj/item/clothing/under/rank/prisoner
	greyscale_config_worn_better_vox = /datum/greyscale_config/jumpsuit/prison/worn/better_vox

// APHELION EDIT ADDITION START - Generated pants for uniforms without a Vox sprite.
/datum/greyscale_config/vox_primalis_pants
	name = "Vox Primalis Pants"
	icon_file = 'modular_nova/modules/better_vox/icons/clothing/pants_template.dmi'
	json_config = 'modular_nova/modules/GAGS/json_configs/vox_primalis_pants.json'

/datum/species/vox_primalis/generate_custom_worn_icon(item_slot, obj/item/item, mob/living/carbon/human/human_owner)
	. = ..()
	if(.)
		return
	if(item_slot != LOADOUT_ITEM_UNIFORM || !istype(item, /obj/item/clothing/under) || !(item.body_parts_covered & LEGS))
		return null

	var/source_file = item.worn_icon || DEFAULT_UNIFORM_FILE
	var/source_state = item.worn_icon_state || item.icon_state
	if(!icon_exists(source_file, source_state))
		return null

	use_custom_worn_icon_cached()
	var/cache_key = "pants-[item.icon_state]-[item.greyscale_colors]"
	var/icon/cached_icon = get_custom_worn_icon_cached(source_file, source_state, cache_key)
	if(cached_icon)
		return cached_icon

	var/icon/base_icon = icon(source_file, source_state)
	// Match the digi mask's single-color handling and sampling of multicolor pants.
	var/pants_color = item.greyscale_colors
	if(isnull(pants_color) || length(SSgreyscale.ParseColorString(pants_color)) != 1)
		pants_color = item.get_general_color(base_icon)
	var/icon/legs = icon(SSgreyscale.GetColoredIconByType(/datum/greyscale_config/vox_primalis_pants, pants_color), "pants")
	var/icon/result = icon()
	// Keep both the normal and rolled-down shirt, including explicit worn states.
	var/list/states = list(source_state, "[source_state]_d", item.icon_state, "[item.icon_state]_d")
	for(var/state in states)
		if(icon_exists(source_file, state))
			result.Insert(replace_icon_legs(icon(source_file, state), legs), state)
	result = fcopy_rsc(result)
	set_custom_worn_icon_cached(source_file, source_state, cache_key, result)
	return result
// APHELION EDIT ADDITION END
