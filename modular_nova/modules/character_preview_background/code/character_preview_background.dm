/// Enables the choice of background in the character preview menu
/datum/preference/choiced/background_state
	savefile_key = "background_state"
	savefile_identifier = PREFERENCE_CHARACTER

GLOBAL_LIST_INIT(background_state_options, list(
	"Black",
	"Grey",
	"White",
	"White Tiles",
	"Plasteel",
	"Dark Tiles" ,
	"Plating",
	"Reinforced Floor",
))

/datum/preference/choiced/background_state/create_default_value()
	return GLOB.background_state_options[1]

/datum/preference/choiced/background_state/init_possible_values()
	return GLOB.background_state_options

/datum/preference/choiced/background_state/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/// Rebuild directional worn offsets before copying the dummy into the preview canvas.
/atom/movable/screen/map_view/char_preview/setDir(newdir)
	. = ..()
	// Directory and records previews use this screen type without a preference dummy or canvas.
	if(isnull(body) || isnull(canvas))
		return

	body.setDir(dir)
	canvas.dir = body.dir
	canvas.cut_overlays()
	canvas.add_overlay(body.appearance)
	appearance = canvas.appearance
