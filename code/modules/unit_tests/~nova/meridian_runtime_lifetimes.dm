/// A browserless window retains the real TGUI close/unregister path.
/datum/tgui_window/runtime_lifetimes/New()
	id = "runtime_lifetimes"

/// Records whether each viewer released the real screen before it was destroyed.
/atom/movable/screen/map_view/examine_panel_screen/runtime_lifetimes
	/// Viewers released by the panel's real ui_close callback.
	var/list/released_viewers = list()
	/// A callback must never see a terminal screen.
	var/released_after_destroy = FALSE

/atom/movable/screen/map_view/examine_panel_screen/runtime_lifetimes/hide_from(mob/viewer)
	released_viewers += viewer
	released_after_destroy ||= QDELETED(src)
	return ..()

/// Deleting the examined human closes every registered UI before releasing its screen.
/datum/unit_test/meridian_examine_panel_teardown/Run()
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/viewer = allocate(/mob/living/carbon/human/consistent)
	var/mob/dead/observer/observer = allocate(/mob/dead/observer)
	var/datum/examine_panel/panel = target.mob_examine_panel
	var/atom/movable/screen/map_view/examine_panel_screen/runtime_lifetimes/screen = allocate(/atom/movable/screen/map_view/examine_panel_screen/runtime_lifetimes)
	panel.examine_panel_screen = screen
	var/list/windows = list()
	for(var/mob/participant as anything in list(viewer, observer))
		var/datum/tgui/ui = allocate(/datum/tgui, participant, panel, "ExaminePanel")
		ui.window = allocate(/datum/tgui_window/runtime_lifetimes)
		SStgui.on_open(ui)
		windows += ui

	qdel(target)
	if(length(screen.released_viewers) != 2 || !(observer in screen.released_viewers) || !(viewer in screen.released_viewers))
		TEST_FAIL("Deleting an examined target must release both the living and observer viewers.")
	if(screen.released_after_destroy)
		TEST_FAIL("The examine screen was destroyed before a UI released it.")
	if(!QDELETED(screen) || !QDELETED(panel))
		TEST_FAIL("The target must finish deleting its panel and screen.")
	for(var/datum/tgui/ui as anything in windows)
		if(!ui.closing || (ui in SStgui.all_uis))
			TEST_FAIL("A target deletion left an examine UI open or registered with SStgui.")
		// Keep the failing baseline from leaking its orphaned UIs into another test.
		SStgui.on_close(ui)
		qdel(ui)

/// A terminal panel cannot be reopened, including by an observer whose state normally always allows viewing.
/datum/unit_test/meridian_examine_panel_terminal/Run()
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/mob/dead/observer/viewer = allocate(/mob/dead/observer)
	var/datum/examine_panel/panel = target.mob_examine_panel
	qdel(target)
	TEST_ASSERT_EQUAL(panel.ui_status(viewer, GLOB.always_state), UI_CLOSE, "A deleted target must close the panel even for observers.")
	panel.ui_interact(viewer)
	TEST_ASSERT_NULL(panel.examine_panel_screen, "Reopening a terminal panel recreated its screen.")

/// Uses synthetic accounts in isolated files; never reads or replaces existing player data.
/datum/unit_test/meridian_modular_persistence
	abstract_type = /datum/unit_test/meridian_modular_persistence
	/// Every exact fixture filename is removed even after a failed assertion.
	var/list/fixture_paths = list()
	/// Minds whose synthetic account keys may move to a body or brain during real transfer paths.
	var/list/fixture_minds = list()

/datum/unit_test/meridian_modular_persistence/Destroy()
	// End the synthetic connection before destroying its body, so real teardown does not spawn a keyed ghost.
	for(var/datum/mind/fixture_mind as anything in fixture_minds)
		fixture_mind.key = null
		var/mob/current_body = fixture_mind.current
		if(current_body)
			current_body.key = null
	for(var/mob/owned_mob in allocated)
		owned_mob.key = null
	for(var/path in fixture_paths)
		fdel(path)
	return ..()

