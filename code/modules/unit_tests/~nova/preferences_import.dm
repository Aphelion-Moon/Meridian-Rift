// Exercise native import helpers directly. Client fixtures supply mock client state;
// upload dialogs, permission checks, and reconnects are outside these tests.

/// Missing and empty preset collections must be safe before character migrations run.
/datum/unit_test/preferences_import_loadout_defaults/Run()
	var/list/legacy = list("/obj/item/cane" = list("name" = "Walking stick"))
	var/list/fixtures = list(
		list("version" = 52, "loadout_list" = legacy),
		list("version" = 52, "loadout_lists" = list()),
		list("version" = 52),
	)
	for(var/list/slot as anything in fixtures)
		prefs_import_pass1(list("version" = 52, "character1" = slot))
		var/list/presets = slot["loadout_lists"]
		TEST_ASSERT(length(presets), "Import left no preset for the loadout-index default before migration.")
		TEST_ASSERT(istext(presets[1]), "The first preset must be a usable loadout-index default.")
		if(slot["loadout_list"])
			TEST_ASSERT_EQUAL(json_encode(presets["Default"]), json_encode(legacy), "The legacy loadout was lost while supplying a modern default.")

/// JSON arrays inside item details must not become numeric list indexes.
/// Valid text receives UI-equivalent encoding; later cleanup must preserve shared loadout references.
/datum/unit_test/preferences_import_loadout_details/Run()
	var/list/clean
	try
		clean = prefs_import_clean_loadout(list("/obj/item/cane" = list(999, null, list(999))))
	catch
		TEST_FAIL("Malformed loadout detail keys caused a runtime instead of being discarded.")
		return
	TEST_ASSERT_EQUAL(length(clean["/obj/item/cane"]), 0, "Malformed loadout details were retained.")

	clean = prefs_import_clean_loadout(list("/obj/item/cane" = list("name" = "<b>Stick</b>", "description" = "A stick.")))
	var/list/details = clean["/obj/item/cane"]
	TEST_ASSERT_EQUAL(details["name"], html_encode("<b>Stick</b>"), "Imported names need the same HTML encoding as UI input.")
	TEST_ASSERT_EQUAL(details["description"], "A stick.", "A valid description was changed.")
	clean = prefs_import_clean_loadout(list("/obj/item/cane" = list("name" = list("invalid"), "description" = 999)))
	TEST_ASSERT_EQUAL(length(clean["/obj/item/cane"]), 0, "Structured or numeric values cannot be used as item names or descriptions.")

	// Post-migration cleanup relies on pass 1 having converted uploaded arrays to unique path keys.
	clean = prefs_import_clean_loadout(list("/obj/item/cane", "/obj/item/cane"))
	TEST_ASSERT_EQUAL(length(clean), 1, "Pass 1 must coalesce duplicate uploaded paths before post-migration cleanup.")
	clean += null
	clean[""] = list()
	var/shared_contents = json_encode(clean)
	var/list/slot = list("loadout_list" = clean)
	prefs_import_strip_empty_loadout_keys(slot)
	TEST_ASSERT_EQUAL(json_encode(clean), shared_contents, "Removing empty loadout keys changed another reference to the original list.")
	var/list/stripped = slot["loadout_list"]
	TEST_ASSERT_EQUAL(length(stripped), 1, "Post-migration cleanup did not remove every empty key.")
	TEST_ASSERT("/obj/item/cane" in stripped, "Post-migration cleanup removed a valid path.")

/// Reject unsafe augment registry values while preserving the numeric flags used by language entries.
/datum/unit_test/preferences_import_registry_values/Run()
	var/list/slot = list("version" = 52, "augments" = list("head" = 999), "augment_limb_styles" = list("head" = list(999)), "languages" = list("/datum/language/common" = 3))
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	TEST_ASSERT_EQUAL(length(slot["augments"]), 0, "A numeric augment would index its owner's registry out of bounds.")
	TEST_ASSERT_EQUAL(length(slot["augment_limb_styles"]), 0, "A structured augment style must not reach the owner's registry.")
	TEST_ASSERT_EQUAL(length(slot["languages"]), 1, "Valid numeric language flags were removed.")

