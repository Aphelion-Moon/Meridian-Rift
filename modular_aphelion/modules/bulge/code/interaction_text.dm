/// Optional text is immutable input per interaction; no per-mob or global lookup cache.
/datum/interaction
	var/list/message_pit_hair
	var/list/user_messages_pit_hair
	var/list/target_messages_pit_hair

/datum/interaction/proc/load_pit_hair_text(list/json)
	message_pit_hair = sanitize_islist(json["message_pit_hair"], null)
	user_messages_pit_hair = sanitize_islist(json["user_messages_pit_hair"], null)
	target_messages_pit_hair = sanitize_islist(json["target_messages_pit_hair"], null)

/datum/interaction/proc/save_pit_hair_text(list/json)
	if(message_pit_hair)
		json["message_pit_hair"] = message_pit_hair
	if(user_messages_pit_hair)
		json["user_messages_pit_hair"] = user_messages_pit_hair
	if(target_messages_pit_hair)
		json["target_messages_pit_hair"] = target_messages_pit_hair
