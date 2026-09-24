/// Preserve native previews for browser qualification without a live client or asset delivery.
/datum/custom_sprite_editor/qualification/publish_icon(icon/rendered)
	var/list/asset = generate_and_hash_rsc_file(rendered)
	var/name = "custom-sprite-[asset[2]].png"
	fcopy(asset[1], "data/custom_sprite_checks/[name]")
	return "/native/[name]"

/// Shared editor behavior is exercised on the torso, since every marking editor has a zone.
/proc/custom_sprite_test_zone(target)
	return target == "markings" ? BODY_ZONE_CHEST : null

/// The saved drawing a test editor for this target writes to.
/proc/custom_sprite_test_saved(datum/preferences/preferences, target)
	return target == "hair" ? preferences.custom_hair : preferences.custom_limb_markings?[BODY_ZONE_CHEST]

/// The first pixel this draft may paint in one view.
/proc/custom_sprite_test_paintable_point(datum/custom_sprite_editor/editor, direction = "2")
	var/list/bounds = editor.workspace.draw_bounds[direction]
	for(var/y in bounds[2] to bounds[4])
		for(var/x in bounds[1] to bounds[3])
			if(editor.workspace.is_point_allowed(x, y, direction))
				return list(x, y)

/datum/unit_test/custom_sprite_editor_lifecycle/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/target in list("hair", "markings"))
		var/zone = custom_sprite_test_zone(target)
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		TEST_ASSERT(!(length(editor.guide_urls) != 4 || length(editor.preview_urls) != 4), "Each editor must publish all four guides and previews.")
		var/list/bounds = editor.workspace.draw_bounds["2"]
		TEST_ASSERT(bounds, "The preview body needs editable bounds.")
		var/list/stroke = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))
		TEST_ASSERT(editor.workspace.new_transaction(stroke), "The editor rejected a sampled shade within its own bounds.")
		editor.refresh_preview()
		rustg_file_write(json_encode(editor.ui_data(mock_client.mob)), "data/custom_sprite_checks/[target].json")
		editor.finish(TRUE)
		var/list/saved = custom_sprite_test_saved(preferences, target)
		TEST_ASSERT(!(!saved || preferences.custom_sprite_editors?[custom_style_key(target, zone)]), "Closing must save the drawing and release its editor.")
		var/saved_hash = custom_sprite_hash(saved)
		editor = new /datum/custom_sprite_editor/qualification(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		editor.workspace.clear_direction("2")
		editor.finish(FALSE)
		TEST_ASSERT(saved_hash == custom_sprite_hash(custom_sprite_test_saved(preferences, target)), "Discard must preserve the last saved drawing.")
	var/old_gate = CONFIG_GET(flag/disallow_custom_sprite_editing)
	CONFIG_SET(flag/disallow_custom_sprite_editing, TRUE)
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	var/list/ui_data = middleware.get_ui_data(mock_client.mob)
	CONFIG_SET(flag/disallow_custom_sprite_editing, old_gate)
	TEST_ASSERT(!(ui_data["allow_custom_sprite_editing"] || !custom_sprite_paint_icon(preferences.custom_hair)), "Disabling editing must hide controls while saved drawings still render.")

/datum/unit_test/custom_sprite_editor_colors/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/obj/item/bodypart/head/head = editor.preview_body.get_bodypart(BODY_ZONE_HEAD)
	var/list/initial_data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!(initial_data["colorMode"] != "literal" || initial_data["displayTint"] || editor.workspace.tint != "#ffffff"), "New drawings must paint literal palette colors without an implicit hair filter.")
	editor.color_mode = "hair"
	head.hair_color = "#123456"
	head.fixed_hair_color = null
	head.override_hair_color = null
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["displayTint"] == "#123456", "Custom hair swatches must use the character's hair color when selected.")
	head.fixed_hair_color = "#654321"
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["displayTint"] == "#654321", "Fixed species hair color must take priority over the preference.")
	head.override_hair_color = "#abcdef"
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["displayTint"] == "#abcdef", "Hair overrides must also apply to the editor.")
	editor.color_mode = "tint"
	editor.custom_tint = "#ff0000"
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["displayTint"] == "#ff0000", "A selected Custom brush tint must take priority over hair color.")
	editor.preview_body.dna.features[FEATURE_MUTANT_COLOR] = "#ff0000"
	editor.preview_body.dna.features[FEATURE_MUTANT_COLOR_TWO] = "#00ff00"
	editor.preview_body.dna.features[FEATURE_MUTANT_COLOR_THREE] = "#0000ff"
	var/list/palette = editor.sample_marking_palette()
	for(var/color in list("#ff0000", "#00ff00", "#0000ff"))
		TEST_ASSERT((color in palette), "The marking palette must include all three selected mutant colors: [color].")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_facial_brush_color/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new(preferences, "facial_hair")
	var/obj/item/bodypart/head/head = editor.preview_body.get_bodypart(BODY_ZONE_HEAD)
	head.hair_color = "#ff0000"
	head.override_hair_color = "#0000ff"
	head.facial_hair_color = "#00ff00"
	editor.color_mode = "hair"
	TEST_ASSERT(editor.custom_palette_tint() == "#00ff00", "Facial-hair brushes must follow beard color, including when scalp hair has an override.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_editor_saved_colors/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hair = new /datum/custom_sprite_editor/qualification(preferences, "hair")
	var/datum/custom_sprite_editor/markings = new /datum/custom_sprite_editor/qualification(preferences, "markings", BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "hair", hair)
	LAZYSET(preferences.custom_sprite_editors, markings.editor_key, markings)
	TEST_ASSERT(hair.set_custom_palette(list("#fe12ab")), "Adding a saved swatch through the editor must succeed.")
	for(var/datum/custom_sprite_editor/editor as anything in list(hair, markings))
		var/list/data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(data["maxCustomColors"] != 16 || !("#fe12ab" in data["customPalette"]) || !editor.workspace.is_valid_color("#fe12abff")), "A saved swatch must immediately become paintable in both open editors.")
	var/list/full_palette = list()
	for(var/i in 1 to CUSTOM_SPRITE_MAX_COLORS)
		full_palette += rgb(i, 0, 0)
	var/grid = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 2) + repeat_string(1024 - CUSTOM_SPRITE_MAX_COLORS, "0")
	var/list/full_drawing = list("version" = 2, "palette" = full_palette, "dirs" = list("2" = custom_sprite_encode_grid(grid, CUSTOM_SPRITE_MAX_COLORS)))
	QDEL_NULL(hair.workspace)
	hair.workspace = new(full_drawing, list(), null)
	TEST_ASSERT(hair.set_custom_palette(list("#fe12ab", "#ab12fe")), "A full drawing must not prevent saving colors for other characters.")
	var/list/full_data = hair.ui_data(mock_client.mob)
	TEST_ASSERT(!(!("#ab12fe" in full_data["customPalette"]) || ("#ab12fe" in full_data["availableColors"])), "Unavailable colors must stay saved and be identified as unavailable in a full drawing.")
	hair.finish(FALSE)
	markings.finish(FALSE)
	var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
	TEST_ASSERT(json_encode(colors) == json_encode(list("#fe12ab", "#ab12fe")), "Discarding a character drawing must retain its account palette.")

/// Exercise the real UI actions without requiring a connected BYOND client.
/datum/custom_sprite_editor/optimization_test/can_edit(mob/user)
	return !closing

