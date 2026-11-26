#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Turf replacement must discard type-owned context while retaining external listeners. */
/datum/unit_test/turf_context_replacement
	/// Number of signals delivered to the external test listener.
	var/context_callbacks = 0

/datum/unit_test/turf_context_replacement/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/turf/door = run_loc_floor_bottom_left.ChangeTurf(/turf/closed/indestructible/hoteldoor/fakedoor/public)
	var/list/door_handlers = door._signal_procs?[door]
	var/door_registered = door_handlers?[COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM]
	RegisterSignal(door, COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM, PROC_REF(on_context))
	var/turf/restored = door.ChangeTurf(original_type, original_baseturfs)
	var/list/restored_handlers = restored._signal_procs?[restored]
	var/stale_context = restored_handlers?[COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM]
	SEND_SIGNAL(restored, COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM, list(), null, null)
	UnregisterSignal(restored, COMSIG_ATOM_REQUESTING_CONTEXT_FROM_ITEM)
	if(!door_registered || stale_context || context_callbacks != 1)
		return Fail("Turf context lifecycle mismatch: door registered=[!!door_registered], stale handler=[!!stale_context], external callbacks=[context_callbacks].", __FILE__, __LINE__)

/** Observes context signals without supplying any UI text. */
/datum/unit_test/turf_context_replacement/proc/on_context(datum/source, list/context, obj/item/held_item, mob/user)
	SIGNAL_HANDLER
	context_callbacks++
	return NONE

/** A subscriber deleted by replacement initialization must not return in the saved signal table. */
/datum/unit_test/turf_context_deleted_subscriber
	/// Signals received by the live subscriber sharing the deleted decal's signal bucket.
	var/entered_callbacks = 0

/datum/unit_test/turf_context_deleted_subscriber/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/obj/effect/decal/cleanable/blood/gibs/old/subscriber = new(run_loc_floor_bottom_left)
	RegisterSignal(run_loc_floor_bottom_left, COMSIG_ATOM_ENTERED, PROC_REF(on_entered))
	var/turf/replacement = run_loc_floor_bottom_left.ChangeTurf(/turf/open/floor/plating/turf_context_cleanup_test)
	var/deleted = QDELETED(subscriber)
	var/list/lookup = replacement._listen_lookup
	var/listeners = lookup?[COMSIG_ATOM_ENTERED]
	var/retained = islist(listeners) ? (subscriber in listeners) : listeners == subscriber
	// Clean only this fixture's stale entry so a red test does not leave a hard delete behind.
	if(retained)
		if(islist(listeners))
			var/list/remaining = listeners - subscriber
			if(length(remaining) > 1)
				lookup[COMSIG_ATOM_ENTERED] = remaining
			else if(length(remaining))
				lookup[COMSIG_ATOM_ENTERED] = remaining[1]
			else
				lookup -= COMSIG_ATOM_ENTERED
		else
			lookup -= COMSIG_ATOM_ENTERED
	SEND_SIGNAL(replacement, COMSIG_ATOM_ENTERED, null, null)
	UnregisterSignal(replacement, COMSIG_ATOM_ENTERED)
	qdel(subscriber)
	replacement.ChangeTurf(original_type, original_baseturfs)
	if(!deleted || retained || entered_callbacks != 1)
		return Fail("Replacement subscriber lifecycle mismatch: deleted=[!!deleted], retained=[!!retained], live callbacks=[entered_callbacks].", __FILE__, __LINE__)

/** Counts surviving signal deliveries after replacement. */
/datum/unit_test/turf_context_deleted_subscriber/proc/on_entered(datum/source)
	SIGNAL_HANDLER
	entered_callbacks++

/// A reservation's empty/reload cycles must leave one elevation listener per signal.
/datum/unit_test/turf_context_elevation_reservation
	/// Number of retained external listeners delivered while the reservation is replaced.
	var/change_callbacks = 0

