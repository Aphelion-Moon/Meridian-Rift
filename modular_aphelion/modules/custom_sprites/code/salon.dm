#define SALON_DRAFTING "drafting"
#define SALON_AWAITING_APPROVAL "awaiting approval"
#define SALON_APPLYING "applying"
#define SALON_COMPLETED "completed"
#define SALON_PROMPT_TIMEOUT (120 SECONDS)
#define SALON_REQUEST_COOLDOWN (10 SECONDS)
#define SALON_APPLY_DURATION (5 SECONDS)
/// Hair starts hitting the floor shortly after the artist gets going.
#define SALON_TRIMMING_FIRST_DELAY (5 SECONDS)
/// How long the pile takes to build up by one more step while work continues.
#define SALON_TRIMMING_GROW_MIN (20 SECONDS)
#define SALON_TRIMMING_GROW_MAX (40 SECONDS)
/// Mid-cut the pile only ever reaches this size. The rest lands on completion.
#define SALON_TRIMMING_WORKING_MAX 2

/// Artist ckey -> style key -> that artist's retained draft for that drawing.
/// Hair, facial hair and each tattoo zone are separate drafts, so one never discards another.
GLOBAL_LIST_EMPTY(custom_sprite_salon_sessions)
/// Artist ckey -> an in-progress restoration. Restorations have no draft to retain.
GLOBAL_LIST_EMPTY(custom_sprite_salon_restorations)
/// Recipient ckey -> TRUE while they have an incoming salon prompt.
GLOBAL_LIST_EMPTY(custom_sprite_salon_prompts)
/// "artist ckey|recipient ckey" -> world.time when that pair may send another request.
GLOBAL_LIST_EMPTY(custom_sprite_salon_cooldowns)

/// The artist's retained draft for one drawing, or null.
/proc/custom_sprite_salon_session(artist_ckey, target, zone)
	var/list/drafts = GLOB.custom_sprite_salon_sessions[artist_ckey]
	return drafts?[custom_style_key(target, zone)]

/// Every draft this artist has, newest last.
/proc/custom_sprite_salon_sessions_for(artist_ckey)
	var/list/drafts = GLOB.custom_sprite_salon_sessions[artist_ckey]
	. = list()
	for(var/key in drafts)
		. += drafts[key]

/// The drafts this tool can resume.
/proc/custom_sprite_salon_sessions_for_tool(artist_ckey, obj/item/tool)
	. = list()
	for(var/datum/custom_sprite_salon/session as anything in custom_sprite_salon_sessions_for(artist_ckey))
		if(istype(tool, session.tool_type))
			. += session

/mob/living/carbon/human
	/// Style key -> the style this body had before its last salon change. Drawings may be explicitly null.
	var/list/custom_sprite_round_history

/proc/custom_sprite_salon_label(target, zone)
	if(target == "facial_hair")
		return "facial hairstyle"
	if(target == "hair")
		return "hairstyle"
	return "[LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] tattoo"

/// The recipient's live style for one target. Hair includes the whitelisted base hair look.
/proc/custom_sprite_live_package(mob/living/carbon/human/body, target, zone)
	var/list/drawing
	var/list/markings
	if(custom_style_hair_target(target))
		var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
		drawing = head?.custom_head_drawing(target)
	else
		var/obj/item/bodypart/limb = body.get_bodypart(custom_marking_zone_limb(zone))
		if(zone in GLOB.body_markings_per_limb)
			markings = custom_style_marking_entries(zone == limb?.aux_zone ? limb?.aux_zone_markings : limb?.markings)
		var/datum/bodypart_overlay/custom_marking/marking = limb?.get_custom_marking(custom_marking_zone_overlay_type(zone))
		drawing = marking?.drawing
	return custom_style_package(target, zone, custom_sprite_validate(drawing), custom_style_hair_target(target) ? custom_style_live_hair_context(body, target) : null, markings)

/// Ordered, portable records for a limb's existing native markings.
/proc/custom_style_marking_entries(list/native)
	. = list()
	for(var/name in native)
		var/list/entry = native[name]
		. += list(list("name" = name, "color" = custom_style_normal_color(entry[MARKING_INDEX_COLOR]), "emissive" = entry[MARKING_INDEX_EMISSIVE] ? TRUE : FALSE))

/// Convert validated records back into the native marking renderer's ordered map.
/proc/custom_style_marking_data(list/entries)
	. = list()
	for(var/list/entry as anything in entries)
		.[entry["name"]] = list(entry["color"], entry["emissive"])

/// Change only this limb/hand's native markings and its DNA snapshot. The caller redraws the body.
/proc/custom_style_apply_base_markings(mob/living/carbon/human/body, zone, list/entries, allow_emissives = TRUE)
	if(isnull(entries))
		return
	var/list/native = custom_style_marking_data(entries)
	if(!allow_emissives)
		for(var/name in native)
			native[name][MARKING_INDEX_EMISSIVE] = FALSE
	LAZYSET(body.dna.body_markings, zone, deep_copy_list(native))
	var/obj/item/bodypart/limb = body.get_bodypart(custom_marking_zone_limb(zone))
	if(limb)
		if(zone == limb.aux_zone)
			limb.aux_zone_markings = native
		else
			limb.markings = native

/// Applies a whitelisted hair look to a live or preview body.
/proc/custom_style_apply_hair_context(mob/living/carbon/human/body, list/hair, update = TRUE, target = "hair")
	var/gradient_key = custom_style_gradient_key(target)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	if(target == "facial_hair")
		body.set_facial_hairstyle(hair["style"], update = FALSE)
		body.set_facial_haircolor(hair["color"], update = FALSE)
		// The gradient setters own the head-hair key only.
		LAZYSET(body.grad_style, gradient_key, hair["gradient_style"])
		LAZYSET(body.grad_color, gradient_key, hair["gradient_color"])
	else
		body.set_hairstyle(hair["style"], update = FALSE)
		body.set_haircolor(hair["color"], update = FALSE)
		body.set_hair_gradient_style(hair["gradient_style"], update = FALSE)
		body.set_hair_gradient_color(hair["gradient_color"], update = FALSE)
		body.hair_alpha = hair["opacity"]
		body.emissive_hair = hair["emissive"]
		if(head)
			head.hair_alpha = hair["opacity"] || body.dna.species.hair_alpha
	if(head)
		// The body setters may early-return when its cache matches but a donor head differs.
		LAZYSET(head.gradient_styles, gradient_key, hair["gradient_style"])
		LAZYSET(head.gradient_colors, gradient_key, hair["gradient_color"])
	if(update)
		body.update_hair()

/**
 * Changes a live body's round appearance for one drawing target.
 *
 * DNA keeps the edit for regenerated limbs; attached donor parts retain their other snapshots.
 * Normal redraws preserve native markings, skin and the unedited custom layers.
 */
