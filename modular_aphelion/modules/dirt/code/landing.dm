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
 * DIRT_MAX_SPLATS, and only then draws each garment that changed and the person, once, so the masks asked for are
 * the ones kept.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 * - levels: How many levels it adds, or the level of a new splat when a variant is given.
 * - variant: 0 to DIRT_VARIANTS - 1 for a new splat with that variant, or null to land as a shot does.
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
	dirt_draw_landing(target, changed)
	return splat

/**
 * Takes the oldest splats off a person past the cap (dirt_evict()), then draws each carrier a landing changed and the
 * person once, so the masks asked for are the ones kept. The person is drawn whole if a part's share changed, as
 * mess_changed() draws a part, and else only their limbs.
 *
 * Arguments:
 * - target: The person.
 * - changed: list(carrier = list of what of it changed, ORGAN_SLOT_* defines or null for its own surface), added to.
 */
/proc/dirt_draw_landing(mob/living/carbon/human/target, list/changed)
	for(var/datum/component/dirtiness/evicted_carrier, slots in dirt_evict(target))
		changed[evicted_carrier] = (changed[evicted_carrier] || list()) | slots
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

/**
 * Takes a person's oldest splats off until they carry DIRT_MAX_SPLATS at most, mess and general deposits together,
 * counting their skin, their underclothes, their parts and their worn items. It draws nothing. The caller draws each
 * carrier it returns, and each part.
 *
 * Arguments:
 * - target: The person.
 *
 * Returns what it took splats off: list(carrier = list of what of it changed, ORGAN_SLOT_* defines or null for its own
 * surface).
 */
/proc/dirt_evict(mob/living/carbon/human/target)
	RETURN_TYPE(/list)
	. = list()
	var/list/carriers = dirt_carriers(target)
	var/total = 0
	for(var/datum/component/dirtiness/carrier as anything in carriers)
		total += carrier.mess_count()
	for(var/turn in 1 to total - DIRT_MAX_SPLATS)
		var/datum/component/dirtiness/oldest_carrier
		var/datum/dirt_splat/oldest
		for(var/datum/component/dirtiness/carrier as anything in carriers)
			var/datum/dirt_splat/candidate = carrier.oldest_mess()
			if(candidate && (!oldest || candidate.last_serial < oldest.last_serial))
				oldest = candidate
				oldest_carrier = carrier
		if(!oldest_carrier)
			break
		var/organ_slot = oldest_carrier.remove_mess(oldest, redraw = FALSE)
		LAZYOR(.[oldest_carrier], list(organ_slot))

/**
 * Returns the carriers of a person's splats: their own, then each worn item's, suit storage's included.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_carriers(mob/living/carbon/human/target)
	RETURN_TYPE(/list)
	var/list/carriers = list()
	var/datum/component/dirtiness/own = target.GetComponent(/datum/component/dirtiness)
	if(own)
		carriers += own
	var/list/worn_items = target.get_equipped_items()
	// get_equipped_items() leaves suit storage out with the pockets, though suit storage is drawn
	if(target.s_store)
		worn_items += target.s_store
	for(var/obj/item/worn as anything in worn_items)
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
	var/drawn_limbs = dirt_drawn_limbs(target)
	var/list/lower_zones = dirt_lower_zones()
	var/taur = istype(target.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body)
	var/list/aim_zones = dirt_aim_zones()
	for(var/zone in dirt_mess_zones())
		if((taur && (zone in lower_zones)) || !dirt_portal_shows(zone, portal_view))
			continue
		for(var/list/area as anything in aim_zones[zone])
			if(drawn_limbs & DIRT_LIMB_BIT(area[1]))
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

/**
 * Puts a cause's dirt in a material on a person. Each carrier that shows on a limb the cause reaches
 * (dirt_cause_reach(), dirt_shown_carriers()) takes the deposit for those limbs. The carriers are worn items,
 * underclothes and the skin, which takes only the limbs it draws. They share one variant and the person's dirtier side,
 * so the deposit's lines meet across them. The sweat cause and a wet material never land on bare skin or underwear. A
 * taur's lower half takes what reaches the legs it stands in place of. If it wears a taur suit, the suit takes that,
 * else its taur body does. The suit takes it on every limb the cause reaches, so a biped wearing it draws them all. On
 * the taur, its hem band draws it. Its upper part draws it over the rider too, all but the legs' share of walking,
 * crawling and dust. The hem band draws that share as the taur body's coat. That upper part also takes what reaches
 * the rider alone, as any garment does. The person's tail, wings, ears, horns and other drawn parts take what their own
 * rules take, each while it's drawn (dirt_shape_slots()). Their hair takes what reaches the hair while it shows
 * (dirt_hair_takes()), and a hat that hides it takes that as a worn item. A carrier holding the same cause and material
 * raises that deposit instead (/datum/component/dirtiness/proc/add_dirt()). Then it takes the oldest splats off past
 * DIRT_MAX_SPLATS and draws what changed, once.
 *
 * Arguments:
 * - target: The person.
 * - cause: A DIRT_CAUSE_* define, but not mess's, because mess lands where it's aimed (dirt_mess_land()).
 * - material: A DIRT_MATERIAL_* define other than DIRT_MATERIAL_MESS and DIRT_MATERIAL_BLOOD, or a splat's material
 *   ("slime#RRGGBB").
 * - level: The deposit's level, kept to 1 up to the cause's top (dirt_cause_max_level()).
 * - variant: 0 to DIRT_VARIANTS - 1, or null for one at random.
 * - colour: Slime's colour, "#RRGGBB", with DIRT_MATERIAL_SLIME.
 *
 * Returns how many carriers it landed on.
 */
