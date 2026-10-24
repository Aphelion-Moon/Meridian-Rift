/// Shortest time between two freehand sessions or paint jobs one player starts.
#define GRAFFITI_START_COOLDOWN (3 SECONDS)

/obj/item/toy/crayon/spraycan
	/// What a click on a wall, a floor, a full-tile window or a poster paints: null for the stencil, "freehand" for a live editor on it, "unfinished" for the Unfinished slot's piece, or a library piece's id.
	var/graffiti_armed
	/// The window's tab: "stencils" or "graffiti".
	var/graffiti_tab = "stencils"
	/// The graffiti library revision the window's static data last carried, or 0 while it carries none.
	var/graffiti_sent_revision = 0

/**
 * Whether the can paints custom graffiti: every spray can that paints, but not the hellcan, lubecan or mimecan.
 *
 * Returns:
 * - TRUE/FALSE
 */
/obj/item/toy/crayon/spraycan/proc/graffiti_enabled()
	return TRUE

/obj/item/toy/crayon/spraycan/hellcan/graffiti_enabled()
	return FALSE

/obj/item/toy/crayon/spraycan/lubecan/graffiti_enabled()
	return FALSE

/obj/item/toy/crayon/spraycan/mimecan/graffiti_enabled()
	return FALSE

/**
 * Adds the player's graffiti library to the window's static data while the Custom Graffiti tab is open, and only then:
 * 50 pieces' thumbnails take 40 KB as typical art and up to 1.5 MB as adversarial art, which a window open on the
 * stencils would carry for nothing. It is sent again once the library changes or the tab opens.
 *
 * Arguments:
 * - user: The player.
 *
 * Returns:
 * - list: The static data, with "graffitiLibrary": "entries", "unfinished", "count", "cap" and "defaultPalette" while
 *   the tab is open.
 */
/obj/item/toy/crayon/spraycan/ui_static_data(mob/user)
	. = ..()
	graffiti_sent_revision = 0
	var/datum/graffiti_library/library = graffiti_enabled() && graffiti_tab == "graffiti" ? graffiti_library(user.ckey) : null
	if(!library)
		return
	graffiti_sent_revision = library.revision
	.["graffitiLibrary"] = list(
		"entries" = library.entries(),
		"unfinished" = library.unfinished_entry(),
		"count" = length(library.pieces),
		"cap" = GRAFFITI_LIBRARY_CAP,
		"defaultPalette" = graffiti_default_palette(),
	)

/**
 * Adds the can's graffiti state to the window's data.
 *
 * Arguments:
 * - user: The player.
 *
 * Returns:
 * - list: The data, with "graffiti": "armed", "armedName", "tab" and "hasEditor".
 */
/obj/item/toy/crayon/spraycan/ui_data(mob/user)
	. = ..()
	if(!graffiti_enabled())
		return
	.["graffiti"] = list(
		"armed" = graffiti_armed,
		"armedName" = graffiti_armed_name(user),
		"tab" = graffiti_tab,
		"hasEditor" = !!SSgraffiti.editors[user.ckey],
	)

/**
 * Opens the window, or refreshes the open one. Opening it afresh clears what the can was set to paint. A refresh after
 * the player's graffiti library changed sends the static data too, which carries the library, while its tab is open.
 *
 * Arguments:
 * - user: The player.
 * - ui: The open window, when tgui refreshes it.
 */
/obj/item/toy/crayon/spraycan/ui_interact(mob/user, datum/tgui/ui)
	if(!ui && !SStgui.get_open_ui(user, src))
		graffiti_armed = null
	var/datum/graffiti_library/library = ui && graffiti_enabled() && graffiti_tab == "graffiti" ? graffiti_library(user.ckey) : null
	if(!library || library.revision == graffiti_sent_revision)
		return ..()
	ui.process_status()
	if(ui.status <= UI_CLOSE)
		ui.close()
		return
	ui.send_full_update()

/**
 * Handles the Custom Graffiti tab's actions, after the crayon's own. Picking a stencil also clears what the can was set
 * to paint.
 *
 * Arguments:
 * - action: The action.
 * - params: Its params, as the window sent them.
 * - ui: The window.
 * - state: The window's state.
 *
 * Returns:
 * - TRUE/FALSE: Whether the window updates.
 */
