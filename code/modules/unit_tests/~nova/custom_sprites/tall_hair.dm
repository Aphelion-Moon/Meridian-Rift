/// Runs the hair editor's actions without a connected client.
/datum/custom_sprite_editor/tall_hair_test/can_edit(mob/user)
	return !closing

/// A 32 by 48 hair drawing with one pixel painted, in every view. Rows count down from the top.
/proc/custom_sprite_tall_hair_test_drawing(x, y, color = "#123456")
	var/grid = "[repeat_string(y * 32 + x, "0")]1[repeat_string(32 * 48 - (y * 32 + x) - 1, "0")]"
	var/list/dirs = list()
	for(var/direction in GLOB.custom_style_directions)
		dirs[direction] = custom_sprite_encode_grid(grid, 1, 32 * 48)
	return list("version" = 4, "palette" = list(color), "tint" = "#ffffff", "dirs" = dirs, "emissive" = custom_sprite_emissive_settings(FALSE))

/// Tall drawings have 16 more rows than normal ones and round-trip; drawings made before them keep their 32 by 32 canvas.
/datum/unit_test/custom_sprite_tall_hair_codec/Run()
	var/list/tall = custom_sprite_validate(custom_sprite_tall_hair_test_drawing(3, 2))
	TEST_ASSERT(tall, "A 32 by 48 drawing should validate")
	TEST_ASSERT_EQUAL(tall["version"], 4, "A tall drawing should stay tall")
	TEST_ASSERT_EQUAL(copytext(custom_sprite_decode_grid(tall["dirs"]["2"], 1, 32 * 48), 2 * 32 + 4, 2 * 32 + 5), "1", "The tall drawing's pixels should survive the round trip")
	var/icon/tall_icon = custom_sprite_paint_icon(tall, FALSE)
	TEST_ASSERT_EQUAL(tall_icon.Height(), 48, "A tall drawing should render 48 rows")
	var/list/old = custom_sprite_validate(list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = custom_sprite_encode_grid("1[repeat_string(1023, "0")]", 1))))
	TEST_ASSERT_EQUAL(old["version"], 1, "An old drawing should keep its version")
	var/icon/old_icon = custom_sprite_paint_icon(old, FALSE)
	TEST_ASSERT(old_icon.Height() == 32 && old_icon.Width() == 32, "An old drawing should still render 32 by 32")

