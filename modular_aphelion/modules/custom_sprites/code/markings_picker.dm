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
