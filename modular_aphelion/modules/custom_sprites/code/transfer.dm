#define CUSTOM_STYLE_FORMAT "aphelion-custom-style"
#define CUSTOM_STYLE_VERSION 1
#define CUSTOM_STYLE_MAX_BYTES 16384
#define CUSTOM_STYLE_MAX_DEPTH 8
#define CUSTOM_STYLE_MAX_TOKENS 512
#define CUSTOM_STYLE_IMPORT_COOLDOWN (5 SECONDS)
#define CUSTOM_STYLE_EXPORT_COOLDOWN (2 SECONDS)
#define CUSTOM_STYLE_EXPORT_DIRECTORY "data/custom_style_exports/"
#define CUSTOM_STYLE_JSON_TRUE "@custom-style-true@"
#define CUSTOM_STYLE_JSON_FALSE "@custom-style-false@"

#define STYLE_JSON_VALUE 1
#define STYLE_JSON_VALUE_OR_END 2
#define STYLE_JSON_KEY 3
#define STYLE_JSON_KEY_OR_END 4
#define STYLE_JSON_COLON 5
#define STYLE_JSON_COMMA_OR_END 6
#define STYLE_JSON_DONE 7

/// Account ckey -> list("busy", "import", "export"): one transfer at a time, with per-kind cooldowns.
GLOBAL_LIST_EMPTY(custom_style_transfers)

/// Exact fields allowed in an imported drawing.
GLOBAL_LIST_INIT(custom_style_drawing_keys, list("version", "palette", "dirs", "tint", "emissive"))
/// Exact fields allowed in an imported base hair look.
GLOBAL_LIST_INIT(custom_style_hair_keys, list("style", "color", "gradient_style", "gradient_color", "opacity", "emissive"))
/// Exact fields allowed in one imported native marking.
GLOBAL_LIST_INIT(custom_style_marking_keys, list("name", "color", "emissive"))
/// Serialized cardinal direction keys required by current exports.
GLOBAL_LIST_INIT(custom_style_directions, list("2", "1", "4", "8"))
/// Direction labels used in validation errors.
GLOBAL_LIST_INIT(custom_style_direction_labels, list("2" = "Front", "1" = "Back", "4" = "Right", "8" = "Left"))

/**
 * Checks untrusted JSON text before it reaches json_decode().
 *
 * The scanner is iterative, so hostile nesting cannot recurse. It is string and escape aware,
 * rejects duplicate object keys, trailing content, non-ASCII text and malformed numbers, and
 * limits nesting depth and token count. Object keys must be short lowercase identifiers, so
 * escaped spellings of the same key cannot slip past the duplicate check.
 *
 * Only a top-level object is accepted.
 *
 * Arguments:
 * - text: The raw file contents. The caller has already checked the byte size.
 *
 * Returns:
 * - list("types" = path -> JSON type): The file is structurally safe to decode. Paths look like
 *   `drawing.dirs.2`, `drawing.palette[]`, and `markings[1].name`. Array summaries with mixed
 *   element types record "mixed"; indexed paths retain each entry's own field types.
 * - list("error" = message): The file was rejected. The message is safe to show the player.
 */
