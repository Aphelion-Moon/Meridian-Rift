/datum/unit_test/movement_order_sanity/Run()
	var/obj/movement_tester/test_obj = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/list/movement_cache = test_obj.movement_order

	var/obj/movement_interceptor/interceptor = allocate(__IMPLIED_TYPE__)
	interceptor.forceMove(locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))

	var/did_move = step(test_obj, EAST)

	TEST_ASSERT(did_move, "Object did not move at all.")
	TEST_ASSERT(QDELETED(test_obj), "Object was not qdeleted.")
	TEST_ASSERT(length(movement_cache) == 4, "Movement order length was not the expected value of 4, got: [length(movement_cache)].\nMovement Log\n[jointext(movement_cache, "\n")]")

	// Due to when the logging takes place, it will always be Move Move > Moved Moved instead of the reality of
	// Move > Moved > Move > Moved
	TEST_ASSERT(findtext(movement_cache[1], "Moving from"),"Movement step 1 was not a Move attempt.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[2], "Moving from"),"Movement step 2 was not a Move attempt.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[3], "Moved from"),"Movement step 3 was not a Moved() call.\nMovement Log\n[jointext(movement_cache, "\n")]")
	TEST_ASSERT(findtext(movement_cache[4], "Moved from"),"Movement step 4 was not a Moved() call.\nMovement Log\n[jointext(movement_cache, "\n")]")

/obj/movement_tester
	name = "movement debugger"
	var/list/movement_order = list()

/obj/movement_tester/Move(atom/newloc, direct, glide_size_override, z_movement_flags)
	movement_order += "Moving from ([loc.x], [loc.y]) to [newloc ? "([newloc.x], [newloc.y])" : "NULL"]"
	return ..()

/obj/movement_tester/doMove(atom/destination)
	movement_order += "Abstractly Moving from ([loc.x], [loc.y]) to [destination ? "([destination.x], [destination.y])" : "NULL"]"
	return ..()

/obj/movement_tester/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	movement_order += "Moved from ([old_loc.x], [old_loc.y]) to [loc ? "([loc.x], [loc.y])" : "NULL"]"
	return ..()

/obj/movement_interceptor
	name = "movement interceptor"

/obj/movement_interceptor/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/connect_loc, list(COMSIG_ATOM_ENTERED = PROC_REF(on_crossed)))

/obj/movement_interceptor/proc/on_crossed(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(src == arrived)
		return

	qdel(arrived)

/** Movement can delete the mover and its loop before Move() returns. */
/datum/unit_test/jps_loop_deleted_during_move/Run()
	var/turf/destination = get_step(run_loc_floor_bottom_left, EAST)
	var/obj/movement_tester/mover = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.jps_move(mover, destination,
		delay = 1 HOURS, timeout = 1 HOURS, repath_delay = 0, max_path_length = 30,
		minimum_distance = 0, access = list(), simulated_only = TRUE, skip_first = TRUE,
		subsystem = SSmovement, diagonal_handling = DIAGONAL_REMOVE_CLUNKY, initial_path = list(destination))
	TEST_ASSERT(istype(loop), "Could not create the normal JPS movement control.")
	TEST_ASSERT_EQUAL(loop.move(), MOVELOOP_SUCCESS, "The normal JPS control did not move.")
	TEST_ASSERT_EQUAL(get_turf(mover), destination, "The normal JPS control did not reach its destination.")
	TEST_ASSERT_EQUAL(length(loop.movement_path), 0, "The normal JPS control did not consume its path step.")
	qdel(loop)

	mover.forceMove(run_loc_floor_bottom_left)
	allocate(/obj/movement_interceptor, destination)
	loop = GLOB.move_manager.jps_move(mover, destination,
		delay = 1 HOURS, timeout = 1 HOURS, repath_delay = 0, max_path_length = 30,
		minimum_distance = 0, access = list(), simulated_only = TRUE, skip_first = TRUE,
		subsystem = SSmovement, diagonal_handling = DIAGONAL_REMOVE_CLUNKY, initial_path = list(destination))
	TEST_ASSERT(istype(loop), "Could not create the JPS deletion regression loop.")
	var/paths_before = length(SSpathfinder.active_pathing)
	var/result = loop.move()
	TEST_ASSERT(QDELETED(mover), "The interception fixture did not delete the mover during Move().")
	TEST_ASSERT(QDELETED(loop), "Deleting the mover did not delete its owned loop.")
	TEST_ASSERT_EQUAL(result, MOVELOOP_FAILURE, "A deleted JPS loop reported a successful move.")
	// An already dispatched callback must also be harmless after loop destruction.
	loop.repath_cooldown = 0
	loop.recalculate_path()
	TEST_ASSERT_EQUAL(loop.repath_cooldown, 0, "A deleted loop started a new repath cooldown.")
	TEST_ASSERT_EQUAL(length(SSpathfinder.active_pathing), paths_before, "A deleted loop queued another pathfinding request.")
