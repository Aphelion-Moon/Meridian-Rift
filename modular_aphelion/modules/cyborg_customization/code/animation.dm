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
	var/movement_timer
	var/moving = FALSE

/obj/effect/client_image_holder/cyborg_customization/proc/on_owner_transform()
	SIGNAL_HANDLER
	render_key = null
	update_from_owner()

/obj/effect/client_image_holder/cyborg_customization/proc/on_owner_moved()
	SIGNAL_HANDLER
	if(movement_timer)
		deltimer(movement_timer)
	movement_timer = addtimer(CALLBACK(src, PROC_REF(end_movement)), 2, TIMER_STOPPABLE)
	if(!moving)
		moving = TRUE
		play_authored_animation()

/obj/effect/client_image_holder/cyborg_customization/proc/end_movement()
	movement_timer = null
	moving = FALSE
	play_authored_animation()

/obj/effect/client_image_holder/cyborg_customization/proc/play_authored_animation()
	if(!owner || !shown_image)
		return
	animate(shown_image)
	shown_image.pixel_w = 0
	shown_image.pixel_z = 0
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	if(!descriptor || !length(render_layers))
		return
	var/list/frames = cyborg_animation_frames(descriptor, owner.dir, owner.cyborg_customization_pose(), moving)
	if(length(frames) <= 1)
		return
	var/list/anchor = cyborg_animation_anchor(descriptor, owner.dir, owner.cyborg_customization_pose())
	if(!anchor)
		return
	// Pixel animation is client-side. Slider edits regenerate bounded inputs; walking does not.
	var/first = TRUE
	for(var/list/frame as anything in frames)
		var/x = (frame["x"] - anchor["x"])
		var/y = (frame["y"] - anchor["y"])
		if(first)
			animate(shown_image, pixel_w = x, pixel_z = y, time = frame["delay"], loop = -1, flags = ANIMATION_END_NOW)
			first = FALSE
		else
			animate(pixel_w = x, pixel_z = y, time = frame["delay"], loop = -1)

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
