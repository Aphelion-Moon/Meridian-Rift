/datum/json_savefile/custom_sprites/counting_test
	/// Save calls observed by the persistence fixture, including failed attempts.
	var/writes = 0

/datum/json_savefile/custom_sprites/counting_test/save()
	writes++
	return ..()

/datum/json_savefile/custom_sprites/counting_test/failing
	/// Exact destination at which to simulate a failed write.
	var/fail_destination
	/// Whether the failed attempt truncates the destination.
	var/short_write = TRUE
	/// Matching write number to fail.
	var/fail_on_match = 1
	/// Number of writes observed for the selected destination.
	var/matching_writes = 0

/datum/json_savefile/custom_sprites/counting_test/failing/write_file(contents, destination)
	if(destination == fail_destination && ++matching_writes >= fail_on_match)
		if(short_write)
			rustg_file_write("{", destination)
			return null
		return "Simulated write failure"
	return ..()

/proc/custom_sprite_test_remove_sidecar(test_path)
	for(var/test_file in list(test_path, "[test_path].bak", "[test_path].new"))
		fdel(test_file)

/// Removes a test's sidecar files as the test starts, and again when the framework deletes it after any assertion.
/datum/custom_sprite_test_files
	/// Sidecar path whose primary, backup and staging files are removed.
	var/test_path

/datum/custom_sprite_test_files/New(test_path)
	src.test_path = test_path

/datum/custom_sprite_test_files/Destroy()
	custom_sprite_test_remove_sidecar(test_path)
	return ..()

/datum/unit_test/custom_sprite_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_preferences_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	preferences.create_character_preview_view(mock_client.mob)
	var/preferences_before = json_encode(preferences.savefile.get_entry())
	var/list/drawing = custom_sprite_test_drawing()
	TEST_ASSERT(!(preferences.commit_custom_style(custom_style_package("hair", null, drawing, null), preferences.default_slot) || store.writes != 1), "A changed drawing should write the sidecar once.")
	TEST_ASSERT(json_encode(preferences.savefile.get_entry()) == preferences_before, "Drawing data must not grow preferences.json or character exports.")
	preferences.commit_custom_style(custom_style_package("hair", null, drawing, null), preferences.default_slot)
	preferences.save_preferences()
	TEST_ASSERT(store.writes == 1, "Unchanged drawings and ordinary preference saves must not rewrite the sidecar.")
	preferences.switch_to_slot(2)
	preferences.load_custom_sprites()
	TEST_ASSERT(!(preferences.custom_hair || length(preferences.custom_limb_markings)), "A new slot must have a blank canvas.")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_CHEST, drawing, null), preferences.default_slot)
	// Exercise the private UI action without requiring a live browser.
	call(preferences, "remove_current_slot")()
	TEST_ASSERT(!store.get_entry("character2"), "Deleting a slot must remove its sidecar record.")
	preferences.switch_to_slot(1)
	preferences.load_custom_sprites()
	TEST_ASSERT(!(json_encode(preferences.custom_hair) != json_encode(drawing) || length(preferences.custom_limb_markings)), "Switching slots must restore only that slot's drawings.")
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	TEST_ASSERT(json_encode(reloaded.get_entry("character1")) == json_encode(store.get_entry("character1")), "A new session must recover saved drawings.")
	store.path = null
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_import_cleanup/Run()
	var/test_key = ckey("customspriteunittest[REF(src)]")
	var/test_path = "data/player_saves/c/[test_key]/custom_sprites.json"
	allocate(/datum/custom_sprite_test_files, test_path)
	TEST_ASSERT(!(fexists(test_path) || fexists("[test_path].bak") || fexists("[test_path].new") || GLOB.preferences_datums[test_key]), "Disposable import fixture already exists.")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = new(test_path)
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	preferences.commit_custom_style(custom_style_package("hair", null, custom_sprite_test_drawing(), null), preferences.default_slot)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing("2"), null), preferences.default_slot)
	GLOB.preferences_datums[test_key] = preferences
	custom_sprites_after_import(test_key)
	GLOB.preferences_datums -= test_key
	TEST_ASSERT(!(fexists(test_path) || fexists("[test_path].bak") || fexists("[test_path].new") || preferences.custom_hair || length(preferences.custom_limb_markings) || preferences.custom_sprite_savefile.path), "An imported character must not inherit old disk data or writable cached drawings.")
	preferences.load_and_save = FALSE

