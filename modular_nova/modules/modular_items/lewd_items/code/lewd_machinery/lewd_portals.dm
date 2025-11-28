#define GLORYHOLE "gloryhole"
#define WALLSTUCK "wallstuck"
#define PORTAL_ICON 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_structures/lewd_portals.dmi'

/// Appearance changes on the occupant which mean the relay has to be re-rendered.
GLOBAL_LIST_INIT(portal_visual_signals, list(
	COMSIG_MOB_EQUIPPED_ITEM,
	COMSIG_MOB_UNEQUIPPED_ITEM,
	COMSIG_CARBON_APPLY_OVERLAY,
	COMSIG_CARBON_REMOVE_OVERLAY,
	COMSIG_HUMAN_GENITAL_UPDATED,
))

/obj/structure/lewd_portal
	name = "LustWish Portal"
	desc = "A portal that people can partially fit through."
	icon = PORTAL_ICON
	icon_state = "portal"
	can_buckle = TRUE
	anchored = TRUE
	max_buckled_mobs = 1
	buckle_lying = 0
	buckle_prevents_pull = TRUE
	/// Human currently occupying this endpoint. Borrowed; never deleted by the portal.
	var/mob/living/carbon/human/current_mob
	/// Portal mode, gloryhole for crotch, wallstuck for lower body.
	var/portal_mode = GLORYHOLE
	/// The other endpoint. A portal pair owns both of its endpoints.
	var/obj/structure/lewd_portal/linked_portal
	/// The body relay exclusively owned by this endpoint's active session.
	var/obj/effect/lewd_portal_relay/relayed_body
	/// Prevents teardown callbacks from re-entering session cleanup.
	var/ending_session = FALSE
	/// Prevents overlay signals caused by our own render pass from recursing.
	var/refreshing_current_mob = FALSE
	/// Whether the active occupant has our appearance invalidation signals registered.
	var/current_mob_visual_signals_registered = FALSE
	/// Coalesces the several overlay signals emitted by one appearance rebuild.
	var/current_mob_visual_refresh_queued = FALSE
	/// Direction to restore when the session ends.
	var/initial_mob_dir
	/// Exact transform copy to restore when the session ends.
	var/matrix/initial_mob_transform
	/// Exact pixel offsets to restore when the session ends.
	var/initial_mob_pixel_x
	var/initial_mob_pixel_y
	/// Visible overlays outside `overlays_standing`, which the normal update procs cannot rebuild.
	var/list/initial_mob_overlays
	/// How far a head is offset while stuck through this portal.
	var/wallstuck_offset_amount = 12

/obj/structure/lewd_portal/Initialize(mapload)
	LAZYINITLIST(buckled_mobs)
	. = ..()
	register_context()

/obj/structure/lewd_portal/Destroy()
	end_session()

	var/obj/structure/lewd_portal/portal_to_delete = linked_portal
	linked_portal = null
	if(portal_to_delete?.linked_portal == src)
		portal_to_delete.linked_portal = null
	if(!QDELETED(portal_to_delete))
		portal_to_delete.end_session()
		qdel(portal_to_delete)

	return ..()

/obj/structure/lewd_portal/examine(mob/user)
	. = ..()
	var/inspect_mode = portal_mode == WALLSTUCK ? "stuck in wall" : "gloryhole"
	. += span_notice("It is currently in [inspect_mode] mode.")
	. += span_notice("Right click to change modes.")

/obj/structure/lewd_portal/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	if(portal_mode == GLORYHOLE)
		context[SCREENTIP_CONTEXT_RMB] = "Stuck In Wall Mode"
	else
		context[SCREENTIP_CONTEXT_RMB] = "Gloryhole Mode"
	return CONTEXTUAL_SCREENTIP_SET