/// Gives a real brain a real mind/slot admission identity without connecting a player.
/datum/unit_test/meridian_modular_persistence/proc/make_record(slot = 2, suffix = "primary")
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.mind_initialize()
	fixture_minds += target.mind
	var/account = ckey("unittestpersistence[REF(src)][suffix]")
	target.mind.key = account
	target.mind.original_character_slot_index = slot
	var/path = "data/player_saves/[account[1]]/[account]/modular_persistence.json"
	if(fexists(path))
		TEST_FAIL("Refusing to use a persistence fixture that already exists: [path]")
		return
	fixture_paths |= path
	var/obj/item/organ/brain/brain = target.get_organ_slot(ORGAN_SLOT_BRAIN)
	brain.modular_persistence = new(brain)
	brain.modular_persistence.stored_rewards_points = 17
	return list(target, brain, brain.modular_persistence, account, path)

/// Ghosting and disconnecting leave a save bound to the account and slot admitted with the character.
/datum/unit_test/meridian_modular_persistence/offline/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/datum/modular_persistence/record = fixture[3]
	// Neither the body nor brainmob has a live key; the admission mind is the only authority.
	target.mind.key = null
	target.mind.original_character_slot_index = 9
	TEST_ASSERT(record.save_data(), "A disconnected or ghosted record must save using its admitted account.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "A late slot change must not move the admitted character's record.")
	TEST_ASSERT_NULL(saved["9"], "The current mind slot must not replace the admitted slot.")

/// A real ghost transition does not change the admitted account or leave a keyed fixture behind.
/datum/unit_test/meridian_modular_persistence/ghost/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/datum/modular_persistence/record = fixture[3]
	target.key = fixture[4]
	var/mob/dead/observer/ghost = target.ghostize()
	if(ghost)
		allocated += ghost
	TEST_ASSERT_NOTNULL(ghost, "The fixture must execute a real ghost transition.")
	TEST_ASSERT_NULL(target.key, "Ghosting must release the body's live key.")
	TEST_ASSERT(record.save_data(), "A ghosted brain must retain its admission identity.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "Ghosting lost the admitted character's data.")

/// Repeated admission reuses live data, while another account or slot cannot rebind it.
/datum/unit_test/meridian_modular_persistence/load/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/obj/item/organ/brain/brain = fixture[2]
	var/datum/modular_persistence/original = fixture[3]
	TEST_ASSERT(original.save_data(), "The fixture must create the admitted slot's saved data.")
	QDEL_NULL(brain.modular_persistence)
	TEST_ASSERT(SSpersistence.load_modular_persistence(brain), "A valid admission must load its own saved slot.")
	var/datum/modular_persistence/loaded = brain.modular_persistence
	TEST_ASSERT_EQUAL(loaded.stored_rewards_points, 17, "Loading did not restore the saved character's data.")
	loaded.stored_rewards_points = 31
	TEST_ASSERT(SSpersistence.load_modular_persistence(brain), "Repeating the same admission must remain valid.")
	TEST_ASSERT_EQUAL(brain.modular_persistence, loaded, "Repeating admission replaced the live record.")
	TEST_ASSERT_EQUAL(loaded.stored_rewards_points, 31, "Repeating admission discarded unsaved live data.")
	target.mind.original_character_slot_index = 5
	TEST_ASSERT(!SSpersistence.load_modular_persistence(brain), "Another slot cannot rebind an admitted brain.")
	target.mind.original_character_slot_index = 2
	target.mind.key = "anotheraccount"
	TEST_ASSERT(!SSpersistence.load_modular_persistence(brain), "Another account cannot rebind an admitted brain.")
	TEST_ASSERT_EQUAL(brain.modular_persistence, loaded, "Rejected admission changed the existing record.")

/// Cryo's fake admin key spelling must still identify the same admitted account.
/datum/unit_test/meridian_modular_persistence/admin_key/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/datum/modular_persistence/record = fixture[3]
	TEST_ASSERT(record.save_data("@[fixture[4]]"), "An aghost key must normalize to its admitted account.")
	TEST_ASSERT(fexists(fixture[5]), "The normalized account's persistence file was not saved.")
	var/mob/living/carbon/human/target = fixture[1]
	var/obj/item/organ/brain/brain = fixture[2]
	target.mind.key = "@[fixture[4]]"
	QDEL_NULL(brain.modular_persistence)
	TEST_ASSERT(SSpersistence.load_modular_persistence(brain), "An aghost spelling must still load the admitted account.")
	TEST_ASSERT_EQUAL(brain.modular_persistence.stored_ckey, fixture[4], "An aghost prefix became part of the authoritative save identity.")
	TEST_ASSERT_EQUAL(brain.modular_persistence.stored_rewards_points, 17, "An aghost admission read a different account's file.")

/// An explicit caller cannot redirect one character's record into another account.
/datum/unit_test/meridian_modular_persistence/account_isolation/Run()
	var/list/first = make_record(2, "first")
	var/list/second = make_record(5, "second")
	TEST_ASSERT(first && second, "Both synthetic account fixtures must be created.")
	var/datum/modular_persistence/record = first[3]
	TEST_ASSERT(!record.save_data(second[4]), "A caller-supplied key must not redirect a bound persistence record.")
	TEST_ASSERT(!fexists(second[5]), "Another account's file was written by the first record.")
	TEST_ASSERT(record.save_data(first[4]), "The admitted account can explicitly save its own record.")
	var/list/saved = json_decode(file2text(first[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "Saving the admitted account lost its data.")

/// A removed brain saves its last recorded state without sampling a nonexistent human owner.
/datum/unit_test/meridian_modular_persistence/detached/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/obj/item/organ/brain/brain = fixture[2]
	var/datum/modular_persistence/record = fixture[3]
	brain.Remove(target, special = TRUE)
	TEST_ASSERT_NULL(brain.owner, "The fixture must actually detach its brain.")
	TEST_ASSERT(record.save_data(fixture[4]), "A detached admitted brain must save its recorded data.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "Detached serialization discarded the retained record.")
	brain.Insert(target, special = TRUE)
	TEST_ASSERT(record.save_data(), "Reinserting the brain must preserve its original save identity.")

/// Replacing a brain moves the existing record and preserves its account/slot after the old organ is deleted.
/datum/unit_test/meridian_modular_persistence/replacement/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/obj/item/organ/brain/old_brain = fixture[2]
	var/datum/modular_persistence/record = fixture[3]
	var/datum/augment_item/organ/brain/cortical/augment = allocate(/datum/augment_item/organ/brain/cortical)
	augment.apply(target)
	var/obj/item/organ/brain/new_brain = target.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT_NOTEQUAL(new_brain, old_brain, "The real augment path must replace the brain.")
	TEST_ASSERT_NULL(old_brain.modular_persistence, "The old brain must release its record before deletion.")
	TEST_ASSERT_EQUAL(new_brain.modular_persistence, record, "The replacement must retain the same record.")
	TEST_ASSERT_EQUAL(record.owner_brain.resolve(), new_brain, "The record must resolve its replacement brain.")
	qdel(old_brain)
	TEST_ASSERT(!QDELETED(record), "Deleting a replaced brain must not delete its transferred record.")
	TEST_ASSERT(record.save_data(), "A replacement brain must save without a current client key.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "Replacing the brain changed the admitted record.")

/// Transfers cannot overwrite another brain's record, even when the caller owns a valid record.
/datum/unit_test/meridian_modular_persistence/transfer_isolation/Run()
	var/list/first = make_record(2, "first")
	var/list/second = make_record(5, "second")
	TEST_ASSERT(first && second, "Both synthetic account fixtures must be created.")
	var/obj/item/organ/brain/first_brain = first[2]
	var/obj/item/organ/brain/second_brain = second[2]
	var/datum/modular_persistence/record = first[3]
	TEST_ASSERT(!record.transfer_to_brain(second_brain), "A transfer must not overwrite another character's record.")
	TEST_ASSERT_EQUAL(first_brain.modular_persistence, first[3], "A rejected transfer detached the original record.")
	TEST_ASSERT_EQUAL(second_brain.modular_persistence, second[3], "A rejected transfer changed the other account's record.")
	TEST_ASSERT_EQUAL(record.owner_brain.resolve(), first_brain, "A rejected transfer changed ownership.")

/// Account and slot are constructor authority; JSON cannot inject either, and neither is written back into JSON.
/datum/unit_test/meridian_modular_persistence/import_identity/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/obj/item/organ/brain/brain = fixture[2]
	qdel(brain.modular_persistence)
	brain.modular_persistence = new(brain, list("stored_ckey" = "wrongaccount", "stored_character_slot_index" = 99, "stored_rewards_points" = 23))
	var/datum/modular_persistence/record = brain.modular_persistence
	TEST_ASSERT_EQUAL(record.stored_ckey, fixture[4], "JSON changed the admitted account.")
	TEST_ASSERT_EQUAL(record.stored_character_slot_index, 2, "JSON changed the admitted slot.")
	TEST_ASSERT(record.save_data(), "Imported data must save under the admission identity.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 23, "Ordinary persistence data must still round-trip.")
	TEST_ASSERT_NULL(saved["2"]["stored_ckey"], "The account identity must not be serialized as mutable payload.")
	TEST_ASSERT_NULL(saved["2"]["stored_character_slot_index"], "The slot identity must not be serialized as mutable payload.")

/// Distinct admitted slots of the same account coexist in the existing file format.
/datum/unit_test/meridian_modular_persistence/slot_isolation/Run()
	var/list/first = make_record(2)
	var/list/second = make_record(5)
	TEST_ASSERT(first && second, "Both synthetic slot fixtures must be created.")
	var/datum/modular_persistence/first_record = first[3]
	var/datum/modular_persistence/second_record = second[3]
	second_record.stored_rewards_points = 29
	TEST_ASSERT(first_record.save_data(), "The first admitted slot must save.")
	TEST_ASSERT(second_record.save_data(), "The second admitted slot must save.")
	var/list/saved = json_decode(file2text(first[5]))
	TEST_ASSERT_EQUAL(saved["2"]["stored_rewards_points"], 17, "Saving another slot overwrote the first slot.")
	TEST_ASSERT_EQUAL(saved["5"]["stored_rewards_points"], 29, "The second slot was saved under the wrong identity.")

/// A changed occupant's NIF cannot be sampled into the admitted character's saved record.
/datum/unit_test/meridian_modular_persistence/occupant_isolation/Run()
	var/list/fixture = make_record()
	TEST_ASSERT_NOTNULL(fixture, "The synthetic persistence fixture must be created.")
	var/mob/living/carbon/human/target = fixture[1]
	var/datum/modular_persistence/record = fixture[3]
	record.nif_path = /obj/item/organ/cyberimp/brain/nif
	record.nif_durability = 75
	target.mind.key = "anotheraccount"
	TEST_ASSERT(record.save_data(), "A changed occupant must not change the record's save destination.")
	var/list/saved = json_decode(file2text(fixture[5]))
	TEST_ASSERT_EQUAL(saved["2"]["nif_durability"], 75, "Another account's missing NIF penalized the admitted character.")

/// Both post-prompt checks use this ownership contract; no real client or player preferences are required.
/datum/unit_test/meridian_vv_prefs_ownership/Run()
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_body = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/client_interface/other_connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/preferences/other_preferences = allocate(/datum/preferences/preferences_import_test, other_connection)
	connection.mob = target
	connection.prefs = preferences
	TEST_ASSERT(target.vv_prefs_target_valid(connection, preferences), "A live target with the captured preferences must remain eligible.")

	connection.mob = other_body
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, preferences), "A body transfer while either prompt is open must invalidate the original target.")
	connection.mob = null
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, preferences), "A disconnected captured client must invalidate the prompt.")
	connection.mob = target
	connection.prefs = other_preferences
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, preferences), "Replacing client preferences while either prompt is open must cancel.")
	connection.prefs = preferences
	preferences.parent = other_connection
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, preferences), "Preferences owned by another connection must cancel.")
	preferences.parent = connection
	TEST_ASSERT(target.vv_prefs_target_valid(connection, preferences), "Restoring the same live ownership should remain eligible.")

	qdel(preferences)
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, preferences), "Deleted preferences must cancel before any DNA mutation.")
	connection.prefs = other_preferences
	other_preferences.parent = connection
	qdel(target)
	TEST_ASSERT(!target.vv_prefs_target_valid(connection, other_preferences), "A deleted human with cleared DNA must cancel without manufacturing DNA.")
	connection.mob = null

