/// The account the editor tests paint as. A ckey given to a mob comes back canonical, so it has no underscore.
#define GRAFFITI_EDITOR_TEST_CKEY "graffititest"

/**
 * Points the graffiti registry and libraries at the scratch directory, with the test account's library empty.
 */
/proc/graffiti_editor_test_begin()
	graffiti_registry_test_begin("data/graffiti_test/editor.json")
	graffiti_library_test_reset("data/graffiti_test/library/")
	SSgraffiti.libraries -= GRAFFITI_EDITOR_TEST_CKEY

/**
 * Puts a painter for the test account beside a wall, holding an uncapped spray can.
 *
 * Arguments:
 * - test: The test, which owns the painter and the can.
 * - wall: The wall to paint.
 *
 * Returns:
 * - list: The painter, whose ckey is the test account's, then the can.
 */
/proc/graffiti_editor_test_painter(datum/unit_test/test, turf/wall)
	var/mob/living/carbon/human/consistent/painter = test.allocate(/mob/living/carbon/human/consistent, get_step(wall, SOUTH))
	painter.ckey = GRAFFITI_EDITOR_TEST_CKEY
	var/obj/item/toy/crayon/spraycan/can = test.allocate(/obj/item/toy/crayon/spraycan)
	can.is_capped = FALSE
	painter.put_in_hands(can)
	return list(painter, can)

/**
 * Returns a one-pixel pencil stroke on the bottom layer's top row, as the editor's window sends it.
 *
 * Arguments:
 * - column: The pixel's column.
 *
 * Returns:
 * - list: The spriteEditorCommand action's params.
 */
/proc/graffiti_editor_test_stroke(column)
	return list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "layerId" = "l1", "dir" = "2", "color" = "#ff0000", "points" = list(list(column, 0))))

/**
 * Returns a one-pixel green paste on the bottom layer's top row, as the editor's window sends pasted paint it drops.
 *
 * Arguments:
 * - column: The pixel's column.
 *
 * Returns:
 * - list: The spriteEditorCommand action's params.
 */
/proc/graffiti_editor_test_paste(column)
	return list("command" = "transaction", "transaction" = list("type" = "move", "layer" = 1, "layerId" = "l1", "dir" = "2", "area" = list(column, 0, column, 0), "palette" = list("#00ff00"), "digits" = 1, "codes" = "0"))

/**
 * Ends the test account's graffiti editor, takes the test ckey back off its painter, and puts the registry, the library
 * directory and the account's library and cooldowns back.
 */
/proc/graffiti_editor_test_end()
	qdel(SSgraffiti.editors[GRAFFITI_EDITOR_TEST_CKEY])
	var/mob/painter = get_mob_by_ckey(GRAFFITI_EDITOR_TEST_CKEY)
	if(painter)
		painter.ckey = null
	GLOB.custom_style_transfers -= GRAFFITI_EDITOR_TEST_CKEY
	SSgraffiti.start_cooldowns -= GRAFFITI_EDITOR_TEST_CKEY
	SSgraffiti.libraries -= GRAFFITI_EDITOR_TEST_CKEY
	graffiti_registry_test_end()
	graffiti_library_test_reset(GRAFFITI_LIBRARY_DIRECTORY)

/**
 * A freehand session puts its piece on the wall at the first stroke and recomposites it at most once per
 * GRAFFITI_COMPOSITE_SPACING, strokes that waited for the stroke budget included, and refuses a paste.
 * Closing it charges the can once, leaves the paint, and keeps the unsaved piece as a freehand draft that resumes the
 * piece on that wall.
 */
