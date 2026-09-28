/** Dogmos scheduling state and bounded active-turf helpers owned by SSair. */
/datum/controller/subsystem/air
	/// Native diffusion only, included in cost_turfs (never an additive stage).
	var/cost_fdm = 0
	/// Cost of Dogmos' post_process() pass.
	var/cost_post_process = 0
	/// Cost of Dogmos' Katmos equalization pass.
	var/cost_equalize = 0
	/// Pipenets that performed reconciliation during the most recently started pipenet pass.
	var/dogmos_pipenets_reconciled = 0
	/// Candidate mixture references visited by those pipenet reconciliations.
	var/dogmos_pipenet_mixtures_reconciled = 0
	/// Maximum FDM iterations per Dogmos processing call.
	var/share_max_steps = 4
	/// Whether the Katmos pressure equalizer runs after FDM.
	var/equalize_enabled = TRUE
	/// Whether space-adjacent heat loss uses blackbody radiation instead of the gameplay sink.
	var/realistic_space_radiation = TRUE
	/// Whether flamethrowers use directional ignition spread.
	var/flamethrower_directional_spread = TRUE
	/// Sole owner of bounded diagnostics, pin membership and diagnostic policy.
	var/datum/dogmos_diagnostics/diagnostics = new
	/// Fraction shared with planetary atmosphere per FDM cycle.
	var/planet_share_ratio = 0.125
	/// Turfs last flagged as low pressure by Dogmos.
	var/low_pressure_turfs = 0
	/// Turfs last flagged as high pressure by Dogmos.
	var/high_pressure_turfs = 0
	/// Pressure delta at which Dogmos considers a group converged.
	var/excited_group_pressure_goal = 0.5
	/// Turfs processed by the last excited-group pass.
	var/num_group_turfs_processed = 0
	/// Maximum turfs touched by one Katmos equalization pass.
	var/equalize_hard_turf_limit = 2000
	/// Turfs processed by the last Katmos equalization pass.
	var/num_equalize_processed = 0
	/// Number of initial snapshot entries visited by this cycle's resumable maintenance walk.
	var/active_turfs_walk_cursor = 0
	/// Mutually exclusive active-turf maintenance, native dispatch and settlement phase.
	var/dogmos_active_phase = DOGMOS_ACTIVE_MAINTENANCE
	/// Whether equalization finished before a pressure-queue continuation.
	var/dogmos_equalize_stage_complete = FALSE
	/// Number of initial snapshot entries whose post-simulation visuals have been refreshed.
	var/dogmos_visual_refresh_cursor = 0
	/// End of the current maintenance chunk, retained across budget pauses.
	var/dogmos_walk_chunk_end = 0
	/// End of the current settlement chunk, retained across budget pauses.
	var/dogmos_visual_chunk_end = 0
	/// One-use continuation override after the Master replaces this subsystem and rebuilds its queue.
	var/dogmos_resume_recovered_cycle = FALSE
	/// Turfs that reacted during this active phase and must remain active for another evaluation.
	var/list/dogmos_reacted_turfs = list()
	/// Fixed initial active set, retained through maintenance, native stages and visual refresh.
	var/list/dogmos_visual_refresh_batch = list()
	/// Flat, uniquely-prioritised view of gas_reactions. Read by Dogmos; see init_dogmos_reactions().
	var/list/dogmos_reactions = list()

/** Returns whether this invocation begins a new SSair cycle health preflight. */
/datum/controller/subsystem/air/proc/dogmos_health_preflight_required(resumed)
	return !resumed

/** Visits at most one snapshot chunk, returning TRUE while maintenance remains.
 * The cursor advances before exposure callbacks, so resuming never repeats an emitted exposure.
 * Settling and reactivation mutate only the live queue, never this fixed snapshot.
 */
