/**
 * A limb's skin semen: one container image at DIRT_SKIN_LAYER holding a tinted image per role mask, so a limb adds one
 * overlay to its person whatever the splats. Above the underclothes it lies over underwear as skin, and under the uniform
 * and everything worn. The masks are its carrier's, clipped to the pixels the limb shows.
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
	return !!(masks && length(masks.roles_by_limb[bodypart_owner.body_zone]))

/datum/bodypart_overlay/dirt_skin/get_image(obj/item/bodypart/limb, layer_index, layer_real)
	// together, so the height filter apply_height() puts on it reaches the role images, not just its empty icon
	var/mutable_appearance/container = mutable_appearance(layer = layer_real, appearance_flags = KEEP_TOGETHER)
	var/datum/dirt_masks/masks = carrier?.skin_masks
	if(masks)
		container.overlays += dirt_semen_role_images(masks.roles_by_limb[limb.body_zone])
	return container

/// The masks' key: limbs with the same sprites and splats share their cached images.
/datum/bodypart_overlay/dirt_skin/icon_render_key(obj/item/bodypart/limb)
	return list(carrier?.skin_masks?.key)

/**
 * Returns the body zones of the limbs skin semen draws on: the head, the chest and the legs, where aimed semen lands. You
 * should NEVER modify it.
 */
/proc/dirt_skin_zones()
	RETURN_TYPE(/list)
	var/static/list/zones = list(BODY_ZONE_HEAD, BODY_ZONE_CHEST, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	return zones

/**
 * Returns whether a limb draws the sprite zone sources name for its zone, or none where they name none.
 *
 * Arguments:
 * - limb: The limb.
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 */
/proc/dirt_limb_drawn_as(obj/item/bodypart/limb, list/zone_sources)
	var/list/source = zone_sources[limb.body_zone]
	var/sheet = limb.drawn_sheet()
	if(!sheet)
		return isnull(source)
	return source && source[1] == sheet && source[2] == custom_sprite_limb_state(limb)

/**
 * Returns a surface's role masks as images, one per role drawn, each tinted with its role's colour and alpha
 * (dirt_semen_role_colour()). Haze needs none of its own: it's half covered in the film mask. Each pixel holds one role,
 * so the order they're drawn in changes nothing; it's fixed so equal masks make equal appearances.
 *
 * Arguments:
 * - roles: alist(DIRT_ROLE_* define = registered icon), as /datum/dirt_masks holds them, or null.
 */
/proc/dirt_semen_role_images(alist/roles)
	RETURN_TYPE(/list)
	var/static/list/drawn_roles = list(DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_CORE, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	var/list/images = list()
	if(!roles)
		return images
	for(var/role in drawn_roles)
		var/mask = roles[role]
		if(!mask)
			continue
		var/list/tint = dirt_semen_role_colour(role)
		var/mutable_appearance/role_image = mutable_appearance(mask)
		role_image.color = tint[1]
		role_image.alpha = round(tint[2] * 255, 1)
		images += role_image
	return images
