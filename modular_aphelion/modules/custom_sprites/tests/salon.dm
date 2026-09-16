#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/// Drives application directly instead of sleeping in a timed action, and records awards.
/datum/custom_sprite_salon/test
	/// Achievement types emitted by successful test applications.
	var/list/awards = list()

/datum/custom_sprite_salon/test/apply_proposal(token)
	return

/datum/custom_sprite_salon/test/award(mob/player, award_type)
	awards += award_type

/// Records stop packets without requiring a real sound-capable client.
/mob/living/carbon/human/consistent/salon_sound_listener
	/// Most recent channel silenced for this listener.
	var/stopped_channel

/mob/living/carbon/human/consistent/salon_sound_listener/stop_sound_channel(channel)
	stopped_channel = channel
	return ..()

/datum/unit_test/custom_sprite_salon_sound_cleanup/Run()
	var/mob/living/carbon/human/consistent/salon_sound_listener/source = allocate(/mob/living/carbon/human/consistent/salon_sound_listener)
	var/mob/living/carbon/human/consistent/salon_sound_listener/bystander = allocate(/mob/living/carbon/human/consistent/salon_sound_listener)
	var/datum/looping_sound/salon_snipping/sound = new(source, TRUE)
	var/channel = sound.sound_channel
	sound.listeners = list(WEAKREF(source), WEAKREF(bystander))
	qdel(source)
	if(source.stopped_channel != channel || bystander.stopped_channel != channel)
		Fail("Deleting the source must silence its own channel as well as nearby listeners.", __FILE__, __LINE__)
	if(sound.is_active() || sound.listeners || SSsounds.reserved_channels["[channel]"])
		Fail("Source deletion must release the clip, timer and reserved channel.", __FILE__, __LINE__)
	qdel(sound)

/datum/unit_test/custom_sprite_salon
	/// Connected artist body used by consent and application checks.
	var/mob/living/carbon/human/consistent/artist
	/// Connected recipient body, including transplanted-part fixtures.
	var/mob/living/carbon/human/consistent/recipient
	/// Artist's held haircut tool.
	var/obj/item/scissors/scissors
	/// Artist's held tattoo tool.
	var/obj/item/tattoo_machine/machine

/datum/unit_test/custom_sprite_salon/proc/setup_players()
	artist = allocate(/mob/living/carbon/human/consistent)
	recipient = allocate(/mob/living/carbon/human/consistent, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	artist.mock_client = new
	recipient.mock_client = new
	artist.ckey = "salontestartist"
	recipient.ckey = "salontestrecipient"
	artist.mock_client.ckey = artist.ckey
	recipient.mock_client.ckey = recipient.ckey
	scissors = allocate(/obj/item/scissors)
	machine = allocate(/obj/item/tattoo_machine)
	artist.put_in_active_hand(scissors)
	artist.put_in_inactive_hand(machine)
	recipient.set_hairstyle("Short Hair", update = TRUE)

/datum/unit_test/custom_sprite_salon/proc/teardown_players()
	for(var/key in list(artist.ckey, recipient.ckey))
		for(var/datum/custom_sprite_salon/session as anything in custom_sprite_salon_sessions_for(key))
			qdel(session)
		qdel(GLOB.custom_sprite_salon_restorations[key])
		GLOB.custom_sprite_salon_prompts -= key
	GLOB.custom_sprite_salon_cooldowns.Cut()
	artist.ckey = null
	recipient.ckey = null

/datum/unit_test/custom_sprite_salon/proc/paint(datum/custom_sprite_salon/session)
	var/datum/custom_sprite_editor/salon/editor = session.editor
	var/list/bounds = editor.workspace.draw_bounds["2"]
	var/list/points = list()
	// Paint a visible block from the middle of the allowed area, rather than an edge pixel hidden by masks.
	for(var/y in round((bounds[2] + bounds[4]) / 2) to bounds[4])
		for(var/x in round((bounds[1] + bounds[3]) / 2) - 2 to round((bounds[1] + bounds[3]) / 2) + 2)
			if(editor.workspace.is_point_allowed(x, y, "2"))
				points += list(list(x, y))
	var/color = "#[copytext(md5("[length(editor.workspace.undo_stack)]"), 1, 7)]"
	editor.workspace.update_palette(editor.workspace.palette | color)
	if(!length(points) || !editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "[color]ff", "points" = points)))
		return FALSE
	editor.draft_changed()
	return TRUE

/datum/unit_test/custom_sprite_salon/timed_sounds
	/// Number of do_after checks observed with sound channels reserved.
	var/sound_checks = 0

/datum/unit_test/custom_sprite_salon/timed_sounds/proc/check_sounds(expected_channels, interrupted)
	sound_checks++
	if(length(SSsounds.reserved_channels) != expected_channels)
		Fail("Salon audio must start before the timed work and remain active during it.", __FILE__, __LINE__)
	return !interrupted

