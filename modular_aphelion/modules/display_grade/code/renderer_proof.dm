// This diagnostic is deliberately opt-in until DreamSeeker acceptance is complete.
#ifdef DISPLAY_GRADE_PROOF

/client
	var/datum/display_grade_proof/display_grade_proof

/client/verb/test_display_grade()
	set name = "Display Grade Renderer Proof"
	set category = "Debug"
	if(!check_rights(R_DEBUG))
		return
	if(display_grade_settings || display_grade_editor)
		to_chat(src, span_warning("Set Display grade to Off and close its editor before starting the renderer diagnostic."))
		return
	if(!display_grade_proof)
		display_grade_proof = new(src)
	display_grade_proof.ui_interact(mob)

/datum/display_grade_proof
	var/client/viewer
	var/mob/viewing_mob
	var/list/settings
	var/enabled = FALSE
	var/atom/movable/screen/plane_master/rendering_plate/master/master
	var/datum/plane_master_group/source_group
	var/datum/display_grade_renderer/renderer
	var/list/atom/movable/screen/display_grade_swatch/swatches = list()

/datum/display_grade_proof/New(client/viewer)
	src.viewer = viewer
	viewing_mob = viewer.mob
	settings = display_grade_reference()
	RegisterSignal(viewing_mob, COMSIG_MOB_LOGOUT, PROC_REF(stop_proof))

/datum/display_grade_proof/Destroy()
	clear_renderer()
	if(viewer)
		viewer.screen -= swatches
		viewer.display_grade_proof = null
	QDEL_LIST(swatches)
	viewer = null
	viewing_mob = null
	return ..()

/datum/display_grade_proof/proc/stop_proof()
	SIGNAL_HANDLER
	qdel(src)

/datum/display_grade_proof/ui_state(mob/user)
	return ADMIN_STATE(R_DEBUG)

/datum/display_grade_proof/ui_interact(mob/user, datum/tgui/ui)
	if(user.client != viewer)
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DisplayGradeProof", "Display grade renderer proof")
		ui.open()

/datum/display_grade_proof/ui_close(mob/user)
	qdel(src)

/datum/display_grade_proof/ui_data(mob/user)
	return list("settings" = settings, "enabled" = enabled, "resources" = length(renderer?.nodes))

/datum/display_grade_proof/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || ui.user.client != viewer)
		return
	switch(action)
		if("render")
			var/list/validated = display_grade_validate(params["settings"])
			if(!validated)
				return FALSE
			settings = validated
			clear_renderer()
			build_renderer()
		if("off")
			clear_renderer()
		else
			return FALSE
	return TRUE

/datum/display_grade_proof/proc/clear_renderer()
	enabled = FALSE
	QDEL_NULL(renderer)
	if(!QDELETED(master))
		UnregisterSignal(master, COMSIG_QDELETING)
	if(source_group)
		UnregisterSignal(source_group, list(COMSIG_PLANE_GROUP_OFFSET_CHANGED, COMSIG_PLANE_GROUP_PERSPECTIVE_CHANGED, COMSIG_PLANE_GROUP_HUD_CHANGED))
	source_group = null
	master = null

/// The diagnostic deliberately stops when its comparison scene changes.
/datum/display_grade_proof/proc/invalidate_renderer()
	SIGNAL_HANDLER
	clear_renderer()
	viewer.screen -= swatches
	QDEL_LIST(swatches)
	SStgui.update_uis(src)

/datum/display_grade_proof/proc/build_renderer()
	if(settings["strength"] == 0)
		return
	var/datum/plane_master_group/group = viewer.mob?.hud_used?.master_groups[PLANE_GROUP_MAIN]
	if(!group || group.active_offset != 0)
		to_chat(viewer, span_warning("Renderer proof requires the main map at plane offset zero."))
		return
	master = group.get_plane(RENDER_PLANE_MASTER)
	if(!master || length(master.relays))
		master = null
		return
	source_group = group
	viewer.display_grade_clear_native()
	renderer = new(viewer, master, settings)
	RegisterSignal(master, COMSIG_QDELETING, PROC_REF(invalidate_renderer))
	RegisterSignals(group, list(COMSIG_PLANE_GROUP_OFFSET_CHANGED, COMSIG_PLANE_GROUP_PERSPECTIVE_CHANGED, COMSIG_PLANE_GROUP_HUD_CHANGED), PROC_REF(invalidate_renderer))
	enabled = TRUE
	add_swatches()

/datum/display_grade_proof/proc/add_swatches()
	if(length(swatches))
		return
	var/list/colors = list("#000000", "#404040", "#808080", "#BFBFBF", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF", "#FFBF00", "#00FFFF", "#FF00FF")
	for(var/column in 1 to length(colors))
		for(var/row in 1 to 2)
			var/atom/movable/screen/display_grade_swatch/backdrop = new()
			backdrop.color = "#202020"
			backdrop.layer = 99
			backdrop.screen_loc = "[column],NORTH-[row - 1]"
			swatches += backdrop
			var/atom/movable/screen/display_grade_swatch/swatch = new()
			swatch.color = colors[column]
			swatch.alpha = row == 1 ? 255 : 128
			swatch.screen_loc = "[column],NORTH-[row - 1]"
			swatches += swatch
	viewer.screen += swatches

/atom/movable/screen/display_grade_swatch
	name = "display grade click target"
	plane = HUD_PLANE
	layer = 100
	mouse_opacity = MOUSE_OPACITY_OPAQUE

/atom/movable/screen/display_grade_swatch/Initialize(mapload)
	. = ..()
	var/static/icon/tile
	if(!tile)
		tile = icon('icons/blanks/32x32.dmi', "nothing")
		tile.DrawBox("#FFFFFF", 1, 1, 32, 32)
	icon = tile

/atom/movable/screen/display_grade_swatch/Click()
	to_chat(usr, span_notice("Display grade swatch click received."))

#endif
