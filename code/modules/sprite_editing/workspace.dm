/datum/sprite_editor_workspace
	var/width
	var/height
	var/dirs
	var/backdrop

	var/color_mode = SPRITE_EDITOR_COLOR_MODE_RGBA
	/// A bitfield specifying whether certain functions of the sprite editor should be performed if the corresponding ui actions are received - used to prevent href exploitation
	var/config_flags = ALL
	/// A bitfield specifying what tools we are allowed to use in the sprite editor
	var/tool_flags = ALL

	var/list/layers
	var/list/undo_stack = list()
	var/list/undo_names = list()
	var/list/redo_stack = list()
	var/list/redo_names = list()

/datum/sprite_editor_workspace/New(
	width = 32,
	height = 32,
	dirs = 1,
	backdrop = null,
	color_mode = SPRITE_EDITOR_COLOR_MODE_RGBA,
	config_flags = ALL,
	tool_flags = ALL,
	initial_layer_color = null)
	. = ..()
	src.width = width
	src.height = height
	src.dirs = dirs
	src.color_mode = color_mode
	src.config_flags = config_flags
	src.tool_flags = tool_flags
	src.backdrop = backdrop
	layers = list(list("name" = "Background", visible = TRUE, "data" = create_layer_data(initial_layer_color)))

/datum/sprite_editor_workspace/proc/copy(preserve_history = FALSE)
	var/datum/sprite_editor_workspace/new_workspace = new(width, height, dirs, backdrop, color_mode, config_flags, tool_flags) // APHELION EDIT CHANGE - ORIGINAL: var/datum/sprite_editor_workspace/new_workspace = new(width, height, dirs, color_mode, config_flags, tool_flags)
	new_workspace.layers = deep_copy_list_alt(layers)
	if(preserve_history)
		new_workspace.undo_names = undo_names.Copy()
		new_workspace.undo_stack = deep_copy_list_alt(undo_stack)
		new_workspace.redo_names = redo_names.Copy()
		new_workspace.redo_stack = deep_copy_list_alt(redo_stack)
	return new_workspace

/datum/sprite_editor_workspace/proc/create_layer_data(color = "#00000000")
	var/list/out = list()
	for(var/i in 1 to dirs)
		var/list/layer = list()
		for(var/y in 1 to height)
			var/list/row = list()
			for(var/x in 1 to width)
				row += color
			layer += list(row)
		out["[GLOB.alldirs_dmi_order[i]]"] = layer
	return out

/**
 * Take a new transaction, perform it, and optionally add it to the undo history.
 * Returns TRUE if the transaction was valid.
 */
/datum/sprite_editor_workspace/proc/new_transaction(transaction)
	if(!can_transact(transaction))
		return
	transaction = sanitize_transaction(transaction) // APHELION EDIT ADDITION
	preprocess_new_transaction(transaction)
	transact(transaction)
	if(!(config_flags & SPRITE_EDITOR_ALLOW_UNDO))
		return TRUE
	redo_stack.Cut()
	redo_names.Cut()
	undo_stack += list(transaction)
	undo_names += transaction["name"]
	return TRUE

/datum/sprite_editor_workspace/proc/undo(count = 1) // APHELION EDIT CHANGE - ORIGINAL: /datum/sprite_editor_workspace/proc/undo()
	if(!(config_flags & SPRITE_EDITOR_ALLOW_UNDO))
		return
	// if(length(undo_stack)) // APHELION EDIT REMOVAL
	// APHELION EDIT ADDITION START - Validate history jumps.
	if(!isnum(count) || count < 1)
		return
	for(var/i in 1 to min(round(count), length(undo_stack)))
	// APHELION EDIT ADDITION END
		pop(undo_names)
		var/transaction = pop(undo_stack)
		reverse_transact(transaction)
		redo_stack += list(transaction)
		redo_names += transaction["name"]

