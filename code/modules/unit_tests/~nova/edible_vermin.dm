/// Eating a live mouse or bloodroach leaves nothing: no corpse in hand or on the floor, no guts or blood. A player who left goes on as a ghost where it was eaten.
/datum/unit_test/edible_vermin_eaten
	/// Key of the player who left their mouse
	var/abandoned_key = "ediblevermintest"

/datum/unit_test/edible_vermin_eaten/Run()
	var/mob/living/carbon/human/consistent/eater = allocate(__IMPLIED_TYPE__)

	var/mob/living/basic/mouse/mouse = allocate(__IMPLIED_TYPE__)
	mouse.mob_pickup(eater)
	var/obj/item/mob_holder/edible/holder = mouse.loc
	TEST_ASSERT(istype(holder), "A picked up mouse must be in an edible holder")
	holder.eat_time = 0
	holder.melee_attack_chain(eater, eater)
	TEST_ASSERT(QDELETED(mouse) && QDELETED(holder), "An eaten mouse and its holder must be deleted")
	TEST_ASSERT_NULL(eater.is_holding_item_of_type(/obj/item/food/deadmouse), "Eating a mouse must not leave a dead mouse in hand")
	TEST_ASSERT_NULL(locate(/obj/item/food/deadmouse) in eater.loc, "Eating a mouse must not leave a dead mouse on the floor")
	TEST_ASSERT(eater.has_reagent(/datum/reagent/consumable/nutriment), "The eater must get the mouse's nutriment")

	var/decals_before = count_decals(eater)
	var/mob/living/basic/cockroach/bloodroach/roach = allocate(__IMPLIED_TYPE__)
	roach.mob_pickup(eater)
	holder = roach.loc
	TEST_ASSERT(istype(holder), "A picked up bloodroach must be in an edible holder")
	holder.eat_time = 0
	holder.melee_attack_chain(eater, eater)
	TEST_ASSERT(QDELETED(roach) && QDELETED(holder), "An eaten bloodroach and its holder must be deleted")
	TEST_ASSERT_NULL(eater.is_holding_item_of_type(/obj/item/food/deadroach), "Eating a bloodroach must not leave a dead roach in hand")
	TEST_ASSERT_EQUAL(count_decals(eater), decals_before, "An eaten bloodroach must not splatter blood or leave guts")

	var/mob/living/basic/mouse/abandoned = allocate(__IMPLIED_TYPE__)
	abandoned.mind_initialize()
	abandoned.ckey = abandoned_key
	abandoned.mob_pickup(eater)
	holder = abandoned.loc
	holder.eat_time = 0
	holder.melee_attack_chain(eater, eater)
	TEST_ASSERT(QDELETED(abandoned), "A mouse whose player left must be eaten without asking")
	var/mob/ghost = get_mob_by_ckey(abandoned_key)
	TEST_ASSERT(isobserver(ghost) && get_turf(ghost) == get_turf(eater), "A mouse whose player left must leave them a ghost where it was eaten")

/// Takes the key off the ghost of the player who left, since deleting a mob that still has a key stack traces.
/datum/unit_test/edible_vermin_eaten/Destroy()
	var/mob/keyed = get_mob_by_ckey(abandoned_key)
	if(keyed)
		keyed.ckey = null
	return ..()

/**
 * Counts the messes near a spot.
 *
 * Arguments:
 * - center: Where to count around.
 */
/datum/unit_test/edible_vermin_eaten/proc/count_decals(atom/center)
	. = 0
	for(var/obj/effect/decal/cleanable/mess in range(2, center))
		.++

/// Pets, tamed or named critters, shapeshifters and anything alive in a pacifist's hand are refused, but a regal rat's minions are not.
/datum/unit_test/edible_vermin_refusals

