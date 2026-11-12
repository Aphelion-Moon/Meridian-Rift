// Contact coats on taur bodies: mud and dust spread from wherever each kind touches the ground. Every pixel of the
// kind's own silhouette has a distance through the body to the nearest pixel touching the floor. Dirt is densest at
// contact and fades with that distance along a noise-roughened line. So it climbs legs from the hooves, fills a coil
// from below, runs up spider legs from their tips, and fades across a belly instead of stopping at a column. A band
// over the whole canvas would slice a taur in half, and coats kept to the columns touching the floor would cut off
// sharply at their edges.

/**
 * A taur body in one direction as its contact coats read it: its silhouette, with every layer's states together, and
 * each pixel's distance through it to the floor. It's also a surface as dirt_halo() reads one: the body's pixels lie on
 * it, and those with a side off the body are its rim.
 */
/datum/dirt_canvas_view/taur
	/// alist(index = TRUE) on the taur body's pixels.
	var/alist/mask
	/// alist(index = TRUE) on its pixels that have no pixel of its own directly under them.
	var/alist/underside
	/// alist(index = TRUE) on the pixels touching the floor that are hooves, paws or leg tips: not a resting coil.
	var/alist/feet
	/// Each pixel's distance through the body to the nearest pixel touching the floor, indexed by pixel. Null where no
	/// path through the body reaches the floor. Steps across and down count 1, diagonals 1.414.
	var/list/distances

/**
 * Reads a taur body's silhouette in one direction and measures it.
 *
 * Arguments:
 * - source: The taur body.
 * - direction: The direction.
 */
/datum/dirt_canvas_view/taur/New(datum/dirt_taur_source/source, direction)
	..(DIRT_CANVAS_TAUR, direction)
	mask = alist()
	for(var/layer_key, states in source.layer_states)
		for(var/state in states)
			for(var/index in dirt_sprite_pixels(source.icon, state, direction, DIRT_TAUR_WIDTH))
				mask[index] = TRUE
	var/list/table = dirt_neighbour_table(width, height)
	flags_of = new /list(width * height)
	underside = alist()
	var/lowest
	for(var/index in mask)
		var/flags = DIRT_LIMB_TORSO
		// a side off the canvas is off the body too
		if(length(table[index]) < 4)
			flags |= DIRT_PIXEL_RIM
		else
			for(var/neighbour in table[index])
				if(!mask[neighbour])
					flags |= DIRT_PIXEL_RIM
					break
		flags_of[index] = flags
		var/row = floor((index - 1) / width)
		if(row == height - 1 || !mask[index + width])
			underside[index] = TRUE
		lowest = isnull(lowest) ? row : max(lowest, row)
	// some sprites stop short of the canvas's last row, so the floor is under their lowest row
	var/list/contact = list()
	var/list/contact_columns = new /list(width)
	for(var/index in underside)
		if(floor((index - 1) / width) >= lowest - 1)
			contact += index
			contact_columns[(index - 1) % width + 1] = TRUE
	// runs of touching columns 6 or fewer wide are feet
	var/list/narrow = new /list(width)
	var/run_start
	for(var/column in 0 to width)
		if(column < width && contact_columns[column + 1])
			if(isnull(run_start))
				run_start = column
			continue
		if(!isnull(run_start) && column - run_start <= 6)
			for(var/run_column in run_start to column - 1)
				narrow[run_column + 1] = TRUE
		run_start = null
	feet = alist()
	for(var/index in contact)
		if(narrow[(index - 1) % width + 1])
			feet[index] = TRUE
	measure(contact)

/**
 * Measures each pixel's distance through the body to the floor (distances), by Dijkstra's search from the pixels
 * touching it, nearest first. Each pixel ends at the least of its neighbours' distances plus the step to it, whatever
 * order they're taken in. So ties need no order of their own.
 *
 * Arguments:
 * - contact: The pixels touching the floor.
 */
