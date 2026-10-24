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
	// By cardinal - what LOWER_TEXT(dir2text()) gives, without building text
	var/static/list/direction_keys = list("north", "south", null, "east", null, null, null, "west")
	var/cardinal = cyborg_cardinal_direction(direction)
	var/direction_key = direction_keys[cardinal]
	var/pose_key = "[pose]_[direction_key]"
	var/list/advanced = entry["advanced"]
	var/list/directional = advanced[pose_key] || advanced[direction_key]
	var/list/override = directional?["arousal"]?[arousal]
	var/list/resolved = list("visible" = TRUE, "pixel_x" = 0, "pixel_y" = 0, "rotation" = 0, "priority" = 5)
	// Most parts have no override for this pose and direction, and the arousal override sits inside the directional one
	if(directional)
		for(var/field in resolved)
			if(!isnull(directional[field]))
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

/// Whether a part's placement is mirrored - a wide chassis facing west, unless the part opts out
/proc/cyborg_mirror_placement(list/descriptor, list/entry, direction)
	return (TRAIT_R_WIDE in descriptor["features"]) && entry["mirror_sides"] && cyborg_cardinal_direction(direction) == WEST

/// Returns the direction of a part's art - a wide chassis facing north may reuse its south art
/proc/cyborg_part_sprite_direction(list/descriptor, list/entry, direction)
	var/cardinal = cyborg_cardinal_direction(direction)
	if(cardinal == NORTH && (TRAIT_R_WIDE in descriptor["features"]) && entry["reuse_south"])
		return SOUTH
	return cardinal

/// Generates only the changed appearance, never creates organs or reads preferences. Returns null when no part shows
/proc/cyborg_build_appearance(list/descriptor, list/layout, list/runtime_state)
	var/list/layers
	if(!descriptor || !layout)
		return null
	var/list/choices = runtime_state["choices"]
	var/list/active = runtime_state["active"]
	var/list/arousal = runtime_state["arousal"]
	// The editor owns the six displayed PNGs independently of the shared FIFO.
	// Reusing them must still run the same placement math as the live renderer.
	var/list/cached_icons = runtime_state["cached_icons"]
	var/list/anchor = cyborg_animation_anchor(descriptor, runtime_state["direction"], runtime_state["pose"])
	for(var/slot in cyborg_layout_supported_slots())
		if(!LAZYACCESS(active, slot) || !choices[slot] || choices[slot] == SPRITE_ACCESSORY_NONE)
			continue
		var/state = LAZYACCESS(arousal, slot) || "none"
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
		LAZYADD(layers, list(list(
			"slot" = slot, "icon" = pixels, "resource" = rendered?["icon"],
			"x" = placement["pixel_x"], "y" = placement["pixel_y"],
			"rotation" = placement["rotation"], "scale" = placement["scale"], "priority" = placement["priority"],
			"mirror_x" = mirrored ? -1 : 1,
		)))
	return layers

/// Redraws the borg's parts, making their image holder the first time
/mob/living/silicon/robot/proc/cyborg_customization_update_render()
	if(!cyborg_appearance_layout)
		return
	if(!cyborg_appearance_holder)
		cyborg_appearance_holder = new(src, list())
	cyborg_appearance_holder.update_from_owner()

/// Redraws the parts once the borg is tipped over, which hides them
/mob/living/silicon/robot/after_tip_over(mob/user)
	. = ..()
	// Every tip ends here, through tg's tippable and Nova's cyborg override alike, even for a borg that was already immobilized
	cyborg_appearance_holder?.on_owner_transform()

/// Redraws the parts once the borg is back on its feet
/mob/living/silicon/robot/after_righted(mob/user)
	. = ..()
	cyborg_appearance_holder?.on_owner_transform()

/obj/effect/client_image_holder/cyborg_customization
	persist_without_seers = TRUE
	/// The borg whose parts we show
	var/mob/living/silicon/robot/owner
	/// Everything the parts were last drawn from, so an update that changes none of it does nothing
	var/render_key
	/// The part layers last built for the owner, null while none show - hidden or turned off
	var/list/render_layers

/// Starts showing the parts to every player who opted in, now and as they log in, and follows the borg's transform
/obj/effect/client_image_holder/cyborg_customization/Initialize(mapload, list/mobs_which_see_us)
	owner = loc
	. = ..()
	GLOB.cyborg_customization_holders += src
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(viewer_login))
	RegisterSignal(owner, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(on_owner_transform))
	for(var/mob/player as anything in GLOB.player_list)
		refresh_viewer(player)

