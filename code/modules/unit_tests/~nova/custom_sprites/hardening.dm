/// A whole-body editor that runs actions without a connected client.
/datum/custom_sprite_editor/markings/hardening_test

/// Acts without a connected client.
/datum/custom_sprite_editor/markings/hardening_test/can_edit(mob/user)
	return !closing

/// A hair editor that runs actions without a connected client.
/datum/custom_sprite_editor/hardening_test/can_edit(mob/user)
	return !closing

/// Counts the saves that reach the character's files.
/datum/preferences/preferences_import_test/hardening_commits
	/// Saves written so far.
	var/commits = 0

/// Counts saves.
/datum/preferences/preferences_import_test/hardening_commits/commit_custom_styles(list/packages, slot, list/rotate_keys, reject_pending_hair = FALSE, reject_pending_markings = FALSE)
	commits++
	return ..()

/// Shared setup for the editor hardening tests.
/datum/unit_test/custom_sprite_hardening
	abstract_type = /datum/unit_test/custom_sprite_hardening

/// A whole-body editor on a pinned character of `species`, and its window.
/datum/unit_test/custom_sprite_hardening/proc/whole_body_editor(species = SPECIES_HUMAN)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], species)
	var/datum/custom_sprite_editor/markings/hardening_test/editor = allocate(/datum/custom_sprite_editor/markings/hardening_test, preferences, BODY_ZONE_CHEST)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	return list(editor, allocate(/datum/tgui, mock_client.mob, editor, "CustomMarkingsEditor"))

/// Every canvas pixel a region owns in one view, as list(x, y) entries.
/datum/unit_test/custom_sprite_hardening/proc/region_pixels(datum/custom_sprite_editor/markings/editor, zone, direction = "2")
	. = list()
	var/index = "[editor.region_zones.Find(zone)]"
	var/list/rows = editor.region_map[direction]
	for(var/y in 1 to length(rows))
		for(var/x in 1 to length(rows[y]))
			if(copytext(rows[y], x, x + 1) == index)
				. += list(list(x - 1, y - 1))

/// One undo or redo action takes at most a handful of steps, whatever count a hostile window sends.
/datum/unit_test/custom_sprite_hardening/history_jump/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	var/cap = custom_sprite_history_jump(1e9)
	TEST_ASSERT(cap >= 1 && cap < 100, "The history jump cap must be a handful of steps: [cap]")
	var/list/torso = region_pixels(editor, BODY_ZONE_CHEST)
	var/list/point = torso[1]
	for(var/i in 1 to cap + 5)
		var/color = editor.workspace.palette[(i % 2) + 1]
		editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[color]ff", "points" = list(point)))
	var/steps = length(editor.workspace.undo_stack)
	editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1e9), ui, null)
	TEST_ASSERT_EQUAL(length(editor.workspace.undo_stack), steps - cap, "One undo action must go back at most [cap] steps.")
	editor.ui_act("spriteEditorCommand", list("command" = "redo", "count" = 1e9), ui, null)
	TEST_ASSERT_EQUAL(length(editor.workspace.undo_stack), steps, "One redo action must go forward at most [cap] steps.")

/// Saving a draft that hasn't changed since its last save writes nothing, while a changed draft is written again.
/datum/unit_test/custom_sprite_hardening/unchanged_save/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences_import_test/hardening_commits/preferences = allocate(/datum/preferences/preferences_import_test/hardening_commits, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.workspace.update_palette(list("#ffffff"))
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(3, 3)))), ui, null), "The fixture stroke must be taken.")
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT_EQUAL(preferences.commits, 1, "The first save must write the drawing.")
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT_EQUAL(preferences.commits, 1, "Saving an unchanged draft again must write nothing.")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(4, 3)))), ui, null)
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT_EQUAL(preferences.commits, 2, "A changed draft must be saved again.")

/// A stroke sent as a compact mask paints exactly the pixels it marks, and a malformed mask is refused without painting.
/datum/unit_test/custom_sprite_hardening/stroke_mask/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	var/list/torso = region_pixels(editor, BODY_ZONE_CHEST)
	var/list/stroke = torso.Copy(1, min(length(torso), 40) + 1)
	var/mask = custom_sprite_hardening_mask(stroke, editor.workspace.width, editor.workspace.height)
	var/color = "[editor.workspace.palette[1]]ff"
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = color, "mask" = mask)), ui, null), "A masked stroke must be taken.")
	var/list/frame = editor.workspace.layers[1]["data"]["2"]
	var/list/transaction = editor.workspace.last_transaction()
	TEST_ASSERT_EQUAL(length(transaction["points"]), length(stroke), "A masked stroke must paint exactly the pixels it marks.")
	for(var/list/point as anything in stroke)
		TEST_ASSERT_EQUAL(frame[point[2] + 1][point[1] + 1], color, "A masked stroke must paint every pixel it marks.")
	var/steps = length(editor.workspace.undo_stack)
	for(var/bad in list("zz", copytext(mask, 2), "[copytext(mask, 1, length(mask))]!", 5))
		editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = color, "mask" = bad)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.workspace.undo_stack), steps, "A malformed mask must be refused.")

