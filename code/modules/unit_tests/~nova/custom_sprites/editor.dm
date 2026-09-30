/// Whether two GetPixel() results are the same colour to within the rounding iconforge and BYOND's icon procs differ by.
/proc/custom_sprite_test_close_pixel(first, second)
	if(first == second)
		return TRUE
	var/list/first_rgba = first ? rgb2num(first) : list(0, 0, 0, 0)
	var/list/second_rgba = second ? rgb2num(second) : list(0, 0, 0, 0)
	if(length(first_rgba) < 4)
		first_rgba += 255
	if(length(second_rgba) < 4)
		second_rgba += 255
	for(var/channel in 1 to 4)
		if(abs(first_rgba[channel] - second_rgba[channel]) > 2)
			return FALSE
	return TRUE

/// The first pixel this draft may paint in one view.
/proc/custom_sprite_test_paintable_point(datum/custom_sprite_editor/editor, direction = "2")
	var/list/bounds = editor.workspace.draw_bounds[direction]
	for(var/y in bounds[2] to bounds[4])
		for(var/x in bounds[1] to bounds[3])
			if(editor.workspace.is_point_allowed(x, y, direction))
				return list(x, y)

/// Save and close writes the draft and releases its editor, and Discard keeps the last saved drawing.
/datum/unit_test/custom_sprite_editor_lifecycle/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))
	TEST_ASSERT(editor.workspace.new_transaction(stroke), "The editor rejected a sampled shade within its own bounds.")
	editor.finish(TRUE)
	TEST_ASSERT(!(!preferences.custom_hair || preferences.custom_sprite_editors?["hair"]), "Closing must save the drawing and release its editor.")
	var/saved_hash = custom_sprite_hash(preferences.custom_hair)
	editor = new(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	editor.workspace.clear_direction("2")
	editor.finish(FALSE)
	TEST_ASSERT(saved_hash == custom_sprite_hash(preferences.custom_hair), "Discard must preserve the last saved drawing.")

/// Exercise the real UI actions without requiring a connected BYOND client.
/datum/custom_sprite_editor/optimization_test/can_edit(mob/user)
	return !closing

/// Cancelling an import or restore preview keeps the draft, confirming replaces it, and a preview the draft changed under is refused.
/datum/unit_test/custom_sprite_candidate_dismissal/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/empty_package = editor.current_package()
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))), "The candidate dismissal fixture must start with a painted draft.")
	var/draft_hash = custom_sprite_hash(editor.workspace.serialize_drawing())
	for(var/action in list("cancelCandidate", "confirmCandidate"))
		TEST_ASSERT(editor.show_candidate(empty_package, "import"), "An empty style must offer a confirmable preview: [editor.transfer_error]")
		editor.run_deferred_work()
		TEST_ASSERT(editor.ui_act(action, list(), ui, null) && !editor.candidate, "[action] must dismiss the preview.")
		TEST_ASSERT(!(action == "cancelCandidate" && custom_sprite_hash(editor.workspace.serialize_drawing()) != draft_hash), "Cancelling the candidate must preserve the painted draft.")
		TEST_ASSERT(!(action == "confirmCandidate" && (editor.workspace.serialize_drawing() || editor.transfer_error)), "Confirming an empty candidate must replace the draft.")
	TEST_ASSERT(editor.show_candidate(empty_package, "restore"), "A restored style must also offer a confirmable preview.")
	editor.run_deferred_work()
	editor.draft_changed()
	editor.ui_act("confirmCandidate", list(), ui, null)
	TEST_ASSERT(editor.transfer_error && !editor.candidate, "A preview the draft changed under must be refused and dismissed.")
	editor.finish(FALSE)

