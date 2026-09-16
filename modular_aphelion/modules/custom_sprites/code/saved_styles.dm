#define CUSTOM_STYLE_JOURNAL_NAME "custom_style_transaction.json"
#define CUSTOM_STYLE_JOURNAL_FORMAT "aphelion-custom-style-transaction"
#define CUSTOM_STYLE_MAX_PREFERENCES_BYTES (8 * 1024 * 1024)

/// Account folders whose interrupted style transaction couldn't be recovered. Writes stay blocked for the round.
GLOBAL_LIST_EMPTY(custom_style_blocked_folders)

/// Fixed transaction file identities. Journals name these keys; they never supply paths.
GLOBAL_LIST_INIT(custom_style_transaction_targets, list(
	"preferences" = "preferences.json",
	"custom_sprites" = "custom_sprites.json",
))

/// Transaction reads and writes use each fixed target's existing storage limit.
/proc/custom_style_transaction_max_bytes(name)
	return name == "custom_sprites" ? CUSTOM_SPRITE_MAX_SIDECAR_BYTES : CUSTOM_STYLE_MAX_PREFERENCES_BYTES

/proc/custom_style_folder(file_path)
	if(!istext(file_path))
		return null
	var/separator = findlasttext(file_path, "/")
	return separator ? copytext(file_path, 1, separator + 1) : null

/proc/custom_style_writes_blocked(file_path)
	var/folder = custom_style_folder(file_path)
	return folder && GLOB.custom_style_blocked_folders[folder]

/proc/custom_style_transaction_files(folder)
	. = list("[folder][CUSTOM_STYLE_JOURNAL_NAME]")
	for(var/name in GLOB.custom_style_transaction_targets)
		var/live = "[folder][GLOB.custom_style_transaction_targets[name]]"
		. += list("[live].txn-new", "[live].txn-old")

/proc/custom_style_key(target, zone)
	return zone ? "[target]:[zone]" : target

/// Previous styles are trusted disk data, but still pass the strict package validator.
/proc/custom_style_previous_validate(list/raw)
	if(!islist(raw))
		return null
	var/list/clean = list()
	for(var/key in GLOB.custom_style_hair_targets + list("markings") + GLOB.custom_marking_zone_labels)
		var/target = custom_style_hair_target(key) ? key : "markings"
		var/zone = (key in GLOB.custom_marking_zone_labels) ? key : null
		var/storage_key = custom_style_key(target, zone)
		var/list/stored = raw[storage_key]
		if(!islist(stored))
			continue
		var/list/result = custom_style_validate_package(stored, null)
		var/list/package = result["package"]
		if(package && package["target"] == target && package["zone"] == zone)
			clean[storage_key] = package
	return length(clean) ? clean : null

/// Keep each previous package's native record array independent and JSON-serializable.
/proc/custom_style_copy_previous(list/previous)
	if(isnull(previous))
		return null
	. = list()
	for(var/key in previous)
		.[key] = custom_style_copy_package(previous[key])

/// Preference types in each whitelisted base look, keyed by package field.
/// Facial hair has no opacity or glow preference of its own, so those fields stay empty.
GLOBAL_LIST_INIT(custom_style_hair_preferences, list(
	"hair" = list(
		"style" = /datum/preference/choiced/hairstyle,
		"color" = /datum/preference/color/hair_color,
		"gradient_style" = /datum/preference/choiced/hair_gradient,
		"gradient_color" = /datum/preference/color/hair_gradient,
		"opacity" = /datum/preference/numeric/hair_opacity,
		"emissive" = /datum/preference/toggle/hair_emissive,
	),
	"facial_hair" = list(
		"style" = /datum/preference/choiced/facial_hairstyle,
		"color" = /datum/preference/color/facial_hair_color,
		"gradient_style" = /datum/preference/choiced/facial_hair_gradient,
		"gradient_color" = /datum/preference/color/facial_hair_gradient,
	),
))

/proc/custom_style_normal_color(color)
	return istext(color) ? custom_sprite_color(lowertext(sanitize_hexcolor(color, 6, TRUE, "#000000"))) || "#000000" : "#000000"

/// Keep explicit opacity, including fully opaque hair on naturally translucent species.
/proc/custom_style_normal_opacity(opacity)
	return isnum(opacity) && opacity >= 40 && opacity <= 255 ? round(opacity) : null