/datum/unit_test/graffiti_editor_surface/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "Runtime Station must have a wall between two floors to paint.")
	var/turf/wall = turfs[1]
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	var/datum/custom_sprite_editor/graffiti/editor = graffiti_editor_for(painter, null, null, can, wall)
	var/datum/tgui/ui = allocate(/datum/tgui, painter, editor, "GraffitiEditor")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(3), ui, null)
	editor.run_deferred_work()
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(wall)
	TEST_ASSERT(decal && length(decal.stack) == 1, "The first stroke must put the piece on the wall.")
	TEST_ASSERT_EQUAL(graffiti_art_pixels(decal.render_cache["art"]), 1, "The wall must show the one painted pixel.")
	var/list/data = editor.ui_data(painter)
	TEST_ASSERT(istext(data["editorData"]["sprite"]["canvas"]["views"]?["2"]) && data["graffiti"]["kind"] == "surface", "The window must get the bottom layer's view and the session's fields.")
	var/list/background = editor.ui_static_data(painter)["graffitiBackground"]
	TEST_ASSERT(length(background) == 1 && isnull(background[1]), "The window must draw only older graffiti beneath the canvas, not the session's own piece.")
	var/key = decal.stack_key
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(4), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(decal.stack_key, key, "A stroke inside the composite spacing must wait for it.")
	COOLDOWN_RESET(editor, composite_cooldown)
	var/datum/custom_sprite_pace/pace = editor.pace()
	COOLDOWN_RESET(pace, spacing)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(graffiti_art_pixels(decal.render_cache["art"]), 2, "Once the spacing has passed, the wall must show the second stroke.")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_paste(6), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT(editor.workspace.layers[1]["data"]["2"][1][7] == "#00000000", "A surface session must refuse a paste.")
	// This second's stroke budget is spent, so the next stroke waits for the subsystem.
	COOLDOWN_START(pace, stroke_window, 1 SECONDS)
	pace.stroke_pixels = INFINITY
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(5), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "A stroke past the budget must wait.")
	editor.run_deferred_work()
	COOLDOWN_RESET(editor, composite_cooldown)
	COOLDOWN_RESET(pace, spacing)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(graffiti_art_pixels(decal.render_cache["art"]), 3, "A stroke that waited for the budget must reach the wall.")
	editor.ui_close(painter)
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST, "Ending the session must charge the can once.")
	TEST_ASSERT(!QDELETED(decal) && graffiti_tile_decal(wall) == decal, "The paint must stay on the wall.")
	var/datum/graffiti_library/library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	var/list/entry = library.unfinished_entry()
	TEST_ASSERT(entry?["progress"] == -1, "The unsaved piece must be kept as a freehand draft: [json_encode(entry)]")
	TEST_ASSERT_EQUAL(entry["resume"]["pid"], SSgraffiti.unpack(decal.stack[1])["pid"], "The draft must resume the piece on the wall.")
	TEST_ASSERT(QDELETED(editor) && !SSgraffiti.editors[GRAFFITI_EDITOR_TEST_CKEY], "Closing the window must end the session.")

/**
 * Puts the editor, the registry and the library back.
 */
/datum/unit_test/graffiti_editor_surface/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A freehand session that ends without paint on the wall leaves nothing: no graffiti, no charge and no Unfinished piece,
 * while a session with paint cannot clear it before closing.
 */
/datum/unit_test/graffiti_editor_empty_session/Run()
	graffiti_editor_test_begin()
	var/datum/graffiti_library/library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "Runtime Station must have a wall between two floors to paint.")
	var/turf/wall = turfs[1]
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	var/datum/custom_sprite_editor/graffiti/editor = graffiti_editor_for(painter, null, null, can, wall)
	editor.ui_close(painter)
	TEST_ASSERT_NULL(graffiti_tile_decal(wall), "A session without a stroke must leave the wall alone.")
	TEST_ASSERT_EQUAL(can.charges_left, charges, "A session without a stroke must not charge the can.")
	TEST_ASSERT_NULL(library.unfinished_entry(), "A session without a stroke must keep no Unfinished piece.")
	editor = graffiti_editor_for(painter, null, null, can, wall)
	var/datum/tgui/ui = allocate(/datum/tgui, painter, editor, "GraffitiEditor")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(3), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT(graffiti_tile_decal(wall), "The stroke must reach the wall.")
	editor.ui_act("clear", list("dir" = "2", "layer" = "l1"), ui, null)
	editor.ui_close(painter)
	TEST_ASSERT(graffiti_tile_decal(wall), "Freehand paint must stay after a clear request and closing the window.")
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST, "The freehand paint left on the wall must charge the can.")
	// Looked up again: a session ending while its owner has no client unloads the library, so the next one loads it anew.
	library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	TEST_ASSERT(library.unfinished_entry(), "Freehand paint must remain available as an Unfinished piece.")

/**
 * Puts the editor, the registry and the library back.
 */
/datum/unit_test/graffiti_editor_empty_session/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A studio session saves into the account's library. Save makes a piece and then saves over it, but not twice within
 * a second; Save as copy makes a second piece and edits it from then on; a piece widened to two tiles saves one tile
 * wide until its right tile has paint, then wide.
 */
