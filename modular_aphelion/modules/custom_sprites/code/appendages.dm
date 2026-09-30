/// The HAIR_APPENDAGE zones an appendage can attach at, in the editor's order: crown, forehead, sides, back of the head, then hair down the front and back.
GLOBAL_LIST_INIT(custom_hair_appendage_zones, list(HAIR_APPENDAGE_TOP, HAIR_APPENDAGE_FRONT, HAIR_APPENDAGE_LEFT, HAIR_APPENDAGE_RIGHT, HAIR_APPENDAGE_REAR, HAIR_APPENDAGE_HANGING_FRONT, HAIR_APPENDAGE_HANGING_REAR))

/// Exact fields of one appendage in a drawing.
GLOBAL_LIST_INIT(custom_hair_appendage_keys, list("name", "zone", "outer", "dirs", "emissive"))

/// An appendage name as saved: tags, stray angle brackets, backslashes and control characters removed, spaces collapsed, at most CUSTOM_SPRITE_MAX_APPENDAGE_NAME characters. Null when nothing is left.
/proc/custom_hair_appendage_name(raw)
	// Anything longer came from no name field; don't run the patterns over it.
	if(!istext(raw) || length(raw) > 256)
		return null
	var/static/regex/tags = regex(@"<[^>]*>", "g")
	var/static/regex/unsafe = regex(@"[<>\\\x00-\x1F\x7F]", "g")
	var/static/regex/spaces = regex(@"\s+", "g")
	var/name = unsafe.Replace(spaces.Replace(tags.Replace(raw, ""), " "), "")
	name = trimtext(copytext_char(trimtext(spaces.Replace(name, " ")), 1, CUSTOM_SPRITE_MAX_APPENDAGE_NAME + 1))
	return length(name) ? name : null

/// An appendage's painted views, re-encoded canonically. Unreadable and empty views are left out.
/proc/custom_hair_appendage_views(list/raw_dirs, palette_size, pixel_count)
	. = list()
	if(!islist(raw_dirs))
		return
	for(var/direction in GLOB.custom_style_directions)
		var/grid = custom_sprite_decode_grid(raw_dirs[direction], palette_size, pixel_count)
		if(grid && spantext(grid, "0") != pixel_count)
			.[direction] = custom_sprite_encode_grid(grid, palette_size, pixel_count)

/**
 * A drawing's appendages as they are saved, keyed "1", "2", "3" in order, or null when none are left.
 *
 * The keys are strings so deep_copy_list() copies each record instead of turning it into a key. An
 * entry that isn't a record, attaches at an unknown zone, sits neither under nor over hats or has no
 * paint is dropped on its own, and a missing or unusable name becomes "Appendage N". Entries past
 * CUSTOM_SPRITE_MAX_APPENDAGES are dropped.
 */
/proc/custom_hair_appendages_validate(list/raw_appendages, palette_size, pixel_count)
	if(!islist(raw_appendages))
		return null
	var/list/clean = list()
	for(var/_key, entry in raw_appendages)
		if(length(clean) >= CUSTOM_SPRITE_MAX_APPENDAGES)
			break
		var/list/raw = entry
		if(!islist(raw) || !(raw["zone"] in GLOB.custom_hair_appendage_zones) || !(raw["outer"] in list(FALSE, TRUE)))
			continue
		var/list/directions = custom_hair_appendage_views(raw["dirs"], palette_size, pixel_count)
		if(!length(directions))
			continue
		var/index = length(clean) + 1
		clean["[index]"] = list("name" = custom_hair_appendage_name(raw["name"]) || "Appendage [index]", "zone" = raw["zone"], "outer" = raw["outer"], "dirs" = directions, "emissive" = custom_sprite_emissive_settings(raw["emissive"]))
	return length(clean) ? clean : null

