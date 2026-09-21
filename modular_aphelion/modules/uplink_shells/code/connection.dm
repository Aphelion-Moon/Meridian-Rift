/// Control sessions are distinct from personal allocation. Crew-built endpoints use this too.
/mob/living/silicon/ai
	var/datum/ai_shell_session/shell_session
	var/shell_session_generation = 0
	var/datum/weakref/uplink_resume
	var/datum/action/innate/uplink_resume/uplink_resume_action

/mob/living
	var/datum/ai_shell_session/ai_shell_session

/mob/living/silicon/ai/proc/uplink_player()
	if(shell_session?.matches())
		return shell_session.endpoint
	return src

/// Camera power, actuator power and the ability to receive our own mind are different capabilities.
/mob/living/silicon/ai/proc/shell_control_denial(mob/living/endpoint)
	if(QDELETED(src) || stat == DEAD)
		return "The authoritative core is offline."
	if(control_disabled || controlled_equipment || !isturf(loc))
		return "The core has no available wireless control link."
	if(QDELETED(endpoint) || endpoint.stat)
		return "The endpoint is not conscious and operational."
	if(iscyborg(endpoint) && incapacitated)
		return "The core cannot deploy a cyborg in its current state."
	return null

/mob/living/silicon/ai/proc/shell_return_denial(datum/mind/identity)
	if(QDELETED(src))
		return "The receiving core no longer exists."
	if(mind && mind != identity)
		return "The receiving core belongs to another mind."
	return null

/mob/living/silicon/ai/proc/shell_service_denial()
	if(QDELETED(src) || stat == DEAD || control_disabled || controlled_equipment || !isturf(loc))
		return "Core network services are unavailable."
	if(incapacitated || lacks_power())
		return "Core network services require restored mains power. Physical Uplink control and safe return remain separate."
	return null

/mob/living/silicon/ai/proc/connect_shell(mob/living/target, obj/item/organ/brain/cybernetic/ai/brain)
	var/reason = shell_control_denial(target)
	if(reason)
		to_chat(uplink_player(), span_warning(reason))
		return FALSE
	if(shell_session || deployed_shell || !mind || mind.current != src || !client || target.mind || target.key || target.ai_shell_session)
		return FALSE
	if(brain)
		if(brain.organ_flags & ORGAN_FAILING)
			return FALSE
		if(brain.personal_authorization_revoked)
			return FALSE
		if(brain.personal_registry && !brain.personal_registry.authorize(target, brain, src))
			return FALSE
		if(istype(target, /mob/living/carbon/human/uplink))
			var/mob/living/carbon/human/uplink/body = target
			if(!body.registry?.authorize(body, brain, src))
				return FALSE
		if(brain.owner != target || brain.mainframe || (brain.connected_ai && brain.connected_ai != src) || !brain.is_sufficiently_augmented())
			return FALSE
	else
		var/mob/living/silicon/robot/robot = target
		if(!istype(robot) || !robot.shell || robot.deployed || (robot.connected_ai && robot.connected_ai != src))
			return FALSE
	var/datum/ai_shell_session/session = new(src, target, brain)
	return session.start()

/datum/ai_shell_session
	var/mob/living/silicon/ai/core
	var/mob/living/endpoint
	var/datum/mind/identity
	var/obj/item/organ/brain/cybernetic/ai/brain
	var/generation
	var/ending = FALSE
	var/network_mode = FALSE
	var/datum/action/innate/uplink_services/services_action
	var/photo_mode = FALSE

/datum/ai_shell_session/New(mob/living/silicon/ai/new_core, mob/living/new_endpoint, obj/item/organ/brain/cybernetic/ai/new_brain)
	core = new_core
	endpoint = new_endpoint
	identity = core.mind
	brain = new_brain
	generation = ++core.shell_session_generation

/datum/ai_shell_session/proc/matches()
	return !ending && !QDELETED(core) && !QDELETED(endpoint) && core.shell_session == src && endpoint.ai_shell_session == src && core.shell_session_generation == generation && identity?.current == endpoint && endpoint.mind == identity

/datum/ai_shell_session/proc/start()
	SStgui.close_user_uis(core)
	core.end_multicam()
	core.shell_session = src
	core.deployed_shell = endpoint
	endpoint.ai_shell_session = src
	RegisterSignals(endpoint, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_LIVING_PRE_WABBAJACKED), PROC_REF(endpoint_lost))
	RegisterSignal(core, COMSIG_QDELETING, PROC_REF(core_lost))
	RegisterSignal(identity, COMSIG_MIND_TRANSFERRED, PROC_REF(mind_moved))
	RegisterSignal(endpoint, COMSIG_MOB_LOGOUT, PROC_REF(player_left))
	RegisterSignal(endpoint, COMSIG_MOB_STATCHANGE, PROC_REF(endpoint_state_changed))
	if(brain)
		brain.deploy_init(core)
		RegisterSignal(endpoint, COMSIG_MOB_CLICKON, PROC_REF(network_click))
		services_action = new(src)
		services_action.Grant(endpoint)
		ADD_TRAIT(identity, TRAIT_UNCONVERTABLE, REF(brain))
		ADD_TRAIT(core, TRAIT_MIND_TEMPORARILY_GONE, REF(brain))
		endpoint.copy_languages(core.get_language_holder())
	else
		var/mob/living/silicon/robot/robot = endpoint
		robot.deploy_init(core)
		ADD_TRAIT(endpoint, TRAIT_LOUD_BINARY, REF(core))
	identity.transfer_to(endpoint)
	core.diag_hud_set_deployed()
	return matches()

