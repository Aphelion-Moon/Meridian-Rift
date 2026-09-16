#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

#define CUSTOM_STYLE_TEST_JOURNAL "custom_style_transaction.json"

/datum/custom_style_transaction/crash_test
	/// Checkpoint at which to leave files as though the process stopped.
	var/crash_phase

/datum/custom_style_transaction/crash_test/checkpoint(phase)
	return phase != crash_phase

/datum/custom_style_transaction/failing_test
	/// Destination suffix selected for write-failure injection.
	var/fail_suffix
	/// Matching write number to fail, including the second journal write.
	var/fail_on_match = 1
	/// Number of writes observed with the selected suffix.
	var/matching_writes = 0
	/// Whether failure writes truncated contents before returning.
	var/short_write = FALSE
	/// Whether the injected short write reports an error or relies on readback detection.
	var/report_error = TRUE

/datum/custom_style_transaction/failing_test/write_file(text, destination)
	if(fail_suffix && findtext(destination, fail_suffix, -length(fail_suffix)) && ++matching_writes == fail_on_match)
		if(short_write)
			rustg_file_write("{\"format\":", destination)
		return report_error ? "Simulated write failure" : null
	return ..()

/proc/custom_style_test_folder(datum/source)
	return "tmp/custom_style_[ckey(REF(source))]_[rand(1, 1e6)]/"

/proc/custom_style_test_cleanup(folder)
	for(var/test_file in list("[folder]preferences.json", "[folder]custom_sprites.json", "[folder]custom_sprites.json.bak") + custom_style_transaction_files(folder))
		fdel(test_file)
	GLOB.custom_style_blocked_folders -= folder

/proc/custom_style_test_remaining(folder)
	for(var/test_file in custom_style_transaction_files(folder))
		if(fexists(test_file))
			return test_file
	return null

/// A sidecar store whose last verified contents match the file written for a transaction test.
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
	if(preferences.commit_custom_style(package, preferences.default_slot, rotate = FALSE) || preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM))
		Fail("Ordinary saves must not rotate the previous style.", __FILE__, __LINE__)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_L_ARM, first, null), preferences.default_slot)
	if(preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE))
		Fail("A rotating save must succeed.", __FILE__, __LINE__)
	var/list/previous = preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)
	if(custom_sprite_hash(previous?["drawing"]) != custom_sprite_hash(first) || custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_L_ARM]) != custom_sprite_hash(second))
		Fail("Rotation must keep exactly one previous style for the zone.", __FILE__, __LINE__)
	if(custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_R_ARM]) != custom_sprite_hash(second) || preferences.custom_style_previous_package("markings", BODY_ZONE_R_ARM) || preferences.custom_markings)
		Fail("Rotating one zone must not affect other zones or whole-body markings.", __FILE__, __LINE__)
	if(preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE) || custom_sprite_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)?["drawing"]) != custom_sprite_hash(first))
		Fail("An unchanged rotating save must not overwrite the real previous style.", __FILE__, __LINE__)
	if(preferences.commit_custom_style(previous, preferences.default_slot, rotate = TRUE) || custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_L_ARM]) != custom_sprite_hash(first) || custom_sprite_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)?["drawing"]) != custom_sprite_hash(second))
		Fail("Restoring the previous style must swap current and previous.", __FILE__, __LINE__)
	var/list/empty = custom_style_package("markings", BODY_ZONE_HEAD, null, null)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_HEAD, first, null), preferences.default_slot)
	preferences.commit_custom_style(empty, preferences.default_slot, rotate = TRUE)
	var/list/stored_empty = preferences.custom_style_previous_package("markings", BODY_ZONE_HEAD)
	if(preferences.custom_limb_markings?[BODY_ZONE_HEAD] || custom_sprite_hash(stored_empty?["drawing"]) != custom_sprite_hash(first))
		Fail("Saving empty art must clear the zone and keep the old drawing as previous.", __FILE__, __LINE__)
	preferences.commit_custom_style(stored_empty, preferences.default_slot, rotate = TRUE)
	var/list/previous_empty = preferences.custom_style_previous_package("markings", BODY_ZONE_HEAD)
	if(!previous_empty || !isnull(previous_empty["drawing"]))
		Fail("An empty style must be kept as an explicit previous style.", __FILE__, __LINE__)
	var/list/reloaded = custom_style_previous_validate(preferences.custom_sprite_savefile.get_entry("character[preferences.default_slot]")["previous_styles"])
	if(length(reloaded) != 2)
		Fail("Previous styles must survive validation when the sidecar is reloaded.", __FILE__, __LINE__)
	if(!preferences.commit_custom_style(package, preferences.default_slot + 1))
		Fail("A save bound to another slot must be rejected.", __FILE__, __LINE__)
	preferences.remove_custom_sprite_slot(preferences.default_slot)
	if(preferences.custom_style_previous || preferences.custom_sprite_savefile.get_entry("character[preferences.default_slot]"))
		Fail("Deleting a slot must remove its previous styles.", __FILE__, __LINE__)