/datum/unit_test/custom_sprite_candidate_dismissal/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	for(var/target in list("hair", "markings"))
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, custom_sprite_test_zone(target))
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
		var/list/empty_package = editor.current_package()
		var/list/bounds = editor.workspace.draw_bounds["2"]
		if(!bounds || !editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))))
			editor.finish(FALSE)
			return Fail("The candidate dismissal fixture must start with a painted draft.", __FILE__, __LINE__)
		var/draft_hash = custom_sprite_hash(editor.workspace.serialize_drawing())
		for(var/action in list("cancelCandidate", "confirmCandidate"))
			if(!editor.show_candidate(empty_package, "import"))
				editor.finish(FALSE)
				return Fail("An empty style must offer a confirmable preview: [editor.transfer_error]", __FILE__, __LINE__)
			var/list/before = json_decode(json_encode(editor.ui_data(mock_client.mob)))
			TEST_ASSERT(!(before["candidate"]?["source"] != "import" || length(before["candidate"]?["previews"]) != 4), "The UI payload must expose the pending import and its four previews.")
			TEST_ASSERT(editor.ui_act(action, list(), ui, null), "Candidate dismissal must request an immediate UI update.")
			var/list/after = json_decode(json_encode(editor.ui_data(mock_client.mob)))
			TEST_ASSERT(!(editor.candidate || !("candidate" in after) || !isnull(after["candidate"])), "[action] must explicitly send a null candidate so TGUI clears its previously merged preview.")
			TEST_ASSERT(!(action == "cancelCandidate" && custom_sprite_hash(editor.workspace.serialize_drawing()) != draft_hash), "Cancelling the candidate must preserve the painted draft.")
			TEST_ASSERT(!(action == "confirmCandidate" && (editor.workspace.serialize_drawing() || editor.transfer_error)), "Confirming an empty candidate must replace the draft before dismissing the preview.")
		TEST_ASSERT(editor.show_candidate(empty_package, "restore"), "A restored style must also offer a confirmable preview.")
		editor.draft_changed()
		editor.ui_act("confirmCandidate", list(), ui, null)
		var/list/rejected = json_decode(json_encode(editor.ui_data(mock_client.mob)))
		TEST_ASSERT(!(!editor.transfer_error || !("candidate" in rejected) || !isnull(rejected["candidate"])), "Rejecting a stale candidate must also dismiss its previously merged preview.")
		editor.finish(FALSE)

/datum/sprite_editor_workspace/custom_sprite/serialization_test
	/// Total serialization requests, including metadata-only updates.
	var/serializations = 0
	/// Requests that actually rescan pixel data instead of using the cache.
	var/pixel_scans = 0

/datum/sprite_editor_workspace/custom_sprite/serialization_test/serialize_drawing()
	serializations++
	return ..()

/datum/sprite_editor_workspace/custom_sprite/serialization_test/used_colors()
	pixel_scans++
	return ..()

/datum/unit_test/custom_sprite_preview_resources/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/cache_size = length(SSassets.cache)
	var/datum/custom_sprite_editor/first = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/datum/custom_sprite_editor/second = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/list/second_previews = second.preview_urls.Copy()
	for(var/i in 1 to 8)
		var/icon/preview = icon('icons/blanks/32x32.dmi', "nothing")
		preview.DrawBox(rgb(i * 20, 10, 30), 1, 1, 32, 32)
		var/url = first.publish_icon(preview)
		TEST_ASSERT(findtextEx(url, "data:image/png;base64,iVBOR") == 1, "Runtime preview images must be self-contained PNG data URLs.")
	TEST_ASSERT(length(SSassets.cache) == cache_size, "Editor previews must not accumulate registrations in the global asset cache.")
	first.finish(FALSE)
	TEST_ASSERT(json_encode(second.preview_urls) == json_encode(second_previews), "Closing one editor must not invalidate another editor's previews.")
	second.finish(FALSE)

/datum/unit_test/custom_sprite_editor_debounce/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	QDEL_NULL(editor.workspace)
	var/datum/sprite_editor_workspace/custom_sprite/serialization_test/workspace = new(null, list("#ffffff"), null)
	editor.workspace = workspace
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	for(var/x in 0 to 2)
		editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(x, 0)))), ui, null)
	TEST_ASSERT(!workspace.serializations, "A burst of strokes must not serialize pixels before the preview debounce.")
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["edited"]["2"], "The edited-direction marker must update before its preview is serialized.")
	for(var/i in 1 to 50)
		if(!editor.preview_timer)
			break
		sleep(1)
	TEST_ASSERT(!(editor.preview_timer || workspace.serializations != 1 || !editor.draft), "The real timer must serialize a burst once and publish the final preview.")
	var/scans = workspace.pixel_scans
	var/list/untinted = workspace.serialize_drawing()
	workspace.tint = "#123456"
	var/list/tinted = workspace.serialize_drawing()
	TEST_ASSERT(!(workspace.pixel_scans != scans || tinted?["dirs"] != untinted?["dirs"] || untinted?["tint"] || tinted?["tint"] != "#123456"), "Tint-only serialization must reuse encoded pixels without mutating the previous snapshot.")
	editor.ui_act("setColorMode", list("mode" = "literal"), ui, null)
	editor.ui_act("spriteEditorCommand", list("command" = "redo"), ui, null)
	TEST_ASSERT(workspace.pixel_scans == scans, "Selecting the current brush mode and redo with no history must not rescan pixels.")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "1", "color" = "#ffffffff", "points" = list(list(31, 31)))), ui, null)
	editor.finish(TRUE)
	var/list/saved = preferences.custom_hair
	var/south = custom_sprite_decode_grid(saved?["dirs"]?["2"], 1)
	var/north = custom_sprite_decode_grid(saved?["dirs"]?["1"], 1)
	TEST_ASSERT(!(south != "111" + repeat_string(1021, "0") || north != repeat_string(1023, "0") + "1"), "Closing before the timer fires must persist the last stroke in every edited direction.")

/datum/unit_test/custom_sprite_save_without_close/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	QDEL_NULL(editor.workspace)
	editor.workspace = new(null, list("#ffffff"), null)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(0, 0)))), ui, null)
	var/pending_timer = editor.preview_timer
	TEST_ASSERT(!(!editor.ui_act("saveDraft", list(), ui, null) || editor.closing || preferences.custom_sprite_editors?["hair"] != editor || !pending_timer || editor.preview_timer != pending_timer), "Saving a draft must keep the editor and pending preview timer alive.")
	var/list/saved = preferences.custom_hair
	TEST_ASSERT(!(custom_sprite_decode_grid(saved?["dirs"]?["2"], 1) != "1" + repeat_string(1023, "0")), "Saving before the preview debounce must persist the current workspace.")
	var/saved_hash = custom_sprite_hash(saved)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(1, 0)))), ui, null)
	editor.ui_act("discard", list(), ui, null)
	TEST_ASSERT(custom_sprite_hash(preferences.custom_hair) == saved_hash, "Discarding later edits must preserve the most recently saved draft.")