/datum/dirt_canvas_view/taur/proc/measure(list/contact)
	// each list(columns right, rows down, length)
	var/static/list/steps = list(list(1, 0, 1), list(-1, 0, 1), list(0, 1, 1), list(0, -1, 1), list(1, 1, 1.414), list(1, -1, 1.414), list(-1, 1, 1.414), list(-1, -1, 1.414))
	distances = new /list(width * height)
	var/list/heap_distances = list()
	var/list/heap_indexes = list()
	for(var/index in contact)
		distances[index] = 0
		dirt_heap_push(heap_distances, heap_indexes, 0, index)
	// a pixel is pushed at most once per neighbour that shortens its distance, so this many pops empty the heap
	for(var/popped in 1 to length(mask) * 9 + 1)
		if(!length(heap_indexes))
			break
		var/distance = heap_distances[1]
		var/index = dirt_heap_pop(heap_distances, heap_indexes)
		if(distance > distances[index])
			continue
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		for(var/list/step_by as anything in steps)
			var/near_column = column + step_by[1]
			var/near_row = row + step_by[2]
			if(near_column < 0 || near_row < 0 || near_column >= width || near_row >= height)
				continue
			var/near = near_row * width + near_column + 1
			if(!mask[near])
				continue
			var/through = distance + step_by[3]
			if(isnull(distances[near]) || through < distances[near])
				distances[near] = through
				dirt_heap_push(heap_distances, heap_indexes, through, near)

/**
 * Adds an entry to a binary heap kept least first: by key, then by value.
 *
 * Arguments:
 * - keys: The heap's keys, changed.
 * - values: Its values, changed alongside.
 * - key: The entry's key.
 * - value: Its value.
 */
/proc/dirt_heap_push(list/keys, list/values, key, value)
	keys += key
	values += value
	var/position = length(keys)
	// each step halves the position
	while(position > 1)
		var/parent = floor(position / 2)
		if(keys[parent] < key || (keys[parent] == key && values[parent] < value))
			break
		keys[position] = keys[parent]
		values[position] = values[parent]
		position = parent
	keys[position] = key
	values[position] = value

/**
 * Takes the least entry off a binary heap (dirt_heap_push()) and returns its value. Its key was keys[1].
 *
 * Arguments:
 * - keys: The heap's keys, not empty, changed.
 * - values: Its values, changed alongside.
 */
/proc/dirt_heap_pop(list/keys, list/values)
	. = values[1]
	var/count = length(keys) - 1
	var/last_key = keys[count + 1]
	var/last_value = values[count + 1]
	keys.len = count
	values.len = count
	if(!count)
		return
	var/position = 1
	// each step doubles the position
	while(position * 2 <= count)
		var/child = position * 2
		if(child < count && (keys[child + 1] < keys[child] || (keys[child + 1] == keys[child] && values[child + 1] < values[child])))
			child++
		if(last_key < keys[child] || (last_key == keys[child] && last_value < values[child]))
			break
		keys[position] = keys[child]
		values[position] = values[child]
		position = child
	keys[position] = last_key
	values[position] = last_value

/**
 * Every random draw a taur coat makes. They don't depend on its level, so its levels nest. A speck's or a tongue's pick
 * is kept as the whole random draw, and turned into a place once the list it picks from is known (dirt_taur_picked()).
 */
/datum/dirt_taur_draws
	/// How far through the body the coat's line reaches at each level.
	var/list/reach
	/// The seed of its noise, a whole number.
	var/seed
	/// Its specks, each list(pick, how far past the line, whether it's a drip).
	var/list/specks
	/// Its tongues, each list(pick, how much higher the line climbs there).
	var/list/tongues

/**
 * Returns a taur coat's random draws, from its stream. It takes the random draws for flecks too, though the coat
 * doesn't use them, so the tongues keep their places in the stream.
 *
 * Arguments:
 * - rng: The coat's "taur:<cause>:<variant>" stream.
 */
