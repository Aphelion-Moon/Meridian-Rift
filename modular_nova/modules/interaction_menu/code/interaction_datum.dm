
GLOBAL_LIST_EMPTY_TYPED(interaction_instances, /datum/interaction)

/datum/interaction
	/// The name to be displayed in the interaction menu for this interaction
	var/name = "broken interaction"
	/// The description of the interacton.
	var/description = "broken"
	/// If it can be done at a distance.
	var/distance_allowed = FALSE
	/// A list of possible messages displayed loaded by the JSON.
	var/list/message = list()
	/// A list of possible messages displayed directly to the USER.
	var/list/user_messages = list()
	/// A list of possible messages displayed directly to the TARGET.
	var/list/target_messages = list()
	/// What category this interaction will fall under in the menu.
	var/category = INTERACTION_CAT_HIDE
	/// Defines how we interact with ourselves or others.
	var/usage = INTERACTION_OTHER
	/// Does this interaction play a sound?
	var/sound_use = FALSE
	/// Does the interaction sound vary in pitch each time?
	var/sound_vary = TRUE
	/// If it plays a sound, how far does it travel?
	var/sound_range = 1
	/// Stores the sound for later.
	var/sound_cache = null
	/// Is this lewd?
	var/lewd = FALSE
	/// What parts do WE need(IMPORTANT TO GET IT TO THE CORRECT DEFINE, ORGAN SLOT)?
	var/list/user_required_parts = list()
	/// What parts do they need(IMPORTANT TO GET IT TO THE CORRECT DEFINE, ORGAN SLOT)?
	var/list/target_required_parts = list()
	/// The amount of pleasure the target receives from this interaciton.
	var/target_pleasure = 0
	/// The amount of arousal the target receives from this interaction.
	var/target_arousal = 0
	/// The amount of pain the target receives.
	var/target_pain = 0
	/// The amount of pleasure the user receives.
	var/user_pleasure = 0
	/// The amount of arousal the user receives.
	var/user_arousal = 0
	/// The amount of pain the user receives.
	var/user_pain = 0
	/// A list of possible sounds.
	var/list/sound_possible = list()
	/// What requirements does this interaction have? See defines.
	var/list/interaction_requires = list()
	/// What color should the interaction button be?
	var/color = "blue"
	/// What sexuality preference do we display for.
	var/sexuality = ""

/datum/interaction/proc/allow_act(
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	allow_same_participant = FALSE,
	check_part_exposure = TRUE,
)
	if(target == user && usage == INTERACTION_OTHER && !allow_same_participant)
		return FALSE

	if(target != user && usage == INTERACTION_SELF)
		return FALSE

	if(length(user_required_parts))
		for(var/thing in user_required_parts)
			var/obj/item/organ/genital/required_part = user.get_organ_slot(thing)
			if(isnull(required_part))
				return FALSE
			if(check_part_exposure && !required_part.is_exposed())
				return FALSE

	if(length(target_required_parts))
		for(var/thing in target_required_parts)
			var/obj/item/organ/genital/required_part = target.get_organ_slot(thing)
			if(isnull(required_part))
				return FALSE
			if(check_part_exposure && !required_part.is_exposed())
				return FALSE

	for(var/requirement in interaction_requires)
		switch(requirement)
			if(INTERACTION_REQUIRE_SELF_HAND)
				if(!user.get_active_hand())
					return FALSE
			if(INTERACTION_REQUIRE_TARGET_HAND)
				if(!target.get_active_hand())
					return FALSE

			else
				CRASH("Unimplemented interaction requirement '[requirement]'")
	return TRUE

/// Returns TRUE only while both participants can consciously take part in an interaction.
/datum/interaction/proc/participants_are_actionable(mob/living/carbon/human/user, mob/living/carbon/human/target)
	return ishuman(user) \
		&& ishuman(target) \
		&& !QDELETED(user) \
		&& !QDELETED(target) \
		&& !IS_UNCONSCIOUS_OR_CRIT(user) \
		&& !IS_UNCONSCIOUS_OR_CRIT(target) \
		&& !user.incapacitated \
		&& !target.incapacitated

