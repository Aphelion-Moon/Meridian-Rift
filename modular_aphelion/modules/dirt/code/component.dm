/**
 * The semen a person or an item carries, as splats: each a variant of a zone's semen at a level. A person's skin splats
 * draw through one /datum/bodypart_overlay/dirt_skin on each limb skin semen draws on, from masks SSdirt makes. Washing
 * clears it, as it clears the floor's decals.
 */
/datum/component/dirtiness
	/// This carrier's /datum/dirt_splat, oldest first: a person's skin, or an item's cloth.
	var/list/semen_splats = list()
	/// A person's parts' splats: alist(ORGAN_SLOT_* = list of /datum/dirt_splat, oldest first).
	var/alist/part_semen_splats = alist()
	/// alist(body zone = /datum/bodypart_overlay/dirt_skin): the overlay on each limb skin semen draws on.
	var/alist/skin_overlays = alist()
	/// What the skin's masks are made from now, made again when the splats or the body's sprites change.
	var/datum/dirt_mask_request/skin_request
	/// skin_request's mask_key(), so asking again costs no MD5.
	var/skin_key
	/// The masks the skin is drawn with: skin_request's once made, and until then the ones before them, if any.
	var/datum/dirt_masks/skin_masks

/datum/component/dirtiness/Initialize()
	if(!ishuman(parent) && !isitem(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/dirtiness/RegisterWithParent()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	if(ishuman(parent))
		RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
		RegisterSignal(parent, COMSIG_CARBON_ATTACH_LIMB, PROC_REF(on_limb_attached))
		RegisterSignal(parent, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_limb_removed))

/datum/component/dirtiness/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_ATOM_EXAMINE, COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVE_LIMB))
	var/mob/living/carbon/human/body = parent
	if(!istype(body) || !length(skin_overlays))
		return
	for(var/zone, overlay in skin_overlays)
		var/datum/bodypart_overlay/dirt_skin/skin_overlay = overlay
		skin_overlay.carrier = null
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		if(limb && (skin_overlay in limb.bodypart_overlays))
			limb.remove_bodypart_overlay(skin_overlay, update = FALSE)
	skin_overlays.Cut()
	if(!QDELING(body))
		body.update_body_parts()

/datum/component/dirtiness/Destroy(force)
	skin_request = null
	skin_masks = null
	return ..()

/**
 * Puts semen on a zone of this carrier: its skin or cloth, or the part in an organ slot. As a climax lands it, the levels
 * go on the zone's newest splat, up to DIRT_SEMEN_MAX_LEVEL, and what's left starts another splat at that level, at most
 * the top one, with a variant this carrier doesn't have on that zone yet while one is left. A variant given places a new
 * splat at `levels` with that variant.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - organ_slot: The part's ORGAN_SLOT_* define, or null for the skin or cloth.
 * - levels: How many levels it adds, 1 or more.
 * - variant: 0 to DIRT_SEMEN_VARIANTS - 1, or null.
 * - redraw: Whether to draw the change. A caller that changes more first, as a landing past the cap does, draws once
 *   after (semen_changed()), so no masks are made for splats it's about to take off.
 *
 * Returns the splat it started, or the one it raised when it started none.
 */
/datum/component/dirtiness/proc/add_semen(zone, organ_slot = null, levels = 1, variant = null, redraw = TRUE)
	RETURN_TYPE(/datum/dirt_splat)
	var/list/splats = semen_splats
	if(organ_slot)
		splats = part_semen_splats[organ_slot]
		if(!splats)
			splats = list()
			part_semen_splats[organ_slot] = splats
	var/datum/dirt_splat/touched
	if(isnull(variant))
		for(var/index in length(splats) to 1 step -1)
			var/datum/dirt_splat/newest = splats[index]
			if(newest.zone != zone)
				continue
			var/risen = min(levels, DIRT_SEMEN_MAX_LEVEL - newest.level)
			if(risen > 0)
				newest.level += risen
				levels -= risen
				touched = newest
			break
	if(levels > 0)
		touched = new /datum/dirt_splat(zone, min(levels, DIRT_SEMEN_MAX_LEVEL), isnull(variant) ? fresh_semen_variant(zone, organ_slot) : variant, SSdirt.next_serial())
		splats += touched
	if(redraw)
		semen_changed(organ_slot)
	return touched

