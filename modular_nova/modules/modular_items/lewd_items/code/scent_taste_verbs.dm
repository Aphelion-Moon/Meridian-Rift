GAME_VERB_CONTEXT(/mob/living/carbon/human, lick, "Lick", "", "IC", /mob/living/carbon/human)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	if(!istype(target))
		return FALSE
	if(!get_organ_slot(ORGAN_SLOT_TONGUE))
		to_chat(src, span_warning("You don't have a tongue to lick with."))
		return FALSE
	if(!can_use_erp_flavor_verb(target, "doesn't feel like being touched right now."))
		return FALSE

	var/taste = target.dna.features[ERP_FLAVOR_DNA_TASTE]
	if(!taste)
		to_chat(src, span_warning("[target] doesn't seem to have a taste."))
		return FALSE

	to_chat(src, span_notice("[target] tastes like [taste]."))
	to_chat(target, span_notice("[src] licks you."))
	return TRUE

GAME_VERB_CONTEXT(/mob/living/carbon/human, smell, "Smell", "", "IC", /mob/living/carbon/human)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_VIEW, /mob/living/carbon/human)
	if(!istype(target))
		return FALSE
	if(!can_use_erp_flavor_verb(target, "doesn't feel like being approached that close right now."))
		return FALSE
	return smell_human(target)

/// Tells this human what [target] smells like, with any scent a partner left on them.
/mob/living/carbon/human/proc/smell_human(mob/living/carbon/human/target)
	var/scent = target.dna.features[ERP_FLAVOR_DNA_SCENT]
	var/datum/status_effect/scent_transfer/left_on = target.has_status_effect(/datum/status_effect/scent_transfer)
	if(!scent && !left_on)
		to_chat(src, span_warning("[target] doesn't seem to have a smell."))
		return FALSE
	if(!left_on)
		to_chat(src, span_notice("[target] smells like [scent]."))
	else if(!scent)
		to_chat(src, span_notice("[target] carries a trace of [left_on.scent]."))
	else
		to_chat(src, span_notice("[target] smells like [scent], with a trace of [left_on.scent]."))
	return TRUE

/// Leaves this human's scent on [receiver] when this one gives scents and the receiver takes them.
/mob/living/carbon/human/proc/leave_scent_on(mob/living/carbon/human/receiver)
	var/scent = dna.features[ERP_FLAVOR_DNA_SCENT]
	if(!scent || receiver == src)
		return
	var/datum/client_interface/giver_client = GET_CLIENT(src)
	if(!giver_client?.prefs?.read_preference(/datum/preference/toggle/erp/scent_transfer_give))
		return
	var/datum/client_interface/receiver_client = GET_CLIENT(receiver)
	if(!receiver_client?.prefs?.read_preference(/datum/preference/toggle/erp/scent_transfer_receive))
		return
	receiver.apply_status_effect(/datum/status_effect/scent_transfer, scent)

/// A partner's scent, left by a lewd interaction. The newest replaces the last; it fades, or washes off.
/datum/status_effect/scent_transfer
	id = "scent_transfer"
	duration = 20 MINUTES
	status_type = STATUS_EFFECT_REPLACE
	alert_type = null
	/// The scent left behind, as its owner wrote it.
	var/scent

/datum/status_effect/scent_transfer/on_creation(mob/living/new_owner, scent)
	src.scent = scent
	return ..()

/datum/status_effect/scent_transfer/on_apply()
	RegisterSignal(owner, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_washed))
	return TRUE

/datum/status_effect/scent_transfer/on_remove()
	UnregisterSignal(owner, COMSIG_COMPONENT_CLEAN_ACT)

/datum/status_effect/scent_transfer/proc/on_washed(datum/source, clean_types)
	SIGNAL_HANDLER
	if(clean_types & CLEAN_WASH)
		qdel(src)

/mob/living/carbon/human/proc/can_see_erp_flavor(mob/living/carbon/human/target)
	return client?.prefs?.read_preference(/datum/preference/toggle/erp) && target?.client?.prefs?.read_preference(/datum/preference/toggle/erp)

/mob/living/carbon/human/proc/can_use_erp_flavor_verb(mob/living/carbon/human/target, warning_message)
	if(!can_see_erp_flavor(target))
		to_chat(src, span_warning("You need ERP preferences enabled on both characters to do that."))
		return FALSE

	if(HAS_TRAIT(target, TRAIT_QUICKREFLEXES))
		to_chat(src, span_warning("[target] [warning_message]"))
		return FALSE

	return TRUE

/// Returns adjacent humans for the Lick/Smell IC verb target selector.
/mob/living/proc/get_adjacent_humans()
	var/list/nearby_humans = list()
	for(var/mob/living/carbon/human/nearby_human in range(1, src))
		if(nearby_human == src)
			continue
		nearby_humans += nearby_human
	return nearby_humans
