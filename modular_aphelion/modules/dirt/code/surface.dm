/// How many sprite directions dirt_sprite_pixels() keeps, about 0.5 MB: a template reads up to 40, most of them shared.
#define DIRT_SPRITE_READS 256

/**
 * One direction of a body's dirt surface. Dirt lies on limbs, not on the screen: every pixel of the body and of a margin
 * round it maps to a limb, an angle round that limb (theta) and a height along it (h), so a mark keeps its place on the
 * body as the mob turns.
 * - theta: degrees round the limb, 0 at the body's front, 90 its right side, 180 its back and -90 its left.
 * - h: 0 at the limb's lowest row, 1 at its highest.
 *
 * Per-pixel lists are indexed y * width + x + 1, in the reference generator's coordinates: x from the left and y from the
 * top, both from 0. That pixel is (x + 1, height - y) in an icon.
 */
/datum/dirt_surface
	/// The direction it's seen from.
	var/direction
	var/width
	var/height
	/// Each pixel's limb, a DIRT_LIMB_* define, or null off the surface.
	var/list/limb_of
	/// Each pixel's theta, from -180 up to 180.
	var/list/theta_of
	/// Each pixel's h, from -0.2 to 1.2: the margin runs past the limbs' ends.
	var/list/height_of
	/// TRUE on the silhouette's edge and the margin's first ring, where clothing draws its outline. Each leg's sole stays
	/// off it: it's in contact with the floor.
	var/list/rim
	/// TRUE on the body's pixels off the rim.
	var/list/interior
	/// Where nothing may be drawn: DIRT_GUARD_EYE on an eye and the pixels beside it, DIRT_GUARD_MOUTH on a human mouth.
	var/list/face_guard
	/// TRUE on an eye's diagonals, which take film at most.
	var/list/eye_soft
	/// alist(limb = alist(row = list(leftmost column, rightmost column))): each row a limb's sprites cover, hidden parts
	/// included.
	var/alist/limb_rows
	/// Each pixel's zone, the body zone whose image shows there, or null off the body: dirt_zone_owners()'s.
	var/list/zone_of
	/// TRUE on the body pixels a covering coat fades at, from outline(), or null until it's asked for.
	var/list/outline_pixels
	/// TRUE on the outline and the pixels beside it, from outline_band(), or null until it's asked for.
	var/list/outline_band_pixels

/**
 * Builds one direction of a body's surface from the sprites it draws.
 *
 * Arguments:
 * - direction: The direction it's seen from.
 * - masks: Each drawn zone's sprite pixels, from dirt_zone_pixels().
 * - owners: The zone each pixel shows, from dirt_zone_owners().
 * - eyes: The eye sprites' pixels, or null for a body without eyes.
 * - human_head: Whether the head is a human's, whose mouth is guarded.
 */
/datum/dirt_surface/New(direction, list/masks, list/owners, list/eyes, human_head)
	. = ..()
	src.direction = direction
	width = ICON_SIZE_X
	height = ICON_SIZE_Y
	var/pixel_count = width * height
	limb_of = new /list(pixel_count)
	theta_of = new /list(pixel_count)
	height_of = new /list(pixel_count)
	rim = new /list(pixel_count)
	interior = new /list(pixel_count)
	face_guard = new /list(pixel_count)
	eye_soft = new /list(pixel_count)
	zone_of = owners
	var/list/limbs = map_body(owners)
	measure_rows(masks, limbs)
	var/list/distances = new /list(pixel_count)
	place_pixels(spread_margin(limbs, distances))
	find_rim(limbs, distances)
	guard_face(eyes, human_head)

/**
 * Returns where a pixel lies on the body: list(limb, theta, h), or null off the surface.
 *
 * Arguments:
 * - column, row: The pixel, from the left and from the top, from 0.
 */
/datum/dirt_surface/proc/surface_at(column, row)
	var/index = pixel_index(column, row)
	var/limb = index && limb_of[index]
	return limb ? list(limb, theta_of[index], height_of[index]) : null

/**
 * Returns a pixel's index in the per-pixel lists, or null off the canvas.
 *
 * Arguments:
 * - column, row: The pixel, from the left and from the top, from 0.
 */
/datum/dirt_surface/proc/pixel_index(column, row)
	if(column < 0 || row < 0 || column >= width || row >= height)
		return null
	return row * width + column + 1

/**
 * Returns TRUE on the body pixels a covering coat fades at: the silhouette's edge, and where the head, an arm or a hand
 * meets another zone. The legs' meeting with the chest stays off it: a film line there read as a waistband. Built once.
 * You should NEVER modify it.
 */
/datum/dirt_surface/proc/outline()
	RETURN_TYPE(/list)
	if(outline_pixels)
		return outline_pixels
	var/static/list/over_zones = list(BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_PRECISE_R_HAND)
	var/list/offsets = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	outline_pixels = new /list(width * height)
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			var/zone = zone_of[index]
			if(!zone)
				continue
			for(var/list/offset as anything in offsets)
				var/neighbour = pixel_index(column + offset[1], row + offset[2])
				var/neighbour_zone = neighbour && zone_of[neighbour]
				if(!neighbour_zone || (neighbour_zone != zone && ((zone in over_zones) || (neighbour_zone in over_zones))))
					outline_pixels[index] = TRUE
					break
	return outline_pixels

/**
 * Returns TRUE on the outline and the pixels beside it, where a covering coat breaks in profile: whole, it ran the
 * torso's height as one band. Built once. You should NEVER modify it.
 */
/datum/dirt_surface/proc/outline_band()
	RETURN_TYPE(/list)
	if(outline_band_pixels)
		return outline_band_pixels
	var/list/edges = outline()
	var/list/offsets = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	outline_band_pixels = edges.Copy()
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			if(!edges[row * width + column + 1])
				continue
			for(var/list/offset as anything in offsets)
				var/neighbour = pixel_index(column + offset[1], row + offset[2])
				if(neighbour)
					outline_band_pixels[neighbour] = TRUE
	return outline_band_pixels

/**
 * Returns each body pixel's limb: its zone's, except below the belt, where the torso's pixels go to the legs. Facing
 * south or north they split down the middle; in profile they go to the near leg.
 *
 * Arguments:
 * - owners: The zone each pixel shows, from dirt_zone_owners().
 */
/datum/dirt_surface/proc/map_body(list/owners)
	var/list/lookup = dirt_zone_limbs()
	var/list/limbs = new /list(width * height)
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			var/zone = owners[index]
			if(!zone)
				continue
			var/limb = lookup[zone]
			if(limb == DIRT_LIMB_TORSO && row >= DIRT_BELT)
				var/left = column < width / 2
				switch(direction)
					if(EAST)
						limb = DIRT_LIMB_R_LEG
					if(WEST)
						limb = DIRT_LIMB_L_LEG
					if(SOUTH)
						limb = left ? DIRT_LIMB_R_LEG : DIRT_LIMB_L_LEG
					else
						limb = left ? DIRT_LIMB_L_LEG : DIRT_LIMB_R_LEG
			limbs[index] = limb
	return limbs

/**
 * Finds the rows each limb covers and its span in each, from its zones' whole sprites, the torso's only above the belt.
 * A leg also spans the torso pixels it took below the belt, in the rows its own sprite misses.
 *
 * Arguments:
 * - masks: Each drawn zone's sprite pixels, from dirt_zone_pixels().
 * - limbs: Each body pixel's limb, from map_body().
 */
/datum/dirt_surface/proc/measure_rows(list/masks, list/limbs)
	var/list/lookup = dirt_zone_limbs()
	limb_rows = alist()
	for(var/zone, pixels in masks)
		var/limb = lookup[zone]
		for(var/index in pixels)
			var/row = floor((index - 1) / width)
			if(limb != DIRT_LIMB_TORSO || row < DIRT_BELT)
				widen_row(limb_rows, limb, row, index - 1 - row * width)
	var/alist/extra_rows = alist()
	for(var/row in DIRT_BELT to height - 1)
		for(var/column in 0 to width - 1)
			var/limb = limbs[row * width + column + 1]
			if((limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_L_LEG) && !limb_rows[limb]?[row])
				widen_row(extra_rows, limb, row, column)
	for(var/limb, rows in extra_rows)
		var/alist/merged = limb_rows[limb]
		if(!merged)
			merged = alist()
			limb_rows[limb] = merged
		for(var/row, span in rows)
			merged[row] = span

/**
 * Widens a limb's span in one row to take in a column.
 *
 * Arguments:
 * - spans: alist(limb = alist(row = list(leftmost column, rightmost column))).
 * - limb: The limb.
 * - row, column: The pixel.
 */
/datum/dirt_surface/proc/widen_row(alist/spans, limb, row, column)
	var/alist/rows = spans[limb]
	if(!rows)
		rows = alist()
		spans[limb] = rows
	var/list/span = rows[row]
	if(span)
		span[1] = min(span[1], column)
		span[2] = max(span[2], column)
	else
		rows[row] = list(column, column)

/**
 * Returns each pixel's limb with the margin added: DIRT_SURFACE_MARGIN rings round the body, each margin pixel taking the
 * limb of the first pixel of the ring before it to reach it. A ring is reached from in row-major order, each pixel trying
 * right, left, down and up, as the reference generator does, so a margin pixel between two limbs goes the same way.
 *
 * Arguments:
 * - limbs: Each body pixel's limb, from map_body().
 * - distances: Filled with each pixel's ring: 0 on the body, then 1 to DIRT_SURFACE_MARGIN.
 */
/datum/dirt_surface/proc/spread_margin(list/limbs, list/distances)
	var/list/offsets = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	var/list/spread = limbs.Copy()
	var/list/edge = list()
	for(var/index in 1 to length(spread))
		if(spread[index])
			distances[index] = 0
			edge += index
	for(var/ring in 1 to DIRT_SURFACE_MARGIN)
		var/list/claimed = list()
		for(var/index in edge)
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			for(var/list/offset as anything in offsets)
				var/neighbour = pixel_index(column + offset[1], row + offset[2])
				if(neighbour && !spread[neighbour])
					spread[neighbour] = spread[index]
					distances[neighbour] = ring
					claimed += neighbour
		edge = sortTim(claimed, GLOBAL_PROC_REF(cmp_numeric_asc))
	return spread

/**
 * Places each pixel of the body and its margin on its limb, from the limb's span in the nearest row it covers, the upper
 * one on a tie. Theta is the angle whose sine is how far the pixel sits from the span's middle, as a fraction of its half
 * width, turned to the direction; h runs from the limb's lowest row, 0, to its highest, 1.
 *
 * Arguments:
 * - spread: Each pixel's limb, the margin included, from spread_margin().
 */
/datum/dirt_surface/proc/place_pixels(list/spread)
	var/facing = direction == NORTH ? 180 : (direction == EAST ? 90 : (direction == WEST ? -90 : 0))
	// limb -> list(its nearest row to each canvas row, its highest row, its lowest row)
	var/alist/layouts = alist()
	for(var/limb, rows in limb_rows)
		var/list/sorted = list()
		for(var/row in rows)
			sorted += row
		sortTim(sorted, GLOBAL_PROC_REF(cmp_numeric_asc))
		var/list/nearest = new /list(height)
		for(var/row in 0 to height - 1)
			var/best
			for(var/candidate in sorted)
				if(isnull(best) || abs(candidate - row) < abs(best - row))
					best = candidate
			nearest[row + 1] = best
		layouts[limb] = list(nearest, sorted[1], sorted[length(sorted)])
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			var/limb = spread[index]
			var/list/bounds = limb && layouts[limb]
			if(!bounds)
				continue
			var/alist/rows = limb_rows[limb]
			var/list/nearest = bounds[1]
			var/list/span = rows[nearest[row + 1]]
			var/half = max(0.75, (span[2] - span[1] + 1) / 2)
			var/fraction = clamp((column + 0.5 - (span[1] + span[2] + 1) / 2) / half, -1, 1)
			var/angle = facing + arcsin(-fraction)
			angle = DIRT_WRAP_DEGREES(angle)
			var/highest = bounds[2]
			var/lowest = bounds[3]
			limb_of[index] = limb
			theta_of[index] = angle
			height_of[index] = clamp((lowest - row) / max(1, lowest - highest), -0.2, 1.2)

/**
 * Marks the rim and the interior. The rim is the silhouette's edge, body pixels with a side off the body or off the
 * canvas, and the margin's first ring. Each leg's lowest row is its sole and stays off it.
 *
 * Arguments:
 * - limbs: Each body pixel's limb, from map_body().
 * - distances: Each pixel's ring, from spread_margin().
 */
/datum/dirt_surface/proc/find_rim(list/limbs, list/distances)
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			if(distances[index] == 1)
				rim[index] = TRUE
			else if(limbs[index])
				var/at_edge = column == 0 || column == width - 1 || row == 0 || row == height - 1
				rim[index] = at_edge || !limbs[index - 1] || !limbs[index + 1] || !limbs[index - width] || !limbs[index + width]
	for(var/leg in list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG))
		var/alist/rows = limb_rows[leg]
		if(!rows)
			continue
		var/sole = 0
		for(var/row in rows)
			sole = max(sole, row)
		for(var/column in 0 to width - 1)
			var/index = sole * width + column + 1
			if(limbs[index] == leg)
				rim[index] = FALSE
	for(var/index in 1 to length(limbs))
		if(limbs[index] && !rim[index])
			interior[index] = TRUE

/**
 * Guards the face: nothing on an eye or the pixels beside it, film at most on its diagonals, and nothing on a human
 * mouth, whose pixels are the human head sprite's.
 *
 * Arguments:
 * - eyes: The eye sprites' pixels, or null for a body without eyes.
 * - human_head: Whether the head is a human's.
 */
/datum/dirt_surface/proc/guard_face(list/eyes, human_head)
	var/list/sides = list(list(0, 0), list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	var/list/corners = list(list(-1, -1), list(1, -1), list(-1, 1), list(1, 1))
	for(var/index in eyes)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		for(var/list/offset as anything in sides)
			var/neighbour = pixel_index(column + offset[1], row + offset[2])
			if(neighbour)
				face_guard[neighbour] = DIRT_GUARD_EYE
	// Every eye's sides first: a corner of one eye beside another stays guarded.
	for(var/index in eyes)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		for(var/list/offset as anything in corners)
			var/neighbour = pixel_index(column + offset[1], row + offset[2])
			if(neighbour && face_guard[neighbour] != DIRT_GUARD_EYE)
				eye_soft[neighbour] = TRUE
	if(!human_head)
		return
	var/list/mouth
	switch(direction)
		if(SOUTH)
			mouth = list(list(15, 8), list(15, 9))
		if(EAST)
			mouth = list(list(19, 8), list(18, 9))
		if(WEST)
			mouth = list(list(12, 8), list(13, 9))
		else
			return
	for(var/list/spot as anything in mouth)
		var/index = pixel_index(spot[1], spot[2])
		if(index && !face_guard[index])
			face_guard[index] = DIRT_GUARD_MOUTH

/**
 * A body's dirt template: its surface in each direction and the pixels each zone shows, built once from the sprites it's
 * drawn from and shared by every body drawn from the same ones.
 */
/datum/dirt_template
	/// What it's built from, as dirt_template_key() writes it.
	var/key
	/// alist(direction = /datum/dirt_surface)
	var/alist/surfaces = alist()
	/// alist(zone = alist(direction = indexes)): the pixels where each zone's image is the topmost limb image, in row-major
	/// order. The zones' pixels don't overlap, so an overlay over the limbs, clipped to its limb's, stays off the others.
	var/alist/silhouettes = alist()

/**
 * Builds a dirt template one direction at a time, in the reference generator's order (south, north, east, west), so
 * SSdirt can spread the work over ticks. A body whose limb names a state its sheet lacks gets no template: the job fails
 * on its first piece.
 */
/datum/dirt_template_job
	parent_type = /datum/dirt_job
	/// The sprites it's built from, as dirt_zone_sources() returns them.
	var/list/zone_sources
	/// The directions it builds, in the order it builds them.
	var/list/directions
	/// How many of them are built.
	var/built_count = 0
	/// The template being built.
	var/datum/dirt_template/template

/**
 * Starts a template.
 *
 * Arguments:
 * - zone_sources: The sprites to build it from, as dirt_zone_sources() returns them.
 * - directions: The directions to build, every one unless a template's reader needs only some.
 */
/datum/dirt_template_job/New(list/zone_sources, list/directions = list(SOUTH, NORTH, EAST, WEST))
	. = ..()
	src.zone_sources = zone_sources
	src.directions = directions
	template = new
	template.key = dirt_template_key(zone_sources)

/// One piece a direction.
/datum/dirt_template_job/most_pieces()
	return length(directions)

/**
 * Builds the next direction's surface and silhouettes.
 *
 * Returns:
 * - TRUE: Every direction is built, or the template can't be (failed).
 * - FALSE: Directions are left.
 */
/datum/dirt_template_job/next_piece()
	if(!built_count && !dirt_zone_sources_drawable(zone_sources))
		failed = TRUE
		return TRUE
	var/direction = directions[built_count + 1]
	var/list/masks = dirt_zone_pixels(zone_sources, direction)
	var/list/owners = dirt_zone_owners(masks, direction)
	var/list/eyes = zone_sources["eyes"]
	template.surfaces[direction] = new /datum/dirt_surface(direction, masks, owners, eyes && (dirt_sprite_pixels(eyes[1], eyes[2], direction) | dirt_sprite_pixels(eyes[1], eyes[3], direction)), zone_sources["human_head"])
	var/list/shown = list()
	for(var/zone in masks)
		shown[zone] = list()
	for(var/index in 1 to length(owners))
		var/zone = owners[index]
		if(zone)
			shown[zone] += index
	for(var/zone, pixels in shown)
		var/alist/by_dir = template.silhouettes[zone]
		if(!by_dir)
			by_dir = alist()
			template.silhouettes[zone] = by_dir
		by_dir[direction] = pixels
	built_count++
	return built_count >= length(directions)

/**
 * Returns the template once every direction is built, or null while some are left or when it failed.
 */
/datum/dirt_template_job/proc/built()
	RETURN_TYPE(/datum/dirt_template)
	return (!failed && built_count >= length(directions)) ? template : null

/**
 * Builds a dirt template at once, for tests and for anything that can't wait for a subsystem.
 *
 * Arguments:
 * - zone_sources: The sprites to build it from, as dirt_zone_sources() returns them.
 * - directions: The directions to build, every one unless the caller reads only some.
 *
 * Returns:
 * - /datum/dirt_template: The template.
 * - null: A limb names a state its sheet lacks.
 */
/proc/dirt_build_template_now(list/zone_sources, list/directions = list(SOUTH, NORTH, EAST, WEST))
	RETURN_TYPE(/datum/dirt_template)
	var/datum/dirt_template_job/job = new(zone_sources, directions)
	for(var/piece in 1 to job.most_pieces())
		if(job.next_piece())
			break
	return job.built()

/**
 * Returns whether every limb sprite zone sources name is in its sheet. The eyes aren't checked: a missing eye state draws
 * no eye, so the face is left unguarded as the body shows it.
 *
 * Arguments:
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 */
/proc/dirt_zone_sources_drawable(list/zone_sources)
	for(var/zone in dirt_zone_draw_order())
		var/list/source = zone_sources[zone]
		if(source && !icon_exists(source[1], source[2]))
			return FALSE
	return TRUE

/**
 * Returns the zones a body's limb sprites come from, in the order the body draws them: get_all_limbs() order, which for
 * every carbon is its species' bodypart_overrides sorted by body_part (/datum/species/New()), so the chest, the head, the
 * legs and the arms, each hand straight after its arm. Zone sources are alists, which keep no order, so they're always
 * read in this one.
 */
/proc/dirt_zone_draw_order()
	RETURN_TYPE(/list)
	var/static/list/order = list(BODY_ZONE_CHEST, BODY_ZONE_HEAD, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND, BODY_ZONE_R_ARM, BODY_ZONE_PRECISE_R_HAND)
	return order

/**
 * Returns the limb each zone's pixels lie on: list(zone = DIRT_LIMB_* define). An arm runs on into its hand. You should
 * NEVER modify it.
 */
/proc/dirt_zone_limbs()
	RETURN_TYPE(/list)
	var/static/list/limbs = list(
		BODY_ZONE_HEAD = DIRT_LIMB_HEAD,
		BODY_ZONE_CHEST = DIRT_LIMB_TORSO,
		BODY_ZONE_R_ARM = DIRT_LIMB_R_ARM,
		BODY_ZONE_PRECISE_R_HAND = DIRT_LIMB_R_ARM,
		BODY_ZONE_L_ARM = DIRT_LIMB_L_ARM,
		BODY_ZONE_PRECISE_L_HAND = DIRT_LIMB_L_ARM,
		BODY_ZONE_R_LEG = DIRT_LIMB_R_LEG,
		BODY_ZONE_L_LEG = DIRT_LIMB_L_LEG,
	)
	return limbs

/**
 * Returns the sprites a body's dirt template is built from, as get_limb_icon() draws them: alist(zone = list(icon file,
 * icon state)) for each drawn limb and each hand, "eyes" = list(icon file, left state, right state) when the head draws
 * eyes, and "human_head" = whether the head is a human's. Stumps, invisible limbs and a taur's hidden legs draw no sprite
 * of their own, so they're left out.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_zone_sources(mob/living/carbon/human/body)
	var/alist/zone_sources = alist()
	for(var/zone in GLOB.all_body_zones)
		var/obj/item/bodypart/limb = body.get_bodypart(zone)
		var/sheet = limb?.drawn_sheet()
		if(!sheet)
			continue
		zone_sources[zone] = list(sheet, custom_sprite_limb_state(limb))
		if(limb.aux_zone)
			zone_sources[limb.aux_zone] = list(sheet, custom_sprite_limb_state(limb, TRUE))
	var/obj/item/bodypart/head/head = zone_sources[BODY_ZONE_HEAD] ? body.get_bodypart(BODY_ZONE_HEAD) : null
	var/obj/item/organ/eyes/eyes = (head?.head_flags & HEAD_EYESPRITES) ? body.get_organ_slot(ORGAN_SLOT_EYES) : null
	if(eyes?.eye_icon_state)
		zone_sources["eyes"] = list(eyes.eye_icon, "[eyes.eye_icon_state]_l", "[eyes.eye_icon_state]_r")
	zone_sources["human_head"] = head?.limb_id == SPECIES_HUMAN
	return zone_sources

/**
 * Returns the key of the template zone sources build: an MD5 of every sprite they name, in draw order, the eyes and
 * whether the head is a human's. Bodies drawn from the same sprites share it.
 *
 * Arguments:
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 */
/proc/dirt_template_key(list/zone_sources)
	var/list/parts = list()
	for(var/zone in dirt_zone_draw_order())
		var/list/source = zone_sources[zone]
		if(source)
			parts += "[zone]:[source[1]]:[source[2]]"
	var/list/eyes = zone_sources["eyes"]
	if(eyes)
		parts += "eyes:[eyes[1]]:[eyes[2]]:[eyes[3]]"
	if(zone_sources["human_head"])
		parts += "human_head"
	return md5(jointext(parts, "|"))

/**
 * Returns each drawn zone's sprite pixels in one direction: list(zone = indexes from dirt_sprite_pixels()), zones in
 * draw order.
 *
 * Arguments:
 * - zone_sources: The sprites, as dirt_zone_sources() returns them.
 * - direction: The direction to read.
 */
/proc/dirt_zone_pixels(list/zone_sources, direction)
	RETURN_TYPE(/list)
	var/list/masks = list()
	for(var/zone in dirt_zone_draw_order())
		var/list/source = zone_sources[zone]
		if(source)
			masks[zone] = dirt_sprite_pixels(source[1], source[2], direction)
	return masks

/**
 * Returns the pixels a sprite covers in one direction, any opacity counting, as surface indexes in row-major order.
 * Templates share sprites (every human head, its eyes), so each sprite's direction is read once and kept, the oldest
 * dropped past DIRT_SPRITE_READS. You should NEVER modify the list it returns.
 *
 * Arguments:
 * - sheet: The sprite's icon file.
 * - state: Its icon state.
 * - direction: The direction to read.
 */
/proc/dirt_sprite_pixels(sheet, state, direction)
	RETURN_TYPE(/list)
	var/static/datum/bulge_bounded_cache/reads
	if(!reads)
		reads = new
		reads.limit = DIRT_SPRITE_READS
	var/key = "[sheet]|[state]|[direction]"
	var/list/pixels = reads.fetch(key)
	if(pixels)
		return pixels
	var/icon/sprite = icon(sheet, state)
	pixels = list()
	for(var/row in 0 to ICON_SIZE_Y - 1)
		for(var/column in 0 to ICON_SIZE_X - 1)
			if(sprite.GetPixel(column + 1, ICON_SIZE_Y - row, null, direction))
				pixels += row * ICON_SIZE_X + column + 1
	return reads.store_value(key, pixels)

/**
 * Returns the zone each pixel shows in one direction, as the body draws its limb images: a list of one zone or null per
 * pixel. The images draw the lowest layer first and in draw order within a layer, and the last one drawn over a pixel
 * owns it: the legs' lower halves (BODYPARTS_LOW_LAYER), then the limbs and the legs' upper halves (BODYPARTS_LAYER), then
 * the hands (BODYPARTS_HIGH_LAYER). handle_masking() splits each leg between its halves with leg_masks.dmi, so the far
 * leg goes under everything in profile.
 *
 * Arguments:
 * - masks: Each drawn zone's sprite pixels, from dirt_zone_pixels().
 * - direction: The direction they're seen from.
 */
/proc/dirt_zone_owners(list/masks, direction)
	RETURN_TYPE(/list)
	var/icon/leg_crop_mask = icon('icons/mob/leg_masks.dmi')
	// Each layer's images, lowest first: zone -> the pixels its image there covers.
	var/list/lower = list()
	var/list/middle = list()
	var/list/upper = list()
	for(var/zone, pixels in masks)
		if(zone == BODY_ZONE_PRECISE_L_HAND || zone == BODY_ZONE_PRECISE_R_HAND)
			upper[zone] = pixels
			continue
		if(zone != BODY_ZONE_L_LEG && zone != BODY_ZONE_R_LEG)
			middle[zone] = pixels
			continue
		var/mask_state = zone == BODY_ZONE_R_LEG ? "right_leg" : "left_leg"
		var/list/halves = list(list(), list())
		for(var/index in pixels)
			var/row = floor((index - 1) / ICON_SIZE_X)
			var/column = index - 1 - row * ICON_SIZE_X
			if(leg_crop_mask.GetPixel(column + 1, ICON_SIZE_Y - row, mask_state, direction))
				halves[1] += index
			if(leg_crop_mask.GetPixel(column + 1, ICON_SIZE_Y - row, "[mask_state]_lower", direction))
				halves[2] += index
		middle[zone] = halves[1]
		lower[zone] = halves[2]
	var/list/owners = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/list/layer as anything in list(lower, middle, upper))
		for(var/zone, pixels in layer)
			for(var/index in pixels)
				owners[index] = zone
	return owners

