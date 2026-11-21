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
	/// Whether it covers, so that where splats merge it keeps every piece (dirt_merge()). Mess at the top level covers,
	/// and so does every part's field (dirt_part_field()).
	var/covers = FALSE
	/// Every pixel drawn, where it's kept, so a walk that doesn't depend on order visits those pixels alone. They're
	/// in the order drawn. A pixel cleared since is still listed, and one drawn again after a clear is listed twice.
	/// Null where it isn't kept, and then the walk takes the whole canvas. A merge, a deposit's levels and their stack
	/// keep it, and a copy keeps its original's. A decoded raster lists its pixels in row-major order
	/// (dirt_pixels_from_drawn()), on a deposit's limbs alone where it's decoded to them. Every writer lists a blank
	/// pixel it draws. A walk in row-major order goes from the lowest index to the highest (drawn_span()).
	var/list/drawn_indexes
	/// Each drawn pixel's material, as a splat stores it (/datum/dirt_splat/var/material), where dirt_merge() was given
	/// materials. Null where the mask is one material. A raster's material is its deposit's own. A merge's null means
	/// the surface's only material is mess (dirt_splat_materials() gives null for mess alone), and runs and the bake
	/// read it that way.
	var/list/materials

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
	copied.materials = materials?.Copy()
	copied.drawn_indexes = drawn_indexes?.Copy()
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
 * Returns each role a step darker, indexed by its DIRT_ROLE_* define: haze to film and film to body, the rest as they
 * are. A material that its cause draws darker takes it, and so does a painted design at level 4. You should NEVER
 * modify it.
 */
