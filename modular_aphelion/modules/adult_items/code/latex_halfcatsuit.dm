/// Nova's latex catsuit with the legs cut off. Its sibling, not its subtype - a subtype would bulge as long johns, hide
/// its wearer's ears, horns and wings (LEWD_ITEM_HIDES_PARTS) and hide a taur's body (HIDETAUR).
/obj/item/clothing/under/misc/latex_halfcatsuit
	name = "latex half-catsuit"
	desc = "A shiny uniform that fits snugly to the skin. The legs have been cut off this one."
	icon = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit.dmi'
	icon_state = "latex_halfcatsuit_female"
	worn_icon = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit_worn.dmi'
	worn_icon_digi = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit_worn_digi.dmi'
	worn_icon_vox = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit_worn_vox.dmi'
	worn_icon_better_vox = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit_worn_better_vox.dmi'
	worn_icon_teshari = 'modular_aphelion/modules/adult_items/icons/latex_halfcatsuit_worn_teshari.dmi'
	inhand_icon_state = "latex_catsuit"
	lefthand_file = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_inhands/lewd_inhand_left.dmi'
	righthand_file = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_inhands/lewd_inhand_right.dmi'
	equip_sound = 'modular_nova/modules/modular_items/lewd_items/sounds/latex.ogg'
	body_parts_covered = CHEST|GROIN|ARMS
	can_adjust = FALSE
	strip_delay = 1 SECONDS
	// The full female mask would cut off the tip of the V.
	female_sprite_flags = FEMALE_UNIFORM_TOP_ONLY
	// Nova's uniform default less CLOTHING_BIG_LEGS_MASK, which would draw jumpsuit legs on a big-legged taur.
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION | CLOTHING_CERULEAN_MASK_LEGS

/// Takes six seconds to peel off yourself, as the catsuit does.
/obj/item/clothing/under/misc/latex_halfcatsuit/attack_hand(mob/user, list/modifiers)
	if(user.get_item_by_slot(ITEM_SLOT_ICLOTHING) == src && !do_after(user, 6 SECONDS, target = src))
		return
	return ..()

/// Takes the sprite of the body under it - female where the chest is drawn female (body type) - in visual_equipped(),
/// which preview dummies get, not equipped().
/obj/item/clothing/under/misc/latex_halfcatsuit/visual_equipped(mob/living/carbon/human/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_ICLOTHING))
		return
	var/obj/item/bodypart/chest/chest = user.get_bodypart(BODY_ZONE_CHEST)
	var/body_state = "latex_halfcatsuit_[user.physique == FEMALE && chest?.is_dimorphic ? "female" : "male"]"
	if(icon_state != body_state)
		icon_state = body_state
		user.update_worn_undersuit()

/// The Vox halves are fitted to their bodies, as the catsuit's are (vox_clothing.dm) - no female mask.
/obj/item/clothing/under/misc/latex_halfcatsuit/build_worn_icon(default_layer = 0, default_icon_file, isinhands = FALSE, female_uniform = NO_FEMALE_UNIFORM, override_state, override_file, bodyshape = NONE)
	if(override_file == worn_icon_vox || override_file == worn_icon_better_vox)
		female_uniform = NO_FEMALE_UNIFORM
	return ..(default_layer, default_icon_file, isinhands, female_uniform, override_state, override_file, bodyshape)

/// The Vox halves' latex hand covers, as the catsuit's (vox_clothing.dm) - a sibling of the suit, so they can cover the
/// hands, and below gloves.
/obj/item/clothing/under/misc/latex_halfcatsuit/get_worn_undersuit_appearances(mob/living/carbon/human/wearer, mutable_appearance/uniform_overlay, icon_file)
	if(icon_file != worn_icon_vox && icon_file != worn_icon_better_vox)
		return ..()
	var/mutable_appearance/hands = mutable_appearance(icon_file, "[icon_state]_hands", -(GLOVES_LAYER + BODYPARTS_HIGH_LAYER) / 2)
	hands.alpha = alpha
	hands = color_atom_overlay(hands)
	wearer.apply_height(hands, ENTIRE_BODY)
	var/obj/item/bodypart/chest/chest = wearer.get_bodypart(BODY_ZONE_CHEST)
	chest?.worn_uniform_offset?.apply_offset(hands)
	return list(uniform_overlay, hands)
