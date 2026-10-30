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
	/// Turfs the fire run in progress still has to burn. A big fire's run spans several ticks.
	var/list/currentrun_fire = list()

	/// Burning 2x2 blocks: each block's bottom-left turf to the burning liquid holding the block's light.
	var/list/fire_block_lights = list()
	/// Blocks whose fire changed since the last light pass, as bottom-left turfs.
	var/list/dirty_fire_blocks = list()
	/// TRUE while the fire run burns tiles in this tick. Hosts going out then hand their lights over when the run stops for the tick.
	var/in_fire_run = FALSE
	/// Blocks whose light host went out while the fire run burnt tiles in this tick.
	var/list/fire_run_handovers = list()
	/// Dirty blocks the light pass in progress has yet to check for a start or stop of burning.
	var/list/currentrun_dirty_fire_blocks = list()
	/// Blocks the light pass in progress has yet to light.
	var/list/currentrun_fire_blocks = list()
	/// Blocks that burnt when a light pass last checked them. A block's neighbours relight only when it starts or stops burning.
	var/list/burning_fire_blocks = list()
	/// Flames holders of tiles that stopped burning, for the next tiles that catch.
	var/list/fire_flame_pool = list()
	/// Emissive copies of the flames, kept the same way.
	var/list/fire_glow_pool = list()
	/// Smoke holders, kept the same way.
	var/list/fire_smoke_pool = list()

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
	// Only burn_fire_run() sets it, for the tiles it burns; a runtime there must not leave it set.
	in_fire_run = FALSE
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
		// A resumed fire carries on the run it stopped, without counting towards the next one.
		if(!resumed)
			fire_counter++
			if(fire_counter >= REQUIRED_FIRE_PROCESSES)
				fire_counter = 0
				currentrun_fire = processing_fire.Copy()
		if(length(currentrun_fire) && !burn_fire_run())
			return
		resumed = FALSE
		run_type = SSLIQUIDS_RUN_TYPE_FIRE_LIGHTS

	if(run_type == SSLIQUIDS_RUN_TYPE_FIRE_LIGHTS)
		// Tick checked: a pass that runs out of tick carries on next fire.
		if(!update_fire_lights(TRUE))
			return
		run_type = SSLIQUIDS_RUN_TYPE_TURFS

/**
 * Burns the fire run's tiles, as many as the tick allows.
 *
 * Hosts going out meanwhile hand their block lights over once per block: here when the run stops for the tick, in the
 * light pass right after the run when it ends.
 *
 * Returns:
 * - TRUE: The run is done.
 * - FALSE: It stopped for the tick and carries on next fire.
 */
/datum/controller/subsystem/liquids/proc/burn_fire_run()
	PRIVATE_PROC(TRUE)

	var/list/currentrun_fire = src.currentrun_fire
	in_fire_run = TRUE
	while(length(currentrun_fire))
		var/turf/tile = currentrun_fire[length(currentrun_fire)]
		currentrun_fire.len--
		// A tile that went out or lost its liquid since the run began has left processing_fire.
		if(processing_fire[tile])
			tile.liquids.process_fire()
		if(MC_TICK_CHECK)
			in_fire_run = FALSE
			// No block that still burns waits in the dark for the next tick.
			hand_over_fire_lights(list())
			return FALSE
	in_fire_run = FALSE
	return TRUE

/**
 * Gives each block whose light host went out during the fire run a new host, from what burns on it now.
 *
 * Arguments:
 * - burning_by_block: The get_fire_block_burning() results to reuse and add to.
 *
 * Returns the blocks it worked out, as an assoc list.
 */
/datum/controller/subsystem/liquids/proc/hand_over_fire_lights(list/burning_by_block)
	. = fire_run_handovers
	fire_run_handovers = list()
	for(var/turf/block as anything in .)
		update_fire_block(block, burning_by_block)

/datum/controller/subsystem/liquids/Recover()
	active_turfs = SSliquids.active_turfs
	currentrun_active_turfs = SSliquids.currentrun_active_turfs
	active_groups = SSliquids.active_groups
	active_immutables = SSliquids.active_immutables
	evaporation_queue = SSliquids.evaporation_queue
	evaporation_counter = SSliquids.evaporation_counter
	processing_fire = SSliquids.processing_fire
	fire_counter = SSliquids.fire_counter
	singleton_immutables = SSliquids.singleton_immutables
	run_type = SSliquids.run_type
	currentrun_fire = SSliquids.currentrun_fire
	fire_block_lights = SSliquids.fire_block_lights
	dirty_fire_blocks = SSliquids.dirty_fire_blocks
	fire_run_handovers = SSliquids.fire_run_handovers
	currentrun_dirty_fire_blocks = SSliquids.currentrun_dirty_fire_blocks
	currentrun_fire_blocks = SSliquids.currentrun_fire_blocks
	burning_fire_blocks = SSliquids.burning_fire_blocks
	fire_flame_pool = SSliquids.fire_flame_pool
	fire_glow_pool = SSliquids.fire_glow_pool
	fire_smoke_pool = SSliquids.fire_smoke_pool
	// in_fire_run stays FALSE: the new subsystem is not inside a fire run.

