/** Precision hand interaction builds on sustained telekinetic control. */
/datum/psionic_power/manipulate
	action_type = /datum/action/cooldown/psionic/pointed/manipulate
	required_powers = list(/datum/action/cooldown/psionic/pointed/telekinetic_hold)

/** Remote machinery use requires continuous effort and ordinary hand permissions. */
/datum/psionic_rank_variant/manipulate
	rank = PSIONIC_RANK_GAMMA
	variant_name = "remote hand"
	description = "Operate one visible machine or structure within five tiles, using your own access and its normal controls."
	maintained = TRUE
	strain_gain = 4
	active_strain_gain_per_second = 2
	blocks_strain_recovery = TRUE
	cooldown_time = 1 SECONDS
	cast_range = 5

/** A target-scoped remote hand. Ending it closes only this user's connected interfaces. */
/datum/action/cooldown/psionic/pointed/manipulate
	parent_type = /datum/action/cooldown/psionic/pointed/telekinetic_connection
	name = "Manipulate"
	desc = "Use a visible machine or structure with a remote hand. Right-click the connected target to use a tool held beside it by Telekinetic Hold. Locks, access, power and tool requirements still apply. Click this button to release."
	button_icon_state = "psi_kinetic_pull"
	point_cost = 1
	unset_after_click = FALSE
	maintain_end_message = "Your remote hand fades."
	variant_type = /datum/psionic_rank_variant/manipulate
	rank_variant_types = list(/datum/psionic_rank_variant/manipulate)
	/// Tool currently executing an interaction. Its Hold and position are checked throughout tool delays.
	var/datum/weakref/remote_tool_ref
	/// Prevents a new tool operation from starting while an interrupted call is still returning.
	var/tool_in_progress = FALSE

/** Reference to the active connection, never a general distance-bypass permission. */
/mob/var/datum/weakref/psionic_manipulation_ref

/** Returns whether this exact target is covered by a currently valid remote hand. */
/mob/proc/can_psionically_reach(atom/target)
	return FALSE

/mob/living/can_psionically_reach(atom/target)
	var/datum/action/cooldown/psionic/pointed/manipulate/connection = psionic_manipulation_ref?.resolve()
	if(!connection)
		psionic_manipulation_ref = null
		return FALSE
	return connection.owner == src && connection.connected_object == target && connection.can_maintain(src, get_psionic_profile())

/** Overrides UI distance only for the connected object, and closes it when the link is invalid. */
/mob/proc/psionic_ui_distance(atom/target)
	var/datum/action/cooldown/psionic/pointed/manipulate/connection = psionic_manipulation_ref?.resolve()
	if(!connection || connection.connected_object != target)
		return null
	return can_psionically_reach(target) ? UI_INTERACTIVE : UI_CLOSE

/** Only stationary-world machinery and structures support a remote hand. */
/obj/proc/allows_psionic_manipulation()
	return FALSE

/obj/machinery/allows_psionic_manipulation()
	return TRUE

/obj/structure/allows_psionic_manipulation()
	return TRUE

/** Remote canister valve operation is excluded from the initial machinery discipline. */
/obj/machinery/portable_atmospherics/canister/allows_psionic_manipulation()
	return FALSE

/** Preserves specialized UI restrictions by accepting only ordinary physical control states. */
/datum/action/cooldown/psionic/pointed/manipulate/proc/can_manipulate_object(obj/target)
	if(!istype(target) || !in_connection_range(target) || !target.allows_psionic_manipulation())
		return FALSE
	var/datum/ui_state/target_state = target.ui_state(owner)
	return target_state == GLOB.default_state || target_state == GLOB.physical_state

/datum/action/cooldown/psionic/pointed/manipulate/is_valid_target(atom/target)
	if(!can_manipulate_object(target))
		owner.balloon_alert(owner, "can't manipulate that!")
		return FALSE
	return TRUE

/datum/action/cooldown/psionic/pointed/manipulate/can_maintain(mob/living/living_owner, datum/component/psionic_profile/profile)
	return ..() && can_manipulate_object(connected_object)

/datum/action/cooldown/psionic/pointed/manipulate/psionic_activate(obj/target)
	var/mob/living/living_owner = owner
	var/datum/action/cooldown/psionic/pointed/manipulate/previous_connection = living_owner.psionic_manipulation_ref?.resolve()
	previous_connection?.stop_maintaining(living_owner)
	connect_object(target)
	living_owner.psionic_manipulation_ref = WEAKREF(src)
	if(!target.can_interact(living_owner))
		if(get_remote_tool())
			living_owner.balloon_alert(living_owner, "remote tool ready")
			return TRUE
		stop_maintaining(living_owner, silent = TRUE)
		living_owner.balloon_alert(living_owner, "controls unavailable!")
		return FALSE
	interact_with_target()
	return TRUE

/** Runs the user's ordinary empty-hand chain without silicon privileges or access substitution. */
/datum/action/cooldown/psionic/pointed/manipulate/proc/interact_with_target()
	if(tool_in_progress || !validate_connection())
		return FALSE
	var/mob/living/living_owner = owner
	if(world.time < living_owner.next_move || !connected_object.can_interact(living_owner))
		return FALSE
	living_owner.changeNext_move(CLICK_CD_MELEE)
	new /obj/effect/temp_visual/telekinesis(get_turf(connected_object))
	connected_object.add_hiddenprint(living_owner)
	living_owner.UnarmedAttack(connected_object, FALSE)
	return TRUE

