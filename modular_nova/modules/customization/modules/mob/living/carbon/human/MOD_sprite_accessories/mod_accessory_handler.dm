/// Returns a shared icon resource. The caller resolves the active theme once for all color layers.
/datum/sprite_accessory/proc/get_custom_mod_icon(mutable_appearance/appearance_to_use, datum/mod_theme/mod_theme)
	var/index = "[appearance_to_use.icon]-[appearance_to_use.icon_state]-[mod_theme.hardlight_theme]"
	var/static/list/mod_icon_cache = list()
	var/cached_icon = mod_icon_cache[index]
	if(!cached_icon)
		var/icon/special_icon = icon(appearance_to_use.icon, appearance_to_use.icon_state)
		var/icon/MOD_texture = icon('modular_nova/modules/customization/modules/mob/living/carbon/human/MOD_sprite_accessories/icons/MOD_mask.dmi', "[mod_theme.hardlight_theme]")
		special_icon.Blend("#fff", ICON_ADD)
		special_icon.Blend(MOD_texture, ICON_MULTIPLY)
		cached_icon = fcopy_rsc(special_icon)
		mod_icon_cache[index] = cached_icon

	return cached_icon

/// Is this accessory currently under an active hardlight MOD overlay? Used for determining if we should apply a mod overlay to a bodypart
/datum/sprite_accessory/proc/mod_overlay_active(mob/living/carbon/human/wearer)
	return !isnull(get_mod_overlay_theme(wearer))

/// Resolve both eligibility and color from the same suit, including during partial activation and rollback.
/datum/sprite_accessory/proc/get_mod_overlay_theme(mob/living/carbon/human/wearer)
	RETURN_TYPE(/datum/mod_theme)
	if(!mod_icon_slots || !wearer)
		return null
	var/obj/item/mod/control/modsuit_control = wearer.back
	if(!istype(modsuit_control) || modsuit_control.wearer != wearer)
		return null
	if(!(modsuit_control.active || modsuit_control.activating) || !modsuit_control.theme?.hardlight)
		return null

	var/remaining_slots = mod_icon_slots
	for(var/slot_key in modsuit_control.mod_parts)
		var/slot = text2num(slot_key)
		if(!(remaining_slots & slot))
			continue
		var/datum/mod_part/part = modsuit_control.mod_parts[slot_key]
		if(!part.sealed || wearer.get_item_by_slot(slot) != part.part_item)
			continue
		remaining_slots &= ~slot
		if(!remaining_slots)
			return modsuit_control.theme
	return null

/// The hardlight theme string, for use in the render cache key - so we don't get any color collisions
/datum/sprite_accessory/proc/get_hardlight_theme_key(mob/living/carbon/human/wearer)
	return get_mod_overlay_theme(wearer)?.hardlight_theme || ""
