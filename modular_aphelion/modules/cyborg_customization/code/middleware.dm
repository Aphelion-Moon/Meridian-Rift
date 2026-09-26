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
	/// Per-session private resource payload and its pixel-only dependency key.
	var/list/preview_resources
	var/resource_key
	/// Canonical session-owned store, isolated from presets and the preference cache.
	var/list/draft
	/// Character slot that owns the draft and every pending callback.
	var/draft_slot
	/// Ordinary edit revision; never used as a replacement-session token.
	var/draft_revision = 0
	/// Invalidates frontend actions after slot/model/preset replacement.
	var/context_generation = 0
	/// Stoppable two-second autosave callback.
	var/draft_timer
	/// Whether accepted edits still require a successful native save.
	var/dirty = FALSE
	/// Revision staged by the current native character-save sequence.
	var/staged_revision
	/// Last acknowledged revision and its durability.
	var/saved_revision = 0
	var/session_only = FALSE
	/// A retryable write or staging failure, kept across UI close/reopen.
	var/save_error
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
		commit_draft()
		context_generation++
		preview_resources = null
		resource_key = null
		if(user?.client)
			preferences.update_static_data(user, always_instant = TRUE)
	return TRUE

/datum/preference_middleware/cyborg_character/proc/set_preview(list/params, mob/user)
	if(!page_active || params["context"] != context_generation)
		return FALSE
	if(user && user.client && user.client != preferences.parent)
		return FALSE
	var/list/catalog = cyborg_catalog_for(preferences, "creator")
	if(istext(params["model"]) && catalog[params["model"]])
		if(preview_model != params["model"])
			context_generation++
			preview_layout_source = "active"
		preview_model = params["model"]
		var/list/draft = begin_draft()
		if(draft)
			draft["active_model"] = preview_model
			update_draft(draft)
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
	var/previous_source = preview_layout_source
	if(params["layout_source"] == "active")
		preview_layout_source = "active"
	else if(params["layout_source"] == "model_default")
		var/list/store = begin_draft()
		var/list/defaults = store?["model_defaults"]
		if(islist(defaults) && islist(defaults[preview_model]))
			preview_layout_source = "model_default"
		else
			preview_layout_source = "active"
	if(previous_source != preview_layout_source)
		context_generation++
		// Changing the viewed layout invalidates actions, not the active draft's autosave.
		if(dirty)
			schedule_draft_save()
	return TRUE

/datum/preference_middleware/cyborg_character/proc/edit_layout(list/params, mob/user)
	if(length(params) > 8)
		return FALSE
	if(!page_active || params["character_slot"] != preferences.default_slot || params["context"] != context_generation)
		return FALSE
	if(user && user.client && user.client != preferences.parent)
		return FALSE
	if(params["operation"] == "retry_save")
		commit_draft()
		return TRUE
	if(!cyborg_visuals_allowed(preferences))
		status_message = "Enable the relevant character preferences first."
		return TRUE
	var/list/catalog = cyborg_catalog_for(preferences, "creator")
	if(!catalog[preview_model])
		status_message = "This chassis is no longer available. Select an eligible chassis."
		return TRUE
	if(preview_layout_source == "model_default" && (params["operation"] in list("set", "set_placement", "inherit_placement", "reset", "reset_position", "reset_colors", "reset_overrides", "save", "save_default")))
		status_message = "Load this model default into the active layout before editing it."
		return TRUE
	var/list/store = begin_draft()
	if(!store)
		status_message = "This slot contains a newer layout schema. Its saved data has been preserved."
		return TRUE
	if(params["operation"] in list("save", "save_default"))
		store = deep_copy_list(store)
		for(var/part_slot in cyborg_layout_supported_slots())
			store["active"][part_slot]["sprite"] = cyborg_preference_value(preferences, "silicon_[part_slot]_sprite")
	var/list/result = cyborg_layout_action(store, params, preview_model)
	if(result["model"] && !catalog[result["model"]])
		status_message = "This preset's chassis is no longer available."
		return TRUE
	status_message = result["message"]
	if(result["store"])
		if(params["operation"] in list("load", "load_default", "reset"))
			context_generation++
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
		update_draft(result["store"])
		if(params["operation"] in list("load", "load_default", "delete_default"))
			preview_layout_source = "active"
		if(result["immediate"])
			commit_draft()
	return TRUE

