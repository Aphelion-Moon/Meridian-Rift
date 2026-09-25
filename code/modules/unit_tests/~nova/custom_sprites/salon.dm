/// Drives application directly instead of sleeping in a timed action, and records awards.
/datum/custom_sprite_salon/test
	/// Achievement types emitted by successful test applications.
	var/list/awards = list()

/datum/custom_sprite_salon/test/apply_proposal(token)
	return

/datum/custom_sprite_salon/test/award(mob/player, award_type)
	awards += award_type

/// Counts part checks, so one window action can be shown to work out the region locks once.
/datum/custom_sprite_salon/test/lock_counting
	/// part_problem() calls so far.
	var/part_checks = 0

/datum/custom_sprite_salon/test/lock_counting/part_problem(mob/living/carbon/human/recipient, key)
	part_checks++
	return ..()

/// Counts body redraws, so applying several regions can be shown to redraw once.
/mob/living/carbon/human/consistent/redraw_counting
	/// update_body() calls so far.
	var/redraws = 0

/mob/living/carbon/human/consistent/redraw_counting/update_body(is_creating = FALSE)
	redraws++
	return ..()

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
	TEST_ASSERT(!(source.stopped_channel != channel || bystander.stopped_channel != channel), "Deleting the source must silence its own channel as well as nearby listeners.")
	TEST_ASSERT(!(sound.is_active() || sound.listeners || SSsounds.reserved_channels["[channel]"]), "Source deletion must release the clip, timer and reserved channel.")
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

/datum/unit_test/custom_sprite_salon/proc/setup_players(recipient_type = /mob/living/carbon/human/consistent)
	artist = allocate(/mob/living/carbon/human/consistent)
	recipient = allocate(recipient_type, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
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

/// Assertions stop a test early, so players are always released here rather than at the end of Run().
/datum/unit_test/custom_sprite_salon/Destroy()
	if(artist)
		GLOB.preferences_datums -= list(artist.ckey, recipient.ckey)
		teardown_players()
	return ..()

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

/// Paints one pixel a region owns on the tattoo canvas with a new color, as a stroke from the window would.
/datum/unit_test/custom_sprite_salon/proc/paint_region(datum/custom_sprite_salon/session, zone, direction = "2")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/point = custom_sprite_test_region_pixel(canvas, zone, direction)
	var/color = "#[copytext(md5("[zone][length(canvas.workspace.undo_stack)]"), 1, 7)]"
	canvas.workspace.update_palette(canvas.workspace.palette | color)
	if(!point || !canvas.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = direction, "color" = "[color]ff", "points" = list(point))))
		return FALSE
	canvas.draft_changed()
	return TRUE

/datum/unit_test/custom_sprite_salon/timed_sounds
	/// Number of do_after checks observed with sound channels reserved.
	var/sound_checks = 0

/datum/unit_test/custom_sprite_salon/timed_sounds/proc/check_sounds(expected_channels, interrupted)
	sound_checks++
	TEST_ASSERT(length(SSsounds.reserved_channels) == expected_channels, "Salon audio must start before the timed work and remain active during it.")
	return !interrupted

/datum/unit_test/custom_sprite_salon/timed_sounds/Run()
	setup_players()
	for(var/tattoo in list(FALSE, TRUE))
		for(var/interrupted in list(FALSE, TRUE))
			var/before = length(SSsounds.reserved_channels)
			sound_checks = 0
			var/completed = do_salon_work(artist, 0.3 SECONDS, recipient, tattoo, CALLBACK(src, PROC_REF(check_sounds), before + (tattoo ? 2 : 1), interrupted))
			TEST_ASSERT(!(!sound_checks || completed == interrupted), "The timed salon action must run its validity callback and respect interruption.")
			TEST_ASSERT(length(SSsounds.reserved_channels) == before, "Completion and interruption must both release salon sound channels.")