/proc/dirt_taur_draws(datum/dirt_random/rng)
	RETURN_TYPE(/datum/dirt_taur_draws)
	var/datum/dirt_taur_draws/draws = new
	var/second_reach = rng.uniform(6, 7)
	draws.reach = list(3, second_reach, rng.uniform(10, 13))
	draws.seed = rng.randrange(65536)
	draws.specks = list()
	for(var/speck_number in 1 to 16)
		var/pick = SSdirt.drafting ? rng.random() : rng.draw()
		var/extra = rng.uniform(1.5, 4.5)
		draws.specks += list(list(pick, extra, rng.random() < 0.35))
	for(var/fleck_number in 1 to 24)
		rng.random()
		rng.uniform(0.55, 1.45)
		rng.randrange(3)
	draws.tongues = list()
	for(var/tongue_number in 1 to 3)
		var/pick = SSdirt.drafting ? rng.random() : rng.draw()
		draws.tongues += list(list(pick, rng.uniform(1.5, 2.5)))
	return draws

/**
 * Returns the item a taur coat's pick lands on: the whole random draw modulo the count, or, while drafting,
 * the draft's int(random() * (count - 1)).
 *
 * Arguments:
 * - items: The list picked from, not empty.
 * - pick: The pick, from dirt_taur_draws().
 */
/proc/dirt_taur_picked(list/items, pick)
	if(SSdirt.drafting)
		return items[dirt_fraction_index(pick, length(items) - 1) + 1]
	return items[pick % length(items) + 1]

/**
 * Returns how much higher a coat's line climbs at each column, indexed by column + 1, or null where it doesn't climb.
 * These tongues are narrow places where the mud drags up the body, one column each, because a wider one reads as a
 * seam. Level 2 has one, and each level after it one more. The first tongue on a column holds it.
 *
 * Arguments:
 * - view: The taur body.
 * - draws: The coat's random draws.
 * - level: 1 to 3.
 */
/proc/dirt_taur_tongues(datum/dirt_canvas_view/taur/view, datum/dirt_taur_draws/draws, level)
	RETURN_TYPE(/list)
	var/list/tongues = new /list(view.width)
	if(level < 2 || !length(view.mask))
		return tongues
	var/list/shown = new /list(view.width)
	for(var/index in view.mask)
		shown[(index - 1) % view.width + 1] = TRUE
	var/list/columns = list()
	for(var/column in 0 to view.width - 1)
		if(shown[column + 1])
			columns += column
	for(var/position in 1 to level - 1)
		var/list/tongue = draws.tongues[position]
		var/column = dirt_taur_picked(columns, tongue[1])
		if(isnull(tongues[column + 1]))
			tongues[column + 1] = tongue[2]
	return tongues