/**
 * Strictly validates a style file's appendages, as custom_style_validate_drawing() does its views.
 * Nothing is salvaged, and messages never repeat uploaded text.
 *
 * Arguments:
 * - raw_appendages: The decoded "appendages" object, keyed "1", "2", "3" in order.
 * - legacy: Accepts stored styles, where empty views and emission settings may be absent.
 *
 * Returns list("appendages" = canonical appendages) or list("error" = message).
 */
/proc/custom_hair_appendages_validate_strict(list/raw_appendages, palette_size, pixel_count, legacy = FALSE)
	if(!islist(raw_appendages) || length(raw_appendages) > CUSTOM_SPRITE_MAX_APPENDAGES)
		return list("error" = "The drawing's appendages are malformed or more than [CUSTOM_SPRITE_MAX_APPENDAGES].")
	var/list/clean = list()
	for(var/key, entry in raw_appendages)
		var/index = length(clean) + 1
		var/label = "Appendage [index]"
		var/list/raw = entry
		if(key != "[index]" || !islist(raw) || custom_style_unknown_key(raw, GLOB.custom_hair_appendage_keys))
			return list("error" = "[label] is malformed.")
		for(var/field in (legacy ? list("name", "zone", "outer", "dirs") : GLOB.custom_hair_appendage_keys))
			if(!(field in raw))
				return list("error" = "[label] is missing \"[field]\".")
		var/name = custom_hair_appendage_name(raw["name"])
		if(!name || name != raw["name"])
			return list("error" = "[label]'s name must be 1 to [CUSTOM_SPRITE_MAX_APPENDAGE_NAME] characters, without markup.")
		if(!(raw["zone"] in GLOB.custom_hair_appendage_zones))
			return list("error" = "[label] attaches at an unknown part of the head.")
		if(!(raw["outer"] in list(FALSE, TRUE)))
			return list("error" = "[label] must sit under or over hats.")
		var/list/raw_dirs = raw["dirs"]
		if(!islist(raw_dirs) || custom_style_unknown_key(raw_dirs, GLOB.custom_style_directions))
			return list("error" = "[label]'s views are malformed.")
		var/list/directions = list()
		for(var/direction in GLOB.custom_style_directions)
			if(!(direction in raw_dirs))
				if(!legacy)
					return list("error" = "[label] is missing its [GLOB.custom_style_direction_labels[direction]] view.")
				continue
			var/grid = custom_sprite_decode_grid(raw_dirs[direction], palette_size, pixel_count)
			if(!grid)
				return list("error" = "[label]'s [GLOB.custom_style_direction_labels[direction]] view has invalid pixel data.")
			if(spantext(grid, "0") != pixel_count)
				directions[direction] = custom_sprite_encode_grid(grid, palette_size, pixel_count)
		if(!length(directions))
			return list("error" = "[label] has no paint.")
		var/emissive_problem = custom_style_emissive_problem(raw, legacy)
		if(emissive_problem)
			return list("error" = "[label]'s [emissive_problem]")
		clean["[index]"] = list("name" = name, "zone" = raw["zone"], "outer" = raw["outer"], "dirs" = directions, "emissive" = custom_sprite_emissive_settings(raw["emissive"]))
	return list("appendages" = length(clean) ? clean : null)

/// Appendages in export form: every view and emission setting spelled out, keyed as saved. Null without any.
/proc/custom_hair_appendages_export(list/appendages, palette_size, pixel_count)
	if(!length(appendages))
		return null
	. = list()
	var/empty = custom_sprite_encode_grid(repeat_string(pixel_count, "0"), palette_size, pixel_count)
	for(var/key, entry in appendages)
		var/list/appendage = entry
		var/list/dirs = list()
		for(var/direction in GLOB.custom_style_directions)
			dirs[direction] = appendage["dirs"][direction] || empty
		.[key] = list("name" = appendage["name"], "zone" = appendage["zone"], "outer" = appendage["outer"], "dirs" = dirs, "emissive" = custom_sprite_emissive_settings(appendage["emissive"]))

/// Bounded cache of under-hat appendage paint trimmed by the worn masks that strictly cover it, keyed by pixels, lift and masks.
GLOBAL_LIST_EMPTY(custom_hair_appendage_icons)

