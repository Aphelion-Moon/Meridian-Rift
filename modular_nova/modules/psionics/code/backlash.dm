/**
 * A single bad thing that happens to a psion for running hot.
 *
 * Backlashes are rolled by tier from `try_backlash()` on the profile. Mild fires as a nuisance
 * while strain is elevated, severe as an unambiguous warning to stop, and catastrophic only
 * alongside a full burnout.
 */
/datum/psionic_backlash
	abstract_type = /datum/psionic_backlash
	/// Relative pick weight against the other backlashes in the same tier.
	var/weight = PSIONIC_BACKLASH_WEIGHT_COMMON
	/// TRUE if this backlash owns a timer and deletes itself later. The picker leaves it alone.
	var/lingering = FALSE

/// Extra conditions on top of the tier roll. Return FALSE to make the picker try another backlash.
/datum/psionic_backlash/proc/can_execute(mob/living/psion, datum/component/psionic_profile/profile)
	return TRUE

/// Applies the backlash. Return FALSE if it could not land, and the picker will try another.
/datum/psionic_backlash/proc/execute(mob/living/psion, datum/component/psionic_profile/profile)
	return FALSE

/// Noticeable but not disabling. Enough that an attentive psion knows they are pushing it.
/datum/psionic_backlash/mild
	abstract_type = /datum/psionic_backlash/mild

/// An unambiguous instruction to stop casting and let strain decay.
/datum/psionic_backlash/severe
	abstract_type = /datum/psionic_backlash/severe

/// Rolled only on burnout. Expect a medbay visit.
/datum/psionic_backlash/catastrophic
	abstract_type = /datum/psionic_backlash/catastrophic

GLOBAL_LIST_INIT(psionic_backlash_tiers, list(
	PSIONIC_BACKLASH_MILD = /datum/psionic_backlash/mild,
	PSIONIC_BACKLASH_SEVERE = /datum/psionic_backlash/severe,
	PSIONIC_BACKLASH_CATASTROPHIC = /datum/psionic_backlash/catastrophic,
))

/// Cached weight tables keyed by tier, built on first roll of each tier.
GLOBAL_LIST_EMPTY(psionic_backlash_candidates)

/proc/get_psionic_backlash_candidates(tier)
	RETURN_TYPE(/list)
	if(GLOB.psionic_backlash_candidates[tier])
		return GLOB.psionic_backlash_candidates[tier]

	var/base_type = GLOB.psionic_backlash_tiers[tier]
	if(!base_type)
		return null

	var/list/candidates = list()
	for(var/datum/psionic_backlash/backlash_type as anything in subtypesof(base_type))
		if(initial(backlash_type.abstract_type) == backlash_type)
			continue

		candidates[backlash_type] = initial(backlash_type.weight)

	GLOB.psionic_backlash_candidates[tier] = candidates
	return candidates

/**
 * Rolls one backlash of [tier] onto [psion].
 *
 * Weighted pick, retrying with the remaining candidates whenever one declines to fire, so a tier
 * only fails outright if every backlash in it refuses. Each tier needs at least one backlash that
 * always lands. Returns TRUE if one did.
 */
/proc/roll_psionic_backlash(tier, mob/living/psion, datum/component/psionic_profile/profile)
	if(!istype(psion))
		return FALSE

	var/list/remaining_candidates = get_psionic_backlash_candidates(tier)?.Copy()
	while(length(remaining_candidates))
		var/backlash_type = pick_weight(remaining_candidates)
		remaining_candidates -= backlash_type

		var/datum/psionic_backlash/backlash = new backlash_type
		if(backlash.can_execute(psion, profile) && backlash.execute(psion, profile))
			if(!backlash.lingering)
				qdel(backlash)
			return TRUE

		qdel(backlash)

	return FALSE
