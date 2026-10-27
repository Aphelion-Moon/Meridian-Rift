/datum/bodypart_overlay/mutant/genital
	/// Set while mess reads the genital's own images (dirt_part_images()): get_overlay() draws it without its mess.
	var/dirt_bare = FALSE
	/// The genital's own render key when dirt_source was read, joined.
	var/dirt_source_key
	/// What the genital drew as a part source (dirt_part_source_of()) under dirt_source_key, or null.
	var/datum/dirt_part_source/dirt_source

/**
 * A genital carrying mess of its own (its owner's part_mess_splats) draws it with its front layer: one container just
 * over that layer's images, at their layer and offsets, holding the baked image of its share. So it draws wherever the
 * genital does, over clothing or through a portal (penis_only(), lower_body_only()), and takes the height filter with
 * it (dirt_container_over()). A butt's back image draws under every surface, so its share is drawn in that surface's
 * masks; the container holds only the directions its front image shows over what it lies on.
 */
/datum/bodypart_overlay/mutant/genital/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	if(dirt_bare || layer_index != EXTERNAL_FRONT_UNDER_CLOTHES || !length(.))
		return
	var/datum/component/dirtiness/carrier = dirt_share_carrier(limb)
	if(!carrier)
		return
	var/kind = dirt_part_kind(limb.owner.get_organ_slot(organ_slot))
	// a kind read from its front layer alone is these images, so they needn't be drawn again for it
	var/datum/dirt_masks/masks = carrier.ready_part_masks(organ_slot, length(dirt_part_layers(kind)) == 1 ? dirt_part_source_of(kind, .) : dirt_share_source(limb))
	var/mutable_appearance/container = masks?.baked && dirt_container_over(., masks.baked)
	if(container)
		.[container] = NONE

/// Adds the key of the share's masks, or "pending" while they're made, so the limb's images follow it, kept on its own
/// mob (limb_icons_for()).
/datum/bodypart_overlay/mutant/genital/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	// checked first, so a clean genital's redraws don't build the key string
	if(!dirt_share_carrier(limb))
		return
	// the override in _genital.dm, included after this one, adds the layering and the device once this returns
	. += dirt_share_key(limb, "[jointext(., "|")]|[is_custom_layered(limb = limb) ? layer_mode : "default"]|[device_state]")

/**
 * Returns what the genital's own mess draws as, for keys, after DIRT_PRIVATE_KEY: its masks' key, "pending" while
 * they're made, or null while it has none or doesn't draw as itself. Asking queues masks not made yet. Given its own
 * render key, the part source is read again only when that changes: the key covers the genital's sprites, colours,
 * layering and device, which are what the part source is read from.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 * - own_key: The genital's own render key, without its mess, joined, or null to read the part source now.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_share_key(obj/item/bodypart/limb, own_key)
	var/datum/component/dirtiness/carrier = dirt_share_carrier(limb)
	if(!carrier)
		return null
	var/datum/dirt_part_source/source
	if(isnull(own_key))
		source = dirt_share_source(limb)
	else
		if(own_key != dirt_source_key)
			dirt_source = dirt_share_source(limb)
			dirt_source_key = own_key
		source = dirt_source
	var/datum/dirt_masks/masks = carrier.ready_part_masks(organ_slot, source)
	return "[DIRT_PRIVATE_KEY]mess=[masks ? masks.key : "pending"]"

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
 * Returns the carrier of the genital's own mess while it has some and draws as itself, or null.
 *
 * Arguments:
 * - limb: The limb it's drawn on.
 */
/datum/bodypart_overlay/mutant/genital/proc/dirt_share_carrier(obj/item/bodypart/limb)
	var/mob/living/carbon/human/owner = limb?.owner
	if(!istype(owner) || device_state || !dirt_draws_itself())
		return null
	var/datum/component/dirtiness/carrier = owner.GetComponent(/datum/component/dirtiness)
	return length(carrier?.part_mess_splats[organ_slot]) ? carrier : null

/// Returns whether the genital draws its own sprites, so mess can go on them.
/datum/bodypart_overlay/mutant/genital/proc/dirt_draws_itself()
	return TRUE

/**
 * Returns whether the genital draws on a body now, from the checks can_draw_on_bodypart() makes of it: not on a husk,
 * not closed off by a device, not hidden by its accessory (is_hidden(), which reads clothing and custom layering), and
 * not covered by a look drawn in its place. They're read rather than asked through can_draw_on_bodypart(), which a
 * garment's render reading the parts mustn't call: a penis's resolves its bulge look, which can draw that garment
 * again.
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
