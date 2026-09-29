/**
 * What the page draws over the character preview's drawing, because a flatten leaves it out: the rows tg's height
 * filters move, and the mob's transform (body size). Takes the drawing's frame height and how far its tile sits above
 * the frame's bottom (the "y" the page gets). Returns the page's keys for them, left out when the mob has neither:
 *
 * - "rows": runs of the tile's columns, each list(first frame row, rows, first source row), counting rows from the
 *   frame's top; a source row of -1 leaves the run empty.
 * - "transform": list(a, b, c, d, e, f), the mob's matrix about its tile's centre with y upwards.
 *
 * The page applies both to the drawing it already has, so a new height or body size needs no new drawing.
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
 * on the tile and then moved by its own offset.
 */
/proc/character_preview_rows(atom/movable/body, frame_height, tile_y)
	var/list/maps
	var/lowest = 1
	var/highest = ICON_SIZE_Y
	for (var/list/filter_info as anything in body.filter_data)
		if (filter_info["type"] != "displace")
			continue
		var/list/map_rows = character_preview_map_rows(filter_info["icon"])
		var/size = filter_info["size"]
		if (!map_rows || filter_info["x"] || !isnum(size) || size != round(size))
			return null
		var/map_height = length(map_rows)
		var/bottom = 1 + (ICON_SIZE_Y - map_height) / 2 + filter_info["y"]
		if (bottom != round(bottom))
			return null
		LAZYADD(maps, list(list(map_rows, size, bottom)))
		lowest = min(lowest, bottom)
		highest = max(highest, bottom + map_height - 1)
	if (!maps)
		return null

	// Frame row + 1 -> the frame row it shows, or -1 for none.
	var/list/sources = new /list(frame_height)
	var/map_count = length(maps)
	for (var/frame_row in 0 to frame_height - 1)
		var/tile_row = frame_height - tile_y - frame_row
		var/source = tile_row
		if (tile_row >= lowest && tile_row <= highest)
			// The last filter samples first: its output row, then its input row, back to the flatten's own row.
			for (var/index in map_count to 1 step -1)
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
 * How a displacement map moves each of its rows, from the bottom: -1 when a row shows the row below, 1 the row above,
 * 0 itself. FALSE for a map that isn't a tile wide, or whose rows don't each move whole and as one. tg's heights use
 * a handful of shared maps, so each is read once.
 */
/proc/character_preview_map_rows(icon/map)
	if (!isicon(map))
		return FALSE
	var/static/alist/rows_by_map = alist()
	// Counted here, since length() walks an alist.
	var/static/maps_read = 0
	var/rows = rows_by_map[map]
	if (!isnull(rows))
		return rows
	// Something that made a new map every time mustn't fill the cache: start it again.
	if (++maps_read > 32)
		rows_by_map = alist()
		maps_read = 1
	rows = FALSE
	var/width = map.Width()
	if (width == ICON_SIZE_X)
		rows = list()
		for (var/y in 1 to map.Height())
			var/move = character_preview_map_pixel_move(map.GetPixel(1, y))
			if (isnull(move) || move != character_preview_map_pixel_move(map.GetPixel(width / 2, y)) || move != character_preview_map_pixel_move(map.GetPixel(width, y)))
				rows = FALSE
				break
			rows += move
	rows_by_map[map] = rows
	return rows

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