/**
 * The worn hair masks that trim an appendage, or null when they hide it.
 *
 * As with a hairstyle's own pieces: an under-hat piece is trimmed only by masks whose strict coverage
 * includes its zone, and an over-hat piece is never trimmed but is left out while any worn mask
 * strictly covers its zone.
 */
/obj/item/bodypart/head/proc/custom_appendage_masks(list/appendage)
	. = list()
	for(var/datum/hair_mask/mask as anything in owner?.hair_masks)
		if(!(mask.strict_coverage_zones & appendage["zone"]))
			continue
		if(appendage["outer"])
			return null
		. += mask

/// Adds each appendage after the hair's paint: under-hat pieces on the hair layer, over-hat pieces above headwear.
/obj/item/bodypart/head/proc/append_custom_appendage_overlays(list/hair_overlays, datum/sprite_accessory/hair/hairstyle, dropped)
	for(var/_key, entry in custom_hair?["appendages"])
		var/list/appendage = entry
		var/list/masks = custom_appendage_masks(appendage)
		if(isnull(masks))
			continue
		var/list/layer_drawing = list("version" = custom_hair["version"], "palette" = custom_hair["palette"], "dirs" = appendage["dirs"])
		var/icon/paint = custom_sprite_paint_icon(layer_drawing)
		if(!paint)
			continue
		var/list/geometry = list("hair-appendage", custom_sprite_pixel_hash(layer_drawing), hairstyle.y_offset)
		for(var/datum/hair_mask/mask as anything in masks)
			geometry += "[mask.icon]|[mask.icon_state]"
		var/geometry_key = json_encode(geometry)
		if(length(masks))
			var/icon/masked = GLOB.custom_hair_appendage_icons[geometry_key]
			if(!masked)
				masked = icon(paint)
				for(var/datum/hair_mask/mask as anything in masks)
					var/icon/mask_icon = icon(mask.icon, mask.icon_state)
					mask_icon.Shift(SOUTH, hairstyle.y_offset)
					// Tall paint reaches above the mask, which carries on upward as its top row does.
					masked.Blend(custom_sprite_extend_up(mask_icon, masked.Height()), ICON_ADD)
				custom_sprite_cache_put(GLOB.custom_hair_appendage_icons, geometry_key, masked)
			paint = masked
		append_custom_paint_image(hair_overlays, paint, custom_hair["tint"], appendage["emissive"], appendage["outer"] ? -OUTER_HAIR_LAYER : -HAIR_LAYER, geometry_key, hairstyle, dropped)

/// The hats the hair editor's Try on offers, one for each hair mask the game's hats use, keyed as the window names them.
GLOBAL_LIST_INIT(custom_hair_try_on_hats, list(
	"hardhat" = list("label" = "Hard hat", "group" = "Berets and hard hats", "item" = /obj/item/clothing/head/utility/hardhat, "mask" = /datum/hair_mask/standard_hat_middle),
	"fedora" = list("label" = "Fedora", "group" = "Fedoras and security helmets", "item" = /obj/item/clothing/head/fedora, "mask" = /datum/hair_mask/standard_hat_low),
	"hood" = list("label" = "Winter hood", "group" = "Winter hoods and hoodies", "item" = /obj/item/clothing/head/hooded/winterhood, "mask" = /datum/hair_mask/winterhood),
))

/**
 * Where a try-on hat's hair mask keeps and trims paint on the hair canvas: per view, `height` rows,
 * top row first, of eight hex digits. Each digit is four pixels, the leftmost in its high bit: set
 * where the mask keeps paint, clear where it trims. That's a quarter of a character a pixel, and the
 * window sends these with every rebuild. The mask is lowered by the hairstyle's `y_offset` and
 * carried upward as its top row, as it is on the paint itself. Cached.
 */
