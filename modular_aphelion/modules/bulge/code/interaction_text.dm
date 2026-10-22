/// Optional text is immutable input per interaction; no per-mob or global lookup cache.
/datum/interaction
	var/list/message_pit_hair
	var/list/user_messages_pit_hair
	var/list/target_messages_pit_hair
	/// Extra `message` options joining the pool while the sweaty participant is visibly sweating. Optional.
	var/list/message_sweaty
	/// Extra `user_messages` options joining the pool while the sweaty participant is visibly sweating. Optional.
	var/list/user_messages_sweaty
	/// Extra `target_messages` options joining the pool while the sweaty participant is visibly sweating. Optional.
	var/list/target_messages_sweaty
	/// Whose sweat the `*_sweaty` text follows: the target's by default, the user's when set (pitjobs, smothering).
	var/sweaty_is_user = FALSE
	/// Emote keys the actor fires when a specific `message` template is picked: list("template" = "moan"). Optional.
	var/list/message_auto_emotes
	/// Messages replacing the whole `message` pool while the bulge's penis pokes out (bulge_pokes_out()):
	/// bare-skin text for when head-through-cloth lines no longer apply. Optional.
	var/list/message_pokes_out
	/// Messages replacing the whole `user_messages` pool while the bulge's penis pokes out. Optional.
	var/list/user_messages_pokes_out
	/// Messages replacing the whole `target_messages` pool while the bulge's penis pokes out. Optional.
	var/list/target_messages_pokes_out

/// Reads the optional Aphelion text: pit-hair and sweaty extras, and per-line auto emotes.
/datum/interaction/proc/load_aphelion_text(list/json)
	message_pit_hair = sanitize_islist(json["message_pit_hair"], null)
	user_messages_pit_hair = sanitize_islist(json["user_messages_pit_hair"], null)
	target_messages_pit_hair = sanitize_islist(json["target_messages_pit_hair"], null)
	message_sweaty = sanitize_islist(json["message_sweaty"], null)
	user_messages_sweaty = sanitize_islist(json["user_messages_sweaty"], null)
	target_messages_sweaty = sanitize_islist(json["target_messages_sweaty"], null)
	sweaty_is_user = sanitize_integer(json["sweaty_is_user"], 0, 1, 0)
	message_auto_emotes = sanitize_islist(json["message_auto_emotes"], null)
	message_pokes_out = sanitize_islist(json["message_pokes_out"], null)
	user_messages_pokes_out = sanitize_islist(json["user_messages_pokes_out"], null)
	target_messages_pokes_out = sanitize_islist(json["target_messages_pokes_out"], null)

/// Writes back whichever optional Aphelion text is set.
/datum/interaction/proc/save_aphelion_text(list/json)
	if(message_pit_hair)
		json["message_pit_hair"] = message_pit_hair
	if(user_messages_pit_hair)
		json["user_messages_pit_hair"] = user_messages_pit_hair
	if(target_messages_pit_hair)
		json["target_messages_pit_hair"] = target_messages_pit_hair
	if(message_sweaty)
		json["message_sweaty"] = message_sweaty
	if(user_messages_sweaty)
		json["user_messages_sweaty"] = user_messages_sweaty
	if(target_messages_sweaty)
		json["target_messages_sweaty"] = target_messages_sweaty
	if(sweaty_is_user)
		json["sweaty_is_user"] = sweaty_is_user
	if(message_auto_emotes)
		json["message_auto_emotes"] = message_auto_emotes
	if(message_pokes_out)
		json["message_pokes_out"] = message_pokes_out
	if(user_messages_pokes_out)
		json["user_messages_pokes_out"] = user_messages_pokes_out
	if(target_messages_pokes_out)
		json["target_messages_pokes_out"] = target_messages_pokes_out

/// Whether this mob visibly reads as sweaty to interaction text. The hook for the dirt and sweat
/// overlays: report their sweat state here once they land. Until then nobody reads as sweaty, so
/// `*_sweaty` interaction text ships dormant.
/mob/living/carbon/human/proc/is_visibly_sweaty()
	return FALSE

/// The mob's armpit as interaction text reads it: hair and sweat become adjectives, the hair's by style.
/mob/living/carbon/human/proc/described_armpit()
	var/hair_adjective
	if(istype(get_organ_slot(ORGAN_SLOT_EXTERNAL_PITS), /obj/item/organ/body_hair/pits))
		var/datum/mutant_bodypart/pit_part = dna?.mutant_bodyparts[FEATURE_PITS]
		switch(pit_part?.name)
			if("Trimmed")
				hair_adjective = "trimmed"
			if("Untamed")
				hair_adjective = "bushy"
			else
				hair_adjective = "hairy"
	if(is_visibly_sweaty())
		return hair_adjective ? "sweaty, [hair_adjective] armpit" : "sweaty armpit"
	return hair_adjective ? "[hair_adjective] armpit" : "armpit"

/// The mob's bulge as interaction text reads it: sweat becomes an adjective.
/mob/living/carbon/human/proc/described_bulge()
	return is_visibly_sweaty() ? "sweat-damp bulge" : "bulge"
