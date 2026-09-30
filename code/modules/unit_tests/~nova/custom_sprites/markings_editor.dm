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

/// A whole-body editor on a body with a real taur organ.
/datum/custom_sprite_editor/markings/unified_test/taur/create_preview_body()
	var/mob/living/carbon/human/dummy/body = ..()
	body.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part("Cow (Spotted)", list("#654321", "#321654", "#213456"))
	body.dna.species.regenerate_organs(body, visual_only = TRUE)
	body.update_body(is_creating = TRUE)
	return body

/// A whole-body editor whose saves always fail, as a full disk would make them.
/datum/custom_sprite_editor/markings/unified_test/failing/save_drawing()
	save_error = "The disk is full."
	return FALSE

/// A drawing with one painted pixel, in the Front view only.
/proc/custom_sprite_test_front_drawing(list/point, color)
	var/list/drawing = custom_sprite_test_region_drawing(list(list(point[1], point[2], color)))
	drawing["dirs"] = list("2" = drawing["dirs"]["2"])
	return drawing

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
	for(var/zone, owned_points in owned)
		var/list/points = list()
		for(var/list/point as anything in owned_points)
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
	TEST_ASSERT(!(editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_LEG), ui, null) || editor.selected_zone != BODY_ZONE_L_LEG), "Selecting a present region must work without resending the window, which already shows it.")
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "Adding a base marking to a region must work.")
	TEST_ASSERT(editor.save_drawing(), "Saving a base-marking-only change must succeed: [editor.save_error]")
	TEST_ASSERT(length(preferences.body_markings?[BODY_ZONE_L_ARM]) == 1, "The region's base markings must be saved.")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_L_ARM], "A base marking change alone must not create a drawing.")
	custom_sprite_test_paint_region(editor, BODY_ZONE_L_ARM)
	TEST_ASSERT(editor.ui_act("setEmissive", list("zone" = BODY_ZONE_L_ARM, "dir" = "2", "enabled" = TRUE), ui, null), "Turning on a region's emission must work.")
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_CHEST), ui, null)
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

/datum/unit_test/custom_sprite_markings_editor_species_choices/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
	var/foreign
	for(var/name in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM])
		var/datum/body_marking/marking = GLOB.body_markings[name]
		if(marking.recommended_species && !marking.recommended_species[SPECIES_HUMAN])
			foreign = name
			break
	TEST_ASSERT(foreign, "The fixture needs a left arm marking meant for another species.")
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	var/list/static_data = editor.ui_static_data(mock_client.mob)
	var/list/choices = static_data["regionMarkingChoices"][BODY_ZONE_L_ARM]
	TEST_ASSERT(length(choices) && !(foreign in choices), "Without mismatched parts, a region offers only its species' markings.")
	TEST_ASSERT(editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "Adding a base marking must work.")
	var/list/added = editor.workspace.markings_context[BODY_ZONE_L_ARM][1]
	TEST_ASSERT(added["name"] in choices, "Adding a base marking picks one the region offers.")
	TEST_ASSERT(!editor.ui_act("setBaseMarking", list("zone" = BODY_ZONE_L_ARM, "index" = 1, "name" = foreign), ui, null), "Without mismatched parts, another species' marking is refused.")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	TEST_ASSERT(editor.ui_act("setBaseMarking", list("zone" = BODY_ZONE_L_ARM, "index" = 1, "name" = foreign), ui, null), "Mismatched parts allow any species' marking.")
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
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "An over-full canvas must still take base marking changes.")
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_L_ARM)
	var/list/arm = custom_sprite_test_region_drawing(list(list(point[1], point[2], "#fe12ab")))
	arm["dirs"] = list("2" = arm["dirs"]["2"])
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, arm, null)), "import"), "An over-full canvas must preview an import: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "An over-full canvas must take an import: [editor.transfer_error]")
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
	TEST_ASSERT(!(length(editor.candidate["regions"]) != 1 || !("Taur lower body (not on this body)" in editor.candidate["skipped"])), "Regions this body doesn't have are skipped and named.")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][point[2] + 1][point[1] + 1] == "#fe12abff", "The imported region must replace its pixels.")
	TEST_ASSERT((BODY_ZONE_L_ARM in editor.workspace.unsaved_rotations()), "Saving after an import rotates the imported regions' previous styles.")
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

