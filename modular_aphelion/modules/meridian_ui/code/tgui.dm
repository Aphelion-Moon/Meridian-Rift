/// Refresh presentation without asking the source object to produce UI data.
/datum/tgui/proc/send_config_update()
	if(!user.client || closing || !window)
		return FALSE
	window.send_message("update", list("config" = get_config()))
	return TRUE

/datum/tgui/get_config()
	. = ..()
	.["meridianTheme"] = user.client.prefs.read_preference(/datum/preference/choiced/meridian_theme)

/datum/tgui/on_message(type, list/payload, list/href_list)
	if(type == "setMeridianTheme")
		if(!user.client?.set_meridian_theme(payload?["theme"]))
			send_config_update()
		return TRUE
	return ..()
