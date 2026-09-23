/** Restores Dogmos continuation and diagnostic state after the inherited SSair recovery. */
/datum/controller/subsystem/air/Recover()
	. = ..()
	// The Master owns state and queue links and resets them after replacement.
	// Preserve the phase and cycle separately so its first fire(FALSE) can resume.
	currentpart = SSair.currentpart
	times_fired = SSair.times_fired
	dogmos_resume_recovered_cycle = initialized && (SSair.dogmos_resume_recovered_cycle || SSair.state == SS_RUNNING || SSair.state == SS_PAUSED || length(SSair.dogmos_visual_refresh_batch))
	share_max_steps = SSair.share_max_steps
	equalize_enabled = SSair.equalize_enabled
	realistic_space_radiation = SSair.realistic_space_radiation
	flamethrower_directional_spread = SSair.flamethrower_directional_spread
	planet_share_ratio = SSair.planet_share_ratio
	excited_group_pressure_goal = SSair.excited_group_pressure_goal
	equalize_hard_turf_limit = SSair.equalize_hard_turf_limit
	dogmos_blocked_turf_temperature_authority = SSair.dogmos_blocked_turf_temperature_authority
	dogmos_equalize_performance_profile = SSair.dogmos_equalize_performance_profile
	dogmos_active_turf_stages_complete = SSair.dogmos_active_turf_stages_complete
	dogmos_equalize_stage_complete = SSair.dogmos_equalize_stage_complete
	dogmos_visual_refresh_batch = SSair.dogmos_visual_refresh_batch?.Copy() || list()
	dogmos_active_walk_complete = SSair.dogmos_active_walk_complete
	dogmos_visual_refresh_cursor = SSair.dogmos_visual_refresh_cursor
	dogmos_walk_prefetch_end = SSair.dogmos_walk_prefetch_end
	dogmos_visual_prefetch_end = SSair.dogmos_visual_prefetch_end
	dogmos_reacted_turfs = SSair.dogmos_reacted_turfs.Copy()

	kennel_slow_mode = SSair.kennel_slow_mode
	kennel_profile_reactions = SSair.kennel_profile_reactions
	kennel_high_cost_ms_threshold = SSair.kennel_high_cost_ms_threshold
	kennel_fire_group_notable_size = SSair.kennel_fire_group_notable_size
	kennel_reaction_magnitude_threshold = SSair.kennel_reaction_magnitude_threshold
	kennel_machine_cost_ms_threshold = SSair.kennel_machine_cost_ms_threshold
	kennel_auto_pin_duration = SSair.kennel_auto_pin_duration
	kennel_push_cursor = 0
	active_turfs_walk_cursor = SSair.active_turfs_walk_cursor

	recent_fire_groups = SSair.recent_fire_groups
	recent_high_cost_zones = SSair.recent_high_cost_zones
	recent_explosions = SSair.recent_explosions
	recent_reactions_of_interest = SSair.recent_reactions_of_interest
	recent_breaches = SSair.recent_breaches
	structures_of_interest = SSair.structures_of_interest

	cached_cost = SSair.cached_cost
	cost_atoms = SSair.cost_atoms
	cost_turfs = SSair.cost_turfs
	cost_fdm = SSair.cost_fdm
	cost_hotspots = SSair.cost_hotspots
	cost_groups = SSair.cost_groups
	cost_highpressure = SSair.cost_highpressure
	cost_superconductivity = SSair.cost_superconductivity
	cost_pipenets = SSair.cost_pipenets
	cost_atmos_machinery = SSair.cost_atmos_machinery
	cost_rebuilds = SSair.cost_rebuilds
	cost_adjacent = SSair.cost_adjacent
	cost_post_process = SSair.cost_post_process
	cost_equalize = SSair.cost_equalize
	low_pressure_turfs = SSair.low_pressure_turfs
	high_pressure_turfs = SSair.high_pressure_turfs
	num_group_turfs_processed = SSair.num_group_turfs_processed
	num_equalize_processed = SSair.num_equalize_processed
	dogmos_heat_graph_nodes = SSair.dogmos_heat_graph_nodes
	dogmos_heat_edge_attempts = SSair.dogmos_heat_edge_attempts
	dogmos_heat_edges_applied = SSair.dogmos_heat_edges_applied
	dogmos_heat_lock_contention = SSair.dogmos_heat_lock_contention
	dogmos_heat_registration_changes = SSair.dogmos_heat_registration_changes

	dogmos_reactions = init_dogmos_reactions(gas_reactions)
	recover_kennel_derived_state(SSair)
	RegisterSignal(SSdcs, COMSIG_GLOB_EXPLOSION, PROC_REF(on_kennel_explosion))
	// SSdogmos owns the native atmosphere arena; recovery must not initialize it twice.
