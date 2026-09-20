/client
	var/list/display_grade_renderers = list()

/client/proc/display_grade_clear_native()
	for(var/master in display_grade_renderers.Copy())
		qdel(display_grade_renderers[master])

/client/proc/display_grade_clear_group(datum/plane_master_group/group)
	for(var/atom/movable/screen/plane_master/master as anything in display_grade_renderers.Copy())
		if(master.home == group)
			qdel(display_grade_renderers[master])

/client/proc/display_grade_attach(atom/movable/screen/plane_master/rendering_plate/master/master)
	if(display_grade_renderers[master] || !display_grade_settings || master.home?.display_grade_changing)
		return
	// Relaying masters are inputs to another floor. Only the displayed endpoint is graded.
	if(!(master in screen) || length(master.relays) || master.offset != master.home?.active_offset)
		return
	display_grade_renderers[master] = new /datum/display_grade_renderer(src, master, display_grade_settings)

/client/proc/display_grade_refresh_native()
	display_grade_clear_native()
	if(!display_grade_settings || QDELING(src))
		return
	for(var/atom/movable/screen/plane_master/rendering_plate/master/master in screen)
		display_grade_attach(master)

/atom/movable/screen/plane_master/rendering_plate/master/show_to(mob/mymob)
	. = ..()
	var/client/viewer = mymob?.canon_client
	if(. && istype(viewer))
		viewer.display_grade_attach(src)

/atom/movable/screen/plane_master/rendering_plate/master/hide_from(mob/oldmob)
	var/client/viewer = oldmob?.canon_client
	if(istype(viewer) && viewer.display_grade_renderers[src])
		qdel(viewer.display_grade_renderers[src])
	return ..()

/datum/plane_master_group
	var/display_grade_changing = FALSE

/// Restore targets before the floor relay code changes them or copies them into new relays.
/datum/plane_master_group/proc/display_grade_before_offset()
	display_grade_changing = TRUE
	var/client/viewer = our_hud?.mymob?.canon_client
	if(istype(viewer))
		viewer.display_grade_clear_group(src)

/datum/plane_master_group/proc/display_grade_after_offset()
	display_grade_changing = FALSE
	var/client/viewer = our_hud?.mymob?.canon_client
	if(!istype(viewer) || !viewer.display_grade_settings)
		return
	for(var/key in plane_masters)
		var/atom/movable/screen/plane_master/master = plane_masters[key]
		if(istype(master, /atom/movable/screen/plane_master/rendering_plate/master))
			viewer.display_grade_attach(master)