/datum/unit_test/custom_sprite_markings_editor_import_scope/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/arm = custom_sprite_test_region_pixel(probe, BODY_ZONE_L_ARM)
	var/list/leg = custom_sprite_test_region_pixel(probe, BODY_ZONE_R_LEG)
	var/list/head = custom_sprite_test_region_pixel(probe, BODY_ZONE_HEAD)
	probe.finish(FALSE)
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm, "#111111"))
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_R_LEG, custom_sprite_test_front_drawing(leg, "#222222"))
	var/leg_json = json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG])
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	// A single-region file replaces only its own region.
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm, "#333333"), null)), "import"), "The arm import must preview: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the arm import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.save_drawing(), "Saving the arm import must succeed: [editor.save_error]")
	TEST_ASSERT(json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG]) == leg_json, "A single-region import must leave every other region alone.")
	// A whole-body file replaces every region it lists, clearing the ones it has empty.
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, null, null), BODY_ZONE_HEAD = custom_style_package("markings", BODY_ZONE_HEAD, custom_sprite_test_front_drawing(head, "#444444"), null)), "import"), "The whole-body import must preview: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the whole-body import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.save_drawing(), "Saving the whole-body import must succeed: [editor.save_error]")
	TEST_ASSERT(!(preferences.custom_limb_markings?[BODY_ZONE_L_ARM] || !preferences.custom_limb_markings?[BODY_ZONE_HEAD]), "A whole-body import clears the regions it has empty and paints the ones it has painted.")
	TEST_ASSERT(json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG]) == leg_json, "Regions a whole-body file doesn't list are left alone.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_failed_close/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/custom_sprite_editor/markings/unified_test/failing/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware.pre_set_preference(mock_client.mob, "species", SPECIES_LIZARD), "A setting change must wait while an open drawing can't be saved.")
	TEST_ASSERT(preferences.custom_sprite_editors?["markings"] == editor, "The drawing that couldn't be saved stays open.")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, preferences, "PreferencesMenu")
	preferences.ui_act("add_marking", list("bodypart_slot" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(!length(preferences.body_markings?[BODY_ZONE_L_ARM]), "A Markings tab change must wait too.")
	TEST_ASSERT(preferences.custom_sprite_editors?["markings"] == editor, "The drawing that couldn't be saved stays open after a refused tab change.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_rebuild/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = editor.workspace
	editor.region_results()
	TEST_ASSERT(editor.results_cache, "The fixture must have cached results.")
	// As if the arm appeared after the draft opened.
	var/list/emissive = canvas.emissive.Copy()
	emissive -= BODY_ZONE_L_ARM
	canvas.emissive = emissive
	var/list/markings = canvas.markings_context.Copy()
	markings -= BODY_ZONE_L_ARM
	canvas.markings_context = markings
	var/obj/item/bodypart/leg = editor.preview_body.get_bodypart(BODY_ZONE_R_LEG)
	leg.drop_limb(special = TRUE)
	qdel(leg)
	editor.update_draw_area()
	TEST_ASSERT(!(BODY_ZONE_R_LEG in editor.region_zones), "The fixture must change the body's regions.")
	TEST_ASSERT(isnull(editor.results_cache), "A new region map must drop results worked out on the old one.")
	TEST_ASSERT(!(!canvas.emissive[BODY_ZONE_L_ARM] || !(BODY_ZONE_L_ARM in canvas.markings_context)), "Every present region needs emissive settings and base markings, including one that appeared later.")
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("setEmissive", list("zone" = BODY_ZONE_L_ARM, "dir" = "2", "enabled" = TRUE), ui, null), "A region that appeared later must take emissive changes.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_selection_authority/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	TEST_ASSERT(custom_sprite_test_paint_region(editor, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_L_ARM)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	editor.ui_act("clear", list("dir" = "2", "zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][point[2] + 1][point[1] + 1] != "#00000000", "Region actions act on the server's selection; a different zone from the window is refused.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_undo_side_effects/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/arm = custom_sprite_test_region_pixel(probe, BODY_ZONE_L_ARM)
	probe.finish(FALSE)
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm, "#111111"))
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = editor.workspace
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm, "#333333"), null)), "import"), "The arm import must preview: [editor.transfer_error]")
	TEST_ASSERT(editor.apply_candidate(), "Confirming the arm import must apply it: [editor.transfer_error]")
	TEST_ASSERT(editor.ui_act("setEmissive", list("zone" = BODY_ZONE_CHEST, "dir" = "2", "enabled" = TRUE), ui, null), "Turning on the torso's emission must work.")
	canvas.undo()
	TEST_ASSERT(canvas.emissive[BODY_ZONE_CHEST]["2"], "Undoing an import must not undo a later emission change on another region.")
	// The undone import must not rotate the arm's saved style away either.
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.ui_act("clear", list("dir" = "2", "zone" = BODY_ZONE_L_ARM), ui, null), "Clearing the arm must work.")
	TEST_ASSERT(editor.save_drawing(), "Saving must succeed: [editor.save_error]")
	TEST_ASSERT(!preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM), "An undone import must not make the next save keep the replaced style as previous.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_region_color_limit/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	TEST_ASSERT(custom_sprite_test_pool_colors(preferences, 100) > CUSTOM_SPRITE_MAX_COLORS, "The fixture needs more than [CUSTOM_SPRITE_MAX_COLORS] colors across its regions.")
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	// Move 64 of the canvas's colors into the torso: more than one region can save.
	var/index = "[editor.region_zones.Find(BODY_ZONE_CHEST)]"
	var/list/rows = editor.region_map["2"]
	var/list/colors = editor.workspace.palette.Copy()
	var/painted = 0
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(painted >= CUSTOM_SPRITE_MAX_COLORS + 1 || copytext(rows[y], x, x + 1) != index)
				continue
			painted++
			editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[colors[painted]]ff", "points" = list(list(x - 1, y - 1))))
	TEST_ASSERT(painted == CUSTOM_SPRITE_MAX_COLORS + 1, "The fixture needs [CUSTOM_SPRITE_MAX_COLORS + 1] torso pixels.")
	TEST_ASSERT(editor.region_results()[BODY_ZONE_CHEST]["error"], "The fixture's torso must be over the limit.")
	TEST_ASSERT(findtext(editor.export_problem(list(BODY_ZONE_CHEST)), "torso"), "Exporting a region that can't be saved must say which region and why.")
	TEST_ASSERT(findtext(editor.ui_data(mock_client.mob)["paletteNotice"], "torso"), "The window must warn about a region that can't be saved before a save fails.")
	editor.render_region_previews(editor.region_results())
	TEST_ASSERT(editor.preview_body.dna.custom_limb_markings?[BODY_ZONE_CHEST], "The preview keeps showing the torso's saved paint instead of an empty torso.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_legacy_import/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	// A drawing-only file goes into the selected region.
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	var/list/arm = custom_sprite_test_region_pixel(editor, BODY_ZONE_L_ARM)
	var/list/legacy = custom_style_parse(json_encode(custom_style_export_drawing(custom_sprite_test_front_drawing(arm, "#fe12ab"))))
	TEST_ASSERT(legacy["legacy"], "The fixture must be a drawing-only file: [legacy["error"]]")
	TEST_ASSERT(editor.preview_received(legacy), "A drawing-only file must preview in the selected region: [editor.transfer_error]")
	TEST_ASSERT(!(length(editor.candidate["regions"]) != 1 || !editor.candidate["regions"][BODY_ZONE_L_ARM]), "A drawing-only file goes into the selected region only.")
	editor.finish(FALSE)
	// The taur region centres an old 32-wide file, as the single-zone taur editor did.
	var/datum/custom_sprite_editor/markings/unified_test/taur/wide = new(preferences, CUSTOM_MARKING_ZONE_TAUR)
	TEST_ASSERT(wide.selected_zone == CUSTOM_MARKING_ZONE_TAUR, "The fixture needs a taur body with its region selected.")
	var/index = "[wide.region_zones.Find(CUSTOM_MARKING_ZONE_TAUR)]"
	var/list/rows = wide.region_map["2"]
	var/list/centre
	for(var/y in 1 to 32)
		for(var/x in 17 to 48)
			if(!centre && copytext(rows[y], x, x + 1) == index)
				centre = list(x - 1, y - 1)
	TEST_ASSERT(centre, "The fixture needs a taur pixel in the central 32 columns.")
	legacy = custom_style_parse(json_encode(custom_style_export_drawing(custom_sprite_test_front_drawing(list(centre[1] - 16, centre[2]), "#fe12ab"))))
	TEST_ASSERT(wide.preview_received(legacy), "An old 32-wide file must preview in the taur region: [wide.transfer_error]")
	var/list/drawing = wide.candidate["regions"][CUSTOM_MARKING_ZONE_TAUR]["drawing"]
	TEST_ASSERT(custom_sprite_width(drawing) == CUSTOM_SPRITE_TAUR_WIDTH, "The taur region must centre the old file on its wide canvas.")
	TEST_ASSERT(custom_sprite_drawing_pixels(drawing, CUSTOM_SPRITE_TAUR_WIDTH)["2"][centre[2] * CUSTOM_SPRITE_TAUR_WIDTH + centre[1] + 1], "The centred paint must land where the old taur editor put it.")
	wide.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_move_between_regions/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	// A torso pixel with a different region straight to its right.
	var/chest = "[editor.region_zones.Find(BODY_ZONE_CHEST)]"
	var/list/rows = editor.region_map["2"]
	var/list/from
	var/landing_zone
	for(var/y in 1 to 32)
		for(var/x in 1 to 31)
			var/next = copytext(rows[y], x + 1, x + 2)
			if(!from && copytext(rows[y], x, x + 1) == chest && next != "0" && next != chest)
				from = list(x - 1, y - 1)
				landing_zone = editor.region_zones[text2num(next)]
	TEST_ASSERT(from, "The fixture needs a torso pixel next to another region.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(from))), "The fixture must paint the torso pixel.")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "move", "layer" = 1, "dir" = "2", "rect" = list(from[1], from[2], from[1], from[2]), "offset" = list(1, 0))), "Moving paint across a region edge must work.")
	TEST_ASSERT(editor.save_drawing(), "Saving the move must succeed: [editor.save_error]")
	var/list/landed = custom_sprite_drawing_pixels(preferences.custom_limb_markings?[landing_zone])
	TEST_ASSERT(landed["2"][from[2] * 32 + from[1] + 2], "Moved paint belongs to the region it lands in ([landing_zone]).")
	TEST_ASSERT(!preferences.custom_limb_markings?[BODY_ZONE_CHEST], "The region the paint left no longer has it.")
	editor.finish(FALSE)

/datum/unit_test/custom_sprite_markings_editor_emissive_only/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/arm = custom_sprite_test_region_pixel(probe, BODY_ZONE_L_ARM)
	var/list/leg = custom_sprite_test_region_pixel(probe, BODY_ZONE_R_LEG)
	probe.finish(FALSE)
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm, "#111111"))
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_R_LEG, custom_sprite_test_front_drawing(leg, "#222222"))
	var/leg_json = json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG])
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.ui_act("setEmissive", list("zone" = BODY_ZONE_L_ARM, "dir" = "2", "enabled" = TRUE), ui, null), "Turning on the arm's emission must work.")
	TEST_ASSERT(editor.save_drawing(), "Saving an emission-only change must succeed: [editor.save_error]")
	TEST_ASSERT(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]?["emissive"]?["2"], "An emission change alone must rewrite the painted region.")
	TEST_ASSERT(json_encode(preferences.custom_limb_markings[BODY_ZONE_R_LEG]) == leg_json, "An emission change must leave other regions alone.")
	editor.finish(FALSE)

