/// How many sprites' coverage of a zone dirt_sprite_zone_pixels() keeps. Each takes about 1.86 KB with its key
/// (measured), so about 0.9 MB in all.
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
 * Returns an image drawing cloth's baked dirt over a garment. BLEND_INSET_OVERLAY keeps it to what's drawn before it
 * inside the worn KEEP_TOGETHER wrapper that build_worn_icon() makes. That's the garment's own pixels, and every image
 * added to the wrapper earlier, such as a blood stain the dirt draws over. It floats, and on a garment drawn on the
 * body's own tile it isn't offset. So the bulge redraws it over its cloth too (bulge_over_cloth()).
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
	var/width = garment.worn_x_dimension
	var/height = garment.worn_y_dimension
	// center_image()'s offsets, worked out without an appearance to set them on
	var/centre_x = 0
	var/centre_y = 0
	if(width != ICON_SIZE_X || height != ICON_SIZE_Y)
		centre_x = -((width / ICON_SIZE_X) - 1) * (ICON_SIZE_X * 0.5)
		centre_y = -((height / ICON_SIZE_Y) - 1) * (ICON_SIZE_Y * 0.5)
		if(width < ICON_SIZE_X)
			centre_x *= -1
		if(height < ICON_SIZE_Y)
			centre_y *= -1
	var/list/offsets = garment.get_worn_offsets(FALSE)
	return list(-centre_x - offsets[1], -centre_y - offsets[2])

/obj/item
	/// Where this item's blood stain goes in its separate worn overlays, so that its dirt draws over it, or null. It's
	/// set while the item's worn sprite is built (/datum/component/dirtiness/proc/on_worn_overlays()), as list(the
	/// place of its first dirt image, the place of its sweat's multiplier or 0). Its build calls dirt_order_worn() only
	/// while this is set.
	var/dirt_stain_slot

/**
 * Returns where a worn sprite is read over its wearer's tile (dirt_worn_shift()). Returns null for a 32x32 sprite its
 * wrapper doesn't move, which is read on the tile, where it lies.
 *
 * Arguments:
 * - garment: The worn item.
 * - sprite_icon: Its sprite's icon, as drawn.
 */
/proc/dirt_worn_read_shift(obj/item/garment, sprite_icon)
	RETURN_TYPE(/list)
	var/list/shift = dirt_worn_shift(garment)
	if(shift[1] || shift[2])
		return shift
	var/list/size = get_icon_dimensions(sprite_icon)
	return (size["width"] != ICON_SIZE_X || size["height"] != ICON_SIZE_Y) ? shift : null

/**
 * Moves this item's blood stain to the place its dirt kept for it in its separate worn overlays (dirt_stain_slot), so
 * that its dirt draws over the stain. It also lets go of that place. Its sweat's multiplier goes just under the stain,
 * as sweat never draws over it. The stain is the last image after that place whose state names blood, as every
 * get_blood_overlay() names it, whatever sheet it's drawn from. Without a stain, nothing moves.
 *
 * Arguments:
 * - separate: separate_worn_overlays()'s list, as build_worn_icon() adds it to the worn wrapper. It's changed in place.
 */
/obj/item/proc/dirt_order_worn(list/separate)
	var/list/places = dirt_stain_slot
	dirt_stain_slot = null
	var/slot = places[1]
	for(var/index in length(separate) to slot + 1 step -1)
		var/mutable_appearance/stain = separate[index]
		if(findtextEx(stain.icon_state, "blood"))
			separate.Cut(index, index + 1)
			separate.Insert(slot, stain)
			var/wet_place = places[2]
			if(wet_place)
				// one place on, as the stain now goes before it
				var/mutable_appearance/wet = separate[wet_place + 1]
				separate.Cut(wet_place + 1, wet_place + 2)
				separate.Insert(slot, wet)
			return

/**
 * Returns whether a garment is drawn on its wearer's taur body as a taur suit, as its slot draws it now
 * (dirt_taur_suit_sprite()). A taur suit takes the taur body's dirt.
 *
 * Arguments:
 * - garment: The worn item.
 * - wearer: Who wears it.
 */
