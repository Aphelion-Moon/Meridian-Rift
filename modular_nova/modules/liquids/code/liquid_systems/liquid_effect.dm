#define LIQUID_SURFACES_DMI 'modular_nova/modules/liquids/icons/obj/effects/liquid_surfaces.dmi'
#define LIQUID_FIRE_DMI 'modular_nova/modules/liquids/icons/obj/effects/liquid_fire.dmi'
#define LIQUID_MASKS_DMI 'modular_nova/modules/liquids/icons/obj/effects/liquid_masks.dmi'

/obj/effect/abstract/liquid_turf
	name = "liquid"
	icon = 'modular_nova/modules/liquids/icons/obj/effects/liquid.dmi'
	icon_state = "water-0"
	base_icon_state = "water"
	anchored = TRUE
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	appearance_flags = TILE_BOUND
	// No compile-time color: init would make it an atom colour, and that adds KEEP_TOGETHER, which tints the surface overlays.

	//For being on fire
	light_range = 0
	light_power = 1
	light_color = LIGHT_COLOR_FIRE

	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WATER
	canSmoothWith = SMOOTH_GROUP_WATER + SMOOTH_GROUP_WINDOW_FULLTILE + SMOOTH_GROUP_WALLS

	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	var/height = 1
	var/only_big_diffs = 1
	var/turf/my_turf
	var/liquid_state = LIQUID_STATE_PUDDLE
	var/has_cached_share = FALSE

	var/attrition = 0

	var/immutable = FALSE

	var/list/reagent_list = list()
	var/total_reagents = 0
	/// Volume-weighted liquid_opacity of reagent_list, from 0 (clear) to 1 (opaque).
	var/reagent_opacity = 0
	/// Colour of the blood in reagent_list, blended by blood volume as blood comes in. Null when no blood is tracked.
	var/blood_color
	/// The LIQUID_SURFACE_* look this pool draws, from get_liquid_surface().
	var/surface_class = LIQUID_SURFACE_CLEAR
	/// The marks this pool draws over its surface ("grit", "chunks" or "bumps"), or null.
	var/surface_detail
	var/temp = T20C

	var/fire_state = LIQUID_FIRE_STATE_NONE
	/// How far east of this tile the light it holds for its fire light block sits, in tiles.
	var/fire_light_x = 0
	/// How far north of this tile the light it holds for its fire light block sits, in tiles.
	var/fire_light_y = 0
	/// The flames while this tile burns, in vis_contents.
	var/obj/effect/abstract/liquid_fire/fire_flames
	/// The flames' emissive copy, in vis_contents. It always shows the flames' icon_state.
	var/obj/effect/abstract/liquid_fire/fire_glow
	/// Smoke over the flames, in vis_contents from the end of the ignite.
	var/obj/effect/abstract/liquid_fire/fire_smoke
	/// The fire loop (1 to 5) per world tile, read as [(y % 8) + 1][(x % 8) + 1], so neighbours burn out of step.
	var/static/list/fire_loop_table = list(
		list(2, 1, 5, 2, 4, 3, 5, 1),
		list(3, 4, 3, 1, 5, 1, 2, 4),
		list(1, 5, 2, 4, 2, 4, 3, 5),
		list(4, 3, 1, 5, 3, 5, 1, 2),
		list(5, 2, 4, 2, 1, 2, 4, 3),
		list(4, 3, 1, 3, 5, 3, 1, 2),
		list(1, 2, 5, 4, 2, 4, 5, 3),
		list(5, 4, 3, 1, 5, 1, 2, 4),
	)

	var/no_effects = FALSE

	/// State-specific message chunks for examine_turf()
	var/static/list/liquid_state_messages = list(
		"[LIQUID_STATE_PUDDLE]" = "a puddle of $",
		"[LIQUID_STATE_ANKLES]" = "$ going [span_warning("up to your ankles")]",
		"[LIQUID_STATE_WAIST]" = "$ going [span_warning("up to your waist")]",
		"[LIQUID_STATE_SHOULDERS]" = "$ going [span_warning("up to your shoulders")]",
		"[LIQUID_STATE_FULLTILE]" = "$ going [span_danger("over your head")]",
	)

/obj/effect/abstract/liquid_turf/onShuttleMove(turf/newT, turf/oldT, list/movement_force, move_dir, obj/docking_port/stationary/old_dock, obj/docking_port/mobile/moving_dock)
	return

/**
 * Updates fire_state from this liquid's mix.
 *
 * Arguments:
 * - hotspotted: TRUE when something is igniting us, so a liquid that isn't burning yet can catch.
 *
 * Returns:
 * - TRUE: The liquid is burning.
 * - FALSE: It isn't, and any fire it had is out.
 */
/obj/effect/abstract/liquid_turf/proc/check_fire(hotspotted = FALSE)
	var/new_state = get_fire_state(hotspotted)
	if(fire_state != new_state)
		set_fire_state(new_state)
	return new_state != LIQUID_FIRE_STATE_NONE

/// Sets the fire state and its flames, and queues the tile's fire light block, which SSliquids lights.
/obj/effect/abstract/liquid_turf/proc/set_fire_state(new_state)
	fire_state = new_state
	if(my_turf)
		if(fire_state)
			SSliquids.mark_fire_block(my_turf)
		else
			SSliquids.release_fire_light(src)
	update_fire_visuals()

/// Returns the fire art's tier for fire_state: "small", "medium" or "big", or null while the liquid isn't burning.
/obj/effect/abstract/liquid_turf/proc/get_fire_tier()
	switch(fire_state)
		if(LIQUID_FIRE_STATE_SMALL, LIQUID_FIRE_STATE_MILD)
			return "small"
		if(LIQUID_FIRE_STATE_MEDIUM)
			return "medium"
		if(LIQUID_FIRE_STATE_HUGE, LIQUID_FIRE_STATE_INFERNO)
			return "big"

/**
 * Sets the light this liquid holds for its fire light block, and refreshes it only when something changed.
 *
 * Arguments:
 * - range: The light's range.
 * - power: The light's power.
 * - light_x: Where the light sits, in tiles east of this tile.
 * - light_y: Where the light sits, in tiles north of this tile.
 */
/obj/effect/abstract/liquid_turf/proc/set_fire_light(range, power, light_x, light_y)
	if(light && light_range == range && light_power == power && fire_light_x == light_x && fire_light_y == light_y)
		return
	fire_light_x = light_x
	fire_light_y = light_y
	// set_light() ends in update_light(), the only call that makes the light read get_light_offset() again.
	set_light(range, power)

/obj/effect/abstract/liquid_turf/get_light_offset()
	// A light sits at minus its offset.
	return list(-fire_light_x, -fire_light_y)

/// Returns this tile's fire loop, 1 to 5, from fire_loop_table.
/obj/effect/abstract/liquid_turf/proc/get_fire_loop()
	var/list/table_row = fire_loop_table[(y % 8) + 1]
	return table_row[(x % 8) + 1]