/proc/custom_style_preflight(text)
	if(!istext(text) || !length(text))
		return list("error" = "The file is empty.")
	var/text_length = length(text)
	if(text_length > CUSTOM_STYLE_MAX_BYTES)
		return list("error" = "The file is larger than 16 KiB.")
	var/static/whitespace = " \t\n[ascii2text(13)]"
	var/static/key_characters = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var/static/number_characters = "-+.eE0123456789"
	var/static/regex/number_format = regex(@"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$")
	var/static/string_characters
	if(!string_characters)
		string_characters = ""
		for(var/code in 32 to 126)
			if(code != 34 && code != 92)
				string_characters += ascii2text(code)
	var/list/types = list()
	// Each container is list(is_object, path, keys, current key, array index).
	var/list/containers = list()
	var/expect = STYLE_JSON_VALUE
	var/tokens = 0
	var/position = 1
	while(TRUE)
		position += spantext(text, whitespace, position)
		if(position > text_length)
			break
		var/character = copytext(text, position, position + 1)
		var/list/container = length(containers) ? containers[length(containers)] : null
		switch(expect)
			if(STYLE_JSON_DONE)
				return list("error" = "The file has extra content after the style.")
			if(STYLE_JSON_COLON)
				if(character != ":")
					return list("error" = "The file is not valid JSON.")
				expect = STYLE_JSON_VALUE
				position++
				continue
			if(STYLE_JSON_COMMA_OR_END)
				if(character == ",")
					expect = container[1] ? STYLE_JSON_KEY : STYLE_JSON_VALUE
					position++
					continue
				if(character != (container[1] ? "}" : "]"))
					return list("error" = "The file is not valid JSON.")
				containers.len--
				expect = length(containers) ? STYLE_JSON_COMMA_OR_END : STYLE_JSON_DONE
				position++
				continue
			if(STYLE_JSON_KEY, STYLE_JSON_KEY_OR_END)
				if(expect == STYLE_JSON_KEY_OR_END && character == "}")
					containers.len--
					expect = length(containers) ? STYLE_JSON_COMMA_OR_END : STYLE_JSON_DONE
					position++
					continue
				if(character != "\"")
					return list("error" = "The file is not valid JSON.")
				var/key_length = spantext(text, key_characters, position + 1)
				if(!key_length || key_length > 32 || copytext(text, position + key_length + 1, position + key_length + 2) != "\"")
					return list("error" = "The file has an unsupported field name.")
				var/key = copytext(text, position + 1, position + key_length + 1)
				var/list/keys = container[3]
				if(keys[key])
					return list("error" = "The file repeats the field \"[key]\".")
				if(++tokens > CUSTOM_STYLE_MAX_TOKENS)
					return list("error" = "The file has too many values.")
				keys[key] = TRUE
				container[4] = key
				expect = STYLE_JSON_COLON
				position += key_length + 2
				continue
		// Remaining states expect a value.
		if(expect == STYLE_JSON_VALUE_OR_END && character == "]")
			containers.len--
			expect = length(containers) ? STYLE_JSON_COMMA_OR_END : STYLE_JSON_DONE
			position++
			continue
		if(!container && character != "{")
			return list("error" = "The file must contain a JSON object.")
		if(++tokens > CUSTOM_STYLE_MAX_TOKENS)
			return list("error" = "The file has too many values.")
		var/path = ""
		var/array_path
		if(container)
			if(container[1])
				path = container[2] ? "[container[2]].[container[4]]" : container[4]
			else
				container[5]++
				path = "[container[2]]\[[container[5]]]"
				array_path = "[container[2]]\[]"
		var/value_type
		switch(character)
			if("{", "\[")
				if(length(containers) >= CUSTOM_STYLE_MAX_DEPTH)
					return list("error" = "The file is nested too deeply.")
				value_type = character == "{" ? "object" : "array"
				containers += list(list(character == "{", path, list(), null, 0))
				expect = character == "{" ? STYLE_JSON_KEY_OR_END : STYLE_JSON_VALUE_OR_END
				position++
			if("\"")
				var/end = position + 1
				while(TRUE)
					end += spantext(text, string_characters, end)
					if(end > text_length)
						return list("error" = "The file has an unterminated string.")
					var/string_character = copytext(text, end, end + 1)
					if(string_character == "\"")
						break
					if(string_character != "\\")
						return list("error" = "The file contains unsupported characters.")
					var/escaped = copytext(text, end + 1, end + 2)
					if(escaped == "u")
						if(spantext(text, "0123456789abcdefABCDEF", end + 2) < 4)
							return list("error" = "The file has an invalid escape sequence.")
						end += 6
					else if(escaped && findtextEx("\"\\/bfnrt", escaped))
						end += 2
					else
						return list("error" = "The file has an invalid escape sequence.")
				value_type = "string"
				position = end + 1
			if("t", "f", "n")
				var/literal = character == "t" ? "true" : (character == "f" ? "false" : "null")
				if(copytext(text, position, position + length(literal)) != literal)
					return list("error" = "The file is not valid JSON.")
				value_type = literal
				position += length(literal)
			else
				var/number_length = spantext(text, number_characters, position)
				if(!number_length || !number_format.Find(copytext(text, position, position + number_length)))
					return list("error" = "The file is not valid JSON.")
				value_type = "number"
				position += number_length
		if(array_path)
			types[array_path] = types[array_path] && types[array_path] != value_type ? "mixed" : value_type
		types[path] = value_type
		if(value_type != "object" && value_type != "array")
			expect = length(containers) ? STYLE_JSON_COMMA_OR_END : STYLE_JSON_DONE
	if(expect != STYLE_JSON_DONE)
		return list("error" = "The file ends before the style is complete.")
	return list("types" = types)

