
// Supported TG Masks
/obj/item/clothing/mask/bandana
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION
	greyscale_config_worn_muzzled = /datum/greyscale_config/bandana/worn/muzzled
	greyscale_config_worn_vox = /datum/greyscale_config/bandana/worn/vox
	greyscale_config_worn_better_vox = /datum/greyscale_config/bandana/worn/better_vox

/obj/item/clothing/mask/bandana/striped
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION
	greyscale_config_worn_muzzled = /datum/greyscale_config/bandana/striped/worn/muzzled
	greyscale_config_worn_vox = /datum/greyscale_config/bandana/striped/worn/vox
	greyscale_config_worn_better_vox = /datum/greyscale_config/bandana/striped/worn/better_vox

/obj/item/clothing/mask/bandana/skull
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION
	greyscale_config_worn_muzzled = /datum/greyscale_config/bandana/skull/worn/muzzled
	greyscale_config_worn_vox = /datum/greyscale_config/bandana/skull/worn/vox
	greyscale_config_worn_better_vox = /datum/greyscale_config/bandana/skull/worn/better_vox

/obj/item/clothing/mask/facescarf
	greyscale_config_worn_better_vox = /datum/greyscale_config/facescarf/worn/better_vox

/obj/item/clothing/mask/muzzle/tape
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION
	greyscale_config_worn_muzzled = /datum/greyscale_config/tape_piece/worn/muzzled
	greyscale_config_worn_vox = /datum/greyscale_config/tape_piece/worn/vox

/obj/item/clothing/mask/muzzle/tape/pointy
	greyscale_config_worn_muzzled = /datum/greyscale_config/tape_piece/worn/spikes/muzzled
	greyscale_config_worn_vox = /datum/greyscale_config/tape_piece/worn/spikes/vox

/obj/item/clothing/mask/cigarette
	supports_variations_flags = NONE

/obj/item/vape
	worn_icon_vox = 'modular_nova/master_files/icons/mob/clothing/species/vox/mask.dmi'
	supports_variations_flags = NONE
	greyscale_config_worn_vox = /datum/greyscale_config/vape/worn/vox

// Modular masks

/obj/item/clothing/mask/breath/vox
	desc = "A close-fitting mask that can be connected to an air supply. This one's got an easily accessible feeding port to be more suitable for the Vox crewmembers."
	name = "vox breath mask"
	actions_types = list()
	flags_cover = NONE

/obj/item/clothing/mask/balaclava/adjustable
	name = "adjustable balaclava"
	desc = "Wider eyed and made of an elastic based material, this one seems like it can contort more."
	icon = 'modular_nova/master_files/icons/obj/clothing/masks.dmi'
	worn_icon = 'modular_nova/master_files/icons/mob/clothing/mask.dmi'
	icon_state = "balaclava_adj"
	actions_types = list(/datum/action/item_action/adjust_style)
	var/list/balaclava_adjustment = list()

/obj/item/clothing/mask/balaclava/adjustable/Initialize(mapload)
	. = ..()
	balaclava_adjustment = list(
		"Balaclava" = image(icon = src.icon, icon_state = "balaclava_adj"),
		"Open Face" = image(icon = src.icon, icon_state = "balaclava_adj_open"),
		"Neck Gaiter" = image(icon = src.icon, icon_state = "balaclava_adj_mouth"),
		"Beanie" = image(icon = src.icon, icon_state = "balaclava_adj_up")
		)

/obj/item/clothing/mask/balaclava/adjustable/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		return
	. += span_notice("[EXAMINE_HINT("Alt-click")] to adjust how it's worn.")

/obj/item/clothing/mask/balaclava/adjustable/ui_action_click(mob/user)
	if(!istype(user) || user.incapacitated)
		return

	var/list/options = list()
	options["Balaclava"] = "balaclava_adj"
	options["Open Face"] = "balaclava_adj_open"
	options["Neck Gaiter"] = "balaclava_adj_mouth"
	options["Beanie"] = "balaclava_adj_up"

	var/choice = show_radial_menu(user, src, balaclava_adjustment, custom_check = FALSE, radius = 36, require_near = TRUE)
	if(!choice)
		return FALSE

	if(src && choice && !user.incapacitated && in_range(user, src) && user.can_perform_action(src, interaction_flags_click | SILENT_ADJACENCY))
		icon_state = options[choice]
		switch(choice)
			if("Balaclava")
				flags_inv = HIDEFACE|HIDEFACIALHAIR|HIDEHAIR|HIDESNOUT|SHOWSPRITEEARS
				to_chat(user, span_notice("You pull the balaclava down to cover your whole face."))
			if("Open Face")
				flags_inv = HIDEHAIR|SHOWSPRITEEARS
				to_chat(user, span_notice("You pull the balaclava down to reveal your face."))
			if("Neck Gaiter")
				flags_inv = HIDEFACE|HIDEFACIALHAIR|HIDESNOUT
				to_chat(user, span_notice("You pull the balaclava over to only cover your mouth."))
				alternate_worn_layer = BENEATH_HAIR_LAYER //prevents the neck-height sprite from going through long hair
			if("Beanie")
				flags_inv = HIDEHAIR|SHOWSPRITEEARS
				to_chat(user, span_notice("You roll the balaclava up to wear as a beanie."))
		if(choice != "Neck Gaiter") //make sure that it goes back to the intended layer if it's not in neck gaiter
			alternate_worn_layer = LOW_FACEMASK_LAYER
		user.update_clothing(ITEM_SLOT_MASK)
		user.refresh_obscured()
		return TRUE

/obj/item/clothing/mask/balaclava/adjustable/click_alt(mob/user)
	return ui_action_click(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/obj/item/clothing/mask/balaclava/adjustable/attack_self(mob/user)
	return //prevents following the parent's use and getting bugged while set to beanie

/obj/item/clothing/mask/balaclava/threehole
	name = "three hole balaclava"
	icon = 'modular_nova/master_files/icons/obj/clothing/masks.dmi'
	worn_icon = 'modular_nova/master_files/icons/mob/clothing/mask.dmi'
	icon_state = "balaclavam"
	inhand_icon_state = "balaclava"
	flags_inv = HIDEFACE|HIDEHAIR|HIDEFACIALHAIR
	visor_flags_inv = HIDEFACE|HIDEFACIALHAIR

/obj/item/clothing/mask/balaclava/threehole/green
	name = "three hole green balaclava"
	icon = 'modular_nova/master_files/icons/obj/clothing/masks.dmi'
	worn_icon = 'modular_nova/master_files/icons/mob/clothing/mask.dmi'
	icon_state = "swatclavam"
	inhand_icon_state = "balaclava"

/obj/item/clothing/mask/surgical/greyscale
	worn_icon = 'modular_nova/modules/GAGS/icons/masks.dmi'
	flags_1 = IS_PLAYER_COLORABLE_1
	greyscale_colors = "#AAE4DB"
	icon = 'icons/map_icons/clothing/mask.dmi'
	icon_state = "/obj/item/clothing/mask/surgical/greyscale"
	post_init_icon_state = "sterile"
	greyscale_config = /datum/greyscale_config/sterile_mask
	greyscale_config_worn = /datum/greyscale_config/sterile_mask/worn
	greyscale_config_worn_muzzled = /datum/greyscale_config/sterile_mask/worn/snouted
	greyscale_config_worn_better_vox = /datum/greyscale_config/sterile_mask/worn/better_vox
	greyscale_config_worn_vox = /datum/greyscale_config/sterile_mask/worn/vox
	greyscale_config_worn_teshari = /datum/greyscale_config/sterile_mask/worn/teshari
