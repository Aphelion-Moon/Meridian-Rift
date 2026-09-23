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
	// Painted pixels outside changed bounds may be moved back in; their destinations are still checked.
	for(var/y in top to bottom)
		for(var/x in left to right)
			var/color = frame[y + 1][x + 1]
			if(istext(color) && !(length(color) == 9 && endswith(color, "00")))
				if(!is_point_allowed(x + dx, y + dy, direction))
					return FALSE
				changes["[x],[y]"] = list(x, y, color, "#00000000")
	for(var/y in top to bottom)
		for(var/x in left to right)
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
	/// Opaque brush colors available to this workspace.
	var/list/palette
	/// Direction -> inclusive rectangle of editable pixels.
	var/list/draw_bounds
	/// Direction -> limb silhouette rows, or null for rectangular bounds.
	var/list/draw_mask
	/// Set while an eraser stroke is validated, so already-painted pixels outside the bounds can be removed.
	var/erasing = FALSE
	/// The editor this workspace belongs to, so view locks are checked as they are now.
	var/datum/weakref/owner_ref
	/// Legacy drawing multiplier retained until it is baked into the palette.
	var/tint
	/// Direction -> whether this drawing emits instead of blocking light.
	var/list/emissive
	/// The whitelisted base hair look this draft belongs to. Null for markings.
	var/list/hair_context
	/// Ordered native marking records for this zone; null when this workspace has no base markings.
	var/list/markings_context
	/// Direction -> whether that canvas currently contains paint.
	var/list/edited_directions = list()
	/// Serialized pixels are immutable until the next edit; appearance settings only replace metadata.
	var/list/drawing_cache
	/// Whether serialization must rebuild the cached pixel payload.
	var/pixels_dirty = TRUE