/datum/unit_test/custom_marking_zone_persistence/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_marking_zone_preferences_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/list/hair = custom_sprite_test_drawing("2")
	var/list/arm = custom_sprite_test_drawing("2")
	var/list/leg = custom_sprite_test_drawing()
	leg["emissive"] = custom_sprite_emissive_settings(list("1" = TRUE))
	preferences.commit_custom_style(custom_style_package("hair", null, hair, null), preferences.default_slot)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), preferences.default_slot)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_R_LEG, leg, null), preferences.default_slot)
	var/list/saved = store.get_entry("character[preferences.default_slot]")
	TEST_ASSERT(json_encode(saved?["limb_markings"]?[BODY_ZONE_L_ARM]) == json_encode(arm), "A zone drawing must be saved independently in the same character slot.")
	TEST_ASSERT(!(store.writes != 3 || preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), preferences.default_slot) || store.writes != 3), "Only a changed zone drawing should write the sidecar.")
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	TEST_ASSERT(json_encode(reloaded.get_entry("character[preferences.default_slot]")) == json_encode(saved), "A new session must recover hair and independent zone drawings.")
	preferences.custom_hair = null
	preferences.custom_limb_markings = null
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	TEST_ASSERT(!(json_encode(preferences.custom_hair) != json_encode(hair) || json_encode(preferences.custom_limb_markings?[BODY_ZONE_R_LEG]) != json_encode(leg)), "Reloading preferences must recover each drawing and its own emissive settings.")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, null, null), preferences.default_slot)
	saved = store.get_entry("character[preferences.default_slot]")
	TEST_ASSERT(!(saved?["limb_markings"]?[BODY_ZONE_L_ARM] || json_encode(saved?["limb_markings"]?[BODY_ZONE_R_LEG]) != json_encode(leg) || json_encode(preferences.custom_hair) != json_encode(hair)), "Clearing an arm must preserve hair and the leg drawing.")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_R_LEG, null, null), preferences.default_slot)
	saved = store.get_entry("character[preferences.default_slot]")
	TEST_ASSERT(!(saved?["limb_markings"] || length(preferences.custom_limb_markings)), "Clearing the final zone must omit the empty zone map.")
	store.path = null
	preferences.load_and_save = FALSE

