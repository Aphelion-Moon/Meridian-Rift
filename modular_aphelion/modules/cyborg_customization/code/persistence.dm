/// The account's cyborg layout sidecar, cyborg_customization.json beside preferences.json, keyed by character slot.
/datum/json_savefile/cyborg_customization
	/// Pending durability belongs to the account, not whichever character is open now.
	var/write_pending = FALSE
	var/write_failed = FALSE
	/// The last write was refused because the whole tree encodes past CYBORG_LAYOUT_MAX_SIDECAR_BYTES.
	var/write_oversized = FALSE
	/// The file on disk was past CYBORG_LAYOUT_MAX_SIDECAR_BYTES, so it was not read and is never overwritten.
	var/read_refused = FALSE
	var/next_write_at = 0
	var/datum/weakref/preferences_ref

/// Writes the tree now if it has unsaved changes. Inside the account's spacing, SScyborg_layout_saves writes it later
/// instead, with whatever the tree holds by then; `force` writes regardless, for teardown.
/datum/json_savefile/cyborg_customization/proc/flush_pending(force = FALSE)
	if(!write_pending)
		return TRUE
	if(!force && path && world.time < next_write_at)
		request_save()
		return FALSE
	next_write_at = world.time + CYBORG_LAYOUT_SAVE_SPACING
	write_failed = !save()
	write_pending = write_failed
	var/datum/preferences/preferences = preferences_ref?.resolve()
	preferences?.cyborg_session()?.sidecar_write_completed()
	return !write_pending

/// Import replacement must cancel work owned by the superseded tree. A queued save then finds nothing to write.
/datum/json_savefile/cyborg_customization/wipe()
	write_pending = FALSE
	write_failed = FALSE
	write_oversized = FALSE
	return ..()

/datum/json_savefile/cyborg_customization/Destroy()
	flush_pending(force = TRUE)
	preferences_ref = null
	return ..()

/// The parent decodes a file of any size. An oversized one is left on disk as it is.
/datum/json_savefile/cyborg_customization/load()
	read_refused = !!(path && fexists(path) && length(file(path)) > CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
	if(read_refused)
		return FALSE
	return ..()

/// rust-g returns error text rather than a success boolean. Returns whether the file now holds the tree.
/datum/json_savefile/cyborg_customization/save()
	write_oversized = FALSE
	if(!path)
		return TRUE
	// We never saw what is in a refused file, so writing our tree over it would lose it.
	if(read_refused)
		return FALSE
	var/serialized = json_encode(get_entry())
	if(length(serialized) > CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
		write_oversized = TRUE
		return FALSE
	return !length(rustg_file_write(serialized, path))

/// What the editor tells the player about the file or the last write, null when both are fine.
/datum/json_savefile/cyborg_customization/proc/write_error()
	if(read_refused)
		return "Your saved cyborg setups are too big to load. They were left untouched and new changes can't be saved; ask an admin for help."
	if(!write_failed)
		return null
	if(write_oversized)
		return "Your cyborg setups are too big to save; all your characters share one limit. Delete presets or model defaults you no longer need. Your edits are kept until then."
	return "Could not save your cyborg setups. Your edits are retained; retry saving."

/// About how big the file would be with `text` as `key`'s entry. Other slots count without JSON escapes, so save() stays
/// the exact check; this only keeps an over-limit account from being staged at all.
/datum/json_savefile/cyborg_customization/proc/bytes_with(key, text)
	. = length(json_encode(text))
	for(var/entry_key, stored in get_entry())
		if(entry_key != key)
			. += istext(stored) ? length(stored) : length(json_encode(stored))

/// What the editor says while a character's setups are past CYBORG_LAYOUT_MAX_SLOT_BYTES.
/proc/cyborg_layout_slot_full_message()
	return "This character's cyborg setups are over the [CYBORG_LAYOUT_MAX_SLOT_BYTES / 1024] KB limit, so recent changes aren't saved. Delete presets or model defaults, or reset overrides, to save again."

/// What the editor says while saving a character would take the account past CYBORG_LAYOUT_MAX_SIDECAR_BYTES.
/proc/cyborg_layout_account_full_message()
	return "Your cyborg setups are over the limit all your characters share, so recent changes aren't saved. Delete presets or model defaults you no longer need, on this character or another."

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
	cyborg_layout_savefile.preferences_ref = WEAKREF(src)
	return cyborg_layout_savefile

/// The saved layout for a character slot, or null when it has none. Save text is decoded into a tree the caller owns.
/// A tree from an older build, or text from a newer one, comes back as stored and stays read-only.
/datum/preferences/proc/read_cyborg_layout(slot = default_slot)
	var/stored = cyborg_layout_store().get_entry("character[slot]")
	return istext(stored) && !cyborg_layout_text_is_future(stored) ? cyborg_layout_decode(stored) : stored

/// Stores a character slot's layout and writes the sidecar. Returns FALSE when the write failed, or when the layout is
/// past CYBORG_LAYOUT_MAX_SLOT_BYTES, which leaves the slot as it was.
/datum/preferences/proc/write_cyborg_layout(slot, list/layout)
	var/text = cyborg_layout_encode(layout)
	if(length(text) > CYBORG_LAYOUT_MAX_SLOT_BYTES)
		return FALSE
	var/datum/preference_middleware/cyborg_character/editor = cyborg_session()
	if(editor?.draft_slot == slot)
		// The account tree no longer holds the editor's revision, so its next commit stages the draft again.
		editor.staged_revision = -1
	return stage_cyborg_layout(slot, text)

/// Puts a slot's save text in the account tree and writes the sidecar. Returns whether the write succeeded.
/datum/preferences/proc/stage_cyborg_layout(slot, text)
	var/datum/json_savefile/cyborg_customization/store = cyborg_layout_store()
	store.set_entry("character[slot]", text)
	store.write_pending = TRUE
	return store.flush_pending()

/// Forgets a deleted slot's layout, including any unsaved draft for it, so a reused slot starts empty.
/datum/preferences/proc/remove_cyborg_layout_slot(slot)
	var/datum/preference_middleware/cyborg_character/editor = cyborg_session()
	if(editor?.draft_slot == slot)
		editor.discard_draft()
	var/datum/json_savefile/cyborg_customization/store = cyborg_layout_store()
	if(isnull(store.get_entry("character[slot]")))
		return TRUE
	store.remove_entry("character[slot]")
	store.write_pending = TRUE
	return store.flush_pending()

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
	var/too_big = 0
	var/account_bytes = 0
	for(var/key, layout in layouts)
		var/is_future = cyborg_layout_import_is_future(layout)
		var/stored = is_future ? layout : cyborg_layout_encode(layout)
		var/stored_bytes = length(json_encode(stored))
		if(!is_future && length(stored) > CYBORG_LAYOUT_MAX_SLOT_BYTES || account_bytes + stored_bytes > CYBORG_LAYOUT_MAX_SIDECAR_BYTES)
			too_big++
			continue
		account_bytes += stored_bytes
		future ||= is_future
		store.set_entry(key, stored)
	if(too_big)
		to_chat(connected, span_warning("Cyborg layouts for [too_big] character\s were too big to import and were left out."))
	if(!length(store.get_entry()))
		fdel(store.path)
	else if(!store.save())
		// The old layouts belong to the characters this import replaced, so they go even when the new ones can't be written.
		fdel(store.path)
		to_chat(connected, span_warning("Your cyborg layouts could not be imported. Everything else was."))
	if(future)
		to_chat(connected, span_warning("A newer cyborg layout was preserved without loading because this server does not understand its schema."))
	qdel(store)
