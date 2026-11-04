/// Most colours the editor keeps among those picked: picking one more drops the oldest.
#define GRAFFITI_PICKED_COLORS 16
/// Shortest time between two surface composites for one painter.
#define GRAFFITI_COMPOSITE_SPACING (1.5 SECONDS)
/// Surface composites one painter gets per round, paint job steps included, before freehand composites slow to
/// GRAFFITI_COMPOSITE_SLOW_SPACING.
#define GRAFFITI_COMPOSITE_BUDGET 600
/// Shortest time between two surface composites once a painter's budget is spent.
#define GRAFFITI_COMPOSITE_SLOW_SPACING (10 SECONDS)
/// How long a freehand session waits before asking a tile that refused its paint again, its composites only showing the
/// refusal meanwhile. A refusal costs about 0.02 ms (measured) since the per-ckey index.
#define GRAFFITI_PLACE_RETRY (10 SECONDS)
/// Longest freehand session on one surface.
#define GRAFFITI_SESSION_LIMIT (15 MINUTES)
/// Deferred work for SScustom_sprite_work: recomposite a freehand session's surface. The custom sprite editors' own work
/// flags take the bits below it.
#define GRAFFITI_WORK_COMPOSITE (1<<8)

/**
 * The graffiti editor: the custom sprite editor's shell on a graffiti piece, whose canvas, tools and history it reuses.
 *
 * A studio session edits a piece for its owner's library, which its saves go into. A surface session paints live on a
 * wall, a floor or a full-tile window: the piece goes on top of the tile's stack at its first stroke and is
 * recomposited there at a paced cadence, the can is charged once the session ends with paint on the surface, and a
 * piece it didn't save goes in the library's Unfinished slot, ready to resume on that tile.
 *
 * The editor belongs to the account it is registered to in SSgraffiti.editors, and ends with its window.
 */
/datum/custom_sprite_editor/graffiti
	context = "graffiti"
	/// "studio" or "surface".
	var/kind
	/// The library piece saves go over, or null until the first save.
	var/piece_id
	/// The piece's name as the library keeps it: the opened piece's, or "Untitled" for a new one. A save takes the library
	/// piece's current one, which only the Custom Graffiti tab changes.
	var/piece_name
	/// The piece's description as the library keeps it: the opened piece's, or "" for a new one. A save takes the
	/// library piece's current one, which only the Custom Graffiti tab changes.
	var/piece_desc
	/// The wall, floor or window tile a surface session paints: the left tile of a two-tile piece.
	var/turf/surface
	/// The spray can the session was opened from. A surface session paints with it and charges it.
	var/obj/item/toy/crayon/spraycan/can
	/// The piece's placement on the surface, packed as SSgraffiti keeps it, or null until it has one. The left half of a two-tile piece.
	var/placement
	/// The right half's placement of a two-tile piece, packed, or null.
	var/placement2
	/// When the session started.
	var/started
	/// The spray can tab the window asked for as it closed, for the can to reopen on.
	var/pending_tab
	/// Colours added through the picker, which the palette offers beside the paint's own, oldest first. A queue of
	/// GRAFFITI_PICKED_COLORS: one more drops the oldest.
	var/list/piece_colors = list()
	/// json_encode() of the piece as opened or last saved, which unsaved changes are told by. While the editor is built, the piece it opens.
	var/saved_encoding
	/// When the last spray sound ends.
	COOLDOWN_DECLARE(spray_cooldown)
	/// When the surface may be recomposited again.
	COOLDOWN_DECLARE(composite_cooldown)
	/// Tile -> list(when it is asked again, the notice it gave) for each tile that refused the piece's paint: "0" for a
	/// one-tile piece, "1" and "2" for a two-tile piece's halves.
	var/list/refusals
	/// Layer id -> list(the codes of its view the window was last sent, their serial), so an update sends a view only once
	/// it changes. Null for a window that has none yet.
	var/list/sent_views
	/// The serial the codes sent last went under. New codes take the next, so a serial never comes twice.
	var/view_serial = 0

/**
 * Opens a piece, or a blank one, for a session.
 *
 * Arguments:
 * - preferences: The owner's preferences, which pace the editor's costly work and keep their saved swatches, or null.
 * - piece: The canonical piece to open, a copy the editor may keep, or null for a blank one.
 * - piece_id: The library piece it is, or null.
 * - can: The spray can it was opened from, or null.
 * - surface: The wall, floor or window tile to paint live, or null for a studio session.
 */
/datum/custom_sprite_editor/graffiti/New(datum/preferences/preferences, list/piece, piece_id, obj/item/toy/crayon/spraycan/can, turf/surface)
	src.piece_id = piece_id
	src.can = can
	src.surface = surface
	kind = surface ? "surface" : "studio"
	piece_name = piece?["name"] || "Untitled"
	piece_desc = piece?["description"] || ""
	started = world.time
	// The base constructor builds the workspace from initial_package().
	saved_encoding = json_encode(piece)
	..(preferences, "graffiti")
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	// Measured against the piece as the workspace serializes it, which an imported piece may not match byte for byte.
	saved_encoding = json_encode(canvas.serialize_piece(piece_name, piece_desc))
	var/list/palette = graffiti_default_palette()
	selected_color = palette[1]
	if(can)
		RegisterSignal(can, COMSIG_QDELETING, PROC_REF(can_gone))

