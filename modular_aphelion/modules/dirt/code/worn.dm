/// How many sprites' coverage of a zone dirt_sprite_zone_pixels() keeps: a few dozen numbers each.
#define DIRT_COVERAGE_READS 512

/**
 * Returns the worn item a shot at a zone lands on, or null for the skin: the outermost of the head, mask, suit and
 * uniform slots whose body_parts_covered includes the zone's part (the chest for the chest, stomach and back; the groin
 * for the groin and butt; the legs for the thighs). The face is covered when the mouth is, by the item covering it.
 * Underclothes never count: they aren't items. Through a wall portal only the uniform counts, while it's drawn: the
 * relay copies it and no suit (lower_body_only()), so a coat over the lower body leaves the shot to what the relay
 * shows under it. A skirt the relay leaves out (wall_relay_skips_uniform()) leaves it to the underclothes or the skin.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target.
 */
/proc/dirt_mess_garment(mob/living/carbon/human/target, zone, portal_view = DIRT_PORTAL_NONE)
	RETURN_TYPE(/obj/item)
	if(zone == DIRT_ZONE_FACE)
		return target.is_mouth_covered()
	var/part = dirt_zone_cover_flags()[zone]
	if(!part)
		return null
	if(portal_view == DIRT_PORTAL_LOWER_BODY)
		var/obj/item/uniform = target.w_uniform
		// as update_worn_undersuit() draws it, and the relay with it
		var/drawn = uniform && !(target.obscured_slots & HIDEJUMPSUIT) && !HAS_TRAIT(uniform, TRAIT_NO_WORN_ICON) && !target.wall_relay_skips_uniform()
		return (drawn && (uniform.body_parts_covered & part)) ? uniform : null
	for(var/obj/item/worn as anything in list(target.head, target.wear_mask, target.wear_suit, target.w_uniform))
		if(worn && (worn.body_parts_covered & part))
			return worn
	return null

/**
 * Returns the body_parts_covered flag each zone below the face lies under: list(zone = flag).
 * You should NEVER modify it.
 */
/proc/dirt_zone_cover_flags()
	RETURN_TYPE(/list)
	var/static/list/flags = list(
		DIRT_ZONE_CHEST = CHEST,
		DIRT_ZONE_STOMACH = CHEST,
		DIRT_ZONE_BACK = CHEST,
		DIRT_ZONE_GROIN = GROIN,
		DIRT_ZONE_BUTT = GROIN,
		DIRT_ZONE_THIGHS = LEGS,
	)
	return flags

/**
 * Returns the carrier a shot at a zone lands on, and the underclothes it lands on: list(/datum/component/dirtiness, a
 * DIRT_UNDERCLOTHES_* define or null). The outermost garment over the zone takes it (dirt_mess_garment()), else the
 * underclothes that cover it, held by the person, else the skin.
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 * - portal_view: A DIRT_PORTAL_* define, what a portal shows of the target.
 */
/proc/dirt_mess_surface(mob/living/carbon/human/target, zone, portal_view = DIRT_PORTAL_NONE)
	RETURN_TYPE(/list)
	var/obj/item/garment = dirt_mess_garment(target, zone, portal_view)
	if(garment)
		return list(garment.LoadComponent(/datum/component/dirtiness), null)
	return list(target.LoadComponent(/datum/component/dirtiness), dirt_underclothes_on(target, zone))

/**
 * Returns an image drawing cloth's baked mess over a garment, kept to the garment's own pixels by BLEND_INSET_OVERLAY
 * inside the worn KEEP_TOGETHER wrapper build_worn_icon() makes. It floats, and on a garment drawn on the body's own
 * tile it isn't offset, so the bulge redraws it over its cloth too (bulge_over_cloth()).
 *
 * Arguments:
 * - baked: The baked icon, as /datum/dirt_masks holds a cloth's.
 * - shift_x, shift_y: Pixels right and up in the wrapper: dirt_worn_shift() for the body's 32x32 masks, DIRT_TAUR_INSET
 *   less to the right for pools on the 64x32 taur canvas round it.
 */
/proc/dirt_mess_inset_image(icon/baked, shift_x = 0, shift_y = 0)
	RETURN_TYPE(/mutable_appearance)
	var/mutable_appearance/inset = dirt_mess_baked_image(baked)
	inset.blend_mode = BLEND_INSET_OVERLAY
	inset.pixel_w = shift_x
	inset.pixel_z = shift_y
	return inset

