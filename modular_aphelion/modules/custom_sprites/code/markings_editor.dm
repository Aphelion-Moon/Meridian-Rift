/**
 * The whole-body markings editor in character setup.
 *
 * One canvas covers every region of the body. Each pixel belongs to one region, and saving writes
 * each changed region into its own per-limb drawing, exactly as the per-limb editors stored them.
 * Regions nobody edited aren't written at all.
 */
/datum/custom_sprite_editor/markings
	/// Zone -> each region's drawing as saved when the draft opened or was last saved.
	var/list/saved_drawings
	/// Zone -> decoded pixels of saved_drawings, reused read-only by every split.
	var/list/saved_pixels
	/// Zone -> native marking records as saved, for regions that have native markings.
	var/list/saved_markings
	/// Direction -> the canvas as it stood when the draft opened or was last saved.
	var/list/baseline
	/// Direction -> row strings naming the region that owns each pixel.
	var/list/region_map
	/// Regions in draw order. A region map character N means region_zones[N].
	var/list/region_zones
	/// The region that region-specific actions act on.
	var/selected_zone
	/// Bumped when character setup moves the selection, so the open window follows.
	var/focus_revision = 0
	/// region_results() for the draft state in results_revision.
	var/list/results_cache
	/// Which draft state results_cache belongs to.
	var/results_revision
	/// locked_regions() as apply_region_locks() last worked it out, which the canvas enforces.
	var/list/lock_reasons

/datum/custom_sprite_editor/markings/New(datum/preferences/preferences, focus_zone)
	..(preferences, "markings")
	focus_region(focus_zone)

/// The canvas is composed from every region's save instead of one package.
/datum/custom_sprite_editor/markings/initial_package()
	return list()

/datum/custom_sprite_editor/markings/create_workspace(list/package)
	build_region_map()
	load_saved_state()
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = new(null, list(), null, null, region_width())
	canvas.region_map = region_map
	canvas.tint = "#ffffff"
	canvas.load_frames(custom_sprite_compose_regions(saved_drawings, region_map, region_zones, canvas.width))
	var/list/markings = list()
	for(var/zone, entries in saved_markings)
		markings[zone] = custom_style_copy_markings(entries)
	canvas.markings_context = markings
	var/list/emissive = list()
	for(var/zone in region_zones)
		emissive[zone] = custom_sprite_emissive_settings(saved_drawings[zone]?["emissive"])
	canvas.emissive = emissive
	baseline = deep_copy_list(canvas.layers[1]["data"])
	return canvas

/// Reads what every region is measured against: the reference for spotting changes.
/datum/custom_sprite_editor/markings/proc/load_saved_state()
	var/list/references = reference_packages()
	saved_drawings = list()
	saved_pixels = list()
	for(var/zone, reference in references)
		var/list/drawing = reference["drawing"]
		if(!drawing)
			continue
		saved_drawings[zone] = deep_copy_list(drawing)
		saved_pixels[zone] = custom_sprite_drawing_pixels(drawing, custom_marking_zone_width(zone))
	saved_markings = list()
	for(var/zone in region_zones)
		if(zone in GLOB.body_markings_per_limb)
			saved_markings[zone] = custom_style_copy_markings(references[zone]?["markings"])
	results_cache = null

/**
 * Context hook: zone -> the package each region is measured against, for every marking zone.
 *
 * Character setup measures against the character's saved drawings and base markings.
 */
/datum/custom_sprite_editor/markings/proc/reference_packages()
	preferences.load_custom_sprites()
	. = list()
	for(var/zone in GLOB.custom_marking_zone_labels)
		.[zone] = preferences.custom_style_saved_package("markings", zone)

/// Context hook: zone -> why that region can't be changed right now. Character setup locks nothing.
/datum/custom_sprite_editor/markings/proc/locked_regions()
	return list()

