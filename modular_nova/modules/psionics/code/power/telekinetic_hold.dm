/** A maintained connection to one visible object, shared by Hold and Manipulate. */
/datum/action/cooldown/psionic/pointed/telekinetic_connection
	psionic_flags = PSIONIC_KINETIC
	school = PSIONIC_SCHOOL_GRAVITY
	needs_hands = TRUE
	/// Connected object; its deletion signal tears down the connection.
	var/obj/connected_object
	/// Visible marker removed on every teardown path.
	var/mutable_appearance/connection_overlay

/** Checks physical location and sight without granting interaction permissions. */
/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/in_connection_range(atom/target)
	var/mob/living/living_owner = owner
	if(!istype(living_owner) || QDELETED(target) || !isturf(living_owner.loc))
		return FALSE
	if(!isturf(target.loc) || living_owner.z != target.z || living_owner.is_blind())
		return FALSE
	var/connection_range = get_variant_value(living_owner.get_psionic_profile(), "cast_range")
	return get_dist(living_owner, target) <= connection_range && can_see(living_owner, target, connection_range)

/datum/action/cooldown/psionic/pointed/telekinetic_connection/can_maintain(mob/living/living_owner, datum/component/psionic_profile/profile)
	return ..() && length(get_unlocked_rank_variants(profile)) && in_connection_range(connected_object)

/** Starts target tracking only after the cast has passed its strain and eligibility checks. */
/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/connect_object(obj/target)
	connected_object = target
	connection_overlay = mutable_appearance('icons/effects/effects.dmi', "kinesis")
	connection_overlay.color = get_manifestation_color()
	connected_object.add_overlay(connection_overlay)
	RegisterSignal(connected_object, COMSIG_QDELETING, PROC_REF(on_connection_deleted))
	RegisterSignal(connected_object, COMSIG_MOVABLE_MOVED, PROC_REF(on_connection_moved))
	RegisterSignal(connected_object, COMSIG_MOVABLE_SET_ANCHORED, PROC_REF(on_connection_anchored))
	RegisterSignal(connected_object, COMSIG_ATOM_PSIONIC_DISPEL, PROC_REF(on_connection_dispelled))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_connection_moved))
	RegisterSignal(owner, SIGNAL_ADDTRAIT(TRAIT_PSIONIC_DAMPENER), PROC_REF(on_connection_dampened))
	RegisterSignal(owner, COMSIG_MOB_LOGOUT, PROC_REF(on_connection_deleted))
	start_maintaining(owner)
	START_PROCESSING(SSfastprocess, src)
	owner.log_message("established [name] on [connected_object] at [AREACOORD(connected_object)].", LOG_GAME)
	playsound(connected_object, 'sound/effects/gravhit.ogg', 35, TRUE)

/datum/action/cooldown/psionic/pointed/telekinetic_connection/on_maintain_stopped(mob/living/living_owner, silent = FALSE)
	STOP_PROCESSING(SSfastprocess, src)
	if(connected_object)
		UnregisterSignal(connected_object, list(COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_SET_ANCHORED, COMSIG_ATOM_PSIONIC_DISPEL))
		connected_object.cut_overlay(connection_overlay)
	connected_object = null
	connection_overlay = null
	UnregisterSignal(living_owner, list(COMSIG_MOVABLE_MOVED, SIGNAL_ADDTRAIT(TRAIT_PSIONIC_DAMPENER), COMSIG_MOB_LOGOUT))
	if(living_owner?.click_intercept == src)
		unset_click_ability(living_owner, refund_cooldown = FALSE)
	return ..()

/** Revalidates the connection between life ticks, including moving doors and suppression fields. */
/datum/action/cooldown/psionic/pointed/telekinetic_connection/process(seconds_per_tick)
	if(!maintaining)
		..()
		return FALSE
	build_all_button_icons(UPDATE_BUTTON_STATUS)
	return validate_connection()

/** Ends a connection as soon as its owner or target becomes ineligible. */
/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/validate_connection()
	var/mob/living/living_owner = owner
	if(!maintaining)
		return FALSE
	if(can_maintain(living_owner, living_owner.get_psionic_profile()))
		return TRUE
	stop_maintaining(living_owner)
	return FALSE

/datum/action/cooldown/psionic/pointed/telekinetic_connection/update_status_on_signal()
	. = ..()
	validate_connection()

/datum/action/cooldown/psionic/pointed/telekinetic_connection/on_rank_variant_selected(mob/living/living_owner, datum/psionic_rank_variant/variant)
	if(maintaining)
		stop_maintaining(living_owner)
	return ..()

