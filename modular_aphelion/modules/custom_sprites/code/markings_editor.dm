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
	/// Zones whose drawing came from an import or restore since the last save.
	var/list/rotate_zones
	/// region_results() for the draft state in results_revision.
	var/list/results_cache
	/// Which draft state results_cache belongs to.
	var/results_revision

/datum/custom_sprite_editor/markings/New(datum/preferences/preferences, focus_zone)
	..(preferences, "markings", null)
	focus_region(focus_zone)

/// The canvas is composed from every region's save instead of one package.
/datum/custom_sprite_editor/markings/initial_package()
	return list()

/datum/custom_sprite_editor/markings/create_workspace(list/package)
	preferences.load_custom_sprites()
	build_region_map()
	load_saved_state()
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = new(null, list(), null, null, region_width())
	canvas.region_map = region_map
	canvas.tint = "#ffffff"
	canvas.load_frames(custom_sprite_compose_regions(saved_drawings, region_map, region_zones, canvas.width))
	var/list/markings = list()
	for(var/zone in saved_markings)
		markings[zone] = custom_style_copy_markings(saved_markings[zone])
	canvas.markings_context = markings
	var/list/emissive = list()
	for(var/zone in region_zones)
		emissive[zone] = custom_sprite_emissive_settings(saved_drawings[zone]?["emissive"])
	canvas.emissive = emissive
	baseline = deep_copy_list(canvas.layers[1]["data"])
	return canvas

/// Reads what every region has saved: the reference for spotting changes.
/datum/custom_sprite_editor/markings/proc/load_saved_state()
	saved_drawings = deep_copy_list(preferences.custom_limb_markings) || list()
	saved_pixels = list()
	for(var/zone in saved_drawings)
		saved_pixels[zone] = custom_sprite_drawing_pixels(saved_drawings[zone], custom_marking_zone_width(zone))
	saved_markings = list()
	for(var/zone in region_zones)
		if(zone in GLOB.body_markings_per_limb)
			saved_markings[zone] = custom_style_marking_entries(preferences.body_markings?[zone])
	results_cache = null

/// Rebuilds which region owns each pixel from the preview body.
/datum/custom_sprite_editor/markings/proc/build_region_map()
	region_zones = custom_sprite_present_regions(preview_body)
	region_map = custom_sprite_region_map(preview_body, region_zones, region_width())

