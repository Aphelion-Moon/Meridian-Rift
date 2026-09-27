/obj/item/bodypart
	disabling_threshold_percentage = 1 // Originally: disabling_threshold_percentage = LIMB_NO_DISABLE
	/// The bodypart's currently applied style's name. Only necessary for bodyparts that come in multiple
	/// variants, like prosthetics and cyborg bodyparts.
	var/current_style = null
	/// Used for taur limbs that do not get rendered at all
	VAR_PROTECTED/is_actually_just_invisible = FALSE

/obj/item/bodypart/generate_icon_key()
	RETURN_TYPE(/list)
	. = ..()
	if(current_style)
		. += "-[current_style]"
	for(var/datum/body_marking_entry/marking_entry as anything in markings)
		. += (bodyshape & BODYSHAPE_DIGITIGRADE) ? "[BODYPART_ID_DIGITIGRADE]_[body_zone]" : body_zone
		. += "-[marking_entry.cache_key()]"
	for(var/datum/body_marking_entry/marking_entry as anything in aux_zone_markings)
		. += aux_zone
		. += "-[marking_entry.cache_key()]"
	return .

/**
 * # This should only be ran by augments, if you don't know what you're doing, you shouldn't be touching this.
 * A setter for the `icon_static` variable of the bodypart. Runs through `icon_exists()` for sanity, and it won't
 * change anything in the event that the check fails.
 *
 * Arguments:
 * * new_icon - The new icon filepath that you want to replace `icon_static` with.
 */
/obj/item/bodypart/proc/set_icon_static(new_icon)
	var/state_to_verify = "[limb_id]_[body_zone][is_dimorphic ? "_[limb_gender]" : ""]"
	if(icon_exists_or_scream(new_icon, state_to_verify))
		icon_static = new_icon

#define ICON_STATE_FORMULA_DIGI "[limb_id]_[body_zone][(bodyshape & BODYSHAPE_DIGITIGRADE) ? "_[ICON_KEY_DIGI]" : ""]"

/obj/item/bodypart/leg/set_icon_static(new_icon)
	var/state_to_verify = ICON_STATE_FORMULA_DIGI
	if(icon_exists_or_scream(new_icon, state_to_verify))
		icon_static = new_icon
/**
 * # This should only be ran by augments, if you don't know what you're doing, you shouldn't be touching this.
 * A setter for the `icon_greyscale` variable of the bodypart. Runs through `icon_exists()` for sanity, and it won't
 * change anything in the event that the check fails.
 *
 * Arguments:
 * * new_icon - The new icon filepath that you want to replace `icon_greyscale` with.
 */
/obj/item/bodypart/proc/set_icon_greyscale(new_icon)
	var/state_to_verify = "[limb_id]_[body_zone][is_dimorphic ? "_[limb_gender]" : ""]"
	if(icon_exists_or_scream(new_icon, state_to_verify))
		icon_greyscale = new_icon

/obj/item/bodypart/leg/set_icon_greyscale(new_icon)
	var/state_to_verify = ICON_STATE_FORMULA_DIGI
	if(icon_exists_or_scream(new_icon, state_to_verify))
		icon_greyscale = new_icon

#undef ICON_STATE_FORMULA_DIGI
