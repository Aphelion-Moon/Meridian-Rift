/// A Cerulean's tail is its lower body: it stays out of the DNA's tail entry, and a styled tail there never replaces it.
/datum/unit_test/cerulean_tail_kept

/datum/unit_test/cerulean_tail_kept/Run()
	var/mob/living/carbon/human/consistent/cerulean = allocate(__IMPLIED_TYPE__)
	cerulean.set_species(/datum/species/human/cerulean)
	TEST_ASSERT_NULL(cerulean.dna.mutant_bodyparts[FEATURE_TAIL], "The Cerulean tail wrote itself into the DNA's tail entry.")

	cerulean.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part(/datum/sprite_accessory/tails/felinid/cat::name)
	cerulean.dna.species.regenerate_organs(cerulean)
	var/obj/item/organ/tail = cerulean.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT(istype(tail, /obj/item/organ/tail/fish/cerulean), "Regenerating organs swapped the Cerulean tail for [tail?.type].")

/// Becoming a Cerulean sheds a taur body, which has no legs left to replace, and growing legs again brings it back.
/datum/unit_test/cerulean_sheds_taur

/datum/unit_test/cerulean_sheds_taur/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(__IMPLIED_TYPE__)
	var/legged_species = taur.dna.species.type
	give_feline_taur(taur)

	taur.set_species(/datum/species/human/cerulean)
	TEST_ASSERT_NULL(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), "A Cerulean kept its taur body.")
	var/obj/item/organ/tail = taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT(istype(tail, /obj/item/organ/tail/fish/cerulean), "The former taur grew [tail?.type] instead of the Cerulean tail.")
	TEST_ASSERT_NULL(taur.get_bodypart(BODY_ZONE_L_LEG), "The shed taur body left legs on a Cerulean.")

	taur.set_species(legged_species)
	TEST_ASSERT(istype(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body), "Growing legs again did not bring the taur body back.")

/// A fish tail's DNA block encodes like any other, so the feature blocks after it stay aligned.
/datum/unit_test/cerulean_dna_blocks_aligned

/datum/unit_test/cerulean_dna_blocks_aligned/Run()
	var/mob/living/carbon/human/consistent/cerulean = allocate(__IMPLIED_TYPE__)
	cerulean.set_species(/datum/species/human/cerulean)
	var/full_length = 0
	for(var/_block_type, block in GLOB.dna_feature_blocks)
		var/datum/dna_block/feature/feature_block = block
		full_length += feature_block.block_length
	TEST_ASSERT_EQUAL(length(cerulean.dna.unique_features), full_length, "Growing the fish tail shortened the unique features.")
	TEST_ASSERT_EQUAL(length(cerulean.dna.generate_unique_features()), full_length, "The fish tail's block encoded to the wrong length.")

/// Frills wear the Cerulean's tail colour unless the player chose a frills colour (mismatched parts on), and the tail keeps its preference.
/datum/unit_test/cerulean_frills_color

/datum/unit_test/cerulean_frills_color/Run()
	var/mob/living/carbon/human/species/cerulean/spawned = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(frills_color(spawned), LOWER_TEXT(spawned.dna.features[FEATURE_TAIL_FISH_COLOR]), "A spawned Cerulean's frills don't match its tail.")
	var/mob/living/carbon/human/species/cerulean/abyss/abyssal = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_EQUAL(frills_color(abyssal), LOWER_TEXT(abyssal.dna.features[FEATURE_TAIL_FISH_COLOR]), "An abyssal Cerulean's frills kept the colour from before its tail darkened.")

	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, allocate(/datum/client_interface))
	preferences.value_cache[/datum/preference/choiced/species] = /datum/species/human/cerulean
	preferences.value_cache[/datum/preference/color/fish_tail_color] = "#3366cc"
	preferences.value_cache[/datum/preference/toggle/cerulean_frills] = TRUE
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = FALSE
	var/mob/living/carbon/human/consistent/player = allocate(__IMPLIED_TYPE__)
	preferences.apply_prefs_to(player)
	TEST_ASSERT_EQUAL(LOWER_TEXT(player.dna.features[FEATURE_TAIL_FISH_COLOR]), "#3366cc", "The tail lost its colour preference.")
	TEST_ASSERT_EQUAL(frills_color(player), "#3366cc", "A player with mismatched parts off got frills that don't match their tail.")

	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	preferences.value_cache[/datum/preference/toggle/mutant_toggle/frills] = TRUE
	preferences.value_cache[/datum/preference/choiced/mutant_choice/frills] = /datum/sprite_accessory/frills/aquatic::name
	preferences.value_cache[/datum/preference/tri_color/frills] = list("#aa3311", "#aa3311", "#aa3311")
	var/mob/living/carbon/human/consistent/chooser = allocate(__IMPLIED_TYPE__)
	preferences.apply_prefs_to(chooser)
	TEST_ASSERT_EQUAL(frills_color(chooser), "#aa3311", "A chosen frills colour was replaced by the tail's.")

/// Returns the colour the Cerulean's frills draw in, lowercased.
/datum/unit_test/cerulean_frills_color/proc/frills_color(mob/living/carbon/human/cerulean)
	var/obj/item/organ/frills/frills = cerulean.get_organ_slot(ORGAN_SLOT_EXTERNAL_FRILLS)
	if(isnull(frills))
		TEST_FAIL("[cerulean.type] grew no frills.")
		return
	var/list/colors = frills.bodypart_overlay.draw_color
	return LOWER_TEXT(islist(colors) ? colors[1] : colors)

/// A female Cerulean draws the female tail, with its fins.
/datum/unit_test/cerulean_tail_female

/datum/unit_test/cerulean_tail_female/Run()
	var/mob/living/carbon/human/consistent/cerulean = allocate(__IMPLIED_TYPE__)
	cerulean.physique = FEMALE
	cerulean.set_species(/datum/species/human/cerulean)
	var/obj/item/organ/tail/fish/cerulean/tail = cerulean.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	var/obj/item/bodypart/chest/chest = cerulean.get_bodypart(BODY_ZONE_CHEST)

	var/drawn_states = 0
	for(var/mutable_appearance/drawn as anything in tail.bodypart_overlay.get_all_overlays(chest))
		if(!drawn.icon)
			continue
		drawn_states++
		TEST_ASSERT(findtext(drawn.icon_state, "f_") == 1, "A female Cerulean drew the tail state \"[drawn.icon_state]\".")
	TEST_ASSERT(drawn_states, "The Cerulean tail drew nothing.")
