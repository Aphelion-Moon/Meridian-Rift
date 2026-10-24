/**
 * A graffiti piece being painted: one view of up to GRAFFITI_MAX_LAYERS layers, in colours that may be translucent.
 *
 * The layers are alike. Each has its own name, glow and id ("l1", "l2", ...), the bottom one included, so none of the
 * hair's rules for its base layer apply. Layer changes are custom sprite history steps, so undo covers them. The piece
 * keeps no palette: it takes its colours from its paint when it saves, at most GRAFFITI_MAX_COLORS of them. Every change
 * counts the pixels of each colour, so checking a stroke's colour never reads the canvas.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti
	dirs = 1
	color_mode = SPRITE_EDITOR_COLOR_MODE_RGBA
	/// The number the next layer's id takes. Ids are never reused in a draft, so the window's choice of layer survives undo.
	var/next_layer_id = 1
	/// Pixel value -> how many pixels of all the layers hold it, for each value the paint uses; transparent pixels aren't
	/// counted. In the order the layers first use them when counted afresh, then as new values come.
	var/list/color_counts
	/// Layer id -> its layer_records() record, kept until the layer's pixels or glow change, so a surface session's
	/// composite reads only the layers painted since the last one. Studio sessions never composite, so never fill it.
	var/list/layer_record_cache
	/// The draw mask as a compact stroke mask's slots, a bit for each pixel that takes paint, as a poster's canvas has it,
	/// or null. A stroke is cut down to it as its points are read (stroke_mask_slots()), so none needs checking.
	var/list/draw_mask_bits

/**
 * Opens a piece with a layer for each of its own, or a blank one-tile piece.
 *
 * Arguments:
 * - piece: A canonical piece, as graffiti_validate_piece() returns it, or null. A piece without layers opens with one
 *   blank layer.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/New(list/piece)
	..(null, list())
	width = piece?["width"] == GRAFFITI_WIDE_WIDTH ? GRAFFITI_WIDE_WIDTH : GRAFFITI_WIDTH
	// The piece's layers replace the base constructor's blank one.
	layers = list()
	var/list/colors = piece?["palette"]
	// Grid character -> pixel value: opaque colours gain their alpha, and paint that shows nothing is transparent.
	var/list/pixel_values = list()
	for(var/character, index in custom_sprite_index_values())
		if(index > length(colors))
			break
		var/color = index ? colors[index] : null
		if(length(color) == 7)
			color += "ff"
		pixel_values[character] = (color && !endswith(color, "00")) ? color : "#00000000"
	for(var/list/layer as anything in piece?["layers"])
		var/list/entry = layer_entry(layer["name"], layer["glow"])
		layers += list(entry)
		var/grid = custom_sprite_decode_grid(layer["grid"], length(colors), width * GRAFFITI_HEIGHT)
		if(!grid)
			continue
		var/list/frame = entry["data"]["2"]
		for(var/pixel_row in 1 to GRAFFITI_HEIGHT)
			var/list/row = frame[pixel_row]
			var/position = (pixel_row - 1) * width
			for(var/column in 1 to width)
				row[column] = pixel_values[copytext(grid, position + column, position + column + 1)]
		update_edited_direction("2", length(layers))
	if(!length(layers))
		layers += list(layer_entry("Layer 1", FALSE))
	pixels_changed()

/**
 * Builds a blank layer under the next id, not yet in the piece.
 *
 * Arguments:
 * - name: The layer's name, already clean.
 * - glow: Whether its paint glows.
 *
 * Returns:
 * - list: The layer entry.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_entry(name, glow)
	return list("name" = name, "visible" = TRUE, "data" = create_layer_data(), "id" = "l[next_layer_id++]", "emissive" = list("2" = glow ? TRUE : FALSE), "edited" = list("2" = FALSE))

/**
 * Returns how many layers the piece has.
 *
 * Returns:
 * - number: 1 to GRAFFITI_MAX_LAYERS.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_count()
	return length(layers)

/**
 * Returns a layer's one view.
 *
 * Arguments:
 * - index: The layer, 1 at the bottom.
 *
 * Returns:
 * - list: The frame itself, its pixel rows from the top.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_view(index)
	return layers[index]["data"]["2"]

/**
 * Returns whether a layer's paint glows.
 *
 * Arguments:
 * - index: The layer.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_glow(index)
	return layers[index]["emissive"]["2"]

/**
 * Returns the layers as the editor's window lists them.
 *
 * Returns:
 * - list: list("id", "name", "glow") for each layer, bottom first.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_entries()
	. = list()
	for(var/index in 1 to length(layers))
		. += list(list("id" = layers[index]["id"], "name" = layers[index]["name"], "glow" = layer_glow(index)))

/**
 * Adds a blank layer on top, as an undoable step.
 *
 * Returns:
 * - number: The new layer's index.
 * - 0: The piece already has GRAFFITI_MAX_LAYERS layers.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/add_layer()
	if(length(layers) >= GRAFFITI_MAX_LAYERS)
		return 0
	var/index = length(layers) + 1
	record_step(list("type" = "addAppendage", "name" = "Add layer", "index" = index, "entry" = layer_entry("Layer [index]", FALSE)))
	return index

/**
 * Removes a layer, paint and all, as an undoable step.
 *
 * Arguments:
 * - index: The layer.
 *
 * Returns:
 * - TRUE/FALSE: FALSE when `index` names no layer, or names the only one.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/remove_layer(index)
	if(!valid_layer(index) || length(layers) <= 1)
		return FALSE
	return record_step(list("type" = "removeAppendage", "name" = "Remove layer", "index" = index, "entry" = layers[index]))

/**
 * Renames a layer as an undoable step, cleaning the name as a saved piece's layer names are.
 *
 * Arguments:
 * - index: The layer.
 * - name: The player's text.
 *
 * Returns:
 * - TRUE/FALSE: FALSE when `index` names no layer, nothing is left of the name once cleaned, or it wouldn't change.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/rename_layer(index, name)
	name = graffiti_clean_text(name, GRAFFITI_MAX_LAYER_NAME)
	if(!valid_layer(index) || !length(name) || layers[index]["name"] == name)
		return FALSE
	return record_step(list("type" = "setAppendage", "name" = "Rename layer", "index" = index, "field" = "name", "old" = layers[index]["name"], "new" = name))

/**
 * Turns a layer's glow on or off as an undoable step.
 *
 * Arguments:
 * - index: The layer.
 * - glow: Whether its paint glows.
 *
 * Returns:
 * - TRUE/FALSE: FALSE when `index` names no layer or the glow wouldn't change.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/set_layer_glow(index, glow)
	glow = glow ? TRUE : FALSE
	if(!valid_layer(index) || layer_glow(index) == glow)
		return FALSE
	return record_step(list("type" = "setAppendage", "name" = "Change layer glow", "index" = index, "field" = "emissive", "old" = layers[index]["emissive"], "new" = list("2" = glow)))

/**
 * Swaps a layer with the one above or below it, as an undoable step.
 *
 * Arguments:
 * - index: The layer.
 * - delta: 1 to move it up, -1 to move it down.
 *
 * Returns:
 * - TRUE/FALSE: FALSE when `index` names no layer, `delta` is neither, or no layer lies that way.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/move_layer(index, delta)
	if(!valid_layer(index) || !(delta in list(-1, 1)) || !valid_layer(index + delta))
		return FALSE
	return record_step(list("type" = "swapLayers", "name" = "Move layer", "a" = index, "b" = index + delta))

/**
 * Also applies the layer swap move_layer() records. A swap undoes itself, so both directions swap.
 *
 * Arguments:
 * - transaction: The step.
 * - forward: Whether it is applied or reversed.
 *
 * Returns:
 * - TRUE/FALSE: Whether the step was one this workspace records itself.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/apply_step(list/transaction, forward)
	if(transaction["type"] != "swapLayers")
		// A layer's glow is in its record.
		if(transaction["type"] == "setAppendage" && transaction["field"] == "emissive")
			LAZYREMOVE(layer_record_cache, layers[transaction["index"]]["id"])
		return ..()
	layers.Swap(transaction["a"], transaction["b"])
	pixels_changed()
	return TRUE

/**
 * Also counts the colours afresh when any view may have changed, as opening a piece, a width change or a layer swap
 * leave them. A change to one view is a step, which transact() or reverse_transact() counts.
 *
 * Arguments:
 * - direction: The view that changed, or null for all of them.
 * - layer: The layer that changed.
 * - points: The step's points, when only they changed.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/pixels_changed(direction, layer = 1, list/points = null)
	..()
	if(!direction)
		layer_record_cache = null
		count_colors()
		return
	LAZYREMOVE(layer_record_cache, layers[layer]["id"])

/// Also counts the colours afresh: a layer came or went with its paint.
/datum/sprite_editor_workspace/custom_sprite/graffiti/layers_changed()
	..()
	layer_record_cache = null
	count_colors()

/**
 * Counts every layer's pixels of each colour afresh, in the order the layers first use the colours: layer 1 row by row
 * from the top, then each layer above it.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/count_colors()
	color_counts = list()
	for(var/index in 1 to length(layers))
		if(!layer_edited(index)["2"])
			continue
		for(var/list/row as anything in layer_view(index))
			for(var/pixel in row)
				if(pixel != "#00000000")
					color_counts[pixel] += 1

/**
 * Counts the pixels a stroke, fill, erasure or placement changed: each point keeps the value it replaced. The other
 * steps change whole layers, which count_colors() counts.
 *
 * Arguments:
 * - transaction: The step, as the history keeps it.
 * - forward: Whether it was applied rather than reversed.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/count_points(list/transaction, forward)
	var/kind = transaction["type"]
	if(!(kind in list("pencil", "eraser", "bucket", "move")))
		return
	// Pixel value -> how many more pixels hold it once the step is applied.
	var/list/changes = list()
	if(kind == "move")
		for(var/list/point as anything in transaction["points"])
			changes[point[3]] -= 1
			changes[point[4]] += 1
	else
		// One value lands on every point. What it replaces runs along rows, so it is counted a run at a time: a stroke's
		// points can number thousands.
		var/painted = kind == "eraser" ? "#00000000" : transaction["color"]
		var/landed = 0
		var/run_value
		var/run_length = 0
		for(var/list/point as anything in transaction["points"])
			var/before = point[3]
			if(before == painted)
				continue
			landed++
			if(before == run_value)
				run_length++
				continue
			if(run_length)
				changes[run_value] -= run_length
			run_value = before
			run_length = 1
		if(run_length)
			changes[run_value] -= run_length
		changes[painted] += landed
	changes -= "#00000000"
	for(var/pixel, change in changes)
		var/count = color_counts[pixel] + (forward ? change : -change)
		if(count > 0)
			color_counts[pixel] = count
		else
			color_counts -= pixel

/**
 * Whether a stroke names the layer it paints by its id as well as its place. The bottom layer is named like any other,
 * so a stroke meant for a layer that undo just moved can't land on another.
 *
 * Arguments:
 * - transaction: The stroke.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/stroke_layer_matches(list/transaction)
	var/layer = transaction["layer"]
	return valid_layer(layer) && transaction["layerId"] == layers[layer]["id"]

/**
 * Returns which views of a layer have paint. Every layer keeps its own map, the bottom one included, so the map moves
 * with its layer. edited_directions only serves the base constructor's blank layer, which New() replaces.
 *
 * Arguments:
 * - layer: The layer.
 *
 * Returns:
 * - list: Direction -> whether that view has paint.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/layer_edited(layer)
	return layers[layer]["edited"] || edited_directions

/**
 * Returns the colours the paint uses, read from color_counts. Unlike a drawing's, translucent colours keep their alpha,
 * as graffiti_color() writes them.
 *
 * Returns:
 * - list: The colours in color_counts' order, a list the caller may change.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/used_colors()
	. = list()
	for(var/pixel in color_counts)
		. += copytext(pixel, 8) == "ff" ? copytext(pixel, 1, 8) : pixel

/**
 * Takes any brush colour that shows, until the paint uses GRAFFITI_MAX_COLORS colours: then only those.
 *
 * Arguments:
 * - source: This workspace.
 * - color: A well-formed `#rrggbb` or `#rrggbbaa` colour, in either case.
 *
 * Returns:
 * - COLOR_IS_INVALID: The colour paints nothing, or would be one colour too many.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/validate_palette_color(datum/source, color)
	var/canonical = graffiti_color(color)
	if(!canonical)
		return COLOR_IS_INVALID
	if(!color_counts[length(canonical) == 7 ? "[canonical]ff" : canonical] && length(color_counts) >= GRAFFITI_MAX_COLORS)
		return COLOR_IS_INVALID

/**
 * Also writes the colours a placement lands as their canonical pixels, and refuses a placement that would take the paint
 * past GRAFFITI_MAX_COLORS colours, and, in a surface session, one that adds paint. A stroke brings one colour, but a
 * placement can bring several, so each one it lands counts, whatever it paints over.
 *
 * A surface is painted by hand, so its pieces show the staged reveal's work rather than prepared art. A placement there
 * may move, turn, mirror or cut the session's own paint, which never lands more of a colour than it lifts or covers; a
 * paste does, and is refused with a notice.
 *
 * Arguments:
 * - transaction: The placement.
 *
 * Returns:
 * - TRUE/FALSE: Whether anything changes, within the colour limit and, on a surface, without adding paint.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/prepare_selection_placement(list/transaction)
	if(!..())
		return FALSE
	// Value sent -> the pixel it paints, as graffiti_color() takes it: a pasted colour may have any alpha.
	var/list/pixels = list("#00000000" = "#00000000")
	// The pixel values it lands, once each.
	var/list/seen = list()
	// Pixel value -> how many more pixels of it the placement lands than it lifts or covers.
	var/list/counts = list()
	for(var/list/point as anything in transaction["points"])
		var/pixel = pixels[point[4]]
		if(!pixel)
			pixel = graffiti_color(point[4])
			pixel = length(pixel) == 7 ? "[pixel]ff" : pixel
			pixels[point[4]] = pixel
		point[4] = pixel
		seen[point[4]] = TRUE
		counts[point[4]] += 1
		counts[point[3]] -= 1
	seen -= "#00000000"
	var/list/colors = used_colors()
	for(var/pixel in seen)
		colors |= graffiti_color(pixel)
	if(length(colors) > GRAFFITI_MAX_COLORS)
		return FALSE
	var/datum/custom_sprite_editor/graffiti/editor = owner_ref?.resolve()
	if(!istype(editor) || editor.kind != "surface")
		return TRUE
	counts -= "#00000000"
	for(var/pixel, count in counts)
		if(count > 0)
			editor.notify("Paste isn't allowed on a surface. Paint it by hand.")
			return FALSE
	return TRUE

/**
 * Returns draw_mask_bits, which a stroke's compact mask is cut down to as it is read: a check of each point costs about
 * as much as the rest of the stroke (measured). A canvas with a draw mask holds no paint outside it, so an eraser loses
 * nothing by it.
 *
 * Returns:
 * - list: The slots, for a one-tile canvas with a draw mask.
 * - null: The canvas paints everywhere.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/stroke_mask_slots()
	return (draw_mask_bits && length(draw_mask_bits) == CEILING(width * height / 6, 1)) ? draw_mask_bits : null

/// A stroke read from a compact mask cut down to the draw mask lands only where paint may go.
/datum/sprite_editor_workspace/custom_sprite/graffiti/all_points_allowed(direction)
	return (mask_stroke && stroke_mask_slots()) || ..()

/**
 * Also writes a stroke's colour as the nine-character pixel it paints, in graffiti_color()'s form, so every pixel value
 * stays canonical.
 *
 * Arguments:
 * - input: The checked transaction.
 *
 * Returns:
 * - list: The transaction to apply.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/sanitize_transaction(list/input)
	. = ..()
	var/color = graffiti_color(.["color"])
	if(color)
		.["color"] = length(color) == 7 ? "[color]ff" : color

/**
 * Fills by setting each pixel to the fill colour, as the pencil paints: translucent paint blends only when the layers
 * merge. Anything else is applied as a custom sprite workspace applies it. Either way, what changed is counted.
 *
 * Arguments:
 * - transaction: The step.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/transact(list/transaction)
	if(transaction["type"] != "bucket")
		..()
		count_points(transaction, TRUE)
		return
	var/direction = transaction["dir"]
	var/layer = transaction["layer"]
	var/color = transaction["color"]
	var/list/frame = layers[layer]["data"][direction]
	for(var/list/point as anything in transaction["points"])
		frame[point[2] + 1][point[1] + 1] = color
	var/list/edited = layer_edited(layer)
	edited[direction] = length(transaction["points"]) > 0 || edited[direction]
	pixels_changed(direction, layer, transaction["points"])
	count_points(transaction, TRUE)

/**
 * Also counts what reversing a step changed.
 *
 * Arguments:
 * - transaction: The step.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/reverse_transact(list/transaction)
	..()
	count_points(transaction, FALSE)

/**
 * Checks a colour the player wants to paint with. The piece keeps no palette, so this only says whether the colour can
 * be painted now.
 *
 * Arguments:
 * - color: `#rrggbb` or `#rrggbbaa` text, in either case.
 *
 * Returns:
 * - text: The colour, as graffiti_color() writes it.
 * - null: It isn't a colour, it paints nothing, or it is new and the paint already uses GRAFFITI_MAX_COLORS colours.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/add_color(color)
	var/canonical = graffiti_color(color)
	return (canonical && is_valid_color(canonical)) ? canonical : null

/**
 * Makes the canvas one or two tiles wide where it stands: columns come and go on the right, so paint keeps its place
 * and every layer keeps its id. Paint in columns that go is lost, which has_paint_right_half() lets the caller ask
 * about first. History can't span two widths, so it starts over.
 *
 * Arguments:
 * - canvas_width: GRAFFITI_WIDTH or GRAFFITI_WIDE_WIDTH.
 *
 * Returns:
 * - TRUE/FALSE: FALSE for any other width, or for the width the canvas already has.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/set_width(canvas_width)
	if(!(canvas_width in list(GRAFFITI_WIDTH, GRAFFITI_WIDE_WIDTH)) || canvas_width == width)
		return FALSE
	var/list/blank = list()
	for(var/column in 1 to GRAFFITI_WIDE_WIDTH - GRAFFITI_WIDTH)
		blank += "#00000000"
	for(var/index in 1 to length(layers))
		for(var/list/row as anything in layer_view(index))
			if(canvas_width > width)
				row += blank
			else
				row.Cut(canvas_width + 1)
		update_edited_direction("2", index)
	width = canvas_width
	undo_stack.Cut()
	undo_names.Cut()
	redo_stack.Cut()
	redo_names.Cut()
	saved_transactions = list()
	pixels_changed()
	return TRUE

/**
 * Returns the layers decoded for graffiti_flatten_records(), read straight from their frames. They flatten to the art
 * graffiti_flatten() makes of the piece serialize_piece() returns, without encoding the layers and decoding them again.
 * Each layer's record is kept until it changes (layer_record_cache).
 *
 * Returns:
 * - list: A graffiti_art_decode() record for each layer, bottom first: the colours it paints, the index of each pixel's
 *   colour, 0 where transparent, and its glow on every pixel.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/layer_records()
	. = list()
	var/pixel_count = width * GRAFFITI_HEIGHT
	var/list/unlit = graffiti_unlit_glow(width)[2]
	var/list/lit
	for(var/index in 1 to length(layers))
		var/id = layers[index]["id"]
		var/list/record = layer_record_cache?[id]
		if(record)
			. += list(record)
			continue
		var/list/colors = list()
		var/list/indices = unlit.Copy()
		if(layer_edited(index)["2"])
			// Pixel value -> its index in colors.
			var/list/found = list()
			var/position = 0
			for(var/list/row as anything in layer_view(index))
				for(var/pixel in row)
					position++
					if(pixel == "#00000000")
						continue
					var/spot = found[pixel]
					if(!spot)
						colors += copytext(pixel, 8) == "ff" ? copytext(pixel, 1, 8) : pixel
						spot = length(colors)
						found[pixel] = spot
					indices[position] = spot
		var/glow = layer_glow(index)
		if(glow && !lit)
			lit = new /list(pixel_count)
			for(var/position in 1 to pixel_count)
				lit[position] = 1
		record = list(colors, indices, glow ? lit : unlit)
		LAZYSET(layer_record_cache, id, record)
		. += list(record)

/**
 * Returns whether any layer has paint in the right tile's columns, which narrowing the canvas would lose.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/has_paint_right_half()
	for(var/index in 1 to length(layers))
		if(!layer_edited(index)["2"])
			continue
		for(var/list/row as anything in layer_view(index))
			for(var/column in GRAFFITI_WIDTH + 1 to width)
				if(row[column] != "#00000000")
					return TRUE
	return FALSE

/**
 * Returns the piece as the library saves it: every layer, painted or not, each grid indexing a palette of the colours
 * the paint uses, in the order the layers first use them: layer 1 row by row from the top, then each layer above it. A
 * two-tile canvas with nothing painted on its right tile saves one tile wide, though the canvas keeps its width.
 *
 * Arguments:
 * - name: The piece's name.
 * - description: Its description.
 *
 * Returns:
 * - list: The canonical piece, as graffiti_validate_piece() would return it.
 * - null: Nothing is painted, or the paint uses more than GRAFFITI_MAX_COLORS colours.
 */