/// A placement can't bring more values than pixels it covers, and a value it repeats stands for the same colour each time.
/datum/unit_test/custom_sprite_hardening/placement_values/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000"), list("2" = list(0, 0, 7, 3)))
	var/list/repeated = list()
	for(var/i in 1 to 16)
		repeated += list("#FF0000FF", "#00000000")
	var/list/crowded = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 3, 3), "palette" = repeated.Copy(), "digits" = 1, "codes" = repeat_string(16, "0"))
	TEST_ASSERT(!workspace.new_transaction(crowded), "A placement with more values than pixels should be refused")
	// Value 30 repeats value 0, and value 31 is transparent.
	var/list/roomy = list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 7, 3), "palette" = repeated.Copy(), "digits" = 1, "codes" = "[repeat_string(30, "0")]uv")
	TEST_ASSERT(workspace.new_transaction(roomy), "A placement that repeats values should apply")
	var/list/frame = workspace.get_first_layer_pixel_data()
	TEST_ASSERT_EQUAL(frame[1][1], "#ff0000ff", "A value should paint its colour")
	TEST_ASSERT_EQUAL(frame[4][7], "#ff0000ff", "A repeated value should paint the same colour")
	TEST_ASSERT_EQUAL(frame[4][8], "#00000000", "A transparent value should leave the pixel clear")
	var/list/bad = repeated.Copy()
	bad[31] = "#zzzzzzff"
	bad[1] = "#zzzzzzff"
	var/steps = length(workspace.undo_stack)
	TEST_ASSERT(!workspace.new_transaction(list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 7, 3), "palette" = bad, "digits" = 1, "codes" = repeat_string(32, "1"))), "A placement with an invalid value should be refused, however often it repeats")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps, "A refused placement should leave the history alone")

/// Colours only the undo or redo history still needs stay kept, so history can't bring back a colour the palette dropped.
/datum/unit_test/custom_sprite_hardening/kept_colors/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#00ff00", "#0000ff"), list("2" = list(0, 0, 31, 31)))
	var/list/row = list()
	for(var/x in 0 to 9)
		row += list(list(x, 0))
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "points" = deep_copy_list(row))), "The red stroke should be taken")
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#00ff00ff", "points" = deep_copy_list(row))), "The green stroke over it should be taken")
	TEST_ASSERT(workspace.new_transaction(list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 7, 0), "palette" = list("#00000000", "#0000ffff"), "digits" = 1, "codes" = "01010101")), "The placement should be taken")
	var/list/imported = custom_sprite_validate(list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = custom_sprite_encode_grid("1[repeat_string(1023, "0")]", 1))))
	TEST_ASSERT(workspace.replace_drawing(imported, null, "Import style"), "The imported drawing should replace the draft")
	TEST_ASSERT(workspace.clear_direction("2"), "Clearing the view should be taken")
	TEST_ASSERT(("#ff0000" in workspace.kept_colors()), "Red only survives in the history, which must keep it")
	for(var/undo in 1 to 5)
		workspace.undo()
	var/list/kept = workspace.kept_colors()
	for(var/color in list("#ff0000", "#00ff00", "#0000ff", "#123456"))
		TEST_ASSERT((color in kept), "Undone steps must keep [color], which redoing them puts back")

/// A placement undone and waiting to be redone keeps its colours: a palette refresh meanwhile leaves them paintable, and the redone paint's swatch is listed.
/datum/unit_test/custom_sprite_hardening/redo_keeps_placed_colors/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#123456"), list("2" = list(0, 0, 7, 3)))
	TEST_ASSERT(("#123456" in workspace.palette), "The fixture colour should start paintable")
	TEST_ASSERT(workspace.new_transaction(list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, 1, 0), "palette" = list("#123456ff"), "digits" = 1, "codes" = "00")), "The placement should apply")
	workspace.undo()
	// Only the undone placement uses the colour now.
	workspace.update_palette(list("#ff0000"))
	TEST_ASSERT(("#123456" in workspace.kept_colors()), "An undone placement's colour should stay kept")
	TEST_ASSERT(("#123456" in workspace.palette), "A palette refresh should keep an undone placement's colour")
	workspace.redo()
	var/list/frame = workspace.get_first_layer_pixel_data()
	TEST_ASSERT_EQUAL(frame[1][1], "#123456ff", "Redo should put the placed colour back")
	TEST_ASSERT(("#123456" in workspace.palette), "The palette should list the colour a redone placement shows")

