#define PORTAL_DEVICE_ICON 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/portal.dmi'

/obj/item/clothing/sextoy/portal_fleshlight
	name = "portal device"
	desc = "A LustWish(TM) portal device, with configurations for fleshlight or dildo, using bluespace tech to allow lovers to hump at a distance. Needs to be paired with the portal receiver before use."
	icon = PORTAL_DEVICE_ICON
	icon_state = "unpaired"
	w_class = WEIGHT_CLASS_SMALL

	/// Strong peer reference; neither item owns the other.
	var/obj/item/clothing/sextoy/portal_panties/linked_panties
	/// The local target used when the operator selects the groin.
	var/current_target = ORGAN_SLOT_PENIS
	/// Hides the local participant from the remote receiver wearer.
	var/anonymous = FALSE

	/// Live-config interaction names, indexed by the target side part and then the user side part. The first name is the default.
	var/static/list/interaction_map = list(
		ORGAN_SLOT_VAGINA = list(
			ORGAN_SLOT_PENIS = list("Fuck (vagina)"),
			ORGAN_SLOT_VAGINA = list("Tribadism"),
			BODY_ZONE_PRECISE_MOUTH = list("Lick vagina", "Lick pussy"),
			BODY_ZONE_R_ARM = list("Finger (vagina)", "Caress pussy"),
			BODY_ZONE_L_ARM = list("Finger (vagina)", "Caress pussy"),
			BODY_ZONE_R_LEG = list("Footjob (vagina)"),
			BODY_ZONE_L_LEG = list("Footjob (vagina)"),
		),
		ORGAN_SLOT_ANUS = list(
			ORGAN_SLOT_PENIS = list("Ass fuck", "Ass fuck - HARD"),
			BODY_ZONE_PRECISE_MOUTH = list("Eat ass"),
			BODY_ZONE_R_ARM = list("Finger (ass)"),
			BODY_ZONE_L_ARM = list("Finger (ass)"),
		),
		ORGAN_SLOT_PENIS = list(
			ORGAN_SLOT_PENIS = list("Frot", "Sheath fuck"),
			ORGAN_SLOT_VAGINA = list("Ride cock (vagina)", "Mount (Vagina)"),
			ORGAN_SLOT_ANUS = list("Ride cock (ass)", "Mount (Anal)"),
			BODY_ZONE_PRECISE_MOUTH = list("Blowjob", "Dick suck", "Lick cock", "Lick penis", "Smother sheath"),
			BODY_ZONE_R_ARM = list("Handjob", "Caress penis"),
			BODY_ZONE_L_ARM = list("Handjob", "Caress penis"),
			BODY_ZONE_R_LEG = list("Footjob (cock)"),
			BODY_ZONE_L_LEG = list("Footjob (cock)"),
		),
		BODY_ZONE_PRECISE_MOUTH = list(
			ORGAN_SLOT_PENIS = list("Mouth fuck", "Facefuck (Penis)"),
			ORGAN_SLOT_VAGINA = list("Facesit (vagina)"),
			ORGAN_SLOT_ANUS = list("Facesit (ass)"),
			BODY_ZONE_PRECISE_MOUTH = list("Tongue kiss", "Kiss", "Smooch"),
			BODY_ZONE_R_LEG = list("Feet to Face"),
			BODY_ZONE_L_LEG = list("Feet to Face"),
		),
	)
	var/static/list/target_cycle = list(
		ORGAN_SLOT_PENIS,
		ORGAN_SLOT_VAGINA,
		ORGAN_SLOT_ANUS,
		BODY_ZONE_PRECISE_MOUTH,
	)

	/// Device icon states for vagina descriptors with their own art. Every other descriptor uses the human art.
	var/static/list/portal_vagina_states = list(
		"Gaping" = "portal_vag_gaping",
		"Spade" = "portal_vag_spade",
		"Cloaca" = "portal_vag_cloacal",
	)
	/// Anus descriptors that the single "portal_anus" state covers.
	var/static/list/portal_anus_descriptors = list("Anus", "Donut", "Squished")

