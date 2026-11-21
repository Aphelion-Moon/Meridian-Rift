/**
 * What the page draws over the character preview's drawing, because a flatten leaves it out: the rows tg's height
 * filters move, and the mob's transform (body size). Takes the drawing's frame height and how far its tile sits above
 * the frame's bottom (the "y" the page gets). Returns the page's keys for them, left out when the mob has neither:
 *
 * - "rows": runs of the tile's columns, each list(first frame row, rows, first source row), counting rows from the
 *   frame's top; a source row of -1 leaves the run empty.
 * - "transform": list(a, b, c, d, e, f), the mob's matrix about its tile's centre with y upwards.
 *
 * The page applies both to the drawing it already has, so a new height or body size needs no new drawing. The rows are
 * a body's that stretches in one piece; one that stretches each image, as a taur does to keep its body its size, has
 * its height drawn in by the flatten (character_preview_flat_height()).
 */
/proc/character_preview_effects(mob/living/carbon/human/body, frame_height, tile_y)
	. = list()
	var/matrix/transform = body.transform
	var/list/matrix = list(transform.a, transform.b, transform.c, transform.d, transform.e, transform.f)
	// Growing a body and shrinking it back leaves a trace of float error: a whole number that close is meant.
	for (var/index in 1 to 6)
		var/whole = round(matrix[index], 1)
		if (abs(matrix[index] - whole) < 0.0001)
			matrix[index] = whole
	if (matrix[1] != 1 || matrix[2] || matrix[3] || matrix[4] || matrix[5] != 1 || matrix[6])
		.["transform"] = matrix
	var/list/rows = character_preview_rows(body, frame_height, tile_y)
	if (rows)
		.["rows"] = rows

/**
 * The runs of frame rows that the mob's displacement filters move, as character_preview_effects() gives them, or
 * null if there are none or one moves more than whole rows. Filters run in the order tg keeps them, each map centred
 * on the tile and then moved by its own offset. The page moves the tile's columns, so each map must cover them.
 */
/proc/character_preview_rows(atom/movable/body, frame_height, tile_y)
	// A body's maps are a height's shared ones, and frames come in a few sizes: each set is worked out once.
	var/key = "[frame_height]|[tile_y]"
	for (var/list/filter_info as anything in body.filter_data)
		if (filter_info["type"] == "displace")
			key += "|[REF(filter_info["icon"])],[filter_info["x"]],[filter_info["y"]],[filter_info["size"]]"
	if (length(key) == length("[frame_height]|[tile_y]"))
		return null
	var/static/alist/runs_by_key = alist()
	// Counted here, since length() walks an alist.
	var/static/keys_kept = 0
	var/runs = runs_by_key[key]
	if (isnull(runs))
		if (++keys_kept > 64)
			runs_by_key = alist()
			keys_kept = 1
		runs = character_preview_body_rows(body.filter_data, frame_height, tile_y) || FALSE
		runs_by_key[key] = runs
	return runs || null

