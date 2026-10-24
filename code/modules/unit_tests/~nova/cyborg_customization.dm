/// Focused tests for the bounded cyborg layout contract.

/// Counts preference reads and saves, so rejected requests can be shown to do no work.
/datum/preferences/cyborg_save_failure_test
	parent_type = /datum/preferences/preferences_import_test
	var/save_preferences_calls = 0
	var/sprite_reads = 0

/datum/preferences/cyborg_save_failure_test/read_preference(preference_type)
	if(ispath(preference_type, /datum/preference/choiced/cyborg_sprite))
		sprite_reads++
	return ..()

/datum/preferences/cyborg_save_failure_test/save_preferences()
	save_preferences_calls++
	return ..()

/// Injects sidecar write failures without touching player files.
/datum/json_savefile/cyborg_customization/write_failure_test
	var/fail_writes = FALSE

/datum/json_savefile/cyborg_customization/write_failure_test/save()
	if(fail_writes)
		return FALSE
	return ..()

/datum/unit_test/cyborg_save_failure_retains_draft
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_save_failure_retains_draft/Run()
	var/datum/preferences/preferences = create_preferences()
	var/datum/json_savefile/cyborg_customization/write_failure_test/store = allocate(/datum/json_savefile/cyborg_customization/write_failure_test, null)
	preferences.cyborg_layout_savefile = store
	preferences.default_slot = 1
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 19
	editor.update_draft(draft)
	var/context = editor.context_generation
	var/revision = editor.draft_revision
	store.fail_writes = TRUE
	TEST_ASSERT(!editor.commit_draft(), "Injected sidecar write failure was acknowledged.")
	TEST_ASSERT(editor.dirty && editor.draft == draft && editor.save_error, "Write failure lost its retryable draft.")
	store.fail_writes = FALSE
	TEST_ASSERT(editor.commit_draft(), "Retry after write recovery failed.")
	TEST_ASSERT(!editor.dirty && !editor.save_error, "Successful retry did not clear pending/error state.")
	TEST_ASSERT_EQUAL(editor.saved_revision, revision, "Retry acknowledged the wrong revision.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 19, "Retry lost accepted placement data.")
	TEST_ASSERT(editor.session_only, "A memory-only sidecar claimed durable saving.")
	var/list/saved_character = preferences.savefile.get_entry("character1")
	TEST_ASSERT(!islist(saved_character) || !("silicon_genital_layout_presets" in saved_character), "Layouts must stay out of preferences.json.")
	// The sidecar is keyed by slot, so a slot change writes the old draft to its own slot.
	draft["active"]["penis"]["pixel_x"] = 23
	editor.update_draft(draft)
	preferences.default_slot = 2
	var/list/slot_two = editor.begin_draft()
	TEST_ASSERT_EQUAL(slot_two["active"]["penis"]["pixel_x"], 0, "A slot-one draft leaked into slot two.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(1)["active"]["penis"]["pixel_x"], 23, "Changing slots lost the old slot's pending draft.")
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(2), "Opening an empty slot wrote a layout for it.")
	editor.discard_draft()
	editor.flush_timer(1, context, revision)
	TEST_ASSERT_NULL(editor.draft, "A stale timer resurrected replaced data.")
	TEST_ASSERT_NULL(editor.draft_timer, "Replacement retained an old callback.")

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
	command["operation"] = "nudge_placement"
	command["changes"] = list("pixel_x" = -1)
	for(var/step in 1 to 3)
		next = cyborg_layout_action(next, command, model_id)["store"]
		TEST_ASSERT(next, "A valid held-key step was rejected.")
	TEST_ASSERT_EQUAL(next["active"]["penis"]["placement_groups"]["side"]["pixel_x"], 7, "Held-key steps must accumulate against current server state.")
	command["target"] = list("scope" = "arousal", "direction" = WEST, "pose" = "rest", "arousal" = "partial")
	command["changes"] = list("pixel_y" = 1)
	next = cyborg_layout_action(next, command, model_id)["store"]
	TEST_ASSERT_EQUAL(next["active"]["penis"]["advanced"]["rest_west"]["arousal"]["partial"]["pixel_y"], 4, "Arousal nudges must start from inherited pose placement.")
	command["changes"] = list("pixel_y" = 2)
	TEST_ASSERT_NULL(cyborg_layout_action(next, command, model_id)["store"], "A nudge accepted more than one pixel.")
	command["changes"] = list("rotation" = 1)
	TEST_ASSERT_NULL(cyborg_layout_action(next, command, model_id)["store"], "A nudge accepted a non-position field.")

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
	// These existing layout/lifecycle tests exercise ready resources. Cold demand
	// and superseded completion have dedicated tests with an empty controlled cache.
	for(var/model_type in list(/obj/item/robot_model/engineering, /obj/item/robot_model/medical, /obj/item/robot_model/service))
		var/list/descriptor = cyborg_model_catalog()[cyborg_appearance_model_id(model_type, "Drake")]
		cyborg_occlusion_ensure_model_ready(descriptor["icon"], descriptor["icon_state"])
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

/// Exercise the creator protocol and sidecar writes, without a UI client.
/// Removing either the slot guard or the page-close flush must break this regression.
/datum/unit_test/cyborg_creator_draft_lifecycle
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_model_default_parts_and_runtime_usage
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_model_default_parts_and_runtime_usage/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/cyborg_save_failure_test/preferences = create_preferences(robot, /datum/preferences/cyborg_save_failure_test)
	preferences.default_slot = 2
	preferences.savefile.remove_entry("character2")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/datum/preference_middleware/cyborg_character/middleware = preferences.cyborg_session()
	middleware.page_active = TRUE
	middleware.preview_model = model_id
	TEST_ASSERT(middleware.edit_layout(list("operation" = "save_default", "character_slot" = 2, "context" = middleware.context_generation), robot), "Saving a model default must succeed.")
	middleware.commit_draft()
	var/list/store = preferences.read_cyborg_layout(2)
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
	apply_cyborg_customization(robot, preferences)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_choices["penis"], "Dogborg Knotted", "Spawn must restore the model's saved sprite instead of the current None preference.")
	TEST_ASSERT(robot.cyborg_appearance_active["penis"], "A configured part must start active on a new body.")
	TEST_ASSERT(length(robot.cyborg_appearance_holder.render_layers), "The configured model must produce native render layers on spawn.")
	var/list/runtime_data = robot.cyborg_runtime_data()
	TEST_ASSERT_NULL(runtime_data["store"], "Runtime data must not expose editable saved layouts.")
	TEST_ASSERT(length(runtime_data["parts"]), "Runtime controls must list configured parts.")
	// Runtime controls answer to the player whose prefs the body took, once they are in it.
	robot.ckey = preferences.parent.ckey
	var/before = json_encode(robot.cyborg_appearance_layout)
	TEST_ASSERT(!robot.cyborg_runtime_action(list("operation" = "place", "slot" = "penis", "x" = 100, "y" = 100, "character_slot" = 2, "context" = middleware.context_generation), robot), "Runtime placement must be rejected server-side.")
	TEST_ASSERT_EQUAL(json_encode(robot.cyborg_appearance_layout), before, "Rejected runtime editing must leave layout untouched.")
	TEST_ASSERT(robot.cyborg_runtime_action(list("operation" = "activate", "slot" = "penis", "value" = FALSE, "character_slot" = 2, "context" = middleware.context_generation), robot), "Usage controls must allow hiding configured parts.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/see_cyborg_genitalia], FALSE)
	var/revision = robot.cyborg_appearance_revision
	var/image/unchanged_image = robot.cyborg_appearance_holder.shown_image
	var/saves = preferences.save_preferences_calls
	for(var/repeat in 1 to 10)
		robot.cyborg_runtime_action(list("operation" = "activate", "slot" = "penis", "value" = FALSE, "character_slot" = 2), robot)
		robot.cyborg_runtime_action(list("operation" = "arousal", "slot" = "penis", "value" = "none", "character_slot" = 2), robot)
		robot.cyborg_runtime_action(list("operation" = "viewer", "value" = FALSE, "character_slot" = 2), robot)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_revision, revision, "Identical usage controls rebuilt native appearance.")
	TEST_ASSERT(robot.cyborg_appearance_holder.shown_image == unchanged_image, "Identical usage controls replaced the image.")
	TEST_ASSERT_EQUAL(preferences.save_preferences_calls, saves, "Identical viewer controls wrote the whole preference file.")
	apply_cyborg_customization(robot, preferences)
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "Reconnect must preserve an explicit hidden state.")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_choices["penis"], "Dogborg Knotted", "Reconnect must preserve the model's saved sprite.")
	TEST_ASSERT(middleware.edit_layout(list("operation" = "load_default", "character_slot" = 2, "context" = middleware.context_generation), robot), "Creator must load the saved default.")
	TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/cyborg_sprite/penis), "Dogborg Knotted", "Loading a default must restore the sprite selector too.")
	middleware.set_preview(list("context" = middleware.context_generation, "model" = model_id), null)
	middleware.commit_draft()
	var/draft_revision = middleware.draft_revision
	middleware.set_preview(list("context" = middleware.context_generation, "model" = model_id), null)
	TEST_ASSERT_EQUAL(middleware.draft_revision, draft_revision, "Selecting the current model created another draft revision.")
	TEST_ASSERT(!middleware.dirty && !middleware.draft_timer, "Selecting the current model scheduled another save.")
	robot.ckey = null

/datum/unit_test/cyborg_action_snapshot_isolation/Run()
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/store = cyborg_layout_default()
	store["active"]["penis"]["pixel_x"] = 9
	store["presets"]["Original"] = cyborg_layout_copy(store["active"])
	store["preset_models"]["Original"] = model_id
	store["model_defaults"][model_id] = cyborg_layout_copy(store["active"])
	store["model_presets"][model_id] = "Original"
	var/before = json_encode(store)
	for(var/operation in list("set", "reset_position", "reset_colors", "reset_overrides", "reset", "save", "load", "delete", "assign_default", "save_default", "load_default", "delete_default"))
		var/list/params = list("operation" = operation, "slot" = "penis", "name" = "Original", "overwrite" = TRUE, "field" = "colors", "value" = list("#123456"))
		var/list/next = cyborg_layout_action(store, params, model_id)["store"]
		TEST_ASSERT(next, "Valid [operation] failed during ownership regression.")
		TEST_ASSERT_EQUAL(json_encode(store), before, "[operation] mutated the previous draft.")
		var/list/edited = cyborg_layout_action(next, list("operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = SOUTH), "changes" = list("pixel_x" = 31)), model_id)["store"]
		TEST_ASSERT(edited, "Placement after [operation] was rejected.")
		TEST_ASSERT_EQUAL(json_encode(store), before, "Placement after [operation] leaked through a shared branch.")
		if(edited["presets"]["Original"])
			TEST_ASSERT_NULL(edited["presets"]["Original"]["penis"]["placement_groups"]["south"], "Placement after [operation] mutated a saved preset.")
		if(edited["model_defaults"][model_id])
			TEST_ASSERT_NULL(edited["model_defaults"][model_id]["penis"]["placement_groups"]["south"], "Placement after [operation] mutated a saved default.")

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
	preferences.cyborg_session().discard_draft()
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	for(var/cycle in 1 to 3)
		TEST_ASSERT(editor.set_page(list("active" = TRUE), null), "Opening the creator was rejected.")
		TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = model_id, "direction" = NORTH), null), "Selecting a valid creator model was rejected.")
		// This content/lifecycle check starts after admission; pacing has its own test.
		editor.resource_refresh_at = world.time
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
		TEST_ASSERT_NULL(payload["models"], "Public gallery lists must not be serialized into private UI updates.")
		TEST_ASSERT(payload["gallery"]?["catalog_url"], "A closed gallery lost its public model catalog URL.")
		TEST_ASSERT_NULL(payload["gallery"]?["thumbnails_url"], "A closed gallery acquired department thumbnails.")
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
			TEST_ASSERT_NULL(editor.preview_resources, "Revoking permission generated or retained private resources before discarding them.")
			preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
			editor.resource_refresh_at = world.time
			editor.get_ui_data(null)
			TEST_ASSERT(editor.get_ui_static_data(null)["cyborg_resources"], "Restoring permission did not restore preview resources.")
		var/stale_context = editor.context_generation - 1
		TEST_ASSERT(!editor.set_preview(list("context" = stale_context, "model" = model_id), null), "A replaced context accepted a stale model action.")
		TEST_ASSERT(preferences.cyborg_session().draft_timer, "A creator edit did not schedule persistence.")
		// Leaving the cyborg page asks for a save without waiting for the debounce.
		editor.set_page(list("active" = FALSE), null)
		TEST_ASSERT(!editor.page_active && !length(editor.get_ui_data(null)), "Leaving the page left the creator active.")
		TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Leaving the page retained a deferred write callback.")
		TEST_ASSERT(cyborg_test_run_queued_save(preferences.cyborg_layout_store()), "Leaving the page did not queue a save.")
		TEST_ASSERT(!preferences.cyborg_session().dirty, "Leaving the page left accepted edits unsaved.")
		var/list/saved = preferences.read_cyborg_layout(1)
		TEST_ASSERT_EQUAL(saved["active"]["penis"]["placement_groups"]["north"]["pixel_x"], cycle, "Leaving the page lost the last creator edit.")
		TEST_ASSERT(!editor.edit_layout(edit, null), "A closed creator accepted a delayed edit.")
		TEST_ASSERT(!editor.set_preview(list("context" = editor.context_generation, "model" = model_id), null), "A closed creator accepted a delayed preview action.")

	editor.set_page(list("active" = TRUE), null)
	TEST_ASSERT(!editor.set_page(list("unexpected" = FALSE), null), "Unknown page input closed the editor.")
	TEST_ASSERT(editor.page_active, "Malformed page input changed the editor lifecycle.")
	editor.discard_draft()
	var/list/future = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	preferences.cyborg_layout_store().set_entry("character1", future)
	var/list/unsupported = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(unsupported["unsupported"] && length(unsupported["message"]), "A future schema did not show a read-only preservation notice in the creator.")
	TEST_ASSERT_EQUAL(editor.resource_key, "unsupported", "Unsupported data must record its invalidation before a full update can re-enter ui_data.")
	editor.get_ui_data(null)
	TEST_ASSERT_EQUAL(editor.resource_key, "unsupported", "Repeated unsupported updates reset their static invalidation guard.")
	editor.set_page(list("active" = FALSE), null)
	TEST_ASSERT(preferences.read_cyborg_layout(1) == future, "Closing the unsupported creator rewrote the future schema.")

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
	var/unrelated_model = cyborg_appearance_model_id(/obj/item/robot_model/medical, "Drake")
	draft["model_defaults"][unrelated_model] = cyborg_layout_copy(model_default)
	draft["presets"]["Saved"] = cyborg_layout_copy(model_default)
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "The model-default fixture was not accepted.")
	var/list/payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["store"]["presets"]["Saved"], TRUE, "The UI must receive preset names without saved layout bodies.")
	TEST_ASSERT_EQUAL(length(payload["store"]["model_defaults"]), 0, "Active editing must not receive unread saved layout bodies.")
	TEST_ASSERT(payload["model_default_available"], "Compact active data lost saved-appearance availability.")
	TEST_ASSERT(islist(draft["presets"]["Saved"]) && islist(draft["model_defaults"][unrelated_model]), "Building the compact UI projection mutated saved snapshots.")
	TEST_ASSERT_EQUAL(payload["layout_source"], "active", "A newly opened creator must edit the active layout.")
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 7, "The active draft fixture was not retained.")
	var/pending_timer = editor.draft_timer
	TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "layout_source" = "model_default"), null), "Selecting the model-default preview was rejected.")
	payload = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(payload["layout_source"], "model_default", "A saved model default was not selected for preview.")
	TEST_ASSERT_EQUAL(length(payload["store"]["model_defaults"]), 1, "Saved-appearance view must receive only its selected model's layout.")
	TEST_ASSERT_EQUAL(payload["store"]["model_defaults"][model_id]["penis"]["pixel_x"], 31, "The viewed model default was lost from the UI projection.")
	TEST_ASSERT_EQUAL(payload["store"]["active"]["penis"]["pixel_x"], 7, "Previewing a model default mutated the active draft.")
	TEST_ASSERT(editor.draft_timer && editor.draft_timer != pending_timer, "Changing preview source did not reschedule its stale-context save callback.")
	deltimer(editor.draft_timer)
	editor.flush_timer(editor.draft_slot, editor.context_generation, editor.draft_revision)
	cyborg_test_run_queued_save(preferences.cyborg_layout_store())
	TEST_ASSERT(!editor.dirty, "Changing preview source invalidated the active draft's pending autosave.")
	var/other_model
	for(var/candidate in cyborg_model_catalog())
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

/// Rejected creator requests must leave the draft/context intact and skip save preparation.
/datum/unit_test/cyborg_creator_admission
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_creator_admission/Run()
	var/datum/preferences/cyborg_save_failure_test/preferences = create_preferences(preference_type = /datum/preferences/cyborg_save_failure_test)
	preferences.default_slot = 1
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.value_cache = list()
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	TEST_ASSERT(editor.set_preview(list("context" = editor.context_generation, "model" = model_id), null), "A catalog model failed bounded preview admission.")
	for(var/id, descriptor in cyborg_model_catalog())
		TEST_ASSERT(length(id) <= CYBORG_PREVIEW_MAX_IDENTIFIER_LENGTH && length(descriptor["department"]) <= CYBORG_PREVIEW_MAX_IDENTIFIER_LENGTH, "A catalog identifier exceeds the preview input bound.")
	var/context = editor.context_generation
	var/long_text = repeat_string(100000, "x")
	TEST_ASSERT(!editor.set_preview(list("context" = context, "model" = long_text), null), "Oversized preview identifier was accepted.")
	TEST_ASSERT(!editor.set_preview(list("context" = context, "model" = list(model_id)), null), "Nested preview identifier was accepted.")
	TEST_ASSERT(!editor.set_preview(list("context" = context, "unexpected" = TRUE), null), "Unknown preview input was accepted.")
	TEST_ASSERT_EQUAL(editor.context_generation, context, "Rejected preview input replaced the context.")
	TEST_ASSERT_EQUAL(editor.preview_model, model_id, "Rejected preview input replaced the chassis.")
	var/list/draft = editor.begin_draft()
	var/before = json_encode(draft)
	var/sprite_reads = preferences.sprite_reads
	var/saves = preferences.save_preferences_calls
	for(var/name in list(long_text, "", "                         "))
		editor.edit_layout(list("character_slot" = 1, "context" = context, "operation" = "save", "name" = name), null)
	TEST_ASSERT_EQUAL(preferences.sprite_reads, sprite_reads, "Rejected preset names performed sprite snapshot preparation.")
	TEST_ASSERT_EQUAL(preferences.save_preferences_calls, saves, "Rejected preset names performed native saves.")
	TEST_ASSERT_EQUAL(json_encode(draft), before, "Rejected preset names mutated the draft.")
	TEST_ASSERT(editor.edit_layout(list("character_slot" = 1, "context" = context, "operation" = "save", "name" = "Valid"), null), "Valid preset save was rejected.")
	TEST_ASSERT(editor.draft["presets"]["Valid"], "Valid preset save did not retain its snapshot.")
	sprite_reads = preferences.sprite_reads
	saves = preferences.save_preferences_calls
	editor.edit_layout(list("character_slot" = 1, "context" = context, "operation" = "save", "name" = "Valid"), null)
	TEST_ASSERT_EQUAL(preferences.sprite_reads, sprite_reads, "Refused implicit overwrite performed snapshot preparation.")
	TEST_ASSERT_EQUAL(preferences.save_preferences_calls, saves, "Refused implicit overwrite performed a native save.")

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
	var/list/imported_layout = cyborg_layouts_from_import(list("character1" = list("silicon_genital_layout_presets" = legacy_layout)))["character1"]
	TEST_ASSERT_EQUAL(imported_layout["active"]["penis"]["advanced"]["rest_north"]["pixel_x"], 9, "Legacy pose aliases must expand only at the import boundary.")

	var/list/slot = list("headshot_silicon" = "https://i.gyazo.com/example.png", "headshot_silicon_nsfw" = "https://i.gyazo.com/example-nsfw.png", "silicon_genital_layout_presets" = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 8))))
	cyborg_identity_import_sanitize_slot(slot)
	TEST_ASSERT_EQUAL(slot["silicon_headshot"], "https://i.gyazo.com/example.png", "The donor headshot alias was not migrated.")
	TEST_ASSERT(!("headshot_silicon" in slot), "The donor headshot alias remained after import.")
	TEST_ASSERT_EQUAL(slot["silicon_headshot_nsfw"], "https://i.gyazo.com/example-nsfw.png", "The donor NSFW headshot alias was not migrated.")
	TEST_ASSERT(!("headshot_silicon_nsfw" in slot), "The donor NSFW headshot alias remained after import.")
	TEST_ASSERT(!("silicon_genital_layout_presets" in slot), "Imported layouts must not stay in preferences.json.")

	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 77)))
	var/list/layouts = cyborg_layouts_from_import(list(
		"character1" = list("silicon_genital_layout_presets" = future_layout),
		"character2" = list("silicon_genital_layout_presets" = list("schema_version" = 1, "active" = list("penis" = list("pixel_x" = 8)))),
		"character3" = list(),
		"characterX" = list("silicon_genital_layout_presets" = list("schema_version" = 1)),
	))
	TEST_ASSERT(layouts["character1"] == future_layout, "A future layout was rewritten during import.")
	TEST_ASSERT_EQUAL(layouts["character2"]["active"]["penis"]["pixel_x"], 8, "A current layout was not carried into the sidecar.")
	TEST_ASSERT_EQUAL(length(layouts), 2, "Slots without layouts or with malformed keys were carried into the sidecar.")

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
		var/raw_layout = preferences.read_cyborg_layout()
		TEST_FAIL("Current-schema draft was malformed (draft_list=[islist(draft)], active_list=[islist(draft_active)], penis_list=[islist(draft_penis)], raw_future=[cyborg_layout_import_is_future(raw_layout)]).")
		return
	draft["active"]["penis"]["pixel_x"] = 42
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "A current-schema draft must be accepted.")
	TEST_ASSERT(preferences.cyborg_session().draft_timer, "Draft updates must schedule a debounced flush.")
	preferences.cyborg_session().discard_draft()
	TEST_ASSERT_NULL(preferences.cyborg_session().draft, "Discard must clear the slot-bound draft.")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Discard must cancel the pending flush callback.")

	draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 17
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "A second draft update failed.")
	TEST_ASSERT(preferences.cyborg_session().commit_draft(), "A current-slot draft must flush.")
	var/flushed_slot = preferences.default_slot
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout(flushed_slot)["active"]["penis"]["pixel_x"], 17, "Flush did not write the current slot's layout.")

	// Deleting a slot forgets its layout and its unsaved draft, so a reused slot starts empty.
	draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 41
	TEST_ASSERT(preferences.cyborg_session().update_draft(draft), "The draft update before deletion failed.")
	preferences.remove_cyborg_layout_slot(flushed_slot)
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(flushed_slot), "Deleting a slot kept its layout.")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft, "Deleting a slot kept its unsaved draft.")
	TEST_ASSERT_NULL(preferences.cyborg_session().draft_timer, "Deleting a slot kept a pending write that would restore it.")

	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	preferences.cyborg_layout_store().set_entry("character[flushed_slot]", future_layout)
	TEST_ASSERT_NULL(preferences.cyborg_session().begin_draft(), "An unsupported future layout must not become an editable draft.")
	TEST_ASSERT(preferences.read_cyborg_layout(flushed_slot) == future_layout, "Opening the creator replaced future layout data.")

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
	var/datum/component/interactable/human_component = human.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(human_component, "The human interaction target lacked its component.")
	human_component.build_interactions_list()
	payload = human_component.ui_data(robot)
	TEST_ASSERT("Cheer" in payload["interactions"]["Miscellaneous"], "The cyborg viewer could not see the safe Cheer action on a human.")
	TEST_ASSERT_EQUAL(human_component.ui_status(robot), UI_INTERACTIVE, "A cyborg viewer could not use the human interaction menu.")
	TEST_ASSERT_EQUAL(component.ui_status(robot), UI_INTERACTIVE, "A cyborg could not use its own interaction menu.")
	payload = component.ui_data(robot)
	TEST_ASSERT("cyborg_runtime" in payload, "The cyborg's own interaction menu omitted its runtime controls.")
	TEST_ASSERT_NULL(component.get_interaction_route(cheer, human), "Cyborg targets must not enter human portal routing.")
	TEST_ASSERT_NULL(human_component.get_interaction_route(cheer, robot), "Cyborg actors must not enter human portal routing.")

	var/datum/tgui/human_ui = allocate(/datum/tgui, human, component, "InteractionPanel")
	var/datum/tgui/robot_ui = allocate(/datum/tgui, robot, human_component, "InteractionPanel")
	human_ui.status = UI_INTERACTIVE
	robot_ui.status = UI_INTERACTIVE
	component.interact_next = world.time - 1
	human_component.interact_next = world.time - 1
	TEST_ASSERT(component.ui_act("interact", list("interaction" = cheer.name), human_ui), "The bound UI rejected a human cheering at a cyborg.")
	TEST_ASSERT_EQUAL(component.interact_next, human_component.interact_next, "A cyborg interaction did not share the cooldown between participants.")
	TEST_ASSERT(!human_component.ui_act("interact", list("interaction" = cheer.name), robot_ui), "Reversing actor and target bypassed the shared cooldown.")
	component.interact_next = world.time - 1
	human_component.interact_next = world.time - 1
	TEST_ASSERT(human_component.ui_act("interact", list("interaction" = cheer.name), robot_ui), "The bound UI rejected a cyborg cheering at a human.")
	component.interact_next = world.time - 1
	human_component.interact_next = world.time - 1
	TEST_ASSERT(!human_component.ui_act("interact", list("interaction" = cheer.name), human_ui), "A foreign component's UI entered cyborg interaction dispatch.")
	TEST_ASSERT(!component.ui_act("set_genital_visibility", list(), human_ui), "A human body action was accepted for a cyborg target.")
	TEST_ASSERT(!human_component.ui_act("set_all_underwear_visibility", list(), robot_ui), "A cyborg actor entered human body configuration.")
	TEST_ASSERT(!component.ui_act("interact", list("item_slot" = ORGAN_SLOT_PENIS), human_ui), "A cyborg target entered human item interaction handling.")
	cheer.lewd = TRUE
	TEST_ASSERT(!component.ui_act("interact", list("interaction" = cheer.name), human_ui), "A cyborg interaction dispatched a lewd message outside its whitelist.")