/proc/dirt_land(mob/living/carbon/human/target, cause, material, level = 1, variant = null, colour = null)
	if(!ishuman(target) || QDELETED(target) || !istext(cause) || !dirt_cause_procs()[cause] || !isnum(level))
		return 0
	// validated and keyed as a splat stores it, so one material never splits by its colour's case
	var/datum/dirt_material/made = dirt_material(material, colour)
	if(!made || made.id == DIRT_MATERIAL_MESS || made.id == DIRT_MATERIAL_BLOOD)
		return 0
	level = clamp(floor(level), 1, dirt_cause_max_level(cause))
	variant = isnum(variant) ? clamp(floor(variant), 0, DIRT_VARIANTS - 1) : rand(0, DIRT_VARIANTS - 1)
	var/reach = dirt_cause_reach(cause, made)
	// sweat and wet materials keep off bare skin and underwear, which draws general dirt as skin does
	var/cloth_only = (made.flags & DIRT_MATERIAL_WET) || cause == DIRT_CAUSE_SWEAT
	var/datum/component/dirtiness/own = target.LoadComponent(/datum/component/dirtiness)
	// carrier -> what of it changed, as dirt_draw_landing() takes it
	var/list/changed = list()
	var/landed = 0
	var/obj/item/taur_suit = dirt_taur_suit(target)
	// a taur suit taking the taur body's dirt as its hem band takes it once, below, on more limbs than it shows on here
	var/hem = taur_suit && dirt_taur_takes(cause, made)
	for(var/carrier, shown in dirt_shown_carriers(target))
		var/limbs = shown & reach
		if(carrier == DIRT_CARRIER_SKIN)
			if(cloth_only)
				continue
			limbs &= dirt_drawn_limbs(target)
		if(!limbs || (hem && carrier == taur_suit))
			continue
		if(isitem(carrier))
			var/obj/item/worn = carrier
			var/datum/component/dirtiness/item_carrier = worn.LoadComponent(/datum/component/dirtiness)
			item_carrier.add_dirt(cause, made.key, level, limbs, variant)
			changed[item_carrier] = list(null)
		else if(carrier == DIRT_CARRIER_SKIN)
			own.add_dirt(cause, made.key, level, limbs, variant)
			changed[own] = list(null)
		else
			var/piece = dirt_underclothes_piece(carrier)
			if((cloth_only && piece == DIRT_UNDERCLOTHES_UNDERWEAR) || !own.add_underclothes_dirt(piece, cause, made.key, level, limbs, variant))
				continue
			changed[own] = list(null)
		landed++
	// on every limb the cause reaches, for when a biped wears it
	if(hem)
		var/datum/component/dirtiness/suit_carrier = taur_suit.LoadComponent(/datum/component/dirtiness)
		suit_carrier.add_dirt(cause, made.key, level, reach, variant)
		changed[suit_carrier] = list(null)
		landed++
	for(var/organ_slot in dirt_shape_slots(target, cause, made, !!taur_suit))
		own.add_dirt(cause, made.key, level, NONE, variant, organ_slot = organ_slot)
		LAZYOR(changed[own], organ_slot)
		landed++
	if(dirt_hair_takes(target, cause, made))
		own.add_dirt(cause, made.key, level, NONE, variant, organ_slot = DIRT_CARRIER_HAIR)
		LAZYOR(changed[own], DIRT_CARRIER_HAIR)
		landed++
	dirt_draw_landing(target, changed)
	return landed

