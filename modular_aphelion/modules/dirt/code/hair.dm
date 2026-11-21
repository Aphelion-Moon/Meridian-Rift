// The hairstyle as a carrier of general dirt. The person holds its splats under DIRT_CARRIER_HAIR, with their drawn
// parts' (/datum/component/dirtiness/var/part_splats). While the hair shows, it takes what reaches it
// (dirt_hair_levels()). Its dirt is drawn in one container over the hair
// (/obj/item/bodypart/head/proc/dirt_hair_overlay()), and in one more over its pieces drawn over hats, where it has
// them. Its masks lie on the hair's own pixels, less its darkest strands. Those pixels are read from the icon the head
// draws and those pieces together (dirt_hair_source()). The masks are merged, despeckled and given a glint where a
// material with a sheen lies (dirt_hair_dirt()).

/**
 * Returns the causes that reach the hair, each with the first level at which it reaches it, as the reference
 * generator's HAIR_CAUSES. Full coverage reaches it from level 2. A douse and slime on the head reach it from level 1,
 * and smoke and slime lain in with the back from level 3. A deposit of another cause, or under its level, draws nothing
 * on the hair. You should NEVER modify it.
 */
/proc/dirt_hair_levels()
	RETURN_TYPE(/alist)
	var/static/alist/levels = alist(
		DIRT_CAUSE_PLUNGE = 2,
		DIRT_CAUSE_BLAST = 2,
		DIRT_CAUSE_SMOKE = 3,
		DIRT_CAUSE_DOUSE = 1,
		DIRT_CAUSE_SLIMED = 2,
		DIRT_CAUSE_SLIMED_HEAD = 1,
		DIRT_CAUSE_SLIMED_BACK = 3,
	)
	return levels

/**
 * Returns whether a person's hair takes a general cause's dirt in a material. It takes a cause that reaches the hair at
 * some level (dirt_hair_levels()) while the hair shows (dirt_hair_source()). It never takes dirt in a material that
 * wets cloth. A deposit under the cause's first hair level is taken all the same and draws nothing. Once another raises
 * it, it draws as the body's does.
 *
 * Arguments:
 * - target: The person.
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 */
/proc/dirt_hair_takes(mob/living/carbon/human/target, cause, datum/dirt_material/material)
	if((material.flags & DIRT_MATERIAL_WET) || !dirt_hair_levels()[cause])
		return FALSE
	var/obj/item/bodypart/head/head = target.get_bodypart(BODY_ZONE_HEAD)
	return istype(head) && !!head.dirt_hair_source()

/**
 * Returns the hair as dirt reads it while the head draws it, as get_hair_overlays() does. One layer is the icon its
 * hairstyle draws from (getCachedIcon()), on the canvas it fits. That icon has the hairstyle's inner appendages blended
 * in, and the hair masks of what's worn cut out. Another layer over it holds its pieces drawn over hats that show
 * (dirt_hair_outer_states()), from the hairstyle's sheet. Returns null while the hair isn't drawn (hidden by what's
 * worn, husked, a head without hair, debrained, bald) or sits on no canvas. A source is made once for each such icon
 * and the pieces shown, and kept, as the hairstyles keep those icons.
 */
/obj/item/bodypart/head/proc/dirt_hair_source()
	RETURN_TYPE(/datum/dirt_shape_source)
	// the hairstyles' icon and the pieces shown over hats -> its source, or FALSE on no canvas
	var/static/alist/sources = alist()
	if(is_invisible || is_husked || !(head_flags & HEAD_HAIR) || (owner?.obscured_slots & HIDEHAIR))
		return null
	var/obj/item/organ/brain/brain = locate() in src
	if(QDELETED(brain) && (head_flags & HEAD_DEBRAIN))
		return null
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[hairstyle]
	if(!style?.icon_state || style.icon_state == SPRITE_ACCESSORY_NONE)
		return null
	var/icon/sheet = style.getCachedIcon(owner?.hair_masks)
	var/list/outer_states = dirt_hair_outer_states(style, owner?.hair_masks)
	var/sheet_key = outer_states ? "[dirt_sprite_key(sheet)]|[jointext(outer_states, ",")]" : dirt_sprite_key(sheet)
	var/datum/dirt_shape_source/source = sources[sheet_key]
	if(!isnull(source))
		return source || null
	var/canvas = dirt_canvas_of(sheet, 0, 0)
	if(!canvas)
		source = FALSE
	else if(outer_states)
		// the pieces draw over the hair, so a pixel both draw belongs to the piece
		source = new /datum/dirt_shape_source(sheet, alist(DIRT_CARRIER_HAIR = list(null), DIRT_HAIR_OUTER = outer_states), list(DIRT_CARRIER_HAIR, DIRT_HAIR_OUTER), canvas, DIRT_SHAPE_HAIR)
		source.layer_sheets = alist(DIRT_HAIR_OUTER = style.icon)
	else
		// the icon's one state is read as null, whatever it's named
		source = new /datum/dirt_shape_source(sheet, alist(DIRT_CARRIER_HAIR = list(null)), list(DIRT_CARRIER_HAIR), canvas, DIRT_SHAPE_HAIR)
	sources[sheet_key] = source
	return source || null

