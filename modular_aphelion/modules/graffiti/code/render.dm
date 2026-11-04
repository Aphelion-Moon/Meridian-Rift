/// Most icons the art icon cache keeps, and the glow mask cache too: 128 dense art icons of 4,801 bytes take 0.6 MB,
/// and 128 glow masks of 6,930 bytes 0.9 MB, as measured.
#define GRAFFITI_ICON_CACHE 128

/**
 * Returns a new transparent icon one or two tiles wide.
 *
 * The files call their one state "nothing", but icon() names the state it takes "", the state an atom
 * shows by default.
 *
 * Arguments:
 * - width: GRAFFITI_WIDTH or GRAFFITI_WIDE_WIDTH.
 *
 * Returns:
 * - icon: GRAFFITI_HEIGHT rows of `width` transparent pixels in one state, "".
 */
/proc/graffiti_blank_icon(width)
	if(width == GRAFFITI_WIDE_WIDTH)
		return icon('modular_aphelion/modules/graffiti/icons/blank_64x32.dmi', "nothing")
	return icon('icons/blanks/32x32.dmi', "nothing")

/**
 * Draws pixels on a new icon as horizontal runs, one DrawBox() for each run of one colour.
 *
 * Arguments:
 * - indices: One entry per pixel, row by row from the top left: the position of its colour in `colors`,
 *   0 where nothing is drawn.
 * - colors: The colours. DrawBox() writes their alpha as given.
 * - width: GRAFFITI_WIDTH or GRAFFITI_WIDE_WIDTH.
 *
 * Returns:
 * - icon: The pixels in one state, "".
 */
/proc/graffiti_draw_icon(list/indices, list/colors, width)
	var/icon/paint = graffiti_blank_icon(width)
	for(var/row in 0 to GRAFFITI_HEIGHT - 1)
		var/start = row * width
		for(var/column = 1; column <= width;)
			var/index = indices[start + column]
			var/run = 1
			while(column + run <= width && indices[start + column + run] == index)
				run++
			if(index)
				paint.DrawBox(colors[index], column, GRAFFITI_HEIGHT - row, column + run - 1, GRAFFITI_HEIGHT - row)
			column += run
	return paint

/**
 * Returns colours as placed graffiti draws them, in their real alphas: opaque ones at GRAFFITI_ALPHA_CEILING, so the
 * surface shows through, and translucent ones at their own, which is below it. None draws above the ceiling.
 *
 * Arguments:
 * - palette: Canonical colours, as graffiti_color() returns them.
 *
 * Returns:
 * - list: The colours as `#rrggbbaa`, in the same order.
 */
/proc/graffiti_drawn_colors(list/palette)
	var/ceiling = num2hex(GRAFFITI_ALPHA_CEILING, 2)
	. = list()
	for(var/color in palette)
		// Art stored before the ceiling, or written by hand, may hold more alpha than it.
		. += (length(color) == 7 || hex2num(copytext(color, 8)) > GRAFFITI_ALPHA_CEILING) ? "[copytext(color, 1, 8)][ceiling]" : color

/**
 * Returns an art drawn as an icon, which every tile showing that art shares. Its paint shows at its real alpha
 * (graffiti_drawn_colors()).
 *
 * Icons are cached by graffiti_art_hash() in SSgraffiti.art_icons, up to GRAFFITI_ICON_CACHE of them, the oldest
 * going first. A placement's art the map no longer uses goes at once (SSgraffiti's release_art()); the composite of a
 * stack of several pieces, which no placement names, only ages out. Never change one.
 *
 * Arguments:
 * - art: The art.
 * - key: The art's graffiti_art_hash(), when the caller has it.
 * - use_cache: Whether to take the icon from the cache and keep it there. A sprite sheet takes icons drawn without it:
 *   once about twenty icons inserted into a sheet are still held elsewhere, as the cache holds them, BYOND refuses
 *   every further Insert() into that sheet ("bad icon operation").
 * - decoded: The art's graffiti_art_decode(), when the caller has it.
 *
 * Returns:
 * - icon: The art in one state, "".
 * - null: There is no art, or it can't be decoded.
 */