/// Saving keeps the editor open and writes the current workspace, and a later Discard keeps that save.
/datum/unit_test/custom_sprite_save_without_close/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	QDEL_NULL(editor.workspace)
	editor.workspace = new(null, list("#ffffff"), null)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(0, 0)))), ui, null)
	TEST_ASSERT(editor.ui_act("saveDraft", list(), ui, null) && !editor.closing && preferences.custom_sprite_editors?["hair"] == editor, "Saving a draft must keep the editor open.")
	var/list/saved = preferences.custom_hair
	TEST_ASSERT(!(custom_sprite_decode_grid(saved?["dirs"]?["2"], 1) != "1" + repeat_string(1023, "0")), "Saving before the preview debounce must persist the current workspace.")
	var/saved_hash = custom_sprite_hash(saved)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(1, 0)))), ui, null)
	editor.ui_act("discard", list(), ui, null)
	TEST_ASSERT(custom_sprite_hash(preferences.custom_hair) == saved_hash, "Discarding later edits must preserve the most recently saved draft.")

/// Opening an explicitly tinted drawing bakes its tint into exact colours that render identically, without saving or aliasing the stored drawing.
/datum/unit_test/custom_sprite_explicit_tint_reopen/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/list/original = custom_sprite_test_drawing()
	original["palette"] = list("#ffffff", "#804020")
	original["tint"] = "#80c040"
	for(var/direction in original["dirs"])
		original["dirs"][direction] = custom_sprite_encode_grid(repeat_string(512, "12"))
	preferences.commit_custom_style(custom_style_package("hair", null, original, null), preferences.default_slot)
	var/original_hash = custom_sprite_hash(preferences.custom_hair)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/literal = editor.workspace.serialize_drawing()
	TEST_ASSERT(!(literal?["tint"] != "#ffffff" || !("#80c040" in literal["palette"]) || custom_sprite_hash(preferences.custom_hair) != original_hash), "Opening an explicitly tinted drawing must bake exact RGB without saving or aliasing its stored data.")
	var/mob/living/carbon/human/body = editor.preview_body
	for(var/opacity in list(255, 123))
		body.hair_alpha = opacity
		body.dna.custom_hair = original
		body.sync_custom_sprite_appearance(refresh_body = TRUE)
		var/list/before = list()
		for(var/direction in GLOB.cardinals)
			before["[direction]"] = getFlatIcon(body, defdir = direction, no_anim = TRUE)
		body.dna.custom_hair = literal
		body.sync_custom_sprite_appearance(refresh_body = TRUE)
		for(var/direction in GLOB.cardinals)
			TEST_ASSERT(custom_sprite_test_same_pixels(before["[direction]"], getFlatIcon(body, defdir = direction, no_anim = TRUE)), "Baking an explicit tint must preserve every rendered pixel at alpha [opacity].")
	editor.finish(FALSE)

