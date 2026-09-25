#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Escape decorators must release a deleted target through the blackboard ownership API. */
/datum/unit_test/runtime_ownership_escape_targets

/** Exercises both target sources without processing an autonomous AI tree. */
/datum/unit_test/runtime_ownership_escape_targets/Run()
	var/mob/living/carbon/human/pawn = allocate(/mob/living/carbon/human/consistent)
	var/datum/ai_controller/controller = allocate(/datum/ai_controller, pawn)
	controller.force_ai_off()
	for(var/decorator_type in list(/datum/bt_node/decorator/pawn_contained_in_obj, /datum/bt_node/decorator/pawn_buckled_to_obj))
		var/obj/structure/chair/target = allocate(/obj/structure/chair)
		var/datum/bt_node/decorator/decorator = allocate(decorator_type)
		if(istype(decorator, /datum/bt_node/decorator/pawn_contained_in_obj))
			pawn.forceMove(target)
		else
			target.buckle_mob(pawn, force = TRUE)
		if(!decorator.check_condition(controller) || controller.blackboard[BB_BASIC_MOB_ESCAPE_TARGET] != target)
			return Fail("Escape decorator [decorator_type] did not select its current target.", __FILE__, __LINE__)
		pawn.buckled?.unbuckle_mob(pawn, force = TRUE)
		pawn.forceMove(run_loc_floor_bottom_left)
		qdel(target)
		var/retained = !isnull(controller.blackboard[BB_BASIC_MOB_ESCAPE_TARGET])
		controller.clear_blackboard_key(BB_BASIC_MOB_ESCAPE_TARGET)
		if(retained)
			Fail("Escape decorator [decorator_type] retained a deleted target.", __FILE__, __LINE__)

/** Hand transfers and deletion must clear every previous holder's slot. */
/datum/unit_test/runtime_ownership_hand_transfer

/** Uses the observed security-baton type and checks each ownership transition directly. */
/datum/unit_test/runtime_ownership_hand_transfer/Run()
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/melee/baton/security/baton = allocate(/obj/item/melee/baton/security)
	if(!first.put_in_hands(baton))
		return Fail("Initial baton pickup failed.", __FILE__, __LINE__)
	if(!second.put_in_hands(baton) || (baton in first.held_items) || !(baton in second.held_items))
		return Fail("Moving a held baton retained the previous owner's slot.", __FILE__, __LINE__)
	if(!second.put_in_hands(baton))
		return Fail("Moving a baton between the same owner's hands failed.", __FILE__, __LINE__)
	qdel(baton)
	if((baton in first.held_items) || (baton in second.held_items))
		return Fail("Deleting the transferred baton retained a hand slot.", __FILE__, __LINE__)

/** A movement callback may transfer an item before the original pickup resumes. */
/datum/unit_test/runtime_ownership_reentrant_pickup
	/// Destination owned by base fixture teardown; only used during the movement signal.
	var/mob/living/carbon/human/receiving_human
	/// The first holder whose pickup is interrupted.
	var/mob/living/carbon/human/original_human
	/// Selects the deletion boundary instead of a transfer during the callback.
	var/delete_in_callback = FALSE

/** Simulates nested pickup with a real movement signal and the observed baton type. */
/datum/unit_test/runtime_ownership_reentrant_pickup/Run()
	original_human = allocate(/mob/living/carbon/human/consistent)
	receiving_human = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/melee/baton/security/baton = allocate(/obj/item/melee/baton/security)
	RegisterSignal(baton, COMSIG_MOVABLE_MOVED, PROC_REF(transfer_during_move))
	var/picked_up = original_human.put_in_active_hand(baton)
	UnregisterSignal(baton, COMSIG_MOVABLE_MOVED)
	var/stale_slot = (baton in original_human.held_items)
	var/transferred = delete_in_callback ? QDELETED(baton) : (baton.loc == receiving_human && (baton in receiving_human.held_items))
	// Release any broken slot before the fixture leaves; the assertion still reports it.
	if(stale_slot)
		original_human.temporarilyRemoveItemFromInventory(baton, force = TRUE)
	if(picked_up || stale_slot || !transferred)
		return Fail("Reentrant pickup lost ownership: reported pickup=[picked_up], stale slot=[stale_slot], transfer preserved=[transferred].", __FILE__, __LINE__)

/** Moves the item exactly once while the original forceMove call is dispatching signals. */
/datum/unit_test/runtime_ownership_reentrant_pickup/proc/transfer_during_move(obj/item/source)
	SIGNAL_HANDLER
	if(source.loc != original_human)
		return
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)
	if(delete_in_callback)
		qdel(source)
	else
		receiving_human.put_in_active_hand(source)

/** Deletion during movement must also abort pickup before a hand slot is written. */
/datum/unit_test/runtime_ownership_reentrant_pickup/deleted
	delete_in_callback = TRUE

#endif
