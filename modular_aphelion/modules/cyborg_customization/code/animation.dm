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
	/// The chassis mask image viewers see with the parts, null while there is none
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
	animation_image = replace_image(animation_image, owner && shown_image ? build_animation() : null)

/// Pads the parts image for its displacement filter and returns the motion map image that drives it, or null.
/obj/effect/client_image_holder/cyborg_customization/proc/build_animation()
	shown_image.filters = null
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	if(!descriptor || !length(render_layers))
		return null
	var/icon/movement_map = cyborg_animation_map(descriptor)
	if(!movement_map)
		return null
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
	var/image/motion = image(movement_map, owner, owner.icon_state, dir = cyborg_cardinal_direction(owner.dir))
	motion.render_target = "*cyborg_motion_[REF(src)]"
	motion.appearance_flags = RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA | PIXEL_SCALE
	motion.transform = matrix().Scale(width + 2, height + 2)
	SET_PLANE_EXPLICIT(motion, GAME_PLANE, owner)
	// At size 127, a one-channel increment is exactly one pixel on BYOND 516.
	shown_image.filters += filter(type = "displace", render_source = motion.render_target, size = 127)
	return motion

/obj/effect/client_image_holder/cyborg_customization/proc/update_occlusion()
	occlusion_image = replace_image(occlusion_image, build_occlusion())

/// The chassis mask image for the parts, or null while there is none to show.
/obj/effect/client_image_holder/cyborg_customization/proc/build_occlusion()
	if(!owner || !length(render_layers))
		return null
	var/list/catalog = cyborg_model_catalog()
	var/list/descriptor = owner.cyborg_appearance_model ? catalog[owner.cyborg_appearance_model] : null
	if(!descriptor || !cyborg_animation_anchor(descriptor, owner.dir, owner.cyborg_customization_pose()))
		return null
	// update_from_owner admits any missing model before publishing this group.
	// Live image mutation is synchronous and reads only immutable cached output.
	var/resource = cyborg_occlusion_cached(descriptor["icon"], descriptor["icon_state"])
	if(!resource)
		return null
	var/image/mask = image(resource, owner, owner.icon_state, ABOVE_MOB_LAYER + 0.1, cyborg_cardinal_direction(owner.dir))
	// Owner-relative mask: inherit its transform and pixel offsets exactly once.
	mask.appearance_flags = PIXEL_SCALE
	SET_PLANE_EXPLICIT(mask, GAME_PLANE, owner)
	return mask

/**
 * Demand-only immutable resources shared for the round. Registration indexes
 * finite authored metadata; one worker generates only requested model keys.
 * The queue/cache never retain owners, preferences, callbacks or color variants.
 */
/datum/asset/cyborg_occlusion
	/// The finished mask of each chassis by its icon#state key, kept for the round
	var/list/resources
	/// What each chassis's mask is built from (source file, base state, size and states) by its icon#state key
	var/list/model_sources
	/// Keys of the masks being built or queued, so a second request waits instead of building again
	var/list/pending = list()
	/// The exception each failed mask threw by its key, thrown again to later requests
	var/list/failures = list()
	/// Keys waiting for the worker, oldest first
	var/list/queue = list()
	/// Whether or not the worker is running, so a new request only queues
	var/worker_running = FALSE
	/// Counts the worker's jobs, which keeps each job's temporary file names apart
	var/job_serial = 0

/datum/asset/cyborg_occlusion/register()
	if(resources)
		return
	resources = list()
	model_sources = list()
	var/list/sources = cyborg_occlusion_sources()
	for(var/source_file in sources)
		var/list/source = sources[source_file]
		for(var/list/state as anything in source["states"])
			var/base_state = state["model"]
			var/key = "[source_file]#[base_state]"
			if(!model_sources[key])
				model_sources[key] = list("source" = source_file, "base" = base_state, "width" = source["width"], "height" = source["height"], "states" = list())
			model_sources[key]["states"] += list(state)

/// Joins a finite shared request. Successful immutable resources live for the round.
/datum/asset/cyborg_occlusion/proc/ensure_model_ready(source_file, base_state)
	var/key = "[source_file]#[base_state]"
	if(!model_sources[key])
		return null
	if(resources[key])
		return resources[key]
	if(failures[key])
		throw failures[key]
	if(!pending[key])
		pending[key] = TRUE
		queue += key
		if(!worker_running)
			worker_running = TRUE
			INVOKE_ASYNC(src, PROC_REF(process_queue))
	UNTIL(!pending[key])
	if(failures[key])
		throw failures[key]
	return resources[key]

