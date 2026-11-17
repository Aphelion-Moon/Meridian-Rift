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
