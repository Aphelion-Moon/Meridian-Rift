/datum/bodypart_overlay/mutant/taur_body
	/// The taur body as mess reads it (dirt_read_source()), or null when it can't be.
	var/datum/dirt_taur_source/dirt_source
	/// What dirt_source was read for: list(the accessory, its base state (standing or lying), the limb's gender).
	var/list/dirt_source_read

/**
 * A taur body carrying dirt (its owner's part_mess_splats and part_splats in ORGAN_SLOT_EXTERNAL_TAUR: pools and general
 * deposits) draws it with each of its layers: one container just over the layer's images, at their layer and offsets
 * (centred on the 64x32 taur canvas as they are), holding the dirt's baked image kept to the pixels that layer shows.
 * So the container joins the layer's own holder and adds no overlay to the mob (dirt_container_over()). Height doesn't
 * stretch it, as a taur body that takes dirt doesn't stretch (height_location() in taur_body.dm). Blood run down from
 * its rider's garments (ready_taur_blood_masks()) goes in the same container. It draws over the taur body's own dirt
 * if it landed after that dirt, and under that dirt otherwise (waist_blood_over()). The garments' dirt plays no part.
 * So a stain can draw under its garment's dirt above the waist, while its run draws over the body's dirt below it.
 * The taur body's own dirt draws its emissive blocker beside the container (dirt_emissive_blocker()). The blood draws
 * none, as tg's stains block nothing. Nothing is noted here, since images are also made outside the body's draw.
 * check_taur_blood() reads the drawn key instead.
 */
/datum/bodypart_overlay/mutant/taur_body/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	if(!length(.))
		return
	var/mob/living/carbon/human/owner = limb.owner
	var/datum/component/dirtiness/own = istype(owner) ? owner.GetComponent(/datum/component/dirtiness) : null
	var/datum/component/dirtiness/carrier = dirt_pools_carrier(limb, own)
	// icon_render_key() asked for the masks before this draw, with the same checks: read what it found
	var/datum/dirt_drawing/drawing = carrier?.part_drawings?[ORGAN_SLOT_EXTERNAL_TAUR]
	var/baked = drawing?.masks?.baked_by_layer[layer_index]
	var/blood = own?.taur_blood?.masks?.baked_by_layer[layer_index]
	var/mutable_appearance/container = (baked || blood) && ((blood && own.waist_blood_over()) ? dirt_container_over(., blood, baked) : dirt_container_over(., baked, blood))
	if(container)
		.[container] = NONE
		if(baked)
			.[dirt_emissive_blocker(baked, limb, container)] = LIMB_OVERLAY_META

/// Adds the key of the dirt's masks after DIRT_PRIVATE_KEY, or "pending" while they're made. The chest's images then
/// follow the masks and stay on its own mob (limb_icons_for()). Adds the key of the blood below the rider's waist too,
/// and DIRT_TAUR_BLOOD_OVER_KEY while that blood draws over the taur body's dirt. It reads that side and notes nothing,
/// so a key read outside the body's draw can't hide a side left undrawn (check_taur_blood()).
/datum/bodypart_overlay/mutant/taur_body/icon_render_key(obj/item/bodypart/limb)
	. = ..()
	var/mob/living/carbon/human/owner = limb?.owner
	var/datum/component/dirtiness/own = istype(owner) ? owner.GetComponent(/datum/component/dirtiness) : null
	var/datum/component/dirtiness/carrier = dirt_pools_carrier(limb, own)
	if(carrier)
		// dirt_pools_carrier() read the taur body just now
		var/datum/dirt_masks/masks = carrier.ready_taur_masks(dirt_source)
		. += "[DIRT_PRIVATE_KEY]pools=[masks ? masks.key : "pending"]"
	if(!own)
		return
	var/datum/dirt_masks/blood = own.ready_taur_blood_masks(src, limb)
	if(!own.taur_blood)
		return
	. += "[DIRT_PRIVATE_KEY]blood=[blood ? blood.key : "pending"]"
	if(own.waist_blood_over())
		. += DIRT_TAUR_BLOOD_OVER_KEY

/**
 * Returns the carrier of the taur body's dirt, or null if the body has none or can't draw it (dirt_read_source()).
 * Both icon_render_key() and get_overlay() ask this proc, so the dirt drawn always matches the key. Dirt drawn under a
 * key that didn't name it would be cached for every body that draws alike.
 *
 * Arguments:
 * - limb: The chest it's drawn on.
 * - carrier: The dirtiness component of the chest's owner, or null if it has none.
 */
/datum/bodypart_overlay/mutant/taur_body/proc/dirt_pools_carrier(obj/item/bodypart/limb, datum/component/dirtiness/carrier)
	RETURN_TYPE(/datum/component/dirtiness)
	return (length(carrier?.part_mess_splats[ORGAN_SLOT_EXTERNAL_TAUR]) || length(carrier?.part_splats?[ORGAN_SLOT_EXTERNAL_TAUR])) && dirt_read_source(limb) ? carrier : null

/**
 * Returns the taur body as dirt reads it: the images of each of its layers as get_images() draws them, with their
 * states taken together (dirt_read_images()). Returns null if they draw nothing on the 64x32 taur canvas, or if its
 * kind takes no dirt. Big Legs kinds take none: they're legs under the rider with no taur back. The body is read again
 * when the accessory, its base state or the limb's gender changes. The three are compared directly.
 *
 * Arguments:
 * - limb: The chest it's drawn on.
 */
/datum/bodypart_overlay/mutant/taur_body/proc/dirt_read_source(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/dirt_taur_source)
	var/datum/sprite_accessory/taur/kind = sprite_datum
	if(!kind || (kind.taur_mode & BODYSHAPE_TAUR_BIG_LEGS_ALL))
		return null
	var/base_state = get_base_icon_state()
	var/gender = limb?.limb_gender
	if(dirt_source_read && dirt_source_read[1] == kind && dirt_source_read[2] == base_state && dirt_source_read[3] == gender)
		return dirt_source
	dirt_source_read = list(kind, base_state, gender)
	dirt_source = null
	var/list/read = dirt_read_images(limb)
	if(read && get_icon_dimensions(read[1])["width"] == DIRT_TAUR_WIDTH)
		dirt_source = new(read[1], read[2])
	return dirt_source
