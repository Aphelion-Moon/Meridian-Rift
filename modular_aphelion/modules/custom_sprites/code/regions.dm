/**
 * The marking regions this body can be painted on right now, in draw order.
 *
 * Limbs follow the body's own render order (`get_all_limbs()`, as `update_body_parts()` draws them).
 * Each hand comes straight after its arm, because hand paint draws above arm paint on that limb.
 * A visible taur comes last; its native layers sort it in front of or behind the rest when the
 * map is composed. Missing limbs, stumps and invisible taur legs have no region, and a hand only
 * exists through its arm.
 */
/proc/custom_sprite_present_regions(mob/living/carbon/human/body)
	. = list()
	for(var/zone in body.get_all_limbs())
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		if(!limb || IS_STUMP(limb) || (limb.bodyshape & BODYSHAPE_TAUR) || !(zone in GLOB.custom_marking_zone_labels))
			continue
		. += zone
		for(var/hand, arm in GLOB.custom_marking_hand_arms)
			if(arm == zone && limb.aux_zone == hand)
				. += hand
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(body)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(taur && chest && taur.can_draw_on_bodypart(chest, body))
		. += CUSTOM_MARKING_ZONE_TAUR

/**
 * Region N's ID color. Regions paint nothing else, so a pixel of this color is unambiguous.
 *
 * The colors sit on a circle, so a blend of two regions at an antialiased edge falls inside it and
 * never reads as a third region.
 */
/proc/custom_sprite_region_color(index)
	var/angle = (index - 1) * 40
	return LOWER_TEXT(rgb(round(128 + 100 * cos(angle), 1), round(128 + 100 * sin(angle), 1), 64))

/// A solid drawing of region N's ID color across one editing mask, or null when the mask is empty.
/proc/custom_sprite_region_id_drawing(index, list/mask, width)
	var/list/directions = list()
	for(var/direction, rows in mask)
		var/grid = jointext(rows, "")
		if(findtext(grid, "1"))
			directions[direction] = custom_sprite_encode_grid(grid, 1, width * 32)
	if(!length(directions))
		return null
	return list("version" = custom_sprite_version(width, 1), "palette" = list(custom_sprite_region_color(index)), "tint" = null, "dirs" = directions, "emissive" = custom_sprite_emissive_settings(FALSE))

/**
 * Which region owns each canvas pixel, in every view.
 *
 * Every region's current editing mask is filled with its ID color and pushed through its real
 * overlay type, so the hand/arm layering, the leg split and the taur's native layers all apply as
 * they do in game. The images are composed in draw order (by layer, then region order) and the
 * result is read once per view. A blended edge pixel goes to the region that dominates it. Maps are
 * cached by the geometry that produced them.
 *
 * Arguments:
 * - body: The body whose limbs and taur organ define the regions.
 * - zones: The regions to map, from custom_sprite_present_regions().
 * - width: The canvas width, 32 or CUSTOM_SPRITE_TAUR_WIDTH.
 *
 * Returns direction -> 32 row strings of `width` characters: "0" for no region, "N" for zones[N].
 */
