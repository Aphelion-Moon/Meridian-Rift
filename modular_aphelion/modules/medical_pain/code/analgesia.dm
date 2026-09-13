/** Finite symptom relief supplied only while this reagent is metabolizing. */
/datum/reagent
	/// Pain points suppressed; multiple drugs use the strongest value, never their sum.
	var/medical_pain_relief = 0
	/// Whether this reagent provides sufficient numbing for surgery and fracture handling.
	var/surgical_analgesia = FALSE

/** Returns the strongest active bloodstream analgesic, excluding stomach contents and stopped metabolism. */
/mob/living/proc/get_medical_pain_relief()
	var/strongest_relief = 0
	for(var/datum/reagent/medicine as anything in reagents?.reagent_list)
		if(is_medical_analgesic_active(medicine))
			strongest_relief = max(strongest_relief, medicine.medical_pain_relief)
	return strongest_relief

/** Checks deliberate pain immunity or active surgical-strength medication without consuming it. */
/mob/living/proc/has_surgical_analgesia()
	if(HAS_TRAIT(src, TRAIT_ANALGESIA))
		return TRUE
	for(var/datum/reagent/medicine as anything in reagents?.reagent_list)
		if(medicine.surgical_analgesia && is_medical_analgesic_active(medicine))
			return TRUE
	return FALSE

/**
 * Checks active metabolism without granting relief from paused or liver-blocked chemicals.
 * The holder starts metabolism before checking liverless processing, so its flag alone is insufficient.
 */
/mob/living/proc/is_medical_analgesic_active(datum/reagent/medicine)
	if(!medicine.metabolizing || stat == DEAD || HAS_TRAIT(src, TRAIT_STASIS))
		return FALSE
	if(iscarbon(src) && !medicine.self_consuming)
		var/mob/living/carbon/patient = src
		var/obj/item/organ/liver/liver = patient.get_organ_slot(ORGAN_SLOT_LIVER)
		if(!liver || (liver.organ_flags & ORGAN_FAILING) || HAS_TRAIT(patient, TRAIT_LIVERLESS_METABOLISM))
			return FALSE
	return TRUE