/// character_preview_rows() worked out from the body's filter_data, uncached.
/proc/character_preview_body_rows(list/filter_data, frame_height, tile_y)
	var/list/maps
	var/lowest = 1
	var/highest = ICON_SIZE_Y
	for (var/list/filter_info as anything in filter_data)
		if (filter_info["type"] != "displace")
			continue
		var/list/map = character_preview_height_map(filter_info["icon"], filter_info["x"], filter_info["y"], filter_info["size"])
		if (!map || map[4] > 1 || map[5] < ICON_SIZE_X)
			return null
		LAZYADD(maps, list(map))
		lowest = min(lowest, map[3])
		highest = max(highest, map[3] + length(map[1]) - 1)
	if (!maps)
		return null

	// Frame row + 1 -> the frame row it shows, or -1 for none.
	var/list/sources = new /list(frame_height)
	for (var/frame_row in 0 to frame_height - 1)
		var/tile_row = frame_height - tile_y - frame_row
		var/source = tile_row
		if (tile_row >= lowest && tile_row <= highest)
			// The last filter samples first: its output row, then its input row, back to the flatten's own row.
			for (var/index in length(maps) to 1 step -1)
				var/list/map = maps[index]
				var/list/map_rows = map[1]
				var/map_row = source - map[3] + 1
				if (map_row >= 1 && map_row <= length(map_rows))
					source += map_rows[map_row] * map[2]
		var/source_row = frame_row + tile_row - source
		sources[frame_row + 1] = (source_row >= 0 && source_row < frame_height) ? source_row : -1

	var/list/runs
	var/frame_row = 0
	while (frame_row < frame_height)
		var/source_row = sources[frame_row + 1]
		if (source_row == frame_row)
			frame_row++
			continue
		// A run carries on while each row shows the row after the last one's, or while they stay empty.
		var/last = frame_row
		while (last + 1 < frame_height)
			var/next_source = sources[last + 2]
			if (source_row == -1 ? next_source != -1 : next_source != source_row + last + 1 - frame_row)
				break
			last++
		LAZYADD(runs, list(list(frame_row, last - frame_row + 1, source_row)))
		frame_row = last + 1
	return runs

/**
 * How a displacement map moves each of its rows, and how wide it is: list(moves, width), the moves from the bottom, -1
 * when a row shows the row below, 1 the row above, 0 itself. FALSE for a map whose rows don't each move whole and as
 * one. tg's heights use a handful of shared maps, tiled three wide (wide_height_map()), so each is read once.
 */
/proc/character_preview_map_rows(icon/map)
	if (!isicon(map))
		return FALSE
	var/static/alist/rows_by_map = alist()
	// Counted here, since length() walks an alist.
	var/static/maps_read = 0
	var/reading = rows_by_map[map]
	if (!isnull(reading))
		return reading
	// Something that made a new map every time mustn't fill the cache: start it again.
	if (++maps_read > 32)
		rows_by_map = alist()
		maps_read = 1
	// A filter hands its map back as a resource, which has no pixels to read until it is an icon.
	var/icon/pixels = icon(map)
	var/width = pixels.Width()
	var/list/rows = list()
	reading = list(rows, width)
	for (var/y in 1 to pixels.Height())
		var/move = character_preview_map_pixel_move(pixels.GetPixel(1, y))
		if (isnull(move) || move != character_preview_map_pixel_move(pixels.GetPixel(width / 2, y)) || move != character_preview_map_pixel_move(pixels.GetPixel(width, y)))
			reading = FALSE
			break
		rows += move
	rows_by_map[map] = reading
	return reading

/**
 * A height map as it lies on an image `width` by `height`, centred on it and then moved by the filter's own offset:
 * list(its rows' moves as character_preview_map_rows() gives them, size, its bottom row, its left column, its right
 * column), in the image's own pixels from its lower left (1, 1). Null for a map that moves more than whole rows.
 */
/proc/character_preview_height_map(icon/map, x, y, size, width = ICON_SIZE_X, height = ICON_SIZE_Y)
	var/list/reading = character_preview_map_rows(map)
	if (!reading || !isnum(size) || size != round(size))
		return null
	var/list/map_rows = reading[1]
	var/bottom = 1 + (height - length(map_rows)) / 2 + y
	var/left = 1 + (width - reading[2]) / 2 + x
	if (bottom != round(bottom) || left != round(left))
		return null
	return list(map_rows, size, bottom, left, left + reading[2] - 1)

/**
 * A flat icon with the height filters of the image it was drawn from drawn in, as the game draws a body that
 * stretches each of its images: each row its maps move shows the row they take it from, across the columns they cover.
 * get_flat_uni_icon() calls it, when the preview asks (character_preview_flatten()), for an image below the one it
 * flattens, with the image's own icon, or with all of it when it keeps its overlays together, as far as BYOND's filters
 * reach. The look's own filters are the page's; see character_preview_rows().
 *
 * Returns `flat` as it was when the image has no height filters, or one moves more than whole rows.
 *
 * Arguments:
 * - flat: The image's flat icon, its canvas from the image's own lower left pixel; see character_preview_flat_box().
 * - drawn: The image, its filters read from it.
 * - drawn_icon: The icon it draws, which its maps are centred on. Null for a tile's.
 */