/proc/dirt_taur_fitted(obj/item/garment, mob/living/carbon/human/wearer)
	var/image/sprite = bulge_drawn_leaf(bulge_drawn_root(wearer.overlays_standing[dirt_slot_layer(wearer.get_slot_by_item(garment))]))
	return dirt_taur_suit_sprite(sprite?.icon, wearer)

/**
 * Returns whether a worn sprite draws a taur suit. It does if its wearer has a taur body and the sprite spans the 64x32
 * taur canvas, with the body's own tile in its middle. A 64x64 hat or back item doesn't.
 *
 * Arguments:
 * - sprite_icon: The sprite's icon, or null.
 * - wearer: Who wears it.
 */
/proc/dirt_taur_suit_sprite(sprite_icon, mob/living/carbon/human/wearer)
	if(!sprite_icon || !istype(wearer.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), /obj/item/organ/taur_body))
		return FALSE
	var/list/size = get_icon_dimensions(sprite_icon)
	return size["width"] == DIRT_TAUR_WIDTH && size["height"] == ICON_SIZE_Y

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
 * dirt_cover_layers() order. A garment's sprite its wrapper moves off the tile, or one that isn't 32x32, adds where
 * the wrapper has the body's tile (dirt_worn_read_shift()). So a taur suit, a 64x64 hat or a hat drawn higher covers
 * where it lies. dirt_shown_carriers() reads worn sprites the same way.
 *
 * Arguments:
 * - body: The body.
 * - layers: The overlays_standing slots to read, or null for every one of dirt_cover_layers().
 */
/proc/dirt_cover_sprites(mob/living/carbon/human/body, list/layers = null)
	RETURN_TYPE(/list)
	. = list()
	for(var/layer in layers || dirt_cover_layers())
		var/standing = body.overlays_standing[layer]
		if(!standing)
			continue
		var/obj/item/worn
		for(var/slot in dirt_carrier_slots())
			worn = dirt_slot_layer(slot) == layer && body.get_item_by_slot(slot)
			if(worn)
				break
		for(var/image/root as anything in (islist(standing) ? standing : list(standing)))
			if(root.plane != FLOAT_PLANE)
				continue
			var/image/leaf = bulge_drawn_leaf(root)
			if(!leaf)
				continue
			var/list/sprite = list(leaf.icon, leaf.icon_state)
			var/list/shift = worn && dirt_worn_read_shift(worn, leaf.icon)
			if(shift)
				sprite += list(shift)
			. += list(sprite)

/**
 * Returns sprites as one line of text, to key masks by and to tell outfits apart.
 *
 * Arguments:
 * - sprites: list(list(icon, icon state), ...), or null. A sprite may add where its wrapper has the body's tile, as
 *   dirt_cover_sprites() gives it.
 */
/proc/dirt_sprites_key(list/sprites)
	var/list/parts = list()
	for(var/list/sprite as anything in sprites)
		var/list/shift = length(sprite) > 2 ? sprite[3] : null
		parts += "[dirt_sprite_key(sprite[1])]:[sprite[2]][shift ? "@[shift[1]],[shift[2]]" : ""]"
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
	var/list/drawn = list()
	var/obj/item/organ/genital/penis/penis = body.organs_slot[ORGAN_SLOT_PENIS]
	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis?.bodypart_overlay
	for(var/piece in drawn_order)
		var/datum/sprite_accessory/clothing/accessory = worn[piece]
		var/mutable_appearance/sprite = accessory?.make_appearance(dirt_underclothes_colour(body, piece), body_type, body.bodyshape, body)
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
 * Returns the colour a body's preferences give a piece of underclothes, as get_underwear_overlays() passes it to
 * make_appearance(), which draws a static accessory without it. dirt_underclothes_sprites() draws the piece in this
 * colour, and sweat's multiplier reads the piece in it too.
 *
 * Arguments:
 * - body: The body.
 * - piece: A DIRT_UNDERCLOTHES_* define.
 */
