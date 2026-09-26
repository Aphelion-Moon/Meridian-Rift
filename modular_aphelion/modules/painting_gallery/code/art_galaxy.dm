#define ART_GALAXY_PAGE_SIZE 24

/// Personal navigation must not be reset by another viewer polling the same PDA.
/datum/art_galaxy_view
	/// Active collection for this authenticated viewer.
	var/tab = "browse"
	/// One-based thumbnail page, bounded when the collection changes.
	var/page = 1
	/// Pixel identity retained across snapshot refreshes.
	var/selected

/datum/computer_file/program/portrait_printer
	/// Lazily allocated navigation by viewer ckey; released when their UI closes.
	var/list/gallery_views

/// Lazily obtain navigation state for the authenticated viewer, independently of other PDA users.
/datum/computer_file/program/portrait_printer/proc/get_gallery_view(owner)
	if(!owner)
		return null
	var/datum/art_galaxy_view/view = gallery_views?[owner]
	if(!view)
		view = new
		LAZYSET(gallery_views, owner, view)
	return view

/// Release the departing viewer's navigation state before normal UI cleanup.
/datum/computer_file/program/portrait_printer/ui_close(mob/user)
	LAZYREMOVE(gallery_views, user?.ckey)
	return ..()

/// Register the program for gallery refreshes after painting transactions.
/datum/computer_file/program/portrait_printer/New()
	. = ..()
	LAZYOR(SSpersistent_paintings.gallery_programs, src)

/// Remove the program from the gallery refresh registry before deletion.
/datum/computer_file/program/portrait_printer/Destroy()
	LAZYREMOVE(SSpersistent_paintings.gallery_programs, src)
	return ..()

/// Offer eligible players a Nova import when opening Art Galaxy, without blocking the UI.
/datum/computer_file/program/portrait_printer/ui_interact(mob/user, datum/tgui/ui)
	if(user?.client)
		INVOKE_ASYNC(SSpersistent_paintings, TYPE_PROC_REF(/datum/controller/subsystem/persistent_paintings, offer_nova_import), user.client)

/// Closed applications keep no rebuilt search payload; an empty result remains a valid cache.
/datum/computer_file/program/portrait_printer/proc/gallery_browse_data()
	if(search_string && isnull(matching_paintings))
		generate_matching_paintings_list()
	return isnull(matching_paintings) ? SSpersistent_paintings.painting_ui_data() : matching_paintings

/// The authenticated viewer owns these controls, independently of the PDA's registered owner.
/datum/computer_file/program/portrait_printer/proc/add_art_galaxy_data(mob/user, list/data)
	var/datum/art_galaxy_view/view = get_gallery_view(user?.ckey)
	if(!view)
		return
	var/list/entries = view.tab == "mine" ? SSpersistent_paintings.get_owned_paintings(user?.ckey) : gallery_browse_data()
	add_gallery_page(data, entries, view, user)
	data["gallery_busy"] = SSpersistent_paintings.store_busy
	data["gallery_error"] = user?.client?.persistent_client?.painting_gallery_error || (SSpersistent_paintings.store_writable ? null : "Painting storage is unavailable. Please contact an administrator.")
	if(view.tab != "mine")
		data["search_string"] = search_string
		data["search_mode"] = search_mode == PAINTINGS_FILTER_SEARCH_TITLE ? "Title" : "Author"
		return
	data["gallery_writable"] = SSpersistent_paintings.store_writable
	data["import_enabled"] = CONFIG_GET(flag/enable_nova_painting_import)
	if(data["import_enabled"])
		data["import_busy"] = !!SSpersistent_paintings.nova_import_busy?[user?.ckey]
		data["import_status"] = SSpersistent_paintings.nova_import_status?[user?.ckey]
		data["can_retry_import"] = SSpersistent_paintings.can_retry_nova_import(user?.client)

/// Project only one detail record or at most 24 thumbnails; shared full catalogs stay server-side.
/datum/computer_file/program/portrait_printer/proc/add_gallery_page(list/data, list/entries, datum/art_galaxy_view/view, mob/user)
	var/total = length(entries)
	var/pages = max(1, CEILING(total / ART_GALAXY_PAGE_SIZE, 1))
	var/index = 0
	if(view.selected)
		for(var/i in 1 to total)
			if(entries[i]["md5"] == view.selected)
				index = i
				break
		if(!index)
			view.selected = null
	if(index)
		view.page = CEILING(index / ART_GALAXY_PAGE_SIZE, 1)
	view.page = clamp(view.page, 1, pages)
	data["gallery_tab"] = view.tab
	data["gallery_page"] = view.page
	data["gallery_pages"] = pages
	data["painting_count"] = total
	data["painting_index"] = index - 1
	data["selected_painting"] = null
	var/list/paintings = list()
	data["paintings"] = paintings
	var/list/page_assets
	if(user?.client)
		get_asset_datum(/datum/asset/simple/portraits)
	var/start = index || ((view.page - 1) * ART_GALAXY_PAGE_SIZE + 1)
	var/end = index || min(total, start + ART_GALAXY_PAGE_SIZE - 1)
	for(var/i in start to end)
		var/list/entry = entries[i]
		var/asset_name = "paintings_[entry["md5"]].png"
		var/datum/asset_cache_item/image = SSassets.cache[asset_name]
		if(!image && user?.client)
			var/png = "data/paintings/images/[entry["md5"]].png"
			if(fexists(png))
				image = SSassets.transport.register_asset(asset_name, png)
		var/list/row = list("title" = entry["title"], "creator" = entry["creator"], "ref" = entry["ref"], "image" = image ? SSassets.transport.get_asset_url(asset_name, image) : null)
		if(image)
			LAZYSET(page_assets, asset_name, image)
		if(view.tab == "mine")
			row["show_in_webgallery"] = entry["show_in_webgallery"]
			row["framed_count"] = entry["framed_count"]
			row["in_rotation"] = entry["in_rotation"]
			if(index)
				row["creation_date"] = entry["creation_date"]
				row["medium"] = entry["medium"]
		if(index)
			data["selected_painting"] = row
		else
			paintings += list(row)
	if(user?.client && length(page_assets) && SSassets.transport.send_assets(user, page_assets))
		user.client?.browse_queue_flush()

