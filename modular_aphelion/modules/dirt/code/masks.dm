/// How much of a pixel a role's run covers, out of 255 (dirt_role_runs()). Haze is film at half.
#define DIRT_MASK_SOLID 255
#define DIRT_MASK_HALF 128

/**
 * One shot's mark: a variant of a zone's mess at a level. More shots on the zone raise the level; past the top
 * one, another splat starts.
 */
/datum/dirt_splat
	/// A DIRT_ZONE_* define.
	var/zone
	/// 1 to DIRT_MESS_MAX_LEVEL.
	var/level
	/// 0 to DIRT_MESS_VARIANTS - 1.
	var/variant
	/// When it landed, from SSdirt.next_serial(): the lowest goes first past the cap.
	var/serial

/**
 * Arguments:
 * - zone: A DIRT_ZONE_* define.
 * - level: 1 to DIRT_MESS_MAX_LEVEL.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1.
 * - serial: From SSdirt.next_serial().
 */
/datum/dirt_splat/New(zone, level, variant, serial)
	. = ..()
	src.zone = zone
	src.level = level
	src.variant = variant
	src.serial = serial

/**
 * What a surface's masks are made from: the body they're drawn on and the splats on it. Requests with the same
 * mask_key() share their masks, so bodies drawn from the same sprites with the same splats draw the same icons. A
 * request is made once and never changed: it keeps copies of the splats, so a splat that levels up or lands while its
 * masks wait in the queue changes neither the key nor what's drawn under it.
 */
/datum/dirt_mask_request
	/// What it's drawn on: DIRT_MASKS_BODY, DIRT_MASKS_PART or DIRT_MASKS_TAUR.
	var/kind
	/// The body's sprites, as dirt_zone_sources() returns them: its template's. On a taur, the rider's.
	var/list/zone_sources
	/// DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH. A taur body's pools are drawn per layer on skin (on the taur body's own
	/// images), on cloth over the whole canvas (inset on a taur suit).
	var/surface_kind
	/// Copies of the surface's /datum/dirt_splat as they were when it was made, oldest first. They merge in this order.
	var/list/splats
	/// The parts the splats reach, each a /datum/dirt_part_source, lowest first. They drop the mess's level below the
	/// top one, which keeps its glaze, and it leaves out the rounded ones' pixels; in each direction a part drawn under
	/// the surface (/datum/dirt_part_source/proc/under()) has its own mess drawn in these masks, and one drawn
	/// over it on itself.
	var/list/parts
	/// The layer of the surface the masks are drawn on, which the parts are drawn under or over.
	var/surface_layer
	/// For a part's masks, the part they're drawn on: their mess keeps to its pixels.
	var/datum/dirt_part_source/part_source
	/// For a part's masks, the directions it draws its share in, where it shows over what it lies on;
	/// null for all four.
	var/list/facings
	/// For a taur body's pools, the taur body they're drawn on.
	var/datum/dirt_taur_source/taur_source
	/// For skin, the sprites worn over it, from dirt_cover_sprites(): its mess fades out beside them.
	var/list/cover
	/// For cloth on underclothes, the sprites its mess is kept to, each list(icon, icon state)...
	var/list/clip
	/// ...less the pixels of these, drawn over them.
	var/list/cut

/**
 * Arguments:
 * - kind: DIRT_MASKS_BODY, DIRT_MASKS_PART or DIRT_MASKS_TAUR.
 * - zone_sources: The body's sprites, as dirt_zone_sources() returns them. A part's masks need them only for the vulva
 *   on skin, which takes the ring of the body round it.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH. For a part, what it lies on.
 * - splats: The surface's /datum/dirt_splat, oldest first. Copied: the request never reads them again.
 * - parts: The parts the splats reach, lowest first, from dirt_surface_parts(), or null.
 * - part_source: For a part's masks, the part.
 * - taur_source: For a taur body's pools, the taur body.
 * - cover: The sprites worn over skin, from dirt_cover_sprites(), or null.
 * - clip: The sprites cloth's mess is kept to, each list(icon, icon state), or null for the whole canvas.
 * - cut: The sprites drawn over `clip`'s, in the same form, or null.
 * - surface_layer: The surface's layer: a garment's, DIRT_UNDERCLOTHES_LAYER or DIRT_SKIN_LAYER.
 * - facings: For a part's masks, the directions it draws its share in, or null for all four.
 */
/datum/dirt_mask_request/New(kind, list/zone_sources, surface_kind, list/splats, list/parts, datum/dirt_part_source/part_source, datum/dirt_taur_source/taur_source, list/cover, list/clip, list/cut, surface_layer, list/facings)
	. = ..()
	src.kind = kind
	src.zone_sources = zone_sources
	src.surface_kind = surface_kind
	src.splats = list()
	for(var/datum/dirt_splat/splat as anything in splats)
		src.splats += new /datum/dirt_splat(splat.zone, splat.level, splat.variant, splat.serial)
	src.parts = parts || list()
	src.surface_layer = surface_layer
	src.part_source = part_source
	src.facings = facings
	src.taur_source = taur_source
	src.cover = cover
	src.clip = clip
	src.cut = cut

