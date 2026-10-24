/// The lowest rotation a part can have, in degrees
#define CYBORG_LAYOUT_MIN_ROTATION -180
/// The highest rotation a part can have, in degrees
#define CYBORG_LAYOUT_MAX_ROTATION 180
/// The smallest scale a part can have, as a multiple of its art's size
#define CYBORG_LAYOUT_MIN_SCALE 0.25
/// The largest scale a part can have, as a multiple of its art's size
#define CYBORG_LAYOUT_MAX_SCALE 2
/// The lowest layer order a part can have, which draws it under the other parts
#define CYBORG_LAYOUT_MIN_PRIORITY 1
/// The highest layer order a part can have, which draws it over the other parts
#define CYBORG_LAYOUT_MAX_PRIORITY 10

/// Save texts store parts by their place here, so only append. Every caller shares the list, so none may change it
/proc/cyborg_layout_supported_slots()
	var/static/list/slots = list("penis", "sheath", "testicles", "vagina", "anus", "breasts")
	return slots

/// Save texts store overrides by their place here, so only append.
/proc/cyborg_layout_supported_advanced_keys()
	var/static/list/keys
	if(keys)
		return keys
	keys = list("north", "south", "east", "west")
	for(var/pose in list("idle", "rest", "sit", "bellyup", "rest_deep", "rest_alt", "sit_alt"))
		for(var/direction in list("north", "south", "east", "west"))
			keys += "[pose]_[direction]"
	return keys

/// Returns a new layout tree with default parts and no presets or model defaults
/proc/cyborg_layout_default()
	return list(
		"schema_version" = CYBORG_LAYOUT_SCHEMA_VERSION,
		"active" = cyborg_layout_default_slots(),
		"presets" = list(),
		"preset_models" = list(),
		"model_presets" = list(),
		"model_defaults" = list(),
	)

/// Returns the sprite size a slot's parts start at
/proc/cyborg_layout_default_sprite_size(slot)
	if(slot in list("penis", "sheath", "testicles"))
		return 2
	return 1

/// Returns a sprite size clamped to the allowed range, or the slot's default when it isn't a number
/proc/cyborg_layout_sprite_size(value, slot)
	var/default_value = cyborg_layout_default_sprite_size(slot)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value))
		return default_value
	return clamp(round(value), CYBORG_LAYOUT_MIN_SPRITE_SIZE, CYBORG_LAYOUT_MAX_SPRITE_SIZE)

/// Returns a new part entry with every field at its default
/proc/cyborg_layout_default_entry(slot = null)
	return list(
		"pixel_x" = 0,
		"pixel_y" = 0,
		"rotation" = 0,
		"scale" = 1,
		"sprite_size" = cyborg_layout_default_sprite_size(slot),
		"mirror_sides" = TRUE,
		"reuse_south" = FALSE,
		"placement_groups" = list(),
		"colors" = list("#ffffff", "#ffffff", "#ffffff"),
		"advanced" = list(),
	)

/// Returns a new layout with every part slot at its defaults
/proc/cyborg_layout_default_slots()
	var/list/slots = list()
	for(var/slot in cyborg_layout_supported_slots())
		slots[slot] = cyborg_layout_default_entry(slot)
	return slots

/// Returns a number clamped to its range and rounded to its step, or the default when it isn't one. Text numbers are read too
/proc/cyborg_layout_number(value, minimum, maximum, default_value, step = 0.01)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value))
		return default_value
	// sanitize_float intentionally substitutes its default for out-of-range values.
	// Layout input instead clamps at its declared schema boundary before rounding.
	return sanitize_float(clamp(value, minimum, maximum), minimum, maximum, step, default_value)