/// Counts requests at the real preview rebuild boundary, without needing a browser or client during teardown.
/atom/movable/screen/map_view/char_preview/runtime_lifetimes
	/// A closed setup session must never ask for another body.
	var/rebuild_requests = 0

/atom/movable/screen/map_view/char_preview/runtime_lifetimes/update_body(catching_up = FALSE)
	rebuild_requests++

/// Saving an editor on preferences close preserves its drawing without rebuilding the departing preview.
/datum/unit_test/meridian_custom_sprite_close/Run()
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/custom_sprite_editor/editor = allocate(/datum/custom_sprite_editor, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))
	TEST_ASSERT(editor.workspace.new_transaction(stroke), "The fixture must contain a real unsaved drawing.")
	var/saved_hash = custom_sprite_hash(editor.workspace.serialize_drawing())
	var/atom/movable/screen/map_view/char_preview/runtime_lifetimes/view = allocate(/atom/movable/screen/map_view/char_preview/runtime_lifetimes, null, null, preferences)
	preferences.character_preview_view = view
	preferences.ui_close(null)
	TEST_ASSERT_EQUAL(view.rebuild_requests, 0, "Closing preferences must release the preview before a saved editor publishes its drawing.")
	TEST_ASSERT(QDELETED(view) && QDELETED(editor), "Closing preferences must release the view and saved editor.")
	TEST_ASSERT_EQUAL(custom_sprite_hash(preferences.custom_hair), saved_hash, "Closing preferences lost the saved drawing.")
	TEST_ASSERT(!(editor in SScustom_sprite_work.queue), "A closed editor retained queued rendering work.")

