#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/datum/json_savefile/custom_sprites/counting_test
	var/writes = 0

/datum/json_savefile/custom_sprites/counting_test/save()
	writes++
	return ..()

/datum/json_savefile/custom_sprites/counting_test/failing
	var/fail_destination
	var/short_write = TRUE
	var/fail_on_match = 1
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
	custom_sprite_test_remove_sidecar(test_path)
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_import_cleanup/Run()
	var/test_key = ckey("customspriteunittest[REF(src)]")
	var/test_path = "data/player_saves/c/[test_key]/custom_sprites.json"
	if(fexists(test_path) || fexists("[test_path].bak") || fexists("[test_path].new") || GLOB.preferences_datums[test_key])
		return Fail("Disposable import fixture already exists.", __FILE__, __LINE__)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = new(test_path)
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	preferences.save_custom_sprite("hair", custom_sprite_test_drawing())
	preferences.save_custom_sprite("markings", custom_sprite_test_drawing("2"), preferences.default_slot, BODY_ZONE_L_ARM)
	GLOB.preferences_datums[test_key] = preferences
	custom_sprites_after_import(test_key)
	GLOB.preferences_datums -= test_key
	if(fexists(test_path) || fexists("[test_path].bak") || fexists("[test_path].new") || preferences.custom_hair || preferences.custom_markings || length(preferences.custom_limb_markings) || preferences.custom_sprite_savefile.path)
		Fail("An imported character must not inherit old disk data or writable cached drawings.", __FILE__, __LINE__)
	preferences.load_and_save = FALSE
	custom_sprite_test_remove_sidecar(test_path)

/datum/unit_test/custom_marking_zone_persistence/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_marking_zone_preferences_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/list/hair = custom_sprite_test_drawing("2")
	var/list/whole = custom_sprite_test_drawing()
	var/list/arm = custom_sprite_test_drawing("2")
	var/list/leg = custom_sprite_test_drawing()
	leg["emissive"] = custom_sprite_emissive_settings(list("1" = TRUE))
	preferences.save_custom_sprite("hair", hair)
	preferences.save_custom_sprite("markings", whole)
	preferences.save_custom_sprite("markings", arm, preferences.default_slot, BODY_ZONE_L_ARM)
	preferences.save_custom_sprite("markings", leg, preferences.default_slot, BODY_ZONE_R_LEG)
	if(json_encode(preferences.custom_markings) != json_encode(whole))
		Fail("A zone drawing must not replace the whole-body marking.", __FILE__, __LINE__)
	var/list/saved = store.get_entry("character[preferences.default_slot]")
	if(json_encode(saved?["limb_markings"]?[BODY_ZONE_L_ARM]) != json_encode(arm))
		Fail("A zone drawing must be saved independently in the same character slot.", __FILE__, __LINE__)
	if(store.writes != 4 || !preferences.save_custom_sprite("markings", arm, preferences.default_slot, BODY_ZONE_L_ARM) || store.writes != 4)
		Fail("Only a changed zone drawing should write the sidecar.", __FILE__, __LINE__)
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	if(json_encode(reloaded.get_entry("character[preferences.default_slot]")) != json_encode(saved))
		Fail("A new session must recover hair, whole-body markings, and independent zone drawings.", __FILE__, __LINE__)
	preferences.custom_hair = null
	preferences.custom_markings = null
	preferences.custom_limb_markings = null
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	if(json_encode(preferences.custom_hair) != json_encode(hair) || json_encode(preferences.custom_limb_markings?[BODY_ZONE_R_LEG]) != json_encode(leg))
		Fail("Reloading preferences must recover each drawing and its own emissive settings.", __FILE__, __LINE__)
	preferences.save_custom_sprite("markings", null, preferences.default_slot, BODY_ZONE_L_ARM)
	saved = store.get_entry("character[preferences.default_slot]")
	if(saved?["limb_markings"]?[BODY_ZONE_L_ARM] || json_encode(saved?["limb_markings"]?[BODY_ZONE_R_LEG]) != json_encode(leg) || json_encode(preferences.custom_hair) != json_encode(hair) || json_encode(preferences.custom_markings) != json_encode(whole))
		Fail("Clearing an arm must preserve hair, whole-body markings, and the leg drawing.", __FILE__, __LINE__)
	preferences.save_custom_sprite("markings", null, preferences.default_slot, BODY_ZONE_R_LEG)
	saved = store.get_entry("character[preferences.default_slot]")
	if(saved?["limb_markings"] || length(preferences.custom_limb_markings))
		Fail("Clearing the final zone must omit the empty zone map.", __FILE__, __LINE__)
	store.path = null
	custom_sprite_test_remove_sidecar(test_path)
	preferences.load_and_save = FALSE

