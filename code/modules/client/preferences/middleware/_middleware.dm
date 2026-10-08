/// Preference middleware is code that helps to decentralize complicated preference features.
/datum/preference_middleware
	/// The preferences datum
	var/datum/preferences/preferences

	/// The key that will be used for get_constant_data().
	/// If null, will use the typepath minus /datum/preference_middleware.
	var/key = null

	/// Map of ui_act actions -> proc paths to call.
	/// Signature is `(list/params, mob/user) -> TRUE/FALSE.
	/// Return output is the same as ui_act--TRUE if it should update, FALSE if it should not
	var/list/action_delegations = list()

/datum/preference_middleware/New(datum/preferences)
	src.preferences = preferences

	if (isnull(key))
		// + 2 coming from the off-by-one of copytext, and then another from the slash
		key = copytext("[type]", length("[parent_type]") + 2)

/datum/preference_middleware/Destroy()
	preferences = null
	return ..()

/// Append all of these into ui_data
/datum/preference_middleware/proc/get_ui_data(mob/user)
	return list()

/// Append all of these into ui_static_data
/datum/preference_middleware/proc/get_ui_static_data(mob/user)
	return list()

/// Append all of these into ui_assets
/datum/preference_middleware/proc/get_ui_assets()
	return list()

/// Append all of these into /datum/asset/json/preferences.
/datum/preference_middleware/proc/get_constant_data()
	return null

/// Merge this into the result of compile_character_preferences.
/datum/preference_middleware/proc/get_character_preferences(mob/user)
	return null

/// Called before every update_preference, returns TRUE if this handled it.
/datum/preference_middleware/proc/pre_set_preference(mob/user, preference, value)
	return FALSE

/// Called when a character is changed.
/datum/preference_middleware/proc/on_new_character(mob/user)
	return

/// Called when the preferences UI closes, before the current character is saved.
/datum/preference_middleware/proc/on_ui_close()
	return

/// Called before the active character slot is serialized.
/datum/preference_middleware/proc/before_character_save()
	return TRUE

/// Called before a character slot replaces the currently loaded values.
/datum/preference_middleware/proc/before_character_load(slot, replacing_current_slot)
	return

/// Called while the owning preferences datum is being destroyed.
/datum/preference_middleware/proc/on_preferences_destroy()
	return

/// Called after every update_preference
/datum/preference_middleware/proc/post_set_preference(mob/user, preference, value)
	return
// NOVA EDIT ADDITION START
/// Called when applying preferences to the mob.
/datum/preference_middleware/proc/apply_to_human(mob/living/carbon/human/target, datum/preferences/preferences, visuals_only = FALSE) //NOVA EDIT CHANGE
	SHOULD_NOT_SLEEP(TRUE)
	SHOULD_CALL_PARENT(FALSE)
	return
// NOVA EDIT ADDITION END

// APHELION EDIT ADDITION START - CYBORG_CUSTOMIZATION - native save and replacement boundaries
/// Called with the checked native save outcome; staging alone must never acknowledge saving.
/datum/preference_middleware/proc/after_preferences_save(result)
	return

/// Preflight before a user-requested slot switch; FALSE aborts without loading a slot.
/datum/preference_middleware/proc/can_change_character()
	return TRUE

/// Authorized delete/import invalidates any draft and delayed actions for replaced data.
/datum/preference_middleware/proc/on_character_replaced()
	return
// APHELION EDIT ADDITION END
