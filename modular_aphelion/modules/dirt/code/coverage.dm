// Full coverage: a plunge, a blast and a douse coat the whole body from one field in mob space. A point is sampled
// by its pixels across from the tile's middle and up from its floor. So a body, and any other shape that samples the
// same random draws, meet along one line.

/**
 * Every random draw a plunge or a blast makes, whatever its level, in the reference generator's order. Anything else
 * drawn from the same field makes them on the same stream (dirt_cover_draws()), so a coat's line meets across shapes.
 */
/datum/dirt_cover_draws
	/// The coat's line at each level, in pixels over the floor: knee-deep, chest-deep, over the head.
	var/list/lines
	/// How many pixels the line climbs from the tile's middle to 16 px across, either way.
	var/tilt
	/// The seed of the coat's noise, a whole number.
	var/seed
	/// The theta a blast comes from: the front most often, or 60 degrees to either side.
	var/facing
	/// The short runs of thicker material down a plunge's coat, each list(pixels across, top in pixels up, length).
	/// Of the five drawn, one within 3 px across of an earlier run is left out. The two would join into one line that
	/// reads as a strap.
	var/list/kept_runs
	/// alist(pixels across = the kept run within half a pixel of it, or FALSE for none). Each is found the first time a
	/// plunge's coat is asked about a point there (dirt_plunge_thickness()). Kept runs lie 3 px apart, so there's one
	/// at most. A point lies in a column's middle on every canvas, so it holds 64 entries at most.
	var/alist/runs_at
	/// Where a wet coat catches the light, each list(pixels across, pixels up).
	var/list/shine

/**
 * Returns a plunge's or a blast's draws, from its random stream.
 *
 * Arguments:
 * - rng: The deposit's random stream.
 */
/proc/dirt_cover_draws(datum/dirt_random/rng)
	RETURN_TYPE(/datum/dirt_cover_draws)
	var/static/list/base_lines = list(9, 18, 40)
	var/datum/dirt_cover_draws/draws = new
	draws.lines = list()
	for(var/base in base_lines)
		draws.lines += base + rng.uniform(-1, 1)
	var/tilt_sign = rng.choose(list(-1, 1))
	draws.tilt = tilt_sign * rng.uniform(1, 2)
	draws.seed = rng.randrange(65536)
	draws.facing = rng.choose(list(DIRT_THETA_FRONT, DIRT_THETA_FRONT, DIRT_THETA_FRONT, 60, -60))
	draws.kept_runs = list()
	for(var/run_number in 1 to 5)
		var/across = rng.uniform(-9, 9)
		var/top = rng.uniform(10, 24)
		var/list/coat_run = list(across, top, rng.uniform(2.5, 4.5))
		var/apart = TRUE
		for(var/list/kept as anything in draws.kept_runs)
			if(abs(across - kept[1]) < 3)
				apart = FALSE
				break
		if(apart)
			draws.kept_runs += list(coat_run)
	draws.shine = list()
	for(var/shine_number in 1 to 5)
		var/across = rng.uniform(-8, 8)
		draws.shine += list(list(across, rng.uniform(5, 24)))
	return draws

/**
 * Every random draw a douse makes, whatever its level, in the reference generator's order. Anything else drawn from
 * the same field makes the same draws from the same random stream (dirt_douse_draws()). So a stream of the douse down
 * one shape meets the one down the next.
 */
/datum/dirt_douse_draws
	/// The seed of its noise, a whole number.
	var/seed
	/// Its streams, each list(pixels across, half width, length as a share of the level's reach, noise seed), kept 3 px
	/// apart. Evenly spaced full-length streams read as pinstripes.
	var/list/streams
	/// Where a wet coat catches the light, each list(pixels across, pixels up).
	var/list/shine

/**
 * Returns a douse's draws, from its random stream. It draws twelve candidate streams with uneven widths and lengths.
 * It keeps each one that lies 3 px or more across from every stream kept before it.
 *
 * Arguments:
 * - rng: The deposit's random stream.
 */
