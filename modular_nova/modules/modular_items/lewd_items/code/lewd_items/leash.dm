/// Leash length in tiles.
#define ERP_LEASH_LENGTH 2
/// The most turfs of the leader's route kept.
#define ERP_LEASH_TRAIL_MAX (ERP_LEASH_LENGTH * 4)
/// Time a holder gets to let go after the leashed falls, and between each step they're dragged.
#define ERP_LEASH_DRAG_DELAY (1.5 SECONDS)
/// How long the line takes to follow the hand when the holder turns in place.
#define ERP_LEASH_TURN_GLIDE (0.1 SECONDS)
/// Whether two turfs are on the same z-level and at most a tile apart.
#define ERP_LEASH_NEAR(a, b) ((a).z == (b).z && get_dist(a, b) <= 1)
/// Whether two turfs are on the same z-level and within the leash length plus one, enough to pick up a leash lying at
/// full length.
#define ERP_LEASH_IN_REACH(a, b) ((a).z == (b).z && get_dist(a, b) <= ERP_LEASH_LENGTH + 1)

/obj/item/clothing/erp_leash
	name = "leash"
	desc = "A guiding hand's best friend; in a sleek, semi-elastic package. Can either clip to a collar or be affixed to the neck on its own."
	worn_icon = 'modular_nova/modules/modular_items/lewd_items/icons/mob/lewd_clothing/lewd_belts.dmi'
	greyscale_colors = "#383840#dc7ef4#d1d3e0"
	icon = 'icons/map_icons/clothing/_clothing.dmi'
	icon_state = "/obj/item/clothing/erp_leash"
	post_init_icon_state = "neckleash"
	greyscale_config = /datum/greyscale_config/neckleash
	greyscale_config_worn = /datum/greyscale_config/neckleash/worn
	equip_sound = 'sound/items/equip/toolbelt_equip.ogg'
	drop_sound = 'sound/items/handling/toolbelt_drop.ogg'
	slot_flags = ITEM_SLOT_BELT
	obj_flags_nova = ERP_ITEM
	breakouttime = 3 SECONDS
	flags_1 = IS_PLAYER_COLORABLE_1
	/// The component on the leashed, while it's clipped to someone.
	var/datum/component/erp_leash/hook

/// Clips the leash to someone's neck after two seconds, if their sex toy preference allows. Used on the leashed, unhooks it.
/obj/item/clothing/erp_leash/attack(mob/living/carbon/human/to_be_leashed, mob/living/user, params)
	if(hook)
		if(hook.parent != to_be_leashed)
			to_chat(user, span_warning("[src] is clipped to [hook.parent] already."))
		else if(user == to_be_leashed)
			hook.break_out()
		else
			to_be_leashed.balloon_alert_to_viewers("unhooked")
			qdel(hook)
		return
	if(!istype(to_be_leashed) || user == to_be_leashed)
		return
	if(!to_be_leashed.check_erp_prefs(/datum/preference/toggle/erp/sex_toy, user, src))
		to_chat(user, span_danger("[to_be_leashed] doesn't want you to do that."))
		return
	to_be_leashed.visible_message(span_warning("[user] raises [src] to [to_be_leashed]'s neck!"),\
				span_userdanger("[user] starts to bring [src] to your neck!"),\
				span_hear("You hear a light click as pressure builds in the air around your neck."))
	if(!do_after(user, 2 SECONDS, to_be_leashed) || hook)
		return
	if(to_be_leashed.GetComponent(/datum/component/erp_leash))
		to_chat(user, span_danger("There's a leash attached to [to_be_leashed] already."))
		return
	to_be_leashed.AddComponent(/datum/component/erp_leash, src)
	to_be_leashed.balloon_alert(user, "leashed!")

/// A hooked leash can only be picked up by someone the leashed allows to lead them.
/obj/item/clothing/erp_leash/attempt_pickup(mob/living/user, skip_grav)
	if(hook && user != hook.free_end && !hook.may_hold(user))
		return TRUE
	return ..()

/**
 * The leash's hook on the leashed. The free end is whoever holds or wears the leash, or the leash itself on the floor.
 *
 * The leashed follows their holder's route a step at a time, and holds the holder back where they can't follow. A leash
 * on the floor follows the leashed the same way, but never holds them back.
 */