/proc/character_preview_flat_height(datum/universal_icon/flat, image/drawn, icon/drawn_icon)
	var/list/filters = drawn.filters
	if (!flat || !length(filters))
		return flat
	var/list/box = character_preview_flat_box(flat)
	var/list/icon_size = drawn_icon ? get_icon_dimensions(drawn_icon) : null
	// A body's images share a height's maps, and mostly their size: what to move is worked out once for each.
	var/key = "[box[1]],[box[2]],[box[3]],[box[4]]|[icon_size?["width"] || ICON_SIZE_X],[icon_size?["height"] || ICON_SIZE_Y]"
	var/list/height_filters
	for (var/dm_filter/height_filter as anything in filters)
		if (height_filter.type == "displace")
			key += "|[REF(height_filter.icon)],[height_filter.x],[height_filter.y],[height_filter.size]"
			LAZYADD(height_filters, height_filter)
	if (!height_filters)
		return flat
	var/static/alist/plans = alist()
	// Counted here, since length() walks an alist.
	var/static/plans_kept = 0
	var/list/plan = plans[key]
	if (isnull(plan))
		if (++plans_kept > 256)
			plans = alist()
			plans_kept = 1
		plan = character_preview_height_plan(height_filters, icon_size, box) || FALSE
		plans[key] = plan
	if (!plan)
		return flat

	// A sprite only coloured is stretched bare and coloured once after, so each band copies the sprite alone.
	var/list/colours = character_preview_clear_colours(flat)
	var/datum/universal_icon/stretched = flat
	if (colours)
		stretched = new /datum/universal_icon(flat.icon_file, flat.icon_state, flat.dir, flat.frame)

	// The bands that move are copies taken first; the flat itself, grown to the new rows, keeps the rows that don't.
	var/lowest = plan[1]
	var/highest = plan[2]
	var/left = plan[3] - box[1] + 1
	var/right = plan[4] - box[1] + 1
	var/list/moved = plan[5]
	var/list/pieces = list()
	for (var/list/band as anything in moved)
		var/datum/universal_icon/piece = stretched.copy()
		piece.crop(left, band[1] - box[2] + 1, right, band[2] - box[2] + 1)
		pieces += piece
	stretched.crop(1, lowest - box[2] + 1, box[3], highest - box[2] + 1)
	for (var/list/rows as anything in plan[6])
		stretched.draw_box("#00000000", left, rows[1] - lowest + 1, right, rows[2] - lowest + 1)
	for (var/index in 1 to length(pieces))
		stretched.blend_icon(pieces[index], ICON_OVERLAY, left, moved[index][3] - lowest + 1)
	if (length(colours))
		stretched.transform.transforms += colours
	stretched.flat_x1 = box[1]
	stretched.flat_y1 = lowest
	stretched.flat_width = box[3]
	stretched.flat_height = highest - lowest + 1
	return stretched

/**
 * A flat icon's own transforms, when they are all colours that leave a clear pixel clear (a multiply, or a colour
 * matrix with no alpha of its own), so it can be stretched bare and coloured after: the rows a stretch adds and clears
 * stay clear either way. An empty list for a bare sprite; null for anything else, like a flat with overlays drawn in.
 */
/proc/character_preview_clear_colours(datum/universal_icon/flat)
	var/list/transforms = flat.transform?.transforms
	if (!length(transforms))
		return list()
	for (var/list/transform as anything in transforms)
		switch (transform["type"])
			if (RUSTG_ICONFORGE_BLEND_COLOR)
				if (transform["blend_mode"] != ICON_MULTIPLY)
					return null
			if (RUSTG_ICONFORGE_MAP_COLORS)
				if (transform["a0"])
					return null
			else
				return null
	return transforms