/datum/unit_test/custom_style_transaction_success/Run()
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
	if(error)
		Fail("A complete hair save failed: [error]", __FILE__, __LINE__)
	var/list/disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	var/list/disk_sprites = json_decode(rustg_file_read("[folder]custom_sprites.json"))["character[preferences.default_slot]"]
	if(disk_preferences?["hairstyle_name"] != "Short Hair" || disk_preferences?["hair_color"] != "#583820" || custom_sprite_hash(disk_sprites?["hair"]) != custom_sprite_hash(custom_sprite_validate(drawing)))
		Fail("A complete hair save must write the base look and drawing to both files.", __FILE__, __LINE__)
	if(disk_sprites?["previous_styles"]?["hair"]?["hair"]?["style"] != "Bald")
		Fail("The previous hair package must include the old base haircut.", __FILE__, __LINE__)
	if(preferences.read_preference(/datum/preference/choiced/hairstyle) != "Short Hair" || json_encode(preferences.custom_style_hair_context()) != json_encode(hair))
		Fail("Saved hair must be published to in-memory preferences after verification.", __FILE__, __LINE__)
	if(custom_style_test_remaining(folder) || preferences.custom_sprite_savefile.dirty)
		Fail("A committed transaction must clean up and leave the sidecar clean.", __FILE__, __LINE__)
	preferences.update_preference(GLOB.preference_entries[/datum/preference/color/hair_color], "#123456")
	if(!preferences.commit_custom_style(custom_style_package("hair", null, null, custom_style_test_hair("Bald")), preferences.default_slot, rotate = TRUE, reject_pending_hair = TRUE))
		Fail("Unsaved hair edits in character setup must reject a salon save.", __FILE__, __LINE__)
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
	if(preferences.commit_custom_style(custom_style_package("markings", zone, old_drawing, null), preferences.default_slot))
		Fail("The initial native marking fixture must save its drawing.", __FILE__, __LINE__)
	var/list/original = preferences.custom_style_saved_package("markings", zone)
	var/list/package = custom_style_package("markings", zone, custom_sprite_test_drawing("2"), null, entries)
	var/old_preferences = rustg_file_read(preferences.path)
	var/old_sidecar = rustg_file_read("[folder]custom_sprites.json")
	var/old_memory = json_encode(preferences.body_markings)
	var/verified_sidecar = preferences.custom_sprite_savefile.last_good_json
	// A transaction cannot safely replace either file without the sidecar's verified recovery snapshot.
	preferences.custom_sprite_savefile.last_good_json = null
	var/error = preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	preferences.custom_sprite_savefile.last_good_json = verified_sidecar
	if(!error || rustg_file_read(preferences.path) != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sidecar)
		Fail("A rejected native marking transaction must preserve both saved files.", __FILE__, __LINE__)
	if(json_encode(preferences.body_markings) != old_memory || custom_style_package_hash(preferences.custom_style_saved_package("markings", zone)) != custom_style_package_hash(original) || preferences.custom_style_previous_package("markings", zone))
		Fail("A failed native marking save must preserve in-memory native marks, drawing and previous style.", __FILE__, __LINE__)
	// An edit on another limb must survive the transaction while only this limb is replaced.
	preferences.body_markings[other_zone][old_entries[1]["name"]][1] = "#654321"
	var/other_before = json_encode(preferences.body_markings[other_zone])
	error = preferences.commit_custom_style(package, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	if(error)
		Fail("A complete native marking save failed: [error]", __FILE__, __LINE__)
	var/list/disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	var/list/disk_sprites = json_decode(rustg_file_read("[folder]custom_sprites.json"))["character[preferences.default_slot]"]
	if(json_encode(custom_style_marking_entries(disk_preferences?["body_markings"]?[zone])) != json_encode(entries) || custom_sprite_hash(disk_sprites?["limb_markings"]?[zone]) != custom_sprite_hash(custom_sprite_validate(package["drawing"])))
		Fail("Native marking saves must atomically persist ordered presets and the selected drawing.", __FILE__, __LINE__)
	if(json_encode(custom_style_marking_entries(preferences.body_markings[zone])) != json_encode(entries) || json_encode(preferences.body_markings[other_zone]) != other_before || json_encode(disk_preferences?["body_markings"]?[other_zone]) != other_before)
		Fail("Native marking saves must publish the committed limb and preserve pending edits on other limbs.", __FILE__, __LINE__)
	var/list/previous = preferences.custom_style_previous_package("markings", zone)
	if(custom_style_package_hash(previous) != custom_style_package_hash(original))
		Fail("Previous-style rotation must retain the original native marking context and drawing.", __FILE__, __LINE__)
	var/list/reloaded = custom_style_previous_validate(disk_sprites?["previous_styles"])
	if(custom_style_package_hash(reloaded?[custom_style_key("markings", zone)]) != custom_style_package_hash(original))
		Fail("Native previous styles must survive strict sidecar reload validation.", __FILE__, __LINE__)
	if(custom_style_test_remaining(folder) || preferences.custom_sprite_savefile.dirty)
		Fail("A successful native transaction must clean up and leave the sidecar verified.", __FILE__, __LINE__)
	// Save-character normally aliases these lists, so an in-place edit must still collide with disk.
	preferences.save_character()
	preferences.body_markings[zone][entries[1]["name"]][1] = "#fedcba"
	var/pending_memory = json_encode(preferences.body_markings)
	old_preferences = rustg_file_read(preferences.path)
	old_sidecar = rustg_file_read("[folder]custom_sprites.json")
	error = preferences.commit_custom_style(original, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	if(!findtext(error, "unsaved base marking changes") || json_encode(preferences.body_markings) != pending_memory || rustg_file_read(preferences.path) != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sidecar)
		Fail("Recipient saves must reject aliased pending changes on the target limb without altering either file.", __FILE__, __LINE__)
	preferences.body_markings[zone][entries[1]["name"]][1] = entries[1]["color"]
	var/list/clear = custom_style_package("markings", zone, null, null, list())
	error = preferences.commit_custom_style(clear, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE)
	disk_preferences = json_decode(rustg_file_read(preferences.path))["character[preferences.default_slot]"]
	if(error || length(preferences.body_markings[zone]) || length(disk_preferences?["body_markings"]?[zone]) || preferences.custom_limb_markings?[zone])
		Fail("Explicit empty native markings must clear the saved limb and its drawing: [error]", __FILE__, __LINE__)
	previous = preferences.custom_style_previous_package("markings", zone)
	if(custom_style_package_hash(previous) != custom_style_package_hash(package) || preferences.commit_custom_style(previous, preferences.default_slot, rotate = TRUE, reject_pending_markings = TRUE))
		Fail("Restoring the previous style must recover both native markings and its drawing.", __FILE__, __LINE__)
	previous = preferences.custom_style_previous_package("markings", zone)
	if(custom_style_package_hash(previous) != custom_style_package_hash(clear))
		Fail("Restoration must rotate the explicit native Clear package as the previous style.", __FILE__, __LINE__)
	error = preferences.commit_custom_style(custom_style_package("markings", zone, old_drawing, null), preferences.default_slot, rotate = TRUE)
	if(error || json_encode(custom_style_marking_entries(preferences.body_markings[zone])) != json_encode(entries))
		Fail("A legacy package without native marking context must preserve saved native markings.", __FILE__, __LINE__)
	preferences.load_and_save = FALSE
	custom_style_test_cleanup(folder)

/// Transaction contents are opaque JSON; padding isolates file-size boundaries from drawing validation.
/proc/custom_style_test_large_sidecar()
	var/padding = "0"
	for(var/i in 1 to 23)
		padding += padding
	return "{\"character1\":{\"padding\":\"[padding]\",\"revision\":0}}"

/datum/unit_test/custom_style_transaction_target_limits/Run()
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/old_sprites = custom_style_test_large_sidecar()
	var/new_sprites = replacetext(old_sprites, "\"revision\":0", "\"revision\":1")
	for(var/fail_commit in list(FALSE, TRUE))
		var/folder = custom_style_test_folder(src)
		rustg_file_write(old_preferences, "[folder]preferences.json")
		var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, old_sprites)
		var/datum/custom_style_transaction/failing_test/transaction = new(folder, sidecar)
		transaction.contents = list("preferences" = new_preferences, "custom_sprites" = new_sprites)
		if(fail_commit)
			transaction.fail_suffix = CUSTOM_STYLE_TEST_JOURNAL
			transaction.fail_on_match = 2
			transaction.short_write = TRUE
		var/error = transaction.commit()
		if(fail_commit ? !error : error)
			Fail("A sidecar above 8 MiB must support normal commits and report injected final-journal failures.", __FILE__, __LINE__)
		if(rustg_file_read("[folder]preferences.json") != (fail_commit ? old_preferences : new_preferences) || rustg_file_read("[folder]custom_sprites.json") != (fail_commit ? old_sprites : new_sprites))
			Fail("A large-sidecar transaction must publish the new pair or roll back both old files after a failed final journal.", __FILE__, __LINE__)
		if(sidecar.last_good_json != (fail_commit ? old_sprites : new_sprites) || custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder])
			Fail("Large-sidecar commit and rollback must retain a verified snapshot, clean up, and allow future saves.", __FILE__, __LINE__)
		qdel(transaction)
		sidecar.path = null
		qdel(sidecar)
		custom_style_test_cleanup(folder)
	for(var/target in list("preferences", "custom_sprites"))
		var/folder = custom_style_test_folder(src)
		rustg_file_write(old_preferences, "[folder]preferences.json")
		var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, "{}")
		var/datum/custom_style_transaction/transaction = new(folder, sidecar)
		transaction.contents = list("preferences" = new_preferences, "custom_sprites" = "{}")
		transaction.contents[target] = target == "preferences" ? old_sprites : "[old_sprites][old_sprites]"
		if(!transaction.commit() || rustg_file_read("[folder]preferences.json") != old_preferences || rustg_file_read("[folder]custom_sprites.json") != "{}" || custom_style_test_remaining(folder))
			Fail("Transactions must retain the 8 MiB preferences and 16 MiB sidecar ceilings without changing live files.", __FILE__, __LINE__)
		qdel(transaction)
		sidecar.path = null
		qdel(sidecar)
		custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_transaction_large_recovery/Run()
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/old_sprites = custom_style_test_large_sidecar()
	var/new_sprites = replacetext(old_sprites, "\"revision\":0", "\"revision\":1")
	for(var/list/scenario as anything in list(list("replaced custom_sprites", FALSE, FALSE), list("committed", FALSE, TRUE), list("replaced preferences", TRUE, FALSE), list("replaced custom_sprites", TRUE, TRUE)))
		var/folder = custom_style_test_folder(src)
		rustg_file_write(old_preferences, "[folder]preferences.json")
		var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, old_sprites)
		var/datum/custom_style_transaction/crash_test/transaction = new(folder, sidecar)
		transaction.crash_phase = scenario[1]
		transaction.contents = list("preferences" = new_preferences, "custom_sprites" = new_sprites)
		if(transaction.commit() != "crashed")
			Fail("The large-sidecar fixture must reach its [scenario[1]] crash checkpoint.", __FILE__, __LINE__)
		if(scenario[2])
			rustg_file_write("{\"format\":", "[folder][CUSTOM_STYLE_TEST_JOURNAL]")
		var/datum/json_savefile/preferences/reloaded = new("[folder]preferences.json")
		var/expect_new = scenario[3]
		if(rustg_file_read("[folder]preferences.json") != (expect_new ? new_preferences : old_preferences) || rustg_file_read("[folder]custom_sprites.json") != (expect_new ? new_sprites : old_sprites))
			Fail("Large-sidecar recovery at [scenario[1]] must restore the matching [expect_new ? "new" : "old"] pair, including corrupt-journal recovery.", __FILE__, __LINE__)
		if(custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder] || reloaded.get_entry("character1")?["hairstyle_name"] != (expect_new ? "Short Hair" : "Bald"))
			Fail("Large-sidecar recovery must clean up and load the recovered preferences without blocking writes.", __FILE__, __LINE__)
		qdel(transaction)
		reloaded.path = null
		qdel(reloaded)
		sidecar.path = null
		qdel(sidecar)
		custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_transaction_oversized_recovery/Run()
	var/folder = custom_style_test_folder(src)
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/new_sprites = "{\"character1\":{\"revision\":1}}"
	rustg_file_write(new_preferences, "[folder]preferences.json")
	rustg_file_write(new_preferences, "[folder]preferences.json.txn-new")
	rustg_file_write(old_preferences, "[folder]preferences.json.txn-old")
	rustg_file_write(new_sprites, "[folder]custom_sprites.json")
	rustg_file_write("{}", "[folder]custom_sprites.json.txn-new")
	var/padding = custom_style_test_large_sidecar()
	rustg_file_write("[padding][padding]", "[folder]custom_sprites.json.txn-old")
	rustg_file_write("{\"format\":", "[folder][CUSTOM_STYLE_TEST_JOURNAL]")
	if(custom_style_recover_transaction(folder) || !GLOB.custom_style_blocked_folders[folder] || rustg_file_read("[folder]custom_sprites.json") != new_sprites || !fexists("[folder]custom_sprites.json.txn-old"))
		Fail("An existing oversized recovery copy must block recovery and preserve the live sidecar instead of being treated as an absent old file.", __FILE__, __LINE__)
	custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_transaction_failures/Run()
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/old_sprites = "{\"character1\":{}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/new_sprites = "{\"character1\":{\"hair\":1}}"
	for(var/suffix in list("preferences.json.txn-new", "custom_sprites.json.txn-old", CUSTOM_STYLE_TEST_JOURNAL, "preferences.json", "custom_sprites.json"))
		var/folder = custom_style_test_folder(src)
		rustg_file_write(old_preferences, "[folder]preferences.json")
		var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, old_sprites)
		var/datum/custom_style_transaction/failing_test/transaction = new(folder, sidecar)
		transaction.fail_suffix = suffix
		transaction.contents = list("preferences" = new_preferences, "custom_sprites" = new_sprites)
		if(!transaction.commit())
			Fail("A write failure at [suffix] must report failure.", __FILE__, __LINE__)
		if(rustg_file_read("[folder]preferences.json") != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sprites)
			Fail("A write failure at [suffix] must leave both old files in place.", __FILE__, __LINE__)
		if(custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder])
			Fail("A recovered failure at [suffix] must clean up without blocking writes.", __FILE__, __LINE__)
		qdel(transaction)
		sidecar.path = null
		qdel(sidecar)
		custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_final_journal_failure/Run()
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/old_sprites = "{\"character1\":{}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/new_sprites = "{\"character1\":{\"hair\":1}}"
	for(var/report_error in list(TRUE, FALSE))
		var/folder = custom_style_test_folder(src)
		rustg_file_write(old_preferences, "[folder]preferences.json")
		var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, old_sprites)
		var/datum/custom_style_transaction/failing_test/transaction = new(folder, sidecar)
		transaction.fail_suffix = CUSTOM_STYLE_TEST_JOURNAL
		transaction.fail_on_match = 2
		transaction.short_write = TRUE
		transaction.report_error = report_error
		transaction.contents = list("preferences" = new_preferences, "custom_sprites" = new_sprites)
		if(!transaction.commit())
			Fail("A truncated final journal must fail even when the writer reports success.", __FILE__, __LINE__)
		if(rustg_file_read("[folder]preferences.json") != old_preferences || rustg_file_read("[folder]custom_sprites.json") != old_sprites)
			Fail("Active rollback after a truncated final journal must restore both old files (reported error: [report_error]).", __FILE__, __LINE__)
		if(sidecar.last_good_json != old_sprites || json_encode(sidecar.get_entry("character1")) != "\[]")
			Fail("A failed transaction must retain the old in-memory sidecar and verified snapshot.", __FILE__, __LINE__)
		if(custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder])
			Fail("Successful rollback of a truncated final journal must clean up and permit another save.", __FILE__, __LINE__)
		qdel(transaction)
		var/datum/json_savefile/preferences/reloaded = new("[folder]preferences.json")
		if(reloaded.get_entry("character1")?["hairstyle_name"] != "Bald")
			Fail("Reloading after a rejected transaction must recover the old haircut.", __FILE__, __LINE__)
		reloaded.path = null
		qdel(reloaded)
		sidecar.path = null
		qdel(sidecar)
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
		if(preferences.custom_style_hair_problem(hair))
			Fail("An eligible human haircut must remain usable on preferences tab [window].", __FILE__, __LINE__)
		hair["opacity"] = 128
		if(!preferences.custom_style_hair_problem(hair))
			Fail("A human without mismatched parts must not gain hair opacity on tab [window].", __FILE__, __LINE__)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], TRUE)
		if(preferences.custom_style_hair_problem(hair))
			Fail("Enabled mismatched hair opacity must remain usable on preferences tab [window].", __FILE__, __LINE__)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
		if(!preferences.custom_style_hair_problem(hair))
			Fail("Mismatched hair opacity still requires its feature toggle on tab [window].", __FILE__, __LINE__)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
		hair["opacity"] = null
		hair["emissive"] = TRUE
		if(!preferences.custom_style_hair_problem(hair))
			Fail("Changing tabs must not bypass the master emissive permission.", __FILE__, __LINE__)
		hair["emissive"] = FALSE
	preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	var/error = preferences.commit_custom_style(custom_style_package("hair", null, null, hair), preferences.default_slot)
	if(error || preferences.read_preference(/datum/preference/choiced/hairstyle) != "Short Hair")
		Fail("The production save must publish an eligible haircut while game preferences are selected: [error]", __FILE__, __LINE__)

