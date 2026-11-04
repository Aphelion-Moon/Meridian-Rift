/**
 * The mess a person or an item carries, as splats: each a variant of a zone's mess at a level, from masks SSdirt
 * makes. A person's skin splats draw through one /datum/bodypart_overlay/dirt_skin on each limb skin mess draws on,
 * under what they wear, and fade out beside it. Their underclothes' splats are kept with each piece, and draw over it
 * through one /datum/bodypart_overlay/dirt_underclothes on the chest while it's worn and shows. Their parts' splats
 * draw with each part's own front layer, and their taur body's pools with the taur body's own images. A garment's
 * splats draw inset over it while a person wears it, and a taur suit's back splats as pools along the taur body's back
 * too. The parts a surface's mess reaches shape it (dirt_surface_parts()). Washing clears it, as it clears the floor's
 * decals.
 */
/datum/component/dirtiness
	/// This carrier's /datum/dirt_splat, oldest first: a person's skin, or an item's cloth.
	var/list/mess_splats = list()
	/// A person's parts' splats: alist(ORGAN_SLOT_* = list of /datum/dirt_splat, oldest first). The taur body's pools are
	/// ORGAN_SLOT_EXTERNAL_TAUR's.
	var/alist/part_mess_splats = alist()
	/// alist(ORGAN_SLOT_* = /datum/dirt_drawing): each part with splats' own masks, made again when its sprite changes.
	var/alist/part_drawings
	/// The body's parts as dirt_body_parts_key() wrote them when check_parts() last looked, so a change since draws the
	/// garments it wears again, which check their own masks as they draw.
	var/parts_key
	/// alist(body zone = /datum/bodypart_overlay/dirt_skin): the overlay on each limb skin mess draws on.
	var/alist/skin_overlays = alist()
	/// The skin's masks, made again when the splats, the body's sprites or what it wears change. Its parts_key is the
	/// body's parts when its request was made, as dirt_body_parts_key() writes them.
	var/datum/dirt_drawing/skin
	/// What the body wore over its skin when the skin's request was made, as dirt_sprites_key() writes it.
	var/cover_key
	/// What the limbs and eyes were drawn from when they last matched the skin's request (skin_read_again()):
	/// alist(body zone = /obj/item/bodypart/proc/dirt_sprite_reads(), "eyes" = dirt_eye_reads()), for skin_reads_for.
	var/alist/skin_reads
	/// The skin's request skin_reads were read for. Another one reads them again.
	var/datum/dirt_mask_request/skin_reads_for
	/// A person's underclothes' splats: alist(underclothes key = list of /datum/dirt_splat, oldest first), keyed by the
	/// piece and its accessory (dirt_underclothes_key()). They stay while the piece is off or hidden.
	var/alist/underclothes_splats
	/// alist(underclothes key = /datum/dirt_drawing): each piece with splats' masks, made again when what's drawn changes,
	/// and none while the piece is off or hidden.
	var/alist/underclothes_drawings
	/// The overlay on the chest drawing the underclothes' splats, while there are any.
	var/datum/bodypart_overlay/dirt_underclothes/underclothes_overlay
	/// An item's cloth masks, made from its wearer's body.
	var/datum/dirt_drawing/cloth
	/// A taur suit's pools, its back splats along its wearer's taur body's back, made while a taur wears it.
	var/datum/dirt_drawing/taur_cloth

/datum/component/dirtiness/Initialize()
	if(!ishuman(parent) && !isitem(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/dirtiness/RegisterWithParent()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	if(ishuman(parent))
		RegisterSignal(parent, COMSIG_CARBON_ATTACH_LIMB, PROC_REF(on_limb_attached))
		RegisterSignal(parent, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_limb_removed))
		RegisterSignals(parent, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY), PROC_REF(on_overlay_changed))
		RegisterSignal(parent, COMSIG_HUMAN_GENITAL_UPDATED, PROC_REF(on_genital_updated))
		RegisterSignal(parent, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(on_organ_gained))
		RegisterSignal(parent, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_organ_lost))
		return
	RegisterSignal(parent, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS, PROC_REF(on_worn_overlays))

/datum/component/dirtiness/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVE_LIMB, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_HUMAN_GENITAL_UPDATED, COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS))
	var/mob/living/carbon/human/body = parent
	if(!istype(body) || (!length(skin_overlays) && !underclothes_overlay))
		return
	for(var/zone, overlay in skin_overlays)
		var/datum/bodypart_overlay/dirt_skin/skin_overlay = overlay
		skin_overlay.carrier = null
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		if(limb && (skin_overlay in limb.bodypart_overlays))
			limb.remove_bodypart_overlay(skin_overlay, update = FALSE)
	skin_overlays.Cut()
	drop_underclothes_overlay(body)
	if(!QDELING(body))
		body.update_body_parts()

/datum/component/dirtiness/Destroy(force)
	skin = null
	forget_skin_reads()
	underclothes_drawings = null
	part_drawings = null
	cloth = null
	taur_cloth = null
	return ..()