/proc/dirt_douse_draws(datum/dirt_random/rng)
	RETURN_TYPE(/datum/dirt_douse_draws)
	var/datum/dirt_douse_draws/draws = new
	draws.streams = list()
	for(var/stream_number in 1 to 12)
		var/across = rng.uniform(-12, 12)
		var/half_width = rng.uniform(0.4, 1.3)
		var/stream_length = rng.uniform(0.15, 1) ** 0.8
		var/list/stream = list(across, half_width, stream_length, rng.randrange(65536))
		var/apart = TRUE
		for(var/list/kept as anything in draws.streams)
			if(abs(across - kept[1]) < 3)
				apart = FALSE
				break
		if(apart)
			draws.streams += list(stream)
	draws.seed = rng.randrange(65536)
	draws.shine = list()
	for(var/shine_number in 1 to 5)
		var/across = rng.uniform(-8, 8)
		draws.shine += list(list(across, rng.uniform(5, 24)))
	return draws

/**
 * Returns how thick a plunge's coat lies at a point: haze over a jagged line, and film along it. Under the line it's
 * the body tone, with film windows stretched into vertical runs that open up with height, so the garment's shading
 * shows. Short runs of thicker material lie apart, and the floor's row is solid. A glossy material keeps almost no
 * windows under level 2's line. Bare skin thins with height much faster, in uneven blotches mixed with drip streaks,
 * because even weight reads as camo. A light material thins out more. The noise doesn't depend on the level, so its
 * field samples it once. It samples the line's jag once a cell across, and the body noise once a pixel.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 * - up: Pixels up from the floor.
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_cover_draws().
 * - light: Whether it's a light material.
 * - glossy: Whether it's a glossy material.
 * - on_skin: Whether it's on bare skin.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 * - index: The pixel's index, which the samples are kept under.
 */
/proc/dirt_plunge_thickness(mob_x, up, level, datum/dirt_cover_draws/draws, light = FALSE, glossy = FALSE, on_skin = FALSE, alist/samples, index)
	var/jag_cell = floor((mob_x + 32) / 2.5)
	var/line = draws.lines[level] + draws.tilt * mob_x / 16 + (dirt_field_noise_hash(samples, "plunge line", jag_cell, jag_cell, 0, draws.seed) - 0.5) * 2.2
	var/depth = line - up
	if(depth < -1.6)
		return 0
	if(depth < 0)
		return DIRT_HAZE_T
	if(depth < 1.6)
		return DIRT_FILM_T
	if(up < 0.5)
		return 1
	if(!light)
		// FALSE where there's no run, since null means that column wasn't asked about yet
		var/alist/runs_at = (draws.runs_at ||= alist())
		var/list/coat_run = runs_at[mob_x]
		if(isnull(coat_run))
			coat_run = FALSE
			for(var/list/kept as anything in draws.kept_runs)
				if(abs(mob_x - kept[1]) < 0.5)
					coat_run = kept
					break
			runs_at[mob_x] = coat_run
		if(coat_run)
			var/top = coat_run[2]
			if(top - min(coat_run[3], 3) < up && up <= top && top < line - 2)
				return 1
	var/noise
	var/thin
	if(on_skin)
		noise = 0.6 * dirt_field_spread_noise(samples, "plunge skin", index, mob_x, up, draws.seed + 5, 3.5) + 0.4 * dirt_field_spread_noise(samples, "plunge streaks", index, mob_x * 2.5, up * 0.35, draws.seed + 7, 2.6)
		thin = 0.1 + 0.5 * min(1, up / 26) + (light ? 0.25 : 0)
	else
		// stretched into thin runs, because blobs read as camo
		noise = dirt_field_spread_noise(samples, "plunge", index, mob_x * 2.2, up * 0.4, draws.seed + 5, 2.6)
		thin = 0.08 + 0.27 * min(1, up / 28) + (light ? 0.25 : 0)
	if(glossy && up < draws.lines[2])
		thin = 0.02
	return noise < thin ? DIRT_FILM_T : DIRT_BODY_T