/datum/unit_test/cyborg_future_layout_apply_preserves_raw_data/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	var/list/future_layout = list("schema_version" = 2, "active" = list("penis" = list("pixel_x" = 99)))
	preferences.cyborg_layout_store().set_entry("character1", future_layout)
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	robot.cyborg_appearance_store = cyborg_layout_default()
	robot.cyborg_appearance_layout = cyborg_layout_copy(robot.cyborg_appearance_store["active"])
	robot.cyborg_appearance_active = list("penis" = TRUE)
	robot.cyborg_appearance_slot = preferences.default_slot
	robot.cyborg_appearance_owner = "previous_owner"
	apply_cyborg_customization(robot, preferences)
	TEST_ASSERT(preferences.read_cyborg_layout(1) == future_layout, "Applying a future schema layout rewrote the preserved raw save data.")
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
	var/list/draft = preferences.cyborg_session().begin_draft()
	draft["active"]["penis"]["pixel_x"] = 11
	var/other_model = cyborg_appearance_model_id(/obj/item/robot_model/service, "Drake")
	var/list/other_default = cyborg_layout_copy(draft["active"])
	other_default["penis"]["pixel_x"] = 22
	draft["model_defaults"][other_model] = other_default
	draft["presets"]["Editor only"] = cyborg_layout_copy(draft["active"])
	apply_cyborg_customization(robot, preferences)
	TEST_ASSERT_NULL(robot.cyborg_appearance_store["presets"], "Spawn retained the editor's unused preset library.")
	var/starting_size = robot.cyborg_appearance_requested_size
	var/datum/preference_middleware/cyborg_character/editor = new(preferences)
	allocated += editor
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_size], 2.5)
	editor.post_set_preference(robot, "cyborg_size", 2.5)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_requested_size, starting_size, "Creator size edits must not resize a spawned body.")
	apply_cyborg_customization(robot, preferences)
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
	var/obj/effect/client_image_holder/cyborg_customization/holder = robot.cyborg_appearance_holder
	// Emulate companion images retained from a previous plane-offset level.
	// RuntimeStation has no stacked levels; exercise the native transition hook directly.
	holder.occlusion_image.plane = GET_NEW_PLANE(GAME_PLANE, 1)
	holder.animation_image.plane = GET_NEW_PLANE(GAME_PLANE, 1)
	var/turf/current_turf = get_turf(robot)
	holder.on_changed_z_level(current_turf, current_turf, FALSE)
	var/current_plane = MUTATE_PLANE(GAME_PLANE, current_turf)
	TEST_ASSERT_EQUAL(holder.shown_image.plane, current_plane, "A plane transition left the part image on another plane.")
	TEST_ASSERT_EQUAL(holder.occlusion_image.plane, current_plane, "A plane transition left the occlusion mask behind.")
	TEST_ASSERT_EQUAL(holder.animation_image.plane, current_plane, "A plane transition left the movement carrier behind.")
	TEST_ASSERT(length(holder.shown_image.filters), "A plane transition discarded the native animation filter.")
	TEST_ASSERT_EQUAL(holder.shown_image.filters[1]:size, 127, "A plane transition changed animation displacement.")
	draft["active"]["penis"]["pixel_x"] = 88
	other_default["penis"]["pixel_x"] = 99
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/service(robot)
	robot.model.cyborg_customization_skin = "Drake"
	robot.cyborg_customization_refresh_model()
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_layout["penis"]["pixel_x"], 22, "Switching chassis read later editor edits instead of the spawn default snapshot.")
	TEST_ASSERT(robot.cyborg_runtime_data()["model_default"], "The projected snapshot lost its runtime model-default badge.")
	QDEL_NULL(robot.model)
	robot.model = new /obj/item/robot_model/engineering(robot)
	robot.model.cyborg_customization_skin = "Drake"
	robot.cyborg_customization_refresh_model()
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_layout["penis"]["pixel_x"], 11, "Switching back lost the original fallback snapshot.")

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
	var/full_name = "abcdefghijklmnopqrstuvwx"
	store = cyborg_layout_action(store, list("operation" = "save", "name" = full_name), model_a)["store"]
	store = cyborg_layout_action(store, list("operation" = "assign_default", "name" = full_name), model_a)["store"]
	store = cyborg_layout_normalize(json_decode(json_encode(store)))
	TEST_ASSERT(store["presets"][full_name], "A valid 24-character preset name was truncated by save/load normalization.")
	TEST_ASSERT_EQUAL(store["preset_models"][full_name], model_a, "Roundtrip lost the full-length preset's model binding.")
	TEST_ASSERT_EQUAL(store["active_preset"], full_name, "Roundtrip lost the active preset name.")
	TEST_ASSERT_EQUAL(store["model_presets"][model_a], full_name, "Roundtrip lost the named spawn assignment.")
	var/before_copy = json_encode(store)
	var/list/copied = cyborg_layout_copy(store)
	copied["active"]["penis"]["pixel_x"] = 88
	copied["model_defaults"][model_a]["penis"]["pixel_x"] = 99
	TEST_ASSERT_EQUAL(json_encode(store), before_copy, "The stored copy aliased the editor draft.")

/datum/unit_test/cyborg_imported_preset_names/Run()
	var/model_a = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/model_b = cyborg_appearance_model_id(/obj/item/robot_model/service, "Drake")
	var/list/first = cyborg_layout_default_slots()
	first["penis"]["pixel_x"] = 7
	var/list/collision = cyborg_layout_default_slots()
	collision["penis"]["pixel_x"] = 99
	var/list/raw = list(
		"presets" = list(" Workshop " = first, "Workshop" = collision),
		"preset_models" = list(" Workshop " = model_a, "Workshop" = model_b),
		"active_preset" = " Workshop ",
		"model_defaults" = list(),
		"model_presets" = list(),
	)
	raw["model_defaults"][model_a] = first
	raw["model_defaults"][model_b] = collision
	raw["model_presets"][model_a] = " Workshop "
	raw["model_presets"][model_b] = "Workshop"
	var/list/normalized = cyborg_layout_normalize(raw, allow_legacy_aliases = TRUE)
	TEST_ASSERT_EQUAL(length(normalized["presets"]), 1, "Canonical name collisions must retain the first accepted preset only.")
	TEST_ASSERT_EQUAL(normalized["presets"]["Workshop"]["penis"]["pixel_x"], 7, "A colliding preset replaced the accepted geometry.")
	TEST_ASSERT_EQUAL(normalized["preset_models"]["Workshop"], model_a, "A colliding preset supplied metadata to the accepted preset.")
	TEST_ASSERT_EQUAL(normalized["active_preset"], "Workshop", "Trimming an imported name lost its active reference.")
	TEST_ASSERT_EQUAL(normalized["model_presets"][model_a], "Workshop", "Trimming an imported name lost its spawn assignment.")
	TEST_ASSERT_NULL(normalized["model_presets"][model_b], "A rejected colliding preset retained its named assignment.")
	normalized["presets"]["Workshop"]["penis"]["pixel_x"] = 12
	TEST_ASSERT_EQUAL(normalized["model_defaults"][model_a]["penis"]["pixel_x"], 7, "Normalized preset and default snapshots shared mutable entries.")
	TEST_ASSERT_EQUAL(first["penis"]["pixel_x"], 7, "Normalization mutated the imported input.")

