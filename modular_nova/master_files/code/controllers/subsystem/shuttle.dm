/datum/controller/subsystem/shuttle
	/// Cargo weapon designs that were researched before supply_packs was built, flagged once it is.
	var/list/designs_awaiting_packs

/datum/controller/subsystem/shuttle/New()
	. = ..()
	RegisterSignal(src, COMSIG_SUBSYSTEM_POST_INITIALIZE, PROC_REF(flag_awaiting_designs))

/**
 * Flags the supply packs of cargo weapon designs that researched before we had a pack list to flag.
 *
 * The starting nodes config researches the whole techweb as the station techweb is created, during
 * SSresearch's init. That has to happen before SSatoms, because machines look the techweb up as they
 * initialise, and we only build supply_packs after SSatoms - so those designs find nothing to flag
 * and queue themselves on us instead.
 */
/datum/controller/subsystem/shuttle/proc/flag_awaiting_designs(datum/source)
	SIGNAL_HANDLER

	for(var/datum/design/cargo_weapon/design as anything in designs_awaiting_packs)
		design.on_station_research()
	designs_awaiting_packs = null
