/// Whether a character's build follows their strength stat. There is no strength stat yet, so while it does, their limbs stay at the baseline.
/datum/preference/toggle/fitness_match_strength
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "fitness_match_strength"
	default_value = TRUE
	can_randomize = FALSE

/datum/preference/toggle/fitness_match_strength/is_accessible(datum/preferences/preferences)
	return ..() && species_has_fitness_limbs(preferences.read_preference(/datum/preference/choiced/species), GLOB.fitness_zone_features)

/datum/preference/toggle/fitness_match_strength/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return // The fitness levels read it.

/**
 * The fitness level of one group of a character's limbs, picked while their build doesn't follow their strength stat. Applied
 * before species, as the leg shape is, so a species change builds the limbs at their levels; with the species unchanged, the
 * group's limbs are swapped here.
 */
/datum/preference/choiced/fitness_level
	abstract_type = /datum/preference/choiced/fitness_level
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	priority = PREFERENCE_PRIORITY_PRE_SPECIES
	can_randomize = FALSE
	/// The dna.features entry the level goes in.
	var/feature_key
	/// The body zones of the group's limbs.
	var/list/zones

/datum/preference/choiced/fitness_level/init_possible_values()
	. = list()
	for(var/level in FITNESS_LEVEL_BASELINE to FITNESS_LEVEL_MAX)
		. += level

/datum/preference/choiced/fitness_level/create_default_value()
	return FITNESS_LEVEL_BASELINE

/datum/preference/choiced/fitness_level/compile_constant_data()
	var/list/data = ..()
	data[CHOICED_PREFERENCE_DISPLAY_NAMES] = list(
		"0" = "Baseline",
		"1" = "Tuned",
		"2" = "Wired",
		"3" = "Hardened",
		"4" = "Overclocked",
		"5" = "Redline",
	)
	return data

/datum/preference/choiced/fitness_level/is_accessible(datum/preferences/preferences)
	if(!..() || preferences.read_preference(/datum/preference/toggle/fitness_match_strength))
		return FALSE
	return species_has_fitness_limbs(preferences.read_preference(/datum/preference/choiced/species), zones)

/datum/preference/choiced/fitness_level/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(preferences && !is_applicable(preferences))
		value = FITNESS_LEVEL_BASELINE
	target.dna.features[feature_key] = value
	// The species preference, applied next, rebuilds the outgoing preview species' body itself.
	if(target == preferences?.character_preview_view?.body && target.dna.species.type != preferences.read_preference(/datum/preference/choiced/species))
		return
	target.update_fitness_limbs(zones)

/datum/preference/choiced/fitness_level/arms
	savefile_key = "fitness_arms"
	feature_key = FEATURE_FITNESS_ARMS
	zones = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)

/datum/preference/choiced/fitness_level/legs
	savefile_key = "fitness_legs"
	feature_key = FEATURE_FITNESS_LEGS
	zones = list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)

/datum/preference/choiced/fitness_level/torso
	savefile_key = "fitness_torso"
	feature_key = FEATURE_FITNESS_TORSO
	zones = list(BODY_ZONE_CHEST)