/// A taur organ widens the canvas, even while hidden, so it doesn't change size.
/datum/custom_sprite_editor/markings/proc/region_width()
	return custom_sprite_taur_overlay(preview_body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/datum/custom_sprite_editor/markings/update_draw_area()
	build_region_map()
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	canvas.region_map = region_map
	workspace.draw_mask = custom_sprite_region_mask(region_map)
	workspace.draw_bounds = custom_sprite_mask_bounds(workspace.draw_mask, workspace.width)

/// The canvas never holds paint outside its regions, so there's nothing stranded to drop.
/datum/custom_sprite_editor/markings/clip_stranded_paint()
	return

/datum/custom_sprite_editor/markings/apply_draft_base_markings()
	for(var/zone in workspace.markings_context)
		custom_style_apply_base_markings(preview_body, zone, workspace.markings_context[zone], emissives_allowed())
	preview_body.update_body()

/**
 * Selects a region from outside the window, such as a limb's Custom button.
 *
 * A region this body doesn't have keeps the current selection and says why. With nothing selected
 * yet, the torso is picked, or the first region when there's no torso.
 */
/datum/custom_sprite_editor/markings/proc/focus_region(zone)
	if(zone in region_zones)
		selected_zone = zone
	else
		if(zone in GLOB.custom_marking_zone_labels)
			transfer_notice = "This body has no [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] right now."
		if(!(selected_zone in region_zones))
			selected_zone = (BODY_ZONE_CHEST in region_zones) ? BODY_ZONE_CHEST : (length(region_zones) ? region_zones[1] : null)
	focus_revision++
	SStgui.update_uis(src)

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
	for(var/zone in split)
		var/list/entry = split[zone]
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

/datum/custom_sprite_editor/markings/current_package()
	return region_package(selected_zone, region_results())

/// Saves every changed region in one write. Untouched regions aren't written.
/datum/custom_sprite_editor/markings/save_drawing()
	var/list/results = region_results()
	var/list/packages = list()
	var/list/rotate_keys = list()
	for(var/zone in results)
		var/list/result = results[zone]
		if(!result["changed"])
			continue
		if(result["error"])
			save_error = "[GLOB.custom_marking_zone_labels[zone]] [result["error"]] Your drawing is kept in this session. Press Ctrl+S to retry."
			SStgui.update_uis(src)
			return FALSE
		packages += list(region_package(zone, results))
		if(zone in rotate_zones)
			rotate_keys += custom_style_key("markings", zone)
	if(length(packages))
		var/error = preferences.commit_custom_styles(packages, slot, rotate_keys)
		if(error)
			save_error = "[error] Your drawing is kept in this session. Press Ctrl+S to retry."
			SStgui.update_uis(src)
			return FALSE
	mark_saved()
	save_error = null
	save_revision++
	return TRUE

/// The saved canvas becomes the reference for the next save.
/datum/custom_sprite_editor/markings/proc/mark_saved()
	load_saved_state()
	baseline = deep_copy_list(workspace.layers[1]["data"])
	rotate_zones = null

/datum/custom_sprite_editor/markings/refresh_preview(push = TRUE)
	preview_timer = null
	if(closing || !resources_ready)
		return
	var/list/results = region_results()
	var/new_hash = md5(json_encode(results))
	if(preview_hash == new_hash)
		return
	preview_urls = render_region_previews(results)
	preview_hash = new_hash
	if(push)
		SStgui.update_uis(src)

/// Renders the preview body wearing exactly what saving would write.
/datum/custom_sprite_editor/markings/proc/render_region_previews(list/results)
	custom_sprite_apply_region_results(preview_body, results, emissives_allowed())
	return custom_sprite_render_directions(preview_body, publish = CALLBACK(src, PROC_REF(publish_icon)), worn_overlays = render_overlays())

/// Puts every region's drawing and base markings on a body, then redraws it once.
/proc/custom_sprite_apply_region_results(mob/living/carbon/human/body, list/results, allow_emissives)
	body.AddComponent(/datum/component/custom_sprite_appearance)
	for(var/zone in results)
		var/list/result = results[zone]
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

/datum/custom_sprite_editor/markings/ui_data(mob/user)
	. = ..()
	.["emissive"] = custom_sprite_emissive_settings(FALSE)
	.["regions"] = region_map
	.["regionZones"] = region_zones
	.["selectedZone"] = selected_zone
	.["focusRevision"] = focus_revision
	.["regionEmissive"] = workspace.emissive
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
	.["paletteNotice"] = length(workspace.palette) > CUSTOM_SPRITE_MAX_COLORS ? "Your markings already use more than [CUSTOM_SPRITE_MAX_COLORS] colors between them, so new colors can't be added until some are gone." : null

/// A region's native markings in layer order, as its Base markings section shows them.
/datum/custom_sprite_editor/markings/proc/region_marking_rows(zone)
	. = list()
	var/index = 0
	for(var/list/entry as anything in workspace.markings_context[zone])
		index++
		. += list(list("index" = index, "name" = entry["name"], "color" = entry["color"]))

/// Marks the draft changed and schedules its preview, as the base editor does after every edit.
/datum/custom_sprite_editor/markings/proc/draft_edited()
	draft_changed()
	preview_timer = addtimer(CALLBACK(src, PROC_REF(refresh_preview)), 0.6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_STOPPABLE)

/// Whether a region's saved paint in one view includes any the canvas can't show, under other limbs or outside every region.
/datum/custom_sprite_editor/markings/proc/has_covered_paint(zone, direction)
	var/list/colors = saved_pixels[zone]?[direction]
	var/list/rows = region_map[direction]
	return colors && rows && length(custom_sprite_covered_positions(colors, zone, rows, region_zones, workspace.width)) > 0

/datum/custom_sprite_editor/markings/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/static/list/region_actions = list("selectRegion", "setEmissive", "clear", "setBaseMarking", "addBaseMarking", "removeBaseMarking", "pickBaseMarkingColor")
	if(action in list("exportStyle", "restorePrevious"))
		return can_edit(ui.user) && prompt_action(action, ui.user)
	if(!(action in region_actions))
		return ..()
	if(!can_edit(ui.user))
		return FALSE
	var/zone = params["zone"]
	if(!(zone in region_zones))
		return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	switch(action)
		if("selectRegion")
			selected_zone = zone
			return TRUE
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
	if(!(zone in context))
		return FALSE
	var/list/entries = custom_style_rewrite_markings(context[zone], index, name, color)
	if(isnull(entries))
		return FALSE
	var/list/new_context = list()
	for(var/region in context)
		new_context[region] = custom_style_copy_markings(context[region])
	new_context[zone] = entries
	if(!canvas.replace_frames(canvas.layers[1]["data"], "Change base markings", new_context, canvas.emissive))
		return FALSE
	draft_changed()
	rebuild_resources()
	refresh_preview(push = FALSE)
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
		var/list/results = region_results()
		if(choice == "Whole body")
			var/list/regions = list()
			for(var/region in region_zones)
				regions[region] = region_package(region, results)
			transfer_error = custom_style_send_body(user.client, regions)
		else
			transfer_error = custom_style_send(user.client, region_package(zone, results))
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

/// Each region's previous saved style that differs from what it would save now.
/datum/custom_sprite_editor/markings/proc/restorable_regions()
	. = list()
	var/list/results = region_results()
	for(var/zone in region_zones)
		var/list/previous = preferences.custom_style_previous_package("markings", zone)
		if(previous && !custom_style_matches(previous, region_package(zone, results)))
			.[zone] = previous

/datum/custom_sprite_editor/markings/context_ui_data()
	return list("canRestorePrevious" = length(restorable_regions()) > 0)

/// Imports a style file into a confirmable preview. Sleeps while the file dialog is open.
/datum/custom_sprite_editor/markings/begin_import(mob/user)
	var/revision = draft_revision
	var/owner_slot = slot
	var/zone = selected_zone
	transfer_error = null
	transfer_notice = null
	candidate = null
	var/list/result = custom_style_receive(user)
	if(QDELETED(src))
		return
	if(!can_edit(user) || revision != draft_revision || owner_slot != slot)
		transfer_error = "The drawing changed while you were choosing a file. Nothing was imported."
		return
	if(result?["error"])
		transfer_error = result["error"]
		return
	if(!result)
		return
	var/list/regions = result["body"]
	if(!regions)
		var/list/package = result["package"]
		if(result["legacy"])
			package = custom_style_package("markings", zone, package["drawing"], null)
		if(package["target"] != "markings")
			transfer_error = "That style is for [package["target"] == "facial_hair" ? "facial hair" : "hair"], not markings."
			return
		regions = list()
		regions[package["zone"]] = package
	if(!show_region_candidate(regions, "import"))
		log_game("[key_name(user)] had a custom style import rejected ([result["bytes"]] bytes): [transfer_error]")

/**
 * Previews regions from an import or restoration before they replace anything.
 *
 * Regions this body doesn't have are skipped and named in the preview. Nothing in the draft
 * changes until the candidate is confirmed.
 *
 * Returns TRUE when a preview is waiting for confirmation; otherwise transfer_error says why.
 */
/datum/custom_sprite_editor/markings/proc/show_region_candidate(list/regions, source)
	var/list/usable = list()
	var/list/skipped = list()
	for(var/zone in regions)
		if(zone in region_zones)
			usable[zone] = custom_style_copy_package(regions[zone])
		else
			skipped += GLOB.custom_marking_zone_labels[zone] || zone
	if(!length(usable))
		transfer_error = "That style has no regions this body has."
		return FALSE
	var/problem = region_candidate_problem(usable)
	if(problem)
		transfer_error = problem
		return FALSE
	candidate = list("regions" = usable, "skipped" = skipped, "source" = source, "revision" = draft_revision, "summary" = null, "previews" = render_region_previews(candidate_results(usable)))
	// The body now shows the candidate; the next refresh restores the draft.
	preview_hash = null
	refresh_preview(push = FALSE)
	return TRUE

/// Why candidate regions can't replace their parts of this draft, or null.
/datum/custom_sprite_editor/markings/proc/region_candidate_problem(list/regions)
	if(!resources_ready)
		return "The preview isn't available right now."
	for(var/zone in regions)
		var/list/package = regions[zone]
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
	for(var/zone in results)
		var/list/entry = results[zone]
		.[zone] = entry.Copy()
	for(var/zone in regions)
		var/list/package = regions[zone]
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
	for(var/zone in results)
		drawings[zone] = results[zone]["drawing"]
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = workspace
	var/list/new_markings = list()
	for(var/zone in canvas.markings_context)
		new_markings[zone] = custom_style_copy_markings(results[zone]?["markings"] || canvas.markings_context[zone])
	var/list/new_emissive = canvas.emissive.Copy()
	// A confirmed region replaces the old one outright, paint other limbs cover included.
	var/list/new_resets = canvas.resets ? canvas.resets.Copy() : list()
	for(var/zone in regions)
		new_emissive[zone] = custom_sprite_emissive_settings(regions[zone]["drawing"]?["emissive"])
		var/list/views = list()
		for(var/direction in GLOB.custom_style_directions)
			views[direction] = TRUE
		new_resets[zone] = views
	if(!canvas.replace_frames(custom_sprite_compose_regions(drawings, region_map, region_zones, canvas.width), source == "restore" ? "Restore saved style" : "Import style", new_markings, new_emissive, new_resets))
		transfer_error = "This style and your undo history need more than [CUSTOM_SPRITE_MAX_COLORS] colors. Save or reopen the editor, then import again."
		return FALSE
	for(var/zone in regions)
		LAZYOR(rotate_zones, zone)
	rebuild_resources()
	transfer_notice = source == "restore" ? "Previous saved style restored. Save to keep it." : "Style imported."
	return TRUE