/**
 * Returns where a worn garment's wrapper has its wearer's own tile, as list(pixels right, pixels up):
 * build_worn_icon() centres the wrapper on the garment's worn dimensions, then moves it by its worn offsets, so masks
 * drawn on the body go back by both. list(0, 0) for a 32x32 garment without offsets; list(16, 0) for a 64x32 taur
 * suit, moved 16 px left.
 *
 * Arguments:
 * - garment: The worn item.
 */
/proc/dirt_worn_shift(obj/item/garment)
	RETURN_TYPE(/list)
	var/mutable_appearance/centred = center_image(new /mutable_appearance, garment.worn_x_dimension, garment.worn_y_dimension)
	var/list/offsets = garment.get_worn_offsets(FALSE)
	return list(-centred.pixel_w - offsets[1], -centred.pixel_z - offsets[2])

/**
 * Returns whether a garment is drawn on its wearer's taur body as a taur suit: a sprite spanning the 64x32 taur canvas,
 * the body's own tile in its middle, which takes the taur body's pools.
 *
 * Arguments:
 * - garment: The worn item.
 * - wearer: Who wears it.
 */
/proc/dirt_taur_fitted(obj/item/garment, mob/living/carbon/human/wearer)
	if(!istype(wearer.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body))
		return FALSE
	var/image/sprite = bulge_drawn_leaf(bulge_drawn_root(wearer.overlays_standing[dirt_slot_layer(wearer.get_slot_by_item(garment))]))
	return sprite && get_icon_dimensions(sprite.icon)["width"] == DIRT_TAUR_WIDTH

/**
 * Returns the overlays_standing slots whose sprites cover skin mess, so it fades out beside them: the underclothes and
 * the garments. You should NEVER modify it.
 */
/proc/dirt_cover_layers()
	RETURN_TYPE(/list)
	var/static/list/layers = list(BODY_LAYER, UNIFORM_LAYER, SUIT_LAYER, SHOES_LAYER, NECK_LAYER, HEAD_LAYER, FACEMASK_LAYER)
	return layers

/**
 * Returns the sprites a body draws over its skin, from what it wears: list(list(icon, icon state), ...), in
 * dirt_cover_layers() order.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_cover_sprites(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list()
	for(var/layer in dirt_cover_layers())
		var/standing = body.overlays_standing[layer]
		if(!standing)
			continue
		for(var/image/root as anything in (islist(standing) ? standing : list(standing)))
			if(root.plane != FLOAT_PLANE)
				continue
			var/image/leaf = bulge_drawn_leaf(root)
			if(leaf)
				. += list(list(leaf.icon, leaf.icon_state))

/**
 * Returns sprites as one line of text, to key masks by and to tell outfits apart.
 *
 * Arguments:
 * - sprites: list(list(icon, icon state), ...), or null.
 */
/proc/dirt_sprites_key(list/sprites)
	var/list/parts = list()
	for(var/list/sprite as anything in sprites)
		parts += "[dirt_sprite_key(sprite[1])]:[sprite[2]]"
	return jointext(parts, ";")

