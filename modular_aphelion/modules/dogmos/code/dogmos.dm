/// Runtime count captured after subsystem initialization.
GLOBAL_VAR_INIT(runtimes_at_init_complete, 0)

/datum/controller/subsystem/air
	/// Temperature source used by blocked-turf consumers.
	var/dogmos_blocked_turf_temperature_authority = DOGMOS_TEMPERATURE_AUTHORITY_RUST
	/// Pressure-processing profile used after FDM diffusion.
	var/dogmos_equalize_performance_profile = DOGMOS_EQUALIZE_PROFILE_FAST_ZONE
	/// Heat-graph nodes observed by the most recent completed cycle.
	var/dogmos_heat_graph_nodes = 0
	/// Unique heat edges considered by the most recent cycle.
	var/dogmos_heat_edge_attempts = 0
	/// Unique heat edges applied by the most recent cycle.
	var/dogmos_heat_edges_applied = 0
	/// Temperature writes that waited for a lock in the most recent cycle.
	var/dogmos_heat_lock_contention = 0
	/// Heat-graph insertions and removals since the previous completed cycle.
	var/dogmos_heat_registration_changes = 0

/** Initializes Dogmos' gas registry before turfs create gas mixtures. */
SUBSYSTEM_DEF(dogmos)
	name = "Dogmos"
	init_stage = INITSTAGE_EARLY
	ss_flags = SS_NO_FIRE
	/// Subsystems that must wait for Dogmos initialization.
	dependents = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)

	/// TRUE after the Rust gas registry initializes successfully.
	var/gases_registered = FALSE

/datum/controller/subsystem/dogmos/Initialize()
	// Build the reaction table before the Rust registry starts.
	SSair.gas_reactions = init_gas_reactions()
	SSair.dogmos_reactions = init_dogmos_reactions(SSair.gas_reactions)

	if(!length(SSair.dogmos_reactions))
		stack_trace("init_dogmos_reactions() produced an empty list - Dogmos will run with no reactions at all.")

	populate_gas_data_overlays()

	if(!auxtools_atmos_init(GLOB.gas_data))
		stack_trace("auxtools_atmos_init() did not report success - Dogmos may hold an incomplete gas registry.")
		return SS_INIT_FAILURE

	gases_registered = TRUE
	#ifdef UNIT_TESTS
	if(GLOB.focused_tests?.Find(/datum/unit_test/dogmos_shift_start_performance) \
		|| GLOB.focused_tests?.Find(/datum/unit_test/dogmos_shift_start_performance/profile))
		INVOKE_ASYNC(src, PROC_REF(record_shift_start_performance))
	#endif
	return SS_INIT_SUCCESS

/** Preserves the live service session and every DM-side identity boundary across MC recovery. */
/datum/controller/subsystem/dogmos/Recover()
	ss_flags |= SS_NO_INIT
	initialized = SSdogmos.initialized
	gases_registered = SSdogmos.gases_registered
	service_ready = SSdogmos.service_ready
	service_failure_latched = SSdogmos.service_failure_latched
	dogmos_mixture_slots = SSdogmos.dogmos_mixture_slots
	dogmos_mixture_generations = SSdogmos.dogmos_mixture_generations
	dogmos_free_mixture_slots = SSdogmos.dogmos_free_mixture_slots
	dogmos_gas_ids = SSdogmos.dogmos_gas_ids
	dogmos_gas_paths = SSdogmos.dogmos_gas_paths
	dogmos_reaction_ids = SSdogmos.dogmos_reaction_ids
	dogmos_holder_slots = SSdogmos.dogmos_holder_slots
	dogmos_holder_generations = SSdogmos.dogmos_holder_generations
	dogmos_free_holder_slots = SSdogmos.dogmos_free_holder_slots
	dogmos_next_callback_sequence = SSdogmos.dogmos_next_callback_sequence
	dogmos_pending_callback_batch = SSdogmos.dogmos_pending_callback_batch
	dogmos_pending_callback_index = SSdogmos.dogmos_pending_callback_index
	dogmos_pending_callback_count = SSdogmos.dogmos_pending_callback_count
	dogmos_pending_service_callbacks = SSdogmos.dogmos_pending_service_callbacks
	dogmos_stale_callback_count = SSdogmos.dogmos_stale_callback_count
	dogmos_health_preflight_count = SSdogmos.dogmos_health_preflight_count
	turf_registration_batching = SSdogmos.turf_registration_batching
	dogmos_pending_turf_lifecycle = SSdogmos.dogmos_pending_turf_lifecycle
	dogmos_pending_turf_adjacency = SSdogmos.dogmos_pending_turf_adjacency
	dogmos_pending_turf_adjacency_index = SSdogmos.dogmos_pending_turf_adjacency_index
	dogmos_pending_turf_heat = SSdogmos.dogmos_pending_turf_heat
	dogmos_pending_turf_heat_adjacency = SSdogmos.dogmos_pending_turf_heat_adjacency
	dogmos_pending_turf_heat_adjacency_index = SSdogmos.dogmos_pending_turf_heat_adjacency_index
	dogmos_pending_adjacency_retry = SSdogmos.dogmos_pending_adjacency_retry
	runtime_topology_batching = SSdogmos.runtime_topology_batching
	dogmos_runtime_topology_records = SSdogmos.dogmos_runtime_topology_records
	dogmos_runtime_topology_calls = SSdogmos.dogmos_runtime_topology_calls
	dogmos_runtime_topology_max_queued = SSdogmos.dogmos_runtime_topology_max_queued
	dogmos_runtime_topology_deferrals = SSdogmos.dogmos_runtime_topology_deferrals
	dogmos_mixture_cache = SSdogmos.dogmos_mixture_cache
	dogmos_mixture_cache_epoch = SSdogmos.dogmos_mixture_cache_epoch
	dogmos_mixture_cache_hits = SSdogmos.dogmos_mixture_cache_hits
	dogmos_mixture_cache_misses = SSdogmos.dogmos_mixture_cache_misses
	dogmos_mixture_cache_collisions = SSdogmos.dogmos_mixture_cache_collisions
	dogmos_mixture_cache_epoch_invalidations = SSdogmos.dogmos_mixture_cache_epoch_invalidations

