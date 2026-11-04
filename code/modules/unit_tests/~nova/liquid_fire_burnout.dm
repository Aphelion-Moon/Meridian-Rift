/// A welding fuel spill must flare up, step down through medium flames and burn out in 45 to 90 seconds, while an oil spill lit with it burns on. A burning pool lights the floor with one light per 2x2 block of burning tiles, and leaves none behind. Tiles that catch again on reused fire holders show their own fire.
/datum/unit_test/liquid_fire_burnout

/datum/unit_test/liquid_fire_burnout/Run()
	var/turf/fuel_turf = run_loc_floor_bottom_left
	var/turf/oil_turf = run_loc_floor_top_right
	fuel_turf.add_liquid(/datum/reagent/fuel, 30, no_react = TRUE)
	oil_turf.add_liquid(/datum/reagent/fuel/oil, 30, no_react = TRUE)
	var/obj/effect/abstract/liquid_turf/fuel = fuel_turf.liquids
	var/obj/effect/abstract/liquid_turf/oil = oil_turf.liquids
	fuel.fire_act(1000, 125)
	oil.fire_act(1000, 125)
	TEST_ASSERT_EQUAL(fuel.fire_state, LIQUID_FIRE_STATE_INFERNO, "30u of welding fuel should ignite straight at the top fire state")
	TEST_ASSERT(oil.fire_state && oil.fire_state < LIQUID_FIRE_STATE_INFERNO, "30u of oil should ignite below an inferno, got fire state [oil.fire_state]")

	var/run_interval = REQUIRED_FIRE_PROCESSES * SSliquids.wait
	var/min_runs = ceil((45 SECONDS) / run_interval)
	var/max_runs = floor((90 SECONDS) / run_interval)
	var/list/seen_states = list()
	var/last_state = fuel.fire_state
	var/runs = 0
	var/expected_medium_flames = "fire_medium_A[fuel.fire_loop_table[(fuel_turf.y % 8) + 1][(fuel_turf.x % 8) + 1]]"
	var/medium_flames
	while(!QDELETED(fuel) && runs < max_runs)
		seen_states |= fuel.fire_state
		if(fuel.fire_state == LIQUID_FIRE_STATE_MEDIUM && isnull(medium_flames))
			medium_flames = fuel.fire_flames?.icon_state
		fuel.process_fire()
		oil.process_fire()
		runs++
		if(QDELETED(fuel))
			break
		TEST_ASSERT(fuel.fire_state <= last_state, "The fuel fire grew from state [last_state] to [fuel.fire_state] on fire run [runs]")
		last_state = fuel.fire_state
	TEST_ASSERT(QDELETED(fuel) && isnull(fuel_turf.liquids), "30u of welding fuel should burn away within [max_runs] fire runs")
	TEST_ASSERT(runs >= min_runs, "30u of welding fuel burnt away in [runs] fire runs, short of the [min_runs] that 45 seconds takes")
	TEST_ASSERT(length(seen_states) >= 3, "The fuel fire should step down through at least 3 fire states, saw [jointext(seen_states, ", ")]")
	TEST_ASSERT(LIQUID_FIRE_STATE_MEDIUM in seen_states, "The fuel fire should pass through the medium fire state, saw [jointext(seen_states, ", ")]")
	TEST_ASSERT_EQUAL(medium_flames, expected_medium_flames, "Medium fuel flames should show their tier and the loop the pick table gives their tile")
	TEST_ASSERT(!QDELETED(oil) && oil.fire_state, "30u of oil should still burn after the [runs] fire runs that burnt away the fuel")
	qdel(oil, TRUE)

	// A 4x4 pool of four whole blocks, so every block has the other three around it.
	var/turf/first_block = SSliquids.get_fire_block(fuel_turf)
	var/start_x = first_block.x < fuel_turf.x ? first_block.x + 2 : first_block.x
	var/start_y = first_block.y < fuel_turf.y ? first_block.y + 2 : first_block.y
	var/list/pool = list()
	for(var/turf/tile as anything in block(start_x, start_y, fuel_turf.z, start_x + 3, start_y + 3, fuel_turf.z))
		tile.add_liquid(/datum/reagent/fuel, 30, no_react = TRUE)
		pool += tile.liquids
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in pool)
		liquid.fire_act(1000, 125)
	SSliquids.update_fire_lights()
	var/list/hosts = get_fire_hosts(pool)
	TEST_ASSERT_EQUAL(length(hosts), 4, "A burning pool of four whole blocks should hold one light per block")
	var/list/lit_blocks = list()
	var/whole_power = LIQUID_FIRE_BLOCK_POWER * LIQUID_FIRE_BLOCK_POWER_BIG / (1 + LIQUID_FIRE_BLOCK_SHARE * 3)
	for(var/obj/effect/abstract/liquid_turf/host as anything in hosts)
		var/turf/host_block = SSliquids.get_fire_block(host.loc)
		lit_blocks |= host_block
		var/list/position = get_light_position(host)
		TEST_ASSERT(abs(position[1] - (host_block.x + 0.5)) < 0.001 && abs(position[2] - (host_block.y + 0.5)) < 0.001, "A whole block's light should sit at its centre ([host_block.x + 0.5], [host_block.y + 0.5]), not at ([position[1]], [position[2]])")
		TEST_ASSERT(host.light_range == LIQUID_FIRE_BLOCK_RANGE_BIG && abs(host.light_power - whole_power) < 0.001, "A big block with three burning blocks around it should light at range [LIQUID_FIRE_BLOCK_RANGE_BIG] and power [whole_power], not [host.light_range] and [host.light_power]")
	TEST_ASSERT_EQUAL(length(lit_blocks), 4, "No block should hold two lights")

	// Its host goes out: before any pass, the light moves to the centre of the block's three burning tiles.
	var/obj/effect/abstract/liquid_turf/old_host = hosts[1]
	var/turf/dark_block = SSliquids.get_fire_block(old_host.loc)
	old_host.extinguish()
	TEST_ASSERT_NULL(old_host.light, "A liquid that stops burning should give up its block's light")
	var/list/block_burning = SSliquids.get_fire_block_burning(dark_block)
	var/centre_x = 0
	var/centre_y = 0
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in block_burning)
		centre_x += liquid.x / length(block_burning)
		centre_y += liquid.y / length(block_burning)
	var/obj/effect/abstract/liquid_turf/new_host
	hosts = get_fire_hosts(pool)
	for(var/obj/effect/abstract/liquid_turf/host as anything in hosts)
		if(SSliquids.get_fire_block(host.loc) == dark_block)
			new_host = host
	TEST_ASSERT(new_host in block_burning, "A block whose host goes out should hand its light to another of its burning tiles at once, not wait for the light pass")
	TEST_ASSERT(length(hosts) == 4 && length(get_lit_blocks(hosts)) == 4, "Handing a light over should leave one light per block, got [length(hosts)] lights on [length(get_lit_blocks(hosts))] blocks")
	var/list/moved_position = get_light_position(new_host)
	TEST_ASSERT(abs(moved_position[1] - centre_x) < 0.001 && abs(moved_position[2] - centre_y) < 0.001, "A block's light should sit at the centre ([centre_x], [centre_y]) of its burning tiles, not at ([moved_position[1]], [moved_position[2]])")
	SSliquids.update_fire_lights()
	hosts = get_fire_hosts(pool)
	TEST_ASSERT(length(hosts) == 4 && length(get_lit_blocks(hosts)) == 4, "The light pass after a hand-over should leave one light per block, got [length(hosts)] lights on [length(get_lit_blocks(hosts))] blocks")

	// The whole block goes out: the three blocks around it each lose a burning neighbour.
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in block_burning)
		liquid.extinguish()
	SSliquids.update_fire_lights()
	hosts = get_fire_hosts(pool)
	TEST_ASSERT_EQUAL(length(hosts), 3, "A block with nothing burning should hold no light")
	var/raised_power = LIQUID_FIRE_BLOCK_POWER * LIQUID_FIRE_BLOCK_POWER_BIG / (1 + LIQUID_FIRE_BLOCK_SHARE * 2)
	for(var/obj/effect/abstract/liquid_turf/host as anything in hosts)
		TEST_ASSERT(abs(host.light_power - raised_power) < 0.001, "A big block with two burning blocks around it should light at power [raised_power], not [host.light_power]")

	// The block catches again a tick after it went out, smoothed into the pool, on the holders it gave back.
	var/list/pooled_flames = SSliquids.fire_flame_pool.Copy()
	// Pools hold back the holders released this tick.
	for(var/obj/effect/abstract/liquid_fire/holder as anything in pooled_flames + SSliquids.fire_glow_pool)
		holder.released_at -= world.tick_lag
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in pool)
		liquid.smooth_icon()
	// Pooled holders keep their last mask, so stamp a lone tile's flame-0 on each: every catch below must replace or drop it.
	for(var/obj/effect/abstract/liquid_fire/holder as anything in pooled_flames)
		holder.filters = old_host.get_alpha_filter('modular_nova/modules/liquids/icons/obj/effects/liquid_masks.dmi', "flame-0")
	var/list/recaught = block_burning + old_host
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in recaught)
		liquid.fire_act(1000, 125)
	// A filter reads its mask back as a resource, not the cached /icon, so the expected mask goes through a probe too.
	var/obj/effect/abstract/liquid_fire/mask_probe = allocate(/obj/effect/abstract/liquid_fire)
	// A whole block of a 4x4 pool holds one tile inside the pool and three on its edge.
	var/interior_tiles = 0
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in recaught)
		var/obj/effect/abstract/liquid_fire/flames = liquid.fire_flames
		var/junction = liquid.smoothing_junction || NONE
		TEST_ASSERT(flames in pooled_flames, "A tile catching a tick after its block went out should reuse a pooled flames holder")
		TEST_ASSERT(junction, "A tile inside a pool should smooth to a junction, or its reused holder's old flame-0 mask would pass for its own")
		TEST_ASSERT_EQUAL(flames.icon_state, "fire_[liquid.get_fire_tier()]_A[liquid.fire_loop_table[(liquid.y % 8) + 1][(liquid.x % 8) + 1]]", "A reused flames holder should show its new tile's tier and loop")
		if(junction == ALL_SMOOTHING_JUNCTIONS)
			interior_tiles++
			TEST_ASSERT(!length(flames.filters), "A reused flames holder inside the pool should drop its old mask, since flame-[junction] is fully opaque")
		else
			mask_probe.filters = liquid.get_alpha_filter('modular_nova/modules/liquids/icons/obj/effects/liquid_masks.dmi', "flame-[junction]")
			TEST_ASSERT_EQUAL(get_mask_ref(flames), get_mask_ref(mask_probe), "A reused flames holder on the pool's edge should be clipped by its new tile's flame-[junction] mask")
		TEST_ASSERT_EQUAL(flames.plane, MUTATE_PLANE(GAME_PLANE, liquid), "A reused flames holder should sit on its new tile's game plane")
	TEST_ASSERT(interior_tiles, "The block that caught again should hold a tile inside the pool, or no reused holder is checked for dropping its mask")

	// Then the pool burns out and leaves no light behind.
	var/list/seen_lights = list()
	var/burn_runs = 0
	var/burning = TRUE
	while(burning && burn_runs < max_runs)
		for(var/obj/effect/abstract/liquid_turf/host as anything in get_fire_hosts(pool))
			seen_lights |= host.light
		burning = FALSE
		for(var/obj/effect/abstract/liquid_turf/liquid as anything in pool)
			if(!QDELETED(liquid))
				liquid.process_fire()
				burning = TRUE
		SSliquids.update_fire_lights()
		burn_runs++
	TEST_ASSERT(!burning, "The pool should burn away within [max_runs] fire runs")
	for(var/datum/light_source/fire_light as anything in seen_lights)
		TEST_ASSERT(QDELETED(fire_light), "A burnt-out pool should leave no fire light behind")
	for(var/turf/pool_block as anything in lit_blocks)
		TEST_ASSERT_NULL(SSliquids.fire_block_lights[pool_block], "A burnt-out block should hold no light")

