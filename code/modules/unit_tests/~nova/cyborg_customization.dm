/// Focused tests for the bounded cyborg layout contract.

/// Inject a staging failure through the same native seam used by the editor.
/datum/preferences/cyborg_save_failure_test
	parent_type = /datum/preferences/preferences_import_test
	var/fail_layout_stage = FALSE

/datum/preferences/cyborg_save_failure_test/write_preference(datum/preference/preference, preference_value)
	if(fail_layout_stage && istype(preference, /datum/preference/cyborg_layout))
		return FALSE
	return ..()

/datum/unit_test/cyborg_save_failure_retains_draft
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_save_failure_retains_draft/Run()
	var/datum/preferences/cyborg_save_failure_test/preferences = create_preferences(preference_type = /datum/preferences/cyborg_save_failure_test)
	var/datum/json_savefile/save_result_test/store = allocate(/datum/json_savefile/save_result_test, null)
	preferences.savefile = store
	preferences.default_slot = 1
	preferences.max_save_slots = 3
	preferences.value_cache = list()
	store.set_entry("character1", list("version" = 52))
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 19
	editor.update_draft(draft)
	var/context = editor.context_generation
	var/revision = editor.draft_revision
	preferences.fail_layout_stage = TRUE
	TEST_ASSERT(!editor.commit_draft(), "Injected staging failure was acknowledged.")
	TEST_ASSERT(editor.dirty && editor.draft && editor.save_error, "Staging failure lost its retryable draft.")
	preferences.fail_layout_stage = FALSE
	store.path = "unused_cyborg_write_failure.json"
	TEST_ASSERT(!editor.commit_draft(), "Injected disk write failure was acknowledged.")
	TEST_ASSERT(editor.dirty && editor.draft == draft, "Write failure discarded the owned draft.")
	TEST_ASSERT_EQUAL(preferences.load_character(2), PREFERENCES_LOAD_ABORTED, "Direct slot load did not veto the failed save.")
	preferences.switch_to_slot(2)
	TEST_ASSERT_EQUAL(preferences.default_slot, 1, "Failed save changed the character slot.")
	TEST_ASSERT_NULL(store.get_entry("character2"), "An aborted slot change initialized a missing character.")
	store.forced_result = ""
	TEST_ASSERT(editor.commit_draft(), "Retry after write recovery failed.")
	TEST_ASSERT(!editor.dirty && !editor.save_error, "Successful retry did not clear pending/error state.")
	TEST_ASSERT_EQUAL(editor.saved_revision, revision, "Retry acknowledged the wrong revision.")
	TEST_ASSERT_EQUAL(store.get_entry("character1")["silicon_genital_layout_presets"]["active"]["penis"]["pixel_x"], 19, "Retry lost accepted placement data.")
	draft["active"]["penis"]["pixel_x"] = 21
	editor.update_draft(draft)
	editor.before_character_save()
	draft["active"]["penis"]["pixel_x"] = 22
	editor.update_draft(draft)
	editor.after_preferences_save(JSON_SAVE_WRITTEN)
	TEST_ASSERT(editor.dirty, "An older staged revision acknowledged a newer edit.")
	editor.on_character_replaced()
	editor.flush_timer(1, context, revision)
	TEST_ASSERT_NULL(editor.draft, "A stale timer resurrected replaced data.")
	TEST_ASSERT_NULL(editor.draft_timer, "Replacement retained an old callback.")
	store.path = null
	draft = editor.begin_draft()
	editor.update_draft(draft)
	TEST_ASSERT_EQUAL(editor.commit_draft(), JSON_SAVE_SESSION_ONLY, "Memory-only preference mode must remain usable.")
	TEST_ASSERT(editor.session_only && !editor.dirty, "Memory-only result claimed durable saving or remained stuck.")

/datum/unit_test/cyborg_targeted_placement/Run()
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/store = cyborg_layout_default()
	var/list/entry = store["active"]["penis"]
	entry["advanced"]["west"] = list("visible" = FALSE, "pixel_x" = 12, "pixel_y" = -4, "scale" = 1.5, "arousal" = list("full" = list("pixel_y" = 8)))
	store["presets"]["Original"] = deep_copy_list(store["active"])
	var/list/command = list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "pose", "direction" = "west", "pose" = "rest"), "changes" = list("pixel_x" = 0, "pixel_y" = 3))
	var/list/result = cyborg_layout_action(store, command, model_id)
	var/list/next = result["store"]
	TEST_ASSERT(next, "A valid atomic placement was rejected.")
	var/list/pose = next["active"]["penis"]["advanced"]["rest_west"]
	TEST_ASSERT_EQUAL(pose["pixel_x"], 0, "An explicit zero correction was lost or mirrored.")
	TEST_ASSERT_EQUAL(pose["pixel_y"], 3, "Atomic placement lost its other coordinate.")
	TEST_ASSERT_EQUAL(pose["scale"], 1.5, "First pose edit failed to materialize the direction fallback.")
	TEST_ASSERT_EQUAL(pose["visible"], FALSE, "First edit lost explicit false visibility.")
	TEST_ASSERT_EQUAL(pose["arousal"]["full"]["pixel_y"], 8, "First edit lost inherited arousal overrides.")
	TEST_ASSERT_NULL(entry["advanced"]["rest_west"], "Mutation changed the input store.")
	TEST_ASSERT_NULL(next["presets"]["Original"]["penis"]["advanced"]["rest_west"], "Mutation changed a saved preset.")
	command["changes"] = list("pixel_x" = 5, "pixel_y" = list("nested" = 2))
	TEST_ASSERT_NULL(cyborg_layout_action(next, command, model_id)["store"], "Malformed multi-field input partially applied.")
	TEST_ASSERT_EQUAL(pose["pixel_x"], 0, "Rejected input mutated the existing store.")
	command["target"]["scope"] = "arousal"
	command["target"]["arousal"] = "full"
	command["changes"] = list("pixel_x" = 9)
	next = cyborg_layout_action(next, command, model_id)["store"]
	pose = next["active"]["penis"]["advanced"]["rest_west"]
	TEST_ASSERT_EQUAL(pose["pixel_x"], 0, "Arousal edit changed the pose correction.")
	TEST_ASSERT_EQUAL(pose["arousal"]["full"]["pixel_y"], 8, "Arousal edit erased an unrelated field.")
	command["operation"] = "inherit_placement"
	command -= "changes"
	next = cyborg_layout_action(next, command, model_id)["store"]
	TEST_ASSERT_NULL(next["active"]["penis"]["advanced"]["rest_west"]["arousal"]["full"], "Inherit did not remove the addressed arousal override.")
	TEST_ASSERT_EQUAL(next["active"]["penis"]["advanced"]["west"]["pixel_x"], 12, "Inherit changed the direction fallback.")
	command = list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = WEST), "changes" = list("pixel_x" = 10, "scale" = 1.5))
	next = cyborg_layout_action(next, command, model_id)["store"]
	TEST_ASSERT_EQUAL(next["active"]["penis"]["scale"], 1.5, "Part scale became specific to a direction group.")
	TEST_ASSERT_EQUAL(next["active"]["penis"]["placement_groups"]["side"]["pixel_x"], 10, "The server did not derive the wide side group.")

/// Keep mock connections out of real registries and detach them on every exit path.
/datum/unit_test/cyborg_mock_preferences
	abstract_type = /datum/unit_test/cyborg_mock_preferences
	var/list/previous_preferences
	var/list/previous_directory
	var/list/previous_persistent_clients
	var/list/previous_persistent_client_list