/obj/item/toy/crayon/spraycan/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(!graffiti_enabled())
		return
	if(action == "select_stencil" && drawtype == params["item"])
		graffiti_armed = null
	if(.)
		return
	var/mob/user = ui.user
	var/datum/graffiti_library/library = graffiti_library(user.ckey)
	if(!library)
		return
	var/id = params["id"]
	switch(action)
		if("graffitiTab")
			var/tab = params["tab"]
			if(!(tab in list("stencils", "graffiti")))
				return FALSE
			graffiti_tab = tab
			// The library travels with its tab, as static data: sent as the tab opens, or within the second tgui paces full
			// updates by. The tab itself goes at once, and a window shows the library it last had meanwhile.
			if(tab == "graffiti")
				ui.send_full_update()
			return TRUE
		if("graffitiArm")
			if(!istext(id) || !(id in library.pieces))
				return FALSE
			graffiti_armed = id
			return TRUE
		if("graffitiFreehand")
			graffiti_armed = "freehand"
			return TRUE
		if("graffitiResume")
			if(!library.unfinished)
				return FALSE
			graffiti_armed = "unfinished"
			return TRUE
		if("graffitiDisarm")
			graffiti_armed = null
			return TRUE
		if("graffitiNew")
			graffiti_open_editor(user, null, null)
			return TRUE
		if("graffitiEdit")
			if(!istext(id) || !library.piece(id))
				return FALSE
			graffiti_open_editor(user, graffiti_copy_piece(library.piece(id)), id)
			return TRUE
		if("graffitiDelete", "graffitiRename", "graffitiExport", "graffitiImport", "graffitiKeep", "graffitiDiscard")
			// Each rewrites and checks the whole library file, or shares the account's transfer slot.
			if(!graffiti_library_write_due(user.ckey))
				balloon_alert(user, "wait a moment!")
				return FALSE
			var/error
			switch(action)
				if("graffitiDelete")
					error = library.delete_piece(id) ? null : "That graffiti piece couldn't be deleted."
					if(!error && graffiti_armed == id)
						graffiti_armed = null
				if("graffitiRename")
					// graffiti_clean_text() makes anything else "", which would name the piece Untitled and wipe its description.
					if(!istext(params["name"]) || !istext(params["description"]))
						return FALSE
					var/renamed = library.rename_piece(id, params["name"], params["description"])
					error = istext(renamed) ? renamed : null
				if("graffitiExport")
					error = graffiti_export(user, id)
				if("graffitiImport")
					// Sleeps while the file dialog is open.
					error = graffiti_import(user)
					if(QDELETED(src))
						return FALSE
				if("graffitiKeep")
					id = library.keep_unfinished()
					if(id in library.pieces)
						if(graffiti_armed == "unfinished")
							graffiti_armed = null
						graffiti_open_editor(user, graffiti_copy_piece(library.piece(id)), id)
						return TRUE
					error = id
				if("graffitiDiscard")
					error = library.discard_unfinished() ? null : "There's no unfinished graffiti to discard."
					if(!error && graffiti_armed == "unfinished")
						graffiti_armed = null
			if(error)
				to_chat(user, span_warning(error))
			return TRUE

/**
 * Paints with an armed can. A click on an adjacent wall or floor, a full-tile window fastened down, or graffiti on one,
 * on the static station (graffiti_static_station(), else "can't paint here!" and the can stays armed), opens a freehand
 * session there, continues a freehand draft on its own tile, or starts a paint job of the armed piece, and a session or
 * job that starts uses the arming up. An Unfinished piece whose paint still shows goes on only there: a click on
 * another surface is refused ("wrong wall!") and starts no cooldown. Each attempt waits out GRAFFITI_START_COOLDOWN
 * from the last, refused or not, and is refused before any costly work: by an empty can, a paint job already running,
 * or a two-tile piece without a surface like this one to the right. A two-tile piece that paints nothing on its right
 * tile paints one tile. A click on a poster that isn't ripped paints over the poster itself, one painter at a time, and
 * only on its own pixels; it takes no two-tile piece ("too wide!"), and nothing resumes there. A click on anything else
 * clears the arming and sprays as usual, as does an unarmed can, which tints a window or a poster.
 *
 * Arguments:
 * - target: What was clicked.
 * - user: The painter.
 * - modifiers: The click's modifiers.
 *
 * Returns:
 * - ITEM_INTERACT_SUCCESS or ITEM_INTERACT_BLOCKING, as the parent returns them.
 */
