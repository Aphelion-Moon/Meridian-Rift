/obj/item/bodypart
	/// The /datum/body_marking_entry list this limb draws on its body zone, or null for none. Normally the owner DNA
	/// collection's own list for that zone, shared with it and read-only: replace it by assigning another list, never
	/// edit it. A detached limb goes on drawing the list it last got.
	var/list/markings
	/// The same for its aux zone (hands).
	var/list/aux_zone_markings
	/// The alpha our markings are drawn at. A creating update_limb() sets it from the owner's species.
	var/markings_alpha = 255
	/// What is our normal limb ID? used for squashing legs.

/obj/item/bodypart/leg
	/// This is used in digitigrade legs, when this leg is swapped out with the digitigrade version.
	var/obj/item/bodypart/leg/digitigrade_type

/obj/item/bodypart/leg/right
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade

/obj/item/bodypart/leg/left
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade

/obj/item/bodypart/leg/left/stump
	digitigrade_type = null

/obj/item/bodypart/leg/right/stump
	digitigrade_type = null

// Just blanket apply the footstep pref on limb addition, it gets far too complicated otherwise as limbs are getting replaced more often than you'd think
/obj/item/bodypart/leg/on_adding(mob/living/carbon/new_owner)
	. = ..()
	var/mob/living/carbon/human/human_owner = new_owner
	if(istype(human_owner) && human_owner.footstep_type)
		if(islist(human_owner.footstep_type))
			special_footstep_sounds = human_owner.footstep_type
		else
			footstep_type = human_owner.footstep_type

/// General mutant bodyparts. Used in most mutant species.
/obj/item/bodypart/head/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL

/obj/item/bodypart/chest/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL
	is_dimorphic = TRUE

/obj/item/bodypart/arm/left/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL
	unarmed_attack_verbs = list("slash")
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slash.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'


/obj/item/bodypart/arm/right/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL
	unarmed_attack_verbs = list("slash")
	unarmed_attack_effect = ATTACK_EFFECT_CLAW
	unarmed_attack_sound = 'sound/items/weapons/slash.ogg'
	unarmed_miss_sound = 'sound/items/weapons/slashmiss.ogg'


/obj/item/bodypart/leg/left/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL

/obj/item/bodypart/leg/right/mutant
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL

/obj/item/bodypart/leg/left/digitigrade
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL
	bodyshape = parent_type::bodyshape | BODYSHAPE_DIGITIGRADE

/obj/item/bodypart/leg/right/digitigrade
	icon_greyscale = BODYPART_ICON_MAMMAL
	limb_id = SPECIES_MAMMAL
	bodyshape = parent_type::bodyshape | BODYSHAPE_DIGITIGRADE
