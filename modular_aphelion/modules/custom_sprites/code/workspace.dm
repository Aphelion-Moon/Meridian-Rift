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
	if(!isnull(transaction["codes"]))
		return prepare_selection_placement(transaction)
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
	for(var/_key, change in changes)
		if(change[3] != change[4])
			points += list(change)
	transaction["points"] = points
	return length(points) > 0

/**
 * Validates a selection the window placed itself: pasted, turned, cut down to a mask, or dropped
 * after hanging off the canvas.
 *
 * The window sends the box around every pixel that changes (`area`), the new pixel values used in
 * it (`palette`), and the box row by row as `digits` characters per pixel (`codes`): an index into
 * the values in CUSTOM_SPRITE_INDEX_ALPHABET, or dots where the pixel stays as it is. That keeps a
 * large paste within one small message. Transparent values lift paint away.
 *
 * Lifted pixels may come from anywhere on the canvas, as a move's may. New paint follows the pencil's
 * rules, so any that lands outside the drawing area is dropped rather than refusing the rest.
 * Anything malformed refuses the whole placement.
 *
 * Returns TRUE when anything changes; `points` then holds each pixel's old and new color.
 */
/datum/sprite_editor_workspace/proc/prepare_selection_placement(list/transaction)
	var/list/area = transaction["area"]
	var/list/palette = transaction["palette"]
	var/digits = transaction["digits"]
	var/codes = transaction["codes"]
	if(!islist(area) || length(area) != 4 || !islist(palette) || !length(palette) || !(digits in list(1, 2)) || length(palette) > 64 ** digits || !istext(codes))
		return FALSE
	for(var/coordinate in area)
		if(!isnum(coordinate) || round(coordinate) != coordinate)
			return FALSE
	var/left = area[1]
	var/top = area[2]
	var/right = area[3]
	var/bottom = area[4]
	if(left < 0 || top < 0 || right >= width || bottom >= height || right < left || bottom < top || length(codes) != (right - left + 1) * (bottom - top + 1) * digits)
		return FALSE
	// Each value is checked once: transparent lifts paint away, anything else must be a color this drawing takes.
	var/list/values = list()
	for(var/raw_color in palette)
		if(!istext(raw_color))
			return FALSE
		var/color = LOWER_TEXT(raw_color)
		if(length(color) == 9 && endswith(color, "00"))
			color = "#00000000"
		else if(!is_valid_color(color))
			return FALSE
		else if(length(color) == 7)
			color += "ff"
		values += color
	var/list/index_values = custom_sprite_index_values()
	var/unchanged = digits == 1 ? "." : ".."
	var/direction = transaction["dir"]
	var/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/points = list()
	var/position = 1
	for(var/y in top to bottom)
		for(var/x in left to right)
			var/code = copytext(codes, position, position + digits)
			position += digits
			if(code == unchanged)
				continue
			var/index = 0
			for(var/character in 1 to digits)
				var/value = index_values[copytext(code, character, character + 1)]
				if(isnull(value))
					return FALSE
				index = index * 64 + value
			if(index >= length(values))
				return FALSE
			var/color = values[index + 1]
			if(color != "#00000000" && !is_point_allowed(x, y, direction))
				continue
			if(frame[y + 1][x + 1] != color)
				points += list(list(x, y, frame[y + 1][x + 1], color))
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
	/// Zone -> ordered native marking records on the whole-body canvas; null for hair.
	var/list/markings_context
	/// Direction -> whether that canvas currently contains paint.
	var/list/edited_directions = list()
	/// Serialized pixels are immutable until the next edit; appearance settings only replace metadata.
	var/list/drawing_cache
	/// Whether serialization must rebuild the cached pixel payload.
	var/pixels_dirty = TRUE
	/// History entries already applied when the draft was last saved.
	var/list/saved_transactions = list()
	/// Rotation markers of unsaved imports and restorations that fell off the end of the history.
	var/list/trimmed_rotations = list()
	/// Pixel value -> its code in the window's canvas.
	var/list/canvas_codes
	/// Every pixel value the window's canvas uses, in first-use order. Null until built.
	var/list/canvas_palette
	/// Direction -> that view as codes. A null entry is rebuilt on the next update.
	var/list/canvas_views
	/// Characters per pixel in canvas_views.
	var/canvas_digits = 1

