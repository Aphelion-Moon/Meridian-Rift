/**
 * The icons a bulge derives on the server: printed patches, adaptive kind masks, anatomy restricted to a mask, and
 * cut covers.
 *
 * A printed garment keeps its print where a bulge pushes its cloth out. Every pixel of the patch copies a pixel of the
 * garment's own worn sprite, chosen by the approved print rule (the print mirrored in from beside the bulge, rows
 * first, then columns toward the body), and the template's kind shades it, in integer arithmetic.
 *
 * A plain-coloured garment's bulge is the template's kinds as white masks, tinted with the adaptive palette by the
 * client: the masks are derived once per shape, so a recolour derives nothing (bulge_template_masks()).
 *
 * Anatomy a bulge shows (the bare part past a family's small_cap, a skirt's clearance) is the penis's own sprite
 * times a white mask, drawn in the penis's own colours (bulge_masked_icon()).
 *
 * A cut cover is the cover garment with its lifted part removed, for skirts and loincloths that reveal: by the skirt's
 * flap (bulge_cut_cover_flap()) or by a loincloth's derived cut, through its keep mask (bulge_cut_cover_patch()).
 *
 * As tg's digitigrade leg mask (get_bodyshape_icon()) and Nova's species GAGS fallback do, a derived icon is built once,
 * registered with fcopy_rsc() and cached by its inputs; a second request is one keyed lookup. Nothing here is called
 * on a per-pass path: a renderer asks when a wearer's look changes.
 */

/// Print templates by "[sheet]|[state]", or by name for a derived one (templates.dm): /datum/bulge_print_template. Lazy.
GLOBAL_LIST(bulge_print_templates)
/// Printed patches by "[sprite ref]|[state]|[template key]", with "|[colour]" for a tinted sprite: a registered icon,
/// or FALSE when the sprite has no print to carry. Lazy; its length counts the failed requests too. A printed sprite,
/// state and colour gets at most one patch per shape its family prints: the sheet shapes to small_cap, and past it to
/// print_cap the shapes derived for the family (96 for loose boxers and for briefs, 33 for jeans, 144 for track pants).
GLOBAL_LIST(bulge_print_patches)
/// Cut covers by "[sprite ref]|[state]|[flap key]" or "[sprite ref]|[state]||[cut name]": a registered icon, or FALSE
/// when nothing could be cut. Lazy.
GLOBAL_LIST(bulge_cut_covers)
/// Keep masks built from skirt flaps, by flap key: an /icon kept on the server, never sent. Lazy.
GLOBAL_LIST(bulge_flap_keeps)
/// Keep masks of loincloth cuts, by "|[cut name]": an /icon kept on the server, never sent. Lazy.
GLOBAL_LIST(bulge_patch_keeps)
/// Anatomy restricted to a mask, by "[sprite]|[state]|[mask sheet]|[mask state]" (no sheet for a derived mask): a
/// registered icon, or FALSE. Lazy.
GLOBAL_LIST(bulge_masked_icons)
/// Masks placed on the 32x32 tile, by "[sheet]|[state]" (no sheet for a derived mask): an /icon kept on the server, never
/// sent. Lazy.
GLOBAL_LIST(bulge_mask_tiles)

/// One channel of a pixel under translucent white or black (OVER): round(base + (target - base) * alpha / 255).
/// The exact value is a whole number of 255ths, which never sits on a half, so rounding cannot differ from the rule's.
#define BULGE_OVER(base, target, alpha) round(((base) * (255 - (alpha)) + (target) * (alpha)) / 255, 1)

/**
 * A bulge shape template decoded for printing: which kind of pushed-out cloth sits at each pixel facing south, east
 * and west (nothing prints facing north). Decoded once per template from a kind map in the template sheets by
 * bulge_decode_template(), or past small_cap derived from the game's sprites (templates.dm), and kept in
 * GLOB.bulge_print_templates.
 */
