#ifdef MEMORY_PROFILER_RANDOM_WORKLOAD
/** Seeded, clientless large-station exercise, compiled only into disposable test builds. */
SUBSYSTEM_DEF(memory_random_workload)
	name = "Memory random workload"
	ss_flags = SS_BACKGROUND
	wait = 1
	/// Test-owned actors; actual clients never participate.
	var/list/mob/living/carbon/human/actors = list()
	/// Spawn candidates near station machinery, collected once outside the collector.
	var/list/turf/spawns = list()
	/// Original light state per controlled area, shared by all its switches.
	var/list/original_lights = list()
	/// One surviving switch per area provides the ordinary restoration path.
	var/list/light_representatives = list()
	/// Reaction vessels mapped to their observation deadline.
	var/list/reaction_vessels = list()
	/// Current phase and its fixed label.
	var/phase = 0
	var/list/phase_names = list("loaded-map", "warm-population", "sustained-random", "population-churn", "ordinary-cleanup")
	/// Whether phase-local timing/profiling has started.
	var/phase_started = FALSE
	/// Pending capture and a separate flag for the profiler-off control.
	var/datum/memory_capture/pending
	var/capture_requested = FALSE
	var/control_until = 0
	/// Number of attempted random actions in this phase.
	var/actions = 0
	var/action_target = 2400
	/// Initial population; churn doubles it up to the test-only maximum.
	var/population = 24
	/// Scenario PRNG is independent of random draws in background subsystems.
	var/seed = 12345
	var/random_state = 12345
	/// Phase action attempts/outcomes, never player content.
	var/list/counts = list()
	/// Earliest next phase and the ordinary cleanup deadline.
	var/next_phase = 0
	var/cleanup_until = 0
	/// Bounded tick-latency histogram, sampled by a monotonic rust-g timer.
	var/list/tick_bins = list(0, 0, 0, 0, 0, 0)
	var/tick_samples = 0
	var/tick_total_ms = 0
	var/tick_max_ms = 0
	/// Per-phase action-call timing; includes actual gameplay methods.
	var/action_ms = 0
	var/action_max_ms = 0
	/// Sampling loop lifetime; unrelated daemons are never touched.
	var/sampling = FALSE
	/// Exact phase interval in the scenario's monotonic clock.
	var/phase_start_ms = 0
	var/phase_start_random = 0

/datum/controller/subsystem/memory_random_workload/Initialize()
	Master.sleep_offline_after_initializations = FALSE
	SSticker.start_immediately = TRUE
	SSticker.roundend_check_paused = TRUE
	GLOB.debugging_enabled = TRUE
	if(world.params["memory-seed"])
		seed = clamp(round(text2num(world.params["memory-seed"])), 1, 65520)
	if(world.params["memory-population"])
		population = clamp(round(text2num(world.params["memory-population"])), 4, 48)
	if(world.params["memory-actions"])
		action_target = clamp(round(text2num(world.params["memory-actions"])), 200, 10000)
	random_state = seed
	return SS_INIT_SUCCESS

/** Small integer arithmetic remains exact in DM; this is a scenario generator, not statistical sampling. */
/datum/controller/subsystem/memory_random_workload/proc/choice(maximum)
	random_state = (random_state * 75 + 74) % 65521
	return 1 + random_state % maximum

/** Find diverse, reachable machinery-adjacent floor locations on the selected station. */
/datum/controller/subsystem/memory_random_workload/proc/prepare()
	for(var/obj/machinery/light_switch/switch_object in world)
		if(!is_station_level(switch_object.z))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/open/floor/candidate = get_step(switch_object, direction)
			if(istype(candidate) && !candidate.is_blocked_turf())
				spawns |= candidate
		CHECK_TICK
	if(!length(spawns))
		world.log << "MEMORY_RANDOM_ABORT no station spawn candidates"
		shutdown()
		return FALSE
	CONFIG_SET(flag/memory_profiler_enabled, TRUE)
	rustg_time_reset("memory-random-workload")
	sampling = TRUE
	sample_ticks()
	world.log << "MEMORY_RANDOM_START map=[SSmapping.current_map.map_name] seed=[seed] population=[population] actions=[action_target] spawn_candidates=[length(spawns)]"
	return TRUE

