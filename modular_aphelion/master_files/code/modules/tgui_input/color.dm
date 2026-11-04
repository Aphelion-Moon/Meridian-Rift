/// Shortcuts to the picking player's own colours: their character's three mutant colours, and its skin tone when it uses one.
/datum/tgui_color_picker/ui_static_data(mob/user)
	. = ..()
	var/datum/preferences/prefs = user.client?.prefs
	if(!prefs)
		return
	.["mutant_colors"] = prefs.read_preference(/datum/preference/tri_color/mutant_colors)
	var/datum/preference/skin_tone = GLOB.preference_entries[/datum/preference/choiced/skin_tone]
	if(skin_tone.is_applicable(prefs))
		.["skin_tone"] = skintone2hex(prefs.read_preference(/datum/preference/choiced/skin_tone))
