/// How many parts' fields dirt_part_field() keeps, packed: a few hundred bytes each, so under 128 KB.
#define DIRT_PART_FIELDS 256

/**
 * A part's sprite as mess reads it: the images a genital draws in the layers the reference generator draws that part
 * from (dirt_part_layers()), their colour layers' states taken together, or the plain pecs' shape a human chest without
 * breasts takes its mess in (dirt_pecs_guide()). A mess aimed at the part's zone takes its share on these pixels
 * (dirt_part_own()). Made once and never changed.
 */
/datum/dirt_part_source
	/// A DIRT_PART_* define.
	var/kind
	/// The sheet: an icon file, or an icon made at run time.
	var/icon
	/// The states drawn, every layer's colour layers together.
	var/list/states
	/// The layer each state draws at, in step with `states`, as get_overlay() works it out, custom layering included; or
	/// null where no layer is read (the guide, never drawn, lies under everything).
	var/list/state_layers
	/// Pixels across the sheet.
	var/width
	/// Pixels down the sheet.
	var/height
	/// Whether it's the pecs guide: never drawn, and kept to where the chest shows.
	var/guide = FALSE
	/// The organ slot of the genital it's drawn for, or null for the guide.
	var/organ_slot
	/// part_key(), once built.
	var/cached_key
	/// alist(direction = layer_at() there), once worked out.
	var/alist/facing_layers
	/// top_layer(), worked out with them.
	var/topmost_layer

/**
 * Arguments:
 * - kind: A DIRT_PART_* define.
 * - icon: The sheet.
 * - states: The states drawn.
 * - guide: Whether it's the pecs guide.
 * - state_layers: The layer each state draws at, in step with `states`, or null.
 */
/datum/dirt_part_source/New(kind, icon, list/states, guide = FALSE, list/state_layers)
	. = ..()
	src.kind = kind
	src.icon = icon
	src.states = states
	src.guide = guide
	src.state_layers = state_layers
	var/list/dimensions = get_icon_dimensions(icon)
	width = dimensions["width"]
	height = dimensions["height"]

/// Returns what the source draws, as text: sources with the same key take mess on the same pixels.
/datum/dirt_part_source/proc/part_key()
	cached_key ||= "[kind]|[dirt_sprite_key(icon)]|[jointext(states, ",")]|[width]x[height][guide ? "|guide" : ""]"
	return cached_key

/**
 * Returns the source's pixels in one direction, any opacity counting, every state's together, as indexes in row-major
 * order (dirt_sprite_pixels()): none on a sheet that isn't 32x32. You should NEVER modify the list it returns.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_part_source/proc/pixels(direction)
	RETURN_TYPE(/list)
	if(length(states) == 1)
		return dirt_sprite_pixels(icon, states[1], direction)
	var/list/covered = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/state in states)
		for(var/index in dirt_sprite_pixels(icon, state, direction))
			covered[index] = TRUE
	. = list()
	for(var/index in 1 to length(covered))
		if(covered[index])
			. += index

/**
 * Returns the layer of the topmost image that shows the source in one direction: the least layer number of its states
 * with pixels there (dirt_sprite_facings()). INFINITY when none has (the guide lies under everything). A butt shows its
 * front image facing north and its back image, under the body's skin, the other ways. Worked out once for every
 * direction.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/dirt_part_source/proc/layer_at(direction)
	if(!facing_layers)
		read_layers()
	return facing_layers[direction]

/// Returns the layer of the topmost image the source draws in any direction.
/datum/dirt_part_source/proc/top_layer()
	if(!facing_layers)
		read_layers()
	return topmost_layer

/// Works out layer_at() in every direction, and top_layer().
/datum/dirt_part_source/proc/read_layers()
	facing_layers = alist()
	topmost_layer = INFINITY
	for(var/facing in dirt_mask_directions())
		var/facing_layer = INFINITY
		if(!guide)
			for(var/position in 1 to length(state_layers))
				if(state_layers[position] < facing_layer && (dirt_sprite_facings(icon, states[position]) & facing))
					facing_layer = state_layers[position]
		facing_layers[facing] = facing_layer
		topmost_layer = min(topmost_layer, facing_layer)

/// Returns whether the source's images draw at more than one layer, so what it draws over can change with direction.
/datum/dirt_part_source/proc/layered()
	for(var/part_layer in state_layers)
		if(part_layer != state_layers[1])
			return TRUE
	return FALSE

/**
 * Returns whether the source draws under a surface in one direction, as its topmost image there does (layer_at()), so
 * its share is drawn in that surface's masks rather than on itself.
 *
 * Arguments:
 * - direction: The direction.
 * - surface_layer: The surface's layer: a garment's, DIRT_UNDERCLOTHES_LAYER or DIRT_SKIN_LAYER.
 */
/datum/dirt_part_source/proc/under(direction, surface_layer)
	return layer_at(direction) >= surface_layer

/**
 * Returns parts' keys as one line of text, to key masks by: each with where it draws against a surface in each
 * direction, when one is given.
 *
 * Arguments:
 * - sources: /datum/dirt_part_source, or null.
 * - surface_layer: The surface's layer, or null.
 */