/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/on_connection_moved(atom/movable/source, atom/old_loc, direction, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	validate_connection()

/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/on_connection_anchored(atom/movable/source, anchorvalue)
	SIGNAL_HANDLER
	validate_connection()

/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/on_connection_dampened(datum/source)
	SIGNAL_HANDLER
	validate_connection()

/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/on_connection_deleted(datum/source)
	SIGNAL_HANDLER
	stop_maintaining(owner, silent = TRUE)

/datum/action/cooldown/psionic/pointed/telekinetic_connection/proc/on_connection_dispelled(atom/source, atom/dispeller)
	SIGNAL_HANDLER
	stop_maintaining(owner)
	return COMPONENT_PSIONIC_DISPELLED

/** Loose-object control, with the existing Shove action bundled as a combat shortcut. */
/datum/psionic_power/telekinetic_hold
	action_type = /datum/action/cooldown/psionic/pointed/telekinetic_hold

/** Light control trades lifting capacity for passive strain recovery. */
/datum/psionic_rank_variant/telekinetic_hold
	rank = PSIONIC_RANK_EPSILON
	variant_name = "light hold"
	description = "Move one tiny or small loose item within five tiles. Acquisition costs 2 strain per weight class; launch costs 4 per class."
	maintained = TRUE
	strain_gain = 2
	active_strain_gain_per_second = 0
	blocks_strain_recovery = FALSE
	cooldown_time = 1 SECONDS
	cast_range = 5
	/// Largest object weight supported by this form.
	var/max_weight = WEIGHT_CLASS_SMALL
	/// Launch strain per weight class, before school discounts.
	var/launch_strain_per_weight = 4
	/// Tiles a deliberate launch can travel.
	var/launch_range = 5

/datum/psionic_rank_variant/telekinetic_hold/gamma
	rank = PSIONIC_RANK_GAMMA
	variant_name = "firm hold"
	description = "Move one loose item up to bulky size, or an unanchored structure, within five tiles. Acquisition costs 2 strain per weight class; launch costs 4 per class."
	max_weight = WEIGHT_CLASS_BULKY
	active_strain_gain_per_second = 1
	blocks_strain_recovery = TRUE

/datum/psionic_rank_variant/telekinetic_hold/get_description(datum/action/cooldown/psionic/action)
	return "[description] ([active_strain_gain_per_second] strain/s, [blocks_strain_recovery ? "pauses" : "allows"] recovery while held, [cooldown_time / 10]s cooldown)"

/** One movable object, commanded by clicks without replacing its movement or collision rules. */
/datum/action/cooldown/psionic/pointed/telekinetic_hold
	parent_type = /datum/action/cooldown/psionic/pointed/telekinetic_connection
	name = "Telekinetic Hold"
	desc = "Control one loose object. Click a destination to move it, shift-click to retrieve it, or right-click to launch it. Click the held object or this button to release. Includes a separate Shove shortcut."
	button_icon_state = "psi_kinetic_pull"
	point_cost = 1
	unset_after_click = FALSE
	maintain_end_message = "You release your telekinetic hold."
	variant_type = /datum/psionic_rank_variant/telekinetic_hold
	rank_variant_types = list(/datum/psionic_rank_variant/telekinetic_hold, /datum/psionic_rank_variant/telekinetic_hold/gamma)
	/// Current destination; movement advances one normal step at a time.
	var/turf/destination
	/// Retrieve into a free hand once the object reaches the caster's turf.
	var/retrieving = FALSE
	/// Bundled combat shortcut, owned by this discipline and removed with it.
	var/datum/action/cooldown/psionic/pointed/kinetic_shove/shove_action

/datum/action/cooldown/psionic/pointed/telekinetic_hold/Grant(mob/grant_to)
	. = ..()
	if(!shove_action)
		shove_action = new(src)
	shove_action.Grant(grant_to)

/datum/action/cooldown/psionic/pointed/telekinetic_hold/Remove(mob/remove_from)
	QDEL_NULL(shove_action)
	return ..()

/** Returns zero for objects outside Hold's physical scope. */
/obj/proc/psionic_hold_weight()
	return 0

/obj/item/psionic_hold_weight()
	if((item_flags & ABSTRACT) || HAS_TRAIT(src, TRAIT_UNCATCHABLE))
		return 0
	return w_class

/obj/structure/psionic_hold_weight()
	if(has_buckled_mobs())
		return 0
	return WEIGHT_CLASS_BULKY

/** Rejects containment, anchoring, excessive weight, throws, and competing holders. */
/datum/action/cooldown/psionic/pointed/telekinetic_hold/proc/can_hold_object(obj/target)
	if(!istype(target) || !in_connection_range(target) || target.anchored || target.throwing || target.move_resist >= MOVE_FORCE_STRONG)
		return FALSE
	var/datum/psionic_rank_variant/telekinetic_hold/form = get_form()
	var/object_weight = target.psionic_hold_weight()
	if(!form || !object_weight || object_weight > form.max_weight)
		return FALSE
	if(HAS_TRAIT_NOT_FROM(target, TRAIT_TELEKINESIS_CONTROLLED, REF(src)))
		return FALSE
	return TRUE

/datum/action/cooldown/psionic/pointed/telekinetic_hold/is_valid_target(atom/target)
	if(!can_hold_object(target))
		owner.balloon_alert(owner, "can't hold that!")
		return FALSE
	return TRUE

/datum/action/cooldown/psionic/pointed/telekinetic_hold/get_activation_strain(obj/target, datum/component/psionic_profile/profile)
	return ..() * target.psionic_hold_weight()

/datum/action/cooldown/psionic/pointed/telekinetic_hold/psionic_activate(obj/target)
	if(!can_hold_object(target))
		return FALSE
	ADD_TRAIT(target, TRAIT_TELEKINESIS_CONTROLLED, REF(src))
	connect_object(target)
	owner.visible_message(span_notice("[target] lifts under [owner]'s telekinetic control."), span_notice("You hold [target]. Click to move, shift-click to retrieve, right-click to launch; click this power to release."))
	return TRUE

/datum/action/cooldown/psionic/pointed/telekinetic_hold/can_maintain(mob/living/living_owner, datum/component/psionic_profile/profile)
	return ..() && can_hold_object(connected_object)

/datum/action/cooldown/psionic/pointed/telekinetic_hold/on_maintain_stopped(mob/living/living_owner, silent = FALSE)
	if(connected_object)
		REMOVE_TRAIT(connected_object, TRAIT_TELEKINESIS_CONTROLLED, REF(src))
	destination = null
	retrieving = FALSE
	return ..()

/datum/action/cooldown/psionic/pointed/telekinetic_hold/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(istype(target, /atom/movable/screen))
		return FALSE
	var/list/modifiers = params2list(params)
	if(!maintaining)
		if(..() && LAZYACCESS(modifiers, SHIFT_CLICK) && maintaining)
			retrieving = TRUE
		return TRUE
	if(!validate_connection())
		return TRUE
	if(LAZYACCESS(modifiers, SHIFT_CLICK))
		retrieving = TRUE
	else if(target == connected_object)
		stop_maintaining(clicker)
	else if(LAZYACCESS(modifiers, RIGHT_CLICK))
		launch_object(target)
	else
		set_destination(get_turf(target))
	clicker.next_click = world.time + 0.2 SECONDS
	return TRUE

/** Selects a visible destination without teleporting or automatically attacking obstacles. */
/datum/action/cooldown/psionic/pointed/telekinetic_hold/proc/set_destination(turf/target)
	var/datum/psionic_rank_variant/telekinetic_hold/form = get_form()
	if(!target || !form || target.z != owner.z || get_dist(owner, target) > form.cast_range || !can_see(owner, target, form.cast_range))
		return FALSE
	destination = target
	retrieving = FALSE
	return TRUE

/datum/action/cooldown/psionic/pointed/telekinetic_hold/process(seconds_per_tick)
	if(!..())
		return FALSE
	var/mob/living/living_owner = owner
	if(retrieving)
		destination = get_turf(living_owner)
	if(!destination)
		return TRUE
	if(connected_object.loc != destination)
		var/turf/next_turf = get_step_towards(connected_object, destination)
		// Move() checks doors, walls, windows and diagonal corners normally.
		connected_object.Move(next_turf, get_dir(connected_object, next_turf))
	if(!maintaining || connected_object.loc != destination)
		return TRUE
	destination = null
	if(retrieving && isitem(connected_object) && length(living_owner.get_empty_held_indexes()))
		var/obj/item/retrieved_item = connected_object
		stop_maintaining(living_owner, silent = TRUE)
		living_owner.put_in_hands(retrieved_item)
		living_owner.balloon_alert(living_owner, "retrieved")
	return TRUE

/** Charges a deliberate launch separately from acquisition, then uses the ordinary throw path. */
/datum/action/cooldown/psionic/pointed/telekinetic_hold/proc/launch_object(atom/target)
	var/turf/target_turf = get_turf(target)
	if(!validate_connection() || !set_destination(target_turf))
		return FALSE
	var/datum/psionic_rank_variant/telekinetic_hold/form = get_form()
	var/mob/living/living_owner = owner
	var/datum/component/psionic_profile/profile = living_owner.get_psionic_profile()
	if(!profile.try_gain_strain(form.launch_strain_per_weight * connected_object.psionic_hold_weight(), src) || !maintaining)
		return FALSE
	var/obj/launched_object = connected_object
	stop_maintaining(living_owner, silent = TRUE)
	StartCooldown(form.cooldown_time)
	living_owner.log_message("launched [launched_object] from [AREACOORD(launched_object)] toward [AREACOORD(target_turf)] with Telekinetic Hold.", LOG_ATTACK)
	playsound(launched_object, 'sound/effects/magic/repulse.ogg', 50, TRUE)
	return launched_object.safe_throw_at(target_turf, range = min(form.launch_range, launched_object.tk_throw_range), speed = 2, thrower = living_owner)