/proc/custom_sprite_apply_round_style(mob/living/carbon/human/body, list/package, allow_emissives)
	if(isnull(allow_emissives))
		var/datum/preferences/preferences = GLOB.preferences_datums[body.ckey]
		allow_emissives = preferences?.read_preference(/datum/preference/toggle/allow_emissives)
	var/list/drawing = custom_sprite_appearance_drawing(package["drawing"], allow_emissives)
	var/zone = package["zone"]
	body.AddComponent(/datum/component/custom_sprite_appearance)
	var/target = package["target"]
	if(custom_style_hair_target(target))
		if(package["hair"])
			custom_style_apply_hair_context(body, package["hair"], update = FALSE, target = target)
		if(target == "facial_hair")
			body.dna.custom_facial_hair = drawing
		else
			body.dna.custom_hair = drawing
		var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
		head?.set_custom_head_drawing(target, deep_copy_list(drawing))
		body.update_hair()
		return
	custom_style_apply_base_markings(body, zone, package["markings"], allow_emissives)
	if(drawing)
		LAZYSET(body.dna.custom_limb_markings, zone, drawing)
	else
		LAZYREMOVE(body.dna.custom_limb_markings, zone)
	var/obj/item/bodypart/limb = body.get_bodypart(custom_marking_zone_limb(zone))
	limb?.apply_custom_marking(drawing, custom_marking_zone_overlay_type(zone))
	body.update_body()

/**
 * Builds a private preview body from a live body's current appearance.
 *
 * This deliberately avoids generate_dummy_lookalike(), which reapplies saved preferences and can
 * undo round changes. Only appearance data is copied: no inventory, mind, quirks or effects.
 * Replaced and missing limbs follow the source body.
 */
/proc/custom_sprite_salon_dummy(mob/living/carbon/human/source)
	var/mob/living/carbon/human/dummy/body = new
	var/obj/item/bodypart/head/source_head = source.get_bodypart(BODY_ZONE_HEAD)
	source.dna.copy_dna(body.dna, COPY_DNA_SPECIES)
	source.copy_clothing_prefs(body)
	body.underwear_visibility = source.underwear_visibility
	body.gender = source.gender
	body.physique = source.physique
	body.skin_tone = source.skin_tone
	body.eye_color_left = source.eye_color_left
	body.eye_color_right = source.eye_color_right
	body.lip_style = source_head ? source_head.lip_style : source.lip_style
	body.lip_color = source_head ? source_head.lip_color : source.lip_color
	body.facial_hairstyle = source_head ? source_head.facial_hairstyle : source.facial_hairstyle
	body.facial_hair_color = source_head ? source_head.facial_hair_color : source.facial_hair_color
	body.grad_style = LAZYCOPY(source_head ? source_head.gradient_styles : source.grad_style)
	body.grad_color = LAZYCOPY(source_head ? source_head.gradient_colors : source.grad_color)
	body.hair_masks = LAZYCOPY(source.hair_masks)
	custom_style_apply_hair_context(body, custom_style_live_hair_context(source), update = FALSE)
	custom_style_apply_hair_context(body, custom_style_live_hair_context(source, "facial_hair"), update = FALSE, target = "facial_hair")
	// The live organ may differ from DNA after surgery; clone only its visual identity and pose.
	var/obj/item/organ/taur_body/source_taur = source.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	var/obj/item/organ/taur_body/preview_taur = body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	if(preview_taur && (!source_taur || preview_taur.type != source_taur.type))
		preview_taur.Remove(body, special = TRUE)
		qdel(preview_taur)
		preview_taur = null
	if(source_taur)
		if(!preview_taur)
			preview_taur = new source_taur.type
		var/datum/bodypart_overlay/mutant/taur_body/source_overlay = source_taur.bodypart_overlay
		var/datum/bodypart_overlay/mutant/taur_body/preview_overlay = preview_taur.bodypart_overlay
		preview_overlay.sprite_datum = source_overlay.sprite_datum
		preview_overlay.draw_color = deep_copy_list(source_overlay.draw_color)
		preview_overlay.dye_color = source_overlay.dye_color
		preview_overlay.emissive_eligibility_by_color_index = LAZYCOPY(source_overlay.emissive_eligibility_by_color_index)
		preview_overlay.imprint_on_next_insertion = FALSE
		preview_overlay.can_lay_down = source_overlay.can_lay_down
		preview_overlay.laying_down = source_overlay.laying_down
		preview_overlay.laydown_offset = source_overlay.laydown_offset
		preview_taur.hide_self = source_taur.hide_self
		if(!preview_taur.owner)
			preview_taur.Insert(body, special = TRUE)
	// Initialize the new body before copying donor appearance; never reinitialize those snapshots.
	body.sync_custom_sprite_appearance(refresh_body = TRUE)
	for(var/obj/item/bodypart/limb as anything in body.bodyparts.Copy())
		var/obj/item/bodypart/source_limb = source.get_bodypart(limb.body_zone)
		if(!source_limb)
			limb.drop_limb(TRUE)
			qdel(limb)
			continue
		if(source_limb.type != limb.type)
			var/obj/item/bodypart/replacement = new source_limb.type
			if(!replacement.replace_limb(body))
				qdel(replacement)
				continue
			qdel(limb)
			limb = replacement
			if(istype(limb, /obj/item/bodypart/head))
				var/obj/item/bodypart/head/replacement_head = limb
				replacement_head.copy_appearance_from(body)
		limb.skin_tone = source_limb.skin_tone
		limb.species_color = source_limb.species_color
		limb.limb_gender = source_limb.limb_gender
		limb.bodyshape = source_limb.bodyshape
		// Customization can change a limb's sprite without changing its type.
		limb.change_appearance(source_limb.custom_sprite_icon_file(), source_limb.limb_id, source_limb.should_draw_greyscale, source_limb.is_dimorphic, update_owner = FALSE)
		limb.alpha = source_limb.alpha
		limb.markings = deep_copy_list(source_limb.markings)
		limb.aux_zone_markings = deep_copy_list(source_limb.aux_zone_markings)
		limb.markings_alpha = source_limb.markings_alpha
		limb.apply_custom_marking(null, /datum/bodypart_overlay/custom_marking/zone)
		limb.apply_custom_marking(null, /datum/bodypart_overlay/custom_marking/taur/zone)
		for(var/datum/bodypart_overlay/custom_marking/marking in source_limb.bodypart_overlays)
			limb.apply_custom_marking(marking.drawing, marking.type)
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	if(head && source_head)
		head.custom_hair = deep_copy_list(source_head.custom_hair)
		head.custom_facial_hair = deep_copy_list(source_head.custom_facial_hair)
		head.hair_alpha = source_head.hair_alpha
		head.facial_hair_alpha = source_head.facial_hair_alpha
		head.fixed_hair_color = source_head.fixed_hair_color
		head.override_hair_color = source_head.override_hair_color
	body.update_body()
	body.update_hair()
	return body

