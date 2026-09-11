/world/proc/update_status()
	var/list/features = list()

	var/static/cached_prefix
	var/prefix = cached_prefix || ""

	if(isnull(cached_prefix))
		if(config)
			var/server_name = CONFIG_GET(string/servername)
			if(server_name)
				prefix += "<b>[server_name]</b><br>"
				var/discord = CONFIG_GET(string/discord_link)
				if(discord)
					prefix += "(<a href=\"[discord]\">Discord</a>)"
				var/wiki_url = CONFIG_GET(string/wikiurl)
				if(wiki_url)
					prefix += " | (<a href=\"[wiki_url]\">Wiki</a>)"
		prefix += "<br>[CONFIG_GET(string/servertagline)]<br>"
		// If we at least have loaded the config system, we don't have to keep doing all this
		if(global.config?.loaded)
			cached_prefix = prefix

	if(SSticker.HasRoundStarted())
		features += "Open | [round_timestamp("hh:mm")]"
	else
		features += "Starting"

	status = prefix + (length(features) ? "\[[jointext(features, ", ")]" : "")

