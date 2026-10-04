#ifdef MEMORY_PROFILER_WORKLOAD
/** Disposable, zero-client gameplay exercise. Excluded from ordinary builds. */
SUBSYSTEM_DEF(memory_workload)
	name = "Memory workload"
	ss_flags = SS_BACKGROUND
	wait = 10
	/// Actual spawned actors, kept separate from real clients in provenance.
	var/list/mob/living/carbon/human/actors = list()
	/// Phase index in the documented scenario.
	var/phase = 0
	/// Activity steps within the current phase.
	var/activity = 0
	/// Requested capture, whose cleanup must finish before the next phase.
	var/datum/memory_capture/pending
	/// Earliest next phase, allowing ordinary subsystem processing.
	var/next_phase = 0

/datum/controller/subsystem/memory_workload/Initialize()
	// Match the repository's unattended-test lifecycle without enabling unit-test
	// reference tracking or disabling loop checks in the measured game.
	Master.sleep_offline_after_initializations = FALSE
	SSticker.start_immediately = TRUE
	SSticker.roundend_check_paused = TRUE
	GLOB.debugging_enabled = TRUE
	rand_seed(12345)
	return SS_INIT_SUCCESS

/datum/controller/subsystem/memory_workload/fire(resumed)
	if(length(GLOB.clients))
		world.log << "MEMORY_WORKLOAD_ABORT: client connected; no artificial activity allowed"
		can_fire = FALSE
		return
	if(SSticker.current_state != GAME_STATE_PLAYING || world.time < next_phase)
		return
	if(pending)
		if(pending.state != "done")
			return
		world.log << "MEMORY_CAPTURE_DONE phase=[phase] status=[pending.result] worst_step_ms=[pending.worst_atomic_ms] worst_tick_ms=[pending.worst_tick_ms] total_ms=[pending.total_ms] retained=[length(pending.entries)]"
		pending = null
		phase++
		next_phase = world.time + 5 SECONDS
		return
	switch(phase)
		if(0)
			CONFIG_SET(flag/memory_profiler_enabled, TRUE)
			capture_phase("loaded-map")
		if(1)
			var/turf/location
			// Test-only discovery outside the collector: runtime maps do not retain
			// job start landmarks after round setup.
			for(var/turf/open/floor/ground in world)
				if(is_station_level(ground.z) && !ground.is_blocked_turf())
					location = ground
					break
				CHECK_TICK
			if(!location)
				world.log << "MEMORY_WORKLOAD_ABORT: no start landmark"
				can_fire = FALSE
				return
			for(var/index in 1 to 4)
				var/mob/living/carbon/human/actor = new(location)
				actor.equipOutfit(/datum/outfit/job/assistant)
				actors += actor
			capture_phase("warm-equipped")
		if(2, 3)
			for(var/mob/living/carbon/human/actor as anything in actors)
				if(QDELETED(actor))
					continue
				step(actor, activity % 2 ? NORTH : SOUTH)
				actor.update_body()
				var/obj/item/reagent_containers/cup/beaker/beaker = new(get_turf(actor))
				beaker.reagents.add_reagent(/datum/reagent/water, 5)
				actor.put_in_hands(beaker)
				actor.dropItemToGround(beaker)
				if(phase == 3)
					actor.apply_damage(1, BRUTE)
				qdel(beaker)
			activity++
			if(activity >= 15)
				activity = 0
				capture_phase(phase == 2 ? "sustained-activity" : "churn-event")
		if(4)
			if(length(actors))
				for(var/mob/living/carbon/human/actor as anything in actors)
					qdel(actor)
				actors.Cut()
				next_phase = world.time + 30 SECONDS
				return
			capture_phase("ordinary-cleanup")
		else
			world.log << "MEMORY_WORKLOAD_DONE"
			shutdown()

/** Label each real engine capture with the exact simulated activity phase. */
/datum/controller/subsystem/memory_workload/proc/capture_phase(label)
	text2file(label, "memory-[label].marker")
	if(world.params["memory-profile-off"])
		// Paired control uses the measured on-run capture interval supplied by the
		// runner, so background subsystems receive the same observation window.
		var/delay_ds = max(1, text2num(world.params["memory-delay-[phase]"]))
		phase++
		next_phase = world.time + delay_ds + 5 SECONDS
		return
	if(!SSmemory_profiler.start_capture())
		world.log << "MEMORY_WORKLOAD_ABORT: capture refused"
		can_fire = FALSE
		return
	pending = SSmemory_profiler.job
	pending.output_path = "[GLOB.log_directory]/memory-[label].ndjson"
	pending.provenance["capture_id"] = label
	pending.provenance["evidence_class"] = "running_test_round_simulated_actors"
	pending.provenance["simulated_actors"] = length(actors)
	pending.provenance["workload"] = "four-actors-equipment-movement-inventory-water-appearance-damage-v1"
	pending.provenance["phase"] = label
	pending.provenance["seed"] = 12345
#endif
