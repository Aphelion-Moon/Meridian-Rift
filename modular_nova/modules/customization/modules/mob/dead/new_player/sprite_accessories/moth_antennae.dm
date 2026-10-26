/datum/sprite_accessory/moth_antennae
	icon = 'modular_nova/master_files/icons/mob/sprite_accessory/moth_antennae.dmi'
	key = FEATURE_MOTH_ANTENNAE
	organ_type = /obj/item/organ/antennae
	mod_icon_slots = ITEM_SLOT_HEAD

/datum/sprite_accessory/moth_antennae/is_hidden(mob/living/carbon/human/wearer, datum/bodypart_overlay/mutant/bodypart_overlay)
	var/obj/item/clothing/head/mod/worn_head = wearer.head
	if(worn_head)
		// Can hide if wearing hat
		if(wearer.try_hide_mutant_parts?[key])
			return TRUE
		// Exception for MODs. Otherwise hide if flagged to, unless the head has earholes and so does the mask, if one is worn:
		// items with earholes like Balaclavas and Luchador masks FORCE accessory-ears to show.
		if(!istype(worn_head))
			var/head_flags = worn_head.flags_inv
			var/obj/item/clothing/mask/worn_mask = wearer.wear_mask
			if(((head_flags | worn_mask?.flags_inv) & HIDEHAIR) && (!(head_flags & SHOWSPRITEEARS) || (worn_mask && !(worn_mask.flags_inv & SHOWSPRITEEARS))))
				return TRUE
	return LEWD_ITEM_HIDES_PARTS(wearer, TRUE, TRUE)

/datum/sprite_accessory/moth_antennae/none
	name = SPRITE_ACCESSORY_NONE
	icon_state = "none"
	factual = FALSE
	natural_spawn = FALSE