/**
 * Puts a mess on a zone of this carrier: its skin or cloth, or the part in an organ slot. As a shot lands it, the
 * levels go on the zone's newest splat, up to DIRT_MESS_MAX_LEVEL, and what's left starts another splat at that level,
 * at most the top one, with a variant this carrier doesn't have on that zone yet while one is left. A variant given
 * places a new splat at `levels` with that variant.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - organ_slot: The part's ORGAN_SLOT_* define, or null for the skin or cloth.
 * - levels: How many levels it adds, 1 or more.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1, or null.
 * - redraw: Whether to draw the change. A caller that changes more first, as a landing past the cap does, draws once
 *   after (mess_changed()), so no masks are made for splats it's about to take off.
 * - new_variant: The variant a splat started without `variant` takes, or null for one the zone doesn't have yet: a part
 *   takes the variant of the shot's splat on the surface under it.
 *
 * Returns the splat it started, or the one it raised when it started none.
 */
/datum/component/dirtiness/proc/add_mess(zone, organ_slot = null, levels = 1, variant = null, redraw = TRUE, new_variant = null)
	RETURN_TYPE(/datum/dirt_splat)
	var/list/splats = mess_splats
	if(organ_slot)
		splats = (part_mess_splats[organ_slot] ||= list())
	var/datum/dirt_splat/touched = stack_mess(splats, zone, levels, variant, new_variant)
	if(redraw)
		mess_changed(organ_slot)
	return touched

/**
 * Puts a mess on a zone of the underclothes a person wears in a slot, as add_mess() puts it on the skin. It stays with
 * that piece, kept while it's off or hidden.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - piece: A DIRT_UNDERCLOTHES_* define the person wears.
 * - levels: How many levels it adds, 1 or more.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1, or null.
 * - redraw: Whether to draw the change, as add_mess()'s.
 *
 * Returns the splat it started or raised, or null when the person doesn't wear that piece.
 */
/datum/component/dirtiness/proc/add_underclothes_mess(zone, piece, levels = 1, variant = null, redraw = TRUE)
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/sprite_accessory/accessory = dirt_underclothes_worn(parent)[piece]
	if(!accessory)
		return null
	underclothes_splats ||= alist()
	var/key = dirt_underclothes_key(piece, accessory.name)
	var/list/splats = (underclothes_splats[key] ||= list())
	var/datum/dirt_splat/touched = stack_mess(splats, zone, levels, variant)
	if(redraw)
		mess_changed()
	return touched

/**
 * Adds a mess to one surface's splats as add_mess() describes, and returns the splat it started, or the one it raised.
 *
 * Arguments:
 * - splats: The surface's splats, oldest first. Added to.
 * - zone, levels, variant, new_variant: As add_mess()'s.
 */
/datum/component/dirtiness/proc/stack_mess(list/splats, zone, levels, variant, new_variant = null)
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/dirt_splat/touched
	if(isnull(variant))
		for(var/index in length(splats) to 1 step -1)
			var/datum/dirt_splat/newest = splats[index]
			if(newest.zone != zone)
				continue
			var/risen = min(levels, DIRT_MESS_MAX_LEVEL - newest.level)
			if(risen > 0)
				newest.level += risen
				levels -= risen
				touched = newest
			break
	if(levels > 0)
		if(isnull(variant))
			variant = isnull(new_variant) ? dirt_fresh_variant(splats, zone) : new_variant
		touched = new /datum/dirt_splat(zone, min(levels, DIRT_MESS_MAX_LEVEL), variant, SSdirt.next_serial())
		splats += touched
	return touched

/**
 * Returns a variant of a zone's mess this carrier doesn't have on that zone yet, at random, or any once it has them
 * all.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - piece: A DIRT_UNDERCLOTHES_* define for the underclothes a person wears in that slot, or null for the skin or
 *   cloth.
 */
/datum/component/dirtiness/proc/fresh_mess_variant(zone, piece = null)
	if(piece)
		var/datum/sprite_accessory/accessory = dirt_underclothes_worn(parent)[piece]
		return dirt_fresh_variant(accessory && underclothes_splats?[dirt_underclothes_key(piece, accessory.name)], zone)
	return dirt_fresh_variant(mess_splats, zone)

/**
 * Returns a variant of a zone's mess none of some splats on that zone has, at random, or any once they have them all.
 *
 * Arguments:
 * - splats: The splats, or null.
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_fresh_variant(list/splats, zone)
	var/list/unused = list()
	for(var/variant in 0 to DIRT_MESS_VARIANTS - 1)
		unused += variant
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.zone == zone)
			unused -= splat.variant
	return length(unused) ? pick(unused) : rand(0, DIRT_MESS_VARIANTS - 1)

/**
 * Takes one splat off this carrier, wherever it lies.
 *
 * Arguments:
 * - splat: The splat.
 * - redraw: Whether to draw the change, as add_mess()'s.
 *
 * Returns the ORGAN_SLOT_* define of the part it was on, or null for the skin, the cloth or the underclothes: what to
 * draw again (mess_changed()).
 */