/datum/unit_test/custom_sprite_salon/timed_sounds/Run()
	setup_players()
	for(var/tattoo in list(FALSE, TRUE))
		for(var/interrupted in list(FALSE, TRUE))
			var/before = length(SSsounds.reserved_channels)
			sound_checks = 0
			var/completed = do_salon_work(artist, 0.3 SECONDS, recipient, tattoo, CALLBACK(src, PROC_REF(check_sounds), before + (tattoo ? 2 : 1), interrupted))
			if(!sound_checks || completed == interrupted)
				Fail("The timed salon action must run its validity callback and respect interruption.", __FILE__, __LINE__)
			if(length(SSsounds.reserved_channels) != before)
				Fail("Completion and interruption must both release salon sound channels.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/Run()
	setup_players()
	if(custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"))
		Fail("Adjacent distinct players with scissors must be able to start: [custom_sprite_salon_start_problem(scissors, artist, recipient, "hair")]", __FILE__, __LINE__)
	if(custom_sprite_salon_start_problem(scissors, artist, artist, "hair"))
		Fail("Working on yourself must be allowed.", __FILE__, __LINE__)
	if(custom_sprite_salon_start_problem(machine, artist, recipient, "markings", BODY_ZONE_L_ARM))
		Fail("An exposed limb must be tattooable with a held tattoo machine.", __FILE__, __LINE__)
	var/datum/client_interface/recipient_client = recipient.mock_client
	recipient.mock_client = null
	if(!custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"))
		Fail("A disconnected recipient must be rejected.", __FILE__, __LINE__)
	recipient.mock_client = recipient_client
	recipient.obscured_slots |= HIDEHAIR
	if(!custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"))
		Fail("Covered hair must be rejected.", __FILE__, __LINE__)
	recipient.obscured_slots &= ~HIDEHAIR
	recipient.set_hairstyle("Bald", update = TRUE)
	if(custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"))
		Fail("Custom hair must be allowed on bald heads.", __FILE__, __LINE__)
	custom_sprite_apply_round_style(recipient, custom_style_package("hair", null, custom_sprite_test_drawing(), custom_style_live_hair_context(recipient)))
	var/obj/item/bodypart/head/bald_head = recipient.get_bodypart(BODY_ZONE_HEAD)
	if(!length(bald_head.get_hair_overlays()))
		Fail("Custom hair must render on a bald head.", __FILE__, __LINE__)
	if(custom_style_parse(custom_style_export_text(custom_sprite_live_package(recipient, "hair", null)))["error"])
		Fail("Bald custom hair must export and import.", __FILE__, __LINE__)
	custom_sprite_apply_round_style(recipient, custom_style_package("hair", null, null, custom_style_live_hair_context(recipient)))
	if(length(bald_head.get_hair_overlays()))
		Fail("Removing custom hair from a bald head must leave no hair overlays.", __FILE__, __LINE__)
	recipient.set_hairstyle("Short Hair", update = TRUE)

	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair", null)
	if(custom_sprite_salon_session(artist.ckey, "hair", null) != session || session.editor?.context != "salon")
		Fail("A salon session must own the artist's single retained draft.", __FILE__, __LINE__)
	if(session.propose(artist) != "Nothing has changed yet.")
		Fail("Unchanged submissions must not be proposed.", __FILE__, __LINE__)
	var/icon/guide = session.editor.guide_icons["2"]
	var/body_pixels = 0
	for(var/y in 1 to 14)
		for(var/x in 1 to 32)
			if(guide?.GetPixel(x, y))
				body_pixels++
	if(!body_pixels)
		Fail("Artist guides must show the whole body they're working on.", __FILE__, __LINE__)
	if(!paint(session))
		return Fail("The salon editor rejected paint inside the hair bounds.", __FILE__, __LINE__)
	if(!session.propose(recipient))
		Fail("Only the artist may finish the work.", __FILE__, __LINE__)
	var/error = session.propose(artist)
	if(error || session.state != "awaiting approval" || !session.mirror || !GLOB.custom_sprite_salon_prompts[recipient.ckey])
		return Fail("A changed draft must open the recipient's mirror: [error]", __FILE__, __LINE__)
	var/list/before = session.mirror.before_urls
	if(length(before) != 4 || length(session.mirror.after_urls) != 4 || before["2"] == session.mirror.after_urls["2"])
		Fail("The mirror must render all four directions before and after the change.", __FILE__, __LINE__)
	var/first_token = session.proposal["token"]
	paint(session)
	if(session.state != "drafting" || session.mirror || session.proposal)
		Fail("Editing must withdraw the pending proposal.", __FILE__, __LINE__)
	if(!findtext(session.propose(artist), "wait"))
		Fail("Repeated requests between the same players must honor the cooldown.", __FILE__, __LINE__)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	var/token = session.proposal["token"]
	if(session.accept(recipient, first_token) || session.accept(artist, token))
		Fail("Stale tokens and other players must not approve.", __FILE__, __LINE__)
	session.mirror.ui_close(recipient)
	if(session.state != "drafting")
		Fail("Closing the mirror must decline, never accept.", __FILE__, __LINE__)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	artist.forceMove(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	if(session.accept(recipient, token) || session.state != "drafting")
		Fail("Approval must recheck reachability.", __FILE__, __LINE__)
	artist.forceMove(run_loc_floor_bottom_left)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	if(!session.accept(recipient, token) || session.state != "applying")
		return Fail("A valid approval must start the timed application.", __FILE__, __LINE__)
	artist.forceMove(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	if(session.complete_application(token) || session.state != "drafting" || !session.editor)
		Fail("Walking away before completion must fail without losing the draft.", __FILE__, __LINE__)
	artist.forceMove(run_loc_floor_bottom_left)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	session.accept(recipient, token)
	var/list/applied = session.proposal["package"]
	if(!session.complete_application(token) || !QDELETED(session))
		return Fail("A valid completion must apply and end the session.", __FILE__, __LINE__)
	if(session.complete_application(token) || length(session.awards) != 2)
		Fail("Replayed completion must not apply or award twice.", __FILE__, __LINE__)
	if(custom_sprite_hash(custom_sprite_validate(recipient.dna.custom_hair)) != custom_sprite_hash(custom_sprite_validate(custom_sprite_appearance_drawing(applied["drawing"], FALSE))))
		Fail("The approved revision must become the recipient's round hair.", __FILE__, __LINE__)
	var/list/history = recipient.custom_sprite_round_history?["hair"]
	if(!history || !("drawing" in history) || history["drawing"] || !history["hair"])
		Fail("Application must keep the previous style, including an explicit empty drawing and base look.", __FILE__, __LINE__)

	var/datum/custom_sprite_salon/test/restore = new(scissors, artist, recipient, "hair", null, deep_copy_list(history))
	GLOB.custom_sprite_salon_cooldowns.Cut()
	error = restore.propose(artist)
	if(error)
		return Fail("Restoration must open the mirror: [error]", __FILE__, __LINE__)
	token = restore.proposal["token"]
	if(!restore.accept(recipient, token) || !restore.complete_application(token))
		return Fail("Restoration must use the same approval and application flow.", __FILE__, __LINE__)
	if(recipient.dna.custom_hair || !recipient.custom_sprite_round_history["hair"]["drawing"] || length(restore.awards))
		Fail("Restoration must swap current and previous styles without awarding achievements.", __FILE__, __LINE__)

	var/datum/custom_sprite_salon/test/tattoo = new(machine, artist, recipient, "markings", BODY_ZONE_L_ARM)
	if(!paint(tattoo))
		Fail("The tattoo editor must accept paint inside the limb silhouette.", __FILE__, __LINE__)
	var/obj/item/bodypart/arm/left/replacement = new
	replacement.replace_limb(recipient)
	if(!findtext(tattoo.propose(artist), "replaced"))
		Fail("A replaced limb must invalidate the tattoo.", __FILE__, __LINE__)
	if(!tattoo.editor || tattoo.editor.workspace.edited_directions["2"] != TRUE)
		Fail("Invalidation must keep the tattoo draft for export.", __FILE__, __LINE__)
	var/list/other_hair = custom_style_test_hair("Mohawk")
	if(!tattoo.editor.candidate_problem(custom_style_package("markings", BODY_ZONE_R_ARM, null, null)))
		Fail("Salon imports must reject a different body zone.", __FILE__, __LINE__)
	qdel(tattoo)
	var/datum/custom_sprite_salon/test/hair_session = new(scissors, artist, recipient, "hair", null)
	other_hair = hair_session.editor.workspace.hair_context.Copy()
	other_hair["style"] = "Mohawk"
	if(hair_session.editor.candidate_problem(custom_style_package("hair", null, null, other_hair)))
		Fail("Salon imports must allow another unlocked base haircut.", __FILE__, __LINE__)
	other_hair["opacity"] = other_hair["opacity"] == 0.5 ? 1 : 0.5
	if(!hair_session.editor.candidate_problem(custom_style_package("hair", null, null, other_hair)))
		Fail("Salon imports must preserve the recipient's other hair settings.", __FILE__, __LINE__)
	recipient.ckey = "salontestbodythief"
	if(!hair_session.participant_problem())
		Fail("A changed controlling player must invalidate the work.", __FILE__, __LINE__)
	recipient.ckey = "salontestrecipient"
	hair_session.editor.ui_close(artist)
	if(hair_session.editor.resources_ready || hair_session.editor.preview_body || !hair_session.editor.workspace)
		Fail("Closing the salon editor must keep the draft and release preview resources.", __FILE__, __LINE__)
	if(!custom_sprite_salon_resume(scissors, artist) || !custom_sprite_salon_resume(machine, artist))
		Fail("The tool's self-use action must handle resuming.", __FILE__, __LINE__)
	hair_session.editor.ui_interact(artist)
	if(!hair_session.editor.resources_ready || length(hair_session.editor.guide_urls) != 4)
		Fail("Resuming must rebuild preview resources.", __FILE__, __LINE__)
	teardown_players()

/// Retain the real native pixels at the existing publication boundary.
/datum/custom_sprite_editor/salon/test_icons
	/// Captured native pixels from the production rendering and publication path.
	var/list/published_icons = list()

/datum/custom_sprite_editor/salon/test_icons/publish_icon(icon/rendered)
	published_icons += icon(rendered)
	return ..()

/datum/unit_test/custom_sprite_salon/proc/transplant_donor(zone, hair_opacity = 128)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.skin_tone = "african2"
	donor.hair_alpha = hair_opacity
	donor.set_hairstyle("Short Hair", update = FALSE)
	donor.set_hair_gradient_style("Fade Up", update = FALSE)
	donor.set_hair_gradient_color("#123456", update = FALSE)
	// Live preferences apply the emissive permission before placing drawings in DNA.
	donor.dna.custom_hair = custom_sprite_appearance_drawing(custom_sprite_test_drawing("2"), FALSE)
	donor.dna.custom_markings = custom_sprite_appearance_drawing(custom_sprite_test_drawing("2"), FALSE)
	donor.dna.custom_limb_markings = list()
	donor.dna.custom_limb_markings[zone] = custom_sprite_appearance_drawing(custom_sprite_test_drawing(), FALSE)
	donor.dna.body_markings[zone] = list("Tiger Stripe" = list("#ff0000", 0))
	donor.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/limb = donor.get_bodypart(zone)
	limb.drop_limb(TRUE)
	var/obj/item/bodypart/original = recipient.get_bodypart(zone)
	if(!limb.replace_limb(recipient))
		Fail("The fixture's donor limb must attach.", __FILE__, __LINE__)
	qdel(original)
	return limb

/datum/unit_test/custom_sprite_salon/donor_appearance/Run()
	setup_players()
	var/obj/item/bodypart/arm = transplant_donor(BODY_ZONE_L_ARM)
	var/original_markings = json_encode(arm.markings)
	var/original_draw_color = arm.draw_color
	var/datum/bodypart_overlay/custom_marking/whole = locate(/datum/bodypart_overlay/custom_marking) in arm.bodypart_overlays
	var/datum/bodypart_overlay/custom_marking/zone = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
	var/whole_hash = whole?.drawing_hash
	var/zone_hash = zone?.drawing_hash
	if(arm.skin_tone != "african2" || arm.skin_tone == recipient.skin_tone || !whole_hash || !zone_hash || !length(arm.markings))
		Fail("The attached fixture must retain differently colored skin, native markings and both donor paint layers.", __FILE__, __LINE__)
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	var/obj/item/bodypart/preview_arm = preview.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/preview_zone = locate(/datum/bodypart_overlay/custom_marking/zone) in preview_arm.bodypart_overlays
	if(preview_arm.draw_color != original_draw_color || json_encode(preview_arm.markings) != original_markings || preview_zone?.drawing_hash != zone_hash)
		Fail("Salon dummies must preserve donor skin, native markings and limb paint.", __FILE__, __LINE__)
	qdel(preview)
	for(var/list/package as anything in list(custom_style_package("hair", null, custom_sprite_test_drawing(), custom_style_live_hair_context(recipient)), custom_style_package("markings", BODY_ZONE_R_ARM, custom_sprite_test_drawing(), null)))
		custom_sprite_apply_round_style(recipient, package)
		if(recipient.get_bodypart(BODY_ZONE_L_ARM) != arm || arm.owner != recipient || arm.draw_color != original_draw_color || json_encode(arm.markings) != original_markings || QDELETED(whole) || whole.drawing_hash != whole_hash || QDELETED(zone) || zone.drawing_hash != zone_hash)
			Fail("Editing [package["target"]] on another part must preserve the donor arm and both paint layers.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/donor_history/Run()
	setup_players()
	var/obj/item/bodypart/arm = transplant_donor(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
	var/original_hash = zone.drawing_hash
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", BODY_ZONE_L_ARM)
	if(custom_sprite_hash(session.original["package"]["drawing"]) != original_hash || !session.editor.workspace.serialize_drawing())
		Fail("A transplanted limb's draft must start from its paint snapshot, even when recipient DNA has no tattoo.", __FILE__, __LINE__)
	if(!paint(session))
		Fail("The donor tattoo draft must be editable.", __FILE__, __LINE__)
	var/error = session.propose(artist)
	if(error)
		Fail("The donor tattoo must be proposable: [error]", __FILE__, __LINE__)
	else
		var/token = session.proposal["token"]
		if(!session.accept(recipient, token) || !session.complete_application(token))
			Fail("Approved work on the donor arm must complete.", __FILE__, __LINE__)
		var/list/history = recipient.custom_sprite_round_history?[custom_style_key("markings", BODY_ZONE_L_ARM)]
		if(custom_sprite_hash(history?["drawing"]) != original_hash)
			Fail("Round history must retain the actual donor tattoo for restoration.", __FILE__, __LINE__)
		custom_sprite_apply_round_style(recipient, history)
		var/datum/bodypart_overlay/custom_marking/restored = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
		if(restored?.drawing_hash != original_hash)
			Fail("Restoring round history must restore the donor's original paint.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/donor_head/Run()
	setup_players()
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD)
	var/paint_hash = custom_sprite_hash(head.custom_hair)
	var/original_skin = head.skin_tone
	var/list/package = custom_sprite_live_package(recipient, "hair")
	if(custom_sprite_hash(package["drawing"]) != paint_hash || package["hair"]["opacity"] != 128 || package["hair"]["gradient_color"] != "#123456")
		Fail("Hair packages must capture the attached head's paint, opacity and gradient.", __FILE__, __LINE__)
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	var/obj/item/bodypart/head/preview_head = preview.get_bodypart(BODY_ZONE_HEAD)
	if(preview_head.skin_tone != original_skin || preview_head.hair_alpha != 128 || custom_sprite_hash(preview_head.custom_hair) != paint_hash)
		Fail("The salon dummy must show the transplanted head's skin and hair.", __FILE__, __LINE__)
	qdel(preview)
	custom_sprite_apply_round_style(recipient, package)
	if(head.skin_tone != original_skin || head.hair_alpha != 128 || custom_sprite_hash(head.custom_hair) != paint_hash)
		Fail("Applying hair must preserve donor head identity and its unrelated appearance.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/hair_extension_preview/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	qdel(session.editor)
	var/datum/custom_sprite_editor/salon/test_icons/editor = new(session)
	session.editor = editor
	editor.workspace.update_palette(editor.workspace.palette | "#fe12ab")
	for(var/direction in GLOB.cardinals)
		var/icon/guide = editor.guide_icons["[direction]"]
		if(guide.GetPixel(7, 31))
			Fail("The extension fixture must be outside the original head and hair silhouette in direction [direction].", __FILE__, __LINE__)
		if(!editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "[direction]", "color" = "#fe12abff", "points" = list(list(6, 1)))))
			Fail("A bun above the original hair must be inside the editor's allowed drawing area.", __FILE__, __LINE__)
	editor.published_icons.Cut()
	editor.refresh_preview()
	var/index = 0
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = editor.published_icons[++index]
		if(rendered.GetPixel(7, 31) != "#fe12ab")
			Fail("Artist previews must retain allowed custom hair outside the original silhouette in direction [direction].", __FILE__, __LINE__)
		var/body_pixels = 0
		for(var/y in 1 to 14)
			for(var/x in 1 to 32)
				if(rendered.GetPixel(x, y))
					body_pixels++
		if(!body_pixels)
			Fail("Artist previews must show the body being worked on in direction [direction].", __FILE__, __LINE__)
	var/error = session.propose(artist)
	if(error)
		Fail("The extension must be proposable: [error]", __FILE__, __LINE__)
	else
		for(var/direction in GLOB.cardinals)
			var/icon/rendered = getFlatIcon(editor.preview_body, defdir = direction, no_anim = TRUE)
			rendered.Crop(1, 1, 32, 32)
			if(rendered.GetPixel(7, 31) != "#fe12ab" || session.mirror.after_urls["[direction]"] != "data:image/png;base64,[icon2base64(rendered)]")
				Fail("The recipient mirror must show the same native extension in direction [direction].", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/donor_gradient/Run()
	setup_players()
	recipient.set_hair_gradient_style("None", update = FALSE)
	recipient.set_hair_gradient_color("#000000", update = FALSE)
	var/list/original_hair = custom_style_live_hair_context(recipient)
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD)
	if(head.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "Fade Up" || recipient.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "None")
		Fail("The donor's gradient must differ from the recipient's retained hair settings.", __FILE__, __LINE__)
	custom_style_apply_hair_context(recipient, original_hair)
	if(head.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "None" || head.get_hair_gradient_color(GRADIENT_HAIR_KEY) != "#000000")
		Fail("Applying a hair context must update the head even when the recipient's cached settings already match it.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon_native_hair_opacity/Run()
	for(var/species_id in list(SPECIES_ETHEREAL, SPECIES_SLIMESTART))
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], species_id)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Short Hair")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
		var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
		preferences.apply_prefs_to(recipient, TRUE, visuals_only = TRUE)
		var/obj/item/bodypart/head/head = recipient.get_bodypart(BODY_ZONE_HEAD)
		if(recipient.hair_alpha || head.hair_alpha != (species_id == SPECIES_ETHEREAL ? 140 : 160))
			Fail("The fixture must have the species' native hair opacity without an override.", __FILE__, __LINE__)
		var/list/package = custom_sprite_live_package(recipient, "hair")
		if(!isnull(package["hair"]["opacity"]))
			Fail("Native [species_id] opacity must remain the default in a salon package, not become an unsupported override.", __FILE__, __LINE__)
		package["drawing"] = custom_sprite_test_drawing()
		var/error = preferences.commit_custom_style(package, preferences.default_slot)
		if(error)
			Fail("Saving custom hair with native [species_id] opacity must succeed: [error]", __FILE__, __LINE__)

/datum/unit_test/custom_sprite_salon/donor_opaque_hair/Run()
	setup_players()
	recipient.set_species(/datum/species/ethereal)
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD, 255)
	if(recipient.hair_alpha || recipient.dna.species.hair_alpha != 140 || head.hair_alpha != 255)
		Fail("The donor head must have opaque hair on a body whose native hair is translucent.", __FILE__, __LINE__)
	var/list/package = custom_sprite_live_package(recipient, "hair")
	var/list/parsed = custom_style_parse(custom_style_export_text(package))
	if(package["hair"]["opacity"] != 255 || parsed["error"] || parsed["package"]["hair"]["opacity"] != 255)
		Fail("A donor's opaque hair must remain explicitly opaque in live and exported packages.", __FILE__, __LINE__)
	custom_sprite_apply_round_style(recipient, package)
	if(head.hair_alpha != 255)
		Fail("Applying a salon package must not make opaque donor hair translucent.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon_recipient_save/Run()
	var/mob/living/carbon/human/consistent/recipient = allocate(/mob/living/carbon/human/consistent)
	var/datum/client_interface/mock_client = new
	recipient.mock_client = mock_client
	recipient.ckey = "salontestsaver"
	mock_client.ckey = recipient.ckey
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	mock_client.prefs = preferences
	GLOB.preferences_datums[recipient.ckey] = preferences
	recipient.mind_initialize()
	recipient.mind.original_character_slot_index = preferences.default_slot
	recipient.real_name = preferences.read_preference(/datum/preference/name/real_name)
	var/list/package = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing(), null)
	custom_sprite_apply_round_style(recipient, package)
	var/datum/custom_sprite_mirror/mirror = new(null, recipient, package, preferences.default_slot)
	var/datum/tgui/ui = new(recipient, mirror, "CustomSpriteMirror")
	mirror.ui_act("export", list(), ui)
	if(mirror.save_message)
		Fail("The completed result must not offer a second export: [mirror.save_message]", __FILE__, __LINE__)
	qdel(ui)
	if(!mirror.save_style(recipient) || custom_sprite_hash(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != custom_sprite_hash(package["drawing"]))
		Fail("The recipient must be able to save an applied style: [mirror.save_message]", __FILE__, __LINE__)
	if(!preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM))
		Fail("A salon save must keep the replaced style as previous.", __FILE__, __LINE__)
	// Admin-spawned bodies record no slot, but they are still this player's character.
	recipient.mind.original_character_slot_index = null
	custom_sprite_apply_round_style(recipient, package)
	if(!mirror.save_style(recipient))
		Fail("A character spawned without a recorded slot must still be able to save: [mirror.save_message]", __FILE__, __LINE__)
	recipient.mind.original_character_slot_index = preferences.default_slot + 1
	if(mirror.save_style(recipient) || mirror.save_state != "error")
		Fail("Saves must stay bound to the slot the character spawned with.", __FILE__, __LINE__)
	if(findtext(lowertext(mirror.save_message), "export"))
		Fail("The completed result must not direct players to an export action it no longer offers.", __FILE__, __LINE__)
	recipient.mind.original_character_slot_index = preferences.default_slot
	mirror.slot = preferences.default_slot
	recipient.real_name = "Someone Else Entirely"
	if(mirror.save_style(recipient))
		Fail("Saves must reject a slot belonging to another character.", __FILE__, __LINE__)
	qdel(mirror)
	GLOB.preferences_datums -= recipient.ckey
	recipient.ckey = null

/datum/unit_test/custom_sprite_salon/taur/Run()
	setup_players()
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(recipient)
	if(!organ)
		teardown_players()
		return Fail("The salon fixture needs a real taur organ.", __FILE__, __LINE__)
	if(custom_sprite_salon_target_problem(recipient, "markings", "taur"))
		Fail("An exposed taur organ must be a supported tattoo target.", __FILE__, __LINE__)
	if(!custom_sprite_salon_target_problem(recipient, "markings", BODY_ZONE_L_LEG))
		Fail("Hidden taur leg slots must remain unsupported tattoo targets.", __FILE__, __LINE__)
	var/icon/silhouette = custom_sprite_body_silhouette(recipient, CUSTOM_MARKING_ZONE_TAUR, CUSTOM_SPRITE_TAUR_WIDTH)
	if(silhouette.Width() != 64 || silhouette.Height() != 32)
		Fail("The taur drawing geometry must retain the entire 64-pixel lower body.", __FILE__, __LINE__)
	recipient.dna.custom_markings = custom_sprite_test_wide_drawing()
	recipient.dna.custom_limb_markings = list("taur" = custom_sprite_test_wide_drawing(repeat_string(64, "2")))
	recipient.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/chest = recipient.get_bodypart(BODY_ZONE_CHEST)
	chest.apply_custom_marking(custom_sprite_test_wide_drawing(), /datum/bodypart_overlay/custom_marking/taur/zone)
	var/list/current = custom_sprite_live_package(recipient, "markings", "taur")
	if(!current?["drawing"] || current["drawing"]["version"] != 3 || custom_sprite_hash(current["drawing"]) == custom_sprite_hash(custom_sprite_validate(recipient.dna.custom_limb_markings["taur"])))
		Fail("Live taur capture must read its independent chest overlay snapshot.", __FILE__, __LINE__)
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	allocated += preview
	if(!preview.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR) || custom_style_package_hash(custom_sprite_live_package(preview, "markings", "taur")) != custom_style_package_hash(current))
		Fail("Salon dummies must preserve the actual taur organ and its independent paint snapshot.", __FILE__, __LINE__)
	if(current?["drawing"])
		var/whole_hash = custom_sprite_hash(recipient.dna.custom_markings)
		custom_sprite_apply_round_style(recipient, custom_style_package("markings", "taur", null, null), FALSE)
		if(custom_sprite_live_package(recipient, "markings", "taur")?["drawing"] || custom_sprite_hash(recipient.dna.custom_markings) != whole_hash)
			Fail("Clearing a salon taur tattoo must preserve whole-body paint.", __FILE__, __LINE__)
		custom_sprite_apply_round_style(recipient, current, FALSE)
		if(custom_sprite_hash(custom_sprite_live_package(recipient, "markings", "taur")?["drawing"]) != custom_sprite_hash(custom_sprite_appearance_drawing(current["drawing"], FALSE)))
			Fail("Salon application must restore the independent taur paint snapshot.", __FILE__, __LINE__)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", "taur", current)
	if(session.participant_problem())
		Fail("Taur consent must bind to the existing chest and external organ.", __FILE__, __LINE__)
	var/obj/item/organ/taur_body/replacement = allocate(organ.type)
	var/datum/bodypart_overlay/mutant/taur_body/replacement_overlay = replacement.bodypart_overlay
	replacement_overlay.set_appearance_from_name("Cow (Spotted)")
	replacement_overlay.imprint_on_next_insertion = FALSE
	allocated += organ
	replacement.Insert(recipient, special = TRUE)
	if(!findtext(session.participant_problem(), "replaced"))
		Fail("Replacing the taur organ while retaining the chest must invalidate salon consent.", __FILE__, __LINE__)
	teardown_players()


/proc/custom_sprite_test_mask_count(list/rows)
	. = 0
	for(var/row in rows)
		. += length(replacetext(row, "0", ""))

/proc/custom_sprite_test_mask_top(list/rows)
	for(var/y in 1 to length(rows))
		if(findtext(rows[y], "1"))
			return y - 1
	return null

/datum/unit_test/custom_sprite_salon/hands_and_coverage/Run()
	setup_players()
	var/list/arm_mask = custom_sprite_body_draw_mask(recipient, BODY_ZONE_L_ARM)["2"]
	var/list/hand_mask = custom_sprite_body_draw_mask(recipient, BODY_ZONE_PRECISE_L_HAND)["2"]
	var/list/hand_only = custom_sprite_body_silhouette(recipient, BODY_ZONE_PRECISE_L_HAND)
	var/obj/item/bodypart/arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	var/list/hand_bounds = custom_sprite_icon_bounds(custom_sprite_silhouette(arm, TRUE), SOUTH, 0)
	if(!hand_only || !hand_bounds || !custom_sprite_test_mask_count(hand_mask) || custom_sprite_test_mask_count(hand_mask) >= custom_sprite_test_mask_count(arm_mask))
		return Fail("A hand zone must paint a smaller part of its arm.", __FILE__, __LINE__)
	if(custom_sprite_test_mask_top(hand_mask) < hand_bounds[2] - 3 || custom_sprite_test_mask_top(arm_mask) >= custom_sprite_test_mask_top(hand_mask))
		Fail("Hand paint may only reach a few rows above the hand.", __FILE__, __LINE__)
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(copytext(hand_mask[y], x, x + 1) == "1" && copytext(arm_mask[y], x, x + 1) != "1")
				return Fail("A hand zone must stay within its arm's silhouette.", __FILE__, __LINE__)
	var/list/hand_package = custom_style_package("markings", BODY_ZONE_PRECISE_L_HAND, custom_sprite_test_drawing("1"), null)
	var/list/arm_package = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing("2"), null)
	custom_sprite_apply_round_style(recipient, hand_package)
	custom_sprite_apply_round_style(recipient, arm_package)
	var/hand_overlays = 0
	var/zone_overlays = 0
	for(var/datum/bodypart_overlay/custom_marking/marking in arm.bodypart_overlays)
		if(marking.type == /datum/bodypart_overlay/custom_marking/zone/hand)
			hand_overlays++
		else if(marking.type == /datum/bodypart_overlay/custom_marking/zone)
			zone_overlays++
	if(hand_overlays != 1 || zone_overlays != 1)
		Fail("Hand and arm paint must be independent overlays on the arm.", __FILE__, __LINE__)
	if(custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_PRECISE_L_HAND)) != custom_style_package_hash(custom_sprite_live_package_from(hand_package, recipient)) || custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_L_ARM)) != custom_style_package_hash(custom_sprite_live_package_from(arm_package, recipient)))
		Fail("Live hand and arm styles must read back their own drawings.", __FILE__, __LINE__)
	if(custom_sprite_salon_start_problem(machine, artist, recipient, "markings", BODY_ZONE_PRECISE_L_HAND))
		Fail("A bare hand must be tattooable.", __FILE__, __LINE__)
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	if(!custom_sprite_zone_covered(recipient, BODY_ZONE_PRECISE_L_HAND) || custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM))
		Fail("Gloves must cover hands without covering arms.", __FILE__, __LINE__)
	if(!findtext(custom_sprite_salon_start_problem(machine, artist, recipient, "markings", BODY_ZONE_PRECISE_L_HAND), "covered"))
		Fail("Tattooing a gloved hand must be refused.", __FILE__, __LINE__)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	if(!custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM) || !custom_sprite_zone_covered(recipient, BODY_ZONE_CHEST))
		Fail("A jumpsuit must cover the arms and torso.", __FILE__, __LINE__)
	if(uniform.can_adjust && !uniform.alt_covers_chest)
		uniform.toggle_jumpsuit_adjust()
		if(custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM) || custom_sprite_salon_start_problem(machine, artist, recipient, "markings", BODY_ZONE_L_ARM))
			Fail("Rolled-up sleeves must expose the arms for tattooing.", __FILE__, __LINE__)
	teardown_players()


