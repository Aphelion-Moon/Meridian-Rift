/// Dedicated creator state. Catalog/preview work is lazy and has no map registrations.
/datum/preference_middleware/cyborg_character
	key = "cyborg_character"
	var/page_active = FALSE
	var/preview_model
	var/preview_layout_source = "active"
	var/preview_direction = SOUTH
	var/preview_pose = "idle"
	var/preview_arousal = "none"
	var/preview_moving = FALSE
	var/gallery_open = FALSE
	var/gallery_department
	var/selected_part = "penis"
	var/status_message
	action_delegations = list(
		"cyborg_page" = PROC_REF(set_page),
		"cyborg_preview" = PROC_REF(set_preview),
		"cyborg_layout" = PROC_REF(edit_layout),
	)

/datum/preference_middleware/cyborg_character/proc/set_page(list/params, mob/user)
	var/active = params["active"] == TRUE
	if(active == page_active)
		return TRUE
	page_active = active
	if(page_active)
		preview_layout_source = "active"
		selected_part = "penis"
	if(!page_active)
		gallery_open = FALSE
		gallery_department = null
		preferences.cyborg_layout_flush_draft("leave_cyborg_page")
		preferences.save_character()
		preferences.save_preferences()
	return TRUE

/datum/preference_middleware/cyborg_character/proc/set_preview(list/params, mob/user)
	if(!page_active)
		return FALSE
	var/list/catalog = cyborg_catalog_for(preferences, "creator")
	if(istext(params["model"]) && catalog[params["model"]])
		if(preview_model != params["model"])
			preview_layout_source = "active"
		preview_model = params["model"]
		var/list/draft = preferences.cyborg_layout_begin_draft()
		if(draft)
			draft["active_model"] = preview_model
			preferences.cyborg_layout_update_draft(draft)
		preview_pose = "idle"
	if(params["direction"] in GLOB.cardinals)
		preview_direction = params["direction"]
	var/list/descriptor = catalog[preview_model]
	if(descriptor && (params["pose"] in descriptor["poses"]))
		preview_pose = params["pose"]
	if(params["arousal"] in list("none", "partial", "full"))
		preview_arousal = params["arousal"]
	if(!isnull(params["moving"]))
		preview_moving = params["moving"] == TRUE
	if(params["selected_part"] in cyborg_layout_supported_slots())
		selected_part = params["selected_part"]
	if(!isnull(params["gallery_open"]))
		gallery_open = params["gallery_open"] == TRUE
	if(istext(params["gallery_department"]))
		for(var/id in catalog)
			if(catalog[id]["department"] == params["gallery_department"])
				gallery_department = params["gallery_department"]
				break
	if(params["layout_source"] == "active")
		preview_layout_source = "active"
	else if(params["layout_source"] == "model_default")
		var/list/store = preferences.cyborg_layout_begin_draft()
		var/list/defaults = store?["model_defaults"]
		if(islist(defaults) && islist(defaults[preview_model]))
			preview_layout_source = "model_default"
		else
			preview_layout_source = "active"
	return TRUE

