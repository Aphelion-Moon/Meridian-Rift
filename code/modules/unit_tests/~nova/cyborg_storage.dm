/// Independent staged snapshots retain mutable-input and failure/lifecycle isolation.
/datum/unit_test/cyborg_storage_fixture
	parent_type = /datum/unit_test/cyborg_mock_preferences
	abstract_type = /datum/unit_test/cyborg_storage_fixture
	var/model_a
	var/model_b

/datum/unit_test/cyborg_storage_fixture/proc/make_editor()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = allocate(/datum/json_savefile/cyborg_customization/review_failure_store, null)
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

/// Recopying the whole independent library for a six-part edit fails the work-bound assertion.
/datum/unit_test/cyborg_incremental_stage_reuses_only_owned_snapshots
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_incremental_stage_reuses_only_owned_snapshots/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/list/before = preferences.read_cyborg_layout(1)
	var/before_json = json_encode(before)
	place(editor, 29)
	TEST_ASSERT(editor.commit_draft(), "Canonical placement did not stage successfully.")
	var/list/after = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(after["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 29, "Staging lost the accepted placement.")
	TEST_ASSERT_EQUAL(json_encode(before), before_json, "Staging mutated the previous owned snapshot.")
	TEST_ASSERT_EQUAL(json_encode(after), json_encode(editor.draft), "Incremental staging changed accepted values or index order.")
	TEST_ASSERT(after["active"] != editor.draft["active"], "The active snapshot aliases the mutable draft.")
	TEST_ASSERT(after["model_defaults"][model_b] != editor.draft["model_defaults"][model_b], "A saved default aliases the mutable draft.")
	TEST_ASSERT_EQUAL(after["model_defaults"][model_b], before["model_defaults"][model_b], "A minimal canonical edit recopied the unchanged saved default library.")
	TEST_ASSERT_EQUAL(after["presets"]["Beta"], before["presets"]["Beta"], "A minimal canonical edit recopied an unchanged owned preset.")
	// A held draft list must still be independent after an incremental stage.
	editor.draft["active"]["penis"]["placement_groups"]["south"]["pixel_x"] = 99
	editor.draft["model_defaults"][model_b]["penis"]["pixel_x"] = 99
	TEST_ASSERT_EQUAL(after["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 29, "Later mutable active input changed the staged revision.")
	TEST_ASSERT_EQUAL(after["model_defaults"][model_b]["penis"]["pixel_x"], 33, "Later mutable default input changed the staged revision.")

/// Missing a library key when preset overwrite propagates would retain old saved geometry.
/datum/unit_test/cyborg_incremental_library_actions
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_incremental_library_actions/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/list/original = preferences.read_cyborg_layout(1)
	var/original_json = json_encode(original)
	place(editor, 41)
	command(editor, list("operation" = "save", "name" = "Alpha", "overwrite" = TRUE))
	var/list/saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["presets"]["Alpha"]["penis"]["placement_groups"]["south"]["pixel_x"], 41, "Preset overwrite missed its changed snapshot.")
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_a]["penis"]["placement_groups"]["south"]["pixel_x"], 41, "Preset overwrite missed its assigned default snapshot.")
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_b]["penis"]["pixel_x"], 33, "Preset overwrite changed an unrelated default.")
	TEST_ASSERT_EQUAL(json_encode(original), original_json, "Preset overwrite changed an older staged tree.")
	command(editor, list("operation" = "assign_default", "name" = "Beta"))
	saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["model_defaults"][model_a]["penis"]["pixel_x"], 17, "Assigning a preset did not copy its default.")
	TEST_ASSERT(saved["presets"]["Beta"] != saved["model_defaults"][model_a], "Assigned preset and default lost their independent snapshots.")
	command(editor, list("operation" = "delete", "name" = "Alpha"))
	command(editor, list("operation" = "save", "name" = "Alpha"))
	saved = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(saved["presets"][1], "Beta", "Delete/re-add changed the current preset order.")
	TEST_ASSERT_EQUAL(saved["presets"][2], "Alpha", "Re-added preset was not staged at its current index.")
	command(editor, list("operation" = "load", "name" = "Beta"))
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 17, "Loading a preset did not copy the new active layout.")
	for(var/operation in list("reset_position", "reset_colors", "reset_overrides", "reset", "save_default", "load_default", "delete_default"))
		var/list/before = preferences.read_cyborg_layout(1)
		var/before_json = json_encode(before)
		command(editor, list("operation" = operation, "slot" = "penis"))
		editor.commit_draft()
		var/list/after = preferences.read_cyborg_layout(1)
		TEST_ASSERT_EQUAL(json_encode(after), json_encode(editor.draft), "[operation] was incompletely staged.")
		TEST_ASSERT_EQUAL(json_encode(before), before_json, "[operation] changed the previous staged snapshot.")
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(1)["model_defaults"][model_a], "Deleting the selected default left its staged snapshot.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 33, "Library actions lost an unrelated default.")

