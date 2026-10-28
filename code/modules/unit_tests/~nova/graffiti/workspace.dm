/// Layers are added up to GRAFFITI_MAX_LAYERS, swapped as an undoable step and removed down to one, every layer is named by its id, and a width change keeps each layer and its paint in place.
/datum/unit_test/graffiti_workspace_layers/Run()
	var/list/piece = list("name" = "Tag", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("1[repeat_string(1023, "0")]", 1, 1024)),
	))
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite/graffiti, piece)
	TEST_ASSERT(workspace.layer_count() == 1 && workspace.layer_view(1)[1][1] == "#ff0000ff", "A one-layer piece must open as one layer with its paint.")
	for(var/index in 2 to GRAFFITI_MAX_LAYERS)
		TEST_ASSERT_EQUAL(workspace.add_layer(), index, "A new layer must go on top.")
	TEST_ASSERT_EQUAL(workspace.add_layer(), 0, "A layer past GRAFFITI_MAX_LAYERS must be refused.")
	TEST_ASSERT(workspace.move_layer(1, 1) && workspace.layers[1]["id"] == "l2" && workspace.layers[2]["id"] == "l1", "Moving the bottom layer up must swap it with the layer above.")
	workspace.undo()
	TEST_ASSERT(workspace.layers[1]["id"] == "l1" && workspace.layers[2]["id"] == "l2", "Undo must swap the layers back.")
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 3, "layerId" = "l3", "dir" = "2", "color" = "#00ff00ff", "points" = list(list(5, 5)))) && workspace.layer_view(3)[6][6] == "#00ff00ff", "A stroke naming layer 3 by its id must land on it.")
	TEST_ASSERT(!workspace.stroke_layer_matches(list("layer" = 1, "layerId" = "l2")) && !workspace.stroke_layer_matches(list("layer" = 1)), "A stroke must name the bottom layer by its id, as any other.")
	TEST_ASSERT(!workspace.set_width(48), "Only one- and two-tile widths may be set.")
	TEST_ASSERT(workspace.set_width(GRAFFITI_WIDE_WIDTH), "Widening must be taken.")
	for(var/index in 1 to GRAFFITI_MAX_LAYERS)
		var/list/frame = workspace.layer_view(index)
		TEST_ASSERT(workspace.layers[index]["id"] == "l[index]" && length(frame) == GRAFFITI_HEIGHT && length(frame[1]) == GRAFFITI_WIDE_WIDTH && length(frame[GRAFFITI_HEIGHT]) == GRAFFITI_WIDE_WIDTH, "Widening must keep layer [index] and make every row [GRAFFITI_WIDE_WIDTH] pixels long.")
	TEST_ASSERT(workspace.layer_view(1)[1][1] == "#ff0000ff" && workspace.layer_view(3)[6][6] == "#00ff00ff", "Widening must leave paint where it was.")
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 2, "layerId" = "l2", "dir" = "2", "color" = "#00ff00ff", "points" = list(list(40, 0)))) && workspace.has_paint_right_half(), "A wide canvas must take paint at x = 40.")
	TEST_ASSERT(workspace.set_width(GRAFFITI_WIDTH), "Narrowing must be taken.")
	TEST_ASSERT(!workspace.can_transact(list("type" = "pencil", "layer" = 2, "dir" = "2", "color" = "#00ff00ff", "points" = list(list(40, 0)))), "A narrow canvas must refuse paint at x = 40.")
	for(var/index in GRAFFITI_MAX_LAYERS to 2 step -1)
		TEST_ASSERT(workspace.remove_layer(index), "Layer [index] must be removable.")
	TEST_ASSERT(!workspace.remove_layer(1), "The last layer must stay.")