/datum/preferences/proc/custom_style_hair_context(target = "hair")
	var/list/fields = GLOB.custom_style_hair_preferences[target]
	var/opacity
	var/emissive = FALSE
	if(target != "facial_hair")
		opacity = read_preference(/datum/preference/toggle/mutant_toggle/hair_opacity) ? read_preference(fields["opacity"]) : null
		emissive = read_preference(fields["emissive"]) ? TRUE : FALSE
	return list(
		"style" = read_preference(fields["style"]),
		"color" = custom_style_normal_color(read_preference(fields["color"])),
		"gradient_style" = read_preference(fields["gradient_style"]),
		"gradient_color" = custom_style_normal_color(read_preference(fields["gradient_color"])),
		"opacity" = custom_style_normal_opacity(opacity),
		"emissive" = emissive,
	)

/proc/custom_style_live_hair_context(mob/living/carbon/human/body, target = "hair")
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	var/gradient_key = custom_style_gradient_key(target)
	var/facial = target == "facial_hair"
	var/style = facial ? (head?.facial_hairstyle || body.facial_hairstyle) : (head?.hairstyle || body.hairstyle)
	var/color = facial ? (head?.facial_hair_color || body.facial_hair_color) : (head?.hair_color || body.hair_color)
	var/opacity = facial ? null : (head ? head.hair_alpha : body.hair_alpha)
	// Native translucency needs no opacity feature; a different donor value is an override.
	if(!facial && head && isnull(body.hair_alpha) && opacity == body.dna.species.hair_alpha)
		opacity = null
	return list(
		"style" = style,
		"color" = custom_style_normal_color(color),
		"gradient_style" = head ? head.get_hair_gradient_style(gradient_key) : body.get_hair_gradient_style(gradient_key),
		"gradient_color" = custom_style_normal_color(head ? head.get_hair_gradient_color(gradient_key) : body.get_hair_gradient_color(gradient_key)),
		"opacity" = custom_style_normal_opacity(opacity),
		"emissive" = !facial && body.emissive_hair ? TRUE : FALSE,
	)

/**
 * Returns why a hair look can't be used by this character, or null when it can.
 *
 * This applies the character setup menu's feature and species rules independently of its selected
 * page, plus the character's master emissive permission.
 */
/datum/preferences/proc/custom_style_hair_problem(list/hair, target = "hair")
	if(!hair)
		return "The style has no hair settings."
	var/list/fields = GLOB.custom_style_hair_preferences[target]
	var/datum/preference/choiced/hairstyle = GLOB.preference_entries[fields["style"]]
	if(!hairstyle.is_valid(hair["style"]) || !hairstyle.has_relevant_feature(src))
		return "This character can't use that [target == "facial_hair" ? "facial hairstyle" : "hairstyle"]."
	var/datum/preference/choiced/gradient = GLOB.preference_entries[fields["gradient_style"]]
	if(!gradient.is_valid(hair["gradient_style"]))
		return "This character can't use that hair gradient."
	if(target == "facial_hair")
		return !isnull(hair["opacity"]) || hair["emissive"] ? "Facial hair has no opacity or glow settings." : null
	if(!isnull(hair["opacity"]))
		var/datum/preference/numeric/hair_opacity/opacity = GLOB.preference_entries[/datum/preference/numeric/hair_opacity]
		var/allow_mismatched_opacity = read_preference(/datum/preference/toggle/allow_mismatched_parts) && read_preference(/datum/preference/toggle/mutant_toggle/hair_opacity)
		if(!opacity.has_relevant_feature(src) && !allow_mismatched_opacity)
			return "Hair opacity isn't available for this character."
	if(hair["emissive"] && !read_preference(/datum/preference/toggle/allow_emissives))
		return "This style glows, but emissive appearance is disabled for this character."
	return null

/// The currently saved package for a target, including its native base look.
/datum/preferences/proc/custom_style_saved_package(target, zone)
	load_custom_sprites()
	var/list/drawing = custom_style_hair_target(target) ? (target == "facial_hair" ? custom_facial_hair : custom_hair) : (zone ? custom_limb_markings?[zone] : custom_markings)
	var/list/markings = target == "markings" && (zone in GLOB.body_markings_per_limb) ? custom_style_marking_entries(body_markings?[zone]) : null
	return custom_style_package(target, zone, drawing, custom_style_hair_target(target) ? custom_style_hair_context(target) : null, markings)