/datum/unit_test/cyborg_mock_preferences/New()
	..()
	previous_preferences = GLOB.preferences_datums
	previous_directory = GLOB.directory
	previous_persistent_clients = GLOB.persistent_clients_by_ckey
	previous_persistent_client_list = GLOB.persistent_clients
	GLOB.preferences_datums = list()
	GLOB.directory = list()
	GLOB.persistent_clients_by_ckey = list()
	GLOB.persistent_clients = list()

/datum/unit_test/cyborg_mock_preferences/Destroy()
	// A deleted mob keeps its mock_client field; unlike a real /client this is
	// a strong datum reference. Detach before either side enters the GC queue.
	for(var/mob/mob in allocated)
		mob.mock_client = null
	for(var/datum/client_interface/mock_client in allocated)
		mock_client.mob = null
		mock_client.prefs = null
	. = ..()
	GLOB.preferences_datums = previous_preferences
	GLOB.directory = previous_directory
	GLOB.persistent_clients_by_ckey = previous_persistent_clients
	GLOB.persistent_clients = previous_persistent_client_list
	previous_preferences = null
	previous_directory = null
	previous_persistent_clients = null
	previous_persistent_client_list = null

/datum/unit_test/cyborg_mock_preferences/proc/create_preferences(mob/living/silicon/robot/robot, preference_type = /datum/preferences/preferences_import_test)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	// Reuse the native memory-only preference fixture and its parent-link teardown.
	var/datum/preferences/preferences = allocate(preference_type, mock_client)
	mock_client.prefs = preferences
	if(robot)
		robot.mock_client = mock_client
		mock_client.mob = robot
	return preferences

/datum/unit_test/cyborg_interaction_and_runtime_owner_gate
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_future_layout_apply_preserves_raw_data
	parent_type = /datum/unit_test/cyborg_mock_preferences

/// Exercise the creator protocol and real preference save hooks, without a UI client.
/// Removing either the slot guard or close-time flush must break this regression.
/datum/unit_test/cyborg_creator_draft_lifecycle
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_model_default_parts_and_runtime_usage
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_model_default_parts_and_runtime_usage/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
	preferences.default_slot = 2
	preferences.savefile.remove_entry("character2")
	preferences.value_cache -= /datum/preference/cyborg_layout
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/datum/preference_middleware/cyborg_character/middleware = preferences.cyborg_session()
	middleware.page_active = TRUE
	middleware.preview_model = model_id
	TEST_ASSERT(middleware.edit_layout(list("operation" = "save_default", "character_slot" = 2, "context" = middleware.context_generation), robot), "Saving a model default must succeed.")
	var/list/store = preferences.read_preference(/datum/preference/cyborg_layout)
	TEST_ASSERT_EQUAL(store["model_defaults"][model_id]["penis"]["sprite"], "Dogborg Knotted", "Model defaults must snapshot sprite choices.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], SPRITE_ACCESSORY_NONE)
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/engineering(robot)
	robot.model.cyborg_customization_skin = "Drake"
	var/list/descriptor = cyborg_model_catalog()[model_id]
	robot.model.cyborg_base_icon = descriptor["icon_state"]
	robot.model.cyborg_icon_override = descriptor["icon"]
	robot.icon = descriptor["icon"]
	robot.icon_state = descriptor["icon_state"]
	apply_cyborg_customization(robot, preferences, "spawn")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_choices["penis"], "Dogborg Knotted", "Spawn must restore the model's saved sprite instead of the current None preference.")
	TEST_ASSERT(robot.cyborg_appearance_active["penis"], "A configured part must start active on a new body.")
	TEST_ASSERT(length(robot.cyborg_appearance_holder.render_layers), "The configured model must produce native render layers on spawn.")
	var/list/runtime_data = robot.cyborg_runtime_data()
	TEST_ASSERT_NULL(runtime_data["store"], "Runtime data must not expose editable saved layouts.")
	TEST_ASSERT(length(runtime_data["parts"]), "Runtime controls must list configured parts.")
	var/before = json_encode(robot.cyborg_appearance_layout)
	TEST_ASSERT(!robot.cyborg_runtime_action(list("operation" = "place", "slot" = "penis", "x" = 100, "y" = 100, "character_slot" = 2, "context" = middleware.context_generation), robot), "Runtime placement must be rejected server-side.")
	TEST_ASSERT_EQUAL(json_encode(robot.cyborg_appearance_layout), before, "Rejected runtime editing must leave layout untouched.")
	TEST_ASSERT(robot.cyborg_runtime_action(list("operation" = "activate", "slot" = "penis", "value" = FALSE, "character_slot" = 2, "context" = middleware.context_generation), robot), "Usage controls must allow hiding configured parts.")
	apply_cyborg_customization(robot, preferences, "login")
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "Reconnect must preserve an explicit hidden state.")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_choices["penis"], "Dogborg Knotted", "Reconnect must preserve the model's saved sprite.")
	TEST_ASSERT(middleware.edit_layout(list("operation" = "load_default", "character_slot" = 2, "context" = middleware.context_generation), robot), "Creator must load the saved default.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/cyborg_sprite/penis), "Dogborg Knotted", "Loading a default must restore the sprite selector too.")

/datum/unit_test/cyborg_creator_draft_lifecycle/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.value_cache = list()
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	TEST_ASSERT(cyborg_visuals_allowed(preferences), "The creator fixture requires enabled ERP configuration and character consent.")
	var/datum/preference_middleware/cyborg_character/editor = locate() in preferences.middleware
	TEST_ASSERT(editor, "The character creator middleware was not registered on real preferences.")
	TEST_ASSERT(!length(editor.get_ui_data(null)), "A closed creator eagerly generated preview data.")
	var/list/pending = preferences.cyborg_session().begin_draft()
	preferences.cyborg_session().update_draft(pending)
	var/pending_timer = preferences.cyborg_session().draft_timer
	editor.set_page(list("active" = FALSE), null)
	TEST_ASSERT_EQUAL(preferences.cyborg_session().draft_timer, pending_timer, "A redundant inactive-page message flushed a draft owned by another interface.")
	preferences.cyborg_session().discard_draft("creator_fixture")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	for(var/cycle in 1 to 3)
		TEST_ASSERT(editor.set_page(list("active" = TRUE), null), "Opening the creator was rejected.")
		TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = model_id, "direction" = NORTH), null), "Selecting a valid creator model was rejected.")
		var/list/payload = editor.get_ui_data(null)["cyborg_customization"]
		TEST_ASSERT_NULL(payload["body"], "Ordinary UI updates must not retransmit chassis images.")
		if(cycle == 1)
			TEST_NOTICE(src, "Creator payload JSON characters: dynamic [length(json_encode(payload))], private resources [length(json_encode(editor.preview_resources))]. Closed gallery, Drake north, default parts.")
		payload += editor.get_ui_static_data(null)["cyborg_resources"]
		var/list/resources_before = editor.preview_resources
		TEST_ASSERT_EQUAL(payload["model"], model_id, "The preview did not select the requested canonical model.")
		TEST_ASSERT_EQUAL(payload["direction"], NORTH, "The preview did not select the requested cardinal direction.")
		TEST_ASSERT(findtext(payload["body"], "iVBORw0KGgo") == 1, "The creator did not return a PNG body preview.")
		TEST_ASSERT(!length(payload["layers"]), "Default None choices produced visual layers.")
		for(var/list/model_preview as anything in payload["models"])
			TEST_ASSERT_NULL(model_preview["thumbnail"], "Closed galleries must not render every model thumbnail on each layout edit.")
			TEST_ASSERT_NULL(model_preview["thumbnail_directions"], "Closed galleries must not send rotation frames.")
		TEST_ASSERT(findtext(payload["reference"], "iVBORw0KGgo") == 1, "The creator must include its fixed-size reference artwork.")
		var/list/edit = list("character_slot" = 2, "context" = editor.context_generation, "operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = NORTH), "changes" = list("pixel_x" = 99))
		TEST_ASSERT(!editor.edit_layout(edit, null), "A stale character slot was allowed to edit the current slot.")
		TEST_ASSERT_EQUAL((preferences.cyborg_session().begin_draft()["active"]["penis"]["placement_groups"]?["north"]?["pixel_x"] || 0), cycle == 1 ? 0 : cycle - 1, "A rejected stale action changed the current draft.")
		edit["character_slot"] = 1
		edit["changes"]["pixel_x"] = cycle
		TEST_ASSERT(editor.edit_layout(edit, null), "A current-slot creator edit was rejected.")
		editor.get_ui_data(null)
		TEST_ASSERT(editor.preview_resources == resources_before, "A position-only edit rebuilt static preview resources.")
		if(cycle == 1)
			preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], FALSE)
			var/list/denied = editor.get_ui_data(null)["cyborg_customization"]
			TEST_ASSERT(!denied["allowed"] && !length(denied["layers"]), "Revoking permission retained private preview layers.")
			TEST_ASSERT_NULL(editor.get_ui_static_data(null)["cyborg_resources"], "Revoking permission retained the static resource payload.")
			preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
			editor.get_ui_data(null)
			TEST_ASSERT(editor.get_ui_static_data(null)["cyborg_resources"], "Restoring permission did not restore preview resources.")
		var/stale_context = editor.context_generation - 1
		TEST_ASSERT(!editor.set_preview(list("context" = stale_context, "model" = model_id), null), "A replaced context accepted a stale model action.")
		TEST_ASSERT(preferences.cyborg_session().draft_timer, "A creator edit did not schedule persistence.")
		// Closing the whole preferences window must save even without a React unmount action.
		preferences.ui_close(null)
		TEST_ASSERT(!editor.page_active && !length(editor.get_ui_data(null)), "Closing preferences left the creator active.")
		TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Closing preferences retained a deferred write callback.")
		TEST_ASSERT(!preferences.cyborg_session().dirty, "Closing preferences left accepted edits unsaved.")
		var/list/saved = preferences.savefile.get_entry("character1")
		TEST_ASSERT_EQUAL(saved["silicon_genital_layout_presets"]["active"]["penis"]["placement_groups"]["north"]["pixel_x"], cycle, "Closing preferences lost the last creator edit.")
		TEST_ASSERT(!editor.edit_layout(edit, null), "A closed creator accepted a delayed edit.")
		TEST_ASSERT(!editor.set_preview(list("context" = editor.context_generation, "model" = model_id), null), "A closed creator accepted a delayed preview action.")

	editor.set_page(list("active" = TRUE), null)
	editor.on_character_replaced()
	var/list/future = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	preferences.savefile.set_entry("character1", list("version" = 52, "silicon_genital_layout_presets" = future))
	preferences.value_cache -= /datum/preference/cyborg_layout
	var/list/unsupported = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(unsupported["unsupported"] && length(unsupported["message"]), "A future schema did not show a read-only preservation notice in the creator.")
	preferences.ui_close(null)
	var/list/preserved = preferences.savefile.get_entry("character1")
	TEST_ASSERT(preserved["silicon_genital_layout_presets"] == future, "Closing the unsupported creator rewrote the future schema.")

