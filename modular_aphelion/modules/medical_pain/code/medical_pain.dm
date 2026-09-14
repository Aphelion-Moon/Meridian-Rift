// Injury-derived medical pain, owned by a human independently of roleplay preferences.
/datum/medical_pain
	/// The patient owns this datum and deletes it before human teardown.
	var/mob/living/carbon/human/patient
	/// Current untreated injury score.
	var/raw_pain = 0
	/// Current score after analgesia.
	var/effective_pain = 0
	/// Capacity copied from stateless species configuration when recalculating.
	var/capacity = MEDICAL_PAIN_CAPACITY
	/// Current symptom stage; zero means no symptoms.
	var/stage = 0
	/// Earliest time another upward transition may occur.
	var/next_stage_change = 0
	/// Percentage thresholds shared by all patients.
	var/static/list/stage_thresholds = list(20, 30, 40, 60, 70, 80)
	/// Patient-facing stage names, indexed by stage plus one.
	var/static/list/stage_names = list("none", "mild", "moderate", "distressing", "severe", "intense", "overwhelming")
	/// Bounded movement penalties indexed by stage plus one.
	var/static/list/stage_slowdowns = list(0, 0, 0.3, 0.8, 1.5, 2.25, MEDICAL_PAIN_MAX_SLOWDOWN)

/datum/medical_pain/New(mob/living/carbon/human/patient)
	..()
	src.patient = patient
	RegisterSignal(patient, COMSIG_LIVING_HEALTHSCAN, PROC_REF(on_healthscan))
	RegisterSignals(patient, list(COMSIG_LIVING_DEATH, SIGNAL_ADDTRAIT(TRAIT_STASIS), COMSIG_SPECIES_LOSS), PROC_REF(on_suspended))
	RegisterSignals(patient, list(COMSIG_LIVING_REVIVE, COMSIG_LIVING_POST_FULLY_HEAL, COMSIG_SPECIES_GAIN, SIGNAL_REMOVETRAIT(TRAIT_STASIS), SIGNAL_ADDTRAIT(TRAIT_ANALGESIA), SIGNAL_REMOVETRAIT(TRAIT_ANALGESIA)), PROC_REF(on_changed))

/datum/medical_pain/Destroy()
	patient = null
	return ..()

// Pure injury query. Does not transition stages, consume medicine, or apply symptoms.
/datum/medical_pain/proc/calculate_raw_pain()
	if(!patient.uses_medical_pain())
		return 0
	var/injury_pain = max(0, patient.get_tox_loss()) * MEDICAL_PAIN_TOXIN_FACTOR
	for(var/obj/item/bodypart/limb as anything in patient.bodyparts)
		injury_pain += limb.get_medical_pain()
	var/organ_pain = 0
	for(var/obj/item/organ/organ as anything in patient.organs)
		organ_pain += organ.get_medical_pain()
	return injury_pain + min(organ_pain, MEDICAL_PAIN_ORGAN_CAP)

/**
 * Sample current injuries and active treatment, recovering promptly with hysteresis.
 * Only life processing advances stages. current_time permits deterministic timing tests.
 * Re-evaluates stat after medicine, organ, or injury changes so deferred crit tracks
 * fresh pain. Safe from recursion because the stat gate only pure-queries raw pain
 * minus relief and never recalculates.
 */
/datum/medical_pain/proc/recalculate(advance_stage = FALSE, current_time = world.time)
	capacity = patient.dna?.species?.medical_pain_capacity > 0 ? patient.dna.species.medical_pain_capacity : MEDICAL_PAIN_CAPACITY
	raw_pain = calculate_raw_pain()
	if(patient.stat == DEAD || HAS_TRAIT(patient, TRAIT_STASIS) || !patient.uses_medical_pain() || HAS_TRAIT(patient, TRAIT_ANALGESIA))
		effective_pain = 0
		set_stage(0)
		next_stage_change = current_time
		patient.update_medical_pain_slowdown()
		update_pain_crit()
		return
	effective_pain = max(0, raw_pain - patient.get_medical_pain_relief())
	var/pain_percent = clamp(100 * effective_pain / capacity, 0, 100)
	var/new_stage = stage
	while(new_stage > 0 && pain_percent < stage_thresholds[new_stage] - MEDICAL_PAIN_RECOVERY_MARGIN)
		new_stage--
	if(new_stage == stage && advance_stage && current_time >= next_stage_change)
		var/stage_limit = min(stage + MEDICAL_PAIN_MAX_STAGE_ADVANCE, length(stage_thresholds))
		while(new_stage < stage_limit && pain_percent >= stage_thresholds[new_stage + 1])
			new_stage++
	if(new_stage != stage)
		set_stage(new_stage)
		next_stage_change = current_time + MEDICAL_PAIN_STAGE_INTERVAL
	// Restore presentation if an external status clear left an untreated injury.
	update_symptoms()
	patient.update_medical_pain_slowdown()
	update_pain_crit()

