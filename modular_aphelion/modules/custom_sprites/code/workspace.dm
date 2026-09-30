/// Selection moves and placements, drawing bounds and input sanitizing, shared by every SpriteEditor workspace.
/datum/sprite_editor_workspace
	/// Set while a stroke decoded from a compact mask is checked. A mask can't name a pixel twice, so can_transact() skips its duplicate check; no window can set it.
	var/mask_stroke = FALSE

/// Shared point validation and the extension point for consumer-specific drawing bounds.
/datum/sprite_editor_workspace/proc/valid_point_pair(list/point)
	return islist(point) && length(point) == 2 && isnum(point[1]) && isnum(point[2]) && round(point[1]) == point[1] && round(point[2]) == point[2]

/// Whether a pixel may be painted; the base workspace allows the whole canvas.
/datum/sprite_editor_workspace/proc/is_point_allowed(x, y, direction)
	return x >= 0 && x < width && y >= 0 && y < height

/// Whether `box` is list(left, top, right, bottom) of whole pixels on the canvas, none of it inside out.
/datum/sprite_editor_workspace/proc/valid_box(list/box)
	if(!islist(box) || length(box) != 4)
		return FALSE
	for(var/coordinate in box)
		if(!isnum(coordinate) || round(coordinate) != coordinate)
			return FALSE
	return box[1] >= 0 && box[2] >= 0 && box[3] < width && box[4] < height && box[3] >= box[1] && box[4] >= box[2]

/// Build an immutable old/new pixel patch before modifying the frame, including overlapping moves.
/datum/sprite_editor_workspace/proc/prepare_selection_move(list/transaction)
	var/direction = transaction["dir"]
	if(!istext(direction) || !(direction in layers[transaction["layer"]]["data"]))
		return FALSE
	if(!isnull(transaction["codes"]))
		return prepare_selection_placement(transaction)
	var/list/rect = transaction["rect"]
	var/list/offset = transaction["offset"]
	if(!valid_box(rect) || !valid_point_pair(offset))
		return FALSE
	var/left = rect[1]
	var/top = rect[2]
	var/right = rect[3]
	var/bottom = rect[4]
	var/dx = offset[1]
	var/dy = offset[2]
	// A move goes somewhere, its whole box still on the canvas. The box may include shaded margins; only its painted pixels must stay in the drawing area.
	if((!dx && !dy) || left + dx < 0 || top + dy < 0 || right + dx >= width || bottom + dy >= height)
		return FALSE
	var/list/frame = layers[transaction["layer"]]["data"][direction]
	// Every painted pixel lifts away, then lands: "x,y" -> list(x, y, old color, new color).
	var/list/changes = list()
	var/list/landings = list()
	// Painted pixels outside changed bounds may be moved back in; their destinations are still checked.
	for(var/y in top to bottom)
		for(var/x in left to right)
			var/color = frame[y + 1][x + 1]
			if(istext(color) && !(length(color) == 9 && endswith(color, "00")))
				if(!is_point_allowed(x + dx, y + dy, direction))
					return FALSE
				changes["[x],[y]"] = list(x, y, color, "#00000000")
				landings += list(list(x + dx, y + dy, color))
	for(var/list/landing as anything in landings)
		var/key = "[landing[1]],[landing[2]]"
		var/list/change = changes[key]
		if(change)
			change[4] = landing[3]
		else
			changes[key] = list(landing[1], landing[2], frame[landing[2] + 1][landing[1] + 1], landing[3])
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
	if(!valid_box(area) || !islist(palette) || !length(palette) || !(digits in list(1, 2)) || length(palette) > 64 ** digits || !istext(codes))
		return FALSE
	var/left = area[1]
	var/top = area[2]
	var/right = area[3]
	var/bottom = area[4]
	var/pixels = (right - left + 1) * (bottom - top + 1)
	// The codes cover the area exactly, and a window never sends more values than pixels it changes.
	if(length(codes) != pixels * digits || length(palette) > pixels)
		return FALSE
	// Each distinct value is checked once: transparent lifts paint away, anything else must be a color this drawing takes.
	var/list/values = list()
	// Lowercased value -> the value it stands for, so repeats cost a lookup instead of another check.
	var/list/checked = list()
	for(var/raw_color in palette)
		if(!istext(raw_color))
			return FALSE
		var/key = LOWER_TEXT(raw_color)
		var/color = checked[key]
		if(!color)
			color = key
			if(length(color) == 9 && endswith(color, "00"))
				color = "#00000000"
			else if(!is_valid_color(color))
				return FALSE
			else if(length(color) == 7)
				color += "ff"
			checked[key] = color
		values += color
	var/list/index_values = custom_sprite_index_values()
	var/unchanged = digits == 1 ? "." : ".."
	var/direction = transaction["dir"]
	var/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/points = list()
	var/position = 1
	for(var/y in top to bottom)
		var/list/row = frame[y + 1]
		for(var/x in left to right)
			var/code = copytext(codes, position, position + digits)
			position += digits
			if(code == unchanged)
				continue
			var/index = index_values[digits == 1 ? code : copytext(code, 1, 2)]
			if(digits == 2 && !isnull(index))
				var/low = index_values[copytext(code, 2, 3)]
				index = isnull(low) ? null : index * 64 + low
			if(isnull(index) || index >= length(values))
				return FALSE
			var/color = values[index + 1]
			// A pixel already that colour changes nothing, wherever it is.
			var/old_color = row[x + 1]
			if(old_color == color || (color != "#00000000" && !is_point_allowed(x, y, direction)))
				continue
			points += list(list(x, y, old_color, color))
	transaction["points"] = points
	return length(points) > 0