/**
 * Whether a graffiti workspace's colour counts hold what its layers do, read pixel by pixel.
 *
 * Arguments:
 * - workspace: The workspace.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_test_counts_match(datum/sprite_editor_workspace/custom_sprite/graffiti/workspace)
	var/list/expected = list()
	for(var/index in 1 to workspace.layer_count())
		for(var/list/row as anything in workspace.layer_view(index))
			for(var/pixel in row)
				if(pixel != "#00000000")
					expected[pixel] += 1
	if(length(expected) != length(workspace.color_counts))
		return FALSE
	for(var/pixel, count in expected)
		if(workspace.color_counts[pixel] != count)
			return FALSE
	return TRUE

/**
 * Translucent paint is taken and saved with its alpha in a canonical piece, and malformed colours are refused. The pixels
 * of each colour stay counted through a width change, strokes, a fill, an erasure, a placement, undo and redo, and the
 * 63-colour gate reads those counts: a 64th colour waits until undo takes one away, and paint that shows nothing is never
 * taken. The layers flattened straight from their frames, as a live composite flattens them, give the art of the piece
 * they serialize to.
 */
/datum/unit_test/graffiti_workspace_colors/Run()
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite/graffiti, null)
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#39ff1480", "points" = list(list(0, 0)))), "A translucent stroke must be taken.")
	var/list/saved = workspace.serialize_piece("Glow", "")
	TEST_ASSERT(saved && ("#39ff1480" in saved["palette"]), "The piece must keep the translucent colour with its alpha: [json_encode(saved)]")
	TEST_ASSERT_EQUAL(json_encode(graffiti_validate_piece(json_decode(graffiti_encode_piece(saved)))), json_encode(saved), "A saved piece must be canonical: importing its export must change nothing.")
	for(var/bad in list("#ggggggg", "#12345", "#1234567890"))
		TEST_ASSERT_NULL(workspace.add_color(bad), "Accepted the malformed colour [bad].")
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/counted = allocate(/datum/sprite_editor_workspace/custom_sprite/graffiti, graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH)))
	counted.set_width(GRAFFITI_WIDE_WIDTH)
	counted.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#0000ff", "points" = list(list(0, 0), list(40, 3))))
	counted.new_transaction(list("type" = "bucket", "layer" = 2, "layerId" = "l2", "dir" = "2", "color" = "#00ff0080", "point" = list(63, 31)))
	counted.new_transaction(list("type" = "eraser", "layer" = 1, "layerId" = "l1", "dir" = "2", "points" = list(list(0, 0), list(1, 0))))
	counted.new_transaction(list("type" = "move", "layer" = 1, "layerId" = "l1", "dir" = "2", "area" = list(10, 10, 11, 10), "palette" = list("#ffff00", "#00000000"), "digits" = 1, "codes" = "01"))
	counted.undo(2)
	counted.redo()
	TEST_ASSERT(graffiti_test_counts_match(counted), "The colour counts must match the layers after strokes, a fill, an erasure, a placement, undo and redo: [json_encode(counted.color_counts)]")
	TEST_ASSERT_EQUAL(graffiti_art_hash(graffiti_flatten_records(counted.layer_records(), counted.width)), graffiti_art_hash(graffiti_flatten(counted.serialize_piece("Counted", ""))), "The frames must flatten to the art of the piece they serialize to.")
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/full = allocate(/datum/sprite_editor_workspace/custom_sprite/graffiti, null)
	for(var/shade in 1 to GRAFFITI_MAX_COLORS)
		full.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = rgb(shade, 0, 0), "points" = list(list(shade % GRAFFITI_WIDTH, round(shade / GRAFFITI_WIDTH)))))
	var/refused = !full.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#0000ff", "points" = list(list(0, 5))))
	full.undo()
	var/taken = full.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#0000ff", "points" = list(list(0, 5))))
	// On a workspace of one colour, far below the cap, only its alpha can refuse it.
	var/hidden = !workspace.new_transaction(list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#ff000000", "points" = list(list(1, 5))))
	TEST_ASSERT(refused && taken && hidden, "At [GRAFFITI_MAX_COLORS] colours a new one must wait until undo frees one, and a colour with no alpha must never paint: refused [refused], taken [taken], hidden [hidden].")