/datum/unit_test/cyborg_slot_deletion_clears_layout
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_slot_deletion_clears_layout/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.max_save_slots = 2
	preferences.savefile.set_entry("character1", list("version" = 52))
	preferences.savefile.set_entry("character2", list("version" = 52))
	preferences.default_slot = 2
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 19
	editor.update_draft(draft)
	TEST_ASSERT(editor.commit_draft(), "The slot-two layout could not be written.")
	draft["active"]["penis"]["pixel_x"] = 20
	editor.update_draft(draft)
	var/list/slot_one = cyborg_layout_default()
	slot_one["active"]["penis"]["pixel_x"] = 7
	preferences.write_cyborg_layout(1, slot_one)
	// Switching slots redraws the character preview.
	preferences.character_preview_view = allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	var/datum/tgui/ui = allocate(/datum/tgui, null, preferences, "PreferencesMenu")
	ui.status = UI_INTERACTIVE
	preferences.ui_act("remove_current_slot", list(), ui)
	TEST_ASSERT_EQUAL(preferences.default_slot, 1, "Deleting the slot did not move to the remaining character.")
	TEST_ASSERT_NULL(preferences.read_cyborg_layout(2), "Deleting a character kept its cyborg layout.")
	TEST_ASSERT(!editor.dirty && !editor.draft_timer, "Deleting a character kept a pending write that would restore its layout.")
	TEST_ASSERT_EQUAL(editor.begin_draft()["active"]["penis"]["pixel_x"], 7, "The remaining character's layout was not loaded.")

/// Job spawns, ghost cafe and mapped ghost roles, mind transfers and admin direct control all reach transfer_silicon_prefs().
/datum/unit_test/cyborg_customization_applies_through_silicon_prefs
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_customization_applies_through_silicon_prefs/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/list/layout = cyborg_layout_default()
	layout["active"]["penis"]["pixel_x"] = 13
	preferences.write_cyborg_layout(preferences.default_slot, layout)
	TEST_ASSERT_NULL(robot.cyborg_appearance_store, "The fixture body started with a customization snapshot.")
	TEST_ASSERT(istype(robot.mmi, /obj/item/brain_processor/organic), "The fixture body must start with an organic processor so the brain preference replaces it.")
	robot.transfer_silicon_prefs(robot.mock_client)
	// The brain preference runs first; a runtime there would skip every later silicon preference.
	TEST_ASSERT(istype(robot.mmi, /obj/item/brain_processor/positronic), "The default positronic brain preference was not applied.")
	TEST_ASSERT_EQUAL(robot.mmi.brainmob?.real_name, robot.real_name, "The replacement processor's brainmob lost the cyborg's name.")
	TEST_ASSERT(robot.cyborg_appearance_store, "transfer_silicon_prefs() did not apply cyborg customization.")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_store["active"]["penis"]["pixel_x"], 13, "The applied snapshot did not come from the layout sidecar.")
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_choices["penis"], "Dogborg Knotted", "The applied snapshot lost the sprite preference.")
	// A second pass, as when a job spawn is followed by its mind transfer, keeps the body's snapshot.
	robot.cyborg_appearance_active["penis"] = FALSE
	layout["active"]["penis"]["pixel_x"] = 99
	preferences.write_cyborg_layout(preferences.default_slot, layout)
	robot.transfer_silicon_prefs(robot.mock_client)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_store["active"]["penis"]["pixel_x"], 13, "Re-entering the same body replaced its spawn snapshot.")
	TEST_ASSERT(!robot.cyborg_appearance_active["penis"], "Re-entering the same body reset its runtime state.")
	TEST_ASSERT(robot._listen_lookup?[COMSIG_MOB_MIND_TRANSFERRED_INTO], "Cyborgs must apply silicon preferences on mind transfer.")
	TEST_ASSERT(robot._listen_lookup?[COMSIG_MOB_GIVE_DIRECT_CONTROL], "Cyborgs must apply silicon preferences on admin direct control.")
	TEST_ASSERT(robot.GetComponent(/datum/component/interactable), "Cyborgs must carry the interaction component.")

/// Regression coverage for failed-write ownership, backend close and forced model installation.
/datum/json_savefile/cyborg_customization/review_failure_store
	var/fail_writes = FALSE
	var/write_attempts = 0
	var/successful_writes = 0
	/// Character key -> the tree that write held, save text decoded.
	var/list/last_written

/datum/json_savefile/cyborg_customization/review_failure_store/save()
	write_attempts++
	if(fail_writes)
		return FALSE
	successful_writes++
	last_written = list()
	for(var/key, stored in get_entry())
		last_written[key] = istext(stored) ? cyborg_layout_decode(stored) : deep_copy_list(stored)
	return TRUE

/// Runs the save SScyborg_layout_saves would run for `store` on its next fire. Returns FALSE while none is due.
/proc/cyborg_test_run_queued_save(datum/json_savefile/cyborg_customization/store)
	if(!(store in SScyborg_layout_saves.queue) || (store.path && world.time < store.next_write_at))
		return FALSE
	SScyborg_layout_saves.queue -= store
	store.run_save()
	return TRUE

/datum/unit_test/cyborg_review_failed_slot_write_retry
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_review_failed_slot_write_retry/Run()
	var/datum/preferences/preferences = create_preferences()
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = allocate(/datum/json_savefile/cyborg_customization/review_failure_store, null)
	preferences.cyborg_layout_savefile = store
	preferences.default_slot = 1
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 23
	editor.update_draft(draft)
	store.fail_writes = TRUE
	preferences.default_slot = 2
	editor.begin_draft()
	store.fail_writes = FALSE
	editor.commit_draft()
	TEST_ASSERT_EQUAL(store.successful_writes, 1, "Recovering storage and retrying after a slot switch did not write the old pending layout.")
	TEST_ASSERT_EQUAL(store.last_written["character1"]["active"]["penis"]["pixel_x"], 23, "Retry lost the original slot's accepted edit.")
	TEST_ASSERT_NULL(store.last_written["character2"], "Retry wrote an untouched second slot.")

/datum/unit_test/cyborg_review_forced_model_identity
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_review_forced_model_identity/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	robot.model.transform_to(/obj/item/robot_model/engineering, TRUE, FALSE)
	// Complete the installed appearance without waiting for the cosmetic transform animation.
	robot.update_icons()
	robot.transfer_silicon_prefs(robot.mock_client)
	TEST_ASSERT(robot.cyborg_appearance_model, "Forced stock model creation did not establish customization identity.")
	TEST_ASSERT(cyborg_model_catalog()[robot.cyborg_appearance_model], "Forced stock model identity does not resolve to its actual chassis.")
	TEST_ASSERT(length(robot.cyborg_appearance_holder?.render_layers), "A configured forced stock model rendered no custom parts.")