/datum/unit_test/custom_sprite_salon/locked_paint/Run()
	setup_players()
	var/obj/item/bodypart/chest = artist.get_bodypart(BODY_ZONE_CHEST)
	var/icon/silhouette = custom_sprite_silhouette(chest)
	var/list/point
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(silhouette.GetPixel(x + 1, 32 - y, "", NORTH))
				point = list(x, y)
	if(!point)
		return Fail("The fixture needs a back-facing chest pixel.", __FILE__, __LINE__)
	var/list/drawing = custom_sprite_reopen_test_drawing(point[1], point[2], "#ffffff")
	drawing["dirs"]["1"] = drawing["dirs"]["2"]
	drawing["dirs"] -= "2"
	custom_sprite_apply_round_style(artist, custom_style_package("markings", BODY_ZONE_CHEST, drawing, null))
	var/datum/custom_sprite_salon/test/session = new(machine, artist, artist, "markings", BODY_ZONE_CHEST)
	var/original_hash = custom_sprite_hash(session.original["package"]["drawing"])
	for(var/rebuild in 1 to 2)
		if(custom_sprite_hash(session.editor.workspace.serialize_drawing()) != original_hash)
			Fail("Opening or rebuilding a mirror-locked view must preserve its existing tattoo.", __FILE__, __LINE__)
		if(session.editor.workspace.is_point_allowed(point[1], point[2], "1"))
			Fail("Preserving locked paint must not make the back view editable.", __FILE__, __LINE__)
		session.editor.rebuild_resources()
	teardown_players()