/datum/unit_test/custom_sprite_salon/Run()
	setup_players()
	TEST_ASSERT(!custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"), "Adjacent distinct players with scissors must be able to start: [custom_sprite_salon_start_problem(scissors, artist, recipient, "hair")]")
	TEST_ASSERT(!custom_sprite_salon_start_problem(scissors, artist, artist, "hair"), "Working on yourself must be allowed.")
	TEST_ASSERT(!custom_sprite_salon_start_problem(machine, artist, recipient, "markings"), "An exposed body must be tattooable with a held tattoo machine.")
	var/datum/client_interface/recipient_client = recipient.mock_client
	recipient.mock_client = null
	TEST_ASSERT(custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"), "A disconnected recipient must be rejected.")
	recipient.mock_client = recipient_client
	recipient.obscured_slots |= HIDEHAIR
	TEST_ASSERT(custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"), "Covered hair must be rejected.")
	recipient.obscured_slots &= ~HIDEHAIR
	recipient.set_hairstyle("Bald", update = TRUE)
	TEST_ASSERT(!custom_sprite_salon_start_problem(scissors, artist, recipient, "hair"), "Custom hair must be allowed on bald heads.")
	custom_sprite_apply_round_style(recipient, custom_style_package("hair", null, custom_sprite_test_drawing(), custom_style_live_hair_context(recipient)))
	var/obj/item/bodypart/head/bald_head = recipient.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(length(bald_head.get_hair_overlays()), "Custom hair must render on a bald head.")
	TEST_ASSERT(!custom_style_parse(custom_style_export_text(custom_sprite_live_package(recipient, "hair", null)))["error"], "Bald custom hair must export and import.")
	custom_sprite_apply_round_style(recipient, custom_style_package("hair", null, null, custom_style_live_hair_context(recipient)))
	TEST_ASSERT(!length(bald_head.get_hair_overlays()), "Removing custom hair from a bald head must leave no hair overlays.")
	recipient.set_hairstyle("Short Hair", update = TRUE)

	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair", null)
	TEST_ASSERT(!(custom_sprite_salon_session(artist.ckey, "hair", recipient.ckey) != session || session.editor?.context != "salon"), "A salon session must own the artist's retained draft for this recipient.")
	TEST_ASSERT(session.propose(artist) == "Nothing has changed yet.", "Unchanged submissions must not be proposed.")
	var/icon/guide = session.editor.guide_icons["2"]
	var/body_pixels = 0
	for(var/y in 1 to 14)
		for(var/x in 1 to 32)
			if(guide?.GetPixel(x, y))
				body_pixels++
	TEST_ASSERT(body_pixels, "Artist guides must show the whole body they're working on.")
	TEST_ASSERT(paint(session), "The salon editor rejected paint inside the hair bounds.")
	TEST_ASSERT(session.propose(recipient), "Only the artist may finish the work.")
	var/error = session.propose(artist)
	TEST_ASSERT(!(error || session.state != "awaiting approval" || !session.mirror || !GLOB.custom_sprite_salon_prompts[recipient.ckey]), "A changed draft must open the recipient's mirror: [error]")
	var/list/before = session.mirror.before_urls
	TEST_ASSERT(!(length(before) != 4 || length(session.mirror.after_urls) != 4 || before["2"] == session.mirror.after_urls["2"]), "The mirror must render all four directions before and after the change.")
	var/first_token = session.proposal["token"]
	paint(session)
	TEST_ASSERT(!(session.state != "drafting" || session.mirror || session.proposal), "Editing must withdraw the pending proposal.")
	TEST_ASSERT(findtext(session.propose(artist), "wait"), "Repeated requests between the same players must honor the cooldown.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	var/token = session.proposal["token"]
	TEST_ASSERT(!(session.accept(recipient, first_token) || session.accept(artist, token)), "Stale tokens and other players must not approve.")
	session.mirror.ui_close(recipient)
	TEST_ASSERT(session.state == "drafting", "Closing the mirror must decline, never accept.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	artist.forceMove(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!(session.accept(recipient, token) || session.state != "drafting"), "Approval must recheck reachability.")
	artist.forceMove(run_loc_floor_bottom_left)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	TEST_ASSERT(!(!session.accept(recipient, token) || session.state != "applying"), "A valid approval must start the timed application.")
	artist.forceMove(locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!(session.complete_application(token) || session.state != "drafting" || !session.editor), "Walking away before completion must fail without losing the draft.")
	artist.forceMove(run_loc_floor_bottom_left)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	session.accept(recipient, token)
	var/list/applied = session.proposal["packages"]["hair"]
	TEST_ASSERT(!(!session.complete_application(token) || !QDELETED(session)), "A valid completion must apply and end the session.")
	TEST_ASSERT(!(session.complete_application(token) || length(session.awards) != 2), "Replayed completion must not apply or award twice.")
	TEST_ASSERT(custom_sprite_hash(custom_sprite_validate(recipient.dna.custom_hair)) == custom_sprite_hash(custom_sprite_validate(custom_sprite_appearance_drawing(applied["drawing"], FALSE))), "The approved revision must become the recipient's round hair.")
	var/list/history = recipient.custom_sprite_round_history?["hair"]
	TEST_ASSERT(!(!history || !("drawing" in history) || history["drawing"] || !history["hair"]), "Application must keep the previous style, including an explicit empty drawing and base look.")

	var/list/restored = list("hair" = deep_copy_list(history))
	var/datum/custom_sprite_salon/test/restore = new(scissors, artist, recipient, "hair", restored)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	error = restore.propose(artist)
	TEST_ASSERT(!error, "Restoration must open the mirror: [error]")
	token = restore.proposal["token"]
	TEST_ASSERT(!(!restore.accept(recipient, token) || !restore.complete_application(token)), "Restoration must use the same approval and application flow.")
	TEST_ASSERT(!(recipient.dna.custom_hair || !recipient.custom_sprite_round_history["hair"]["drawing"] || length(restore.awards)), "Restoration must swap current and previous styles without awarding achievements.")

	var/datum/custom_sprite_salon/test/tattoo = new(machine, artist, recipient, "markings")
	TEST_ASSERT(istype(tattoo.editor, /datum/custom_sprite_editor/markings/salon), "Tattoo work must use the whole-body canvas.")
	TEST_ASSERT(paint_region(tattoo, BODY_ZONE_L_ARM), "The tattoo canvas must accept paint on the left arm.")
	var/obj/item/bodypart/arm/left/replacement = new
	replacement.replace_limb(recipient)
	TEST_ASSERT(findtext(tattoo.propose(artist), "replaced"), "A replaced limb must invalidate a tattoo that changes it.")
	TEST_ASSERT(!(!tattoo.editor || !tattoo.editor.workspace.edited_directions["2"]), "Invalidation must keep the tattoo draft for export.")
	qdel(tattoo)
	var/datum/custom_sprite_salon/test/hair_session = new(scissors, artist, recipient, "hair", null)
	var/list/other_hair = hair_session.editor.workspace.hair_context.Copy()
	other_hair["style"] = "Mohawk"
	TEST_ASSERT(!hair_session.editor.candidate_problem(custom_style_package("hair", null, null, other_hair)), "Salon imports must allow another unlocked base haircut.")
	other_hair["opacity"] = other_hair["opacity"] == 0.5 ? 1 : 0.5
	TEST_ASSERT(hair_session.editor.candidate_problem(custom_style_package("hair", null, null, other_hair)), "Salon imports must preserve the recipient's other hair settings.")
	recipient.ckey = "salontestbodythief"
	TEST_ASSERT(hair_session.participant_problem(), "A changed controlling player must invalidate the work.")
	recipient.ckey = "salontestrecipient"
	hair_session.editor.ui_close(artist)
	TEST_ASSERT(!(hair_session.editor.resources_ready || hair_session.editor.preview_body || !hair_session.editor.workspace), "Closing the salon editor must keep the draft and release preview resources.")
	TEST_ASSERT(!(!custom_sprite_salon_resume(scissors, artist) || !custom_sprite_salon_resume(machine, artist)), "The tool's self-use action must handle resuming.")
	hair_session.editor.ui_interact(artist)
	TEST_ASSERT(!(!hair_session.editor.resources_ready || length(hair_session.editor.guide_urls) != 4), "Resuming must rebuild preview resources.")

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
	donor.dna.custom_limb_markings = list()
	donor.dna.custom_limb_markings[zone] = custom_sprite_appearance_drawing(custom_sprite_test_drawing(), FALSE)
	donor.dna.body_markings[zone] = list("Tiger Stripe" = list("#ff0000", 0))
	donor.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/limb = donor.get_bodypart(zone)
	limb.drop_limb(TRUE)
	var/obj/item/bodypart/original = recipient.get_bodypart(zone)
	TEST_ASSERT(limb.replace_limb(recipient), "The fixture's donor limb must attach.")
	qdel(original)
	return limb

/datum/unit_test/custom_sprite_salon/donor_appearance/Run()
	setup_players()
	var/obj/item/bodypart/arm = transplant_donor(BODY_ZONE_L_ARM)
	var/original_markings = json_encode(arm.markings)
	var/original_draw_color = arm.draw_color
	var/datum/bodypart_overlay/custom_marking/zone = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
	var/zone_hash = zone?.drawing_hash
	TEST_ASSERT(!(arm.skin_tone != "african2" || arm.skin_tone == recipient.skin_tone || !zone_hash || !length(arm.markings)), "The attached fixture must retain differently colored skin, native markings and donor paint.")
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	var/obj/item/bodypart/preview_arm = preview.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/preview_zone = locate(/datum/bodypart_overlay/custom_marking/zone) in preview_arm.bodypart_overlays
	TEST_ASSERT(!(preview_arm.draw_color != original_draw_color || json_encode(preview_arm.markings) != original_markings || preview_zone?.drawing_hash != zone_hash), "Salon dummies must preserve donor skin, native markings and limb paint.")
	qdel(preview)
	for(var/list/package as anything in list(custom_style_package("hair", null, custom_sprite_test_drawing(), custom_style_live_hair_context(recipient)), custom_style_package("markings", BODY_ZONE_R_ARM, custom_sprite_test_drawing(), null)))
		custom_sprite_apply_round_style(recipient, package)
		TEST_ASSERT(!(recipient.get_bodypart(BODY_ZONE_L_ARM) != arm || arm.owner != recipient || arm.draw_color != original_draw_color || json_encode(arm.markings) != original_markings || QDELETED(zone) || zone.drawing_hash != zone_hash), "Editing [package["target"]] on another part must preserve the donor arm and its paint.")

/datum/unit_test/custom_sprite_salon/donor_history/Run()
	setup_players()
	var/obj/item/bodypart/arm = transplant_donor(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/zone = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
	var/original_hash = zone.drawing_hash
	var/key = custom_style_key("markings", BODY_ZONE_L_ARM)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/list/start = session.original[key]
	var/list/start_package = start["package"]
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/results = canvas.region_results()
	var/list/arm_result = results[BODY_ZONE_L_ARM]
	TEST_ASSERT(!(custom_sprite_hash(start_package["drawing"]) != original_hash || custom_sprite_hash(arm_result["drawing"]) != original_hash), "A transplanted limb's region must start from its paint snapshot, even when recipient DNA has no tattoo.")
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The donor arm must be paintable on the tattoo canvas.")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "The donor tattoo must be proposable: [error]")
	var/token = session.proposal["token"]
	TEST_ASSERT(!(!session.accept(recipient, token) || !session.complete_application(token)), "Approved work on the donor arm must complete.")
	var/list/history = recipient.custom_sprite_round_history?[key]
	TEST_ASSERT(custom_sprite_hash(history?["drawing"]) == original_hash, "Round history must retain the actual donor tattoo for restoration.")
	custom_sprite_apply_round_style(recipient, history)
	var/datum/bodypart_overlay/custom_marking/restored = locate(/datum/bodypart_overlay/custom_marking/zone) in arm.bodypart_overlays
	TEST_ASSERT(restored?.drawing_hash == original_hash, "Restoring round history must restore the donor's original paint.")

/datum/unit_test/custom_sprite_salon/donor_head/Run()
	setup_players()
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD)
	var/paint_hash = custom_sprite_hash(head.custom_hair)
	var/original_skin = head.skin_tone
	var/list/package = custom_sprite_live_package(recipient, "hair")
	TEST_ASSERT(!(custom_sprite_hash(package["drawing"]) != paint_hash || package["hair"]["opacity"] != 128 || package["hair"]["gradient_color"] != "#123456"), "Hair packages must capture the attached head's paint, opacity and gradient.")
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	var/obj/item/bodypart/head/preview_head = preview.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!(preview_head.skin_tone != original_skin || preview_head.hair_alpha != 128 || custom_sprite_hash(preview_head.custom_hair) != paint_hash), "The salon dummy must show the transplanted head's skin and hair.")
	qdel(preview)
	custom_sprite_apply_round_style(recipient, package)
	TEST_ASSERT(!(head.skin_tone != original_skin || head.hair_alpha != 128 || custom_sprite_hash(head.custom_hair) != paint_hash), "Applying hair must preserve donor head identity and its unrelated appearance.")

/datum/unit_test/custom_sprite_salon/hair_extension_preview/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	qdel(session.editor)
	var/datum/custom_sprite_editor/salon/test_icons/editor = new(session)
	session.editor = editor
	editor.workspace.update_palette(editor.workspace.palette | "#fe12ab")
	for(var/direction in GLOB.cardinals)
		var/icon/guide = editor.guide_icons["[direction]"]
		TEST_ASSERT(!guide.GetPixel(7, 31), "The extension fixture must be outside the original head and hair silhouette in direction [direction].")
		TEST_ASSERT(editor.workspace.new_transaction(list("type" = "pencil", "layer" = 1, "dir" = "[direction]", "color" = "#fe12abff", "points" = list(list(6, 1)))), "A bun above the original hair must be inside the editor's allowed drawing area.")
	editor.published_icons.Cut()
	editor.refresh_preview()
	var/index = 0
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = editor.published_icons[++index]
		TEST_ASSERT(rendered.GetPixel(7, 31) == "#fe12ab", "Artist previews must retain allowed custom hair outside the original silhouette in direction [direction].")
		var/body_pixels = 0
		for(var/y in 1 to 14)
			for(var/x in 1 to 32)
				if(rendered.GetPixel(x, y))
					body_pixels++
		TEST_ASSERT(body_pixels, "Artist previews must show the body being worked on in direction [direction].")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "The extension must be proposable: [error]")
	for(var/direction in GLOB.cardinals)
		var/icon/rendered = getFlatIcon(editor.preview_body, defdir = direction, no_anim = TRUE)
		rendered.Crop(1, 1, 32, 32)
		TEST_ASSERT(!(rendered.GetPixel(7, 31) != "#fe12ab" || session.mirror.after_urls["[direction]"] != "data:image/png;base64,[icon2base64(rendered)]"), "The recipient mirror must show the same native extension in direction [direction].")

/datum/unit_test/custom_sprite_salon/donor_gradient/Run()
	setup_players()
	recipient.set_hair_gradient_style("None", update = FALSE)
	recipient.set_hair_gradient_color("#000000", update = FALSE)
	var/list/original_hair = custom_style_live_hair_context(recipient)
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD)
	TEST_ASSERT(!(head.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "Fade Up" || recipient.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "None"), "The donor's gradient must differ from the recipient's retained hair settings.")
	custom_style_apply_hair_context(recipient, original_hair)
	TEST_ASSERT(!(head.get_hair_gradient_style(GRADIENT_HAIR_KEY) != "None" || head.get_hair_gradient_color(GRADIENT_HAIR_KEY) != "#000000"), "Applying a hair context must update the head even when the recipient's cached settings already match it.")

/datum/unit_test/custom_sprite_salon_native_hair_opacity/Run()
	for(var/species_id in list(SPECIES_ETHEREAL, SPECIES_SLIMESTART))
		var/datum/client_interface/mock_client = allocate(/datum/client_interface)
		var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
		// Species choices follow the roundstart config, which CI doesn't load, so pin the species directly.
		preferences.value_cache[/datum/preference/choiced/species] = GLOB.species_list[species_id]
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Short Hair")
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/hair_opacity], FALSE)
		var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
		preferences.apply_prefs_to(recipient, TRUE, visuals_only = TRUE)
		var/obj/item/bodypart/head/head = recipient.get_bodypart(BODY_ZONE_HEAD)
		TEST_ASSERT(!(recipient.hair_alpha || head.hair_alpha != (species_id == SPECIES_ETHEREAL ? 140 : 160)), "The fixture must have the species' native hair opacity without an override.")
		var/list/package = custom_sprite_live_package(recipient, "hair")
		TEST_ASSERT(isnull(package["hair"]["opacity"]), "Native [species_id] opacity must remain the default in a salon package, not become an unsupported override.")
		package["drawing"] = custom_sprite_test_drawing()
		var/error = preferences.commit_custom_style(package, preferences.default_slot)
		TEST_ASSERT(!error, "Saving custom hair with native [species_id] opacity must succeed: [error]")

