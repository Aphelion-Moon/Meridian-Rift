/datum/preference_middleware/custom_sprites
	action_delegations = list("open_custom_sprite_editor" = PROC_REF(open_editor))

/datum/preference_middleware/custom_sprites/get_ui_data(mob/user)
	return list("allow_custom_sprite_editing" = CONFIG_GET(flag/allow_custom_sprite_editing))

/datum/preference_middleware/custom_sprites/apply_to_human(mob/living/carbon/human/target, datum/preferences/preferences, visuals_only = FALSE)
	preferences.load_custom_sprites()
	target.dna.custom_hair = preferences.custom_hair ? deep_copy_list(preferences.custom_hair) : null
	target.dna.custom_markings = preferences.custom_markings ? deep_copy_list(preferences.custom_markings) : null
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
	if(!(target in list("hair", "markings")))
		return FALSE
	var/datum/custom_sprite_editor/editor = preferences.custom_sprite_editors[target]
	if(!editor)
		editor = new(preferences, target)
		preferences.custom_sprite_editors[target] = editor
	editor.ui_interact(user)
	return TRUE

/// One slot-bound, short-lived owner for each independent editor window.
/datum/custom_sprite_editor
	var/datum/preferences/preferences
	var/datum/sprite_editor_workspace/custom_sprite/workspace
	var/mob/living/carbon/human/dummy/preview_body
	var/target
	var/slot
	var/list/draft
	var/draft_hash
	var/preview_hash
	var/preview_timer
	var/closing = FALSE
	var/list/guide_urls = list()
	var/list/preview_urls = list()
	var/list/unsupported_zones = list()

/datum/custom_sprite_editor/New(datum/preferences/preferences, target)
	src.preferences = preferences
	src.target = target
	slot = preferences.default_slot
	preferences.load_custom_sprites()
	preview_body = new
	preferences.apply_prefs_to(preview_body, TRUE, visuals_only = TRUE)
	var/list/saved = target == "hair" ? preferences.custom_hair : preferences.custom_markings
	var/list/palette
	var/list/bounds
	if(target == "hair")
		var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
		palette = custom_sprite_sample_palette(hairstyle?.icon, hairstyle?.icon_state)
		bounds = custom_sprite_hair_draw_bounds(hairstyle)
		preview_body.dna.custom_hair = null
	else
		bounds = custom_sprite_body_draw_bounds(preview_body)
		palette = sample_marking_palette()
		preview_body.dna.custom_markings = null
		for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
			if(limb.bodyshape & BODYSHAPE_TAUR)
				unsupported_zones += limb.body_zone
	workspace = new(saved, palette, bounds)
	draft = workspace.serialize_drawing()
	draft_hash = custom_sprite_hash(draft)
	preview_body.sync_custom_sprite_appearance()
	preview_body.update_body(is_creating = TRUE)
	for(var/direction in GLOB.cardinals)
		var/icon/guide = getFlatIcon(preview_body, defdir = direction, no_anim = TRUE)
		guide.Crop(1, 1, 32, 32)
		if(target == "hair")
			var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
			guide.Shift(SOUTH, hairstyle?.y_offset || 0)
			if(LAZYFIND(preview_body.dna.species.offset_features, OFFSET_HAIR))
				guide.Shift(WEST, preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_W])
				guide.Shift(SOUTH, preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_Z])
		guide_urls["[direction]"] = publish_icon(guide)
	refresh_preview()

/datum/custom_sprite_editor/Destroy()
	if(preview_timer)
		deltimer(preview_timer)
	SStgui.close_uis(src)
	QDEL_NULL(workspace)
	QDEL_NULL(preview_body)
	preferences = null
	draft = null
	return ..()