/**
 * Returns why an artist can't start work on a recipient, or null when they can.
 *
 * Starting requires two distinct connected players, a supported human recipient, adjacency and
 * the right tool in hand. The drawing target must exist and be reachable.
 */
/proc/custom_sprite_salon_start_problem(obj/item/tool, mob/living/carbon/human/artist, mob/living/carbon/human/recipient, target, zone)
	if(CONFIG_GET(flag/disallow_custom_sprite_editing))
		return "Custom styling is disabled on this server."
	if(!ishuman(artist) || !ishuman(recipient) || isdummy(recipient))
		return "You can't style that."
	if(!GET_CLIENT(artist) || !artist.ckey)
		return "Custom styling needs a connected player."
	if(artist != recipient && (!GET_CLIENT(recipient) || artist.ckey == recipient.ckey))
		return "Custom styling needs another connected player."
	if(artist.stat != STABLE || INCAPACITATED_IGNORING(artist, INCAPABLE_GRAB))
		return "You can't do that right now."
	if(artist != recipient && recipient.stat != STABLE)
		return "[recipient] needs to be awake."
	if(QDELETED(tool) || !artist.is_holding(tool))
		return "You need to hold [tool]."
	if(artist != recipient && !artist.Adjacent(recipient))
		return "You need to be next to [recipient]."
	return custom_sprite_salon_target_problem(recipient, target, zone, artist == recipient)

/// Why a drawing target can't be worked on. Addresses the recipient when they're doing the work.
/proc/custom_sprite_salon_target_problem(mob/living/carbon/human/recipient, target, zone, self_work = FALSE)
	var/whose = self_work ? "Your" : "[recipient]'s"
	if(custom_style_hair_target(target))
		var/obj/item/bodypart/head/head = recipient.get_bodypart(BODY_ZONE_HEAD)
		var/facial = target == "facial_hair"
		if(!head || !(head.head_flags & (facial ? HEAD_FACIAL_HAIR : HEAD_HAIR)) || head.is_husked)
			return "[self_work ? "You have" : "[recipient] has"] no [facial ? "facial hair" : "hair"] to style."
		if(recipient.obscured_slots & (facial ? HIDEFACIALHAIR : HIDEHAIR))
			return "[whose] [facial ? "facial hair" : "hair"] is covered."
		return null
	if(zone == CUSTOM_MARKING_ZONE_TAUR)
		var/obj/item/bodypart/chest = recipient.get_bodypart(BODY_ZONE_CHEST)
		var/datum/bodypart_overlay/mutant/taur_body/taur = custom_sprite_taur_overlay(recipient)
		if(!chest || chest.is_husked || !taur)
			return "[whose] taur body can't be tattooed."
		if(!taur.can_draw_on_bodypart(chest, recipient))
			return "[whose] taur body is covered."
		return null
	var/obj/item/bodypart/limb = recipient.get_bodypart(custom_marking_zone_limb(zone))
	if(!limb || IS_STUMP(limb) || (limb.bodyshape & BODYSHAPE_TAUR) || limb.is_husked || ((zone in GLOB.custom_marking_hand_arms) && !limb.aux_zone))
		return "[whose] [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] can't be tattooed."
	if(custom_sprite_zone_covered(recipient, zone))
		return "[whose] [LOWER_TEXT(GLOB.custom_marking_zone_labels[zone])] is covered."
	return null

/**
 * Returns whether worn clothing covers a marking zone.
 *
 * This reads the same worn coverage flags as other clothing checks, but per zone: a rolled-up
 * jumpsuit exposes the arms, and gloves only cover the hands rather than the whole arm.
 */
/proc/custom_sprite_zone_covered(mob/living/carbon/human/body, zone)
	var/static/list/zone_flags = list(
		BODY_ZONE_HEAD = HEAD,
		BODY_ZONE_CHEST = CHEST,
		BODY_ZONE_L_ARM = ARM_LEFT,
		BODY_ZONE_R_ARM = ARM_RIGHT,
		BODY_ZONE_PRECISE_L_HAND = HAND_LEFT,
		BODY_ZONE_PRECISE_R_HAND = HAND_RIGHT,
		BODY_ZONE_L_LEG = LEG_LEFT,
		BODY_ZONE_R_LEG = LEG_RIGHT,
	)
	return !!(body.get_all_covered_flags() & zone_flags[zone])

/**
 * Whether someone can see the parts of themselves they can't look at directly.
 *
 * A hand mirror you're holding, or a mounted mirror you're standing by.
 */
/proc/custom_sprite_self_mirror(mob/living/carbon/human/user)
	if(locate(/obj/item/hhmirror) in user.held_items)
		return TRUE
	for(var/obj/structure/mirror/mirror in range(1, user))
		if(!mirror.broken)
			return TRUE
	return FALSE

/// Claims the recipient's single incoming prompt and the pair's request cooldown.
/proc/custom_sprite_salon_claim_request(artist_ckey, recipient_ckey)
	if(GLOB.custom_sprite_salon_prompts[recipient_ckey])
		return "They're already considering a style request."
	var/pair = "[artist_ckey]|[recipient_ckey]"
	if(world.time < GLOB.custom_sprite_salon_cooldowns[pair])
		return "Please wait."
	GLOB.custom_sprite_salon_cooldowns[pair] = world.time + SALON_REQUEST_COOLDOWN
	GLOB.custom_sprite_salon_prompts[recipient_ckey] = TRUE
	return null

/**
 * Asks a recipient to start custom work, then opens the artist's editor. Sleeps on prompts.
 *
 * Call through INVOKE_ASYNC from item interactions. Every condition is checked again after each
 * prompt, because either player may have moved, changed bodies or disconnected meanwhile.
 */