/datum/unit_test/custom_style_pending_hair_opacity/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
	preferences.load_custom_sprites()
	var/list/hair = custom_style_test_hair()
	if(!preferences.update_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], TRUE))
		return Fail("The pending opacity-toggle fixture must be accepted by character setup.", __FILE__, __LINE__)
	var/before_hair = json_encode(preferences.custom_style_hair_context())
	var/before_preferences = json_encode(preferences.savefile.get_entry())
	var/before_sidecar = json_encode(preferences.custom_sprite_savefile.get_entry())
	var/error = preferences.commit_custom_style(custom_style_package("hair", null, custom_sprite_test_drawing(), hair), preferences.default_slot, rotate = TRUE, reject_pending_hair = TRUE)
	if(!error || !findtext(error, "unsaved hair changes"))
		Fail("A pending hair opacity toggle must reject a salon save as an unsaved hair conflict.", __FILE__, __LINE__)
	if(json_encode(preferences.savefile.get_entry()) != before_preferences || json_encode(preferences.custom_sprite_savefile.get_entry()) != before_sidecar || json_encode(preferences.custom_style_hair_context()) != before_hair || !(/datum/preference/toggle/mutant_toggle/hair_opacity in preferences.recently_updated_keys))
		Fail("Rejecting a pending opacity toggle must preserve the saved package and pending character edits.", __FILE__, __LINE__)