/datum/controller/subsystem/air/proc/walk_active_turfs_batch()
	var/list/snapshot = dogmos_visual_refresh_batch
	var/turf_count = length(snapshot)
	if(active_turfs_walk_cursor >= turf_count)
		return FALSE
	if(MC_TICK_CHECK)
		return TRUE
	if(active_turfs_walk_cursor >= dogmos_walk_chunk_end)
		dogmos_walk_chunk_end = min(active_turfs_walk_cursor + DOGMOS_ACTIVE_TURFS_WALK_BATCH_SIZE, turf_count)
		// Retain the chunk end when the tick budget is exhausted.
		if(MC_TICK_CHECK)
			return TRUE
	var/batch_end = dogmos_walk_chunk_end
	while(active_turfs_walk_cursor < batch_end)
		var/turf/open/active_turf = snapshot[++active_turfs_walk_cursor]
		if(QDELETED(active_turf) || !isopenturf(active_turf) || !active_turf.air)
			remove_from_active(active_turf)
		else if(active_turf.excited)
			if(active_turf.archived_cycle < times_fired)
				LINDA_CYCLE_ARCHIVE(active_turf)
			active_turf.current_cycle = times_fired
			active_turf.temperature_expose(active_turf.air, active_turf.air.return_temperature())
			if(!QDELETED(active_turf) && isopenturf(active_turf) && active_turf.air)
				// Wake differing neighbors before publication, but matching gas may
				// still react. Retirement belongs after native reactions and callbacks.
				turf_settled(active_turf)
		if(MC_TICK_CHECK)
			return TRUE
	return active_turfs_walk_cursor < turf_count

/** Resumes post-simulation visuals without repeating native stages or completed refreshes. */
/datum/controller/subsystem/air/proc/refresh_dogmos_visuals()
	var/list/snapshot = dogmos_visual_refresh_batch
	while(dogmos_visual_refresh_cursor < length(snapshot))
		if(MC_TICK_CHECK)
			return
		if(dogmos_visual_refresh_cursor >= dogmos_visual_chunk_end)
			dogmos_visual_chunk_end = min(dogmos_visual_refresh_cursor + DOGMOS_ACTIVE_TURFS_WALK_BATCH_SIZE, length(snapshot))
			if(MC_TICK_CHECK)
				return
		var/batch_end = dogmos_visual_chunk_end
		while(dogmos_visual_refresh_cursor < batch_end)
			var/turf/open/active_turf = snapshot[++dogmos_visual_refresh_cursor]
			if(!QDELETED(active_turf) && isopenturf(active_turf) && active_turf.air)
				if(active_turf.excited && turf_settled(active_turf) && !dogmos_reacted_turfs[active_turf])
					remove_from_active(active_turf)
				active_turf.update_visuals()
				diagnostics.check_kennel_reaction_of_interest(active_turf)
			if(MC_TICK_CHECK)
				return
	dogmos_visual_refresh_batch.Cut()
	dogmos_reacted_turfs.Cut()
	active_turfs_walk_cursor = 0
	dogmos_visual_refresh_cursor = 0
	dogmos_walk_chunk_end = 0
	dogmos_visual_chunk_end = 0

/** Returns TRUE when a turf has no active hotspot and matches its open neighbors.
 * Mutable neighbors with different air are activated before this cycle's frontier publication.
 * Immutable sources settle after waking mutable neighbors. Immutable boundaries remain fixed, but
 * keep a mutable source active until it converges within the normal comparison tolerance.
 */
/datum/controller/subsystem/air/proc/turf_settled(turf/open/T)
	// Classify live neighbors in one crossing; native code releases its locks
	// before invoking the existing DM wake path, including dormant machinery.
	return __turf_settled(T)

/** Initializes a bounded turf batch in order, preserving its cycle stamps. */
/datum/controller/subsystem/air/proc/dogmos_initialize_turf_batch(list/batch, list/difference_check, time)
	for(var/turf/setup as anything in batch)
		if(QDELETED(setup) || !setup.init_air)
			continue
		setup.Initalize_Atmos(time)
		difference_check += setup
		if(CHECK_TICK)
			time--
	return time