/// Per-view emission changes only metadata, refuses malformed actions, survives a disk reload, and the master emissive preference gates it without overwriting the saved choice.
/datum/unit_test/custom_sprite_emissive_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/personality], list())
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/hair_emissive], TRUE)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))), "The emissive persistence fixture must paint a valid pixel.")
	var/list/before = editor.workspace.serialize_drawing()
	TEST_ASSERT(editor.ui_act("setEmissive", list("dir" = "1", "enabled" = TRUE), ui, null), "The emissive checkbox must update the current drawing.")
	var/list/after = editor.workspace.serialize_drawing()
	TEST_ASSERT(!(!after["emissive"]["1"] || before["emissive"]["1"] || after["dirs"] != before["dirs"] || after["palette"] != before["palette"] || editor.workspace.pixels_dirty), "Toggling emissive must replace only metadata and preserve the previous snapshot.")
	for(var/bad in list(null, "true", 2, list(TRUE)))
		TEST_ASSERT(!(editor.ui_act("setEmissive", list("dir" = "1", "enabled" = bad), ui, null) || !editor.workspace.emissive["1"]), "Malformed emissive actions must not change the drawing.")
	for(var/bad in list(null, "3", 2, list("2")))
		TEST_ASSERT(!editor.ui_act("setEmissive", list("dir" = bad, "enabled" = FALSE), ui, null), "Emissive actions must reject invalid directions.")
	editor.ui_act("saveDraft", list(), ui, null)
	editor.finish(FALSE)
	var/test_path = "tmp/custom_sprite_emissive_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	preferences.custom_sprite_savefile.path = test_path
	preferences.custom_sprite_savefile.save()
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	var/list/slot_data = reloaded.get_entry("character[preferences.default_slot]")
	TEST_ASSERT(!(slot_data?["hair"]?["emissive"]?["2"] || !slot_data?["hair"]?["emissive"]?["1"]), "Per-view emission must survive a disk reload.")
	preferences.custom_sprite_savefile.path = null
	reloaded.path = null
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], FALSE)
	var/datum/custom_sprite_editor/blocked = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/tgui/blocked_ui = allocate(/datum/tgui, mock_client.mob, blocked, "CustomHairEditor")
	TEST_ASSERT(!(blocked.ui_act("setEmissive", list("dir" = "2", "enabled" = TRUE), blocked_ui, null) || json_encode(blocked.preview_body.dna.custom_hair["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE))), "The character's master emissive preference must gate both the editor and rendered drawing.")
	blocked.finish(FALSE)
	TEST_ASSERT(preferences.custom_hair["emissive"]["1"], "The master preference must suppress appearance without overwriting the saved setting.")
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	TEST_ASSERT(json_encode(body.dna.custom_hair["emissive"]) == json_encode(custom_sprite_emissive_settings(FALSE)), "Ordinary preference application must respect the master emissive switch.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	TEST_ASSERT(!(body.dna.custom_hair["emissive"]["2"] || !body.dna.custom_hair["emissive"]["1"]), "Re-enabling emissives must restore the saved per-view settings.")
	var/hair_hash = custom_sprite_hash(preferences.custom_hair)
	for(var/hair_emissive in list(FALSE, TRUE))
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/hair_emissive], hair_emissive)
		preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
		TEST_ASSERT(!(json_encode(body.dna.custom_hair["emissive"]) != json_encode(preferences.custom_hair["emissive"]) || custom_sprite_hash(preferences.custom_hair) != hair_hash), "Normal hair emission changes must not alter the custom drawing's saved or applied flags.")

/// A version 1 drawing with one pixel painted at `x`, `y` in its Front view.
/proc/custom_sprite_reopen_test_drawing(x, y, tint = "#ff00ff")
	var/offset = y * 32 + x
	var/grid = repeat_string(offset, "0") + "1" + repeat_string(1023 - offset, "0")
	return list("version" = 1, "palette" = list("#ffffff"), "tint" = tint, "dirs" = list("2" = custom_sprite_encode_grid(grid)))

/// Erasing or clearing reopened paint saves its removal without touching other drawings.
/datum/unit_test/custom_sprite_reopen_clear_render/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.commit_custom_style(custom_style_package("hair", null, null, null), preferences.default_slot)
	preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_CHEST, custom_sprite_reopen_test_drawing(15, 12, "#00ffff"), null), preferences.default_slot)
	var/markings_hash = custom_sprite_hash(preferences.custom_limb_markings?[BODY_ZONE_CHEST])
	for(var/tool in list("eraser", "clear"))
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
		LAZYSET(preferences.custom_sprite_editors, "hair", editor)
		var/list/bounds = editor.workspace.draw_bounds["2"]
		var/x = bounds[1]
		var/y = bounds[2]
		editor.workspace.tint = "#ff00ff"
		TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(x, y)))), "Fixture must paint inside native bounds.")
		editor.finish(TRUE)
		TEST_ASSERT(preferences.custom_hair, "Fixture must save its drawing before reopening.")
		editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
		LAZYSET(preferences.custom_sprite_editors, "hair", editor)
		if(tool == "clear")
			TEST_ASSERT(editor.workspace.clear_direction("2"), "Clear must remove reopened pixels.")
		else
			TEST_ASSERT(editor.workspace.new_transaction(list("type" = "eraser", "layer" = 1, "dir" = "2", "points" = list(list(x, y)))), "The eraser must remove a reopened pixel.")
		TEST_ASSERT(!(editor.workspace.serialize_drawing() || editor.workspace.edited_directions["2"]), "Erased pixels must leave an empty drawing and edited marker.")
		editor.finish(TRUE)
		TEST_ASSERT(!preferences.custom_hair, "Saving cleared hair must persist its removal.")
		TEST_ASSERT(custom_sprite_hash(preferences.custom_limb_markings?[BODY_ZONE_CHEST]) == markings_hash, "Editing hair must preserve the independent markings drawing.")

