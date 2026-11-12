/**
 * The dirt a person or an item carries, as splats. Mess splats are each a variant of a zone's mess at a level. General
 * deposits are each a variant of a cause's dirt in a material, on some limbs. SSdirt makes the masks they draw with. A
 * person's skin splats draw through one /datum/bodypart_overlay/dirt_skin on each limb they lie on, under what the
 * person wears, and fade out beside it. The splats on their underclothes are kept with each piece. While the piece is
 * worn and shows, they draw over it through one /datum/bodypart_overlay/dirt_underclothes on the chest. The splats on a
 * person's parts draw with each part's own front layer. A taur body's pools and general deposits draw with its own
 * images. The splats of tails, wings, ears, horns and other drawn parts draw with each part's images (appendages.dm).
 * The hair's draw over the hair while it shows (hair.dm). A garment's splats draw inset over it while a person wears
 * it. A taur suit's back splats and general deposits draw on the taur canvas round it too. The parts that a surface's
 * mess reaches shape it (dirt_surface_parts()). Washing clears it, as it clears the floor's decals.
 */
/datum/component/dirtiness
	/// This carrier's splats (/datum/dirt_splat) on a person's skin or an item's cloth, mess and general deposits
	/// alike, oldest first.
	var/list/mess_splats = list()
	/// A person's parts' splats: alist(ORGAN_SLOT_* = list of /datum/dirt_splat, oldest first). The taur body's pools are
	/// ORGAN_SLOT_EXTERNAL_TAUR's.
	var/alist/part_mess_splats = alist()
	/// The general deposits on a person's drawn parts, each part a carrier of its own: alist(ORGAN_SLOT_* = list of
	/// /datum/dirt_splat, oldest first), or null while there are none. The parts are the taur body, a tail, wings,
	/// ears, horns and the like, and the hair under DIRT_CARRIER_HAIR.
	var/alist/part_splats
	/// alist(ORGAN_SLOT_* = /datum/dirt_drawing): each part with splats' own masks, made again when its sprite changes.
	var/alist/part_drawings
	/// The body's parts as dirt_body_parts_key() wrote them when check_parts() last looked. A change since then draws
	/// the garments the body wears again, and they check their own masks as they draw. Before check_parts() first
	/// looks, it holds the parts the first skin or underclothes masks were asked for with. Or it holds the parts the
	/// body drew when a part's splats first changed. A wash lets it go, so the next dirt starts it afresh.
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
	/// What skin_hidden() last read, or null to read it again: list(the body's overlays_standing[UNIFORM_LAYER], its
	/// [SUIT_LAYER] entry, the organ in its taur body's slot or null, whether dirt_body_hidden() found the body hidden,
	/// the icon the uniform's entry draws or null, the suit's, whether either icon isn't 32x32).
	var/list/hidden_read
	/// What the taur body's rider was drawn from when it last matched the request of the taur body's masks
	/// (rider_unchanged()), for rider_reads_for: alist(body zone = /obj/item/bodypart/proc/dirt_sprite_reads(), or null
	/// with no limb, "eyes" = dirt_eye_reads()).
	var/alist/rider_reads
	/// The taur body's request that rider_reads were read for. A different request has them read again.
	var/datum/dirt_mask_request/rider_reads_for
	/// The zone sources the garments a person wears ask for their masks with (dirt_worn_sources()), or null. It can
	/// also hold a garment's zone sources that matched in full (dirt_worn_sources_match()).
	var/list/worn_sources
	/// What every limb and the eyes were drawn from when worn_sources were noted (dirt_body_reads()), or null.
	var/alist/worn_reads
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
	/// Blood run down below a taur's waist from its garment's stain, while there is some. A person's draws on their
	/// taur body (ready_taur_blood_masks()), and a taur-fitted garment's on its cloth (ready_taur_blood_cloth_masks()).
	/// It's never stored otherwise, because it's drawn from the garments' own blood.
	var/datum/dirt_drawing/taur_blood
	/// On a taur-fitted garment, whether its last draw put taur_blood, the blood run down onto its cloth, over its dirt
	/// (dirt_cloth_run_over()).
	var/cloth_run_over = FALSE
	/// On a person, the serial of the newest mess or general deposit landed or raised on their taur body, or null.
	var/taur_dirt_landed
	/// On a person, the serial of the newest blood seen landing on a uniform or suit of theirs whose stain runs below
	/// their taur waist (note_waist_blood()), or null.
	var/waist_blood_landed
	/// The blood DNA list note_waist_blood() last saw on the person's suit, which a merge of more blood replaces.
	var/list/suit_blood_seen
	/// The blood DNA list note_waist_blood() last saw on the person's uniform.
	var/list/uniform_blood_seen
	/// On an item, the serial (/datum/controller/subsystem/dirt/proc/next_serial()) of its newest visible blood landing,
	/// or null.
	var/blood_landed
	/// On an item, the serial of the newest mess or general deposit landed or raised on its cloth, or null. A wet
	/// material (sweat) isn't counted.
	var/dirt_landed
	/// A person's dirtier side, 1 or -1, or null until it's picked at random on first use (dirtier_side()). Every
	/// general deposit on them and on what they wear draws on it. Mess never asks, so it spends no random draw.
	var/side
	/// How many times a slot that covers skin has changed on the person (on_overlay_changed()). A part whose masks
	/// follow what's worn over its zone reads it to know whether to look again (ready_part_masks()).
	var/worn_changes = 0

/datum/dirt_drawing
	/// For a part drawn at more than one layer, or the vulva, its carrier's worn_changes when its masks were last
	/// matched to what's worn over its zone (/datum/component/dirtiness/proc/ready_part_masks()).
	var/worn_seen

/datum/component/dirtiness/Initialize()
	if(!ishuman(parent) && !isitem(parent))
		return COMPONENT_INCOMPATIBLE

/// Returns the person's dirtier side, 1 or -1 (/datum/component/dirtiness/var/side), picking it on first use.
/datum/component/dirtiness/proc/dirtier_side()
	side ||= pick(1, -1)
	return side

/datum/component/dirtiness/RegisterWithParent()
	RegisterSignal(parent, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	if(ishuman(parent))
		RegisterSignal(parent, COMSIG_CARBON_ATTACH_LIMB, PROC_REF(on_limb_attached))
		RegisterSignal(parent, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_limb_removed))
		RegisterSignals(parent, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY), PROC_REF(on_overlay_changed))
		RegisterSignal(parent, COMSIG_HUMAN_GENITAL_UPDATED, PROC_REF(on_genital_updated))
		RegisterSignal(parent, COMSIG_CARBON_GAIN_ORGAN, PROC_REF(on_organ_gained))
		RegisterSignal(parent, COMSIG_CARBON_LOSE_ORGAN, PROC_REF(on_organ_lost))
		// blood already on what they wear landed before any dirt this carrier will hold
		note_waist_blood(parent, stamp = FALSE)
		return
	RegisterSignal(parent, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS, PROC_REF(on_worn_overlays))

/datum/component/dirtiness/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_ATOM_EXAMINE, COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVE_LIMB, COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY, COMSIG_HUMAN_GENITAL_UPDATED, COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN, COMSIG_ITEM_GET_SEPARATE_WORN_OVERLAYS, COMSIG_ITEM_DROPPED))
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
	drop_drawing_jobs()
	skin = null
	forget_skin_reads(worn = TRUE)
	underclothes_drawings = null
	drop_wags()
	part_drawings = null
	cloth = null
	taur_cloth = null
	taur_blood = null
	return ..()

