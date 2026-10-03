/// Each language's description and icon go to character setup once a round, with the constant data, and a window update
/// names the languages alone; a secret language a species may learn is the exception and carries its own.
/datum/unit_test/preferences_language_info

/datum/unit_test/preferences_language_info/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference_middleware/languages/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware, "Preferences should have the languages middleware")
	var/list/info = middleware.get_constant_data()
	for(var/language_path, language_instance in GLOB.language_datum_instances)
		var/datum/language/language = language_instance
		if(language.secret)
			TEST_ASSERT(isnull(info[language.name]), "The secret [language.name] shouldn't be in the constant data")
			continue
		TEST_ASSERT_EQUAL(info[language.name]?["description"], language.desc, "[language.name]'s description should be in the constant data")
		TEST_ASSERT_EQUAL(info[language.name]?["icon"], sanitize_css_class_name(language.name), "[language.name]'s icon should be in the constant data")
	var/list/data = middleware.get_ui_data(mock_client.mob)
	var/list/sent = data["selected_languages"] + data["unselected_languages"]
	TEST_ASSERT(length(sent), "The window should be sent the languages a character knows or may learn")
	for(var/list/entry as anything in sent)
		var/datum/language/language = GLOB.language_datum_instances[middleware.name_to_language[entry["name"]]]
		TEST_ASSERT(language, "[entry["name"]] should name a language")
		if(language.secret)
			TEST_ASSERT_EQUAL(entry["description"], language.desc, "The secret [language.name] should carry its own description")
		else
			TEST_ASSERT(isnull(entry["description"]) && isnull(entry["icon"]), "[language.name] should be sent by name alone")

/// The window's markings and augments actions still do what they did, but ask for no full update of the window: each sends
/// it what it changed instead. The actions themselves still say whether they did anything.
/datum/unit_test/preferences_partial_updates

/datum/unit_test/preferences_partial_updates/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.value_cache[/datum/preference/choiced/species] = GLOB.species_list[SPECIES_HUMAN]
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/user = mock_client.mob
	var/datum/body_marking/heart = GLOB.body_markings_by_type[/datum/body_marking/tattoo/heart]
	preferences.body_markings = new /datum/body_marking_collection
	var/list/action = list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = heart.name)
	TEST_ASSERT(!middleware.act_add_marking(action, user), "Adding a marking from the window should ask for no full update")
	TEST_ASSERT(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, heart.name), "The window's add should still add the marking")
	TEST_ASSERT(!middleware.act_add_marking(action, user), "A refused add should ask for no update either")
	TEST_ASSERT_EQUAL(preferences.body_markings.entry_count(), 1, "A refused add should add nothing")
	var/list/row = list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1")
	TEST_ASSERT(!middleware.act_color_marking(row + list("color" = "#12ab34"), user), "Painting from the window should ask for no full update")
	TEST_ASSERT_EQUAL(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, heart.name).get_color(), "#12ab34", "The window's paint should still paint")
	TEST_ASSERT(!middleware.act_remove_marking(row, user), "Removing from the window should ask for no full update")
	TEST_ASSERT(!preferences.body_markings.entry_count(), "The window's remove should still remove the marking")
	TEST_ASSERT(middleware.add_marking(action, user), "The action itself should still say it added the marking")
	var/datum/augment_item/limb/arm = GLOB.augment_items[/datum/augment_item/limb/l_arm/cyborg]
	TEST_ASSERT(!middleware.act_set_bodypart_aug(list("slot" = arm.slot, "augment_path" = "[arm.type]"), user), "Fitting an augment from the window should ask for no full update")
	TEST_ASSERT_EQUAL(preferences.augments[arm.slot], arm.type, "The window's augment should still be fitted")
	TEST_ASSERT(middleware.set_bodypart_aug(list("slot" = arm.slot, "augment_path" = "[arm.type]"), user), "The augment action itself should still say it did something")