/proc/dirt_parts_key(list/sources, surface_layer)
	var/list/keys = list()
	for(var/datum/dirt_part_source/source as anything in sources)
		var/placement = ""
		if(!isnull(surface_layer))
			for(var/direction in dirt_mask_directions())
				placement += source.under(direction, surface_layer) ? "u" : "o"
		keys += "[source.part_key()]@[placement]"
	return jointext(keys, ";")

/**
 * Returns a body's parts as one line of text, with what they're drawn for and at what layers, to tell when a change to
 * them may shape its mess otherwise.
 *
 * Arguments:
 * - parts: The body's parts, from dirt_body_parts().
 */
/proc/dirt_body_parts_key(list/parts)
	var/list/keys = list()
	for(var/datum/dirt_part_source/part as anything in parts)
		keys += "[part.organ_slot]@[jointext(part.state_layers || list(), ",")]:[part.part_key()]"
	return jointext(keys, ";")

/**
 * Returns the layers mess reads a kind of genital from, as the reference generator draws it (its own parts take every
 * one): the butt's front and back (ADJ) images, every other kind's front image alone. You should NEVER modify it.
 *
 * Arguments:
 * - kind: A DIRT_PART_* define.
 */
/proc/dirt_part_layers(kind)
	RETURN_TYPE(/list)
	var/static/list/front = list(EXTERNAL_FRONT_UNDER_CLOTHES)
	var/static/list/front_and_back = list(EXTERNAL_FRONT_UNDER_CLOTHES, EXTERNAL_ADJACENT)
	return kind == DIRT_PART_BUTT ? front_and_back : front

/**
 * Returns what a genital is drawn as for mess: a DIRT_PART_* define, or null for one that takes no share (the anus,
 * the womb). The breasts organ is pecs when it's built from a pecs accessory.
 *
 * Arguments:
 * - part: The genital.
 */
/proc/dirt_part_kind(obj/item/organ/genital/part)
	switch(part?.slot)
		if(ORGAN_SLOT_BREASTS)
			var/obj/item/organ/genital/breasts/breasts = part
			return breasts.pecs ? DIRT_PART_PECS : DIRT_PART_BREASTS
		if(ORGAN_SLOT_PENIS)
			return DIRT_PART_PENIS
		if(ORGAN_SLOT_TESTICLES)
			return DIRT_PART_TESTICLES
		if(ORGAN_SLOT_VAGINA)
			return DIRT_PART_VAGINA
		if(ORGAN_SLOT_BUTT)
			return DIRT_PART_BUTT
	return null

/**
 * Returns the zone whose shots a kind of part takes a share of: the chest for breasts and pecs, the butt for the butt,
 * the groin for the rest.
 *
 * Arguments:
 * - kind: A DIRT_PART_* define.
 */
/proc/dirt_part_zone(kind)
	switch(kind)
		if(DIRT_PART_BREASTS, DIRT_PART_PECS)
			return DIRT_ZONE_CHEST
		if(DIRT_PART_BUTT)
			return DIRT_ZONE_BUTT
	return DIRT_ZONE_GROIN

/**
 * Returns whether a kind of part is rounded, so its mess follows its form in lobes (dirt_lobe_rasterise()) and the
 * body's own mess leaves its pixels out: every kind but the penis, which takes a bead behind its tip.
 *
 * Arguments:
 * - kind: A DIRT_PART_* define.
 */
/proc/dirt_part_rounded(kind)
	return kind != DIRT_PART_PENIS

/**
 * Returns the level of a splat's mess on the body where parts take a share of it: down by 2 where a penis, testicles
 * or vulva does, else by 1 where any part does, never under 1. A part takes a share in a direction where it has pixels.
 * The top level stays: the body keeps its glaze, still off the rounded parts' pixels, and the parts draw theirs at
 * DIRT_PART_MAX_LEVEL.
 *
 * Arguments:
 * - splat: The splat.
 * - sources: The parts, each a /datum/dirt_part_source.
 * - owns: alist(source = its pixels in this direction, from dirt_part_own()).
 */
/proc/dirt_part_body_level(datum/dirt_splat/splat, list/sources, alist/owns)
	if(splat.level >= DIRT_MESS_MAX_LEVEL)
		return splat.level
	var/drop = 0
	for(var/datum/dirt_part_source/source as anything in sources)
		if(dirt_part_zone(source.kind) != splat.zone || !length(owns[source]))
			continue
		var/kind = source.kind
		drop = max(drop, (kind == DIRT_PART_PENIS || kind == DIRT_PART_TESTICLES || kind == DIRT_PART_VAGINA) ? 2 : 1)
	return max(1, splat.level - drop)

/**
 * Returns the pixels a part takes its share on in one direction, as indexes in row-major order: its own. The pecs guide
 * keeps to where the chest shows. The vulva, too small for a lobe of its own, also takes the ring of visible pixels
 * round them (the body's, and the parts') when it lies on skin, but never on cloth.
 *
 * Arguments:
 * - source: The part.
 * - direction: The direction.
 * - template: The body's template, or null when the part needs none: neither the guide nor the vulva on skin.
 * - sources: Every part drawn with it, itself included, whose pixels count as visible round the vulva.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH, what the part's share lies on.
 */
