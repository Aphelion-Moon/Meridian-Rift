/// Staged save text keeps edits, failures and slot lifecycles apart, and holds each character to its byte limit.
/datum/unit_test/cyborg_storage_fixture
	parent_type = /datum/unit_test/cyborg_mock_preferences
	abstract_type = /datum/unit_test/cyborg_storage_fixture
	var/model_a
	var/model_b

/// With a sidecar path the editor saves through the real store; without one, to a double that records its writes.
/datum/unit_test/cyborg_storage_fixture/proc/make_editor(sidecar_path)
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	// Allocated after the preferences, so it outlives the editor's final commit at teardown.
	var/datum/json_savefile/cyborg_customization/store = sidecar_path \
		? allocate(/datum/json_savefile/cyborg_customization, sidecar_path) \
		: allocate(/datum/json_savefile/cyborg_customization/review_failure_store, null)
	preferences.cyborg_layout_savefile = store
	model_a = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	model_b = cyborg_appearance_model_id(/obj/item/robot_model/service, "Drake")
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.preview_model = model_a
	var/list/draft = editor.begin_draft()
	draft["active_model"] = model_a
	draft["active"]["penis"]["sprite"] = "Dogborg Knotted"
	draft["active"]["penis"]["advanced"]["south"] = list("pixel_y" = 7, "arousal" = list("full" = list("pixel_y" = 13)))
	draft["presets"]["Alpha"] = cyborg_layout_copy(draft["active"])
	draft["presets"]["Beta"] = cyborg_layout_copy(draft["active"])
	draft["presets"]["Beta"]["penis"]["pixel_x"] = 17
	draft["preset_models"]["Alpha"] = model_a
	draft["preset_models"]["Beta"] = model_a
	draft["model_defaults"][model_a] = cyborg_layout_copy(draft["active"])
	draft["model_defaults"][model_b] = cyborg_layout_copy(draft["active"])
	draft["model_defaults"][model_b]["penis"]["pixel_x"] = 33
	draft["model_presets"][model_a] = "Alpha"
	editor.update_draft(draft)
	editor.commit_draft()
	return editor

/datum/unit_test/cyborg_storage_fixture/proc/command(datum/preference_middleware/cyborg_character/editor, list/params)
	params["character_slot"] = editor.preferences.default_slot
	params["context"] = editor.context_generation
	return editor.edit_layout(params, null)

/datum/unit_test/cyborg_storage_fixture/proc/place(datum/preference_middleware/cyborg_character/editor, value)
	return command(editor, list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = SOUTH), "changes" = list("pixel_x" = value)))

/// Every part with every override, arousal state and field away from its default: the most one layout can hold.
/datum/unit_test/cyborg_storage_fixture/proc/full_depth_layout()
	var/list/layout = cyborg_layout_default_slots()
	for(var/part in layout)
		var/list/entry = layout[part]
		entry["pixel_x"] = -101
		entry["pixel_y"] = 102
		entry["rotation"] = -103
		entry["scale"] = 1.85
		entry["sprite"] = "Dogborg Knotted"
		entry["colors"] = list("#123456", "#abcdef", "#fedcba")
		entry["placement_groups"] = list(
			"north" = list("pixel_x" = -111, "pixel_y" = 112, "rotation" = -113),
			"south" = list("pixel_x" = -121, "pixel_y" = 122, "rotation" = -123),
			"side" = list("pixel_x" = -126, "pixel_y" = 127, "rotation" = -128),
		)
		var/key_number = 0
		for(var/key in cyborg_layout_supported_advanced_keys())
			key_number++
			var/list/fields = list("visible" = FALSE, "pixel_x" = -100 - key_number, "pixel_y" = 100 + key_number, "rotation" = -170 + key_number, "scale" = 1.75, "priority" = 9)
			var/list/override = fields.Copy()
			override["arousal"] = list("none" = fields.Copy(), "partial" = fields.Copy(), "full" = fields.Copy())
			entry["advanced"][key] = override
	return layout

