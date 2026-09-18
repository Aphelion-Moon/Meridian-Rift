/// How long a player has to wait between uses of the Notify Admins verb.
#define ADMIN_NOTIFY_COOLDOWN (2 MINUTES)
/// How long the Notify Admins hotkey has to be held down before it fires.
#define ADMIN_NOTIFY_HOLD_TIME (2 SECONDS)

/client
	/// Timer id for the hotkey's hold delay. Hung off the client so it dies with them on disconnect.
	var/notify_admins_hold_timer
	/// Physical-key press timestamps for the notify binding that started the timer.
	var/list/notify_admins_held_keys

/datum/persistent_client
	/// World time at which this player may notify admins again, including after reconnecting.
	COOLDOWN_DECLARE(notify_admins_cooldown)

GAME_VERB_DESC(/client, notify_admins, "Notify Admins", "Ask staff to come and observe what is happening to you.", "OOC")
	if(is_banned_from(ckey, BAN_ADMIN_NOTIFY))
		to_chat(src, span_danger("You are not able to use this."))
		return

	if(!COOLDOWN_FINISHED(persistent_client, notify_admins_cooldown))
		to_chat(src, span_warning("You can notify the admins again in [DisplayTimeText(COOLDOWN_TIMELEFT(persistent_client, notify_admins_cooldown))]."))
		return

	if(isnewplayer(mob))
		return

	COOLDOWN_START(persistent_client, notify_admins_cooldown, ADMIN_NOTIFY_COOLDOWN)

	log_admin("[key_name(src)] notified admins to observe them.")
	to_chat(GLOB.admins,
		type = MESSAGE_TYPE_ADMINPM,
		html = span_adminhelp("[key_name_admin(src)] has requested admin attention/observation. [ADMIN_FLW(mob)]"),
		confidential = TRUE
	)

	for(var/client/admin_client as anything in GLOB.admins)
		if(!admin_client.prefs?.read_preference(/datum/preference/toggle/admin_notify_alert))
			continue
		SEND_SOUND(admin_client, sound('modular_aphelion/modules/admin_notify/sound/admin_notify.ogg', volume = 50))
		window_flash(admin_client)

	if(!length(GLOB.admins))
		to_chat(src, span_warning("No staff are online at the moment. Your request has been logged, but use Adminhelp if you need it seen."))
		return

	to_chat(src, span_notice("You've notified the admins to take a look at you."))

/// Hotkey pairing for the verb above. Held rather than tapped so nobody fat-fingers the whole staff team.
/datum/keybinding/client/notify_admins
	hotkey_keys = list(UNBOUND_KEY)
	name = "notify_admins"
	full_name = "Notify Admins (Hold)"
	description = "Hold for 2 seconds to notify admins to come observe you."
	keybind_signal = COMSIG_KB_NOTIFYADMINS_DOWN

/datum/keybinding/client/notify_admins/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	if(user.notify_admins_hold_timer)
		if(user.is_holding_admin_notify())
			return TRUE
		deltimer(user.notify_admins_hold_timer)
		user.notify_admins_hold_timer = null
	// Checked here as well as in the verb so a player on cooldown finds out now, not two seconds from now.
	// Deliberately not the ban check, which can block on the ban cache and has no business doing that in a keypress.
	if(!COOLDOWN_FINISHED(user.persistent_client, notify_admins_cooldown))
		to_chat(user, span_warning("You can notify the admins again in [DisplayTimeText(COOLDOWN_TIMELEFT(user.persistent_client, notify_admins_cooldown))]."))
		return TRUE
	user.notify_admins_held_keys = get_held_keys(user)
	if(!length(user.notify_admins_held_keys))
		return TRUE
	to_chat(user, span_notice("Keep holding to notify admins..."))
	user.notify_admins_hold_timer = addtimer(CALLBACK(user, TYPE_PROC_REF(/client, finish_notify_admins)), ADMIN_NOTIFY_HOLD_TIME, TIMER_STOPPABLE)
	return TRUE

/datum/keybinding/client/notify_admins/up(client/user, turf/target)
	. = ..()
	if(user.is_holding_admin_notify())
		return
	if(user.notify_admins_hold_timer)
		deltimer(user.notify_admins_hold_timer)
		user.notify_admins_hold_timer = null
	user.notify_admins_held_keys = null

/// Recover the triggering chord from keyDown's timestamps without modifying the shared input handler.
/datum/keybinding/client/notify_admins/proc/get_held_keys(client/user)
	var/pressed_key
	var/pressed_at = -1
	for(var/key, time in user.keys_held)
		// New presses append to keys_held, so its order breaks ties within the same world tick.
		if(time >= pressed_at)
			pressed_key = key
			pressed_at = time
	if(isnull(pressed_key))
		return

	var/list/modifiers = list("Alt", "Ctrl", "Shift")
	var/list/keypresses = list()
	var/full_key = ""
	for(var/modifier in modifiers)
		if(user.keys_held[modifier])
			full_key += modifier
			keypresses[modifier] = user.keys_held[modifier]
	if(!(pressed_key in modifiers))
		full_key += pressed_key
		keypresses[pressed_key] = pressed_at
	if(full_key in user.prefs.key_bindings[name])
		return keypresses

/// Validate the captured chord even if its up() never ran. Timestamps have world.time's tick precision.
/client/proc/is_holding_admin_notify()
	if(!length(notify_admins_held_keys))
		return FALSE
	for(var/key in notify_admins_held_keys)
		if(!(key in keys_held) || keys_held[key] != notify_admins_held_keys[key])
			return FALSE
	return TRUE

/// Called by the hold timer once the key has been down long enough.
/client/proc/finish_notify_admins()
	var/still_held = is_holding_admin_notify()
	notify_admins_hold_timer = null
	notify_admins_held_keys = null
	if(still_held)
		notify_admins()

#undef ADMIN_NOTIFY_COOLDOWN
#undef ADMIN_NOTIFY_HOLD_TIME