/datum/sprite_editor_workspace/custom_sprite/New(list/drawing, list/sampled_palette, list/bounds, list/mask, canvas_width = null, canvas_height = null)
	..(max(custom_sprite_width(drawing), canvas_width == CUSTOM_SPRITE_TAUR_WIDTH ? CUSTOM_SPRITE_TAUR_WIDTH : 32), max(custom_sprite_height(drawing), canvas_height == CUSTOM_SPRITE_TALL_HEIGHT ? CUSTOM_SPRITE_TALL_HEIGHT : 32), 4, null, SPRITE_EDITOR_COLOR_MODE_RGB, SPRITE_EDITOR_ALLOW_UNDO, SPRITE_EDITOR_TOOL_PENCIL | SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_BUCKET | SPRITE_EDITOR_TOOL_DROPPER | SPRITE_EDITOR_TOOL_SELECT, "#00000000")
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

/// Colors the current and undoable pixels use, which must stay paintable.
/datum/sprite_editor_workspace/custom_sprite/proc/kept_colors()
	. = used_colors()
	// Pixel value -> TRUE once looked at: a long history repeats a few values thousands of times.
	var/list/seen = list()
	for(var/list/stack as anything in list(undo_stack, redo_stack))
		for(var/list/transaction as anything in stack)
			var/color = transaction["color"]
			if(color && !seen[color])
				seen[color] = TRUE
				. |= LOWER_TEXT(copytext(color, 1, 8))
			for(var/list/point as anything in transaction["points"])
				var/old_color = point[3]
				if(seen[old_color])
					continue
				seen[old_color] = TRUE
				if(!endswith(old_color, "00"))
					. |= LOWER_TEXT(copytext(old_color, 1, 8))
			for(var/_direction, points in transaction["replaced"])
				for(var/list/point as anything in points)
					for(var/replaced_color in list(point[3], point[4]))
						if(seen[replaced_color])
							continue
						seen[replaced_color] = TRUE
						if(!endswith(replaced_color, "00"))
							. |= LOWER_TEXT(copytext(replaced_color, 1, 8))