/proc/dirt_part_own(datum/dirt_part_source/source, direction, datum/dirt_template/template, list/sources, surface_kind)
	RETURN_TYPE(/list)
	var/list/own = source.pixels(direction)
	var/ring = source.kind == DIRT_PART_VAGINA && surface_kind == DIRT_SURFACE_SKIN
	if(!template || !length(own) || (!source.guide && !ring))
		return own
	var/pixel_count = ICON_SIZE_X * ICON_SIZE_Y
	var/list/kept = list()
	if(source.guide)
		var/alist/chest = template.silhouettes[BODY_ZONE_CHEST]
		var/list/shown = new /list(pixel_count)
		for(var/index in chest?[direction])
			shown[index] = TRUE
		for(var/index in own)
			if(shown[index])
				kept += index
		return kept
	var/datum/dirt_surface/surface = template.surfaces[direction]
	var/list/flags_of = surface.flags_of
	// the parts' pixels, visible round the vulva as the body's are (those with a zone)
	var/list/part_pixels = new /list(pixel_count)
	for(var/datum/dirt_part_source/part as anything in sources)
		for(var/index in part.pixels(direction))
			part_pixels[index] = TRUE
	var/list/ringed = new /list(pixel_count)
	for(var/index in own)
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		for(var/near_row in max(0, row - 1) to min(ICON_SIZE_Y - 1, row + 1))
			for(var/near_column in max(0, column - 1) to min(ICON_SIZE_X - 1, column + 1))
				var/near = near_row * ICON_SIZE_X + near_column + 1
				if(part_pixels[near] || DIRT_PIXEL_ZONE(flags_of[near]))
					ringed[near] = TRUE
	for(var/index in 1 to pixel_count)
		if(ringed[index])
			kept += index
	return kept

/**
 * Returns one splat's mess on a part's pixels, which keeps every piece where it merges with others: lobes on a rounded
 * part, a bead behind the tip on the penis. Its fields have levels 1 to DIRT_PART_MAX_LEVEL, so a splat past it draws
 * at it. A field rests on its arguments alone, and every mask its splat is on draws it again, so the newest
 * DIRT_PART_FIELDS are kept, packed.
 *
 * Arguments:
 * - kind: The part's DIRT_PART_* define.
 * - own: Its pixels in this direction, from dirt_part_own().
 * - zone: The splat's DIRT_ZONE_* define.
 * - level: The splat's level.
 * - variant: The splat's variant.
 * - direction: The direction.
 */