/proc/graffiti_art_icon(list/art, key = null, use_cache = TRUE, list/decoded = null)
	if(!art)
		return null
	if(use_cache)
		key ||= graffiti_art_hash(art)
		var/icon/cached = SSgraffiti.art_icons[key]
		if(cached)
			return cached
	var/width = art["w"]
	var/list/palette = decoded ? decoded[1] : graffiti_palette_unpack(art["pal"])
	var/list/indices = decoded ? decoded[2] : (palette && graffiti_decode_flat(art["grid"], length(palette), width * GRAFFITI_HEIGHT))
	if(!indices)
		return null
	var/icon/paint = graffiti_draw_icon(indices, graffiti_drawn_colors(palette), width)
	return use_cache ? custom_sprite_cache_put(SSgraffiti.art_icons, key, paint, GRAFFITI_ICON_CACHE) : paint

/**
 * Returns an art's glow mask: white wherever its paint glows, as opaque as the paint is drawn there.
 *
 * Masks are cached by graffiti_art_hash() in SSgraffiti.glow_icons, as graffiti_art_icon() caches its icons. Never
 * change one.
 *
 * Arguments:
 * - art: The art.
 * - key: The art's graffiti_art_hash(), when the caller has it.
 * - use_cache: Whether to take the mask from the cache and keep it there. A sprite sheet takes masks drawn without it,
 *   as graffiti_art_icon() explains.
 * - decoded: The art's graffiti_art_decode(), when the caller has it.
 *
 * Returns:
 * - icon: The mask in one state, "".
 * - null: No paint glows, there is no art, or it can't be decoded.
 */
/proc/graffiti_glow_icon(list/art, key = null, use_cache = TRUE, list/decoded = null)
	if(!art)
		return null
	if(use_cache)
		key ||= graffiti_art_hash(art)
		var/icon/cached = SSgraffiti.glow_icons[key]
		if(cached)
			return cached
	var/width = art["w"]
	var/pixel_count = width * GRAFFITI_HEIGHT
	var/list/palette = decoded ? decoded[1] : graffiti_palette_unpack(art["pal"])
	var/list/indices = decoded ? decoded[2] : (palette && graffiti_decode_flat(art["grid"], length(palette), pixel_count))
	var/list/glow = decoded ? decoded[3] : (indices && graffiti_decode_flat(art["glow"], 1, pixel_count))
	if(!glow)
		return null
	// One mask colour per alpha, so runs break only where the alpha does.
	var/list/colors = list()
	var/list/classes = list()
	for(var/color in graffiti_drawn_colors(palette))
		var/glow_color = "#ffffff[copytext(color, 8)]"
		colors |= glow_color
		classes += colors.Find(glow_color)
	var/list/lit_classes = new /list(pixel_count)
	var/lit = FALSE
	for(var/position in 1 to pixel_count)
		var/index = glow[position] && indices[position]
		lit_classes[position] = index && classes[index]
		lit ||= index
	if(!lit)
		return null
	var/icon/mask = graffiti_draw_icon(lit_classes, colors, width)
	return use_cache ? custom_sprite_cache_put(SSgraffiti.glow_icons, key, mask, GRAFFITI_ICON_CACHE) : mask

/**
 * Returns which of an art's painted pixels glow, which decides its emissive overlays.
 *
 * Arguments:
 * - art: The art.
 * - decoded: The art's graffiti_art_decode(), when the caller has it.
 *
 * Returns:
 * - GRAFFITI_GLOW_NONE: None of them, or there is no art or it can't be decoded.
 * - GRAFFITI_GLOW_ALL: Every one.
 * - GRAFFITI_GLOW_MIXED: Some.
 */
/proc/graffiti_art_glow_kind(list/art, list/decoded = null)
	if(!art)
		return GRAFFITI_GLOW_NONE
	var/pixel_count = art["w"] * GRAFFITI_HEIGHT
	var/list/indices = decoded ? decoded[2] : graffiti_decode_flat(art["grid"], length(art["pal"]) / 9, pixel_count)
	var/list/glow = decoded ? decoded[3] : (indices && graffiti_decode_flat(art["glow"], 1, pixel_count))
	if(!glow)
		return GRAFFITI_GLOW_NONE
	var/painted = 0
	var/lit = 0
	for(var/position in 1 to pixel_count)
		if(indices[position])
			painted++
			lit += glow[position]
	if(!lit)
		return GRAFFITI_GLOW_NONE
	return lit == painted ? GRAFFITI_GLOW_ALL : GRAFFITI_GLOW_MIXED