/// A forced body refresh redraws changed hair paint even when no limb's cache key changed.
/datum/unit_test/custom_sprite_forced_hair_refresh/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = /datum/sprite_accessory/hair/bedhead::name
	human.update_body(is_creating = TRUE)
	human.update_hair()
	var/obj/item/bodypart/head/head = human.get_bodypart(BODY_ZONE_HEAD)
	var/old_key = head.get_cache_key()
	var/icon/before = getFlatIcon(human, defdir = SOUTH, no_anim = TRUE)
	human.dna.custom_hair = custom_sprite_reopen_test_drawing(6, 0)
	human.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/icon/after = getFlatIcon(human, defdir = SOUTH, no_anim = TRUE)
	TEST_ASSERT(!(head.get_cache_key() != old_key || !head.custom_hair), "The fixture must change the private hair snapshot without changing the head limb key.")
	TEST_ASSERT(!custom_sprite_test_same_pixels(before, after), "A forced body refresh must redraw changed hair even when every limb key is unchanged.")
	human.update_hair()
	var/icon/explicit_refresh = getFlatIcon(human, defdir = SOUTH, no_anim = TRUE)
	TEST_ASSERT(custom_sprite_test_same_pixels(after, explicit_refresh), "Forced refresh must produce the same hair pixels as an explicit hair update.")

/// Build a real wide organ through the same DNA path as character setup.
/datum/custom_sprite_editor/taur_test/create_preview_body()
	var/mob/living/carbon/human/dummy/body = ..()
	body.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part("Cow (Spotted)", list("#654321", "#321654", "#213456"))
	body.dna.species.regenerate_organs(body, visual_only = TRUE)
	body.update_body(is_creating = TRUE)
	return body

/// A taur body's hair guide draws the hair exactly where the body draws it, in every view.
/datum/unit_test/custom_sprite_taur_alignment/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], /datum/sprite_accessory/hair/bedhead::name)
	// Compare opaque hair to the full body without random gradients or beards blending into it.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hair_gradient], SPRITE_ACCESSORY_NONE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], "Shaved")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/taur_test(preferences, "hair")
	var/mob/living/carbon/human/body = editor.preview_body
	TEST_ASSERT(body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), "The alignment fixture must have a real taur organ.")
	var/mutable_appearance/hair = new(body.appearance)
	hair.icon = custom_sprite_blank_icon()
	hair.icon_state = ""
	hair.underlays = null
	hair.overlays = body.overlays_standing[HAIR_LAYER]
	for(var/direction in GLOB.cardinals)
		var/icon/expected = getFlatIcon(hair, defdir = direction, no_anim = TRUE)
		editor.visible_direction = "[direction]"
		editor.request_view()
		editor.run_deferred_work()
		var/icon/guide = editor.guide_icon("[direction]")
		var/checked = 0
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/pixel = expected.GetPixel(x, y)
				if(!pixel)
					continue
				checked++
				TEST_ASSERT(custom_sprite_test_close_pixel(guide.GetPixel(x, y), pixel), "Taur hair guide pixel [x],[y] in direction [direction]: expected [pixel], got [guide.GetPixel(x, y)].")
		TEST_ASSERT(checked, "The alignment fixture must contain hair in every direction.")
	editor.finish(FALSE)