/datum/component/erp_leash
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The leash.
	var/obj/item/clothing/erp_leash/leash
	/// Whoever holds or wears the leash (the leashed included), or the leash itself on the floor.
	var/atom/movable/free_end
	/// Turfs the leader walked, oldest first, for the follower to retrace. Null when empty.
	var/list/turf/trail
	/// The hole the leashed fell down, while their holder is dragged to it or held by it.
	var/turf/hole
	/// The timer dragging the holder to the hole. TIMER_DELETE_ME so its own callback can stop it.
	var/drag_timer
	/// The turf the leash is moving an end onto. The ends' move handlers skip that move.
	var/turf/moving
	/// When the follower last stepped. At most one step a tick.
	var/last_step
	/// The line from the free end to the leashed.
	var/datum/beam/held/leash/line
	COOLDOWN_DECLARE(tug_cd)
	COOLDOWN_DECLARE(taut_cd)

/datum/component/erp_leash/Initialize(obj/item/clothing/erp_leash/leash)
	if(!isliving(parent) || !istype(leash))
		return COMPONENT_INCOMPATIBLE
	src.leash = leash
	leash.hook = src
	ADD_TRAIT(leash, TRAIT_NO_STORAGE_INSERT, REF(src))
	RegisterSignal(leash, COMSIG_QDELETING, PROC_REF(selfdelete))
	RegisterSignal(leash, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_leash_pre_move))
	RegisterSignal(leash, COMSIG_MOVABLE_MOVED, PROC_REF(on_leash_moved))
	RegisterSignal(leash, COMSIG_ITEM_POST_EQUIPPED, PROC_REF(on_leash_equipped))
	RegisterSignal(leash, COMSIG_ITEM_ATTACK_SELF, PROC_REF(on_tug))

/datum/component/erp_leash/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_collar_pre_move))
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_collar_moved))
	RegisterSignal(parent, COMSIG_CAN_Z_MOVE, PROC_REF(on_collar_z_move))
	RegisterSignal(parent, COMSIG_MOVABLE_CHASM_DROPPED, PROC_REF(on_chasm_dropped))
	RegisterSignal(parent, COMSIG_LIVING_RESIST, PROC_REF(on_resist))
	set_free_end(ismob(leash.loc) ? leash.loc : leash)

/datum/component/erp_leash/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_CAN_Z_MOVE, COMSIG_MOVABLE_CHASM_DROPPED, COMSIG_LIVING_RESIST))

/datum/component/erp_leash/Destroy(force)
	QDEL_NULL(line)
	REMOVE_TRAIT(leash, TRAIT_NO_STORAGE_INSERT, REF(src))
	if(leash.hook == src)
		leash.hook = null
	leash = null
	free_end = null
	return ..()

/// Sets the free end, redrawing the line and clearing the route. Dropped while the leashed is down a hole, the leash
/// goes down after them.
/datum/component/erp_leash/proc/set_free_end(atom/movable/end)
	if(free_end && free_end != leash && free_end != parent)
		UnregisterSignal(free_end, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_CHASM_DROPPED, COMSIG_QDELETING))
	free_end = end
	trail = null
	var/turf/drop = hole
	stop_drag()
	QDEL_NULL(line)
	if(end == parent)
		return
	if(end == leash)
		if(drop && isturf(leash.loc))
			leash.forceMove(drop)
	else
		RegisterSignal(end, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_holder_pre_move))
		RegisterSignal(end, COMSIG_MOVABLE_MOVED, PROC_REF(on_holder_moved))
		RegisterSignal(end, COMSIG_MOVABLE_CHASM_DROPPED, PROC_REF(on_chasm_dropped))
		RegisterSignal(end, COMSIG_QDELETING, PROC_REF(separate))
	line = new(end, parent, icon_state = "fishing_line", beam_color = SSgreyscale.ParseColorString(leash.greyscale_colors)[1], emissive = FALSE)
	if(ismob(end))
		var/mob/holder = end
		line.held_index = holder.get_held_index_of_item(leash)
		line.lefthand = IS_LEFT_INDEX(line.held_index)
	RegisterSignal(line, COMSIG_QDELETING, PROC_REF(on_line_deleted))
	INVOKE_ASYNC(line, TYPE_PROC_REF(/datum/beam, Start))

/// Clears the line, which is deleted with either end.
/datum/component/erp_leash/proc/on_line_deleted(datum/source)
	SIGNAL_HANDLER
	line = null

/// Whether `user` can hold the leash, checked against the leashed's sex toy preference.
/datum/component/erp_leash/proc/may_hold(mob/user)
	var/mob/living/leashed = parent
	if(user == leashed || leashed.check_erp_prefs(/datum/preference/toggle/erp/sex_toy, user, leash))
		return TRUE
	to_chat(user, span_danger("[leashed] doesn't want you to do that."))
	return FALSE