/**
 * Returns the overlays that light an art's glowing paint on the emissive plane and let its other paint block
 * the glow of whatever lies beneath it.
 *
 * Paint that doesn't glow gets a blocker of the visible icon, and paint that all glows an emissive of it.
 * Mixed paint gets the blocker with an emissive of the glow mask just above it. They take the layer of
 * `location`, a decal's own, over the glass on a window, moved onto the emissive plane as emissive_appearance()
 * moves a floor plane layer.
 *
 * Arguments:
 * - kind: The art's graffiti_art_glow_kind().
 * - location: The atom the overlays go on, whose plane offset and layer they take.
 * - visible: The art's icon, as graffiti_art_icon() draws it, or the sheet holding it.
 * - mask: The art's glow mask, as graffiti_glow_icon() draws it, or the sheet holding it. Only mixed paint
 *   uses it.
 * - icon_state: The art's state in `visible`, "" for a drawn icon.
 * - mask_state: The mask's state in `mask`, "" for a drawn icon.
 *
 * Returns:
 * - list: The mutable appearances, bottom first.
 */
/proc/graffiti_emissive_overlays(kind, atom/location, icon/visible, icon/mask, icon_state = "", mask_state = "")
	var/layer = IS_TOPDOWN_PLANE(location.plane) ? TOPDOWN_TO_EMISSIVE_LAYER(location.layer) : location.layer
	switch(kind)
		if(GRAFFITI_GLOW_ALL)
			return list(emissive_appearance(visible, icon_state, location, layer))
		if(GRAFFITI_GLOW_MIXED)
			return list(emissive_blocker(visible, icon_state, location, layer), emissive_appearance(mask, mask_state, location, layer + 0.01))
	return list(emissive_blocker(visible, icon_state, location, layer))

/**
 * Returns a new sprite sheet for icons of one width. BYOND can't remove a state, so the blank's own
 * transparent state, "", stays beside the states added to it.
 *
 * Arguments:
 * - width: GRAFFITI_WIDTH or GRAFFITI_WIDE_WIDTH.
 *
 * Returns:
 * - icon: The sheet.
 */
/proc/graffiti_new_sheet(width)
	return graffiti_blank_icon(width)

/**
 * Adds an icon to a sprite sheet as a state of its own, replacing any state of that name.
 *
 * Arguments:
 * - sheet: The sheet, from graffiti_new_sheet() at the icon's width.
 * - new_icon: The icon, as graffiti_art_icon() or graffiti_glow_icon() draws it without their caches, held nowhere else
 *   once it is in.
 * - state_name: The state's name.
 */
/proc/graffiti_sheet_add(icon/sheet, icon/new_icon, state_name)
	sheet.Insert(new_icon, state_name)

/**
 * Returns where one of a map's sprite sheet files lives.
 *
 * Arguments:
 * - map_name: The map's name.
 * - hash: The sheet's hash, from the stack keys it holds and GRAFFITI_ALPHA_CEILING.
 * - root: The directory every map's sheets go under.
 *
 * Returns:
 * - text: The file's path, in the map's own directory under `root`.
 */
/proc/graffiti_sheet_path(map_name, hash, root = GRAFFITI_SHEET_DIRECTORY)
	return "[root][graffiti_file_key(map_name)]/[hash].dmi"

/**
 * Returns text made safe to name a file or directory with.
 *
 * Arguments:
 * - text: The text, such as a map's name.
 *
 * Returns:
 * - text: The text in lowercase, with `_` for every character other than a letter or a digit.
 */
/proc/graffiti_file_key(text)
	return replacetext(LOWER_TEXT(text), regex(@"[^a-z0-9]", "g"), "_")

#undef GRAFFITI_ICON_CACHE
