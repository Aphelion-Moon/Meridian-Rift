/// Public stock artwork is encoded once per catalog generation, independently of
/// private layouts. Keep file resources and small indexes, not duplicate JSON lists.
/datum/asset/cyborg_model_gallery
	early = TRUE
	early_blocking = TRUE
	var/list/catalog
	var/generation
	var/catalog_asset
	var/list/department_assets = list()
	/// Owned resources are registered only on acquisition, avoiding global preloading.
	var/list/assets = list()
	var/generating = FALSE
	var/exception/generation_failure

/datum/asset/cyborg_model_gallery/register()
	build_catalog(cyborg_model_catalog())

/datum/asset/cyborg_model_gallery/ensure_ready()
	UNTIL(!generating)
	if(generation_failure)
		throw generation_failure
	return src

/datum/asset/cyborg_model_gallery/proc/build_catalog(list/source_catalog)
	ensure_ready()
	if(catalog == source_catalog)
		return
	generating = TRUE
	var/list/completed_assets = list()
	var/list/completed_departments = list()
	var/completed_catalog_asset
	var/completed_generation
	try
		var/list/plain = list()
		var/list/department_models = list()
		for(var/id, model_entry in source_catalog)
			var/department = model_entry["department"]
			plain += list(list("id" = id, "department" = department, "skin" = model_entry["skin"]))
			if(!department_models[department])
				department_models[department] = list()
			department_models[department] += id
		var/catalog_resource = json_resource(plain)
		var/list/department_resources = list()
		var/list/hashes = list("catalog" = md5asfile(catalog_resource))
		for(var/department, model_ids in department_models)
			var/list/thumbnails = list()
			for(var/id in model_ids)
				var/list/directions = list()
				for(var/direction in GLOB.cardinals)
					// The file asset replaces the old PNG-string gallery cache. Do not
					// also populate the bounded private-preview FIFO with this catalog.
					directions["[direction]"] = cyborg_preview_body(source_catalog[id], direction, use_cache = FALSE)
				thumbnails[id] = directions
				CHECK_TICK
			var/department_resource = json_resource(thumbnails)
			department_resources[department] = department_resource
			hashes[department] = md5asfile(department_resource)
			CHECK_TICK
		// Content identity is stable when configuration toggles back. User input
		// cannot create new asset names; there are four finite catalog variants.
		completed_generation = md5(json_encode(hashes))
		completed_catalog_asset = "cyborg-gallery-[completed_generation]-catalog.json"
		completed_assets[completed_catalog_asset] = owned_asset(completed_catalog_asset, catalog_resource, hashes["catalog"])
		var/department_index = 0
		for(var/department, department_resource in department_resources)
			var/asset_name = "cyborg-gallery-[completed_generation]-department-[++department_index].json"
			completed_assets[asset_name] = owned_asset(asset_name, department_resource, hashes[department])
			completed_departments[department] = asset_name
	catch(var/exception/failure)
		generation_failure = failure
	if(!generation_failure)
		for(var/asset_name in assets)
			var/datum/asset_cache_item/asset = assets[asset_name]
			if(completed_assets[asset_name] != asset && SSassets.cache[asset_name] == asset)
				SSassets.transport.unregister_asset(asset_name)
		catalog = source_catalog
		generation = completed_generation
		catalog_asset = completed_catalog_asset
		department_assets = completed_departments
		assets = completed_assets
		cached_serialized_url_mappings = null
		cached_serialized_url_mappings_transport_type = null
	generating = FALSE
	ensure_ready()

/// Only a temporary serialization buffer exists; the round retains the file resource.
/datum/asset/cyborg_model_gallery/proc/json_resource(list/data)
	var/static/file_serial = 0
	var/filename = "data/cyborg-gallery-[world.port]-[++file_serial].json"
	var/resource
	var/exception/failure
	try
		var/write_error = write_json(json_encode(data), filename)
		if(length(write_error))
			throw EXCEPTION("Could not write public cyborg gallery asset: [write_error]")
		resource = fcopy_rsc(filename)
	catch(var/exception/error)
		failure = error
	fdel(filename)
	if(failure)
		throw failure
	if(!resource)
		throw EXCEPTION("Could not create public cyborg gallery asset")
	return resource