/datum/unit_test/edible_vermin_refusals/Run()
	var/mob/living/carbon/human/consistent/eater = allocate(__IMPLIED_TYPE__)
	var/mob/living/carbon/human/consistent/owner = allocate(__IMPLIED_TYPE__)
	owner.mind_initialize()

	var/mob/living/basic/mouse/brown/tom/tom = allocate(__IMPLIED_TYPE__)
	check_refused(eater, tom, "Tom")

	var/mob/living/basic/mouse/pet = allocate(__IMPLIED_TYPE__)
	pet.befriend(owner)
	check_refused(eater, pet, "A befriended mouse")

	var/mob/living/basic/mouse/named = allocate(__IMPLIED_TYPE__)
	named.name = "Mik"
	check_refused(eater, named, "A named mouse")

	var/mob/living/carbon/human/consistent/wizard = allocate(__IMPLIED_TYPE__)
	var/mob/living/basic/mouse/disguise = allocate(__IMPLIED_TYPE__)
	disguise.apply_status_effect(/datum/status_effect/shapechange_mob, wizard)
	check_refused(eater, disguise, "A shapeshifted wizard")
	// turn back first, as deleting a caster inside its form trips the shapeshift cleanup
	disguise.remove_status_effect(/datum/status_effect/shapechange_mob)

	var/mob/living/basic/mouse/plain = allocate(__IMPLIED_TYPE__)
	ADD_TRAIT(eater, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	check_refused(eater, plain, "A live mouse in a pacifist's hand")
	REMOVE_TRAIT(eater, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)

	var/mob/living/basic/regal_rat/king = allocate(__IMPLIED_TYPE__)
	king.mind_initialize()
	var/mob/living/basic/mouse/recruit = allocate(__IMPLIED_TYPE__)
	SEND_SIGNAL(recruit, COMSIG_REGAL_RAT_RIOTED, king)
	var/mob/living/basic/mouse/rat/minion = locate() in run_loc_floor_bottom_left
	TEST_ASSERT_NOTNULL(minion, "A rioted mouse must turn into a rat")
	minion.mob_pickup(eater)
	var/obj/item/mob_holder/edible/holder = minion.loc
	holder.eat_time = 0
	holder.melee_attack_chain(eater, eater)
	TEST_ASSERT(QDELETED(minion), "A regal rat's minion must be eaten")

/**
 * Has the eater try to eat the mouse, which must stay alive in a holder that never became food.
 *
 * Arguments:
 * - eater: Who tries to eat it.
 * - mouse: The mouse to pick up and try.
 * - case_name: What the mouse is, for failure messages.
 */
/datum/unit_test/edible_vermin_refusals/proc/check_refused(mob/living/carbon/human/eater, mob/living/basic/mouse/mouse, case_name)
	mouse.mob_pickup(eater)
	var/obj/item/mob_holder/edible/holder = mouse.loc
	TEST_ASSERT(istype(holder), "[case_name] must be in an edible holder when picked up")
	holder.eat_time = 0
	holder.melee_attack_chain(eater, eater)
	TEST_ASSERT(!QDELETED(mouse) && mouse.loc == holder, "[case_name] must not be eaten")
	TEST_ASSERT(!IS_EDIBLE(holder), "[case_name] must not make its holder food")
	holder.release(display_messages = FALSE)

/// An attempt that ends without a swallow leaves a plain holder, and a critter befriended mid-bite is let go unbitten.
/datum/unit_test/edible_vermin_mid_meal

/datum/unit_test/edible_vermin_mid_meal/Run()
	var/mob/living/carbon/human/consistent/masked_eater = allocate(__IMPLIED_TYPE__)
	var/obj/item/clothing/mask/gas/mask = allocate(__IMPLIED_TYPE__)
	masked_eater.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK)
	var/mob/living/basic/mouse/kept = allocate(__IMPLIED_TYPE__)
	kept.mob_pickup(masked_eater)
	var/obj/item/mob_holder/edible/holder = kept.loc
	TEST_ASSERT(istype(holder), "A picked up mouse must be in an edible holder")
	holder.melee_attack_chain(masked_eater, masked_eater)
	TEST_ASSERT(kept.loc == holder && !IS_EDIBLE(holder) && !holder.reagents, "A failed attempt must leave a plain holder, with no food in it")

	var/mob/living/carbon/human/consistent/eater = allocate(__IMPLIED_TYPE__)
	eater.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	var/mob/living/carbon/human/consistent/owner = allocate(__IMPLIED_TYPE__)
	owner.mind_initialize()
	var/mob/living/basic/mouse/befriended = allocate(__IMPLIED_TYPE__)
	befriended.mob_pickup(eater)
	holder = befriended.loc
	holder.eat_time = 1
	holder.melee_attack_chain(eater, eater)
	befriended.befriend(owner)
	sleep(0.5 SECONDS)
	TEST_ASSERT(!QDELETED(befriended) && isturf(befriended.loc), "A mouse befriended mid-bite must be let go")
	TEST_ASSERT(!eater.has_reagent(/datum/reagent/consumable/nutriment), "A mouse let go mid-bite must not be bitten")

