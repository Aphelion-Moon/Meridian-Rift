/// Counts every guide and preview the editor draws and every resource rebuild, and runs actions without a connected client.
/datum/custom_sprite_editor/markings/hardening_test
	/// Guides and previews drawn so far.
	var/renders = 0
	/// Resource rebuilds so far.
	var/rebuilds = 0

/// Acts without a connected client.
/datum/custom_sprite_editor/markings/hardening_test/can_edit(mob/user)
	return !closing

/// Counts guides drawn.
/datum/custom_sprite_editor/markings/hardening_test/render_guide(direction)
	. = ..()
	if(.)
		renders++

/// Counts previews drawn.
/datum/custom_sprite_editor/markings/hardening_test/render_preview(direction)
	. = ..()
	if(.)
		renders++

/// Counts rebuilds.
/datum/custom_sprite_editor/markings/hardening_test/rebuild_resources(reuse_body = FALSE)
	rebuilds++
	return ..()

/// A hair editor that runs actions without a connected client.
/datum/custom_sprite_editor/hardening_test/can_edit(mob/user)
	return !closing

/// Counts the base hairstyle changes that reach the draft.
/datum/custom_sprite_editor/hardening_test/hair_changes
	/// Hairstyle changes applied so far.
	var/changes = 0

/// Counts a change reaching the draft.
/datum/custom_sprite_editor/hardening_test/hair_changes/apply_hair_context(list/hair, name)
	changes++
	return ..()

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

/// Paints every pixel of every region in one view, a different colour per row, as one stroke per row.
/datum/unit_test/custom_sprite_hardening/proc/paint_view(datum/custom_sprite_editor/markings/editor, direction)
	var/list/rows_by_y = list()
	for(var/zone in editor.region_zones)
		for(var/list/point as anything in region_pixels(editor, zone, direction))
			LAZYADD(rows_by_y["[point[2]]"], list(point))
	var/index = 0
	for(var/y, points in rows_by_y)
		var/color = editor.workspace.palette[(index++ % length(editor.workspace.palette)) + 1]
		editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = direction, "color" = "[color]ff", "points" = points))

/// Whether two GetPixel() results are the same colour, allowing a step of rounding in any channel.
/datum/unit_test/custom_sprite_hardening/proc/same_pixel(first, second)
	if(first == second)
		return TRUE
	var/list/first_rgba = first ? rgb2num(first) : list(0, 0, 0, 0)
	var/list/second_rgba = second ? rgb2num(second) : list(0, 0, 0, 0)
	if(length(first_rgba) < 4)
		first_rgba += 255
	if(length(second_rgba) < 4)
		second_rgba += 255
	for(var/channel in 1 to 4)
		if(abs(first_rgba[channel] - second_rgba[channel]) > 1)
			return FALSE
	return TRUE

