/datum/emote
	/// If we should check a preference for this emote
	var/pref_to_check

/datum/emote/living/lewd
	pref_to_check = /datum/preference/toggle/erp
	emote_type = parent_type::emote_type | EMOTE_LEWD

// Can we play this emote to viewers?
/datum/emote/proc/pref_check_emote(mob/user, client/client, preference)
	. = TRUE
	if(isnull(pref_to_check) && isnull(preference))
		return

	var/client/user_client = client || user.client
	if(user_client && !user_client.prefs.read_preference(pref_to_check || preference))
		return FALSE

/datum/emote/living/lewd/can_run_emote(mob/living/carbon/user, status_check = TRUE, intentional, params)
	return ..() && user.client?.prefs?.read_preference(pref_to_check)

/datum/emote/living/lewd/lewdmoan
	key = "lewdmoan"
	key_third_person = "lewdmoans"
	message = "moans lewdly!"
	emote_type = parent_type::emote_type | EMOTE_AUDIBLE
	vary = TRUE
	sound_volume = 35

/datum/emote/living/lewd/lewdmoan/get_sound(mob/living/carbon/user)
	if(!istype(user))
		return

	if(user.gender == MALE)
		return pick('modular_nova/modules/modular_items/lewd_items/sounds/final_m1.ogg',
					'modular_nova/modules/modular_items/lewd_items/sounds/final_m2.ogg',
					'modular_nova/modules/modular_items/lewd_items/sounds/final_m3.ogg',

		)
	else
		return pick('modular_nova/modules/modular_items/lewd_items/sounds/final_f1.ogg',
					'modular_nova/modules/modular_items/lewd_items/sounds/final_f2.ogg',
					'modular_nova/modules/modular_items/lewd_items/sounds/final_f3.ogg',
		)

/// Bounces on the spot so the chest jiggles. `*jiggle 6` keeps it up for six seconds; using it again stops.
/datum/emote/living/lewd/jiggle
	key = "jiggle"
	key_third_person = "jiggles"
	message = "shakes their chest and bounces on the spot!"
	mob_type_allowed_typecache = /mob/living/carbon/human

/datum/emote/living/lewd/jiggle/can_run_emote(mob/living/carbon/human/user, status_check = TRUE, intentional, params)
	if(!..())
		return FALSE
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	if(chest?.is_playing(chest.get_shape()?.jiggle_icon))
		return TRUE
	var/blocker = chest ? chest.bounce_blocker() : "You have nothing to bounce."
	if(blocker && intentional)
		to_chat(user, span_warning(blocker))
	return !blocker

/datum/emote/living/lewd/jiggle/select_message_type(mob/living/carbon/human/user, msg, intentional)
	. = ..()
	if(user.has_pecs())
		return "flexes and bounces their pecs!"

/datum/emote/living/lewd/jiggle/run_emote(mob/living/carbon/human/user, params, type_override, intentional)
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	if(chest?.is_playing(chest.get_shape()?.jiggle_icon))
		chest.stop_bounce()
		return
	// Text after the key is how many seconds to keep it up, so it never stands in for the message.
	var/seconds = text2num(params)
	if(!chest?.start_bounce(seconds > 0 ? seconds SECONDS : BREAST_BOUNCE_DEFAULT_DURATION))
		return
	return ..(user, null, type_override, intentional)

// Not lewd: the pecs flex and bounce from their own sheets, and clothes only hide the sprite.
/// Flexes so both pecs bounce. `*pbounce 6` keeps it up for six seconds; using it again stops.
/// No key_third_person on these: "pbounces" is the slow flex's key.
/datum/emote/living/carbon/human/pecbounce
	key = "pbounce"
	name = "pec bounce"
	message = "flexes, bouncing their pecs."
	/// The pecs take turns instead of bouncing together.
	var/alternating = FALSE
	/// Slowed down, each flex held longer.
	var/slow = FALSE

/// The pecs bounce one after the other.
/datum/emote/living/carbon/human/pecbounce/alternate
	key = "pbounce2"
	name = "pec bounce 2"
	message = "bounces their pecs one after the other."
	alternating = TRUE

/datum/emote/living/carbon/human/pecbounce/slow
	key = "pbounces"
	name = "pec bounce (slow)"
	message = "slowly flexes, bouncing their pecs."
	slow = TRUE

/datum/emote/living/carbon/human/pecbounce/alternate/slow
	key = "pbounce2s"
	name = "pec bounce 2 (slow)"
	message = "slowly bounces their pecs one after the other."
	slow = TRUE

/datum/emote/living/carbon/human/pecbounce/can_run_emote(mob/living/carbon/human/user, status_check = TRUE, intentional, params)
	if(!..())
		return FALSE
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	if(chest?.is_playing(chest.flex_sheet(alternating, slow)))
		return TRUE
	var/blocker = chest ? chest.flex_blocker() : "You have no pecs to bounce."
	if(blocker && intentional)
		to_chat(user, span_warning(blocker))
	return !blocker

/datum/emote/living/carbon/human/pecbounce/run_emote(mob/living/carbon/human/user, params, type_override, intentional)
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	if(chest?.is_playing(chest.flex_sheet(alternating, slow)))
		chest.stop_bounce()
		return
	// Text after the key is how many seconds to keep it up, so it never stands in for the message.
	var/seconds = text2num(params)
	if(!chest?.start_flex(alternating, slow, seconds > 0 ? seconds SECONDS : BREAST_BOUNCE_DEFAULT_DURATION))
		return
	return ..(user, null, type_override, intentional)
