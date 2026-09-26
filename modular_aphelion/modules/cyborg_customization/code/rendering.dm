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
		var/list/rendered = cyborg_accessory_render(slot, choices[slot], entry["colors"], state, cyborg_part_sprite_direction(descriptor, entry, runtime_state["direction"]), entry["sprite_size"])
		if(!rendered)
			continue
		layers += list(list(
			"slot" = slot, "icon" = rendered["base64"], "resource" = rendered["icon"],
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

/obj/effect/client_image_holder/cyborg_customization
	persist_without_seers = TRUE
	var/mob/living/silicon/robot/owner
	var/render_key
	var/list/render_layers = list()

/obj/effect/client_image_holder/cyborg_customization/Initialize(mapload, list/mobs_which_see_us)
	owner = loc
	. = ..()
	GLOB.cyborg_customization_holders += src
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN, PROC_REF(viewer_login))
	RegisterSignal(owner, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(on_owner_transform))
	RegisterSignal(owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))
	RegisterSignals(owner, list(SIGNAL_ADDTRAIT(TRAIT_IMMOBILIZED), SIGNAL_REMOVETRAIT(TRAIT_IMMOBILIZED)), PROC_REF(on_owner_transform))
	for(var/mob/player as anything in GLOB.player_list)
		refresh_viewer(player)

/obj/effect/client_image_holder/cyborg_customization/Destroy(force)
	if(movement_timer)
		deltimer(movement_timer)
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images -= occlusion_image
	occlusion_image = null
	UnregisterSignal(owner, list(COMSIG_LIVING_POST_UPDATE_TRANSFORM, COMSIG_MOVABLE_MOVED))
	UnregisterSignal(owner, list(SIGNAL_ADDTRAIT(TRAIT_IMMOBILIZED), SIGNAL_REMOVETRAIT(TRAIT_IMMOBILIZED)))
	GLOB.cyborg_customization_holders -= src
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_LOGGED_IN)
	owner = null
	return ..()

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

/obj/effect/client_image_holder/cyborg_customization/remove_seer(mob/source)
	source.client?.images -= occlusion_image
	UnregisterSignal(source, COMSIG_MOB_LOGOUT)
	return ..()

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
	var/new_key = "[owner.cyborg_appearance_revision]|[owner.dir]|[owner.icon]|[owner.icon_state]|[owner.stat]|[owner.transform]|[HAS_TRAIT(owner, TRAIT_IMMOBILIZED)]|[CONFIG_GET(flag/disable_erp_preferences)]|[owner.cyborg_appearance_allowed]"
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
	regenerate_image()
	update_occlusion()
	play_authored_animation()

/datum/preference_middleware/cyborg_character/post_set_preference(mob/user, preference, value)
	for(var/slot in cyborg_layout_supported_slots())
		if(preference != "silicon_[slot]_sprite")
			continue
		var/list/draft = begin_draft()
		if(draft)
			draft["active"][slot]["sprite"] = cyborg_preference_value(preferences, preference)
			update_draft(draft)
	if(iscyborg(user))
		var/mob/living/silicon/robot/robot = user
		robot.cyborg_customization_sync_permissions(preferences)
	if(preference == "see_cyborg_genitalia")
		for(var/obj/effect/client_image_holder/cyborg_customization/holder as anything in GLOB.cyborg_customization_holders)
			holder.refresh_viewer(user)

/// A configuration reload must revoke existing images, including idle owners.
/datum/controller/configuration/admin_reload()
	. = ..()
	for(var/obj/effect/client_image_holder/cyborg_customization/holder as anything in GLOB.cyborg_customization_holders)
		if(!holder.owner)
			continue
		holder.owner.cyborg_customization_sync_permissions(holder.owner.client?.prefs)
		holder.render_key = null
		holder.owner.cyborg_customization_refresh_model()
