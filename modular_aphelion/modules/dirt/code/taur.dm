/// A pool pixel as a key, from its column and row on the taur canvas: a pool's drip can run a few pixels off it.
#define DIRT_POOL_KEY(column, row) (((row) + 8) * 100 + (column) + 8)
/// A fixed seed value, the reference generator's: changing it reshapes every taur splat.
#define DIRT_MESS_TAUR_SEED "semen:aimed_back:taur"

/**
 * A drawn shape's sprite as dirt reads it: the states of each of its layers, as it draws them on its canvas
 * (dirt_canvases()). A layer's colour layers are taken together (a matrixed part's channel images). The shape is a taur
 * body, a tail, wings, ears, horns or another drawn part. It's made once and never changed.
 */
/datum/dirt_shape_source
	/// The sheet: an icon file, or an icon made at run time.
	var/icon
	/// alist(EXTERNAL_* layer key = list of the states drawn at that layer).
	var/alist/layer_states
	/// Its layer keys, lowest drawn first. A taur body's include its rider (dirt_taur_stack()).
	var/list/stack
	/// The DIRT_CANVAS_* define it's drawn on.
	var/canvas
	/// The DIRT_SHAPE_* define it takes dirt as.
	var/kind
	/// alist(layer key = the sheet its states are drawn from) for each layer drawn from a sheet other than `icon`, as
	/// the hair's outer pieces are. Null when there's no such layer.
	var/alist/layer_sheets
	/// shape_key(), once built.
	var/cached_key

/**
 * Arguments:
 * - icon: The sheet.
 * - layer_states: alist(EXTERNAL_* = list of states).
 * - stack: Its layer keys, lowest drawn first.
 * - canvas: A DIRT_CANVAS_* define.
 * - kind: A DIRT_SHAPE_* define.
 */
/datum/dirt_shape_source/New(icon, alist/layer_states, list/stack, canvas, kind)
	. = ..()
	src.icon = icon
	src.layer_states = layer_states
	src.stack = stack
	src.canvas = canvas
	src.kind = kind

/**
 * Returns the sheet a layer's states are drawn from: its own (layer_sheets), or `icon`.
 *
 * Arguments:
 * - layer_key: The layer's key, in `stack`.
 */
/datum/dirt_shape_source/proc/sheet_of(layer_key)
	return layer_sheets?[layer_key] || icon

/// Returns what the source draws, as text. Shapes with the same key take dirt on the same pixels.
/datum/dirt_shape_source/proc/shape_key()
	if(cached_key)
		return cached_key
	var/list/parts = list(dirt_sprite_key(icon))
	for(var/layer_key in stack)
		var/list/states = layer_states[layer_key]
		if(length(states))
			parts += "[layer_key]=[jointext(states, ",")]"
	cached_key = jointext(parts, "|")
	return cached_key

/**
 * A taur body's sprite as dirt reads it, on the 64x32 taur canvas, with its layers stacked round its rider
 * (dirt_taur_stack()). Mess aimed at the back puts pools along the back that these pixels show (dirt_taur_pools()).
 */
/datum/dirt_taur_source
	parent_type = /datum/dirt_shape_source

/**
 * Arguments:
 * - icon: The sheet.
 * - layer_states: alist(EXTERNAL_* = list of states).
 */
/datum/dirt_taur_source/New(icon, alist/layer_states)
	..(icon, layer_states, dirt_taur_stack(), DIRT_CANVAS_TAUR, DIRT_SHAPE_TAUR)

/**
 * Returns what a taur canvas shows, lowest first, as the reference stacks a taur under its rider: the taur body's
 * behind and adjacent layers, the rider, then its front layers. You should NEVER modify it.
 */
/proc/dirt_taur_stack()
	RETURN_TYPE(/list)
	var/static/list/stack = list(EXTERNAL_BEHIND, EXTERNAL_ADJACENT, DIRT_TAUR_RIDER, EXTERNAL_FRONT_UNDER_CLOTHES, EXTERNAL_FRONT, EXTERNAL_FRONT_OVER)
	return stack

/**
 * Returns a person's taur body as mess reads it, drawn or hidden (a taur suit hides it), or null without one.
 *
 * Arguments:
 * - body: The person.
 */
/proc/dirt_taur_source(mob/living/carbon/human/body)
	RETURN_TYPE(/datum/dirt_taur_source)
	var/obj/item/organ/taur_body/organ = body?.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	var/obj/item/bodypart/chest = body?.get_bodypart(BODY_ZONE_CHEST)
	if(!istype(organ) || !chest)
		return null
	var/datum/bodypart_overlay/mutant/taur_body/taur = organ.bodypart_overlay
	return istype(taur) ? taur.dirt_read_source(chest) : null

