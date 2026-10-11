#define BRIDLE_BLINDERS (1<<0)
#define BRIDLE_BIT (1<<1)

/// A horse bridle in three colours - straps, blinders and fittings. Lowered blinders darken the wearer's sight; a set
/// bit covers their mouth and muffles them through tg's muffles_speech element. The wearer moves either with an action
/// button, alt-click steps through none, blinders, bit and both, and another player takes that step from the strip menu.
/// Secured in hand, the straps hold the blinders and the bit where they are.
/obj/item/clothing/mask/bridle
	name = "bridle"
	desc = "A Sunny Stables design of a leather horse bridle, complete with blinders and a bit. It's made of several leather straps and metal fittings. You can tighten or loosen the straps to make sure that the blinders and the bit stay in place."
	icon = 'icons/map_icons/clothing/mask.dmi'
	icon_state = "/obj/item/clothing/mask/bridle"
	post_init_icon_state = "bridle"
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_masks.dmi'
	worn_icon_muzzled = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_masks_muzzled.dmi'
	worn_icon_state = "bridle"
	inhand_icon_state = "sechailer"
	greyscale_config = /datum/greyscale_config/bridle
	greyscale_config_worn = /datum/greyscale_config/bridle/worn
	greyscale_config_worn_muzzled = /datum/greyscale_config/bridle/worn/muzzled
	greyscale_colors = "#383840#dc7ef4#c0c0c0"
	flags_1 = IS_PLAYER_COLORABLE_1
	supports_variations_flags = CLOTHING_SNOUTED_VARIATION
	w_class = WEIGHT_CLASS_SMALL
	equip_sound = 'sound/items/equip/toolbelt_equip.ogg'
	actions_types = list(/datum/action/item_action/bridle_blinders, /datum/action/item_action/bridle_bit)
	action_slots = ITEM_SLOT_MASK
	obj_flags_nova = ERP_ITEM
	/// BRIDLE_BLINDERS while the blinders are lowered, BRIDLE_BIT while the bit is set - changed only by set_mode().
	var/mode = NONE
	/// The straps are secured, holding the blinders and the bit where they are.
	var/straps_locked = FALSE

/obj/item/clothing/mask/bridle/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ITEM_GET_STRIPPABLE_ALT_ACTIONS, PROC_REF(add_strip_action))
	RegisterSignal(src, COMSIG_ITEM_STRIPPABLE_ALT_ACTION, PROC_REF(do_strip_action))

/obj/item/clothing/mask/bridle/examine(mob/user)
	. = ..()
	. += span_notice("The blinders are [(mode & BRIDLE_BLINDERS) ? "down" : "up"], the bit is [(mode & BRIDLE_BIT) ? "set" : "unset"], and the straps are [straps_locked ? "secured" : "loose"].")

/obj/item/clothing/mask/bridle/attack_self(mob/user)
	..()
	straps_locked = !straps_locked
	to_chat(user, span_notice("You [straps_locked ? "secure" : "loosen"] [src]'s straps."))

/obj/item/clothing/mask/bridle/click_alt(mob/user)
	return cycle_mode(user) ? CLICK_ACTION_SUCCESS : CLICK_ACTION_BLOCKING

/obj/item/clothing/mask/bridle/ui_action_click(mob/user, actiontype)
	set_mode(mode ^ (istype(actiontype, /datum/action/item_action/bridle_bit) ? BRIDLE_BIT : BRIDLE_BLINDERS), user)

/// Steps through none, blinders, bit and both - counting in binary.
/obj/item/clothing/mask/bridle/proc/cycle_mode(mob/user)
	return set_mode((mode + 1) & (BRIDLE_BLINDERS | BRIDLE_BIT), user)

/// Lowers or raises the blinders and sets or loosens the bit to match `new_mode`, unless the straps are secured.
/obj/item/clothing/mask/bridle/proc/set_mode(new_mode, mob/user)
	if(straps_locked)
		to_chat(user, span_warning("[src]'s straps are too secure to adjust!"))
		return FALSE
	var/changed = mode ^ new_mode
	mode = new_mode
	var/mob/living/carbon/wearer = loc
	if(!istype(wearer) || wearer.get_item_by_slot(ITEM_SLOT_MASK) != src)
		wearer = null
	if(changed & BRIDLE_BLINDERS)
		var/lowered = mode & BRIDLE_BLINDERS
		tint = lowered ? TINT_DARKENED : 0
		worn_icon_state = lowered ? "bridle_blinders" : "bridle"
		wearer?.update_tint()
		wearer?.update_worn_mask()
		tell_moved(user, wearer, lowered ? "lower" : "raise", "blinders",
			lowered ? "obscuring your vision" : "restoring your sight")
	if(changed & BRIDLE_BIT)
		var/bitted = mode & BRIDLE_BIT
		flags_cover = bitted ? MASKCOVERSMOUTH : NONE
		set_muffled(bitted, wearer)
		tell_moved(user, wearer, bitted ? "set" : "loosen", "bit",
			bitted ? "muffling your speech" : "letting you speak freely")
	return TRUE

