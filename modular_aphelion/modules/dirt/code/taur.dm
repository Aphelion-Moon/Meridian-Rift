/// A pool pixel as a key, from its column and row on the taur canvas: a pool's drip can run a few pixels off it.
#define DIRT_POOL_KEY(column, row) (((row) + 8) * 100 + (column) + 8)
/// A fixed seed value, the reference generator's: changing it reshapes every taur splat.
#define DIRT_MESS_TAUR_SEED "semen:aimed_back:taur"

/**
 * A taur body's sprite as mess reads it: each of its layers' states, its colour layers' together, as the taur body
 * draws them on the 64x32 taur canvas. A mess aimed at the back puts pools along the back these pixels show
 * (dirt_taur_pools()). Made once and never changed.
 */
/datum/dirt_taur_source
	/// The sheet: an icon file, or an icon made at run time.
	var/icon
	/// alist(EXTERNAL_* layer key = list of the states drawn at that layer).
	var/alist/layer_states
	/// taur_key(), once built.
	var/cached_key

/**
 * Arguments:
 * - icon: The sheet.
 * - layer_states: alist(EXTERNAL_* = list of states).
 */
/datum/dirt_taur_source/New(icon, alist/layer_states)
	. = ..()
	src.icon = icon
	src.layer_states = layer_states

/// Returns what the source draws, as text: taur bodies with the same key take pools on the same pixels.
/datum/dirt_taur_source/proc/taur_key()
	if(cached_key)
		return cached_key
	var/list/parts = list(dirt_sprite_key(icon))
	for(var/layer_key in dirt_taur_stack())
		var/list/states = layer_states[layer_key]
		if(length(states))
			parts += "[layer_key]=[jointext(states, ",")]"
	cached_key = jointext(parts, "|")
	return cached_key

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
 * Returns what each pixel of the taur canvas shows in one direction: the EXTERNAL_* layer of the taur body drawn last
 * over it, DIRT_TAUR_RIDER where the rider (the body, 16 px in) is drawn over the taur body, or null, as
 * dirt_taur_stack() stacks them.
 *
 * Arguments:
 * - source: The taur body.
 * - rider: The rider's surface in that direction, the template of the body drawn on the taur.
 * - direction: The direction.
 */
/proc/dirt_taur_owners(datum/dirt_taur_source/source, datum/dirt_surface/rider, direction)
	RETURN_TYPE(/list)
	var/list/owners = new /list(DIRT_TAUR_WIDTH * ICON_SIZE_Y)
	for(var/shown in dirt_taur_stack())
		if(shown != DIRT_TAUR_RIDER)
			for(var/state in source.layer_states[shown])
				for(var/index in dirt_sprite_pixels(source.icon, state, direction, DIRT_TAUR_WIDTH))
					owners[index] = shown
			continue
		var/list/flags_of = rider.flags_of
		for(var/index in 1 to length(flags_of))
			if(DIRT_PIXEL_ZONE(flags_of[index]))
				var/row = floor((index - 1) / ICON_SIZE_X)
				owners[index + row * (DIRT_TAUR_WIDTH - ICON_SIZE_X) + DIRT_TAUR_INSET] = DIRT_TAUR_RIDER
	return owners

/**
 * Returns a back shot's pools on a taur body in one direction: dirt_mess_splat_rasterise() on the pixels the taur body
 * shows, keeping clear of the rider's mess there.
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
	var/list/mask_pixels = list()
	for(var/index in 1 to length(owners))
		var/shown = owners[index]
		if(shown && shown != DIRT_TAUR_RIDER)
			mask_pixels += index
	var/list/avoid = list()
	var/list/taken = new /list(length(owners))
	for(var/drawn in rider_mess)
		for(var/index in dirt_drawn_indexes(drawn))
			var/row = floor((index - 1) / ICON_SIZE_X)
			var/canvas_index = index + row * (DIRT_TAUR_WIDTH - ICON_SIZE_X) + DIRT_TAUR_INSET
			if(owners[canvas_index] == DIRT_TAUR_RIDER && !taken[canvas_index])
				taken[canvas_index] = TRUE
				avoid += canvas_index
	return dirt_mess_splat_rasterise(mask_pixels, level, variant, direction, avoid)

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
 * Returns a 64x32 blank, for masks on the taur canvas. You should NEVER modify it.
 */
/proc/dirt_taur_blank()
	RETURN_TYPE(/icon)
	var/static/icon/blank
	if(!blank)
		blank = icon('icons/blanks/32x32.dmi', "nothing")
		blank.Crop(1, 1, DIRT_TAUR_WIDTH, ICON_SIZE_Y)
		// loaded once here, or every copy loads it again
		blank.GetPixel(1, 1)
	return blank

#undef DIRT_POOL_KEY
#undef DIRT_MESS_TAUR_SEED