/proc/dirt_part_field(kind, list/own, zone, level, variant, direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/static/datum/bulge_bounded_cache/fields
	if(!fields)
		fields = new
		fields.limit = DIRT_PART_FIELDS
	level = min(level, DIRT_PART_MAX_LEVEL)
	var/key = "[kind]|[zone]|[level]|[variant]|[direction]|[md5(jointext(own, ","))]"
	var/drawn = fields.fetch(key)
	if(drawn)
		return dirt_pixels_from_drawn(drawn, ICON_SIZE_X, ICON_SIZE_Y)
	var/datum/dirt_pixels/field = dirt_part_rounded(kind) ? dirt_lobe_rasterise(own, zone, kind, level, variant, direction) : dirt_part_rasterise(own, zone, level, variant)
	fields.store_value(key, field.drawn())
	return field

/**
 * Returns mess on a part too small to round, the penis: a bead just behind its tip (its pixel farthest from where it
 * joins the body) with a highlight and a grey underside, the tip itself translucent (over the whole end it read as a
 * white cap); at levels 2 and 3 a run back from the tip and a drop or two along the part; a translucent fringe inside
 * it. Drawn from the "part:aimed_<zone>:<variant>" stream, on its pixels only.
 *
 * Arguments:
 * - own: The part's pixels, as indexes in row-major order. Fewer than three take nothing: clothing can leave a part all
 *   but hidden.
 * - zone: The splat's DIRT_ZONE_* define.
 * - level: 1 to DIRT_PART_MAX_LEVEL.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1.
 */
/proc/dirt_part_rasterise(list/own, zone, level, variant)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/drawn = new
	drawn.covers = TRUE
	if(length(own) < 3)
		return drawn
	var/pixel_count = ICON_SIZE_X * ICON_SIZE_Y
	var/list/inside = new /list(pixel_count)
	for(var/index in own)
		inside[index] = TRUE
	var/datum/dirt_random/stream = new("part:aimed_[zone]:[num2text(variant, 12)]")
	// where it joins the body: its pixel nearest the groin's middle, ties to the left, then up
	var/base_x
	var/base_y
	var/best
	for(var/index in own)
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		var/across = column - 15.5
		var/down = row - 19.5
		var/distance = across * across + down * down
		if(isnull(best) || distance < best || (distance == best && (column < base_x || (column == base_x && row < base_y))))
			best = distance
			base_x = column
			base_y = row
	// the tip: its pixel farthest from there, ties to the lower, then the left
	var/tip_x
	var/tip_y
	best = null
	for(var/index in own)
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		var/distance = (column - base_x) ** 2 + (row - base_y) ** 2
		if(isnull(best) || distance > best || (distance == best && (row > tip_y || (row == tip_y && column < tip_x))))
			best = distance
			tip_x = column
			tip_y = row
	var/part_length = sqrt((base_x - tip_x) ** 2 + (base_y - tip_y) ** 2)
	var/step_x = (base_x - tip_x) / max(part_length, 1)
	var/step_y = (base_y - tip_y) / max(part_length, 1)
	var/tip = tip_y * ICON_SIZE_X + tip_x + 1
	// the drop hangs on the pixel nearest the spot just behind the tip, in thousandths so equal distances tie: then the
	// lower, then the left
	var/anchor
	var/anchor_x
	var/anchor_y
	best = null
	for(var/index in own)
		if(index == tip)
			continue
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		var/nearness = floor((abs(column - (tip_x + step_x)) + abs(row - (tip_y + step_y))) * 1000 + 0.5)
		if(isnull(best) || nearness < best || (nearness == best && (row > anchor_y || (row == anchor_y && column < anchor_x))))
			best = nearness
			anchor = index
			anchor_x = column
			anchor_y = row
	var/list/drop
	var/below = anchor_y + 1 < ICON_SIZE_Y ? anchor + ICON_SIZE_X : null
	if(below && inside[below] && below != tip)
		drop = list(anchor, below)
	else
		drop = list(anchor_y > 0 ? anchor - ICON_SIZE_X : null, anchor)
	var/list/drop_pixels = list()
	for(var/index in drop)
		if(index && inside[index])
			drop_pixels += index
	var/list/solid = new /list(pixel_count)
	for(var/index in drop_pixels)
		solid[index] = DIRT_ROLE_BODY
	if(length(drop_pixels) == 2)
		solid[drop_pixels[2]] = DIRT_ROLE_CORE // the grey underside
	var/glint = drop_pixels[1]
	var/tip_thin = !solid[tip]
	if(level >= 2 && part_length > 2)
		// the run back toward the base, its length drawn at every level past the first
		var/run_length = list(0, 2, stream.randint(3, 4))[level]
		for(var/run_step in 1 to run_length)
			var/run_x = floor(tip_x + (base_x - tip_x) * run_step / part_length + 0.5)
			var/run_y = floor(tip_y + (base_y - tip_y) * run_step / part_length + 0.5)
			var/index = dirt_part_index(run_x, run_y)
			if(index && inside[index] && !solid[index])
				solid[index] = DIRT_ROLE_BODY
		// then drops along it
		var/list/fractions = list(0.55, 0.8)
		for(var/drop_number in 1 to level - 1)
			var/along = fractions[drop_number] + stream.uniform(-0.1, 0.1)
			var/spot_x = floor(tip_x + (base_x - tip_x) * along + 0.5)
			var/spot_y = floor(tip_y + (base_y - tip_y) * along + 0.5)
			var/nearest
			var/nearest_x
			var/nearest_y
			best = null
			for(var/index in own)
				var/row = floor((index - 1) / ICON_SIZE_X)
				var/column = index - 1 - row * ICON_SIZE_X
				var/score = abs(column - spot_x) + abs(row - spot_y) + 0.5 * (row - spot_y)
				if(isnull(best) || score < best || (score == best && (column < nearest_x || (column == nearest_x && row < nearest_y))))
					best = score
					nearest = index
					nearest_x = column
					nearest_y = row
			if(!solid[nearest])
				solid[nearest] = DIRT_ROLE_BODY
	for(var/index in 1 to pixel_count)
		if(solid[index])
			drawn.put_index(index, solid[index], 0.9)
	drawn.put_index(glint, DIRT_ROLE_GLINT, 0.9)
	if(tip_thin && !drawn.roles[tip])
		drawn.put_index(tip, DIRT_ROLE_FILM, 0.4)
	dirt_part_fringe(drawn, solid, inside)
	return drawn

/**
 * Lays a part's translucent fringe: film on each of the part's pixels beside its solid mess, up, down or across, that
 * holds none yet.
 *
 * Arguments:
 * - drawn: The part's mess so far, added to.
 * - solid: Each pixel's solid role, or null.
 * - inside: TRUE on each of the part's pixels.
 */
/proc/dirt_part_fringe(datum/dirt_pixels/drawn, list/solid, list/inside)
	var/list/neighbours = dirt_neighbour_table(ICON_SIZE_X, ICON_SIZE_Y)
	for(var/index in 1 to length(solid))
		if(!solid[index])
			continue
		for(var/near in neighbours[index])
			if(inside[near] && !drawn.roles[near])
				drawn.put_index(near, DIRT_ROLE_FILM, 0.4)

/**
 * Returns a pixel's index on a 32x32 canvas, or null off it.
 *
 * Arguments:
 * - column, row: The pixel, from the left and from the top, from 0.
 */
/proc/dirt_part_index(column, row)
	if(column < 0 || row < 0 || column >= ICON_SIZE_X || row >= ICON_SIZE_Y)
		return null
	return row * ICON_SIZE_X + column + 1

/**
 * Draws a role on a pixel of the mask by its index.
 *
 * Arguments:
 * - index: The pixel's index.
 * - role: A DIRT_ROLE_* define.
 * - thickness: How thick it lies, from 0 to 1.
 */
/datum/dirt_pixels/proc/put_index(index, role, thickness)
	roles[index] = role
	thicknesses[index] = thickness

/**
 * Returns a rounded part's lobes, each a list of indexes in row-major order: each side of DIRT_PART_MIDLINE where the
 * view shows both (front or back, the vulva excepted), else the whole part. A lobe under 4 px holds none.
 *
 * Arguments:
 * - own: The part's pixels.
 * - direction: The direction.
 * - kind: A DIRT_PART_* define.
 */
/proc/dirt_lobes(list/own, direction, kind)
	RETURN_TYPE(/list)
	. = list()
	if((direction == SOUTH || direction == NORTH) && kind != DIRT_PART_VAGINA)
		var/list/left = list()
		var/list/right = list()
		for(var/index in own)
			var/column = (index - 1) % ICON_SIZE_X
			if(column < DIRT_PART_MIDLINE)
				left += index
			else if(column > DIRT_PART_MIDLINE)
				right += index
		for(var/list/side as anything in list(left, right))
			if(length(side) >= 4)
				. += list(side)
		return
	if(length(own) >= 4)
		. += list(own)

/**
 * Returns mess following a rounded part's form (breasts, pecs, the butt, testicles, the vulva), from the
 * "lobe:aimed_<zone>:<kind>:<variant>" stream. A ragged blob lands on a lobe's upper slope, and at levels 2 and 3 its
 * drip runs down the lobe keeping its place across each row as the lobe widens and narrows, to a bead at the
 * under-curve. Level 3 adds a smaller blob with a short drip, and breaks the drips into beads. A pair's other lobe
 * takes a smaller blob, clear of the first lobe's rows (level with it, the pair read as a bra). Opaque cores, a
 * highlight per drop, a grey underside, a translucent fringe, all on the part's own pixels.
 *
 * Arguments:
 * - own: The part's pixels, as indexes in row-major order.
 * - zone: The splat's DIRT_ZONE_* define.
 * - kind: A DIRT_PART_* define.
 * - level: 1 to DIRT_PART_MAX_LEVEL.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1.
 * - direction: The direction.
 */
/proc/dirt_lobe_rasterise(list/own, zone, kind, level, variant, direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/drawn = new
	drawn.covers = TRUE
	var/list/lobes = dirt_lobes(own, direction, kind)
	if(!length(lobes))
		return drawn
	var/datum/dirt_random/stream = new("lobe:aimed_[zone]:[kind]:[num2text(variant, 12)]")
	var/list/inside = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/index in own)
		inside[index] = TRUE
	var/datum/dirt_lobe_raster/raster = new(inside, stream.randrange(65536), kind, level)
	stream.shuffle(lobes)
	var/list/first_lobe = dirt_lobe_shape(lobes[1])
	var/across = stream.uniform(-0.55, 0.55)
	var/down = stream.uniform(0.15, 0.35)
	// every draw at every level: the other lobe's blob holds its place as the level rises
	var/second_down = stream.uniform(0.3, 0.5)
	var/other_across = stream.uniform(-0.4, 0.4)
	var/other_down = stream.uniform(0.35, 0.6)
	var/static/list/radii = list(0.9, 1.15, 1.35)
	var/static/list/drip_lengths = list(0, 3, 5)
	var/list/first = raster.blob(first_lobe, across, down, radii[level], 0, null, null, kind == DIRT_PART_VAGINA)
	if(first[1] && level >= 2)
		raster.drip(first_lobe, first[1], across, drip_lengths[level])
	if(level == 3)
		var/second_across = across + (across < 0 ? 0.6 : -0.6)
		var/list/second = raster.blob(first_lobe, second_across, second_down, 0.85, 1)
		if(second[1])
			raster.drip(first_lobe, second[1], second_across, 2)
	if(level >= 2 && length(lobes) > 1)
		var/list/other_lobe = dirt_lobe_shape(lobes[2])
		raster.blob(other_lobe, other_across, other_down, 0.8, 2, list(first[2], dirt_lobe_row_at(first_lobe, second_down)), 0.6 * first[3])
	raster.draw(drawn)
	return drawn

/**
 * Returns a lobe's shape: list(its indexes, TRUE on each of its pixels, alist(row = list(leftmost column, rightmost
 * column)), its rows from the top).
 *
 * Arguments:
 * - indexes: The lobe's pixels, in row-major order.
 */
/proc/dirt_lobe_shape(list/indexes)
	RETURN_TYPE(/list)
	var/list/lookup = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	var/alist/spans = alist()
	var/list/rows = list()
	for(var/index in indexes)
		lookup[index] = TRUE
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		var/list/span = spans[row]
		if(span)
			span[1] = min(span[1], column)
			span[2] = max(span[2], column)
		else
			spans[row] = list(column, column)
			rows += row
	sortTim(rows, GLOBAL_PROC_REF(cmp_numeric_asc))
	return list(indexes, lookup, spans, rows)

/**
 * Returns the row a fraction of the way down a lobe, 0 its top and 1 its bottom, not rounded.
 *
 * Arguments:
 * - shape: The lobe's shape, from dirt_lobe_shape().
 * - fraction: How far down.
 */
/proc/dirt_lobe_row_at(list/shape, fraction)
	var/list/rows = shape[4]
	return rows[1] + fraction * (rows[length(rows)] - rows[1])

/**
 * One rounded part's mess while dirt_lobe_rasterise() lays it: each pixel's role so far and the highlights.
 */
/datum/dirt_lobe_raster
	/// TRUE on each of the part's pixels.
	var/list/inside
	/// The noise seed of the blobs' ragged edges.
	var/seed
	/// A DIRT_PART_* define.
	var/kind
	/// 1 to DIRT_PART_MAX_LEVEL.
	var/level
	/// Each pixel's role so far, a DIRT_ROLE_* define, or null.
	var/list/solid
	/// The highlights' pixels, in the order they were laid.
	var/list/glints = list()

/**
 * Arguments:
 * - inside: TRUE on each of the part's pixels.
 * - seed: The noise seed of the blobs' ragged edges.
 * - kind: A DIRT_PART_* define.
 * - level: 1 to DIRT_PART_MAX_LEVEL.
 */
/datum/dirt_lobe_raster/New(list/inside, seed, kind, level)
	. = ..()
	src.inside = inside
	src.seed = seed
	src.kind = kind
	src.level = level
	solid = new /list(ICON_SIZE_X * ICON_SIZE_Y)

/**
 * Lays a ragged drop on a lobe: an ellipse round a spot a fraction across and down it, its edge broken by noise, kept
 * to the lobe. Its lowest pixels with no drop pixel under them are core, the rest body, and its topmost pixel a
 * highlight.
 *
 * Arguments:
 * - shape: The lobe's shape, from dirt_lobe_shape().
 * - across: Where across the nearest row, -1 its left end and 1 its right.
 * - down: How far down the lobe, 0 its top and 1 its bottom.
 * - radius: The drop's radius across, in pixels; it's 0.85 of that tall.
 * - noise_offset: Added to the noise seed: each drop on a part breaks its edge differently.
 * - away_from: Rows the drop keeps 2 px clear of, moved below them or else above them, or null.
 * - most: The most pixels it may cover, shrinking until it covers no more, or null for no limit.
 * - centred: Whether it's held within a pixel of the lobe's centroid: on the hip crease the vulva's read as off target.
 *
 * Returns list(its lowest pixel, ties to the side away from the midline, or null when it covers none; the row it's
 * centred on; how many pixels it covers).
 */
/datum/dirt_lobe_raster/proc/blob(list/shape, across, down, radius, noise_offset, list/away_from, most, centred = FALSE)
	RETURN_TYPE(/list)
	var/list/lobe = shape[2]
	var/alist/spans = shape[3]
	var/list/rows = shape[4]
	var/centre_y = dirt_lobe_row_at(shape, down)
	var/too_close = FALSE
	for(var/kept_row in away_from)
		if(abs(centre_y - kept_row) < 2)
			too_close = TRUE
			break
	if(too_close)
		var/below = max(away_from) + 2
		var/above = min(away_from) - 2
		if(below <= rows[length(rows)])
			centre_y = below
		else if(above >= rows[1])
			centre_y = above
	var/nearest_row
	for(var/row in rows)
		if(isnull(nearest_row) || abs(row - centre_y) < abs(nearest_row - centre_y))
			nearest_row = row
	var/list/span = spans[nearest_row]
	var/centre_x = (span[1] + span[2]) / 2 + across * (span[2] - span[1]) / 2
	if(centred)
		var/sum_x = 0
		var/sum_y = 0
		var/list/indexes = shape[1]
		for(var/index in indexes)
			var/row = floor((index - 1) / ICON_SIZE_X)
			sum_x += index - 1 - row * ICON_SIZE_X
			sum_y += row
		var/mean_x = sum_x / length(indexes)
		var/mean_y = sum_y / length(indexes)
		centre_x = max(mean_x - 1, min(mean_x + 1, centre_x))
		centre_y = max(mean_y - 1, min(mean_y + 1, centre_y))
	var/list/points = blob_points(lobe, centre_x, centre_y, radius, noise_offset)
	// clearly the smaller: a near twin of the first read as a bra
	for(var/shrink in 1 to 20)
		if(isnull(most) || length(points) <= most || radius <= 0.45)
			break
		radius *= 0.85
		points = blob_points(lobe, centre_x, centre_y, radius, noise_offset)
	if(!length(points))
		return list(null, centre_y, 0)
	var/list/covered = new /list(ICON_SIZE_X * ICON_SIZE_Y)
	for(var/index in points)
		covered[index] = TRUE
	var/lowest
	var/lowest_row
	var/lowest_column
	// the drip leaves from the outer side: a teardrop, not a T
	var/outward = centre_x >= DIRT_PART_MIDLINE ? 1 : -1
	for(var/index in points)
		var/row = floor((index - 1) / ICON_SIZE_X)
		var/column = index - 1 - row * ICON_SIZE_X
		var/under = row + 1 < ICON_SIZE_Y ? index + ICON_SIZE_X : null
		solid[index] = (row > centre_y && !covered[under]) ? DIRT_ROLE_CORE : DIRT_ROLE_BODY
		if(isnull(lowest) || row > lowest_row || (row == lowest_row && column * outward > lowest_column * outward))
			lowest = index
			lowest_row = row
			lowest_column = column
	// the topmost pixel, then the leftmost: the least index
	glints += min(points)
	return list(lowest, centre_y, length(points))

/**
 * Returns the pixels of a lobe a ragged ellipse covers: where ((x - centre_x) / radius)^2 + ((y - centre_y) / (0.85 *
 * radius))^2 plus a share of noise is at most 1.
 *
 * Arguments:
 * - lobe: TRUE on each of the lobe's pixels.
 * - centre_x, centre_y: The ellipse's centre.
 * - radius: Its radius across.
 * - noise_offset: Added to the noise seed.
 */
/datum/dirt_lobe_raster/proc/blob_points(list/lobe, centre_x, centre_y, radius, noise_offset)
	RETURN_TYPE(/list)
	. = list()
	var/tall = radius * 0.85
	for(var/column in floor(centre_x - radius - 1) to floor(centre_x + radius + 2) - 1)
		for(var/row in floor(centre_y - radius - 1) to floor(centre_y + radius + 2) - 1)
			var/index = dirt_part_index(column, row)
			if(!index || !lobe[index])
				continue
			var/off_x = (column - centre_x) / radius
			var/off_y = (row - centre_y) / tall
			if(off_x * off_x + off_y * off_y + (dirt_spread_noise(column, row, seed + noise_offset, 1.5) - 0.5) * 0.5 <= 1)
				. += index

/**
 * Lays a drip down a lobe from a drop: on each row below it, as far as `drip_length`, at the place across the row the
 * drop started from, stepping out from the midline every few rows (every other on a flat chest, where the form gives a
 * drip no bend and a straight column under a blob spelt T). Level 3 breaks it into beads with skin between them. It
 * ends in a bead with a highlight and a grey underside.
 *
 * Arguments:
 * - shape: The lobe's shape, from dirt_lobe_shape().
 * - start: The drop's lowest pixel.
 * - across: Where across each row, -1 its left end and 1 its right.
 * - drip_length: The most rows it runs down.
 */
/datum/dirt_lobe_raster/proc/drip(list/shape, start, across, drip_length)
	var/list/lobe = shape[2]
	var/alist/spans = shape[3]
	var/start_row = floor((start - 1) / ICON_SIZE_X)
	var/column = start - 1 - start_row * ICON_SIZE_X
	var/list/drip_rows = list()
	for(var/row in shape[4])
		if(length(drip_rows) >= drip_length)
			break
		if(row > start_row)
			drip_rows += row
	var/lean = column >= DIRT_PART_MIDLINE ? 1 : -1
	var/every = kind == DIRT_PART_PECS ? 2 : 3
	for(var/position in 1 to length(drip_rows))
		var/row = drip_rows[position]
		var/list/span = spans[row]
		var/number = position - 1
		column = floor((span[1] + span[2]) / 2 + across * (span[2] - span[1]) / 2 + 0.5) + lean * floor((number + every - 1) / every)
		var/index = dirt_part_index(column, row)
		if(index && lobe[index] && !(level == 3 && number % 2 == 1))
			solid[index] = DIRT_ROLE_BODY
	if(!length(drip_rows))
		return
	var/last_row = drip_rows[length(drip_rows)]
	var/bead = dirt_part_index(column, last_row)
	if(!bead || !lobe[bead])
		return
	solid[bead] = DIRT_ROLE_BODY
	glints += bead
	var/under = dirt_part_index(column, last_row + 1)
	if(under && lobe[under])
		solid[under] = DIRT_ROLE_CORE

/**
 * Draws what was laid onto a mask: the solid roles and the highlights on the part's pixels, then the fringe.
 *
 * Arguments:
 * - drawn: The mask, added to.
 */
/datum/dirt_lobe_raster/proc/draw(datum/dirt_pixels/drawn)
	for(var/index in 1 to length(solid))
		if(solid[index] && inside[index])
			drawn.put_index(index, solid[index], 0.9)
	for(var/index in glints)
		if(inside[index])
			drawn.put_index(index, DIRT_ROLE_GLINT, 0.9)
	dirt_part_fringe(drawn, solid, inside)

/**
 * Returns the source of the plain pecs' shape a human chest without breasts takes mess in, an undrawn guide (Muscular
 * pecs and breasts are the breasts organ, drawn), or null for any other chest. You should NEVER modify it.
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_pecs_guide(mob/living/carbon/human/body)
	RETURN_TYPE(/datum/dirt_part_source)
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	if(chest?.limb_id != SPECIES_HUMAN || !chest.drawn_sheet() || body.get_organ_slot(ORGAN_SLOT_BREASTS))
		return null
	var/static/datum/dirt_part_source/guide
	guide ||= new(DIRT_PART_PECS, /datum/sprite_accessory/genital/breasts/pecs::icon, list("m_breasts_[/datum/sprite_accessory/genital/breasts/pecs::icon_state]_0_FRONT_UNDER"), TRUE)
	return guide

/**
 * Returns the source a genital is drawn as now, its organ slot filled in and each state's layer read from its image, or
 * null while it draws none: hidden (dirt_shown()), a device drawn in its place, a bulge look drawn for it, no sprite in
 * the layers mess reads it from (a taur's penis draws only behind the body), or a kind that takes no share.
 *
 * Arguments:
 * - part: The genital.
 * - owner: Its owner.
 */
/proc/dirt_part_drawn(obj/item/organ/genital/part, mob/living/carbon/human/owner)
	RETURN_TYPE(/datum/dirt_part_source)
	var/kind = dirt_part_kind(part)
	var/datum/bodypart_overlay/mutant/genital/overlay = part?.bodypart_overlay
	var/obj/item/bodypart/limb = part?.bodypart_owner
	if(!kind || !istype(overlay) || !limb || !overlay.dirt_shown(limb, owner))
		return null
	var/datum/dirt_part_source/source = dirt_part_source_of(kind, overlay.dirt_part_images(limb, kind))
	if(source)
		source.organ_slot = part.slot
	return source

/**
 * Returns the parts a body draws that take mess, lowest drawn first: the pecs guide if its chest takes one, then each
 * genital drawn (dirt_part_drawn()).
 *
 * Arguments:
 * - body: The body.
 */
/proc/dirt_body_parts(mob/living/carbon/human/body)
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/organ/genital/part in body.organs)
		var/datum/dirt_part_source/source = dirt_part_drawn(part, body)
		if(source)
			. += source
	sortTim(., GLOBAL_PROC_REF(cmp_dirt_parts_drawn))
	var/datum/dirt_part_source/guide = dirt_pecs_guide(body)
	if(guide)
		. = list(guide) + .