/datum/unit_test/custom_sprite_salon/marking_ownership/Run()
	setup_players()
	var/previous_preferences = GLOB.preferences_datums[artist.ckey]
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, artist.mock_client)
	GLOB.preferences_datums[artist.ckey] = preferences
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", BODY_ZONE_CHEST)
	var/before = json_encode(preferences.body_markings)
	var/name = GLOB.body_markings_per_limb[BODY_ZONE_CHEST][1]
	var/recipient_before = json_encode(recipient.dna.body_markings)
	if(!session.editor.can_change_markings() || !session.editor.write_base_marking(null, name, "#112233"))
		Fail("The tattoo editor must offer native markings as part of its draft.", __FILE__, __LINE__)
	if(json_encode(preferences.body_markings) != before)
		Fail("Salon base-marking actions must leave the artist's preferences untouched.", __FILE__, __LINE__)
	if(json_encode(recipient.dna.body_markings) != recipient_before)
		Fail("Changing a tattoo preset must not change the recipient before approval.", __FILE__, __LINE__)
	session.editor.workspace.undo()
	if(length(session.editor.base_markings()))
		Fail("Undo must remove the draft's new tattoo preset.", __FILE__, __LINE__)
	session.editor.workspace.redo()
	session.editor.rebuild_resources()
	session.editor.workspace.markings_context[1]["emissive"] = TRUE
	if(!findtext(session.propose(artist), "emissive appearance disabled"))
		Fail("Disallowed native emission must be rejected before approval, not after applying.", __FILE__, __LINE__)
	session.editor.workspace.markings_context[1]["emissive"] = FALSE
	var/problem = session.propose(artist)
	if(problem)
		Fail("A native-marking-only change must be reviewable: [problem]", __FILE__, __LINE__)
	else
		var/token = session.proposal["token"]
		session.editor.write_base_marking(1, name, "#445566")
		if(session.proposal || session.accept(recipient, token))
			Fail("Changing base markings must withdraw an existing approval.", __FILE__, __LINE__)
		GLOB.custom_sprite_salon_cooldowns.Cut()
		session.propose(artist)
		token = session.proposal["token"]
		session.accept(recipient, token)
		session.complete_application(token)
		if(recipient.dna.body_markings?[BODY_ZONE_CHEST]?[name]?[MARKING_INDEX_COLOR] != "#445566")
			Fail("Approved tattoo presets must apply to the recipient's selected zone.", __FILE__, __LINE__)
	GLOB.preferences_datums[artist.ckey] = previous_preferences
	teardown_players()

