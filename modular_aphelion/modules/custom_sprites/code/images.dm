/// Bounded cache of paint clipped to bodyparts and their split leg layers.
GLOBAL_LIST_EMPTY(custom_sprite_limb_icons)

/// A blank in every editable direction, including bald hairstyles without an icon state.
/// Insert() alone leaves an empty icon reporting 0x0, so seed its dimensions from the blank.
/proc/custom_sprite_blank_icon(width = 32)
	var/icon/blank = icon('icons/blanks/32x32.dmi', "nothing")
	if(width != 32)
		blank.Crop(1, 1, width, 32)
	var/icon/result = icon(blank)
	for(var/direction in GLOB.cardinals)
		result.Insert(blank, "", direction)
	return result

/// Clip in body coordinates before flattening can expand a wide or offset overlay's origin.
/proc/custom_sprite_flat_icon(image/appearance, direction, width = 32)
	var/offset_x = (width - 32) / 2
	return getFlatIcon(appearance, defdir = direction, no_anim = TRUE, clip_bounds = list(1 - offset_x, 1, 32 + offset_x, 32))

/// Keep runtime caches bounded. Callers treat cached icons/lists as immutable.
/proc/custom_sprite_cache_put(list/cache, key, value, limit = 256)
	if(length(cache) >= limit && !(key in cache))
		cache.Cut(1, 2)
	cache[key] = value
	return value

/// Sample the most frequent opaque shades from all four authored directions.
/proc/custom_sprite_sample_palette(icon_file, icon_state)
	// Bounded cache of palettes sampled from existing sprites.
	var/static/list/palettes = list()
	var/key = "[icon_file]|[icon_state]"
	var/list/cached = palettes[key]
	if(cached)
		return cached.Copy()
	var/list/counts = list()
	if(icon_file && icon_exists(icon_file, icon_state))
		var/icon/source = icon(icon_file, icon_state)
		for(var/direction in GLOB.cardinals)
			for(var/y in 1 to min(32, source.Height()))
				for(var/x in 1 to min(32, source.Width()))
					var/pixel = source.GetPixel(x, y, "", direction)
					if(!pixel)
						continue
					var/list/channels = split_color(pixel)
					if(channels[4] < 128)
						continue
					var/color = LOWER_TEXT(rgb(channels[1], channels[2], channels[3]))
					counts[color]++
	var/list/palette = list()
	while(length(counts) && length(palette) < 15)
		var/most_frequent
		for(var/color, count in counts)
			if(isnull(most_frequent) || count > counts[most_frequent])
				most_frequent = color
		palette += most_frequent
		counts -= most_frequent
	if(!length(palette))
		palette = list("#ffffff", "#d8d8d8", "#b0b0b0")
	custom_sprite_cache_put(palettes, key, palette)
	return palette.Copy()

/// Match the Custom palette's frontend multiplication and nearest-integer channel rounding.
/proc/custom_sprite_tint_color(color, tint)
	if(!tint)
		return color
	var/list/color_rgb = rgb2num(color)
	var/list/tint_rgb = rgb2num(tint)
	return rgb(round(color_rgb[1] * tint_rgb[1] / 255 + 0.5), round(color_rgb[2] * tint_rgb[2] / 255 + 0.5), round(color_rgb[3] * tint_rgb[3] / 255 + 0.5))

/// Bake effective hair color into source shades; gradients already supply their own RGB.
/proc/custom_sprite_sample_hair_palette(datum/sprite_accessory/hair/hairstyle, obj/item/bodypart/head/head, target = "hair")
	var/list/palette = custom_sprite_sample_palette(hairstyle?.icon, hairstyle?.icon_state)
	if(!head)
		return palette
	var/list/hair_rgb = rgb2num(target == "facial_hair" ? head.facial_hair_color : head.get_rendered_hair_color())
	var/list/shades = palette
	palette = list()
	for(var/shade in shades)
		var/list/shade_rgb = rgb2num(shade)
		palette |= rgb(shade_rgb[1] * hair_rgb[1] / 255, shade_rgb[2] * hair_rgb[2] / 255, shade_rgb[3] * hair_rgb[3] / 255)
	var/gradient_key = custom_style_gradient_key(target)
	var/gradient_style = head.get_hair_gradient_style(gradient_key)
	if(gradient_style == SPRITE_ACCESSORY_NONE || !custom_style_hair_gradients(target)[gradient_style])
		return palette
	var/gradient_color = custom_sprite_color(head.get_hair_gradient_color(gradient_key))
	if(gradient_color)
		palette |= gradient_color
	return palette

