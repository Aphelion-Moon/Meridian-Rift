/**
 * NO NEW ICON
 * Clothing that do not require a new icon to function correctly, think, big jackets.
 */
/obj/item/clothing/shoes/changeling
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON

// TODO: These need sprites
/obj/item/clothing/shoes/singerr
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON

/obj/item/clothing/shoes/cowboy/lizard
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON

/obj/item/clothing/shoes/bhop
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON

/**
 * SUBTYPE WITH NEW ICON
 * Clothing that has a digitigrade version, but its parent was set to something else earlier in this file or elsewhere entirely.
 */
/obj/item/clothing/shoes/combat
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/jackboots
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/workboots
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/russian
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/winterboots
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/sneakers
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/obj/item/clothing/shoes/sneakers/orange
	greyscale_config_worn_digi = /datum/greyscale_config/sneakers_orange/worn/digi

// Undisguised it looks like a pair of sneakers
/obj/item/clothing/shoes/chameleon
	greyscale_config_worn_digi = /datum/greyscale_config/sneakers/worn/digi
	greyscale_config_worn_vox = /datum/greyscale_config/sneakers/worn/vox
	greyscale_config_worn_teshari = /datum/greyscale_config/sneakers/worn/teshari
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
	bodyshapes_with_variations = NONE

/**
 * These already have digi art drawn for them.
 */
/obj/item/clothing/shoes/jackboots/floortile
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/shoes/bhop/rocket
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION

/obj/item/clothing/shoes/bhop/rocket/jet
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION
