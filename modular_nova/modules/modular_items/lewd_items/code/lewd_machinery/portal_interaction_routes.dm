/**
 * Reaching someone through the far end of a LustWish portal pair.
 *
 * The user is standing next to a relay; the target is buckled into the portal it belongs to, somewhere else.
 */
/datum/interaction_route/portal_relay
	/// The relay standing in for the target.
	var/datum/weakref/body_relay_ref

/datum/interaction_route/portal_relay/New(obj/effect/lewd_portal_relay/body_relay)
	. = ..()
	body_relay_ref = WEAKREF(body_relay)

/obj/effect/lewd_portal_relay/interaction_route_for(
	mob/living/carbon/human/represented,
	datum/interaction/interaction,
	mob/living/carbon/human/user,
)
	if(owner != represented)
		return null
	return new /datum/interaction_route/portal_relay(src)

/// The relay, or null once it has gone away.
/datum/interaction_route/portal_relay/proc/resolve_relay()
	var/obj/effect/lewd_portal_relay/body_relay = body_relay_ref?.resolve()
	return QDELETED(body_relay) ? null : body_relay

/datum/interaction_route/portal_relay/is_still_valid(datum/interaction/interaction, mob/living/carbon/human/user, mob/living/carbon/human/target, ignore_cooldown = FALSE)
	var/obj/effect/lewd_portal_relay/body_relay = resolve_relay()
	if(isnull(body_relay) || body_relay.owner != target)
		return FALSE
	var/obj/structure/lewd_portal/target_portal = target.buckled
	if(!istype(target_portal) || !target_portal.is_active_session(target, body_relay))
		return FALSE
	return interaction.distance_allowed || user.Adjacent(target) || user.Adjacent(body_relay)

/datum/interaction_route/portal_relay/participants_accept(mob/living/carbon/human/user, mob/living/carbon/human/target)
	return user.allows_portal_use() && target.allows_portal_use()

/datum/interaction_route/portal_relay/get_target_name()
	var/obj/effect/lewd_portal_relay/body_relay = resolve_relay()
	return body_relay ? "\the [body_relay.name]" : null

/datum/interaction_route/portal_relay/user_is_anonymous()
	return TRUE

/datum/interaction_route/portal_relay/target_is_anonymous()
	return TRUE

/// A relay that can no longer draw the body it is standing in for has nothing left to show; end the session.
/datum/interaction_route/portal_relay/after_effects(mob/living/carbon/human/user, mob/living/carbon/human/target)
	var/obj/effect/lewd_portal_relay/body_relay = resolve_relay()
	if(isnull(body_relay) || body_relay.update_visuals())
		return
	var/obj/structure/lewd_portal/target_portal = target.buckled
	if(istype(target_portal) && target_portal.is_active_session(target, body_relay))
		target_portal.end_session()

/**
 * Reaching someone through a linked portal device and receiver.
 *
 * Every participant here is a separate object that can be dropped, unequipped or deleted mid-interaction, so this
 * route keeps nothing but weak references and re-asks the device itself whether the connection still stands.
 */
/datum/interaction_route/portal_device
	/// The device that owns the interaction lookup, which is not always the one being held.
	var/datum/weakref/validator_device_ref
	/// Whoever is driving the device.
	var/datum/weakref/operator_ref
	/// The worn receiver on the far end.
	var/datum/weakref/receiver_ref
	/// The device actually in the operator's hands.
	var/datum/weakref/held_device_ref
	/// Which part of the local participant is in play.
	var/local_target
	/// Whether the receiver supplies the interaction's user-side part.
	var/receiver_is_user = FALSE

/datum/interaction_route/portal_device/New(
	obj/item/clothing/sextoy/portal_fleshlight/validator_device,
	mob/living/carbon/human/operator,
	obj/item/clothing/sextoy/portal_panties/receiver,
	obj/item/clothing/sextoy/portal_fleshlight/held_device,
	local_target,
	receiver_is_user = FALSE,
)
	. = ..()
	validator_device_ref = WEAKREF(validator_device)
	operator_ref = WEAKREF(operator)
	receiver_ref = WEAKREF(receiver)
	held_device_ref = WEAKREF(held_device)
	src.local_target = local_target
	src.receiver_is_user = receiver_is_user

/datum/interaction_route/portal_device/is_still_valid(datum/interaction/interaction, mob/living/carbon/human/user, mob/living/carbon/human/target, ignore_cooldown = FALSE)
	if(isnull(local_target))
		return FALSE
	var/obj/item/clothing/sextoy/portal_fleshlight/validator_device = validator_device_ref?.resolve()
	var/mob/living/carbon/human/operator = operator_ref?.resolve()
	var/obj/item/clothing/sextoy/portal_panties/receiver = receiver_ref?.resolve()
	var/obj/item/clothing/sextoy/portal_fleshlight/held_device = held_device_ref?.resolve()
	if(QDELETED(validator_device) || QDELETED(operator) || QDELETED(receiver) || QDELETED(held_device))
		return FALSE
	if(validator_device.validate_interaction(
		operator,
		user,
		receiver,
		local_target,
		held_device,
		ignore_cooldown = ignore_cooldown,
		receiver_is_user = receiver_is_user,
	) != interaction)
		return FALSE
	return receiver.get_equipped_wearer() == target

/datum/interaction_route/portal_device/allows_same_participant()
	return TRUE

/datum/interaction_route/portal_device/validates_part_access()
	return TRUE

/datum/interaction_route/portal_device/user_is_anonymous()
	if(receiver_is_user)
		var/obj/item/clothing/sextoy/portal_panties/receiver = receiver_ref?.resolve()
		return !QDELETED(receiver) && receiver.anonymous
	var/obj/item/clothing/sextoy/portal_fleshlight/validator_device = validator_device_ref?.resolve()
	return !QDELETED(validator_device) && validator_device.anonymous

/datum/interaction_route/portal_device/target_is_anonymous()
	if(receiver_is_user)
		var/obj/item/clothing/sextoy/portal_fleshlight/validator_device = validator_device_ref?.resolve()
		return !QDELETED(validator_device) && validator_device.anonymous
	var/obj/item/clothing/sextoy/portal_panties/receiver = receiver_ref?.resolve()
	return !QDELETED(receiver) && receiver.anonymous

/// The relay currently projecting this mob, while the complete session and preferences still permit it.
/mob/proc/get_portal_output()
	var/obj/structure/lewd_portal/portal = buckled
	if(!istype(portal))
		return null
	var/obj/effect/lewd_portal_relay/output_relay = portal.relayed_body
	if(QDELETED(output_relay) || output_relay.owner != src || !output_relay.can_reveal_to(src))
		return null
	return output_relay

/// Resolves exactly the output offered before a prompt, never a replacement session.
/mob/proc/resolve_portal_output(datum/weakref/offered_output_ref)
	var/obj/effect/lewd_portal_relay/offered_output = offered_output_ref?.resolve()
	if(QDELETED(offered_output) || get_portal_output() != offered_output)
		return null
	return offered_output