/datum/preferences/proc/custom_style_previous_package(target, zone)
	load_custom_sprites()
	var/list/package = custom_style_previous?[custom_style_key(target, zone)]
	return custom_style_copy_package(package)

/datum/preferences/proc/set_custom_style_drawing(target, zone, list/drawing)
	if(target == "facial_hair")
		custom_facial_hair = drawing
	else if(target == "hair")
		custom_hair = drawing
	else if(zone)
		if(drawing)
			LAZYSET(custom_limb_markings, zone, drawing)
		else
			LAZYREMOVE(custom_limb_markings, zone)
	else
		custom_markings = drawing

/**
 * Saves a complete style package to a character slot.
 *
 * Drawing-only changes use the verified sidecar writer. A changed native base look also changes
 * preferences.json, so both files are replaced through a recoverable transaction. In-memory
 * preferences, the sidecar tree and success are only published after the disk state verifies.
 * On failure, both in-memory stores are left as they were.
 *
 * Arguments:
 * - package: A validated package for this character.
 * - slot: The slot the caller bound the save to. It must still be selected.
 * - rotate: Keeps the currently saved package as the previous style. Only whole-style
 *   replacement, import, restoration and salon saves rotate it.
 * - reject_pending_hair: Refuses when the character setup menu has unsaved hair edits, rather
 *   than silently replacing them.
 * - reject_pending_markings: Refuses when the target zone has unsaved native marking edits.
 *
 * Returns:
 * - null: Saved, or already identical.
 * - text: Why nothing was saved. Safe to show the player.
 */