/// The hairstyle's shades tinted by a hair look's color, in sampling order and without merging.
/// Palettes dedupe these; recolors need the positions to line up between two looks.
/proc/custom_style_hair_shades(list/hair, target = "hair")
	var/datum/sprite_accessory/hair/hairstyle = custom_style_hair_accessories(target)[hair?["style"]]
	var/list/hair_rgb = rgb2num(custom_sprite_color(hair?["color"]) || "#000000")
	var/list/shades = list()
	for(var/shade in custom_sprite_sample_palette(hairstyle?.icon, hairstyle?.icon_state))
		var/list/shade_rgb = rgb2num(shade)
		shades += rgb(shade_rgb[1] * hair_rgb[1] / 255, shade_rgb[2] * hair_rgb[2] / 255, shade_rgb[3] * hair_rgb[3] / 255)
	return shades

/**
 * Maps painted hair shades from one base hair look to another.
 *
 * Only a recolor of the same hairstyle maps: different hairstyles have their own shades, so their
 * paint keeps the colors it was drawn with. Shades that collapse onto one color under the old look
 * are ambiguous and left alone, as are the account's saved custom colors.
 *
 * Returns list(old color = new color), or null when nothing should move.
 */
/proc/custom_style_hair_color_map(list/old_hair, list/new_hair, list/protected_colors, target = "hair")
	if(!old_hair || !new_hair || old_hair["style"] != new_hair["style"])
		return null
	var/list/map = list()
	var/list/ambiguous = list()
	var/list/old_shades = custom_style_hair_shades(old_hair, target)
	var/list/new_shades = custom_style_hair_shades(new_hair, target)
	for(var/index in 1 to min(length(old_shades), length(new_shades)))
		var/painted = old_shades[index]
		var/recolored = new_shades[index]
		if(map[painted] && map[painted] != recolored)
			ambiguous |= painted
		map[painted] = recolored
	var/gradient_style = old_hair["gradient_style"]
	if(gradient_style == new_hair["gradient_style"] && gradient_style != SPRITE_ACCESSORY_NONE && old_hair["gradient_color"] != new_hair["gradient_color"])
		map[old_hair["gradient_color"]] = new_hair["gradient_color"]
	for(var/color in ambiguous + protected_colors)
		map -= color
	// Identity candidates also establish ambiguity, but have no work left once it is resolved.
	for(var/color in map.Copy())
		if(map[color] == color)
			map -= color
	return length(map) ? map : null

/proc/custom_sprite_hydrate(datum/sprite_editor_workspace/workspace, list/drawing)
	if(!drawing)
		return
	var/list/palette = drawing["palette"]
	var/width = custom_sprite_width(drawing)
	var/offset_x = (workspace.width - width) / 2
	for(var/direction, encoded in drawing["dirs"])
		var/grid = custom_sprite_decode_grid(encoded, length(palette), width * 32)
		if(!grid)
			continue
		var/list/frame = workspace.layers[1]["data"][direction]
		for(var/y in 1 to 32)
			for(var/x in 1 to width)
				var/position = (y - 1) * width + x
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1)) - 1
				frame[y][x + offset_x] = index > 0 ? "[palette[index]]ff" : "#00000000"

