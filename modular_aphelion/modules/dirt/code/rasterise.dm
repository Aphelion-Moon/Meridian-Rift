/**
 * One mask's pixels: a tone role and a thickness for each. Lists are indexed y * width + x + 1 in the reference
 * generator's coordinates, as a /datum/dirt_surface's are: x from the left and y from the top, both from 0.
 */
/datum/dirt_pixels
	/// Pixels across.
	var/width
	/// Pixels down.
	var/height
	/// Each pixel's DIRT_ROLE_* define, or null where nothing is drawn.
	var/list/roles
	/// Each drawn pixel's thickness, from 0 to 1. Where masks merge, the thicker one wins a pixel its role ties on.
	var/list/thicknesses
	/// Whether it's a splat at the top level, which covers: where splats merge, it keeps every piece (dirt_merge()).
	var/covers = FALSE
	/// For a mask made again from a cached raster (dirt_pixels_from_drawn()), the pixels it was drawn on, so a merge
	/// walks those alone; null for one drawn here. Pixels cleared since stay listed.
	var/list/drawn_indexes

/**
 * Starts an empty mask.
 *
 * Arguments:
 * - width: Pixels across.
 * - height: Pixels down.
 */
/datum/dirt_pixels/New(width = ICON_SIZE_X, height = ICON_SIZE_Y)
	. = ..()
	src.width = width
	src.height = height
	roles = new /list(width * height)
	thicknesses = new /list(width * height)

/**
 * Returns a copy of the mask, its own lists.
 */
/datum/dirt_pixels/proc/copy()
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/copied = new(width, height)
	copied.roles = roles.Copy()
	copied.thicknesses = thicknesses.Copy()
	copied.covers = covers
	return copied

/**
 * Returns the mask as text, one line per row joined by newlines, one glyph per pixel: "." none, "h" haze, "f" film,
 * "b" body, "c" core, "k" fleck, "g" glint.
 */
/datum/dirt_pixels/proc/grid_text()
	var/static/glyphs = ".hfbckg"
	var/list/lines = list()
	for(var/row in 0 to height - 1)
		var/list/glyph_row = list()
		for(var/column in 0 to width - 1)
			var/role = roles[row * width + column + 1] || DIRT_ROLE_NONE
			glyph_row += copytext(glyphs, role + 1, role + 2)
		lines += jointext(glyph_row, "")
	return jointext(lines, "\n")

/**
 * Returns list(1, 2, ... count), made once for each count. You should NEVER modify it.
 *
 * Arguments:
 * - count: How many.
 */
/proc/dirt_index_range(count)
	RETURN_TYPE(/list)
	var/static/alist/ranges = alist()
	var/list/range = ranges[count]
	if(!range)
		range = list()
		for(var/index in 1 to count)
			range += index
		ranges[count] = range
	return range

/**
 * Returns each role's rank, indexed by its DIRT_ROLE_* define: where masks or levels meet, the higher rank keeps the
 * pixel. You should NEVER modify it.
 */
/proc/dirt_role_ranks()
	RETURN_TYPE(/list)
	var/static/list/ranks = list(0.5, 1, 2, 3, 2, 2) // haze, film, body, core, fleck, glint
	return ranks

/**
 * Returns each pixel's neighbours on a canvas, in the order the reference generator visits them: right, left, below,
 * above, those off the canvas left out. Built once per canvas size. You should NEVER modify it.
 *
 * Arguments:
 * - width: Pixels across.
 * - height: Pixels down.
 */
/proc/dirt_neighbour_table(width, height)
	RETURN_TYPE(/list)
	var/static/alist/tables = alist()
	var/key = "[width]x[height]"
	var/list/table = tables[key]
	if(table)
		return table
	table = new /list(width * height)
	for(var/row in 0 to height - 1)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			var/list/neighbours = list()
			if(column < width - 1)
				neighbours += index + 1
			if(column > 0)
				neighbours += index - 1
			if(row < height - 1)
				neighbours += index + width
			if(row > 0)
				neighbours += index - width
			table[index] = neighbours
	tables[key] = table
	return table

/**
 * Returns a surface's pixels grouped by limb and row, so a feature is weighed only on the rows it can reach:
 * alist(limb = list(list(row, lowest h, highest h, indexes), ...)), rows from the top. Built once for each surface. You
 * should NEVER modify it.
 *
 * Arguments:
 * - surface: The surface.
 */