/**
 * Returns how thick a blast's coat lies at a point: large soft round patches, because a stretched field draws tiger
 * stripes. They cover more with the level, and the more squarely the point faces the blast. From level 2 some lie on
 * the lee side, as clouds wrap round. The head's and the shoulders' tops ramp up smoothly, because a step draws a
 * headband. A light material covers less. The noise doesn't depend on the level, so its field samples it once a pixel.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 * - up: Pixels up from the floor.
 * - facing: How squarely the point faces the blast, from 0 to 1 (dirt_facing_amount()).
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_cover_draws().
 * - light: Whether it's a light material.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 * - index: The pixel's index, which the samples are kept under.
 */
/proc/dirt_blast_thickness(mob_x, up, facing, level, datum/dirt_cover_draws/draws, light = FALSE, alist/samples, index)
	var/static/list/boosts = list(0, 0.25, 0.42)
	var/big = dirt_field_spread_noise(samples, "blast", index, mob_x, up, draws.seed + 9, 4.5)
	var/top = 0.18 * clamp((up - 20) / 7, 0, 1)
	var/score = facing * 0.7 + top + (big - 0.5) * 0.9 + boosts[level] - (light ? 0.15 : 0)
	if(score > 1.05)
		return DIRT_BODY_T
	if(score > 0.62)
		return DIRT_FILM_T
	if(score > 0.5)
		return DIRT_HAZE_T
	return 0

/**
 * Returns how squarely a point faces a theta, from 0 (away) to 1 (straight at it).
 *
 * Arguments:
 * - theta: The point's theta.
 * - facing: The theta it's faced with.
 */
/proc/dirt_facing_amount(theta, facing)
	return (1 + cos(theta - facing)) / 2

/**
 * Returns a light material's coat at a point. Pale dirt never coats, because a coat reads as a pastel recolour or white
 * hair. So its film stays where 2-3 px noise allows, about 55% of it, and the body tone only as clumps on spots that
 * face up. The noise doesn't depend on the level, so its field samples it once a pixel.
 *
 * Arguments:
 * - thickness: How thick the coat lies there.
 * - sample_x, sample_y: Where its noise is sampled.
 * - seed: The coat's seed.
 * - top: Whether the point faces up.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 * - index: The pixel's index, which the samples are kept under.
 */
/proc/dirt_light_cover(thickness, sample_x, sample_y, seed, top, alist/samples, index)
	if(thickness >= DIRT_BODY_T && !top)
		thickness = DIRT_FILM_T
	if(thickness == DIRT_FILM_T && dirt_field_spread_noise(samples, "light", index, sample_x, sample_y, seed + 41, 2.5) < 0.42)
		return 0
	return thickness

/**
 * Returns the height along the torso (h) over which a whole-body coat lies as film at most. It wanders by column,
 * because a dark band under the chin reads as a beard, and a level one as a neckline. It depends only on the column,
 * so its field samples it once a column.
 *
 * Arguments:
 * - column: The pixel's column.
 * - seed: The coat's seed.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/proc/dirt_cover_collar(column, seed, alist/samples)
	return 0.9 + (dirt_field_spread_noise(samples, "collar", column, column, 0, seed + 31, 2.5) - 0.5) * 0.16

/**
 * Returns how many pixels under a column's top edge a douse's cap reaches, by level, with a jagged lower edge. The jag
 * depends only on the column, so its field samples it once a column.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_douse_draws().
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/proc/dirt_douse_cap(mob_x, level, datum/dirt_douse_draws/draws, alist/samples)
	var/static/list/caps = list(3, 6, 9)
	return caps[level] + (dirt_field_spread_noise(samples, "cap", mob_x, mob_x, 0, draws.seed, 2.5) - 0.5) * 2.4

/**
 * Returns how thick a douse lies at a point, `depth` pixels under its column's top edge. A cap follows that edge,
 * mostly the body tone, then streams run below it, and from level 2 the run-off lies round the feet. The noise doesn't
 * depend on the level, so its field samples it once. It samples the cap's body noise once a pixel, its jag once a
 * column, and the streams' centres once a row.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 * - depth: Pixels under the column's top edge.
 * - up: Pixels up from the floor.
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_douse_draws().
 * - light: Whether it's a light material, whose cap keeps more film.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 * - index: The pixel's index, which the samples are kept under.
 */