/// A custom hair or markings drawing being edited: its layers share one palette, paint stays within the body's bounds, and the history is kept within limits.
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
	/// The number the next appendage layer's id takes. Ids are never reused in a draft, so the window's choice of layer survives undo.
	var/next_appendage_id = 1
	/// The layer the transaction being checked paints, so an eraser outside the bounds reads that layer's pixels.
	var/current_layer = 1
	/// The view the window shows, the only one of each appendage layer it's sent.
	var/visible_view = "2"
	/// What used_colors() last found, until pixels change.
	var/list/used_colors_cache

/**
 * Opens `drawing`, or a blank canvas for null, painting within `bounds` and `mask`, and offers `sampled_palette`
 * after the drawing's own colours. `canvas_width` and `canvas_height` ask for the taur's wide canvas or tall hair's
 * canvas; a drawing larger than the canvas asked for keeps its own size.
 */
/datum/sprite_editor_workspace/custom_sprite/New(list/drawing, list/sampled_palette, list/bounds, list/mask, canvas_width = null, canvas_height = null)
	..(max(custom_sprite_width(drawing), canvas_width == CUSTOM_SPRITE_TAUR_WIDTH ? CUSTOM_SPRITE_TAUR_WIDTH : 32), max(custom_sprite_height(drawing), canvas_height == CUSTOM_SPRITE_TALL_HEIGHT ? CUSTOM_SPRITE_TALL_HEIGHT : 32), 4, null, SPRITE_EDITOR_COLOR_MODE_RGB, SPRITE_EDITOR_ALLOW_UNDO, SPRITE_EDITOR_TOOL_PENCIL | SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_BUCKET | SPRITE_EDITOR_TOOL_DROPPER | SPRITE_EDITOR_TOOL_SELECT, "#00000000")
	tint = drawing?["tint"]
	emissive = custom_sprite_emissive_settings(drawing?["emissive"])
	draw_bounds = bounds
	draw_mask = mask
	RegisterSignal(src, COMSIG_SPRITE_EDITOR_VALIDATE_COLOR, PROC_REF(validate_palette_color))
	layers[1]["id"] = "hair"
	custom_sprite_hydrate(src, drawing)
	// add_appendage_layer() notes which views of each appendage are painted.
	for(var/_key, appendage in drawing?["appendages"])
		add_appendage_layer(appendage, drawing)
	for(var/direction in layers[1]["data"])
		update_edited_direction(direction)
	palette = used_colors()
	update_palette(sampled_palette)