/// A roach killed in hand leaves its body in that same hand and no guts, a squashed or burst one leaves no body, and a pest-sprayed one only keeps its own.
/datum/unit_test/edible_vermin_dead_roach

/datum/unit_test/edible_vermin_dead_roach/Run()
	var/mob/living/carbon/human/consistent/carrier = allocate(__IMPLIED_TYPE__)
	var/mob/living/basic/cockroach/roach = allocate(__IMPLIED_TYPE__)
	roach.mob_pickup(carrier)
	var/obj/item/mob_holder/holder = roach.loc
	var/hand_index = carrier.get_held_index_of_item(holder)
	TEST_ASSERT(hand_index, "A picked up roach must be in hand")
	carrier.swap_hand(carrier.get_inactive_hand_index())
	roach.death()
	TEST_ASSERT(QDELETED(roach) && QDELETED(holder), "A roach killed in hand and its holder must be deleted")
	TEST_ASSERT(istype(carrier.get_item_for_held_index(hand_index), /obj/item/food/deadroach), "A roach killed in hand must leave its body in that hand")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/insectguts) in carrier.loc, "A roach that leaves its body must not leave guts too")

	var/mob/living/basic/cockroach/squashed = allocate(__IMPLIED_TYPE__)
	var/datum/component/squashable/squash = squashed.GetComponent(/datum/component/squashable)
	squash.Squish(squashed)
	TEST_ASSERT(QDELETED(squashed), "A squashed roach must be gone")
	TEST_ASSERT_NULL(locate(/obj/item/food/deadroach) in run_loc_floor_bottom_left, "A squashed roach must leave no body")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/insectguts) in run_loc_floor_bottom_left, "A squashed roach must still leave guts")

	var/mob/living/basic/cockroach/bloodroach/burst = allocate(__IMPLIED_TYPE__)
	burst.death()
	TEST_ASSERT_NULL(locate(/obj/item/food/deadroach) in run_loc_floor_bottom_left, "A burst bloodroach must leave no body")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/decal/cleanable/blood) in run_loc_floor_bottom_left, "A burst bloodroach must still splatter blood")

	var/mob/living/basic/cockroach/sprayed = allocate(__IMPLIED_TYPE__)
	sprayed.apply_status_effect(/datum/status_effect/bugkiller_death)
	sprayed.remove_status_effect(/datum/status_effect/bugkiller_death)
	TEST_ASSERT(!QDELETED(sprayed) && sprayed.stat == DEAD, "A pest-sprayed roach must keep its body")
	TEST_ASSERT_NULL(locate(/obj/item/food/deadroach) in run_loc_floor_bottom_left, "A pest-sprayed roach must not leave a second body")

/// A mob deleted while held takes its holder with it, a bee let go of stays alive, and a shapeshifter turning back while held comes back where it was held.
/datum/unit_test/mob_holder_fix

/datum/unit_test/mob_holder_fix/Run()
	var/mob/living/carbon/human/consistent/carrier = allocate(__IMPLIED_TYPE__)
	var/mob/living/basic/mouse/doomed = allocate(__IMPLIED_TYPE__)
	doomed.mob_pickup(carrier)
	var/obj/item/mob_holder/holder = doomed.loc
	qdel(doomed)
	TEST_ASSERT(QDELETED(holder) && !carrier.is_holding(holder), "A mob deleted while held must take its holder out of the hand with it")

	var/mob/living/basic/bee/dropped = allocate(__IMPLIED_TYPE__)
	dropped.mob_pickup(carrier)
	carrier.dropItemToGround(dropped.loc)
	TEST_ASSERT(!QDELETED(dropped) && isturf(dropped.loc), "A dropped bee must be let go alive")

	var/mob/living/basic/bee/thrown = allocate(__IMPLIED_TYPE__)
	thrown.mob_pickup(carrier)
	carrier.throw_item(get_step(carrier, NORTH))
	TEST_ASSERT(!QDELETED(thrown), "A thrown bee must be let go alive")

	var/mob/living/carbon/human/consistent/wizard = allocate(__IMPLIED_TYPE__)
	var/mob/living/basic/mouse/disguise = allocate(__IMPLIED_TYPE__)
	disguise.apply_status_effect(/datum/status_effect/shapechange_mob, wizard)
	disguise.mob_pickup(carrier)
	disguise.remove_status_effect(/datum/status_effect/shapechange_mob)
	TEST_ASSERT(!QDELETED(wizard) && wizard.loc == get_turf(carrier), "A shapeshifter turning back while held must come back where it was held")