/proc/dirt_douse_thickness(mob_x, depth, up, level, datum/dirt_douse_draws/draws, light = FALSE, alist/samples, index)
	if(depth < 0)
		return 0
	var/cap = dirt_douse_cap(mob_x, level, draws, samples)
	if(depth <= cap - 1.2)
		return dirt_field_spread_noise(samples, "cap body", index, mob_x, up, draws.seed + 3, 2.2) < (light ? 0.35 : 0.12) ? DIRT_FILM_T : DIRT_BODY_T
	if(depth <= cap)
		return DIRT_FILM_T
	var/thickness = dirt_douse_streams(mob_x, depth - cap, up, level, draws, samples)
	if(up < 1.5 && level >= 2)
		thickness = max(thickness, level >= 3 ? DIRT_BODY_T : DIRT_FILM_T)
	return thickness

/**
 * Returns how thick a douse's streams lie under its cap. Each wanders as it runs, thins, and ends in a soft drip a
 * little wider than it. Its length is its share of the level's reach, and level 2 stops above the knees. Two run at
 * level 1, four at 2 and five at 3. Where each wanders depends only on the row, so its field samples it once a row,
 * keeping each row's centres by stream.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 * - below: Pixels under the cap.
 * - up: Pixels up from the floor.
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_douse_draws().
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/proc/dirt_douse_streams(mob_x, below, up, level, datum/dirt_douse_draws/draws, alist/samples)
	var/static/list/reaches = list(5, 12, 30)
	var/static/list/counts = list(2, 4, 5)
	var/list/streams = draws.streams
	var/alist/centres_by_up = samples["streams"]
	if(!centres_by_up)
		centres_by_up = alist()
		samples["streams"] = centres_by_up
	var/list/centres = centres_by_up[up]
	if(!centres)
		centres = new /list(length(streams))
		centres_by_up[up] = centres
	var/best = 0
	for(var/position in 1 to min(counts[level], length(streams)))
		var/list/stream = streams[position]
		var/reach = reaches[level] * stream[3]
		if(below > reach + 1.5)
			continue
		var/centre = centres[position]
		if(isnull(centre))
			centre = stream[1] + (dirt_value_noise(0, up, stream[4], 3.5) - 0.5) * 2.6
			centres[position] = centre
		var/half_width = stream[2] * (1 - 0.5 * min(1, below / max(1, reach)))
		var/distance = abs(mob_x - centre)
		var/thickness = 0
		if(below > reach)
			thickness = distance <= 1 ? DIRT_FILM_T : (distance <= 1.6 ? DIRT_HAZE_T : 0)
		else if(distance <= half_width)
			thickness = DIRT_BODY_T
		else if(distance <= half_width + 0.8)
			thickness = DIRT_FILM_T
		else if(distance <= half_width + 1.4)
			thickness = DIRT_HAZE_T
		best = max(best, thickness)
	return best

/**
 * Returns how thick what runs off the head lies on the torso. It flows down the front and back centre lines, heavy near
 * the top, then thins to a jagged end. A light centre with heavy sides reads as an open coat. It's nothing on another
 * limb. Its width and its end's jag depend only on the column, so its field samples them once a column.
 *
 * Arguments:
 * - limb: The point's DIRT_LIMB_* define.
 * - theta: Its theta.
 * - along: Its h, its height along the limb.
 * - mob_x: Pixels across from the tile's middle.
 * - level: 1 to 3.
 * - draws: The deposit's draws, from dirt_douse_draws().
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/proc/dirt_runoff(limb, theta, along, mob_x, level, datum/dirt_douse_draws/draws, alist/samples)
	var/static/list/reaches = list(6, 10, 14)
	if(limb != DIRT_LIMB_TORSO)
		return 0
	var/back_turn = theta - DIRT_THETA_BACK
	var/off = min(abs(theta), abs(DIRT_WRAP_DEGREES(back_turn)))
	if(off > 32 + dirt_field_spread_noise(samples, "runoff width", mob_x, mob_x, 0, draws.seed + 21, 2) * 14)
		return 0
	var/down = (1 - along) / dirt_metric(DIRT_LIMB_TORSO)[2]
	var/reach = reaches[level] + (dirt_field_spread_noise(samples, "runoff reach", mob_x, mob_x, 0, draws.seed + 23, 2) - 0.5) * 3
	return down < reach - 3 ? DIRT_BODY_T : (down < reach ? DIRT_FILM_T : 0)

/**
 * A coat over the whole body from the field in mob space, rather than on one limb. It lies on every pixel of the
 * surface, the margin round the body included. It's a coat, never a recolour. So every level keeps windows, and light
 * materials clump rather than coat. Its body field tells it its material and surface before it binds the rows
 * (/datum/dirt_canvas_field/body). It's a veil, so on a face it keeps to dirt_face_zone()'s limits.
 */
