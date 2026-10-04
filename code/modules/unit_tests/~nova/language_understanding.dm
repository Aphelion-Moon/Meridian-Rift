/// Only a language the character only understands takes a partial understanding level, which never adds a language, reaches the body as partial understanding, and saves and loads sanitised.
/datum/unit_test/language_understanding

/datum/unit_test/language_understanding/Run()
	TEST_ASSERT_EQUAL(snap_language_understanding(250), 100, "Nothing should go past full understanding")

	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.languages = list(
		/datum/language/common = LANGUAGE_SPOKEN,
		/datum/language/draconic = LANGUAGE_UNDERSTOOD,
	)
	var/datum/preference_middleware/language_understanding/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware, "Preferences should have the language understanding middleware")
	var/datum/language/common = GLOB.language_datum_instances[/datum/language/common]
	var/datum/language/draconic = GLOB.language_datum_instances[/datum/language/draconic]
	var/datum/language/moffic = GLOB.language_datum_instances[/datum/language/moffic]

	// Only a language the character only understands takes a level.
	TEST_ASSERT(!middleware.set_language_understanding(list("language_name" = common.name, "level" = 40)), "A spoken language should take no level")
	TEST_ASSERT(!middleware.set_language_understanding(list("language_name" = "Not a language", "level" = 40)), "An unknown name should take no level")
	TEST_ASSERT(!middleware.set_language_understanding(list("language_name" = draconic.name, "level" = "40")), "A level should be a number")
	TEST_ASSERT(!middleware.set_language_understanding(list("language_name" = moffic.name, "level" = 50)), "A language not picked should take no level")
	TEST_ASSERT(isnull(preferences.languages[/datum/language/moffic]), "Setting a level should never add a language")
	TEST_ASSERT(middleware.set_language_understanding(list("language_name" = draconic.name, "level" = 42)), "An understood-only language should take a level")
	var/level = snap_language_understanding(42)
	TEST_ASSERT(level < 100 && preferences.language_understanding_level(/datum/language/draconic) == level, "The level should be snapped to a step")

	// A body gets the level as partial understanding, and applying again at full replaces it.
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	var/datum/language_holder/holder = body.get_language_holder()
	holder.adjust_languages_to_prefs(preferences)
	TEST_ASSERT(!body.has_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE), "A partial level shouldn't understand the language outright")
	TEST_ASSERT_EQUAL(body.has_partial_language(/datum/language/draconic), level, "The body should follow the language at its level")
	TEST_ASSERT(body.has_language(/datum/language/common, SPOKEN_LANGUAGE), "Spoken languages should be granted as before")
	middleware.set_language_understanding(list("language_name" = draconic.name, "level" = 100))
	holder.adjust_languages_to_prefs(preferences)
	TEST_ASSERT(body.has_language(/datum/language/draconic, UNDERSTOOD_LANGUAGE), "At full, the language should be understood")
	TEST_ASSERT(!body.has_partial_language(/datum/language/draconic), "No old partial level should be left behind")

	// Saves keep understood-only languages below full; loading keeps real languages with a level, snapped.
	middleware.set_language_understanding(list("language_name" = draconic.name, "level" = 55))
	preferences.language_understanding[/datum/language/common] = 30
	var/list/saved = preferences.saved_language_understanding()
	TEST_ASSERT_EQUAL(length(saved), 1, "Only understood-only languages below full should be saved")
	TEST_ASSERT_EQUAL(saved["[/datum/language/draconic]"], snap_language_understanding(55), "The saved level should be the one set")
	var/list/loaded = sanitize_language_understanding(list(
		"[/datum/language/draconic]" = 57,
		"/datum/language/not_a_language" = 50,
		"[/datum/language/moffic]" = "fifty",
		"[/datum/language/uncommon]" = 100,
	))
	TEST_ASSERT_EQUAL(length(loaded), 1, "Only real languages with a number below full should load")
	TEST_ASSERT_EQUAL(loaded[/datum/language/draconic], snap_language_understanding(57), "A loaded level should snap to a step")