/**
 * Keeps current and undoable colors paintable, then admits available colors in order while there's room.
 *
 * Returns TRUE when every available color fit. When the kept colors alone need more than
 * CUSTOM_SPRITE_MAX_COLORS, or an available color is invalid, the palette is left alone.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/update_palette(list/available_palette)
	var/list/kept = kept_colors()
	if(length(kept) > CUSTOM_SPRITE_MAX_COLORS)
		return FALSE
	return admit_colors(kept, available_palette)

/// Sets the palette to the kept colors plus as many available ones, in order, as fit. Returns TRUE when all fit.
/datum/sprite_editor_workspace/custom_sprite/proc/admit_colors(list/kept, list/available_palette)
	. = TRUE
	var/list/combined = kept.Copy()
	for(var/raw_color in available_palette)
		var/color = custom_sprite_color(raw_color)
		if(!color)
			return FALSE
		if(color in combined)
			continue
		if(length(combined) >= CUSTOM_SPRITE_MAX_COLORS)
			. = FALSE
			continue
		combined += color
	palette = combined

/datum/sprite_editor_workspace/custom_sprite/proc/used_colors()
	var/list/colors = list()
	// Pixel value -> TRUE once looked at.
	var/list/seen = list()
	for(var/direction, frame in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		for(var/list/row as anything in frame)
			for(var/pixel in row)
				if(seen[pixel])
					continue
				seen[pixel] = TRUE
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
	// Windows send strokes as a compact mask; the history keeps point lists.
	if(islist(transaction) && ("mask" in transaction))
		transaction["points"] = custom_sprite_mask_points(transaction["mask"], width, height)
	. = ..()
	erasing = FALSE
	trim_history()

#define CUSTOM_SPRITE_MAX_UNDO 100

/// Keeps the undo history within CUSTOM_SPRITE_MAX_UNDO steps, dropping the oldest first.
/datum/sprite_editor_workspace/custom_sprite/proc/trim_history()
	if(length(undo_stack) > CUSTOM_SPRITE_MAX_UNDO)
		var/list/oldest = undo_stack[1]
		// An unsaved import that can no longer be undone still keeps the replaced style.
		if(oldest["rotate"] && !(oldest in saved_transactions))
			trimmed_rotations |= oldest["rotate"]
		undo_stack.Cut(1, 2)
		undo_names.Cut(1, 2)

/// The last applied history entry, or null.
/datum/sprite_editor_workspace/custom_sprite/proc/last_transaction()
	return length(undo_stack) ? undo_stack[length(undo_stack)] : null

/// Remembers the history as it stands at a save, so later imports and restorations can be told apart.
/datum/sprite_editor_workspace/custom_sprite/proc/mark_saved()
	saved_transactions = undo_stack.Copy()
	trimmed_rotations = list()

/**
 * Rotation markers of imports and restorations applied since the last save and not undone.
 *
 * Saving with any keeps the replaced saved style as the previous one.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/unsaved_rotations()
	. = trimmed_rotations.Copy()
	for(var/list/transaction as anything in undo_stack)
		if(transaction["rotate"] && !(transaction in saved_transactions))
			. |= transaction["rotate"]

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
	pixels_changed(transaction["dir"])
	update_edited_direction(transaction["dir"])

/datum/sprite_editor_workspace/custom_sprite/reverse_transact(list/transaction)
	if(transaction["type"] == "replace")
		apply_replacement(transaction, FALSE)
		return
	..()
	pixels_changed(transaction["dir"])
	update_edited_direction(transaction["dir"])

/// Explicit saved tints already render as a separate overlay: bake their RGB into literal colors.
/datum/sprite_editor_workspace/custom_sprite/proc/bake_tint()
	if(!tint || tint == "#ffffff")
		return
	var/list/colors = list()
	for(var/color in palette)
		colors["[color]ff"] = "[custom_sprite_tint_color(color, tint)]ff"
	for(var/_direction, frame in layers[1]["data"])
		for(var/list/row as anything in frame)
			for(var/x in 1 to length(row))
				if(colors[row[x]])
					row[x] = colors[row[x]]
	tint = "#ffffff"
	pixels_changed()
	palette = used_colors()

/**
 * Replaces every view, emission setting and the base hair look as one undoable action.
 *
 * The caller has already validated the drawing for this destination, so this bypasses the
 * per-stroke bounds checks. Colors needed by the replacement and by undo history share the
 * normal 63-color limit. Drawings without an explicit tint keep the old hair-color filter.
 *
 * Arguments:
 * - drawing: Canonical drawing, or null for empty art.
 * - new_hair_context: The base hair look that goes with it.
 * - name: The undo history label.
 *
 * Returns:
 * - TRUE: Replaced, or already identical.
 * - FALSE: The drawing is too wide or combined colors would exceed the limit. Nothing changed.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/replace_drawing(list/drawing, list/new_hair_context, name)
	if(drawing)
		drawing = custom_sprite_resize_drawing(drawing, width, height)
		if(!drawing)
			return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/replacement = new(drawing, list(), null, null, width, height)
	replacement.bake_tint()
	if(!drawing)
		replacement.tint = "#ffffff"
	var/list/replaced = frame_changes(replacement.layers[1]["data"])
	var/changed = length(replaced) || json_encode(hair_context) != json_encode(new_hair_context) || json_encode(emissive) != json_encode(replacement.emissive) || tint != replacement.tint
	var/list/transaction = list("type" = "replace", "name" = name, "replaced" = replaced, "hair_old" = hair_context, "hair_new" = new_hair_context, "emissive_old" = emissive, "emissive_new" = replacement.emissive, "tint_old" = tint, "tint_new" = replacement.tint, "markings_old" = markings_context, "markings_new" = markings_context)
	qdel(replacement)
	if(!changed)
		return TRUE
	return commit_replacement(transaction)

/// Pixel changes that turn each current frame into the matching new frame, as list(x, y, old, new).
/datum/sprite_editor_workspace/custom_sprite/proc/frame_changes(list/new_frames)
	. = list()
	for(var/direction, old_frame in layers[1]["data"])
		var/list/new_frame = new_frames[direction]
		var/list/points = list()
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/old_color = old_frame[y][x]
				var/new_color = new_frame[y][x]
				if(old_color != new_color && !(endswith(old_color, "00") && endswith(new_color, "00")))
					points += list(list(x - 1, y - 1, old_color, new_color))
		if(length(points))
			.[direction] = points

/// Applies and records a replacement; rolls it back when current and undoable colors wouldn't fit the palette.
/datum/sprite_editor_workspace/custom_sprite/proc/commit_replacement(list/transaction)
	var/list/previous_palette = palette
	transact(transaction)
	undo_stack += list(transaction)
	undo_names += transaction["name"]
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

/// Restores emission as a replacement recorded it.
/datum/sprite_editor_workspace/custom_sprite/proc/apply_replacement_emissive(list/transaction, forward)
	emissive = forward ? transaction["emissive_new"] : transaction["emissive_old"]

/datum/sprite_editor_workspace/custom_sprite/proc/apply_replacement(list/transaction, forward)
	for(var/direction, points in transaction["replaced"])
		var/list/frame = layers[1]["data"][direction]
		for(var/list/point as anything in points)
			frame[point[2] + 1][point[1] + 1] = forward ? point[4] : point[3]
		update_edited_direction(direction)
	hair_context = forward ? transaction["hair_new"] : transaction["hair_old"]
	markings_context = forward ? transaction["markings_new"] : transaction["markings_old"]
	apply_replacement_emissive(transaction, forward)
	tint = forward ? transaction["tint_new"] : transaction["tint_old"]
	pixels_changed()

/// Update only the affected direction, without serializing the drawing for its UI marker.
/datum/sprite_editor_workspace/custom_sprite/proc/update_edited_direction(direction)
	edited_directions[direction] = FALSE
	var/list/frame = layers[1]["data"][direction]
	for(var/list/row as anything in frame)
		for(var/pixel in row)
			if(!endswith(pixel, "00"))
				edited_directions[direction] = TRUE
				return

/// Pixels changed: serialization rebuilds, and so does the window's canvas, only that view when one is named.
/datum/sprite_editor_workspace/custom_sprite/proc/pixels_changed(direction)
	pixels_dirty = TRUE
	if(direction && canvas_views)
		canvas_views[direction] = null
	else
		canvas_palette = null

/**
 * The canvas as the window receives it: every pixel value once, and each view as codes.
 *
 * A code is `canvas_digits` characters of CUSTOM_SPRITE_INDEX_ALPHABET naming a palette entry, most
 * significant first, row by row from the top left. The palette only grows until the next full
 * rebuild, so views that didn't change keep their codes and aren't encoded again.
 *
 * Returns list("palette" = pixel values, "digits" = characters per pixel, "views" = direction -> codes).
 */