/// Resolve navigation against the current authorized collection, never an arbitrary datum reference.
/datum/computer_file/program/portrait_printer/proc/select_gallery_painting(list/params, list/entries, datum/art_galaxy_view/view)
	if(params["selected"])
		for(var/list/entry as anything in entries)
			if(entry["ref"] == params["selected"])
				view.selected = entry["md5"]
				return
	else
		var/index = params["index"]
		if(isnum(index) && index == round(index) && index >= 0 && index < length(entries))
			view.selected = entries[index + 1]["md5"]

/// Called only after the original program's parent action checks have passed.
/datum/computer_file/program/portrait_printer/proc/handle_art_galaxy_action(action, list/params, datum/tgui/ui)
	var/client/player = ui.user?.client
	var/datum/art_galaxy_view/view = get_gallery_view(player?.ckey)
	if(!view)
		return TRUE
	switch(action)
		if("gallery_tab")
			if(params["tab"] in list("browse", "mine"))
				view.tab = params["tab"]
				view.selected = null
				view.page = 1
			return TRUE
		if("gallery_page")
			if(isnum(params["page"]))
				view.page = max(1, round(params["page"]))
				view.selected = null
			return TRUE
		if("gallery_back")
			view.selected = null
			return TRUE
		if("gallery_select")
			var/list/entries = view.tab == "mine" ? SSpersistent_paintings.get_owned_paintings(player?.ckey) : gallery_browse_data()
			select_gallery_painting(params, entries, view)
			return TRUE
		if("search", "change_search_mode")
			view.page = 1
			view.selected = null
			return FALSE
		if("set_webgallery")
			if(!player || !isnum(params["enabled"]) || (params["enabled"] != FALSE && params["enabled"] != TRUE))
				return TRUE
			var/datum/painting/painting = locate(params["selected"]) in SSpersistent_paintings.paintings
			if(!painting || painting.creator_ckey != player.ckey)
				player.persistent_client.painting_gallery_error = "You can only manage your own paintings."
				return TRUE
			player.persistent_client.painting_gallery_error = null
			var/list/result = SSpersistent_paintings.patch_painting(painting, list("show_in_webgallery" = params["enabled"]), player.ckey)
			if(player && !result["ok"])
				player.persistent_client.painting_gallery_error = "The visibility change could not be saved. Please try again."
			if(player && result["ok"] && params["enabled"] == TRUE)
				var/datum/painting/updated_painting = SSpersistent_paintings.paintings_by_id?[painting.md5]
				updated_painting?.award_public_gallery_achievement(player.mob)
			SSpersistent_paintings.refresh_gallery_uis()
			return TRUE
		if("delete_painting")
			if(!player)
				return TRUE
			var/datum/painting/painting = locate(params["selected"]) in SSpersistent_paintings.paintings
			var/owner = player.ckey
			if(!painting || painting.creator_ckey != owner)
				player.persistent_client.painting_gallery_error = "You can only delete your own paintings."
				return TRUE
			var/id = painting.md5
			var/framed_count = 0
			for(var/obj/structure/sign/painting/frame as anything in SSpersistent_paintings.painting_frames)
				if(frame.current_canvas?.painting_metadata.md5 == id)
					framed_count++
			var/warning = "Delete '[painting.title]'? This removes it from My Artwork and the public web gallery."
			warning += " It is currently displayed in [framed_count] frame(s)[length(painting.tags) ? " and is in the station's spawn rotation" : ""]."
			warning += " All framed copies will be removed, and it will no longer spawn in persistent frames. This cannot be undone."
			if(tgui_alert(ui.user, warning, "Delete artwork", list("Delete", "Cancel")) != "Delete")
				return TRUE
			if(!player || ui.user?.client != player || player.ckey != owner)
				return TRUE
			var/list/result = SSpersistent_paintings.run_store_operation("delete", list("id" = id, "owner" = owner))
			if(player)
				player.persistent_client.painting_gallery_error = result["ok"] ? null : SSpersistent_paintings.store_result_message(result)
			if(result["ok"])
				log_game("[owner] deleted their painting [id] from My Artwork, displayed frames, rotation, and web gallery publication.")
			SSpersistent_paintings.refresh_gallery_uis()
			return TRUE
		if("retry_nova_import")
			if(player)
				INVOKE_ASYNC(SSpersistent_paintings, TYPE_PROC_REF(/datum/controller/subsystem/persistent_paintings, offer_nova_import), player, TRUE)
			return TRUE
	return FALSE

#undef ART_GALAXY_PAGE_SIZE