/datum/custom_sprite_editor/graffiti/Destroy()
	// Deleted with its window open, the editor still ends its session as the window closes.
	SStgui.close_uis(src)
	SSgraffiti.composite_line -= src
	for(var/key, editor in SSgraffiti.editors)
		if(editor == src)
			SSgraffiti.editors -= key
			// An owner who disconnected meanwhile left the library loaded for the editor.
			if(!GLOB.directory[key])
				graffiti_library_unload(key)
			break
	can = null
	surface = null
	return ..()

/// The piece being opened, which the constructor keeps in saved_encoding until the workspace is built.
/datum/custom_sprite_editor/graffiti/initial_package()
	return json_decode(saved_encoding)

/// A one-view workspace of uniform layers in colours that may be translucent.
/datum/custom_sprite_editor/graffiti/create_workspace(list/package)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = new(package)
	if(kind == "surface")
		canvas.tool_flags &= ~(SPRITE_EDITOR_TOOL_ERASER | SPRITE_EDITOR_TOOL_SELECT)
	return canvas

/// Graffiti draws on no body: the window composes its own preview.
/datum/custom_sprite_editor/graffiti/create_preview_body()
	return null

/// Any layer may glow.
/datum/custom_sprite_editor/graffiti/emissives_allowed()
	return TRUE

/datum/custom_sprite_editor/graffiti/window_title()
	// A window's glass, not the floor beneath it.
	return kind == "surface" ? "Graffiti editor on \the [graffiti_window_of(surface) || surface]" : "Graffiti editor"

/// There are no guides or previews to build, so the editor is always ready.
/datum/custom_sprite_editor/graffiti/rebuild_resources(reuse_body = FALSE)
	sampled_palette = list()
	resources_ready = TRUE
	return TRUE

/// The window previews graffiti itself; nothing is drawn on the server.
/datum/custom_sprite_editor/graffiti/refresh_preview(push = TRUE)
	preview_timer = null

/// No views wait to be drawn: graffiti has one view and no server pictures.
/datum/custom_sprite_editor/graffiti/draw_waiting_views()
	return

/// Graffiti has no body parts to hide.
/datum/custom_sprite_editor/graffiti/can_hide_parts()
	return FALSE

/// Graffiti saves pieces, never style packages.
/datum/custom_sprite_editor/graffiti/current_package()
	return null

/**
 * Whether a mob may act on this editor: the account it is registered to, until the session ends.
 *
 * Arguments:
 * - user: The mob.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/custom_sprite_editor/graffiti/can_edit(mob/user)
	return !closing && !!user?.ckey && SSgraffiti.editors[user.ckey] == src

/datum/custom_sprite_editor/graffiti/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(. == UI_INTERACTIVE && session_problem(user))
		return UI_CLOSE

/**
 * Opens the window, or refreshes the open one.
 *
 * Arguments:
 * - user: The owner.
 * - ui: The open window, when tgui refreshes it.
 */