/// A whole-body editor that locks the left arm, as the salon does with a covered region.
/datum/custom_sprite_editor/markings/unified_test/locking
	/// Whether the left arm is locked right now.
	var/arm_locked = TRUE

/datum/custom_sprite_editor/markings/unified_test/locking/locked_regions()
	. = list()
	if(arm_locked)
		.[BODY_ZONE_L_ARM] = "The left arm is covered."

/datum/unit_test/custom_sprite_markings_editor_locked_regions/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	// A first editor maps the body, so the saved arm paint lands on a pixel the arm owns.
	var/datum/custom_sprite_editor/markings/unified_test/probe = new(preferences, BODY_ZONE_CHEST)
	var/list/arm_point = custom_sprite_test_region_pixel(probe, BODY_ZONE_L_ARM)
	var/list/chest_point = custom_sprite_test_region_pixel(probe, BODY_ZONE_CHEST)
	probe.finish(FALSE)
	LAZYSET(preferences.custom_limb_markings, BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm_point, "#fe12ab"))
	var/datum/custom_sprite_editor/markings/unified_test/locking/editor = new(preferences, BODY_ZONE_L_ARM)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	TEST_ASSERT(editor.selected_zone == BODY_ZONE_CHEST, "Opening on a locked region must select the torso instead: [editor.selected_zone]")
	TEST_ASSERT(editor.transfer_notice == "The left arm is covered.", "Opening on a locked region must say why: [editor.transfer_notice]")
	var/list/mask = editor.workspace.draw_mask["2"]
	TEST_ASSERT(copytext(mask[arm_point[2] + 1], arm_point[1] + 1, arm_point[1] + 2) == "0", "A locked region's pixels must leave the paintable mask, so the canvas shades them.")
	TEST_ASSERT(!editor.workspace.is_point_allowed(arm_point[1], arm_point[2], "2"), "No tool may paint a locked region.")
	TEST_ASSERT(editor.workspace.is_point_allowed(chest_point[1], chest_point[2], "2"), "Other regions stay paintable.")
	var/list/frame = editor.workspace.layers[1]["data"]["2"]
	TEST_ASSERT(frame[arm_point[2] + 1][arm_point[1] + 1] == "#fe12abff", "A locked region keeps showing its paint.")
	TEST_ASSERT(!editor.workspace.new_transaction(list("type" = "eraser", "layer" = 1, "dir" = "2", "points" = list(arm_point))), "The eraser must not reach a locked region.")
	TEST_ASSERT(!editor.workspace.new_transaction(list("type" = "bucket", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "point" = arm_point)), "Fill must not start in a locked region.")
	var/list/move = list("type" = "move", "layer" = 1, "dir" = "2", "rect" = list(arm_point[1], arm_point[2], arm_point[1], arm_point[2]), "offset" = list(chest_point[1] - arm_point[1], chest_point[2] - arm_point[2]))
	TEST_ASSERT(!editor.workspace.new_transaction(move), "A move must not carry paint out of a locked region.")
	var/revision = editor.draft_revision
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "eraser", "layer" = 1, "dir" = "2", "points" = list(arm_point))), ui, null), "A refused stroke must resend the canvas so the window drops it.")
	TEST_ASSERT(editor.draft_revision == revision, "A refused stroke must not count as an edit.")
	editor.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui, null)
	TEST_ASSERT(editor.selected_zone != BODY_ZONE_L_ARM, "A locked region can't be selected.")
	// A region can lock while it's selected; its actions are refused until it unlocks.
	editor.selected_zone = BODY_ZONE_L_ARM
	TEST_ASSERT(!editor.ui_act("clear", list("dir" = "2", "zone" = BODY_ZONE_L_ARM), ui, null), "Clear must refuse a locked region.")
	TEST_ASSERT(!editor.ui_act("setEmissive", list("zone" = BODY_ZONE_L_ARM, "dir" = "2", "enabled" = TRUE), ui, null), "Emission can't change on a locked region.")
	TEST_ASSERT(!editor.ui_act("addBaseMarking", list("zone" = BODY_ZONE_L_ARM), ui, null), "Base markings can't change on a locked region.")
	var/list/results = editor.region_results()
	var/list/arm_result = results[BODY_ZONE_L_ARM]
	TEST_ASSERT(!arm_result["changed"], "Nothing may have changed the locked region.")
	var/list/data = editor.ui_data(mock_client.mob)
	var/list/reasons = data["lockedRegions"]
	TEST_ASSERT(reasons[BODY_ZONE_L_ARM] == "The left arm is covered.", "The window must learn which regions are locked and why.")
	var/list/arm_package = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm_point, "#123456"), null)
	var/list/chest_package = custom_style_package("markings", BODY_ZONE_CHEST, custom_sprite_test_front_drawing(chest_point, "#123456"), null)
	TEST_ASSERT(editor.show_region_candidate(list(BODY_ZONE_L_ARM = arm_package, BODY_ZONE_CHEST = chest_package), "import"), "An import that also covers a locked region must still preview: [editor.transfer_error]")
	var/list/candidate_regions = editor.candidate["regions"]
	TEST_ASSERT(!((BODY_ZONE_L_ARM in candidate_regions) || !(BODY_ZONE_CHEST in candidate_regions)), "An import must skip locked regions and keep the rest.")
	TEST_ASSERT(("Left arm (not available right now)" in editor.candidate["skipped"]), "The preview must name the skipped locked region: [json_encode(editor.candidate["skipped"])]")
	editor.candidate = null
	TEST_ASSERT(!editor.show_region_candidate(list(BODY_ZONE_L_ARM = arm_package), "import"), "An import of only locked regions has nothing to preview.")
	TEST_ASSERT(editor.transfer_error == "None of that style's regions can be changed right now.", "It must say why: [editor.transfer_error]")
	TEST_ASSERT(editor.region_candidate_problem(list(BODY_ZONE_L_ARM = arm_package)) == "The left arm is covered.", "A region that locks after its preview must be refused when confirmed.")
	// Unlocking frees the region at once.
	editor.arm_locked = FALSE
	editor.sync_locked_views(push = FALSE)
	TEST_ASSERT(editor.workspace.is_point_allowed(arm_point[1], arm_point[2], "2"), "An unlocked region must be paintable again.")
	TEST_ASSERT(editor.ui_act("clear", list("dir" = "2", "zone" = BODY_ZONE_L_ARM), ui, null), "An unlocked region's actions must work again.")
	editor.finish(FALSE)


