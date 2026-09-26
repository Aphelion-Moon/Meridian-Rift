/proc/custom_style_test_folder(datum/source)
	return "tmp/custom_style_[ckey(REF(source))]_[rand(1, 1e6)]/"

/proc/custom_style_test_cleanup(folder)
	for(var/test_file in list("preferences.json", "custom_sprites.json", "custom_sprites.json.bak", "custom_sprites.json.new"))
		fdel("[folder][test_file]")

/// A sidecar store whose last verified contents match the file written for a save test.
/proc/custom_style_test_sidecar(folder, contents)
	rustg_file_write(contents, "[folder]custom_sprites.json")
	return new /datum/json_savefile/custom_sprites("[folder]custom_sprites.json")

/datum/unit_test/custom_style_previous_rotation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.load_custom_sprites()
	var/list/first = custom_sprite_test_drawing("1")
	var/list/second = custom_sprite_test_drawing("2")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, first, null), preferences.default_slot)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_R_ARM, second, null), preferences.default_slot)
	var/list/package = custom_style_package("markings", BODY_ZONE_L_ARM, second, null)
	TEST_ASSERT(!(preferences.commit_custom_style(package, preferences.default_slot, rotate = FALSE) || preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)), "Ordinary saves must not rotate the previous style.")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, first, null), preferences.default_slot)
	TEST_ASSERT(!preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE), "A rotating save must succeed.")
	var/list/previous = preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)
	TEST_ASSERT(!(custom_sprite_hash(previous?["drawing"]) != custom_sprite_hash(first) || custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_L_ARM]) != custom_sprite_hash(second)), "Rotation must keep exactly one previous style for the zone.")
	TEST_ASSERT(!(custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_R_ARM]) != custom_sprite_hash(second) || preferences.custom_style_previous_package("markings", BODY_ZONE_R_ARM)), "Rotating one zone must not affect other zones.")
	TEST_ASSERT(!(preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE) || custom_sprite_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)?["drawing"]) != custom_sprite_hash(first)), "An unchanged rotating save must not overwrite the real previous style.")
	TEST_ASSERT(!(preferences.commit_custom_style(previous, preferences.default_slot, rotate = TRUE) || custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_L_ARM]) != custom_sprite_hash(first) || custom_sprite_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)?["drawing"]) != custom_sprite_hash(second)), "Restoring the previous style must swap current and previous.")
	var/list/empty = custom_style_package("markings", BODY_ZONE_HEAD, null, null)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_HEAD, first, null), preferences.default_slot)
	preferences.commit_custom_style(empty, preferences.default_slot, rotate = TRUE)
	var/list/stored_empty = preferences.custom_style_previous_package("markings", BODY_ZONE_HEAD)
	TEST_ASSERT(!(preferences.custom_limb_markings?[BODY_ZONE_HEAD] || custom_sprite_hash(stored_empty?["drawing"]) != custom_sprite_hash(first)), "Saving empty art must clear the zone and keep the old drawing as previous.")
	preferences.commit_custom_style(stored_empty, preferences.default_slot, rotate = TRUE)
	var/list/previous_empty = preferences.custom_style_previous_package("markings", BODY_ZONE_HEAD)
	TEST_ASSERT(!(!previous_empty || !isnull(previous_empty["drawing"])), "An empty style must be kept as an explicit previous style.")
	var/list/reloaded = custom_style_previous_validate(preferences.custom_sprite_savefile.get_entry("character[preferences.default_slot]")["previous_styles"])
	TEST_ASSERT(length(reloaded) == 2, "Previous styles must survive validation when the sidecar is reloaded.")
	TEST_ASSERT(preferences.commit_custom_style(package, preferences.default_slot + 1), "A save bound to another slot must be rejected.")
	preferences.remove_custom_sprite_slot(preferences.default_slot)
	TEST_ASSERT(!(preferences.custom_style_previous || preferences.custom_sprite_savefile.get_entry("character[preferences.default_slot]")), "Deleting a slot must remove its previous styles.")

