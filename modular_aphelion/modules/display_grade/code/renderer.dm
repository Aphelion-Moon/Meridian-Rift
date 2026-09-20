/// One fixed graph for one displayed master, owned by one client.
/datum/display_grade_renderer
	var/client/viewer
	var/atom/movable/screen/plane_master/rendering_plate/master/master
	var/list/settings
	var/old_target
	var/source_target
	var/list/atom/movable/render_plane_relay/nodes = list()

/datum/display_grade_renderer/New(client/viewer, atom/movable/screen/plane_master/rendering_plate/master/master, list/settings)
	src.viewer = viewer
	src.master = master
	src.settings = settings.Copy()
	old_target = master.render_target
	source_target = "*aphelion_display_grade_[REF(src)]_source"
	master.render_target = source_target
	RegisterSignal(master, COMSIG_QDELETING, PROC_REF(master_deleted))
	build_renderer()

/datum/display_grade_renderer/Destroy()
	if(viewer)
		viewer.screen -= nodes
		viewer.display_grade_renderers -= master
	QDEL_LIST(nodes)
	if(!QDELETED(master) && master.render_target == source_target)
		master.render_target = old_target
	master = null
	viewer = null
	return ..()

/datum/display_grade_renderer/proc/master_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/display_grade_renderer/proc/node(label, source)
	var/atom/movable/render_plane_relay/result = new()
	result.name = "Aphelion display grade: [label]"
	result.screen_loc = master.home.map ? "[master.home.map]:[master.home.relay_loc]" : master.home.relay_loc
	// A separate endpoint plane keeps the output out of its own input texture.
	// Above every floor's master. Offsetting +1 would collide with the next floor's lowest planes.
	result.plane = RENDER_PLANE_MASTER + 1
	result.layer = 1
	result.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	result.render_source = source
	result.render_target = "*aphelion_display_grade_[REF(src)]_[label]"
	nodes += result
	viewer.screen += result
	return result

/// RGB scale/bias with an explicitly opaque output. Source alpha is restored only at the endpoint.
/proc/display_grade_opaque_matrix(scale, red = 0, green = 0, blue = 0)
	return list(scale,0,0,0, 0,scale,0,0, 0,0,scale,0, 0,0,0,0, red,green,blue,1)

/proc/display_grade_weight_matrix(slope, bias)
	return list(
		0.2126*slope,0.2126*slope,0.2126*slope,0,
		0.7152*slope,0.7152*slope,0.7152*slope,0,
		0.0722*slope,0.0722*slope,0.0722*slope,0,
		0,0,0,0, bias,bias,bias,1,
	)

/datum/display_grade_renderer/proc/build_renderer()
	var/atom/movable/render_plane_relay/original = node("opaque", source_target)
	original.add_filter("aphelion-grade-opaque", 1, color_matrix_filter(display_grade_opaque_matrix(1)))
	var/atom/movable/render_plane_relay/adjusted = node("adjusted", original.render_target)
	adjusted.add_filter("aphelion-grade-adjust", 1, color_matrix_filter(display_grade_adjustment_matrix(settings)))
	var/atom/movable/render_plane_relay/shadow = node("shadow-mask", adjusted.render_target)
	shadow.add_filter("aphelion-grade-shadow-mask", 1, color_matrix_filter(display_grade_weight_matrix(-2, 1)))
	var/atom/movable/render_plane_relay/highlight = node("highlight-mask", adjusted.render_target)
	highlight.add_filter("aphelion-grade-highlight-mask", 1, color_matrix_filter(display_grade_weight_matrix(2, -1)))
	var/atom/movable/render_plane_relay/midtone = node("midtone-mask", adjusted.render_target)
	midtone.add_filter("aphelion-grade-mid-white", 1, color_matrix_filter(display_grade_opaque_matrix(0, 1, 1, 1)))
	midtone.add_filter("aphelion-grade-mid-shadow", 2, layering_filter(render_source = shadow.render_target, blend_mode = BLEND_SUBTRACT))
	midtone.add_filter("aphelion-grade-mid-highlight", 3, layering_filter(render_source = highlight.render_target, blend_mode = BLEND_SUBTRACT))
	var/list/masks = list("shadow" = shadow, "midtone" = midtone, "highlight" = highlight)
	var/list/branches = list()
	for(var/band in masks)
		var/atom/movable/render_plane_relay/mask = masks[band]
		var/atom/movable/render_plane_relay/branch = node(band, adjusted.render_target)
		var/list/tint = rgb2num(settings["[band]_color"])
		var/strength = settings["[band]_strength"]
		branch.add_filter("aphelion-grade-tint-[band]", 1, color_matrix_filter(display_grade_opaque_matrix(1 - strength, tint[1]/255*strength, tint[2]/255*strength, tint[3]/255*strength)))
		branch.add_filter("aphelion-grade-weight-[band]", 2, layering_filter(render_source = mask.render_target, blend_mode = BLEND_MULTIPLY))
		branches += branch

	// Add opaque, weighted RGB contributions; never OVER the three translucent bands.
	var/atom/movable/render_plane_relay/output = node("output", source_target)
	output.add_filter("aphelion-grade-original", 1, color_matrix_filter(display_grade_opaque_matrix(1 - settings["strength"])))
	var/priority = 2
	for(var/atom/movable/render_plane_relay/branch as anything in branches)
		output.add_filter("aphelion-grade-add-[priority]", priority++, layering_filter(render_source = branch.render_target, color = display_grade_opaque_matrix(settings["strength"]), blend_mode = BLEND_ADD))
	output.add_filter("aphelion-grade-alpha", priority, alpha_mask_filter(render_source = source_target))
	output.render_target = null
	output.mouse_opacity = master.mouse_opacity
	// PASS_MOUSE on the original render source keeps the existing hit map available.
