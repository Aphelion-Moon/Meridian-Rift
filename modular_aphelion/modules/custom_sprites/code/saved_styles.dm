#define CUSTOM_STYLE_MAX_PREFERENCES_BYTES (8 * 1024 * 1024)

/proc/custom_style_key(target, zone)
	return zone ? "[target]:[zone]" : target

/// Previous styles are trusted disk data, but still pass the strict package validator.
/proc/custom_style_previous_validate(list/raw)
	if(!islist(raw))
		return null
	var/list/clean = list()
	for(var/key in GLOB.custom_style_hair_targets + GLOB.custom_marking_zone_labels)
		var/target = custom_style_hair_target(key) ? key : "markings"
		var/zone = (key in GLOB.custom_marking_zone_labels) ? key : null
		var/storage_key = custom_style_key(target, zone)
		var/list/stored = raw[storage_key]
		if(!islist(stored))
			continue
		var/list/result = custom_style_validate_package(stored, trusted = TRUE)
		var/list/package = result["package"]
		if(package && package["target"] == target && package["zone"] == zone)
			clean[storage_key] = package
	return length(clean) ? clean : null

/// Keep each previous package's native record array independent and JSON-serializable.
/proc/custom_style_copy_previous(list/previous)
	if(isnull(previous))
		return null
	. = list()
	for(var/key, package in previous)
		.[key] = custom_style_copy_package(package)

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
	return sanitize_hexcolor(color, 6, TRUE, "#000000")

/// Keep explicit opacity, including fully opaque hair on naturally translucent species.
/proc/custom_style_normal_opacity(opacity)
	return isnum(opacity) && opacity >= /datum/preference/numeric/hair_opacity::minimum && opacity <= /datum/preference/numeric/hair_opacity::maximum ? round(opacity) : null

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
	var/list/drawing = custom_style_hair_target(target) ? (target == "facial_hair" ? custom_facial_hair : custom_hair) : custom_limb_markings?[zone]
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
	else if(drawing)
		LAZYSET(custom_limb_markings, zone, drawing)
	else
		LAZYREMOVE(custom_limb_markings, zone)

/**
 * Saves one style package to a character slot. See commit_custom_styles().
 *
 * Arguments:
 * - rotate: Keeps the currently saved package as the previous style. Only whole-style
 *   replacement, import, restoration and salon saves rotate it.
 */