/// Text past the sidecar limit, without building layouts that big.
/datum/unit_test/cyborg_storage_fixture/proc/oversized_text()
	. = "x"
	while(length(.) <= CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
		. += .

/// Save text reloads as exactly what the old nested tree reloaded as, which overrides exist included, in far fewer bytes.
/datum/unit_test/cyborg_save_text_round_trip
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_save_text_round_trip/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/list/layout = cyborg_layout_default()
	layout["active_model"] = model_a
	var/list/penis = layout["active"]["penis"]
	penis["pixel_x"] = -12
	penis["scale"] = 1.35
	penis["sprite_size"] = 5
	penis["mirror_sides"] = FALSE
	penis["reuse_south"] = TRUE
	penis["sprite"] = ""
	penis["colors"] = list("#ff0000", "#ffffff", "#00ff00")
	penis["placement_groups"] = list("south" = list("pixel_x" = 0, "pixel_y" = 0, "rotation" = 0), "side" = list("pixel_x" = 4, "pixel_y" = -2, "rotation" = 90))
	// An override left at its defaults still hides its direction's older override.
	penis["advanced"] = list(
		"south" = list("pixel_y" = 7),
		"idle_south" = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "scale" = 1, "priority" = 5),
		"rest_west" = list("visible" = FALSE, "pixel_x" = 3, "pixel_y" = 0, "rotation" = -45, "scale" = 0.75, "priority" = 9, "arousal" = list("partial" = list("pixel_y" = 0), "full" = list("visible" = TRUE, "scale" = 1.5))),
		"sit_east" = list("arousal" = list("none" = list("rotation" = 10))),
	)
	layout["active"]["breasts"]["colors"] = list("#123456", "#ffffff", "#ffffff")
	layout["presets"]["Alpha"] = cyborg_layout_copy(layout["active"])
	layout["presets"]["Beta"] = cyborg_layout_default_slots()
	layout["preset_models"]["Alpha"] = model_a
	layout["active_preset"] = "Alpha"
	layout["model_defaults"][model_a] = cyborg_layout_copy(layout["presets"]["Alpha"])
	layout["model_presets"][model_a] = "Alpha"
	layout["model_defaults"][model_b] = cyborg_layout_default_slots()
	layout["model_defaults"][model_b]["vagina"]["rotation"] = 30
	var/list/expected = cyborg_layout_normalize(layout)
	var/text = cyborg_layout_encode(expected)
	var/list/decoded = cyborg_layout_decode(text)
	TEST_ASSERT_EQUAL(json_encode(decoded), json_encode(expected), "The save text did not reload as the same layout.")
	TEST_ASSERT_EQUAL(cyborg_resolve_placement(decoded["active"]["penis"], SOUTH, "idle", "none")["pixel_y"], 0, "An override at its defaults stopped hiding the direction's older override.")
	TEST_ASSERT(length(text) * 4 < length(json_encode(expected)), "The save text is not much smaller than the nested tree ([length(text)] vs [length(json_encode(expected))] bytes).")
	// Older nested saves still load, and the next commit rewrites them as save text.
	var/datum/json_savefile/cyborg_customization/store = editor.preferences.cyborg_layout_store()
	editor.discard_draft()
	store.set_entry("character1", layout)
	TEST_ASSERT_EQUAL(json_encode(editor.begin_draft()), json_encode(expected), "An older nested save loaded differently.")
	place(editor, 5)
	editor.commit_draft()
	TEST_ASSERT(istext(store.get_entry("character1")), "The next commit kept the older nested format.")
	// Text from a newer format is kept as it is and never opened.
	editor.discard_draft()
	store.set_entry("character1", "\[3,\"later\"]")
	TEST_ASSERT_NULL(editor.begin_draft(), "A newer save text was opened as a current draft.")
	TEST_ASSERT_EQUAL(editor.preferences.read_cyborg_layout(1), "\[3,\"later\"]", "A newer save text was decoded or rewritten.")

