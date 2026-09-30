/// Preferences whose character setup window counts as open once asked to, without drawing anything.
/datum/preferences/preferences_import_test/preview_window_test
	/// Whether the window counts as open.
	var/window_open = FALSE

/// Counts as open once the test says so.
/datum/preferences/preferences_import_test/preview_window_test/character_preview_open()
	return window_open

/// Asks for no drawing; the test takes the drawing's turn itself.
/datum/preferences/preferences_import_test/preview_window_test/character_preview_changed()
	return

/// With character setup open, changes leave the preview mob stale until its turn in SScharacter_preview, whose rebuild takes in every change and ends the turn a waiting drawing waits for.
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
	TEST_ASSERT(view.body_stale, "With a window open, a change should leave the preview mob for the drawing to rebuild")
	TEST_ASSERT_EQUAL(view.body.hair_color, "#111111", "With a window open, a change shouldn't rebuild the preview mob inside the action")
	preferences.write_preference(hair_color, "#333333")
	view.update_body()

	var/list/queue = SScharacter_preview.queue
	var/atom/movable/screen/map_view/char_preview/ahead = allocate(/atom/movable/screen/map_view/char_preview)
	queue.Insert(1, ahead)
	TEST_ASSERT(!SScharacter_preview.rebuild_or_wait(view), "A rebuild shouldn't go ahead of one already waiting")
	var/turns = view.turns
	SScharacter_preview.rebuild(view)
	TEST_ASSERT_EQUAL(view.body.hair_color, "#333333", "A rebuild should take in every change made while the mob waited")
	TEST_ASSERT(!view.body_stale, "A rebuilt preview mob shouldn't be stale")
	TEST_ASSERT(!(view in queue), "A rebuilt preview should leave the queue")
	TEST_ASSERT_EQUAL(view.turns, turns + 1, "A rebuild should be the turn a waiting drawing waits for")

	qdel(ahead)
	TEST_ASSERT(!(ahead in queue), "A deleted preview should leave the queue")
