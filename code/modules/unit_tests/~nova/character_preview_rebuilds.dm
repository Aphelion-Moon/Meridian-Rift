/// Preferences whose character setup window counts as open once asked to, counting the drawings it is asked for
/// instead of drawing them.
/datum/preferences/preferences_import_test/preview_window_test
	/// Whether the window counts as open.
	var/window_open = FALSE
	/// How many times a change asked for a drawing.
	var/asked = 0

/datum/preferences/preferences_import_test/preview_window_test/character_preview_open()
	return window_open

/datum/preferences/preferences_import_test/preview_window_test/character_preview_changed()
	if(window_open)
		asked++

/**
 * Without a window, a change rebuilds the preview mob at once. With one, a change leaves it for the window's drawing to
 * rebuild, once for however many changes, and in turn behind rebuilds already waiting; whatever reads the mob gets it
 * rebuilt first. A preview leaves the queue once rebuilt, or deleted.
 */
/datum/unit_test/character_preview_rebuild_turns/Run()
	if(!SScharacter_preview.can_fire)
		TEST_FAIL("The character preview subsystem should be able to fire")
		return
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences_import_test/preview_window_test/preferences = allocate(/datum/preferences/preferences_import_test/preview_window_test, mock_client)
	var/datum/preference/hair_color = GLOB.preference_entries[/datum/preference/color/hair_color]
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(hair_color, "#111111")
	var/atom/movable/screen/map_view/char_preview/view = allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	view.update_body()
	TEST_ASSERT(!view.body_stale, "Without a window, a change should rebuild the preview mob at once")
	TEST_ASSERT_EQUAL(view.body.hair_color, "#111111", "Without a window, the preview mob should show a change at once")

	preferences.window_open = TRUE
	preferences.write_preference(hair_color, "#222222")
	view.update_body()
	TEST_ASSERT_EQUAL(preferences.asked, 1, "A change should ask the window for a drawing")
	TEST_ASSERT(view.body_stale, "With a window open, a change should leave the preview mob for the drawing to rebuild")
	TEST_ASSERT_EQUAL(view.body.hair_color, "#111111", "With a window open, a change shouldn't rebuild the preview mob inside the action")
	preferences.write_preference(hair_color, "#333333")
	view.update_body()

	var/list/queue = SScharacter_preview.queue
	var/atom/movable/screen/map_view/char_preview/ahead = allocate(/atom/movable/screen/map_view/char_preview)
	queue.Insert(1, ahead)
	TEST_ASSERT(!SScharacter_preview.rebuild_or_wait(view, now = TRUE), "A rebuild shouldn't go ahead of one already waiting")
	TEST_ASSERT_EQUAL(queue.Find(view), queue.Find(ahead) + 1, "A rebuild should wait behind those already waiting")
	var/turns = view.turns
	TEST_ASSERT_EQUAL(view.current_body().hair_color, "#333333", "Reading the preview mob should rebuild it first, with every change")
	TEST_ASSERT(!view.body_stale, "A rebuilt preview mob shouldn't be stale")
	TEST_ASSERT(!(view in queue), "A rebuilt preview should leave the queue")
	TEST_ASSERT_EQUAL(view.turns, turns + 1, "A rebuild should be the turn a waiting drawing waits for")
	TEST_ASSERT_EQUAL(preferences.asked, 2, "Rebuilding the mob shouldn't ask for another drawing")

	qdel(ahead)
	TEST_ASSERT(!(ahead in queue), "A deleted preview should leave the queue")