/proc/custom_sprite_salon_request(obj/item/tool, mob/living/carbon/human/artist, mob/living/carbon/human/recipient, target, zone)
	var/problem = custom_sprite_salon_start_problem(tool, artist, recipient, target, zone)
	if(problem)
		to_chat(artist, span_warning(problem))
		return
	var/label = custom_sprite_salon_label(target, zone)
	var/datum/custom_sprite_salon/existing = custom_sprite_salon_session(artist.ckey, target, zone)
	if(existing)
		var/choice = tgui_alert(artist, "You already have [existing.work_phrase()]. Starting new work discards that draft.", "Custom work in progress", list("Keep it", "Export and discard", "Discard"))
		if(QDELETED(existing) || custom_sprite_salon_session(artist.ckey, target, zone) != existing)
			return
		if(!(choice in list("Export and discard", "Discard")))
			// The target is already chosen; resume that exact draft without another picker.
			custom_sprite_salon_open_draft(existing, tool, artist)
			return
		if(choice == "Export and discard")
			var/export_error = custom_style_send(artist.client, existing.editor.current_package())
			if(export_error)
				to_chat(artist, span_warning("[export_error] Your draft was kept."))
				return
		qdel(existing)
		problem = custom_sprite_salon_start_problem(tool, artist, recipient, target, zone)
		if(problem)
			to_chat(artist, span_warning(problem))
			return
	var/artist_ckey = artist.ckey
	var/recipient_ckey = recipient.ckey
	if(artist == recipient)
		// Your own body needs no consent, no prompt and no cooldown.
		var/datum/custom_sprite_salon/session = new(tool, artist, recipient, target, zone)
		to_chat(artist, span_notice("You start working on your own [label]."))
		session.editor.ui_interact(artist)
		return
	problem = custom_sprite_salon_claim_request(artist_ckey, recipient_ckey)
	if(problem)
		to_chat(artist, span_warning(problem))
		return
	var/list/current = custom_sprite_live_package(recipient, target, zone)
	var/list/buttons = list("Continue", "Decline")
	if(current["drawing"])
		buttons.Insert(2, "Export current style and continue")
	to_chat(artist, span_notice("You ask [recipient] whether you can draw a custom [label]."))
	var/answer = tgui_alert(recipient, "[artist] wants to draw a custom [label] for you. Nothing changes until you approve the finished design in a mirror preview.", "Custom [label]", buttons, SALON_PROMPT_TIMEOUT)
	GLOB.custom_sprite_salon_prompts -= recipient_ckey
	if(!(answer in list("Continue", "Export current style and continue")))
		if(artist)
			to_chat(artist, span_warning("[recipient || "They"] declined the custom [label]."))
		return
	if(QDELETED(artist) || QDELETED(recipient) || artist.ckey != artist_ckey || recipient.ckey != recipient_ckey)
		return
	problem = custom_sprite_salon_start_problem(tool, artist, recipient, target, zone)
	if(!problem && custom_sprite_salon_session(artist_ckey, target, zone))
		problem = "You already have custom [label] work in progress."
	if(!problem && custom_style_package_hash(custom_sprite_live_package(recipient, target, zone)) != custom_style_package_hash(current))
		problem = "[recipient]'s [label] changed. Ask again."
	if(problem)
		to_chat(artist, span_warning(problem))
		to_chat(recipient, span_warning("The custom [label] couldn't start: [problem]"))
		return
	if(answer == "Export current style and continue")
		var/export_error = custom_style_send(recipient.client, current)
		if(export_error)
			to_chat(recipient, span_warning("[export_error] The custom [label] didn't start."))
			to_chat(artist, span_warning("[recipient]'s style export failed, so the custom [label] didn't start."))
			return
	var/datum/custom_sprite_salon/session = new(tool, artist, recipient, target, zone)
	to_chat(recipient, span_notice("[artist] starts sketching a custom [label] for you."))
	session.editor.ui_interact(artist)

/**
 * Asks a recipient to restore the style they had before their last salon change. Sleeps.
 *
 * Restoration uses the same preview, consent and timed application as new work, but has no draft.
 */
/proc/custom_sprite_salon_request_restore(obj/item/tool, mob/living/carbon/human/artist, mob/living/carbon/human/recipient, target, zone)
	var/problem = custom_sprite_salon_start_problem(tool, artist, recipient, target, zone)
	var/list/previous = recipient?.custom_sprite_round_history?[custom_style_key(target, zone)]
	if(!problem && !previous)
		problem = "[recipient] has no previous style to restore."
	if(!problem && GLOB.custom_sprite_salon_restorations[artist.ckey])
		problem = "You're already restoring a style."
	if(problem)
		to_chat(artist, span_warning(problem))
		return
	var/datum/custom_sprite_salon/session = new(tool, artist, recipient, target, zone, custom_style_copy_package(previous))
	problem = session.propose(artist)
	if(problem)
		to_chat(artist, span_warning(problem))
		qdel(session)

/**
 * One artist's custom work for one recipient and drawing target.
 *
 * States: drafting -> awaiting approval -> applying -> completed. Declining, interruption or a
 * stale approval returns to drafting and keeps the draft. Approval binds to an immutable copy of
 * the exact reviewed revision, and every step checks the participants again.
 */
/datum/custom_sprite_salon
	/// Consent and application phase of this salon session.
	var/state = SALON_DRAFTING
	/// Account allowed to edit and resume this draft.
	var/artist_ckey
	/// Account allowed to approve the finished design.
	var/recipient_ckey
	/// Recipient's display name captured when work starts.
	var/recipient_name
	/// Weak reference to the artist's current body.
	var/datum/weakref/artist_ref
	/// Weak reference to the original recipient body.
	var/datum/weakref/recipient_ref
	/// Weak reference to the tool used to start the work.
	var/datum/weakref/tool_ref
	/// Original target limb; replacement invalidates finalization.
	var/datum/weakref/bodypart_ref
	/// Original taur organ for taur-zone consent; replacement invalidates the approved target.
	var/datum/weakref/taur_ref
	/// Required tool family when checking or resuming the work.
	var/tool_type
	/// Drawing kind: hair, facial_hair or markings.
	var/target
	/// Tattoo zone, or null for a hairstyle.
	var/body_zone
	/// The package and identity captured when work started. Changes invalidate proposals.
	var/list/original
	/// Recipient's master emissive permission captured for the draft.
	var/recipient_emissives = FALSE
	/// A restoration proposes this package instead of a draft.
	var/list/restoration
	/// list("token", "revision", "package") for the reviewed revision.
	var/list/proposal
	/// Recipient requested a permanent save after this exact proposal is successfully applied.
	var/save_on_completion = FALSE
	/// Retained drawing editor owned by this session.
	var/datum/custom_sprite_editor/salon/editor
	/// Current recipient approval window, if any.
	var/datum/custom_sprite_mirror/mirror
	/// Working on your own body: no consent step, and views you can't see need a mirror.
	var/self_work = FALSE
	/// Artist currently watched for mirror and movement changes.
	var/datum/weakref/watched_ref
	/// Pending rebuild after the recipient's clothing changed.
	var/dress_timer
	/// A body-owned appearance changed; worn items alone can reuse the existing preview body.
	var/rebuild_preview_body = FALSE
	/// Pending timer for the next lot of clippings to hit the floor.
	var/trimming_timer
	/// How big the pile under the recipient has grown so far.
	var/trimming_stage = 0