/datum/unit_test/turf_context_elevation_reservation/Run()
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(
		1,
		1,
		turf_type_override = /turf/open/space/basic,
	)
	if(!reservation)
		return Fail("Could not reserve the elevation lifecycle fixture.", __FILE__, __LINE__)

	var/turf/target = reservation.bottom_left_turfs[1]
	var/x = target.x
	var/y = target.y
	var/z = target.z
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))

	var/turf/loaded = target.load_on_top(/turf/open/floor/wood)
	var/obj/structure/table/wood/table = new(loaded)
	var/datum/element/elevation/elevation = SSdcs.GetElement(list(/datum/element/elevation, "pixel_shift" = 12), FALSE)
	var/failure
	var/error = turf_context_elevation_state_error(loaded, elevation, TRUE)
	if(!table || error)
		failure = "Initial load_on_top table did not register one elevation listener per signal: [error || "table was not created"]."

	// Shuttle transfers use abstract_move(), so ordinary entering/exiting signals do not fire.
	var/turf/destination = run_loc_floor_bottom_left
	table.onShuttleMove(destination, loaded, list(), EAST, null, null)
	error = turf_context_elevation_state_error(loaded, elevation, FALSE)
	if(error || HAS_TRAIT(loaded, TRAIT_TURF_HAS_ELEVATED_OBJ(12)))
		failure ||= "Shuttle transfer left elevation ownership on the old reservation turf: [error || "trait remained"]."
	error = turf_context_elevation_state_error(destination, elevation, TRUE)
	if(error || !HAS_TRAIT_FROM(destination, TRAIT_TURF_HAS_ELEVATED_OBJ(12), ref(table)))
		failure ||= "Shuttle transfer did not register elevation on its destination: [error || "source trait missing"]."

	// Exercise ordinary movement too and restore the fixture before its existing empty/reload checks.
	table.forceMove(loaded)
	error = turf_context_elevation_state_error(destination, elevation, FALSE)
	if(error || HAS_TRAIT(destination, TRAIT_TURF_HAS_ELEVATED_OBJ(12)))
		failure ||= "Moving the table back left elevation ownership on the shuttle destination: [error || "trait remained"]."
	error = turf_context_elevation_state_error(loaded, elevation, TRUE)
	if(error || !HAS_TRAIT_FROM(loaded, TRAIT_TURF_HAS_ELEVATED_OBJ(12), ref(table)))
		failure ||= "Ordinary movement did not restore elevation on the reservation turf: [error || "source trait missing"]."

	loaded.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, TRUE)
	target = locate(x, y, z)
	error = turf_context_elevation_state_error(target, elevation, FALSE)
	if(!QDELETED(table) || error)
		failure ||= "First empty did not delete the table and clear its elevation listeners: [error || "table remained live"]."

	loaded = target.load_on_top(/turf/open/floor/wood)
	table = new(loaded)
	error = turf_context_elevation_state_error(loaded, elevation, TRUE)
	if(!table || error)
		failure ||= "Reloaded table did not register one elevation listener per signal: [error || "table was not created"]."

	if(table)
		qdel(table)
	if(loaded)
		loaded.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, TRUE)
	target = locate(x, y, z)
	error = turf_context_elevation_state_error(target, elevation, FALSE)
	if(error)
		failure ||= "Final empty left stale elevation listeners: [error]."
	if(turf_context_elevation_listener_count(target, COMSIG_TURF_CHANGE, src) != 1 || change_callbacks < 4)
		failure ||= "The external turf-change listener was not retained through both table cycles and final cleanup."
	UnregisterSignal(target, COMSIG_TURF_CHANGE)
	reservation.Release()
	if(!QDELETED(reservation))
		qdel(reservation)

	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Counts a surviving external listener on each replacement turf. */