/datum/unit_test/custom_sprite_salon/hair_controls/Run()
	setup_players()
	for(var/target in GLOB.custom_style_hair_targets)
		var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, target)
		var/datum/custom_sprite_editor/salon/editor = session.editor
		if(!editor.can_change_hair() || editor.can_hide_parts())
			Fail("The salon must offer base hair without Hide Parts for [target].", __FILE__, __LINE__)
		var/list/hair = editor.workspace.hair_context.Copy()
		for(var/style in editor.available_hairstyles())
			var/datum/sprite_accessory/accessory = custom_style_hair_accessories(target)[style]
			if(style != hair["style"] && !accessory.locked)
				hair["style"] = style
				break
		var/before = custom_style_package_hash(custom_sprite_live_package(recipient, target))
		var/revision = editor.draft_revision
		if(!editor.apply_hair_context(hair, "Change hairstyle") || editor.draft_revision == revision)
			Fail("Changing the salon's base hair must update the draft revision.", __FILE__, __LINE__)
		if(custom_style_package_hash(custom_sprite_live_package(recipient, target)) != before)
			Fail("The recipient's live base hair must wait for approval.", __FILE__, __LINE__)
		var/problem = session.propose(artist)
		if(problem)
			Fail("A base-hair-only change must be reviewable: [problem]", __FILE__, __LINE__)
		else
			var/token = session.proposal["token"]
			session.accept(recipient, token)
			session.complete_application(token)
			var/list/applied = custom_style_live_hair_context(recipient, target)
			if(applied["style"] != hair["style"])
				Fail("Approved base hair must be applied to the recipient.", __FILE__, __LINE__)
		GLOB.custom_sprite_salon_cooldowns.Cut()
	teardown_players()