/datum/unit_test/custom_sprite_guide_eyedropper/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/guides = editor.guide_icons
	if(length(guides) != 4)
		editor.finish(FALSE)
		return Fail("Guide sampling requires all four cropped native guide icons.", __FILE__, __LINE__)
	QDEL_NULL(editor.workspace)
	editor.workspace = new(null, list("#ffffff"), null)
	editor.sampled_palette = list("#ffffff")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.ui_act("selectColor", list("color" = "#ffffffff"), ui, null)
	var/icon/guide = icon('icons/blanks/32x32.dmi', "nothing")
	guide.DrawBox("#12abef", 1, 32, 2, 32)
	guide.DrawBox("#aabbcc80", 3, 32, 3, 32)
	guide.DrawBox("#ff00ff", 32, 1, 32, 1)
	guides["2"] = guide
	var/account_before = json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette))
	TEST_ASSERT(!(!editor.ui_act("sampleGuide", list("dir" = "2", "x" = 0, "y" = 0), ui, null) || !editor.workspace.is_valid_color("#12abefff")), "A visible guide pixel must become an admitted paint color using top-left coordinates.")
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["editorData"]["serverSelectedColor"] == "#12abef", "Guide sampling must synchronize the selected brush color.")
	editor.ui_act("selectColor", list("color" = "#ffffffff"), ui, null)
	editor.ui_act("sampleGuide", list("dir" = "2", "x" = 0, "y" = 0), ui, null)
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["editorData"]["serverSelectedColor"] == "#12abef", "Resampling a guide color after another selection must select it again.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#12abefff", "points" = list(list(4, 0)))), "A newly sampled guide color must paint successfully.")
	editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(1, 0))))
	editor.ui_act("sampleGuide", list("dir" = "2", "x" = 1, "y" = 0), ui, null)
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["editorData"]["serverSelectedColor"] == "#ffffff", "Current painted pixels must take precedence over the underlying guide.")
	editor.ui_act("sampleGuide", list("dir" = "2", "x" = 2, "y" = 0), ui, null)
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["editorData"]["serverSelectedColor"] == "#aabbcc", "A partially transparent guide pixel must become an opaque RGB brush color.")
	for(var/list/params as anything in list(list("dir" = "3", "x" = 0, "y" = 0), list("dir" = 2, "x" = 0, "y" = 0), list("dir" = "2", "x" = -1, "y" = 0), list("dir" = "2", "x" = 32, "y" = 0), list("dir" = "2", "x" = 0.5, "y" = 0), list("dir" = "2", "x" = "0", "y" = 0), list("dir" = "2", "x" = 0, "y" = 1)))
		TEST_ASSERT(!editor.ui_act("sampleGuide", params, ui, null), "Malformed coordinates and transparent guide pixels must not change selection.")
	TEST_ASSERT(!(editor.ui_act("selectColor", list("color" = "#654321"), ui, null) || editor.ui_act("selectColor", list("color" = "#ffffff80"), ui, null)), "Selecting a color must not admit arbitrary colors or partial alpha.")
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!(data["editorData"]["serverSelectedColor"] != "#aabbcc" || json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != account_before), "Rejected sampling must retain selection, and guide colors must not consume account swatches.")
	editor.set_custom_palette(list("#abcdef"))
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!(data["editorData"]["serverSelectedColor"] != "#aabbcc" || !editor.workspace.is_valid_color("#aabbccff")), "Custom palette updates must preserve the active, unpainted guide brush.")
	editor.set_custom_palette(list())
	var/list/palette = list()
	for(var/i in 1 to 63)
		palette += rgb(i, 0, 0)
	var/grid = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 2) + repeat_string(961, "0")
	QDEL_NULL(editor.workspace)
	editor.workspace = new(list("version" = 2, "palette" = palette, "dirs" = list("2" = custom_sprite_encode_grid(grid, 63))), list(), null)
	editor.ui_act("selectColor", list("color" = "#010000"), ui, null)
	TEST_ASSERT(!editor.ui_act("sampleGuide", list("dir" = "2", "x" = 31, "y" = 31), ui, null), "Guide sampling must not exceed the 63-color drawing capacity.")
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(data["editorData"]["serverSelectedColor"] == "#010000", "A full palette must retain its selected brush when guide sampling is rejected.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_save_palette_color/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/custom_sprite_editor/other = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, other.editor_key, other)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.sampled_palette |= "#12abef"
	editor.workspace.update_palette(editor.sampled_palette)
	editor.ui_act("selectColor", list("color" = "#12abefff"), ui, null)
	TEST_ASSERT(editor.ui_act("savePaletteColor", list("color" = "#12ABEFff"), ui, null), "An admitted opaque swatch must save directly to the custom palette.")
	var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
	var/list/stored_colors = preferences.savefile.get_entry("custom_sprite_palette")
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!(json_encode(colors) != json_encode(list("#12abef")) || json_encode(stored_colors) != json_encode(colors) || !other.workspace.is_valid_color("#12abefff") || data["editorData"]["serverSelectedColor"] != "#12abef"), "Direct saving must persist immediately, update both editors and preserve the selected brush.")
	for(var/color in list("#12abef", "#12abef80", "#987654", "not-a-color"))
		TEST_ASSERT(!editor.ui_act("savePaletteColor", list("color" = color), ui, null), "Duplicate, translucent, unadmitted and malformed swatches must not be saved.")
	var/list/full_palette = list()
	for(var/i in 1 to 16)
		full_palette += rgb(i, 0, 0)
	editor.set_custom_palette(full_palette)
	TEST_ASSERT(!(editor.ui_act("savePaletteColor", list("color" = "#12abef"), ui, null) || json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != json_encode(full_palette)), "Direct swatch saving must reject a seventeenth custom color without changing the palette.")
	editor.finish(FALSE)
	other.finish(FALSE)