/// A stroke over `points` as the window's compact mask.
/proc/custom_sprite_hardening_mask(list/points, width, height)
	var/list/cells = list()
	for(var/i in 1 to CEILING(width * height / 6, 1))
		cells += 0
	for(var/list/point as anything in points)
		var/position = point[2] * width + point[1]
		cells[round(position / 6) + 1] |= (1 << (position % 6))
	var/list/mask = list()
	for(var/value in cells)
		mask += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, value + 1, value + 2)
	return jointext(mask, "")

/// Every pixel of a canvas, row by row.
/proc/custom_sprite_hardening_all_points(width, height)
	. = list()
	for(var/y in 0 to height - 1)
		for(var/x in 0 to width - 1)
			. += list(list(x, y))

/// A flood of strokes past the budget queues only so many and refuses the rest, and every queued stroke still applies, in order, in the background.
/datum/unit_test/custom_sprite_hardening/stroke_budget/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	var/list/colors = list("#ff0000", "#00ff00")
	workspace.update_palette(colors + "#0000ff")
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#0000ffff", "mask" = mask)), ui, null), "The first stroke fits the budget")
	// As if this second's budget were spent: every stroke after it waits.
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	var/queued = 0
	var/last_color
	for(var/i in 1 to 1000)
		var/color = colors[(i % 2) + 1]
		editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[color]ff", "mask" = mask)), ui, null)
		if(length(editor.stroke_queue) == queued)
			break
		queued = length(editor.stroke_queue)
		last_color = color
	TEST_ASSERT(queued && queued < 1000, "A flood of strokes must queue a bounded number and refuse the rest: [queued] queued")
	var/fires = 0
	while(length(editor.stroke_queue) && fires < 100)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT(!length(editor.stroke_queue), "The queue must drain in the background")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "[last_color]ff", "Queued strokes must all apply, in the order they were sent")

/// A whole-canvas placement of `color` on every other pixel, offset by `index`, as the window sends a paste that covers the canvas.
/proc/custom_sprite_hardening_placement(datum/sprite_editor_workspace/custom_sprite/workspace, color, index)
	var/list/codes = list()
	for(var/i in 1 to workspace.width * workspace.height)
		codes += (i + index) % 2 ? "0" : "1"
	return list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, workspace.width - 1, workspace.height - 1), "palette" = list("#00000000", "[color]ff"), "digits" = 1, "codes" = jointext(codes, ""))

/// Whole-canvas placements can't grow the undo history without bound: the oldest steps go, and every kept step still undoes and redoes exactly.
/datum/unit_test/custom_sprite_hardening/history_points_cap/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#00ff00"), list("2" = list(0, 0, 31, 47)), null, null, 48)
	TEST_ASSERT_EQUAL(workspace.height, 48, "The fixture needs the tall canvas")
	var/list/colors = list("#ff0000", "#00ff00")
	for(var/i in 1 to 60)
		TEST_ASSERT(workspace.new_transaction(custom_sprite_hardening_placement(workspace, colors[(i % 2) + 1], i)), "Placement [i] should be taken")
	var/kept = length(workspace.undo_stack)
	TEST_ASSERT(kept && kept < 60, "Whole-canvas steps must evict the oldest once their recorded pixels pass the cap: [kept] kept")
	var/after_all = json_encode(workspace.layers[1]["data"]["2"])
	workspace.undo(kept)
	TEST_ASSERT(!length(workspace.undo_stack) && length(workspace.redo_stack) == kept, "Every kept step must undo")
	var/list/frame = workspace.layers[1]["data"]["2"]
	TEST_ASSERT(!endswith(frame[1][1], "00") || !endswith(frame[1][2], "00"), "Undoing past the cut leaves the evicted steps' paint, which can't be undone")
	workspace.redo(kept)
	TEST_ASSERT_EQUAL(json_encode(workspace.layers[1]["data"]["2"]), after_all, "Redoing every kept step must restore the canvas exactly")

