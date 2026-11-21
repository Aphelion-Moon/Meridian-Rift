/**
 * A limb's skin dirt: one container image at DIRT_SKIN_LAYER holding the limb's baked image, with that image's emissive
 * blocker beside it. So a limb adds one of each to its person whatever the splats, and an arm adds one more of each for
 * its hand (/datum/bodypart_overlay/dirt_skin/arm). It lies under the underclothes, the genitals and everything worn.
 * The masks are its carrier's, clipped to the pixels the limb shows, fading out beside what's worn over them.
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
	return !!masks && draws_from(masks, bodypart_owner)

/**
 * Returns whether the masks hold the baked image this overlay draws on a limb, which is the limb's own.
 *
 * Arguments:
 * - masks: The carrier's skin masks.
 * - limb: The limb.
 */
/datum/bodypart_overlay/dirt_skin/proc/draws_from(datum/dirt_masks/masks, obj/item/bodypart/limb)
	return !!masks.baked_by_limb[limb.body_zone]

/**
 * Returns the zone whose baked image a layer of this overlay draws, which is the limb's own zone.
 *
 * Arguments:
 * - limb: The limb.
 * - layer_index: The layer's key in `layers`.
 */
/datum/bodypart_overlay/dirt_skin/proc/layer_zone(obj/item/bodypart/limb, layer_index)
	return limb.body_zone

/datum/bodypart_overlay/dirt_skin/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	// together, so the height filter apply_height() puts on it reaches the baked image, not just its empty icon
	var/mutable_appearance/container = mutable_appearance(layer = layer_real, appearance_flags = KEEP_TOGETHER)
	var/baked = carrier?.skin?.masks?.baked_by_limb[layer_zone(limb, layer_index)]
	if(baked)
		container.overlays += dirt_mess_baked_image(baked)
	return container

/// Adds the baked image's emissive blocker beside its container (dirt_emissive_blocker()). Each is one of the limb's
/// images, so apply_height() moves the blocker as it moves the container.
/datum/bodypart_overlay/dirt_skin/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	var/baked = carrier?.skin?.masks?.baked_by_limb[layer_zone(limb, layer_index)]
	if(baked)
		.[dirt_emissive_blocker(baked, limb, .[1])] = LIMB_OVERLAY_META

/// What the limb's baked image draws (/datum/dirt_masks/var/limb_keys), after DIRT_PRIVATE_KEY: the limb's images are
/// kept on its own mob (limb_icons_for()), and a landing elsewhere on the body leaves them as they were.
/datum/bodypart_overlay/dirt_skin/icon_render_key(obj/item/bodypart/limb)
	return list(DIRT_PRIVATE_KEY, carrier?.skin?.masks?.limb_keys[limb.body_zone])

/**
 * An arm's skin dirt. It draws the arm's baked image at DIRT_SKIN_LAYER, as every limb does, and the hand's at
 * DIRT_HAND_SKIN_LAYER. That layer lies over the hand and under gloves, and the hand draws over the uniform. Each layer
 * draws only while its baked image has something to draw.
 */
/datum/bodypart_overlay/dirt_skin/arm
	layers = list("" = DIRT_SKIN_LAYER, DIRT_HAND_LAYER_POSTFIX = DIRT_HAND_SKIN_LAYER)

/// Draws while the masks hold a baked image for the arm or its hand.
/datum/bodypart_overlay/dirt_skin/arm/draws_from(datum/dirt_masks/masks, obj/item/bodypart/limb)
	var/alist/baked_by_limb = masks.baked_by_limb
	return !!(baked_by_limb[limb.body_zone] || baked_by_limb[limb.aux_zone])

/// The DIRT_HAND_LAYER_POSTFIX layer draws the hand's baked image, and the other layer draws the arm's.
/datum/bodypart_overlay/dirt_skin/arm/layer_zone(obj/item/bodypart/limb, layer_index)
	return layer_index == DIRT_HAND_LAYER_POSTFIX ? limb.aux_zone : limb.body_zone

/// Returns an overlay for each layer whose baked image has something to draw: the arm's, the hand's, or both.
/datum/bodypart_overlay/dirt_skin/arm/get_all_overlays(obj/item/bodypart/limb)
	. = list()
	var/alist/baked_by_limb = carrier?.skin?.masks?.baked_by_limb
	for(var/layer_index, layer_number in layers)
		if(baked_by_limb?[layer_zone(limb, layer_index)])
			. += get_overlay(limb, layer_index, -layer_number)

/// The keys of the arm's and the hand's baked images, after DIRT_PRIVATE_KEY as on every limb.
/datum/bodypart_overlay/dirt_skin/arm/icon_render_key(obj/item/bodypart/limb)
	var/alist/limb_keys = carrier?.skin?.masks?.limb_keys
	return list(DIRT_PRIVATE_KEY, limb_keys?[limb.body_zone], limb_keys?[limb.aux_zone])