/datum/unit_test/turf_context_elevation_reservation/proc/on_turf_change(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	change_callbacks++

/// A turf constructor that qdel's a carried elevating object before saved listeners are restored.
/turf/open/floor/plating/turf_context_elevation_constructor_test

/turf/open/floor/plating/turf_context_elevation_constructor_test/Initialize(mapload)
	. = ..()
	for(var/obj/structure/table/wood/table in contents)
		qdel(table)

/** Constructor-time deletion must not leave a stale elevation callback on the replacement turf. */
/datum/unit_test/turf_context_elevation_constructor
	/// Number of retained external listeners delivered by both turf changes.
	var/change_callbacks = 0

/datum/unit_test/turf_context_elevation_constructor/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/turf/target = run_loc_floor_bottom_left.ChangeTurf(/turf/open/floor/plating)
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))
	var/obj/structure/table/wood/table = new(target)
	var/datum/element/give_turf_traits/table_traits_element = SSdcs.GetElement(
		list(/datum/element/give_turf_traits, table.turf_traits),
		FALSE,
	)
	var/datum/element/footstep_override/table_footstep_element = SSdcs.GetElement(
		list(/datum/element/footstep_override, "priority" = STEP_SOUND_TABLE_PRIORITY),
		FALSE,
	)
	var/turf/replacement = target.ChangeTurf(/turf/open/floor/plating/turf_context_elevation_constructor_test)
	var/datum/element/elevation/elevation = SSdcs.GetElement(list(/datum/element/elevation, "pixel_shift" = 12), FALSE)
	var/failure
	var/error = turf_context_elevation_state_error(replacement, elevation, FALSE)
	if(!QDELETED(table))
		failure = "Constructor fixture did not delete the carried elevating table."
	if(error)
		failure ||= "Constructor-time deletion left stale elevation listeners on the replacement turf: [error]."
	if(!table_traits_element || !table_footstep_element)
		failure ||= "Constructor fixture could not resolve the carried table's shared turf elements."
	else
		var/list/state = turf_context_shared_element_state(replacement, table_traits_element, table_footstep_element)
		if(state[1] || state[2] || state[3] || state[4])
			failure ||= "Constructor-time deletion left shared turf-element registrations: give_turf_traits target=[state[1]] handler=[!!state[2]], footstep_override target=[state[3]] handler=[!!state[4]]."

	table = new(replacement)
	error = turf_context_elevation_state_error(replacement, elevation, TRUE)
	if(!table || error)
		failure ||= "A table reloaded after constructor-time deletion did not register one elevation listener per signal: [error || "table was not created"]."
	if(table_traits_element && table_footstep_element)
		var/list/state = turf_context_shared_element_state(replacement, table_traits_element, table_footstep_element)
		if(state[1] != 1 || !state[2] || state[3] != 1 || !state[4])
			failure ||= "Reloaded table did not restore one shared turf-element registration per signal: give_turf_traits target=[state[1]] handler=[!!state[2]], footstep_override target=[state[3]] handler=[!!state[4]]."

	if(table)
		qdel(table)
	var/turf/restored = replacement.ChangeTurf(original_type, original_baseturfs)
	if(turf_context_elevation_listener_count(restored, COMSIG_TURF_CHANGE, src) != 1 || change_callbacks < 2)
		failure ||= "The external turf-change listener was not retained through the final replacement."
	UnregisterSignal(restored, COMSIG_TURF_CHANGE)
	if(failure)
		return Fail(failure, __FILE__, __LINE__)

/** Counts the external listener retained across the constructor fixture's turf changes. */
/datum/unit_test/turf_context_elevation_constructor/proc/on_turf_change(turf/source, path, list/new_baseturfs, flags, list/post_change_callbacks)
	SIGNAL_HANDLER
	change_callbacks++

/** Entry callbacks can delete an elevating object before its final Moved signal. */
/datum/unit_test/turf_context_elevation_entered_deletion
	var/obj/structure/table/wood/moving_table

