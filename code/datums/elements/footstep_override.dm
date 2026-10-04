///When attached, the footstep sound played by the footstep element will be replaced by this one's
/datum/element/footstep_override
	element_flags = ELEMENT_BESPOKE|ELEMENT_DETACH_ON_HOST_DESTROY
	argument_hash_start_idx = 2
	///The sound played for movables with claw step sound type.
	var/clawfootstep
	///The sound played for movables with barefoot step sound type.
	var/barefootstep
	///The sound played for movables with heavy step sound type.
	var/heavyfootstep
	///The sound played for movables with shoed step sound type.
	var/footstep
	///The priority this element has in relation to other elements of the same type attached to other movables on the same turf.
	var/priority
	/**
	 * A list of turfs occupied by the movables this element is attached to.
	 * Needed so it stops listening the turf's signals ONLY when it has no movable with the element.
	 */
	var/list/occupied_turfs = list()

/datum/element/footstep_override/Attach(atom/movable/target, clawfootstep = FOOTSTEP_HARD_CLAW, barefootstep = FOOTSTEP_HARD_BAREFOOT, heavyfootstep = FOOTSTEP_GENERIC_HEAVY, footstep = FOOTSTEP_FLOOR, priority = STEP_SOUND_NO_PRIORITY)
	. = ..()
	if(!ismovable(target))
		return ELEMENT_INCOMPATIBLE

	src.clawfootstep = clawfootstep
	src.barefootstep = barefootstep
	src.heavyfootstep = heavyfootstep
	src.footstep = footstep
	src.priority = priority

	RegisterSignal(target, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	// APHELION EDIT ADDITION START - TURF_CONTEXT
	RegisterSignal(target, COMSIG_ATOM_EXITING, PROC_REF(on_exiting))
	// APHELION EDIT ADDITION END
	if(isturf(target.loc))
		occupy_turf(target, target.loc)

/datum/element/footstep_override/Detach(atom/movable/source)
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)
	// APHELION EDIT ADDITION START - TURF_CONTEXT
	UnregisterSignal(source, COMSIG_ATOM_EXITING)
	// APHELION EDIT ADDITION END
	if(isturf(source.loc))
		vacate_turf(source, source.loc)
	return ..()

/datum/element/footstep_override/proc/on_moved(atom/movable/source, atom/oldloc)
	SIGNAL_HANDLER
	if(isturf(oldloc))
		vacate_turf(source, oldloc)
	if(isturf(source.loc))
		occupy_turf(source, source.loc)

// APHELION EDIT ADDITION START - TURF_CONTEXT
/// Entered() can delete the source before Moved(), so release the old turf on exit.
/datum/element/footstep_override/proc/on_exiting(atom/movable/source, atom/exiting)
	SIGNAL_HANDLER
	if(isturf(exiting))
		vacate_turf(source, exiting)
// APHELION EDIT ADDITION END

/**
 * Adds the movable to the list of movables with the element occupying the turf.
 * If the turf was not on the list of occupied turfs before, a signal will be registered
 * to it.
 */
/datum/element/footstep_override/proc/occupy_turf(atom/movable/movable, turf/location)
	if(occupied_turfs[location])
		occupied_turfs[location] |= movable
		return
	occupied_turfs[location] = list(movable)
	RegisterSignal(location, COMSIG_TURF_PREPARE_STEP_SOUND, PROC_REF(prepare_steps))

/**
 * Removes the movable from the list of movables with the element occupying the turf.
 * If the turf is no longer occupied, it'll be removed from the list, and the signal
 * unregistered from it
 */
/datum/element/footstep_override/proc/vacate_turf(atom/movable/movable, turf/location)
	// APHELION EDIT ADDITION START - TURF_CONTEXT
	if(!(movable in occupied_turfs[location]))
		return
	// APHELION EDIT ADDITION END
	LAZYREMOVE(occupied_turfs[location], movable)
	if(!occupied_turfs[location])
		occupied_turfs -= location
		UnregisterSignal(location, COMSIG_TURF_PREPARE_STEP_SOUND)

///Changes the sound types to be played if the element priority is higher than the one in the steps list.
/datum/element/footstep_override/proc/prepare_steps(turf/source, list/steps)
	SIGNAL_HANDLER
	if(steps[STEP_SOUND_PRIORITY] > priority)
		return
	steps[FOOTSTEP_MOB_SHOE] = footstep
	steps[FOOTSTEP_MOB_BAREFOOT] = barefootstep
	steps[FOOTSTEP_MOB_HEAVY] = heavyfootstep
	steps[FOOTSTEP_MOB_CLAW] = clawfootstep
	steps[STEP_SOUND_PRIORITY] = priority
	return FOOTSTEP_OVERRIDEN