/datum/unit_test/custom_sprite_naked_guide/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/underwear], /datum/sprite_accessory/clothing/underwear/male_briefs::name)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
	var/mob/living/carbon/human/body = editor.preview_body
	TEST_ASSERT(!(body.underwear_visibility & UNDERWEAR_HIDE_UNDIES || !length(body.get_underwear_overlays())), "Generating guides must leave the preview body's underwear visible.")
	var/list/clothed_icons = list()
	for(var/direction in GLOB.cardinals)
		// Previews show the whole look.
		var/icon/whole = getFlatIcon(new /mutable_appearance(body.appearance), defdir = direction, no_anim = TRUE)
		whole.Crop(1, 1, 32, 32)
		TEST_ASSERT(editor.preview_urls["[direction]"] == editor.publish_icon(whole), "The ordinary preview must retain the clothed character appearance.")
		// Marking guides leave hair out, so compare them against the same appearance.
		var/icon/clothed = getFlatIcon(editor.render_appearance(body), defdir = direction, no_anim = TRUE)
		clothed.Crop(1, 1, 32, 32)
		clothed_icons["[direction]"] = clothed
	// Guides show the body as it is until the owner hides the underwear.
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT(custom_sprite_test_same_pixels(clothed_icons["[direction]"], editor.guide_icons["[direction]"]), "Every guide direction must match the character's own underwear.")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("toggleUnderwear", list(), ui, null), "Character setup must let markings hide underwear.")
	TEST_ASSERT(editor.preview_body.underwear_visibility == UNDERWEAR_HIDE_ALL, "Hiding underwear must hide every underwear slot on the preview body.")
	var/clothing_changed_pixels = FALSE
	for(var/direction in GLOB.cardinals)
		clothing_changed_pixels ||= !custom_sprite_test_same_pixels(editor.guide_icons["[direction]"], clothed_icons["[direction]"])
	TEST_ASSERT(clothing_changed_pixels, "Hiding underwear must change the guides.")
	editor.ui_act("toggleUnderwear", list(), ui, null)
	for(var/direction in GLOB.cardinals)
		TEST_ASSERT(custom_sprite_test_same_pixels(clothed_icons["[direction]"], editor.guide_icons["[direction]"]), "Showing underwear again must restore the guides.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_color_modes/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/target in list("hair", "markings"))
		var/zone = custom_sprite_test_zone(target)
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
		var/list/data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(data["colorMode"] != "literal" || data["displayTint"] || data["customTint"] != "#ffffff" || editor.workspace.tint != "#ffffff"), "Both new editors must default to literal colors and an inactive white Custom tint.")
		TEST_ASSERT(editor.ui_act("setColorMode", list("mode" = "hair"), ui, null) == (target == "hair"), "Only hair editors may tint Custom brushes to hair color.")
		editor.custom_tint = "#804020"
		editor.ui_act("setColorMode", list("mode" = "tint"), ui, null)
		data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(data["colorMode"] != "tint" || data["displayTint"] != "#804020" || editor.workspace.tint != "#ffffff"), "An explicit Custom tint must not become a drawing filter.")
		TEST_ASSERT(!(!editor.ui_act("setColorMode", list("mode" = "literal"), ui, null) || editor.workspace.tint != "#ffffff"), "Disabling Custom effects must keep the drawing literal.")
		TEST_ASSERT(!editor.ui_act("setColorMode", list("mode" = "invalid"), ui, null), "Unknown color modes must be rejected.")
		editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor))))
		editor.ui_act("saveDraft", list(), ui, null)
		data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(data["saveRevision"] == 1, "Ctrl+S must acknowledge a completed save.")
		editor.ui_act("saveDraft", list(), ui, null)
		data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(data["saveRevision"] == 2, "Saving an unchanged drawing must acknowledge success again.")
		editor.finish(TRUE)
		editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(data["colorMode"] != "literal" || data["saveRevision"] != 0), "Reopening must retain literal colors and start a fresh save acknowledgement.")
		editor.finish(FALSE)
	preferences.custom_hair["tint"] = null
	var/datum/custom_sprite_editor/legacy = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	var/list/data = legacy.ui_data(mock_client.mob)
	TEST_ASSERT(!(data["colorMode"] != "literal" || legacy.workspace.tint), "Legacy appearance metadata must remain separate from the default Custom brush mode.")
	legacy.finish(FALSE)

/// Brush effects admit exact RGB colors without recoloring automatic swatches, pixels or history.
/datum/unit_test/custom_sprite_custom_brush_effects/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/custom_sprite_editor/other = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, other.editor_key, other)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	QDEL_NULL(editor.workspace)
	editor.sampled_palette = list("#ffffff", "#123456")
	editor.workspace = new(null, editor.sampled_palette, null)
	editor.workspace.tint = "#ffffff"
	editor.set_custom_palette(list("#ffffff", "#804020"))
	var/account_before = json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette))
	var/obj/item/bodypart/head/head = editor.preview_body.get_bodypart(BODY_ZONE_HEAD)
	head.hair_color = "#804020"
	head.fixed_hair_color = null
	head.override_hair_color = null
	TEST_ASSERT(!(!editor.ui_act("selectCustomColor", list("color" = "#FFFFFF"), ui, null) || editor.selected_color != "#ffffff"), "Literal Custom selection must accept a canonical account swatch.")
	editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(0, 0))))
	var/drawing_before = json_encode(editor.workspace.serialize_drawing())
	var/history_before = json_encode(editor.workspace.undo_stack)
	var/list/data_before = editor.ui_data(mock_client.mob)
	editor.ui_act("setColorMode", list("mode" = "hair"), ui, null)
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!(editor.selected_color != "#804020" || !("#401004" in editor.workspace.palette) || editor.selected_custom_color != "#ffffff"), "Hair mode must admit transformed account colors and update the selected Custom brush.")
	TEST_ASSERT(!(json_encode(editor.workspace.serialize_drawing()) != drawing_before || json_encode(editor.workspace.undo_stack) != history_before || json_encode(data["previews"]) != json_encode(data_before["previews"]) || editor.preview_timer), "Changing Custom effects must leave existing pixels, history and previews unchanged.")
	for(var/color in editor.sampled_palette)
		TEST_ASSERT((color in data["editorData"]["serverPalette"]), "Automatic palette colors must stay exact and visible even when also saved as Custom colors.")
	editor.ui_act("selectColor", list("color" = "#123456ff"), ui, null)
	var/icon/guide = icon('icons/blanks/32x32.dmi', "nothing")
	guide.DrawBox("#abcdef", 3, 32, 3, 32)
	editor.guide_icons["2"] = guide
	TEST_ASSERT(editor.sample_guide("2", 2, 0), "The guide fixture must select an unused color outside the automatic and Custom palettes.")
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(("#abcdef" in data["editorData"]["serverPalette"]), "An explicit guide pick must expose its swatch for right-click Save.")
	editor.custom_tint = "#000000"
	editor.ui_act("setColorMode", list("mode" = "tint"), ui, null)
	TEST_ASSERT(!(editor.selected_color != "#abcdef" || editor.selected_custom_color || !editor.workspace.is_valid_color("#abcdefff")), "An active, unpainted guide brush must remain exact and admitted across Custom mode changes.")
	editor.ui_act("selectColor", list("color" = "#123456ff"), ui, null)
	editor.ui_act("setColorMode", list("mode" = "literal"), ui, null)
	TEST_ASSERT(!(editor.selected_color != "#123456" || editor.selected_custom_color || ("#abcdef" in editor.workspace.palette)), "Automatic selection must stay exact while an abandoned guide color is pruned.")
	data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!("#abcdef" in data["editorData"]["serverPalette"]), "A pruned guide brush must not leave an unavailable swatch behind.")
	editor.ui_act("setColorMode", list("mode" = "tint"), ui, null)
	TEST_ASSERT(!(!editor.ui_act("selectCustomColor", list("color" = "#804020"), ui, null) || editor.selected_color != "#000000"), "A tinted Custom swatch must select its admitted, opaque transformed RGB.")
	editor.custom_tint = "#ffffff"
	editor.refresh_custom_palette()
	TEST_ASSERT(!(editor.selected_color != "#804020" || editor.selected_custom_color != "#804020"), "Custom swatches that render identically must retain their distinct raw selection.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.selected_color]ff", "points" = list(list(1, 0)))), "The transformed Custom brush must paint successfully.")
	var/list/frame = editor.workspace.layers[1]["data"]["2"]
	TEST_ASSERT(!(frame[1][1] != "#ffffffff" || frame[1][2] != "#804020ff" || editor.workspace.tint != "#ffffff"), "New Custom strokes must store their exact color without changing earlier pixels.")
	for(var/color in list("#123456", "#80402080", "invalid"))
		TEST_ASSERT(!editor.ui_act("selectCustomColor", list("color" = color), ui, null), "Custom selection must reject unsaved, translucent and malformed colors.")
	TEST_ASSERT(!(json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)) != account_before || json_encode(preferences.savefile.get_entry("custom_sprite_palette")) != account_before || other.color_mode != "literal" || !("#804020" in other.workspace.palette)), "Brush effects must preserve shared raw account colors and the other editor's independent mode.")
	editor.ui_act("saveDraft", list(), ui, null)
	var/saved_hash = custom_sprite_hash(preferences.custom_hair)
	editor.finish(FALSE)
	editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	TEST_ASSERT(!(custom_sprite_hash(editor.workspace.serialize_drawing()) != saved_hash || editor.color_mode != "literal" || editor.custom_tint != "#ffffff"), "Reopening literal strokes must preserve their RGB and reset transient Custom effects.")
	editor.finish(FALSE)
	other.finish(FALSE)