/datum/unit_test/custom_style_base_look_save/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/folder = custom_style_test_folder(src)
	preferences.path = "[folder]preferences.json"
	preferences.load_and_save = TRUE
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = custom_style_test_sidecar(folder, "{}")
	preferences.custom_sprite_slot = null
	preferences.save_character()
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.savefile.path = preferences.path
	preferences.savefile.save()
	var/list/hair = custom_style_test_hair()
	var/list/drawing = custom_sprite_test_drawing()
	var/list/package = custom_style_package("hair", null, drawing, hair)
	var/error = preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE, reject_pending_hair = TRUE)
	TEST_ASSERT(!error, "A complete hair save failed: [error]")
	var/list/disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	var/list/disk_sprites = json_decode(rustg_file_read("[folder]custom_sprites.json"))["character[preferences.default_slot]"]
	TEST_ASSERT(!(disk_preferences?["hairstyle_name"] != "Short Hair" || disk_preferences?["hair_color"] != "#583820" || custom_sprite_hash(disk_sprites?["hair"]) != custom_sprite_hash(custom_sprite_validate(drawing))), "A complete hair save must write the base look and drawing to both files.")
	TEST_ASSERT(disk_sprites?["previous_styles"]?["hair"]?["hair"]?["style"] == "Bald", "The previous hair package must include the old base haircut.")
	TEST_ASSERT(!(preferences.read_preference(/datum/preference/choiced/hairstyle) != "Short Hair" || json_encode(preferences.custom_style_hair_context()) != json_encode(hair)), "Saved hair must be published to in-memory preferences after verification.")
	TEST_ASSERT(!preferences.custom_sprite_savefile.dirty, "A complete hair save must leave the sidecar clean.")
	preferences.update_preference(GLOB.preference_entries[/datum/preference/color/hair_color], "#123456")
	TEST_ASSERT(preferences.commit_custom_style(custom_style_package("hair", null, null, custom_style_test_hair("Bald")), preferences.default_slot, rotate = TRUE, reject_pending_hair = TRUE), "Unsaved hair edits in character setup must reject a salon save.")
	preferences.load_and_save = FALSE
	custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_native_markings_persistence/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/folder = custom_style_test_folder(src)
	preferences.path = "[folder]preferences.json"
	preferences.load_and_save = TRUE
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = custom_style_test_sidecar(folder, "{}")
	preferences.custom_sprite_slot = null
	var/zone = BODY_ZONE_L_ARM
	var/other_zone = BODY_ZONE_R_ARM
	var/list/entries = custom_style_test_markings(zone)
	var/list/old_entries = list(deep_copy_list(entries[1]))
	preferences.body_markings = list("[zone]" = custom_style_marking_data(old_entries), "[other_zone]" = custom_style_marking_data(old_entries))
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.save_character()
	preferences.savefile.path = preferences.path
	preferences.savefile.save()
	var/list/old_drawing = custom_sprite_test_drawing("1")
	// This identity round trip uses current metadata; legacy drawings gain explicit emission on reload.
	old_drawing["emissive"] = custom_sprite_emissive_settings(FALSE)
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("markings", zone, old_drawing, null), preferences.default_slot), "The initial native marking fixture must save its drawing.")
	var/list/original = preferences.custom_style_saved_package("markings", zone)
	var/list/package = custom_style_package("markings", zone, custom_sprite_test_drawing("2"), null, entries)
	var/old_preferences = rustg_file_read(preferences.path)
	var/old_sidecar = rustg_file_read("[folder]custom_sprites.json")
	var/old_memory = json_encode(preferences.body_markings)
	var/verified_sidecar = preferences.custom_sprite_savefile.last_good_json
	// Nothing may be written without the sidecar's verified recovery snapshot.
	preferences.custom_sprite_savefile.last_good_json = null
	var/error = preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	preferences.custom_sprite_savefile.last_good_json = verified_sidecar
	TEST_ASSERT(!(!error || rustg_file_read(preferences.path) != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sidecar), "A rejected native marking save must preserve both saved files.")
	TEST_ASSERT(!(json_encode(preferences.body_markings) != old_memory || custom_style_package_hash(preferences.custom_style_saved_package("markings", zone)) != custom_style_package_hash(original) || preferences.custom_style_previous_package("markings", zone)), "A failed native marking save must preserve in-memory native marks, drawing and previous style.")
	// An edit on another limb must survive the save while only this limb is replaced.
	preferences.body_markings[other_zone][old_entries[1]["name"]][1] = "#654321"
	var/other_before = json_encode(preferences.body_markings[other_zone])
	error = preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	TEST_ASSERT(!error, "A complete native marking save failed: [error]")
	var/list/disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	var/list/disk_sprites = json_decode(rustg_file_read("[folder]custom_sprites.json"))["character[preferences.default_slot]"]
	TEST_ASSERT(!(json_encode(custom_style_marking_entries(disk_preferences?["body_markings"]?[zone])) != json_encode(entries) || custom_sprite_hash(disk_sprites?["limb_markings"]?[zone]) != custom_sprite_hash(custom_sprite_validate(package["drawing"]))), "Native marking saves must persist ordered presets and the selected drawing.")
	TEST_ASSERT(!(json_encode(custom_style_marking_entries(preferences.body_markings[zone])) != json_encode(entries) || json_encode(preferences.body_markings[other_zone]) != other_before || json_encode(disk_preferences?["body_markings"]?[other_zone]) != other_before), "Native marking saves must publish the committed limb and preserve pending edits on other limbs.")
	var/list/previous = preferences.custom_style_previous_package("markings", zone)
	TEST_ASSERT(custom_style_package_hash(previous) == custom_style_package_hash(original), "Previous-style rotation must retain the original native marking context and drawing.")
	var/list/reloaded = custom_style_previous_validate(disk_sprites?["previous_styles"])
	TEST_ASSERT(custom_style_package_hash(reloaded?[custom_style_key("markings", zone)]) == custom_style_package_hash(original), "Native previous styles must survive strict sidecar reload validation.")
	TEST_ASSERT(!preferences.custom_sprite_savefile.dirty, "A successful native marking save must leave the sidecar verified.")
	// Save-character normally aliases these lists, so an in-place edit must still collide with disk.
	preferences.save_character()
	preferences.body_markings[zone][entries[1]["name"]][1] = "#fedcba"
	var/pending_memory = json_encode(preferences.body_markings)
	old_preferences = rustg_file_read(preferences.path)
	old_sidecar = rustg_file_read("[folder]custom_sprites.json")
	error = preferences.commit_custom_style(original, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	TEST_ASSERT(!(!findtext(error, "unsaved base marking changes") || json_encode(preferences.body_markings) != pending_memory || rustg_file_read(preferences.path) != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sidecar), "Recipient saves must reject aliased pending changes on the target limb without altering either file.")
	preferences.body_markings[zone][entries[1]["name"]][1] = entries[1]["color"]
	var/list/clear = custom_style_package("markings", zone, null, null, list())
	error = preferences.commit_custom_style(clear, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	TEST_ASSERT(!(error || length(preferences.body_markings[zone]) || length(disk_preferences?["body_markings"]?[zone]) || preferences.custom_limb_markings?[zone]), "Explicit empty native markings must clear the saved limb and its drawing: [error]")
	previous = preferences.custom_style_previous_package("markings", zone)
	TEST_ASSERT(!(custom_style_package_hash(previous) != custom_style_package_hash(package) || preferences.commit_custom_style(previous, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)), "Restoring the previous style must recover both native markings and its drawing.")
	previous = preferences.custom_style_previous_package("markings", zone)
	TEST_ASSERT(custom_style_package_hash(previous) == custom_style_package_hash(clear), "Restoration must rotate the explicit native Clear package as the previous style.")
	error = preferences.commit_custom_style(custom_style_package("markings", zone, old_drawing, null), preferences.default_slot, rotate = TRUE)
	TEST_ASSERT(!(error || json_encode(custom_style_marking_entries(preferences.body_markings[zone])) != json_encode(entries)), "A legacy package without native marking context must preserve saved native markings.")
	preferences.load_and_save = FALSE
	custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_hair_eligibility/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], FALSE)
	var/list/hair = custom_style_test_hair()
	for(var/window in list(PREFERENCE_TAB_CHARACTER_PREFERENCES, PREFERENCE_TAB_GAME_PREFERENCES))
		preferences.current_window = window
		TEST_ASSERT(!preferences.custom_style_hair_problem(hair), "An eligible human haircut must remain usable on preferences tab [window].")
		hair["opacity"] = 128
		TEST_ASSERT(preferences.custom_style_hair_problem(hair), "A human without mismatched parts must not gain hair opacity on tab [window].")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], TRUE)
		TEST_ASSERT(!preferences.custom_style_hair_problem(hair), "Enabled mismatched hair opacity must remain usable on preferences tab [window].")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
		TEST_ASSERT(preferences.custom_style_hair_problem(hair), "Mismatched hair opacity still requires its feature toggle on tab [window].")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
		hair["opacity"] = null
		hair["emissive"] = TRUE
		TEST_ASSERT(preferences.custom_style_hair_problem(hair), "Changing tabs must not bypass the master emissive permission.")
		hair["emissive"] = FALSE
	preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	var/error = preferences.commit_custom_style(custom_style_package("hair", null, null, hair), preferences.default_slot)
	TEST_ASSERT(!(error || preferences.read_preference(/datum/preference/choiced/hairstyle) != "Short Hair"), "The production save must publish an eligible haircut while game preferences are selected: [error]")

