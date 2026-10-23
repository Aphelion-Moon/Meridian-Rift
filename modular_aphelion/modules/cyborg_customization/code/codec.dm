/**
 * The compact save text for one character slot, kept as a string in cyborg_customization.json.
 *
 * A slot is a JSON array of [format version, active layout, presets, model defaults, active model, active preset].
 * Presets are flat [name, layout, chassis] triples and model defaults flat [chassis, layout, linked preset] triples.
 * A layout lists its parts in cyborg_layout_supported_slots() order, 0 for an untouched part. A part is [mask, values...]:
 * each mask bit marks a field that differs from its default, and its value follows in bit order unless the bit says it all.
 * Overrides are flat [key, override] pairs, the key an index into cyborg_layout_supported_advanced_keys(). An override is
 * [header, values..., arousal states]: the header's low six bits say which fields it has, the next six which of those
 * differ from what the editor fills a new override with, and only those values are written.
 * Decoding rebuilds the nested tree and runs it through cyborg_layout_normalize(), so a reload matches the old format.
 * Unset trailing fields are left out everywhere. Appending to these orders is fine; reordering breaks saved slots.
 */

#define CYBORG_CODEC_VERSION 2

#define CYBORG_PART_PIXEL_X (1<<0)
#define CYBORG_PART_PIXEL_Y (1<<1)
#define CYBORG_PART_ROTATION (1<<2)
#define CYBORG_PART_SCALE (1<<3)
#define CYBORG_PART_SPRITE_SIZE (1<<4)
/// No value follows; the bit alone turns mirror_sides off.
#define CYBORG_PART_NO_MIRROR (1<<5)
/// No value follows; the bit alone turns reuse_south on.
#define CYBORG_PART_REUSE_SOUTH (1<<6)
#define CYBORG_PART_COLORS (1<<7)
#define CYBORG_PART_GROUPS (1<<8)
#define CYBORG_PART_ADVANCED (1<<9)
#define CYBORG_PART_SPRITE (1<<10)

/// Override fields in header bit order, with what the editor fills a new override with.
/proc/cyborg_layout_override_fields()
	var/static/list/fields = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "scale" = 1, "priority" = 5)
	return fields

/// Element `index` of a decoded list, or null past its end.
/proc/cyborg_layout_codec_element(list/encoded, index)
	return index <= length(encoded) ? encoded[index] : null

/// Drops unset trailing elements, which decoding reads as unset.
/proc/cyborg_layout_codec_trim(list/encoded)
	var/kept = length(encoded)
	while(kept)
		var/value = encoded[kept]
		if(islist(value) ? length(value) : value)
			break
		kept--
	encoded.len = kept
	return encoded

/// The save text for a character slot.
/proc/cyborg_layout_encode(list/layout)
	var/list/presets = list()
	var/list/preset_models = layout["preset_models"]
	for(var/name, preset in layout["presets"])
		presets[++presets.len] = name
		presets[++presets.len] = cyborg_layout_encode_slots(preset)
		presets[++presets.len] = preset_models?[name] || 0
	var/list/defaults = list()
	var/list/model_presets = layout["model_presets"]
	for(var/model_id, model_default in layout["model_defaults"])
		defaults[++defaults.len] = model_id
		defaults[++defaults.len] = cyborg_layout_encode_slots(model_default)
		defaults[++defaults.len] = model_presets?[model_id] || 0
	var/list/encoded = list(CYBORG_CODEC_VERSION)
	encoded[++encoded.len] = cyborg_layout_encode_slots(layout["active"])
	encoded[++encoded.len] = presets
	encoded[++encoded.len] = defaults
	encoded[++encoded.len] = layout["active_model"] || 0
	encoded[++encoded.len] = layout["active_preset"] || 0
	return json_encode(cyborg_layout_codec_trim(encoded))

/proc/cyborg_layout_encode_slots(list/slots)
	var/list/encoded = list()
	for(var/slot in cyborg_layout_supported_slots())
		encoded[++encoded.len] = cyborg_layout_encode_part(islist(slots) ? slots[slot] : null, slot)
	return cyborg_layout_codec_trim(encoded)

