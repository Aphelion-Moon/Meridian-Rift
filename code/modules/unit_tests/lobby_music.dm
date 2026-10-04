/// Native output is captured so transitions can be tested without connecting a Dream Seeker client.
/datum/lobby_music_player/test
	var/sound/active_sound
	var/list/sent_sounds = list()
	var/test_in_lobby = TRUE
	var/test_enabled = TRUE
	var/test_volume = 70
	var/test_track = 'sound/music/lobby_music/title2.ogg'
	var/stop_during_query = FALSE
	var/volume_during_query = FALSE
	var/capture_state = FALSE

/datum/lobby_music_player/test/is_enabled()
	return test_enabled

/datum/lobby_music_player/test/in_lobby()
	return test_in_lobby

/datum/lobby_music_player/test/volume()
	return test_volume * volume_multiplier

/datum/lobby_music_player/test/resolve_track()
	return test_track

/datum/lobby_music_player/test/wait_for_music(request)
	return

/datum/lobby_music_player/test/query_sound()
	var/sound/result = active_sound
	if(stop_during_query)
		stop_during_query = FALSE
		stop()
	if(volume_during_query)
		volume_during_query = FALSE
		update_volume()
	return result

/datum/lobby_music_player/test/send_sound(sound/music)
	sent_sounds += music
	if(music.status & SOUND_UPDATE)
		if(active_sound)
			active_sound.volume = music.volume
			active_sound.repeat = music.repeat
	else
		// sound(music) resets repeat/channel/volume to constructor defaults; retain the actual command.
		active_sound = music.file ? music : null

/datum/lobby_music_player/test/send_state()
	if(capture_state)
		return ..()

/datum/unit_test/lobby_music_transitions/Run()
	var/datum/client_interface/owner = allocate(/datum/client_interface)
	var/datum/lobby_music_player/test/player = allocate(/datum/lobby_music_player/test, owner)
	player.play()
	TEST_ASSERT(player.active_sound, "Entering the lobby did not start music.")
	TEST_ASSERT(player.active_sound.repeat, "Title music did not loop in the lobby.")
	player.active_sound.offset = 42
	player.play()
	var/sound/update = player.sent_sounds[length(player.sent_sounds)]
	TEST_ASSERT(update.status & SOUND_UPDATE, "Showing the title screen restarted a playing track.")
	TEST_ASSERT_EQUAL(player.active_sound.offset, 42, "Showing the title screen sought the track.")
	player.test_in_lobby = FALSE
	player.update_context()
	update = player.sent_sounds[length(player.sent_sounds)]
	TEST_ASSERT(update.status & SOUND_UPDATE, "Joining/observing stopped the current track.")
	TEST_ASSERT(player.active_sound, "Joining/observing cleared playback.")
	TEST_ASSERT(!player.active_sound.repeat, "Music kept looping after leaving the lobby.")
	TEST_ASSERT_EQUAL(player.active_sound.offset, 42, "Leaving the lobby changed playback position.")
	player.test_in_lobby = TRUE
	player.play()
	TEST_ASSERT(player.active_sound.repeat, "Returning to the lobby did not restore looping.")
	TEST_ASSERT_EQUAL(player.active_sound.offset, 42, "Returning to the lobby restarted ongoing music.")
	player.active_sound = null // The client reports natural completion.
	player.play()
	TEST_ASSERT(player.active_sound, "Returning after natural completion did not restart music.")
	player.play(restart = TRUE)
	update = player.sent_sounds[length(player.sent_sounds)]
	TEST_ASSERT(!(update.status & SOUND_UPDATE), "Explicit restart only updated the current sound.")

/datum/unit_test/lobby_music_controls/Run()
	var/datum/client_interface/owner = allocate(/datum/client_interface)
	var/datum/lobby_music_player/test/player = allocate(/datum/lobby_music_player/test, owner)
	player.play()
	player.active_sound.offset = 23
	player.test_volume = 35
	player.update_volume()
	TEST_ASSERT_EQUAL(player.active_sound.volume, 35, "Volume did not update.")
	TEST_ASSERT_EQUAL(player.active_sound.offset, 23, "Volume changes restarted music.")
	player.stop()
	TEST_ASSERT_NULL(player.active_sound, "Stop did not clear the lobby channel.")
	player.test_volume = 60
	player.update_volume()
	TEST_ASSERT_NULL(player.active_sound, "Changing volume undid an explicit stop.")
	player.test_volume = 0
	player.update_volume()
	player.test_volume = 60
	player.update_volume()
	TEST_ASSERT_NULL(player.active_sound, "Muting and unmuting undid an explicit stop.")
	player.play()
	TEST_ASSERT(player.active_sound, "Play did not resume stopped music.")
	player.test_volume = 0
	player.update_volume()
	TEST_ASSERT_NULL(player.active_sound, "Zero volume left music playing.")
	player.test_volume = 60
	player.update_volume()
	TEST_ASSERT(player.active_sound, "Unmuting in the lobby did not restore music.")
	player.test_track = 'sound/music/lobby_music/title3.ogg'
	player.play()
	TEST_ASSERT_EQUAL(player.active_sound.file, player.test_track, "Changing tracks did not replace playback.")
	player.stop_during_query = TRUE
	player.play(restart = TRUE)
	TEST_ASSERT_NULL(player.active_sound, "An older asynchronous play request overrode a newer stop.")
	player.test_in_lobby = FALSE
	player.volume_during_query = TRUE
	player.play()
	TEST_ASSERT(player.active_sound, "A volume change cancelled an in-game play request.")
	player.test_track = 'sound/music/lobby_music/title2.ogg'
	player.volume_during_query = TRUE
	player.play(restart = TRUE)
	TEST_ASSERT_EQUAL(player.active_sound.file, player.test_track, "A volume change cancelled a track selection.")
	player.test_enabled = FALSE
	player.play()
	TEST_ASSERT_NULL(player.active_sound, "Server-disabled title music still played.")

