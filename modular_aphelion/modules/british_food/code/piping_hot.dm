/**
 * Food fresh out of a hot vendor. It steams until it cools, and every bite before then burns the
 * eater's tongue a little and puts them off eating for a moment. The bite still goes down.
 * Masochists keep eating. Eaters the heat can't hurt don't notice it.
 *
 * One timer cools it; nothing processes. Food taken out of a hot pack gets the heat that is left
 * through pass_to().
 */
/datum/component/piping_hot
	/// world.time when the food has cooled
	var/cool_at
	/// Keeps a burned eater off the food for a moment
	COOLDOWN_DECLARE(scald_pause)

/datum/component/piping_hot/Initialize(duration)
	if(!isitem(parent) || !IS_EDIBLE(parent))
		return COMPONENT_INCOMPATIBLE
	cool_at = world.time + duration
	addtimer(CALLBACK(src, PROC_REF(cool_down)), duration)

/datum/component/piping_hot/RegisterWithParent()
	RegisterSignal(parent, COMSIG_FOOD_ATTEMPT_EAT, PROC_REF(on_attempt_eat))
	RegisterSignal(parent, COMSIG_FOOD_EATEN, PROC_REF(on_bite))
	RegisterSignal(parent, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(parent, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))
	var/atom/food = parent
	food.update_appearance(UPDATE_OVERLAYS)

/datum/component/piping_hot/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_FOOD_ATTEMPT_EAT, COMSIG_FOOD_EATEN, COMSIG_ATOM_EXAMINE, COMSIG_ATOM_UPDATE_OVERLAYS))
	var/atom/food = parent
	if(!QDELETED(food))
		food.update_appearance(UPDATE_OVERLAYS)

/// Refuses the next bite while a burned tongue recovers, so eating stops.
/datum/component/piping_hot/proc/on_attempt_eat(datum/source, mob/living/eater, mob/living/feeder)
	SIGNAL_HANDLER
	if(COOLDOWN_FINISHED(src, scald_pause) || HAS_TRAIT(eater, TRAIT_MASOCHISM) || !can_scald(eater))
		return NONE
	eater.balloon_alert(feeder, "too hot!")
	return BLOCK_EAT_ATTEMPT

/// Burns the eater's tongue and, unless they enjoy it, puts them off the next bite.
/datum/component/piping_hot/proc/on_bite(datum/source, mob/living/eater, mob/living/feeder, bitecount, bite_consumption)
	SIGNAL_HANDLER
	if(!can_scald(eater))
		return
	eater.apply_damage(1, BURN, BODY_ZONE_HEAD)
	var/masochist = HAS_TRAIT(eater, TRAIT_MASOCHISM)
	if(!masochist)
		COOLDOWN_START(src, scald_pause, 3 SECONDS)
	var/self_message = "You burn your tongue on [parent]! It's still piping hot."
	eater.visible_message(
		span_warning("[eater] yelps and fans [eater.p_their()] mouth."),
		masochist ? span_nicegreen(self_message) : span_danger(self_message),
	)

/**
 * Returns whether the heat hurts this eater. It doesn't if they resist heat or lava, can't feel
 * pain, or have a body built for lavaland heat (lizards, golems, kobolds) or hotter.
 *
 * Arguments:
 * - eater: Who is taking the bite.
 */
/datum/component/piping_hot/proc/can_scald(mob/living/eater)
	if(HAS_TRAIT(eater, TRAIT_RESISTHEAT) || HAS_TRAIT(eater, TRAIT_LAVA_IMMUNE) || HAS_TRAIT(eater, TRAIT_ANALGESIA))
		return FALSE
	return eater.get_body_temp_heat_damage_limit() < BODYTEMP_HEAT_LAVALAND_SAFE

/// Warns whoever looks that it's still hot.
/datum/component/piping_hot/proc/on_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_warning("It's still piping hot.")

/// Draws the steam.
/datum/component/piping_hot/proc/on_update_overlays(atom/source, list/overlays)
	SIGNAL_HANDLER
	overlays += mutable_appearance('icons/effects/steam.dmi', "steam_triple", ABOVE_OBJ_LAYER)

/// Ends the hot window: the steam and the burn go with the component.
/datum/component/piping_hot/proc/cool_down()
	qdel(src)

/**
 * Gives food taken out of this one the heat this one has left.
 *
 * Arguments:
 * - bare_food: The food that came out.
 */
/datum/component/piping_hot/proc/pass_to(obj/item/food/bare_food)
	if(cool_at > world.time)
		bare_food.AddComponent(/datum/component/piping_hot, cool_at - world.time)