/**
 * Shows this tile's fire as fire_state asks: lights it, swaps its tier, or puts it out.
 *
 * The flames, their emissive copy and the smoke are holders in vis_contents, so a tier change only swaps their
 * icon_states and never rebuilds the liquid's overlays. Every looping state runs on one clock per client, so a
 * swapped loop keeps time.
 */
/obj/effect/abstract/liquid_turf/proc/update_fire_visuals()
	if(no_effects)
		return
	var/tier = get_fire_tier()
	if(!tier)
		clear_fire_visuals()
		return
	var/loop = get_fire_loop()
	if(!fire_flames)
		ignite_fire_visuals(tier, loop)
		return
	fire_flames.icon_state = "fire_[tier]_A[loop]"
	fire_glow.icon_state = fire_flames.icon_state
	if(fire_smoke)
		fire_smoke.icon_state = "smoke_[tier]_A[loop]"

/**
 * Lights this tile's fire: makes the flames and their emissive copy, plays the ignite once on both, and starts the
 * smoke when the ignite ends.
 *
 * The ignite is a flick, which the server times, so a client that first sees the tile mid-ignite sees the rest of it
 * and then the loop. NEVER show the ignite through icon_state: each client would start it over at first sight.
 *
 * Arguments:
 * - tier: The fire art's tier, from get_fire_tier().
 * - loop: This tile's fire loop, from get_fire_loop().
 */
/obj/effect/abstract/liquid_turf/proc/ignite_fire_visuals(tier, loop)
	PRIVATE_PROC(TRUE)

	var/flame_state = "fire_[tier]_A[loop]"
	// Holders come from SSliquids' pools, so a reused one gets every var a new one is given here.
	fire_flames = SSliquids.take_fire_holder(SSliquids.fire_flame_pool)
	SET_PLANE_EXPLICIT(fire_flames, GAME_PLANE, src)
	fire_flames.icon_state = flame_state
	fire_glow = SSliquids.take_fire_holder(SSliquids.fire_glow_pool)
	// Its layer is the flames', so whatever draws over the flames also blocks their glow.
	fire_glow.appearance = emissive_appearance(LIQUID_FIRE_DMI, flame_state, src, BELOW_MOB_LAYER, appearance_flags = RESET_ALPHA)
	fire_glow.pixel_w = LIQUID_FIRE_PIXEL_OFFSET
	fire_glow.pixel_z = LIQUID_FIRE_PIXEL_OFFSET
	fire_glow.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	set_fire_masks()
	vis_contents += fire_flames
	vis_contents += fire_glow
	var/ignite_state = "ignite_[tier]_A[loop]"
	flick(ignite_state, fire_flames)
	flick(ignite_state, fire_glow)
	addtimer(CALLBACK(src, PROC_REF(start_fire_smoke)), LIQUID_FIRE_IGNITE_TIME, TIMER_UNIQUE | TIMER_OVERRIDE)

/// Adds the smoke over this tile's flames when their ignite ends, so no puff floats over flames still growing.
/obj/effect/abstract/liquid_turf/proc/start_fire_smoke()
	if(!fire_flames || fire_smoke)
		return
	fire_smoke = SSliquids.take_fire_holder(SSliquids.fire_smoke_pool)
	SET_PLANE_EXPLICIT(fire_smoke, GAME_PLANE, src)
	fire_smoke.layer = BELOW_MOB_LAYER + 0.01
	fire_smoke.icon_state = "smoke_[get_fire_tier()]_A[get_fire_loop()]"
	set_smoke_mask(smoothing_junction || NONE)
	vis_contents += fire_smoke

/**
 * Clips this tile's flames and their copy by its junction's "flame-[junction]" mask, and its smoke by "smoke-[junction]".
 *
 * A fully opaque mask leaves them unfiltered (get_clip_filter()), so the fire art must keep the exact-art RULE in the
 * art contract above update_overlays().
 */
/obj/effect/abstract/liquid_turf/proc/set_fire_masks()
	PRIVATE_PROC(TRUE)

	var/junction = smoothing_junction || NONE
	var/flame_mask = get_clip_filter(LIQUID_MASKS_DMI, "flame-[junction]")
	fire_flames.filters = flame_mask
	fire_glow.filters = flame_mask
	if(fire_smoke)
		set_smoke_mask(junction)

/**
 * Clips this tile's smoke by its junction's "smoke-[junction]" mask.
 *
 * Arguments:
 * - junction: This tile's smoothing junction, NONE for a lone puddle.
 */
/obj/effect/abstract/liquid_turf/proc/set_smoke_mask(junction)
	PRIVATE_PROC(TRUE)

	fire_smoke.filters = get_clip_filter(LIQUID_MASKS_DMI, "smoke-[junction]")

/// Takes this tile's fire holders off it and gives them back to SSliquids' pools.
/obj/effect/abstract/liquid_turf/proc/clear_fire_visuals()
	PRIVATE_PROC(TRUE)

	if(fire_flames)
		vis_contents -= fire_flames
		SSliquids.keep_fire_holder(fire_flames, SSliquids.fire_flame_pool)
		fire_flames = null
	if(fire_glow)
		vis_contents -= fire_glow
		SSliquids.keep_fire_holder(fire_glow, SSliquids.fire_glow_pool)
		fire_glow = null
	if(fire_smoke)
		vis_contents -= fire_smoke
		SSliquids.keep_fire_holder(fire_smoke, SSliquids.fire_smoke_pool)
		fire_smoke = null

/**
 * Returns the fire state this liquid's mix supports.
 *
 * A mix burns only while more than REQUIRED_FIRE_FLAMMABLE_SHARE of it is flammable and its power per unit
 * beats REQUIRED_FIRE_POWER_PER_UNIT. Each state above small then needs both its LIQUID_FIRE_POWER_* power
 * per unit and its LIQUID_FIRE_UNITS_* flammable units. Power per unit caps how fierce the mix burns, and the
 * flammable units left shrink the fire as it burns out.
 *
 * Arguments:
 * - hotspotted: TRUE when something is igniting us. Without it, a liquid that isn't burning stays out.
 *
 * Returns:
 * - A LIQUID_FIRE_STATE_* define, LIQUID_FIRE_STATE_NONE when the liquid won't burn.
 */
/obj/effect/abstract/liquid_turf/proc/get_fire_state(hotspotted = FALSE)
	if(!hotspotted && !fire_state)
		return LIQUID_FIRE_STATE_NONE
	var/total_burn_power = 0
	var/flammable_units = 0
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		var/burn_power = initial(reagent_path.liquid_fire_power)
		if(burn_power)
			total_burn_power += burn_power * volume
			flammable_units += volume
	if(flammable_units <= total_reagents * REQUIRED_FIRE_FLAMMABLE_SHARE)
		return LIQUID_FIRE_STATE_NONE
	var/power_per_unit = total_burn_power / total_reagents
	if(power_per_unit <= REQUIRED_FIRE_POWER_PER_UNIT)
		return LIQUID_FIRE_STATE_NONE
	if(power_per_unit >= LIQUID_FIRE_POWER_INFERNO && flammable_units >= LIQUID_FIRE_UNITS_INFERNO)
		return LIQUID_FIRE_STATE_INFERNO
	if(power_per_unit >= LIQUID_FIRE_POWER_HUGE && flammable_units >= LIQUID_FIRE_UNITS_HUGE)
		return LIQUID_FIRE_STATE_HUGE
	if(power_per_unit >= LIQUID_FIRE_POWER_MEDIUM && flammable_units >= LIQUID_FIRE_UNITS_MEDIUM)
		return LIQUID_FIRE_STATE_MEDIUM
	if(power_per_unit >= LIQUID_FIRE_POWER_MILD && flammable_units >= LIQUID_FIRE_UNITS_MILD)
		return LIQUID_FIRE_STATE_MILD
	return LIQUID_FIRE_STATE_SMALL

/// Returns the temperature this liquid's fire exposes its tile and everything on it to.
/obj/effect/abstract/liquid_turf/proc/get_fire_temperature()
	switch(fire_state)
		if(LIQUID_FIRE_STATE_HUGE)
			return LIQUID_FIRE_TEMPERATURE_HUGE
		if(LIQUID_FIRE_STATE_INFERNO)
			return LIQUID_FIRE_TEMPERATURE_INFERNO
	return (T20C + 50) + (50 * fire_state)

/obj/effect/abstract/liquid_turf/extinguish()
	. = ..()
	if(fire_state)
		set_fire_state(LIQUID_FIRE_STATE_NONE)

/**
 * Runs one fire run on this tile: spreads the fire, burns its fuel and heats the tile.
 *
 * Each flammable reagent uses up its liquid_fire_burnrate, then the fire state follows what's left.
 * So the fire steps down as it burns out, and leaves processing once it's out.
 */
/obj/effect/abstract/liquid_turf/proc/process_fire()
	if(!fire_state || !check_fire())
		SSliquids.processing_fire -= my_turf
		return
	//Try spreading
	for(var/turf/adjacent_turf in my_turf.atmos_adjacent_turfs)
		if(adjacent_turf.liquids && !adjacent_turf.liquids.fire_state && adjacent_turf.liquids.check_fire(TRUE))
			SSliquids.processing_fire[adjacent_turf] = TRUE
	//Burn our resources
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		if(!initial(reagent_path.liquid_fire_power))
			continue
		var/burn_rate = initial(reagent_path.liquid_fire_burnrate)
		if(burn_rate >= volume)
			reagent_list -= reagent_type
			total_reagents -= volume
		else
			reagent_list[reagent_type] -= burn_rate
			total_reagents -= burn_rate

	var/fire_temperature = get_fire_temperature()
	my_turf.hotspot_expose(fire_temperature, 125)
	for(var/atom/content in my_turf.contents)
		if(!QDELETED(content))
			content.fire_act(fire_temperature, 125)

	if(reagent_list.len == 0)
		qdel(src, TRUE)
		return
	has_cached_share = FALSE
	if(my_turf.lgroup)
		// The burn changed our mix, so the group reshares and remixes its colour.
		my_turf.lgroup.dirty = TRUE
		my_turf.lgroup.invalidate_cached_mix()
	else
		update_from_reagents()
	// Step down now, so the smallest flames still show before the fuel is gone.
	if(!check_fire())
		SSliquids.processing_fire -= my_turf

/obj/effect/abstract/liquid_turf/proc/process_evaporation()
	if(immutable)
		SSliquids.evaporation_queue -= my_turf
		return
	//We're in a group. dont try and evaporate
	if(my_turf.lgroup)
		SSliquids.evaporation_queue -= my_turf
		return
	if(liquid_state != LIQUID_STATE_PUDDLE)
		SSliquids.evaporation_queue -= my_turf
		return
	//See if any of our reagents evaporates
	var/any_change = FALSE
	var/datum/reagent/R //Faster declaration
	for(var/reagent_type in reagent_list)
		R = reagent_type
		//We evaporate. bye bye
		if(initial(R.evaporates))
			total_reagents -= reagent_list[reagent_type]
			reagent_list -= reagent_type
			any_change = TRUE
	if(!any_change)
		SSliquids.evaporation_queue -= my_turf
		return
	//No total reagents. Commit death
	if(reagent_list.len == 0)
		qdel(src, TRUE)
	//Reagents still left. Recalculte height and color and remove us from the queue
	else
		has_cached_share = FALSE
		SSliquids.evaporation_queue -= my_turf
		update_from_reagents()

/obj/effect/abstract/liquid_turf/forceMove(atom/destination, no_tp=FALSE, harderforce = FALSE)
	if(harderforce)
		. = ..()

/**
 * Makes and returns the liquid effect overlay.
 *
 * Arguments:
 * * overlay_state - the icon state of the new overlay
 * * overlay_layer - the layer
 * * overlay_plane - the plane
 */
/obj/effect/abstract/liquid_turf/proc/make_liquid_overlay(overlay_state, overlay_layer, overlay_plane)
	PRIVATE_PROC(TRUE)

	return mutable_appearance(
		'modular_nova/modules/liquids/icons/obj/effects/liquid_overlays.dmi',
		overlay_state,
		overlay_layer,
		src,
		overlay_plane,
	)

/**
 * Returns a list of over and underlays for different liquid states.
 *
 * Arguments:
 * * state - the stage number.
 * * has_top - if this stage has a top.
 */
/obj/effect/abstract/liquid_turf/proc/make_state_layer(state, has_top)
	PRIVATE_PROC(TRUE)

	. = list(make_liquid_overlay("stage[state]_bottom", ABOVE_MOB_LAYER, GAME_PLANE))

	if(has_top)
		. += make_liquid_overlay("stage[state]_top", TABLE_LAYER + 0.05, GAME_PLANE)

	// Immutables don't scale their colour.
	if(immutable)
		return
	// The bands draw in the mix itself: a matrix (a colour string can't go past 1) undoes the class factor color carries.
	var/inverse = 1 / get_liquid_color_factor(surface_class)
	for(var/mutable_appearance/band as anything in .)
		band.color = list(inverse, 0, 0, 0, inverse, 0, 0, 0, inverse)

/**
 * Sets the pool's LIQUID_STATE_* depth.
 *
 * Arguments:
 * - new_state: The new depth.
 * - redraw: FALSE leaves the overlays for the caller to redraw.
 */
/obj/effect/abstract/liquid_turf/proc/set_new_liquid_state(new_state, redraw = TRUE)
	liquid_state = new_state
	if(!isnull(my_turf))
		my_turf.liquids_change(new_state)
	if(redraw)
		update_icon(UPDATE_OVERLAYS)

