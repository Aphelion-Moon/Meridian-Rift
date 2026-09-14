#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/json_savefile/custom_sprites/counting_test
	var/writes = 0

/datum/json_savefile/custom_sprites/counting_test/save()
	writes++
	return ..()

/datum/unit_test/custom_sprite_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_preferences_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	preferences.create_character_preview_view(mock_client.mob)
	var/preferences_before = json_encode(preferences.savefile.get_entry())
	var/list/drawing = custom_sprite_test_drawing()
	if(!preferences.save_custom_sprite("hair", drawing) || store.writes != 1)
		Fail("A changed drawing should write the sidecar once.", __FILE__, __LINE__)
	if(json_encode(preferences.savefile.get_entry()) != preferences_before)
		Fail("Drawing data must not grow preferences.json or character exports.", __FILE__, __LINE__)
	preferences.save_custom_sprite("hair", drawing)
	preferences.save_preferences()
	if(store.writes != 1)
		Fail("Unchanged drawings and ordinary preference saves must not rewrite the sidecar.", __FILE__, __LINE__)
	preferences.switch_to_slot(2)
	preferences.load_custom_sprites()
	if(preferences.custom_hair || preferences.custom_markings)
		Fail("A new slot must have a blank canvas.", __FILE__, __LINE__)
	preferences.save_custom_sprite("markings", drawing)
	// Exercise the private UI action without requiring a live browser.
	call(preferences, "remove_current_slot")()
	if(store.get_entry("character2"))
		Fail("Deleting a slot must remove its sidecar record.", __FILE__, __LINE__)
	preferences.switch_to_slot(1)
	preferences.load_custom_sprites()
	if(json_encode(preferences.custom_hair) != json_encode(drawing) || preferences.custom_markings)
		Fail("Switching slots must restore only that slot's drawings.", __FILE__, __LINE__)
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	if(json_encode(reloaded.get_entry("character1")) != json_encode(store.get_entry("character1")))
		Fail("A new session must recover saved drawings.", __FILE__, __LINE__)
	store.path = null
	fdel(test_path)
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_import_cleanup/Run()
	var/test_key = ckey("customspriteunittest[REF(src)]")
	var/test_path = "data/player_saves/c/[test_key]/custom_sprites.json"
	if(fexists(test_path) || GLOB.preferences_datums[test_key])
		return Fail("Disposable import fixture already exists.", __FILE__, __LINE__)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = new(test_path)
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	preferences.save_custom_sprite("hair", custom_sprite_test_drawing())
	GLOB.preferences_datums[test_key] = preferences
	custom_sprites_after_import(test_key)
	GLOB.preferences_datums -= test_key
	if(fexists(test_path) || preferences.custom_hair || preferences.custom_markings || preferences.custom_sprite_savefile.path)
		Fail("An imported character must not inherit old disk data or writable cached drawings.", __FILE__, __LINE__)
	preferences.load_and_save = FALSE
	fdel(test_path)

#endif
