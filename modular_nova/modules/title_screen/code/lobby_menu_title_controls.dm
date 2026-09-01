/**
 * Server-wide title screen controls for the lobby menu.
 *
 * These live here rather than in code/modules/lobby_menu/lobby_menu.dm so the
 * feature stays modular: both procs are declared with proc/ upstream, so this
 * file overrides them and falls through with ..() for everything it does not
 * handle.
 */

/**
 * The lobby browser never received the Font Awesome asset that TGUI windows
 * send, so every <Icon> in the lobby rendered as an empty element: the theme
 * picker's tick marks and the title screen overlay checkboxes were invisible.
 * Sending it here keeps the fix out of core lobby_menu.dm.
 */
/datum/lobby_menu/initialize_browser()
	. = ..()
	window.send_asset(get_asset_datum(/datum/asset/simple/namespaced/fontawesome))
	SStitle.ensure_title_mark_asset()
	SSassets.transport.send_assets(client, LOBBY_TITLE_MARK_ASSET_NAME)

/// Whether this particular client may open the title manager.
/datum/lobby_menu/proc/get_title_control_payload()
	return list("canSetTitleScreen" = can_set_title_screen())

/**
 * Whether this client holds the rank that owns the title screen.
 *
 * The client-side flag only decides whether the menu renders. Every handler
 * below re-checks this, because a payload can be forged.
 */
/datum/lobby_menu/proc/can_set_title_screen()
	return !isnull(client?.holder) && check_rights_for(client, TITLE_SCREEN_ADMIN_RIGHTS)

/datum/lobby_menu/on_message(type, payload, href_list)
	if(type == "setMeridianTheme")
		if(!client?.set_meridian_theme(payload?["theme"]))
			send_update(list(
				"meridianTheme" = client?.prefs?.read_preference(/datum/preference/choiced/meridian_theme) || "meridian_aphelion",
			))
		return TRUE
	switch(type)
		if("openTitleManager")
			// The lobby only opens the window; every change is made and
			// confirmed inside it, against the same draft the admin verb uses.
			if(!can_set_title_screen())
				message_admins("[key_name(client)] tried to open the title screen manager without the required rights.")
				send_update(get_title_control_payload())
				return TRUE
			client.open_title_screen_manager()
			return TRUE

	return ..()

/// Title artwork and its presentation must arrive together in the initial message.
/datum/lobby_menu/proc/get_title_init_payload()
	var/list/payload = SStitle.get_published_title_payload()
	payload += get_title_control_payload()
	payload += SStitle.get_startup_status()
	payload += list(
		"notice" = SStitle.current_notice,
		"latejoinQueue" = SStitle.get_latejoin_queue_count(),
		"characterName" = uppertext(client?.prefs?.read_preference(/datum/preference/name/real_name)),
		"isAntag" = client?.prefs?.read_preference(/datum/preference/toggle/be_antag),
		"startupMessages" = GLOB.startup_messages,
		"progressCurrent" = world.timeofday - SStitle.progress_reference_time,
		"progressTotal" = SStitle.average_completion_time,
		"meridianTheme" = client?.prefs?.read_preference(/datum/preference/choiced/meridian_theme) || "meridian_aphelion",
	)
	return payload