/**
 * Adds DIRT_HAND_LAYER_POSTFIX before setup_lists() builds its sprite accessory lists, so the arm's "hand" layer
 * (above) is in SSaccessories.all_layer_postfixes before anything reads it. That list holds every bodypart_overlay
 * layer postfix. The matrixed colour probes in sprite_accessories.dm and taur_types.dm walk it as they build each
 * matrixed accessory. No accessory icon has a state ending in DIRT_HAND_LAYER_POSTFIX, so those probes find nothing
 * for it. It's added with |=, so a second call can't add it twice.
 */
/datum/controller/subsystem/accessories/setup_lists()
	all_layer_postfixes |= DIRT_HAND_LAYER_POSTFIX
	return ..()

/**
 * Returns a new skin overlay for a limb. An arm's overlay draws its hand too.
 *
 * Arguments:
 * - zone: The limb's body zone.
 * - carrier: The carrier whose skin splats it draws.
 */
/proc/dirt_skin_overlay(zone, datum/component/dirtiness/carrier)
	RETURN_TYPE(/datum/bodypart_overlay/dirt_skin)
	if(zone == BODY_ZONE_L_ARM || zone == BODY_ZONE_R_ARM)
		return new /datum/bodypart_overlay/dirt_skin/arm(carrier)
	return new /datum/bodypart_overlay/dirt_skin(carrier)

/**
 * A person's mess on their underclothes: one container image on the chest at DIRT_UNDERCLOTHES_LAYER, over the
 * underclothes and under the uniform. It holds the baked image of each piece worn and shown, already kept to the pixels
 * the piece shows. Each baked image's emissive blocker draws beside the container. A piece holding sweat also draws its
 * multiplier there (get_all_overlays()), and no blocker for it.
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
 * Adds each piece's baked image's emissive blocker beside the container (dirt_emissive_blocker()). A bulge look drawn
 * over a piece of underclothes covers that piece's mess with its cloth. So the mess is drawn again over the cloth, kept
 * to its pixels, as the look draws a garment's own mess over it (bulge_over_cloth()). The copy draws its own blocker.
 */
/datum/bodypart_overlay/dirt_underclothes/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	. = ..()
	var/mutable_appearance/pieces_container = .[1]
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/piece = drawing
		if(piece.masks?.baked)
			.[dirt_emissive_blocker(piece.masks.baked, limb, pieces_container)] = LIMB_OVERLAY_META
	var/datum/bodypart_overlay/mutant/genital/penis/look = dirt_bulge_over(limb)
	var/datum/dirt_drawing/drawn = look && carrier.underclothes_drawings?[dirt_bulge_piece(limb.owner, look)]
	var/clipped = drawn?.masks?.baked && bulge_clipped_icon(drawn.masks.baked, "", look.bulge_template)
	if(!clipped)
		return
	var/mutable_appearance/container = mutable_appearance(layer = -(look.bulge_layer - BULGE_ABOVE_COVER), appearance_flags = KEEP_TOGETHER)
	container.overlays += dirt_mess_baked_image(clipped)
	.[container] = NONE
	.[dirt_emissive_blocker(clipped, limb, container)] = LIMB_OVERLAY_META

/**
 * Returns the container, unless every piece drawn holds sweat alone, which bakes no colour. After it comes the
 * multiplier of each piece whose masks hold sweat (current_wet()), drawn on its own beside the container, because
 * there it darkens the piece under it. Inside the container it would darken only what's in the container. Its pixels
 * lie only on those the piece shows, so it draws on nothing else.
 */
/datum/bodypart_overlay/dirt_underclothes/get_all_overlays(obj/item/bodypart/limb)
	. = list()
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		if(drawn.masks && (drawn.masks.baked || !drawn.masks.wet))
			. = ..()
			break
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		// a piece whose sweat has gone is still asked, so it lets go of the multiplier it held
		if(!drawn.masks?.wet && !drawn.wet_key)
			continue
		var/icon/factors = drawn.current_wet(carrier.parent, DIRT_REDRAW_BODY, wet_garment(key, drawn))
		if(!factors)
			continue
		var/mutable_appearance/multiplier = dirt_wet_image(factors)
		multiplier.layer = -DIRT_UNDERCLOTHES_LAYER
		.[multiplier] = NONE

/**
 * Returns the sprite a piece of underclothes draws, in the form current_wet() takes for a garment. Returns null unless
 * its drawn masks hold sweat. Its colour is the one get_underwear_overlays() draws it in. That's the body's colour for
 * the piece (dirt_underclothes_colour()), or none for a static accessory.
 *
 * Arguments:
 * - key: The piece's underclothes key (dirt_underclothes_key()).
 * - drawn: The piece's masks being drawn.
 */