/datum/bulge_print_template
	/// The template's name, unique per shape; part of every patch's cache key.
	var/key
	/// Kind pixels facing south: flat (column, row, kind) triples, columns and rows from 0 at the top left. Null if none.
	var/list/south
	/// Kind pixels facing east, as south.
	var/list/east
	/// Kind pixels facing west, as south.
	var/list/west
	/// The template sheet it was decoded from; null for a derived template.
	var/icon
	/// Its state in that sheet, or the name it was derived under.
	var/icon_state
	/// The white masks an adaptive bulge of this shape draws, one per kind, and of all its kinds together for its
	/// emissive blocker: registered icons, FALSE for a kind it has no pixels of, null until bulge_template_masks().
	var/mask_cloth
	/// As mask_cloth, for BULGE_KIND_LIGHT.
	var/mask_light
	/// As mask_cloth, for BULGE_KIND_HIGHLIGHT.
	var/mask_highlight
	/// As mask_cloth, for BULGE_KIND_SHADE.
	var/mask_shade
	/// As mask_cloth, for BULGE_KIND_DEEP_SHADE.
	var/mask_deep_shade
	/// Every kind together.
	var/mask_union
	/// What covers draw over their sprites kept to this shape's pixels (bulge_clipped_icon()): sprite -> state ->
	/// registered icon, or FALSE when nothing could be kept. Lazy.
	var/list/clipped

/// The kind pixels facing `facing`, or null.
/datum/bulge_print_template/proc/pixels_facing(facing)
	switch(facing)
		if(SOUTH)
			return south
		if(EAST)
			return east
		if(WEST)
			return west

/**
 * Returns the printed patch for a garment sprite under a bulge template: one registered icon whose state "" faces
 * south, east and west (north stays empty), drawn over the garment where the bulge pushes it out. Derived the first
 * time and cached; null when the sprite has no print to carry, or is not a 32x32 resource.
 *
 * Arguments:
 * * sprite - the worn icon as the garment's appearance holds it (a resource file, never an /icon object).
 * * state - its icon state.
 * * template - the bulge shape, from bulge_shape().
 * * colour - the colour the garment is drawn in ("#rrggbb"), or null: the print is read from the sprite as tinted,
 *   so the patch matches the garment drawn around it. The patch itself is drawn untinted.
 */
/proc/bulge_print_patch(sprite, state, datum/bulge_print_template/template, colour)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isfile(sprite) || isnull(state) || !template)
		return null
	var/key = colour ? "[ref(sprite)]|[state]|[template.key]|[colour]" : "[ref(sprite)]|[state]|[template.key]"
	var/patch = GLOB.bulge_print_patches?[key]
	if(isnull(patch))
		patch = bulge_derive_print_patch(sprite, state, template, colour) || FALSE
		LAZYSET(GLOB.bulge_print_patches, key, patch)
	return patch || null

/// A transparent 32x32 tile in one direction, loaded once; copy it with icon() before drawing on it.
/proc/bulge_blank_tile()
	var/static/icon/blank_tile
	if(!blank_tile)
		blank_tile = icon('icons/blanks/32x32.dmi', "nothing")
		blank_tile.GetPixel(1, 1) // Loaded once here, or every copy loads it again.
	return blank_tile