/// Accepted strokes waiting for the background are included when the preferences window closes.
/datum/unit_test/meridian_custom_sprite_pending_close/Run()
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/custom_sprite_editor/editor = allocate(/datum/custom_sprite_editor, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	COOLDOWN_START(pace, stroke_window, 5 SECONDS)
	editor.take_stroke(stroke)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "The real stroke admission path must defer the accepted stroke.")
	preferences.ui_close(null)
	TEST_ASSERT(QDELETED(editor), "Closing preferences must drain accepted strokes and finish the editor.")
	TEST_ASSERT_NOTNULL(preferences.custom_hair, "Closing preferences discarded the queued drawing.")
	TEST_ASSERT(!(editor in SScustom_sprite_work.queue), "The saved editor left work in the rendering queue.")

/// Preferences destruction has the same save-before-release data contract without retaining a preview to rebuild.
/datum/unit_test/meridian_custom_sprite_destroy/Run()
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/custom_sprite_editor/editor = allocate(/datum/custom_sprite_editor, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))
	TEST_ASSERT(editor.workspace.new_transaction(stroke), "The fixture must contain a real unsaved drawing.")
	var/atom/movable/screen/map_view/char_preview/runtime_lifetimes/view = allocate(/atom/movable/screen/map_view/char_preview/runtime_lifetimes, null, null, preferences)
	preferences.character_preview_view = view
	qdel(preferences)
	TEST_ASSERT_EQUAL(view.rebuild_requests, 0, "Preferences destruction must release its preview before saving editors.")
	TEST_ASSERT(QDELETED(editor) && QDELETED(view), "Preferences destruction must release its saved editor and view.")

