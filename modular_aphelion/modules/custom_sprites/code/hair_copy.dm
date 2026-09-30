// Copy all (Ctrl+Shift+C) copies the native base under a selection. An editor keeps at most one pending
// request, one rendered base frame and the palette of the copy it last handed out.
/datum/custom_sprite_editor
	/// The validated copy request waiting for deferred work, tagged with the base look it was made on; null when none waits.
	var/list/base_copy_request
	/// Weak reference to the tgui window that asked for base_copy_request, which the result is sent to.
	var/datum/weakref/base_copy_ui
	/// Rows of colour strings of one view of the native base, as render_base_copy_frame() drew it. Reused while base_copy_frame_key matches.
	var/list/base_copy_frame
	/// What base_copy_frame was drawn from: the guide look, the view and the canvas size.
	var/base_copy_frame_key
	/// The colours the last finished copy handed out: the only new colours pasting it may add to the palette.
	var/list/base_copy_colors
	/// The window's request number of the last finished copy. Pasting it must quote this and this editor's ref.
	var/base_copy_token

/// Captures native hair alone before its live gradient and opacity, on a private editor head only.
/obj/item/bodypart/head/proc/custom_sprite_copy_base_hair(direction, width, height, list/lift)
	if(!istype(owner, /mob/living/carbon/human/dummy))
		return null
	var/list/old_paint = custom_hair
	var/list/old_gradients = gradient_styles
	var/old_alpha = hair_alpha
	var/old_block = blocks_emissive
	var/mob/living/carbon/human/dummy/body = owner
	var/old_glow = body.emissive_hair
	var/list/overlays
	var/exception/failure
	custom_hair = null
	gradient_styles = null
	hair_alpha = 255
	blocks_emissive = EMISSIVE_BLOCK_NONE
	body.emissive_hair = FALSE
	try
		overlays = get_base_hair_overlays(FALSE)
	catch(var/exception/error)
		failure = error
	custom_hair = old_paint
	gradient_styles = old_gradients
	hair_alpha = old_alpha
	blocks_emissive = old_block
	body.emissive_hair = old_glow
	if(failure)
		throw failure
	var/image/look = image('icons/blanks/32x32.dmi', "nothing")
	look.overlays = overlays
	return custom_sprite_flat_icon(look, direction, width, height, lift[1], lift[2])

/// Validate a bounded selection envelope before retaining it or reading any pixels.
/datum/custom_sprite_editor/proc/validated_base_copy(list/params)
	if(!(target == "hair" || istype(src, /datum/custom_sprite_editor/markings)) || !resources_ready || !islist(params) || !(params["dir"] in GLOB.custom_style_directions))
		return null
	var/request = params["request"]
	var/list/rect = params["rect"]
	if(!isnum(request) || request < 1 || request > 1000000000 || round(request) != request || !islist(rect) || length(rect) != 4)
		return null
	for(var/value in rect)
		if(!isnum(value) || round(value) != value || abs(value) > max(workspace.width, workspace.height))
			return null
	var/width = rect[3] - rect[1] + 1
	var/height = rect[4] - rect[2] + 1
	if(width < 1 || height < 1 || width > max(workspace.width, workspace.height) || height > max(workspace.width, workspace.height) || width * height > workspace.width * workspace.height)
		return null
	var/list/mask = params["mask"]
	if(!isnull(mask))
		if(!islist(mask) || length(mask) != height)
			return null
		for(var/row in mask)
			if(!istext(row) || length(row) != width || length(replacetext(replacetext(row, "0", ""), "1", "")))
				return null
	return list("request" = request, "dir" = params["dir"], "rect" = rect.Copy(), "mask" = mask?.Copy())

/// Copy requests use the existing deferred work queue and never change paint, history or saves.
/datum/custom_sprite_editor/proc/request_base_copy(list/params, datum/tgui/ui)
	var/list/request = validated_base_copy(params)
	if(!request || !can_edit(ui?.user) || (request["dir"] in locked_directions()))
		transfer_error = "The base layer cannot be copied from this selection right now."
		return TRUE
	request["look"] = base_copy_context()
	base_copy_request = request
	base_copy_ui = WEAKREF(ui)
	transfer_error = null
	notify("Copying...")
	request_base_copy_work()
	return TRUE