/**
 * Returns a variant of a zone's semen this carrier doesn't have on that zone yet, at random, or any once it has them all.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - organ_slot: The part's ORGAN_SLOT_* define, or null for the skin or cloth.
 */
/datum/component/dirtiness/proc/fresh_semen_variant(zone, organ_slot = null)
	var/list/unused = list()
	for(var/variant in 0 to DIRT_SEMEN_VARIANTS - 1)
		unused += variant
	for(var/datum/dirt_splat/splat as anything in (organ_slot ? part_semen_splats[organ_slot] : semen_splats))
		if(splat.zone == zone)
			unused -= splat.variant
	return length(unused) ? pick(unused) : rand(0, DIRT_SEMEN_VARIANTS - 1)

/**
 * Takes one splat off this carrier, wherever it lies.
 *
 * Arguments:
 * - splat: The splat.
 * - redraw: Whether to draw the change, as add_semen()'s.
 */
/datum/component/dirtiness/proc/remove_semen(datum/dirt_splat/splat, redraw = TRUE)
	if(splat in semen_splats)
		semen_splats -= splat
		if(redraw)
			semen_changed()
		return
	for(var/organ_slot, splats in part_semen_splats)
		var/list/part_splats = splats
		if(splat in part_splats)
			part_splats -= splat
			if(!length(part_splats))
				part_semen_splats -= organ_slot
			if(redraw)
				semen_changed(organ_slot)
			return

/// Takes all of this carrier's semen off.
/datum/component/dirtiness/proc/clear_semen()
	semen_splats.Cut()
	part_semen_splats = alist()
	skin_masks = null
	semen_changed()

/// Returns how many splats this carrier holds, parts included.
/datum/component/dirtiness/proc/semen_count()
	. = length(semen_splats)
	for(var/organ_slot, splats in part_semen_splats)
		var/list/part_splats = splats
		. += length(part_splats)

/// Returns this carrier's oldest splat, parts included, or null with none.
/datum/component/dirtiness/proc/oldest_semen()
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/dirt_splat/oldest = length(semen_splats) ? semen_splats[1] : null
	for(var/organ_slot, splats in part_semen_splats)
		var/list/part_splats = splats
		var/datum/dirt_splat/first = length(part_splats) ? part_splats[1] : null
		if(first && (!oldest || first.serial < oldest.serial))
			oldest = first
	return oldest

/**
 * Draws a change to this carrier's splats.
 *
 * Arguments:
 * - organ_slot: The part whose splats changed, or null for the skin or cloth. Parts aren't drawn.
 */
/datum/component/dirtiness/proc/semen_changed(organ_slot = null)
	if(organ_slot)
		return
	var/mob/living/carbon/human/body = parent
	if(!istype(body))
		return
	forget_skin_request()
	if(!length(semen_splats))
		skin_masks = null
	sync_skin_overlays(body)
	body.update_body_parts()

/// Drops the skin's request, so the next draw makes one from the splats and the body as they are.
/datum/component/dirtiness/proc/forget_skin_request()
	skin_request = null
	skin_key = null

/**
 * Puts a skin overlay on each limb skin semen draws on while the skin carries any, and takes them off once it doesn't.
 * Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/sync_skin_overlays(mob/living/carbon/human/body)
	var/carries = length(semen_splats)
	for(var/zone in dirt_skin_zones())
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		var/datum/bodypart_overlay/dirt_skin/overlay = skin_overlays[zone]
		if(overlay && (!carries || !limb || !(overlay in limb.bodypart_overlays)))
			if(limb && (overlay in limb.bodypart_overlays))
				limb.remove_bodypart_overlay(overlay, update = FALSE)
			overlay.carrier = null
			skin_overlays -= zone
			overlay = null
		if(carries && limb && !overlay)
			overlay = new(src)
			limb.add_bodypart_overlay(overlay, update = FALSE)
			skin_overlays[zone] = overlay

/**
 * Returns the masks the skin's semen is drawn with on a limb, or null while there are none to draw. The first ask after
 * a change queues them with SSdirt, which draws the body again once they're made; until then the masks before them are
 * drawn, so semen already there stays while more is added. Masks made for other sprites than the limb draws (a new size,
 * a swapped limb) are dropped and made again.
 *
 * Arguments:
 * - limb: The limb asking.
 */
