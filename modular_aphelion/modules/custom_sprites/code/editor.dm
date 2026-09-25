/// Editing can be disabled without removing any saved appearance.
/datum/config_entry/flag/disallow_custom_sprite_editing

/datum/preference_middleware/custom_sprites
	action_delegations = list("open_custom_sprite_editor" = PROC_REF(open_editor))

/datum/preference_middleware/custom_sprites/get_ui_data(mob/user)
	preferences.load_custom_sprites()
	// An empty canvas saves as no drawing, so any saved drawing has paint on it.
	return list(
		"allow_custom_sprite_editing" = !CONFIG_GET(flag/disallow_custom_sprite_editing),
		"custom_marking_zones" = assoc_to_keys(preferences.custom_limb_markings),
	)

/datum/preference_middleware/custom_sprites/apply_to_human(mob/living/carbon/human/target, datum/preferences/preferences, visuals_only = FALSE)
	preferences.load_custom_sprites()
	var/allow_emissives = preferences.read_preference(/datum/preference/toggle/allow_emissives)
	target.dna.custom_hair = custom_sprite_appearance_drawing(preferences.custom_hair, allow_emissives)
	target.dna.custom_facial_hair = custom_sprite_appearance_drawing(preferences.custom_facial_hair, allow_emissives)
	target.dna.custom_limb_markings = null
	for(var/body_zone, drawing in preferences.custom_limb_markings)
		LAZYSET(target.dna.custom_limb_markings, body_zone, custom_sprite_appearance_drawing(drawing, allow_emissives))
	target.sync_custom_sprite_appearance()

/datum/preference_middleware/custom_sprites/pre_set_preference(mob/user, preference, value)
	// A style/species change must not leave an editor using the old palette or geometry.
	return !preferences.finish_custom_sprite_editors_for_change(user)

/// Setup actions that change the body or its markings outside set_preference save and close open editors first, as preference changes do.
/datum/preferences/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	var/static/list/body_actions = list("set_bodypart_aug", "set_bodypart_aug_style", "add_marking", "change_marking", "color_marking", "remove_marking", "change_emissive", "set_preset", "randomize_character")
	if((action in body_actions) && !finish_custom_sprite_editors_for_change(ui?.user))
		return TRUE
	return ..()

/datum/preference_middleware/custom_sprites/on_new_character(mob/user)
	preferences.load_custom_sprites()

/datum/preference_middleware/custom_sprites/proc/open_editor(list/params, mob/user)
	if(CONFIG_GET(flag/disallow_custom_sprite_editing) || user?.client != preferences.parent)
		return FALSE
	var/target = params["target"]
	var/body_zone = params["body_zone"]
	if(target == "markings" ? (!istext(body_zone) || !(body_zone in GLOB.custom_marking_zone_labels)) : (!custom_style_hair_target(target) || !isnull(body_zone)))
		return FALSE
	if(target == "markings")
		var/datum/custom_sprite_editor/markings/whole_body = markings_editor(body_zone)
		whole_body.ui_interact(user)
		return TRUE
	var/editor_key = custom_style_key(target, body_zone)
	var/datum/custom_sprite_editor/editor = preferences.custom_sprite_editors?[editor_key]
	if(!editor)
		editor = new(preferences, target, body_zone)
		LAZYSET(preferences.custom_sprite_editors, editor_key, editor)
	editor.ui_interact(user)
	return TRUE

/// The character's one whole-body markings editor, opened on a limb or moved to it.
/datum/preference_middleware/custom_sprites/proc/markings_editor(body_zone)
	var/datum/custom_sprite_editor/markings/editor = preferences.custom_sprite_editors?["markings"]
	if(editor)
		editor.focus_region(body_zone)
		return editor
	editor = new(preferences, body_zone)
	LAZYSET(preferences.custom_sprite_editors, "markings", editor)
	return editor

/**
 * One draft and its window. This base type is the character preferences context: it is bound
 * to its owner, slot and saved drawing, and saves to the character.
 *
 * Other contexts, such as the salon, reuse the same workspace, tools, palette, history,
 * blending, preview renderer, import and export by overriding the context hooks below.
 */
/datum/custom_sprite_editor
	/// Selects preferences or salon actions and window wording.
	var/context = "preferences"
	/// Supplies Custom swatches. In the preferences context it is also the saved character.
	var/datum/preferences/preferences
	/// Editable pixels, palette and undo history for this draft.
	var/datum/sprite_editor_workspace/custom_sprite/workspace
	/// Private dummy used to build guides and previews; released on close.
	var/mob/living/carbon/human/dummy/preview_body
	/// Drawing kind: hair, facial_hair or markings.
	var/target
	/// Edited limb or taur zone, or null for hair.
	var/body_zone
	/// Target and zone key in the preferences editor registry.
	var/editor_key
	/// Character slot bound when this editor opened.
	var/slot
	/// Most recently serialized workspace drawing used by saves and previews.
	var/list/draft
	/// Appearance identity of the last rendered preview.
	var/preview_hash
	/// Pending preview debounce timer, cancelled when the editor closes.
	var/preview_timer
	/// Prevents actions and duplicate saves during teardown.
	var/closing = FALSE
	/// Successful save counter used for the UI's acknowledgement flash.
	var/save_revision = 0
	/// Failure message from the last attempted save.
	var/save_error
	/// Effective brush color after any Custom color blending.
	var/selected_color
	/// Original Custom swatch, retained when blended colors coincide.
	var/selected_custom_color
	/// Brush blending mode: literal, hair or tint.
	var/color_mode = "literal"
	/// Chosen multiplier for Blend with color; white has no effect.
	var/custom_tint = "#ffffff"
	/// Direction -> native guide icon used by the eyedropper.
	var/list/guide_icons = list()
	/// Direction -> private guide image sent to the editor.
	var/list/guide_urls = list()
	/// Direction -> private preview image sent to the editor.
	var/list/preview_urls = list()
	/// Colors sampled from the current hair or native markings.
	var/list/sampled_palette
	/// Eyedropper colors retained as literal palette choices.
	var/list/guide_palette = list()
	/// The hair look the current guides and palette were built from.
	var/resources_hair
	/// The native markings the current guides and sampled palette were built from.
	var/resources_markings
	/// Whether guide geometry and images are available for this draft.
	var/resources_ready = FALSE
	/// Increments on every draft change. Dialogs that yield compare it before changing anything.
	var/draft_revision = 0
	/// An import or restoration waiting for the owner to confirm its preview.
	var/list/candidate
	/// Safe import or export failure message for the owner.
	var/transfer_error
	/// Import or export completion message for the owner.
	var/transfer_notice
	/// Whether guides, previews and the sampled palette include the base look's gradient.
	var/show_gradient = TRUE
	/// Drawing bounds as the body allows them, before any views are locked.
	var/list/unlocked_bounds
	/// Whether hair and parts that hang over the drawing are left out of the guide. Previews always show them.
	var/hide_parts = TRUE
	/// Whether underwear is left out of guides and previews.
	var/hide_underwear = FALSE
	/// Whether a previous saved style differs from the draft, as of the last preview refresh or save.
	var/can_restore_previous = FALSE
	/// Guides, the draw mask or the region map changed since the window last received static data.
	var/static_dirty = FALSE
	/// The view the window shows. Guides and previews are drawn for it at once, and for the others once shown.
	var/visible_direction = "2"
	/// The guide's look as the last rebuild captured it, flattened one view at a time.
	var/mutable_appearance/guide_appearance
	/// Hair and parts drawn over the body, captured with the guide, lowest layer first. Paint under them is hidden in game.
	var/list/cover_looks
	/// Direction -> 32 row strings marking which of cover_looks covers each canvas pixel.
	var/list/cover_rows = list()
	/// What cover_looks were built from, so their rows come from the shared cache.
	var/cover_key
	/// Hair guide shifts, applied in order: south by the hairstyle offset, then west and south by the species offset.
	var/list/guide_shift
	/// Direction -> TRUE for views whose guide predates the last rebuild.
	var/list/stale_guides = list()
	/// The previewed look for preview_hash, flattened one view at a time.
	var/mutable_appearance/preview_appearance
	/// Canvas width previews are flattened at.
	var/preview_width = 32
	/// Direction -> TRUE for views whose preview predates preview_hash.
	var/list/stale_previews = list()

