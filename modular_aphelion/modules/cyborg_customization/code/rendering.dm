/// Every borg's part image holder, so a viewer's preference or a config reload reaches them all
GLOBAL_LIST_EMPTY(cyborg_customization_holders)

/// Diagonals deterministically use the north/south component, then east/west.
/proc/cyborg_cardinal_direction(direction)
	if(direction & NORTH)
		return NORTH
	if(direction & SOUTH)
		return SOUTH
	if(direction & EAST)
		return EAST
	return WEST

/// Pure geometry shared by creator/live rendering. Input has already been normalized.
/proc/cyborg_resolve_placement(list/entry, direction, pose, arousal, mirrored = FALSE, wide = FALSE)
	var/cardinal = cyborg_cardinal_direction(direction)
	var/direction_key = LOWER_TEXT(dir2text(cardinal))
	var/pose_key = "[pose]_[direction_key]"
	var/list/advanced = entry["advanced"]
	var/list/directional = advanced[pose_key] || advanced[direction_key]
	var/list/override = directional?["arousal"]?[arousal]
	var/list/resolved = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "priority" = 5)
	for(var/field in resolved)
		if(!isnull(directional?[field]))
			resolved[field] = directional[field]
		if(!isnull(override?[field]))
			resolved[field] = override[field]
	var/group = cardinal == NORTH ? "north" : cardinal == SOUTH ? "south" : "side"
	var/list/base = wide ? (entry["placement_groups"]?[group] || entry) : entry
	resolved["pixel_x"] += base["pixel_x"] * (mirrored ? -1 : 1)
	resolved["pixel_y"] += base["pixel_y"]
	resolved["rotation"] += base["rotation"] * (mirrored ? -1 : 1)
	resolved["scale"] = entry["scale"]
	if(!isnull(override?["scale"]))
		resolved["scale"] *= override["scale"]
	else if(!isnull(directional?["scale"]))
		resolved["scale"] *= directional["scale"]
	return resolved

/proc/cyborg_mirror_placement(list/descriptor, list/entry, direction)
	return (TRAIT_R_WIDE in descriptor["features"]) && entry["mirror_sides"] && cyborg_cardinal_direction(direction) == WEST

/proc/cyborg_part_sprite_direction(list/descriptor, list/entry, direction)
	var/cardinal = cyborg_cardinal_direction(direction)
	if(cardinal == NORTH && (TRAIT_R_WIDE in descriptor["features"]) && entry["reuse_south"])
		return SOUTH
	return cardinal

/// Generates only the changed appearance, never creates organs or reads preferences.
/proc/cyborg_build_appearance(list/descriptor, list/layout, list/runtime_state)
	var/list/layers = list()
	if(!descriptor || !layout)
		return layers
	var/list/choices = runtime_state["choices"]
	var/list/active = runtime_state["active"]
	var/list/arousal = runtime_state["arousal"]
	// The editor owns the six displayed PNGs independently of the shared FIFO.
	// Reusing them must still run the same placement math as the live renderer.
	var/list/cached_icons = runtime_state["cached_icons"]
	var/list/anchor = cyborg_animation_anchor(descriptor, runtime_state["direction"], runtime_state["pose"])
	for(var/slot in cyborg_layout_supported_slots())
		if(!active[slot] || !choices[slot] || choices[slot] == SPRITE_ACCESSORY_NONE)
			continue
		var/state = arousal[slot] || "none"
		var/list/entry = layout[slot]
		var/mirrored = cyborg_mirror_placement(descriptor, entry, runtime_state["direction"])
		var/list/placement = cyborg_resolve_placement(entry, runtime_state["direction"], runtime_state["pose"], state, mirrored, TRAIT_R_WIDE in descriptor["features"])
		if(anchor)
			placement["pixel_x"] += anchor["x"]
			placement["pixel_y"] += anchor["y"]
		if(!placement["visible"])
			continue
		var/list/rendered
		var/pixels
		if(islist(cached_icons))
			pixels = cached_icons[slot]
		else
			rendered = cyborg_accessory_render(slot, choices[slot], entry["colors"], state, cyborg_part_sprite_direction(descriptor, entry, runtime_state["direction"]), entry["sprite_size"])
			pixels = rendered?["base64"]
		if(!pixels)
			continue
		layers += list(list(
			"slot" = slot, "icon" = pixels, "resource" = rendered?["icon"],
			"x" = placement["pixel_x"], "y" = placement["pixel_y"],
			"rotation" = placement["rotation"], "scale" = placement["scale"], "priority" = placement["priority"],
			"mirror_x" = mirrored ? -1 : 1,
		))
	return layers