/datum/custom_sprite_salon/New(obj/item/tool, mob/living/carbon/human/artist, mob/living/carbon/human/recipient, target, zone, list/restoration)
	artist_ckey = artist.ckey
	recipient_ckey = recipient.ckey
	recipient_name = "[recipient]"
	artist_ref = WEAKREF(artist)
	recipient_ref = WEAKREF(recipient)
	tool_ref = WEAKREF(tool)
	tool_type = istype(tool, /obj/item/scissors) ? /obj/item/scissors : /obj/item/tattoo_machine
	src.target = target
	body_zone = zone
	self_work = artist == recipient
	bodypart_ref = WEAKREF(recipient.get_bodypart(custom_marking_zone_limb(zone) || BODY_ZONE_HEAD))
	if(zone == CUSTOM_MARKING_ZONE_TAUR)
		taur_ref = WEAKREF(recipient.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR))
	var/list/package = custom_sprite_live_package(recipient, target, zone)
	original = list("package" = package, "hash" = custom_style_package_hash(package))
	var/datum/preferences/recipient_preferences = GLOB.preferences_datums[recipient_ckey]
	recipient_emissives = !!recipient_preferences?.read_preference(/datum/preference/toggle/allow_emissives)
	src.restoration = restoration
	watch_artist(artist)
	watch_recipient(recipient)
	if(restoration)
		GLOB.custom_sprite_salon_restorations[artist_ckey] = src
		return
	LAZYSET(GLOB.custom_sprite_salon_sessions[artist_ckey], custom_style_key(target, zone), src)
	editor = new(src)
	schedule_trimmings()

/datum/custom_sprite_salon/Destroy()
	var/list/drafts = GLOB.custom_sprite_salon_sessions[artist_ckey]
	var/style_key = custom_style_key(target, body_zone)
	if(drafts?[style_key] == src)
		drafts -= style_key
		if(!length(drafts))
			GLOB.custom_sprite_salon_sessions -= artist_ckey
	if(GLOB.custom_sprite_salon_restorations[artist_ckey] == src)
		GLOB.custom_sprite_salon_restorations -= artist_ckey
	close_mirror()
	QDEL_NULL(editor)
	proposal = null
	return ..()

/**
 * Queues the next lot of clippings.
 *
 * Only hair work sheds, and only a real cut rather than a restoration. Cutting
 * your own hair still drops it. Mid-cut the pile stops growing at
 * [SALON_TRIMMING_WORKING_MAX]; completion takes it the rest of the way.
 */
/datum/custom_sprite_salon/proc/schedule_trimmings()
	if(trimming_timer || restoration || !custom_style_hair_target(target))
		return
	if(state == SALON_COMPLETED || trimming_stage >= SALON_TRIMMING_WORKING_MAX)
		return
	var/delay = trimming_stage ? rand(SALON_TRIMMING_GROW_MIN, SALON_TRIMMING_GROW_MAX) : SALON_TRIMMING_FIRST_DELAY
	trimming_timer = addtimer(CALLBACK(src, PROC_REF(shed_trimmings)), delay, TIMER_STOPPABLE)

/// Drops or grows the pile under the recipient, then queues the next one.
/datum/custom_sprite_salon/proc/shed_trimmings()
	trimming_timer = null
	if(state == SALON_COMPLETED)
		return
	var/mob/living/carbon/human/recipient = recipient()
	// Nobody actually cutting means no hair falling, but the session may well
	// resume, so keep the timer running rather than giving up on it.
	if(recipient && !participant_problem())
		trimming_stage = min(trimming_stage + 1, SALON_TRIMMING_WORKING_MAX)
		drop_hair_trimmings(get_turf(recipient), recipient, trimming_stage, facial = (target == "facial_hair"))
	schedule_trimmings()

/datum/custom_sprite_salon/proc/label()
	return custom_sprite_salon_label(target, body_zone)

/datum/custom_sprite_salon/proc/artist()
	var/mob/living/carbon/human/artist = artist_ref?.resolve()
	return !QDELETED(artist) && artist.ckey == artist_ckey ? artist : null

/datum/custom_sprite_salon/proc/recipient()
	var/mob/living/carbon/human/recipient = recipient_ref?.resolve()
	return !QDELETED(recipient) && recipient.ckey == recipient_ckey ? recipient : null

/// Returns the held tool of this session's type, preferring the one work started with.
/datum/custom_sprite_salon/proc/held_tool(mob/living/carbon/human/artist)
	var/obj/item/tool = tool_ref?.resolve()
	if(!QDELETED(tool) && artist.is_holding(tool))
		return tool
	tool = locate(tool_type) in artist.held_items
	if(tool)
		tool_ref = WEAKREF(tool)
	return tool

/**
 * Returns why the work can't proceed, or null when it can.
 *
 * This covers both participants and their controlling players, consciousness, the held tool,
 * reachability, bodypart identity, and the recipient's appearance since work started.
 */
/datum/custom_sprite_salon/proc/participant_problem()
	var/mob/living/carbon/human/artist = artist()
	if(!artist || !GET_CLIENT(artist))
		return self_work ? "You aren't available." : "The artist isn't available."
	var/mob/living/carbon/human/recipient = recipient()
	if(!recipient || !GET_CLIENT(recipient))
		return self_work ? "You aren't available." : "[recipient_name] isn't available."
	if(artist.stat != STABLE || INCAPACITATED_IGNORING(artist, INCAPABLE_GRAB))
		return self_work ? "You can't work right now." : "The artist can't work right now."
	if(recipient.stat != STABLE)
		return self_work ? "You need to be awake." : "[recipient_name] needs to be awake."
	if(!held_tool(artist))
		return "[self_work ? "You need" : "The artist needs"] to hold [tool_type == /obj/item/scissors ? "scissors" : "a tattoo machine"]."
	if(!self_work && !artist.Adjacent(recipient))
		return "The artist needs to be next to [recipient_name]."
	var/whose = self_work ? "Your" : "[recipient_name]'s"
	if(body_zone == CUSTOM_MARKING_ZONE_TAUR && recipient.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR) != taur_ref?.resolve())
		return "[whose] taur body was replaced. Export the draft and start again."
	if(recipient.get_bodypart(custom_marking_zone_limb(body_zone) || BODY_ZONE_HEAD) != bodypart_ref?.resolve())
		return "[whose] [body_zone ? LOWER_TEXT(GLOB.custom_marking_zone_labels[body_zone]) : "head"] was replaced. Export the draft and start again."
	if(custom_style_package_hash(custom_sprite_live_package(recipient, target, body_zone)) != original["hash"])
		return "[whose] [label()] changed since work started. Export the draft and start again."
	return custom_sprite_salon_target_problem(recipient, target, body_zone, self_work)

/// Self-styling locks depend on what the artist is holding and where they stand, so follow both.
/datum/custom_sprite_salon/proc/watch_artist(mob/living/carbon/human/artist)
	if(!self_work || watched_ref?.resolve() == artist)
		return
	var/mob/living/carbon/human/watched = watched_ref?.resolve()
	if(watched)
		UnregisterSignal(watched, COMSIG_MOVABLE_MOVED)
	watched_ref = null
	if(QDELETED(artist))
		return
	RegisterSignal(artist, COMSIG_MOVABLE_MOVED, PROC_REF(on_artist_changed))
	watched_ref = WEAKREF(artist)

