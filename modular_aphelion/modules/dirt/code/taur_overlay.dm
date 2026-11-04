/datum/bodypart_overlay/mutant/taur_body
	/// The taur body as mess reads it (dirt_read_source()), or null when it can't be.
	var/datum/dirt_taur_source/dirt_source
	/// What dirt_source was read for: the accessory, its base state (standing or lying) and the limb's gender.
	var/dirt_source_key

/**
 * A taur body carrying pools (its owner's part_mess_splats in ORGAN_SLOT_EXTERNAL_TAUR) draws them with each of its
 * layers: one container just over the layer's images, at their layer and offsets (centred on the 64x32 taur canvas as
 * they are), holding the pools' baked image kept to the pixels that layer shows. So the container joins the layer's own
 * holder and adds no overlay to the mob, and takes the height filter with it (dirt_container_over()).
 */
/datum/bodypart_overlay/mutant/taur_body/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	if(!length(.))
		return
	var/datum/component/dirtiness/carrier = dirt_pools_carrier(limb)
	// icon_render_key() asked for the masks before this draw, with the same checks: read what it found
	var/datum/dirt_drawing/drawing = carrier?.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	var/baked = drawing?.masks?.baked_by_layer[layer_index]
	var/mutable_appearance/container = baked && dirt_container_over(., baked)
	if(container)
		.[container] = NONE

/// Adds the key of the pools' masks, or "pending" while they're made, after DIRT_PRIVATE_KEY, so the chest's images
/// follow them, kept on its own mob (limb_icons_for()).
/datum/bodypart_overlay/mutant/taur_body/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	var/datum/component/dirtiness/carrier = dirt_pools_carrier(limb)
	if(!carrier)
		return
	var/datum/dirt_masks/masks = carrier.ready_taur_masks(dirt_read_source(limb))
	. += "[DIRT_PRIVATE_KEY]pools=[masks ? masks.key : "pending"]"

/**
 * Returns the carrier of the taur body's pools while it has some and draws them (dirt_read_source()), or null. Both
 * icon_render_key() and get_overlay() ask it, so the pools drawn always follow the key: pools drawn under a key without
 * them would be cached for every body drawn alike.
 *
 * Arguments:
 * - limb: The chest it's drawn on.
 */
/datum/bodypart_overlay/mutant/taur_body/proc/dirt_pools_carrier(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/component/dirtiness)
	var/mob/living/carbon/human/owner = limb?.owner
	if(!istype(owner))
		return null
	var/datum/component/dirtiness/carrier = owner.GetComponent(/datum/component/dirtiness)
	return length(carrier?.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]) && dirt_read_source(limb) ? carrier : null

/**
 * Returns the taur body as mess reads it: each of its layers' images, as get_images() draws them, their states taken
 * together, or null when they draw nothing on the 64x32 taur canvas or its kind takes no pools: Big Legs, legs under
 * the rider with no taur back. Read again when the accessory, its base state or the limb's gender changes.
 *
 * Arguments:
 * - limb: The chest it's drawn on.
 */
/datum/bodypart_overlay/mutant/taur_body/proc/dirt_read_source(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_taur_source)
	var/datum/sprite_accessory/taur/kind = sprite_datum
	if(!kind || (kind.taur_mode & BODYSHAPE_TAUR_BIG_LEGS_ALL))
		return null
	var/read_key = "[sprite_datum.type]|[get_base_icon_state()]|[limb?.limb_gender]"
	if(read_key == dirt_source_key)
		return dirt_source
	dirt_source_key = read_key
	dirt_source = null
	var/sheet
	var/alist/layer_states = alist()
	for(var/layer_key, layer_number in layers)
		for(var/mutable_appearance/drawn as anything in get_images(limb, layer_key, -layer_number))
			// a MOD suit's texture holder draws no sprite of its own
			if(!drawn.icon || !drawn.icon_state)
				continue
			sheet ||= drawn.icon
			if(drawn.icon != sheet)
				continue
			LAZYADD(layer_states[layer_key], drawn.icon_state)
	if(length(layer_states) && get_icon_dimensions(sheet)["width"] == DIRT_TAUR_WIDTH)
		dirt_source = new(sheet, layer_states)
	return dirt_source
