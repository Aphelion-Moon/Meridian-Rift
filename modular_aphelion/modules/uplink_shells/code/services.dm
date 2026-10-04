/// Existing AI interfaces keep their original owner and UI user. Only transport goes to the shell.
/datum/tgui
	var/datum/ai_shell_session/uplink_session

/datum/tgui/proc/uplink_ui_viewer()
	if(uplink_session)
		return uplink_session.matches() ? uplink_session.endpoint : null
	return user

/datum/tgui/proc/uplink_ui_client()
	var/mob/viewer = uplink_ui_viewer()
	return viewer?.client

/datum/ai_shell_session/proc/services_available()
	if(!matches() || !endpoint.client || core.shell_service_denial())
		return FALSE
	if(iscyborg(endpoint))
		var/mob/living/silicon/robot/robot = endpoint
		return !robot.incapacitated && !robot.lockcharge
	return TRUE

/datum/ai_shell_session/proc/local_target(atom/target)
	var/turf/target_turf = get_turf(target)
	return services_available() && target_turf && isturf(endpoint.loc) && target_turf.z == endpoint.z && get_dist(endpoint, target) <= /mob/living/silicon::interaction_range && (target in view(/mob/living/silicon::interaction_range, endpoint))

/datum/ai_shell_session/proc/network_click(mob/source, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!network_mode || !matches())
		return NONE
	if(local_target(target))
		INVOKE_ASYNC(src, PROC_REF(dispatch_network_click), target, modifiers)
	else
		to_chat(endpoint, span_warning("Network target unavailable: use a visible target within cyborg wireless range, with an operational core link."))
	return COMSIG_MOB_CANCEL_CLICKON

/datum/ai_shell_session/proc/dispatch_network_click(atom/target, list/modifiers)
	if(!network_mode || !local_target(target))
		return
	if(photo_mode)
		photo_mode = FALSE
		network_mode = FALSE
		core.aicamera?.attempt_picture(target, endpoint)
		return
	world.push_usr(core, CALLBACK(core, TYPE_PROC_REF(/mob, ClickOn), target, list2params(modifiers)))

/datum/action/innate/uplink_services
	name = "AI Services"
	desc = "Open your AI's existing interfaces or switch local network interaction on/off."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_core"
	var/datum/ai_shell_session/session

/datum/action/innate/uplink_services/New(datum/ai_shell_session/new_session)
	..()
	session = new_session

/datum/action/innate/uplink_services/Trigger(mob/clicker, trigger_flags)
	if(!..() || !session?.matches())
		return FALSE
	return session.core.run_ai_command("AI services")
