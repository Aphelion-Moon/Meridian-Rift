/// Protect route generation, server-side input validation, and recovery/trace boundaries.
/datum/unit_test/personal_cache_puzzle

/datum/unit_test/personal_cache_puzzle/Run()
	for(var/board in 1 to 24)
		var/datum/cache_lock_puzzle/puzzle = allocate(/datum/cache_lock_puzzle)
		var/list/first = puzzle.targets[1]
		var/list/second = puzzle.targets[2]
		var/list/sequence = first + second.Copy(3)
		var/list/route = find_route(puzzle, sequence, list())
		TEST_ASSERT_EQUAL(length(route), 6, "Generated board [board] has no legal route for both signatures")
		TEST_ASSERT(!puzzle.select_cell(0), "Zero index accepted")
		TEST_ASSERT(!puzzle.select_cell(1.5), "Fractional index accepted")
		TEST_ASSERT(!puzzle.select_cell("1"), "Text index accepted")
		TEST_ASSERT(!puzzle.select_cell(37), "Out-of-range index accepted")
		TEST_ASSERT(!puzzle.select_cell(7), "First pulse accepted outside top row")
		TEST_ASSERT(!puzzle.stabilize(), "Recovery allowed before the trace")
		TEST_ASSERT_EQUAL(puzzle.deadline, 0, "Invalid input started the timer")
		for(var/step in 1 to length(route))
			TEST_ASSERT(puzzle.select_cell(route[step]), "Solution step [step] rejected on board [board]")
			TEST_ASSERT(!puzzle.select_cell(route[step]), "Consumed cell accepted twice")
			if(step == 4)
				var/deadline = puzzle.deadline
				TEST_ASSERT(puzzle.stabilize(), "Recovery rejected during a viable route")
				TEST_ASSERT(!puzzle.stabilize(), "Recovery allowed twice")
				TEST_ASSERT_EQUAL(puzzle.deadline, deadline + puzzle.recovery_time, "Recovery did not extend trace")
				TEST_ASSERT_EQUAL(puzzle.buffer_limit, 7, "Recovery did not consume capacity")
		TEST_ASSERT(puzzle.solved && !puzzle.failed, "Both signatures did not solve board [board]: buffer=[json_encode(puzzle.buffer)], targets=[json_encode(puzzle.targets)], completed=[json_encode(puzzle.completed)], solved=[puzzle.solved], failed=[puzzle.failed]")
		TEST_ASSERT(!puzzle.select_cell(2), "Solved board accepted another pulse")

	var/datum/cache_lock_puzzle/expired = allocate(/datum/cache_lock_puzzle)
	expired.deadline = world.time - 1
	TEST_ASSERT(!expired.select_cell(1), "Expired trace accepted a pulse")
	TEST_ASSERT(!expired.stabilize(), "Expired trace accepted recovery")

	var/datum/cache_lock_puzzle/exhausted = allocate(/datum/cache_lock_puzzle)
	exhausted.targets = list(list("unreachable"), list("unreachable"))
	var/list/eight_steps = list(1, 7, 8, 14, 15, 21, 22, 28)
	for(var/index in eight_steps)
		TEST_ASSERT(exhausted.select_cell(index), "Legal pulse rejected before the buffer filled")
	TEST_ASSERT(exhausted.failed && !exhausted.solved, "Buffer exhaustion did not end the attempt")

	var/datum/cache_lock_puzzle/final_slot = allocate(/datum/cache_lock_puzzle)
	final_slot.cells = exhausted.cells.Copy()
	var/list/first_target = list()
	var/list/second_target = list()
	for(var/step in 1 to length(eight_steps))
		// Unique values prevent an accidental earlier completion.
		final_slot.cells[eight_steps[step]] = "[step]"
		if(step >= 3 && step <= 6)
			first_target += "[step]"
		if(step >= 5)
			second_target += "[step]"
	final_slot.targets = list(first_target, second_target)
	for(var/index in eight_steps)
		final_slot.select_cell(index)
	TEST_ASSERT(final_slot.solved && !final_slot.failed, "Last-slot success lost to buffer exhaustion")