/datum/custom_sprite_editor/graffiti/ui_interact(mob/user, datum/tgui/ui)
	if(!can_edit(user))
		return
	// While strokes wait, an open window's refresh waits for their drain, which sends it.
	if(length(stroke_queue) && SStgui.get_open_ui(user, src))
		return
	var/opening = isnull(ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		if(opening)
			bring_to_front(user, ui)
		return
	// A refresh that found the window closing ended the session with it.
	if(closing)
		return
	// A new window has no views yet.
	sent_views = null
	ui = new(user, src, "GraffitiEditor", window_title())
	// The spray can's window and this one take turns, so they share its place on screen.
	if(can)
		ui.window_key = "[REF(can)]-main"
	ui.set_autoupdate(FALSE)
	ui.open()

/datum/custom_sprite_editor/graffiti/ui_static_data(mob/user)
	. = ..()
	.["defaultPalette"] = graffiti_default_palette()
	// The graffiti each tile of a surface session's canvas already shows, which the window draws beneath it.
	var/list/arts
	if(kind == "surface")
		arts = list(tile_background(surface, placement))
		if(workspace.width == GRAFFITI_WIDE_WIDTH)
			arts += list(tile_background(get_step(surface, EAST), placement2))
	.["graffitiBackground"] = arts

/datum/custom_sprite_editor/graffiti/ui_data(mob/user)
	. = ..()
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	var/list/editor_data = .["editorData"]
	var/list/sprite = editor_data["sprite"]
	// The inherited canvas sends the hair's layer as the base views; graffiti's bottom layer is whichever comes first, and
	// the others go as appendages. The window keeps every view it is sent, so one it was last sent as it is goes as null.
	// Each view goes with its codes' serial: a window that never drew the update carrying them, as when two come before
	// it draws, or never had them, as after a reload, asks for them all again (canvasResync). Codes are text, which BYOND
	// interns, so comparing them costs nothing.
	var/list/compact = sprite["canvas"]
	var/list/sent = list()
	var/list/serials = list()
	var/list/appendage_views = list()
	for(var/index in 1 to length(canvas.layers))
		var/id = canvas.layers[index]["id"]
		var/codes = canvas.canvas_views[id]?["2"]
		var/list/last = sent_views?[id]
		var/list/entry = (codes && last?[1] == codes) ? last : list(codes, ++view_serial)
		sent[id] = entry
		serials[id] = entry[2]
		var/list/view = list("2" = entry == last ? null : codes)
		if(index == 1)
			compact["views"] = view
			compact["viewsLayer"] = id
		else
			appendage_views[id] = view
	compact["appendages"] = appendage_views
	compact["viewSerials"] = serials
	sent_views = sent
	// Only a body's preview shows a floating selection.
	sprite["selectionPreview"] = FALSE
	var/list/used = canvas.used_colors()
	var/list/colors = used | piece_colors
	editor_data["serverPalette"] = colors
	// Any colour can be painted until the paint uses GRAFFITI_MAX_COLORS of them, and then only those.
	.["availableColors"] = length(used) >= GRAFFITI_MAX_COLORS ? used : colors | .["customPalette"]
	// A poster's canvas keeps to the poster's own pixels.
	.["drawBounds"] = canvas.draw_bounds || list("2" = list(0, 0, canvas.width - 1, GRAFFITI_HEIGHT - 1))
	// Glow is per layer, in the layer list.
	. -= "emissive"
	// Sent once, so the window switches to a layer it was just given.
	.["focusLayer"] = focus_layer
	focus_layer = null
	var/datum/graffiti_library/library = graffiti_library(user?.ckey)
	.["graffiti"] = list(
		"kind" = kind,
		"width" = canvas.width,
		"layers" = canvas.layer_entries(),
		// Infinite cans (crayons.dm's INFINITE_CHARGES) never run out.
		"charges" = can && can.charges >= 0 ? can.charges_left : null,
		"canSave" = length(used) && length(used) <= GRAFFITI_MAX_COLORS && library && ((piece_id in library.pieces) || length(library.pieces) < GRAFFITI_LIBRARY_CAP) ? TRUE : FALSE,
		"full" = length(used) >= GRAFFITI_MAX_COLORS,
		"libraryCount" = length(library?.pieces),
		"libraryCap" = GRAFFITI_LIBRARY_CAP,
		"roundOnly" = kind == "surface" && (!graffiti_anchor_for(surface) || (canvas.width == GRAFFITI_WIDE_WIDTH && !graffiti_anchor_for(get_step(surface, EAST)))),
		"pieceId" = piece_id,
	)

/**
 * Takes the window's request for every view (canvasResync), which the base editor leaves: the window lacks a view it
 * was sent, as after a reload, or one carried by an update it never drew. The next update brings them all: push()'s at
 * once, or, while strokes wait for the budget and the base editor takes nothing but strokes, the drain's, so no update
 * shows the canvas without the strokes that wait.
 *
 * Arguments:
 * - action: The action.
 * - params: Its params, as the window sent them.
 * - ui: The window.
 * - state: The window's state.
 *
 * Returns:
 * - TRUE/FALSE: Whether the window updates at once.
 */
/datum/custom_sprite_editor/graffiti/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || action != "canvasResync" || !can_edit(ui.user))
		return
	sent_views = null
	push()
	return FALSE

/**
 * Handles the graffiti window's own actions and refuses the hair editor's ones that mean nothing here, such as hair,
 * guides, previews, tints, style files and views. A surface session whose painter can no longer paint ends first.
 *
 * Arguments:
 * - action: The action.
 * - params: Its params, as the window sent them.
 * - ui: The window.
 *
 * Returns:
 * - TRUE/FALSE: Whether the window updates.
 * - null: The base editor handles the action: strokes and history, clearing a layer, notices and saved swatches.
 */
