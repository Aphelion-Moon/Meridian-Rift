/datum/tgui_panel
	var/lobby_music_next_request = 0

/datum/tgui_panel/on_message(type, payload)
	if(type == "ready")
		. = ..()
		client.get_lobby_music_player().send_state()
		return .
	if(findtext(type, "audio/lobby/") == 1 && !client?.prefs)
		return TRUE
	switch(type)
		if("audio/lobby/request")
			if(world.time >= lobby_music_next_request)
				lobby_music_next_request = world.time + 1 SECONDS
				client.get_lobby_music_player().send_state()
		if("audio/lobby/play", "audio/lobby/restart")
			client.get_lobby_music_player().play(restart = type == "audio/lobby/restart")
		if("audio/lobby/stop")
			client.get_lobby_music_player().stop()
		if("audio/lobby/volume")
			if(!islist(payload) || !isnum(payload["volume"]) || payload["volume"] < 0 || payload["volume"] > 100)
				return TRUE
			client.prefs.update_preference(GLOB.preference_entries[/datum/preference/numeric/volume/sound_lobby_volume], round(payload["volume"]))
			client.prefs.save_preferences()
		if("audio/lobby/select")
			if(!islist(payload) || !istext(payload["id"]))
				return TRUE
			var/choice = payload["id"]
			if(choice != LOBBY_MUSIC_SERVER && !GLOB.lobby_music_catalog.get_track(choice))
				choice = LOBBY_MUSIC_SERVER
			client.prefs.update_preference(GLOB.preference_entries[/datum/preference/lobby_music_track], choice)
			client.prefs.save_preferences()
		else
			return ..()
	return TRUE