/obj/structure/lewd_portal/user_buckle_mob(mob/living/target, mob/user, check_loc)
	if(!ishuman(target))
		balloon_alert(user, "[target.p_they()] does not fit!")
		return FALSE

	var/mob/living/carbon/human/human_target = target
	if(!human_target.check_erp_prefs(/datum/preference/toggle/erp/sex_toy, user, src))
		to_chat(user, span_danger("Looks like [human_target] doesn't want you to do that."))
		return FALSE
	if(!is_valid_pair())
		balloon_alert(user, "portal not linked!")
		return FALSE
	if(current_mob || linked_portal.current_mob)
		balloon_alert(user, "portal already occupied!")
		return FALSE
	if(!can_relay(human_target))
		if(portal_mode == GLORYHOLE)
			balloon_alert(user, "an exposed penis is required!")
		else
			balloon_alert(user, "their body cannot fit!")
		return FALSE

	return ..(human_target, user, check_loc = FALSE)

/// Revalidates and creates the relay after the public buckle delay.
/obj/structure/lewd_portal/buckle_mob(mob/living/target, force = FALSE, check_loc = TRUE)
	if(!ishuman(target))
		return FALSE

	var/mob/living/carbon/human/human_target = target
	// Consent may have changed during the public buckle delay.
	if(!force && !human_target.allows_portal_use())
		return FALSE
	if(!is_valid_pair() || current_mob || linked_portal.current_mob || !can_relay(human_target))
		return FALSE
	if(!is_buckle_possible(human_target, force, check_loc))
		return FALSE
	if(!begin_session(human_target))
		return FALSE

	. = ..()
	if(!.)
		end_session()

/obj/structure/lewd_portal/post_buckle_mob(mob/living/buckled_mob)
	. = ..()
	if(buckled_mob != current_mob || !relayed_body)
		return

	position_relay()
	if(!apply_current_mob_visuals())
		return
	RegisterSignals(current_mob, GLOB.portal_visual_signals, PROC_REF(on_current_mob_visual_changed))
	current_mob_visual_signals_registered = TRUE

/obj/structure/lewd_portal/post_unbuckle_mob(mob/living/unbuckled_mob)
	. = ..()
	if(unbuckled_mob == current_mob)
		end_session()

/// Returns TRUE when both endpoints still form the same live reciprocal pair.
/obj/structure/lewd_portal/proc/is_valid_pair()
	return !QDELETED(linked_portal) && linked_portal.linked_portal == src

/// Returns TRUE only while the supplied mob and relay are this endpoint's complete active session.
/obj/structure/lewd_portal/proc/is_active_session(mob/living/carbon/human/candidate, obj/effect/lewd_portal_relay/candidate_relay)
	if(QDELETED(candidate) || QDELETED(candidate_relay) || !is_valid_pair())
		return FALSE
	if(current_mob != candidate || relayed_body != candidate_relay || candidate.buckled != src || candidate_relay.owner != candidate)
		return FALSE
	var/datum/component/interactable/interact_component = candidate.GetComponent(/datum/component/interactable)
	return interact_component?.resolve_body_relay() == candidate_relay

/// Whether candidate has everything we need to draw the current portal mode.
/obj/structure/lewd_portal/proc/can_relay(mob/living/carbon/human/candidate)
	if(QDELETED(candidate) || !candidate.dna?.species)
		return FALSE
	if(portal_mode == GLORYHOLE)
		var/obj/item/organ/genital/penis/penis = candidate.get_organ_slot(ORGAN_SLOT_PENIS)
		var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis?.bodypart_overlay
		return candidate.has_penis(REQUIRE_GENITAL_EXPOSED) && penis.bodypart_owner && penis_overlay?.sprite_datum
	return istype(candidate.get_bodypart(BODY_ZONE_HEAD), /obj/item/bodypart/head)

