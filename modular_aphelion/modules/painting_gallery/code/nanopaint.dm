/// The medium recorded for artwork that was drawn on a device rather than on a real canvas.
#define NANOPAINT_MEDIUM "Digital on nanocanvas"

/datum/computer_file/program/nanopaint
	/// Set while an Art Galaxy transaction is in flight, so one workspace cannot be archived twice over.
	var/persistence_saving = FALSE

/// The canvas dimensions this workspace would be archived at, or null when no canvas has its shape.
/datum/computer_file/program/nanopaint/proc/gallery_canvas_size()
	if(!current_workspace)
		return null
	return GLOB.canvas_dimensions["[current_workspace.width]x[current_workspace.height]"]

/// The sizes Art Galaxy accepts, named as the New Project templates name them.
/datum/computer_file/program/nanopaint/proc/gallery_size_list()
	var/list/sizes = list()
	for(var/size in GLOB.canvas_dimensions)
		sizes += size
	return english_list(sizes)

/// Art Galaxy state for the menu bar; an archive transaction holds the entry until it finishes.
/datum/computer_file/program/nanopaint/proc/add_gallery_data(mob/user, list/data)
	data["galleryBusy"] = persistence_saving
	// The artist's own collection is only worth sending while they are looking through it.
	if(check_dialog(null, "galleryOpen"))
		data["galleryFiles"] = gallery_open_entries(user)

/// Runs before the program's own actions and reports whether this was an Art Galaxy one.
/datum/computer_file/program/nanopaint/proc/handle_gallery_action(action, list/params, datum/tgui/ui)
	switch(action)
		if("galleryOpenDialog")
			dialog = list("type" = "galleryOpen")
			return TRUE
		if("galleryOpen")
			if(!check_dialog(null, "galleryOpen"))
				return TRUE
			dialog = null
			INVOKE_ASYNC(src, PROC_REF(open_gallery_painting), ui.user, params["ref"])
			return TRUE
		if("galleryDialog")
			open_gallery_dialog(ui.user)
			return TRUE
		if("gallerySave")
			if(!check_dialog(null, "gallery") || dialog["busy"] || dialog["message"])
				return TRUE
			INVOKE_ASYNC(src, PROC_REF(save_to_gallery), ui.user, params["title"], params["sign"])
			return TRUE
	return FALSE

/// Offer the archive form, or explain in the same place why this drawing cannot be archived.
/datum/computer_file/program/nanopaint/proc/open_gallery_dialog(mob/user)
	if(!current_workspace)
		return
	if(persistence_saving)
		dialog = list("type" = "error", "message" = "This drawing is already being saved.")
		return
	if(!SSpersistent_paintings.store_writable)
		dialog = list("type" = "error", "message" = "Art Galaxy is not accepting new artwork. Please contact an administrator.")
		return
	if(!gallery_canvas_size())
		dialog = list("type" = "error", "message" = "[current_workspace.width]x[current_workspace.height] is not a canvas size. Art Galaxy accepts [gallery_size_list()].")
		return
	var/datum/painting/source_painting = source_photo_or_painting
	dialog = list(
		"type" = "gallery",
		"defaultTitle" = istype(source_painting) ? source_painting.title : "Untitled Artwork",
		"signature" = user?.real_name,
		"maxTitle" = MAX_NAME_LEN,
		"size" = "[current_workspace.width]x[current_workspace.height]",
	)