/// One worker owns staging and the IconForge lease; concurrent requests only queue.
/datum/asset/cyborg_occlusion/proc/process_queue()
	while(length(queue))
		var/key = queue[1]
		queue.Cut(1, 2)
		job_serial++
		var/list/temporary_files = list()
		var/resource
		var/exception/failure
		SSasset_loading.assets_generating++
		try
			var/prefix = "tmp/cyborg-occlusion-[world.port]-[world.realtime]-[job_serial]"
			resource = generate_model(model_sources[key], prefix, temporary_files)
			if(!resource)
				throw EXCEPTION("Cyborg occlusion generation produced no resource for [key]")
		catch(var/exception/error)
			failure = error
		for(var/path in temporary_files)
			fdel(path)
		SSasset_loading.assets_generating--
		// Both shared cleanup callers observe our lease. Release intermediates
		// after each model when no other asset or character draw still needs them.
		if(!SSasset_loading.assets_generating && !length(SSasset_loading.generate_queue) && !character_preview_drawing_under_way())
			rustg_iconforge_cleanup()
		if(failure)
			failures[key] = failure
		else
			resources[key] = resource
		pending -= key
		if(failure)
			report_generation_failure(key, failure)
		CHECK_TICK
	worker_running = FALSE

/// Report the worker failure once; joining callers only observe the cached error.
/datum/asset/cyborg_occlusion/proc/report_generation_failure(key, exception/failure)
	log_asset("Cyborg occlusion generation failed for [key]")
	world.Error(failure, src)

/// This invocation receives only one model, including all its supported poses.
/datum/asset/cyborg_occlusion/proc/generate_model(list/model, prefix, list/temporary_files)
	var/source_file = model["source"]
	var/key = "[source_file]#[model["base"]]"
	var/list/states = model["states"]
	var/list/mask_states = list()
	for(var/list/state as anything in states)
		// Reject a stale or hand-edited plan before changing animation metadata.
		if(state["dirs"] != 4 || state["loop"] || state["rewind"])
			throw EXCEPTION("Unsupported cyborg occlusion metadata for [key]:[state["state"]]: dirs=[state["dirs"]] loop=[state["loop"]] rewind=[state["rewind"]]")
		var/mask_file = state["mask"]
		if(!mask_states[mask_file])
			mask_states[mask_file] = list()
		mask_states[mask_file]["[state["mask_state"]]#[state["moving"]]"] = state
	var/list/mask_inputs = list()
	for(var/mask_file in mask_states)
		var/list/required_states = mask_states[mask_file]
		var/icon/staged_mask = icon()
		var/list/names = list()
		for(var/state_key in required_states)
			var/list/state = required_states[state_key]
			var/alias = "state[length(names) + 1]"
			staged_mask.Insert(icon(mask_file, state["mask_state"], moving = state["moving"]), alias, moving = FALSE)
			names[state_key] = alias
			CHECK_TICK
		var/path = "[prefix]-mask[length(mask_inputs) + 1].dmi"
		temporary_files += path
		if(!fcopy(staged_mask, path))
			throw EXCEPTION("Could not stage cyborg occlusion mask [mask_file]")
		mask_inputs[mask_file] = list("file" = file(path), "states" = names)
	var/icon/staged_body = icon()
	for(var/index in 1 to length(states))
		var/list/state = states[index]
		var/list/delays = state["delays"]
		// Whole-state export performs costly deferred source work in one native
		// call. Detach the same cells used by preview rendering, yielding between.
		for(var/direction in GLOB.cardinals)
			for(var/frame_index in 1 to length(delays))
				var/icon/cell = icon(source_file, state["state"], direction, frame_index, state["moving"])
				cell.GetPixel(1, 1)
				staged_body.Insert(cell, "state[index]", direction, frame_index, FALSE, delays[frame_index])
				CHECK_TICK
	var/body_path = "[prefix]-body.dmi"
	temporary_files += body_path
	if(!fcopy(staged_body, body_path))
		throw EXCEPTION("Could not stage cyborg occlusion body [key]")
	var/list/entries = list()
	for(var/index in 1 to length(states))
		var/list/state = states[index]
		var/list/mask = mask_inputs[state["mask"]]
		var/mask_state = mask["states"]["[state["mask_state"]]#[state["moving"]]"]
		entries["state[index]"] = cyborg_occlusion_recipe(file(body_path), "state[index]", mask["file"], mask_state)
	// One asynchronous IconForge job contains only this requested model.
	var/output_name = "cyborg-occlusion-[world.port]-[world.realtime]-[job_serial]-output"
	var/size = "[model["width"]]x[model["height"]]"
	var/output_path = "tmp/[output_name]_[size].dmi"
	temporary_files += output_path
	var/job = rustg_iconforge_generate_async("tmp/", output_name, json_encode(entries), FALSE, TRUE, FALSE)
	var/result
	UNTIL((result = rustg_iconforge_check(job)) != RUSTG_JOB_NO_RESULTS_YET)
	if(!findtext(result, "{", 1, 2))
		throw EXCEPTION("Cyborg occlusion IconForge job failed for [key]: [result]")
	var/list/output = json_decode(result)
	var/list/sizes = output["sizes"]
	for(var/output_size in sizes)
		temporary_files |= "tmp/[output_name]_[output_size].dmi"
	if(output["error"] || length(sizes) != 1 || sizes[1] != size)
		throw EXCEPTION("Cyborg occlusion IconForge output failed for [key]: [result]")
	var/list/metadata = rustg_dmi_read_metadata(output_path)
	if(!islist(metadata))
		throw EXCEPTION("Could not read generated cyborg occlusion metadata for [key]: [metadata]")
	var/list/generated_states = metadata["states"]
	if(length(generated_states) != length(states))
		throw EXCEPTION("Cyborg occlusion state count changed for [key]")
	var/icon/restored = icon()
	for(var/index in 1 to length(states))
		var/list/state = states[index]
		var/list/generated = generated_states[index]
		var/list/delays = generated["delay"] || list(1)
		if(generated["name"] != "state[index]" || generated["dirs"] != state["dirs"] || !compare_list(delays, state["delays"]) || (generated["loop_count"] || 0) != state["loop"] || (generated["rewind"] || 0) != state["rewind"])
			throw EXCEPTION("Cyborg occlusion animation metadata changed for [key]:[state["state"]]")
		restored.Insert(icon(file(output_path), "state[index]"), state["state"], moving = state["moving"])
		CHECK_TICK
	// Finish native construction, then serialize every frame once. Publishing an
	// icon-backed resource can retain deferred work or empty native selections.
	restored.GetPixel(1, 1)
	var/model_path = "[prefix]-model.dmi"
	temporary_files += model_path
	if(!fcopy(restored, model_path))
		throw EXCEPTION("Could not serialize cyborg occlusion resource [key]")
	var/resource = fcopy_rsc(file(model_path))
	if(!resource)
		throw EXCEPTION("Could not publish cyborg occlusion resource [key]")
	CHECK_TICK
	return resource

