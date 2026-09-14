/// Shared point validation and the extension point for consumer-specific drawing bounds.
/datum/sprite_editor_workspace/proc/valid_point_pair(list/point)
	return islist(point) && length(point) == 2 && isnum(point[1]) && isnum(point[2]) && round(point[1]) == point[1] && round(point[2]) == point[2]

/datum/sprite_editor_workspace/proc/is_point_allowed(x, y, direction)
	return x >= 0 && x < width && y >= 0 && y < height

/// Build an immutable old/new pixel patch before modifying the frame, including overlapping moves.
/datum/sprite_editor_workspace/proc/prepare_selection_move(list/transaction)
	var/direction = transaction["dir"]
	if(!istext(direction) || !(direction in layers[transaction["layer"]]["data"]))
		return FALSE
	var/list/rect = transaction["rect"]
	var/list/offset = transaction["offset"]
	if(!islist(rect) || length(rect) != 4 || !valid_point_pair(offset))
		return FALSE
	for(var/coordinate in rect)
		if(!isnum(coordinate) || round(coordinate) != coordinate)
			return FALSE
	var/left = rect[1]
	var/top = rect[2]
	var/right = rect[3]
	var/bottom = rect[4]
	var/dx = offset[1]
	var/dy = offset[2]
	if(left < 0 || top < 0 || right >= width || bottom >= height || right < left || bottom < top || abs(dx) >= width || abs(dy) >= height || (!dx && !dy))
		return FALSE
	// The box may include shaded margins; only its painted pixels must stay in the drawing area.
	if(left + dx < 0 || top + dy < 0 || right + dx >= width || bottom + dy >= height)
		return FALSE
	var/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/changes = list()
	for(var/y in top to bottom)
		for(var/x in left to right)
			if(!is_point_allowed(x, y, direction))
				continue
			var/color = frame[y + 1][x + 1]
			if(istext(color) && !(length(color) == 9 && endswith(color, "00")))
				if(!is_point_allowed(x + dx, y + dy, direction))
					return FALSE
				changes["[x],[y]"] = list(x, y, color, "#00000000")
	for(var/y in top to bottom)
		for(var/x in left to right)
			if(!is_point_allowed(x, y, direction))
				continue
			var/color = frame[y + 1][x + 1]
			if(!istext(color) || (length(color) == 9 && endswith(color, "00")))
				continue
			var/destination_x = x + dx
			var/destination_y = y + dy
			var/key = "[destination_x],[destination_y]"
			var/list/change = changes[key]
			if(change)
				change[4] = color
			else
				changes[key] = list(destination_x, destination_y, frame[destination_y + 1][destination_x + 1], color)
	var/list/points = list()
	for(var/key in changes)
		var/list/change = changes[key]
		if(change[3] != change[4])
			points += list(change)
	transaction["points"] = points
	return length(points) > 0

/datum/sprite_editor_workspace/custom_sprite
	var/list/palette
	var/list/draw_bounds
	var/list/draw_mask
	var/tint
	var/list/emissive
	var/list/edited_directions = list()
	/// Serialized pixels are immutable until the next edit; appearance settings only replace metadata.
	var/list/drawing_cache
	var/pixels_dirty = TRUE

/datum/sprite_editor_workspace/custom_sprite/New(list/drawing, list/sampled_palette, list/bounds, list/mask)
	..(32, 32, 4, null, SPRITE_EDITOR_COLOR_MODE_RGB, SPRITE_EDITOR_ALLOW_UNDO, SPRITE_EDITOR_TOOL_PENCIL | SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_BUCKET | SPRITE_EDITOR_TOOL_DROPPER | SPRITE_EDITOR_TOOL_SELECT, "#00000000")
	palette = list()
	tint = drawing?["tint"]
	emissive = custom_sprite_emissive_settings(drawing?["emissive"])
	draw_bounds = bounds
	draw_mask = mask
	RegisterSignal(src, COMSIG_SPRITE_EDITOR_VALIDATE_COLOR, PROC_REF(validate_palette_color))
	custom_sprite_hydrate(src, drawing)
	for(var/direction in layers[1]["data"])
		update_edited_direction(direction)
	palette = used_colors()
	update_palette(sampled_palette)

/// Keep current and undoable pixels paintable while replacing unused sample/account colors.
/datum/sprite_editor_workspace/custom_sprite/proc/update_palette(list/available_palette)
	var/list/combined = used_colors()
	for(var/list/stack as anything in list(undo_stack, redo_stack))
		for(var/list/transaction as anything in stack)
			var/color = transaction["color"]
			if(color)
				combined |= lowertext(copytext(color, 1, 8))
			for(var/list/point as anything in transaction["points"])
				var/old_color = point[3]
				if(!endswith(old_color, "00"))
					combined |= lowertext(copytext(old_color, 1, 8))
	for(var/raw_color in available_palette)
		var/color = custom_sprite_color(raw_color)
		if(!color)
			return FALSE
		combined |= color
	if(length(combined) > CUSTOM_SPRITE_MAX_COLORS)
		return FALSE
	palette = combined
	return TRUE

/datum/sprite_editor_workspace/custom_sprite/proc/used_colors()
	var/list/colors = list()
	for(var/direction in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		var/list/frame = layers[1]["data"][direction]
		for(var/list/row as anything in frame)
			for(var/pixel in row)
				if(istext(pixel) && !endswith(pixel, "00"))
					colors |= lowertext(copytext(pixel, 1, 8))
	return colors

/datum/sprite_editor_workspace/custom_sprite/proc/validate_palette_color(datum/source, color)
	SIGNAL_HANDLER
	if(!(lowertext(copytext(color, 1, 8)) in palette))
		return COLOR_IS_INVALID

/datum/sprite_editor_workspace/custom_sprite/is_point_allowed(x, y, direction)
	if(!..())
		return FALSE
	if(!isnull(draw_bounds))
		var/list/bounds = draw_bounds[direction]
		if(!bounds || x < bounds[1] || y < bounds[2] || x > bounds[3] || y > bounds[4])
			return FALSE
	if(isnull(draw_mask))
		return TRUE
	var/list/rows = draw_mask[direction]
	return rows && copytext(rows[y + 1], x + 1, x + 2) == "1"

/datum/sprite_editor_workspace/custom_sprite/new_transaction(transaction)
	. = ..()
	if(length(undo_stack) > 100)
		undo_stack.Cut(1, 2)
		undo_names.Cut(1, 2)

/// Treat masked pixels as fill boundaries, so disconnected parts do not fill through the backdrop.
/datum/sprite_editor_workspace/custom_sprite/preprocess_new_transaction(list/transaction)
	if(transaction["type"] != "bucket" || !draw_mask)
		return ..()
	var/direction = transaction["dir"]
	var/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/masked = list()
	for(var/y in 0 to height - 1)
		var/list/row = frame[y + 1].Copy()
		for(var/x in 0 to width - 1)
			if(!is_point_allowed(x, y, direction))
				row[x + 1] = null
		masked += list(row)
	var/list/point = transaction["point"]
	transaction["points"] = flood_fill(masked, point[1] + 1, point[2] + 1, width, height)
	transaction -= "point"

/datum/sprite_editor_workspace/custom_sprite/transact(list/transaction)
	..()
	pixels_dirty = TRUE
	update_edited_direction(transaction["dir"])

/datum/sprite_editor_workspace/custom_sprite/reverse_transact(list/transaction)
	..()
	pixels_dirty = TRUE
	update_edited_direction(transaction["dir"])

/// Update only the affected direction, without serializing the drawing for its UI marker.
/datum/sprite_editor_workspace/custom_sprite/proc/update_edited_direction(direction)
	edited_directions[direction] = FALSE
	var/list/frame = layers[1]["data"][direction]
	for(var/list/row as anything in frame)
		for(var/pixel in row)
			if(!endswith(pixel, "00"))
				edited_directions[direction] = TRUE
				return

/datum/sprite_editor_workspace/custom_sprite/proc/serialize_drawing()
	if(!pixels_dirty)
		if(drawing_cache && (drawing_cache["tint"] != tint || drawing_cache["emissive"] != emissive))
			drawing_cache = drawing_cache.Copy()
			drawing_cache["tint"] = tint
			drawing_cache["emissive"] = emissive
		return drawing_cache
	pixels_dirty = FALSE
	drawing_cache = null
	var/list/directions = list()
	var/list/indices = list()
	var/list/saved_palette = used_colors()
	if(!length(saved_palette) || length(saved_palette) > CUSTOM_SPRITE_MAX_COLORS)
		return null
	for(var/i in 1 to length(saved_palette))
		indices[saved_palette[i]] = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, i + 1, i + 2)
	for(var/direction in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		var/list/frame = layers[1]["data"][direction]
		var/grid = ""
		for(var/list/row as anything in frame)
			for(var/pixel in row)
				var/index = istext(pixel) && !endswith(pixel, "00") ? indices[lowertext(copytext(pixel, 1, 8))] : null
				grid += index || "0"
		directions[direction] = custom_sprite_encode_grid(grid, length(saved_palette))
	drawing_cache = list("version" = length(saved_palette) > 15 ? 2 : 1, "palette" = saved_palette, "tint" = tint, "dirs" = directions, "emissive" = emissive)
	return drawing_cache

/// An explicit clear can erase old pixels outside the bounds of a newly selected hairstyle/body.
/datum/sprite_editor_workspace/custom_sprite/proc/clear_direction(direction)
	if(!istext(direction) || !edited_directions[direction])
		return FALSE
	var/list/points = list()
	var/list/frame = layers[1]["data"][direction]
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(!endswith(frame[y + 1][x + 1], "00"))
				points += list(list(x, y))
	if(!length(points))
		return FALSE
	var/list/previous_bounds = draw_bounds
	var/list/previous_mask = draw_mask
	draw_bounds = null
	draw_mask = null
	. = new_transaction(list("type" = "eraser", "layer" = 1, "dir" = direction, "points" = points))
	draw_bounds = previous_bounds
	draw_mask = previous_mask

/// Keep only validated input; history metadata belongs to the server.
/datum/sprite_editor_workspace/proc/sanitize_transaction(list/input)
	var/list/transaction = list("type" = input["type"])
	if(input["type"] != "addLayer")
		transaction["layer"] = input["layer"]
	switch(input["type"])
		if("pencil", "eraser", "bucket")
			transaction["dir"] = input["dir"]
			if(input["type"] != "eraser")
				transaction["color"] = input["color"]
			if(input["type"] == "bucket")
				transaction["point"] = input["point"]
			else
				transaction["points"] = input["points"]
		if("renameLayer")
			transaction["newName"] = input["newName"]
		if("move")
			transaction["dir"] = input["dir"]
			transaction["points"] = input["points"]
	var/static/list/transaction_names = list("pencil" = "Pencil", "eraser" = "Eraser", "bucket" = "Flood Fill", "move" = "Move selection", "renameLayer" = "Rename Layer", "moveLayerUp" = "Move Layer Up", "moveLayerDown" = "Move Layer Down", "flattenLayer" = "Flatten Layer", "addLayer" = "Add Layer", "deleteLayer" = "Delete Layer")
	transaction["name"] = transaction_names[transaction["type"]]
	return transaction