/**
 * Returns a coat's thickness on some of a taur body's pixels at one level, alist(index = thickness). The coat is solid
 * under the feet. Up to a noise-roughened line, in distance through the body, it goes from the body role near the
 * ground through a wide film band to haze. The line's noise is stretched along it, because round noise reads as camo.
 * Extra kick-up film lies along the belly. One spray field breaks the coat up: film blots in the haze, and mud thrown
 * up past the line in soft blots that thin out. A light material reaches less, keeps the body role only in clumps by
 * the contact, and breaks its film up. Each pixel's thickness is worked out from that pixel alone. Its noise doesn't
 * depend on the level: the line's roughening, the spray, the belly's kick-up and a light material's breaks are the
 * same at every level of a coat. So its field samples them once a pixel, and the spray only where it's read.
 *
 * Arguments:
 * - view: The taur body.
 * - draws: The coat's random draws.
 * - level: 1 to 3.
 * - light: Whether its material is light.
 * - tongues: The level's tongues (dirt_taur_tongues()).
 * - pixels: The body's pixels, in the mask's order.
 * - first_pixel, last_pixel: Which of them, from 1.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/proc/dirt_taur_coat_thickness(datum/dirt_canvas_view/taur/view, datum/dirt_taur_draws/draws, level, light, list/tongues, list/pixels, first_pixel, last_pixel, alist/samples)
	RETURN_TYPE(/alist)
	// how far thrown mud rides up past the line, through the body, by level
	var/static/list/rises = list(2, 3.5, 5)
	var/alist/coat = alist()
	var/reach = draws.reach[level] * (light ? 0.75 : 1)
	var/rise = rises[level]
	var/width = view.width
	var/seed = draws.seed
	for(var/position in first_pixel to last_pixel)
		var/index = pixels[position]
		var/distance = view.distances[index]
		if(isnull(distance))
			continue
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		var/line = reach + (dirt_field_spread_noise(samples, "taur line", index, column * 0.45, row, seed, 3.4) - 0.5) * 2.6
		if(tongues[column + 1])
			line += tongues[column + 1]
		var/share = distance / max(1, line)
		var/thickness
		if(distance < 0.5 && level >= 2)
			// core belongs to a foot, because core along a coil's full length reads as an outline
			thickness = view.feet[index] ? 1 : DIRT_BODY_T
		else if(share <= 0.32)
			thickness = DIRT_BODY_T
		else if(share <= 0.72)
			thickness = DIRT_FILM_T
		else if(share <= 1 || distance - line <= rise)
			var/spray = 0.5 * dirt_field_spread_noise(samples, "spray", index, column * 0.5, row, seed + 61, 3) + 0.5 * dirt_field_spread_noise(samples, "spray fine", index, column, row, seed + 67, 1.2)
			if(share <= 1)
				thickness = spray > 0.86 ? DIRT_FILM_T : DIRT_HAZE_T
			else
				var/settled = spray - 0.3 * (distance - line) / rise
				thickness = settled > 0.82 ? DIRT_FILM_T : (settled > 0.6 ? DIRT_HAZE_T : null)
		// kick-up along the belly, broken
		if(isnull(thickness) && share > 1 && level >= 2 && view.underside[index] && distance <= line + 4 && dirt_field_noise_hash(samples, "belly", index, column, row, seed) < 0.5)
			thickness = DIRT_FILM_T
		if(isnull(thickness))
			continue
		if(light)
			if(thickness == DIRT_BODY_T && share > 0.15)
				thickness = DIRT_FILM_T
			if(thickness == DIRT_FILM_T && dirt_field_spread_noise(samples, "light", index, column, row, seed + 41, 2.5) < 0.42)
				continue
		coat[index] = thickness
	return coat

/**
 * Puts soft specks beyond a taur coat's line, changing the mask: four at level 2 and eight at 3. Each goes on the pixel
 * its pick lands on, among those within 0.8 px either side of its distance past the line. It's kept clear of the coat
 * and of every speck's rows and columns (dirt_place_speck()). The pixels are picked from in row-major order, or, while
 * drafting, column by column, as the draft picked them.
 *
 * Arguments:
 * - view: The taur body.
 * - draws: The coat's random draws.
 * - level: 1 to 3.
 * - drawn: The coat, changed.
 */
/proc/dirt_taur_specks(datum/dirt_canvas_view/taur/view, datum/dirt_taur_draws/draws, level, datum/dirt_pixels/drawn)
	var/static/list/counts = list(0, 4, 8)
	var/count = counts[level]
	if(!count)
		return
	var/width = view.width
	var/height = view.height
	var/list/points = list()
	if(SSdirt.drafting)
		for(var/column in 0 to width - 1)
			for(var/row in 0 to height - 1)
				if(view.mask[row * width + column + 1])
					points += row * width + column + 1
	else
		for(var/index in view.mask)
			points += index
	var/reach = draws.reach[level]
	var/list/used_rows = new /list(height)
	var/list/used_columns = new /list(width)
	var/placed = 0
	for(var/list/speck as anything in draws.specks)
		if(placed >= count)
			break
		var/low = reach + speck[2] - 0.8
		var/high = reach + speck[2] + 0.8
		var/list/band = list()
		for(var/index in points)
			var/distance = view.distances[index]
			if(!isnull(distance) && low <= distance && distance <= high)
				band += index
		if(!length(band))
			continue
		var/index = dirt_taur_picked(band, speck[1])
		var/row = floor((index - 1) / width)
		if(dirt_place_speck(drawn, dirt_soft_speck(index - 1 - row * width, row, speck[3], width, height, view.mask), used_rows, used_columns))
			placed++