/datum/component/dirtiness/proc/remove_mess(datum/dirt_splat/splat, redraw = TRUE)
	if(splat in mess_splats)
		mess_splats -= splat
		if(redraw)
			mess_changed()
		return null
	for(var/organ_slot, splats in part_mess_splats)
		var/list/part_splats = splats
		if(splat in part_splats)
			part_splats -= splat
			if(!length(part_splats))
				part_mess_splats -= organ_slot
			if(redraw)
				mess_changed(organ_slot)
			return organ_slot
	for(var/key, splats in underclothes_splats)
		var/list/piece_splats = splats
		if(splat in piece_splats)
			piece_splats -= splat
			if(!length(piece_splats))
				underclothes_splats -= key
				LAZYREMOVE(underclothes_drawings, key)
			if(redraw)
				mess_changed()
			return null
	return null

/**
 * Takes all of this carrier's mess off.
 *
 * Arguments:
 * - redraw: Whether to draw the change. Washing an item draws its slot itself.
 */
/datum/component/dirtiness/proc/clear_mess(redraw = TRUE)
	var/parts_had_mess = length(part_mess_splats)
	mess_splats.Cut()
	part_mess_splats = alist()
	part_drawings = null
	underclothes_splats = null
	underclothes_drawings = null
	skin?.forget(TRUE)
	forget_skin_reads()
	cloth?.forget(TRUE)
	taur_cloth?.forget(TRUE)
	if(redraw)
		mess_changed(null, parts_had_mess)

/**
 * Takes a part's splats and masks off, as it leaves the body. Its leaving draws the body.
 *
 * Arguments:
 * - organ_slot: The part's ORGAN_SLOT_* define.
 */
/datum/component/dirtiness/proc/drop_part(organ_slot)
	part_mess_splats -= organ_slot
	LAZYREMOVE(part_drawings, organ_slot)

/// Returns how many splats this carrier holds, parts and underclothes included.
/datum/component/dirtiness/proc/mess_count()
	. = length(mess_splats)
	for(var/organ_slot, splats in part_mess_splats)
		var/list/part_splats = splats
		. += length(part_splats)
	for(var/key, splats in underclothes_splats)
		var/list/piece_splats = splats
		. += length(piece_splats)

/// Returns this carrier's oldest splat, parts and underclothes included, or null with none.
/datum/component/dirtiness/proc/oldest_mess()
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/dirt_splat/oldest = length(mess_splats) ? mess_splats[1] : null
	for(var/organ_slot, splats in part_mess_splats)
		var/list/part_splats = splats
		var/datum/dirt_splat/first = length(part_splats) ? part_splats[1] : null
		if(first && (!oldest || first.serial < oldest.serial))
			oldest = first
	for(var/key, splats in underclothes_splats)
		var/list/piece_splats = splats
		var/datum/dirt_splat/first = length(piece_splats) ? piece_splats[1] : null
		if(first && (!oldest || first.serial < oldest.serial))
			oldest = first
	return oldest

/**
 * Draws a change to this carrier's splats: a person's skin and underclothes, a part of theirs, or an item's slot while
 * it's worn. A part's change redraws the whole body, which a portal relay drawing the part, or a bulge look drawing it
 * behind a cover, follows.
 *
 * Arguments:
 * - organ_slot: The part whose splats changed, or null for the rest.
 * - parts_too: Whether parts' splats changed with the rest (a wash), so the whole body is drawn again.
 * - draw: Whether to draw a person now. A caller changing several of their surfaces at once draws them once after.
 */
/datum/component/dirtiness/proc/mess_changed(organ_slot = null, parts_too = FALSE, draw = TRUE)
	if(organ_slot)
		var/datum/dirt_drawing/drawing = part_drawings?[organ_slot]
		drawing?.forget(!length(part_mess_splats[organ_slot]))
		var/mob/living/carbon/human/owner = parent
		if(draw && istype(owner))
			owner.update_body()
		return
	if(isitem(parent))
		cloth?.forget(!length(mess_splats))
		taur_cloth?.forget(!length(mess_splats))
		var/obj/item/garment = parent
		garment.update_slot_icon()
		return
	var/mob/living/carbon/human/body = parent
	skin?.forget(!length(mess_splats))
	if(!length(mess_splats))
		forget_skin_reads()
	forget_underclothes_masks()
	sync_skin_overlays(body)
	sync_underclothes_overlay(body)
	if(!draw)
		return
	if(parts_too)
		body.update_body()
	else
		body.update_body_parts()

