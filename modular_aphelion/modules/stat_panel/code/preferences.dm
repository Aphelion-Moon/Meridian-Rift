/datum/preference/toggle/verb_search
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "verb_search"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE

/datum/preference/toggle/verb_search/apply_to_client_updated(client/client, value)
	client?.update_stat_panel_preferences()

/datum/preference/toggle/verb_favourites
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "verb_favourites"
	savefile_identifier = PREFERENCE_PLAYER
	default_value = TRUE

/datum/preference/toggle/verb_favourites/apply_to_client_updated(client/client, value)
	client?.update_stat_panel_preferences()

/// Resend preferences when the stat panel loads or its verbs are refreshed.
/client/init_verbs()
	. = ..()
	update_stat_panel_preferences()

/client/proc/update_stat_panel_preferences()
	stat_panel?.send_message("update_verb_preferences", list(
		"verb_search" = prefs.read_preference(/datum/preference/toggle/verb_search),
		"verb_favourites" = prefs.read_preference(/datum/preference/toggle/verb_favourites),
	))
