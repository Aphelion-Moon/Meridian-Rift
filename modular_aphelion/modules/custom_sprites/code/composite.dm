/// Where a canvas pixel falls in one region's own drawing, which may be narrower than the canvas. 0 when outside it.
/proc/custom_sprite_region_position(zone, x, y, width)
	var/zone_width = custom_marking_zone_width(zone)
	var/zone_x = x - (width - zone_width) / 2
	if(zone_x < 0 || zone_x >= zone_width)
		return 0
	return y * zone_width + zone_x + 1

/**
 * One drawing's pixels as colors, row-major from the top left.
 *
 * An explicit tint is baked in, so the colors are what the game shows. A drawing of the wrong
 * width for its zone, or no drawing at all, reads as empty.
 *
 * Returns direction -> list of width * 32 entries: "#rrggbb", or null for transparent.
 */
/proc/custom_sprite_drawing_pixels(list/drawing, width = 32)
	. = list()
	var/list/palette = drawing?["palette"]
	var/tint = drawing?["tint"]
	var/list/colors = list()
	for(var/color in palette)
		colors += tint && tint != "#ffffff" ? custom_sprite_tint_color(color, tint) : color
	var/usable = drawing && custom_sprite_width(drawing) == width
	for(var/direction in GLOB.custom_style_directions)
		var/list/pixels = new /list(width * 32)
		var/grid = usable ? custom_sprite_decode_grid(drawing["dirs"][direction], length(palette), width * 32) : null
		if(grid)
			for(var/position in 1 to width * 32)
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1)) - 1
				if(index > 0)
					pixels[position] = colors[index]
		.[direction] = pixels

/// One region's pixels in one view, copied on first write, since decoded pixels may be shared with the caller's cache.
/proc/custom_sprite_private_view(list/pixels, list/private, zone, direction)
	var/key = "[zone]|[direction]"
	if(!private[key])
		var/list/views = pixels[zone]
		views = views.Copy()
		var/list/view = views[direction]
		views[direction] = view.Copy()
		pixels[zone] = views
		private[key] = TRUE
	return pixels[zone][direction]

/**
 * Where a region's paint in one view sits under a different limb or outside every region.
 *
 * The canvas never shows paint there. Pixels its arm/hand partner owns aren't included, since the
 * canvas shows their paint.
 *
 * Returns positions in `colors`, a region's pixels in one view, that hold covered paint.
 */
/proc/custom_sprite_covered_positions(list/colors, zone, list/rows, list/zones, width)
	. = list()
	var/zone_width = custom_marking_zone_width(zone)
	var/offset = (width - zone_width) / 2
	var/partner = custom_marking_partner(zone)
	for(var/y in 0 to 31)
		for(var/zone_x in 0 to zone_width - 1)
			var/position = y * zone_width + zone_x + 1
			if(isnull(colors[position]))
				continue
			var/owner = custom_sprite_region_owner(rows, zones, zone_x + offset, y)
			if(owner != zone && (!partner || owner != partner))
				. += position

/// One region's color at a canvas pixel, or null.
/proc/custom_sprite_region_pixel(list/pixels, zone, direction, x, y, width)
	var/position = custom_sprite_region_position(zone, x, y, width)
	var/list/colors = pixels[zone]?[direction]
	return position && colors ? colors[position] : null

/// What the game shows at a canvas pixel: its owner's paint, with a hand's paint over its arm's.
/proc/custom_sprite_region_visible(list/pixels, zone, direction, x, y, width)
	if(!zone)
		return null
	var/partner = custom_marking_partner(zone)
	if(!partner)
		return custom_sprite_region_pixel(pixels, zone, direction, x, y, width)
	var/hand = GLOB.custom_marking_hand_arms[zone] ? zone : partner
	var/arm = hand == zone ? partner : zone
	return custom_sprite_region_pixel(pixels, hand, direction, x, y, width) || custom_sprite_region_pixel(pixels, arm, direction, x, y, width)

/**
 * Builds the whole-body canvas from each region's saved drawing.
 *
 * Each pixel shows its owner's paint. An arm and its hand share one limb and hand paint draws
 * above arm paint, so at a pixel either of them owns the hand's paint wins and the arm's shows
 * where the hand has none. Paint hidden under a different limb isn't shown, as in game.
 *
 * Arguments:
 * - drawings: zone -> saved drawing, or null.
 * - region_map, zones: From custom_sprite_region_map().
 * - width: The canvas width.
 *
 * Returns direction -> 32 rows of `width` "#rrggbbaa" colors, the workspace frame format.
 */
/proc/custom_sprite_compose_regions(list/drawings, list/region_map, list/zones, width)
	var/list/pixels = list()
	for(var/zone in zones)
		for(var/owner in list(zone, custom_marking_partner(zone)))
			if(owner && !pixels[owner])
				pixels[owner] = custom_sprite_drawing_pixels(drawings?[owner], custom_marking_zone_width(owner))
	. = list()
	for(var/direction in GLOB.custom_style_directions)
		var/list/rows = region_map[direction]
		var/list/frame = list()
		for(var/y in 0 to 31)
			var/list/row = list()
			for(var/x in 0 to width - 1)
				var/color = custom_sprite_region_visible(pixels, custom_sprite_region_owner(rows, zones, x, y), direction, x, y, width)
				row += color ? "[color]ff" : "#00000000"
			frame += list(row)
		.[direction] = frame