/// Called by debounced previews and appearance rendering, never by the per-stroke UI payload. Throwaway drawings skip the cache.
/proc/custom_sprite_paint_icon(list/drawing, cache = TRUE)
	// Bounded cache of decoded drawing icons shared by appearance renderers.
	var/static/list/paint_icons = list()
	if(!drawing)
		return null
	var/key = custom_sprite_pixel_hash(drawing)
	var/icon/cached = paint_icons[key]
	if(cached)
		return cached
	var/list/palette = drawing["palette"]
	var/width = custom_sprite_width(drawing)
	var/icon/paint = custom_sprite_blank_icon(width)
	for(var/direction in GLOB.cardinals)
		var/grid = custom_sprite_decode_grid(drawing["dirs"]["[direction]"], length(palette), width * 32)
		if(!grid)
			continue
		var/icon/frame = icon(paint, "", direction)
		// Paint opaque horizontal runs directly, without an editor workspace or temporary files.
		for(var/y in 0 to 31)
			var/row = copytext(grid, y * width + 1, (y + 1) * width + 1)
			for(var/x = 1; x <= width;)
				var/pixel = copytext(row, x, x + 1)
				var/run = spantext(row, pixel, x)
				if(pixel != "0")
					var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, pixel) - 1
					frame.DrawBox(palette[index], x, 32 - y, x + run - 1, 32 - y)
				x += run
		paint.Insert(frame, "", direction)
	return cache ? custom_sprite_cache_put(paint_icons, key, paint) : paint

/// Raw limb geometry, using exactly the state selection in get_limb_icon().
/proc/custom_sprite_limb_state(obj/item/bodypart/limb, auxiliary = FALSE)
	if(auxiliary)
		return "[limb.limb_id]_[limb.aux_zone]"
	var/state = "[limb.limb_id]_[limb.body_zone]"
	if(limb.is_dimorphic)
		state += "_[limb.limb_gender]"
	if(limb.bodyshape & BODYSHAPE_DIGITIGRADE)
		state += "_[ICON_KEY_DIGI]"
	return state

/obj/item/bodypart/proc/custom_sprite_icon_file()
	return should_draw_greyscale && icon_greyscale ? icon_greyscale : icon_static

/// White RGB and original alpha: multiplying by this clips without darkening the paint.
/proc/custom_sprite_silhouette(obj/item/bodypart/limb, auxiliary = FALSE)
	var/icon_file = limb.custom_sprite_icon_file()
	var/state = custom_sprite_limb_state(limb, auxiliary)
	if(!icon_file || !icon_exists(icon_file, state))
		return icon('icons/blanks/32x32.dmi', "nothing")
	var/icon/mask = icon(icon_file, state)
	mask.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, 1,1,1,0)
	return mask

/// Inclusive bounds in the editor's top-left coordinate system.
/proc/custom_sprite_icon_bounds(icon/source, direction)
	var/width = source.Width()
	var/height = source.Height()
	var/min_x = width
	var/min_y = height
	var/max_x = -1
	var/max_y = -1
	for(var/y in 0 to height - 1)
		for(var/x in 0 to width - 1)
			if(!source.GetPixel(x + 1, height - y, "", direction))
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if(max_x < 0)
		return null
	return list(min_x, min_y, max_x, max_y)

/// Full canvas for hair and facial hair; per-view locks are applied separately.
/proc/custom_sprite_canvas_bounds(width = 32)
	. = list()
	for(var/direction in GLOB.cardinals)
		.["[direction]"] = list(0, 0, width - 1, 31)

/// The taur organ owns its visible body; its two leg placeholders have no paintable pixels.
/proc/custom_sprite_taur_overlay(mob/living/carbon/human/body)
	var/obj/item/organ/taur_body/organ = body?.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	return organ?.bodypart_overlay

/// Native taur geometry in its centered 64 by 32 frame, shared by editing and rendering.
/proc/custom_sprite_taur_silhouette(mob/living/carbon/human/body, layer_index)
	var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(body)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(!taur?.sprite_datum || !chest)
		return custom_sprite_blank_icon(CUSTOM_SPRITE_TAUR_WIDTH)
	var/key = "taur-silhouette|[json_encode(taur.icon_render_key(chest))]|[chest.limb_gender]|[layer_index]"
	var/icon/cached = GLOB.custom_sprite_limb_icons[key]
	if(cached)
		return cached
	var/icon/silhouette = custom_sprite_blank_icon(CUSTOM_SPRITE_TAUR_WIDTH)
	var/list/native_layers = taur.custom_sprite_layers()
	for(var/native_layer, layer_value in native_layers)
		if(!isnull(layer_index) && native_layer != layer_index)
			continue
		for(var/image/part as anything in taur.get_images(chest, native_layer, -layer_value))
			var/icon/shape = icon(part.icon, part.icon_state)
			shape.MapColors(0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,1, 1,1,1,0)
			silhouette.Blend(shape, ICON_OVERLAY, part.pixel_x + part.pixel_w + 17, part.pixel_y + part.pixel_z + 1)
	return custom_sprite_cache_put(GLOB.custom_sprite_limb_icons, key, silhouette)

