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
	return matches() && brain && endpoint.client && !core.shell_service_denial()

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
	name = "Uplink AI Services"
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
	var/choice = tgui_input_list(owner, "AI state and service authority remain with your core. Physical interaction is the default.", "Uplink AI Services", list("Laws", "Core and cyborg status", "Transceiver", "Station alerts", "Crew manifest", "Crew monitor", "Vox announcement", "Call emergency shuttle", "Integrated computer", "Robot control", "Core display", "Status displays", "Hologram appearance", "Sensor overlays", "Camera light", "Take photograph", "Photo album", "Special abilities", "Local network mode", "AI View"))
	if(!session?.matches() || owner != session.endpoint)
		return FALSE
	var/mob/living/silicon/ai/core = session.core
	if(choice == "AI View")
		return session.finish("AI View", ai_view = TRUE)
	if(choice == "Core and cyborg status")
		to_chat(owner, span_notice("Core integrity [core.health]/[core.maxHealth]; backup [core.battery]/200. Connected cyborgs: [length(core.connected_robots)]."))
		for(var/mob/living/silicon/robot/robot as anything in core.connected_robots)
			to_chat(owner, span_notice("[robot]: integrity [robot.health]/[robot.maxHealth], [robot.stat == DEAD ? "offline" : "online"]."))
		return TRUE
	if(choice == "Laws")
		if(session.services_available())
			core.law_ui.ui_interact(core)
		else
			core.show_laws(owner)
		return TRUE
	if(!session.services_available())
		to_chat(owner, span_warning(core.shell_service_denial()))
		return FALSE
	switch(choice)
		if("Transceiver")
			core.radio.interact(core)
		if("Station alerts")
			core.alert_control.ui_interact(core)
		if("Crew manifest")
			GLOB.manifest.ui_interact(core)
		if("Crew monitor")
			GLOB.crewmonitor.show(core, core)
		if("Vox announcement")
			world.push_usr(core, CALLBACK(core, TYPE_PROC_REF(/mob/living/silicon/ai, announcement)))
		if("Call emergency shuttle")
			world.push_usr(core, CALLBACK(core, TYPE_PROC_REF(/mob/living/silicon/ai, ai_call_shuttle)))
		if("Integrated computer")
			core.modularInterface.interact(core)
		if("Hologram appearance")
			world.push_usr(core, CALLBACK(core, TYPE_PROC_REF(/mob/living/silicon/ai, ai_hologram_change)))
		if("Take photograph")
			session.photo_mode = TRUE
			session.network_mode = TRUE
			to_chat(owner, span_notice("Click a visible local target to take a photo with your AI camera. Physical mode resumes afterward."))
		if("Photo album")
			core.aicamera?.viewpictures(owner)
		if("Special abilities")
			var/list/abilities = list()
			for(var/datum/action/innate/ai/ability in core.actions)
				abilities[ability.name] = ability
			if(core.modules_action)
				abilities[core.modules_action.name] = core.modules_action
			var/selected = tgui_input_list(owner, "Existing core abilities only; original costs, uses and cooldowns apply.", "AI abilities", abilities)
			var/datum/action/ability = abilities[selected]
			if(!session?.services_available() || QDELETED(ability) || ability.owner != core || !(ability in core.actions))
				return FALSE
			world.push_usr(core, CALLBACK(ability, TYPE_PROC_REF(/datum/action, Trigger), core))
			if(session?.matches() && core.click_intercept)
				session.network_mode = TRUE
				to_chat(owner, span_notice("Ability targeting active: select a visible target within local network range."))
		if("Robot control")
			if(!core.robot_control)
				core.robot_control = new(core)
			core.robot_control.ui_interact(core)
		if("Core display")
			if(!core.core_display_picker)
				core.core_display_picker = new(core)
			core.core_display_picker.ui_interact(core)
		if("Status displays")
			if(!core.status_display_picker)
				core.status_display_picker = new(core)
			core.status_display_picker.ui_interact(core)
		if("Camera light")
			var/mob/living/carbon/human/uplink/body = owner
			if(!istype(body) || !body.registry?.is_current(body) || QDELETED(body.uplink_camera) || !body.uplink_camera.can_use())
				to_chat(owner, span_warning("This endpoint has no available personal camera light."))
				return FALSE
			body.uplink_light_on = !body.uplink_light_on
			body.uplink_camera.set_light(body.uplink_light_on ? AI_CAMERA_LUMINOSITY : 0)
		if("Sensor overlays")
			var/list/sensors = list(TRAIT_MEDICAL_HUD_SENSOR_ONLY, TRAIT_SECURITY_HUD_ID_ONLY, TRAIT_DIAGNOSTIC_HUD)
			for(var/trait in sensors)
				if(HAS_TRAIT_FROM(owner, trait, REF(session)))
					REMOVE_TRAIT(owner, trait, REF(session))
				else
					ADD_TRAIT(owner, trait, REF(session))
		if("Local network mode")
			session.network_mode = !session.network_mode
			to_chat(owner, span_boldnotice("Local network interaction [session.network_mode ? "ON: clicks use the AI link" : "OFF: clicks use your hands"]."))
	return TRUE
