#define CUSTOM_SPRITE_MIRROR_TIMEOUT (120 SECONDS)

/// This body's worn clothing overlays, in layer order. Held items are left out.
/proc/custom_sprite_worn_overlays(mob/living/carbon/human/source)
	. = list()
	for(var/layer in GLOB.worn_overlay_layers)
		if(layer == HANDS_LAYER)
			continue
		var/overlays = source?.overlays_standing?[layer]
		if(overlays)
			. += overlays

/**
 * A body without its hair, so nothing hanging off the head covers the limb being drawn on.
 *
 * A copied appearance holds appearances, not the images they were built from, so subtracting the
 * mob's own hair overlays silently does nothing. Dropping the layer through the mob and putting it
 * straight back does, and nothing else reads the body in between.
 */
/proc/custom_sprite_limb_appearance(mob/living/carbon/human/body)
	var/list/hair = body.overlays_standing[HAIR_LAYER]
	if(!length(hair))
		return new /mutable_appearance(body.appearance)
	body.remove_overlay(HAIR_LAYER)
	var/mutable_appearance/appearance = new(body.appearance)
	body.overlays_standing[HAIR_LAYER] = hair
	body.apply_overlay(HAIR_LAYER)
	return appearance

/**
 * The looks that can hide paint: the hair, then every mutant part drawn on the body. Each look
 * carries its images, offset the way get_limb_icon() draws them, the highest layer it draws on
 * and a label for the window. Looks come lowest layer first, so stamping them in order leaves the
 * topmost part at each pixel. Parts behind the body, hidden parts, the taur body (which carries
 * its own paint) and emissive images are left out. `key`, when given, collects what each look is
 * drawn from and where it lands, so rows flattened from these looks can be cached by geometry.
 */
/proc/custom_sprite_cover_looks(mob/living/carbon/human/body, list/key)
	var/list/looks = list()
	if(key)
		key += body.mob_height
	var/list/hair = body.overlays_standing[HAIR_LAYER]
	if(length(hair))
		var/list/images = list()
		var/top = -INFINITY
		for(var/mutable_appearance/strand as anything in hair)
			if(PLANE_TO_TRUE(strand.plane) == EMISSIVE_PLANE)
				continue
			images += strand
			top = max(top, strand.layer)
			if(key)
				key += custom_sprite_placement_key(strand)
		if(length(images))
			looks += list(list("label" = "hair", "layer" = top, "images" = images))
		if(key)
			key += custom_sprite_hair_cover_key(body)
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		for(var/datum/bodypart_overlay/mutant/part in limb.bodypart_overlays)
			if(istype(part, /datum/bodypart_overlay/mutant/taur_body) || !part.can_draw_on_bodypart(limb, body))
				continue
			var/list/images = list()
			var/top = -INFINITY
			for(var/mutable_appearance/image as anything in part.get_all_overlays(limb))
				if(PLANE_TO_TRUE(image.plane) == EMISSIVE_PLANE)
					continue
				body.apply_height(image, part.offset_location)
				images += image
				top = max(top, image.layer)
				if(key)
					key += custom_sprite_placement_key(image)
			if(!length(images))
				continue
			looks += list(list("label" = replacetext(part.feature_key, "_", " "), "layer" = top, "images" = images))
			if(key)
				// The part's render key names its art; generated icons have no path to key by.
				key += list(json_encode(part.icon_render_key(limb)), "[limb.limb_gender]|[part.offset_location]")
	// Lowest look first: the last one stamped on a pixel is the one on top.
	var/list/sorted = list()
	for(var/list/look as anything in looks)
		var/position = 1
		while(position <= length(sorted))
			var/list/other = sorted[position]
			if(other["layer"] > look["layer"])
				break
			position++
		sorted.Insert(position, list(look))
	return sorted

/// The look the head's hair images were built from: those icons are generated at runtime and can't be keyed by path.
/proc/custom_sprite_hair_cover_key(mob/living/carbon/human/body)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	var/list/masks = list()
	for(var/datum/hair_mask/mask as anything in body.hair_masks)
		masks += "[mask.type]"
	var/list/hair_paint = head?.custom_head_drawing("hair")
	var/list/facial_paint = head?.custom_head_drawing("facial_hair")
	return json_encode(list(custom_style_live_hair_context(body, "hair"), custom_style_live_hair_context(body, "facial_hair"), custom_sprite_hash(hair_paint), custom_sprite_hash(facial_paint), masks))

/// Where an image lands when flattened: its offsets and layer. Its art is keyed separately.
/proc/custom_sprite_placement_key(mutable_appearance/image)
	return "[image.pixel_x]|[image.pixel_y]|[image.pixel_w]|[image.pixel_z]|[image.layer]"