/obj/item/toy/crayon/spraycan/use_on(atom/target, mob/user, list/modifiers)
	if(!graffiti_armed || !graffiti_enabled())
		return ..()
	var/obj/structure/sign/poster/poster = istype(target, /obj/structure/sign/poster) ? target : null
	var/obj/structure/window/window = target
	// Graffiti, a full-tile window and a poster stand for the tile they are on.
	var/turf/surface = (poster || istype(target, /obj/effect/decal/cleanable) || (istype(window) && window.fulltile)) ? target.loc : target
	// Where refusals show: the poster, or the tile.
	var/atom/spot = poster || surface
	var/datum/graffiti_library/library = graffiti_library(user.ckey)
	if(!library || !isturf(surface) || !(poster || graffiti_surface_kind(surface)) || !user.Adjacent(surface))
		graffiti_armed = null
		balloon_alert(user, "graffiti disarmed")
		return ..()
	if(is_capped)
		return ..()
	// The map's graffiti loads in the background from the lobby on, and nothing is placed before it has. A poster's never
	// goes in the map's.
	if(!poster && !SSgraffiti.loaded)
		surface.balloon_alert(user, "graffiti still loading!")
		return ITEM_INTERACT_BLOCKING
	// Graffiti goes on the station as the map built it only: not other levels, ruins, bitrunning or maploaded rooms.
	if(poster ? (poster.ruined || !graffiti_static_station(surface)) : !graffiti_surface_ok(surface))
		spot.balloon_alert(user, "can't paint here!")
		return ITEM_INTERACT_BLOCKING
	// While the Unfinished piece's paint still shows, it resumes there and nowhere else: either tile of a wide one.
	if(graffiti_armed == "unfinished")
		var/turf/home = graffiti_resume_tile(library.unfinished?["resume"], user.ckey)
		if(home && (poster || surface != home))
			if(poster || surface != get_step(home, EAST) || library.unfinished["resume"]["width"] != GRAFFITI_WIDE_WIDTH || !user.Adjacent(home))
				spot.balloon_alert(user, "wrong [poster ? "poster" : graffiti_surface_kind(surface)]!")
				return ITEM_INTERACT_BLOCKING
			surface = home
	if(world.time < SSgraffiti.start_cooldowns[user.ckey])
		balloon_alert(user, "wait a moment!")
		return ITEM_INTERACT_BLOCKING
	SSgraffiti.start_cooldowns[user.ckey] = world.time + GRAFFITI_START_COOLDOWN
	if(check_empty(user))
		return ITEM_INTERACT_BLOCKING
	if(SSgraffiti.paint_jobs[user.ckey])
		balloon_alert(user, "already painting!")
		return ITEM_INTERACT_BLOCKING
	if(poster)
		// One painter at a time; the painter's own session there gives way to the new one.
		if(poster.graffiti_painter && poster.graffiti_painter != SSgraffiti.editors[user.ckey])
			poster.balloon_alert(user, "someone's painting it!")
			return ITEM_INTERACT_BLOCKING
		// Read from the poster's icon, after the cooldown, as it reads every pixel the first time.
		if(!graffiti_poster_look(poster))
			poster.balloon_alert(user, "can't paint here!")
			return ITEM_INTERACT_BLOCKING
	var/list/piece
	var/list/resume
	switch(graffiti_armed)
		if("freehand")
			graffiti_armed = null
			graffiti_open_editor(user, null, null, surface, null, poster)
			return ITEM_INTERACT_SUCCESS
		if("unfinished")
			piece = library.unfinished?["piece"]
			if(!piece)
				graffiti_armed = null
				balloon_alert(user, "nothing to resume!")
				return ITEM_INTERACT_BLOCKING
			resume = library.unfinished["resume"]
			// A freehand draft goes back in the editor, and continues only on its own tile, so it never appears at once on another.
			if(resume?["progress"] == -1)
				var/list/kept
				if(!poster)
					var/list/art = graffiti_flatten(piece)
					kept = graffiti_resume_placements(resume, surface, piece["width"] == GRAFFITI_WIDE_WIDTH ? graffiti_split_wide(art) : list(art))
				if(kept)
					log_game("[key_name(user)] resumed freehand graffiti, placement [resume["pid"]], at [AREACOORD(surface)]")
				graffiti_armed = null
				graffiti_open_editor(user, kept && graffiti_copy_piece(piece), null, surface, kept, poster)
				return ITEM_INTERACT_SUCCESS
		else
			piece = library.piece(graffiti_armed)
			if(!piece)
				graffiti_armed = null
				balloon_alert(user, "that graffiti is gone!")
				return ITEM_INTERACT_BLOCKING
	// A two-tile piece with nothing on its right tile paints one. A poster takes one tile.
	piece = graffiti_trim_wide(piece)
	if(piece["width"] == GRAFFITI_WIDE_WIDTH && (poster || !graffiti_wide_ok(surface)))
		spot.balloon_alert(user, poster ? "too wide!" : "no room!")
		return ITEM_INTERACT_BLOCKING
	var/datum/graffiti_paint_job/job = poster ? new /datum/graffiti_paint_job/poster(user, src, surface, graffiti_copy_piece(piece), resume, graffiti_armed, poster) : new(user, src, surface, graffiti_copy_piece(piece), resume, graffiti_armed)
	if(!job.start())
		qdel(job)
		return ITEM_INTERACT_BLOCKING
	graffiti_armed = null
	return ITEM_INTERACT_SUCCESS

