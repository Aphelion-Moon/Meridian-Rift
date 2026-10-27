/**
 * Puts a mess on a person where a shot was aimed (dirt_mess_place()), when the portal shows a zone that lands.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define, from dirt_mess_zones() or DIRT_ZONE_COCK.
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target: a zone it doesn't show takes nothing, and
 *   through a wall only what the relay draws takes the shot.
 * - levels: How many levels it adds, from dirt_mess_amount_levels().
 *
 * Returns whether anything was deposited.
 */
/proc/dirt_mess_land(mob/living/carbon/human/target, zone, portal_view = DIRT_PORTAL_NONE, levels = 1)
	if(!ishuman(target) || QDELETED(target) || !dirt_mess_landable(zone) || !dirt_portal_shows(zone, portal_view))
		return FALSE
	return !!dirt_mess_place(target, zone, levels, portal_view = portal_view)

/**
 * Returns whether dirt_mess_land() lands a shot at a zone: the zones dirt_mess_zones() lists, and DIRT_ZONE_COCK,
 * which dirt_mess_regions() offers through a one-part portal and which lands on the penis alone.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_mess_landable(zone)
	return zone == DIRT_ZONE_COCK || (zone in dirt_mess_zones())

/**
 * Returns whether a portal shows the part of its occupant a zone lies on: through a one-part portal only
 * DIRT_ZONE_COCK, through a wall the groin and the butt (its relay draws no legs), and anything with no portal.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - portal_view: A DIRT_PORTAL_* define.
 */
/proc/dirt_portal_shows(zone, portal_view)
	switch(portal_view)
		if(DIRT_PORTAL_PENIS)
			return zone == DIRT_ZONE_COCK
		if(DIRT_PORTAL_LOWER_BODY)
			return zone == DIRT_ZONE_GROIN || zone == DIRT_ZONE_BUTT
	return TRUE

/**
 * Returns the zones below the waist: the groin, the thighs and the butt. You should NEVER modify it.
 */
/proc/dirt_lower_zones()
	RETURN_TYPE(/list)
	var/static/list/zones = list(DIRT_ZONE_GROIN, DIRT_ZONE_THIGHS, DIRT_ZONE_BUTT)
	return zones

/**
 * Returns how many levels a shot's amount adds where it lands: 1 for a normal shot, 2 for a heavy one, and straight to
 * DIRT_MESS_MAX_LEVEL for a huge one.
 *
 * Arguments:
 * - amount: The fluid the shot spends, in units.
 */
/proc/dirt_mess_amount_levels(amount)
	if(amount >= DIRT_MESS_AMOUNT_HUGE)
		return DIRT_MESS_MAX_LEVEL
	return amount >= DIRT_MESS_AMOUNT_HEAVY ? 2 : 1

/**
 * Puts a mess where a shot at a zone lands on a person (dirt_mess_surface()) as
 * /datum/component/dirtiness/proc/add_mess() does, and on each part drawn over that surface which the zone reaches
 * (dirt_body_parts()), a splat of the same variant in its own slot. A back shot on a taur also puts one in its taur
 * body's slot (dirt_taur_takes_pools()), unless a taur suit takes it, whose own splat draws the pools.
 * DIRT_ZONE_COCK lands on the penis alone, while it draws its front image. Then it takes the oldest splats off past
 * DIRT_MESS_MAX_SPLATS, and only then draws each garment that changed and the person, once, so the masks asked for are
 * the ones kept.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 * - levels: How many levels it adds, or the level of a new splat when a variant is given.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1 for a new splat with that variant, or null to land as a shot does.
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target: through a wall only what its relay draws
 *   takes the shot (dirt_mess_garment()).
 *
 * Returns the splat it started, or the one it raised when it started none, or null when it landed nowhere.
 */
/proc/dirt_mess_place(mob/living/carbon/human/target, zone, levels = 1, variant = null, portal_view = DIRT_PORTAL_NONE)
	RETURN_TYPE(/datum/dirt_splat)
	// carrier -> what of it changed: ORGAN_SLOT_* defines, null for its own surface
	var/list/changed = list()
	var/datum/dirt_splat/splat
	if(zone == DIRT_ZONE_COCK)
		// only a penis drawing its front image can show what lands on it
		if(!dirt_part_drawn(target.get_organ_slot(ORGAN_SLOT_PENIS), target))
			return null
		var/datum/component/dirtiness/own = target.LoadComponent(/datum/component/dirtiness)
		splat = own.add_mess(dirt_part_zone(DIRT_PART_PENIS), ORGAN_SLOT_PENIS, levels, variant, redraw = FALSE)
		changed[own] = list(ORGAN_SLOT_PENIS)
	else
		var/list/surface = dirt_mess_surface(target, zone, portal_view)
		var/datum/component/dirtiness/carrier = surface[1]
		var/piece = surface[2]
		splat = piece ? carrier.add_underclothes_mess(zone, piece, levels, variant, redraw = FALSE) : carrier.add_mess(zone, null, levels, variant, redraw = FALSE)
		if(!splat)
			return null
		changed[carrier] = list(null)
		var/surface_layer = piece ? DIRT_UNDERCLOTHES_LAYER : (isitem(carrier.parent) ? dirt_slot_layer(target.get_slot_by_item(carrier.parent)) : DIRT_SKIN_LAYER)
		for(var/datum/dirt_part_source/part as anything in dirt_body_parts(target))
			if(!part.organ_slot || dirt_part_zone(part.kind) != zone || part.top_layer() >= surface_layer)
				continue
			var/datum/component/dirtiness/own = target.LoadComponent(/datum/component/dirtiness)
			own.add_mess(zone, part.organ_slot, levels, variant, redraw = FALSE, new_variant = splat.variant)
			LAZYOR(changed[own], part.organ_slot)
		// the taur body's back takes broken pools beside the rider's
		if(zone == DIRT_ZONE_BACK && dirt_taur_takes_pools(target, carrier))
			var/datum/component/dirtiness/own = target.LoadComponent(/datum/component/dirtiness)
			own.add_mess(zone, ORGAN_SLOT_EXTERNAL_TAUR, levels, variant, redraw = FALSE, new_variant = splat.variant)
			LAZYOR(changed[own], ORGAN_SLOT_EXTERNAL_TAUR)
	for(var/datum/component/dirtiness/evicted_carrier, slots in dirt_mess_evict(target))
		changed[evicted_carrier] = (changed[evicted_carrier] || list()) | slots
	// the person is drawn once: whole if a part's share changed, as mess_changed() draws a part, else their limbs
	var/redraw_body = NONE
	for(var/datum/component/dirtiness/changed_carrier, slots in changed)
		var/list/changed_slots = slots
		var/own = changed_carrier.parent == target
		for(var/organ_slot in changed_slots)
			changed_carrier.mess_changed(organ_slot, draw = !own)
			if(own)
				redraw_body = organ_slot ? DIRT_REDRAW_SHARE : (redraw_body || DIRT_REDRAW_BODY)
	if(redraw_body == DIRT_REDRAW_SHARE)
		target.update_body()
	else if(redraw_body)
		target.update_body_parts()
	return splat