/// Without preflight types, trusted decoded data uses the equivalent DM value kinds.
/proc/custom_style_has_type(value, list/types, path, expected)
	if(types)
		if(expected == "boolean")
			return types[path] == "true" || types[path] == "false"
		return types[path] == expected
	switch(expected)
		if("object", "array")
			return islist(value)
		if("string")
			return istext(value)
		if("number")
			return isnum(value)
		if("boolean")
			return isnum(value) && (value == TRUE || value == FALSE)
		if("null")
			return isnull(value)
	return FALSE

/// Returns the first unsupported key, or null when every key is allowed.
/proc/custom_style_unknown_key(list/object, list/allowed)
	for(var/key in object)
		if(!istext(key) || !(key in allowed))
			return key || "?"
	return null

/**
 * Strictly validates one drawing. Unlike custom_sprite_validate(), nothing is salvaged.
 *
 * Arguments:
 * - raw: The decoded drawing object.
 * - types: Preflight types, or null for trusted decoded data such as the sidecar.
 * - path: The drawing's preflight path.
 * - legacy: Accepts old drawing-only files, where tint, emission and empty directions may be absent.
 *
 * Returns:
 * - list("drawing" = canonical drawing): Valid paint in at least one direction.
 * - list("error" = message): Anything malformed, including a drawing with no paint. Empty art
 *   must be written as an explicit null drawing, so invalid data can never become Clear.
 */
/proc/custom_style_validate_drawing(list/raw, list/types, path, legacy = FALSE)
	var/prefix = path ? "[path]." : ""
	if(!custom_style_has_type(raw, types, path, "object") || !islist(raw))
		return list("error" = "The drawing is malformed.")
	if(custom_style_unknown_key(raw, GLOB.custom_style_drawing_keys))
		return list("error" = "The drawing has an unsupported field.")
	var/list/required = legacy ? list("version", "palette", "dirs") : GLOB.custom_style_drawing_keys
	for(var/key in required)
		if(!(key in raw))
			return list("error" = "The drawing is missing \"[key]\".")
	var/version = raw["version"]
	if(!custom_style_has_type(version, types, "[prefix]version", "number") || !(version in list(1, 2, 3)))
		return list("error" = "The drawing uses an unsupported version.")
	var/list/raw_palette = raw["palette"]
	var/palette_limit = version == 1 ? 15 : CUSTOM_SPRITE_MAX_COLORS
	if(!custom_style_has_type(raw_palette, types, "[prefix]palette", "array") || !islist(raw_palette) || !length(raw_palette) || length(raw_palette) > palette_limit)
		return list("error" = "The drawing's palette is invalid or has more than [palette_limit] colors.")
	if(types && types["[prefix]palette\[]"] != "string")
		return list("error" = "The drawing's palette must only contain colors.")
	var/list/palette = list()
	for(var/raw_color in raw_palette)
		var/color = custom_sprite_color(raw_color)
		if(!color || (color in palette) || !isnull(raw_palette[raw_color]))
			return list("error" = "The drawing's palette has an invalid or repeated color.")
		palette += color
	var/list/raw_dirs = raw["dirs"]
	if(!custom_style_has_type(raw_dirs, types, "[prefix]dirs", "object") || !islist(raw_dirs) || custom_style_unknown_key(raw_dirs, GLOB.custom_style_directions))
		return list("error" = "The drawing's views are malformed.")
	var/pixel_count = custom_sprite_width(raw) * 32
	var/list/directions = list()
	for(var/direction in GLOB.custom_style_directions)
		if(!(direction in raw_dirs))
			if(!legacy)
				return list("error" = "The drawing is missing its [GLOB.custom_style_direction_labels[direction]] view.")
			continue
		var/encoded = raw_dirs[direction]
		var/grid = custom_style_has_type(encoded, types, "[prefix]dirs.[direction]", "string") ? custom_sprite_decode_grid(encoded, length(palette), pixel_count) : null
		if(!grid)
			return list("error" = "The [GLOB.custom_style_direction_labels[direction]] view has invalid pixel data.")
		if(spantext(grid, "0") != pixel_count)
			directions[direction] = custom_sprite_encode_grid(grid, length(palette), pixel_count)
	if(!length(directions))
		return list("error" = "The drawing has no paint. Empty styles must use a null drawing.")
	var/tint = raw["tint"]
	if(!isnull(tint) && (!custom_style_has_type(tint, types, "[prefix]tint", "string") || !custom_sprite_color(tint)))
		return list("error" = "The drawing's color filter is invalid.")
	if(("tint" in raw) && isnull(tint) && !custom_style_has_type(tint, types, "[prefix]tint", "null"))
		return list("error" = "The drawing's color filter is invalid.")
	var/raw_emissive = raw["emissive"]
	// Persisted legacy flags are numeric 0/1; current exports must use JSON booleans.
	var/list/emissive_types = legacy ? null : types
	if("emissive" in raw)
		if(islist(raw_emissive))
			if(!custom_style_has_type(raw_emissive, types, "[prefix]emissive", "object") || custom_style_unknown_key(raw_emissive, GLOB.custom_style_directions))
				return list("error" = "The drawing's emissive settings are malformed.")
			for(var/direction in GLOB.custom_style_directions)
				if(!(direction in raw_emissive))
					if(!legacy)
						return list("error" = "The drawing's emissive settings are incomplete.")
					continue
				if(!custom_style_has_type(raw_emissive[direction], emissive_types, "[prefix]emissive.[direction]", "boolean"))
					return list("error" = "The drawing's emissive settings must be true or false.")
		else if(!legacy || !custom_style_has_type(raw_emissive, emissive_types, "[prefix]emissive", "boolean"))
			return list("error" = "The drawing's emissive settings are malformed.")
	var/list/canonical = list("version" = version == 3 ? 3 : (length(palette) > 15 ? 2 : 1), "palette" = palette, "tint" = custom_sprite_color(tint), "dirs" = directions, "emissive" = custom_sprite_emissive_settings(raw_emissive))
	return list("drawing" = canonical)