/// Export must serialize pending editor state before the debounce callback runs.
/datum/unit_test/cyborg_export_includes_pending_draft
	parent_type = /datum/unit_test/cyborg_mock_preferences

/// Previewing a model default must not replace or mutate the active draft.
/datum/unit_test/cyborg_creator_model_default_preview
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_creator_model_default_preview/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.value_cache = list()
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = locate() in preferences.middleware
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	TEST_ASSERT(editor.set_page(list("active" = TRUE), null), "Opening the creator was rejected.")
	TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = model_id), null), "Selecting the model was rejected.")
	var/list/draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 7
	var/list/model_default = cyborg_layout_copy(draft["active"])
	model_default["penis"]["pixel_x"] = 31
	draft["model_defaults"][model_id] = model_default
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "The model-default fixture was not accepted.")
	var/list/payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["layout_source"], "active", "A newly opened creator must edit the active layout.")
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 7, "The active draft fixture was not retained.")
	var/pending_timer = editor.draft_timer
	TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "layout_source" = "model_default"), null), "Selecting the model-default preview was rejected.")
	payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["layout_source"], "model_default", "A saved model default was not selected for preview.")
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 7, "Previewing a model default mutated the active draft.")
	TEST_ASSERT(editor.draft_timer && editor.draft_timer != pending_timer, "Changing preview source did not reschedule its stale-context save callback.")
	deltimer(editor.draft_timer)
	editor.flush_timer(editor.draft_slot, editor.context_generation, editor.draft_revision)
	TEST_ASSERT(!editor.dirty, "Changing preview source invalidated the active draft's pending autosave.")
	var/other_model
	for(var/candidate in cyborg_catalog_for(preferences, "creator"))
		if(candidate != model_id)
			other_model = candidate
			break
	if(other_model)
		TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = other_model), null), "Changing the preview model was rejected.")
		payload = editor.get_ui_data(null)["cyborg_customization"]
		TEST_ASSERT_EQUAL(payload["layout_source"], "active", "Changing models retained a read-only model-default source.")
		TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = model_id, "layout_source" = "model_default"), null), "Returning to the model-default fixture was rejected.")
	TEST_ASSERT(editor.edit_layout(list("character_slot" = 1, "context" = editor.context_generation, "operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = NORTH), "changes" = list("pixel_x" = 99)), null), "The read-only model-default edit was not handled.")
	payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 7, "Editing a model-default preview changed the active draft.")
	TEST_ASSERT(editor.edit_layout(list("context" = editor.context_generation, "character_slot" = 1, "operation" = "delete_default"), null), "Deleting the selected model default was rejected.")
	payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["layout_source"], "active", "Deleting the selected model default did not fall back to the active source.")
	draft = preferences.cyborg_session().begin_draft()
	model_default = cyborg_layout_copy(draft["active"])
	model_default["penis"]["pixel_x"] = 31
	draft["model_defaults"][model_id] = model_default
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "The model-default fixture could not be restored.")
	TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "layout_source" = "model_default"), null), "Restoring the model-default preview was rejected.")
	TEST_ASSERT(editor.edit_layout(list("context" = editor.context_generation, "character_slot" = 1, "operation" = "load_default"), null), "Loading the selected model default was rejected.")
	payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["layout_source"], "active", "Loading a model default did not return to the editable active source.")
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 31, "Loading a model default did not copy it into the active layout.")
	editor.set_page(list("active" = FALSE), null)

/datum/unit_test/cyborg_export_includes_pending_draft/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.value_cache = list()
	var/list/draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 23
	preferences.cyborg_session().update_draft(draft)
	// No recipient exercises export preparation while skipping the file-transfer UI.
	// There is deliberately no sleep: export must contain the edit before debounce fires.
	preferences.export_to_client(null, null)
	var/list/saved = preferences.savefile.get_entry("character1")
	TEST_ASSERT_EQUAL(saved?["silicon_genital_layout_presets"]?["active"]?["penis"]?["pixel_x"], 23, "Immediate export omitted the pending creator edit from its JSON tree.")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Export left the exported edit waiting on its debounce timer.")

/// A short real-GC regression for the leak found by the full create/destroy sweep.
/datum/unit_test/cyborg_mock_preferences_cleanup
	priority = TEST_LONGER