/*
 * LIQUID ART CONTRACT
 * Replacement art drops in by keeping these names, with no new plumbing:
 * - Base: "[base_icon_state]-[junction]" bitmask smoothing states in liquid.dmi, one light grey at full alpha.
 * - Depth: "stage[1-4]_bottom" and "stage[1-3]_top" in liquid_overlays.dmi, picked below from liquid_state.
 * - Code tints both with color (the reagent mix times the class's LIQUID_COLOR_FACTOR_*) and sets alpha from depth
 *   and reagent_opacity in SSliquids.get_pool_alpha(), so the art bakes in neither. The depth overlays undo the
 *   factor with a colour matrix, so they draw in the mix itself.
 * - Surface, in liquid_surfaces.dmi, in its own colour and alpha over the base, by the pool's surface_class:
 *   - one edge piece per tile, "<edge>-[junction]": lip (clear), opaque (opaque, blood), oil (oil, fuel), mirror, tar;
 *   - up to two texture slices "<texture>_<row>_<column>", world-anchored (column = x % grid,
 *     row = (grid - 1) - (y % grid)) and clipped to the base by an alpha filter: sheen_oil (oil), sheen_fuel under
 *     "fuel_weight-[junction]" (fuel), mirror (mirror), tone (opaque, blood, tar) and the reagent's detail (grit,
 *     chunks, bumps). A lone puddle (junction 0) takes a fixed sheen or mirror slice. make_surface_texture() holds
 *     the grids and the lone slices.
 * - RULE: the fire, tone, grit and chunks art must keep every partly clear pixel at 0 or 255 per colour channel, at
 *   its mask's size. Only then does a fully opaque mask's filter change nothing, so get_clip_filter() drops it. A
 *   filter draws other soft colours a level off, so art that breaks the rule comes off exact_textures (the fire goes
 *   back to get_alpha_filter()). The other slices keep their filter, with one approved exception: a weight mask of
 *   one alpha (fuel's "fuel_weight-255", inside a pool) becomes the sheen slice's own alpha, up to a level off
 *   the filter. Weight masks that vary over the tile, on a pool's edge, keep their filter.
 * - Fire, in liquid_fire.dmi, untinted and at full alpha, as vis_contents holders (update_fire_visuals()): 48x48 at
 *   LIQUID_FIRE_PIXEL_OFFSET, below mobs on the game plane. Flames "fire_<tier>_A<loop>" and their emissive copy are
 *   clipped by "flame-[junction]", the smoke "smoke_<tier>_A<loop>" over them by "smoke-[junction]" (liquid_masks.dmi).
 *   The tier is small, medium or big from fire_state, the loop 1 to 5 from fire_loop_table. A tile that catches flicks
 *   the one-shot "ignite_<tier>_A<loop>" on the flames and their copy, and its smoke starts when the ignite ends.
 */
/obj/effect/abstract/liquid_turf/update_overlays()
	. = ..()

	if(no_effects)
		return

	switch(liquid_state)
		if(LIQUID_STATE_ANKLES)
			. += make_state_layer(1, has_top = TRUE)
		if(LIQUID_STATE_WAIST)
			. += make_state_layer(2, has_top = TRUE)
		if(LIQUID_STATE_SHOULDERS)
			. += make_state_layer(3, has_top = TRUE)
		if(LIQUID_STATE_FULLTILE)
			. += make_state_layer(4, has_top = FALSE)

	. += make_surface_overlays()

/// Returns this tile's surface overlays for its surface_class, in drawing order: the edge piece and the texture slices.
/obj/effect/abstract/liquid_turf/proc/make_surface_overlays()
	PRIVATE_PROC(TRUE)

	var/junction = smoothing_junction || NONE
	switch(surface_class)
		if(LIQUID_SURFACE_CLEAR)
			return list(make_surface_piece("lip-[junction]"))
		if(LIQUID_SURFACE_OIL)
			return list(make_surface_piece("oil-[junction]"), make_surface_texture("sheen_oil", junction))
		if(LIQUID_SURFACE_FUEL)
			// Fuel takes oil's lit rim, and its sheen thins out toward the middle.
			return list(make_surface_piece("oil-[junction]"), make_surface_texture("sheen_fuel", junction, "fuel_weight-[junction]"))
		if(LIQUID_SURFACE_MIRROR)
			// The reflection lies under the bead's rim.
			return list(make_surface_texture("mirror", junction), make_surface_piece("mirror-[junction]"))
		if(LIQUID_SURFACE_OPAQUE, LIQUID_SURFACE_BLOOD, LIQUID_SURFACE_TAR)
			. = list(make_surface_piece("[surface_class == LIQUID_SURFACE_TAR ? "tar" : "opaque"]-[junction]"), make_surface_texture("tone", junction))
			if(surface_detail)
				. += make_surface_texture(surface_detail, junction)

/// Returns a liquid_surfaces.dmi state as an overlay in its own colour and alpha.
/obj/effect/abstract/liquid_turf/proc/make_surface_piece(piece_state)
	PRIVATE_PROC(TRUE)

	// Float plane and layer draw it with the liquid, plane offset included. On FLOOR_PLANE it would need a TOPDOWN layer.
	return mutable_appearance(LIQUID_SURFACES_DMI, piece_state, FLOAT_LAYER, null, FLOAT_PLANE, 255, RESET_COLOR|RESET_ALPHA)

/**
 * Returns this tile's slice of a world-anchored surface texture, clipped to the pool by an alpha filter.
 *
 * A fully opaque mask leaves tone, grit and chunks slices unfiltered (get_clip_filter()), and a weight mask of one
 * alpha becomes the slice's own alpha.
 *
 * Arguments:
 * - texture: The slices' state prefix in liquid_surfaces.dmi.
 * - junction: This tile's smoothing junction. A lone puddle (0) takes the texture's fixed slice, when it has one.
 * - mask_state: A liquid_surfaces.dmi weight state to clip by. Null clips by this tile's base state.
 */
/obj/effect/abstract/liquid_turf/proc/make_surface_texture(texture, junction, mask_state)
	PRIVATE_PROC(TRUE)

	var/static/list/grids = list("sheen_oil" = 3, "sheen_fuel" = 6, "mirror" = 6, "tone" = 6, "bumps" = 3, "grit" = 3, "chunks" = 3)
	// The (row, column) a lone puddle shows: its world slice could hold anything from no sheen to all sheen.
	var/static/list/lone_slices = list("sheen_oil" = list(0, 1), "sheen_fuel" = list(5, 5), "mirror" = list(3, 2))
	// RULE (art contract): these textures keep every partly clear pixel at 0 or 255 per channel, at the mask's size.
	// A texture whose art breaks it comes off this list, or its slices draw a level off where the filter is skipped.
	var/static/list/exact_textures = list("tone" = TRUE, "grit" = TRUE, "chunks" = TRUE)
	var/list/lone_slice = junction ? null : lone_slices[texture]
	var/mutable_appearance/slice
	if(lone_slice)
		slice = make_surface_piece("[texture]_[lone_slice[1]]_[lone_slice[2]]")
	else
		var/grid = grids[texture]
		slice = make_surface_piece("[texture]_[(grid - 1) - (y % grid)]_[x % grid]")
	if(mask_state)
		// The art contract's approved exception: a weight of one alpha is the slice's own, in place of the filter.
		var/weight_alpha = get_mask_alpha(LIQUID_SURFACES_DMI, mask_state)
		if(isnull(weight_alpha))
			slice.filters = get_alpha_filter(LIQUID_SURFACES_DMI, mask_state)
		else
			slice.alpha = weight_alpha
		return slice
	var/base_mask = "[base_icon_state]-[junction]"
	slice.filters = exact_textures[texture] ? get_clip_filter(icon, base_mask) : get_alpha_filter(icon, base_mask)
	return slice

