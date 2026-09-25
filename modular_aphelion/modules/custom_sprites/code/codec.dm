/// Supported drawing zones and their editor labels.
GLOBAL_LIST_INIT(custom_marking_zone_labels, list(
	BODY_ZONE_HEAD = "Head",
	BODY_ZONE_CHEST = "Torso",
	BODY_ZONE_L_ARM = "Left arm",
	BODY_ZONE_R_ARM = "Right arm",
	BODY_ZONE_PRECISE_L_HAND = "Left hand",
	BODY_ZONE_PRECISE_R_HAND = "Right hand",
	BODY_ZONE_L_LEG = "Left leg",
	BODY_ZONE_R_LEG = "Right leg",
	CUSTOM_MARKING_ZONE_TAUR = "Taur lower body",
))

/// Serialized cardinal direction keys: Front, Back, Right, Left.
GLOBAL_LIST_INIT(custom_style_directions, list("2", "1", "4", "8"))

/// Drawing targets that sit on a head accessory and carry its base look with the paint.
GLOBAL_LIST_INIT(custom_style_hair_targets, list("hair", "facial_hair"))

/proc/custom_style_hair_target(target)
	return target in GLOB.custom_style_hair_targets

/// The accessory list, gradient list and gradient key each head target draws on.
/proc/custom_style_hair_accessories(target)
	return target == "facial_hair" ? SSaccessories.facial_hairstyles_list : SSaccessories.hairstyles_list

/proc/custom_style_hair_gradients(target)
	return target == "facial_hair" ? SSaccessories.facial_hair_gradients_list : SSaccessories.hair_gradients_list

/proc/custom_style_gradient_key(target)
	return target == "facial_hair" ? GRADIENT_FACIAL_HAIR_KEY : GRADIENT_HAIR_KEY

/// Hands are auxiliary zones of their arm rather than limbs, so their paint lives on the arm.
GLOBAL_LIST_INIT(custom_marking_hand_arms, list(
	BODY_ZONE_PRECISE_L_HAND = BODY_ZONE_L_ARM,
	BODY_ZONE_PRECISE_R_HAND = BODY_ZONE_R_ARM,
))

/// The bodypart that carries a marking zone's paint.
/proc/custom_marking_zone_limb(zone)
	if(zone == CUSTOM_MARKING_ZONE_TAUR)
		return BODY_ZONE_CHEST
	return (zone && GLOB.custom_marking_hand_arms[zone]) || zone

/// The overlay identity for a marking zone, so zone, hand and taur paint on one bodypart stay independent.
/proc/custom_marking_zone_overlay_type(zone)
	if(zone == CUSTOM_MARKING_ZONE_TAUR)
		return /datum/bodypart_overlay/custom_marking/taur/zone
	if(zone && GLOB.custom_marking_hand_arms[zone])
		return /datum/bodypart_overlay/custom_marking/zone/hand
	return /datum/bodypart_overlay/custom_marking/zone

/// The other half of an arm/hand pair, which share one limb, or null.
/proc/custom_marking_partner(zone)
	if(GLOB.custom_marking_hand_arms[zone])
		return GLOB.custom_marking_hand_arms[zone]
	for(var/hand, arm in GLOB.custom_marking_hand_arms)
		if(arm == zone)
			return hand
	return null

/// A zone's own drawing width: the taur spans the wide canvas, everything else the body's 32 pixels.
/proc/custom_marking_zone_width(zone)
	return zone == CUSTOM_MARKING_ZONE_TAUR ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/// The format owns the canvas dimensions; legacy drawings always remain 32 by 32.
/proc/custom_sprite_width(list/drawing)
	return drawing?["version"] == 3 ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/// Wide drawings extend equally to either side of the body's original 32-pixel canvas.
/proc/custom_sprite_origin_x(list/drawing)
	return (32 - custom_sprite_width(drawing)) / 2

/// Wide canvases are version 3. Otherwise version 1 holds up to 15 colors and version 2 the rest.
/proc/custom_sprite_version(width, palette_length)
	if(width == CUSTOM_SPRITE_TAUR_WIDTH)
		return 3
	return palette_length > 15 ? 2 : 1

/// Grids are 32 rows of 32 or 64 pixels, indexing a palette of 1 to CUSTOM_SPRITE_MAX_COLORS colors.
/proc/custom_sprite_grid_args_valid(palette_size, pixel_count)
	return (pixel_count == 32 * 32 || pixel_count == CUSTOM_SPRITE_TAUR_WIDTH * 32) && isnum(palette_size) && palette_size == round(palette_size) && palette_size >= 1 && palette_size <= CUSTOM_SPRITE_MAX_COLORS

