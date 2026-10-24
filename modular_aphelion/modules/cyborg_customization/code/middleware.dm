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
	/// Only the current six images/metadata are retained; shared FIFO eviction is harmless.
	var/list/resource_layer_keys
	var/list/resource_part_keys
	var/list/resource_catalog
	var/resource_body_key
	/// One latest-state refresh, with a deadline that survives close/reopen and slot changes.
	var/resource_timer
	var/resource_generation = 0
	var/resource_refresh_at = 0
	var/resources_pending = FALSE
	/// Metadata/gallery work must not interrupt placement against unchanged stage pixels.
	var/preview_pending = FALSE
	/// One public model load per editor; survives close/slot changes until it finishes.
	var/occlusion_loading = FALSE
	var/occlusion_failed_key
	/// Bounded view fields keep the old pixels and geometry coherent during a refresh.
	var/list/rendered_preview
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
	/// Whether accepted edits still require a successful sidecar write.
	var/dirty = FALSE
	/// Last written revision and whether it only reached memory.
	var/saved_revision = 0
	/// Revision already encoded into the account tree; failed retries do not encode it again.
	var/staged_revision = -1
	/// Why the draft would pass its character's or the account's limit, so it stays unstaged until edits shrink it.
	var/full_message
	var/session_only = FALSE
	/// A retryable write or staging failure, kept across UI close/reopen.
	var/save_error
	action_delegations = list(
		"cyborg_page" = PROC_REF(set_page),
		"cyborg_preview" = PROC_REF(set_preview),
		"cyborg_layout" = PROC_REF(edit_layout),
	)

/datum/preference_middleware/cyborg_character/proc/set_page(list/params, mob/user)
	if(!islist(params) || length(params) != 1 || !("active" in params) || !(params["active"] in list(TRUE, FALSE)))
		return FALSE
	if(user?.client && user.client != preferences.parent)
		return FALSE
	var/active = params["active"] == TRUE
	if(active == page_active)
		return TRUE
	page_active = active
	if(page_active)
		preview_layout_source = "active"
		selected_part = "penis"
	if(!page_active)
		close_editor()
		if(user?.client)
			preferences.update_static_data(user, always_instant = TRUE)
	return TRUE

/// The backend owns close even when native window teardown cannot deliver React cleanup.
/datum/preference_middleware/cyborg_character/proc/close_editor()
	page_active = FALSE
	gallery_open = FALSE
	gallery_department = null
	commit_draft()
	context_generation++
	clear_preview_resources()