/datum/unit_test/custom_sprite_salon/donor_opaque_hair/Run()
	setup_players()
	recipient.set_species(/datum/species/ethereal)
	var/obj/item/bodypart/head/head = transplant_donor(BODY_ZONE_HEAD, 255)
	TEST_ASSERT(!(recipient.hair_alpha || recipient.dna.species.hair_alpha != 140 || head.hair_alpha != 255), "The donor head must have opaque hair on a body whose native hair is translucent.")
	var/list/package = custom_sprite_live_package(recipient, "hair")
	var/list/parsed = custom_style_parse(custom_style_export_text(package))
	TEST_ASSERT(!(package["hair"]["opacity"] != 255 || parsed["error"] || parsed["package"]["hair"]["opacity"] != 255), "A donor's opaque hair must remain explicitly opaque in live and exported packages.")
	custom_sprite_apply_round_style(recipient, package)
	TEST_ASSERT(head.hair_alpha == 255, "Applying a salon package must not make opaque donor hair translucent.")

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
	var/list/applied = list()
	applied[custom_style_key("markings", BODY_ZONE_L_ARM)] = package
	var/datum/custom_sprite_mirror/mirror = new(null, recipient, applied, preferences.default_slot)
	var/datum/tgui/ui = new(recipient, mirror, "CustomSpriteMirror")
	mirror.ui_act("export", list(), ui)
	TEST_ASSERT(!mirror.save_message, "The completed result must not offer a second export: [mirror.save_message]")
	qdel(ui)
	TEST_ASSERT(!(!mirror.save_style(recipient) || custom_sprite_hash(preferences.custom_limb_markings?[BODY_ZONE_L_ARM]) != custom_sprite_hash(package["drawing"])), "The recipient must be able to save an applied style: [mirror.save_message]")
	TEST_ASSERT(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM), "A salon save must keep the replaced style as previous.")
	// Character setup's whole-body editor holds a draft of every region, so any markings save waits for it.
	var/datum/custom_sprite_editor/markings/unified_test/setup_editor = new(preferences, BODY_ZONE_R_LEG)
	LAZYSET(preferences.custom_sprite_editors, "markings", setup_editor)
	TEST_ASSERT(!(mirror.save_style(recipient) || !findtext(mirror.save_message, "Close the matching custom editor")), "A salon markings save must wait while the whole-body editor is open in character setup.")
	setup_editor.finish(FALSE)
	// Admin-spawned bodies record no slot, but they are still this player's character.
	recipient.mind.original_character_slot_index = null
	custom_sprite_apply_round_style(recipient, package)
	TEST_ASSERT(mirror.save_style(recipient), "A character spawned without a recorded slot must still be able to save: [mirror.save_message]")
	recipient.mind.original_character_slot_index = preferences.default_slot + 1
	TEST_ASSERT(!(mirror.save_style(recipient) || mirror.save_state != "error"), "Saves must stay bound to the slot the character spawned with.")
	TEST_ASSERT(!findtext(LOWER_TEXT(mirror.save_message), "export"), "The completed result must not direct players to an export action it no longer offers.")
	recipient.mind.original_character_slot_index = preferences.default_slot
	mirror.slot = preferences.default_slot
	recipient.real_name = "Someone Else Entirely"
	TEST_ASSERT(!mirror.save_style(recipient), "Saves must reject a slot belonging to another character.")
	qdel(mirror)
	recipient.ckey = null

/datum/unit_test/custom_sprite_salon_recipient_save/Destroy()
	GLOB.preferences_datums -= "salontestsaver"
	return ..()

/datum/unit_test/custom_sprite_salon/taur/Run()
	setup_players()
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(recipient)
	TEST_ASSERT(organ, "The salon fixture needs a real taur organ.")
	TEST_ASSERT(!custom_sprite_salon_target_problem(recipient, "markings", "taur"), "An exposed taur organ must be a supported tattoo target.")
	TEST_ASSERT(custom_sprite_salon_target_problem(recipient, "markings", BODY_ZONE_L_LEG), "Hidden taur leg slots must remain unsupported tattoo targets.")
	var/icon/silhouette = custom_sprite_body_silhouette(recipient, CUSTOM_MARKING_ZONE_TAUR, CUSTOM_SPRITE_TAUR_WIDTH)
	TEST_ASSERT(!(silhouette.Width() != 64 || silhouette.Height() != 32), "The taur drawing geometry must retain the entire 64-pixel lower body.")
	recipient.dna.custom_limb_markings = list("taur" = custom_sprite_test_wide_drawing(repeat_string(64, "2")))
	recipient.sync_custom_sprite_appearance(refresh_body = TRUE)
	var/obj/item/bodypart/chest = recipient.get_bodypart(BODY_ZONE_CHEST)
	chest.apply_custom_marking(custom_sprite_test_wide_drawing(), /datum/bodypart_overlay/custom_marking/taur/zone)
	var/list/current = custom_sprite_live_package(recipient, "markings", "taur")
	TEST_ASSERT(!(!current?["drawing"] || current["drawing"]["version"] != 3 || custom_sprite_hash(current["drawing"]) == custom_sprite_hash(custom_sprite_validate(recipient.dna.custom_limb_markings["taur"]))), "Live taur capture must read its independent chest overlay snapshot.")
	var/mob/living/carbon/human/dummy/preview = custom_sprite_salon_dummy(recipient)
	allocated += preview
	TEST_ASSERT(!(!preview.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR) || custom_style_package_hash(custom_sprite_live_package(preview, "markings", "taur")) != custom_style_package_hash(current)), "Salon dummies must preserve the actual taur organ and its independent paint snapshot.")
	if(current?["drawing"])
		custom_sprite_apply_round_style(recipient, custom_style_package("markings", "taur", null, null), FALSE)
		TEST_ASSERT(!custom_sprite_live_package(recipient, "markings", "taur")?["drawing"], "Clearing a salon taur tattoo must remove its paint.")
		custom_sprite_apply_round_style(recipient, current, FALSE)
		TEST_ASSERT(custom_sprite_hash(custom_sprite_live_package(recipient, "markings", "taur")?["drawing"]) == custom_sprite_hash(custom_sprite_appearance_drawing(current["drawing"], FALSE)), "Salon application must restore the independent taur paint snapshot.")
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	TEST_ASSERT(!(canvas.workspace.width != CUSTOM_SPRITE_TAUR_WIDTH || !(CUSTOM_MARKING_ZONE_TAUR in canvas.region_zones) || (BODY_ZONE_L_LEG in canvas.region_zones)), "A taur's tattoo canvas must be wide, with a taur region and no leg regions.")
	TEST_ASSERT(paint_region(session, CUSTOM_MARKING_ZONE_TAUR), "The taur region must be paintable.")
	TEST_ASSERT(!session.participant_problem(), "Taur consent must bind to the existing chest and external organ: [session.participant_problem()]")
	var/obj/item/organ/taur_body/replacement = allocate(organ.type)
	var/datum/bodypart_overlay/mutant/taur_body/replacement_overlay = replacement.bodypart_overlay
	replacement_overlay.set_appearance_from_name("Cow (Spotted)")
	replacement_overlay.imprint_on_next_insertion = FALSE
	allocated += organ
	replacement.Insert(recipient, special = TRUE)
	TEST_ASSERT(findtext(session.participant_problem(), "replaced"), "Replacing the taur organ while retaining the chest must invalidate a tattoo that changes it.")


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
	var/list/hand_bounds = custom_sprite_icon_bounds(custom_sprite_silhouette(arm, TRUE), SOUTH)
	TEST_ASSERT(!(!hand_only || !hand_bounds || !custom_sprite_test_mask_count(hand_mask) || custom_sprite_test_mask_count(hand_mask) >= custom_sprite_test_mask_count(arm_mask)), "A hand zone must paint a smaller part of its arm.")
	TEST_ASSERT(!(custom_sprite_test_mask_top(hand_mask) < hand_bounds[2] - 3 || custom_sprite_test_mask_top(arm_mask) >= custom_sprite_test_mask_top(hand_mask)), "Hand paint may only reach a few rows above the hand.")
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			TEST_ASSERT(!(copytext(hand_mask[y], x, x + 1) == "1" && copytext(arm_mask[y], x, x + 1) != "1"), "A hand zone must stay within its arm's silhouette.")
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
	TEST_ASSERT(!(hand_overlays != 1 || zone_overlays != 1), "Hand and arm paint must be independent overlays on the arm.")
	TEST_ASSERT(!(custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_PRECISE_L_HAND)) != custom_style_package_hash(custom_sprite_live_package_from(hand_package, recipient)) || custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_L_ARM)) != custom_style_package_hash(custom_sprite_live_package_from(arm_package, recipient))), "Live hand and arm styles must read back their own drawings.")
	TEST_ASSERT(!custom_sprite_salon_target_problem(recipient, "markings", BODY_ZONE_PRECISE_L_HAND), "A bare hand must be tattooable.")
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	TEST_ASSERT(!(!custom_sprite_zone_covered(recipient, BODY_ZONE_PRECISE_L_HAND) || custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM)), "Gloves must cover hands without covering arms.")
	TEST_ASSERT(findtext(custom_sprite_salon_target_problem(recipient, "markings", BODY_ZONE_PRECISE_L_HAND), "covered"), "Tattooing a gloved hand must be refused.")
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	TEST_ASSERT(!(!custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM) || !custom_sprite_zone_covered(recipient, BODY_ZONE_CHEST)), "A jumpsuit must cover the arms and torso.")
	TEST_ASSERT(uniform.can_adjust && !uniform.alt_covers_chest, "The fixture jumpsuit must roll down to bare the torso and arms.")
	uniform.toggle_jumpsuit_adjust()
	TEST_ASSERT(!(custom_sprite_zone_covered(recipient, BODY_ZONE_L_ARM) || custom_sprite_salon_target_problem(recipient, "markings", BODY_ZONE_L_ARM)), "Rolled-up sleeves must expose the arms for tattooing.")