/// Arm rows above a hand's top edge that hand paint may still cover.
#define CUSTOM_SPRITE_HAND_ARM_ROWS 3

/// A hand's own pixels plus, with `wrist`, a short band of the arm just above them, so hand paint can't climb the arm.
/proc/custom_sprite_hand_silhouette(obj/item/bodypart/limb, wrist = TRUE)
	var/icon/result = custom_sprite_blank_icon()
	if(!limb.aux_zone)
		return result
	var/icon/hand = custom_sprite_silhouette(limb, TRUE)
	var/icon/arm = custom_sprite_silhouette(limb)
	for(var/direction in GLOB.cardinals)
		var/icon/frame = icon(hand, dir = direction)
		var/list/hand_bounds = wrist ? custom_sprite_icon_bounds(hand, direction) : null
		if(hand_bounds)
			var/icon/arm_frame = icon(arm, dir = direction)
			// Editor rows count down from the top; icon rows count up from the bottom.
			var/highest_row = 32 - max(0, hand_bounds[2] - CUSTOM_SPRITE_HAND_ARM_ROWS)
			if(highest_row < 32)
				arm_frame.DrawBox(null, 1, highest_row + 1, 32, 32)
			frame.Blend(arm_frame, ICON_OVERLAY)
		result.Insert(frame, "", direction)
	return result

#undef CUSTOM_SPRITE_HAND_ARM_ROWS

/// Compose geometry in the canvas frame without stretching or changing the body's origin. `wrist` gives a hand its wrist band.
/proc/custom_sprite_body_silhouette(mob/living/carbon/human/body, body_zone, width = 32, wrist = TRUE)
	var/icon/silhouette = custom_sprite_blank_icon(width)
	var/offset_x = (width - 32) / 2
	var/limb_zone = GLOB.custom_marking_hand_arms[body_zone] || body_zone
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		if(limb.body_zone != limb_zone)
			continue
		if(limb.bodyshape & BODYSHAPE_TAUR || IS_STUMP(limb))
			continue
		if(limb_zone != body_zone)
			silhouette.Blend(custom_sprite_hand_silhouette(limb, wrist), ICON_OVERLAY, offset_x + 1, 1)
			continue
		silhouette.Blend(custom_sprite_silhouette(limb), ICON_OVERLAY, offset_x + 1, 1)
		if(limb.aux_zone)
			silhouette.Blend(custom_sprite_silhouette(limb, TRUE), ICON_OVERLAY, offset_x + 1, 1)
	if(body_zone == CUSTOM_MARKING_ZONE_TAUR)
		silhouette.Blend(custom_sprite_taur_silhouette(body), ICON_OVERLAY, offset_x - 15, 1)
	return silhouette

/// Each view's paintable area padded by one pixel, from row-string masks.
/proc/custom_sprite_mask_bounds(list/mask, width = 32)
	. = list()
	for(var/direction, rows in mask)
		var/list/box = list(width, 32, -1, -1)
		for(var/y in 1 to length(rows))
			var/first = findtext(rows[y], "1")
			if(first)
				box = list(min(box[1], first - 1), min(box[2], y - 1), max(box[3], findlasttext(rows[y], "1") - 1), y - 1)
		.[direction] = box[3] < 0 ? null : list(max(0, box[1] - 1), max(0, box[2] - 1), min(width - 1, box[3] + 1), min(31, box[4] + 1))

/// Each view's paintable area padded by one pixel, read from the cached mask rather than the icon.
/proc/custom_sprite_body_draw_bounds(mob/living/carbon/human/body, body_zone, width = 32)
	return custom_sprite_mask_bounds(custom_sprite_body_draw_mask(body, body_zone, width), width)