/datum/sprite_editor_workspace/proc/redo(count = 1) // APHELION EDIT CHANGE - ORIGINAL: /datum/sprite_editor_workspace/proc/redo()
	if(!(config_flags & SPRITE_EDITOR_ALLOW_UNDO))
		return
	// if(length(redo_stack)) // APHELION EDIT REMOVAL
	// APHELION EDIT ADDITION START - Validate history jumps.
	if(!isnum(count) || count < 1)
		return
	for(var/i in 1 to min(round(count), length(redo_stack)))
	// APHELION EDIT ADDITION END
		pop(redo_names)
		var/transaction = pop(redo_stack)
		transact(transaction)
		undo_stack += list(transaction)
		undo_names += transaction["name"]

/datum/sprite_editor_workspace/proc/toggle_layer_visible(layer)
	if(!(config_flags & SPRITE_EDITOR_ALLOW_LAYERS))
		return
	if(!isnum(layer) || round(layer) != layer) // APHELION EDIT CHANGE - ORIGINAL: if(!isnum(layer))
		return
	if(layer < 1 || layer > length(layers))
		return
	layers[layer]["visible"] = !layers[layer]["visible"]

/datum/sprite_editor_workspace/proc/is_valid_color(color)
	// APHELION EDIT ADDITION START - split_color must not receive malformed UI input.
	if(!istext(color) || !(length(color) in list(7, 9)) || copytext(color, 1, 2) != "#")
		return FALSE
	if(sanitize_hexcolor(color, length(color) - 1, TRUE, "invalid") != LOWER_TEXT(color))
		return FALSE
	// APHELION EDIT ADDITION END
	if(SEND_SIGNAL(src, COMSIG_SPRITE_EDITOR_VALIDATE_COLOR, color))
		return FALSE
	var/list/rgb_color = split_color(color)
	switch(color_mode)
		if(SPRITE_EDITOR_COLOR_MODE_RGBA)
			return TRUE
		if(SPRITE_EDITOR_COLOR_MODE_RGB)
			return rgb_color[4] == 255
		if(SPRITE_EDITOR_COLOR_MODE_GREYSCALE)
			return rgb_color[1] == rgb_color[2] && rgb_color[2] == rgb_color[3]
		else
			return TRUE

/datum/sprite_editor_workspace/proc/can_transact(list/transaction)
	// APHELION EDIT ADDITION START - Validate before indexing any layer or frame.
	if(!islist(transaction))
		return FALSE
	var/transaction_type = transaction["type"]
	var/layer = transaction["layer"]
	if(transaction_type == "addLayer")
		return config_flags & SPRITE_EDITOR_ALLOW_LAYERS
	if(!isnum(layer) || round(layer) != layer || layer < 1 || layer > length(layers))
		return FALSE
	if(transaction_type in list("pencil", "eraser", "bucket"))
		var/direction = transaction["dir"]
		if(!istext(direction) || !(direction in layers[layer]["data"]))
			return FALSE
		if(transaction_type == "bucket")
			var/list/point = transaction["point"]
			if(!valid_point_pair(point) || !is_point_allowed(point[1], point[2], direction))
				return FALSE
			transaction["point"] = point.Copy()
		else
			var/list/points = transaction["points"]
			if(!islist(points) || length(points) > width * height)
				return FALSE
			var/list/filtered = list()
			var/list/seen = list()
			for(var/list/point as anything in points)
				if(!valid_point_pair(point))
					return FALSE
				var/x = point[1]
				var/y = point[2]
				if(!is_point_allowed(x, y, direction))
					continue
				if(!mask_stroke)
					if(seen["[x],[y]"])
						continue
					seen["[x],[y]"] = TRUE
				filtered += list(list(x, y))
			transaction["points"] = filtered
			if(!length(filtered))
				return FALSE
	// APHELION EDIT ADDITION END
	switch(transaction["type"])
		if("pencil")
			return tool_flags & SPRITE_EDITOR_TOOL_PENCIL && is_valid_color(transaction["color"])
		if("eraser")
			return tool_flags & SPRITE_EDITOR_TOOL_ERASER
		if("bucket")
			return tool_flags & SPRITE_EDITOR_TOOL_BUCKET && is_valid_color(transaction["color"])
		// APHELION EDIT ADDITION START
		if("move")
			return tool_flags & SPRITE_EDITOR_TOOL_SELECT && prepare_selection_move(transaction)
		// APHELION EDIT ADDITION END
		/* // APHELION EDIT REMOVAL START - Validate each layer operation and its boundaries.
		if("renameLayer", "moveLayerUp", "moveLayerDown", "flattenLayer", "addLayer", "deleteLayer")
			return config_flags & SPRITE_EDITOR_ALLOW_LAYERS
		*/ // APHELION EDIT REMOVAL END
		// APHELION EDIT ADDITION START - Validate each layer operation and its boundaries.
		if("renameLayer")
			return config_flags & SPRITE_EDITOR_ALLOW_LAYERS && istext(transaction["newName"]) && length(transaction["newName"]) <= 64
		if("moveLayerUp")
			return config_flags & SPRITE_EDITOR_ALLOW_LAYERS && layer < length(layers)
		if("moveLayerDown", "flattenLayer")
			return config_flags & SPRITE_EDITOR_ALLOW_LAYERS && layer > 1
		if("deleteLayer")
			return config_flags & SPRITE_EDITOR_ALLOW_LAYERS && length(layers) > 1
		// APHELION EDIT ADDITION END
		else // Invalid transaction type, probably from href exploitation
			return FALSE