/// The compact placement the selection tool sends for a temporary picture or a final drop.
/proc/custom_sprite_test_selection_placement(list/changes, width = 32)
	var/list/palette = list("#00000000", "#fe12abff", "#12ab34ff")
	var/list/codes = new /list(width * 32)
	for(var/index in 1 to length(codes))
		codes[index] = "."
	for(var/list/point as anything in changes)
		codes[point[2] * width + point[1] + 1] = "[palette.Find(point[3]) - 1]"
	return list("layer" = 1, "dir" = "2", "area" = list(0, 0, width - 1, 31), "palette" = palette, "digits" = 1, "codes" = jointext(codes, ""))

/// Both ordinary and taur previews follow a floating selection without changing its draft or undo stack.
/datum/unit_test/custom_sprite_markings_selection_preview/Run()
	for(var/editor_type in list(/datum/custom_sprite_editor/markings/unified_test, /datum/custom_sprite_editor/markings/unified_test/taur))
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
		// Keep the tested torso/arm pixels visible instead of depending on randomized hair or beards.
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], "Shaved")
		var/datum/custom_sprite_editor/markings/unified_test/editor = new editor_type(preferences, BODY_ZONE_CHEST)
		LAZYSET(preferences.custom_sprite_editors, "markings", editor)
		var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
		var/list/points = list()
		var/list/rows = editor.region_map["2"]
		for(var/zone in list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM))
			var/list/point
			for(var/y in 0 to 30)
				for(var/x in 0 to editor.workspace.width - 1)
					if(!point && custom_sprite_region_owner(rows, editor.region_zones, x, y) == zone && editor.workspace.is_point_allowed(x, y + 1, "2"))
						point = list(x, y)
			TEST_ASSERT(point, "Each fixture region needs a source and a drawable pixel below it.")
			points += list(point)
		editor.workspace.update_palette(list("#fe12ab", "#12ab34"))
		var/list/changes = list()
		for(var/index in 1 to length(points))
			var/list/point = points[index]
			var/color = index == 1 ? "#fe12abff" : "#12ab34ff"
			TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = color, "points" = list(point))), "Both source regions must be painted.")
			changes += list(list(point[1], point[2], "#00000000"), list(point[1], point[2] + 1, color))
		editor.draft_edited()
		editor.refresh_preview(push = FALSE)
		var/original_preview = editor.preview_urls["2"]
		var/original_frame = json_encode(editor.workspace.layers[1]["data"])
		var/original_results = json_encode(editor.region_results())
		var/history = length(editor.workspace.undo_stack)
		var/revision = editor.draft_revision
		var/list/transaction = custom_sprite_test_selection_placement(changes, editor.workspace.width)
		editor.ui_act("previewSelection", list("transaction" = transaction), ui, null)
		TEST_ASSERT(editor.selection_request && !editor.selection_frames, "A selection action must defer validation and rendering.")
		TEST_ASSERT_EQUAL(editor.preview_urls["2"], original_preview, "Actions must not compose or flatten a preview inline.")
		editor.refresh_preview(push = FALSE)
		TEST_ASSERT(editor.selection_frames, "The ordinary placement validator must accept paint spanning multiple regions.")
		TEST_ASSERT(editor.preview_urls["2"] != original_preview, "The character thumbnail must show the moved paint for ordinary and taur bodies.")
		for(var/list/change as anything in changes)
			TEST_ASSERT_EQUAL(editor.selection_frames["2"][change[2] + 1][change[1] + 1], change[3], "Every moved region must appear in the temporary frame.")
		TEST_ASSERT_EQUAL(json_encode(editor.workspace.layers[1]["data"]), original_frame, "Floating previews must never write the draft.")
		TEST_ASSERT_EQUAL(json_encode(editor.region_results()), original_results, "Save/export packages must ignore temporary paint.")
		TEST_ASSERT_EQUAL(length(editor.workspace.undo_stack), history, "Floating previews must not create history.")
		TEST_ASSERT_EQUAL(editor.draft_revision, revision, "Floating previews must not mark the draft changed.")
		editor.ui_act("previewSelection", list("transaction" = null), ui, null)
		editor.refresh_preview(push = FALSE)
		TEST_ASSERT(!editor.selection_frames, "Cancelling must forget temporary paint.")
		TEST_ASSERT_EQUAL(editor.preview_urls["2"], original_preview, "Cancelling must restore the exact previous thumbnail.")
		editor.queue_selection_preview(transaction)
		editor.refresh_preview(push = FALSE)
		editor.queue_selection_preview(transaction)
		editor.ui_close(mock_client.mob)
		TEST_ASSERT(!editor.selection_request && !editor.selection_frames, "Closing must discard queued and rendered temporary paint without a frontend cancellation.")
		TEST_ASSERT(editor.rebuild_resources(), "Reopening must rebuild the retained authoritative draft.")
		editor.refresh_preview(push = FALSE)
		TEST_ASSERT_EQUAL(editor.preview_urls["2"], original_preview, "Reopening must show the original draft, not a previous temporary selection.")
		editor.finish(FALSE)