/**
 * Puts a mess on a zone of this carrier: its skin or cloth, or the part in an organ slot. As a shot lands it, the
 * levels go on the zone's newest splat, up to DIRT_MESS_MAX_LEVEL. What's left starts another splat with that many
 * levels, at most the top one. The new splat takes a variant this carrier doesn't have on that zone yet, if there's
 * one. A splat raised keeps its place and counts as landed now (/datum/dirt_splat/var/last_serial). A variant given
 * places a new splat at `levels` with that variant.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - organ_slot: The part's ORGAN_SLOT_* define, or null for the skin or cloth.
 * - levels: How many levels it adds, 1 or more.
 * - variant: 0 to DIRT_VARIANTS - 1, or null.
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
	if(touched)
		if(isitem(parent))
			dirt_landed = touched.last_serial
		else if(organ_slot == ORGAN_SLOT_EXTERNAL_TAUR)
			taur_dirt_landed = touched.last_serial
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
 * - variant: 0 to DIRT_VARIANTS - 1, or null.
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
			// a general deposit has no zone, so mess never stacks on one
			if(newest.zone != zone)
				continue
			var/risen = min(levels, DIRT_MESS_MAX_LEVEL - newest.level)
			if(risen > 0)
				newest.level += risen
				newest.last_serial = SSdirt.next_serial()
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
 * Puts a general deposit on this carrier's skin or cloth, or on a person's drawn part in an organ slot, as dirt_land()
 * lands it (stack_dirt()). It draws nothing, as dirt_land() draws once every carrier it changed (dirt_draw_landing()).
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its material as a splat stores it (/datum/dirt_material/var/key).
 * - level: Its level, 1 up to the cause's top. A level under 1 counts as 1.
 * - limbs: The limbs it covers here, DIRT_LIMB_BIT() of each, or NONE on a drawn part, which has no limbs.
 * - variant: 0 to DIRT_VARIANTS - 1, for a deposit it starts, or null for one at random.
 * - organ_slot: The drawn part's ORGAN_SLOT_* define (part_splats), or null for the skin or cloth.
 *
 * Returns the deposit it started or raised.
 */
/datum/component/dirtiness/proc/add_dirt(cause, material, level, limbs, variant, organ_slot = null)
	RETURN_TYPE(/datum/dirt_splat)
	var/list/splats = mess_splats
	if(organ_slot)
		part_splats ||= alist()
		splats = (part_splats[organ_slot] ||= list())
	var/datum/dirt_splat/touched = stack_dirt(splats, cause, material, level, limbs, variant)
	if(isitem(parent))
		// a wet material darkens the cloth through its multiplier, which never draws over the blood stain
		if(!(dirt_material(material)?.flags & DIRT_MATERIAL_WET))
			dirt_landed = touched.last_serial
	else if(organ_slot == ORGAN_SLOT_EXTERNAL_TAUR)
		taur_dirt_landed = touched.last_serial
	return touched

/**
 * Puts a general deposit on the underclothes a person wears in a slot, as add_dirt() puts it on the skin. Like
 * add_dirt(), it draws nothing. It stays with that piece, kept while it's off or hidden.
 *
 * Arguments:
 * - piece: A DIRT_UNDERCLOTHES_* define the person wears.
 * - cause, material, level, limbs, variant: As add_dirt()'s.
 *
 * Returns the deposit it started or raised, or null when the person doesn't wear that piece.
 */
/datum/component/dirtiness/proc/add_underclothes_dirt(piece, cause, material, level, limbs, variant)
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/sprite_accessory/accessory = dirt_underclothes_worn(parent)[piece]
	if(!accessory)
		return null
	underclothes_splats ||= alist()
	var/list/splats = (underclothes_splats[dirt_underclothes_key(piece, accessory.name)] ||= list())
	return stack_dirt(splats, cause, material, level, limbs, variant)

/**
 * Adds a general deposit to one surface's splats, and returns the deposit it started or raised. If a deposit there has
 * the same cause and material, it takes the new one. Its level rises by the new one's, up to the cause's top
 * (dirt_cause_max_level()). It keeps its variant and its place, covers the new limbs too, and counts as landed now
 * (/datum/dirt_splat/var/last_serial). Else a new deposit starts. Past DIRT_CARRIER_DEPOSITS general deposits on the
 * surface, the one that landed longest ago goes. Mess there neither takes it nor counts.
 *
 * Arguments:
 * - splats: The surface's splats, in the order they first landed. Changed.
 * - cause, material, level, limbs, variant: As add_dirt()'s.
 */
/datum/component/dirtiness/proc/stack_dirt(list/splats, cause, material, level, limbs, variant)
	RETURN_TYPE(/datum/dirt_splat)
	var/top = dirt_cause_max_level(cause)
	// whole and 1 at least, as dirt_land() takes a level
	level = isnum(level) ? max(1, floor(level)) : 1
	var/deposits = 0
	var/datum/dirt_splat/oldest
	for(var/datum/dirt_splat/splat as anything in splats)
		if(!splat.cause)
			continue
		if(splat.cause == cause && splat.material == material)
			splat.level = min(splat.level + level, top)
			splat.limbs |= limbs
			splat.last_serial = SSdirt.next_serial()
			return splat
		deposits++
		if(!oldest || splat.last_serial < oldest.last_serial)
			oldest = splat
	if(deposits >= DIRT_CARRIER_DEPOSITS)
		splats -= oldest
	// the variant keys and seeds the deposit's raster
	variant = isnum(variant) ? clamp(floor(variant), 0, DIRT_VARIANTS - 1) : rand(0, DIRT_VARIANTS - 1)
	var/datum/dirt_splat/started = new(null, min(level, top), variant, SSdirt.next_serial(), cause, material, limbs)
	splats += started
	return started

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
	for(var/variant in 0 to DIRT_VARIANTS - 1)
		unused += variant
	for(var/datum/dirt_splat/splat as anything in splats)
		if(splat.zone == zone)
			unused -= splat.variant
	return length(unused) ? pick(unused) : rand(0, DIRT_VARIANTS - 1)

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
	// a part's mess, then its general deposits
	for(var/alist/slots as anything in list(part_mess_splats, part_splats))
		for(var/organ_slot, splats in slots)
			var/list/slot_splats = splats
			if(splat in slot_splats)
				slot_splats -= splat
				if(!length(slot_splats))
					slots -= organ_slot
				if(redraw)
					mess_changed(organ_slot)
				return organ_slot
	for(var/key, splats in underclothes_splats)
		var/list/piece_splats = splats
		if(splat in piece_splats)
			piece_splats -= splat
			if(!length(piece_splats))
				underclothes_splats -= key
				var/datum/dirt_drawing/piece_drawing = underclothes_drawings?[key]
				piece_drawing?.drop_jobs(parent)
				LAZYREMOVE(underclothes_drawings, key)
			if(redraw)
				mess_changed()
			return null
	return null

/**
 * Takes all of this carrier's splats off. An item's carrier is then deleted unless it still draws blood below a taur's
 * waist. If `redraw` is set, mess_changed() deletes it, as it deletes one the cap empties. If not, as when a wash
 * clears an item, it's deleted once it holds nothing (holds_nothing()). A person's stays and keeps its dirtier side,
 * since what they wear may still draw on it.
 *
 * Arguments:
 * - redraw: Whether to draw the change. Washing an item draws its slot itself.
 */
/datum/component/dirtiness/proc/clear_mess(redraw = TRUE)
	var/parts_had_mess = length(part_mess_splats) || length(part_splats)
	mess_splats.Cut()
	part_mess_splats = alist()
	part_splats = null
	drop_wags()
	drop_drawing_jobs()
	part_drawings = null
	underclothes_splats = null
	underclothes_drawings = null
	skin?.forget(TRUE)
	forget_skin_reads()
	cloth = null
	taur_cloth = null
	parts_key = null
	if(redraw)
		mess_changed(null, parts_had_mess)
	else if(isitem(parent) && holds_nothing())
		qdel(src)

/**
 * Takes a part's splats and masks off, as it leaves the body, and drops its queued jobs as drop_drawing_jobs() drops
 * them. Its leaving draws the body.
 *
 * Arguments:
 * - organ_slot: The part's ORGAN_SLOT_* define.
 */
/datum/component/dirtiness/proc/drop_part(organ_slot)
	part_mess_splats -= organ_slot
	LAZYREMOVE(part_splats, organ_slot)
	var/datum/dirt_drawing/drawing = part_drawings?[organ_slot]
	drawing?.drop_wag(parent)
	drawing?.drop_jobs(parent)
	LAZYREMOVE(part_drawings, organ_slot)

/// Stops every part drawing its wag, as the parts' drawings are let go (/datum/dirt_drawing/proc/drop_wag()).
/datum/component/dirtiness/proc/drop_wags()
	for(var/organ_slot, drawing in part_drawings)
		var/datum/dirt_drawing/drawn = drawing
		drawn.drop_wag(parent)

/**
 * Drops the queued jobs of this carrier's drawings as a wash or its deletion lets them go, as drop_wags() drops wags'.
 * It keeps a job that another body still waits for (/datum/controller/subsystem/dirt/proc/drop_mask_job()). On a
 * person they're the skin's, underclothes', parts' and taur blood's masks, which the person waits for. On a worn item
 * they're its cloth's, taur cloth's and taur blood's, which its wearer (the person it's on) waits for. Each drawing's
 * job goes with the job of the request a newer one replaced (/datum/dirt_drawing/proc/drop_jobs()). So does the job
 * of the sweat multiplier the drawing last asked for. An item on no person keeps its jobs, because whoever wore it may
 * still wait for them.
 */
