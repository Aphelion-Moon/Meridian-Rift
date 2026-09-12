/// How long bleeding eyes leaves the psion red-blind.
#define PSIONIC_EYE_BLEED_BLIND_TIME (6 SECONDS)
/// Tiles a telekinetic backlash flings loose objects across.
#define PSIONIC_TK_BACKLASH_RANGE 4

// Mild ---------------------------------------------------------------------------------------

/// The tier's guaranteed fallback: a mood hit needs nothing from the psion's body.
/datum/psionic_backlash/mild/headache

/datum/psionic_backlash/mild/headache/execute(mob/living/psion, datum/component/psionic_profile/profile)
	psion.add_mood_event("psionic_backlash", /datum/mood_event/psionic_headache)
	to_chat(psion, span_danger("A splitting headache blooms behind your eyes."))
	return TRUE

/datum/mood_event/psionic_headache
	description = "Pushing my gift too hard has given me a splitting headache."
	mood_change = -3
	timeout = 2 MINUTES

/datum/psionic_backlash/mild/nosebleed

/datum/psionic_backlash/mild/nosebleed/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	if(!psion.can_bleed())
		return FALSE

	return !!psion.get_bodypart(BODY_ZONE_HEAD)

/datum/psionic_backlash/mild/nosebleed/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/obj/item/bodypart/head/head = psion.get_bodypart(BODY_ZONE_HEAD)
	head.adjustBleedStacks(5)
	psion.visible_message(
		span_warning("[psion]'s nose starts to bleed."),
		span_danger("Your nose starts to bleed."),
	)
	return TRUE

/datum/psionic_backlash/mild/dizziness

/datum/psionic_backlash/mild/dizziness/execute(mob/living/psion, datum/component/psionic_profile/profile)
	psion.adjust_dizzy(20 SECONDS)
	to_chat(psion, span_warning("The deck tilts under you."))
	return TRUE

/datum/psionic_backlash/mild/twitching

/datum/psionic_backlash/mild/twitching/execute(mob/living/psion, datum/component/psionic_profile/profile)
	psion.adjust_jitter(20 SECONDS)
	psion.visible_message(
		span_warning("[psion] starts twitching."),
		span_danger("Your hands will not hold still."),
	)
	return TRUE

// Severe -------------------------------------------------------------------------------------

/// The tier's guaranteed fallback.
/datum/psionic_backlash/severe/exhaustion

/datum/psionic_backlash/severe/exhaustion/execute(mob/living/psion, datum/component/psionic_profile/profile)
	psion.apply_damage(50, STAMINA)
	psion.adjust_dizzy(30 SECONDS)
	psion.visible_message(
		span_warning("[psion] sags, suddenly exhausted."),
		span_userdanger("The strength goes out of your limbs all at once."),
	)
	return TRUE

/datum/psionic_backlash/severe/eyes_bleed
	lingering = TRUE

/datum/psionic_backlash/severe/eyes_bleed/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	if(!iscarbon(psion) || !psion.can_bleed())
		return FALSE

	var/mob/living/carbon/carbon_psion = psion
	return !!carbon_psion.get_organ_slot(ORGAN_SLOT_EYES)

/datum/psionic_backlash/severe/eyes_bleed/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/mob/living/carbon/carbon_psion = psion
	var/obj/item/organ/eyes/eyes = carbon_psion.get_organ_slot(ORGAN_SLOT_EYES)
	eyes.apply_organ_damage(15)

	var/obj/item/bodypart/head/head = carbon_psion.get_bodypart(BODY_ZONE_HEAD)
	head?.adjustBleedStacks(10)

	psion.visible_message(
		span_warning("[psion] begins to bleed from the eyes!"),
		span_userdanger("Blood wells up and seeps out of your eyes!"),
	)
	psion.become_nearsighted(REF(src))
	psion.add_client_colour(/datum/client_colour/psionic_eyes_bleed, REF(src))
	addtimer(CALLBACK(src, PROC_REF(clear_blinding), psion), PSIONIC_EYE_BLEED_BLIND_TIME)
	return TRUE

/datum/psionic_backlash/severe/eyes_bleed/proc/clear_blinding(mob/living/psion)
	if(!QDELETED(psion))
		psion.cure_nearsighted(REF(src))
		psion.remove_client_colour(REF(src))
	qdel(src)

/datum/client_colour/psionic_eyes_bleed
	priority = CLIENT_COLOR_IMPORTANT_PRIORITY
	color = COLOR_RED
	fade_in = 1
	fade_out = 1

/datum/psionic_backlash/severe/vomit

/datum/psionic_backlash/severe/vomit/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	return iscarbon(psion)

/datum/psionic_backlash/severe/vomit/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/mob/living/carbon/carbon_psion = psion
	to_chat(psion, span_userdanger("Your stomach turns inside out."))
	carbon_psion.vomit(VOMIT_CATEGORY_DEFAULT, distance = 2)
	return TRUE

/datum/psionic_backlash/severe/hallucinate
	weight = PSIONIC_BACKLASH_WEIGHT_UNCOMMON

/datum/psionic_backlash/severe/hallucinate/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	return iscarbon(psion)

/datum/psionic_backlash/severe/hallucinate/execute(mob/living/psion, datum/component/psionic_profile/profile)
	psion.adjust_hallucinations(60 SECONDS)
	to_chat(psion, span_userdanger("Thoughts that are not yours crowd in at the edges."))
	return TRUE