/**
 * Returns the masks' key: an MD5 of what they're drawn on, each splat's zone, level and variant in order, the sprites
 * that fade or keep them, and the parts that shape them, each with where it draws against the surface in each
 * direction, or the part or taur body they're drawn on and the directions it draws in. Serials stay out of it, so
 * splats that landed apart draw alike. A part's splats count at the level they draw at. A taur body's count at their
 * own: the rider's mess its pools keep clear of is drawn at it.
 */
/datum/dirt_mask_request/proc/mask_key()
	var/list/key_parts = list(kind, zone_sources ? dirt_template_key(zone_sources) : "", surface_kind)
	for(var/datum/dirt_splat/splat as anything in splats)
		key_parts += "[splat.zone]:[kind == DIRT_MASKS_PART ? min(splat.level, DIRT_PART_MAX_LEVEL) : splat.level]:[splat.variant]"
	// only when there are any, so masks without them keep their keys
	if(length(cover))
		key_parts += "cover:[dirt_sprites_key(cover)]"
	if(length(clip))
		key_parts += "clip:[dirt_sprites_key(clip)]|cut:[dirt_sprites_key(cut)]"
	if(length(parts))
		key_parts += "parts:[dirt_parts_key(parts, surface_layer)]"
	if(part_source)
		key_parts += "part:[part_source.part_key()]"
	if(taur_source)
		key_parts += "taur:[taur_source.taur_key()]"
	if(facings)
		key_parts += "facing:[jointext(facings, ",")]"
	// the masks are baked in mess's tints (dirt_mess_role_tints()): a second material would add its own name here
	return md5(jointext(key_parts, "|"))

/// Returns every part the request reads: the parts its splats reach, or the part its masks are drawn on.
/datum/dirt_mask_request/proc/read_parts()
	RETURN_TYPE(/list)
	return part_source ? list(part_source) : parts

/**
 * Returns the sprites a request reads besides its template, each list(icon, icon state, what for): "cover", "clip" or
 * "cut".
 */
/datum/dirt_mask_request/proc/read_sprites()
	RETURN_TYPE(/list)
	. = list()
	for(var/purpose, purpose_sprites in list("cover" = cover, "clip" = clip, "cut" = cut))
		for(var/list/sprite as anything in purpose_sprites)
			. += list(list(sprite[1], sprite[2], purpose))

/**
 * A surface's masks: its mess baked into four-direction RGBA icons (dirt_baked_icon()), registered in the resource
 * cache, each drawn as it is (dirt_mess_baked_image()).
 */
/datum/dirt_masks
	/// The request's mask_key().
	var/key
	/// For skin: alist(limb zone = baked icon), each limb's clipped to the pixels its image shows.
	var/alist/baked_by_limb = alist()
	/// For skin: alist(limb zone = an MD5 of what its baked icon draws, dirt_runs_key()), so only a limb whose pixels
	/// changed caches new images.
	var/alist/limb_keys = alist()
	/// For cloth: the baked icon on the whole canvas, which the garment's own pixels clip. For a part, the same, already
	/// kept to the part's pixels. Null when it draws nothing.
	var/baked
	/// For a taur body's pools: alist(EXTERNAL_* layer = baked icon), each on the taur canvas, kept to the pixels that
	/// layer shows (dirt_taur_owners()). A taur suit draws them from `baked`, over the whole canvas.
	var/alist/baked_by_layer = alist()

/**
 * Arguments:
 * - key: The request's mask_key().
 */
/datum/dirt_masks/New(key)
	. = ..()
	src.key = key

/**
 * Makes a request's masks a piece at a time (next_piece()). While it waits, SSdirt.mask_jobs holds it under its key,
 * so a body asking meanwhile waits for it (wait()) rather than queueing it again.
 */
/datum/dirt_mask_job
	parent_type = /datum/dirt_job
	/// What it makes.
	var/datum/dirt_mask_request/request
	/// The request's mask_key().
	var/key
	/// Where its template comes from, from SSdirt.template_for(): the template, the job building it, or FALSE. Null for
	/// a part's masks that need none.
	var/template_source
	/// The template, once its turn comes.
	var/datum/dirt_template/template
	/// Whether its first piece has found its template and set it up.
	var/started = FALSE
	/// The request's read_parts().
	var/list/parts
	/// The next part to read.
	var/next_part = 1
	/// alist(direction = alist(/datum/dirt_part_source = its pixels there, from dirt_part_own())).
	var/alist/part_owns = alist()
	/// Each splat's rasters in the request's order, each alist(direction = /datum/dirt_pixels/proc/drawn() of it). For
	/// a part, alist(direction = /datum/dirt_pixels).
	var/list/splat_rasters
	/// The next splat to rasterise.
	var/next_splat = 1
	/// alist(direction = /datum/dirt_pixels): each direction's splats merged.
	var/alist/merged = alist()
	/// What it made.
	var/datum/dirt_masks/masks
	/// Weak references to the bodies that drew without the masks while this waited -> DIRT_REDRAW_* flags.
	var/list/waiters
	/// The request's read_sprites(), read one a piece.
	var/list/sprites
	/// The next sprite to read.
	var/next_sprite = 1
	/// What the sprites read cover:
	/// alist("cover", "clip" or "cut" = alist(direction = list of TRUE or null per pixel)).
	var/alist/sprite_pixels = alist()
	/// For a taur body's pools: alist(direction = what each pixel of the taur canvas shows, from dirt_taur_owners()).
	var/alist/taur_owners = alist()
	/// The sprite directions its parts or taur body are read from, each list(sheet, state, direction, width), from
	/// wanted_reads().
	var/list/wanted_sprites
	/// The next of them to look for in SSdirt.sprite_reads.
	var/next_read = 1

