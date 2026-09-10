/** Applies configured humanoid combat values during initialization, preserving existing health and crit modifiers. */
/mob/living/carbon/human/proc/initialize_combat_reform()
	setMaxHealth(maxHealth + REFORM_COMBAT_MAX_HEALTH - HUMAN_MAXHEALTH)
	crit_threshold += REFORM_COMBAT_SOFT_CRIT_THRESHOLD - HEALTH_THRESHOLD_CRIT
	hardcrit_threshold += REFORM_COMBAT_HARD_CRIT_THRESHOLD - HEALTH_THRESHOLD_FULLCRIT
	max_stamina = REFORM_COMBAT_MAX_STAMINA
	updatehealth()

/** Returns stamina damage needed for incapacitation, retaining the original behavior for non-humanoids. */
/mob/living/proc/get_stamina_crit_threshold()
	return maxHealth - crit_threshold

/** Returns the configured humanoid stamina incapacitation threshold, retaining runtime crit modifiers such as mood. */
/mob/living/carbon/human/get_stamina_crit_threshold()
	return REFORM_COMBAT_STAMINA_CRIT_THRESHOLD - (crit_threshold - REFORM_COMBAT_SOFT_CRIT_THRESHOLD)