/datum/custom_sprite_salon/proc/on_artist_changed(datum/source)
	SIGNAL_HANDLER
	editor?.sync_locked_views()

/// Observe the live body, never its preview, so redraws cannot schedule themselves.
/datum/custom_sprite_salon/proc/watch_recipient(mob/living/carbon/human/recipient)
	if(QDELETED(recipient))
		return
	RegisterSignals(recipient, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM), PROC_REF(on_recipient_changed))
	RegisterSignals(recipient, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_REMOVE_OVERLAY), PROC_REF(on_recipient_overlay_changed))

/datum/custom_sprite_salon/proc/on_recipient_changed(datum/source)
	SIGNAL_HANDLER
	if(self_work)
		editor?.sync_locked_views()
	schedule_preview_refresh()

/datum/custom_sprite_salon/proc/on_recipient_overlay_changed(datum/source, layer)
	SIGNAL_HANDLER
	// Underwear is also drawn by the dummy, from its copied clothing preferences.
	var/body_changed = layer == BODYPARTS_LAYER || layer == HAIR_LAYER || layer == BODY_LAYER
	if(body_changed || (layer in GLOB.worn_overlay_layers))
		schedule_preview_refresh(body_changed)

/// Coalesce overlay remove/apply pairs without postponing refreshes during continuous changes.
/datum/custom_sprite_salon/proc/schedule_preview_refresh(body_changed = FALSE)
	if(!editor?.resources_ready)
		return
	rebuild_preview_body ||= body_changed
	if(!dress_timer)
		dress_timer = addtimer(CALLBACK(src, PROC_REF(refresh_editor_body)), 0.1 SECONDS, TIMER_STOPPABLE)

/datum/custom_sprite_salon/proc/refresh_editor_body()
	dress_timer = null
	var/rebuild_body = rebuild_preview_body
	rebuild_preview_body = FALSE
	if(QDELETED(src) || !editor?.resources_ready)
		return
	editor.rebuild_resources(reuse_body = !rebuild_body)
	editor.refresh_preview()

/// How a retained draft is described to the artist it belongs to.
/datum/custom_sprite_salon/proc/work_phrase()
	return self_work ? "custom [label()] work" : "custom [label()] work for [recipient_name]"

/// Views this artist can't work on right now. Only self-styling restricts anything.
/datum/custom_sprite_salon/proc/locked_directions()
	if(!self_work)
		return null
	var/mob/living/carbon/human/artist = artist()
	return artist && custom_sprite_self_mirror(artist) ? null : list("1")

/// Refuses changes to views the artist can't see, in case the mirror is gone by the time they finish.
/datum/custom_sprite_salon/proc/locked_view_problem(list/package)
	var/list/locked = locked_directions()
	if(!length(locked))
		return null
	var/list/original_drawing = original["package"]["drawing"]
	for(var/direction in locked)
		if(custom_sprite_direction_signature(original_drawing, direction) != custom_sprite_direction_signature(package["drawing"], direction))
			return "You need a mirror to change the [GLOB.custom_style_direction_labels[direction]] view of your own [label()]."
	return null

/// Scissors and tattoo machines change the haircut and its color, not the rest of the look.
/datum/custom_sprite_salon/proc/hair_problem(list/hair)
	if(!hair)
		return "The style has no hair settings."
	var/list/current = original["package"]["hair"]
	for(var/field in list("gradient_style", "gradient_color", "opacity", "emissive"))
		if(hair[field] != current[field])
			return "A haircut can only change the style and its color."
	var/list/accessories = custom_style_hair_accessories(target)
	var/datum/sprite_accessory/hair/hairstyle = accessories[hair["style"]]
	if(!(hair["style"] in accessories) || hairstyle?.locked)
		return "That [label()] isn't available."
	if(!custom_sprite_color(hair["color"]))
		return "That hair color isn't valid."
	return null

/datum/custom_sprite_salon/proc/proposed_package()
	return restoration ? custom_style_copy_package(restoration) : editor.current_package()

/**
 * Sends the current revision to the recipient's mirror.
 *
 * Returns:
 * - null: The mirror opened.
 * - text: Why it didn't. The draft is unchanged.
 */
/datum/custom_sprite_salon/proc/propose(mob/user)
	if(user?.ckey != artist_ckey)
		return "Only the artist can finish this work."
	if(state != SALON_DRAFTING)
		return state == SALON_AWAITING_APPROVAL ? "[recipient_name] is already reviewing this style." : "This work is already being applied."
	var/mob/living/carbon/human/artist = user
	if(artist_ref?.resolve() != artist)
		artist_ref = WEAKREF(artist)
	var/problem = participant_problem()
	if(problem)
		return problem
	var/list/package = proposed_package()
	if(custom_style_matches(package, original["package"]))
		return restoration ? "[self_work ? "You already have" : "[recipient_name] already has"] that style." : "Nothing has changed yet."
	if(custom_style_has_emission(package["drawing"]) && !recipient_emissives)
		return "[self_work ? "You have" : "[recipient_name] has"] emissive appearance disabled. Turn off Emissive on each view."
	if(!recipient_emissives)
		for(var/list/entry as anything in package["markings"])
			if(entry["emissive"])
				return "This style has glowing base markings, but [self_work ? "you have" : "[recipient_name] has"] emissive appearance disabled."
	problem = locked_view_problem(package)
	if(!problem && !self_work)
		problem = custom_sprite_salon_claim_request(artist_ckey, recipient_ckey)
	if(problem)
		return problem
	proposal = list("token" = md5("[world.time]-[rand(1, 1e9)]-[REF(src)]"), "revision" = editor?.draft_revision, "package" = package)
	if(self_work)
		// Nobody to ask: the timed work starts straight away.
		state = SALON_APPLYING
		INVOKE_ASYNC(src, PROC_REF(apply_proposal), proposal["token"])
		return null
	state = SALON_AWAITING_APPROVAL
	var/mob/living/carbon/human/recipient = recipient()
	mirror = new(src, recipient)
	to_chat(artist, span_notice("You show [recipient_name] the finished [label()] in a mirror."))
	mirror.ui_interact(recipient)
	if(editor)
		SStgui.update_uis(editor)
	return null

/// Closes the mirror without treating the close as a decision.
/datum/custom_sprite_salon/proc/close_mirror()
	if(!mirror)
		return
	var/datum/custom_sprite_mirror/closing = mirror
	mirror = null
	closing.session = null
	qdel(closing)
	GLOB.custom_sprite_salon_prompts -= recipient_ckey

