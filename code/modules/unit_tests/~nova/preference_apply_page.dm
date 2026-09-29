/// The same preferences build the same character whatever setup page their player last had open: what a character gets is
/// asked with is_applicable(), which leaves out the page test is_accessible() makes for the menu. Each fixture is loaded as a
/// connection loads a character and built on fresh bodies, as a spawn does and as the preview draws, with the character page
/// open, the game page open and the keybindings open, and every body must match the one built on the character page: its
/// pixels, mutant parts, limbs and organs (where augments go), DNA features (where the genital fields go), traits and blood
/// type. Each fixture also checks the thing it is about on the character page, so none can pass by building nothing, and each
/// but one pins the blood type to the test body's own, so only the fixture about blood types depends on it.
/datum/unit_test/preference_apply_page
	// Forty-two bodies built and flattened.
	priority = TEST_LONGER

/datum/unit_test/preference_apply_page/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/window = preferences.current_window
	// name -> the savefile tree's keys beyond the current version's own
	var/list/fixtures = list(
		"a taur with a leg augment" = list("species" = SPECIES_MAMMAL, "taur_toggle" = TRUE, "feature_taur" = "Bunny", "augments" = list(AUGMENT_SLOT_L_LEG = "[/datum/augment_item/limb/l_leg/digi_prosthetic]")),
		"a knot" = list("species" = SPECIES_HUMAN, "feature_penis" = "Knotted", "has_knot" = TRUE),
		"a penis with taur art, taur mode off" = list("species" = SPECIES_HUMAN, "feature_penis" = "Flared", "penis_taur_mode_toggle" = FALSE),
		"a penis with a sheath" = list("species" = SPECIES_HUMAN, "feature_penis" = "Nondescript", "penis_sheath" = "Sheath"),
		"a human with skin tones off" = list("species" = SPECIES_HUMAN, "skin_tone_toggle" = FALSE),
		"a chosen blood type" = list("species" = SPECIES_HUMAN, "blood_type" = /datum/blood_type/human/ab_plus::name),
		"a plain human" = list("species" = SPECIES_HUMAN),
	)
	for(var/fixture_name, fixture_keys in fixtures)
		var/list/slot = list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "allow_mismatched_parts_toggle" = FALSE, "blood_type" = /datum/blood_type/human/o_minus::name)
		var/list/extra_keys = fixture_keys
		for(var/key, value in extra_keys)
			slot[key] = value
		preferences.savefile.set_entry("character[preferences.default_slot]", slot)
		preferences.value_cache = list()
		TEST_ASSERT(preferences.load_character(preferences.default_slot), "[fixture_name] must load")
		for(var/visuals_only in list(FALSE, TRUE))
			var/build = visuals_only ? "drawn for the preview" : "spawned"
			var/on_character_page
			for(var/page in list(PREFERENCE_TAB_CHARACTER_PREFERENCES, PREFERENCE_TAB_GAME_PREFERENCES, PREFERENCE_TAB_KEYBINDINGS))
				preferences.current_window = page
				var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
				preferences.apply_prefs_to(body, TRUE, visuals_only = visuals_only)
				var/signature = body_signature(body)
				// Not an assertion: every fixture and page is checked, so a failure names each one the page still decides.
				if(page == PREFERENCE_TAB_CHARACTER_PREFERENCES)
					on_character_page = signature
					check_fixture(fixture_name, body, build)
				else if(signature != on_character_page)
					TEST_FAIL("[fixture_name] [build] with setup page [page] open must be the character built on the character page: [signature] vs [on_character_page]")
	preferences.current_window = window

/**
 * Signs a body with everything its preferences give it that the setup page could change.
 *
 * Returns the signature as text, so two compare with one assertion.
 */
/datum/unit_test/preference_apply_page/proc/body_signature(mob/living/carbon/human/body)
	var/list/record = list()
	var/list/pixels = markings_baseline_signature(get_flat_icon_for_all_directions(body))
	record["pixels"] = pixels["pixels_md5"]
	var/list/parts = list()
	for(var/key, part_datum in body.dna.mutant_bodyparts)
		var/datum/mutant_bodypart/part = part_datum
		parts += "[key]=[part.name]|[json_encode(part.get_colors())]|[json_encode(part.get_emissive_tri_bool_list())]"
	record["mutant_parts"] = parts
	var/list/limbs = list()
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		limbs += "[limb.body_zone]=[limb.type]"
	record["limbs"] = sortTim(limbs, GLOBAL_PROC_REF(cmp_text_asc))
	var/list/organs = list()
	for(var/obj/item/organ/organ as anything in body.organs)
		organs += "[organ.slot]=[organ.type]"
	record["organs"] = sortTim(organs, GLOBAL_PROC_REF(cmp_text_asc))
	var/list/features = list()
	for(var/key, value in body.dna.features)
		features += "[key]=[json_encode(value)]"
	record["features"] = sortTim(features, GLOBAL_PROC_REF(cmp_text_asc))
	var/list/traits = list()
	for(var/trait in list(TRAIT_CAN_KNOT, TRAIT_USES_SKINTONES, TRAIT_MUTANT_COLORS))
		traits[trait] = HAS_TRAIT(body, trait) ? TRUE : FALSE
	record["traits"] = traits
	record["blood_type"] = "[body.get_bloodtype()?.type]"
	return json_encode(record)

/// Checks, on the body built with the character page open, the thing a fixture is about.
/datum/unit_test/preference_apply_page/proc/check_fixture(fixture_name, mob/living/carbon/human/body, build)
	switch(fixture_name)
		if("a taur with a leg augment")
			TEST_ASSERT(body.dna.mutant_bodyparts[FEATURE_TAUR], "[fixture_name] [build] must be a taur")
			var/datum/augment_item/leg_augment = GLOB.augment_items[/datum/augment_item/limb/l_leg/digi_prosthetic]
			TEST_ASSERT(!istype(body.get_bodypart(BODY_ZONE_L_LEG), leg_augment.path), "[fixture_name] [build] must refuse the leg augment, as the taur takes the legs' place")
		if("a knot")
			TEST_ASSERT(HAS_TRAIT(body, TRAIT_CAN_KNOT), "[fixture_name] [build] must be able to knot")
		if("a penis with taur art, taur mode off")
			TEST_ASSERT_EQUAL(body.dna.features["penis_taur_mode"], FALSE, "[fixture_name] [build] must have taur mode off")
		if("a penis with a sheath")
			TEST_ASSERT_EQUAL(body.dna.features["penis_sheath"], "Sheath", "[fixture_name] [build] must have the sheath")
		if("a human with skin tones off")
			TEST_ASSERT(!HAS_TRAIT(body, TRAIT_USES_SKINTONES) && HAS_TRAIT(body, TRAIT_MUTANT_COLORS), "[fixture_name] [build] must use mutant colours")
		if("a chosen blood type")
			TEST_ASSERT_EQUAL(body.get_bloodtype()?.type, /datum/blood_type/human/ab_plus, "[fixture_name] [build] must have the chosen blood type")
		if("a plain human")
			TEST_ASSERT(istype(body.dna.species, /datum/species/human), "[fixture_name] [build] must be a human")