/// Mutable locks emulate clothing or mirror access changing during the debounce.
/datum/custom_sprite_editor/markings/unified_test/selection_locks
	var/list/test_region_locks = list()
	var/list/test_view_locks = list()

/datum/custom_sprite_editor/markings/unified_test/selection_locks/locked_regions()
	return test_region_locks

/datum/custom_sprite_editor/markings/unified_test/selection_locks/locked_directions()
	return test_view_locks

/// Hostile preview messages cannot bypass placement validation, region locks, draft isolation or the one-request bound.
/datum/unit_test/custom_sprite_markings_selection_preview/hostile/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/selection_locks/editor = new(preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	editor.workspace.update_palette(list("#fe12ab", "#12ab34"))
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	var/list/first = custom_sprite_test_selection_placement(list(list(point[1], point[2], "#fe12abff")))
	var/list/last = custom_sprite_test_selection_placement(list(list(point[1], point[2], "#12ab34ff")))
	var/original_frame = json_encode(editor.workspace.layers[1]["data"])
	var/original_preview = editor.preview_urls["2"]
	for(var/index in 1 to 100)
		TEST_ASSERT(editor.queue_selection_preview(index == 100 ? last : first), "Valid preview requests must coalesce.")
	TEST_ASSERT_EQUAL(editor.selection_request["codes"], last["codes"], "A burst retains exactly its latest request.")
	TEST_ASSERT(!editor.selection_frames, "A hostile action burst must not decode or compose inline.")
	TEST_ASSERT_EQUAL(editor.preview_urls["2"], original_preview, "A hostile action burst must not render inline.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT_EQUAL(editor.selection_frames["2"][point[2] + 1][point[1] + 1], "#12ab34ff", "The deferred preview must use only the latest bounded request.")
	TEST_ASSERT_EQUAL(json_encode(editor.workspace.layers[1]["data"]), original_frame, "Even a hostile burst must not modify the draft.")
	for(var/invalid in list("dir", "area", "palette", "digits", "codes"))
		var/list/bad = first.Copy()
		switch(invalid)
			if("dir")
				bad[invalid] = "bogus"
			if("area")
				bad[invalid] = list(0, 0, 31)
			if("palette")
				bad[invalid] = new /list(1025)
			if("digits")
				bad[invalid] = 3
			if("codes")
				bad[invalid] = repeat_string(2049, "0")
		TEST_ASSERT(!editor.queue_selection_preview(bad), "Oversized or malformed [invalid] must be refused before queueing.")
	var/list/bad_color = first.Copy()
	bad_color["palette"] = list("#00000000", "not a color", "#12ab34ff")
	TEST_ASSERT(editor.queue_selection_preview(bad_color), "Color validation is deferred.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "Malformed colors must never reach a preview frame.")
	TEST_ASSERT_EQUAL(editor.preview_urls["2"], original_preview, "A malformed replacement must restore the authoritative thumbnail.")
	var/datum/sprite_editor_workspace/custom_sprite/regions/canvas = editor.workspace
	// Erasing locked paint must fail too, not just painting a locked destination.
	canvas.layers[1]["data"]["2"][point[2] + 1][point[1] + 1] = "#fe12abff"
	var/list/erase = custom_sprite_test_selection_placement(list(list(point[1], point[2], "#00000000")))
	TEST_ASSERT(editor.queue_selection_preview(erase), "Lock checks are deferred.")
	editor.test_region_locks = list(BODY_ZONE_CHEST = "Covered")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "A region locking during the debounce must discard its pending preview.")
	TEST_ASSERT(editor.queue_selection_preview(erase), "A stable lock still passes the cheap envelope check.")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "Selections must never erase or move paint out of locked regions.")
	editor.test_region_locks = list()
	editor.sync_locked_views(push = FALSE)
	editor.queue_selection_preview(erase)
	editor.test_view_locks = list("2")
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "A view locking during the debounce must discard its pending preview.")
	editor.queue_selection_preview(erase)
	editor.refresh_preview(push = FALSE)
	TEST_ASSERT(!editor.selection_frames, "Even transparent erasure must not preview changes to a locked view.")
	editor.queue_selection_preview(last)
	editor.draft_changed()
	TEST_ASSERT(!editor.selection_request && !editor.selection_frames, "A real draft change must invalidate pending and rendered temporary paint.")
	editor.finish(FALSE)

