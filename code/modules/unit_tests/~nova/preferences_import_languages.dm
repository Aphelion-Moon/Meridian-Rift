/// Exports a character's preferences as the export verb writes them, and imports the file as the import verb reads it,
/// returning the importing preferences once the import has finished.
/datum/unit_test/proc/prefs_import_round_trip(datum/preferences/source, list/edit_slot)
	var/list/upload = json_decode(json_encode(source.savefile.get_entry(), JSON_PRETTY_PRINT))
	if(edit_slot)
		var/list/slot = upload["character[source.default_slot]"]
		for(var/key in edit_slot)
			slot[key] = edit_slot[key]
	var/datum/client_interface/client = allocate(/datum/client_interface)
	var/datum/preferences/target = allocate(/datum/preferences/preferences_import_test, client)
	var/list/tree = prefs_import_pass1(upload, target.savefile.get_entry())
	for(var/key in tree)
		target.savefile.set_entry(key, tree[key])
	target.value_cache = list()
	if(!target.prefs_import_finalise())
		return null
	return target

/// Languages survive exporting a character and importing the file: which it speaks, which it only understands, and how
/// much of those it follows; and a character made from the import speaks.
/datum/unit_test/preferences_import_languages/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/source = allocate(/datum/preferences/preferences_import_test, mock_client)
	source.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_LIZARD)
	source.languages = list(/datum/language/common = LANGUAGE_SPOKEN, /datum/language/draconic = LANGUAGE_SPOKEN, /datum/language/uncommon = LANGUAGE_UNDERSTOOD)
	source.language_understanding = list(/datum/language/uncommon = 50)
	source.save_character()

	var/datum/preferences/imported = prefs_import_round_trip(source)
	TEST_ASSERT_NOTNULL(imported, "The exported preferences should import")
	TEST_ASSERT_EQUAL(json_encode(imported.languages), json_encode(source.languages), "Importing should keep the character's languages")
	TEST_ASSERT_EQUAL(imported.language_understanding_level(/datum/language/uncommon), 50, "Importing should keep how much of a language the character follows")
	var/mob/living/carbon/human/consistent/character = allocate(/mob/living/carbon/human/consistent)
	imported.apply_prefs_to(character)
	TEST_ASSERT(character.get_language_holder().can_speak_language(/datum/language/common), "A character imported speaking Common should speak it")
	TEST_ASSERT(!character.get_language_holder().can_speak_language(/datum/language/uncommon), "A character imported only understanding a language shouldn't speak it")

/// A file from elsewhere may hold what a character knows of a language as text, or as tg's language flags. Imported, the
/// character speaks what it spoke and understands what it understood, and a language it knows nothing of is dropped.
/datum/unit_test/preferences_import_language_knowledge/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/source = allocate(/datum/preferences/preferences_import_test, mock_client)
	source.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_LIZARD)
	source.save_character()
	var/list/knowledge = list(
		"/datum/language/common" = "2",
		"/datum/language/draconic" = 3,
		"/datum/language/uncommon" = "1",
		"/datum/language/moffic" = 0,
	)
	var/datum/preferences/imported = prefs_import_round_trip(source, list("languages" = knowledge))
	TEST_ASSERT_NOTNULL(imported, "The file should import")
	TEST_ASSERT_EQUAL(imported.languages[/datum/language/common], LANGUAGE_SPOKEN, "A language spoken, held as text, should import spoken")
	TEST_ASSERT_EQUAL(imported.languages[/datum/language/draconic], LANGUAGE_SPOKEN, "A language spoken and understood, held as flags, should import spoken")
	TEST_ASSERT_EQUAL(imported.languages[/datum/language/uncommon], LANGUAGE_UNDERSTOOD, "A language only understood, held as text, should import understood")
	TEST_ASSERT(isnull(imported.languages[/datum/language/moffic]), "A language known not at all should be dropped")
	var/mob/living/carbon/human/consistent/character = allocate(/mob/living/carbon/human/consistent)
	imported.apply_prefs_to(character)
	TEST_ASSERT(character.get_language_holder().can_speak_language(/datum/language/common), "A character imported speaking Common as text should speak it")

/// A character imported with no languages speaks its species' languages, rather than none.
/datum/unit_test/preferences_import_no_languages/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/source = allocate(/datum/preferences/preferences_import_test, mock_client)
	source.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_LIZARD)
	source.save_character()
	var/datum/preferences/imported = prefs_import_round_trip(source, list("languages" = list()))
	TEST_ASSERT_NOTNULL(imported, "The file should import")
	TEST_ASSERT_EQUAL(imported.languages[/datum/language/common], LANGUAGE_SPOKEN, "A character without languages should speak its species' Common")
	TEST_ASSERT_EQUAL(imported.languages[/datum/language/draconic], LANGUAGE_SPOKEN, "A character without languages should speak its species' own language")
	var/mob/living/carbon/human/consistent/character = allocate(/mob/living/carbon/human/consistent)
	imported.apply_prefs_to(character)
	TEST_ASSERT(character.get_language_holder().can_speak_language(/datum/language/common), "A character imported without languages should still speak")