/** Observe scheduler delays with bounded storage; the timer loop also runs in the off control. */
/datum/controller/subsystem/memory_random_workload/proc/sample_ticks()
	set waitfor = FALSE
	var/last_ms = rustg_time_milliseconds("memory-random-workload")
	while(sampling)
		sleep(world.tick_lag)
		var/now_ms = rustg_time_milliseconds("memory-random-workload")
		var/elapsed = max(0, now_ms - last_ms)
		last_ms = now_ms
		if(!phase_started)
			continue
		tick_samples++
		tick_total_ms += elapsed
		tick_max_ms = max(tick_max_ms, elapsed)
		var/ratio = elapsed / (world.tick_lag * 100)
		var/bucket = ratio <= 1.25 ? 1 : (ratio <= 1.5 ? 2 : (ratio <= 2 ? 3 : (ratio <= 5 ? 4 : (ratio <= 10 ? 5 : 6))))
		tick_bins[bucket]++

/datum/controller/subsystem/memory_random_workload/fire(resumed)
	if(length(GLOB.clients))
		world.log << "MEMORY_RANDOM_ABORT client connected"
		pending?.finish("cancelled", "test_client_connected")
		can_fire = FALSE
		sampling = FALSE
		return
	if(SSticker.current_state != GAME_STATE_PLAYING || world.time < next_phase)
		return
	if(!length(spawns) && !prepare())
		return
	if(phase > 4)
		sampling = FALSE
		world.log << "MEMORY_RANDOM_DONE"
		shutdown()
		return
	if(!phase_started)
		phase_started = TRUE
		phase_start_ms = rustg_time_milliseconds("memory-random-workload")
		phase_start_random = random_state
		tick_bins = list(0, 0, 0, 0, 0, 0)
		tick_samples = 0
		tick_total_ms = 0
		tick_max_ms = 0
		counts = list()
		actions = 0
		action_ms = 0
		action_max_ms = 0
		world.Profile(PROFILE_CLEAR)
		world.Profile(PROFILE_START)
	process_reactions()
	var/ready = FALSE
	switch(phase)
		if(0)
			ready = TRUE
		if(1)
			if(length(actors) < population)
				spawn_actor()
			ready = length(actors) >= population
		if(2, 3)
			if(phase == 3 && length(actors) < min(96, population * 2))
				spawn_actor()
			for(var/batch in 1 to 4)
				if(actions >= action_target || TICK_CHECK)
					break
				rustg_time_reset("memory-random-action")
				random_action()
				var/elapsed = rustg_time_microseconds("memory-random-action") / 1000
				action_ms += elapsed
				action_max_ms = max(action_max_ms, elapsed)
				actions++
			if(actions >= action_target / 2 && !capture_requested)
				capture_phase()
			ready = actions >= action_target
		if(4)
			if(length(actors))
				var/mob/living/carbon/human/actor = actors[length(actors)]
				actors.Cut(length(actors), length(actors) + 1)
				qdel(actor)
				return
			if(!cleanup_until)
				for(var/area/controlled_area as anything in original_lights)
					var/obj/machinery/light_switch/switch_object = light_representatives[controlled_area]
					if(!QDELETED(switch_object))
						switch_object.set_lights(original_lights[controlled_area])
				original_lights.Cut()
				light_representatives.Cut()
				cleanup_until = world.time + 60 SECONDS
			ready = world.time >= cleanup_until && !length(reaction_vessels)
	if(ready && !capture_requested)
		capture_phase()
	if(ready && capture_requested && (pending ? pending.state == "done" : world.time >= control_until))
		finish_phase()

