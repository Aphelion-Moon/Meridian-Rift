/// The most of its own colour that wet cloth keeps, so even white cloth darkens when it's wet.
#define DIRT_WET_CAP 0.82
/// How far a soaked pixel moves toward the darkened colour around it. Wet cloth clings, and its folds flatten.
#define DIRT_WET_FLATTEN 0.4

/**
 * What sweat's multiplier on a garment is made from. The multiplier is the image that darkens the wet cloth. It's made
 * from the wet pixels of the masks the garment draws (/datum/dirt_masks/var/wet) and the garment's own sprite as it's
 * drawn. Garments drawn alike with the same masks share the multiplier, kept in SSdirt.wet_icons.
 */
/datum/dirt_mask_request/wet
	/// The garment's sprite: its icon file, or an icon made at run time.
	var/sheet
	/// The sprite's icon state.
	var/state
	/// The colour the sprite is drawn in, "#RRGGBB", or null.
	var/colour
	/// Pixels right from the body's canvas to the sprite's, as dirt_worn_shift() gives them.
	var/shift_x = 0
	/// Pixels up from the body's canvas to the sprite's.
	var/shift_y = 0
	/// The masks' wet pixels, as /datum/dirt_masks/var/wet holds them. You should NEVER modify it.
	var/alist/wet
	/// The masks' key.
	var/masks_key
	/// The garment's look, from dirt_wet_look().
	var/look
	/// The sprites drawn over the garment that stay dry, from dirt_accessory_sprites(), or null.
	var/list/kept_dry

/**
 * Arguments:
 * - source: The masks the garment draws, holding wet pixels.
 * - look: dirt_wet_look() of `garment`.
 * - garment: As dirt_wet_look() takes it.
 */
/datum/dirt_mask_request/wet/New(datum/dirt_masks/source, look, list/garment)
	. = ..(DIRT_MASKS_WET)
	wet = source.wet
	masks_key = source.key
	src.look = look
	sheet = garment[1]
	state = garment[2]
	if(istext(garment[3]))
		colour = garment[3]
	shift_x = garment[5]
	shift_y = garment[6]
	if(length(garment) > 6)
		kept_dry = garment[7]

/// Returns the multiplier's key: dirt_wet_key() of the garment's look and its masks' key.
/datum/dirt_mask_request/wet/mask_key()
	return dirt_wet_key(look, masks_key)

/datum/dirt_drawing
	/// The key of the multiplier last asked for and what it was worked out from (current_wet()): list(the key, the
	/// masks' key, the garment as current_wet() took it, the garment's look), or null.
	var/list/wet_read

/datum/dirt_mask_job
	/// For sweat's multiplier: the garment's sprite, then each sprite kept dry, as icon() makes them from the request.
	/// They're made at the job's first piece, for every direction to read.
	var/list/wet_sprites

/**
 * Returns a garment's look as text, which sweat's multiplier is keyed by. It holds the sprite, colour and greyscale
 * colours, where the sprite lies from the body's canvas, and the sprites drawn over it that stay dry.
 *
 * Arguments:
 * - garment: list(icon, icon state, colour, greyscale colours, shift right, shift up), then the sprites drawn over it
 *   that stay dry (dirt_accessory_sprites()) if there are any. The colour is "#RRGGBB" or null. A colour drawn by a
 *   filter instead is left out.
 */
/proc/dirt_wet_look(list/garment)
	. = "[dirt_sprite_key(garment[1])]|[garment[2]]|[istext(garment[3]) ? garment[3] : ""]|[garment[4]]|[garment[5]],[garment[6]]"
	for(var/list/sprite as anything in (length(garment) > 6 ? garment[7] : null))
		. += "|[dirt_sprite_key(sprite[1])]:[sprite[2]]:[sprite[3]],[sprite[4]]"

/**
 * Returns the accessories of a wearer's uniform drawn over a garment's sprite, which sweat on the garment leaves dry.
 * They're on the uniform's own sprite, or on a suit or a tie that draws them over itself. The result is
 * list(list(icon, icon state, pixels right, pixels up), ...) as each is drawn on the sprite, or null for none.
 *
 * Arguments:
 * - uniform: The wearer's uniform, or null.
 * - draw_target: The garment's sprite as worn, with what it draws over itself.
 */