/datum/unit_test/custom_sprite_salon/locked_paint/Run()
	setup_players()
	var/obj/item/bodypart/chest = artist.get_bodypart(BODY_ZONE_CHEST)
	var/icon/silhouette = custom_sprite_silhouette(chest)
	var/list/point
	for(var/y in 0 to 31)
		for(var/x in 0 to 31)
			if(silhouette.GetPixel(x + 1, 32 - y, "", NORTH))
				point = list(x, y)
	TEST_ASSERT(point, "The fixture needs a back-facing chest pixel.")
	var/list/drawing = custom_sprite_reopen_test_drawing(point[1], point[2], "#ffffff")
	drawing["dirs"]["1"] = drawing["dirs"]["2"]
	drawing["dirs"] -= "2"
	custom_sprite_apply_round_style(artist, custom_style_package("markings", BODY_ZONE_CHEST, drawing, null))
	var/datum/custom_sprite_salon/test/session = new(machine, artist, artist, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/start = session.original[custom_style_key("markings", BODY_ZONE_CHEST)]
	var/list/start_package = start["package"]
	var/original_hash = custom_sprite_hash(start_package["drawing"])
	for(var/rebuild in 1 to 2)
		var/list/results = canvas.region_results()
		var/list/chest_result = results[BODY_ZONE_CHEST]
		TEST_ASSERT(!(chest_result["changed"] || custom_sprite_hash(chest_result["drawing"]) != original_hash), "Opening or rebuilding a mirror-locked view must preserve its existing tattoo.")
		TEST_ASSERT(!canvas.workspace.is_point_allowed(point[1], point[2], "1"), "Preserving locked paint must not make the back view editable.")
		canvas.rebuild_resources()

/datum/unit_test/custom_sprite_salon/marking_ownership/Run()
	setup_players()
	var/previous_preferences = GLOB.preferences_datums[artist.ckey]
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, artist.mock_client)
	GLOB.preferences_datums[artist.ckey] = preferences
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/before = json_encode(preferences.body_markings)
	var/name = GLOB.body_markings_per_limb[BODY_ZONE_CHEST][1]
	var/recipient_before = json_encode(recipient.dna.body_markings)
	TEST_ASSERT(canvas.write_region_marking(BODY_ZONE_CHEST, null, name, "#112233"), "The tattoo canvas must offer the torso's native markings as part of its draft.")
	TEST_ASSERT(json_encode(preferences.body_markings) == before, "Salon base-marking actions must leave the artist's preferences untouched.")
	TEST_ASSERT(json_encode(recipient.dna.body_markings) == recipient_before, "Changing a tattoo preset must not change the recipient before approval.")
	canvas.workspace.undo()
	TEST_ASSERT(!length(canvas.workspace.markings_context[BODY_ZONE_CHEST]), "Undo must remove the draft's new tattoo preset.")
	canvas.workspace.redo()
	canvas.rebuild_resources()
	var/list/chest_markings = canvas.workspace.markings_context[BODY_ZONE_CHEST]
	var/list/entry = chest_markings[1]
	// Emission set behind the window's back: results are cached by history position, so drop them.
	entry["emissive"] = TRUE
	canvas.results_cache = null
	TEST_ASSERT(findtext(session.propose(artist), "emissive appearance disabled"), "Disallowed native emission must be rejected before approval, not after applying.")
	entry["emissive"] = FALSE
	canvas.results_cache = null
	var/problem = session.propose(artist)
	TEST_ASSERT(!problem, "A native-marking-only change must be reviewable: [problem]")
	var/token = session.proposal["token"]
	canvas.write_region_marking(BODY_ZONE_CHEST, 1, name, "#445566")
	TEST_ASSERT(!(session.proposal || session.accept(recipient, token)), "Changing base markings must withdraw an existing approval.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	session.accept(recipient, token)
	session.complete_application(token)
	TEST_ASSERT(recipient.dna.body_markings?[BODY_ZONE_CHEST]?[name]?[MARKING_INDEX_COLOR] == "#445566", "Approved tattoo presets must apply to the recipient's torso.")
	GLOB.preferences_datums[artist.ckey] = previous_preferences

/datum/unit_test/custom_sprite_salon/hair_controls/Run()
	setup_players()
	for(var/target in GLOB.custom_style_hair_targets)
		var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, target)
		var/datum/custom_sprite_editor/salon/editor = session.editor
		TEST_ASSERT(!(!editor.can_change_hair() || editor.can_hide_parts()), "The salon must offer base hair without Hide Parts for [target].")
		var/list/hair = editor.workspace.hair_context.Copy()
		for(var/style in editor.available_hairstyles())
			var/datum/sprite_accessory/accessory = custom_style_hair_accessories(target)[style]
			if(style != hair["style"] && !accessory.locked)
				hair["style"] = style
				break
		var/before = custom_style_package_hash(custom_sprite_live_package(recipient, target))
		var/revision = editor.draft_revision
		TEST_ASSERT(!(!editor.apply_hair_context(hair, "Change hairstyle") || editor.draft_revision == revision), "Changing the salon's base hair must update the draft revision.")
		TEST_ASSERT(custom_style_package_hash(custom_sprite_live_package(recipient, target)) == before, "The recipient's live base hair must wait for approval.")
		var/problem = session.propose(artist)
		TEST_ASSERT(!problem, "A base-hair-only change must be reviewable: [problem]")
		var/token = session.proposal["token"]
		session.accept(recipient, token)
		session.complete_application(token)
		var/list/applied = custom_style_live_hair_context(recipient, target)
		TEST_ASSERT(applied["style"] == hair["style"], "Approved base hair must be applied to the recipient.")
		GLOB.custom_sprite_salon_cooldowns.Cut()

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
	TEST_ASSERT(session.dress_timer, "Changing an already-worn uniform must schedule a guide refresh.")
	deltimer(session.dress_timer)
	session.refresh_editor_body()
	TEST_ASSERT(session.editor.preview_body == body, "A clothing-only refresh must reuse the preview body.")
	TEST_ASSERT(!custom_sprite_test_same_pixels(before, session.editor.guide_icons["2"]), "The refreshed guide must show the adjusted uniform.")
	TEST_ASSERT(custom_sprite_hash(session.editor.workspace.serialize_drawing()) == paint_before, "Clothing changes must preserve the drawing.")
	// Unlike worn items, underwear is also part of the dummy's copied appearance.
	recipient.set_all_underwear_visibility(TRUE)
	TEST_ASSERT(session.dress_timer, "Underwear visibility changes must schedule a preview refresh.")
	deltimer(session.dress_timer)
	session.refresh_editor_body()
	TEST_ASSERT(session.editor.preview_body.underwear_visibility == recipient.underwear_visibility, "A preview must discard its old underwear visibility after the recipient changes it.")
	session.editor.ui_close(artist)
	uniform.rolldown()
	TEST_ASSERT(!session.dress_timer, "Closed drafts must not schedule preview work.")

/datum/unit_test/custom_sprite_salon/self_styling/Run()
	setup_players()
	TEST_ASSERT(!custom_sprite_salon_start_problem(scissors, artist, artist, "hair"), "Cutting your own hair must be allowed: [custom_sprite_salon_start_problem(scissors, artist, artist, "hair")]")
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, artist, "hair", null)
	TEST_ASSERT(!(!session.self_work || !session.editor.can_change_hair()), "Self-styling must own the session and allow a new haircut.")
	TEST_ASSERT(json_encode(session.locked_directions()) == json_encode(list("1")), "Without a mirror, the back view must be locked.")
	var/list/bounds = session.editor.workspace.draw_bounds["1"]
	TEST_ASSERT(!(bounds[3] >= bounds[1] || session.editor.workspace.is_point_allowed(16, 10, "1")), "A locked view must have no paintable pixels.")
	TEST_ASSERT(paint(session), "The front view must stay paintable without a mirror.")
	var/list/package = session.editor.current_package()
	TEST_ASSERT(!session.locked_view_problem(list("hair" = package)), "Painting only the front must pass the mirror check.")
	var/list/back_painted = deep_copy_list(package)
	back_painted["drawing"] = custom_sprite_test_drawing()
	TEST_ASSERT(findtext(session.locked_view_problem(list("hair" = back_painted)), "mirror"), "Changing a locked view must need a mirror.")
	var/obj/item/hhmirror/mirror = allocate(/obj/item/hhmirror)
	artist.dropItemToGround(machine)
	TEST_ASSERT(artist.put_in_inactive_hand(mirror), "The fixture must be able to hold the mirror.")
	// Picking the mirror up must free the view without reopening the editor.
	var/list/back_stroke = list("type" = "pencil", "layer" = 1, "dir" = "1", "color" = "[session.editor.workspace.palette[1]]ff", "points" = list(list(16, 10)))
	TEST_ASSERT(!(session.locked_directions() || session.locked_view_problem(list("hair" = back_painted)) || !session.editor.workspace.new_transaction(deep_copy_list(back_stroke))), "A held hand mirror must unlock the back view at once.")
	artist.dropItemToGround(mirror)
	TEST_ASSERT(!(!session.locked_directions() || session.editor.workspace.new_transaction(deep_copy_list(back_stroke))), "Dropping the mirror must lock the back view again at once.")
	artist.put_in_inactive_hand(mirror)
	bounds = session.editor.workspace.draw_bounds["1"]
	TEST_ASSERT(bounds[3] >= bounds[1], "Picking up a mirror must immediately unlock the UI bounds before another editor action.")
	TEST_ASSERT(session.editor.workspace.new_transaction(deep_copy_list(back_stroke)), "Holding the mirror again must unlock the back view.")
	artist.dropItemToGround(mirror)
	var/obj/structure/mirror/wall_mirror = allocate(/obj/structure/mirror, locate(run_loc_floor_bottom_left.x + 1, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!(session.locked_directions() || !session.editor.workspace.new_transaction(deep_copy_list(back_stroke))), "Standing next to a wall mirror must unlock the back view.")
	qdel(wall_mirror)
	TEST_ASSERT(session.locked_directions(), "Losing the mirror must lock the back view again.")
	// The back view was painted with a mirror at hand; keep one so the work can still be finished.
	artist.put_in_inactive_hand(mirror)
	// Self work applies without a consent step.
	var/error = session.propose(artist)
	TEST_ASSERT(!(error || session.state != "applying"), "Finishing your own work must start applying at once: [error]")
	TEST_ASSERT(!session.mirror, "Self work must not open an approval mirror.")
	TEST_ASSERT(session.complete_application(session.proposal["token"]), "Self work must apply.")
	TEST_ASSERT(!length(session.awards), "Styling yourself must not award achievements.")
	TEST_ASSERT(artist.dna.custom_hair, "Self work must apply its drawing.")
	// A haircut may change the style and color, but not the rest of the look.
	var/datum/custom_sprite_salon/test/haircut = new(scissors, artist, artist, "hair", null)
	var/list/restyle = haircut.editor.workspace.hair_context.Copy()
	restyle["style"] = /datum/sprite_accessory/hair/bedhead::name
	TEST_ASSERT(haircut.editor.apply_hair_context(restyle, "Change hairstyle"), "Self-styling must be able to change the hairstyle: [haircut.editor.transfer_error]")
	var/list/glowing = haircut.editor.workspace.hair_context.Copy()
	glowing["emissive"] = TRUE
	TEST_ASSERT(!(haircut.editor.apply_hair_context(glowing, "Change hair") || !haircut.editor.transfer_error), "A haircut must not change hair glow or opacity.")
	qdel(haircut)


/datum/unit_test/custom_sprite_salon/self_hair_guide/Run()
	setup_players()
	artist.set_hairstyle("Short Hair", update = TRUE)
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, artist, "hair", null)
	var/datum/sprite_accessory/hair/current = SSaccessories.hairstyles_list[session.editor.workspace.hair_context["style"]]
	var/list/current_bounds = custom_sprite_icon_bounds(icon(current.icon, current.icon_state), SOUTH)
	var/longer
	for(var/name, candidate_untyped in SSaccessories.hairstyles_list)
		var/datum/sprite_accessory/hair/candidate = candidate_untyped
		if(!candidate?.icon_state || candidate.locked)
			continue
		var/list/bounds = custom_sprite_icon_bounds(icon(candidate.icon, candidate.icon_state), SOUTH)
		if(bounds && current_bounds && bounds[4] > current_bounds[4] + 2)
			longer = name
			break
	TEST_ASSERT(longer, "The fixture needs a hairstyle that reaches further than the current one.")
	var/icon/before = icon(session.editor.guide_icons["2"])
	var/list/restyle = session.editor.workspace.hair_context.Copy()
	restyle["style"] = longer
	TEST_ASSERT(session.editor.apply_hair_context(restyle, "Change hairstyle"), "Changing the hairstyle failed: [session.editor.transfer_error]")
	// The guide is drawn from the drafted look, not the one the session started with.
	TEST_ASSERT(!custom_sprite_test_same_pixels(before, session.editor.guide_icons["2"]), "A new haircut must change the guide.")
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	artist.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	var/icon/dressed = icon(session.editor.guide_icons["2"])
	session.editor.rebuild_resources()
	TEST_ASSERT(!custom_sprite_test_same_pixels(dressed, session.editor.guide_icons["2"]), "Guides must show the clothes the recipient is wearing.")


