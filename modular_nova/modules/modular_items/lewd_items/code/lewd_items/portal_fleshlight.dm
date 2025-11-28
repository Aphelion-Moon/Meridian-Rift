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

	/// Live-config interaction names, indexed by target-side and then user-side endpoint.
	var/static/list/interaction_map = list(
		ORGAN_SLOT_VAGINA = list(
			ORGAN_SLOT_PENIS = "Fuck (vagina)",
			ORGAN_SLOT_VAGINA = "Tribadism",
			BODY_ZONE_PRECISE_MOUTH = "Lick vagina",
			BODY_ZONE_R_ARM = "Finger (vagina)",
			BODY_ZONE_L_ARM = "Finger (vagina)",
			BODY_ZONE_R_LEG = "Footjob (vagina)",
			BODY_ZONE_L_LEG = "Footjob (vagina)",
		),
		ORGAN_SLOT_ANUS = list(
			ORGAN_SLOT_PENIS = "Ass fuck",
			BODY_ZONE_PRECISE_MOUTH = "Eat ass",
			BODY_ZONE_R_ARM = "Finger (ass)",
			BODY_ZONE_L_ARM = "Finger (ass)",
		),
		ORGAN_SLOT_PENIS = list(
			ORGAN_SLOT_PENIS = "Frot",
			ORGAN_SLOT_VAGINA = "Ride cock (vagina)",
			ORGAN_SLOT_ANUS = "Ride cock (ass)",
			BODY_ZONE_PRECISE_MOUTH = "Blowjob",
			BODY_ZONE_R_ARM = "Handjob",
			BODY_ZONE_L_ARM = "Handjob",
			BODY_ZONE_R_LEG = "Footjob (cock)",
			BODY_ZONE_L_LEG = "Footjob (cock)",
		),
		BODY_ZONE_PRECISE_MOUTH = list(
			ORGAN_SLOT_PENIS = "Mouth fuck",
			BODY_ZONE_PRECISE_MOUTH = "Tongue kiss",
		),
	)
	var/static/list/target_cycle = list(
		ORGAN_SLOT_PENIS,
		ORGAN_SLOT_VAGINA,
		ORGAN_SLOT_ANUS,
		BODY_ZONE_PRECISE_MOUTH,
	)

	/// Device icon state per genital descriptor. A descriptor with no entry has no art, and renders nothing.
	var/static/list/portal_vagina_states = list(
		"Human" = "portal_vag",
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
		return CONTEXTUAL_SCREENTIP_SET

	if(istype(held_item, /obj/item/clothing/sextoy/portal_panties))
		context[SCREENTIP_CONTEXT_LMB] = "Link panties"
		return CONTEXTUAL_SCREENTIP_SET

	if(linked_panties?.loc && ishuman(linked_panties.loc))
		context[SCREENTIP_CONTEXT_LMB] = "Use on target"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/// TRUE when the far end is worn, configured and exposed — i.e. the portal would actually go through right now.
/obj/item/clothing/sextoy/portal_fleshlight/proc/is_portal_open()
	return is_link_valid() && linked_panties.receiver_configuration_valid()

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
		var/datum/component/interactable/interaction_component = target_mob.GetComponent(/datum/component/interactable)
		interaction_component?.open_interaction_menu(target_mob, user)
		return TRUE

	var/local_target = user.zone_selected == BODY_ZONE_PRECISE_GROIN ? current_target : user.zone_selected
	perform_interaction(user, target_mob, linked_panties, local_target, src)
	return TRUE

/// Routes matching menu actions through the receiver when its wearer uses the device on themselves.
/obj/item/clothing/sextoy/portal_fleshlight/interaction_route_for(
	mob/living/carbon/human/represented,
	datum/interaction/interaction,
	mob/living/carbon/human/user,
)
	if(represented != user || user.get_active_held_item() != src || !interaction || !is_link_valid())
		return null
	var/obj/item/clothing/sextoy/portal_panties/receiver = linked_panties
	if(receiver.get_equipped_wearer() != represented)
		return null
	var/list/local_targets = interaction_map[receiver.current_target]
	for(var/local_target in local_targets)
		if(local_targets[local_target] != interaction.name)
			continue
		if(validate_interaction(user, represented, receiver, local_target, src, ignore_cooldown = TRUE) != interaction)
			continue
		return new /datum/interaction_route/portal_device(src, user, receiver, src, local_target)
	// The same wearer can also use the receiver end as the interaction's active part.
	for(var/local_target in interaction_map)
		if(interaction_map[local_target]?[receiver.current_target] != interaction.name)
			continue
		if(validate_interaction(user, represented, receiver, local_target, src, ignore_cooldown = TRUE, receiver_is_user = TRUE) != interaction)
			continue
		return new /datum/interaction_route/portal_device(src, user, receiver, src, local_target, receiver_is_user = TRUE)
	return null

/obj/item/clothing/sextoy/portal_fleshlight/attackby(obj/item/used_item, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(istype(used_item, /obj/item/clothing/sextoy/portal_fleshlight))
		var/obj/item/clothing/sextoy/portal_fleshlight/held_device = used_item
		var/mob/living/carbon/human/local_participant = linked_panties?.get_equipped_wearer()
		perform_interaction(user, local_participant, held_device.linked_panties, linked_panties?.current_target, held_device)
		return

	if(istype(used_item, /obj/item/clothing/sextoy/portal_panties))
		link_panties(used_item, user)
		return

/obj/item/clothing/sextoy/portal_fleshlight/proc/perform_interaction(
	mob/living/carbon/human/operator,
	mob/living/carbon/human/local_participant,
	obj/item/clothing/sextoy/portal_panties/receiver,
	local_target,
	obj/item/clothing/sextoy/portal_fleshlight/held_device,
)
	// act() revalidates through the route before it does anything, so one check here is enough.
	var/datum/interaction/interaction = validate_interaction(operator, local_participant, receiver, local_target, held_device)
	var/mob/living/carbon/human/receiver_wearer = receiver?.get_equipped_wearer()
	if(!interaction || !receiver_wearer)
		to_chat(operator, span_warning("The portal cannot form a valid connection for that interaction."))
		return FALSE

	if(!interaction.act(
		local_participant,
		receiver_wearer,
		use_subtler = TRUE,
		route = new /datum/interaction_route/portal_device(src, operator, receiver, held_device, local_target),
	))
		return FALSE

	apply_interaction_cooldown(local_participant, receiver_wearer)
	receiver_wearer.do_jitter_animation()
	return TRUE

/// Returns the configured interaction only while every authoritative precondition still holds.
/obj/item/clothing/sextoy/portal_fleshlight/proc/validate_interaction(
	mob/living/carbon/human/operator,
	mob/living/carbon/human/local_participant,
	obj/item/clothing/sextoy/portal_panties/receiver,
	local_target,
	obj/item/clothing/sextoy/portal_fleshlight/held_device,
	ignore_cooldown = FALSE,
	receiver_is_user = FALSE,
)
	if(QDELETED(src) || QDELETED(held_device) || QDELETED(receiver))
		return null
	if(!ishuman(operator) || !ishuman(local_participant) || IS_UNCONSCIOUS_OR_CRIT(operator) || operator.incapacitated)
		return null
	if(!(held_device in operator.held_items) || !operator.can_perform_action(held_device, NEED_DEXTERITY | NEED_HANDS | ALLOW_RESTING))
		return null
	if(!held_device.is_link_valid() || receiver != held_device.linked_panties)
		return null
	if(QDELETED(local_participant) || IS_UNCONSCIOUS_OR_CRIT(local_participant) || local_participant.incapacitated)
		return null

	if(src == held_device)
		if(!operator.Adjacent(local_participant))
			return null
	else
		if(!operator.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | ALLOW_RESTING))
			return null
		if(!is_link_valid() || linked_panties.get_equipped_wearer() != local_participant || !linked_panties.receiver_configuration_valid())
			return null
		if(local_target != linked_panties.current_target)
			return null

	var/mob/living/carbon/human/receiver_wearer = receiver.get_equipped_wearer()
	if(!receiver_wearer || IS_UNCONSCIOUS_OR_CRIT(receiver_wearer) || receiver_wearer.incapacitated || !receiver.receiver_configuration_valid())
		return null
	if(receiver_is_user && local_participant != receiver_wearer)
		return null
	if(local_participant == receiver_wearer && operator != local_participant)
		return null
	if(!local_participant.allows_portal_use() || !receiver_wearer.allows_portal_use())
		return null
	if(!local_participant.portal_target_is_accessible(local_target))
		return null

	var/interaction_user_part = receiver_is_user ? receiver.current_target : local_target
	var/interaction_target_part = receiver_is_user ? local_target : receiver.current_target
	var/interaction_name = interaction_map[interaction_target_part]?[interaction_user_part]
	var/datum/interaction/interaction = GLOB.interaction_instances[interaction_name]
	if(!interaction_name || !interaction || !interaction.lewd || interaction.category == INTERACTION_CAT_HIDE || interaction.usage != INTERACTION_OTHER)
		return null
	var/list/expected_user_parts = (interaction_user_part in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS)) ? list(interaction_user_part) : list()
	var/list/expected_target_parts = (interaction_target_part in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS)) ? list(interaction_target_part) : list()
	if(!deep_compare_list(interaction.user_required_parts, expected_user_parts) || !deep_compare_list(interaction.target_required_parts, expected_target_parts))
		return null
	if(!interaction.allow_act(
		local_participant,
		receiver_wearer,
		allow_same_participant = TRUE,
		check_part_exposure = FALSE,
	))
		return null

	var/datum/component/interactable/local_component = local_participant.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/remote_component = receiver_wearer.GetComponent(/datum/component/interactable)
	if(!local_component || !remote_component)
		return null
	if(!ignore_cooldown && local_component.on_interaction_cooldown(remote_component))
		return null
	return interaction

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

	var/datum/weakref/panties_ref = WEAKREF(linked_panties)
	var/choice = tgui_alert(user, "Are you sure you want to unlink the portal panties?", "Unlink Portal Panties", list("Yes", "No"))
	if(choice != "Yes")
		return CLICK_ACTION_BLOCKING
	var/obj/item/clothing/sextoy/portal_panties/panties = panties_ref.resolve()
	if(QDELETED(src) || QDELETED(panties) || linked_panties != panties || panties.linked_fleshlight != src || !(src in user.held_items))
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
			var/vagina_state = portal_vagina_states[vagina.get_genital_descriptor(vagina_accessory)]
			if(!vagina_state)
				return
			organ = mutable_appearance(PORTAL_DEVICE_ICON, vagina_state)
			organ.color = portal_organ_color(vagina)
			if(vagina.aroused == AROUSAL_FULL)
				extra_overlay = mutable_appearance(PORTAL_DEVICE_ICON, "portal_vag_drip")
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
			var/datum/sprite_accessory/genital/penis/shaft = penis_overlay?.shaft_datum || penis_overlay?.sprite_datum
			if(!shaft || !penis.bodypart_owner || penis.is_sheathed())
				return
			var/portal_sprite_suffix = penis.get_sprite_size_string(minimum_sprite_affix = 4)
			var/current_suffix_token = "_[penis.sprite_suffix]_"
			var/portal_suffix_token = "_[portal_sprite_suffix]_"
			var/list/penis_appearances = list()
			var/mutable_appearance/alignment_appearance
			for(var/mutable_appearance/penis_appearance as anything in penis_overlay.get_all_overlays(penis.bodypart_owner))
				var/mutable_appearance/portal_penis = make_mutable_appearance_directional(penis_appearance, WEST)
				portal_penis.icon_state = replacetext(portal_penis.icon_state, current_suffix_token, portal_suffix_token)
				if(portal_penis.icon && !icon_exists(portal_penis.icon, portal_penis.icon_state))
					continue
				penis_appearances += portal_penis
				if(portal_penis.icon && (isnull(alignment_appearance) || (!findtext(alignment_appearance.icon_state, "_FRONT_UNDER") && findtext(portal_penis.icon_state, "_FRONT_UNDER"))))
					alignment_appearance = portal_penis
			if(!alignment_appearance)
				return
			var/list/portal_offset = portal_penis_offset(alignment_appearance)
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

/// Seats a native WEST frame by the root that actually appears in its DMI state.
/obj/item/clothing/sextoy/portal_fleshlight/proc/portal_penis_offset(
	mutable_appearance/penis_appearance,
)
	var/static/list/cached_offsets = list()
	var/cache_key = "[penis_appearance.icon]#[penis_appearance.icon_state]#[penis_appearance.pixel_w]#[penis_appearance.pixel_z]"
	if(cached_offsets[cache_key])
		return cached_offsets[cache_key]

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
	if(!length(root_rows))
		return null
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
