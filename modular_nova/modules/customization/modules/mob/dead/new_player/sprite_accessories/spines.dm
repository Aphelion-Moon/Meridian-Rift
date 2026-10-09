/datum/sprite_accessory/spines
	key = FEATURE_SPINES
	default_color = DEFAULT_SECONDARY
	recommended_species = list(
		SPECIES_LIZARD = 1,
		SPECIES_UNATHI = 1,
		SPECIES_LIZARD_ASH = 1,
		SPECIES_LIZARD_SILVER = 1,
	)
	organ_type = /obj/item/organ/spines
	mod_icon_slots = ITEM_SLOT_OCLOTHING|ITEM_SLOT_HEAD

/datum/sprite_accessory/spines/none
	name = SPRITE_ACCESSORY_NONE
	icon_state = "none"

/datum/sprite_accessory/spines/is_hidden(mob/living/carbon/human/wearer, datum/bodypart_overlay/mutant/bodypart_overlay)
	return ((wearer.w_uniform?.flags_inv | wearer.wear_suit?.flags_inv) & HIDESPINE) || wearer.try_hide_mutant_parts?[key]

/datum/sprite_accessory/tail_spines
	key = FEATURE_TAILSPINES
	default_color = DEFAULT_SECONDARY

/datum/sprite_accessory/tail_spines/none
	name = SPRITE_ACCESSORY_NONE
	icon_state = "none"
	factual = FALSE
	natural_spawn = FALSE

/datum/sprite_accessory/tail_spines/is_hidden(mob/living/carbon/human/wearer, datum/bodypart_overlay/mutant/bodypart_overlay)
	// Emote exception
	if(wearer.owned_turf?.name == "tail")
		return TRUE
	var/obj/item/clothing/suit/mod/worn_suit = wearer.wear_suit
	if(!worn_suit && !wearer.w_uniform)
		return FALSE
	var/list/hidden_parts = wearer.try_hide_mutant_parts
	if(hidden_parts?["spines"] || hidden_parts?["tail"])
		return TRUE
	// Hide accessory if flagged to do so, with an exception for MODs
	return worn_suit && !istype(worn_suit) && (worn_suit.flags_inv & HIDETAIL)
