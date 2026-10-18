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
