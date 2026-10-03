/// Legs
/datum/preference/choiced/digitigrade_legs
	savefile_key = "digitigrade_legs"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	relevant_mutant_bodypart = FEATURE_LEGS

/datum/preference/choiced/digitigrade_legs/create_default_value()
	return NORMAL_LEGS

/datum/preference/choiced/digitigrade_legs/init_possible_values()
	return list(NORMAL_LEGS, DIGITIGRADE_LEGS)

/datum/preference/choiced/digitigrade_legs/is_accessible(datum/preferences/preferences)
	return ..() && is_usable(preferences)

/**
 * Actually rendered. Slimmed down version of the logic in is_available() that actually works when spawning or drawing the character.
 *
 * Returns if feature value is usable.
 *
 * Arguments:
 * * preferences - The relevant character preferences.
 */
/datum/preference/choiced/digitigrade_legs/proc/is_usable(datum/preferences/preferences)
	var/species_type = preferences.read_preference(/datum/preference/choiced/species)
	var/datum/species/species = GLOB.species_prototypes[species_type]

	return (savefile_key in species.get_features()) \
		&& species.digitigrade_customization == DIGITIGRADE_OPTIONAL

/**
 * Whether the body already wears every limb its species' replace_body() would give it for this leg shape, so a swap would only
 * replace each limb with a new one of the same type and nothing else. Otherwise the swap runs, as it always did: for a limb of
 * another type (another species' limb, the other leg shape), a zone the species has no limb for (replace_body() deletes that
 * limb), a limb carrying a colour override (the limb keeps it, its replacement would not), and a synthetic, whose chassis
 * replace_body() weighs before it hands out digitigrade legs.
 *
 * Arguments:
 * * target - The body to check.
 * * value - The leg shape asked for.
 */
/datum/preference/choiced/digitigrade_legs/proc/wears_swapped_limbs(mob/living/carbon/human/target, value)
	if(issynthetic(target))
		return FALSE
	var/datum/species/species = target.dna.species
	// replace_body()'s own test: the shape asked for, unless the species forces digitigrade legs.
	var/digitigrade = species.digitigrade_customization == DIGITIGRADE_FORCED || (species.digitigrade_customization == DIGITIGRADE_OPTIONAL && value == DIGITIGRADE_LEGS)
	var/list/limb_types = species.bodypart_overrides
	for(var/obj/item/bodypart/part as anything in target.get_bodyparts())
		// replace_body() leaves these alone.
		if((part.change_exempt_flags & BP_BLOCK_CHANGE_SPECIES) || (part.bodypart_flags & BODYPART_IMPLANTED))
			continue
		if(LAZYLEN(part.color_overrides))
			return FALSE
		var/limb_type = limb_types[part.body_zone]
		if(limb_type && digitigrade && (part.body_zone == BODY_ZONE_L_LEG || part.body_zone == BODY_ZONE_R_LEG))
			var/obj/item/bodypart/leg/leg_type = limb_type
			limb_type = initial(leg_type.digitigrade_type)
		if(isnull(limb_type) || part.type != limb_type)
			return FALSE
	return TRUE

/datum/preference/choiced/digitigrade_legs/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(!preferences || !is_usable(preferences))
		return FALSE

	var/old_value = target.dna.features[FEATURE_LEGS]
	if(value == old_value)
		return FALSE

	target.dna.features[FEATURE_LEGS] = value

	// Avoid rebuilding the outgoing preview species.
	// Species runs after legs and will replace this body itself. Other callers may apply only some preferences.
	if(target == preferences.character_preview_view?.body && target.dna.species.type != preferences.read_preference(/datum/preference/choiced/species))
		return TRUE

	// The preview's features are reset before every render, so this runs on each one: a body that already wears the limbs
	// a swap would give it keeps them.
	if(wears_swapped_limbs(target, value))
		return TRUE

	// Swap the limbs as one render batch, as a species change does, then draw the body once.
	var/already_batched = target.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS
	target.living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	target.dna.species.replace_body(target, target.dna.species) // TODO: Replace this with something less stupidly expensive.
	if(!already_batched)
		target.living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
		target.update_body()
		target.update_damage_overlays()
	return TRUE
