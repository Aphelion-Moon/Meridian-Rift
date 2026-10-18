/// Sends the choices with each background's tile, name -> PNG data URL, for the page to draw behind the character preview.
/datum/preference/choiced/background_state/compile_constant_data()
	. = ..()
	var/list/tiles = list()
	// The custom sprite editors draw the same tiles, once a round.
	for(var/list/tile as anything in custom_sprite_background_tiles())
		tiles[tile["name"]] = tile["url"]
	.["tiles"] = tiles