/// A body's look with worn overlays added, captured so its views can be flattened one at a time.
/proc/custom_sprite_preview_appearance(mob/living/carbon/human/body, list/worn_overlays)
	var/mutable_appearance/appearance = new(body.appearance)
	if(length(worn_overlays))
		appearance.overlays += worn_overlays
	return appearance

/// The canvas width a body's previews are flattened at: a taur organ widens it.
/proc/custom_sprite_preview_width(mob/living/carbon/human/body)
	return custom_sprite_taur_overlay(body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32

/// One view of a captured look as a data URL, published through the callback when one is given.
/proc/custom_sprite_render_view(mutable_appearance/appearance, direction, width, datum/callback/publish, height = 32)
	var/icon/rendered = custom_sprite_flat_icon(appearance, direction, width, height)
	return publish ? publish.Invoke(rendered) : "data:image/png;base64,[icon2base64(rendered)]"

/// Front, Back, Right and Left data URLs of a captured look, without flipping any view.
/proc/custom_sprite_render_views(mutable_appearance/appearance, width, datum/callback/publish, height = 32)
	. = list()
	for(var/direction in GLOB.cardinals)
		.["[direction]"] = custom_sprite_render_view(appearance, direction, width, publish, height)

/// The canvas height a body's pictures need: taller while its hair drawing reaches above the head.
/proc/custom_sprite_preview_height(mob/living/carbon/human/body)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	return custom_sprite_height(head?.custom_hair)

/**
 * The recipient's mirror.
 *
 * In approval mode it shows the live look beside an exact proposed revision. Closing, declining
 * or letting it expire never implies acceptance. Permanent acceptance saves only after successful
 * application. Exporting the reviewed proposal doesn't apply it or change preferences.
 */
/datum/custom_sprite_mirror
	/// Salon session awaiting approval; null in the completed result window.
	var/datum/custom_sprite_salon/session
	/// Account bound to this mirror's approval and save actions.
	var/recipient_ckey
	/// Weak reference to the body being styled.
	var/datum/weakref/recipient_ref
	/// Exact proposal revision that Accept is allowed to approve.
	var/token
	/// Drawing kind shown in this mirror.
	var/target
	/// Region labels the proposal or result changes, for a tattoo.
	var/list/changes
	/// Whether the proposal restores the previous round style.
	var/restoration = FALSE
	/// Display name captured for the recipient's prompt.
	var/artist_name
	/// Direction -> image of the recipient before the proposal.
	var/list/before_urls
	/// Direction -> image of the exact proposed appearance.
	var/list/after_urls
	/// World time when an unanswered proposal expires.
	var/expires_at
	/// Result mode: style key -> each applied package.
	var/list/packages
	/// Recipient's spawned character slot eligible for a permanent save.
	var/slot
	/// Result status shown after a permanent save attempt.
	var/save_state
	/// Explanation accompanying the permanent save result.
	var/save_message
	/// Whether the latest save or export message reports a failure.
	var/message_error = FALSE
	/// Pending redraw after the recipient's look changed while they decide.
	var/refresh_timer
	/// The view the recipient's window shows. Its pictures are drawn at once, the others once shown.
	var/visible_direction = "2"
	/// The recipient's look before the proposal, captured to flatten one view at a time.
	var/mutable_appearance/before_appearance
	/// The same body wearing the proposal, captured to flatten one view at a time.
	var/mutable_appearance/after_appearance
	/// Canvas width the pictures are flattened at.
	var/picture_width = 32
	/// Canvas height the pictures are flattened at: taller when either look has tall hair.
	var/picture_height = 32
	/// Direction -> TRUE for views whose pictures predate the last capture.
	var/list/stale_views = list()

/datum/custom_sprite_mirror/New(datum/custom_sprite_salon/session, mob/living/carbon/human/recipient, list/applied_packages, slot)
	recipient_ckey = recipient.ckey
	recipient_ref = WEAKREF(recipient)
	if(!session)
		packages = list()
		for(var/key, package in applied_packages)
			packages[key] = custom_style_copy_package(package)
		var/list/first = packages[packages[1]]
		target = first["target"]
		changes = custom_sprite_salon_changes(packages)
		src.slot = slot
		return
	src.session = session
	token = session.proposal["token"]
	target = session.target
	var/list/proposed = session.proposal["packages"]
	changes = custom_sprite_salon_changes(proposed)
	restoration = !!session.restoration
	var/mob/artist = session.artist()
	artist_name = "[artist || "The artist"]"
	render_proposal(recipient)
	expires_at = world.time + CUSTOM_SPRITE_MIRROR_TIMEOUT
	addtimer(CALLBACK(src, PROC_REF(expire)), CUSTOM_SPRITE_MIRROR_TIMEOUT)

/datum/custom_sprite_mirror/Destroy()
	var/datum/custom_sprite_salon/owner = session
	session = null
	SStgui.close_uis(src)
	owner?.close_mirror()
	return ..()

/// Captures the recipient as they look now and the same body wearing the proposal, then draws the shown view. Other views keep their last pictures until shown.
/datum/custom_sprite_mirror/proc/render_proposal(mob/living/carbon/human/recipient)
	var/list/worn = custom_sprite_worn_overlays(recipient)
	var/mob/living/carbon/human/dummy/body = custom_sprite_salon_dummy(recipient)
	before_appearance = custom_sprite_preview_appearance(body, worn)
	var/before_height = custom_sprite_preview_height(body)
	custom_sprite_apply_round_styles(body, session.proposal["packages"], session.recipient_emissives)
	after_appearance = custom_sprite_preview_appearance(body, worn)
	picture_width = custom_sprite_preview_width(body)
	picture_height = max(before_height, custom_sprite_preview_height(body))
	qdel(body)
	before_urls ||= list()
	after_urls ||= list()
	for(var/direction in GLOB.custom_style_directions)
		stale_views[direction] = TRUE
	render_view(visible_direction)

/// Flattens one view's before and after pictures when they predate the last capture. Returns TRUE when it drew them.
/datum/custom_sprite_mirror/proc/render_view(direction)
	if(!stale_views[direction] || !before_appearance)
		return FALSE
	before_urls[direction] = custom_sprite_render_view(before_appearance, text2num(direction), picture_width, null, picture_height)
	after_urls[direction] = custom_sprite_render_view(after_appearance, text2num(direction), picture_width, null, picture_height)
	stale_views -= direction
	return TRUE

/// Redraws both pictures shortly after the recipient's look changes, once for a burst of changes.
/datum/custom_sprite_mirror/proc/schedule_refresh()
	if(session && !refresh_timer)
		refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh)), 1 SECONDS, TIMER_STOPPABLE)