/datum/preferences/proc/commit_custom_style(list/package, slot, rotate = FALSE, reject_pending_hair = FALSE, reject_pending_markings = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	if(slot != default_slot)
		return "That character slot is no longer selected in character setup."
	var/target = package["target"]
	var/zone = package["zone"]
	if(!isnull(package["markings"]))
		if(target != "markings")
			return "Base markings require a supported body zone."
		var/list/markings_result = custom_style_validate_markings(package["markings"], null, zone = zone)
		if(markings_result["error"])
			return markings_result["error"]
		package = custom_style_package(target, zone, custom_sprite_validate(package["drawing"]), package["hair"], markings_result["markings"])
	else
		package = custom_style_package(target, zone, custom_sprite_validate(package["drawing"]), package["hair"])
	load_custom_sprites()
	if(load_and_save && custom_style_writes_blocked(path))
		return "Saving is paused because an earlier save couldn't be recovered. Please contact an administrator."
	var/list/current = custom_style_saved_package(target, zone)
	// A drawing-only hair package keeps the saved base look.
	if(custom_style_hair_target(target) && !package["hair"])
		package["hair"] = current["hair"]
	// Old tattoo files carry only paint and keep this zone's current native markings.
	if(("markings" in current) && !("markings" in package))
		package["markings"] = custom_style_copy_markings(current["markings"])
	if(reject_pending_markings && ("markings" in package))
		var/problem = custom_style_pending_markings_problem(slot, zone)
		if(problem)
			return problem
	// Identical packages never rotate, so repeated saves can't overwrite the real previous style.
	if(custom_style_package_hash(current) == custom_style_package_hash(package))
		return !load_and_save || !custom_sprite_savefile.dirty || custom_sprite_savefile.save() ? null : "Couldn't save to disk."
	var/list/new_previous = custom_style_previous ? custom_style_copy_previous(custom_style_previous) : list()
	if(rotate)
		new_previous[custom_style_key(target, zone)] = current
	var/hair_changed = custom_style_hair_target(target) && json_encode(package["hair"]) != json_encode(current["hair"])
	var/markings_changed = ("markings" in package) && json_encode(package["markings"]) != json_encode(current["markings"])
	if(markings_changed && !read_preference(/datum/preference/toggle/allow_emissives))
		for(var/list/entry as anything in package["markings"])
			if(entry["emissive"])
				return "This style glows, but emissive appearance is disabled for this character."
	if(hair_changed)
		var/problem = custom_style_hair_problem(package["hair"], target)
		if(problem)
			return problem
		if(reject_pending_hair)
			var/list/fields = GLOB.custom_style_hair_preferences[target]
			var/pending_hair = target == "hair" && (/datum/preference/toggle/mutant_toggle/hair_opacity in recently_updated_keys)
			for(var/field in fields)
				if(fields[field] in recently_updated_keys)
					pending_hair = TRUE
					break
			if(pending_hair)
				return "Character setup has unsaved hair changes. Close character setup, then try again."
	var/list/old_drawing = current["drawing"]
	var/list/old_previous = custom_style_previous
	set_custom_style_drawing(target, zone, package["drawing"] ? deep_copy_list(package["drawing"]) : null)
	custom_style_previous = length(new_previous) ? new_previous : null
	var/sidecar_key = "character[slot]"
	var/list/old_sidecar_entry = custom_sprite_savefile.get_entry(sidecar_key)
	store_custom_sprite_slot(slot)
	var/error
	if(!hair_changed && !markings_changed)
		if(load_and_save && !custom_sprite_savefile.save())
			error = "Couldn't save to disk."
	else if(load_and_save)
		error = commit_custom_style_transaction(slot, package["hair"], target, zone, markings_changed ? package["markings"] : null)
	if(error)
		set_custom_style_drawing(target, zone, old_drawing)
		custom_style_previous = old_previous
		if(isnull(old_sidecar_entry))
			custom_sprite_savefile.remove_entry(sidecar_key)
		else
			custom_sprite_savefile.set_entry(sidecar_key, old_sidecar_entry)
		return error
	if(hair_changed)
		publish_custom_style_hair(slot, package["hair"], target)
	if(markings_changed)
		publish_custom_style_markings(slot, zone, package["markings"])
	return null

/// Native marking lists may alias the save tree; compare the actual saved file for recipient saves.
/datum/preferences/proc/custom_style_pending_markings_problem(slot, zone)
	var/list/slot_data = savefile.get_entry("character[slot]")
	if(load_and_save)
		var/list/disk_tree
		try
			disk_tree = json_decode(custom_style_read_file(path))
		catch
			return "Couldn't verify the saved base markings. Save the character, then try again."
		if(!islist(disk_tree) || !islist(disk_tree["character[slot]"]))
			return "That character slot has no saved data yet. Save the character first."
		slot_data = disk_tree["character[slot]"]
	var/list/saved = custom_style_marking_entries(slot_data?["body_markings"]?[zone])
	if(json_encode(saved) != json_encode(custom_style_marking_entries(body_markings?[zone])))
		return "Character setup has unsaved base marking changes for this limb. Close character setup, then try again."
	return null

/// Publish only the committed zone, preserving native markings and pending edits on other limbs.
/datum/preferences/proc/publish_custom_style_markings(slot, zone, list/markings)
	var/list/slot_data = custom_style_markings_slot_data(savefile.get_entry("character[slot]"), zone, markings)
	if(slot_data)
		savefile.set_entry("character[slot]", slot_data)
	LAZYSET(body_markings, zone, custom_style_marking_data(markings))
	character_preview_view?.update_body()

/// Copy a character's saved native markings and replace exactly the selected zone, including Clear.
/proc/custom_style_markings_slot_data(list/slot_data, zone, list/markings)
	if(!islist(slot_data) || !(zone in GLOB.body_markings_per_limb))
		return null
	slot_data = deep_copy_list(slot_data)
	var/list/all_markings = slot_data["body_markings"]
	LAZYSET(all_markings, zone, custom_style_marking_data(markings))
	slot_data["body_markings"] = all_markings
	return slot_data

/// Writes a hair look into value_cache and the in-memory character tree. Disk writes happen elsewhere.
/datum/preferences/proc/publish_custom_style_hair(slot, list/hair, target = "hair")
	var/list/slot_data = custom_style_hair_slot_data(savefile.get_entry("character[slot]"), hair, target)
	if(slot_data)
		savefile.set_entry("character[slot]", slot_data)
	var/list/fields = GLOB.custom_style_hair_preferences[target]
	for(var/field in fields)
		var/preference_type = fields[field]
		recently_updated_keys -= preference_type
		value_cache -= preference_type
	if(target == "hair")
		recently_updated_keys -= /datum/preference/toggle/mutant_toggle/hair_opacity
		value_cache -= /datum/preference/toggle/mutant_toggle/hair_opacity
	character_preview_view?.update_body()

/// Returns an updated copy of a character's save data, or null when that slot has no data.
/proc/custom_style_hair_slot_data(list/slot_data, list/hair, target = "hair")
	if(!islist(slot_data))
		return null
	slot_data = deep_copy_list(slot_data)
	var/list/fields = GLOB.custom_style_hair_preferences[target]
	for(var/field in fields)
		var/datum/preference/preference = GLOB.preference_entries[fields[field]]
		var/value = hair[field]
		if(field == "opacity")
			var/datum/preference/opacity_toggle = GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity]
			slot_data[opacity_toggle.savefile_key] = !isnull(value)
			value = isnull(value) ? 255 : value
		slot_data[preference.savefile_key] = preference.serialize(value)
	return slot_data