/datum/unit_test/custom_sprite_salon/separate_drafts/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/haircut = new(scissors, artist, recipient, "hair")
	var/datum/custom_sprite_salon/test/tattoo = new(machine, artist, recipient, "markings")
	TEST_ASSERT(!(custom_sprite_salon_session(artist.ckey, "hair", recipient.ckey) != haircut || custom_sprite_salon_session(artist.ckey, "markings", recipient.ckey) != tattoo), "Hair and the whole-body tattoo must keep separate drafts.")
	TEST_ASSERT(length(custom_sprite_salon_sessions_for(artist.ckey)) == 2, "An artist may hold a draft per drawing target.")
	TEST_ASSERT(!(length(custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)[1] != haircut), "Scissors must resume hair work, not tattoo work.")
	TEST_ASSERT(!(length(custom_sprite_salon_sessions_for_tool(artist.ckey, machine)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, machine)[1] != tattoo), "A tattoo machine must resume tattoo work, not hair work.")
	qdel(haircut)
	TEST_ASSERT(!(custom_sprite_salon_session(artist.ckey, "hair", recipient.ckey) || custom_sprite_salon_session(artist.ckey, "markings", recipient.ckey) != tattoo), "Discarding one draft must leave the others alone.")
	var/datum/custom_sprite_salon/test/facial = new(scissors, artist, recipient, "facial_hair")
	TEST_ASSERT(!(length(custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)) != 1 || custom_sprite_salon_sessions_for_tool(artist.ckey, scissors)[1] != facial), "Hair and facial hair must be separate drafts.")
	// Each person worked on keeps their own draft, so tattooing one never discards another's.
	var/datum/custom_sprite_salon/test/own = new(machine, artist, artist, "markings")
	TEST_ASSERT(!(custom_sprite_salon_session(artist.ckey, "markings", recipient.ckey) != tattoo || custom_sprite_salon_session(artist.ckey, "markings", artist.ckey) != own), "Tattoo drafts for two people must be kept apart.")
	TEST_ASSERT(length(custom_sprite_salon_sessions_for_tool(artist.ckey, machine)) == 2, "The tattoo machine must offer both tattoo drafts.")
	qdel(own)
	TEST_ASSERT(custom_sprite_salon_session(artist.ckey, "markings", recipient.ckey) == tattoo, "Discarding one person's draft must keep the other's.")

/datum/unit_test/custom_sprite_salon/tattoo_geometry/Run()
	setup_players()
	var/obj/item/bodypart/limb = recipient.get_bodypart(BODY_ZONE_L_ARM)
	// Same bodypart type, but a different sprite selected through character customization.
	limb.change_appearance(BODYPART_ICON_HUMANOID, SPECIES_HUMANOID, TRUE, FALSE)
	var/list/zones = custom_sprite_present_regions(recipient)
	var/list/expected = custom_sprite_region_map(recipient, zones, 32)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	TEST_ASSERT(!(json_encode(canvas.region_zones) != json_encode(zones) || json_encode(canvas.region_map) != json_encode(expected)), "The tattoo canvas must map the recipient's own regions, customized limbs included.")
	var/obj/item/bodypart/preview_limb = canvas.preview_body.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(!(preview_limb.custom_sprite_icon_file() != limb.custom_sprite_icon_file() || preview_limb.limb_id != limb.limb_id), "Salon previews must preserve custom limb sprite files and state IDs.")
	var/index = "[canvas.region_zones.Find(BODY_ZONE_L_ARM)]"
	for(var/direction in GLOB.cardinals)
		var/list/rows = expected["[direction]"]
		for(var/y in 0 to 31)
			for(var/x in 0 to 31)
				TEST_ASSERT(!(copytext(rows[y + 1], x + 1, x + 2) == index && !canvas.workspace.is_point_allowed(x, y, "[direction]")), "Every left arm pixel must be paintable in direction [direction].")