/// While strokes over the budget wait, anything but more strokes is ignored and saving waits for them, so history and saves keep their order.
/datum/unit_test/custom_sprite_hardening/stroke_queue_order/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(list("#ff0000", "#00ff00"))
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "mask" = mask)), ui, null), "The first stroke fits the budget")
	var/steps = length(workspace.undo_stack)
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#00ff00ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "A stroke over the budget waits")
	editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null)
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps, "An undo sent while a stroke waits must be ignored")
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT(isnull(preferences.custom_hair), "A save sent while a stroke waits is ignored rather than saving without it")
	editor.finish(TRUE)
	TEST_ASSERT(!QDELETED(editor) && editor.save_error, "Saving and closing waits for the strokes rather than dropping them")
	var/fires = 0
	while(length(editor.stroke_queue) && fires < 10)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + 1, "The waiting stroke lands after the ones before it")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "#00ff00ff", "The waiting stroke paints last")
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null), "Once the strokes are in, undo works again")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "#ff0000ff", "Undo takes back the stroke that waited, the last one drawn")
	editor.finish(TRUE)
	TEST_ASSERT(QDELETED(editor) && preferences.custom_hair, "Saving and closing works once the strokes are in")

/// Closing the window while strokes wait keeps them: they still go into the kept draft in the background.
/datum/unit_test/custom_sprite_hardening/stroke_queue_close/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(list("#ff0000", "#00ff00"))
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "mask" = mask)), ui, null)
	var/steps = length(workspace.undo_stack)
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#00ff00ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "A stroke over the budget waits")
	editor.ui_close(mock_client.mob)
	TEST_ASSERT((editor in SScustom_sprite_work.queue) && length(editor.stroke_queue), "Closing the window keeps the waiting stroke queued")
	var/fires = 0
	while(length(editor.stroke_queue) && fires < 10)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + 1, "The waiting stroke goes into the kept draft")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "#00ff00ff", "The kept draft shows the stroke that waited")

/// Preferences going away while strokes wait save them too: they go in first, and the editor closes rather than outliving its preferences.
/datum/unit_test/custom_sprite_hardening/stroke_queue_teardown/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(list("#ff0000", "#00ff00"))
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "mask" = mask)), ui, null)
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#00ff00ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "A stroke over the budget waits")
	qdel(preferences)
	TEST_ASSERT(QDELETED(editor), "The editor closes with its preferences")
	TEST_ASSERT(("#00ff00" in preferences.custom_hair?["palette"]) && !("#ff0000" in preferences.custom_hair?["palette"]), "The save has the stroke that waited, painted over the one before it")

/// A rebuild split over two fires ends exactly where a rebuild in one go does, with the same paintable mask and region map.
/datum/unit_test/custom_sprite_hardening/rebuild_two_fires/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	// A twin on the same character, rebuilt in one go, is the reference.
	var/datum/custom_sprite_editor/markings/hardening_test/twin = allocate(/datum/custom_sprite_editor/markings/hardening_test, editor.preferences, BODY_ZONE_CHEST)
	TEST_ASSERT(editor.ui_act("toggleParts", list(), ui, null), "Toggling parts must update the window.")
	twin.hide_parts = editor.hide_parts
	twin.rebuild_resources()
	var/old_body = REF(editor.preview_body)
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work(), "The first fire builds the body and keeps the editor queued.")
	TEST_ASSERT(editor.pending_body && REF(editor.preview_body) == old_body, "The new body waits beside the old one.")
	TEST_ASSERT(editor.run_deferred_work(), "The second fire finishes the rebuild.")
	TEST_ASSERT(!editor.pending_body && REF(editor.preview_body) != old_body, "The new body is in use and nothing is pending.")
	TEST_ASSERT_EQUAL(json_encode(editor.workspace.draw_mask), json_encode(twin.workspace.draw_mask), "The split rebuild's paintable mask must match a single rebuild's.")
	TEST_ASSERT_EQUAL(json_encode(editor.region_map), json_encode(twin.region_map), "The split rebuild's region map must match a single rebuild's.")

/// A fill is charged every pixel it filled, so a hostile window can't pass the stroke budget with whole-canvas fills at one pixel each.
/datum/unit_test/custom_sprite_hardening/stroke_bucket_budget/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	editor.workspace.update_palette(list("#ff0000"))
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "bucket", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "point" = list(0, 0))), ui, null), "A whole-canvas fill must apply inside its action")
	var/filled = length(editor.workspace.last_transaction()["points"])
	var/datum/custom_sprite_pace/pace = editor.pace()
	TEST_ASSERT(filled > 1 && pace.stroke_pixels == filled, "A fill must be charged every pixel it filled, not one: [filled] filled, [pace.stroke_pixels] charged")