/// Derives a printed patch (see bulge_print_patch()), uncached.
/proc/bulge_derive_print_patch(sprite, state, datum/bulge_print_template/template, colour)
	var/static/list/facings = list(SOUTH, EAST, WEST)
	var/icon/blank_tile = bulge_blank_tile()
	// One cut from the (possibly large) sprite sheet; each direction then comes from the small copy.
	var/icon/garment = icon(sprite, state, null, 1, 0)
	if(garment.Width() != 32 || garment.Height() != 32)
		return null
	if(colour)
		garment.Blend(colour, ICON_MULTIPLY) // As the client and getFlatIcon() tint the garment drawn around it.
	// A worn state with one direction draws its south view every way, as getFlatIcon() treats one.
	var/one_way = !length(icon_states(icon(garment, null, EAST)))
	var/icon/patch = icon()
	var/drawn = 0
	for(var/facing in facings)
		var/icon/frame = icon(blank_tile)
		var/list/kind_pixels = template.pixels_facing(facing)
		if(kind_pixels)
			var/datum/bulge_print_reader/reader = new
			reader.frame = icon(garment, null, one_way ? SOUTH : facing)
			for(var/index = 1; index <= length(kind_pixels); index += 3)
				var/column = kind_pixels[index]
				var/row = kind_pixels[index + 1]
				var/source = reader.source_pixel(column, row, facing)
				if(!source)
					return null
				frame.DrawBox(bulge_print_colour(source, kind_pixels[index + 2]), column + 1, 32 - row)
				drawn++
		// Every facing is inserted, empty or not, so the state always has four directions and north stays empty.
		patch.Insert(frame, "", facing)
	if(!drawn)
		return null
	return bulge_register_icon(patch)

/**
 * Returns the cover garment with a flap cut away: its sprite with every pixel of the flap made transparent (the
 * lifted part of a revealing skirt's hem), as one registered icon whose state "" faces all four ways; nothing is cut
 * facing north. One flap serves every garment with that hem. Cached like a patch; null when the sprite is not a
 * 32x32 resource or has no such state.
 *
 * Arguments:
 * * sprite, state - the cover's worn icon (a resource file) and state, as its appearance draws them.
 * * flap - the flap, from bulge_flap().
 */
/proc/bulge_cut_cover_flap(sprite, state, datum/bulge_print_template/flap)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isfile(sprite) || isnull(state) || !flap)
		return null
	var/key = "[ref(sprite)]|[state]|[flap.key]"
	var/cover = GLOB.bulge_cut_covers?[key]
	if(isnull(cover))
		cover = bulge_derive_cut(sprite, state, bulge_flap_keep(flap)) || FALSE
		LAZYSET(GLOB.bulge_cut_covers, key, cover)
	return cover || null

/**
 * Returns a loincloth with its lifted flap cut away: its sprite kept only where the cut's keep mask (bulge_patch_keep())
 * is opaque, as one registered icon whose state "" faces all four ways. Only the mask's alpha is used, so the wearer's
 * own garment pixels stay. Cached like a patch; null when the sprite is not a 32x32 resource or has no such state.
 *
 * Arguments:
 * * sprite, state - the cover's worn icon (a resource file) and state, as its appearance draws them.
 * * cut - the cut, from bulge_loincloth_cut().
 */
/proc/bulge_cut_cover_patch(sprite, state, datum/bulge_sheet_state/cut)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isfile(sprite) || isnull(state) || !cut)
		return null
	var/key = "[ref(sprite)]|[state]|[cut.icon]|[cut.icon_state]"
	var/cover = GLOB.bulge_cut_covers?[key]
	if(isnull(cover))
		cover = bulge_derive_cut(sprite, state, bulge_patch_keep(cut)) || FALSE
		LAZYSET(GLOB.bulge_cut_covers, key, cover)
	return cover || null

/// A sprite's state as an icon with four directions, frame 1: a state with one direction is its south view every way,
/// as getFlatIcon() treats one. Null when the state is missing or not 32x32.
/proc/bulge_four_way(sprite, state)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/icon/frames = icon(sprite, state, null, 1, 0)
	if(!length(icon_states(frames)) || frames.Width() != 32 || frames.Height() != 32)
		return null
	if(length(icon_states(icon(frames, null, EAST))))
		return frames
	var/icon/south = icon(frames, null, SOUTH)
	frames = icon()
	for(var/facing in facings)
		frames.Insert(south, "", facing)
	return frames

/// Cuts a cover by a keep mask (see bulge_cut_cover_flap() and bulge_cut_cover_patch()), uncached: the sprite times the
/// keep mask.
/proc/bulge_derive_cut(sprite, state, icon/keep)
	var/icon/garment = bulge_four_way(sprite, state)
	if(!garment)
		return null
	garment.Blend(keep, ICON_MULTIPLY)
	return bulge_register_icon(garment)