/datum/component/dirtiness/proc/drop_drawing_jobs()
	var/mob/living/carbon/human/waiter = parent
	if(isitem(parent))
		var/obj/item/garment = parent
		waiter = garment.loc
	if(!ishuman(waiter))
		return
	var/list/drawings = list(skin, cloth, taur_cloth, taur_blood)
	for(var/organ_slot, part_drawing in part_drawings)
		drawings += part_drawing
	for(var/key, piece_drawing in underclothes_drawings)
		drawings += piece_drawing
	// a typed loop, so it skips the drawings this carrier lacks, which are null
	for(var/datum/dirt_drawing/drawing in drawings)
		drawing.drop_jobs(waiter)

/// Returns how many splats this carrier holds, parts and underclothes included.
/datum/component/dirtiness/proc/mess_count()
	. = length(mess_splats)
	for(var/alist/slots as anything in list(part_mess_splats, part_splats))
		for(var/organ_slot, splats in slots)
			var/list/slot_splats = splats
			. += length(slot_splats)
	for(var/key, splats in underclothes_splats)
		var/list/piece_splats = splats
		. += length(piece_splats)

/**
 * Returns whether this carrier holds nothing worth keeping it for: no splats, no drawing of any surface (blood below a
 * taur's waist included), nothing drawn on a limb and no dirtier side picked. A person's skin drawing is made when the
 * skin first asks for masks, and stays until the carrier is destroyed. So a person whose skin has drawn dirt never
 * holds nothing. If a carrier on a person, their uniform or their suit holds nothing, the person's next cover check
 * deletes it (check_taur_blood()), whatever made it. While blood runs below a taur's waist, that check keeps the
 * person's carrier and the taur-fitted garment's. A garment's is also deleted as it's taken off after drawing that
 * blood (on_dropped()). An item's is deleted as soon as a wash, Clear Dirt or the cap leaves it no splats and no such
 * blood (clear_mess(), mess_changed()).
 */
/datum/component/dirtiness/proc/holds_nothing()
	return !mess_count() && !side && !skin && !cloth && !taur_cloth && !taur_blood && !length(part_drawings) && !length(underclothes_drawings) && !underclothes_overlay && !length(skin_overlays)

/// Returns this carrier's splat that landed longest ago, parts and underclothes included, or null with none. A splat
/// raised in place counts as landed when it was raised (/datum/dirt_splat/var/last_serial).
/datum/component/dirtiness/proc/oldest_mess()
	RETURN_TYPE(/datum/dirt_splat)
	var/datum/dirt_splat/oldest
	var/list/surfaces = list(mess_splats)
	for(var/alist/slots as anything in list(part_mess_splats, part_splats))
		for(var/organ_slot, splats in slots)
			surfaces += list(splats)
	for(var/key, splats in underclothes_splats)
		surfaces += list(splats)
	for(var/list/splats as anything in surfaces)
		for(var/datum/dirt_splat/splat as anything in splats)
			if(!oldest || splat.last_serial < oldest.last_serial)
				oldest = splat
	return oldest

/**
 * Draws a change to this carrier's splats: a person's skin and underclothes, a part of theirs, or an item's slot while
 * it's worn. A part's change redraws the whole body. A portal relay drawing the part, or a bulge look drawing it behind
 * a cover, follows that redraw. An item's carrier left with no splats and no blood below a taur's waist is deleted.
 * While it's on a person, its queued jobs go with it (Destroy()). One left drawing that blood alone lets go of its
 * cloth's masks and their jobs. So it's deleted once that blood is dropped too (on_dropped(), check_taur_blood()).
 *
 * Arguments:
 * - organ_slot: The part whose splats changed, or null for the rest.
 * - parts_too: Whether parts' splats changed with the rest (a wash), so the whole body is drawn again.
 * - draw: Whether to draw a person now. A caller changing several of their surfaces at once draws them once after.
 */
/datum/component/dirtiness/proc/mess_changed(organ_slot = null, parts_too = FALSE, draw = TRUE)
	if(organ_slot)
		var/datum/dirt_drawing/drawing = part_drawings?[organ_slot]
		if(drawing)
			var/emptied = !length(part_mess_splats[organ_slot]) && !length(part_splats?[organ_slot])
			drawing.forget(emptied)
			// the wag's frames came from the old splats, so their job goes now if none are left, else once different
			// frames are asked for
			if(emptied)
				drawing.drop_wag(parent)
				// no masks are asked for until dirt lands again, so no current() would drop these jobs
				drawing.drop_jobs(parent)
			else
				drawing.wag?.forget(TRUE)
		var/mob/living/carbon/human/owner = parent
		if(!istype(owner))
			return
		parts_key ||= dirt_body_parts_key(dirt_body_parts(owner))
		if(draw)
			owner.update_body()
		return
	if(isitem(parent))
		var/obj/item/garment = parent
		if(length(mess_splats))
			cloth?.forget(FALSE)
			taur_cloth?.forget(FALSE)
		else if(taur_blood)
			// let go as a wash lets go, so the carrier holds nothing once its blood goes too (holds_nothing())
			var/mob/living/carbon/human/wearer = garment.loc
			if(ishuman(wearer))
				cloth?.drop_jobs(wearer)
				taur_cloth?.drop_jobs(wearer)
			cloth = null
			taur_cloth = null
		else
			qdel(src)
		garment.update_slot_icon()
		return
	var/mob/living/carbon/human/body = parent
	skin?.forget(!length(mess_splats))
	if(!length(mess_splats))
		// no masks are asked for until dirt lands again, so no current() would drop these jobs
		skin?.drop_jobs(body)
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
 * Puts a skin overlay on each limb the skin's splats lie on (skin_limbs()), and takes them off once they don't.
 * Nothing is drawn until the body's next update_body_parts().
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/sync_skin_overlays(mob/living/carbon/human/body)
	var/limbs = skin_limbs()
	for(var/zone, zone_limbs in dirt_skin_zone_limbs())
		var/carries = limbs & zone_limbs
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		var/datum/bodypart_overlay/dirt_skin/overlay = skin_overlays[zone]
		if(overlay && (!carries || !limb || !(overlay in limb.bodypart_overlays)))
			if(limb && (overlay in limb.bodypart_overlays))
				limb.remove_bodypart_overlay(overlay, update = FALSE)
			overlay.carrier = null
			skin_overlays -= zone
			overlay = null
		if(carries && limb && !overlay)
			overlay = dirt_skin_overlay(zone, src)
			limb.add_bodypart_overlay(overlay, update = FALSE)
			skin_overlays[zone] = overlay

/**
 * Returns the limbs the skin's splats lie on, DIRT_LIMB_BIT() of each. A general deposit lies on its own limbs, and
 * mess on DIRT_MESS_SKIN_LIMBS, where aimed mess draws.
 */
/datum/component/dirtiness/proc/skin_limbs()
	. = NONE
	for(var/datum/dirt_splat/splat as anything in mess_splats)
		. |= splat.cause ? (splat.limbs || DIRT_LIMBS_ALL) : DIRT_MESS_SKIN_LIMBS

