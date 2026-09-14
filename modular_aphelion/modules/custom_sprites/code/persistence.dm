#define CUSTOM_SPRITE_MAX_SIDECAR_BYTES (8 * 1024 * 1024)

/datum/json_savefile/custom_sprites
	/// Includes changes from other targets/slots after a failed disk save.
	var/dirty = FALSE
	var/last_save_failed = FALSE
	/// The verified prior file, never replaced with a corrupt primary during recovery.
	var/last_good_json = "\[]"
	/// Deleted identities must also be removed from the recovery copy before acknowledging a save.
	var/list/pending_removed_entries

/datum/json_savefile/custom_sprites/New(path)
	. = ..()
	// The parent only calls load() when the primary exists.
	if(path && !fexists(path) && fexists("[path].bak"))
		load()

/datum/json_savefile/custom_sprites/set_entry(key, value)
	dirty = TRUE
	return ..()

/datum/json_savefile/custom_sprites/remove_entry(key)
	dirty = TRUE
	if(key)
		LAZYOR(pending_removed_entries, key)
	return ..()

/datum/json_savefile/custom_sprites/wipe()
	dirty = TRUE
	return ..()

/// The parent JSON store logs malformed JSON; an optional drawing sidecar must fail quietly.
/datum/json_savefile/custom_sprites/proc/read_snapshot(snapshot_path)
	if(!snapshot_path || !fexists(snapshot_path) || length(file(snapshot_path)) > CUSTOM_SPRITE_MAX_SIDECAR_BYTES)
		return null
	try
		var/contents = rustg_file_read(snapshot_path)
		var/list/decoded = json_decode(contents)
		if(islist(decoded))
			return list("text" = contents, "data" = decoded)
	catch
		return null
	return null

/datum/json_savefile/custom_sprites/load()
	wipe()
	pending_removed_entries = null
	last_good_json = null
	last_save_failed = FALSE
	if(!path)
		return FALSE
	var/list/snapshot = read_snapshot(path)
	var/recovered = FALSE
	if(!snapshot)
		snapshot = read_snapshot("[path].bak")
		recovered = TRUE
	if(!snapshot)
		return FALSE
	var/list/decoded = snapshot["data"]
	for(var/slot in 1 to MAX_SAVE_SLOTS_SUBSCRIBER)
		var/key = "character[slot]"
		if(islist(decoded[key]))
			set_entry(key, decoded[key])
	last_good_json = snapshot["text"]
	dirty = recovered
	return TRUE

/// rust-g returns error text, not a success boolean; a full readback also catches short writes.
/datum/json_savefile/custom_sprites/proc/write_verified(contents, destination)
	var/write_error = write_file(contents, destination)
	return !length(write_error) && rustg_file_read(destination) == contents

/datum/json_savefile/custom_sprites/proc/write_file(contents, destination)
	return rustg_file_write(contents, destination)

/datum/json_savefile/custom_sprites/save()
	if(!dirty && !last_save_failed)
		return TRUE
	last_save_failed = TRUE
	if(!path || isnull(last_good_json))
		return FALSE
	var/serialized
	var/staging_path = "[path].new"
	var/backup_path = "[path].bak"
	var/previous_json = last_good_json
	try
		serialized = json_encode(get_entry())
		if(length(serialized) > CUSTOM_SPRITE_MAX_SIDECAR_BYTES || !write_verified(serialized, staging_path))
			return FALSE
		// After fallback the backup may be the only good copy: do not rewrite it.
		if(rustg_file_read(backup_path) != last_good_json && !write_verified(last_good_json, backup_path))
			return FALSE
		// rust-g flushes and syncs each file, but replacement is not atomic.
		// An interrupted primary can recover the previous revision from the verified backup.
		if(!write_verified(serialized, path))
			return FALSE
		last_good_json = serialized
		if(length(pending_removed_entries))
			var/list/backup = json_decode(previous_json)
			for(var/key in pending_removed_entries)
				backup -= key
			// Primary is verified before scrubbing. Failure leaves it intact and the deletion retryable.
			if(!write_verified(json_encode(backup), backup_path))
				return FALSE
			pending_removed_entries = null
	catch
		return FALSE
	last_good_json = serialized
	dirty = FALSE
	last_save_failed = FALSE
	fdel(staging_path)
	return TRUE

/datum/preferences
	var/datum/json_savefile/custom_sprites/custom_sprite_savefile
	var/custom_sprite_slot
	var/list/custom_hair
	var/list/custom_markings
	var/list/custom_limb_markings
	var/list/custom_sprite_editors = list()

