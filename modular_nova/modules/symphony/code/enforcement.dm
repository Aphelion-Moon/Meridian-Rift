/// Announce a revoke, block pending admission, and schedule enforcement after the grace period.
/proc/symphony_revoke(target_ckey)
	// The panel pushes revokes whether we're enforcing or not.
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	target_ckey = ckey(target_ckey)
	symphony_seed_whitelist_cache(target_ckey, FALSE)
	var/client/found = GLOB.directory[target_ckey]
	if(!found)
		return
	// Staff retain the same exemption as the admission gate.
	if(found.holder)
		return
	if(isnewplayer(found.mob))
		var/mob/dead/new_player/lobby = found.mob
		to_chat(found, span_userdanger("Your Discord whitelist role was removed."))
		// Drop their pending admission immediately, as well as updating the visible gate.
		lobby.ready = PLAYER_NOT_READY
		// Seed the visible state before rebuilding the lobby menu.
		found.lobby_menu?.set_whitelist_gate(TRUE)
		lobby.show_title_screen()
		return
	var/grace = CONFIG_GET(number/symphony_grace_seconds)
	to_chat(found, span_userdanger("Your Discord whitelist role was removed. You will be returned to the lobby in [grace] seconds unless it is restored."))
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_enforce_kick), target_ckey), grace SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Recheck a revoke after its grace period, then return the player to the lobby.
/// A failed query leaves them in the round; the periodic sweep retries when the database recovers.
/proc/symphony_enforce_kick(target_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	target_ckey = ckey(target_ckey)
	var/client/found = GLOB.directory[target_ckey]
	if(!found || isnewplayer(found.mob))
		return
	// Staff status may have changed during the grace period.
	if(found.holder)
		return
	var/whitelisted = symphony_whitelist_lookup(target_ckey)
	// The query can sleep through a disconnect, staff promotion, lobby return, or enforcement toggle.
	if(!CONFIG_GET(flag/symphony_enabled) || !found || GLOB.directory[target_ckey] != found || found.holder || !found.mob || isnewplayer(found.mob))
		return
	// An outage is not a confirmed revoke. The periodic sweep will retry.
	if(isnull(whitelisted))
		log_game("Symphony: skipped returning [key_name(found)] to the lobby, the whitelist database was unreachable.")
		return
	if(whitelisted)
		to_chat(found, span_notice("Whitelist role restored - you may continue playing."))
		return
	to_chat(found, span_userdanger("Whitelist lost. Returning you to the lobby."))
	symphony_return_to_lobby(found)

/proc/symphony_return_to_lobby(client/target, mob/prepared_body)
	if(!target)
		return
	var/mob/old_mob = prepared_body || target.mob
	if(old_mob && !isnewplayer(old_mob))
		old_mob.log_message("returned to lobby by discord whitelist enforcement", LOG_GAME)
		// The lobby mob's Login() makes a new mind, so retire this one or the key owns two.
		if(old_mob.mind)
			old_mob.mind.active = FALSE
	var/mob/dead/new_player/lobby = new()
	lobby.key = target.key
	if(!target || QDELETED(lobby) || target.mob != lobby)
		return // Lobby Login() can yield through a disconnect or another client transfer.
	// Login may also have slept through a grant or config change; keep the current gate state.
	var/blocked = lobby.symphony_blocks_play_cached()
	target.lobby_menu?.set_whitelist_gate(isnull(blocked) || blocked)
	lobby.show_title_screen()
	// Notify staff because the abandoned body may still be relevant to the round.
	message_admins("Symphony: [key_name_admin(target)] was returned to the lobby by whitelist enforcement. Their body was left in place[old_mob ? " at [AREACOORD(old_mob)]" : ""].")

/// Re-check on connect, the grace timer is one shot so a relog would otherwise dodge it.
/client/New()
	. = ..()
	if(!.)
		return
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	if(!ckey || !mob || isnewplayer(mob)) // the lobby has its own gate
		return
	if(holder) // staff exemption, as in gate.dm
		return
	// Only a confirmed FALSE justifies announcing a revoke; null means a database outage.
	var/whitelisted = symphony_whitelist_lookup(ckey)
	if(!src || !CONFIG_GET(flag/symphony_enabled) || holder || !mob || isnewplayer(mob))
		return
	if(isnull(whitelisted) || whitelisted)
		return
	symphony_revoke(ckey)

/proc/symphony_notify_grant(target_ckey)
	// Disabled enforcement must not announce or change the lobby gate.
	if(!CONFIG_GET(flag/symphony_enabled))
		return
	symphony_seed_whitelist_cache(target_ckey, TRUE)
	var/client/found = GLOB.directory[ckey(target_ckey)]
	if(!found)
		return
	to_chat(found, span_greentext("You are now whitelisted - you can join the round."))
	var/mob/dead/new_player/lobby_mob = found.mob
	if(istype(lobby_mob))
		found.lobby_menu?.set_whitelist_gate(FALSE)
		lobby_mob.show_title_screen()
