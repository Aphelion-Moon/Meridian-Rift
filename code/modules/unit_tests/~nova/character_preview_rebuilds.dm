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

/// The preview's own data is all ui_data() is read for here: compiling every preference's needs a real client.
/datum/preferences/preferences_import_test/preview_window_test/compile_character_preferences(mob/user)
	return

/// Character setup offers the two underwear arousal previews right after Underwear, only for a character with a penis and
/// never with ERP disabled, and one picked goes back to Underwear once the penis is gone. Each sets the preview mob's penis
/// and its bulge on the underwear, in the order the update_preview action leaves the drawing's rebuild.
/datum/unit_test/character_preview/Run()
	if(CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "The underwear arousal previews need genitals, which the ERP config disables.")
		return
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences_import_test/preview_window_test/preferences = allocate(/datum/preferences/preferences_import_test/preview_window_test, mock_client)
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/choiced/genital/penis]
	preferences.cached_character_profiles = list() // so ui_data() reads no save slots
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/underwear], "Boxers")
	preferences.write_preference(preference, "Human")
	var/atom/movable/screen/map_view/char_preview/view = allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	preferences.character_preview_view = view // as the loadout data reads it
	TEST_ASSERT_EQUAL(jointext(preferences.ui_data(null)["preview_options"], "|"), "Job|Loadout|Underwear|Underwear - Half Aroused|Underwear - Aroused|Naked|Naked - Aroused", "A character with a penis should be offered both underwear arousal previews, right after Underwear")
	for(var/mode, arousal_flag in list(PREVIEW_PREF_NAKED_AROUSED = AROUSAL_FULL, PREVIEW_PREF_UNDERWEAR_HALF = AROUSAL_PARTIAL, PREVIEW_PREF_UNDERWEAR_AROUSED = AROUSAL_FULL, PREVIEW_PREF_UNDERWEAR = AROUSAL_NONE))
		preferences.preview_pref = mode
		preferences.previous_preview_pref = mode // as the update_preview action leaves it for the drawing's rebuild
		view.update_body()
		var/obj/item/organ/genital/penis/penis = view.body.get_organ_slot(ORGAN_SLOT_PENIS)
		var/datum/bodypart_overlay/mutant/genital/penis/overlay = penis?.bodypart_overlay
		TEST_ASSERT_EQUAL(penis?.aroused, arousal_flag, "[mode] should leave the preview mob's penis at arousal [arousal_flag]")
		if(mode != PREVIEW_PREF_NAKED_AROUSED)
			TEST_ASSERT_EQUAL(!!overlay?.bulge_key, arousal_flag != AROUSAL_NONE, "[mode] should draw [arousal_flag == AROUSAL_NONE ? "no" : "a"] bulge on the underwear")
	preferences.preview_pref = PREVIEW_PREF_UNDERWEAR_AROUSED
	preferences.write_preference(preference, SPRITE_ACCESSORY_NONE)
	TEST_ASSERT_EQUAL(jointext(preferences.ui_data(null)["preview_options"], "|"), "Job|Loadout|Underwear|Naked|Naked - Aroused", "A character without a penis should be offered neither underwear arousal preview")
	TEST_ASSERT_EQUAL(preferences.preview_pref, PREVIEW_PREF_UNDERWEAR, "An underwear arousal preview should go back to Underwear once the penis is gone")
	preferences.write_preference(preference, "Human")
	CONFIG_SET(flag/disable_erp_preferences, TRUE)
	var/list/options = preferences.ui_data(null)["preview_options"]
	CONFIG_SET(flag/disable_erp_preferences, FALSE)
	TEST_ASSERT_EQUAL(jointext(options, "|"), "Job|Loadout|Underwear|Naked", "With ERP disabled, no aroused preview should be offered, penis or not")
