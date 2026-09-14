/// Editing can be disabled without removing any saved appearance.
/datum/config_entry/flag/allow_custom_sprite_editing
	default = TRUE

/datum/preference_middleware/custom_sprites
	action_delegations = list("open_custom_sprite_editor" = PROC_REF(open_editor))

/datum/preference_middleware/custom_sprites/get_ui_data(mob/user)
	return list("allow_custom_sprite_editing" = CONFIG_GET(flag/allow_custom_sprite_editing))

/datum/preference_middleware/custom_sprites/apply_to_human(mob/living/carbon/human/target, datum/preferences/preferences, visuals_only = FALSE)
	preferences.load_custom_sprites()
	var/allow_emissives = preferences.read_preference(/datum/preference/toggle/allow_emissives)
	target.dna.custom_hair = custom_sprite_appearance_drawing(preferences.custom_hair, allow_emissives)
	target.dna.custom_markings = custom_sprite_appearance_drawing(preferences.custom_markings, allow_emissives)
	target.dna.custom_limb_markings = null
	for(var/body_zone in preferences.custom_limb_markings)
		LAZYSET(target.dna.custom_limb_markings, body_zone, custom_sprite_appearance_drawing(preferences.custom_limb_markings[body_zone], allow_emissives))
	target.sync_custom_sprite_appearance()

/datum/preference_middleware/custom_sprites/pre_set_preference(mob/user, preference, value)
	// A style/species change must not leave an editor using the old palette or geometry.
	preferences.close_custom_sprite_editors()
	return FALSE

/datum/preference_middleware/custom_sprites/on_new_character(mob/user)
	preferences.load_custom_sprites()

/datum/preference_middleware/custom_sprites/proc/open_editor(list/params, mob/user)
	if(!CONFIG_GET(flag/allow_custom_sprite_editing) || user?.client != preferences.parent)
		return FALSE
	var/target = params["target"]
	var/body_zone = params["body_zone"]
	if(!(target in list("hair", "markings")) || (!isnull(body_zone) && (target != "markings" || !istext(body_zone) || !(body_zone in GLOB.custom_marking_zone_labels))))
		return FALSE
	var/editor_key = body_zone ? "[target]:[body_zone]" : target
	var/datum/custom_sprite_editor/editor = preferences.custom_sprite_editors[editor_key]
	if(!editor)
		editor = new(preferences, target, body_zone)
		preferences.custom_sprite_editors[editor_key] = editor
	editor.ui_interact(user)
	return TRUE

/// One slot-bound, short-lived owner for each independent editor window.
/datum/custom_sprite_editor
	var/datum/preferences/preferences
	var/datum/sprite_editor_workspace/custom_sprite/workspace
	var/mob/living/carbon/human/dummy/preview_body
	var/target
	var/body_zone
	var/editor_key
	var/slot
	var/list/draft
	var/preview_hash
	var/preview_timer
	var/closing = FALSE
	var/save_revision = 0
	var/save_error
	var/selected_color
	var/selected_custom_color
	var/color_mode = "literal"
	var/custom_tint = "#ffffff"
	var/list/guide_icons = list()
	var/list/guide_urls = list()
	var/list/preview_urls = list()
	var/list/unsupported_zones = list()
	var/list/sampled_palette
	var/list/guide_palette = list()