/mob/living/silicon/robot/proc/cyborg_customization_update_render()
	if(!cyborg_appearance_layout)
		return
	if(!cyborg_appearance_holder)
		cyborg_appearance_holder = new(src, list())
	cyborg_appearance_holder.update_from_owner()

/mob/living/silicon/robot/after_tip_over(mob/user)
	. = ..()
	// Every tip ends here, through tg's tippable and Nova's cyborg override alike, even for a borg that was already immobilized
	cyborg_appearance_holder?.on_owner_transform()

/mob/living/silicon/robot/after_righted(mob/user)
	. = ..()
	cyborg_appearance_holder?.on_owner_transform()

/obj/effect/client_image_holder/cyborg_customization
	persist_without_seers = TRUE
	/// The borg whose parts we show
	var/mob/living/silicon/robot/owner
	/// Everything the parts were last drawn from, so an update that changes none of it does nothing
	var/render_key
	/// The part layers last built for the owner, empty while they're hidden or waiting on a mask
	var/list/render_layers = list()
	/// At most one weak completion is outstanding, regardless of appearance churn.
	var/occlusion_loading = FALSE
	/// The icon#state key of a chassis whose mask failed to build, so we don't try it again
	var/occlusion_failed_key

/obj/effect/client_image_holder/cyborg_customization/Initialize(mapload, list/mobs_which_see_us)
	owner = loc
	. = ..()
	GLOB.cyborg_customization_holders += src
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(viewer_login))
	RegisterSignal(owner, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(on_owner_transform))
	for(var/mob/player as anything in GLOB.player_list)
		refresh_viewer(player)

/obj/effect/client_image_holder/cyborg_customization/Destroy(force)
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images -= occlusion_image
		seer.client?.images -= animation_image
	occlusion_image = null
	animation_image = null
	UnregisterSignal(owner, COMSIG_LIVING_POST_UPDATE_TRANSFORM)
	GLOB.cyborg_customization_holders -= src
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN)
	owner = null
	return ..()

/obj/effect/client_image_holder/cyborg_customization/on_changed_z_level(turf/old_turf, turf/new_turf, same_z_layer, notify_contents)
	. = ..()
	if(QDELETED(src) || same_z_layer)
		return
	// The parent moves only shown_image; rebuild its filter and both companion images.
	render_key = null
	update_from_owner()

/obj/effect/client_image_holder/cyborg_customization/proc/viewer_login(datum/source, mob/player)
	SIGNAL_HANDLER
	refresh_viewer(player)

/obj/effect/client_image_holder/cyborg_customization/proc/refresh_viewer(mob/player)
	var/allowed = player.client?.prefs?.read_preference(/datum/preference/toggle/see_cyborg_genitalia)
	if(allowed && !(player in who_sees_us))
		add_seer(player)
	else if(!allowed && (player in who_sees_us))
		remove_seer(player)

/obj/effect/client_image_holder/cyborg_customization/add_seer(mob/new_seer)
	. = ..()
	RegisterSignal(new_seer, COMSIG_MOB_LOGOUT, PROC_REF(remove_seer))
	if(occlusion_image)
		new_seer.client?.images |= occlusion_image
	if(animation_image)
		new_seer.client?.images |= animation_image

