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
/proc/custom_sprite_render_view(mutable_appearance/appearance, direction, width, datum/callback/publish)
	var/icon/rendered = custom_sprite_flat_icon(appearance, direction, width)
	return publish ? publish.Invoke(rendered) : "data:image/png;base64,[icon2base64(rendered)]"

/// Front, Back, Right and Left data URLs of a captured look, without flipping any view.
/proc/custom_sprite_render_views(mutable_appearance/appearance, width, datum/callback/publish)
	. = list()
	for(var/direction in GLOB.cardinals)
		.["[direction]"] = custom_sprite_render_view(appearance, direction, width, publish)

/// Front, Back, Right and Left data URLs for a preview body, without flipping any view.
/proc/custom_sprite_render_directions(mob/living/carbon/human/body, datum/callback/publish, list/worn_overlays)
	return custom_sprite_render_views(custom_sprite_preview_appearance(body, worn_overlays), custom_sprite_preview_width(body), publish)

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

/// Draws the recipient as they look now beside the same body wearing the proposal, from every side.
/datum/custom_sprite_mirror/proc/render_proposal(mob/living/carbon/human/recipient)
	var/list/worn = custom_sprite_worn_overlays(recipient)
	var/mob/living/carbon/human/dummy/body = custom_sprite_salon_dummy(recipient)
	before_urls = custom_sprite_render_directions(body, worn_overlays = worn)
	custom_sprite_apply_round_styles(body, session.proposal["packages"], session.recipient_emissives)
	after_urls = custom_sprite_render_directions(body, worn_overlays = worn)
	qdel(body)

/// Redraws both pictures shortly after the recipient's look changes, once for a burst of changes.
/datum/custom_sprite_mirror/proc/schedule_refresh()
	if(session && !refresh_timer)
		refresh_timer = addtimer(CALLBACK(src, PROC_REF(refresh)), 1 SECONDS, TIMER_STOPPABLE)

/// Redraws both pictures and sends them to the open window.
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
	)

/datum/custom_sprite_mirror/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || ui.user != recipient())
		return
	if(session && world.time >= expires_at)
		expire()
		return TRUE
	switch(action)
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
