GLOBAL_LIST_EMPTY(custom_sprite_palettes)
GLOBAL_LIST_EMPTY(custom_sprite_paint_icons)
GLOBAL_LIST_EMPTY(custom_sprite_limb_icons)
GLOBAL_LIST_EMPTY(custom_sprite_hair_bounds)
GLOBAL_LIST_EMPTY(custom_sprite_limb_masks)

/// A blank in every editable direction, including bald hairstyles without an icon state.
/proc/custom_sprite_blank_icon()
	var/icon/result = new
	var/icon/blank = icon('icons/blanks/32x32.dmi', "nothing")
	for(var/direction in GLOB.cardinals)
		result.Insert(blank, "", direction)
	return result

/// Keep runtime caches bounded. Callers treat cached icons/lists as immutable.
/proc/custom_sprite_cache_put(list/cache, key, value, limit = 256)
	if(length(cache) >= limit && !(key in cache))
		cache.Cut(1, 2)
	cache[key] = value
	return value

/// Sample the most frequent opaque shades from all four authored directions.
/proc/custom_sprite_sample_palette(icon_file, icon_state)
	var/key = "[icon_file]|[icon_state]"
	var/list/cached = GLOB.custom_sprite_palettes[key]
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
					var/color = lowertext(rgb(channels[1], channels[2], channels[3]))
					counts[color]++
	var/list/palette = list()
	while(length(counts) && length(palette) < 15)
		var/most_frequent
		for(var/color in counts)
			if(isnull(most_frequent) || counts[color] > counts[most_frequent])
				most_frequent = color
		palette += most_frequent
		counts -= most_frequent
	if(!length(palette))
		palette = list("#ffffff", "#d8d8d8", "#b0b0b0")
	custom_sprite_cache_put(GLOB.custom_sprite_palettes, key, palette)
	return palette.Copy()

/// Match the Custom palette's frontend multiplication and nearest-integer channel rounding.
/proc/custom_sprite_tint_color(color, tint)
	if(!tint)
		return color
	var/list/color_rgb = rgb2num(color)
	var/list/tint_rgb = rgb2num(tint)
	return rgb(round(color_rgb[1] * tint_rgb[1] / 255 + 0.5), round(color_rgb[2] * tint_rgb[2] / 255 + 0.5), round(color_rgb[3] * tint_rgb[3] / 255 + 0.5))

/// Bake effective hair color into source shades; gradients already supply their own RGB.
/proc/custom_sprite_sample_hair_palette(datum/sprite_accessory/hair/hairstyle, obj/item/bodypart/head/head)
	var/list/palette = custom_sprite_sample_palette(hairstyle?.icon, hairstyle?.icon_state)
	if(!head)
		return palette
	var/list/hair_rgb = rgb2num(head.override_hair_color || head.fixed_hair_color || head.hair_color)
	var/list/shades = palette
	palette = list()
	for(var/shade in shades)
		var/list/shade_rgb = rgb2num(shade)
		palette |= rgb(shade_rgb[1] * hair_rgb[1] / 255, shade_rgb[2] * hair_rgb[2] / 255, shade_rgb[3] * hair_rgb[3] / 255)
	var/gradient_style = head.get_hair_gradient_style(GRADIENT_HAIR_KEY)
	if(gradient_style == SPRITE_ACCESSORY_NONE || !SSaccessories.hair_gradients_list[gradient_style])
		return palette
	var/gradient_color = custom_sprite_color(head.get_hair_gradient_color(GRADIENT_HAIR_KEY))
	if(gradient_color)
		palette |= gradient_color
	return palette

/proc/custom_sprite_hydrate(datum/sprite_editor_workspace/workspace, list/drawing)
	if(!drawing)
		return
	var/list/palette = drawing["palette"]
	for(var/direction in drawing["dirs"])
		var/grid = custom_sprite_decode_grid(drawing["dirs"][direction], length(palette))
		if(!grid)
			continue
		var/list/frame = workspace.layers[1]["data"][direction]
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/position = (y - 1) * 32 + x
				var/index = findtextEx(CUSTOM_SPRITE_INDEX_ALPHABET, copytext(grid, position, position + 1)) - 1
				frame[y][x] = index > 0 ? "[palette[index]]ff" : "#00000000"

