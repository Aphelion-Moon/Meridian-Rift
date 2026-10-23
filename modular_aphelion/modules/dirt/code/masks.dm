/// The colour a role's pixels take in its greyscale mask. Haze is half covered in the film mask.
#define DIRT_MASK_SOLID "#FFFFFF"
#define DIRT_MASK_HALF "#FFFFFF80"

/**
 * One climax's mark: a variant of a zone's semen at a level. More climaxes on the zone raise the level; past the top
 * one, another splat starts.
 */
/datum/dirt_splat
	/// A DIRT_ZONE_* define.
	var/zone
	/// 1 to DIRT_SEMEN_MAX_LEVEL.
	var/level
	/// 0 to DIRT_SEMEN_VARIANTS - 1.
	var/variant
	/// When it landed, from SSdirt.next_serial(): the lowest goes first past the cap.
	var/serial

/**
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - level: 1 to DIRT_SEMEN_MAX_LEVEL.
 * - variant: 0 to DIRT_SEMEN_VARIANTS - 1.
 * - serial: From SSdirt.next_serial().
 */
/datum/dirt_splat/New(zone, level, variant, serial)
	. = ..()
	src.zone = zone
	src.level = level
	src.variant = variant
	src.serial = serial

/**
 * What a surface's masks are made from: the body they're drawn on and the splats on it. Requests with the same mask_key()
 * share their masks, so bodies drawn from the same sprites with the same splats draw the same icons. A request is made
 * once and never changed: it keeps copies of the splats, so a splat that levels up or lands while its masks wait in the
 * queue changes neither the key nor what's drawn under it.
 */
/datum/dirt_mask_request
	/// What it's drawn on: DIRT_MASKS_BODY, DIRT_MASKS_PART or DIRT_MASKS_TAUR.
	var/kind
	/// The body's sprites, as dirt_zone_sources() returns them: its template's.
	var/list/zone_sources
	/// DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
	var/surface_kind
	/// Copies of the surface's /datum/dirt_splat as they were when it was made, oldest first. They merge in this order.
	var/list/splats
	/// The parts drawn under the surface, which shape its semen. None are drawn yet.
	var/list/under_parts
	/// The part a part's masks are drawn on. None are drawn yet.
	var/part_source
	/// The taur body a taur's masks are drawn on. None are drawn yet.
	var/taur_source

/**
 * Arguments:
 * - kind: DIRT_MASKS_BODY, DIRT_MASKS_PART or DIRT_MASKS_TAUR.
 * - zone_sources: The body's sprites, as dirt_zone_sources() returns them.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - splats: The surface's /datum/dirt_splat, oldest first. Copied: the request never reads them again.
 * - under_parts, part_source, taur_source: Parts and taurs, which aren't drawn yet.
 */
/datum/dirt_mask_request/New(kind, list/zone_sources, surface_kind, list/splats, list/under_parts, part_source, taur_source)
	. = ..()
	src.kind = kind
	src.zone_sources = zone_sources
	src.surface_kind = surface_kind
	src.splats = list()
	for(var/datum/dirt_splat/splat as anything in splats)
		src.splats += new /datum/dirt_splat(splat.zone, splat.level, splat.variant, splat.serial)
	src.under_parts = under_parts || list()
	src.part_source = part_source
	src.taur_source = taur_source

/**
 * Returns the masks' key: an MD5 of what they're drawn on and each splat's zone, level and variant in order. Serials
 * stay out of it, so splats that landed apart draw alike.
 *
 * Crashes:
 * - On a request with parts or a taur, which aren't drawn yet.
 */
/datum/dirt_mask_request/proc/mask_key()
	if(length(under_parts) || part_source || taur_source)
		CRASH("Dirt masks with parts or a taur aren't drawn yet.")
	var/list/parts = list(kind, dirt_template_key(zone_sources), surface_kind)
	for(var/datum/dirt_splat/splat as anything in splats)
		parts += "[splat.zone]:[splat.level]:[splat.variant]"
	return md5(jointext(parts, "|"))