/// Flattened and iconforge-drawn pictures keep fixed 32 and 64 pixel windows and every nested offset's native pixel origin.
/datum/unit_test/custom_sprite_fixed_origin/Run()
	// Native offsets compose across containers. The outer dots lie beyond a normal mob tile.
	var/icon/dots = custom_sprite_blank_icon(64)
	dots.DrawBox("#ff0000", 1, 1, 1, 1)
	dots.DrawBox("#00ff00", 31, 11, 31, 11)
	dots.DrawBox("#0000ff", 62, 29, 62, 29)
	var/mutable_appearance/child = mutable_appearance(dots)
	child.pixel_x = 2
	child.pixel_y = -1
	var/mutable_appearance/container = mutable_appearance(custom_sprite_blank_icon(64))
	container.pixel_w = -16
	container.pixel_z = 3
	container.overlays = list(child)
	var/mutable_appearance/body = mutable_appearance(custom_sprite_blank_icon())
	body.overlays = list(container)
	for(var/direction in GLOB.cardinals)
		// Insert-built icons can report 0x0 until reloaded. Check the PNG sent to the browser.
		var/wide_path = "tmp/custom_sprite_fixed_origin_wide_[direction].png"
		var/narrow_path = "tmp/custom_sprite_fixed_origin_narrow_[direction].png"
		fcopy(custom_sprite_flat_icon(body, direction, 64), wide_path)
		fcopy(custom_sprite_flat_icon(body, direction), narrow_path)
		var/icon/wide = icon(file(wide_path))
		var/icon/narrow = icon(file(narrow_path))
		fdel(wide_path)
		fdel(narrow_path)
		TEST_ASSERT(!(wide.Width() != 64 || wide.Height() != 32 || narrow.Width() != 32 || narrow.Height() != 32), "Fixed viewports must retain their exact dimensions despite nested wide icons.")
		for(var/y in 1 to 32)
			for(var/x in 1 to 64)
				var/expected = (x == 3 && y == 3) ? "#ff0000" : (x == 33 && y == 13) ? "#00ff00" : (x == 64 && y == 31) ? "#0000ff" : null
				TEST_ASSERT(wide.GetPixel(x, y) == expected, "Wide preview lost a native nested offset at [x],[y] in direction [direction].")
				TEST_ASSERT(!(x <= 32 && narrow.GetPixel(x, y) != ((x == 17 && y == 13) ? "#00ff00" : null)), "The hair guide must keep the central tile's native pixel origin.")
	// The editors' pictures are drawn by iconforge in the same windows, from one walk for all four views.
	var/datum/callback/to_icon = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(custom_sprite_picture_icon))
	var/list/wide_views = custom_sprite_draw_recipes(custom_sprite_view_recipes(body, 64), to_icon)
	var/list/narrow_views = custom_sprite_draw_recipes(custom_sprite_view_recipes(body), to_icon)
	for(var/view in GLOB.custom_style_directions)
		var/icon/wide = wide_views[view]
		var/icon/narrow = narrow_views[view]
		TEST_ASSERT(!(wide?.Width() != 64 || wide.Height() != 32 || narrow?.Width() != 32 || narrow.Height() != 32), "Drawn pictures must keep their windows' exact dimensions.")
		for(var/y in 1 to 32)
			for(var/x in 1 to 64)
				var/expected = (x == 3 && y == 3) ? "#ff0000" : (x == 33 && y == 13) ? "#00ff00" : (x == 64 && y == 31) ? "#0000ff" : null
				TEST_ASSERT(wide.GetPixel(x, y) == expected, "A drawn wide picture lost a native nested offset at [x],[y] in view [view].")
				TEST_ASSERT(!(x <= 32 && narrow.GetPixel(x, y) != ((x == 17 && y == 13) ? "#00ff00" : null)), "A drawn guide must keep the central tile's native pixel origin.")

/// Closing the window keeps the editor, its unsaved draft and its history, and saves nothing.
/datum/unit_test/custom_sprite_editor_close_keeps_draft/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/bounds = editor.workspace.draw_bounds?["2"]
	editor.workspace.update_palette(list("#ffffff"))
	TEST_ASSERT(!(!length(bounds) || !editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(bounds[1] + 2, bounds[2] + 2))))), "The fixture must accept a stroke inside the hair bounds.")
	var/saved_hash = custom_sprite_hash(preferences.custom_hair)
	editor.ui_close(mock_client.mob)
	TEST_ASSERT(!(QDELETED(editor) || editor.closing || LAZYACCESS(preferences.custom_sprite_editors, "hair") != editor), "Closing the window must keep the editor and its draft.")
	TEST_ASSERT(!(custom_sprite_hash(preferences.custom_hair) != saved_hash || !editor.workspace.edited_directions["2"] || !length(editor.workspace.undo_stack)), "Closing the window must not save, and must keep the unsaved paint and history.")
	editor.finish(FALSE)