/// Returns an awaiting or interrupted proposal to drafting. Restorations end instead.
/datum/custom_sprite_salon/proc/return_to_drafting(message)
	proposal = null
	save_on_completion = FALSE
	close_mirror()
	if(message)
		to_chat(artist(), span_warning(message))
	if(restoration)
		qdel(src)
		return
	state = SALON_DRAFTING
	if(editor)
		SStgui.update_uis(editor)

/datum/custom_sprite_salon/proc/draft_changed()
	if(state == SALON_AWAITING_APPROVAL)
		to_chat(recipient(), span_notice("The artist changed the design, so the preview was withdrawn."))
		return_to_drafting("You changed the design, so [recipient_name]'s preview was withdrawn.")

/datum/custom_sprite_salon/proc/decline(mob/user, reason = "declined")
	if(state != SALON_AWAITING_APPROVAL || (user && user.ckey != recipient_ckey))
		return
	return_to_drafting("[recipient_name] [reason] the [label()].[restoration ? "" : " Your draft is kept."]")

/// Recipient approval. Binds to the exact reviewed token and revision, then starts the timed action.
/datum/custom_sprite_salon/proc/accept(mob/user, token, save_permanently = FALSE)
	if(state != SALON_AWAITING_APPROVAL || !proposal || token != proposal["token"] || user != recipient())
		return FALSE
	if(mirror && world.time >= mirror.expires_at)
		mirror.expire()
		return FALSE
	if(!restoration && proposal["revision"] != editor?.draft_revision)
		return_to_drafting("The design changed before [recipient_name] approved it.")
		return FALSE
	var/problem = participant_problem()
	if(problem)
		to_chat(user, span_warning(problem))
		return_to_drafting(problem)
		return FALSE
	save_on_completion = save_permanently
	state = SALON_APPLYING
	close_mirror()
	INVOKE_ASYNC(src, PROC_REF(apply_proposal), proposal["token"])
	return TRUE

/datum/custom_sprite_salon/proc/application_valid(token)
	return state == SALON_APPLYING && proposal?["token"] == token

/// Runs the timed action and applies the approved package once. Duplicate or stale calls do nothing.
/datum/custom_sprite_salon/proc/apply_proposal(token)
	if(!application_valid(token))
		return
	var/mob/living/carbon/human/artist = artist()
	var/mob/living/carbon/human/recipient = recipient()
	if(!artist || !recipient)
		return_to_drafting("The work couldn't be applied.")
		return
	artist.visible_message(span_notice("[artist] adds the finishing touches to [recipient]'s [label()]."), span_notice("You add the finishing touches to [recipient]'s [label()]."))
	editor?.stop_drawing_sounds()
	var/finished = do_salon_work(artist, SALON_APPLY_DURATION, recipient, tool_type == /obj/item/tattoo_machine, CALLBACK(src, PROC_REF(application_valid), token))
	if(!QDELETED(src))
		complete_application(token, finished)

/**
 * Applies the approved package after the timed action. Every check runs again first.
 *
 * Returns:
 * - TRUE: Applied. The session is deleted, so a replayed call finds nothing to apply.
 * - FALSE: Stale, duplicate, interrupted or invalid. Nothing changed.
 */
/datum/custom_sprite_salon/proc/complete_application(token, finished = TRUE)
	if(!application_valid(token))
		return FALSE
	var/problem = finished ? participant_problem() : "The work was interrupted."
	if(problem)
		to_chat(recipient(), span_warning("The [label()] wasn't applied: [problem]"))
		return_to_drafting("[problem][restoration ? "" : " Your draft is kept."]")
		return FALSE
	var/mob/living/carbon/human/artist = artist()
	var/mob/living/carbon/human/recipient = recipient()
	state = SALON_COMPLETED
	var/list/package = proposal["package"]
	var/list/previous = custom_sprite_live_package(recipient, target, body_zone)
	custom_sprite_apply_round_style(recipient, package)
	LAZYSET(recipient.custom_sprite_round_history, custom_style_key(target, body_zone), previous)
	log_game("[key_name(artist)] [restoration ? "restored" : "applied"] a custom [label()] on [key_name(recipient)].")
	artist.visible_message(span_notice("[artist] finishes [self_work ? artist.p_their() : "[recipient]'s"] [label()]."), span_notice("You finish [self_work ? "your own" : "[recipient]'s"] [label()]."))
	// Hair falls on the floor whoever was holding the scissors. The awards are
	// for work done on somebody else, so they stay off self-styling.
	if(!restoration && custom_style_hair_target(target))
		drop_hair_trimmings(get_turf(recipient), recipient, 3, facial = (target == "facial_hair"))
	if(!restoration && !self_work)
		if(custom_style_hair_target(target))
			award(artist, /datum/award/achievement/misc/custom_style_given)
			award(recipient, /datum/award/achievement/misc/custom_style_received)
		else
			award(artist, /datum/award/achievement/misc/custom_tattoo_given)
			award(recipient, /datum/award/achievement/misc/custom_tattoo_received)
	if(self_work || save_on_completion)
		var/datum/custom_sprite_mirror/result = new(null, recipient, package, recipient.mind?.original_character_slot_index)
		if(save_on_completion)
			result.save_style(recipient)
		if(self_work)
			result.ui_interact(recipient)
		else
			to_chat(recipient, result.message_error ? span_warning(result.save_message) : span_notice(result.save_message))
			qdel(result)
	qdel(src)
	return TRUE

/datum/custom_sprite_salon/proc/award(mob/player, award_type)
	player.client?.give_award(award_type, player)

/**
 * Resumes a retained draft from a tool's self-use action. Sleeps only when asking which one.
 *
 * Returns TRUE when this tool had something to resume.
 */
/proc/custom_sprite_salon_resume(obj/item/tool, mob/living/carbon/human/user)
	var/list/drafts = custom_sprite_salon_sessions_for_tool(user?.ckey, tool)
	if(!length(drafts))
		var/list/other_drafts = custom_sprite_salon_sessions_for(user?.ckey)
		if(length(other_drafts))
			var/datum/custom_sprite_salon/other = other_drafts[1]
			to_chat(user, span_warning("Your [other.work_phrase()] needs [other.tool_type == /obj/item/scissors ? "scissors" : "a tattoo machine"]."))
			return TRUE
		tool.balloon_alert(user, "no custom work!")
		return FALSE
	if(length(drafts) > 1)
		INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(custom_sprite_salon_choose_draft), tool, user, drafts)
		return TRUE
	custom_sprite_salon_open_draft(drafts[1], tool, user)
	return TRUE