/datum/custom_sprite_editor/New(datum/preferences/preferences, target, body_zone)
	src.preferences = preferences
	src.target = target
	src.body_zone = body_zone
	if(custom_style_hair_target(target))
		hide_parts = FALSE
	// Start the way character setup is already previewing the character.
	if(can_hide_underwear() && (preferences.preview_pref in list(PREVIEW_PREF_NAKED, PREVIEW_PREF_NAKED_AROUSED)))
		hide_underwear = TRUE
	editor_key = custom_style_key(target, body_zone)
	slot = preferences?.default_slot
	var/list/package = initial_package()
	preview_body = create_preview_body()
	workspace = create_workspace(package)
	workspace.owner_ref = WEAKREF(src)
	rebuild_resources(reuse_body = TRUE)
	selected_color = length(workspace.palette) ? workspace.palette[1] : null
	refresh_preview()

/datum/custom_sprite_editor/Destroy()
	SStgui.close_uis(src)
	QDEL_NULL(workspace)
	QDEL_NULL(preview_body)
	preferences = null
	draft = null
	guide_icons = null
	candidate = null
	return ..()

/// Context hook: the package the draft starts from.
/datum/custom_sprite_editor/proc/initial_package()
	return preferences.custom_style_saved_package(target, body_zone)

/// Context hook: the draft's workspace, built from the starting package.
/datum/custom_sprite_editor/proc/create_workspace(list/package)
	var/datum/sprite_editor_workspace/custom_sprite/new_workspace = new(package["drawing"], list(), null, null, body_zone == CUSTOM_MARKING_ZONE_TAUR ? CUSTOM_SPRITE_TAUR_WIDTH : 32)
	new_workspace.hair_context = package["hair"]
	new_workspace.markings_context = package["markings"]
	new_workspace.bake_tint()
	if(!package["drawing"] || target == "markings")
		new_workspace.tint = "#ffffff"
	return new_workspace

/// Context hook: a private body showing the appearance being drawn on, or null when unavailable.
/datum/custom_sprite_editor/proc/create_preview_body()
	var/mob/living/carbon/human/dummy/body = new
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	return body

/// Context hook: whether this destination may use emissive paint.
/datum/custom_sprite_editor/proc/emissives_allowed()
	return preferences.read_preference(/datum/preference/toggle/allow_emissives)

/**
 * Applies the context's current view locks to the drawing bounds.
 *
 * Locks can change while the window is open, so this runs on every update and before every action
 * rather than only when the preview body is rebuilt.
 *
 * Returns TRUE when the locks changed.
 */
/datum/custom_sprite_editor/proc/sync_locked_views(push = TRUE)
	if(!length(unlocked_bounds) || !islist(workspace.draw_bounds))
		return FALSE
	var/list/locked = locked_directions()
	var/changed = FALSE
	for(var/direction, bounds in unlocked_bounds)
		var/list/allowed = (direction in locked) ? list(0, 0, -1, -1) : bounds
		var/list/current = workspace.draw_bounds[direction]
		// A view with no drawable pixels has no box at all; none on both sides is no change.
		if(isnull(allowed) ? isnull(current) : compare_list(current, allowed))
			continue
		workspace.draw_bounds[direction] = allowed?.Copy()
		changed = TRUE
	if(changed && push)
		SStgui.update_uis(src)
	return changed

/// Context hook: the window's title. BYOND shows it until the interface draws its own, so the two match.
/datum/custom_sprite_editor/proc/window_title()
	if(target == "hair")
		return "Custom Hair"
	if(target == "facial_hair")
		return "Custom Facial Hair"
	var/label = GLOB.custom_marking_zone_labels[body_zone]
	return label ? "Custom [label] markings" : "Custom Markings"

/// Context hook: views that can't be painted right now, beyond the drawing's own bounds.
/datum/custom_sprite_editor/proc/locked_directions()
	return null

/// Context hook: whether this context may change the base hair look from inside the editor.
/datum/custom_sprite_editor/proc/can_change_hair()
	return custom_style_hair_target(target) && !!preferences

/// Context hook: why an imported hair look can't be used here, or null.
/datum/custom_sprite_editor/proc/hair_context_problem(list/hair)
	return preferences.custom_style_hair_problem(hair, target)

/// Context hook: the appearance guides and previews render, and any extra overlays to add.
/datum/custom_sprite_editor/proc/render_appearance(mob/living/carbon/human/body)
	if(custom_style_hair_target(target) || !hide_parts)
		return body
	return custom_sprite_limb_appearance(body)

/// Markings can hide parts that cover the body; hair editors always keep the full look visible.
/datum/custom_sprite_editor/proc/can_hide_parts()
	return !custom_style_hair_target(target)


/// Context hook: whether underwear can be left out of guides and previews.
/datum/custom_sprite_editor/proc/can_hide_underwear()
	return target == "markings"

/**
 * Takes wings, tails and other parts that hang over the limb off the preview body while the guide is drawn.
 *
 * Only the guide leaves them out: rebuild_resources() puts them back once the guides are rendered,
 * so previews still show the whole look. A taur body carries its own drawing, so it always stays.
 *
 * Returns the removed overlays, each mapped to the limb it came off, or null when nothing was removed.
 */
/datum/custom_sprite_editor/proc/hide_obstructing_parts()
	var/list/hidden
	for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
		for(var/datum/bodypart_overlay/mutant/part in LAZYCOPY(limb.bodypart_overlays))
			if(istype(part, /datum/bodypart_overlay/mutant/taur_body))
				continue
			limb.remove_bodypart_overlay(part, FALSE)
			LAZYSET(hidden, part, limb)
	if(hidden)
		preview_body.update_body_parts()
	return hidden

/datum/custom_sprite_editor/proc/render_overlays()
	return null

/// Context hook: called after every change to the draft.
/datum/custom_sprite_editor/proc/draft_changed()
	draft_revision++

/// Hook: actions a subtype handles itself, after the shared checks. Returns null for actions it leaves to the base.
/datum/custom_sprite_editor/proc/editor_act(action, list/params, datum/tgui/ui)
	return null