/**
 * What character_preview_flat_height() moves for an image's height filters on a canvas `box`, counted as
 * character_preview_flat_box() counts it: list(the lowest row drawn, the highest, the maps' left column, their right
 * column, the moved runs, each list(bottom row, top row, the row its bottom lands on), and the runs of the canvas's own
 * rows to clear under them, each list(bottom row, top row)). Null for maps that move more than whole rows, or move
 * columns of their own, or nothing on the canvas.
 *
 * Arguments:
 * - height_filters: The image's displacement filters, in the order they apply.
 * - icon_size: The size of the icon they're centred on, as get_icon_dimensions() gives it. Null for a tile's.
 * - box: The image's canvas, as character_preview_flat_box() gives it.
 */
/proc/character_preview_height_plan(list/height_filters, list/icon_size, list/box)
	var/list/maps
	var/reach = 0
	for (var/dm_filter/height_filter as anything in height_filters)
		var/list/map = character_preview_height_map(height_filter.icon, height_filter.x, height_filter.y, height_filter.size, icon_size?["width"] || ICON_SIZE_X, icon_size?["height"] || ICON_SIZE_Y)
		// Maps of their own columns would need the rows moved column by column. tg's heights share theirs.
		if (!map || (maps && (map[4] != maps[1][4] || map[5] != maps[1][5])))
			return null
		LAZYADD(maps, list(map))
		reach += map[2]
	var/flat_x2 = box[1] + box[3] - 1
	var/flat_y2 = box[2] + box[4] - 1
	var/left = max(box[1], maps[1][4])
	var/right = min(flat_x2, maps[1][5])
	if (left > right)
		return null

	// Row -> the flat's row it shows, or null. The last filter samples first: its output row, then its input row.
	var/list/sources = alist()
	var/lowest
	var/highest
	for (var/row in box[2] - reach to flat_y2 + reach)
		var/source = row
		for (var/index in length(maps) to 1 step -1)
			var/list/map = maps[index]
			var/map_row = source - map[3] + 1
			if (map_row >= 1 && map_row <= length(map[1]))
				source += map[1][map_row] * map[2]
		if (source < box[2] || source > flat_y2)
			continue
		sources[row] = source
		if (isnull(lowest))
			lowest = row
		highest = row
	if (isnull(lowest))
		return null

	// Each run of rows that shows a run of the flat's rows from elsewhere, one after another. What the maps don't
	// cover, and rows that show themselves, stay where they are.
	var/list/moved = list()
	var/run_start = lowest
	for (var/row in lowest to highest + 1)
		var/source = sources[row]
		var/run_source = sources[run_start]
		if (row <= highest && !isnull(source) && !isnull(run_source) && source - row == run_source - run_start)
			continue
		if (!isnull(run_source) && run_source != run_start)
			moved += list(list(run_source, run_source + row - run_start - 1, run_start))
		run_start = row
	// The flat's own rows that now show another row, or none, are cleared under the moved runs.
	var/list/clears = list()
	var/clear_start
	for (var/row in box[2] to flat_y2 + 1)
		var/cleared = row <= flat_y2 && sources[row] != row
		if (cleared && isnull(clear_start))
			clear_start = row
		else if (!cleared && !isnull(clear_start))
			clears += list(list(clear_start, row - 1))
			clear_start = null
	if (!length(moved) && !length(clears))
		return null
	return list(lowest, highest, left, right, moved, clears)

/// How one displacement map pixel moves its row: -1, 0 or 1 as character_preview_map_rows() has them, or null when it
/// moves it sideways or by part of a pixel.
/proc/character_preview_map_pixel_move(pixel)
	if (!pixel)
		return 0
	var/list/channels = rgb2num(pixel)
	if (length(channels) > 3 && !channels[4])
		return 0
	if (channels[1] != 127 && channels[1] != 128)
		return null
	switch (channels[2])
		if (255)
			return -1
		if (0)
			return 1
		if (127, 128)
			return 0
	return null