/proc/dirt_stepped_up_roles()
	RETURN_TYPE(/list)
	var/static/list/stepped = list(DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_BODY, DIRT_ROLE_CORE, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	return stepped

/**
 * Returns each role a step lighter, indexed by its DIRT_ROLE_* define: haze to nothing, film to haze, body to film and
 * core to body. Highlights stay as they are. Cloth's rim takes it, for every role of a coat but its core, and for a
 * speck. You should NEVER modify it.
 */
/proc/dirt_lighter_roles()
	RETURN_TYPE(/list)
	var/static/list/lighter = list(null, DIRT_ROLE_HAZE, DIRT_ROLE_FILM, DIRT_ROLE_BODY, DIRT_ROLE_FLECK, DIRT_ROLE_GLINT)
	return lighter

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
 * Returns mess aimed at a zone, drawn on one direction of a body. It holds levels 1 to `level`, each from the deposit's
 * same draws. They're merged by role rank, the later level winning a tie, and the result is despeckled. Only a glint,
 * once drawn, stays, because a later run beside it folded it in. A fleck is taken like any other role. The top level
 * then breaks its flat edges, and keeps every pixel of level 3 as it was drawn, at its role or a darker one.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define, not DIRT_ZONE_COCK.
 * - level: 1 to DIRT_MESS_MAX_LEVEL.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - surface: The direction's surface.
 */
/proc/dirt_rasterise_aimed(zone, level, variant, surface_kind, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/alist/surface_rows = dirt_surface_rows(surface)
	var/list/ranks = dirt_role_ranks()
	var/datum/dirt_pixels/merged = new(surface.width, surface.height)
	merged.drawn_indexes = list()
	var/datum/dirt_aim/aim = new(zone, variant)
	var/datum/dirt_pixels/below
	for(var/each_level in 1 to level)
		var/list/features = dirt_runs_apart(aim.features(each_level), surface, surface_rows)
		dirt_stack_level(merged, dirt_rasterise_level(features, surface_kind, surface, surface_rows))
		if(level == DIRT_MESS_MAX_LEVEL && each_level == DIRT_MESS_MAX_LEVEL - 1)
			below = dirt_despeckle(merged, surface)
	merged = dirt_despeckle(merged, surface)
	if(level != DIRT_MESS_MAX_LEVEL)
		return merged
	// after the despeckle, so what it breaks stays broken; three times, as a rise can meet another edge
	for(var/pass in 1 to 3)
		merged = dirt_ragged_edges(merged, surface, 4000 + variant)
	var/list/merged_roles = merged.roles
	var/list/merged_thicknesses = merged.thicknesses
	var/list/below_roles = below.roles
	for(var/index in 1 to length(below_roles))
		var/role = below_roles[index]
		var/held = merged_roles[index]
		if(role && (!held || ranks[held] < ranks[role]))
			if(!held)
				merged.drawn_indexes += index
			merged_roles[index] = role
			merged_thicknesses[index] = below.thicknesses[index]
	merged.covers = TRUE
	return merged

/**
 * Returns a deposit drawn on one direction of a body. It's the one entry point for every cause. Mess aimed at a zone
 * ("aimed_<zone>") goes to dirt_rasterise_aimed(). Any other cause draws levels 1 to `level`, each from the deposit's
 * same random draws (dirt_cause_features()), merged by role rank with the later level winning a tie. If its cause
 * draws the material darker (/datum/dirt_material/var/darker_causes), it then goes a step darker, haze to film and
 * film to body. On a bare body's skin, a deposit with a hand-painted design (dirt_painted_rasterise()) wears it below
 * the head in place of its own marks, which the head keeps. Then the whole is despeckled (dirt_rasterise_deposit()). A
 * plunge, a blast or a douse is drawn by its body field (/datum/dirt_canvas_field/body), its bands back to back. Under
 * DIRT_DRAFT_EXACT a general deposit is drawn drafting (dirt_drafted()), so its noise samples the draft's hash. The
 * lattice it samples is emptied as it begins and as it ends, whether it ends well or in a runtime. The exception is a
 * mask job drawing it, which keeps the lattice between the deposit's directions. Either way, mess drawn after it never
 * samples that lattice.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define, or "aimed_<zone>".
 * - material: The /datum/dirt_material it's made of (dirt_material()). Unread for mess.
 * - level: 1 to the cause's top level (dirt_cause_max_level()). A level past it is taken as the top level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - side: The mob's dirtier side, 1 or -1.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - surface: The direction's surface.
 * - painted: Whether the body is bare, so bare skin takes the cause's painted design where it has one.
 * - level_features: A mask job's features of the deposit by level (/datum/dirt_mask_job/var/deposit_features), which
 *   its directions share (dirt_level_features()), or null to make them for this direction alone. Unread for mess.
 * - deposit_samples: The mask job's table of the noise those features sample
 *   (/datum/dirt_mask_job/var/deposit_samples), or null. Unread for mess.
 */
/proc/dirt_rasterise(cause, datum/dirt_material/material, level, variant, side, surface_kind, datum/dirt_surface/surface, painted = FALSE, alist/level_features = null, alist/deposit_samples = null)
	RETURN_TYPE(/datum/dirt_pixels)
	if(copytext(cause, 1, length(DIRT_CAUSE_AIMED_PREFIX) + 1) == DIRT_CAUSE_AIMED_PREFIX)
		return dirt_rasterise_aimed(copytext(cause, length(DIRT_CAUSE_AIMED_PREFIX) + 1), level, variant, surface_kind, surface)
	level = min(level, dirt_cause_max_level(cause))
#ifdef DIRT_DRAFT_EXACT
	return dirt_drafted(GLOBAL_PROC_REF(dirt_rasterise_deposit), list(cause, material, level, variant, side, surface_kind, surface, painted, level_features, deposit_samples))
#else
	return dirt_rasterise_deposit(cause, material, level, variant, side, surface_kind, surface, painted, level_features, deposit_samples)
#endif

/**
 * Returns a general deposit drawn on one direction of a body, for dirt_rasterise(): levels 1 to `level`, then its
 * finish (dirt_finish_deposit()). A plunge, a blast or a douse is its body field's bands drawn back to back
 * (/datum/dirt_canvas_field/body), as a mask job draws them a piece each.
 *
 * Walking or kneeling on a bare body's skin is its design alone, despeckled, as its finish would leave it. That's
 * because a design keeps only the head of the deposit under it, and their marks never reach the head on any template.
 * Each feature they make lies on a leg: walking's coats and kicked-up specks, and kneeling's knee blobs, contacts,
 * strokes, patches and toe cap. Each is drawn on that leg's pixels alone (/datum/dirt_feature/proc/bind()), and
 * kneeling's stamps on the hands' pixels alone, with no face level. A level's later steps change only pixels already
 * drawn, put a speck on its own limb, or put a ring's or a halo's film beside a pixel the features drew. The stamps
 * come after the ring and the halo. No template puts a leg's pixel beside the head's, because the torso lies between
 * them, whatever the legs (digitigrade, a Muscular body's, a taur's rider's legless template). Every other cause with
 * a design draws on the head: machine work and smoke stamp the face, and a blast and a plunge coat the whole body.
 *
 * Arguments:
 * - cause: A general DIRT_CAUSE_* define.
 * - material, variant, side, surface_kind, surface, painted, level_features, deposit_samples: As dirt_rasterise()'s.
 * - level: 1 to the cause's top level.
 */
/proc/dirt_rasterise_deposit(cause, datum/dirt_material/material, level, variant, side, surface_kind, datum/dirt_surface/surface, painted, alist/level_features = null, alist/deposit_samples = null)
	RETURN_TYPE(/datum/dirt_pixels)
	if(dirt_coverage_cause(cause))
		var/datum/dirt_canvas_field/body/field = new(cause, material, level, variant, side, surface_kind, surface, painted, level_features)
		for(var/band in 1 to field.level * ceil(surface.height / field.band_rows))
			if(field.draw_rows(field.band_rows))
				break
		return field.merged
	if(painted && surface_kind == DIRT_SURFACE_SKIN && (cause == DIRT_CAUSE_WALK || cause == DIRT_CAUSE_KNEEL) && dirt_painted_design(cause, material))
		return dirt_despeckle(dirt_painted_rasterise(cause, material, level, variant, side, surface), surface)
	var/alist/surface_rows = dirt_surface_rows(surface)
	var/datum/dirt_pixels/merged = new(surface.width, surface.height)
	merged.drawn_indexes = list()
	for(var/each_level in 1 to level)
		var/list/features = dirt_runs_apart(dirt_level_features(level_features, cause, each_level, variant, side, deposit_samples), surface, surface_rows)
		dirt_stack_level(merged, dirt_rasterise_level(features, surface_kind, surface, surface_rows, material))
	return dirt_finish_deposit(merged, cause, material, level, variant, side, surface_kind, surface, painted)

/**
 * Returns a general deposit on a body finished, from its levels stacked (dirt_stack_level()). It's made darker if its
 * cause draws its material darker. It wears its painted design on a bare body's skin, and then it's despeckled.
 *
 * Arguments:
 * - merged: Its stacked levels, changed.
 * - cause, material, level, variant, side, surface_kind, surface, painted: As dirt_rasterise_deposit()'s.
 */
/proc/dirt_finish_deposit(datum/dirt_pixels/merged, cause, datum/dirt_material/material, level, variant, side, surface_kind, datum/dirt_surface/surface, painted)
	RETURN_TYPE(/datum/dirt_pixels)
	if(length(material.darker_causes) && (cause in material.darker_causes))
		var/list/stepped = dirt_stepped_up_roles()
		var/list/roles = merged.roles
		// the stack lists a pixel once, as it's first drawn, and clears none, so each steps once
		for(var/index in merged.drawn_indexes || dirt_index_range(length(roles)))
			if(roles[index])
				roles[index] = stepped[roles[index]]
	if(painted && surface_kind == DIRT_SURFACE_SKIN)
		var/datum/dirt_pixels/design = dirt_painted_rasterise(cause, material, level, variant, side, surface)
		if(design)
			var/list/flags_of = surface.flags_of
			var/list/merged_roles = merged.roles
			for(var/index in merged.drawn_indexes || dirt_index_range(length(merged_roles)))
				if(merged_roles[index] && DIRT_PIXEL_LIMB(flags_of[index]) == DIRT_LIMB_HEAD)
					design.roles[index] = merged_roles[index]
					design.thicknesses[index] = merged.thicknesses[index]
			merged = design
	return dirt_despeckle(merged, surface)

/**
 * A plunge, a blast or a douse on one direction of a body, as dirt_rasterise_deposit() draws it, drawn some rows at a
 * time (draw_rows()). A mask job draws it a band a piece (dirt_canvas_field_band()) and keeps it among its fields
 * (/datum/dirt_mask_job/proc/field_for()). Each level's whole-body coat is bound a band of rows at a time
 * (/datum/dirt_feature/coverage/proc/bind_rows()). Once its last row is bound, the level is finished as any level is
 * (dirt_rasterise_level(), which finds the coat bound) and stacked. Once the last level is stacked, the deposit is
 * finished (dirt_finish_deposit()).
 *
 * It draws the same pixels however it's banded. dirt_rasterise_deposit() draws a whole deposit through it too, its
 * bands back to back, so the job's draw and the whole one are one code path. Each coat pixel is worked out from that
 * pixel alone. A douse's tops are read from the whole surface on its first band. The level's features are made as its
 * first band begins, or taken unbound from its job's earlier direction (dirt_level_features()). Each finish runs once,
 * on the whole level and the whole deposit. The noise its levels' coats share is sampled once (samples).
 */
/datum/dirt_canvas_field/body
	/// The body's surface in the direction.
	var/datum/dirt_surface/surface
	/// Its pixels by limb and row (dirt_surface_rows()), until it's done.
	var/alist/surface_rows
	/// The variant, which picks its features' stream.
	var/variant
	/// Whether the body is bare, so bare skin takes the cause's painted design.
	var/painted = FALSE
	/// The whole-body coat of the level being drawn, bound a band at a time, or null between levels.
	var/datum/dirt_feature/coverage/cover
	/// Its mask job's features of the deposit by level, which the job's fields share (dirt_level_features()), or null.
	var/alist/level_features

/**
 * Arguments:
 * - cause: DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST or DIRT_CAUSE_DOUSE.
 * - material, level, variant, side, surface_kind, surface, painted, level_features: As dirt_rasterise()'s.
 */
/datum/dirt_canvas_field/body/New(cause, datum/dirt_material/material, level, variant, side, surface_kind, datum/dirt_surface/surface, painted, alist/level_features = null)
	// not a canvas's, so the canvas field's New() isn't run
	src.cause = cause
	src.material = material
	src.level = min(level, dirt_cause_max_level(cause))
	src.variant = variant
	src.side = side
	src.surface_kind = surface_kind
	src.surface = surface
	src.painted = painted
	src.level_features = level_features
	surface_rows = dirt_surface_rows(surface)
	merged = new(surface.width, surface.height)
	merged.drawn_indexes = list()
	band_rows = dirt_field_band_rows(surface.width)
	samples = alist()

/**
 * Binds the level's coat on its next rows. As a level begins, it makes the level's features (dirt_level_features()).
 * Once the level's last row is bound, it runs the level's finish (dirt_rasterise_level()) and stacks it on the levels
 * before. Once the last level is stacked, it runs the deposit's finish (dirt_finish_deposit()), and the surface rows
 * and samples go. Call it while drafting (dirt_drafted()).
 *
 * Arguments:
 * - rows: The most rows to bind.
 *
 * Returns whether every level is drawn.
 */
/datum/dirt_canvas_field/body/draw_rows(rows)
	if(done)
		return TRUE
	if(!features)
		drawing_level++
		features = dirt_runs_apart(dirt_level_features(level_features, cause, drawing_level, variant, side), surface, surface_rows)
		cover = locate(/datum/dirt_feature/coverage) in features
		cover.set_material(material, surface_kind == DIRT_SURFACE_SKIN)
		next_row = 0
	var/last_row = min(next_row + rows, surface.height) - 1
	cover.bind_rows(surface, next_row, last_row, samples)
	next_row = last_row + 1
	if(next_row < surface.height)
		return FALSE
	dirt_stack_level(merged, dirt_rasterise_level(features, surface_kind, surface, surface_rows, material))
	features = null
	cover = null
	if(drawing_level < level)
		return FALSE
	merged = dirt_finish_deposit(merged, cause, material, level, variant, side, surface_kind, surface, painted)
	done = TRUE
	surface_rows = null
	samples = null
	return TRUE

/**
 * Lays one level of a deposit over the levels under it, and changes them. Each pixel takes the level's role where that
 * role ranks as high or higher. Only a glint, once drawn, stays, because a later run beside it folded it in. A fleck is
 * taken like any other role.
 *
 * Arguments:
 * - merged: The levels under it, changed.
 * - drawn: The level.
 */
/proc/dirt_stack_level(datum/dirt_pixels/merged, datum/dirt_pixels/drawn)
	var/list/ranks = dirt_role_ranks()
	var/list/merged_roles = merged.roles
	var/list/merged_thicknesses = merged.thicknesses
	var/list/merged_indexes = merged.drawn_indexes
	var/list/roles = drawn.roles
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		var/role = roles[index]
		if(!role)
			continue
		var/held = merged_roles[index]
		if(held == DIRT_ROLE_GLINT)
			continue
		if(!held)
			merged_indexes?.Add(index)
		else if(ranks[role] < ranks[held])
			continue
		merged_roles[index] = role
		merged_thicknesses[index] = drawn.thicknesses[index]

/**
 * Returns a general deposit's features at one level, from its "<cause>:<variant>" stream (dirt_general_stream()),
 * drawn by its cause's proc (dirt_cause_procs()). A cause without a proc gets none.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - level: The level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_features(cause, level, variant, side)
	RETURN_TYPE(/list)
	var/entry = dirt_cause_procs()[cause]
	if(!entry)
		return list()
	var/datum/dirt_random/rng = dirt_general_stream("[cause]:[num2text(variant, 12)]")
	if(islist(entry))
		return call(entry[1])(level, rng, side, entry[2])
	return call(entry)(level, rng, side)

/**
 * Returns a general deposit's features at one level for one direction. They're made afresh (dirt_cause_features()),
 * or they're a mask job's, kept by level across the deposit's directions. They depend on the cause, level, variant and
 * side alone. Their stream starts at its seed text on every call, and none of them reads it once made. So the first
 * direction to ask makes them, and each later one takes them unbound (/datum/dirt_feature/proc/unbind()) to bind on
 * its own view. A job draws one deposit's directions back to back, so the level keys them. The job's
 * /datum/dirt_mask_job/proc/rasterise_next() stays on the same splat until it's made in every direction, then drops
 * the features. Each of a job's features samples its noise through the job's table (/datum/dirt_feature/proc/noise()).
 * This proc hands that table to the features, when a caller passes one. A body field passes none, so noise() samples
 * afresh for its features. You should NEVER modify them.
 *
 * Arguments:
 * - kept: The job's /datum/dirt_mask_job/var/deposit_features, filled here, or null.
 * - cause, level, variant, side: As dirt_cause_features()'s.
 * - deposit_samples: The job's /datum/dirt_mask_job/var/deposit_samples, or null.
 */
/proc/dirt_level_features(alist/kept, cause, level, variant, side, alist/deposit_samples = null)
	RETURN_TYPE(/list)
	if(isnull(kept))
		return dirt_cause_features(cause, level, variant, side)
	var/list/features = kept[level]
	if(!features)
		features = dirt_cause_features(cause, level, variant, side)
		kept[level] = features
		for(var/datum/dirt_feature/feature as anything in features)
			feature.deposit_samples = deposit_samples
		return features
	for(var/datum/dirt_feature/feature as anything in features)
		feature.unbind()
		feature.deposit_samples = deposit_samples
	return features

/**
 * Returns each general cause's proc: alist(DIRT_CAUSE_* define = proc path). Each proc takes (level,
 * /datum/dirt_random, side) and returns the cause's features at that level. For slime where it touched, the entry is
 * list(proc path, the zone it touched), and the zone is passed after the side. You should NEVER modify it.
 */
/proc/dirt_cause_procs()
	RETURN_TYPE(/alist)
	var/static/alist/cause_procs = alist(
		DIRT_CAUSE_WALK = GLOBAL_PROC_REF(dirt_cause_walk),
		DIRT_CAUSE_KNEEL = GLOBAL_PROC_REF(dirt_cause_kneel),
		DIRT_CAUSE_CRAWL = GLOBAL_PROC_REF(dirt_cause_crawl),
		DIRT_CAUSE_DUST = GLOBAL_PROC_REF(dirt_cause_dust),
		DIRT_CAUSE_WEAR = GLOBAL_PROC_REF(dirt_cause_wear),
		DIRT_CAUSE_FALL = GLOBAL_PROC_REF(dirt_cause_fall),
		DIRT_CAUSE_SPLASH = GLOBAL_PROC_REF(dirt_cause_splash),
		DIRT_CAUSE_MACHINE = GLOBAL_PROC_REF(dirt_cause_machine),
		DIRT_CAUSE_SMOKE = GLOBAL_PROC_REF(dirt_cause_smoke),
		DIRT_CAUSE_SWEAT = GLOBAL_PROC_REF(dirt_cause_sweat),
		DIRT_CAUSE_SLIMED = GLOBAL_PROC_REF(dirt_cause_slimed),
		DIRT_CAUSE_PLUNGE = GLOBAL_PROC_REF(dirt_cause_plunge),
		DIRT_CAUSE_BLAST = GLOBAL_PROC_REF(dirt_cause_blast),
		DIRT_CAUSE_DOUSE = GLOBAL_PROC_REF(dirt_cause_douse),
		DIRT_CAUSE_SLIMED_HEAD = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_HEAD),
		DIRT_CAUSE_SLIMED_CHEST = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_CHEST),
		DIRT_CAUSE_SLIMED_BACK = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), DIRT_ZONE_BACK),
		DIRT_CAUSE_SLIMED_R_ARM = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_R_ARM),
		DIRT_CAUSE_SLIMED_L_ARM = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_L_ARM),
		DIRT_CAUSE_SLIMED_R_LEG = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_R_LEG),
		DIRT_CAUSE_SLIMED_L_LEG = list(GLOBAL_PROC_REF(dirt_cause_slime_contact), BODY_ZONE_L_LEG),
	)
	return cause_procs

