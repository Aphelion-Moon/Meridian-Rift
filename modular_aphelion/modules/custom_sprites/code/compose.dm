/**
 * Whole-body markings previews composed from the canvas, instead of flattening the painted body.
 *
 * Paint sits at fixed layers: body paint at BODYPARTS_LAYER and hand paint at the hands'
 * BODYPARTS_HIGH_LAYER. Each view of the body without paint is flattened once per resource
 * rebuild into three slices: everything under body paint, everything between body and hand paint,
 * and everything over hand paint. A preview is those slices with the canvas pixels between them.
 * The canvas already shows exactly the paint the game shows, one region per pixel, so a preview
 * costs a few Blend()s instead of a full getFlatIcon(), and a view whose paint didn't change keeps
 * its picture.
 *
 * Bodies whose paint doesn't sit on those layers alone (a taur), and drafts a save would change
 * (a region over its colour limit), keep flattening the painted body.
 */
/datum/custom_sprite_editor/markings
	/// Whether the current previews are composed from slices rather than flattened.
	var/preview_composed = FALSE
	/// The paint-free look the slices are cut from, captured once per rebuild.
	var/mutable_appearance/paintless_look
	/// The guide appearance of the rebuild paintless_look was captured for.
	var/mutable_appearance/paintless_for
	/// Direction -> list(under, between, over) flat icons of paintless_look.
	var/list/slices = list()
	/// Direction -> the canvas pixels its composed preview was drawn from.
	var/list/composed_frames = list()

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
 * Refreshes composed previews. Only views whose canvas pixels changed are drawn again, and only the
 * visible one straight away.
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
	var/list/frames = workspace.layers[1]["data"]
	var/changed = FALSE
	for(var/direction in GLOB.custom_style_directions)
		if(composed_frames[direction] != json_encode(frames[direction]))
			stale_previews[direction] = TRUE
			changed = TRUE
	if(!changed)
		return TRUE
	render_preview(visible_direction)
	if(push)
		push()
	return TRUE

/// Composed previews come from the slices and the canvas; otherwise the painted body is flattened.
/datum/custom_sprite_editor/markings/render_preview(direction)
	if(!preview_composed || !resources_ready)
		return ..()
	preview_urls[direction] = publish_icon(composed_view(direction))
	composed_frames[direction] = json_encode(workspace.layers[1]["data"][direction])
	stale_previews -= direction
	return TRUE

/// One view of the preview: its slices with the canvas pixels between them.
/datum/custom_sprite_editor/markings/proc/composed_view(direction)
	var/list/cut = view_slices(direction)
	var/list/frame = workspace.layers[1]["data"][direction]
	var/icon/composed = icon('icons/blanks/32x32.dmi', "nothing")
	// A slice with nothing in it flattens to null, which the typed loop skips.
	for(var/icon/part in list(cut[1], paint_icon(frame, direction, FALSE), cut[2], paint_icon(frame, direction, TRUE), cut[3]))
		composed.Blend(part, ICON_OVERLAY)
	return composed

/// One view's slices, flattened the first time the view is drawn after each rebuild.
/datum/custom_sprite_editor/markings/proc/view_slices(direction)
	if(paintless_for != guide_appearance)
		paintless_look = capture_paintless_look()
		paintless_for = guide_appearance
		slices = list()
	var/list/cached = slices[direction]
	if(cached)
		return cached
	var/dir_number = text2num(direction)
	cached = list(
		slice_flat(-INFINITY, -BODYPARTS_LAYER, dir_number),
		slice_flat(-BODYPARTS_LAYER, -BODYPARTS_HIGH_LAYER, dir_number),
		slice_flat(-BODYPARTS_HIGH_LAYER, INFINITY, dir_number),
	)
	slices[direction] = cached
	return cached

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
	var/mutable_appearance/look = custom_sprite_preview_appearance(preview_body, render_overlays())
	for(var/datum/bodypart_overlay/overlay, limb in hidden)
		var/obj/item/bodypart/owner = limb
		owner.add_bodypart_overlay(overlay, FALSE)
	if(length(hidden))
		preview_body.update_body_parts()
	return look

/// paintless_look flattened with only its overlays layered in (low, high]. Only the lowest slice draws the body's own icon and underlays.
/datum/custom_sprite_editor/markings/proc/slice_flat(low, high, dir_number)
	var/mutable_appearance/slice = new(paintless_look)
	slice.overlays = list()
	if(low != -INFINITY)
		slice.underlays = list()
		slice.icon = null
		slice.icon_state = null
	for(var/mutable_appearance/overlay as anything in paintless_look.overlays)
		if(overlay.layer > low && overlay.layer <= high)
			slice.overlays += overlay
	return custom_sprite_flat_icon(slice, dir_number)

/// One view's canvas pixels as an icon: only hand regions, or only the rest. Paint takes its limb's marking opacity, as in game.
/datum/custom_sprite_editor/markings/proc/paint_icon(list/frame, direction, hands)
	var/icon/paint = icon('icons/blanks/32x32.dmi', "nothing")
	var/list/rows = region_map[direction]
	// Zone -> alpha suffix for its paint, "" when fully opaque.
	var/list/alphas = list()
	for(var/y in 0 to 31)
		var/list/row = frame[y + 1]
		var/run_start = 0
		var/run_color
		for(var/x in 0 to 32)
			var/color
			if(x < 32 && !endswith(row[x + 1], "00"))
				var/zone = custom_sprite_region_owner(rows, region_zones, x, y)
				if(zone && !!GLOB.custom_marking_hand_arms[zone] == hands)
					if(isnull(alphas[zone]))
						var/obj/item/bodypart/limb = preview_body.get_bodypart(custom_marking_zone_limb(zone))
						var/alpha = limb?.markings_alpha
						alphas[zone] = isnum(alpha) && alpha < 255 ? copytext(rgb(0, 0, 0, alpha), 8) : ""
					color = "[copytext(row[x + 1], 1, 8)][alphas[zone]]"
			if(color == run_color)
				continue
			if(run_color)
				paint.DrawBox(run_color, run_start + 1, 32 - y, x, 32 - y)
			run_start = x
			run_color = color
	return paint
