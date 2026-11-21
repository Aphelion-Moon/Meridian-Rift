/**
 * Blood and rips are drawn for a human body, so they must follow a worn sprite that sits elsewhere. This checks a
 * taur-fitted suit, moved 16 px left as a whole, and a Teshari's own uniform, drawn lower.
 */
/datum/unit_test/worn_stain_fit

/datum/unit_test/worn_stain_fit/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(/mob/living/carbon/human/consistent)
	give_feline_taur(taur)
	var/obj/item/clothing/suit/space/eva/suit = allocate(/obj/item/clothing/suit/space/eva)
	TEST_ASSERT(taur.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "A feline taur must be able to wear an EVA suit")
	stain(suit)
	taur.update_worn_oversuit()
	TEST_ASSERT(suit.worn_x_offset, "The EVA suit must be drawn from its taur sheet, moved left, for its stains to be checked - if it has no paw sprite now, wear one that has")
	for(var/stain_icon in list('icons/effects/blood.dmi', 'icons/effects/item_damage.dmi'))
		var/list/drawn_at = find_drawn(taur, SUIT_LAYER, stain_icon)
		TEST_ASSERT_NOTNULL(drawn_at, "A taur's stained EVA suit draws nothing from [stain_icon]")
		TEST_ASSERT_EQUAL(drawn_at[1], 0, "[stain_icon] on a taur-fitted suit must sit on the rider as on a human, not moved with the 64 px sprite")

	var/mob/living/carbon/human/consistent/bird = allocate(/mob/living/carbon/human/consistent)
	bird.set_species(/datum/species/teshari)
	var/obj/item/clothing/under/color/grey/jumpsuit = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(bird.equip_to_slot_if_possible(jumpsuit, ITEM_SLOT_ICLOTHING), "A Teshari must be able to wear a jumpsuit")
	stain(jumpsuit)
	bird.update_worn_undersuit()
	var/obj/item/bodypart/chest/chest = bird.get_bodypart(BODY_ZONE_CHEST)
	var/datum/worn_feature_offset/torso_offset = chest.worn_accessory_offset
	TEST_ASSERT_NOTNULL(torso_offset, "A Teshari's chest must move things drawn for a human torso, or its stains can't be checked")
	var/expected_y = torso_offset.get_offset()["y"]
	for(var/stain_icon in list('icons/effects/blood.dmi', 'icons/effects/item_damage.dmi'))
		var/list/drawn_at = find_drawn(bird, UNIFORM_LAYER, stain_icon)
		TEST_ASSERT_NOTNULL(drawn_at, "A Teshari's stained jumpsuit draws nothing from [stain_icon]")
		TEST_ASSERT_EQUAL(drawn_at[2], expected_y, "[stain_icon] on a Teshari's own jumpsuit must sit as low as the torso it's drawn on")

/// Bloodies and rips a garment
/datum/unit_test/worn_stain_fit/proc/stain(obj/item/clothing/garment)
	garment.add_blood_DNA(list("Test DNA" = get_blood_type(/datum/blood_type/human/o_minus)))
	garment.update_clothes_damaged_state(CLOTHING_DAMAGED)

/// Where the first image drawn from an icon file on a body's layer lands, as list(x, y): its offsets summed with its parents'
/datum/unit_test/worn_stain_fit/proc/find_drawn(mob/living/carbon/human/body, layer, icon_file)
	var/standing = body.overlays_standing[layer]
	return find_in(islist(standing) ? standing : list(standing), icon_file, 0, 0)

/// find_drawn's depth-first search, carrying the offset of the images above
/datum/unit_test/worn_stain_fit/proc/find_in(list/images, icon_file, x, y)
	for(var/mutable_appearance/drawn as anything in images)
		var/drawn_x = x + drawn.pixel_w
		var/drawn_y = y + drawn.pixel_z
		if(drawn.icon == icon_file)
			return list(drawn_x, drawn_y)
		var/list/found = find_in(drawn.overlays, icon_file, drawn_x, drawn_y)
		if(found)
			return found