/**
 * Returns the /icon of one icon state for an alpha mask filter, made once and shared.
 *
 * Every tile with the same junction then filters by the same icon, so their filters dedupe.
 *
 * Arguments:
 * - icon_file: The DMI holding the mask.
 * - mask_state: The mask's icon state.
 */
/obj/effect/abstract/liquid_turf/proc/get_alpha_mask(icon_file, mask_state)
	var/static/list/masks = list()
	var/key = "[mask_state]|\ref[icon_file]"
	var/icon/mask = masks[key]
	if(!mask)
		mask = icon(icon_file, mask_state)
		masks[key] = mask
	return mask

/**
 * Returns the one alpha every pixel of a mask has, or null when its pixels differ. Each mask is read once.
 *
 * Arguments:
 * - icon_file: The DMI holding the mask.
 * - mask_state: The mask's icon state.
 */
/obj/effect/abstract/liquid_turf/proc/get_mask_alpha(icon_file, mask_state)
	// -1 marks a mask whose pixels differ.
	var/static/list/mask_alphas = list()
	var/key = "[mask_state]|\ref[icon_file]"
	var/shared_alpha = mask_alphas[key]
	if(isnull(shared_alpha))
		var/icon/mask = get_alpha_mask(icon_file, mask_state)
		var/width = mask.Width()
		var/height = mask.Height()
		for(var/pixel_y in 1 to height)
			for(var/pixel_x in 1 to width)
				// GetPixel gives null for a clear pixel, and alpha digits only for a partly clear one.
				var/pixel = mask.GetPixel(pixel_x, pixel_y)
				var/pixel_alpha = pixel ? (length(pixel) > 7 ? hex2num(copytext(pixel, 8, 10)) : 255) : 0
				if(isnull(shared_alpha))
					shared_alpha = pixel_alpha
				else if(pixel_alpha != shared_alpha)
					mask_alphas[key] = -1
					return null
		mask_alphas[key] = shared_alpha
	return shared_alpha == -1 ? null : shared_alpha

/**
 * Returns get_alpha_filter() for a mask, or null when the mask is fully opaque and so clips nothing.
 *
 * Only for art under the exact-art RULE in the art contract: the mask's size, and partly clear pixels, if any, at 0 or
 * 255 per channel. A filter passes those and opaque or clear pixels exactly, but draws other partly clear colours a
 * level off, so leaving it out would change them.
 *
 * Arguments:
 * - icon_file: The DMI holding the mask.
 * - mask_state: The mask's icon state.
 */
/obj/effect/abstract/liquid_turf/proc/get_clip_filter(icon_file, mask_state)
	return get_mask_alpha(icon_file, mask_state) == 255 ? null : get_alpha_filter(icon_file, mask_state)

/**
 * Returns an alpha filter by one icon state's mask from get_alpha_mask(), made once and shared.
 *
 * Arguments:
 * - icon_file: The DMI holding the mask.
 * - mask_state: The mask's icon state.
 */
/obj/effect/abstract/liquid_turf/proc/get_alpha_filter(icon_file, mask_state)
	var/static/list/alpha_filters = list()
	var/key = "[mask_state]|\ref[icon_file]"
	. = alpha_filters[key]
	if(!.)
		. = filter(type = "alpha", icon = get_alpha_mask(icon_file, mask_state))
		alpha_filters[key] = .

/obj/effect/abstract/liquid_turf/set_smoothed_icon_state(new_junction)
	. = ..()
	// The edge piece, the texture clips and the fire masks follow the junction; before the first smoothing they drew 0.
	if((. || NONE) != (new_junction || NONE))
		update_icon(UPDATE_OVERLAYS)
		if(fire_flames)
			set_fire_masks()

//Takes a flat of our reagents and returns it, possibly qdeling our liquids
/obj/effect/abstract/liquid_turf/proc/take_reagents_flat(flat_amount)
	var/datum/reagents/tempr = new(10000)
	if(flat_amount >= total_reagents)
		tempr.add_noreact_reagent_list(reagent_list)
		qdel(src, TRUE)
	else
		var/fraction = flat_amount/total_reagents
		var/passed_list = list()
		for(var/reagent_type in reagent_list)
			var/amount = fraction * reagent_list[reagent_type]
			reagent_list[reagent_type] -= amount
			total_reagents -= amount
			passed_list[reagent_type] = amount
		tempr.add_noreact_reagent_list(passed_list)
		has_cached_share = FALSE
	tempr.chem_temp = temp
	return tempr

/obj/effect/abstract/liquid_turf/immutable/take_reagents_flat(flat_amount)
	return simulate_reagents_flat(flat_amount)

//Returns a reagents holder with all the reagents with a higher volume than the threshold
/obj/effect/abstract/liquid_turf/proc/simulate_reagents_threshold(amount_threshold)
	var/datum/reagents/tempr = new(10000)
	var/passed_list = list()
	for(var/reagent_type in reagent_list)
		var/amount = reagent_list[reagent_type]
		if(amount_threshold && amount < amount_threshold)
			continue
		passed_list[reagent_type] = amount
	tempr.add_noreact_reagent_list(passed_list)
	tempr.chem_temp = temp
	return tempr

//Returns a flat of our reagents without any effects on the liquids
/obj/effect/abstract/liquid_turf/proc/simulate_reagents_flat(flat_amount)
	var/datum/reagents/tempr = new(10000)
	if(flat_amount >= total_reagents)
		tempr.add_noreact_reagent_list(reagent_list)
	else
		var/fraction = flat_amount/total_reagents
		var/passed_list = list()
		for(var/reagent_type in reagent_list)
			var/amount = fraction * reagent_list[reagent_type]
			passed_list[reagent_type] = amount
		tempr.add_noreact_reagent_list(passed_list)
	tempr.chem_temp = temp
	return tempr

/obj/effect/abstract/liquid_turf/fire_act(temperature, volume)
	if(!fire_state)
		if(check_fire(TRUE))
			SSliquids.processing_fire[my_turf] = TRUE

/**
 * Tints the liquid to its reagent mix, sets its alpha from depth and opacity, and picks its surface.
 *
 * Arguments:
 * - redraw: FALSE leaves a changed surface for the caller to redraw.
 *
 * Returns:
 * - TRUE: The surface changed.
 */