/// Staging writes text, so nothing done to the draft or a read tree afterwards reaches the saved revision.
/datum/unit_test/cyborg_staged_text_is_independent
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_staged_text_is_independent/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	place(editor, 29)
	TEST_ASSERT(editor.commit_draft(), "A placement did not stage.")
	var/staged = preferences.cyborg_layout_store().get_entry("character1")
	TEST_ASSERT(istext(staged), "The slot was not staged as save text.")
	var/list/after = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(after["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 29, "Staging lost the accepted placement.")
	TEST_ASSERT_EQUAL(json_encode(after), json_encode(cyborg_layout_normalize(editor.draft)), "The staged slot is not what reloading the draft gives.")
	editor.draft["active"]["penis"]["placement_groups"]["south"]["pixel_x"] = 99
	editor.draft["model_defaults"][model_b]["penis"]["pixel_x"] = 99
	after["presets"]["Beta"]["penis"]["pixel_x"] = 99
	TEST_ASSERT_EQUAL(preferences.cyborg_layout_store().get_entry("character1"), staged, "Changing the draft or a read tree changed the staged text.")
	var/list/reread = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(reread["model_defaults"][model_b]["penis"]["pixel_x"], 33, "A later draft change reached the staged default.")
	TEST_ASSERT_EQUAL(reread["presets"]["Beta"]["penis"]["pixel_x"], 17, "Changing a read tree reached the staged preset.")

/// Library actions stage everything they touch: a preset update reaches its linked default, and order survives re-adding.
/datum/unit_test/cyborg_library_actions_stage_completely
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_library_actions_stage_completely/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	place(editor, 41)
	command(editor, list("operation" = "save", "name" = "Alpha", "overwrite" = TRUE))
	var/list/saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["presets"]["Alpha"]["penis"]["placement_groups"]["south"]["pixel_x"], 41, "Preset overwrite was not staged.")
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_a]["penis"]["placement_groups"]["south"]["pixel_x"], 41, "Preset overwrite missed its assigned default.")
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_b]["penis"]["pixel_x"], 33, "Preset overwrite changed an unrelated default.")
	command(editor, list("operation" = "assign_default", "name" = "Beta"))
	saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_a]["penis"]["pixel_x"], 17, "Assigning a preset did not copy its default.")
	TEST_ASSERT(saved["presets"]["Beta"] != saved["model_defaults"][model_a], "Assigned preset and default reload as one list.")
	command(editor, list("operation" = "delete", "name" = "Alpha"))
	command(editor, list("operation" = "save", "name" = "Alpha"))
	saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["presets"][1], "Beta", "Delete and re-add changed the preset order.")
	TEST_ASSERT_EQUAL(saved["presets"][2], "Alpha", "A re-added preset was not staged in its new place.")
	command(editor, list("operation" = "load", "name" = "Beta"))
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 17, "Loading a preset did not stage the new active layout.")
	for(var/operation in list("reset_position", "reset_colors", "reset_overrides", "reset", "save_default", "load_default", "delete_default"))
		command(editor, list("operation" = operation, "slot" = "penis"))
		editor.commit_draft()
		TEST_ASSERT_EQUAL(json_encode(preferences.read_cyborg_layout(1)), json_encode(cyborg_layout_normalize(editor.draft)), "[operation] was not staged completely.")
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(1)["model_defaults"][model_a], "Deleting the selected default left it staged.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 33, "Library actions lost an unrelated default.")

/// Raw draft updates stage like action results, and a public write to the editor's slot makes it stage its draft again.
/datum/unit_test/cyborg_raw_updates_and_public_writes
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_raw_updates_and_public_writes/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/list/raw = editor.begin_draft()
	raw["model_defaults"][model_b]["penis"]["pixel_x"] = 45
	raw["extra_root"] = list("nested" = list("value" = 19))
	editor.update_draft(raw)
	place(editor, 51)
	editor.commit_draft()
	var/list/first = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(first["model_defaults"][model_b]["penis"]["pixel_x"], 45, "A raw library update was not staged.")
	TEST_ASSERT(!("extra_root" in first), "Data outside the layout schema was staged, though a reload drops it.")
	var/list/external = cyborg_layout_default()
	external["model_defaults"][model_b] = cyborg_layout_default_slots()
	external["model_defaults"][model_b]["penis"]["pixel_x"] = 66
	var/staged_revision = editor.staged_revision
	preferences.write_cyborg_layout(2, external)
	TEST_ASSERT_EQUAL(editor.staged_revision, staged_revision, "Writing another slot made the editor stage its own again.")
	preferences.write_cyborg_layout(1, external)
	TEST_ASSERT_EQUAL(editor.staged_revision, -1, "Replacing the editor's slot left it believing its draft was staged.")
	external["model_defaults"][model_b]["penis"]["pixel_x"] = 88
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 66, "The public writer kept a reference to its input.")
	place(editor, 53)
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 45, "The editor's next commit did not stage its whole draft over the replacement.")