/datum/custom_sprite_editor/graffiti/editor_act(action, list/params, datum/tgui/ui)
	var/mob/user = ui.user
	if(session_problem(user))
		end_session(user)
		return TRUE
	// Keep the stroke records for fill accounting, but freehand cannot use history or erase paint.
	if(kind == "surface" && ((action in list("clear", "layerRemove")) || (action == "spriteEditorCommand" && (params["command"] in list("undo", "redo")))))
		return FALSE
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	switch(action)
		if("spriteEditorCommand", "clear", "dismissTransfer")
			return null
		if("savePaletteColor", "addPaletteColor", "removePaletteColor", "editPaletteColor")
			return preferences ? null : FALSE
		if("layerAdd")
			var/index = canvas.add_layer()
			if(!index)
				return FALSE
			focus_layer = canvas.layers[index]["id"]
		if("layerRemove")
			if(!canvas.remove_layer(canvas.layer_index(params["id"])))
				return FALSE
		if("layerRename")
			if(!canvas.rename_layer(canvas.layer_index(params["id"]), params["name"]))
				return FALSE
		if("layerMove")
			if(!canvas.move_layer(canvas.layer_index(params["id"]), params["delta"]))
				return FALSE
		if("layerGlow")
			var/enabled = params["enabled"]
			if(!(enabled in list(TRUE, FALSE)) || !canvas.set_layer_glow(canvas.layer_index(params["id"]), enabled))
				return FALSE
		if("setWidth")
			var/width = params["width"]
			if(!(width in list(GRAFFITI_WIDTH, GRAFFITI_WIDE_WIDTH)) || width == canvas.width)
				return FALSE
			if(kind == "surface")
				// Placements keep the width they were made at.
				if(placement || placement2)
					notify("This graffiti is already on the surface, so its width can't change.")
					return TRUE
				if(width == GRAFFITI_WIDE_WIDTH && !graffiti_wide_ok(surface))
					notify("There's no surface like this one to the right to paint a second tile on.")
					return TRUE
			if(width == GRAFFITI_WIDTH && canvas.has_paint_right_half() && params["confirm"] != TRUE)
				notify("Going back to one tile loses the paint on the right one. Confirm to go ahead.")
				return TRUE
			canvas.set_width(width)
			draft_edited()
			// A surface session's canvas now covers another tile, whose graffiti is static data.
			if(kind == "surface")
				ui.send_full_update()
				return FALSE
			return TRUE
		if("addColor", "selectColor", "selectCustomColor")
			var/color = canvas.add_color(params["color"])
			if(!color)
				notify("That colour can't be painted: it shows nothing, or the piece already uses [GRAFFITI_MAX_COLORS] colours.")
				return TRUE
			selected_color = color
			selected_custom_color = null
			if(action == "addColor")
				piece_colors -= color
				piece_colors += color
				// The oldest goes even if it is painted: painted colours stay listed through the paint.
				if(length(piece_colors) > GRAFFITI_PICKED_COLORS)
					piece_colors.Cut(1, 2)
				return TRUE
			// The window picks a plain swatch itself, so echoing it back would only resend the canvas; a saved swatch waits for the server.
			return action == "selectCustomColor"
		if("sampleGuide")
			return sample_paint(params["x"], params["y"], params["layer"])
		if("save", "saveDraft", "saveAs")
			save_drawing(user, action == "saveAs")
			return TRUE
		if("importPiece", "exportPiece")
			if(kind == "surface")
				notify("Import and export work in the studio, not on a surface.")
				return TRUE
			// An export carries the piece as the library has it.
			if(action == "exportPiece" && (!piece_id || json_encode(canvas.serialize_piece(piece_name, piece_desc)) != saved_encoding))
				notify("Save the piece first, then export it.")
				return TRUE
			if(!graffiti_library_write_due(user.ckey))
				notify("Wait a moment before trying that again.")
				return TRUE
			transfer_notice = null
			if(action == "exportPiece")
				transfer_error = graffiti_export(user, piece_id)
				if(!transfer_error)
					notify("Exported.")
				return TRUE
			var/datum/graffiti_library/library = graffiti_library(user.ckey)
			var/count = length(library?.pieces)
			// Sleeps while the file dialog is open.
			transfer_error = graffiti_import(user)
			if(QDELETED(src))
				return FALSE
			if(!transfer_error && length(library?.pieces) > count)
				notify("Imported into Custom Graffiti.")
			return TRUE
		if("drawing")
			if(kind == "surface")
				spray_cooldown = graffiti_spray(surface, spray_cooldown)
			return FALSE
		if("openTab")
			var/tab = params["tab"]
			if(!(tab in list("stencils", "graffiti")))
				return FALSE
			pending_tab = tab
			SStgui.close_uis(src)
			return FALSE
		else
			return FALSE
	draft_edited()
	return TRUE

/**
 * The eyedropper: makes a layer's pixel the brush colour, alpha and all.
 *
 * Arguments:
 * - column: The pixel's column.
 * - row: Its row, from the top.
 * - id: The layer to sample, or anything else for the topmost layer painted there.
 *
 * Returns:
 * - TRUE/FALSE: Whether a colour was taken.
 */
/datum/custom_sprite_editor/graffiti/proc/sample_paint(column, row, id)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	if(!canvas.valid_point_pair(list(column, row)) || column < 0 || column >= canvas.width || row < 0 || row >= GRAFFITI_HEIGHT)
		return FALSE
	var/list/order = list()
	var/index = canvas.layer_index(id)
	if(index)
		order += index
	else
		for(var/layer in canvas.layer_count() to 1 step -1)
			order += layer
	for(var/layer in order)
		var/pixel = canvas.layer_view(layer)[row + 1][column + 1]
		if(!endswith(pixel, "00"))
			selected_color = graffiti_color(pixel)
			selected_custom_color = null
			return TRUE
	return FALSE

/// Marks the draft changed, as every window edit does. A surface session asks for its surface to be recomposited.
/datum/custom_sprite_editor/graffiti/draft_edited()
	draft_changed()
	// A composite asked for already keeps the editor queued until it runs, so a drain in that run doesn't queue it again.
	if(kind == "surface" && !(pending_work & GRAFFITI_WORK_COMPOSITE))
		request_work(GRAFFITI_WORK_COMPOSITE)

/**
 * Saves the piece into its owner's library: over its library piece, or as a new one the first time or when asked. An
 * unchanged piece is acknowledged without writing, and writes wait for graffiti_library_write_due(). The piece keeps
 * the name and description its library piece has (take_library_names()), so a rename alone writes nothing.
 *
 * Arguments:
 * - user: The owner.
 * - copy: Whether to save a new piece rather than over this one.
 *
 * Returns:
 * - TRUE/FALSE: Whether the library holds the piece as it is now. On FALSE the status line says why.
 */