/datum/unit_test/custom_marking_zone_validation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/list/drawing = custom_sprite_test_drawing()
	preferences.save_custom_sprite("markings", drawing)
	preferences.save_custom_sprite("markings", drawing, preferences.default_slot, BODY_ZONE_L_ARM)
	var/before = json_encode(preferences.custom_sprite_savefile.get_entry())
	for(var/bad_zone in list("", "tail", "Left arm", 1, list(BODY_ZONE_L_ARM)))
		if(preferences.save_custom_sprite("markings", null, preferences.default_slot, bad_zone))
			Fail("Invalid zones must be rejected instead of clearing a drawing.", __FILE__, __LINE__)
	if(preferences.save_custom_sprite("hair", drawing, preferences.default_slot, BODY_ZONE_HEAD))
		Fail("Hair cannot be saved to a marking zone.", __FILE__, __LINE__)
	if(json_encode(preferences.custom_sprite_savefile.get_entry()) != before)
		Fail("Rejected zone actions must leave all existing drawings untouched.", __FILE__, __LINE__)
	var/list/raw_zones = list(
		BODY_ZONE_L_ARM = drawing,
		BODY_ZONE_R_ARM = list("version" = 1, "palette" = list("not a color"), "dirs" = drawing["dirs"]),
		BODY_ZONE_L_LEG = "not a drawing",
		"tail" = drawing,
	)
	preferences.custom_sprite_savefile.set_entry("character[preferences.default_slot]", list("markings" = drawing, "limb_markings" = raw_zones))
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	if(length(preferences.custom_limb_markings) != 1 || json_encode(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != json_encode(drawing) || json_encode(preferences.custom_markings) != json_encode(drawing))
		Fail("Loading must retain valid zones and whole-body markings while dropping unknown and malformed zones.", __FILE__, __LINE__)
	for(var/bad_zones in list(null, 1, "not a map", list("tail" = drawing)))
		if(custom_limb_markings_validate(bad_zones))
			Fail("Invalid or empty zone maps must sanitize to no drawings.", __FILE__, __LINE__)
	var/list/all_zones = list()
	for(var/body_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		all_zones[body_zone] = drawing
	var/list/clean = custom_limb_markings_validate(all_zones)
	if(length(clean) != 6)
		Fail("Every supported body zone must survive validation.", __FILE__, __LINE__)
	clean[BODY_ZONE_HEAD]["palette"][1] = "#123456"
	if(clean[BODY_ZONE_CHEST]["palette"][1] == "#123456" || drawing["palette"][1] == "#123456")
		Fail("Validated zone drawings must not alias their source or each other.", __FILE__, __LINE__)

/datum/unit_test/custom_marking_zone_slots/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.create_character_preview_view(mock_client.mob)
	var/list/first = custom_sprite_test_drawing()
	var/list/second = custom_sprite_test_drawing("2")
	preferences.save_custom_sprite("markings", first, preferences.default_slot, BODY_ZONE_HEAD)
	preferences.switch_to_slot(2)
	preferences.load_custom_sprites()
	if(length(preferences.custom_limb_markings))
		Fail("A new slot must not inherit another slot's limb drawings.", __FILE__, __LINE__)
	if(preferences.save_custom_sprite("markings", second, 1, BODY_ZONE_HEAD))
		Fail("An old editor must not save into an inactive slot.", __FILE__, __LINE__)
	preferences.save_custom_sprite("markings", second, 2, BODY_ZONE_HEAD)
	preferences.switch_to_slot(1)
	preferences.load_custom_sprites()
	if(json_encode(preferences.custom_limb_markings?[BODY_ZONE_HEAD]) != json_encode(first))
		Fail("Switching back must restore the first slot's independent drawing.", __FILE__, __LINE__)
	preferences.remove_custom_sprite_slot(2)
	if(preferences.custom_sprite_savefile.get_entry("character2") || json_encode(preferences.custom_limb_markings?[BODY_ZONE_HEAD]) != json_encode(first))
		Fail("Removing another slot must preserve the active slot's limb drawings.", __FILE__, __LINE__)
	preferences.remove_custom_sprite_slot(1)
	if(preferences.custom_sprite_savefile.get_entry("character1") || length(preferences.custom_limb_markings))
		Fail("Removing the active slot must clear its stored and cached limb drawings.", __FILE__, __LINE__)

/datum/unit_test/custom_marking_zone_sidecar_capacity/Run()
	var/test_path = "tmp/custom_marking_zone_capacity_[REF(src)].json"
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
	var/list/all_slots = list()
	for(var/slot in 1 to MAX_SAVE_SLOTS_SUBSCRIBER)
		all_slots["character[slot]"] = list("hair" = drawing, "markings" = drawing, "limb_markings" = zones)
	text2file(json_encode(all_slots), test_path)
	var/datum/json_savefile/custom_sprites/store = allocate(/datum/json_savefile/custom_sprites, test_path)
	if(length(store.get_entry()) != MAX_SAVE_SLOTS_SUBSCRIBER || json_encode(store.get_entry("character[MAX_SAVE_SLOTS_SUBSCRIBER]")) != json_encode(all_slots["character[MAX_SAVE_SLOTS_SUBSCRIBER]"]))
		Fail("A full account with hair, whole-body markings, and six full limb drawings per slot must reload.", __FILE__, __LINE__)
	custom_sprite_test_remove_sidecar(test_path)
	var/padding = "0"
	for(var/i in 1 to 23)
		padding += padding
	text2file(json_encode(list("character1" = all_slots["character1"], "padding" = padding)), test_path)
	if(store.load() || length(store.get_entry()))
		Fail("Oversized sidecars must still be rejected and clear previously loaded entries.", __FILE__, __LINE__)
	store.path = null
	custom_sprite_test_remove_sidecar(test_path)

/datum/unit_test/custom_sprite_sidecar_write_failures/Run()
	for(var/suffix in list(".new", ".bak", ""))
		for(var/short_write in list(TRUE, FALSE))
			var/test_path = "tmp/custom_sprite_write_failure_[REF(src)][suffix][short_write].json"
			var/datum/json_savefile/custom_sprites/counting_test/failing/store = allocate(/datum/json_savefile/custom_sprites/counting_test/failing, test_path)
			var/list/original = list("hair" = custom_sprite_test_drawing())
			store.set_entry("character1", original)
			if(!store.save())
				Fail("Could not create the disposable write-failure fixture.", __FILE__, __LINE__)
			var/original_bytes = file2text(test_path)
			var/list/replacement = list("hair" = custom_sprite_test_drawing("2"))
			store.set_entry("character1", replacement)
			store.fail_destination = "[test_path][suffix]"
			store.short_write = short_write
			if(store.save() || !store.dirty || !store.last_save_failed)
				Fail("Partial writes and reported errors must fail without losing pending changes.", __FILE__, __LINE__)
			if(suffix && file2text(test_path) != original_bytes)
				Fail("Staging or backup failure must not touch the primary.", __FILE__, __LINE__)
			var/datum/json_savefile/custom_sprites/recovered = allocate(/datum/json_savefile/custom_sprites, test_path)
			if(json_encode(recovered.get_entry("character1")) != json_encode(original))
				Fail("A new session must recover the last good drawing after any failed write phase.", __FILE__, __LINE__)
			if(!suffix && short_write)
				// The primary is corrupt. A failed backup rewrite would destroy the only good file.
				store.fail_destination = "[test_path].bak"
			else
				store.fail_destination = null
			if(!store.save() || store.dirty || store.last_save_failed || file2text(test_path) != json_encode(list("character1" = replacement)))
				Fail("Retry must persist the retained draft and avoid rewriting the only good backup during recovery.", __FILE__, __LINE__)
			store.path = null
			custom_sprite_test_remove_sidecar(test_path)

/datum/unit_test/custom_sprite_sidecar_oversized_save/Run()
	var/test_path = "tmp/custom_sprite_oversized_save_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/store = allocate(/datum/json_savefile/custom_sprites, test_path)
	store.set_entry("character1", list("hair" = custom_sprite_test_drawing()))
	store.save()
	var/original = file2text(test_path)
	var/original_backup = file2text("[test_path].bak")
	var/padding = "0"
	for(var/i in 1 to 23)
		padding += padding
	store.set_entry("padding", padding)
	if(store.save() || !store.dirty || !store.last_save_failed || file2text(test_path) != original || file2text("[test_path].bak") != original_backup || fexists("[test_path].new"))
		Fail("An oversized serialized payload must be refused before staging, preserving both saved copies and dirty state.", __FILE__, __LINE__)
	store.remove_entry("padding")
	if(!store.save() || store.dirty || store.last_save_failed || file2text(test_path) != original)
		Fail("Removing the oversized entry must allow the retained drawing to save again.", __FILE__, __LINE__)
	store.path = null
	custom_sprite_test_remove_sidecar(test_path)

/datum/unit_test/custom_sprite_sidecar_recovery_and_deletion/Run()
	var/test_path = "tmp/custom_sprite_recovery_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/counting_test/failing/store = allocate(/datum/json_savefile/custom_sprites/counting_test/failing, test_path)
	store.set_entry("character1", list("hair" = custom_sprite_test_drawing()))
	store.set_entry("character2", list("markings" = custom_sprite_test_drawing("2")))
	store.save()
	store.remove_entry("character2")
	store.fail_destination = "[test_path].bak"
	store.fail_on_match = 2
	if(store.save() || !store.dirty || !store.last_save_failed)
		Fail("Failed backup scrubbing must remain dirty even after the new primary was written.", __FILE__, __LINE__)
	var/list/primary = json_decode(file2text(test_path))
	if(primary["character2"] || !primary["character1"])
		Fail("Backup scrub failure must preserve the verified primary and its slot deletion.", __FILE__, __LINE__)
	store.fail_destination = null
	if(!store.save())
		Fail("A failed deletion scrub must be retryable.", __FILE__, __LINE__)
	var/list/backup = json_decode(file2text("[test_path].bak"))
	if(backup["character2"] || !backup["character1"])
		Fail("Successful slot deletion must also remove the old identity from the recovery copy.", __FILE__, __LINE__)
	fdel(test_path)
	var/datum/json_savefile/custom_sprites/recovered = allocate(/datum/json_savefile/custom_sprites, test_path)
	if(!recovered.dirty || recovered.get_entry("character2") || !recovered.get_entry("character1") || !recovered.save())
		Fail("A missing primary must load its backup and remain dirty until the primary is repaired.", __FILE__, __LINE__)
	custom_sprite_test_remove_sidecar(test_path)
	store.path = null
	recovered.path = null

/datum/unit_test/custom_sprite_failed_save_retry/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/test_path = "tmp/custom_sprite_retry_[REF(src)].json"
	var/datum/json_savefile/custom_sprites/counting_test/failing/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	var/list/hair = custom_sprite_test_drawing()
	var/list/arm = custom_sprite_test_drawing("2")
	preferences.save_custom_sprite("hair", hair)
	store.fail_destination = "[test_path].new"
	if(preferences.save_custom_sprite("markings", arm, preferences.default_slot, BODY_ZONE_L_ARM) || !store.dirty || json_encode(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != json_encode(arm))
		Fail("A failed save must report failure and retain the limb draft in memory.", __FILE__, __LINE__)
	store.fail_destination = null
	if(!preferences.save_custom_sprite("hair", hair) || store.dirty || store.last_save_failed)
		Fail("Saving an unchanged other target must retry every pending sidecar change.", __FILE__, __LINE__)
	var/list/disk = json_decode(file2text(test_path))
	if(json_encode(disk["character1"]["limb_markings"][BODY_ZONE_L_ARM]) != json_encode(arm))
		Fail("A retry from another target must flush the failed limb save.", __FILE__, __LINE__)
	var/writes = store.writes
	if(!preferences.save_custom_sprite("markings", arm, preferences.default_slot, BODY_ZONE_L_ARM) || store.writes != writes)
		Fail("An unchanged, clean save must succeed without writing again.", __FILE__, __LINE__)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, "hair")
	preferences.custom_sprite_editors[editor.editor_key] = editor
	editor.workspace.clear_direction("2")
	store.fail_destination = "[test_path].new"
	if(editor.save_drawing() || editor.save_revision || !editor.save_error)
		Fail("A failed editor save must report an error without acknowledging a new revision.", __FILE__, __LINE__)
	editor.finish(TRUE)
	if(QDELETED(editor) || editor.closing || !preferences.custom_sprite_editors["hair"])
		Fail("Save and close must retain the editor and workspace after a disk failure.", __FILE__, __LINE__)
	store.fail_destination = null
	if(!editor.save_drawing() || editor.save_revision != 1 || editor.save_error)
		Fail("Successful retry must acknowledge the saved revision and clear the error.", __FILE__, __LINE__)
	editor.finish(TRUE)
	if(preferences.custom_sprite_editors["hair"])
		Fail("After a successful retry, closing must release the editor.", __FILE__, __LINE__)
	store.path = null
	preferences.load_and_save = FALSE
	custom_sprite_test_remove_sidecar(test_path)

#endif