/**
 * Puts a skin overlay on each limb skin mess draws on while the skin carries any, and takes them off once it doesn't.
 * Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/sync_skin_overlays(mob/living/carbon/human/body)
	var/carries = length(mess_splats)
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
 * Puts the underclothes overlay on the chest while the underclothes carry mess, and takes it off once they don't.
 * Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/sync_underclothes_overlay(mob/living/carbon/human/body)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(underclothes_overlay && (!length(underclothes_splats) || !chest || !(underclothes_overlay in chest.bodypart_overlays)))
		drop_underclothes_overlay(body)
	if(length(underclothes_splats) && chest && !underclothes_overlay)
		underclothes_overlay = new(src)
		chest.add_bodypart_overlay(underclothes_overlay, update = FALSE)

/**
 * Takes the underclothes overlay off, wherever it is. Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/drop_underclothes_overlay(mob/living/carbon/human/body)
	if(!underclothes_overlay)
		return
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		if(underclothes_overlay in limb.bodypart_overlays)
			limb.remove_bodypart_overlay(underclothes_overlay, update = FALSE)
	underclothes_overlay.carrier = null
	underclothes_overlay = null

/**
 * Returns the masks the skin's mess is drawn with on a limb, or null while there are none to draw. The first ask after
 * a change queues them with SSdirt, which draws the body again once they're made; until then the masks before them are
 * drawn, so mess already there stays while more is added. Masks made for other sprites than the body draws (a new
 * size, a swapped limb, other eyes) are dropped and made again: on every draw each limb skin mess draws on checks its
 * own, and the chest the arms, the hands and the eyes. Each is read again only once what it's drawn from has changed
 * since it last matched (skin_reads), so a steady draw compares a few vars. They fade out beside what the body wears
 * (dirt_cover_sprites()), and the parts the splats reach shape them (dirt_surface_parts()) as each draws over or under
 * the skin in each direction: every front image over it, a butt's back image and the pecs guide under it.
 *
 * Arguments:
 * - limb: The limb asking.
 */
/datum/component/dirtiness/proc/ready_skin_masks(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	if(!length(mess_splats) || !istype(body))
		return null
	skin ||= new
	if(skin.request)
		var/list/read = skin_reads_for == skin.request ? skin_reads[limb.body_zone] : null
		var/steady = read && limb.dirt_sprite_unchanged(read) && (limb.body_zone != BODY_ZONE_CHEST || skin_besides_unchanged(body))
		if(!steady && !skin_read_again(body, limb))
			skin.forget(TRUE)
	if(!skin.request)
		var/list/cover = dirt_cover_sprites(body)
		var/list/zone_sources = dirt_zone_sources(body)
		var/list/body_parts = dirt_body_parts(body)
		cover_key = dirt_sprites_key(cover)
		skin.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, zone_sources, DIRT_SURFACE_SKIN, mess_splats, dirt_surface_parts(body_parts, mess_splats), cover = cover, surface_layer = DIRT_SKIN_LAYER), dirt_body_parts_key(body_parts))
		// read from the body just now, with nothing between that changes a limb, so the draws after only compare
		note_skin_reads(body, GLOB.all_body_zones, TRUE)
	return skin.current(body, DIRT_REDRAW_BODY)

/**
 * Returns whether what the chest's draw checks of the skin's sprites besides its own, the arms and hands, the eyes and
 * whether the head is a human's, is drawn from what it was when they last matched (skin_reads).
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/skin_besides_unchanged(mob/living/carbon/human/body)
	for(var/zone in dirt_skin_besides(BODY_ZONE_CHEST))
		var/obj/item/bodypart/checked = body.get_bodypart(zone)
		var/list/read = skin_reads[zone]
		// a zone with no limb is read again every time
		if(!checked || !read || !checked.dirt_sprite_unchanged(read))
			return FALSE
	var/list/eye_read = skin_reads["eyes"]
	return eye_read && dirt_eyes_unchanged(body, skin.request.zone_sources, eye_read)

/**
 * Returns whether the body draws the sprites the skin's masks were made from, as a limb's draw checks them: its own,
 * and for the chest the arms and hands, the eyes and whether the head is a human's (dirt_zone_sources_match(), which
 * checks the eyes whichever limb asks). When it does, notes what they're drawn from (skin_reads).
 *
 * Arguments:
 * - body: The person.
 * - limb: The limb asking.
 */
/datum/component/dirtiness/proc/skin_read_again(mob/living/carbon/human/body, obj/item/bodypart/limb)
	var/list/zones = list(limb.body_zone) + dirt_skin_besides(limb.body_zone)
	if(!dirt_zone_sources_match(body, skin.request.zone_sources, zones))
		return FALSE
	note_skin_reads(body, zones, limb.body_zone == BODY_ZONE_CHEST)
	return TRUE

/**
 * Notes what some zones' limbs, and the eyes when asked, are drawn from now, for the skin's request (skin_reads): its
 * zone sources name what they draw.
 *
 * Arguments:
 * - body: The person.
 * - zones: The body zones.
 * - eyes: Whether to note the eyes and the head they're read through.
 */
