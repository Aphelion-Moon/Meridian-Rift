/mob/living/carbon/human
	/// Medical injury state, independent of the Nova roleplay pain variable.
	var/datum/medical_pain/medical_pain

/datum/species
	/// Independent capacity for medical pain; zero opts the species out.
	var/medical_pain_capacity = MEDICAL_PAIN_CAPACITY

// Organic human bodies feel injury pain; synthetic and nonorganic bodies retain their original impairment.
/mob/living/carbon/human/proc/uses_medical_pain()
	return dna?.species?.medical_pain_capacity > 0 && (mob_biotypes & MOB_ORGANIC) && !(mob_biotypes & MOB_ROBOTIC)

/**
 * Whether injury-driven soft or hard crit is deferred while pain remains bearable.
 *
 * Pure fresh query for the core stat gate: resamples untreated injury minus current
 * bloodstream analgesia without touching stages, medicine, or health. Never recurses
 * because it never recalculates, heals, or damages. Defers only when health is already
 * in crit from injury; physiological-only crit from oxygen plus toxin load or from a
 * missing or failing essential organ never defers. Stock death and trait handling stay
 * in the core gate, and pain above health never knocks out in this pass.
 */
/mob/living/carbon/human/defers_injury_crit()
	if(stat == DEAD)
		return FALSE
	if(HAS_TRAIT(src, TRAIT_GODMODE) || HAS_TRAIT(src, TRAIT_STASIS))
		return FALSE
	if(!uses_medical_pain())
		return FALSE
	if(health > crit_threshold)
		return FALSE
	if((maxHealth - get_oxy_loss() - get_tox_loss()) <= crit_threshold)
		return FALSE
	if(undergoing_cardiac_arrest())
		return FALSE
	if(!HAS_TRAIT(src, TRAIT_BRAINLESS_CARBON))
		var/obj/item/organ/brain/brain = get_organ_slot(ORGAN_SLOT_BRAIN)
		if(isnull(brain) || ((brain.organ_flags & ORGAN_FAILING) && !HAS_TRAIT(brain, TRAIT_BRAIN_DAMAGE_NODEATH)))
			return FALSE
	if(needs_heart())
		var/obj/item/organ/heart/heart = get_organ_slot(ORGAN_SLOT_HEART)
		if(isnull(heart) || (heart.organ_flags & ORGAN_FAILING))
			return FALSE
	if(!HAS_TRAIT(src, TRAIT_NOBREATH))
		var/obj/item/organ/lungs/lungs = get_organ_slot(ORGAN_SLOT_LUNGS)
		if(isnull(lungs) || (lungs.organ_flags & ORGAN_FAILING))
			return FALSE
	if(isnull(medical_pain))
		return FALSE
	var/raw_pain = medical_pain.calculate_raw_pain()
	var/effective_pain = HAS_TRAIT(src, TRAIT_ANALGESIA) ? 0 : max(0, raw_pain - get_medical_pain_relief())
	return (100 * effective_pain / dna.species.medical_pain_capacity) < MEDICAL_PAIN_CRIT_PERCENT

/**
 * Overflow part of a head or chest hit into one present organic internal organ.
 *
 * Caller runs after mitigation and before storing limb damage, using current health
 * to pick the 25 percent softcrit or 50 percent hardcrit
 * share. Additional injury only; normal limb damage still applies and there is no
 * extra chance gate or recursive limb damage. One random candidate from the struck
 * region's explicit slot pool is damaged through the organ setter so thresholds and
 * failure still apply. Applies while unconscious in crit and independent of analgesia.
 * Arguments:
 * * damage_amount - post-mitigation brute plus burn for the actual struck part.
 * * body_zone - body zone of the actual struck part; groin normalizes to chest.
 */
/mob/living/carbon/human/proc/overflow_medical_pain_to_organs(damage_amount, body_zone)
	if(damage_amount <= 0)
		return
	if(stat == DEAD)
		return
	if(HAS_TRAIT(src, TRAIT_GODMODE) || HAS_TRAIT(src, TRAIT_STASIS))
		return
	if(!uses_medical_pain())
		return
	if(health > crit_threshold)
		return
	var/share = health <= hardcrit_threshold ? MEDICAL_PAIN_OVERFLOW_HARD_SHARE : MEDICAL_PAIN_OVERFLOW_SOFT_SHARE
	var/overflow_damage = round(damage_amount * share, DAMAGE_PRECISION)
	if(overflow_damage <= 0)
		return
	var/struck_zone = check_zone(body_zone)
	var/list/slot_pool
	if(struck_zone == BODY_ZONE_HEAD)
		slot_pool = list(ORGAN_SLOT_BRAIN, ORGAN_SLOT_EYES, ORGAN_SLOT_EARS)
	else if(struck_zone == BODY_ZONE_CHEST)
		slot_pool = list(ORGAN_SLOT_HEART, ORGAN_SLOT_LUNGS, ORGAN_SLOT_LIVER, ORGAN_SLOT_STOMACH, ORGAN_SLOT_APPENDIX)
	else
		return
	var/list/candidate_slots = list()
	for(var/slot in slot_pool)
		var/obj/item/organ/candidate = get_organ_slot(slot)
		if(isnull(candidate))
			continue
		if(!(candidate.organ_flags & ORGAN_ORGANIC) || (candidate.organ_flags & ORGAN_ROBOTIC))
			continue
		if(candidate.organ_flags & (ORGAN_EXTERNAL | ORGAN_FAILING))
			continue
		if(candidate.damage >= candidate.maxHealth)
			continue
		if(check_zone(candidate.zone) != struck_zone)
			continue
		candidate_slots += slot
	if(!length(candidate_slots))
		return
	adjust_organ_loss(pick(candidate_slots), overflow_damage, required_organ_flag = ORGAN_ORGANIC)
	// Organ setter never updates health; resample pain and re-evaluate stat without touching pre-hit health.
	medical_pain?.recalculate()

/**
 * Preserve the strongest of physiological damage, exhaustion and pain in the existing modifier.
 * Keeping its type preserves deliberate mobility exemptions from equipment and abilities.
 */
/mob/living/carbon/human/proc/update_medical_pain_slowdown()
	var/health_deficiency = max(maxHealth - health, staminaloss)
	var/pain_slowdown = 0
	if(medical_pain && uses_medical_pain())
		health_deficiency = max(get_oxy_loss() + get_tox_loss(), staminaloss)
		pain_slowdown = medical_pain.stage_slowdowns[medical_pain.stage + 1]
		// Pain relief does not restore mobility to a critically injured body.
		if(health <= hardcrit_threshold && stat != DEAD && !HAS_TRAIT(src, TRAIT_GODMODE) && !HAS_TRAIT(src, TRAIT_STASIS))
			pain_slowdown = max(pain_slowdown, MEDICAL_PAIN_HARDCRIT_SLOWDOWN)
	var/physiological_slowdown = health_deficiency >= MEDICAL_PAIN_DAMAGE_SLOW_THRESHOLD ? health_deficiency / MEDICAL_PAIN_DAMAGE_SLOW_DIVISOR : 0
	var/combined_slowdown = max(pain_slowdown, physiological_slowdown)
	if(combined_slowdown > 0)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/damage_slowdown, TRUE, multiplicative_slowdown = combined_slowdown)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/damage_slowdown)