/**
 * Grows or shrinks the canvas to `new_height` rows where it stands, as picking or leaving the tall
 * base does: rows come and go at the top, so paint keeps its place on the head and every layer keeps
 * its id. The caller has made sure no paint sits in rows that go. History can't span two canvas
 * sizes, so it starts over; imports and restorations it held still count when the draft saves.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/resize_height(new_height)
	trimmed_rotations = unsaved_rotations()
	var/list/blank = list()
	for(var/x in 1 to width)
		blank += "#00000000"
	for(var/list/entry as anything in layers)
		for(var/_direction, rows in entry["data"])
			var/list/frame = rows
			if(new_height > height)
				for(var/i in 1 to new_height - height)
					frame.Insert(1, list(blank.Copy()))
			else
				frame.Cut(1, height - new_height + 1)
	height = new_height
	undo_stack.Cut()
	undo_names.Cut()
	redo_stack.Cut()
	redo_names.Cut()
	saved_transactions = list()
	// The editor's rebuild bounds the new size.
	draw_bounds = null
	draw_mask = null
	pixels_changed()

/// Blank frames from one row copied, rather than every pixel appended one at a time: a draft builds a layer per appendage.
/datum/sprite_editor_workspace/custom_sprite/create_layer_data(color = "#00000000")
	var/list/blank = list()
	for(var/x in 1 to width)
		blank += color
	. = list()
	for(var/i in 1 to dirs)
		var/list/frame = list()
		for(var/y in 1 to height)
			frame += list(blank.Copy())
		.["[GLOB.alldirs_dmi_order[i]]"] = frame

/// A new blank appendage layer, not yet in the draft, with `appendage`'s name, zone, kind and emission under the next id.
/datum/sprite_editor_workspace/custom_sprite/proc/appendage_entry(list/appendage)
	return list("name" = appendage["name"], "visible" = TRUE, "data" = create_layer_data(), "id" = "a[next_appendage_id++]", "zone" = appendage["zone"], "outer" = appendage["outer"] ? TRUE : FALSE, "emissive" = custom_sprite_emissive_settings(appendage["emissive"]), "edited" = list())

/**
 * Adds an appendage layer at `position` (the end when null), painted from `appendage`'s views when
 * `drawing` is given, and returns it. Nothing is recorded for undo; steps that add one do that.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/add_appendage_layer(list/appendage, list/drawing, position = null)
	var/list/entry = appendage_entry(appendage)
	var/index = isnull(position) ? length(layers) + 1 : clamp(position, 2, length(layers) + 1)
	layers.Insert(index, list(entry))
	if(drawing)
		custom_sprite_hydrate(src, drawing, index, appendage["dirs"])
		for(var/direction in entry["data"])
			update_edited_direction(direction, index)
	return entry

/// Direction -> whether `layer` has paint in that view. The hair's own map is edited_directions.
/datum/sprite_editor_workspace/custom_sprite/proc/layer_edited(layer)
	return layer == 1 ? edited_directions : layers[layer]["edited"]

/// The index of the layer with this id, or 0.
/datum/sprite_editor_workspace/custom_sprite/proc/layer_index(id)
	for(var/index in 1 to length(layers))
		if(layers[index]["id"] == id)
			return index
	return 0

/// Whether `layer` is a whole number naming one of the layers, from `lowest` on: 2 names only appendage layers.
/datum/sprite_editor_workspace/custom_sprite/proc/valid_layer(layer, lowest = 1)
	return isnum(layer) && round(layer) == layer && layer >= lowest && layer <= length(layers)

/// Whether any view of `layer` has paint.
/datum/sprite_editor_workspace/custom_sprite/proc/layer_painted(layer)
	for(var/_direction, painted in layer_edited(layer))
		if(painted)
			return TRUE
	return FALSE

/// Colors the current and undoable pixels use, which must stay paintable.
/datum/sprite_editor_workspace/custom_sprite/proc/kept_colors()
	. = used_colors()
	for(var/list/transaction as anything in undo_stack + redo_stack)
		. |= step_colors(transaction)

/// Adds a pixel value's colour, lowercase and without its alpha, to the proc's `colors` the first time its `seen` meets the value, unless it's transparent.
#define NOTE_COLOR(pixel) \
	if(!seen[pixel]) { \
		seen[pixel] = TRUE; \
		if(istext(pixel) && !endswith(pixel, "00")) { \
			colors |= LOWER_TEXT(copytext(pixel, 1, 8)); \
		} \
	}

/**
 * The opaque colors one history step paints with or over, in the order it first uses them. A move or
 * placement's own colors count, so they stay paintable while the step waits undone to be redone.
 *
 * Worked out once and kept on the step, which never changes once it's in the history: a history of
 * whole-canvas steps would otherwise be read pixel by pixel on every palette refresh.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/step_colors(list/transaction)
	var/list/colors = transaction["kept_colors"]
	if(colors)
		return colors
	colors = list()
	// Pixel value -> TRUE once looked at: one step can repeat a few values thousands of times.
	var/list/seen = list()
	var/color = transaction["color"]
	if(color)
		seen[color] = TRUE
		colors += LOWER_TEXT(copytext(color, 1, 8))
	// A move or placement puts down colors of its own, which redoing it paints again.
	var/placed = transaction["type"] == "move"
	for(var/list/point as anything in transaction["points"])
		var/old_color = point[3]
		NOTE_COLOR(old_color)
		if(placed)
			var/new_color = point[4]
			NOTE_COLOR(new_color)
	for(var/_direction, points in transaction["replaced"])
		for(var/list/point as anything in points)
			for(var/replaced_color in list(point[3], point[4]))
				NOTE_COLOR(replaced_color)
	// A layer the step adds, removes or swaps comes back whole, colours and all.
	for(var/list/entry as anything in step_layers(transaction))
		for(var/_direction, frame in entry["data"])
			for(var/list/row as anything in frame)
				for(var/pixel in row)
					NOTE_COLOR(pixel)
	transaction["kept_colors"] = colors
	return colors

/// Appendage layers a history step keeps whole: the one it adds or removes, or both sets a replacement swaps.
/datum/sprite_editor_workspace/custom_sprite/proc/step_layers(list/transaction)
	. = list()
	if(transaction["entry"])
		. += list(transaction["entry"])
	for(var/key in list("appendages_old", "appendages_new"))
		for(var/list/entry as anything in transaction[key])
			. += list(entry)

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

/// The opaque colours every layer's frames use, lowercase, in first-use order. The layers share one palette.
/datum/sprite_editor_workspace/custom_sprite/proc/used_colors()
	// Palette refreshes ask far more often than pixels change, and each answer reads every layer.
	if(used_colors_cache)
		return used_colors_cache.Copy()
	var/list/colors = list()
	// Pixel value -> TRUE once looked at.
	var/list/seen = list()
	for(var/layer in 1 to length(layers))
		var/list/edited = layer_edited(layer)
		for(var/direction, frame in layers[layer]["data"])
			if(!edited[direction])
				continue
			for(var/list/row as anything in frame)
				for(var/pixel in row)
					NOTE_COLOR(pixel)
	used_colors_cache = colors
	return colors.Copy()

/// Refuses a stroke colour that isn't in the palette.
/datum/sprite_editor_workspace/custom_sprite/proc/validate_palette_color(datum/source, color)
	SIGNAL_HANDLER
	if(!(LOWER_TEXT(copytext(color, 1, 8)) in palette))
		return COLOR_IS_INVALID

/// Pixels inside the view's bounds and mask; while erasing, also paint left anywhere else on the canvas.
/datum/sprite_editor_workspace/custom_sprite/is_point_allowed(x, y, direction)
	// The base check, inline: this runs for every pixel of every stroke.
	if(x < 0 || x >= width || y < 0 || y >= height)
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

/// Whether a pixel of `layer` holds opaque paint.
/datum/sprite_editor_workspace/custom_sprite/proc/is_painted(x, y, direction, layer = current_layer)
	var/list/frame = layers[layer]["data"][direction]
	var/color = frame?[y + 1][x + 1]
	return istext(color) && !endswith(color, "00")

/// Existing paint left outside changed bounds can always be erased; new paint stays inside.
/datum/sprite_editor_workspace/custom_sprite/new_transaction(transaction)
	if(islist(transaction) && !stroke_layer_matches(transaction))
		return FALSE
	// A mirror can be picked up or dropped between strokes.
	var/datum/custom_sprite_editor/editor = owner_ref?.resolve()
	editor?.sync_locked_views(push = FALSE)
	erasing = islist(transaction) && transaction["type"] == "eraser"
	// can_transact() refuses any other layer before a pixel is looked at.
	var/layer = islist(transaction) ? transaction["layer"] : null
	current_layer = valid_layer(layer) ? layer : 1
	// Windows send strokes as a compact mask; the history keeps point lists.
	if(islist(transaction) && ("mask" in transaction))
		transaction["points"] = custom_sprite_mask_points(transaction["mask"], width, height)
		mask_stroke = TRUE
	. = ..()
	erasing = FALSE
	mask_stroke = FALSE
	current_layer = 1
	trim_history()

/// The most steps the undo history keeps; the oldest go first once it's passed.
#define CUSTOM_SPRITE_MAX_UNDO 100
/// The most pixels the undo history records across its steps; the oldest steps go first once it's passed.
#define CUSTOM_SPRITE_MAX_UNDO_POINTS 40000

/// Keeps the undo history within CUSTOM_SPRITE_MAX_UNDO steps and CUSTOM_SPRITE_MAX_UNDO_POINTS recorded pixels, dropping the oldest first.
/datum/sprite_editor_workspace/custom_sprite/proc/trim_history()
	var/points = 0
	for(var/list/step as anything in undo_stack)
		points += step_points(step)
	while(length(undo_stack) > 1 && (length(undo_stack) > CUSTOM_SPRITE_MAX_UNDO || points > CUSTOM_SPRITE_MAX_UNDO_POINTS))
		var/list/oldest = popleft(undo_stack)
		undo_names.Cut(1, 2)
		// An unsaved import that can no longer be undone still keeps the replaced style.
		if(oldest["rotate"] && !(oldest in saved_transactions))
			trimmed_rotations |= oldest["rotate"]
		points -= step_points(oldest)

/// The pixels one history step records: its points, every view a replacement changed, and every pixel of a layer it keeps whole.
/datum/sprite_editor_workspace/custom_sprite/proc/step_points(list/transaction)
	. = length(transaction["points"])
	for(var/_direction, points in transaction["replaced"])
		. += length(points)
	. += length(step_layers(transaction)) * width * height * dirs

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
#undef CUSTOM_SPRITE_MAX_UNDO_POINTS

/// Treat masked pixels as fill boundaries, so disconnected parts do not fill through the backdrop.
/datum/sprite_editor_workspace/custom_sprite/preprocess_new_transaction(list/transaction)
	if(transaction["type"] != "bucket" || !draw_mask)
		return ..()
	masked_fill(transaction)

/**
 * Floods a fill from its point over the pixels is_point_allowed() takes; the others are boundaries. With `rows`,
 * a view's region map, only pixels of `region` fill.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/masked_fill(list/transaction, list/rows, region)
	var/direction = transaction["dir"]
	var/list/list/frame = layers[transaction["layer"]]["data"][direction]
	var/list/masked = list()
	for(var/y in 0 to height - 1)
		var/list/row = frame[y + 1].Copy()
		for(var/x in 0 to width - 1)
			if(!is_point_allowed(x, y, direction) || (rows && copytext(rows[y + 1], x + 1, x + 2) != region))
				row[x + 1] = null
		masked += list(row)
	var/list/point = transaction["point"]
	transaction["points"] = flood_fill(masked, point[1] + 1, point[2] + 1, width, height)
	transaction -= "point"

/**
 * Applies, or with `forward` FALSE reverses, a step this workspace records itself: a replacement, an appendage
 * layer added, removed or changed, or a new base hair look. Returns FALSE for anything else, a stroke or a move.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/apply_step(list/transaction, forward)
	switch(transaction["type"])
		if("replace")
			apply_replacement(transaction, forward)
		if("addAppendage", "removeAppendage")
			// Adding a layer, or undoing its removal, puts it in; the other two take it out.
			if((transaction["type"] == "addAppendage") == forward)
				layers.Insert(transaction["index"], list(transaction["entry"]))
			else
				layers.Cut(transaction["index"], transaction["index"] + 1)
			layers_changed()
		if("setAppendage")
			layers[transaction["index"]][transaction["field"]] = forward ? transaction["new"] : transaction["old"]
			pixels_dirty = TRUE
		if("hairContext")
			hair_context = forward ? transaction["new"] : transaction["old"]
		else
			return FALSE
	return TRUE

/// Applies a step: this workspace's own through apply_step(), a pencil stroke by assigning its colour, and anything else as the base workspace does.
/datum/sprite_editor_workspace/custom_sprite/transact(list/transaction)
	if(apply_step(transaction, TRUE))
		return
	var/direction = transaction["dir"]
	var/layer = transaction["layer"]
	if(transaction["type"] == "pencil")
		// blend_color() returns the source for an opaque colour, and this canvas only takes opaque colours: assign outright.
		var/color = transaction["color"]
		var/list/frame = layers[layer]["data"][direction]
		for(var/list/point as anything in transaction["points"])
			frame[point[2] + 1][point[1] + 1] = color
		var/list/edited = layer_edited(layer)
		edited[direction] = length(transaction["points"]) > 0 || edited[direction]
	else
		..()
		update_edited_direction(direction, layer)
	pixels_changed(direction, layer)

/// Reverses a step: this workspace's own through apply_step(), and anything else as the base workspace does.
/datum/sprite_editor_workspace/custom_sprite/reverse_transact(list/transaction)
	if(apply_step(transaction, FALSE))
		return
	..()
	pixels_changed(transaction["dir"], transaction["layer"])
	update_edited_direction(transaction["dir"], transaction["layer"])

/**
 * Applies a step the editor built itself, such as adding an appendage, and records it for undo
 * under the same limits as any other step.
 *
 * With `check_palette`, the palette then keeps only the colours the draft and its history use; a step
 * whose colours wouldn't fit is rolled back instead, leaving everything as it was, and FALSE is returned.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/record_step(list/transaction, check_palette = FALSE)
	var/list/previous_palette = palette
	transact(transaction)
	undo_stack += list(transaction)
	undo_names += transaction["name"]
	if(check_palette && !update_palette(list()))
		pop(undo_names)
		pop(undo_stack)
		reverse_transact(transaction)
		palette = previous_palette
		return FALSE
	redo_stack.Cut()
	redo_names.Cut()
	trim_history()
	return TRUE

/// Adds an empty appendage layer after the others, as an undoable step. Returns its id, or null when there's no room.
/datum/sprite_editor_workspace/custom_sprite/proc/add_appendage()
	if(length(layers) - 1 >= CUSTOM_SPRITE_MAX_APPENDAGES)
		return null
	var/list/entry = appendage_entry(list("name" = "Appendage [length(layers)]", "zone" = HAIR_APPENDAGE_REAR, "outer" = FALSE))
	record_step(list("type" = "addAppendage", "name" = "Add appendage layer", "index" = length(layers) + 1, "entry" = entry))
	return entry["id"]

/// Copies an under-hat appendage to a new over-hat layer right after it, as the built-in pieces pair up. Returns the copy's id, or null.
/datum/sprite_editor_workspace/custom_sprite/proc/copy_appendage_over(layer)
	if(!valid_layer(layer, 2) || length(layers) - 1 >= CUSTOM_SPRITE_MAX_APPENDAGES || layers[layer]["outer"])
		return null
	var/list/source = layers[layer]
	// The name gives way so the suffix always fits.
	var/list/entry = appendage_entry(list("name" = custom_hair_appendage_name("[copytext_char(source["name"], 1, CUSTOM_SPRITE_MAX_APPENDAGE_NAME - 6)] (over)"), "zone" = source["zone"], "outer" = TRUE, "emissive" = source["emissive"]))
	// Frames are lists of row lists, which neither deep copy helper copies row by row.
	var/list/frames = list()
	for(var/direction, frame in source["data"])
		var/list/rows = list()
		for(var/list/row as anything in frame)
			rows += list(row.Copy())
		frames[direction] = rows
	entry["data"] = frames
	var/list/source_edited = source["edited"]
	entry["edited"] = source_edited.Copy()
	record_step(list("type" = "addAppendage", "name" = "Copy to over-hat layer", "index" = layer + 1, "entry" = entry))
	return entry["id"]

/// Removes an appendage layer, paint and all, as an undoable step.
/datum/sprite_editor_workspace/custom_sprite/proc/remove_appendage(layer)
	if(!valid_layer(layer, 2))
		return FALSE
	return record_step(list("type" = "removeAppendage", "name" = "Remove appendage layer", "index" = layer, "entry" = layers[layer]))

/**
 * Changes an appendage's name, zone or kind as an undoable step. The caller has already made the
 * value canonical. Returns FALSE when nothing would change.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/set_appendage(layer, field, value)
	var/static/list/step_names = list("name" = "Rename appendage", "zone" = "Move appendage", "outer" = "Change appendage kind")
	if(!valid_layer(layer, 2) || !istext(field) || !step_names[field] || layers[layer][field] == value)
		return FALSE
	return record_step(list("type" = "setAppendage", "name" = step_names[field], "index" = layer, "field" = field, "old" = layers[layer][field], "new" = value))

/// Explicit saved tints already render as a separate overlay: bake their RGB into literal colors.
/datum/sprite_editor_workspace/custom_sprite/proc/bake_tint()
	if(!tint || tint == "#ffffff")
		return
	var/list/colors = list()
	for(var/color in palette)
		colors["[color]ff"] = "[custom_sprite_tint_color(color, tint)]ff"
	// The layers share the drawing's filter.
	for(var/list/entry as anything in layers)
		for(var/_direction, frame in entry["data"])
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
 * - keep_layers: The drawing is this draft's own, recolored or re-fitted, so appendage layers keep
 *   their ids and unpainted ones stay. Imports and restorations replace them outright.
 *
 * Returns:
 * - TRUE: Replaced, or already identical.
 * - FALSE: The drawing is too wide or combined colors would exceed the limit. Nothing changed.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/replace_drawing(list/drawing, list/new_hair_context, name, keep_layers = FALSE)
	if(drawing)
		drawing = custom_sprite_resize_drawing(drawing, width, height)
		if(!drawing)
			return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/replacement = new(drawing, list(), null, null, width, height)
	replacement.bake_tint()
	if(!drawing)
		replacement.tint = "#ffffff"
	var/list/replaced = frame_changes(replacement.layers[1]["data"])
	var/list/appendages_old = layers.Copy(2)
	var/list/appendages_new = incoming_appendage_layers(replacement.layers.Copy(2), keep_layers)
	var/changed = length(replaced) || length(appendages_old) || length(appendages_new) || json_encode(hair_context) != json_encode(new_hair_context) || json_encode(emissive) != json_encode(replacement.emissive) || tint != replacement.tint
	var/list/transaction = list("type" = "replace", "name" = name, "replaced" = replaced, "hair_old" = hair_context, "hair_new" = new_hair_context, "emissive_old" = emissive, "emissive_new" = replacement.emissive, "tint_old" = tint, "tint_new" = replacement.tint, "markings_old" = markings_context, "markings_new" = markings_context, "appendages_old" = appendages_old, "appendages_new" = appendages_new)
	qdel(replacement)
	if(!changed)
		return TRUE
	return record_step(transaction, check_palette = TRUE)

/**
 * Swaps the base hair look under paint that stays exactly as it is, as one undoable step. A new
 * hairstyle never recolors paint, so this is all it changes: replace_drawing() would rebuild every
 * layer to find no difference, and keep whole copies of each appendage layer in the history.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/replace_hair_context(list/new_hair_context, name)
	if(json_encode(hair_context) == json_encode(new_hair_context))
		return TRUE
	return record_step(list("type" = "hairContext", "name" = name, "old" = hair_context, "new" = new_hair_context))

/**
 * A replacement's appendage layers under this draft's ids.
 *
 * With `keep`, the draft's painted layers take the incoming ones in order under their own ids, and
 * unpainted ones stay where they are, so a recolor or a new base look doesn't move or drop a layer.
 * Otherwise every incoming layer gets a fresh id.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/incoming_appendage_layers(list/incoming, keep)
	. = list()
	var/next = 1
	if(keep)
		for(var/layer in 2 to length(layers))
			if(!layer_painted(layer))
				. += list(layers[layer])
			else if(next <= length(incoming))
				var/list/entry = incoming[next++]
				entry["id"] = layers[layer]["id"]
				. += list(entry)
	for(var/index in next to length(incoming))
		var/list/entry = incoming[index]
		entry["id"] = "a[next_appendage_id++]"
		. += list(entry)

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

/// Restores emission as a replacement recorded it.
/datum/sprite_editor_workspace/custom_sprite/proc/apply_replacement_emissive(list/transaction, forward)
	emissive = forward ? transaction["emissive_new"] : transaction["emissive_old"]

/// Applies or reverses a replacement step: pixels, appendage layers, base look, markings, emission and tint together.
/datum/sprite_editor_workspace/custom_sprite/proc/apply_replacement(list/transaction, forward)
	for(var/direction, points in transaction["replaced"])
		var/list/frame = layers[1]["data"][direction]
		for(var/list/point as anything in points)
			frame[point[2] + 1][point[1] + 1] = forward ? point[4] : point[3]
		update_edited_direction(direction)
	if("appendages_new" in transaction)
		layers.Cut(2)
		layers += forward ? transaction["appendages_new"] : transaction["appendages_old"]
	hair_context = forward ? transaction["hair_new"] : transaction["hair_old"]
	markings_context = forward ? transaction["markings_new"] : transaction["markings_old"]
	apply_replacement_emissive(transaction, forward)
	tint = forward ? transaction["tint_new"] : transaction["tint_old"]
	pixels_changed()

/// Update only the affected direction of `layer`, without serializing the drawing for its UI marker.
/datum/sprite_editor_workspace/custom_sprite/proc/update_edited_direction(direction, layer = 1)
	var/list/edited = layer_edited(layer)
	edited[direction] = FALSE
	// Whatever wrote the view may have changed the colours in use.
	used_colors_cache = null
	var/list/frame = layers[layer]["data"][direction]
	for(var/list/row as anything in frame)
		for(var/pixel in row)
			// Most pixels are the blank colour, which a comparison rules out far faster than endswith().
			if(pixel != "#00000000" && !endswith(pixel, "00"))
				edited[direction] = TRUE
				return

/// Pixels changed: serialization and the colours in use are worked out again, and so is the window's canvas, only that layer's view when one is named.
/datum/sprite_editor_workspace/custom_sprite/proc/pixels_changed(direction, layer = 1)
	pixels_dirty = TRUE
	used_colors_cache = null
	if(!direction)
		canvas_palette = null
		return
	// A layer with no views yet has all of its encoded on the next update anyway.
	var/list/views = canvas_views?[layers[layer]["id"]]
	if(views)
		views[direction] = null

/// An appendage layer came or went, pixels and all: the window's canvas keeps the views of the layers still there, and forgets the rest.
/datum/sprite_editor_workspace/custom_sprite/proc/layers_changed()
	pixels_dirty = TRUE
	used_colors_cache = null
	if(!canvas_views)
		return
	var/list/kept = list()
	for(var/list/entry as anything in layers)
		kept[entry["id"]] = canvas_views[entry["id"]]
	canvas_views = kept

/// The views of `layer` the window's canvas carries: every view of the hair, and the visible one of an appendage.
/datum/sprite_editor_workspace/custom_sprite/proc/canvas_directions(layer)
	return layer == 1 ? layers[1]["data"] : list(visible_view)

/**
 * The canvas as the window receives it: every pixel value once, and each view as codes.
 *
 * A code is `canvas_digits` characters of CUSTOM_SPRITE_INDEX_ALPHABET naming a palette entry, most
 * significant first, row by row from the top left. The palette only grows until the next full
 * rebuild, so views that didn't change keep their codes and aren't encoded again.
 *
 * The hair layer sends every view, as it always has. Appendage layers send, and so encode, only
 * `visible_view`: the window shows one view at a time, and switching views asks for the next.
 *
 * Returns list("palette" = pixel values, "digits" = characters per pixel, "views" = the hair's
 * direction -> codes, "appendages" = appendage id -> direction -> codes).
 */