/// Marking popups share immutable preference classes and never resend them with paint updates.
/datum/unit_test/custom_sprite_marking_catalog
	priority = TEST_LONGER

/datum/unit_test/custom_sprite_marking_catalog/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/markings/editor = allocate(/datum/custom_sprite_editor/markings/unified_test, preferences, BODY_ZONE_L_ARM)
	var/list/static_data = editor.ui_static_data(mock_client.mob)
	var/list/icons_by_zone = static_data["regionMarkingIcons"]
	TEST_ASSERT(icons_by_zone == custom_sprite_marking_icons(), "Editor catalogs must reuse the immutable shared map")
	var/datum/preference_middleware/limbs_and_markings/middleware = allocate(/datum/preference_middleware/limbs_and_markings)
	var/list/preference_data = middleware.get_constant_data()
	TEST_ASSERT(preference_data["marking_icons"] == icons_by_zone, "Normal preferences must use the same marking classes")
	var/datum/asset/spritesheet_batched/preferences/sheet = get_asset_datum(/datum/asset/spritesheet_batched/preferences)
	sheet.ensure_ready()
	for(var/zone, choices in GLOB.body_markings_per_limb)
		var/list/icons = icons_by_zone[zone]
		TEST_ASSERT_EQUAL(length(icons), length(choices), "Every [zone] marking must have a picker entry")
		for(var/name in choices)
			TEST_ASSERT(sheet.entries[icons[name]], "The cached preferences sheet must contain [zone] / [name]")
			TEST_ASSERT_EQUAL(sheet.icon_size_id(icons[name]), "preferences32x32", "The [zone] / [name] thumbnail must fit the shared picker, including wide source icons")
	var/list/dynamic_data = editor.ui_data(mock_client.mob)
	TEST_ASSERT(!("regionMarkingIcons" in dynamic_data) && !("regionMarkingChoices" in dynamic_data), "Painting updates must not resend marking catalogs")
	var/list/assets = editor.ui_assets(mock_client.mob)
	TEST_ASSERT(length(assets) == 1 && assets[1] == sheet, "Markings and tattooing must reuse the existing cached preferences asset")


/// Synthetic native marking art, registered only for these tests and removed by the test allocator.
/datum/custom_sprite_base_marking_fixture
	var/list/names = list()
	var/list/previous_choices = list()

/datum/custom_sprite_base_marking_fixture/New()
	var/list/zones = list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND)
	for(var/zone in zones)
		previous_choices[zone] = GLOB.body_markings_per_limb[zone]
		var/list/choices = GLOB.body_markings_per_limb[zone]
		GLOB.body_markings_per_limb[zone] = choices.Copy()
	for(var/index in 1 to 4)
		var/datum/body_marking/marking = new
		marking.name = "Copy test [REF(src)] [index]"
		marking.icon_state = index == 4 ? "missing" : "copy"
		marking.gendered = FALSE
		var/icon/tile = icon('icons/blanks/32x32.dmi', "nothing")
		tile.DrawBox(index == 3 ? "#ffffff80" : "#ffffff", 1, 1, 32, 32)
		var/icon/art = icon(tile)
		for(var/direction in GLOB.cardinals)
			art.Insert(tile, "", direction)
			for(var/zone in zones)
				art.Insert(tile, "copy_[zone]", direction)
				art.Insert(tile, "copy_digitigrade_[zone]", direction)
		marking.icon = art
		names += marking.name
		GLOB.body_markings[marking.name] = marking
		for(var/zone in zones)
			GLOB.body_markings_per_limb[zone] += marking.name

/datum/custom_sprite_base_marking_fixture/Destroy()
	for(var/name in names)
		qdel(GLOB.body_markings[name])
		GLOB.body_markings -= name
	for(var/zone, choices in previous_choices)
		GLOB.body_markings_per_limb[zone] = choices
	return ..()

/// Put one native record on a draft without producing a paint transaction.
/datum/custom_sprite_base_marking_fixture/proc/put(datum/custom_sprite_editor/markings/editor, zone, index = 1, color = "#ff0000", emissive = FALSE)
	editor.workspace.markings_context[zone] = list(list("name" = names[index], "color" = color, "emissive" = emissive))

