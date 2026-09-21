/** Adopts the existing native arena; controller recovery must not initialize it twice. */
/datum/controller/subsystem/dogmos/Recover()
	ss_flags |= SS_NO_INIT
	initialized = SSdogmos.initialized
	gases_registered = SSdogmos.gases_registered
	SSdogmos.gases_registered = FALSE
	populate_gas_data_overlays()

/** Native state is shared in-process; the DM list only schedules exposures and visuals. */
/datum/controller/subsystem/air/proc/dogmos_add_frontier_member(turf/active_turf)
	active_turfs += active_turf

/datum/controller/subsystem/air/proc/dogmos_remove_frontier_member(turf/active_turf)
	var/previous_count = length(active_turfs)
	active_turfs -= active_turf
	return length(active_turfs) != previous_count

/datum/controller/subsystem/air/proc/dogmos_clear_active_frontier()
	active_turfs.Cut()

/datum/controller/subsystem/air/proc/dogmos_replace_active_frontier(list/replacement)
	active_turfs = replacement

/** Main-thread reaction callback, including public mixture signals and retirement protection. */
/turf/open/proc/dogmos_react()
	if(QDELETED(src) || !air)
		return
	. = air.react(src)
	if(. && !QDELETED(src))
		SSair.dogmos_reacted_turfs[src] = TRUE

/** Preserves the shuttle's destination-before-source atmosphere update ordering. */
/datum/controller/subsystem/dogmos/proc/block_shuttle_turfs(turf/source_turf, turf/destination_turf)
	SHOULD_NOT_SLEEP(TRUE)
	destination_turf.blocks_air = TRUE
	destination_turf.air_update_turf(TRUE, FALSE)
	source_turf.blocks_air = TRUE
	source_turf.air_update_turf(TRUE, TRUE)

/** Template initialization has completed before publishing its final border adjacency. */
/datum/controller/subsystem/dogmos/proc/update_template_border(list/turfs)
	SHOULD_NOT_SLEEP(TRUE)
	for(var/turf/affected_turf as anything in turfs)
		affected_turf.air_update_turf(TRUE, TRUE)
		affected_turf.levelupdate()

/** Samples the DreamDaemon host; there is no dogmosd process in this backend. */
/proc/dogmos_process_metrics_snapshot()
	return json_decode(dogmos_in_process_metrics())

/** Retains pipeline mass/energy arithmetic while accessing native mixtures directly. */
/proc/dogmos_reconcile_pipeline_mixtures(list/datum/gas_mixture/gas_mixture_list)
	var/static/process_id = 0
	process_id = WRAP_UID(process_id + 1)
	var/list/datum/gas_mixture/unique_mixtures = list()
	var/datum/gas_mixture/total_gas_mixture = new
	var/list/cached_specific_heat = GAS_META[META_GAS_SPECIFIC_HEAT]
	var/total_thermal_energy = 0
	var/total_heat_capacity = 0
	var/volume_sum = 0
	for(var/datum/gas_mixture/gas_mixture as anything in gas_mixture_list)
		if(gas_mixture.pipeline_cycle == process_id)
			continue
		gas_mixture.pipeline_cycle = process_id
		unique_mixtures += gas_mixture
		volume_sum += gas_mixture.return_volume()
		var/list/giver_cached_moles = gas_mixture.get_moles_list()
		var/heat_capacity = values_dot(giver_cached_moles, cached_specific_heat)
		var/list/gas_deltas = list()
		for(var/gas_id, amount in giver_cached_moles)
			gas_deltas += list(gas_id, amount)
		if(length(gas_deltas))
			total_gas_mixture.adjust_multi(arglist(gas_deltas))
		total_heat_capacity += heat_capacity
		total_thermal_energy += gas_mixture.return_temperature() * heat_capacity
	if(volume_sum == 0)
		return
	total_gas_mixture.set_volume(volume_sum)
	total_gas_mixture.set_temperature(total_heat_capacity ? total_thermal_energy / total_heat_capacity : 0)
	for(var/datum/gas_mixture/gas_mixture as anything in unique_mixtures)
		gas_mixture.copy_from_ratio(total_gas_mixture, gas_mixture.return_volume() / volume_sum)