/// Archive the open workspace as a private painting in the artist's own My Artwork collection.
/datum/computer_file/program/nanopaint/proc/save_to_gallery(mob/user, title, signed)
	if(persistence_saving || !user?.ckey || !check_dialog(null, "gallery"))
		return
	var/list/size = gallery_canvas_size()
	if(!size)
		return
	var/new_title = reject_bad_name(trim(title, MAX_NAME_LEN), allow_numbers = TRUE, ascii_only = FALSE, strict = TRUE, cap_after_symbols = FALSE)
	if(!new_title)
		dialog = list("type" = "error", "message" = "That title cannot be used.")
		SStgui.update_uis(computer)
		return
	persistence_saving = TRUE
	dialog["busy"] = TRUE
	SStgui.update_uis(computer)
	var/icon/flattened = flatten_for_gallery()
	var/pixels = flattened && painting_pixels_from_icon(flattened, size[1], size[2])
	var/list/result
	if(!pixels)
		result = painting_store_failure("The drawing could not be prepared. Please try again.")
	else
		var/datum/painting/painting = new
		painting.title = new_title
		painting.creator_ckey = user.ckey
		painting.creator_name = signed ? user.real_name : "Anonymous"
		painting.creation_date = time2text(world.realtime, "DDD MMM DD hh:mm:ss YYYY", TIMEZONE_UTC)
		painting.creation_round_id = GLOB.round_id
		painting.width = size[1]
		painting.height = size[2]
		painting.medium = NANOPAINT_MEDIUM
		result = SSpersistent_paintings.run_store_operation("create", list("painting" = painting, "pixels" = pixels))
		if(result["ok"] && result["changed"])
			log_player_image_creation("[key_name(user)] saved \"[new_title]\" ([painting.md5]) to Art Galaxy from [computer]", user, flattened)
	persistence_saving = FALSE
	var/list/error = result["error"]
	var/outcome = !result["ok"] \
		? (error?["message"] || "The painting could not be saved. Please try again.") \
		: (result["changed"] \
			? "Saved to My Artwork. You can publish it to the web gallery from Art Galaxy." \
			: "This image is already in the archive, or was deleted this round.")
	// The artist may have closed the form while the transaction ran; tell them either way.
	if(!check_dialog(null, "gallery"))
		to_chat(user, result["ok"] ? span_notice(outcome) : span_warning(outcome))
		return
	dialog = result["ok"] ? list("type" = "gallery", "message" = outcome) : list("type" = "error", "message" = outcome)
	SStgui.update_uis(computer)

/// The artist's own archived paintings, listed for the gallery's own Open dialog.
/datum/computer_file/program/nanopaint/proc/gallery_open_entries(mob/user, list/owned = SSpersistent_paintings.get_owned_paintings(user?.ckey))
	var/list/entries = list()
	for(var/list/entry as anything in owned)
		entries += list(list("name" = entry["title"], "ref" = entry["ref"], "size" = "[entry["width"]]x[entry["height"]]"))
	return entries

/// The artist's own painting with this reference: a gallery open never reaches anyone else's work.
/datum/computer_file/program/nanopaint/proc/gallery_painting(painting_ref, ckey, list/collection = SSpersistent_paintings.paintings)
	var/datum/painting/painting = locate(painting_ref) in collection
	return ckey && painting?.creator_ckey == ckey ? painting : null

/// Open one of the artist's own paintings as a fresh workspace, keeping the record as the drawing's source.
/datum/computer_file/program/nanopaint/proc/open_gallery_painting(mob/user, painting_ref)
	var/datum/painting/painting = gallery_painting(painting_ref, user?.ckey)
	if(!painting)
		dialog = list("type" = "error", "message" = "That painting is no longer in your collection.")
		SStgui.update_uis(computer)
		return
	if(!fexists("data/paintings/images/[painting.md5].png"))
		dialog = list("type" = "error", "message" = "[painting.title] - the archived image could not be read.")
		SStgui.update_uis(computer)
		return
	var/icon/artwork = painting.get_icon()
	close_workspace()
	current_workspace = new(artwork.Width(), artwork.Height())
	fill_grid_from_icon(current_workspace.get_first_layer_pixel_data(), artwork)
	source_photo_or_painting = painting
	SStgui.update_uis(computer)
/// A painting is a filled canvas, so the layers are flattened over the colour a blank canvas starts at.
/datum/computer_file/program/nanopaint/proc/flatten_for_gallery()
	var/icon/flattened = current_workspace.to_icon()
	if(!flattened)
		return null
	flattened.Blend(/obj/item/canvas::canvas_color, ICON_UNDERLAY)
	return flattened

/// The painting store's pixel string: every pixel of the drawing, row by row, as the canvas grid writes them.
/proc/painting_pixels_from_icon(icon/source, width, height)
	if(source.Width() != width || source.Height() != height)
		return null
	var/list/pixels = list()
	for(var/y in 1 to height)
		for(var/x in 1 to width)
			// The icon is opaque after the underlay, so GetPixel gives "#rrggbb" and never the null of a clear pixel.
			var/pixel = source.GetPixel(x, height + 1 - y)
			pixels += length(pixel) == 7 ? "[pixel]ff" : pixel
	return pixels.Join("")

#undef NANOPAINT_MEDIUM