/**
 * A surface's masks, one greyscale four-direction icon per tone role, registered in the resource cache. Each is drawn as
 * an overlay tinted with its role's colour and alpha (dirt_semen_role_colour()). Haze is half covered in the film mask.
 */
/datum/dirt_masks
	/// The request's mask_key().
	var/key
	/// For skin: alist(limb zone = alist(DIRT_ROLE_* define = icon)), each limb's clipped to the pixels its image shows.
	var/alist/roles_by_limb = alist()
	/// For cloth: alist(DIRT_ROLE_* define = icon), the whole canvas, which the garment's own pixels clip.
	var/alist/roles = alist()
	/// For a taur body: alist(layer = alist(DIRT_ROLE_* define = icon)). None are drawn yet.
	var/alist/roles_by_layer = alist()

/**
 * Arguments:
 * - key: The request's mask_key().
 */
/datum/dirt_masks/New(key)
	. = ..()
	src.key = key

/**
 * Makes a request's masks a piece at a time (next_piece()): each splat rasterised in each direction, a piece apiece,
 * unless an earlier job left that splat rasterised on the same template (SSdirt.rasters); then each direction's splats
 * merged (dirt_merge()); then the icons. Its template is built first, by its own job queued ahead of it. While it waits,
 * its place in SSdirt.masks holds the job itself, so a body asking meanwhile waits for it (wait()) rather than queueing
 * it again.
 */
/datum/dirt_mask_job
	parent_type = /datum/dirt_job
	/// What it makes.
	var/datum/dirt_mask_request/request
	/// The request's mask_key().
	var/key
	/// Where its template comes from, from SSdirt.template_for(): the template, the job building it, or FALSE.
	var/template_source
	/// The template, once its turn comes.
	var/datum/dirt_template/template
	/// Each splat's rasters in the request's order, each alist(direction = /datum/dirt_pixels/proc/drawn() of it).
	var/list/splat_rasters
	/// The next splat to rasterise.
	var/next_splat = 1
	/// alist(direction = /datum/dirt_pixels): each direction's splats merged.
	var/alist/merged = alist()
	/// What it made.
	var/datum/dirt_masks/masks
	/// Weak references to the bodies that drew without the masks while this waited -> DIRT_REDRAW_* flags.
	var/list/waiters

/**
 * Arguments:
 * - request: What it makes.
 * - key: The request's mask_key().
 */
/datum/dirt_mask_job/New(datum/dirt_mask_request/request, key)
	. = ..()
	src.request = request
	src.key = key

/// Four rasters a splat, a piece that finds only cached splats left, four merges and the icons.
/datum/dirt_mask_job/most_pieces()
	return 4 * length(request.splats) + 6

/**
 * Notes a body that drew without the masks while this waits, to draw it again once they're made. A body being deleted
 * isn't drawn again.
 *
 * Arguments:
 * - body: The body.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/datum/dirt_mask_job/proc/wait(mob/living/carbon/human/body, redraw_flags)
	var/datum/weakref/body_ref = WEAKREF(body)
	if(!body_ref || !redraw_flags)
		return
	LAZYINITLIST(waiters)
	waiters[body_ref] |= redraw_flags

/**
 * Makes the next piece of the masks: one splat rasterised in one direction, one direction's splats merged, or the icons.
 *
 * Returns:
 * - TRUE: The masks are made, or can't be (failed).
 * - FALSE: Pieces are left.
 *
 * Crashes:
 * - On a part's or a taur's request, which aren't drawn yet.
 */
/datum/dirt_mask_job/next_piece()
	if(!template)
		if(istype(template_source, /datum/dirt_template_job))
			var/datum/dirt_template_job/template_job = template_source
			template = template_job.built()
		else if(template_source)
			template = template_source
		if(!template)
			failed = TRUE
			return TRUE
		if(request.kind != DIRT_MASKS_BODY)
			CRASH("[request.kind] dirt masks aren't drawn yet.")
		splat_rasters = new /list(length(request.splats))
	if(next_splat <= length(request.splats))
		rasterise_next()
		return FALSE
	for(var/direction in dirt_mask_directions())
		if(!merged[direction])
			merge(direction)
			return FALSE
	masks = request.surface_kind == DIRT_SURFACE_SKIN ? limb_masks() : canvas_masks()
	return TRUE

