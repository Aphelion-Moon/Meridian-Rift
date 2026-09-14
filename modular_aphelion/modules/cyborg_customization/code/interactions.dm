/// Deliberately small interaction capability surface for cyborgs. Visual anatomy
/// does not grant organs, hands, toy handling, vore, or any lewd interaction.

/proc/cyborg_interaction_participant(mob/living/mob)
	return ishuman(mob) || istype(mob, /mob/living/silicon/robot)

/proc/cyborg_message_interaction_contract_is_safe(datum/interaction/interaction, mob/living/actor, mob/living/target)
	if(!interaction || interaction.lewd || actor == target || interaction.usage != INTERACTION_OTHER || interaction.category != "Miscellaneous")
		return FALSE
	if(length(interaction.user_required_parts) || length(interaction.target_required_parts) || length(interaction.user_messages) || length(interaction.target_messages))
		return FALSE
	if(interaction.user_pain || interaction.user_pleasure || interaction.user_arousal || interaction.target_pain || interaction.target_pleasure || interaction.target_arousal)
		return FALSE
	if(interaction.sound_use || interaction.sound_cache || length(interaction.sexuality))
		return FALSE
	// The interaction JSON loader represents an explicit empty sound array as this
	// sentinel. It has no playable effect while sound_use remains false.
	if(length(interaction.sound_possible) && (length(interaction.sound_possible) != 1 || interaction.sound_possible[1] != "json error"))
		return FALSE
	if(!length(interaction.interaction_requires))
		return TRUE
	if(!ishuman(actor) || length(interaction.interaction_requires) != 1 || interaction.interaction_requires[1] != INTERACTION_REQUIRE_SELF_HAND)
		return FALSE
	return !!actor.get_active_hand()

/proc/cyborg_message_interaction_allowed(datum/interaction/interaction, mob/living/actor, mob/living/target)
	if(!cyborg_interaction_participant(actor) || !cyborg_interaction_participant(target) || !cyborg_message_interaction_contract_is_safe(interaction, actor, target))
		return FALSE
	if(!interaction.distance_allowed && !actor.Adjacent(target))
		return FALSE
	if(istype(actor, /mob/living/silicon/robot))
		return interaction.name == "Cheer"
	if(istype(target, /mob/living/silicon/robot))
		return interaction.name in list("Cheer", "Beckon", "Headpat", "Pat")
	return FALSE

/// Uses only authored non-lewd messages. It never invokes the human effects path.
/proc/cyborg_message_interaction_act(datum/interaction/interaction, mob/living/actor, mob/living/target)
	if(!cyborg_message_interaction_allowed(interaction, actor, target) || !length(interaction.message))
		return FALSE
	var/message = islist(interaction.message) ? pick(interaction.message) : interaction.message
	if(!istext(message))
		return FALSE
	message = trim(replacetext(replacetext(message, "%TARGET%", "[target]"), "%USER%", ""), INTERACTION_MAX_CHAR)
	message = replacetext(replacetext(message, "%TARGET_PRONOUN_THEIR%", target.p_their()), "%TARGET_PRONOUN_THEIRS%", target.p_theirs())
	message = replacetext(replacetext(message, "%USER_PRONOUN_THEIR%", actor.p_their()), "%USER_PRONOUN_THEIRS%", actor.p_theirs())
	message = replacetext(replacetext(message, "%TARGET_PRONOUN_THEM%", target.p_them()), "%USER_PRONOUN_THEM%", actor.p_them())
	message = replacetext(replacetext(message, "%TARGET_PRONOUN_THEY%", target.p_they()), "%USER_PRONOUN_THEY%", actor.p_they())
	actor.manual_emote(message)
	return TRUE

/// The runtime backend shares this actor/slot gate with its self-management UI.
/proc/cyborg_runtime_actor_is_owner(mob/living/silicon/robot/robot, mob/actor, character_slot)
	var/datum/preferences/owner_preferences = cyborg_preferences_for(robot)
	if(!robot || !istype(actor, /mob/living/silicon/robot) || actor != robot || !owner_preferences)
		return FALSE
	return robot.cyborg_appearance_owner == robot.ckey \
		&& robot.cyborg_appearance_slot == owner_preferences.default_slot \
		&& character_slot == robot.cyborg_appearance_slot