/**
 * Returns the top level a cause reaches. Machine work and smoke have a harder fourth, as mess has its covering one.
 * Every other cause stops at DIRT_DEPOSIT_MAX_LEVEL.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define, or "aimed_<zone>".
 */
/proc/dirt_cause_max_level(cause)
	var/static/alist/top_levels = alist(
		DIRT_CAUSE_MACHINE = 4,
		DIRT_CAUSE_SMOKE = 4,
	)
	if(copytext(cause, 1, length(DIRT_CAUSE_AIMED_PREFIX) + 1) == DIRT_CAUSE_AIMED_PREFIX)
		return DIRT_MESS_MAX_LEVEL
	return top_levels[cause] || DIRT_DEPOSIT_MAX_LEVEL

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
 * a pixel picks its role. A feature for cloth only or for skin only is left out of the other. A feature for profile
 * only is left out facing south and north, and one hidden in profile is left out facing east and west. Nothing goes
 * on an eye, the pixels beside it or a human mouth, but a veil keeps only to dirt_face_zone()'s limits, and an eye's
 * diagonals take film at most. On skin, a feature with a skin role draws in it. Cloth draws its rim a role lighter,
 * so a garment keeps its outline, though a contact point keeps its tone.
 *
 * A whole-body coat (/datum/dirt_feature/coverage) comes bound. The body field that bound it
 * (/datum/dirt_canvas_field/body) already told it its material and surface.
 *
 * Then the steps run in the reference generator's order. Bare legs streak, unless a whole-body coat covers them (a
 * plunge below level 3 still streaks). A light material thins up the legs, unless a whole-body coat clumps it. Lone
 * pixels go. A ringed feature's pixels take a broken film ring. Then come the material's edge (halo or tide), its
 * sheen, and on cloth a whole-body coat's glints (dirt_cover_sheen()). Then come the material's specks, the speck
 * features (dirt_scatter()) and the stamps (dirt_overlay_stamps()). Last, on skin, nothing smaller than 2 px stays,
 * nor any core but goo's. The material is read only for what its shape class names
 * (/datum/dirt_material/proc/shape_class()).
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
 * - material: The /datum/dirt_material it's made of, or null for mess.
 */
