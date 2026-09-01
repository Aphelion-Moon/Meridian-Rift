/datum/preference/choiced/pda_theme/deserialize(input, datum/preferences/preferences)
	// Translate saved display names before the parent validates the choices.
	switch(input)
		if(PDA_THEME_NTOS_LEGACY_NAME)
			input = PDA_THEME_MERIDIAN_NAME
		if(PDA_THEME_DARK_MODE_LEGACY_NAME)
			input = PDA_THEME_DARK_MODE_NAME
		if(PDA_THEME_LIGHT_MODE_LEGACY_NAME)
			input = PDA_THEME_LIGHT_MODE_NAME
	return ..(input, preferences)

/// Account-wide MeridianOS presentation selected from the in-window gear menu.
/datum/preference/choiced/meridian_theme
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "meridian_theme"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/choiced/meridian_theme/init_possible_values()
	return list(
		"meridian_aphelion",
		"meridian_classic",
		"meridian",
		"meridian_vector",
		"meridian_synapse",
		"meridian_highline",
		"meridian_afterlight",
		"meridian_diagnostic",
		"meridian_augmentation",
		"meridian_synapse_xxxo",
		"meridian_cyberpunk",
		"meridian_bastion",
		"meridian_pipboy",
		"meridian_relay",
		"meridian_foundry",
	)

/datum/preference/choiced/meridian_theme/create_default_value()
	return "meridian_aphelion"

/datum/preference/choiced/meridian_theme/apply_to_client_updated(client/client, value)
	if(isnull(client))
		return
	var/mob/client_mob = client.mob
	for(var/datum/tgui/open_ui as anything in client_mob?.tgui_open_uis)
		open_ui.send_config_update()
	client.lobby_menu?.send_update(list("meridianTheme" = value))

/**
 * Validate, persist, and distribute a MeridianOS theme selection.
 *
 * The explicit membership check must remain before update_preference(); the
 * generic choiced deserializer converts unknown input to its default, which
 * would otherwise let an invalid wire value silently change the selection.
 */
/datum/preferences/proc/set_meridian_theme(raw_theme)
	if(!istext(raw_theme))
		return FALSE

	var/datum/preference/choiced/meridian_theme/theme_preference = GLOB.preference_entries[/datum/preference/choiced/meridian_theme]
	if(!(raw_theme in theme_preference.get_choices()))
		return FALSE

	if(read_preference(theme_preference.type) == raw_theme)
		return TRUE

	if(!update_preference(theme_preference, raw_theme))
		return FALSE

	return save_preferences()

/// Self-bound transport entrypoint; browser payloads can never choose an owner.
/client/proc/set_meridian_theme(raw_theme)
	return prefs?.set_meridian_theme(raw_theme)