/datum/custom_sprite_editor/New(datum/preferences/preferences, target, body_zone)
	src.preferences = preferences
	src.target = target
	src.body_zone = body_zone
	editor_key = body_zone ? "[target]:[body_zone]" : target
	slot = preferences.default_slot
	preferences.load_custom_sprites()
	preview_body = new
	preferences.apply_prefs_to(preview_body, TRUE, visuals_only = TRUE)
	var/list/saved = target == "hair" ? preferences.custom_hair : preferences.custom_markings
	if(body_zone)
		saved = preferences.custom_limb_markings?[body_zone]
	var/list/palette
	var/list/bounds
	var/list/mask
	if(target == "hair")
		var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
		palette = custom_sprite_sample_hair_palette(hairstyle, preview_body.get_bodypart(BODY_ZONE_HEAD))
		bounds = custom_sprite_hair_draw_bounds(hairstyle)
		preview_body.dna.custom_hair = null
	else
		bounds = custom_sprite_body_draw_bounds(preview_body, body_zone)
		if(body_zone)
			mask = custom_sprite_body_draw_mask(preview_body, body_zone)
		palette = sample_marking_palette()
		preview_body.dna.custom_markings = null
		preview_body.dna.custom_limb_markings = null
		for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
			if(limb.bodyshape & BODYSHAPE_TAUR)
				unsupported_zones += limb.body_zone
	sampled_palette = palette
	workspace = new(saved, palette | preferences.read_preference(/datum/preference/custom_sprite_palette), bounds, mask)
	// Explicit tints already render as a separate overlay: bake their RGB while retaining its alpha.
	if(workspace.tint && workspace.tint != "#ffffff")
		var/list/colors = list()
		for(var/color in workspace.palette)
			colors["[color]ff"] = "[custom_sprite_tint_color(color, workspace.tint)]ff"
		for(var/direction in workspace.layers[1]["data"])
			var/list/frame = workspace.layers[1]["data"][direction]
			for(var/list/row as anything in frame)
				for(var/x in 1 to length(row))
					if(colors[row[x]])
						row[x] = colors[row[x]]
		workspace.palette = workspace.used_colors()
		workspace.update_palette(palette | preferences.read_preference(/datum/preference/custom_sprite_palette))
		workspace.tint = "#ffffff"
	else if(!saved || target == "markings")
		workspace.tint = "#ffffff"
	selected_color = workspace.palette[1]
	// This dummy has preference underwear but no equipped outfit. Hide underwear only for the guides.
	var/preview_underwear_visibility = preview_body.underwear_visibility
	preview_body.underwear_visibility = UNDERWEAR_HIDE_ALL
	preview_body.sync_custom_sprite_appearance(refresh_body = TRUE)
	for(var/direction in GLOB.cardinals)
		var/icon/guide = getFlatIcon(preview_body, defdir = direction, no_anim = TRUE)
		guide.Crop(1, 1, 32, 32)
		if(target == "hair")
			var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
			guide.Shift(SOUTH, hairstyle?.y_offset || 0)
			if(LAZYFIND(preview_body.dna.species.offset_features, OFFSET_HAIR))
				guide.Shift(WEST, preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_W])
				guide.Shift(SOUTH, preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_Z])
		guide_icons["[direction]"] = guide
		guide_urls["[direction]"] = publish_icon(guide)
	preview_body.underwear_visibility = preview_underwear_visibility
	refresh_preview()

/datum/custom_sprite_editor/Destroy()
	if(preview_timer)
		deltimer(preview_timer)
	SStgui.close_uis(src)
	QDEL_NULL(workspace)
	QDEL_NULL(preview_body)
	preferences = null
	draft = null
	guide_icons = null
	return ..()

/datum/custom_sprite_editor/proc/sample_marking_palette()
	var/list/colors = list()
	for(var/feature in list(FEATURE_MUTANT_COLOR, FEATURE_MUTANT_COLOR_TWO, FEATURE_MUTANT_COLOR_THREE))
		var/color = custom_sprite_color(preview_body.dna.features[feature])
		if(color)
			colors |= color
	var/list/shades = sample_marking_shades()
	if(!length(colors))
		return shades
	var/list/palette = colors.Copy()
	for(var/shade in shades)
		var/list/shade_rgb = rgb2num(shade)
		for(var/color in colors)
			var/list/color_rgb = rgb2num(color)
			palette |= rgb(shade_rgb[1] * color_rgb[1] / 255, shade_rgb[2] * color_rgb[2] / 255, shade_rgb[3] * color_rgb[3] / 255)
			if(length(palette) >= 15)
				return palette
	return palette

