/obj/item/bodypart
	disabling_threshold_percentage = 1 // Originally: disabling_threshold_percentage = LIMB_NO_DISABLE
	/// The bodypart's currently applied style's name. Only necessary for bodyparts that come in multiple
	/// variants, like prosthetics and cyborg bodyparts.
	var/current_style = null
	/// Used for taur limbs that do not get rendered at all
	VAR_PROTECTED/is_actually_just_invisible = FALSE
	/// The part of this limb's icon cache keys standing for the markings it draws, or null for none. See LIMB_MARKING_ICON_KEY.
	VAR_PRIVATE/marking_key
	/// The markings list marking_key was built from.
	VAR_PRIVATE/list/marking_key_markings
	/// The aux_zone_markings list marking_key was built from.
	VAR_PRIVATE/list/marking_key_aux_markings
	/// The markings_alpha marking_key was built with.
	VAR_PRIVATE/marking_key_alpha
	/// Whether marking_key was built for a digitigrade limb.
	VAR_PRIVATE/marking_key_digitigrade = FALSE
	/// GLOB.body_marking_entry_revision when marking_key was built, -1 until it first is.
	VAR_PRIVATE/marking_key_revision = -1

/// The markings part of this limb's icon cache keys: marking_key, read with no proc call, while the five things it was built
/// from are unchanged, else a new one from rebuild_marking_icon_key(). It reads private vars, so only /obj/item/bodypart's
/// own procs may use it.
#define LIMB_MARKING_ICON_KEY ((marking_key_revision == GLOB.body_marking_entry_revision && marking_key_markings == markings && marking_key_aux_markings == aux_zone_markings && marking_key_alpha == markings_alpha && marking_key_digitigrade == !!(bodyshape & BODYSHAPE_DIGITIGRADE)) ? marking_key : rebuild_marking_icon_key())

/obj/item/bodypart/generate_icon_key()
	RETURN_TYPE(/list)
	. = ..()
	if(current_style)
		. += "-[current_style]"
	if(markings || aux_zone_markings)
		var/drawn_markings = LIMB_MARKING_ICON_KEY
		if(drawn_markings)
			. += drawn_markings
	return .

/**
 * Keys a husked limb by the markings it still draws: grey, but at their own alpha and with their own glow.
 */
/obj/item/bodypart/generate_husk_key()
	RETURN_TYPE(/list)
	. = ..()
	if(markings || aux_zone_markings)
		var/drawn_markings = LIMB_MARKING_ICON_KEY
		if(drawn_markings)
			. += drawn_markings
	return .

/**
 * Builds the part of this limb's icon cache keys standing for the markings it draws, and stamps what it was built from.
 *
 * LIMB_MARKING_ICON_KEY reuses the result until something it describes changes: the marking lists are swapped for
 * others, an entry anywhere is recoloured or its glow toggled (GLOB.body_marking_entry_revision), markings_alpha changes,
 * or the limb turns digitigrade or back. Marking lists are never edited in place, so the same list still holds the same
 * entries in the same order.
 *
 * Returns:
 * - string: "[zone]=[entries];[aux zone]=[entries];alpha=[markings_alpha]", a zone without markings left empty and
 *   the zone written "digitigrade_[zone]" on a digitigrade limb, or null when the limb draws no markings.
 */
/obj/item/bodypart/proc/rebuild_marking_icon_key()
	var/digitigrade = (bodyshape & BODYSHAPE_DIGITIGRADE) ? TRUE : FALSE
	marking_key_revision = GLOB.body_marking_entry_revision
	marking_key_markings = markings
	marking_key_aux_markings = aux_zone_markings
	marking_key_alpha = markings_alpha
	marking_key_digitigrade = digitigrade
	var/body_part = length(markings) ? "[digitigrade ? "[BODYPART_ID_DIGITIGRADE]_[body_zone]" : body_zone]=[marking_zone_key(body_zone, markings)]" : ""
	var/aux_part = (aux_zone && length(aux_zone_markings)) ? "[aux_zone]=[marking_zone_key(aux_zone, aux_zone_markings)]" : ""
	// The alpha rides along: roundstartslime draws its markings at 130, and must not share everyone else's icons.
	marking_key = (body_part || aux_part) ? "[body_part];[aux_part];alpha=[markings_alpha]" : null
	return marking_key

/**
 * Returns the string standing for the markings this limb draws on one zone, in order, with their colours and glow.
 *
 * Arguments:
 * - zone: body_zone or aux_zone.
 * - zone_entries: the entries this limb draws there.
 *
 * Returns:
 * - string: the owner's cache_key_for_zone() while zone_entries is still the owner's list for that zone, else one built
 *   from zone_entries themselves, as for a detached limb, a limb whose owner's markings changed after its last
 *   update_limb(), or a limb given entries of its own.
 */
/obj/item/bodypart/proc/marking_zone_key(zone, list/zone_entries)
	var/datum/body_marking_collection/owner_markings = owner?.dna?.body_markings
	if(owner_markings && owner_markings.entries_for_zone(zone) == zone_entries)
		return owner_markings.cache_key_for_zone(zone)
	return body_marking_entries_cache_key(zone_entries)

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
#undef LIMB_MARKING_ICON_KEY