/proc/dirt_accessory_sprites(obj/item/clothing/under/uniform, mutable_appearance/draw_target)
	RETURN_TYPE(/list)
	if(!istype(uniform) || !LAZYLEN(uniform.attached_accessories))
		return null
	var/list/sprites = list()
	for(var/image/child as anything in draw_target.overlays)
		if(bulge_is_accessory(uniform, child))
			sprites += list(list(child.icon, child.icon_state, child.pixel_w, child.pixel_z))
	return length(sprites) ? sprites : null

/**
 * Returns the key sweat's multiplier is kept under in SSdirt.wet_icons: an MD5 of the garment's look and its masks'.
 *
 * Arguments:
 * - look: dirt_wet_look() of the garment.
 * - masks_key: The masks' key.
 */
/proc/dirt_wet_key(look, masks_key)
	return md5("[DIRT_MASKS_WET]|[look]|[masks_key]")

/**
 * Returns sweat's multiplier to draw with the masks drawn on a garment, or null for none. Once SSdirt has made the
 * multiplier for those masks and the garment's look, this drawing holds it (wet, wet_key). So it's drawn after
 * SSdirt.wet_icons drops it, and while a new one is made, as masks are (current()). One not made yet is asked for, and
 * `body` is drawn again once it's made. Masks without sweat drop it, and so does forget() with the masks. So a garment
 * washed or taken off while its multiplier is made draws none once it is. The key asked for is kept with the masks' key
 * and the garment it was worked out from (wet_read). So a draw that reads the same builds no text and no MD5.
 *
 * Arguments:
 * - body: The body it's drawn on.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again on it.
 * - garment: As dirt_wet_look() takes it, or null where the masks drawn hold no sweat.
 */
/datum/dirt_drawing/proc/current_wet(mob/living/carbon/human/body, redraw_flags, list/garment)
	if(!masks?.wet || !garment)
		wet = null
		wet_key = null
		wet_read = null
		return null
	// if every entry is equal, the look's text is the same
	if(!wet_read || wet_read[2] != masks.key || !deep_compare_list(wet_read[3], garment))
		var/look = dirt_wet_look(garment)
		wet_read = list(dirt_wet_key(look, masks.key), masks.key, garment, look)
	var/key = wet_read[1]
	if(key == wet_key)
		return wet
	var/cached = SSdirt.wet_icons.fetch(key)
	if(isnull(cached))
		var/datum/dirt_mask_job/waiting = SSdirt.mask_jobs[key]
		if(waiting)
			waiting.wait(body, redraw_flags)
		else
			cached = SSdirt.masks_for(new /datum/dirt_mask_request/wet(masks, wet_read[4], garment), body, redraw_flags, key = key)
	// hold a made one, or FALSE if it can't be made, so a failed one isn't asked for again
	if(!isnull(cached))
		var/datum/dirt_masks/made = cached
		wet = istype(made) ? made.baked : null
		wet_key = key
	return wet

/**
 * Returns whether some splats' materials hold a wet one (sweat), whose pixels make a garment's multiplier.
 *
 * Arguments:
 * - materials: The splats' materials, from dirt_splat_materials(), or null when all are mess.
 */
/proc/dirt_holds_wet(list/materials)
	for(var/material_key in materials)
		if(dirt_material(material_key)?.flags & DIRT_MATERIAL_WET)
			return TRUE
	return FALSE

/**
 * Returns the wet pixels of a cloth surface's merged masks, for sweat's multiplier, or null when none is wet. The
 * result is alist(material key = a list of one text for each direction, in dirt_mask_directions() order). Each text is
 * /datum/dirt_pixels/proc/drawn() of that direction's wet pixels. A wet material's pixels take no colour in the bake
 * (dirt_baked_icon()). Each material is asked once whether it's wet.
 *
 * Arguments:
 * - merged: alist(direction = /datum/dirt_pixels), the surface's merged masks.
 * - shown: alist(direction = indexes) of the only pixels drawn, or null for the whole canvas. If it's null and a mask
 *   keeps its drawn pixels (/datum/dirt_pixels/var/drawn_indexes), this walks those alone.
 */