/// Captures all mob state that this portal changes.
/obj/structure/lewd_portal/proc/snapshot_current_mob(mob/living/carbon/human/candidate)
	initial_mob_dir = candidate.dir
	initial_mob_transform = matrix(candidate.transform)
	initial_mob_pixel_x = candidate.pixel_x
	initial_mob_pixel_y = candidate.pixel_y
	initial_mob_overlays = candidate.overlays.Copy()
	for(var/image/cached_overlay as anything in candidate.get_overlays_copy(list()))
		while(cached_overlay.appearance in initial_mob_overlays)
			initial_mob_overlays -= cached_overlay.appearance

	var/datum/decompose_matrix/scale_manager = initial_mob_transform.decompose()
	var/transform_scale_height = scale_manager.scale_y
	if(transform_scale_height <= 1)
		wallstuck_offset_amount = (-30 * transform_scale_height) + 42
	else
		wallstuck_offset_amount = (-24 * transform_scale_height) + 36
	wallstuck_offset_amount = clamp(round(wallstuck_offset_amount), 0, 18)

/// Starts ownership tracking and creates a fully rendered relay.
/obj/structure/lewd_portal/proc/begin_session(mob/living/carbon/human/candidate)
	snapshot_current_mob(candidate)
	set_current_mob(candidate)

	var/obj/effect/lewd_portal_relay/new_relay = new(linked_portal.loc, candidate, linked_portal)
	if(QDELETED(new_relay) || !new_relay.owner)
		if(!QDELETED(new_relay))
			qdel(new_relay)
		end_session()
		return FALSE

	set_relayed_body(new_relay)
	return TRUE

/// Setter for the borrowed occupant reference and its deletion signal.
/obj/structure/lewd_portal/proc/set_current_mob(mob/living/carbon/human/new_current_mob)
	if(current_mob == new_current_mob)
		return
	if(current_mob)
		UnregisterSignal(current_mob, COMSIG_QDELETING)
	current_mob = new_current_mob
	if(current_mob)
		RegisterSignal(current_mob, COMSIG_QDELETING, PROC_REF(on_current_mob_qdeleting))

/// Setter for the owned relay reference and its deletion signal.
/obj/structure/lewd_portal/proc/set_relayed_body(obj/effect/lewd_portal_relay/new_relay)
	if(relayed_body == new_relay)
		return
	if(relayed_body)
		UnregisterSignal(relayed_body, COMSIG_QDELETING)
	relayed_body = new_relay
	if(relayed_body)
		RegisterSignal(relayed_body, COMSIG_QDELETING, PROC_REF(on_relay_qdeleting))

/obj/structure/lewd_portal/proc/on_current_mob_qdeleting(datum/source)
	SIGNAL_HANDLER
	if(source == current_mob)
		end_session()

/obj/structure/lewd_portal/proc/on_relay_qdeleting(datum/source)
	SIGNAL_HANDLER
	if(source == relayed_body)
		end_session()

/// Signal handler which keeps the displayed body section constrained to this portal's mode.
/obj/structure/lewd_portal/proc/on_current_mob_visual_changed()
	SIGNAL_HANDLER
	if(current_mob_visual_refresh_queued || ending_session || QDELETED(current_mob))
		return
	// The queued flag is the uniqueness guard; this just defers us past the rest of the rebuild.
	current_mob_visual_refresh_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(flush_current_mob_visual_refresh)), 0)

/// Performs one render pass after a complete equipment/body overlay rebuild.
/obj/structure/lewd_portal/proc/flush_current_mob_visual_refresh()
	if(!current_mob_visual_refresh_queued)
		return
	apply_current_mob_visuals()
	current_mob_visual_refresh_queued = FALSE

