/datum/species/moth
	inherent_traits = list(
		TRAIT_MUTANT_COLORS,
	)

/datum/species/moth/get_default_mutant_bodyparts()
	return list(
		FEATURE_MOTH_MARKINGS = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
		FEATURE_EARS = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
		FEATURE_FLUFF = MUTPART_BLUEPRINT("Plain", is_randomizable = FALSE),
		FEATURE_WINGS = MUTPART_BLUEPRINT("Moth (Plain)", is_randomizable = TRUE),
		FEATURE_MOTH_ANTENNAE = MUTPART_BLUEPRINT("Plain", is_randomizable = TRUE),
	)

/datum/species/moth/randomize_features()
	var/list/features = ..()
	features[FEATURE_MUTANT_COLOR] = "#E5CD99"
	return features

/datum/species/moth/get_random_marking_sets()
	return body_marking_set_types_for_species(id)

/datum/species/moth/prepare_human_for_preview(mob/living/carbon/human/moth)
	moth.dna.features[FEATURE_MUTANT_COLOR] = "#E5CD99"
	moth.dna.mutant_bodyparts[FEATURE_MOTH_ANTENNAE] = build_mutant_part("Plain")
	moth.dna.mutant_bodyparts[FEATURE_MOTH_MARKINGS] = build_mutant_part(SPRITE_ACCESSORY_NONE)
	moth.dna.mutant_bodyparts[FEATURE_WINGS] = build_mutant_part("Moth (Plain)")
	regenerate_organs(moth, src, visual_only = TRUE)
	moth.update_body(TRUE)