/proc/dirt_underclothes_colour(mob/living/carbon/human/body, piece)
	switch(piece)
		if(DIRT_UNDERCLOTHES_UNDERWEAR)
			return body.underwear_color
		if(DIRT_UNDERCLOTHES_BRA)
			return body.bra_color
		if(DIRT_UNDERCLOTHES_UNDERSHIRT)
			return body.undershirt_color
		if(DIRT_UNDERCLOTHES_SOCKS)
			return body.socks_color
	return null

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
 * Returns the piece of underclothes an underclothes key (dirt_underclothes_key()) names, as its
 * DIRT_UNDERCLOTHES_* define.
 *
 * Arguments:
 * - key: The key.
 */
/proc/dirt_underclothes_piece(key)
	return copytext(key, 1, findtextEx(key, "|"))

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
 * Returns which of a zone's pixels a sprite covers, read at those pixels only, facing the way given or else the way
 * that shows the zone. It keeps a result for each sprite, zone, direction and placement, and drops the oldest past
 * DIRT_COVERAGE_READS. A sprite given a shift is read where the shift puts it over the body's tile, whatever its size.
 * One given none covers nothing unless it's 32x32. You should NEVER modify the list it returns.
 *
 * Arguments:
 * - sheet: The sprite's icon file, or an icon made at run time.
 * - state: Its icon state.
 * - zone: A DIRT_ZONE_* define, or a name for other pixels read: "body" for dirt_human_body_pixels(), "tile" for every
 *   pixel of the tile.
 * - zone_pixels: The zone's pixels, from dirt_human_zone_pixels().
 * - direction: The direction it's drawn facing, or null for the zone's (dirt_zone_facing()). A state with one direction
 *   is read facing south.
 * - shift: Where a worn garment's wrapper has the body's tile, from dirt_worn_shift() (dirt_worn_read_shift()), or
 *   null for a sprite read on it.
 */
/proc/dirt_sprite_zone_pixels(sheet, state, zone, list/zone_pixels, direction = null, list/shift = null)
	RETURN_TYPE(/list)
	var/static/datum/bulge_bounded_cache/reads
	if(!reads)
		reads = new
		reads.limit = DIRT_COVERAGE_READS
	var/key = "[dirt_sprite_key(sheet)]|[state]|[zone][direction ? "|[direction]" : ""][shift ? "|[shift[1]],[shift[2]]" : ""]"
	var/list/covered = reads.fetch(key)
	if(covered)
		return covered
	covered = list()
	var/icon/sprite = icon(sheet, state)
	var/width = sprite.Width()
	var/height = sprite.Height()
	if(shift || (width == ICON_SIZE_X && height == ICON_SIZE_Y))
		var/shift_x = shift?[1] || 0
		var/shift_y = shift?[2] || 0
		direction ||= dirt_zone_facing(zone)
		direction = dirt_sprite_read_facing(sheet, state, direction, sprite)
		for(var/index in zone_pixels)
			var/row = floor((index - 1) / ICON_SIZE_X)
			var/sprite_x = index - row * ICON_SIZE_X + shift_x
			var/sprite_y = ICON_SIZE_Y - row + shift_y
			if(sprite_x >= 1 && sprite_y >= 1 && sprite_x <= width && sprite_y <= height && sprite.GetPixel(sprite_x, sprite_y, null, direction))
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
 * Returns the plain human template's body pixels in one direction, as indexes in row-major order. It returns every
 * one, or only those one zone's image shows (dirt_pixel_zones()). Returns null until SSdirt has built that direction
 * (/datum/controller/subsystem/dirt/proc/human_surface()). Each list is read once a round. You should NEVER modify the
 * list it returns.
 *
 * Arguments:
 * - direction: The direction.
 * - zone: A body zone, or null for the whole body.
 */