/**
 * Returns a fire holder from a pool, or a new one when the pool has none released before this tick. The caller sets
 * everything a holder shows.
 *
 * A holder released this tick is never handed out: until the tick ends, a client can draw its new look at its old tile.
 * Pools are in release order, so only the newest and the oldest need checking.
 *
 * Arguments:
 * - pool: fire_flame_pool, fire_glow_pool or fire_smoke_pool.
 */
/datum/controller/subsystem/liquids/proc/take_fire_holder(list/pool)
	RETURN_TYPE(/obj/effect/abstract/liquid_fire)
	var/count = length(pool)
	if(count)
		var/obj/effect/abstract/liquid_fire/holder = pool[count]
		if(holder.released_at != world.time)
			pool.len--
			return holder
		holder = pool[1]
		if(holder.released_at != world.time)
			pool.Cut(1, 2)
			return holder
	return new /obj/effect/abstract/liquid_fire(null)

/**
 * Keeps a fire holder that left its tile for reuse, stamped with the time it left, or deletes it when its pool is full.
 *
 * Arguments:
 * - holder: The holder, already out of its liquid's vis_contents.
 * - pool: The pool of its kind.
 */
/datum/controller/subsystem/liquids/proc/keep_fire_holder(obj/effect/abstract/liquid_fire/holder, list/pool)
	if(length(pool) >= LIQUID_FIRE_HOLDER_POOL_SIZE)
		qdel(holder)
		return
	holder.released_at = world.time
	pool += holder

/**
 * Returns the bottom-left turf of the 2x2 fire light block holding a turf.
 *
 * Blocks are world-aligned per z and start on odd x and y (1-2, 3-4, ...), so a block's bottom-left turf always exists.
 *
 * Arguments:
 * - tile: Any turf.
 */
/datum/controller/subsystem/liquids/proc/get_fire_block(turf/tile)
	RETURN_TYPE(/turf)
	return locate(tile.x - !(tile.x % 2), tile.y - !(tile.y % 2), tile.z)

/// Queues the fire light block holding a turf for the next light pass.
/datum/controller/subsystem/liquids/proc/mark_fire_block(turf/tile)
	dirty_fire_blocks[get_fire_block(tile)] = TRUE

/**
 * Takes the block light off a liquid, if it holds one, hands it to another burning tile of the block, and queues the
 * block so the next light pass updates its neighbours.
 *
 * Call it when a burning liquid stops burning, leaves its turf or is deleted, and only once the block scan can no longer
 * see it there: after its fire_state is NONE, or after its turf's liquids is cleared. Inside the fire run the hand-over
 * waits until the run stops for the tick, so a pool burning out at once is relit one block at a time, not once per tile.
 *
 * Arguments:
 * - liquid: A liquid on a turf.
 */
/datum/controller/subsystem/liquids/proc/release_fire_light(obj/effect/abstract/liquid_turf/liquid)
	var/turf/block = get_fire_block(liquid.my_turf)
	dirty_fire_blocks[block] = TRUE
	if(fire_block_lights[block] != liquid)
		return
	fire_block_lights -= block
	liquid.set_light(0)
	if(in_fire_run)
		fire_run_handovers[block] = TRUE
	else
		update_fire_block(block, list())

/**
 * Relights the fire light blocks queued since the last pass, and the 8 neighbours of each that started or stopped
 * burning, whose power depends on how many blocks around them burn. Blocks whose host went out in the fire run get
 * their new host first.
 *
 * Every block is worked out at most once per call, from what burns on it now, however often its tiles changed. So a pass
 * does at most nine blocks of work per queued block, and blocks queued while it runs wait for the next pass.
 *
 * Arguments:
 * - tick_checked: TRUE in fire(), where the pass stops when the tick runs out and carries on next fire. FALSE runs a
 *   stopped pass and everything queued to the end now.
 *
 * Returns:
 * - TRUE: The pass is done.
 * - FALSE: It stopped for the tick.
 */