/// A public replacement can complete I/O without saving the editor's superseded pending revision.
/datum/unit_test/cyborg_external_stage_keeps_unsaved_revision
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_external_stage_keeps_unsaved_revision/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = preferences.cyborg_layout_store()
	store.path = "review-storage-counter-no-file"
	store.fail_writes = TRUE
	store.next_write_at = world.time
	place(editor, 71)
	var/pending_revision = editor.draft_revision
	TEST_ASSERT(!editor.commit_draft(), "The pending fixture unexpectedly saved its revision.")
	var/list/external = cyborg_layout_default()
	external["active"]["penis"]["pixel_x"] = 73
	store.fail_writes = FALSE
	store.next_write_at = world.time
	TEST_ASSERT(preferences.write_cyborg_layout(1, external), "The external replacement did not save.")
	TEST_ASSERT(editor.dirty && editor.saved_revision != pending_revision, "An external replacement falsely acknowledged the superseded editor revision.")
	TEST_ASSERT_EQUAL(editor.staged_revision, -1, "External replacement retained the superseded staging revision.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 73, "The external replacement was silently overwritten.")
	store.next_write_at = world.time
	TEST_ASSERT(editor.commit_draft(), "The next editor commit did not save the retained draft.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 71, "The next editor commit lost its retained accepted revision.")
	TEST_ASSERT(!editor.dirty && editor.saved_revision == pending_revision, "The retained revision was not acknowledged after it actually saved.")

/// Root and sprite callbacks must publish new draft roots before staging can track revisions.
/datum/unit_test/cyborg_stage_model_sprite_callbacks
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_stage_model_sprite_callbacks/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/list/original_draft = editor.draft
	editor.set_preview(list("context" = editor.context_generation, "model" = model_b), null)
	TEST_ASSERT_EQUAL(original_draft["active_model"], model_a, "Model selection mutated a previously returned draft root.")
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active_model"], model_b, "Model-only change was not staged.")
	var/list/before_sprite = editor.draft
	var/list/staged_before = preferences.read_cyborg_layout(1)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], SPRITE_ACCESSORY_NONE)
	editor.post_set_preference(null, "silicon_penis_sprite", SPRITE_ACCESSORY_NONE)
	TEST_ASSERT_EQUAL(before_sprite["active"]["penis"]["sprite"], "Dogborg Knotted", "Sprite selection mutated a previously returned active entry.")
	editor.commit_draft()
	var/list/after_sprite = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(after_sprite["active"]["penis"]["sprite"], SPRITE_ACCESSORY_NONE, "Sprite change was not staged.")
	TEST_ASSERT_EQUAL(json_encode(after_sprite["model_defaults"][model_b]), json_encode(staged_before["model_defaults"][model_b]), "A sprite-only change altered an unrelated saved default.")
	TEST_ASSERT_EQUAL(after_sprite["model_defaults"][model_b]["penis"]["sprite"], "Dogborg Knotted", "Sprite selection mutated a saved default.")

