/// Exercises the whole-body editor's real actions without a connected client.
/datum/custom_sprite_editor/markings/unified_test/can_edit(mob/user)
	return !closing

/// The first canvas pixel a region owns in one view, as list(x, y), or null.
/proc/custom_sprite_test_region_pixel(datum/custom_sprite_editor/markings/editor, zone, direction = "2")
	var/index = "[editor.region_zones.Find(zone)]"
	var/list/rows = editor.region_map[direction]
	for(var/y in 1 to 32)
		var/x = findtext(rows[y], index)
		if(x)
			return list(x - 1, y - 1)

/// Paints one pixel a region owns with the first color the canvas offers.
/proc/custom_sprite_test_paint_region(datum/custom_sprite_editor/markings/editor, zone, direction = "2")
	var/list/point = custom_sprite_test_region_pixel(editor, zone, direction)
	return point && editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = direction, "color" = "[editor.workspace.palette[1]]ff", "points" = list(point)))

/**
 * Saves up to `count` distinct colors across the body's regions in the Front view, a few per region.
 *
 * Returns how many colors were placed.
 */
/proc/custom_sprite_test_pool_colors(datum/preferences/preferences, count)
	// A first editor maps the body, so each color lands on a pixel its region owns.
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/owned = list()
	for(var/zone in probe.region_zones)
		var/index = "[probe.region_zones.Find(zone)]"
		var/list/rows = probe.region_map["2"]
		var/list/points = list()
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				if(copytext(rows[y], x, x + 1) == index && length(points) < 20)
					points += list(list(x - 1, y - 1))
		owned[zone] = points
	probe.finish(FALSE)
	var/placed = 0
	for(var/zone in owned)
		var/list/points = list()
		for(var/list/point as anything in owned[zone])
			if(placed >= count)
				break
			placed++
			points += list(list(point[1], point[2], LOWER_TEXT(rgb(placed, 17, 99))))
		if(length(points))
			var/list/drawing = custom_sprite_test_region_drawing(points)
			drawing["dirs"] = list("2" = drawing["dirs"]["2"])
			LAZYSET(preferences.custom_limb_markings, zone, drawing)
	return placed

/// A pixel a region's own mask covers but a different limb owns on the canvas, as list(direction, x, y), or null.
/proc/custom_sprite_test_hidden_pixel(datum/custom_sprite_editor/markings/editor, zone)
	var/index = "[editor.region_zones.Find(zone)]"
	var/list/masks = custom_sprite_body_draw_mask(editor.preview_body, zone, custom_marking_zone_width(zone))
	for(var/direction in list("4", "8", "1", "2"))
		var/list/rows = editor.region_map[direction]
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/owner = copytext(rows[y], x, x + 1)
				if(owner == "0" || owner == index || copytext(masks[direction][y], x, x + 1) != "1")
					continue
				if(editor.region_zones[text2num(owner)] != custom_marking_partner(zone))
					return list(direction, x - 1, y - 1)

/datum/unit_test/custom_sprite_markings_editor_save/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/test_path = "tmp/custom_sprite_markings_editor_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/datum/json_savefile/custom_sprites/counting_test/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_and_save = TRUE
	TEST_ASSERT(!preferences.commit_custom_style(custom_style_package("markings", BODY_ZONE_R_LEG, custom_sprite_test_drawing(), null), preferences.default_slot), "The fixture leg must save.")
	var/leg_json = json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG])
	var/writes = store.writes
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	TEST_ASSERT(editor.selected_zone == BODY_ZONE_L_ARM, "Opening from a limb's Custom button selects that limb.")
	var/list/leg_point = custom_sprite_test_region_pixel(editor, BODY_ZONE_R_LEG)
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][leg_point[2] + 1][leg_point[1] + 1] != "#00000000", "The canvas must show saved per-limb paint on its region.")
	TEST_ASSERT(editor.save_drawing(), "Saving an untouched draft must succeed.")
	TEST_ASSERT(store.writes == writes, "Saving an untouched draft must not write anything.")
	TEST_ASSERT(custom_sprite_test_paint_region(editor, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	TEST_ASSERT(editor.save_drawing(), "Saving one painted region must succeed: [editor.save_error]")
	TEST_ASSERT(store.writes == writes + 1, "Saving must write once.")
	TEST_ASSERT(preferences.custom_limb_markings?[BODY_ZONE_L_ARM], "The painted region must be saved as its own limb drawing.")
	TEST_ASSERT(json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG]) == leg_json, "Regions nobody edited must be left exactly as saved.")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("clear", list("dir" = "2", "zone" = BODY_ZONE_L_ARM), ui, null), "Clearing the painted region must succeed.")
	TEST_ASSERT(!(editor.save_drawing() != TRUE || preferences.custom_limb_markings?[BODY_ZONE_L_ARM]), "Erasing a region's paint saves it as unmarked.")
	TEST_ASSERT(json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG]) == leg_json, "Clearing one region must not touch another.")
	editor.finish(FALSE)
	store.path = null
	preferences.load_and_save = FALSE