/obj/item/clothing/sextoy/portal_fleshlight/Initialize(mapload)
	. = ..()
	if(. == INITIALIZE_HINT_QDEL)
		return
	appearance_flags |= KEEP_TOGETHER
	update_appearance()
	register_context()

/obj/item/clothing/sextoy/portal_fleshlight/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	if(isnull(held_item))
		context[SCREENTIP_CONTEXT_LMB] = "Pick up"
		context[SCREENTIP_CONTEXT_RMB] = "Toggle anonymous mode"
		context[SCREENTIP_CONTEXT_ALT_LMB] = linked_panties ? "Unlink panties" : "No panties linked"
		if(is_portal_open())
			context[SCREENTIP_CONTEXT_CTRL_SHIFT_LMB] = "Interact through the portal"
		return CONTEXTUAL_SCREENTIP_SET

	if(istype(held_item, /obj/item/clothing/sextoy/portal_panties))
		context[SCREENTIP_CONTEXT_LMB] = "Link panties"
		return CONTEXTUAL_SCREENTIP_SET

	if(istype(held_item, /obj/item/clothing/sextoy/portal_fleshlight) && is_portal_open())
		context[SCREENTIP_CONTEXT_LMB] = "Use on target"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/// TRUE while the linked receiver is worn, which is all the far end needs for the portal to go through.
/obj/item/clothing/sextoy/portal_fleshlight/proc/is_portal_open()
	return is_link_valid() && !!linked_panties.get_equipped_wearer()

/**
 * Returns whether user can put their body against this device right now.
 *
 * That is holding it, or standing within a tile of it while it lies out in the open or sits in someone's hands.
 * A device packed away in storage is out of reach.
 */
/obj/item/clothing/sextoy/portal_fleshlight/proc/can_reach_device(mob/living/user)
	if(user.is_holding(src))
		return TRUE
	var/mob/living/holder = loc
	return (isturf(loc) || (istype(holder) && holder.is_holding(src))) && user.Adjacent(src)

/// Opens the receiver wearer's interaction panel for user, listing what user's own parts can do through the portal.
/obj/item/clothing/sextoy/portal_fleshlight/proc/open_wearer_panel(mob/living/carbon/human/user)
	var/mob/living/carbon/human/panel_owner = is_link_valid() ? linked_panties.get_equipped_wearer() : null
	if(!panel_owner || !user.allows_portal_use() || !panel_owner.allows_portal_use())
		panel_owner = user
	var/datum/component/interactable/interaction_component = panel_owner.GetComponent(/datum/component/interactable)
	interaction_component?.open_interaction_menu(panel_owner, user)

/obj/item/clothing/sextoy/portal_fleshlight/click_ctrl_shift(mob/user)
	if(!ishuman(user) || !is_portal_open())
		return NONE
	open_wearer_panel(user)
	return CLICK_ACTION_SUCCESS

/obj/item/clothing/sextoy/portal_fleshlight/update_appearance(updates = ALL)
	icon_state = is_link_valid() ? "paired" : "unpaired"
	return ..()

/obj/item/clothing/sextoy/portal_fleshlight/examine(mob/user)
	update_appearance()
	. = ..()
	if(!is_link_valid())
		. += span_notice("The status light is off. The device needs to be paired with portal panties.")
		return

	var/portal_open = is_portal_open()
	. += span_notice("The status light is [portal_open ? "on" : "off"]. The portal is [portal_open ? "open" : "closed"].")
	. += span_notice("The current target is set to: [current_target]")
	if(portal_open)
		. += span_notice("Use it on yourself, or Ctrl-Shift-click it from up to a tile away, to interact through the portal.")

/obj/item/clothing/sextoy/portal_fleshlight/attack_self(mob/user)
	. = ..()
	var/current_index = target_cycle.Find(current_target)
	current_target = target_cycle[(current_index % length(target_cycle)) + 1]
	to_chat(user, span_notice("Now targeting: [current_target]"))

