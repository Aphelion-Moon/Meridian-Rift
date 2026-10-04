/// Resolve authority from the current body, never from a cyborg's ordinary connected_ai link.
/mob/living/proc/ai_controller()
	if(isAI(src))
		var/mob/living/silicon/ai/core = src
		return !core.shell_session && mind?.current == src ? core : null
	return ai_shell_session?.matches() ? ai_shell_session.core : null

/// Menu and preference keybindings share native operations, permissions and captured-session checks.
/mob/living/silicon/ai/proc/run_ai_command(command, camera_slot = 0)
	var/datum/ai_shell_session/session = shell_session
	var/command_generation = shell_session_generation
	if(session && !session.matches())
		return FALSE
	var/mob/living/player = uplink_player()
	if(command == "Return to core" || command == "AI View")
		return session ? session.finish(command, ai_view = command == "AI View") : TRUE
	if(command == "Show laws")
		show_laws(player)
		return TRUE
	if(command == "Core and cyborg status")
		to_chat(player, span_notice("Core integrity [health]/[maxHealth]; backup [battery]/200. Connected cyborgs: [length(connected_robots)]."))
		for(var/mob/living/silicon/robot/robot as anything in connected_robots)
			to_chat(player, span_notice("[robot]: integrity [robot.health]/[robot.maxHealth], [robot.stat == DEAD ? "offline" : "online"]."))
		return TRUE
	if(command == "Manage Uplink")
		uplink_registry?.ui_interact(player)
		return TRUE
	if(command == "Resume Uplink" || command == "Reconnect cyborg" || command == "Deploy shell")
		if(session && ((command == "Resume Uplink" && session.brain) || (command == "Reconnect cyborg" && !session.brain)))
			return TRUE
		if(session && !session.finish("Switching shells"))
			return FALSE
		if(command == "Resume Uplink")
			return uplink_resume_action?.Trigger(src)
		select_shell(command == "Reconnect cyborg" ? redeploy_action.last_used_shell : null)
		return TRUE
	if(command == "Laws" && shell_service_denial())
		show_laws(player)
		return TRUE
	// Floor bolts intentionally remain usable on backup power, as in their native verb.
	if(command != "AI services" && command != /datum/verb_metadata/mob/living/silicon/ai/toggle_anchor && command != /datum/action/innate/core_return)
		var/denial = shell_service_denial()
		if(denial || (session && !session.services_available()))
			to_chat(player, span_warning(denial || "This endpoint cannot currently operate AI services. Safe return is still available."))
			return FALSE
	var/static/list/camera_commands = list("View core", "Camera list", "Track camera", "Multicamera", "Add camera", "Camera up", "Camera down", "Previous camera", "Recall camera", "Save camera", /datum/verb_metadata/mob/living/silicon/ai/ai_network_change, /datum/verb_metadata/mob/living/silicon/ai/toggle_acceleration, /datum/verb_metadata/mob/living/silicon/ai/ai_cryo, /datum/action/innate/ai/place_transformer)
	if(session && (command in camera_commands))
		if(!session.finish("AI View", ai_view = TRUE))
			return FALSE
		session = null
		player = src
	if(ispath(command, /datum/verb_metadata))
		var/datum/verb_metadata/verb = SSverbs.verbs_by_type[command]
		if(!verb || !(verb.verb_path in verbs))
			return FALSE
		SSverbs.invoke(src, command, src, alist())
		return TRUE
	if(ispath(command, /datum/action))
		var/datum/action/ability = locate(command) in actions
		return trigger_ai_ability(ability)
	switch(command)
		if("AI services")
			var/list/choices = list("Laws", "Show laws", "Core and cyborg status", "Transceiver", "Station alerts", "Crew manifest", "Crew monitor", "Vox announcement", "Call emergency shuttle", "Integrated computer", "Robot control", "Core display", "Status displays", "Hologram appearance", "Sensor overlays", "Camera light", "Take photograph", "Photo album", "Special abilities", "Local network mode", "Manage Uplink", "AI View")
			var/choice = tgui_input_list(src, "AI state and service authority remain with your core. Physical interaction is the default.", "AI Services", choices)
			if(!choice || command_generation != shell_session_generation || (session ? !session.matches() : shell_session || mind?.current != src))
				return FALSE
			return run_ai_command(choice)
		if("Laws")
			law_ui.ui_interact(src)
		if("Transceiver")
			radio.interact(src)
		if("Station alerts")
			alert_control.ui_interact(src)
		if("Crew manifest")
			GLOB.manifest.ui_interact(src)
		if("Crew monitor")
			GLOB.crewmonitor.show(src, src)
		if("Vox announcement")
			world.push_usr(src, CALLBACK(src, PROC_REF(announcement)))
		if("Call emergency shuttle")
			world.push_usr(src, CALLBACK(src, PROC_REF(ai_call_shuttle)))
		if("Integrated computer")
			modularInterface.interact(src)
		if("Robot control")
			return run_ai_command(/datum/verb_metadata/mob/living/silicon/ai/botcall)
		if("Core display")
			return run_ai_command(/datum/verb_metadata/mob/living/silicon/ai/pick_icon)
		if("Status displays")
			return run_ai_command(/datum/verb_metadata/mob/living/silicon/ai/pick_status_display)
		if("Hologram appearance")
			return run_ai_command(/datum/verb_metadata/mob/living/silicon/ai/ai_hologram_change)
		if("Special abilities")
			var/list/abilities = list()
			for(var/datum/action/innate/ai/ability in actions)
				abilities[ability.name] = ability
			if(modules_action)
				abilities[modules_action.name] = modules_action
			var/selected = tgui_input_list(src, "Existing abilities only; original costs, uses and cooldowns apply.", "AI abilities", abilities)
			if(command_generation != shell_session_generation || (session ? !session.matches() : shell_session || mind?.current != src))
				return FALSE
			return trigger_ai_ability(abilities[selected])
		if("Malfunction modules")
			return trigger_ai_ability(modules_action)
		if("Camera light")
			if(iscyborg(player))
				var/mob/living/silicon/robot/robot = player
				robot.toggle_headlamp()
			else if(session)
				var/mob/living/carbon/human/uplink/body = player
				if(!istype(body) || !body.uplink_camera?.can_use())
					return FALSE
				body.uplink_light_on = !body.uplink_light_on
				body.uplink_camera.set_light(body.uplink_light_on ? AI_CAMERA_LUMINOSITY : 0)
			else
				toggle_camera_light()
		if("Sensor overlays")
			if(issilicon(player))
				var/mob/living/silicon/silicon = player
				silicon.toggle_sensors()
			else
				for(var/trait in list(TRAIT_MEDICAL_HUD_SENSOR_ONLY, TRAIT_SECURITY_HUD_ID_ONLY, TRAIT_DIAGNOSTIC_HUD))
					if(HAS_TRAIT_FROM(player, trait, REF(session)))
						REMOVE_TRAIT(player, trait, REF(session))
					else
						ADD_TRAIT(player, trait, REF(session))
		if("Take photograph")
			if(iscyborg(player))
				var/mob/living/silicon/robot/robot = player
				robot.aicamera.toggle_camera_mode(robot)
			else if(session)
				session.photo_mode = !session.photo_mode
				session.network_mode = session.photo_mode
				to_chat(player, span_notice(session.photo_mode ? "Click a visible local target to take a photo. Physical mode resumes afterward." : "Photography canceled."))
			else
				aicamera.toggle_camera_mode(src)
		if("Photo album")
			aicamera.viewpictures(player)
		if("Local network mode")
			if(!session)
				return FALSE
			session.photo_mode = FALSE
			session.network_mode = !session.network_mode
			to_chat(player, span_boldnotice("Local network interaction [session.network_mode ? "ON: clicks use the AI link" : "OFF: clicks use your body"]."))
		if("View core")
			view_core()
		if("Camera list")
			show_camera_list()
		if("Track camera")
			ai_tracking_tool.track_input(src)
		if("Multicamera")
			toggle_multicam()
		if("Add camera")
			drop_new_multicam()
		if("Camera up")
			world.push_usr(src, CALLBACK(src, TYPE_PROC_REF(/mob, up)))
		if("Camera down")
			world.push_usr(src, CALLBACK(src, TYPE_PROC_REF(/mob, down)))
		if("Previous camera", "Recall camera", "Save camera")
			if(command != "Previous camera" && (camera_slot < 1 || camera_slot > 9))
				return FALSE
			if(command == "Save camera")
				cam_hotkeys[camera_slot] = get_turf(eyeobj)
				to_chat(src, span_notice("Location saved to Camera Group [camera_slot]."))
				return TRUE
			var/turf/destination = command == "Previous camera" ? cam_prev : cam_hotkeys[camera_slot]
			if(!destination || !is_valid_z_level(get_turf(src), destination))
				return FALSE
			cam_prev = get_turf(eyeobj)
			ai_tracking_tool.reset_tracking()
			eyeobj.setLoc(destination)
		else
			return FALSE
	return TRUE

/// Only already-owned actions can run; their native availability, cooldown and targeting remain authoritative.
/mob/living/silicon/ai/proc/trigger_ai_ability(datum/action/ability)
	if(QDELETED(ability) || ability.owner != src || !(ability in actions) || (!istype(ability, /datum/action/innate/core_return) && shell_service_denial()))
		return FALSE
	var/datum/ai_shell_session/session = shell_session
	if(session && !session.services_available())
		return FALSE
	if(session && istype(ability, /datum/action/innate/ai/place_transformer))
		if(!session.finish("AI View", ai_view = TRUE))
			return FALSE
		session = null
	world.push_usr(src, CALLBACK(ability, TYPE_PROC_REF(/datum/action, Trigger), src))
	if(session?.matches() && click_intercept)
		session.network_mode = TRUE
		to_chat(session.endpoint, span_notice("Ability targeting active: select a visible target within local network range."))
	return TRUE