/obj/effect/client_image_holder/cyborg_customization/remove_seer(mob/source)
	source.client?.images -= occlusion_image
	source.client?.images -= animation_image
	UnregisterSignal(source, COMSIG_MOB_LOGOUT)
	return ..()

/**
 * Shows `new_image` to every seer in place of `old_image`. A seer keeps an image it already has, changed in place, so
 * turns, steps and poses cost no work per seer. Returns the image shown now, or null.
 */
/obj/effect/client_image_holder/cyborg_customization/proc/replace_image(image/old_image, image/new_image)
	if(old_image && new_image)
		old_image.appearance = new_image
		// Taking an appearance leaves dir as it was, and the mask and motion map turn with the body.
		old_image.dir = new_image.dir
		return old_image
	if(old_image)
		for(var/mob/seer as anything in who_sees_us)
			seer.client?.images -= old_image
	if(new_image)
		for(var/mob/seer as anything in who_sees_us)
			seer.client?.images |= new_image
	return new_image

/obj/effect/client_image_holder/cyborg_customization/regenerate_image()
	shown_image = replace_image(shown_image, generate_image())

/obj/effect/client_image_holder/cyborg_customization/generate_image()
	// Order the whole KEEP_TOGETHER group below the separate chassis mask.
	// Child priorities only order parts within this group, not against the mask.
	var/image/result = image(loc = owner, layer = ABOVE_MOB_LAYER)
	if(!owner)
		return result
	SET_PLANE_EXPLICIT(result, GAME_PLANE, owner)
	// Images attached to the robot inherit its offsets and transform.
	result.appearance_flags = KEEP_TOGETHER | PIXEL_SCALE
	var/list/dimensions = get_icon_dimensions(owner.icon)
	for(var/list/entry as anything in render_layers)
		var/mutable_appearance/part = mutable_appearance(entry["resource"], layer = MOB_LAYER + entry["priority"] * 0.001)
		var/matrix/placement = matrix()
		placement.Scale(entry["scale"])
		placement.Turn(entry["rotation"])
		part.transform = placement
		var/icon/art = entry["resource"]
		// Preview origin: body centered on X, part centered on the 32px tile.
		// SIDE_MAP uses pixel_x/y for depth sorting as well as displacement.
		// These are screen-space edits and must stay on the owner's depth row.
		part.pixel_w = entry["x"] + (dimensions["width"] - art.Width()) / 2
		part.pixel_z = entry["y"] + 16 - art.Height() / 2
		part.appearance_flags = PIXEL_SCALE
		result.overlays += part
	return result

/obj/effect/client_image_holder/cyborg_customization/proc/update_from_owner()
	if(!owner)
		return
	var/new_key = "[owner.cyborg_appearance_revision]|[owner.dir]|[owner.icon]|[owner.icon_state]|[owner.stat]|[owner.transform]|[HAS_TRAIT_FROM(owner, TRAIT_IMMOBILIZED, TIPPED_OVER)]|[CONFIG_GET(flag/disable_erp_preferences)]|[owner.cyborg_appearance_allowed]"
	if(new_key == render_key)
		return
	render_key = new_key
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	// Disguises and non-player chassis do not reveal the underlying customization.
	var/visible = cyborg_body_visuals_visible(owner)
	render_layers = visible ? cyborg_build_appearance(descriptor, owner.cyborg_appearance_layout, list(
		"choices" = owner.cyborg_appearance_choices, "active" = owner.cyborg_appearance_active,
		"arousal" = owner.cyborg_appearance_arousal, "direction" = owner.dir, "pose" = owner.cyborg_customization_pose(),
	)) : list()
	if(length(render_layers) && cyborg_occlusion_has_model(descriptor["icon"], descriptor["icon_state"]) && !cyborg_occlusion_cached(descriptor["icon"], descriptor["icon_state"]))
		// Never attach parts without their matching chassis mask. A first use
		// prepares the pair asynchronously; subsequent owners reuse the resource.
		render_layers = list()
		var/model_key = "[descriptor["icon"]]#[descriptor["icon_state"]]"
		if(!occlusion_loading && occlusion_failed_key != model_key)
			occlusion_loading = TRUE
			INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(cyborg_complete_holder_occlusion), WEAKREF(src), descriptor["icon"], descriptor["icon_state"])
	regenerate_image()
	update_occlusion()
	update_animation()