/// Applies the active mode without permanently changing genital preferences.
/obj/structure/lewd_portal/proc/apply_current_mob_visuals()
	if(refreshing_current_mob || ending_session || QDELETED(current_mob))
		return FALSE
	refreshing_current_mob = TRUE
	if(!can_relay(current_mob))
		refreshing_current_mob = FALSE
		end_session()
		return FALSE

	if(portal_mode == GLORYHOLE)
		var/obj/item/organ/genital/penis/affected_penis = current_mob.get_organ_slot(ORGAN_SLOT_PENIS)
		if(affected_penis)
			var/old_visibility = affected_penis.visibility_preference
			affected_penis.visibility_preference = GENITAL_NEVER_SHOW
			current_mob.update_body()
			if(!QDELETED(affected_penis))
				affected_penis.visibility_preference = old_visibility
		current_mob.setDir(dir)
		current_mob.transform = matrix(initial_mob_transform)
		current_mob.pixel_x = initial_mob_pixel_x
		current_mob.pixel_y = initial_mob_pixel_y
		switch(dir)
			if(NORTH)
				current_mob.pixel_y += 24
			if(SOUTH)
				current_mob.pixel_y -= 6
			if(EAST)
				current_mob.pixel_x += 12
			if(WEST)
				current_mob.pixel_x -= 12
	else
		current_mob.setDir(SOUTH)
		current_mob.transform = matrix(initial_mob_transform)
		current_mob.pixel_x = initial_mob_pixel_x
		current_mob.pixel_y = initial_mob_pixel_y
		current_mob.render_only_head()
		switch(dir)
			if(NORTH)
				current_mob.pixel_y += wallstuck_offset_amount
			if(SOUTH)
				current_mob.pixel_y -= wallstuck_offset_amount
				current_mob.transform = turn(current_mob.transform, ROTATION_FLIP)
			if(EAST)
				current_mob.pixel_x += wallstuck_offset_amount
				current_mob.transform = turn(current_mob.transform, ROTATION_COUNTERCLOCKWISE)
			if(WEST)
				current_mob.pixel_x -= wallstuck_offset_amount
				current_mob.transform = turn(current_mob.transform, ROTATION_CLOCKWISE)

	var/relay_rendered = !QDELETED(relayed_body) && relayed_body.update_visuals()
	refreshing_current_mob = FALSE
	if(!relay_rendered)
		end_session()
	return relay_rendered

/// Positions the relay using the occupant's original scale and the receiving endpoint's direction.
/obj/structure/lewd_portal/proc/position_relay()
	if(QDELETED(relayed_body) || !initial_mob_transform)
		return
	var/datum/decompose_matrix/scale_manager = initial_mob_transform.decompose()
	relayed_body.transform = relayed_body.transform.Scale(scale_manager.scale_x, scale_manager.scale_y)
	switch(linked_portal.dir)
		if(NORTH)
			relayed_body.pixel_y = 24
			if(portal_mode == GLORYHOLE)
				relayed_body.pixel_y += 3
		if(SOUTH)
			relayed_body.pixel_y = -24
			relayed_body.transform = turn(relayed_body.transform, ROTATION_FLIP)
			if(portal_mode == GLORYHOLE)
				relayed_body.pixel_y -= 3
		if(EAST)
			relayed_body.pixel_x = 24
			if(portal_mode == WALLSTUCK)
				relayed_body.transform = turn(relayed_body.transform, ROTATION_COUNTERCLOCKWISE)
			else
				relayed_body.pixel_y = 7
		if(WEST)
			relayed_body.pixel_x = -24
			if(portal_mode == WALLSTUCK)
				relayed_body.transform = turn(relayed_body.transform, ROTATION_CLOCKWISE)
			else
				relayed_body.pixel_y = 7

/// Ends the session, deleting its relay and restoring its borrowed mob.
/obj/structure/lewd_portal/proc/end_session()
	if(ending_session)
		return
	ending_session = TRUE

	var/mob/living/carbon/human/session_mob = current_mob
	var/obj/effect/lewd_portal_relay/session_relay = relayed_body

	if(session_mob && current_mob_visual_signals_registered)
		UnregisterSignal(session_mob, GLOB.portal_visual_signals)
	current_mob_visual_signals_registered = FALSE
	current_mob_visual_refresh_queued = FALSE

	if(session_relay)
		UnregisterSignal(session_relay, COMSIG_QDELETING)
		var/datum/component/interactable/interact_component = session_mob?.GetComponent(/datum/component/interactable)
		interact_component?.clear_body_relay(session_relay)
	relayed_body = null
	if(!QDELETED(session_relay))
		qdel(session_relay)

	set_current_mob(null)

	if(!QDELETED(session_mob))
		if(session_mob.buckled == src)
			unbuckle_mob(session_mob, force = TRUE, can_fall = FALSE)
		restore_current_mob(session_mob)

	clear_session_snapshot()
	ending_session = FALSE

