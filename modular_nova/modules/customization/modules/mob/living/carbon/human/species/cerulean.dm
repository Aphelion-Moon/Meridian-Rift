/datum/species/human/cerulean
	digitigrade_customization = DIGITIGRADE_NEVER

// The fish tail is the Cerulean's lower body, so there are no tail or legs choices to make.
/datum/species/human/cerulean/get_default_mutant_bodyparts()
	return list(
		FEATURE_EARS = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
		FEATURE_WINGS = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
	)

/obj/item/organ/tail/fish/cerulean
	// Not a styled tail: it neither writes nor clears the DNA's tail entry, which the DNA pass would swap it for.
	mutantpart_key = null

/obj/item/organ/frills/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	// Frills without a colour of their own wear the Cerulean's tail colour: a player with no frills preference
	// (mismatched parts off), or a body spawned without preferences. Nova's insert hook then stores it in the DNA.
	if(organ_owner.dna && isnull(organ_owner.dna.mutant_bodyparts[FEATURE_FRILLS]) && organ_owner.has_cerulean_tail())
		var/tail_color = organ_owner.dna.features[FEATURE_TAIL_FISH_COLOR]
		bodypart_overlay.draw_color = list(tail_color, tail_color, tail_color)
	return ..()

/// Returns whether this body wears a Cerulean tail, or its species grows one.
/mob/living/carbon/proc/has_cerulean_tail()
	return istype(get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/fish/cerulean) \
		|| ispath(dna?.species?.get_mutant_organ_type_for_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/fish/cerulean)

/// Repaints the frills, DNA included, in the tail's colour. For bodies whose tail changes colour after their frills grow.
/mob/living/carbon/human/proc/match_frills_to_tail()
	var/obj/item/organ/frills/frills = get_organ_slot(ORGAN_SLOT_EXTERNAL_FRILLS)
	if(isnull(frills))
		return
	var/tail_color = dna.features[FEATURE_TAIL_FISH_COLOR]
	var/list/colors = list(tail_color, tail_color, tail_color)
	var/datum/mutant_bodypart/frills_part = dna.mutant_bodyparts[FEATURE_FRILLS]
	frills_part?.set_colors(colors)
	frills.bodypart_overlay.draw_color = colors
	update_body_parts()

/datum/preference/toggle/cerulean_frills/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	// Frills from the mutant part preferences (mismatched parts on) stand. Rebuilding for the aquatic default would delete them.
	if(target.dna.mutant_bodyparts[FEATURE_FRILLS])
		return
	return ..()

/mob/living/carbon/human/species/cerulean/abyss/set_species(datum/species/mrace, icon_update, pref_load, replace_missing, list/override_features, list/override_mutantparts, list/override_markings)
	. = ..()
	match_frills_to_tail() // Its tail darkens after the frills grow
