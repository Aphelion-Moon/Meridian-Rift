/// What the lobby menu's `whitelistGate` field can hold.
#define SYMPHONY_GATE_OPEN "open"
#define SYMPHONY_GATE_BLOCKED "blocked"
#define SYMPHONY_GATE_CHECKING "checking"
#define SYMPHONY_GATE_UNAVAILABLE "unavailable"

/// Return whether the whitelist gate prevents this player from entering the round.
/mob/dead/new_player/proc/symphony_blocks_play()
	return symphony_gate_state() != SYMPHONY_GATE_OPEN

// These entry points also serve callers outside the lobby menu.
/mob/dead/new_player/make_me_an_observer()
	if(symphony_blocks_play())
		symphony_gate_notice()
		return FALSE
	return ..()

/mob/dead/new_player/AttemptLateSpawn(rank)
	if(symphony_blocks_play())
		symphony_gate_notice()
		return FALSE
	return ..()

/// Resolve admission as open, blocked, or unavailable, preserving the reason for a denial.
/// Uses the whitelist cache and may sleep on a miss. Never call from process().
/mob/dead/new_player/proc/symphony_gate_state()
	if(!CONFIG_GET(flag/symphony_enabled))
		return SYMPHONY_GATE_OPEN
	if(!client)
		return SYMPHONY_GATE_BLOCKED
	if(client.holder)
		return SYMPHONY_GATE_OPEN
	var/client/checked_client = client
	var/checked_ckey = ckey
	var/answer = symphony_whitelist_lookup(checked_ckey)
	if(QDELETED(src) || !client || client != checked_client || ckey != checked_ckey)
		return SYMPHONY_GATE_BLOCKED
	if(!CONFIG_GET(flag/symphony_enabled) || client.holder)
		return SYMPHONY_GATE_OPEN
	// A failed query blocks admission but must be displayed as an outage.
	if(isnull(answer))
		return SYMPHONY_GATE_UNAVAILABLE
	return answer ? SYMPHONY_GATE_OPEN : SYMPHONY_GATE_BLOCKED

/// Validate pending admission before job selection and again immediately before character creation.
/mob/dead/new_player/proc/symphony_validate_ready()
	if(ready != PLAYER_READY_TO_PLAY)
		return FALSE
	var/blocked = symphony_blocks_play()
	if(QDELETED(src) || !client)
		return FALSE
	if(blocked)
		ready = PLAYER_NOT_READY
		show_title_screen()
		return FALSE
	// They may have unreadied while the whitelist lookup slept.
	return ready == PLAYER_READY_TO_PLAY

/// Equipment and manifest setup can yield after creation; revalidate at the final roundstart transfer.
/mob/dead/new_player/proc/symphony_validate_roundstart_transfer()
	var/mob/living/prepared_body = new_character
	if(!prepared_body)
		return TRUE
	if(QDELETED(prepared_body))
		return FALSE
	// AI initialization can already have taken the client and unreadied its old lobby on Logout().
	var/client/checked_client = client || prepared_body?.client
	if(!checked_client)
		return TRUE // Preserve the existing transfer behavior for disconnected characters.
	if(!CONFIG_GET(flag/symphony_enabled) || checked_client.holder)
		return TRUE
	var/checked_ckey = checked_client.ckey
	var/answer = symphony_whitelist_lookup(checked_ckey)
	if(QDELETED(src) || QDELETED(prepared_body) || new_character != prepared_body)
		return FALSE
	if(!checked_client)
		return !client && !prepared_body.client
	if(checked_client.ckey != checked_ckey || GLOB.directory[checked_ckey] != checked_client || (checked_client.mob != src && checked_client.mob != prepared_body))
		return FALSE
	if(!CONFIG_GET(flag/symphony_enabled) || checked_client.holder || answer)
		return TRUE
	// The old lobby no longer owns a mind. Leave the equipped body intact and create a fresh lobby mind.
	new_character = null
	symphony_return_to_lobby(checked_client, prepared_body)
	if(!QDELETED(src))
		qdel(src)
	return FALSE