/// View changes never draw inside the action: a burst of them draws only the view it ends on, once.
/datum/unit_test/custom_sprite_hardening/view_burst/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	var/list/torso = region_pixels(editor, BODY_ZONE_CHEST)
	var/list/point = torso[1]
	TEST_ASSERT(editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[editor.workspace.palette[1]]ff", "points" = list(point))), ui, null), "A stroke on the torso must be taken.")
	deltimer(editor.preview_timer)
	editor.request_refresh()
	editor.run_deferred_work()
	editor.renders = 0
	for(var/i in 1 to 3)
		for(var/direction in list("4", "1", "8", "2", "4"))
			editor.ui_act("setView", list("dir" = direction), ui, null)
	TEST_ASSERT_EQUAL(editor.renders, 0, "View changes must not draw anything inside the action.")
	TEST_ASSERT_EQUAL(editor.visible_direction, "4", "The editor must follow the view the window ends on.")
	editor.run_deferred_work()
	TEST_ASSERT(editor.renders <= 2, "A burst of view changes must draw only the final view's guide and preview, not [editor.renders] pictures.")
	TEST_ASSERT(!editor.stale_previews["4"] && !editor.stale_guides["4"], "The final view must be drawn.")
	var/drawn = editor.renders
	editor.ui_act("setView", list("dir" = "2"), ui, null)
	editor.ui_act("setView", list("dir" = "4"), ui, null)
	editor.run_deferred_work()
	TEST_ASSERT_EQUAL(editor.renders, drawn, "Views drawn since the last change must be shown again without drawing.")

/// Changes that rebuild resources apply at once, but rebuild once per burst, spaced out.
/datum/unit_test/custom_sprite_hardening/rebuild_burst/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	editor.rebuilds = 0
	var/hide_parts = editor.hide_parts
	for(var/i in 1 to 5)
		TEST_ASSERT(editor.ui_act("toggleParts", list(), ui, null), "Toggling parts must update the window.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 0, "Toggles must not rebuild inside the action.")
	TEST_ASSERT_EQUAL(editor.hide_parts, !hide_parts, "The toggle state must follow every action at once.")
	TEST_ASSERT(!editor.run_deferred_work(), "The first rebuild after a quiet spell builds its body first.")
	TEST_ASSERT(editor.run_deferred_work(), "The next fire renders it.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "A burst of toggles must rebuild once.")
	editor.ui_act("toggleUnderwear", list(), ui, null)
	TEST_ASSERT(!editor.run_deferred_work(), "A rebuild right after another must wait for the spacing.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "A spaced-out rebuild must not run early.")
	TEST_ASSERT(editor in SScustom_sprite_work.queue, "Waiting work must stay queued.")
	// As if the spacing had passed.
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work() && editor.pending_body, "Queued work builds its body once the spacing has passed.")
	TEST_ASSERT(editor.run_deferred_work(), "And renders on the fire after.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 2, "The waiting rebuild must run.")

/// One undo or redo action takes at most a handful of steps, whatever count a window sends.
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

/// A previous saved style is previewed only as the player's pace allows, and never while a preview waits for an answer.
/datum/unit_test/custom_sprite_hardening/restore_guard/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], /datum/sprite_accessory/hair/bedhead::name)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/drawing = list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = "f1[repeat_string(1023, "0")]"), "emissive" = custom_sprite_emissive_settings(FALSE))
	preferences.custom_style_previous = list("hair" = custom_style_package("hair", null, drawing, editor.workspace.hair_context.Copy()))
	editor.update_restorable()
	TEST_ASSERT(editor.ui_act("restorePrevious", list(), ui, null), "Restoring the previous style must preview it.")
	var/list/shown = editor.candidate
	TEST_ASSERT(shown, "The previous style must wait for confirmation.")
	editor.ui_act("restorePrevious", list(), ui, null)
	TEST_ASSERT(editor.candidate == shown, "A second restore must not replace the preview waiting for an answer.")
	editor.ui_act("cancelCandidate", list(), ui, null)
	editor.ui_act("restorePrevious", list(), ui, null)
	TEST_ASSERT(!editor.candidate, "Restoring again straight away must wait for the spacing.")
	TEST_ASSERT(editor.transfer_notice, "A restore that has to wait must say so.")
	COOLDOWN_RESET(preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(editor.ui_act("restorePrevious", list(), ui, null) && editor.candidate, "Restoring must work again once the spacing has passed.")

/// Saving a draft that hasn't changed since its last save writes nothing, but is still acknowledged.
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
	var/acknowledged = editor.save_revision
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT_EQUAL(preferences.commits, 1, "Saving an unchanged draft again must write nothing.")
	TEST_ASSERT_EQUAL(editor.save_revision, acknowledged + 1, "Saving an unchanged draft must still be acknowledged.")
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ffffffff", "points" = list(list(4, 3)))), ui, null)
	editor.ui_act("saveDraft", list(), ui, null)
	TEST_ASSERT_EQUAL(preferences.commits, 2, "A changed draft must be saved again.")

/// Four species, every view painted and flattened twice: the slowest custom sprite test.
/datum/unit_test/custom_sprite_hardening/composed_previews
	priority = TEST_LONGER

/// Composed previews show exactly what flattening the painted body shows, for bodies with parts, wings, tails and translucent paint.
/datum/unit_test/custom_sprite_hardening/composed_previews/Run()
	for(var/species in list(SPECIES_HUMAN, SPECIES_LIZARD, SPECIES_MOTH, SPECIES_SLIMESTART))
		var/list/opened = whole_body_editor(species)
		var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
		for(var/direction in GLOB.custom_style_directions)
			paint_view(editor, direction)
		editor.refresh_preview(push = FALSE)
		TEST_ASSERT(editor.preview_composed, "A [species] body's previews must be composed.")
		var/mutable_appearance/painted = editor.capture_region_previews(editor.region_results())
		for(var/direction in GLOB.custom_style_directions)
			var/icon/expected = custom_sprite_flat_icon(painted, text2num(direction))
			var/icon/composed = editor.composed_view(direction)
			var/mismatch
			for(var/y in 1 to 32)
				for(var/x in 1 to 32)
					if(!mismatch && !same_pixel(expected.GetPixel(x, y), composed.GetPixel(x, y)))
						mismatch = "[x],[y]: [expected.GetPixel(x, y)] vs [composed.GetPixel(x, y)]"
			TEST_ASSERT(!mismatch, "A [species] body's composed [GLOB.custom_style_direction_labels[direction]] preview must match the flattened body, first difference at [mismatch].")

/// Character setup builds at most one new editor per spacing; an open that comes sooner waits, then happens by itself.
/datum/unit_test/custom_sprite_hardening/open_spacing/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!middleware.open_deferred("hair", null, user), "The first new editor must open at once.")
	TEST_ASSERT(middleware.open_deferred("facial_hair", null, user), "Another new editor straight after must wait for the spacing.")
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	TEST_ASSERT(!middleware.open_deferred("hair", null, user), "An editor that already exists must open at once.")