/// Solve from public board data without consulting the production move validator.
/datum/unit_test/personal_cache_puzzle/proc/find_route(datum/cache_lock_puzzle/puzzle, list/sequence, list/route)
	var/step = length(route) + 1
	if(step > length(sequence))
		return route
	var/previous = length(route) ? route[length(route)] : 0
	for(var/index in 1 to length(puzzle.cells))
		if((index in route) || puzzle.cells[index] != sequence[step])
			continue
		if(!previous && index > puzzle.grid_size)
			continue
		if(previous && step % 2 == 0 && (index - 1) % puzzle.grid_size != (previous - 1) % puzzle.grid_size)
			continue
		if(previous && step % 2 == 1 && round((index - 1) / puzzle.grid_size) != round((previous - 1) / puzzle.grid_size))
			continue
		var/list/solution = find_route(puzzle, sequence, route + index)
		if(solution)
			return solution
	return null

/// Identity restrictions and nested movement must hold through the normal storage APIs.
/datum/unit_test/personal_cache_storage

/datum/unit_test/personal_cache_storage/Run()
	var/obj/item/storage/box/personal_cache/cache = allocate(/obj/item/storage/box/personal_cache)
	var/obj/item/storage/box/cache_pouch/loadout/own_matrix = allocate(/obj/item/storage/box/cache_pouch/loadout, cache)
	var/obj/item/storage/box/cache_pouch/loadout/other_matrix = allocate(/obj/item/storage/box/cache_pouch/loadout)
	var/obj/item/multitool/own_item = allocate(/obj/item/multitool)
	var/obj/item/multitool/foreign_item = allocate(/obj/item/multitool)
	own_item.AddElement(/datum/element/loadout_pouch_item, REF(own_matrix))
	foreign_item.AddElement(/datum/element/loadout_pouch_item, REF(other_matrix))
	TEST_ASSERT(own_matrix.atom_storage.can_insert(own_item, messages = FALSE), "Matrix rejected its own item")
	TEST_ASSERT(!own_matrix.atom_storage.can_insert(foreign_item, messages = FALSE), "Matrix accepted a foreign signature")
	TEST_ASSERT(cache.atom_storage.attempt_insert(own_item, messages = FALSE), "Cache rejected its own tagged item")
	TEST_ASSERT_EQUAL(own_item.loc, own_matrix, "Catch-all stole a loadout item")
	TEST_ASSERT(!cache.atom_storage.attempt_remove(own_matrix, run_loc_floor_bottom_left), "Fused matrix could be removed")

	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack)
	cache.forceMove(bag)
	cache.owner_ckey = "cache-test-owner"
	cache.owner_name = "Cache test owner"
	cache.update_gps_state()
	TEST_ASSERT(cache.gps_active, "Unheld attuned cache did not transmit")
	cache.remove_gps_signal()
	bag.forceMove(run_loc_floor_top_right)
	TEST_ASSERT(cache.gps_active, "Moving a containing bag did not refresh GPS")
	cache.clear_owner()
	TEST_ASSERT(!cache.gps_active, "Clearing attunement retained GPS")

	var/obj/item/storage/box/survival/ordinary_box = allocate(/obj/item/storage/box/survival)
	ordinary_box.cache_locked = TRUE
	var/datum/loadout_item/cache/tank/emergency/tank_pick = GLOB.all_loadout_datums[/obj/item/tank/internals/emergency_oxygen]
	var/obj/item/tank/internals/emergency_oxygen/tank = allocate(/obj/item/tank/internals/emergency_oxygen)
	TEST_ASSERT(!tank_pick.place_in_cache(ordinary_box, tank), "Locked survival air was replaced")
	TEST_ASSERT(QDELETED(tank), "Rejected cache pick was orphaned")
	var/datum/loadout_item/cache/general/tool/multitool/tool_pick = GLOB.all_loadout_datums[/obj/item/multitool]
	TEST_ASSERT(tool_pick.place_in_cache(ordinary_box, foreign_item), "Locked air box rejected an unrelated general pick")
	TEST_ASSERT_EQUAL(foreign_item.loc, ordinary_box, "General pick missed ordinary survival box")

