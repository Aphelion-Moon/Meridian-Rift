/mob/living/basic/frog
	inhand_holder_type = /obj/item/mob_holder/frog

/mob/living/basic/frog/rare
	inhand_holder_type = /obj/item/mob_holder/frog/rare

/mob/living/basic/frog/crazy/rare
	inhand_holder_type = /obj/item/mob_holder/frog/rare

/**
 * A held frog that can be eaten once it is dead, in one bite, like any food.
 *
 * It is food only while someone tries to eat it. If the attempt ends without a swallow, it is a
 * plain holder again, so nothing else can use up the meal. Eating deletes the body.
 */
/obj/item/mob_holder/frog
	/// Reagents the frog is worth, all swallowed in one bite
	var/list/food_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/nutriment/protein = 2)
	/// Who is trying to eat it right now
	var/datum/weakref/meal_eater

/// A frog with hallucinogen in its bite. Swallowed whole, it is a strong sunshine pill.
/obj/item/mob_holder/frog/rare
	// food is half pure, which halves the mushroom overdose to 15
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/drug/mushroomhallucinogen = 10,
		/datum/reagent/toxin/mindbreaker = 25,
	)

/// Clicking someone with a dead one outside combat mode feeds it to them, if it may be eaten.
/obj/item/mob_holder/frog/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(. || user.combat_mode || !iscarbon(target) || held_mob.stat != DEAD)
		return
	. = TRUE
	user.changeNext_move(attack_speed)
	var/refusal = eat_refusal()
	if(refusal)
		balloon_alert(user, refusal)
		return
	start_meal(target, user)

/**
 * Says why the held frog's body can't be eaten.
 *
 * Returns:
 * - text: A balloon alert, or null if it can be eaten.
 */
/obj/item/mob_holder/frog/proc/eat_refusal()
	// a shapeshifter carries its real body inside, which would go with it
	if(locate(/datum/status_effect/shapechange_mob) in held_mob.status_effects)
		return "can't eat that!"
	if(HAS_TRAIT(held_mob, TRAIT_TAMED) || istype(held_mob, /mob/living/basic/frog/icemoon_facility) || held_mob.name != initial(held_mob.name))
		return "someone's pet!"
	for(var/friend_ref in held_mob.allies)
		var/mob/living/friend = locate(friend_ref)
		// owners are people other than regal rats
		if(friend != held_mob && istype(friend) && !QDELETED(friend) && friend.mind && !isregalrat(friend))
			return "someone's pet!"
	return null

/**
 * Makes the holder food and has the eater try it, as clicking them with food does. Does nothing
 * while someone is trying already.
 *
 * Arguments:
 * - eater: Who eats it.
 * - feeder: Who feeds it to them, the eater when eating it themselves.
 */
/obj/item/mob_holder/frog/proc/start_meal(mob/living/carbon/eater, mob/living/feeder)
	if(meal_eater || DOING_INTERACTION(feeder, eater))
		return
	meal_eater = WEAKREF(eater)
	AddComponentFrom(\
		SOURCE_EDIBLE_INNATE,\
		/datum/component/edible,\
		initial_reagents = food_reagents,\
		foodtypes = MEAT | RAW,\
		eat_time = 3 SECONDS,\
		tastes = list("frog" = 1, "slime" = 1),\
		eatverbs = list("devour", "gulp", "swallow"),\
		bite_consumption = counterlist_sum(food_reagents),\
		on_consume = CALLBACK(src, PROC_REF(swallowed)),\
	)
	RegisterSignal(feeder, COMSIG_DO_AFTER_ENDED, PROC_REF(on_attempt_ended))
	attack(eater, feeder)
	if(!QDELETED(src) && !DOING_INTERACTION(feeder, eater))
		end_meal(feeder)

/**
 * When the feeder stops trying, lets go of a frog that may no longer be eaten, before it is
 * bitten. Otherwise the holder turns plain again a moment later, unless it was swallowed.
 *
 * Arguments:
 * - feeder: Whose action ended.
 */
/obj/item/mob_holder/frog/proc/on_attempt_ended(mob/living/feeder)
	SIGNAL_HANDLER
	var/mob/living/eater = meal_eater?.resolve()
	// another of the feeder's actions ended
	if(eater && DOING_INTERACTION(feeder, eater))
		return
	// it came back to life, or became a pet
	if(held_mob.stat != DEAD || eat_refusal())
		release()
		return
	addtimer(CALLBACK(src, PROC_REF(end_meal), feeder), 1, TIMER_UNIQUE)

/**
 * Makes the holder plain again after an attempt that didn't end in a swallow.
 *
 * Arguments:
 * - feeder: Who was feeding it.
 */
/obj/item/mob_holder/frog/proc/end_meal(mob/living/feeder)
	var/mob/living/eater = meal_eater?.resolve()
	if(eater && DOING_INTERACTION(feeder, eater))
		return
	UnregisterSignal(feeder, COMSIG_DO_AFTER_ENDED)
	meal_eater = null
	RemoveComponentSource(SOURCE_EDIBLE_INNATE, /datum/component/edible)
	QDEL_NULL(reagents)

/**
 * Deletes the swallowed body, which deletes the holder.
 *
 * Arguments:
 * - eater: Who swallowed it.
 * - feeder: Who fed it to them.
 */
/obj/item/mob_holder/frog/proc/swallowed(mob/living/eater, mob/living/feeder)
	log_combat(eater, held_mob, "swallowed", addition = feeder == eater ? "dead" : "dead, fed by [key_name(feeder)]")
	qdel(held_mob)

/**
 * A cockroach that dies whole leaves a dead roach and no guts, in the hand or pocket that held it,
 * unless it keeps its own body. A bloodroach bursts, so it leaves its usual mess and no body.
 */
/mob/living/basic/cockroach/death(gibbed)
	// no item when the body stays, a shapeshifter's caster comes back, or it bursts
	if(gibbed || stat == DEAD || !(basic_mob_flags & DEL_ON_DEATH) || (locate(/datum/status_effect/shapechange_mob) in status_effects) || istype(src, /mob/living/basic/cockroach/bloodroach))
		return ..()
	var/atom/drop_loc = drop_location()
	var/mob/living/carrier
	var/hand_index
	var/slot
	var/obj/item/mob_holder/holder = loc
	if(istype(holder))
		drop_loc = holder.loc
		if(isliving(drop_loc))
			carrier = drop_loc
			hand_index = carrier.get_held_index_of_item(holder)
			slot = carrier.get_slot_by_item(holder) & (ITEM_SLOT_LPOCKET | ITEM_SLOT_RPOCKET)
			drop_loc = carrier.drop_location()
	if(istype(drop_loc, /obj/machinery/microwave))
		return ..()
	var/obj/item/food/deadroach/corpse = new(drop_loc)
	corpse.copy_corpse(src)
	// the guts are still in the body
	RemoveElement(/datum/element/death_drops, /obj/effect/decal/cleanable/insectguts)
	// deleting us takes the holder too, which frees its hand or pocket
	. = ..()
	if(hand_index)
		carrier.put_in_hand(corpse, hand_index)
	else if(slot)
		carrier.equip_to_slot_if_possible(corpse, slot, disable_warning = TRUE)

/// A cockroach that died whole, lying on its back
/obj/item/food/deadroach
	name = "dead cockroach"
	desc = "It lies on its back with its legs in the air."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "cockroach_no_animation"
	w_class = WEIGHT_CLASS_TINY
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 2)
	foodtypes = BUGS | RAW
	tastes = list("crunchy bug" = 1)
	eatverbs = list("chomp", "gobble")
	bite_consumption = 2
	eat_time = 1 SECONDS
	decomp_type = null
	// random food, gifts and mystery boxes don't roll one
	spawn_blacklisted = TRUE

/obj/item/food/deadroach/Initialize(mapload)
	. = ..()
	transform = transform.Scale(1, -1)

/**
 * Takes the dead roach's name, sprite and tint.
 *
 * Arguments:
 * - roach: The cockroach this was.
 */
/obj/item/food/deadroach/proc/copy_corpse(mob/living/basic/cockroach/roach)
	name = "dead [roach.name]"
	icon = roach.icon
	icon_state = roach.icon_dead
	if(roach.color)
		add_atom_colour(roach.color, FIXED_COLOUR_PRIORITY)