/datum/dirt_feature/coverage
	veil = TRUE
	/// The DIRT_CAUSE_* define it's drawn by: DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST or DIRT_CAUSE_DOUSE.
	var/cause
	/// Its level, 1 to 3.
	var/level
	/// Whether its material is light (DIRT_MATERIAL_LIGHT).
	var/light = FALSE
	/// Whether its material is glossy (DIRT_MATERIAL_GLOSSY).
	var/glossy = FALSE
	/// Whether it's drawn on bare skin.
	var/on_skin = FALSE

/**
 * Starts a whole-body coat.
 *
 * Arguments:
 * - cause: The DIRT_CAUSE_* define it's drawn by.
 * - level: Its level, 1 to 3.
 */
/datum/dirt_feature/coverage/New(cause, level)
	. = ..(null)
	src.cause = cause
	src.level = level

/**
 * Returns whether a cause coats the whole body from the field in mob space (/datum/dirt_feature/coverage): a plunge,
 * a blast or a douse. A body's deposit of one is drawn a band of rows at a time (/datum/dirt_canvas_field/body).
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define, or null for mess.
 */
/proc/dirt_coverage_cause(cause)
	return cause == DIRT_CAUSE_PLUNGE || cause == DIRT_CAUSE_BLAST || cause == DIRT_CAUSE_DOUSE

/**
 * Tells the coat its material's light and glossy flags, and whether it's on bare skin, before its rows are bound
 * (/datum/dirt_canvas_field/body).
 *
 * Arguments:
 * - material: The /datum/dirt_material it's made of, or null.
 * - on_skin: Whether it's drawn on bare skin.
 */
/datum/dirt_feature/coverage/proc/set_material(datum/dirt_material/material, on_skin)
	var/material_flags = material?.flags
	light = !!(material_flags & DIRT_MATERIAL_LIGHT)
	glossy = !!(material_flags & DIRT_MATERIAL_GLOSSY)
	src.on_skin = on_skin

/**
 * Works out the coat on every pixel of some rows of the surface, the margin's too, by at(), and adds it to
 * drawn_pixels. Each pixel is worked out alone. So binding the rows a band at a time from the top gives what binding
 * every row at once gives, in the same order. A body field binds them that way (/datum/dirt_canvas_field/body).
 *
 * Arguments:
 * - surface: The view's surface.
 * - first_row: The first row, from 0.
 * - last_row: The last row.
 * - samples: The field's samples (/datum/dirt_canvas_field/var/samples), the noise its levels share.
 */
/datum/dirt_feature/coverage/proc/bind_rows(datum/dirt_surface/surface, first_row, last_row, alist/samples)
	drawn_pixels ||= alist()
	var/list/flags_of = surface.flags_of
	var/list/theta_of = surface.theta_of
	var/list/height_of = surface.height_of
	var/width = surface.width
	for(var/index in first_row * width + 1 to (last_row + 1) * width)
		var/limb = DIRT_PIXEL_LIMB(flags_of[index])
		if(!limb)
			continue
		var/row = floor((index - 1) / width)
		var/thickness = at(index - 1 - row * width, row, limb, theta_of[index], height_of[index], index, samples)
		if(thickness)
			drawn_pixels[index] = thickness