/**
 * Arguments:
 * - request: What it makes.
 * - key: The request's mask_key().
 */
/datum/dirt_mask_job/New(datum/dirt_mask_request/request, key)
	. = ..()
	src.request = request
	src.key = key

/// A piece a sprite direction of its parts or taur body read, then a piece a part read, four rasters a splat, a piece
/// that finds only cached splats left, four merges, a piece a sprite read and the icons. A taur body's after its reads:
/// four canvas reads, three pieces a splat in each direction (the rider's mess on cloth and on skin, then the pools), a
/// piece that finds only cached splats left, four merges and the icons.
/datum/dirt_mask_job/most_pieces()
	var/reads = length(wanted_sprites || wanted_reads())
	if(request.kind == DIRT_MASKS_TAUR)
		return reads + 12 * length(request.splats) + 10
	return reads + 4 * length(request.splats) + 6 + length(request.cover) + length(request.clip) + length(request.cut) + length(request.read_parts())

/**
 * Returns the sprite directions the request's parts or taur body are read from, each list(sheet, state, direction,
 * width): every state of each in every direction.
 */
/datum/dirt_mask_job/proc/wanted_reads()
	RETURN_TYPE(/list)
	. = list()
	if(request.kind == DIRT_MASKS_TAUR)
		var/datum/dirt_taur_source/source = request.taur_source
		for(var/direction in dirt_mask_directions())
			for(var/layer_key, states in source.layer_states)
				for(var/state in states)
					. += list(list(source.icon, state, direction, DIRT_TAUR_WIDTH))
		return
	for(var/datum/dirt_part_source/source as anything in request.read_parts())
		for(var/direction in dirt_mask_directions())
			for(var/state in source.states)
				. += list(list(source.icon, state, direction, ICON_SIZE_X))

/**
 * Reads the next sprite direction the job's parts or taur body are read from that SSdirt.sprite_reads doesn't hold, so
 * the pieces after find them all read: a horse taur draws six states and a part up to three, each read whole in four
 * directions.
 *
 * Returns whether it read one.
 */
/datum/dirt_mask_job/proc/read_wanted_sprite()
	for(var/turn in next_read to length(wanted_sprites))
		var/list/wanted = wanted_sprites[next_read++]
		if(!SSdirt.sprite_reads.fetch(dirt_sprite_read_key(wanted[1], wanted[2], wanted[3], wanted[4])))
			dirt_sprite_pixels(wanted[1], wanted[2], wanted[3], wanted[4])
			return TRUE
	return FALSE

/**
 * Returns the template it's drawn on once that's built, or null.
 */
/datum/dirt_mask_job/proc/held_template()
	RETURN_TYPE(/datum/dirt_template)
	if(template)
		return template
	if(istype(template_source, /datum/dirt_template_job))
		var/datum/dirt_template_job/template_job = template_source
		return template_job.built()
	return istype(template_source, /datum/dirt_template) ? template_source : null

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
 * Makes the next piece of the masks: one sprite direction of its parts or taur body read, one part's pixels read, one
 * splat rasterised in one direction (on a part, in every direction), one direction's splats merged, one sprite worn
 * over or under them read, or the icons. A taur body's pools go by next_taur_piece().
 *
 * Returns:
 * - TRUE: The masks are made, or can't be (failed).
 * - FALSE: Pieces are left.
 */