/// Recolouring the base hair carries painted shades through undo, a new hairstyle keeps the paint exactly, and unknown hairstyles are refused.
/datum/unit_test/custom_sprite_editor_hair_swap/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Short Hair")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/hair_color], "#583820")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/shade
	for(var/color in custom_style_hair_shades(editor.workspace.hair_context))
		if(color in editor.workspace.palette)
			shade = color
			break
	var/list/bounds = editor.workspace.draw_bounds["2"]
	TEST_ASSERT(!(!shade || !editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[shade]ff", "points" = list(list(bounds[1] + 2, bounds[2] + 2))))), "The fixture must paint with one of the character's hair shades.")
	var/list/frame = editor.workspace.get_first_layer_pixel_data()
	var/painted_x = bounds[1] + 3
	var/painted_y = bounds[2] + 3
	var/list/recolor = editor.workspace.hair_context.Copy()
	recolor["color"] = "#c0d0e0"
	TEST_ASSERT(editor.apply_hair_context(recolor, "Change hair color"), "Changing the hair color failed: [editor.transfer_error]")
	var/list/color_map = custom_style_hair_color_map(custom_style_test_hair(), recolor, null)
	TEST_ASSERT(!(editor.workspace.hair_context["color"] != "#c0d0e0" || frame[painted_y][painted_x] != "[color_map[shade]]ff"), "A hair recolor must update the look and carry painted shades with it.")
	editor.workspace.undo()
	TEST_ASSERT(!(editor.workspace.hair_context["color"] != "#583820" || frame[painted_y][painted_x] != "[shade]ff"), "Undo must restore the old look and its painted shades.")
	editor.workspace.redo()
	var/list/restyle = editor.workspace.hair_context.Copy()
	restyle["style"] = /datum/sprite_accessory/hair/bedhead::name
	TEST_ASSERT(editor.apply_hair_context(restyle, "Change hairstyle"), "Changing the hairstyle failed: [editor.transfer_error]")
	TEST_ASSERT(!(editor.workspace.hair_context["style"] != /datum/sprite_accessory/hair/bedhead::name || frame[painted_y][painted_x] != "[color_map[shade]]ff"), "A new hairstyle must keep the drawing exactly as painted.")
	TEST_ASSERT(json_encode(editor.workspace.draw_bounds) == json_encode(custom_sprite_canvas_bounds()), "Changing hairstyles must leave the full canvas paintable.")
	var/list/locked = editor.workspace.hair_context.Copy()
	locked["style"] = "Definitely Not A Hairstyle"
	TEST_ASSERT(!(editor.apply_hair_context(locked, "Change hairstyle") || !editor.transfer_error), "Unavailable hairstyles must be refused.")
	editor.finish(FALSE)

/// Saving facial hair writes its own key and never touches the head hair drawing.
/datum/unit_test/custom_sprite_facial_hair_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], custom_style_test_facial_style())
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/facial_hair_color], "#583820")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "facial_hair")
	var/list/bounds = editor.workspace.draw_bounds["2"]
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(bounds[1] + 2, bounds[2] + 2)))), "The facial hair editor must accept paint inside its bounds.")
	TEST_ASSERT(!(editor.save_drawing() != TRUE || custom_sprite_hash(preferences.custom_facial_hair) != custom_sprite_hash(editor.workspace.serialize_drawing())), "Saving must store the facial hair drawing on its own key: [editor.save_error]")
	TEST_ASSERT(!preferences.custom_hair, "Saving facial hair must not touch the head hair drawing.")
	editor.finish(FALSE)

