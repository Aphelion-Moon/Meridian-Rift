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

/datum/species/moth/get_random_body_markings(list/passed_features)
	var/name = SPRITE_ACCESSORY_NONE
	// The sets meant for any species or for this one, gathered rather than removed from a list being looped over.
	var/list/candidates
	for(var/set_name, set_datum in GLOB.body_marking_sets)
		var/datum/body_marking_set/setter = set_datum
		if(isnull(setter.recommended_species) || !isnull(setter.recommended_species[id]))
			LAZYADD(candidates, set_name)
	if(length(candidates))
		name = pick(candidates)
	var/datum/body_marking_set/BMS = GLOB.body_marking_sets[name]
	var/datum/body_marking_collection/markings = new
	if(BMS)
		markings = assemble_body_markings_from_set(BMS, passed_features, src)
	return markings

/datum/species/moth/prepare_human_for_preview(mob/living/carbon/human/moth)
	moth.dna.features[FEATURE_MUTANT_COLOR] = "#E5CD99"
	moth.dna.mutant_bodyparts[FEATURE_MOTH_ANTENNAE] = build_mutant_part("Plain")
	moth.dna.mutant_bodyparts[FEATURE_MOTH_MARKINGS] = build_mutant_part(SPRITE_ACCESSORY_NONE)
	moth.dna.mutant_bodyparts[FEATURE_WINGS] = build_mutant_part("Moth (Plain)")
	regenerate_organs(moth, src, visual_only = TRUE)
	moth.update_body(TRUE)