/datum/unit_test/custom_sprite_salon/tattoo_hair_layer/Run()
	setup_players()
	// A style long enough to hang over the chest.
	var/long_style
	var/lowest = 0
	for(var/name, candidate_untyped in SSaccessories.hairstyles_list)
		var/datum/sprite_accessory/hair/candidate = candidate_untyped
		if(!candidate?.icon_state || candidate.locked)
			continue
		var/list/extent = custom_sprite_icon_bounds(icon(candidate.icon, candidate.icon_state), SOUTH)
		if(extent && extent[4] > lowest)
			lowest = extent[4]
			long_style = name
	recipient.set_hairstyle(long_style, update = TRUE)
	var/obj/item/organ/wings/moth/wings = new
	wings.Insert(recipient, special = TRUE)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/editor = session.editor
	TEST_ASSERT(length(editor.preview_body.overlays_standing[HAIR_LAYER]), "The fixture must have hair to leave out of the guide.")
	TEST_ASSERT(!(!editor.can_hide_parts() || !editor.hide_parts), "Tattoo guides must keep hair and parts out of the way by default.")
	TEST_ASSERT(!editor.can_hide_underwear(), "Tattoo guides must show the recipient as they're dressed, underwear included.")
	// Only the guide leaves parts out; the preview body keeps them once the guides are drawn.
	var/obj/item/bodypart/wings_limb
	var/datum/bodypart_overlay/mutant/wings/wings_overlay
	for(var/obj/item/bodypart/limb as anything in editor.preview_body.bodyparts)
		wings_overlay = locate() in limb.bodypart_overlays
		if(wings_overlay)
			wings_limb = limb
			break
	TEST_ASSERT(wings_overlay, "Hiding parts from the guide must leave the wings on the preview body.")
	TEST_ASSERT(json_encode(custom_sprite_render_directions(editor.preview_body, worn_overlays = editor.render_overlays())) == json_encode(editor.preview_urls), "Hiding parts from the guide must leave hair and wings on the preview.")
	// Hidden means gone from the whole canvas: hair hanging beside the body counts too.
	var/icon/hidden = editor.guide_icons["2"]
	// Build the comparison through the mob itself, not the helpers this is checking.
	wings_limb.remove_bodypart_overlay(wings_overlay)
	var/list/hair = editor.preview_body.overlays_standing[HAIR_LAYER]
	editor.preview_body.remove_overlay(HAIR_LAYER)
	var/icon/bare = custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)
	editor.preview_body.overlays_standing[HAIR_LAYER] = hair
	editor.preview_body.apply_overlay(HAIR_LAYER)
	wings_limb.add_bodypart_overlay(wings_overlay)
	var/icon/whole = custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)
	TEST_ASSERT(!custom_sprite_test_same_pixels(bare, whole), "The fixture's hair and wings must be visible on the body it's drawn on.")
	// Guides are built while other renders read the same body, so hiding hair must not touch it.
	custom_sprite_limb_appearance(editor.preview_body)
	TEST_ASSERT(custom_sprite_test_same_pixels(whole, custom_sprite_flat_icon(editor.preview_body, SOUTH, editor.workspace.width)), "Hiding hair must leave the body it was taken from alone.")
	for(var/y in 1 to 32)
		for(var/x in 1 to 32)
			TEST_ASSERT(hidden.GetPixel(x, y) == bare.GetPixel(x, y), "Hidden hair and parts must leave the guide alone at [x],[y].")
	editor.hide_parts = FALSE
	editor.rebuild_resources()
	TEST_ASSERT(!custom_sprite_test_same_pixels(hidden, editor.guide_icons["2"]), "Putting hair and parts back on must change the guide.")

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
		var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
		paint_region(session, BODY_ZONE_L_ARM)
		session.propose(artist)
		var/datum/custom_sprite_mirror/mirror = session.mirror
		var/list/static_data = mirror.ui_static_data(recipient)
		var/list/data = mirror.ui_data(recipient)
		TEST_ASSERT(!(length(static_data["before"]) != 4 || length(static_data["after"]) != 4 || data["before"] || data["after"] || data["timeout"] <= 0), "Mirror images must be static while the small timeout payload updates.")
		var/list/prior = preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)
		var/old_hash = custom_style_package_hash(prior)
		var/token = session.proposal["token"]
		var/datum/tgui/ui = new(recipient, mirror, "CustomSpriteMirror")
		mirror.ui_act("export", list("token" = "stale"), ui)
		TEST_ASSERT(!(mirror.save_message || session.state != "awaiting approval"), "A stale export must do nothing.")
		mirror.ui_act("export", list("token" = token), ui)
		// The mock recipient has no real client to download to; reaching the exporter reports that.
		TEST_ASSERT(!(mirror.save_message != "You need to be connected to export." || session.state != "awaiting approval" || custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)) != old_hash), "Export must be available before acceptance without applying or saving the proposal.")
		mirror.ui_act(permanent ? "acceptPermanent" : "accept", list("token" = token), ui)
		qdel(ui)
		TEST_ASSERT(!(session.state != "applying" || session.save_on_completion != permanent), "The recipient's acceptance choice must bind to the reviewed proposal.")
		TEST_ASSERT(custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM)) == old_hash, "Approval must not save before application completes.")
		var/list/applied = session.proposal["packages"][custom_style_key("markings", BODY_ZONE_L_ARM)]
		TEST_ASSERT(session.complete_application(token), "Valid reviewed work must still apply.")
		var/saved_hash = custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_L_ARM))
		TEST_ASSERT(saved_hash == (permanent ? custom_style_package_hash(applied) : old_hash), "Only permanent acceptance may save the applied proposal.")
		TEST_ASSERT(!(permanent && custom_style_package_hash(preferences.custom_style_previous_package("markings", BODY_ZONE_L_ARM)) != old_hash), "Permanent acceptance must keep the replaced saved style.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	paint(session)
	session.propose(artist)
	var/token = session.proposal["token"]
	session.accept(recipient, token, save_permanently = TRUE)
	TEST_ASSERT(!(session.complete_application(token, finished = FALSE) || session.save_on_completion || session.state != "drafting"), "Interrupted work must discard permanent-save authorization and retain the draft.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	session.propose(artist)
	token = session.proposal["token"]
	session.mirror.expires_at = world.time
	TEST_ASSERT(!(session.accept(recipient, token, save_permanently = TRUE) || session.state != "drafting" || session.save_on_completion), "A late approval must fail even before the expiry timer runs.")
	GLOB.preferences_datums -= recipient.ckey

/datum/unit_test/custom_sprite_salon/editor_sounds/Run()
	setup_players()
	for(var/target in list("hair", "markings"))
		var/tattoo = target == "markings"
		var/datum/custom_sprite_salon/test/session = new(tattoo ? machine : scissors, artist, recipient, target)
		var/datum/custom_sprite_editor/editor = session.editor
		var/channels_before = length(SSsounds.reserved_channels)
		// Register the open UI without needing a DreamSeeker window in a native test.
		var/datum/tgui/ui = new(artist, editor, "CustomHairEditor")
		editor.open_uis = list(ui)
		editor.ui_interact(artist, ui)
		TEST_ASSERT(!(session.drawing_sound || session.drawing_ambience), "An idle open editor must stay silent.")
		for(var/list/invalid as anything in list(list("dir" = "2", "x" = -1, "y" = 0, "erasing" = TRUE), list("dir" = "2", "x" = 9999, "y" = 0, "erasing" = TRUE), list("dir" = "invalid", "x" = 1, "y" = 1), list("dir" = "2", "x" = "text", "y" = 1)))
			editor.ui_act("drawing", invalid, ui)
		TEST_ASSERT(!(session.drawing_sound || session.drawing_ambience), "Malformed or off-canvas activity must not start sounds.")
		var/list/activity
		for(var/y in 0 to editor.workspace.height - 1)
			for(var/x in 0 to editor.workspace.width - 1)
				if(editor.workspace.is_point_allowed(x, y, "2"))
					activity = list("dir" = "2", "x" = x, "y" = y)
					break
			if(activity)
				break
		var/revision = editor.draft_revision
		TEST_ASSERT(!(editor.ui_act("drawing", activity, ui) || editor.draft_revision != revision), "Brush activity must not change pixels or request a UI update.")
		var/datum/looping_sound/sound = session.drawing_sound
		TEST_ASSERT(!(!sound?.is_active() || sound.parent != artist || length(SSsounds.reserved_channels) != channels_before + (tattoo ? 2 : 1)), "The first brush movement must immediately start sounds on the artist.")
		TEST_ASSERT(!(tattoo && (!sound.vary || !session.drawing_ambience?.native_repeat_active)), "Tattooing needs varied needle bursts and steady native-looped ambience.")
		var/sound_timer = sound.timer_id
		editor.ui_act("drawing", activity, ui)
		TEST_ASSERT(!(session.drawing_sound != sound || sound.timer_id != sound_timer), "Drawing during the cooldown must not restart or duplicate the clip.")
		TEST_ASSERT(!(!istype(sound, /datum/looping_sound/salon_snipping/drawing) || sound.mid_length_vary || sound.mid_length != (tattoo ? 12 SECONDS : 5 SECONDS)), "Brush clips must play once with a fixed five/twelve-second cooldown.")
		artist.forceMove(get_step(artist, NORTH))
		TEST_ASSERT(sound.is_active(), "Drawing sounds must survive movement while the editor stays open.")
		if(tattoo)
			sleep(2 SECONDS)
			editor.ui_act("drawing", activity, ui)
			sleep(2 SECONDS)
			TEST_ASSERT(session.drawing_ambience?.is_active(), "Continued drawing must extend the ambience tail.")
			sleep(2 SECONDS)
			TEST_ASSERT(!session.drawing_ambience, "Tattoo ambience must stop after drawing has been idle for three seconds.")
		else
			sleep(6 SECONDS)
			TEST_ASSERT(!sound.is_active(), "A snip must not loop while the drawing is idle.")
		// Advance only the cooldown, avoiding a twelve-second sleep for a repeated clip.
		session.drawing_sound_cooldown = 0
		editor.ui_act("drawing", activity, ui)
		TEST_ASSERT(!(!sound.is_active() || sound.timer_id == sound_timer), "The next brush movement after cooldown must start another clip.")
		editor.ui_close(artist)
		TEST_ASSERT(!(!QDELETED(sound) || session.drawing_sound || session.drawing_ambience || length(SSsounds.reserved_channels) != channels_before), "Closing the editor must silence and release both sound channels.")
		editor.ui_interact(artist, ui)
		TEST_ASSERT(!(session.drawing_sound || session.drawing_ambience), "Reopening a retained draft must stay silent until drawing resumes.")
		session.drawing_sound_cooldown = 0
		editor.ui_act("drawing", activity, ui)
		qdel(session)
		TEST_ASSERT(length(SSsounds.reserved_channels) == channels_before, "Discarding open work must release its sound channels.")
		artist.forceMove(run_loc_floor_bottom_left)

/// Only regions the draft changes are proposed, named in the mirror, applied and remembered.
/datum/unit_test/custom_sprite_salon/touched_regions/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	TEST_ASSERT(session.propose(artist) == "Nothing has changed yet.", "An untouched canvas must not be proposed.")
	var/list/before = custom_sprite_live_packages(recipient, "markings")
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/name = GLOB.body_markings_per_limb[BODY_ZONE_CHEST][1]
	TEST_ASSERT(canvas.write_region_marking(BODY_ZONE_CHEST, null, name, "#112233"), "The fixture must give the torso a base marking.")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "Touched regions must be proposable: [error]")
	var/arm_key = custom_style_key("markings", BODY_ZONE_L_ARM)
	var/chest_key = custom_style_key("markings", BODY_ZONE_CHEST)
	var/list/packages = session.proposal["packages"]
	TEST_ASSERT(!(length(packages) != 2 || !packages[arm_key] || !packages[chest_key]), "The proposal must carry exactly the touched regions: [json_encode(assoc_to_keys(packages))]")
	var/token = session.proposal["token"]
	TEST_ASSERT(!(!session.accept(recipient, token) || !session.complete_application(token)), "Approved touched regions must apply.")
	var/list/after = custom_sprite_live_packages(recipient, "markings")
	for(var/key, package in before)
		var/changed = custom_style_package_hash(package) != custom_style_package_hash(after[key])
		TEST_ASSERT(changed == (key in list(arm_key, chest_key)), "Only touched regions may change on the recipient: [key]")
	TEST_ASSERT(json_encode(sort_list(assoc_to_keys(recipient.custom_sprite_round_history))) == json_encode(sort_list(list(arm_key, chest_key))), "Each applied region must keep its own history entry.")
	TEST_ASSERT(length(session.awards) == 2, "One application awards the pair once, however many regions it changes.")

/// Only the regions a tattoo changes are checked and applied; the rest may change, or be covered, while it waits.
/datum/unit_test/custom_sprite_salon/untouched_changes/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	var/obj/item/bodypart/leg/right/new_leg = allocate(/obj/item/bodypart/leg/right)
	new_leg.replace_limb(recipient)
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "Covered or replaced regions the tattoo doesn't touch must not block it: [error]")
	// Someone else changes the leg while the recipient is still looking at the mirror.
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_R_LEG, custom_sprite_test_drawing(), null))
	var/leg_hash = custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_R_LEG))
	var/token = session.proposal["token"]
	TEST_ASSERT(!(!session.accept(recipient, token) || !session.complete_application(token)), "The touched arm must still apply after an untouched region changed.")
	TEST_ASSERT(custom_style_package_hash(custom_sprite_live_package(recipient, "markings", BODY_ZONE_R_LEG)) == leg_hash, "Applying must leave an untouched region's newer look alone.")
	// A second draft touches the hand, which the gloves then cover.
	recipient.dropItemToGround(gloves)
	var/datum/custom_sprite_salon/test/second = new(machine, artist, recipient, "markings")
	TEST_ASSERT(paint_region(second, BODY_ZONE_PRECISE_L_HAND), "The fixture must paint the left hand.")
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	TEST_ASSERT(findtext(second.propose(artist), "covered"), "A touched region under clothing must block finishing.")
	recipient.dropItemToGround(gloves)
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_PRECISE_L_HAND, custom_sprite_test_drawing(), null))
	TEST_ASSERT(findtext(second.propose(artist), "changed since work started"), "A touched region that changed on the body must block finishing.")

/// Counts multi-region commits, so a salon save can be shown to write once.
/datum/preferences/preferences_import_test/counting_commits
	/// commit_custom_styles() calls so far.
	var/commits = 0

/datum/preferences/preferences_import_test/counting_commits/commit_custom_styles(list/packages, slot, list/rotate_keys, reject_pending_hair = FALSE, reject_pending_markings = FALSE)
	commits++
	return ..()

/// Accepting permanently saves only the touched regions, in one write, rotating only their previous styles.
/datum/unit_test/custom_sprite_salon/permanent_regions/Run()
	setup_players()
	var/datum/client_interface/player = recipient.mock_client
	var/datum/preferences/preferences_import_test/counting_commits/preferences = allocate(/datum/preferences/preferences_import_test/counting_commits, player)
	player.prefs = preferences
	GLOB.preferences_datums[recipient.ckey] = preferences
	recipient.real_name = preferences.read_preference(/datum/preference/name/real_name)
	recipient.mind_initialize()
	recipient.mind.original_character_slot_index = preferences.default_slot
	var/list/leg = preferences.custom_style_saved_package("markings", BODY_ZONE_R_LEG)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	TEST_ASSERT(paint_region(session, BODY_ZONE_R_ARM), "The fixture must paint the right arm.")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "Two touched regions must be proposable: [error]")
	var/token = session.proposal["token"]
	session.accept(recipient, token, save_permanently = TRUE)
	TEST_ASSERT(session.complete_application(token), "The approved regions must apply.")
	TEST_ASSERT(preferences.commits == 1, "Saving permanently must write every touched region in one commit: [preferences.commits]")
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM))
		TEST_ASSERT(preferences.custom_limb_markings?[zone], "Saving permanently must save the touched [zone].")
		TEST_ASSERT(preferences.custom_style_previous_package("markings", zone), "Saving permanently must keep the replaced [zone] as its previous style.")
	TEST_ASSERT(custom_style_package_hash(preferences.custom_style_saved_package("markings", BODY_ZONE_R_LEG)) == custom_style_package_hash(leg), "Untouched regions must stay as saved.")
	TEST_ASSERT(!preferences.custom_style_previous_package("markings", BODY_ZONE_R_LEG), "Untouched regions must not rotate.")

/// Tattooing your own back needs a mirror, and the mirror is checked again when you finish.
/datum/unit_test/custom_sprite_salon/self_tattoo/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, artist, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/back_point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_CHEST, "1")
	TEST_ASSERT(!canvas.workspace.is_point_allowed(back_point[1], back_point[2], "1"), "Without a mirror, your own back is locked.")
	var/obj/item/hhmirror/mirror = allocate(/obj/item/hhmirror)
	artist.dropItemToGround(scissors)
	TEST_ASSERT(artist.put_in_active_hand(mirror), "The fixture must be able to hold the mirror.")
	TEST_ASSERT(paint_region(session, BODY_ZONE_CHEST, "1"), "A held mirror must unlock your back.")
	artist.dropItemToGround(mirror)
	TEST_ASSERT(findtext(session.propose(artist), "mirror"), "Finishing a change to your back without a mirror must be refused.")
	artist.put_in_active_hand(mirror)
	var/error = session.propose(artist)
	TEST_ASSERT(!(error || session.state != "applying" || session.mirror), "Your own tattoo applies without a consent mirror: [error]")
	// The mirror can be put down during the finishing touches.
	artist.dropItemToGround(mirror)
	TEST_ASSERT(!(session.complete_application(session.proposal["token"]) || session.state != "drafting" || !session.editor), "Putting the mirror down before your back is finished must stop the tattoo and keep the draft.")
	artist.put_in_active_hand(mirror)
	error = session.propose(artist)
	TEST_ASSERT(!error, "Picking the mirror up again must let you finish: [error]")
	TEST_ASSERT(session.complete_application(session.proposal["token"]), "Your own tattoo must apply.")
	TEST_ASSERT(!length(session.awards), "Tattooing yourself awards nothing.")