/// A newer accepted stage must survive failed I/O, slot changes, deletion and future-schema replacement.
/datum/unit_test/cyborg_stage_failure_slot_lifecycle
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_stage_failure_slot_lifecycle/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = preferences.cyborg_layout_store()
	store.path = "review-storage-counter-no-file"
	store.fail_writes = TRUE
	store.next_write_at = world.time
	place(editor, 61)
	var/revision = editor.draft_revision
	TEST_ASSERT(!editor.commit_draft(), "A failed write was acknowledged.")
	TEST_ASSERT(editor.dirty && editor.saved_revision != revision, "Failure acknowledged the accepted revision.")
	place(editor, 62)
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 62, "A changed pending revision was not staged.")
	preferences.default_slot = 2
	editor.begin_draft()
	TEST_ASSERT(store.write_pending && editor.save_error, "A slot switch concealed the failed account write.")
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(2), "A slot switch staged an untouched character.")
	store.fail_writes = FALSE
	store.next_write_at = world.time
	TEST_ASSERT(editor.commit_draft(), "Retry from the new slot did not finish the old account write.")
	TEST_ASSERT_EQUAL(store.last_written["character1"]["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 62, "Recovery wrote an older pending revision.")
	TEST_ASSERT(!store.write_pending && !editor.save_error, "Recovery retained false pending/error state.")
	preferences.default_slot = 1
	editor.begin_draft()
	store.path = null
	preferences.remove_cyborg_layout_slot(1)
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(1), "Deleting a slot kept a staged revision.")
	TEST_ASSERT_NULL(editor.draft, "Deleting a slot retained its editor draft.")
	editor.begin_draft()
	place(editor, 63)
	editor.commit_draft()
	TEST_ASSERT_EQUAL(length(preferences.read_cyborg_layout(1)["model_defaults"]), 0, "A reused slot resurrected the previous staged library.")
	// This is the same discard/wipe ownership sequence used by import replacement.
	editor.discard_draft()
	store.wipe()
	var/list/future = list("schema_version" = CYBORG_LAYOUT_SCHEMA_VERSION + 1, "future" = list("untouched" = 79))
	store.set_entry("character1", future)
	TEST_ASSERT_NULL(editor.begin_draft(), "Future-schema replacement was opened as a current draft.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1), future, "Future-schema replacement was rewritten.")
	TEST_ASSERT_EQUAL(future["future"]["untouched"], 79, "Future-schema replacement lost opaque data.")

/// Each character's setups have one byte limit. Copies that would pass it are refused up front; edits that pass it stay
/// unsaved, and only edits that shrink the slot go through until it fits again.
/datum/unit_test/cyborg_slot_limit
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_slot_limit/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/json_savefile/cyborg_customization/store = editor.preferences.cyborg_layout_store()
	var/list/draft = editor.draft.Copy()
	draft["active"] = full_depth_layout()
	editor.update_draft(draft)
	TEST_ASSERT(editor.commit_draft(), "The fullest single layout did not fit its character's limit.")
	var/staged = store.get_entry("character1")
	TEST_ASSERT(length(staged) <= CYBORG_LAYOUT_MAX_SLOT_BYTES, "A slot past the limit was staged.")
	TEST_ASSERT(length(staged) * 2 < length(json_encode(cyborg_layout_normalize(draft))), "Save text for the fullest layout is not under half the nested tree.")
	command(editor, list("operation" = "save", "name" = "Gamma"))
	TEST_ASSERT(!("Gamma" in editor.draft["presets"]) && findtext(editor.status_message, "limit"), "A preset that would pass the limit was saved.")
	// Edits past the limit stay unsaved until the slot shrinks.
	draft = editor.draft.Copy()
	var/list/presets = draft["presets"]
	draft["presets"] = presets.Copy()
	draft["presets"]["Gamma"] = full_depth_layout()
	editor.update_draft(draft)
	TEST_ASSERT(!editor.commit_draft(), "A slot past the limit was acknowledged.")
	TEST_ASSERT(editor.full_message == cyborg_layout_slot_full_message() && editor.save_error == editor.full_message, "The editor did not say the slot is full.")
	TEST_ASSERT_EQUAL(store.get_entry("character1"), staged, "A slot past the limit replaced its last save.")
	var/revision = editor.draft_revision
	place(editor, 9)
	TEST_ASSERT_EQUAL(editor.draft_revision, revision, "An edit that adds data went through on a full slot.")
	command(editor, list("operation" = "delete", "name" = "Gamma"))
	TEST_ASSERT(!editor.full_message && !editor.save_error && !editor.dirty, "Shrinking the slot under the limit did not save it.")
	TEST_ASSERT(!("Gamma" in editor.preferences.read_cyborg_layout(1)["presets"]), "The deletion was not saved.")

/// All of an account's characters share one limit. A character that would pass it is not staged and the file keeps its
/// last good contents until there is room; save() refuses a bigger tree whatever put it there.
/datum/unit_test/cyborg_sidecar_size_limit
	parent_type = /datum/unit_test/cyborg_storage_fixture
	var/sidecar_path = "data/cyborg_sidecar_size_limit_test.json"

/datum/unit_test/cyborg_sidecar_size_limit/Destroy()
	// After the parent, so the store's final flush can't write the file again.
	. = ..()
	fdel(sidecar_path)

/datum/unit_test/cyborg_sidecar_size_limit/Run()
	fdel(sidecar_path)
	var/datum/preference_middleware/cyborg_character/editor = make_editor(sidecar_path)
	var/datum/preferences/preferences = editor.preferences
	var/datum/json_savefile/cyborg_customization/store = preferences.cyborg_layout_savefile
	var/written = rustg_file_read(sidecar_path)
	TEST_ASSERT(length(written) && !editor.save_error, "A sidecar under the limit was not written.")
	// Another character already fills the account.
	store.set_entry("character2", oversized_text())
	place(editor, 51)
	TEST_ASSERT(!editor.commit_draft(), "A character was staged past the account limit.")
	TEST_ASSERT(editor.full_message == cyborg_layout_account_full_message() && editor.save_error == editor.full_message, "The editor did not say the account is full.")
	var/revision = editor.draft_revision
	place(editor, 52)
	TEST_ASSERT_EQUAL(editor.draft_revision, revision, "An edit that adds data went through on a full account.")
	TEST_ASSERT(!store.save() && store.write_oversized, "save() wrote an account past the limit.")
	TEST_ASSERT(rustg_file_read(sidecar_path) == written, "A refused account changed the file on disk.")
	// Deleting the other character makes room.
	store.next_write_at = world.time
	TEST_ASSERT(preferences.remove_cyborg_layout_slot(2), "Removing the other character did not save.")
	store.next_write_at = world.time
	TEST_ASSERT(editor.commit_draft() && !editor.full_message && !editor.save_error, "The character did not save once the account had room.")
	var/list/on_disk = json_decode(rustg_file_read(sidecar_path))
	TEST_ASSERT(!("character2" in on_disk), "The deleted character is still on disk.")
	TEST_ASSERT_EQUAL(cyborg_layout_decode(on_disk["character1"])["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 51, "The edit made while the account was full was lost.")

/// A sidecar already past the limit on disk is neither decoded nor written over, and the editor says why.
/datum/unit_test/cyborg_sidecar_refuses_oversized_file
	parent_type = /datum/unit_test/cyborg_storage_fixture
	var/sidecar_path = "data/cyborg_sidecar_oversized_file_test.json"

/datum/unit_test/cyborg_sidecar_refuses_oversized_file/Destroy()
	. = ..()
	fdel(sidecar_path)

/datum/unit_test/cyborg_sidecar_refuses_oversized_file/Run()
	var/oversized = json_encode(list("character1" = oversized_text()))
	TEST_ASSERT(!length(rustg_file_write(oversized, sidecar_path)), "The oversized fixture could not be written.")
	var/datum/json_savefile/cyborg_customization/probe = new(sidecar_path)
	var/decoded = !isnull(probe.get_entry("character1"))
	var/refused = probe.read_refused
	qdel(probe)
	TEST_ASSERT(refused && !decoded, "An oversized sidecar was decoded.")
	var/datum/preference_middleware/cyborg_character/editor = make_editor(sidecar_path)
	var/datum/json_savefile/cyborg_customization/store = editor.preferences.cyborg_layout_savefile
	TEST_ASSERT(store.write_error() && editor.save_error == store.write_error(), "The editor did not say the saved setups are too big to load.")
	var/revision = editor.draft_revision
	place(editor, 71)
	TEST_ASSERT_EQUAL(editor.draft_revision, revision, "An edit went through on setups that could not be loaded.")
	TEST_ASSERT(!store.save(), "A store that refused its file wrote over it.")
	TEST_ASSERT(rustg_file_read(sidecar_path) == oversized, "Refusing an oversized sidecar changed it on disk.")

/// A character keeps at most CYBORG_LAYOUT_MAX_MODEL_DEFAULTS model defaults. Replacing one stays allowed, and an
/// import past the limit keeps the first ones.
/datum/unit_test/cyborg_model_defaults_limit
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_model_defaults_limit/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/list/catalog = cyborg_model_catalog()
	TEST_ASSERT(length(catalog) > CYBORG_LAYOUT_MAX_MODEL_DEFAULTS, "The catalog is too small to reach the model default limit.")
	var/list/draft = editor.draft.Copy()
	var/list/defaults = draft["model_defaults"]
	defaults = defaults.Copy()
	draft["model_defaults"] = defaults
	var/spare_model
	for(var/model_id in catalog)
		if(defaults[model_id])
			continue
		if(length(defaults) >= CYBORG_LAYOUT_MAX_MODEL_DEFAULTS)
			spare_model = model_id
			break
		defaults[model_id] = cyborg_layout_copy(draft["active"])
	editor.update_draft(draft)
	editor.preview_model = spare_model
	var/limit_message = "This character already has [CYBORG_LAYOUT_MAX_MODEL_DEFAULTS] model defaults. Delete one first."
	command(editor, list("operation" = "save_default"))
	TEST_ASSERT(!editor.draft["model_defaults"][spare_model] && editor.status_message == limit_message, "A model default past the limit was saved.")
	command(editor, list("operation" = "assign_default", "name" = "Alpha"))
	TEST_ASSERT(!editor.draft["model_defaults"][spare_model] && editor.status_message == limit_message, "Assigning a preset added a model default past the limit.")
	// Replacing a default the character already has adds no entry, so the limit allows it.
	editor.preview_model = model_b
	command(editor, list("operation" = "set", "slot" = "penis", "field" = "sprite_size", "value" = 5))
	command(editor, list("operation" = "save_default"))
	TEST_ASSERT_EQUAL(editor.draft["model_defaults"][model_b]["penis"]["sprite_size"], 5, "Replacing an existing model default was refused at the limit.")
	var/list/raw = cyborg_layout_default()
	for(var/model_id in catalog)
		raw["model_defaults"][model_id] = cyborg_layout_default_slots()
	var/list/normalized = cyborg_layout_normalize(raw)
	TEST_ASSERT_EQUAL(length(normalized["model_defaults"]), CYBORG_LAYOUT_MAX_MODEL_DEFAULTS, "Loading kept more model defaults than the limit.")
	TEST_ASSERT_EQUAL(normalized["model_defaults"][1], catalog[1], "Loading past the limit did not keep the first model defaults.")

/// An import replaces every character's layouts: the old ones go, and one too big for its character is left out.
/datum/unit_test/cyborg_import_replaces_old_layouts
	parent_type = /datum/unit_test/cyborg_storage_fixture
	var/account_path = "data/player_saves/c/cyborgimportlimittest/"

/datum/unit_test/cyborg_import_replaces_old_layouts/Destroy()
	. = ..()
	fdel(account_path)

/datum/unit_test/cyborg_import_replaces_old_layouts/Run()
	var/sidecar_path = "[account_path]cyborg_customization.json"
	var/list/old = cyborg_layout_default()
	old["active"]["penis"]["pixel_x"] = 3
	var/old_text = cyborg_layout_encode(old)
	TEST_ASSERT(!length(rustg_file_write(json_encode(list("character1" = old_text, "character3" = old_text)), sidecar_path)), "The old layouts could not be written.")
	var/list/fitting = cyborg_layout_default()
	fitting["active"]["penis"]["pixel_x"] = 5
	var/list/too_big = cyborg_layout_default()
	too_big["active"] = full_depth_layout()
	too_big["presets"]["Copy"] = full_depth_layout()
	cyborg_customization_after_import("cyborgimportlimittest", list("character1" = cyborg_layout_normalize(fitting), "character2" = cyborg_layout_normalize(too_big)))
	var/list/on_disk = json_decode(rustg_file_read(sidecar_path))
	TEST_ASSERT_EQUAL(cyborg_layout_decode(on_disk["character1"])["active"]["penis"]["pixel_x"], 5, "The imported layout was not written.")
	TEST_ASSERT(!("character2" in on_disk), "A layout past its character's limit was imported.")
	TEST_ASSERT(!("character3" in on_disk), "An old layout stayed behind for a character the import replaced.")
	// Characters past the limit they all share are left out too, and the file stays under it.
	var/list/many = list()
	for(var/slot_number in 1 to 50)
		var/list/layout = cyborg_layout_default()
		layout["active"] = full_depth_layout()
		many["character[slot_number]"] = cyborg_layout_normalize(layout)
	cyborg_customization_after_import("cyborgimportlimittest", many)
	var/list/kept = json_decode(rustg_file_read(sidecar_path))
	TEST_ASSERT(length(kept) && length(kept) < 50, "Importing past the account limit kept [length(kept)] of 50 characters.")
	TEST_ASSERT(length(file(sidecar_path)) <= CYBORG_LAYOUT_MAX_SIDECAR_BYTES, "An import wrote a file past the account limit.")
	cyborg_customization_after_import("cyborgimportlimittest", list("character2" = cyborg_layout_normalize(too_big)))
	TEST_ASSERT(!fexists(sidecar_path), "Old layouts stayed behind when every imported layout was too big.")