/obj/effect/abstract/liquid_turf/proc/set_reagent_color_for_liquid(redraw = TRUE)
	if(!reagent_list[/datum/reagent/blood])
		blood_color = null
	if(length(reagent_list) == 1 && !blood_color)
		// One reagent mixes to its own colour at any volume, so its look comes from the per-type cache.
		var/reagent_type = reagent_list[1]
		var/volume = reagent_list[reagent_type]
		if(volume > 0)
			var/datum/liquid_reagent_look/look = get_liquid_reagent_look(reagent_type)
			color = get_lone_liquid_color(reagent_type)
			// The same sum mix_opacity_from_reagent_list() makes, to the last bit.
			reagent_opacity = look.opacity * volume / volume
			alpha = SSliquids.get_pool_alpha(liquid_state, reagent_opacity)
			return set_surface(look.surface_class, look.surface_detail, redraw)
	var/list/surface = get_liquid_surface(reagent_list)
	color = scale_liquid_color(mix_liquid_color(reagent_list, blood_color), surface[1])
	reagent_opacity = mix_opacity_from_reagent_list(reagent_list)
	// Alpha after color: a colour with its own alpha, like water's, overwrites alpha too.
	alpha = SSliquids.get_pool_alpha(liquid_state, reagent_opacity)
	return set_surface(surface[1], surface[2], redraw)

/**
 * Sets the pool's surface class and detail.
 *
 * Arguments:
 * - new_class: A LIQUID_SURFACE_* define.
 * - new_detail: The class's detail, or null.
 * - redraw: FALSE leaves a change for the caller to redraw.
 *
 * Returns:
 * - TRUE: Either changed.
 */
/obj/effect/abstract/liquid_turf/proc/set_surface(new_class, new_detail, redraw = TRUE)
	if(surface_class == new_class && surface_detail == new_detail)
		return FALSE
	surface_class = new_class
	surface_detail = new_detail
	if(redraw)
		update_icon(UPDATE_OVERLAYS)
	return TRUE

/**
 * Works out this liquid's depth, colour, alpha and surface from reagent_list, and redraws its overlays once if its
 * depth or surface changed.
 *
 * Arguments:
 * - force_redraw: TRUE redraws even when neither changed, for a liquid that isn't drawn yet.
 */
/obj/effect/abstract/liquid_turf/proc/update_from_reagents(force_redraw = FALSE)
	var/state_changed = calculate_height(FALSE)
	if(set_reagent_color_for_liquid(FALSE) || state_changed || force_redraw)
		update_icon(UPDATE_OVERLAYS)

/**
 * Blends blood coming into this liquid into blood_color, weighted by blood volume.
 *
 * Call it before the blood joins reagent_list, which must still hold the old blood volume.
 *
 * Arguments:
 * - added_color: Colour of the blood coming in. Null counts as the blood reagent's own colour.
 * - added_blood: Units of blood coming in.
 */
/obj/effect/abstract/liquid_turf/proc/blend_blood_color(added_color, added_blood)
	if(added_blood <= 0)
		return
	var/list/blood_by_color = list()
	blood_by_color[added_color || /datum/reagent/blood::color] = added_blood
	var/old_blood = reagent_list[/datum/reagent/blood]
	if(old_blood)
		blood_by_color[blood_color || /datum/reagent/blood::color] += old_blood
	blood_color = mix_colors_by_volume(blood_by_color)

/**
 * Sets the liquid's height from its volume, and its depth from that height.
 *
 * Arguments:
 * - redraw: FALSE leaves a changed depth for the caller to redraw.
 *
 * Returns:
 * - TRUE: The depth changed.
 */
/obj/effect/abstract/liquid_turf/proc/calculate_height(redraw = TRUE)
	var/new_height = ceil(total_reagents)/LIQUID_HEIGHT_DIVISOR
	set_height(new_height)
	//We add the turf height if it's positive to state calculations
	if(my_turf.turf_height > 0)
		new_height += my_turf.turf_height
	var/determined_new_state = get_liquid_state_for_height(new_height)
	if(determined_new_state == liquid_state)
		return FALSE
	set_new_liquid_state(determined_new_state, redraw)
	alpha = SSliquids.get_pool_alpha(liquid_state, reagent_opacity)
	return TRUE

/obj/effect/abstract/liquid_turf/immutable/calculate_height(redraw = TRUE)
	var/new_height = ceil(total_reagents)/LIQUID_HEIGHT_DIVISOR
	set_height(new_height)
	var/determined_new_state = get_liquid_state_for_height(new_height)
	if(determined_new_state == liquid_state)
		return FALSE
	set_new_liquid_state(determined_new_state, redraw)
	return TRUE

/// Returns the LIQUID_STATE_* depth for a liquid height, fractions included, from a puddle up to a full tile.
/obj/effect/abstract/liquid_turf/proc/get_liquid_state_for_height(state_height)
	if(state_height < LIQUID_ANKLES_LEVEL_HEIGHT)
		return LIQUID_STATE_PUDDLE
	if(state_height < LIQUID_WAIST_LEVEL_HEIGHT)
		return LIQUID_STATE_ANKLES
	if(state_height < LIQUID_SHOULDERS_LEVEL_HEIGHT)
		return LIQUID_STATE_WAIST
	if(state_height < LIQUID_FULLTILE_LEVEL_HEIGHT)
		return LIQUID_STATE_SHOULDERS
	return LIQUID_STATE_FULLTILE

/obj/effect/abstract/liquid_turf/proc/set_height(new_height)
	var/prev_height = height
	height = new_height
	if(abs(height - prev_height) > WATER_HEIGH_DIFFERENCE_DELTA_SPLASH)
		//Splash
		if(prob(WATER_HEIGH_DIFFERENCE_SOUND_CHANCE))
			var/sound_to_play = pick(list(
				'modular_nova/modules/liquids/sound/effects/water_wade1.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade2.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade3.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade4.ogg'
				))
			playsound(my_turf, sound_to_play, 60, 0)
		var/obj/splashy = new /obj/effect/temp_visual/liquid_splash(my_turf)
		// The mix itself: color carries the base art's class factor.
		splashy.color = mix_liquid_color(reagent_list, blood_color)
		splashy.alpha = alpha
		if(height >= LIQUID_WAIST_LEVEL_HEIGHT)
			//Push things into some direction, like space wind
			var/turf/dest_turf
			var/last_height = height
			for(var/turf in my_turf.atmos_adjacent_turfs)
				var/turf/T = turf
				if(T.z != my_turf.z)
					continue
				if(!T.liquids) //Automatic winner
					dest_turf = T
					break
				if(T.liquids.height < last_height)
					dest_turf = T
					last_height = T.liquids.height
			if(dest_turf)
				var/dir = get_dir(my_turf, dest_turf)
				var/atom/movable/AM
				for(var/thing in my_turf)
					AM = thing
					if(!AM.anchored && !AM.pulledby && !isobserver(AM) && (AM.move_resist < INFINITY))
						var/mob/living/carbon/carbon = AM
						if(istype(carbon))
							var/obj/item/clothing/shoes/shoes = carbon.get_item_by_slot(ITEM_SLOT_FEET)
							if(!(shoes && shoes.clothing_flags))
								step(carbon, dir)
								if(prob(60) && carbon.body_position != LYING_DOWN)
									to_chat(carbon, span_userdanger("The current knocks you down!"))
									carbon.Knockdown(1 SECONDS)
						else
							step(AM, dir)