/datum/preferences/proc/commit_custom_style(list/package, slot, rotate = FALSE, reject_pending_hair = FALSE, reject_pending_markings = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	return commit_custom_styles(list(package), slot, rotate ? list(custom_style_key(package["target"], package["zone"])) : null, reject_pending_hair, reject_pending_markings)

/**
 * Saves several style packages to a character slot in one sidecar write.
 *
 * Every package is validated before anything changes. Packages identical to what's saved are
 * skipped and never rotate. The drawings are written first, through the verified sidecar writer,
 * once; if that fails, every package is rolled back and nothing in memory changes. Changed native
 * base looks are then published and preferences.json written once, so an interruption between the
 * two writes can only leave new drawings on old base looks.
 *
 * Arguments:
 * - packages: Canonical packages, at most one per target and zone.
 * - slot: The slot the caller bound the save to. It must still be selected.
 * - rotate_keys: Style keys (custom_style_key()) whose saved package becomes the previous style.
 * - reject_pending_hair: Refuses when character setup has unsaved hair edits.
 * - reject_pending_markings: Refuses when a target zone has unsaved native marking edits.
 *
 * Returns:
 * - null: Saved, or already identical.
 * - text: Why nothing was saved. Safe to show the player.
 */
/datum/preferences/proc/commit_custom_styles(list/packages, slot, list/rotate_keys, reject_pending_hair = FALSE, reject_pending_markings = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	if(slot != default_slot)
		return "That character slot is no longer selected in character setup."
	load_custom_sprites()
	var/list/prepared = list()
	for(var/list/package as anything in packages)
		var/list/result = prepare_custom_style(package, slot, reject_pending_hair, reject_pending_markings)
		if(result["error"])
			return result["error"]
		if(result["package"])
			prepared += list(result)
	if(!length(prepared))
		return !load_and_save || !custom_sprite_savefile.dirty || custom_sprite_savefile.save() ? null : "Couldn't save to disk."
	var/list/old_previous = custom_style_previous
	var/list/new_previous = custom_style_copy_previous(custom_style_previous) || list()
	for(var/list/entry as anything in prepared)
		var/list/package = entry["package"]
		var/key = custom_style_key(package["target"], package["zone"])
		if(key in rotate_keys)
			new_previous[key] = entry["current"]
		set_custom_style_drawing(package["target"], package["zone"], deep_copy_list(package["drawing"]))
	custom_style_previous = length(new_previous) ? new_previous : null
	var/sidecar_key = "character[slot]"
	var/list/old_sidecar_entry = custom_sprite_savefile.get_entry(sidecar_key)
	store_custom_sprite_slot(slot)
	if(load_and_save && !custom_sprite_savefile.save())
		for(var/list/entry as anything in prepared)
			var/list/package = entry["package"]
			set_custom_style_drawing(package["target"], package["zone"], entry["current"]["drawing"])
		custom_style_previous = old_previous
		if(isnull(old_sidecar_entry))
			custom_sprite_savefile.remove_entry(sidecar_key)
		else
			custom_sprite_savefile.set_entry(sidecar_key, old_sidecar_entry)
		return "Couldn't save to disk."
	var/write_base = FALSE
	for(var/list/entry as anything in prepared)
		write_base ||= entry["hair_changed"] || entry["markings_changed"]
	write_base = write_base && load_and_save
	if(write_base)
		// Keeps pending character setup edits, and creates the slot's entry if it has none.
		save_character()
	for(var/list/entry as anything in prepared)
		var/list/package = entry["package"]
		if(entry["hair_changed"])
			publish_custom_style_hair(slot, package["hair"], package["target"])
		if(entry["markings_changed"])
			publish_custom_style_markings(slot, package["zone"], package["markings"])
	if(write_base)
		savefile.save()
	return null

/**
 * Validates one package against the saved character without changing anything.
 *
 * Returns:
 * - list("error" = text): Nothing may be saved.
 * - list("package" = null): Identical to what's saved.
 * - list("package", "current", "hair_changed", "markings_changed"): Ready to write.
 */
/datum/preferences/proc/prepare_custom_style(list/package, slot, reject_pending_hair, reject_pending_markings)
	var/target = package["target"]
	var/zone = package["zone"]
	var/list/markings
	if(!isnull(package["markings"]))
		if(target != "markings")
			return list("error" = "Base markings require a supported body zone.")
		var/list/markings_result = custom_style_validate_markings(package["markings"], zone)
		if(markings_result["error"])
			return markings_result
		markings = markings_result["markings"]
	package = custom_style_package(target, zone, custom_sprite_validate(package["drawing"]), package["hair"], markings)
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
			return list("error" = problem)
	// Identical packages never rotate, so repeated saves can't overwrite the real previous style.
	if(custom_style_package_hash(current) == custom_style_package_hash(package))
		return list("package" = null)
	var/hair_changed = custom_style_hair_target(target) && json_encode(package["hair"]) != json_encode(current["hair"])
	var/markings_changed = ("markings" in package) && json_encode(package["markings"]) != json_encode(current["markings"])
	if(markings_changed && !read_preference(/datum/preference/toggle/allow_emissives))
		for(var/list/entry as anything in package["markings"])
			if(entry["emissive"])
				return list("error" = "This style glows, but emissive appearance is disabled for this character.")
	if(hair_changed)
		var/problem = custom_style_hair_problem(package["hair"], target)
		if(problem)
			return list("error" = problem)
		if(reject_pending_hair)
			var/list/fields = GLOB.custom_style_hair_preferences[target]
			var/pending_hair = target == "hair" && (/datum/preference/toggle/mutant_toggle/hair_opacity in recently_updated_keys)
			for(var/_field, preference_type in fields)
				if(preference_type in recently_updated_keys)
					pending_hair = TRUE
					break
			if(pending_hair)
				return list("error" = "Character setup has unsaved hair changes. Close character setup, then try again.")
	return list("package" = package, "current" = current, "hair_changed" = hair_changed, "markings_changed" = markings_changed)

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

/**
 * Redraws the character setup preview without waiting on it.
 *
 * Saves and teardown must not sleep, but the preview renderer can reach resolve_ai_icon(), whose
 * Portrait branch opens a window. Character setup never offers Portrait, so in practice this runs
 * straight through; detaching it keeps the no-sleep guarantee without editing the renderer.
 */
/datum/preferences/proc/refresh_custom_sprite_preview()
	if(character_preview_view)
		INVOKE_ASYNC(character_preview_view, TYPE_PROC_REF(/atom/movable/screen/map_view/char_preview, update_body))

/// Publish only the committed zone, preserving native markings and pending edits on other limbs.
/datum/preferences/proc/publish_custom_style_markings(slot, zone, list/markings)
	var/list/slot_data = custom_style_markings_slot_data(savefile.get_entry("character[slot]"), zone, markings)
	if(slot_data)
		savefile.set_entry("character[slot]", slot_data)
	LAZYSET(body_markings, zone, custom_style_marking_data(markings))
	refresh_custom_sprite_preview()

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
	for(var/_field, preference_type in fields)
		recently_updated_keys -= preference_type
		value_cache -= preference_type
	if(target == "hair")
		recently_updated_keys -= /datum/preference/toggle/mutant_toggle/hair_opacity
		value_cache -= /datum/preference/toggle/mutant_toggle/hair_opacity
	refresh_custom_sprite_preview()

/// Returns an updated copy of a character's save data, or null when that slot has no data.
/proc/custom_style_hair_slot_data(list/slot_data, list/hair, target = "hair")
	if(!islist(slot_data))
		return null
	slot_data = deep_copy_list(slot_data)
	var/list/fields = GLOB.custom_style_hair_preferences[target]
	for(var/field, preference_type in fields)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		var/value = hair[field]
		if(field == "opacity")
			var/datum/preference/opacity_toggle = GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity]
			slot_data[opacity_toggle.savefile_key] = !isnull(value)
			value = isnull(value) ? 255 : value
		slot_data[preference.savefile_key] = preference.serialize(value)
	return slot_data

/proc/custom_style_read_file(file_path, max_bytes = CUSTOM_STYLE_MAX_PREFERENCES_BYTES)
	if(!fexists(file_path) || length(file(file_path)) > max_bytes)
		return null
	return rustg_file_read(file_path)

#undef CUSTOM_STYLE_MAX_PREFERENCES_BYTES