/**
 * Rasterises the next splat in the next direction it lacks, after taking the splats already rasterised on this template
 * from SSdirt.rasters, which cost no piece. A splat rasterised in every direction goes in SSdirt.rasters.
 */
/datum/dirt_mask_job/proc/rasterise_next()
	for(var/turn in next_splat to length(request.splats))
		var/datum/dirt_splat/splat = request.splats[next_splat]
		var/raster_key = "[template.key]|[request.surface_kind]|[splat.zone]:[splat.level]:[splat.variant]"
		var/alist/rasters = splat_rasters[next_splat]
		if(!rasters)
			rasters = SSdirt.rasters.fetch(raster_key)
			if(rasters)
				splat_rasters[next_splat] = rasters
				next_splat++
				continue
			rasters = alist()
			splat_rasters[next_splat] = rasters
		for(var/direction in dirt_mask_directions())
			if(rasters[direction])
				continue
			var/datum/dirt_pixels/drawn = dirt_rasterise_aimed(splat.zone, splat.level, splat.variant, request.surface_kind, template.surfaces[direction])
			rasters[direction] = drawn.drawn()
			if(direction == WEST)
				SSdirt.rasters.store_value(raster_key, rasters)
				next_splat++
			return

/**
 * Merges one direction's splats into one mask, the thickest winning each pixel.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/merge(direction)
	var/datum/dirt_surface/surface = template.surfaces[direction]
	var/list/pixel_maps = list()
	for(var/alist/rasters as anything in splat_rasters)
		pixel_maps += dirt_pixels_from_drawn(rasters[direction], surface.width, surface.height)
	merged[direction] = length(pixel_maps) ? dirt_merge(pixel_maps) : new /datum/dirt_pixels(surface.width, surface.height)

/**
 * Returns the masks for skin: each limb's clipped to the pixels its image shows, so nothing floats in the margin past
 * the body, and each limb's overlay draws only on its own limb.
 */
/datum/dirt_mask_job/proc/limb_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	for(var/zone, by_direction in template.silhouettes)
		var/alist/roles = dirt_role_icons(merged, by_direction)
		if(length(roles))
			made.roles_by_limb[zone] = roles
	return made

/**
 * Returns the masks for cloth: the whole canvas, which the garment's own pixels clip.
 */
/datum/dirt_mask_job/proc/canvas_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	made.roles = dirt_role_icons(merged)
	return made

/**
 * Returns the directions a mask is made in, in the order its pieces go. You should NEVER modify it.
 */
/proc/dirt_mask_directions()
	RETURN_TYPE(/list)
	var/static/list/directions = list(SOUTH, NORTH, EAST, WEST)
	return directions

/**
 * Returns a mask's drawn pixels alone, which is all a cached raster keeps: list(indexes, roles, thicknesses, covers),
 * three lists in step, indexes in row-major order, then whether it covers.
 */
/datum/dirt_pixels/proc/drawn()
	RETURN_TYPE(/list)
	var/list/indexes = list()
	var/list/drawn_roles = list()
	var/list/drawn_thicknesses = list()
	for(var/index in 1 to length(roles))
		var/role = roles[index]
		if(role)
			indexes += index
			drawn_roles += role
			drawn_thicknesses += thicknesses[index]
	return list(indexes, drawn_roles, drawn_thicknesses, covers)

/**
 * Returns a mask made again from its drawn pixels.
 *
 * Arguments:
 * - drawn: From /datum/dirt_pixels/proc/drawn().
 * - width: Pixels across.
 * - height: Pixels down.
 */
/proc/dirt_pixels_from_drawn(list/drawn, width, height)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/pixel_map = new(width, height)
	var/list/indexes = drawn[1]
	var/list/drawn_roles = drawn[2]
	var/list/drawn_thicknesses = drawn[3]
	for(var/position in 1 to length(indexes))
		var/index = indexes[position]
		pixel_map.roles[index] = drawn_roles[position]
		pixel_map.thicknesses[index] = drawn_thicknesses[position]
	pixel_map.covers = drawn[4]
	return pixel_map

