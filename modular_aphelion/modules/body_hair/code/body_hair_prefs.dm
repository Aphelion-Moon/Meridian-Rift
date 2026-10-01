/// Armpit or pubic hair style. Applied before species, whose organ regeneration grows the hair from dna.
/datum/preference/choiced/body_hair
	abstract_type = /datum/preference/choiced/body_hair
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	can_randomize = FALSE
	/// FEATURE_PITS or FEATURE_PUBES.
	var/feature_key

/datum/preference/choiced/body_hair/init_possible_values()
	return assoc_to_keys_features(SSaccessories.sprite_accessories[feature_key])

/datum/preference/choiced/body_hair/create_default_value()
	return SPRITE_ACCESSORY_NONE

/datum/preference/choiced/body_hair/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(preferences && !is_accessible(preferences))
		value = SPRITE_ACCESSORY_NONE
	var/colour = preferences?.read_preference(/datum/preference/color/body_hair) || BODY_HAIR_DEFAULT_COLOR
	target.dna.mutant_bodyparts[feature_key] = build_mutant_part(value, list(colour, colour, colour))
	if(value != SPRITE_ACCESSORY_NONE)
		return
	// Species regeneration only grows hair, so going bare removes it here.
	var/obj/item/organ/body_hair/hair = target.get_organ_slot(feature_key == FEATURE_PUBES ? ORGAN_SLOT_EXTERNAL_PUBES : ORGAN_SLOT_EXTERNAL_PITS)
	if(hair)
		hair.Remove(target, special = TRUE)
		qdel(hair)

/datum/preference/choiced/body_hair/pits
	savefile_key = "feature_pits"
	feature_key = FEATURE_PITS

/datum/preference/choiced/body_hair/pubes
	savefile_key = "feature_pubes"
	feature_key = FEATURE_PUBES

/datum/preference/choiced/body_hair/pubes/is_accessible(datum/preferences/preferences)
	if(!..(preferences) || CONFIG_GET(flag/disable_erp_preferences))
		return FALSE
	return preferences.read_preference(/datum/preference/toggle/master_erp_preferences) && preferences.read_preference(/datum/preference/toggle/allow_genitals)

/// Body hair's own colour. Hidden while it matches the head hair instead.
/datum/preference/color/body_hair
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "body_hair_color"

/datum/preference/color/body_hair/create_default_value()
	return BODY_HAIR_DEFAULT_COLOR

/datum/preference/color/body_hair/is_accessible(datum/preferences/preferences)
	return ..(preferences) && !preferences.read_preference(/datum/preference/toggle/body_hair_matches_hair)

/datum/preference/color/body_hair/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	for(var/feature in list(FEATURE_PITS, FEATURE_PUBES))
		var/datum/mutant_bodypart/part = target.dna.mutant_bodyparts[feature]
		part?.set_colors(list(value, value, value))

/// Body hair takes the head hair's colour, and follows it when that changes.
/datum/preference/toggle/body_hair_matches_hair
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "body_hair_matches_hair"
	default_value = TRUE

/datum/preference/toggle/body_hair_matches_hair/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_BODY_HAIR_MATCHES_HAIR] = value
