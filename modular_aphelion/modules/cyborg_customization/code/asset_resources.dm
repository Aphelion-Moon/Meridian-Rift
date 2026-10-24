/// Returns a chassis's occlusion mask - its family's mask icon and the state its poses add their suffix to - or null when it has none
/proc/cyborg_occlusion_mask(list/descriptor)
	var/static/list/masks = list(
		"alina" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/alinamask.dmi', "alina-eng"),
		"borgi" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/borgimask.dmi', "borgi-jani"),
		"drake" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/drakemask.dmi', "drake"),
		"hound" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/houndmask.dmi', "hound"),
		"otie" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/otiemask.dmi', "otie"),
		"vale" = list('modular_aphelion/modules/cyborg_customization/icons/occlusion_masks/valemask.dmi', "vale"),
	)
	var/family = GLOB.cyborg_animation_manifest["models"]["[descriptor["icon"]]#[descriptor["icon_state"]]"]
	return family && masks[family]