/datum/unit_test/custom_sprite_salon/clothing_refresh/Run()
	setup_players()
	recipient.underwear = "Briefs"
	recipient.update_body()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	if(session.dress_timer)
		deltimer(session.dress_timer)
	session.refresh_editor_body()
	var/mob/living/carbon/human/dummy/body = session.editor.preview_body
	var/icon/before = icon(session.editor.guide_icons["2"])
	var/paint_before = custom_sprite_hash(session.editor.workspace.serialize_drawing())
	uniform.rolldown()
	if(!session.dress_timer)
		Fail("Changing an already-worn uniform must schedule a guide refresh.", __FILE__, __LINE__)
	else
		deltimer(session.dress_timer)
	session.refresh_editor_body()
	if(session.editor.preview_body != body)
		Fail("A clothing-only refresh must reuse the preview body.", __FILE__, __LINE__)
	if(custom_sprite_test_same_pixels(before, session.editor.guide_icons["2"]))
		Fail("The refreshed guide must show the adjusted uniform.", __FILE__, __LINE__)
	if(custom_sprite_hash(session.editor.workspace.serialize_drawing()) != paint_before)
		Fail("Clothing changes must preserve the drawing.", __FILE__, __LINE__)
	// Unlike worn items, underwear is also part of the dummy's copied appearance.
	recipient.set_all_underwear_visibility(TRUE)
	if(!session.dress_timer)
		Fail("Underwear visibility changes must schedule a preview refresh.", __FILE__, __LINE__)
	else
		deltimer(session.dress_timer)
	session.refresh_editor_body()
	if(session.editor.preview_body.underwear_visibility != recipient.underwear_visibility)
		Fail("A preview must discard its old underwear visibility after the recipient changes it.", __FILE__, __LINE__)
	session.editor.ui_close(artist)
	uniform.rolldown()
	if(session.dress_timer)
		Fail("Closed drafts must not schedule preview work.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/self_styling/Run()
	setup_players()
	if(custom_sprite_salon_start_problem(scissors, artist, artist, "hair"))
		Fail("Cutting your own hair must be allowed: [custom_sprite_salon_start_problem(scissors, artist, artist, "hair")]", __FILE__, __LINE__)
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, artist, "hair", null)
	if(!session.self_work || !session.editor.can_change_hair())
		Fail("Self-styling must own the session and allow a new haircut.", __FILE__, __LINE__)
	if(json_encode(session.locked_directions()) != json_encode(list("1")))
		Fail("Without a mirror, the back view must be locked.", __FILE__, __LINE__)
	var/list/bounds = session.editor.workspace.draw_bounds["1"]
	if(bounds[3] >= bounds[1] || session.editor.workspace.is_point_allowed(16, 10, "1"))
		Fail("A locked view must have no paintable pixels.", __FILE__, __LINE__)
	if(!paint(session))
		return Fail("The front view must stay paintable without a mirror.", __FILE__, __LINE__)
	var/list/package = session.editor.current_package()
	if(session.locked_view_problem(package))
		Fail("Painting only the front must pass the mirror check.", __FILE__, __LINE__)
	var/list/back_painted = deep_copy_list(package)
	back_painted["drawing"] = custom_sprite_test_drawing()
	if(!findtext(session.locked_view_problem(back_painted), "mirror"))
		Fail("Changing a locked view must need a mirror.", __FILE__, __LINE__)
	var/obj/item/hhmirror/mirror = allocate(/obj/item/hhmirror)
	artist.dropItemToGround(machine)
	if(!artist.put_in_inactive_hand(mirror))
		return Fail("The fixture must be able to hold the mirror.", __FILE__, __LINE__)
	// Picking the mirror up must free the view without reopening the editor.
	var/list/back_stroke = list("type" = "pencil", "layer" = 1, "dir" = "1", "color" = "[session.editor.workspace.palette[1]]ff", "points" = list(list(16, 10)))
	if(session.locked_directions() || session.locked_view_problem(back_painted) || !session.editor.workspace.new_transaction(deep_copy_list(back_stroke)))
		Fail("A held hand mirror must unlock the back view at once.", __FILE__, __LINE__)
	artist.dropItemToGround(mirror)
	if(!session.locked_directions() || session.editor.workspace.new_transaction(deep_copy_list(back_stroke)))
		Fail("Dropping the mirror must lock the back view again at once.", __FILE__, __LINE__)
	artist.put_in_inactive_hand(mirror)
	bounds = session.editor.workspace.draw_bounds["1"]
	if(bounds[3] < bounds[1])
		Fail("Picking up a mirror must immediately unlock the UI bounds before another editor action.", __FILE__, __LINE__)
	if(!session.editor.workspace.new_transaction(deep_copy_list(back_stroke)))
		Fail("Holding the mirror again must unlock the back view.", __FILE__, __LINE__)
	artist.dropItemToGround(mirror)
	var/obj/structure/mirror/wall_mirror = allocate(/obj/structure/mirror, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	if(session.locked_directions() || !session.editor.workspace.new_transaction(deep_copy_list(back_stroke)))
		Fail("Standing next to a wall mirror must unlock the back view.", __FILE__, __LINE__)
	qdel(wall_mirror)
	if(!session.locked_directions())
		Fail("Losing the mirror must lock the back view again.", __FILE__, __LINE__)
	// The back view was painted with a mirror at hand; keep one so the work can still be finished.
	artist.put_in_inactive_hand(mirror)
	// Self work applies without a consent step.
	var/error = session.propose(artist)
	if(error || session.state != "applying")
		return Fail("Finishing your own work must start applying at once: [error]", __FILE__, __LINE__)
	if(session.mirror)
		Fail("Self work must not open an approval mirror.", __FILE__, __LINE__)
	if(!session.complete_application(session.proposal["token"]))
		return Fail("Self work must apply.", __FILE__, __LINE__)
	if(length(session.awards))
		Fail("Styling yourself must not award achievements.", __FILE__, __LINE__)
	if(!artist.dna.custom_hair)
		Fail("Self work must apply its drawing.", __FILE__, __LINE__)
	// A haircut may change the style and color, but not the rest of the look.
	var/datum/custom_sprite_salon/test/haircut = new(scissors, artist, artist, "hair", null)
	var/list/restyle = haircut.editor.workspace.hair_context.Copy()
	restyle["style"] = /datum/sprite_accessory/hair/bedhead::name
	if(!haircut.editor.apply_hair_context(restyle, "Change hairstyle"))
		Fail("Self-styling must be able to change the hairstyle: [haircut.editor.transfer_error]", __FILE__, __LINE__)
	var/list/glowing = haircut.editor.workspace.hair_context.Copy()
	glowing["emissive"] = TRUE
	if(haircut.editor.apply_hair_context(glowing, "Change hair") || !haircut.editor.transfer_error)
		Fail("A haircut must not change hair glow or opacity.", __FILE__, __LINE__)
	qdel(haircut)
	teardown_players()


/datum/unit_test/custom_sprite_salon/self_hair_guide/Run()
	setup_players()
	artist.set_hairstyle("Short Hair", update = TRUE)
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, artist, "hair", null)
	var/datum/sprite_accessory/hair/current = SSaccessories.hairstyles_list[session.editor.workspace.hair_context["style"]]
	var/list/current_bounds = custom_sprite_icon_bounds(icon(current.icon, current.icon_state), SOUTH, 0)
	var/longer
	for(var/name in SSaccessories.hairstyles_list)
		var/datum/sprite_accessory/hair/candidate = SSaccessories.hairstyles_list[name]
		if(!candidate?.icon_state || candidate.locked)
			continue
		var/list/bounds = custom_sprite_icon_bounds(icon(candidate.icon, candidate.icon_state), SOUTH, 0)
		if(bounds && current_bounds && bounds[4] > current_bounds[4] + 2)
			longer = name
			break
	if(!longer)
		return Fail("The fixture needs a hairstyle that reaches further than the current one.", __FILE__, __LINE__)
	var/icon/before = icon(session.editor.guide_icons["2"])
	var/list/restyle = session.editor.workspace.hair_context.Copy()
	restyle["style"] = longer
	if(!session.editor.apply_hair_context(restyle, "Change hairstyle"))
		return Fail("Changing the hairstyle failed: [session.editor.transfer_error]", __FILE__, __LINE__)
	// The guide is drawn from the drafted look, not the one the session started with.
	if(custom_sprite_test_same_pixels(before, session.editor.guide_icons["2"]))
		Fail("A new haircut must change the guide.", __FILE__, __LINE__)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	artist.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	var/icon/dressed = icon(session.editor.guide_icons["2"])
	session.editor.rebuild_resources()
	if(custom_sprite_test_same_pixels(dressed, session.editor.guide_icons["2"]))
		Fail("Guides must show the clothes the recipient is wearing.", __FILE__, __LINE__)
	teardown_players()


/datum/unit_test/custom_sprite_salon/separate_drafts/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/haircut = new(scissors, artist, recipient, "hair", null)
	var/datum/custom_sprite_salon/test/tattoo = new(machine, artist, recipient, "markings", BODY_ZONE_L_ARM)
	if(custom_sprite_salon_session(artist.ckey, "hair", null) != haircut || custom_sprite_salon_session(artist.ckey, "markings", BODY_ZONE_L_ARM) != tattoo)
		return Fail("Each drawing must keep its own draft.", __FILE__, __LINE__)
	if(length(custom_sprite_salon_sessions_for(artist.ckey)) != 2)
		Fail("An artist may hold a draft per drawing.", __FILE__, __LINE__)
	if(length(custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)[1] != haircut)
		Fail("Scissors must resume hair work, not tattoo work.", __FILE__, __LINE__)
	if(length(custom_sprite_salon_sessions_for_tool(artist.ckey, machine)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, machine)[1] != tattoo)
		Fail("A tattoo machine must resume tattoo work, not hair work.", __FILE__, __LINE__)
	// Starting the same drawing again is what warns about discarding a draft.
	if(!custom_sprite_salon_session(artist.ckey, "hair", null))
		Fail("The hair draft must still be there.", __FILE__, __LINE__)
	qdel(haircut)
	if(custom_sprite_salon_session(artist.ckey, "hair", null) || custom_sprite_salon_session(artist.ckey, "markings", BODY_ZONE_L_ARM) != tattoo)
		Fail("Discarding one draft must leave the others alone.", __FILE__, __LINE__)
	var/datum/custom_sprite_salon/test/facial = new(scissors, artist, recipient, "facial_hair", null)
	if(length(custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)[1] != facial)
		Fail("Hair and facial hair must be separate drafts.", __FILE__, __LINE__)
	teardown_players()


