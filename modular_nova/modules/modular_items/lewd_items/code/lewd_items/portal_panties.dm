/obj/item/clothing/sextoy/portal_panties
	name = "portal underwear receiver"
	desc = "A bluespace endpoint to be used inside the underwear, meant to allow lovers to hump at a distance. Needs to be paired with a portal device before use."
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/portal.dmi'
	icon_state = "portal_panties"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_MASK
	lewd_slot_flags = LEWD_SLOT_PENIS | LEWD_SLOT_VAGINA | LEWD_SLOT_ANUS
	/// Strong peer reference; neither item owns the other.
	var/obj/item/clothing/sextoy/portal_fleshlight/linked_fleshlight
	/// Receiver anatomy selected by its authoritative equipped slot.
	var/current_target
	/// Whether the panties' wearer is anonymous
	var/anonymous = FALSE
	/// The currently observed receiver wearer.
	var/datum/weakref/observed_wearer
	/// Whether an appearance refresh is already queued.
	var/appearance_refresh_queued = FALSE

/obj/item/clothing/sextoy/portal_panties/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
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
	if(!has_reciprocal_link())
		. += span_notice("The status light is off. The device needs to be paired with a portal fleshlight.")
		return

	var/configuration_valid = receiver_configuration_valid()
	. += span_notice("The status light is [configuration_valid ? "on" : "off"]. The portal is [configuration_valid ? "open" : "closed"].")
	if(configuration_valid)
		. += span_notice("The current target is: [current_target]")

	. += span_notice("Equip it as a mask to connect to the mouth, or use the interaction panel to equip it in a specific genital slot.")

/obj/item/clothing/sextoy/portal_panties/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	var/obj/item/clothing/sextoy/portal_fleshlight/portal_toy = attacking_item
	if(!istype(portal_toy))
		return
	portal_toy.link_panties(src, user)

/obj/item/clothing/sextoy/portal_panties/lewd_equipped(mob/living/carbon/human/user, slot, initial)
	. = ..()
	update_target(user, slot)

/obj/item/clothing/sextoy/portal_panties/equipped(mob/living/carbon/human/user, slot)
	. = ..()
	update_target(user, slot)

/obj/item/clothing/sextoy/portal_panties/dropped(mob/living/carbon/human/user)
	. = ..()
	update_target(user)

/obj/item/clothing/sextoy/portal_panties/proc/update_target(mob/living/carbon/human/user, slot)
	if(!istype(user))
		return

	current_equipped_slot = slot

	// The mask slot is an ITEM_SLOT_ bitflag; the rest are ORGAN_SLOT_ strings that double as their own target.
	switch(slot)
		if(ITEM_SLOT_MASK)
			current_target = BODY_ZONE_PRECISE_MOUTH
		if(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS)
			current_target = slot
		else
			current_target = null
	set_observed_wearer(current_target ? user : null)

	if(has_reciprocal_link())
		linked_fleshlight.update_appearance()
	else if(!isnull(current_target))
		audible_message("[icon2html(src, hearers(src))] *beep* *beep* *beep*")
		playsound(src, 'sound/machines/beep/triple_beep.ogg', ASSEMBLY_BEEP_VOLUME, TRUE)
		to_chat(user, span_notice("The panties are not linked to a portal fleshlight."))

/// Sets the wearer we observe without owning them.
/obj/item/clothing/sextoy/portal_panties/proc/set_observed_wearer(mob/living/carbon/human/new_wearer)
	var/static/list/wearer_visual_signals = list(
		COMSIG_MOB_EQUIPPED_ITEM = PROC_REF(on_wearer_item_equipped),
		COMSIG_MOB_UNEQUIPPED_ITEM = PROC_REF(on_wearer_item_unequipped),
		COMSIG_CARBON_APPLY_OVERLAY = PROC_REF(on_wearer_overlay_changed),
		COMSIG_CARBON_REMOVE_OVERLAY = PROC_REF(on_wearer_overlay_changed),
		COMSIG_HUMAN_GENITAL_UPDATED = PROC_REF(on_wearer_genital_changed),
	)
	var/mob/living/carbon/human/old_wearer = observed_wearer?.resolve()
	if(old_wearer == new_wearer)
		return
	if(!QDELETED(old_wearer))
		UnregisterSignal(old_wearer, wearer_visual_signals)
	observed_wearer = new_wearer ? WEAKREF(new_wearer) : null
	if(new_wearer)
		for(var/wearer_signal in wearer_visual_signals)
			RegisterSignal(new_wearer, wearer_signal, wearer_visual_signals[wearer_signal])

/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_item_equipped(datum/source, obj/item/equipped_item, slot)
	SIGNAL_HANDLER
	if(slot != ITEM_SLOT_HANDS)
		on_wearer_visual_changed(source)

