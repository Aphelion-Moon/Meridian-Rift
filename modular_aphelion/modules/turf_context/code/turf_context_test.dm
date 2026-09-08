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

/** Deletes the old decal during construction, before ChangeTurf restores saved listeners. */
/turf/open/floor/plating/turf_context_cleanup_test

/turf/open/floor/plating/turf_context_cleanup_test/Initialize(mapload)
	. = ..()
	for(var/obj/effect/decal/cleanable/blood/gibs/old/subscriber in contents)
		qdel(subscriber)

#endif