/**
 * Strictly validates the whitelisted base hair look carried by hair styles.
 *
 * Registered names and value ranges are checked here. Destination-specific rules, such as a
 * character's species, emissive permission or opacity access, are checked by the destination.
 *
 * Returns:
 * - list("hair" = canonical context): A complete, valid base look.
 * - list("error" = message): Anything missing, unknown, locked or out of range.
 */
/proc/custom_style_validate_hair(list/raw, list/types, path = "hair", target = "hair")
	if(!custom_style_has_type(raw, types, path, "object") || !islist(raw) || custom_style_unknown_key(raw, GLOB.custom_style_hair_keys))
		return list("error" = "The hair settings are malformed.")
	for(var/key in GLOB.custom_style_hair_keys)
		if(!(key in raw))
			return list("error" = "The hair settings are missing \"[key]\".")
	var/style = raw["style"]
	// Hairstyles without an icon state, such as Bald, are registered by name with no datum.
	var/list/accessories = custom_style_hair_accessories(target)
	var/registered = istext(style) && custom_style_has_type(style, types, "[path].style", "string") && (style in accessories)
	var/datum/sprite_accessory/hair/hairstyle = registered ? accessories[style] : null
	if(!registered || hairstyle?.locked)
		return list("error" = "The [target == "facial_hair" ? "facial hairstyle" : "hairstyle"] isn't available.")
	var/gradient_style = raw["gradient_style"]
	if(!istext(gradient_style) || !custom_style_has_type(gradient_style, types, "[path].gradient_style", "string") || !custom_style_hair_gradients(target)[gradient_style])
		return list("error" = "The hair gradient isn't available.")
	var/color = custom_style_has_type(raw["color"], types, "[path].color", "string") ? custom_sprite_color(raw["color"]) : null
	var/gradient_color = custom_style_has_type(raw["gradient_color"], types, "[path].gradient_color", "string") ? custom_sprite_color(raw["gradient_color"]) : null
	if(!color || !gradient_color)
		return list("error" = "The hair colors are invalid.")
	var/opacity = raw["opacity"]
	if(!isnull(opacity) && (!custom_style_has_type(opacity, types, "[path].opacity", "number") || !isnum(opacity) || round(opacity) != opacity || opacity < 40 || opacity > 255))
		return list("error" = "The hair opacity must be a whole number from 40 to 255.")
	if(isnull(opacity) && !custom_style_has_type(opacity, types, "[path].opacity", "null"))
		return list("error" = "The hair opacity is invalid.")
	if(!custom_style_has_type(raw["emissive"], types, "[path].emissive", "boolean"))
		return list("error" = "The hair emissive setting must be true or false.")
	return list("hair" = list("style" = style, "color" = color, "gradient_style" = gradient_style, "gradient_color" = gradient_color, "opacity" = custom_style_normal_opacity(opacity), "emissive" = raw["emissive"] ? TRUE : FALSE))