/// Returns the limbs the skin's general deposits lie on, DIRT_LIMB_BIT() of each, or NONE while it holds none.
/datum/component/dirtiness/proc/deposit_limbs()
	. = NONE
	for(var/datum/dirt_splat/splat as anything in mess_splats)
		if(splat.cause)
			. |= splat.limbs || DIRT_LIMBS_ALL

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
 * Returns the masks the skin's splats are drawn with on a limb, or null while there are none to draw. The first ask
 * after a change queues them with SSdirt, which draws the body again once they're made. Until then the masks before
 * them are drawn, so mess already there stays while more is added. Masks made for other sprites than the body draws (a
 * new size, a swapped limb, other eyes) are dropped and made again. On every draw, each limb that skin mess draws on
 * checks its own sprites, and the chest also checks the arms, the hands and the eyes. Each is read again only once what
 * it's drawn from has changed since it last matched (skin_reads), so a steady draw compares a few vars. The masks fade
 * out beside what the body wears (dirt_cover_sprites()). The parts the splats reach shape them (dirt_surface_parts()),
 * as each part draws over or under the skin in each direction: every front image over it, and a butt's back image and
 * the pecs guide under it. General deposits draw on the person's dirtier side, and on a bare body (dirt_bare_bodied())
 * as their painted designs. The parts drawn over the skin take them on their own pixels (dirt_parts_over()), drawn with
 * each part. A body hidden under a worn sprite larger than its tile (skin_hidden()) draws none. Its request is made,
 * but no masks are.
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
		var/general_limbs = deposit_limbs()
		var/painted = general_limbs && dirt_bare_bodied(body)
		skin.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, zone_sources, DIRT_SURFACE_SKIN, mess_splats, dirt_surface_parts(body_parts, mess_splats), cover = cover, surface_layer = DIRT_SKIN_LAYER, side = general_limbs ? dirtier_side() : 1, painted = painted, deposit_parts = general_limbs ? dirt_parts_over(body_parts, DIRT_SKIN_LAYER, general_limbs) : null), dirt_body_parts_key(body_parts))
		parts_key ||= skin.parts_key
		// read from the body just now, with nothing between that changes a limb, so the draws after only compare
		note_skin_reads(body, GLOB.all_body_zones, TRUE)
	if(skin_hidden(body))
		// current() isn't reached, so the job of the request before goes here as it would there
		if(skin.superseded_key != skin.key)
			SSdirt.drop_mask_job(skin.superseded_key, body, DIRT_REDRAW_BODY)
		skin.superseded_key = null
		return null
	return skin.current(body, DIRT_REDRAW_BODY)

/**
 * Returns whether the body is hidden under a worn sprite larger than its tile (dirt_body_hidden()). The answer is read
 * once and kept with everything it was read from (hidden_read). That's the uniform's and suit's entries in
 * overlays_standing, and the organ in the taur body's slot, which decides whether a wide suit is a taur suit. Once an
 * entry isn't the same one, as after every worn redraw of its slot, the icon each entry draws is read.
 * dirt_body_hidden() reads only those icons' sizes, and the organ for an icon that isn't 32x32. So the same icons give
 * the same answer, with the same organ where an icon isn't 32x32. The answer is read again only once any of those
 * differs. The organ is read from the slot list itself, as get_organ_slot() reads it. A taur body joining or leaving
 * drops it too, letting go of the organ.
 *
 * Arguments:
 * - body: The person.
 */
/datum/component/dirtiness/proc/skin_hidden(mob/living/carbon/human/body)
	var/uniform = body.overlays_standing[UNIFORM_LAYER]
	var/suit = body.overlays_standing[SUIT_LAYER]
	if(hidden_read && hidden_read[1] == uniform && hidden_read[2] == suit && (!hidden_read[7] || hidden_read[3] == body.organs_slot[ORGAN_SLOT_EXTERNAL_TAUR]))
		return hidden_read[4]
	var/taur_body = body.organs_slot[ORGAN_SLOT_EXTERNAL_TAUR]
	var/image/uniform_leaf = bulge_drawn_leaf(bulge_drawn_root(uniform))
	var/image/suit_leaf = bulge_drawn_leaf(bulge_drawn_root(suit))
	var/uniform_icon = uniform_leaf?.icon
	var/suit_icon = suit_leaf?.icon
	var/same_icons = hidden_read && hidden_read[5] == uniform_icon && hidden_read[6] == suit_icon
	// only an icon that isn't 32x32 has dirt_body_hidden() read the organ (dirt_taur_suit_sprite())
	var/off_tile = same_icons && hidden_read[7]
	if(!same_icons)
		for(var/drawn_icon in list(uniform_icon, suit_icon))
			var/list/size = drawn_icon && get_icon_dimensions(drawn_icon)
			off_tile ||= size && (size["width"] != ICON_SIZE_X || size["height"] != ICON_SIZE_Y)
	var/hidden = (same_icons && (!off_tile || hidden_read[3] == taur_body)) ? hidden_read[4] : dirt_body_hidden(body)
	hidden_read = list(uniform, suit, taur_body, hidden, uniform_icon, suit_icon, off_tile)
	return hidden

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

/**
 * Drops what the skin's sprites and the taur body's rider were last read from (skin_reads, rider_reads), and whether
 * the body was hidden (hidden_read). They hold the limbs, eyes and worn sprites read. Once they're dropped, nothing
 * that leaves the body is kept by them. The next draw reads them again.
 *
 * Arguments:
 * - worn: Whether to drop what the garments' wearer was read from too (worn_sources, worn_reads), as a limb or the eyes
 *   leave or the carrier goes. Any other change is caught as the next draw compares them (body_reads_steady()).
 */
/datum/component/dirtiness/proc/forget_skin_reads(worn = FALSE)
	skin_reads = null
	skin_reads_for = null
	hidden_read = null
	rider_reads = null
	rider_reads_for = null
	if(worn)
		worn_sources = null
		worn_reads = null

/**
 * Returns the masks of each piece of a person's underclothes that has some drawn and is worn and shows now, asking for
 * those not made yet as ready_skin_masks() does. Each is cloth's, kept to the pixels the piece shows, under those drawn
 * over it, and shaped by the parts its splats reach (dirt_surface_parts()): pecs under a tank top, or a genital set to
 * draw below the underwear. Underwear takes the skin's general dirt, as the skin draws it, painted on a bare body. The
 * other pieces take cloth's. A piece that's off or hidden keeps its splats but draws none.
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
			var/piece
			for(var/list/entry as anything in drawn)
				if(clip)
					cut += list(list(entry[2], entry[3]))
				else if(dirt_underclothes_key(entry[1], entry[4]) == key)
					clip = list(list(entry[2], entry[3]))
					piece = entry[1]
			if(!clip)
				drawing.forget(TRUE)
				// no masks are asked for while it's absent, so no current() would drop these jobs
				drawing.drop_jobs(body)
				drawing.absent = TRUE
				continue
			if(isnull(body_parts))
				body_parts = dirt_body_parts(body)
				body_parts_key = dirt_body_parts_key(body_parts)
			var/underwear = piece == DIRT_UNDERCLOTHES_UNDERWEAR
			var/general = dirt_holds_deposits(splats)
			var/painted = underwear && general && dirt_bare_bodied(body)
			drawing.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, dirt_zone_sources(body), DIRT_SURFACE_CLOTH, splats, dirt_surface_parts(body_parts, splats), clip = clip, cut = cut, surface_layer = DIRT_UNDERCLOTHES_LAYER, side = general ? dirtier_side() : 1, painted = painted, deposit_surface = underwear ? DIRT_SURFACE_SKIN : null), body_parts_key)
			parts_key ||= body_parts_key
		var/datum/dirt_masks/masks = drawing.current(body, DIRT_REDRAW_BODY)
		if(masks)
			. += masks

/**
 * Returns the masks a worn item's cloth is drawn with on its wearer, or null while there are none to draw, asking for
 * them as ready_skin_masks() does. Masks made for a body drawn from other sprites (another wearer, other eyes) are
 * dropped and made again, as are general deposits' masks made for another wearer's dirtier side. A change to the parts
 * its splats reach (dirt_surface_parts()) makes them again too, and the old ones are drawn meanwhile. A taur suit's
 * masks are those of its upper part, over the rider on the body's tile. Its general deposits draw there as on any
 * garment, beside its hem band on the taur canvas (ready_taur_cloth_masks()). The upper part leaves out the legs'
 * share of walking, crawling and dust. The hem band draws that share as the taur body's contact coat. Masks asked for
 * while the item is drawn as a taur suit are made again once it isn't, and the other way round.
 *
 * Arguments:
 * - garment: The item.
 * - wearer: Who wears it.
 * - taur_suit: Whether it's drawn as a taur suit (dirt_taur_suit_sprite()).
 */
