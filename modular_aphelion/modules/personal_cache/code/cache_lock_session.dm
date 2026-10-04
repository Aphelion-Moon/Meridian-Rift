/// One user's in-hand attempt; owns the UI, puzzle, and trace timer.
/datum/cache_lock_session
	/// Cache whose attunement is being challenged.
	var/obj/item/storage/box/personal_cache/cache
	/// Only this mob may operate the session.
	var/mob/living/hacker
	/// Prevent a changed login from inheriting an open session.
	var/hacker_ckey
	/// Owner at the start of the attempt.
	var/owner_ckey
	/// Practice never changes ownership or applies a lockout.
	var/self_test = FALSE
	/// Server-authoritative puzzle state.
	var/datum/cache_lock_puzzle/puzzle
	/// Stoppable timer for the trace, replaced when recovery extends it.
	var/trace_timer
	/// Success must not be treated as an aborted attempt during cleanup.
	var/succeeded = FALSE

/datum/cache_lock_session/New(obj/item/storage/box/personal_cache/cache, mob/living/hacker, self_test)
	. = ..()
	src.cache = cache
	src.hacker = hacker
	src.self_test = self_test
	hacker_ckey = hacker.ckey
	owner_ckey = cache.owner_ckey
	puzzle = new

/datum/cache_lock_session/Destroy()
	if(trace_timer)
		deltimer(trace_timer)
	if(!QDELETED(cache) && cache.active_hack == src)
		cache.active_hack = null
		if(!succeeded && !self_test && puzzle?.deadline)
			cache.hack_cooldown_until = world.time + 30 SECONDS
	SStgui.close_uis(src)
	QDEL_NULL(puzzle)
	cache = null
	hacker = null
	return ..()

/datum/cache_lock_session/ui_host(mob/user)
	return cache

/datum/cache_lock_session/ui_state(mob/user)
	return GLOB.hands_state

/// Recheck identity, ownership and physical possession on every action/update.
/datum/cache_lock_session/ui_status(mob/user, datum/ui_state/state)
	if(QDELETED(cache) || QDELETED(hacker) || cache.active_hack != src || user != hacker)
		return UI_CLOSE
	if(hacker.ckey != hacker_ckey || cache.owner_ckey != owner_ckey || !hacker.is_holding(cache) || hacker.incapacitated)
		return UI_CLOSE
	return ..()

/datum/cache_lock_session/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PersonalCacheLock", cache.name)
		ui.open()

/datum/cache_lock_session/ui_close(mob/user)
	if(!QDELETED(src))
		qdel(src)

/datum/cache_lock_session/ui_data(mob/user)
	var/list/grid = list()
	for(var/index in 1 to length(puzzle.cells))
		grid += list(list(
			"index" = index,
			"symbol" = puzzle.cells[index],
			"available" = puzzle.can_select(index),
			"used" = (index in puzzle.used_cells),
		))
	return list(
		"grid" = grid,
		"grid_size" = puzzle.grid_size,
		"targets" = puzzle.targets,
		"completed" = puzzle.completed,
		"buffer" = puzzle.buffer,
		"buffer_limit" = puzzle.buffer_limit,
		"select_row" = length(puzzle.used_cells) % 2 == 0,
		"started" = !!puzzle.deadline,
		"seconds_left" = puzzle.deadline ? max(0, CEILING((puzzle.deadline - world.time) / (1 SECONDS), 1)) : puzzle.time_limit / (1 SECONDS),
		"can_stabilize" = puzzle.can_stabilize(),
		"recovery_seconds" = puzzle.recovery_time / (1 SECONDS),
		"self_test" = self_test,
		"revision" = puzzle.revision,
	)

/datum/cache_lock_session/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(ui_status(usr, state) != UI_INTERACTIVE)
		return FALSE
	if(puzzle.deadline && world.time >= puzzle.deadline)
		trace_expired()
		return TRUE
	if(params["revision"] != puzzle.revision)
		return FALSE
	var/previous_deadline = puzzle.deadline
	var/accepted = FALSE
	switch(action)
		if("pulse")
			accepted = puzzle.select_cell(params["cell"])
		if("stabilize")
			accepted = puzzle.stabilize()
		if("abort")
			qdel(src)
			return TRUE
	if(!accepted)
		return FALSE
	if(puzzle.solved)
		succeeded = TRUE
		cache.on_lock_cracked(hacker, self_test)
		qdel(src)
		return TRUE
	if(puzzle.failed)
		to_chat(hacker, span_warning("The routing buffer cannot complete the remaining signatures. The attempt has ended."))
		qdel(src)
		return TRUE
	if(puzzle.deadline != previous_deadline)
		if(trace_timer)
			deltimer(trace_timer)
		trace_timer = addtimer(CALLBACK(src, PROC_REF(trace_expired)), puzzle.deadline - world.time, TIMER_STOPPABLE)
	return TRUE

/// The deadline is enforced even when the player stops sending UI actions.
/datum/cache_lock_session/proc/trace_expired()
	to_chat(hacker, span_warning("The trace has reached your connection. The attempt has ended."))
	qdel(src)