/// Muffles the wearer through tg's muffles_speech element while the bit is set. The element hooks a wearer only as the
/// bridle goes on or comes off, so one already wearing it is hooked, or freed before the element comes off, here.
/obj/item/clothing/mask/bridle/proc/set_muffled(bitted, mob/living/carbon/wearer)
	var/datum/element/muffles_speech/muffler = wearer ? SSdcs.GetElement(list(/datum/element/muffles_speech)) : null
	if(bitted)
		AddElement(/datum/element/muffles_speech)
		muffler?.equipped(src, wearer, ITEM_SLOT_MASK)
		return
	muffler?.dropped(src, wearer)
	RemoveElement(/datum/element/muffles_speech)

/// Tells `user` they moved the `part` - a wearer who is someone else learns what it does, and by whom unless blind.
/obj/item/clothing/mask/bridle/proc/tell_moved(mob/user, mob/living/carbon/wearer, moved, part, effect)
	to_chat(user, span_notice("You [moved] [src]'s [part][wearer == user ? ", [effect]" : ""]."))
	if(wearer && wearer != user)
		to_chat(wearer, span_userdanger("[wearer.is_blind() ? "Someone" : user] [moved]s your bridle's [part], [effect]!"))

/// Whether `user` may adjust the bridle `wearer` wears from the strip menu - only on a face, and only for an adjuster
/// who takes part in ERP and a wearer who takes sex toys. The strip menu's owner may be any atom, so it is checked first.
/obj/item/clothing/mask/bridle/proc/strip_adjustable(mob/living/carbon/wearer, mob/user)
	if(!istype(wearer) || wearer.get_item_by_slot(ITEM_SLOT_MASK) != src)
		return FALSE
	var/datum/client_interface/wearer_client = GET_CLIENT(wearer)
	var/datum/client_interface/user_client = GET_CLIENT(user)
	return wearer_client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy) \
		&& user_client?.prefs?.read_preference(/datum/preference/toggle/erp)

/obj/item/clothing/mask/bridle/proc/add_strip_action(obj/item/source, atom/owner, mob/user, list/alt_actions)
	SIGNAL_HANDLER
	if(strip_adjustable(owner, user))
		alt_actions += "adjust_bridle"

/obj/item/clothing/mask/bridle/proc/do_strip_action(obj/item/source, atom/owner, mob/user, action_key)
	SIGNAL_HANDLER
	if(action_key != "adjust_bridle")
		return NONE
	INVOKE_ASYNC(src, PROC_REF(strip_adjust), owner, user)
	return COMPONENT_ALT_ACTION_DONE

/// The strip menu's "Adjust bridle" - one step of the alt-click cycle after as long as taking the bridle off would take,
/// the wearer and onlookers warned first and both sides logged. Secured straps refuse at once, without the wait.
/obj/item/clothing/mask/bridle/proc/strip_adjust(mob/living/carbon/wearer, mob/user)
	if(DOING_INTERACTION_WITH_TARGET(user, wearer)) // The strip menu lets clicks through mid-wait - warn once.
		return
	if(!straps_locked)
		wearer.visible_message(span_warning("[user] tries to adjust [wearer]'s bridle."),
			span_userdanger("[wearer.is_blind() ? "Someone" : user] tries to adjust your bridle!"),
			span_hear("You hear rustling."), ignored_mobs = user, visible_message_flags = ALWAYS_SHOW_SELF_MESSAGE)
		if(!do_after(user, strip_delay, wearer))
			return
	if(!strip_adjustable(wearer, user) || !cycle_mode(user))
		return
	var/state = "blinders [(mode & BRIDLE_BLINDERS) ? "down" : "up"], bit [(mode & BRIDLE_BIT) ? "set" : "unset"]"
	user.log_message("adjusted the bridle of [key_name(wearer)] to [state].", LOG_ATTACK, color = "red")
	wearer.log_message("had their bridle adjusted to [state] by [key_name(user)].", LOG_VICTIM, color = "orange", log_globally = FALSE)

/datum/action/item_action/bridle_blinders
	name = "Toggle Blinders"
	desc = "Lower or raise the bridle's blinders."

/datum/action/item_action/bridle_bit
	name = "Toggle Bit"
	desc = "Set or loosen the bridle's bit."

#undef BRIDLE_BLINDERS
#undef BRIDLE_BIT