/proc/dirt_human_body_pixels(direction, zone = null)
	RETURN_TYPE(/list)
	var/static/alist/found = alist()
	var/key = "[direction]|[zone]"
	var/list/pixels = found[key]
	if(pixels)
		return pixels
	var/datum/dirt_surface/surface = SSdirt.human_surface(direction)
	if(!surface)
		return null
	var/place = zone && dirt_pixel_zones()[zone]
	pixels = list()
	var/list/flags_of = surface.flags_of
	for(var/index in 1 to length(flags_of))
		var/pixel_place = DIRT_PIXEL_ZONE(flags_of[index])
		if(pixel_place && (!place || pixel_place == place))
			pixels += index
	found[key] = pixels
	return pixels

/**
 * Returns the slots whose worn items take general dirt (dirt_shown_carriers()). You should NEVER modify it.
 */
/proc/dirt_carrier_slots()
	RETURN_TYPE(/list)
	var/static/list/slots = list(ITEM_SLOT_ICLOTHING, ITEM_SLOT_OCLOTHING, ITEM_SLOT_FEET, ITEM_SLOT_GLOVES, ITEM_SLOT_HEAD, ITEM_SLOT_MASK, ITEM_SLOT_NECK, ITEM_SLOT_BELT, ITEM_SLOT_BACK, ITEM_SLOT_EYES, ITEM_SLOT_EARS)
	return slots