/** Stops Dogmos workers and releases its Rust-side arenas. */
/datum/controller/subsystem/dogmos/Shutdown()
	if(gases_registered)
		dogmos_shutdown()
	gases_registered = FALSE
	return ..()

/** Shares gas overlay lists with Dogmos' visual callback. */
/datum/controller/subsystem/dogmos/proc/populate_gas_data_overlays()
	var/list/meta_overlays = GLOB.meta_gas_info[META_GAS_OVERLAY]
	for(var/gas_path in GLOB.gas_data.datums)
		var/datum/gas/gas_instance = GLOB.gas_data.datums[gas_path]
		var/list/overlay_table = meta_overlays[gas_path]
		if(length(overlay_table))
			GLOB.gas_data.overlays[gas_instance.id] = overlay_table

/// Reinforced floors keep their surface during Dogmos decompression events.
/turf/open/floor/engine
	decompression_floor_rip_resistant = TRUE

/turf/open/floor/plating/reinforced
	decompression_floor_rip_resistant = TRUE

#define DOGMOS_GOGGLE_MODE_NONE ""
#define DOGMOS_GOGGLE_MODE_MESON "meson"
#define DOGMOS_GOGGLE_MODE_TRAY "t-ray"
#define DOGMOS_GOGGLE_MODE_PIPE_CONNECTABLE "connectable"
#define DOGMOS_GOGGLE_MODE_ATMOS_THERMAL "atmospheric-thermal"
#define DOGMOS_GOGGLE_MODE_AREA_BLUEPRINTS "area-blueprints"

/** Station-safe atmospheric imaging goggles for Dogmos work. */
/obj/item/clothing/glasses/meson/engine/dogmos
	name = "Dogmos atmospheric imaging goggles"
	desc = "Engineering goggles with meson, T-ray, pipe-connection, thermal, breach-alert, and reaction-profile modes."
	range = 3
	modes = list(
		DOGMOS_GOGGLE_MODE_NONE,
		DOGMOS_GOGGLE_MODE_MESON,
		DOGMOS_GOGGLE_MODE_TRAY,
		DOGMOS_GOGGLE_MODE_PIPE_CONNECTABLE,
		DOGMOS_GOGGLE_MODE_ATMOS_THERMAL,
		DOGMOS_GOGGLE_MODE_BREACHES,
		DOGMOS_GOGGLE_MODE_REACTIONS,
	)

/** Returns the Kennel overlay categories represented by the current mode. */
/obj/item/clothing/glasses/meson/engine/dogmos/proc/dogmos_overlay_categories()
	switch(mode)
		if(DOGMOS_GOGGLE_MODE_BREACHES)
			return list(KENNEL_OVERLAY_BREACH)
		if(DOGMOS_GOGGLE_MODE_REACTIONS)
			return list(KENNEL_OVERLAY_REACTION)
		if(DOGMOS_GOGGLE_MODE_HIGH_COST)
			return list(KENNEL_OVERLAY_HIGH_COST)
		if(DOGMOS_GOGGLE_MODE_STRUCTURES)
			return list(KENNEL_OVERLAY_STRUCTURE)
		if(DOGMOS_GOGGLE_MODE_ALL)
			return list(
				KENNEL_OVERLAY_BREACH,
				KENNEL_OVERLAY_HIGH_COST,
				KENNEL_OVERLAY_REACTION,
				KENNEL_OVERLAY_STRUCTURE,
			)
	return list()