/**
 * Adds what an armed can paints to its examine. Only its holder, whose library the armed piece is from, sees it named.
 *
 * Arguments:
 * - user: The examiner.
 *
 * Returns:
 * - list: The examine lines.
 */
/obj/item/toy/crayon/spraycan/examine(mob/user)
	. = ..()
	if(!graffiti_enabled() || !graffiti_armed)
		return
	if(!user.is_holding(src))
		. += span_notice("It is set to paint a piece of graffiti.")
		return
	var/label = graffiti_armed == "freehand" ? "freehand" : (graffiti_armed_name(user) || "a piece of graffiti")
	. += span_notice("It is set to paint [label] — click a wall, floor, full-tile window or poster.")

/**
 * Swaps the can's window for a graffiti editor, which reuses its place on screen.
 *
 * Arguments:
 * - user: The player.
 * - piece: A copy of the canonical piece to open, or null for a blank one.
 * - piece_id: The library piece it is, or null.
 * - surface: The wall, floor or window tile to paint live, or a poster's tile, or null for a studio session.
 * - kept: The placements a freehand draft left on the surface, from graffiti_resume_placements(), which the session goes
 *   on painting, or null.
 * - poster: The poster to paint live, or null.
 */
/obj/item/toy/crayon/spraycan/proc/graffiti_open_editor(mob/user, list/piece, piece_id, turf/surface = null, list/kept = null, obj/structure/sign/poster/poster = null)
	SStgui.close_uis(src)
	var/datum/custom_sprite_editor/graffiti/editor = graffiti_editor_for(user, piece, piece_id, src, surface, poster)
	if(kept)
		editor.placement = kept[1]
		editor.placement2 = kept[2]
	editor.ui_interact(user)

/**
 * Opens the can's window on a tab, as a graffiti editor hands back to it.
 *
 * Arguments:
 * - user: The player.
 * - tab: "stencils" or "graffiti".
 */
/obj/item/toy/crayon/spraycan/proc/graffiti_reopen(mob/user, tab)
	graffiti_tab = tab
	ui_interact(user)

/**
 * Returns a copy of a canonical piece that shares no list with it, such as one to hand on from a library, which keeps
 * its own. deep_copy_list() would turn the list of layers into an associative list.
 *
 * Arguments:
 * - piece: The piece.
 *
 * Returns:
 * - list: The copy.
 */
/proc/graffiti_copy_piece(list/piece)
	return json_decode(json_encode(piece))

/**
 * Returns the name of the piece the can is armed with, from the library of the player holding it.
 *
 * Arguments:
 * - user: The player.
 *
 * Returns:
 * - text: The piece's name, escaped as the library keeps it.
 * - null: The can paints freehand or isn't armed, the player isn't holding it, or the library no longer has the piece.
 */
/obj/item/toy/crayon/spraycan/proc/graffiti_armed_name(mob/user)
	// Anyone else's library holds other pieces, and isn't loaded for them.
	if(!user?.is_holding(src))
		return null
	var/datum/graffiti_library/library = graffiti_library(user.ckey)
	var/list/entry = graffiti_armed == "unfinished" ? library?.unfinished?["piece"] : library?.piece(graffiti_armed)
	return entry?["name"]

#undef GRAFFITI_START_COOLDOWN
