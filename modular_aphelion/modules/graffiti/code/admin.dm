/// Opens a Graffiti Manager window of the admin's own.
ADMIN_VERB(graffiti_manager, R_ADMIN, "Graffiti Manager", "View and remove custom graffiti.", ADMIN_CATEGORY_MAIN)
	var/datum/graffiti_manager/tgui = new()
	tgui.ui_interact(user.mob)

/// One admin's Graffiti Manager window: the current map's graffiti a page at a time, to find, look at, jump to and delete.
/datum/graffiti_manager
	/// What a listed placement's ckey or painter's character name holds, escaped as character names are kept, or "" to
	/// list them all.
	var/search = ""
	/// The rows' order: "date" for the newest first, "ckey" or "area".
	var/sort = "date"
	/// The page shown, from 1.
	var/page = 1

/**
 * Admins only.
 *
 * Arguments:
 * - user: The admin.
 *
 * Returns:
 * - /datum/ui_state: The admin state.
 */
/datum/graffiti_manager/ui_state(mob/user)
	return ADMIN_STATE(R_ADMIN)

/**
 * Opens the window, or refreshes the open one. It refreshes only after its own actions, as listing the rows reads every
 * placement.
 *
 * Arguments:
 * - user: The admin.
 * - ui: The open window, when tgui refreshes it.
 */
/datum/graffiti_manager/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "GraffitiAdminPanel")
		ui.set_autoupdate(FALSE)
		ui.open()

/**
 * Lists one page of the map's graffiti.
 *
 * Arguments:
 * - user: The admin.
 *
 * Returns:
 * - list: SSgraffiti.admin_rows()'s "rows" and "total", with "search", "sort", "page", "pageSize" and "mapName".
 */
/datum/graffiti_manager/ui_data(mob/user)
	var/list/data = SSgraffiti.admin_rows(search, sort, page)
	// admin_rows() lists the last page for one past it, as after a delete.
	page = min(page, max(1, CEILING(data["total"] / GRAFFITI_ADMIN_PAGE, 1)))
	data["search"] = search
	data["sort"] = sort
	data["page"] = page
	data["pageSize"] = GRAFFITI_ADMIN_PAGE
	data["mapName"] = SSmapping.current_map.map_name
	return data

/**
 * Handles the window's actions. Each deletion asks the admin first, then is logged and told to the other admins with
 * how many placements went. Nothing is deleted while the map's graffiti is still loading.
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
/datum/graffiti_manager/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	// A deletion while SSgraffiti loads would pull placements out from under the load.
	if(!SSgraffiti.loaded && (action in list("delete", "deleteCkeyMap", "deleteCkeyAll", "clearMap", "clearAll")))
		to_chat(user, span_warning("The map's graffiti is still loading. Try again once it has."))
		return
	switch(action)
		if("refresh")
			return TRUE
		if("search")
			if(!istext(params["text"]))
				return
			// Escaped as the character names it is matched against are.
			search = graffiti_clean_text(params["text"], 64)
			page = 1
			return TRUE
		if("sort")
			if(!(params["key"] in list("date", "ckey", "area")))
				return
			sort = params["key"]
			page = 1
			return TRUE
		if("page")
			if(!isnum(params["n"]))
				return
			page = max(1, round(params["n"]))
			return TRUE
		if("jump")
			if(!istext(params["pid"]))
				return
			// The two halves of a wide piece share its id.
			for(var/packed in placements_with("pid", params["pid"]))
				var/obj/effect/decal/cleanable/crayon/custom/decal = SSgraffiti.shown[packed]
				var/turf/tile = decal ? get_turf(decal) : SSgraffiti.placement_turf(SSgraffiti.unpack(packed))
				if(tile)
					user.admin_teleport(tile)
					return
			to_chat(user, span_warning("That graffiti isn't on the map right now."))
			return TRUE
		if("delete")
			var/list/pids = params["pids"]
			if(!islist(pids) || !length(pids) || length(pids) > GRAFFITI_ADMIN_PAGE)
				return
			for(var/pid in pids)
				if(!istext(pid))
					return
			if(!confirm(user, "Delete the [length(pids)] selected graffiti piece\s from this map? A wide piece loses both halves."))
				return
			report(user, "deleted [SSgraffiti.admin_delete(pids)] graffiti placement\s on [SSmapping.current_map.map_name] by id: [html_encode(jointext(pids, ", "))]")
			return TRUE
		if("deleteCkeyMap")
			var/target = istext(params["ckey"]) ? ckey(params["ckey"]) : null
			if(!target)
				return
			if(!confirm(user, "Delete [target]'s [length(placements_with("ckey", target))] graffiti placement\s on this map?"))
				return
			report(user, "deleted [target]'s [SSgraffiti.admin_delete_ckey(target)] graffiti placement\s on [SSmapping.current_map.map_name]")
			return TRUE
		if("deleteCkeyAll")
			var/target = istext(params["ckey"]) ? ckey(params["ckey"]) : null
			if(!target)
				return
			if(!confirm(user, "Delete every graffiti placement by [target] on every map and purge their graffiti library? [length(placements_with("ckey", target))] on this map; other maps are counted when it runs."))
				return
			report(user, "deleted [target]'s [SSgraffiti.admin_delete_ckey_everywhere(target)] graffiti placement\s on every map, and their graffiti library")
			return TRUE
		if("clearMap")
			if(!confirm(user, "Delete all [length(SSgraffiti.placements)] graffiti placement\s on this map?"))
				return
			report(user, "cleared [SSgraffiti.admin_clear_map()] graffiti placement\s from [SSmapping.current_map.map_name]")
			return TRUE
		if("clearAll")
			if(!confirm(user, "Delete every graffiti placement on every map? [length(SSgraffiti.placements)] on this map; other maps are counted when it runs."))
				return
			report(user, "cleared [SSgraffiti.admin_clear_all_maps()] graffiti placement\s from every map")
			return TRUE

/**
 * Asks the admin to confirm a deletion. The question waits for their answer, so this also checks they are still an
 * admin once they give it.
 *
 * Arguments:
 * - user: The admin.
 * - question: What goes, and how much of it.
 *
 * Returns:
 * - TRUE/FALSE: Whether to go ahead.
 */
/datum/graffiti_manager/proc/confirm(mob/user, question)
	return tgui_alert(user, question, "Are you sure?", list("Yes", "No")) == "Yes" && check_rights_for(user?.client, R_ADMIN)

/**
 * Logs an admin's deletion and tells the other admins.
 *
 * Arguments:
 * - user: The admin.
 * - text: What they did, after their name.
 */
/datum/graffiti_manager/proc/report(mob/user, text)
	log_admin("[key_name(user)] [text].")
	message_admins("[key_name_admin(user)] [text].")

/**
 * Returns the map's placements whose field has a value, such as one account's or one piece's.
 *
 * Arguments:
 * - key: The field, such as "ckey" or "pid".
 * - value: Its value.
 *
 * Returns:
 * - list: The packed placements, oldest first.
 */
/datum/graffiti_manager/proc/placements_with(key, value)
	. = list()
	for(var/packed in SSgraffiti.placements)
		var/list/placement = SSgraffiti.unpack(packed)
		if(placement[key] == value)
			. += packed