/// Sorts parts lowest drawn first: the higher layer number draws under.
/proc/cmp_dirt_parts_drawn(datum/dirt_part_source/first, datum/dirt_part_source/second)
	return second.top_layer() - first.top_layer()

/**
 * Returns the parts a surface's splats reach, lowest drawn first: those on a zone one of the splats is on. Where each
 * draws against the surface is worked out in each direction (/datum/dirt_part_source/proc/under()).
 *
 * Arguments:
 * - parts: The body's parts, from dirt_body_parts().
 * - splats: The surface's /datum/dirt_splat.
 */
/proc/dirt_surface_parts(list/parts, list/splats)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/dirt_part_source/part as anything in parts)
		var/zone = dirt_part_zone(part.kind)
		for(var/datum/dirt_splat/splat as anything in splats)
			if(splat.zone == zone)
				. += part
				break

/**
 * Returns parts split by where they draw against a surface in one direction: list(those under it, whose share is drawn
 * in its masks, those over it, whose share is drawn on themselves).
 *
 * Arguments:
 * - parts: /datum/dirt_part_source, lowest drawn first.
 * - surface_layer: The surface's layer.
 * - direction: The direction.
 */
/proc/dirt_split_parts(list/parts, surface_layer, direction)
	RETURN_TYPE(/list)
	var/list/under = list()
	var/list/over = list()
	for(var/datum/dirt_part_source/part as anything in parts)
		if(part.under(direction, surface_layer))
			under += part
		else
			over += part
	return list(under, over)