/// rust-g reports write failures as nonempty text, not a success boolean.
/datum/asset/cyborg_model_gallery/proc/write_json(encoded_data, filename)
	return rustg_file_write(encoded_data, filename)

/// Reuse an identical current item without registering new global/preload entries.
/datum/asset/cyborg_model_gallery/proc/owned_asset(asset_name, resource, content_hash)
	var/datum/asset_cache_item/current = assets[asset_name]
	if(current?.hash == content_hash)
		return current
	return new /datum/asset_cache_item(asset_name, resource, content_hash)

/// Unknown departments select only the finite catalog, never a new resource.
/datum/asset/cyborg_model_gallery/proc/assets_for_department(department)
	. = list()
	.[catalog_asset] = assets[catalog_asset]
	var/department_asset = department_assets[department]
	if(department_asset)
		.[department_asset] = assets[department_asset]

/// Called before private state is captured. Native acquisition can yield while flushing.
/datum/asset/cyborg_model_gallery/proc/send_to_viewer(mob/user, department)
	var/list/requested_assets = assets_for_department(department)
	for(var/asset_name in requested_assets)
		var/datum/asset_cache_item/asset = requested_assets[asset_name]
		if(SSassets.cache[asset_name] != asset)
			SSassets.transport.register_asset(asset_name, asset)
	if(user?.client && SSassets.transport.send_assets(user.client, requested_assets))
		return user.client.browse_queue_flush()
	return TRUE

/// No waits or generation here: the preflight already acquired this public selection.
/datum/asset/cyborg_model_gallery/proc/ui_descriptor(department)
	. = list("generation" = generation, "catalog_url" = SSassets.transport.get_asset_url(catalog_asset, assets[catalog_asset]))
	var/department_asset = department_assets[department]
	if(department_asset)
		.["department"] = department
		.["thumbnails_url"] = SSassets.transport.get_asset_url(department_asset, assets[department_asset])

/datum/asset/cyborg_model_gallery/get_url_mappings()
	. = list()
	for(var/asset_name in assets)
		var/datum/asset_cache_item/asset = assets[asset_name]
		.[asset_name] = SSassets.transport.get_asset_url(asset_name, asset)

/datum/asset/cyborg_model_gallery/unregister()
	for(var/asset_name in assets)
		var/datum/asset_cache_item/asset = assets[asset_name]
		if(SSassets.cache[asset_name] == asset)
			SSassets.transport.unregister_asset(asset_name)
	catalog = null
	generation = null
	catalog_asset = null
	department_assets = list()
	assets = list()
	generation_failure = null

/// Body previews use immutable resources, never world mobs. A bounded FIFO caches PNGs.
/proc/cyborg_preview_body(list/descriptor, direction = SOUTH, pose = "idle", occlusion = FALSE, frame = 1, moving = FALSE, use_cache = TRUE)
	var/static/list/images = list()
	var/static/cache_bytes = 0
	if(!descriptor)
		return null
	if(!(direction in GLOB.cardinals))
		direction = SOUTH
	if(!(pose in descriptor["poses"]))
		pose = "idle"
	var/cache_key = "[descriptor["id"]]|[direction]|[pose]|[occlusion]|[frame]|[moving]"
	if(use_cache && images[cache_key])
		return images[cache_key]
	var/state = descriptor["icon_state"]
	if(pose != "idle")
		state += "-[pose]"
	var/resource = descriptor["icon"]
	if(occlusion)
		if(!cyborg_animation_anchor(descriptor, direction, pose))
			return null
		resource = cyborg_occlusion_cached(resource, descriptor["icon_state"])
		if(!resource)
			return null
	var/icon/body = icon(resource, state, direction, frame, moving)
	var/data = icon2base64(body)
	if(!use_cache)
		return data
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

/proc/cyborg_preview_layers(datum/preferences/preferences, list/descriptor, list/layout, direction, pose, arousal_state, use_saved_choices = FALSE, list/cached_icons)
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
	var/list/layers = cyborg_build_appearance(descriptor, layout, list("choices" = choices, "active" = active, "arousal" = arousal, "direction" = direction, "pose" = pose, "cached_icons" = cached_icons))
	for(var/list/layer as anything in layers)
		layer -= "resource"
	return layers