/// Restore previous offers the whole body or one region, and restores only what was chosen.
/datum/unit_test/custom_sprite_salon/restore_regions/Run()
	setup_players()
	var/arm_key = custom_style_key("markings", BODY_ZONE_L_ARM)
	var/leg_key = custom_style_key("markings", BODY_ZONE_R_LEG)
	var/list/before = custom_sprite_live_packages(recipient, "markings")
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	TEST_ASSERT(!(!paint_region(session, BODY_ZONE_L_ARM) || !paint_region(session, BODY_ZONE_R_LEG)), "The fixture must paint the left arm and right leg.")
	session.propose(artist)
	var/token = session.proposal["token"]
	session.accept(recipient, token)
	TEST_ASSERT(session.complete_application(token), "The fixture tattoo must apply.")
	var/list/tattooed = custom_sprite_live_packages(recipient, "markings")
	var/list/previous = custom_sprite_salon_previous(recipient, "markings")
	TEST_ASSERT(!(length(previous) != 2 || !previous[arm_key] || !previous[leg_key]), "Both applied regions must have a previous look to restore.")
	var/list/choices = custom_sprite_salon_restore_choices(previous)
	TEST_ASSERT(json_encode(choices) == json_encode(list("Whole body" = list(arm_key, leg_key), "Left arm" = list(arm_key), "Right leg" = list(leg_key))), "Restore must offer the whole body, then each region: [json_encode(choices)]")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	var/datum/custom_sprite_salon/test/one = new(machine, artist, recipient, "markings", custom_sprite_salon_previous(recipient, "markings", choices["Left arm"]))
	var/error = one.propose(artist)
	TEST_ASSERT(!error, "Restoring one region must open the mirror: [error]")
	token = one.proposal["token"]
	TEST_ASSERT(!(!one.accept(recipient, token) || !one.complete_application(token)), "The one-region restoration must apply.")
	var/list/after = custom_sprite_live_packages(recipient, "markings")
	TEST_ASSERT(custom_style_package_hash(after[arm_key]) == custom_style_package_hash(before[arm_key]), "The chosen region must get its previous look back.")
	TEST_ASSERT(custom_style_package_hash(after[leg_key]) == custom_style_package_hash(tattooed[leg_key]), "Regions not chosen must keep their tattoo.")
	TEST_ASSERT(!length(one.awards), "Restorations award nothing.")
	GLOB.custom_sprite_salon_cooldowns.Cut()
	var/datum/custom_sprite_salon/test/whole = new(machine, artist, recipient, "markings", custom_sprite_salon_previous(recipient, "markings", choices["Whole body"]))
	error = whole.propose(artist)
	TEST_ASSERT(!error, "Restoring the whole body must open the mirror: [error]")
	token = whole.proposal["token"]
	TEST_ASSERT(!(!whole.accept(recipient, token) || !whole.complete_application(token)), "The whole-body restoration must apply.")
	after = custom_sprite_live_packages(recipient, "markings")
	TEST_ASSERT(!(custom_style_package_hash(after[arm_key]) != custom_style_package_hash(tattooed[arm_key]) || custom_style_package_hash(after[leg_key]) != custom_style_package_hash(before[leg_key])), "A whole-body restoration must swap every region with history.")

/// Gloves grey the hands out the moment they go on and free them when they come off. Drafted paint under them stays.
/datum/unit_test/custom_sprite_salon/live_coverage/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/locked = canvas.locked_regions()
	TEST_ASSERT(!length(locked), "An undressed recipient has nothing locked: [json_encode(locked)]")
	TEST_ASSERT(paint_region(session, BODY_ZONE_PRECISE_L_HAND), "The fixture must paint the left hand.")
	var/list/point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_PRECISE_L_HAND)
	var/list/frame = canvas.workspace.layers[1]["data"]["2"]
	var/painted = frame[point[2] + 1][point[1] + 1]
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	locked = canvas.locked_regions()
	TEST_ASSERT(!(!findtext(locked[BODY_ZONE_PRECISE_L_HAND], "covered") || !locked[BODY_ZONE_PRECISE_R_HAND] || locked[BODY_ZONE_L_ARM]), "Gloves must lock both hands and nothing else: [json_encode(locked)]")
	TEST_ASSERT(!canvas.workspace.is_point_allowed(point[1], point[2], "2"), "Putting gloves on must lock the hand at once.")
	var/list/mask = canvas.workspace.draw_mask["2"]
	TEST_ASSERT(copytext(mask[point[2] + 1], point[1] + 1, point[1] + 2) == "0", "A covered region must be shaded on the canvas.")
	frame = canvas.workspace.layers[1]["data"]["2"]
	TEST_ASSERT(frame[point[2] + 1][point[1] + 1] == painted, "Drafted paint under clothing must be kept.")
	var/list/data = canvas.ui_data(artist)
	var/list/reasons = data["lockedRegions"]
	TEST_ASSERT(findtext(reasons[BODY_ZONE_PRECISE_L_HAND], "covered"), "The window must say why the hand is locked.")
	TEST_ASSERT(findtext(session.propose(artist), "covered"), "The covered, touched hand must block finishing.")
	// A whole-body import skips the covered hand and names it.
	var/list/arm_point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_L_ARM)
	var/list/regions = list(BODY_ZONE_PRECISE_L_HAND = custom_style_package("markings", BODY_ZONE_PRECISE_L_HAND, custom_sprite_test_front_drawing(point, "#123456"), null), BODY_ZONE_L_ARM = custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_front_drawing(arm_point, "#123456"), null))
	TEST_ASSERT(canvas.show_region_candidate(regions, "import"), "An import must preview around a covered region: [canvas.transfer_error]")
	TEST_ASSERT(("Left hand (not available right now)" in canvas.candidate["skipped"]), "The preview must name the covered hand: [json_encode(canvas.candidate["skipped"])]")
	TEST_ASSERT(canvas.apply_candidate(), "The rest of the import must apply: [canvas.transfer_error]")
	canvas.draft_changed()
	// Undo is the artist's own history, even across a covered region; finishing still never applies one.
	canvas.workspace.undo(2)
	canvas.draft_changed()
	var/list/results = canvas.region_results()
	var/list/hand = results[BODY_ZONE_PRECISE_L_HAND]
	TEST_ASSERT(!hand["changed"], "Undo may take back a stroke on a covered region.")
	TEST_ASSERT(session.propose(artist) == "Nothing has changed yet.", "With the covered stroke undone, nothing is left to propose.")
	recipient.dropItemToGround(gloves)
	TEST_ASSERT(canvas.workspace.is_point_allowed(point[1], point[2], "2"), "Taking the gloves off must unlock the hand at once.")

/// Clothing on at the start keeps the selection off covered regions. A rolled-down jumpsuit frees the torso and arms once the guides refresh.
/datum/unit_test/custom_sprite_salon/covered_start/Run()
	setup_players()
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/locked = canvas.locked_regions()
	TEST_ASSERT(!(!locked[BODY_ZONE_CHEST] || !locked[BODY_ZONE_L_ARM] || !locked[BODY_ZONE_L_LEG]), "A jumpsuit must lock the torso, arms and legs: [json_encode(locked)]")
	TEST_ASSERT(!(!canvas.selected_zone || (canvas.selected_zone in locked)), "Opening must select a region that isn't covered: [canvas.selected_zone]")
	TEST_ASSERT(uniform.can_adjust && !uniform.alt_covers_chest, "The fixture jumpsuit must roll down to bare the torso and arms.")
	var/list/arm_point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_L_ARM)
	// Adjusting the jumpsuit without redrawing it still frees the arms at once.
	uniform.toggle_jumpsuit_adjust()
	locked = canvas.locked_regions()
	TEST_ASSERT(!(locked[BODY_ZONE_L_ARM] || locked[BODY_ZONE_CHEST] || !locked[BODY_ZONE_L_LEG] || !canvas.workspace.is_point_allowed(arm_point[1], arm_point[2], "2")), "A rolled-down jumpsuit must free the torso and arms at once and keep the legs covered: [json_encode(locked)]")
	TEST_ASSERT(session.dress_timer, "Adjusting the jumpsuit must schedule a guide refresh.")
	deltimer(session.dress_timer)
	session.refresh_editor_body()
	TEST_ASSERT(canvas.workspace.is_point_allowed(arm_point[1], arm_point[2], "2"), "Refreshing the guides must keep the arms free.")
	for(var/obj/item/bodypart/limb as anything in recipient.bodyparts)
		limb.is_husked = TRUE
	TEST_ASSERT(findtext(custom_sprite_salon_start_problem(machine, artist, recipient, "markings"), "nowhere to tattoo"), "A body with nothing tattooable can't start tattoo work.")

/// Body changes keep the canvas's regions. A missing or replaced part greys out with the reason and blocks finishing only when touched.
/datum/unit_test/custom_sprite_salon/body_changes/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/zones = json_encode(canvas.region_zones)
	var/list/map = canvas.region_map
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/list/point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_L_ARM)
	var/list/frame = canvas.workspace.layers[1]["data"]["2"]
	var/painted = frame[point[2] + 1][point[1] + 1]
	var/obj/item/bodypart/arm = recipient.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(TRUE)
	allocated += arm
	if(session.dress_timer)
		deltimer(session.dress_timer)
	session.rebuild_preview_body = TRUE
	session.refresh_editor_body()
	TEST_ASSERT(!(json_encode(canvas.region_zones) != zones || canvas.region_map != map), "A body change must keep the canvas's regions, so paint never changes region.")
	var/list/locked = canvas.locked_regions()
	TEST_ASSERT(!(!findtext(locked[BODY_ZONE_L_ARM], "can't be tattooed") || !locked[BODY_ZONE_PRECISE_L_HAND]), "A missing arm must lock its region and its hand's: [json_encode(locked)]")
	frame = canvas.workspace.layers[1]["data"]["2"]
	TEST_ASSERT(frame[point[2] + 1][point[1] + 1] == painted, "Paint drafted on a missing arm must be kept.")
	TEST_ASSERT(findtext(session.propose(artist), "can't be tattooed"), "A touched region that's gone must block finishing with the reason.")
	var/obj/item/bodypart/arm/left/replacement = allocate(/obj/item/bodypart/arm/left)
	replacement.replace_limb(recipient)
	locked = canvas.locked_regions()
	TEST_ASSERT(findtext(locked[BODY_ZONE_L_ARM], "replaced"), "A different arm must lock the region as replaced: [json_encode(locked)]")
	TEST_ASSERT(findtext(session.propose(artist), "replaced"), "A touched region on a replaced arm must block finishing.")
	var/obj/item/bodypart/right_arm = recipient.get_bodypart(BODY_ZONE_R_ARM)
	right_arm.is_husked = TRUE
	locked = canvas.locked_regions()
	TEST_ASSERT(!(!locked[BODY_ZONE_R_ARM] || !locked[BODY_ZONE_PRECISE_R_HAND]), "A husked arm must lock its region and its hand's: [json_encode(locked)]")

