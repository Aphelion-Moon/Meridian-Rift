/datum/controller/subsystem/condos
	/// Prevents new preview map loads once dependent subsystems begin shutting down.
	var/previews_shutting_down = FALSE
	/// Photographs that may still be suspended in map loading, rendering or reservation release.
	var/active_preview_renders = 0

/** Finishes owned map work before Mapping, Atoms and Dogmos release their state. */
/datum/controller/subsystem/condos/Shutdown()
	stop_preview_renders()
	return ..()

/** Called before Master stops scheduling so in-flight reservations can finish using Mapping.fire. */
/datum/controller/subsystem/condos/proc/stop_preview_renders()
	previews_shutting_down = TRUE
	while(active_preview_renders)
		sleep(world.tick_lag)

/** Tracks both startup and admin-upload photographs across their yielding map operations. */
/datum/controller/subsystem/condos/proc/photograph_interior(datum/map_template/condo/chosen)
	// Reservation wiping needs Mapping.fire, which cannot run once Master shuts down.
	// Wait outside the owned render so shutdown can cancel this admission instead of joining it.
	while(SSmapping.clearing_reserved_turfs && !previews_shutting_down)
		sleep(world.tick_lag)
	if(previews_shutting_down)
		return null
	active_preview_renders++
	try
		. = render_interior(chosen)
	catch(var/exception/error)
		active_preview_renders--
		throw error
	active_preview_renders--
	if(previews_shutting_down)
		return null