/**
 * A flap's keep mask: opaque white over the whole 32x32 tile in all four directions except the flap's own pixels,
 * which are transparent. Built once per flap (GLOB.bulge_flap_keeps), so a cut costs one multiply.
 */
/proc/bulge_flap_keep(datum/bulge_print_template/flap)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/icon/keep = GLOB.bulge_flap_keeps?[flap.key]
	if(keep)
		return keep
	keep = icon()
	for(var/facing in facings)
		var/icon/frame = icon(bulge_white_tile())
		var/list/pixels = flap.pixels_facing(facing)
		// Runs of the flap along a row are erased with one box each.
		var/index = 1
		while(index <= length(pixels))
			var/first = pixels[index]
			var/row = pixels[index + 1]
			var/last = first
			index += 3
			while(index <= length(pixels) && pixels[index + 1] == row && pixels[index] == last + 1)
				last++
				index += 3
			frame.DrawBox(null, first + 1, 32 - row, last + 1, 32 - row)
		keep.Insert(frame, "", facing)
	keep.GetPixel(1, 1) // Finish the deferred operations once, here.
	LAZYSET(GLOB.bulge_flap_keeps, flap.key, keep)
	return keep

/// A white 32x32 tile in one direction, loaded once; copy it with icon() before drawing on it.
/proc/bulge_white_tile()
	var/static/icon/white_tile
	if(!white_tile)
		white_tile = icon('icons/blanks/32x32.dmi', "nothing")
		white_tile.DrawBox("#ffffff", 1, 1, 32, 32)
		white_tile.GetPixel(1, 1)
	return white_tile

/**
 * A loincloth cut's keep mask: opaque white over the whole 32x32 tile in all four directions, except the pixels the cut
 * takes away. Built once per cut (GLOB.bulge_patch_keeps) from `erased`, those pixels facing south, north, east and west
 * (lists of indices, row * 32 + column + 1 from the top left), which bulge_loincloth_cut() derives and passes before it
 * returns the cut; asked for again, without `erased`, it is the one built then.
 */
/proc/bulge_patch_keep(datum/bulge_sheet_state/cut, list/erased)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/key = "[cut.icon]|[cut.icon_state]"
	var/icon/keep = GLOB.bulge_patch_keeps?[key]
	if(keep)
		return keep
	if(!erased)
		CRASH("Bulge cut [cut.icon_state] asked for its keep mask before bulge_loincloth_cut() derived it.")
	keep = icon()
	for(var/index in 1 to length(facings))
		var/facing = facings[index]
		var/icon/frame = icon(bulge_white_tile())
		for(var/at in erased[index])
			frame.DrawBox(null, ((at - 1) & 31) + 1, 32 - ((at - 1) >> 5))
		keep.Insert(frame, "", facing)
	keep.GetPixel(1, 1) // Finish the deferred operations once, here.
	LAZYSET(GLOB.bulge_patch_keeps, key, keep)
	return keep

/**
 * Derives the white masks an adaptive bulge of a template draws (see /datum/bulge_print_template/var/mask_cloth), once
 * per template: one registered icon per kind it has pixels of, and one of all its kinds together. Their state "" faces
 * all four ways; north stays empty. The palette is the client's tint on them, so a recolour derives nothing.
 */