/// Steps of route from `at` to the leader, from the newest of the trail's first `last` turfs that `at` is on or beside.
/datum/component/erp_leash/proc/route_hops(turf/at, last)
	for(var/index in last to 1 step -1)
		var/turf/step = trail[index]
		if(step == at)
			return last - index + 1
		if(ERP_LEASH_NEAR(at, step))
			return last - index + 2
	return INFINITY

/// Leash needed from `at` to the leader at `here`: `hops` along the route (the whole trail by default), or the straight
/// line if it's shorter, clear and within the leash length, or if `at` is off the route.
/datum/component/erp_leash/proc/rope_to(turf/at, turf/here, hops)
	if(at == here)
		return 0
	if(ERP_LEASH_NEAR(at, here))
		return 1
	if(isnull(hops))
		hops = route_hops(at, length(trail))
	if(hops <= ERP_LEASH_LENGTH || at.z != here.z)
		return hops
	var/straight = get_dist(at, here)
	if(hops == INFINITY || (straight <= ERP_LEASH_LENGTH && no_wall_between(at, here)))
		return min(hops, straight)
	return hops

/// Leash needed from `at` after the leader steps from `here` to `next`. Stepping back along the route, or back down
/// stairs it climbed, shortens the route, and both halves of a diagonal count as one step.
/datum/component/erp_leash/proc/rope_after(turf/at, turf/here, turf/next, moving_diagonally)
	if(ERP_LEASH_NEAR(at, next))
		return 1
	var/back = trail?.Find(next)
	if(back)
		return rope_to(at, next, route_hops(at, back - 1))
	. = rope_to(at, next, ERP_LEASH_NEAR(at, here) ? 2 : route_hops(at, length(trail)) + (moving_diagonally != SECOND_DIAG_STEP))
	if(. <= ERP_LEASH_LENGTH || !length(trail))
		return
	var/turf/landing = trail[length(trail)]
	if(next == GET_TURF_ABOVE(landing))
		return rope_to(at, landing, route_hops(at, length(trail) - 1))

/// Whether the straight line between two turfs on the same z-level is passable and safe for the leashed.
/datum/component/erp_leash/proc/no_wall_between(turf/start, turf/finish)
	for(var/turf/step = get_step_towards(start, finish); step != finish; step = get_step_towards(step, finish))
		if(step.is_blocked_turf(exclude_mobs = TRUE) || !can_cross_safely(step, start))
			return FALSE
	return TRUE

/// Whether the leashed can safely cross `place`. Lattices and catwalks count as footing, and space is safe coming from
/// unsafe footing, so someone adrift can be led. Without gravity the leash is checked instead, as holes count as safe
/// for floaters.
/datum/component/erp_leash/proc/can_cross_safely(turf/place, turf/from)
	var/atom/movable/crossing = HAS_TRAIT_FROM_ONLY(parent, TRAIT_MOVE_FLOATING, NO_GRAVITY_TRAIT) ? leash : parent
	if(!isturf(place) || place.can_cross_safely(crossing))
		return TRUE
	return isspaceturf(place) && ((locate(/obj/structure/lattice) in place) || (from && !can_cross_safely(from)))

/// Records the leader's step from `old` to `now`, cutting the route back where it doubles back on itself.
/datum/component/erp_leash/proc/add_to_trail(turf/old, turf/now, hop)
	var/index = trail?.Find(now)
	if(index)
		trail.Cut(index)
		if(!length(trail))
			trail = null
	else if(hop)
		LAZYADD(trail, old)
		if(length(trail) > ERP_LEASH_TRAIL_MAX)
			trail.Cut(1, 2)

/// Drops the route behind the follower's turf.
/datum/component/erp_leash/proc/followed(turf/at)
	var/index = trail?.Find(at)
	if(index > 1)
		trail.Cut(1, index)

/**
 * Moves the follower one step toward the leader at `here`, gliding with them. Goes straight at them when the way is
 * clear, otherwise along the route: round corners, through doors, up stairs and down holes.
 */