/datum/preferences/proc/commit_custom_style_transaction(slot, list/hair, target = "hair", zone, list/markings)
	// Include other pending character edits in memory first, so this write doesn't discard them.
	save_character()
	var/list/tree = deep_copy_list(savefile.get_entry())
	var/list/slot_data = custom_style_hair_target(target) ? custom_style_hair_slot_data(tree["character[slot]"], hair, target) : custom_style_markings_slot_data(tree["character[slot]"], zone, markings)
	if(!slot_data)
		return "That character slot has no saved data yet. Save the character first."
	tree["character[slot]"] = slot_data
	var/datum/custom_style_transaction/transaction = new(custom_style_folder(path), custom_sprite_savefile)
	transaction.contents["preferences"] = json_encode(tree, JSON_PRETTY_PRINT)
	transaction.contents["custom_sprites"] = json_encode(custom_sprite_savefile.get_entry())
	. = transaction.commit()
	qdel(transaction)

/**
 * A narrowly scoped, verified replacement of preferences.json and custom_sprites.json.
 *
 * Phases:
 * 1. Stage both new files and read them back.
 * 2. Keep verified recovery copies of both live files, and the sidecar's normal .bak.
 * 3. Write a server-generated journal in the prepared state.
 * 4. Replace and verify both live files.
 * 5. Mark the journal committed, then remove staging, recovery copies and finally the journal.
 *
 * custom_style_recover_transaction() completes or reverses an interrupted run. Tests override
 * write_file() and checkpoint() to inject failures and crashes.
 */
/datum/custom_style_transaction
	/// Server-selected account folder containing both transaction targets.
	var/folder
	/// Drawing store committed alongside the character preferences.
	var/datum/json_savefile/custom_sprites/sidecar
	/// Transaction name -> new contents.
	var/list/contents = list()
	/// Server-generated identifier for this save transaction.
	var/id

/datum/custom_style_transaction/New(folder, datum/json_savefile/custom_sprites/sidecar)
	src.folder = folder
	src.sidecar = sidecar
	id = md5("[world.realtime]-[world.time]-[rand(1, 1e9)]-[REF(src)]")

/datum/custom_style_transaction/Destroy()
	sidecar = null
	return ..()

/datum/custom_style_transaction/proc/write_file(text, destination)
	return rustg_file_write(text, destination)

/datum/custom_style_transaction/proc/write_verified(text, destination)
	return !length(write_file(text, destination)) && rustg_file_read(destination) == text

/// Returns FALSE to simulate the server stopping after a phase. Production never stops.
/datum/custom_style_transaction/proc/checkpoint(phase)
	return TRUE

/datum/custom_style_transaction/proc/live_path(name)
	return "[folder][GLOB.custom_style_transaction_targets[name]]"