/**
 * Returns a surface's masks as icons: alist(DIRT_ROLE_* define = registered four-direction icon), one for each role
 * drawn, haze half covered in the film mask's.
 *
 * Arguments:
 * - merged: alist(direction = /datum/dirt_pixels), the surface's semen in each direction.
 * - shown: alist(direction = indexes): only these pixels are drawn, or null for the whole canvas.
 */
/proc/dirt_role_icons(alist/merged, alist/shown)
	RETURN_TYPE(/alist)
	// role -> alist(direction -> runs)
	var/alist/runs = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/pixel_map = merged[direction]
		var/list/indexes = shown ? shown[direction] : null
		if(!shown)
			indexes = list()
			for(var/index in 1 to length(pixel_map.roles))
				if(pixel_map.roles[index])
					indexes += index
		dirt_role_runs(pixel_map, indexes, direction, runs)
	var/alist/icons = alist()
	for(var/role, by_direction in runs)
		icons[role] = dirt_mask_icon(by_direction)
	return icons

/**
 * Adds a mask's horizontal runs in one direction to each role's: list(icon y, first icon x, last icon x, colour), one
 * DrawBox() each. A run is a role's pixels side by side in one row at one coverage.
 *
 * Arguments:
 * - pixel_map: The mask.
 * - indexes: The pixels to draw, in row-major order.
 * - direction: The direction it's seen from.
 * - runs: alist(DIRT_ROLE_* define = alist(direction = runs)), added to.
 */
/proc/dirt_role_runs(datum/dirt_pixels/pixel_map, list/indexes, direction, alist/runs)
	var/list/roles = pixel_map.roles
	var/width = pixel_map.width
	// role -> its run being drawn, or null
	var/alist/open = alist()
	for(var/index in indexes)
		var/role = roles[index]
		if(!role)
			continue
		var/colour = role == DIRT_ROLE_HAZE ? DIRT_MASK_HALF : DIRT_MASK_SOLID
		if(role == DIRT_ROLE_HAZE)
			role = DIRT_ROLE_FILM
		var/row = floor((index - 1) / width)
		var/icon_x = index - row * width
		var/icon_y = pixel_map.height - row
		var/list/run = open[role]
		if(run && run[1] == icon_y && run[3] == icon_x - 1 && run[4] == colour)
			run[3] = icon_x
			continue
		if(run)
			dirt_add_run(runs, role, direction, run)
		open[role] = list(icon_y, icon_x, icon_x, colour)
	for(var/role, run in open)
		dirt_add_run(runs, role, direction, run)

/**
 * Adds one run to a role's in one direction.
 *
 * Arguments:
 * - runs: alist(DIRT_ROLE_* define = alist(direction = runs)).
 * - role: The role.
 * - direction: The direction.
 * - run: list(icon y, first icon x, last icon x, colour).
 */
/proc/dirt_add_run(alist/runs, role, direction, list/run)
	var/alist/by_direction = runs[role]
	if(!by_direction)
		by_direction = alist()
		runs[role] = by_direction
	var/list/direction_runs = by_direction[direction]
	if(!direction_runs)
		direction_runs = list()
		by_direction[direction] = direction_runs
	direction_runs += list(run)

/**
 * Returns one role's mask as a four-direction icon on a blank state, one DrawBox() per run, registered in the resource
 * cache as bulge_register_icon() registers an icon built at run time.
 *
 * Arguments:
 * - by_direction: alist(direction = runs), from dirt_role_runs().
 */
/proc/dirt_mask_icon(alist/by_direction)
	var/icon/blank = bulge_blank_tile()
	var/icon/mask = icon(blank)
	for(var/direction in dirt_mask_directions())
		var/icon/frame = icon(blank)
		for(var/list/run as anything in by_direction[direction])
			frame.DrawBox(run[4], run[2], run[1], run[3], run[1])
		mask.Insert(frame, "", direction)
	return bulge_register_icon(mask)

#undef DIRT_MASK_SOLID
#undef DIRT_MASK_HALF