/**
 * Returns how far one pixel reaches on a limb: list(degrees round it, h along it). It's measured once, as the reference
 * generator measures it, and serves every body, so marks keep one size whatever the body and the direction.
 *
 * SSdirt measures it before any mask job it queues reads it (/datum/dirt_template_job/metric). Anything else that draws
 * semen, such as the parity manifest, has it measured on the spot.
 *
 * Arguments:
 * - limb: A DIRT_LIMB_* define.
 */
/proc/dirt_metric(limb)
	RETURN_TYPE(/list)
	SSdirt.metrics ||= dirt_measure_metrics(dirt_build_template_now(dirt_metric_sources(), dirt_metric_directions()))
	return SSdirt.metrics[limb]

/**
 * Returns the plain human template's sprites, which dirt_metric() is measured from: no eyes, no mouth guard. You should
 * NEVER modify it.
 */
/proc/dirt_metric_sources()
	RETURN_TYPE(/alist)
	var/static/alist/sources
	if(!sources)
		sources = alist()
		for(var/zone, state in list(BODY_ZONE_CHEST = "human_chest_m", BODY_ZONE_HEAD = "human_head_m", BODY_ZONE_L_LEG = "human_l_leg", BODY_ZONE_R_LEG = "human_r_leg", BODY_ZONE_L_ARM = "human_l_arm", BODY_ZONE_PRECISE_L_HAND = "human_l_hand", BODY_ZONE_R_ARM = "human_r_arm", BODY_ZONE_PRECISE_R_HAND = "human_r_hand"))
			sources[zone] = list(BODYPART_ICON_HUMAN, state)
	return sources