/// Fields are read the way cyborg_layout_normalize_entry() reads them, so leaving one out decodes to the same value.
/proc/cyborg_layout_encode_part(list/entry, slot)
	if(!islist(entry))
		return 0
	var/mask = 0
	var/list/encoded = list(0)
	if(entry["pixel_x"])
		mask |= CYBORG_PART_PIXEL_X
		encoded[++encoded.len] = entry["pixel_x"]
	if(entry["pixel_y"])
		mask |= CYBORG_PART_PIXEL_Y
		encoded[++encoded.len] = entry["pixel_y"]
	if(entry["rotation"])
		mask |= CYBORG_PART_ROTATION
		encoded[++encoded.len] = entry["rotation"]
	if(!isnull(entry["scale"]) && entry["scale"] != 1)
		mask |= CYBORG_PART_SCALE
		encoded[++encoded.len] = entry["scale"]
	if(!isnull(entry["sprite_size"]) && entry["sprite_size"] != cyborg_layout_default_sprite_size(slot))
		mask |= CYBORG_PART_SPRITE_SIZE
		encoded[++encoded.len] = entry["sprite_size"]
	if(!isnull(entry["mirror_sides"]) && !entry["mirror_sides"])
		mask |= CYBORG_PART_NO_MIRROR
	if(entry["reuse_south"])
		mask |= CYBORG_PART_REUSE_SOUTH
	var/list/colors = entry["colors"]
	if(islist(colors) && !(length(colors) == 3 && colors[1] == "#ffffff" && colors[2] == "#ffffff" && colors[3] == "#ffffff"))
		mask |= CYBORG_PART_COLORS
		encoded[++encoded.len] = colors.Copy()
	var/list/groups = entry["placement_groups"]
	if(length(groups))
		var/list/positions = list()
		for(var/group in list("north", "south", "side"))
			var/list/position = groups[group]
			positions[++positions.len] = islist(position) ? list(position["pixel_x"], position["pixel_y"], position["rotation"]) : 0
		if(length(cyborg_layout_codec_trim(positions)))
			mask |= CYBORG_PART_GROUPS
			encoded[++encoded.len] = positions
	var/list/advanced = cyborg_layout_encode_advanced(entry["advanced"])
	if(length(advanced))
		mask |= CYBORG_PART_ADVANCED
		encoded[++encoded.len] = advanced
	if(istext(entry["sprite"]))
		mask |= CYBORG_PART_SPRITE
		encoded[++encoded.len] = entry["sprite"]
	if(!mask)
		return 0
	encoded[1] = mask
	return encoded

/proc/cyborg_layout_encode_advanced(list/advanced)
	if(!length(advanced))
		return null
	var/static/list/key_indices
	if(!key_indices)
		key_indices = list()
		var/list/keys = cyborg_layout_supported_advanced_keys()
		for(var/index in 1 to length(keys))
			key_indices[keys[index]] = index
	var/list/encoded = list()
	for(var/key, override in advanced)
		if(!istext(key) || !key_indices[key])
			continue
		var/list/code = cyborg_layout_encode_override(override)
		if(code)
			encoded[++encoded.len] = key_indices[key]
			encoded[++encoded.len] = code
	return encoded

/// An arousal state writes every field it has: there each one overrides its pose, whatever the value.
/proc/cyborg_layout_encode_override(list/override, arousal_state = FALSE)
	if(!islist(override))
		return null
	var/present = 0
	var/changed = 0
	var/bit = 1
	var/list/encoded = list(0)
	for(var/field, default_value in cyborg_layout_override_fields())
		if(field in override)
			present |= bit
			var/value = override[field]
			if(arousal_state || value != default_value)
				changed |= bit
				encoded[++encoded.len] = value
		bit *= 2
	if(!arousal_state && islist(override["arousal"]))
		var/list/arousal = override["arousal"]
		var/list/states = list()
		for(var/state in list("none", "partial", "full"))
			states[++states.len] = cyborg_layout_encode_override(arousal[state], TRUE) || 0
		if(length(cyborg_layout_codec_trim(states)))
			encoded[++encoded.len] = states
	if(!present && length(encoded) == 1)
		return null
	encoded[1] = arousal_state ? present : present | (changed << 6)
	return encoded

/// The normalized tree for a save text, or null when the text is not a save of this format.
/proc/cyborg_layout_decode(text)
	var/list/encoded
	try
		encoded = json_decode(text)
	catch
		return null
	if(!islist(encoded) || !length(encoded) || encoded[1] != CYBORG_CODEC_VERSION)
		return null
	var/list/raw = list(
		"schema_version" = CYBORG_LAYOUT_SCHEMA_VERSION,
		"active" = cyborg_layout_decode_slots(cyborg_layout_codec_element(encoded, 2)),
		"presets" = list(),
		"preset_models" = list(),
		"model_presets" = list(),
		"model_defaults" = list(),
	)
	var/list/presets = cyborg_layout_codec_element(encoded, 3)
	if(islist(presets))
		for(var/index = 1, index + 2 <= length(presets), index += 3)
			var/name = presets[index]
			if(!istext(name))
				continue
			raw["presets"][name] = cyborg_layout_decode_slots(presets[index + 1])
			if(istext(presets[index + 2]))
				raw["preset_models"][name] = presets[index + 2]
	var/list/defaults = cyborg_layout_codec_element(encoded, 4)
	if(islist(defaults))
		for(var/index = 1, index + 2 <= length(defaults), index += 3)
			var/model_id = defaults[index]
			if(!istext(model_id))
				continue
			raw["model_defaults"][model_id] = cyborg_layout_decode_slots(defaults[index + 1])
			if(istext(defaults[index + 2]))
				raw["model_presets"][model_id] = defaults[index + 2]
	var/active_model = cyborg_layout_codec_element(encoded, 5)
	if(istext(active_model))
		raw["active_model"] = active_model
	var/active_preset = cyborg_layout_codec_element(encoded, 6)
	if(istext(active_preset))
		raw["active_preset"] = active_preset
	return cyborg_layout_normalize(raw)