/// Context hook: extra actions owned by the context.
/datum/custom_sprite_editor/proc/context_act(action, list/params, mob/user)
	switch(action)
		if("save")
			var/datum/preferences/owner = preferences
			finish(TRUE)
			// Character setup marks which markings have a drawing.
			SStgui.update_uis(owner)
			return TRUE
		if("saveDraft")
			if(save_drawing())
				preferences.character_preview_view?.update_body()
				SStgui.update_uis(preferences)
			return TRUE
		if("discard")
			finish(FALSE)
			return TRUE
		if("restorePrevious")
			var/list/previous = restorable_package()
			if(!previous)
				return FALSE
			show_candidate(previous, "restore")
			return TRUE
	return FALSE

/// The previous saved style, or null when the draft already is that style.
/datum/custom_sprite_editor/proc/restorable_package()
	var/list/previous = preferences.custom_style_previous_package(target, body_zone)
	if(!previous || custom_style_matches(previous, current_package()))
		return null
	return previous

/// Context hook: extra window data owned by the context.
/datum/custom_sprite_editor/proc/context_ui_data()
	return list("canRestorePrevious" = can_restore_previous)

/// Works out whether Restore previous saved style is offered. Runs with the debounced preview and after saves, not on every window update.
/datum/custom_sprite_editor/proc/update_restorable()
	can_restore_previous = !!restorable_package()

/**
 * Rebuilds the preview body, guides, sampled palette and drawing bounds.
 *
 * Runs on opening, after the hair look changes through import or history, and when a closed
 * salon draft resumes. Heavyweight preview resources can be released while a window is closed.
 *
 * Returns:
 * - TRUE: Resources are ready.
 * - FALSE: The context has no body to draw on right now. The draft is kept.
 */
/datum/custom_sprite_editor/proc/rebuild_resources(reuse_body = FALSE)
	if(!reuse_body)
		QDEL_NULL(preview_body)
		preview_body = create_preview_body()
	resources_hair = json_encode(workspace.hair_context)
	resources_markings = json_encode(workspace.markings_context)
	static_dirty = TRUE
	if(!preview_body)
		release_resources()
		resources_ready = FALSE
		sampled_palette = list()
		workspace.draw_bounds = list()
		workspace.draw_mask = null
		refresh_custom_palette()
		return FALSE
	// Every view keeps its last guide and preview until it's drawn again.
	preview_hash = null
	preview_appearance = null
	for(var/direction in GLOB.custom_style_directions)
		stale_guides[direction] = TRUE
		stale_previews[direction] = TRUE
	if(!isnull(workspace.markings_context))
		apply_draft_base_markings()
	// Captured before parts are taken off for the guide: paint under them is covered whether or not the guide shows them.
	cover_looks = null
	cover_key = null
	if(target == "markings")
		var/list/key = list()
		cover_looks = custom_sprite_cover_looks(preview_body, key)
		cover_key = json_encode(key)
	cover_rows = list()
	// Everything taken off the body for the guides, mapped to its limb, to put back afterwards.
	var/list/hidden_overlays
	if(can_hide_parts() && hide_parts)
		hidden_overlays = hide_obstructing_parts()
	if(can_hide_underwear() && hide_underwear)
		preview_body.set_all_underwear_visibility(TRUE)
	if(custom_style_hair_target(target) && workspace.hair_context)
		// Hiding the gradient leaves the saved look alone; only this preview body drops it.
		var/list/context = workspace.hair_context
		if(!show_gradient)
			context = context.Copy()
			context["gradient_style"] = SPRITE_ACCESSORY_NONE
		custom_style_apply_hair_context(preview_body, context, update = FALSE, target = target)
	var/obj/item/bodypart/head/head = preview_body.get_bodypart(BODY_ZONE_HEAD)
	var/list/head_drawing = head?.custom_head_drawing(target)
	var/list/palette
	if(custom_style_hair_target(target))
		var/datum/sprite_accessory/hair/hairstyle = custom_style_hair_accessories(target)[target == "facial_hair" ? preview_body.facial_hairstyle : preview_body.hairstyle]
		palette = custom_sprite_sample_hair_palette(hairstyle, head, target)
		workspace.draw_bounds = custom_sprite_canvas_bounds(workspace.width)
		workspace.draw_mask = null
		head?.set_custom_head_drawing(target, null)
		preview_body.update_hair()
	else
		update_draw_area()
		palette = sample_marking_palette()
		var/hid_paint = FALSE
		for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
			// Hide paint only while rendering guides, retaining every donor layer's exact snapshot.
			for(var/datum/bodypart_overlay/custom_marking/marking in LAZYCOPY(limb.bodypart_overlays))
				LAZYSET(hidden_overlays, marking, limb)
				limb.remove_bodypart_overlay(marking, FALSE)
				hid_paint = TRUE
		// The limbs the body already drew still carry that paint until they're composed again.
		if(hid_paint)
			preview_body.update_body_parts()
	unlocked_bounds = deep_copy_list(workspace.draw_bounds)
	clip_stranded_paint()
	// Temporary view locks restrict edits, never the pixels retained by the draft.
	sync_locked_views(push = FALSE)
	sampled_palette = palette
	refresh_custom_palette()
	capture_guide()
	head?.set_custom_head_drawing(target, head_drawing)
	for(var/datum/bodypart_overlay/overlay as anything in hidden_overlays)
		var/obj/item/bodypart/limb = hidden_overlays[overlay]
		limb.add_bodypart_overlay(overlay, FALSE)
	if(hidden_overlays)
		preview_body.update_body_parts()
	resources_ready = TRUE
	return TRUE

/// Context hook: puts the draft's native base markings on the preview body.
/datum/custom_sprite_editor/proc/apply_draft_base_markings()
	custom_style_apply_base_markings(preview_body, body_zone, workspace.markings_context, emissives_allowed())
	preview_body.update_body()

/// Context hook: sets a markings draft's drawing bounds and mask from the preview body.
/datum/custom_sprite_editor/proc/update_draw_area()
	workspace.draw_bounds = custom_sprite_body_draw_bounds(preview_body, body_zone, workspace.width)
	workspace.draw_mask = custom_sprite_body_draw_mask(preview_body, body_zone, workspace.width)

/// Context hook: markings clip to the body, so paint stranded by a changed body or zone is dropped.
/datum/custom_sprite_editor/proc/clip_stranded_paint()
	if(target == "markings")
		workspace.clip_to_allowed()

/// Drops the guides and previews built from the preview body.
/datum/custom_sprite_editor/proc/release_resources()
	guide_icons = list()
	guide_urls = list()
	preview_urls = list()
	preview_hash = null
	guide_appearance = null
	preview_appearance = null
	cover_looks = null
	cover_key = null
	cover_rows = list()
	stale_guides = list()
	stale_previews = list()

/// Captures the guide's look from the prepared preview body and draws the visible view. Other views are drawn when shown.
/datum/custom_sprite_editor/proc/capture_guide()
	guide_appearance = new(render_appearance(preview_body))
	var/list/worn = render_overlays()
	if(length(worn))
		guide_appearance.overlays += worn
	guide_shift = null
	if(target == "hair")
		var/datum/sprite_accessory/hair/hairstyle = SSaccessories.hairstyles_list[preview_body.hairstyle]
		guide_shift = list(hairstyle?.y_offset || 0)
		if(LAZYFIND(preview_body.dna.species.offset_features, OFFSET_HAIR))
			guide_shift += list(preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_W], preview_body.dna.species.offset_features[OFFSET_HAIR][INDEX_Z])
	render_guide(visible_direction)

