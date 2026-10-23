/obj/effect/abstract/liquid_turf
	name = "liquid"
	icon = 'modular_nova/modules/liquids/icons/obj/effects/liquid.dmi'
	icon_state = "water-0"
	base_icon_state = "water"
	anchored = TRUE
	plane = FLOOR_PLANE
	layer = ABOVE_OPEN_TURF_LAYER
	appearance_flags = TILE_BOUND
	color = "#DDF"

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
	var/temp = T20C

	var/fire_state = LIQUID_FIRE_STATE_NONE

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

/// Sets the fire state, with flames and a light sized to it.
/obj/effect/abstract/liquid_turf/proc/set_fire_state(new_state)
	fire_state = new_state
	switch(fire_state)
		if(LIQUID_FIRE_STATE_NONE)
			set_light(0)
		if(LIQUID_FIRE_STATE_SMALL)
			set_light(1.5, 0.5)
		if(LIQUID_FIRE_STATE_MILD)
			set_light(2, 0.75)
		if(LIQUID_FIRE_STATE_MEDIUM)
			set_light(2.5, 1)
		if(LIQUID_FIRE_STATE_HUGE)
			set_light(LIGHT_RANGE_FIRE, 1.5)
		if(LIQUID_FIRE_STATE_INFERNO)
			set_light(4, LIGHT_POWER_FIRE)
	update_icon(UPDATE_OVERLAYS)

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
		calculate_height()
		set_reagent_color_for_liquid()
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
		calculate_height()
		set_reagent_color_for_liquid()

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

	if(!has_top)
		return

	. += make_liquid_overlay("stage[state]_top", TABLE_LAYER + 0.05, GAME_PLANE)

/obj/effect/abstract/liquid_turf/proc/set_new_liquid_state(new_state)
	liquid_state = new_state
	if(!isnull(my_turf))
		my_turf.liquids_change(new_state)
	update_icon(UPDATE_OVERLAYS)

/*
 * LIQUID ART CONTRACT
 * Replacement art drops in by keeping these names, with no new plumbing:
 * - Floor layer: "[base_icon_state]-[junction]" bitmask smoothing states in liquid.dmi.
 * - Depth: "stage[1-4]_bottom" and "stage[1-3]_top" in liquid_overlays.dmi, picked below from liquid_state.
 * - Both are grayscale at full alpha. Code tints them with color (the reagent mix) and sets alpha
 *   from depth and reagent_opacity in SSliquids.get_pool_alpha(), so the art bakes in neither.
 * - An opaque variant, if the art has one, keys off reagent_opacity (0 to 1), which every pool carries.
 * - "shine" and the fire states keep their own colour and alpha.
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

	var/mutable_appearance/shine = mutable_appearance(icon, "shine", offset_spokesman = src, alpha = 32, appearance_flags = RESET_COLOR|RESET_ALPHA)
	shine.blend_mode = BLEND_ADD
	. += shine

	//Add a fire overlay too

	if(fire_state == LIQUID_FIRE_STATE_NONE)
		return

	var/fire_icon_state
	switch(fire_state)
		if(LIQUID_FIRE_STATE_SMALL)
			fire_icon_state = "fire_small"
		if(LIQUID_FIRE_STATE_MILD)
			fire_icon_state = "fire_small"
		if(LIQUID_FIRE_STATE_MEDIUM)
			fire_icon_state = "fire_medium"
		if(LIQUID_FIRE_STATE_HUGE)
			fire_icon_state = "fire_big"
		if(LIQUID_FIRE_STATE_INFERNO)
			fire_icon_state = "fire_big"

	. += mutable_appearance(icon, fire_icon_state, BELOW_MOB_LAYER, src, GAME_PLANE, appearance_flags = RESET_COLOR|RESET_ALPHA)
	. += emissive_appearance(icon, fire_icon_state, src, appearance_flags = RESET_ALPHA)

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

/// Tints the liquid to its reagent mix and sets its alpha from depth and opacity.
/obj/effect/abstract/liquid_turf/proc/set_reagent_color_for_liquid()
	color = mix_color_from_reagent_list(reagent_list)
	reagent_opacity = mix_opacity_from_reagent_list(reagent_list)
	// Alpha after color: a colour with its own alpha, like water's, overwrites alpha too.
	alpha = SSliquids.get_pool_alpha(liquid_state, reagent_opacity)

/obj/effect/abstract/liquid_turf/proc/calculate_height()
	var/new_height = ceil(total_reagents)/LIQUID_HEIGHT_DIVISOR
	set_height(new_height)
	//We add the turf height if it's positive to state calculations
	if(my_turf.turf_height > 0)
		new_height += my_turf.turf_height
	var/determined_new_state = get_liquid_state_for_height(new_height)
	if(determined_new_state != liquid_state)
		set_new_liquid_state(determined_new_state)
		alpha = SSliquids.get_pool_alpha(liquid_state, reagent_opacity)

/obj/effect/abstract/liquid_turf/immutable/calculate_height()
	var/new_height = ceil(total_reagents)/LIQUID_HEIGHT_DIVISOR
	set_height(new_height)
	var/determined_new_state = get_liquid_state_for_height(new_height)
	if(determined_new_state != liquid_state)
		set_new_liquid_state(determined_new_state)

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
		splashy.color = color
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

/obj/effect/abstract/liquid_turf/Initialize(mapload)
	. = ..()
	if(!SSliquids)
		CRASH("Liquid Turf created with the liquids sybsystem not yet initialized!")
	if(!immutable)
		my_turf = loc
		RegisterSignal(my_turf, COMSIG_ATOM_ENTERED, PROC_REF(movable_entered))
		RegisterSignal(my_turf, COMSIG_TURF_MOB_FALL, PROC_REF(mob_fall))
		RegisterSignal(my_turf, COMSIG_ATOM_EXAMINE, PROC_REF(examine_turf))
		SSliquids.add_active_turf(my_turf)

		SEND_SIGNAL(my_turf, COMSIG_TURF_LIQUIDS_CREATION, src)

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
		//Is added because it could invoke a change to neighboring liquids
		SSliquids.add_active_turf(my_turf)
		my_turf.liquids = null
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
	my_turf = NewT
	NewT.liquids = src
	loc = NewT
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
	. = ..()
	SET_PLANE_W_SCALAR(src, initial(plane), plane_offset)
	reagent_list = starting_mixture.Copy()
	total_reagents = 0
	for(var/key in reagent_list)
		total_reagents += reagent_list[key]
	temp = starting_temp
	calculate_height()
	// Immutables keep the alpha their reagent colour carries; the ocean art is tuned for it.
	color = mix_color_from_reagent_list(reagent_list)