/datum/unit_test/cyborg_mock_preferences_cleanup/Run()
	var/list/previous_directory = GLOB.directory
	var/list/previous_preferences = GLOB.preferences_datums
	var/list/previous_clients = GLOB.persistent_clients_by_ckey
	var/list/previous_client_list = GLOB.persistent_clients
	var/list/deleted_refs = create_and_dispose_fixture()
	TEST_ASSERT(GLOB.directory == previous_directory && GLOB.preferences_datums == previous_preferences, "Mock teardown replaced the original client/preference registries.")
	TEST_ASSERT(GLOB.persistent_clients_by_ckey == previous_clients && GLOB.persistent_clients == previous_client_list, "Mock teardown replaced the original persistent-client registries.")
	// Primitive identity records hold neither object alive. Use the same deletion
	// generation as SSgarbage: raw refs can be reused, and Destroy clears weakrefs
	// before native collection, making either weakref resolver unsuitable here.
	sleep(5 SECONDS)
	for(var/list/deleted_ref as anything in deleted_refs)
		var/datum/candidate = locate(deleted_ref["reference"])
		TEST_ASSERT(!candidate || candidate.type != deleted_ref["type"] || candidate.gc_destroyed != deleted_ref["destroyed_at"], "A mock client or preference survived fixture teardown and native collection.")

/datum/unit_test/cyborg_mock_preferences_cleanup/proc/create_and_dispose_fixture()
	var/datum/unit_test/cyborg_mock_preferences/fixture = new
	var/mob/living/silicon/robot/robot = fixture.allocate(/mob/living/silicon/robot)
	var/datum/preferences/preferences = fixture.create_preferences(robot)
	var/datum/client_interface/mock_client = robot.mock_client
	qdel(fixture)
	return list(
		list("reference" = text_ref(mock_client), "type" = mock_client.type, "destroyed_at" = mock_client.gc_destroyed),
		list("reference" = text_ref(preferences), "type" = preferences.type, "destroyed_at" = preferences.gc_destroyed),
	)

/datum/unit_test/cyborg_layout_schema_rejects_malformed_input/Run()
	var/list/normalized = cyborg_layout_normalize("not a layout")
	TEST_ASSERT_EQUAL(normalized["schema_version"], 1, "Malformed roots must produce the current schema.")
	TEST_ASSERT_EQUAL(length(normalized["active"]), 6, "Malformed roots must produce six safe active entries.")

	var/list/numeric_root = list(list("penis" = list("pixel_x" = 20)))
	normalized = cyborg_layout_normalize(numeric_root)
	TEST_ASSERT_EQUAL(length(normalized["active"]), 6, "Numeric root keys must not become layout slots.")

/datum/unit_test/cyborg_layout_schema_bounds_and_filters/Run()
	var/list/raw = list(
		"schema_version" = 1,
		"active" = list(
			"penis" = list(
				"pixel_x" = 999, "pixel_y" = -999, "rotation" = -999, "scale" = 999,
				"colors" = list("#ffffff", "invalid", "#000000", "#123456"),
				"advanced" = list("north" = list("priority" = 999, "arousal" = list("full" = list("scale" = 0))), "diagonal" = list("visible" = TRUE)),
			),
			"invalid_slot" = list("pixel_x" = 10),
		),
	)
	var/list/entry = cyborg_layout_normalize(raw)["active"]["penis"]
	TEST_ASSERT_EQUAL(entry["pixel_x"], 128, "Pixel X was not bounded.")
	TEST_ASSERT_EQUAL(entry["pixel_y"], -128, "Pixel Y was not bounded.")
	TEST_ASSERT_EQUAL(entry["rotation"], -180, "Rotation was not bounded.")
	TEST_ASSERT_EQUAL(entry["scale"], 2, "Scale was not bounded to the creator's 200% cap.")
	TEST_ASSERT_EQUAL(length(entry["colors"]), 3, "Colors must be fixed to three layers.")
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(list("active" = list("penis" = list("colors" = list()))))["active"]["penis"]["colors"][1], "#ffffff", "Empty color arrays must safely restore the default color.")
	TEST_ASSERT(!("diagonal" in entry["advanced"]), "An unsupported direction survived normalization.")
	TEST_ASSERT_EQUAL(entry["advanced"]["north"]["priority"], 10, "Priority was not bounded.")
	TEST_ASSERT_EQUAL(entry["advanced"]["north"]["arousal"]["full"]["scale"], 0.25, "Arousal scale was not bounded.")

/datum/unit_test/cyborg_layout_schema_copies_and_fills_slots/Run()
	var/list/raw_entry = list("pixel_x" = 12)
	var/list/raw = list("schema_version" = 1, "active" = list("penis" = raw_entry), "presets" = list("One" = list("penis" = raw_entry), "Two" = list("penis" = raw_entry)))
	var/list/normalized = cyborg_layout_normalize(raw)
	normalized["presets"]["One"]["penis"]["pixel_x"] = 42
	TEST_ASSERT_EQUAL(raw_entry["pixel_x"], 12, "Normalization mutated caller data.")
	TEST_ASSERT_EQUAL(normalized["presets"]["Two"]["penis"]["pixel_x"], 12, "Presets shared an entry alias.")
	for(var/slot in cyborg_layout_supported_slots())
		TEST_ASSERT(normalized["active"][slot], "The active [slot] entry was omitted instead of defaulted.")
		TEST_ASSERT(normalized["presets"]["One"][slot], "A preset omitted its default [slot] entry.")

/datum/unit_test/cyborg_layout_schema_rejects_unknown_versions_and_deep_input/Run()
	var/list/future = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 50)))
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(future)["active"]["penis"]["pixel_x"], 0, "Future layouts must be rejected rather than partially rewritten.")
	var/list/deep = list()
	var/list/cursor = deep
	for(var/index in 1 to 13)
		var/list/child = list()
		cursor["nested"] = child
		cursor = child
	var/list/deep_input = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 42, "ignored_deep_branch" = deep)))
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(deep_input)["active"]["penis"]["pixel_x"], 42, "Unknown deep input must be ignored without traversing or replacing known fields.")
	var/list/sequential_deep = list()
	cursor = sequential_deep
	for(var/index in 1 to 13)
		var/list/child = list()
		cursor += list(child)
		cursor = child
	var/list/sequential_input = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 24, "ignored" = sequential_deep)))
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(sequential_input)["active"]["penis"]["pixel_x"], 24, "Sequential unknown branches must be ignored without recursive traversal.")
	var/list/wide = list()
	for(var/index in 1 to 32769)
		wide += list(list())
	var/list/wide_input = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 23, "ignored" = wide)))
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(wide_input)["active"]["penis"]["pixel_x"], 23, "Wide unknown branches must be ignored without scanning every child.")
	var/list/wide_edges = list()
	for(var/index in 1 to 65537)
		wide_edges += 1
	wide_input["active"]["penis"]["ignored"] = wide_edges
	TEST_ASSERT_EQUAL(cyborg_layout_normalize(wide_input)["active"]["penis"]["pixel_x"], 23, "Unknown scalar width must be ignored without scanning every entry.")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/command = list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "pose", "direction" = "north", "pose" = "idle"), "changes" = list())
	for(var/index in 1 to 29)
		command["changes"]["unknown_[index]"] = list()
	TEST_ASSERT_NULL(cyborg_layout_action(cyborg_layout_default(), command, model_id)["store"], "Oversized targeted edits must be rejected before walking nested values.")
	command["changes"] = list("unknown" = 1)
	TEST_ASSERT_NULL(cyborg_layout_action(cyborg_layout_default(), command, model_id)["store"], "Unknown placement fields must not replace valid data.")