/// Recaptures both looks, redraws the shown view and sends the pictures to the open window.
/datum/custom_sprite_mirror/proc/refresh()
	refresh_timer = null
	var/mob/living/carbon/human/recipient = recipient()
	if(!session || !recipient)
		return
	render_proposal(recipient)
	update_static_data_for_all_viewers()

/datum/custom_sprite_mirror/proc/expire()
	var/mob/recipient = recipient_ref?.resolve()
	to_chat(recipient, span_warning("The mirror preview expired without approval."))
	session?.decline(null, "didn't respond to")

/datum/custom_sprite_mirror/proc/recipient()
	var/mob/living/carbon/human/recipient = recipient_ref?.resolve()
	return !QDELETED(recipient) && recipient.ckey == recipient_ckey ? recipient : null

/datum/custom_sprite_mirror/ui_state(mob/user)
	return GLOB.always_state

/datum/custom_sprite_mirror/ui_status(mob/user, datum/ui_state/state)
	return user && user == recipient() ? UI_INTERACTIVE : UI_CLOSE

/datum/custom_sprite_mirror/ui_interact(mob/user, datum/tgui/ui)
	if(user != recipient())
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CustomSpriteMirror", "Mirror")
		ui.set_autoupdate(!!session)
		ui.open()

/datum/custom_sprite_mirror/ui_static_data(mob/user)
	return list(
		"mode" = session ? "approval" : "result",
		"label" = custom_sprite_salon_label(target),
		"changes" = changes,
		"artistName" = artist_name,
		"restoration" = restoration,
		"token" = token,
		"before" = before_urls,
		"after" = after_urls,
	)

/datum/custom_sprite_mirror/ui_data(mob/user)
	return list(
		"timeout" = session ? CLAMP01((expires_at - world.time) / CUSTOM_SPRITE_MIRROR_TIMEOUT) : null,
		"canSave" = !session && save_state != "saved",
		"saveState" = save_state,
		"saveMessage" = save_message,
		"messageError" = message_error,
		"visibleView" = visible_direction,
	)