/// Returns the pool's liquids that hold a light.
/datum/unit_test/liquid_fire_burnout/proc/get_fire_hosts(list/pool)
	. = list()
	for(var/obj/effect/abstract/liquid_turf/liquid as anything in pool)
		if(!QDELETED(liquid) && liquid.light)
			. += liquid

/// Returns the distinct fire light blocks the hosts sit on.
/datum/unit_test/liquid_fire_burnout/proc/get_lit_blocks(list/hosts)
	. = list()
	for(var/obj/effect/abstract/liquid_turf/host as anything in hosts)
		. |= SSliquids.get_fire_block(host.loc)

/// Returns where a liquid's light sits, as list(x, y) in world tiles, from the offset its light source reads.
/datum/unit_test/liquid_fire_burnout/proc/get_light_position(atom/host)
	var/list/offset = calculate_light_offset(host)
	return list(host.x - offset[1], host.y - offset[2])

/// Returns the ref of the mask an atom's only filter clips by, or null when it has no filter or several.
/datum/unit_test/liquid_fire_burnout/proc/get_mask_ref(atom/masked)
	if(length(masked.filters) != 1)
		return null
	var/dm_filter/mask_filter = masked.filters[1]
	return "\ref[mask_filter:icon]"

/datum/unit_test/liquid_fire_burnout/Destroy()
	// The test room's cleanup qdels without force, which liquids ignore.
	for(var/turf/spilled_turf as anything in block(run_loc_floor_bottom_left, run_loc_floor_top_right))
		if(spilled_turf.liquids)
			qdel(spilled_turf.liquids, TRUE)
	return ..()
