#define CUSTOM_SPRITE_MIRROR_TIMEOUT (120 SECONDS)

/// This body's worn clothing overlays, in layer order.
/proc/custom_sprite_worn_overlays(mob/living/carbon/human/source)
	. = list()
	for(var/layer in GLOB.worn_overlay_layers)
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

/// Front, Back, Right and Left data URLs for a preview body, without flipping any view.
/proc/custom_sprite_render_directions(mob/living/carbon/human/body, datum/callback/publish, list/worn_overlays)
	var/mutable_appearance/appearance = new(body.appearance)
	if(length(worn_overlays))
		appearance.overlays += worn_overlays
	var/list/urls = list()
	var/width = custom_sprite_taur_overlay(body) ? CUSTOM_SPRITE_TAUR_WIDTH : 32
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = custom_sprite_flat_icon(appearance, direction, width)
		urls["[direction]"] = publish ? publish.Invoke(rendered) : "data:image/png;base64,[icon2base64(rendered)]"
	return urls

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
	/// Tattoo zone, or null for a hairstyle.
	var/body_zone
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
	/// Result mode: the applied package and the recipient's spawned character slot.
	var/list/package
	/// Recipient's spawned character slot eligible for a permanent save.
	var/slot
	/// Result status shown after a permanent save attempt.
	var/save_state
	/// Explanation accompanying the permanent save result.
	var/save_message
	/// Whether the latest save or export message reports a failure.
	var/message_error = FALSE

/datum/custom_sprite_mirror/New(datum/custom_sprite_salon/session, mob/living/carbon/human/recipient, list/applied_package, slot)
	recipient_ckey = recipient.ckey
	recipient_ref = WEAKREF(recipient)
	if(!session)
		package = custom_style_copy_package(applied_package)
		target = package["target"]
		body_zone = package["zone"]
		src.slot = slot
		return
	src.session = session
	token = session.proposal["token"]
	var/list/worn = custom_sprite_worn_overlays(recipient)
	target = session.target
	body_zone = session.body_zone
	restoration = !!session.restoration
	var/mob/artist = session.artist()
	artist_name = "[artist || "The artist"]"
	var/mob/living/carbon/human/dummy/body = custom_sprite_salon_dummy(recipient)
	before_urls = custom_sprite_render_directions(body, worn_overlays = worn)
	custom_sprite_apply_round_style(body, session.proposal["package"], session.recipient_emissives)
	after_urls = custom_sprite_render_directions(body, worn_overlays = worn)
	qdel(body)
	expires_at = world.time + CUSTOM_SPRITE_MIRROR_TIMEOUT
	addtimer(CALLBACK(src, PROC_REF(expire)), CUSTOM_SPRITE_MIRROR_TIMEOUT)

/datum/custom_sprite_mirror/Destroy()
	var/datum/custom_sprite_salon/owner = session
	session = null
	SStgui.close_uis(src)
	owner?.close_mirror()
	return ..()

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
		"label" = custom_sprite_salon_label(target, body_zone),
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
			var/error = custom_style_send(ui.user.client, session.proposal["package"])
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
 * Saves the applied style to the recipient's spawned character slot.
 *
 * The slot must still be selected and still be this character. Unsaved hair edits in character
 * setup are rejected rather than overwritten. Failure leaves the round appearance applied.
 */
/datum/custom_sprite_mirror/proc/save_style(mob/living/carbon/human/user)
	var/datum/preferences/preferences = GLOB.preferences_datums[recipient_ckey]
	slot = preferences?.default_slot
	var/error = custom_style_spawned_slot_problem(user, preferences)
	if(!error && custom_style_package_hash(custom_sprite_live_package(user, target, body_zone)) != custom_style_package_hash(custom_sprite_live_package_from(package, user)))
		error = "Your [custom_sprite_salon_label(target, body_zone)] changed after it was applied."
	if(!error && preferences.custom_sprite_editors?[custom_style_key(target, body_zone)])
		error = "Close the matching custom editor in character setup, then try again."
	if(!error)
		error = preferences.commit_custom_style(package, slot, rotate = TRUE, reject_pending_hair = TRUE, reject_pending_markings = TRUE)
	if(error)
		save_state = "error"
		message_error = TRUE
		save_message = "[error] Your style is still applied this round."
		return FALSE
	save_state = "saved"
	message_error = FALSE
	save_message = "Saved for future rounds."
	log_game("[key_name(user)] saved a salon [custom_sprite_salon_label(target, body_zone)] to character slot [slot].")
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