/proc/bulge_template_masks(datum/bulge_print_template/template)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isnull(template.mask_union))
		return
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/icon/blank_tile = bulge_blank_tile()
	// Six transient icons, one per kind (BULGE_KIND_CLOTH to BULGE_KIND_DEEP_SHADE) and the union last.
	var/list/masks = list(icon(), icon(), icon(), icon(), icon(), icon())
	var/list/drawn = new /list(6)
	for(var/facing in facings)
		var/list/frames = list(icon(blank_tile), icon(blank_tile), icon(blank_tile), icon(blank_tile), icon(blank_tile), icon(blank_tile))
		var/list/pixels = template.pixels_facing(facing)
		for(var/index = 1; index <= length(pixels); index += 3)
			var/x = pixels[index] + 1
			var/y = 32 - pixels[index + 1]
			var/kind = pixels[index + 2]
			if(kind < BULGE_KIND_CLOTH || kind > BULGE_KIND_DEEP_SHADE)
				stack_trace("Bulge template [template.key] has kind [kind] at [x],[y].")
				continue
			var/icon/frame = frames[kind]
			frame.DrawBox("#ffffff", x, y)
			frame = frames[6]
			frame.DrawBox("#ffffff", x, y)
			drawn[kind] = TRUE
			drawn[6] = TRUE
		for(var/index in 1 to 6)
			var/icon/mask = masks[index]
			mask.Insert(frames[index], "", facing)
	template.mask_cloth = drawn[BULGE_KIND_CLOTH] ? bulge_register_icon(masks[BULGE_KIND_CLOTH]) : FALSE
	template.mask_light = drawn[BULGE_KIND_LIGHT] ? bulge_register_icon(masks[BULGE_KIND_LIGHT]) : FALSE
	template.mask_highlight = drawn[BULGE_KIND_HIGHLIGHT] ? bulge_register_icon(masks[BULGE_KIND_HIGHLIGHT]) : FALSE
	template.mask_shade = drawn[BULGE_KIND_SHADE] ? bulge_register_icon(masks[BULGE_KIND_SHADE]) : FALSE
	template.mask_deep_shade = drawn[BULGE_KIND_DEEP_SHADE] ? bulge_register_icon(masks[BULGE_KIND_DEEP_SHADE]) : FALSE
	template.mask_union = drawn[6] ? bulge_register_icon(masks[6]) : FALSE

/**
 * A mask placed on the 32x32 tile, in all four directions: transparent outside the mask. Built once per state
 * (GLOB.bulge_mask_tiles), kept on the server and never sent: drawn from `pixels` when given (a derived mask's pixels
 * as a template, as bulge_derive_large() derives them and bulge_exposed() passes them before it returns the mask), else
 * from the mask's sheet.
 */
/proc/bulge_mask_tile(datum/bulge_sheet_state/mask, datum/bulge_print_template/pixels)
	var/static/list/facings = list(SOUTH, NORTH, EAST, WEST)
	var/key = "[mask.icon]|[mask.icon_state]"
	var/icon/tile = GLOB.bulge_mask_tiles?[key]
	if(tile)
		return tile
	if(!pixels && !mask.icon)
		CRASH("Bulge mask [mask.icon_state] asked for its tile before bulge_exposed() derived it.")
	tile = icon()
	for(var/facing in facings)
		var/icon/frame = icon(bulge_blank_tile())
		if(pixels)
			// Runs of the mask along a row are drawn with one box each.
			var/list/drawn = pixels.pixels_facing(facing)
			var/index = 1
			while(index <= length(drawn))
				var/first = drawn[index]
				var/row = drawn[index + 1]
				var/last = first
				index += 3
				while(index <= length(drawn) && drawn[index + 1] == row && drawn[index] == last + 1)
					last++
					index += 3
				frame.DrawBox("#ffffff", first + 1, 32 - row, last + 1, 32 - row)
		else
			frame.Blend(icon(mask.icon, mask.icon_state, facing, 1, 0), ICON_OVERLAY, mask.pixel_x + 1, mask.pixel_y + 1)
		tile.Insert(frame, "", facing)
	tile.GetPixel(1, 1) // Finish the deferred operations once, here.
	LAZYSET(GLOB.bulge_mask_tiles, key, tile)
	return tile