/// Revalidates whichever route supplied this interaction. A null route is a plain face-to-face interaction.
/datum/interaction/proc/interaction_route_is_valid(
	datum/interaction_route/route,
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	ignore_cooldown = FALSE,
)
	if(isnull(route))
		return distance_allowed || user.Adjacent(target)
	return route.is_still_valid(src, user, target, ignore_cooldown)

/// Checks the preferences required at both execution boundaries.
/datum/interaction/proc/participants_accept_interaction(
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	datum/interaction_route/route,
)
	if(route && !route.participants_accept(user, target))
		return FALSE
	if(!lewd)
		return TRUE
	var/datum/client_interface/user_client = GET_CLIENT(user)
	var/datum/client_interface/target_client = GET_CLIENT(target)
	if(!user_client?.prefs?.read_preference(/datum/preference/toggle/erp) \
		|| !target_client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return FALSE
	return TRUE

/// Shared authority checks for the menu, immediate execution, and deferred effects.
/datum/interaction/proc/can_execute(
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	datum/interaction_route/route = null,
	ignore_cooldown = FALSE,
)
	if(!participants_are_actionable(user, target))
		return FALSE
	if(!interaction_route_is_valid(route, user, target, ignore_cooldown))
		return FALSE
	if(!participants_accept_interaction(user, target, route))
		return FALSE
	return allow_act(
		user,
		target,
		allow_same_participant = route?.allows_same_participant(),
		check_part_exposure = !route?.validates_part_access(),
	)

/datum/interaction/proc/act(
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	use_subtler = TRUE,
	datum/interaction_route/route = null,
)
	if(!can_execute(user, target, route))
		return FALSE
	var/user_anonymous = route?.user_is_anonymous()
	var/target_anonymous = isnull(route) ? !can_see(user, target) : route.target_is_anonymous()
	if(!message)
		message_admins("Interaction had a null message list. '[html_encode(name)]'")
		return FALSE
	if(!islist(message) && istext(message))
		message_admins("Deprecated message handling for '[html_encode(name)]'. Correct format is a list with one entry. This message will only show once.")
		message = list(message)
	var/message_template = pick(message)
	// %USER% is blanked here because the emote procs below already prepend the user's name.
	var/msg = format_message_for(
		message_template,
		user,
		target,
		route = route,
		omit_user = TRUE,
		target_anonymous = target_anonymous,
	)

	if(lewd)
		if(use_subtler)
			if(!user.can_send_subtler_emote())
				return FALSE
			if(!user.emote("subtler", type_override = /datum/emote/living/subtler::emote_type | EMOTE_LEWD, message = msg, intentional = TRUE))
				return FALSE
		else
			var/list/ignoring_mobs = list()
			for(var/mob/not_interested in get_hearers_in_view(DEFAULT_MESSAGE_RANGE, user))
				if(!not_interested.client?.prefs?.read_preference(/datum/preference/toggle/erp))
					ignoring_mobs += not_interested
			user.visible_message(span_purple("[user] [msg]"), ignored_mobs = ignoring_mobs)
			user.log_message(msg, LOG_EMOTE)
	else
		user.manual_emote(msg)

	// Player-facing anonymity never removes the real participants from administrative logs.
	if(user_anonymous || target_anonymous)
		var/admin_msg = format_message_for(message_template, user, target, omit_user = TRUE)
		user.log_message("[admin_msg] (interaction target: [key_name(target)]; user anonymous: [user_anonymous]; target anonymous: [target_anonymous])", LOG_GAME)

	if(user_messages.len)
		var/user_msg = format_message_for(
			pick(user_messages),
			user,
			target,
			route = route,
			target_anonymous = target_anonymous,
			recipient = user,
		)
		to_chat(user, user_msg)

	if(target_messages.len)
		var/target_msg = format_message_for(
			pick(target_messages),
			user,
			target,
			user_anonymous = user_anonymous,
			recipient = target,
		)
		to_chat(target, target_msg)

	if(sound_use)
		if(!sound_possible)
			message_admins("Interaction has sound_use set to TRUE but does not set sound! '[html_encode(name)]'")
			return
		if(!islist(sound_possible) && istext(sound_possible))
			message_admins("Deprecated sound handling for '[html_encode(name)]'. Correct format is a list with one entry. This message will only show once.")
			sound_possible = list(sound_possible)
		sound_cache = pick(sound_possible)
		if (lewd)
			playsound_if_pref(target.loc, sound_cache, 50, sound_vary, max(0, -SOUND_RANGE + sound_range), pref_to_check = /datum/preference/toggle/erp/sounds)
		else
			playsound(target.loc, sound_cache, 50, sound_vary, max(0, -SOUND_RANGE + sound_range))

	INVOKE_ASYNC(src, PROC_REF(apply_effects), WEAKREF(user), WEAKREF(target), route)
	return TRUE

/// Expands a message for an observer by default, or for the recipient of a private notice.
/// Anonymity takes precedence over recipient identity, including when both roles belong to one mob.
/datum/interaction/proc/format_message_for(
	message_template,
	mob/living/carbon/human/user,
	mob/living/carbon/human/target,
	datum/interaction_route/route = null,
	omit_user = FALSE,
	user_anonymous = FALSE,
	target_anonymous = FALSE,
	mob/living/carbon/human/recipient = null,
)
	var/known_self_interaction = recipient == user && user == target && !user_anonymous && !target_anonymous
	var/formatted_message = message_template
	for(var/role in list("USER", "TARGET"))
		var/is_user = role == "USER"
		var/mob/living/carbon/human/participant = is_user ? user : target
		var/anonymous = is_user ? user_anonymous : target_anonymous
		var/is_recipient = participant == recipient && !anonymous
		var/participant_name = "[participant]"
		if(anonymous)
			participant_name = (is_user ? null : route?.get_target_name()) || "Unknown"
		else if(is_recipient)
			participant_name = "you"
		if(is_user && omit_user)
			participant_name = ""

		var/possessive = is_recipient ? (known_self_interaction ? "your own" : "your") : "[participant_name]'s"
		var/object_name = is_recipient && known_self_interaction ? "yourself" : participant_name
		var/their = is_recipient ? "your" : (anonymous ? "their" : participant.p_their())
		var/theirs = is_recipient ? "yours" : (anonymous ? "theirs" : participant.p_theirs())
		var/them = is_recipient ? (known_self_interaction ? "yourself" : "you") : (anonymous ? "them" : participant.p_them())
		var/they = is_recipient ? "you" : (anonymous ? "they" : participant.p_they())
		var/themselves = is_recipient ? "yourself" : (anonymous ? "themselves" : participant.p_themselves())

		// Expand possessives before bare names so a recipient never becomes "you's".
		formatted_message = replacetext(formatted_message, "%[role]%'s", possessive)
		formatted_message = replacetext(formatted_message, "%[role]_CAPITAL%'s", capitalize(possessive))
		formatted_message = replacetext(formatted_message, "%[role]%", participant_name)
		formatted_message = replacetext(formatted_message, "%[role]_CAPITAL%", capitalize(participant_name))
		formatted_message = replacetext(formatted_message, "%[role]_OBJECT%", object_name)
		// Templates supply agreement explicitly; do not guess how to conjugate arbitrary prose.
		formatted_message = replacetext(formatted_message, "%[role]_VERB_S%", is_recipient ? "" : "s")
		formatted_message = replacetext(formatted_message, "%[role]_VERB_ES%", is_recipient ? "" : "es")
		formatted_message = replacetext(formatted_message, "%[role]_PRONOUN_THEIR%", their)
		formatted_message = replacetext(formatted_message, "%[role]_PRONOUN_THEIRS%", theirs)
		formatted_message = replacetext(formatted_message, "%[role]_PRONOUN_THEM%", them)
		formatted_message = replacetext(formatted_message, "%[role]_PRONOUN_THEY%", they)
		formatted_message = replacetext(formatted_message, "%[role]_PRONOUN_THEMSELVES%", themselves)
	return trim(formatted_message, INTERACTION_MAX_CHAR)

/// Applies side effects only while the interaction's original authority remains valid.
/datum/interaction/proc/apply_effects(
	datum/weakref/user_ref,
	datum/weakref/target_ref,
	datum/interaction_route/route = null,
)
	var/mob/living/carbon/human/user = user_ref?.resolve()
	var/mob/living/carbon/human/target = target_ref?.resolve()
	// The successful caller already paid the cooldown for these queued effects.
	if(!can_execute(user, target, route, ignore_cooldown = TRUE))
		return
	if(user_pain)
		user.adjust_pain(user_pain)
	if(target_pain)
		target.adjust_pain(target_pain)
	if(!lewd)
		return
	if(user_pleasure)
		user.adjust_pleasure(user_pleasure)
	if(user_arousal)
		user.adjust_arousal(user_arousal)
	if(target_pleasure)
		target.adjust_pleasure(target_pleasure)
	if(target_arousal)
		target.adjust_arousal(target_arousal)
	route?.after_effects(user, target)

/datum/interaction/proc/load_from_json(path)
	var/fpath = path
	if(!fexists(fpath))
		message_admins("Attempted to load an interaction from json and the file does not exist")
		qdel(src)
		return FALSE
	var/file = file(fpath)
	var/list/json = json_load(file)
	name = sanitize_text(json["name"])
	description = sanitize_text(json["description"])
	distance_allowed = sanitize_integer(json["distance_allowed"], 0, 1, 0)
	message = sanitize_islist(json["message"], list("json error"))
	category = sanitize_text(json["category"])
	usage = sanitize_text(json["usage"])
	sound_use = sanitize_integer(json["sound_use"], 0, 1, 0)
	sound_range = sanitize_integer(json["sound_range"], 1, 7, 1)
	sound_vary = sanitize_integer(json["sound_vary"], 0, 1, 1)
	sound_possible = sanitize_islist(json["sound_possible"], list("json error"))
	interaction_requires = sanitize_islist(json["interaction_requires"], list())
	color = sanitize_text(json["color"])

	user_messages = sanitize_islist(json["user_messages"], list())
	user_required_parts = sanitize_islist(json["user_required_parts"], list())
	user_arousal = sanitize_integer(json["user_arousal"], 0, 100, 0)
	user_pleasure = sanitize_integer(json["user_pleasure"], 0, 100, 0)
	user_pain = sanitize_integer(json["user_pain"], 0, 100, 0)
	target_messages = sanitize_islist(json["target_messages"], list())
	target_required_parts = sanitize_islist(json["target_required_parts"], list())
	target_arousal = sanitize_integer(json["target_arousal"], 0, 100, 0)
	target_pleasure = sanitize_integer(json["target_pleasure"], 0, 100, 0)
	target_pain = sanitize_integer(json["target_pain"], 0, 100, 0)
	lewd = sanitize_integer(json["lewd"], 0, 1, 0)
	sexuality = sanitize_text(json["sexuality"])
	return TRUE

/datum/interaction/proc/json_save(path)
	var/fpath = path
	if(fexists(fpath))
		fdel(fpath)
	var/list/json = list(
		"name" = name,
		"description" = description,
		"distance_allowed" = distance_allowed,
		"message" = message,
		"category" = category,
		"usage" = usage,
		"sound_use" = sound_use,
		"sound_range" = sound_range,
		"sound_vary" = sound_vary,
		"sound_possible" = sound_possible,
		"interaction_requires" = interaction_requires,
		"color" = color,
		"user_messages" = user_messages,
		"user_required_parts" = user_required_parts,
		"user_arousal" = user_arousal,
		"user_pleasure" = user_pleasure,
		"user_pain" = user_pain,
		"target_messages" = target_messages,
		"target_required_parts" = target_required_parts,
		"target_arousal" = target_arousal,
		"target_pleasure" = target_pleasure,
		"target_pain" = target_pain,
		"lewd" = lewd,
		"sexuality" = sexuality,
	)
	var/file = file(fpath)
	WRITE_FILE(file, json_encode(json))
	return TRUE

/// Global loading procs
/proc/populate_interaction_instances()
	for(var/spath in subtypesof(/datum/interaction))
		var/datum/interaction/interaction = new spath()
		GLOB.interaction_instances[interaction.name] = interaction
	populate_interaction_jsons(INTERACTION_JSON_FOLDER)

/proc/populate_interaction_jsons(directory)
	for(var/path in pathwalk(directory, ".json"))
		if(endswith(path, ".master.json"))
			populate_interaction_jsons_master(path)
			continue
		var/datum/interaction/interaction = new()
		if(interaction.load_from_json(path))
			GLOB.interaction_instances[interaction.name] = interaction
		else message_admins("Error loading interaction from file: '[html_encode(path)]'. Inform coders.")

/proc/populate_interaction_jsons_master(path)
	if(!fexists(path))
		message_admins("We are attempting to load an interaction master without the file existing! '[path]'")
		return
	var/file = file(path)
	var/list/json = json_load(file)

	for(var/iname in json)
		if(GLOB.interaction_instances[iname])
			message_admins("Interaction Master '[html_encode(path)]' contained a duplicate interaction! '[html_encode(iname)]'")
			continue

		var/list/ijson = json[iname]
		if(ijson["name"] != iname)
			message_admins("Interaction Master '[html_encode(path)]' contained an invalid interaction! '[html_encode(iname)]'")
			continue

		var/datum/interaction/interaction = new()

		interaction.distance_allowed = sanitize_integer(ijson["distance_allowed"], 0, 1, 0)
		interaction.message = sanitize_islist(ijson["message"], list("json error"))
		interaction.category = sanitize_text(ijson["category"])
		interaction.usage = sanitize_text(ijson["usage"])
		interaction.sound_use = sanitize_integer(ijson["sound_use"], 0, 1, 0)
		interaction.sound_range = sanitize_integer(ijson["sound_range"], 1, 7, 1)
		interaction.sound_vary = sanitize_integer(ijson["sound_vary"], 0, 1, 1)
		interaction.sound_possible = sanitize_islist(ijson["sound_possible"], list("json error"))
		interaction.interaction_requires = sanitize_islist(ijson["interaction_requires"], list())
		interaction.color = sanitize_text(ijson["color"])

		interaction.user_messages = sanitize_islist(ijson["user_messages"], list())
		interaction.user_required_parts = sanitize_islist(ijson["user_required_parts"], list())
		interaction.user_arousal = sanitize_integer(ijson["user_arousal"], 0, 100, 0)
		interaction.user_pleasure = sanitize_integer(ijson["user_pleasure"], 0, 100, 0)
		interaction.user_pain = sanitize_integer(ijson["user_pain"], 0, 100, 0)
		interaction.target_messages = sanitize_islist(ijson["target_messages"], list())
		interaction.target_required_parts = sanitize_islist(ijson["target_required_parts"], list())
		interaction.target_arousal = sanitize_integer(ijson["target_arousal"], 0, 100, 0)
		interaction.target_pleasure = sanitize_integer(ijson["target_pleasure"], 0, 100, 0)
		interaction.target_pain = sanitize_integer(ijson["target_pain"], 0, 100, 0)
		interaction.lewd = sanitize_integer(ijson["lewd"], 0, 1, 0)
		interaction.sexuality = sanitize_text(ijson["sexuality"])

		GLOB.interaction_instances[iname] = interaction

ADMIN_VERB(reload_interactions, R_DEBUG, "Reload Interactions", "Force reload interactions.", ADMIN_CATEGORY_DEBUG)
	populate_interaction_instances()
