/datum/keybinding/artificial_intelligence
	category = CATEGORY_AI
	weight = WEIGHT_AI

/datum/keybinding/artificial_intelligence/can_use(client/user)
	// APHELION EDIT CHANGE START - resolve the authenticated AI from all three control modes.
	// ORIGINAL: return isAI(user.mob)
	var/mob/living/body = user.mob
	return istype(body) && !!body.ai_controller()
	// APHELION EDIT CHANGE END

/datum/keybinding/artificial_intelligence/reconnect
	hotkey_keys = list(UNBOUND_KEY) // APHELION EDIT CHANGE - ORIGINAL: hotkey_keys = list("-")
	name = "reconnect"
	full_name = "Reconnect to Cyborg Shell" // APHELION EDIT CHANGE - ORIGINAL: full_name = "Reconnect to shell"
	command = "Reconnect cyborg" // APHELION EDIT ADDITION
	description = "Reconnects you to your most recently used AI shell"
	keybind_signal = COMSIG_KB_SILICON_RECONNECT_DOWN

/* APHELION EDIT REMOVAL START - inherited AI dispatcher handles all authorized endpoints.
ORIGINAL:
/datum/keybinding/artificial_intelligence/reconnect/down(client/user, turf/target, mousepos_x, mousepos_y)
	. = ..()
	if(.)
		return
	var/mob/living/silicon/ai/our_ai = user.mob
	our_ai.select_shell(our_ai.redeploy_action.last_used_shell)
	return TRUE
APHELION EDIT REMOVAL END */