/datum/sprite_editor_workspace/proc/preprocess_new_transaction(list/transaction)
	switch(transaction["type"])
		if("pencil", "eraser")
			var/layer = transaction["layer"]
			var/dir = transaction["dir"]
			var/list/points = transaction["points"]
			var/list/affected_frame = layers[layer]["data"][dir]
			for(var/point in points)
				var/x = point[1]+1
				var/y = point[2]+1
				point += affected_frame[y][x]
		if("bucket")
			var/layer = transaction["layer"]
			var/dir = transaction["dir"]
			var/list/affected_frame = layers[layer]["data"][dir]
			var/list/point = transaction["point"]
			var/x = point[1]+1
			var/y = point[2]+1
			transaction["points"] = flood_fill(affected_frame, x, y, width, height)
			// APHELION EDIT ADDITION START
			var/list/filtered = list()
			for(var/list/filled_point as anything in transaction["points"])
				if(is_point_allowed(filled_point[1], filled_point[2], dir))
					filtered += list(filled_point)
			transaction["points"] = filtered
			// APHELION EDIT ADDITION END
			transaction -= "point"
		// APHELION EDIT ADDITION START - Do not trust client undo values.
		if("renameLayer")
			transaction["oldName"] = layers[transaction["layer"]]["name"]
		// APHELION EDIT ADDITION END
		if("flattenLayer")
			var/layer = transaction["layer"]
			var/list/top_layer = layers[layer]
			var/list/bottom_layer = layers[layer-1]
			transaction["oldTop"] = top_layer
			transaction["oldBottom"] = deep_copy_list(bottom_layer)
		if("deleteLayer")
			var/layer = transaction["layer"]
			var/list/old_layer = layers[layer]
			transaction["oldLayer"] = old_layer