/datum/unit_test/cyborg_review_backend_ui_close
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_review_backend_ui_close/Run()
	var/datum/preferences/preferences = create_preferences()
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 17
	editor.update_draft(draft)
	editor.preview_resources = list("review" = "private-resource")
	preferences.ui_close(null)
	TEST_ASSERT(!editor.page_active, "Backend UI close left the cyborg editor active.")
	TEST_ASSERT_NULL(editor.preview_resources, "Backend UI close retained private preview resources.")
	TEST_ASSERT(cyborg_test_run_queued_save(preferences.cyborg_layout_store()), "Backend UI close did not queue a save.")
	TEST_ASSERT(!editor.dirty && !editor.draft_timer, "Backend UI close did not flush an accepted layout edit.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout()["active"]["penis"]["pixel_x"], 17, "Backend UI close lost the accepted layout.")

/datum/unit_test/cyborg_idempotent_save_and_account_write_pacing
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_idempotent_save_and_account_write_pacing/Run()
	var/datum/preferences/preferences = create_preferences()
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = allocate(/datum/json_savefile/cyborg_customization/review_failure_store, null)
	// The test writer counts calls without opening this path; exercise disk admission.
	store.path = "review-counter-no-file"
	preferences.cyborg_layout_savefile = store
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.preview_model = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	editor.begin_draft()
	var/list/command = list("operation" = "save_default", "character_slot" = preferences.default_slot, "context" = editor.context_generation)
	editor.edit_layout(command, null)
	TEST_ASSERT_EQUAL(store.write_attempts, 0, "An explicit save wrote the account inside its action.")
	TEST_ASSERT(cyborg_test_run_queued_save(store), "An explicit save did not queue the account's save.")
	TEST_ASSERT_EQUAL(store.successful_writes, 1, "The initial explicit save was not durable.")
	var/revision = editor.draft_revision
	for(var/index in 1 to 20)
		editor.edit_layout(command, null)
	store.next_write_at = world.time
	cyborg_test_run_queued_save(store)
	TEST_ASSERT_EQUAL(store.write_attempts, 1, "Identical explicit saves repeated the whole-account write.")
	store.next_write_at = world.time + 2 SECONDS
	TEST_ASSERT_EQUAL(editor.draft_revision, revision, "An identical save created a new edit revision.")
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 12
	editor.update_draft(draft)
	editor.edit_layout(command, null)
	TEST_ASSERT(!cyborg_test_run_queued_save(store), "A changed save ran inside the account write interval.")
	TEST_ASSERT_EQUAL(store.write_attempts, 1, "A changed save bypassed the account write interval.")
	TEST_ASSERT((store in SScyborg_layout_saves.queue) && editor.save_requested && editor.dirty, "A coalesced save lost its pending ownership.")
	editor.close_editor()
	TEST_ASSERT_EQUAL(store.write_attempts, 1, "Closing the editor bypassed the account write interval.")
	TEST_ASSERT_NULL(editor.draft_timer, "Backend close retained the editor debounce instead of the queued save.")
	store.next_write_at = world.time
	TEST_ASSERT(cyborg_test_run_queued_save(store), "The due account save was no longer queued.")
	TEST_ASSERT_EQUAL(preferences.read_cyborg_layout()["active"]["penis"]["pixel_x"], 12, "The queued save did not stage the latest accepted edit.")
	TEST_ASSERT_EQUAL(store.successful_writes, 2, "The due account write did not save the latest state.")
	TEST_ASSERT(!store.write_pending && !editor.dirty, "A successful delayed write left false pending state.")
	TEST_ASSERT_EQUAL(store.last_written["character[preferences.default_slot]"]["active"]["penis"]["pixel_x"], 12, "Coalescing saved an earlier revision.")
	// Both unnamed and named snapshots have idempotent explicit save semantics.
	store.next_write_at = world.time
	command["operation"] = "save"
	command["name"] = "Repeated setup"
	command["context"] = editor.context_generation
	editor.set_page(list("active" = TRUE), null)
	editor.edit_layout(command, null)
	cyborg_test_run_queued_save(store)
	var/named_writes = store.write_attempts
	command["overwrite"] = TRUE
	for(var/index in 1 to 20)
		editor.edit_layout(command, null)
	store.next_write_at = world.time
	cyborg_test_run_queued_save(store)
	TEST_ASSERT_EQUAL(store.write_attempts, named_writes, "Identical named preset overwrites repeated account writes.")

/datum/unit_test/cyborg_failed_retry_is_paced_across_slots
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_failed_retry_is_paced_across_slots/Run()
	var/datum/preferences/preferences = create_preferences()
	var/datum/json_savefile/cyborg_customization/review_failure_store/store = allocate(/datum/json_savefile/cyborg_customization/review_failure_store, null)
	store.path = "review-counter-no-file"
	store.fail_writes = TRUE
	preferences.cyborg_layout_savefile = store
	preferences.default_slot = 1
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = editor.begin_draft()
	draft["active"]["penis"]["pixel_x"] = 27
	editor.update_draft(draft)
	TEST_ASSERT(!editor.commit_draft(), "The injected failed write was acknowledged.")
	var/list/staged = store.get_entry("character1")
	for(var/index in 1 to 20)
		editor.commit_draft()
	TEST_ASSERT_EQUAL(store.write_attempts, 1, "Repeated failed retries bypassed disk admission.")
	TEST_ASSERT_EQUAL(store.get_entry("character1"), staged, "Retrying recopied an unchanged full character tree.")
	preferences.default_slot = 2
	editor.begin_draft()
	TEST_ASSERT(store.write_pending && editor.save_error, "Changing slots concealed the pending failed account write.")
	TEST_ASSERT_EQUAL(store.write_attempts, 1, "Changing slots bypassed failed-write pacing.")
	store.fail_writes = FALSE
	store.next_write_at = world.time
	editor.commit_draft()
	TEST_ASSERT_EQUAL(store.successful_writes, 1, "Recovered storage did not flush the old pending slot.")
	TEST_ASSERT_EQUAL(store.last_written["character1"]["active"]["penis"]["pixel_x"], 27, "Retry after slot replacement lost its accepted edit.")
	TEST_ASSERT_NULL(store.last_written["character2"], "Retry wrote a clean unrelated slot.")
	TEST_ASSERT(!editor.save_error && !store.write_pending, "Recovery retained false pending or error state.")

// Focused behavior probes for cached geometry and bounded latest-state refresh.
/datum/unit_test/cyborg_cached_preview_geometry/Run()
	var/list/descriptor = cyborg_model_catalog()[cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")]
	var/list/layout = cyborg_layout_default_slots()
	layout["penis"]["pixel_x"] = 7
	var/list/cached = list("penis" = "review-owned-png")
	var/list/runtime = list("choices" = list("penis" = "Dogborg Knotted"), "active" = list("penis" = TRUE), "arousal" = list("penis" = "none"), "direction" = SOUTH, "pose" = "idle", "cached_icons" = cached)
	var/list/layers = cyborg_build_appearance(descriptor, layout, runtime)
	TEST_ASSERT_EQUAL(length(layers), 1, "Cached preview geometry lost its visible part.")
	var/list/layer = layers[1]
	TEST_ASSERT_EQUAL(layer["icon"], cached["penis"], "A geometry-only preview regenerated pixels instead of reusing its owned PNG.")
	TEST_ASSERT_NULL(layer["resource"], "Preview-only reuse retained a native icon unnecessarily.")
	var/list/anchor = cyborg_animation_anchor(descriptor, SOUTH, "idle")
	TEST_ASSERT_EQUAL(layer["x"], 7 + anchor["x"], "Cached pixels changed shared placement geometry.")

/datum/unit_test/cyborg_latest_pixel_refresh
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_latest_pixel_refresh/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.default_slot = 1
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")), null)
	editor.get_ui_data(null)
	var/list/resources = editor.preview_resources
	editor.set_preview(list("context" = editor.context_generation, "direction" = NORTH), null)
	var/list/edit = list("context" = editor.context_generation, "character_slot" = 1, "operation" = "set", "slot" = "penis", "field" = "colors", "value" = list("#112233", "#ffffff", "#ffffff"))
	editor.edit_layout(edit, null)
	var/list/pending = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(editor.preview_resources == resources && pending["resources_pending"], "A second pixel edit in one budget interval rebuilt resources immediately.")
	TEST_ASSERT_EQUAL(pending["direction"], NORTH, "Pending controls did not reflect the accepted direction.")
	TEST_ASSERT_EQUAL(pending["rendered_preview"]["direction"], SOUTH, "Pending resources were paired with new direction geometry.")
	var/pending_timer = editor.vars["resource_timer"]
	TEST_ASSERT(pending_timer, "A pending refresh was not scheduled.")
	edit["value"] = list("#445566", "#ffffff", "#ffffff")
	editor.edit_layout(edit, null)
	pending = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(editor.preview_resources == resources && editor.vars["resource_timer"] == pending_timer, "New input replaced the one bounded refresh timer or rebuilt the previous request.")
	TEST_ASSERT_EQUAL(pending["store"]["active"]["penis"]["colors"][1], "#445566", "Controls did not expose the latest accepted draft while pixels waited.")
	sleep(1.1 SECONDS)
	var/list/ready = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!ready["resources_pending"] && editor.preview_resources != resources, "The budget did not eventually publish latest-state pixels.")
	TEST_ASSERT_EQUAL(ready["direction"], NORTH, "Completed pixels retained the old preview direction.")
	TEST_ASSERT_EQUAL(editor.rendered_preview["direction"], NORTH, "Completed pixels did not retain their coherent server stage.")
	var/list/rendered = cyborg_accessory_render("penis", "Dogborg Knotted", list("#445566", "#ffffff", "#ffffff"), "none", NORTH, 2)
	TEST_ASSERT_EQUAL(editor.preview_resources["layer_icons"]["penis"], rendered["base64"], "Deferred work published a stale intermediate color.")
	edit["value"] = list("#778899", "#ffffff", "#ffffff")
	editor.edit_layout(edit, null)
	editor.get_ui_data(null)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], FALSE)
	var/list/denied = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_NULL(editor.preview_resources, "Permission revocation waited for pixel refresh pacing.")
	TEST_ASSERT_NULL(editor.vars["resource_timer"], "Permission revocation retained a private resource job.")
	TEST_ASSERT(!denied["resources_pending"] && !length(denied["layers"]), "Denied content retained a pending preview or visible layers.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	TEST_ASSERT(editor.get_ui_data(null)["cyborg_customization"]["resources_pending"], "Consent toggling bypassed pixel refresh admission.")
	editor.set_page(list("active" = FALSE), null)
	TEST_ASSERT_NULL(editor.resource_timer, "Closing the page retained a resource refresh callback.")
	editor.set_page(list("active" = TRUE), null)
	TEST_ASSERT(editor.get_ui_data(null)["cyborg_customization"]["resources_pending"], "Closing and reopening bypassed pixel refresh admission.")
	editor.set_page(list("active" = FALSE), null)
	sleep(1.1 SECONDS)
	TEST_ASSERT(!length(editor.get_ui_data(null)) && !editor.preview_resources, "A stale deferred callback resurrected a closed preview.")

/datum/unit_test/cyborg_color_refresh_reuses_unaffected_resources
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_color_refresh_reuses_unaffected_resources/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	preferences.write_preference(GLOB.preference_entries_by_key["silicon_sheath_sprite"], "Dogborg Knotted Sheath")
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake"), "selected_part" = "sheath", "gallery_open" = TRUE, "gallery_department" = "Engineering"), null)
	editor.get_ui_data(null)
	var/list/previous = editor.preview_resources
	var/list/gallery = previous["gallery"]
	var/list/parts = previous["parts"]
	var/list/animation = previous["animation"]
	// A sentinel proves an unrelated image is retained, independently of global cache hits.
	previous["layer_icons"]["penis"] = "review-owned-unaffected-png"
	var/list/colors = list("#112233", "#445566", "#778899")
	editor.edit_layout(list("context" = editor.context_generation, "character_slot" = preferences.default_slot, "operation" = "set", "slot" = "sheath", "field" = "colors", "value" = colors), null)
	editor.resource_refresh_at = world.time
	editor.get_ui_data(null)
	var/list/current = editor.preview_resources
	TEST_ASSERT(current != previous, "A changed color did not publish a new resource payload.")
	TEST_ASSERT_EQUAL(current["gallery"], gallery, "A color edit rebuilt the unchanged public gallery descriptor.")
	TEST_ASSERT_EQUAL(current["animation"], animation, "A color edit rebuilt unchanged animation frames.")
	for(var/slot in cyborg_layout_supported_slots())
		TEST_ASSERT_EQUAL(current["parts"][slot], parts[slot], "A color edit rebuilt neutral size metadata for [slot].")
	TEST_ASSERT_EQUAL(current["layer_icons"]["penis"], "review-owned-unaffected-png", "A color edit regenerated an unaffected part.")
	var/list/rendered = cyborg_accessory_render("sheath", "Dogborg Knotted Sheath", colors, "none", SOUTH, cyborg_layout_default_sprite_size("sheath"))
	TEST_ASSERT_EQUAL(current["layer_icons"]["sheath"], rendered["base64"], "The changed part did not use the accepted colors.")
	var/list/size_entry = current["parts"]["sheath"]["sizes"][1]
	var/list/neutral = cyborg_accessory_render("sheath", "Dogborg Knotted Sheath", list("#ffffff", "#ffffff", "#ffffff"), "none", SOUTH, size_entry["value"])
	TEST_ASSERT_EQUAL(size_entry["icon"], neutral["base64"], "Size thumbnails no longer use stable neutral artwork.")

/datum/unit_test/cyborg_metadata_refresh_keeps_placement_live
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_metadata_refresh_keeps_placement_live/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")), null)
	var/list/before = editor.get_ui_data(null)["cyborg_customization"]["layers"][1]
	var/list/resources = editor.preview_resources
	editor.set_preview(list("context" = editor.context_generation, "selected_part" = "sheath"), null)
	editor.edit_layout(list("context" = editor.context_generation, "character_slot" = preferences.default_slot, "operation" = "set_placement", "slot" = "penis", "target" = list("scope" = "base", "direction" = SOUTH), "changes" = list("pixel_x" = 9)), null)
	TEST_ASSERT_EQUAL(editor.draft["active"]["penis"]["placement_groups"]["south"]["pixel_x"], 9, "The placement command was not accepted into the active draft.")
	var/list/current = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(current["resources_pending"] && !current["preview_pending"], "Metadata-only work blocked an unchanged stage.")
	TEST_ASSERT_EQUAL(editor.preview_resources, resources, "Metadata-only work bypassed the resource interval.")
	var/list/after = current["layers"][1]
	TEST_ASSERT_EQUAL(after["x"], before["x"] + 9, "A metadata refresh froze accepted placement geometry.")
	editor.set_preview(list("context" = editor.context_generation, "direction" = NORTH), null)
	current = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(current["preview_pending"], "A real pixel change failed to preserve the old coherent stage.")

/datum/unit_test/cyborg_gallery_shared_projection/Run()
	var/datum/asset/cyborg_model_gallery/gallery = get_asset_datum(/datum/asset/cyborg_model_gallery)
	var/list/catalog = cyborg_model_catalog()
	gallery.build_catalog(catalog)
	var/datum/asset_cache_item/catalog_asset = gallery.assets[gallery.catalog_asset]
	var/list/plain = json_decode(file2text(catalog_asset.resource))
	TEST_ASSERT_EQUAL(length(plain), length(catalog), "The shared gallery omitted catalog models.")
	var/list/closed = gallery.ui_descriptor(null)
	TEST_ASSERT_EQUAL(length(closed), 2, "Closed galleries must contain only catalog identity and URL.")
	TEST_ASSERT_EQUAL(closed["catalog_url"], SSassets.transport.get_asset_url(gallery.catalog_asset, catalog_asset), "The descriptor bypassed the configured asset transport.")
	TEST_ASSERT_EQUAL(length(gallery.assets), length(gallery.department_assets) + 1, "The gallery retained extra public projections.")
	var/list/owned_assets = gallery.assets
	gallery.build_catalog(catalog)
	TEST_ASSERT_EQUAL(gallery.assets, owned_assets, "An unchanged catalog rebuilt its encoded assets.")
	TEST_ASSERT_EQUAL(length(gallery.assets_for_department(null)), 1, "A closed gallery acquired more than its catalog.")
	for(var/repeat in 1 to 100)
		TEST_ASSERT(deep_compare_list(gallery.ui_descriptor("untrusted-[repeat]"), closed), "An unknown department exposed a thumbnail URL.")
		TEST_ASSERT_EQUAL(length(gallery.assets_for_department("untrusted-[repeat]")), 1, "Unknown input created an acquisition entry.")
	TEST_ASSERT_EQUAL(gallery.assets, owned_assets, "Unknown departments replaced the finite asset set.")
	for(var/list/model as anything in plain)
		TEST_ASSERT_EQUAL(length(model), 3, "Public metadata retained thumbnails or unrelated fields.")
		TEST_ASSERT(catalog[model["id"]] && model["department"] == catalog[model["id"]]["department"] && model["skin"] == catalog[model["id"]]["skin"], "Public metadata changed a model's canonical identity.")
	var/thumbnail_models = 0
	for(var/department, asset_name in gallery.department_assets)
		var/list/descriptor = gallery.ui_descriptor(department)
		TEST_ASSERT_EQUAL(length(descriptor), 4, "An open department descriptor has unexpected fields.")
		TEST_ASSERT_EQUAL(descriptor["department"], department, "Department identity was lost in the descriptor.")
		TEST_ASSERT_EQUAL(descriptor["generation"], closed["generation"], "Department and catalog generations disagree.")
		TEST_ASSERT_EQUAL(length(gallery.assets_for_department(department)), 2, "A selected department must acquire only its thumbnails and catalog.")
		var/datum/asset_cache_item/asset = gallery.assets[asset_name]
		TEST_ASSERT_EQUAL(descriptor["thumbnails_url"], SSassets.transport.get_asset_url(asset_name, asset), "Thumbnail URL bypassed the asset transport.")
		var/list/thumbnails = json_decode(file2text(asset.resource))
		for(var/id, directions in thumbnails)
			thumbnail_models++
			TEST_ASSERT_EQUAL(catalog[id]?["department"], department, "A department asset contains another department's model.")
			TEST_ASSERT_EQUAL(length(directions), 4, "A shared model is missing its directional thumbnails.")
			for(var/direction in GLOB.cardinals)
				TEST_ASSERT_EQUAL(directions["[direction]"], cyborg_preview_body(catalog[id], direction), "Asset thumbnails changed the authored appearance.")
	TEST_ASSERT_EQUAL(thumbnail_models, length(catalog), "Department assets duplicated or omitted catalog models.")

/datum/unit_test/cyborg_shared_asset_wait_rechecks_owner
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_shared_asset_wait_rechecks_owner/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/datum/asset/cyborg_model_gallery/gallery = get_asset_datum(/datum/asset/cyborg_model_gallery)
	editor.set_page(list("active" = TRUE), null)
	gallery.generating = TRUE
	spawn(1)
		editor.close_editor()
		gallery.generating = FALSE
	TEST_ASSERT(!length(editor.get_ui_data(null)), "A shared asset wait republished a closed editor.")
	TEST_ASSERT_NULL(editor.preview_resources, "A shared asset wait retained private pixels after close.")
	editor.set_page(list("active" = TRUE), null)
	gallery.generating = TRUE
	spawn(1)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], FALSE)
		gallery.generating = FALSE
	var/list/denied = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!denied["allowed"], "A shared asset wait ignored consent revocation.")
	TEST_ASSERT_NULL(editor.preview_resources, "A shared asset wait published pixels after consent revocation.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	gallery.generating = TRUE
	spawn(1)
		editor.set_preview(list("context" = editor.context_generation, "direction" = NORTH), null)
		gallery.generating = FALSE
	editor.resource_refresh_at = world.time
	var/list/current = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(current["direction"], NORTH, "A shared asset wait captured obsolete preview state.")
	TEST_ASSERT_EQUAL(editor.rendered_preview["direction"], NORTH, "A shared asset wait retained obsolete stage geometry.")

/// Pause public resource readiness without native jobs or retained private state.
/datum/asset/cyborg_occlusion/consumer_wait_test
	abstract_type = /datum/asset/cyborg_occlusion/consumer_wait_test
	var/released = FALSE
	var/calls = 0
	var/fail = FALSE
	var/list/ready_resources

/datum/asset/cyborg_occlusion/consumer_wait_test/ensure_model_ready(source_file, base_state)
	calls++
	UNTIL(released)
	if(fail)
		throw EXCEPTION("expected consumer readiness failure")
	var/key = "[source_file]#[base_state]"
	resources[key] = ready_resources[key]
	return resources[key]

/datum/unit_test/cyborg_demand_editor_latest_state
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_demand_editor_latest_state/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")), null)
	editor.get_ui_data(null)
	var/list/old_resources = editor.preview_resources
	var/list/old_stage = editor.rendered_preview
	var/datum/asset/cyborg_occlusion/original = get_asset_datum(/datum/asset/cyborg_occlusion)
	var/datum/asset/cyborg_occlusion/consumer_wait_test/paused = new
	paused.ready_resources = original.resources
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = paused
	editor.resource_refresh_at = world.time
	editor.set_preview(list("context" = editor.context_generation, "direction" = NORTH), null)
	for(var/repeat in 1 to 20)
		editor.get_ui_data(null)
	var/nonblocking = editor.occlusion_loading && editor.preview_pending && editor.preview_resources == old_resources && editor.rendered_preview == old_stage
	sleep(1)
	var/one_waiter = paused.calls == 1
	var/latest_model = cyborg_appearance_model_id(/obj/item/robot_model/medical, "Drake")
	editor.set_preview(list("context" = editor.context_generation, "model" = latest_model), null)
	editor.get_ui_data(null)
	var/still_one_waiter = paused.calls == 1
	paused.released = TRUE
	UNTIL(!editor.occlusion_loading)
	editor.get_ui_data(null)
	UNTIL(!editor.occlusion_loading)
	var/list/latest = editor.get_ui_data(null)["cyborg_customization"]
	var/latest_correct = latest["model"] == latest_model && editor.rendered_preview?["model"] == latest_model && !latest["preview_pending"]
	// Close while a different first-use request is pending; completion cannot revive it.
	paused.released = FALSE
	paused.resources = list()
	var/calls_before_close = paused.calls
	editor.resource_refresh_at = world.time
	editor.set_preview(list("context" = editor.context_generation, "direction" = SOUTH), null)
	editor.get_ui_data(null)
	editor.close_editor()
	paused.released = TRUE
	UNTIL(!editor.occlusion_loading)
	var/closed_stayed_empty = !editor.preview_resources && !length(editor.get_ui_data(null))
	var/close_skipped_admission = paused.calls == calls_before_close
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = original
	GLOB.asset_datums -= paused.type
	qdel(paused)
	TEST_ASSERT(nonblocking, "A missing model blocked UI reads or split the previous coherent stage.")
	TEST_ASSERT(one_waiter && still_one_waiter, "Repeated reads or model changes retained multiple editor continuations.")
	TEST_ASSERT(latest_correct, "An obsolete completion failed to prepare and publish the latest model.")
	TEST_ASSERT(closed_stayed_empty, "A public resource completion resurrected a closed private preview.")
	TEST_ASSERT(close_skipped_admission, "Closing before admission still generated an obsolete model.")

/datum/unit_test/cyborg_demand_holder_revocation
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_demand_holder_revocation/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
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
	apply_cyborg_customization(robot, preferences)
	var/obj/effect/client_image_holder/cyborg_customization/holder = robot.cyborg_appearance_holder
	var/datum/asset/cyborg_occlusion/original = get_asset_datum(/datum/asset/cyborg_occlusion)
	var/datum/asset/cyborg_occlusion/consumer_wait_test/paused = new
	paused.ready_resources = original.resources
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = paused
	for(var/repeat in 1 to 20)
		holder.render_key = null
		holder.update_from_owner()
	var/coherent_empty = holder.occlusion_loading && !length(holder.render_layers) && !length(holder.shown_image.overlays) && !holder.occlusion_image && !holder.animation_image
	sleep(1)
	var/one_waiter = paused.calls == 1
	robot.cyborg_appearance_allowed = FALSE
	paused.released = TRUE
	UNTIL(!holder.occlusion_loading)
	var/revoked = !length(holder.render_layers) && !holder.occlusion_image && !holder.animation_image
	paused.resources = list()
	paused.released = FALSE
	var/calls_before_delete = paused.calls
	robot.cyborg_appearance_allowed = TRUE
	holder.render_key = null
	holder.update_from_owner()
	var/datum/weakref/holder_ref = WEAKREF(holder)
	QDEL_NULL(robot.cyborg_appearance_holder)
	paused.released = TRUE
	sleep(2)
	var/deleted_stayed_empty = !holder_ref.resolve() && !robot.cyborg_appearance_holder
	var/delete_skipped_admission = paused.calls == calls_before_delete
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = original
	GLOB.asset_datums -= paused.type
	qdel(paused)
	TEST_ASSERT(coherent_empty, "A first-use live model exposed parts before its matching mask was ready.")
	TEST_ASSERT(one_waiter, "Owner churn created duplicate live resource continuations.")
	TEST_ASSERT(revoked, "A delayed resource completion ignored current owner consent.")
	TEST_ASSERT(deleted_stayed_empty, "A delayed completion revived a deleted holder.")
	TEST_ASSERT(delete_skipped_admission, "Deleting before admission still generated an obsolete model.")

/datum/unit_test/cyborg_demand_first_open_failure
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_demand_first_open_failure/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/datum/asset/cyborg_occlusion/original = get_asset_datum(/datum/asset/cyborg_occlusion)
	var/datum/asset/cyborg_occlusion/consumer_wait_test/paused = new
	paused.ready_resources = original.resources
	paused.fail = TRUE
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = paused
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")), null)
	editor.get_ui_data(null)
	var/can_choose_pending = editor.preview_resources?["gallery"]?["catalog_url"] && !editor.preview_resources?["models"]
	editor.set_preview(list("context" = editor.context_generation, "gallery_open" = TRUE, "gallery_department" = "Medical"), null)
	editor.get_ui_data(null)
	var/can_switch_pending = editor.preview_resources?["gallery"]?["department"] == "Medical" && editor.preview_resources?["gallery"]?["thumbnails_url"]
	paused.released = TRUE
	UNTIL(!editor.occlusion_loading)
	var/list/failed = editor.get_ui_data(null)["cyborg_customization"]
	var/can_choose_failed = editor.preview_resources?["gallery"]?["catalog_url"] && findtext(failed["message"], "Choose another model")
	paused.fail = FALSE
	var/healthy_model = cyborg_appearance_model_id(/obj/item/robot_model/medical, "Drake")
	editor.set_preview(list("context" = editor.context_generation, "model" = healthy_model), null)
	editor.get_ui_data(null)
	UNTIL(!editor.occlusion_loading)
	var/list/healthy = editor.get_ui_data(null)["cyborg_customization"]
	var/recovered = healthy["model"] == healthy_model && editor.rendered_preview?["model"] == healthy_model && !healthy["preview_pending"] && !findtext(healthy["message"], "could not be prepared")
	GLOB.asset_datums[/datum/asset/cyborg_occlusion] = original
	GLOB.asset_datums -= paused.type
	qdel(paused)
	TEST_ASSERT(can_choose_pending && can_switch_pending && can_choose_failed, "First-use generation failure trapped the user without a usable model picker.")
	TEST_ASSERT(recovered, "Switching to a ready model retained obsolete failure state or failed to publish the stage.")

/// UI assignment projection must not expose or mutate unrelated saved chassis assignments.
/datum/unit_test/cyborg_ui_assignment_projection
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_ui_assignment_projection/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	var/model_a = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/model_b = cyborg_appearance_model_id(/obj/item/robot_model/medical, "Drake")
	var/model_c = cyborg_appearance_model_id(/obj/item/robot_model/service, "Drake")
	var/list/draft = editor.begin_draft()
	draft["presets"]["Workshop"] = deep_copy_list(draft["active"])
	draft["presets"]["Infirmary"] = deep_copy_list(draft["active"])
	draft["preset_models"]["Workshop"] = model_a
	draft["preset_models"]["Infirmary"] = model_b
	draft["model_presets"][model_a] = "Workshop"
	draft["model_presets"][model_b] = "Infirmary"
	draft["model_defaults"][model_a] = deep_copy_list(draft["active"])
	draft["model_defaults"][model_b] = deep_copy_list(draft["active"])
	editor.set_preview(list("context" = editor.context_generation, "model" = model_a), null)
	var/list/first = editor.get_ui_data(null)["cyborg_customization"]["store"]
	TEST_ASSERT_EQUAL(length(first["model_presets"]), 1, "UI data included another chassis's assignment.")
	TEST_ASSERT_EQUAL(first["model_presets"][model_a], "Workshop", "UI data lost the selected chassis assignment.")
	TEST_ASSERT_EQUAL(length(first["preset_models"]), 2, "Projection removed preset labels needed to choose a different chassis.")
	first["model_presets"][model_a] = "UI-only value"
	TEST_ASSERT_EQUAL(draft["model_presets"][model_a], "Workshop", "UI assignment projection aliased the canonical draft.")
	editor.set_preview(list("context" = editor.context_generation, "model" = model_b), null)
	var/list/second = editor.get_ui_data(null)["cyborg_customization"]["store"]
	TEST_ASSERT_EQUAL(length(second["model_presets"]), 1, "Changing model retained a previous projected assignment.")
	TEST_ASSERT_EQUAL(second["model_presets"][model_b], "Infirmary", "Changing model failed to expose its saved assignment.")
	editor.set_preview(list("context" = editor.context_generation, "model" = model_c), null)
	var/list/unassigned = editor.get_ui_data(null)["cyborg_customization"]["store"]
	TEST_ASSERT_EQUAL(length(unassigned["model_presets"]), 0, "An unassigned chassis inherited stale UI assignment data.")
	TEST_ASSERT_EQUAL(draft["model_presets"][model_a], "Workshop", "Projection deleted another chassis's saved assignment.")
	TEST_ASSERT_EQUAL(draft["model_presets"][model_b], "Infirmary", "Projection changed the second saved assignment.")
	TEST_ASSERT_EQUAL(length(draft["model_defaults"]), 2, "UI projection changed the canonical saved appearance collection.")
	editor.discard_draft()

/// Availability is sufficient until the user opens the saved-appearance view.
/datum/unit_test/cyborg_ui_default_layout_projection
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_ui_default_layout_projection/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	editor.set_preview(list("context" = editor.context_generation, "model" = model_id), null)
	var/list/draft = editor.begin_draft()
	var/list/saved = deep_copy_list(draft["active"])
	saved["penis"]["pixel_x"] = 17
	draft["model_defaults"][model_id] = saved
	var/list/active = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(active["model_default_available"], "Omitting a saved layout hid its load/clear controls.")
	TEST_ASSERT_EQUAL(length(active["store"]["model_defaults"]), 0, "Active editing serialized an unread saved layout.")
	TEST_ASSERT_EQUAL(draft["model_defaults"][model_id]["penis"]["pixel_x"], 17, "Wire projection removed the canonical saved layout.")
	editor.set_preview(list("context" = editor.context_generation, "layout_source" = "model_default"), null)
	var/list/preview = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT_EQUAL(preview["layout_source"], "model_default", "Saved-appearance view was not selected.")
	TEST_ASSERT_EQUAL(length(preview["store"]["model_defaults"]), 1, "Saved-appearance view did not receive exactly its selected model.")
	TEST_ASSERT(deep_compare_list(preview["store"]["model_defaults"][model_id], saved), "Saved-appearance view lost layout controls or sprite data.")
	TEST_ASSERT_EQUAL(length(preview["store"]["model_defaults"][model_id]), 6, "Saved-appearance view omitted a part.")
	editor.set_preview(list("context" = editor.context_generation, "layout_source" = "active"), null)
	active = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(active["model_default_available"] && !length(active["store"]["model_defaults"]), "Returning to active editing retained a duplicate saved layout or lost availability.")
	TEST_ASSERT(editor.edit_layout(list("operation" = "delete_default", "model" = model_id, "character_slot" = preferences.default_slot, "context" = editor.context_generation), null), "The saved layout could not be deleted after projection.")
	var/list/deleted = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!deleted["model_default_available"] && !length(deleted["store"]["model_defaults"]), "Deleting the saved layout retained stale availability or payload.")
	editor.discard_draft()

