/datum/bodypart_overlay/mutant/genital
	/// Set while mess reads the genital's own images (dirt_part_images()): get_overlay() draws it without its mess.
	var/dirt_bare = FALSE
	/// The genital's own render key when dirt_source was read, joined.
	var/dirt_source_key
	/// What the genital drew as a part source (dirt_part_source_of()) under dirt_source_key, or null.
	var/datum/dirt_part_source/dirt_source
	/// dirt_source's place over the skin (/datum/dirt_part_source/proc/placed_key() at DIRT_SKIN_LAYER), or null
	/// until it's asked for.
	var/dirt_source_placed

/**
 * Draws a genital's own mess (its owner's part_mess_splats) with its front layer. One container just over that layer's
 * images, at their layer and offsets, holds the baked image of its share (dirt_container_over()). So the container
 * draws wherever the genital does, over clothing or through a portal (penis_only(), lower_body_only()).
 * apply_height() moves it as it moves the genital's images, by a filter or a pixel offset as the genital's
 * offset_location says. A butt's back image draws under every surface, so its share is drawn in that surface's
 * masks. The container holds only the directions its front image shows over what it lies on. A genital drawn over the
 * skin takes the skin's general dirt on its own pixels too, from the skin's masks
 * (/datum/dirt_masks/var/baked_by_part). That goes in the same container, under its share. Each baked image draws its
 * emissive blocker beside the container (dirt_emissive_blocker()), after the genital's own glows at that layer.
 */
/datum/bodypart_overlay/mutant/genital/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	if(dirt_bare || layer_index != EXTERNAL_FRONT_UNDER_CLOTHES || !length(.))
		return
	var/datum/component/dirtiness/carrier = dirt_drawn_carrier(limb)
	var/sharing = length(carrier?.part_mess_splats[organ_slot])
	var/alist/body_baked = carrier?.skin?.masks?.baked_by_part
	if(!sharing && !body_baked)
		return
	var/kind = dirt_part_kind(limb.owner.get_organ_slot(organ_slot))
	// part_keys holds body_baked's keys, and the render key asks about the same list
	if(body_baked && !dirt_keys_of_kind(carrier.skin.masks.part_keys, kind))
		if(!sharing)
			return
		body_baked = null
	// a kind read from its front layer alone is these images, so they needn't be drawn again for it
	var/datum/dirt_part_source/source = length(dirt_part_layers(kind)) == 1 ? dirt_part_source_of(kind, .) : dirt_share_source(limb)
	var/datum/dirt_masks/masks = sharing ? carrier.ready_part_masks(organ_slot, source) : null
	var/icon/body_dirt = source && body_baked?[source.placed_key(DIRT_SKIN_LAYER)]
	var/mutable_appearance/container = (masks?.baked || body_dirt) && dirt_container_over(., masks?.baked, body_dirt)
	if(!container)
		return
	.[container] = NONE
	if(body_dirt)
		.[dirt_emissive_blocker(body_dirt, limb, container)] = LIMB_OVERLAY_META
	if(masks?.baked)
		.[dirt_emissive_blocker(masks.baked, limb, container)] = LIMB_OVERLAY_META

/// Adds the key of the share's masks, or "pending" while they're made, and the key of the skin's general dirt on it.
/// The limb's images then follow them and stay on its own mob (limb_icons_for()).
/datum/bodypart_overlay/mutant/genital/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	var/datum/component/dirtiness/carrier = dirt_drawn_carrier(limb)
	var/datum/dirt_drawing/skin = carrier?.skin
	// if the skin's request draws general dirt on parts, bring its masks up to date first, as the skin's overlay
	// would, because that overlay may be keyed after this one
	var/datum/dirt_masks/skin_masks = skin?.request?.deposit_parts ? skin.current(limb.owner, DIRT_REDRAW_BODY) : skin?.masks
	// checked first, so a clean genital's redraws don't build the key string
	if(!length(carrier?.part_mess_splats[organ_slot]) && !skin_masks?.part_keys)
		return
	// the override in _genital.dm, included after this one, adds the layering and the device once this returns
	var/dirt_key = dirt_share_key(limb, "[jointext(., "|")]|[is_custom_layered(limb = limb) ? layer_mode : "default"]|[device_state]", carrier)
	if(dirt_key)
		. += dirt_key