/datum/custom_sprite_editor/proc/sample_marking_shades()
	for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
		if(body_zone && limb.body_zone != body_zone)
			continue
		for(var/marking_name in limb.markings)
			var/datum/body_marking/marking = GLOB.body_markings[marking_name]
			if(!marking)
				continue
			var/gender_suffix = limb.body_zone == BODY_ZONE_CHEST && marking.gendered ? (limb.is_dimorphic ? "_[limb.limb_gender]" : "_m") : ""
			var/digi = limb.bodyshape & BODYSHAPE_DIGITIGRADE ? "digitigrade_" : ""
			return custom_sprite_sample_palette(marking.icon, "[marking.icon_state]_[digi][limb.body_zone][gender_suffix]")
	return custom_sprite_sample_palette(null, null)

/datum/custom_sprite_editor/proc/publish_icon(icon/rendered)
	// Small, private previews live with this editor, without global asset/CDN registrations.
	return "data:image/png;base64,[icon2base64(rendered)]"

/datum/custom_sprite_editor/proc/can_edit(mob/user)
	return !closing && preferences && user?.client == preferences.parent && slot == preferences.default_slot && CONFIG_GET(flag/allow_custom_sprite_editing)

/datum/custom_sprite_editor/ui_state(mob/user)
	return GLOB.always_state

/datum/custom_sprite_editor/ui_status(mob/user, datum/ui_state/state)
	return can_edit(user) ? UI_INTERACTIVE : UI_CLOSE

/datum/custom_sprite_editor/ui_interact(mob/user, datum/tgui/ui)
	if(!can_edit(user))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, target == "hair" ? "CustomHairEditor" : "CustomMarkingsEditor", target == "hair" ? "Custom Hair" : "Custom Markings")
		ui.set_autoupdate(FALSE)
		ui.open()

/datum/custom_sprite_editor/ui_data(mob/user)
	var/list/editor_data = workspace.sprite_editor_ui_data()
	var/list/custom_palette = preferences.read_preference(/datum/preference/custom_sprite_palette)
	// Paint/history admission must not add swatches; only style shades and explicit guide picks do.
	editor_data["serverPalette"] = (sampled_palette | guide_palette) & workspace.palette
	editor_data["serverSelectedColor"] = selected_color
	return list("editorData" = editor_data, "customTint" = custom_tint, "displayTint" = custom_palette_tint(), "colorMode" = color_mode, "emissive" = workspace.emissive, "emissiveAllowed" = preferences.read_preference(/datum/preference/toggle/allow_emissives), "saveRevision" = save_revision, "saveError" = save_error, "customPalette" = custom_palette, "availableColors" = workspace.palette, "maxCustomColors" = CUSTOM_SPRITE_MAX_CUSTOM_COLORS, "guides" = guide_urls, "previews" = preview_urls, "edited" = workspace.edited_directions, "drawBounds" = workspace.draw_bounds, "drawMask" = workspace.draw_mask, "bodyZone" = body_zone, "bodyZoneLabel" = GLOB.custom_marking_zone_labels[body_zone], "unsupportedZones" = unsupported_zones)