/// Raw mutable updates and public writes must never use canonical-action reuse assumptions.
/datum/unit_test/cyborg_incremental_stage_raw_fallback
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_incremental_stage_raw_fallback/Run()
	var/datum/preference_middleware/cyborg_character/editor = make_editor()
	var/datum/preferences/preferences = editor.preferences
	var/list/raw = editor.begin_draft()
	raw["model_defaults"][model_b]["penis"]["pixel_x"] = 45
	raw["extra_root"] = list("nested" = list("value" = 19))
	raw["preset_models"]["extra_metadata"] = list("value" = 23)
	editor.update_draft(raw)
	// A later canonical action must not erase the outstanding full-copy requirement.
	place(editor, 51)
	editor.commit_draft()
	var/list/first = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(first["model_defaults"][model_b]["penis"]["pixel_x"], 45, "Canonical follow-up lost the prior raw mutable library update.")
	place(editor, 52)
	editor.commit_draft()
	var/list/second = preferences.read_cyborg_layout(1)
	var/second_json = json_encode(second)
	editor.draft["extra_root"]["nested"]["value"] = 99
	editor.draft["preset_models"]["extra_metadata"]["value"] = 99
	TEST_ASSERT_EQUAL(second["extra_root"]["nested"]["value"], 19, "Extra root data became aliased after incremental staging.")
	TEST_ASSERT_EQUAL(second["preset_models"]["extra_metadata"]["value"], 23, "Nested metadata became aliased after incremental staging.")
	var/list/external = cyborg_layout_default()
	external["model_defaults"][model_b] = cyborg_layout_default_slots()
	external["model_defaults"][model_b]["penis"]["pixel_x"] = 66
	preferences.write_cyborg_layout(2, external)
	TEST_ASSERT_EQUAL(editor.staged_snapshot, second, "Writing another slot released the active slot's staging baseline.")
	preferences.write_cyborg_layout(1, external)
	TEST_ASSERT_NULL(editor.staged_snapshot, "External slot replacement retained the obsolete staged tree.")
	TEST_ASSERT(editor.snapshot_requires_full_copy, "External slot replacement retained incremental reuse permission.")
	external["model_defaults"][model_b]["penis"]["pixel_x"] = 88
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 66, "The public writer aliased raw mutable input.")
	place(editor, 53)
	editor.commit_draft()
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["model_defaults"][model_b]["penis"]["pixel_x"], 45, "External slot replacement reused an incompatible staging baseline.")
	TEST_ASSERT_EQUAL(json_encode(second), second_json, "External replacement or a new stage changed the retained old snapshot.")

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
	var/list/failed_stage = preferences.read_cyborg_layout(1)
	var/list/external = cyborg_layout_default()
	external["active"]["penis"]["pixel_x"] = 73
	store.fail_writes = FALSE
	store.next_write_at = world.time
	TEST_ASSERT(preferences.write_cyborg_layout(1, external), "The external replacement did not save.")
	TEST_ASSERT(editor.dirty && editor.saved_revision != pending_revision, "An external replacement falsely acknowledged the superseded editor revision.")
	TEST_ASSERT_EQUAL(editor.staged_revision, -1, "External replacement retained the superseded staging revision.")
	TEST_ASSERT_NULL(editor.staged_snapshot, "External replacement retained the superseded snapshot.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 73, "The external replacement was silently overwritten.")
	store.next_write_at = world.time
	TEST_ASSERT(editor.commit_draft(), "The next editor commit did not save the retained draft.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 71, "The next editor commit lost its retained accepted revision.")
	TEST_ASSERT(!editor.dirty && editor.saved_revision == pending_revision, "The retained revision was not acknowledged after it actually saved.")
	TEST_ASSERT_EQUAL(failed_stage["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 71, "External replacement mutated the retained failed snapshot.")

/// Root and sprite callbacks must publish new draft roots before staging can track revisions.
/datum/unit_test/cyborg_incremental_stage_model_sprite_callbacks
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_incremental_stage_model_sprite_callbacks/Run()
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
	TEST_ASSERT_EQUAL(after_sprite["model_defaults"][model_b], staged_before["model_defaults"][model_b], "A sprite-only change recopied an unrelated saved library.")
	TEST_ASSERT_EQUAL(after_sprite["model_defaults"][model_b]["penis"]["sprite"], "Dogborg Knotted", "Sprite selection mutated a saved default.")

/// A newer accepted stage must survive failed I/O, slot changes, deletion and future-schema replacement.
/datum/unit_test/cyborg_incremental_stage_failure_slot_lifecycle
	parent_type = /datum/unit_test/cyborg_storage_fixture

/datum/unit_test/cyborg_incremental_stage_failure_slot_lifecycle/Run()
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
	var/list/failed_stage = preferences.read_cyborg_layout(1)
	var/failed_json = json_encode(failed_stage)
	place(editor, 62)
	editor.commit_draft()
	var/list/latest_stage = preferences.read_cyborg_layout(1)
	TEST_ASSERT_EQUAL(latest_stage["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 62, "A changed pending revision was not staged.")
	TEST_ASSERT_EQUAL(json_encode(failed_stage), failed_json, "A later pending edit changed the already failed revision.")
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