/datum/unit_test/graffiti_editor_studio_save/Run()
	graffiti_editor_test_begin()
	var/mob/living/carbon/human/consistent/painter = allocate(/mob/living/carbon/human/consistent)
	painter.ckey = GRAFFITI_EDITOR_TEST_CKEY
	var/datum/custom_sprite_editor/graffiti/editor = graffiti_editor_for(painter, null, null, null, null)
	var/datum/tgui/ui = allocate(/datum/tgui, painter, editor, "GraffitiEditor")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(3), ui, null)
	editor.ui_act("save", list(), ui, null)
	var/datum/graffiti_library/library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	var/id = editor.piece_id
	TEST_ASSERT((id in library.pieces) && length(library.pieces) == 1, "Save must make one library piece: [id]")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(4), ui, null)
	editor.ui_act("save", list(), ui, null)
	TEST_ASSERT_EQUAL(graffiti_art_pixels(library.pieces[id]["thumb"]), 1, "A second save within a second must wait.")
	GLOB.custom_style_transfers -= GRAFFITI_EDITOR_TEST_CKEY
	editor.ui_act("save", list(), ui, null)
	TEST_ASSERT(editor.piece_id == id && length(library.pieces) == 1, "Save must write over the piece it made.")
	TEST_ASSERT_EQUAL(graffiti_art_pixels(library.pieces[id]["thumb"]), 2, "The saved piece must hold both strokes.")
	GLOB.custom_style_transfers -= GRAFFITI_EDITOR_TEST_CKEY
	editor.ui_act("saveAs", list(), ui, null)
	TEST_ASSERT(editor.piece_id != id && (editor.piece_id in library.pieces) && length(library.pieces) == 2, "Save as copy must make a second piece and edit it from then on.")
	GLOB.custom_style_transfers -= GRAFFITI_EDITOR_TEST_CKEY
	editor.ui_act("setWidth", list("width" = GRAFFITI_WIDE_WIDTH), ui, null)
	// Saved now, it would match the last save and write nothing, so the piece a save writes is read directly.
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = editor.workspace
	TEST_ASSERT(canvas.width == GRAFFITI_WIDE_WIDTH && canvas.serialize_piece(editor.piece_name, editor.piece_desc)["width"] == GRAFFITI_WIDTH, "A piece widened to two tiles with nothing on the right one must save one tile wide: the canvas is [canvas.width] wide.")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(40), ui, null)
	editor.ui_act("save", list(), ui, null)
	TEST_ASSERT_EQUAL(library.piece(editor.piece_id)["width"], GRAFFITI_WIDE_WIDTH, "A piece widened to two tiles must save two tiles wide once the right one has paint.")
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_paste(6), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(editor.workspace.layers[1]["data"]["2"][1][7], "#00ff00ff", "A studio session must take a paste.")

/**
 * Puts the editor and the library back.
 */
/datum/unit_test/graffiti_editor_studio_save/Destroy()
	graffiti_editor_test_end()
	return ..()

/// Freehand cannot erase or undo paint, including through selection cutting or layer removal.
/datum/unit_test/graffiti_editor_permanent_paint/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "Runtime Station must have a wall to paint.")
	var/turf/wall = turfs[1]
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/datum/custom_sprite_editor/graffiti/editor = graffiti_editor_for(painter, null, null, can, wall)
	var/datum/tgui/ui = allocate(/datum/tgui, painter, editor, "GraffitiEditor")
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = editor.workspace
	editor.ui_act("spriteEditorCommand", graffiti_editor_test_stroke(3), ui, null)
	editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(1)[1][4], "#ff0000ff", "Freehand undo must leave the stroke painted.")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "eraser", "layer" = 1, "layerId" = "l1", "dir" = "2", "points" = list(list(3, 0)))), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(1)[1][4], "#ff0000ff", "Freehand eraser requests must leave the stroke painted.")
	editor.ui_act("clear", list("dir" = "2", "layer" = "l1"), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(1)[1][4], "#ff0000ff", "Freehand clear requests must leave the stroke painted.")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "move", "layer" = 1, "layerId" = "l1", "dir" = "2", "area" = list(3, 0, 3, 0), "palette" = list("#00000000"), "digits" = 1, "codes" = "0")), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(1)[1][4], "#ff0000ff", "Freehand selection cutting must leave the stroke painted.")
	editor.ui_act("layerAdd", list(), ui, null)
	editor.ui_act("layerRemove", list("id" = "l1"), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_count(), 2, "A freehand layer cannot be removed.")
	TEST_ASSERT_EQUAL(canvas.layer_view(1)[1][4], "#ff0000ff", "Removing a layer must not erase freehand paint.")
	TEST_ASSERT(!(canvas.tool_flags & (SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_SELECT)), "Freehand must not offer erasing or selection tools.")
	var/datum/custom_sprite_pace/pace = editor.pace()
	COOLDOWN_RESET(pace, stroke_window)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "bucket", "layer" = 2, "layerId" = "l2", "dir" = "2", "color" = "#00ff00", "point" = list(0, 0))), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(2)[1][1], "#00ff00ff", "Freehand must still allow fill.")
	TEST_ASSERT_EQUAL(pace.stroke_pixels, GRAFFITI_WIDTH * GRAFFITI_HEIGHT, "A freehand fill must charge every painted pixel against its stroke budget.")
	editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 100), ui, null)
	TEST_ASSERT_EQUAL(canvas.layer_view(2)[1][1], "#00ff00ff", "Freehand fills cannot be undone.")