/datum/unit_test/custom_sprite_palette_display/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	QDEL_NULL(editor.workspace)
	editor.sampled_palette = list("#123456")
	editor.workspace = new(null, editor.sampled_palette, null)
	editor.workspace.tint = "#ffffff"
	editor.selected_color = "#123456"
	editor.set_custom_palette(list("#808080"))
	var/obj/item/bodypart/head/head = editor.preview_body.get_bodypart(BODY_ZONE_HEAD)
	head.hair_color = "#804020"
	head.fixed_hair_color = null
	head.override_hair_color = null
	editor.ui_act("selectCustomColor", list("color" = "#808080"), ui, null)
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#808080ff", "points" = list(list(0, 0)))), "The palette fixture must paint its Custom color.")
	for(var/painted in list(FALSE, TRUE))
		if(painted)
			editor.workspace.redo(1)
		else
			editor.workspace.undo(1)
		var/pixels_before = custom_sprite_hash(editor.workspace.serialize_drawing())
		var/history_before = json_encode(list(editor.workspace.undo_stack, editor.workspace.redo_stack))
		for(var/mode in list("hair", "tint", "literal"))
			editor.custom_tint = "#ff0000"
			editor.ui_act("setColorMode", list("mode" = mode), ui, null)
			var/list/data = editor.ui_data(mock_client.mob)
			TEST_ASSERT(json_encode(data["editorData"]["serverPalette"]) == json_encode(editor.sampled_palette), "Tint changes must not expose retained Custom colors as new automatic swatches.")
			TEST_ASSERT(!(!("#808080" in editor.workspace.palette) || custom_sprite_hash(editor.workspace.serialize_drawing()) != pixels_before || json_encode(list(editor.workspace.undo_stack, editor.workspace.redo_stack)) != history_before), "Keeping the automatic palette stable must preserve painted and undoable Custom colors.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_custom_brush_capacity/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/palette = list()
	for(var/i in 1 to 63)
		palette += rgb(i, 0, 0)
	var/grid = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 2) + repeat_string(961, "0")
	QDEL_NULL(editor.workspace)
	editor.workspace = new(list("version" = 2, "palette" = palette, "tint" = "#ffffff", "dirs" = list("2" = custom_sprite_encode_grid(grid, 63))), list(), null)
	editor.set_custom_palette(list("#ffffff"))
	editor.ui_act("selectColor", list("color" = "#010000"), ui, null)
	editor.custom_tint = "#abcdef"
	var/before = json_encode(editor.workspace.serialize_drawing())
	editor.ui_act("setColorMode", list("mode" = "tint"), ui, null)
	TEST_ASSERT(!(editor.ui_act("selectCustomColor", list("color" = "#ffffff"), ui, null) || editor.selected_color != "#010000" || ("#abcdef" in editor.workspace.palette) || json_encode(editor.workspace.serialize_drawing()) != before), "A full drawing must reject an unavailable transformed brush without changing selection or pixels.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_explicit_tint_reopen/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	for(var/target in list("hair", "markings"))
		var/zone = custom_sprite_test_zone(target)
		var/list/original = custom_sprite_test_drawing()
		original["palette"] = list("#ffffff", "#804020")
		original["tint"] = "#80c040"
		for(var/direction in original["dirs"])
			original["dirs"][direction] = custom_sprite_encode_grid(repeat_string(512, "12"))
		preferences.commit_custom_style(custom_style_package(target, zone, original, null), preferences.default_slot)
		var/original_hash = custom_sprite_hash(custom_sprite_test_saved(preferences, target))
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		var/list/literal = editor.workspace.serialize_drawing()
		TEST_ASSERT(!(literal?["tint"] != "#ffffff" || !("#80c040" in literal["palette"]) || custom_sprite_hash(custom_sprite_test_saved(preferences, target)) != original_hash), "Opening an explicitly tinted drawing must bake exact RGB without saving or aliasing its stored data.")
		var/mob/living/carbon/human/body = editor.preview_body
		for(var/opacity in list(255, 123))
			body.hair_alpha = opacity
			body.dna.species.markings_alpha = opacity
			if(target == "hair")
				body.dna.custom_hair = original
			else
				body.dna.custom_limb_markings = list(BODY_ZONE_CHEST = original)
			body.sync_custom_sprite_appearance(refresh_body = TRUE)
			var/list/before = list()
			for(var/direction in GLOB.cardinals)
				before["[direction]"] = getFlatIcon(body, defdir = direction, no_anim = TRUE)
			if(target == "hair")
				body.dna.custom_hair = literal
			else
				body.dna.custom_limb_markings = list(BODY_ZONE_CHEST = literal)
			body.sync_custom_sprite_appearance(refresh_body = TRUE)
			for(var/direction in GLOB.cardinals)
				TEST_ASSERT(custom_sprite_test_same_pixels(before["[direction]"], getFlatIcon(body, defdir = direction, no_anim = TRUE)), "Baking an explicit [target] tint must preserve every rendered pixel at alpha [opacity].")
		editor.finish(FALSE)

/datum/unit_test/custom_sprite_emissive_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/personality], list())
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/hair_emissive], TRUE)
	for(var/target in list("hair", "markings"))
		var/zone = custom_sprite_test_zone(target)
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
		var/list/data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(json_encode(data["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE)) || !data["emissiveAllowed"]), "Every custom drawing view must default off even when normal hair emission is enabled.")
		TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(custom_sprite_test_paintable_point(editor)))), "The emissive persistence fixture must paint a valid pixel.")
		var/list/before = editor.workspace.serialize_drawing()
		var/emissive_direction = target == "hair" ? "1" : "2"
		var/enabled = TRUE
		TEST_ASSERT(editor.ui_act("setEmissive", list("dir" = emissive_direction, "enabled" = enabled), ui, null), "The emissive checkbox must update the current drawing.")
		var/list/after = editor.workspace.serialize_drawing()
		TEST_ASSERT(!(after["emissive"][emissive_direction] != enabled || before["emissive"][emissive_direction] == enabled || after["dirs"] != before["dirs"] || after["palette"] != before["palette"] || editor.workspace.pixels_dirty), "Toggling emissive must replace only metadata and preserve the previous snapshot.")
		for(var/direction in list("2", "1", "4", "8"))
			TEST_ASSERT(!(direction != emissive_direction && after["emissive"][direction]), "Toggling one view must leave the other three views non-emissive.")
		var/preview_timer = editor.preview_timer
		editor.ui_act("setEmissive", list("dir" = emissive_direction, "enabled" = enabled), ui, null)
		TEST_ASSERT(editor.preview_timer == preview_timer, "An unchanged emissive setting must not reschedule its preview.")
		for(var/bad in list(null, "true", 2, list(TRUE)))
			TEST_ASSERT(!(editor.ui_act("setEmissive", list("dir" = emissive_direction, "enabled" = bad), ui, null) || editor.workspace.emissive[emissive_direction] != enabled), "Malformed emissive actions must not change the drawing.")
		for(var/bad in list(null, "3", 2, list("2")))
			TEST_ASSERT(!editor.ui_act("setEmissive", list("dir" = bad, "enabled" = !enabled), ui, null), "Emissive actions must reject invalid directions.")
		editor.ui_act("saveDraft", list(), ui, null)
		editor.finish(FALSE)
		editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		TEST_ASSERT(!(editor.workspace.emissive[emissive_direction] != enabled || editor.workspace.emissive[target == "hair" ? "2" : "1"]), "Reopening must restore only the custom views explicitly enabled in the drawing.")
		editor.finish(FALSE)
	TEST_ASSERT(!(preferences.custom_hair["emissive"]["2"] || !preferences.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]["2"] || !preferences.read_preference(/datum/preference/toggle/hair_emissive)), "Hair and markings must retain independent choices without changing the hair preference.")
	var/test_path = "data/custom_sprite_checks/emissive_[REF(src)].json"
	preferences.custom_sprite_savefile.path = test_path
	preferences.custom_sprite_savefile.save()
	var/datum/json_savefile/custom_sprites/reloaded = allocate(/datum/json_savefile/custom_sprites, test_path)
	var/list/slot_data = reloaded.get_entry("character[preferences.default_slot]")
	TEST_ASSERT(!(slot_data?["hair"]?["emissive"]?["2"] || !slot_data?["limb_markings"]?[BODY_ZONE_CHEST]?["emissive"]?["2"] || !slot_data?["hair"]?["emissive"]?["1"] || slot_data?["limb_markings"]?[BODY_ZONE_CHEST]?["emissive"]?["1"]), "Both layers' independent emissive settings must survive a disk reload.")
	preferences.custom_sprite_savefile.path = null
	custom_sprite_test_remove_sidecar(test_path)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], FALSE)
	var/datum/custom_sprite_editor/blocked = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_CHEST)
	var/datum/tgui/blocked_ui = allocate(/datum/tgui, mock_client.mob, blocked, "CustomMarkingsEditor")
	var/list/blocked_data = blocked.ui_data(mock_client.mob)
	TEST_ASSERT(!(blocked_data["emissiveAllowed"] || blocked.ui_act("setEmissive", list("dir" = "2", "enabled" = TRUE), blocked_ui, null) || json_encode(blocked.preview_body.dna.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE))), "The character's master emissive preference must gate both the editor and rendered drawing.")
	blocked.finish(FALSE)
	TEST_ASSERT(preferences.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]["2"], "The master preference must suppress appearance without overwriting the saved layer setting.")
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	TEST_ASSERT(!(json_encode(body.dna.custom_hair["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE)) || json_encode(body.dna.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE))), "Ordinary preference application must respect the master emissive switch.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	TEST_ASSERT(!(body.dna.custom_hair["emissive"]["2"] || !body.dna.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]["2"] || !body.dna.custom_hair["emissive"]["1"] || body.dna.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]["1"]), "Re-enabling emissives must restore the saved independent layer settings.")
	var/hair_hash = custom_sprite_hash(preferences.custom_hair)
	var/markings_hash = custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_CHEST])
	for(var/hair_emissive in list(FALSE, TRUE))
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/hair_emissive], hair_emissive)
		preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
		TEST_ASSERT(!(json_encode(body.dna.custom_hair["emissive"]) != json_encode(preferences.custom_hair["emissive"]) || json_encode(body.dna.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]) != json_encode(preferences.custom_limb_markings[BODY_ZONE_CHEST]["emissive"]) || custom_sprite_hash(preferences.custom_hair) != hair_hash || custom_sprite_hash(preferences.custom_limb_markings[BODY_ZONE_CHEST]) != markings_hash), "Normal hair emission changes must not alter either custom drawing's saved or applied flags.")
	var/list/legacy = deep_copy_list(preferences.custom_hair)
	legacy -= "emissive"
	preferences.commit_custom_style(custom_style_package("hair", null, legacy, null), preferences.default_slot)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	var/datum/custom_sprite_editor/legacy_editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	TEST_ASSERT(!(json_encode(body.dna.custom_hair["emissive"]) != json_encode(custom_sprite_emissive_settings(FALSE)) || json_encode(legacy_editor.workspace.emissive) != json_encode(custom_sprite_emissive_settings(FALSE))), "Missing custom emission metadata must default off in both preference application and the editor.")
	legacy_editor.finish(FALSE)