/**
 * Returns a contact coat on a taur body in one direction, on the 64x32 taur canvas. It holds levels 1 to `level`,
 * each from the same random draws of the "taur:<cause>:<variant>" stream (dirt_taur_draws()). They're merged by role
 * rank, and the later level wins a tie. Each level's coat (dirt_taur_coat_thickness()) is cleaned up (dirt_cleanup())
 * and takes its material's edge, halo or tide. For walking (not dust) it takes its specks too (dirt_taur_specks()).
 * A light material draws film at the contact, because core there would paint a light outline. A material's sheen
 * draws nothing here, because it looks for a leg. The coat is drawn while drafting, by its field
 * (/datum/dirt_canvas_field/taur_coat), its bands back to back, as a mask job draws them a piece each.
 *
 * Arguments:
 * - source: The taur body.
 * - cause: DIRT_CAUSE_WALK or DIRT_CAUSE_DUST.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - direction: The direction.
 */
/proc/dirt_taur_coat(datum/dirt_taur_source/source, cause, datum/dirt_material/material, level, variant, direction)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_taur_coat), args.Copy())
#endif
	var/datum/dirt_canvas_field/taur_coat/field = new(source, cause, material, level, variant, direction)
	// a turn for its view, then each level's bands, which cover the canvas's pixels at most, and its finish
	for(var/turn in 1 to 1 + field.level * (ceil(ICON_SIZE_Y / field.band_rows) + 1))
		if(field.draw_rows(field.band_rows))
			break
	return field.merged

/**
 * Returns the contact coat a general cause draws on a taur body (dirt_taur_coat()): walking's for walking and crawling,
 * and dust's for dust. It draws on the fur, and on a taur suit's cloth as the coat of the body it hides. Returns null
 * for any other cause.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 */
/proc/dirt_taur_coat_cause(cause)
	switch(cause)
		if(DIRT_CAUSE_WALK, DIRT_CAUSE_CRAWL)
			return DIRT_CAUSE_WALK
		if(DIRT_CAUSE_DUST)
			return DIRT_CAUSE_DUST
	return null

/**
 * A taur body's contact coat in one direction, as dirt_taur_coat() draws it. It's drawn some of its body's pixels at a
 * time (draw_rows()). A mask job draws it a band a piece (dirt_canvas_field_band()) and keeps it among its fields
 * (/datum/dirt_mask_job/proc/field_for()). Its first band reads the body (/datum/dirt_canvas_view/taur) and makes the
 * coat's random draws (dirt_taur_draws()), as a piece of its own. Then each level's coat (dirt_taur_coat_thickness())
 * is drawn over the body's pixels a band of them at a time, in the mask's order, as many as a field's band draws of the
 * canvas. Once the level's last pixel is drawn, its finish (cleanup, edge, specks) is a band of its own, stacked on the
 * levels before.
 *
 * It draws the same pixels however it's banded. dirt_taur_coat() draws a whole coat through it too, its bands back to
 * back, so the job's draw and the whole one are one code path. Each coat pixel is worked out from that pixel alone, and
 * each level picks its tongues as its first band begins. Every level takes the one set of random draws (the stream's
 * first, the same for each), and each finish runs once, on the whole level.
 */