/datum/component/dirtiness/proc/note_skin_reads(mob/living/carbon/human/body, list/zones, eyes)
	if(skin_reads_for != skin.request)
		skin_reads_for = skin.request
		skin_reads = alist()
	for(var/zone in zones)
		var/obj/item/bodypart/checked = body.get_bodypart(zone)
		skin_reads[zone] = checked?.dirt_sprite_reads()
	if(eyes)
		skin_reads["eyes"] = dirt_eye_reads(body, skin.request.zone_sources)

/// Drops what the skin's sprites were last read from (skin_reads), which holds the limbs and eyes read, so none that
/// leaves is kept: the next draw reads them again.
/datum/component/dirtiness/proc/forget_skin_reads()
	skin_reads = null
	skin_reads_for = null

/**
 * Returns the masks of each piece of a person's underclothes that has some drawn and is worn and shows now, asking for
 * those not made yet as ready_skin_masks() does. Each is cloth's, kept to the pixels the piece shows, under those drawn
 * over it, and shaped by the parts its splats reach (dirt_surface_parts()): pecs under a tank top, or a genital set to
 * draw below the underwear. A piece off or hidden keeps its splats but draws none.
 */
/datum/component/dirtiness/proc/ready_underclothes_masks()
	RETURN_TYPE(/list)
	. = list()
	var/mob/living/carbon/human/body = parent
	if(!length(underclothes_splats) || !istype(body))
		return
	underclothes_drawings ||= alist()
	var/list/drawn
	var/list/body_parts
	var/body_parts_key
	for(var/key, splats in underclothes_splats)
		var/datum/dirt_drawing/drawing = (underclothes_drawings[key] ||= new /datum/dirt_drawing)
		if(drawing.absent)
			continue
		if(!drawing.request)
			drawn ||= dirt_underclothes_sprites(body)
			var/list/clip
			var/list/cut = list()
			for(var/list/entry as anything in drawn)
				if(clip)
					cut += list(list(entry[2], entry[3]))
				else if(dirt_underclothes_key(entry[1], entry[4]) == key)
					clip = list(list(entry[2], entry[3]))
			if(!clip)
				drawing.forget(TRUE)
				drawing.absent = TRUE
				continue
			if(isnull(body_parts))
				body_parts = dirt_body_parts(body)
				body_parts_key = dirt_body_parts_key(body_parts)
			drawing.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_CLOTH, splats, dirt_surface_parts(body_parts, splats), clip = clip, cut = cut, surface_layer = DIRT_UNDERCLOTHES_LAYER), body_parts_key)
		var/datum/dirt_masks/masks = drawing.current(body, DIRT_REDRAW_BODY)
		if(masks)
			. += masks

/**
 * Returns the masks a worn item's cloth is drawn with on its wearer, or null while there are none to draw, asking for
 * them as ready_skin_masks() does. Masks made for a body drawn from other sprites (another wearer, other eyes) are
 * dropped and made again; a change to the parts its splats reach (dirt_surface_parts()) makes them again too, the old
 * ones drawn meanwhile.
 *
 * Arguments:
 * - garment: The item.
 * - wearer: Who wears it.
 */
/datum/component/dirtiness/proc/ready_cloth_masks(obj/item/garment, mob/living/carbon/human/wearer)
	RETURN_TYPE(/datum/dirt_masks)
	if(!length(mess_splats))
		return null
	cloth ||= new
	var/slot = wearer.get_slot_by_item(garment)
	var/surface_layer = dirt_slot_layer(slot)
	var/list/reached = dirt_surface_parts(dirt_body_parts(wearer), mess_splats)
	var/reached_key = dirt_parts_key(reached, surface_layer)
	if(cloth.request && !dirt_zone_sources_match(wearer, cloth.request.zone_sources))
		cloth.forget(TRUE)
	else if(cloth.request && cloth.parts_key != reached_key)
		cloth.forget(FALSE)
	if(!cloth.request)
		cloth.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, dirt_zone_sources(wearer), DIRT_SURFACE_CLOTH, mess_splats, reached, surface_layer = surface_layer), reached_key)
	return cloth.current(wearer, dirt_slot_redraw(slot))

/**
 * Returns the masks of a person's part's own mess, its share drawn with its front layer, or null while there are none
 * to draw, asking for them as ready_skin_masks() does; SSdirt draws the whole body again once they're made. Masks made
 * for another sprite of the part (an erection, a jiggle, another size) are dropped and made again: they wouldn't fit
 * it. The vulva on bare skin takes the ring of skin round it, so its masks follow the body's template too. A part drawn
 * at more than one layer (a butt's front and back images) draws its share only in the directions it shows over what it
 * lies on (dirt_zone_layer()): the surface's masks take it in the rest.
 *
 * Arguments:
 * - organ_slot: The part's ORGAN_SLOT_* define.
 * - source: What the part draws now, from its images in the layers its kind is read from (dirt_part_images()), or null.
 */