/// May sleep. Display and signal handlers must continue to use the cache-only gate.
/proc/symphony_validate_ready_players()
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(!QDELETED(player))
			player.symphony_validate_ready()

/// Non-sleeping admission check: TRUE blocks play, FALSE permits it, and null means uncached.
/// Keeping unknown separate from denied prevents a rejection flash when the cache expires.
/mob/dead/new_player/proc/symphony_blocks_play_cached()
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!client)
		return TRUE
	if(client.holder)
		return FALSE
	var/cached = symphony_whitelist_cache_peek(ckey)
	return isnull(cached) ? null : !cached

/datum/lobby_menu
	/// Whether a background whitelist query is already running.
	var/whitelist_gate_refreshing = FALSE
	/// Last resolved state, retained across cache expiry. Null until the first answer.
	var/whitelist_gate_state = null

/// Return display state without sleeping; start a background refresh on a cache miss.
/// Preserve the last resolved state across cache expiry and database outages.
/datum/lobby_menu/proc/symphony_blocks_this_player()
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		return SYMPHONY_GATE_OPEN
	// Disabled enforcement and staff exemptions require no cache lookup or refresh.
	if(!CONFIG_GET(flag/symphony_enabled) || client.holder)
		return SYMPHONY_GATE_OPEN
	var/cached = symphony_whitelist_cache_peek(player.ckey)
	if(!isnull(cached))
		whitelist_gate_state = cached ? SYMPHONY_GATE_OPEN : SYMPHONY_GATE_BLOCKED
	else if(!whitelist_gate_refreshing)
		whitelist_gate_refreshing = TRUE
		refresh_whitelist_gate()
	return whitelist_gate_state || SYMPHONY_GATE_CHECKING

/// Resolve the gate asynchronously so process() and signal handlers never wait on the database.
/// Publish only if this menu and player still belong to the same client.
/datum/lobby_menu/proc/refresh_whitelist_gate()
	set waitfor = FALSE
	var/mob/dead/new_player/player = client?.mob
	if(!istype(player))
		whitelist_gate_refreshing = FALSE
		return
	var/state = player.symphony_gate_state()
	whitelist_gate_refreshing = FALSE
	if(!client || client.mob != player || player.client != client)
		return
	whitelist_gate_state = state
	send_update(list("whitelistGate" = state))

/// Publish a confirmed grant/revoke immediately, before show_title_screen() rebuilds the menu.
/datum/lobby_menu/proc/set_whitelist_gate(blocked)
	whitelist_gate_state = blocked ? SYMPHONY_GATE_BLOCKED : SYMPHONY_GATE_OPEN
	send_update(list("whitelistGate" = whitelist_gate_state))

/mob/dead/new_player/proc/symphony_gate_notice()
	// `key`, not `ckey` - ckey() strips the hyphen that is_guest_key matches on
	if(is_guest_key(key))
		to_chat(src, span_userdanger("You are logged in as a BYOND guest."))
		to_chat(src, span_warning("Guest accounts cannot be whitelisted. Sign in with a real BYOND account and reconnect to play."))
		return
	// Admission is denied during an outage, but the notice must explain the service failure.
	if(!SSdbcore.Connect())
		to_chat(src, span_userdanger("The whitelist database is unreachable."))
		to_chat(src, span_warning("This is a problem on our end, not with your account. Try again shortly."))
		return
	to_chat(src, span_userdanger("You are not whitelisted."))
	to_chat(src, span_warning("Use the <b>GET WHITELISTED</b> button on the lobby menu to link your Discord account. You must stay in the Discord with the whitelist role to play."))

#undef SYMPHONY_GATE_OPEN
#undef SYMPHONY_GATE_BLOCKED
#undef SYMPHONY_GATE_CHECKING
#undef SYMPHONY_GATE_UNAVAILABLE
