/// Armpit and pubic hair grow, restyle, colour and shave like hair and hide under clothes; armpit interactions need an arm, not hair.
/datum/unit_test/portal_test/body_hair

/datum/unit_test/portal_test/body_hair/Run()
	for(var/feature in list(FEATURE_PITS, FEATURE_PUBES))
		for(var/style, accessory_entry in SSaccessories.sprite_accessories[feature])
			var/datum/sprite_accessory/accessory = accessory_entry
			if(!accessory.factual)
				continue
			for(var/body in list("m", "f"))
				TEST_ASSERT(icon_exists(accessory.icon, "[accessory.icon_state]_[body]"), "[feature] style [style] has no [body] sprite.")

	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	person.set_body_hair(FEATURE_PITS, "Natural")
	var/obj/item/organ/body_hair/organ = person.get_organ_slot(ORGAN_SLOT_EXTERNAL_PITS)
	TEST_ASSERT(istype(organ, /obj/item/organ/body_hair/pits), "Natural armpit hair grew no hair.")
	TEST_ASSERT(chest_draws(person, "pits_natural_m"), "The chest doesn't draw armpit hair.")

	// It takes its own colour, or the head's when set to match.
	var/datum/bodypart_overlay/mutant/body_hair/overlay = organ.bodypart_overlay
	var/obj/item/bodypart/chest/chest = person.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(overlay.get_hair_colour(chest), BODY_HAIR_DEFAULT_COLOR, "Armpit hair didn't start in its own colour.")
	person.set_haircolor("#aa3311", update = TRUE)
	person.dna.features[FEATURE_BODY_HAIR_MATCHES_HAIR] = TRUE
	TEST_ASSERT_EQUAL(overlay.get_hair_colour(chest), "#aa3311", "Matching armpit hair didn't take the hair colour.")

	// A razor's styles: restyle, then shave off.
	person.set_body_hair(FEATURE_PITS, "Trimmed")
	TEST_ASSERT_EQUAL(overlay.sprite_datum.icon_state, "pits_trimmed", "Restyled armpit hair kept its old style.")
	person.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	TEST_ASSERT_NULL(person.get_organ_slot(ORGAN_SLOT_EXTERNAL_PITS), "Shaved armpit hair stayed.")
	TEST_ASSERT_EQUAL(person.get_body_hair(FEATURE_PITS), SPRITE_ACCESSORY_NONE, "Shaved armpit hair came back in the DNA.")

	person.set_body_hair(FEATURE_PUBES, "Heart")
	TEST_ASSERT(chest_draws(person, "pubes_heart_m"), "The chest doesn't draw pubic hair.")
	TEST_ASSERT_NULL(person.get_body_hair_cover(FEATURE_PUBES), "Bare pubic hair counted as covered.")
	var/obj/item/clothing/under/color/grey/pants = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(person.equip_to_slot_if_possible(pants, ITEM_SLOT_ICLOTHING), "Could not dress the test human.")
	TEST_ASSERT_EQUAL(person.get_body_hair_cover(FEATURE_PUBES), pants, "Pants didn't keep a razor off pubic hair.")
	TEST_ASSERT(!chest_draws(person, "pubes_heart_m"), "Pubic hair drew under pants.")

	// The colour picker only shows while body hair doesn't match the head.
	var/datum/client_interface/person_client = attach_portal_preferences(person)
	var/datum/preference/color/body_hair/preference = GLOB.preference_entries[/datum/preference/color/body_hair]
	TEST_ASSERT(!preference.is_accessible(person_client.prefs), "The body hair colour showed while matching the hair.")
	TEST_ASSERT(person_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/body_hair_matches_hair], FALSE), "Could not stop matching the hair colour.")
	TEST_ASSERT(preference.is_accessible(person_client.prefs), "The body hair colour stayed hidden while not matching.")

	// Armpit interactions need an arm there, hair or not.
	var/mob/living/carbon/human/consistent/partner = allocate(/mob/living/carbon/human/consistent)
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.name = "Sniff armpit"
	interaction.interaction_requires = list(INTERACTION_REQUIRE_TARGET_ARM)
	TEST_ASSERT(interaction.allow_act(partner, person), "An armpit interaction needed armpit hair.")
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		var/obj/item/bodypart/arm = person.get_bodypart(zone)
		arm.drop_limb(special = TRUE)
		qdel(arm)
	TEST_ASSERT(!interaction.allow_act(partner, person), "An armpit interaction reached someone with no arms.")

/// Whether the human's chest draws an overlay with `state`.
/datum/unit_test/portal_test/body_hair/proc/chest_draws(mob/living/carbon/human/person, state)
	var/obj/item/bodypart/chest/chest = person.get_bodypart(BODY_ZONE_CHEST)
	for(var/image/drawn in chest.get_limb_icon())
		if(drawn.icon_state == state)
			return TRUE
	return FALSE