/datum/preference_middleware/cyborg_character/proc/edit_layout(list/params, mob/user)
	if(!page_active || params["character_slot"] != preferences.default_slot)
		return FALSE
	if(!cyborg_visuals_allowed(preferences))
		status_message = "Enable the relevant character preferences first."
		return TRUE
	if(preview_layout_source == "model_default" && params["operation"] in list("set", "place", "reset", "reset_position", "reset_colors", "reset_overrides", "save", "save_default"))
		status_message = "Load this model default into the active layout before editing it."
		return TRUE
	var/list/store = preferences.cyborg_layout_begin_draft()
	if(!store)
		status_message = "This slot contains a newer layout schema. Its saved data has been preserved."
		return TRUE
	if(params["operation"] in list("save", "save_default"))
		for(var/part_slot in cyborg_layout_supported_slots())
			store["active"][part_slot]["sprite"] = cyborg_preference_value(preferences, "silicon_[part_slot]_sprite")
	var/list/result = cyborg_layout_action(store, params, preview_model)
	status_message = result["message"]
	if(result["store"])
		if(result["model"])
			preview_model = result["model"]
			preview_pose = "idle"
			gallery_department = cyborg_model_catalog()[preview_model]["department"]
		if(params["operation"] in list("load", "load_default"))
			for(var/part_slot in cyborg_layout_supported_slots())
				var/sprite = result["store"]["active"][part_slot]["sprite"]
				var/datum/preference/preference = GLOB.preference_entries_by_key["silicon_[part_slot]_sprite"]
				if(!isnull(sprite) && preference.is_valid(sprite, preferences))
					preferences.update_preference(preference, sprite)
		preferences.cyborg_layout_update_draft(result["store"])
		if(params["operation"] in list("load", "load_default", "delete_default"))
			preview_layout_source = "active"
		if(params["operation"] in list("save", "delete", "save_default", "delete_default", "assign_default"))
			preferences.cyborg_layout_flush_draft("explicit_preset")
			preferences.save_character()
			preferences.save_preferences()
	return TRUE

