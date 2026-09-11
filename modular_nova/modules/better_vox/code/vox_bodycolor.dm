/datum/preference/choiced/vox_bodycolor
	savefile_key = "vox_bodycolor"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_FEATURES
	main_feature_name = "Skin color"
	should_generate_icons = TRUE

/datum/preference/choiced/vox_bodycolor/init_possible_values()
	return list("default", "darkteal", "yellow", "albino", "brown")

/datum/preference/choiced/vox_bodycolor/create_default_value()
	return "default"

/datum/preference/choiced/vox_bodycolor/is_accessible(datum/preferences/preferences)
	. = ..()
	if(!.)
		return FALSE

	var/species_type = preferences.read_preference(/datum/preference/choiced/species)

	return species_type == /datum/species/vox_primalis

/datum/preference/choiced/vox_bodycolor/icon_for(value)
	var/limb_prefix = value == "default" ? SPECIES_VOX_PRIMALIS : "[SPECIES_VOX_PRIMALIS]_[value]"
	var/bodyparts_icon = /obj/item/bodypart/head/mutant/vox_primalis::icon_static
	var/datum/universal_icon/body = uni_icon(bodyparts_icon, "[limb_prefix]_[BODY_ZONE_HEAD]")
	for(var/body_zone in list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		body.blend_icon(uni_icon(bodyparts_icon, "[limb_prefix]_[body_zone]"), ICON_OVERLAY)

	var/eyes_icon = /obj/item/bodypart/head/mutant/vox_primalis::eyes_icon
	var/datum/universal_icon/eyes = uni_icon(eyes_icon, "eyes_l")
	eyes.blend_icon(uni_icon(eyes_icon, "eyes_r"), ICON_OVERLAY)
	eyes.blend_color(COLOR_BLACK, ICON_MULTIPLY)
	body.blend_icon(eyes, ICON_OVERLAY)

	body.scale(64, 64)
	body.crop(16, 64 - 31, 16 + 31, 64)
	return body

/datum/preference/choiced/vox_bodycolor/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features["vox_bodycolor"] = value