/datum/sprite_editor_workspace/custom_sprite/proc/canvas_ui_data()
	var/list/frames = layers[1]["data"]
	var/list/stale = list()
	for(var/direction in frames)
		if(isnull(canvas_palette) || isnull(canvas_views[direction]))
			stale += direction
	if(length(stale))
		var/list/values = canvas_palette ? canvas_palette.Copy() : list()
		// Pixel value -> TRUE. `values |= row` would keep a row's own repeats.
		var/list/known = list()
		for(var/value in values)
			known[value] = TRUE
		for(var/direction in stale)
			for(var/list/row as anything in frames[direction])
				for(var/pixel in row)
					if(!known[pixel])
						known[pixel] = TRUE
						values += pixel
		var/digits = length(values) <= 64 ? 1 : (length(values) <= 4096 ? 2 : 3)
		if(isnull(canvas_palette) || digits != canvas_digits)
			// Wider codes change every view.
			canvas_digits = digits
			canvas_codes = list()
			canvas_views = list()
			stale = assoc_to_keys(frames)
		canvas_palette = values
		for(var/index in length(canvas_codes) + 1 to length(canvas_palette))
			canvas_codes[canvas_palette[index]] = custom_sprite_canvas_code(index - 1, canvas_digits)
		for(var/direction in stale)
			var/list/codes = list()
			for(var/list/row as anything in frames[direction])
				for(var/pixel in row)
					codes += canvas_codes[pixel]
			canvas_views[direction] = jointext(codes, "")
	return list("palette" = canvas_palette, "digits" = canvas_digits, "views" = canvas_views)

