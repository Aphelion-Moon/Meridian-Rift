/// Ordinary qdel state is checked without resolving weak references or invoking target procs.
#define MEMORY_CAPTURE_DELETED(value) QDELETED(value)
/// Never follow the scheduler back into collector-owned state.
#define MEMORY_CAPTURE_EXCLUDED(value) istype(value, /datum/controller/subsystem/memory_profiler)
#include "capture.dm"
#undef MEMORY_CAPTURE_DELETED
#undef MEMORY_CAPTURE_EXCLUDED

/// Explicit opt-in. No collection at startup or while disabled.
/datum/config_entry/flag/memory_profiler_enabled

/// These settings only reduce conservative hard caps.
/datum/config_entry/number/memory_profiler_nodes
	default = MEMORY_NODE_LIMIT
	min_val = 16
	max_val = MEMORY_NODE_LIMIT

/datum/config_entry/number/memory_profiler_edges
	default = 8192
	min_val = 16
	max_val = 8192

/datum/config_entry/number/memory_profiler_slots
	default = MEMORY_SLOT_LIMIT
	min_val = 1
	max_val = MEMORY_SLOT_LIMIT

/datum/config_entry/number/memory_profiler_work
	default = MEMORY_WORK_LIMIT
	min_val = 32
	max_val = MEMORY_WORK_LIMIT

/datum/config_entry/number/memory_profiler_depth
	default = 8
	min_val = 1
	max_val = 8

/datum/config_entry/number/memory_profiler_seconds
	default = 60
	min_val = 1
	max_val = 60

/datum/config_entry/number/memory_profiler_output_bytes
	default = MEMORY_OUTPUT_LIMIT
	min_val = 8192
	max_val = MEMORY_OUTPUT_LIMIT

/datum/config_entry/number/memory_profiler_budget_ms
	default = 1
	min_val = 0.1
	max_val = 1
	integer = FALSE

/** Scheduler integration; every phase shares the same per-tick allowance. */
SUBSYSTEM_DEF(memory_profiler)
	name = "Memory Profiler"
	ss_flags = SS_NO_INIT|SS_BACKGROUND
	wait = 1
	priority = 1
	runlevels = RUNLEVELS_DEFAULT|RUNLEVEL_LOBBY
	/// At most one job, including its incremental cleanup.
	var/datum/memory_capture/job
	/// Collision-free suffix within this server lifetime.
	var/capture_number = 0

/datum/controller/subsystem/memory_profiler/fire(resumed)
	if(!job || job.state == "done")
		return
	if(!CONFIG_GET(flag/memory_profiler_enabled))
		job.finish("cancelled", "disabled")
	job.tick()

/** Create one conservative selected-root capture. No discovery copies or live client scan. */
/datum/controller/subsystem/memory_profiler/proc/start_capture()
	if(!CONFIG_GET(flag/memory_profiler_enabled) || (job && job.state != "done"))
		return FALSE
	capture_number++
	var/capture_id = "[time2text(world.realtime, "YYYYMMDD-hhmmss")]-[capture_number]"
	job = new("[GLOB.log_directory]/memory-[capture_id].ndjson", list(
		"capture_id" = capture_id,
		"run_id" = "[GLOB.round_id]-[world.system_type]-[time2text(world.realtime - world.time, "YYYYMMDD-hhmmss")]",
		"timestamp_local" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"),
		"byond" = "[world.byond_version].[world.byond_build]",
		"os" = world.system_type,
		"architecture" = "x86",
		"commit" = GLOB.revdata?.commit,
		"round" = GLOB.round_id,
		"map" = SSmapping.current_map?.map_name,
		"real_clients" = length(GLOB.clients),
		"simulated_actors" = null,
		"workload" = "operator-selected-round",
		"evidence_class" = "unclassified_operator_capture",
		"native_versions" = list("rust_g_declared" = "7.0.0", "loaded_version" = null),
	))
	job.node_limit = CONFIG_GET(number/memory_profiler_nodes)
	job.edge_limit = CONFIG_GET(number/memory_profiler_edges)
	job.slot_limit = CONFIG_GET(number/memory_profiler_slots)
	job.work_limit = CONFIG_GET(number/memory_profiler_work)
	job.depth_limit = CONFIG_GET(number/memory_profiler_depth)
	job.duration_limit = CONFIG_GET(number/memory_profiler_seconds) SECONDS
	job.output_limit = CONFIG_GET(number/memory_profiler_output_bytes)
	job.budget_ms = CONFIG_GET(number/memory_profiler_budget_ms)
	// Prioritize known caches so an early partial report still has actionable roots.
#ifdef USE_RUSTG_ICONFORGE_GAGS
	job.add_root(SSgreyscale.gags_cache, "SSgreyscale.gags_cache")
#endif
	job.add_root(SSassets.cache, "SSassets.cache")
	job.add_root(SStimer.hashes, "SStimer.hashes")
	job.add_root(SSgarbage.queues, "SSgarbage.queues")
	job.add_root(SSgreyscale, "SSgreyscale")
	job.add_root(SSassets, "SSassets")
	job.add_root(SStimer, "SStimer")
	job.add_root(SSgarbage, "SSgarbage")
	job.add_root(GLOB, "GLOB")
	return TRUE

/** Permission-checked operator control; the transport is exported automatically as it is collected. */
ADMIN_VERB(memory_capture_control, R_DEBUG, "Memory Capture", "Control a bounded experimental memory capture.", ADMIN_CATEGORY_DEBUG)
	var/action = tgui_input_list(user, "Collection is experimental: inspect partial reasons and measured pauses before live qualification.", "Memory capture", list("Status", "Start", "Pause", "Resume", "Cancel", "Export path"))
	if(!action || !check_rights_for(user, R_DEBUG))
		return
	var/datum/memory_capture/job = SSmemory_profiler.job
	switch(action)
		if("Start")
			if(!SSmemory_profiler.start_capture())
				to_chat(user, "Enable MEMORY_PROFILER_ENABLED in configuration and wait for the previous job to finish cleanup.")
				return
			job = SSmemory_profiler.job
		if("Pause")
			if(job)
				job.paused = TRUE
		if("Resume")
			if(job)
				job.paused = FALSE
		if("Cancel")
			job?.finish("cancelled", "operator_cancelled")
	if(action in list("Start", "Pause", "Resume", "Cancel"))
		log_admin("[key_name(user)] memory capture [action]; nodes=[job?.node_limit], edges=[job?.edge_limit], slots=[job?.slot_limit], work=[job?.work_limit], depth=[job?.depth_limit], duration_ds=[job?.duration_limit], output=[job?.output_limit], tick=min([job?.budget_ms]ms,2%).")
	if(job)
		to_chat(user, "Memory capture: [job.state], result=[job.result], reason=[job.reason], nodes=[job.node_count], edges=[job.edge_count], work=[job.work], retained=[length(job.entries)], worst step=[job.worst_atomic_ms]ms. Export: [job.output_path]")
	else
		to_chat(user, "No memory capture has been started.")

#include "workload.dm"