/**
 * Returns the states of a hairstyle's pieces drawn over hats that show, in its order, as get_base_hair_overlays() draws
 * them. A piece doesn't show in a zone that a hair mask of what's worn strictly covers. Null for none.
 *
 * Arguments:
 * - style: The hairstyle.
 * - hair_masks: The hair masks of what's worn, or null.
 */
/proc/dirt_hair_outer_states(datum/sprite_accessory/hair/style, list/hair_masks)
	RETURN_TYPE(/list)
	if(!LAZYLEN(style.hair_appendages_outer))
		return null
	var/strictly_masked_zones = NONE
	for(var/datum/hair_mask/mask as anything in hair_masks)
		strictly_masked_zones |= mask.strict_coverage_zones
	for(var/appendage_state, appendage_zone in style.hair_appendages_outer)
		if(!(appendage_zone & strictly_masked_zones))
			LAZYADD(., appendage_state)

/**
 * Adds the key of the hair's dirt's masks after DIRT_PRIVATE_KEY, or "pending" while they're made, while the hair shows
 * and holds some dirt. The hair is drawn again with the head (update_body_parts()), so the masks draw once they're
 * made. Asking queues masks not made yet.
 */
/obj/item/bodypart/head/generate_icon_key()
	. = ..()
	var/mob/living/carbon/human/body = owner
	if(!istype(body))
		return
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	if(!length(carrier?.part_splats?[DIRT_CARRIER_HAIR]))
		return
	var/datum/dirt_shape_source/source = dirt_hair_source()
	if(!source)
		return
	var/datum/dirt_masks/masks = carrier.ready_shape_masks(DIRT_CARRIER_HAIR, source)
	. += "[DIRT_PRIVATE_KEY]hair dirt=[masks ? masks.key : "pending"]"

/// Draws the hair's dirt over it (/obj/item/bodypart/head/proc/dirt_hair_overlay()) on its owner.
/obj/item/bodypart/head/get_hair_overlays(dropped)
	. = ..()
	if(!dropped)
		dirt_hair_overlay(.)

/**
 * Adds the hair's dirt to the hair's images while the hair shows. One container at the hair's layer, offsets and alpha,
 * as get_base_hair_overlays() draws the hair, holds its baked image, kept to the hair's own pixels. It's drawn after
 * the hair, its gradient and paint. Where its pieces drawn over hats show, one more container holds the dirt on their
 * pixels, at their layer and drawn after them. Each container's emissive blocker comes just after it
 * (dirt_emissive_blocker()). The blocker takes the container's alpha, as tg's hair blocker takes the hair's. This proc
 * asks for the masks as the head's render key does (generate_icon_key()).
 *
 * Arguments:
 * - images: The hair's images, as get_hair_overlays() returns them, added to.
 */
/obj/item/bodypart/head/proc/dirt_hair_overlay(list/images)
	var/mob/living/carbon/human/body = owner
	if(!istype(body))
		return
	var/datum/component/dirtiness/carrier = body.GetComponent(/datum/component/dirtiness)
	if(!length(carrier?.part_splats?[DIRT_CARRIER_HAIR]))
		return
	var/datum/dirt_shape_source/source = dirt_hair_source()
	var/datum/dirt_masks/masks = source && carrier.ready_shape_masks(DIRT_CARRIER_HAIR, source)
	if(!masks)
		return
	var/datum/sprite_accessory/hair/style = SSaccessories.hairstyles_list[hairstyle]
	var/hair_baked = masks.baked || masks.baked_by_layer[DIRT_CARRIER_HAIR]
	if(hair_baked)
		var/mutable_appearance/container = dirt_hair_container(hair_baked, -HAIR_LAYER, style, body)
		images += container
		images += dirt_emissive_blocker(hair_baked, body, container)
	var/outer_baked = masks.baked_by_layer[DIRT_HAIR_OUTER]
	if(outer_baked)
		var/mutable_appearance/outer_container = dirt_hair_container(outer_baked, -OUTER_HAIR_LAYER, style, body)
		images += outer_container
		images += dirt_emissive_blocker(outer_baked, body, outer_container)

/**
 * Returns a container of the hair's dirt at one of its layers, at its offsets and alpha, as get_base_hair_overlays()
 * draws the hair.
 *
 * Arguments:
 * - baked: The baked image it holds.
 * - drawn_layer: Its layer: -HAIR_LAYER, or -OUTER_HAIR_LAYER for the pieces drawn over hats.
 * - style: The hairstyle.
 * - body: The head's owner.
 */
