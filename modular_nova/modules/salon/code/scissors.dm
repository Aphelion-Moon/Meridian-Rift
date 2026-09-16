/obj/item/scissors
	name = "barber's scissors"
	desc = "Some say a barbers best tool is his electric razor, that is not the case. These are used to cut hair in a professional way!"
	icon = 'modular_nova/modules/salon/icons/items.dmi'
	lefthand_file = 'modular_nova/modules/salon/icons/items_lefthand.dmi'
	righthand_file = 'modular_nova/modules/salon/icons/items_righthand.dmi'
	icon_state = "scissors"
	w_class = WEIGHT_CLASS_TINY
	sharpness = SHARP_EDGED
	// How long does it take to change someone's hairstyle?
	var/haircut_duration = 1 MINUTES
	// How long does it take to change someone's facial hair style?
	var/facial_haircut_duration = 20 SECONDS
	// Same as above, but for those with the hair expert trait
	var/haircut_duration_expert = 45 SECONDS
	var/facial_haircut_duration_expert = 15 SECONDS

/obj/item/scissors/attack(mob/living/attacked_mob, mob/living/user, params)
	if(!ishuman(attacked_mob))
		return

	var/mob/living/carbon/human/target_human = attacked_mob

	var/location = user.zone_selected
	if(!(location in list(BODY_ZONE_PRECISE_MOUTH, BODY_ZONE_HEAD)) && !user.combat_mode)
		to_chat(user, span_warning("You stop, look down at what you're currently holding and ponder to yourself, \"This is probably to be used on their hair or their facial hair.\""))
		return

	if(target_human.hairstyle == "Bald" && target_human.facial_hairstyle == "Shaved")
		// APHELION EDIT ADDITION START - Bald heads can still get custom hair
		if(user.zone_selected == BODY_ZONE_HEAD)
			var/bare_choice = tgui_alert(user, "[target_human] has nothing to cut. Draw a custom style instead?", "It's sculpting time!", list("Custom Hair", "Custom Facial Hair", "Cancel"))
			if(bare_choice in list("Custom Hair", "Custom Facial Hair"))
				custom_sprite_salon_tool_menu(src, user, target_human, bare_choice == "Custom Hair" ? "hair" : "facial_hair")
				return
		// APHELION EDIT ADDITION END
		balloon_alert(user, "no hair!")
		return

	if(user.zone_selected != BODY_ZONE_HEAD)
		return ..()

	var/selected_part = tgui_alert(user, "Please select which part of [target_human] you would like to sculpt!", "It's sculpting time!", list("Hair", "Facial Hair", "Custom Style", "Cancel")) // APHELION EDIT CHANGE - ORIGINAL: var/selected_part = tgui_alert(user, "Please select which part of [target_human] you would like to sculpt!", "It's sculpting time!", list("Hair", "Facial Hair", "Cancel"))

	if(!selected_part || selected_part == "Cancel")
		return

	// APHELION EDIT ADDITION START - Custom hair drawing
	if(selected_part == "Custom Style")
		var/custom_target = tgui_alert(user, "Which custom drawing?", "It's sculpting time!", list("Hair", "Facial Hair", "Cancel"))
		if(custom_target in list("Hair", "Facial Hair"))
			custom_sprite_salon_tool_menu(src, user, target_human, custom_target == "Hair" ? "hair" : "facial_hair")
		return
	// APHELION EDIT ADDITION END
	if(selected_part == "Hair")
		if(!target_human.hairstyle == "Bald" && target_human.head)
			balloon_alert(user, "no hair to cut!")
			return

		var/hair_id = tgui_input_list(user, "Please select what hairstyle you'd like to sculpt!", "Select masterpiece", SSaccessories.hairstyles_list)
		if(!hair_id)
			return

		if(hair_id == "Bald")
			to_chat(target_human, span_danger("[user] seems to be cutting all your hair off!"))

		to_chat(user, span_notice("You begin to masterfully sculpt [target_human]'s hair!"))

		// playsound(target_human, 'modular_nova/modules/salon/sound/haircut.ogg', 100) // APHELION EDIT REMOVAL

		if(HAS_TRAIT(user, TRAIT_HAIR_EXPERT))
			if(do_salon_work(user, haircut_duration_expert, target_human)) // APHELION EDIT CHANGE - ORIGINAL: if(do_after(user, haircut_duration_expert, target_human))
				var/shorn_style = target_human.hairstyle // APHELION EDIT ADDITION - what falls on the floor is the style coming off, not the new one
				target_human.set_hairstyle(hair_id, update = TRUE)
				user.visible_message(span_notice("[user] expertly cuts [target_human]'s hair!"), span_notice("You expertly cut [target_human]'s hair!"))
				// APHELION EDIT ADDITION START - a quicker cut still leaves the same hair on the floor
				drop_hair_trimmings(get_turf(src), target_human, hair_id == "Bald" ? 3 : 2, hairstyle = shorn_style)
				INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(offer_to_keep_hairstyle), target_human, hair_id)
				// APHELION EDIT ADDITION END
		else
			if(do_salon_work(user, haircut_duration, target_human)) // APHELION EDIT CHANGE - ORIGINAL: if(do_after(user, haircut_duration, target_human))
				var/shorn_style = target_human.hairstyle // APHELION EDIT ADDITION - what falls on the floor is the style coming off, not the new one
				target_human.set_hairstyle(hair_id, update = TRUE)
				user.visible_message(span_notice("[user] successfully cuts [target_human]'s hair!"), span_notice("You successfully cut [target_human]'s hair!"))
				drop_hair_trimmings(get_turf(src), target_human, hair_id == "Bald" ? 3 : 2, hairstyle = shorn_style) // APHELION EDIT CHANGE - ORIGINAL: new /obj/effect/decal/cleanable/hair(get_turf(src))
				INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(offer_to_keep_hairstyle), target_human, hair_id) // APHELION EDIT ADDITION - offer to keep the new style for future rounds
	else
		if(!target_human.facial_hairstyle == "Shaved" && target_human.wear_mask)
			balloon_alert(user, "no hair to cut!")
			return

		var/facial_hair_id = tgui_input_list(user, "Please select what facial hairstyle you'd like to sculpt!", "Select masterpiece", SSaccessories.facial_hairstyles_list)
		if(!facial_hair_id)
			return

		if(facial_hair_id == "Shaved")
			to_chat(target_human, span_danger("[user] seems to be cutting all your facial hair off!"))

		to_chat(user, "You begin to masterfully sculpt [target_human]'s facial hair!")

		// playsound(target_human, 'modular_nova/modules/salon/sound/haircut.ogg', 100) // APHELION EDIT REMOVAL

		if(HAS_TRAIT(user, TRAIT_HAIR_EXPERT))
			if(do_salon_work(user, facial_haircut_duration_expert, target_human)) // APHELION EDIT CHANGE - ORIGINAL: if(do_after(user, facial_haircut_duration_expert, target_human))
				var/shorn_style = target_human.facial_hairstyle // APHELION EDIT ADDITION - what falls on the floor is the style coming off, not the new one
				target_human.set_facial_hairstyle(facial_hair_id, update = TRUE)
				user.visible_message(span_notice("[user] expertly cuts [target_human]'s facial hair!"), span_notice("You expertly cut [target_human]'s facial hair!"))
				// APHELION EDIT ADDITION START - a quicker cut still leaves the same hair on the floor
				drop_hair_trimmings(get_turf(src), target_human, facial_hair_id == "Shaved" ? 2 : 1, facial = TRUE, hairstyle = shorn_style)
				INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(offer_to_keep_hairstyle), target_human, facial_hair_id, TRUE)
				// APHELION EDIT ADDITION END
		else
			if(do_salon_work(user, facial_haircut_duration, target_human)) // APHELION EDIT CHANGE - ORIGINAL: if(do_after(user, facial_haircut_duration, target_human))
				var/shorn_style = target_human.facial_hairstyle // APHELION EDIT ADDITION - what falls on the floor is the style coming off, not the new one
				target_human.set_facial_hairstyle(facial_hair_id, update = TRUE)
				user.visible_message(span_notice("[user] successfully cuts [target_human]'s facial hair!"), span_notice("You successfully cut [target_human]'s facial hair!"))
				drop_hair_trimmings(get_turf(src), target_human, facial_hair_id == "Shaved" ? 2 : 1, facial = TRUE, hairstyle = shorn_style) // APHELION EDIT CHANGE - ORIGINAL: new /obj/effect/decal/cleanable/hair(get_turf(src))
				INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(offer_to_keep_hairstyle), target_human, facial_hair_id, TRUE) // APHELION EDIT ADDITION - offer to keep the new style for future rounds