/datum/unit_test/custom_sprite_salon/tattoo_geometry/Run()
	setup_players()
	var/obj/item/bodypart/limb = recipient.get_bodypart(BODY_ZONE_L_ARM)
	// Same bodypart type, but a different sprite selected through character customization.
	limb.change_appearance(BODYPART_ICON_HUMANOID, SPECIES_HUMANOID, TRUE, FALSE)
	var/list/expected = custom_sprite_body_draw_mask(recipient, BODY_ZONE_L_ARM)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", BODY_ZONE_L_ARM)
	if(json_encode(session.editor.workspace.draw_mask) != json_encode(expected))
		Fail("Tattoo masks must cover the recipient's full customized limb, exactly like character setup.", __FILE__, __LINE__)
	var/obj/item/bodypart/preview_limb = session.editor.preview_body.get_bodypart(BODY_ZONE_L_ARM)
	if(preview_limb.custom_sprite_icon_file() != limb.custom_sprite_icon_file() || preview_limb.limb_id != limb.limb_id)
		Fail("Salon previews must preserve custom limb sprite files and state IDs.", __FILE__, __LINE__)
	for(var/direction in GLOB.cardinals)
		var/list/rows = expected["[direction]"]
		for(var/y in 0 to 31)
			for(var/x in 0 to 31)
				if(copytext(rows[y + 1], x + 1, x + 2) == "1" && !session.editor.workspace.is_point_allowed(x, y, "[direction]"))
					Fail("Tattoo bounds must include every limb pixel in direction [direction].", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/tattoo_hair_layer/Run()
	setup_players()
	// A style long enough to hang over the chest.
	var/long_style
	var/lowest = 0
	for(var/name in SSaccessories.hairstyles_list)
		var/datum/sprite_accessory/hair/candidate = SSaccessories.hairstyles_list[name]
		if(!candidate?.icon_state || candidate.locked)
			continue
		var/list/extent = custom_sprite_icon_bounds(icon(candidate.icon, candidate.icon_state), SOUTH, 0)
		if(extent && extent[4] > lowest)
			lowest = extent[4]
			long_style = name
	recipient.set_hairstyle(long_style, update = TRUE)
	var/obj/item/organ/wings/moth/wings = new
	wings.Insert(recipient, special = TRUE)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", BODY_ZONE_CHEST)
	var/datum/custom_sprite_editor/salon/editor = session.editor
	if(!length(editor.preview_body.overlays_standing[HAIR_LAYER]))
		return Fail("The fixture must have hair to leave out of the guide.", __FILE__, __LINE__)
	if(!editor.can_hide_parts() || !editor.hide_parts)
		Fail("Tattoo guides must keep hair and parts out of the way by default.", __FILE__, __LINE__)
	for(var/obj/item/bodypart/limb as anything in editor.preview_body.bodyparts)
		for(var/datum/bodypart_overlay/mutant/part in limb.bodypart_overlays)
			if(!istype(part, /datum/bodypart_overlay/mutant/taur_body))
				Fail("Wings and tails must be off the preview body while parts are hidden.", __FILE__, __LINE__)
	// Hidden means gone from the whole canvas: hair hanging beside the body counts too.
	var/icon/hidden = editor.guide_icons["2"]
	// Build the comparison through the mob itself, not the helper this is checking.
	var/list/hair = editor.preview_body.overlays_standing[HAIR_LAYER]
	editor.preview_body.remove_overlay(HAIR_LAYER)
	var/icon/without_hair = custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)
	editor.preview_body.overlays_standing[HAIR_LAYER] = hair
	editor.preview_body.apply_overlay(HAIR_LAYER)
	var/icon/with_hair = custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)
	if(custom_sprite_test_same_pixels(without_hair, with_hair))
		return Fail("The fixture's hair must be visible on the body it's drawn on.", __FILE__, __LINE__)
	// Guides are built while other renders read the same body, so hiding hair must not touch it.
	custom_sprite_limb_appearance(editor.preview_body)
	if(!custom_sprite_test_same_pixels(with_hair, custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)))
		Fail("Hiding hair must leave the body it was taken from alone.", __FILE__, __LINE__)
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			if(hidden.GetPixel(x, y) != without_hair.GetPixel(x, y))
				return Fail("Hidden hair must leave the guide alone at [x],[y].", __FILE__, __LINE__)
	editor.hide_parts = FALSE
	editor.rebuild_resources()
	if(custom_sprite_test_same_pixels(hidden, editor.guide_icons["2"]))
		Fail("Putting hair and parts back on must change the guide.", __FILE__, __LINE__)
	var/wings_back = FALSE
	for(var/obj/item/bodypart/limb as anything in editor.preview_body.bodyparts)
		for(var/datum/bodypart_overlay/mutant/part in limb.bodypart_overlays)
			if(istype(part, /datum/bodypart_overlay/mutant/wings))
				wings_back = TRUE
	if(!wings_back)
		Fail("Showing parts again must put the recipient's wings back.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/mirror_choices/Run()
	setup_players()
	var/datum/client_interface/player = recipient.mock_client
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, player)
	player.prefs = preferences
	GLOB.preferences_datums[recipient.ckey] = preferences
	recipient.real_name = preferences.read_preference(/datum/preference/name/real_name)
	recipient.mind_initialize()
	recipient.mind.original_character_slot_index = preferences.default_slot
	for(var/permanent in list(FALSE, TRUE))
		GLOB.custom_sprite_salon_cooldowns.Cut()
		custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_L_ARM, null, null))
		var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", BODY_ZONE_L_ARM)
		paint(session)
		session.propose(artist)
		var/datum/custom_sprite_mirror/mirror = session.mirror
		var/list/static_data = mirror.ui_static_data(recipient)
		var/list/data = mirror.ui_data(recipient)
		if(length(static_data["before"]) != 4 || length(static_data["after"]) != 4 || data["before"] || data["after"] || data["timeout"] <= 0)
			Fail("Mirror images must be static while the small timeout payload updates.", __FILE__, __LINE__)
		var/list/prior = preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)
		var/old_hash = custom_style_package_hash(prior)
		var/token = session.proposal["token"]
		var/datum/tgui/ui = new(recipient, mirror, "CustomSpriteMirror")
		mirror.ui_act("export", list("token" = "stale"), ui)
		if(mirror.save_message || session.state != "awaiting approval")
			Fail("A stale export must do nothing.", __FILE__, __LINE__)
		mirror.ui_act("export", list("token" = token), ui)
		// The mock recipient has no real client to download to; reaching the exporter reports that.
		if(mirror.save_message != "You need to be connected to export." || session.state != "awaiting approval" || custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)) != old_hash)
			Fail("Export must be available before acceptance without applying or saving the proposal.", __FILE__, __LINE__)
		mirror.ui_act(permanent ? "acceptPermanent" : "accept", list("token" = token), ui)
		qdel(ui)
		if(session.state != "applying" || session.save_on_completion != permanent)
			Fail("The recipient's acceptance choice must bind to the reviewed proposal.", __FILE__, __LINE__)
		if(custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)) != old_hash)
			Fail("Approval must not save before application completes.", __FILE__, __LINE__)
		var/list/applied = session.proposal["package"]
		if(!session.complete_application(token))
			Fail("Valid reviewed work must still apply.", __FILE__, __LINE__)
		var/saved_hash = custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM))
		if(saved_hash != (permanent ? custom_style_package_hash(applied) : old_hash))
			Fail("Only permanent acceptance may save the applied proposal.", __FILE__, __LINE__)
		if(permanent && custom_style_package_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)) != old_hash)
			Fail("Permanent acceptance must keep the replaced saved style.", __FILE__, __LINE__)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	paint(session)
	session.propose(artist)
	var/token = session.proposal["token"]
	session.accept(recipient, token, save_permanently = TRUE)
	if(session.complete_application(token, finished = FALSE) || session.save_on_completion || session.state != "drafting")
		Fail("Interrupted work must discard permanent-save authorization and retain the draft.", __FILE__, __LINE__)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	session.mirror.expires_at = world.time
	if(session.accept(recipient, token, save_permanently = TRUE) || session.state != "drafting" || session.save_on_completion)
		Fail("A late approval must fail even before the expiry timer runs.", __FILE__, __LINE__)
	GLOB.preferences_datums -= recipient.ckey
	teardown_players()

/datum/unit_test/custom_sprite_salon/editor_sounds/Run()
	setup_players()
	for(var/target in list("hair", "markings"))
		var/tattoo = target == "markings"
		var/datum/custom_sprite_salon/test/session = new(tattoo ? machine : scissors, artist, recipient, target, tattoo ? BODY_ZONE_L_ARM : null)
		var/datum/custom_sprite_editor/salon/editor = session.editor
		var/channels_before = length(SSsounds.reserved_channels)
		// Register the open UI without needing a DreamSeeker window in a native test.
		var/datum/tgui/ui = new(artist, editor, "CustomHairEditor")
		editor.open_uis = list(ui)
		editor.ui_interact(artist, ui)
		if(editor.drawing_sound || editor.drawing_ambience)
			Fail("An idle open editor must stay silent.", __FILE__, __LINE__)
		for(var/list/invalid as anything in list(list("dir" = "2", "x" = -1, "y" = 0, "erasing" = TRUE), list("dir" = "2", "x" = 9999, "y" = 0, "erasing" = TRUE), list("dir" = "invalid", "x" = 1, "y" = 1), list("dir" = "2", "x" = "text", "y" = 1)))
			editor.ui_act("drawing", invalid, ui)
		if(editor.drawing_sound || editor.drawing_ambience)
			Fail("Malformed or off-canvas activity must not start sounds.", __FILE__, __LINE__)
		var/list/activity
		for(var/y in 0 to editor.workspace.height - 1)
			for(var/x in 0 to editor.workspace.width - 1)
				if(editor.workspace.is_point_allowed(x, y, "2"))
					activity = list("dir" = "2", "x" = x, "y" = y)
					break
			if(activity)
				break
		var/revision = editor.draft_revision
		if(editor.ui_act("drawing", activity, ui) || editor.draft_revision != revision)
			Fail("Brush activity must not change pixels or request a UI update.", __FILE__, __LINE__)
		var/datum/looping_sound/sound = editor.drawing_sound
		if(!sound?.is_active() || sound.parent != artist || length(SSsounds.reserved_channels) != channels_before + (tattoo ? 2 : 1))
			Fail("The first brush movement must immediately start sounds on the artist.", __FILE__, __LINE__)
		if(tattoo && (!sound.vary || !editor.drawing_ambience?.native_repeat_active))
			Fail("Tattooing needs varied needle bursts and steady native-looped ambience.", __FILE__, __LINE__)
		var/sound_timer = sound.timer_id
		editor.ui_act("drawing", activity, ui)
		if(editor.drawing_sound != sound || sound.timer_id != sound_timer)
			Fail("Drawing during the cooldown must not restart or duplicate the clip.", __FILE__, __LINE__)
		if(!istype(sound, /datum/looping_sound/salon_snipping/drawing) || sound.mid_length_vary || sound.mid_length != (tattoo ? 12 SECONDS : 5 SECONDS))
			Fail("Brush clips must play once with a fixed five/twelve-second cooldown.", __FILE__, __LINE__)
		artist.forceMove(get_step(artist, NORTH))
		if(!sound.is_active())
			Fail("Drawing sounds must survive movement while the editor stays open.", __FILE__, __LINE__)
		if(tattoo)
			sleep(2 SECONDS)
			editor.ui_act("drawing", activity, ui)
			sleep(2 SECONDS)
			if(!editor.drawing_ambience?.is_active())
				Fail("Continued drawing must extend the ambience tail.", __FILE__, __LINE__)
			sleep(2 SECONDS)
			if(editor.drawing_ambience || editor.ambience_stop_timer)
				Fail("Tattoo ambience must stop after drawing has been idle for three seconds.", __FILE__, __LINE__)
		else
			sleep(6 SECONDS)
			if(sound.is_active())
				Fail("A snip must not loop while the drawing is idle.", __FILE__, __LINE__)
		// Advance only the cooldown, avoiding a twelve-second sleep for a repeated clip.
		editor.drawing_sound_cooldown = 0
		editor.ui_act("drawing", activity, ui)
		if(!sound.is_active() || sound.timer_id == sound_timer)
			Fail("The next brush movement after cooldown must start another clip.", __FILE__, __LINE__)
		editor.ui_close(artist)
		if(!QDELETED(sound) || editor.drawing_sound || editor.drawing_ambience || editor.ambience_stop_timer || length(SSsounds.reserved_channels) != channels_before)
			Fail("Closing the editor must silence and release both sound channels.", __FILE__, __LINE__)
		editor.ui_interact(artist, ui)
		if(editor.drawing_sound || editor.drawing_ambience)
			Fail("Reopening a retained draft must stay silent until drawing resumes.", __FILE__, __LINE__)
		editor.drawing_sound_cooldown = 0
		editor.ui_act("drawing", activity, ui)
		qdel(session)
		if(length(SSsounds.reserved_channels) != channels_before)
			Fail("Discarding open work must release its sound channels.", __FILE__, __LINE__)
		artist.forceMove(run_loc_floor_bottom_left)
	teardown_players()