/**
 * Returns the underclothes a body draws, each its own surface: alist(DIRT_UNDERCLOTHES_* define = its
 * /datum/sprite_accessory/clothing), as get_underwear_overlays() picks them.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_underclothes_worn(mob/living/carbon/human/body)
	RETURN_TYPE(/alist)
	var/alist/worn = alist()
	if(HAS_TRAIT(body, TRAIT_HUSK) || HAS_TRAIT(body, TRAIT_INVISIBLE_MAN) || HAS_TRAIT(body, TRAIT_NO_UNDERWEAR))
		return worn
	var/hidden = body.underwear_visibility
	var/list/candidates = list(
		DIRT_UNDERCLOTHES_UNDERWEAR = !(hidden & UNDERWEAR_HIDE_UNDIES) && SSaccessories.underwear_list[body.underwear],
		DIRT_UNDERCLOTHES_BRA = !(hidden & UNDERWEAR_HIDE_BRA) && SSaccessories.bra_list[body.bra],
		DIRT_UNDERCLOTHES_UNDERSHIRT = !(hidden & UNDERWEAR_HIDE_SHIRT) && SSaccessories.undershirt_list[body.undershirt],
		DIRT_UNDERCLOTHES_SOCKS = !(hidden & UNDERWEAR_HIDE_SOCKS) && body.num_legs >= 2 && isnull(body.dna.mutant_bodyparts[FEATURE_TAUR]) && SSaccessories.socks_list[body.socks],
	)
	for(var/piece, candidate in candidates)
		var/datum/sprite_accessory/clothing/accessory = candidate
		// "Nude" draws nothing
		if(istype(accessory) && accessory.icon_state)
			worn[piece] = accessory
	return worn

/**
 * Returns a body's underclothes as drawn, lowest first: list(list(DIRT_UNDERCLOTHES_* define, icon, icon state,
 * accessory name), ...). Each is drawn as get_underwear_overlays() draws it, fitted to the body, a revealing loincloth
 * with its flap cut away while the bulge cuts it (bulge_cut_worn()), and they stack by their accessories' layers, then
 * in that proc's order.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_underclothes_sprites(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	var/alist/worn = dirt_underclothes_worn(body)
	var/body_type = MALE
	if(body.dna.species.sexes)
		var/obj/item/bodypart/chest/chest = body.get_bodypart(BODY_ZONE_CHEST)
		if(chest?.is_dimorphic)
			body_type = body.physique
	var/static/list/drawn_order = list(DIRT_UNDERCLOTHES_UNDERWEAR, DIRT_UNDERCLOTHES_BRA, DIRT_UNDERCLOTHES_UNDERSHIRT, DIRT_UNDERCLOTHES_SOCKS)
	var/list/colours = list(
		DIRT_UNDERCLOTHES_UNDERWEAR = body.underwear_color,
		DIRT_UNDERCLOTHES_BRA = body.bra_color,
		DIRT_UNDERCLOTHES_UNDERSHIRT = body.undershirt_color,
		DIRT_UNDERCLOTHES_SOCKS = body.socks_color,
	)
	var/list/drawn = list()
	var/obj/item/organ/genital/penis/penis = body.organs_slot[ORGAN_SLOT_PENIS]
	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis?.bodypart_overlay
	for(var/piece in drawn_order)
		var/datum/sprite_accessory/clothing/accessory = worn[piece]
		var/mutable_appearance/sprite = accessory?.make_appearance(colours[piece], body_type, body.bodyshape, body)
		if(!sprite?.icon)
			continue
		var/sprite_icon = sprite.icon
		var/sprite_state = sprite.icon_state
		if(piece == DIRT_UNDERCLOTHES_UNDERWEAR && istype(penis_overlay) && isfile(sprite_icon))
			var/datum/cut = penis_overlay.bulge_wanted_cut(body, BODY_LAYER)
			var/cut_icon = cut && bulge_cut_sprite(sprite_icon, sprite_state, cut)
			if(cut_icon)
				sprite_icon = cut_icon
				sprite_state = ""
		drawn += list(list(piece, sprite_icon, sprite_state, accessory.name, accessory.layer))
	sortTim(drawn, GLOBAL_PROC_REF(cmp_dirt_underclothes_drawn))
	for(var/list/entry as anything in drawn)
		entry.Cut(5)
	return drawn

/// Sorts underclothes from dirt_underclothes_sprites() lowest first: the higher layer number draws under.
/proc/cmp_dirt_underclothes_drawn(list/first, list/second)
	return second[5] - first[5]

/**
 * Returns the key a person's mess on one piece of underclothes is kept under: the slot and the accessory, so it stays
 * with that piece while it's off.
 *
 * Arguments:
 * - piece: A DIRT_UNDERCLOTHES_* define.
 * - name: The accessory's name.
 */
/proc/dirt_underclothes_key(piece, name)
	return "[piece]|[name]"