/datum/sprite_editor_workspace/proc/transact(list/transaction)
	switch(transaction["type"])
		if("pencil", "bucket")
			var/layer = transaction["layer"]
			var/dir = transaction["dir"]
			var/color = transaction["color"]
			var/list/points = transaction["points"]
			var/list/affected_frame = layers[layer]["data"][dir]
			for(var/list/point in points)
				var/x = point[1]+1
				var/y = point[2]+1
				affected_frame[y][x] = blend_color(affected_frame[y][x], color)
		if("eraser", "move") // APHELION EDIT CHANGE - ORIGINAL: if("eraser")
			var/layer = transaction["layer"]
			var/dir = transaction["dir"]
			var/list/points = transaction["points"]
			var/list/affected_frame = layers[layer]["data"][dir]
			for(var/list/point in points)
				var/x = point[1]+1
				var/y = point[2]+1
				affected_frame[y][x] = transaction["type"] == "move" ? point[4] : "#00000000" // APHELION EDIT CHANGE - ORIGINAL: affected_frame[y][x] = "#00000000"
		if("renameLayer")
			var/layer = transaction["layer"]
			var/new_name = transaction["newName"]
			layers[layer]["name"] = new_name
		if("moveLayerUp")
			var/layer = transaction["layer"]
			layers.Swap(layer, layer+1)
		if("moveLayerDown")
			var/layer = transaction["layer"]
			layers.Swap(layer, layer-1)
		if("flattenLayer")
			var/layer = transaction["layer"]
			var/list/top_layer = layers[layer]
			var/list/bottom_layer = layers[layer-1]
			for(var/dir in bottom_layer["data"]) // APHELION EDIT CHANGE - ORIGINAL: for(var/dir in 1 to dirs)
				for(var/y in 1 to height)
					for(var/x in 1 to width)
						bottom_layer["data"][dir][y][x] = blend_color(bottom_layer["data"][dir][y][x], top_layer["data"][dir][y][x]) // APHELION EDIT CHANGE - ORIGINAL: bottom_layer["[dir]"][y][x] = blend_color(bottom_layer["[dir]"][y][x], top_layer["[dir]"][y][x])
			layers.Cut(layer, layer+1)
		if("addLayer")
			var/layer_name = "New Layer"
			var/dupe_count = 1
			for(var/list/layer in layers)
				if(layer["name"] == layer_name)
					layer_name = "New Layer [++dupe_count]"
			layers += list(list("name" = layer_name, "visible" = TRUE, "data" = create_layer_data()))
		if("deleteLayer")
			var/layer = transaction["layer"]
			layers.Cut(layer, layer+1)

/datum/sprite_editor_workspace/proc/reverse_transact(list/transaction)
	switch(transaction["type"])
		if("pencil", "eraser", "bucket", "move") // APHELION EDIT CHANGE - ORIGINAL: if("pencil", "eraser", "bucket")
			var/layer = transaction["layer"]
			var/dir = transaction["dir"]
			var/list/points = transaction["points"]
			var/list/affected_frame = layers[layer]["data"][dir]
			for(var/list/point in points)
				var/x = point[1]+1
				var/y = point[2]+1
				affected_frame[y][x] = point[3]
		if("renameLayer")
			var/layer = transaction["layer"]
			var/old_name = transaction["oldName"]
			layers[layer]["name"] = old_name
		if("moveLayerUp")
			var/layer = transaction["layer"]
			layers.Swap(layer, layer+1)
		if("moveLayerDown")
			var/layer = transaction["layer"]
			layers.Swap(layer, layer-1)
		if("flattenLayer")
			var/layer = transaction["layer"]
			var/top_layer = transaction["oldTop"]
			var/bottom_layer = transaction["oldBottom"]
			var/bottom_layer_index = layer-1
			var/old_visibility = layers[bottom_layer_index]["visible"]
			layers[bottom_layer_index] = bottom_layer
			layers[bottom_layer_index]["visible"] = old_visibility
			layers.Insert(layer, list(top_layer)) // APHELION EDIT CHANGE - ORIGINAL: layers.Insert(layer, top_layer)
		if("addLayer")
			pop(layers)
		if("deleteLayer")
			var/layer = transaction["layer"]
			var/old_layer = transaction["oldLayer"]
			layers.Insert(layer, list(old_layer)) // APHELION EDIT CHANGE - ORIGINAL: layers.Insert(layer, old_layer)