/// These raw fields are consumed before native loaders reach their normal sanitizers.
/datum/unit_test/preferences_import_raw_player_fields/Run()
	var/list/upload = list("version" = 52, "preferred_spawn_outfits" = list(999), "key_bindings" = list(999), "favorite_outfits" = list(999))
	var/list/clean = prefs_import_pass1(upload)
	TEST_ASSERT_EQUAL(length(clean["preferred_spawn_outfits"]), 0, "A numeric spawn-outfit key will index its list out of bounds during load_preferences.")
	TEST_ASSERT_EQUAL(length(clean["key_bindings"]), 0, "A numeric keybinding key will reach the keybinding migration before sanitization.")
	TEST_ASSERT_EQUAL(length(clean["favorite_outfits"]), 0, "A numeric outfit type will reach text2path before sanitization.")

	upload = list("version" = 35, "key_bindings" = list("ShiftQ" = "quick_equip_belt", "X" = list("swap_hands", 999)), "preferred_spawn_outfits" = list("Normal" = "Naked"))
	clean = prefs_import_pass1(upload)
	var/list/bindings = clean["key_bindings"]
	TEST_ASSERT_EQUAL(json_encode(bindings["ShiftQ"]), json_encode(list("quick_equip_belt")), "Supported legacy scalar keybindings were lost.")
	TEST_ASSERT_EQUAL(json_encode(bindings["X"]), json_encode(list("swap_hands")), "Valid keybinding entries were lost while rejecting a hostile entry.")
	var/list/outfits = clean["preferred_spawn_outfits"]
	TEST_ASSERT_EQUAL(outfits["Normal"], "Naked", "The native special-case Naked outfit was lost.")

/// Exported names already contain HTML entities and must survive a round trip unchanged.
/datum/unit_test/preferences_import_encoded_loadouts/Run()
	var/name = "A &amp; B"
	var/list/input_presets = list()
	input_presets[name] = list("/obj/item/cane" = list("name" = name))
	var/list/slot = list("version" = 52, "loadout_lists" = input_presets, "loadout_index" = name)
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	var/list/presets = slot["loadout_lists"]
	TEST_ASSERT(name in presets, "Import double-encoded an exported preset name.")
	TEST_ASSERT_EQUAL(slot["loadout_index"], name, "Import changed the selected exported preset.")
	var/list/loadout = presets[name]
	var/list/details = loadout?["/obj/item/cane"]
	TEST_ASSERT_EQUAL(details?["name"], name, "Import double-encoded an exported custom item name.")

/// Player-owned fields import; the destination server retains its commendation state.
/// Omitting the destination metadata argument models a staff import that restores the complete backup.
/datum/unit_test/preferences_import_server_metadata/Run()
	var/list/upload = list("version" = 52, "hearted_until" = 999999999, "unrecognised_server_state" = TRUE, "sound_tts_blips" = TRUE)
	var/list/local_metadata = list("hearted_until" = 1234, "aphelion_import_notice_seen" = TRUE)
	var/list/clean = prefs_import_pass1(upload, local_metadata)
	TEST_ASSERT_EQUAL(clean["hearted_until"], 1234, "A player import replaced the server's commendation state.")
	TEST_ASSERT_EQUAL(clean["aphelion_import_notice_seen"], TRUE, "A player import lost the destination server's notice state.")
	TEST_ASSERT(!("unrecognised_server_state" in clean), "An unknown root field bypassed the player import allowlist.")
	TEST_ASSERT_EQUAL(clean["sound_tts_blips"], TRUE, "An input required by the legacy sound migration was removed.")

	clean = prefs_import_pass1(list("version" = 52, "hearted_until" = 999999999), list())
	TEST_ASSERT_NULL(clean["hearted_until"], "An upload granted a commendation to an account with none locally.")

	clean = prefs_import_pass1(list("version" = 52, "hearted_until" = 1234))
	TEST_ASSERT_EQUAL(clean["hearted_until"], 1234, "Staff imports must retain their existing ability to restore a complete backup.")