/// The window gets the canvas as palette indexes rather than a color string per pixel.
/datum/sprite_editor_workspace/custom_sprite/sprite_editor_ui_data()
	. = ..()
	var/list/sprite = .["sprite"]
	sprite -= "layers"
	sprite["canvas"] = canvas_ui_data()
	sprite["compactStrokes"] = TRUE

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
	// A tall canvas saves as a normal 32-row drawing until paint reaches the rows above it.
	var/saved_height = height
	if(height > 32 && !paint_above(height - 32))
		saved_height = 32
	for(var/direction, frame in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		var/list/pixels = list()
		for(var/y in height - saved_height + 1 to height)
			for(var/pixel in frame[y])
				var/index = istext(pixel) ? pixel_indices[pixel] : "0"
				if(!index)
					index = !endswith(pixel, "00") ? indices[LOWER_TEXT(copytext(pixel, 1, 8))] : null
					pixel_indices[pixel] = index || "0"
				pixels += index || "0"
		directions[direction] = custom_sprite_encode_grid(jointext(pixels, ""), length(saved_palette), width * saved_height)
	drawing_cache = list("version" = custom_sprite_version(width, length(saved_palette), saved_height), "palette" = saved_palette, "tint" = tint, "dirs" = directions, "emissive" = emissive)
	return drawing_cache

/// Whether any view has paint in its top `rows` rows.
/datum/sprite_editor_workspace/custom_sprite/proc/paint_above(rows)
	for(var/direction, frame in layers[1]["data"])
		if(!edited_directions[direction])
			continue
		for(var/y in 1 to rows)
			for(var/pixel in frame[y])
				if(!endswith(pixel, "00"))
					return TRUE
	return FALSE

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

/**
 * The whole-body markings canvas.
 *
 * Every pixel of paint belongs to a region, so every tool, the eraser included, stays inside the
 * regions. Fill stops at region edges and Clear works on one region. markings_context and emissive
 * are zone-keyed maps here; replace transactions swap them whole, so undo restores them.
 */
/datum/sprite_editor_workspace/custom_sprite/regions
	/// Direction -> row strings naming the region that owns each pixel, "0" for none.
	var/list/region_map
	/// Zone -> views ("2" -> TRUE) that Clear, an import or a restoration replaced outright. Paint other limbs cover there goes too.
	var/list/resets
	/// Region characters no tool may change right now, such as regions worn clothing covers.
	var/list/locked

/// Regions may hold more than CUSTOM_SPRITE_MAX_COLORS colors between them, as saves and imports can; only new colors wait for room.
/datum/sprite_editor_workspace/custom_sprite/regions/update_palette(list/available_palette)
	return admit_colors(kept_colors(), available_palette)

/datum/sprite_editor_workspace/custom_sprite/regions/apply_replacement(list/transaction, forward)
	..()
	if("resets_new" in transaction)
		resets = forward ? transaction["resets_new"] : transaction["resets_old"]

/// Region replacements record only the regions whose emission they change, so undo leaves later toggles elsewhere alone.
/datum/sprite_editor_workspace/custom_sprite/regions/apply_replacement_emissive(list/transaction, forward)
	var/list/changes = forward ? transaction["emissive_new"] : transaction["emissive_old"]
	var/list/merged = emissive.Copy()
	for(var/zone, change in changes)
		if(isnull(change))
			merged -= zone
		else
			merged[zone] = change
	emissive = merged

/// The region character at a canvas pixel in one view, "0" when no region owns it.
/datum/sprite_editor_workspace/custom_sprite/regions/proc/region_at(x, y, direction)
	var/list/rows = region_map?[direction]
	return rows ? copytext(rows[y + 1], x + 1, x + 2) : "0"

/datum/sprite_editor_workspace/custom_sprite/regions/is_point_allowed(x, y, direction)
	if(x < 0 || x >= width || y < 0 || y >= height)
		return FALSE
	if(!isnull(draw_bounds))
		var/list/bounds = draw_bounds[direction]
		if(!bounds || x < bounds[1] || y < bounds[2] || x > bounds[3] || y > bounds[4])
			return FALSE
	var/region = region_at(x, y, direction)
	return region != "0" && !(region in locked)

/// A move can't carry paint out of a locked region. Destinations are already checked through is_point_allowed().
/datum/sprite_editor_workspace/custom_sprite/regions/prepare_selection_move(list/transaction)
	if(!..())
		return FALSE
	if(!length(locked))
		return TRUE
	for(var/list/change as anything in transaction["points"])
		if(region_at(change[1], change[2], transaction["dir"]) in locked)
			return FALSE
	return TRUE

/// Fill floods only the region under the clicked pixel; other regions are boundaries.
/datum/sprite_editor_workspace/custom_sprite/regions/preprocess_new_transaction(list/transaction)
	if(transaction["type"] != "bucket")
		return ..()
	var/direction = transaction["dir"]
	var/list/point = transaction["point"]
	var/region = region_at(point[1], point[2], direction)
	var/list/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/masked = list()
	for(var/y in 0 to height - 1)
		var/list/row = frame[y + 1].Copy()
		for(var/x in 0 to width - 1)
			if(!is_point_allowed(x, y, direction) || region_at(x, y, direction) != region)
				row[x + 1] = null
		masked += list(row)
	transaction["points"] = flood_fill(masked, point[1] + 1, point[2] + 1, width, height)
	transaction -= "point"

/// Fills the canvas as a draft opens, without history.
/datum/sprite_editor_workspace/custom_sprite/regions/proc/load_frames(list/frames)
	for(var/direction, frame in layers[1]["data"])
		var/list/source = frames[direction]
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				frame[y][x] = source[y][x]
		update_edited_direction(direction)
	pixels_changed()
	palette = used_colors()

/**
 * Erases one region's pixels in one view as a single undoable step.
 *
 * With covered_zone, that region's saved paint under other limbs in this view goes too when it saves.
 */
/datum/sprite_editor_workspace/custom_sprite/regions/proc/clear_region(direction, region, covered_zone)
	if(!istext(direction) || !(direction in layers[1]["data"]) || !istext(region) || region == "0")
		return FALSE
	var/list/frames = deep_copy_list(layers[1]["data"])
	var/list/frame = frames[direction]
	var/erased = FALSE
	for(var/y in 0 to height - 1)
		for(var/x in 0 to width - 1)
			if(region_at(x, y, direction) == region && !endswith(frame[y + 1][x + 1], "00"))
				frame[y + 1][x + 1] = "#00000000"
				erased = TRUE
	var/list/new_resets = resets
	if(covered_zone && !resets?[covered_zone]?[direction])
		new_resets = resets ? resets.Copy() : list()
		var/list/views = new_resets[covered_zone]
		views = views ? views.Copy() : list()
		views[direction] = TRUE
		new_resets[covered_zone] = views
	else if(!erased)
		return FALSE
	return replace_frames(frames, "Clear", markings_context, emissive, new_resets)

/**
 * Replaces the canvas, the per-region base markings and emission as one undoable action.
 *
 * new_resets, when given, also changes which regions are replaced outright in which views.
 *
 * Returns TRUE when replaced or already identical, FALSE when the colors and undo history would
 * need more than CUSTOM_SPRITE_MAX_COLORS colors. Nothing changes then.
 */
/datum/sprite_editor_workspace/custom_sprite/regions/proc/replace_frames(list/frames, name, list/new_markings_context, list/new_emissive, list/new_resets)
	if(isnull(new_resets))
		new_resets = resets
	var/list/replaced = frame_changes(frames)
	var/list/emissive_old = list()
	var/list/emissive_new = list()
	for(var/zone, settings in new_emissive)
		if(json_encode(emissive[zone]) != json_encode(settings))
			emissive_old[zone] = emissive[zone]
			emissive_new[zone] = settings
	if(!length(replaced) && !length(emissive_new) && json_encode(markings_context) == json_encode(new_markings_context) && json_encode(resets) == json_encode(new_resets))
		return TRUE
	return commit_replacement(list("type" = "replace", "name" = name, "replaced" = replaced, "hair_old" = hair_context, "hair_new" = hair_context, "emissive_old" = emissive_old, "emissive_new" = emissive_new, "tint_old" = tint, "tint_new" = tint, "markings_old" = markings_context, "markings_new" = new_markings_context, "resets_old" = resets, "resets_new" = new_resets))