/// Restores only the borrowed mob; it never transfers or deletes ownership.
/obj/structure/lewd_portal/proc/restore_current_mob(mob/living/carbon/human/session_mob)
	session_mob.cut_overlays()
	session_mob.regenerate_icons()
	session_mob.add_overlay(initial_mob_overlays)
	session_mob.setDir(initial_mob_dir)
	session_mob.transform = matrix(initial_mob_transform)
	session_mob.pixel_x = initial_mob_pixel_x
	session_mob.pixel_y = initial_mob_pixel_y

/obj/structure/lewd_portal/proc/clear_session_snapshot()
	initial_mob_dir = null
	initial_mob_transform = null
	initial_mob_pixel_x = null
	initial_mob_pixel_y = null
	initial_mob_overlays = null
	wallstuck_offset_amount = 12
	refreshing_current_mob = FALSE
	current_mob_visual_refresh_queued = FALSE

/obj/structure/lewd_portal/wrench_act_secondary(mob/living/user, obj/item/weapon)
	..()
	weapon.play_tool_sound(src)
	deconstruct(disassembled = TRUE)
	return TRUE

/obj/structure/lewd_portal/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return
	if(!is_valid_pair())
		balloon_alert(user, "portal not linked")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	if(current_mob || linked_portal.current_mob)
		balloon_alert(user, "portal occupied")
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	if(portal_mode == GLORYHOLE)
		portal_mode = WALLSTUCK
		linked_portal.portal_mode = WALLSTUCK
		balloon_alert(user, "switched to stuck in wall mode")
	else
		portal_mode = GLORYHOLE
		linked_portal.portal_mode = GLORYHOLE
		balloon_alert(user, "switched to gloryhole mode")
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN


/obj/item/wallframe/lewd_portal
	name = "LustWish Portal Bore"
	desc = "A device utilizing bluespace technology to transpose portions of people from one space to another."
	icon = PORTAL_ICON
	icon_state = "device"
	result_path = /obj/structure/lewd_portal
	pixel_shift = 32
	requires_floor = FALSE
	consume_after_attach = FALSE
	/// The mode portals created by this device will be in.
	var/creation_mode = GLORYHOLE
	/// Endpoints owned by this bore. Either endpoint deleting clears the pair.
	var/obj/structure/lewd_portal/first_portal
	var/obj/structure/lewd_portal/second_portal

/obj/item/wallframe/lewd_portal/Destroy()
	clear_portals()
	return ..()

/obj/item/wallframe/lewd_portal/examine(mob/user)
	. = ..()
	var/inspect_mode = creation_mode == WALLSTUCK ? "stuck in wall" : "gloryhole"
	. += span_notice("It is currently in [inspect_mode] mode.")
	if(first_portal)
		. += span_notice(second_portal ? "Use in hand to collapse its portals." : "Use in hand to remove its staged portal.")
	else
		. += span_notice("Use in hand to change modes.")

/obj/item/wallframe/lewd_portal/try_build(atom/support, mob/user)
	if(first_portal && second_portal)
		balloon_alert(user, "remove existing portals first!")
		return FALSE
	return ..()