/datum/custom_sprite_editor/graffiti/save_drawing(mob/user, copy = FALSE)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	var/datum/graffiti_library/library = graffiti_library(user?.ckey)
	take_library_names(library)
	var/list/piece = canvas.serialize_piece(piece_name, piece_desc)
	if(!piece)
		notify(length(canvas.used_colors()) ? "This piece uses more than [GRAFFITI_MAX_COLORS] colours. Remove some to save it." : "Paint something first.")
		return FALSE
	if(!library)
		save_error = "Your graffiti library isn't available."
		return FALSE
	var/text = json_encode(piece)
	// The window still flashes Saved.
	if(!copy && (piece_id in library.pieces) && text == saved_encoding)
		save_revision++
		return TRUE
	if(!graffiti_library_write_due(user.ckey))
		notify("Wait a moment before saving again.")
		return FALSE
	var/result = library.save_piece(piece, copy ? null : piece_id)
	if(!(result in library.pieces))
		save_error = result
		return FALSE
	piece_id = result
	saved_encoding = text
	save_error = null
	save_revision++
	if(kind == "surface")
		notify("Saved to Custom Graffiti.")
	else if(copy)
		notify("Saved as a new piece.")
	return TRUE

/**
 * Takes the name and description the library holds for the piece, which the Custom Graffiti tab may have changed since
 * it was opened or saved. The piece as last saved takes them too, so a rename alone isn't an unsaved change.
 *
 * Arguments:
 * - library: The owner's library, or null.
 */
/datum/custom_sprite_editor/graffiti/proc/take_library_names(datum/graffiti_library/library)
	var/list/saved = library?.piece(piece_id)
	if(!saved || (saved["name"] == piece_name && saved["description"] == piece_desc))
		return
	piece_name = saved["name"]
	piece_desc = saved["description"]
	var/list/last_saved = json_decode(saved_encoding)
	if(!islist(last_saved))
		return
	last_saved["name"] = piece_name
	last_saved["description"] = piece_desc
	saved_encoding = json_encode(last_saved)

/**
 * Returns why a surface session can't go on: its painter must stay beside the surface, holding the uncapped can and
 * able to use it, the surface must still take graffiti, the piece must still be on it, and the session must not have
 * run past GRAFFITI_SESSION_LIMIT.
 *
 * Arguments:
 * - user: The painter.
 *
 * Returns:
 * - text: Why the session ends, to tell the painter.
 * - null: It goes on, or it is a studio session.
 */
/datum/custom_sprite_editor/graffiti/proc/session_problem(mob/user)
	if(kind != "surface")
		return null
	if(world.time - started >= GRAFFITI_SESSION_LIMIT)
		return "You've been painting here a long time. Take a break."
	if(QDELETED(can) || !user?.is_holding(can) || can.is_capped)
		return "You need the uncapped spray can in your hand to paint."
	if(user.incapacitated)
		return "You can't paint like this."
	if(!user.Adjacent(surface))
		return "You're too far away to keep painting."
	return surface_problem()

/**
 * Returns why a surface session's surface can't take its paint any more: it no longer takes graffiti, or the piece is
 * gone from it.
 *
 * Returns:
 * - text: Why the session ends, to tell the painter.
 * - null: The surface still takes it.
 */
/datum/custom_sprite_editor/graffiti/proc/surface_problem()
	if(workspace.width == GRAFFITI_WIDE_WIDTH ? !graffiti_wide_ok(surface) : !graffiti_surface_ok(surface))
		return "There's nothing left to paint on."
	if((placement && !SSgraffiti.shown[placement]) || (placement2 && !SSgraffiti.shown[placement2]))
		return "Your graffiti is gone from the surface."
	return null

/**
 * Ends the session and closes its window. The strokes still waiting go in first. A surface session leaves its piece
 * on the surface through leave_surface(). A piece that changed since it was opened or saved goes in the library's
 * Unfinished slot, under the name and description its library piece has (take_library_names()), resumable on the
 * surface while it is still there. A pane loosened under the piece drops all of its paint first, both halves of a
 * two-tile piece, and the piece goes in the slot as a plain draft, with no tile to resume on.
 *
 * Arguments:
 * - user: The owner.
 * - keep: Whether the piece is kept. An admin deleting its paint ends the session with nothing kept: no last composite,
 *   no charge and no Unfinished piece.
 */
/datum/custom_sprite_editor/graffiti/proc/end_session(mob/user, keep = TRUE)
	if(closing)
		return
	var/problem = session_problem(user)
	closing = TRUE
	if(problem)
		to_chat(user, span_warning(problem))
	// Each drain applies at least one stroke.
	for(var/attempt in 1 to length(stroke_queue))
		if(drain_strokes())
			break
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	var/datum/graffiti_library/library = graffiti_library(user?.ckey)
	take_library_names(library)
	var/list/piece = canvas.serialize_piece(piece_name, piece_desc)
	var/list/resume = kind == "surface" ? end_surface(user, piece, keep) : null
	if(keep && piece && json_encode(piece) != saved_encoding)
		var/error = library ? library.set_unfinished(piece, resume, TRUE) : "Your graffiti library isn't available."
		if(error)
			to_chat(user, span_warning("Your unsaved graffiti couldn't be kept: [error]"))
	SStgui.close_uis(src)
	// A window closing because the editor is being deleted ends the session from inside Destroy().
	if(!QDELETED(src))
		qdel(src)