/datum/unit_test/turf_context_elevation_entered_deletion/Run()
	var/turf/origin = run_loc_floor_bottom_left
	var/turf/destination = get_step(origin, EAST)
	moving_table = allocate(/obj/structure/table/wood, origin)
	var/obj/structure/table/wood/remaining_table = allocate(/obj/structure/table/wood, origin)
	var/datum/element/elevation/elevation = SSdcs.GetElement(list(/datum/element/elevation, "pixel_shift" = 12), FALSE)
	var/datum/element/give_turf_traits/table_traits = SSdcs.GetElement(list(/datum/element/give_turf_traits, moving_table.turf_traits), FALSE)
	var/datum/element/footstep_override/table_steps = SSdcs.GetElement(list(/datum/element/footstep_override, "priority" = STEP_SOUND_TABLE_PRIORITY), FALSE)
	RegisterSignal(destination, COMSIG_ATOM_ENTERED, PROC_REF(delete_entrant))
	moving_table.forceMove(destination)
	UnregisterSignal(destination, COMSIG_ATOM_ENTERED)

	var/remaining_source = REF(remaining_table)
	var/remaining_owned = (remaining_table in table_steps.occupied_turfs[origin]) && (remaining_source in table_traits.trait_sources?[origin])
	var/remaining_steps = turf_context_elevation_listener_count(origin, COMSIG_TURF_PREPARE_STEP_SOUND, table_steps)
	var/remaining_traits = turf_context_elevation_listener_count(origin, COMSIG_TURF_CHANGE, table_traits)
	for(var/trait in table_traits.traits)
		remaining_owned &&= HAS_TRAIT_FROM(origin, trait, remaining_source)
	qdel(remaining_table)

	var/shared_ownership_error = FALSE
	for(var/turf/location as anything in list(origin, destination))
		var/list/step_handlers = table_steps._signal_procs?[location]
		var/list/trait_handlers = table_traits._signal_procs?[location]
		if(length(table_steps.occupied_turfs[location]) || length(table_traits.trait_sources?[location]) \
			|| turf_context_elevation_listener_count(location, COMSIG_TURF_PREPARE_STEP_SOUND, table_steps) \
			|| turf_context_elevation_listener_count(location, COMSIG_TURF_CHANGE, table_traits) \
			|| step_handlers?[COMSIG_TURF_PREPARE_STEP_SOUND] || trait_handlers?[COMSIG_TURF_CHANGE])
			shared_ownership_error = TRUE
		for(var/trait in table_traits.traits)
			shared_ownership_error ||= HAS_TRAIT_FROM(location, trait, REF(moving_table))
		// Capture the failure first, then prevent a red fixture from retaining a deleted table.
		table_steps.vacate_turf(moving_table, location)
		table_traits.remove_from_occupied_turfs(location, moving_table)

	var/origin_error = turf_context_elevation_state_error(origin, elevation, FALSE)
	var/destination_error = turf_context_elevation_state_error(destination, elevation, FALSE)
	var/origin_has_source = HAS_TRAIT_FROM(origin, TRAIT_TURF_HAS_ELEVATED_OBJ(12), ref(moving_table))
	var/destination_has_source = HAS_TRAIT_FROM(destination, TRAIT_TURF_HAS_ELEVATED_OBJ(12), ref(moving_table))
	// Repair the old side even on failure so the regression cannot poison later fixtures.
	elevation.unregister_turf(moving_table, origin)
	if(!QDELETED(moving_table))
		Fail("The destination callback did not delete the entering table.", __FILE__, __LINE__)
	if(!remaining_owned || remaining_steps != 1 || remaining_traits != 1)
		Fail("Entry-time deletion disturbed the table remaining on the origin turf.", __FILE__, __LINE__)
	if(shared_ownership_error)
		Fail("Entry-time deletion left footstep or turf-trait ownership after the last table was deleted.", __FILE__, __LINE__)
	if(origin_error || origin_has_source)
		Fail("Entry-time deletion left old turf elevation ownership: [origin_error || "trait remained"].", __FILE__, __LINE__)
	if(destination_error || destination_has_source)
		Fail("Entry-time deletion left destination elevation ownership: [destination_error || "trait remained"].", __FILE__, __LINE__)

/datum/unit_test/turf_context_elevation_entered_deletion/proc/delete_entrant(turf/source, atom/movable/entrant)
	SIGNAL_HANDLER
	if(entrant == moving_table)
		qdel(entrant)

/**
 * Returns the carried table's shared turf-element registrations on a turf:
 * list(give_turf_traits target count, its handler, footstep_override target count, its handler).
 */
/proc/turf_context_shared_element_state(turf/target, datum/element/give_turf_traits/traits, datum/element/footstep_override/footstep)
	var/list/handlers = traits._signal_procs?[target]
	. = list(turf_context_elevation_listener_count(target, COMSIG_TURF_CHANGE, traits), handlers?[COMSIG_TURF_CHANGE])
	handlers = footstep._signal_procs?[target]
	. += list(turf_context_elevation_listener_count(target, COMSIG_TURF_PREPARE_STEP_SOUND, footstep), handlers?[COMSIG_TURF_PREPARE_STEP_SOUND])