/**
 * Rebuilds which region owns each pixel from the preview body.
 *
 * A changed map drops results worked out on the old one. A region that appeared since the draft
 * opened gets its saved emission and base markings. A context whose map doesn't follow the body
 * keeps the first one.
 */
/datum/custom_sprite_editor/markings/proc/build_region_map()
	// Body changes then only lock regions, through locked_regions().
	if(region_map && !map_follows_body())
		return
	var/list/old_map = region_map
	region_zones = custom_sprite_present_regions(preview_body)
	region_map = custom_sprite_region_map(preview_body, region_zones, region_width())
	if(region_map != old_map)
		results_cache = null
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	if(!canvas)
		return
	var/list/emissive = canvas.emissive.Copy()
	var/list/markings = canvas.markings_context.Copy()
	var/list/references
	for(var/zone in region_zones)
		if(!emissive[zone])
			emissive[zone] = custom_sprite_emissive_settings(saved_drawings?[zone]?["emissive"])
		if(!(zone in markings) && (zone in GLOB.body_markings_per_limb))
			references ||= reference_packages()
			saved_markings[zone] = custom_style_copy_markings(references[zone]?["markings"])
			markings[zone] = custom_style_copy_markings(saved_markings[zone])
	canvas.emissive = emissive
	canvas.markings_context = markings