/datum/component/erp_leash/proc/retrace(atom/movable/follower, turf/at, turf/here, glide)
	var/mob/living/leashed = parent
	if(last_step == world.time || follower.anchored || (follower == leashed && leashed.buckled))
		return FALSE
	if(at.z == here.z && get_dist(at, here) <= ERP_LEASH_LENGTH + 1 && no_wall_between(at, here) && take_step(follower, at, get_step_towards(at, here), null, glide))
		return TRUE
	for(var/index in length(trail) to 1 step -1)
		var/turf/step = trail[index]
		if(step != at)
			if(ERP_LEASH_NEAR(at, step))
				return take_step(follower, at, step, null, glide)
			continue
		var/turf/ahead = index < length(trail) ? trail[index + 1] : here
		var/obj/structure/stairs/stairs = locate() in at
		if(stairs?.isTerminator() && get_step_multiz(at, stairs.dir | UP) == ahead)
			return take_step(follower, at, get_step(at, stairs.dir), stairs.dir, glide)
		var/turf/drop = GET_TURF_ABOVE(ahead)
		return drop && ERP_LEASH_NEAR(at, drop) && take_step(follower, at, drop, null, glide)
	return FALSE

/// Moves an end one step from `at` onto `target`, skipping its own move handlers. With `glide`, the line is drawn once
/// the other end's move is done.
/datum/component/erp_leash/proc/take_step(atom/movable/follower, turf/at, turf/target, direction, glide)
	moving = target
	if(line && glide)
		line.stepping = TRUE
	follower.Move(target, direction || get_dir(at, target), glide)
	moving = null
	line?.stepping = FALSE
	. = follower.loc != at
	if(.)
		last_step = world.time

/// Blocks a move past the leash length, with a balloon alert at most once a second.
/datum/component/erp_leash/proc/taut(mob/living/mover, message)
	if(COOLDOWN_FINISHED(src, taut_cd))
		COOLDOWN_START(src, taut_cd, 1 SECONDS)
		mover.balloon_alert(mover, message)
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/// Pulls the leashed along when the holder steps, or holds the holder back where the leashed can't follow.
/datum/component/erp_leash/proc/on_holder_pre_move(mob/living/source, atom/new_loc)
	SIGNAL_HANDLER
	var/turf/here = source.loc
	var/mob/living/leashed = parent
	var/turf/at = leashed.loc
	if(moving || !isturf(here) || !isturf(new_loc) || !isturf(at))
		return NONE
	if(hole)
		// Being dragged, they can only get closer. Held by it, they stay within the leash length.
		if(get_dist(new_loc, hole) <= (drag_timer ? get_dist(here, hole) : ERP_LEASH_LENGTH))
			return NONE
		return taut(source, "leash pulls taut!")
	// Allowed: a diagonal's second half once the leashed has stepped this tick, or a step starting or ending beside them.
	if((source.moving_diagonally == SECOND_DIAG_STEP && last_step == world.time) || ERP_LEASH_NEAR(at, here) || ERP_LEASH_NEAR(at, new_loc))
		return NONE
	var/after = rope_after(at, here, new_loc, source.moving_diagonally)
	if(after <= ERP_LEASH_LENGTH)
		return NONE
	if(retrace(leashed, at, here, source.glide_size))
		at = leashed.loc
		if(free_end != source || !isturf(at))
			return NONE
		after = rope_after(at, here, new_loc, source.moving_diagonally)
	// Held back if the leash would run longer than now, or no route measures it.
	if(after <= ERP_LEASH_LENGTH || (after < INFINITY && after <= rope_to(at, here)))
		return NONE
	if(last_step == world.time)
		line?.redrawing(leashed) // The holder isn't moving, so draw the line for the leashed's step.
	return taut(source, "leash pulls taut!")