/// Profile limits count UTF-8 bytes but must not split a Unicode codepoint.
/datum/unit_test/cyborg_profile_text_boundaries/proc/repeated(glyph, count)
	var/list/pieces = list()
	for(var/index in 1 to count)
		pieces += glyph
	return pieces.Join()

/datum/unit_test/cyborg_profile_text_boundaries/Run()
	var/list/profile_types = list(
		/datum/preference/text/custom_species_silicon,
		/datum/preference/text/custom_species_lore_silicon,
		/datum/preference/text/silicon_flavor_text,
		/datum/preference/text/silicon_flavor_text_nsfw,
		/datum/preference/text/ooc_notes_silicon,
		/datum/preference/text/ooc_notes_silicon/nsfw,
	)
	for(var/preference_type in profile_types)
		var/datum/preference/text/preference = GLOB.preference_entries[preference_type]
		var/budget = preference.maximum_value_length - 1
		var/list/constants = preference.compile_constant_data()
		TEST_ASSERT_EQUAL(constants["maximum_length"], budget, "The advertised upper limit includes an invalid exclusive endpoint.")
		TEST_ASSERT_EQUAL(constants["maximum_bytes"], budget, "The browser cannot enforce the native UTF-8 byte budget.")
		var/ascii = repeated("a", budget)
		TEST_ASSERT_EQUAL(preference.deserialize(ascii, null), ascii, "A boundary-sized ASCII value changed.")
		TEST_ASSERT_EQUAL(preference.deserialize("[ascii]z", null), ascii, "ASCII truncation changed the existing accepted budget.")
		for(var/glyph in list("é", "🦊"))
			var/prefix = repeated(glyph, round(budget / length(glyph)))
			var/output = preference.deserialize("[prefix][glyph]", null)
			TEST_ASSERT_EQUAL(output, prefix, "Truncating [preference_type] split or lost a complete [glyph] codepoint.")
			TEST_ASSERT(preference.is_valid(output, null), "Deserialization produced an invalid profile value.")
			TEST_ASSERT(length(output) <= budget, "Profile truncation widened the saved byte budget.")
		var/mixed = "[repeated("a", budget - 2)]é"
		TEST_ASSERT_EQUAL(preference.deserialize("[mixed]z", null), mixed, "Mixed-width text lost a complete character at the exact byte boundary.")
		TEST_ASSERT_EQUAL(preference.deserialize("A <b>name</b> é", null), STRIP_HTML_SIMPLE("A <b>name</b> é", preference.maximum_value_length), "The scoped profile fix changed existing HTML stripping.")
		TEST_ASSERT_NULL(preference.deserialize(list("invalid"), null), "Structured profile input was converted into an accepted clearing value.")
		TEST_ASSERT_EQUAL(preference.deserialize("", null), "", "An explicit empty profile value can no longer clear the field.")
	var/datum/preference/text/unrelated = GLOB.preference_entries[/datum/preference/text/flavor_text]
	TEST_ASSERT_EQUAL(unrelated.compile_constant_data()["maximum_length"], unrelated.maximum_value_length, "The cyborg repair changed unrelated generic text metadata.")
	TEST_ASSERT_NULL(unrelated.compile_constant_data()["maximum_bytes"], "The cyborg repair added byte-budget UI behavior to unrelated preferences.")