/// Strictly validates the ordered native markings for one supported limb.
/proc/custom_style_validate_markings(list/raw, list/types, path = "markings", zone)
	if(!(zone in GLOB.body_markings_per_limb) || !islist(raw) || !custom_style_has_type(raw, types, path, "array") || length(raw) > MAXIMUM_MARKINGS_PER_LIMB)
		return list("error" = "The base markings are invalid or exceed the limb's marking limit.")
	var/list/markings = list()
	var/list/names = list()
	for(var/index in 1 to length(raw))
		var/list/entry = raw[index]
		var/entry_path = "[path]\[[index]]"
		if(!islist(entry) || !custom_style_has_type(entry, types, entry_path, "object") || custom_style_unknown_key(entry, GLOB.custom_style_marking_keys))
			return list("error" = "The base marking settings are malformed.")
		for(var/key in GLOB.custom_style_marking_keys)
			if(!(key in entry))
				return list("error" = "The base marking settings are incomplete.")
		var/name = entry["name"]
		if(!custom_style_has_type(name, types, "[entry_path].name", "string") || !istext(name) || !(name in GLOB.body_markings_per_limb[zone]) || (name in names))
			return list("error" = "The base markings contain an unavailable or repeated marking.")
		var/color = custom_style_has_type(entry["color"], types, "[entry_path].color", "string") ? custom_sprite_color(entry["color"]) : null
		if(!color)
			return list("error" = "The base marking colors are invalid.")
		if(!custom_style_has_type(entry["emissive"], types, "[entry_path].emissive", "boolean"))
			return list("error" = "The base marking emissive settings must be true or false.")
		names += name
		markings += list(list("name" = name, "color" = color, "emissive" = entry["emissive"] ? TRUE : FALSE))
	return list("markings" = markings)

/**
 * Validates a package's structure: one drawing target, plus its optional native context.
 *
 * Packages are the server's canonical style shape, used by transfers, runtime restoration and
 * previous saved styles: list("target", "zone", "drawing", "hair", optional "markings").
 * A null drawing is valid empty art; absent markings preserve the destination's native markings.
 *
 * Returns:
 * - list("package" = canonical package)
 * - list("error" = message)
 */
/proc/custom_style_validate_package(list/raw, list/types, root = "")
	if(!islist(raw))
		return list("error" = "The style is malformed.")
	if(custom_style_unknown_key(raw, list("format", "version", "target", "zone", "drawing", "hair", "markings")))
		return list("error" = "The style has an unsupported field.")
	var/prefix = root ? "[root]." : ""
	var/target = raw["target"]
	if(!custom_style_has_type(target, types, "[prefix]target", "string") || !(target in GLOB.custom_style_hair_targets + list("markings")))
		return list("error" = "The style's drawing target is invalid.")
	var/zone = raw["zone"]
	if(target == "markings")
		if(!("zone" in raw))
			return list("error" = "The style is missing its body zone.")
		if(!isnull(zone) && (!custom_style_has_type(zone, types, "[prefix]zone", "string") || !istext(zone) || !(zone in GLOB.custom_marking_zone_labels)))
			return list("error" = "The style's body zone is invalid.")
		if(isnull(zone) && !custom_style_has_type(zone, types, "[prefix]zone", "null"))
			return list("error" = "The style's body zone is invalid.")
	else if(!isnull(zone))
		return list("error" = "Hair styles cannot have a body zone.")
	if(!("drawing" in raw))
		return list("error" = "The style is missing its drawing.")
	var/list/drawing
	if(!isnull(raw["drawing"]))
		// Trusted stored drawings may predate per-view emission settings; uploads must be complete.
		var/list/drawing_result = custom_style_validate_drawing(raw["drawing"], types, "[prefix]drawing", legacy = isnull(types))
		if(drawing_result["error"])
			return drawing_result
		drawing = drawing_result["drawing"]
		if(custom_sprite_width(drawing) == CUSTOM_SPRITE_TAUR_WIDTH)
			if(target != "markings" || (!isnull(zone) && zone != CUSTOM_MARKING_ZONE_TAUR))
				return list("error" = "Wide drawings require whole-body or taur markings.")
		else if(zone == CUSTOM_MARKING_ZONE_TAUR)
			return list("error" = "Taur markings require a wide drawing.")
	else if(!custom_style_has_type(null, types, "[prefix]drawing", "null"))
		return list("error" = "The style's drawing is malformed.")
	var/list/hair
	if(custom_style_hair_target(target))
		var/list/hair_result = custom_style_validate_hair(raw["hair"], types, "[prefix]hair", target)
		if(hair_result["error"])
			return hair_result
		hair = hair_result["hair"]
	else if(!isnull(raw["hair"]))
		return list("error" = "Markings cannot carry hair settings.")
	var/list/markings
	if("markings" in raw)
		if(target != "markings" || !(zone in GLOB.body_markings_per_limb))
			return list("error" = "Base markings require a supported body zone.")
		if(!isnull(raw["markings"]))
			var/list/markings_result = custom_style_validate_markings(raw["markings"], types, "[prefix]markings", zone)
			if(markings_result["error"])
				return markings_result
			markings = markings_result["markings"]
		else if(!custom_style_has_type(null, types, "[prefix]markings", "null"))
			return list("error" = "The base markings are malformed.")
	return list("package" = custom_style_package(target, zone, drawing, hair, markings))

