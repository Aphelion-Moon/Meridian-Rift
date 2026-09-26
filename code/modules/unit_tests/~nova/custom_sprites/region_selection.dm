/// A front-view pixel of `upper` right above a pixel of `lower`, as list(x, y) of the upper one, or null.
/proc/custom_sprite_test_region_seam(datum/custom_sprite_editor/markings/editor, upper, lower)
	var/upper_index = "[editor.region_zones.Find(upper)]"
	var/lower_index = "[editor.region_zones.Find(lower)]"
	var/list/rows = editor.region_map["2"]
	for(var/y in 1 to 31)
		for(var/x in 1 to 32)
			if(copytext(rows[y], x, x + 1) == upper_index && copytext(rows[y + 1], x, x + 1) == lower_index)
				return list(x - 1, y - 1)
	return null

/// Whether saving would change a region, and the front preview as it stands after a refresh.
/datum/unit_test/custom_sprite_region_selection/proc/state(datum/custom_sprite_editor/markings/editor)
	var/list/results = editor.region_results()
	editor.refresh_preview(push = FALSE)
	return list(!!results[BODY_ZONE_R_ARM]["changed"], !!results[BODY_ZONE_PRECISE_R_HAND]["changed"], editor.preview_urls["2"])

/// Selections moved or placed across two regions change both, and the preview follows them through undo and redo.
/datum/unit_test/custom_sprite_region_selection/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/markings/unified_test/editor = allocate(/datum/custom_sprite_editor/markings/unified_test, preferences, BODY_ZONE_R_ARM)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor")
	var/list/seam = custom_sprite_test_region_seam(editor, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND)
	TEST_ASSERT(seam, "The front view should have a right arm pixel right above a right hand pixel")
	var/x = seam[1]
	var/y = seam[2]
	var/color = "[editor.workspace.palette[1]]ff"
	var/list/untouched = state(editor)
	TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = color, "points" = list(list(x, y)))), "The arm pixel should take paint")
	var/list/on_arm = state(editor)
	TEST_ASSERT(on_arm[1] && !on_arm[2] && on_arm[3] != untouched[3], "Only the arm should change, and the preview with it")
	// Moved down a pixel, the paint leaves the arm for the hand.
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "move", "layer" = 1, "dir" = "2", "rect" = list(x, y, x, y), "offset" = list(0, 1))), ui, null), "The move should reach the canvas")
	var/list/on_hand = state(editor)
	TEST_ASSERT(!on_hand[1] && on_hand[2] && on_hand[3] != on_arm[3], "The move should change both regions, and the preview with them")
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null), "Undo should reach the canvas")
	TEST_ASSERT(json_encode(state(editor)) == json_encode(on_arm), "Undoing the move should put the paint and the preview back on the arm")
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "redo", "count" = 1), ui, null), "Redo should reach the canvas")
	TEST_ASSERT(json_encode(state(editor)) == json_encode(on_hand), "Redoing the move should put the paint and the preview back on the hand")
	// A placed selection, such as a paste or a dropped float, paints both regions at once.
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(x, y, x, y + 1), "palette" = list(color, "#00000000"), "digits" = 1, "codes" = "01")), ui, null), "The placement should reach the canvas")
	var/list/placed = state(editor)
	TEST_ASSERT(placed[1] && !placed[2] && placed[3] != on_hand[3], "The placement should change both regions, and the preview with them")
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null), "Undo should reach the canvas")
	TEST_ASSERT(json_encode(state(editor)) == json_encode(on_hand), "Undoing the placement should restore both regions and the preview")
