/// Burns contribute more pain than an equal amount of stored brute damage.
#define MEDICAL_PAIN_BURN_FACTOR 1.2
/// Persistent surcharge for a moderate wound or incision.
#define MEDICAL_PAIN_WOUND_MODERATE 5
/// Persistent surcharge for a severe wound or opened incision.
#define MEDICAL_PAIN_WOUND_SEVERE 15
/// Persistent surcharge for a critical wound or operated bone/organ.
#define MEDICAL_PAIN_WOUND_CRITICAL 25
/// Maximum contribution from one damaged major organ.
#define MEDICAL_PAIN_MAJOR_ORGAN 20
/// Maximum contribution from one damaged sensory organ.
#define MEDICAL_PAIN_SENSORY_ORGAN 10

/*
 * Calculate current local injury pain without changing the limb or its wounds.
 * Stored damage is deliberately unweighted by body_damage_coeff. Only the strongest
 * wound or surgery surcharge applies, so an open fracture does not count twice.
 */
/obj/item/bodypart/proc/get_medical_pain()
	if(!IS_ORGANIC_LIMB(src) || IS_STUMP(src))
		return 0

	var/injury_surcharge = 0
	for(var/datum/wound/wound as anything in wounds)
		injury_surcharge = max(injury_surcharge, wound.get_medical_pain())

	// Reported states exclude innate anatomy and surgery states supplied by wounds.
	var/reported_state = get_reported_surgery_state()
	if(HAS_ANY_SURGERY_STATE(reported_state, SURGERY_SKIN_CUT))
		injury_surcharge = max(injury_surcharge, MEDICAL_PAIN_WOUND_MODERATE)
	if(HAS_ANY_SURGERY_STATE(reported_state, SURGERY_SKIN_OPEN))
		injury_surcharge = max(injury_surcharge, MEDICAL_PAIN_WOUND_SEVERE)
	if(HAS_ANY_SURGERY_STATE(reported_state, SURGERY_BONE_SAWED|SURGERY_BONE_DRILLED|SURGERY_ORGANS_CUT))
		injury_surcharge = max(injury_surcharge, MEDICAL_PAIN_WOUND_CRITICAL)

	return max(0, brute_dam) + MEDICAL_PAIN_BURN_FACTOR * max(0, burn_dam) + injury_surcharge

// Return persistent wound pain independently of the limb's remaining brute/burn damage.
/datum/wound/proc/get_medical_pain()
	switch(severity)
		if(WOUND_SEVERITY_MODERATE)
			return MEDICAL_PAIN_WOUND_MODERATE
		if(WOUND_SEVERITY_SEVERE)
			return MEDICAL_PAIN_WOUND_SEVERE
		if(WOUND_SEVERITY_CRITICAL)
			return MEDICAL_PAIN_WOUND_CRITICAL
	return 0

// Existing splints reduce fracture pain immediately without repairing the fracture.
/datum/wound/blunt/bone/get_medical_pain()
	return ..() * (limb ? limb.get_splint_factor() : 1)

/obj/item/organ
	/// Pain at the organ's severe damage threshold; zero excludes cosmetic organs and implants.
	var/max_medical_pain = 0

// Return bounded pain scaled to this organ's severe damage threshold.
/obj/item/organ/proc/get_medical_pain()
	if(!IS_ORGANIC_ORGAN(src) || IS_ROBOTIC_ORGAN(src) || max_medical_pain <= 0 || high_threshold <= 0)
		return 0
	return max_medical_pain * clamp(damage / high_threshold, 0, 1)

/obj/item/organ/heart
	max_medical_pain = MEDICAL_PAIN_MAJOR_ORGAN

/obj/item/organ/lungs
	max_medical_pain = MEDICAL_PAIN_MAJOR_ORGAN

/obj/item/organ/liver
	max_medical_pain = MEDICAL_PAIN_MAJOR_ORGAN

/obj/item/organ/stomach
	max_medical_pain = MEDICAL_PAIN_MAJOR_ORGAN

/obj/item/organ/appendix
	max_medical_pain = MEDICAL_PAIN_MAJOR_ORGAN

/obj/item/organ/eyes
	max_medical_pain = MEDICAL_PAIN_SENSORY_ORGAN

/obj/item/organ/ears
	max_medical_pain = MEDICAL_PAIN_SENSORY_ORGAN

/**
 * Forward post-mitigation limb damage for possible head or chest organ overflow.
 *
 * Called from the limb damage hook after armor, config, limb, wound, and physiology
 * mitigation and before limb capping, so saturated limbs still overflow. Uses owner
 * health before this limb's damage is stored. Forwards the actual struck part only;
 * region filtering and eligibility live on the human overflow proc. Causes no limb
 * damage itself and never recurses into limb damage.
 * Arguments:
 * * damage_amount - post-mitigation brute plus burn for this part.
 */
/obj/item/bodypart/proc/apply_medical_pain_overflow(damage_amount)
	if(damage_amount <= 0)
		return
	if(isnull(owner))
		return
	if(!ishuman(owner))
		return
	var/mob/living/carbon/human/human_owner = owner
	human_owner.overflow_medical_pain_to_organs(damage_amount, body_zone)

#undef MEDICAL_PAIN_BURN_FACTOR
#undef MEDICAL_PAIN_WOUND_MODERATE
#undef MEDICAL_PAIN_WOUND_SEVERE
#undef MEDICAL_PAIN_WOUND_CRITICAL
#undef MEDICAL_PAIN_MAJOR_ORGAN
#undef MEDICAL_PAIN_SENSORY_ORGAN