/** Returns all category images selected by the current goggles mode. */
/obj/item/clothing/glasses/meson/engine/dogmos/proc/dogmos_overlay_images()
	var/list/selected_images = list()
	for(var/category in dogmos_overlay_categories())
		selected_images += GLOB.kennel_overlay_images_by_category[category]
	return selected_images

/** Synchronizes the selected Kennel overlay images with the current wearer. */
/obj/item/clothing/glasses/meson/engine/dogmos/proc/update_dogmos_overlay_images()
	var/mob/living/carbon/human/wearer = loc
	if(!istype(wearer) || wearer.glasses != src || !wearer.client)
		return
	if(!wearer.hud_used?.atmos_debug_overlays)
		wearer.client.images -= GLOB.kennel_overlay_images
	wearer.client.images |= dogmos_overlay_images()

/// Shows the selected Kennel overlays when these goggles enter the eye slot.
/obj/item/clothing/glasses/meson/engine/dogmos/equipped(mob/living/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_EYES)
		update_dogmos_overlay_images()

/// Removes goggles-owned Kennel overlays when the wearer drops them.
/obj/item/clothing/glasses/meson/engine/dogmos/dropped(mob/living/user)
	if(user?.client && !user.hud_used?.atmos_debug_overlays)
		user.client.images -= GLOB.kennel_overlay_images
	return ..()

/// Removes goggles-owned Kennel overlays before the item is deleted.
/obj/item/clothing/glasses/meson/engine/dogmos/Destroy()
	var/mob/living/carbon/human/wearer = loc
	if(istype(wearer) && wearer.client && !wearer.hud_used?.atmos_debug_overlays)
		wearer.client.images -= GLOB.kennel_overlay_images
	return ..()

/// Refreshes the selected Kennel overlays after the inherited mode switch.
/obj/item/clothing/glasses/meson/engine/dogmos/toggle_mode(mob/user, voluntary)
	var/mob/living/carbon/human/wearer = loc
	if(istype(wearer) && wearer.client && !wearer.hud_used?.atmos_debug_overlays)
		wearer.client.images -= GLOB.kennel_overlay_images
	. = ..()
	update_dogmos_overlay_images()

/obj/item/clothing/glasses/meson/engine/dogmos/update_icon_state()
	. = ..()
	switch(mode)
		if(DOGMOS_GOGGLE_MODE_BREACHES, DOGMOS_GOGGLE_MODE_REACTIONS, DOGMOS_GOGGLE_MODE_HIGH_COST, DOGMOS_GOGGLE_MODE_STRUCTURES, DOGMOS_GOGGLE_MODE_ALL)
			icon_state = inhand_icon_state = worn_icon_state = "trayson-atmospheric-thermal"

/** Administrative atmospheric imaging goggles with the complete Dogmos debugging set. */
/obj/item/clothing/glasses/meson/engine/dogmos/admin
	name = "Dogmos administrative imaging goggles"
	desc = "Administrative goggles with the complete engineering and Kennel overlay set, including area-blueprint imaging."
	range = 7
	modes = list(
		DOGMOS_GOGGLE_MODE_NONE,
		DOGMOS_GOGGLE_MODE_MESON,
		DOGMOS_GOGGLE_MODE_TRAY,
		DOGMOS_GOGGLE_MODE_PIPE_CONNECTABLE,
		DOGMOS_GOGGLE_MODE_ATMOS_THERMAL,
		DOGMOS_GOGGLE_MODE_BREACHES,
		DOGMOS_GOGGLE_MODE_REACTIONS,
		DOGMOS_GOGGLE_MODE_HIGH_COST,
		DOGMOS_GOGGLE_MODE_STRUCTURES,
		DOGMOS_GOGGLE_MODE_ALL,
		DOGMOS_GOGGLE_MODE_AREA_BLUEPRINTS,
	)

/datum/design/dogmos_goggles
	name = "Dogmos Atmospheric Imaging Goggles"
	desc = "Engineering goggles tuned for Dogmos troubleshooting without administrative area-blueprint access."
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 5,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT * 5,
		/datum/material/plasma = SMALL_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/clothing/glasses/meson/engine/dogmos
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_ENGINEERING,
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

#undef DOGMOS_GOGGLE_MODE_NONE
#undef DOGMOS_GOGGLE_MODE_MESON
#undef DOGMOS_GOGGLE_MODE_TRAY
#undef DOGMOS_GOGGLE_MODE_PIPE_CONNECTABLE
#undef DOGMOS_GOGGLE_MODE_ATMOS_THERMAL
#undef DOGMOS_GOGGLE_MODE_AREA_BLUEPRINTS