/**
 * Returns anatomy restricted to a mask: an icon state's frames kept only where a white mask is opaque (the bare
 * part of a penis past a family's small_cap, or what of it shows above a skirt), as one registered
 * icon whose state "" faces all four ways. The image drawing it keeps the anatomy's own colour, so one masked copy
 * serves every colouring. Cached by its inputs; null when the state is missing or not 32x32.
 *
 * Arguments:
 * * sprite, state - the anatomy's icon and state, as the penis overlay draws them.
 * * mask - the mask, from bulge_exposed() or bulge_clearance().
 */
/proc/bulge_masked_icon(sprite, state, datum/bulge_sheet_state/mask)
	SHOULD_NOT_SLEEP(TRUE)
	if(!sprite || isnull(state) || !mask)
		return null
	var/sprite_key = isfile(sprite) && length("[sprite]") ? "[sprite]" : ref(sprite)
	var/key = "[sprite_key]|[state]|[mask.icon]|[mask.icon_state]"
	var/masked = GLOB.bulge_masked_icons?[key]
	if(isnull(masked))
		var/icon/frames = bulge_four_way(sprite, state)
		if(frames)
			frames.Blend(bulge_mask_tile(mask), ICON_MULTIPLY)
			masked = bulge_register_icon(frames)
		else
			masked = FALSE
		LAZYSET(GLOB.bulge_masked_icons, key, masked)
	return masked || null

/**
 * Returns a sprite kept only inside a shape's pixels (what a cover draws over itself, kept to a look's cloth): the
 * sprite's frames times the template's union mask (bulge_template_masks()), as one registered icon whose state ""
 * faces all four ways. The image drawing it keeps the sprite's own colour. Cached on the template by sprite and state;
 * null when the state is missing or not 32x32, or the template has no pixels.
 *
 * Arguments:
 * * sprite, state - the overlay's icon (a resource file) and state, as the cover draws it.
 * * template - the look's shape, its masks derived.
 */
/proc/bulge_clipped_icon(sprite, state, datum/bulge_print_template/template)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isfile(sprite) || isnull(state) || !template?.mask_union)
		return null
	var/list/states = template.clipped?[sprite]
	var/clipped = states?[state]
	if(isnull(clipped))
		var/icon/frames = bulge_four_way(sprite, state)
		if(frames)
			frames.Blend(icon(template.mask_union), ICON_MULTIPLY)
			clipped = bulge_register_icon(frames)
		else
			clipped = FALSE
		if(!states)
			states = list()
			LAZYSET(template.clipped, sprite, states)
		states[state] = clipped
	return clipped || null

/// Registers an icon built at run time in the resource cache, as tg's derived icons are. The GetPixel() makes BYOND
/// finish its deferred icon operations first, as GAGS does before it caches an icon.
/proc/bulge_register_icon(icon/built)
	built.GetPixel(1, 1)
	return fcopy_rsc(built)

/**
 * The colour of a patch pixel (rgb() text) from the garment pixel the rule chose (GetPixel() text): the pixel itself
 * for cloth, or the pixel under the kind's translucent white or black. A partly transparent garment pixel gives its
 * colour; patches are opaque.
 */
/proc/bulge_print_colour(pixel, kind)
	var/target
	var/alpha
	switch(kind)
		if(BULGE_KIND_CLOTH)
			return length(pixel) == 7 ? pixel : copytext(pixel, 1, 8)
		if(BULGE_KIND_LIGHT)
			target = 255
			alpha = 70
		if(BULGE_KIND_HIGHLIGHT)
			target = 255
			alpha = 110
		if(BULGE_KIND_SHADE)
			target = 0
			alpha = 55
		if(BULGE_KIND_DEEP_SHADE)
			target = 0
			alpha = 105
		else
			stack_trace("Unknown bulge kind [kind] for a patch pixel.")
			return length(pixel) == 7 ? pixel : copytext(pixel, 1, 8)
	var/list/channels = rgb2num(pixel)
	return rgb(BULGE_OVER(channels[1], target, alpha), BULGE_OVER(channels[2], target, alpha), BULGE_OVER(channels[3], target, alpha))

