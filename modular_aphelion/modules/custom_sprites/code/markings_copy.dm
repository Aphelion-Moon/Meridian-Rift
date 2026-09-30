/// Marking copies follow the draft's native records, independently of custom paint and candidate previews.
/datum/custom_sprite_editor/markings/base_copy_context()
	return json_encode(workspace.markings_context)

/datum/custom_sprite_editor/markings/base_copy_ready()
	return resources_markings == base_copy_context()

/// Whole-body and taur canvases use body coordinates, without a hairstyle's moving origin.
/datum/custom_sprite_editor/markings/base_copy_origin()
	return list(0, 0)

/**
 * Sample each region's own native markings, never the body, clothing or taur organ artwork.
 *
 * The native helper runs before live height/textures and with marking opacity neutralized; pasted
 * custom paint receives those settings once. Regions without native records contribute no base
 * pixels. Where native layers overlap at reduced global opacity, the copy takes the topmost layer's
 * pixel rather than their blend.
 */
/datum/custom_sprite_editor/markings/render_base_copy_frame(direction)
	if(!istype(preview_body, /mob/living/carbon/human/dummy))
		return null
	apply_draft_base_markings()
	var/list/icons = list()
	for(var/zone in region_zones)
		if(!(zone in GLOB.body_markings_per_limb))
			continue
		var/obj/item/bodypart/limb = preview_body.get_bodypart(custom_marking_zone_limb(zone))
		if(!limb)
			continue
		var/list/overlays = list()
		limb.append_base_marking_overlays(overlays, zone, FALSE, 255)
		var/image/look = image('icons/blanks/32x32.dmi', "nothing")
		for(var/mutable_appearance/overlay as anything in overlays)
			// Missing native states are blank; getFlatIcon's default-state fallback must not invent pixels.
			if(!overlay.icon || !icon_exists(overlay.icon, overlay.icon_state))
				continue
			look.overlays += overlay
		if(!length(look.overlays))
			continue
		icons[zone] = custom_sprite_flat_icon(look, text2num(direction), workspace.width, workspace.height)
	var/list/rows = region_map[direction]
	. = list()
	for(var/y in 0 to workspace.height - 1)
		var/list/row = list()
		row.len = workspace.width
		for(var/x in 0 to workspace.width - 1)
			var/zone = custom_sprite_region_owner(rows, region_zones, x, y)
			var/icon/base = icons[zone]
			row[x + 1] = base?.GetPixel(x + 1, workspace.height - y) || "#00000000"
		. += list(row)

/// Check the existing placement parser and the saved palette of each affected region before admitting a copy.
/datum/custom_sprite_editor/markings/base_copy_placement_valid(list/transaction)
	var/list/checked = transaction.Copy()
	if(isnull(checked["codes"]) || !workspace.can_transact(checked))
		transfer_error = "The copied pixels no longer fit the editable regions or their permitted colors."
		return FALSE
	var/direction = checked["dir"]
	// Ordinary placements can trim paint outside their mask; a base copy must report a newly locked destination.
	var/list/area = checked["area"]
	var/list/palette = checked["palette"]
	var/list/values = custom_sprite_index_values()
	var/digits = checked["digits"]
	var/position = 1
	for(var/y in area[2] to area[4])
		for(var/x in area[1] to area[3])
			var/code = copytext(checked["codes"], position, position + digits)
			position += digits
			if(copytext(code, 1, 2) == ".")
				continue
			var/index = 0
			for(var/character in 1 to digits)
				index = index * 64 + values[copytext(code, character, character + 1)]
			var/color = palette[index + 1]
			if(!(length(color) == 9 && endswith(color, "00")) && !workspace.is_point_allowed(x, y, direction))
				transfer_error = "The copied pixels include a region that is no longer editable."
				return FALSE
	var/list/source_frames = workspace.layers[1]["data"]
	var/list/frames = source_frames.Copy()
	var/list/frame = deep_copy_list(frames[direction])
	frames[direction] = frame
	var/list/affected = list()
	for(var/list/point as anything in checked["points"])
		frame[point[2] + 1][point[1] + 1] = point[4]
		affected |= custom_sprite_region_owner(region_map[direction], region_zones, point[1], point[2])
	var/list/results = region_results(frames)
	for(var/zone in affected)
		if(results[zone]?["error"])
			transfer_error = "The copied pixels would exceed the [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] saved color limit."
			return FALSE
	return TRUE
