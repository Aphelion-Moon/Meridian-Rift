/**
 * A limb's skin mess: one container image at DIRT_SKIN_LAYER holding the limb's baked image, so a limb adds one overlay
 * to its person whatever the splats. It lies under the underclothes, the genitals and everything worn. The masks are
 * its carrier's, clipped to the pixels the limb shows, fading out beside what's worn over them.
 */
/datum/bodypart_overlay/dirt_skin
	layers = list("" = DIRT_SKIN_LAYER)
	blocks_emissive = EMISSIVE_BLOCK_NONE
	draw_on_husks = HUSK_OVERLAY_NORMAL
	offset_location = ENTIRE_BODY
	overlay_flags = NONE
	/// The carrier whose skin splats it draws.
	var/datum/component/dirtiness/carrier

/**
 * Arguments:
 * - carrier: The carrier whose skin splats it draws.
 */
/datum/bodypart_overlay/dirt_skin/New(datum/component/dirtiness/carrier)
	. = ..()
	src.carrier = carrier

/// Draws only once the carrier's masks are made, and only on a limb they reach. Asking queues them.
/datum/bodypart_overlay/dirt_skin/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	. = ..()
	if(!. || !carrier)
		return FALSE
	var/datum/dirt_masks/masks = carrier.ready_skin_masks(bodypart_owner)
	return !!masks?.baked_by_limb[bodypart_owner.body_zone]

/datum/bodypart_overlay/dirt_skin/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	// together, so the height filter apply_height() puts on it reaches the baked image, not just its empty icon
	var/mutable_appearance/container = mutable_appearance(layer = layer_real, appearance_flags = KEEP_TOGETHER)
	var/baked = carrier?.skin?.masks?.baked_by_limb[limb.body_zone]
	if(baked)
		container.overlays += dirt_mess_baked_image(baked)
	return container

/// What the limb's baked image draws (/datum/dirt_masks/var/limb_keys), after DIRT_PRIVATE_KEY: the limb's images are
/// kept on its own mob (limb_icons_for()), and a landing elsewhere on the body leaves them as they were.
/datum/bodypart_overlay/dirt_skin/icon_render_key(obj/item/bodypart/limb)
	return list(DIRT_PRIVATE_KEY, carrier?.skin?.masks?.limb_keys[limb.body_zone])

/**
 * A person's mess on their underclothes: one container image on the chest at DIRT_UNDERCLOTHES_LAYER, over the
 * underclothes and under the uniform, holding the baked image of each piece worn and shown, already kept to the pixels
 * it shows.
 */
/datum/bodypart_overlay/dirt_underclothes
	layers = list("" = DIRT_UNDERCLOTHES_LAYER)
	blocks_emissive = EMISSIVE_BLOCK_NONE
	draw_on_husks = HUSK_OVERLAY_NORMAL
	offset_location = ENTIRE_BODY
	overlay_flags = NONE
	/// The carrier whose underclothes splats it draws.
	var/datum/component/dirtiness/carrier

/**
 * Arguments:
 * - carrier: The carrier whose underclothes splats it draws.
 */
/datum/bodypart_overlay/dirt_underclothes/New(datum/component/dirtiness/carrier)
	. = ..()
	src.carrier = carrier

/// Draws only once some of the carrier's masks are made. Asking queues them.
/datum/bodypart_overlay/dirt_underclothes/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	. = ..()
	if(!. || !carrier)
		return FALSE
	return !!length(carrier.ready_underclothes_masks())

/datum/bodypart_overlay/dirt_underclothes/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	var/mutable_appearance/container = mutable_appearance(layer = layer_real, appearance_flags = KEEP_TOGETHER)
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		if(drawn.masks?.baked)
			container.overlays += dirt_mess_baked_image(drawn.masks.baked)
	return container

/**
 * A bulge look drawn over a piece of underclothes covers that piece's mess with its cloth, so the mess is drawn again
 * over the cloth, kept to its pixels, as the look draws a garment's own mess over it (bulge_over_cloth()).
 */
/datum/bodypart_overlay/dirt_underclothes/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	var/datum/bodypart_overlay/mutant/genital/penis/look = dirt_bulge_over(limb)
	var/datum/dirt_drawing/drawn = look && carrier.underclothes_drawings?[dirt_bulge_piece(limb.owner, look)]
	var/clipped = drawn?.masks?.baked && bulge_clipped_icon(drawn.masks.baked, "", look.bulge_template)
	if(!clipped)
		return
	var/mutable_appearance/container = mutable_appearance(layer = -(look.bulge_layer - BULGE_ABOVE_COVER), appearance_flags = KEEP_TOGETHER)
	container.overlays += dirt_mess_baked_image(clipped)
	.[container] = NONE

/// The drawn masks' keys, after DIRT_PRIVATE_KEY: the chest's images follow them, kept on its own mob
/// (limb_icons_for()). A bulge look drawn over them adds its own key.
/datum/bodypart_overlay/dirt_underclothes/icon_render_key(obj/item/bodypart/limb)
	var/list/keys = list(DIRT_PRIVATE_KEY)
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		if(drawn.masks)
			keys += "[key]:[drawn.masks.key]"
	var/datum/bodypart_overlay/mutant/genital/penis/look = dirt_bulge_over(limb)
	if(look)
		keys += look.bulge_key
	return keys

/**
 * Returns the penis whose bulge look draws its adaptive cloth over a piece of the owner's underclothes, or null. The
 * penis resolves its look before this overlay is drawn: it's on the chest first.
 *
 * Arguments:
 * - limb: The chest.
 */