/proc/custom_sprite_region_map(mob/living/carbon/human/body, list/zones, width = 32)
	// Bounded cache of composed region maps, keyed by the geometry that produced them.
	var/static/list/maps = list()
	var/list/geometry = list(width, zones)
	for(var/zone in zones)
		geometry += list(custom_sprite_body_draw_mask(body, zone, custom_marking_zone_width(zone)))
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(body)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(taur && chest)
		geometry += list(taur.icon_render_key(chest))
	var/key = md5(json_encode(geometry))
	if(maps[key])
		return maps[key]
	var/offset_x = (width - 32) / 2
	var/list/entries = list()
	for(var/index in 1 to length(zones))
		var/zone = zones[index]
		var/obj/item/bodypart/limb = body.get_bodypart(custom_marking_zone_limb(zone))
		var/zone_width = custom_marking_zone_width(zone)
		var/list/drawing = limb && custom_sprite_region_id_drawing(index, custom_sprite_body_draw_mask(body, zone, zone_width), zone_width)
		if(!drawing)
			continue
		var/overlay_type = custom_marking_zone_overlay_type(zone)
		var/datum/bodypart_overlay/custom_marking/scratch = new overlay_type
		scratch.blocks_emissive = EMISSIVE_BLOCK_NONE
		scratch.cache_icons = FALSE
		scratch.set_drawing(drawing, limb)
		for(var/image/part as anything in scratch.get_all_overlays(limb))
			if(PLANE_TO_TRUE(part.plane) == EMISSIVE_PLANE)
				continue
			entries += list(list(part.layer, index, 1 + offset_x + part.pixel_x + part.pixel_w, 1 + part.pixel_y + part.pixel_z, icon(part.icon, part.icon_state)))
		qdel(scratch)
	// Stable draw order: lower layers first, then region order within a layer.
	var/list/layers = list()
	for(var/list/entry as anything in entries)
		layers |= entry[1]
	var/list/ordered = list()
	for(var/layer in sort_list(layers, GLOBAL_PROC_REF(cmp_numeric_asc)))
		for(var/list/entry as anything in entries)
			if(entry[1] == layer)
				ordered += list(entry)
	var/icon/composite = custom_sprite_blank_icon(width)
	for(var/list/entry as anything in ordered)
		composite.Blend(entry[5], ICON_OVERLAY, entry[3], entry[4])
	var/list/ids = list()
	for(var/index in 1 to length(zones))
		ids[custom_sprite_region_color(index)] = "[index]"
	var/list/result = list()
	for(var/direction in GLOB.cardinals)
		var/list/rows = list()
		for(var/y in 0 to 31)
			var/row = ""
			for(var/x in 0 to width - 1)
				var/pixel = composite.GetPixel(x + 1, 32 - y, "", direction)
				row += pixel ? (ids[LOWER_TEXT(copytext(pixel, 1, 8))] || custom_sprite_region_fallback(ordered, x, y, direction)) : "0"
			rows += row
		result["[direction]"] = rows
	return custom_sprite_cache_put(maps, key, result)

/**
 * The region that dominates one blended pixel, as its region character.
 *
 * Images composite from the top down, so each one's share of the pixel is its alpha times what the
 * images above it left showing. A tie goes to the higher image.
 */
/proc/custom_sprite_region_fallback(list/ordered, x, y, direction)
	var/list/shares = list()
	var/showing = 1
	for(var/position = length(ordered); position >= 1 && showing > 0; position--)
		var/list/entry = ordered[position]
		var/icon/shape = entry[5]
		var/image_x = x + 2 - entry[3]
		var/image_y = 33 - y - entry[4]
		if(image_x < 1 || image_y < 1 || image_x > shape.Width() || image_y > shape.Height())
			continue
		var/pixel = shape.GetPixel(image_x, image_y, "", direction)
		if(!pixel)
			continue
		var/list/channels = rgb2num(pixel)
		var/alpha = (length(channels) > 3 ? channels[4] : 255) / 255
		shares["[entry[2]]"] += alpha * showing
		showing *= 1 - alpha
	. = "0"
	var/best = 0
	for(var/region, share in shares)
		if(share > best)
			best = share
			. = region

/// The region owning a canvas pixel (0-based), or null.
/proc/custom_sprite_region_owner(list/rows, list/zones, x, y)
	var/index = text2num(copytext(rows[y + 1], x + 1, x + 2))
	return index ? zones[index] : null

/// The paintable mask of a region map: every pixel an unlocked region owns. `locked` holds region characters.
/proc/custom_sprite_region_mask(list/region_map, list/locked)
	. = list()
	for(var/direction, map_rows in region_map)
		var/list/rows = list()
		for(var/row in map_rows)
			var/owned = row
			// Locked regions go first, so region 1 can be locked before 2-9 become "1".
			for(var/region in locked)
				owned = replacetext(owned, region, "0")
			for(var/index in 2 to 9)
				owned = replacetext(owned, "[index]", "1")
			rows += owned
		.[direction] = rows