/// Only a pixel wait needs a second wire stage; keep its server snapshot coherent.
/datum/unit_test/cyborg_ui_pending_stage_projection
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_ui_pending_stage_projection/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/cyborg_sprite/penis], "Dogborg Knotted")
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	editor.set_page(list("active" = TRUE), null)
	editor.set_preview(list("context" = editor.context_generation, "model" = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")), null)
	var/list/ready = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!ready["preview_pending"] && !("rendered_preview" in ready), "A ready preview duplicated its current geometry on the wire.")
	TEST_ASSERT(editor.rendered_preview && length(ready["layers"]), "Wire projection discarded the server's coherent ready stage.")
	var/list/old_layers = editor.rendered_preview["layers"]
	editor.resource_refresh_at = world.time + 1 SECONDS
	editor.set_preview(list("context" = editor.context_generation, "direction" = NORTH), null)
	var/list/pending = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(pending["preview_pending"], "Changing direction did not enter the paced pixel wait.")
	TEST_ASSERT_EQUAL(pending["direction"], NORTH, "A pending stage hid the accepted direction from controls.")
	TEST_ASSERT_EQUAL(pending["rendered_preview"]?["direction"], SOUTH, "Pixel wait lost the previous stage's direction.")
	TEST_ASSERT(deep_compare_list(pending["rendered_preview"]?["layers"], old_layers), "Pixel wait combined old pixels with different geometry.")
	editor.resource_refresh_at = world.time
	ready = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!ready["preview_pending"] && !("rendered_preview" in ready), "Completed pixels retained a redundant frozen wire stage.")
	TEST_ASSERT_EQUAL(ready["direction"], NORTH, "Completed pixels exposed an obsolete direction.")
	TEST_ASSERT_EQUAL(editor.rendered_preview["direction"], NORTH, "Projection failed to retain the latest coherent server stage.")
	editor.resource_refresh_at = world.time + 1 SECONDS
	editor.set_preview(list("context" = editor.context_generation, "selected_part" = "sheath"), null)
	var/list/metadata = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(metadata["resources_pending"] && !metadata["preview_pending"], "Metadata selection incorrectly froze stage placement.")
	TEST_ASSERT(!("rendered_preview" in metadata) && length(metadata["layers"]), "Metadata-only wait lost current geometry or serialized a second stage.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], FALSE)
	var/list/denied = editor.get_ui_data(null)["cyborg_customization"]
	TEST_ASSERT(!("rendered_preview" in denied) && !length(denied["layers"]), "Consent revocation retained wire stage geometry.")
	TEST_ASSERT_NULL(editor.rendered_preview, "Consent revocation retained the server's private stage.")
	TEST_ASSERT_NULL(editor.preview_resources, "Consent revocation retained private preview resources.")
	editor.discard_draft()

/// Acquisition must not turn the early public gallery into an all-client preload.
/datum/unit_test/cyborg_gallery_selected_acquisition/Run()
	var/datum/asset/cyborg_model_gallery/gallery = get_asset_datum(/datum/asset/cyborg_model_gallery)
	var/list/previous_registration = list()
	for(var/asset_name in gallery.assets)
		previous_registration[asset_name] = SSassets.cache[asset_name]
		if(SSassets.cache[asset_name])
			SSassets.transport.unregister_asset(asset_name)
	gallery.send_to_viewer(null, "Engineering")
	var/list/selected = gallery.assets_for_department("Engineering")
	var/only_selected = TRUE
	for(var/asset_name in gallery.assets)
		if((asset_name in selected) != (SSassets.cache[asset_name] == gallery.assets[asset_name]))
			only_selected = FALSE
	gallery.send_to_viewer(null, "untrusted-department")
	var/unknown_unchanged = TRUE
	for(var/asset_name in gallery.assets)
		if((asset_name in selected) != (SSassets.cache[asset_name] == gallery.assets[asset_name]))
			unknown_unchanged = FALSE
		// Restore shared registration before reporting an assertion failure.
		if(SSassets.cache[asset_name])
			SSassets.transport.unregister_asset(asset_name)
		if(previous_registration[asset_name])
			SSassets.transport.register_asset(asset_name, previous_registration[asset_name])
	TEST_ASSERT_EQUAL(length(selected), 2, "Selected acquisition must consist of catalog plus one department.")
	TEST_ASSERT(only_selected, "Opening one department registered unrelated thumbnail resources.")
	TEST_ASSERT(unknown_unchanged, "An invalid department registered more public resources.")

/// Force the native acquisition wait without network clients or private snapshots.
/datum/asset/cyborg_model_gallery/acquisition_wait_test
	abstract_type = /datum/asset/cyborg_model_gallery/acquisition_wait_test
	var/released = FALSE
	var/calls = 0
	var/last_department

/datum/asset/cyborg_model_gallery/acquisition_wait_test/register()
	return

/datum/asset/cyborg_model_gallery/acquisition_wait_test/send_to_viewer(mob/user, department)
	calls++
	last_department = department
	UNTIL(released)
	return TRUE

/datum/unit_test/cyborg_gallery_acquisition_rechecks_owner
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_gallery_acquisition_rechecks_owner/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/datum/asset/cyborg_model_gallery/original = get_asset_datum(/datum/asset/cyborg_model_gallery)
	var/datum/asset/cyborg_model_gallery/acquisition_wait_test/paused = new
	paused.catalog = original.catalog
	paused.generation = original.generation
	paused.catalog_asset = original.catalog_asset
	paused.assets = original.assets
	paused.department_assets = original.department_assets
	GLOB.asset_datums[/datum/asset/cyborg_model_gallery] = paused
	editor.set_page(list("active" = TRUE), null)
	spawn(1)
		editor.close_editor()
		editor.set_page(list("active" = TRUE), null)
		paused.released = TRUE
	var/closed_stayed_empty = !length(editor.get_ui_data(null)) && !editor.preview_resources
	paused.released = FALSE
	spawn(1)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], FALSE)
		paused.released = TRUE
	var/list/denied = editor.get_ui_data(null)["cyborg_customization"]
	var/revoked_stayed_empty = !denied["allowed"] && !editor.get_ui_static_data(null)["cyborg_resources"] && !editor.preview_resources
	var/calls_while_denied = paused.calls
	editor.get_ui_data(null)
	var/no_denied_acquisition = paused.calls == calls_while_denied
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	editor.set_preview(list("context" = editor.context_generation, "gallery_open" = TRUE, "gallery_department" = "Engineering"), null)
	paused.released = FALSE
	var/calls_before_switch = paused.calls
	spawn(1)
		preferences.default_slot = 2
		editor.set_preview(list("context" = editor.context_generation, "gallery_department" = "Medical"), null)
		paused.released = TRUE
	editor.resource_refresh_at = world.time
	var/list/current = editor.get_ui_data(null)["cyborg_customization"]
	var/current_slot = editor.draft_slot == 2
	var/current_department = current["gallery_department"] == "Medical" && editor.preview_resources?["gallery"]?["department"] == "Medical"
	var/reacquired_current = paused.calls == calls_before_switch + 2 && paused.last_department == "Medical"
	editor.discard_draft()
	GLOB.asset_datums[/datum/asset/cyborg_model_gallery] = original
	GLOB.asset_datums -= paused.type
	qdel(paused)
	TEST_ASSERT(closed_stayed_empty, "An acquisition continuation republished into a closed/reopened editor.")
	TEST_ASSERT(revoked_stayed_empty && no_denied_acquisition, "Revoked consent retained public acquisition or private UI resources.")
	TEST_ASSERT(current_slot && current_department && reacquired_current, "An acquisition wait published an obsolete slot or an unacquired department URL.")