/// A trusted copy survives choosing Bald, but cannot bypass palette admission, history limits or editor lifetime.
/datum/unit_test/custom_sprite_base_hair_copy_paste/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Short Hair")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/hair_color], "#6030b0")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/list/copied = editor.build_base_copy(list("request" = 2, "dir" = "2", "rect" = list(0, 0, 31, 31)))
	TEST_ASSERT(copied && length(copied["palette"]) > 1, "The fixture must copy visible base hair: [editor.transfer_error]")
	var/list/placement = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 31, 31), "palette" = copied["palette"], "digits" = 1, "codes" = copied["codes"], "baseCopy" = 1, "baseCopySource" = copied["source"])
	var/palette_before = json_encode(editor.workspace.palette)
	TEST_ASSERT(!editor.prepare_base_copy_paste(placement), "An older copy token must not admit any colors.")
	placement["baseCopy"] = copied["request"]
	placement["baseCopySource"] = REF(preferences)
	TEST_ASSERT(!editor.prepare_base_copy_paste(placement) && json_encode(editor.workspace.palette) == palette_before, "A token from another source must not admit colors.")
	placement["baseCopySource"] = copied["source"]
	var/list/bald = editor.workspace.hair_context.Copy()
	bald["style"] = "Bald"
	TEST_ASSERT(editor.apply_hair_context(bald, "Change hairstyle"), "The copied hairstyle must be replaceable with Bald.")
	editor.rebuild_resources()
	TEST_ASSERT(editor.base_copy_token == copied["request"] && editor.prepare_base_copy_paste(placement), "Changing to Bald must retain the trusted copy and its paste colors.")
	TEST_ASSERT(editor.workspace.new_transaction(deep_copy_list(placement)), "Copied hair must paste as editable custom pixels after choosing Bald.")
	var/pasted = json_encode(editor.workspace.serialize_drawing())
	editor.workspace.undo()
	TEST_ASSERT(!editor.workspace.serialize_drawing() && editor.workspace.hair_context["style"] == "Bald", "Undo must remove pasted pixels while keeping the selected Bald base.")
	editor.workspace.redo()
	TEST_ASSERT(json_encode(editor.workspace.serialize_drawing()) == pasted, "Redo must restore the exact copied colors and pixels.")
	var/list/forged = deep_copy_list(placement)
	forged["palette"] = list("#00000000", "#fe01abff")
	forged["codes"] = repeat_string(1024, "1")
	TEST_ASSERT(editor.prepare_base_copy_paste(forged) && !editor.workspace.new_transaction(forged), "A valid token must not authorize arbitrary browser-supplied colors.")
	TEST_ASSERT(json_encode(editor.workspace.serialize_drawing()) == pasted, "Rejected placement must leave copied pixels unchanged.")
	var/list/full_palette = list()
	for(var/index in 1 to CUSTOM_SPRITE_MAX_COLORS)
		full_palette += rgb(index, 0, 0)
	var/grid = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 2) + repeat_string(1024 - CUSTOM_SPRITE_MAX_COLORS, "0")
	var/list/full_drawing = list("version" = 2, "palette" = full_palette, "dirs" = list("2" = custom_sprite_encode_grid(grid, CUSTOM_SPRITE_MAX_COLORS)))
	QDEL_NULL(editor.workspace)
	editor.workspace = new(full_drawing, list(), null)
	palette_before = json_encode(editor.workspace.palette)
	TEST_ASSERT(!editor.prepare_base_copy_paste(placement) && json_encode(editor.workspace.palette) == palette_before, "Copy admission must refuse a sixty-fourth retained color without changing the palette.")
	editor.release_resources()
	TEST_ASSERT(isnull(editor.base_copy_token) && !editor.base_copy_colors && !editor.base_copy_frame && !editor.prepare_base_copy_paste(placement), "Closing preview resources must expire the copy and release its cached pixels and colors.")
	editor.finish(FALSE)

