//This one's a weird outlier so isn't a reskin
/obj/item/clothing/neck/collar/leather
	name = "leather collar"
	desc = "A firm collar made of leather; fit with a locking clasp. There's a little metallic ring on the front."
	greyscale_colors = "#2d2d33#9b111e"
	icon = 'icons/map_icons/clothing/neck.dmi'
	icon_state = "/obj/item/clothing/neck/collar/leather"
	post_init_icon_state = "leather_collar"
	greyscale_config = /datum/greyscale_config/leather_collar
	greyscale_config_worn = /datum/greyscale_config/leather_collar/worn

/obj/item/clothing/neck/collar/leather/setup_reskins()
	return //No reskins on this one

//Reskins for the tagged leather collar
/datum/atom_skin/collar/leather
	abstract_type = /datum/atom_skin/collar/leather
	greyscale_item_path = /obj/item/clothing/neck/collar/leather/tagged

//Alphabetically sorted; the initial selection is Tagged
/datum/atom_skin/collar/leather/bell
	preview_name = "Bell"
	new_icon_state = "leather_bell_collar"
	jingles = TRUE

/datum/atom_skin/collar/leather/cowbell
	preview_name = "Cowbell"
	new_icon_state = "leather_cowbell_collar"
	jingles = TRUE

/datum/atom_skin/collar/leather/cross
	preview_name = "Cross"
	new_icon_state = "leather_cross_collar"

/datum/atom_skin/collar/leather/holo
	preview_name = "Holographic"
	new_icon_state = "leather_holocollar"

/datum/atom_skin/collar/leather/tag
	preview_name = "Tagged"
	new_icon_state = "leather_tagged_collar"

/obj/item/clothing/neck/collar/leather/tagged
	name = "tagged leather collar"
	desc = "A firm collar made of leather; fit with a locking clasp. There's something hanging off the front."
	icon = 'icons/map_icons/clothing/neck.dmi'
	icon_state = "/obj/item/clothing/neck/collar/leather/tagged"
	post_init_icon_state = "leather_tagged_collar"
	greyscale_config = /datum/greyscale_config/leather_tagged_collar
	greyscale_config_worn = /datum/greyscale_config/leather_tagged_collar/worn
	greyscale_colors = "#2d2d33#9b111e#dead39"

/obj/item/clothing/neck/collar/leather/tagged/setup_reskins()
	AddComponent(/datum/component/reskinable_item, /datum/atom_skin/collar/leather, initial_skin = "Tagged")
