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
	if(!second.put_in_hands(baton) || first.is_holding(baton) || !second.is_holding(baton))
		return Fail("Moving a held baton retained the previous owner's slot.", __FILE__, __LINE__)
	if(!second.put_in_hands(baton))
		return Fail("Moving a baton between the same owner's hands failed.", __FILE__, __LINE__)
	qdel(baton)
	if(first.is_holding(baton) || second.is_holding(baton))
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
	var/stale_slot = original_human.is_holding(baton)
	var/transferred = delete_in_callback ? QDELETED(baton) : (baton.loc == receiving_human && receiving_human.is_holding(baton))
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

/** Already queued owner-deletion callbacks must tolerate another listener destroying their bar first. */
/datum/unit_test/runtime_ownership_progressbar_delete

/** Uses the wall healer's real callback ordering and an ordinary bar sharing the same owner. */
/datum/unit_test/runtime_ownership_progressbar_delete/Run()
	var/mob/living/carbon/human/first_user = allocate(/mob/living/carbon/human/consistent)
	var/obj/machinery/wall_healer/free/healer = allocate(/obj/machinery/wall_healer/free, run_loc_floor_bottom_left)
	healer.set_using_mob(first_user)
	var/list/healer_bars = first_user.progressbars[healer]
	if(length(healer_bars) != 1)
		return Fail("The wall healer did not create one progress bar for its user.", __FILE__, __LINE__)
	var/datum/progressbar/wall_healer/healer_bar = healer_bars[1]
	var/datum/progressbar/ordinary_bar = allocate(/datum/progressbar, first_user, 1, run_loc_floor_bottom_left)
	qdel(first_user)
	if(!QDELETED(healer_bar) || healer_bar.user || healer_bar.bar_loc || healer_bar.user_client)
		return Fail("Wall-healer cleanup retained its deleted user's progress bar ownership.", __FILE__, __LINE__)
	if(!QDELETED(ordinary_bar) || ordinary_bar.user || ordinary_bar.bar_loc)
		return Fail("An ordinary progress bar missed user-deletion cleanup after another bar was already destroyed.", __FILE__, __LINE__)

	var/mob/living/carbon/human/second_user = allocate(/mob/living/carbon/human/consistent)
	healer.set_using_mob(second_user)
	var/list/replacement_bars = second_user.progressbars[healer]
	if(length(replacement_bars) != 1)
		return Fail("The wall healer could not create a fresh bar after its previous user was deleted.", __FILE__, __LINE__)
	var/datum/progressbar/wall_healer/replacement_bar = replacement_bars[1]
	if(replacement_bar.user != second_user)
		return Fail("The replacement progress bar retained the wrong user.", __FILE__, __LINE__)
	healer.clear_using_mob()
	if(!QDELETED(replacement_bar) || replacement_bar.user || length(second_user.progressbars))
		return Fail("Ending the replacement user's interaction retained a progress bar.", __FILE__, __LINE__)

#endif