/// Resolve the holder only after waiting. No owner, layout, or old image is captured.
/proc/cyborg_complete_holder_occlusion(datum/weakref/holder_ref, source_file, base_state)
	// Finish the synchronous hide before a ready/failed completion can rebuild.
	sleep(0)
	var/obj/effect/client_image_holder/cyborg_customization/holder = holder_ref.resolve()
	if(QDELETED(holder))
		return
	if(QDELETED(holder.owner) || holder.owner.cyborg_appearance_holder != holder)
		holder.occlusion_loading = FALSE
		return
	var/list/current = cyborg_model_catalog()[holder.owner.cyborg_appearance_model]
	if(!cyborg_body_visuals_visible(holder.owner) || !current || current["icon"] != source_file || current["icon_state"] != base_state)
		holder.occlusion_loading = FALSE
		holder.render_key = null
		holder.update_from_owner()
		return
	var/has_active_part = FALSE
	for(var/slot in cyborg_layout_supported_slots())
		if(holder.owner.cyborg_appearance_active[slot] && holder.owner.cyborg_appearance_choices[slot] && holder.owner.cyborg_appearance_choices[slot] != SPRITE_ACCESSORY_NONE)
			has_active_part = TRUE
			break
	if(!has_active_part)
		holder.occlusion_loading = FALSE
		return
	holder = null
	current = null
	var/exception/failure
	try
		cyborg_occlusion_ensure_model_ready(source_file, base_state)
	catch(var/exception/error)
		failure = error
	holder = holder_ref.resolve()
	if(QDELETED(holder))
		return
	holder.occlusion_loading = FALSE
	if(failure)
		holder.occlusion_failed_key = "[source_file]#[base_state]"
	if(QDELETED(holder.owner) || holder.owner.cyborg_appearance_holder != holder)
		return
	holder.render_key = null
	holder.update_from_owner()

/datum/preference_middleware/cyborg_character/post_set_preference(mob/user, preference, value)
	for(var/slot in cyborg_layout_supported_slots())
		if(preference != "silicon_[slot]_sprite")
			continue
		var/list/draft = begin_draft()
		if(draft)
			draft = draft.Copy()
			var/list/active = draft["active"]
			draft["active"] = active.Copy()
			var/list/entry = active[slot]
			draft["active"][slot] = entry.Copy()
			draft["active"][slot]["sprite"] = cyborg_preference_value(preferences, preference)
			update_draft(draft, copied_on_write = TRUE)
	if(iscyborg(user))
		var/mob/living/silicon/robot/robot = user
		robot.cyborg_customization_sync_permissions(preferences)
	if(preference == "see_cyborg_genitalia")
		for(var/obj/effect/client_image_holder/cyborg_customization/holder as anything in GLOB.cyborg_customization_holders)
			holder.refresh_viewer(user)
	// Character setup and the editor's window can both change what the editor shows, so we refresh it last, after the draft
	if(editor_open)
		SStgui.update_uis(src)

/// A configuration reload must revoke existing images, including idle owners.
/datum/controller/configuration/admin_reload()
	. = ..()
	for(var/obj/effect/client_image_holder/cyborg_customization/holder as anything in GLOB.cyborg_customization_holders)
		if(!holder.owner)
			continue
		holder.owner.cyborg_customization_sync_permissions(holder.owner.client?.prefs)
		holder.render_key = null
		holder.owner.cyborg_customization_refresh_model()
