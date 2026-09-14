/// The parent JSON store logs malformed JSON; an optional drawing sidecar must fail quietly.
/datum/json_savefile/custom_sprites/load()
	wipe()
	if(!path || !fexists(path) || length(file(path)) > 2 * 1024 * 1024)
		return FALSE
	var/list/decoded
	try
		decoded = json_decode(rustg_file_read(path))
	catch
		return FALSE
	if(!islist(decoded))
		return FALSE
	for(var/slot in 1 to MAX_SAVE_SLOTS_SUBSCRIBER)
		var/key = "character[slot]"
		if(islist(decoded[key]))
			set_entry(key, decoded[key])
	return TRUE

/datum/preferences
	var/datum/json_savefile/custom_sprites/custom_sprite_savefile
	var/custom_sprite_slot
	var/list/custom_hair
	var/list/custom_markings
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

/// Writes only on an actual drawing change, never from ordinary preference saves.
/datum/preferences/proc/save_custom_sprite(target, list/drawing, slot = default_slot)
	if(!(target in list("hair", "markings")) || slot != default_slot)
		return FALSE
	load_custom_sprites()
	var/list/clean = custom_sprite_validate(drawing)
	var/list/old_drawing = target == "hair" ? custom_hair : custom_markings
	if(json_encode(old_drawing) == json_encode(clean))
		return FALSE
	if(target == "hair")
		custom_hair = clean
	else
		custom_markings = clean
	var/list/slot_data = list()
	if(custom_hair)
		slot_data["hair"] = deep_copy_list(custom_hair)
	if(custom_markings)
		slot_data["markings"] = deep_copy_list(custom_markings)
	if(length(slot_data))
		custom_sprite_savefile.set_entry("character[slot]", slot_data)
	else
		custom_sprite_savefile.remove_entry("character[slot]")
	if(load_and_save)
		custom_sprite_savefile.save()
	return TRUE

/datum/preferences/proc/remove_custom_sprite_slot(slot)
	load_custom_sprites()
	var/key = "character[slot]"
	if(!isnull(custom_sprite_savefile.get_entry(key)))
		custom_sprite_savefile.remove_entry(key)
		if(load_and_save)
			custom_sprite_savefile.save()
	if(custom_sprite_slot == slot)
		custom_sprite_slot = null
		custom_hair = null
		custom_markings = null

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
	if(fexists(sidecar))
		fdel(sidecar)
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
		old_prefs.custom_sprite_slot = null