/// A taur organ widens the canvas, even while hidden, so it doesn't change size.
/datum/custom_sprite_editor/markings/proc/region_width()
	return custom_sprite_taur_overlay(preview_body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/// Context hook: whether the region map follows the preview body after the draft opens. The salon keeps its first map, so paint never changes region.
/datum/custom_sprite_editor/markings/proc/map_follows_body()
	return TRUE

/datum/custom_sprite_editor/markings/update_draw_area()
	build_region_map()
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	canvas.region_map = region_map
	// Bounds cover every region, locked or not; the mask decides what can be painted.
	workspace.draw_bounds = custom_sprite_mask_bounds(custom_sprite_region_mask(region_map), workspace.width)
	canvas.locked = null
	apply_region_locks()

/**
 * Keeps locked regions out of the paintable mask, so the canvas shades them and every tool refuses them.
 *
 * Locks can change while the window is open, such as when clothing goes on, so this also runs
 * whenever the view locks are synced.
 *
 * Returns TRUE when the locks changed.
 */
/datum/custom_sprite_editor/markings/proc/apply_region_locks()
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	var/list/reasons = locked_regions()
	lock_reasons = reasons
	var/list/locked = list()
	for(var/index in 1 to length(region_zones))
		if(reasons[region_zones[index]])
			locked += "[index]"
	if(canvas.locked && compare_list(canvas.locked, locked))
		return FALSE
	canvas.locked = locked
	canvas.draw_mask = custom_sprite_region_mask(region_map, locked)
	static_dirty = TRUE
	return TRUE

/// Zone -> why it's locked, as the canvas enforces it. Worked out afresh only while the canvas isn't built.
/datum/custom_sprite_editor/markings/proc/current_locks()
	return resources_ready ? lock_reasons : locked_regions()

/datum/custom_sprite_editor/markings/sync_locked_views(push = TRUE)
	var/regions_changed = resources_ready && apply_region_locks()
	var/views_changed = ..(FALSE)
	if(push && (regions_changed || views_changed))
		push()
	return regions_changed || views_changed

/datum/custom_sprite_editor/markings/apply_draft_base_markings()
	for(var/zone, entries in workspace.markings_context)
		custom_style_apply_base_markings(preview_body, zone, entries, emissives_allowed())
	preview_body.update_body()

/**
 * Selects a region from outside the window, such as a limb's Custom button.
 *
 * A region this body doesn't have, or one that's locked, keeps the current selection and says why.
 * With nothing usable selected, the torso is picked, or else the first region that isn't locked.
 * When every region is locked one is still selected, so the window can name it and say why.
 */
/datum/custom_sprite_editor/markings/proc/focus_region(zone)
	var/list/locked = locked_regions()
	if((zone in region_zones) && !(zone in locked))
		selected_zone = zone
	else
		if(zone in locked)
			transfer_notice = locked[zone]
		else if(zone in GLOB.custom_marking_zone_labels)
			transfer_notice = "This body has no [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] right now."
		if(!(selected_zone in region_zones) || (selected_zone in locked))
			var/list/available = region_zones - locked
			if(!length(available))
				available = region_zones
			selected_zone = (BODY_ZONE_CHEST in available) ? BODY_ZONE_CHEST : (length(available) ? available[1] : null)
	focus_revision++
	push()

/**
 * What saving would write for every region right now, cached per draft state.
 *
 * Returns zone -> list("drawing", "markings", "changed", "error"). `markings` is null for regions
 * without native markings, such as the taur.
 */
/datum/custom_sprite_editor/markings/proc/region_results()
	var/revision = "[draft_revision]|[save_revision]|[length(workspace.undo_stack)]|[length(workspace.redo_stack)]"
	if(results_cache && results_revision == revision)
		return results_cache
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	var/list/split = custom_sprite_split_regions(canvas.layers[1]["data"], baseline, saved_drawings, region_map, region_zones, canvas.width, saved_pixels, canvas.resets)
	. = list()
	for(var/zone, entry in split)
		var/list/drawing = entry["drawing"]
		var/changed = entry["changed"]
		var/list/emissive = workspace.emissive[zone]
		if(drawing && emissive && json_encode(custom_sprite_emissive_settings(drawing["emissive"])) != json_encode(emissive))
			drawing = drawing.Copy()
			drawing["emissive"] = emissive.Copy()
			changed = TRUE
		var/list/markings = workspace.markings_context[zone]
		if(!isnull(markings) && json_encode(markings) != json_encode(saved_markings[zone]))
			changed = TRUE
		.[zone] = list("drawing" = drawing, "markings" = markings, "changed" = changed, "error" = entry["error"])
	results_cache = .
	results_revision = revision

/// One region's would-be-saved package.
/datum/custom_sprite_editor/markings/proc/region_package(zone, list/results)
	return custom_style_package("markings", zone, results[zone]?["drawing"], null, results[zone]?["markings"])

/// Every present region's would-be-saved package, zone -> package, as a whole-body export holds them.
/datum/custom_sprite_editor/markings/proc/body_packages()
	. = list()
	var/list/results = region_results()
	for(var/zone in region_zones)
		.[zone] = region_package(zone, results)

/datum/custom_sprite_editor/markings/current_package()
	return region_package(selected_zone, region_results())

/// Saves every changed region in one write. Untouched regions aren't written.
/datum/custom_sprite_editor/markings/save_drawing()
	var/list/results = region_results()
	var/list/packages = list()
	var/list/rotate_keys = list()
	var/list/rotations = workspace.unsaved_rotations()
	for(var/zone, result in results)
		if(!result["changed"])
			continue
		if(result["error"])
			save_error = "[GLOB.custom_marking_zone_labels[zone]] [result["error"]] Your drawing is kept in this session. Press Ctrl+S to retry."
			push()
			return FALSE
		packages += list(region_package(zone, results))
		if(zone in rotations)
			rotate_keys += custom_style_key("markings", zone)
	if(length(packages))
		var/error = preferences.commit_custom_styles(packages, slot, rotate_keys)
		if(error)
			save_error = "[error] Your drawing is kept in this session. Press Ctrl+S to retry."
			push()
			return FALSE
	mark_saved()
	update_restorable()
	save_error = null
	save_revision++
	return TRUE

/// The saved canvas becomes the reference for the next save.
/datum/custom_sprite_editor/markings/proc/mark_saved()
	load_saved_state()
	baseline = deep_copy_list(workspace.layers[1]["data"])
	workspace.mark_saved()

/datum/custom_sprite_editor/markings/refresh_preview(push = TRUE)
	preview_timer = null
	if(closing || !resources_ready)
		return
	if(refresh_composed_previews(push))
		return
	var/list/results = region_results()
	update_restorable()
	var/new_hash = md5(json_encode(results))
	if(preview_hash == new_hash)
		return
	adopt_preview(capture_region_previews(results), new_hash, push)

/// Puts exactly what saving would write on the preview body and captures its look. A region too colorful to save shows its saved paint.
/datum/custom_sprite_editor/markings/proc/capture_region_previews(list/results)
	var/list/shown = results.Copy()
	for(var/zone, entry_untyped in results)
		var/list/entry = entry_untyped
		if(entry["error"])
			entry = entry.Copy()
			entry["drawing"] = saved_drawings[zone]
			shown[zone] = entry
	custom_sprite_apply_region_results(preview_body, shown, emissives_allowed())
	return custom_sprite_preview_appearance(preview_body, render_overlays())

/// All four views' data URLs of the preview body wearing these results, for import and restore previews.
/datum/custom_sprite_editor/markings/proc/render_region_previews(list/results)
	return custom_sprite_render_views(capture_region_previews(results), custom_sprite_preview_width(preview_body), CALLBACK(src, PROC_REF(publish_icon)))

/// Puts every region's drawing and base markings on a body, then redraws it once.
/proc/custom_sprite_apply_region_results(mob/living/carbon/human/body, list/results, allow_emissives)
	body.AddComponent(/datum/component/custom_sprite_appearance)
	for(var/zone, result in results)
		if(!isnull(result["markings"]))
			custom_style_apply_base_markings(body, zone, result["markings"], allow_emissives)
		var/list/drawing = custom_sprite_appearance_drawing(result["drawing"], allow_emissives)
		if(drawing)
			LAZYSET(body.dna.custom_limb_markings, zone, drawing)
		else
			LAZYREMOVE(body.dna.custom_limb_markings, zone)
		var/obj/item/bodypart/limb = body.get_bodypart(custom_marking_zone_limb(zone))
		limb?.apply_custom_marking(drawing, custom_marking_zone_overlay_type(zone))
	body.update_body()

/datum/custom_sprite_editor/markings/ui_static_data(mob/user)
	. = ..()
	.["regionLabels"] = GLOB.custom_marking_zone_labels
	var/list/choices = list()
	for(var/zone in GLOB.custom_marking_zone_labels)
		if(zone in GLOB.body_markings_per_limb)
			choices[zone] = GLOB.body_markings_per_limb[zone]
	.["regionMarkingChoices"] = choices
	.["maxBaseMarkings"] = MAXIMUM_MARKINGS_PER_LIMB
	.["regions"] = region_map
	.["regionZones"] = region_zones
	.["emissive"] = custom_sprite_emissive_settings(FALSE)

/datum/custom_sprite_editor/markings/ui_data(mob/user)
	. = ..()
	// Region emission lives in regionEmissive; the all-off view flags are static data.
	. -= "emissive"
	.["selectedZone"] = selected_zone
	.["focusRevision"] = focus_revision
	.["regionEmissive"] = workspace.emissive
	.["lockedRegions"] = current_locks()
	var/list/markings = list()
	for(var/zone in workspace.markings_context)
		markings[zone] = region_marking_rows(zone)
	.["regionMarkings"] = markings
	if(candidate)
		var/list/names = list()
		for(var/zone in candidate["regions"])
			names += GLOB.custom_marking_zone_labels[zone]
		var/list/shown = .["candidate"]
		shown["regions"] = names
		shown["skipped"] = candidate["skipped"]
	.["paletteNotice"] = palette_notice()

/**
 * Explains colors the window can't take: a region over its own limit first, then a canvas over the shared one.
 *
 * Only a canvas over the shared limit can hold a region over its own, so ordinary strokes skip the check.
 */
/datum/custom_sprite_editor/markings/proc/palette_notice()
	if(length(workspace.palette) <= CUSTOM_SPRITE_MAX_COLORS)
		return null
	var/list/results = region_results()
	for(var/zone in region_zones)
		if(results[zone]?["error"])
			return "The [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] uses more than [CUSTOM_SPRITE_MAX_COLORS] colors on its own, so it can't be saved or exported until some are gone."
	return "Your markings already use more than [CUSTOM_SPRITE_MAX_COLORS] colors between them, so new colors can't be added until some are gone."

/// A region's native markings in layer order, as its Base markings section shows them.
/datum/custom_sprite_editor/markings/proc/region_marking_rows(zone)
	. = list()
	var/index = 0
	for(var/list/entry as anything in workspace.markings_context[zone])
		index++
		. += list(list("index" = index, "name" = entry["name"], "color" = entry["color"]))

/// Whether a region's saved paint in one view includes any the canvas can't show, under other limbs or outside every region.
/datum/custom_sprite_editor/markings/proc/has_covered_paint(zone, direction)
	var/list/colors = saved_pixels[zone]?[direction]
	var/list/rows = region_map[direction]
	return colors && rows && length(custom_sprite_covered_positions(colors, zone, rows, region_zones, workspace.width)) > 0

/datum/custom_sprite_editor/markings/editor_act(action, list/params, datum/tgui/ui)
	var/static/list/region_actions = list("selectRegion", "setEmissive", "clear", "setBaseMarking", "addBaseMarking", "removeBaseMarking", "pickBaseMarkingColor")
	if(action in list("exportStyle", "restorePrevious"))
		return prompt_action(action, ui.user)
	if(!(action in region_actions))
		return null
	var/zone = params["zone"]
	// The server's selection decides which region these act on; a window out of step is refused, and so is a locked region.
	if(!(zone in region_zones) || (zone in current_locks()) || (action != "selectRegion" && zone != selected_zone))
		return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	switch(action)
		if("selectRegion")
			selected_zone = zone
			// The window already shows its own selection.
			return FALSE
		if("setEmissive")
			var/direction = params["dir"]
			var/enabled = params["enabled"]
			var/list/current = canvas.emissive[zone]
			if(!current || !istext(direction) || !(direction in current) || !isnum(enabled) || !(enabled in list(TRUE, FALSE)) || (enabled && !emissives_allowed()))
				return FALSE
			if(current[direction] == enabled)
				return TRUE
			var/list/emissive = canvas.emissive.Copy()
			emissive[zone] = current.Copy()
			emissive[zone][direction] = enabled
			canvas.emissive = emissive
		if("clear")
			if(!canvas.clear_region(params["dir"], "[region_zones.Find(zone)]", has_covered_paint(zone, params["dir"]) ? zone : null))
				return FALSE
		if("setBaseMarking")
			var/name = params["name"]
			if(!isnum(params["index"]) || !istext(name) || !(name in GLOB.body_markings_per_limb[zone]) || custom_style_marking_data(canvas.markings_context[zone])[name])
				return FALSE
			return write_region_marking(zone, params["index"], name, null)
		if("addBaseMarking")
			var/list/markings = custom_style_marking_data(canvas.markings_context[zone])
			if(!(zone in canvas.markings_context) || length(markings) >= MAXIMUM_MARKINGS_PER_LIMB)
				return FALSE
			var/list/choices = GLOB.body_markings_per_limb[zone].Copy()
			for(var/name in markings)
				choices -= name
			if(!length(choices))
				return FALSE
			return write_region_marking(zone, null, choices[1], default_marking_color(choices[1]))
		if("removeBaseMarking")
			if(!isnum(params["index"]))
				return FALSE
			return write_region_marking(zone, params["index"], null, null)
		if("pickBaseMarkingColor")
			var/index = params["index"]
			var/list/entries = canvas.markings_context[zone]
			if(!isnum(index) || index < 1 || index > length(entries))
				return FALSE
			var/list/entry = entries[index]
			var/color = tgui_color_picker(ui.user, "Choose a color for [entry["name"]].", "Limb markings", entry["color"])
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			// The list may have changed while the picker was open.
			entries = canvas.markings_context[zone]
			if(index > length(entries) || entries[index]["name"] != entry["name"])
				return FALSE
			return write_region_marking(zone, index, entry["name"], custom_sprite_color(color))
	draft_edited()
	return TRUE

/// Rewrites one region's native markings as an undoable draft change.
/datum/custom_sprite_editor/markings/proc/write_region_marking(zone, index, name, color)
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	var/list/context = canvas.markings_context
	// Checked afresh: the colour picker may have waited while the region was covered.
	if(!(zone in context) || (zone in locked_regions()))
		return FALSE
	var/list/entries = custom_style_rewrite_markings(context[zone], index, name, color)
	if(isnull(entries))
		return FALSE
	var/list/new_context = list()
	for(var/region, region_markings in context)
		new_context[region] = custom_style_copy_markings(region_markings)
	new_context[zone] = entries
	if(!canvas.replace_frames(canvas.layers[1]["data"], "Change base markings", new_context, canvas.emissive))
		return FALSE
	draft_changed()
	// The palette keeps its sampled shades until the rebuild samples the new look.
	refresh_custom_palette()
	request_rebuild()
	return TRUE

/**
 * Export and Restore ask whether they mean the whole body or the selected region. Sleeps.
 *
 * Returns TRUE when the window should update.
 */
/datum/custom_sprite_editor/markings/proc/prompt_action(action, mob/user)
	var/zone = selected_zone
	var/label = GLOB.custom_marking_zone_labels[zone]
	if(action == "exportStyle")
		var/choice = tgui_alert(user, "Export the whole body, or just the [LOWER_TEXT(label)]?", "Export style", list("Whole body", label, "Cancel"))
		if(!can_edit(user) || !choice || choice == "Cancel")
			return FALSE
		transfer_notice = null
		transfer_error = export_problem(choice == "Whole body" ? region_zones : list(zone))
		if(transfer_error)
			return TRUE
		if(choice == "Whole body")
			transfer_error = custom_style_send_body(user.client, body_packages())
		else
			transfer_error = custom_style_send(user.client, region_package(zone, region_results()))
		if(!transfer_error)
			transfer_notice = "Style exported."
		return TRUE
	var/list/previous = restorable_regions()
	if(!length(previous))
		return FALSE
	var/list/choices = list("Whole body")
	if(previous[zone])
		choices += label
	choices += "Cancel"
	var/choice = tgui_alert(user, "Restore the whole body's previous saved style, or just the [LOWER_TEXT(label)]?", "Restore previous saved style", choices)
	if(!can_edit(user) || !choice || choice == "Cancel")
		return FALSE
	// The draft may have moved on while the prompt was open.
	previous = restorable_regions()
	if(choice != "Whole body")
		var/list/single = list()
		if(previous[zone])
			single[zone] = previous[zone]
		previous = single
	if(!length(previous))
		return FALSE
	show_region_candidate(previous, "restore")
	return TRUE

/// Why these regions can't be exported right now, or null.
/datum/custom_sprite_editor/markings/proc/export_problem(list/zones)
	var/list/results = region_results()
	for(var/zone in zones)
		var/error = results[zone]?["error"]
		if(error)
			return "The [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] [error] Remove some before exporting it."

/// Each region's previous saved style that differs from what it would save now.
/datum/custom_sprite_editor/markings/proc/restorable_regions()
	. = list()
	var/list/previous = list()
	for(var/zone in region_zones)
		var/list/package = preferences.custom_style_previous_package("markings", zone)
		if(package)
			previous[zone] = package
	// Most bodies have none, and working out what every region would save isn't free.
	if(!length(previous))
		return
	var/list/results = region_results()
	for(var/zone, package in previous)
		if(!custom_style_matches(package, region_package(zone, results)))
			.[zone] = package

/datum/custom_sprite_editor/markings/update_restorable()
	can_restore_previous = length(restorable_regions()) > 0

/// A whole-body file previews its regions; a single-region file its own; a drawing-only file goes into the selected region.
/datum/custom_sprite_editor/markings/preview_received(list/result)
	var/list/regions = result["body"]
	if(!regions)
		var/list/package = result["package"]
		if(result["legacy"])
			var/list/drawing = package["drawing"]
			var/width = custom_marking_zone_width(selected_zone)
			// Old files are 32 wide; the taur region centres them, as its single-zone editor did.
			if(drawing && custom_sprite_width(drawing) < width)
				drawing = custom_sprite_resize_drawing(drawing, width)
			package = custom_style_package("markings", selected_zone, drawing, null)
		if(package["target"] != "markings")
			transfer_error = "That style is for [package["target"] == "facial_hair" ? "facial hair" : "hair"], not markings."
			return FALSE
		regions = list()
		regions[package["zone"]] = package
	return show_region_candidate(regions, "import")

/**
 * Previews regions from an import or restoration before they replace anything.
 *
 * Regions this body doesn't have, and regions that are locked, are skipped and named in the
 * preview with the reason. Nothing in the draft changes until the candidate is confirmed.
 *
 * Returns TRUE when a preview is waiting for confirmation; otherwise transfer_error says why.
 */
/datum/custom_sprite_editor/markings/proc/show_region_candidate(list/regions, source)
	var/list/usable = list()
	var/list/skipped = list()
	var/list/locked = locked_regions()
	var/only_locked = TRUE
	for(var/zone, package in regions)
		var/label = GLOB.custom_marking_zone_labels[zone] || zone
		if(!(zone in region_zones))
			skipped += "[label] (not on this body)"
			only_locked = FALSE
		else if(zone in locked)
			skipped += "[label] (not available right now)"
		else
			usable[zone] = custom_style_copy_package(package)
	if(!length(usable))
		transfer_error = length(skipped) && only_locked ? "None of that style's regions can be changed right now." : "That style has no regions this body has."
		return FALSE
	var/problem = region_candidate_problem(usable)
	if(problem)
		transfer_error = problem
		return FALSE
	candidate = list("regions" = usable, "skipped" = skipped, "source" = source, "revision" = draft_revision, "summary" = null, "previews" = null)
	candidate["previews"] = candidate_cache[candidate_key()]
	if(isnull(candidate["previews"]))
		request_candidate()
	return TRUE

/// A whole-body candidate is keyed by every region it would set and the body it's drawn on.
/datum/custom_sprite_editor/markings/candidate_key()
	return json_encode(list(md5(json_encode(candidate_results(candidate["regions"]))), REF(preview_body), resources_markings, hide_parts, hide_underwear))

/datum/custom_sprite_editor/markings/render_candidate()
	var/key = candidate_key()
	candidate["previews"] = render_region_previews(candidate_results(candidate["regions"]))
	if(length(candidate_cache) >= 8)
		candidate_cache.Cut(1, 2)
	candidate_cache[key] = candidate["previews"]
	preview_hash = null
	refresh_preview(push = FALSE)

/// Why candidate regions can't replace their parts of this draft, or null.
/datum/custom_sprite_editor/markings/proc/region_candidate_problem(list/regions)
	if(!resources_ready)
		return "The preview isn't available right now."
	for(var/zone, reason in locked_regions())
		if(zone in regions)
			return reason
	for(var/zone, package in regions)
		var/label = LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])
		var/list/drawing = package["drawing"]
		if(custom_style_has_emission(drawing) && !emissives_allowed())
			return "The [label] glows, but emissive appearance is disabled for this character."
		if(!emissives_allowed())
			for(var/list/entry as anything in package["markings"])
				if(entry["emissive"])
					return "The [label] has glowing base markings, but emissive appearance is disabled for this character."
		if(drawing && custom_sprite_width(drawing) != custom_marking_zone_width(zone))
			return "The [label] drawing is the wrong size for that region."
		var/outside = custom_style_paint_outside(drawing, null, custom_sprite_body_draw_mask(preview_body, zone, custom_marking_zone_width(zone)))
		if(outside)
			return "The [outside] view has paint outside the [label]."
	return null

