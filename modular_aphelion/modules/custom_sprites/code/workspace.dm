/datum/sprite_editor_workspace/custom_sprite
	var/list/palette
	var/list/draw_bounds
	var/tint

/datum/sprite_editor_workspace/custom_sprite/New(list/drawing, list/sampled_palette, list/bounds)
	..(32, 32, 4, null, SPRITE_EDITOR_COLOR_MODE_RGB, SPRITE_EDITOR_ALLOW_UNDO, SPRITE_EDITOR_TOOL_PENCIL | SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_BUCKET | SPRITE_EDITOR_TOOL_DROPPER, "#00000000")
	var/list/stored_palette = drawing?["palette"]
	palette = stored_palette ? stored_palette.Copy() : sampled_palette.Copy()
	tint = drawing?["tint"]
	draw_bounds = bounds
	RegisterSignal(src, COMSIG_SPRITE_EDITOR_VALIDATE_COLOR, PROC_REF(validate_palette_color))
	custom_sprite_hydrate(src, drawing)

/datum/sprite_editor_workspace/custom_sprite/proc/validate_palette_color(datum/source, color)
	SIGNAL_HANDLER
	if(!(lowertext(copytext(color, 1, 8)) in palette))
		return COLOR_IS_INVALID

/datum/sprite_editor_workspace/custom_sprite/is_point_allowed(x, y, direction)
	if(!..())
		return FALSE
	if(isnull(draw_bounds))
		return TRUE
	var/list/bounds = draw_bounds[direction]
	return bounds && x >= bounds[1] && y >= bounds[2] && x <= bounds[3] && y <= bounds[4]

/datum/sprite_editor_workspace/custom_sprite/new_transaction(transaction)
	. = ..()
	if(length(undo_stack) > 100)
		undo_stack.Cut(1, 2)
		undo_names.Cut(1, 2)

/datum/sprite_editor_workspace/custom_sprite/proc/serialize_drawing()
	var/list/directions = list()
	var/list/indices = list()
	for(var/i in 1 to length(palette))
		indices[palette[i]] = copytext("0123456789abcdef", i + 1, i + 2)
	for(var/direction in layers[1]["data"])
		var/list/frame = layers[1]["data"][direction]
		var/grid = ""
		var/painted = FALSE
		for(var/list/row as anything in frame)
			for(var/pixel in row)
				var/index = istext(pixel) && !endswith(pixel, "00") ? indices[lowertext(copytext(pixel, 1, 8))] : null
				grid += index || "0"
				painted ||= !!index
		if(painted)
			directions[direction] = custom_sprite_encode_grid(grid)
	if(!length(directions))
		return null
	return list("version" = 1, "palette" = palette.Copy(), "tint" = tint, "dirs" = directions)

/// An explicit clear can erase old pixels outside the bounds of a newly selected hairstyle/body.
/datum/sprite_editor_workspace/custom_sprite/proc/clear_direction(direction)
	if(!istext(direction) || !(direction in layers[1]["data"]))
		return FALSE
	var/list/points = list()
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			points += list(list(x, y))
	var/list/previous_bounds = draw_bounds
	draw_bounds = null
	. = new_transaction(list("type" = "eraser", "layer" = 1, "dir" = direction, "points" = points))
	draw_bounds = previous_bounds