/datum/action/cooldown/psionic/pointed/manipulate/InterceptClickOn(mob/living/clicker, params, atom/target)
	if(istype(target, /atom/movable/screen))
		return FALSE
	if(maintaining && target == connected_object)
		var/list/modifiers = params2list(params)
		if(LAZYACCESS(modifiers, RIGHT_CLICK))
			use_remote_tool(modifiers)
		else
			interact_with_target()
		return TRUE
	if(maintaining)
		if(next_use_time > world.time)
			return TRUE
		stop_maintaining(clicker)
	if(..() && maintaining && clicker.click_intercept != src)
		set_click_ability(clicker)
	return TRUE

/datum/action/cooldown/psionic/pointed/manipulate/on_maintain_stopped(mob/living/living_owner, silent = FALSE)
	remote_tool_ref = null
	if(living_owner?.psionic_manipulation_ref == weak_reference)
		living_owner.psionic_manipulation_ref = null
	if(connected_object)
		for(var/datum/tgui/ui as anything in living_owner.tgui_open_uis.Copy())
			if(ui.src_object == connected_object || ui.src_object?.ui_host(living_owner) == connected_object)
				ui.close()
	return ..()

/** Finds an eligible tool held beside the connected target. */
/datum/action/cooldown/psionic/pointed/manipulate/proc/get_remote_tool()
	var/mob/living/living_owner = owner
	var/datum/component/psionic_profile/profile = living_owner.get_psionic_profile()
	var/datum/action/cooldown/psionic/pointed/telekinetic_hold/hold = profile.granted_actions[/datum/action/cooldown/psionic/pointed/telekinetic_hold]
	var/obj/item/held_tool = hold?.connected_object
	if(!istype(held_tool) || !held_tool.tool_behaviour || !hold.validate_connection() || !held_tool.Adjacent(connected_object))
		return null
	return held_tool

/** Runs a held tool's normal item interaction at the tool's own location. */
/datum/action/cooldown/psionic/pointed/manipulate/proc/use_remote_tool(list/modifiers)
	var/mob/living/living_owner = owner
	if(tool_in_progress || world.time < living_owner.next_move || !validate_connection())
		return FALSE
	var/datum/component/psionic_profile/profile = living_owner.get_psionic_profile()
	var/datum/action/cooldown/psionic/pointed/telekinetic_hold/hold = profile.granted_actions[/datum/action/cooldown/psionic/pointed/telekinetic_hold]
	var/obj/item/held_tool = get_remote_tool()
	if(!held_tool)
		living_owner.balloon_alert(living_owner, "hold a tool beside it!")
		return FALSE
	hold.destination = null
	hold.retrieving = FALSE
	remote_tool_ref = WEAKREF(held_tool)
	tool_in_progress = TRUE
	living_owner.changeNext_move(CLICK_CD_MELEE)
	living_owner.log_message("used [held_tool] at [AREACOORD(held_tool)] on [connected_object] with Manipulate.", LOG_GAME)
	// Right-click selects tool use here; the tool receives an ordinary primary interaction.
	var/list/tool_modifiers = modifiers.Copy()
	tool_modifiers -= RIGHT_CLICK
	var/interaction_result = held_tool.melee_attack_chain(living_owner, connected_object, tool_modifiers)
	remote_tool_ref = null
	tool_in_progress = FALSE
	return interaction_result

/** Adds connection checks to an existing tool callback without changing the tool's normal delay or fuel checks. */
/mob/proc/psionic_tool_checks(obj/item/tool, atom/target, datum/callback/extra_checks)
	var/datum/action/cooldown/psionic/pointed/manipulate/connection = psionic_manipulation_ref?.resolve()
	if(connection?.remote_tool_ref?.resolve() != tool || connection.connected_object != target)
		return extra_checks
	return CALLBACK(connection, TYPE_PROC_REF(/datum/action/cooldown/psionic/pointed/manipulate, check_remote_tool), WEAKREF(tool), WEAKREF(target), extra_checks)

/** Rechecks both the remote hand and the actual held tool on every tick of a timed tool operation. */
/datum/action/cooldown/psionic/pointed/manipulate/proc/check_remote_tool(datum/weakref/tool_ref, datum/weakref/target_ref, datum/callback/extra_checks)
	var/obj/item/tool = tool_ref.resolve()
	var/obj/target_object = target_ref.resolve()
	if(QDELETED(tool) || QDELETED(target_object) || remote_tool_ref?.resolve() != tool || connected_object != target_object || !validate_connection())
		return FALSE
	var/mob/living/living_owner = owner
	var/datum/component/psionic_profile/profile = living_owner.get_psionic_profile()
	var/datum/action/cooldown/psionic/pointed/telekinetic_hold/hold = profile.granted_actions[/datum/action/cooldown/psionic/pointed/telekinetic_hold]
	return hold?.connected_object == tool && hold.validate_connection() && tool.Adjacent(target_object) && (!extra_checks || extra_checks.Invoke())