/proc/dirt_surface_rows(datum/dirt_surface/surface)
	RETURN_TYPE(/alist)
	if(surface.limb_row_pixels)
		return surface.limb_row_pixels
	var/alist/by_limb = alist()
	surface.limb_row_pixels = by_limb
	var/list/flags_of = surface.flags_of
	var/list/height_of = surface.height_of
	for(var/index in 1 to length(flags_of))
		var/limb = DIRT_PIXEL_LIMB(flags_of[index])
		if(!limb)
			continue
		var/row = floor((index - 1) / surface.width)
		var/along = height_of[index]
		var/list/rows = by_limb[limb]
		if(!rows)
			rows = list()
			by_limb[limb] = rows
		// pixels come row by row, so a limb's last row is the only one still filling
		var/list/entry = length(rows) ? rows[length(rows)] : null
		if(!entry || entry[1] != row)
			rows += list(list(row, along, along, list(index)))
			continue
		entry[2] = min(entry[2], along)
		entry[3] = max(entry[3], along)
		var/list/indexes = entry[4]
		indexes += index
	return by_limb

/**
 * Returns mess aimed at a zone, drawn on one direction of a body: levels 1 to `level`, each from the deposit's same
 * draws, merged by role rank with the later level winning a tie, then despeckled. A highlight, once drawn, stays: a
 * later run beside it folded it in. The top level then breaks its flat edges, and keeps every pixel of level 3 as it
 * was drawn, at its role or a darker one.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define, not DIRT_ZONE_COCK.
 * - level: 1 to DIRT_MESS_MAX_LEVEL.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - surface: The direction's surface.
 */