/**
 * Splits the canvas back into each region's drawing, changing only what was edited.
 *
 * A pixel is edited when the canvas differs from the baseline. An edited pixel goes to its owner,
 * and leaves the owner's arm/hand partner so the old paint can't show through. Every other pixel,
 * including stranded paint and paint hidden under a different limb, keeps its saved value, except
 * in views where Clear, an import or a restoration replaced the region outright.
 *
 * Arguments:
 * - frames: direction -> the canvas now.
 * - baseline: direction -> the canvas when the draft opened or was last saved.
 * - drawings: zone -> saved drawing, or null.
 * - region_map, zones, width: The map the canvas was built with.
 * - decoded: Optional zone -> custom_sprite_drawing_pixels() of `drawings`, reused read-only.
 * - resets: Optional zone -> views ("2" -> TRUE) replaced outright, where covered paint goes too.
 *
 * Returns zone -> list("drawing" = drawing or null, "changed" = TRUE/FALSE, "error" = text or
 * null) for every zone in `zones` and `drawings`. Unchanged zones return their saved drawing.
 */
/proc/custom_sprite_split_regions(list/frames, list/baseline, list/drawings, list/region_map, list/zones, width, list/decoded, list/resets)
	var/list/all_zones = zones.Copy()
	for(var/zone in drawings)
		all_zones |= zone
	var/list/pixels = list()
	for(var/zone in all_zones)
		pixels[zone] = decoded?[zone] || custom_sprite_drawing_pixels(drawings?[zone], custom_marking_zone_width(zone))
	var/list/private = list()
	var/list/changed = list()
	for(var/direction in GLOB.custom_style_directions)
		var/list/rows = region_map[direction]
		var/list/frame = frames[direction]
		var/list/base = baseline[direction]
		for(var/y in 1 to 32)
			var/list/frame_row = frame[y]
			var/list/base_row = base[y]
			for(var/x in 1 to width)
				var/now = frame_row[x]
				if(now == base_row[x])
					continue
				var/owner = custom_sprite_region_owner(rows, zones, x - 1, y - 1)
				if(!owner)
					continue
				var/color = endswith(now, "00") ? null : LOWER_TEXT(copytext(now, 1, 8))
				for(var/target in list(owner, custom_marking_partner(owner)))
					if(!target || !pixels[target])
						continue
					var/value = target == owner ? color : null
					var/position = custom_sprite_region_position(target, x - 1, y - 1, width)
					if(!position || pixels[target][direction][position] == value)
						continue
					var/list/view = custom_sprite_private_view(pixels, private, target, direction)
					view[position] = value
					changed[target] = TRUE
	for(var/zone in resets)
		if(!pixels[zone])
			continue
		for(var/direction in resets[zone])
			var/list/covered = custom_sprite_covered_positions(pixels[zone][direction], zone, region_map[direction], zones, width)
			if(!length(covered))
				continue
			var/list/view = custom_sprite_private_view(pixels, private, zone, direction)
			for(var/position in covered)
				view[position] = null
			changed[zone] = TRUE
	. = list()
	for(var/zone in all_zones)
		var/list/saved = drawings?[zone]
		if(!changed[zone])
			.[zone] = list("drawing" = saved, "changed" = FALSE, "error" = null)
			continue
		var/list/encoded = custom_sprite_pixels_drawing(pixels[zone], custom_marking_zone_width(zone), saved?["emissive"])
		.[zone] = list("drawing" = encoded["drawing"], "changed" = TRUE, "error" = encoded["error"])

/**
 * Encodes one region's pixels as a canonical, literal-color drawing.
 *
 * Returns list("drawing" = drawing, or null when nothing is painted), or list("error" = text)
 * when the region would need more than CUSTOM_SPRITE_MAX_COLORS colors.
 */
/proc/custom_sprite_pixels_drawing(list/pixels, width, emissive)
	var/list/palette = list()
	var/list/indices = list()
	var/list/grids = list()
	for(var/direction in GLOB.custom_style_directions)
		var/list/cells = list()
		var/painted = FALSE
		for(var/color in pixels[direction])
			if(!color)
				cells += "0"
				continue
			var/index = indices[color]
			if(!index)
				if(length(palette) >= CUSTOM_SPRITE_MAX_COLORS)
					return list("error" = "uses more than [CUSTOM_SPRITE_MAX_COLORS] colors.")
				palette += color
				index = length(palette)
				indices[color] = index
			cells += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, index + 1, index + 2)
			painted = TRUE
		if(painted)
			grids[direction] = jointext(cells, "")
	if(!length(grids))
		return list("drawing" = null)
	var/list/directions = list()
	for(var/direction in grids)
		directions[direction] = custom_sprite_encode_grid(grids[direction], length(palette), width * 32)
	return list("drawing" = list("version" = custom_sprite_version(width, length(palette)), "palette" = palette, "tint" = null, "dirs" = directions, "emissive" = custom_sprite_emissive_settings(emissive)))