/datum/unit_test/cyborg_layout_import_aliases_and_future_data/Run()
	var/list/legacy_layout = list("schema_version" = 1, "active" = list("penis" = list("advanced" = list("rest" = list("pixel_x" = 9)))))
	var/list/ordinary_layout = cyborg_layout_normalize(legacy_layout)
	TEST_ASSERT(!ordinary_layout["active"]["penis"]["advanced"]["rest_north"], "Legacy pose aliases must not be expanded during ordinary load or save.")
	var/list/imported_layout = cyborg_layout_pref_slot_data(legacy_layout)
	TEST_ASSERT_EQUAL(imported_layout["active"]["penis"]["advanced"]["rest_north"]["pixel_x"], 9, "Legacy pose aliases must expand only at the import boundary.")

	var/list/root = list()
	var/list/slot = list("headshot_silicon" = "https://i.gyazo.com/example.png", "headshot_silicon_nsfw" = "https://i.gyazo.com/example-nsfw.png", "silicon_genital_layout_presets" = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 8))))
	cyborg_layout_import_sanitize_slot(slot, root)
	TEST_ASSERT_EQUAL(slot["silicon_headshot"], "https://i.gyazo.com/example.png", "The donor headshot alias was not migrated.")
	TEST_ASSERT(!("headshot_silicon" in slot), "The donor headshot alias remained after import.")
	TEST_ASSERT_EQUAL(slot["silicon_headshot_nsfw"], "https://i.gyazo.com/example-nsfw.png", "The donor NSFW headshot alias was not migrated.")
	TEST_ASSERT(!("headshot_silicon_nsfw" in slot), "The donor NSFW headshot alias remained after import.")

	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 77)))
	slot = list("silicon_genital_layout_presets" = future_layout)
	root = list()
	cyborg_layout_import_sanitize_slot(slot, root)
	TEST_ASSERT(slot["silicon_genital_layout_presets"] == future_layout, "A future layout was rewritten during import.")
	TEST_ASSERT(length(root["aphelion_cyborg_layout_import_notice"]), "A preserved future layout did not produce an import notice.")