/datum/component/dirtiness/proc/ready_skin_masks(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	if(!length(semen_splats) || !istype(body))
		return null
	if(skin_request && !dirt_limb_drawn_as(limb, skin_request.zone_sources))
		forget_skin_request()
		skin_masks = null
	if(!skin_request)
		skin_request = new(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_SKIN, semen_splats)
		skin_key = skin_request.mask_key()
		take_skin_masks(SSdirt.masks_for(skin_request, body, DIRT_REDRAW_BODY))
		return skin_masks
	if(skin_masks?.key == skin_key)
		return skin_masks
	// asked before: read the cache rather than spend masks_for()'s two MD5s on every draw
	var/cached = SSdirt.masks[skin_key]
	if(isnull(cached))
		cached = SSdirt.masks_for(skin_request, body, DIRT_REDRAW_BODY)
	take_skin_masks(cached)
	return skin_masks

/**
 * Draws the skin with newly made masks. A job still making them, a failure or nothing leaves the masks drawn before.
 *
 * Arguments:
 * - made: What SSdirt holds for skin_key: /datum/dirt_masks, the job making them, FALSE, or null.
 */
/datum/component/dirtiness/proc/take_skin_masks(made)
	if(istype(made, /datum/dirt_masks))
		skin_masks = made

/**
 * Clears this carrier's semen when it's washed as the floor's decals are.
 *
 * Arguments:
 * - source: The carrier.
 * - clean_types: CLEAN_TYPE_* flags.
 */
/datum/component/dirtiness/proc/on_clean(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_LIGHT_DECAL) || !semen_count())
		return NONE
	clear_semen()
	return COMPONENT_CLEANED

/**
 * Names the regions a person's skin carries semen on, to examiners who both have the ERP preference on.
 *
 * Arguments:
 * - source: The person.
 * - user: The examiner.
 * - examine_list: The examine lines, added to.
 */
/datum/component/dirtiness/proc/on_examine(mob/living/carbon/human/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/viewer = user
	if(!length(semen_splats) || !istype(viewer) || !viewer.can_see_erp_flavor(source))
		return
	var/list/regions = list()
	for(var/zone in dirt_semen_zones())
		for(var/datum/dirt_splat/splat as anything in semen_splats)
			if(splat.zone == zone)
				regions += zone
				break
	examine_list += span_purple("[source.p_They()] [source.p_have()] cum on [source.p_their()] [english_list(regions)].")

/**
 * Has the skin's masks made again for the body a limb attached to the person makes, every limb shaping the others'
 * silhouettes, and gives the limb a skin overlay if skin semen draws on it. The attach draws the body.
 *
 * Arguments:
 * - source: The person.
 * - limb: The limb being attached.
 * - special: Whether it's swapped without the usual effects.
 * - lazy: Whether the person is still being made.
 */
/datum/component/dirtiness/proc/on_limb_attached(mob/living/carbon/human/source, obj/item/bodypart/limb, special, lazy)
	SIGNAL_HANDLER
	if(!length(semen_splats) || IS_STUMP(limb))
		return
	forget_skin_request()
	skin_masks = null
	if(!(limb.body_zone in dirt_skin_zones()))
		return
	var/datum/bodypart_overlay/dirt_skin/old_overlay = skin_overlays[limb.body_zone]
	if(old_overlay)
		old_overlay.carrier = null
	var/datum/bodypart_overlay/dirt_skin/overlay = new(src)
	limb.add_bodypart_overlay(overlay, update = FALSE)
	skin_overlays[limb.body_zone] = overlay

/**
 * Takes the skin overlay off a limb leaving the person, whose semen stays with them, and has the skin's masks made again
 * for the body left. The removal draws the body.
 *
 * Arguments:
 * - source: The person.
 * - limb: The limb being removed.
 * - special: Whether it's swapped without the usual effects.
 * - dismembered: Whether it was cut off.
 */
/datum/component/dirtiness/proc/on_limb_removed(mob/living/carbon/human/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER
	if(length(semen_splats))
		forget_skin_request()
		skin_masks = null
	var/datum/bodypart_overlay/dirt_skin/overlay = skin_overlays[limb.body_zone]
	if(!overlay || !(overlay in limb.bodypart_overlays))
		return
	limb.remove_bodypart_overlay(overlay, update = FALSE)
	overlay.carrier = null
	skin_overlays -= limb.body_zone