/datum/unit_test/graffiti_editor_permanent_paint/Destroy()
	graffiti_editor_test_end()
	return ..()

/// Keep saves the Unfinished piece without creating an editor or changing the spray can's tab.
/datum/unit_test/graffiti_keep_without_editor/Run()
	graffiti_editor_test_begin()
	var/mob/living/carbon/human/consistent/painter = allocate(/mob/living/carbon/human/consistent)
	painter.ckey = GRAFFITI_EDITOR_TEST_CKEY
	var/obj/item/toy/crayon/spraycan/can = allocate(/obj/item/toy/crayon/spraycan)
	painter.put_in_hands(can)
	can.graffiti_tab = "graffiti"
	can.graffiti_armed = "unfinished"
	var/datum/graffiti_library/library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	library.set_unfinished(graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH)), null)
	GLOB.custom_style_transfers -= GRAFFITI_EDITOR_TEST_CKEY
	var/datum/tgui/ui = allocate(/datum/tgui, painter, can, "Crayon")
	can.ui_act("graffitiKeep", list(), ui, null)
	TEST_ASSERT_EQUAL(length(library.pieces), 1, "Keep must save one library piece.")
	TEST_ASSERT_NULL(library.unfinished, "Keep must clear the Unfinished slot.")
	TEST_ASSERT_NULL(can.graffiti_armed, "Keep must disarm the Unfinished piece.")
	TEST_ASSERT_NULL(SSgraffiti.editors[GRAFFITI_EDITOR_TEST_CKEY], "Keep must not open an editor.")
	TEST_ASSERT_EQUAL(can.graffiti_tab, "graffiti", "Keep must stay on Custom Graffiti.")

/datum/unit_test/graffiti_keep_without_editor/Destroy()
	graffiti_editor_test_end()
	return ..()

/// A full tile refuses a fresh freehand session or saved piece before opening a window or spending paint.
/datum/unit_test/graffiti_full_surface_refused/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "Runtime Station must have a wall to paint.")
	var/turf/wall = turfs[1]
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/datum/graffiti_library/library = graffiti_library(GRAFFITI_EDITOR_TEST_CKEY)
	var/id = library.save_piece(graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH)))
	for(var/index in 1 to GRAFFITI_STACK_CAP)
		SSgraffiti.add_placement(wall, graffiti_test_art(index), GRAFFITI_EDITOR_TEST_CKEY, "Painter")
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(wall)
	var/before = json_encode(decal.stack)
	var/charges = can.charges_left
	for(var/armed in list("freehand", id))
		can.graffiti_armed = armed
		SSgraffiti.start_cooldowns -= GRAFFITI_EDITOR_TEST_CKEY
		TEST_ASSERT_EQUAL(can.use_on(decal, painter, list()), ITEM_INTERACT_BLOCKING, "A full tile must immediately refuse [armed].")
		TEST_ASSERT_NULL(SSgraffiti.editors[GRAFFITI_EDITOR_TEST_CKEY], "A full tile must not open the editor.")
		TEST_ASSERT_NULL(SSgraffiti.paint_jobs[GRAFFITI_EDITOR_TEST_CKEY], "A full tile must not start a paint job.")
		TEST_ASSERT_EQUAL(can.graffiti_armed, armed, "The refused can must remain armed for another surface.")
	TEST_ASSERT_EQUAL(can.charges_left, charges, "Refused paint must cost no charges.")
	TEST_ASSERT_EQUAL(json_encode(decal.stack), before, "Refused paint must preserve every existing piece.")
	TEST_ASSERT(!graffiti_surface_full(wall, decal.stack[1]), "Resuming an existing placement must need no extra slot.")

/datum/unit_test/graffiti_full_surface_refused/Destroy()
	graffiti_editor_test_end()
	return ..()

#undef GRAFFITI_EDITOR_TEST_CKEY