/**
 * Returns what shows on each limb of a person, as general dirt lands on it: alist(carrier = the limbs it shows on,
 * DIRT_LIMB_BIT() of each). Each carrier is a worn item (dirt_carrier_slots()), an underclothes key
 * (dirt_underclothes_key()) or DIRT_CARRIER_SKIN. Each is judged as dirt_underclothes_on() judges a piece, on the plain
 * human template's body facing south and north. Every carrier that shows counts, not only the one that shows most. A
 * carrier shows on a limb where its sprite covers that limb's pixels and nothing drawn over it does.
 * - Worn items are read as drawn (bulge_drawn_leaf()), in the order of the layers they're drawn at. They're read where
 *   their wrappers put them over the body's tile (dirt_worn_shift()), so a 64x64 hat or a large back item shows too.
 *   A taur suit shows there as any garment does, with its upper part over the rider. Its hem band also takes the taur
 *   body's general dirt (dirt_taur_suit()).
 * - The hands, drawn over the uniform (BODYPARTS_HIGH_LAYER), count as skin at that layer.
 * - The underclothes go under every worn item. The skin takes what's left, under everything.
 * Drawn parts and a taur body take their dirt by their own rules (dirt_shape_slots()).
 * The template is built now if SSdirt hasn't built it yet.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_shown_carriers(mob/living/carbon/human/target)
	RETURN_TYPE(/alist)
	. = alist()
	if(!SSdirt.human_template_now())
		return
	// topmost first: list(carrier, icon, icon state, the layer it's drawn at, where a worn item's wrapper puts it)
	// the hands' entry has no icon
	var/list/stack = list(list(DIRT_CARRIER_SKIN, null, null, -BODYPARTS_HIGH_LAYER, null))
	for(var/slot in dirt_carrier_slots())
		var/obj/item/worn = target.get_item_by_slot(slot)
		var/image/root = worn && bulge_drawn_root(target.overlays_standing[dirt_slot_layer(slot)])
		var/image/leaf = bulge_drawn_leaf(root)
		if(leaf)
			stack += list(list(worn, leaf.icon, leaf.icon_state, root.layer, dirt_worn_read_shift(worn, leaf.icon)))
	sortTim(stack, GLOBAL_PROC_REF(cmp_dirt_drawn_topmost))
	var/list/underclothes = dirt_underclothes_sprites(target)
	for(var/index in length(underclothes) to 1 step -1)
		var/list/entry = underclothes[index]
		stack += list(list(dirt_underclothes_key(entry[1], entry[4]), entry[2], entry[3], null, null))
	for(var/direction in list(SOUTH, NORTH))
		var/datum/dirt_surface/surface = SSdirt.human_surface(direction)
		var/list/flags_of = surface.flags_of
		var/list/body_pixels = dirt_human_body_pixels(direction)
		var/list/covered = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		for(var/list/entry as anything in stack)
			var/list/pixels = entry[2] ? dirt_sprite_zone_pixels(entry[2], entry[3], "body", body_pixels, direction, entry[5]) : (dirt_human_body_pixels(direction, BODY_ZONE_PRECISE_L_HAND) + dirt_human_body_pixels(direction, BODY_ZONE_PRECISE_R_HAND))
			var/shown = NONE
			for(var/pixel in pixels)
				if(!covered[pixel])
					covered[pixel] = TRUE
					shown |= DIRT_LIMB_BIT(DIRT_PIXEL_LIMB(flags_of[pixel]))
			if(shown)
				.[entry[1]] |= shown
		var/skin = NONE
		for(var/pixel in body_pixels)
			if(!covered[pixel])
				skin |= DIRT_LIMB_BIT(DIRT_PIXEL_LIMB(flags_of[pixel]))
		if(skin)
			.[DIRT_CARRIER_SKIN] |= skin

/// Sorts what a body draws from dirt_shown_carriers() topmost first. The lower layer number draws over, so it's first.
/proc/cmp_dirt_drawn_topmost(list/first, list/second)
	return second[4] - first[4]

/**
 * Returns whether a body is bare, so its skin and underwear take the painted designs where a cause has one. A body is
 * bare when more than DIRT_BARE_SHARE of the chest's pixels on the plain human template, facing south, show skin past
 * its garments (dirt_cover_layers()) and its undershirt, bra and socks. Underwear takes the skin's dirt, so it covers
 * nothing here. This judges by what the skin's masks fade beside (dirt_cover_sprites()), so a change to those sprites
 * has the masks made again (/datum/component/dirtiness/proc/check_cover()). Returns FALSE until SSdirt has built the
 * template, and while the body is hidden (dirt_body_hidden()).
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_bare_bodied(mob/living/carbon/human/body)
	var/list/chest = dirt_human_body_pixels(SOUTH, BODY_ZONE_CHEST)
	if(!length(chest) || dirt_body_hidden(body))
		return FALSE
	var/list/sprites = dirt_cover_sprites(body, dirt_cover_layers() - BODY_LAYER)
	for(var/list/entry as anything in dirt_underclothes_sprites(body))
		if(entry[1] != DIRT_UNDERCLOTHES_UNDERWEAR)
			sprites += list(list(entry[2], entry[3]))
	var/list/body_pixels = dirt_human_body_pixels(SOUTH)
	var/list/covered = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/list/sprite as anything in sprites)
		for(var/pixel in dirt_sprite_zone_pixels(sprite[1], sprite[2], "body", body_pixels, SOUTH, length(sprite) > 2 ? sprite[3] : null))
			covered[pixel] = TRUE
	var/bare = 0
	for(var/pixel in chest)
		if(!covered[pixel])
			bare++
	return bare > DIRT_BARE_SHARE * length(chest)

/**
 * Returns whether a body is hidden under a worn sprite larger than its tile, as a sleeping bag is. It is when its
 * uniform's or suit's sprite as drawn isn't 32x32 and isn't a taur suit (dirt_taur_suit_sprite()). Its skin then draws
 * no dirt, and keeps it. Putting such a sprite on or off changes what the skin fades beside, so check_cover() redraws
 * the body.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_body_hidden(mob/living/carbon/human/body)
	for(var/layer in list(UNIFORM_LAYER, SUIT_LAYER))
		var/image/leaf = bulge_drawn_leaf(bulge_drawn_root(body.overlays_standing[layer]))
		if(!leaf)
			continue
		var/list/size = get_icon_dimensions(leaf.icon)
		if((size["width"] != ICON_SIZE_X || size["height"] != ICON_SIZE_Y) && !dirt_taur_suit_sprite(leaf.icon, body))
			return TRUE
	return FALSE

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
	if(dirt_underclothes_on(body, zone))
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
		if(ITEM_SLOT_FEET)
			return SHOES_LAYER
		if(ITEM_SLOT_GLOVES)
			return GLOVES_LAYER
		if(ITEM_SLOT_NECK)
			return NECK_LAYER
		if(ITEM_SLOT_BELT)
			return BELT_LAYER
		if(ITEM_SLOT_BACK)
			return BACK_LAYER
		if(ITEM_SLOT_EYES)
			return GLASSES_LAYER
		if(ITEM_SLOT_EARS)
			return EARS_LAYER
		if(ITEM_SLOT_SUITSTORE)
			return SUIT_STORE_LAYER
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
	/// Whether the surface isn't drawn now (underclothes off or hidden, or a taur suit's upper part with nothing to
	/// draw). It stays set until the next forget() or start(), so draws meanwhile don't look for it again.
	var/absent = FALSE
	/// What the request's parts were made from, as its owner writes it, where its owner checks it.
	var/parts_key
	/// The icon of sweat's multiplier drawn with the masks (current_wet()), or null for none. It's held while a new one
	/// is made, and after SSdirt.wet_icons drops it.
	var/wet
	/// The key of the multiplier held (dirt_wet_key()), or of the one asked for if it couldn't be made, else null.
	var/wet_key

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
	absent = FALSE

/**
 * Drops the request, so the next draw makes one. Its job is dropped once the next request has another key (current()).
 *
 * Arguments:
 * - drop_masks: Whether to stop drawing the masks made before, which no longer fit what's drawn, and their sweat's
 *   multiplier.
 */