/obj/item/wallframe/lewd_portal/after_attach(obj/attached_to)
	. = ..()
	var/obj/structure/lewd_portal/portal_result = attached_to
	if(!istype(portal_result))
		return
	portal_result.portal_mode = creation_mode

	if(isnull(first_portal))
		first_portal = portal_result
		RegisterSignal(first_portal, COMSIG_QDELETING, PROC_REF(on_portal_qdeleting))
		return

	second_portal = portal_result
	RegisterSignal(second_portal, COMSIG_QDELETING, PROC_REF(on_portal_qdeleting))
	portal_result.linked_portal = first_portal
	first_portal.linked_portal = portal_result

/obj/item/wallframe/lewd_portal/attack_self(mob/user)
	if(first_portal || second_portal)
		clear_portals()
		balloon_alert(user, "portals collapsed")
		return

	if(creation_mode == GLORYHOLE)
		creation_mode = WALLSTUCK
		balloon_alert(user, "switched to stuck in wall mode")
	else
		creation_mode = GLORYHOLE
		balloon_alert(user, "switched to gloryhole mode")

/// Drops our references before deleting either endpoint, so reciprocal teardown cannot re-enter us.
/obj/item/wallframe/lewd_portal/proc/clear_portals()
	var/obj/structure/lewd_portal/old_first = first_portal
	var/obj/structure/lewd_portal/old_second = second_portal
	if(old_first)
		UnregisterSignal(old_first, COMSIG_QDELETING)
	if(old_second)
		UnregisterSignal(old_second, COMSIG_QDELETING)
	first_portal = null
	second_portal = null

	if(!QDELETED(old_first))
		qdel(old_first)
	if(!QDELETED(old_second))
		qdel(old_second)

/obj/item/wallframe/lewd_portal/proc/on_portal_qdeleting(obj/structure/lewd_portal/source)
	SIGNAL_HANDLER
	if(source != first_portal && source != second_portal)
		return
	clear_portals()


/obj/effect/lewd_portal_relay
	name = "portal relay"
	desc = "Someone's behind hanging out from a portal."
	/// Everything we show is an overlay copied off the owner, so we never want the parent's icon.
	icon = null
	icon_state = null
	anchored = TRUE
	layer = ABOVE_MOB_LAYER
	/// Mob represented by this relay. Borrowed; never deleted by the relay.
	var/mob/living/carbon/human/owner
	/// The copied mode of the portal which created this relay.
	var/portal_mode = GLORYHOLE
	/// Prevents overlay signals caused by an active render from recursing.
	var/refreshing_visuals = FALSE

/obj/effect/lewd_portal_relay/Initialize(mapload, mob/living/carbon/human/owner_ref, obj/structure/lewd_portal/receiving_portal)
	. = ..()
	appearance_flags |= KEEP_TOGETHER
	if(QDELETED(owner_ref) || QDELETED(receiving_portal) || !owner_ref.dna?.species)
		return INITIALIZE_HINT_QDEL

	portal_mode = receiving_portal.portal_mode
	set_owner(owner_ref)
	if(portal_mode == GLORYHOLE)
		var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
		var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis?.bodypart_overlay
		var/datum/sprite_accessory/genital/shaft = penis_overlay?.shaft_datum || penis_overlay?.sprite_datum
		if(!penis || !shaft)
			return INITIALIZE_HINT_QDEL
		var/penis_type = LOWER_TEXT(penis.get_genital_descriptor(shaft))
		name = "[penis_type] penis"
		desc = penis.has_sheath() && penis.is_sheathed() ? "Someone's sheathed penis hanging out from a portal." : "Someone's penis hanging out from a portal."
		dir = (receiving_portal.dir == EAST || receiving_portal.dir == WEST) ? REVERSE_DIR(receiving_portal.dir) : SOUTH
	else
		dir = NORTH
		var/species_name
		if(owner.dna.species.lore_protected || !owner.dna.features["custom_species"])
			species_name = owner.dna.species.name
		else
			species_name = owner.dna.features["custom_species"]
		name = LOWER_TEXT("[species_name] behind")

	if(!update_visuals())
		return INITIALIZE_HINT_QDEL

	become_hearing_sensitive(ROUNDSTART_TRAIT)
	var/datum/component/interactable/interact_component = owner.GetComponent(/datum/component/interactable)
	interact_component?.set_body_relay(src)