/proc/custom_sprite_reopen_test_drawing(x, y, tint = "#ff00ff")
	var/offset = y * 32 + x
	var/grid = repeat_string(offset, "0") + "1" + repeat_string(1023 - offset, "0")
	return list("version" = 1, "palette" = list("#ffffff"), "tint" = tint, "dirs" = list("2" = custom_sprite_encode_grid(grid)))

/datum/unit_test/custom_sprite_reopen_clear_render/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	for(var/target in list("hair", "markings"))
		var/zone = custom_sprite_test_zone(target)
		var/other_target = target == "hair" ? "markings" : "hair"
		preferences.commit_custom_style(custom_style_package(target, zone, null, null), preferences.default_slot)
		preferences.commit_custom_style(custom_style_package(other_target, custom_sprite_test_zone(other_target), custom_sprite_reopen_test_drawing(15, 12, "#00ffff"), null), preferences.default_slot)
		var/other_hash = custom_sprite_hash(custom_sprite_test_saved(preferences, other_target))
		for(var/tool in list("eraser", "clear"))
			var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
			LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
			var/list/clean_guides = editor.guide_urls.Copy()
			var/list/clean_previews = editor.preview_urls.Copy()
			var/list/bounds = editor.workspace.draw_bounds["2"]
			var/x = bounds[1]
			var/y = bounds[2]
			if(target == "markings")
				var/obj/item/bodypart/chest = editor.preview_body.get_bodypart(BODY_ZONE_CHEST)
				var/icon/chest_mask = custom_sprite_silhouette(chest)
				var/found = FALSE
				for(var/scan_y in bounds[2] to bounds[4])
					for(var/scan_x in bounds[1] to bounds[3])
						if(!chest_mask.GetPixel(scan_x + 1, 32 - scan_y, "", SOUTH))
							continue
						x = scan_x
						y = scan_y
						found = TRUE
						break
					if(found)
						break
			var/color = "[editor.workspace.palette[1]]ff"
			editor.workspace.tint = "#ff00ff"
			TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = color, "points" = list(list(x, y)))), "Fixture must paint inside native bounds.")
			editor.finish(TRUE)
			TEST_ASSERT(custom_sprite_test_saved(preferences, target), "Fixture must save its drawing before reopening.")
			editor = new /datum/custom_sprite_editor/optimization_test(preferences, target, zone)
			LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
			TEST_ASSERT(json_encode(editor.guide_urls) == json_encode(clean_guides), "Reopening [target] must not bake editable paint into its guide.")
			if(tool == "clear")
				TEST_ASSERT(editor.workspace.clear_direction("2"), "Clear must remove reopened [target] pixels.")
			else
				TEST_ASSERT(editor.workspace.new_transaction(list("type" = "eraser", "layer" = 1, "dir" = "2", "points" = list(list(x, y)))), "The eraser must remove a reopened [target] pixel.")
			TEST_ASSERT(!(editor.workspace.serialize_drawing() || editor.workspace.edited_directions["2"]), "Erased [target] pixels must leave an empty drawing and edited marker.")
			editor.refresh_preview()
			TEST_ASSERT(json_encode(editor.preview_urls) == json_encode(clean_previews), "After [tool], native [target] preview must return to the clean baseline.")
			editor.finish(TRUE)
			TEST_ASSERT(!custom_sprite_test_saved(preferences, target), "Saving cleared [target] must persist its removal.")
			TEST_ASSERT(custom_sprite_hash(custom_sprite_test_saved(preferences, other_target)) == other_hash, "Editing [target] must preserve the other target's independent drawing.")

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

