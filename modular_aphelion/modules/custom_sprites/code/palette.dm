/// Account-wide editor swatches, independent of each character's painted pixels.
/datum/preference/custom_sprite_palette
	savefile_key = "custom_sprite_palette"
	savefile_identifier = PREFERENCE_PLAYER
	can_randomize = FALSE

/datum/preference/custom_sprite_palette/create_default_value()
	return list()

/datum/preference/custom_sprite_palette/deserialize(input, datum/preferences/preferences)
	if(!islist(input) || length(input) > CUSTOM_SPRITE_MAX_CUSTOM_COLORS)
		return null
	var/list/colors = list()
	for(var/raw_color in input)
		var/color = custom_sprite_color(raw_color)
		if(!color || (color in colors) || !isnull(input[raw_color]))
			return null
		colors += color
	return colors

/datum/preference/custom_sprite_palette/is_valid(value, datum/preferences/preferences)
	var/list/colors = deserialize(value, preferences)
	return !isnull(colors) && json_encode(colors) == json_encode(value)

/datum/preference/custom_sprite_palette/serialize(input)
	return deserialize(input)

/// The custom editor owns this preference's UI.
/datum/preference/custom_sprite_palette/is_accessible(datum/preferences/preferences)
	. = ..()
	return FALSE