/datum/unit_test/custom_sprite_salon/whole_body/Run()
	setup_players()
	var/datum/client_interface/player = recipient.mock_client
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, player)
	player.prefs = preferences
	GLOB.preferences_datums[recipient.ckey] = preferences
	recipient.real_name = preferences.read_preference(/datum/preference/name/real_name)
	recipient.mind_initialize()
	recipient.mind.original_character_slot_index = preferences.default_slot
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing(), null))
	var/arm_hash = custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_L_ARM))
	var/hair_hash = custom_style_package_hash(custom_sprite_live_package(recipient, "hair"))
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", null)
	if(session.label() != "whole-body tattoo" || session.participant_problem() || custom_sprite_salon_start_problem(machine, artist, recipient, "markings", null))
		Fail("The whole-body marking slot must be a named, supported salon target.", __FILE__, __LINE__)
	if(custom_sprite_salon_session(artist.ckey, "markings", null) != session || session.editor.workspace.width != 32 || !paint(session))
		Fail("Whole-body work must retain a separate, paintable 32-pixel draft.", __FILE__, __LINE__)
	var/list/exported = custom_style_parse(custom_style_export_text(session.editor.current_package()))
	if(exported["error"] || session.editor.candidate_problem(exported["package"]) || !isnull(exported["package"]["zone"]))
		Fail("A whole-body salon draft must round-trip through the shared style transfer format.", __FILE__, __LINE__)
	var/problem = session.propose(artist)
	if(problem)
		Fail("Whole-body work must reach recipient approval: [problem]", __FILE__, __LINE__)
	else
		var/token = session.proposal["token"]
		var/list/applied = session.proposal["package"]
		if(recipient.dna.custom_markings || preferences.custom_markings)
			Fail("Proposing whole-body work must leave the recipient and saved character unchanged.", __FILE__, __LINE__)
		if(!session.accept(recipient, token, save_permanently = TRUE) || !session.complete_application(token))
			Fail("Reviewed whole-body work must apply and honor permanent acceptance.", __FILE__, __LINE__)
		if(!recipient.dna.custom_markings || custom_style_package_hash(preferences.custom_style_saved_package("markings", null)) != custom_style_package_hash(applied))
			Fail("Whole-body application must update the live and saved whole-body marking slots.", __FILE__, __LINE__)
		var/list/history = recipient.custom_sprite_round_history?[custom_style_key("markings", null)]
		if(!history || history["drawing"])
			Fail("Whole-body history must preserve an explicitly empty previous drawing.", __FILE__, __LINE__)
		else
			GLOB.custom_sprite_salon_cooldowns.Cut()
			var/datum/custom_sprite_salon/test/restore = new(machine, artist, recipient, "markings", null, custom_style_copy_package(history))
			problem = restore.propose(artist)
			token = restore.proposal?["token"]
			if(problem || !restore.accept(recipient, token) || !restore.complete_application(token) || recipient.dna.custom_markings)
				Fail("Whole-body restoration must use approval and restore the previous empty drawing.", __FILE__, __LINE__)
	if(custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_L_ARM)) != arm_hash || custom_style_package_hash(custom_sprite_live_package(recipient, "hair")) != hair_hash)
		Fail("Whole-body work and restoration must preserve independent limb tattoos and hair.", __FILE__, __LINE__)
	GLOB.preferences_datums -= recipient.ckey
	teardown_players()

/datum/unit_test/custom_sprite_salon/whole_body_coverage/Run()
	setup_players()
	if(custom_sprite_salon_target_problem(recipient, "markings", null))
		Fail("An exposed body must support whole-body tattooing.", __FILE__, __LINE__)
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	if(!findtext(custom_sprite_salon_target_problem(recipient, "markings", null), "covered"))
		Fail("Whole-body work must reject covered hands even when their arms are exposed.", __FILE__, __LINE__)
	recipient.dropItemToGround(gloves)
	var/obj/item/clothing/shoes/shoes = allocate(/obj/item/clothing/shoes/sneakers/black)
	recipient.equip_to_slot_if_possible(shoes, ITEM_SLOT_FEET)
	if(!findtext(custom_sprite_salon_target_problem(recipient, "markings", null), "covered"))
		Fail("Whole-body work must reject covered feet even when their legs are exposed.", __FILE__, __LINE__)
	recipient.dropItemToGround(shoes)
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	if(!findtext(custom_sprite_salon_target_problem(recipient, "markings", null), "covered"))
		Fail("Whole-body work must reject covered limbs and torso.", __FILE__, __LINE__)
	recipient.dropItemToGround(uniform)
	var/obj/item/bodypart/arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	arm.is_husked = TRUE
	if(!custom_sprite_salon_target_problem(recipient, "markings", null))
		Fail("Whole-body work must reject an existing husked limb.", __FILE__, __LINE__)
	arm.is_husked = FALSE
	arm.drop_limb(TRUE)
	allocated += arm
	if(custom_sprite_salon_target_problem(recipient, "markings", null))
		Fail("An already missing limb must not prevent work on the remaining body.", __FILE__, __LINE__)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", null)
	arm.try_attach_limb(recipient, special = TRUE)
	if(!findtext(session.participant_problem(), "changed"))
		Fail("Attaching a limb after whole-body consent must invalidate its anatomy snapshot.", __FILE__, __LINE__)
	qdel(session)
	session = new(machine, artist, recipient, "markings", null)
	var/obj/item/bodypart/arm/left/replacement = allocate(/obj/item/bodypart/arm/left)
	replacement.replace_limb(recipient)
	if(!findtext(session.participant_problem(), "changed"))
		Fail("Replacing a limb without changing limb count must invalidate whole-body consent.", __FILE__, __LINE__)
	qdel(session)
	session = new(machine, artist, recipient, "markings", null)
	replacement.drop_limb(TRUE)
	if(!findtext(session.participant_problem(), "changed"))
		Fail("Removing a limb after whole-body consent must invalidate its anatomy snapshot.", __FILE__, __LINE__)
	teardown_players()

/datum/unit_test/custom_sprite_salon/whole_body_taur/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings", null)
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(recipient)
	if(!organ)
		teardown_players()
		return Fail("The whole-body fixture needs a real taur organ.", __FILE__, __LINE__)
	if(!findtext(session.participant_problem(), "replaced"))
		Fail("Adding a taur body must invalidate existing whole-body consent.", __FILE__, __LINE__)
	qdel(session)
	session = new(machine, artist, recipient, "markings", null)
	if(session.participant_problem() || session.editor.workspace.width != 64 || session.editor.workspace.height != 32 || !paint(session))
		Fail("Whole-body taur work must expose its complete 64 by 32 canvas despite invisible leg slots.", __FILE__, __LINE__)
	organ.hide_self = TRUE
	if(!findtext(session.participant_problem(), "covered"))
		Fail("Whole-body work must not change a concealed taur body.", __FILE__, __LINE__)
	organ.hide_self = FALSE
	var/list/exported = custom_style_parse(custom_style_export_text(session.editor.current_package()))
	if(exported["error"] || session.editor.candidate_problem(exported["package"]) || custom_sprite_width(exported["package"]["drawing"]) != 64)
		Fail("Whole-body taur exports must preserve the wide canvas and reimport into the same target.", __FILE__, __LINE__)
	var/obj/item/organ/taur_body/replacement = allocate(organ.type)
	var/datum/bodypart_overlay/mutant/taur_body/replacement_overlay = replacement.bodypart_overlay
	replacement_overlay.set_appearance_from_name("Cow (Spotted)")
	replacement_overlay.imprint_on_next_insertion = FALSE
	allocated += organ
	replacement.Insert(recipient, special = TRUE)
	if(!findtext(session.participant_problem(), "replaced"))
		Fail("Replacing the taur organ while keeping every limb must invalidate whole-body consent.", __FILE__, __LINE__)
	teardown_players()

#endif