/datum/custom_sprite_editor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_edit(ui.user))
		return
	switch(action)
		if("selectColor")
			if(!workspace.is_valid_color(params["color"]))
				return FALSE
			selected_color = lowertext(copytext(params["color"], 1, 8))
			selected_custom_color = null
			return TRUE
		if("selectCustomColor")
			var/color = custom_sprite_color(params["color"])
			if(!(color in preferences.read_preference(/datum/preference/custom_sprite_palette)))
				return FALSE
			var/transformed = custom_sprite_tint_color(color, custom_palette_tint())
			if(!(transformed in workspace.palette))
				return FALSE
			selected_custom_color = color
			selected_color = transformed
			return TRUE
		if("sampleGuide")
			return sample_guide(params["dir"], params["x"], params["y"])
		if("savePaletteColor")
			if(!workspace.is_valid_color(params["color"]))
				return FALSE
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors | lowertext(copytext(params["color"], 1, 8)))
		if("addPaletteColor")
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			if(length(colors) >= CUSTOM_SPRITE_MAX_CUSTOM_COLORS)
				return FALSE
			var/color = tgui_color_picker(ui.user, "Choose a color to save for all your characters.", "Custom palette", selected_color || "#ffffff")
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors | custom_sprite_color(color))
		if("removePaletteColor")
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors - custom_sprite_color(params["color"]))
		if("spriteEditorCommand")
			switch(params["command"])
				if("transaction")
					if(!workspace.new_transaction(params["transaction"]))
						return FALSE
				if("undo")
					var/history_length = length(workspace.undo_stack)
					workspace.undo(isnull(params["count"]) ? 1 : params["count"])
					if(length(workspace.undo_stack) == history_length)
						return TRUE
				if("redo")
					var/history_length = length(workspace.redo_stack)
					workspace.redo(isnull(params["count"]) ? 1 : params["count"])
					if(length(workspace.redo_stack) == history_length)
						return TRUE
				else
					return FALSE
		if("clear")
			if(!workspace.clear_direction(params["dir"]))
				return FALSE
		if("setEmissive")
			var/direction = params["dir"]
			var/enabled = params["enabled"]
			if(!istext(direction) || !(direction in workspace.emissive) || !isnum(enabled) || !(enabled in list(TRUE, FALSE)) || (enabled && !preferences.read_preference(/datum/preference/toggle/allow_emissives)))
				return FALSE
			if(workspace.emissive[direction] == enabled)
				return TRUE
			workspace.emissive = workspace.emissive.Copy()
			workspace.emissive[direction] = enabled
		if("pickTint")
			var/color = tgui_color_picker(ui.user, "Choose a color to blend with Custom palette brushes.", "Custom palette blending", custom_tint)
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			custom_tint = custom_sprite_color(color)
			color_mode = "tint"
			refresh_custom_palette()
			return TRUE
		if("setColorMode")
			var/mode = params["mode"]
			if(!(mode in list("literal", "hair", "tint")) || (mode == "hair" && target != "hair"))
				return FALSE
			if(mode == color_mode)
				return TRUE
			color_mode = mode
			refresh_custom_palette()
			return TRUE
		if("save")
			finish(TRUE)
			return TRUE
		if("saveDraft")
			if(!save_drawing())
				return TRUE
			preferences.character_preview_view?.update_body()
			return TRUE
		if("discard")
			finish(FALSE)
			return TRUE
		else
			return FALSE
	if(preview_timer)
		deltimer(preview_timer)
	preview_timer = addtimer(CALLBACK(src, PROC_REF(refresh_preview)), 0.6 SECONDS, TIMER_STOPPABLE)
	return TRUE

/// Prefer current paint over the retained native guide, including strokes newer than the browser's view.
/datum/custom_sprite_editor/proc/sample_guide(direction, x, y)
	if(!istext(direction) || !(direction in workspace.layers[1]["data"]) || !workspace.valid_point_pair(list(x, y)) || x < 0 || x > 31 || y < 0 || y > 31)
		return FALSE
	var/list/frame = workspace.layers[1]["data"][direction]
	var/list/channels = split_color(frame[y + 1][x + 1])
	if(!channels[4])
		var/icon/guide = guide_icons[direction]
		var/pixel = guide?.GetPixel(x + 1, 32 - y)
		if(!pixel)
			return FALSE
		channels = split_color(pixel)
		if(!channels[4])
			return FALSE
	var/color = lowertext(rgb(channels[1], channels[2], channels[3]))
	if(!(color in workspace.palette) && !workspace.update_palette(sampled_palette | transformed_custom_palette() | list(color)))
		return FALSE
	selected_color = color
	selected_custom_color = null
	guide_palette = (guide_palette | color) & workspace.palette
	return TRUE

/// Brush effects are editor state, never a mutation of existing drawing pixels.
/datum/custom_sprite_editor/proc/custom_palette_tint()
	if(color_mode == "tint")
		return custom_tint
	if(color_mode == "hair")
		var/obj/item/bodypart/head/head = preview_body.get_bodypart(BODY_ZONE_HEAD)
		return head?.override_hair_color || head?.fixed_hair_color || head?.hair_color
	return null

/datum/custom_sprite_editor/proc/transformed_custom_palette()
	var/list/colors = list()
	var/tint = custom_palette_tint()
	for(var/color in preferences.read_preference(/datum/preference/custom_sprite_palette))
		colors |= custom_sprite_tint_color(color, tint)
	return colors