/// Row strings keep the wire payload small and test the same silhouette used by rendering. `wrist` gives a hand its wrist band.
/proc/custom_sprite_body_draw_mask(mob/living/carbon/human/body, body_zone, width = 32, wrist = TRUE)
	// Bounded cache of directional limb silhouettes used by editing masks.
	var/static/list/limb_masks = list()
	var/list/geometry = list(width, body_zone, wrist)
	var/limb_zone = GLOB.custom_marking_hand_arms[body_zone] || body_zone
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		if(limb.body_zone != limb_zone || limb.bodyshape & BODYSHAPE_TAUR || IS_STUMP(limb))
			continue
		geometry += list(limb.custom_sprite_icon_file(), custom_sprite_limb_state(limb), limb.aux_zone)
	if(body_zone == CUSTOM_MARKING_ZONE_TAUR)
		var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(body)
		var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
		if(taur && chest)
			geometry += list(taur.icon_render_key(chest), chest.limb_gender)
	var/key = json_encode(geometry)
	if(limb_masks[key])
		return limb_masks[key]
	var/icon/silhouette = custom_sprite_body_silhouette(body, body_zone, width, wrist)
	var/list/mask = list()
	for(var/direction in GLOB.cardinals)
		var/list/rows = list()
		for(var/y in 0 to 31)
			var/list/row = list()
			for(var/x in 0 to width - 1)
				row += silhouette.GetPixel(x + 1, 32 - y, "", direction) ? "1" : "0"
			rows += jointext(row, "")
		mask["[direction]"] = rows
	return custom_sprite_cache_put(limb_masks, key, mask)

/// One view of a cover look as "1"/"0" rows: the canvas pixels something drawn over the body layer occupies.
/// With `cache_key` (from custom_sprite_cover_appearance), the same look reuses its rows across rebuilds and editors.
/// `bounds` (0-based, inclusive x0, y0, x1, y1) limits the pixel reads to the drawable box; outside it is clear.
/proc/custom_sprite_cover_rows(mutable_appearance/cover, direction, width = 32, cache_key, list/bounds)
	// Bounded cache of flattened cover rows, keyed by the images that made them.
	var/static/list/cover_masks = list()
	var/key = cache_key ? "[cache_key]|[direction]|[width]|[json_encode(bounds)]" : null
	if(key && cover_masks[key])
		return cover_masks[key]
	var/icon/flat = custom_sprite_flat_icon(cover, text2num(direction), width)
	var/list/rows = list()
	// Nothing to flatten (a bare, bald body) comes back as no icon at all.
	if(!flat)
		var/empty = repeat_string(width, "0")
		for(var/y in 1 to 32)
			rows += empty
		return key ? custom_sprite_cache_put(cover_masks, key, rows) : rows
	var/x0 = bounds ? bounds[1] : 0
	var/y0 = bounds ? bounds[2] : 0
	var/x1 = bounds ? bounds[3] : width - 1
	var/y1 = bounds ? bounds[4] : 31
	var/left = repeat_string(x0, "0")
	var/right = repeat_string(width - 1 - x1, "0")
	var/empty = repeat_string(width, "0")
	for(var/y in 0 to 31)
		if(y < y0 || y > y1)
			rows += empty
			continue
		var/list/row = list()
		for(var/x in x0 to x1)
			row += flat.GetPixel(x + 1, 32 - y) ? "1" : "0"
		rows += "[left][jointext(row, "")][right]"
	return key ? custom_sprite_cache_put(cover_masks, key, rows) : rows

/// Nova's character preview backgrounds as tiles for the custom editors' background swatches.
/proc/custom_sprite_background_tiles()
	var/static/list/tiles
	if(tiles)
		return tiles
	tiles = list()
	for(var/name in GLOB.background_state_options)
		var/icon/tile = icon('modular_nova/modules/character_preview_background/icons/background_32x32.dmi', name, SOUTH)
		var/icon/wide = icon(tile)
		wide.Crop(1, 1, CUSTOM_SPRITE_TAUR_WIDTH, 32)
		wide.Blend(tile, ICON_OVERLAY, 33, 1)
		tiles += list(list("name" = name, "url" = "data:image/png;base64,[icon2base64(tile)]", "wideUrl" = "data:image/png;base64,[icon2base64(wide)]"))
	return tiles