/obj/effect/abstract/liquid_turf/immutable/set_height(new_height)
	height = new_height

/obj/effect/abstract/liquid_turf/proc/movable_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	var/turf/T = source
	if(isobserver(AM))
		return //ghosts, camera eyes, etc. don't make water splashy splashy
	if(liquid_state >= LIQUID_STATE_ANKLES)
		if(prob(30))
			var/sound_to_play = pick(list(
				'modular_nova/modules/liquids/sound/effects/water_wade1.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade2.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade3.ogg',
				'modular_nova/modules/liquids/sound/effects/water_wade4.ogg'
				))
			playsound(T, sound_to_play, 50, 0)
		if(iscarbon(AM))
			var/mob/living/carbon/C = AM
			C.apply_status_effect(/datum/status_effect/water_affected)
	else if (isliving(AM))
		var/mob/living/L = AM
		if(prob(7) && !(L.movement_type & FLYING))
			L.slip(1 SECONDS, T, NO_SLIP_WHEN_WALKING, 2 SECONDS, TRUE)
	if(fire_state)
		AM.fire_act(get_fire_temperature(), 125)

/obj/effect/abstract/liquid_turf/proc/mob_fall(datum/source, mob/M)
	SIGNAL_HANDLER
	var/turf/T = source
	if(liquid_state >= LIQUID_STATE_ANKLES && T.has_gravity(T))
		playsound(T, 'modular_nova/modules/liquids/sound/effects/splash.ogg', 50, 0)
		if(iscarbon(M))
			var/mob/living/carbon/falling_carbon = M

			// No point in giving reagents to the deceased. It can cause some runtimes.
			if(falling_carbon.stat >= DEAD)
				return

			var/obj/item/clothing/mask/wear_mask = falling_carbon.get_item_by_slot(ITEM_SLOT_MASK)
			if(wear_mask && wear_mask.flags_cover & MASKCOVERSMOUTH)
				to_chat(falling_carbon, span_userdanger("You fall in the [reagents_to_text()]!"))
			else
				var/datum/reagents/tempr = take_reagents_flat(CHOKE_REAGENTS_INGEST_ON_FALL_AMOUNT)
				tempr.trans_to(falling_carbon, tempr.total_volume, methods = INGEST)
				qdel(tempr)
				falling_carbon.adjust_oxy_loss(5)
				//C.emote("cough")
				INVOKE_ASYNC(falling_carbon, TYPE_PROC_REF(/mob, emote), "cough")
				to_chat(falling_carbon, span_userdanger("You fall in and swallow some [reagents_to_text()]!"))
		else
			to_chat(M, span_userdanger("You fall in the [reagents_to_text()]!"))

/**
 * Hooks the liquid to its turf, draws it and queues its smoothing.
 *
 * Arguments:
 * - draw_later: TRUE when the caller fills the new liquid and draws it once at the end; FALSE draws it now, empty.
 */
/obj/effect/abstract/liquid_turf/Initialize(mapload, draw_later = FALSE)
	. = ..()
	if(!SSliquids)
		CRASH("Liquid Turf created with the liquids sybsystem not yet initialized!")
	if(!immutable)
		my_turf = loc
		RegisterSignal(my_turf, COMSIG_ATOM_ENTERED, PROC_REF(movable_entered))
		RegisterSignal(my_turf, COMSIG_TURF_MOB_FALL, PROC_REF(mob_fall))
		RegisterSignal(my_turf, COMSIG_ATOM_EXAMINE, PROC_REF(examine_turf))
		SSliquids.add_active_turf(my_turf)
		my_turf.set_fuel_pool_under_liquid(TRUE)

		SEND_SIGNAL(my_turf, COMSIG_TURF_LIQUIDS_CREATION, src)

	if(!draw_later)
		update_icon(UPDATE_OVERLAYS)
	if(z)
		QUEUE_SMOOTH(src)
		QUEUE_SMOOTH_NEIGHBORS(src)

	/* //Cant do it immediately, hmhm
	if(isspaceturf(my_turf))
		qdel(src, TRUE)
	*/

/obj/effect/abstract/liquid_turf/Destroy(force)
	if(force)
		UnregisterSignal(my_turf, list(COMSIG_ATOM_ENTERED, COMSIG_TURF_MOB_FALL, COMSIG_ATOM_EXAMINE))
		if(my_turf.lgroup)
			my_turf.lgroup.remove_from_group(my_turf)
		if(SSliquids.evaporation_queue[my_turf])
			SSliquids.evaporation_queue -= my_turf
		if(SSliquids.processing_fire[my_turf])
			SSliquids.processing_fire -= my_turf
		clear_fire_visuals()
		//Is added because it could invoke a change to neighboring liquids
		SSliquids.add_active_turf(my_turf)
		my_turf.liquids = null
		my_turf.set_fuel_pool_under_liquid(FALSE)
		if(fire_state)
			SSliquids.release_fire_light(src)
		my_turf = null
		QUEUE_SMOOTH_NEIGHBORS(src)
	else
		return QDEL_HINT_LETMELIVE
	return ..()

/obj/effect/abstract/liquid_turf/immutable/Destroy(force)
	if(force)
		stack_trace("Something tried to hard destroy an immutable liquid.")
	return ..()

//Exposes my turf with simulated reagents
/obj/effect/abstract/liquid_turf/proc/ExposeMyTurf()
	var/datum/reagents/tempr = simulate_reagents_threshold(LIQUID_REAGENT_THRESHOLD_TURF_EXPOSURE)
	if(tempr.total_volume > 0)
		tempr.expose(my_turf, TOUCH, tempr.total_volume)
	qdel(tempr)

/obj/effect/abstract/liquid_turf/proc/ChangeToNewTurf(turf/NewT)
	if(NewT.liquids)
		stack_trace("Liquids tried to change to a new turf, that already had liquids on it!")

	UnregisterSignal(my_turf, list(COMSIG_ATOM_ENTERED, COMSIG_TURF_MOB_FALL))
	if(SSliquids.active_turfs[my_turf])
		SSliquids.active_turfs -= my_turf
		SSliquids.active_turfs[NewT] = TRUE
	if(SSliquids.evaporation_queue[my_turf])
		SSliquids.evaporation_queue -= my_turf
		SSliquids.evaporation_queue[NewT] = TRUE
	if(SSliquids.processing_fire[my_turf])
		SSliquids.processing_fire -= my_turf
		SSliquids.processing_fire[NewT] = TRUE
	my_turf.liquids = null
	if(fire_state)
		SSliquids.release_fire_light(src)
	my_turf = NewT
	NewT.liquids = src
	loc = NewT
	if(fire_state)
		SSliquids.mark_fire_block(my_turf)
	RegisterSignal(my_turf, COMSIG_ATOM_ENTERED, PROC_REF(movable_entered))
	RegisterSignal(my_turf, COMSIG_TURF_MOB_FALL, PROC_REF(mob_fall))

