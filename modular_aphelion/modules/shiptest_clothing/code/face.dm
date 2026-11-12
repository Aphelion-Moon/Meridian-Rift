// Shiptest eyewear, masks, ear and foot wear, all cosmetic - none of it gives a HUD, armour or internals

/obj/item/clothing/ears/shiptest
	abstract_type = /obj/item/clothing/ears/shiptest

/obj/item/clothing/glasses/shiptest
	abstract_type = /obj/item/clothing/glasses/shiptest
	inhand_icon_state = "glasses"

/obj/item/clothing/mask/shiptest
	abstract_type = /obj/item/clothing/mask/shiptest
	var/can_adjust = FALSE

/obj/item/clothing/shoes/shiptest
	abstract_type = /obj/item/clothing/shoes/shiptest
	armor_type = /datum/armor/none
	fastening_type = SHOES_SLIPON
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON

/obj/item/clothing/mask/shiptest/attack_self(mob/user)
	if(!can_adjust)
		return ..()
	adjust_visor(user)

/obj/item/clothing/mask/shiptest/click_alt(mob/user)
	if(!can_adjust)
		return ..()
	return adjust_visor(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/obj/item/clothing/mask/shiptest/examine(mob/user)
	. = ..()
	if(can_adjust)
		// Alt-click opens a styled mask's styles, so that one adjusts in hand
		. += span_notice(length(GetComponents(/datum/component/reskinable_item)) ? "Use it in hand to adjust it." : "Alt-click to adjust it.")

/obj/item/clothing/mask/shiptest/balaclava
	abstract_type = /obj/item/clothing/mask/shiptest/balaclava
	flags_cover = MASKCOVERSMOUTH
	can_adjust = TRUE
	actions_types = list(/datum/action/item_action/adjust)
	visor_flags_cover = MASKCOVERSMOUTH
	w_class = WEIGHT_CLASS_SMALL
	flags_inv = HIDEFACE | HIDEHAIR | HIDEFACIALHAIR | HIDEEARS | HIDESNOUT
	visor_flags_inv = HIDEFACE | HIDEHAIR | HIDEFACIALHAIR | HIDESNOUT
	alternate_worn_layer = LOW_FACEMASK_LAYER
	inhand_icon_state = "balaclava"

/obj/item/clothing/mask/shiptest/breath
	abstract_type = /obj/item/clothing/mask/shiptest/breath
	flags_cover = MASKCOVERSMOUTH
	can_adjust = TRUE
	actions_types = list(/datum/action/item_action/adjust)
	visor_flags_cover = MASKCOVERSMOUTH
	w_class = WEIGHT_CLASS_SMALL
	body_parts_covered = NONE
	inhand_icon_state = "m_mask"

/obj/item/clothing/mask/shiptest/gas_mask
	abstract_type = /obj/item/clothing/mask/shiptest/gas_mask
	flags_cover = MASKCOVERSEYES | MASKCOVERSMOUTH
	flags_inv = HIDEEARS | HIDEEYES | HIDEFACE | HIDEFACIALHAIR | HIDESNOUT
	inhand_icon_state = "gas_alt"

/obj/item/clothing/mask/shiptest/sterile_mask
	abstract_type = /obj/item/clothing/mask/shiptest/sterile_mask
	flags_cover = MASKCOVERSMOUTH
	can_adjust = TRUE
	actions_types = list(/datum/action/item_action/adjust)
	visor_flags_cover = MASKCOVERSMOUTH
	w_class = WEIGHT_CLASS_TINY
	flags_inv = HIDEFACE | HIDESNOUT
	visor_flags_inv = HIDEFACE | HIDESNOUT
	inhand_icon_state = "s_mask"

/obj/item/clothing/glasses/shiptest/ballistic_goggles
	abstract_type = /obj/item/clothing/glasses/shiptest/ballistic_goggles

/obj/item/clothing/glasses/shiptest/eye_mask
	abstract_type = /obj/item/clothing/glasses/shiptest/eye_mask

/obj/item/clothing/glasses/shiptest/eyepatch
	abstract_type = /obj/item/clothing/glasses/shiptest/eyepatch

/obj/item/clothing/glasses/shiptest/pincher_glasses
	abstract_type = /obj/item/clothing/glasses/shiptest/pincher_glasses

/obj/item/clothing/glasses/shiptest/safety_goggles
	abstract_type = /obj/item/clothing/glasses/shiptest/safety_goggles

/obj/item/clothing/glasses/shiptest/sunglasses
	abstract_type = /obj/item/clothing/glasses/shiptest/sunglasses

/obj/item/clothing/glasses/shiptest/tinted_goggles
	abstract_type = /obj/item/clothing/glasses/shiptest/tinted_goggles

/obj/item/clothing/mask/shiptest/breath/composite_respirator
	abstract_type = /obj/item/clothing/mask/shiptest/breath/composite_respirator

/obj/item/clothing/mask/shiptest/breath/face_mask
	abstract_type = /obj/item/clothing/mask/shiptest/breath/face_mask

/obj/item/clothing/mask/shiptest/breath/half_mask
	abstract_type = /obj/item/clothing/mask/shiptest/breath/half_mask

/obj/item/clothing/mask/shiptest/whistle
	abstract_type = /obj/item/clothing/mask/shiptest/whistle

/obj/item/clothing/shoes/shiptest/clogs
	abstract_type = /obj/item/clothing/shoes/shiptest/clogs

/obj/item/clothing/ears/shiptest/headlamp
	name = "headlamp"
	desc = "A compact headlamp that leaves your hands free."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "headlamp"
	base_icon_state = "headlamp"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "headlamp"
	actions_types = list(/datum/action/item_action/toggle_light)
	light_system = OVERLAY_LIGHT_DIRECTIONAL
	light_color = COLOR_LIGHT_ORANGE
	light_range = 4
	light_power = 0.8
	light_on = FALSE

/obj/item/clothing/ears/shiptest/headlamp/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/clothing/ears/shiptest/headlamp/attack_self(mob/living/user)
	set_light_on(!light_on)
	update_appearance()
	update_item_action_buttons()

/obj/item/clothing/ears/shiptest/headlamp/update_icon_state()
	. = ..()
	icon_state = inhand_icon_state = "[base_icon_state][light_on ? "-on" : ""]"

/obj/item/clothing/glasses/shiptest/eyepatch/double
	name = "double eyepatch"
	desc = "Two costume eye patches with see-through mesh for the seasoned stage pirate."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "eyepatch_double"
	base_icon_state = "eyepatch_double"
	inhand_icon_state = "blindfold"

/obj/item/clothing/glasses/shiptest/sunglasses/cheap
	name = "cheap sunglasses"
	desc = "Decorative eyewear styled after cheap sunglasses."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "sun"
	base_icon_state = "sun"
	inhand_icon_state = "sunglasses"

/obj/item/clothing/glasses/shiptest/eye_mask/gold_trimmed
	name = "gold-trimmed eye mask"
	desc = "A decorative eye mask with dark lenses and gold trim."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "eye_mask_gold_trimmed"
	base_icon_state = "eye_mask_gold_trimmed"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "eye_mask_gold_trimmed"

/obj/item/clothing/glasses/shiptest/tinted_goggles/red
	name = "red-tinted goggles"
	desc = "Decorative red-tinted goggles with a broad wraparound lens."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "tinted_goggles_red"

/obj/item/clothing/glasses/shiptest/ballistic_goggles/orange
	name = "orange-tinted goggles"
	desc = "Decorative orange-tinted goggles with a broad wraparound lens."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "ballistic_goggles_orange"

/obj/item/clothing/glasses/shiptest/tinted_goggles/green
	name = "green-tinted goggles"
	desc = "Decorative green-tinted goggles with a broad wraparound lens."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "tinted_goggles_green"

/obj/item/clothing/glasses/shiptest/tinted_goggles/amber
	name = "amber-tinted goggles"
	desc = "Decorative amber-tinted goggles with a broad wraparound lens."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "tinted_goggles_amber"
	base_icon_state = "tinted_goggles_amber"

/obj/item/clothing/glasses/shiptest/eye_mask/monochrome
	name = "monochrome eye mask"
	desc = "A decorative eye mask with contrasting black and white panels."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "eye_mask_monochrome"
	base_icon_state = "eye_mask_monochrome"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "eye_mask_monochrome"

/obj/item/clothing/glasses/shiptest/pincher_glasses/thin
	name = "thin pincher glasses"
	desc = "Thin, armless costume glasses that clip onto the face."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "pincher_glasses_thin"
	base_icon_state = "pincher_glasses_thin"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "pincher_glasses_thin"

/obj/item/clothing/glasses/shiptest/safety_goggles/skier
	name = "safety goggles"
	desc = "A pair of costume goggles with a broad, wraparound lens."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "safety_goggles_skier"
	base_icon_state = "safety_goggles_skier"

/obj/item/clothing/glasses/shiptest/safety_goggles/biker
	parent_type = /obj/item/clothing/glasses/shiptest/safety_goggles/skier
	name = "safety goggles (biker)"
	icon_state = "safety_goggles_biker"
	base_icon_state = "safety_goggles_biker"

/obj/item/clothing/glasses/shiptest/eye_mask/purple
	name = "purple eye mask"
	desc = "A decorative purple eye mask."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "eye_mask_purple"
	base_icon_state = "eye_mask_purple"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "eye_mask_purple"

/obj/item/clothing/glasses/shiptest/ballistic_goggles/amber
	name = "ballistic goggles"
	desc = "Decorative eyewear styled after ballistic goggles."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "ballistic_goggles_amber"

/obj/item/clothing/glasses/shiptest/tinted_goggles/cyan
	name = "cyan-tinted goggles"
	desc = "Bright cyan costume goggles whose colored lenses obscure the wearer's eyes."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "tinted_goggles_cyan"
	base_icon_state = "tinted_goggles_cyan"

/obj/item/clothing/mask/shiptest/balaclava/combat
	name = "combat balaclava"
	desc = "A comfortable fabric balaclava with a decorative mouthpiece."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "balaclava_combat"
	base_icon_state = "balaclava_combat"

/obj/item/clothing/mask/shiptest/balaclava/ribbed_black
	name = "ribbed black balaclava"
	desc = "A comfortable fabric balaclava with a decorative mouthpiece."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "balaclava_ribbed_black"

/obj/item/clothing/mask/shiptest/balaclava/grey
	name = "grey balaclava"
	desc = "A comfortable fabric balaclava with a decorative mouthpiece."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "balaclava_grey"
	base_icon_state = "balaclava_grey"

/obj/item/clothing/mask/shiptest/breath/face_mask/grey_draped
	name = "grey draped face mask"
	desc = "A fabric face covering with a loose drape around the neck."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "face_mask_grey_draped"
	base_icon_state = "face_mask_grey_draped"
	alternate_worn_layer = LOW_FACEMASK_LAYER

/obj/item/clothing/mask/shiptest/breath/composite_respirator/olive
	name = "olive composite respirator replica"
	desc = "A costume replica of an olive composite respirator, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "composite_respirator_olive"

/obj/item/clothing/mask/shiptest/breath/composite_respirator/blue
	parent_type = /obj/item/clothing/mask/shiptest/breath/composite_respirator/olive
	name = "blue composite respirator replica"
	desc = "A costume replica of a blue composite respirator, with decorative fittings."
	icon_state = "composite_respirator_blue"

/obj/item/clothing/mask/shiptest/breath/half_mask/white
	name = "white half mask"
	desc = "A close-fitting costume half mask with a decorative fitting."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "half_mask_white"
	base_icon_state = "half_mask_white"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "half_mask_white"

/obj/item/clothing/mask/shiptest/gas_mask/teal_lensed
	name = "teal-lensed gas mask replica"
	desc = "A costume replica of a teal-lensed gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_teal_lensed"
	base_icon_state = "gas_mask_teal_lensed"
	flags_inv = HIDEEARS | HIDEFACE | HIDEFACIALHAIR | HIDESNOUT

/obj/item/clothing/mask/shiptest/gas_mask/crimson_visored
	name = "crimson-visored gas mask replica"
	desc = "A costume replica of a crimson-visored gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_crimson_visored"
	base_icon_state = "gas_mask_crimson_visored"

/obj/item/clothing/mask/shiptest/gas_mask/sack
	name = "sack gas mask replica"
	desc = "A costume replica of sack gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_sack"
	base_icon_state = "gas_mask_sack"

/obj/item/clothing/mask/shiptest/gas_mask/amber_visored
	name = "amber-visored gas mask replica"
	desc = "A costume replica of an amber-visored gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "gas_mask_amber_visored"

/obj/item/clothing/mask/shiptest/gas_mask/round_lensed
	name = "round-lensed gas mask replica"
	desc = "A costume replica of a round-lensed gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_round_lensed"
	base_icon_state = "gas_mask_round_lensed"

/obj/item/clothing/mask/shiptest/gas_mask/leather
	name = "leather gas mask replica"
	desc = "A costume replica of leather gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_leather"
	base_icon_state = "gas_mask_leather"

/obj/item/clothing/mask/shiptest/gas_mask/black
	name = "black gas mask replica"
	desc = "A costume replica of black gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "gas_mask_black"
	base_icon_state = "gas_mask_black"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "gas_mask_black"

/obj/item/clothing/mask/shiptest/gas_mask/red_visored
	name = "red-visored gas mask replica"
	desc = "A costume replica of a red-visored gas mask, with decorative fittings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	icon_state = "gas_mask_red_visored"

/obj/item/clothing/mask/shiptest/sterile_mask/purple
	name = "purple fabric mask"
	desc = "A purple fabric mask styled after medical face coverings."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "sterile_mask_purple"
	base_icon_state = "sterile_mask_purple"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "sterile_mask_purple"

/obj/item/clothing/mask/shiptest/whistle/trench
	parent_type = /obj/item/clothing/mask/whistle
	name = "trench whistle"
	desc = "A long whistle worn on a cord. Useful for announcing a charge."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	base_icon_state = "whistle"

/obj/item/clothing/shoes/shiptest/clogs/white
	name = "white clogs"
	desc = "Comfortable clogs for general use."
	icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	worn_icon = 'modular_aphelion/modules/shiptest_clothing/icons/worn.dmi'
	icon_state = "clogs_white"
	base_icon_state = "clogs_white"
	lefthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/shiptest_clothing/icons/face_righthand.dmi'
	inhand_icon_state = "clogs_white"
