#define SUBTLE_DEFAULT_DISTANCE world.view
#define SUBTLE_ONE_TILE 1
#define SUBTLE_SAME_TILE_DISTANCE 0

#define SUBTLE_ONE_TILE_TEXT "1-Tile Range"
#define SUBTLE_SAME_TILE_TEXT "Same Tile"

#define PORTAL_ONE_TILE_TEXT "Portal 1-Tile Range"
#define PORTAL_SAME_TILE_TEXT "Portal Tile"

/datum/emote/living/subtle
	key = "subtle"
	key_third_person = "subtle"
	message = null
	mob_type_blacklist_typecache = list(/mob/living/brain)

/datum/config_entry/flag/play_subtler_sound
	default = TRUE

/datum/preference/toggle/subtler_sound
	savefile_key = "subtler_sound"
	savefile_identifier = PREFERENCE_PLAYER
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	default_value = TRUE

/datum/emote/living/subtle/run_emote(mob/user, params, type_override, intentional)
	if(!can_run_emote(user))
		to_chat(user, span_warning("You can't emote at this time."))
		return FALSE
	var/datum/weakref/user_ref
	var/subtle_message
	var/subtle_emote = params
	if(SSdbcore.IsConnected() && is_banned_from(user, "emote"))
		to_chat(user, "You cannot send subtle emotes (banned).")
		return FALSE
	else if(user.client?.prefs.muted & MUTE_IC)
		to_chat(user, "You cannot send IC messages (muted).")
		return FALSE
	else if(!params)
		user_ref = WEAKREF(user)
		subtle_emote = tgui_input_text(user, "Choose an emote to display.", "Subtle", null, max_length = MAX_MESSAGE_LEN, multiline = TRUE)
		user = user_ref.resolve()
		if(QDELETED(user) || !subtle_emote)
			return FALSE
		subtle_message = subtle_emote
	else
		subtle_message = params

	var/running_emote_type = type_override || emote_type

	if(!can_run_emote(user))
		to_chat(user, span_warning("You can't emote at this time."))
		return FALSE

	user.log_message(subtle_message, LOG_SUBTLE)

	var/space = should_have_space_before_emote(html_decode(subtle_emote)[1]) ? " " : ""

	subtle_message = span_subtle("<b>[user]</b>[space]<i>[user.apply_message_emphasis(subtle_message)]</i>")

	var/list/viewers = get_hearers_in_view(SUBTLE_ONE_TILE, user)

	var/obj/effect/overlay/holo_pad_hologram/hologram = GLOB.hologram_impersonators[user]
	if(hologram)
		viewers |= get_hearers_in_view(SUBTLE_ONE_TILE, hologram)
	for(var/obj/item/dullahan_relay/dullahan in viewers)
		viewers -= dullahan
		viewers += dullahan.owner

	for(var/obj/effect/overlay/holo_pad_hologram/iterating_hologram in viewers)
		if(iterating_hologram?.Impersonation?.client)
			viewers |= iterating_hologram.Impersonation

	for(var/mob/ghost as anything in GLOB.dead_mob_list)
		if((ghost.client?.prefs.chat_toggles & CHAT_GHOSTSIGHT) && !(ghost in viewers))
			to_chat(ghost, "[FOLLOW_LINK(ghost, user)] [subtle_message]")

	for(var/mob/receiver in viewers)
		if((running_emote_type & EMOTE_LEWD) && !pref_check_emote(receiver, preference = /datum/emote/living/lewd::pref_to_check))
			continue
		receiver.show_message(subtle_message, alt_msg = subtle_message)
		// Optional sound notification
		if(!isobserver(receiver))
			var/datum/preferences/prefs = receiver.client?.prefs
			if(prefs && prefs.read_preference(/datum/preference/toggle/subtler_sound))
				receiver.playsound_local(get_turf(receiver), 'sound/effects/achievement/beeps_jingle.ogg', 50)

	return TRUE

/*
*	SUBTLE 2: NO GHOST BOOGALOO
*/

/// Checks the moderation gates for Subtler emotes.
/mob/proc/can_send_subtler_emote()
	if(SSdbcore.IsConnected() && is_banned_from(src, "emote"))
		to_chat(src, span_warning("You cannot send subtle emotes (banned)."))
		return FALSE
	if(client?.prefs.muted & MUTE_IC)
		to_chat(src, span_warning("You cannot send IC messages (muted)."))
		return FALSE
	return TRUE