/// Costly work comes a moment apart for a short burst, then one piece per refill while it keeps coming, and the burst comes back after a quiet spell.
/datum/unit_test/custom_sprite_hardening/pace_burst/Run()
	var/datum/custom_sprite_pace/pace = allocate(/datum/custom_sprite_pace)
	TEST_ASSERT(pace.due(), "A fresh pace must allow work at once.")
	pace.start()
	TEST_ASSERT(!pace.due(), "Work straight after other work must wait.")
	var/shortest = pace.time_left()
	TEST_ASSERT(shortest > 0 && shortest <= 1 SECONDS, "Work within the burst must wait only a moment: [shortest]")
	var/burst = 1
	// As if each wait had just passed.
	pace.spacing = world.time
	while(pace.due() && burst < 100)
		pace.start()
		burst++
		pace.spacing = world.time
	TEST_ASSERT(burst >= 2 && burst <= 10, "A few pieces in a row must run at the shortest spacing: [burst]")
	var/wait = pace.time_left()
	TEST_ASSERT(wait > shortest && wait <= 3 SECONDS, "Once the burst is used, work must wait a little longer, not for good: [wait]")
	// As if that wait had passed: one more piece, then waiting again.
	pace.refilled_at -= wait
	TEST_ASSERT(pace.due(), "A piece must come back once the wait has passed.")
	pace.start()
	pace.spacing = world.time
	TEST_ASSERT(!pace.due(), "Work that keeps coming must keep waiting a refill per piece.")
	// As if the player had stopped for a good while.
	pace.refilled_at = world.time - 1 MINUTES
	var/after_quiet = 0
	while(pace.due() && after_quiet < 100)
		pace.start()
		after_quiet++
		pace.spacing = world.time
	TEST_ASSERT_EQUAL(after_quiet, burst, "A quiet spell must bring the whole burst back.")

/// A stroke sent as a compact mask paints exactly the pixels it marks, and a malformed mask is refused without painting.
/datum/unit_test/custom_sprite_hardening/stroke_mask/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	var/list/torso = region_pixels(editor, BODY_ZONE_CHEST)
	var/list/stroke = torso.Copy(1, min(length(torso), 40) + 1)
	var/width = editor.workspace.width
	var/list/cells = list()
	for(var/i in 1 to CEILING(width * editor.workspace.height / 6, 1))
		cells += 0
	for(var/list/point as anything in stroke)
		var/position = point[2] * width + point[1]
		cells[round(position / 6) + 1] |= (1 << (position % 6))
	var/mask = ""
	for(var/value in cells)
		mask += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, value + 1, value + 2)
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

/// The colours a history keeps, read from every step pixel by pixel: what each step paints over, and what a move or placement puts down.
/proc/custom_sprite_hardening_read_history(datum/sprite_editor_workspace/custom_sprite/workspace)
	. = workspace.used_colors()
	var/list/seen = list()
	for(var/list/stack as anything in list(workspace.undo_stack, workspace.redo_stack))
		for(var/list/transaction as anything in stack)
			var/color = transaction["color"]
			if(color && !seen[color])
				seen[color] = TRUE
				. |= LOWER_TEXT(copytext(color, 1, 8))
			for(var/list/point as anything in transaction["points"])
				for(var/point_color in transaction["type"] == "move" ? list(point[3], point[4]) : list(point[3]))
					if(seen[point_color])
						continue
					seen[point_color] = TRUE
					if(!endswith(point_color, "00"))
						. |= LOWER_TEXT(copytext(point_color, 1, 8))
			for(var/_direction, points in transaction["replaced"])
				for(var/list/point as anything in points)
					for(var/replaced_color in list(point[3], point[4]))
						if(seen[replaced_color])
							continue
						seen[replaced_color] = TRUE
						if(!endswith(replaced_color, "00"))
							. |= LOWER_TEXT(copytext(replaced_color, 1, 8))