/** Spawn pairs around diverse station locations so both social/combat and machinery paths are reachable. */
/datum/controller/subsystem/memory_random_workload/proc/spawn_actor()
	var/turf/location = length(actors) % 2 ? get_turf(actors[length(actors)]) : spawns[choice(length(spawns))]
	if(!location)
		location = spawns[choice(length(spawns))]
	var/mob/living/carbon/human/actor = new(location)
	var/list/outfits = list(/datum/outfit/job/assistant, /datum/outfit/job/engineer, /datum/outfit/job/doctor, /datum/outfit/job/scientist)
	actor.equipOutfit(outfits[choice(length(outfits))])
	actors += actor
	counts["spawned"]++

/** One randomized gameplay operation; attempted and observable successful outcomes remain separate. */
/datum/controller/subsystem/memory_random_workload/proc/random_action()
	var/mob/living/carbon/human/actor = actors[choice(length(actors))]
	if(QDELETED(actor) || actor.stat || IS_UNCONSCIOUS(actor))
		counts["inactive_actor"]++
		return
	actor.set_combat_mode(FALSE)
	switch(choice(10))
		if(1 to 4)
			counts["move_attempt"]++
			var/turf/before = get_turf(actor)
			step(actor, GLOB.cardinals[choice(4)])
			counts["move_success"] += get_turf(actor) != before
		if(5)
			counts["storage_attempt"]++
			var/obj/item/backpack = actor.back
			if(!backpack?.atom_storage)
				return
			var/obj/item/reagent_containers/cup/beaker/item = new(get_turf(actor))
			if(actor.put_in_hands(item) && backpack.atom_storage.attempt_insert(item, actor))
				counts["storage_inserted"]++
				backpack.atom_storage.remove_single(actor, item, get_turf(actor))
				counts["storage_removed"] += item.loc == get_turf(actor)
			qdel(item)
		if(6)
			chemistry_action(actor)
		if(7)
			counts["appearance_attempt"]++
			actor.set_haircolor(actor.hair_color == "bb9966" ? "553322" : "bb9966", update = TRUE)
			counts["appearance_changed"]++
		if(8)
			counts["combat_attempt"]++
			for(var/mob/living/carbon/human/target in range(1, actor))
				if(target == actor || !(target in actors) || target.stat == DEAD)
					continue
				var/health_before = target.health
				actor.set_combat_mode(TRUE)
				actor.ClickOn(target, "")
				counts["combat_damage"] += target.health < health_before
				break
		if(9)
			counts["switch_attempt"]++
			for(var/obj/machinery/light_switch/switch_object in range(1, actor))
				var/old_state = switch_object.area.lightswitch
				if(!(switch_object.area in original_lights))
					original_lights[switch_object.area] = old_state
				light_representatives[switch_object.area] = switch_object
				actor.ClickOn(switch_object, "")
				counts["switch_changed"] += switch_object.area.lightswitch != old_state
				break
		if(10)
			counts["door_attempt"]++
			for(var/obj/machinery/door/door in range(1, actor))
				var/was_operating = door.operating
				var/was_dense = door.density
				actor.ClickOn(door, "")
				counts["door_activation_started"] += (!was_operating && door.operating) || (was_dense != door.density)
				break

/** Pour through the normal item interaction and retain the target until SSreagents has processed it. */
/datum/controller/subsystem/memory_random_workload/proc/chemistry_action(mob/living/carbon/human/actor)
	counts["chemistry_attempt"]++
	if(length(reaction_vessels) >= 64 || actor.get_active_held_item())
		return
	var/obj/item/reagent_containers/cup/beaker/source = new(get_turf(actor))
	var/obj/item/reagent_containers/cup/beaker/target = new(get_turf(actor))
	source.reagents.add_reagent(/datum/reagent/consumable/sugar, 5)
	target.reagents.add_reagent(/datum/reagent/water/salt, 10)
	actor.put_in_hands(source)
	actor.ClickOn(target, "")
	counts["chemistry_poured"] += source.reagents.total_volume < 5
	reaction_vessels[target] = world.time + 5 SECONDS
	qdel(source)