/proc/custom_style_package(target, zone, list/drawing, list/hair, list/markings)
	. = list("target" = target, "zone" = target == "markings" ? zone : null, "drawing" = drawing ? deep_copy_list(drawing) : null, "hair" = hair ? hair.Copy() : null)
	if(!isnull(markings))
		.["markings"] = custom_style_copy_markings(markings)

/// Copy record arrays without deep_copy_list() turning their list values into associative keys.
/proc/custom_style_copy_markings(list/markings)
	if(isnull(markings))
		return null
	. = list()
	for(var/list/entry as anything in markings)
		. += list(entry.Copy())

/// Canonical packages own every drawing, native context and marking record they carry.
/proc/custom_style_copy_package(list/package)
	return package ? custom_style_package(package["target"], package["zone"], package["drawing"], package["hair"], package["markings"]) : null

/// Content identity for proposals, rotations and unchanged checks.
/proc/custom_style_package_hash(list/package)
	if(!package)
		return "none"
	var/list/content = list(package["target"], package["zone"], custom_sprite_hash(package["drawing"]), package["hair"])
	if("markings" in package)
		content += list(package["markings"])
	return md5(json_encode(content))

/// Compare a legacy drawing-only package with the base markings it would preserve.
/proc/custom_style_matches(list/package, list/current)
	if(package && current && !("markings" in package) && ("markings" in current))
		package = package.Copy()
		package["markings"] = current["markings"]
	return custom_style_package_hash(package) == custom_style_package_hash(current)

/**
 * Parses an uploaded style file into a package.
 *
 * Envelopes must match the export format exactly. Strictly valid legacy drawing-only files are
 * also accepted; they return `legacy` so the open editor can supply its own target and hair look.
 *
 * Returns:
 * - list("package" = package, "legacy" = TRUE/FALSE)
 * - list("error" = message): Safe to show the player. Never includes uploaded content.
 */
/proc/custom_style_parse(text)
	var/list/preflight = custom_style_preflight(text)
	if(preflight["error"])
		return preflight
	var/list/types = preflight["types"]
	var/list/decoded
	try
		decoded = json_decode(text)
	catch
		return list("error" = "The file is not valid JSON.")
	if(!islist(decoded))
		return list("error" = "The file must contain a JSON object.")
	if(!("format" in decoded))
		for(var/key in decoded)
			if(istext(key) && findtext(key, "character") == 1)
				return list("error" = "That is an account drawing file, not a style export.")
		if(custom_style_unknown_key(decoded, GLOB.custom_style_drawing_keys))
			return list("error" = "The file isn't a custom style export.")
		var/list/legacy = custom_style_validate_drawing(decoded, types, "", TRUE)
		if(legacy["error"])
			return legacy
		return list("package" = custom_style_package(null, null, legacy["drawing"], null), "legacy" = TRUE)
	if(decoded["format"] != CUSTOM_STYLE_FORMAT || !custom_style_has_type(decoded["format"], types, "format", "string"))
		return list("error" = "The file isn't a custom style export.")
	if(!custom_style_has_type(decoded["version"], types, "version", "number") || decoded["version"] != CUSTOM_STYLE_VERSION)
		return list("error" = "The style file uses an unsupported version.")
	if(custom_style_unknown_key(decoded, list("format", "version", "target", "zone", "drawing", "hair", "markings")))
		return list("error" = "The style file has an unsupported field.")
	var/list/result = custom_style_validate_package(decoded, types)
	if(result["error"])
		return result
	result["legacy"] = FALSE
	return result