/datum/component/dirtiness/proc/ready_cloth_masks(obj/item/garment, mob/living/carbon/human/wearer, taur_suit = FALSE)
	RETURN_TYPE(/datum/dirt_masks)
	if(!length(mess_splats))
		return null
	cloth ||= new
	var/slot = wearer.get_slot_by_item(garment)
	var/surface_layer = dirt_slot_layer(slot)
	var/list/reached = list()
	// a part lies on the chest, the groin or the butt (dirt_part_zone()), so only a splat there can reach one
	for(var/datum/dirt_splat/splat as anything in mess_splats)
		if(splat.zone == DIRT_ZONE_CHEST || splat.zone == DIRT_ZONE_GROIN || splat.zone == DIRT_ZONE_BUTT)
			reached = dirt_surface_parts(dirt_body_parts(wearer), mess_splats)
			break
	var/reached_key = dirt_parts_key(reached, surface_layer)
	if(taur_suit)
		reached_key += "|taur suit"
	var/wearer_side = dirt_holds_deposits(mess_splats) ? dirt_wearer_side(wearer) : 1
	if(cloth.request && (!dirt_worn_sources_match(wearer, cloth.request.zone_sources) || cloth.request.side != wearer_side))
		cloth.forget(TRUE)
	else if(cloth.request && cloth.parts_key != reached_key)
		cloth.forget(FALSE)
	if(!cloth.request)
		// a taur suit's upper part with nothing to draw stays absent until a change to its splats forgets the drawing
		if(taur_suit && cloth.absent)
			return null
		var/list/splats = mess_splats
		if(taur_suit)
			splats = list()
			var/legs = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG)
			for(var/datum/dirt_splat/splat as anything in mess_splats)
				// the hem band draws the legs' share of these as the taur body's coat
				if(!splat.cause || !dirt_taur_coat_cause(splat.cause) || !dirt_taur_takes(splat.cause, dirt_material(splat.material)))
					splats += splat
					continue
				var/upper_limbs = (splat.limbs || DIRT_LIMBS_ALL) & ~legs
				if(upper_limbs)
					splats += new /datum/dirt_splat(splat.zone, splat.level, splat.variant, splat.serial, splat.cause, splat.material, upper_limbs)
			if(!length(splats))
				// no masks are asked for while the upper part draws none, so no current() would drop these jobs
				cloth.drop_jobs(wearer)
				cloth.forget(TRUE)
				cloth.absent = TRUE
				return null
		cloth.start(new /datum/dirt_mask_request(DIRT_MASKS_BODY, dirt_worn_sources(wearer), DIRT_SURFACE_CLOTH, splats, reached, surface_layer = surface_layer, side = wearer_side), reached_key)
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
	// a butt's or the vulva's masks also follow what's worn over its zone, so they hold while nothing worn has changed
	var/datum/dirt_mask_request/asked = drawing.request
	if(asked?.part_source == source && drawing.worn_seen == worn_changes && (asked.surface_kind != DIRT_SURFACE_SKIN || source.kind != DIRT_PART_VAGINA || dirt_zone_sources_match(body, asked.zone_sources)))
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
	drawing.worn_seen = worn_changes
	return drawing.current(body, DIRT_REDRAW_SHARE)

/**
 * Returns the masks of a taur suit's dirt on its wearer over the whole taur canvas, or null while there are none to
 * draw, asking for them as ready_skin_masks() does. Its back splats draw as pools along the back of the taur body it
 * hides, as that body would draw them (ready_taur_masks()). The general deposits that body would take
 * (dirt_taur_takes()) draw as its hem band. Walking, crawling and dust draw as that body's contact coat
 * (dirt_taur_coat()). The others draw as that body takes them on cloth (dirt_shape_deposit()), on its wearer's dirtier
 * side. Its upper part alone draws the rest (ready_cloth_masks()). Masks made for another taur body, rider or side are
 * dropped and made again.
 *
 * Arguments:
 * - garment: The item.
 * - wearer: The taur wearing it.
 */
/datum/component/dirtiness/proc/ready_taur_cloth_masks(obj/item/garment, mob/living/carbon/human/wearer)
	RETURN_TYPE(/datum/dirt_masks)
	var/list/splats = list()
	for(var/datum/dirt_splat/splat as anything in mess_splats)
		if(splat.zone == DIRT_ZONE_BACK || (splat.cause && dirt_taur_takes(splat.cause, dirt_material(splat.material))))
			splats += splat
	if(!length(splats) && taur_cloth)
		// none of its splats draw on the taur canvas now, so no current() would drop these jobs
		taur_cloth.drop_jobs(wearer)
		taur_cloth = null
	var/datum/dirt_taur_source/source = length(splats) && dirt_taur_source(wearer)
	if(!source)
		return null
	taur_cloth ||= new
	var/source_key = source.shape_key()
	var/wearer_side = dirt_holds_deposits(splats) ? dirt_wearer_side(wearer) : 1
	if(taur_cloth.request && (taur_cloth.parts_key != source_key || !dirt_worn_sources_match(wearer, taur_cloth.request.zone_sources) || taur_cloth.request.side != wearer_side))
		taur_cloth.forget(TRUE)
	if(!taur_cloth.request)
		taur_cloth.start(new /datum/dirt_mask_request(DIRT_MASKS_TAUR, dirt_worn_sources(wearer), DIRT_SURFACE_CLOTH, splats, shape_source = source, side = wearer_side), source_key)
	return taur_cloth.current(wearer, dirt_slot_redraw(wearer.get_slot_by_item(garment)))

/**
 * Returns the masks of a person's taur body's dirt, drawn with its own images, or null while there are none to draw
 * (ready_shape_masks()).
 *
 * Arguments:
 * - source: The taur body as it draws now (/datum/bodypart_overlay/mutant/taur_body/proc/dirt_read_source()), or null.
 */
/datum/component/dirtiness/proc/ready_taur_masks(datum/dirt_taur_source/source)
	RETURN_TYPE(/datum/dirt_masks)
	return ready_shape_masks(ORGAN_SLOT_EXTERNAL_TAUR, source)

/**
 * Returns the masks of a person's drawn part's dirt, or null while there are none to draw, asking for them as
 * ready_skin_masks() does. The part is their taur body, another drawn part or their hair. The masks draw with the
 * part's own images, and the hair's over the hair. SSdirt draws the body again once they're made, and the hair with the
 * head. A taur body's mess lies as pools along the back of its sprite, keeping clear of the rider's mess. General
 * deposits land by the part's own rules (dirt_shape_deposit()), the hair's as hair (dirt_hair_dirt()), on the person's
 * dirtier side. Masks made for another sprite (lying down, another kind, another hairstyle or hat) are dropped and made
 * again. On a taur body, so are masks made for another rider or height. A wag never has them made again, as a tail is
 * read still.
 * A steady draw compares a few vars. The source a request was made with stands for its key. The rider is read again
 * only once what a limb or the eyes are drawn from changes (rider_unchanged()). A taur body's mess and deposits are
 * joined into one list, oldest first, only as a request is made.
 *
 * Arguments:
 * - organ_slot: The part's ORGAN_SLOT_* define, or DIRT_CARRIER_HAIR.
 * - source: The part as it draws now, or null.
 */
/datum/component/dirtiness/proc/ready_shape_masks(organ_slot, datum/dirt_shape_source/source)
	RETURN_TYPE(/datum/dirt_masks)
	var/mob/living/carbon/human/body = parent
	var/list/mess = part_mess_splats[organ_slot]
	var/list/deposits = part_splats?[organ_slot]
	if((!length(mess) && !length(deposits)) || !source || !istype(body))
		return null
	part_drawings ||= alist()
	var/datum/dirt_drawing/drawing = (part_drawings[organ_slot] ||= new /datum/dirt_drawing)
	var/taur = source.kind == DIRT_SHAPE_TAUR
	// a source never changes, so the source a request was made with still matches its key
	if(drawing.request && ((drawing.request.shape_source != source && drawing.parts_key != source.shape_key()) || (taur && (drawing.request.rows != dirt_height_rows(body) || !rider_unchanged(body, drawing.request)))))
		drawing.forget(TRUE)
	if(!drawing.request)
		var/on_hair = source.kind == DIRT_SHAPE_HAIR
		// only a taur body takes mess, joined with its deposits oldest first, as a request takes them
		var/list/splats = length(mess) ? mess : deposits
		if(length(mess) && length(deposits))
			splats = sortTim(mess + deposits, GLOBAL_PROC_REF(cmp_dirt_splats_landed))
		drawing.start(new /datum/dirt_mask_request(taur ? DIRT_MASKS_TAUR : (on_hair ? DIRT_MASKS_HAIR : DIRT_MASKS_SHAPE), taur ? dirt_zone_sources(body) : null, taur ? DIRT_SURFACE_SKIN : (on_hair ? DIRT_SURFACE_HAIR : DIRT_SURFACE_FUR), splats, shape_source = source, side = length(deposits) ? dirtier_side() : 1, rows = taur ? dirt_height_rows(body) : null), source.shape_key())
		if(taur)
			// read from the body just now, with nothing between that changes a limb, so the draws after only compare
			note_rider_reads(body, drawing.request)
	return drawing.current(body, DIRT_REDRAW_BODY)