/// Returns the number of registrations for one listener in a turf's target-side signal lookup.
/proc/turf_context_elevation_listener_count(turf/target, signal_type, datum/listener)
	var/list/listeners = target?._listen_lookup?[signal_type]
	if(isnull(listeners))
		return 0
	if(!islist(listeners))
		return listeners == listener
	var/count = 0
	for(var/datum/current_listener as anything in listeners)
		if(current_listener == listener)
			count++
	return count

/// Returns a diagnostic when elevation's target and listener-side metadata are inconsistent.
/proc/turf_context_elevation_state_error(turf/target, datum/element/elevation/elevation, expected)
	var/reset_count = turf_context_elevation_listener_count(target, COMSIG_TURF_RESET_ELEVATION, elevation)
	var/change_count = turf_context_elevation_listener_count(target, COMSIG_TURF_CHANGE, elevation)
	var/list/handlers = elevation?._signal_procs?[target]
	var/reset_handler = handlers?[COMSIG_TURF_RESET_ELEVATION]
	var/change_handler = handlers?[COMSIG_TURF_CHANGE]
	if(expected)
		if(reset_count != 1 || change_count != 1 || !reset_handler || !change_handler)
			return "expected reset=[reset_count]/change=[change_count] target listeners and listener handlers=[!!reset_handler]/[!!change_handler]"
		return null
	if(reset_count || change_count || reset_handler || change_handler)
		return "found stale reset=[reset_count]/change=[change_count] target listeners or listener handlers=[!!reset_handler]/[!!change_handler]"
	return null

/** Deletes the old decal during construction, before ChangeTurf restores saved listeners. */
/turf/open/floor/plating/turf_context_cleanup_test

/turf/open/floor/plating/turf_context_cleanup_test/Initialize(mapload)
	. = ..()
	for(var/obj/effect/decal/cleanable/blood/gibs/old/subscriber in contents)
		qdel(subscriber)

/** Replacing lava must retire its own trait-removal callback and retain external subscribers. */
/datum/unit_test/turf_context_lava_replacement
	/// Trait removals delivered to the external listener on the replacement floor.
	var/trait_callbacks = 0

/datum/unit_test/turf_context_lava_replacement/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/turf/lava = run_loc_floor_bottom_left.ChangeTurf(/turf/open/lava)
	var/signal = SIGNAL_REMOVETRAIT(TRAIT_LAVA_STOPPED)
	var/list/lava_handlers = lava._signal_procs?[lava]
	var/registered = lava_handlers?[signal]
	RegisterSignal(lava, signal, PROC_REF(on_trait_removed))
	var/turf/replacement = lava.ChangeTurf(original_type, original_baseturfs)
	var/self_listeners = turf_context_elevation_listener_count(replacement, signal, replacement)
	var/list/replacement_handlers = replacement._signal_procs?[replacement]
	var/stale_handler = replacement_handlers?[signal]
	// Retire only this fixture's recorded stale self-entry before exercising catwalk deletion.
	// A red assertion must not leave an invalid signal table for the following tests.
	if(self_listeners)
		var/list/lookup = replacement._listen_lookup
		var/list/listeners = lookup[signal]
		if(islist(listeners))
			var/list/survivors = listeners - replacement
			if(length(survivors) > 1)
				lookup[signal] = survivors
			else if(length(survivors))
				lookup[signal] = survivors[1]
			else
				lookup -= signal
		else
			lookup -= signal
	if(stale_handler)
		replacement_handlers -= signal
	var/obj/structure/lattice/catwalk/catwalk = new(replacement)
	qdel(catwalk)
	var/external_listeners = turf_context_elevation_listener_count(replacement, signal, src)
	UnregisterSignal(replacement, signal)
	if(!registered || self_listeners || stale_handler || external_listeners != 1 || trait_callbacks != 1)
		return Fail("Lava replacement signal mismatch: initial handler=[!!registered], stale self listeners=[self_listeners], stale handler=[!!stale_handler], external listeners=[external_listeners], callbacks=[trait_callbacks].", __FILE__, __LINE__)

/** Observes lava-stopping trait removal after the tile has become an ordinary floor. */
/datum/unit_test/turf_context_lava_replacement/proc/on_trait_removed(datum/source)
	SIGNAL_HANDLER
	trait_callbacks++

#endif