/datum/component/dirtiness/proc/ready_part_masks(organ_slot, datum/dirt_part_source/source)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	var/list/splats = part_mess_splats[organ_slot]
	if(!length(splats) || !source || !istype(body))
		return null
	part_drawings ||= alist()
	var/datum/dirt_drawing/drawing = (part_drawings[organ_slot] ||= new /datum/dirt_drawing)
	// a part drawn at one layer, other than the vulva, keys its masks by its source alone, which is never changed: asked
	// with the source its masks were asked for, it asks for the same ones
	if(drawing.request?.part_source == source && isnull(drawing.request.facings) && source.kind != DIRT_PART_VAGINA)
		return drawing.current(body, DIRT_REDRAW_SHARE)
	var/surface_kind = DIRT_SURFACE_SKIN
	var/list/facings
	var/layered = source.layered()
	if(layered || source.kind == DIRT_PART_VAGINA)
		var/surface_layer = dirt_zone_layer(body, dirt_part_zone(source.kind))
		if(layered)
			// drawn over what it lies on in some directions only: it draws its share in those, the surface in the rest
			facings = list()
			for(var/direction in dirt_mask_directions())
				if(!source.under(direction, surface_layer))
					facings += direction
		if(source.kind == DIRT_PART_VAGINA && surface_layer != DIRT_SKIN_LAYER)
			surface_kind = DIRT_SURFACE_CLOTH
	// the vulva on skin takes the ring of the body round it
	var/on_body = source.kind == DIRT_PART_VAGINA && surface_kind == DIRT_SURFACE_SKIN
	var/source_key = "[surface_kind]|[source.part_key()]|[facings ? jointext(facings, ",") : "all"]"
	if(drawing.request && (drawing.parts_key != source_key || (on_body && !dirt_zone_sources_match(body, drawing.request.zone_sources))))
		drawing.forget(TRUE)
	if(!drawing.request)
		drawing.start(new /datum/dirt_mask_request(DIRT_MASKS_PART, on_body ? dirt_zone_sources(body) : null, surface_kind, splats, part_source = source, facings = facings), source_key)
	return drawing.current(body, DIRT_REDRAW_SHARE)

/**
 * Returns the masks of a taur suit's pools on its wearer, or null while there are none to draw, asking for them as
 * ready_skin_masks() does: its back splats along the back of the taur body it hides, as that body would draw them
 * (ready_taur_masks()), over the whole taur canvas. Masks made for another taur body or rider are dropped and made
 * again.
 *
 * Arguments:
 * - garment: The item.
 * - wearer: The taur wearing it.
 */
/datum/component/dirtiness/proc/ready_taur_cloth_masks(obj/item/garment, mob/living/carbon/human/wearer)
	RETURN_TYPE(/datum/dirt_masks)
	var/list/back_splats = list()
	for(var/datum/dirt_splat/splat as anything in mess_splats)
		if(splat.zone == DIRT_ZONE_BACK)
			back_splats += splat
	var/datum/dirt_taur_source/source = length(back_splats) && dirt_taur_source(wearer)
	if(!source)
		return null
	taur_cloth ||= new
	var/source_key = source.taur_key()
	if(taur_cloth.request && (taur_cloth.parts_key != source_key || !dirt_zone_sources_match(wearer, taur_cloth.request.zone_sources)))
		taur_cloth.forget(TRUE)
	if(!taur_cloth.request)
		taur_cloth.start(new /datum/dirt_mask_request(DIRT_MASKS_TAUR, dirt_zone_sources(wearer), DIRT_SURFACE_CLOTH, back_splats, taur_source = source), source_key)
	return taur_cloth.current(wearer, dirt_slot_redraw(wearer.get_slot_by_item(garment)))

/**
 * Returns the masks of a person's taur body's pools, drawn with its own images, or null while there are none to draw,
 * asking for them as ready_skin_masks() does; SSdirt draws the body again once they're made. They lie along the back of
 * the taur body's sprite, keeping clear of the rider's mess, so masks made for another sprite (lying down, another
 * kind) or another rider are dropped and made again.
 *
 * Arguments:
 * - source: The taur body as it draws now (/datum/bodypart_overlay/mutant/taur_body/proc/dirt_read_source()), or null.
 */
/datum/component/dirtiness/proc/ready_taur_masks(datum/dirt_taur_source/source)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	var/list/splats = part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]
	if(!length(splats) || !source || !istype(body))
		return null
	part_drawings ||= alist()
	var/datum/dirt_drawing/drawing = (part_drawings[ORGAN_SLOT_EXTERNAL_TAUR] ||= new /datum/dirt_drawing)
	var/source_key = source.taur_key()
	if(drawing.request && (drawing.parts_key != source_key || !dirt_zone_sources_match(body, drawing.request.zone_sources)))
		drawing.forget(TRUE)
	if(!drawing.request)
		drawing.start(new /datum/dirt_mask_request(DIRT_MASKS_TAUR, dirt_zone_sources(body), DIRT_SURFACE_SKIN, splats, taur_source = source), source_key)
	return drawing.current(body, DIRT_REDRAW_BODY)