/// The export format always includes all four views and their emission settings.
/// BYOND encodes TRUE as 1, so booleans are written through markers that become JSON true/false.
/proc/custom_style_export_text(list/package)
	var/list/envelope = list("format" = CUSTOM_STYLE_FORMAT, "version" = CUSTOM_STYLE_VERSION, "target" = package["target"])
	if(package["target"] == "markings")
		envelope["zone"] = package["zone"]
	var/list/drawing = package["drawing"]
	if(drawing)
		var/list/palette = drawing["palette"]
		var/pixel_count = custom_sprite_width(drawing) * 32
		var/list/dirs = list()
		for(var/direction in GLOB.custom_style_directions)
			dirs[direction] = drawing["dirs"][direction] || custom_sprite_encode_grid(repeat_string(pixel_count, "0"), length(palette), pixel_count)
		var/list/emissive = list()
		for(var/direction in GLOB.custom_style_directions)
			emissive[direction] = custom_sprite_emissive_settings(drawing["emissive"])[direction] ? CUSTOM_STYLE_JSON_TRUE : CUSTOM_STYLE_JSON_FALSE
		envelope["drawing"] = list("version" = drawing["version"] == 3 ? 3 : (length(palette) > 15 ? 2 : 1), "palette" = palette.Copy(), "dirs" = dirs, "tint" = drawing["tint"], "emissive" = emissive)
	else
		envelope["drawing"] = null
	if(custom_style_hair_target(package["target"]))
		var/list/hair = package["hair"]
		hair = hair.Copy()
		hair["emissive"] = hair["emissive"] ? CUSTOM_STYLE_JSON_TRUE : CUSTOM_STYLE_JSON_FALSE
		envelope["hair"] = hair
	if("markings" in package)
		var/list/markings = custom_style_copy_markings(package["markings"])
		for(var/list/entry as anything in markings)
			entry["emissive"] = entry["emissive"] ? CUSTOM_STYLE_JSON_TRUE : CUSTOM_STYLE_JSON_FALSE
		envelope["markings"] = markings
	var/text = json_encode(envelope, JSON_PRETTY_PRINT)
	return replacetext(replacetext(text, "\"[CUSTOM_STYLE_JSON_TRUE]\"", "true"), "\"[CUSTOM_STYLE_JSON_FALSE]\"", "false")

/**
 * Returns the first view with paint outside the destination's allowed pixels.
 *
 * Arguments:
 * - bounds: Direction -> inclusive editor bounds, or null for the whole canvas.
 * - mask: Direction -> row strings, or null for no silhouette restriction.
 *
 * Returns:
 * - null: Every painted pixel is allowed.
 * - text: The label of the first offending view.
 */
/proc/custom_style_paint_outside(list/drawing, list/bounds, list/mask)
	if(!drawing)
		return null
	var/width = custom_sprite_width(drawing)
	for(var/direction in GLOB.custom_style_directions)
		var/grid = custom_sprite_decode_grid(drawing["dirs"][direction], length(drawing["palette"]), width * 32)
		if(!grid)
			continue
		var/list/box = bounds?[direction]
		var/list/rows = mask?[direction]
		for(var/y in 0 to 31)
			var/row = copytext(grid, y * width + 1, (y + 1) * width + 1)
			if(spantext(row, "0") == width)
				continue
			for(var/x in 0 to width - 1)
				if(copytext(row, x + 1, x + 2) == "0")
					continue
				if(bounds && (!box || x < box[1] || y < box[2] || x > box[3] || y > box[4]))
					return GLOB.custom_style_direction_labels[direction]
				if(mask && (!rows || copytext(rows[y + 1], x + 1, x + 2) != "1"))
					return GLOB.custom_style_direction_labels[direction]
	return null

/proc/custom_style_has_emission(list/drawing)
	for(var/direction in drawing?["emissive"])
		if(drawing["emissive"][direction])
			return TRUE
	return FALSE

/**
 * Claims the account's single transfer slot and starts the relevant cooldown.
 *
 * Failed and cancelled attempts consume the cooldown too, so repeated rejected uploads cannot be
 * used to keep the server parsing files.
 *
 * Returns:
 * - null: The caller owns the transfer and must call custom_style_transfer_end().
 * - text: Why the transfer can't start.
 */
