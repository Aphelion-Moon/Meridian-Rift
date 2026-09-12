// voxs!
/obj/item/bodypart/head/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_head"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	is_dimorphic = FALSE
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS
	eyes_icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_eyes.dmi'
	teeth_count = 72

/// Masks without a Primalis sprite fall back to human art, which sits where a flat human face would be. Nudge it onto the beak.
/obj/item/bodypart/head/mutant/vox_primalis/Initialize(mapload)
	worn_mask_offset = new(
		attached_part = src,
		feature_key = OFFSET_FACEMASK,
		offset_x = list("north" = 0, "south" = 0, "east" = 5, "west" = -5),
		offset_y = list("north" = 0, "south" = 0, "east" = 1, "west" = 0),
	)
	return ..()

/obj/item/bodypart/chest/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_chest"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	is_dimorphic = FALSE
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS

/obj/item/bodypart/arm/left/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_l_arm"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS

/obj/item/bodypart/arm/right/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_r_arm"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS

/obj/item/bodypart/leg/left/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_l_leg"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS

/obj/item/bodypart/leg/right/mutant/vox_primalis
	icon_static = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_greyscale = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon = 'modular_nova/modules/better_vox/icons/bodyparts/vox_bodyparts.dmi'
	icon_state = "vox_primalis_r_leg"
	bodyshape = parent_type::bodyshape | BODYSHAPE_CUSTOM
	should_draw_greyscale = FALSE
	limb_id = SPECIES_VOX_PRIMALIS