/// Native RGB sampling follows region ownership and does not copy body/custom paint or change draft state.
/datum/unit_test/custom_sprite_markings_base_copy/Run()
	var/datum/custom_sprite_base_marking_fixture/art = allocate(/datum/custom_sprite_base_marking_fixture)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	art.put(editor, BODY_ZONE_CHEST)
	art.put(editor, BODY_ZONE_L_ARM, 1, "#0000ff")
	art.put(editor, BODY_ZONE_PRECISE_L_HAND, 1, "#00ff00")
	editor.rebuild_resources()
	var/list/chest = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	editor.workspace.update_palette(list("#fe12ab"))
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#fe12abff", "points" = list(chest))), "The fixture custom paint must land on the chest.")
	var/before = json_encode(editor.workspace.layers[1]["data"])
	var/history = length(editor.workspace.undo_stack)
	var/palette = json_encode(editor.workspace.palette)
	var/revision = editor.draft_revision
	var/list/copied = editor.build_base_copy(list("request" = 1, "dir" = "2", "rect" = list(0, 0, 31, 31)))
	TEST_ASSERT(copied && length(copied["codes"]) == 1024, "A multi-region native base copy must succeed: [editor.transfer_error]")
	var/list/expected = list(BODY_ZONE_CHEST = "#ff0000ff", BODY_ZONE_L_ARM = "#0000ffff", BODY_ZONE_PRECISE_L_HAND = "#00ff00ff")
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			var/zone = custom_sprite_region_owner(editor.region_map["2"], editor.region_zones, x, y)
			var/code = copytext(copied["codes"], y * 32 + x + 1, y * 32 + x + 2)
			TEST_ASSERT_EQUAL(copied["palette"][findtext(CUSTOM_SPRITE_INDEX_ALPHABET, code)], expected[zone] || "#00000000", "Each canvas pixel may sample only its owning region's native marks, never skin or custom paint.")
	TEST_ASSERT(json_encode(editor.workspace.layers[1]["data"]) == before && length(editor.workspace.undo_stack) == history && json_encode(editor.workspace.palette) == palette && editor.draft_revision == revision, "Copy must not change authoritative pixels, history, palette or revision.")
	TEST_ASSERT(!length(preferences.custom_limb_markings), "Copy must not create saved drawings.")
	var/obj/item/bodypart/limb = editor.preview_body.get_bodypart(BODY_ZONE_CHEST)
	limb.markings_alpha = 96
	var/list/native = list()
	limb.append_base_marking_overlays(native)
	var/mutable_appearance/native_marking = native[1]
	TEST_ASSERT(length(native) == 1 && native_marking.alpha == 96 && native_marking.color == "#ff0000", "Default helper arguments must preserve native marking alpha and color.")
	var/list/sampled = list()
	limb.append_base_marking_overlays(sampled, BODY_ZONE_CHEST, FALSE, 255)
	var/mutable_appearance/sampled_marking = sampled[1]
	TEST_ASSERT(length(sampled) == 1 && sampled_marking.alpha == 255 && limb.markings_alpha == 96, "Sampling must neutralize only the returned appearance's alpha, leaving the limb untouched.")
	editor.finish(FALSE)

/// A marking copy survives deleting the native source and previews without admitting permanent colors.
/datum/unit_test/custom_sprite_markings_base_copy_paste/Run()
	var/datum/custom_sprite_base_marking_fixture/art = allocate(/datum/custom_sprite_base_marking_fixture)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	art.put(editor, BODY_ZONE_CHEST, 1, "#fe12ab")
	editor.rebuild_resources()
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	var/list/copied = editor.build_base_copy(list("request" = 1, "dir" = "2", "rect" = list(point[1], point[2], point[1], point[2])))
	TEST_ASSERT(copied, "The selected base marking pixel must copy.")
	TEST_ASSERT(editor.write_region_marking(BODY_ZONE_CHEST, 1, null, null), "The native source must be removable after copying.")
	editor.rebuild_resources()
	var/list/placement = custom_sprite_test_selection_placement(list(list(point[1], point[2], "#fe12abff")))
	placement["palette"] = list("#00000000", "#fe12abff")
	placement["baseCopy"] = copied["request"]
	placement["baseCopySource"] = copied["source"]
	editor.workspace.update_palette(list())
	var/original_palette = json_encode(editor.workspace.palette)
	var/original_frame = json_encode(editor.workspace.layers[1]["data"])
	var/history = length(editor.workspace.undo_stack)
	TEST_ASSERT(editor.queue_selection_preview(placement), "A copied marking must enter the normal deferred preview path.")
	editor.apply_selection_preview()
	TEST_ASSERT(editor.selection_frames && editor.selection_frames["2"][point[2] + 1][point[1] + 1] == "#fe12abff", "The temporary picture must include the copied color after removing its native source.")
	TEST_ASSERT(json_encode(editor.workspace.palette) == original_palette && json_encode(editor.workspace.layers[1]["data"]) == original_frame && length(editor.workspace.undo_stack) == history, "Trusted preview admission must be temporary and must not affect the draft or undo history.")
	placement["type"] = "move"
	TEST_ASSERT(editor.prepare_base_copy_paste(placement) && editor.workspace.new_transaction(deep_copy_list(placement)), "The base copy must paste through the existing validated move transaction.")
	var/pasted = json_encode(editor.workspace.layers[1]["data"])
	TEST_ASSERT(!length(editor.workspace.markings_context[BODY_ZONE_CHEST]), "Pasting must not restore native base records.")
	editor.workspace.undo()
	TEST_ASSERT_EQUAL(json_encode(editor.workspace.layers[1]["data"]), original_frame, "Undo must remove copied custom pixels.")
	editor.workspace.redo()
	TEST_ASSERT_EQUAL(json_encode(editor.workspace.layers[1]["data"]), pasted, "Redo must restore the exact copied pixels.")
	editor.finish(FALSE)

