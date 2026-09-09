/*
 * /obj/item/clothing/mask defaults to:
 * supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
 */

/**
 * NO NEW ICON
 * Clothing that do not require a new icon to function correctly.
 * Masks that don't actually cover the snout, or large masks that already cover it by default
 */

/obj/item/clothing/mask/fakemoustache
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
	flags_inv = NONE //Moustache no longer marks you as Unknown

/obj/item/clothing/mask/gas/tiki_mask
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/changeling
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/knife
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/food/grown/wheat
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/kitsune
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/**
 * NONE(Squash)
 * Clothing that does not have species or snout variation, and doesn't quite cover the snout either.
 * Instead, it will 'squash' the face, hiding the snout.
 */

/obj/item/clothing/mask/gas/monkeymask
	supports_variations_flags = NONE

/obj/item/clothing/mask/gondola
	supports_variations_flags = NONE

/obj/item/clothing/mask/gas/owl_mask
	supports_variations_flags = NONE

/obj/item/clothing/mask/gas/carp
	supports_variations_flags = NONE

/obj/item/clothing/mask/animal
	supports_variations_flags = NONE

/obj/item/clothing/head/bio_hood/plague
	supports_variations_flags = NONE

/obj/item/clothing/mask/scarecrow
	supports_variations_flags = NONE

/**
 * INVENTORY/VISOR FLAGS
 * While not strictly a variation override, this applies to showing mutant ears or snouts.
 */

/obj/item/clothing/mask/gas
	//All gas masks show ears
	visor_flags_inv = HIDEFACE|HIDEFACIALHAIR|HIDESNOUT
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/explorer // HIDESNOUT is in visor toggle now
	visor_flags_inv = HIDEFACIALHAIR|HIDESNOUT

/obj/item/clothing/mask/luchador // No longer has HIDESNOUT, has SHOWSPRITEEARS
	flags_inv = HIDEFACE|HIDEHAIR|HIDEFACIALHAIR|SHOWSPRITEEARS

/obj/item/clothing/mask/balaclava // Now has SHOWSPRITEEARS
	flags_inv = HIDEFACE|HIDEHAIR|HIDEFACIALHAIR|HIDESNOUT|SHOWSPRITEEARS

/**
 * TYPES WITH A SNOUTED VARIATION
 */
/obj/item/clothing/mask/balaclava
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/breath
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/chameleon
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/facehugger
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/facescarf
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/floortilebalaclava
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/atmos
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/atmosprop
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/clown_hat
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/cyborg
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/driscoll
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/explorer
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/hunter
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/mime
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/ninja
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/prop
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/sechailer
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/sexyclown
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/sexymime
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/syndicate
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/gas/welding
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/joy
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/luchador
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/madness_mask
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/mummy
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/muzzle
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/nobreath
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/rebellion
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/russian_balaclava
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/obj/item/clothing/mask/surgical
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION

/**
 * NO NEW ICON
 */
/obj/item/clothing/mask/gas/jonkler
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/gas/plaguedoctor
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/gas/sechailer/cyborg
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/gas/syndicate/cybersun
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION_NO_NEW_ICON