/**
 * Returns the directions dirt_measure_metrics() reads, the only ones its template needs. You should NEVER modify it.
 */
/proc/dirt_metric_directions()
	RETURN_TYPE(/list)
	var/static/list/directions = list(SOUTH, EAST)
	return directions

/**
 * Returns alist(limb = list(degrees per pixel, h per pixel)), measured from the plain human template facing south, then
 * facing east for a limb the south view lacks. A limb's diameter is its median row width; its length, its rows.
 *
 * Arguments:
 * - human: The template built from dirt_metric_sources(), facing at least dirt_metric_directions().
 */
/proc/dirt_measure_metrics(datum/dirt_template/human)
	var/alist/measured = alist()
	for(var/direction in dirt_metric_directions())
		var/datum/dirt_surface/surface = human.surfaces[direction]
		for(var/limb, rows in surface.limb_rows)
			if(measured[limb])
				continue
			var/list/sizes = list()
			var/list/sorted = list()
			for(var/row, span in rows)
				sizes += span[2] - span[1] + 1
				sorted += row
			sortTim(sizes, GLOBAL_PROC_REF(cmp_numeric_asc))
			// tg's PI is 3.1416, too coarse to match the reference
			measured[limb] = list(360 / (3.14159265358979 * sizes[floor(length(sizes) / 2) + 1]), 1 / max(1, max(sorted) - min(sorted)))
	return measured

#undef DIRT_SPRITE_READS