/proc/custom_style_transfer_begin(ckey, kind)
	if(!ckey)
		return "Transfers need a connected account."
	var/list/state = GLOB.custom_style_transfers[ckey]
	if(!state)
		state = GLOB.custom_style_transfers[ckey] = list("busy" = FALSE, "import" = 0, "export" = 0)
	if(state["busy"])
		return "Another style transfer is still in progress."
	if(world.time < state[kind])
		return "Please wait [DisplayTimeText(state[kind] - world.time)] before trying again."
	state["busy"] = TRUE
	state[kind] = world.time + (kind == "import" ? CUSTOM_STYLE_IMPORT_COOLDOWN : CUSTOM_STYLE_EXPORT_COOLDOWN)
	return null

/proc/custom_style_transfer_end(ckey)
	var/list/state = GLOB.custom_style_transfers[ckey]
	if(state)
		state["busy"] = FALSE

/proc/custom_style_file_label(list/package)
	if(package["target"] == "facial_hair")
		return "custom-facial-hair-style"
	if(package["target"] == "hair")
		return "custom-hair-style"
	return package["zone"] ? "custom-tattoo-[replacetext(package["zone"], "_", "-")]" : "custom-markings"

/**
 * Sends a package to a client as a downloaded file.
 *
 * The temporary file uses a fixed directory and a server-generated name; nothing from the
 * package becomes a path. It is removed on every exit path.
 *
 * Returns:
 * - null: The download was sent.
 * - text: Why it wasn't.
 */
/proc/custom_style_send(client/receiver, list/package)
	if(!receiver)
		return "You need to be connected to export."
	var/transfer_error = custom_style_transfer_begin(receiver.ckey, "export")
	if(transfer_error)
		return transfer_error
	var/temporary_path = "[CUSTOM_STYLE_EXPORT_DIRECTORY][md5("[world.realtime]-[world.time]-[rand(1, 1e9)]-[REF(package)]")].json"
	var/result
	try
		var/contents = custom_style_export_text(package)
		if(length(rustg_file_write(contents, temporary_path)) || rustg_file_read(temporary_path) != contents)
			result = "The export couldn't be prepared. Try again later."
		else
			DIRECT_OUTPUT(receiver, ftp(file(temporary_path), "[custom_style_file_label(package)].json"))
			log_game("[key_name(receiver)] exported a custom [package["target"]] style ([length(contents)] bytes).")
	catch
		result = "The export couldn't be prepared. Try again later."
	fdel(temporary_path)
	custom_style_transfer_end(receiver.ckey)
	return result

/**
 * Asks a player for a style file and parses it. This sleeps while the file dialog is open.
 *
 * The byte size is checked before the file is read. BYOND has already received the upload by
 * then, so this limit protects parsing, not the transfer itself. Callers must recheck ownership,
 * slot, session and draft revision after this returns.
 *
 * Returns:
 * - null: The player cancelled.
 * - list("package", "legacy", "bytes") or list("error"): See custom_style_parse().
 */
/proc/custom_style_receive(mob/user)
	var/ckey = user?.ckey
	var/transfer_error = custom_style_transfer_begin(ckey, "import")
	if(transfer_error)
		return list("error" = transfer_error)
	var/list/result
	try
		var/uploaded = input(user, "Choose a custom style file to preview.", "Import custom style") as null|file
		if(!isnull(uploaded))
			var/bytes = isfile(uploaded) ? length(uploaded) : 0
			if(!bytes)
				result = list("error" = "The file is empty or unreadable.")
			else if(bytes > CUSTOM_STYLE_MAX_BYTES)
				result = list("error" = "The file is larger than 16 KiB.")
			else
				result = custom_style_parse(file2text(uploaded))
			result["bytes"] = bytes
			if(result["error"])
				log_game("[key_name(user)] had a custom style import rejected ([bytes] bytes): [result["error"]]")
	catch
		result = list("error" = "The file couldn't be read.")
	custom_style_transfer_end(ckey)
	return result

#undef STYLE_JSON_VALUE
#undef STYLE_JSON_VALUE_OR_END
#undef STYLE_JSON_KEY
#undef STYLE_JSON_KEY_OR_END
#undef STYLE_JSON_COLON
#undef STYLE_JSON_COMMA_OR_END
#undef STYLE_JSON_DONE
