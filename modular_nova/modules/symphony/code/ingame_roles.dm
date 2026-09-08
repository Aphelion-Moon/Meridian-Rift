/// Available Discord mappings, derived from current ranks and configuration.
/datum/world_topic/symphony/ingame_roles
	keyword = "symphony_ingame_roles"

/datum/world_topic/symphony/ingame_roles/Run(list/input)
	var/list/role_descriptions = list("whitelist" = "Required to join the round.")
	if(symphony_discord_admin_sync_enabled())
		for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
			if(!rank?.name)
				continue
			// Multiple rank datums may share a name, but the panel maps each key only once.
			role_descriptions["admin:[rank.name]"] = "Grants the in-game admin rank \"[rank.name]\"."
	var/list/roles = list()
	for(var/key in role_descriptions)
		roles += list(list("key" = key, "description" = role_descriptions[key]))
	return list("roles" = roles)