/datum/dirt_mask_job/next_piece()
	if(!started)
		if(istype(template_source, /datum/dirt_template_job))
			var/datum/dirt_template_job/template_job = template_source
			template = template_job.built()
		else if(template_source)
			template = template_source
		if(!template && (request.zone_sources || request.kind != DIRT_MASKS_PART))
			failed = TRUE
			return TRUE
		started = TRUE
		splat_rasters = new /list(length(request.splats))
		sprites = request.read_sprites()
		parts = request.read_parts()
		wanted_sprites = wanted_reads()
		for(var/direction in dirt_mask_directions())
			part_owns[direction] = alist()
	if(read_wanted_sprite())
		return FALSE
	if(request.kind == DIRT_MASKS_TAUR)
		return next_taur_piece()
	if(next_part <= length(parts))
		read_part(parts[next_part++])
		return FALSE
	if(request.kind == DIRT_MASKS_PART)
		if(next_splat <= length(request.splats))
			rasterise_part(next_splat++)
			return FALSE
		for(var/direction in dirt_mask_directions())
			var/list/fields = list()
			for(var/alist/fields_by_direction as anything in splat_rasters)
				fields += fields_by_direction[direction]
			merged[direction] = length(fields) ? dirt_merge(fields) : new /datum/dirt_pixels
		masks = canvas_masks()
		return TRUE
	if(next_splat <= length(request.splats))
		rasterise_next()
		return FALSE
	for(var/direction in dirt_mask_directions())
		if(!merged[direction])
			merge(direction)
			return FALSE
	if(next_sprite <= length(sprites))
		read_sprite(sprites[next_sprite++])
		return FALSE
	masks = request.surface_kind == DIRT_SURFACE_SKIN ? limb_masks() : canvas_masks()
	return TRUE

/**
 * Makes the next piece of a taur body's pools, once its states are read (read_wanted_sprite()): what one direction of
 * the taur canvas shows (dirt_taur_owners()), one splat's pools in one direction or the rider's mess they keep clear of
 * (rasterise_taur()), one direction's pools merged, or the icons (taur_masks()).
 *
 * Returns:
 * - TRUE: The masks are made.
 * - FALSE: Pieces are left.
 */