/datum/unit_test/custom_sprite_markings_editor_regions/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(!editor.ui_act("selectRegion", list("zone" = "tail"), ui, null), "Unknown regions can't be selected.")
	TEST_ASSERT(!(!editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_LEG), ui, null) || editor.selected_zone != BODY_ZONE_L_LEG), "Selecting a present region must work.")
	TEST_ASSERT(editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "Adding a base marking to a region must work.")
	TEST_ASSERT(editor.save_drawing(), "Saving a base-marking-only change must succeed: [editor.save_error]")
	TEST_ASSERT(length(preferences.body_markings?[BODY_ZONE_L_ARM]) == 1, "The region's base markings must be saved.")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_L_ARM], "A base marking change alone must not create a drawing.")
	custom_sprite_test_paint_region(editor, BODY_ZONE_L_ARM)
	TEST_ASSERT(editor.ui_act("setEmissive", list("zone" = BODY_ZONE_L_ARM, "dir" = "2", "enabled" = TRUE), ui, null), "Turning on a region's emission must work.")
	editor.ui_act("setEmissive", list("zone" = BODY_ZONE_CHEST, "dir" = "2", "enabled" = TRUE), ui, null)
	TEST_ASSERT(editor.save_drawing(), "Saving emission must succeed: [editor.save_error]")
	TEST_ASSERT(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]?["emissive"]?["2"], "A painted region saves its emission per view.")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_CHEST], "An empty region has nothing to glow and saves nothing.")
	// Fill stays inside the clicked region.
	var/list/before = deep_copy_list(editor.workspace.layers[1]["data"]["2"])
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "bucket", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "point" = point)), ui, null), "Filling the torso must succeed.")
	var/chest_index = "[editor.region_zones.Find(BODY_ZONE_CHEST)]"
	var/list/frame = editor.workspace.layers[1]["data"]["2"]
	var/list/rows = editor.region_map["2"]
	var/filled = 0
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(frame[y][x] == before[y][x])
				continue
			filled++
			TEST_ASSERT(copytext(rows[y], x, x + 1) == chest_index, "Fill must not spill outside the torso ([x],[y]).")
	TEST_ASSERT(filled, "Fill must paint the torso.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_focus/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	var/revision = editor.focus_revision
	editor.focus_region(BODY_ZONE_R_LEG)
	TEST_ASSERT(!(editor.selected_zone != BODY_ZONE_R_LEG || editor.focus_revision != revision + 1), "Focusing a present region selects it and tells the window.")
	editor.focus_region(CUSTOM_MARKING_ZONE_TAUR)
	TEST_ASSERT(!(editor.selected_zone != BODY_ZONE_R_LEG || !findtext(editor.transfer_notice, "no taur")), "Focusing a region this body doesn't have keeps the selection and says why.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_palette_overflow/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	TEST_ASSERT(custom_sprite_test_pool_colors(preferences, 100) > CUSTOM_SPRITE_MAX_COLORS, "The fixture needs more than [CUSTOM_SPRITE_MAX_COLORS] visible colors across its regions.")
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	var/list/data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(length(editor.workspace.palette) > CUSTOM_SPRITE_MAX_COLORS, "Opening must keep every color the saves already use.")
	TEST_ASSERT(data["paletteNotice"], "An over-full canvas must explain why new colors can't be added.")
	TEST_ASSERT(!editor.workspace.is_valid_color("#fedcbaff"), "An over-full canvas must refuse new colors.")
	TEST_ASSERT(editor.save_drawing(), "An over-full but unedited canvas must still save as a no-op.")
	// Base markings add no colors, and imports hold each region to its own limit, as saves do.
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "An over-full canvas must still take base marking changes.")
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_L_ARM)
	var/list/arm = custom_sprite_test_region_drawing(list(list(point[1], point[2], "#fe12ab")))
	arm["dirs"] = list("2" = arm["dirs"]["2"])
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, arm, null)), "import"), "An over-full canvas must preview an import: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "An over-full canvas must take an import: [editor.transfer_error]")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_pooled_palette/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	TEST_ASSERT(custom_sprite_test_pool_colors(preferences, 50) == 50, "The fixture needs fifty colors across its regions.")
	var/list/custom = list()
	for(var/index in 1 to CUSTOM_SPRITE_MAX_CUSTOM_COLORS)
		custom += LOWER_TEXT(rgb(200, index, 7))
	TEST_ASSERT(preferences.write_preference(GLOB.preference_entries[/datum/preference/custom_sprite_palette], custom), "The fixture needs a full Custom palette.")
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	TEST_ASSERT(length(editor.workspace.palette) == CUSTOM_SPRITE_MAX_COLORS, "Sampled and Custom colors must fill the room the saves leave, not all be refused together.")
	TEST_ASSERT(!(!length(editor.sampled_palette) || !(editor.sampled_palette[1] in editor.workspace.palette)), "The body's own shades are admitted before Custom colors.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_routing/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	var/datum/custom_sprite_editor/markings/editor = middleware.markings_editor(BODY_ZONE_L_ARM)
	TEST_ASSERT(!(!istype(editor) || preferences.custom_sprite_editors?["markings"] != editor || editor.selected_zone != BODY_ZONE_L_ARM), "Any limb's Custom button must open the whole-body editor on that limb.")
	TEST_ASSERT(middleware.markings_editor(BODY_ZONE_R_LEG) == editor, "Another Custom button must reuse the open editor.")
	TEST_ASSERT(editor.selected_zone == BODY_ZONE_R_LEG, "Another Custom button must select its own limb.")
	TEST_ASSERT(length(preferences.custom_sprite_editors) == 1, "There is one markings window per character.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_import/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_L_ARM)
	var/list/arm = custom_sprite_test_region_drawing(list(list(point[1], point[2], "#fe12ab")))
	// Front view only: the same pixel may fall outside the arm in the other views.
	arm["dirs"] = list("2" = arm["dirs"]["2"])
	var/list/regions = list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, arm, null), CUSTOM_MARKING_ZONE_TAUR = custom_style_package("markings", CUSTOM_MARKING_ZONE_TAUR, null, null))
	TEST_ASSERT(editor.show_region_candidate(regions, "import"), "A whole-body import must preview: [editor.transfer_error]")
	TEST_ASSERT(!(length(editor.candidate["regions"]) != 1 || !("Taur lower body" in editor.candidate["skipped"])), "Regions this body doesn't have are skipped and named.")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][point[2] + 1][point[1] + 1] == "#fe12abff", "The imported region must replace its pixels.")
	TEST_ASSERT((BODY_ZONE_L_ARM in editor.rotate_zones), "Saving after an import rotates the imported regions' previous styles.")
	TEST_ASSERT(editor.save_drawing(), "Saving the import must succeed: [editor.save_error]")
	TEST_ASSERT(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM), "The imported region's previous style is kept.")
	TEST_ASSERT(length(editor.restorable_regions()) == 1, "The imported region can be restored.")
	editor.workspace.undo()
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][point[2] + 1][point[1] + 1] == "#00000000", "Undo must revert an import.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_setup_actions/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	TEST_ASSERT(custom_sprite_test_paint_region(editor, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, preferences, "PreferencesMenu")
	preferences.ui_act("add_marking", list("bodypart_slot" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(!preferences.custom_sprite_editors?["markings"], "A Markings tab change must save and close the whole-body editor first, so it can't write stale base markings back later.")
	TEST_ASSERT(preferences.custom_limb_markings?[BODY_ZONE_L_ARM], "Closing the editor must save its paint.")
	TEST_ASSERT(length(preferences.body_markings?[BODY_ZONE_L_ARM]) == 1, "The Markings tab change must still apply.")

/datum/unit_test/custom_sprite_markings_editor_hidden_paint/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/hidden = custom_sprite_test_hidden_pixel(probe, BODY_ZONE_CHEST)
	var/list/owned = custom_sprite_test_region_pixel(probe, BODY_ZONE_CHEST)
	probe.finish(FALSE)
	TEST_ASSERT(hidden, "The fixture needs torso paint that another limb covers in some view.")
	var/direction = hidden[1]
	var/list/drawing = custom_sprite_test_region_drawing(list(list(hidden[2], hidden[3], "#fe12ab")))
	var/list/views = list()
	views[direction] = drawing["dirs"][direction]
	drawing["dirs"] = views
	// Clear reaches the region's paint the canvas can't show.
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_CHEST, drawing)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("clear", list("dir" = direction, "zone" = BODY_ZONE_CHEST), ui, null), "Clearing a region must reach its paint another limb covers.")
	TEST_ASSERT(editor.save_drawing(), "Saving the cleared torso must succeed: [editor.save_error]")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_CHEST], "A cleared region with no paint left saves as unmarked.")
	editor.finish(FALSE)
	// An import replaces the region outright, covered paint included.
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_CHEST, drawing)
	editor = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/list/imported = custom_sprite_test_region_drawing(list(list(owned[1], owned[2], "#12ab34")))
	imported["dirs"] = list("2" = imported["dirs"]["2"])
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_CHEST = custom_style_package("markings", BODY_ZONE_CHEST, imported, null)), "import"), "The torso import must preview: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.save_drawing(), "Saving the import must succeed: [editor.save_error]")
	var/list/pixels = custom_sprite_drawing_pixels(preferences.custom_limb_markings?[BODY_ZONE_CHEST])
	TEST_ASSERT(!(pixels[direction][hidden[3] * 32 + hidden[2] + 1] || !pixels["2"][owned[2] * 32 + owned[1] + 1]), "An imported region must replace the old one, paint other limbs cover included.")
	editor.finish(FALSE)