/proc/custom_hair_try_on_mask_rows(hat_key, height, y_offset)
	var/static/list/cache = list()
	var/key = "[hat_key]|[height]|[y_offset]"
	if(cache[key])
		return cache[key]
	var/datum/hair_mask/mask = SSaccessories.hair_masks_list[GLOB.custom_hair_try_on_hats[hat_key]["mask"]]
	var/icon/mask_icon = icon(mask.icon, mask.icon_state)
	mask_icon.Shift(SOUTH, y_offset)
	mask_icon = custom_sprite_extend_up(mask_icon, height)
	var/list/views = list()
	for(var/direction in GLOB.custom_style_directions)
		var/list/rows = list()
		for(var/y in height to 1 step -1)
			var/row = ""
			for(var/first in 1 to 29 step 4)
				var/value = 0
				for(var/x in first to first + 3)
					value = value * 2 + (mask_icon.GetPixel(x, y, "", text2num(direction)) ? 1 : 0)
				row += copytext("0123456789abcdef", value + 1, value + 2)
			rows += row
		views[direction] = rows
	return custom_sprite_cache_put(cache, key, views, 32)

/// A try-on hat as the hair canvas shows it, per view: its worn sprite placed against paint drawn `lift` = list(x, z) off the tile. Data URLs, cached.
/proc/custom_hair_try_on_views(hat_key, height, list/lift)
	var/static/list/cache = list()
	var/lift_x = lift?[1] || 0
	var/lift_z = lift?[2] || 0
	var/key = "[hat_key]|[height]|[lift_x]|[lift_z]"
	if(cache[key])
		return cache[key]
	var/obj/item/clothing/head/hat_type = GLOB.custom_hair_try_on_hats[hat_key]["item"]
	var/list/views = list()
	for(var/direction in GLOB.custom_style_directions)
		var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
		canvas.Crop(1, 1, 32, height)
		// The worn sprite, as the mob wears it before any body offset.
		var/icon/worn = icon(initial(hat_type.worn_icon), initial(hat_type.worn_icon_state) || initial(hat_type.icon_state), text2num(direction))
		canvas.Blend(worn, ICON_OVERLAY, 1 - lift_x, 1 - lift_z + initial(hat_type.worn_y_offset))
		views[direction] = "data:image/png;base64,[icon2base64(canvas)]"
	return custom_sprite_cache_put(cache, key, views, 32)

/**
 * The window's Try on hats for a hair canvas `height` tall, drawn `lift` off the tile, over a
 * hairstyle lifted `y_offset`. The window crops its "Hats that cover it" chips from the front
 * views itself: BYOND exports an icon smaller than a tile padded out to 32 by 32.
 */
/proc/custom_hair_try_on_ui_data(height, list/lift, y_offset)
	. = list()
	for(var/key, hat in GLOB.custom_hair_try_on_hats)
		var/datum/hair_mask/mask = SSaccessories.hair_masks_list[hat["mask"]]
		.[key] = list("label" = hat["label"], "group" = hat["group"], "strict" = mask.strict_coverage_zones, "masks" = custom_hair_try_on_mask_rows(key, height, y_offset), "views" = custom_hair_try_on_views(key, height, lift))

/// The hat a try-on puts on the preview: its worn sprite on the head layer, placed as the body places head items.
/proc/custom_hair_try_on_image(hat_key, mob/living/carbon/human/body)
	var/obj/item/clothing/head/hat_type = GLOB.custom_hair_try_on_hats[hat_key]["item"]
	var/image/worn = image(initial(hat_type.worn_icon), icon_state = initial(hat_type.worn_icon_state) || initial(hat_type.icon_state), layer = -HEAD_LAYER)
	worn.pixel_z = initial(hat_type.worn_y_offset)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	head?.worn_head_offset?.apply_offset(worn)
	return worn

/// The hair editor's appendage layers and Try on hat.
/datum/custom_sprite_editor
	/// The Try on hat the window shows while an appendage layer is chosen, or null. Only previews wear it.
	var/try_on
	/// An appendage layer id the window switches to on its next update, after adding or copying one.
	var/focus_layer

