// Imported savefiles are hostile input, and the load path never calls is_valid().

/// Cap on JSON nesting depth, json_decode has none of its own.
#define PREFS_IMPORT_MAX_DEPTH 24
/// Cap on character slots in an imported file.
#define PREFS_IMPORT_MAX_SLOTS 60
/// Marks a file as waiting on pass 2.
#define PREFS_IMPORT_PENDING_KEY "aphelion_import_pending"
/// Have we already shown them the import notice?
#define PREFS_IMPORT_NOTICE_KEY "aphelion_import_notice_seen"

/// Check depth iteratively so a deeply nested upload cannot overflow the call stack.
/proc/prefs_import_tree_too_deep(tree)
	if(!islist(tree))
		return FALSE
	// Only lists enter the stack; depths stay aligned with them.
	var/list/nodes = list(tree)
	var/list/depths = list(1)
	while(length(nodes))
		var/list/node = nodes[length(nodes)]
		var/depth = depths[length(depths)]
		nodes.len--
		depths.len--
		if(depth > PREFS_IMPORT_MAX_DEPTH)
			return TRUE
		for(var/key in node)
			// Assoc values live under the key, plain entries ARE the key.
			var/value = key
			if(!isnum(key) && !isnull(node[key]))
				value = node[key]
			if(!islist(value))
				continue
			nodes += list(value)
			depths += depth + 1
	return FALSE

/// Structural checks. Returns an error string, or null if it's fine.
/proc/prefs_import_prevalidate(list/json_tree, datum/preferences/prefs)
	if(!islist(json_tree) || !length(json_tree))
		return "file is empty or not a savefile"
	var/version = json_tree["version"]
	if(!isnum(version))
		return "missing version"
	// The version defines are #undef'd elsewhere, so use the datum's helper.
	if(prefs?.check_savedata_version(json_tree) == SAVE_DATA_OBSOLETE)
		return "savefile version [version] is too old to be migrated"
	for(var/key in json_tree)
		if(!istext(key))
			return "the savefile root must be a JSON object"
		if(findtext(key, "character") == 1)
			var/slot_number = text2num(copytext(key, 10))
			if(!isnum(slot_number) || slot_number < 1 || slot_number > PREFS_IMPORT_MAX_SLOTS || key != "character[round(slot_number)]")
				return "invalid character slot [html_encode(key)]"
	return null

/// Pass 1. Retains character migration inputs. Player imports may only replace player-owned root fields.
/// Supplying local_player_data enables the player allowlist; staff may still restore a complete backup.
/proc/prefs_import_pass1(list/json_tree, list/local_player_data)
	if(islist(local_player_data))
		json_tree = prefs_import_player_root(json_tree, local_player_data)
	// These fields are indexed by load_preferences and its migrations before their normal sanitizers.
	for(var/list_key in list("favorite_outfits", "favorite_verbs", "ignoring", "be_special"))
		if(list_key in json_tree)
			json_tree[list_key] = prefs_import_clean_text_list(json_tree[list_key])
	for(var/map_key in list("preferred_spawn_outfits", "preferred_spawn_methods"))
		if(map_key in json_tree)
			json_tree[map_key] = prefs_import_clean_assoc_paths(json_tree[map_key])
	if("key_bindings" in json_tree)
		var/list/bindings = json_tree["key_bindings"]
		var/list/clean_bindings = list()
		if(islist(bindings))
			for(var/binding in bindings)
				if(istext(binding))
					// Supported old files stored single keybindings as scalar strings.
					var/keys = bindings[binding]
					clean_bindings[binding] = istext(keys) ? list(keys) : prefs_import_clean_text_list(keys)
		json_tree["key_bindings"] = clean_bindings
	for(var/key in json_tree)
		if(findtext(key, "character") != 1)
			continue
		var/list/slot = json_tree[key]
		if(!islist(slot))
			json_tree[key] = list()
			continue
		// Pre-preset savefiles still carry the flat key; migration reads it.
		if("loadout_list" in slot)
			slot["loadout_list"] = prefs_import_clean_loadout(slot["loadout_list"])
		var/list/presets = prefs_import_clean_loadout_presets(slot["loadout_lists"])
		// load_character reads loadout_index before it runs the legacy migration.
		if(!length(presets))
			presets = list("Default" = slot["loadout_list"] || list())
		slot["loadout_lists"] = presets
		var/selected_preset = slot["loadout_index"]
		if(istext(selected_preset))
			selected_preset = copytext(html_encode(html_decode(selected_preset)), 1, MAX_NAME_LEN)
		slot["loadout_index"] = (selected_preset in presets) ? selected_preset : presets[1]
		slot["alt_job_titles"] = sanitize_alt_job_titles(slot["alt_job_titles"])
		slot["augments"] = prefs_import_clean_assoc_paths(slot["augments"])
		slot["augment_limb_styles"] = prefs_import_clean_assoc_paths(slot["augment_limb_styles"])
		slot["languages"] = prefs_import_clean_assoc_paths(slot["languages"], allow_numeric = TRUE)
	json_tree[PREFS_IMPORT_PENDING_KEY] = TRUE
	return json_tree