/datum/sprite_editor_workspace/custom_sprite/proc/canvas_ui_data()
	// list(layer index, direction) for each view to encode again.
	var/list/stale = list()
	for(var/layer in 1 to length(layers))
		var/list/views = canvas_views?[layers[layer]["id"]]
		for(var/direction in canvas_directions(layer))
			if(isnull(canvas_palette) || isnull(views?[direction]))
				stale += list(list(layer, direction))
	if(length(stale))
		var/list/values = canvas_palette ? canvas_palette.Copy() : list()
		// Pixel value -> TRUE. `values |= row` would keep a row's own repeats.
		var/list/known = list()
		for(var/value in values)
			known[value] = TRUE
		for(var/list/item as anything in stale)
			for(var/list/row as anything in layers[item[1]]["data"][item[2]])
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
			stale = list()
			for(var/layer in 1 to length(layers))
				for(var/direction in canvas_directions(layer))
					stale += list(list(layer, direction))
		canvas_palette = values
		for(var/index in length(canvas_codes) + 1 to length(canvas_palette))
			canvas_codes[canvas_palette[index]] = custom_sprite_canvas_code(index - 1, canvas_digits)
		for(var/list/item as anything in stale)
			var/id = layers[item[1]]["id"]
			var/list/views = canvas_views[id] || list()
			canvas_views[id] = views
			var/list/codes = list()
			for(var/list/row as anything in layers[item[1]]["data"][item[2]])
				for(var/pixel in row)
					codes += canvas_codes[pixel]
			views[item[2]] = jointext(codes, "")
	var/list/appendage_views = list()
	for(var/layer in 2 to length(layers))
		var/id = layers[layer]["id"]
		appendage_views[id] = list("[visible_view]" = canvas_views[id]?["[visible_view]"])
	return list("palette" = canvas_palette, "digits" = canvas_digits, "views" = canvas_views["hair"], "appendages" = appendage_views)