/datum/unit_test/cyborg_interaction_and_runtime_owner_gate/Run()
	var/mob/living/carbon/human/consistent/human = EASY_ALLOCATE()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.name = "Cheer"
	interaction.category = "Miscellaneous"
	interaction.usage = INTERACTION_OTHER
	interaction.message = list("%USER% cheers for %TARGET%!")
	interaction.distance_allowed = TRUE
	TEST_ASSERT(cyborg_message_interaction_allowed(interaction, human, robot), "Humans must be able to cheer cyborgs.")
	TEST_ASSERT(cyborg_message_interaction_allowed(interaction, robot, human), "Cyborgs must be able to cheer humans.")
	interaction.name = "Headpat"
	interaction.interaction_requires = list(INTERACTION_REQUIRE_SELF_HAND)
	var/obj/item/bodypart/active_hand = human.get_active_hand()
	active_hand.drop_limb()
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, human, robot), "Physical human gestures must require an active hand.")
	TEST_ASSERT(active_hand.try_attach_limb(human), "The active hand could not be restored after the rejection fixture.")
	TEST_ASSERT(cyborg_message_interaction_allowed(interaction, human, robot), "Humans with an active hand must be able to headpat cyborgs.")
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, robot, human), "Cyborgs must not use human-only physical interactions.")
	interaction.name = "Cheer"
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, robot, human), "Cyborg cheer must reject a reloaded hand requirement.")
	interaction.interaction_requires = list()
	interaction.target_pain = 1
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, robot, human), "Cyborg cheer must reject a same-named interaction with an effect field.")
	interaction.target_pain = 0
	interaction.sound_possible = list("unexpected.ogg")
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, robot, human), "Cyborg cheer must reject a reloaded sound effect.")
	interaction.sound_possible = list()
	interaction.lewd = TRUE
	TEST_ASSERT(!cyborg_message_interaction_allowed(interaction, human, robot), "Cyborg interactions must reject lewd entries.")

	var/datum/preferences/preferences = create_preferences(robot)
	preferences.default_slot = 2
	// Mock savefiles can retain a prior focused run's future-layout fixture.
	// This lifecycle case deliberately begins from an absent character tree.
	preferences.savefile.remove_entry("character2")
	preferences.value_cache -= /datum/preference/cyborg_layout
	robot.cyborg_appearance_slot = 2
	robot.cyborg_appearance_owner = robot.ckey
	TEST_ASSERT(cyborg_runtime_actor_is_owner(robot, robot, 2), "The owning cyborg and active character slot must be accepted.")
	TEST_ASSERT(!cyborg_runtime_actor_is_owner(robot, human, 2), "A different actor must not manage cyborg customization.")
	TEST_ASSERT(!cyborg_runtime_actor_is_owner(robot, robot, 1), "A different character slot must not manage cyborg customization.")
	robot.cyborg_appearance_slot = 1
	TEST_ASSERT(!cyborg_runtime_actor_is_owner(robot, robot, 2), "A body bound to another preference slot must be rejected.")
	robot.cyborg_appearance_slot = 2
	robot.cyborg_appearance_owner = "wrong_owner"
	TEST_ASSERT(!cyborg_runtime_actor_is_owner(robot, robot, 2), "A body bound to another owner must be rejected.")
	robot.cyborg_appearance_owner = robot.ckey
	robot.cyborg_appearance_store = cyborg_layout_default()
	robot.cyborg_appearance_layout = cyborg_layout_copy(robot.cyborg_appearance_store["active"])
	robot.cyborg_appearance_active = list("penis" = FALSE)
	var/list/runtime_activate = list("operation" = "activate", "slot" = "penis", "value" = TRUE, "character_slot" = 1)
	TEST_ASSERT(!robot.cyborg_runtime_action(runtime_activate, human), "A different actor must not enter the cyborg runtime action.")
	TEST_ASSERT(robot.cyborg_runtime_action(runtime_activate, robot), "A slot-mismatched runtime request must return a visible refusal.")
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "A mismatched runtime slot changed the body state.")
	runtime_activate["character_slot"] = 2
	robot.cyborg_appearance_owner = "wrong_owner"
	TEST_ASSERT(robot.cyborg_runtime_action(runtime_activate, robot), "An owner-mismatched runtime request must return a visible refusal.")
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "An owner-mismatched runtime request changed the body state.")
	robot.cyborg_appearance_owner = robot.ckey
	var/datum/preference/toggle/allow_genitals/genitals_preference = GLOB.preference_entries[/datum/preference/toggle/allow_genitals]
	preferences.write_preference(genitals_preference, FALSE)
	TEST_ASSERT(robot.cyborg_runtime_action(runtime_activate, robot), "A consent-disabled runtime request must return visible feedback.")
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "A consent-disabled runtime request changed the body state.")

	var/list/draft = preferences.cyborg_session().begin_draft()
	var/list/draft_active = islist(draft) ? draft["active"] : null
	var/list/draft_penis = islist(draft_active) ? draft_active["penis"] : null
	if(!islist(draft) || !islist(draft_active) || !islist(draft_penis))
		var/list/raw_slot = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
		var/raw_layout = raw_slot?["silicon_genital_layout_presets"]
		TEST_FAIL("Current-schema draft was malformed (draft_list=[islist(draft)], active_list=[islist(draft_active)], penis_list=[islist(draft_penis)], raw_future=[cyborg_layout_import_is_future(raw_layout)], cached_layout_list=[islist(preferences.value_cache[/datum/preference/cyborg_layout])]).")
		return
	draft["active"]["penis"]["pixel_x"] = 42
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "A current-schema draft must be accepted.")
	TEST_ASSERT(preferences.cyborg_session().draft_timer, "Draft updates must schedule a debounced flush.")
	preferences.cyborg_session().discard_draft("unit_test")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft, "Discard must clear the slot-bound draft.")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Discard must cancel the pending flush callback.")

	draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 17
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "A second draft update failed.")
	TEST_ASSERT(preferences.cyborg_session().commit_draft(), "A current-slot draft must flush.")
	var/list/flushed = preferences.read_preference(/datum/preference/cyborg_layout)
	TEST_ASSERT_EQUAL(flushed["active"]["penis"]["pixel_x"], 17, "Flush did not write the current slot's layout.")
	var/list/new_slot_data = preferences.savefile.get_entry("character2")
	TEST_ASSERT_EQUAL(new_slot_data["silicon_genital_layout_presets"]["active"]["penis"]["pixel_x"], 17, "Flushing a newly created slot did not materialize its character tree before writing.")

	// Direct slot loads cannot carry a deferred layout write into the new slot.
	preferences.default_slot = 1
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.savefile.set_entry("character2", list("version" = 52))
	preferences.value_cache = list()
	var/datum/preference/cyborg_layout/layout_preference = GLOB.preference_entries[/datum/preference/cyborg_layout]
	var/list/slot_one_layout = cyborg_layout_default()
	slot_one_layout["active"]["penis"]["pixel_x"] = 1
	preferences.write_preference(layout_preference, slot_one_layout)
	preferences.default_slot = 2
	preferences.value_cache = list()
	var/list/slot_two_layout = cyborg_layout_default()
	slot_two_layout["active"]["penis"]["pixel_x"] = 2
	preferences.write_preference(layout_preference, slot_two_layout)
	preferences.default_slot = 1
	preferences.value_cache = list()
	preferences.read_preference(/datum/preference/cyborg_layout)
	draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 41
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "The slot-one draft update failed.")
	TEST_ASSERT(preferences.load_character(2), "Directly loading the second character slot failed.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/cyborg_layout)["active"]["penis"]["pixel_x"], 2, "A slot-one layout draft leaked into slot two.")
	var/list/saved_slot_one = preferences.savefile.get_entry("character1")
	TEST_ASSERT_EQUAL(saved_slot_one["silicon_genital_layout_presets"]["active"]["penis"]["pixel_x"], 41, "Direct slot loading did not persist the old slot's layout draft.")

	preferences.cyborg_session().on_character_replaced()
	var/list/saved_slot_two = preferences.savefile.get_entry("character2")
	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	saved_slot_two["silicon_genital_layout_presets"] = future_layout
	preferences.value_cache -= /datum/preference/cyborg_layout
	TEST_ASSERT_NULL(preferences.cyborg_session().begin_draft(), "An unsupported future layout must not become an editable draft.")
	TEST_ASSERT(saved_slot_two["silicon_genital_layout_presets"] == future_layout, "Opening the creator replaced future layout data.")

	var/datum/preference/choiced/cyborg_size/size_preference = GLOB.preference_entries[/datum/preference/choiced/cyborg_size]
	TEST_ASSERT_EQUAL(size_preference.deserialize("1.6", preferences), 1.6, "Serialized cyborg size choices must remain numeric.")

/// Loads authored interaction data independently of the deployment's server configuration.
/datum/unit_test/cyborg_interaction_component_lists_safe_actions
	/// Restored even if an assertion exits Run early.
	var/list/datum/interaction/previous_interactions
	/// The JSON loader requires a filesystem path, not an embedded resource.
	var/interaction_fixture_path

/datum/unit_test/cyborg_interaction_component_lists_safe_actions/New()
	..()
	previous_interactions = GLOB.interaction_instances
	GLOB.interaction_instances = list()

/datum/unit_test/cyborg_interaction_component_lists_safe_actions/Destroy()
	GLOB.interaction_instances = previous_interactions
	previous_interactions = null
	if(interaction_fixture_path)
		fdel(interaction_fixture_path)
	return ..()

/datum/unit_test/cyborg_interaction_component_lists_safe_actions/Run()
	var/datum/interaction/cheer = allocate(/datum/interaction)
	// A resource literal bundles the existing JSON in the test RSC. CI does not
	// deploy config/nova/interactions, and this must not depend on a live registry.
	interaction_fixture_path = "[GLOB.log_directory]/cyborg_cheer_[REF(src)].json"
	TEST_ASSERT(fcopy('config/nova/interactions/cheer.json', interaction_fixture_path), "The authored Cheer interaction resource failed to extract.")
	TEST_ASSERT(cheer.load_from_json(interaction_fixture_path), "The authored Cheer interaction fixture failed to load.")
	GLOB.interaction_instances[cheer.name] = cheer
	var/mob/living/carbon/human/consistent/human = EASY_ALLOCATE()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	TEST_ASSERT(cheer && !cheer.lewd, "The authored non-lewd Cheer interaction was unavailable for the cyborg integration test.")
	TEST_ASSERT(!cheer.sound_use && length(cheer.sound_possible) == 1 && cheer.sound_possible[1] == "json error", "The actual empty-sound Cheer JSON fixture no longer reaches the loader sentinel path.")
	TEST_ASSERT(cyborg_message_interaction_allowed(cheer, human, robot), "The authored no-sound Cheer interaction was rejected before UI assembly.")
	var/datum/component/interactable/component = robot.GetComponent(/datum/component/interactable)
	if(!component)
		component = robot.AddComponent(/datum/component/interactable)
	component.build_interactions_list()
	TEST_ASSERT(cheer in component.interactions, "A non-lewd authored action was omitted from the robot interaction candidate list.")
	var/list/payload = component.ui_data(human)
	TEST_ASSERT("Miscellaneous" in payload["interactions"], "The robot interaction payload omitted the safe action category.")
	TEST_ASSERT("Cheer" in payload["interactions"]["Miscellaneous"], "The robot interaction payload omitted the safe Cheer action.")

/datum/unit_test/cyborg_future_layout_apply_preserves_raw_data/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	preferences.savefile.set_entry("character1", list("version" = 52, "silicon_genital_layout_presets" = future_layout))
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	robot.cyborg_appearance_store = cyborg_layout_default()
	robot.cyborg_appearance_layout = cyborg_layout_copy(robot.cyborg_appearance_store["active"])
	robot.cyborg_appearance_active = list("penis" = TRUE)
	robot.cyborg_appearance_slot = preferences.default_slot
	robot.cyborg_appearance_owner = robot.ckey
	apply_cyborg_customization(robot, preferences, "unit_test")
	var/list/saved_slot = preferences.savefile.get_entry("character1")
	TEST_ASSERT(saved_slot["silicon_genital_layout_presets"] == future_layout, "Applying a future schema layout rewrote the preserved raw save data.")
	TEST_ASSERT_NULL(robot.cyborg_appearance_store, "Applying a future schema layout left a mutable body store.")
	TEST_ASSERT_NULL(robot.cyborg_appearance_layout, "Applying a future schema layout left a mutable body layout.")
	TEST_ASSERT(!length(robot.cyborg_appearance_active), "Applying a future schema layout left active visual state behind.")

/datum/unit_test/cyborg_layout_sprite_size_and_granular_actions
/datum/unit_test/cyborg_layout_sprite_size_and_granular_actions/Run()
	var/list/defaults = cyborg_layout_default()
	TEST_ASSERT_EQUAL(defaults["active"]["penis"]["sprite_size"], 2, "Penis entries did not preserve the current native size default.")
	TEST_ASSERT_EQUAL(defaults["active"]["testicles"]["sprite_size"], 2, "Testicle entries did not preserve the current native size default.")
	TEST_ASSERT_EQUAL(defaults["active"]["breasts"]["sprite_size"], 1, "Breast entries did not preserve the current native size default.")
	var/list/normalized = cyborg_layout_normalize(list("schema_version" = 1, "active" = list("penis" = list("sprite_size" = 99, "scale" = 99))))
	TEST_ASSERT_EQUAL(normalized["active"]["penis"]["sprite_size"], 16, "Sprite size was not bounded.")
	TEST_ASSERT_EQUAL(normalized["active"]["penis"]["scale"], 2, "Continuous scale exceeded the 200% cap.")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/placed = cyborg_layout_action(cyborg_layout_default(), list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "pose", "direction" = "south", "pose" = "idle"), "changes" = list("pixel_x" = 999, "pixel_y" = -999)), model_id)
	TEST_ASSERT_EQUAL(placed["store"]["active"]["penis"]["advanced"]["idle_south"]["pixel_x"], 128, "Atomic placement did not clamp X.")
	TEST_ASSERT_EQUAL(placed["store"]["active"]["penis"]["advanced"]["idle_south"]["pixel_y"], -128, "Atomic placement did not clamp Y.")
	var/list/fractional = cyborg_layout_action(cyborg_layout_default(), list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "pose", "direction" = "south", "pose" = "idle"), "changes" = list("pixel_x" = 15.6, "pixel_y" = -15.6)), model_id)["store"]["active"]["penis"]["advanced"]["idle_south"]
	TEST_ASSERT_EQUAL(fractional["pixel_x"], 16, "Placement must round X to the nearest whole pixel.")
	TEST_ASSERT_EQUAL(fractional["pixel_y"], -16, "Placement must round negative Y to the nearest whole pixel.")
	var/list/fractional_entry = list("pixel_x" = -7.6, "pixel_y" = 7.6, "advanced" = list("north" = list("pixel_x" = -1.6, "arousal" = list("full" = list("pixel_y" = 2.6)))))
	fractional = cyborg_layout_normalize_entry(fractional_entry)
	TEST_ASSERT_EQUAL(fractional["pixel_x"], -8, "Saved base X must round to whole pixels.")
	TEST_ASSERT_EQUAL(fractional["pixel_y"], 8, "Saved base Y must round to whole pixels.")
	TEST_ASSERT_EQUAL(fractional["advanced"]["north"]["pixel_x"], -2, "Directional offsets must round to whole pixels.")
	TEST_ASSERT_EQUAL(fractional["advanced"]["north"]["arousal"]["full"]["pixel_y"], 3, "Arousal offsets must round to whole pixels.")
	var/list/reset = cyborg_layout_action(placed["store"], list("operation" = "reset_colors", "slot" = "penis"), null)
	TEST_ASSERT_EQUAL(reset["store"]["active"]["penis"]["colors"][1], "#ffffff", "Color reset did not restore the first channel.")
	reset = cyborg_layout_action(reset["store"], list("operation" = "reset_overrides", "slot" = "penis"), null)
	TEST_ASSERT(!length(reset["store"]["active"]["penis"]["advanced"]), "Override reset retained directional data.")
	var/list/position_store = cyborg_layout_default()
	position_store["active"]["penis"]["pixel_x"] = 12
	position_store["active"]["penis"]["pixel_y"] = -8
	position_store["active"]["penis"]["rotation"] = 33
	position_store["active"]["penis"]["scale"] = 1.5
	position_store["active"]["penis"]["colors"] = list("#111111", "#222222", "#333333")
	position_store["active"]["penis"]["advanced"]["north"] = list("pixel_x" = 3)
	var/list/position_reset = cyborg_layout_action(position_store, list("operation" = "reset_position", "slot" = "penis"), null)["store"]["active"]["penis"]
	TEST_ASSERT_EQUAL(position_reset["pixel_x"], 0, "Position reset retained X.")
	TEST_ASSERT_EQUAL(position_reset["pixel_y"], 0, "Position reset retained Y.")
	TEST_ASSERT_EQUAL(position_reset["rotation"], 0, "Position reset retained rotation.")
	TEST_ASSERT_EQUAL(position_reset["scale"], 1, "Position reset retained scale.")
	TEST_ASSERT_EQUAL(position_reset["colors"][1], "#111111", "Position reset unexpectedly changed colors.")
	TEST_ASSERT(position_reset["advanced"]["north"], "Position reset unexpectedly removed directional overrides.")
	var/list/global_reset = cyborg_layout_action(position_store, list("operation" = "reset"), null)
	TEST_ASSERT(islist(global_reset["store"]), "Resetting all parts without a slot was rejected.")
	for(var/reset_slot in cyborg_layout_supported_slots())
		TEST_ASSERT_EQUAL(json_encode(global_reset["store"]["active"][reset_slot]), json_encode(defaults["active"][reset_slot]), "Global reset did not restore [reset_slot] defaults.")
	var/list/invalid_reset = cyborg_layout_action(position_store, list("operation" = "reset", "slot" = "invalid"), null)
	TEST_ASSERT_NULL(invalid_reset["store"], "An invalid slot unexpectedly reset all parts.")
	var/list/knotted_sizes = cyborg_accessory_size_values("penis", "Dogborg Knotted")
	TEST_ASSERT_EQUAL(length(knotted_sizes), 7, "Direct knotted accessory did not expose all authored sizes.")
	var/list/small_knotted = cyborg_accessory_render("penis", "Dogborg Knotted", list("#ffffff", "#ffffff", "#ffffff"), "none", SOUTH, 1)
	var/list/large_knotted = cyborg_accessory_render("penis", "Dogborg Knotted", list("#ffffff", "#ffffff", "#ffffff"), "none", SOUTH, 7)
	TEST_ASSERT(small_knotted && large_knotted && small_knotted["base64"] != large_knotted["base64"], "Direct authored sprite sizes did not change the rendered image.")
	TEST_ASSERT_EQUAL(cyborg_accessory_effective_size("penis", "Dogborg Knotted", 99), 1, "Invalid direct sizes did not fall back to an authored size.")
	for(var/direct_slot in list("penis", "sheath", "testicles", "anus"))
		var/list/direct_catalog = cyborg_direct_accessories(direct_slot)
		for(var/direct_choice in direct_catalog)
			var/list/direct_descriptor = direct_catalog[direct_choice]
			for(var/authored_size in direct_descriptor["sizes"])
				var/list/rendered = cyborg_accessory_render(direct_slot, direct_choice, list("#ffffff", "#ffffff", "#ffffff"), "none", SOUTH, authored_size)
				TEST_ASSERT(rendered, "Authored [direct_slot] size [authored_size] failed to render for [direct_choice].")
				TEST_ASSERT(length(cyborg_accessory_color_channels(direct_slot, direct_choice, authored_size, "none")), "Authored [direct_slot] size [authored_size] had no available color channel for [direct_choice].")