/// Custom hair over Bald (Tall Canvas) gets 48 rows; paint in the extra rows saves tall, paint below them saves as before.
/datum/unit_test/custom_sprite_tall_hair_editor/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference/hairstyle = GLOB.preference_entries[/datum/preference/choiced/hairstyle]
	TEST_ASSERT(preferences.write_preference(hairstyle, "Bald (Tall Canvas)"), "The tall slot should be a hairstyle to pick")
	var/datum/custom_sprite_editor/tall_hair_test/editor = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
	TEST_ASSERT_EQUAL(editor.workspace.height, 48, "The tall slot should open a 48-row canvas")
	var/brush = "[editor.workspace.palette[1]]ff"
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = brush, "points" = list(list(5, 47)))), "The bottom row should be paintable")
	TEST_ASSERT_EQUAL(editor.workspace.serialize_drawing()["version"], 1, "Paint below the extra rows should save as a normal drawing")
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = brush, "points" = list(list(5, 0)))), "The top row should be paintable")
	TEST_ASSERT_EQUAL(editor.workspace.serialize_drawing()["version"], 4, "Paint in the extra rows should save as a tall drawing")
	// Choosing a normal base style for drawing keeps the usual canvas.
	TEST_ASSERT(preferences.write_preference(hairstyle, "Bald"), "Bald should be a hairstyle to pick")
	var/datum/custom_sprite_editor/tall_hair_test/normal = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
	TEST_ASSERT_EQUAL(normal.workspace.height, 32, "A normal base style should keep the 32-row canvas")
	// Picking the tall slot in the editor grows the canvas upward, keeping the paint where it sits on the head.
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, normal, "CustomHairEditor")
	TEST_ASSERT(normal.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[normal.workspace.palette[1]]ff", "points" = list(list(5, 31)))), "The normal canvas should take paint")
	TEST_ASSERT(normal.ui_act("setHairStyle", list("style" = "Bald (Tall Canvas)"), ui, null), "The editor should switch to the tall slot")
	TEST_ASSERT_EQUAL(normal.workspace.height, 48, "Switching to the tall slot should grow the canvas")
	var/list/grown = normal.workspace.get_first_layer_pixel_data()
	TEST_ASSERT(!endswith(grown[48][6], "00"), "The paint should keep its place above the body")
	TEST_ASSERT(normal.ui_act("setHairStyle", list("style" = "Bald"), ui, null), "The editor should switch back")
	TEST_ASSERT_EQUAL(normal.workspace.height, 32, "Paint that fits should go back to the normal canvas")

/// Tall drawings belong to hair on the tall canvas: facial hair and a normal hair canvas refuse them.
/datum/unit_test/custom_sprite_tall_hair_import/Run()
	var/list/beard = list("style" = "Shaved", "color" = "#000000", "gradient_style" = SPRITE_ACCESSORY_NONE, "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)
	var/list/facial_result = custom_style_validate_package(list("format" = "aphelion-custom-style", "version" = 1, "target" = "facial_hair", "zone" = null, "drawing" = custom_sprite_tall_hair_test_drawing(3, 2), "hair" = beard))
	TEST_ASSERT(findtext(facial_result["error"], "Tall drawings"), "A tall facial hair drawing should be refused by name: [facial_result["error"]]")
	var/list/hair = list("style" = "Bald (Tall Canvas)", "color" = "#000000", "gradient_style" = SPRITE_ACCESSORY_NONE, "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)
	var/list/result = custom_style_validate_package(list("format" = "aphelion-custom-style", "version" = 1, "target" = "hair", "zone" = null, "drawing" = custom_sprite_tall_hair_test_drawing(3, 2), "hair" = hair))
	TEST_ASSERT(result["package"], "A tall hair style should validate: [result["error"]]")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	var/datum/custom_sprite_editor/tall_hair_test/editor = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
	TEST_ASSERT(findtext(editor.candidate_problem(result["package"]), "tall"), "A normal canvas should refuse tall paint and say it needs the tall canvas")

/// A tall drawing renders its extra rows above the head.
/datum/unit_test/custom_sprite_tall_hair_render/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.set_hairstyle("Bald (Tall Canvas)", update = FALSE)
	human.dna.custom_hair = custom_sprite_tall_hair_test_drawing(16, 2)
	human.sync_custom_sprite_appearance()
	human.update_hair()
	var/icon/flat = getFlatIcon(new /mutable_appearance(human.appearance), defdir = SOUTH, no_anim = TRUE, clip_bounds = list(1, 1, 32, 48))
	TEST_ASSERT_EQUAL(LOWER_TEXT(flat.GetPixel(17, 46)), "#123456", "Paint in the extra rows should show above the head")

/// A 32 by 32 hair drawing painted in every view, once in its top row and once in its bottom row.
/proc/custom_sprite_tall_hair_test_short_drawing()
	var/grid = "[repeat_string(3, "0")]1[repeat_string(995, "0")]1[repeat_string(24, "0")]"
	var/list/dirs = list()
	for(var/direction in GLOB.custom_style_directions)
		dirs[direction] = custom_sprite_encode_grid(grid, 1)
	return list("version" = 1, "palette" = list("#123456"), "tint" = "#ffffff", "dirs" = dirs, "emissive" = custom_sprite_emissive_settings(FALSE))

/// Imports and restorations give the canvas the height their base style asks for at once, placing short paint as picking that style does.
/datum/unit_test/custom_sprite_tall_hair_candidates/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference/hairstyle = GLOB.preference_entries[/datum/preference/choiced/hairstyle]
	preferences.write_preference(hairstyle, "Bald")
	var/list/short = custom_sprite_tall_hair_test_short_drawing()
	// A short drawing under a normal style keeps the normal canvas.
	var/datum/custom_sprite_editor/tall_hair_test/normal = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
	var/datum/tgui/normal_ui = allocate(/datum/tgui, mock_client.mob, normal, "CustomHairEditor")
	var/list/bald = normal.workspace.hair_context.Copy()
	TEST_ASSERT(confirm(normal, normal_ui, custom_style_package("hair", null, short, bald), "import"), "A short style should import: [normal.transfer_error]")
	TEST_ASSERT_EQUAL(normal.workspace.height, 32, "A short drawing under a normal style should keep the normal canvas")
	var/normal_frames = json_encode(normal.workspace.layers[1]["data"])
	var/normal_save = json_encode(normal.workspace.serialize_drawing())
	// Picking the tall slot shows where the short paint belongs on the tall canvas.
	TEST_ASSERT(normal.ui_act("setHairStyle", list("style" = CUSTOM_SPRITE_TALL_HAIRSTYLE), normal_ui, null), "The editor should switch to the tall slot")
	var/picked_frames = json_encode(normal.workspace.layers[1]["data"])
	var/list/tall = normal.workspace.hair_context.Copy()
	for(var/source in list("import", "restore"))
		var/datum/custom_sprite_editor/tall_hair_test/editor = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
		var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
		TEST_ASSERT(confirm(editor, ui, custom_style_package("hair", null, short, tall), source), "A short style over the tall slot should [source]: [editor.transfer_error]")
		TEST_ASSERT_EQUAL(editor.workspace.height, 48, "The [source] should grow the canvas without the style being picked again")
		TEST_ASSERT(json_encode(editor.workspace.layers[1]["data"]) == picked_frames, "The [source] should place the short paint where picking the tall slot does")
		TEST_ASSERT(json_encode(editor.workspace.serialize_drawing()) == normal_save, "Short paint on the grown canvas should save exactly as it does on a normal one")
		TEST_ASSERT(length(editor.workspace.unsaved_rotations()), "Saving after the [source] should still keep the replaced style as the previous one")
	// Under a normal style again, short paint shrinks a tall canvas back, as picking that style does.
	preferences.write_preference(hairstyle, CUSTOM_SPRITE_TALL_HAIRSTYLE)
	var/datum/custom_sprite_editor/tall_hair_test/shrinking = allocate(/datum/custom_sprite_editor/tall_hair_test, preferences, "hair")
	var/datum/tgui/shrinking_ui = allocate(/datum/tgui, mock_client.mob, shrinking, "CustomHairEditor")
	TEST_ASSERT_EQUAL(shrinking.workspace.height, 48, "The tall slot should open a 48-row canvas")
	TEST_ASSERT(confirm(shrinking, shrinking_ui, custom_style_package("hair", null, short, bald), "import"), "A short style under a normal style should import: [shrinking.transfer_error]")
	TEST_ASSERT_EQUAL(shrinking.workspace.height, 32, "A short drawing under a normal style should shrink a tall canvas")
	TEST_ASSERT(json_encode(shrinking.workspace.layers[1]["data"]) == normal_frames, "The short paint should sit where it does on a normal canvas")

/// Shows a package as an import or a restoration of the previous saved style does, then confirms it. Returns whether it applied.
/datum/unit_test/custom_sprite_tall_hair_candidates/proc/confirm(datum/custom_sprite_editor/editor, datum/tgui/ui, list/package, source)
	if(source == "restore")
		editor.preferences.custom_style_previous = list("hair" = package)
		editor.ui_act("restorePrevious", list(), ui, null)
	else
		editor.show_candidate(package, "import")
	return editor.candidate && editor.ui_act("confirmCandidate", list(), ui, null) && !editor.transfer_error