/**
 * Returns how thick the coat lies on a pixel of the surface.
 *
 * Arguments:
 * - column, row: The pixel, from the left and from the top, from 0.
 * - limb: Its DIRT_LIMB_* define.
 * - theta: Its theta.
 * - along: Its h, its height along the limb.
 * - index: Its index.
 * - samples: The field's samples (/datum/dirt_canvas_field/var/samples).
 */
/datum/dirt_feature/coverage/proc/at(column, row, limb, theta, along, index, alist/samples)
	return 0

/**
 * Returns where the wet coat catches the light: its draws' shine points, each list(pixels across, pixels up).
 */
/datum/dirt_feature/coverage/proc/shine_points()
	RETURN_TYPE(/list)
	return null

/**
 * A plunge or a blast over the body.
 */
/datum/dirt_feature/coverage/cover
	/// Its draws, from dirt_cover_draws().
	var/datum/dirt_cover_draws/draws

/**
 * Starts a plunge or a blast.
 *
 * Arguments:
 * - cause: DIRT_CAUSE_PLUNGE or DIRT_CAUSE_BLAST.
 * - level: Its level, 1 to 3.
 * - draws: Its draws, from dirt_cover_draws().
 */
/datum/dirt_feature/coverage/cover/New(cause, level, datum/dirt_cover_draws/draws)
	. = ..(cause, level)
	src.draws = draws

/**
 * Returns the field's coat, clumped for a light material. On bare skin a blast's body tone breaks up with noise,
 * because a uniform near-black front reads as a tank top. A 5x5 face can't carry the coat, because the body tone under
 * clean eyes reads as a beard. So the head, and the torso over its wandering collar, take film at most. The face takes
 * its veil and the stamps' smudges.
 */
/datum/dirt_feature/coverage/cover/at(column, row, limb, theta, along, index, alist/samples)
	var/mob_x = column - 15.5
	var/up = 31 - row
	var/thickness
	if(cause == DIRT_CAUSE_PLUNGE)
		thickness = dirt_plunge_thickness(mob_x, up, level, draws, light, glossy, on_skin, samples, index)
	else
		thickness = dirt_blast_thickness(mob_x, up, dirt_facing_amount(theta, draws.facing), level, draws, light, samples, index)
	if(light && thickness > 0)
		thickness = dirt_light_cover(thickness, column, row, draws.seed, up > 22, samples, index)
	if(on_skin && cause == DIRT_CAUSE_BLAST && thickness == DIRT_BODY_T && dirt_field_spread_noise(samples, "break", index, column, row, draws.seed + 61, 2.6) < 0.35)
		thickness = DIRT_FILM_T
	if(limb == DIRT_LIMB_HEAD || (limb == DIRT_LIMB_TORSO && along > dirt_cover_collar(column, draws.seed, samples)))
		return min(thickness, DIRT_FILM_T)
	return thickness

/// Returns its draws' shine points.
/datum/dirt_feature/coverage/cover/shine_points()
	return draws.shine

/**
 * A douse over the body: each column's top edge is read from the body's own pixels, as gravity is down in every view.
 */
/datum/dirt_feature/coverage/douse
	/// Its draws, from dirt_douse_draws().
	var/datum/dirt_douse_draws/draws
	/// Each column's top body row, indexed by column + 1, or null where the column has none. It's set as the first rows
	/// are bound (bind_rows()) and kept until the douse is unbound (unbind()).
	var/list/tops
	/// The columns of a mouth in the view it's drawn on, set with `tops`.
	var/list/mouth_columns

/**
 * Starts a douse.
 *
 * Arguments:
 * - level: Its level, 1 to 3.
 * - draws: Its draws, from dirt_douse_draws().
 */
/datum/dirt_feature/coverage/douse/New(level, datum/dirt_douse_draws/draws)
	. = ..(DIRT_CAUSE_DOUSE, level)
	src.draws = draws