/// Use the native loadout preference and Nova migration with a supported pre-preset character.
/// The client is mocked; preference defaults, character loading, and finalization run against memory-only JSON.
/datum/unit_test/preferences_import_legacy_character/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/list/slot = list(
		"version" = 52,
		"modular_version" = 11,
		"tgui_prefs_migration" = TRUE,
		"real_name" = "Legacy Import",
		"loadout_list" = list("/obj/item/cane" = list("name" = "Walking stick")),
	)
	prefs_import_pass1(list("version" = 52, "character1" = slot))
	preferences.savefile.set_entry("character1", slot)
	preferences.value_cache = list()
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/loadout_index), "Default", "A legacy character cannot obtain a valid loadout index before migration.")
	TEST_ASSERT(preferences.load_character(), "A supported legacy character failed the native loader.")
	var/list/presets = preferences.read_preference(/datum/preference/loadout)
	var/list/loadout = presets["Default"]
	TEST_ASSERT(/obj/item/cane in loadout, "The native migration lost the imported cane.")
	var/list/details = loadout[/obj/item/cane]
	TEST_ASSERT_EQUAL(details["name"], "Walking stick", "The native migration lost custom item details.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Legacy Import", "The native migration changed a valid character name.")

	// A current root version must not prevent migration of a secondary legacy slot.
	var/list/second_slot = deep_copy_list(slot)
	second_slot["real_name"] = "Second Import"
	second_slot["modular_version"] = 11
	preferences.savefile.set_entry("character2", second_slot)
	preferences.savefile.set_entry("aphelion_import_pending", TRUE)
	TEST_ASSERT(preferences.prefs_import_finalise(), "The pending import was not finalized.")
	TEST_ASSERT(second_slot["modular_version"] > 11, "The secondary slot was rebuilt without running its native migration.")
	TEST_ASSERT_EQUAL(preferences.default_slot, 1, "Finalizing secondary slots changed the selected character.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/name/real_name), "Legacy Import", "Finalizing secondary slots left the wrong character loaded.")

/// Native preference loading uses memory-only JSON; file tests explicitly redirect writes to disposable paths.
/datum/preferences/preferences_import_test/load_path(ckey, filename)
	load_and_save = FALSE
	path = "preferences_import_memory_only"

/// Mock clients are datums, so their preference backreference must be detached before GC.
/datum/preferences/preferences_import_test/Destroy()
	if(parent?.prefs == src)
		parent.prefs = null
	parent = null
	return ..()

/// Real file writes verify that rejected imports preserve the original and successful replacements are complete.
/datum/unit_test/preferences_import_replacement
	var/test_path = "data/preferences_import_unit_test.json"

/datum/unit_test/preferences_import_replacement/Destroy()
	// Remove the fixture and every recovery artifact even when Run exits on a failed assertion.
	for(var/suffix in list("", ".importtmp", ".importrestore", ".updatebac"))
		fdel("[test_path][suffix]")
	return ..()

/datum/unit_test/preferences_import_replacement/Run()
	fdel(test_path)
	TEST_ASSERT(text2file("{\"version\":52,\"original\":true}", test_path), "Could not create the disposable import fixture.")
	var/original = file2text(test_path)
	TEST_ASSERT(prefs_import_replace(test_path, "invalid JSON"), "A malformed candidate was reported as successfully installed.")
	TEST_ASSERT_EQUAL(file2text(test_path), original, "Failed candidate verification changed the live file.")

	// A retained recovery file blocks another import until the recovery is resolved.
	TEST_ASSERT(text2file(original, "[test_path].importrestore"), "Could not create the disposable recovery fixture.")
	TEST_ASSERT(prefs_import_replace(test_path, "{\"version\":52}"), "A pending recovery backup was overwritten by another import.")
	TEST_ASSERT_EQUAL(file2text(test_path), original, "A pending recovery changed the live file.")
	fdel("[test_path].importrestore")

	var/list/replacement = list("version" = 52, "character1" = list("real_name" = "Imported Character"))
	TEST_ASSERT_NULL(prefs_import_replace(test_path, json_encode(replacement)), "A valid candidate failed to replace the disposable fixture.")
	TEST_ASSERT_EQUAL(json_encode(json_decode(file2text(test_path))), json_encode(replacement), "The replacement was not written completely or was appended to the old JSON.")
	TEST_ASSERT(!fexists("[test_path].importrestore"), "A successful import left a recovery lock behind.")

/// Keep every filesystem fixture separate from player saves and remove it even after an assertion fails.
/// Backup fixtures use distinct text markers to verify file retention and ownership.
/datum/unit_test/preferences_import_files
	abstract_type = /datum/unit_test/preferences_import_files
	var/test_path
	var/previous_player_backup_limit
	var/previous_admin_backup_limit
	var/previous_upload_limit

/datum/unit_test/preferences_import_files/New()
	..()
	test_path = "data/preferences_import_unit_test_[REF(src)].json"
	previous_player_backup_limit = CONFIG_GET(number/preferences_import_backup_limit)
	previous_admin_backup_limit = CONFIG_GET(number/savefile_backup_limit)
	previous_upload_limit = CONFIG_GET(number/savefile_upload_limit)

/datum/unit_test/preferences_import_files/Destroy()
	// Tear down allocated datums before restoring config and deleting their disposable files.
	. = ..()
	CONFIG_SET(number/preferences_import_backup_limit, previous_player_backup_limit)
	CONFIG_SET(number/savefile_backup_limit, previous_admin_backup_limit)
	CONFIG_SET(number/savefile_upload_limit, previous_upload_limit)
	for(var/suffix in list("", ".txt", ".importbac", ".importtmp", ".importrestore", ".updatebac"))
		fdel("[test_path][suffix]")
	for(var/index in 1 to 5)
		fdel("[test_path].importbac-[index]")
		fdel("[test_path].playerimportbac-[index]")

/// Replace fixture contents explicitly because text2file appends to an existing file.
/datum/unit_test/preferences_import_files/proc/write_fixture(suffix, contents)
	var/fixture_path = "[test_path][suffix]"
	if(fexists(fixture_path) && !fdel(fixture_path))
		return FALSE
	return text2file(contents, fixture_path)

/// A player import must never rotate or overwrite the backups retained by an administrator.
/datum/unit_test/preferences_import_files/player_preserves_staff_backups/Run()
	CONFIG_SET(number/preferences_import_backup_limit, 3)
	TEST_ASSERT(write_fixture("", "current preferences"), "Could not write the current preferences fixture.")
	TEST_ASSERT(write_fixture(".importbac", "first staff backup"), "Could not write the first staff backup fixture.")
	TEST_ASSERT(write_fixture(".importbac-2", "second staff backup"), "Could not write the second staff backup fixture.")
	var/first_staff_backup = file2text("[test_path].importbac")
	var/second_staff_backup = file2text("[test_path].importbac-2")
	var/current_preferences = file2text(test_path)

	TEST_ASSERT(prefs_import_backup(test_path), "The player backup failed with available capacity.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), current_preferences, "The player backup was not saved in its own collection.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac"), first_staff_backup, "The player backup changed the first staff backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac-2"), second_staff_backup, "The player backup overwrote a retained staff backup.")

/// Compact gaps without losing backups, then rotate only the oldest once the player collection is full.
/datum/unit_test/preferences_import_files/player_backup_gaps/Run()
	CONFIG_SET(number/preferences_import_backup_limit, 3)
	TEST_ASSERT(write_fixture("", "current preferences"), "Could not write the current preferences fixture.")
	TEST_ASSERT(write_fixture(".playerimportbac-1", "oldest backup"), "Could not write the oldest player backup fixture.")
	TEST_ASSERT(write_fixture(".playerimportbac-3", "newer backup"), "Could not write the newer player backup fixture.")
	var/oldest_backup = file2text("[test_path].playerimportbac-1")
	var/newer_backup = file2text("[test_path].playerimportbac-3")
	var/current_preferences = file2text(test_path)

	TEST_ASSERT(prefs_import_backup(test_path), "The player backup failed when its collection contained a gap.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), oldest_backup, "A backup was dropped before the configured capacity was reached.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-2"), newer_backup, "Compacting a gap lost the newer retained backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-3"), current_preferences, "The current preferences were not added after retained backups.")

	TEST_ASSERT(write_fixture("", "next preferences"), "Could not update the current preferences fixture.")
	var/next_preferences = file2text(test_path)
	TEST_ASSERT(prefs_import_backup(test_path), "Rotating a full player backup collection failed.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), newer_backup, "Rotation did not retain the second oldest backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-2"), current_preferences, "Rotation lost the preceding import's backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-3"), next_preferences, "Rotation did not append the newest backup.")
	TEST_ASSERT(!fexists("[test_path].playerimportbac-4"), "Rotation exceeded the configured backup capacity.")

/// Sparse compaction removes leftover high slots; capacity one retains only the latest backup.
/datum/unit_test/preferences_import_files/player_backup_sparse_and_single/Run()
	CONFIG_SET(number/preferences_import_backup_limit, 3)
	TEST_ASSERT(write_fixture("", "current preferences"), "Could not write the current preferences fixture.")
	TEST_ASSERT(write_fixture(".playerimportbac-3", "retained backup"), "Could not write the sparse player backup fixture.")
	var/retained_backup = file2text("[test_path].playerimportbac-3")
	var/current_preferences = file2text(test_path)
	TEST_ASSERT(prefs_import_backup(test_path), "Compacting a single high-numbered backup failed.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), retained_backup, "Compaction lost the retained backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-2"), current_preferences, "Compaction did not append the current preferences.")
	TEST_ASSERT(!fexists("[test_path].playerimportbac-3"), "Compaction left a duplicate in the original high slot.")

	TEST_ASSERT(fdel("[test_path].playerimportbac-2"), "Could not remove the second disposable backup before testing capacity one.")
	CONFIG_SET(number/preferences_import_backup_limit, 1)
	TEST_ASSERT(prefs_import_backup(test_path), "Rotating a single-file backup collection failed.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), current_preferences, "A single-file backup collection did not retain the current preferences.")
	TEST_ASSERT(!fexists("[test_path].playerimportbac-2"), "A single-file backup collection exceeded its capacity.")

/// Staff backups fill free names and refuse at the limit instead of replacing earlier recovery data.
/datum/unit_test/preferences_import_files/admin_backup_gaps_and_limit/Run()
	CONFIG_SET(number/savefile_backup_limit, 3)
	TEST_ASSERT(write_fixture("", "current preferences"), "Could not write the current preferences fixture.")
	TEST_ASSERT(write_fixture(".importbac", "oldest staff backup"), "Could not write the oldest staff backup fixture.")
	TEST_ASSERT(write_fixture(".importbac-3", "newer staff backup"), "Could not write the newer staff backup fixture.")
	TEST_ASSERT(write_fixture(".playerimportbac-1", "separate player backup"), "Could not write the player backup fixture.")
	var/oldest_backup = file2text("[test_path].importbac")
	var/newer_backup = file2text("[test_path].importbac-3")
	var/player_backup = file2text("[test_path].playerimportbac-1")
	var/current_preferences = file2text(test_path)

	TEST_ASSERT_NULL(prefs_import_admin_backup(test_path), "The staff backup failed despite an available filename and capacity.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac-2"), current_preferences, "The staff backup did not use the free suffix.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac"), oldest_backup, "The staff backup replaced the oldest backup.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac-3"), newer_backup, "A gap caused a retained staff backup to be overwritten.")
	TEST_ASSERT_EQUAL(file2text("[test_path].playerimportbac-1"), player_backup, "The staff backup changed the player's separate collection.")

	TEST_ASSERT(write_fixture("", "next preferences"), "Could not update the current preferences fixture.")
	TEST_ASSERT(prefs_import_admin_backup(test_path), "A full staff backup collection must return an error.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac-2"), current_preferences, "Refusing at the staff backup limit changed an existing backup.")
	TEST_ASSERT(!fexists("[test_path].importbac-4"), "The staff backup exceeded its configured capacity.")

	CONFIG_SET(number/savefile_backup_limit, 0)
	TEST_ASSERT_NULL(prefs_import_admin_backup(test_path), "Disabling staff backups must still permit the import.")
	TEST_ASSERT_EQUAL(file2text("[test_path].importbac-2"), current_preferences, "Disabling staff backups must leave retained backups untouched.")

/// Mock-client construction registers persistent datums; isolate and restore those registries too.
/datum/unit_test/preferences_import_files/with_client
	abstract_type = /datum/unit_test/preferences_import_files/with_client
	var/list/previous_preferences
	var/list/previous_directory
	var/list/previous_persistent_clients
	var/list/previous_persistent_client_list

/datum/unit_test/preferences_import_files/with_client/New()
	..()
	previous_preferences = GLOB.preferences_datums
	previous_directory = GLOB.directory
	previous_persistent_clients = GLOB.persistent_clients_by_ckey
	previous_persistent_client_list = GLOB.persistent_clients
	GLOB.preferences_datums = list()
	GLOB.directory = list()
	GLOB.persistent_clients_by_ckey = list()
	GLOB.persistent_clients = list()

/datum/unit_test/preferences_import_files/with_client/Destroy()
	// Allocated clients and preferences must tear down against test registries before the originals return.
	. = ..()
	GLOB.preferences_datums = previous_preferences
	GLOB.directory = previous_directory
	GLOB.persistent_clients_by_ckey = previous_persistent_clients
	GLOB.persistent_clients = previous_persistent_client_list

/// Calling ui_close and load_savefile on stale preferences must not overwrite the installed import.
/datum/unit_test/preferences_import_files/with_client/detach_stale_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/cached_preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preferences/connected_preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	mock_client.prefs = connected_preferences
	GLOB.preferences_datums[mock_client.ckey] = cached_preferences
	// The registry and connected client can hold different datums; both can still reach the same file.
	var/list/stale_preferences = list(cached_preferences, connected_preferences)
	for(var/datum/preferences/preferences as anything in stale_preferences)
		preferences.path = test_path
		preferences.load_and_save = TRUE
		preferences.savefile.path = test_path
		preferences.savefile.set_entry("pre_import_marker", TRUE)
	cached_preferences.savefile.save()
	TEST_ASSERT_NULL(prefs_import_replace(test_path, json_encode(list("version" = 52, "imported_marker" = TRUE))), "Could not install the imported fixture.")
	var/imported_contents = file2text(test_path)

	prefs_import_invalidate_cache(mock_client.ckey)
	TEST_ASSERT_NULL(GLOB.preferences_datums[mock_client.ckey], "The imported account still has a cached preferences datum.")
	for(var/datum/preferences/preferences as anything in stale_preferences)
		preferences.ui_close(mock_client.mob)
		TEST_ASSERT_EQUAL(file2text(test_path), imported_contents, "Closing the old preferences UI overwrote the imported file.")
		preferences.load_savefile()
		preferences.savefile.set_entry("late_stale_marker", TRUE)
		preferences.savefile.save()
		TEST_ASSERT_EQUAL(file2text(test_path), imported_contents, "Reloading an invalidated preferences datum restored its ability to overwrite the import.")

/// Both import verbs validate the uploaded container before applying their separate metadata policies.
/// Real files exercise extension, size, JSON, and native version checks without invoking either verb.
/datum/unit_test/preferences_import_files/with_client/shared_upload_validation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	CONFIG_SET(number/savefile_upload_limit, 1)
	for(var/invalid_contents in list("{", "\[\]", "true", "{\"version\":\"52\"}", "{\"version\":0}"))
		TEST_ASSERT(write_fixture("", invalid_contents), "Could not write an invalid upload fixture.")
		var/list/rejected = prefs_import_read_upload(file(test_path), preferences)
		TEST_ASSERT(rejected["error"], "Shared validation accepted malformed JSON, an invalid root, or an unsupported version.")
		TEST_ASSERT(!("tree" in rejected), "A rejected upload returned a tree that a caller could install.")

	var/list/supported_upload = list("version" = 52, "hearted_until" = 1234, "character1" = list("version" = 52))
	var/supported_contents = json_encode(supported_upload)
	TEST_ASSERT(write_fixture(".txt", supported_contents), "Could not write the wrong-extension upload fixture.")
	var/list/rejected = prefs_import_read_upload(file("[test_path].txt"), preferences)
	TEST_ASSERT(rejected["error"], "Shared validation accepted an upload with the wrong file extension.")

	var/padding = ""
	for(var/index in 1 to 2048)
		padding += "x"
	TEST_ASSERT(write_fixture("", json_encode(list("version" = 52, "padding" = padding))), "Could not write the oversized upload fixture.")
	rejected = prefs_import_read_upload(file(test_path), preferences)
	TEST_ASSERT(rejected["error"], "Shared validation accepted a file larger than the configured upload limit.")

	TEST_ASSERT(write_fixture("", supported_contents), "Could not write a supported upload fixture.")
	var/list/accepted = prefs_import_read_upload(file(test_path), preferences)
	TEST_ASSERT_NULL(accepted["error"], "Shared validation rejected a supported preferences upload.")
	TEST_ASSERT_EQUAL(json_encode(accepted["tree"]), supported_contents, "Shared validation changed the uploaded tree before the caller applied its metadata policy.")
	TEST_ASSERT_EQUAL(accepted["filesize"], length(file(test_path)), "Shared validation returned an incorrect upload byte count.")
