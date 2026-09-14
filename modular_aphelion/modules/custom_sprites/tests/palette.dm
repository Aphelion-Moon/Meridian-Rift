#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/unit_test/custom_sprite_account_palette/Run()
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/custom_sprite_palette]
	var/list/colors = list()
	for(var/i in 1 to 16)
		colors += rgb(i, 0, 0)
	if(!preference.is_valid(colors) || !preference.is_valid(list()))
		Fail("An account palette must allow zero through 16 swatches.", __FILE__, __LINE__)
	var/list/too_many = colors.Copy()
	too_many += "#ffffff"
	for(var/bad in list(TRUE, "#ffffff", too_many, list("#ffffff", "#FFFFFF"), list("#ffffff80"), list("#nope00"), list("#ffffff" = "forged")))
		if(!isnull(preference.deserialize(bad)))
			Fail("Malformed, duplicate or oversized account palettes must be rejected.", __FILE__, __LINE__)
	var/list/canonical = preference.deserialize(list("#ABCDEF"))
	if(canonical?[1] != "#abcdef")
		Fail("Account swatches must normalize to lowercase RGB.", __FILE__, __LINE__)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "data/custom_sprite_palette_[REF(src)].json"
	preferences.savefile.path = test_path
	if(!preferences.update_preference(preference, colors))
		Fail("A valid palette must update through the account preference API.", __FILE__, __LINE__)
	preferences.save_preferences()
	preferences.create_character_preview_view(mock_client.mob)
	preferences.switch_to_slot(2)
	if(json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != json_encode(colors))
		Fail("Custom swatches must remain shared after switching characters.", __FILE__, __LINE__)
	var/datum/json_savefile/reloaded = allocate(/datum/json_savefile, test_path)
	if(json_encode(preference.read(reloaded.get_entry(), preferences)) != json_encode(colors))
		Fail("Saved account colors must survive a new disk read.", __FILE__, __LINE__)
	var/list/character_data = reloaded.get_entry("character1")
	if(character_data?[preference.savefile_key])
		Fail("Account swatches must not be stored in character slots.", __FILE__, __LINE__)
	if(preferences.update_preference(preference, too_many) || json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != json_encode(colors))
		Fail("Rejecting the seventeenth swatch must leave the account palette intact.", __FILE__, __LINE__)
	preferences.savefile.path = null
	fdel(test_path)

#endif