/datum/unit_test/custom_style_transaction_crash_recovery/Run()
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	var/old_sprites = "{\"character1\":{}}"
	var/new_preferences = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}"
	var/new_sprites = "{\"character1\":{\"hair\":1}}"
	var/list/phases = list("staged" = FALSE, "prepared" = FALSE, "replaced preferences" = FALSE, "replaced custom_sprites" = FALSE, "committed" = TRUE)
	for(var/corrupt_journal in list(FALSE, TRUE))
		for(var/phase in phases)
			var/folder = custom_style_test_folder(src)
			rustg_file_write(old_preferences, "[folder]preferences.json")
			var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, old_sprites)
			var/datum/custom_style_transaction/crash_test/transaction = new(folder, sidecar)
			transaction.crash_phase = phase
			transaction.contents = list("preferences" = new_preferences, "custom_sprites" = new_sprites)
			transaction.commit()
			if(corrupt_journal && fexists("[folder][CUSTOM_STYLE_TEST_JOURNAL]"))
				rustg_file_write("{\"format\":", "[folder][CUSTOM_STYLE_TEST_JOURNAL]")
			// A new preferences load runs recovery before reading.
			var/datum/json_savefile/preferences/reloaded = new("[folder]preferences.json")
			var/live_preferences = rustg_file_read("[folder]preferences.json")
			var/live_sprites = rustg_file_read("[folder]custom_sprites.json")
			var/expect_new = phases[phase] || (corrupt_journal && phase == "replaced custom_sprites")
			if(expect_new ? (live_preferences != new_preferences || live_sprites != new_sprites) : (live_preferences != old_preferences || live_sprites != old_sprites))
				Fail("Recovery after a crash at [phase][corrupt_journal ? " with a corrupt journal" : ""] must leave both files [expect_new ? "new" : "old"].", __FILE__, __LINE__)
			if(custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder] || reloaded.get_entry("character1")?["hairstyle_name"] != (expect_new ? "Short Hair" : "Bald"))
				Fail("Recovery after a crash at [phase] must clean up and load the recovered preferences.", __FILE__, __LINE__)
			qdel(transaction)
			reloaded.path = null
			sidecar.path = null
			qdel(sidecar)
			custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_transaction_blocked_recovery/Run()
	var/folder = custom_style_test_folder(src)
	var/old_preferences = "{\"character1\":{\"hairstyle_name\":\"Bald\"}}"
	rustg_file_write(old_preferences, "[folder]preferences.json")
	var/datum/json_savefile/custom_sprites/sidecar = custom_style_test_sidecar(folder, "{}")
	var/datum/custom_style_transaction/crash_test/transaction = new(folder, sidecar)
	transaction.crash_phase = "replaced preferences"
	transaction.contents = list("preferences" = "{\"character1\":{\"hairstyle_name\":\"Short Hair\"}}", "custom_sprites" = "{\"x\":1}")
	transaction.commit()
	// The only verified copy of the old preferences is gone, so recovery can't be trusted.
	fdel("[folder]preferences.json.txn-old")
	var/datum/json_savefile/preferences/reloaded = new("[folder]preferences.json")
	if(reloaded.get_entry("character1")?["hairstyle_name"] != "Short Hair")
		Fail("Blocked recovery must still load character data instead of randomizing.", __FILE__, __LINE__)
	if(!GLOB.custom_style_blocked_folders[folder] || !fexists("[folder][CUSTOM_STYLE_TEST_JOURNAL]") || !fexists("[folder]custom_sprites.json.txn-new"))
		Fail("Failed recovery must block writes and preserve recovery material.", __FILE__, __LINE__)
	reloaded.set_entry("character1", list("hairstyle_name" = "Mohawk"))
	reloaded.save()
	sidecar.set_entry("character1", list())
	if(findtext(rustg_file_read("[folder]preferences.json"), "Mohawk") || sidecar.save())
		Fail("Blocked folders must not accept preference or sidecar writes.", __FILE__, __LINE__)
	qdel(transaction)
	reloaded.path = null
	sidecar.path = null
	qdel(sidecar)
	custom_style_test_cleanup(folder)

/datum/unit_test/custom_style_import_cleanup_transactions/Run()
	var/test_key = ckey("customstyletxn[REF(src)]")
	var/folder = "data/player_saves/c/[test_key]/"
	for(var/test_file in custom_style_transaction_files(folder))
		rustg_file_write("{}", test_file)
	GLOB.custom_style_blocked_folders[folder] = TRUE
	custom_sprites_after_import(test_key)
	if(custom_style_test_remaining(folder) || GLOB.custom_style_blocked_folders[folder])
		Fail("A successful preferences import must discard stale transaction material.", __FILE__, __LINE__)

#undef CUSTOM_STYLE_TEST_JOURNAL

#endif