/// The window gets the canvas as palette indexes rather than a color string per pixel.
/datum/sprite_editor_workspace/custom_sprite/sprite_editor_ui_data()
	. = ..()
	var/list/sprite = .["sprite"]
	sprite -= "layers"
	sprite["canvas"] = canvas_ui_data()
	sprite["compactStrokes"] = TRUE

/// The draft as a canonical drawing, cached until pixels change; null when empty or over the colour limit.
/datum/sprite_editor_workspace/custom_sprite/proc/serialize_drawing()
	if(!pixels_dirty)
		if(drawing_cache && (drawing_cache["tint"] != tint || drawing_cache["emissive"] != emissive))
			drawing_cache = drawing_cache.Copy()
			drawing_cache["tint"] = tint
			drawing_cache["emissive"] = emissive
		return drawing_cache
	pixels_dirty = FALSE
	drawing_cache = null
	var/list/indices = list()
	var/list/pixel_indices = list()
	var/list/saved_palette = used_colors()
	if(!length(saved_palette) || length(saved_palette) > CUSTOM_SPRITE_MAX_COLORS)
		return null
	for(var/i in 1 to length(saved_palette))
		indices[saved_palette[i]] = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, i + 1, i + 2)
	// A tall canvas saves as a normal 32-row drawing until paint on any layer reaches the rows above it.
	var/saved_height = (height > 32 && !paint_above(height - 32)) ? 32 : height
	var/list/directions = encode_layer(1, saved_height, indices, pixel_indices, length(saved_palette))
	// Unpainted appendage layers stay in the draft but aren't saved.
	var/list/appendages = list()
	for(var/layer in 2 to length(layers))
		var/list/views = encode_layer(layer, saved_height, indices, pixel_indices, length(saved_palette))
		if(!length(views))
			continue
		var/list/entry = layers[layer]
		appendages["[length(appendages) + 1]"] = list("name" = entry["name"], "zone" = entry["zone"], "outer" = entry["outer"], "dirs" = views, "emissive" = entry["emissive"])
	drawing_cache = list("version" = custom_sprite_version(width, length(saved_palette), saved_height), "palette" = saved_palette, "tint" = tint, "dirs" = directions, "emissive" = emissive)
	if(length(appendages))
		drawing_cache["appendages"] = appendages
	return drawing_cache