/datum/dirt_mask_job/proc/next_taur_piece()
	for(var/direction in dirt_mask_directions())
		if(!taur_owners[direction])
			taur_owners[direction] = dirt_taur_owners(request.taur_source, template.surfaces[direction], direction)
			return FALSE
	if(next_splat <= length(request.splats))
		rasterise_taur()
		return FALSE
	for(var/direction in dirt_mask_directions())
		if(merged[direction])
			continue
		var/list/pixel_maps = list()
		for(var/alist/pools as anything in splat_rasters)
			pixel_maps += dirt_pixels_from_drawn(pools[direction], DIRT_TAUR_WIDTH, ICON_SIZE_Y)
		merged[direction] = length(pixel_maps) ? dirt_merge(pixel_maps) : new /datum/dirt_pixels(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
		return FALSE
	masks = taur_masks()
	return TRUE

/**
 * Makes the next splat's pools in the next direction it lacks, after taking the directions already made on this taur
 * body and rider from SSdirt.rasters, which cost no piece. The rider's mess they keep clear of, the splat at its own
 * level on the rider's cloth and skin, comes from SSdirt.rasters too, as the rider's own masks may have made it; each
 * one made here is a piece of its own. What's made goes in SSdirt.rasters.
 */
/datum/dirt_mask_job/proc/rasterise_taur()
	var/static/list/rider_surfaces = list(DIRT_SURFACE_CLOTH, DIRT_SURFACE_SKIN)
	for(var/turn in next_splat to length(request.splats))
		var/datum/dirt_splat/splat = request.splats[next_splat]
		splat_rasters[next_splat] ||= alist()
		var/alist/pools = splat_rasters[next_splat]
		var/raster_key = "taur|[request.taur_source.taur_key()]|[template.key]|[splat.level]:[splat.variant]"
		for(var/direction in dirt_mask_directions())
			if(pools[direction])
				continue
			var/cached = SSdirt.rasters.fetch_direction(raster_key, direction)
			if(cached)
				pools[direction] = cached
				continue
			var/list/rider_mess = list()
			for(var/surface_kind in rider_surfaces)
				var/rider_key = "[template.key]|[surface_kind]|[splat.zone]:[splat.level]:[splat.variant]"
				var/rider_cached = SSdirt.rasters.fetch_direction(rider_key, direction)
				if(!rider_cached)
					var/datum/dirt_pixels/rider_drawn = dirt_rasterise_aimed(splat.zone, splat.level, splat.variant, surface_kind, template.surfaces[direction])
					SSdirt.rasters.store_direction(rider_key, direction, rider_drawn.drawn())
					return
				rider_mess += list(rider_cached)
			var/datum/dirt_pixels/drawn = dirt_taur_pools(taur_owners[direction], rider_mess, splat.level, splat.variant, direction)
			pools[direction] = SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
			return
		next_splat++

/**
 * Returns a taur body's pools as masks on the taur canvas: on skin, each layer's kept to the pixels it shows; on cloth,
 * the whole canvas, which a taur suit's own pixels clip.
 */
/datum/dirt_mask_job/proc/taur_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	var/icon/blank = dirt_taur_blank()
	if(request.surface_kind == DIRT_SURFACE_CLOTH)
		made.baked = dirt_baked_icon(dirt_shown_runs(merged), blank, dirt_mess_role_tints())
		return made
	for(var/layer_key in dirt_taur_stack())
		if(layer_key == DIRT_TAUR_RIDER)
			continue
		var/alist/shown = alist()
		var/any_shown = FALSE
		for(var/direction in dirt_mask_directions())
			var/list/owners = taur_owners[direction]
			var/datum/dirt_pixels/pixel_map = merged[direction]
			var/list/indexes = list()
			for(var/index in 1 to length(owners))
				if(owners[index] == layer_key && pixel_map.roles[index])
					indexes += index
			shown[direction] = indexes
			if(length(indexes))
				any_shown = TRUE
		if(any_shown)
			made.baked_by_layer[layer_key] = dirt_baked_icon(dirt_shown_runs(merged, shown), blank, dirt_mess_role_tints())
	return made

/**
 * Reads the pixels a part takes its share on in every direction (dirt_part_own()).
 *
 * Arguments:
 * - source: The part.
 */
/datum/dirt_mask_job/proc/read_part(datum/dirt_part_source/source)
	for(var/direction in dirt_mask_directions())
		var/alist/owns = part_owns[direction]
		owns[source] = dirt_part_own(source, direction, template, parts, request.surface_kind)

/**
 * Rasterises one splat's field on a part's masks' part, in every direction.
 *
 * Arguments:
 * - position: The splat's place in the request.
 */
/datum/dirt_mask_job/proc/rasterise_part(position)
	var/datum/dirt_splat/splat = request.splats[position]
	var/datum/dirt_part_source/source = request.part_source
	var/alist/fields = alist()
	for(var/direction in dirt_mask_directions())
		if(request.facings && !(direction in request.facings))
			fields[direction] = new /datum/dirt_pixels
			continue
		var/alist/owns = part_owns[direction]
		fields[direction] = dirt_part_field(source.kind, owns[source], splat.zone, splat.level, splat.variant, direction)
	splat_rasters[position] = fields

/**
 * Adds a sprite's pixels in every direction to what its kind covers.
 *
 * Arguments:
 * - sprite: list(icon, icon state, "cover", "clip" or "cut"), from the request's read_sprites().
 */
/datum/dirt_mask_job/proc/read_sprite(list/sprite)
	sprite_pixels[sprite[3]] ||= alist()
	var/alist/by_direction = sprite_pixels[sprite[3]]
	for(var/direction in dirt_mask_directions())
		by_direction[direction] ||= new /list(ICON_SIZE_X * ICON_SIZE_Y)
		var/list/covered = by_direction[direction]
		for(var/index in dirt_sprite_pixels(sprite[1], sprite[2], direction))
			covered[index] = TRUE

/**
 * Rasterises the next splat in the next direction it lacks, at its level there (dirt_part_body_level()), after taking
 * the directions already rasterised at that level on this template from SSdirt.rasters, which cost no piece. Each
 * direction rasterised goes in SSdirt.rasters.
 */
/datum/dirt_mask_job/proc/rasterise_next()
	var/list/sources = request.parts
	for(var/turn in next_splat to length(request.splats))
		var/datum/dirt_splat/splat = request.splats[next_splat]
		splat_rasters[next_splat] ||= alist()
		var/alist/rasters = splat_rasters[next_splat]
		for(var/direction in dirt_mask_directions())
			if(rasters[direction])
				continue
			var/level = dirt_part_body_level(splat, sources, part_owns[direction])
			var/raster_key = "[template.key]|[request.surface_kind]|[splat.zone]:[level]:[splat.variant]"
			var/cached = SSdirt.rasters.fetch_direction(raster_key, direction)
			if(cached)
				rasters[direction] = cached
				continue
			var/datum/dirt_pixels/drawn = dirt_rasterise_aimed(splat.zone, level, splat.variant, request.surface_kind, template.surfaces[direction])
			rasters[direction] = SSdirt.rasters.store_direction(raster_key, direction, drawn.drawn())
			return
		next_splat++

/**
 * Merges one direction's splats into one mask, the thickest winning each pixel, with the parts drawn under and over the
 * surface (dirt_merge_with_parts()).
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_mask_job/proc/merge(direction)
	var/datum/dirt_surface/surface = template.surfaces[direction]
	var/list/pixel_maps = list()
	for(var/alist/rasters as anything in splat_rasters)
		pixel_maps += dirt_pixels_from_drawn(rasters[direction], surface.width, surface.height)
	if(!length(pixel_maps))
		merged[direction] = new /datum/dirt_pixels(surface.width, surface.height)
	else if(length(parts))
		var/list/split = dirt_split_parts(parts, request.surface_layer, direction)
		merged[direction] = dirt_merge_with_parts(pixel_maps, request.splats, split[1], split[2], part_owns[direction], direction)
	else
		merged[direction] = dirt_merge(pixel_maps)

/**
 * Returns the masks for skin: each limb's baked from its runs (limb_runs()).
 */
/datum/dirt_mask_job/proc/limb_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	for(var/zone, runs in limb_runs())
		made.baked_by_limb[zone] = dirt_baked_icon(runs, null, dirt_mess_role_tints())
		made.limb_keys[zone] = dirt_runs_key(runs)
	return made

/**
 * Returns skin's runs, once its pieces are made: alist(limb zone = dirt_shown_runs()), for each limb they draw on, each
 * clipped to the pixels its image shows, so nothing floats in the margin past the body, and each limb's overlay draws
 * only on its own limb. The chest's also takes the pixels past the body of the parts drawn under the skin there (a butt
 * in profile), which carry their share in the skin's mess: they're drawn with the chest.
 */
/datum/dirt_mask_job/proc/limb_runs()
	RETURN_TYPE(/alist)
	. = alist()
	var/alist/fades
	var/alist/covered = sprite_pixels["cover"]
	if(covered)
		fades = alist()
		for(var/direction in dirt_mask_directions())
			fades[direction] = dirt_cover_fades(merged[direction], covered[direction])
	for(var/zone, shown in template.silhouettes)
		if(zone == BODY_ZONE_CHEST && length(parts))
			shown = parts_past_body(shown)
		var/alist/runs = dirt_shown_runs(merged, shown, fades)
		if(length(runs))
			.[zone] = runs

/**
 * Returns the chest's pixels in each direction with the pixels past the body of the parts drawn under the skin there
 * added: alist(direction = indexes in row-major order).
 *
 * Arguments:
 * - chest: alist(direction = indexes), the pixels the chest's image shows.
 */
/datum/dirt_mask_job/proc/parts_past_body(alist/chest)
	RETURN_TYPE(/alist)
	var/alist/shown = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_surface/surface = template.surfaces[direction]
		var/list/flags_of = surface.flags_of
		var/alist/owns = part_owns[direction]
		var/list/added = new /list(ICON_SIZE_X * ICON_SIZE_Y)
		var/extra = FALSE
		for(var/datum/dirt_part_source/source as anything in parts)
			if(!source.under(direction, request.surface_layer))
				continue
			for(var/index in owns[source])
				if(!DIRT_PIXEL_ZONE(flags_of[index]))
					added[index] = TRUE
					extra = TRUE
		if(!extra)
			shown[direction] = chest[direction]
			continue
		for(var/index in chest[direction])
			added[index] = TRUE
		var/list/indexes = list()
		for(var/index in 1 to length(added))
			if(added[index])
				indexes += index
		shown[direction] = indexes
	return shown

/**
 * Returns the masks for cloth or a part: baked from canvas_runs().
 */
/datum/dirt_mask_job/proc/canvas_masks()
	RETURN_TYPE(/datum/dirt_masks)
	var/datum/dirt_masks/made = new(key)
	made.baked = dirt_baked_icon(canvas_runs(), null, dirt_mess_role_tints())
	return made

/**
 * Returns cloth's or a part's runs, once its pieces are made (dirt_shown_runs()): the whole canvas, which the
 * garment's own pixels clip, or on underclothes only the pixels they show.
 */
/datum/dirt_mask_job/proc/canvas_runs()
	RETURN_TYPE(/alist)
	var/alist/shown
	if(length(request.clip))
		shown = alist()
		var/alist/kept = sprite_pixels["clip"]
		var/alist/cut_off = sprite_pixels["cut"]
		for(var/direction in dirt_mask_directions())
			var/list/kept_pixels = kept[direction]
			var/list/cut_pixels = cut_off?[direction]
			var/list/indexes = list()
			for(var/index in 1 to length(kept_pixels))
				if(kept_pixels[index] && !cut_pixels?[index])
					indexes += index
			shown[direction] = indexes
	return dirt_shown_runs(merged, shown)

/**
 * Returns how near a mask's pixels lie to what's worn over them, where they fade out: alist(index = 1 beside it, or 2
 * one pixel further), for the pixels drawn that it leaves bare. Steps are up, down and across.
 *
 * Arguments:
 * - pixel_map: The mask.
 * - covered: Which pixels are worn over, a list of TRUE or null per pixel.
 */
/proc/dirt_cover_fades(datum/dirt_pixels/pixel_map, list/covered)
	RETURN_TYPE(/alist)
	var/alist/fades = alist()
	var/list/neighbours = dirt_neighbour_table(pixel_map.width, pixel_map.height)
	var/list/roles = pixel_map.roles
	for(var/index in 1 to length(roles))
		if(!roles[index] || covered[index])
			continue
		var/ring = 0
		for(var/near in neighbours[index])
			if(covered[near])
				ring = 1
				break
		if(!ring)
			for(var/near in neighbours[index])
				for(var/further in neighbours[near])
					if(covered[further])
						ring = 2
						break
				if(ring)
					break
		if(ring)
			fades[index] = ring
	return fades

/**
 * Returns the directions a mask is made in, in the order its pieces go. You should NEVER modify it.
 */
/proc/dirt_mask_directions()
	RETURN_TYPE(/list)
	var/static/list/directions = list(SOUTH, NORTH, EAST, WEST)
	return directions

/**
 * Returns a mask's drawn pixels alone, which is all a cached raster keeps, packed as text: "1" if it covers, else "0",
 * then three characters a drawn pixel, in row-major order, for its index, role and thickness (dirt_thickness_code()).
 * Equal masks pack as equal text. SSdirt.rasters keeps a splat's four directions joined in one text, its key's own.
 * Three base-64 characters hold indexes up to 2048, the 64x32 taur canvas: a bigger mask can't be packed.
 */
/datum/dirt_pixels/proc/drawn()
	var/static/list/digits
	if(!digits)
		digits = list()
		for(var/value in 0 to 63)
			digits += ascii2text(48 + value)
	var/list/chars = list(covers ? "1" : "0")
	for(var/index in 1 to length(roles))
		var/role = roles[index]
		if(!role)
			continue
		var/packed = (index - 1) * 128 + role * 16 + dirt_thickness_code(thicknesses[index])
		chars += digits[floor(packed / 4096) + 1]
		chars += digits[floor(packed / 64) % 64 + 1]
		chars += digits[packed % 64 + 1]
	return jointext(chars, "")

/**
 * Returns the code a thickness packs as in /datum/dirt_pixels/proc/drawn(), from 0: its place among the thicknesses
 * packed so far this round. A mask's thicknesses come from a handful of values.
 *
 * Arguments:
 * - thickness: The thickness.
 *
 * Crashes:
 * - Past 16 thicknesses, which a code can't hold.
 */
/proc/dirt_thickness_code(thickness)
	var/static/alist/codes = alist()
	var/code = codes[thickness]
	if(!isnull(code))
		return code
	var/list/thicknesses = dirt_packed_thicknesses()
	if(length(thicknesses) >= 16)
		CRASH("Dirt masks pack 16 thicknesses at most: [thickness] is the 17th.")
	thicknesses += thickness
	codes[thickness] = length(thicknesses) - 1
	return codes[thickness]

/**
 * Returns the thicknesses packed so far, indexed by their code + 1 (dirt_thickness_code()). You should NEVER modify it.
 */
/proc/dirt_packed_thicknesses()
	RETURN_TYPE(/list)
	var/static/list/thicknesses = list()
	return thicknesses

/**
 * Returns a mask made again from its drawn pixels.
 *
 * Arguments:
 * - drawn: From /datum/dirt_pixels/proc/drawn().
 * - width: Pixels across.
 * - height: Pixels down.
 */
/proc/dirt_pixels_from_drawn(drawn, width, height)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/pixel_map = new(width, height)
	var/list/thicknesses = dirt_packed_thicknesses()
	var/list/roles = pixel_map.roles
	var/list/drawn_thicknesses = pixel_map.thicknesses
	var/list/indexes = list()
	pixel_map.covers = text2ascii(drawn, 1) == 49
	pixel_map.drawn_indexes = indexes
	for(var/position = 2, position < length(drawn), position += 3)
		var/packed = (text2ascii(drawn, position) - 48) * 4096 + (text2ascii(drawn, position + 1) - 48) * 64 + text2ascii(drawn, position + 2) - 48
		var/index = floor(packed / 128) + 1
		indexes += index
		roles[index] = floor(packed / 16) % 8
		drawn_thicknesses[index] = thicknesses[packed % 16 + 1]
	return pixel_map

/**
 * Returns the indexes of a mask's drawn pixels, in row-major order.
 *
 * Arguments:
 * - drawn: From /datum/dirt_pixels/proc/drawn().
 */
/proc/dirt_drawn_indexes(drawn)
	RETURN_TYPE(/list)
	. = list()
	for(var/position = 2, position < length(drawn), position += 3)
		. += floor(((text2ascii(drawn, position) - 48) * 4096 + (text2ascii(drawn, position + 1) - 48) * 64) / 128) + 1

/**
 * Returns the roles runs are drawn in, one to a pixel, in the order they're baked: haze is film at half
 * (dirt_role_runs()). You should NEVER modify it.
 */
/proc/dirt_drawn_roles()
	RETURN_TYPE(/list)
	var/static/list/roles = list(DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_CORE, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	return roles

/**
 * Returns a surface's runs, as dirt_role_runs() lays them: alist(DIRT_ROLE_* define = alist(direction = runs)).
 *
 * Arguments:
 * - merged: alist(direction = /datum/dirt_pixels), the surface's mess in each direction.
 * - shown: alist(direction = indexes): only these pixels are drawn, or null for the whole canvas.
 * - fades: alist(direction = dirt_cover_fades()): pixels drawn fainter beside what's worn over them, or null.
 */
/proc/dirt_shown_runs(alist/merged, alist/shown, alist/fades)
	RETURN_TYPE(/alist)
	// role -> alist(direction -> runs)
	var/alist/runs = alist()
	for(var/direction in dirt_mask_directions())
		var/datum/dirt_pixels/pixel_map = merged[direction]
		var/list/indexes = shown ? shown[direction] : dirt_index_range(length(pixel_map.roles))
		dirt_role_runs(pixel_map, indexes, direction, runs, fades?[direction])
	return runs

/**
 * Returns runs baked into one four-direction RGBA icon on a blank state, registered in the resource cache as
 * bulge_register_icon() registers an icon built at run time, or null when they draw nothing. Each run is one DrawBox()
 * in its role's tint colour, at the tint's alpha times the run's level, rounded to 8 bits.
 *
 * Arguments:
 * - runs: From dirt_shown_runs().
 * - blank: A blank of the icon's size, or null for 32x32.
 * - tints: Each role's list(colour, alpha from 0 to 1), indexed by DIRT_ROLE_* define (dirt_mess_role_tints()).
 */
/proc/dirt_baked_icon(alist/runs, icon/blank, list/tints)
	if(!length(runs))
		return null
	blank ||= bulge_blank_tile()
	// the bake composites nothing, as a mask holds one role per pixel; a material whose roles could overlap on a pixel
	// would need compositing back
	var/icon/baked = icon(blank)
	// role * 256 + level -> rgb() text
	var/alist/colours = alist()
	for(var/direction in dirt_mask_directions())
		var/icon/frame = icon(blank)
		for(var/role in dirt_drawn_roles())
			var/alist/by_direction = runs[role]
			for(var/list/run as anything in by_direction?[direction])
				var/colour_key = role * 256 + run[4]
				var/colour = colours[colour_key]
				if(!colour)
					var/list/tint = tints[role]
					var/list/channels = rgb2num(tint[1])
					var/alpha = tint[2] * run[4] / 255
					colour = rgb(channels[1], channels[2], channels[3], round(alpha * 255, 1))
					colours[colour_key] = colour
				frame.DrawBox(colour, run[2], run[1], run[3], run[1])
		baked.Insert(frame, "", direction)
	return bulge_register_icon(baked)

/**
 * Returns an MD5 of what runs draw, the same for runs that draw the same pixels: each role's runs in each direction, in
 * a fixed order, with their levels.
 *
 * Arguments:
 * - runs: From dirt_shown_runs().
 */
/proc/dirt_runs_key(alist/runs)
	var/list/key_parts = list()
	for(var/role in dirt_drawn_roles())
		var/alist/by_direction = runs[role]
		if(!by_direction)
			continue
		key_parts += "role [role]"
		for(var/direction in dirt_mask_directions())
			key_parts += "dir [direction]"
			for(var/list/run as anything in by_direction[direction])
				key_parts += "[run[1]],[run[2]],[run[3]],[run[4]]"
	// the runs carry no tints: a second material would add its own name here, as in mask_key()
	return md5(jointext(key_parts, ";"))

/**
 * Adds a mask's horizontal runs in one direction to each role's: list(icon y, first icon x, last icon x, level). A run
 * is a role's pixels side by side in one row at one level, how much of each pixel it covers out of 255:
 * DIRT_MASK_SOLID, or DIRT_MASK_HALF for haze, drawn as film. A pixel beside what's worn over it keeps a share of its
 * level: its fade ring over DIRT_FADE_RINGS + 1.
 *
 * Arguments:
 * - pixel_map: The mask.
 * - indexes: The pixels to draw, in row-major order.
 * - direction: The direction it's seen from.
 * - runs: alist(DIRT_ROLE_* define = alist(direction = runs)), added to.
 * - fades: dirt_cover_fades() in this direction, or null.
 */
/proc/dirt_role_runs(datum/dirt_pixels/pixel_map, list/indexes, direction, alist/runs, alist/fades)
	var/list/roles = pixel_map.roles
	var/width = pixel_map.width
	// role -> its run being drawn, or null
	var/alist/open = alist()
	for(var/index in indexes)
		var/role = roles[index]
		if(!role)
			continue
		var/level = role == DIRT_ROLE_HAZE ? DIRT_MASK_HALF : DIRT_MASK_SOLID
		var/ring = fades?[index]
		if(ring)
			level = round(level * ring / (DIRT_FADE_RINGS + 1), 1)
		if(role == DIRT_ROLE_HAZE)
			role = DIRT_ROLE_FILM
		var/row = floor((index - 1) / width)
		var/icon_x = index - row * width
		var/icon_y = pixel_map.height - row
		var/list/run = open[role]
		if(run && run[1] == icon_y && run[3] == icon_x - 1 && run[4] == level)
			run[3] = icon_x
			continue
		if(run)
			dirt_add_run(runs, role, direction, run)
		open[role] = list(icon_y, icon_x, icon_x, level)
	for(var/role, run in open)
		dirt_add_run(runs, role, direction, run)

/**
 * Adds one run to a role's in one direction.
 *
 * Arguments:
 * - runs: alist(DIRT_ROLE_* define = alist(direction = runs)).
 * - role: The role.
 * - direction: The direction.
 * - run: list(icon y, first icon x, last icon x, level).
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

#undef DIRT_MASK_SOLID
#undef DIRT_MASK_HALF