/// Each history step remembers its own colours, and the kept colours come out the same, in the same order, as reading every step pixel by pixel.
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
	for(var/step in list("taken", "undo", "undo", "redo", "undo", "undo", "undo", "undo"))
		switch(step)
			if("undo")
				workspace.undo()
			if("redo")
				workspace.redo()
		var/expected = json_encode(custom_sprite_hardening_read_history(workspace))
		TEST_ASSERT_EQUAL(json_encode(workspace.kept_colors()), expected, "Kept colours after [step] should match reading the history pixel by pixel")
		TEST_ASSERT_EQUAL(json_encode(workspace.kept_colors()), expected, "Kept colours asked for again after [step] should come out the same")

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

/datum/unit_test/custom_sprite_hardening/hairstyle_burst
	priority = TEST_LONGER

/// Base hairstyle changes: one applies at once, and a burst of them ends on the style picked last, applied once more, while the window shows it all along.
/datum/unit_test/custom_sprite_hardening/hairstyle_burst/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], /datum/sprite_accessory/hair/bedhead::name)
	var/datum/custom_sprite_editor/hardening_test/hair_changes/editor = allocate(/datum/custom_sprite_editor/hardening_test/hair_changes, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/styles = list()
	for(var/style in editor.available_hairstyles())
		if(length(styles) >= 10)
			break
		var/list/hair = editor.workspace.hair_context.Copy()
		if(style == hair["style"] || style == CUSTOM_SPRITE_TALL_HAIRSTYLE)
			continue
		hair["style"] = style
		if(!editor.hair_context_problem(hair))
			styles += style
	TEST_ASSERT_EQUAL(length(styles), 10, "The fixture needs ten hairstyles to pick")
	TEST_ASSERT(editor.ui_act("setHairStyle", list("style" = styles[1]), ui, null), "Picking a hairstyle should update the window")
	TEST_ASSERT_EQUAL(editor.workspace.hair_context["style"], styles[1], "A single change should apply at once")
	for(var/i in 2 to 10)
		editor.ui_act("setHairStyle", list("style" = styles[i]), ui, null)
		var/list/data = editor.ui_data(null)
		TEST_ASSERT_EQUAL(data["hairStyle"], styles[i], "The window should show the style picked last")
	// As long as the window takes to end.
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(editor.workspace.hair_context["style"], styles[10], "A burst should end on the style picked last")
	TEST_ASSERT(editor.changes <= 2, "A burst of ten changes should apply at most the first and the last, not [editor.changes]")

/// A hair editor that counts every picture it publishes, candidate previews included.
/datum/custom_sprite_editor/hardening_test/publishing
	/// Pictures published so far.
	var/published = 0

/datum/custom_sprite_editor/hardening_test/publishing/publish_icon(icon/rendered)
	published++
	return ..()

/// Restore previous shows its card at once and draws the previews in the background; the same style again comes from the cache.
/datum/unit_test/custom_sprite_hardening/candidate_previews/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], /datum/sprite_accessory/hair/bedhead::name)
	var/datum/custom_sprite_editor/hardening_test/publishing/editor = allocate(/datum/custom_sprite_editor/hardening_test/publishing, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/drawing = list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = "f1[repeat_string(1023, "0")]"), "emissive" = custom_sprite_emissive_settings(FALSE))
	preferences.custom_style_previous = list("hair" = custom_style_package("hair", null, drawing, editor.workspace.hair_context.Copy()))
	editor.update_restorable()
	var/published = editor.published
	TEST_ASSERT(editor.ui_act("restorePrevious", list(), ui, null), "Restoring must show the card at once.")
	TEST_ASSERT(editor.candidate && isnull(editor.candidate["previews"]), "The card is recorded before its previews are drawn.")
	TEST_ASSERT_EQUAL(editor.published, published, "The action itself must draw nothing.")
	TEST_ASSERT(editor.pending_work, "The previews must be queued for the subsystem.")
	TEST_ASSERT(editor.run_deferred_work(), "One fire must draw the previews.")
	TEST_ASSERT_EQUAL(length(editor.candidate?["previews"]), 4, "The previews must arrive after one fire.")
	TEST_ASSERT_EQUAL(editor.published, published + 5, "One fire draws the four views once, then the draft's own view again, as showing a candidate always has.")
	TEST_ASSERT(editor.ui_act("cancelCandidate", list(), ui, null), "Cancelling must work.")
	COOLDOWN_RESET(preferences.custom_sprite_pace, spacing)
	published = editor.published
	TEST_ASSERT(editor.ui_act("restorePrevious", list(), ui, null), "Restoring the same style again must work.")
	TEST_ASSERT_EQUAL(length(editor.candidate?["previews"]), 4, "The same style's previews come from the cache in the action itself.")
	TEST_ASSERT_EQUAL(editor.published, published, "A cached candidate draws nothing.")
	TEST_ASSERT(editor.ui_act("confirmCandidate", list(), ui, null), "Confirming must still replace the draft.")
	TEST_ASSERT_EQUAL(custom_sprite_hash(editor.workspace.serialize_drawing()), custom_sprite_hash(custom_sprite_validate(drawing)), "The confirmed draft is the restored drawing, as before.")