/obj/effect/lewd_portal_relay/Destroy()
	var/mob/living/carbon/human/old_owner = owner
	var/datum/component/interactable/interact_component = old_owner?.GetComponent(/datum/component/interactable)
	interact_component?.clear_body_relay(src)
	set_owner(null)
	lose_hearing_sensitivity(ROUNDSTART_TRAIT)
	return ..()

/// Setter for the borrowed owner reference and all invalidation signals.
/obj/effect/lewd_portal_relay/proc/set_owner(mob/living/carbon/human/new_owner)
	if(owner == new_owner)
		return
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	owner = new_owner
	if(owner)
		RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_qdeleting))

/obj/effect/lewd_portal_relay/proc/on_owner_qdeleting(datum/source)
	SIGNAL_HANDLER
	if(source != owner)
		return
	set_owner(null)
	qdel(src)

/obj/effect/lewd_portal_relay/examine(mob/user)
	. = ..()
	if(!can_reveal_to(user))
		return
	if(owner.has_exposed_genitals(skipped_slots = list(ORGAN_SLOT_BREASTS)))
		. += span_notice("It has exposed genitals... <a href='byond://?src=[REF(src)];lookup_info=genitals'>\[Look closer...\]</a>")

/obj/effect/lewd_portal_relay/Topic(href, href_list)
	. = ..()
	if(href_list["lookup_info"] != "genitals" || QDELETED(owner))
		return
	if(!isliving(usr) || !usr.can_perform_action(src, ALLOW_RESTING | SILENT_ADJACENCY))
		return
	if(!can_reveal_to(usr))
		return

	var/list/line = owner.get_genital_description_lines(skipped_slots = list(ORGAN_SLOT_BREASTS))
	if(length(line))
		to_chat(usr, span_notice("[jointext(line, "\n")]"))

/// Requires a complete active session and both participants' canonical portal preferences.
/obj/effect/lewd_portal_relay/proc/can_reveal_to(mob/viewer)
	if(QDELETED(owner) || QDELETED(viewer))
		return FALSE
	var/obj/structure/lewd_portal/owner_portal = owner.buckled
	if(!istype(owner_portal) || !owner_portal.is_active_session(owner, src))
		return FALSE
	return owner.allows_portal_use() && viewer.allows_portal_use()

/// Rebuilds relay overlays from live owner state. Failure always leaves a blank relay.
/obj/effect/lewd_portal_relay/proc/update_visuals()
	if(refreshing_visuals || QDELETED(owner))
		return FALSE
	refreshing_visuals = TRUE
	cut_overlays()
	var/rendered = portal_mode == GLORYHOLE ? penis_only() : lower_body_only()
	refreshing_visuals = FALSE
	return rendered

/obj/effect/lewd_portal_relay/proc/penis_only()
	var/obj/item/organ/genital/penis/penis = owner.get_organ_slot(ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = penis?.bodypart_overlay
	if(!penis || !(penis_overlay?.shaft_datum || penis_overlay?.sprite_datum) || !penis.bodypart_owner)
		return FALSE

	var/list/generated_overlays = penis_overlay.get_all_overlays(penis.bodypart_owner)
	var/list/copied_overlays = list()
	append_appearance_copies(copied_overlays, generated_overlays)
	add_overlay(copied_overlays)
	return length(copied_overlays) > 0

/obj/effect/lewd_portal_relay/proc/lower_body_only()
	var/list/generated_overlays = list()
	for(var/limb_zone in list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_CHEST))
		var/obj/item/bodypart/limb = owner.get_bodypart(limb_zone)
		if(!istype(limb))
			continue
		var/list/limb_icons = limb.get_limb_icon()
		if(limb_zone == BODY_ZONE_CHEST)
			limb_icons = torso_only(limb_icons)
		append_appearance_copies(generated_overlays, limb_icons)

	if(owner.shoes)
		append_appearance_copies(generated_overlays, owner.overlays_standing[SHOES_LAYER])
	if(owner.w_uniform)
		append_appearance_copies(generated_overlays, owner.overlays_standing[UNIFORM_LAYER], apply_mask = TRUE)
	append_appearance_copies(generated_overlays, owner.overlays_standing[BODY_LAYER], apply_mask = TRUE)
	if(!length(generated_overlays))
		return FALSE
	add_overlay(generated_overlays)
	return TRUE