/**
 * Returns which underclothes a shot at a zone lands on, or null for the skin. Each piece is judged by its sprite
 * against the zone's pixels on the plain human template (dirt_human_zone_pixels()), so every body is judged on the
 * human shape and nothing waits on its own template.
 * - The pieces with a pixel in the zone take the shot when together they cover at least half of it.
 * - The one that shows the most of the zone takes it: its pixels there less those the pieces above it draw over. Ties
 *   go to the kind that belongs on the zone (dirt_zone_underclothes()), then to the topmost. So a shirt hem over the
 *   waistband doesn't take a groin shot from the underwear, and a corset does.
 * - Until the human template is built that far, the rules judge instead (dirt_underclothes_by_rules()).
 *
 * Arguments:
 * - target: The person.
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_underclothes_on(mob/living/carbon/human/target, zone)
	var/list/drawn = dirt_underclothes_sprites(target)
	if(!length(drawn))
		return null
	var/list/zone_pixels = dirt_human_zone_pixels(zone)
	if(!zone_pixels)
		return dirt_underclothes_by_rules(target, drawn, zone)
	var/list/kinds = dirt_zone_underclothes()[zone]
	var/list/covered = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	var/covered_count = 0
	var/best_piece
	var/best_shown = 0
	var/best_rank
	// topmost first, so what a piece shows is what no piece above it covers, and a full tie keeps the topmost
	for(var/index in length(drawn) to 1 step -1)
		var/list/entry = drawn[index]
		var/shown = 0
		for(var/pixel in dirt_sprite_zone_pixels(entry[2], entry[3], zone, zone_pixels))
			if(!covered[pixel])
				covered[pixel] = TRUE
				shown++
		if(!shown)
			continue
		covered_count += shown
		var/rank = LAZYFIND(kinds, entry[1]) || INFINITY
		if(shown > best_shown || (shown == best_shown && rank < best_rank))
			best_piece = entry[1]
			best_shown = shown
			best_rank = rank
	return covered_count * 2 >= length(zone_pixels) ? best_piece : null

/**
 * Returns which underclothes a shot at a zone lands on before the human template is built: the topmost piece covering
 * it by the rules underclothes follow elsewhere, or null. Underwear covers the groin and butt, an undershirt or bra the
 * chest, and an undershirt the stomach and back too. A piece also covers what it hides (dirt_underclothes_hides()).
 *
 * Arguments:
 * - target: The person.
 * - drawn: Their underclothes, from dirt_underclothes_sprites().
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_underclothes_by_rules(mob/living/carbon/human/target, list/drawn, zone)
	var/static/list/rules = list(
		DIRT_UNDERCLOTHES_UNDERWEAR = list(DIRT_ZONE_GROIN, DIRT_ZONE_BUTT),
		DIRT_UNDERCLOTHES_UNDERSHIRT = list(DIRT_ZONE_CHEST, DIRT_ZONE_STOMACH, DIRT_ZONE_BACK),
		DIRT_UNDERCLOTHES_BRA = list(DIRT_ZONE_CHEST),
	)
	var/alist/worn = dirt_underclothes_worn(target)
	for(var/index in length(drawn) to 1 step -1)
		var/list/entry = drawn[index]
		var/piece = entry[1]
		if((zone in rules[piece]) || dirt_underclothes_hides(worn[piece], piece, zone))
			return piece
	return null

/**
 * Returns whether the underclothes rules say a piece hides a zone outright: an undershirt that hides the groin
 * (a corset, a leotard) the groin and butt, underwear that hides the breasts (a one-piece swimsuit) the chest.
 *
 * Arguments:
 * - accessory: The piece's accessory.
 * - piece: Its DIRT_UNDERCLOTHES_* define.
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_underclothes_hides(datum/sprite_accessory/clothing/accessory, piece, zone)
	if(!accessory)
		return FALSE
	switch(zone)
		if(DIRT_ZONE_GROIN, DIRT_ZONE_BUTT)
			var/datum/sprite_accessory/clothing/undershirt/shirt = accessory
			return piece == DIRT_UNDERCLOTHES_UNDERSHIRT && shirt.hides_groin
		if(DIRT_ZONE_CHEST)
			return piece == DIRT_UNDERCLOTHES_UNDERWEAR && accessory.hides_breasts
	return FALSE

/**
 * Returns the kinds of underclothes that belong on each zone, in the order they take a tied shot there: list(zone =
 * list of DIRT_UNDERCLOTHES_* defines). You should NEVER modify it.
 */
