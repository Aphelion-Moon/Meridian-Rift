/// A selection the window placed itself (pasted, turned or cut to a mask) arrives as its final pixels and applies as one undoable step.
/datum/unit_test/custom_sprite_selection_placement/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000"), list("2" = list(0, 0, 3, 3)))
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "points" = list(list(0, 0)))), "The fixture needs paint to lift")
	// Lift the paint at 0,0 and place red at 2,1, and at 5,5, which is outside the drawing area. Dots keep a pixel.
	var/codes = "0.......1...[repeat_string(18, ".")].....1"
	var/list/placement = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 5, 5), "palette" = list("#00000000", "#ff0000ff"), "digits" = 1, "codes" = codes)
	TEST_ASSERT(workspace.new_transaction(placement), "A placed selection should apply")
	var/list/frame = workspace.get_first_layer_pixel_data()
	TEST_ASSERT_EQUAL(frame[1][1], "#00000000", "Lifted paint should leave its old place")
	TEST_ASSERT_EQUAL(frame[2][3], "#ff0000ff", "Placed paint should land where it was dropped")
	TEST_ASSERT_EQUAL(frame[6][6], "#00000000", "Paint dropped outside the drawing area should be cut")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), 2, "The placement should be one history step")
	workspace.undo()
	frame = workspace.get_first_layer_pixel_data()
	TEST_ASSERT(frame[1][1] == "#ff0000ff" && frame[2][3] == "#00000000", "Undo should put the lifted paint back")
	placement["codes"] = "0"
	TEST_ASSERT(!workspace.new_transaction(placement), "A placement whose codes don't fill its area should be refused")