/datum/ai_shell_session/proc/endpoint_lost(datum/source)
	SIGNAL_HANDLER
	if(source == endpoint)
		finish("Endpoint unavailable")

/datum/ai_shell_session/proc/endpoint_state_changed()
	SIGNAL_HANDLER
	if(endpoint?.stat && brain)
		finish("Uplink body incapacitated")

/datum/ai_shell_session/proc/core_lost(datum/source)
	SIGNAL_HANDLER
	finish("Core destroyed", terminal = TRUE)

/datum/ai_shell_session/proc/mind_moved(datum/source, mob/old_body)
	SIGNAL_HANDLER
	if(!ending && identity.current != endpoint)
		finish("External mind transfer", move_mind = FALSE)

/datum/ai_shell_session/proc/player_left()
	SIGNAL_HANDLER
	network_mode = FALSE
	photo_mode = FALSE
	core.click_intercept = null
	SStgui.close_user_uis(core)
	if(istype(endpoint, /mob/living/carbon/human/uplink))
		var/mob/living/carbon/human/uplink/body = endpoint
		body.stow_uplink_tools()

/// All exits invalidate the session before touching the mind. Unattended organs cannot recall another endpoint.
/datum/ai_shell_session/proc/finish(reason, ai_view = FALSE, terminal = FALSE, move_mind = TRUE)
	if(ending || core?.shell_session != src || endpoint?.ai_shell_session != src || core.shell_session_generation != generation)
		return FALSE
	if(move_mind && !terminal && core.shell_return_denial(identity))
		return FALSE
	var/turf/launch_turf = get_turf(endpoint)
	if(ai_view && core.shell_service_denial())
		to_chat(endpoint, span_warning("Camera view is unavailable. Returning safely to the core's emergency controls."))
	ending = TRUE
	network_mode = FALSE
	photo_mode = FALSE
	core.click_intercept = null
	core.setting_waypoint = FALSE
	UnregisterSignal(endpoint, COMSIG_MOB_LOGOUT)
	UnregisterSignal(endpoint, COMSIG_MOB_STATCHANGE)
	QDEL_NULL(services_action)
	UnregisterSignal(endpoint, COMSIG_MOB_CLICKON)
	if(istype(endpoint, /mob/living/carbon/human/uplink))
		var/mob/living/carbon/human/uplink/body = endpoint
		body.stow_uplink_tools()
	endpoint.remove_traits(list(TRAIT_MEDICAL_HUD_SENSOR_ONLY, TRAIT_SECURITY_HUD_ID_ONLY, TRAIT_DIAGNOSTIC_HUD), REF(src))
	UnregisterSignal(endpoint, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_LIVING_PRE_WABBAJACKED))
	UnregisterSignal(core, COMSIG_QDELETING)
	UnregisterSignal(identity, COMSIG_MIND_TRANSFERRED)
	SStgui.close_user_uis(endpoint)
	SStgui.close_user_uis(core)
	if(brain)
		brain.end_shell_session()
		core.uplink_resume = WEAKREF(endpoint)
		if(!core.uplink_resume_action)
			core.uplink_resume_action = new
		core.uplink_resume_action.Grant(core)
	else
		var/mob/living/silicon/robot/robot = endpoint
		robot.deployed = FALSE
		robot.undeployment_action.Remove(robot)
		REMOVE_TRAIT(robot, TRAIT_LOUD_BINARY, REF(core))
		robot.radio?.recalculateChannels()
		robot.mainframe = null
		robot.diag_hud_set_aishell()
		core.redeploy_action.last_used_shell = robot
		core.redeploy_action.Grant(core)
	endpoint.ai_shell_session = null
	core.shell_session = null
	core.deployed_shell = null
	core.shell_session_generation++
	if(move_mind && identity.current == endpoint && endpoint.mind == identity)
		if(!terminal && !core.shell_return_denial(identity))
			identity.transfer_to(core)
		else
			endpoint.ghostize(FALSE)
			endpoint.mind = null
			identity.set_current(null)
	core.diag_hud_set_deployed()
	if(core.client && ai_view && launch_turf && !core.shell_service_denial())
		core.ai_tracking_tool?.reset_tracking()
		core.end_multicam()
		if(istype(core.current, /obj/machinery/holopad))
			var/obj/machinery/holopad/pad = core.current
			pad.clear_holo(core)
		if(is_valid_z_level(get_turf(core), launch_turf))
			core.eyeobj?.setLoc(launch_turf, TRUE)
		else
			to_chat(core, span_warning("The shell's z-level is outside this core's permitted camera region. AI View remains at the core; Resume can still reconnect to the body."))
		core.eyeobj?.update_visibility()
	to_chat(core.uplink_player(), span_notice("Shell session ended: [reason]."))
	qdel(src)
	return TRUE

/datum/ai_shell_session/Destroy()
	core = null
	endpoint = null
	identity = null
	brain = null
	return ..()

/datum/action/innate/uplink_resume
	name = "Resume Uplink Shell"
	desc = "Reconnect to the same authorized body at its current location."
	button_icon = 'icons/mob/actions/actions_AI.dmi'
	button_icon_state = "ai_last_shell"

/datum/action/innate/uplink_resume/Trigger(mob/clicker, trigger_flags)
	if(!..() || !isAI(owner))
		return FALSE
	var/mob/living/silicon/ai/core = owner
	var/mob/living/carbon/target = core.uplink_resume?.resolve()
	var/obj/item/organ/brain/cybernetic/ai/brain = target?.get_organ_by_type(/obj/item/organ/brain/cybernetic/ai)
	if(!brain || brain.connected_ai != core)
		to_chat(owner, span_warning("The previous Uplink binding is unavailable."))
		return FALSE
	return core.connect_shell(target, brain)