/// Session cleanup releases exclusivity and applies penalties only to started real attempts.
/datum/unit_test/personal_cache_session

/datum/unit_test/personal_cache_session/Run()
	var/obj/item/storage/box/personal_cache/cache = allocate(/obj/item/storage/box/personal_cache)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/other_user = allocate(/mob/living/carbon/human/consistent)
	cache.owner_ckey = "cache-test-owner"
	var/datum/cache_lock_session/session = new(cache, user, FALSE)
	cache.active_hack = session
	TEST_ASSERT_EQUAL(session.ui_status(other_user, GLOB.hands_state), UI_CLOSE, "Another mob could use the session")
	qdel(session)
	TEST_ASSERT_NULL(cache.active_hack, "Closing planning did not release cache")
	TEST_ASSERT_EQUAL(cache.hack_cooldown_until, 0, "Planning cancellation applied a lockout")

	session = new(cache, user, FALSE)
	cache.active_hack = session
	session.puzzle.select_cell(1)
	qdel(session)
	TEST_ASSERT(cache.hack_cooldown_until > world.time, "Started real attempt escaped lockout")
	cache.hack_cooldown_until = 0
	session = new(cache, user, TRUE)
	cache.active_hack = session
	session.puzzle.select_cell(1)
	qdel(session)
	TEST_ASSERT_EQUAL(cache.hack_cooldown_until, 0, "Practice applied a lockout")
	TEST_ASSERT_EQUAL(cache.owner_ckey, "cache-test-owner", "Practice changed ownership")

	session = new(cache, user, FALSE)
	cache.active_hack = session
	session.succeeded = TRUE
	cache.on_lock_cracked(user, FALSE)
	TEST_ASSERT_NULL(cache.owner_ckey, "Successful hack did not clear ownership")
	TEST_ASSERT_NULL(cache.active_hack, "Ownership change retained stale session")
	TEST_ASSERT(QDELETED(session), "Ownership change leaked the session")

/// Exercise the real loadout helper in each delivery mode, including ordinary survival kits.
/datum/unit_test/personal_cache_loadout

/datum/unit_test/personal_cache_loadout/Run()
	for(var/box_type in list(/obj/item/storage/box/personal_cache, /obj/item/storage/box/survival))
		for(var/delivery in list(LOADOUT_OVERRIDE_BACKPACK, LOADOUT_OVERRIDE_CASE, LOADOUT_OVERRIDE_CACHE_POUCH))
			var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
			var/datum/client_interface/client = allocate(/datum/client_interface)
			client.prefs = new(client)
			user.mock_client = client
			client.prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/loadout_override_preference], delivery)
			client.prefs.write_preference(GLOB.preference_entries[/datum/preference/loadout], list("Default" = list(
				/obj/item/tank/internals/emergency_oxygen = list(),
				/obj/item/multitool = list(),
			)))
			client.prefs.write_preference(GLOB.preference_entries[/datum/preference/loadout_index], "Default")
			var/datum/outfit/job/outfit = allocate(/datum/outfit/job)
			outfit.back = /obj/item/storage/backpack
			outfit.box = box_type
			user.equip_outfit_and_loadout(outfit, client.prefs)
			var/obj/item/storage/box/survival/cache = locate(box_type) in user.get_all_gear()
			TEST_ASSERT_NOTNULL(cache, "[delivery] did not equip [box_type]")
			var/list/cache_contents = cache.get_all_contents()
			var/obj/item/multitool/tool = locate() in cache_contents
			TEST_ASSERT_NOTNULL(tool, "[delivery] failed to deliver tool into [box_type]")
			var/tanks = 0
			for(var/obj/item/tank/internals/tank in cache_contents)
				tanks++
			TEST_ASSERT_EQUAL(tanks, 1, "[delivery] duplicated or lost the survival tank in [box_type]")
			if(box_type == /obj/item/storage/box/survival)
				TEST_ASSERT_NULL(locate(/obj/item/storage/box/cache_pouch/loadout) in cache_contents, "Normal box trapped the loadout matrix")
