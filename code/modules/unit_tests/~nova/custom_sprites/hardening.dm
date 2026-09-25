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
	TEST_ASSERT(editor.run_deferred_work(), "The first rebuild after a quiet spell must run.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "A burst of toggles must rebuild once.")
	editor.ui_act("toggleUnderwear", list(), ui, null)
	TEST_ASSERT(!editor.run_deferred_work(), "A rebuild right after another must wait for the spacing.")
	TEST_ASSERT_EQUAL(editor.rebuilds, 1, "A spaced-out rebuild must not run early.")
	TEST_ASSERT(editor in SScustom_sprite_work.queue, "Waiting work must stay queued.")
	// As if the spacing had passed.
	COOLDOWN_RESET(editor.preferences.custom_sprite_pace, spacing)
	TEST_ASSERT(editor.run_deferred_work(), "Queued work must run once the spacing has passed.")
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
