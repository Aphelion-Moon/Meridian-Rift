/// Whether a character's muscles follow their stats: dexterity their definition, strength their size. Neither stat exists yet,
/// so while they do, the character's muscles are Normal-sized with no definition.
/datum/preference/toggle/muscles_automatic
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "muscles_automatic"
	default_value = TRUE
	can_randomize = FALSE

/datum/preference/toggle/muscles_automatic/is_accessible(datum/preferences/preferences)
	return ..() && species_has_fitness_limbs(preferences.read_preference(/datum/preference/choiced/species))

/datum/preference/toggle/muscles_automatic/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return // The muscle size and definition read it.

/**
 * A character's muscle size or definition, picked while their muscles don't follow their stats; shown on a slider, with
 * each step's name. One for the whole body. Applied before species, as the leg shape is, so a species change builds the limbs
 * at it; with the species unchanged, the limbs are swapped here.
 */
/datum/preference/numeric/muscles
	abstract_type = /datum/preference/numeric/muscles
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	priority = PREFERENCE_PRIORITY_PRE_SPECIES
	can_randomize = FALSE
	minimum = 0

/datum/preference/numeric/muscles/create_default_value()
	return 0

/datum/preference/numeric/muscles/is_accessible(datum/preferences/preferences)
	return ..() && species_has_fitness_limbs(preferences.read_preference(/datum/preference/choiced/species))

/datum/preference/numeric/muscles/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	if(preferences && (!is_applicable(preferences) || preferences.read_preference(/datum/preference/toggle/muscles_automatic)))
		value = 0
	target.dna.features[dna_feature()] = value
	// The species preference, applied next, rebuilds the outgoing preview species' body itself.
	if(target == preferences?.character_preview_view?.body && target.dna.species.type != preferences.read_preference(/datum/preference/choiced/species))
		return
	target.update_fitness_limbs()

/**
 * Returns the dna.features entry this preference goes in.
 */
/datum/preference/numeric/muscles/proc/dna_feature()
	return

/datum/preference/numeric/muscles/size
	savefile_key = "muscle_size"
	maximum = MUSCLE_SIZE_MUSCULAR

/datum/preference/numeric/muscles/size/dna_feature()
	return FEATURE_MUSCLE_SIZE

/datum/preference/numeric/muscles/size/compile_constant_data()
	. = ..()
	.["step_names"] = list("Normal", "Athletic", "Muscular")

/datum/preference/numeric/muscles/definition
	savefile_key = "muscle_definition"
	maximum = MUSCLE_DEFINITION_MAX

/datum/preference/numeric/muscles/definition/dna_feature()
	return FEATURE_MUSCLE_DEFINITION

/datum/preference/numeric/muscles/definition/compile_constant_data()
	. = ..()
	.["step_names"] = list("None", "Toned", "Defined", "Shredded")
