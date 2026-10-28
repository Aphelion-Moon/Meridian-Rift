#define TESHARI_PUNCH_LOW 2 // Lower bound punch damage
#define TESHARI_PUNCH_HIGH 6
#define TESHARI_BURN_MODIFIER 1.25 // They take more damage from practically everything
#define TESHARI_BRUTE_MODIFIER 1.2

// teshari!
/obj/item/bodypart/head/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	is_dimorphic = FALSE
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	head_flags = HEAD_EYESPRITES|HEAD_EYECOLOR|HEAD_EYEHOLES|HEAD_DEBRAIN|HEAD_HAIR
	eyes_icon = 'modular_nova/modules/organs/icons/teshari_eyes.dmi'
	worn_offsets_species = /datum/species/teshari


/obj/item/bodypart/chest/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	is_dimorphic = FALSE
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	bodypart_traits = list(TRAIT_NO_UNDERWEAR)
	worn_offsets_species = /datum/species/teshari

/obj/item/bodypart/arm/left/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	unarmed_damage_low = TESHARI_PUNCH_LOW
	unarmed_damage_high = TESHARI_PUNCH_HIGH
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	worn_offsets_species = /datum/species/teshari


/obj/item/bodypart/arm/right/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	unarmed_damage_low = TESHARI_PUNCH_LOW
	unarmed_damage_high = TESHARI_PUNCH_HIGH
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	worn_offsets_species = /datum/species/teshari


/obj/item/bodypart/leg/left/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/teshari
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/leg/right/mutant/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/teshari
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER

/obj/item/bodypart/leg/left/digitigrade/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	speed_modifier = -0.1

/obj/item/bodypart/leg/right/digitigrade/teshari
	icon_greyscale = BODYPART_ICON_TESHARI
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	limb_id = SPECIES_TESHARI
	brute_modifier = TESHARI_BRUTE_MODIFIER
	burn_modifier = TESHARI_BURN_MODIFIER
	speed_modifier = -0.1

/// Teshari limbs sit lower and narrower than a human's, and so do the raptoral prosthetics drawn in their shape
/// An offset the same whichever way they face is one entry, which turning leaves alone
/datum/species/teshari/add_worn_offsets(obj/item/bodypart/limb)
	switch(limb.body_zone)
		if(BODY_ZONE_HEAD)
			var/obj/item/bodypart/head/head = limb
			head.worn_ears_offset = new /datum/worn_feature_offset(
				attached_part = head,
				feature_key = OFFSET_EARS,
				offset_y = list("south" = -4),
			)
			head.worn_head_offset = new /datum/worn_feature_offset(
				attached_part = head,
				feature_key = OFFSET_HEAD,
				offset_x = list("north" = 1, "south" = 1, "east" = 1, "west" = -1, "northwest" = -1, "southwest" = -1, "northeast" = 1, "southeast" = 1),
				offset_y = list("north" = -4, "south" = -4, "east" = -4, "west" = -4),
			)
			head.worn_mask_offset = new /datum/worn_feature_offset(
				attached_part = head,
				feature_key = OFFSET_FACEMASK,
				offset_y = list("south" = -5),
			)
		if(BODY_ZONE_CHEST)
			var/obj/item/bodypart/chest/chest = limb
			chest.worn_back_offset = new /datum/worn_feature_offset(
				attached_part = chest,
				feature_key = OFFSET_BACK,
				offset_y = list("south" = -4),
			)
			chest.worn_accessory_offset = new /datum/worn_feature_offset(
				attached_part = chest,
				feature_key = OFFSET_ACCESSORY,
				offset_y = list("south" = -4),
			)
		if(BODY_ZONE_L_ARM)
			var/obj/item/bodypart/arm/left_arm = limb
			left_arm.held_hand_offset = new /datum/worn_feature_offset(
				attached_part = left_arm,
				feature_key = OFFSET_HELD,
				offset_x = list("north" = 0, "south" = 0, "east" = 0, "west" = -6, "northwest" = -6, "southwest" = -6, "northeast" = 0, "southeast" = 0),
				offset_y = list("north" = -3, "south" = -3, "east" = -3, "west" = -3),
			)
		if(BODY_ZONE_R_ARM)
			var/obj/item/bodypart/arm/right_arm = limb
			right_arm.held_hand_offset = new /datum/worn_feature_offset(
				attached_part = right_arm,
				feature_key = OFFSET_HELD,
				offset_x = list("north" = 0, "south" = 0, "east" = 6, "west" = 0, "northwest" = 0, "southwest" = 0, "northeast" = 6, "southeast" = 6),
				offset_y = list("north" = -3, "south" = -3, "east" = -3, "west" = -3),
			)

#undef TESHARI_PUNCH_LOW
#undef TESHARI_PUNCH_HIGH
#undef TESHARI_BURN_MODIFIER
#undef TESHARI_BRUTE_MODIFIER