/datum/unit_test/custom_style_pending_hair_opacity/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
	preferences.load_custom_sprites()
	var/list/hair = custom_style_test_hair()
	TEST_ASSERT(preferences.update_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], TRUE), "The pending opacity-toggle fixture must be accepted by character setup.")
	var/before_hair = json_encode(preferences.custom_style_hair_context())
	var/before_preferences = json_encode(preferences.savefile.get_entry())
	var/before_sidecar = json_encode(preferences.custom_sprite_savefile.get_entry())
	var/error = preferences.commit_custom_style(custom_style_package("hair", null, custom_sprite_test_drawing(), hair), preferences.default_slot, rotate = TRUE, reject_pending_hair = TRUE)
	TEST_ASSERT(!(!error || !findtext(error, "unsaved hair changes")), "A pending hair opacity toggle must reject a salon save as an unsaved hair conflict.")
	TEST_ASSERT(!(json_encode(preferences.savefile.get_entry()) != before_preferences || json_encode(preferences.custom_sprite_savefile.get_entry()) != before_sidecar || json_encode(preferences.custom_style_hair_context()) != before_hair || !(/datum/preference/toggle/mutant_toggle/hair_opacity in preferences.recently_updated_keys)), "Rejecting a pending opacity toggle must preserve the saved package and pending character edits.")