/**
 * Ends a surface session on its surface. A kept piece stays there through leave_surface(), unless a pane loosened under
 * it, which drops all of its paint first. Either way the tiles' decals let go of their merges.
 *
 * Arguments:
 * - user: The painter.
 * - piece: The piece as it ends, or null when nothing is painted.
 * - keep: Whether the piece is kept, as end_session() takes it.
 *
 * Returns:
 * - list: Where the Unfinished piece resumes: the map, its left tile's anchor and its placement id.
 * - null: It resumes nowhere.
 */
/datum/custom_sprite_editor/graffiti/proc/end_surface(mob/user, list/piece, keep)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	if(keep)
		// Before the last composite, which a loose pane skips: it would place a half that has none yet and charge for it.
		var/loose = graffiti_drop_loose_paint(surface, canvas.width, list(placement, placement2))
		var/list/kept = leave_surface(user, loose ? null : piece)
		// progress -1 marks a freehand draft rather than a stopped paint job. The width is the piece's: one tile when
		// nothing is painted on the right one, where leave_surface() leaves no placement.
		if(length(kept) && !loose)
			. = list("map" = SSmapping.current_map.map_name, "anchor" = graffiti_resume_anchor(surface, kept[1]), "pid" = SSgraffiti.unpack(kept[1])["pid"], "progress" = -1, "width" = piece["width"])
	graffiti_release_merges(surface, canvas.width)

/**
 * Leaves a surface session's piece on the surface as the session ends: composited one last time, without an empty piece
 * or a half of a two-tile piece left without paint. With paint left, the can is charged once, never refused, unless the
 * session resumed a draft and changed nothing, and each tile the piece is on is marked as the painter's work and the
 * painter given the graffiti achievement, as for a finished paint job.
 *
 * Arguments:
 * - user: The painter.
 * - piece: The piece as it ends, or null for no last composite: nothing is painted, or a pane loosened under it.
 *
 * Returns:
 * - list: The placements the piece left on the surface, packed.
 */
/datum/custom_sprite_editor/graffiti/proc/leave_surface(mob/user, list/piece)
	// The last composite asks every tile again, whatever it refused before: a full map may have room by now.
	refusals = null
	if(piece)
		apply_live(user)
	. = list()
	for(var/packed in list(placement, placement2))
		if(!SSgraffiti.shown[packed])
			continue
		var/list/art = SSgraffiti.art[SSgraffiti.unpack(packed)["art"]]
		if(piece && length(art?["pal"]))
			. += packed
		else
			SSgraffiti.remove_placement(packed)
	if(!length(.))
		log_game("[key_name(user)] ended a freehand graffiti session at [AREACOORD(surface)] without leaving paint")
		return
	// A resumed draft that this session left as it was has been paid for.
	if(draft_revision)
		can?.use_charges(user, GRAFFITI_COST * (HAS_TRAIT(user, TRAIT_TAGGER) ? 0.5 : 1), FALSE)
	for(var/packed in .)
		var/obj/effect/decal/cleanable/crayon/custom/decal = SSgraffiti.shown[packed]
		if(decal)
			graffiti_credit_painter(decal, user)
	user.client?.give_award(/datum/award/achievement/misc/custom_graffiti_painted, user)
	log_game("[key_name(user)] painted freehand graffiti, placement [SSgraffiti.unpack(.[1])["pid"]], at [AREACOORD(surface)]")

/// Closing the window ends the session. A window closed for a spray can tab hands back to the can's window on it.
/datum/custom_sprite_editor/graffiti/ui_close(mob/user)
	..()
	// Taken first: ending the session deletes the editor, which lets go of the can.
	var/obj/item/toy/crayon/spraycan/spraycan = can
	var/tab = take_pending_tab()
	end_session(user)
	// Opening a window may sleep, which closing one must not.
	if(tab && !QDELETED(spraycan))
		INVOKE_ASYNC(spraycan, TYPE_PROC_REF(/obj/item/toy/crayon/spraycan, graffiti_reopen), user, tab)

/**
 * Returns the spray can tab the window asked for as it closed, once.
 *
 * Returns:
 * - text: "stencils" or "graffiti".
 * - null: The window didn't ask for one.
 */
/datum/custom_sprite_editor/graffiti/proc/take_pending_tab()
	. = pending_tab
	pending_tab = null

/**
 * Whether the surface may be recomposited now: the painter's pace allows costly work, the last composite was
 * GRAFFITI_COMPOSITE_SPACING ago, or GRAFFITI_COMPOSITE_SLOW_SPACING once the round's GRAFFITI_COMPOSITE_BUDGET is
 * spent, and it is the editor's turn among every painter's composites (SSgraffiti's composite_turn()).
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/custom_sprite_editor/graffiti/proc/composite_due()
	var/datum/custom_sprite_pace/pace = pace()
	return COOLDOWN_FINISHED(src, composite_cooldown) && pace.due() && SSgraffiti.composite_turn(src)

/// A due composite is costly work, which SScustom_sprite_work keeps within its overrun budget. Waiting strokes bring one in the run that drains them.
/datum/custom_sprite_editor/graffiti/costly_work_due()
	return ..() || (!closing && kind == "surface" && ((pending_work & GRAFFITI_WORK_COMPOSITE) || length(stroke_queue)) && composite_due())

/**
 * Applies the strokes still waiting, then recomposites a surface session's surface when it is due, then does the base
 * editor's work.
 *
 * Returns:
 * - TRUE/FALSE: FALSE while the composite or strokes have to wait, so the subsystem keeps the editor queued.
 */