/**
 * Returns what the genital's own dirt draws as, for keys, after DIRT_PRIVATE_KEY: the key of the skin's general dirt on
 * it (/datum/dirt_masks/var/part_keys), and its share's masks' key, or "pending" while they're made. It's null while
 * it has neither or doesn't draw as itself. Asking queues share masks not made yet. Given its own render key, the part
 * source is read again only when that key changes, because the key covers the genital's sprites, colours, layering
 * and device, which the part source is read from. Its place over the skin is read once for each part source, which
 * never changes.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - own_key: The genital's own render key, without its mess, joined, or null to read the part source now.
 * - carrier: Its owner's carrier as dirt_drawn_carrier() returns it, from a caller that has it, or null to look it up.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_share_key(obj/item/bodypart/limb, own_key, datum/component/dirtiness/carrier = null)
	carrier ||= dirt_drawn_carrier(limb)
	var/sharing = length(carrier?.part_mess_splats[organ_slot])
	var/alist/body_keys = carrier?.skin?.masks?.part_keys
	// a key starts with its part's kind (/datum/dirt_part_source/proc/part_key()), so without a key of this kind the
	// part source needn't be read for it. The organ is read from the slot list itself, as get_organ_slot() reads it.
	if(body_keys && !dirt_keys_of_kind(body_keys, dirt_part_kind(limb.owner.organs_slot[organ_slot])))
		body_keys = null
	if(!sharing && !body_keys)
		return null
	var/datum/dirt_part_source/source
	var/body_key
	if(isnull(own_key))
		source = dirt_share_source(limb)
		body_key = source && body_keys?[source.placed_key(DIRT_SKIN_LAYER)]
	else
		if(own_key != dirt_source_key)
			dirt_source = dirt_share_source(limb)
			dirt_source_key = own_key
			dirt_source_placed = null
		source = dirt_source
		if(source && body_keys)
			dirt_source_placed ||= source.placed_key(DIRT_SKIN_LAYER)
			body_key = body_keys[dirt_source_placed]
	if(!sharing)
		return body_key && "[DIRT_PRIVATE_KEY]dirt=[body_key]"
	var/datum/dirt_masks/masks = carrier.ready_part_masks(organ_slot, source)
	return "[DIRT_PRIVATE_KEY][body_key ? "dirt=[body_key]|" : ""]mess=[masks ? masks.key : "pending"]"

/**
 * Returns whether some keys of part sources include one of a kind (/datum/dirt_part_source/proc/part_key()). The kinds
 * a list's keys start with are read once and kept with that list, by reference, until another list is asked about.
 * The lists asked about are skin masks' part keys (/datum/dirt_masks/var/part_keys). Those are written only while
 * their masks are made and never changed after, so a body's genitals, each asking of its own kind, read them once a
 * redraw. It keeps one list and its kinds' names, no datums.
 *
 * Arguments:
 * - keys: alist(placed or part key = anything), never changed once asked about, or null.
 * - kind: A DIRT_PART_* define.
 */
/proc/dirt_keys_of_kind(alist/keys, kind)
	var/static/alist/read_keys
	var/static/alist/kinds = alist()
	if(keys != read_keys)
		read_keys = keys
		kinds.Cut()
		for(var/key in keys)
			// a key starts with its kind and a bar
			var/kind_end = findtextEx(key, "|")
			if(kind_end)
				kinds[copytext(key, 1, kind_end)] = TRUE
	return !!kinds["[kind]"]

/**
 * Returns what the genital draws now as a part source (dirt_part_source_of()), or null.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_share_source(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_part_source)
	var/kind = dirt_part_kind(limb.owner.get_organ_slot(organ_slot))
	return dirt_part_source_of(kind, dirt_part_images(limb, kind))

/**
 * Returns the carrier of the genital's owner's dirt while the genital draws as itself, or null. While it does, its own
 * mess and the skin's general dirt can go on it.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_drawn_carrier(obj/item/bodypart/limb)
	var/mob/living/carbon/human/owner = limb?.owner
	if(!istype(owner) || device_state || !dirt_draws_itself())
		return null
	return owner.GetComponent(/datum/component/dirtiness)

/// Returns whether the genital draws its own sprites, so mess can go on them.
/datum/bodypart_overlay/mutant/genital/proc/dirt_draws_itself()
	return TRUE

/**
 * Returns whether the genital draws on a body now, from the checks can_draw_on_bodypart() makes of it: not on a husk,
 * not closed off by a device, not hidden by its accessory (is_hidden(), which reads clothing and custom layering), and
 * not covered by a look drawn in its place. Its gloryhole check is left out, because a shot through the portal lands
 * on the penis its relay draws (dirt_part_drawn()). dirt_body_parts() makes that check instead. The checks are read
 * here rather than asked through can_draw_on_bodypart(). A garment's render that reads the parts mustn't call that
 * proc, because a penis's can_draw_on_bodypart() resolves its bulge look, which can draw that garment again.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - owner: Its owner.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_shown(obj/item/bodypart/limb, mob/living/carbon/human/owner)
	if((limb.is_husked && draw_on_husks == HUSK_OVERLAY_NONE) || hidden_by_device || isnull(sprite_datum))
		return FALSE
	return dirt_draws_itself() && !sprite_datum.is_hidden(owner, src)

/// A penis covered by a bulge look draws the cover's cloth, not itself.
/datum/bodypart_overlay/mutant/genital/penis/dirt_draws_itself()
	return !bulge_key

/**
 * Returns the genital's images in the layers mess reads its kind from (dirt_part_layers()), as get_overlay() draws
 * them, custom layering included, without its mess, or null when a device draws in its place.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - kind: Its DIRT_PART_* define.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_part_images(obj/item/bodypart/limb, kind)
	RETURN_TYPE(/list)
	if(device_state)
		return null
	. = list()
	dirt_bare = TRUE
	// a runtime mustn't leave it set, or the genital would never draw its mess again
	try
		for(var/layer_index in dirt_part_layers(kind))
			var/part_layer = layers?[layer_index]
			if(!isnull(part_layer))
				. += get_overlay(limb, layer_index, -part_layer)
	catch(var/exception/error)
		dirt_bare = FALSE
		throw error
	dirt_bare = FALSE

/// A genital joining a body carrying mess may shape it: SSdirt looks again once the change settles.
/obj/item/organ/genital/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	if(organ_owner.GetComponent(/datum/component/dirtiness))
		SSdirt.redraw_later(organ_owner, DIRT_REDRAW_PARTS)

/// A genital leaving a body takes its own mess with it, and no longer shapes the body's.
/obj/item/organ/genital/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	var/datum/component/dirtiness/carrier = organ_owner.GetComponent(/datum/component/dirtiness)
	if(!carrier)
		return
	carrier.drop_part(slot)
	SSdirt.redraw_later(organ_owner, DIRT_REDRAW_PARTS)
