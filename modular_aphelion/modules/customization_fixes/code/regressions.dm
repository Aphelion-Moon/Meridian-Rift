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
#endif