/obj/item/bodypart/head/proc/dirt_hair_container(baked, drawn_layer, datum/sprite_accessory/hair/style, mob/living/carbon/human/body)
	RETURN_TYPE(/mutable_appearance)
	var/mutable_appearance/container = mutable_appearance(layer = drawn_layer, appearance_flags = KEEP_TOGETHER, alpha = hair_alpha)
	container.overlays += dirt_mess_baked_image(baked)
	container.pixel_z = style.y_offset
	if(LAZYFIND(body.dna?.species?.offset_features, OFFSET_HAIR))
		container.pixel_x += body.dna.species.offset_features[OFFSET_HAIR][INDEX_W]
		container.pixel_z += body.dna.species.offset_features[OFFSET_HAIR][INDEX_Z]
	worn_face_offset?.apply_offset(container)
	return container

/**
 * Merges one direction of the hair's deposits into its dirt (dirt_hair_dirt()). It reads the rasters of the deposits
 * that reach the hair at their level (rasterise_shape_deposit()), in the request's order. It merges them on the hair
 * and its pieces drawn over hats together (dirt_hair_layers_brightness()).
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/hair_merge(direction)
	var/datum/dirt_shape_source/shape = request.shape_source
	var/list/size = dirt_canvases()[shape.canvas]
	var/list/pixel_maps = list()
	var/list/materials = list()
	for(var/position in 1 to length(splat_rasters))
		var/alist/rasters = splat_rasters[position]
		if(!rasters?[direction])
			continue
		pixel_maps += dirt_pixels_from_drawn(rasters[direction], size[1], size[2])
		materials += splat_materials[position]
	var/alist/brightness = dirt_hair_layers_brightness(shape.icon, shape.layer_states[DIRT_CARRIER_HAIR][1], shape.sheet_of(DIRT_HAIR_OUTER), shape.layer_states[DIRT_HAIR_OUTER], direction, size[1], size[2])
	merged[direction] = dirt_hair_dirt(brightness, pixel_maps, materials, size[1], size[2])

/**
 * Returns the hair's dirt in one direction, as the reference generator draws it on a hairstyle. The deposits that reach
 * the hair are merged (dirt_merge()) on its pixels less its darkest quarter (dirt_hair_kept()), so dirty hair keeps its
 * strands. They're then despeckled on those pixels (dirt_despeckle()). A pixel the despeckle adds takes the material of
 * the first deposit with a pixel on them. The body or core of a material with a sheen (DIRT_MATERIAL_SHEEN) on the
 * hair's top three rows glints at the brightest of them. On a tie, the first in row-major order glints. Every pixel
 * names its material.
 *
 * Arguments:
 * - brightness: The hair's pixels in that direction, from dirt_hair_layers_brightness().
 * - pixel_maps: Each deposit's raster on the hair, dirt_shape_rasterise() as hair, in deposit order: those that reach
 *   it at their level alone. Each its own copy.
 * - materials: Their materials, as a splat stores them, in the same order.
 * - width, height: The canvas's size.
 */
/proc/dirt_hair_dirt(alist/brightness, list/pixel_maps, list/materials, width, height)
	RETURN_TYPE(/datum/dirt_pixels)
	if(!length(pixel_maps))
		return new /datum/dirt_pixels(width, height)
	var/alist/kept = dirt_hair_kept(brightness)
	var/datum/dirt_pixels/merged = dirt_clip_to_shape(dirt_merge(pixel_maps, materials), kept)
	var/fallback
	for(var/position in 1 to length(pixel_maps))
		var/datum/dirt_pixels/pixel_map = pixel_maps[position]
		for(var/index in kept)
			if(pixel_map.roles[index])
				fallback = materials[position]
				break
		if(fallback)
			break
	var/datum/dirt_pixels/softened = dirt_despeckle(merged, new /datum/dirt_hair_view(kept, width, height))
	var/list/roles = merged.roles
	var/list/merged_materials = merged.materials
	var/list/softened_materials = softened.materials
	var/top_row
	var/glint_at
	var/brightest = -1
	// kept is in row-major order, so its first row is the hair's top one
	for(var/index in kept)
		if(softened.roles[index] && !roles[index])
			softened_materials[index] = fallback
		var/row = floor((index - 1) / width)
		top_row = isnull(top_row) ? row : top_row
		var/role = roles[index]
		if(row > top_row + 2 || (role != DIRT_ROLE_BODY && role != DIRT_ROLE_CORE) || brightness[index] <= brightest)
			continue
		if(dirt_material(merged_materials[index]).flags & DIRT_MATERIAL_SHEEN)
			brightest = brightness[index]
			glint_at = index
	if(glint_at)
		softened.put_index(glint_at, DIRT_ROLE_GLINT, 0.5)
		softened_materials[glint_at] = merged_materials[glint_at]
	return softened

