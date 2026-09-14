/mob/living/silicon/robot
	var/cyborg_customization_message

/mob/living/silicon/robot/proc/cyborg_runtime_data()
	var/datum/preferences/owner_preferences = cyborg_preferences_for(src)
	cyborg_customization_sync_permissions(owner_preferences)
	if(!cyborg_appearance_store)
		return null
	var/list/parts = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/choice = cyborg_appearance_choices?[slot]
		if(!choice || choice == SPRITE_ACCESSORY_NONE)
			continue
		parts += list(list("slot" = slot, "choice" = choice, "active" = !!cyborg_appearance_active[slot], "arousal" = cyborg_appearance_arousal[slot] || "none", "can_arouse" = (slot in list("penis", "testicles", "vagina", "breasts"))))
	var/list/descriptor = cyborg_model_catalog()[cyborg_appearance_model]
	return list(
		"parts" = parts, "message" = cyborg_customization_message,
		"character_slot" = cyborg_appearance_slot, "allowed" = cyborg_appearance_allowed,
		"viewer_enabled" = !!owner_preferences?.read_preference(/datum/preference/toggle/see_cyborg_genitalia),
		"body_visible" = cyborg_body_visuals_visible(src),
		"model_name" = descriptor ? "[descriptor["department"]] / [descriptor["skin"]]" : "Choose a chassis model",
		"model_default" = !!cyborg_appearance_store["model_defaults"][cyborg_appearance_model],
	)

/// Runtime controls change body usage state only; saved configuration belongs to setup.
/mob/living/silicon/robot/proc/cyborg_runtime_action(list/params, mob/actor)
	var/datum/preferences/preferences = cyborg_preferences_for(src)
	if(actor != src || !preferences || shell || incapacitated || !cyborg_appearance_store)
		return FALSE
	if(!cyborg_runtime_actor_is_owner(src, actor, params["character_slot"]))
		cyborg_customization_message = "Return to this body's character slot to use these controls."
		return TRUE
	var/operation = params["operation"]
	if(!(operation in list("activate", "arousal", "viewer")))
		return FALSE
	if(operation == "viewer")
		var/datum/preference/preference = GLOB.preference_entries[/datum/preference/toggle/see_cyborg_genitalia]
		preferences.write_preference(preference, params["value"] == TRUE)
		preferences.save_preferences()
		for(var/obj/effect/client_image_holder/cyborg_customization/holder as anything in GLOB.cyborg_customization_holders)
			holder.refresh_viewer(src)
		return TRUE
	cyborg_customization_sync_permissions(preferences)
	if(!cyborg_appearance_allowed)
		cyborg_customization_message = "Genital content is disabled in character or server preferences."
		return TRUE
	var/slot = params["slot"]
	if(!(slot in cyborg_layout_supported_slots()) || !cyborg_appearance_choices?[slot] || cyborg_appearance_choices[slot] == SPRITE_ACCESSORY_NONE)
		return FALSE
	if(operation == "activate")
		cyborg_appearance_active[slot] = params["value"] == TRUE
	else if((slot in list("penis", "testicles", "vagina", "breasts")) && (params["value"] in list("none", "partial", "full")))
		cyborg_appearance_arousal[slot] = params["value"]
	else
		return FALSE
	cyborg_customization_message = null
	cyborg_appearance_revision++
	cyborg_customization_update_render()
	return TRUE

/datum/computer_file/program/robotact/proc/cyborg_customization_owner(mob/actor)
	var/obj/item/modular_computer/pda/silicon/tablet = computer
	if(!istype(tablet) || !iscyborg(actor) || tablet.silicon_owner != actor)
		return null
	var/mob/living/silicon/robot/robot = actor
	if(robot.modularInterface != tablet)
		return null
	return robot
