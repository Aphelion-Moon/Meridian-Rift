/datum/unit_test/digi_underclothes_sanity

/datum/unit_test/digi_underclothes_sanity/Run()
	// The icon files where digi underwear resides
	var/list/digi_underclothes_icon_files = list(
		'modular_nova/master_files/icons/mob/clothing/underwear.dmi' = TRUE,
	)

	// Checks whether we have a digi icon_state (denoted by "_d")
	for (var/datum/sprite_accessory/clothing/clothing_accessory as anything in valid_subtypesof(/datum/sprite_accessory/clothing))
		var/has_digi_sprite = FALSE
		if (digi_underclothes_icon_files[clothing_accessory::icon] && clothing_accessory::icon_state)
			var/digi_icon_state = "[clothing_accessory::icon_state]_d"
			has_digi_sprite = icon_exists(clothing_accessory::icon, digi_icon_state)

		if (has_digi_sprite && !clothing_accessory::has_custom_digi_sprite)
			TEST_FAIL("[clothing_accessory] ([clothing_accessory::icon_state]) has a '_d' version of the sprite but has_custom_digi_sprite = FALSE (should be TRUE)")

		else if (!has_digi_sprite && clothing_accessory::has_custom_digi_sprite)
			TEST_FAIL("[clothing_accessory] ([clothing_accessory::icon_state]) has_custom_digi_sprite = TRUE but no '_d' version of the sprite exists (should be FALSE)")

/// A human with no bra (nor underwear, undershirt or socks) draws nothing in BODY_LAYER: the Nude bra draws no empty
/// appearance and emissive blocker, as the other Nude accessories draw none. With a bra, the bra is drawn there.
/datum/unit_test/braless_body_layer/Run()
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	human.underwear = "Nude"
	human.undershirt = "Nude"
	human.socks = "Nude"
	human.bra = "Nude"
	human.update_body()
	TEST_ASSERT_NULL(human.overlays_standing[BODY_LAYER], "A human with no underclothes draws [length(human.overlays_standing[BODY_LAYER])] appearances in BODY_LAYER.")
	human.bra = "Bra"
	human.update_body()
	TEST_ASSERT(length(human.overlays_standing[BODY_LAYER]), "A human with a bra draws nothing in BODY_LAYER.")
