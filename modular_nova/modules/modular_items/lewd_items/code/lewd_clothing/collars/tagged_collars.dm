/datum/atom_skin/collar_tagged
	abstract_type = /datum/atom_skin/collar_tagged
	greyscale_item_path = /obj/item/clothing/neck/collar/tagged

//Alphabetically sorted; the initial selection is Tagged (Thin)
/datum/atom_skin/collar_tagged/thin_bell
	preview_name = "Bell (Thin)"
	new_icon_state = "thin_bell_collar"
	new_name = "bell collar"

/datum/atom_skin/collar_tagged/thin_cowbell
	preview_name = "Cowbell (Thin)"
	new_icon_state = "thin_cowbell_collar"
	new_name = "cowbell collar"

/datum/atom_skin/collar_tagged/thin_cross
	preview_name = "Cross (Thin)"
	new_icon_state = "thin_cross_collar"
	new_name = "cross collar"

/datum/atom_skin/collar_tagged/thin_holo
	preview_name = "Holographic (Thin)"
	new_icon_state = "thin_holocollar"
	new_name = "holocollar"

/datum/atom_skin/collar_tagged/thin_tag
	preview_name = "Tagged (Thin)"
	new_icon_state = "thin_tagged_collar"

/datum/atom_skin/collar_tagged/thick_bell
	preview_name = "Bell (Thick)"
	new_icon_state = "thick_bell_collar"
	new_name = "bell collar"

/datum/atom_skin/collar_tagged/thick_cowbell
	preview_name = "Cowbell (Thick)"
	new_icon_state = "thick_cowbell_collar"
	new_name = "cowbell collar"

/datum/atom_skin/collar_tagged/thick_cross
	preview_name = "Cross (Thick)"
	new_icon_state = "thick_cross_collar"
	new_name = "cross collar"

/datum/atom_skin/collar_tagged/thick_holo
	preview_name = "Holographic (Thick)"
	new_icon_state = "thick_holocollar"
	new_name = "holocollar"

/datum/atom_skin/collar_tagged/thick_tag
	preview_name = "Tagged (Thick)"
	new_icon_state = "thick_tagged_collar"

/obj/item/clothing/neck/collar/tagged
	name = "tagged collar"
	desc = "A collar, fit with a locking buckle and adorned with an ornament."
	icon = 'icons/map_icons/clothing/neck.dmi'
	icon_state = "/obj/item/clothing/neck/collar/tagged"
	post_init_icon_state = "thin_tagged_collar"
	greyscale_config = /datum/greyscale_config/tagged_collar
	greyscale_config_worn = /datum/greyscale_config/tagged_collar/worn
	greyscale_colors = "#2d2d33#dead39"

/obj/item/clothing/neck/collar/tagged/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/collar_tagged, initial_skin = "Tagged (Thin)")