/**
 * Whether two pixels (GetPixel() text) are different colours of a print (red and yellow, red and white) rather than
 * one colour lighter or darker (black and its shine): one has chroma 30 or more and the other not, or both do and
 * their hues are 25 degrees or more apart. Hues are compared as exact fractions, never as floating point; so a hue
 * difference of exactly 25 degrees counts as two prints here, where the preview's colorsys floats may land a hair
 * below 25 and call it one (no approved garment comes near a tie: the smallest margin in the corpus is 1.87 degrees).
 */
/proc/bulge_two_prints(first_pixel, second_pixel)
	var/list/first = rgb2num(first_pixel)
	var/list/second = rgb2num(second_pixel)
	var/first_max = max(first[1], first[2], first[3])
	var/first_chroma = first_max - min(first[1], first[2], first[3])
	var/second_max = max(second[1], second[2], second[3])
	var/second_chroma = second_max - min(second[1], second[2], second[3])
	if((first_chroma >= 30) != (second_chroma >= 30))
		return TRUE
	if(first_chroma < 30)
		return FALSE
	// Hues in sixths of a turn, scaled by their chroma (as colorsys: red first, then green, then blue).
	var/first_hue = bulge_hue_numerator(first[1], first[2], first[3], first_max, first_chroma)
	var/second_hue = bulge_hue_numerator(second[1], second[2], second[3], second_max, second_chroma)
	var/turn = 6 * first_chroma * second_chroma
	var/apart = abs(first_hue * second_chroma - second_hue * first_chroma)
	apart = min(apart, turn - apart)
	// apart / (chroma * chroma) sixths >= 25 degrees, that is 5/12 of a sixth. Every term stays below 2^24.
	return 12 * apart >= 5 * first_chroma * second_chroma

/// A colour's hue in sixths of a turn times its chroma, in [0, 6 * chroma): the hue as an exact fraction over chroma.
/proc/bulge_hue_numerator(red, green, blue, high, chroma)
	if(red == high)
		var/hue = green - blue
		return hue < 0 ? hue + 6 * chroma : hue
	if(green == high)
		return 2 * chroma + blue - red
	return 4 * chroma + red - green

/// `value` folded into first..last as between two mirrors, the ends not repeated, so alternating stripes keep
/// alternating across the fold.
/proc/bulge_mirror(value, first, last)
	if(first == last)
		return first
	var/period = 2 * (last - first)
	var/offset = (value - first) % period
	if(offset < 0)
		offset += period
	return first + (offset <= last - first ? offset : period - offset)

/// The index in `runs` (flat ascending (first, last) pairs) of the run nearest `value`; the first of equals.
/proc/bulge_nearest_run(list/runs, value)
	var/best = 0
	var/best_distance = 0
	for(var/index = 1; index < length(runs); index += 2)
		var/distance = 0
		if(value < runs[index])
			distance = runs[index] - value
		else if(value > runs[index + 1])
			distance = value - runs[index + 1]
		if(!best || distance < best_distance)
			best = index
			best_distance = distance
	return best

/**
 * One direction of a worn sprite while a patch is derived, read a row at a time: rows the rule never visits are never
 * read. Lives for one derivation.
 */
/datum/bulge_print_reader
	/// The sprite facing one way.
	var/icon/frame
	/// Row + 1 (rows from 0 at the top) -> its 32 pixels as GetPixel() text, null where transparent; null until read.
	var/list/pixels = new /list(32)
	/// Row + 1 -> its print as flat (first, last) column pairs, FALSE when it has none; null until read.
	var/list/runs = new /list(32)
	/// Whether every row has been read; the row branch looks down whole columns.
	var/all_read = FALSE

/**
 * Returns the print on `row`: flat (first, last) column pairs of the row's interior, or FALSE. Each run of garment
 * pixels counts whole when one or two pixels wide and loses its two end pixels (its outline) when wider. Reads the
 * row the first time.
 */