/proc/dirt_zone_underclothes()
	RETURN_TYPE(/list)
	var/static/list/kinds = list(
		DIRT_ZONE_CHEST = list(DIRT_UNDERCLOTHES_UNDERSHIRT, DIRT_UNDERCLOTHES_BRA),
		DIRT_ZONE_STOMACH = list(DIRT_UNDERCLOTHES_UNDERSHIRT),
		DIRT_ZONE_BACK = list(DIRT_UNDERCLOTHES_UNDERSHIRT),
		DIRT_ZONE_GROIN = list(DIRT_UNDERCLOTHES_UNDERWEAR, DIRT_UNDERCLOTHES_SOCKS),
		DIRT_ZONE_BUTT = list(DIRT_UNDERCLOTHES_UNDERWEAR, DIRT_UNDERCLOTHES_SOCKS),
		DIRT_ZONE_THIGHS = list(DIRT_UNDERCLOTHES_UNDERWEAR, DIRT_UNDERCLOTHES_SOCKS),
	)
	return kinds

/**
 * Returns which of a zone's pixels a sprite covers, read at those pixels only, facing the way that shows the zone. Kept
 * for each sprite and zone, the oldest dropped past DIRT_COVERAGE_READS. A sprite that isn't 32x32 covers none. You
 * should NEVER modify the list it returns.
 *
 * Arguments:
 * - sheet: The sprite's icon file, or an icon made at run time.
 * - state: Its icon state.
 * - zone: A DIRT_ZONE_* define.
 * - zone_pixels: The zone's pixels, from dirt_human_zone_pixels().
 */
/proc/dirt_sprite_zone_pixels(sheet, state, zone, list/zone_pixels)
	RETURN_TYPE(/list)
	var/static/datum/bulge_bounded_cache/reads
	if(!reads)
		reads = new
		reads.limit = DIRT_COVERAGE_READS
	var/key = "[dirt_sprite_key(sheet)]|[state]|[zone]"
	var/list/covered = reads.fetch(key)
	if(covered)
		return covered
	covered = list()
	var/icon/sprite = icon(sheet, state)
	if(sprite.Width() == ICON_SIZE_X && sprite.Height() == ICON_SIZE_Y)
		var/direction = dirt_zone_facing(zone)
		for(var/index in zone_pixels)
			var/row = floor((index - 1) / ICON_SIZE_X)
			if(sprite.GetPixel(index - row * ICON_SIZE_X, ICON_SIZE_Y - row, null, direction))
				covered += index
	return reads.store_value(key, covered)

/**
 * Returns the direction a zone is judged from, the one that shows it: north for the back and butt, south for the rest.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_zone_facing(zone)
	return (zone == DIRT_ZONE_BACK || zone == DIRT_ZONE_BUTT) ? NORTH : SOUTH

/**
 * Returns a zone's pixels on the plain human template, facing the way that shows it (dirt_zone_facing()): the body
 * pixels whose limb, angle and height lie in one of the zone's aim areas (dirt_aim_zones()). Null until SSdirt has
 * built that direction of the template in the background (/datum/controller/subsystem/dirt/proc/human_surface()). Each
 * zone is read once a round. You should NEVER modify the list it returns.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_human_zone_pixels(zone)
	RETURN_TYPE(/list)
	var/static/alist/found = alist()
	var/list/pixels = found[zone]
	if(pixels)
		return pixels
	var/datum/dirt_surface/surface = SSdirt.human_surface(dirt_zone_facing(zone))
	if(!surface)
		return null
	pixels = list()
	var/list/areas = dirt_aim_zones()[zone]
	var/list/flags_of = surface.flags_of
	for(var/index in 1 to length(flags_of))
		var/flags = flags_of[index]
		if(!DIRT_PIXEL_ZONE(flags))
			continue
		var/limb = DIRT_PIXEL_LIMB(flags)
		var/theta = surface.theta_of[index]
		var/along = surface.height_of[index]
		for(var/list/area as anything in areas)
			var/turn = theta - area[2]
			if(limb == area[1] && DIRT_MODULO(turn, 360) <= area[3] - area[2] && along >= area[4] && along <= area[5])
				pixels += index
				break
	found[zone] = pixels
	return pixels

/**
 * Returns the layer of the surface a shot at a zone would land on: the garment's over it, DIRT_UNDERCLOTHES_LAYER where
 * underclothes take it, else DIRT_SKIN_LAYER.
 *
 * Arguments:
 * - body: The body.
 * - zone: A DIRT_ZONE_* define.
 */