/// Registered preferences plus raw player settings and inputs still used by supported migrations.
/proc/prefs_import_player_root(list/upload, list/local_player_data)
	var/static/list/raw_player_keys = list(
		"version", "lastchangelog", "be_special", "default_slot", "chat_toggles", "toggles",
		"ignoring", "job_assigned_profiles", "favorite_outfits", "favorite_verbs", "key_bindings",
		"preferred_spawn_methods", "preferred_spawn_outfits",
		"sound_tts_blips", "sound_tts", "sound_ai_vox", "sound_midi", "sound_instruments",
		"sound_ambience_volume", "sound_ship_ambience_volume", "sound_lobby_volume", "sound_radio_noise",
	)
	var/list/allowed_keys = raw_player_keys.Copy()
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if(preference.savefile_identifier == PREFERENCE_PLAYER)
			allowed_keys |= preference.savefile_key
	var/list/out = list()
	for(var/key in upload)
		if(istext(key) && ((key in allowed_keys) || findtext(key, "character") == 1))
			out[key] = upload[key]
	// These are awarded/tracked by this server, never by the uploaded file.
	out["hearted_until"] = local_player_data["hearted_until"]
	out[PREFS_IMPORT_NOTICE_KEY] = local_player_data[PREFS_IMPORT_NOTICE_KEY]
	return out

/// Lists consumed as text/type names by raw loaders must not carry numeric indexes or nested collections.
/proc/prefs_import_clean_text_list(raw)
	var/list/out = list()
	if(islist(raw))
		for(var/value in raw)
			if(istext(value))
				out += value
	return out

/// loadout_lists is preset -> path -> details, so unwrap a level first.
/proc/prefs_import_clean_loadout_presets(raw)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/preset in raw)
		if(!istext(preset))
			continue
		out[copytext(html_encode(html_decode(preset)), 1, MAX_NAME_LEN)] = prefs_import_clean_loadout(raw[preset])
	return out

/// The UI encodes and caps these, the load path doesn't, so we redo it here.
/proc/prefs_import_clean_loadout(raw)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/path in raw)
		// A number indexes the list instead of keying it, and runtimes.
		if(!istext(path) && !ispath(path))
			continue
		var/list/details = raw[path]
		if(!islist(details))
			out[path] = list()
			continue
		var/list/clean = list()
		for(var/detail_key in details)
			if(!istext(detail_key))
				continue
			var/value = details[detail_key]
			if(istext(value))
				var/cap = (detail_key == INFO_DESCRIBED) ? MAX_DESC_LEN : MAX_NAME_LEN
				clean[detail_key] = copytext(html_encode(html_decode(value)), 1, cap)
			else if(isnum(value) && detail_key == INFO_LAYER)
				clean[detail_key] = value
		out[path] = clean
	return out

/// We just guarantee the shape, the owning loaders resolve them.
/proc/prefs_import_clean_assoc_paths(raw, allow_numeric = FALSE)
	if(!islist(raw))
		return list()
	var/list/out = list()
	for(var/key in raw)
		if(!istext(key) && !ispath(key))
			continue
		var/value = raw[key]
		if(istext(value) || ispath(value) || (allow_numeric && isnum(value)))
			out[key] = value
	return out

