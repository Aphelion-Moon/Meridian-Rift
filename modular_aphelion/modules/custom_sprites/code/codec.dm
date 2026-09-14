/// Each run is two hex nibbles: length (1-f), then palette index (0-f).
/// Coordinates are row-major from the top left, matching SpriteEditor.
/proc/custom_sprite_encode_grid(grid)
	if(!istext(grid) || length(grid) != 1024)
		return null
	var/hex_digits = "0123456789abcdef"
	var/rle = "r"
	var/run = 0
	var/previous
	for(var/i in 1 to 1024)
		var/pixel = copytext(grid, i, i + 1)
		if(!findtextEx(hex_digits, pixel))
			return null
		if(pixel != previous || run == 15)
			if(run)
				rle += "[copytext(hex_digits, run + 1, run + 2)][previous]"
			previous = pixel
			run = 0
		run++
	rle += "[copytext(hex_digits, run + 1, run + 2)][previous]"
	return length(rle) < 1025 ? rle : "f[grid]"

/// Reject before expanding, and stop at 1024 pixels even for hostile run counts.
/proc/custom_sprite_decode_grid(encoded, palette_size = 15)
	if(!istext(encoded) || length(encoded) < 2 || length(encoded) > 1025 || !isnum(palette_size) || palette_size < 1 || palette_size > 15)
		return null
	var/hex_digits = "0123456789abcdef"
	var/format = copytext(encoded, 1, 2)
	var/grid = ""
	switch(format)
		if("f")
			if(length(encoded) != 1025)
				return null
			grid = copytext(encoded, 2)
		if("r")
			if((length(encoded) - 1) % 2)
				return null
			for(var/i = 2; i < length(encoded); i += 2)
				var/run = findtextEx(hex_digits, copytext(encoded, i, i + 1)) - 1
				var/pixel = copytext(encoded, i + 1, i + 2)
				var/index = findtextEx(hex_digits, pixel) - 1
				if(run < 1 || index < 0 || index > palette_size || length(grid) + run > 1024)
					return null
				grid += repeat_string(run, pixel)
		else
			return null
	if(length(grid) != 1024)
		return null
	for(var/i in 1 to 1024)
		var/index = findtextEx(hex_digits, copytext(grid, i, i + 1)) - 1
		if(index < 0 || index > palette_size)
			return null
	return grid

/proc/custom_sprite_color(color)
	if(!istext(color) || length(color) != 7 || copytext(color, 1, 2) != "#")
		return null
	var/clean = sanitize_hexcolor(color, 6, TRUE, "invalid")
	return clean == lowertext(color) ? clean : null

/// Reconstruct a bounded, canonical payload. Missing directions are ordinary empty canvases.
/proc/custom_sprite_validate(list/drawing)
	if(!islist(drawing) || drawing["version"] != 1)
		return null
	var/list/raw_palette = drawing["palette"]
	var/list/raw_dirs = drawing["dirs"]
	if(!islist(raw_palette) || !length(raw_palette) || length(raw_palette) > 15 || !islist(raw_dirs))
		return null
	var/list/palette = list()
	for(var/raw_color in raw_palette)
		var/color = custom_sprite_color(raw_color)
		if(!color || (color in palette))
			return null
		palette += color
	var/tint = custom_sprite_color(drawing["tint"])
	var/list/directions = list()
	for(var/direction in list("2", "1", "4", "8"))
		var/grid = custom_sprite_decode_grid(raw_dirs[direction], length(palette))
		if(grid && grid != repeat_string(1024, "0"))
			directions[direction] = custom_sprite_encode_grid(grid)
	if(!length(directions))
		return null
	return list("version" = 1, "palette" = palette, "tint" = tint, "dirs" = directions)

/proc/custom_sprite_hash(list/drawing)
	return drawing ? md5(json_encode(drawing)) : "empty"