/**
 * The drawing serialize_drawing() would give with `frames` as the views of `layer`, for a preview of
 * paint that isn't placed yet. The draft and its caches are left exactly as they were.
 */
/datum/sprite_editor_workspace/custom_sprite/proc/serialize_drawing_with(layer, list/frames)
	var/list/entry = layers[layer]
	var/list/data = entry["data"]
	var/list/edited = layer_edited(layer)
	var/list/was_edited = edited.Copy()
	var/list/cache = drawing_cache
	var/dirty = pixels_dirty
	var/list/colors = used_colors_cache
	entry["data"] = frames
	for(var/direction in frames)
		update_edited_direction(direction, layer)
	pixels_dirty = TRUE
	. = serialize_drawing()
	entry["data"] = data
	for(var/direction, painted in was_edited)
		edited[direction] = painted
	drawing_cache = cache
	pixels_dirty = dirty
	used_colors_cache = colors

/// One layer's painted views as saved: its bottom `saved_height` rows, as palette indexes. `pixel_indices` caches each pixel value's index across layers.
/datum/sprite_editor_workspace/custom_sprite/proc/encode_layer(layer, saved_height, list/indices, list/pixel_indices, palette_size)
	. = list()
	var/list/edited = layer_edited(layer)
	for(var/direction, frame in layers[layer]["data"])
		if(!edited[direction])
			continue
		var/list/pixels = list()
		for(var/y in height - saved_height + 1 to height)
			for(var/pixel in frame[y])
				var/index = istext(pixel) ? pixel_indices[pixel] : "0"
				if(!index)
					index = !endswith(pixel, "00") ? indices[LOWER_TEXT(copytext(pixel, 1, 8))] : null
					pixel_indices[pixel] = index || "0"
				pixels += index || "0"
		.[direction] = custom_sprite_encode_grid(jointext(pixels, ""), palette_size, width * saved_height)

