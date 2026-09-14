#define CUSTOM_SPRITE_MAX_CUSTOM_COLORS 16
#define CUSTOM_SPRITE_MAX_COLORS 63
#define CUSTOM_SPRITE_INDEX_ALPHABET "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

GLOBAL_LIST_INIT(custom_marking_zone_labels, list(
	BODY_ZONE_HEAD = "Head",
	BODY_ZONE_CHEST = "Torso",
	BODY_ZONE_L_ARM = "Left arm",
	BODY_ZONE_R_ARM = "Right arm",
	BODY_ZONE_L_LEG = "Left leg",
	BODY_ZONE_R_LEG = "Right leg",
))

/// Each run is a hex length (1-f), followed by one palette-index character.
/// Coordinates are row-major from the top left, matching SpriteEditor.
/proc/custom_sprite_encode_grid(grid, palette_size = 15)
	if(!istext(grid) || length(grid) != 1024 || !isnum(palette_size) || palette_size != round(palette_size) || palette_size < 1 || palette_size > CUSTOM_SPRITE_MAX_COLORS)
		return null
	var/hex_digits = "0123456789abcdef"
	var/rle = "r"
	var/run = 0
	var/previous
	for(var/i in 1 to 1024)
		var/pixel = copytext(grid, i, i + 1)
		var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, pixel) - 1
		if(index < 0 || index > palette_size)
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
	if(!istext(encoded) || length(encoded) < 2 || length(encoded) > 1025 || !isnum(palette_size) || palette_size != round(palette_size) || palette_size < 1 || palette_size > CUSTOM_SPRITE_MAX_COLORS)
		return null
	var/hex_digits = "0123456789abcdef"
	var/format = copytext(encoded, 1, 2)
	var/grid = ""
	switch(format)
		if("f")
			if(length(encoded) != 1025)
				return null
			grid = copytext(encoded, 2)
			for(var/i in 1 to 1024)
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, i, i + 1)) - 1
				if(index < 0 || index > palette_size)
					return null
		if("r")
			if((length(encoded) - 1) % 2)
				return null
			for(var/i = 2; i < length(encoded); i += 2)
				var/run = findtextEx(hex_digits, copytext(encoded, i, i + 1)) - 1
				var/pixel = copytext(encoded, i + 1, i + 2)
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, pixel) - 1
				if(run < 1 || index < 0 || index > palette_size || length(grid) + run > 1024)
					return null
				grid += repeat_string(run, pixel)
		else
			return null
	if(length(grid) != 1024)
		return null
	return grid

/proc/custom_sprite_color(color)
	if(!istext(color) || length(color) != 7 || copytext(color, 1, 2) != "#")
		return null
	var/clean = sanitize_hexcolor(color, 6, TRUE, "invalid")
	return clean == lowertext(color) ? clean : null

/// Older drawings used one boolean; each view now owns its own saved choice.
/proc/custom_sprite_emissive_settings(value)
	var/list/settings = list()
	var/list/directions = islist(value) ? value : null
	for(var/direction in list("2", "1", "4", "8"))
		settings[direction] = directions ? directions[direction] == TRUE : value == TRUE
	return settings

/// Reconstruct a bounded, canonical payload. Missing directions are ordinary empty canvases.
/proc/custom_sprite_validate(list/drawing)
	if(!islist(drawing) || !(drawing["version"] in list(1, 2)))
		return null
	var/list/raw_palette = drawing["palette"]
	var/list/raw_dirs = drawing["dirs"]
	var/palette_limit = drawing["version"] == 1 ? 15 : CUSTOM_SPRITE_MAX_COLORS
	if(!islist(raw_palette) || !length(raw_palette) || length(raw_palette) > palette_limit || !islist(raw_dirs))
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
			directions[direction] = custom_sprite_encode_grid(grid, length(palette))
	if(!length(directions))
		return null
	var/list/validated = list("version" = length(palette) > 15 ? 2 : 1, "palette" = palette, "tint" = tint, "dirs" = directions)
	// Preserve older payloads; the editor and appearance default missing emission settings to off.
	if("emissive" in drawing)
		validated["emissive"] = custom_sprite_emissive_settings(drawing["emissive"])
	return validated

/proc/custom_sprite_hash(list/drawing)
	return drawing ? md5(json_encode(drawing)) : "empty"

/// Zone drawings keep the existing codec; discard unknown zones and independently copy each valid drawing.
/proc/custom_limb_markings_validate(list/drawings)
	if(!islist(drawings))
		return null
	var/list/clean = list()
	for(var/body_zone in GLOB.custom_marking_zone_labels)
		var/list/drawing = custom_sprite_validate(drawings[body_zone])
		if(drawing)
			clean[body_zone] = drawing
	return length(clean) ? clean : null

/// Tint and emissive settings affect appearances, not the drawing's raw pixels.
/proc/custom_sprite_pixel_hash(list/drawing)
	return drawing ? md5(json_encode(list(drawing["palette"], drawing["dirs"]))) : "empty"
