/// Paints custom hair and facial hair over a bald, shaved head. Returns the head.
/proc/custom_hair_interaction_test_subject(mob/living/carbon/human/human)
	var/list/drawing = list("version" = 1, "palette" = list("#aa5500"), "tint" = null, "dirs" = list("2" = custom_sprite_encode_grid(repeat_string(1024, "1"))))
	human.set_hairstyle("Bald", update = FALSE)
	human.set_facial_hairstyle("Shaved", update = FALSE)
	human.dna.custom_hair = drawing
	human.dna.custom_facial_hair = deep_copy_list(drawing)
	human.sync_custom_sprite_appearance()
	return human.get_bodypart(BODY_ZONE_HEAD)

/// Custom hair on a bald head can be tied up; a bald head without it can't.
/datum/unit_test/custom_hair_takes_hair_tie/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	custom_hair_interaction_test_subject(human)
	var/obj/item/clothing/head/hair_tie/tie = allocate(/obj/item/clothing/head/hair_tie)
	TEST_ASSERT(tie.mob_can_equip(human, ITEM_SLOT_HEAD, disable_warning = TRUE), "Custom hair on a bald head should take a hair tie")
	human.dna.custom_hair = null
	human.sync_custom_sprite_appearance()
	TEST_ASSERT(!tie.mob_can_equip(human, ITEM_SLOT_HEAD, disable_warning = TRUE), "A bald head without custom hair has nothing to tie up")

/// Shaving takes custom hair and facial hair off with the hair beneath them.
/datum/unit_test/custom_hair_shaves_off/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = custom_hair_interaction_test_subject(human)
	var/obj/item/razor/razor = allocate(/obj/item/razor)
	razor.shave(human, BODY_ZONE_HEAD)
	TEST_ASSERT(!head.custom_hair && !human.dna.custom_hair, "Shaving the head should take the custom hair off")
	TEST_ASSERT(head.custom_facial_hair, "Shaving the head should leave the custom facial hair")
	razor.shave(human, BODY_ZONE_PRECISE_MOUTH)
	TEST_ASSERT(!head.custom_facial_hair && !human.dna.custom_facial_hair, "Shaving the face should take the custom facial hair off")

/// Hair falling out takes custom hair and facial hair with it.
/datum/unit_test/custom_hair_falls_out/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = custom_hair_interaction_test_subject(human)
	human.dna.species.go_bald(human)
	TEST_ASSERT(!head.custom_hair && !head.custom_facial_hair, "Hair falling out should take custom hair and facial hair with it")
