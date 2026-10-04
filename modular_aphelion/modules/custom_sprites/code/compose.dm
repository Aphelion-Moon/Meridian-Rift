/**
 * Whole-body markings previews composed from the canvas, instead of drawing the painted body.
 *
 * Paint sits at fixed layers: body paint at BODYPARTS_LAYER and hand paint at the hands'
 * BODYPARTS_HIGH_LAYER. The body without paint is cut once per resource rebuild into three slices,
 * each an iconforge recipe for every view from one walk: everything under body paint, everything
 * between body and hand paint, and everything over hand paint. A preview is those slices with the
 * canvas pixels between them, drawn as boxes. The canvas already shows exactly the paint the game
 * shows, one region per pixel, so a preview costs no walk at all, and a view whose paint didn't
 * change keeps its picture.
 *
 * Bodies whose paint doesn't sit on those layers alone (a taur), and drafts a save would change
 * (a region over its colour limit), keep drawing the painted body.
 */
/datum/custom_sprite_editor/markings
	/// Whether the current previews are composed from slices rather than flattened.
	var/preview_composed = FALSE
	/// The paint-free look the slices are cut from, captured once per rebuild.
	var/mutable_appearance/paintless_look
	/// The guide appearance of the rebuild paintless_look was captured for.
	var/mutable_appearance/paintless_for
	/// Direction -> list(under, between, over) iconforge recipes of paintless_look, null for an empty slice.
	var/list/slice_recipes
	/// Direction -> the canvas pixels its composed preview was drawn from.
	var/list/composed_frames = list()

/// The character thumbnail can show floating paint without changing the authoritative draft. Markings have one layer.
/datum/custom_sprite_editor/markings/proc/preview_frames()
	return selection_frames || workspace.layers[1]["data"]

/// Whether previews can be composed right now, rather than flattened from the painted body.
/datum/custom_sprite_editor/markings/proc/can_compose_previews()
	if(!resources_ready || !guide_appearance || (CUSTOM_MARKING_ZONE_TAUR in region_zones) || workspace.width != 32 || workspace.height != 32)
		return FALSE
	// A tinted or translucent body tints the paint along with everything else when flattened.
	if(preview_body.color || preview_body.alpha < 255)
		return FALSE
	// Only a canvas over the shared colour limit can hold a region a save would refuse, and those previews show the saved paint.
	return length(workspace.palette) <= CUSTOM_SPRITE_MAX_COLORS

/**
 * Refreshes composed previews. Only views whose canvas pixels changed are drawn again.
 *
 * Returns FALSE when previews can't be composed, so the painted body has to be flattened instead.
 */
/datum/custom_sprite_editor/markings/proc/refresh_composed_previews(push)
	if(!can_compose_previews())
		preview_composed = FALSE
		return FALSE
	if(!preview_composed || paintless_for != guide_appearance)
		preview_composed = TRUE
		composed_frames = list()
	update_restorable()
	var/list/frames = preview_frames()
	var/changed = FALSE
	for(var/direction in GLOB.custom_style_directions)
		if(composed_frames[direction] != json_encode(frames[direction]))
			stale_previews[direction] = TRUE
			changed = TRUE
	if(changed)
		render_preview(visible_direction)
		if(push)
			push()
	return TRUE

/// Composed previews come from the slices and the canvas; otherwise the painted body is drawn. Every view whose paint changed is drawn at once.
/datum/custom_sprite_editor/markings/render_preview(direction)
	if(!preview_composed || !resources_ready)
		return ..()
	var/list/frames = preview_frames()
	var/list/recipes = list()
	for(var/view in GLOB.custom_sprite_view_facings)
		if(stale_previews[view] || !preview_urls[view])
			recipes[view] = composed_recipe(view)
	for(var/view, url in custom_sprite_draw_recipes(recipes, CALLBACK(src, PROC_REF(publish_picture)), "[picture_name]_preview"))
		preview_urls[view] = url
		composed_frames[view] = json_encode(frames[view])
		stale_previews -= view
	return TRUE

/// One view of the preview as an iconforge recipe: its slices with the canvas pixels between them.
/datum/custom_sprite_editor/markings/proc/composed_recipe(direction)
	var/list/cut = view_slice_recipes()[direction]
	var/list/paint = paint_recipes(preview_frames()[direction], direction)
	var/list/blends = list()
	for(var/part in list(cut[1], paint[1], cut[2], paint[2], cut[3]))
		if(part)
			blends += "{\"type\":\"[RUSTG_ICONFORGE_BLEND_ICON]\",\"icon\":[part],\"blend_mode\":[ICON_OVERLAY],\"x\":1,\"y\":1}"
	// The lowest slice, with the body's own icon, is always there, so this is never null.
	return custom_sprite_boxes_recipe(blends)