/// Provides only the browser and iconforge boundaries; all queue, session, drawing, and publication logic is real.
/datum/preference_middleware/character_preview/runtime_lifetimes
	// Auto-created middleware instances must not take any real UI actions.
	action_delegations = list()
	/// The browser window currently owned by this test session.
	var/datum/tgui/test_window
	/// Pause the external renderer so the test can close and reopen while it is drawing.
	var/pause_renderer = FALSE
	/// Whether the real drawing pipeline reached the external renderer.
	var/renderer_entered = FALSE
	/// Names are scoped to this fixture and never collide with production drawings.
	var/last_drawing_name
	/// Updates emitted to the browser boundary.
	var/updates_sent = 0

/// Preferences instantiate every middleware subtype; leave their normal preview owner unchanged unless the test invokes us.
/datum/preference_middleware/character_preview/runtime_lifetimes/New(datum/preferences/preferences)
	var/datum/preference_middleware/character_preview/previous = preferences?.preview_drawing
	. = ..()
	if(preferences)
		preferences.preview_drawing = previous

/datum/preference_middleware/character_preview/runtime_lifetimes/open_window()
	return test_window

/datum/preference_middleware/character_preview/runtime_lifetimes/send_preview_update(list/update)
	if(test_window)
		updates_sent++

/datum/preference_middleware/character_preview/runtime_lifetimes/draw_preview(list/walk)
	renderer_entered = TRUE
	UNTIL(!pause_renderer || QDELETED(src))
	last_drawing_name = "runtime_lifetimes_[REF(src)]_[preview_serial]"
	var/list/drawn = list("name" = last_drawing_name, "height" = walk["height"], "width" = 32)
	GLOB.character_preview_drawings[last_drawing_name] = drawn
	return drawn