/// Called by debounced previews and appearance rendering, never by the per-stroke UI payload.
/proc/custom_sprite_paint_icon(list/drawing)
	if(!drawing)
		return null
	var/key = custom_sprite_pixel_hash(drawing)
	var/icon/cached = GLOB.custom_sprite_paint_icons[key]
	if(cached)
		return cached
	var/datum/sprite_editor_workspace/workspace = new(32, 32, 4, initial_layer_color = "#00000000")
	custom_sprite_hydrate(workspace, drawing)
	var/icon/paint = workspace.to_icon()
	qdel(workspace)
	if(paint)
		custom_sprite_cache_put(GLOB.custom_sprite_paint_icons, key, paint)
	return paint

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
/proc/custom_sprite_icon_bounds(icon/source, direction, padding = 1)
	var/min_x = 32
	var/min_y = 32
	var/max_x = -1
	var/max_y = -1
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(!source.GetPixel(x + 1, 32 - y, "", direction))
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)
	if(max_x < 0)
		return null
	return list(max(0, min_x - padding), max(0, min_y - padding), min(31, max_x + padding), min(31, max_y + padding))

/proc/custom_sprite_hair_draw_bounds(datum/sprite_accessory/hair/hairstyle)
	var/key = "[hairstyle?.icon]|[hairstyle?.icon_state]"
	if(GLOB.custom_sprite_hair_bounds[key])
		return deep_copy_list(GLOB.custom_sprite_hair_bounds[key])
	var/list/bounds = list()
	var/icon/source = hairstyle ? icon(hairstyle.icon, hairstyle.icon_state) : null
	for(var/direction in GLOB.cardinals)
		var/list/extent = source ? custom_sprite_icon_bounds(source, direction, 4) : null
		bounds["[direction]"] = list(min(6, extent ? extent[1] : 6), 0, max(25, extent ? extent[3] : 25), max(20, extent ? extent[4] : 20))
	custom_sprite_cache_put(GLOB.custom_sprite_hair_bounds, key, bounds)
	return deep_copy_list(bounds)

/proc/custom_sprite_body_draw_bounds(mob/living/carbon/human/body, body_zone)
	var/icon/silhouette = custom_sprite_blank_icon()
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		if(body_zone && limb.body_zone != body_zone)
			continue
		if(limb.bodyshape & BODYSHAPE_TAUR || IS_STUMP(limb))
			continue
		silhouette.Blend(custom_sprite_silhouette(limb), ICON_OVERLAY)
		if(limb.aux_zone)
			silhouette.Blend(custom_sprite_silhouette(limb, TRUE), ICON_OVERLAY)
	var/list/bounds = list()
	for(var/direction in GLOB.cardinals)
		bounds["[direction]"] = custom_sprite_icon_bounds(silhouette, direction)
	return bounds

/// Row strings keep the wire payload small and test the same silhouette used by rendering.
/proc/custom_sprite_body_draw_mask(mob/living/carbon/human/body, body_zone)
	var/obj/item/bodypart/limb = body.get_bodypart(body_zone)
	var/supported = limb && !(limb.bodyshape & BODYSHAPE_TAUR) && !IS_STUMP(limb)
	var/key = supported ? "[limb.custom_sprite_icon_file()]|[custom_sprite_limb_state(limb)]|[limb.aux_zone]" : "empty"
	if(GLOB.custom_sprite_limb_masks[key])
		return GLOB.custom_sprite_limb_masks[key]
	var/icon/silhouette = custom_sprite_blank_icon()
	if(supported)
		silhouette.Blend(custom_sprite_silhouette(limb), ICON_OVERLAY)
		if(limb.aux_zone)
			silhouette.Blend(custom_sprite_silhouette(limb, TRUE), ICON_OVERLAY)
	var/list/mask = list()
	for(var/direction in GLOB.cardinals)
		var/list/rows = list()
		for(var/y in 0 to 31)
			var/row = ""
			for(var/x in 0 to 31)
				row += silhouette.GetPixel(x + 1, 32 - y, "", direction) ? "1" : "0"
			rows += row
		mask["[direction]"] = rows
	return custom_sprite_cache_put(GLOB.custom_sprite_limb_masks, key, mask)