// Catastrophic -------------------------------------------------------------------------------

/// The tier's guaranteed fallback.
/datum/psionic_backlash/catastrophic/telekinetic_backlash

/datum/psionic_backlash/catastrophic/telekinetic_backlash/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/turf/epicentre = get_turf(psion)
	if(!epicentre)
		return FALSE

	psion.visible_message(
		span_boldwarning("Space bucks and heaves around [psion]!"),
		span_userdanger("Everything you were holding onto tears loose at once!"),
	)
	for(var/atom/movable/loose_atom in range(PSIONIC_TK_BACKLASH_RANGE, epicentre))
		if(loose_atom == psion || loose_atom.anchored || !loose_atom.has_gravity())
			continue
		if(!isitem(loose_atom) && !isliving(loose_atom))
			continue

		var/throw_target = get_edge_target_turf(loose_atom, get_dir(epicentre, loose_atom))
		loose_atom.safe_throw_at(throw_target, PSIONIC_TK_BACKLASH_RANGE, 2, psion)

	playsound(epicentre, 'sound/effects/gravhit.ogg', 75, TRUE)
	return TRUE

/datum/psionic_backlash/catastrophic/brain_trauma
	weight = PSIONIC_BACKLASH_WEIGHT_UNCOMMON

/datum/psionic_backlash/catastrophic/brain_trauma/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	return iscarbon(psion)

/datum/psionic_backlash/catastrophic/brain_trauma/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/mob/living/carbon/carbon_psion = psion
	if(!carbon_psion.gain_trauma_type(BRAIN_TRAUMA_SEVERE, TRAUMA_RESILIENCE_SURGERY))
		return FALSE

	to_chat(psion, span_userdanger("Something in your head tears, and does not close again."))
	return TRUE

/datum/psionic_backlash/catastrophic/cardiac_arrest
	weight = PSIONIC_BACKLASH_WEIGHT_RARE

/datum/psionic_backlash/catastrophic/cardiac_arrest/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	if(!iscarbon(psion))
		return FALSE

	var/mob/living/carbon/carbon_psion = psion
	return carbon_psion.can_heartattack() && !carbon_psion.undergoing_cardiac_arrest()

/datum/psionic_backlash/catastrophic/cardiac_arrest/execute(mob/living/psion, datum/component/psionic_profile/profile)
	var/mob/living/carbon/carbon_psion = psion
	if(!carbon_psion.set_heartattack(TRUE))
		return FALSE

	psion.visible_message(
		span_boldwarning("[psion] clutches at their chest and collapses!"),
		span_userdanger("Your heart stops."),
	)
	return TRUE

// Admin --------------------------------------------------------------------------------------

/// Exposes each backlash to the smite menu, so the tiers can be tested without grinding strain.
/datum/smite/psionic_backlash
	/// The backlash this smite fires.
	var/backlash_type

/datum/smite/psionic_backlash/effect(client/user, mob/living/target)
	var/datum/psionic_backlash/backlash = new backlash_type
	var/datum/component/psionic_profile/profile = target.get_psionic_profile()

	if(!backlash.can_execute(target, profile) || !backlash.execute(target, profile))
		to_chat(user, span_warning("[name] could not land on [target]."))
		qdel(backlash)
		return

	. = ..()

	if(!backlash.lingering)
		qdel(backlash)

/datum/smite/psionic_backlash/headache
	name = "Psionic Backlash: Headache"
	backlash_type = /datum/psionic_backlash/mild/headache

/datum/smite/psionic_backlash/nosebleed
	name = "Psionic Backlash: Nosebleed"
	backlash_type = /datum/psionic_backlash/mild/nosebleed

/datum/smite/psionic_backlash/dizziness
	name = "Psionic Backlash: Dizziness"
	backlash_type = /datum/psionic_backlash/mild/dizziness

/datum/smite/psionic_backlash/twitching
	name = "Psionic Backlash: Twitching"
	backlash_type = /datum/psionic_backlash/mild/twitching

/datum/smite/psionic_backlash/exhaustion
	name = "Psionic Backlash: Exhaustion"
	backlash_type = /datum/psionic_backlash/severe/exhaustion

/datum/smite/psionic_backlash/eyes_bleed
	name = "Psionic Backlash: Bleeding Eyes"
	backlash_type = /datum/psionic_backlash/severe/eyes_bleed

/datum/smite/psionic_backlash/vomit
	name = "Psionic Backlash: Vomiting"
	backlash_type = /datum/psionic_backlash/severe/vomit

/datum/smite/psionic_backlash/hallucinate
	name = "Psionic Backlash: Hallucination"
	backlash_type = /datum/psionic_backlash/severe/hallucinate

/datum/smite/psionic_backlash/telekinetic_backlash
	name = "Psionic Backlash: Telekinetic Backlash"
	backlash_type = /datum/psionic_backlash/catastrophic/telekinetic_backlash

/datum/smite/psionic_backlash/brain_trauma
	name = "Psionic Backlash: Brain Trauma"
	backlash_type = /datum/psionic_backlash/catastrophic/brain_trauma

/datum/smite/psionic_backlash/cardiac_arrest
	name = "Psionic Backlash: Cardiac Arrest"
	backlash_type = /datum/psionic_backlash/catastrophic/cardiac_arrest

#undef PSIONIC_EYE_BLEED_BLIND_TIME
#undef PSIONIC_TK_BACKLASH_RANGE
