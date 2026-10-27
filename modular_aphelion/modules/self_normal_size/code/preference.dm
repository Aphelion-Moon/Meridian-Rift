/// Whether a player with a body resized up sees their own body at normal size. Everyone else always sees its true size.
/datum/preference/toggle/see_self_normal_size
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "see_self_normal_size"

/datum/preference/toggle/see_self_normal_size/apply_to_client(client/client, value)
	if (ishuman(client?.mob))
		var/mob/living/carbon/human/body = client.mob
		body.update_self_normal_size()