/**
 * Takes a person's oldest splats off until they carry DIRT_MESS_MAX_SPLATS at most, counting their skin, their parts
 * and their worn items. It draws nothing: the caller draws each carrier it returns, and each part.
 *
 * Arguments:
 * - target: The person.
 *
 * Returns what it took splats off: list(carrier = list of what of it changed, ORGAN_SLOT_* defines or null for its own
 * surface).
 */
/proc/dirt_mess_evict(mob/living/carbon/human/target)
	RETURN_TYPE(/list)
	. = list()
	var/list/carriers = dirt_mess_carriers(target)
	var/total = 0
	for(var/datum/component/dirtiness/carrier as anything in carriers)
		total += carrier.mess_count()
	for(var/turn in 1 to total - DIRT_MESS_MAX_SPLATS)
		var/datum/component/dirtiness/oldest_carrier
		var/datum/dirt_splat/oldest
		for(var/datum/component/dirtiness/carrier as anything in carriers)
			var/datum/dirt_splat/candidate = carrier.oldest_mess()
			if(candidate && (!oldest || candidate.serial < oldest.serial))
				oldest = candidate
				oldest_carrier = carrier
		if(!oldest_carrier)
			break
		var/organ_slot = oldest_carrier.remove_mess(oldest, redraw = FALSE)
		LAZYOR(.[oldest_carrier], list(organ_slot))

/**
 * Returns the carriers of a person's mess: their own, then each worn item's.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_mess_carriers(mob/living/carbon/human/target)
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
 * Returns the zones a shot can be aimed at on a person, in the order they're offered: face, chest, stomach, back,
 * groin, thighs, butt. You should NEVER modify it.
 */
/proc/dirt_mess_zones()
	RETURN_TYPE(/list)
	var/static/list/zones = list(DIRT_ZONE_FACE, DIRT_ZONE_CHEST, DIRT_ZONE_STOMACH, DIRT_ZONE_BACK, DIRT_ZONE_GROIN, DIRT_ZONE_THIGHS, DIRT_ZONE_BUTT)
	return zones

/**
 * Returns the zones a shot on a person can aim at, in dirt_mess_zones() order.
 * - A zone is offered when a limb its shots land on (dirt_aim_zones()) is drawn. A monkey gets none: the zones are laid
 *   out on a human's. Kobolds, a monkey's kin in shape, get theirs: mess draws on them.
 * - A taur gets none below the waist: its legs are hidden, and its groin is the join with the taur body.
 * - Through a portal, only what it shows (dirt_portal_shows()): the groin and the butt, or DIRT_ZONE_COCK alone while
 *   the person's penis draws its front image (dirt_part_drawn()).
 *
 * Arguments:
 * - target: The person.
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target.
 */
/proc/dirt_mess_regions(mob/living/carbon/human/target, portal_view = DIRT_PORTAL_NONE)
	RETURN_TYPE(/list)
	. = list()
	if(portal_view == DIRT_PORTAL_PENIS)
		if(dirt_part_drawn(target.get_organ_slot(ORGAN_SLOT_PENIS), target))
			. += DIRT_ZONE_COCK
		return
	if(target.dna?.species?.type == /datum/species/monkey)
		return
	var/alist/drawn_limbs = alist()
	for(var/zone, limb_kind in dirt_zone_limbs())
		var/obj/item/bodypart/limb = target.get_bodypart(zone)
		if(limb?.drawn_sheet())
			drawn_limbs[limb_kind] = TRUE
	var/list/lower_zones = dirt_lower_zones()
	var/taur = istype(target.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body)
	var/list/aim_zones = dirt_aim_zones()
	for(var/zone in dirt_mess_zones())
		if((taur && (zone in lower_zones)) || !dirt_portal_shows(zone, portal_view))
			continue
		for(var/list/area as anything in aim_zones[zone])
			if(drawn_limbs[area[1]])
				. += zone
				break

/**
 * Returns a zone's entry in a shot's list of where to aim: "On their chest".
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - their: The person's possessive pronoun, as the shooter knows them.
 */
/proc/dirt_mess_entry(zone, their)
	return "On [their] [zone]"