/// Returns null on success, or a player-facing error after restoring the previous files.
/datum/custom_style_transaction/proc/commit()
	if(!folder || !sidecar || isnull(sidecar.last_good_json))
		return "Couldn't save to disk."
	if(!custom_style_recover_transaction(folder))
		return "Saving is paused because an earlier save couldn't be recovered. Please contact an administrator."
	var/list/journal_files = list()
	for(var/name in GLOB.custom_style_transaction_targets)
		var/text = contents[name]
		var/live = live_path(name)
		var/max_bytes = custom_style_transaction_max_bytes(name)
		if(!istext(text) || length(text) > max_bytes || !write_verified(text, "[live].txn-new"))
			return abandon("staging")
		var/existed = fexists(live)
		var/old_text = existed ? custom_style_read_file(live, max_bytes) : null
		if(existed && (isnull(old_text) || !write_verified(old_text, "[live].txn-old")))
			return abandon("recovery copy")
		journal_files[name] = list("existed" = existed, "old" = existed ? md5(old_text) : null, "new" = md5(text))
	if(!checkpoint("staged"))
		return "crashed"
	var/sidecar_backup = "[live_path("custom_sprites")].bak"
	if(rustg_file_read(sidecar_backup) != sidecar.last_good_json && !write_verified(sidecar.last_good_json, sidecar_backup))
		return abandon("sidecar backup")
	var/list/journal = list("format" = CUSTOM_STYLE_JOURNAL_FORMAT, "version" = 1, "id" = id, "state" = "prepared", "files" = journal_files)
	if(!write_verified(json_encode(journal), "[folder][CUSTOM_STYLE_JOURNAL_NAME]"))
		return abandon("journal")
	if(!checkpoint("prepared"))
		return "crashed"
	for(var/name in GLOB.custom_style_transaction_targets)
		if(!write_verified(contents[name], live_path(name)))
			return roll_back("replace [name]", journal)
		if(!checkpoint("replaced [name]"))
			return "crashed"
	// Keep the prepared journal authoritative for active rollback if this final write is damaged.
	var/list/committed_journal = journal.Copy()
	committed_journal["state"] = "committed"
	if(!write_verified(json_encode(committed_journal), "[folder][CUSTOM_STYLE_JOURNAL_NAME]"))
		return roll_back("commit journal", journal)
	if(!checkpoint("committed"))
		return "crashed"
	if(length(sidecar.pending_removed_entries))
		var/list/backup = json_decode(sidecar.last_good_json)
		for(var/key in sidecar.pending_removed_entries)
			backup -= key
		if(write_verified(json_encode(backup), sidecar_backup))
			sidecar.pending_removed_entries = null
	sidecar.last_good_json = contents["custom_sprites"]
	sidecar.dirty = FALSE
	sidecar.last_save_failed = FALSE
	custom_style_finish_transaction(folder)
	return null

/// Before any live file changes, leftover material can simply be removed.
/datum/custom_style_transaction/proc/abandon(phase)
	log_game("Custom style transaction [id] stopped before replacement ([phase]).")
	custom_style_finish_transaction(folder)
	return "Couldn't save to disk."

/datum/custom_style_transaction/proc/roll_back(phase, list/prepared_journal)
	log_game("Custom style transaction [id] failed during [phase]; restoring the previous files.")
	// Crash recovery may accept two new files; a rejected active commit must restore the old pair.
	if(!custom_style_recover_journal(folder, prepared_journal))
		GLOB.custom_style_blocked_folders[folder] = TRUE
		return "Saving failed and couldn't be undone automatically. Saving is paused; please contact an administrator."
	custom_style_finish_transaction(folder)
	return "Couldn't save to disk."

/proc/custom_style_finish_transaction(folder)
	for(var/transaction_file in custom_style_transaction_files(folder))
		if(copytext(transaction_file, -length(CUSTOM_STYLE_JOURNAL_NAME)) != CUSTOM_STYLE_JOURNAL_NAME)
			fdel(transaction_file)
	// The journal goes last: until then, an interruption is still recoverable.
	fdel("[folder][CUSTOM_STYLE_JOURNAL_NAME]")

/proc/custom_style_read_file(file_path, max_bytes = CUSTOM_STYLE_MAX_PREFERENCES_BYTES)
	if(!fexists(file_path) || length(file(file_path)) > max_bytes)
		return null
	return rustg_file_read(file_path)

/**
 * Completes or reverses an interrupted style transaction for one account folder.
 *
 * Call this before loading or writing either file. With no journal, stray staging material is
 * removed. A prepared journal restores both old files from verified recovery copies. A committed
 * journal only finishes cleanup once both live files match their new contents. A corrupt journal
 * was interrupted while being written; both files are then compared with their staged and
 * recovery copies instead.
 *
 * Returns:
 * - TRUE: No transaction is pending.
 * - FALSE: Recovery failed. Recovery material is preserved and writes to this folder are
 *   blocked for the round.
 */
