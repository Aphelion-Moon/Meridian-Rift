/// Opens and locks the one chastity device it came tucked inside, worn or in hand.
/obj/item/key/chastity
	name = "chastity key"
	desc = "A small key with a heart-shaped bow, for a chastity device."
	icon = 'modular_aphelion/modules/chastity/icons/chastity.dmi'
	icon_state = "chastity_key"
	obj_flags = parent_type::obj_flags | UNIQUE_RENAME
	obj_flags_nova = ERP_ITEM
	interaction_flags_click = NEED_DEXTERITY
	/// REF() of the device this key turns.
	var/key_id

/obj/item/key/chastity/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/obj/item/clothing/sextoy/chastity/device = interacting_with
	if(ishuman(interacting_with))
		var/mob/living/carbon/human/wearer = interacting_with
		device = null
		var/wears_one = FALSE
		for(var/obj/item/clothing/sextoy/chastity/worn in list(wearer.penis, wearer.vagina))
			wears_one = TRUE
			if(REF(worn) == key_id)
				device = worn
		if(!device)
			if(!wears_one)
				return NONE
			to_chat(user, span_warning("This isn't the right key."))
			return ITEM_INTERACT_BLOCKING
	if(!istype(device))
		return NONE
	if(REF(device) != key_id)
		to_chat(user, span_warning("This isn't the right key."))
		return ITEM_INTERACT_BLOCKING
	if(!device.key_path)
		return NONE
	INVOKE_ASYNC(device, TYPE_PROC_REF(/obj/item/clothing/sextoy/chastity, turn_key), user)
	return ITEM_INTERACT_SUCCESS

/// A smart lock's key: one red button that locks or unlocks its device from anywhere.
/obj/item/key/chastity/remote
	name = "chastity remote"
	desc = "A little fob with one red button. It locks and unlocks a smart chastity lock from anywhere."
	icon_state = "chastity_remote"

/obj/item/key/chastity/remote/Initialize(mapload)
	. = ..()
	update_appearance(UPDATE_OVERLAYS)

/obj/item/key/chastity/remote/update_overlays()
	. = ..()
	. += emissive_appearance(icon, "[icon_state]_e", src, alpha = src.alpha)

/obj/item/key/chastity/remote/attack_self(mob/user)
	var/obj/item/clothing/sextoy/chastity/device = locate(key_id)
	if(!istype(device))
		to_chat(user, span_warning("You press the button. Nothing answers."))
		return TRUE
	device.set_locked(!device.locked, user, remote = TRUE)
	return TRUE
