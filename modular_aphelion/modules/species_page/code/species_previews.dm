// Species page previews for species whose default look doesn't read as themselves.

/// A friendly hammerhead: baby blue with a white belly, eyes on the hammer and a darker fin.
/datum/species/aquatic/prepare_human_for_preview(mob/living/carbon/human/shark)
	var/main_color = "#8EC5E8"
	var/belly_color = "#FFFFFF"
	var/fin_color = "#5B8FB5"
	shark.dna.features[FEATURE_MUTANT_COLOR] = main_color
	shark.dna.features[FEATURE_MUTANT_COLOR_TWO] = belly_color
	shark.dna.features[FEATURE_MUTANT_COLOR_THREE] = fin_color
	shark.dna.mutant_bodyparts[FEATURE_SNOUT] = build_mutant_part("hShark and eyes", list(main_color, belly_color, fin_color))
	shark.dna.mutant_bodyparts[FEATURE_EARS] = build_mutant_part("Hammerhead", list(main_color, belly_color, fin_color))
	shark.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part("Shark", list(main_color, belly_color, fin_color))
	shark.dna.features[FEATURE_LEGS] = NORMAL_LEGS
	shark.dna.body_markings = assemble_body_markings_from_set(GLOB.body_marking_sets["Shark"], shark.dna.features, src)
	shark.set_hairstyle("Bald", update = FALSE)
	shark.set_eye_color("#0E1A26")
	regenerate_organs(shark, src, visual_only = TRUE)
	shark.update_body(TRUE)

/// Coastal red scales over a sand belly, bone horns and a spine ridge, after the common Unathi look.
/datum/species/unathi/prepare_human_for_preview(mob/living/carbon/human/unathi)
	var/scale_color = "#8C3A22"
	var/belly_color = "#D8B07A"
	var/ridge_color = "#4A1C12"
	var/horn_color = "#D6C8A6"
	unathi.dna.features[FEATURE_MUTANT_COLOR] = scale_color
	unathi.dna.features[FEATURE_MUTANT_COLOR_TWO] = belly_color
	unathi.dna.features[FEATURE_MUTANT_COLOR_THREE] = ridge_color
	unathi.dna.mutant_bodyparts[FEATURE_SNOUT] = build_mutant_part("Sharp + Light", list(scale_color, belly_color, ridge_color))
	unathi.dna.mutant_bodyparts[FEATURE_HORNS] = build_mutant_part("Curled", list(horn_color, horn_color, horn_color))
	unathi.dna.mutant_bodyparts[FEATURE_FRILLS] = build_mutant_part("Short", list(scale_color, belly_color, ridge_color))
	unathi.dna.mutant_bodyparts[FEATURE_SPINES] = build_mutant_part("Long", list(ridge_color, ridge_color, ridge_color))
	unathi.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part("Smooth", list(scale_color, belly_color, ridge_color))
	unathi.dna.features[FEATURE_LEGS] = NORMAL_LEGS
	unathi.dna.body_markings = assemble_body_markings_from_set(GLOB.body_marking_sets["Belly"], unathi.dna.features, src)
	unathi.set_hairstyle("Bald", update = FALSE)
	unathi.set_eye_color("#E3A21A")
	regenerate_organs(unathi, src, visual_only = TRUE)
	unathi.update_body(TRUE)

/**
 * Headless, with the head in a hand, as in the round. A body in nullspace keeps its head on - on_species_gain() has
 * nowhere to drop it - so it comes off here, with the plain eyes the round gives it. A dummy's head has no brain, which
 * would draw it opened up; the round's has one.
 */
/datum/species/dullahan/prepare_human_for_preview(mob/living/carbon/human/dullahan)
	var/obj/item/bodypart/head/head = dullahan.get_bodypart(BODY_ZONE_HEAD)
	if(isnull(head))
		return
	head.head_flags &= ~HEAD_DEBRAIN
	head.drop_limb(special = TRUE, move_to_floor = FALSE)
	var/obj/item/organ/eyes/eyes = new /obj/item/organ/eyes(head)
	eyes.eye_color_left = dullahan.eye_color_left
	eyes.eye_color_right = dullahan.eye_color_right
	eyes.bodypart_insert(head)
	head.update_limb()
	head.update_icon_dropped()
	dullahan.put_in_hands(head)

/// The head in the hand the round puts it in, the left, where tg's in-hand sprites hold things facing each way - no in-hand
/// sprite draws a held head. It faces the way the body does.
/datum/species/dullahan/species_page_held_icon(mob/living/carbon/human/dullahan)
	var/obj/item/bodypart/head/head = dullahan.is_holding_item_of_type(/obj/item/bodypart/head)
	if(isnull(head))
		return null
	var/static/list/in_hand = list(
		"[SOUTH]" = list(7, -6),
		"[NORTH]" = list(-6, -6),
		"[EAST]" = list(5, -6),
		"[WEST]" = list(3, -6),
	)
	return list(get_flat_uni_icon(head, UP), in_hand)