/** Re-evaluate crit after pain-only changes, including the movement state normally refreshed by updatehealth. */
/datum/medical_pain/proc/update_pain_crit()
	patient.update_stat()
	if(patient.stat == SOFT_CRIT)
		patient.add_movespeed_modifier(/datum/movespeed_modifier/carbon_softcrit)
	else
		patient.remove_movespeed_modifier(/datum/movespeed_modifier/carbon_softcrit)

// Change only the symptom state belonging to medical pain.
/datum/medical_pain/proc/set_stage(new_stage)
	if(stage == new_stage)
		return
	var/old_stage = stage
	stage = new_stage
	update_symptoms()
	if(stage && !old_stage && !IS_UNCONSCIOUS(patient) && patient.stat != DEAD)
		to_chat(patient, span_warning("Your injuries are starting to hurt. Treatment or pain relief can ease the symptoms."))
	else if(stage >= 4 && old_stage < 4 && !IS_UNCONSCIOUS(patient) && patient.stat != DEAD)
		to_chat(patient, span_warning("The pain is making it difficult to move. You need medical attention."))

// Keep a non-processing alert/status only while symptoms exist.
/datum/medical_pain/proc/update_symptoms()
	if(!stage)
		patient.remove_status_effect(/datum/status_effect/medical_pain)
		return
	var/datum/status_effect/medical_pain/symptoms = patient.has_status_effect(/datum/status_effect/medical_pain)
	if(!symptoms)
		symptoms = patient.apply_status_effect(/datum/status_effect/medical_pain)
	symptoms?.update_stage(stage_names[stage + 1])

// Clear symptoms immediately at death, stasis entry, or species loss.
/datum/medical_pain/proc/on_suspended(datum/source)
	SIGNAL_HANDLER
	effective_pain = 0
	set_stage(0)
	next_stage_change = world.time
	patient.update_medical_pain_slowdown()

// Re-evaluate after a completed lifecycle or pain-immunity change without escalating.
/datum/medical_pain/proc/on_changed(datum/source)
	SIGNAL_HANDLER
	recalculate()

// Scanner reads current injury and drug values without changing symptom progression.
/datum/medical_pain/proc/on_healthscan(datum/source, list/render_list, scanpower, mob/user, mode, tochat)
	SIGNAL_HANDLER
	if(!patient.uses_medical_pain() || patient.stat == DEAD)
		return
	var/current_raw = calculate_raw_pain()
	var/current_relief = patient.get_medical_pain_relief()
	var/suppressed = HAS_TRAIT(patient, TRAIT_ANALGESIA) || HAS_TRAIT(patient, TRAIT_STASIS)
	var/current_effective = suppressed ? 0 : max(0, current_raw - current_relief)
	render_list += "<span class='notice'>Estimated pain: [round(clamp(100 * current_effective / capacity, 0, 100))]% of capacity; symptoms: [stage_names[stage + 1]]. Active analgesic relief: [current_relief][suppressed ? " (pain suppressed)" : ""]. Injury treatment is still required.</span><br>"

// Non-processing patient feedback. The human's combined modifier owns movement.
/datum/status_effect/medical_pain
	id = "medical_pain"
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = /atom/movable/screen/alert/status_effect/medical_pain

// Update the alert's text without replacing the status on every life tick.
/datum/status_effect/medical_pain/proc/update_stage(stage_name)
	if(linked_alert)
		linked_alert.name = "Pain: [stage_name]"

/datum/status_effect/medical_pain/get_examine_text(mob/examiner)
	var/mob/living/carbon/human/patient = owner
	if(!IS_UNCONSCIOUS(patient) && patient.stat != DEAD && patient.medical_pain?.stage >= 4)
		return span_warning("[owner] appears to be struggling with severe pain.")
	return null

// Reuses the established injury alert artwork.
/atom/movable/screen/alert/status_effect/medical_pain
	name = "Pain"
	desc = "Injuries are causing pain. Painkillers temporarily ease symptoms; wounds, damaged organs, and open incisions need treatment."
	icon_state = "injury"
