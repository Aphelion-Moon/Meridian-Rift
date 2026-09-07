/// Safety net for revokes we never heard about.
SUBSYSTEM_DEF(symphony)
	name = "Discord Whitelist"
	wait = 5 MINUTES
	ss_flags = SS_BACKGROUND | SS_NO_INIT
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME

	// Static state survives subsystem replacement, including queries still waiting on the database.
	/// Admission answers keyed by ckey, shared by lobby updates and enforcement.
	var/static/list/whitelist_cache = list()
	/// Expiry time for each cached admission answer.
	var/static/list/whitelist_cache_expiry = list()
	/// Incremented when grants change so queries can reject stale results after yielding.
	var/static/whitelist_epoch = 0
	/// Last authenticated panel contact accepted by the address gate.
	var/static/list/panel = list()
	/// Last authenticated contact refused by the address gate, kept separate for diagnostics.
	var/static/list/panel_refused = list()

/datum/controller/subsystem/symphony/fire()
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	// One query for the lot. null means we couldn't check, an empty list means nobody holds it.
	var/epoch = SSsymphony.whitelist_epoch
	var/list/holders = symphony_ingame_role_ckeys("whitelist")
	// A panel notification or config change during the query makes the whole snapshot obsolete.
	if(isnull(holders) || !CONFIG_GET(flag/symphony_enabled) || epoch != SSsymphony.whitelist_epoch)
		return
	// A copy, because revoking can qdel a client out from under the loop.
	for(var/client/checked as anything in GLOB.clients.Copy())
		if(!checked || !checked.ckey)
			continue
		// We've got the real answer in bulk, so write it over whatever the per-ckey cache held. Blanking it instead just forces everyone to re-query for something we already know.
		var/whitelisted = holders[checked.ckey] ? TRUE : FALSE
		symphony_seed_whitelist_cache(checked.ckey, whitelisted)
		if(whitelisted)
			continue
		if(checked.holder)
			continue
		// Lobby players need unreadying too, or a missed revoke still spawns them.
		if(isnewplayer(checked.mob))
			var/mob/dead/new_player/lobby = checked.mob
			if(lobby.ready != PLAYER_NOT_READY)
				lobby.ready = PLAYER_NOT_READY
				lobby.show_title_screen()
			continue
		if(!checked.mob)
			continue
		symphony_revoke(checked.ckey)