/// A rebuild can change what previews show, such as the recipient's clothing in the salon, so it throws cached candidate previews away.
/datum/unit_test/custom_sprite_hardening/candidate_cache_rebuild/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/publishing/editor = allocate(/datum/custom_sprite_editor/hardening_test/publishing, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/list/drawing = list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = "f1[repeat_string(1023, "0")]"), "emissive" = custom_sprite_emissive_settings(FALSE))
	var/list/package = custom_style_package("hair", null, drawing, editor.workspace.hair_context.Copy())
	TEST_ASSERT(editor.show_candidate(package, "import"), "The style should preview: [editor.transfer_error]")
	editor.run_deferred_work()
	TEST_ASSERT(editor.ui_act("cancelCandidate", list(), ui, null), "Cancelling must work.")
	// As the salon's clothing refresh does: the same body, rebuilt resources.
	editor.request_rebuild(reuse_body = TRUE)
	COOLDOWN_RESET(preferences.custom_sprite_pace, spacing)
	editor.run_deferred_work()
	TEST_ASSERT(editor.show_candidate(package, "import"), "The style should preview again: [editor.transfer_error]")
	TEST_ASSERT(isnull(editor.candidate["previews"]), "A rebuild must throw cached candidate previews away, so they're drawn on the rebuilt resources.")

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

/// Strokes within the budget apply at once; the rest wait in order and apply in the background; past the queue's length they're refused, quietly.
/datum/unit_test/custom_sprite_hardening/stroke_budget/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], CUSTOM_SPRITE_TALL_HAIRSTYLE)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	TEST_ASSERT_EQUAL(workspace.height, 48, "The fixture needs the tall canvas")
	workspace.update_palette(list("#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", "#ffffff", "#808080", "#800000", "#008000"))
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(32, 48), 32, 48)
	var/list/colors = workspace.palette.Copy()
	var/steps = length(workspace.undo_stack)
	var/list/pushed = list()
	for(var/i in 1 to 10)
		pushed += editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[colors[i]]ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + 3, "Three full tall strokes fit a second's budget and apply at once")
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 7, "The rest wait in the queue")
	TEST_ASSERT(pushed[1] && pushed[3] && !pushed[4] && !pushed[10], "Applied strokes push; queued ones don't")
	TEST_ASSERT(editor.ui_act("toggleGradient", list(), ui, null) == FALSE && editor.push_after_drain, "While strokes wait, an action's push waits for the drain")
	var/fires = 0
	while(length(editor.stroke_queue) && fires < 20)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT(!length(editor.stroke_queue), "The queue drains in the background")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + 10, "Every queued stroke applies")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "[colors[10]]ff", "Queued strokes apply in the order they were sent")
	TEST_ASSERT(!editor.push_after_drain, "The drain pushes what waited")
	// Past the queue's length, strokes are refused with a quiet notice.
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	for(var/i in 1 to 51)
		editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[colors[(i % 10) + 1]]ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 50, "The queue never grows past its length")
	TEST_ASSERT(editor.stroke_notice, "A refused stroke is explained")
	TEST_ASSERT(editor.ui_data(mock_client.mob)["strokeNotice"], "The window is told")
	fires = 0
	while(length(editor.stroke_queue) && fires < 100)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT(!length(editor.stroke_queue) && !editor.stroke_notice, "Draining clears the queue and the notice")

