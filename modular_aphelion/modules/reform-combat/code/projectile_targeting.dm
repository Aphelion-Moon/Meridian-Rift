/** Tracks failed limb aim so the projectile can pass carbon targets without applying hit effects. */
/obj/projectile
	/// Whether the current impact's failed limb accuracy roll produces a complete miss.
	var/missed_limb_aim = FALSE

/**
 * Resolves the impact zone and records whether failed arm or leg aim should miss entirely.
 *
 * The fallback zone retains the original distribution for other targets and subsequent impacts.
 *
 * Arguments:
 * * accuracy - Percentage chance to hit the selected zone after range and accuracy modifiers.
 */
/obj/projectile/proc/resolve_combat_hit_zone(accuracy)
	missed_limb_aim = FALSE
	var/aimed_zone = check_zone(def_zone)
	switch(aimed_zone)
		if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
			if(prob(accuracy))
				return aimed_zone
			missed_limb_aim = prob(REFORM_COMBAT_LIMB_MISS_CHANCE)
			return ran_zone(def_zone, 0)
	return ran_zone(def_zone, accuracy)

/** Returns whether failed limb aim skips this carbon target, with feedback for unsuppressed shots. */
/obj/projectile/proc/misses_limb_target(atom/target)
	if(!missed_limb_aim || !iscarbon(target))
		return FALSE
	var/mob/living/carbon/carbon_target = target
	if(suppressed == SUPPRESSED_NONE)
		carbon_target.visible_message(
			span_danger("[src] misses [carbon_target]!"),
			span_userdanger("[src] misses you!"),
			null,
			COMBAT_MESSAGE_RANGE,
		)
	return TRUE