/**
 * Draws an item's mess over it while a person wears it: inset images in its worn wrapper, from the wearer's cloth
 * masks, moved back onto the body's tile by what build_worn_icon() moves the wrapper by (dirt_worn_shift()). On a taur
 * suit, a sprite spanning the taur canvas (dirt_taur_fitted()), the suit's back splats draw as pools along the taur
 * body's back too, on the canvas round that tile. Off the body it draws none.
 *
 * Arguments:
 * - source: The item.
 * - overlays: build_worn_icon()'s separate overlays, added to.
 * - standing, icon_file, bodyshape: Unused.
 * - draw_target: The item's own sprite as worn.
 * - isinhands: Whether it's drawn held.
 */
/datum/component/dirtiness/proc/on_worn_overlays(obj/item/source, list/overlays, mutable_appearance/standing, mutable_appearance/draw_target, isinhands, icon_file, bodyshape)
	SIGNAL_HANDLER
	if(isinhands || !length(mess_splats) || !ishuman(source.loc))
		return
	var/mob/living/carbon/human/wearer = source.loc
	// the worn wrapper isn't drawn yet, so the sprite being built tells a taur suit
	var/taur_fitted = draw_target?.icon && get_icon_dimensions(draw_target.icon)["width"] == DIRT_TAUR_WIDTH && istype(wearer.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body)
	var/list/shift = dirt_worn_shift(source)
	var/datum/dirt_masks/masks = ready_cloth_masks(source, wearer)
	if(masks?.baked)
		overlays += dirt_mess_inset_image(masks.baked, shift[1], shift[2])
	if(!taur_fitted)
		return
	var/datum/dirt_masks/pools = ready_taur_cloth_masks(source, wearer)
	if(pools?.baked)
		// the taur canvas is centred on the body's tile, as the taur body's images are
		overlays += dirt_mess_inset_image(pools.baked, shift[1] - DIRT_TAUR_INSET, shift[2])

/**
 * Clears this carrier's mess when it's washed as the floor's decals are.
 *
 * Arguments:
 * - source: The carrier.
 * - clean_types: CLEAN_TYPE_* flags.
 */
/datum/component/dirtiness/proc/on_clean(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_LIGHT_DECAL) || !mess_count())
		return NONE
	// a washed item draws its slot itself (/obj/item/wash())
	clear_mess(redraw = !isitem(parent))
	return COMPONENT_CLEANED

/**
 * Follows what a person wears: a change to the underclothes has their masks made again for what's drawn now, and a
 * change to any slot that covers skin has SSdirt check, once the slots settle, whether the skin's mess fades at other
 * edges now (check_cover()).
 *
 * Arguments:
 * - source: The person.
 * - cache_index: The overlays_standing slot applied or removed.
 */
/datum/component/dirtiness/proc/on_overlay_changed(mob/living/carbon/human/source, cache_index)
	SIGNAL_HANDLER
	if(!(cache_index in dirt_cover_layers()))
		return
	if(cache_index == BODY_LAYER)
		forget_underclothes_masks()
	if(length(mess_splats) || length(underclothes_splats) || length(part_mess_splats))
		SSdirt.redraw_later(source, DIRT_REDRAW_COVER)

/**
 * Has SSdirt look again, once the change settles, at a body gaining a taur body, as a genital joining it would have it
 * (check_parts()). The taur body's own images ask for its pools as they're drawn.
 *
 * Arguments:
 * - source: The person.
 * - organ: The organ gained.
 * - special: Whether it was put in without the usual effects.
 */