/datum/preference_middleware/cyborg_character/proc/set_preview(list/params, mob/user)
	if(!islist(params) || length(params) > 10)
		return FALSE
	for(var/key, value in params)
		if(!(key in list("context", "model", "direction", "pose", "arousal", "moving", "selected_part", "gallery_open", "gallery_department", "layout_source")))
			return FALSE
		// All valid identifiers come from the finite server catalog. Bound text before lookup.
		if(islist(value) || (istext(value) && length(value) > CYBORG_PREVIEW_MAX_IDENTIFIER_LENGTH))
			return FALSE
	if(!page_active || params["context"] != context_generation)
		return FALSE
	if(user && user.client && user.client != preferences.parent)
		return FALSE
	var/list/catalog = cyborg_model_catalog()
	if(istext(params["model"]) && catalog[params["model"]])
		if(preview_model != params["model"])
			context_generation++
			preview_layout_source = "active"
		preview_model = params["model"]
		var/list/draft = begin_draft()
		if(draft && draft["active_model"] != preview_model)
			draft = draft.Copy()
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
		for(var/id, model in catalog)
			if(model["department"] == params["gallery_department"])
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
	if(!islist(params) || length(params) > 8)
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
	var/list/catalog = cyborg_model_catalog()
	if(!catalog[preview_model])
		status_message = "This chassis is no longer available. Select an eligible chassis."
		return TRUE
	if(preview_layout_source == "model_default" && (params["operation"] in list("set", "set_placement", "nudge_placement", "inherit_placement", "reset", "reset_position", "reset_colors", "reset_overrides", "save", "save_default")))
		status_message = "Load this model default into the active layout before editing it."
		return TRUE
	var/list/store = begin_draft()
	if(!store)
		status_message = "This slot contains a newer layout schema. Its saved data has been preserved."
		return TRUE
	var/datum/json_savefile/cyborg_customization/sidecar = preferences.cyborg_layout_store()
	if(sidecar.read_refused)
		status_message = sidecar.write_error()
		return TRUE
	// Past a limit only edits that shrink the slot go through, until it can be saved again.
	if(full_message && !(params["operation"] in list("delete", "delete_default", "reset", "reset_position", "reset_colors", "reset_overrides", "inherit_placement")))
		status_message = full_message
		return TRUE
	var/list/result = cyborg_layout_action(store, params, preview_model, preferences)
	if(result["model"] && !catalog[result["model"]])
		status_message = "This preset's chassis is no longer available."
		return TRUE
	// These copy a whole layout, so the result must fit before it is taken.
	if(result["store"] && (params["operation"] in list("save", "save_default", "assign_default", "load", "load_default")))
		var/text = cyborg_layout_encode(result["store"])
		if(length(text) > CYBORG_LAYOUT_MAX_SLOT_BYTES)
			status_message = "That would put this character's cyborg setups over the [CYBORG_LAYOUT_MAX_SLOT_BYTES / 1024] KB limit. Delete presets or model defaults you no longer need."
			return TRUE
		if(sidecar.bytes_with("character[preferences.default_slot]", text) > CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
			status_message = "That would put your cyborg setups over the limit all your characters share. Delete presets or model defaults you no longer need, on this character or another."
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
	else if(result["immediate"])
		// An idempotent save may still need to flush an earlier accepted edit.
		commit_draft()
	return TRUE

/datum/preference_middleware/cyborg_character/get_ui_data(mob/user)
	if(!page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return list()
	var/list/catalog = cyborg_model_catalog()
	// These shared assets may yield during early startup or a catalog config change.
	// Complete that work before capturing any private draft or preview state.
	if(cyborg_visuals_allowed(preferences))
		var/preflight_generation = resource_generation
		var/datum/asset/cyborg_model_gallery/gallery = get_asset_datum(/datum/asset/cyborg_model_gallery)
		if(QDELETED(src) || QDELETED(preferences) || !page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES || resource_generation != preflight_generation)
			return list()
		while(TRUE)
			if(!cyborg_visuals_allowed(preferences))
				break
			catalog = cyborg_model_catalog()
			gallery.build_catalog(catalog)
			if(QDELETED(src) || QDELETED(preferences) || !page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES || resource_generation != preflight_generation)
				return list()
			if(!cyborg_visuals_allowed(preferences))
				break
			var/requested_department = gallery_open ? gallery_department : null
			gallery.send_to_viewer(user, requested_department)
			if(QDELETED(src) || QDELETED(preferences) || !page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES || resource_generation != preflight_generation)
				return list()
			if(!cyborg_visuals_allowed(preferences))
				break
			// A department/catalog change during native acquisition must acquire the
			// current public selection before publishing its URLs. Private state is
			// still uncaptured, so a slot/model change is resolved below from scratch.
			if(catalog == cyborg_model_catalog() && requested_department == (gallery_open ? gallery_department : null))
				break
	if(!catalog[preview_model] && length(catalog))
		var/list/draft = begin_draft()
		preview_model = catalog[draft?["active_model"]] ? draft["active_model"] : catalog[1]
		preview_layout_source = "active"
	var/list/descriptor = catalog[preview_model]
	var/list/store = begin_draft()
	if(!store)
		var/needs_clear = resource_key != "unsupported"
		clear_preview_resources()
		resource_key = "unsupported"
		if(needs_clear && user?.client)
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
	var/resources_changed = refresh_resources(catalog, descriptor, preview_layout, layout_source)
	var/wide = descriptor && (TRAIT_R_WIDE in descriptor["features"])
	var/body_scale = descriptor ? cyborg_effective_base_size(cyborg_preference_value(preferences, "cyborg_size"), descriptor["features"]) : 1
	if(!preview_pending && preview_resources)
		var/list/layers = cyborg_preview_layers(preferences, descriptor, preview_layout, preview_direction, preview_pose, preview_arousal, layout_source == "model_default", preview_resources["layer_icons"])
		for(var/list/layer as anything in layers)
			layer -= "icon"
		rendered_preview = list(
			"model" = preview_model, "pose" = preview_pose, "direction" = preview_direction,
			"arousal" = preview_arousal, "moving" = preview_moving,
			"wide" = wide, "body_scale" = body_scale, "layers" = layers,
		)
	// Saved snapshots stay server-side. Only the saved-appearance view reads a default's full layout.
	var/list/ui_store = store.Copy()
	var/list/preset_names = list()
	for(var/name in store["presets"])
		preset_names[name] = TRUE
	ui_store["presets"] = preset_names
	ui_store["model_presets"] = list()
	var/list/model_presets = store["model_presets"]
	if(model_presets?[preview_model])
		ui_store["model_presets"][preview_model] = model_presets[preview_model]
	ui_store["model_defaults"] = list()
	if(layout_source == "model_default" && islist(defaults?[preview_model]))
		ui_store["model_defaults"][preview_model] = defaults[preview_model]
	. = list("cyborg_customization" = list(
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
		"wide" = wide,
		"body_scale" = body_scale,
		"context" = context_generation,
		"revision" = draft_revision,
		"save_status" = list("pending" = dirty || preferences.cyborg_layout_store().write_pending, "revision" = saved_revision, "session_only" = session_only, "error" = save_error),
		"store" = ui_store,
		"layout_source" = layout_source,
		"model_default_available" = islist(defaults) && islist(defaults[preview_model]),
		"layers" = rendered_preview?["layers"] || list(),
		"resources_pending" = resources_pending,
		"preview_pending" = preview_pending,
		"message" = descriptor && "[descriptor["icon"]]#[descriptor["icon_state"]]" == occlusion_failed_key ? "This model's preview could not be prepared. Choose another model." : status_message,
	))
	// The nested customization object is replaced on every update. Only a pixel
	// wait needs a second stage on the wire; keep the server snapshot for later waits.
	if(preview_pending)
		.["cyborg_customization"]["rendered_preview"] = rendered_preview
	// Publish the new resource identity and its geometry together before TGUI re-enters ui_data.
	if(resources_changed && user?.client)
		preferences.update_static_data(user, always_instant = TRUE)

/datum/preference_middleware/cyborg_character/on_new_character(mob/user)
	preview_model = null
	selected_part = "penis"
	status_message = null
	preview_layout_source = "active"
	gallery_open = FALSE
	gallery_department = null

/** Creator action protocol; the middleware owns slot and actor checks.
 * The result takes over draft ownership. Unchanged branches may be shared with
 * the old draft; mutation copies its branch, and saved/body snapshots stay deep copies.
 */
/proc/cyborg_layout_action(list/store, list/params, model_id, datum/preferences/preferences)
	var/message = "Working setup updated."
	var/restored_model
	var/operation = params["operation"]
	var/slot = params["slot"]
	var/group = params["placement_group"]
	if(!isnull(group) && !(group in list("north", "south", "side")))
		return list("message" = "Unknown placement group.")
	if((operation in list("set", "set_placement", "nudge_placement", "inherit_placement", "reset_position", "reset_colors", "reset_overrides")) && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	if(operation == "reset" && !isnull(slot) && !(slot in cyborg_layout_supported_slots()))
		return list("message" = "Choose a valid layout slot.")
	var/name = params["name"]
	if(operation in list("save", "load", "delete", "assign_default"))
		if(!istext(name))
			return list("message" = "Enter a preset name.")
		// UTF-8 needs at most four bytes per character; cap work before trimming/counting.
		if(length(name) > CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH * 4)
			return list("message" = "Preset names must be 1 to 24 characters.")
		name = trim(name)
		if(!length(name) || length_char(name) > CYBORG_LAYOUT_MAX_PRESET_NAME_LENGTH)
			return list("message" = "Preset names must be 1 to 24 characters.")
		var/list/presets = store["presets"]
		if(operation == "save")
			if(presets[name] && params["overwrite"] != TRUE)
				return list("message" = "That preset exists. Use Update preset to replace it.")
			if(!presets[name] && length(presets) >= CYBORG_LAYOUT_MAX_PRESETS)
				return list("message" = "Ten presets are already saved. Delete one first.")
		else if(!presets[name])
			return list("message" = "That preset no longer exists.")
	if(operation in list("save_default", "load_default", "delete_default", "assign_default"))
		if(!cyborg_model_catalog()[model_id])
			return list("message" = "Select an eligible model first.")
		if((operation in list("save_default", "assign_default")) && !store["model_defaults"][model_id] && length(store["model_defaults"]) >= CYBORG_LAYOUT_MAX_MODEL_DEFAULTS)
			return list("message" = "This character already has [CYBORG_LAYOUT_MAX_MODEL_DEFAULTS] model defaults. Delete one first.")
	// Copy collection indices only for operations that replace their snapshots.
	var/list/collections
	switch(operation)
		if("save")
			collections = list("presets", "preset_models", "model_presets", "model_defaults")
		if("delete")
			collections = list("presets", "preset_models", "model_presets")
		if("assign_default")
			collections = list("preset_models", "model_presets", "model_defaults")
		if("save_default", "delete_default")
			collections = list("model_presets", "model_defaults")
		else
			if(!(operation in list("set", "set_placement", "nudge_placement", "inherit_placement", "reset", "reset_position", "reset_colors", "reset_overrides", "load", "load_default")))
				return list("message" = "Unknown layout action.")
	var/list/next = store.Copy()
	for(var/key in collections)
		var/list/collection = store[key]
		next[key] = collection.Copy()
	// Six slot references are cheap; copy the selected entry only when editing it.
	var/list/active = store["active"]
	next["active"] = active.Copy()
	if(preferences && (operation in list("save", "save_default")))
		// Snapshot selected art only after admission, keeping the source draft untouched.
		for(var/part_slot in cyborg_layout_supported_slots())
			var/list/entry = active[part_slot]
			entry = entry.Copy()
			entry["sprite"] = cyborg_preference_value(preferences, "silicon_[part_slot]_sprite")
			next["active"][part_slot] = entry
	// Compare only the six-part snapshot, never encode/copy the complete account to
	// discover that a repeated Save button made no change.
	if(operation in list("save", "save_default"))
		var/list/snapshot = next["active"]
		var/unchanged = deep_compare_list(snapshot, active)
		if(operation == "save_default")
			unchanged &&= !store["model_presets"][model_id] && deep_compare_list(snapshot, store["model_defaults"][model_id])
		else
			unchanged &&= store["active_preset"] == name && store["preset_models"][name] == model_id && deep_compare_list(snapshot, store["presets"][name])
			for(var/assigned_model, assigned_name in store["model_presets"])
				if(assigned_name == name && (assigned_model != model_id || !deep_compare_list(snapshot, store["model_defaults"][assigned_model])))
					unchanged = FALSE
		if(unchanged)
			return list("message" = "This setup is unchanged.", "immediate" = TRUE)
	switch(operation)
		if("set_placement", "nudge_placement", "inherit_placement")
			next["active"][slot] = deep_copy_list(active[slot])
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
			var/list/entry = active[slot]
			entry = entry.Copy()
			entry[field] = params["value"]
			next["active"][slot] = cyborg_layout_normalize_entry(entry, slot = slot)
		if("reset_position")
			var/list/entry = active[slot]
			next["active"][slot] = entry.Copy()
			next["active"][slot]["placement_groups"] = list()
			next["active"][slot]["pixel_x"] = 0
			next["active"][slot]["pixel_y"] = 0
			next["active"][slot]["rotation"] = 0
			next["active"][slot]["scale"] = 1
		if("reset_colors")
			var/list/entry = active[slot]
			next["active"][slot] = entry.Copy()
			next["active"][slot]["colors"] = list("#ffffff", "#ffffff", "#ffffff")
		if("reset_overrides")
			var/list/entry = active[slot]
			next["active"][slot] = entry.Copy()
			next["active"][slot]["advanced"] = list()
		if("reset")
			if(slot in cyborg_layout_supported_slots())
				next["active"][slot] = cyborg_layout_default_entry(slot)
			else
				next["active"] = cyborg_layout_default_slots()
		if("save", "load", "delete")
			var/list/presets = next["presets"]
			if(operation == "save")
				presets[name] = cyborg_layout_copy(next["active"])
				if(model_id && cyborg_model_catalog()[model_id])
					next["preset_models"][name] = model_id
				else
					next["preset_models"] -= name
				next["active_preset"] = name
				for(var/assigned_model, assigned_name in next["model_presets"])
					if(assigned_name != name)
						continue
					if(assigned_model == model_id)
						next["model_defaults"][assigned_model] = cyborg_layout_copy(presets[name])
					else
						next["model_presets"] -= assigned_model
				message = "Preset saved."
			else
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
					for(var/assigned_model, assigned_name in next["model_presets"])
						if(assigned_name == name)
							next["model_presets"] -= assigned_model
					message = "Preset deleted."
		if("assign_default")
			var/preset_model = next["preset_models"][name]
			if(preset_model && preset_model != model_id)
				return list("message" = "Load this preset to switch to its chassis first.")
			next["preset_models"][name] = model_id
			next["model_defaults"][model_id] = cyborg_layout_copy(next["presets"][name])
			next["model_presets"][model_id] = name
			message = "[name] will load when a new body selects this chassis."
		if("save_default", "load_default", "delete_default")
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
	var/nudge = params["operation"] == "nudge_placement"
	for(var/field, value in changes)
		if(!(field in list("pixel_x", "pixel_y", "rotation", "scale", "visible", "priority")) || !isnum(value))
			return FALSE
		if(nudge && (!(field in list("pixel_x", "pixel_y")) || !(value in list(-1, 0, 1))))
			return FALSE
		if(scope == "base" && (field in list("visible", "priority")))
			return FALSE
	var/list/values = cyborg_layout_normalize_advanced_entry(changes, FALSE)
	if(scope == "base")
		var/group = (TRAIT_R_WIDE in descriptor["features"]) ? (direction == "north" ? "north" : direction == "south" ? "south" : "side") : null
		var/list/position = cyborg_layout_edit_position(entry, group)
		for(var/field, value in values)
			if(field == "scale")
				entry[field] = value
			else
				position[field] = nudge ? clamp(position[field] + value, CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET) : value
		return TRUE
	var/list/directional = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "scale" = 1, "priority" = 5)
	var/list/inherited = advanced[key] || advanced[direction]
	if(inherited)
		for(var/field, value in inherited)
			directional[field] = islist(value) ? deep_copy_list(value) : value
	advanced[key] = directional
	var/list/destination = directional
	if(scope == "arousal")
		if(!islist(directional["arousal"]))
			directional["arousal"] = list()
		if(!islist(directional["arousal"][arousal]))
			directional["arousal"][arousal] = list()
		destination = directional["arousal"][arousal]
	for(var/field, value in values)
		var/current = isnull(destination[field]) ? directional[field] : destination[field]
		destination[field] = nudge ? clamp(current + value, CYBORG_LAYOUT_MIN_PIXEL_OFFSET, CYBORG_LAYOUT_MAX_PIXEL_OFFSET) : value
	return TRUE

/** Returns the owned canonical draft, decoding the slot's save text the first time.
 * Callers must use the action path or update_draft to accept mutations.
 * The sidecar is keyed by slot, so a draft left by a slot change is written to its own slot first.
 */
/datum/preference_middleware/cyborg_character/proc/begin_draft()
	if(draft && draft_slot == preferences.default_slot)
		return draft
	if(draft)
		// A failed disk write is still staged under its original slot; only a slot past its limit loses unsaved edits.
		commit_draft()
	var/stored = preferences.cyborg_layout_store().get_entry("character[preferences.default_slot]")
	if(cyborg_layout_import_is_future(stored))
		return null
	discard_draft()
	draft_slot = preferences.default_slot
	draft = cyborg_layout_from_stored(stored)
	session_only = !preferences.cyborg_layout_store().path
	return draft

/** Accepts canonical data and schedules the existing debounce. Staging encodes the draft, so callers keep their lists. */
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

/** Encodes the draft into its slot and writes the sidecar. A failed write keeps the draft dirty for retry, and a draft
 * past CYBORG_LAYOUT_MAX_SLOT_BYTES stays unstaged until edits shrink it.
 */
/datum/preference_middleware/cyborg_character/proc/commit_draft()
	if(!dirty && !preferences.cyborg_layout_savefile?.write_pending)
		return TRUE
	var/datum/json_savefile/cyborg_customization/store = preferences.cyborg_layout_store()
	if(draft_timer)
		deltimer(draft_timer)
		draft_timer = null
	if(dirty && staged_revision != draft_revision)
		var/text = cyborg_layout_encode(draft)
		var/problem
		if(length(text) > CYBORG_LAYOUT_MAX_SLOT_BYTES)
			problem = cyborg_layout_slot_full_message()
		else if(store.bytes_with("character[draft_slot]", text) > CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
			problem = cyborg_layout_account_full_message()
		if(problem != full_message)
			full_message = problem
			save_error = save_problem()
		if(full_message)
			// Other slots' pending writes still go out.
			store.flush_pending()
			return FALSE
		// Set before the synchronous completion callback can acknowledge this revision.
		staged_revision = draft_revision
		preferences.stage_cyborg_layout(draft_slot, text)
	else
		store.flush_pending()
	return !store.write_pending

/// What the save status shows, null when everything is saved or on its way.
/datum/preference_middleware/cyborg_character/proc/save_problem()
	return full_message || preferences.cyborg_layout_savefile?.write_error()

/// A delayed account write can complete after this editor switched slots or closed.
/datum/preference_middleware/cyborg_character/proc/sidecar_write_completed()
	var/datum/json_savefile/cyborg_customization/store = preferences.cyborg_layout_store()
	if(!store.write_pending && dirty && staged_revision == draft_revision)
		saved_revision = draft_revision
		dirty = FALSE
	session_only = !store.path
	save_error = save_problem()
	SStgui.update_uis(preferences)

/** A stale timer cannot write a replaced draft or an older revision. */
/datum/preference_middleware/cyborg_character/proc/flush_timer(slot, context, revision)
	if(slot != draft_slot || context != context_generation || revision != draft_revision)
		return
	draft_timer = null
	commit_draft()

/** Releases draft ownership on explicit replacement or teardown, never on write failure. */
/datum/preference_middleware/cyborg_character/proc/discard_draft()
	if(draft_timer)
		deltimer(draft_timer)
		draft_timer = null
	clear_preview_resources()
	draft = null
	draft_slot = null
	dirty = FALSE
	full_message = null
	staged_revision = -1
	save_error = save_problem()
	context_generation++
	draft_revision++

/datum/preference_middleware/cyborg_character/Destroy()
	// Preferences asset registration creates ownerless metadata prototypes; only a
	// real preferences session can own drafts, account writes or private resources.
	if(preferences)
		commit_draft()
		discard_draft()
	return ..()

/** Static data is private to this preferences UI; never register sensitive PNGs globally. */
/datum/preference_middleware/cyborg_character/get_ui_static_data(mob/user)
	return list("cyborg_resources" = page_active && cyborg_visuals_allowed(preferences) ? preview_resources : null)

/// Cancel work and release private pixels immediately, without resetting admission time.
/datum/preference_middleware/cyborg_character/proc/clear_preview_resources()
	resource_generation++
	if(resource_timer)
		deltimer(resource_timer)
		resource_timer = null
	resources_pending = FALSE
	preview_pending = FALSE
	preview_resources = null
	rendered_preview = null
	resource_key = null
	resource_layer_keys = null
	resource_part_keys = null
	resource_catalog = null
	resource_body_key = null

/// The timer owns no layout snapshots: the next UI update reads the latest accepted draft.
/datum/preference_middleware/cyborg_character/proc/refresh_resources_timer(generation, slot)
	if(generation != resource_generation || slot != draft_slot || slot != preferences.default_slot)
		return
	resource_timer = null
	if(!page_active || preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return
	SStgui.update_uis(preferences)

/** Pixel dependencies exclude placement/rotation/scale, so a drag only resolves geometry.
 * Full private payloads are limited to one pixel refresh per second per editor. A single
 * pending timer coalesces later input while the old coherent stage remains visible.
 */
/datum/preference_middleware/cyborg_character/proc/refresh_resources(list/catalog, list/descriptor, list/preview_layout, layout_source)
	if(!cyborg_visuals_allowed(preferences))
		var/needs_clear = resource_key != "denied"
		clear_preview_resources()
		resource_key = "denied"
		return needs_clear
	var/list/layer_keys = list()
	var/list/part_keys = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/list/entry = preview_layout[slot]
		var/choice = cyborg_preference_value(preferences, "silicon_[slot]_sprite")
		if(layout_source == "model_default" && !isnull(entry["sprite"]))
			choice = entry["sprite"]
		var/direction = descriptor ? cyborg_part_sprite_direction(descriptor, entry, preview_direction) : SOUTH
		var/list/placement = cyborg_resolve_placement(entry, preview_direction, preview_pose, preview_arousal)
		if(descriptor && placement["visible"] && choice && choice != SPRITE_ACCESSORY_NONE)
			layer_keys[slot] = json_encode(list(choice, entry["colors"], preview_arousal, direction, entry["sprite_size"]))
		// Size choices show neutral artwork. Color edits never regenerate this gallery.
		part_keys[slot] = json_encode(list(choice, preview_arousal, direction, entry["sprite_size"], slot == selected_part))
	var/models_key = gallery_open ? gallery_department : null
	// Preflight completed any generation/acquisition before this private snapshot.
	var/datum/asset/cyborg_model_gallery/gallery = GLOB.asset_datums[/datum/asset/cyborg_model_gallery]
	var/list/gallery_descriptor = gallery.ui_descriptor(models_key)
	var/body_key = json_encode(list(preview_model, preview_direction, preview_pose, preview_moving))
	var/new_key = json_encode(list(gallery_descriptor, body_key, layer_keys, part_keys))
	if(new_key == resource_key && resource_catalog == catalog)
		if(resource_timer)
			deltimer(resource_timer)
			resource_timer = null
		resources_pending = FALSE
		preview_pending = FALSE
		return FALSE
	if(world.time < resource_refresh_at)
		resources_pending = TRUE
		preview_pending = !preview_resources || resource_body_key != body_key || !deep_compare_list(resource_layer_keys, layer_keys)
		if(!resource_timer)
			resource_timer = addtimer(CALLBACK(src, PROC_REF(refresh_resources_timer), resource_generation, draft_slot), resource_refresh_at - world.time, TIMER_STOPPABLE)
		return FALSE
	// A first model use may yield in Rust-g. Keep all private snapshots in this
	// synchronous request and show the previous coherent stage until it completes.
	if(descriptor && cyborg_occlusion_has_model(descriptor["icon"], descriptor["icon_state"]) && !cyborg_occlusion_cached(descriptor["icon"], descriptor["icon_state"]))
		resources_pending = TRUE
		preview_pending = TRUE
		// First-use failure must still leave the public model picker usable.
		// No private pixels or geometry are published in this metadata-only payload.
		var/publish_gallery = !preview_resources || !deep_compare_list(preview_resources["gallery"], gallery_descriptor)
		if(publish_gallery)
			preview_resources = preview_resources ? preview_resources.Copy() : list()
			preview_resources["gallery"] = gallery_descriptor
		var/model_key = "[descriptor["icon"]]#[descriptor["icon_state"]]"
		if(!occlusion_loading && occlusion_failed_key != model_key)
			occlusion_loading = TRUE
			INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(cyborg_complete_editor_occlusion), WEAKREF(src), descriptor["icon"], descriptor["icon_state"])
		return publish_gallery
	if(resource_timer)
		deltimer(resource_timer)
		resource_timer = null
	resources_pending = FALSE
	preview_pending = FALSE
	// Set admission before publishing: the forced full update can re-enter ui_data.
	resource_refresh_at = world.time + 1 SECONDS
	preview_resources = build_resources(catalog, descriptor, preview_layout, layout_source, layer_keys, part_keys, gallery_descriptor, body_key)
	resource_layer_keys = layer_keys
	resource_part_keys = part_keys
	resource_catalog = catalog
	resource_body_key = body_key
	resource_key = new_key
	return TRUE

/// Only public authored identity crosses the wait; deleted editors are not retained.
/proc/cyborg_complete_editor_occlusion(datum/weakref/editor_ref, source_file, base_state)
	// Even an immediately cached/failed result must finish after this UI read.
	sleep(0)
	var/datum/preference_middleware/cyborg_character/editor = editor_ref.resolve()
	if(QDELETED(editor))
		return
	if(QDELETED(editor.preferences) || !editor.page_active || editor.preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES || !cyborg_visuals_allowed(editor.preferences))
		editor.occlusion_loading = FALSE
		return
	var/list/current = cyborg_model_catalog()[editor.preview_model]
	if(!current || current["icon"] != source_file || current["icon_state"] != base_state)
		editor.occlusion_loading = FALSE
		SStgui.update_uis(editor.preferences)
		return
	// Only weak identity and public source values survive the actual wait.
	editor = null
	current = null
	var/exception/failure
	try
		cyborg_occlusion_ensure_model_ready(source_file, base_state)
	catch(var/exception/error)
		failure = error
	editor = editor_ref.resolve()
	if(QDELETED(editor))
		return
	editor.occlusion_loading = FALSE
	if(failure)
		editor.occlusion_failed_key = "[source_file]#[base_state]"
	if(QDELETED(editor.preferences) || !editor.page_active || editor.preferences.current_window != PREFERENCE_TAB_CHARACTER_PREFERENCES)
		return
	// The next read resolves the current slot, model, consent, and layout afresh.
	SStgui.update_uis(editor.preferences)

/** Reuse the current session's unchanged resources, even after shared FIFO eviction.
 * Retention stays bounded to one gallery and six part images/metadata, not edit history.
 */
/datum/preference_middleware/cyborg_character/proc/build_resources(list/catalog, list/descriptor, list/preview_layout, layout_source, list/layer_keys, list/part_keys, list/gallery_descriptor, body_key)
	var/list/result = preview_resources ? preview_resources.Copy() : list()
	if(!preview_resources || !deep_compare_list(preview_resources["gallery"], gallery_descriptor))
		result["gallery"] = gallery_descriptor
	var/list/parts = list()
	var/list/layer_icons = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/choice = cyborg_preference_value(preferences, "silicon_[slot]_sprite")
		var/list/entry = preview_layout[slot]
		if(layout_source == "model_default" && !isnull(entry["sprite"]))
			choice = entry["sprite"]
		var/direction = descriptor ? cyborg_part_sprite_direction(descriptor, entry, preview_direction) : SOUTH
		if(preview_resources && resource_part_keys?[slot] == part_keys[slot])
			parts[slot] = preview_resources["parts"][slot]
		else
			parts[slot] = cyborg_accessory_metadata(slot, choice, list("#ffffff", "#ffffff", "#ffffff"), preview_arousal, direction, entry["sprite_size"], slot == selected_part)
		if(!layer_keys[slot])
			continue
		if(preview_resources && resource_layer_keys?[slot] == layer_keys[slot])
			layer_icons[slot] = preview_resources["layer_icons"][slot]
		else
			var/list/rendered = cyborg_accessory_render(slot, choice, entry["colors"], preview_arousal, direction, entry["sprite_size"])
			if(rendered)
				layer_icons[slot] = rendered["base64"]
	result["layer_icons"] = layer_icons
	result["parts"] = parts
	if(!preview_resources || resource_body_key != body_key)
		var/list/dimensions = descriptor ? get_icon_dimensions(descriptor["icon"]) : list()
		result["body"] = cyborg_preview_body(descriptor, preview_direction, preview_pose)
		result["occlusion"] = cyborg_preview_body(descriptor, preview_direction, preview_pose, TRUE)
		result["animation"] = cyborg_preview_animation(descriptor, preview_direction, preview_pose, preview_moving, TRUE)
		// The client falls back to the standalone images. Only exact duplicates
		// are omitted; frame timing, offsets and distinct movement pixels stay intact.
		for(var/list/frame as anything in result["animation"])
			if(frame["body"] == result["body"])
				frame -= "body"
			if(frame["occlusion"] == result["occlusion"])
				frame -= "occlusion"
		result["body_width"] = dimensions["width"] || 32
		result["body_height"] = dimensions["height"] || 32
		result["reference"] = cyborg_preview_reference()
	return result