/// Every view's slices as recipes, from one walk per slice, the first time a preview is composed after each rebuild.
/datum/custom_sprite_editor/markings/proc/view_slice_recipes()
	if(paintless_for != guide_appearance)
		paintless_look = capture_paintless_look()
		paintless_for = guide_appearance
		slice_recipes = null
	if(slice_recipes)
		return slice_recipes
	var/list/cuts = list()
	for(var/list/bounds as anything in list(list(-INFINITY, -BODYPARTS_LAYER), list(-BODYPARTS_LAYER, -BODYPARTS_HIGH_LAYER), list(-BODYPARTS_HIGH_LAYER, INFINITY)))
		var/mutable_appearance/slice = slice_look(bounds[1], bounds[2])
		cuts += list(slice ? custom_sprite_view_recipes(slice) : list())
	slice_recipes = list()
	for(var/view in GLOB.custom_sprite_view_facings)
		slice_recipes[view] = list(cuts[1][view], cuts[2][view], cuts[3][view])
	return slice_recipes

/// The preview body as previews show it, wearing the draft's base markings and none of its custom paint.
/datum/custom_sprite_editor/markings/proc/capture_paintless_look()
	// An import or restoration preview may have left its own base markings on the body.
	apply_draft_base_markings()
	var/list/hidden = list()
	for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
		for(var/datum/bodypart_overlay/custom_marking/marking in LAZYCOPY(limb.bodypart_overlays))
			hidden[marking] = limb
			limb.remove_bodypart_overlay(marking, FALSE)
	if(length(hidden))
		preview_body.update_body_parts()
	. = custom_sprite_preview_appearance(preview_body, render_overlays())
	for(var/datum/bodypart_overlay/overlay, limb in hidden)
		var/obj/item/bodypart/owner = limb
		owner.add_bodypart_overlay(overlay, FALSE)
	if(length(hidden))
		preview_body.update_body_parts()

/// paintless_look with only its overlays layered in (low, high], or null when that leaves nothing. Only the lowest slice has the body's own icon and underlays.
/datum/custom_sprite_editor/markings/proc/slice_look(low, high)
	var/mutable_appearance/slice = new(paintless_look)
	slice.overlays = list()
	if(low != -INFINITY)
		slice.underlays = list()
		slice.icon = null
		slice.icon_state = null
	for(var/mutable_appearance/overlay as anything in paintless_look.overlays)
		if(overlay.layer > low && overlay.layer <= high)
			slice.overlays += overlay
	return (low == -INFINITY || length(slice.overlays)) ? slice : null

/**
 * One view's canvas pixels as recipes of boxes, list(everything but the hands, the hands), each null when it has no
 * paint. Paint takes its limb's marking opacity, as in game. One pass over the canvas serves both.
 */
/datum/custom_sprite_editor/markings/proc/paint_recipes(list/frame, direction)
	var/list/rows = region_map[direction]
	var/list/zones = region_zones
	var/list/hand_arms = GLOB.custom_marking_hand_arms
	// Zone -> alpha suffix for its paint, "" when fully opaque.
	var/list/alphas = list()
	var/list/body_boxes = list()
	var/list/hand_boxes = list()
	for(var/y in 0 to 31)
		var/list/row = frame[y + 1]
		var/region_row = rows[y + 1]
		var/row_y = 32 - y
		// Each part's run of one colour along the row, and where it started.
		var/body_start = 0
		var/body_color
		var/hand_start = 0
		var/hand_color
		for(var/x in 0 to 32)
			var/body_now
			var/hand_now
			if(x < 32)
				var/cell = row[x + 1]
				if(copytext(cell, -2) != "00")
					var/index = text2num(copytext(region_row, x + 1, x + 2))
					var/zone = index ? zones[index] : null
					if(zone)
						var/alpha = alphas[zone]
						if(isnull(alpha))
							var/obj/item/bodypart/limb = preview_body.get_bodypart(custom_marking_zone_limb(zone))
							var/limb_alpha = limb?.markings_alpha
							alpha = isnum(limb_alpha) && limb_alpha < 255 ? copytext(rgb(0, 0, 0, limb_alpha), 8) : ""
							alphas[zone] = alpha
						if(hand_arms[zone])
							hand_now = "[copytext(cell, 1, 8)][alpha]"
						else
							body_now = "[copytext(cell, 1, 8)][alpha]"
			if(body_now != body_color)
				if(body_color)
					body_boxes += "{\"type\":\"[RUSTG_ICONFORGE_DRAW_BOX]\",\"color\":\"[body_color]\",\"x1\":[body_start + 1],\"y1\":[row_y],\"x2\":[x],\"y2\":[row_y]}"
				body_start = x
				body_color = body_now
			if(hand_now != hand_color)
				if(hand_color)
					hand_boxes += "{\"type\":\"[RUSTG_ICONFORGE_DRAW_BOX]\",\"color\":\"[hand_color]\",\"x1\":[hand_start + 1],\"y1\":[row_y],\"x2\":[x],\"y2\":[row_y]}"
				hand_start = x
				hand_color = hand_now
	return list(custom_sprite_boxes_recipe(body_boxes), custom_sprite_boxes_recipe(hand_boxes))

/// A blank tile with these iconforge transforms applied in order, such as DrawBox boxes, as a recipe, or null for none.
/proc/custom_sprite_boxes_recipe(list/boxes)
	if(!length(boxes))
		return null
	return "{\"icon_file\":\"icons/blanks/32x32.dmi\",\"icon_state\":\"nothing\",\"dir\":null,\"frame\":null,\"transform\":\[[jointext(boxes, ",")]\]}"