/datum/dirt_drawing/proc/forget(drop_masks)
	superseded_key ||= key
	request = null
	key = null
	absent = FALSE
	parts_key = null
	if(drop_masks)
		masks = null
		wet = null
		wet_key = null

/**
 * Drops the queued jobs of the masks this drawing asked for, as it's let go, while no other body waits for them
 * (/datum/controller/subsystem/dirt/proc/drop_mask_job()). Those are the jobs of its request, of the request a newer
 * one replaced (superseded_key), and of the sweat multiplier it last asked for (wet_read).
 *
 * Arguments:
 * - body: The body that waits for them.
 */
/datum/dirt_drawing/proc/drop_jobs(mob/living/carbon/human/body)
	SSdirt.drop_mask_job(key, body)
	SSdirt.drop_mask_job(superseded_key, body)
	// a multiplier made already has no job
	SSdirt.drop_mask_job(wet_read?[1], body)
	superseded_key = null

/**
 * Returns the masks to draw: the request's once made, else the ones before them, or null. If they aren't made yet,
 * SSdirt draws `body` again once they are, whoever queued them. A skin's job that this queues holds the masks drawn
 * now, so each limb whose runs are unchanged keeps its icon (/datum/dirt_mask_job/proc/limb_masks()).
 *
 * Arguments:
 * - body: The body they're drawn on.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again on it.
 */
/datum/dirt_drawing/proc/current(mob/living/carbon/human/body, redraw_flags)
	RETURN_TYPE(/datum/dirt_masks)
	if(superseded_key && request)
		if(superseded_key != key)
			SSdirt.drop_mask_job(superseded_key, body, redraw_flags)
		superseded_key = null
	if(!request || masks?.key == key)
		return masks
	masks = SSdirt.masks_for(request, body, redraw_flags, masks, key) || masks
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
		if(ITEM_SLOT_FEET)
			return DIRT_REDRAW_SHOES
		if(ITEM_SLOT_GLOVES)
			return DIRT_REDRAW_GLOVES
		if(ITEM_SLOT_NECK)
			return DIRT_REDRAW_NECK
		if(ITEM_SLOT_BELT)
			return DIRT_REDRAW_BELT
		if(ITEM_SLOT_BACK)
			return DIRT_REDRAW_BACK
		if(ITEM_SLOT_EYES)
			return DIRT_REDRAW_GLASSES
		if(ITEM_SLOT_EARS)
			return DIRT_REDRAW_EARS
		if(ITEM_SLOT_SUITSTORE)
			return DIRT_REDRAW_SUIT_STORE
	return NONE

#undef DIRT_COVERAGE_READS