/datum/custom_sprite_editor/graffiti/run_deferred_work()
	if(closing)
		return ..()
	// Strokes that waited for the budget go first, and the composite shows them. It is asked for here, while the
	// subsystem runs this editor, so their drain doesn't queue the editor again.
	if(length(stroke_queue))
		if(kind == "surface")
			pending_work |= GRAFFITI_WORK_COMPOSITE
		if(!drain_strokes())
			return FALSE
	if(!(pending_work & GRAFFITI_WORK_COMPOSITE))
		return ..()
	if(!composite_due())
		return FALSE
	pending_work &= ~GRAFFITI_WORK_COMPOSITE
	// The turn is taken whether or not the composite places anything.
	SSgraffiti.composite_line -= src
	// Paint goes on while the owner holds the can; anyone else holding it ends the session at its next check.
	var/mob/painter = can?.loc
	if(ismob(painter) && SSgraffiti.editors[painter.ckey] == src)
		apply_live(painter)
	return ..()

/**
 * Puts the piece on its surface as it is now, the first time on top of each tile's stack, and counts the composite
 * against the painter's pace and its time against every painter's (SSgraffiti's spend_composite()). An unpainted piece
 * leaves the surface as it is. While every tile waits out a refusal, the composite only shows that refusal again,
 * flattening nothing and costing no pace.
 *
 * Arguments:
 * - user: The painter, whose ckey and character name new placements carry.
 */
/datum/custom_sprite_editor/graffiti/proc/apply_live(mob/user)
	var/datum/sprite_editor_workspace/custom_sprite/graffiti/canvas = workspace
	var/notice
	var/placing = FALSE
	for(var/half in (canvas.width == GRAFFITI_WIDE_WIDTH ? list(1, 2) : list(0)))
		var/list/refusal = refusals?["[half]"]
		if(!refusal || world.time >= refusal[1])
			placing = TRUE
		else
			notice ||= refusal[2]
	if(!placing)
		notify(notice)
		push()
		return
	// What serialize_piece() refuses: nothing painted, or too many colours.
	if(!length(canvas.color_counts) || length(canvas.color_counts) > GRAFFITI_MAX_COLORS)
		return
	var/started = TICK_USAGE_REAL
	var/datum/custom_sprite_pace/pace = pace()
	pace.start()
	pace.graffiti_composites++
	COOLDOWN_START(src, composite_cooldown, pace.graffiti_composites >= GRAFFITI_COMPOSITE_BUDGET ? GRAFFITI_COMPOSITE_SLOW_SPACING : GRAFFITI_COMPOSITE_SPACING)
	// Straight from the frames, so the layers are never encoded to be decoded again.
	var/list/record = list()
	var/list/art = graffiti_flatten_records(canvas.layer_records(), canvas.width, 0, 0, record)
	// The ids of the painter's own placements that made room, both halves' together.
	var/list/evicted = list()
	place_art(user, art, record, evicted)
	SSgraffiti.spend_composite(started)
	// A two-tile piece's halves share an id, so the pieces are counted once.
	var/count = length(unique_list(evicted))
	if(count)
		notify(count == 1 ? "Your oldest graffiti on this map went to make room for this piece." : "Your [count] oldest pieces of graffiti on this map went to make room for this one.")
		push()

/**
 * Puts the piece, flattened, on each of its tiles (place_tile()).
 *
 * Arguments:
 * - user: The painter.
 * - art: The flattened piece.
 * - decoded: The art's graffiti_art_decode().
 * - evicted: Filled with the ids of the painter's own placements a new one took past their caps.
 */
/datum/custom_sprite_editor/graffiti/proc/place_art(mob/user, list/art, list/decoded, list/evicted)
	if(workspace.width == GRAFFITI_WIDTH)
		placement = place_tile(placement, surface, art, 0, user, decoded, evicted)
		return
	var/list/halves = list()
	var/list/arts = graffiti_split_wide(art, decoded, halves)
	placement = place_tile(placement, surface, arts[1], 1, user, halves[1], evicted)
	placement2 = place_tile(placement2, get_step(surface, EAST), arts[2], 2, user, halves[2], evicted)

/**
 * Puts one tile's art of the piece on the surface: as new art for the tile's placement, or as a new placement once the
 * art has paint. The halves of a two-tile piece share one placement id. A tile that refuses the paint, as a full map of
 * connected painters' graffiti does, isn't asked again for GRAFFITI_PLACE_RETRY; meanwhile its refusal shows again, and
 * a placement it has keeps its old art.
 *
 * Arguments:
 * - packed: The tile's placement so far, packed, or null.
 * - tile: The tile.
 * - art: The tile's art.
 * - half: 1 or 2 for the left or right half of a two-tile piece, else 0.
 * - user: The painter.
 * - decoded: The art's graffiti_art_decode().
 * - evicted: Filled with the ids of the painter's own placements a new one took past their caps, for apply_live() to
 *   tell the painter once.
 *
 * Returns:
 * - text: The tile's placement now, packed. One that is gone stays as it was, so the session sees it is gone, and so
 *   does one refused its new art.
 * - null: The tile has none: its art has no paint yet, or the surface refused it.
 */