/datum/component/dirtiness/proc/on_organ_gained(mob/living/carbon/human/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(istype(organ, /obj/item/organ/taur_body) && mess_count())
		SSdirt.redraw_later(source, DIRT_REDRAW_PARTS)

/**
 * Takes a taur body's pools off as it leaves the body, as a genital leaving takes its share, and has SSdirt look again
 * once the change settles. Its leaving draws the body. Eyes leaving are let go of (forget_skin_reads()).
 *
 * Arguments:
 * - source: The person.
 * - organ: The organ lost.
 * - special: Whether it was taken out without the usual effects.
 */
/datum/component/dirtiness/proc/on_organ_lost(mob/living/carbon/human/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(istype(organ, /obj/item/organ/eyes))
		forget_skin_reads()
	if(!istype(organ, /obj/item/organ/taur_body))
		return
	drop_part(ORGAN_SLOT_EXTERNAL_TAUR)
	if(mess_count())
		SSdirt.redraw_later(source, DIRT_REDRAW_PARTS)

/**
 * Has SSdirt look, once the change settles, whether the parts the body draws changed with a genital's sprite (an
 * erection, a new size) and the masks they shape need making again (check_parts()).
 *
 * Arguments:
 * - source: The person.
 * - genital: The genital whose sprite changed.
 */
/datum/component/dirtiness/proc/on_genital_updated(mob/living/carbon/human/source, obj/item/organ/genital/genital)
	SIGNAL_HANDLER
	if(mess_count())
		SSdirt.redraw_later(source, DIRT_REDRAW_PARTS)

/**
 * Has the masks the body's parts shape made again if what it draws of them changed since they were asked for (a genital
 * shown, hidden, layered otherwise, swapped or resized), and draws the body. The skin and each piece of underclothes
 * are judged by the parts their own masks were asked for with, so a piece made again meanwhile can't hide skin masks
 * made before; the garments by a change since this last looked.
 */
/datum/component/dirtiness/proc/check_parts()
	var/mob/living/carbon/human/body = parent
	if(!mess_count())
		return
	var/current = dirt_body_parts_key(dirt_body_parts(body))
	var/stale = current != parts_key || (skin?.request && skin.parts_key != current)
	parts_key = current
	for(var/key, drawing in underclothes_drawings)
		if(stale)
			break
		var/datum/dirt_drawing/drawn = drawing
		stale = drawn.request && drawn.parts_key != current
	if(stale)
		parts_changed()

/**
 * Has every mask a body's parts shape made again, the old ones drawn meanwhile: the skin's, the underclothes', and the
 * garments' it wears, which their own draws make again. Draws the body.
 */
/datum/component/dirtiness/proc/parts_changed()
	var/mob/living/carbon/human/body = parent
	skin?.forget(FALSE)
	forget_underclothes_masks()
	for(var/datum/component/dirtiness/carrier as anything in dirt_mess_carriers(body))
		if(carrier != src && length(carrier.mess_splats))
			var/obj/item/garment = carrier.parent
			garment.update_slot_icon()
	body.update_body_parts()

/**
 * Has every piece of underclothes' masks made again for what's drawn now: its splats stay with it, worn or not.
 * Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - drop_masks: Whether to stop drawing the masks made before, which no longer fit the body.
 */
/datum/component/dirtiness/proc/forget_underclothes_masks(drop_masks = FALSE)
	for(var/key, drawing in underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		drawn.forget(drop_masks)

/**
 * Has the skin's masks made again if what the body wears over its skin changed since they were asked for, so its mess
 * fades out beside what it wears now, and draws the body.
 */
/datum/component/dirtiness/proc/check_cover()
	var/mob/living/carbon/human/body = parent
	if(!length(mess_splats) || (skin?.request && cover_key == dirt_sprites_key(dirt_cover_sprites(body))))
		return
	skin?.forget(FALSE)
	body.update_body_parts()

/**
 * Has the masks made again for the body a limb attached to the person makes, every limb shaping the others'
 * silhouettes, and gives the limb a skin overlay if skin mess draws on it, and the chest the underclothes overlay. The
 * attach draws the body.
 *
 * Arguments:
 * - source: The person.
 * - limb: The limb being attached.
 * - special: Whether it's swapped without the usual effects.
 * - lazy: Whether the person is still being made.
 */
/datum/component/dirtiness/proc/on_limb_attached(mob/living/carbon/human/source, obj/item/bodypart/limb, special, lazy)
	SIGNAL_HANDLER
	if(IS_STUMP(limb))
		return
	forget_underclothes_masks(TRUE)
	if(length(underclothes_splats) && limb.body_zone == BODY_ZONE_CHEST)
		underclothes_overlay?.carrier = null
		underclothes_overlay = new(src)
		limb.add_bodypart_overlay(underclothes_overlay, update = FALSE)
	if(!length(mess_splats))
		return
	skin?.forget(TRUE)
	if(!(limb.body_zone in dirt_skin_zones()))
		return
	var/datum/bodypart_overlay/dirt_skin/old_overlay = skin_overlays[limb.body_zone]
	old_overlay?.carrier = null
	var/datum/bodypart_overlay/dirt_skin/overlay = new(src)
	limb.add_bodypart_overlay(overlay, update = FALSE)
	skin_overlays[limb.body_zone] = overlay

/**
 * Takes the skin overlay off a limb leaving the person, whose mess stays with them, lets go of it and of the eyes it
 * may take (forget_skin_reads()), and has the masks made again for the body left. The removal draws the body.
 *
 * Arguments:
 * - source: The person.
 * - limb: The limb being removed.
 * - special: Whether it's swapped without the usual effects.
 * - dismembered: Whether it was cut off.
 */
/datum/component/dirtiness/proc/on_limb_removed(mob/living/carbon/human/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER
	forget_skin_reads()
	if(length(mess_splats))
		skin?.forget(TRUE)
	forget_underclothes_masks(TRUE)
	if(underclothes_overlay && (underclothes_overlay in limb.bodypart_overlays))
		limb.remove_bodypart_overlay(underclothes_overlay, update = FALSE)
		underclothes_overlay.carrier = null
		underclothes_overlay = null
	var/datum/bodypart_overlay/dirt_skin/overlay = skin_overlays[limb.body_zone]
	if(!overlay || !(overlay in limb.bodypart_overlays))
		return
	limb.remove_bodypart_overlay(overlay, update = FALSE)
	overlay.carrier = null
	skin_overlays -= limb.body_zone
