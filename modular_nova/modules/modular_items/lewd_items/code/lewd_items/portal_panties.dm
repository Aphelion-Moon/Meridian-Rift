/obj/item/clothing/sextoy/portal_panties
	name = "portal underwear receiver"
	desc = "A bluespace endpoint to be used inside the underwear, meant to allow lovers to hump at a distance. Needs to be paired with a portal device before use."
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/portal.dmi'
	icon_state = "portal_panties"
	w_class = WEIGHT_CLASS_SMALL
	lewd_slot_flags = LEWD_SLOT_PENIS | LEWD_SLOT_VAGINA | LEWD_SLOT_ANUS | LEWD_SLOT_MOUTH
	/// Strong peer reference; neither item owns the other.
	var/obj/item/clothing/sextoy/portal_fleshlight/linked_fleshlight
	/// The lewd slot this sits in while worn: an ORGAN_SLOT_ genital or BODY_ZONE_PRECISE_MOUTH.
	var/current_target
	/// Whether the panties' wearer is anonymous
	var/anonymous = FALSE

/obj/item/clothing/sextoy/portal_panties/Initialize(mapload)
	. = ..()
	register_context()

/obj/item/clothing/sextoy/portal_panties/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	if(isnull(held_item))
		context[SCREENTIP_CONTEXT_LMB] = "Pick up"
		context[SCREENTIP_CONTEXT_RMB] = "Toggle anonymous mode"
		context[SCREENTIP_CONTEXT_ALT_LMB] = linked_fleshlight ? "Unlink fleshlight" : "No fleshlight linked"
		return CONTEXTUAL_SCREENTIP_SET

	if(istype(held_item, /obj/item/clothing/sextoy/portal_fleshlight))
		context[SCREENTIP_CONTEXT_LMB] = "Link fleshlight"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/obj/item/clothing/sextoy/portal_panties/examine(mob/user)
	. = ..()
	. += span_notice("Use the interaction panel to put it in a mouth or a genital slot.")
	if(!has_reciprocal_link())
		. += span_notice("The status light is off. The device needs to be paired with a portal fleshlight.")
		return

	var/portal_open = !!get_equipped_wearer()
	. += span_notice("The status light is [portal_open ? "on" : "off"]. The portal is [portal_open ? "open" : "closed"].")
	if(portal_open)
		. += span_notice("The current target is: [current_target]")

/obj/item/clothing/sextoy/portal_panties/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	var/obj/item/clothing/sextoy/portal_fleshlight/portal_toy = attacking_item
	if(istype(portal_toy))
		portal_toy.link_panties(src, user)

/obj/item/clothing/sextoy/portal_panties/lewd_equipped(mob/living/carbon/human/user, slot, initial)
	. = ..()
	update_target(user, slot)

/obj/item/clothing/sextoy/portal_panties/dropped(mob/living/carbon/human/user)
	. = ..()
	update_target(user)

/**
 * Points the receiver at the part it now sits on, and starts or stops redrawing the device from its wearer.
 *
 * Arguments:
 * - user: The mob this was just equipped to or dropped from.
 * - slot: The lewd slot it went into, an ORGAN_SLOT_ genital or BODY_ZONE_PRECISE_MOUTH, or null when dropped.
 */
/obj/item/clothing/sextoy/portal_panties/proc/update_target(mob/living/carbon/human/user, slot)
	if(!istype(user))
		return

	current_target = (slot in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS, BODY_ZONE_PRECISE_MOUTH)) ? slot : null

	var/static/list/visual_signals = list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_HUMAN_GENITAL_UPDATED)
	if(current_target)
		RegisterSignals(user, visual_signals, PROC_REF(on_wearer_visual_changed), override = TRUE)
	else
		UnregisterSignal(user, visual_signals)

	if(has_reciprocal_link())
		linked_fleshlight.update_appearance()
	else if(current_target)
		audible_message("[icon2html(src, hearers(src))] *beep* *beep* *beep*")
		playsound_if_pref(src, 'sound/machines/beep/triple_beep.ogg', ASSEMBLY_BEEP_VOLUME, TRUE)
		to_chat(user, span_notice("The panties are not linked to a portal fleshlight."))

/// Redraws the linked device on the next tick when the wearer's body art or genitals change.
/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_visual_changed(datum/source, changed_layer_or_genital)
	SIGNAL_HANDLER
	// Genitals, lips and skin all draw on the body parts layer; clothing and held items never reach the portal art.
	if(source != loc || (isnum(changed_layer_or_genital) && changed_layer_or_genital != BODYPARTS_LAYER) || !has_reciprocal_link())
		return
	addtimer(CALLBACK(linked_fleshlight, TYPE_PROC_REF(/atom, update_appearance)), 0, TIMER_UNIQUE)

/obj/item/clothing/sextoy/portal_panties/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return .

	anonymous = !anonymous
	playsound_if_pref(src, 'sound/machines/ping.ogg', 50, FALSE)
	balloon_alert(user, "anonymous mode: [anonymous ? "ON" : "OFF"]")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/clothing/sextoy/portal_panties/click_alt(mob/user)
	if(!has_reciprocal_link())
		to_chat(user, span_warning("[src] isn't linked to any portal fleshlight!"))
		return CLICK_ACTION_BLOCKING

	if(tgui_alert(user, "Are you sure you want to unlink the portal fleshlight?", "Unlink Portal Fleshlight", list("Yes", "No")) != "Yes" || QDELETED(src) || !user.Adjacent(src))
		return CLICK_ACTION_BLOCKING

	to_chat(user, span_notice("You unlink the portal fleshlight from [src]."))
	clear_link()
	return CLICK_ACTION_SUCCESS

/**
 * Returns whoever is wearing this in the slot its target claims, or null when it isn't worn.
 *
 * A worn receiver is always open. It sits on its part underneath anything the wearer has on, so clothing,
 * underwear and arousal never close it.
 */
/obj/item/clothing/sextoy/portal_panties/proc/get_equipped_wearer()
	var/mob/living/carbon/human/wearer = loc
	if(!ishuman(wearer) || isnull(current_target))
		return null
	return wearer.get_lewd_slot_item(current_target) == src ? wearer : null

/obj/item/clothing/sextoy/portal_panties/proc/has_reciprocal_link()
	return !QDELETED(linked_fleshlight) && linked_fleshlight.linked_panties == src

/// Silently and idempotently clears both peer references without deleting either item.
/obj/item/clothing/sextoy/portal_panties/proc/clear_link()
	if(has_reciprocal_link())
		linked_fleshlight.clear_link()
	linked_fleshlight = null

/obj/item/clothing/sextoy/portal_panties/Destroy()
	var/mob/living/carbon/human/wearer = loc
	if(ishuman(wearer) && wearer.get_lewd_slot_item(current_target) == src)
		wearer.set_lewd_slot_item(current_target, null)
		if(!QDELETED(wearer))
			wearer.update_inv_lewd()
	clear_link()
	return ..()
