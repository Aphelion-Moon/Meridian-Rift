/// The character preview shows a floating selection where it would drop, before any paint is written.
/datum/custom_sprite_editor
	/// At most one bounded compact selection placement, waiting for the ordinary preview debounce.
	var/list/selection_request
	/// Temporary preview-only frames: every view of selection_layer, the placement on one. The workspace, history, saves and exports never read these.
	var/list/selection_frames
	/// The layer selection_frames stand in for.
	var/selection_layer = 1

/// Floating paint is previewed at the end of a gesture; no pointer moves or unvalidated pixels reach the renderer.
/datum/custom_sprite_editor/proc/queue_selection_preview(list/transaction)
	if(isnull(transaction))
		return clear_selection_preview(schedule = TRUE)
	if(!resources_ready || !islist(transaction) || transaction["dir"] != visible_direction)
		return FALSE
	var/list/area = transaction["area"]
	var/list/palette = transaction["palette"]
	var/codes = transaction["codes"]
	var/pixels = workspace.width * workspace.height
	// Cheap envelope limits before retaining anything. Full placement/color/layer/lock validation runs after the burst settles.
	if(!islist(area) || length(area) != 4 || !islist(palette) || !length(palette) || length(palette) > pixels || !istext(codes) || length(codes) > pixels * 2 || !(transaction["digits"] in list(1, 2)))
		return FALSE
	selection_request = list("type" = "move", "layer" = transaction["layer"], "layerId" = transaction["layerId"], "dir" = transaction["dir"], "area" = area, "palette" = palette, "digits" = transaction["digits"], "codes" = codes)
	if(!isnull(transaction["baseCopy"]))
		selection_request["baseCopy"] = transaction["baseCopy"]
		selection_request["baseCopySource"] = transaction["baseCopySource"]
	preview_timer = addtimer(CALLBACK(src, PROC_REF(request_refresh)), 0.6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_STOPPABLE)
	return TRUE

/// Drops the temporary picture on cancellation, a new gesture, a draft edit or changed body, view or region locks.
/datum/custom_sprite_editor/proc/clear_selection_preview(schedule = FALSE)
	if(!selection_request && !selection_frames)
		return FALSE
	selection_request = null
	selection_frames = null
	if(schedule)
		preview_timer = addtimer(CALLBACK(src, PROC_REF(request_refresh)), 0.6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_STOPPABLE)
	return TRUE

/// Checks exactly the placement a real drop would accept, on the layer it names, but writes only a copy of that one view.
/datum/custom_sprite_editor/proc/apply_selection_preview()
	if(!selection_request)
		return
	// Clothing or mirror access may have changed since this request entered the debounce.
	sync_locked_views(push = FALSE)
	if(!selection_request || (selection_request["dir"] in locked_directions()))
		clear_selection_preview()
		return
	var/list/transaction = selection_request
	selection_request = null
	selection_frames = null
	var/list/old_palette = workspace.palette
	var/trusted_copy = !isnull(transaction["baseCopy"])
	var/allowed = workspace.stroke_layer_matches(transaction) && (!trusted_copy || prepare_base_copy_paste(transaction)) && workspace.can_transact(transaction)
	if(trusted_copy)
		workspace.palette = old_palette
	if(!allowed)
		return
	var/direction = transaction["dir"]
	selection_layer = transaction["layer"]
	var/list/frames = workspace.layers[selection_layer]["data"]
	selection_frames = frames.Copy()
	var/list/frame = deep_copy_list(selection_frames[direction])
	selection_frames[direction] = frame
	for(var/list/point as anything in transaction["points"])
		frame[point[2] + 1][point[1] + 1] = point[4]