/proc/custom_sprite_sidecar_path(preferences_path)
	if(!istext(preferences_path))
		return null
	var/separator = findlasttext(preferences_path, "/")
	return separator ? "[copytext(preferences_path, 1, separator + 1)]custom_sprites.json" : null

/datum/preferences/proc/load_custom_sprites()
	if(!custom_sprite_savefile)
		custom_sprite_savefile = new(load_and_save ? custom_sprite_sidecar_path(path) : null)
	if(custom_sprite_slot == default_slot)
		return
	custom_sprite_slot = default_slot
	var/list/slot_data = custom_sprite_savefile.get_entry("character[default_slot]")
	custom_hair = islist(slot_data) ? custom_sprite_validate(slot_data["hair"]) : null
	custom_markings = islist(slot_data) ? custom_sprite_validate(slot_data["markings"]) : null
	custom_limb_markings = islist(slot_data) ? custom_limb_markings_validate(slot_data["limb_markings"]) : null

/// TRUE means saved or unchanged. Failures retain the draft and whole-store dirty state for retry.
/// Ordinary preference saves never rewrite this sidecar.
/datum/preferences/proc/save_custom_sprite(target, list/drawing, slot = default_slot, body_zone = null)
	if(!(target in list("hair", "markings")) || slot != default_slot)
		return FALSE
	if(!isnull(body_zone) && (target != "markings" || !istext(body_zone) || !(body_zone in GLOB.custom_marking_zone_labels)))
		return FALSE
	load_custom_sprites()
	var/list/clean = custom_sprite_validate(drawing)
	var/list/old_drawing = target == "hair" ? custom_hair : (body_zone ? custom_limb_markings?[body_zone] : custom_markings)
	if(json_encode(old_drawing) == json_encode(clean))
		return !load_and_save || !custom_sprite_savefile.dirty || custom_sprite_savefile.save()
	if(target == "hair")
		custom_hair = clean
	else if(body_zone)
		if(clean)
			LAZYSET(custom_limb_markings, body_zone, clean)
		else
			LAZYREMOVE(custom_limb_markings, body_zone)
	else
		custom_markings = clean
	var/list/slot_data = list()
	if(custom_hair)
		slot_data["hair"] = deep_copy_list(custom_hair)
	if(custom_markings)
		slot_data["markings"] = deep_copy_list(custom_markings)
	if(length(custom_limb_markings))
		slot_data["limb_markings"] = deep_copy_list(custom_limb_markings)
	if(length(slot_data))
		custom_sprite_savefile.set_entry("character[slot]", slot_data)
	else
		custom_sprite_savefile.remove_entry("character[slot]")
	if(load_and_save)
		return custom_sprite_savefile.save()
	return TRUE

/datum/preferences/proc/remove_custom_sprite_slot(slot)
	load_custom_sprites()
	var/key = "character[slot]"
	if(!isnull(custom_sprite_savefile.get_entry(key)))
		custom_sprite_savefile.remove_entry(key)
	if(custom_sprite_slot == slot)
		custom_sprite_slot = null
		custom_hair = null
		custom_markings = null
		custom_limb_markings = null
	return !load_and_save || !custom_sprite_savefile.dirty || custom_sprite_savefile.save()

/datum/preferences/proc/close_custom_sprite_editors(save_changes = TRUE)
	for(var/target in custom_sprite_editors.Copy())
		var/datum/custom_sprite_editor/editor = custom_sprite_editors[target]
		editor.finish(save_changes)

/// Imports replace the character identities, so an old slot's drawings cannot carry across.
/proc/custom_sprites_after_import(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!length(target_ckey))
		return
	var/sidecar = "data/player_saves/[target_ckey[1]]/[target_ckey]/custom_sprites.json"
	for(var/drawing_file in list(sidecar, "[sidecar].bak", "[sidecar].new"))
		if(fexists(drawing_file))
			fdel(drawing_file)
	var/client/connected = GLOB.directory[target_ckey]
	for(var/datum/preferences/old_prefs as anything in list(GLOB.preferences_datums[target_ckey], connected?.prefs))
		if(!old_prefs)
			continue
		old_prefs.close_custom_sprite_editors(FALSE)
		if(old_prefs.custom_sprite_savefile)
			old_prefs.custom_sprite_savefile.path = null
			old_prefs.custom_sprite_savefile.wipe()
		old_prefs.custom_hair = null
		old_prefs.custom_markings = null
		old_prefs.custom_limb_markings = null
		old_prefs.custom_sprite_slot = null