/proc/custom_style_recover_transaction(folder)
	if(!folder || GLOB.custom_style_blocked_folders[folder])
		return !GLOB.custom_style_blocked_folders[folder]
	var/journal_path = "[folder][CUSTOM_STYLE_JOURNAL_NAME]"
	if(!fexists(journal_path))
		custom_style_finish_transaction(folder)
		return TRUE
	var/list/journal
	try
		journal = json_decode(custom_style_read_file(journal_path, 16384))
	catch
		journal = null
	var/list/files = islist(journal) ? journal["files"] : null
	var/valid = islist(files) && journal["format"] == CUSTOM_STYLE_JOURNAL_FORMAT && (journal["state"] in list("prepared", "committed"))
	for(var/name in GLOB.custom_style_transaction_targets)
		var/list/entry = valid ? files[name] : null
		if(!islist(entry) || !istext(entry["new"]) || !(entry["existed"] in list(TRUE, FALSE)) || (entry["existed"] && !istext(entry["old"])))
			valid = FALSE
	var/recovered = valid ? custom_style_recover_journal(folder, journal) : custom_style_recover_contents(folder)
	if(!recovered)
		GLOB.custom_style_blocked_folders[folder] = TRUE
		log_game("Custom style transaction recovery failed in [folder]. Recovery files were kept and writes are blocked.")
		return FALSE
	custom_style_finish_transaction(folder)
	return TRUE

/proc/custom_style_recover_journal(folder, list/journal)
	for(var/name in GLOB.custom_style_transaction_targets)
		var/list/entry = journal["files"][name]
		var/live = "[folder][GLOB.custom_style_transaction_targets[name]]"
		var/max_bytes = custom_style_transaction_max_bytes(name)
		var/live_text = custom_style_read_file(live, max_bytes)
		if(journal["state"] == "committed")
			if(isnull(live_text) || md5(live_text) != entry["new"])
				return FALSE
			continue
		if(!entry["existed"])
			fdel(live)
			if(fexists(live))
				return FALSE
			continue
		if(!isnull(live_text) && md5(live_text) == entry["old"])
			continue
		var/old_text = custom_style_read_file("[live].txn-old", max_bytes)
		if(isnull(old_text) || md5(old_text) != entry["old"] || length(rustg_file_write(old_text, live)) || rustg_file_read(live) != old_text)
			return FALSE
	log_game("Recovered an interrupted custom style transaction in [folder] ([journal["state"]]).")
	return TRUE

/// The journal is only written after staging and recovery copies verify, so those copies are authoritative.
/proc/custom_style_recover_contents(folder)
	var/all_new = TRUE
	for(var/name in GLOB.custom_style_transaction_targets)
		var/live = "[folder][GLOB.custom_style_transaction_targets[name]]"
		var/max_bytes = custom_style_transaction_max_bytes(name)
		var/new_text = custom_style_read_file("[live].txn-new", max_bytes)
		if(isnull(new_text) || custom_style_read_file(live, max_bytes) != new_text)
			all_new = FALSE
	if(all_new)
		return TRUE
	for(var/name in GLOB.custom_style_transaction_targets)
		var/live = "[folder][GLOB.custom_style_transaction_targets[name]]"
		if(!fexists("[live].txn-new"))
			return FALSE
		var/max_bytes = custom_style_transaction_max_bytes(name)
		var/old_text = custom_style_read_file("[live].txn-old", max_bytes)
		if(isnull(old_text))
			// A rejected recovery copy cannot prove that the old live file never existed.
			if(fexists("[live].txn-old"))
				return FALSE
			fdel(live)
			if(fexists(live))
				return FALSE
		else if(custom_style_read_file(live, max_bytes) != old_text && (length(rustg_file_write(old_text, live)) || rustg_file_read(live) != old_text))
			return FALSE
	log_game("Recovered a custom style transaction with an unreadable journal in [folder].")
	return TRUE

/// Character preferences recover any interrupted style transaction before loading, and stop writing if that fails.
/datum/json_savefile/preferences

/datum/json_savefile/preferences/New(path)
	if(path)
		custom_style_recover_transaction(custom_style_folder(path))
	return ..()

/datum/json_savefile/preferences/load()
	. = ..()
	if(. || !custom_style_writes_blocked(path))
		return
	// Unrecoverable writes are blocked; show the last verified copy rather than a random character.
	var/list/recovery
	try
		recovery = json_decode(custom_style_read_file("[path].txn-old"))
	catch
		recovery = null
	if(!islist(recovery))
		return
	wipe()
	for(var/key in recovery)
		set_entry(key, recovery[key])
	return TRUE

/datum/json_savefile/preferences/save()
	if(custom_style_writes_blocked(path))
		return
	return ..()

#undef CUSTOM_STYLE_JOURNAL_NAME
#undef CUSTOM_STYLE_JOURNAL_FORMAT
#undef CUSTOM_STYLE_MAX_PREFERENCES_BYTES