/**
 * Returns what a taur canvas shows, lowest first, as the game draws it over a taur's own pixels: the taur body's behind
 * layer, the rider's limbs, the taur's adjacent and front-under layers, a taur-fitted garment's cloth, then the taur's
 * front layers, which are drawn over that garment. Blood below the waist reads this stack (dirt_blood_carriers()),
 * while mess keeps dirt_taur_stack(). You should NEVER modify it.
 */
/proc/dirt_taur_drawn_stack()
	RETURN_TYPE(/list)
	var/static/list/stack = list(EXTERNAL_BEHIND, DIRT_TAUR_RIDER, EXTERNAL_ADJACENT, EXTERNAL_FRONT_UNDER_CLOTHES, DIRT_TAUR_CLOTH, EXTERNAL_FRONT, EXTERNAL_FRONT_OVER)
	return stack

/**
 * Returns what each pixel of a shape's canvas shows in one direction. That's the EXTERNAL_* layer of the shape drawn
 * last over it, in its stack's order. On a taur body it's DIRT_TAUR_RIDER where the rider (the body, 16 px in) is drawn
 * over it. It's DIRT_TAUR_CLOTH where a taur-fitted garment is, and null where nothing is.
 *
 * Arguments:
 * - source: The shape.
 * - rider: On a taur body, the rider's surface in that direction (the template of the body drawn on it). Else null.
 * - direction: The direction.
 * - stack: The layer keys to stack, lowest first, or null for the source's own.
 * - cloth_pixels: If `stack` holds DIRT_TAUR_CLOTH, the garment's pixels on the canvas, as dirt_sprite_pixels() reads
 *   them.
 * - rows: On a taur body, the row of the rider's surface that each row shows once the rider's height stretches it
 *   (dirt_height_rows()). Null to use the surface unstretched.
 */
/proc/dirt_taur_owners(datum/dirt_shape_source/source, datum/dirt_surface/rider, direction, list/stack = null, list/cloth_pixels = null, list/rows = null)
	RETURN_TYPE(/list)
	var/list/size = dirt_canvases()[source.canvas]
	var/width = size[1]
	var/list/owners = new /list(width * size[2])
	for(var/shown in stack || source.stack)
		if(shown == DIRT_TAUR_CLOTH)
			for(var/index in cloth_pixels)
				owners[index] = shown
			continue
		if(shown != DIRT_TAUR_RIDER)
			var/sheet = source.sheet_of(shown)
			for(var/state in source.layer_states[shown])
				for(var/index in dirt_sprite_pixels(sheet, state, direction, width, size[2]))
					owners[index] = shown
			continue
		if(!rider)
			continue
		var/list/flags_of = rider.flags_of
		if(rows)
			for(var/row in 0 to ICON_SIZE_Y - 1)
				var/source_row = rows[row + 1]
				if(isnull(source_row))
					continue
				for(var/column in 0 to ICON_SIZE_X - 1)
					if(DIRT_PIXEL_ZONE(flags_of[source_row * ICON_SIZE_X + column + 1]))
						owners[row * width + column + DIRT_TAUR_INSET + 1] = DIRT_TAUR_RIDER
			continue
		for(var/index in 1 to length(flags_of))
			if(DIRT_PIXEL_ZONE(flags_of[index]))
				var/row = floor((index - 1) / ICON_SIZE_X)
				owners[index + row * (width - ICON_SIZE_X) + DIRT_TAUR_INSET] = DIRT_TAUR_RIDER
	return owners

/**
 * Returns a shape's own pixels in one direction, as alist(index = TRUE) in row-major order: every pixel its layers
 * show, leaving out the rider's.
 *
 * Arguments:
 * - owners: What each pixel of its canvas shows, from dirt_taur_owners().
 */
/proc/dirt_shape_mask(list/owners)
	RETURN_TYPE(/alist)
	var/alist/mask = alist()
	for(var/index in 1 to length(owners))
		var/shown = owners[index]
		if(shown && shown != DIRT_TAUR_RIDER)
			mask[index] = TRUE
	return mask

/**
 * Returns a back shot's pools on a taur body in one direction. dirt_splat_rasterise() draws them as mess on the pixels
 * the taur body shows, keeping clear of the rider's mess there.
 *
 * Arguments:
 * - owners: What each pixel of the taur canvas shows, from dirt_taur_owners().
 * - rider_mess: The same shot on the rider's back, on cloth and on skin, each /datum/dirt_pixels/proc/drawn() of it.
 *   Either may lie where the rider is, so the pools keep clear of both.
 * - level: The splat's level.
 * - variant: The splat's variant.
 * - direction: The direction.
 */
