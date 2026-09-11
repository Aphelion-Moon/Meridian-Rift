/client
	var/datum/lobby_music_player/lobby_music_player

/client/proc/get_lobby_music_player()
	if(!lobby_music_player)
		lobby_music_player = new(src)
	return lobby_music_player

/client/Del()
	QDEL_NULL(lobby_music_player)
	return ..()

/// Follows the client across bodies. Native sound queries distinguish playing, ended, and stopped music.
/datum/lobby_music_player
	var/client/client
	var/datum/lobby_music_catalog/catalog
	var/current_track
	var/volume_multiplier = 1
	var/request_id = 0
	var/state_pending = FALSE
	var/manually_stopped = FALSE

/datum/lobby_music_player/New(client/owner, datum/lobby_music_catalog/catalog = GLOB.lobby_music_catalog)
	client = owner
	src.catalog = catalog

/datum/lobby_music_player/Destroy(force)
	client = null
	catalog = null
	return ..()

/datum/lobby_music_player/proc/is_enabled()
	return client?.prefs && !CONFIG_GET(flag/disallow_title_music)

/datum/lobby_music_player/proc/in_lobby()
	return isnewplayer(client?.mob)

/datum/lobby_music_player/proc/volume()
	return client.prefs.read_preference(/datum/preference/numeric/volume/sound_lobby_volume) * volume_multiplier

/datum/lobby_music_player/proc/resolve_track()
	var/choice = client.prefs.read_preference(/datum/preference/lobby_music_track)
	if(choice != LOBBY_MUSIC_SERVER)
		var/list/track = catalog.get_track(choice)
		if(track)
			return track["path"]
		// Do not retain a stale preference that could unexpectedly become valid again later.
		client.prefs.write_preference(GLOB.preference_entries[/datum/preference/lobby_music_track], LOBBY_MUSIC_SERVER)
		client.prefs.save_preferences()
	return catalog.server_track()

/datum/lobby_music_player/proc/query_sound()
	for(var/sound/playing as anything in client.SoundQuery())
		if(playing?.channel == CHANNEL_LOBBYMUSIC)
			return playing
	return null

/datum/lobby_music_player/proc/send_sound(sound/music)
	SEND_SOUND(client, music)

/datum/lobby_music_player/proc/wait_for_music()
	UNTIL(SSticker.login_music)

/// Returning to the lobby resumes an existing track; only explicit restart or a new selection replaces it.
/datum/lobby_music_player/proc/play(restart = FALSE, new_volume_multiplier = 1)
	set waitfor = FALSE
	var/request = ++request_id
	manually_stopped = FALSE
	volume_multiplier = new_volume_multiplier
	if(!is_enabled())
		stop(manual = FALSE)
		return
	wait_for_music()
	if(QDELETED(src) || !client || request != request_id)
		return
	var/track = resolve_track()
	var/sound/playing = query_sound()
	// A stop, selection change, or another play request can arrive while SoundQuery waits for the client.
	if(QDELETED(src) || !client || request != request_id)
		return
	if(!is_enabled() || !volume() || !track)
		stop(manual = FALSE)
		return
	if(playing && current_track == track && !restart)
		update_sound()
	else
		current_track = track
		send_sound(sound(track, repeat = in_lobby(), wait = FALSE, volume = volume(), channel = CHANNEL_LOBBYMUSIC))
	send_state()

/// Change looping/volume without seeking or interrupting the current track.
/datum/lobby_music_player/proc/update_sound()
	var/sound/update = sound(null, repeat = in_lobby(), volume = volume(), channel = CHANNEL_LOBBYMUSIC)
	update.status = SOUND_UPDATE
	send_sound(update)

/// Leaving the lobby disables repetition, allowing the current iteration to finish naturally.
/datum/lobby_music_player/proc/update_context()
	if(current_track)
		update_sound()
	send_state()

/datum/lobby_music_player/proc/update_volume()
	set waitfor = FALSE
	var/request = ++request_id
	var/sound/playing = query_sound()
	if(QDELETED(src) || !client || request != request_id)
		return
	if(!is_enabled() || !volume())
		stop(manual = FALSE)
	else if(playing)
		update_sound()
		send_state()
	else if(in_lobby() && !manually_stopped)
		play()
	else
		send_state()

/datum/lobby_music_player/proc/stop(manual = TRUE)
	request_id++
	manually_stopped = manual
	current_track = null
	if(client)
		send_sound(sound(null, channel = CHANNEL_LOBBYMUSIC))
	send_state()

/// Only the open music panel polls this; native playback itself requires no server polling or timers.
/datum/lobby_music_player/proc/send_state()
	set waitfor = FALSE
	if(state_pending || !client?.prefs || !client.tgui_panel?.is_ready())
		return
	state_pending = TRUE
	wait_for_music()
	if(QDELETED(src) || !client)
		state_pending = FALSE
		return
	var/request = request_id
	var/track = resolve_track()
	var/sound/playing = query_sound()
	state_pending = FALSE
	if(QDELETED(src) || !client || request != request_id)
		return
	if(playing && in_lobby() && current_track != track)
		// Refreshing the open controls also applies a stale-choice fallback while in the lobby.
		play()
		return
	client.tgui_panel.window.send_message("audio/lobby/state", list(
		"enabled" = is_enabled() && !!track,
		"playing" = !!playing,
		"looping" = playing ? !!playing.repeat : in_lobby(),
		"volume" = client.prefs.read_preference(/datum/preference/numeric/volume/sound_lobby_volume),
		"selected" = client.prefs.read_preference(/datum/preference/lobby_music_track),
		"currentTrack" = lobby_music_name(playing ? current_track : track),
		"serverTrack" = lobby_music_name(catalog.server_track()),
		"tracks" = catalog.ui_tracks(),
	))

/mob/Login()
	. = ..()
	if(client && !isnewplayer(src))
		client.lobby_music_player?.update_context()