/datum/unit_test/custom_sprite_commit_regions/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_commit_regions_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/list/leg = custom_sprite_test_drawing()
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_LEG, leg, null), preferences.default_slot), "The fixture leg must save.")
	var/writes = store.writes
	var/list/arm = custom_sprite_test_drawing("2")
	var/list/head = custom_sprite_test_drawing()
	var/error = preferences.commit_custom_styles(list(
		custom_style_package("markings", BODY_ZONE_L_ARM, arm, null),
		custom_style_package("markings", BODY_ZONE_HEAD, head, null),
		custom_style_package("markings", BODY_ZONE_L_LEG, leg, null),
	), preferences.default_slot, list(custom_style_key("markings", BODY_ZONE_L_ARM)))
	TEST_ASSERT(!error, "Saving several regions failed: [error]")
	TEST_ASSERT(store.writes == writes + 1, "Several regions must be written in one sidecar write.")
	TEST_ASSERT(!(json_encode(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != json_encode(custom_sprite_validate(arm)) || json_encode(preferences.custom_limb_markings?[BODY_ZONE_HEAD]) != json_encode(custom_sprite_validate(head))), "Every changed region must be saved.")
	TEST_ASSERT(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM), "Listed keys rotate their previous style.")
	TEST_ASSERT(!(preferences.custom_style_previous_package("markings", BODY_ZONE_HEAD) || preferences.custom_style_previous_package("markings", BODY_ZONE_L_LEG)), "Unlisted and identical regions must not rotate.")
	writes = store.writes
	TEST_ASSERT(!preferences.commit_custom_styles(list(custom_style_package("markings", BODY_ZONE_L_LEG, leg, null)), preferences.default_slot, null), "Identical packages save as a no-op.")
	TEST_ASSERT(store.writes == writes, "Identical packages must not write.")
	store.path = null
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_commit_regions_rollback/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_commit_rollback_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/failing/store = new(test_path)
	store.fail_destination = test_path
	store.short_write = FALSE
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/error = preferences.commit_custom_styles(list(
		custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing(), null),
		custom_style_package("markings", BODY_ZONE_HEAD, custom_sprite_test_drawing("2"), null),
	), preferences.default_slot, list(custom_style_key("markings", BODY_ZONE_L_ARM)))
	TEST_ASSERT(error, "A failed sidecar write must be reported.")
	TEST_ASSERT(!(length(preferences.custom_limb_markings) || preferences.custom_style_previous), "A failed write must roll back every region and every rotation.")
	store.path = null
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_commit_regions_markings/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.load_custom_sprites()
	var/marking = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM][1]
	var/list/markings = list(list("name" = marking, "color" = "#123456", "emissive" = FALSE))
	var/error = preferences.commit_custom_styles(list(
		custom_style_package("markings", BODY_ZONE_L_ARM, null, null, markings),
		custom_style_package("markings", BODY_ZONE_HEAD, custom_sprite_test_drawing(), null),
	), preferences.default_slot, null)
	TEST_ASSERT(!error, "Saving a base marking with another region's drawing failed: [error]")
	TEST_ASSERT(preferences.body_markings?[BODY_ZONE_L_ARM]?[marking], "The changed region's base markings must be published.")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_L_ARM], "A base-marking-only region must not gain a drawing.")