/// Draws one view of the guide the last rebuild captured. Guides are static data, so the window needs a full update afterwards.
/datum/custom_sprite_editor/proc/render_guide(direction)
	if(!guide_appearance)
		return FALSE
	var/icon/guide = custom_sprite_flat_icon(guide_appearance, text2num(direction), workspace.width)
	if(guide_shift)
		guide.Shift(SOUTH, guide_shift[1])
		if(length(guide_shift) > 1)
			guide.Shift(WEST, guide_shift[2])
			guide.Shift(SOUTH, guide_shift[3])
	guide_icons[direction] = guide
	guide_urls[direction] = publish_icon(guide)
	if(cover_looks)
		cover_rows[direction] = cover_rows_for(direction)
	stale_guides -= direction
	static_dirty = TRUE
	return TRUE

/// Context hook: one view's cover rows, read inside the view's own box before any lock so an unlocked view is right at once.
/datum/custom_sprite_editor/proc/cover_rows_for(direction)
	return custom_sprite_cover_rows(cover_looks, direction, workspace.width, -BODYPARTS_LAYER, cover_key, unlocked_bounds ? unlocked_bounds[direction] : null)

/// Draws one view of the preview captured for preview_hash.
/datum/custom_sprite_editor/proc/render_preview(direction)
	if(!preview_appearance)
		return FALSE
	preview_urls[direction] = custom_sprite_render_view(preview_appearance, text2num(direction), preview_width, CALLBACK(src, PROC_REF(publish_icon)))
	stale_previews -= direction
	return TRUE

/// Brings one view's guide and preview up to date. Returns TRUE when anything was drawn.
/datum/custom_sprite_editor/proc/render_view(direction)
	. = FALSE
	if(stale_guides[direction] && render_guide(direction))
		. = TRUE
	if(stale_previews[direction] && render_preview(direction))
		. = TRUE

/datum/custom_sprite_editor/proc/sample_marking_palette()
	var/list/colors = list()
	for(var/feature in list(FEATURE_MUTANT_COLOR, FEATURE_MUTANT_COLOR_TWO, FEATURE_MUTANT_COLOR_THREE))
		var/color = custom_sprite_color(preview_body.dna.features[feature])
		if(color)
			colors |= color
	var/list/shades = sample_marking_shades()
	if(!length(colors))
		return shades
	var/list/palette = colors.Copy()
	for(var/shade in shades)
		var/list/shade_rgb = rgb2num(shade)
		for(var/color in colors)
			var/list/color_rgb = rgb2num(color)
			palette |= rgb(shade_rgb[1] * color_rgb[1] / 255, shade_rgb[2] * color_rgb[2] / 255, shade_rgb[3] * color_rgb[3] / 255)
			if(length(palette) >= 15)
				return palette
	return palette

/datum/custom_sprite_editor/proc/sample_marking_shades()
	var/limb_zone = body_zone && (GLOB.custom_marking_hand_arms[body_zone] || body_zone)
	for(var/obj/item/bodypart/limb as anything in preview_body.bodyparts)
		if(limb_zone && limb.body_zone != limb_zone)
			continue
		for(var/marking_name in limb.markings)
			var/datum/body_marking/marking = GLOB.body_markings[marking_name]
			if(!marking)
				continue
			var/gender_suffix = limb.body_zone == BODY_ZONE_CHEST && marking.gendered ? (limb.is_dimorphic ? "_[limb.limb_gender]" : "_m") : ""
			var/digi = limb.bodyshape & BODYSHAPE_DIGITIGRADE ? "digitigrade_" : ""
			return custom_sprite_sample_palette(marking.icon, "[marking.icon_state]_[digi][limb.body_zone][gender_suffix]")
	return custom_sprite_sample_palette(null, null)

/datum/custom_sprite_editor/proc/publish_icon(icon/rendered)
	// Small, private previews live with this editor, without global asset/CDN registrations.
	return "data:image/png;base64,[icon2base64(rendered)]"

/datum/custom_sprite_editor/proc/can_edit(mob/user)
	return !closing && preferences && user?.client == preferences.parent && slot == preferences.default_slot && !CONFIG_GET(flag/disallow_custom_sprite_editing)

/datum/custom_sprite_editor/ui_state(mob/user)
	return GLOB.always_state

/datum/custom_sprite_editor/ui_status(mob/user, datum/ui_state/state)
	return can_edit(user) ? UI_INTERACTIVE : UI_CLOSE

/// Brings the open window in front of the player's other windows.
/datum/custom_sprite_editor/proc/bring_to_front(mob/user, datum/tgui/ui)
	if(ui.window)
		winset(user, ui.window.id, "focus=true")

/// Sends static data a partial update found changed. Runs a tick later, so the payload being built isn't re-entered.
/datum/custom_sprite_editor/proc/push_static_data()
	if(static_dirty)
		SStgui.update_uis(src)

/datum/custom_sprite_editor/ui_interact(mob/user, datum/tgui/ui)
	if(!can_edit(user))
		return
	// tgui's own refreshes pass their window; only an explicit open brings it forward.
	var/opening = isnull(ui)
	if(!resources_ready && rebuild_resources())
		refresh_preview(push = FALSE)
	if(static_dirty)
		ui ||= SStgui.get_open_ui(user, src)
		if(ui)
			// Guides, masks and the region map are static data, which an ordinary refresh leaves out.
			static_dirty = FALSE
			ui.process_status()
			if(ui.status <= UI_CLOSE)
				ui.close()
				return
			ui.send_full_update(always_instant = TRUE)
			if(opening)
				bring_to_front(user, ui)
			return
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		if(opening)
			bring_to_front(user, ui)
		return
	var/interface = "CustomMarkingsEditor"
	if(target == "hair")
		interface = "CustomHairEditor"
	else if(target == "facial_hair")
		interface = "CustomFacialHairEditor"
	ui = new(user, src, interface, window_title())
	ui.set_autoupdate(FALSE)
	static_dirty = FALSE
	ui.open()

/datum/custom_sprite_editor/ui_static_data(mob/user)
	// Static data is only built for a send, which carries every pending change.
	static_dirty = FALSE
	. = list()
	if(can_change_hair())
		.["hairStyles"] = available_hairstyles()
	if(can_change_markings())
		.["baseMarkingChoices"] = GLOB.body_markings_per_limb[body_zone]
		.["maxBaseMarkings"] = MAXIMUM_MARKINGS_PER_LIMB
	.["backgrounds"] = custom_sprite_background_tiles()
	.["defaultBackground"] = preferences?.read_preference(/datum/preference/choiced/background_state)
	.["guides"] = guide_urls
	.["drawMask"] = workspace.draw_mask
	.["coverMask"] = cover_rows
	.["coverParts"] = cover_looks ? custom_sprite_cover_labels(cover_looks) : list()