/datum/bodypart_overlay/dirt_underclothes/proc/dirt_bulge_over(obj/item/bodypart/limb)
	RETURN_TYPE(/datum/bodypart_overlay/mutant/genital/penis)
	var/mob/living/carbon/human/owner = limb?.owner
	var/obj/item/organ/genital/penis/penis = owner?.organs_slot[ORGAN_SLOT_PENIS]
	var/datum/bodypart_overlay/mutant/genital/penis/look = penis?.bodypart_overlay
	if(!carrier || !istype(look) || !look.bulge_key || !look.bulge_template?.mask_union || !ispath(look.bulge_cover_type, /datum/sprite_accessory/clothing))
		return null
	return look

/**
 * Returns the key of the piece of underclothes a bulge look covers (dirt_underclothes_key()), or null when none worn
 * is.
 *
 * Arguments:
 * - owner: Who wears it.
 * - look: The penis drawing the look.
 */
/datum/bodypart_overlay/dirt_underclothes/proc/dirt_bulge_piece(mob/living/carbon/human/owner, datum/bodypart_overlay/mutant/genital/penis/look)
	for(var/piece, accessory in dirt_underclothes_worn(owner))
		var/datum/sprite_accessory/clothing/worn = accessory
		if(worn.type == look.bulge_cover_type)
			return dirt_underclothes_key(piece, worn.name)
	return null

/**
 * Returns the body zones of the limbs skin mess draws on: the head, the chest and the legs, where aimed mess lands. You
 * should NEVER modify it.
 */
/proc/dirt_skin_zones()
	RETURN_TYPE(/list)
	var/static/list/zones = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	return zones

/**
 * Returns the body zones whose sprites a limb skin mess draws on checks besides its own (ready_skin_masks()): for the
 * chest the arms, which bring their hands and which no limb skin mess draws on draws (the chest checks the eyes too);
 * for the rest none. You should NEVER modify it.
 *
 * Arguments:
 * - zone: The limb's body zone.
 */
/proc/dirt_skin_besides(zone)
	RETURN_TYPE(/list)
	// literals: a proc static set from a call is set as the world starts, maybe before the statics that call reads
	var/static/list/arms = list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
	var/static/list/none = list()
	return zone == BODY_ZONE_CHEST ? arms : none

/**
 * Returns what a body's eyes and its human head are drawn from as dirt_zone_sources_match() reads them against zone
 * sources: list(the head, its limb_id, whether it draws eyes, the eyes, their sheet, their state).
 *
 * Arguments:
 * - body: The person.
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 */
/proc/dirt_eye_reads(mob/living/carbon/human/body, list/zone_sources)
	RETURN_TYPE(/list)
	var/obj/item/bodypart/head/head = zone_sources[BODY_ZONE_HEAD] ? body.get_bodypart(BODY_ZONE_HEAD) : null
	var/eye_sprites = head?.head_flags & HEAD_EYESPRITES
	var/obj/item/organ/eyes/eyes = eye_sprites ? body.get_organ_slot(ORGAN_SLOT_EYES) : null
	return list(head, head?.limb_id, eye_sprites, eyes, eyes?.eye_icon, eyes?.eye_icon_state)

/**
 * Returns whether a body's eyes and its human head are drawn from what they were when dirt_eye_reads() read them, read
 * as it reads them without making a list.
 *
 * Arguments:
 * - body: The person.
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 * - reads: What dirt_eye_reads() returned.
 */
/proc/dirt_eyes_unchanged(mob/living/carbon/human/body, list/zone_sources, list/reads)
	var/obj/item/bodypart/head/head = zone_sources[BODY_ZONE_HEAD] ? body.get_bodypart(BODY_ZONE_HEAD) : null
	var/eye_sprites = head?.head_flags & HEAD_EYESPRITES
	var/obj/item/organ/eyes/eyes = eye_sprites ? body.get_organ_slot(ORGAN_SLOT_EYES) : null
	return reads[1] == head && reads[2] == head?.limb_id && reads[3] == eye_sprites && reads[4] == eyes && reads[5] == eyes?.eye_icon && reads[6] == eyes?.eye_icon_state

/**
 * Returns what this limb's sprites are drawn from as mess reads them (drawn_sheet(), custom_sprite_limb_state()): the
 * limb, then every var those read. A limb that still reads the same (dirt_sprite_unchanged()) draws the same sprites.
 */
/obj/item/bodypart/proc/dirt_sprite_reads()
	RETURN_TYPE(/list)
	return list(src, bodypart_flags & BODYPART_STUMP, is_invisible, is_actually_just_invisible, should_draw_greyscale, icon_greyscale, icon_static, limb_id, body_zone, aux_zone, is_dimorphic, limb_gender, bodyshape & BODYSHAPE_DIGITIGRADE)

/**
 * Returns whether this limb's sprites are drawn from what they were when dirt_sprite_reads() read it.
 *
 * Arguments:
 * - reads: What dirt_sprite_reads() returned.
 */
/obj/item/bodypart/proc/dirt_sprite_unchanged(list/reads)
	return reads[1] == src && reads[2] == (bodypart_flags & BODYPART_STUMP) && reads[3] == is_invisible && reads[4] == is_actually_just_invisible && reads[5] == should_draw_greyscale && reads[6] == icon_greyscale && reads[7] == icon_static && reads[8] == limb_id && reads[9] == body_zone && reads[10] == aux_zone && reads[11] == is_dimorphic && reads[12] == limb_gender && reads[13] == (bodyshape & BODYSHAPE_DIGITIGRADE)

/**
 * Returns an image of a surface's baked mess, drawn as it is: its colours and alpha are in its pixels
 * (dirt_baked_icon()).
 *
 * Arguments:
 * - baked: The baked icon, as /datum/dirt_masks holds it.
 */
/proc/dirt_mess_baked_image(icon/baked)
	RETURN_TYPE(/mutable_appearance)
	return mutable_appearance(baked)