/**
 * Adds, removes, renames, moves or copies one of the hair's appendage layers, as an undoable step.
 * Everything the window names is checked first: the layer by id, the zone, the kind, the name.
 *
 * Returns whether the draft changed.
 */
/datum/custom_sprite_editor/proc/appendage_act(action, list/params)
	if(target != "hair")
		return FALSE
	if(action == "addAppendage")
		focus_layer = workspace.add_appendage()
		return !!focus_layer
	var/layer = workspace.layer_index(params["id"])
	if(layer < 2)
		return FALSE
	switch(action)
		if("removeAppendage")
			return workspace.remove_appendage(layer)
		if("renameAppendage")
			var/name = custom_hair_appendage_name(params["name"])
			return name && workspace.set_appendage(layer, "name", name)
		if("setAppendageZone")
			var/zone = params["zone"]
			return (zone in GLOB.custom_hair_appendage_zones) && workspace.set_appendage(layer, "zone", zone)
		if("setAppendageKind")
			var/outer = params["outer"]
			return (outer in list(FALSE, TRUE)) && workspace.set_appendage(layer, "outer", outer)
		if("copyToOverHat")
			focus_layer = workspace.copy_appendage_over(layer)
			return !!focus_layer
	return FALSE

/// Puts a Try on hat on the previews, or takes it off. Previews follow after the usual pause, as they do edits.
/datum/custom_sprite_editor/proc/set_try_on(hat)
	if(target != "hair" || !(isnull(hat) || (istext(hat) && GLOB.custom_hair_try_on_hats[hat])) || hat == try_on)
		return FALSE
	try_on = hat
	preview_timer = addtimer(CALLBACK(src, PROC_REF(request_refresh)), 0.6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_STOPPABLE)
	return TRUE

/// The hair's appendage layers as the window lists them, in order.
/datum/custom_sprite_editor/proc/appendage_ui_data()
	. = list()
	for(var/layer in 2 to length(workspace.layers))
		var/list/entry = workspace.layers[layer]
		. += list(list("id" = entry["id"], "name" = entry["name"], "zone" = entry["zone"], "outer" = entry["outer"], "edited" = entry["edited"], "emissive" = entry["emissive"]))

/// Turns one appendage layer's glow on or off for a view, like the hair's own setting. Returns whether it changed.
/datum/custom_sprite_editor/proc/set_appendage_emissive(layer, direction, enabled)
	var/list/entry = workspace.layers[layer]
	if(entry["emissive"][direction] == enabled)
		return FALSE
	var/list/emissive = entry["emissive"]
	emissive = emissive.Copy()
	emissive[direction] = enabled
	entry["emissive"] = emissive
	workspace.pixels_dirty = TRUE
	return TRUE

/// The draft's unpainted appendage layers and where they sit among the others, which a drawing can't carry through a canvas resize.
/datum/sprite_editor_workspace/custom_sprite/proc/unpainted_appendages()
	. = list()
	for(var/layer in 2 to length(layers))
		if(!layer_painted(layer))
			var/list/entry = layers[layer]
			. += list(list("position" = layer, "name" = entry["name"], "zone" = entry["zone"], "outer" = entry["outer"], "emissive" = entry["emissive"]))

/// Puts unpainted appendage layers back where they were, after a canvas resize rebuilt the draft from its saved form.
/datum/sprite_editor_workspace/custom_sprite/proc/restore_unpainted_appendages(list/unpainted)
	for(var/list/appendage as anything in unpainted)
		add_appendage_layer(appendage, position = appendage["position"])

/// Whether a stroke names the layer it paints: appendage layers are named by id as well, so a stroke meant for one that undo just moved can't land on another.
/datum/sprite_editor_workspace/custom_sprite/proc/stroke_layer_matches(list/transaction)
	var/layer = transaction["layer"]
	return layer == 1 || (valid_layer(layer, 2) && transaction["layerId"] == layers[layer]["id"])