/datum/emote/living/subtler
	key = "subtler"
	key_third_person = "subtler"
	message = null
	mob_type_blacklist_typecache = list(/mob/living/brain)

/datum/emote/living/subtler/run_emote(mob/user, params, type_override, intentional)
	if(!can_run_emote(user))
		to_chat(user, span_warning("You can't emote at this time."))
		return FALSE
	var/datum/weakref/user_ref
	var/subtler_message
	var/subtler_emote = params
	var/target
	var/subtler_range = SUBTLE_DEFAULT_DISTANCE
	var/datum/weakref/offered_portal_output_ref

	if(!user.can_send_subtler_emote())
		return FALSE
	if(!subtler_emote)
		user_ref = WEAKREF(user)
		subtler_emote = tgui_input_text(user, "Choose an emote to display.", "Subtler" , max_length = MAX_MESSAGE_LEN, multiline = TRUE)
		user = user_ref.resolve()
		if(QDELETED(user) || !subtler_emote)
			return FALSE

		var/list/target_refs = build_subtler_targets(user, subtler_range)
		var/list/targets = list(SUBTLE_ONE_TILE_TEXT, SUBTLE_SAME_TILE_TEXT)
		for(var/target_name in target_refs)
			targets += target_name
		var/obj/effect/lewd_portal_relay/offered_portal_output = user.get_portal_output()
		if(offered_portal_output)
			offered_portal_output_ref = WEAKREF(offered_portal_output)
			targets.Insert(1, PORTAL_ONE_TILE_TEXT, PORTAL_SAME_TILE_TEXT)
		offered_portal_output = null

		var/selected_target = tgui_input_list(user, "Pick a target", "Target Selection", targets)
		user = user_ref.resolve()
		if(QDELETED(user) || !selected_target)
			return FALSE

		switch(selected_target)
			if(SUBTLE_ONE_TILE_TEXT)
				target = SUBTLE_ONE_TILE
			if(SUBTLE_SAME_TILE_TEXT)
				target = SUBTLE_SAME_TILE_DISTANCE
			if(PORTAL_ONE_TILE_TEXT, PORTAL_SAME_TILE_TEXT)
				target = selected_target
			else
				var/datum/weakref/target_ref = target_refs[selected_target]
				var/atom/movable/resolved_target = target_ref?.resolve()
				if(QDELETED(resolved_target))
					return FALSE
				target = resolved_target
		subtler_message = subtler_emote
	else
		target = SUBTLE_ONE_TILE
		subtler_message = subtler_emote

	var/running_emote_type = type_override || emote_type

	if(!can_run_emote(user))
		to_chat(user, span_warning("You can't emote at this time."))
		return FALSE
	if(!user.can_send_subtler_emote())
		return FALSE

	user.log_message(subtler_message, LOG_SUBTLER)

	var/space = should_have_space_before_emote(html_decode(subtler_emote)[1]) ? " " : ""

	subtler_message = span_subtler("<b>[user]</b>[space]<i>[user.apply_message_emphasis(subtler_message)]</i>")

	if(istype(target, /mob))
		var/mob/target_mob = target
		if(QDELETED(target_mob) || (target_mob in GLOB.dead_mob_list))
			return FALSE
		user.show_message(subtler_message, alt_msg = subtler_message)
		if((running_emote_type & EMOTE_LEWD) && !pref_check_emote(target_mob, preference = /datum/emote/living/lewd::pref_to_check))
			return FALSE
		if(!is_target_in_range(user, target_mob, subtler_range))
			to_chat(user, span_warning("Your emote was unable to be sent to your target: Too far away."))
			return FALSE
		target_mob.show_message(subtler_message, alt_msg = subtler_message)
		subtler_sound(target_mob, running_emote_type)
	else if(istype(target, /obj/effect/overlay/holo_pad_hologram))
		var/obj/effect/overlay/holo_pad_hologram/hologram = target
		if(QDELETED(hologram) \
			|| QDELETED(hologram.Impersonation) \
			|| !hologram.Impersonation?.client \
			|| (hologram.Impersonation in GLOB.dead_mob_list))
			return FALSE
		if(!is_target_in_range(user, hologram, subtler_range))
			to_chat(user, span_warning("Your emote was unable to be sent to your target: Too far away."))
			return FALSE
		if((running_emote_type & EMOTE_LEWD) && !pref_check_emote(client = hologram.Impersonation.client, preference = /datum/emote/living/lewd::pref_to_check))
			return FALSE
		hologram.Impersonation.show_message(subtler_message, alt_msg = subtler_message)
		subtler_sound(hologram.Impersonation, running_emote_type)
	else if(istype(target, /obj/effect/lewd_portal_relay))
		var/obj/effect/lewd_portal_relay/portal_relay = target
		if(QDELETED(portal_relay) || !portal_relay.can_reveal_to(user))
			return FALSE
		if(!is_target_in_range(user, portal_relay, subtler_range))
			to_chat(user, span_warning("Your emote was unable to be sent to your target: Too far away."))
			return FALSE
		if(!send_portal_subtler(user, portal_relay, subtler_emote, running_emote_type, space, sender_message = subtler_message))
			return FALSE
	else
		var/list/recipients
		var/obj/effect/lewd_portal_relay/output_portal
		if(target == PORTAL_SAME_TILE_TEXT || target == PORTAL_ONE_TILE_TEXT)
			switch(target)
				if(PORTAL_ONE_TILE_TEXT)
					target = SUBTLE_ONE_TILE
				if(PORTAL_SAME_TILE_TEXT)
					target = SUBTLE_SAME_TILE_DISTANCE
			output_portal = user.resolve_portal_output(offered_portal_output_ref)
			if(!output_portal)
				return FALSE
			recipients = get_hearers_in_view(target, output_portal)
			user.show_message(subtler_message, alt_msg = subtler_message)
			subtler_message = span_subtler("<b>[output_portal]</b>[space]<i>[user.apply_message_emphasis(subtler_emote)]</i>")
		else
			recipients = get_hearers_in_view(target, user)
			var/obj/effect/overlay/holo_pad_hologram/sender_hologram = GLOB.hologram_impersonators[user]
			if(!QDELETED(sender_hologram) && sender_hologram.Impersonation == user)
				recipients |= get_hearers_in_view(target, sender_hologram)

		for(var/obj/effect/overlay/holo_pad_hologram/holo in recipients)
			if(holo?.Impersonation?.client)
				recipients |= holo.Impersonation
		for(var/obj/item/dullahan_relay/dullahan in recipients)
			recipients -= dullahan
			recipients += dullahan.owner
		recipients -= GLOB.dead_mob_list

		for(var/mob/receiver in recipients)
			if(QDELETED(receiver))
				continue
			if(output_portal && !output_portal.can_reveal_to(receiver))
				continue
			if(!output_portal && (running_emote_type & EMOTE_LEWD) && !pref_check_emote(receiver, preference = /datum/emote/living/lewd::pref_to_check))
				continue
			receiver.show_message(subtler_message, alt_msg = subtler_message)
			subtler_sound(receiver, output_portal ? (running_emote_type | EMOTE_LEWD) : running_emote_type)

		for(var/obj/effect/lewd_portal_relay/portal_relay in recipients)
			if(QDELETED(portal_relay) || !portal_relay.can_reveal_to(user))
				continue
			send_portal_subtler(user, portal_relay, subtler_emote, running_emote_type, space, log_action = "broadcast")

	return TRUE