/// An opaque pencil stroke lands on the same pixels whether it's applied outright or blended pixel by pixel.
/datum/unit_test/custom_sprite_hardening/stroke_fast_path/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#00ff00"), list("2" = list(0, 0, 31, 31)))
	var/list/points = custom_sprite_hardening_all_points(32, 32)
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "points" = deep_copy_list(points))), "The stroke should be taken")
	var/list/expected = list()
	for(var/y in 1 to 32)
		var/list/row = list()
		for(var/x in 1 to 32)
			row += blend_color("#00000000", "#ff0000ff")
		expected += list(row)
	TEST_ASSERT_EQUAL(json_encode(workspace.get_first_layer_pixel_data()), json_encode(expected), "Outright assignment must match blend_color for an opaque colour")
	TEST_ASSERT(workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#00ff00ff", "mask" = custom_sprite_hardening_mask(points, 32, 32))), "A mask stroke should be taken")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[32][32], "#00ff00ff", "A mask stroke paints its last pixel")
	TEST_ASSERT(workspace.edited_directions["2"], "A painted view is marked edited")
	workspace.undo()
	workspace.undo()
	TEST_ASSERT(!workspace.edited_directions["2"], "Undoing every stroke marks the view empty again")

/// A whole-canvas placement of `color` on every other pixel, offset by `index`, as the window sends a paste that covers the canvas.
/proc/custom_sprite_hardening_placement(datum/sprite_editor_workspace/custom_sprite/workspace, color, index)
	var/list/codes = list()
	for(var/i in 1 to workspace.width * workspace.height)
		codes += (i + index) % 2 ? "0" : "1"
	return list("type" = "move", "layer" = 1, "dir" = "2", "area" = list(0, 0, workspace.width - 1, workspace.height - 1), "palette" = list("#00000000", "[color]ff"), "digits" = 1, "codes" = jointext(codes, ""))

/// The undo history keeps 100 steps or 40,000 recorded pixels, whichever runs out first; small strokes never lose a step early, and history still works across the cut.
/datum/unit_test/custom_sprite_hardening/history_points_cap/Run()
	var/datum/sprite_editor_workspace/custom_sprite/workspace = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#00ff00"), list("2" = list(0, 0, 31, 47)), null, null, 48)
	TEST_ASSERT_EQUAL(workspace.height, 48, "The fixture needs the tall canvas")
	var/list/colors = list("#ff0000", "#00ff00")
	for(var/i in 1 to 30)
		TEST_ASSERT(workspace.new_transaction(custom_sprite_hardening_placement(workspace, colors[(i % 2) + 1], i)), "Placement [i] should be taken")
	var/points = 0
	for(var/list/step as anything in workspace.undo_stack)
		points += length(step["points"])
	TEST_ASSERT(length(workspace.undo_stack) < 30 && length(workspace.undo_stack) >= 20, "Whole-canvas steps must evict the oldest once the pixels pass the cap: [length(workspace.undo_stack)] kept")
	TEST_ASSERT(points <= 40000 && points > 40000 - 32 * 48, "The kept steps must hold at most 40,000 recorded pixels, and not far fewer: [points]")
	var/kept = length(workspace.undo_stack)
	var/after_all = json_encode(workspace.layers[1]["data"]["2"])
	workspace.undo(kept)
	TEST_ASSERT(!length(workspace.undo_stack) && length(workspace.redo_stack) == kept, "Every kept step must undo")
	var/list/frame = workspace.layers[1]["data"]["2"]
	TEST_ASSERT(!endswith(frame[1][1], "00") || !endswith(frame[1][2], "00"), "Undoing past the cut leaves the evicted steps' paint, which can't be undone")
	workspace.redo(kept)
	TEST_ASSERT_EQUAL(json_encode(workspace.layers[1]["data"]["2"]), after_all, "Redoing every kept step must restore the canvas exactly")
	// Small strokes keep the full 100 steps.
	var/datum/sprite_editor_workspace/custom_sprite/small = allocate(/datum/sprite_editor_workspace/custom_sprite, null, list("#ff0000", "#00ff00"), list("2" = list(0, 0, 31, 31)))
	for(var/i in 1 to 101)
		small.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[colors[(i % 2) + 1]]ff", "points" = list(list(i % 32, round(i / 32)))))
	TEST_ASSERT_EQUAL(length(small.undo_stack), 100, "Small strokes keep the last 100 steps")

/// While strokes over the budget wait, the window can only send more strokes. Anything else is ignored until they're in, so history and saves keep their order, and closing waits rather than saving without them.
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
	TEST_ASSERT(!editor.ui_act("spriteEditorCommand", list("command" = "undo", "count" = 1), ui, null) && editor.push_after_drain, "An undo sent while a stroke waits is ignored, and the window hears back after the drain")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps, "The ignored undo changes no history")
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

