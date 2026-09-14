// voxs!
/obj/item/bodypart/head/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX
	eyes_icon = 'modular_nova/modules/organs/icons/vox_eyes.dmi'
	teeth_count = 72

/// Position fallback human hats and glasses on the Vox head.
/obj/item/bodypart/head/mutant/vox/Initialize(mapload)
	worn_head_offset = new(
		attached_part = src,
		feature_key = OFFSET_HEAD,
		offset_x = list("north" = 0, "south" = 0, "east" = 3, "west" = -3),
	)
	worn_glasses_offset = new(
		attached_part = src,
		feature_key = OFFSET_GLASSES,
		offset_x = list("north" = 0, "south" = 0, "east" = 3, "west" = -3),
		offset_y = list("north" = 0, "south" = -1, "east" = -1, "west" = -1),
	)
	return ..()

/obj/item/bodypart/chest/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX

/obj/item/bodypart/arm/left/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX

/obj/item/bodypart/arm/right/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX

/obj/item/bodypart/leg/left/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX
	digitigrade_type = /obj/item/bodypart/leg/left/digitigrade/vox

/obj/item/bodypart/leg/right/mutant/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX
	digitigrade_type = /obj/item/bodypart/leg/right/digitigrade/vox

/obj/item/bodypart/leg/left/digitigrade/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX

/obj/item/bodypart/leg/right/digitigrade/vox
	icon_greyscale = BODYPART_ICON_VOX
	bodyshape = parent_type::bodyshape | BODYSHAPE_SNOUTED | BODYSHAPE_CUSTOM
	limb_id = SPECIES_VOX