/// Returns a part entry in canonical form, every field bounded and filled in, or the slot's defaults when raw isn't a list
/proc/cyborg_layout_normalize_entry(raw, allow_legacy_aliases = FALSE, slot = null)
	if(!islist(raw))
		return cyborg_layout_default_entry(slot)
	var/list/entry = list(
		"pixel_x" = cyborg_layout_number(raw["pixel_x"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1),
		"pixel_y" = cyborg_layout_number(raw["pixel_y"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1),
		"rotation" = cyborg_layout_number(raw["rotation"], CYBORG_LAYOUT_MIN_ROTATION, CYBORG_LAYOUT_MAX_ROTATION, 0, 1),
		"scale" = cyborg_layout_number(raw["scale"], CYBORG_LAYOUT_MIN_SCALE, CYBORG_LAYOUT_MAX_SCALE, 1, 0.05),
		"sprite_size" = cyborg_layout_sprite_size(raw["sprite_size"], slot),
		"mirror_sides" = isnull(raw["mirror_sides"]) ? TRUE : !!raw["mirror_sides"],
		"reuse_south" = !!raw["reuse_south"],
		"placement_groups" = list(),
		"colors" = list(),
		"advanced" = cyborg_layout_normalize_advanced(raw["advanced"], allow_legacy_aliases),
	)
	if(istext(raw["sprite"]) && length_char(raw["sprite"]) <= 100)
		entry["sprite"] = raw["sprite"]
	var/list/groups = raw["placement_groups"]
	if(islist(groups))
		for(var/group in list("north", "south", "side"))
			var/list/position = groups[group]
			if(!islist(position))
				continue
			entry["placement_groups"][group] = list(
				"pixel_x" = cyborg_layout_number(position["pixel_x"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, entry["pixel_x"], 1),
				"pixel_y" = cyborg_layout_number(position["pixel_y"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, entry["pixel_y"], 1),
				"rotation" = cyborg_layout_number(position["rotation"], CYBORG_LAYOUT_MIN_ROTATION, CYBORG_LAYOUT_MAX_ROTATION, entry["rotation"], 1),
			)
	var/list/raw_colors = raw["colors"]
	for(var/index in 1 to 3)
		var/color = islist(raw_colors) && length(raw_colors) >= index ? raw_colors[index] : null
		entry["colors"] += sanitize_hexcolor(color, default = "#ffffff")
	return entry

/// Returns a part's overrides in canonical form. An import also expands donor pose-wide entries to each direction
/proc/cyborg_layout_normalize_advanced(raw, allow_legacy_aliases = FALSE)
	var/list/normalized = list()
	if(!islist(raw))
		return normalized
	var/list/supported = cyborg_layout_supported_advanced_keys()
	for(var/key in supported)
		var/list/entry = cyborg_layout_normalize_advanced_entry(raw[key])
		if(entry)
			normalized[key] = entry
	if(allow_legacy_aliases)
		// Donor files used one pose-wide entry. Import expands only recognized aliases.
		var/static/list/pose_aliases = list("belly_up" = "bellyup", "deep_rest" = "rest_deep")
		for(var/legacy_pose in list("rest", "sit", "bellyup", "belly_up", "rest_deep", "deep_rest", "rest_alt", "sit_alt"))
			if((legacy_pose in supported) || !islist(raw[legacy_pose]))
				continue
			var/pose = pose_aliases[legacy_pose] || legacy_pose
			var/list/legacy_entry = cyborg_layout_normalize_advanced_entry(raw[legacy_pose])
			if(!legacy_entry)
				continue
			for(var/direction in list("north", "south", "east", "west"))
				var/directional_key = "[pose]_[direction]"
				if(!(directional_key in normalized))
					normalized[directional_key] = deep_copy_list(legacy_entry)
	return normalized

/// Returns one override with only the fields it sets, bounded, or null when it sets none. Arousal states can't nest, so they pass allow_arousal FALSE
/proc/cyborg_layout_normalize_advanced_entry(raw, allow_arousal = TRUE)
	if(!islist(raw))
		return null
	var/list/entry = list()
	if("visible" in raw)
		entry["visible"] = !!raw["visible"]
	if("pixel_x" in raw)
		entry["pixel_x"] = cyborg_layout_number(raw["pixel_x"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1)
	if("pixel_y" in raw)
		entry["pixel_y"] = cyborg_layout_number(raw["pixel_y"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1)
	if("rotation" in raw)
		entry["rotation"] = cyborg_layout_number(raw["rotation"], CYBORG_LAYOUT_MIN_ROTATION, CYBORG_LAYOUT_MAX_ROTATION, 0, 1)
	if("scale" in raw)
		entry["scale"] = cyborg_layout_number(raw["scale"], CYBORG_LAYOUT_MIN_SCALE, CYBORG_LAYOUT_MAX_SCALE, 1, 0.05)
	if("priority" in raw)
		entry["priority"] = cyborg_layout_number(raw["priority"], CYBORG_LAYOUT_MIN_PRIORITY, CYBORG_LAYOUT_MAX_PRIORITY, CYBORG_LAYOUT_MIN_PRIORITY, 1)
	var/list/arousal = raw["arousal"]
	if(allow_arousal && islist(arousal))
		var/list/normalized_arousal = list()
		for(var/state in list("none", "partial", "full"))
			var/list/state_entry = cyborg_layout_normalize_advanced_entry(arousal[state], FALSE)
			if(state_entry)
				normalized_arousal[state] = state_entry
		if(length(normalized_arousal))
			entry["arousal"] = normalized_arousal
	return length(entry) ? entry : null

/// Returns a layout with every part slot normalized, defaults filling the missing ones
/proc/cyborg_layout_normalize_slots(raw, allow_legacy_aliases = FALSE)
	var/list/normalized = list()
	for(var/slot in cyborg_layout_supported_slots())
		normalized[slot] = cyborg_layout_normalize_entry(islist(raw) ? raw[slot] : null, allow_legacy_aliases, slot)
	return normalized

/**
 * A layout tree in its canonical form, or the default tree when `raw` is not one.
 *
 * Arguments:
 * * raw - the tree to normalize
 * * normalize_model_defaults - whether to keep model defaults at all
 * * allow_legacy_aliases - whether model ids from older builds are mapped to today's
 * * only_model_default - optional, a model id: only that default is normalized, the others kept are left as TRUE, for
 *   callers that read just that one
 */
/proc/cyborg_layout_normalize(raw, normalize_model_defaults = TRUE, allow_legacy_aliases = FALSE, only_model_default)
	if(!islist(raw))
		return cyborg_layout_default()
	var/version = raw["schema_version"]
	if(!isnull(version) && (!isnum(version) || version > CYBORG_LAYOUT_SCHEMA_VERSION))
		return cyborg_layout_default()
	var/list/normalized = list(
		"schema_version" = CYBORG_LAYOUT_SCHEMA_VERSION,
		"active" = cyborg_layout_normalize_slots(raw["active"], allow_legacy_aliases),
		"presets" = list(),
		"preset_models" = list(),
		"model_presets" = list(),
		"model_defaults" = list(),
	)
	var/list/raw_presets = raw["presets"]
	// Only accepted raw names may supply references or metadata after canonicalization.
	var/list/preset_names = list()
	if(islist(raw_presets))
		var/preset_candidates = 0
		for(var/raw_name, raw_layout in raw_presets)
			preset_candidates++
			if(preset_candidates > CYBORG_LAYOUT_MAX_PRESETS)
				break
			if(!istext(raw_name))
				continue
			var/name = trim(raw_name, CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH + 1)
			if(!length(name) || (name in normalized["presets"]))
				continue
			normalized["presets"][name] = cyborg_layout_normalize_slots(raw_layout, allow_legacy_aliases)
			preset_names[raw_name] = name
	var/list/catalog = cyborg_model_catalog()
	var/active_model = cyborg_canonical_model_id(raw["active_model"])
	if(active_model && catalog[active_model])
		normalized["active_model"] = active_model
	var/list/raw_preset_models = raw["preset_models"]
	for(var/raw_name, name in preset_names)
		var/model_id = cyborg_canonical_model_id(islist(raw_preset_models) ? raw_preset_models[raw_name] : null)
		if(model_id && catalog[model_id])
			normalized["preset_models"][name] = model_id
	var/active_preset = istext(raw["active_preset"]) ? preset_names[raw["active_preset"]] : null
	if(active_preset)
		normalized["active_preset"] = active_preset
	if(!normalize_model_defaults)
		return normalized
	var/list/raw_defaults = raw["model_defaults"]
	if(!islist(raw_defaults) || !length(raw_defaults))
		return normalized
	var/default_candidates = 0
	var/default_candidate_limit = max(1, length(catalog) * 2)
	var/list/raw_assignments = raw["model_presets"]
	for(var/model_id, raw_default in raw_defaults)
		default_candidates++
		if(default_candidates > default_candidate_limit)
			break
		if(!istext(model_id))
			continue
		var/canonical_id = cyborg_canonical_model_id(model_id)
		if(allow_legacy_aliases && !(canonical_id in catalog))
			canonical_id = cyborg_model_legacy_id(model_id)
		if(!canonical_id || !(canonical_id in catalog))
			continue
		if(canonical_id != model_id && raw_defaults[canonical_id])
			continue
		// The editor refuses more, so only an import can reach this; it keeps the first ones like presets do.
		if(!normalized["model_defaults"][canonical_id] && length(normalized["model_defaults"]) >= CYBORG_LAYOUT_MAX_MODEL_DEFAULTS)
			break
		normalized["model_defaults"][canonical_id] = !only_model_default || canonical_id == only_model_default ? cyborg_layout_normalize_slots(raw_default, allow_legacy_aliases) : TRUE
		// Follow the accepted snapshot's original key before canonicalizing its assignment.
		var/raw_name = islist(raw_assignments) ? raw_assignments[model_id] : null
		var/name = istext(raw_name) ? preset_names[raw_name] : null
		if(name && normalized["preset_models"][name] == canonical_id)
			normalized["model_presets"][canonical_id] = name
		else
			normalized["model_presets"] -= canonical_id
	return normalized

/// Whether a stored or uploaded slot comes from a newer build. It is kept as it is and never rewritten.
/proc/cyborg_layout_import_is_future(raw)
	if(istext(raw))
		return cyborg_layout_text_is_future(raw)
	if(!islist(raw))
		return FALSE
	var/version = raw["schema_version"]
	return !isnull(version) && (!isnum(version) || version > CYBORG_LAYOUT_SCHEMA_VERSION)

/// Import-only migration of donor identity keys. Layouts are read separately into the sidecar.
/proc/cyborg_identity_import_sanitize_slot(list/slot)
	if(!islist(slot))
		return
	for(var/donor_key, key in list("headshot_silicon" = "silicon_headshot", "headshot_silicon_nsfw" = "silicon_headshot_nsfw"))
		if(!(donor_key in slot))
			continue
		if(!(key in slot))
			slot[key] = slot[donor_key]
		slot -= donor_key
	slot -= "silicon_genital_layout_presets"

#undef CYBORG_LAYOUT_MIN_ROTATION
#undef CYBORG_LAYOUT_MAX_ROTATION
#undef CYBORG_LAYOUT_MIN_SCALE
#undef CYBORG_LAYOUT_MAX_SCALE
#undef CYBORG_LAYOUT_MIN_PRIORITY
#undef CYBORG_LAYOUT_MAX_PRIORITY