/proc/dirt_wet_drawn(alist/merged, alist/shown)
	RETURN_TYPE(/alist)
	// material key -> alist(direction -> its wet pixels)
	var/alist/wet_maps = alist()
	// material key -> whether it's wet
	var/alist/wet_materials = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/pixel_map = merged[direction]
		var/list/roles = pixel_map.roles
		var/list/pixel_materials = pixel_map.materials
		if(!pixel_materials)
			continue
		// the order doesn't matter, as each pixel is written on its own
		for(var/index in shown ? shown[direction] : (pixel_map.drawn_indexes || dirt_index_range(length(roles))))
			var/role = roles[index]
			if(!role)
				continue
			var/material_key = pixel_materials[index]
			var/wet = wet_materials[material_key]
			if(isnull(wet))
				wet = !!(dirt_material(material_key)?.flags & DIRT_MATERIAL_WET)
				wet_materials[material_key] = wet
			if(!wet)
				continue
			var/alist/by_direction = (wet_maps[material_key] ||= alist())
			var/datum/dirt_pixels/wet_map = by_direction[direction]
			if(!wet_map)
				wet_map = new /datum/dirt_pixels(pixel_map.width, pixel_map.height)
				// so its drawn() walks only the span its pixels lie in
				wet_map.drawn_indexes = list()
				by_direction[direction] = wet_map
			wet_map.roles[index] = role
			wet_map.thicknesses[index] = pixel_map.thicknesses[index]
			wet_map.drawn_indexes += index
	if(!length(wet_maps))
		return null
	var/alist/wet = alist()
	for(var/material_key, maps in wet_maps)
		var/alist/by_direction = maps
		var/list/texts = list()
		for(var/direction in dirt_mask_directions())
			var/datum/dirt_pixels/wet_map = by_direction[direction]
			texts += wet_map ? wet_map.drawn() : "0"
		wet[material_key] = texts
	return wet

/**
 * Returns how wet each wet pixel is in one direction: alist(index = its role's alpha in its material's tints), read
 * from each material's packed text run by run.
 *
 * Arguments:
 * - wet: /datum/dirt_masks/var/wet.
 * - position: The direction's place in dirt_mask_directions().
 */
/proc/dirt_wet_alphas(alist/wet, position)
	RETURN_TYPE(/alist)
	. = alist()
	for(var/material_key, texts in wet)
		var/list/direction_texts = texts
		var/list/tints = dirt_material(material_key).tints
		var/drawn = direction_texts[position]
		for(var/run in 1 to DIRT_PACKED_COUNT(drawn))
			var/bits = DIRT_PACKED_BITS(drawn, run)
			var/list/tint = tints[DIRT_PACKED_ROLE(bits)]
			for(var/index in DIRT_PACKED_FIRST(bits) to DIRT_PACKED_LAST(bits))
				.[index] = tint[2]

/**
 * Returns the pixels of a garment's sprite within two pixels of the wet ones, which are all the multiplier's 5x5 means
 * read. The result is alist(index = list(red, green, blue)) of those with any opacity. The garment's colour is
 * multiplied in as the reference generator multiplies it, each channel rounded down. Indexes are on the body's 32x32
 * canvas, and the sprite is read where it lies from that canvas.
 *
 * Arguments:
 * - sheet: The sprite's icon file, or an icon made at run time.
 * - state: Its icon state.
 * - colour: Its colour, "#RRGGBB", or null.
 * - direction: The direction it's drawn facing. A state with one direction is read facing south.
 * - wet: alist(index = how wet), from dirt_wet_alphas().
 * - shift_x, shift_y: Pixels right and up from the body's canvas to the sprite's.
 * - sprite: icon(sheet, state), made already by a caller reading it in more than one direction, or null to make it
 *   here.
 */