/// Wide canvases keep humanoid coordinates centered, and locked source regions are refused.
/datum/unit_test/custom_sprite_markings_base_copy_bounds/Run()
	var/datum/custom_sprite_base_marking_fixture/art = allocate(/datum/custom_sprite_base_marking_fixture)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/taur/wide = new(preferences, BODY_ZONE_CHEST)
	art.put(wide, BODY_ZONE_CHEST)
	wide.rebuild_resources()
	var/list/copied = wide.build_base_copy(list("request" = 1, "dir" = "2", "rect" = list(0, 0, 63, 31)))
	TEST_ASSERT(copied && copied["width"] == 64 && length(copied["codes"]) == 2048, "A taur body must use the supported wide copy envelope: [wide.transfer_error]")
	TEST_ASSERT(findtext(copied["codes"], "1"), "A wide body still copies its ordinary native chest markings.")
	for(var/y in 0 to 31)
		for(var/x in 0 to 63)
			var/zone = custom_sprite_region_owner(wide.region_map["2"], wide.region_zones, x, y)
			var/code = copytext(copied["codes"], y * 64 + x + 1, y * 64 + x + 2)
			TEST_ASSERT((zone == BODY_ZONE_CHEST) == (code != "0"), "The wide origin must agree with region ownership; taur organ art must stay out of the copy.")
	wide.finish(FALSE)
	var/datum/custom_sprite_editor/markings/unified_test/selection_locks/editor = new(preferences, BODY_ZONE_CHEST)
	art.put(editor, BODY_ZONE_CHEST)
	editor.rebuild_resources()
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	var/list/request = list("request" = 2, "dir" = "2", "rect" = list(point[1], point[2], point[1], point[2]), "mask" = list("1"))
	editor.test_region_locks = list(BODY_ZONE_CHEST = "Covered")
	TEST_ASSERT(!editor.build_base_copy(request) && editor.transfer_error, "A region covered since the request must not be sampled into the clipboard.")
	editor.test_region_locks = list()
	request["mask"] = list("0")
	copied = editor.build_base_copy(request)
	TEST_ASSERT(copied && copied["codes"] == repeat_string(1024, "0"), "Selection holes must stay empty across region boundaries.")
	art.put(editor, BODY_ZONE_CHEST, 1, "#0000ff")
	TEST_ASSERT(!editor.build_base_copy(request), "A base record changed before its resource rebuild must not use stale sampled pixels.")
	editor.finish(FALSE)

/// Appearance and palette limits fail closed rather than changing the persisted drawing representation.
/datum/unit_test/custom_sprite_markings_base_copy_limits/Run()
	var/datum/custom_sprite_base_marking_fixture/art = allocate(/datum/custom_sprite_base_marking_fixture)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/custom_sprite_editor/markings/unified_test/editor = new(preferences, BODY_ZONE_CHEST)
	var/list/point = custom_sprite_test_region_pixel(editor, BODY_ZONE_CHEST)
	var/list/request = list("request" = 1, "dir" = "2", "rect" = list(point[1], point[2], point[1], point[2]))
	art.put(editor, BODY_ZONE_CHEST, 3)
	editor.rebuild_resources()
	TEST_ASSERT(!editor.build_base_copy(request) && editor.transfer_error, "Intrinsic partial alpha cannot enter the opaque drawing format.")
	art.put(editor, BODY_ZONE_CHEST, 1)
	editor.workspace.markings_context[BODY_ZONE_CHEST] += list(list("name" = art.names[2], "color" = "#0000ff", "emissive" = FALSE))
	editor.rebuild_resources()
	var/obj/item/bodypart/limb = editor.preview_body.get_bodypart(BODY_ZONE_CHEST)
	limb.markings_alpha = 128
	TEST_ASSERT(!editor.build_base_copy(request) && editor.transfer_error, "Overlapping independently translucent base marks cannot be baked with altered coverage.")
	art.put(editor, BODY_ZONE_CHEST, 4)
	editor.rebuild_resources()
	var/list/blank = editor.build_base_copy(request)
	TEST_ASSERT(blank && blank["codes"] == repeat_string(1024, "0"), "Missing native states must not fall back to an unrelated opaque default state.")
	editor.finish(FALSE)
	TEST_ASSERT(custom_sprite_test_pool_colors(preferences, 70) == 70, "The palette fixture must retain more than 63 colors across valid individual regions.")
	editor = new(preferences, BODY_ZONE_CHEST)
	var/list/kept = editor.workspace.kept_colors()
	TEST_ASSERT(length(kept) == 70 && editor.base_copy_colors_fit(list(kept[1])), "Existing colors remain copyable when the combined regional pool exceeds 63.")
	TEST_ASSERT(!editor.base_copy_colors_fit(list("#abcdef")), "A full existing regional pool must not admit a new copy color.")
	var/list/empty_copy = editor.build_base_copy(list("request" = 2, "dir" = "2", "rect" = list(0, 0, 31, 31)))
	TEST_ASSERT(empty_copy, "An empty native layer remains copyable on an existing large regional palette.")
	var/list/colors = list()
	for(var/color in kept)
		colors += "[color]ff"
	var/list/codes = new /list(1024)
	for(var/index in 1 to length(codes))
		codes[index] = ".."
	var/placed = 0
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(placed >= length(kept) || custom_sprite_region_owner(editor.region_map["2"], editor.region_zones, x, y) != BODY_ZONE_CHEST)
				continue
			codes[y * 32 + x + 1] = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, round(placed / 64) + 1, round(placed / 64) + 2) + copytext(CUSTOM_SPRITE_INDEX_ALPHABET, (placed % 64) + 1, (placed % 64) + 2)
			placed++
	TEST_ASSERT(placed == 70, "The chest fixture needs enough owned pixels to test its independent save palette.")
	var/list/placement = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 31, 31), "palette" = colors, "digits" = 2, "codes" = jointext(codes, ""), "baseCopy" = empty_copy["request"], "baseCopySource" = empty_copy["source"])
	var/before = json_encode(editor.workspace.layers[1]["data"])
	var/palette_before = json_encode(editor.workspace.palette)
	TEST_ASSERT(!editor.prepare_base_copy_paste(placement) && editor.transfer_error, "Existing shared colors must still respect each destination region's 63-color save limit.")
	TEST_ASSERT(json_encode(editor.workspace.layers[1]["data"]) == before && json_encode(editor.workspace.palette) == palette_before, "A rejected regional placement must leave pixels and palette unchanged.")
	editor.finish(FALSE)