/datum/preference_middleware/cyborg_character/get_ui_data(mob/user)
	if(!page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return list()
	var/list/catalog = cyborg_catalog_for(preferences, "creator")
	if(!catalog[preview_model] && length(catalog))
		var/list/draft = preferences.cyborg_layout_begin_draft()
		preview_model = catalog[draft?["active_model"]] ? draft["active_model"] : catalog[1]
		preview_layout_source = "active"
	var/list/descriptor = catalog[preview_model]
	var/list/store = preferences.cyborg_layout_begin_draft()
	if(!store)
		return list("cyborg_customization" = list("unsupported" = TRUE, "message" = "This slot contains a newer layout schema. Its saved data has been preserved; use a compatible server or another character slot."))
	var/layout_source = preview_layout_source
	var/list/preview_layout = store["active"]
	var/list/defaults = store["model_defaults"]
	if(layout_source == "model_default")
		if(islist(defaults) && islist(defaults[preview_model]))
			preview_layout = defaults[preview_model]
		else
			layout_source = "active"
			preview_layout_source = "active"
	var/list/models = list()
	for(var/id in catalog)
		var/list/model_entry = catalog[id]
		var/list/model = list("id" = id, "department" = model_entry["department"], "skin" = model_entry["skin"])
		if(gallery_open && gallery_department && model_entry["department"] == gallery_department)
			var/list/directions = list()
			for(var/direction in GLOB.cardinals)
				directions["[direction]"] = cyborg_preview_body(model_entry, direction)
			model["thumbnail_directions"] = directions
		models += list(model)
	var/list/parts = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/choice = cyborg_preference_value(preferences, "silicon_[slot]_sprite")
		var/list/part_entry = preview_layout[slot]
		if(layout_source == "model_default" && !isnull(part_entry["sprite"]))
			choice = part_entry["sprite"]
		parts[slot] = cyborg_accessory_metadata(slot, choice, part_entry?["colors"] || list("#ffffff", "#ffffff", "#ffffff"), preview_arousal, descriptor ? cyborg_part_sprite_direction(descriptor, part_entry, preview_direction) : SOUTH, part_entry?["sprite_size"] || cyborg_layout_default_sprite_size(slot), slot == selected_part)
	var/list/dimensions = descriptor ? get_icon_dimensions(descriptor["icon"]) : list()
	return list("cyborg_customization" = list(
		"models" = models,
		"model" = preview_model,
		"poses" = descriptor ? descriptor["poses"] : list(),
		"pose" = preview_pose,
		"direction" = preview_direction,
		"arousal" = preview_arousal,
		"body" = cyborg_preview_body(descriptor, preview_direction, preview_pose),
		"occlusion" = cyborg_visuals_allowed(preferences) ? cyborg_preview_body(descriptor, preview_direction, preview_pose, TRUE) : null,
		"allowed" = cyborg_visuals_allowed(preferences),
		"moving" = preview_moving,
		"gallery_open" = gallery_open,
		"gallery_department" = gallery_department,
		"animation" = cyborg_preview_animation(descriptor, preview_direction, preview_pose, preview_moving, cyborg_visuals_allowed(preferences)),
		"body_width" = dimensions["width"] || 32,
		"body_height" = dimensions["height"] || 32,
		"map_view" = getviewsize(user?.client?.view || world.view),
		"map_zoom" = user?.client?.view_size?.zoom || 0,
		"wide" = descriptor && (TRAIT_R_WIDE in descriptor["features"]),
		"reference" = cyborg_preview_reference(),
		"body_scale" = descriptor ? cyborg_effective_base_size(cyborg_preference_value(preferences, "cyborg_size"), descriptor["features"]) : 1,
		"store" = store,
		"layout_source" = layout_source,
		"model_default_available" = islist(defaults) && islist(defaults[preview_model]),
		"layers" = cyborg_preview_layers(preferences, descriptor, preview_layout, preview_direction, preview_pose, preview_arousal, layout_source == "model_default"),
		"parts" = parts,
		"message" = status_message,
	))

/datum/preference_middleware/cyborg_character/on_new_character(mob/user)
	preview_model = null
	selected_part = "penis"
	status_message = null
	preview_layout_source = "active"
	gallery_open = FALSE
	gallery_department = null

/datum/preference_middleware/cyborg_character/on_ui_close()
	page_active = FALSE
	status_message = null
	gallery_open = FALSE
	gallery_department = null

/// Creator layout action protocol; the middleware owns slot and actor checks.
/proc/cyborg_layout_action(list/store, list/params, model_id)
	var/list/next = cyborg_layout_normalize(store)
	var/message = "Working setup updated."
	var/restored_model
	var/operation = params["operation"]
	var/slot = params["slot"]
	var/group = params["placement_group"]
	if(!isnull(group) && !(group in list("north", "south", "side")))
		return list("message" = "Unknown placement group.")
	if(operation in list("set", "place", "reset_position", "reset_colors", "reset_overrides") && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	if(operation == "reset" && !isnull(slot) && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	switch(operation)
		if("set")
			var/field = params["field"]
			if(!(field in list("pixel_x", "pixel_y", "rotation", "scale", "sprite_size", "mirror_sides", "reuse_south", "colors", "advanced")))
				return list("message" = "Unknown layout field.")
			if(field == "advanced" && !cyborg_layout_advanced_action_is_bounded(params["value"]))
				return list("message" = "The directional layout is too large or contains unsupported entries.")
			if(field == "colors" && (!islist(params["value"]) || length(params["value"]) > 3))
				return list("message" = "Choose up to three colors.")
			if(group && field in list("pixel_x", "pixel_y", "rotation"))
				var/list/position = cyborg_layout_edit_position(next["active"][slot], group)
				position[field] = params["value"]
			else
				next["active"][slot][field] = params["value"]
		if("place")
			if(!isnum(params["x"]) || !isnum(params["y"]))
				return list("message" = "Placement requires numeric coordinates.")
			var/list/position = cyborg_layout_edit_position(next["active"][slot], group)
			position["pixel_x"] = cyborg_layout_number(params["x"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1)
			position["pixel_y"] = cyborg_layout_number(params["y"], CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET, 0, 1)
		if("reset_position")
			next["active"][slot]["placement_groups"] = list()
			next["active"][slot]["pixel_x"] = 0
			next["active"][slot]["pixel_y"] = 0
			next["active"][slot]["rotation"] = 0
			next["active"][slot]["scale"] = 1
		if("reset_colors")
			next["active"][slot]["colors"] = list("#ffffff", "#ffffff", "#ffffff")
		if("reset_overrides")
			next["active"][slot]["advanced"] = list()
		if("reset")
			if(slot in cyborg_layout_supported_slots())
				next["active"][slot] = null
			else
				next["active"] = null
		if("save", "load", "delete")
			var/name = params["name"]
			if(!istext(name))
				return list("message" = "Enter a preset name.")
			name = trim(name)
			if(!length(name) || length_char(name) > 24)
				return list("message" = "Preset names must be 1 to 24 characters.")
			var/list/presets = next["presets"]
			if(operation == "save")
				if(presets[name] && params["overwrite"] != TRUE)
					return list("message" = "That preset exists. Use Update preset to replace it.")
				if(!presets[name] && length(presets) >= 10)
					return list("message" = "Ten presets are already saved. Delete one first.")
				presets[name] = cyborg_layout_copy(next["active"])
				if(model_id && cyborg_model_catalog()[model_id])
					next["preset_models"][name] = model_id
				else
					next["preset_models"] -= name
				next["active_preset"] = name
				for(var/assigned_model in next["model_presets"])
					if(next["model_presets"][assigned_model] != name)
						continue
					if(assigned_model == model_id)
						next["model_defaults"][assigned_model] = cyborg_layout_copy(presets[name])
					else
						next["model_presets"] -= assigned_model
				message = "Preset saved."
			else
				if(!presets[name])
					return list("message" = "That preset no longer exists.")
				if(operation == "load")
					next["active"] = cyborg_layout_copy(presets[name])
					next["active_preset"] = name
					restored_model = next["preset_models"][name]
					if(restored_model)
						next["active_model"] = restored_model
					message = "Preset loaded."
				else
					presets -= name
					next["preset_models"] -= name
					if(next["active_preset"] == name)
						next -= "active_preset"
					for(var/assigned_model in next["model_presets"])
						if(next["model_presets"][assigned_model] == name)
							next["model_presets"] -= assigned_model
					message = "Preset deleted."
		if("assign_default")
			var/name = params["name"]
			if(!istext(name) || !next["presets"][name] || !cyborg_model_catalog()[model_id])
				return list("message" = "Select a saved preset and chassis first.")
			var/preset_model = next["preset_models"][name]
			if(preset_model && preset_model != model_id)
				return list("message" = "Load this preset to switch to its chassis first.")
			next["preset_models"][name] = model_id
			next["model_defaults"][model_id] = cyborg_layout_copy(next["presets"][name])
			next["model_presets"][model_id] = name
			message = "[name] will load when a new body selects this chassis."
		if("save_default", "load_default", "delete_default")
			var/list/catalog = cyborg_model_catalog()
			if(!catalog[model_id])
				return list("message" = "Select an eligible model first.")
			var/list/defaults = next["model_defaults"]
			if(operation in list("save_default", "delete_default"))
				next["model_presets"] -= model_id
			if(operation == "save_default")
				defaults[model_id] = cyborg_layout_copy(next["active"])
			else if(operation == "delete_default")
				defaults -= model_id
			else if(defaults[model_id])
				next["active"] = cyborg_layout_copy(defaults[model_id])
				next["active_preset"] = next["model_presets"][model_id]
			else
				return list("message" = "This model has no saved default.")
	if(!(operation in list("set", "place", "reset", "reset_position", "reset_colors", "reset_overrides", "save", "load", "delete", "assign_default", "save_default", "load_default", "delete_default")))
		return list("message" = "Unknown layout action.")
	return list("store" = cyborg_layout_normalize(next), "message" = message, "model" = restored_model)

/// Materialize just the edited view group, preserving legacy fallback elsewhere.
/proc/cyborg_layout_edit_position(list/entry, group)
	if(!group)
		return entry
	if(!entry["placement_groups"][group])
		entry["placement_groups"][group] = list("pixel_x" = entry["pixel_x"], "pixel_y" = entry["pixel_y"], "rotation" = entry["rotation"])
	return entry["placement_groups"][group]