// APHELION EDIT ADDITION START - Offer to keep a salon haircut for future rounds.
/// How long the recipient has to answer before the offer lapses.
#define HAIR_KEEP_PROMPT_TIMEOUT (60 SECONDS)

/**
 * Asks the freshly cut recipient whether to keep the style beyond this round.
 *
 * Sleeps on the prompt, so call it asynchronously and let the barber carry on.
 * Says nothing when the style already matches what they spawn with.
 *
 * * recipient - whose hair was cut, and who gets asked.
 * * hairstyle - the style that was just applied.
 * * facial - it was their facial hair that changed.
 */
/proc/offer_to_keep_hairstyle(mob/living/carbon/human/recipient, hairstyle, facial = FALSE)
	if(QDELETED(recipient) || !recipient.client || isnull(hairstyle))
		return
	var/datum/preferences/preferences = GLOB.preferences_datums[recipient.ckey]
	var/preference_type = facial ? /datum/preference/choiced/facial_hairstyle : /datum/preference/choiced/hairstyle
	if(!preferences || preferences.read_preference(preference_type) == hairstyle)
		return
	var/label = facial ? "facial hairstyle" : "hairstyle"
	var/answer = tgui_alert(
		recipient,
		"Keep [hairstyle] for future rounds, or just this one?",
		"New [label]",
		list("Keep it", "Just this round"),
		HAIR_KEEP_PROMPT_TIMEOUT,
	)
	if(answer != "Keep it")
		return
	var/problem = keep_hairstyle(recipient, hairstyle, facial)
	if(problem)
		to_chat(recipient, span_warning("[problem] Your new [label] still lasts the rest of the round."))
		return
	to_chat(recipient, span_notice("Saved. You'll start future rounds with this [label]."))