/// A native write can leave partial bytes while returning an error string.
/datum/asset/cyborg_model_gallery/write_failure_test
	abstract_type = /datum/asset/cyborg_model_gallery/write_failure_test
	var/last_filename

/datum/asset/cyborg_model_gallery/write_failure_test/register()
	return

/datum/asset/cyborg_model_gallery/write_failure_test/write_json(encoded_data, filename)
	last_filename = filename
	rustg_file_write("{", filename)
	return "expected partial-write failure"

/datum/unit_test/cyborg_gallery_write_failure/Run()
	var/datum/asset/cyborg_model_gallery/write_failure_test/gallery = new
	var/resource
	var/exception/failure
	try
		resource = gallery.json_resource(list("probe" = TRUE))
	catch(var/exception/error)
		failure = error
	var/partial_removed = gallery.last_filename && !fexists(gallery.last_filename)
	GLOB.asset_datums -= gallery.type
	qdel(gallery)
	TEST_ASSERT(failure && findtext(failure.name, "expected partial-write failure"), "A native write error was ignored before asset publication.")
	TEST_ASSERT_NULL(resource, "A partial JSON file became a published resource.")
	TEST_ASSERT(partial_removed, "Failed public asset generation retained its partial temporary file.")

/// Wire omission must resolve to the exact original animation, including moving frames.
/datum/unit_test/cyborg_ui_animation_projection
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_ui_animation_projection/Run()
	var/datum/preferences/preferences = create_preferences()
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/model_id = cyborg_appearance_model_id(/obj/item/robot_model/engineering, "Drake")
	var/list/descriptor = cyborg_model_catalog()[model_id]
	cyborg_occlusion_ensure_model_ready(descriptor["icon"], descriptor["icon_state"])
	editor.set_page(list("active" = TRUE), null)
	var/omitted_fields = 0
	var/distinct_fields = 0
	for(var/direction in GLOB.cardinals)
		for(var/moving in list(FALSE, TRUE))
			editor.set_preview(list("context" = editor.context_generation, "model" = model_id, "direction" = direction, "moving" = moving), null)
			editor.resource_refresh_at = world.time
			editor.get_ui_data(null)
			var/list/resources = editor.preview_resources
			var/list/projected = resources["animation"]
			var/list/full = cyborg_preview_animation(descriptor, direction, "idle", moving, TRUE)
			TEST_ASSERT(length(full), "The animation projection fixture has no authored frames.")
			TEST_ASSERT_EQUAL(length(projected), length(full), "Projection changed the authored frame count.")
			for(var/index in 1 to length(full))
				var/list/frame = projected[index]
				var/list/original = full[index]
				for(var/field in list("delay", "x", "y"))
					TEST_ASSERT_EQUAL(frame[field], original[field], "Projection changed a frame's timing or anchor offset.")
				for(var/field in list("body", "occlusion"))
					TEST_ASSERT_EQUAL(frame[field] || resources[field], original[field], "Frontend fallback changed a frame's resolved pixels.")
					if(original[field] == resources[field])
						omitted_fields++
						TEST_ASSERT(!(field in frame), "A byte-identical standalone image was repeated in an animation frame.")
					else
						distinct_fields++
						TEST_ASSERT_EQUAL(frame[field], original[field], "Projection removed distinct moving or idle frame pixels.")
	editor.discard_draft()
	TEST_ASSERT(omitted_fields && distinct_fields, "The animation fixture must cover both omitted duplicates and retained distinct pixels.")

/// Job spawns apply prefs before the player enters the body. The snapshot still belongs to that player, so entering the
/// body again keeps it, and its runtime controls answer to them.
/datum/unit_test/cyborg_job_spawn_snapshot_owner
	parent_type = /datum/unit_test/cyborg_mock_preferences

/datum/unit_test/cyborg_job_spawn_snapshot_owner/Run()
	var/mob/living/silicon/robot/robot = EASY_ALLOCATE()
	var/datum/preferences/preferences = create_preferences(robot)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_genitals], TRUE)
	var/datum/preference_middleware/cyborg_character/editor = preferences.cyborg_session()
	var/list/draft = deep_copy_list(editor.begin_draft())
	draft["active"]["penis"]["pixel_x"] = 11
	editor.update_draft(draft)
	TEST_ASSERT_NULL(robot.ckey, "The fixture body already has a player.")
	apply_cyborg_customization(robot, preferences)
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_owner, preferences.parent.ckey, "A body that took prefs before its player entered was not given to that player.")
	robot.ckey = preferences.parent.ckey
	draft = deep_copy_list(editor.begin_draft())
	draft["active"]["penis"]["pixel_x"] = 33
	editor.update_draft(draft)
	apply_cyborg_customization(robot, preferences)
	robot.ckey = null
	TEST_ASSERT_EQUAL(robot.cyborg_appearance_store["active"]["penis"]["pixel_x"], 11, "The spawned player entering again replaced the body's snapshot with later editor changes.")
