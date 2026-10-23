/**
 * Puts a shot of semen on a person, where it was aimed. It lands on the skin, and its levels raise the zone's newest
 * splat or start another (/datum/component/dirtiness/proc/add_semen()). Past DIRT_SEMEN_MAX_SPLATS the person's oldest
 * splat goes.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define from dirt_semen_zones().
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target.
 * - levels: How many levels it adds, from dirt_semen_load_levels().
 *
 * Returns whether anything was deposited.
 */
/proc/dirt_semen_land(mob/living/carbon/human/target, zone, portal_view = DIRT_PORTAL_NONE, levels = 1)
	if(!ishuman(target) || QDELETED(target) || !(zone in dirt_semen_zones()))
		return FALSE
	dirt_semen_place(target, zone, levels)
	return TRUE

/**
 * Returns how many levels a climax's load adds where it lands: 1 for a normal load, 2 for a heavy one, and straight to
 * DIRT_SEMEN_MAX_LEVEL for a huge one.
 *
 * Arguments:
 * - load: The fluid the climax spends, in units.
 */
/proc/dirt_semen_load_levels(load)
	if(load >= DIRT_SEMEN_LOAD_HUGE)
		return DIRT_SEMEN_MAX_LEVEL
	return load >= DIRT_SEMEN_LOAD_HEAVY ? 2 : 1

/**
 * Puts semen on a person's skin as /datum/component/dirtiness/proc/add_semen() does, takes the oldest splats off past
 * DIRT_SEMEN_MAX_SPLATS, and only then draws each carrier that changed, once, so the masks asked for are the ones kept.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 * - levels: How many levels it adds, or the level of a new splat when a variant is given.
 * - variant: 0 to DIRT_SEMEN_VARIANTS - 1 for a new splat with that variant, or null to land as a climax does.
 *
 * Returns the splat it started, or the one it raised when it started none.
 */
/proc/dirt_semen_place(mob/living/carbon/human/target, zone, levels = 1, variant = null)
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/component/dirtiness/carrier = target.LoadComponent(/datum/component/dirtiness)
	var/datum/dirt_splat/splat = carrier.add_semen(zone, null, levels, variant, redraw = FALSE)
	var/list/changed = dirt_semen_evict(target)
	changed |= carrier
	for(var/datum/component/dirtiness/changed_carrier as anything in changed)
		changed_carrier.semen_changed()
	return splat

/**
 * Takes a person's oldest splats off until they carry DIRT_SEMEN_MAX_SPLATS at most, counting their skin, their parts and
 * their worn items. It draws nothing: the caller draws each carrier it returns.
 *
 * Arguments:
 * - target: The person.
 *
 * Returns the carriers it took splats off.
 */
/proc/dirt_semen_evict(mob/living/carbon/human/target)
	RETURN_TYPE(/list)
	. = list()
	var/list/carriers = dirt_semen_carriers(target)
	var/total = 0
	for(var/datum/component/dirtiness/carrier as anything in carriers)
		total += carrier.semen_count()
	for(var/turn in 1 to total - DIRT_SEMEN_MAX_SPLATS)
		var/datum/component/dirtiness/oldest_carrier
		var/datum/dirt_splat/oldest
		for(var/datum/component/dirtiness/carrier as anything in carriers)
			var/datum/dirt_splat/candidate = carrier.oldest_semen()
			if(candidate && (!oldest || candidate.serial < oldest.serial))
				oldest = candidate
				oldest_carrier = carrier
		if(!oldest_carrier)
			break
		oldest_carrier.remove_semen(oldest, redraw = FALSE)
		. |= oldest_carrier

/**
 * Returns the carriers of a person's semen: their own, then each worn item's.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_semen_carriers(mob/living/carbon/human/target)
	RETURN_TYPE(/list)
	var/list/carriers = list()
	var/datum/component/dirtiness/own = target.GetComponent(/datum/component/dirtiness)
	if(own)
		carriers += own
	for(var/obj/item/worn as anything in target.get_equipped_items())
		var/datum/component/dirtiness/carrier = worn.GetComponent(/datum/component/dirtiness)
		if(carrier)
			carriers += carrier
	return carriers

/**
 * Returns the zones a shot can be aimed at on a person, in the order they're offered: face, chest, stomach, back, groin,
 * thighs, butt. You should NEVER modify it.
 */
/proc/dirt_semen_zones()
	RETURN_TYPE(/list)
	var/static/list/zones = list(DIRT_ZONE_FACE, DIRT_ZONE_CHEST, DIRT_ZONE_STOMACH, DIRT_ZONE_BACK, DIRT_ZONE_GROIN, DIRT_ZONE_THIGHS, DIRT_ZONE_BUTT)
	return zones