/**
 * Builds the Subtler target menu for `user`, as display name -> weak reference.
 *
 * Kept in its own proc so everything it walks is released the moment it returns, rather than sitting in a local
 * and holding candidates alive across the prompt that consumes the result.
 */
/datum/emote/living/subtler/proc/build_subtler_targets(mob/user, subtler_range)
	var/list/in_view = get_hearers_in_view(subtler_range, user)

	var/obj/effect/overlay/holo_pad_hologram/sender_hologram = GLOB.hologram_impersonators[user]
	if(!QDELETED(sender_hologram) && sender_hologram.Impersonation == user)
		in_view |= get_hearers_in_view(subtler_range, sender_hologram)

	in_view.Remove(user)

	for(var/obj/item/dullahan_relay/dullahan in in_view)
		in_view -= dullahan
		if(user != dullahan.owner)
			in_view += dullahan.owner
	in_view -= GLOB.dead_mob_list

	for(var/mob/eye/camera/ai/ai_eye in in_view) // Remove clientless AI eyes.
		if(ai_eye.client)
			continue
		in_view.Remove(ai_eye)

	var/list/target_refs = list()
	for(var/atom/movable/candidate as anything in in_view)
		if(QDELETED(candidate))
			continue
		target_refs[unique_target_name(candidate, target_refs)] = WEAKREF(candidate)
	return target_refs

