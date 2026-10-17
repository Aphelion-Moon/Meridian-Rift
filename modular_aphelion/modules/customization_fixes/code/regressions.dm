#ifdef UNIT_TESTS
/// Every randomized primitive-kobold part must have a compatible accessory.
/datum/unit_test/primitive_kobold_accessories/Run()
	var/datum/species/monkey/kobold/species = allocate(__IMPLIED_TYPE__)
	var/list/blueprints = species.get_default_mutant_bodyparts()
	for(var/key in blueprints)
		var/datum/mutant_bodypart/species_blueprint/blueprint = blueprints[key]
		if(!blueprint.is_randomizable)
			continue
		var/list/choices = accessory_list_of_key_for_species(key, species, FALSE)
		TEST_ASSERT(length(choices), "Primitive kobolds have no compatible [key] accessories.")
	var/mob/living/carbon/human/species/monkey/kobold/kobold = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT(kobold.dna.mutant_bodyparts[FEATURE_SNOUT], "Primitive kobold initialization omitted its snout.")

/// A split-color horn has only a secondary front sprite; absent channels must not emit.
/datum/unit_test/matrixed_accessory_sparse_emissives/Run()
	var/datum/bodypart_overlay/mutant/horns/overlay = allocate(__IMPLIED_TYPE__)
	var/datum/sprite_accessory/horns/angler/polish/accessory = SSaccessories.sprite_accessories[FEATURE_HORNS][/datum/sprite_accessory/horns/angler/polish::name]
	TEST_ASSERT_NOTNULL(accessory, "The existing dual-color angler accessory must be registered.")
	var/obj/item/bodypart/head/lizard/head = allocate(__IMPLIED_TYPE__)
	overlay.sprite_datum = accessory
	var/list/visible = overlay.get_images(head, EXTERNAL_FRONT, -BODY_FRONT_LAYER)
	TEST_ASSERT_EQUAL(length(visible), 2, "Matrixed color slots must retain their original indices.")
	var/list/rendered = overlay.add_emissives(visible, head, EXTERNAL_FRONT)
	TEST_ASSERT_EQUAL(length(rendered), length(visible) + 1, "Only the existing front color channel should emit.")
	var/mutable_appearance/glow = rendered[length(rendered)]
	TEST_ASSERT_EQUAL(glow.icon_state, "m_horns_angler_FRONT_secondary", "The surviving secondary channel lost its glow.")
#endif