/** Check a bounded number of aged vessels per fire, then release ordinary ownership. */
/datum/controller/subsystem/memory_random_workload/proc/process_reactions()
	for(var/batch in 1 to 4)
		if(!length(reaction_vessels))
			return
		var/obj/item/reagent_containers/cup/beaker/target = reaction_vessels[1]
		if(!QDELETED(target) && world.time < reaction_vessels[target])
			return
		reaction_vessels.Cut(1, 2)
		if(!QDELETED(target))
			counts["chemistry_product"] += target.reagents.get_reagent_amount(/datum/reagent/medicine/salglu_solution) > 0
			qdel(target)

/** Start the normal conservative collector while random activity continues. */
/datum/controller/subsystem/memory_random_workload/proc/capture_phase()
	var/label = phase_names[phase + 1]
	text2file(label, "[GLOB.log_directory]/memory-[label].marker")
	capture_requested = TRUE
	if(world.params["memory-profile-off"])
		control_until = world.time + max(1, text2num(world.params["memory-delay-[phase]"]))
		return
	if(!SSmemory_profiler.start_capture())
		world.log << "MEMORY_RANDOM_ABORT capture refused"
		shutdown()
		return
	pending = SSmemory_profiler.job
	// The broad cache/GLOB walk starves actor descendants before its timing cap.
	// This explicit scenario scope follows the actors and in-flight chemistry.
	pending.roots = list(actors, reaction_vessels)
	pending.root_names = list("workload.actors", "workload.reaction_vessels")
	pending.output_path = "[GLOB.log_directory]/memory-[label].ndjson"
	pending.provenance["capture_id"] = label
	pending.provenance["evidence_class"] = "running_test_round_simulated_actors"
	pending.provenance["workload"] = "seeded-random-station-actions-v3"
	pending.provenance["simulated_actors"] = length(actors)
	pending.provenance["phase"] = label
	pending.provenance["seed"] = seed
	pending.provenance["random_state"] = random_state

/** Save independent proc/tick/action evidence after each phase; profile dump cost is explicit. */
/datum/controller/subsystem/memory_random_workload/proc/finish_phase()
	var/label = phase_names[phase + 1]
	var/end_ms = rustg_time_milliseconds("memory-random-workload")
	var/profile = world.Profile(PROFILE_REFRESH, format = "json")
	world.Profile(PROFILE_STOP)
	text2file(profile, "[GLOB.log_directory]/proc-[label].json")
	var/export_ms = rustg_time_milliseconds("memory-random-workload") - end_ms
	var/alive = 0
	for(var/mob/living/carbon/human/actor as anything in actors)
		alive += !QDELETED(actor) && actor.stat != DEAD
	var/list/report = list("phase" = label, "seed" = seed, "random_start" = phase_start_random, "random_end" = random_state, "real_clients" = length(GLOB.clients), "actors" = length(actors), "alive" = alive, "actions" = actions, "counts" = counts, "wall_ms" = end_ms - phase_start_ms, "action_ms" = action_ms, "action_max_ms" = action_max_ms, "tick_samples" = tick_samples, "tick_total_ms" = tick_total_ms, "tick_max_ms" = tick_max_ms, "tick_bins" = tick_bins, "tick_bin_upper_ratios" = list(1.25, 1.5, 2, 5, 10, null), "tick_expected_ms" = world.tick_lag * 100, "profile_export_ms" = export_ms, "pending_reactions" = length(reaction_vessels), "capture_status" = pending?.result, "capture_reason" = pending?.reason, "capture_total_ms" = pending?.total_ms, "capture_atomic_ms" = pending?.worst_atomic_ms, "capture_tick_ms" = pending?.worst_tick_ms, "capture_retained" = pending ? length(pending.entries) : 0)
	text2file(json_encode(report), "[GLOB.log_directory]/scenario-[label].json")
	world.log << "MEMORY_RANDOM_PHASE [label] actors=[length(actors)] alive=[alive] actions=[actions] capture=[pending?.reason] retained=[pending ? length(pending.entries) : 0]"
	pending = null
	capture_requested = FALSE
	phase_started = FALSE
	phase++
	next_phase = world.time + 5 SECONDS
#endif