/// Menu entries are keyed by display name, so identically named candidates have to be told apart.
/datum/emote/living/subtler/proc/unique_target_name(atom/movable/candidate, list/taken_names)
	var/static/list/reserved_names = list(
		SUBTLE_ONE_TILE_TEXT,
		SUBTLE_SAME_TILE_TEXT,
		PORTAL_ONE_TILE_TEXT,
		PORTAL_SAME_TILE_TEXT,
	)
	var/target_name = "[candidate]"
	var/name_suffix = 1
	while((target_name in reserved_names) || (target_name in taken_names))
		name_suffix += 1
		target_name = "[candidate] ([name_suffix])"
	return target_name

/// Delivers one Subtler through a portal relay to whoever is on the far side, anonymously.
/datum/emote/living/subtler/proc/send_portal_subtler(
	mob/user,
	obj/effect/lewd_portal_relay/portal_relay,
	subtler_emote,
	running_emote_type,
	space,
	sender_message,
	log_action = "sent",
)
	if(QDELETED(portal_relay) || !portal_relay.can_reveal_to(user))
		return FALSE
	var/mob/living/carbon/human/portal_owner = portal_relay.owner
	if(QDELETED(portal_owner) || portal_owner == user || (portal_owner in GLOB.dead_mob_list))
		return FALSE
	if(sender_message)
		user.show_message(sender_message, alt_msg = sender_message)
	var/portal_message = span_subtler("<b>Unknown</b>[space]<i>[user.apply_message_emphasis(subtler_emote)]</i>")
	portal_owner.show_message(portal_message, alt_msg = portal_message)
	subtler_sound(portal_owner, running_emote_type | EMOTE_LEWD)
	user.log_message("[log_action] a portal subtler to [key_name(portal_owner)]: [subtler_emote]", LOG_GAME)
	return TRUE

/// Returns whether a target is in range of the sender or their live hologram.
/datum/emote/living/subtler/proc/is_target_in_range(mob/user, atom/target, maximum_range)
	if(QDELETED(user) || QDELETED(target))
		return FALSE
	if(IN_GIVEN_RANGE(user, target, maximum_range))
		return TRUE
	var/obj/effect/overlay/holo_pad_hologram/sender_hologram = GLOB.hologram_impersonators[user]
	return !QDELETED(sender_hologram) \
		&& sender_hologram.Impersonation == user \
		&& IN_GIVEN_RANGE(sender_hologram, target, maximum_range)

/// Plays the optional Subtler notification sound when the recipient's preferences allow it.
/datum/emote/living/subtler/proc/subtler_sound(mob/hearer, running_emote_type = NONE)
	if(QDELETED(hearer))
		return
	var/datum/preferences/prefs = hearer.client?.prefs
	if(!prefs || !prefs.read_preference(/datum/preference/toggle/subtler_sound))
		return
	if((running_emote_type & EMOTE_LEWD) && !prefs.read_preference(/datum/preference/toggle/erp/sounds))
		return
	hearer.playsound_local(get_turf(hearer), 'sound/effects/achievement/glockenspiel_ping.ogg', 50)

/*
*	VERB CODE
*/

/mob/living/proc/subtle_keybind()
	var/message = input(src, "", "subtle") as text|null
	if(!length(message))
		return
	return subtle(message)

GAME_VERB(/mob/living, subtle, "Subtle", "IC")
	if(GLOB.say_disabled)	// This is here to try to identify lag problems
		to_chat(usr, span_danger("Speech is currently admin-disabled."))
		return
	usr.emote("subtle")

/*
*	VERB CODE 2
*/

GAME_VERB(/mob/living, subtler, "Subtler Anti-Ghost", "IC")
	if(GLOB.say_disabled)	// This is here to try to identify lag problems
		to_chat(usr, span_danger("Speech is currently admin-disabled."))
		return
	usr.emote("subtler")

#undef SUBTLE_DEFAULT_DISTANCE
#undef SUBTLE_ONE_TILE
#undef SUBTLE_SAME_TILE_DISTANCE

#undef SUBTLE_ONE_TILE_TEXT
#undef SUBTLE_SAME_TILE_TEXT

#undef PORTAL_ONE_TILE_TEXT
#undef PORTAL_SAME_TILE_TEXT
