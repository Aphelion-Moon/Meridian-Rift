/mob/living/carbon/human
	/// Medical injury state, independent of the Nova roleplay pain variable.
	var/datum/medical_pain/medical_pain

/datum/species
	/// Independent capacity for medical pain; zero opts the species out.
	var/medical_pain_capacity = MEDICAL_PAIN_CAPACITY

// Organic human bodies feel injury pain; synthetic and nonorganic bodies retain their original impairment.
/mob/living/carbon/human/proc/uses_medical_pain()
	return dna?.species?.medical_pain_capacity > 0 && (mob_biotypes & MOB_ORGANIC) && !(mob_biotypes & MOB_ROBOTIC)

/*
 * Preserve the strongest of physiological damage, exhaustion and pain in the existing modifier.
 * Keeping its type preserves deliberate mobility exemptions from equipment and abilities.
 */
/mob/living/carbon/human/proc/update_medical_pain_slowdown()
	var/health_deficiency = max(maxHealth - health, staminaloss)
	var/pain_slowdown = 0
	if(medical_pain && uses_medical_pain())
		health_deficiency = max(get_oxy_loss() + get_tox_loss(), staminaloss)
		pain_slowdown = medical_pain.stage_slowdowns[medical_pain.stage + 1]
	var/physiological_slowdown = health_deficiency >= MEDICAL_PAIN_DAMAGE_SLOW_THRESHOLD ? health_deficiency / MEDICAL_PAIN_DAMAGE_SLOW_DIVISOR : 0
	var/combined_slowdown = max(pain_slowdown, physiological_slowdown)
	if(combined_slowdown > 0)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/damage_slowdown, TRUE, multiplicative_slowdown = combined_slowdown)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/damage_slowdown)