/datum/unit_test/custom_marking_zone_validation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/list/drawing = custom_sprite_test_drawing()
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, drawing, null), preferences.default_slot)
	var/before = json_encode(preferences.custom_sprite_savefile.get_entry())
	var/list/valid = custom_style_validate_package(custom_style_package("markings", BODY_ZONE_L_ARM, null, null))
	TEST_ASSERT(!(valid["error"] || !valid["package"]), "The empty zone package must pass validation before testing invalid zones.")
	for(var/bad_zone in list("", "tail", "Left arm", 1, list(BODY_ZONE_L_ARM)))
		var/list/result = custom_style_validate_package(list("target" = "markings", "zone" = bad_zone, "drawing" = null))
		if(result["package"])
			preferences.commit_custom_style(result["package"], preferences.default_slot)
		TEST_ASSERT(!(!result["error"] || !findtext(result["error"], "body zone is invalid")), "Invalid zones must be rejected instead of clearing a drawing.")
	var/list/hair_result = custom_style_validate_package(list("target" = "hair", "zone" = BODY_ZONE_HEAD, "drawing" = drawing, "hair" = custom_style_test_hair()))
	TEST_ASSERT(!(!hair_result["error"] || !findtext(hair_result["error"], "Hair styles cannot have a body zone")), "Hair cannot be saved to a marking zone.")
	TEST_ASSERT(json_encode(preferences.custom_sprite_savefile.get_entry()) == before, "Rejected zone actions must leave all existing drawings untouched.")
	var/list/raw_zones = list(
		BODY_ZONE_L_ARM = drawing,
		BODY_ZONE_R_ARM = list("version" = 1, "palette" = list("not a color"), "dirs" = drawing["dirs"]),
		BODY_ZONE_L_LEG = "not a drawing",
		"tail" = drawing,
	)
	preferences.custom_sprite_savefile.set_entry("character[preferences.default_slot]", list("markings" = drawing, "limb_markings" = raw_zones))
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	TEST_ASSERT(!(length(preferences.custom_limb_markings) != 1 || json_encode(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != json_encode(drawing) || ("markings" in preferences.custom_sprite_slot_data())), "Loading must retain valid zones while dropping unknown and malformed zones and retired whole-body markings.")
	for(var/bad_zones in list(null, 1, "not a map", list("tail" = drawing)))
		TEST_ASSERT(!custom_limb_markings_validate(bad_zones), "Invalid or empty zone maps must sanitize to no drawings.")
	var/list/all_zones = list()
	for(var/body_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		all_zones[body_zone] = drawing
	var/list/clean = custom_limb_markings_validate(all_zones)
	TEST_ASSERT(length(clean) == 6, "Every supported body zone must survive validation.")
	clean[BODY_ZONE_HEAD]["palette"][1] = "#123456"
	TEST_ASSERT(!(clean[BODY_ZONE_CHEST]["palette"][1] == "#123456" || drawing["palette"][1] == "#123456"), "Validated zone drawings must not alias their source or each other.")

/datum/unit_test/custom_marking_zone_slots/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.create_character_preview_view(mock_client.mob)
	var/list/first = custom_sprite_test_drawing()
	var/list/second = custom_sprite_test_drawing("2")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_HEAD, first, null), preferences.default_slot)
	preferences.switch_to_slot(2)
	preferences.load_custom_sprites()
	TEST_ASSERT(!length(preferences.custom_limb_markings), "A new slot must not inherit another slot's limb drawings.")
	TEST_ASSERT(preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_HEAD, second, null), 1), "An old editor must not save into an inactive slot.")
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_HEAD, second, null), 2)
	preferences.switch_to_slot(1)
	preferences.load_custom_sprites()
	TEST_ASSERT(json_encode(preferences.custom_limb_markings?[BODY_ZONE_HEAD]) == json_encode(first), "Switching back must restore the first slot's independent drawing.")
	preferences.remove_custom_sprite_slot(2)
	TEST_ASSERT(!(preferences.custom_sprite_savefile.get_entry("character2") || json_encode(preferences.custom_limb_markings?[BODY_ZONE_HEAD]) != json_encode(first)), "Removing another slot must preserve the active slot's limb drawings.")
	preferences.remove_custom_sprite_slot(1)
	TEST_ASSERT(!(preferences.custom_sprite_savefile.get_entry("character1") || length(preferences.custom_limb_markings)), "Removing the active slot must clear its stored and cached limb drawings.")

