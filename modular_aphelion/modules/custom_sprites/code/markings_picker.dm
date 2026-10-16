/// Immutable per-zone marking classes, shared by character setup and tattoo editors.
/proc/custom_sprite_marking_icons()
	var/static/list/icons_by_zone
	if(icons_by_zone)
		return icons_by_zone
	if(!length(GLOB.body_markings_per_limb))
		return list()
	icons_by_zone = list()
	for(var/zone, choices in GLOB.body_markings_per_limb)
		var/list/icons = list()
		for(var/name in choices)
			icons[name] = "body_marking___[zone]___[md5(name)]"
		icons_by_zone[zone] = icons
	return icons_by_zone

/**
 * Full-size mirror sprite classes for markings whose sheet is larger than a tile. The ordinary 32x32 markings
 * reuse their picker sprite. Kept beside the picker in the same preferences asset, so hovering requests no drawing.
 */
/proc/custom_sprite_native_marking_icons()
	var/static/list/native_icons
	if(native_icons)
		return native_icons
	if(!length(GLOB.body_markings_per_limb))
		return list()
	native_icons = list()
	for(var/zone, icons in custom_sprite_marking_icons())
		for(var/name, sprite_class in icons)
			var/datum/body_marking/marking = GLOB.body_markings[name]
			var/list/dimensions = get_icon_dimensions(marking.icon)
			var/width = dimensions["width"]
			var/height = dimensions["height"]
			if(width == 32 && height == 32)
				continue
			if(!icon_exists(marking.icon, marking.zone_icon_state(zone) || marking.zone_icon_state(zone, digitigrade = TRUE)))
				continue
			LAZYSET(native_icons[zone], name, "preferences[width]x[height] [sprite_class]_native")
	return native_icons

/// Adds each zone's native marking once to the same cached sheet used by hair preferences.
/proc/custom_sprite_insert_marking_icons(datum/asset/spritesheet_batched/preferences/sheet)
	for(var/zone, icons in custom_sprite_marking_icons())
		for(var/name, sprite_class in icons)
			var/datum/body_marking/marking = GLOB.body_markings[name]
			var/icon_file = marking.icon
			// The state a male chest and a plantigrade leg draw, or a digitigrade leg for a marking with art for no other.
			var/icon_state = marking.zone_icon_state(zone) || marking.zone_icon_state(zone, digitigrade = TRUE)
			// Every zone a marking is offered on has its art; one a sheet still lacked would preview blank.
			if(!icon_exists(icon_file, icon_state))
				icon_file = 'icons/blanks/32x32.dmi'
				icon_state = "nothing"
			var/datum/universal_icon/preview = uni_icon(icon_file, icon_state, SOUTH)
			var/list/dimensions = get_icon_dimensions(icon_file)
			var/width = dimensions["width"]
			var/height = dimensions["height"]
			if(width != 32 || height != 32)
				// The mirror paints in native pixels; only its picker thumbnail is scaled below.
				var/datum/universal_icon/native = uni_icon(icon_file, icon_state, SOUTH)
				native.map_colors_rgba(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 3)
				sheet.insert_icon("[sprite_class]_native", native)
				var/scale = min(1, 32 / max(width, height))
				width = max(1, round(width * scale))
				height = max(1, round(height * scale))
				preview.scale(width, height)
				var/left = round((32 - width) / 2)
				var/bottom = round((32 - height) / 2)
				preview.crop(1 - left, 1 - bottom, 32 - left, 32 - bottom)
			// Many markings are faint shading; tripled opacity shows their shape in pickers.
			preview.map_colors_rgba(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 3)
			sheet.insert_icon(sprite_class, preview)

/// Salon artists reuse the preferences sheet already cached by the client.
/datum/custom_sprite_editor/markings/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/spritesheet_batched/preferences))

/**
 * What the editor's marking sheets know of the body they show, as a key: its species and the three mutant colours its
 * markings can follow. The static data carries it, and a window holding sheets made for another asks for them again.
 */
/datum/custom_sprite_editor/markings/proc/marking_sheets_key()
	var/list/features = preview_body?.dna?.features
	return "[preview_body?.dna?.species?.id] [features?[FEATURE_MUTANT_COLOR]] [features?[FEATURE_MUTANT_COLOR_TWO]] [features?[FEATURE_MUTANT_COLOR_THREE]]"

/**
 * Sends the window what its marking sheets draw from, the first time it opens one, as character setup's markings room
 * has it: each marking the editor's zones can take, with its colour mode, exclusion group and species; the colour each
 * fixed one starts in, and the body's three mutant colours for the rest; and the body's species, whose bare body is under
 * every thumbnail. The species' body sheet and the room's art come first, so the sheet draws whole as it opens. In an
 * update of its own: the window keeps it, and nothing else sends it again.
 *
 * Arguments:
 * - ui: The editor's window.
 * - known: The key of the sheets' data the window holds already, if any.
 */
/datum/custom_sprite_editor/markings/proc/send_marking_sheets(datum/tgui/ui, known)
	set waitfor = FALSE
	var/key = marking_sheets_key()
	if(known == key || !preview_body)
		return
	var/list/info = list()
	var/list/defaults = list()
	for(var/zone in GLOB.custom_marking_zone_labels)
		for(var/name in GLOB.body_markings_per_limb[zone])
			if(info[name])
				continue
			var/datum/body_marking/marking = GLOB.body_markings[name]
			info[name] = list(
				"color_mode" = marking.color_mode,
				"exclusion_group" = marking.exclusion_group,
				"recommended_species" = marking.recommended_species ? jointext(marking.recommended_species, ",") : null,
			)
			if(marking.color_mode == MARKING_COLOR_FIXED_DEFAULT || marking.color_mode == MARKING_COLOR_LOCKED)
				defaults[name] = sanitize_hexcolor(marking.default_color)
	var/list/features = preview_body.dna.features
	var/datum/species/species = preview_body.dna.species
	var/client/viewer = ui.user.client
	var/list/art = list(
		get_asset_datum(/datum/asset/spritesheet_batched/species_full/body),
		get_asset_datum(/datum/asset/simple/markings_room),
	)
	// The files have to arrive before the window hears of their stylesheets, or what asks for one at once stays blank.
	var/sent = FALSE
	for(var/datum/asset/asset as anything in art)
		sent |= asset.send(viewer)
	if(sent)
		viewer?.browse_queue_flush()
	for(var/datum/asset/asset as anything in art)
		ui.send_asset(asset)
	ui.send_update(list("markingSheets" = list(
		"key" = key,
		"info" = info,
		"defaults" = defaults,
		"fur" = marking_fur_colors(features),
		"species" = species.id,
		"speciesName" = species.name,
		"speciesIcon" = sanitize_css_class_name(species.name),
	)))
