/// The announcement sounds our announcer knows. The keys are what symphony_announce takes.
/datum/world_topic/symphony/announce_sounds
	keyword = "symphony_announce_sounds"
	log = FALSE

/datum/world_topic/symphony/announce_sounds/Run(list/input)
	. = list()
	.["sounds"] = assoc_to_keys(SSstation.announcer?.event_sounds)
	.["announcer"] = "[SSstation.announcer?.type]"

/// Message from SSymphony to the round.
/datum/world_topic/symphony/announce
	keyword = "symphony_announce"

/datum/world_topic/symphony/announce/Run(list/input)
	. = list()
	var/message = input["message"]
	if(!message)
		.["success"] = FALSE
		.["message"] = "missing message"
		return

	var/mode = input["mode"] || "minor"
	var/audience = input["audience"] || "all"
	var/title = input["title"]
	var/from = input["from"]
	var/sound_key = input["sound"]
	var/play_sound = sound_key != "none"
	// Station announcements reach the whole round, so admin messages use chat.
	if(audience == "admins")
		mode = "chat"

	switch(mode)
		if("priority")
			var/type
			switch(input["kind"])
				if("Priority")
					type = ANNOUNCEMENT_TYPE_PRIORITY
				if("Captain")
					type = ANNOUNCEMENT_TYPE_CAPTAIN
				if("Syndicate")
					type = ANNOUNCEMENT_TYPE_SYNDICATE
			// Priority always plays something, "none" can't silence it, so the panel doesn't offer it.
			priority_announce(message, title, (play_sound && sound_key) ? sound_key : null, type, from ? html_encode(from) : "SSymphony")
		if("chat")
			var/body = html_encode(message)
			switch(input["style"])
				if("alert")
					body = span_userdanger(body)
				if("warning")
					body = span_boldwarning(body)
				else
					body = span_boldnotice(body)
			var/list/lines = list()
			if(title)
				lines += span_boldannounce(html_encode(title))
			lines += body
			if(from)
				lines += span_smallnotice("- [html_encode(from)] via SSymphony")
			var/out = lines.Join("<br>")
			for(var/client/target as anything in GLOB.clients)
				if(audience == "admins" && !target.holder)
					continue
				to_chat(target, out)
		else
			// minor_announce takes a sound file; priority_announce resolves its own key.
			var/resolved_sound = (play_sound && sound_key) ? SSstation.announcer?.event_sounds[sound_key] : null
			minor_announce(message, title || "Attention:", alert = FALSE, sound_override = resolved_sound, should_play_sound = play_sound)

	log_admin_private("SSymphony announcement ([mode], [audience])[from ? " from [from]" : ""]: [message]")
	.["success"] = TRUE
	.["mode"] = mode