/datum/controller/subsystem/liquids/proc/update_fire_lights(tick_checked = FALSE)
	var/list/pass_dirty = currentrun_dirty_fire_blocks
	var/list/pass_blocks = currentrun_fire_blocks
	// A new pass takes the queue; outside fire() the queue joins any pass that stopped for the tick.
	if(!tick_checked || !(length(pass_dirty) || length(pass_blocks)))
		if(length(pass_dirty))
			for(var/turf/dirty_block as anything in dirty_fire_blocks)
				pass_dirty[dirty_block] = TRUE
		else
			pass_dirty = dirty_fire_blocks
			currentrun_dirty_fire_blocks = pass_dirty
		dirty_fire_blocks = list()
	// Scans are reused only within one tick: fire states can change between ticks.
	var/list/burning_by_block = list()
	// The fire run's hand-overs come first, before the pass can stop for the tick. This tick needs no second look at them.
	var/list/handed_over = hand_over_fire_lights(burning_by_block)
	while(length(pass_dirty))
		var/turf/dirty_block = pass_dirty[length(pass_dirty)]
		pass_dirty.len--
		if(!handed_over[dirty_block])
			pass_blocks[dirty_block] = TRUE
		var/burning = length(get_fire_block_burning(dirty_block, burning_by_block)) > 0
		if(burning != !!burning_fire_blocks[dirty_block])
			if(burning)
				burning_fire_blocks[dirty_block] = TRUE
			else
				burning_fire_blocks -= dirty_block
			for(var/column in -1 to 1)
				for(var/row in -1 to 1)
					var/turf/neighbour = locate(dirty_block.x + column * 2, dirty_block.y + row * 2, dirty_block.z)
					if(neighbour && !handed_over[neighbour])
						pass_blocks[neighbour] = TRUE
		if(tick_checked && MC_TICK_CHECK)
			return FALSE
	while(length(pass_blocks))
		var/turf/block = pass_blocks[length(pass_blocks)]
		pass_blocks.len--
		update_fire_block(block, burning_by_block)
		if(tick_checked && MC_TICK_CHECK)
			break
	return !length(pass_blocks)

/**
 * Gives a fire light block one light, on the burning liquid nearest the centre of its burning tiles, or no light when
 * nothing on it burns.
 *
 * The light sits at that centre. Its range and power follow the block's largest flames, and its power is shared out
 * with every burning block around it.
 *
 * Arguments:
 * - block: The block's bottom-left turf.
 * - burning_by_block: The pass's get_fire_block_burning() results so far, filled in as blocks are read.
 */
/datum/controller/subsystem/liquids/proc/update_fire_block(turf/block, list/burning_by_block)
	var/list/burning = get_fire_block_burning(block, burning_by_block)
	var/obj/effect/abstract/liquid_turf/old_host = fire_block_lights[block]
	if(!length(burning))
		if(old_host)
			fire_block_lights -= block
			old_host.set_light(0)
		return
	var/obj/effect/abstract/liquid_turf/fiercest = burning[1]
	var/centre_x = 0
	var/centre_y = 0
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in burning)
		centre_x += liquid.x
		centre_y += liquid.y
		if(liquid.fire_state > fiercest.fire_state)
			fiercest = liquid
	centre_x /= length(burning)
	centre_y /= length(burning)

	// The host keeps the light unless a tile sits nearer the centre, so the light doesn't hop between equal tiles.
	var/obj/effect/abstract/liquid_turf/host = (old_host in burning) ? old_host : null
	var/host_distance = host ? (host.x - centre_x) ** 2 + (host.y - centre_y) ** 2 : INFINITY
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in burning)
		var/distance = (liquid.x - centre_x) ** 2 + (liquid.y - centre_y) ** 2
		if(distance < host_distance - 0.01)
			host = liquid
			host_distance = distance
	if(host != old_host)
		old_host?.set_light(0)
		fire_block_lights[block] = host

	var/neighbours = 0
	for(var/column in -1 to 1)
		for(var/row in -1 to 1)
			if(!(column || row))
				continue
			var/turf/neighbour = locate(block.x + column * 2, block.y + row * 2, block.z)
			if(!neighbour)
				continue
			// A scan this pass already made is read straight from the memo.
			var/list/neighbour_burning = burning_by_block[neighbour] || get_fire_block_burning(neighbour, burning_by_block)
			if(length(neighbour_burning))
				neighbours++
	var/range = LIQUID_FIRE_BLOCK_RANGE_SMALL
	var/power_share = LIQUID_FIRE_BLOCK_POWER_SMALL
	switch(fiercest.get_fire_tier())
		if("big")
			range = LIQUID_FIRE_BLOCK_RANGE_BIG
			power_share = LIQUID_FIRE_BLOCK_POWER_BIG
		if("medium")
			range = LIQUID_FIRE_BLOCK_RANGE_MEDIUM
			power_share = LIQUID_FIRE_BLOCK_POWER_MEDIUM
	var/power = LIQUID_FIRE_BLOCK_POWER * power_share / (1 + LIQUID_FIRE_BLOCK_SHARE * neighbours)
	host.set_fire_light(range, power, centre_x - host.x, centre_y - host.y)

/**
 * Returns the burning liquids on a fire light block's tiles.
 *
 * Arguments:
 * - block: The block's bottom-left turf. Null, for a block off the map, has none.
 * - burning_by_block: Earlier results to reuse and add to, by block. Only valid while no fire state changes.
 */
/datum/controller/subsystem/liquids/proc/get_fire_block_burning(turf/block, list/burning_by_block = list())
	RETURN_TYPE(/list)
	if(!block)
		return list()
	. = burning_by_block[block]
	if(.)
		return
	. = list()
	for(var/column in 0 to 1)
		for(var/row in 0 to 1)
			var/turf/tile = locate(block.x + column, block.y + row, block.z)
			var/obj/effect/abstract/liquid_turf/liquid = tile?.liquids
			if(liquid?.fire_state && !liquid.immutable)
				. += liquid
	burning_by_block[block] = .

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