/datum/custom_sprite_editor/ui_data(mob/user)
	sync_locked_views(push = FALSE)
	// A lock change found here moved the mask, which only a full update carries. One being built takes it along.
	if(static_dirty && LAZYLEN(open_uis))
		addtimer(CALLBACK(src, PROC_REF(push_static_data)), 0, TIMER_UNIQUE)
	var/list/editor_data = workspace.sprite_editor_ui_data()
	var/list/custom_palette = preferences?.read_preference(/datum/preference/custom_sprite_palette) || list()
	// Paint/history admission must not add swatches; only style shades and explicit guide picks do.
	editor_data["serverPalette"] = (sampled_palette | guide_palette) & workspace.palette
	editor_data["serverSelectedColor"] = selected_color
	var/list/data = list("editorData" = editor_data, "context" = context, "customTint" = custom_tint, "displayTint" = custom_palette_tint(), "colorMode" = color_mode, "emissive" = workspace.emissive, "emissiveAllowed" = emissives_allowed(), "saveRevision" = save_revision, "saveError" = save_error, "customPalette" = custom_palette, "availableColors" = workspace.palette, "maxCustomColors" = CUSTOM_SPRITE_MAX_CUSTOM_COLORS, "previews" = preview_urls, "edited" = workspace.edited_directions, "drawBounds" = workspace.draw_bounds, "bodyZone" = body_zone, "bodyZoneLabel" = GLOB.custom_marking_zone_labels[body_zone], "resourcesReady" = resources_ready, "transferError" = transfer_error, "transferNotice" = transfer_notice, "visibleView" = visible_direction)
	if(custom_style_hair_target(target))
		data["hairStyle"] = workspace.hair_context?["style"]
		data["hairColor"] = workspace.hair_context?["color"]
		data["canChangeHair"] = can_change_hair()
		data["hasGradient"] = workspace.hair_context?["gradient_style"] && workspace.hair_context["gradient_style"] != SPRITE_ACCESSORY_NONE
		data["showGradient"] = show_gradient
	data["lockedDirections"] = locked_directions()
	if(can_change_markings())
		data["baseMarkings"] = base_markings()
	data["canChangeMarkings"] = can_change_markings()
	data["canHideParts"] = can_hide_parts()
	data["hideParts"] = hide_parts
	data["canHideUnderwear"] = can_hide_underwear()
	data["hideUnderwear"] = hide_underwear
	// TGUI merges updates, so an absent candidate must explicitly clear the previous preview.
	data["candidate"] = candidate ? list("source" = candidate["source"], "previews" = candidate["previews"], "summary" = candidate["summary"]) : null
	return data + context_ui_data()

/datum/custom_sprite_editor/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(. || !can_edit(ui.user))
		return
	// A mirror can be picked up or dropped while this window is open.
	sync_locked_views(push = FALSE)
	var/handled = editor_act(action, params, ui)
	if(!isnull(handled))
		return handled
	switch(action)
		if("setView")
			var/direction = params["dir"]
			if(!(direction in GLOB.custom_style_directions) || direction == visible_direction)
				return FALSE
			visible_direction = direction
			render_view(direction)
			return TRUE
		if("selectColor")
			if(!workspace.is_valid_color(params["color"]))
				return FALSE
			selected_color = LOWER_TEXT(copytext(params["color"], 1, 8))
			selected_custom_color = null
			// The window picked this swatch itself; echoing it back would resend the whole canvas.
			return FALSE
		if("selectCustomColor")
			var/color = custom_sprite_color(params["color"])
			if(!(color in preferences.read_preference(/datum/preference/custom_sprite_palette)))
				return FALSE
			var/transformed = custom_sprite_tint_color(color, custom_palette_tint())
			if(!(transformed in workspace.palette))
				return FALSE
			selected_custom_color = color
			selected_color = transformed
			return TRUE
		if("setBaseMarking")
			var/name = params["name"]
			if(!can_change_markings() || !isnum(params["index"]) || !istext(name) || !(name in GLOB.body_markings_per_limb[body_zone]))
				return FALSE
			if(custom_style_marking_data(workspace.markings_context)[name])
				return FALSE
			return write_base_marking(params["index"], name, null)
		if("addBaseMarking")
			var/list/markings = custom_style_marking_data(workspace.markings_context)
			if(!can_change_markings() || length(markings) >= MAXIMUM_MARKINGS_PER_LIMB)
				return FALSE
			var/list/choices = GLOB.body_markings_per_limb[body_zone].Copy()
			for(var/name in markings)
				choices -= name
			if(!length(choices))
				return FALSE
			return write_base_marking(null, choices[1], default_marking_color(choices[1]))
		if("removeBaseMarking")
			if(!can_change_markings() || !isnum(params["index"]))
				return FALSE
			return write_base_marking(params["index"], null, null)
		if("pickBaseMarkingColor")
			var/index = params["index"]
			if(!can_change_markings() || !isnum(index))
				return FALSE
			var/list/entries = base_markings()
			if(index < 1 || index > length(entries))
				return FALSE
			var/list/entry = entries[index]
			var/color = tgui_color_picker(ui.user, "Choose a color for [entry["name"]].", "Limb markings", entry["color"])
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			// The list may have changed while the picker was open.
			entries = base_markings()
			if(index > length(entries) || entries[index]["name"] != entry["name"])
				return FALSE
			return write_base_marking(index, entry["name"], custom_sprite_color(color))
		if("toggleParts")
			if(!can_hide_parts())
				return FALSE
			hide_parts = !hide_parts
			rebuild_resources()
			refresh_preview(push = FALSE)
			return TRUE
		if("toggleUnderwear")
			if(!can_hide_underwear())
				return FALSE
			hide_underwear = !hide_underwear
			rebuild_resources()
			refresh_preview(push = FALSE)
			return TRUE
		if("toggleGradient")
			if(!custom_style_hair_target(target))
				return FALSE
			show_gradient = !show_gradient
			rebuild_resources()
			refresh_preview(push = FALSE)
			return TRUE
		if("setHairStyle")
			var/list/hair = workspace.hair_context?.Copy()
			if(!can_change_hair() || !hair || !istext(params["style"]) || params["style"] == hair["style"])
				return FALSE
			hair["style"] = params["style"]
			apply_hair_context(hair, "Change hairstyle")
			return TRUE
		if("pickHairColor")
			var/list/hair = workspace.hair_context?.Copy()
			if(!can_change_hair() || !hair)
				return FALSE
			var/color = tgui_color_picker(ui.user, "Choose this character's base hair color.", "Hair color", hair["color"] || "#000000")
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			// The draft may have moved on while the picker was open.
			hair = workspace.hair_context?.Copy()
			if(!hair || custom_style_normal_color(color) == hair["color"])
				return FALSE
			hair["color"] = custom_style_normal_color(color)
			apply_hair_context(hair, "Change hair color")
			return TRUE
		if("sampleGuide")
			return sample_guide(params["dir"], params["x"], params["y"])
		if("savePaletteColor")
			if(!workspace.is_valid_color(params["color"]))
				return FALSE
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors | LOWER_TEXT(copytext(params["color"], 1, 8)))
		if("addPaletteColor")
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			if(length(colors) >= CUSTOM_SPRITE_MAX_CUSTOM_COLORS)
				return FALSE
			var/color = tgui_color_picker(ui.user, "Choose a color to save for all your characters.", "Custom palette", selected_color || "#ffffff")
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors | custom_sprite_color(color))
		if("removePaletteColor")
			var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
			return set_custom_palette(colors - custom_sprite_color(params["color"]))
		if("editPaletteColor")
			var/old_color = custom_sprite_color(params["color"])
			if(!(old_color in preferences.read_preference(/datum/preference/custom_sprite_palette)))
				return FALSE
			var/color = tgui_color_picker(ui.user, "Adjust this saved color for all your characters.", "Custom palette", old_color)
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			return edit_custom_palette_color(old_color, custom_sprite_color(color))
		if("spriteEditorCommand")
			switch(params["command"])
				if("transaction")
					// A refused stroke still resends the canvas, so the window drops what it drew ahead of the server.
					if(!workspace.new_transaction(params["transaction"]))
						return TRUE
				if("undo")
					var/history_length = length(workspace.undo_stack)
					workspace.undo(params["count"])
					if(length(workspace.undo_stack) == history_length)
						return TRUE
				if("redo")
					var/history_length = length(workspace.redo_stack)
					workspace.redo(params["count"])
					if(length(workspace.redo_stack) == history_length)
						return TRUE
				else
					return FALSE
			if((workspace.hair_context && resources_hair != json_encode(workspace.hair_context)) || (!isnull(workspace.markings_context) && resources_markings != json_encode(workspace.markings_context)))
				rebuild_resources()
		if("clear")
			if(!workspace.clear_direction(params["dir"]))
				return FALSE
		if("setEmissive")
			var/direction = params["dir"]
			var/enabled = params["enabled"]
			if(!istext(direction) || !(direction in workspace.emissive) || !isnum(enabled) || !(enabled in list(TRUE, FALSE)) || (enabled && !emissives_allowed()))
				return FALSE
			if(workspace.emissive[direction] == enabled)
				return TRUE
			workspace.emissive = workspace.emissive.Copy()
			workspace.emissive[direction] = enabled
		if("pickTint")
			var/color = tgui_color_picker(ui.user, "Choose a color to blend with Custom palette brushes.", "Custom palette blending", custom_tint)
			if(!can_edit(ui.user) || !custom_sprite_color(color))
				return FALSE
			custom_tint = custom_sprite_color(color)
			color_mode = "tint"
			refresh_custom_palette()
			return TRUE
		if("setColorMode")
			var/mode = params["mode"]
			if(!(mode in list("literal", "hair", "tint")) || (mode == "hair" && !custom_style_hair_target(target)))
				return FALSE
			if(mode == color_mode)
				return TRUE
			color_mode = mode
			refresh_custom_palette()
			return TRUE
		if("exportStyle")
			transfer_notice = null
			transfer_error = custom_style_send(ui.user.client, current_package())
			if(!transfer_error)
				transfer_notice = "Style exported."
			return TRUE
		if("importStyle")
			begin_import(ui.user)
			return TRUE
		if("confirmCandidate")
			if(!apply_candidate())
				return TRUE
		if("cancelCandidate")
			candidate = null
			return TRUE
		if("dismissTransfer")
			transfer_error = null
			transfer_notice = null
			return TRUE
		else
			return context_act(action, params, ui.user)
	draft_changed()
	preview_timer = addtimer(CALLBACK(src, PROC_REF(refresh_preview)), 0.6 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_STOPPABLE)
	return TRUE