/proc/dirt_zone_layer(mob/living/carbon/human/body, zone)
	var/obj/item/garment = dirt_mess_garment(body, zone)
	if(garment)
		return dirt_slot_layer(body.get_slot_by_item(garment))
	if(length(dirt_underclothes_worn(body)) && dirt_underclothes_on(body, zone))
		return DIRT_UNDERCLOTHES_LAYER
	return DIRT_SKIN_LAYER

/**
 * Returns the layer a worn slot's garment draws at, which its mess lies on, against which parts draw over or under it.
 *
 * Arguments:
 * - slot: An ITEM_SLOT_* flag.
 */
/proc/dirt_slot_layer(slot)
	switch(slot)
		if(ITEM_SLOT_ICLOTHING)
			return UNIFORM_LAYER
		if(ITEM_SLOT_OCLOTHING)
			return SUIT_LAYER
		if(ITEM_SLOT_HEAD)
			return HEAD_LAYER
		if(ITEM_SLOT_MASK)
			return FACEMASK_LAYER
	return UNIFORM_LAYER

/**
 * What one surface's masks are made from and drawn with: a garment's cloth, one of a person's underclothes, or a part.
 * A request is made when the surface's splats or what it's drawn on change, never on a draw.
 */
/datum/dirt_drawing
	/// What the masks are made from now.
	var/datum/dirt_mask_request/request
	/// The request's mask_key().
	var/key
	/// The masks drawn: the request's once made, and until then the ones before them, if any.
	var/datum/dirt_masks/masks
	/// Whether the surface isn't drawn now (underclothes off or hidden), until the next forget(), so draws meanwhile
	/// don't look for it again.
	var/absent = FALSE
	/// What the request's parts were made from, as its owner writes it, where its owner checks it.
	var/parts_key

/**
 * Starts drawing from a new request. The masks before it are drawn until its own are made.
 *
 * Arguments:
 * - new_request: The request.
 * - parts_key: What its parts were made from, for its owner to check, or null.
 */
/datum/dirt_drawing/proc/start(datum/dirt_mask_request/new_request, parts_key)
	request = new_request
	key = request.mask_key()
	src.parts_key = parts_key

/**
 * Drops the request, so the next draw makes one.
 *
 * Arguments:
 * - drop_masks: Whether to stop drawing the masks made before, which no longer fit what's drawn.
 */
/datum/dirt_drawing/proc/forget(drop_masks)
	request = null
	key = null
	absent = FALSE
	parts_key = null
	if(drop_masks)
		masks = null

/**
 * Returns the masks to draw: the request's once made, else the ones before them, or null. Until they're made SSdirt
 * draws `body` again once they are, whoever queued them.
 *
 * Arguments:
 * - body: The body they're drawn on.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again on it.
 */
/datum/dirt_drawing/proc/current(mob/living/carbon/human/body, redraw_flags)
	RETURN_TYPE(/datum/dirt_masks)
	if(!request || masks?.key == key)
		return masks
	// read the cache rather than spend masks_for()'s two MD5s on every draw
	var/cached = SSdirt.masks.fetch(key)
	if(isnull(cached))
		var/datum/dirt_mask_job/waiting = SSdirt.mask_jobs[key]
		if(waiting)
			waiting.wait(body, redraw_flags)
		else
			cached = SSdirt.masks_for(request, body, redraw_flags)
	if(istype(cached, /datum/dirt_masks))
		masks = cached
	return masks

/**
 * Returns what to draw again on a body for an item in a slot: a DIRT_REDRAW_* flag, or NONE.
 *
 * Arguments:
 * - slot: An ITEM_SLOT_* flag.
 */
/proc/dirt_slot_redraw(slot)
	switch(slot)
		if(ITEM_SLOT_ICLOTHING)
			return DIRT_REDRAW_UNIFORM
		if(ITEM_SLOT_OCLOTHING)
			return DIRT_REDRAW_SUIT
		if(ITEM_SLOT_HEAD)
			return DIRT_REDRAW_HEAD
		if(ITEM_SLOT_MASK)
			return DIRT_REDRAW_MASK
	return NONE

#undef DIRT_COVERAGE_READS