/datum/sprite_editor_workspace/proc/sprite_editor_ui_data()
	return list(
		"colorMode" = color_mode,
		"toolFlags" = tool_flags,
		"undoStack" = undo_names,
		"redoStack" = redo_names,
		"sprite" = list(
			"width" = width,
			"height" = height,
			"dirs" = dirs,
			"backdrop" = backdrop,
			"layers" = layers,
		)
	)

/// Get a reference to the pixel data for the first layer of the given dir
/datum/sprite_editor_workspace/proc/get_first_layer_pixel_data(dir = SOUTH)
	return layers[1]["data"]["[dir]"]

/datum/sprite_editor_workspace/proc/to_icon()
	var/metadata = json_encode(list(
		"width" = width,
		"height" = height,
		"states" = list(list(
			"name" = "",
			"dirs" = dirs,
		)),
	))
	var/list/ideal_dims = calculate_optimal_icon_grid_dimensions(width, height, dirs)
	var/grid_width = ideal_dims[1]
	var/grid_height = ideal_dims[2]
	var/file_width = width * grid_width
	var/file_height = height * grid_height
	var/layer_count = length(layers)
	var/list/temp_paths = list() // APHELION EDIT CHANGE - ORIGINAL: var/temp_file_prefix = copytext(REF(src), 2, -1)
	for(var/i in 1 to layer_count)
		var/list/layer_frames = list()
		for(var/dir_index in 1 to dirs)
			layer_frames += list(layers[i]["data"]["[GLOB.alldirs_dmi_order[dir_index]]"])
		var/pixels = reorder_pixels(width, height, grid_width, grid_height, layer_frames)
		var/temp_path = "tmp/sprite_editor_[md5("[metadata]|[pixels]")].dmi" // APHELION EDIT CHANGE - ORIGINAL: var/temp_path = "tmp/[temp_file_prefix]_layer[i].dmi"
		temp_paths += temp_path // APHELION EDIT ADDITION
		var/result = rustg_dmi_create_png(temp_path, "[file_width]", "[file_height]", pixels)
		if(result)
			stack_trace(result)
			// APHELION EDIT ADDITION START - Remove temporary files after failed exports.
			for(var/cleanup_path in temp_paths)
				fdel(cleanup_path)
			// APHELION EDIT ADDITION END
			return null // APHELION EDIT CHANGE - ORIGINAL: return TRUE
		result = rustg_dmi_inject_metadata(temp_path, metadata)
		if(result)
			stack_trace(result)
			// APHELION EDIT ADDITION START - Remove temporary files after failed exports.
			for(var/cleanup_path in temp_paths)
				fdel(cleanup_path)
			// APHELION EDIT ADDITION END
			return null // APHELION EDIT CHANGE - ORIGINAL: return TRUE
	/* // APHELION EDIT REMOVAL START - Runtime files cannot use batched asset generation.
	var/datum/universal_icon/out_icon = uni_icon("tmp/[temp_file_prefix]_layer1.dmi", "")
	for(var/i in 2 to layer_count)
		out_icon.blend_icon(uni_icon("tmp/[temp_file_prefix]_layer[i].dmi", ""), ICON_OVERLAY)
	var/icon/final_icon = out_icon.to_icon()
	for(var/i in 1 to layer_count)
		fdel("tmp/[temp_file_prefix]_layer[i].dmi")
	*/ // APHELION EDIT REMOVAL END
	// APHELION EDIT ADDITION START - Composite runtime files directly before cleanup.
	var/icon/final_icon = icon(file(temp_paths[1]), "")
	for(var/i in 2 to layer_count)
		final_icon.Blend(icon(file(temp_paths[i]), ""), ICON_OVERLAY)
	for(var/temp_path in temp_paths)
		fdel(temp_path)
	// APHELION EDIT ADDITION END
	return final_icon