/// Prefer current paint over the retained native guide, including strokes newer than the browser's view.
/datum/custom_sprite_editor/proc/sample_guide(direction, x, y)
	if(!istext(direction) || !(direction in workspace.layers[1]["data"]) || !workspace.valid_point_pair(list(x, y)) || x < 0 || x >= workspace.width || y < 0 || y >= workspace.height)
		return FALSE
	var/list/frame = workspace.layers[1]["data"][direction]
	var/list/channels = split_color(frame[y + 1][x + 1])
	if(!channels[4])
		if(stale_guides[direction])
			render_guide(direction)
		var/icon/guide = guide_icons[direction]
		var/pixel = guide?.GetPixel(x + 1, workspace.height - y)
		if(!pixel)
			return FALSE
		channels = split_color(pixel)
		if(!channels[4])
			return FALSE
	var/color = LOWER_TEXT(rgb(channels[1], channels[2], channels[3]))
	if(!(color in workspace.palette))
		workspace.update_palette(list(color) | sampled_palette | transformed_custom_palette())
		if(!(color in workspace.palette))
			return FALSE
	selected_color = color
	selected_custom_color = null
	guide_palette = (guide_palette | color) & workspace.palette
	return TRUE

/// Brush effects are editor state, never a mutation of existing drawing pixels.
/datum/custom_sprite_editor/proc/custom_palette_tint()
	if(color_mode == "tint")
		return custom_tint
	if(color_mode == "hair")
		if(!preview_body)
			return workspace.hair_context?["color"]
		var/obj/item/bodypart/head/head = preview_body.get_bodypart(BODY_ZONE_HEAD)
		return target == "facial_hair" ? head?.facial_hair_color : head?.get_rendered_hair_color()
	return null

/datum/custom_sprite_editor/proc/transformed_custom_palette()
	var/list/colors = list()
	var/tint = custom_palette_tint()
	for(var/color in preferences?.read_preference(/datum/preference/custom_sprite_palette))
		colors |= custom_sprite_tint_color(color, tint)
	return colors

/// Whether this context may change the limb's own markings from inside the editor.
/datum/custom_sprite_editor/proc/can_change_markings()
	return target == "markings" && body_zone && (body_zone in GLOB.body_markings_per_limb)

/// This limb's native markings in layer order, as the editor's own control shows them.
/datum/custom_sprite_editor/proc/base_markings()
	var/list/entries = list()
	var/index = 0
	for(var/list/entry as anything in workspace.markings_context)
		index++
		entries += list(list("index" = index, "name" = entry["name"], "color" = entry["color"]))
	return entries

/// Rewrites this draft's native markings, keeping their order and leaving the live body alone.
/datum/custom_sprite_editor/proc/write_base_marking(index, name, color)
	if(!can_change_markings())
		return FALSE
	var/list/entries = custom_style_rewrite_markings(workspace.markings_context, index, name, color)
	if(isnull(entries) || !workspace.replace_drawing(workspace.serialize_drawing(), workspace.hair_context, "Change base markings", new_markings_context = entries))
		return FALSE
	draft_changed()
	rebuild_resources()
	refresh_preview(push = FALSE)
	return TRUE

/// A new base marking's starting color, from the body being drawn on rather than the setup preview.
/datum/custom_sprite_editor/proc/default_marking_color(name)
	var/datum/body_marking/marking = GLOB.body_markings[name]
	var/list/features = list(
		FEATURE_MUTANT_COLOR = preview_body?.dna.features[FEATURE_MUTANT_COLOR],
		FEATURE_MUTANT_COLOR_TWO = preview_body?.dna.features[FEATURE_MUTANT_COLOR_TWO],
		FEATURE_MUTANT_COLOR_THREE = preview_body?.dna.features[FEATURE_MUTANT_COLOR_THREE],
		FEATURE_SKIN_COLOR = skintone2hex(preview_body?.skin_tone),
	)
	return marking.get_default_color(features, preview_body?.dna.species)

/**
 * Rewrites a limb's native marking records. Markings are stored by name, so one limb can't wear
 * the same marking twice, and their order is kept.
 *
 * Arguments:
 * - entries: Ordered records.
 * - index: Which marking to act on, or null when adding.
 * - name: The marking to use, or null to remove the one at `index`.
 * - color: A new color, or null to keep the marking's current one.
 *
 * Returns the new ordered records, or null when there's no marking at `index`.
 */