/// Switching views reads and changes nothing in the draft, so the window can still switch while strokes wait, and the server draws the view it shows.
/datum/unit_test/custom_sprite_hardening/stroke_queue_view/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	workspace.update_palette(list("#ff0000"))
	var/mask = custom_sprite_hardening_mask(custom_sprite_hardening_all_points(workspace.width, workspace.height), workspace.width, workspace.height)
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "mask" = mask)), ui, null)
	var/datum/custom_sprite_pace/pace = editor.pace()
	pace.stroke_pixels = 1e9
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "1", "color" = "#ff0000ff", "mask" = mask)), ui, null)
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 1, "A stroke over the budget waits")
	editor.ui_act("setView", list("dir" = "4"), ui, null)
	TEST_ASSERT_EQUAL(editor.visible_direction, "4", "A view switch sent while a stroke waits is still heard")
	// The Front view is drawn and its refresh is pending, so nothing needs drawing to show it.
	TEST_ASSERT(!editor.ui_act("setView", list("dir" = "2"), ui, null) && editor.push_after_drain && editor.visible_direction == "2", "A view switch sent while strokes wait is heard, and the window hears back after the drain")

/// A deferred rebuild builds its body in one fire and renders in the next, keeping the old pictures up meanwhile, and ends exactly where a single rebuild would.
/datum/unit_test/custom_sprite_hardening/rebuild_two_fires/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	// A twin on the same character, rebuilt in one go, is the reference.
	var/datum/custom_sprite_editor/markings/hardening_test/twin = allocate(/datum/custom_sprite_editor/markings/hardening_test, editor.preferences, BODY_ZONE_CHEST)
	TEST_ASSERT(editor.ui_act("toggleParts", list(), ui, null), "Toggling parts must update the window.")
	twin.hide_parts = editor.hide_parts
	twin.rebuild_resources()
	twin.refresh_preview(push = FALSE)
	var/old_body = REF(editor.preview_body)
	var/old_guide = editor.guide_urls["2"]
	var/old_preview = editor.preview_urls["2"]
	editor.rebuilds = 0
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work(), "The first fire builds the body and keeps the editor queued.")
	TEST_ASSERT(editor.pending_body && REF(editor.preview_body) == old_body, "The new body waits beside the old one.")
	TEST_ASSERT(editor.guide_urls["2"] == old_guide && editor.preview_urls["2"] == old_preview, "The old guide and preview stay up between the fires.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 0, "Nothing is rendered in the first fire.")
	TEST_ASSERT(editor.pending_work, "The rest of the rebuild is still queued.")
	TEST_ASSERT(editor.run_deferred_work(), "The second fire finishes the rebuild.")
	TEST_ASSERT(!editor.pending_body && REF(editor.preview_body) != old_body, "The new body is in use and nothing is pending.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "The second fire renders once.")
	TEST_ASSERT_EQUAL(editor.guide_urls["2"], twin.guide_urls["2"], "The split rebuild's guide must match a single rebuild's.")
	TEST_ASSERT_EQUAL(json_encode(editor.workspace.draw_mask), json_encode(twin.workspace.draw_mask), "The split rebuild's paintable mask must match a single rebuild's.")
	TEST_ASSERT_EQUAL(json_encode(editor.region_map), json_encode(twin.region_map), "The split rebuild's region map must match a single rebuild's.")
	TEST_ASSERT_EQUAL(editor.preview_urls["2"], twin.preview_urls["2"], "The split rebuild's preview must match a single rebuild's.")
	// A newer request while a body waits makes the second fire start over on the latest state.
	editor.ui_act("toggleUnderwear", list(), ui, null)
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work() && editor.pending_body, "A body is pending again.")
	editor.ui_act("toggleUnderwear", list(), ui, null)
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work(), "A request that came while the body waited builds again on the latest state.")
	TEST_ASSERT(editor.run_deferred_work(), "Then the rebuild finishes.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 2, "Two rebuilds in all.")

/// A change that arrives while a new body waits can't make a window rebuild faster than its pace: the stale body is dropped, and the next one waits its turn.
/datum/unit_test/custom_sprite_hardening/rebuild_stale_body_pace/Run()
	var/list/opened = whole_body_editor()
	var/datum/custom_sprite_editor/markings/hardening_test/editor = opened[1]
	var/datum/tgui/ui = opened[2]
	editor.rebuilds = 0
	TEST_ASSERT(editor.ui_act("toggleParts", list(), ui, null), "Toggling parts must update the window.")
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work() && editor.pending_body, "The first fire builds a body.")
	editor.ui_act("toggleUnderwear", list(), ui, null)
	// The spacing that body started hasn't passed.
	TEST_ASSERT(!editor.run_deferred_work(), "A newer request can't finish the rebuild on a stale body.")
	TEST_ASSERT(!editor.pending_body && !editor.rebuilds, "The stale body is dropped, and nothing else is built or drawn before the pace allows.")
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(!editor.run_deferred_work() && editor.pending_body, "Once the pace allows, the latest state builds its body.")
	TEST_ASSERT(editor.run_deferred_work(), "And renders on the fire after.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "One rebuild, for the latest state.")

/// Fills are charged the pixels they filled, so whole-canvas fills can't pass the budget at one pixel each: past it they wait and apply in order like any other stroke.
/datum/unit_test/custom_sprite_hardening/stroke_bucket_budget/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], CUSTOM_SPRITE_TALL_HAIRSTYLE)
	var/datum/custom_sprite_editor/hardening_test/editor = allocate(/datum/custom_sprite_editor/hardening_test, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/datum/tgui/ui = allocate(/datum/tgui, mock_client.mob, editor, "CustomHairEditor")
	var/datum/sprite_editor_workspace/custom_sprite/workspace = editor.workspace
	var/list/colors = list("#ff0000", "#00ff00")
	workspace.update_palette(colors)
	var/area = workspace.width * workspace.height
	// Whole fills apply until one crosses 6,000 pixels a second; the ones after it wait.
	var/applied = round(6000 / area) + 1
	var/steps = length(workspace.undo_stack)
	for(var/i in 1 to applied + 2)
		editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "bucket", "layer" = 1, "dir" = "2", "color" = "[colors[(i % 2) + 1]]ff", "point" = list(0, 0))), ui, null)
	var/list/first = workspace.undo_stack[steps + 1]
	TEST_ASSERT_EQUAL(length(first["points"]), area, "The fixture's fills cover the whole canvas")
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + applied, "Fills are charged the pixels they filled, so only the ones within the budget apply at once")
	TEST_ASSERT_EQUAL(length(editor.stroke_queue), 2, "The fills past the budget wait")
	var/fires = 0
	while(length(editor.stroke_queue) && fires < 10)
		fires++
		editor.run_deferred_work()
	TEST_ASSERT_EQUAL(length(workspace.undo_stack), steps + applied + 2, "The waiting fills apply")
	TEST_ASSERT_EQUAL(workspace.get_first_layer_pixel_data()[1][1], "[colors[((applied + 2) % 2) + 1]]ff", "The waiting fills apply in the order they were sent")