/datum/bodypart_overlay/dirt_underclothes/proc/wet_garment(key, datum/dirt_drawing/drawn)
	RETURN_TYPE(/list)
	var/list/sprite = drawn.masks?.wet && drawn.request?.clip?[1]
	if(!sprite)
		return null
	var/piece = dirt_underclothes_piece(key)
	var/datum/sprite_accessory/clothing/accessory = dirt_underclothes_worn(carrier.parent)[piece]
	return list(sprite[1], sprite[2], accessory?.use_static ? null : dirt_underclothes_colour(carrier.parent, piece), null, 0, 0)

/// The drawn masks' keys, after DIRT_PRIVATE_KEY: the chest's images follow them, kept on its own mob
/// (limb_icons_for()). A piece holding sweat adds the key of the multiplier it holds. It takes up one SSdirt has made
/// since, or asks for one it lacks (current_wet()). So the chest is drawn again once the multiplier is made, even if
/// SSdirt dropped it before the chest was drawn with it. A bulge look drawn over the underclothes adds its own key.
/datum/bodypart_overlay/dirt_underclothes/icon_render_key(obj/item/bodypart/limb)
	var/list/keys = list(DIRT_PRIVATE_KEY)
	for(var/key, drawing in carrier?.underclothes_drawings)
		var/datum/dirt_drawing/drawn = drawing
		if(drawn.masks)
			keys += "[key]:[drawn.masks.key]"
			if(drawn.masks.wet || drawn.wet_key)
				drawn.current_wet(carrier.parent, DIRT_REDRAW_BODY, wet_garment(key, drawn))
				if(drawn.wet_key)
					keys += "wet:[drawn.wet_key]"
	var/datum/bodypart_overlay/mutant/genital/penis/look = dirt_bulge_over(limb)
	if(look)
		keys += look.bulge_key
	return keys

/**
 * Returns the penis whose bulge look draws its adaptive cloth over a piece of the owner's underclothes, or null. The
 * penis resolves its look before this overlay is drawn, as long as it comes first on the chest. A chest swap can
 * change which comes first.
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
 * Returns the limbs each skin zone's pixels lie on, as alist(body zone = DIRT_LIMB_BIT() of each). Its keys are the
 * body zones of the limbs skin dirt draws on: the head, the chest, the arms with their hands and the legs. Mess draws
 * on the head, the chest and the legs, where aimed mess lands. A zone's overlay draws while a splat lies on one of its
 * limbs. The chest's rows from DIRT_BELT down lie on the legs, and an arm takes its hand. You should NEVER modify it.
 */
/proc/dirt_skin_zone_limbs()
	RETURN_TYPE(/alist)
	var/static/alist/limbs = alist(
		BODY_ZONE_HEAD = DIRT_LIMB_BIT(DIRT_LIMB_HEAD),
		BODY_ZONE_CHEST = DIRT_LIMB_BIT(DIRT_LIMB_TORSO) | DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		BODY_ZONE_L_ARM = DIRT_LIMB_BIT(DIRT_LIMB_L_ARM),
		BODY_ZONE_R_ARM = DIRT_LIMB_BIT(DIRT_LIMB_R_ARM),
		BODY_ZONE_L_LEG = DIRT_LIMB_BIT(DIRT_LIMB_L_LEG),
		BODY_ZONE_R_LEG = DIRT_LIMB_BIT(DIRT_LIMB_R_LEG),
	)
	return limbs

/**
 * Returns the body zones whose sprites ready_skin_masks() checks besides a limb's own, for a limb that skin dirt draws
 * on. For the chest those are the arms, which bring their hands, and whose own overlays draw only while general dirt
 * lies on them. The chest checks the eyes too. For every other limb it returns none. You should NEVER modify it.
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

/**
 * Returns an emissive blocker in a baked image's shape and at its alpha, to draw just after an image of it. The dirt
 * then dims what glows under it as much as it covers it. It takes that image's layer, alpha, offsets and blend.
 *
 * Arguments:
 * - baked: The baked icon, as /datum/dirt_masks holds it.
 * - spokesman: What its plane offset is read from: the limb, the person or the item.
 * - beside: The image drawing the baked icon, or the container holding it.
 */
/proc/dirt_emissive_blocker(icon/baked, atom/spokesman, mutable_appearance/beside)
	RETURN_TYPE(/mutable_appearance)
	var/mutable_appearance/blocker = emissive_blocker(baked, "", spokesman, beside.layer, beside.alpha)
	blocker.pixel_x = beside.pixel_x
	blocker.pixel_y = beside.pixel_y
	blocker.pixel_w = beside.pixel_w
	blocker.pixel_z = beside.pixel_z
	blocker.blend_mode = beside.blend_mode
	return blocker