/**
 * Returns the limbs a person draws, DIRT_LIMB_BIT() of each: those with a sprite of their own (drawn_sheet()), so a
 * missing arm or a taur's hidden legs take no skin dirt.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_drawn_limbs(mob/living/carbon/human/target)
	. = NONE
	for(var/zone, limb_kind in dirt_zone_limbs())
		var/obj/item/bodypart/limb = target.get_bodypart(zone)
		if(limb?.drawn_sheet())
			. |= DIRT_LIMB_BIT(limb_kind)

/**
 * Returns the limbs a general cause's dirt in a material can lie on, DIRT_LIMB_BIT() of each, or NONE for a cause that
 * isn't one. They're the union of what the reference generator's deposits of the cause draw on the plain human
 * template. The union takes in every general material of the material's shape class
 * (/datum/dirt_material/proc/shape_class()). It covers every level, variant and side, on cloth, skin and a bare body's
 * painted designs. Materials alike in shape reach the same limbs, and a halo reaches further. Wear and sweat reach the
 * head only in a material with a halo. The two tables below are written from the reference generator.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its material.
 */
/proc/dirt_cause_reach(cause, datum/dirt_material/material)
	// each cause's commonest reach over its materials' shape classes
	var/static/alist/reach = alist(
		DIRT_CAUSE_FALL = DIRT_LIMBS_ALL,
		DIRT_CAUSE_SPLASH = DIRT_LIMBS_ALL,
		DIRT_CAUSE_WALK = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_KNEEL = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_CRAWL = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_MACHINE = DIRT_LIMBS_ALL,
		DIRT_CAUSE_SMOKE = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		DIRT_CAUSE_DUST = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_WEAR = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_PLUNGE = DIRT_LIMBS_ALL,
		DIRT_CAUSE_BLAST = DIRT_LIMBS_ALL,
		DIRT_CAUSE_DOUSE = DIRT_LIMBS_ALL,
		DIRT_CAUSE_SWEAT = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		DIRT_CAUSE_SLIMED = DIRT_LIMBS_ALL,
		DIRT_CAUSE_SLIMED_HEAD = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM),
		DIRT_CAUSE_SLIMED_CHEST = DIRT_LIMBS_ALL,
		DIRT_CAUSE_SLIMED_BACK = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		DIRT_CAUSE_SLIMED_R_ARM = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM),
		DIRT_CAUSE_SLIMED_L_ARM = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		DIRT_CAUSE_SLIMED_R_LEG = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		DIRT_CAUSE_SLIMED_L_LEG = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
	)
	// "cause|shape class" = its reach, where it differs from the cause's commonest reach
	var/static/alist/class_reach = alist(
		"walk|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"walk|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"wear|e1f1" = DIRT_LIMBS_ALL,
		"wear|e1f9" = DIRT_LIMBS_ALL,
		"sweat|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"sweat|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"slimed|e0f6" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_head|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"slimed_head|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"slimed_chest|e0f6" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG),
		"slimed_back|e1f1" = DIRT_LIMBS_ALL,
		"slimed_back|e0f6" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"slimed_back|e1f9" = DIRT_LIMBS_ALL,
		"slimed_r_arm|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG),
		"slimed_r_arm|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG),
		"slimed_l_arm|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_l_arm|e0f6" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		"slimed_l_arm|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_HEAD) | DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_r_leg|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_r_leg|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_L_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_l_leg|e1f1" = DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		"slimed_l_leg|e1f9" = DIRT_LIMB_BIT(DIRT_LIMB_R_ARM) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
	)
	if(material)
		var/other = class_reach["[cause]|[material.shape_class(cause)]"]
		if(!isnull(other))
			return other
	return reach[cause] || NONE
