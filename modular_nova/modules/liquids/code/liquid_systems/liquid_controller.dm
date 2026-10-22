SUBSYSTEM_DEF(liquids)
	name = "Liquid Turfs"
	wait = 1 SECONDS
	ss_flags = SS_KEEP_TIMING | SS_NO_INIT
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	var/list/active_turfs = list()
	var/list/currentrun_active_turfs = list()

	var/list/active_groups = list()

	var/list/active_immutables = list()

	var/list/evaporation_queue = list()
	var/evaporation_counter = 0 //Only process evaporation on intervals

	var/list/processing_fire = list()
	var/fire_counter = 0 //Only process fires on intervals

	// format: list[path, list[str, instance]]
	var/list/singleton_immutables = list()

	var/run_type = SSLIQUIDS_RUN_TYPE_TURFS

	/// Alpha of a clear liquid pool at each liquid state, puddle to full tile.
	var/list/clear_alpha_by_state = list(70, 100, 125, 145, 160)

/**
 * Returns the alpha for a liquid pool.
 *
 * A clear pool takes its depth's entry in clear_alpha_by_state, so deeper liquid reads stronger.
 * Opacity blends that toward 255, so a fully opaque mix hides the floor at any depth.
 *
 * Arguments:
 * - liquid_state: The pool's LIQUID_STATE_* depth. Null counts as a puddle.
 * - opacity: Volume-weighted liquid_opacity of the pool's reagents, 0 to 1.
 */
/datum/controller/subsystem/liquids/proc/get_pool_alpha(liquid_state, opacity)
	var/clear_alpha = clear_alpha_by_state[liquid_state || LIQUID_STATE_PUDDLE]
	return round(clear_alpha + (255 - clear_alpha) * opacity, 1)

/datum/controller/subsystem/liquids/proc/get_immutable(type, turf/reference_turf)
	if(isnull(singleton_immutables[type]))
		singleton_immutables[type] = list()

	var/offset = GET_TURF_PLANE_OFFSET(reference_turf)

	if(!("[offset]" in singleton_immutables[type]))
		var/obj/effect/abstract/liquid_turf/immutable/new_one = new type(null, offset)
		singleton_immutables[type]["[offset]"] = new_one

	return singleton_immutables[type]["[offset]"]


/datum/controller/subsystem/liquids/stat_entry(msg)
	msg += "AT:[active_turfs.len]|AG:[active_groups.len]|AIM:[active_immutables.len]|EQ:[evaporation_queue.len]|PF:[processing_fire.len]"
	return ..()


/datum/controller/subsystem/liquids/fire(resumed = FALSE)
	if(run_type == SSLIQUIDS_RUN_TYPE_TURFS)
		if(!resumed)
			src.currentrun_active_turfs = active_turfs.Copy()
		// cache for speed
		var/list/currentrun_active_turfs = src.currentrun_active_turfs
		while(currentrun_active_turfs.len)
			var/turf/turf = currentrun_active_turfs[currentrun_active_turfs.len]
			turf.process_liquid_cell()
			currentrun_active_turfs.Remove(turf)
			if(MC_TICK_CHECK)
				break
		resumed = FALSE
		if(!currentrun_active_turfs.len)
			run_type = SSLIQUIDS_RUN_TYPE_GROUPS
	if (run_type == SSLIQUIDS_RUN_TYPE_GROUPS)
		for(var/g in active_groups)
			var/datum/liquid_group/LG = g
			if(LG.dirty)
				LG.share()
				LG.dirty = FALSE
			else if(!LG.amount_of_active_turfs)
				LG.decay_counter++
				if(LG.decay_counter >= LIQUID_GROUP_DECAY_TIME)
					//Perhaps check if any turfs in here can spread before removing it? It's not unlikely they would
					LG.break_group()
			if(MC_TICK_CHECK)
				run_type = SSLIQUIDS_RUN_TYPE_IMMUTABLES //No currentrun here for now
				break
		resumed = FALSE
		run_type = SSLIQUIDS_RUN_TYPE_IMMUTABLES
	if(run_type == SSLIQUIDS_RUN_TYPE_IMMUTABLES)
		for(var/t in active_immutables)
			var/turf/T = t
			T.process_immutable_liquid()
			/*
			if(MC_TICK_CHECK)
				break
			*/
		resumed = FALSE
		run_type = SSLIQUIDS_RUN_TYPE_EVAPORATION

	if(run_type == SSLIQUIDS_RUN_TYPE_EVAPORATION)
		evaporation_counter++
		if(evaporation_counter >= REQUIRED_EVAPORATION_PROCESSES)
			for(var/t in evaporation_queue)
				var/turf/T = t
				if(prob(EVAPORATION_CHANCE))
					T.liquids.process_evaporation()
				if(MC_TICK_CHECK)
					break
			resumed = FALSE
			evaporation_counter = 0
		run_type = SSLIQUIDS_RUN_TYPE_FIRE

	if(run_type == SSLIQUIDS_RUN_TYPE_FIRE)
		fire_counter++
		if(fire_counter >= REQUIRED_FIRE_PROCESSES)
			for(var/t in processing_fire)
				var/turf/T = t
				T.liquids.process_fire()
			if(MC_TICK_CHECK)
				return
			resumed = FALSE
			fire_counter = 0
		run_type = SSLIQUIDS_RUN_TYPE_TURFS

/datum/controller/subsystem/liquids/proc/add_active_turf(turf/T)
	if(can_fire && !active_turfs[T])
		active_turfs[T] = TRUE
		if(T.lgroup)
			T.lgroup.amount_of_active_turfs++

/datum/controller/subsystem/liquids/proc/remove_active_turf(turf/T)
	if(active_turfs[T])
		active_turfs -= T
		if(T.lgroup)
			T.lgroup.amount_of_active_turfs--

ADMIN_VERB(toggle_liquid_debug, R_DEBUG, "Liquid Groups Color Debug", "Liquid Groups Color Debug.", ADMIN_CATEGORY_DEBUG)
	GLOB.liquid_debug_colors = !GLOB.liquid_debug_colors