/// Pass 2. Rebuilds every known pref through the validating write path.
/datum/preferences/proc/prefs_import_finalise()
	if(!savefile)
		return FALSE
	if(!savefile.get_entry(PREFS_IMPORT_PENDING_KEY))
		return FALSE

	var/list/player_prefs = list()
	var/list/character_prefs = list()
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		switch(preference.savefile_identifier)
			if(PREFERENCE_PLAYER)
				player_prefs += preference
			if(PREFERENCE_CHARACTER)
				character_prefs += preference

	var/list/counts = list("rebuilt" = 0, "reset" = 0)

	// Player scope lives at the root, one pass covers it.
	prefs_import_rebuild(player_prefs, counts)

	// Character scope goes through default_slot, so we visit each slot.
	var/original_slot = default_slot
	var/original_max_slots = max_save_slots
	var/slots = 0
	var/list/tree = savefile.get_entry()
	if(islist(tree))
		for(var/tree_key in tree)
			if(findtext(tree_key, "character") != 1)
				continue
			var/slot_number = text2num(copytext(tree_key, 10))
			if(!isnum(slot_number) || !islist(tree[tree_key]))
				continue
			max_save_slots = max(max_save_slots, slot_number)
			default_slot = slot_number
			prefs_import_forget(character_prefs)
			// A current root version does not imply that secondary slots were migrated by New().
			if(!load_character())
				continue // An obsolete slot must not be overwritten with the previous slot's raw fields.
			prefs_import_strip_empty_loadout_keys(tree[tree_key])
			prefs_import_rebuild(character_prefs, counts)
			save_character()
			slots++

	default_slot = original_slot
	max_save_slots = original_max_slots
	prefs_import_forget(character_prefs)
	savefile.set_entry("default_slot", original_slot)
	load_character() // Restore raw fields as well as the registered preference cache.

	prefs_import_prune_unknown()
	savefile.remove_entry(PREFS_IMPORT_PENDING_KEY)
	savefile.save()

	log_game("Preferences import finalised for [parent?.ckey]: [slots] slot\s, [counts["rebuilt"]] preferences rebuilt, [counts["reset"]] reset to defaults.")
	return TRUE

/// Round-trips each pref through the write path, tallying as we go.
/datum/preferences/proc/prefs_import_rebuild(list/preferences, list/counts)
	for(var/datum/preference/preference as anything in preferences)
		var/value
		var/usable = FALSE
		try
			value = read_preference(preference.type)
			usable = !isnull(value) && preference.is_valid(value, src)
		catch
			usable = FALSE
		var/written
		if(usable)
			// write_preference deserialises, so hand it the serialised form back.
			written = write_preference(preference, preference.serialize(value))
		else
			written = write_preference(preference, preference.create_informed_default_value(src))
			counts["reset"]++
		if(written)
			counts["rebuilt"]++

/// Clear the whole character cache before loading a slot, including defaults that read other preferences.
/datum/preferences/proc/prefs_import_forget(list/preferences)
	for(var/datum/preference/preference as anything in preferences)
		value_cache -= preference.type

/// Migration leaves null keys behind, and sanitize_loadout_list stack_traces on them.
/proc/prefs_import_strip_empty_loadout_keys(list/slot)
	// Runs post-migration: presets are the live shape, the flat key may linger.
	prefs_import_strip_empty_keys(slot, "loadout_list")
	var/list/presets = slot["loadout_lists"]
	if(!islist(presets))
		return
	for(var/preset in presets)
		prefs_import_strip_empty_keys(presets, preset)

/// Pass 1 and native migrations produce unique path keys; copy only to remove empty keys, preserving shared lists.
/proc/prefs_import_strip_empty_keys(list/holder, key)
	var/list/loadout = holder[key]
	if(!islist(loadout))
		return
	if((null in loadout) || ("" in loadout))
		loadout = loadout.Copy()
		loadout.RemoveAll(null, "")
		holder[key] = loadout

/// Only out-of-range slots go. load_preferences scans these names, other junk is inert.
/datum/preferences/proc/prefs_import_prune_unknown()
	var/list/tree = savefile.get_entry()
	if(!islist(tree))
		return
	var/list/dropped = list()

	for(var/key in tree)
		if(findtext(key, "character") != 1)
			continue
		var/slot_number = text2num(copytext(key, 10))
		if(isnum(slot_number) && slot_number >= 1 && slot_number <= PREFS_IMPORT_MAX_SLOTS)
			continue
		dropped += key

	for(var/key in dropped)
		tree -= key

	if(!length(dropped))
		return
	log_game("Preferences import dropped [length(dropped)] out-of-range character slot\s for [parent?.ckey]: [jointext(dropped, ", ")]")

// Not #undef'd on purpose, the import verb reads these.