/obj/item/clothing/sextoy/portal_fleshlight/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!ishuman(target_mob) || !ishuman(user))
		return ..()
	. = ..()
	if(.)
		return
	if(target_mob == user)
		open_wearer_panel(user)
		return TRUE

	var/local_target = user.zone_selected == BODY_ZONE_PRECISE_GROIN ? current_target : user.zone_selected
	var/list/options = available_interactions(user, target_mob, linked_panties, local_target, src)
	perform_interaction(user, target_mob, linked_panties, local_target, src, length(options) ? options[1] : null)
	return TRUE

/**
 * Routes a menu action on the receiver wearer's panel through this device, using the viewer's own part at this end.
 *
 * The viewer only needs to be able to reach the device, not hold it. When the viewer is the wearer, the receiver
 * end can also act as the interaction's user side, so they get every pairing a third party would, and its mirror.
 */
/obj/item/clothing/sextoy/portal_fleshlight/interaction_route_for(
	mob/living/carbon/human/represented,
	datum/interaction/interaction,
	mob/living/carbon/human/user,
)
	if(!interaction || !is_link_valid() || linked_panties.get_equipped_wearer() != represented || !can_reach_device(user))
		return null
	var/obj/item/clothing/sextoy/portal_panties/receiver = linked_panties
	var/list/local_targets = interaction_map[receiver.current_target]
	for(var/local_target in local_targets)
		if((interaction.name in local_targets[local_target]) && validate_interaction(interaction, user, user, receiver, local_target, src, ignore_cooldown = TRUE))
			return new /datum/interaction_route/portal_device(src, user, receiver, src, local_target)
	if(represented != user)
		return null
	for(var/local_target in interaction_map)
		if((interaction.name in interaction_map[local_target][receiver.current_target]) && validate_interaction(interaction, user, user, receiver, local_target, src, ignore_cooldown = TRUE, receiver_is_user = TRUE))
			return new /datum/interaction_route/portal_device(src, user, receiver, src, local_target, receiver_is_user = TRUE)
	return null