/**
 * Returns whether the body draws the rider that a taur body's masks were asked for, as dirt_zone_sources_match() reads
 * it. What each limb and the eyes are drawn from is compared with what they were when they last matched (rider_reads).
 * The zone sources are read again only once any differs, and noted anew if they still match.
 *
 * Arguments:
 * - body: The person.
 * - request: The request of the taur body's masks.
 */
/datum/component/dirtiness/proc/rider_unchanged(mob/living/carbon/human/body, datum/dirt_mask_request/request)
	if(rider_reads_for == request && body_reads_steady(body, request.zone_sources, rider_reads))
		return TRUE
	if(!dirt_zone_sources_match(body, request.zone_sources))
		return FALSE
	note_rider_reads(body, request)
	return TRUE

/**
 * Returns whether every limb and the eyes are drawn from what some notes hold (dirt_body_reads()). They're read as
 * dirt_zone_sources_match() reads them: the limb in each zone, or no limb then and now, and the eyes and the head
 * they're read through.
 *
 * Arguments:
 * - body: The person.
 * - zone_sources: The sprites the notes were read against.
 * - reads: The notes: rider_reads or worn_reads.
 */
/datum/component/dirtiness/proc/body_reads_steady(mob/living/carbon/human/body, list/zone_sources, alist/reads)
	for(var/zone in GLOB.all_body_zones)
		// reads get_bodypart()'s cache directly, as this runs on every draw of a dirty taur body or garment
		var/obj/item/bodypart/checked = body.real_bodypart_cache[zone]
		var/list/read = reads[zone]
		if(checked ? (!read || !checked.dirt_sprite_unchanged(read)) : read)
			return FALSE
	return dirt_eyes_unchanged(body, zone_sources, reads["eyes"])

/**
 * Notes in rider_reads what every zone's limb and the eyes are drawn from now, for the request of the taur body's
 * masks. The request's zone sources name what they draw.
 *
 * Arguments:
 * - body: The person.
 * - request: The request.
 */
/datum/component/dirtiness/proc/note_rider_reads(mob/living/carbon/human/body, datum/dirt_mask_request/request)
	rider_reads_for = request
	rider_reads = dirt_body_reads(body, request.zone_sources)

/**
 * Returns what every zone's limb and the eyes are drawn from now: alist(body zone =
 * /obj/item/bodypart/proc/dirt_sprite_reads(), or null with no limb, "eyes" = dirt_eye_reads()).
 *
 * Arguments:
 * - body: The person.
 * - zone_sources: The sprites they're read against, which name what they draw.
 */
/proc/dirt_body_reads(mob/living/carbon/human/body, list/zone_sources)
	RETURN_TYPE(/alist)
	var/alist/reads = alist()
	for(var/zone in GLOB.all_body_zones)
		var/obj/item/bodypart/checked = body.get_bodypart(zone)
		reads[zone] = checked?.dirt_sprite_reads()
	reads["eyes"] = dirt_eye_reads(body, zone_sources)
	return reads

/**
 * Returns the zone sources a garment asks for its masks with on its wearer (dirt_zone_sources()). While every limb and
 * the eyes are drawn from what the wearer's carrier noted (worn_reads), each garment gets the same list. Its draws then
 * match by comparing a few vars (dirt_worn_sources_match()). A wearer without a carrier gets a new list each time.
 *
 * Arguments:
 * - wearer: Who wears it.
 */
/proc/dirt_worn_sources(mob/living/carbon/human/wearer)
	RETURN_TYPE(/list)
	var/datum/component/dirtiness/wearer_carrier = wearer.GetComponent(/datum/component/dirtiness)
	if(!wearer_carrier)
		return dirt_zone_sources(wearer)
	if(!wearer_carrier.worn_sources || !wearer_carrier.body_reads_steady(wearer, wearer_carrier.worn_sources, wearer_carrier.worn_reads))
		wearer_carrier.worn_sources = dirt_zone_sources(wearer)
		wearer_carrier.worn_reads = dirt_body_reads(wearer, wearer_carrier.worn_sources)
	return wearer_carrier.worn_sources

/**
 * Returns whether a garment's wearer draws the sprites its masks were asked for with, as dirt_zone_sources_match()
 * reads them. Masks asked for with the wearer's carrier's worn_sources match while worn_reads hold. Others are read in
 * full. If a full read matches, the carrier notes the masks' zone sources and what the body is drawn from now, as
 * rider_unchanged() notes again. It keeps its notes if they're still true. Later draws then compare against them.
 *
 * Arguments:
 * - wearer: Who wears it.
 * - zone_sources: The masks' request's zone sources.
 */
/proc/dirt_worn_sources_match(mob/living/carbon/human/wearer, list/zone_sources)
	var/datum/component/dirtiness/wearer_carrier = wearer.GetComponent(/datum/component/dirtiness)
	if(wearer_carrier && zone_sources == wearer_carrier.worn_sources && wearer_carrier.body_reads_steady(wearer, zone_sources, wearer_carrier.worn_reads))
		return TRUE
	if(!dirt_zone_sources_match(wearer, zone_sources))
		return FALSE
	// the carrier's own list failed the steady check above, so it's checked again only for another garment's list
	if(wearer_carrier && (zone_sources == wearer_carrier.worn_sources || !wearer_carrier.worn_sources || !wearer_carrier.body_reads_steady(wearer, wearer_carrier.worn_sources, wearer_carrier.worn_reads)))
		wearer_carrier.worn_sources = zone_sources
		wearer_carrier.worn_reads = dirt_body_reads(wearer, zone_sources)
	return TRUE

/**
 * Returns the masks of a wagging tail's dirt, drawn with its wagging images, or null while there are none to draw
 * (/datum/dirt_drawing/proc/wag_shown()). They're the wag's own masks (/datum/dirt_wag_source), asked for at the first
 * wag after the splats change. They're made from the still request's splats, on its side, and kept in the drawing while
 * the splats don't change. Where a one-frame wag shows the still sprite's pixels, they're the still masks
 * ready_shape_masks() returned instead. Nothing is drawn while frames are made, because the still dirt would lie still
 * over a moving tail. A one-frame wag draws the still dirt while its job finds out. The job of masks asked for before
 * the splats changed goes once other masks are asked for, or would be (`ask`). Call it after ready_shape_masks().
 *
 * Arguments:
 * - organ_slot: The part's ORGAN_SLOT_* define.
 * - wag: The part read wagging (/datum/bodypart_overlay/mutant/proc/dirt_shape_source_of()), or null when it can't be.
 * - ask: Whether to ask for the masks, queueing them if they aren't made. A still tail doesn't ask, but it starts the
 *   request its next wag asks for, so the job of the request before goes if the new one is different.
 */
/datum/component/dirtiness/proc/ready_wag_masks(organ_slot, datum/dirt_wag_source/wag, ask = TRUE)
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_drawing/drawing = part_drawings?[organ_slot]
	if(!wag || !drawing?.request)
		return null
	if(!wag.shows_still)
		var/wag_key = wag.shape_key()
		if(drawing.wag?.request && drawing.wag.parts_key != wag_key)
			drawing.drop_wag(parent)
		var/datum/dirt_drawing/frames = (drawing.wag ||= new /datum/dirt_drawing)
		if(!frames.request)
			frames.start(new /datum/dirt_mask_request(DIRT_MASKS_SHAPE, null, DIRT_SURFACE_FUR, drawing.request.splats, shape_source = wag, side = drawing.request.side), wag_key)
			if(frames.superseded_key != frames.key)
				SSdirt.drop_mask_job(frames.superseded_key, parent)
			frames.superseded_key = null
		if(ask)
			frames.current(parent, DIRT_REDRAW_BODY)
	return drawing.wag_shown(wag)

/// Orders splats by when they first landed, oldest first (/datum/dirt_splat/var/serial).
/proc/cmp_dirt_splats_landed(datum/dirt_splat/first, datum/dirt_splat/second)
	return first.serial - second.serial

/**
 * Returns the side a worn item's general deposits draw on: its wearer's dirtier side, or 1 for a wearer without a
 * carrier, as none is made mid-render. A carrier made later with another side has the item's masks made again.
 *
 * Arguments:
 * - wearer: Who wears it.
 */
/proc/dirt_wearer_side(mob/living/carbon/human/wearer)
	var/datum/component/dirtiness/wearer_carrier = wearer.GetComponent(/datum/component/dirtiness)
	return wearer_carrier?.dirtier_side() || 1