/// Takes the occlusion, mask and motion map images back from every viewer
/obj/effect/client_image_holder/cyborg_customization/Destroy(force)
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images -= occlusion_image
		seer.client?.images -= mask_image
		seer.client?.images -= animation_image
	occlusion_image = null
	mask_image = null
	animation_image = null
	UnregisterSignal(owner, COMSIG_LIVING_POST_UPDATE_TRANSFORM)
	GLOB.cyborg_customization_holders -= src
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN)
	owner = null
	return ..()

/// Redraws everything after a move to another z layer, as the parent only moves the parts image
/obj/effect/client_image_holder/cyborg_customization/on_changed_z_level(turf/old_turf, turf/new_turf, same_z_layer, notify_contents)
	. = ..()
	if(QDELETED(src) || same_z_layer)
		return
	// The parent moves only shown_image; rebuild its filter and both companion images.
	render_key = null
	update_from_owner()

/// Called when a player logs in - shows them the parts if they opted in
/obj/effect/client_image_holder/cyborg_customization/proc/viewer_login(datum/source, mob/player)
	SIGNAL_HANDLER
	refresh_viewer(player)

/// Shows or hides the parts for a player, by their preference
/obj/effect/client_image_holder/cyborg_customization/proc/refresh_viewer(mob/player)
	var/allowed = player.client?.prefs?.read_preference(/datum/preference/toggle/see_cyborg_genitalia)
	if(allowed && !(player in who_sees_us))
		add_seer(player)
	else if(!allowed && (player in who_sees_us))
		remove_seer(player)

/// Also shows a new viewer the occlusion, mask and motion map images, and stops showing them when they log out
/obj/effect/client_image_holder/cyborg_customization/add_seer(mob/new_seer)
	. = ..()
	RegisterSignal(new_seer, COMSIG_MOB_LOGOUT, PROC_REF(remove_seer))
	if(mask_image)
		new_seer.client?.images |= mask_image
	if(occlusion_image)
		new_seer.client?.images |= occlusion_image
	if(animation_image)
		new_seer.client?.images |= animation_image

/// Also takes the occlusion, mask and motion map images from a viewer
/obj/effect/client_image_holder/cyborg_customization/remove_seer(mob/source)
	source.client?.images -= occlusion_image
	source.client?.images -= mask_image
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

/// Swaps in a new parts image, changed in place on viewers that already have one
/obj/effect/client_image_holder/cyborg_customization/regenerate_image()
	shown_image = replace_image(shown_image, generate_image())

/// Returns the parts image - every layer placed, turned and scaled over the borg, kept together above it
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

/// Redraws the parts when the render key changed
/obj/effect/client_image_holder/cyborg_customization/proc/update_from_owner()
	if(!owner)
		return
	// No transform here - a matrix in text is always "/matrix", so on_owner_transform() clears the key instead
	var/new_key = "[owner.cyborg_appearance_revision]|[owner.dir]|[owner.icon]|[owner.icon_state]|[owner.stat]|[HAS_TRAIT_FROM(owner, TRAIT_IMMOBILIZED, TIPPED_OVER)]|[CONFIG_GET(flag/disable_erp_preferences)]|[owner.cyborg_appearance_allowed]"
	if(new_key == render_key)
		return
	render_key = new_key
	var/list/descriptor = owner.cyborg_appearance_model ? cyborg_model_catalog()[owner.cyborg_appearance_model] : null
	// Disguises and non-player chassis do not reveal the underlying customization.
	var/visible = cyborg_body_visuals_visible(owner, descriptor)
	render_layers = visible ? cyborg_build_appearance(descriptor, owner.cyborg_appearance_layout, list(
		"choices" = owner.cyborg_appearance_choices, "active" = owner.cyborg_appearance_active,
		"arousal" = owner.cyborg_appearance_arousal, "direction" = owner.dir, "pose" = owner.cyborg_customization_pose(),
	)) : null
	regenerate_image()
	update_occlusion(descriptor)
	animation_image = replace_image(animation_image, build_animation())

/// Called after a preference changes - puts a new part sprite in the draft, updates the borg's permissions and viewers, then refreshes the window
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
			draft["active"][slot]["sprite"] = preferences.read_preference(cyborg_sprite_preferences()[slot])
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