/datum/unit_test/custom_marking_zone_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/body_zone in GLOB.custom_marking_zone_labels)
		if(body_zone == CUSTOM_MARKING_ZONE_TAUR)
			continue // The real taur-organ fixture covers this separate geometry.
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/qualification(preferences, "markings", body_zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		var/list/data = editor.ui_data(mock_client.mob)
		TEST_ASSERT(!(data["bodyZone"] != body_zone || data["bodyZoneLabel"] != GLOB.custom_marking_zone_labels[body_zone] || length(data["drawMask"]) != 4), "Zone buttons must scope the existing editor and expose four silhouette masks.")
		var/list/point
		for(var/y in 0 to 31)
			for(var/x in 0 to 31)
				if(editor.workspace.is_point_allowed(x, y, "2"))
					point = list(x, y)
		if(!point)
			editor.finish(FALSE)
			return Fail("Every standard body zone needs paintable pixels.", __FILE__, __LINE__)
		editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(point)))
		editor.refresh_preview()
		if(body_zone == BODY_ZONE_L_ARM)
			rustg_file_write(json_encode(editor.ui_data(mock_client.mob)), "data/custom_sprite_checks/limb-markings.json")
		editor.finish(TRUE)
		TEST_ASSERT(!(!preferences.custom_limb_markings?[body_zone] || preferences.custom_sprite_editors?["markings:[body_zone]"]), "Saving a zone must save its paint and release only its own editor.")
		editor = new /datum/custom_sprite_editor/qualification(preferences, "markings", body_zone)
		LAZYSET(preferences.custom_sprite_editors, editor.editor_key, editor)
		TEST_ASSERT(!(!editor.workspace.edited_directions["2"] || editor.workspace.edited_directions["1"]), "Reopening must hydrate only the selected zone's saved directions.")
		editor.workspace.clear_direction("2")
		editor.refresh_preview()
		TEST_ASSERT(!editor.preview_body.dna.custom_limb_markings?[body_zone], "Cleared saved paint must disappear from the preview.")
		editor.finish(TRUE)
		TEST_ASSERT(!preferences.custom_limb_markings?[body_zone], "Clearing a reopened zone must remove its saved paint.")

/// Build a real wide organ through the same DNA path as character setup.
/datum/custom_sprite_editor/taur_test/create_preview_body()
	var/mob/living/carbon/human/dummy/body = ..()
	body.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part("Cow (Spotted)", list("#654321", "#321654", "#213456"))
	body.dna.species.regenerate_organs(body, visual_only = TRUE)
	body.update_body(is_creating = TRUE)
	return body

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
		var/icon/guide = editor.guide_icons["[direction]"]
		var/checked = 0
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/pixel = expected.GetPixel(x, y)
				if(!pixel)
					continue
				checked++
				TEST_ASSERT(guide.GetPixel(x, y) == pixel, "Taur hair guide pixel [x],[y] in direction [direction]: expected [pixel], got [guide.GetPixel(x, y)].")
		TEST_ASSERT(checked, "The alignment fixture must contain hair in every direction.")
	editor.finish(FALSE)

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
		var/wide_path = "data/custom_sprite_checks/fixed-origin-wide-[direction].png"
		var/narrow_path = "data/custom_sprite_checks/fixed-origin-narrow-[direction].png"
		fcopy(custom_sprite_flat_icon(body, direction, 64), wide_path)
		fcopy(custom_sprite_flat_icon(body, direction), narrow_path)
		var/icon/wide = icon(file(wide_path))
		var/icon/narrow = icon(file(narrow_path))
		TEST_ASSERT(!(wide.Width() != 64 || wide.Height() != 32 || narrow.Width() != 32 || narrow.Height() != 32), "Fixed viewports must retain their exact dimensions despite nested wide icons.")
		for(var/y in 1 to 32)
			for(var/x in 1 to 64)
				var/expected = (x == 3 && y == 3) ? "#ff0000" : (x == 33 && y == 13) ? "#00ff00" : (x == 64 && y == 31) ? "#0000ff" : null
				TEST_ASSERT(wide.GetPixel(x, y) == expected, "Wide preview lost a native nested offset at [x],[y] in direction [direction].")
				TEST_ASSERT(!(x <= 32 && narrow.GetPixel(x, y) != ((x == 17 && y == 13) ? "#00ff00" : null)), "The hair guide must keep the central tile's native pixel origin.")

/datum/unit_test/custom_sprite_taur_canvas/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/taur_test(preferences, "markings", CUSTOM_MARKING_ZONE_TAUR)
	TEST_ASSERT(!(editor.workspace.width != 64 || editor.workspace.height != 32), "Taur drawings need the native 64 by 32 taur canvas.")
	for(var/direction in GLOB.cardinals)
		var/icon/guide = editor.guide_icons["[direction]"]
		TEST_ASSERT(!(guide.Width() != 64 || guide.Height() != 32), "Wide guides must retain the same dimensions as their paint canvas.")
	editor.finish(FALSE)

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
	TEST_ASSERT(!(editor.resources_ready || editor.preview_body || length(editor.guide_urls)), "Closing the window must release preview resources.")
	editor.ui_interact(allocate(/mob/living/carbon/human/consistent))
	TEST_ASSERT(!(!editor.resources_ready || length(editor.guide_urls) != 4 || !editor.workspace.edited_directions["2"]), "Reopening must rebuild previews around the kept draft.")
	editor.finish(FALSE)


/datum/unit_test/custom_sprite_hair_canvas/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/target in GLOB.custom_style_hair_targets)
		var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, target)
		TEST_ASSERT(!(editor.can_hide_parts() || editor.ui_data(mock_client.mob)["canHideParts"]), "Hair editors must not offer Hide Parts.")
		for(var/direction in GLOB.cardinals)
			for(var/list/point as anything in list(list(0, 0), list(31, 0), list(0, 31), list(31, 31)))
				TEST_ASSERT(editor.workspace.is_point_allowed(point[1], point[2], "[direction]"), "Every hair canvas corner must be editable in direction [direction].")
		var/list/drawing = custom_sprite_reopen_test_drawing(31, 31, "#112233")
		TEST_ASSERT(!editor.candidate_problem(custom_style_package(target, null, drawing, editor.workspace.hair_context)), "Hair imports must allow the same full canvas as painting.")
		editor.finish(FALSE)

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
	TEST_ASSERT(editor.can_change_hair(), "Character preferences must be able to change the base hair look.")
	var/list/recolor = editor.workspace.hair_context.Copy()
	recolor["color"] = "#c0d0e0"
	TEST_ASSERT(editor.apply_hair_context(recolor, "Change hair color"), "Changing the hair color failed: [editor.transfer_error]")
	var/list/color_map = custom_style_hair_color_map(custom_style_test_hair(), recolor, null)
	TEST_ASSERT(!(editor.workspace.hair_context["color"] != "#c0d0e0" || frame[painted_y][painted_x] != "[color_map[shade]]ff"), "A hair recolor must update the look and carry painted shades with it.")
	TEST_ASSERT((color_map[shade] in editor.workspace.palette), "The palette must follow the new hair color.")
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