/datum/unit_test/cyborg_live_coordinates_and_spawn_snapshot
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_live_coordinates_and_spawn_snapshot/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
	preferences.default_slot = 2
	preferences.savefile.remove_entry("character2")
	preferences.value_cache -= /datum/preference/cyborg_layout
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/descriptor = cyborg_model_catalog()[model_id]
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/engineering(robot)
	robot.model.cyborg_customization_skin = "Drake"
	robot.model.cyborg_base_icon = descriptor["icon_state"]
	robot.icon = descriptor["icon"]
	robot.icon_state = descriptor["icon_state"]
	robot.base_pixel_x = descriptor["pixel_x"]
	robot.pixel_x = robot.base_pixel_x
	robot.base_pixel_z = descriptor["pixel_y"]
	robot.pixel_z = robot.base_pixel_z
	apply_cyborg_customization(robot, preferences, "spawn")
	var/starting_size = robot.cyborg_appearance_requested_size
	var/datum/preference_middleware/cyborg_character/editor = new(preferences)
	allocated += editor
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_size], 2.5)
	editor.post_set_preference(robot, "cyborg_size", 2.5)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_requested_size, starting_size, "Creator size edits must not resize a spawned body.")
	apply_cyborg_customization(robot, preferences, "login")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_requested_size, starting_size, "Reconnect must not apply future-body settings either.")
	robot.update_transform(1.6) // Hardware/body transforms must still apply exactly once.
	var/list/dimensions = get_icon_dimensions(descriptor["icon"])
	for(var/direction in GLOB.cardinals)
		robot.setDir(direction)
		robot.cyborg_appearance_holder.update_from_owner()
		var/obj/effect/client_image_holder/cyborg_customization/holder = robot.cyborg_appearance_holder
		TEST_ASSERT(holder.shown_image.layer > robot.layer, "Parts must render above the chassis base.")
		TEST_ASSERT(holder.shown_image.layer < holder.occlusion_image.layer, "The live part group must render below its chassis mask, as it does in preview.")
		TEST_ASSERT_EQUAL(holder.occlusion_image.pixel_x, 0, "A body mask attached to its owner must not repeat the owner's X offset.")
		TEST_ASSERT_EQUAL(holder.occlusion_image.pixel_y, 0, "A body mask must not repeat the owner's Z offset as Y.")
		TEST_ASSERT_EQUAL("[holder.occlusion_image.transform]", "[matrix()]", "Body masks inherit the owner's transform exactly once.")
		TEST_ASSERT_EQUAL("[holder.shown_image.transform]", "[matrix()]", "Part roots inherit the owner's transform exactly once.")
		TEST_ASSERT(holder.animation_image, "Authored models must use a native movement carrier.")
		TEST_ASSERT_EQUAL(holder.animation_image.loc, robot, "The carrier must follow the same native movement as the chassis.")
		TEST_ASSERT_EQUAL(holder.animation_image.icon_state, robot.icon_state, "The carrier must select the chassis pose.")
		TEST_ASSERT_EQUAL(holder.animation_image.dir, direction, "Turning must select the matching native direction.")
		TEST_ASSERT_EQUAL(holder.shown_image.filters[1]:size, 127, "Native displacement must stay aligned to whole pixels.")
		var/list/layer = holder.render_layers[1]
		var/mutable_appearance/part = holder.shown_image.overlays[1]
		var/icon/art = layer["resource"]
		TEST_ASSERT_EQUAL(part.pixel_w, layer["x"] + (dimensions["width"] - art.Width()) / 2, "Screen-space part X must use the preview's centered canvas origin.")
		TEST_ASSERT_EQUAL(part.pixel_z, layer["y"] + 16 - art.Height() / 2, "Screen-space part Y must use the preview's tile-center origin.")
		TEST_ASSERT_EQUAL(part.pixel_x, 0, "Cosmetic placement must not change SIDE_MAP depth coordinates.")
		TEST_ASSERT_EQUAL(part.pixel_y, 0, "Cosmetic placement must not move parts in front of the body mask through SIDE_MAP depth sorting.")