/**
 * Returns a genital's images as a part source, every layer's colour layers' states together with the layer each draws
 * at, or null when none draws a sprite. Emissives and texture holders are left out.
 *
 * Arguments:
 * - kind: The genital's DIRT_PART_* define.
 * - images: Its images in the layers mess reads it from (dirt_part_images()).
 */
/proc/dirt_part_source_of(kind, list/images)
	RETURN_TYPE(/datum/dirt_part_source)
	var/sheet
	var/list/states = list()
	var/list/state_layers = list()
	for(var/mutable_appearance/drawn as anything in images)
		if(drawn.plane != FLOAT_PLANE || !drawn.icon)
			continue
		sheet ||= drawn.icon
		if(drawn.icon == sheet)
			states += drawn.icon_state
			state_layers += -drawn.layer
	if(!length(states))
		return null
	return new /datum/dirt_part_source(kind, sheet, states, FALSE, state_layers)

/**
 * Returns a container of a baked mess image just over a genital's or a taur body's images: at the layer and offsets of
 * the last sprite among them, the one drawn over the others, kept together. It isn't nested in that sprite: the sprite
 * is coloured, which its overlays would take, and a filter on it doesn't reach them.
 *
 * Arguments:
 * - images: The images, as get_overlay() returns them.
 * - baked: The baked icon, as /datum/dirt_masks holds it.
 *
 * Returns null when none of the images is a sprite.
 */
/proc/dirt_container_over(list/images, icon/baked)
	RETURN_TYPE(/mutable_appearance)
	for(var/position in length(images) to 1 step -1)
		var/mutable_appearance/front = images[position]
		if(front.plane != FLOAT_PLANE || !front.icon)
			continue
		var/mutable_appearance/container = mutable_appearance(layer = front.layer, appearance_flags = KEEP_TOGETHER)
		container.pixel_x = front.pixel_x
		container.pixel_y = front.pixel_y
		container.pixel_w = front.pixel_w
		container.pixel_z = front.pixel_z
		container.overlays += dirt_mess_baked_image(baked)
		return container
	return null

#undef DIRT_PART_FIELDS
