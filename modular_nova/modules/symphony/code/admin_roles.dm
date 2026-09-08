/// Discord admin grants require both the module and admin sync flags.
/proc/symphony_discord_admin_sync_enabled()
	return CONFIG_GET(flag/symphony_enabled) && CONFIG_GET(flag/symphony_discord_admin_sync)

/// Runs after load_admins() clears and rebuilds local/SQL holders, which take precedence.
/proc/symphony_apply_discord_admins()
	if(!symphony_discord_admin_sync_enabled())
		return 0

	var/list/ranks_by_ckey = list()
	for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
		if(!rank?.name)
			continue
		var/role_key = "admin:[rank.name]"
		var/list/holders = symphony_ingame_role_ckeys(role_key)
		// A failed role query must not grant any ranks.
		if(isnull(holders))
			continue
		for(var/holder_ckey in holders)
			if(GLOB.admin_datums[holder_ckey] || GLOB.deadmins[holder_ckey])
				continue
			LAZYOR(ranks_by_ckey[holder_ckey], rank)

	// Gather every mapping before creating holders, or the first rank hides later grants.
	// The queries can sleep: preserve any local/SQL grants made while they were running.
	if(!symphony_discord_admin_sync_enabled())
		return 0
	var/granted = 0
	for(var/holder_ckey in ranks_by_ckey)
		if(GLOB.admin_datums[holder_ckey] || GLOB.deadmins[holder_ckey])
			continue
		new /datum/admins(ranks_by_ckey[holder_ckey], holder_ckey)
		granted++

	if(granted)
		log_admin("Symphony: granted [granted] admin\s from Discord roles.")
	return granted

/// Rank discovery remains available when Discord sync is disabled.
/datum/world_topic/symphony/admin_ranks
	keyword = "symphony_admin_ranks"

/datum/world_topic/symphony/admin_ranks/Run(list/input)
	. = list()
	var/list/ranks = list()
	for(var/datum/admin_rank/rank as anything in GLOB.admin_ranks)
		if(!rank?.name)
			continue
		ranks += list(list(
			"name" = rank.name,
			"protected" = (rank in GLOB.protected_ranks),
		))
	.["ranks"] = ranks
	.["discord_sync"] = symphony_discord_admin_sync_enabled() ? TRUE : FALSE
	// Legacy mode does not read the SQL admin grants written by the panel.
	.["legacy_admin_system"] = CONFIG_GET(flag/admin_legacy_system) ? TRUE : FALSE

/datum/world_topic/symphony/reload_admins
	keyword = "symphony_reload_admins"

/datum/world_topic/symphony/reload_admins/Run(list/input)
	. = list()
	load_admins()
	.["success"] = TRUE
	.["admins"] = length(GLOB.admin_datums)
	log_admin("Symphony: admins reloaded from the panel.")