/**
 * Writes a hairstyle to the character slot this body spawned from.
 *
 * Guarded the same way [/datum/custom_sprite_mirror/proc/save_style] is: without
 * these checks the write could land on whichever character happens to be
 * selected in character setup instead of the one standing in the barber's chair.
 *
 * Returns a player-facing problem, or null once saved.
 */
/proc/keep_hairstyle(mob/living/carbon/human/recipient, hairstyle, facial = FALSE)
	var/datum/preferences/preferences = GLOB.preferences_datums[recipient.ckey]
	var/datum/client_interface/player = GET_CLIENT(recipient)
	if(!preferences || player?.prefs != preferences)
		return "Your character preferences aren't loaded."
	// Characters spawned by an admin have no recorded slot, so the name decides.
	var/spawned_slot = recipient.mind?.original_character_slot_index
	if(spawned_slot && spawned_slot != preferences.default_slot)
		return "Select the character slot you spawned with in character setup, then try again."
	if(preferences.read_preference(/datum/preference/name/real_name) != recipient.real_name)
		return "The selected character slot belongs to a different character."
	var/datum/preference/entry = GLOB.preference_entries[facial ? /datum/preference/choiced/facial_hairstyle : /datum/preference/choiced/hairstyle]
	if(!preferences.write_preference(entry, hairstyle))
		return "That [facial ? "facial hairstyle" : "hairstyle"] can't be saved to this character."
	preferences.save_character()
	log_game("[key_name(recipient)] kept a salon [facial ? "facial hairstyle" : "hairstyle"] '[hairstyle]' on character slot [preferences.default_slot].")
	return null

#undef HAIR_KEEP_PROMPT_TIMEOUT
// APHELION EDIT ADDITION END