/proc/custom_style_rewrite_markings(list/entries, index, name, color)
	var/list/markings = custom_style_marking_data(entries)
	var/list/rebuilt = list()
	var/position = 0
	var/handled = FALSE
	for(var/entry, marking in markings)
		position++
		if(position != index)
			rebuilt[entry] = marking
			continue
		handled = TRUE
		if(!name)
			continue
		rebuilt[name] = list(color || marking[1], marking[2])
	if(!handled)
		if(isnull(index) && name)
			rebuilt[name] = list(color, FALSE)
		else
			return null
	return custom_style_marking_entries(rebuilt)

/// Hairstyles this character may pick from the editor's own base-hair control.
/datum/custom_sprite_editor/proc/available_hairstyles()
	/// Accessory choices are fixed after initialization and shared by both editor contexts.
	var/static/list/choices_by_target
	var/list/choices = LAZYACCESS(choices_by_target, target)
	if(isnull(choices))
		var/datum/preference/choiced/entry = GLOB.preference_entries[GLOB.custom_style_hair_preferences[target]["style"]]
		choices = sort_list(entry.get_choices())
		LAZYSET(choices_by_target, target, choices)
	return choices

/**
 * Swaps the base hair look under the drawing as one undoable action.
 *
 * A recolor of the same hairstyle carries painted hair shades to the matching new shade, so the
 * drawing keeps its relationship to the hair. Custom palette colors and unrelated paint stay put.
 *
 * Returns TRUE when the look changed; otherwise `transfer_error` says why.
 */
/datum/custom_sprite_editor/proc/apply_hair_context(list/hair, name)
	transfer_error = hair_context_problem(hair)
	if(transfer_error)
		return FALSE
	var/list/drawing = workspace.serialize_drawing()
	var/list/color_map = custom_style_hair_color_map(workspace.hair_context, hair, preferences?.read_preference(/datum/preference/custom_sprite_palette), target)
	var/list/recolored = color_map ? custom_style_recolor_drawing(drawing, color_map) : drawing
	if(isnull(recolored) && drawing)
		transfer_error = "This drawing couldn't be recolored. Save or reopen the editor, then try again."
		return FALSE
	if(!workspace.replace_drawing(recolored, hair, name, TRUE))
		transfer_error = "This change and your undo history need more than [CUSTOM_SPRITE_MAX_COLORS] colors. Save or reopen the editor, then try again."
		return FALSE
	draft_changed()
	rebuild_resources()
	refresh_preview(push = FALSE)
	return TRUE

/datum/custom_sprite_editor/proc/refresh_custom_palette()
	var/list/available = sampled_palette | transformed_custom_palette()
	// An unpainted guide brush is still active even though no drawing/history pixel uses it yet, so it goes first.
	if(!selected_custom_color && selected_color)
		available = list(selected_color) | available
	// The rest fill whatever room the drawing leaves, sampled shades before Custom colors.
	workspace.update_palette(available)
	if(selected_custom_color)
		var/transformed = custom_sprite_tint_color(selected_custom_color, custom_palette_tint())
		if((selected_custom_color in preferences?.read_preference(/datum/preference/custom_sprite_palette)) && (transformed in workspace.palette))
			selected_color = transformed
		else
			selected_custom_color = null
	if(!(selected_color in workspace.palette))
		selected_color = length(workspace.palette) ? workspace.palette[1] : null

/// Account colors save immediately; discarding a character drawing does not discard its palette.
/datum/custom_sprite_editor/proc/set_custom_palette(list/colors)
	var/datum/preference/preference = GLOB.preference_entries[/datum/preference/custom_sprite_palette]
	if(!preference.is_valid(colors, preferences) || json_encode(colors) == json_encode(preferences.read_preference(preference.type)))
		return FALSE
	preferences.update_preference(preference, colors)
	preferences.save_preferences()
	for(var/datum/custom_sprite_editor/editor as anything in preferences.custom_sprite_open_editors())
		// A full drawing keeps its admitted colors; other saved swatches remain visible but disabled.
		editor.refresh_custom_palette()
		SStgui.update_uis(editor)
	return TRUE

/**
 * Replaces one saved Custom swatch with another color, keeping its place in the palette.
 *
 * Like removal, this never recolors paint: pixels already drawn with the old swatch keep it.
 * Brushes in open editors that were using the old swatch follow it to the new color. Choosing a
 * color that's already saved folds the two swatches into one.
 *
 * The picker yields, so the palette is read again here rather than trusted from before it opened.
 *
 * Returns TRUE when the palette changed.
 */
/datum/custom_sprite_editor/proc/edit_custom_palette_color(old_color, new_color)
	var/list/colors = preferences.read_preference(/datum/preference/custom_sprite_palette)
	var/index = colors.Find(old_color)
	if(!index || new_color == old_color)
		return FALSE
	if(new_color in colors)
		colors = colors - old_color
	else
		colors = colors.Copy()
		colors[index] = new_color
	for(var/datum/custom_sprite_editor/editor as anything in preferences.custom_sprite_open_editors())
		if(editor.selected_custom_color == old_color)
			editor.selected_custom_color = new_color
	return set_custom_palette(colors)

/// Every editor using this account's Custom swatches, including a retained salon draft.
/datum/preferences/proc/custom_sprite_open_editors()
	. = list()
	for(var/_editor_target, editor in custom_sprite_editors)
		. += editor
	for(var/datum/custom_sprite_salon/session as anything in custom_sprite_salon_sessions_for(parent?.ckey))
		if(session.editor)
			. += session.editor

/// Timer callbacks push immediately; synchronous UI actions let TGUI send their single final update.
/datum/custom_sprite_editor/proc/refresh_preview(push = TRUE)
	preview_timer = null
	if(closing || !resources_ready)
		return
	draft = workspace.serialize_drawing()
	update_restorable()
	var/new_hash = custom_sprite_hash(draft)
	if(preview_hash == new_hash)
		return
	adopt_preview(capture_preview(draft, workspace.hair_context), new_hash, push)

/// Takes a newly captured preview look: the visible view is drawn now, the others when shown.
/datum/custom_sprite_editor/proc/adopt_preview(mutable_appearance/look, hash, push)
	preview_appearance = look
	preview_width = custom_sprite_preview_width(preview_body)
	preview_hash = hash
	for(var/direction in GLOB.custom_style_directions)
		stale_previews[direction] = TRUE
	render_preview(visible_direction)
	if(push)
		SStgui.update_uis(src)

/**
 * Puts a drawing on the preview body and captures how it looks, for flattening one view at a time.
 *
 * The preview body keeps the given drawing afterwards. Other base looks are restored to the
 * draft before returning, so resources stay consistent with the guides.
 */
/datum/custom_sprite_editor/proc/capture_preview(list/drawing, list/hair, list/markings)
	var/hair_swapped = custom_style_hair_target(target) && hair && json_encode(hair) != json_encode(workspace.hair_context)
	var/markings_swapped = !isnull(markings) && json_encode(markings) != json_encode(workspace.markings_context)
	custom_sprite_apply_round_style(preview_body, list("target" = target, "zone" = body_zone, "drawing" = drawing, "hair" = hair_swapped ? hair : null, "markings" = markings_swapped ? markings : null), emissives_allowed())
	// Hair-only updates don't rebuild the underwear that was hidden for the guides.
	if(custom_style_hair_target(target))
		preview_body.update_body()
	var/mutable_appearance/look = custom_sprite_preview_appearance(preview_body, render_overlays())
	if(hair_swapped)
		custom_style_apply_hair_context(preview_body, workspace.hair_context, update = FALSE, target = target)
	if(markings_swapped)
		custom_style_apply_base_markings(preview_body, body_zone, workspace.markings_context, emissives_allowed())
		preview_body.update_body()
	return look

