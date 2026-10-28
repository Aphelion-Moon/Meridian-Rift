// The chastity devices ported from Ratwood. Their spiked ones were left out.

/obj/item/clothing/sextoy/chastity/shielded
	name = "shielded chastity cage"
	desc = "A small steel cage that keeps a cock from getting hard, with a plate shielding the rear as well. It locks with the key tucked inside it."
	icon_state = "cage_standard_shield"
	closes = CHASTITY_PENIS | CHASTITY_ANUS

/obj/item/clothing/sextoy/chastity/flat
	name = "flat chastity cage"
	desc = "A flat, low-profile cage that presses a cock tight against the body. It locks with the key tucked inside it."
	icon_state = "cage_flat"
	worn_shape = "cage_flat"

/obj/item/clothing/sextoy/chastity/flat/shielded
	name = "shielded flat chastity cage"
	desc = "A flat, low-profile cage with a plate shielding the rear as well. It locks with the key tucked inside it."
	icon_state = "cage_flat_shield"
	closes = CHASTITY_PENIS | CHASTITY_ANUS

/obj/item/clothing/sextoy/chastity/insert
	name = "insertable chastity belt"
	desc = "A locking belt with a smooth insert that fills and seals a pussy. It locks with the key tucked inside it."
	icon_state = "cage_insert"
	worn_shape = "cage_belt"
	lewd_slot_flags = LEWD_SLOT_VAGINA
	closes = CHASTITY_VAGINA
	needs = CHASTITY_VAGINA

/obj/item/clothing/sextoy/chastity/insert/shielded
	name = "shielded insertable chastity belt"
	desc = "A locking belt with an insert that seals a pussy, and a plate shielding the rear. It locks with the key tucked inside it."
	icon_state = "cage_insert_shield"
	closes = CHASTITY_VAGINA | CHASTITY_ANUS

/obj/item/clothing/sextoy/chastity/belt
	name = "chastity belt"
	desc = "A locking steel belt that seals away whatever its wearer has down there. It locks with the key tucked inside it."
	icon_state = "cage_belt"
	worn_shape = "cage_belt"
	lewd_slot_flags = LEWD_SLOT_PENIS | LEWD_SLOT_VAGINA
	closes = CHASTITY_PENIS | CHASTITY_VAGINA
	covers = CHASTITY_TESTICLES
	needs = NONE

/obj/item/clothing/sextoy/chastity/belt/intersex
	name = "intersex chastity device"
	desc = "A cage and a belt in one locking frame, for wearers with both. It locks with the key tucked inside it."
	worn_shape = "cage_intersex"
	needs = CHASTITY_PENIS | CHASTITY_VAGINA

/obj/item/clothing/sextoy/chastity/belt/plate
	name = "chastity plate"
	desc = "A solid locking plate that covers the whole groin. It locks with the key tucked inside it."
	icon_state = "cage_plate"
	worn_shape = "cage_plate"

/**
 * A rune-etched device with no keyhole. It clamps shut when fitted, and nothing short of a bible or a null rod
 * pressed to it breaks the curse and lets it off.
 */
/obj/item/clothing/sextoy/chastity/cursed
	name = "cursed chastity device"
	desc = "A rune-etched chastity frame that flexes like something alive. There's no keyhole anywhere on it."
	icon_state = "cage_cursed"
	lewd_slot_flags = LEWD_SLOT_PENIS | LEWD_SLOT_VAGINA
	closes = CHASTITY_PENIS | CHASTITY_VAGINA
	needs = NONE
	key_path = null

/obj/item/clothing/sextoy/chastity/cursed/get_worn_shape(mob/living/carbon/human/human)
	var/held = closes & genitals_of(human)
	if((held & (CHASTITY_PENIS|CHASTITY_VAGINA)) == (CHASTITY_PENIS|CHASTITY_VAGINA))
		return "cage_cursed_intersex"
	return (held & CHASTITY_PENIS) ? "cage_cursed_cock" : "cage_cursedb"

/obj/item/clothing/sextoy/chastity/cursed/fit(mob/living/carbon/human/wearer)
	. = ..()
	locked = TRUE
	RegisterSignal(wearer, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_holy_item))
	chastity_flavour(wearer, "cursed_lock")

/obj/item/clothing/sextoy/chastity/cursed/unfit()
	var/mob/living/carbon/human/wearer = wearer_ref?.resolve()
	if(wearer)
		UnregisterSignal(wearer, COMSIG_ATOM_ITEM_INTERACTION)
	locked = FALSE
	return ..()

/obj/item/clothing/sextoy/chastity/cursed/proc/on_holy_item(mob/living/carbon/human/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(tool, /obj/item/book/bible) && !istype(tool, /obj/item/nullrod))
		return NONE
	if(user.zone_selected != BODY_ZONE_PRECISE_GROIN)
		return NONE
	INVOKE_ASYNC(src, PROC_REF(exorcise), user, source, tool)
	return ITEM_INTERACT_SUCCESS

/// Presses a holy item to the device until the curse breaks and it lets go.
/obj/item/clothing/sextoy/chastity/cursed/proc/exorcise(mob/living/user, mob/living/carbon/human/wearer, obj/item/tool)
	to_chat(user, span_notice("You press [tool] to [src]. The runes on it start to smoulder..."))
	if(!do_after(user, 5 SECONDS, wearer) || wearer_ref?.resolve() != wearer)
		return
	if(user != wearer)
		to_chat(user, span_notice("The runes on [wearer]'s [name] flare and go dark, and it falls away."))
	to_chat(wearer, span_notice("The runes on [src] flare and go dark, and it lets you go."))
	locked = FALSE
	come_off(wearer)

// Station-made devices, restyled from the shapes above.

/obj/item/clothing/sextoy/chastity/chrome
	name = "chrome chastity cage"
	desc = "A polished chrome cage ringed with red status lights, the kind of hardware chromed-up street crews bolt onto everything. Its smart lock answers to the remote tucked inside it."
	icon_state = "chrome_cage"
	worn_shape = "chrome_cage"
	key_path = /obj/item/key/chastity/remote
	pick_tool = TOOL_MULTITOOL
	status_lights = TRUE

/obj/item/clothing/sextoy/chastity/insert/chrome
	name = "chrome chastity belt"
	desc = "A polished chrome belt with a smooth insert and a red status light at the front. Its smart lock answers to the remote tucked inside it."
	icon_state = "chrome_belt"
	worn_shape = "chrome_belt"
	key_path = /obj/item/key/chastity/remote
	pick_tool = TOOL_MULTITOOL
	status_lights = TRUE

/obj/item/clothing/sextoy/chastity/industrial
	name = "industrial chastity cage"
	desc = "Blackened steel with a hazard-striped ring and a row of blunt spikes along the top, built like it came off a line that usually makes something much bigger. It locks with the key tucked inside it."
	icon_state = "industrial_cage"
	worn_shape = "industrial_cage"

/obj/item/clothing/sextoy/chastity/belt/industrial
	name = "industrial chastity belt"
	desc = "A blackened steel belt with a hazard-striped front plate and blunt studs along the waistband. It seals away whatever its wearer has, and locks with the key tucked inside it."
	icon_state = "industrial_belt"
	worn_shape = "industrial_belt"