/proc/dirt_rasterise_level(list/features, surface_kind, datum/dirt_surface/surface, alist/surface_rows, datum/dirt_material/material = null)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/lighter = dirt_lighter_roles()
	var/pixel_count = surface.width * surface.height
	var/on_skin = surface_kind == DIRT_SURFACE_SKIN
	var/on_cloth = surface_kind == DIRT_SURFACE_CLOTH
	var/in_profile = surface.direction == EAST || surface.direction == WEST
	var/list/coats = list()
	var/list/specks = list()
	var/list/stamps = list()
	for(var/datum/dirt_feature/feature as anything in features)
		if(istype(feature, /datum/dirt_feature/stamps))
			stamps += feature
		else if((on_cloth ? feature.skin_only : feature.cloth_only) || (in_profile ? feature.profile_hidden : feature.profile_only))
			continue
		else if(feature.scatter)
			specks += feature
		else
			coats += feature
	var/material_flags = material?.flags
	var/datum/dirt_feature/coverage/cover = locate() in coats
	for(var/datum/dirt_feature/feature as anything in coats)
		if(feature.covering)
			surface.outline()
			if(in_profile)
				surface.outline_band()
			break
	var/list/thickest = new /list(pixel_count)
	var/list/makers = new /list(pixel_count)
	var/list/flags_of = surface.flags_of
	// the pixels given a thickness lie from lowest to highest, and with none the walk below is empty
	var/lowest = pixel_count + 1
	var/highest = 0
	for(var/datum/dirt_feature/feature as anything in coats)
		var/covering = feature.covering
		for(var/index, value in feature.pixels_on(surface, surface_rows))
			var/thickness = covering ? dirt_covering_thickness(feature, value, index, flags_of[index], in_profile, surface.width) : value
			if(thickness > (thickest[index] || 0))
				thickest[index] = thickness
				makers[index] = feature
				if(index < lowest)
					lowest = index
				if(index > highest)
					highest = index
	var/datum/dirt_pixels/drawn = new(surface.width, surface.height)
	var/list/drawn_indexes = list()
	drawn.drawn_indexes = drawn_indexes
	var/list/ringed = list()
	for(var/index in lowest to highest)
		var/thickness = thickest[index]
		if(thickness < DIRT_THRESHOLD_FILM)
			continue
		var/flags = flags_of[index]
		var/limb = DIRT_PIXEL_LIMB(flags)
		var/datum/dirt_feature/maker = makers[index]
		if(limb == DIRT_LIMB_HEAD)
			if(maker.veil)
				var/limit = dirt_face_zone(surface, index)
				if(!isnull(limit) && limit < thickness)
					thickness = limit
					if(thickness < DIRT_THRESHOLD_FILM)
						continue
			else if(surface.face_guard[index])
				continue
		var/role = maker.role
		if(!role)
			if(thickness == DIRT_HAZE_T)
				role = DIRT_ROLE_HAZE
			else if(thickness >= DIRT_THRESHOLD_CORE)
				role = DIRT_ROLE_CORE
			else if(thickness >= DIRT_THRESHOLD_BODY)
				role = DIRT_ROLE_BODY
			else
				role = DIRT_ROLE_FILM
		if(on_skin && maker.skin_role)
			role = maker.skin_role
		if(limb == DIRT_LIMB_HEAD && surface.eye_soft[index] && (role == DIRT_ROLE_BODY || role == DIRT_ROLE_CORE))
			role = DIRT_ROLE_FILM
		if(on_cloth && (flags & DIRT_PIXEL_RIM) && role != DIRT_ROLE_CORE)
			role = lighter[role]
		if(role)
			drawn.roles[index] = role
			drawn.thicknesses[index] = thickness
			drawn_indexes += index
			if(maker.ring)
				ringed += index
	if(on_skin && (!cover || (cover.cause == DIRT_CAUSE_PLUNGE && cover.level < 3)))
		drawn = dirt_skin_streaks(drawn, surface)
	if((material_flags & DIRT_MATERIAL_LIGHT) && !cover)
		drawn = dirt_thin_light(drawn, surface)
	drawn = dirt_cleanup(drawn)
	if(length(ringed))
		drawn = dirt_rings(drawn, ringed, surface)
	switch(material?.edge)
		if(DIRT_EDGE_HALO)
			drawn = dirt_halo(drawn, surface)
		if(DIRT_EDGE_TIDE)
			drawn = dirt_tide(drawn)
	if(material_flags & DIRT_MATERIAL_SHEEN)
		drawn = dirt_sheen(drawn, surface)
		// a pale glint on skin reads as a scar
		if(cover && on_cloth)
			drawn = dirt_cover_sheen(drawn, surface, cover.shine_points(), (material_flags & DIRT_MATERIAL_GLOSSY) ? 3 : 2)
	if(material_flags & DIRT_MATERIAL_SPECKS)
		drawn = dirt_ash_specks(drawn, surface)
	if(length(specks))
		drawn = dirt_scatter(drawn, specks, surface_kind, surface, surface_rows)
	for(var/datum/dirt_feature/stamps/stamp as anything in stamps)
		dirt_overlay_stamps(drawn, stamp, surface)
	if(on_skin)
		drawn = dirt_skin_rules(drawn, !material || (material_flags & DIRT_MATERIAL_GOO))
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
 * Returns the thickest a veil may lie on a pixel of a face. That's nothing across the eyes' top row and a pixel either
 * side of them, because rings round each eye read as spectacles. Round a lone eye in profile it's haze there, because
 * two clean pixels read as a chip. On the row under the eyes it's haze. Returns null elsewhere, where the veil decides.
 *
 * Arguments:
 * - surface: The surface.
 * - index: A pixel of its head.
 */
