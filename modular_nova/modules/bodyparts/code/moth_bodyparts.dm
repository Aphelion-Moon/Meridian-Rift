// Greyscale, recolourable sprites over tg's moth parts
/obj/item/bodypart/head/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	icon_state = "moth_head_m"
	should_draw_greyscale = TRUE
	is_dimorphic = TRUE
	head_flags = HEAD_DEFAULT_FEATURES

/obj/item/bodypart/chest/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	should_draw_greyscale = TRUE

/**
 * Grows or sheds the extra pair of arms of a chest already attached, as its owner's DNA now asks.
 * A chest attaching asks the DNA itself, in try_attach_limb(), so this is for the extra arms preference changing a body.
 */
/obj/item/bodypart/chest/moth/proc/update_extra_arms()
	if(!owner)
		return
	if(owner.dna.features[FEATURE_MOTH_TWO_ARMS])
		if(isnull(left_inner.owner)) // already shed
			return
		left_inner.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
		right_inner.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
		owner.change_number_of_hands(2)
	else
		if(left_inner.owner) // already grown
			return
		owner.change_number_of_hands(4)
		left_inner.try_attach_limb(owner, special = TRUE)
		right_inner.try_attach_limb(owner, special = TRUE)
	owner.update_body_parts()

/obj/item/bodypart/arm/left/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	should_draw_greyscale = TRUE

/obj/item/bodypart/arm/right/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	should_draw_greyscale = TRUE

/obj/item/bodypart/leg/left/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	should_draw_greyscale = TRUE

/obj/item/bodypart/leg/right/moth
	icon = BODYPART_ICON_MOTH
	icon_greyscale = BODYPART_ICON_MOTH
	should_draw_greyscale = TRUE

// The chest arms in the body's greys, tinted with the chest's colour
/datum/bodypart_overlay/simple/moth_arms
	icon = 'modular_nova/modules/bodyparts/icons/moth_arms_greyscale.dmi'

/datum/bodypart_overlay/simple/moth_arms/color_image(image/overlay, obj/item/bodypart/limb, layer_index)
	overlay.color = limb.draw_color

// A moth without the extra arms keeps them inside its chest, out of sight
/datum/bodypart_overlay/simple/moth_arms/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	return ..() && !owner?.dna.features[FEATURE_MOTH_TWO_ARMS]