/datum/custom_sprite_mirror/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || ui.user != recipient())
		return
	if(session && world.time >= expires_at)
		expire()
		return TRUE
	switch(action)
		if("setView")
			var/direction = params["dir"]
			if(!session || !(direction in GLOB.custom_style_directions) || direction == visible_direction)
				return FALSE
			visible_direction = direction
			if(!render_view(direction))
				return TRUE
			// The pictures are static data, and the full update carries the new view with them.
			update_static_data(ui.user, ui, always_instant = TRUE)
			return FALSE
		if("accept", "acceptPermanent")
			if(session && istext(params["token"]) && params["token"] == token)
				session.accept(ui.user, token, save_permanently = action == "acceptPermanent")
			return TRUE
		if("decline")
			session?.decline(ui.user)
			return TRUE
		if("save")
			if(!session)
				save_style(ui.user)
			return TRUE
		if("export")
			if(!session || params["token"] != token || session.proposal?["token"] != token)
				return TRUE
			var/error = session.export_proposal(ui.user.client)
			save_message = error || "Style exported."
			message_error = !!error
			return TRUE
		if("close")
			if(!session)
				qdel(src)
			return TRUE

/datum/custom_sprite_mirror/ui_close(mob/user)
	if(session)
		session.decline(user, "closed the mirror without approving")
	else if(!QDELETED(src))
		qdel(src)

/**
 * Saves the applied styles to the recipient's spawned character slot, in one write.
 *
 * The slot must still be selected and still be this character. Unsaved hair or marking edits in
 * character setup are rejected rather than overwritten. Failure leaves the round appearance applied.
 */
/datum/custom_sprite_mirror/proc/save_style(mob/living/carbon/human/user)
	var/datum/preferences/preferences = GLOB.preferences_datums[recipient_ckey]
	slot = preferences?.default_slot
	var/label = custom_sprite_salon_label(target)
	var/error = custom_style_spawned_slot_problem(user, preferences)
	if(!error)
		for(var/_key, package in packages)
			if(custom_style_package_hash(custom_sprite_live_package(user, package["target"], package["zone"])) != custom_style_package_hash(custom_sprite_live_package_from(package, user)))
				error = "Your [label] changed after it was applied."
				break
	// Character setup keeps one editor per target: every markings region shares the whole-body editor.
	if(!error && preferences.custom_sprite_editors?[target])
		error = "Close the matching custom editor in character setup, then try again."
	if(!error)
		var/list/saved = list()
		for(var/_key, package in packages)
			saved += list(package)
		error = preferences.commit_custom_styles(saved, slot, assoc_to_keys(packages), reject_pending_hair = TRUE, reject_pending_markings = TRUE)
	if(error)
		save_state = "error"
		message_error = TRUE
		save_message = "[error] Your style is still applied this round."
		return FALSE
	save_state = "saved"
	message_error = FALSE
	save_message = "Saved for future rounds."
	log_game("[key_name(user)] saved a salon [label][length(changes) ? " ([jointext(changes, ", ")])" : ""] to character slot [slot].")
	return TRUE

/**
 * Returns why a body's style can't be saved to the selected character slot, or null when it can.
 *
 * Without these checks a save could land on whichever character happens to be selected in
 * character setup instead of the one this body spawned as.
 */
/proc/custom_style_spawned_slot_problem(mob/living/carbon/human/body, datum/preferences/preferences)
	var/datum/client_interface/player = GET_CLIENT(body)
	if(!preferences || player?.prefs != preferences)
		return "Your character preferences aren't loaded."
	// Characters spawned by an admin have no recorded slot, so the saved name decides who this is.
	var/spawned_slot = body.mind?.original_character_slot_index
	if(spawned_slot && spawned_slot != preferences.default_slot)
		return "Select the character slot you spawned with in character setup, then try again."
	if(preferences.read_preference(/datum/preference/name/real_name) != body.real_name)
		return "The selected character slot belongs to a different character."
	return null

/// The live form of an applied package: emission follows the body's current permission.
/proc/custom_sprite_live_package_from(list/package, mob/living/carbon/human/body)
	var/datum/preferences/preferences = GLOB.preferences_datums[body.ckey]
	var/allow_emissives = preferences?.read_preference(/datum/preference/toggle/allow_emissives)
	var/list/drawing = custom_sprite_appearance_drawing(package["drawing"], allow_emissives)
	var/list/markings = package["markings"]
	if(isnull(markings))
		markings = custom_sprite_live_package(body, package["target"], package["zone"])["markings"]
	else if(!allow_emissives)
		markings = custom_style_copy_markings(markings)
		for(var/list/entry as anything in markings)
			entry["emissive"] = FALSE
	return custom_style_package(package["target"], package["zone"], custom_sprite_validate(drawing), package["hair"], markings)

#undef CUSTOM_SPRITE_MIRROR_TIMEOUT