/// Returns whether an item's blood stain draws over its dirt. It does unless the item holds dirt that landed after its
/// newest visible blood (dirt_landed, blood_landed).
/datum/component/dirtiness/proc/stain_over()
	return !length(mess_splats) || blood_landed > dirt_landed

/**
 * Returns whether a garment's blood stain draws over its dirt (/datum/component/dirtiness/proc/stain_over()). A
 * garment without a carrier holds no dirt, so its stain does.
 *
 * Arguments:
 * - garment: The garment.
 */
/proc/dirt_stain_over(obj/item/garment)
	var/datum/component/dirtiness/carrier = garment.GetComponent(/datum/component/dirtiness)
	return carrier ? carrier.stain_over() : TRUE

/**
 * Draws an item's dirt over it while a person wears it: inset images in its worn wrapper, from the wearer's cloth
 * masks, moved back onto the body's tile by what build_worn_icon() moves the wrapper by (dirt_worn_shift()). Sweat in
 * those masks darkens the item's own pixels through its multiplier (current_wet()), made from the sprite being worn.
 * The accessories drawn over the item stay dry (dirt_accessory_sprites()). A taur suit is a sprite spanning the taur
 * canvas (dirt_taur_fitted()). On one, the suit's back splats also draw as pools along the taur body's back. The
 * general deposits that body would take draw as its hem band, on the canvas round that tile. Its walking, crawling and
 * dust there are that body's contact coat (dirt_taur_coat()). So its upper part draws none of their legs' share
 * (ready_cloth_masks()). While the suit holds general dirt, its upper part's image, mess and all, draws over the hem
 * band and the pools. A suit holding mess alone draws it under its pools. Off the body it draws none. The item's blood
 * stain, which tg adds after these images, draws over all of them while its newest blood landed after its newest dirt
 * (stain_over()). Otherwise, while the item holds blood that shows, dirt_order_worn() moves a stain it finds under all
 * of the dirt, the hem band's too. It moves the sweat to just under the stain. Sweat always draws under the stain.
 * An item that draws no stain keeps the order it has without blood, its sweat over its dirt. Blood can run down below
 * a taur's waist onto a taur-fitted garment's cloth (ready_taur_blood_cloth_masks()). That run draws over all of the
 * dirt while its blood landed after the cloth's own newest dirt (dirt_cloth_run_over()). Otherwise the run draws under
 * all of the dirt, with or without mess. The taur body's own share of that blood takes its side separately, against
 * the body's own dirt (waist_blood_over()). So at the hem the two can differ. Each image of the item's dirt, the hem
 * band's and the pools' too, draws its emissive blocker just after it (dirt_emissive_blocker()). The blocker is inset
 * and moved as its image is. So on the emissive plane it keeps that image's place against a glowing stain. The
 * multiplier and the run draw none.
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
	source.dirt_stain_slot = null
	if(isinhands || !ishuman(source.loc))
		return
	var/mob/living/carbon/human/wearer = source.loc
	var/datum/dirt_masks/blood = ready_taur_blood_cloth_masks(source, wearer, draw_target)
	if(!blood?.baked && !length(mess_splats))
		return
	var/list/shift = dirt_worn_shift(source)
	// the taur canvas is centred on the body's tile, as the taur body's images are
	var/mutable_appearance/blood_run = blood?.baked && dirt_mess_inset_image(blood.baked, shift[1] - DIRT_TAUR_INSET, shift[2])
	var/run_last = blood_run && cloth_run_over && length(mess_splats)
	if(blood_run && !run_last)
		overlays += blood_run
	if(!length(mess_splats))
		return
	// the worn wrapper isn't drawn yet, so check the sprite being built for a taur suit, as dirt_taur_fitted() would
	var/taur_fitted = dirt_taur_suit_sprite(draw_target?.icon, wearer)
	var/datum/dirt_masks/masks = ready_cloth_masks(source, wearer, taur_fitted)
	var/datum/dirt_masks/pools = taur_fitted ? ready_taur_cloth_masks(source, wearer) : null
	// the taur canvas is centred on the body's tile, as the taur body's images are
	var/mutable_appearance/hem = pools?.baked && dirt_mess_inset_image(pools.baked, shift[1] - DIRT_TAUR_INSET, shift[2])
	// the upper part's general dirt draws over the hem band, but with mess alone the pools draw over the cloth's mess
	var/hem_under = hem && dirt_holds_deposits(mess_splats)
	var/mutable_appearance/wet
	// masks whose sweat has gone are still asked, so the garment lets go of the multiplier it held
	if(masks && (masks.wet || cloth.wet_key))
		var/list/garment
		if(masks.wet && draw_target)
			garment = list(draw_target.icon, draw_target.icon_state, draw_target.color, source.greyscale_colors, shift[1], shift[2])
			var/list/kept_dry = dirt_accessory_sprites(wearer.w_uniform, draw_target)
			if(kept_dry)
				garment += list(kept_dry)
		var/icon/factors = cloth.current_wet(wearer, dirt_slot_redraw(wearer.get_slot_by_item(source)), garment)
		if(factors)
			wet = dirt_wet_image(factors, shift[1], shift[2])
	var/stain_place = length(overlays) + 1
	if(hem_under)
		overlays += hem
		overlays += dirt_emissive_blocker(pools.baked, source, hem)
	if(masks?.baked)
		var/mutable_appearance/cloth_dirt = dirt_mess_inset_image(masks.baked, shift[1], shift[2])
		overlays += cloth_dirt
		overlays += dirt_emissive_blocker(masks.baked, source, cloth_dirt)
	if(wet)
		overlays += wet
	// dirt landed after the newest blood that shows (get_blood_overlay()), so a stain goes under it with the sweat
	if(GET_ATOM_BLOOD_DNA_LENGTH(source) && !stain_over() && GET_ATOM_BLOOD_DECAL_LENGTH(source))
		source.dirt_stain_slot = list(stain_place, wet ? length(overlays) : 0)
	if(hem && !hem_under)
		overlays += hem
		overlays += dirt_emissive_blocker(pools.baked, source, hem)
	if(run_last)
		overlays += blood_run

/**
 * Adds the line naming this carrier's general dirt to its examine (dirt_examine_line()). An item's line names its own
 * dirt, and a person's names the dirt on them and on what they wear. Mess adds none.
 *
 * Arguments:
 * - source: The carrier.
 * - user: Who examines it.
 * - examine_list: The examine's lines, added to.
 */
