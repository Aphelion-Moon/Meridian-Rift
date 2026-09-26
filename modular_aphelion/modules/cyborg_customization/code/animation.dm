/// Authored anchor data is generated offline; runtime never scans marker pixels.
/proc/cyborg_animation_frames(list/descriptor, direction, pose, moving = FALSE)
	var/static/list/manifest
	if(isnull(manifest))
		manifest = json_decode(file2text('modular_aphelion/modules/cyborg_customization/animation_manifest.json'))
	var/list/models = manifest["models"]
	var/profile_id = models["[descriptor["icon"]]#[descriptor["icon_state"]]"]
	if(isnull(profile_id))
		return null
	var/list/profiles = manifest["profiles"]
	var/list/model = profiles[profile_id]
	var/list/state = model?["[pose]:[moving ? 1 : 0]"]
	return state?[LOWER_TEXT(dir2text(cyborg_cardinal_direction(direction)))]

/proc/cyborg_animation_anchor(list/descriptor, direction, pose)
	var/list/frames = cyborg_animation_frames(descriptor, direction, pose)
	return length(frames) ? frames[1] : null

/obj/effect/client_image_holder/cyborg_customization
	var/image/occlusion_image
	/// Private native DMI carrier; its movement frames run on the chassis's client clock.
	var/image/animation_image

/// One pixel per native frame, encoding a literal anchor translation after part transforms.
/// Only catalog descriptors reach this cache; player colors and placement are not cache keys.
/proc/cyborg_animation_map(list/descriptor)
	var/static/list/maps = list()
	var/key = "[descriptor["icon"]]#[descriptor["icon_state"]]"
	if(maps[key])
		return maps[key]
	if(!cyborg_animation_anchor(descriptor, SOUTH, "idle"))
		return null
	var/icon/result = icon()
	for(var/pose in descriptor["poses"])
		var/state = descriptor["icon_state"] + (pose == "idle" ? "" : "-[pose]")
		for(var/direction in GLOB.cardinals)
			var/list/anchor = cyborg_animation_anchor(descriptor, direction, pose)
			for(var/moving in 0 to 1)
				var/list/frames = cyborg_animation_frames(descriptor, direction, pose, moving)
				// An unsupported sequence stays at its static placement, never another gait.
				if(!length(frames) || !anchor)
					frames = list(list("x" = anchor ? anchor["x"] : 0, "y" = anchor ? anchor["y"] : 0, "delay" = 1))
				var/frame_index = 0
				for(var/list/frame as anything in frames)
					var/delta_x = anchor ? frame["x"] - anchor["x"] : 0
					var/delta_y = anchor ? frame["y"] - anchor["y"] : 0
					var/icon/pixel = icon('icons/blanks/32x32.dmi', "nothing")
					pixel.Crop(1, 1, 1, 1)
					pixel.DrawBox(rgb(128 - delta_x, 128 + delta_y, 128), 1, 1)
					result.Insert(pixel, state, direction, ++frame_index, moving, frame["delay"])
	maps[key] = result
	return result

/obj/effect/client_image_holder/cyborg_customization/proc/on_owner_transform()
	SIGNAL_HANDLER
	render_key = null
	update_from_owner()

/obj/effect/client_image_holder/cyborg_customization/proc/update_animation()
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images -= animation_image
	animation_image = null
	if(!owner || !shown_image)
		return
	shown_image.filters = null
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	if(!descriptor || !length(render_layers))
		return
	var/icon/movement_map = cyborg_animation_map(descriptor)
	if(!movement_map)
		return
	var/min_x = 0
	var/min_y = 0
	var/max_x = 32
	var/max_y = 32
	for(var/mutable_appearance/part as anything in shown_image.overlays)
		var/list/dimensions = get_icon_dimensions(part.icon)
		var/matrix/placement = part.transform
		var/half_width = (abs(placement.a) * dimensions["width"] + abs(placement.b) * dimensions["height"]) / 2
		var/half_height = (abs(placement.d) * dimensions["width"] + abs(placement.e) * dimensions["height"]) / 2
		var/center_x = part.pixel_w + dimensions["width"] / 2
		var/center_y = part.pixel_z + dimensions["height"] / 2
		min_x = min(min_x, FLOOR(center_x - half_width, 1))
		min_y = min(min_y, FLOOR(center_y - half_height, 1))
		max_x = max(max_x, CEILING(center_x + half_width, 1))
		max_y = max(max_y, CEILING(center_y + half_height, 1))
	var/margin = 1
	var/list/anchor = cyborg_animation_anchor(descriptor, owner.dir, owner.cyborg_customization_pose())
	for(var/moving in 0 to 1)
		for(var/list/frame as anything in cyborg_animation_frames(descriptor, owner.dir, owner.cyborg_customization_pose(), moving))
			margin = max(margin, abs(frame["x"] - anchor["x"]) + 1, abs(frame["y"] - anchor["y"]) + 1)
	var/width = max_x - min_x + 2 * margin
	var/height = max_y - min_y + 2 * margin
	// Displacement does not expand the group's bounds. Reserve transparent edge pixels.
	var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
	canvas.Crop(1, 1, width, height)
	var/mutable_appearance/padding = mutable_appearance(canvas)
	padding.pixel_w = min_x - margin
	padding.pixel_z = min_y - margin
	shown_image.overlays += padding
	animation_image = image(movement_map, owner, owner.icon_state, dir = cyborg_cardinal_direction(owner.dir))
	animation_image.render_target = "*cyborg_motion_[REF(src)]"
	animation_image.appearance_flags = RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA | PIXEL_SCALE
	animation_image.transform = matrix().Scale(width + 2, height + 2)
	SET_PLANE_EXPLICIT(animation_image, GAME_PLANE, owner)
	// At size 127, a one-channel increment is exactly one pixel on BYOND 516.
	shown_image.filters += filter(type = "displace", render_source = animation_image.render_target, size = 127)
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images |= animation_image

/obj/effect/client_image_holder/cyborg_customization/proc/update_occlusion()
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images -= occlusion_image
	occlusion_image = null
	if(!owner || !length(render_layers))
		return
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	if(!descriptor || !cyborg_animation_anchor(descriptor, owner.dir, owner.cyborg_customization_pose()))
		return
	var/list/resources = cyborg_occlusion_resources()
	var/resource = resources["[descriptor["icon"]]"]
	if(!resource)
		return
	occlusion_image = image(resource, owner, owner.icon_state, ABOVE_MOB_LAYER + 0.1, cyborg_cardinal_direction(owner.dir))
	// Owner-relative mask: inherit its transform and pixel offsets exactly once.
	occlusion_image.appearance_flags = PIXEL_SCALE
	SET_PLANE_EXPLICIT(occlusion_image, GAME_PLANE, owner)
	for(var/mob/seer as anything in who_sees_us)
		seer.client?.images |= occlusion_image