/datum/custom_sprite_editor/proc/sample_marking_palette()
	for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
		for(var/marking_name in limb.markings)
			var/datum/body_marking/marking = GLOB.body_markings[marking_name]
			if(!marking)
				continue
			var/gender_suffix = limb.body_zone == BODY_ZONE_CHEST && marking.gendered ? (limb.is_dimorphic ? "_[limb.limb_gender]" : "_m") : ""
			var/digi = limb.bodyshape & BODYSHAPE_DIGITIGRADE ? "digitigrade_" : ""
			return custom_sprite_sample_palette(marking.icon, "[marking.icon_state]_[digi][limb.body_zone][gender_suffix]")
	return custom_sprite_sample_palette(null, null)

/datum/custom_sprite_editor/proc/publish_icon(icon/rendered)
	var/list/asset = generate_and_hash_rsc_file(rendered)
	var/name = "custom-sprite-[asset[2]].png"
	SSassets.transport.register_asset(name, asset[1])
	SSassets.transport.send_assets(preferences.parent, name)
	return SSassets.transport.get_asset_url(name)

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
	editor_data["serverPalette"] = workspace.palette
	var/list/edited = list()
	for(var/direction in list("2", "1", "4", "8"))
		edited[direction] = !!draft?["dirs"]?[direction]
	return list("editorData" = editor_data, "tint" = workspace.tint, "guides" = guide_urls, "previews" = preview_urls, "edited" = edited, "drawBounds" = workspace.draw_bounds, "unsupportedZones" = unsupported_zones)

/datum/custom_sprite_editor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_edit(ui.user))
		return
	switch(action)
		if("spriteEditorCommand")
			switch(params["command"])
				if("transaction")
					if(!workspace.new_transaction(params["transaction"]))
						return FALSE
				if("undo")
					workspace.undo(isnull(params["count"]) ? 1 : params["count"])
				if("redo")
					workspace.redo(isnull(params["count"]) ? 1 : params["count"])
				else
					return FALSE
		if("clear")
			if(!workspace.clear_direction(params["dir"]))
				return FALSE
		if("pickTint")
			var/color = tgui_color_picker(ui.user, "Choose a tint for the drawing.", "Drawing tint", workspace.tint || "#ffffff")
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			workspace.tint = custom_sprite_color(color)
		if("resetTint")
			workspace.tint = null
		if("save")
			finish(TRUE)
			return TRUE
		if("discard")
			finish(FALSE)
			return TRUE
		else
			return FALSE
	draft = workspace.serialize_drawing()
	var/new_hash = custom_sprite_hash(draft)
	if(new_hash != draft_hash)
		draft_hash = new_hash
		if(preview_timer)
			deltimer(preview_timer)
		preview_timer = addtimer(CALLBACK(src, PROC_REF(refresh_preview)), 0.6 SECONDS, TIMER_STOPPABLE)
	return TRUE

/datum/custom_sprite_editor/proc/refresh_preview()
	preview_timer = null
	if(closing || preview_hash == draft_hash)
		return
	if(target == "hair")
		preview_body.dna.custom_hair = draft ? deep_copy_list(draft) : null
	else
		preview_body.dna.custom_markings = draft ? deep_copy_list(draft) : null
	preview_body.sync_custom_sprite_appearance()
	preview_body.update_body(is_creating = TRUE)
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = getFlatIcon(preview_body, defdir = direction, no_anim = TRUE)
		rendered.Crop(1, 1, 32, 32)
		preview_urls["[direction]"] = publish_icon(rendered)
	preview_hash = draft_hash
	SStgui.update_uis(src)

/datum/custom_sprite_editor/ui_close(mob/user)
	finish(TRUE)

/datum/custom_sprite_editor/proc/finish(save_changes = TRUE)
	if(closing)
		return
	closing = TRUE
	if(preview_timer)
		deltimer(preview_timer)
		preview_timer = null
	if(save_changes && preferences && preferences.default_slot == slot)
		preferences.save_custom_sprite(target, workspace.serialize_drawing(), slot)
	if(preferences)
		preferences.custom_sprite_editors -= target
	SStgui.close_uis(src)
	preferences?.character_preview_view?.update_body()
	qdel(src)