/// Return one selected base frame as palette indexes; body, beard and custom paint are never sampled.
/datum/custom_sprite_editor/proc/build_base_copy(list/params)
	sync_locked_views(push = FALSE)
	var/list/request = validated_base_copy(params)
	if(!request || !base_copy_ready() || (request["dir"] in locked_directions()))
		transfer_error = "Wait for the base to finish changing, then press Ctrl+Shift+C again."
		return null
	if(workspace.tint != "#ffffff")
		transfer_error = "This legacy drawing uses a color multiplier. Base copying requires a literal-color drawing."
		return null
	var/key = "[REF(guide_appearance)]|[request["dir"]]|[workspace.width]|[workspace.height]"
	var/list/lift = base_copy_origin()
	if(key != base_copy_frame_key)
		base_copy_frame = render_base_copy_frame(request["dir"])
		if(!base_copy_frame)
			transfer_error ||= "The base layer pixels are unavailable."
			return null
		base_copy_frame_key = key
	var/list/rect = request["rect"]
	var/list/mask = request["mask"]
	var/list/colors = list()
	var/list/indices = list()
	var/list/codes = list()
	for(var/y in 0 to workspace.height - 1)
		var/list/row = base_copy_frame[y + 1]
		for(var/x in 0 to workspace.width - 1)
			var/color = row[x + 1]
			if(x < rect[1] || x > rect[3] || y < rect[2] || y > rect[4] || (mask && copytext(mask[y - rect[2] + 1], x - rect[1] + 1, x - rect[1] + 2) != "1"))
				codes += "0"
				continue
			if(!workspace.is_point_allowed(x, y, request["dir"]) && (workspace.is_painted(x, y, request["dir"]) || !(length(color) == 9 && endswith(color, "00"))))
				transfer_error = "This selection includes a locked region. Select only editable regions."
				return null
			if(length(color) == 9 && endswith(color, "00"))
				codes += "0"
				continue
			// Drawings have no partial alpha, so a partially transparent base pixel is copied solid in its own colour.
			color = custom_sprite_color(copytext(color, 1, 8))
			if(!indices[color])
				colors += color
				if(length(colors) > CUSTOM_SPRITE_MAX_COLORS)
					transfer_error = "This selection needs more than 63 colors. Copy a smaller area."
					return null
				indices[color] = length(colors)
			codes += copytext(CUSTOM_SPRITE_INDEX_ALPHABET, indices[color] + 1, indices[color] + 2)
	if(!base_copy_colors_fit(colors))
		transfer_error = "This copy and your drawing's undo history need more than 63 colors."
		return null
	base_copy_colors = colors
	base_copy_token = request["request"]
	var/list/palette = list("#00000000")
	for(var/color in colors)
		palette += "[color]ff"
	transfer_error = null
	return list("request" = base_copy_token, "source" = REF(src), "origin" = lift.Copy(), "width" = workspace.width, "height" = workspace.height, "palette" = palette, "codes" = jointext(codes, ""))

/// Finish at the normal costly-work pace; recheck the owner, locks and captured look after waiting.
/datum/custom_sprite_editor/proc/finish_base_copy()
	if(!base_copy_request)
		return TRUE
	var/datum/tgui/ui = base_copy_ui?.resolve()
	if(QDELETED(ui) || !can_edit(ui.user))
		base_copy_request = null
		base_copy_ui = null
		return TRUE
	var/datum/custom_sprite_pace/pace = pace()
	if(!pace.due())
		return FALSE
	pace.start()
	var/list/request = base_copy_request
	base_copy_request = null
	base_copy_ui = null
	var/list/result
	if(request["look"] == base_copy_context())
		result = build_base_copy(request)
	else
		transfer_error = "The base changed before copying finished. Press Ctrl+Shift+C again."
	if(!result)
		result = list("request" = request["request"], "error" = TRUE)
	// The window says Copied itself once the pixels reach its clipboard.
	transfer_notice = null
	// This one-off update is merged by TGUI. Ordinary drawing updates never resend these pixels.
	ui.send_update(list("baseCopyResult" = result, "transferError" = transfer_error, "transferNotice" = transfer_notice))
	return TRUE

/// Admit only colors sampled by this editor; the existing move parser still validates every placed pixel.
/datum/custom_sprite_editor/proc/prepare_base_copy_paste(list/transaction)
	sync_locked_views(push = FALSE)
	if(!(target == "hair" || istype(src, /datum/custom_sprite_editor/markings)) || transaction["type"] != "move" || transaction["baseCopy"] != base_copy_token || isnull(base_copy_token) || transaction["baseCopySource"] != REF(src))
		transfer_error = "That copy has expired. Select the area again and press Ctrl+Shift+C."
		return FALSE
	if(!base_copy_colors_fit(base_copy_colors))
		transfer_error = "Pasting these colors and retaining undo history would exceed 63 colors."
		return FALSE
	var/list/old_palette = workspace.palette
	workspace.update_palette(base_copy_colors | old_palette)
	if(!base_copy_placement_valid(transaction))
		workspace.palette = old_palette
		return FALSE
	return TRUE

/// The rendered base settings, captured with a request to reject work made stale by a later change.
/datum/custom_sprite_editor/proc/base_copy_context()
	return json_encode(workspace.hair_context)

/// Whether the resource snapshot still matches the current base settings.
/datum/custom_sprite_editor/proc/base_copy_ready()
	return resources_hair == base_copy_context()

/// Hair pixels use the same movable origin as its guide; markings override this with body coordinates.
/datum/custom_sprite_editor/proc/base_copy_origin()
	return guide_lift || list(0, 0)

/// One native base hair frame; the markings editor overrides only this sampling step.
/datum/custom_sprite_editor/proc/render_base_copy_frame(direction)
	var/obj/item/bodypart/head/head = preview_body?.get_bodypart(BODY_ZONE_HEAD)
	var/icon/hair = head?.custom_sprite_copy_base_hair(text2num(direction), workspace.width, workspace.height, base_copy_origin())
	if(!hair)
		return null
	. = list()
	for(var/y in 1 to workspace.height)
		var/list/row = list()
		for(var/x in 1 to workspace.width)
			row += hair.GetPixel(x, workspace.height - y + 1) || "#00000000"
		. += list(row)

/// Existing multi-region colors remain usable; only new colors need room in the shared admission pool.
/datum/custom_sprite_editor/proc/base_copy_colors_fit(list/colors)
	var/list/kept = workspace.kept_colors()
	return !length(colors - kept) || length(kept | colors) <= CUSTOM_SPRITE_MAX_COLORS

/// Regional editors additionally check that this placement still fits every affected region's saved palette.
/datum/custom_sprite_editor/proc/base_copy_placement_valid(list/transaction)
	return TRUE