/// Clones torso appearances before filtering so cached limb appearances are never mutated.
/obj/effect/lewd_portal_relay/proc/torso_only(list/limb_icon_list)
	var/list/new_limb_icon_list = list()
	for(var/image/limb_icon as anything in limb_icon_list)
		if(compare_organ_icon(ORGAN_SLOT_EXTERNAL_WINGS, limb_icon.icon))
			continue
		var/mutable_appearance/new_limb_icon = new /mutable_appearance(limb_icon.appearance)
		var/limb_icon_layer = new_limb_icon.layer * -1
		if((limb_icon_layer != BODY_BEHIND_LAYER && limb_icon_layer != BODY_FRONT_LAYER) || compare_organ_icon(ORGAN_SLOT_BREASTS, new_limb_icon.icon))
			apply_upper_body_mask(new_limb_icon)
		new_limb_icon_list += new_limb_icon
	return new_limb_icon_list

/// Crops an appearance down to the half of the body that fits through the portal.
/obj/effect/lewd_portal_relay/proc/apply_upper_body_mask(mutable_appearance/appearance)
	var/static/icon/upper_body_mask
	if(isnull(upper_body_mask)) // Statics initialise alongside globals, so build it on first use instead.
		upper_body_mask = icon(PORTAL_ICON, "mask")
	appearance.add_filter("upper_body_removal", 1, list(
		"type" = "alpha",
		"icon" = upper_body_mask,
	))

/// Clones source appearances before filtering, skipping nonexistent icon states.
/obj/effect/lewd_portal_relay/proc/append_appearance_copies(list/output, appearance_source, apply_mask = FALSE)
	if(isnull(appearance_source))
		return
	if(islist(appearance_source))
		for(var/image/appearance as anything in appearance_source)
			append_appearance_copies(output, appearance, apply_mask)
		return

	var/image/source_appearance = appearance_source
	if(source_appearance.icon && !icon_exists(source_appearance.icon, source_appearance.icon_state))
		return
	var/mutable_appearance/copied_appearance = new(source_appearance.appearance)
	if(apply_mask)
		apply_upper_body_mask(copied_appearance)
	output += copied_appearance

/obj/effect/lewd_portal_relay/proc/compare_organ_icon(organ_slot, icon_to_compare)
	var/obj/item/organ/organ = owner?.get_organ_slot(organ_slot)
	var/datum/bodypart_overlay/mutant/organ_overlay = organ?.bodypart_overlay
	var/datum/sprite_accessory/accessory = organ_overlay?.sprite_datum
	return accessory?.get_special_icon(owner) == icon_to_compare

/obj/effect/lewd_portal_relay/attack_hand_secondary(mob/living/user)
	if(!user.can_perform_action(src, NEED_DEXTERITY | NEED_HANDS | ALLOW_RESTING))
		return ..()
	if(portal_mode == GLORYHOLE)
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	if(!can_reveal_to(user))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	dir = dir == NORTH ? SOUTH : NORTH
	to_chat(user, span_info("You flip \the [name] over."))
	to_chat(owner, span_info("You feel your behind flip over."))
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/effect/lewd_portal_relay/click_ctrl_shift(mob/user)
	if(QDELETED(owner))
		return
	return SEND_SIGNAL(owner, COMSIG_CLICK_CTRL_SHIFT, user)

#undef GLORYHOLE
#undef WALLSTUCK
#undef PORTAL_ICON
