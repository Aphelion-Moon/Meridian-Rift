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

#endif