/// Whether any layer has paint in the top `rows` rows of any view.
/datum/sprite_editor_workspace/custom_sprite/proc/paint_above(rows)
	for(var/layer in 1 to length(layers))
		var/list/edited = layer_edited(layer)
		for(var/direction, frame in layers[layer]["data"])
			if(!edited[direction])
				continue
			for(var/y in 1 to rows)
				for(var/pixel in frame[y])
					if(!endswith(pixel, "00"))
						return TRUE
	return FALSE

/// An explicit clear erases one layer's whole view, including pixels outside the current body bounds.
/datum/sprite_editor_workspace/custom_sprite/proc/clear_direction(direction, layer = 1)
	if(!istext(direction) || !valid_layer(layer) || !layer_edited(layer)[direction])
		return FALSE
	var/list/points = list()
	var/list/frame = layers[layer]["data"][direction]
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
	. = new_transaction(list("type" = "eraser", "layer" = layer, "layerId" = layers[layer]["id"], "dir" = direction, "points" = points))
	draw_bounds = previous_bounds
	draw_mask = previous_mask

/// Keep only validated input; history metadata belongs to the server.
/datum/sprite_editor_workspace/proc/sanitize_transaction(list/input)
	var/list/transaction = list("type" = input["type"])
	if(input["type"] != "addLayer")
		transaction["layer"] = input["layer"]
	switch(input["type"])
		if("pencil", "eraser", "bucket", "move")
			transaction["dir"] = input["dir"]
			if(input["type"] in list("pencil", "bucket"))
				transaction["color"] = input["color"]
			if(input["type"] == "bucket")
				transaction["point"] = input["point"]
			else
				transaction["points"] = input["points"]
		if("renameLayer")
			transaction["newName"] = input["newName"]
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

/// Also swaps which regions the step replaced outright.
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

/// Pixels of unlocked regions inside the view's bounds. Unlike other drawings, the eraser stays inside them too.
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
	masked_fill(transaction, region_map?[direction], region_at(point[1], point[2], direction))

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
 * Returns TRUE, replaced or already identical: regions may hold more than CUSTOM_SPRITE_MAX_COLORS
 * colors between them (see update_palette()), so no replacement is refused for its colors.
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
	return record_step(list("type" = "replace", "name" = name, "replaced" = replaced, "hair_old" = hair_context, "hair_new" = hair_context, "emissive_old" = emissive_old, "emissive_new" = emissive_new, "tint_old" = tint, "tint_new" = tint, "markings_old" = markings_context, "markings_new" = new_markings_context, "resets_old" = resets, "resets_new" = new_resets), check_palette = TRUE)

#undef NOTE_COLOR