/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_item_unequipped(datum/source, obj/item/unequipped_item, force, atom/newloc, no_move, invdrop, silent, hand_index)
	SIGNAL_HANDLER
	if(!hand_index)
		on_wearer_visual_changed(source)

/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_overlay_changed(datum/source, changed_layer)
	SIGNAL_HANDLER
	if(changed_layer != HANDS_LAYER)
		on_wearer_visual_changed(source)

/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_genital_changed(datum/source, obj/item/organ/genital/updated_genital)
	SIGNAL_HANDLER
	if(updated_genital.slot == current_target)
		on_wearer_visual_changed(source)

/obj/item/clothing/sextoy/portal_panties/proc/on_wearer_visual_changed(datum/source)
	SIGNAL_HANDLER
	if(source != observed_wearer?.resolve() || appearance_refresh_queued || !has_reciprocal_link())
		return
	appearance_refresh_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(flush_linked_appearance_refresh)), 0)

/obj/item/clothing/sextoy/portal_panties/proc/flush_linked_appearance_refresh()
	appearance_refresh_queued = FALSE
	if(has_reciprocal_link())
		linked_fleshlight.update_appearance()

/obj/item/clothing/sextoy/portal_panties/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return .

	anonymous = !anonymous
	playsound(src, 'sound/machines/ping.ogg', 50, FALSE)
	balloon_alert(user, "anonymous mode: [anonymous ? "ON" : "OFF"]")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/clothing/sextoy/portal_panties/click_alt(mob/user)
	if(!has_reciprocal_link())
		to_chat(user, span_warning("[src] isn't linked to any portal fleshlight!"))
		return CLICK_ACTION_BLOCKING

	var/datum/weakref/fleshlight_ref = WEAKREF(linked_fleshlight)
	var/choice = tgui_alert(user, "Are you sure you want to unlink the portal fleshlight?", "Unlink Portal Fleshlight", list("Yes", "No"))
	if(choice != "Yes")
		return CLICK_ACTION_BLOCKING
	var/obj/item/clothing/sextoy/portal_fleshlight/fleshlight = fleshlight_ref.resolve()
	if(QDELETED(src) || QDELETED(fleshlight) || linked_fleshlight != fleshlight || fleshlight.linked_panties != src || !user.Adjacent(src))
		return CLICK_ACTION_BLOCKING

	to_chat(user, span_notice("You unlink the portal fleshlight from [src]."))
	clear_link()
	return CLICK_ACTION_SUCCESS

/// Returns the wearer only when the receiver is still in the slot it claims.
/obj/item/clothing/sextoy/portal_panties/proc/get_equipped_wearer()
	if(!ishuman(loc) || QDELETED(loc) || !current_target || !current_equipped_slot)
		return null
	var/mob/living/carbon/human/wearer = loc
	if(current_target == BODY_ZONE_PRECISE_MOUTH)
		if(current_equipped_slot != ITEM_SLOT_MASK || wearer.get_item_by_slot(ITEM_SLOT_MASK) != src)
			return null
	else if(current_equipped_slot != current_target || wearer.get_lewd_slot_item(current_equipped_slot) != src)
		return null
	return wearer

/// Presentation and authority helper for equipped slot, anatomy, and exposure.
/obj/item/clothing/sextoy/portal_panties/proc/receiver_configuration_valid()
	var/mob/living/carbon/human/wearer = get_equipped_wearer()
	return wearer && wearer.portal_target_is_accessible(current_target)

/obj/item/clothing/sextoy/portal_panties/proc/has_reciprocal_link()
	return !QDELETED(linked_fleshlight) && linked_fleshlight.linked_panties == src

/// Silently and idempotently clears both peer references without deleting either item.
/obj/item/clothing/sextoy/portal_panties/proc/clear_link()
	var/obj/item/clothing/sextoy/portal_fleshlight/old_fleshlight = linked_fleshlight
	linked_fleshlight = null
	if(old_fleshlight?.linked_panties != src)
		return
	old_fleshlight.linked_panties = null
	if(!QDELETED(old_fleshlight))
		old_fleshlight.update_appearance()

/obj/item/clothing/sextoy/portal_panties/Destroy()
	var/mob/living/carbon/human/wearer = ishuman(loc) ? loc : null
	var/cleared_genital_slot = FALSE
	if(wearer && (current_equipped_slot in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS)) && wearer.get_lewd_slot_item(current_equipped_slot) == src)
		wearer.set_lewd_slot_item(current_equipped_slot, null)
		cleared_genital_slot = TRUE
	if(cleared_genital_slot && !QDELETED(wearer))
		wearer.update_inv_lewd()
	current_equipped_slot = null
	current_target = null
	set_observed_wearer(null)
	appearance_refresh_queued = FALSE
	clear_link()
	return ..()