/**
 * Returns the hair's pixels less its darkest quarter, which stay clean so dirty hair keeps its strands, as
 * alist(index = TRUE) in row-major order: the quarter, rounded down, ranked by brightness, a tie to the first in
 * row-major order.
 *
 * Arguments:
 * - brightness: The hair's pixels, from dirt_hair_layers_brightness().
 */
/proc/dirt_hair_kept(alist/brightness)
	RETURN_TYPE(/alist)
	// brightness * 4096 + index is exact in a float, as brightness reaches 765 and an index 1536 on the tallest canvas
	var/list/ranked = list()
	for(var/index, value in brightness)
		ranked += value * 4096 + index
	sortTim(ranked, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/alist/strands = alist()
	for(var/position in 1 to floor(length(ranked) / 4))
		strands[ranked[position] % 4096] = TRUE
	var/alist/kept = alist()
	for(var/index in brightness)
		if(!strands[index])
			kept[index] = TRUE
	return kept

/**
 * Returns a hairstyle's own pixels in one direction, uncoloured, with any opacity counting. Each pixel has its
 * brightness, its red, green and blue added together. The result is alist(index = brightness) in row-major order on a
 * canvas `width` across and `height` tall. It holds none for a sprite of another size. The hair's colour is never read,
 * so no colour changes which strands are darkest or where the glint goes. It's kept with the sprites dirt reads
 * (SSdirt.sprite_reads). You should NEVER modify it.
 *
 * Arguments:
 * - sheet: The hairstyle's icon file, or the icon it draws from (getCachedIcon()).
 * - state: Its icon state, or null for the icon it draws from, of one state.
 * - direction: The direction.
 * - width, height: The canvas's size.
 */
/proc/dirt_hair_brightness(sheet, state, direction, width, height)
	RETURN_TYPE(/alist)
	var/key = "[dirt_sprite_read_key(sheet, state, direction, width, height)]|brightness"
	var/alist/brightness = SSdirt.sprite_reads.fetch(key)
	if(brightness)
		return brightness
	brightness = alist()
	var/icon/sprite = icon(sheet, state)
	if(sprite.Width() == width && sprite.Height() == height)
		for(var/row in 0 to height - 1)
			for(var/column in 0 to width - 1)
				var/pixel = sprite.GetPixel(column + 1, height - row, null, direction)
				if(!pixel)
					continue
				var/list/channels = rgb2num(pixel)
				brightness[row * width + column + 1] = channels[1] + channels[2] + channels[3]
	return SSdirt.sprite_reads.store_value(key, brightness)

/**
 * Returns the pixels of a hairstyle and its pieces drawn over hats in one direction, each with its brightness, as
 * dirt_hair_brightness() reads one sprite's: alist(index = brightness) in row-major order. Where a piece draws, the
 * pixel is the piece's, and the last piece listed is over the others, as they're drawn over the hair. With no pieces,
 * it's the hair's own alone.
 *
 * Arguments:
 * - sheet, state: The hairstyle's, as dirt_hair_brightness() takes them.
 * - outer_sheet: The sheet its pieces are drawn from.
 * - outer_states: Their states, in the order they're drawn, or null.
 * - direction: The direction.
 * - width, height: The canvas's size.
 */
/proc/dirt_hair_layers_brightness(sheet, state, outer_sheet, list/outer_states, direction, width, height)
	RETURN_TYPE(/alist)
	var/alist/hair = dirt_hair_brightness(sheet, state, direction, width, height)
	if(!length(outer_states))
		return hair
	var/list/pieces = list()
	for(var/outer_state in outer_states)
		pieces += list(dirt_hair_brightness(outer_sheet, outer_state, direction, width, height))
	var/alist/together = alist()
	for(var/index in 1 to width * height)
		var/value = hair[index]
		for(var/alist/piece as anything in pieces)
			var/own = piece[index]
			if(!isnull(own))
				value = own
		if(!isnull(value))
			together[index] = value
	return together

/**
 * The hair's pixels less its darkest strands, as a surface that dirt_despeckle() reads. The haze the despeckle rings a
 * lone pixel with keeps to those pixels, as the reference generator's despeckle keeps to the hair.
 */
/datum/dirt_hair_view
	parent_type = /datum/dirt_surface

/**
 * Maps each of the hair's kept pixels to the head. This isn't a body's surface, so the body's New() isn't run.
 *
 * Arguments:
 * - kept: alist(index = TRUE) on them, from dirt_hair_kept().
 * - width, height: The canvas's size.
 */
/datum/dirt_hair_view/New(alist/kept, width, height)
	src.width = width
	src.height = height
	flags_of = new /list(width * height)
	for(var/index in kept)
		flags_of[index] = DIRT_LIMB_HEAD
