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

/// Bounces on the spot so the chest jiggles, breasts or pecs, with no chat line. `*jiggle 6` keeps it up for six seconds;
/// using it again, or *bounce, stops.
/datum/emote/living/lewd/jiggle
	key = "jiggle"
	key_third_person = "jiggles"
	mob_type_allowed_typecache = /mob/living/carbon/human

/datum/emote/living/lewd/jiggle/can_run_emote(mob/living/carbon/human/user, status_check = TRUE, intentional, params)
	if(!..())
		return FALSE
	if(user.has_status_effect(/datum/status_effect/bouncing))
		return TRUE
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	var/blocker = chest ? chest.bounce_blocker() : "You have nothing to bounce."
	if(blocker && intentional)
		to_chat(user, span_warning(blocker))
	return !blocker

/datum/emote/living/lewd/jiggle/run_emote(mob/living/carbon/human/user, params, type_override, intentional)
	if(user.remove_status_effect(/datum/status_effect/bouncing))
		return
	// The jiggle takes over from a pec flex.
	var/obj/item/organ/genital/breasts/chest = user.get_organ_slot(ORGAN_SLOT_BREASTS)
	chest?.stop_bounce()
	// Text after the key is how many seconds to keep it up. The parent isn't called: it would print that text as the emote.
	var/seconds = text2num(params)
	user.apply_status_effect(/datum/status_effect/bouncing, seconds > 0 ? seconds SECONDS : BREAST_BOUNCE_DEFAULT_DURATION, TRUE)

// Not lewd: anyone can bounce, and only bare breasts jiggle along, for a player with ERP on.
/// Bounces on the spot, with no chat line. `*bounce 6` keeps it up for six seconds; using it again, or *jiggle, stops.
/datum/emote/living/carbon/human/bounce
	key = "bounce"
	key_third_person = "bounces"
	name = "bounce"

/datum/emote/living/carbon/human/bounce/can_run_emote(mob/living/carbon/human/user, status_check = TRUE, intentional, params)
	if(!..())
		return FALSE
	if(user.has_status_effect(/datum/status_effect/bouncing) || user.body_position == STANDING_UP)
		return TRUE
	if(intentional)
		to_chat(user, span_warning("You need to be on your feet."))
	return FALSE

/datum/emote/living/carbon/human/bounce/run_emote(mob/living/carbon/human/user, params, type_override, intentional)
	if(user.remove_status_effect(/datum/status_effect/bouncing))
		return
	// Text after the key is how many seconds to keep it up. The parent isn't called: it would print that text as the emote.
	var/seconds = text2num(params)
	user.apply_status_effect(/datum/status_effect/bouncing, seconds > 0 ? seconds SECONDS : BREAST_BOUNCE_DEFAULT_DURATION)

/**
 * Hops on the spot, two hops a cycle, for a time in whole cycles, while the owner stands. A chest that can jiggle
 * (bounce_blocker()) jiggles along: bare breasts, for a player with ERP on, or for a jiggle bare pecs too. A jiggle ends
 * once the chest can't.
 */
/datum/status_effect/bouncing
	id = "bouncing"
	alert_type = null
	tick_interval = STATUS_EFFECT_NO_TICK
	/// A jiggle, which jiggles pecs too and ends when the chest can't jiggle.
	var/jiggle = FALSE
	/// Cycles still to come.
	var/cycles_left = 0

/datum/status_effect/bouncing/on_creation(mob/living/new_owner, bounce_time = BREAST_BOUNCE_DEFAULT_DURATION, jiggle = FALSE)
	src.jiggle = jiggle
	cycles_left = max(1, round(min(bounce_time, BREAST_BOUNCE_MAX_DURATION) / BREAST_BOUNCE_CYCLE, 1))
	return ..()

/datum/status_effect/bouncing/on_apply()
	return bounce_cycle()

/datum/status_effect/bouncing/on_remove()
	var/mob/living/carbon/human/human_owner = owner
	var/obj/item/organ/genital/breasts/chest = human_owner.get_organ_slot(ORGAN_SLOT_BREASTS)
	chest?.set_jiggling(FALSE)

/// Hops twice, the chest jiggling if it can, and waits for the next cycle. FALSE once the bounce is over.
/datum/status_effect/bouncing/proc/bounce_cycle()
	var/mob/living/carbon/human/human_owner = owner
	var/obj/item/organ/genital/breasts/chest = human_owner.get_organ_slot(ORGAN_SLOT_BREASTS)
	var/jiggles = chest && !chest.bounce_blocker() && (jiggle || (!chest.pecs && human_owner.client?.prefs?.read_preference(/datum/preference/toggle/erp)))
	if(cycles_left <= 0 || IS_UNCONSCIOUS_OR_CRIT(human_owner) || human_owner.body_position != STANDING_UP || (jiggle && !jiggles))
		return FALSE
	cycles_left--
	chest?.set_jiggling(jiggles)
	animate(human_owner, pixel_z = BREAST_BOUNCE_HOP_HEIGHT, time = BREAST_BOUNCE_CYCLE / 4, easing = SINE_EASING | EASE_OUT, loop = 2, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_z = -BREAST_BOUNCE_HOP_HEIGHT, time = BREAST_BOUNCE_CYCLE / 4, easing = SINE_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	addtimer(CALLBACK(src, PROC_REF(next_cycle)), BREAST_BOUNCE_CYCLE)
	return TRUE

/// Runs the bounce's next cycle, or ends it.
/datum/status_effect/bouncing/proc/next_cycle()
	if(!bounce_cycle())
		qdel(src)

// Not lewd: the pecs flex and bounce from their own sheets, and clothes only hide the sprite.
/// Flexes so both pecs bounce together, with no chat line. `*pbounce1 6` keeps it up for six seconds; using it again
/// stops.
/datum/emote/living/carbon/human/pecbounce
	key = "pbounce1"
	name = "pec bounce 1 (together)"
	/// The pecs take turns instead of bouncing together.
	var/alternating = FALSE
	/// Slowed down, each flex held longer.
	var/slow = FALSE

/// The pecs bounce one after the other.
/datum/emote/living/carbon/human/pecbounce/alternate
	key = "pbounce2"
	name = "pec bounce 2 (taking turns)"
	alternating = TRUE

/datum/emote/living/carbon/human/pecbounce/slow
	key = "pbounce3"
	name = "pec bounce 3 (slow)"
	slow = TRUE

/datum/emote/living/carbon/human/pecbounce/alternate/slow
	key = "pbounce4"
	name = "pec bounce 4 (slow, taking turns)"
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
	// Text after the key is how many seconds to keep it up. The parent isn't called: it would print that text as the emote.
	var/seconds = text2num(params)
	chest?.start_flex(alternating, slow, seconds > 0 ? seconds SECONDS : BREAST_BOUNCE_DEFAULT_DURATION)