/obj/item/clothing/sextoy/portal_fleshlight/attackby(obj/item/used_item, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(istype(used_item, /obj/item/clothing/sextoy/portal_fleshlight))
		var/obj/item/clothing/sextoy/portal_fleshlight/active_device = used_item
		active_device.interact_with_device(src, user)
		return

	if(istype(used_item, /obj/item/clothing/sextoy/portal_panties))
		link_panties(used_item, user)
		return

/**
 * Offers every interaction between this device's receiver wearer and another device's, then performs the pick.
 *
 * The device in hand is the active side: its wearer is the interaction's user, and the other device's wearer its target.
 *
 * Arguments:
 * - passive_device: The device this one was used on.
 * - operator: Whoever is holding this device against the other.
 */
/obj/item/clothing/sextoy/portal_fleshlight/proc/interact_with_device(obj/item/clothing/sextoy/portal_fleshlight/passive_device, mob/living/carbon/human/operator)
	if(!is_portal_open() || !passive_device.is_portal_open())
		to_chat(operator, span_warning("Both portals need to be open to connect them."))
		return
	var/mob/living/carbon/human/active_wearer = linked_panties.get_equipped_wearer()
	var/active_part = linked_panties.current_target
	var/obj/item/clothing/sextoy/portal_panties/passive_receiver = passive_device.linked_panties
	var/list/options = list()
	for(var/datum/interaction/interaction as anything in available_interactions(operator, active_wearer, passive_receiver, active_part, passive_device))
		options[interaction.name] = interaction
	if(!length(options))
		to_chat(operator, span_warning("The portals cannot form a valid connection."))
		return
	var/choice = tgui_input_list(operator, "Pick an interaction between the two portals.", "Portal link", options)
	if(choice && !QDELETED(src) && !QDELETED(passive_device))
		perform_interaction(operator, active_wearer, passive_receiver, active_part, passive_device, options[choice])

/// Every mapped interaction this pairing could perform right now, default first. src is the device at the local end.
/obj/item/clothing/sextoy/portal_fleshlight/proc/available_interactions(
	mob/living/carbon/human/operator,
	mob/living/carbon/human/local_participant,
	obj/item/clothing/sextoy/portal_panties/receiver,
	local_target,
	obj/item/clothing/sextoy/portal_fleshlight/receiver_device,
)
	. = list()
	for(var/interaction_name in interaction_map[receiver?.current_target]?[local_target])
		var/datum/interaction/interaction = GLOB.interaction_instances[interaction_name]
		if(validate_interaction(interaction, operator, local_participant, receiver, local_target, receiver_device, ignore_cooldown = TRUE))
			. += interaction

/obj/item/clothing/sextoy/portal_fleshlight/proc/perform_interaction(
	mob/living/carbon/human/operator,
	mob/living/carbon/human/local_participant,
	obj/item/clothing/sextoy/portal_panties/receiver,
	local_target,
	obj/item/clothing/sextoy/portal_fleshlight/receiver_device,
	datum/interaction/interaction,
)
	// act() revalidates through the route before it does anything, so one check here is enough.
	var/mob/living/carbon/human/receiver_wearer = receiver?.get_equipped_wearer()
	if(!receiver_wearer || !validate_interaction(interaction, operator, local_participant, receiver, local_target, receiver_device))
		to_chat(operator, span_warning("The portal cannot form a valid connection for that interaction."))
		return FALSE

	if(!interaction.act(
		local_participant,
		receiver_wearer,
		use_subtler = TRUE,
		route = new /datum/interaction_route/portal_device(src, operator, receiver, receiver_device, local_target),
	))
		return FALSE

	apply_interaction_cooldown(local_participant, receiver_wearer)
	receiver_wearer.do_jitter_animation()
	return TRUE

/**
 * Returns whether interaction can still go through the portal with every precondition in place.
 *
 * The menu, a direct use, and the deferred effects all come through here, so anything that can change
 * mid-interaction (equipment, links, reach, preferences) is checked again every time.
 *
 * Arguments:
 * - interaction: The interaction to check. It must be the live definition mapped for the two parts.
 * - operator: Whoever is working the device. The same mob as local_participant unless they use it on someone else.
 * - local_participant: Whose part is at the device end.
 * - receiver: The worn receiver at the far end.
 * - local_target: The local participant's part in play.
 * - receiver_device: The device linked to receiver. When src is a different device, the local end is src's own receiver.
 * - ignore_cooldown: Skips the shared cooldown, for listing the menu and for effects the action already paid for.
 * - receiver_is_user: Whether the receiver supplies the interaction's user side part rather than its target side.
 */
/obj/item/clothing/sextoy/portal_fleshlight/proc/validate_interaction(
	datum/interaction/interaction,
	mob/living/carbon/human/operator,
	mob/living/carbon/human/local_participant,
	obj/item/clothing/sextoy/portal_panties/receiver,
	local_target,
	obj/item/clothing/sextoy/portal_fleshlight/receiver_device,
	ignore_cooldown = FALSE,
	receiver_is_user = FALSE,
)
	if(QDELETED(interaction) || QDELETED(src) || QDELETED(receiver_device) || QDELETED(receiver) || QDELETED(operator) || QDELETED(local_participant))
		return FALSE
	if(!ishuman(operator) || !ishuman(local_participant) || IS_UNCONSCIOUS_OR_CRIT(operator) || operator.incapacitated)
		return FALSE
	if(!receiver_device.can_reach_device(operator) || !receiver_device.is_link_valid() || receiver != receiver_device.linked_panties)
		return FALSE
	var/mob/living/carbon/human/receiver_wearer = receiver.get_equipped_wearer()
	if(!receiver_wearer || IS_UNCONSCIOUS_OR_CRIT(receiver_wearer) || receiver_wearer.incapacitated)
		return FALSE
	if(IS_UNCONSCIOUS_OR_CRIT(local_participant) || local_participant.incapacitated)
		return FALSE

	if(src == receiver_device)
		if(!operator.Adjacent(local_participant) || !local_participant.portal_target_is_accessible(local_target))
			return FALSE
	// Device to device: the local end is src's own receiver, which is never covered either.
	else if(!can_reach_device(operator) || !is_link_valid() || linked_panties.get_equipped_wearer() != local_participant || local_target != linked_panties.current_target)
		return FALSE

	if(receiver_is_user && local_participant != receiver_wearer)
		return FALSE
	if(!local_participant.allows_portal_use() || !receiver_wearer.allows_portal_use())
		return FALSE

	var/user_part = receiver_is_user ? receiver.current_target : local_target
	var/target_part = receiver_is_user ? local_target : receiver.current_target
	if(!(interaction.name in interaction_map[target_part]?[user_part]) || GLOB.interaction_instances[interaction.name] != interaction)
		return FALSE
	if(!interaction.lewd || interaction.category == INTERACTION_CAT_HIDE || interaction.usage != INTERACTION_OTHER)
		return FALSE
	// A mapped definition may only require the genitals at its own two ends.
	if(length(interaction.user_required_parts - user_part) || length(interaction.target_required_parts - target_part))
		return FALSE
	if(!interaction.allow_act(local_participant, receiver_wearer, allow_same_participant = TRUE, check_part_exposure = FALSE))
		return FALSE

	var/datum/component/interactable/local_component = local_participant.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/remote_component = receiver_wearer.GetComponent(/datum/component/interactable)
	if(!local_component || !remote_component)
		return FALSE
	return ignore_cooldown || !local_component.on_interaction_cooldown(remote_component)

/// Puts both participants on the interaction cooldown the menu UI uses.
/obj/item/clothing/sextoy/portal_fleshlight/proc/apply_interaction_cooldown(mob/living/carbon/human/local_participant, mob/living/carbon/human/receiver_wearer)
	var/datum/component/interactable/local_component = local_participant.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/remote_component = receiver_wearer.GetComponent(/datum/component/interactable)
	if(!local_component || !remote_component)
		return
	local_component.start_interaction_cooldown(remote_component)

/obj/item/clothing/sextoy/portal_fleshlight/proc/link_panties(obj/item/clothing/sextoy/portal_panties/panties, mob/living/user)
	if(!istype(panties) || QDELETED(panties))
		return FALSE

	if(is_link_valid() && linked_panties == panties)
		return TRUE
	if(panties.linked_fleshlight)
		to_chat(user, span_warning("[panties] is already linked to another portal fleshlight!"))
		return FALSE

	if(linked_panties)
		to_chat(user, span_warning("[src] is already linked to another pair of portal panties!"))
		return FALSE

	linked_panties = panties
	panties.linked_fleshlight = src

	playsound(src, 'sound/machines/ping.ogg', 50, FALSE)
	to_chat(user, span_notice("You link [src] to [panties]."))

	update_appearance()
	return TRUE

/obj/item/clothing/sextoy/portal_fleshlight/click_alt(mob/user)
	if(!is_link_valid())
		to_chat(user, span_warning("[src] isn't linked to any portal panties!"))
		return CLICK_ACTION_BLOCKING

	if(tgui_alert(user, "Are you sure you want to unlink the portal panties?", "Unlink Portal Panties", list("Yes", "No")) != "Yes" || QDELETED(src) || !user.Adjacent(src))
		return CLICK_ACTION_BLOCKING

	to_chat(user, span_notice("You unlink the portal panties from [src]."))
	clear_link()
	return CLICK_ACTION_SUCCESS

/// Silently and idempotently clears both peer references without deleting either item.
/obj/item/clothing/sextoy/portal_fleshlight/proc/clear_link()
	var/obj/item/clothing/sextoy/portal_panties/old_panties = linked_panties
	linked_panties = null
	if(old_panties?.linked_fleshlight == src)
		old_panties.linked_fleshlight = null
	if(!QDELETED(src))
		update_appearance()

/obj/item/clothing/sextoy/portal_fleshlight/proc/is_link_valid()
	return !QDELETED(linked_panties) && linked_panties.linked_fleshlight == src

/obj/item/clothing/sextoy/portal_fleshlight/Destroy(force)
	clear_link()
	return ..()

/obj/item/clothing/sextoy/portal_fleshlight/update_name(updates = ALL)
	. = ..()
	if(!is_portal_open())
		name = initial(name)
		return
	name = linked_panties.current_target == ORGAN_SLOT_PENIS ? "portal dildo" : "portal fleshlight"

/obj/item/clothing/sextoy/portal_fleshlight/update_overlays()
	. = ..()
	if(!is_portal_open())
		return

	var/mob/living/carbon/human/target_wearer = linked_panties.get_equipped_wearer()
	var/target_slot = linked_panties.current_target
	var/obj/item/organ/genital/target_organ = target_wearer.get_organ_slot(target_slot)

	// Stage every appearance before applying any of them. Unsupported variants stay blank.
	var/mutable_appearance/organ
	var/mutable_appearance/extra_overlay
	switch(target_slot)
		if(ORGAN_SLOT_VAGINA)
			var/obj/item/organ/genital/vagina/vagina = target_organ
			if(!istype(vagina))
				return
			var/datum/bodypart_overlay/mutant/genital/vagina/vagina_overlay = vagina.bodypart_overlay
			var/datum/sprite_accessory/genital/vagina_accessory = vagina_overlay?.sprite_datum
			if(!vagina_accessory)
				return
			organ = mutable_appearance(PORTAL_DEVICE_ICON, portal_vagina_states[vagina.get_genital_descriptor(vagina_accessory)] || "portal_vag")
			organ.color = portal_organ_color(vagina)
		if(ORGAN_SLOT_ANUS)
			if(!istype(target_organ, /obj/item/organ/genital/anus))
				return
			var/datum/bodypart_overlay/mutant/genital/anus_overlay = target_organ.bodypart_overlay
			var/datum/sprite_accessory/genital/anus_accessory = anus_overlay?.sprite_datum
			if(!anus_accessory || !(target_organ.get_genital_descriptor(anus_accessory) in portal_anus_descriptors))
				return
			organ = mutable_appearance(PORTAL_DEVICE_ICON, "portal_anus")
			organ.color = portal_organ_color(target_organ)
		if(ORGAN_SLOT_PENIS)
			var/obj/item/organ/genital/penis/penis = target_organ
			if(!istype(penis))
				return
			var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis.bodypart_overlay
			if(!penis_overlay?.sprite_datum || !penis.bodypart_owner)
				return
			var/portal_sprite_suffix = penis.get_sprite_size_string(minimum_sprite_affix = 4)
			var/current_suffix_token = "_[penis.sprite_suffix]_"
			var/portal_suffix_token = "_[portal_sprite_suffix]_"
			var/list/penis_appearances = list()
			for(var/mutable_appearance/penis_appearance as anything in penis_overlay.get_all_overlays(penis.bodypart_owner))
				var/mutable_appearance/portal_penis = make_mutable_appearance_directional(penis_appearance, WEST)
				portal_penis.icon_state = replacetext(portal_penis.icon_state, current_suffix_token, portal_suffix_token)
				if(portal_penis.icon && !icon_exists(portal_penis.icon, portal_penis.icon_state))
					continue
				penis_appearances += portal_penis
			// Seat everything by the first layer with art facing west, front layers first. A sheath's primary layer has none.
			var/list/portal_offset
			for(var/front_first in list(TRUE, FALSE))
				for(var/mutable_appearance/candidate as anything in penis_appearances)
					if(!portal_offset && candidate.icon && !!findtext(candidate.icon_state, "_FRONT_UNDER") == front_first)
						portal_offset = portal_penis_offset(candidate)
			if(!portal_offset)
				return
			for(var/mutable_appearance/portal_penis as anything in penis_appearances)
				portal_penis.layer = FLOAT_LAYER
				portal_penis.pixel_w += portal_offset[1]
				portal_penis.pixel_z += portal_offset[2]
				. += portal_penis
			return
		if(BODY_ZONE_PRECISE_MOUTH)
			extra_overlay = mutable_appearance(PORTAL_DEVICE_ICON, "portal_mouth")
			organ = mutable_appearance(PORTAL_DEVICE_ICON, "portal_mouth_lips")
			organ.color = target_wearer.lip_style == "lipstick" ? target_wearer.lip_color : portal_skin_color(target_wearer)

	if(!organ)
		return

	// The penis config sits proud of the device, so it's the only target without a sleeve around it.
	if(target_slot != ORGAN_SLOT_PENIS)
		var/mutable_appearance/sleeve = mutable_appearance(PORTAL_DEVICE_ICON, sleeve_state_for(target_wearer))
		sleeve.color = target_slot == ORGAN_SLOT_ANUS ? portal_organ_color(target_organ) : portal_skin_color(target_wearer)
		. += sleeve
	if(extra_overlay)
		. += extra_overlay
	. += organ

/// Seats a native WEST frame by the root that actually appears in its DMI state. Null when the frame is empty.
/obj/item/clothing/sextoy/portal_fleshlight/proc/portal_penis_offset(
	mutable_appearance/penis_appearance,
)
	var/static/list/cached_offsets = list()
	var/cache_key = "[penis_appearance.icon]#[penis_appearance.icon_state]#[penis_appearance.pixel_w]#[penis_appearance.pixel_z]"
	if(cache_key in cached_offsets)
		return cached_offsets[cache_key]
	cached_offsets[cache_key] = null

	var/icon/west_frame = icon(penis_appearance.icon, penis_appearance.icon_state, WEST)
	var/frame_width = west_frame.Width()
	var/frame_height = west_frame.Height()
	var/root_x = 0
	for(var/x in 1 to frame_width)
		for(var/y in 1 to frame_height)
			if(west_frame.GetPixel(x, y))
				root_x = x
	if(!root_x)
		return null

	var/list/root_rows = list()
	for(var/edge_x in max(1, root_x - 1) to root_x)
		for(var/edge_y in 1 to frame_height)
			if(west_frame.GetPixel(edge_x, edge_y))
				root_rows += edge_y
	sortTim(root_rows, GLOBAL_PROC_REF(cmp_numeric_dsc))
	var/root_y = root_rows[floor(length(root_rows) / 2) + 1]

	var/pixel_w = 12 - (penis_appearance.pixel_w + root_x)
	var/pixel_z = 16 - (penis_appearance.pixel_z + root_y)

	var/list/offset = list(pixel_w, pixel_z)
	cached_offsets[cache_key] = offset
	return offset

/// Picks the sleeve that suits the receiver's species.
/obj/item/clothing/sextoy/portal_fleshlight/proc/sleeve_state_for(mob/living/carbon/human/target_wearer)
	if(islizard(target_wearer) || isunathi(target_wearer))
		return "portal_sleeve_lizard"
	if(isakula(target_wearer))
		return "portal_sleeve_akula"
	if(isslimeperson(target_wearer))
		return "portal_sleeve_slime"
	if(ismammal(target_wearer) || isvulpkanin(target_wearer) || istajaran(target_wearer) || isteshari(target_wearer) || isvox(target_wearer))
		return "portal_sleeve_fluff"
	return "portal_sleeve_normal"

/// Resolves the current genital overlay colour without relying on removed organ fields.
/obj/item/clothing/sextoy/portal_fleshlight/proc/portal_organ_color(obj/item/organ/genital/genital)
	var/datum/bodypart_overlay/mutant/genital/organ_overlay = genital?.bodypart_overlay
	if(!organ_overlay || !genital.bodypart_owner)
		return null
	organ_overlay.inherit_color(genital.bodypart_owner)
	return first_portal_color(organ_overlay.draw_color)

/// Uses the chest bodypart's rendered colour as the current skin-colour source.
/obj/item/clothing/sextoy/portal_fleshlight/proc/portal_skin_color(mob/living/carbon/human/human)
	var/obj/item/bodypart/chest = human?.get_bodypart(BODY_ZONE_CHEST)
	return first_portal_color(chest?.draw_color)

/// Matrixed draw colors use their first entry for portal art.
/obj/item/clothing/sextoy/portal_fleshlight/proc/first_portal_color(color_source)
	if(!islist(color_source))
		return color_source
	var/list/color_list = color_source
	return length(color_list) ? color_list[1] : null

/obj/item/clothing/sextoy/portal_fleshlight/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return .

	anonymous = !anonymous
	playsound(src, 'sound/machines/ping.ogg', 50, FALSE)
	balloon_alert(user, "anonymous mode: [anonymous ? "ON" : "OFF"]")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

#undef PORTAL_DEVICE_ICON