/datum/dirt_canvas_field/taur_coat
	/// The taur body, until it's read.
	var/datum/dirt_taur_source/source
	/// The direction.
	var/direction
	/// The variant, which names its random draws' stream.
	var/variant
	/// Whether its material is light.
	var/light = FALSE
	/// Its random draws (dirt_taur_draws()), made with its view.
	var/datum/dirt_taur_draws/draws
	/// The body's pixels, in the mask's order. Each level's coat is drawn a band of them at a time.
	var/list/pixels
	/// The next pixel of the level being drawn, from 1.
	var/next_pixel = 1
	/// The tongues of the level being drawn (dirt_taur_tongues()).
	var/list/tongues

/**
 * Arguments:
 * - source, cause, material, level, variant, direction: As dirt_taur_coat()'s.
 */
/datum/dirt_canvas_field/taur_coat/New(datum/dirt_taur_source/source, cause, datum/dirt_material/material, level, variant, direction)
	// its view is the body's own, made at its first band, so the canvas field's New() isn't run
	src.source = source
	src.cause = cause
	src.material = material
	src.level = min(level, DIRT_DEPOSIT_MAX_LEVEL)
	src.variant = variant
	src.direction = direction
	light = !!(material.flags & DIRT_MATERIAL_LIGHT)
	merged = new(DIRT_TAUR_WIDTH, ICON_SIZE_Y)
	band_rows = dirt_field_band_rows(DIRT_TAUR_WIDTH)
	samples = alist()

/**
 * Draws the coat's next piece. The first piece makes its view and random draws. Each piece after that draws a level's
 * coat on as many of the body's next pixels as `rows` of the canvas hold, and the level's first piece picks its
 * tongues. Once the level's last pixel is drawn, the next piece is its finish, stacked on the levels before. Once the
 * last level's finish is drawn, the view, random draws and samples go. Call it while drafting.
 *
 * Arguments:
 * - rows: How many pixels to draw, counted in rows of the canvas, at least one.
 *
 * Returns whether every level is drawn.
 */
/datum/dirt_canvas_field/taur_coat/draw_rows(rows)
	if(done)
		return TRUE
	var/datum/dirt_canvas_view/taur/taur_view = view
	if(!taur_view)
		taur_view = new(source, direction)
		view = taur_view
		source = null
		draws = dirt_taur_draws(dirt_general_stream("taur:[cause]:[num2text(variant, 12)]"))
		pixels = list()
		for(var/index in taur_view.mask)
			pixels += index
		return FALSE
	if(!drawn)
		drawing_level++
		drawn = new(taur_view.width, taur_view.height)
		tongues = dirt_taur_tongues(taur_view, draws, drawing_level)
		next_pixel = 1
	if(next_pixel <= length(pixels))
		var/last_pixel = min(next_pixel + rows * taur_view.width, length(pixels) + 1) - 1
		for(var/index, thickness in dirt_taur_coat_thickness(taur_view, draws, drawing_level, light, tongues, pixels, next_pixel, last_pixel, samples))
			var/role = dirt_thickness_role(thickness)
			drawn.put_index(index, (light && role == DIRT_ROLE_CORE) ? DIRT_ROLE_FILM : role, thickness)
		next_pixel = last_pixel + 1
		return FALSE
	drawn = dirt_cleanup(drawn)
	switch(material.edge)
		if(DIRT_EDGE_HALO)
			drawn = dirt_halo(drawn, taur_view)
		if(DIRT_EDGE_TIDE)
			drawn = dirt_tide(drawn)
	if(cause != DIRT_CAUSE_DUST)
		dirt_taur_specks(taur_view, draws, drawing_level, drawn)
	dirt_stack_level(merged, drawn)
	drawn = null
	tongues = null
	if(drawing_level < level)
		return FALSE
	done = TRUE
	view = null
	draws = null
	pixels = null
	samples = null
	return TRUE