/**
 * Handles COMSIG_ATOM_EXAMINE for the turf.
 *
 * Adds reagent info to examine text.
 * Arguments:
 * * source - the turf we're peekin at
 * * examiner - the user
 * * examine_text - the examine list
 *  */
/obj/effect/abstract/liquid_turf/proc/examine_turf(turf/source, mob/examiner, list/examine_list)
	SIGNAL_HANDLER

	// This should always have reagents if this effect object exists, but as a sanity check...
	if(!length(reagent_list))
		return

	var/liquid_state_template = liquid_state_messages["[liquid_state]"]

	if(examiner.can_see_reagents())
		if(length(reagent_list) == 1)
			// Single reagent text.
			var/datum/reagent/reagent_type = reagent_list[1]
			var/reagent_name = initial(reagent_type.name)
			var/volume = round(reagent_list[reagent_type], 0.01)

			examine_list += span_notice("There is [replacetext(liquid_state_template, "$", "[volume] units of [reagent_name]")] here.")
		else
			// Show each individual reagent
			examine_list += "There is [replacetext(liquid_state_template, "$", "the following")] here:"

			for(var/datum/reagent/reagent_type as anything in reagent_list)
				var/reagent_name = initial(reagent_type.name)
				var/volume = round(reagent_list[reagent_type], 0.01)
				examine_list += "&bull; [volume] units of [reagent_name]"

		examine_list += span_notice("The solution has a temperature of [temp]K.[EXAMINE_SECTION_BREAK]")
		return

	// Otherwise, just show the total volume
	examine_list += span_notice("There is [replacetext(liquid_state_template, "$", "liquid")] here.[EXAMINE_SECTION_BREAK]")

/**
 * Creates a string of the reagents that make up this liquid.
 *
 * Puts the reagent(s) that make up the liquid into string form e.g. "plasma" or "plasma and water", or 'plasma, milk, and water' depending on how many reagents there are.
 *
 * Returns the reagents list string or a generic "liquid" if there are no reagents somehow
 *  */
/obj/effect/abstract/liquid_turf/proc/reagents_to_text()
	/// the total amount of different types of reagents in the liquid
	var/total_reagents = length(reagent_list)
	/// the amount of different types of reagents that have not been listed yet
	var/reagents_remaining = total_reagents
	/// the final string to be returned
	var/reagents_string = ""
	if(!reagents_remaining)
		return reagents_string += "liquid"

	do
		for(var/datum/reagent/reagent_type as anything in reagent_list)
			reagents_string += "[initial(reagent_type.name)]"
			reagents_remaining--
			if(!reagents_remaining)
				break
			// if we are at the last reagent in the list, preface its name with 'and'.
			// do not use a comma if there were only two reagents in the list
			if(total_reagents == 2)
				reagents_string += " and "
			else
				reagents_string += ", "
				if(reagents_remaining == 1)
					reagents_string += "and "
	while(reagents_remaining)

	return LOWER_TEXT(reagents_string)

/obj/effect/temp_visual/liquid_splash
	icon = 'modular_nova/modules/liquids/icons/obj/effects/splash.dmi'
	icon_state = "splash"
	layer = FLY_LAYER
	randomdir = FALSE

/// One piece of a burning tile's fire in the liquid's vis_contents: the flames, their emissive copy or the smoke.
/obj/effect/abstract/liquid_fire
	name = "liquid fire"
	icon = LIQUID_FIRE_DMI
	anchored = TRUE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	layer = BELOW_MOB_LAYER
	appearance_flags = RESET_COLOR | RESET_ALPHA
	// An effect's generic blocker would black out the fire's own glow.
	blocks_emissive = EMISSIVE_BLOCK_NONE
	pixel_w = LIQUID_FIRE_PIXEL_OFFSET
	pixel_z = LIQUID_FIRE_PIXEL_OFFSET
	/// The world.time this holder last went back to an SSliquids pool. It isn't taken again in that tick.
	var/released_at

/obj/effect/abstract/liquid_turf/immutable
	immutable = TRUE
	var/list/starting_mixture = list(/datum/reagent/water = 600)
	var/starting_temp = T20C

//STRICTLY FOR IMMUTABLES DESPITE NOT BEING /immutable
/obj/effect/abstract/liquid_turf/proc/add_turf(turf/T)
	T.liquids = src
	T.vis_contents += src
	SSliquids.active_immutables[T] = TRUE
	RegisterSignal(T, COMSIG_ATOM_ENTERED, PROC_REF(movable_entered))
	RegisterSignal(T, COMSIG_TURF_MOB_FALL, PROC_REF(mob_fall))

/obj/effect/abstract/liquid_turf/proc/remove_turf(turf/T)
	SSliquids.active_immutables -= T
	T.liquids = null
	T.vis_contents -= src
	UnregisterSignal(T, list(COMSIG_ATOM_ENTERED, COMSIG_TURF_MOB_FALL))

/obj/effect/abstract/liquid_turf/immutable/ocean
	smoothing_flags = NONE
	icon_state = "ocean"
	base_icon_state = "ocean"
	layer = FLY_LAYER
	plane = ABOVE_GAME_PLANE
	starting_temp = T20C-150
	no_effects = TRUE
	vis_flags = NONE

/obj/effect/abstract/liquid_turf/immutable/ocean/warm
	starting_temp = T20C+20

/obj/effect/abstract/liquid_turf/immutable/Initialize(mapload, plane_offset)
	// Only mapload goes up: the parent's second argument is draw_later.
	. = ..(mapload)
	SET_PLANE_W_SCALAR(src, initial(plane), plane_offset)
	reagent_list = starting_mixture.Copy()
	total_reagents = 0
	for(var/key in reagent_list)
		total_reagents += reagent_list[key]
	temp = starting_temp
	calculate_height()
	color = mix_liquid_color(reagent_list)
	// Alpha after color. Immutables take the alpha their reagents' colours carry; the ocean art is tuned for it.
	var/alpha_volume = 0
	for(var/reagent_type, volume in reagent_list)
		var/datum/reagent/reagent_path = reagent_type
		var/list/channels = rgb2num(initial(reagent_path.color))
		alpha_volume += (length(channels) > 3 ? channels[4] : 255) * volume
	alpha = round(alpha_volume / total_reagents, 1)

#undef LIQUID_SURFACES_DMI
#undef LIQUID_FIRE_DMI
#undef LIQUID_MASKS_DMI
