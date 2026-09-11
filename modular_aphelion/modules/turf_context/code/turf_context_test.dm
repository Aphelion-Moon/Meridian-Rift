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

// APHELION EDIT ADDITION START - TURF_CONTEXT
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

	var/turf/fixture_turf = reservation.bottom_left_turfs[1]
	var/fixture_x = fixture_turf.x
	var/fixture_y = fixture_turf.y
	var/fixture_z = fixture_turf.z
	RegisterSignal(fixture_turf, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))

	var/turf/loaded_turf = fixture_turf.load_on_top(/turf/open/floor/wood)
	var/obj/structure/table/wood/first_table = new(loaded_turf)
	var/datum/element/elevation/elevation = SSdcs.GetElement(list(/datum/element/elevation, "pixel_shift" = 12), FALSE)
	var/failure
	var/state_error = turf_context_elevation_state_error(loaded_turf, elevation, TRUE)
	if(!first_table || state_error)
		failure = "Initial load_on_top table did not register one elevation listener per signal: [state_error || "table was not created"]."

	loaded_turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, TRUE)
	fixture_turf = locate(fixture_x, fixture_y, fixture_z)
	state_error = turf_context_elevation_state_error(fixture_turf, elevation, FALSE)
	if(!QDELETED(first_table) || state_error)
		failure ||= "First empty did not delete the table and clear its elevation listeners: [state_error || "table remained live"]."

	loaded_turf = fixture_turf.load_on_top(/turf/open/floor/wood)
	var/obj/structure/table/wood/second_table = new(loaded_turf)
	state_error = turf_context_elevation_state_error(loaded_turf, elevation, TRUE)
	if(!second_table || state_error)
		failure ||= "Reloaded table did not register one elevation listener per signal: [state_error || "table was not created"]."

	if(second_table)
		qdel(second_table)
	if(loaded_turf)
		loaded_turf.empty(RESERVED_TURF_TYPE, RESERVED_TURF_TYPE, null, TRUE)
	fixture_turf = locate(fixture_x, fixture_y, fixture_z)
	state_error = turf_context_elevation_state_error(fixture_turf, elevation, FALSE)
	if(state_error)
		failure ||= "Final empty left stale elevation listeners: [state_error]."
	if(turf_context_elevation_listener_count(fixture_turf, COMSIG_TURF_CHANGE, src) != 1 || change_callbacks < 4)
		failure ||= "The external turf-change listener was not retained through both table cycles and final cleanup."
	UnregisterSignal(fixture_turf, COMSIG_TURF_CHANGE)
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
	for(var/obj/structure/table/wood/carried_table in contents)
		qdel(carried_table)

/** Constructor-time deletion must not leave a stale elevation callback on the replacement turf. */
/datum/unit_test/turf_context_elevation_constructor
	/// Number of retained external listeners delivered by both turf changes.
	var/change_callbacks = 0

/datum/unit_test/turf_context_elevation_constructor/Run()
	var/original_type = run_loc_floor_bottom_left.type
	var/original_baseturfs = run_loc_floor_bottom_left.baseturfs
	var/turf/fixture_turf = run_loc_floor_bottom_left.ChangeTurf(/turf/open/floor/plating)
	RegisterSignal(fixture_turf, COMSIG_TURF_CHANGE, PROC_REF(on_turf_change))
	var/obj/structure/table/wood/carried_table = new(fixture_turf)
	var/datum/element/give_turf_traits/table_traits_element = SSdcs.GetElement(
		list(/datum/element/give_turf_traits, carried_table.turf_traits),
		FALSE,
	)
	var/datum/element/footstep_override/table_footstep_element = SSdcs.GetElement(
		list(/datum/element/footstep_override, "priority" = STEP_SOUND_TABLE_PRIORITY),
		FALSE,
	)
	var/turf/replacement = fixture_turf.ChangeTurf(/turf/open/floor/plating/turf_context_elevation_constructor_test)
	var/datum/element/elevation/elevation = SSdcs.GetElement(list(/datum/element/elevation, "pixel_shift" = 12), FALSE)
	var/failure
	var/state_error = turf_context_elevation_state_error(replacement, elevation, FALSE)
	if(!QDELETED(carried_table))
		failure = "Constructor fixture did not delete the carried elevating table."
	if(state_error)
		failure ||= "Constructor-time deletion left stale elevation listeners on the replacement turf: [state_error]."
	if(!table_traits_element || !table_footstep_element)
		failure ||= "Constructor fixture could not resolve the carried table's shared turf elements."
	else
		var/list/traits_handlers = table_traits_element._signal_procs?[replacement]
		var/list/footstep_handlers = table_footstep_element._signal_procs?[replacement]
		var/traits_target_count = turf_context_elevation_listener_count(replacement, COMSIG_TURF_CHANGE, table_traits_element)
		var/footstep_target_count = turf_context_elevation_listener_count(replacement, COMSIG_TURF_PREPARE_STEP_SOUND, table_footstep_element)
		var/traits_handler = traits_handlers?[COMSIG_TURF_CHANGE]
		var/footstep_handler = footstep_handlers?[COMSIG_TURF_PREPARE_STEP_SOUND]
		if(traits_target_count || traits_handler || footstep_target_count || footstep_handler)
			failure ||= "Constructor-time deletion left shared turf-element registrations: give_turf_traits target=[traits_target_count] handler=[!!traits_handler], footstep_override target=[footstep_target_count] handler=[!!footstep_handler]."

	var/obj/structure/table/wood/reloaded_table = new(replacement)
	state_error = turf_context_elevation_state_error(replacement, elevation, TRUE)
	if(!reloaded_table || state_error)
		failure ||= "A table reloaded after constructor-time deletion did not register one elevation listener per signal: [state_error || "table was not created"]."
	if(table_traits_element && table_footstep_element)
		var/list/reloaded_traits_handlers = table_traits_element._signal_procs?[replacement]
		var/list/reloaded_footstep_handlers = table_footstep_element._signal_procs?[replacement]
		var/reloaded_traits_target_count = turf_context_elevation_listener_count(replacement, COMSIG_TURF_CHANGE, table_traits_element)
		var/reloaded_footstep_target_count = turf_context_elevation_listener_count(replacement, COMSIG_TURF_PREPARE_STEP_SOUND, table_footstep_element)
		var/reloaded_traits_handler = reloaded_traits_handlers?[COMSIG_TURF_CHANGE]
		var/reloaded_footstep_handler = reloaded_footstep_handlers?[COMSIG_TURF_PREPARE_STEP_SOUND]
		if(reloaded_traits_target_count != 1 || !reloaded_traits_handler || reloaded_footstep_target_count != 1 || !reloaded_footstep_handler)
			failure ||= "Reloaded table did not restore one shared turf-element registration per signal: give_turf_traits target=[reloaded_traits_target_count] handler=[!!reloaded_traits_handler], footstep_override target=[reloaded_footstep_target_count] handler=[!!reloaded_footstep_handler]."

	if(reloaded_table)
		qdel(reloaded_table)
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
// APHELION EDIT ADDITION END - TURF_CONTEXT

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