/// Each run is a hex length (1-f), followed by one palette-index character.
/// Coordinates are row-major from the top left, matching SpriteEditor.
/proc/custom_sprite_encode_grid(grid, palette_size = 15, pixel_count = 1024)
	if(!custom_sprite_grid_args_valid(palette_size, pixel_count) || !istext(grid) || length(grid) != pixel_count)
		return null
	// Validate the entire grid before allowing an early flat fallback.
	if(spantext(grid, copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 1, palette_size + 2)) != pixel_count)
		return null
	var/hex_digits = "0123456789abcdef"
	// Joined once at the end: growing one string run by run copies it every time.
	var/list/runs = list("r")
	var/encoded_length = 1
	for(var/i = 1; i <= pixel_count;)
		var/pixel = copytext(grid, i, i + 1)
		var/run = min(15, spantext(grid, pixel, i))
		runs += "[copytext(hex_digits, run + 1, run + 2)][pixel]"
		encoded_length += 2
		if(encoded_length >= pixel_count + 1)
			return "f[grid]"
		i += run
	return jointext(runs, "")

/// Reject before expanding, and stop at the supported pixel count even for hostile runs.
/proc/custom_sprite_decode_grid(encoded, palette_size = 15, pixel_count = 1024)
	if(!custom_sprite_grid_args_valid(palette_size, pixel_count) || !istext(encoded) || length(encoded) < 2 || length(encoded) > pixel_count + 1)
		return null
	var/hex_digits = "0123456789abcdef"
	var/format = copytext(encoded, 1, 2)
	var/grid = ""
	switch(format)
		if("f")
			if(length(encoded) != pixel_count + 1)
				return null
			grid = copytext(encoded, 2)
			if(spantext(grid, copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 1, palette_size + 2)) != pixel_count)
				return null
		if("r")
			if((length(encoded) - 1) % 2)
				return null
			var/list/runs = list()
			var/decoded_length = 0
			var/encoded_length = length(encoded)
			for(var/i = 2; i < encoded_length; i += 2)
				var/run = findtextEx(hex_digits, copytext(encoded, i, i + 1)) - 1
				var/pixel = copytext(encoded, i + 1, i + 2)
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, pixel) - 1
				if(run < 1 || index < 0 || index > palette_size || decoded_length + run > pixel_count)
					return null
				runs += custom_sprite_run_text(pixel, run)
				decoded_length += run
			grid = jointext(runs, "")
		else
			return null
	if(length(grid) != pixel_count)
		return null
	return grid

/// One index character repeated `run` times (1-15), cut from a string built once per character.
/proc/custom_sprite_run_text(pixel, run)
	var/static/list/repeated = list()
	var/full = repeated[pixel]
	if(!full)
		full = "[pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel][pixel]"
		repeated[pixel] = full
	return copytext(full, 1, run + 1)

/// CUSTOM_SPRITE_INDEX_ALPHABET character -> its palette index. "0" is transparent.
/proc/custom_sprite_index_values()
	var/static/list/values
	if(!values)
		values = list()
		for(var/position in 1 to length(CUSTOM_SPRITE_INDEX_ALPHABET))
			values[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, position, position + 1)] = position - 1
	return values

/// A palette index as `digits` characters of CUSTOM_SPRITE_INDEX_ALPHABET, most significant first.
/proc/custom_sprite_canvas_code(index, digits)
	. = ""
	for(var/i in 1 to digits)
		var/digit = index % 64
		. = "[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, digit + 1, digit + 2)][.]"
		index = round(index / 64)

/proc/custom_sprite_color(color)
	if(!istext(color) || length(color) != 7 || copytext(color, 1, 2) != "#")
		return null
	var/clean = sanitize_hexcolor(color, 6, TRUE, "invalid")
	return clean == LOWER_TEXT(color) ? clean : null

/// Older drawings used one boolean; each view now owns its own saved choice.
/proc/custom_sprite_emissive_settings(value)
	var/list/settings = list()
	var/list/directions = islist(value) ? value : null
	for(var/direction in GLOB.custom_style_directions)
		settings[direction] = directions ? directions[direction] == TRUE : value == TRUE
	return settings

/// Reconstruct a bounded, canonical payload. Missing directions are ordinary empty canvases.
/proc/custom_sprite_validate(list/drawing)
	if(!islist(drawing) || !(drawing["version"] in list(1, 2, 3)))
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
	var/pixel_count = custom_sprite_width(drawing) * 32
	var/list/directions = list()
	for(var/direction in GLOB.custom_style_directions)
		var/grid = custom_sprite_decode_grid(raw_dirs[direction], length(palette), pixel_count)
		if(grid && spantext(grid, "0") != pixel_count)
			directions[direction] = custom_sprite_encode_grid(grid, length(palette), pixel_count)
	if(!length(directions))
		return null
	var/list/validated = list("version" = custom_sprite_version(custom_sprite_width(drawing), length(palette)), "palette" = palette, "tint" = tint, "dirs" = directions)
	// Preserve older payloads; the editor and appearance default missing emission settings to off.
	if("emissive" in drawing)
		validated["emissive"] = custom_sprite_emissive_settings(drawing["emissive"])
	return validated