/// All four views' data URLs of the preview body wearing a drawing, for import and restore previews.
/datum/custom_sprite_editor/proc/render_previews(list/drawing, list/hair, list/markings)
	return custom_sprite_render_views(capture_preview(drawing, hair, markings), custom_sprite_preview_width(preview_body), CALLBACK(src, PROC_REF(publish_icon)))

/// Closing keeps the unsaved draft and its history; only saving writes. Preview resources are rebuilt on reopening.
/datum/custom_sprite_editor/ui_close(mob/user)
	if(preview_timer)
		deltimer(preview_timer)
		preview_timer = null
	candidate = null
	QDEL_NULL(preview_body)
	release_resources()
	resources_ready = FALSE
	// The window opens on the Front view again.
	visible_direction = "2"

/datum/custom_sprite_editor/proc/current_package()
	return custom_style_package(target, body_zone, workspace.serialize_drawing(), workspace.hair_context, workspace.markings_context)

/datum/custom_sprite_editor/proc/save_drawing()
	var/error = preferences.commit_custom_style(current_package(), slot, length(workspace.unsaved_rotations()) > 0)
	if(error)
		save_error = "[error] Your drawing is kept in this session. Press Ctrl+S to retry."
		SStgui.update_uis(src)
		return FALSE
	workspace.mark_saved()
	update_restorable()
	save_error = null
	save_revision++
	return TRUE

/datum/custom_sprite_editor/proc/finish(save_changes = TRUE)
	if(closing)
		return
	if(save_changes && preferences && preferences.default_slot == slot && !save_drawing())
		return
	closing = TRUE
	if(preferences)
		LAZYREMOVE(preferences.custom_sprite_editors, editor_key)
	SStgui.close_uis(src)
	preferences?.refresh_custom_sprite_preview()
	qdel(src)

/**
 * Imports a style file into a confirmable preview. Sleeps while the file dialog is open.
 *
 * Nothing in the draft or preferences changes here. After the dialog returns, ownership, slot,
 * context and draft revision are all checked again before the file is even considered.
 */
/datum/custom_sprite_editor/proc/begin_import(mob/user)
	var/revision = draft_revision
	var/owner_slot = slot
	transfer_error = null
	transfer_notice = null
	candidate = null
	var/list/result = custom_style_receive(user)
	if(QDELETED(src))
		return
	if(!can_edit(user) || revision != draft_revision || owner_slot != slot)
		transfer_error = "The drawing changed while you were choosing a file. Nothing was imported."
	else if(result?["error"])
		transfer_error = result["error"]
	else if(result && !preview_received(result))
		log_game("[key_name(user)] had a custom style import rejected ([result["bytes"]] bytes): [transfer_error]")

/// Previews a received style file. Returns FALSE with transfer_error saying why it can't replace this draft.
/datum/custom_sprite_editor/proc/preview_received(list/result)
	var/list/package = result["package"]
	if(result["body"])
		// A whole-body file offers this drawing's own region, when it has one.
		package = body_zone && result["body"][body_zone]
		if(!package)
			transfer_error = body_zone ? "That whole-body style has no [LOWER_TEXT(GLOB.custom_marking_zone_labels[body_zone])] markings." : "That style is for whole-body markings, not this drawing."
			return FALSE
	else if(result["legacy"])
		package = custom_style_package(target, body_zone, package["drawing"], workspace.hair_context)
	return show_candidate(package, "import")

/// Returns why a package can't replace this draft, or null when it can.
/datum/custom_sprite_editor/proc/candidate_problem(list/package)
	if(package["target"] != target || package["zone"] != body_zone)
		var/label = custom_style_hair_target(package["target"]) ? (package["target"] == "facial_hair" ? "facial hair" : "hair") : "[LOWER_TEXT(GLOB.custom_marking_zone_labels[package["zone"]])] markings"
		return "That style is for [label], not this drawing."
	if(!resources_ready)
		return "The preview isn't available right now."
	var/list/bounds = workspace.draw_bounds
	if(custom_style_hair_target(target))
		var/hair_problem = hair_context_problem(package["hair"])
		if(hair_problem)
			return hair_problem
		bounds = custom_sprite_canvas_bounds(workspace.width)
	if(custom_style_has_emission(package["drawing"]) && !emissives_allowed())
		return "This style glows, but emissive appearance is disabled for this character."
	if(!emissives_allowed())
		for(var/list/entry as anything in package["markings"])
			if(entry["emissive"])
				return "This style has glowing base markings, but emissive appearance is disabled for this character."
	var/list/drawing = package["drawing"]
	if(drawing && custom_sprite_width(drawing) > workspace.width)
		return "This style needs the wider taur canvas."
	drawing = custom_sprite_resize_drawing(drawing, workspace.width)
	var/outside = custom_style_paint_outside(drawing, bounds, custom_style_hair_target(target) ? null : workspace.draw_mask)
	if(outside)
		return "The [outside] view has paint outside the area this [custom_style_hair_target(target) ? "hairstyle" : "body zone"] allows."
	return null

/datum/custom_sprite_editor/proc/show_candidate(list/package, source)
	var/problem = candidate_problem(package)
	if(problem)
		transfer_error = problem
		return FALSE
	// Preview the same centered pixels that replacement will put into the workspace.
	package = package.Copy()
	package["drawing"] = custom_sprite_resize_drawing(package["drawing"], workspace.width)
	var/list/hair = package["hair"]
	var/summary = hair ? "[hair["style"]], [hair["color"]]" : null
	candidate = list("package" = custom_style_copy_package(package), "source" = source, "revision" = draft_revision, "summary" = summary, "previews" = render_previews(package["drawing"], hair, package["markings"]))
	// The body now shows the candidate; the next refresh restores the draft.
	preview_hash = null
	refresh_preview(push = FALSE)
	return TRUE

/// Replaces the draft with the confirmed candidate as one undoable action.
/datum/custom_sprite_editor/proc/apply_candidate()
	if(!candidate)
		return FALSE
	var/list/package = candidate["package"]
	var/source = candidate["source"]
	if(candidate["revision"] != draft_revision)
		candidate = null
		transfer_error = "The drawing changed after the preview. Import the style again."
		return FALSE
	candidate = null
	transfer_error = candidate_problem(package)
	if(transfer_error)
		return FALSE
	var/list/before = workspace.last_transaction()
	if(!workspace.replace_drawing(package["drawing"], package["hair"], source == "restore" ? "Restore saved style" : "Import style", custom_style_hair_target(target), package["markings"]))
		transfer_error = "This style and your undo history need more than [CUSTOM_SPRITE_MAX_COLORS] colors. Save or reopen the editor, then import again."
		return FALSE
	var/list/applied = workspace.last_transaction()
	// Saving keeps the replaced style as the previous one, unless the import is undone first.
	if(context == "preferences" && applied != before)
		applied["rotate"] = TRUE
	if(resources_hair != json_encode(workspace.hair_context) || resources_markings != json_encode(workspace.markings_context))
		rebuild_resources()
	else
		refresh_custom_palette()
	transfer_notice = source == "restore" ? "Previous saved style restored. Save to keep it." : "Style imported."
	return TRUE
