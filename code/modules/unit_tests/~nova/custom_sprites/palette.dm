/datum/unit_test/custom_sprite_account_palette/Run()
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/custom_sprite_palette]
	var/list/colors = list()
	for(var/i in 1 to 16)
		colors += rgb(i, 0, 0)
	TEST_ASSERT(!(!preference.is_valid(colors) || !preference.is_valid(list())), "An account palette must allow zero through 16 swatches.")
	var/list/too_many = colors.Copy()
	too_many += "#ffffff"
	for(var/bad in list(TRUE, "#ffffff", too_many, list("#ffffff", "#FFFFFF"), list("#ffffff80"), list("#nope00"), list("#ffffff" = "forged")))
		TEST_ASSERT(isnull(preference.deserialize(bad)), "Malformed, duplicate or oversized account palettes must be rejected.")
	var/list/canonical = preference.deserialize(list("#ABCDEF"))
	TEST_ASSERT(canonical?[1] == "#abcdef", "Account swatches must normalize to lowercase RGB.")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "data/custom_sprite_palette_[REF(src)].json"
	preferences.savefile.path = test_path
	TEST_ASSERT(preferences.update_preference(preference, colors), "A valid palette must update through the account preference API.")
	preferences.save_preferences()
	preferences.create_character_preview_view(mock_client.mob)
	preferences.switch_to_slot(2)
	TEST_ASSERT(json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) == json_encode(colors), "Custom swatches must remain shared after switching characters.")
	var/datum/json_savefile/reloaded = allocate(/datum/json_savefile, test_path)
	TEST_ASSERT(json_encode(preference.read(reloaded.get_entry(), preferences)) == json_encode(colors), "Saved account colors must survive a new disk read.")
	var/list/character_data = reloaded.get_entry("character1")
	TEST_ASSERT(!character_data?[preference.savefile_key], "Account swatches must not be stored in character slots.")
	TEST_ASSERT(!(preferences.update_preference(preference, too_many) || json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != json_encode(colors)), "Rejecting the seventeenth swatch must leave the account palette intact.")
	preferences.savefile.path = null
	fdel(test_path)