/datum/component/dirtiness/proc/on_examine(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	var/line = dirt_examine_line(source, ishuman(source) ? dirt_carriers(source) : list(src))
	if(line)
		examine_list += line

/**
 * Returns the line examining a person or an item shows for its general dirt, or null with none. It names the heaviest
 * material on the carriers, by the sum of its deposits' levels, worded by its thickest deposit's level
 * ("It is caked in mud."). Mess shows none.
 *
 * Arguments:
 * - examined: The person or item.
 * - carriers: Its carriers, /datum/component/dirtiness.
 */
/proc/dirt_examine_line(atom/examined, list/carriers)
	var/static/list/dry_words = list("flecked with", "smeared with", "caked in", "caked in")
	var/static/list/wet_words = list("damp with", "wet with", "soaked in", "soaked in")
	// material -> the sum of its deposits' levels, and its thickest deposit's level
	var/alist/totals = alist()
	var/alist/thickest = alist()
	for(var/datum/component/dirtiness/carrier as anything in carriers)
		for(var/list/splats as anything in carrier.splat_lists(drawn_parts = TRUE))
			for(var/datum/dirt_splat/splat as anything in splats)
				if(splat.cause)
					totals[splat.material] += splat.level
					thickest[splat.material] = max(thickest[splat.material], splat.level)
	var/heaviest
	for(var/material_key, total in totals)
		// a tie goes to the thicker, then by name, so the line never flickers
		if(!heaviest || total > totals[heaviest] || (total == totals[heaviest] && (thickest[material_key] > thickest[heaviest] || (thickest[material_key] == thickest[heaviest] && sorttext(material_key, heaviest) > 0))))
			heaviest = material_key
	var/datum/dirt_material/material = heaviest && dirt_material(heaviest)
	if(!material)
		return null
	var/list/words = (material.flags & DIRT_MATERIAL_WET) ? wet_words : dry_words
	return "[examined.p_They()] [examined.p_are()] [words[min(thickest[heaviest], length(words))]] [material.name]."

/// Returns this carrier's lists of splats: its own, then each piece of underclothes', then, with `drawn_parts`, each
/// drawn part's general deposits (part_splats).
/datum/component/dirtiness/proc/splat_lists(drawn_parts)
	RETURN_TYPE(/list)
	var/list/surfaces = list(mess_splats)
	for(var/key, splats in underclothes_splats)
		surfaces += list(splats)
	if(drawn_parts)
		for(var/organ_slot, splats in part_splats)
			surfaces += list(splats)
	return surfaces

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
 * Notes visible blood landing on an item (blood_landed), so its stain draws over the dirt that landed before it
 * (stain_over()). It draws nothing. The merge that follows draws its slot, but not on an item's first blood, because
 * its forensics look for a stain before the item holds them. The slot's next draw shows that stain.
 *
 * Arguments:
 * - blood_DNA: The blood being added: list(DNA = its /datum/blood_type).
 */
/datum/component/dirtiness/proc/on_blood_added(list/blood_DNA)
	// /obj/add_blood_DNA() takes nothing but a list
	if(islist(blood_DNA) && has_blood_flag(blood_DNA, BLOOD_COVER_ITEMS))
		blood_landed = SSdirt.next_serial()

/**
 * Adds blood to this item, noting it for dirt as it lands. The item's carrier of dirt notes it before the merge, which
 * draws its slot (/datum/component/dirtiness/proc/on_blood_added()). Once it's merged, a taur wearing the item as its
 * uniform or suit notes it below the waist (/datum/component/dirtiness/proc/note_waist_blood()). So it counts as landed
 * now and not when the slot next draws.
 */
/obj/item/add_blood_DNA(list/blood_DNA_to_add, list/datum/disease/diseases)
	// the item and object procs called next refuse blood on these
	if(!(item_flags & NO_BLOOD_ON_ITEM) && !QDELETED(src))
		var/datum/component/dirtiness/carrier = GetComponent(/datum/component/dirtiness)
		carrier?.on_blood_added(blood_DNA_to_add)
	. = ..()
	var/mob/living/carbon/human/wearer = loc
	if(. && ishuman(wearer) && (src == wearer.w_uniform || src == wearer.wear_suit) && wearer.organs_slot[ORGAN_SLOT_EXTERNAL_TAUR])
		var/datum/component/dirtiness/wearer_carrier = wearer.GetComponent(/datum/component/dirtiness)
		wearer_carrier?.note_waist_blood(wearer)

/**
 * Follows what a person wears: a change to the underclothes has their masks made again for what's drawn now, and a
 * change to any slot that covers skin has SSdirt check, once the slots settle, whether the skin's mess fades at other
 * edges now (check_cover()). A change to a taur's uniform or suit, its blood included, is checked the same way, for the
 * blood below its waist. Blood landing on either is noted as the slot draws (note_waist_blood()). The merge draws the
 * slot in the landing's own call, except on an item's first blood. The blood is noted again once it's merged
 * (/obj/item/add_blood_DNA()).
 *
 * Arguments:
 * - source: The person.
 * - cache_index: The overlays_standing slot applied or removed.
 */
/datum/component/dirtiness/proc/on_overlay_changed(mob/living/carbon/human/source, cache_index)
	SIGNAL_HANDLER
	if(!(cache_index in dirt_cover_layers()) || (SSdirt.redrawing && SSdirt.redrawing == source.weak_reference))
		return
	worn_changes++
	if(cache_index == BODY_LAYER)
		forget_underclothes_masks()
	var/taur_garment = (cache_index == UNIFORM_LAYER || cache_index == SUIT_LAYER) && source.organs_slot[ORGAN_SLOT_EXTERNAL_TAUR]
	if(taur_garment)
		note_waist_blood(source)
	if(length(mess_splats) || length(underclothes_splats) || length(part_mess_splats) || taur_blood || taur_garment)
		SSdirt.redraw_later(source, DIRT_REDRAW_COVER)

/**
 * Has SSdirt look again, once the change settles, at a body gaining a taur body, as a genital joining it would have it
 * (check_parts()). The taur body's own images ask for its pools as they're drawn. Whether the body is hidden is read
 * again (skin_hidden()).
 *
 * Arguments:
 * - source: The person.
 * - organ: The organ gained.
 * - special: Whether it was put in without the usual effects.
 */
/datum/component/dirtiness/proc/on_organ_gained(mob/living/carbon/human/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(!istype(organ, /obj/item/organ/taur_body))
		return
	hidden_read = null
	if(mess_count())
		SSdirt.redraw_later(source, DIRT_REDRAW_PARTS)

/**
 * Takes a taur body's or another drawn part's dirt off as it leaves the body, as a genital leaving takes its share. It
 * has SSdirt look again once the change settles. Its leaving draws the body. Eyes that leave are let go of
 * (forget_skin_reads()). When a taur body leaves, whether the body is hidden is read again (skin_hidden()). The carrier
 * lets go of what the rider was read from (rider_reads) and of the blood below the waist. A cover check then deletes
 * any carrier left holding nothing (check_taur_blood()).
 *
 * Arguments:
 * - source: The person.
 * - organ: The organ lost.
 * - special: Whether it was taken out without the usual effects.
 */
/datum/component/dirtiness/proc/on_organ_lost(mob/living/carbon/human/source, obj/item/organ/organ, special)
	SIGNAL_HANDLER
	if(istype(organ, /obj/item/organ/eyes))
		forget_skin_reads(worn = TRUE)
	if(istype(organ, /obj/item/organ/taur_body))
		hidden_read = null
		rider_reads = null
		rider_reads_for = null
		drop_taur_blood()
		// the blood below its waist goes, and any carrier left holding nothing with it (check_taur_blood())
		SSdirt.redraw_later(source, DIRT_REDRAW_COVER)
	else if(!part_splats?[organ.slot])
		return
	drop_part(organ.slot)
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
	for(var/datum/component/dirtiness/carrier as anything in dirt_carriers(body))
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
 * Has the skin's masks made again if what the body wears over its skin changed since they were asked for. Its splats
 * then fade out beside what it wears now, and its general deposits draw painted only while it's bare
 * (dirt_bare_bodied()). The underwear's masks are made again if its general deposits are painted while the body isn't
 * bare, or unpainted while it is. So are the masks of a taur's blood below the waist, if what it's drawn from changed
 * (check_taur_blood()). That blood is also drawn again if the side of the dirt it lies on isn't the side it takes.
 * Draws the body if any changed.
 */
/datum/component/dirtiness/proc/check_cover()
	var/mob/living/carbon/human/body = parent
	var/changed = check_taur_blood()
	// this carrier is deleted if it held nothing once its blood went
	if(QDELETED(src))
		return
	if(length(mess_splats) && !(skin?.request && cover_key == dirt_sprites_key(dirt_cover_sprites(body))))
		skin?.forget(FALSE)
		changed = TRUE
	var/judged = FALSE
	var/bare = FALSE
	for(var/key, drawing in underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		var/datum/dirt_mask_request/request = drawn.request
		if(request?.deposit_surface != DIRT_SURFACE_SKIN || !dirt_holds_deposits(request.splats))
			continue
		if(!judged)
			bare = dirt_bare_bodied(body)
			judged = TRUE
		if(request.painted != bare)
			drawn.forget(FALSE)
			changed = TRUE
	if(changed)
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
	if(!(skin_limbs() & dirt_skin_zone_limbs()[limb.body_zone]))
		return
	var/datum/bodypart_overlay/dirt_skin/old_overlay = skin_overlays[limb.body_zone]
	old_overlay?.carrier = null
	var/datum/bodypart_overlay/dirt_skin/overlay = dirt_skin_overlay(limb.body_zone, src)
	limb.add_bodypart_overlay(overlay, update = FALSE)
	skin_overlays[limb.body_zone] = overlay

/**
 * Takes the skin overlay off a limb leaving the person, whose mess stays with them. It lets go of the limb and of the
 * eyes it may take (forget_skin_reads()), and has the masks made again for the body left. A head that leaves takes the
 * hair's dirt with it, unless it's swapped without the usual effects, as a species change swaps it. The removal draws
 * the body.
 *
 * Arguments:
 * - source: The person.
 * - limb: The limb being removed.
 * - special: Whether it's swapped without the usual effects.
 * - dismembered: Whether it was cut off.
 */
/datum/component/dirtiness/proc/on_limb_removed(mob/living/carbon/human/source, obj/item/bodypart/limb, special, dismembered)
	SIGNAL_HANDLER
	if(limb.body_zone == BODY_ZONE_HEAD && !special)
		drop_part(DIRT_CARRIER_HAIR)
	forget_skin_reads(worn = TRUE)
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