/// A hair editor whose body can go away, as a salon recipient's can.
/datum/custom_sprite_editor/hardening_test/bodiless
	/// Whether the next preview body can't be built.
	var/no_body = FALSE

/// No body while no_body is set.
/datum/custom_sprite_editor/hardening_test/bodiless/create_preview_body()
	return no_body ? null : ..()

/// An import's previews are drawn only on a body: when the body can't be rebuilt before their fire, the card waits instead of drawing on nothing.
/datum/unit_test/custom_sprite_hardening/candidate_lost_body/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/custom_sprite_editor/hardening_test/bodiless/editor = allocate(/datum/custom_sprite_editor/hardening_test/bodiless, preferences, "hair")
	LAZYSET(preferences.custom_sprite_editors, "hair", editor)
	var/list/drawing = list("version" = 1, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = "f1[repeat_string(1023, "0")]"), "emissive" = custom_sprite_emissive_settings(FALSE))
	TEST_ASSERT(editor.show_candidate(custom_style_package("hair", null, drawing, editor.workspace.hair_context.Copy()), "import"), "The style should preview: [editor.transfer_error]")
	// The body goes away before the previews' fire.
	editor.no_body = TRUE
	editor.request_rebuild()
	COOLDOWN_RESET(preferences.custom_sprite_pace, spacing)
	var/fires = 0
	while(!editor.run_deferred_work() && fires < 5)
		fires++
	TEST_ASSERT(!editor.resources_ready && editor.candidate && isnull(editor.candidate["previews"]), "With no body the card waits without previews")