/datum/custom_sprite_editor/proc/refresh_custom_palette()
	var/list/available = sampled_palette | transformed_custom_palette()
	// An unpainted guide brush is still active even though no drawing/history pixel uses it yet.
	if(!selected_custom_color && selected_color)
		available |= selected_color
	workspace.update_palette(available)
	if(selected_custom_color)
		var/transformed = custom_sprite_tint_color(selected_custom_color, custom_palette_tint())
		if((selected_custom_color in preferences.read_preference(/datum/preference/custom_sprite_palette)) && (transformed in workspace.palette))
			selected_color = transformed
		else
			selected_custom_color = null
	if(!(selected_color in workspace.palette))
		selected_color = length(workspace.palette) ? workspace.palette[1] : null

/// Account colors save immediately; discarding a character drawing does not discard its palette.
/datum/custom_sprite_editor/proc/set_custom_palette(list/colors)
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/custom_sprite_palette]
	if(!preference.is_valid(colors, preferences) || json_encode(colors) == json_encode(preferences.read_preference(preference.type)))
		return FALSE
	preferences.update_preference(preference, colors)
	preferences.save_preferences()
	for(var/editor_target in preferences.custom_sprite_editors)
		var/datum/custom_sprite_editor/editor = preferences.custom_sprite_editors[editor_target]
		// A full drawing keeps its admitted colors; other saved swatches remain visible but disabled.
		editor.refresh_custom_palette()
		SStgui.update_uis(editor)
	return TRUE

/datum/custom_sprite_editor/proc/refresh_preview()
	preview_timer = null
	if(closing)
		return
	draft = workspace.serialize_drawing()
	var/new_hash = custom_sprite_hash(draft)
	if(preview_hash == new_hash)
		return
	var/allow_emissives = preferences.read_preference(/datum/preference/toggle/allow_emissives)
	var/list/appearance_draft = custom_sprite_appearance_drawing(draft, allow_emissives)
	if(target == "hair")
		preview_body.dna.custom_hair = appearance_draft
	else
		preview_body.dna.custom_markings = body_zone ? custom_sprite_appearance_drawing(preferences.custom_markings, allow_emissives) : appearance_draft
		preview_body.dna.custom_limb_markings = null
		for(var/zone in preferences.custom_limb_markings)
			LAZYSET(preview_body.dna.custom_limb_markings, zone, custom_sprite_appearance_drawing(preferences.custom_limb_markings[zone], allow_emissives))
		if(body_zone)
			if(appearance_draft)
				LAZYSET(preview_body.dna.custom_limb_markings, body_zone, appearance_draft)
			else
				LAZYREMOVE(preview_body.dna.custom_limb_markings, body_zone)
	preview_body.sync_custom_sprite_appearance(refresh_body = TRUE)
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = getFlatIcon(preview_body, defdir = direction, no_anim = TRUE)
		rendered.Crop(1, 1, 32, 32)
		preview_urls["[direction]"] = publish_icon(rendered)
	preview_hash = new_hash
	SStgui.update_uis(src)

/datum/custom_sprite_editor/ui_close(mob/user)
	finish(TRUE)

/datum/custom_sprite_editor/proc/save_drawing()
	if(!preferences.save_custom_sprite(target, workspace.serialize_drawing(), slot, body_zone))
		save_error = "Couldn't save to disk. Your drawing is kept in this session. Press Ctrl+S to retry."
		SStgui.update_uis(src)
		return FALSE
	save_error = null
	save_revision++
	return TRUE

/datum/custom_sprite_editor/proc/finish(save_changes = TRUE)
	if(closing)
		return
	if(save_changes && preferences && preferences.default_slot == slot && !save_drawing())
		return
	closing = TRUE
	if(preview_timer)
		deltimer(preview_timer)
		preview_timer = null
	if(preferences)
		preferences.custom_sprite_editors -= editor_key
	SStgui.close_uis(src)
	preferences?.character_preview_view?.update_body()
	qdel(src)