/datum/bulge_print_reader/proc/row_runs(row)
	var/known = runs[row + 1]
	if(!isnull(known))
		return known
	var/list/line = new /list(32)
	var/list/found
	var/first = -1
	var/y = 32 - row
	for(var/column in 0 to 32)
		var/pixel = column < 32 ? frame.GetPixel(column + 1, y) : null
		if(pixel)
			line[column + 1] = pixel
			if(first < 0)
				first = column
			continue
		if(first < 0)
			continue
		var/last = column - 1
		if(last - first < 2)
			LAZYADD(found, list(first, last))
		else
			LAZYADD(found, list(first + 1, last - 1))
		first = -1
	pixels[row + 1] = line
	runs[row + 1] = found || FALSE
	return runs[row + 1]

/// Whether (column, row) is inside the print.
/datum/bulge_print_reader/proc/is_interior(column, row)
	var/list/found = row_runs(row)
	for(var/index = 1; index < length(found); index += 2)
		if(column >= found[index] && column <= found[index + 1])
			return TRUE
	return FALSE

/// Reads every row not read yet.
/datum/bulge_print_reader/proc/read_all_rows()
	if(all_read)
		return
	for(var/row in 0 to 31)
		row_runs(row)
	all_read = TRUE

/**
 * The garment pixel (GetPixel() text) the print rule carries to (column, row) of a patch facing `facing`, or null
 * when the sprite has no print at all. Inside the print a pixel keeps its own colour. Elsewhere the print is mirrored
 * in from beside it: rows first (above the waistband or below the hem), then along the row toward the body in profile,
 * so stripes and patterns run on instead of one edge colour smearing out.
 */
/datum/bulge_print_reader/proc/source_pixel(column, row, facing)
	if(is_interior(column, row))
		return pixels[row + 1][column + 1]
	if(!row_runs(row))
		// Mirror rows in from the nearest stretch of print in this column, or in any column if this one has none; a
		// garment only a few rows deep would mirror its waistband into its hem, so there the nearest row repeats.
		read_all_rows()
		var/list/stretches
		for(var/candidate in 0 to 31)
			if(is_interior(column, candidate))
				if(length(stretches) && stretches[length(stretches)] == candidate - 1)
					stretches[length(stretches)] = candidate
				else
					LAZYADD(stretches, list(candidate, candidate))
		if(!stretches)
			for(var/candidate in 0 to 31)
				if(runs[candidate + 1])
					if(length(stretches) && stretches[length(stretches)] == candidate - 1)
						stretches[length(stretches)] = candidate
					else
						LAZYADD(stretches, list(candidate, candidate))
		if(!stretches)
			return null
		var/nearest = bulge_nearest_run(stretches, row)
		var/top = stretches[nearest]
		var/bottom = stretches[nearest + 1]
		row = bottom - top >= 3 ? bulge_mirror(row, top, bottom) : clamp(row, top, bottom)
		if(is_interior(column, row))
			return pixels[row + 1][column + 1]
	var/list/candidates = runs[row + 1]
	var/profile = facing == EAST || facing == WEST
	if(profile)
		// In profile the print comes from the body's side of the bulge.
		var/list/beside
		for(var/index = 1; index < length(candidates); index += 2)
			if(facing == EAST ? candidates[index + 1] < column : candidates[index] > column)
				LAZYADD(beside, list(candidates[index], candidates[index + 1]))
		if(beside)
			candidates = beside
	var/nearest = bulge_nearest_run(candidates, column)
	var/first = candidates[nearest]
	var/last = candidates[nearest + 1]
	var/list/line = pixels[row + 1]
	if(profile && last - first == 1 && !bulge_two_prints(line[first + 1], line[last + 1]))
		// A two-pixel strip in one colour is cloth plus its edge or shine: take the cloth, nearer the body.
		return line[(facing == EAST ? first : last) + 1]
	return line[bulge_mirror(column, first, last) + 1]

#undef BULGE_OVER