/// Records the holder's step on the route, pulls the leashed after a forced move like stairs, and checks jumps once done.
/datum/component/erp_leash/proc/on_holder_moved(mob/living/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	var/turf/now = source.loc
	var/turf/old = old_loc
	if(moving)
		return
	if(!isturf(now) || !isturf(old))
		jumped()
		return
	var/near = ERP_LEASH_NEAR(old, now)
	var/fall = !near && fell(source, old)
	if(hole)
		if(fall && old == hole)
			stop_drag() // Fell in after them.
		else if(!near)
			jumped()
		return
	if(!near && source.currently_z_moving != CURRENTLY_Z_ASCENDING && !(fall && (locate(/obj/structure/stairs) in now)))
		jumped()
		return
	// A fall belongs to the step onto the hole, and a diagonal's two halves are one step.
	add_to_trail(old, now, !fall && source.moving_diagonally != SECOND_DIAG_STEP)
	var/mob/living/leashed = parent
	if(forced && isturf(leashed.loc) && rope_to(leashed.loc, now) > ERP_LEASH_LENGTH)
		retrace(leashed, leashed.loc, now, source.glide_size)

/// Whether `mover` just fell from `old` to the level below, or into the chasm the leashed dropped down.
/datum/component/erp_leash/proc/fell(atom/movable/mover, turf/old)
	if(hole && old == hole)
		var/datum/component/chasm/chasm = hole.GetComponent(/datum/component/chasm)
		if(chasm && ((!isturf(mover.loc) && get_turf(mover) == hole) || mover.loc == chasm.target_turf))
			return TRUE
	return (mover.currently_z_moving == CURRENTLY_Z_FALLING || mover.currently_z_moving == CURRENTLY_Z_FALLING_FROM_MOVE) && GET_TURF_BELOW(old) == mover.loc

/// Keeps the leashed within the leash length. When the leash moves them, an unsafe corner is refused so a diagonal
/// takes the other one.
/datum/component/erp_leash/proc/on_collar_pre_move(mob/living/source, turf/new_loc)
	SIGNAL_HANDLER
	if(moving)
		return new_loc != moving && !can_cross_safely(new_loc, source.loc) ? COMPONENT_MOVABLE_BLOCK_PRE_MOVE : NONE
	if(free_end == source || free_end == leash)
		return NONE
	var/turf/at = source.loc
	var/turf/hand = free_end.loc
	if(!isturf(at) || !isturf(new_loc) || !isturf(hand))
		return NONE
	if(hole)
		// Fallen: they can move around under the hole while their holder is dragged to it or held by it.
		var/turf/under = GET_TURF_BELOW(hole)
		if(under?.z != new_loc.z || get_dist(new_loc, under) <= max(1, get_dist(at, under)))
			return NONE
	else
		var/reach = rope_to(new_loc, hand)
		if(reach <= ERP_LEASH_LENGTH || (reach < INFINITY && reach <= rope_to(at, hand)))
			return NONE
	return taut(source, "too far!")

/// Stops the leashed climbing a z-level away from their holder.
/datum/component/erp_leash/proc/on_collar_z_move(mob/living/source, turf/start, turf/destination)
	SIGNAL_HANDLER
	if(moving || hole || free_end == source || free_end == leash || GET_TURF_ABOVE(start) != destination)
		return NONE
	var/turf/hand = free_end.loc
	if(!isturf(hand) || rope_to(destination, hand) <= ERP_LEASH_LENGTH)
		return NONE
	source.balloon_alert(source, "too far!")
	return COMPONENT_CANT_Z_MOVE

/**
 * Handles the leashed moving. A leash on the floor follows them. With a holder, the route behind them is dropped, and a
 * fall away from the holder starts the drag. Jumps are checked once done.
 */
/datum/component/erp_leash/proc/on_collar_moved(mob/living/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	var/turf/now = source.loc
	var/turf/old = old_loc
	if(free_end == source)
		return
	var/fall = fell(source, old)
	if(!fall && (!isturf(now) || !isturf(old)))
		jumped()
		return
	var/near = !fall && ERP_LEASH_NEAR(old, now)
	if(!near && !fall && source.currently_z_moving != CURRENTLY_Z_ASCENDING)
		jumped()
		return
	if(free_end == leash)
		add_to_trail(old, now, !fall && source.moving_diagonally != SECOND_DIAG_STEP)
		drag_floor_end(old, now)
		return
	followed(now)
	var/turf/hand = free_end.loc
	if(!isturf(hand))
		return
	if(hole)
		if(isturf(now) && rope_to(now, hand) <= ERP_LEASH_LENGTH)
			stop_drag() // Back up beside their holder.
	else if(fall && rope_to(now, hand) > ERP_LEASH_LENGTH)
		start_drag(old)

/// Moves a leash on the floor after the leashed: a step along the route, or straight onto the turf behind them.
/datum/component/erp_leash/proc/drag_floor_end(turf/behind, turf/now)
	var/turf/at = leash.loc
	var/mob/living/leashed = parent
	if(isturf(at) && (rope_to(at, now) <= ERP_LEASH_LENGTH || last_step == world.time || retrace(leash, at, now, leashed.glide_size)))
		return
	last_step = world.time
	line?.stepping = TRUE // The leashed's move draws the line once done.
	leash.forceMove(behind)
	line?.stepping = FALSE

/// Stops a leash on the floor being thrown, pushed or swept past its length.
/datum/component/erp_leash/proc/on_leash_pre_move(obj/item/source, atom/new_loc)
	SIGNAL_HANDLER
	var/turf/collar = get_turf(parent)
	var/turf/at = leash.loc
	if(moving || free_end != leash || !collar || !isturf(at) || !isturf(new_loc) || new_loc.z != collar.z)
		return NONE
	var/reach = get_dist(new_loc, collar)
	if(reach <= ERP_LEASH_LENGTH || (at.z == collar.z && reach <= get_dist(at, collar)))
		return NONE
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/// Updates the free end when the leash is picked up, put down or moved. A holder the leashed doesn't allow, or one out
/// of reach, drops it again (on_leash_equipped()).
/datum/component/erp_leash/proc/on_leash_moved(obj/item/source, atom/old_loc, dir, forced)
	SIGNAL_HANDLER
	var/atom/movable/end = ismob(leash.loc) ? leash.loc : leash
	if(end != leash && end != parent && end != free_end)
		var/turf/collar = get_turf(parent)
		var/turf/hand = get_turf(end)
		if(!may_hold(end) || (collar && hand && !ERP_LEASH_IN_REACH(collar, hand)))
			end = leash
	if(end != free_end)
		set_free_end(end)
	else if(end == leash && isturf(leash.loc))
		followed(leash.loc)

/// Makes a holder refused by on_leash_moved() let go, and moves the line when the holder swaps hands.
/datum/component/erp_leash/proc/on_leash_equipped(obj/item/source, mob/equipper, slot)
	SIGNAL_HANDLER
	if(free_end == leash)
		let_go(equipper)
	else if(free_end == equipper && line)
		line.set_hand(equipper.get_held_index_of_item(leash))

/// Called when an end moves without stepping: a teleport, jaunt, fall, shuttle or lift. Reach is checked once the move
/// is done, since a ride moves the ends one at a time.
/datum/component/erp_leash/proc/jumped()
	trail = null
	addtimer(CALLBACK(src, PROC_REF(check_reach)), 0, TIMER_UNIQUE | TIMER_NO_HASH_WAIT)

/// After a jump, keeps the ends together if they're in reach or in the same place, like a chasm's depths. Otherwise
/// separates them.
/datum/component/erp_leash/proc/check_reach()
	var/atom/movable/leashed = parent
	if(free_end == leashed)
		return
	if((leashed.loc && leashed.loc == free_end.loc) || (isturf(leashed.loc) && isturf(free_end.loc) && ERP_LEASH_IN_REACH(leashed.loc, free_end.loc)))
		stop_drag()
	else
		separate()

/// Leaves the leash, still hooked, at the leashed's feet.
/datum/component/erp_leash/proc/separate()
	SIGNAL_HANDLER
	stop_drag()
	trail = null
	var/turf/feet = get_turf(parent)
	if(free_end == parent || (free_end == leash && (!feet || leash.loc == feet)))
		return
	if(free_end == leash)
		leash.forceMove(feet)
	else
		let_go(free_end)

/// Makes `holder` drop the leash at the leashed's feet.
/datum/component/erp_leash/proc/let_go(mob/holder)
	to_chat(holder, span_warning("[leash] is yanked out of your grip!"))
	var/turf/feet = get_turf(parent)
	if(feet)
		holder.transferItemToLoc(leash, feet, force = TRUE)
	else
		holder.dropItemToGround(leash, force = TRUE)

/// The leashed or their holder drops into a chasm. The leashed dropping drags their holder toward it, like a hole. A
/// holder dropping in after them stops the drag; one dropping in alone lets go a tick later, as the drop can fire while
/// the line is being drawn.
/datum/component/erp_leash/proc/on_chasm_dropped(atom/movable/source, turf/chasm)
	SIGNAL_HANDLER
	if(source == parent)
		if(!hole && free_end != source && ismob(free_end) && source.loc == chasm)
			start_drag(chasm)
	else if(chasm == hole)
		stop_drag()
	else
		addtimer(CALLBACK(src, PROC_REF(separate)), 0, TIMER_UNIQUE)

/// Starts dragging the holder toward `drop`, the hole the leashed fell down, after a moment to let go.
/datum/component/erp_leash/proc/start_drag(turf/drop)
	var/mob/living/holder = free_end
	if(holder.z != drop.z)
		separate()
		return
	hole = drop
	trail = null
	var/mob/living/leashed = parent
	if(locate(/obj/structure/stairs) in leashed.loc)
		to_chat(holder, span_warning("[leashed] goes down the stairs, and [leash] pulls you after [leashed.p_them()]!"))
	else
		to_chat(holder, span_userdanger("[leashed] falls, and [leash] drags you toward the drop! Let go of it, or follow!"))
	drag_timer = addtimer(CALLBACK(src, PROC_REF(drag_to_hole)), ERP_LEASH_DRAG_DELAY, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// Drags the holder a step toward the hole, where they fall in as normal. If they're buckled or can't fall through, the
/// leash holds them there instead. Ends if the leashed didn't fall or came back up.
/datum/component/erp_leash/proc/drag_to_hole()
	var/mob/living/leashed = parent
	// The leashed is on the hole's level and not mid-fall (a chasm's TRAIT_NO_TRANSFORM).
	if(isturf(leashed.loc) && leashed.z == hole.z && (leashed.loc != hole || !HAS_TRAIT(leashed, TRAIT_NO_TRANSFORM)))
		check_reach()
		return
	var/mob/living/holder = free_end
	var/turf/at = holder.loc
	if(!isturf(at) || at.z != hole.z)
		separate()
		return
	var/held = holder.buckled || holder.anchored
	if(!held && at != hole)
		take_step(holder, at, ERP_LEASH_NEAR(at, hole) ? hole : get_step_towards(at, hole))
		if(QDELETED(src))
			return
	var/turf/now = holder.loc
	if(!isturf(now) || !ERP_LEASH_NEAR(at, now))
		jumped() // Fell in after them, or was carried off.
	else if(held || now == hole)
		deltimer(drag_timer)
		drag_timer = null
		to_chat(holder, held ? span_warning("[leash] strains against you and holds you where you are.") \
			: span_warning("[leash] runs taut down the drop and holds you there."))
	else if(now != at && hole) // No hole means a chasm took them, so no drag message.
		to_chat(holder, span_danger("[leash] drags you toward the drop!"))

/// Ends the drag toward the hole, or the hold by it.
/datum/component/erp_leash/proc/stop_drag()
	hole = null
	deltimer(drag_timer)
	drag_timer = null

/// Pulls the leashed a step toward the holder, unless the step is unsafe.
/datum/component/erp_leash/proc/on_tug(obj/item/source, mob/user)
	SIGNAL_HANDLER
	var/mob/living/leashed = parent
	if(user == leashed || last_step == world.time || !COOLDOWN_FINISHED(src, tug_cd))
		return
	COOLDOWN_START(src, tug_cd, 1 SECONDS)
	var/turf/target = get_step_towards(leashed, user)
	if(!can_cross_safely(target, leashed.loc))
		leashed.balloon_alert(user, "won't pull [leashed.p_them()] there!")
		return
	take_step(leashed, leashed.loc, target)
	leashed.adjust_stamina_loss(10)
	leashed.visible_message(span_warning("[leashed] is pulled in as [user] tugs [source]!"),\
			span_userdanger("[user] suddenly tugs [source], pulling you closer!"),\
			span_userdanger("A sudden tug against your neck pulls you ahead!"))

/datum/component/erp_leash/proc/on_resist(datum/source, mob/living/user)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(break_out))

/// The leashed unhooks themselves over the leash's breakout time.
/datum/component/erp_leash/proc/break_out()
	var/mob/living/leashed = parent
	leashed.visible_message(span_warning("[leashed] attempts to unhook [leashed.p_them()]self from the leash!"), \
		span_userdanger("You start to unhook yourself from the leash..."), \
		span_userdanger("You fumble in the dark, looking to unhook the leash..."))
	if(do_after(leashed, leash.breakouttime, target = leashed))
		to_chat(leashed, span_notice("You unhook yourself from the leash."))
		qdel(src)

/**
 * The leash's line, blank while the ends are out of reach. It leaves the outer edge of the holding hand, with offsets
 * read off the human body sprite. West mirrors east.
 */
/datum/beam/held/leash
	righthand_s_px = -7
	righthand_s_py = -3
	righthand_e_px = 0
	righthand_e_py = -6
	righthand_w_px = -5
	righthand_w_py = -6
	righthand_n_px = 7
	righthand_n_py = -3
	lefthand_s_px = 7
	lefthand_s_py = -3
	lefthand_e_px = 5
	lefthand_e_py = -6
	lefthand_w_px = 0
	lefthand_w_py = -6
	lefthand_n_px = -7
	lefthand_n_py = -3
	/// TRUE while an end steps with the other end's move, which draws the line once done.
	var/stepping = FALSE
	/// TRUE while a redraw is waiting for a later move or catch_up().
	var/stale = FALSE
	/// The holding hand's index. Hands past the first pair draw held items shifted, so the line shifts too.
	var/held_index = 0

/// Turning moves the hand, so the line is redrawn from it this tick.
/datum/beam/held/leash/handle_dir_change(atom/movable/source, olddir, newdir)
	update_offsets(newdir)
	stale = TRUE
	addtimer(CALLBACK(src, PROC_REF(catch_up)), 0, TIMER_UNIQUE)

/// Moves the line to another of the holder's hands.
/datum/beam/held/leash/proc/set_hand(hand_index)
	if(!hand_index || hand_index == held_index)
		return
	held_index = hand_index
	lefthand = IS_LEFT_INDEX(held_index)
	update_offsets(origin.dir)
	stale = TRUE
	addtimer(CALLBACK(src, PROC_REF(catch_up)), 0, TIMER_UNIQUE)

/// Draws a waiting redraw that no move picked up, gliding over the step or ERP_LEASH_TURN_GLIDE for a turn.
/datum/beam/held/leash/proc/catch_up()
	if(stale)
		pending_animate_time = max(pending_animate_time, ERP_LEASH_TURN_GLIDE)
		redrawing()

/// A leash on the floor draws its line from itself, not a hand.
/datum/beam/held/leash/update_offsets(user_dir)
	if(ismob(origin))
		. = ..()
		add_extra_hand_offset(user_dir)
		return
	override_origin_pixel_x = origin.pixel_x
	override_origin_pixel_y = origin.pixel_y

/// Extra hands, like a moth's chest arms, shift held items, so the line shifts with them.
/datum/beam/held/leash/proc/add_extra_hand_offset(user_dir)
	if(held_index <= 2 || !iscarbon(origin))
		return
	var/mob/living/carbon/holder = origin
	if(held_index > length(holder.hand_bodyparts))
		return
	var/obj/item/bodypart/arm/hand = holder.hand_bodyparts[held_index]
	var/datum/worn_feature_offset/offset = hand?.held_hand_offset
	if(isnull(offset))
		return
	// The turn's new direction, not the holder's, which hasn't turned yet when this runs
	var/dir_name = dir2text(ISDIAGONALDIR(user_dir) ? (user_dir & (EAST|WEST)) : user_dir)
	if(length(offset.offset_x))
		override_origin_pixel_x += (dir_name in offset.offset_x) ? offset.offset_x[dir_name] : offset.offset_x["south"]
	if(length(offset.offset_y))
		override_origin_pixel_y += (dir_name in offset.offset_y) ? offset.offset_y[dir_name] : offset.offset_y["south"]

/**
 * Draws the line once a tick, after the last end has moved. A step with the other end's move, or a diagonal's first
 * half, waits for the next move or catch_up(). Blank while an end is inside something or on another z-level, where a
 * normal beam would delete itself.
 */
/datum/beam/held/leash/redrawing(atom/movable/mover, atom/oldloc, direction)
	if(stepping || mover?.moving_diagonally == FIRST_DIAG_STEP)
		pending_animate_time = max(pending_animate_time, ICON_SIZE_ALL / max(mover.glide_size, MIN_GLIDE_SIZE) * world.tick_lag)
		stale = TRUE
		addtimer(CALLBACK(src, PROC_REF(catch_up)), 0, TIMER_UNIQUE)
		return
	if(QDELETED(origin) || QDELETED(target) || (isturf(origin.loc) && isturf(target.loc) && origin.z == target.z))
		return ..()
	Draw()

/// Draws only while the ends are on one z-level and in reach. Skips CheckToolReach(), whose dummy object would fall into
/// a chasm under the line.
/datum/beam/held/leash/Draw(atom/movable/mover, atom/oldloc)
	stale = FALSE
	if(isturf(origin.loc) && isturf(target.loc) && ERP_LEASH_IN_REACH(origin.loc, target.loc))
		return ..()
	QDEL_LIST(elements)
	last_draw_valid = FALSE // Back in reach, it's drawn fresh instead of gliding from its old position.

#undef ERP_LEASH_LENGTH
#undef ERP_LEASH_TRAIL_MAX
#undef ERP_LEASH_DRAG_DELAY
#undef ERP_LEASH_TURN_GLIDE
#undef ERP_LEASH_NEAR
#undef ERP_LEASH_IN_REACH