/proc/dirt_taur_pools(list/owners, list/rider_mess, level, variant, direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/alist/mask = dirt_shape_mask(owners)
	var/alist/avoid = alist()
	for(var/drawn in rider_mess)
		for(var/index in dirt_drawn_indexes(drawn))
			var/row = floor((index - 1) / ICON_SIZE_X)
			var/canvas_index = index + row * (DIRT_TAUR_WIDTH - ICON_SIZE_X) + DIRT_TAUR_INSET
			if(owners[canvas_index] == DIRT_TAUR_RIDER)
				avoid[canvas_index] = TRUE
	return dirt_splat_rasterise(mask, "[DIRT_CAUSE_AIMED_PREFIX][DIRT_ZONE_BACK]", dirt_material(DIRT_MATERIAL_MESS), level, variant, DIRT_SHAPE_TAUR, direction, 1, avoid)

/**
 * Carries a taur body's merged dirt onto the pixels its rider's height uncovers. The dirt is made on the canvas as an
 * Average rider shows it. Pools, slime and a douse lie on what the taur body shows then, so a rider stretched taller
 * leaves bare pixels under its waist. A canvas field or a coat is drawn on the whole canvas, under the rider too, so a
 * pixel the merge draws there keeps its own dirt. Each other uncovered pixel looks at the pixel just below its run of
 * uncovered pixels in the column. If the taur body shows that pixel at Average height, the uncovered pixel takes its
 * dirt. A glint is carried as body, so it isn't doubled. Above a clean pixel, or above no taur pixel, an uncovered
 * pixel stays clean. A carried pixel is shown on the layer it shows at the rider's height, whichever layer the pixel
 * below is on. The pixels a shorter rider covers keep their dirt here, and layers_shown() leaves them out.
 *
 * Arguments:
 * - merged: The direction's splats merged, drawn on.
 * - average_owners: What each pixel of the canvas shows with an Average rider (dirt_taur_owners()).
 * - height_owners: What each pixel shows with the rider at its height.
 */
/proc/dirt_taur_height_fill(datum/dirt_pixels/merged, list/average_owners, list/height_owners)
	var/list/roles = merged.roles
	var/list/thicknesses = merged.thicknesses
	var/list/materials = merged.materials
	var/last_index = length(average_owners)
	for(var/index in 1 to last_index)
		if(roles[index] || average_owners[index] != DIRT_TAUR_RIDER || !height_owners[index] || height_owners[index] == DIRT_TAUR_RIDER)
			continue
		var/below
		for(below = index + DIRT_TAUR_WIDTH, below <= last_index, below += DIRT_TAUR_WIDTH)
			if(average_owners[below] != DIRT_TAUR_RIDER || !height_owners[below] || height_owners[below] == DIRT_TAUR_RIDER)
				break
		if(below > last_index || !average_owners[below] || average_owners[below] == DIRT_TAUR_RIDER)
			continue
		var/role = roles[below]
		if(!role)
			continue
		merged.put_index(index, role == DIRT_ROLE_GLINT ? DIRT_ROLE_BODY : role, thicknesses[below])
		if(materials)
			materials[index] = materials[below]

/**
 * Returns a splat drawn in a shape's own pixels in one direction. It's the one entry point for slime and mess on taur
 * bodies, wings and tails. Mess draws only as a back shot's pools on a taur body (dirt_mess_splat_rasterise()), drawn
 * the portable way, and any other mess draws nothing. Every other material lands as slime's lumps
 * (dirt_slime_splat_rasterise()), drawn while drafting.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels, on its kind's canvas (dirt_shape_canvas()).
 * - cause: A slime DIRT_CAUSE_* define, or for mess "aimed_back".
 * - material: The /datum/dirt_material it's made of.
 * - level: The splat's level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - kind: A DIRT_SHAPE_* define.
 * - direction: The direction.
 * - side: The mob's dirtier side, 1 or -1.
 * - avoid: For mess, alist(index = TRUE) on the rider's mess, which the pools keep clear of. Else null.
 */
/proc/dirt_splat_rasterise(alist/mask, cause, datum/dirt_material/material, level, variant, kind, direction, side = 1, alist/avoid = null)
	RETURN_TYPE(/datum/dirt_pixels)
	if(material.id == DIRT_MATERIAL_MESS)
		if(kind != DIRT_SHAPE_TAUR || cause != "[DIRT_CAUSE_AIMED_PREFIX][DIRT_ZONE_BACK]")
			var/list/size = dirt_canvases()[dirt_shape_canvas(kind)]
			return new /datum/dirt_pixels(size[1], size[2])
		// in row-major order, as dirt_taur_back_region() reads them
		var/list/mask_pixels = list()
		for(var/index in mask)
			mask_pixels += index
		var/list/avoid_pixels = list()
		for(var/index in avoid)
			avoid_pixels += index
		return dirt_mess_splat_rasterise(mask_pixels, level, variant, direction, avoid_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_splat_rasterise), args.Copy())
