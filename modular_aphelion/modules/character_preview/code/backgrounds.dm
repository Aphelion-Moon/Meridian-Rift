/// The backgrounds' tiles for the page to draw behind the character preview, with the choices.
/datum/preference/choiced/background_state/compile_constant_data()
	. = ..()
	.["tiles"] = character_preview_background_tiles()

/// Each character preview background's tile as a PNG data URL, by name. Drawn once a round.
/proc/character_preview_background_tiles()
	var/static/list/tiles
	if(tiles)
		return tiles
	tiles = list()
	for(var/name in GLOB.background_state_options)
		tiles[name] = "data:image/png;base64,[icon2base64(icon('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', name, SOUTH))]"
	return tiles