/proc/cyborg_layout_decode_slots(list/encoded)
	var/list/slots = list()
	if(!islist(encoded))
		return slots
	var/list/names = cyborg_layout_supported_slots()
	for(var/index in 1 to min(length(encoded), length(names)))
		var/list/entry = cyborg_layout_decode_part(encoded[index])
		if(entry)
			slots[names[index]] = entry
	return slots

/proc/cyborg_layout_decode_part(list/encoded)
	if(!islist(encoded) || !length(encoded) || !isnum(encoded[1]))
		return null
	var/mask = encoded[1]
	var/index = 1
	var/list/entry = list()
	if(mask & CYBORG_PART_PIXEL_X)
		entry["pixel_x"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_PIXEL_Y)
		entry["pixel_y"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_ROTATION)
		entry["rotation"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_SCALE)
		entry["scale"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_SPRITE_SIZE)
		entry["sprite_size"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_NO_MIRROR)
		entry["mirror_sides"] = FALSE
	if(mask & CYBORG_PART_REUSE_SOUTH)
		entry["reuse_south"] = TRUE
	if(mask & CYBORG_PART_COLORS)
		entry["colors"] = cyborg_layout_codec_element(encoded, ++index)
	if(mask & CYBORG_PART_GROUPS)
		var/list/positions = cyborg_layout_codec_element(encoded, ++index)
		var/list/groups = list()
		if(islist(positions))
			var/list/names = list("north", "south", "side")
			for(var/group_index in 1 to min(length(positions), length(names)))
				var/list/position = positions[group_index]
				if(islist(position))
					groups[names[group_index]] = list(
						"pixel_x" = cyborg_layout_codec_element(position, 1),
						"pixel_y" = cyborg_layout_codec_element(position, 2),
						"rotation" = cyborg_layout_codec_element(position, 3),
					)
		entry["placement_groups"] = groups
	if(mask & CYBORG_PART_ADVANCED)
		entry["advanced"] = cyborg_layout_decode_advanced(cyborg_layout_codec_element(encoded, ++index))
	if(mask & CYBORG_PART_SPRITE)
		entry["sprite"] = cyborg_layout_codec_element(encoded, ++index)
	return entry

/proc/cyborg_layout_decode_advanced(list/encoded)
	var/list/advanced = list()
	if(!islist(encoded))
		return advanced
	var/list/keys = cyborg_layout_supported_advanced_keys()
	for(var/index = 1, index + 1 <= length(encoded), index += 2)
		var/key_index = encoded[index]
		if(!isnum(key_index) || key_index < 1 || key_index > length(keys) || round(key_index) != key_index)
			continue
		var/list/override = cyborg_layout_decode_override(encoded[index + 1])
		if(override)
			advanced[keys[key_index]] = override
	return advanced

/proc/cyborg_layout_decode_override(list/encoded, arousal_state = FALSE)
	if(!islist(encoded) || !length(encoded) || !isnum(encoded[1]))
		return null
	var/present = encoded[1] & 63
	var/changed = arousal_state ? present : (encoded[1] >> 6) & 63
	var/index = 1
	var/bit = 1
	var/list/override = list()
	for(var/field, default_value in cyborg_layout_override_fields())
		if(present & bit)
			if(changed & bit)
				override[field] = cyborg_layout_codec_element(encoded, ++index)
			else
				override[field] = default_value
		bit *= 2
	var/list/states = cyborg_layout_codec_element(encoded, index + 1)
	if(!arousal_state && islist(states))
		var/list/arousal = list()
		var/list/names = list("none", "partial", "full")
		for(var/state_index in 1 to min(length(states), length(names)))
			var/list/state = cyborg_layout_decode_override(states[state_index], TRUE)
			if(state)
				arousal[names[state_index]] = state
		override["arousal"] = arousal
	return override

/// Whether a save text comes from a newer format. Every format starts with its version, so this needs no decode.
/proc/cyborg_layout_text_is_future(text)
	var/version = text2num(copytext(text, 2, findtext(text, ",")))
	return isnum(version) && version > CYBORG_CODEC_VERSION

/// The editable tree for whatever a slot holds: save text, an older nested tree, or nothing.
/proc/cyborg_layout_from_stored(stored)
	if(istext(stored))
		return cyborg_layout_decode(stored) || cyborg_layout_default()
	return cyborg_layout_normalize(stored)

#undef CYBORG_CODEC_VERSION
#undef CYBORG_PART_PIXEL_X
#undef CYBORG_PART_PIXEL_Y
#undef CYBORG_PART_ROTATION
#undef CYBORG_PART_SCALE
#undef CYBORG_PART_SPRITE_SIZE
#undef CYBORG_PART_NO_MIRROR
#undef CYBORG_PART_REUSE_SOUTH
#undef CYBORG_PART_COLORS
#undef CYBORG_PART_GROUPS
#undef CYBORG_PART_ADVANCED
#undef CYBORG_PART_SPRITE