#endif
	return dirt_slime_splat_rasterise(mask, cause, level, variant, kind, direction)

/**
 * Returns the pixels of a taur body mess aimed at its back reaches in one direction: a band 3 px deep under the back
 * line the view shows. None facing south (the band there is the rider's waist, which read as underwear); facing north,
 * the columns whose top lies within 2 px below the back's middle height; in profile, the columns whose top lies within
 * 1 px of it, less the 30% at the far end (a white tuft at the tail) and the 2 beside the rider's waist (the groin).
 *
 * Arguments:
 * - mask_pixels: The taur body's pixels, as indexes in row-major order on the taur canvas.
 * - direction: The direction.
 */
/proc/dirt_taur_back_region(list/mask_pixels, direction)
	RETURN_TYPE(/list)
	. = list()
	if(!length(mask_pixels) || direction == SOUTH)
		return
	var/alist/top = alist()
	for(var/index in mask_pixels)
		var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
		var/column = index - 1 - row * DIRT_TAUR_WIDTH
		var/highest = top[column]
		if(isnull(highest) || row < highest)
			top[column] = row
	var/list/tops = list()
	for(var/column, row in top)
		tops += row
	sortTim(tops, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/line = tops[floor(length(tops) / 2) + 1]
	var/alist/kept = alist()
	if(direction != NORTH)
		var/list/columns = list()
		for(var/column, row in top)
			if(abs(row - line) <= 1)
				columns += column
		sortTim(columns, GLOBAL_PROC_REF(cmp_numeric_asc))
		var/first = columns[1]
		var/last = columns[length(columns)]
		var/span = last - first
		var/list/far_end = list()
		for(var/column in columns)
			// 0.3 of the span, in tenths, which fall as the reference's doubles do
			if(direction == EAST ? (column - first) * 10 >= span * 3 : (last - column) * 10 >= span * 3)
				far_end += column
		if(direction == EAST)
			far_end.Cut(max(1, length(far_end) - 1))
		else
			far_end.Cut(1, min(length(far_end), 2) + 1)
		for(var/column in far_end)
			kept[column] = TRUE
	for(var/index in mask_pixels)
		var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
		var/column = index - 1 - row * DIRT_TAUR_WIDTH
		if(row - top[column] >= 3)
			continue
		if(direction == NORTH ? top[column] - line <= 2 : kept[column])
			. += index

/**
 * Returns mess aimed at a taur body's back in one direction, from the "splat:aimed_back:taur:<variant>" and
 * DIRT_MESS_TAUR_SEED streams: broken pools along the back line (dirt_taur_back_region()), ragged
 * underneath, drips of uneven length off them, an opaque core, a highlight per drop and a translucent fringe, all on
 * the taur body's pixels. Level 1 is one drop; levels 2 and 3 two pools, level 3's heavier. A drop or pool that comes
 * beside the rider's mess, or under it where a line would carry on down, is left out whole: a pool beside it read as
 * one straight line across both bodies. Its levels don't nest: each is drawn from the streams on its own.
 *
 * Arguments:
 * - mask_pixels: The taur body's pixels, as indexes in row-major order on the taur canvas.
 * - level: The splat's level: past DIRT_TAUR_MAX_LEVEL it draws at that one.
 * - variant: The splat's variant.
 * - direction: The direction.
 * - avoid: The rider's mess pixels on the taur canvas, as indexes.
 */
/proc/dirt_mess_splat_rasterise(list/mask_pixels, level, variant, direction, list/avoid)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/drawn = new(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
	level = min(level, DIRT_TAUR_MAX_LEVEL)
	var/list/region = dirt_taur_back_region(mask_pixels, direction)
	if(!length(region))
		return drawn
	// slime's lumps are drawn from this stream first, so its noise seed comes after their draws
	var/datum/dirt_random/splat_stream = new("splat:aimed_back:taur:[num2text(variant, 12)]")
	for(var/start in 1 to 8)
		splat_stream.randrange(length(region))
	for(var/spent in 1 to 25)
		splat_stream.random()
	var/seed = splat_stream.randrange(65536)
	var/list/inside = new /list(DIRT_TAUR_WIDTH * ICON_SIZE_Y)
	for(var/index in mask_pixels)
		inside[index] = TRUE
	// each region column's top row: the back line
	var/alist/edge = alist()
	var/list/order = list()
	for(var/index in region)
		var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
		var/column = index - 1 - row * DIRT_TAUR_WIDTH
		if(isnull(edge[column]))
			order += column
			edge[column] = row
		else
			edge[column] = min(edge[column], row)
	sortTim(order, GLOBAL_PROC_REF(cmp_numeric_asc))
	// mirrored views put the pools in mirrored places: the rider's side of the back comes last facing east or west
	var/column_step = 1
	if(direction == WEST)
		reverse_range(order)
		column_step = -1
	var/rider_side = order[length(order)]
	var/datum/dirt_random/stream = new("[DIRT_MESS_TAUR_SEED]:[num2text(variant, 12)]")
	// DIRT_POOL_KEY() = DIRT_ROLE_*, and each drop or pool's keys, so one beside the rider's mess goes whole
	var/alist/solid = alist()
	var/list/glints = list()
	var/list/parts = list()
	if(level == 1)
		var/column = order[stream.randrange(length(order)) + 1]
		if(isnull(edge[column + column_step]))
			column -= column_step
		// the reference fails on a back line with a lone column; nothing is drawn there
		if(isnull(edge[column]) || isnull(edge[column + column_step]))
			return drawn
		var/list/part = list()
		dirt_pool_put(solid, part, DIRT_POOL_KEY(column, edge[column]), DIRT_ROLE_BODY)
		dirt_pool_put(solid, part, DIRT_POOL_KEY(column + column_step, edge[column + column_step]), DIRT_ROLE_BODY)
		dirt_pool_put(solid, part, DIRT_POOL_KEY(column, edge[column] + 1), DIRT_ROLE_BODY)
		dirt_pool_put(solid, part, DIRT_POOL_KEY(column + column_step, edge[column + column_step] + 1), DIRT_ROLE_CORE)
		glints += DIRT_POOL_KEY(column, edge[column])
		parts += list(part)
	var/list/pools = list()
	if(level > 1)
		for(var/attempt in 1 to 40)
			// level 3 is heavier by its pools: a thin spread along the back made one straight run with them
			var/pool_width = stream.randint(3, level == 3 ? 6 : 5) + (level == 3 ? 1 : 0)
			// broken: each pixel of a pool lands at its own place along the back
			var/list/columns = list()
			for(var/offset in 0 to pool_width - 1)
				var/column = order[stream.randrange(length(order)) + 1] + column_step * offset
				if(!isnull(edge[column]))
					columns += column
			if(length(columns) >= 3 && dirt_pool_clear(columns, pools))
				pools += list(columns)
			if(length(pools) == 2)
				break
	var/list/runs = stream.sample(level == 2 ? list(list(2, 3), list(0, 0)) : list(list(3, 4), list(1, 2)), length(pools))
	var/list/drips = list()
	for(var/pool_number in 1 to length(pools))
		var/list/columns = pools[pool_number]
		var/list/run_bounds = runs[pool_number]
		var/run_low = run_bounds[1]
		var/run_high = run_bounds[2]
		var/list/part = list()
		// two rows along the back line, a third here and there: a ragged bottom
		for(var/position in 1 to length(columns))
			var/column = columns[position]
			var/depth = 1
			if(position != 1 && position != length(columns))
				depth = 2 + (dirt_spread_noise(column, edge[column], seed + pool_number - 1, 1.2) > 0.6)
			for(var/down in 0 to depth - 1)
				dirt_pool_put(solid, part, DIRT_POOL_KEY(column, edge[column] + down), (down == depth - 1 && depth == 3) ? DIRT_ROLE_CORE : DIRT_ROLE_BODY)
		glints += DIRT_POOL_KEY(columns[2], edge[columns[2]])
		// the drip leaves an end of the pool
		if(run_low || run_high || stream.random() < 0.5)
			var/column = stream.random() < 0.5 ? columns[length(columns)] : columns[1]
			var/inner = column == columns[length(columns)] ? columns[length(columns) - 1] : columns[2]
			var/away = sign(column - inner) || column_step
			// not beside the rider's waist: from the end farthest from it
			if((direction == EAST || direction == WEST) && abs(column - rider_side) < 3)
				var/farthest = columns[1]
				for(var/candidate in columns)
					var/candidate_distance = abs(candidate - rider_side)
					var/farthest_distance = abs(farthest - rider_side)
					if(candidate_distance > farthest_distance || (candidate_distance == farthest_distance && candidate > farthest))
						farthest = candidate
				column = farthest
				away = -column_step
			drips += column
			var/row = edge[column] + 1
			var/run_length = stream.randint(run_low, run_high)
			for(var/run_step in 0 to run_length)
				dirt_pool_put(solid, part, DIRT_POOL_KEY(column, row + run_step), DIRT_ROLE_BODY)
			// the bulb: 2 px wide, 1 tall, pointing away from the pool
			dirt_pool_put(solid, part, DIRT_POOL_KEY(column + away, row + run_length), DIRT_ROLE_BODY)
			glints += DIRT_POOL_KEY(column, row + run_length)
		parts += list(part)
	// beside the rider's mess, or under it where a line would carry on down: the whole drop or pool goes
	var/alist/near = alist()
	for(var/index in avoid)
		var/row = floor((index - 1) / DIRT_TAUR_WIDTH)
		var/column = index - 1 - row * DIRT_TAUR_WIDTH
		for(var/near_column in column - 1 to column + 1)
			for(var/near_row in row - 1 to row + 3)
				near[DIRT_POOL_KEY(near_column, near_row)] = TRUE
	for(var/list/part as anything in parts)
		var/beside = FALSE
		for(var/key in part)
			if(near[key])
				beside = TRUE
				break
		if(beside)
			for(var/key in part)
				solid -= key
	var/list/ranks = dirt_role_ranks()
	for(var/key, role in solid)
		dirt_pool_draw(drawn, inside, ranks, key, role, 0.9)
	for(var/key in glints)
		if(solid[key])
			dirt_pool_draw(drawn, inside, ranks, key, DIRT_ROLE_GLINT, 0.9)
	// the translucent fringe, none on the rider's side of a drip's top: with both sides the drip read as a T
	var/alist/bare = alist()
	if(direction == EAST || direction == WEST)
		for(var/column in drips)
			bare[DIRT_POOL_KEY(column + column_step, edge[column])] = TRUE
			bare[DIRT_POOL_KEY(column + column_step, edge[column] + 1)] = TRUE
	for(var/key, role in solid)
		for(var/near_key in list(key + 1, key - 1, key + 100))
			// solid roles and glints land only on solid keys, so a key off them holds at most this fringe's film
			if(isnull(solid[near_key]) && !bare[near_key])
				dirt_pool_draw(drawn, inside, ranks, near_key, DIRT_ROLE_FILM, 0.4)
	return drawn

/**
 * Lays a solid role on a pool pixel, noting it as the drop or pool's own if nothing was laid there before.
 *
 * Arguments:
 * - solid: alist(DIRT_POOL_KEY() = DIRT_ROLE_*), added to.
 * - part: The keys the drop or pool being laid added, added to.
 * - key: The pixel's DIRT_POOL_KEY().
 * - role: A DIRT_ROLE_* define.
 */
/proc/dirt_pool_put(alist/solid, list/part, key, role)
	if(isnull(solid[key]))
		part += key
	solid[key] = role

/**
 * Returns whether a pool's columns keep more than 2 px from every column of the pools kept before it.
 *
 * Arguments:
 * - columns: The pool's columns.
 * - pools: The pools kept, each a list of columns.
 */
/proc/dirt_pool_clear(list/columns, list/pools)
	for(var/list/pool as anything in pools)
		for(var/kept in pool)
			for(var/column in columns)
				if(abs(column - kept) <= 2)
					return FALSE
	return TRUE

/**
 * Draws a role on a pool pixel of the taur body, where the role drawn there doesn't outrank it: never off the taur
 * body's pixels.
 *
 * Arguments:
 * - drawn: The pools, drawn on.
 * - inside: TRUE on each of the taur body's pixels.
 * - ranks: dirt_role_ranks().
 * - key: The pixel's DIRT_POOL_KEY().
 * - role: A DIRT_ROLE_* define.
 * - thickness: How thick it lies.
 */
/proc/dirt_pool_draw(datum/dirt_pixels/drawn, list/inside, list/ranks, key, role, thickness)
	var/row = floor(key / 100) - 8
	var/column = key - (row + 8) * 100 - 8
	if(column < 0 || row < 0 || column >= DIRT_TAUR_WIDTH || row >= ICON_SIZE_Y)
		return
	var/index = row * DIRT_TAUR_WIDTH + column + 1
	if(!inside[index])
		return
	var/held = drawn.roles[index]
	if(!held || ranks[role] >= ranks[held])
		drawn.put_index(index, role, thickness)

/**
 * Returns slime landed in a shape's own pixels in one direction, from the "splat:<cause>:<kind>:<variant>" stream. It
 * draws lumps in the region its cause reaches on that kind of shape (dirt_splat_region()), darkest underneath with a
 * glint on top. Drips run down from them and end in a bulb, and spatter lies beside them. Nothing lands off the shape.
 * Level 1 draws one lump, one run and one speck of spatter, level 2 three lumps, two runs and two specks, and level 3
 * five, four and three. It's drawn inside the drafting that dirt_splat_rasterise() sets up (SSdirt.drafting), so the
 * lumps' starts are picked from the region column by column, as the draft picked them.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels, on its kind's canvas (dirt_shape_canvas()).
 * - cause: A slime DIRT_CAUSE_* define.
 * - level: The splat's level: past 3 it draws at 3.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - kind: A DIRT_SHAPE_* define.
 * - direction: The direction.
 */
/proc/dirt_slime_splat_rasterise(alist/mask, cause, level, variant, kind, direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/static/list/lump_counts = list(1, 3, 5)
	var/static/list/lump_scales = list(0.8, 1, 1.25)
	var/static/list/run_counts = list(1, 2, 4)
	var/static/list/run_scales = list(0.6, 0.8, 1)
	var/static/list/spatter_counts = list(1, 2, 3)
	var/list/size = dirt_canvases()[dirt_shape_canvas(kind)]
	var/width = size[1]
	var/height = size[2]
	var/datum/dirt_pixels/drawn = new(width, height)
	level = clamp(level, 1, DIRT_DEPOSIT_MAX_LEVEL)
	var/alist/region = dirt_splat_region(mask, cause, kind, direction, level, width)
	var/list/points = list()
	if(SSdirt.drafting)
		for(var/column in 0 to width - 1)
			for(var/row in 0 to height - 1)
				if(region[row * width + column + 1])
					points += row * width + column + 1
	else
		for(var/index in region)
			points += index
	if(!length(points))
		return drawn
	var/datum/dirt_random/rng = dirt_general_stream("splat:[cause]:[kind]:[num2text(variant, 12)]")
	var/list/starts = list()
	for(var/start_number in 1 to 8)
		starts += points[rng.draw_index(length(points)) + 1]
	var/list/sizes = list()
	for(var/size_number in 1 to 8)
		sizes += rng.uniform(1.1, 1.6)
	// random draws for a streak's angle and lengths, which lumps don't take
	rng.uniform(25, 155)
	for(var/length_number in 1 to 8)
		rng.uniform(3, 6.5)
	var/list/drips = list()
	for(var/drip_number in 1 to 8)
		drips += rng.uniform(2, 5)
	var/seed = rng.randrange(65536)
	var/list/ranks = dirt_role_ranks()
	for(var/lump in 1 to lump_counts[level])
		var/centre_row = floor((starts[lump] - 1) / width)
		var/centre_column = starts[lump] - 1 - centre_row * width
		var/radius = sizes[lump] * lump_scales[level]
		// the reference's int() goes toward 0
		var/first_column = centre_column - radius - 1
		first_column = first_column < 0 ? ceil(first_column) : floor(first_column)
		var/first_row = centre_row - radius - 1
		first_row = first_row < 0 ? ceil(first_row) : floor(first_row)
		for(var/column in first_column to floor(centre_column + radius + 2) - 1)
			for(var/row in first_row to floor(centre_row + radius + 2) - 1)
				var/wobble = (dirt_spread_noise(column, row, seed, 1.8) - 0.5) * 0.5
				var/across = (column - centre_column) / radius
				var/down = (row - centre_row) / (radius * 0.85)
				var/spread = across * across + down * down
				if(spread <= 1 + wobble)
					var/role = (row > centre_row + 0.2 * radius && spread < 0.75) ? DIRT_ROLE_CORE : DIRT_ROLE_BODY
					dirt_shape_put(drawn, mask, ranks, column, row, role, row > centre_row ? 0.9 : 0.6)
		dirt_shape_put(drawn, mask, ranks, dirt_round_coordinate(centre_column - 0.4 * radius), dirt_round_coordinate(centre_row - 0.45 * radius), DIRT_ROLE_GLINT, 0.9)
	for(var/run_number in 1 to run_counts[level])
		var/start_row = floor((starts[run_number] - 1) / width)
		var/column = starts[run_number] - 1 - start_row * width
		var/row = dirt_round_coordinate(start_row + sizes[run_number] * 0.8) + 1
		var/run_length = floor(drips[run_number] * run_scales[level])
		for(var/run_step in 0 to run_length - 1)
			dirt_shape_put(drawn, mask, ranks, column, row + run_step, DIRT_ROLE_BODY, 0.6)
		// the bulb it ends in
		dirt_shape_put(drawn, mask, ranks, column, row + run_length, DIRT_ROLE_CORE, 0.9)
		dirt_shape_put(drawn, mask, ranks, column + 1, row + run_length - 1, DIRT_ROLE_BODY, 0.6)
	for(var/spatter_number in 1 to spatter_counts[level])
		var/start = starts[5 + spatter_number]
		var/row = floor((start - 1) / width)
		var/column = start - 1 - row * width
		dirt_shape_put(drawn, mask, ranks, column, row, DIRT_ROLE_BODY, 0.6)
		dirt_shape_put(drawn, mask, ranks, column + 1, row, DIRT_ROLE_BODY, 0.6)
	return drawn

/**
 * Draws a role on a pixel of a shape unless the role drawn there outranks it. It never draws off the shape's pixels.
 *
 * Arguments:
 * - drawn: The mask, drawn on.
 * - mask: alist(index = TRUE) on the shape's pixels.
 * - ranks: dirt_role_ranks().
 * - column, row: The pixel, from the left and from the top, from 0. It may lie off the canvas.
 * - role: A DIRT_ROLE_* define.
 * - thickness: How thick it lies.
 */
/proc/dirt_shape_put(datum/dirt_pixels/drawn, alist/mask, list/ranks, column, row, role, thickness)
	if(column < 0 || row < 0 || column >= drawn.width || row >= drawn.height)
		return
	var/index = row * drawn.width + column + 1
	if(!mask[index])
		return
	var/held = drawn.roles[index]
	if(!held || ranks[role] >= ranks[held])
		drawn.put_index(index, role, thickness)

/**
 * Returns a coordinate rounded to a whole pixel. Halves round up, or to even while drafting, as the draft's round()
 * took them.
 *
 * Arguments:
 * - value: The coordinate.
 */
/proc/dirt_round_coordinate(value)
	var/nearest = floor(value + 0.5)
	if(SSdirt.drafting && nearest - value == 0.5 && nearest % 2)
		nearest--
	return nearest

/**
 * Returns whether a back shot on a person also lands along their taur body's back: they have a taur body of a kind
 * with a back (dirt_read_source(): not Big Legs), it draws now, and the surface the shot lands on isn't a garment drawn
 * over the whole taur canvas (a taur suit), which takes the pools itself
 * (/datum/component/dirtiness/proc/ready_taur_cloth_masks()).
 *
 * Arguments:
 * - target: The person.
 * - carrier: The carrier the shot lands on: theirs, or a garment's.
 */
/proc/dirt_taur_takes_pools(mob/living/carbon/human/target, datum/component/dirtiness/carrier)
	if(isitem(carrier.parent) && dirt_taur_fitted(carrier.parent, target))
		return FALSE
	var/obj/item/organ/taur_body/organ = target.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	var/obj/item/bodypart/chest = target.get_bodypart(BODY_ZONE_CHEST)
	if(!istype(organ) || !chest)
		return FALSE
	var/datum/bodypart_overlay/mutant/taur_body/taur = organ.bodypart_overlay
	return istype(taur) && taur.can_draw_on_bodypart(chest, target) && !!taur.dirt_read_source(chest)

/**
 * Returns whether a general cause's dirt in a material lands on a taur's lower half: its taur body, or the taur suit
 * over it. It lands if it reaches the legs the taur body stands in place of, or if it's slime on the back, the front
 * or the legs (dirt_splat_region()). A wet material never does, because neither a coat nor a hem band takes sweat.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - material: Its /datum/dirt_material.
 */
/proc/dirt_taur_takes(cause, datum/dirt_material/material)
	var/static/list/slimed_causes = list(DIRT_CAUSE_SLIMED, DIRT_CAUSE_SLIMED_BACK, DIRT_CAUSE_SLIMED_CHEST, DIRT_CAUSE_SLIMED_R_LEG, DIRT_CAUSE_SLIMED_L_LEG)
	if(material.flags & DIRT_MATERIAL_WET)
		return FALSE
	if(copytext(cause, 1, length(DIRT_CAUSE_SLIMED) + 1) == DIRT_CAUSE_SLIMED)
		return cause in slimed_causes
	return !!(dirt_cause_reach(cause, material) & (DIRT_LIMB_BIT(DIRT_LIMB_R_LEG) | DIRT_LIMB_BIT(DIRT_LIMB_L_LEG)))

/**
 * Returns the outermost taur suit a taur wears over its taur body (dirt_taur_fitted()), or null. The suit takes the
 * general dirt the taur body would take, as its hem band.
 *
 * Arguments:
 * - target: The person.
 */
/proc/dirt_taur_suit(mob/living/carbon/human/target)
	RETURN_TYPE(/obj/item)
	for(var/slot in list(ITEM_SLOT_OCLOTHING, ITEM_SLOT_ICLOTHING))
		var/obj/item/worn = target.get_item_by_slot(slot)
		if(worn && dirt_taur_fitted(worn, target))
			return worn
	return null

/**
 * Returns a blank icon the size of a canvas (dirt_canvases()), for masks on it. You should NEVER modify it.
 *
 * Arguments:
 * - canvas: A DIRT_CANVAS_* define.
 */
/proc/dirt_canvas_blank(canvas)
	RETURN_TYPE(/icon)
	var/static/alist/blanks = alist()
	var/icon/blank = blanks[canvas]
	if(!blank)
		var/list/size = dirt_canvases()[canvas]
		blank = icon('icons/blanks/32x32.dmi', "nothing")
		blank.Crop(1, 1, size[1], size[2])
		// loaded once here, or every copy loads it again
		blank.GetPixel(1, 1)
		blanks[canvas] = blank
	return blank

#undef DIRT_POOL_KEY
#undef DIRT_MESS_TAUR_SEED
