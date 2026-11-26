/// Maximum entries permitted in one active-turf maintenance chunk.
#define ACTIVE_TURFS_BLOAT_TEST_MAX_ENTRIES 100

/** Bounds the legacy active-turf walk independently of gas movement. */
/datum/unit_test/dogmos_active_turfs_bloat

/datum/unit_test/dogmos_active_turfs_bloat/Run()
	var/list/pair = allocate_turf_pair()
	var/turf/open/turf_a = pair[1]
	var/turf/open/turf_b = pair[2]

	// The regression is driven by list length, so repeated turfs are sufficient.
	var/list/saved = SSair.active_turfs
	var/list/bloated = list(turf_a, turf_b)
	for(var/i in 1 to 1900)
		bloated += turf_a
		bloated += turf_b
	SSair.dogmos_replace_active_frontier(bloated)
	var/backup = SSair.active_turfs_walk_cursor
	SSair.active_turfs_walk_cursor = 0
	var/list/previous = SSair.dogmos_visual_refresh_batch
	var/old_value = SSair.dogmos_walk_chunk_end
	SSair.dogmos_walk_chunk_end = 0
	var/old_state = SSair.state
	var/original_tick_limit = Master.current_ticklimit
	var/list/values = list()
	for(var/turf/open/target as anything in pair)
		values[target] = list(target.excited, target.excited_group, target.current_cycle, target.archived_cycle)
		target.excited = TRUE
		target.excited_group = null
		target.archived_cycle = SSair.times_fired
	SSair.dogmos_visual_refresh_batch = bloated.Copy()
	SSair.state = SS_RUNNING
	Master.current_ticklimit = TICK_USAGE + 100 / world.tick_lag

	var/start_time = TICK_USAGE_REAL
	var/processing = SSair.walk_active_turfs_batch()
	var/visited = SSair.active_turfs_walk_cursor
	var/amount = SSair.dogmos_walk_chunk_end
	var/cost_ms = TICK_USAGE_TO_MS(start_time)

	SSair.dogmos_replace_active_frontier(saved)
	SSair.active_turfs_walk_cursor = backup
	SSair.dogmos_visual_refresh_batch = previous
	SSair.dogmos_walk_chunk_end = old_value
	SSair.state = old_state
	Master.current_ticklimit = original_tick_limit
	for(var/turf/open/target as anything in pair)
		var/list/cached = values[target]
		target.excited = cached[1]
		target.excited_group = cached[2]
		target.current_cycle = cached[3]
		target.archived_cycle = cached[4]

	// Shared CI runner speed and native-call overhead are observations, not a work-bound contract.
	log_test("Active-turf bloat walk: [visited] visited, [amount] chunked, [cost_ms]ms.")
	TEST_ASSERT(amount > 0 && amount <= ACTIVE_TURFS_BLOAT_TEST_MAX_ENTRIES, \
		"Active-turf maintenance must visit at most [ACTIVE_TURFS_BLOAT_TEST_MAX_ENTRIES] entries, got [amount].")
	TEST_ASSERT(visited >= 0 && visited <= amount, \
		"Active-turf maintenance walked outside its chunked chunk: [visited] visited, [amount] chunked.")
	TEST_ASSERT(processing, "A single bounded maintenance call must leave work pending in the bloated snapshot.")

#undef ACTIVE_TURFS_BLOAT_TEST_MAX_ENTRIES