/proc/dirt_face_zone(datum/dirt_surface/surface, index)
	var/list/span = surface.eye_span
	if(!span)
		return null
	var/row = floor((index - 1) / surface.width)
	var/column = index - 1 - row * surface.width
	if(row == span[1] && column >= span[2] - 1 && column <= span[3] + 1)
		return span[4] > 1 ? 0 : DIRT_HAZE_T
	if(row == span[1] + 1 && column >= span[2] && column <= span[3])
		return DIRT_HAZE_T
	return null

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
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
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
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
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
 * Makes a mask as skin takes it, and returns it. No pixel without a neighbour stays, since a lone body dot reads as a
 * mole and nothing smaller than 2 px stays. Skin gets wiped, so its core softens to body. Goo keeps its core, because
 * flattened it reads as body paint.
 *
 * The reference drops lone body pixels, then every group of pixels smaller than two. Neither step leaves a new lone
 * pixel, so together they drop exactly the pixels with no neighbour. A pixel dropped had none, so dropping it where it
 * is leaves every other pixel's neighbours as they were.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - goo: Whether it's goo, which keeps its core.
 */
/proc/dirt_skin_rules(datum/dirt_pixels/drawn, goo = TRUE)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/table = dirt_neighbour_table(drawn.width, drawn.height)
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		if(!roles[index])
			continue
		if(!goo && roles[index] == DIRT_ROLE_CORE)
			roles[index] = DIRT_ROLE_BODY
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
 * Thins a light material's coat on the legs, and returns the mask. Pale dirt lifts dark cloth, so a full coat reads as
 * other trousers. The body tone stays on a leg's bottom two pixels and turns to film above them. The sole's row is
 * film, with every third column clean. From 4 px up, pixels drop out: 14% more for each pixel up, 55% at most. Each
 * pixel is judged on its own, so the mask is changed where it is.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_thin_light(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = drawn.width
	var/right_along_per_pixel = dirt_metric(DIRT_LIMB_R_LEG)[2]
	var/left_along_per_pixel = dirt_metric(DIRT_LIMB_L_LEG)[2]
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		var/role = roles[index]
		if(!role)
			continue
		var/limb = DIRT_PIXEL_LIMB(flags_of[index])
		if(limb != DIRT_LIMB_R_LEG && limb != DIRT_LIMB_L_LEG)
			continue
		var/up = surface.height_of[index] / (limb == DIRT_LIMB_R_LEG ? right_along_per_pixel : left_along_per_pixel)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		if(up < 0.5)
			if(column % 3 == 0)
				drawn.put_index(index, null, null)
				continue
			roles[index] = DIRT_ROLE_FILM
		else if(up > 2 && (role == DIRT_ROLE_BODY || role == DIRT_ROLE_CORE))
			roles[index] = DIRT_ROLE_FILM
		if(up >= 4 && dirt_noise_hash(column, row, 419) < min(0.55, 0.14 * (up - 3)))
			drawn.put_index(index, null, null)
	return drawn

/**
 * Rings what ringed features drew with broken film, and returns the mask. Abrasion's light core marks dark cloth, and
 * its ring marks light cloth. The ring takes about half of the bare pixels of the surface beside them, off the face's
 * guards.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - ringed: The pixels ringed features drew, before the cleanup.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_rings(datum/dirt_pixels/drawn, list/ringed, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = drawn.width
	var/list/table = dirt_neighbour_table(width, drawn.height)
	for(var/index in ringed)
		for(var/neighbour in table[index])
			if(roles[neighbour] || !DIRT_PIXEL_LIMB(flags_of[neighbour]) || surface.face_guard[neighbour])
				continue
			var/row = floor((neighbour - 1) / width)
			if(dirt_noise_hash(neighbour - 1 - row * width, row, 233) < 0.5)
				drawn.put_index(neighbour, DIRT_ROLE_FILM, 0.3)
	return drawn

/**
 * Rings thick patches with film, and returns the mask. It's oil's wicked halo, or wet mud's damp edge. A body or core
 * pixel with two or more such neighbours puts film on the bare pixels of the surface beside it, off its rim and the
 * face's guards.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_halo(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/list/table = dirt_neighbour_table(drawn.width, drawn.height)
	// the film it puts goes on bare pixels and is never thick, so no pixel's count changes as it walks
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		var/role = roles[index]
		if(role != DIRT_ROLE_BODY && role != DIRT_ROLE_CORE)
			continue
		var/list/neighbours = table[index]
		var/thick_count = 0
		for(var/neighbour in neighbours)
			if(roles[neighbour] == DIRT_ROLE_BODY || roles[neighbour] == DIRT_ROLE_CORE)
				thick_count++
		if(thick_count < 2)
			continue
		for(var/neighbour in neighbours)
			var/flags = flags_of[neighbour]
			if(!roles[neighbour] && DIRT_PIXEL_LIMB(flags) && !(flags & DIRT_PIXEL_RIM) && !surface.face_guard[neighbour])
				drawn.put_index(neighbour, DIRT_ROLE_FILM, 0.3)
	return drawn

/**
 * Darkens a drying coat's top edge, and returns the mask. About half of its film pixels with nothing over them take
 * the body tone, in row-major order, two side by side at most, following the jagged top. It never makes core or a
 * long run, because that reads as trim.
 *
 * Arguments:
 * - drawn: The mask, changed.
 */
/proc/dirt_tide(datum/dirt_pixels/drawn)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/width = drawn.width
	var/run_length = 0
	var/previous
	for(var/index in 1 to length(roles))
		if(roles[index] != DIRT_ROLE_FILM || (index > width && roles[index - width]))
			continue
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		run_length = (previous == index - 1 && column > 0) ? run_length + 1 : 1
		if(run_length <= 2 && dirt_noise_hash(column, row, 71) < 0.5)
			roles[index] = DIRT_ROLE_BODY
		previous = index
	return drawn

/**
 * Puts one wet highlight on a coat, and returns the mask. It's a 1x2 fleck on the leg's most convex lit spot, the
 * boot's toe or the shin's front, 1 to 4.5 px up a leg. It goes on body or core with body or core under it, both
 * inside the silhouette. The leftmost such pixel takes it, or the upper one on a tie.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_sheen(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = drawn.width
	// the last pixel with one under it
	var/last_above = length(roles) - width
	var/lit
	var/lit_column
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		if(index > last_above)
			continue
		var/role = roles[index]
		var/below_role = roles[index + width]
		if((role != DIRT_ROLE_BODY && role != DIRT_ROLE_CORE) || (below_role != DIRT_ROLE_BODY && below_role != DIRT_ROLE_CORE))
			continue
		var/flags = flags_of[index]
		var/below_flags = flags_of[index + width]
		if(!DIRT_PIXEL_ZONE(flags) || (flags & DIRT_PIXEL_RIM) || !DIRT_PIXEL_ZONE(below_flags) || (below_flags & DIRT_PIXEL_RIM))
			continue
		var/limb = DIRT_PIXEL_LIMB(flags)
		if(limb != DIRT_LIMB_R_LEG && limb != DIRT_LIMB_L_LEG)
			continue
		var/up = surface.height_of[index] / dirt_metric(limb)[2]
		if(up < 1 || up > 4.5)
			continue
		var/column = (index - 1) % width
		// the lowest column, then the lowest index, so it's the same pixel whatever order the walk takes
		if(isnull(lit) || column < lit_column || (column == lit_column && index < lit))
			lit = index
			lit_column = column
	if(lit)
		roles[lit] = DIRT_ROLE_FLECK
		roles[lit + width] = DIRT_ROLE_FLECK
	return drawn

/**
 * Puts a whole-body wet coat's glints on a mask, and returns it. Each is a pale glint fading into a film pixel under
 * it, because a lone pale pixel reads as a harsh speck. One goes at the body pixel nearest each shine point,
 * within 3 px of it, and the first in row-major order wins a tie. Glints go only on the torso and the legs, because
 * on a hand one reads as a speck. They go inside the silhouette, on body with body under it and off the face's guards.
 * They're 4 px apart counted along rows and columns, and there are `most` of them at most. Where they may go is read
 * before any is put, so the mask is changed where it is.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 * - shine: The coat's shine points, each list(pixels across from the tile's middle, pixels up from its floor).
 * - most: How many glints at most.
 */
/proc/dirt_cover_sheen(datum/dirt_pixels/drawn, datum/dirt_surface/surface, list/shine, most)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = drawn.width
	var/list/spots = list()
	for(var/index in 1 to length(roles) - width)
		if(roles[index] != DIRT_ROLE_BODY || roles[index + width] != DIRT_ROLE_BODY)
			continue
		var/flags = flags_of[index]
		var/limb = DIRT_PIXEL_LIMB(flags)
		if(!DIRT_PIXEL_ZONE(flags) || (flags & DIRT_PIXEL_RIM) || surface.face_guard[index])
			continue
		if(limb == DIRT_LIMB_TORSO || limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_L_LEG)
			spots += index
	if(!length(spots))
		return drawn
	var/list/placed = list()
	for(var/list/point as anything in shine)
		var/target_column = 15.5 + point[1]
		var/target_row = 31 - point[2]
		var/nearest
		var/nearest_distance
		for(var/index in spots)
			var/row = floor((index - 1) / width)
			var/across = index - 1 - row * width - target_column
			var/down = row - target_row
			var/distance = across * across + down * down
			if(isnull(nearest) || distance < nearest_distance)
				nearest = index
				nearest_distance = distance
		if(nearest_distance > 9)
			continue
		var/nearest_row = floor((nearest - 1) / width)
		var/nearest_column = nearest - 1 - nearest_row * width
		var/crowded = FALSE
		for(var/other in placed)
			var/other_row = floor((other - 1) / width)
			if(abs(nearest_column - (other - 1 - other_row * width)) + abs(nearest_row - other_row) < 4)
				crowded = TRUE
				break
		if(crowded)
			continue
		roles[nearest] = DIRT_ROLE_GLINT
		roles[nearest + width] = DIRT_ROLE_FILM
		placed += nearest
		if(length(placed) >= most)
			break
	return drawn

/**
 * Scatters ash's light flecks through a coat, and returns the mask. There are four at most, on body inside the
 * silhouette, each at least 3 px from the others, counted along rows and columns. They're placed in the order a noise
 * hash puts the pixels, row-major on a tie. Pixels are bucketed by their hash, because the draft's hash has 65536
 * values, too many to sort a hash and an index as one number.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_ash_specks(datum/dirt_pixels/drawn, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = drawn.width
	// the pixels by their hash, each hash's in index order
	var/alist/by_hash = alist()
	for(var/index in 1 to length(roles))
		var/flags = flags_of[index]
		if(roles[index] != DIRT_ROLE_BODY || !DIRT_PIXEL_ZONE(flags) || (flags & DIRT_PIXEL_RIM))
			continue
		var/row = floor((index - 1) / width)
		var/hash = dirt_noise_hash(index - 1 - row * width, row, 33)
		var/list/same_hash = by_hash[hash]
		if(!same_hash)
			same_hash = list()
			by_hash[hash] = same_hash
		same_hash += index
	var/list/hashes = list()
	for(var/hash in by_hash)
		hashes += hash
	sortTim(hashes, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/list/placed = list()
	for(var/hash in hashes)
		for(var/index in by_hash[hash])
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			var/crowded = FALSE
			for(var/other in placed)
				var/other_row = floor((other - 1) / width)
				if(abs(column - (other - 1 - other_row * width)) + abs(row - other_row) < 3)
					crowded = TRUE
					break
			if(crowded)
				continue
			roles[index] = DIRT_ROLE_FLECK
			placed += index
			if(length(placed) >= 4)
				return drawn
	return drawn

/**
 * Places specks after the coats, and returns the mask. Each goes where it lies first in row-major order, on its own
 * limb's pixels off the face's guards, and only where it's clear of every pixel drawn so far. A speck is soft: film
 * with a haze ring, or a drip fading from film to haze. A strict speck also keeps off the rows and columns of the
 * strict ones before it. On bare skin only drips are placed, because a dot there reads as a mole however soft. Cloth
 * draws a speck's rim a role lighter.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - specks: The specks (/datum/dirt_feature/speck), in the order they're placed.
 * - surface_kind: DIRT_SURFACE_SKIN or DIRT_SURFACE_CLOTH.
 * - surface: The surface it's drawn on.
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/proc/dirt_scatter(datum/dirt_pixels/drawn, list/specks, surface_kind, datum/dirt_surface/surface, alist/surface_rows)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/lighter = dirt_lighter_roles()
	// each list(columns right, rows down, DIRT_ROLE_* define)
	var/static/list/drip_shape = list(list(0, 0, DIRT_ROLE_FILM), list(0, 1, DIRT_ROLE_FILM), list(0, 2, DIRT_ROLE_HAZE), list(-1, 0, DIRT_ROLE_HAZE), list(1, 0, DIRT_ROLE_HAZE))
	var/static/list/dot_shape = list(list(0, 0, DIRT_ROLE_FILM), list(1, 0, DIRT_ROLE_HAZE), list(-1, 0, DIRT_ROLE_HAZE), list(0, 1, DIRT_ROLE_HAZE), list(0, -1, DIRT_ROLE_HAZE))
	var/list/roles = drawn.roles
	var/list/flags_of = surface.flags_of
	var/width = surface.width
	var/list/table = dirt_neighbour_table(width, surface.height)
	var/list/used_rows = new /list(surface.height)
	var/list/used_columns = new /list(width)
	for(var/datum/dirt_feature/speck/speck as anything in specks)
		if(surface_kind == DIRT_SURFACE_SKIN && !speck.drip)
			continue
		var/start
		for(var/index, value in speck.pixels_on(surface, surface_rows))
			if(value >= DIRT_THRESHOLD_FILM && (isnull(start) || index < start))
				start = index
		if(!start)
			continue
		var/start_row = floor((start - 1) / width)
		var/start_column = start - 1 - start_row * width
		var/list/pixels = list()
		var/list/pixel_roles = list()
		var/list/shape = speck.drip ? drip_shape : dot_shape
		for(var/list/spot as anything in shape)
			var/index = surface.pixel_index(start_column + spot[1], start_row + spot[2])
			if(index && DIRT_PIXEL_LIMB(flags_of[index]) == speck.limb && !surface.face_guard[index])
				pixels += index
				pixel_roles += spot[3]
		if(!length(pixels))
			continue
		var/clear = TRUE
		for(var/index in pixels)
			var/row = floor((index - 1) / width)
			if(speck.strict && (used_rows[row + 1] || used_columns[index - row * width]))
				clear = FALSE
				break
			for(var/neighbour in table[index])
				if(roles[neighbour] && !(neighbour in pixels))
					clear = FALSE
					break
			if(!clear)
				break
		if(!clear)
			continue
		for(var/position in 1 to length(pixels))
			var/index = pixels[position]
			var/role = pixel_roles[position]
			if(surface_kind == DIRT_SURFACE_CLOTH && (flags_of[index] & DIRT_PIXEL_RIM))
				role = lighter[role]
			if(role)
				drawn.put_index(index, role, 0.5)
		if(speck.strict)
			for(var/index in pixels)
				var/row = floor((index - 1) / width)
				used_rows[row + 1] = TRUE
				used_columns[index - row * width] = TRUE
	return drawn

/**
 * Lays stamps over a mask, and changes it. A pixel they wipe goes clean, and a highlight they force turns film
 * whatever is there. Every other mark draws where it ranks over what's there, never on an eye's or a mouth's guard,
 * and film at most on an eye's diagonal.
 *
 * Arguments:
 * - drawn: The mask, changed.
 * - stamps: The stamps.
 * - surface: The surface it's drawn on.
 */
/proc/dirt_overlay_stamps(datum/dirt_pixels/drawn, datum/dirt_feature/stamps/stamps, datum/dirt_surface/surface)
	var/list/ranks = dirt_role_ranks()
	var/list/roles = drawn.roles
	for(var/index, mark in stamps.pixels(surface))
		if(mark == DIRT_STAMP_CLEAN)
			drawn.put_index(index, null, null)
			continue
		if(mark == DIRT_STAMP_LIT)
			drawn.put_index(index, DIRT_ROLE_FILM, 0.3)
			continue
		var/role = mark
		if(DIRT_PIXEL_LIMB(surface.flags_of[index]) == DIRT_LIMB_HEAD)
			if(surface.face_guard[index])
				continue
			if(surface.eye_soft[index])
				role = DIRT_ROLE_FILM
		var/held = roles[index]
		if(ranks[role] > (held ? ranks[held] : 0))
			drawn.put_index(index, role, role == DIRT_ROLE_CORE ? 0.9 : (role == DIRT_ROLE_BODY ? 0.6 : 0.3))

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
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
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
				softened.drawn_indexes?.Add(neighbour)
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
 * keeps a full tie. The pixel takes the winner's material. All the splats on one surface make one mask this way, oldest
 * first. A mess splat below the top level leaves out each of its pieces that comes within DIRT_RUN_GAP px of an
 * earlier mess splat's, because splats piled on each other fill into one sheet. A top-level splat keeps everything,
 * because it covers. Other materials neither keep apart from earlier splats nor make later ones keep apart. A splat's
 * packed raster is read run by run as it merges, and never made into a mask. The exception is mess that leaves pieces
 * out, whose pieces are read on its whole mask (dirt_pixels_from_drawn()).
 *
 * Arguments:
 * - pixel_maps: The masks, all one size, at least one: each a /datum/dirt_pixels, or a splat's packed raster
 *   (/datum/dirt_pixels/proc/drawn()).
 * - materials: Each mask's material, as a splat stores it (dirt_splat_materials()), or null when all are mess.
 * - width, height: The masks' size, read when the first is a packed raster.
 * - limbs: Each mask's limbs, DIRT_LIMB_BIT() of each, as a general deposit keeps to them (dirt_pixels_from_drawn()).
 *   They're read for packed rasters alone. Null or 0 means every limb.
 * - surface: The surface the packed rasters are rasterised on, whose pixels name their limbs. Read only with limbs.
 */
/proc/dirt_merge(list/pixel_maps, list/materials = null, width = null, height = null, list/limbs = null, datum/dirt_surface/surface = null)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/ranks = dirt_role_ranks()
	var/list/packed_thicknesses = dirt_packed_thicknesses()
	var/datum/dirt_pixels/first = pixel_maps[1]
	var/datum/dirt_pixels/merged = istext(first) ? new(width, height) : new(first.width, first.height)
	var/list/merged_indexes = list()
	merged.drawn_indexes = merged_indexes
	var/list/merged_roles = merged.roles
	var/list/merged_thicknesses = merged.thicknesses
	var/list/merged_materials
	if(materials)
		merged_materials = new /list(length(merged_roles))
		merged.materials = merged_materials
	var/alist/taken = alist()
	for(var/position in 1 to length(pixel_maps))
		var/datum/dirt_pixels/pixel_map = pixel_maps[position]
		var/material = materials ? materials[position] : DIRT_MATERIAL_MESS
		var/is_mess = material == DIRT_MATERIAL_MESS
		var/drawn = istext(pixel_map) ? pixel_map : null
		// mess that may leave pieces out reads them on its whole mask
		if(drawn && is_mess && length(taken) && text2ascii(drawn, 1) != 49)
			pixel_map = dirt_pixels_from_drawn(drawn, merged.width, merged.height)
			drawn = null
		var/list/roles
		var/list/thicknesses
		var/list/indexes
		var/list/left_out
		var/kept_limbs = (drawn && limbs) ? limbs[position] : null
		// null while every limb is kept
		var/list/flags_of = (kept_limbs && (kept_limbs & DIRT_LIMBS_ALL) != DIRT_LIMBS_ALL) ? surface.flags_of : null
		if(!drawn)
			roles = pixel_map.roles
			thicknesses = pixel_map.thicknesses
			indexes = pixel_map.drawn_indexes || dirt_index_range(length(roles))
			left_out = (!is_mess || pixel_map.covers || !length(taken)) ? null : dirt_pieces_near(pixel_map, taken)
		// a packed raster's runs never meet, so on a merge holding nothing yet every pixel they reach is blank
		var/onto_blank = drawn && !flags_of && !is_mess && !length(merged_indexes)
		// a packed raster's runs, or a mask's drawn pixels as runs of one
		var/run_count = drawn ? DIRT_PACKED_COUNT(drawn) : length(indexes)
		for(var/run in 1 to run_count)
			var/first_index
			var/last_index
			var/role
			var/thickness
			if(drawn)
				var/bits = DIRT_PACKED_BITS(drawn, run)
				first_index = DIRT_PACKED_FIRST(bits)
				last_index = DIRT_PACKED_LAST(bits)
				role = DIRT_PACKED_ROLE(bits)
				thickness = packed_thicknesses[DIRT_PACKED_CODE(bits) + 1]
			else
				first_index = indexes[run]
				last_index = first_index
				role = roles[first_index]
				if(!role || left_out?[first_index])
					continue
				thickness = thicknesses[first_index]
			if(onto_blank)
				for(var/index in first_index to last_index)
					merged_indexes += index
					merged_roles[index] = role
					merged_thicknesses[index] = thickness
					if(merged_materials)
						merged_materials[index] = material
				continue
			var/rank = ranks[role]
			// every limb kept, and not mess
			if(!flags_of && !is_mess)
				for(var/index in first_index to last_index)
					var/held = merged_roles[index]
					if(!held)
						merged_indexes += index
					else
						var/held_rank = ranks[held]
						if(!(rank > held_rank || (rank == held_rank && thickness > merged_thicknesses[index])))
							continue
					merged_roles[index] = role
					merged_thicknesses[index] = thickness
					if(merged_materials)
						merged_materials[index] = material
				continue
			for(var/index in first_index to last_index)
				if(flags_of)
					var/limb = DIRT_PIXEL_LIMB(flags_of[index])
					if(!(limb && (kept_limbs & DIRT_LIMB_BIT(limb))))
						continue
				if(is_mess)
					taken[index] = TRUE
				var/held = merged_roles[index]
				if(!held)
					merged_indexes += index
				else
					var/held_rank = ranks[held]
					if(!(rank > held_rank || (rank == held_rank && thickness > merged_thicknesses[index])))
						continue
				merged_roles[index] = role
				merged_thicknesses[index] = thickness
				if(merged_materials)
					merged_materials[index] = material
	return merged

/**
 * Returns a surface's splats in one direction merged with the parts drawn under and over it. Each splat leaves out the
 * pixels of the rounded parts on its zone (dirt_part_rounded()): straight streaks carried onto a breast read as blocks.
 * Then each part drawn under the surface takes each splat on its zone in its own pixels (dirt_part_field()), merged in
 * after the splats and keeping every piece, as a top-level splat does. A part drawn over the surface takes its share on
 * itself, so its field isn't drawn here.
 *
 * Arguments:
 * - pixel_maps: Each splat's raster in this direction, at its level here (dirt_part_body_level()). It's either its
 *   packed text, read into a mask of its own on its limbs where the rounded parts' pixels are taken out of it, or a
 *   mask, its own copy, which they're taken out of.
 * - splats: The splats, in the same order.
 * - under_parts: The parts drawn under the surface in this direction, each a /datum/dirt_part_source, lowest first.
 * - over_parts: The parts drawn over it in this direction (dirt_split_parts()).
 * - owns: alist(source = its pixels in this direction, from dirt_part_own()).
 * - direction: The direction.
 * - materials: The splats' materials, dirt_splat_materials() of them, or null when all are mess.
 * - surface: The surface the packed rasters are rasterised on, or null where none is packed.
 */
/proc/dirt_merge_with_parts(list/pixel_maps, list/splats, list/under_parts, list/over_parts, alist/owns, direction, list/materials = null, datum/dirt_surface/surface = null)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/sources = under_parts + over_parts
	var/list/maps = pixel_maps.Copy()
	var/list/limbs = list()
	for(var/position in 1 to length(splats))
		var/datum/dirt_splat/splat = splats[position]
		limbs += splat.limbs
		for(var/datum/dirt_part_source/source as anything in sources)
			if(!dirt_part_rounded(source.kind) || dirt_part_zone(source.kind) != splat.zone)
				continue
			var/datum/dirt_pixels/pixel_map = maps[position]
			if(istext(pixel_map))
				pixel_map = dirt_pixels_from_drawn(pixel_map, surface.width, surface.height, splat.limbs, surface)
				maps[position] = pixel_map
			for(var/index in owns[source])
				pixel_map.roles[index] = null
				pixel_map.thicknesses[index] = null
	// the caller's, so each direction adds its parts' fields to its own copy
	var/list/maps_materials = materials?.Copy()
	for(var/datum/dirt_splat/splat as anything in splats)
		for(var/datum/dirt_part_source/source as anything in under_parts)
			var/list/own = owns[source]
			if(length(own) && dirt_part_zone(source.kind) == splat.zone)
				maps += dirt_part_field(source.kind, own, splat.zone, splat.level, splat.variant, direction)
				// a part's own share is mess
				if(maps_materials)
					maps_materials += DIRT_MATERIAL_MESS
	return dirt_merge(maps, maps_materials, surface?.width, surface?.height, limbs, surface)

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