/datum/unit_test/custom_sprite_markings_clip/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_L_ARM)
	var/list/frame = editor.workspace.get_first_layer_pixel_data()
	var/allowed_x
	var/allowed_y
	var/stranded_x
	var/stranded_y
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(editor.workspace.is_point_allowed(x, y, "2"))
				if(isnull(allowed_x))
					allowed_x = x
					allowed_y = y
			else if(isnull(stranded_x))
				stranded_x = x
				stranded_y = y
	TEST_ASSERT(!(isnull(allowed_x) || isnull(stranded_x)), "The fixture needs both paintable and shaded pixels.")
	editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(allowed_x, allowed_y))))
	// Paint the body left behind: a changed zone or species can strand pixels outside the mask.
	frame[stranded_y + 1][stranded_x + 1] = "#ff0000ff"
	editor.rebuild_resources()
	TEST_ASSERT(frame[stranded_y + 1][stranded_x + 1] == "#00000000", "Markings must drop paint outside the body instead of keeping it.")
	TEST_ASSERT(frame[allowed_y + 1][allowed_x + 1] != "#00000000", "Clipping must leave paint on the body alone.")
	TEST_ASSERT(custom_sprite_hash(editor.workspace.serialize_drawing()) == custom_sprite_hash(custom_sprite_validate(editor.workspace.serialize_drawing())), "The clipped drawing must still be canonical.")
	editor.finish(FALSE)


/datum/unit_test/custom_sprite_facial_hair_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/style = custom_style_test_facial_style()
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], style)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/facial_hair_color], "#583820")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "facial_hair")
	TEST_ASSERT(!(editor.workspace.hair_context["style"] != style || editor.workspace.hair_context["color"] != "#583820"), "The facial hair editor must open on the character's own facial look.")
	TEST_ASSERT(!(!editor.can_change_hair() || !(style in editor.available_hairstyles())), "The facial hair editor must offer facial hairstyles.")
	var/list/bounds = editor.workspace.draw_bounds["2"]
	TEST_ASSERT(json_encode(bounds) == json_encode(list(0, 0, 31, 31)), "Facial hair must have the same unrestricted canvas as head hair.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(bounds[1] + 2, bounds[2] + 2)))), "The facial hair editor must accept paint inside its bounds.")
	TEST_ASSERT(!(editor.save_drawing() != TRUE || custom_sprite_hash(preferences.custom_facial_hair) != custom_sprite_hash(editor.workspace.serialize_drawing())), "Saving must store the facial hair drawing on its own key: [editor.save_error]")
	TEST_ASSERT(!preferences.custom_hair, "Saving facial hair must not touch the head hair drawing.")
	preferences.load_custom_sprites()
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_base_markings/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_L_ARM)
	var/datum/custom_sprite_editor/hair = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	TEST_ASSERT(!(!editor.can_change_markings() || hair.can_change_markings()), "Only a limb zone may change its own markings.")
	hair.finish(FALSE)
	var/marking = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM][1]
	var/before = json_encode(preferences.body_markings)
	TEST_ASSERT(editor.write_base_marking(null, marking, "#112233"), "Adding a limb marking must succeed.")
	TEST_ASSERT(json_encode(preferences.body_markings) == before, "Base markings must remain in the draft until saving.")
	editor.workspace.undo()
	TEST_ASSERT(!length(editor.base_markings()), "Undo must remove a newly added base marking.")
	editor.workspace.redo()
	editor.rebuild_resources()
	var/list/entries = editor.base_markings()
	TEST_ASSERT(!(length(entries) != 1 || entries[1]["name"] != marking || entries[1]["color"] != "#112233"), "The editor must list the limb's markings with their colors.")
	TEST_ASSERT(!(!editor.write_base_marking(1, marking, "#445566") || editor.base_markings()[1]["color"] != "#445566"), "Recoloring a limb marking must keep its place.")
	var/second = length(GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]) > 1 ? GLOB.body_markings_per_limb[BODY_ZONE_L_ARM][2] : null
	TEST_ASSERT(!(second && (!editor.write_base_marking(1, second, null) || editor.base_markings()[1]["name"] != second)), "Changing which marking a slot uses must keep its color slot.")
	TEST_ASSERT(!(!editor.write_base_marking(1, null, null) || length(editor.base_markings())), "Removing a limb marking must empty the list.")
	TEST_ASSERT(!editor.write_base_marking(4, null, null), "Acting on a marking that isn't there must fail.")
	editor.workspace.undo()
	editor.rebuild_resources()
	TEST_ASSERT(!(editor.save_drawing() != TRUE || length(preferences.body_markings?[BODY_ZONE_L_ARM]) != 1), "Saving must persist the draft's base markings with its drawing.")
	editor.finish(FALSE)


/datum/unit_test/custom_sprite_gradient_toggle/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Short Hair")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/hair_color], "#2244cc")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hair_gradient], "Full")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/color/hair_gradient], "#22ddcc")
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "hair")
	TEST_ASSERT(("#22ddcc" in editor.sampled_palette), "A gradient's color must be offered while the gradient is shown.")
	var/showing = json_encode(editor.guide_urls)
	editor.show_gradient = FALSE
	editor.rebuild_resources()
	TEST_ASSERT(!("#22ddcc" in editor.sampled_palette), "Hiding the gradient must fall back to the plain hairstyle palette.")
	TEST_ASSERT(json_encode(editor.guide_urls) != showing, "Hiding the gradient must change the guide.")
	TEST_ASSERT(json_encode(editor.workspace.hair_context) == json_encode(preferences.custom_style_hair_context()), "Hiding the gradient must not change the look being saved.")
	editor.show_gradient = TRUE
	editor.rebuild_resources()
	TEST_ASSERT(!(json_encode(editor.guide_urls) != showing || !("#22ddcc" in editor.sampled_palette)), "Showing the gradient again must restore the guide and palette.")
	editor.finish(FALSE)


/datum/unit_test/custom_sprite_restore_offer/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.load_custom_sprites()
	var/datum/custom_sprite_editor/editor = new /datum/custom_sprite_editor/optimization_test(preferences, "markings", BODY_ZONE_L_ARM)
	TEST_ASSERT(!editor.context_ui_data()["canRestorePrevious"], "Nothing to restore means no offer.")
	var/list/bounds = editor.workspace.draw_bounds["2"]
	var/painted = FALSE
	for(var/y in bounds[2] to bounds[4])
		for(var/x in bounds[1] to bounds[3])
			if(!editor.workspace.is_point_allowed(x, y, "2"))
				continue
			painted = editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(list(x, y))))
			break
		if(painted)
			break
	TEST_ASSERT(painted, "The fixture must paint something on the limb.")
	var/list/previous = editor.current_package()
	LAZYSET(preferences.custom_style_previous, custom_style_key("markings", BODY_ZONE_L_ARM), previous)
	TEST_ASSERT(!editor.context_ui_data()["canRestorePrevious"], "A style the draft already matches must not be offered.")
	editor.workspace.clear_direction("2")
	TEST_ASSERT(editor.context_ui_data()["canRestorePrevious"], "A previous saved style must be offered.")
	editor.show_candidate(custom_style_copy_package(previous), "restore")
	TEST_ASSERT(editor.apply_candidate(), "Restoring the previous style failed: [editor.transfer_error]")
	TEST_ASSERT(!editor.context_ui_data()["canRestorePrevious"], "Restoring the same style again must not be offered.")
	editor.workspace.undo()
	TEST_ASSERT(editor.context_ui_data()["canRestorePrevious"], "Undoing the restore must offer it again.")
	editor.finish(FALSE)