/// Asks which retained draft to reopen. Sleeps on the prompt.
/proc/custom_sprite_salon_choose_draft(obj/item/tool, mob/living/carbon/human/user, list/drafts)
	var/list/choices = list()
	for(var/datum/custom_sprite_salon/session as anything in drafts)
		choices[session.self_work ? "[session.label()] on yourself" : "[session.label()] for [session.recipient_name]"] = session
	var/choice = tgui_input_list(user, "Which custom work do you want to continue?", "Custom work", choices)
	var/datum/custom_sprite_salon/session = choices[choice]
	if(QDELETED(session) || !user.is_holding(tool))
		return
	custom_sprite_salon_open_draft(session, tool, user)

/proc/custom_sprite_salon_open_draft(datum/custom_sprite_salon/session, obj/item/tool, mob/living/carbon/human/user)
	if(QDELETED(session) || !ishuman(user) || user.ckey != session.artist_ckey || !user.is_holding(tool) || !istype(tool, session.tool_type))
		return
	session.watch_artist(user)
	if(session.artist_ref?.resolve() != user)
		// A new body for the same player can't carry an approval given to the old one.
		if(session.state == SALON_AWAITING_APPROVAL)
			session.return_to_drafting()
		session.artist_ref = WEAKREF(user)
	session.tool_ref = WEAKREF(tool)
	session.editor.ui_interact(user)

/// The salon context: an artist-owned draft of another player's live appearance.
/datum/custom_sprite_editor/salon
	context = "salon"
	/// Salon session that owns this editor and its retained draft.
	var/datum/custom_sprite_salon/session
	/// A single brush-triggered clip, stopped when the editor closes.
	var/datum/looping_sound/salon_snipping/drawing_sound
	/// Earliest time another brush movement may start a work clip.
	COOLDOWN_DECLARE(drawing_sound_cooldown)
	/// Steady tattoo-machine ambience, separate from the varied needle bursts.
	var/datum/looping_sound/drawing_ambience

/datum/custom_sprite_editor/salon/New(datum/custom_sprite_salon/session)
	src.session = session
	..(GLOB.preferences_datums[session.artist_ckey], session.target, session.body_zone)

/datum/custom_sprite_editor/salon/Destroy()
	stop_drawing_sounds()
	session = null
	return ..()

/datum/custom_sprite_editor/salon/ui_close(mob/user)
	stop_drawing_sounds()
	return ..()

/// Brush activity is sent during a stroke; validate it without changing pixels or pushing UI data.
/datum/custom_sprite_editor/salon/proc/drawing_activity(mob/user, list/params)
	var/direction = params["dir"]
	var/x = params["x"]
	var/y = params["y"]
	if(user != session.artist() || session.state == SALON_APPLYING)
		return
	if(!workspace.valid_point_pair(list(x, y)) || x < 0 || x >= workspace.width || y < 0 || y >= workspace.height)
		return
	if(!istext(direction) || !(direction in workspace.layers[1]["data"]) || (direction in locked_directions()))
		return
	if(!workspace.is_point_allowed(x, y, direction) && !(params["erasing"] == TRUE && workspace.is_painted(x, y, direction)))
		return
	if(drawing_sound && drawing_sound.parent != user)
		stop_drawing_sounds()
	var/tattoo = session.tool_type == /obj/item/tattoo_machine
	if(!drawing_sound)
		var/sound_type = tattoo ? /datum/looping_sound/salon_snipping/drawing/tattoo : /datum/looping_sound/salon_snipping/drawing
		drawing_sound = new sound_type(user)
	if(COOLDOWN_FINISHED(src, drawing_sound_cooldown))
		drawing_sound.stop()
		drawing_sound.start()
		COOLDOWN_START(src, drawing_sound_cooldown, drawing_sound.mid_length)
	if(tattoo)
		if(!drawing_ambience)
			drawing_ambience = new /datum/looping_sound/salon_tattoo_ambience(user, TRUE)
		// Let the machine settle briefly after the last brush movement.
		addtimer(CALLBACK(src, PROC_REF(stop_drawing_ambience)), 3 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)

/datum/custom_sprite_editor/salon/proc/stop_drawing_ambience()
	QDEL_NULL(drawing_ambience)

/// Closing keeps the draft but silences both channels.
/datum/custom_sprite_editor/salon/proc/stop_drawing_sounds()
	stop_drawing_ambience()
	QDEL_NULL(drawing_sound)

/datum/custom_sprite_editor/salon/initial_package()
	return custom_style_copy_package(session.original["package"])

/// Guides show the recipient as they are dressed, so the artist sees the person they're working on.
/datum/custom_sprite_editor/salon/render_overlays()
	return custom_sprite_worn_overlays(session?.recipient())

/datum/custom_sprite_editor/salon/can_hide_underwear()
	return FALSE

/datum/custom_sprite_editor/salon/create_preview_body()
	var/mob/living/carbon/human/recipient = session.recipient_ref?.resolve()
	if(QDELETED(recipient))
		return null
	return custom_sprite_salon_dummy(recipient)

/datum/custom_sprite_editor/salon/emissives_allowed()
	return session.recipient_emissives

/// Base hair changes stay in the draft until the recipient approves the complete look.
/datum/custom_sprite_editor/salon/can_change_hair()
	return custom_style_hair_target(target)

/datum/custom_sprite_editor/salon/locked_directions()
	return session?.locked_directions()

/datum/custom_sprite_editor/salon/hair_context_problem(list/hair)
	return session.hair_problem(hair)

/datum/custom_sprite_editor/salon/can_edit(mob/user)
	return !closing && session && user?.ckey == session.artist_ckey && !CONFIG_GET(flag/disallow_custom_sprite_editing)

/datum/custom_sprite_editor/salon/draft_changed()
	..()
	session.draft_changed()

/datum/custom_sprite_editor/salon/context_act(action, list/params, mob/user)
	switch(action)
		if("drawing")
			drawing_activity(user, params)
			return FALSE
		if("saveDraft")
			save_error = null
			save_revision++
			return TRUE
		if("finishWork")
			transfer_notice = null
			transfer_error = session.propose(user)
			return TRUE
		if("closeEditor")
			SStgui.close_uis(src)
			return TRUE
		if("discardDraft")
			to_chat(session.recipient(), span_notice("[user] discarded the custom [session.label()] they were drawing for you."))
			qdel(session)
			return TRUE
	return FALSE

/datum/custom_sprite_editor/salon/context_ui_data()
	return list("canRestorePrevious" = FALSE, "recipientName" = session.recipient_name, "salonState" = session.state, "selfWork" = session.self_work)

#undef SALON_DRAFTING
#undef SALON_AWAITING_APPROVAL
#undef SALON_APPLYING
#undef SALON_COMPLETED
#undef SALON_PROMPT_TIMEOUT
#undef SALON_REQUEST_COOLDOWN
#undef SALON_APPLY_DURATION
#undef SALON_TRIMMING_FIRST_DELAY
#undef SALON_TRIMMING_GROW_MIN
#undef SALON_TRIMMING_GROW_MAX
#undef SALON_TRIMMING_WORKING_MAX
