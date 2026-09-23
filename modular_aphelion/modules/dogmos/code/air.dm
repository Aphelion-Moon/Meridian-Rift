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
	/// Whether the Kennel UI uses its reduced payload and update cadence.
	var/kennel_slow_mode = TRUE
	/// Round-robin cursor for Kennel UI updates.
	var/kennel_push_cursor = 0
	/// Recent notable fire groups, newest first.
	var/list/recent_fire_groups = list()
	/// Recent high-cost reaction samples.
	var/list/recent_high_cost_zones = list()
	/// Whether reaction calls are timed for high-cost Kennel entries.
	var/kennel_profile_reactions = FALSE
	/// Minimum reaction duration, in milliseconds, for a high-cost entry.
	var/kennel_high_cost_ms_threshold = 0.5
	/// Recent explosions.
	var/list/recent_explosions = list()
	/// Recent reactions above the configured magnitude.
	var/list/recent_reactions_of_interest = list()
	/// Recent turfs showing breach overlays.
	var/list/kennel_overlay_breach_turfs = list()
	/// Recent turfs showing high-cost overlays.
	var/list/kennel_overlay_high_cost_turfs = list()
	/// Recent turfs showing reaction overlays.
	var/list/kennel_overlay_reaction_turfs = list()
	/// Recent hull breaches.
	var/list/recent_breaches = list()
	/// Last player-facing decompression feedback time, keyed by area REF or z-level fallback.
	var/list/kennel_breach_feedback_times = list()
	/// Atmos machinery pinned for inspection; automatic pins expire, manual pins do not.
	var/list/structures_of_interest = list()
	/// REF(turf) -> weakref for recent Kennel event jump targets.
	var/list/kennel_jump_targets = list()
	/// Number of retained event rows using each jump target ref.
	var/list/kennel_jump_target_counts = list()
	/// REF(machine) -> weakref to the turf used for its structure overlay.
	var/list/kennel_pinned_turfs = list()
	/// Per-machine process cost EWMA, keyed by REF(machine).
	var/list/kennel_machine_cost_ewma = list()
	/// Minimum peak fire-group size to record.
	var/kennel_fire_group_notable_size = 5
	/// Minimum reaction magnitude to record.
	var/kennel_reaction_magnitude_threshold = 20
	/// Minimum process_atmos() cost, in milliseconds, for auto-pinning.
	var/kennel_machine_cost_ms_threshold = 2
	/// Lifetime of automatic structure pins.
	var/kennel_auto_pin_duration = 10 MINUTES
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
	/// Whether native simulation completed before a callback-drain resume.
	var/dogmos_active_turf_stages_complete = FALSE
	/// Whether equalization finished before a pressure-queue continuation.
	var/dogmos_equalize_stage_complete = FALSE
	/// Whether this cycle's complete maintenance walk has published its frontier.
	var/dogmos_active_walk_complete = FALSE
	/// Number of initial snapshot entries whose post-simulation visuals have been refreshed.
	var/dogmos_visual_refresh_cursor = 0
	/// End of the current maintenance chunk, retained across budget pauses.
	var/dogmos_walk_prefetch_end = 0
	/// End of the current settlement chunk, retained across budget pauses.
	var/dogmos_visual_prefetch_end = 0
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
	if(active_turfs_walk_cursor >= dogmos_walk_prefetch_end)
		dogmos_walk_prefetch_end = min(active_turfs_walk_cursor + DOGMOS_ACTIVE_TURFS_WALK_BATCH_SIZE, turf_count)
		// Retain the chunk end when the tick budget is exhausted.
		if(MC_TICK_CHECK)
			return TRUE
	var/batch_end = dogmos_walk_prefetch_end
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
		if(dogmos_visual_refresh_cursor >= dogmos_visual_prefetch_end)
			dogmos_visual_prefetch_end = min(dogmos_visual_refresh_cursor + DOGMOS_ACTIVE_TURFS_WALK_BATCH_SIZE, length(snapshot))
			if(MC_TICK_CHECK)
				return
		var/batch_end = dogmos_visual_prefetch_end
		while(dogmos_visual_refresh_cursor < batch_end)
			var/turf/open/active_turf = snapshot[++dogmos_visual_refresh_cursor]
			if(!QDELETED(active_turf) && isopenturf(active_turf) && active_turf.air)
				if(active_turf.excited && turf_settled(active_turf) && !dogmos_reacted_turfs[active_turf])
					remove_from_active(active_turf)
				active_turf.update_visuals()
				check_kennel_reaction_of_interest(active_turf)
			if(MC_TICK_CHECK)
				return
	dogmos_visual_refresh_batch.Cut()
	dogmos_reacted_turfs.Cut()
	active_turfs_walk_cursor = 0
	dogmos_visual_refresh_cursor = 0
	dogmos_walk_prefetch_end = 0
	dogmos_visual_prefetch_end = 0

/** Returns TRUE when a turf has no active hotspot and matches its open neighbors.
 * Mutable neighbors with different air are activated before this cycle's frontier publication.
 * Immutable sources settle after waking mutable neighbors. Immutable boundaries remain fixed, but
 * keep a mutable source active until it converges within the normal comparison tolerance.
 */
/datum/controller/subsystem/air/proc/turf_settled(turf/open/T)
	// Classify live neighbors in one crossing; native code releases its locks
	// before invoking the existing DM wake path, including dormant machinery.
	return __turf_settled(T)

/** Prefetches own gas before initialization reads its visuals, preserving turf order and cycle stamps. */
/datum/controller/subsystem/air/proc/dogmos_initialize_turf_batch(list/batch, list/difference_check, time)
	for(var/turf/setup as anything in batch)
		if(QDELETED(setup) || !setup.init_air)
			continue
		setup.Initalize_Atmos(time)
		difference_check += setup
		if(CHECK_TICK)
			time--
	return time