/// Center canonical legacy paint on a wide canvas. Refuse shrinking so no paint can be lost.
/proc/custom_sprite_resize_drawing(list/drawing, width)
	if(!drawing || !(width in list(32, CUSTOM_SPRITE_TAUR_WIDTH)))
		return null
	var/source_width = custom_sprite_width(drawing)
	if(width < source_width)
		return null
	if(width == source_width)
		return drawing
	var/list/resized = deep_copy_list(drawing)
	var/padding = repeat_string((width - source_width) / 2, "0")
	var/palette_size = length(drawing["palette"])
	for(var/direction, encoded in drawing["dirs"])
		var/grid = custom_sprite_decode_grid(encoded, palette_size, source_width * 32)
		if(!grid)
			return null
		var/list/rows = list()
		for(var/y in 0 to 31)
			rows += "[padding][copytext(grid, y * source_width + 1, (y + 1) * source_width + 1)][padding]"
		resized["dirs"][direction] = custom_sprite_encode_grid(jointext(rows, ""), palette_size, width * 32)
	resized["version"] = 3
	return resized

/proc/custom_sprite_hash(list/drawing)
	return drawing ? md5(json_encode(drawing)) : "empty"

/// Zone drawings keep the existing codec; discard unknown zones and independently copy each valid drawing.
/proc/custom_limb_markings_validate(list/drawings)
	if(!islist(drawings))
		return null
	var/list/clean = list()
	for(var/body_zone in GLOB.custom_marking_zone_labels)
		var/list/drawing = custom_sprite_validate(drawings[body_zone])
		if(drawing && (body_zone == CUSTOM_MARKING_ZONE_TAUR) == (custom_sprite_width(drawing) == CUSTOM_SPRITE_TAUR_WIDTH))
			clean[body_zone] = drawing
	return length(clean) ? clean : null

/**
 * Rewrites literal-color paint through a color map, keeping every pixel where it is.
 *
 * Legacy no-tint paint already follows native hair coloring, so its raw shades must not change.
 * Entries that collide after mapping are merged into one palette slot, so a recolor can shrink
 * the palette but never reorders or moves paint.
 *
 * Returns:
 * - list: The recolored drawing.
 * - The original drawing: Nothing in the palette changed.
 * - null: The drawing could not be decoded.
 */
/proc/custom_style_recolor_drawing(list/drawing, list/color_map)
	if(!drawing?["tint"] || !length(color_map))
		return drawing
	var/list/old_palette = drawing["palette"]
	var/list/new_palette = list()
	var/list/index_map = list()
	var/changed = FALSE
	for(var/index in 1 to length(old_palette))
		var/color = old_palette[index]
		var/replacement = color_map[color] || color
		if(replacement != color)
			changed = TRUE
		var/position = new_palette.Find(replacement)
		if(!position)
			new_palette += replacement
			position = length(new_palette)
		index_map += position
	if(!changed)
		return drawing
	var/pixel_count = custom_sprite_width(drawing) * 32
	var/list/directions = list()
	for(var/direction, encoded in drawing["dirs"])
		var/grid = custom_sprite_decode_grid(encoded, length(old_palette), pixel_count)
		if(!grid)
			return null
		var/list/recolored = list()
		for(var/position in 1 to pixel_count)
			// Alphabet position 1 is transparent, so palette index 1 lives at position 2.
			var/alphabet_position = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1))
			if(alphabet_position <= 1)
				recolored += "0"
				continue
			var/mapped = index_map[alphabet_position - 1] + 1
			recolored += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, mapped, mapped + 1)
		directions[direction] = custom_sprite_encode_grid(jointext(recolored, ""), length(new_palette), pixel_count)
	var/list/result = drawing.Copy()
	result["palette"] = new_palette
	result["dirs"] = directions
	return custom_sprite_validate(result)

/// One view's pixels as color text, so two drawings compare by what they show, not palette order.
/proc/custom_sprite_direction_signature(list/drawing, direction)
	if(!drawing)
		return ""
	var/list/palette = drawing["palette"]
	var/pixel_count = custom_sprite_width(drawing) * 32
	var/grid = custom_sprite_decode_grid(drawing["dirs"][direction], length(palette), pixel_count)
	if(!grid)
		return ""
	var/list/pixels = list()
	for(var/position in 1 to pixel_count)
		var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1)) - 1
		pixels += index >= 1 ? palette[index] : ""
	return jointext(pixels, ",")

/// Tint and emissive settings affect appearances, not the drawing's raw pixels.
/proc/custom_sprite_pixel_hash(list/drawing)
	return drawing ? md5(json_encode(list(custom_sprite_width(drawing), drawing["palette"], drawing["dirs"]))) : "empty"
