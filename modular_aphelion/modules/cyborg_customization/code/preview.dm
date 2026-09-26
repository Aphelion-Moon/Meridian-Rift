/// Body previews use immutable resources, never world mobs. A bounded FIFO caches PNGs.
/proc/cyborg_preview_body(list/descriptor, direction = SOUTH, pose = "idle", occlusion = FALSE, frame = 1, moving = FALSE)
	var/static/list/images = list()
	var/static/cache_bytes = 0
	if(!descriptor)
		return null
	if(!(direction in GLOB.cardinals))
		direction = SOUTH
	if(!(pose in descriptor["poses"]))
		pose = "idle"
	var/cache_key = "[descriptor["id"]]|[direction]|[pose]|[occlusion]|[frame]|[moving]"
	if(images[cache_key])
		return images[cache_key]
	var/state = descriptor["icon_state"]
	if(pose != "idle")
		state += "-[pose]"
	var/resource = descriptor["icon"]
	if(occlusion)
		if(!cyborg_animation_anchor(descriptor, direction, pose))
			return null
		var/list/resources = cyborg_occlusion_resources()
		resource = resources["[resource]"]
		if(!resource)
			return null
	var/icon/body = icon(resource, state, direction, frame, moving)
	var/data = icon2base64(body)
	while(length(images) && (length(images) >= 512 || cache_bytes + length(data) > 4194304))
		cache_bytes -= length(images[images[1]])
		images.Cut(1, 2)
	images[cache_key] = data
	cache_bytes += length(data)
	return data

/// Existing one-tile mannequin artwork, fixed at normal body scale in the frontend.
/proc/cyborg_preview_reference()
	var/static/reference
	if(!reference)
		reference = icon2base64(icon('icons/mob/human/mannequin.dmi', "mannequin_plastic_male", SOUTH, 1))
	return reference

/// A bounded frame sequence for the visible model only. No periodic server UI updates.
/proc/cyborg_preview_animation(list/descriptor, direction, pose, moving, include_occlusion)
	var/list/result = list()
	if(!descriptor)
		return result
	var/list/frames = cyborg_animation_frames(descriptor, direction, pose, moving)
	var/list/anchor = cyborg_animation_anchor(descriptor, direction, pose)
	if(!anchor || length(frames) > 32)
		return result
	var/index = 0
	for(var/list/frame as anything in frames)
		index++
		result += list(list(
			"body" = cyborg_preview_body(descriptor, direction, pose, FALSE, index, moving),
			"occlusion" = include_occlusion ? cyborg_preview_body(descriptor, direction, pose, TRUE, index, moving) : null,
			"x" = frame["x"] - anchor["x"], "y" = frame["y"] - anchor["y"],
			"delay" = frame["delay"] * 100,
		))
	return result

/proc/cyborg_preview_layers(datum/preferences/preferences, list/descriptor, list/layout, direction, pose, arousal_state, use_saved_choices = FALSE)
	if(!cyborg_visuals_allowed(preferences))
		return list()
	var/list/choices = list()
	var/list/active = list()
	var/list/arousal = list()
	for(var/slot in cyborg_layout_supported_slots())
		choices[slot] = cyborg_preference_value(preferences, "silicon_[slot]_sprite")
		if(use_saved_choices && !isnull(layout[slot]["sprite"]))
			choices[slot] = layout[slot]["sprite"]
		active[slot] = TRUE
		arousal[slot] = arousal_state
	var/list/layers = cyborg_build_appearance(descriptor, layout, list("choices" = choices, "active" = active, "arousal" = arousal, "direction" = direction, "pose" = pose))
	for(var/list/layer as anything in layers)
		layer -= "resource"
	return layers