/// Malformed browser requests and lost permissions cannot retain or execute pending copy work.
/datum/unit_test/custom_sprite_base_hair_copy_validation/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/valid = list("request" = 1, "dir" = "2", "rect" = list(0, 0, 0, 0), "mask" = list("1"))
	for(var/list/replacement as anything in list(list("request", 0), list("request", 1.5), list("request", 2000000000), list("dir", "3"), list("rect", list(0, 0, 31)), list("rect", list(0, 0, 0.5, 1)), list("rect", list(2, 0, 1, 0)), list("rect", list(0, 0, 47, 47)), list("rect", list(-49, 0, -49, 0)), list("mask", list("2")), list("mask", list("11")), list("mask", list("1", "1"))))
		var/list/invalid = deep_copy_list(valid)
		invalid[replacement[1]] = replacement[2]
		TEST_ASSERT(!editor.validated_base_copy(invalid), "Malformed copy metadata must be rejected: [json_encode(replacement)]")
	var/list/retained = editor.validated_base_copy(valid)
	valid["rect"][1] = -1
	valid["mask"][1] = "0"
	TEST_ASSERT(retained["rect"][1] == 0 && retained["mask"][1] == "1", "Validation must own its small selection lists rather than retain caller aliases.")
	editor.closing = TRUE
	editor.request_base_copy(retained, ui)
	TEST_ASSERT(!editor.base_copy_request && editor.transfer_error, "A request without edit permission must not enter the costly work queue.")
	editor.closing = FALSE
	editor.request_base_copy(retained, ui)
	retained["request"] = 2
	editor.request_base_copy(retained, ui)
	TEST_ASSERT(editor.base_copy_request?["request"] == 2 && !editor.base_copy_frame, "A burst must retain only its newest envelope and defer all pixel sampling.")
	editor.closing = TRUE
	TEST_ASSERT(editor.finish_base_copy() && !editor.base_copy_request && !editor.base_copy_ui && !editor.base_copy_frame, "Losing edit permission while waiting must cancel pending copy work without sampling.")
	editor.closing = FALSE
	editor.workspace.tint = "#aaaaaa"
	TEST_ASSERT(!editor.build_base_copy(retained) && editor.transfer_error, "Legacy color multipliers must fail closed instead of changing copied RGB.")
	editor.finish(FALSE)
	var/datum/custom_sprite_editor/facial = new /datum/custom_sprite_editor/optimization_test(preferences, "facial_hair")
	TEST_ASSERT(!facial.validated_base_copy(retained), "Base head hair copy must not be admitted by the facial hair editor.")
	facial.finish(FALSE)

/// Floating paint previews on the layer it names without ever writing the draft, and a preview naming another layer's id is refused.
/datum/unit_test/custom_sprite_hair_selection_preview/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.ui_act("addAppendage", list(), ui, null)
	var/draft = json_encode(editor.workspace.serialize_drawing())
	var/history = length(editor.workspace.undo_stack)
	var/revision = editor.draft_revision
	var/list/point = custom_sprite_test_paintable_point(editor)
	var/color = "[editor.workspace.palette[1]]ff"
	var/list/placement
	for(var/layer in 1 to 2)
		placement = list("layer" = layer, "layerId" = editor.workspace.layers[layer]["id"], "dir" = "2", "area" = list(point[1], point[2], point[1], point[2]), "palette" = list(color), "digits" = 1, "codes" = "0")
		editor.ui_act("previewSelection", list("transaction" = placement), ui, null)
		editor.refresh_preview(push = FALSE)
		TEST_ASSERT(editor.selection_layer == layer && editor.selection_frames?["2"][point[2] + 1][point[1] + 1] == color, "The preview must picture floating paint on the layer it names, layer [layer].")
		TEST_ASSERT(json_encode(editor.workspace.serialize_drawing()) == draft && length(editor.workspace.undo_stack) == history && editor.draft_revision == revision, "Floating previews must never write the draft, its history or its revision.")
	placement["layerId"] = "hair"
	editor.queue_selection_preview(placement)
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "A preview naming another layer's id must be refused.")
	editor.finish(FALSE)