/datum/preference_middleware/character_preview/runtime_lifetimes/Destroy()
	test_window = null
	pause_renderer = FALSE
	return ..()

/// A queued answer and a settling timer both belong to the window that requested them.
/datum/unit_test/meridian_preview_queued_close/Run()
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/preference_middleware/character_preview/runtime_lifetimes/drawing = allocate(/datum/preference_middleware/character_preview/runtime_lifetimes, preferences)
	drawing.test_window = allocate(/datum/tgui, null, preferences, "PreferencesMenu")
	drawing.preview_changed()
	TEST_ASSERT(drawing.answer_due && (drawing in SScharacter_preview.drawings), "The request must enter the real drawing queue.")
	drawing.window_closed()
	TEST_ASSERT(!drawing.answer_due && !(drawing in SScharacter_preview.drawings), "Closing a window must cancel its queued answer.")

	// Force a real settling timer, then reopen before it could fire.
	drawing.drawing = TRUE
	drawing.preview_changed()
	TEST_ASSERT_NOTNULL(drawing.waiting_since, "The busy drawing must schedule a settling answer.")
	drawing.window_closed()
	drawing.drawing = FALSE
	drawing.updates_sent = 0
	drawing.test_window = allocate(/datum/tgui, null, preferences, "PreferencesMenu")
	sleep(1 SECONDS)
	TEST_ASSERT_NULL(drawing.waiting_since, "A closed session retained its settling state.")
	TEST_ASSERT(!drawing.answer_due && !(drawing in SScharacter_preview.drawings), "A closed session's timer queued work after reopening.")
	TEST_ASSERT_EQUAL(drawing.updates_sent, 0, "A closed session's timer sent an update to the reopened window.")

/// A renderer suspended during close cannot publish its old image into a reopened preferences window.
/datum/unit_test/meridian_preview_inflight_close/Run()
	var/datum/client_interface/connection = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, connection)
	var/datum/preference_middleware/character_preview/runtime_lifetimes/drawing = allocate(/datum/preference_middleware/character_preview/runtime_lifetimes, preferences)
	drawing.test_window = allocate(/datum/tgui, null, preferences, "PreferencesMenu")
	var/atom/movable/screen/map_view/char_preview/view = allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	view.silicon_preview = image('icons/effects/effects.dmi', "nothing")
	preferences.character_preview_view = view
	drawing.pause_renderer = TRUE
	INVOKE_ASYNC(drawing, TYPE_PROC_REF(/datum/preference_middleware/character_preview, start_answer))
	TEST_ASSERT(drawing.renderer_entered && drawing.drawing, "The real pipeline must wait inside the renderer.")
	// A second old-session answer waits on the first renderer's lock and must also be invalidated.
	INVOKE_ASYNC(drawing, TYPE_PROC_REF(/datum/preference_middleware/character_preview, start_answer))
	drawing.window_closed()
	qdel(view)
	var/atom/movable/screen/map_view/char_preview/new_view = allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	new_view.silicon_preview = image('icons/effects/effects.dmi', "nothing")
	preferences.character_preview_view = new_view
	drawing.test_window = allocate(/datum/tgui, null, preferences, "PreferencesMenu")
	drawing.pause_renderer = FALSE
	UNTIL(!drawing.drawing)
	sleep(world.tick_lag) // Let the old mutex waiter observe its invalidated session too.
	TEST_ASSERT_NULL(drawing.preview, "The previous window's renderer published into the new session.")
	TEST_ASSERT_EQUAL(drawing.updates_sent, 0, "The previous window's answer sent an update after reopening.")
	TEST_ASSERT_NULL(GLOB.character_preview_drawings[drawing.last_drawing_name], "A discarded drawing retained an unowned cache entry.")

	drawing.start_answer()
	TEST_ASSERT_NOTNULL(drawing.preview, "The reopened window must still draw its own preview.")
	TEST_ASSERT_EQUAL(drawing.updates_sent, 1, "The reopened window must receive its own completed answer.")