/datum/lobby_music_catalog/test
	var/test_server_track = 'sound/music/lobby_music/title2.ogg'

/datum/lobby_music_catalog/test/refresh()
	return

/datum/lobby_music_catalog/test/server_track()
	return test_server_track

/datum/client_interface/lobby_music_test
	var/datum/lobby_music_panel_test/tgui_panel

/datum/client_interface/lobby_music_test/Destroy(force)
	tgui_panel = null
	prefs = null
	return ..()

/// Capture the transport boundary while exercising the real state-query coalescing.
/datum/lobby_music_panel_test
	var/datum/lobby_music_window_test/window

/datum/lobby_music_panel_test/proc/is_ready()
	return TRUE

/datum/lobby_music_window_test
	var/list/states = list()

/datum/lobby_music_window_test/proc/send_message(type, list/payload)
	if(type == "audio/lobby/state")
		states += list(payload)

/datum/unit_test/lobby_music_state/Run()
	var/datum/client_interface/lobby_music_test/owner = allocate(/datum/client_interface/lobby_music_test)
	owner.prefs = allocate(/datum/preferences, owner)
	owner.tgui_panel = allocate(/datum/lobby_music_panel_test)
	var/datum/lobby_music_window_test/window = allocate(/datum/lobby_music_window_test)
	owner.tgui_panel.window = window
	var/datum/lobby_music_catalog/test/catalog = allocate(/datum/lobby_music_catalog/test)
	var/datum/lobby_music_player/test/player = allocate(/datum/lobby_music_player/test, owner, catalog)
	player.play()
	player.capture_state = TRUE
	player.stop_during_query = TRUE
	player.send_state()
	TEST_ASSERT_EQUAL(length(window.states), 1, "A stop during a pending state query did not send replacement state.")
	var/list/state = window.states[1]
	TEST_ASSERT(!state["playing"], "A stale state query reported playback after stopping.")
	TEST_ASSERT(!player.state_pending, "The completed query left future state updates blocked.")
	TEST_ASSERT_NULL(player.active_sound, "Refreshing the stopped state resumed playback.")

/datum/unit_test/lobby_music_preferences/Run()
	var/datum/client_interface/owner = allocate(/datum/client_interface)
	owner.prefs = new(owner)
	var/datum/lobby_music_catalog/test/catalog = allocate(/datum/lobby_music_catalog/test)
	var/builtin_track = 'sound/music/lobby_music/title2.ogg'
	TEST_ASSERT_EQUAL(catalog.available_source(builtin_track), builtin_track, "A compiled resource was rejected by a filesystem-only existence check.")
	var/datum/lobby_music_player/player = allocate(/datum/lobby_music_player, owner, catalog)
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/lobby_music_track]
	TEST_ASSERT_EQUAL(owner.prefs.read_preference(preference.type), "server", "New players did not default to the server selection.")
	TEST_ASSERT_EQUAL(player.resolve_track(), catalog.test_server_track, "Server default did not resolve to the current server song.")
	TEST_ASSERT_EQUAL(preference.deserialize("../../config/dbconfig.txt"), "server", "The preference accepted an arbitrary file path.")
	TEST_ASSERT_EQUAL(preference.deserialize(list("bad")), "server", "Malformed preferences did not fall back safely.")
	var/path = 'sound/music/lobby_music/title3.ogg'
	catalog.add_track(path)
	var/id = catalog.tracks[1]
	owner.prefs.write_preference(preference, id)
	TEST_ASSERT_EQUAL(player.resolve_track(), path, "A valid saved choice was ignored.")
	TEST_ASSERT_NOTEQUAL(catalog.track_id(path, "first"), catalog.track_id(path, "replacement"), "Replacing a file did not change its preference ID.")
	TEST_ASSERT_NOTEQUAL(catalog.track_id(path, "first"), catalog.track_id("renamed.ogg", "first"), "Renaming a file did not change its preference ID.")
	catalog.tracks = list() // A rename/removal/replacement leaves the previous ID unavailable.
	TEST_ASSERT_EQUAL(player.resolve_track(), catalog.test_server_track, "An unavailable choice did not fall back to the server selection.")
	TEST_ASSERT_EQUAL(owner.prefs.read_preference(preference.type), "server", "The stale choice was not reset persistently.")
	catalog.tracks[id] = list("path" = "config/title_music/sounds/nonexistent-unit-test-track.ogg")
	owner.prefs.write_preference(preference, id)
	TEST_ASSERT_EQUAL(player.resolve_track(), catalog.test_server_track, "Deleting a file before catalog refresh did not fall back.")