/proc/dirt_rasterise_aimed(zone, level, variant, surface_kind, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/alist/surface_rows = dirt_surface_rows(surface)
	var/list/ranks = dirt_role_ranks()
	var/datum/dirt_pixels/merged = new(surface.width, surface.height)
	var/list/merged_roles = merged.roles
	var/list/merged_thicknesses = merged.thicknesses
	var/datum/dirt_aim/aim = new(zone, variant)
	var/datum/dirt_pixels/below
	for(var/each_level in 1 to level)
		var/list/features = dirt_runs_apart(aim.features(each_level), surface, surface_rows)
		var/datum/dirt_pixels/drawn = dirt_rasterise_level(features, surface_kind, surface, surface_rows)
		var/list/roles = drawn.roles
		for(var/index in 1 to length(roles))
			var/role = roles[index]
			if(!role)
				continue
			var/held = merged_roles[index]
			if(held == DIRT_ROLE_GLINT)
				continue
			if(!held || ranks[role] >= ranks[held])
				merged_roles[index] = role
				merged_thicknesses[index] = drawn.thicknesses[index]
		if(level == DIRT_MESS_MAX_LEVEL && each_level == DIRT_MESS_MAX_LEVEL - 1)
			below = dirt_despeckle(merged, surface)
	merged = dirt_despeckle(merged, surface)
	if(level != DIRT_MESS_MAX_LEVEL)
		return merged
	// after the despeckle, so what it breaks stays broken; three times, as a rise can meet another edge
	for(var/pass in 1 to 3)
		merged = dirt_ragged_edges(merged, surface, 4000 + variant)
	merged_roles = merged.roles
	merged_thicknesses = merged.thicknesses
	var/list/below_roles = below.roles
	for(var/index in 1 to length(below_roles))
		var/role = below_roles[index]
		var/held = merged_roles[index]
		if(role && (!held || ranks[held] < ranks[role]))
			merged_roles[index] = role
			merged_thicknesses[index] = below.thicknesses[index]
	merged.covers = TRUE
	return merged

/**
 * Returns a level's features with the runs and drops this view leaves out taken out, and its run plan with them. In the
 * plan's order, each run or drop stays only if it keeps DIRT_RUN_GAP px of skin from level 1's shot and from every one
 * kept before it: side by side they filled into a sheet. The two hung from level 1's shot and drop always stay. Then
 * each kept run's carry-on stays where it keeps as clear, and level 2's carry-on from the first drop where level 2
 * shows nothing new in the zone's main facing. The plan holds the top run level's set, so every level keeps
 * the same ones.
 *
 * Arguments:
 * - features: The level's features, bound to the view.
 * - surface: The view's surface.
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/proc/dirt_runs_apart(list/features, datum/dirt_surface/surface, alist/surface_rows)
	RETURN_TYPE(/list)
	var/datum/dirt_feature/run_plan/plan = locate() in features
	if(!plan)
		return features
	var/list/rest = features - plan
	var/list/always = list() // level 1's shot, and whatever else is always drawn but the covering
	var/list/early = list()
	for(var/datum/dirt_feature/feature as anything in rest)
		if(isnull(feature.run_group) && !feature.covering)
			always += feature
		else if(feature.run_group == DIRT_RUN_GROUP_EARLY)
			early += feature
	var/alist/taken = dirt_footprint(always, surface, surface_rows)
	var/list/kept = list()
	var/alist/owned = alist()
	for(var/list/entry as anything in plan.groups)
		var/group = entry[1]
		var/list/members = list()
		for(var/datum/dirt_feature/member as anything in entry[2])
			if(!member.from_level)
				members += member
		var/alist/pixels = dirt_footprint(members, surface, surface_rows)
		if(group == 0 || group == 10 || !dirt_footprint_touches(pixels, taken, surface.width, surface.height))
			kept += group
			for(var/index in pixels)
				taken[index] = TRUE
			owned[group] = pixels
	var/list/carried = list()
	for(var/list/entry as anything in plan.groups)
		var/group = entry[1]
		if(!(group in kept))
			continue
		var/list/tail = list()
		for(var/datum/dirt_feature/member as anything in entry[2])
			if(member.from_level)
				tail += member
		if(!length(tail))
			continue
		var/alist/own = owned[group]
		var/alist/pixels = dirt_footprint(tail, surface, surface_rows)
		for(var/index in own)
			pixels -= index
		if(length(pixels) && !dirt_footprint_touches(pixels, taken, surface.width, surface.height, list(own)))
			carried += tail
			for(var/index in pixels)
				taken[index] = TRUE
	if(length(early) && surface.direction == plan.main && !dirt_level_shows(always, rest, kept, surface, surface_rows))
		var/alist/anchor = dirt_footprint(list(plan.anchor), surface, surface_rows)
		var/alist/pixels = dirt_footprint(early, surface, surface_rows)
		var/on_body = FALSE
		for(var/index in anchor)
			pixels -= index
		for(var/index in pixels)
			if(DIRT_PIXEL_ZONE(surface.flags_of[index]))
				on_body = TRUE
				break
		if(on_body && !dirt_footprint_touches(pixels, taken, surface.width, surface.height, list(anchor, owned[10])))
			carried += early
			kept += DIRT_RUN_GROUP_EARLY
	var/list/drawn = list()
	for(var/datum/dirt_feature/feature as anything in rest)
		if((isnull(feature.run_group) || (feature.run_group in kept)) && (!feature.from_level || (feature in carried)))
			drawn += feature
	return drawn

/**
 * Returns whether a level shows anything new on the body over level 1's shot: a pixel the kept runs and drops draw that
 * level 1's doesn't, beside either. A lone one would go.
 *
 * Arguments:
 * - always: Level 1's shot, and whatever else is always drawn but the covering, from dirt_runs_apart().
 * - features: The level's features but its plan.
 * - kept: The runs and drops kept.
 * - surface: The view's surface.
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/proc/dirt_level_shows(list/always, list/features, list/kept, datum/dirt_surface/surface, alist/surface_rows)
	var/list/shown_features = list()
	for(var/datum/dirt_feature/feature as anything in features)
		if(!isnull(feature.run_group) && (feature.run_group in kept) && !feature.from_level)
			shown_features += feature
	var/alist/base = dirt_footprint(always, surface, surface_rows)
	var/alist/shown = dirt_footprint(shown_features, surface, surface_rows)
	var/list/table = dirt_neighbour_table(surface.width, surface.height)
	var/list/flags_of = surface.flags_of
	for(var/index in shown)
		if(base[index] || !DIRT_PIXEL_ZONE(flags_of[index]))
			continue
		for(var/neighbour in table[index])
			if(shown[neighbour] || base[neighbour])
				return TRUE
	return FALSE

/**
 * Returns the pixels features draw on in one view before the raster's cleanups, as alist(index = TRUE): where any of
 * them lies thick enough for film. A feature hidden in profile is left out there.
 *
 * Arguments:
 * - features: The features, bound to the view.
 * - surface: The view's surface.
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/proc/dirt_footprint(list/features, datum/dirt_surface/surface, alist/surface_rows)
	RETURN_TYPE(/alist)
	var/alist/pixels = alist()
	var/in_profile = surface.direction == EAST || surface.direction == WEST
	for(var/datum/dirt_feature/feature as anything in features)
		if(in_profile && feature.profile_hidden)
			continue
		for(var/index, value in feature.pixels_on(surface, surface_rows))
			if(value >= DIRT_THRESHOLD_FILM)
				pixels[index] = TRUE
	return pixels

/**
 * Returns whether any of a footprint's pixels lies within DIRT_RUN_GAP px of another's, in both axes: no skin between.
 *
 * Arguments:
 * - pixels: The footprint, alist(index = TRUE).
 * - taken: The other, alist(index = TRUE).
 * - width, height: The canvas's size.
 * - excluded: Footprints whose pixels count as not taken, or null.
 */
/proc/dirt_footprint_touches(alist/pixels, alist/taken, width, height, list/excluded)
	for(var/index in pixels)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		for(var/near_row in max(0, row - DIRT_RUN_GAP) to min(height - 1, row + DIRT_RUN_GAP))
			for(var/near_column in max(0, column - DIRT_RUN_GAP) to min(width - 1, column + DIRT_RUN_GAP))
				var/near = near_row * width + near_column + 1
				if(!taken[near])
					continue
				var/counted = TRUE
				for(var/alist/footprint as anything in excluded)
					if(footprint?[near])
						counted = FALSE
						break
				if(counted)
					return TRUE
	return FALSE

/**
 * Returns one level of a deposit drawn on one direction of a body. The first feature, in list order, to lie thickest on
 * a pixel picks its role. Nothing goes on an eye, the pixels beside it or a human mouth, and an eye's diagonals take
 * film at most. Cloth draws its rim a role lighter, so a garment keeps its outline, though a contact point keeps its
 * tone. Then bare legs streak, lone pixels go, and on skin nothing smaller than 2 px stays.
 *
 * A covering feature, the top level's, thins to film on the outline: cut there, a coat read as a garment. In profile it
 * also breaks with noise on the outline and the pixels beside it, where whole it ran the torso's height as one band;
 * highlights stay whole.
 *
 * Arguments:
 * - features: The level's features, from a cause, bound to the view.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - surface: The direction's surface.
 * - surface_rows: The surface's pixels by limb and row, from dirt_surface_rows().
 */
/proc/dirt_rasterise_level(list/features, surface_kind, datum/dirt_surface/surface, alist/surface_rows)
	RETURN_TYPE(/datum/dirt_pixels)
	// each role's lighter one, indexed by its DIRT_ROLE_* define: highlights stay as they are
	var/static/list/lighter = list(null, DIRT_ROLE_HAZE, DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	var/pixel_count = surface.width * surface.height
	var/list/thickest = new /list(pixel_count)
	var/list/forced_roles = new /list(pixel_count)
	var/in_profile = surface.direction == EAST || surface.direction == WEST
	for(var/datum/dirt_feature/feature as anything in features)
		if(feature.covering)
			surface.outline()
			if(in_profile)
				surface.outline_band()
			break
	var/list/flags_of = surface.flags_of
	for(var/datum/dirt_feature/feature as anything in features)
		if(in_profile ? feature.profile_hidden : feature.profile_only)
			continue
		var/covering = feature.covering
		for(var/index, value in feature.pixels_on(surface, surface_rows))
			var/thickness = covering ? dirt_covering_thickness(feature, value, index, flags_of[index], in_profile, surface.width) : value
			if(thickness > (thickest[index] || 0))
				thickest[index] = thickness
				forced_roles[index] = feature.role
	var/on_skin = surface_kind == DIRT_SURFACE_SKIN
	var/on_cloth = surface_kind == DIRT_SURFACE_CLOTH
	var/datum/dirt_pixels/drawn = new(surface.width, surface.height)
	for(var/index in 1 to pixel_count)
		var/thickness = thickest[index]
		if(thickness < DIRT_THRESHOLD_FILM)
			continue
		var/flags = flags_of[index]
		var/limb = DIRT_PIXEL_LIMB(flags)
		if(limb == DIRT_LIMB_HEAD && surface.face_guard[index])
			continue
		var/role = forced_roles[index]
		if(!role)
			if(thickness == DIRT_HAZE_T)
				role = DIRT_ROLE_HAZE
			else if(thickness >= DIRT_THRESHOLD_CORE)
				role = DIRT_ROLE_CORE
			else if(thickness >= DIRT_THRESHOLD_BODY)
				role = DIRT_ROLE_BODY
			else
				role = DIRT_ROLE_FILM
		if(limb == DIRT_LIMB_HEAD && surface.eye_soft[index] && (role == DIRT_ROLE_BODY || role == DIRT_ROLE_CORE))
			role = DIRT_ROLE_FILM
		if(on_cloth && (flags & DIRT_PIXEL_RIM) && role != DIRT_ROLE_CORE)
			role = lighter[role]
		if(role)
			drawn.roles[index] = role
			drawn.thicknesses[index] = thickness
	if(on_skin)
		drawn = dirt_skin_streaks(drawn, surface)
	drawn = dirt_cleanup(drawn)
	if(on_skin)
		drawn = dirt_skin_rules(drawn)
	return drawn

/**
 * Returns how thick a covering feature lies on a pixel: film at most on the outline, and in profile broken by noise on
 * the outline and beside it, to nothing, haze or film. Highlights aren't broken.
 *
 * Arguments:
 * - feature: The covering feature.
 * - thickness: How thick it lies there.
 * - index: The pixel.
 * - flags: The pixel's flags, its outline marked (/datum/dirt_surface/proc/outline()), and in profile its band too
 *   (/datum/dirt_surface/proc/outline_band()).
 * - in_profile: Whether the view faces east or west, the only views the band breaks.
 * - width: The canvas's width.
 */
/proc/dirt_covering_thickness(datum/dirt_feature/feature, thickness, index, flags, in_profile, width)
	if(flags & DIRT_PIXEL_OUTLINE)
		thickness = min(thickness, DIRT_FILM_T)
	if(in_profile && (flags & DIRT_PIXEL_BAND) && thickness > 0 && feature.role != DIRT_ROLE_GLINT)
		var/row = floor((index - 1) / width)
		var/noise = dirt_spread_noise(index - 1 - row * width, row * 0.5, feature.break_seed, 1.6)
		if(noise < 0.38)
			return 0
		if(noise < 0.6 && thickness >= DIRT_HAZE_T)
			return DIRT_HAZE_T
		return min(thickness, DIRT_FILM_T)
	return thickness

/**
 * Streaks bare legs in a mask rather than coating them, and returns it: a solid coat up a bare shin reads as boots.
 * Body pixels more than 2.5 px up a leg mostly thin to film, in clumps about a limb wide. Each pixel is judged on its
 * own, so the mask is changed where it is.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_skin_streaks(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/list/right_metric = dirt_metric(DIRT_LIMB_R_LEG)
	var/list/left_metric = dirt_metric(DIRT_LIMB_L_LEG)
	for(var/index in 1 to length(roles))
		if(roles[index] != DIRT_ROLE_BODY)
			continue
		var/limb = DIRT_PIXEL_LIMB(flags_of[index])
		if(limb != DIRT_LIMB_R_LEG && limb != DIRT_LIMB_L_LEG)
			continue
		var/list/metric = limb == DIRT_LIMB_R_LEG ? right_metric : left_metric
		var/up = surface.height_of[index] / metric[2]
		if(up <= 2.5)
			continue
		if(dirt_spread_noise(surface.theta_of[index] / metric[1], up, 911, 2.4) < 0.62)
			roles[index] = DIRT_ROLE_FILM
	return drawn

/**
 * Returns a mask cleaned up: a lone film pixel goes, a lone core softens to body, and a pixel whose role none of its
 * neighbours share takes the role three of them share. Flecks stay.
 *
 * Arguments:
 * - drawn: The mask.
 */
/proc/dirt_cleanup(datum/dirt_pixels/drawn)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/cleaned = drawn.copy()
	var/list/roles = drawn.roles
	var/list/table = dirt_neighbour_table(drawn.width, drawn.height)
	for(var/index in 1 to length(roles))
		var/role = roles[index]
		if(!role)
			continue
		var/list/neighbours = table[index]
		var/neighbour_count = 0
		var/shared = FALSE
		for(var/neighbour in neighbours)
			var/neighbour_role = roles[neighbour]
			if(neighbour_role)
				neighbour_count++
				if(neighbour_role == role)
					shared = TRUE
		if(!neighbour_count)
			if(role == DIRT_ROLE_FILM)
				cleaned.roles[index] = null
				cleaned.thicknesses[index] = null
			else if(role == DIRT_ROLE_CORE)
				cleaned.roles[index] = DIRT_ROLE_BODY
			continue
		if(role == DIRT_ROLE_FLECK || shared)
			continue
		var/list/around = list()
		for(var/neighbour in neighbours)
			if(roles[neighbour])
				around += roles[neighbour]
		// of four neighbours, only one role can hold three
		for(var/candidate in around)
			var/matches = 0
			for(var/other in around)
				if(other == candidate)
					matches++
			if(matches >= 3)
				cleaned.roles[index] = candidate
				break
	return cleaned

/**
 * Makes a mask as skin takes goo, and returns it: no pixel without a neighbour, since a lone body dot reads as a mole
 * and nothing smaller than 2 px stays. Goo keeps its core: flattened, it read as body paint.
 *
 * The reference drops lone body pixels, then every group of pixels smaller than two. Neither step leaves a new lone
 * pixel, so together they drop exactly the pixels with no neighbour. A pixel dropped had none, so dropping it where it
 * is leaves every other pixel's neighbours as they were.
 *
 * Arguments:
 * - drawn: The mask, changed.
 */
/proc/dirt_skin_rules(datum/dirt_pixels/drawn)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/table = dirt_neighbour_table(drawn.width, drawn.height)
	for(var/index in 1 to length(roles))
		if(!roles[index])
			continue
		var/alone = TRUE
		for(var/neighbour in table[index])
			if(roles[neighbour])
				alone = FALSE
				break
		if(alone)
			roles[index] = null
			drawn.thicknesses[index] = null
	return drawn

/**
 * Returns a mask without lone pixels, which read harshly: a lone film or haze pixel goes, and a lone body or core pixel
 * becomes film with a haze ring where the surface reaches. A film or haze hole with three dark neighbours fills with
 * body: it read as a chip or a scar. Glints and flecks are highlights and stay.
 *
 * Arguments:
 * - drawn: The mask.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_despeckle(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/softened = drawn.copy()
	var/list/roles = drawn.roles
	var/list/softened_roles = softened.roles
	var/list/table = dirt_neighbour_table(drawn.width, drawn.height)
	for(var/index in 1 to length(roles))
		var/role = roles[index]
		if(!role)
			continue
		var/list/neighbours = table[index]
		if(role == DIRT_ROLE_FILM || role == DIRT_ROLE_HAZE)
			var/dark_count = 0
			var/first_dark
			for(var/neighbour in neighbours)
				if(roles[neighbour] == DIRT_ROLE_BODY || roles[neighbour] == DIRT_ROLE_CORE)
					dark_count++
					first_dark ||= neighbour
			if(dark_count >= 3)
				softened_roles[index] = DIRT_ROLE_BODY
				softened.thicknesses[index] = drawn.thicknesses[first_dark]
				continue
		if(role == DIRT_ROLE_GLINT || role == DIRT_ROLE_FLECK)
			continue
		var/alone = TRUE
		for(var/neighbour in neighbours)
			if(roles[neighbour])
				alone = FALSE
				break
		if(!alone)
			continue
		if(role == DIRT_ROLE_FILM || role == DIRT_ROLE_HAZE)
			softened_roles[index] = null
			softened.thicknesses[index] = null
			continue
		softened_roles[index] = DIRT_ROLE_FILM
		for(var/neighbour in neighbours)
			if(!softened_roles[neighbour] && DIRT_PIXEL_LIMB(surface.flags_of[neighbour]))
				softened_roles[neighbour] = DIRT_ROLE_HAZE
				softened.thicknesses[neighbour] = DIRT_HAZE_T
	return softened

/**
 * Breaks a covering mask's flat edges, and returns it: no top or bottom edge runs flat along one row for more than 2
 * px. Cut level, a sheet read as clipped at a region, an apron, a back patch, a bib. At irregular spots along a flat
 * stretch, film runs on 1 to 3 px below a bottom edge, or rises 1 px over a top edge. It only adds film, on bare skin
 * or haze of the chest and the legs, so what's under it and the highlights stay. What's solid is read before anything
 * is added, so the mask is changed where it is.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 * - seed: The noise's seed, a whole number.
 */
/proc/dirt_ragged_edges(datum/dirt_pixels/drawn, datum/dirt_surface/surface, seed)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/width = drawn.width
	var/height = drawn.height
	// what's solid is read from the mask as it came, before anything is added, the rows holding any of it marked
	var/list/solid = new /list(width * height)
	var/list/solid_rows = new /list(height)
	for(var/index in 1 to length(roles))
		var/role = roles[index]
		if(role && role != DIRT_ROLE_HAZE)
			solid[index] = TRUE
			solid_rows[floor((index - 1) / width) + 1] = TRUE
	for(var/step_down in list(1, -1)) // bottom edges, then top edges
		for(var/row in 0 to height - 1)
			if(!solid_rows[row + 1])
				continue
			var/next_row = row + step_down
			var/off_canvas = next_row < 0 || next_row >= height
			var/run_start
			for(var/column in 0 to width) // a column past the last closes the row's last run
				// a solid pixel with no solid one past it is on the edge
				if(column < width && solid[row * width + column + 1] && (off_canvas || !solid[next_row * width + column + 1]))
					if(isnull(run_start))
						run_start = column
					continue
				if(isnull(run_start))
					continue
				if(column - run_start > 2)
					var/flat = 0
					for(var/run_column in run_start to column - 1)
						flat++
						if(flat <= 2 && (flat == 1 || dirt_noise_hash(run_column, row, seed) < 0.65))
							continue
						if(!dirt_ragged_free(surface, roles, run_column, next_row))
							continue
						var/spill_length = step_down < 0 ? 1 : 1 + floor(dirt_noise_hash(run_column, row, seed + 1) * 2.99)
						for(var/spot in 1 to spill_length)
							var/spot_row = row + step_down * spot
							if(!dirt_ragged_free(surface, roles, run_column, spot_row))
								break
							drawn.put_index(spot_row * width + run_column + 1, DIRT_ROLE_FILM, DIRT_FILM_T)
						flat = 0
				run_start = null
	return drawn

/**
 * Returns whether a covering mask's flat edge may run on over a pixel: bare skin or haze on the surface, where the
 * chest or a leg shows.
 *
 * Arguments:
 * - surface: The surface.
 * - roles: The mask's roles so far.
 * - column, row: The pixel.
 */
/proc/dirt_ragged_free(datum/dirt_surface/surface, list/roles, column, row)
	var/static/list/edge_zones = list(BODY_ZONE_CHEST, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
	var/index = surface.pixel_index(column, row)
	var/flags = index && surface.flags_of[index]
	if(!DIRT_PIXEL_LIMB(flags))
		return FALSE
	var/role = roles[index]
	var/zone = DIRT_PIXEL_ZONE(flags)
	return (!role || role == DIRT_ROLE_HAZE) && zone && (dirt_pixel_zones()[zone] in edge_zones)

/**
 * Returns masks merged into one: on each pixel the thickest wins, by role rank and then thickness, and the first mask
 * keeps a full tie. All the splats on one surface make one mask this way, oldest first. A splat below the top level
 * leaves out each of its pieces that comes within DIRT_RUN_GAP px of an earlier splat's: piled on, splats filled into
 * one sheet. A top-level splat keeps everything: it covers.
 *
 * Arguments:
 * - pixel_maps: The masks, all one size, at least one.
 */
/proc/dirt_merge(list/pixel_maps)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/ranks = dirt_role_ranks()
	var/datum/dirt_pixels/first = pixel_maps[1]
	var/datum/dirt_pixels/merged = new(first.width, first.height)
	var/list/merged_roles = merged.roles
	var/list/merged_thicknesses = merged.thicknesses
	var/alist/taken = alist()
	for(var/datum/dirt_pixels/pixel_map as anything in pixel_maps)
		var/list/roles = pixel_map.roles
		var/list/thicknesses = pixel_map.thicknesses
		var/list/left_out = (pixel_map.covers || !length(taken)) ? null : dirt_pieces_near(pixel_map, taken)
		for(var/index in pixel_map.drawn_indexes || dirt_index_range(length(roles)))
			var/role = roles[index]
			if(!role || left_out?[index])
				continue
			taken[index] = TRUE
			var/held = merged_roles[index]
			if(!held || ranks[role] > ranks[held] || (ranks[role] == ranks[held] && thicknesses[index] > merged_thicknesses[index]))
				merged_roles[index] = role
				merged_thicknesses[index] = thicknesses[index]
	return merged

/**
 * Returns a surface's splats in one direction merged with the parts drawn under and over it. Each splat leaves out the
 * pixels of the rounded parts on its zone (dirt_part_rounded()): straight streaks carried onto a breast read as blocks.
 * Then each part drawn under the surface takes each splat on its zone in its own pixels (dirt_part_field()), merged in
 * after the splats and keeping every piece, as a top-level splat does. A part drawn over the surface takes its share on
 * itself, so its field isn't drawn here.
 *
 * Arguments:
 * - pixel_maps: Each splat's raster in this direction, at its level here (dirt_part_body_level()), each its own copy:
 *   the rounded parts' pixels are taken out of it.
 * - splats: The splats, in the same order.
 * - under_parts: The parts drawn under the surface in this direction, each a /datum/dirt_part_source, lowest first.
 * - over_parts: The parts drawn over it in this direction (dirt_split_parts()).
 * - owns: alist(source = its pixels in this direction, from dirt_part_own()).
 * - direction: The direction.
 */
/proc/dirt_merge_with_parts(list/pixel_maps, list/splats, list/under_parts, list/over_parts, alist/owns, direction)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/sources = under_parts + over_parts
	var/list/maps = pixel_maps.Copy()
	for(var/position in 1 to length(splats))
		var/datum/dirt_splat/splat = splats[position]
		var/datum/dirt_pixels/pixel_map = pixel_maps[position]
		for(var/datum/dirt_part_source/source as anything in sources)
			if(!dirt_part_rounded(source.kind) || dirt_part_zone(source.kind) != splat.zone)
				continue
			for(var/index in owns[source])
				pixel_map.roles[index] = null
				pixel_map.thicknesses[index] = null
	for(var/datum/dirt_splat/splat as anything in splats)
		for(var/datum/dirt_part_source/source as anything in under_parts)
			var/list/own = owns[source]
			if(length(own) && dirt_part_zone(source.kind) == splat.zone)
				maps += dirt_part_field(source.kind, own, splat.zone, splat.level, splat.variant, direction)
	return dirt_merge(maps)

/**
 * Returns TRUE on each pixel of a mask's pieces, 8-connected, that come within DIRT_RUN_GAP px of a taken pixel.
 *
 * Arguments:
 * - pixel_map: The mask.
 * - taken: alist(index = TRUE), the pixels taken.
 */
/proc/dirt_pieces_near(datum/dirt_pixels/pixel_map, alist/taken)
	RETURN_TYPE(/list)
	var/list/roles = pixel_map.roles
	var/width = pixel_map.width
	var/height = pixel_map.height
	var/list/left_out = new /list(length(roles))
	var/list/stack = list()
	for(var/index in pixel_map.drawn_indexes || dirt_index_range(length(roles)))
		if(!roles[index] || left_out[index])
			continue
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		var/near = FALSE
		for(var/near_row in max(0, row - DIRT_RUN_GAP) to min(height - 1, row + DIRT_RUN_GAP))
			for(var/near_column in max(0, column - DIRT_RUN_GAP) to min(width - 1, column + DIRT_RUN_GAP))
				if(taken[near_row * width + near_column + 1])
					near = TRUE
		if(!near)
			continue
		// the whole piece goes; each pixel goes on the stack once at most
		left_out[index] = TRUE
		stack += index
		for(var/visit in 1 to length(roles))
			if(!length(stack))
				break
			var/piece_index = stack[length(stack)]
			stack.len--
			var/piece_row = floor((piece_index - 1) / width)
			var/piece_column = piece_index - 1 - piece_row * width
			for(var/next_row in max(0, piece_row - 1) to min(height - 1, piece_row + 1))
				for(var/next_column in max(0, piece_column - 1) to min(width - 1, piece_column + 1))
					var/next_index = next_row * width + next_column + 1
					if(roles[next_index] && !left_out[next_index])
						left_out[next_index] = TRUE
						stack += next_index
	return left_out