/datum/unit_test/cyborg_inspect_portrait_bounds/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/examine_panel/panel = new(robot)
	allocated += panel
	var/list/catalog = cyborg_model_catalog()
	for(var/id in catalog)
		var/list/descriptor = catalog[id]
		robot.icon = descriptor["icon"]
		robot.icon_state = descriptor["icon_state"]
		robot.pixel_x = 7
		robot.pixel_y = -3
		robot.pixel_w = 4
		robot.pixel_z = 9
		robot.transform = matrix().Scale(1.6)
		var/mutable_appearance/portrait = panel.preview_appearance()
		var/list/dimensions = get_icon_dimensions(robot.icon)
		var/width = dimensions["width"]
		var/height = dimensions["height"]
		TEST_ASSERT_EQUAL(portrait.pixel_x + width / 2, world.icon_size / 2, "[id] must be horizontally centered in the inspect tile.")
		TEST_ASSERT_EQUAL(portrait.pixel_y + height / 2, world.icon_size / 2, "[id] must be vertically centered in the inspect tile.")
		TEST_ASSERT_EQUAL(portrait.pixel_w, 0, "Inspect portraits must not inherit a world W shift.")
		TEST_ASSERT_EQUAL(portrait.pixel_z, 0, "Inspect portraits must not inherit a world Z shift.")
		TEST_ASSERT(portrait.transform.a * width <= world.icon_size && portrait.transform.e * height <= world.icon_size, "[id] must fit entirely inside the inspect tile.")
		TEST_ASSERT_EQUAL(robot.pixel_x, 7, "Building a portrait must not change the live mob.")

/datum/unit_test/cyborg_nsfw_ooc_preference
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_nsfw_ooc_preference/Run()
	var/datum/preferences/preferences = create_preferences(null)
	var/list/fallback_types = list("ooc_notes_silicon" = /datum/preference/text/ooc_notes, "ooc_notes_silicon_nsfw" = /datum/preference/text/ooc_notes_nsfw)
	for(var/key in fallback_types)
		var/datum/preference/notes = GLOB.preference_entries_by_key[key]
		TEST_ASSERT(notes, "Cyborg profile needs its own saved [key] preference.")
		var/fallback_type = fallback_types[key]
		preferences.write_preference(GLOB.preference_entries[fallback_type], "Human [key]")
		TEST_ASSERT_EQUAL(cyborg_identity_text(preferences, notes.type, fallback_type), "Human [key]", "Empty cyborg notes must preserve the matching human fallback.")
		preferences.write_preference(notes, "Cyborg [key]")
		TEST_ASSERT_EQUAL(cyborg_identity_text(preferences, notes.type, fallback_type), "Cyborg [key]", "Cyborg notes must override the fallback.")
		TEST_ASSERT_EQUAL(preferences.read_preference(fallback_type), "Human [key]", "Cyborg edits must not alter human notes.")
		preferences.save_character()
		preferences.value_cache -= notes.type
		TEST_ASSERT_EQUAL(preferences.read_preference(notes.type), "Cyborg [key]", "Cyborg notes must survive a save and reload.")
		preferences.write_preference(notes, "")
		TEST_ASSERT_EQUAL(cyborg_identity_text(preferences, notes.type, fallback_type), "Human [key]", "Clearing cyborg notes must restore the matching human fallback.")

/datum/unit_test/cyborg_named_setups_and_model_binding/Run()
	var/model_a = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/model_b = cyborg_appearance_model_id(/obj/item/robot_model/service, "Drake")
	var/list/store = cyborg_layout_default()
	store = cyborg_layout_action(store, list("operation" = "save", "name" = "Workshop"), model_a)["store"]
	TEST_ASSERT_EQUAL(store["preset_models"]?["Workshop"], model_a, "A named setup must retain its chassis.")
	store = cyborg_layout_action(store, list("operation" = "assign_default", "name" = "Workshop"), model_a)["store"]
	TEST_ASSERT(store, "Assigning a named setup as the spawn default must succeed.")
	TEST_ASSERT_EQUAL(store["model_presets"][model_a], "Workshop", "The model must identify its assigned setup.")
	var/list/result = cyborg_layout_action(store, list("operation" = "load", "name" = "Workshop"), model_b)
	TEST_ASSERT_EQUAL(result["model"], model_a, "Loading a setup must restore its chassis.")
	store = result["store"]
	store["active"]["penis"]["pixel_x"] = 23
	store = cyborg_layout_action(store, list("operation" = "save", "name" = "Workshop", "overwrite" = TRUE), model_a)["store"]
	TEST_ASSERT_EQUAL(store["model_defaults"][model_a]["penis"]["pixel_x"], 23, "Updating an assigned setup must update its future spawn default.")
	store = cyborg_layout_action(store, list("operation" = "delete", "name" = "Workshop"), model_a)["store"]
	TEST_ASSERT_NULL(store["model_presets"][model_a], "Deleting a setup must remove dangling name assignments.")
	TEST_ASSERT_EQUAL(store["model_defaults"][model_a]["penis"]["pixel_x"], 23, "Deleting a setup must preserve the last saved default snapshot.")