/datum/sprite_editor_workspace/custom_sprite/graffiti/proc/serialize_piece(name, description)
	if(!length(color_counts) || length(color_counts) > GRAFFITI_MAX_COLORS)
		return null
	var/columns = width == GRAFFITI_WIDE_WIDTH && !has_paint_right_half() ? GRAFFITI_WIDTH : width
	var/list/colors = list()
	// Pixel value -> its grid character, given as the colours come.
	var/list/characters = list("#00000000" = "0")
	var/list/grids = list()
	for(var/index in 1 to length(layers))
		var/list/grid = list()
		for(var/list/row as anything in layer_view(index))
			for(var/column in 1 to columns)
				var/pixel = row[column]
				var/character = characters[pixel]
				if(!character)
					colors += copytext(pixel, 8) == "ff" ? copytext(pixel, 1, 8) : pixel
					character = custom_sprite_canvas_code(length(colors), 1)
					characters[pixel] = character
				grid += character
		grids += jointext(grid, "")
	var/list/entries = list()
	for(var/index in 1 to length(layers))
		entries += list(list("name" = layers[index]["name"], "glow" = layer_glow(index), "grid" = custom_sprite_encode_grid(grids[index], length(colors), columns * GRAFFITI_HEIGHT)))
	return list("name" = graffiti_clean_text(name, GRAFFITI_MAX_NAME) || "Untitled", "description" = graffiti_clean_text(description, GRAFFITI_MAX_DESCRIPTION), "width" = columns, "palette" = colors, "layers" = entries)