/**
 * Reads each column's top body row from the whole surface, and the view's mouth columns, as its first rows are bound.
 * The mouth columns apply to any head, not only a human's.
 */
/datum/dirt_feature/coverage/douse/bind_rows(datum/dirt_surface/surface, first_row, last_row, alist/samples)
	if(tops)
		return ..()
	// the columns of the mouth's pixels, as a human head's guard has them (dirt_mouth_pixels())
	mouth_columns = list()
	for(var/list/spot as anything in dirt_mouth_pixels(surface.direction))
		mouth_columns |= spot[1]
	var/width = surface.width
	tops = new /list(width)
	var/list/flags_of = surface.flags_of
	// row-major, so a column's first body pixel is its top
	for(var/index in 1 to length(flags_of))
		if(!DIRT_PIXEL_ZONE(flags_of[index]))
			continue
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		if(isnull(tops[column + 1]))
			tops[column + 1] = row
	..()

/**
 * Frees the douse for another view. Its tops and mouth columns go with its pixels, because they're read from the view
 * it's bound on.
 */
/datum/dirt_feature/coverage/douse/unbind()
	..()
	tops = null
	mouth_columns = null

/**
 * Returns the douse under its column's top edge, and the run-off on the torso. It's film at most over the torso's
 * wandering collar, and clumped for a light material. On a face the cap is a veil, film at most, but a stream down the
 * face stays dark, except on the mouth's columns.
 */
/datum/dirt_feature/coverage/douse/at(column, row, limb, theta, along, index, alist/samples)
	var/top = tops[column + 1]
	if(isnull(top))
		return 0
	var/mob_x = column - 15.5
	var/up = 31 - row
	var/depth = row - top
	var/thickness = max(dirt_douse_thickness(mob_x, depth, up, level, draws, light, samples, index), dirt_runoff(limb, theta, along, mob_x, level, draws, samples))
	if(limb == DIRT_LIMB_TORSO && along > dirt_cover_collar(column, draws.seed, samples))
		thickness = min(thickness, DIRT_FILM_T)
	if(light && thickness > 0)
		thickness = dirt_light_cover(thickness, column, row, draws.seed, up > 22, samples, index)
	if(limb != DIRT_LIMB_HEAD || thickness <= DIRT_FILM_T)
		return thickness
	if(!(column in mouth_columns))
		var/cap = dirt_douse_cap(mob_x, level, draws, samples)
		if(depth > cap && dirt_douse_streams(mob_x, depth - cap, up, level, draws, samples) >= DIRT_BODY_T)
			return thickness
	return DIRT_FILM_T

/// Returns its draws' shine points.
/datum/dirt_feature/coverage/douse/shine_points()
	return draws.shine

/**
 * Returns a plunge's features, for a body that fell or waded in: knee-deep, then chest-deep, then over the head. At
 * level 3 it smudges the cheeks too.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's random stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_plunge(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/features = list(new /datum/dirt_feature/coverage/cover(DIRT_CAUSE_PLUNGE, level, dirt_cover_draws(rng)))
	if(level >= 3)
		features += new /datum/dirt_feature/stamps(side, 3, alist(), 2, TRUE)
	return features

/**
 * Returns a blast's features, for a body caught in an explosion or a cloud: the side facing it, then everything. From
 * level 2 the face is smudged whichever way the blast came, as every facing it draws is within 60 degrees of the front.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_blast(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/datum/dirt_cover_draws/draws = dirt_cover_draws(rng)
	var/list/features = list(new /datum/dirt_feature/coverage/cover(DIRT_CAUSE_BLAST, level, draws))
	if(level >= 2)
		features += new /datum/dirt_feature/stamps(side, level, alist(), level >= 3 ? 2 : 0, level >= 3)
	return features

/**
 * Returns a douse's features, poured over from above: the head and shoulders, then streams down to the feet.
 * At level 3 it smudges the cheeks too.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's random stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_douse(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/features = list(new /datum/dirt_feature/coverage/douse(level, dirt_douse_draws(rng)))
	if(level >= 3)
		features += new /datum/dirt_feature/stamps(side, 3, alist(), 2, TRUE)
	return features
