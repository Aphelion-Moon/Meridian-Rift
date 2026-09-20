/datum/preference/choiced/display_grade_mode
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "display_grade_mode"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/choiced/display_grade_mode/init_possible_values()
	return list("Off", "Reference", "Custom")

/datum/preference/choiced/display_grade_mode/create_default_value()
	return "Off"

/datum/preference/choiced/display_grade_mode/deserialize(input, datum/preferences/preferences)
	return istext(input) && (input in get_choices()) ? input : null

/datum/preference/choiced/display_grade_mode/apply_to_client(client/client, value)
	if(istype(client))
		client.display_grade_refresh()

/datum/preference/choiced/display_grade_mode/apply_to_client_updated(client/client, value)
	if(!istype(client))
		return
	// A saved mode change ends an outstanding preview instead of hiding it in the cache.
	client?.display_grade_editor?.finish()
	client?.display_grade_refresh()

/datum/preference/display_grade_custom
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "display_grade_custom"
	savefile_identifier = PREFERENCE_PLAYER

/datum/preference/display_grade_custom/create_default_value()
	return display_grade_reference()

/datum/preference/display_grade_custom/deserialize(input, datum/preferences/preferences)
	return display_grade_validate(input)

/datum/preference/display_grade_custom/serialize(input)
	return display_grade_validate(input)

/datum/preference/display_grade_custom/is_valid(value, datum/preferences/preferences)
	return !!display_grade_validate(value)

/datum/preference/display_grade_custom/is_accessible(datum/preferences/preferences)
	// The structured profile is only written by the full-draft Apply transaction.
	return FALSE

/datum/preferences/proc/apply_display_grade(list/draft)
	var/list/validated = display_grade_validate(draft)
	if(!validated)
		return FALSE
	value_cache[/datum/preference/display_grade_custom] = validated
	value_cache[/datum/preference/choiced/display_grade_mode] = "Custom"
	recently_updated_keys |= list(/datum/preference/display_grade_custom, /datum/preference/choiced/display_grade_mode)
	return save_preferences()

/datum/preference_middleware/display_grade
	action_delegations = list("configure_display_grade" = PROC_REF(configure))

/datum/preference_middleware/display_grade/pre_set_preference(mob/user, preference, value)
	// The generic preferences transport does not check is_accessible before writes.
	return preference == "display_grade_custom"

/datum/preference_middleware/display_grade/proc/configure(list/params, mob/user)
	if(user.client != preferences.parent)
		return FALSE
	if(!user.client.display_grade_editor)
		user.client.display_grade_editor = new(user.client)
		user.client.display_grade_refresh()
	user.client.display_grade_editor.ui_interact(user)
	return TRUE

/client
	var/list/display_grade_settings
	var/display_grade_revision = 0
	var/datum/display_grade_editor/display_grade_editor

/client/proc/display_grade_saved_settings()
	if(!prefs)
		return null
	switch(prefs.read_preference(/datum/preference/choiced/display_grade_mode))
		if("Reference")
			return display_grade_reference()
		if("Custom")
			return display_grade_validate(prefs.read_preference(/datum/preference/display_grade_custom))
	return null

/client/proc/display_grade_refresh()
	var/list/effective = display_grade_editor && !display_grade_editor.finished ? display_grade_editor.effective_settings() : display_grade_saved_settings()
	effective = effective && effective["strength"] > 0 ? effective : null
#ifdef DISPLAY_GRADE_PROOF
	if(display_grade_proof && effective)
		QDEL_NULL(display_grade_proof)
#endif
	if(json_encode(effective) == json_encode(display_grade_settings))
		return
	display_grade_settings = effective?.Copy()
	display_grade_refresh_native()
	display_grade_update_browsers()