/datum/preference_middleware/cyborg_character/get_ui_data(mob/user)
	if(!page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return list()
	var/list/catalog = cyborg_catalog_for(preferences, "creator")
	if(!catalog[preview_model] && length(catalog))
		var/list/draft = begin_draft()
		preview_model = catalog[draft?["active_model"]] ? draft["active_model"] : catalog[1]
		preview_layout_source = "active"
	var/list/descriptor = catalog[preview_model]
	var/list/store = begin_draft()
	if(!store)
		preview_resources = null
		resource_key = null
		if(user?.client)
			preferences.update_static_data(user, always_instant = TRUE)
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
	refresh_resources(user, catalog, descriptor, preview_layout, layout_source)
	var/list/layers = cyborg_preview_layers(preferences, descriptor, preview_layout, preview_direction, preview_pose, preview_arousal, layout_source == "model_default")
	for(var/list/layer as anything in layers)
		layer -= "icon"
	return list("cyborg_customization" = list(
		"unsupported" = FALSE,
		"model" = preview_model,
		"poses" = descriptor ? descriptor["poses"] : list(),
		"pose" = preview_pose,
		"direction" = preview_direction,
		"arousal" = preview_arousal,
		"allowed" = cyborg_visuals_allowed(preferences),
		"moving" = preview_moving,
		"gallery_open" = gallery_open,
		"gallery_department" = gallery_department,
		"map_view" = getviewsize(user?.client?.view || world.view),
		"map_zoom" = user?.client?.view_size?.zoom || 0,
		"wide" = descriptor && (TRAIT_R_WIDE in descriptor["features"]),
		"body_scale" = descriptor ? cyborg_effective_base_size(cyborg_preference_value(preferences, "cyborg_size"), descriptor["features"]) : 1,
		"context" = context_generation,
		"revision" = draft_revision,
		"save_status" = list("pending" = dirty, "revision" = saved_revision, "session_only" = session_only, "error" = save_error),
		"store" = store,
		"layout_source" = layout_source,
		"model_default_available" = islist(defaults) && islist(defaults[preview_model]),
		"layers" = layers,
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
	context_generation++
	gallery_open = FALSE
	gallery_department = null
	preview_resources = null
	resource_key = null

/// Creator layout action protocol; the middleware owns slot and actor checks.
/proc/cyborg_layout_action(list/store, list/params, model_id)
	// Owned session data is canonical; copying must not renormalize every preset.
	var/list/next = store.Copy()
	next["active"] = deep_copy_list(store["active"])
	// Collections only replace whole snapshots, so copying their indices is sufficient.
	for(var/key in list("presets", "preset_models", "model_presets", "model_defaults"))
		var/list/collection = store[key]
		next[key] = collection.Copy()
	var/message = "Working setup updated."
	var/restored_model
	var/operation = params["operation"]
	var/slot = params["slot"]
	var/group = params["placement_group"]
	if(!isnull(group) && !(group in list("north", "south", "side")))
		return list("message" = "Unknown placement group.")
	if((operation in list("set", "set_placement", "inherit_placement", "reset_position", "reset_colors", "reset_overrides")) && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	if(operation == "reset" && !isnull(slot) && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	switch(operation)
		if("set_placement", "inherit_placement")
			if(!cyborg_layout_apply_placement(next["active"][slot], params, cyborg_model_catalog()[model_id]))
				return list("message" = "Invalid placement target or values. Refresh the editor and try again.")
		if("set")
			var/field = params["field"]
			if(!(field in list("sprite_size", "mirror_sides", "reuse_south", "colors")))
				return list("message" = "Unknown layout field.")
			if(field == "colors" && (!islist(params["value"]) || length(params["value"]) > 3))
				return list("message" = "Choose up to three colors.")
			if(field != "colors" && !isnum(params["value"]))
				return list("message" = "This setting requires a numeric value.")
			if(field == "colors")
				for(var/color in params["value"])
					if(!istext(color) || length(color) > 9)
						return list("message" = "Choose valid colors.")
			next["active"][slot][field] = params["value"]
			next["active"][slot] = cyborg_layout_normalize_entry(next["active"][slot], slot = slot)
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
				next["active"][slot] = cyborg_layout_default_entry(slot)
			else
				next["active"] = cyborg_layout_default_slots()
		if("save", "load", "delete")
			var/name = params["name"]
			if(!istext(name))
				return list("message" = "Enter a preset name.")
			name = trim(name)
			if(!length(name) || length_char(name) > CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH)
				return list("message" = "Preset names must be 1 to 24 characters.")
			var/list/presets = next["presets"]
			if(operation == "save")
				if(presets[name] && params["overwrite"] != TRUE)
					return list("message" = "That preset exists. Use Update preset to replace it.")
				if(!presets[name] && length(presets) >= CYBORG_LAYOUT_MAX_PRESETS)
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
		else
			return list("message" = "Unknown layout action.")
	return list("store" = next, "message" = message, "model" = restored_model, "immediate" = (operation in list("save", "delete", "save_default", "delete_default", "assign_default")))

/// Materialize just the edited view group, preserving legacy fallback elsewhere.
/proc/cyborg_layout_edit_position(list/entry, group)
	if(!group)
		return entry
	if(!entry["placement_groups"][group])
		entry["placement_groups"][group] = list("pixel_x" = entry["pixel_x"], "pixel_y" = entry["pixel_y"], "rotation" = entry["rotation"])
	return entry["placement_groups"][group]

/** Applies a bounded edit to owned canonical data only after validating every field.
 * First pose edits materialize the old frontend's effective direction entry. A pose
 * entry replaces its direction fallback as a whole; arousal values remain sparse.
 */
/proc/cyborg_layout_apply_placement(list/entry, list/params, list/descriptor)
	var/list/target = params["target"]
	var/list/changes = params["changes"]
	if(!descriptor || !islist(target) || length(target) > 4)
		return FALSE
	for(var/field in target)
		if(!(field in list("scope", "direction", "pose", "arousal")))
			return FALSE
	var/scope = target["scope"]
	var/direction = target["direction"]
	if(isnum(direction) && (direction in GLOB.cardinals))
		direction = LOWER_TEXT(dir2text(direction))
	if(!(direction in list("north", "south", "east", "west")) || !(scope in list("base", "pose", "arousal")))
		return FALSE
	var/pose = target["pose"]
	var/arousal = target["arousal"]
	if(scope != "base" && (!(pose in descriptor["poses"]) || !("[pose]_[direction]" in cyborg_layout_supported_advanced_keys())))
		return FALSE
	if(scope == "arousal" && !(arousal in list("none", "partial", "full")))
		return FALSE
	var/key = "[pose]_[direction]"
	var/list/advanced = entry["advanced"]
	if(params["operation"] == "inherit_placement")
		if(scope == "base" || !isnull(changes))
			return FALSE
		if(scope == "pose")
			advanced -= key
		else
			var/list/states = advanced[key]?["arousal"]
			states -= arousal
		return TRUE
	if(!islist(changes) || !length(changes) || length(changes) > 6)
		return FALSE
	for(var/field in changes)
		if(!(field in list("pixel_x", "pixel_y", "rotation", "scale", "visible", "priority")) || !isnum(changes[field]))
			return FALSE
		if(scope == "base" && (field in list("visible", "priority")))
			return FALSE
	var/list/values = cyborg_layout_normalize_advanced_entry(changes, FALSE)
	if(scope == "base")
		var/group = (TRAIT_R_WIDE in descriptor["features"]) ? (direction == "north" ? "north" : direction == "south" ? "south" : "side") : null
		var/list/position = cyborg_layout_edit_position(entry, group)
		for(var/field in values)
			if(field == "scale")
				entry[field] = values[field]
			else
				position[field] = values[field]
		return TRUE
	var/list/directional = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "scale" = 1, "priority" = 5)
	var/list/inherited = advanced[key] || advanced[direction]
	if(inherited)
		for(var/field in inherited)
			directional[field] = islist(inherited[field]) ? deep_copy_list(inherited[field]) : inherited[field]
	advanced[key] = directional
	var/list/destination = directional
	if(scope == "arousal")
		if(!islist(directional["arousal"]))
			directional["arousal"] = list()
		if(!islist(directional["arousal"][arousal]))
			directional["arousal"][arousal] = list()
		destination = directional["arousal"][arousal]
	for(var/field in values)
		destination[field] = values[field]
	return TRUE

/** Returns the owned canonical draft without normalizing or copying its collections.
 * Callers must use the action path or update_draft to accept mutations.
 */
/datum/preference_middleware/cyborg_character/proc/begin_draft()
	if(draft && draft_slot == preferences.default_slot)
		return draft
	var/list/save_data = preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
	if(cyborg_layout_import_is_future(save_data?["silicon_genital_layout_presets"]))
		return null
	discard_draft("replace")
	draft_slot = preferences.default_slot
	draft = cyborg_layout_normalize(preferences.read_preference(/datum/preference/cyborg_layout))
	session_only = !preferences.savefile.path || preferences.path == DEV_PREFS_PATH
	return draft

/** Takes ownership of canonical action output and schedules the existing debounce. */
/datum/preference_middleware/cyborg_character/proc/update_draft(list/layout)
	if(!draft || draft_slot != preferences.default_slot || !islist(layout) || layout["schema_version"] != CYBORG_LAYOUT_SCHEMA_VERSION)
		return FALSE
	draft = layout
	draft_revision++
	dirty = TRUE
	schedule_draft_save()
	return TRUE

/// Rearm the save for this context without creating a revision for view-only changes.
/datum/preference_middleware/cyborg_character/proc/schedule_draft_save()
	if(draft_timer)
		deltimer(draft_timer)
	draft_timer = addtimer(CALLBACK(src, PROC_REF(flush_timer), draft_slot, context_generation, draft_revision), 2 SECONDS, TIMER_STOPPABLE)

/** Stages a revision into native preferences; only after_preferences_save acknowledges it. */
/datum/preference_middleware/cyborg_character/before_character_save()
	if(dirty && !isnull(staged_revision) && staged_revision == draft_revision && draft_slot == preferences.default_slot)
		return TRUE
	staged_revision = null
	if(!dirty || !draft)
		return TRUE
	if(draft_slot != preferences.default_slot)
		save_error = "This draft belongs to another character slot."
		return FALSE
	if(draft_timer)
		deltimer(draft_timer)
		draft_timer = null
	var/datum/preference/cyborg_layout/preference = GLOB.preference_entries[/datum/preference/cyborg_layout]
	if(isnull(preferences.get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)))
		preferences.savefile.set_entry("character[draft_slot]", list())
	if(!preferences.write_preference(preference, preference.serialize(draft)))
		save_error = "Could not stage the current setup. Retry saving."
		return FALSE
	preferences.recently_updated_keys -= preference.type
	staged_revision = draft_revision
	return TRUE

/** Completes only the staged revision; failed writes leave the owned draft retryable. */
/datum/preference_middleware/cyborg_character/after_preferences_save(result)
	if(!dirty)
		return
	if(!result)
		save_error = "Could not save the current setup. Your edits are retained; retry saving."
	else if(!isnull(staged_revision) && staged_revision == draft_revision && draft_slot == preferences.default_slot)
		saved_revision = staged_revision
		dirty = FALSE
		session_only = result == JSON_SAVE_SESSION_ONLY
		save_error = null
	staged_revision = null
	SStgui.update_uis(preferences)

/** The only editor entry into native staging plus writing; hooks never call this. */
/datum/preference_middleware/cyborg_character/proc/commit_draft()
	if(!dirty)
		return TRUE
	if(!preferences.save_character())
		after_preferences_save(JSON_SAVE_FAILED)
		return FALSE
	return preferences.save_preferences()

/** A stale timer cannot write a new slot, replaced draft, or newer edit. */
/datum/preference_middleware/cyborg_character/proc/flush_timer(slot, context, revision)
	if(slot != draft_slot || slot != preferences.default_slot || context != context_generation || revision != draft_revision)
		return
	draft_timer = null
	commit_draft()

/** Releases draft ownership on explicit replacement or teardown, never on write failure. */
/datum/preference_middleware/cyborg_character/proc/discard_draft(reason)
	if(draft_timer)
		deltimer(draft_timer)
		draft_timer = null
	preview_resources = null
	resource_key = null
	draft = null
	draft_slot = null
	dirty = FALSE
	staged_revision = null
	save_error = null
	context_generation++
	draft_revision++

/datum/preference_middleware/cyborg_character/can_change_character()
	return commit_draft()

/datum/preference_middleware/cyborg_character/before_character_load(slot, replacing_current_slot)
	discard_draft("load")

/datum/preference_middleware/cyborg_character/on_character_replaced()
	discard_draft("replacement")

/datum/preference_middleware/cyborg_character/on_preferences_destroy()
	if(dirty && save_error)
		stack_trace("Cyborg preference teardown after a failed save; unsaved draft cannot survive destruction.")
	discard_draft("destroy")

/datum/preference_middleware/cyborg_character/Destroy()
	discard_draft("destroy")
	return ..()

/** Static data is private to this preferences UI; never register sensitive PNGs globally. */
/datum/preference_middleware/cyborg_character/get_ui_static_data(mob/user)
	return list("cyborg_resources" = page_active && cyborg_visuals_allowed(preferences) ? preview_resources : null)

/** Pixel dependencies exclude placement/rotation/scale, so a drag sends only transforms. */
/datum/preference_middleware/cyborg_character/proc/refresh_resources(mob/user, list/catalog, list/descriptor, list/preview_layout, layout_source)
	var/list/dependencies = list(preview_model, preview_direction, preview_pose, preview_arousal, preview_moving, gallery_open, gallery_department, selected_part, layout_source, cyborg_visuals_allowed(preferences))
	for(var/id in catalog)
		dependencies += id
	for(var/slot in cyborg_layout_supported_slots())
		var/list/entry = preview_layout[slot]
		var/list/placement = cyborg_resolve_placement(entry, preview_direction, preview_pose, preview_arousal)
		dependencies += list(list(cyborg_preference_value(preferences, "silicon_[slot]_sprite"), entry["sprite"], entry["sprite_size"], entry["reuse_south"], entry["colors"], placement["visible"]))
	var/new_key = json_encode(dependencies)
	if(new_key == resource_key)
		return
	resource_key = new_key
	preview_resources = build_resources(catalog, descriptor, preview_layout, layout_source)
	if(user?.client)
		preferences.update_static_data(user, always_instant = TRUE)

/** Regenerates only when a pixel dependency changes; existing global cache budgets still apply. */
/datum/preference_middleware/cyborg_character/proc/build_resources(list/catalog, list/descriptor, list/preview_layout, layout_source)
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
	if(!cyborg_visuals_allowed(preferences))
		parts = list()
	var/list/layer_icons = list()
	for(var/list/layer as anything in cyborg_preview_layers(preferences, descriptor, preview_layout, preview_direction, preview_pose, preview_arousal, layout_source == "model_default"))
		layer_icons[layer["slot"]] = layer["icon"]
	var/list/dimensions = descriptor ? get_icon_dimensions(descriptor["icon"]) : list()
	return list(
		"layer_icons" = layer_icons,
		"models" = models,
		"body" = cyborg_preview_body(descriptor, preview_direction, preview_pose),
		"occlusion" = cyborg_visuals_allowed(preferences) ? cyborg_preview_body(descriptor, preview_direction, preview_pose, TRUE) : null,
		"animation" = cyborg_preview_animation(descriptor, preview_direction, preview_pose, preview_moving, cyborg_visuals_allowed(preferences)),
		"body_width" = dimensions["width"] || 32,
		"body_height" = dimensions["height"] || 32,
		"reference" = cyborg_preview_reference(),
		"parts" = parts,
	)
