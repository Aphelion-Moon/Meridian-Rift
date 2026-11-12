// Adapted from Shiptest PR #6985 by Erikafox and Imaginos
// See ../readme.md for the source and credits
/obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan
	parent_type = /obj/item/clothing/suit/toggle
	name = "heavy trenchcoat"
	desc = "A heavy coat made from durable fabrics."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon_digi = 'modular_aphelion/modules/shiptest_clothing/icons/digi.dmi'
	icon_state = "trenchcoat_tan"
	inhand_icon_state = "brownjsuit"
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	cold_protection = CHEST|GROIN|LEGS|ARMS
	heat_protection = CHEST|GROIN|LEGS|ARMS
	min_cold_protection_temperature = FIRE_SUIT_MIN_TEMP_PROTECT
	bodyshapes_with_variations = NONE
	blood_overlay_type = "coat"

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan/Initialize(mapload)
	. = ..()
	create_storage(storage_type = /datum/storage/pockets/shiptest_trenchcoat)

// Alt-click buttons the coat, so we open the pockets by dragging the coat onto yourself and fill them by dragging
// an item onto it
/datum/storage/pockets/shiptest_trenchcoat
	max_slots = 3
	click_alt_open = FALSE
	attack_hand_interact = FALSE
	do_rustle = TRUE

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/navy
	parent_type = /obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan
	name = "heavy navy trenchcoat"
	desc = "A hard-boiled private investigator's grey trenchcoat."
	icon_state = "trenchcoat_navy"
	inhand_icon_state = "bl_suit"
	// We hold tg's black suit as tg draws it, not the tan coat's coloured one
	greyscale_config_inhand_left = null
	greyscale_config_inhand_right = null

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/fur_collared_black
	parent_type = /obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan
	name = "fur-collared black trenchcoat"
	desc = "A heavy black trenchcoat with a plush collar and red iconography across the back."
	icon_state = "trenchcoat_fur_collared_black"
	inhand_icon_state = "bl_suit"
	greyscale_config_inhand_left = null
	greyscale_config_inhand_right = null

/obj/item/clothing/suit/shiptest/toggle/trenchcoat/deaf_mute
	parent_type = /obj/item/clothing/suit/shiptest/toggle/trenchcoat/tan
	name = "\improper deaf/mute trenchcoat"
	desc = "A dark trenchcoat emblazoned with a roundel on the backside. \"I thought what I'd do was, I'd pretend I was one of those deaf-mutes.\""
	icon_state = "trenchcoat_deaf_mute"
	inhand_icon_state = "bl_suit"
	greyscale_config_inhand_left = null
	greyscale_config_inhand_right = null

/obj/item/clothing/suit/shiptest/toggle/capsule_jacket
	parent_type = /obj/item/clothing/suit/toggle
	name = "capsule jacket"
	desc = "A poorly made jacket with a pill capsule resting on the backside. Good for your health, but not good for your education. Take only as prescribed."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "capsule_jacket"
	inhand_icon_state = "r_suit"
	body_parts_covered = CHEST|ARMS
	cold_protection = CHEST|ARMS
	bodyshapes_with_variations = NONE
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON
