/**
 * Turns a dead frog into a food item when someone picks it up.
 * A pet frog, or a frog that a player was in, keeps its body and is held as usual.
 */
/mob/living/basic/frog/mob_pickup(mob/living/user)
	if(stat != DEAD || mind || is_pet())
		return ..()
	// a frog with mushroom hallucinogen in its bite is a rare one
	var/corpse_type = poison_type == /datum/reagent/drug/mushroomhallucinogen ? /obj/item/food/deadfrog/rare : /obj/item/food/deadfrog
	var/obj/item/food/deadfrog/corpse = new corpse_type(drop_location())
	corpse.name = "dead [name]"
	corpse.icon = icon
	corpse.icon_state = icon_dead
	user.visible_message(span_warning("[user] scoops up [src]!"))
	user.put_in_hands(corpse)
	qdel(src)

/// Returns whether the frog is a pet. A pet is tamed, has a name, or belongs to a player.
/mob/living/basic/frog/proc/is_pet()
	if(HAS_TRAIT(src, TRAIT_TAMED) || name != initial(name) || istype(src, /mob/living/basic/frog/icemoon_facility))
		return TRUE
	for(var/friend_ref in allies)
		var/mob/living/friend = locate(friend_ref)
		// an owner is a player, and a regal rat's frogs aren't pets
		if(friend != src && istype(friend) && !QDELETED(friend) && friend.mind && !isregalrat(friend))
			return TRUE
	return FALSE

/// The food item a dead frog turns into when it is picked up
/obj/item/food/deadfrog
	name = "dead frog"
	desc = "They seem a little dead."
	icon = 'icons/mob/simple/animal.dmi'
	icon_state = "frog_dead"
	w_class = WEIGHT_CLASS_TINY
	food_reagents = list(/datum/reagent/consumable/nutriment = 3, /datum/reagent/consumable/nutriment/protein = 2)
	foodtypes = MEAT | RAW
	tastes = list("frog" = 1, "slime" = 1)
	eatverbs = list("devour", "gulp", "swallow")
	bite_consumption = 5
	decomp_type = null
	// random food, gifts and mystery boxes don't roll one
	spawn_blacklisted = TRUE

/// A dead rare frog. Eating it gives a strong trip, from the same two drugs as a sunshine pill.
/obj/item/food/deadfrog/rare
	name = "dead rare frog"
	icon_state = "rare_frog_dead"
	// food reagents are half pure, so the mushroom overdoses at 15 units, not 30
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 3,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/drug/mushroomhallucinogen = 10,
		/datum/reagent/toxin/mindbreaker = 25,
	)
	bite_consumption = 40

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
