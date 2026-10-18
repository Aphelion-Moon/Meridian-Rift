/// DNA-less carbons retain ordinary and temporary examine text without entering the DNA flavor renderer.
/datum/unit_test/runtime_carbon_examine

/datum/unit_test/runtime_carbon_examine/Run()
	var/mob/living/carbon/human/viewer = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/alien/alien = allocate(/mob/living/carbon/alien/larva)
	alien.temporary_flavor_text = "A distinctive temporary marking."
	var/list/alien_description = alien.examine(viewer)
	TEST_ASSERT(length(alien_description), "A DNA-less alien must retain its ordinary examine description.")
	TEST_ASSERT(findtext(alien_description.Join("\n"), alien.temporary_flavor_text), "Alien temporary flavor must remain visible without DNA.")
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.dna.features["flavor_text"] = "A distinctive permanent marking."
	var/list/human_description = human.examine(viewer)
	TEST_ASSERT(findtext(human_description.Join("\n"), "A distinctive permanent marking."), "Human DNA flavor must remain visible.")