/// What every region would hold with a candidate applied.
/datum/custom_sprite_editor/markings/proc/candidate_results(list/regions)
	. = list()
	var/list/results = region_results()
	for(var/zone, entry_untyped in results)
		var/list/entry = entry_untyped
		.[zone] = entry.Copy()
	for(var/zone, package in regions)
		var/list/entry = .[zone] || list()
		entry["drawing"] = package["drawing"]
		if(!isnull(package["markings"]))
			entry["markings"] = package["markings"]
		.[zone] = entry

/// Replaces the confirmed regions as one undoable action.
/datum/custom_sprite_editor/markings/apply_candidate()
	if(!candidate)
		return FALSE
	var/list/regions = candidate["regions"]
	var/source = candidate["source"]
	if(candidate["revision"] != draft_revision)
		candidate = null
		transfer_error = "The drawing changed after the preview. Import the style again."
		return FALSE
	candidate = null
	transfer_error = region_candidate_problem(regions)
	if(transfer_error)
		return FALSE
	var/list/results = candidate_results(regions)
	var/list/drawings = list()
	for(var/zone, result in results)
		drawings[zone] = result["drawing"]
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	var/list/new_markings = list()
	for(var/zone, entries in canvas.markings_context)
		new_markings[zone] = custom_style_copy_markings(results[zone]?["markings"] || entries)
	var/list/new_emissive = canvas.emissive.Copy()
	// A confirmed region replaces the old one outright, paint other limbs cover included.
	var/list/new_resets = canvas.resets ? canvas.resets.Copy() : list()
	for(var/zone, package in regions)
		new_emissive[zone] = custom_sprite_emissive_settings(package["drawing"]?["emissive"])
		var/list/views = list()
		for(var/direction in GLOB.custom_style_directions)
			views[direction] = TRUE
		new_resets[zone] = views
	var/list/before = canvas.last_transaction()
	if(!canvas.replace_frames(custom_sprite_compose_regions(drawings, region_map, region_zones, canvas.width), source == "restore" ? "Restore saved style" : "Import style", new_markings, new_emissive, new_resets))
		transfer_error = "This style and your undo history need more than [CUSTOM_SPRITE_MAX_COLORS] colors. Save or reopen the editor, then import again."
		return FALSE
	var/list/applied = canvas.last_transaction()
	// Saving keeps each replaced style as the previous one, unless the import is undone first.
	if(applied != before)
		applied["rotate"] = assoc_to_keys(regions)
	refresh_custom_palette()
	request_rebuild()
	transfer_notice = source == "restore" ? "Previous saved style restored. Save to keep it." : "Style imported."
	return TRUE

/// Hand paint draws above the body's own parts and the taur's paint above nearly everything, so each region takes its own cover.
/datum/custom_sprite_editor/markings/cover_rows_for(direction)
	var/list/bounds = unlocked_bounds ? unlocked_bounds[direction] : null
	var/list/body_rows = custom_sprite_cover_rows(cover_looks, direction, workspace.width, -BODYPARTS_LAYER, cover_key, bounds)
	var/list/high_rows = custom_sprite_cover_rows(cover_looks, direction, workspace.width, -BODYPARTS_HIGH_LAYER, cover_key, bounds)
	return custom_sprite_merge_cover_rows(body_rows, high_rows, region_map ? region_map[direction] : null, region_zones)