/// A taur body hidden by clothing or choice greys out, and is tattooable again once it shows.
/datum/unit_test/custom_sprite_salon/hidden_taur/Run()
	setup_players()
	var/obj/item/organ/taur_body/organ = custom_sprite_test_taur(recipient)
	TEST_ASSERT(organ, "The salon fixture needs a real taur organ.")
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/locked = canvas.locked_regions()
	TEST_ASSERT(!locked[CUSTOM_MARKING_ZONE_TAUR], "A visible taur body is tattooable: [json_encode(locked)]")
	var/list/point = custom_sprite_test_region_pixel(canvas, CUSTOM_MARKING_ZONE_TAUR)
	organ.hide_self = TRUE
	canvas.sync_locked_views()
	locked = canvas.locked_regions()
	TEST_ASSERT(findtext(locked[CUSTOM_MARKING_ZONE_TAUR], "covered"), "A hidden taur body must be locked: [json_encode(locked)]")
	TEST_ASSERT(!canvas.workspace.is_point_allowed(point[1], point[2], "2"), "A hidden taur body can't be painted.")
	organ.hide_self = FALSE
	canvas.sync_locked_views()
	TEST_ASSERT(canvas.workspace.is_point_allowed(point[1], point[2], "2"), "A taur body that shows again is paintable.")
	// Taken off rather than swapped for another, it wasn't replaced.
	organ.Remove(recipient, special = TRUE)
	allocated += organ
	locked = canvas.locked_regions()
	TEST_ASSERT(findtext(locked[CUSTOM_MARKING_ZONE_TAUR], "can't be tattooed"), "A removed taur body must lock as untattooable, not replaced: [json_encode(locked)]")

/// The mirror redraws both pictures when the recipient's look changes while they decide.
/datum/unit_test/custom_sprite_salon/mirror_refresh/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	TEST_ASSERT(paint_region(session, BODY_ZONE_L_ARM), "The fixture must paint the left arm.")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "The fixture must open the mirror: [error]")
	var/datum/custom_sprite_mirror/mirror = session.mirror
	var/list/before = mirror.before_urls.Copy()
	var/list/after = mirror.after_urls.Copy()
	// Someone else tattoos a region the proposal doesn't touch.
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_R_LEG, custom_sprite_test_drawing(), null))
	TEST_ASSERT(mirror.refresh_timer, "A change to the recipient's look must schedule a mirror redraw.")
	deltimer(mirror.refresh_timer)
	mirror.refresh()
	TEST_ASSERT(!(mirror.before_urls["2"] == before["2"] || mirror.after_urls["2"] == after["2"]), "Both pictures must show the recipient's new look.")

/// Restoring the whole body leaves out regions that can't be worked on right now, and restores the rest.
/datum/unit_test/custom_sprite_salon/restore_covered/Run()
	setup_players()
	var/arm_key = custom_style_key("markings", BODY_ZONE_L_ARM)
	var/hand_key = custom_style_key("markings", BODY_ZONE_PRECISE_L_HAND)
	var/list/history = list()
	history[arm_key] = custom_sprite_live_package(recipient, "markings", BODY_ZONE_L_ARM)
	history[hand_key] = custom_sprite_live_package(recipient, "markings", BODY_ZONE_PRECISE_L_HAND)
	recipient.custom_sprite_round_history = history
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_L_ARM, custom_sprite_test_drawing(), null))
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_PRECISE_L_HAND, custom_sprite_test_drawing(), null))
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	custom_sprite_salon_start_restore(machine, artist, recipient, "markings")
	var/datum/custom_sprite_salon/session = GLOB.custom_sprite_salon_restorations[artist.ckey]
	TEST_ASSERT(session?.proposal, "Restoring the whole body must go ahead without the covered hand.")
	TEST_ASSERT(json_encode(assoc_to_keys(session.proposal["packages"])) == json_encode(list(arm_key)), "Only the uncovered region may be restored: [json_encode(assoc_to_keys(session.proposal["packages"]))]")
	qdel(session)
	GLOB.custom_sprite_salon_cooldowns.Cut()
	custom_sprite_salon_start_restore(machine, artist, recipient, "markings", list(hand_key))
	TEST_ASSERT(!GLOB.custom_sprite_salon_restorations[artist.ckey], "Restoring only a covered region must be refused.")

/// A region whose look changes on the body while work goes on greys out with the reason; the rest stay free.
/datum/unit_test/custom_sprite_salon/changed_regions/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/list/point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_R_LEG)
	custom_sprite_apply_round_style(recipient, custom_style_package("markings", BODY_ZONE_R_LEG, custom_sprite_test_drawing(), null))
	canvas.sync_locked_views()
	var/list/locked = canvas.locked_regions()
	TEST_ASSERT(findtext(locked[BODY_ZONE_R_LEG], "changed since work started"), "A region changed on the body must lock with the reason: [json_encode(locked)]")
	TEST_ASSERT(length(locked) == 1, "Only the changed region may lock: [json_encode(locked)]")
	TEST_ASSERT(!canvas.workspace.is_point_allowed(point[1], point[2], "2"), "A changed region can't take paint.")
	// Putting the look back frees it again.
	var/list/start = session.original[custom_style_key("markings", BODY_ZONE_R_LEG)]
	custom_sprite_apply_round_style(recipient, start["package"])
	canvas.sync_locked_views()
	TEST_ASSERT(canvas.workspace.is_point_allowed(point[1], point[2], "2"), "A region whose look is back as it was can take paint again.")

/// Applying a tattoo over several regions redraws the body once.
/datum/unit_test/custom_sprite_salon/one_redraw/Run()
	setup_players(/mob/living/carbon/human/consistent/redraw_counting)
	var/mob/living/carbon/human/consistent/redraw_counting/counting = recipient
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	TEST_ASSERT(!(!paint_region(session, BODY_ZONE_L_ARM) || !paint_region(session, BODY_ZONE_R_LEG)), "The fixture must paint two regions.")
	var/error = session.propose(artist)
	TEST_ASSERT(!error, "The fixture must open the mirror: [error]")
	var/token = session.proposal["token"]
	TEST_ASSERT(session.accept(recipient, token), "The fixture tattoo must be approved.")
	counting.redraws = 0
	TEST_ASSERT(session.complete_application(token), "The fixture tattoo must apply.")
	TEST_ASSERT(counting.redraws == 1, "Applying two regions must redraw the body once: [counting.redraws]")

/// One window update, or one region action, works out the region locks once.
/datum/unit_test/custom_sprite_salon/lock_checks/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/lock_counting/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/datum/tgui/ui = new(artist, canvas, "CustomMarkingsEditor")
	var/regions = length(canvas.region_zones)
	session.part_checks = 0
	canvas.ui_data(artist)
	TEST_ASSERT(session.part_checks == regions, "A window update must check each region once: [session.part_checks] checks for [regions] regions")
	session.part_checks = 0
	TEST_ASSERT(canvas.ui_act("selectRegion", list("zone" = BODY_ZONE_L_ARM), ui), "The fixture must select the left arm.")
	TEST_ASSERT(session.part_checks == regions, "Selecting a region must check each region once: [session.part_checks] checks for [regions] regions")
	qdel(ui)

/// Covering a region stops its base markings changing too, such as a recolour that waited on the colour picker.
/datum/unit_test/custom_sprite_salon/covered_markings/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	var/name = GLOB.body_markings_per_limb[BODY_ZONE_CHEST][1]
	TEST_ASSERT(canvas.write_region_marking(BODY_ZONE_CHEST, null, name, "#112233"), "The fixture must give the torso a base marking.")
	var/obj/item/clothing/under/uniform = allocate(/obj/item/clothing/under/color/grey)
	recipient.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING)
	TEST_ASSERT(!canvas.write_region_marking(BODY_ZONE_CHEST, 1, name, "#445566"), "A covered torso must refuse a base-marking recolour.")
	var/list/entries = canvas.workspace.markings_context[BODY_ZONE_CHEST]
	var/list/entry = entries[1]
	TEST_ASSERT(entry["color"] == "#112233", "The torso's drafted base marking must stay as it was: [entry["color"]]")

/// Erasing over paint in a covered region makes no sound, since the stroke is refused.
/datum/unit_test/custom_sprite_salon/locked_erasing/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(machine, artist, recipient, "markings")
	var/datum/custom_sprite_editor/markings/canvas = session.editor
	TEST_ASSERT(paint_region(session, BODY_ZONE_PRECISE_L_HAND), "The fixture must paint the left hand.")
	var/list/point = custom_sprite_test_region_pixel(canvas, BODY_ZONE_PRECISE_L_HAND)
	var/obj/item/clothing/gloves/gloves = allocate(/obj/item/clothing/gloves/color/black)
	recipient.equip_to_slot_if_possible(gloves, ITEM_SLOT_GLOVES)
	var/datum/tgui/ui = new(artist, canvas, "CustomMarkingsEditor")
	var/list/activity = list("dir" = "2", "x" = point[1], "y" = point[2], "erasing" = TRUE)
	canvas.ui_act("drawing", activity, ui)
	TEST_ASSERT(!(session.drawing_sound || session.drawing_ambience), "Erasing paint in a covered region must stay silent.")
	recipient.dropItemToGround(gloves)
	canvas.ui_act("drawing", activity, ui)
	TEST_ASSERT(session.drawing_sound, "Erasing paint in an uncovered region must sound.")
	qdel(ui)

/// A salon haircut's preview follows the artist's strokes, as a tattoo's does.
/datum/unit_test/custom_sprite_salon/hair_preview/Run()
	setup_players()
	var/datum/custom_sprite_salon/test/session = new(scissors, artist, recipient, "hair")
	var/datum/custom_sprite_editor/editor = session.editor
	var/datum/tgui/ui = new(artist, editor, "CustomHairEditor")
	var/before = editor.preview_urls["2"]
	editor.workspace.update_palette(editor.workspace.palette | "#ff0000")
	var/list/points = list()
	for(var/y in 1 to 4)
		for(var/x in 1 to 4)
			points += list(list(x, y))
	editor.ui_act("spriteEditorCommand", list("command" = "transaction", "transaction" = list("type" = "pencil", "layer" = 1, "dir" = "2", "color" = "#ff0000ff", "points" = points)), ui, null)
	TEST_ASSERT(editor.preview_timer, "A haircut stroke must schedule a preview refresh.")
	deltimer(editor.preview_timer)
	editor.refresh_preview()
	TEST_ASSERT(editor.preview_urls["2"] != before, "The haircut preview must show a new stroke.")
	qdel(ui)
