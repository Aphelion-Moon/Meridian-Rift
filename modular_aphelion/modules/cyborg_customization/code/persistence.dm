/// The account's cyborg layout sidecar, cyborg_customization.json beside preferences.json, keyed by character slot.
/datum/json_savefile/cyborg_customization

/// rust-g returns error text rather than a success boolean. Returns whether the file now holds the tree.
/datum/json_savefile/cyborg_customization/save()
	if(!path)
		return TRUE
	return !length(rustg_file_write(json_encode(get_entry(), JSON_PRETTY_PRINT), path))

/datum/preferences
	/// Lazily loaded cyborg layout sidecar owned by these preferences.
	var/datum/json_savefile/cyborg_customization/cyborg_layout_savefile

/// The cyborg layout sidecar beside a preferences.json path, or null when the path has no directory.
/proc/cyborg_layout_sidecar_path(preferences_path)
	if(!istext(preferences_path))
		return null
	var/separator = findlasttext(preferences_path, "/")
	return separator ? "[copytext(preferences_path, 1, separator + 1)]cyborg_customization.json" : null

/// The sidecar store, created on first use. Guests and dev preferences keep it in memory only.
/datum/preferences/proc/cyborg_layout_store()
	RETURN_TYPE(/datum/json_savefile/cyborg_customization)
	if(!cyborg_layout_savefile)
		cyborg_layout_savefile = new(load_and_save && path != DEV_PREFS_PATH ? cyborg_layout_sidecar_path(path) : null)
	return cyborg_layout_savefile

/// The raw saved layout for a character slot, or null when it has none.
/datum/preferences/proc/read_cyborg_layout(slot = default_slot)
	return cyborg_layout_store().get_entry("character[slot]")

/// Stores a character slot's layout and writes the sidecar. Returns whether the write succeeded.
/datum/preferences/proc/write_cyborg_layout(slot, list/layout)
	var/datum/json_savefile/cyborg_customization/store = cyborg_layout_store()
	store.set_entry("character[slot]", cyborg_layout_copy(layout))
	return store.save()

/// Forgets a deleted slot's layout, including any unsaved draft for it, so a reused slot starts empty.
/datum/preferences/proc/remove_cyborg_layout_slot(slot)
	var/datum/preference_middleware/cyborg_character/editor = cyborg_session()
	if(editor?.draft_slot == slot)
		editor.discard_draft()
	var/datum/json_savefile/cyborg_customization/store = cyborg_layout_store()
	if(isnull(store.get_entry("character[slot]")))
		return TRUE
	store.remove_entry("character[slot]")
	return store.save()

/// Layouts carried by an uploaded preferences file, keyed by character slot. Read before pass one sanitation.
/proc/cyborg_layouts_from_import(list/upload)
	var/list/layouts = list()
	if(!islist(upload))
		return layouts
	for(var/key, value in upload)
		if(findtext(key, "character") != 1 || !islist(value))
			continue
		var/slot_number = text2num(copytext(key, 10))
		// The upload size limit bounds this; slots the import prunes leave unread entries.
		if(!isnum(slot_number) || slot_number < 1 || key != "character[round(slot_number)]")
			continue
		var/list/raw = value["silicon_genital_layout_presets"]
		if(!islist(raw))
			continue
		// A future schema is preserved as-is; the editor refuses to write it.
		layouts[key] = cyborg_layout_import_is_future(raw) ? raw : cyborg_layout_normalize(raw, allow_legacy_aliases = TRUE)
	return layouts

/// Imports replace every character, so the old layouts go and the uploaded ones take their place.
/proc/cyborg_customization_after_import(target_ckey, list/layouts)
	target_ckey = ckey(target_ckey)
	if(!length(target_ckey))
		return
	var/client/connected = GLOB.directory[target_ckey]
	for(var/datum/preferences/old_prefs as anything in list(GLOB.preferences_datums[target_ckey], connected?.prefs))
		if(!old_prefs)
			continue
		old_prefs.cyborg_session()?.discard_draft()
		if(old_prefs.cyborg_layout_savefile)
			old_prefs.cyborg_layout_savefile.path = null
			old_prefs.cyborg_layout_savefile.wipe()
	var/datum/json_savefile/cyborg_customization/store = new(null)
	store.path = "data/player_saves/[target_ckey[1]]/[target_ckey]/cyborg_customization.json"
	var/future = FALSE
	for(var/key, layout in layouts)
		store.set_entry(key, layout)
		future ||= cyborg_layout_import_is_future(layout)
	if(!length(layouts))
		fdel(store.path)
	else if(!store.save())
		to_chat(connected, span_warning("Your cyborg layouts could not be imported. Everything else was."))
	if(future)
		to_chat(connected, span_warning("A newer cyborg layout was preserved without loading because this server does not understand its schema."))
	qdel(store)