/proc/dirt_garment_pixels(sheet, state, colour, direction, alist/wet, shift_x = 0, shift_y = 0, icon/sprite = null)
	RETURN_TYPE(/alist)
	. = alist()
	// mark the 5x5 box round each wet pixel in two passes: five along its row, then five up and down from each of those
	var/list/across = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	var/first_wet_row = ICON_SIZE_Y
	var/last_wet_row = -1
	for(var/index in wet)
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		first_wet_row = min(first_wet_row, row)
		last_wet_row = max(last_wet_row, row)
		for(var/near_column in max(column - 2, 0) to min(column + 2, ICON_SIZE_X - 1))
			across[row * ICON_SIZE_X + near_column + 1] = TRUE
	if(last_wet_row < 0)
		return
	var/list/wanted = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/index in first_wet_row * ICON_SIZE_X + 1 to (last_wet_row + 1) * ICON_SIZE_X)
		if(!across[index])
			continue
		var/row = floor((index - 1) / ICON_SIZE_X)
		for(var/near_row in max(row - 2, 0) to min(row + 2, ICON_SIZE_Y - 1))
			wanted[index + (near_row - row) * ICON_SIZE_X] = TRUE
	// the rows the wanted pixels lie in, the only ones looked through
	var/first_row = max(first_wet_row - 2, 0)
	var/last_row = min(last_wet_row + 2, ICON_SIZE_Y - 1)
	sprite ||= icon(sheet, state)
	direction = dirt_sprite_read_facing(sheet, state, direction, sprite)
	var/width = sprite.Width()
	var/height = sprite.Height()
	var/list/tint = colour && rgb2num(colour)
	for(var/index in first_row * ICON_SIZE_X + 1 to (last_row + 1) * ICON_SIZE_X)
		if(!wanted[index])
			continue
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/sprite_x = index - row * ICON_SIZE_X + shift_x
		var/sprite_y = ICON_SIZE_Y - row + shift_y
		if(sprite_x < 1 || sprite_y < 1 || sprite_x > width || sprite_y > height)
			continue
		var/pixel = sprite.GetPixel(sprite_x, sprite_y, null, direction)
		if(!pixel)
			continue
		var/list/channels = rgb2num(pixel)
		if(length(channels) > 3 && !channels[4])
			continue
		if(tint)
			.[index] = list(floor(channels[1] * tint[1] / 255), floor(channels[2] * tint[2] / 255), floor(channels[3] * tint[3] / 255))
		else
			.[index] = list(channels[1], channels[2], channels[3])

/**
 * Returns sweat's multiplier in one direction, as the reference generator makes it for a garment from its own sprite.
 * The result is alist(index = list(red, green, blue)), each factor x 255 with halves rounded up. It holds each wet
 * pixel on the garment's pixels that has a wet one beside it (lone ones read as dark dots). Each factor is
 * 1 - a + a * m, where `a` is how wet the pixel is and `m` is the cloth's local colour. That colour is a 5x5 mean over
 * the garment's pixels, at most DIRT_WET_CAP. The factor is then pulled toward the darkened mean by DIRT_WET_FLATTEN at
 * full wet, so the cloth's own shading flattens rather than deepens. It's never over 1, as a multiply can't lighten.
 * The 5x5 sums are read from summed areas over the rows and columns they reach.
 *
 * Arguments:
 * - garment_pixels: alist(index = list(red, green, blue)) of the garment's pixels near the wet ones, from
 *   dirt_garment_pixels().
 * - wet: alist(index = how wet, 0 to 1), from dirt_wet_alphas().
 * - width, height: The canvas's size.
 */