/datum/custom_sprite_editor/graffiti/proc/place_tile(packed, turf/tile, list/art, half, mob/user, list/decoded, list/evicted)
	if(!packed && !length(art["pal"]))
		return null
	var/list/refusal = refusals?["[half]"]
	if(refusal && world.time < refusal[1])
		notify(refusal[2])
		return packed
	var/result
	if(packed)
		result = SSgraffiti.update_placement_art(packed, art, decoded, evicted)
		if(!result)
			return packed
	else
		var/pid = (placement || placement2) && SSgraffiti.unpack(placement || placement2)["pid"]
		result = SSgraffiti.add_placement(tile, art, user.ckey, user.real_name, pid, half, evicted)
	if(SSgraffiti.placement_info[result])
		LAZYREMOVE(refusals, "[half]")
		return result
	var/notice = "Your graffiti can't go there: [result]."
	LAZYSET(refusals, "[half]", list(world.time + GRAFFITI_PLACE_RETRY, notice))
	notify(notice)
	push()
	return packed

/**
 * Returns the graffiti a tile shows beneath this session's piece, which the window draws under the canvas. A stack the
 * decal keeps no merge of, as one shown from its sheet, is merged here, as the session opens, which
 * GRAFFITI_START_COOLDOWN paces, and the decal keeps the merge while the session paints there.
 *
 * Arguments:
 * - tile: The tile.
 * - packed: This session's placement on it, packed, or null.
 *
 * Returns:
 * - list: The merged art of the pieces beneath this session's, or of the whole stack before it has one there.
 * - null: Nothing else shows there, or someone has painted over this session's piece.
 */
/datum/custom_sprite_editor/graffiti/proc/tile_background(turf/tile, packed)
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(tile)
	if(!decal?.render_cache)
		return null
	if(!(packed in decal.stack))
		return decal.stack_merge()
	return decal.stack[length(decal.stack)] == packed ? decal.base_merge() : null

/**
 * Lets go of the spray can as it is deleted. A surface session without it ends at its next check.
 */
/datum/custom_sprite_editor/graffiti/proc/can_gone()
	SIGNAL_HANDLER
	can = null

/**
 * Opens a graffiti editor for a player, ending any editor they already have. A surface session shakes the can.
 *
 * Arguments:
 * - user: The player.
 * - piece: The canonical piece to open, a copy the editor may keep, or null for a blank piece.
 * - piece_id: The library piece it is, or null.
 * - can: The spray can it is opened from, or null.
 * - surface: The wall, floor or window tile to paint live, or a poster's tile, or null for a studio session.
 * - poster: The poster to paint live, on `surface`, or null.
 *
 * Returns:
 * - /datum/custom_sprite_editor/graffiti: The editor, without its window yet.
 */
/proc/graffiti_editor_for(mob/user, list/piece, piece_id, obj/item/toy/crayon/spraycan/can, turf/surface, obj/structure/sign/poster/poster)
	var/datum/custom_sprite_editor/graffiti/editor = SSgraffiti.editors[user.ckey]
	editor?.end_session(user)
	var/datum/preferences/preferences = GLOB.preferences_datums[user.ckey]
	editor = poster ? new /datum/custom_sprite_editor/graffiti/poster(preferences, piece, piece_id, can, surface, poster) : new(preferences, piece, piece_id, can, surface)
	SSgraffiti.editors[user.ckey] = editor
	if(surface)
		graffiti_shake(user)
		log_game("[key_name(user)] started freehand graffiti [poster ? "on [poster] " : ""]at [AREACOORD(surface)]")
	return editor

/**
 * Whether a player may write their graffiti library now, starting a second's wait if so. Each write rewrites and checks
 * the whole file, so the account's saves, imports and exports share the wait, which is kept beside its style transfer
 * cooldowns, and each write lengthens it by its cost (graffiti_library_paced()).
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_library_write_due(ckey)
	if(graffiti_library_write_wait(ckey) > 0)
		return FALSE
	graffiti_library_paced(ckey, 0)
	return TRUE

/**
 * Paces an account's next graffiti library write by the one just made: a player's waits GRAFFITI_LIBRARY_WRITE_PACE
 * times as long as it took, and at least a second, and a change the server makes is held back as long.
 *
 * Arguments:
 * - ckey: The account's ckey.
 * - cost: How long the write took, in milliseconds.
 */
/proc/graffiti_library_paced(ckey, cost)
	GLOB.custom_style_transfers[ckey] ||= list("busy" = FALSE, "import" = 0, "export" = 0)
	GLOB.custom_style_transfers[ckey]["library"] = world.time + max(1 SECONDS, GRAFFITI_LIBRARY_WRITE_PACE * cost MILLISECONDS)

/**
 * Returns how long until an account's graffiti library may be written again.
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - number: The time left, 0 or less once a write is due.
 */
/proc/graffiti_library_write_wait(ckey)
	var/list/state = GLOB.custom_style_transfers[ckey]
	return state?["library"] - world.time

#undef GRAFFITI_PICKED_COLORS
#undef GRAFFITI_COMPOSITE_SPACING
#undef GRAFFITI_COMPOSITE_BUDGET
#undef GRAFFITI_COMPOSITE_SLOW_SPACING
#undef GRAFFITI_PLACE_RETRY
#undef GRAFFITI_SESSION_LIMIT
#undef GRAFFITI_WORK_COMPOSITE