/**
 * Pillow's authored alpha product floors a*b/255; native/Rust-g alpha blending
 * rounds it. RGB multiplication floors, so compute the product in red, move it
 * to alpha, then add its zero RGB to the opaque original body. This preserves
 * body RGB and every alpha value without a DM pixel loop.
 */
/proc/cyborg_occlusion_recipe(body_file, body_state, mask_file, mask_state)
	var/datum/universal_icon/alpha = uni_icon(body_file, body_state)
	alpha.map_colors_rgba(0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,1)
	var/datum/universal_icon/mask = uni_icon(mask_file, mask_state)
	mask.map_colors_rgba(0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,1)
	alpha.blend_icon(mask, ICON_MULTIPLY)
	alpha.map_colors_rgba(0,0,0,1, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0)
	var/datum/universal_icon/body = uni_icon(body_file, body_state)
	body.map_colors_rgba(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,0, 0,0,0,1)
	body.blend_icon(alpha, ICON_ADD)
	return body.to_list()

/// Metadata-only construction; this helper never starts generation or sleeps.
/proc/cyborg_occlusion_has_model(source_file, base_state)
	var/datum/asset/cyborg_occlusion/asset = get_asset_datum(/datum/asset/cyborg_occlusion)
	return !!asset.model_sources["[source_file]#[base_state]"]

/// UI/load continuations may wait here, then must revalidate their current owner.
/proc/cyborg_occlusion_ensure_model_ready(source_file, base_state)
	var/datum/asset/cyborg_occlusion/asset = get_asset_datum(/datum/asset/cyborg_occlusion)
	return asset.ensure_model_ready(source_file, base_state)

/// Live appearance updates never yield or begin a resource build.
/proc/cyborg_occlusion_cached(source_file, base_state)
	var/datum/asset/cyborg_occlusion/asset = GLOB.asset_datums[/datum/asset/cyborg_occlusion]
	return asset?.resources["[source_file]#[base_state]"]