/proc/dirt_wet_factors(alist/garment_pixels, alist/wet, width, height)
	RETURN_TYPE(/alist)
	. = alist()
	// the wet pixels that lie on the garment's own pixels
	var/alist/on_garment = alist()
	// and the rows and columns their boxes reach
	var/top_row = height
	var/bottom_row = -1
	var/left_column = width
	var/right_column = -1
	for(var/index, alpha in wet)
		if(garment_pixels[index])
			on_garment[index] = alpha
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			top_row = min(top_row, row)
			bottom_row = max(bottom_row, row)
			left_column = min(left_column, column)
			right_column = max(right_column, column)
	if(bottom_row < 0)
		return
	top_row = max(top_row - 2, 0)
	bottom_row = min(bottom_row + 2, height - 1)
	left_column = max(left_column - 2, 0)
	right_column = min(right_column + 2, width - 1)
	// each channel's sum and the pixel count from the range's corner to each pixel, after an unset row and column
	// (read as 0), so a box's sums take four reads, and they're whole numbers under 2^24, exact in any order
	var/stride = right_column - left_column + 2
	var/cells = (bottom_row - top_row + 2) * stride
	var/list/red_area = new /list(cells)
	var/list/green_area = new /list(cells)
	var/list/blue_area = new /list(cells)
	var/list/count_area = new /list(cells)
	for(var/row in top_row to bottom_row)
		var/cell = (row - top_row + 1) * stride + 1
		var/red_run = 0
		var/green_run = 0
		var/blue_run = 0
		var/count_run = 0
		for(var/column in left_column to right_column)
			cell++
			var/list/near = garment_pixels[row * width + column + 1]
			if(near)
				red_run += near[1]
				green_run += near[2]
				blue_run += near[3]
				count_run++
			red_area[cell] = red_area[cell - stride] + red_run
			green_area[cell] = green_area[cell - stride] + green_run
			blue_area[cell] = blue_area[cell - stride] + blue_run
			count_area[cell] = count_area[cell - stride] + count_run
	var/list/channel_areas = list(red_area, green_area, blue_area)
	for(var/index, alpha in on_garment)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		if(!((column < width - 1 && on_garment[index + 1]) || (column > 0 && on_garment[index - 1]) || (row < height - 1 && on_garment[index + width]) || (row > 0 && on_garment[index - width])))
			continue
		// the box's corners in the summed areas
		var/upper = (max(row - 2, 0) - top_row) * stride + 1
		var/lower = (min(row + 2, height - 1) - top_row + 1) * stride + 1
		var/left = max(column - 2, 0) - left_column
		var/right = min(column + 2, width - 1) - left_column + 1
		var/count = count_area[lower + right] - count_area[lower + left] - count_area[upper + right] + count_area[upper + left]
		// every step in the same order as the reference, which works in float32
		var/flat = DIRT_WET_FLATTEN * min(alpha, 1)
		var/kept = 1 - flat
		var/dry = 1 - alpha
		var/list/own = garment_pixels[index]
		var/list/bytes = list()
		for(var/channel in 1 to 3)
			var/list/summed = channel_areas[channel]
			var/mean = (summed[lower + right] - summed[lower + left] - summed[upper + right] + summed[upper + left]) / count
			var/factor = dry + alpha * min(mean / 255, DIRT_WET_CAP)
			var/colour = own[channel]
			if(colour)
				factor = min(1, (colour * factor * kept + mean * factor * flat) / colour)
			bytes += floor(factor * 255 + 0.5)
		.[index] = bytes

/**
 * Returns sweat's multiplier baked into one four-direction RGB icon on a blank state, registered in the resource cache
 * as dirt_baked_icon() registers its icons. Each wet pixel takes its factors as an opaque colour, and every other pixel
 * is clear. Returns null when it has no pixels.
 *
 * Arguments:
 * - factors_by_direction: alist(direction = dirt_wet_factors()).
 */
/proc/dirt_wet_icon(alist/factors_by_direction)
	var/icon/blank = bulge_blank_tile()
	var/icon/baked = icon(blank)
	var/drew = FALSE
	for(var/direction in dirt_mask_directions())
		var/icon/frame = icon(blank)
		for(var/index, factors in factors_by_direction[direction])
			var/list/bytes = factors
			var/row = floor((index - 1) / ICON_SIZE_X)
			frame.DrawBox(rgb(bytes[1], bytes[2], bytes[3]), index - row * ICON_SIZE_X, ICON_SIZE_Y - row)
			drew = TRUE
		baked.Insert(frame, "", direction)
	return drew ? bulge_register_icon(baked) : null

/**
 * Returns an image of sweat's multiplier, BLEND_MULTIPLY. Inside a garment's KEEP_TOGETHER worn wrapper it darkens the
 * garment's own pixels in their own colour. Drawn on its own over the underclothes, it darkens those it lies on.
 *
 * Arguments:
 * - factors: The multiplier's icon (dirt_wet_icon()).
 * - shift_x, shift_y: Pixels right and up in the wrapper, as dirt_mess_inset_image() takes them.
 */
/proc/dirt_wet_image(icon/factors, shift_x = 0, shift_y = 0)
	RETURN_TYPE(/mutable_appearance)
	var/mutable_appearance/multiplier = mutable_appearance(factors)
	multiplier.blend_mode = BLEND_MULTIPLY
	multiplier.pixel_w = shift_x
	multiplier.pixel_z = shift_y
	return multiplier

#undef DIRT_WET_CAP
#undef DIRT_WET_FLATTEN
