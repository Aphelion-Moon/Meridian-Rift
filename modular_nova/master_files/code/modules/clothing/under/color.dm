/obj/item/clothing/under/color/rainbow
	// Species lookup must select the rainbow artwork rather than generic jumpsuit legs.
	worn_icon_state = "rainbow"
	worn_icon_digi = 'modular_nova/master_files/icons/mob/clothing/under/color_digi.dmi'
	greyscale_config_worn_digi = null
	greyscale_config_worn_vox = null
	greyscale_config_worn_better_vox = null
	greyscale_config_worn_teshari = null
	worn_icon_vox = 'modular_nova/master_files/icons/mob/clothing/species/vox/uniform.dmi'
	worn_icon_better_vox = 'modular_nova/modules/better_vox/icons/clothing/uniform.dmi'

/**
 * Random jumpsuit is the preferred style of the wearer if loaded as an outfit.
 * This is cleaner than creating a ../skirt variant as skirts are precached into SSwardrobe
 * and that causes runtimes for runtimes for this class as it qdels on Initialize.
 */
/obj/item/clothing/under/color/random/proc/get_random_variant()
	var/mob/living/carbon/human/wearer = loc
	if(istype(wearer) && wearer.jumpsuit_style == PREF_SKIRT)
		return get_random_jumpskirt()

	return get_random_jumpsuit()