/datum/sprite_editor_workspace/custom_sprite/New(list/drawing, list/sampled_palette, list/bounds, list/mask, canvas_width = null)
	..(max(custom_sprite_width(drawing), canvas_width == CUSTOM_SPRITE_TAUR_WIDTH ? CUSTOM_SPRITE_TAUR_WIDTH : 32), 32, 4, null, SPRITE_EDITOR_COLOR_MODE_RGB, SPRITE_EDITOR_ALLOW_UNDO, SPRITE_EDITOR_TOOL_PENCIL | SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_BUCKET | SPRITE_EDITOR_TOOL_DROPPER | SPRITE_EDITOR_TOOL_SELECT, "#00000000")
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
				combined |= LOWER_TEXT(copytext(color, 1, 8))
			for(var/list/point as anything in transaction["points"])
				var/old_color = point[3]
				if(!endswith(old_color, "00"))
					combined |= LOWER_TEXT(copytext(old_color, 1, 8))
			for(var/direction in transaction["replaced"])
				for(var/list/point as anything in transaction["replaced"][direction])
					for(var/replaced_color in list(point[3], point[4]))
						if(!endswith(replaced_color, "00"))
							combined |= LOWER_TEXT(copytext(replaced_color, 1, 8))
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
	var/list/pixels = list()
	for(var/direction in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		var/list/frame = layers[1]["data"][direction]
		for(var/list/row as anything in frame)
			pixels |= row
	var/list/colors = list()
	for(var/pixel in pixels)
		if(istext(pixel) && !endswith(pixel, "00"))
			colors |= LOWER_TEXT(copytext(pixel, 1, 8))
	return colors

/datum/sprite_editor_workspace/custom_sprite/proc/validate_palette_color(datum/source, color)
	SIGNAL_HANDLER
	if(!(LOWER_TEXT(copytext(color, 1, 8)) in palette))
		return COLOR_IS_INVALID

/datum/sprite_editor_workspace/custom_sprite/is_point_allowed(x, y, direction)
	if(!..())
		return FALSE
	if(erasing && is_painted(x, y, direction))
		return TRUE
	if(!isnull(draw_bounds))
		var/list/bounds = draw_bounds[direction]
		if(!bounds || x < bounds[1] || y < bounds[2] || x > bounds[3] || y > bounds[4])
			return FALSE
	if(isnull(draw_mask))
		return TRUE
	var/list/rows = draw_mask[direction]
	return rows && copytext(rows[y + 1], x + 1, x + 2) == "1"

/**
 * Drops paint outside the current bounds and mask.
 *
 * Markings clip to the body, so paint left outside by a changed body or zone is removed instead of
 * kept. This is a cleanup pass, not an edit: it is not added to the undo history.
 *
 * Returns TRUE when pixels were removed.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/clip_to_allowed()
	var/changed = FALSE
	for(var/direction in layers[1]["data"])
		var/list/frame = layers[1]["data"][direction]
		var/direction_changed = FALSE
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				if(endswith(frame[y][x], "00") || is_point_allowed(x - 1, y - 1, direction))
					continue
				frame[y][x] = "#00000000"
				direction_changed = TRUE
		if(direction_changed)
			update_edited_direction(direction)
			changed = TRUE
	if(changed)
		pixels_dirty = TRUE
	return changed

/datum/sprite_editor_workspace/custom_sprite/proc/is_painted(x, y, direction)
	var/list/frame = layers[1]["data"][direction]
	var/color = frame?[y + 1][x + 1]
	return istext(color) && !endswith(color, "00")

/// Existing paint left outside changed bounds can always be erased; new paint stays inside.
/datum/sprite_editor_workspace/custom_sprite/new_transaction(transaction)
	// A mirror can be picked up or dropped between strokes.
	var/datum/custom_sprite_editor/editor = owner_ref?.resolve()
	editor?.sync_locked_views(push = FALSE)
	erasing = islist(transaction) && transaction["type"] == "eraser"
	. = ..()
	erasing = FALSE
	trim_history()

#define CUSTOM_SPRITE_MAX_UNDO 100

/// Keeps the undo history within CUSTOM_SPRITE_MAX_UNDO steps, dropping the oldest first.
/datum/sprite_editor_workspace/custom_sprite/proc/trim_history()
	if(length(undo_stack) > CUSTOM_SPRITE_MAX_UNDO)
		undo_stack.Cut(1, 2)
		undo_names.Cut(1, 2)

#undef CUSTOM_SPRITE_MAX_UNDO

/// Treat masked pixels as fill boundaries, so disconnected parts do not fill through the backdrop.
/datum/sprite_editor_workspace/custom_sprite/preprocess_new_transaction(list/transaction)
	if(transaction["type"] != "bucket" || !draw_mask)
		return ..()
	var/direction = transaction["dir"]
	var/list/list/frame = layers[transaction["layer"]]["data"][direction]
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
	if(transaction["type"] == "replace")
		apply_replacement(transaction, TRUE)
		return
	..()
	pixels_dirty = TRUE
	update_edited_direction(transaction["dir"])

/datum/sprite_editor_workspace/custom_sprite/reverse_transact(list/transaction)
	if(transaction["type"] == "replace")
		apply_replacement(transaction, FALSE)
		return
	..()
	pixels_dirty = TRUE
	update_edited_direction(transaction["dir"])

/// Explicit saved tints already render as a separate overlay: bake their RGB into literal colors.
/datum/sprite_editor_workspace/custom_sprite/proc/bake_tint()
	if(!tint || tint == "#ffffff")
		return
	var/list/colors = list()
	for(var/color in palette)
		colors["[color]ff"] = "[custom_sprite_tint_color(color, tint)]ff"
	for(var/direction in layers[1]["data"])
		var/list/frame = layers[1]["data"][direction]
		for(var/list/row as anything in frame)
			for(var/x in 1 to length(row))
				if(colors[row[x]])
					row[x] = colors[row[x]]
	tint = "#ffffff"
	pixels_dirty = TRUE
	palette = used_colors()

/**
 * Replaces every view, emission setting and native base look as one undoable action.
 *
 * The caller has already validated the drawing for this destination, so this bypasses the
 * per-stroke bounds checks. Colors needed by the replacement and by undo history share the
 * normal 63-color limit.
 *
 * Arguments:
 * - drawing: Canonical drawing, or null for empty art.
 * - new_hair_context: The base hair look that goes with it.
 * - name: The undo history label.
 * - keep_legacy_tint: Hair drawings without an explicit tint keep the old hair-color filter.
 * - new_markings_context: Ordered native markings, an empty list to clear, or null to keep them.
 *
 * Returns:
 * - TRUE: Replaced, or already identical.
 * - FALSE: The drawing is too wide or combined colors would exceed the limit. Nothing changed.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/replace_drawing(list/drawing, list/new_hair_context, name, keep_legacy_tint = FALSE, list/new_markings_context)
	if(isnull(new_markings_context))
		new_markings_context = markings_context
	if(drawing)
		drawing = custom_sprite_resize_drawing(drawing, width)
		if(!drawing)
			return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/replacement = new(drawing, list(), null, null, width)
	replacement.bake_tint()
	if(!drawing || !keep_legacy_tint)
		replacement.tint = "#ffffff"
	var/list/replaced = list()
	var/changed = json_encode(hair_context) != json_encode(new_hair_context) || json_encode(markings_context) != json_encode(new_markings_context) || json_encode(emissive) != json_encode(replacement.emissive) || tint != replacement.tint
	for(var/direction in layers[1]["data"])
		var/list/old_frame = layers[1]["data"][direction]
		var/list/new_frame = replacement.layers[1]["data"][direction]
		var/list/points = list()
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/old_color = old_frame[y][x]
				var/new_color = new_frame[y][x]
				if(old_color != new_color && !(endswith(old_color, "00") && endswith(new_color, "00")))
					points += list(list(x - 1, y - 1, old_color, new_color))
		if(length(points))
			replaced[direction] = points
			changed = TRUE
	var/list/transaction = list("type" = "replace", "name" = name, "replaced" = replaced, "hair_old" = hair_context, "hair_new" = new_hair_context, "emissive_old" = emissive, "emissive_new" = replacement.emissive, "tint_old" = tint, "tint_new" = replacement.tint)
	transaction["markings_old"] = markings_context
	transaction["markings_new"] = new_markings_context
	qdel(replacement)
	if(!changed)
		return TRUE
	var/list/previous_palette = palette
	transact(transaction)
	undo_stack += list(transaction)
	undo_names += name
	if(!update_palette(list()))
		pop(undo_names)
		pop(undo_stack)
		reverse_transact(transaction)
		palette = previous_palette
		return FALSE
	redo_stack.Cut()
	redo_names.Cut()
	trim_history()
	return TRUE

/datum/sprite_editor_workspace/custom_sprite/proc/apply_replacement(list/transaction, forward)
	for(var/direction in transaction["replaced"])
		var/list/frame = layers[1]["data"][direction]
		for(var/list/point as anything in transaction["replaced"][direction])
			frame[point[2] + 1][point[1] + 1] = forward ? point[4] : point[3]
		update_edited_direction(direction)
	hair_context = forward ? transaction["hair_new"] : transaction["hair_old"]
	markings_context = forward ? transaction["markings_new"] : transaction["markings_old"]
	emissive = forward ? transaction["emissive_new"] : transaction["emissive_old"]
	tint = forward ? transaction["tint_new"] : transaction["tint_old"]
	pixels_dirty = TRUE

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
	var/list/pixel_indices = list()
	var/list/saved_palette = used_colors()
	if(!length(saved_palette) || length(saved_palette) > CUSTOM_SPRITE_MAX_COLORS)
		return null
	for(var/i in 1 to length(saved_palette))
		indices[saved_palette[i]] = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, i + 1, i + 2)
	for(var/direction in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		var/list/frame = layers[1]["data"][direction]
		var/list/pixels = list()
		for(var/list/row as anything in frame)
			for(var/pixel in row)
				var/index = istext(pixel) ? pixel_indices[pixel] : "0"
				if(!index)
					index = !endswith(pixel, "00") ? indices[LOWER_TEXT(copytext(pixel, 1, 8))] : null
					pixel_indices[pixel] = index || "0"
				pixels += index || "0"
		directions[direction] = custom_sprite_encode_grid(jointext(pixels, ""), length(saved_palette), width * height)
	drawing_cache = list("version" = custom_sprite_version(width, length(saved_palette)), "palette" = saved_palette, "tint" = tint, "dirs" = directions, "emissive" = emissive)
	return drawing_cache

/// An explicit clear erases the whole view, including pixels outside the current body bounds.
/datum/sprite_editor_workspace/custom_sprite/proc/clear_direction(direction)
	if(!istext(direction) || !edited_directions[direction])
		return FALSE
	var/list/points = list()
	var/list/frame = layers[1]["data"][direction]
	for(var/y in 0 to height - 1)
		for(var/x in 0 to width - 1)
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