/datum/unit_test/custom_marking_zone_sidecar_capacity/Run()
	var/test_path = "tmp/custom_marking_zone_capacity_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/list/palette = list()
	for(var/i in 1 to 63)
		palette += rgb(i, 0, 0)
	var/list/directions = list()
	for(var/direction in list("2", "1", "4", "8"))
		directions[direction] = "f[repeat_string(512, "12")]"
	var/list/drawing = list("version" = 2, "palette" = palette, "dirs" = directions)
	var/list/zones = list()
	for(var/body_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		zones[body_zone] = drawing
	var/list/wide = custom_sprite_resize_drawing(drawing, 64)
	for(var/direction in directions)
		wide["dirs"][direction] = "f[repeat_string(1024, "12")]"
	zones[CUSTOM_MARKING_ZONE_TAUR] = wide
	var/list/previous = list("hair" = custom_style_package("hair", null, drawing, null))
	for(var/zone, zone_drawing in zones)
		previous[custom_style_key("markings", zone)] = custom_style_package("markings", zone, zone_drawing, null)
	var/list/all_slots = list()
	for(var/slot in 1 to MAX_SAVE_SLOTS_SUBSCRIBER)
		all_slots["character[slot]"] = list("hair" = drawing, "limb_markings" = zones, "previous_styles" = previous)
	text2file(json_encode(all_slots), test_path)
	var/datum/json_savefile/custom_sprites/store = allocate(/datum/json_savefile/custom_sprites, test_path)
	TEST_ASSERT(!(length(store.get_entry()) != MAX_SAVE_SLOTS_SUBSCRIBER || json_encode(store.get_entry("character[MAX_SAVE_SLOTS_SUBSCRIBER]")) != json_encode(all_slots["character[MAX_SAVE_SLOTS_SUBSCRIBER]"])), "A full account must reload every drawing and its previous style, including the wide taur target.")
	custom_sprite_test_remove_sidecar(test_path)
	var/padding = "0"
	for(var/i in 1 to 24)
		padding += padding
	text2file(json_encode(list("character1" = all_slots["character1"], "padding" = padding)), test_path)
	TEST_ASSERT(!(store.load() || length(store.get_entry())), "Oversized sidecars must still be rejected and clear previously loaded entries.")
	store.path = null

/datum/unit_test/custom_sprite_sidecar_write_failures/Run()
	for(var/suffix in list(".new", ".bak", ""))
		for(var/short_write in list(TRUE, FALSE))
			var/test_path = "tmp/custom_sprite_write_failure_[REF(src)][suffix][short_write].json"
			allocate(/datum/custom_sprite_test_files, test_path)
			var/datum/json_savefile/custom_sprites/counting_test/failing/store = allocate(/datum/json_savefile/custom_sprites/counting_test/failing, test_path)
			var/list/original = list("hair" = custom_sprite_test_drawing())
			store.set_entry("character1", original)
			TEST_ASSERT(store.save(), "Could not create the disposable write-failure fixture.")
			var/original_bytes = file2text(test_path)
			var/list/replacement = list("hair" = custom_sprite_test_drawing("2"))
			store.set_entry("character1", replacement)
			store.fail_destination = "[test_path][suffix]"
			store.short_write = short_write
			TEST_ASSERT(!(store.save() || !store.dirty || !store.last_save_failed), "Partial writes and reported errors must fail without losing pending changes.")
			TEST_ASSERT(!(suffix && file2text(test_path) != original_bytes), "Staging or backup failure must not touch the primary.")
			var/datum/json_savefile/custom_sprites/recovered = allocate(/datum/json_savefile/custom_sprites, test_path)
			TEST_ASSERT(json_encode(recovered.get_entry("character1")) == json_encode(original), "A new session must recover the last good drawing after any failed write phase.")
			if(!suffix && short_write)
				// The primary is corrupt. A failed backup rewrite would destroy the only good file.
				store.fail_destination = "[test_path].bak"
			else
				store.fail_destination = null
			TEST_ASSERT(!(!store.save() || store.dirty || store.last_save_failed || file2text(test_path) != json_encode(list("character1" = replacement))), "Retry must persist the retained draft and avoid rewriting the only good backup during recovery.")
			store.path = null

/datum/unit_test/custom_sprite_sidecar_oversized_save/Run()
	var/test_path = "tmp/custom_sprite_oversized_save_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/store = allocate(/datum/json_savefile/custom_sprites, test_path)
	store.set_entry("character1", list("hair" = custom_sprite_test_drawing()))
	store.save()
	var/original = file2text(test_path)
	var/original_backup = file2text("[test_path].bak")
	var/padding = "0"
	for(var/i in 1 to 24)
		padding += padding
	store.set_entry("padding", padding)
	TEST_ASSERT(!(store.save() || !store.dirty || !store.last_save_failed || file2text(test_path) != original || file2text("[test_path].bak") != original_backup || fexists("[test_path].new")), "An oversized serialized payload must be refused before staging, preserving both saved copies and dirty state.")
	store.remove_entry("padding")
	TEST_ASSERT(!(!store.save() || store.dirty || store.last_save_failed || file2text(test_path) != original), "Removing the oversized entry must allow the retained drawing to save again.")
	store.path = null

/datum/unit_test/custom_sprite_sidecar_recovery_and_deletion/Run()
	var/test_path = "tmp/custom_sprite_recovery_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/failing/store = allocate(/datum/json_savefile/custom_sprites/counting_test/failing, test_path)
	store.set_entry("character1", list("hair" = custom_sprite_test_drawing()))
	store.set_entry("character2", list("markings" = custom_sprite_test_drawing("2")))
	store.save()
	store.remove_entry("character2")
	store.fail_destination = "[test_path].bak"
	store.fail_on_match = 2
	TEST_ASSERT(!(store.save() || !store.dirty || !store.last_save_failed), "Failed backup scrubbing must remain dirty even after the new primary was written.")
	var/list/primary = json_decode(file2text(test_path))
	TEST_ASSERT(!(primary["character2"] || !primary["character1"]), "Backup scrub failure must preserve the verified primary and its slot deletion.")
	store.fail_destination = null
	TEST_ASSERT(store.save(), "A failed deletion scrub must be retryable.")
	var/list/backup = json_decode(file2text("[test_path].bak"))
	TEST_ASSERT(!(backup["character2"] || !backup["character1"]), "Successful slot deletion must also remove the old identity from the recovery copy.")
	fdel(test_path)
	var/datum/json_savefile/custom_sprites/recovered = allocate(/datum/json_savefile/custom_sprites, test_path)
	TEST_ASSERT(!(!recovered.dirty || recovered.get_entry("character2") || !recovered.get_entry("character1") || !recovered.save()), "A missing primary must load its backup and remain dirty until the primary is repaired.")
	store.path = null
	recovered.path = null

/datum/unit_test/custom_sprite_failed_save_retry/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_retry_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/failing/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/list/hair = custom_sprite_test_drawing()
	var/list/arm = custom_sprite_test_drawing("2")
	preferences.commit_custom_style(custom_style_package("hair", null, hair, null), preferences.default_slot)
	var/before_disk = file2text(test_path)
	var/before_sidecar = json_encode(store.get_entry())
	store.fail_destination = "[test_path].new"
	TEST_ASSERT(!(!preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), preferences.default_slot) || !store.dirty || preferences.custom_limb_markings?[BODY_ZONE_L_ARM]), "A failed commit must report failure and restore the previous in-memory drawing.")
	TEST_ASSERT(!(file2text(test_path) != before_disk || json_encode(store.get_entry()) != before_sidecar), "A failed commit must preserve the saved file and restore the sidecar tree.")
	store.fail_destination = null
	TEST_ASSERT(!(preferences.commit_custom_style(custom_style_package("hair", null, hair, null), preferences.default_slot) || store.dirty || store.last_save_failed), "Saving an unchanged other target must clear the rolled-back sidecar's pending retry.")
	var/list/disk = json_decode(file2text(test_path))
	TEST_ASSERT(!(disk["character1"]["limb_markings"] || json_encode(disk["character1"]["hair"]) != json_encode(hair)), "A retry from another target must preserve saved hair without publishing the rejected limb draft.")
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), preferences.default_slot), "Submitting the limb draft again must succeed after disk writes recover.")
	disk = json_decode(file2text(test_path))
	TEST_ASSERT(json_encode(disk["character1"]["limb_markings"][BODY_ZONE_L_ARM]) == json_encode(arm), "A successful retry must publish the submitted limb drawing to disk.")
	var/writes = store.writes
	TEST_ASSERT(!(preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), preferences.default_slot) || store.writes != writes), "An unchanged, clean save must succeed without writing again.")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
	editor.workspace.clear_direction("2")
	store.fail_destination = "[test_path].new"
	TEST_ASSERT(!(editor.save_drawing() || editor.save_revision || !editor.save_error), "A failed editor save must report an error without acknowledging a new revision.")
	editor.finish(TRUE)
	TEST_ASSERT(!(QDELETED(editor) || editor.closing || !preferences.custom_sprite_editors?["hair"]), "Save and close must retain the editor and workspace after a disk failure.")
	store.fail_destination = null
	TEST_ASSERT(!(!editor.save_drawing() || editor.save_revision != 1 || editor.save_error), "Successful retry must acknowledge the saved revision and clear the error.")
	editor.finish(TRUE)
	TEST_ASSERT(!preferences.custom_sprite_editors?["hair"], "After a successful retry, closing must release the editor.")
	store.path = null
	preferences.load_and_save = FALSE
