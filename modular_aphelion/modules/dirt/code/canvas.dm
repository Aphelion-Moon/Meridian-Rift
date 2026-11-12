// The canvas generator draws dirt for what isn't the template body: taur bodies, tails, wings, ears, horns and hair.
// Its fields lie in mob space, in pixels across from the tile's middle and up from its floor. So every canvas size
// samples one field through its own offset (dirt_canvases()), and a tail's mud line meets the legs'. The game clips
// each canvas to the real sprite, so the field never needs to know the shape. Along the body in profile, front is +.
// Facing south the viewer sees the front end, and facing north the back end.

/// How many pixels a piece of a mask job draws of a canvas field (dirt_canvas_field_band()): 8 rows of a tile, or 4
/// of the taur canvas. A plunge on the 64x32 canvas takes up to a measured 15.6 ms a piece (about 61 us a pixel a
/// level). A douse draws that many of its shape's pixels a piece, at up to a measured 17.9 ms (about 70 us a pixel a
/// level). A taur's coat draws that many of its body's pixels a piece (/datum/dirt_canvas_field/taur_coat).
/// A plunge, a blast or a douse on a body's template binds 8 of its rows a piece (/datum/dirt_canvas_field/body).
/// That takes up to a measured 16.4 ms for a level 3 douse. A painted plunge's last band at level 1 or 2 takes up to
/// about 35 ms (27.4-35.3 measured) in the first direction its job draws. That band builds its design's shown points
/// (dirt_painted_near()) and draws the design (dirt_finish_deposit()). Later directions read the points back.
#define DIRT_FIELD_BAND_PIXELS 256

/**
 * Returns each canvas dirt is drawn on besides the body's: alist(DIRT_CANVAS_* define = list(width, height, how far its
 * left edge sits from the tile's, how far its bottom edge sits over the tile's floor)). Wide sprites are centred on the
 * tile (center_image()). The 64x32 taur sheet sits 16 px left. The 45x34 wings sit 7 px left and 1 down, centred by
 * their sheet's 46 px dimension_x. You should NEVER modify it.
 */
/proc/dirt_canvases()
	RETURN_TYPE(/alist)
	var/static/alist/canvases = alist(
		DIRT_CANVAS_TILE = list(32, 32, 0, 0),
		DIRT_CANVAS_TALL = list(32, 48, 0, 0),
		DIRT_CANVAS_WINGS = list(45, 34, -7, -1),
		DIRT_CANVAS_TAUR = list(64, 32, -16, 0),
	)
	return canvases

/**
 * Returns the canvas a kind of shape's sprite is drawn on.
 *
 * Arguments:
 * - kind: A DIRT_SHAPE_* define.
 */
/proc/dirt_shape_canvas(kind)
	switch(kind)
		if(DIRT_SHAPE_TAUR)
			return DIRT_CANVAS_TAUR
		if(DIRT_SHAPE_WINGS)
			return DIRT_CANVAS_WINGS
	return DIRT_CANVAS_TILE

/**
 * Every pixel of one canvas in one direction, mapped to mob space, as a surface that dirt_halo() reads. Each pixel lies
 * on it, flagged as the torso's, a limb nothing on a canvas reads. No pixel is its rim, and no face guards any.
 */
/datum/dirt_canvas_view
	parent_type = /datum/dirt_surface
	/// The DIRT_CANVAS_* define it shows.
	var/canvas
	/// How far the canvas's left edge sits from the tile's, in pixels: negative to its left.
	var/pixel_w = 0
	/// How far its bottom edge sits over the tile's floor.
	var/pixel_z = 0

/**
 * Maps every pixel of a canvas. It isn't a body's surface, so a body surface's New() isn't run.
 *
 * Arguments:
 * - canvas: A DIRT_CANVAS_* define.
 * - direction: The direction it's seen from.
 */
/datum/dirt_canvas_view/New(canvas, direction)
	src.canvas = canvas
	src.direction = direction
	var/list/size = dirt_canvases()[canvas]
	width = size[1]
	height = size[2]
	pixel_w = size[3]
	pixel_z = size[4]
	flags_of = new /list(width * height)
	for(var/index in 1 to width * height)
		flags_of[index] = DIRT_LIMB_TORSO
	face_guard = alist()
	eye_soft = alist()

/**
 * Returns how many pixels across from the tile's middle a column lies.
 *
 * Arguments:
 * - column: The column, from 0.
 */
/datum/dirt_canvas_view/proc/mob_x(column)
	return column + pixel_w - 15.5

/**
 * Returns how many pixels up from the tile's floor a row lies.
 *
 * Arguments:
 * - row: The row, from 0 at the top.
 */
/datum/dirt_canvas_view/proc/up(row)
	return height - 1 - row + pixel_z

/**
 * Returns the theta seen at a point, with 0 at the body's front as on a body's limbs. Facing south it's the front, and
 * facing north the back. In profile it runs from the front end (0) through the near side to the back end (180).
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 */
/datum/dirt_canvas_view/proc/theta(mob_x)
	if(direction == SOUTH)
		return 0
	if(direction == NORTH)
		return 180
	var/sign = direction == EAST ? 1 : -1
	var/reach = clamp(sign * mob_x / 16, -1, 1)
	return (90 - reach * 90) * sign

/**
 * Returns how far along the body a point lies, with the front +. In profile it's how far across the view the point
 * lies. Facing south it's the front end (12), and facing north the back end (-12).
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 */
/datum/dirt_canvas_view/proc/along(mob_x)
	switch(direction)
		if(EAST)
			return mob_x
		if(WEST)
			return -mob_x
		if(SOUTH)
			return 12
	return -12

/**
 * Returns how far across the body a point lies: 0 in profile, mob_x facing south, and mob_x mirrored facing north.
 *
 * Arguments:
 * - mob_x: Pixels across from the tile's middle.
 */
/datum/dirt_canvas_view/proc/lateral(mob_x)
	switch(direction)
		if(SOUTH)
			return mob_x
		if(NORTH)
			return -mob_x
	return 0

/**
 * Returns a canvas's view in one direction, made the first time it's asked for. You should NEVER modify it.
 *
 * Arguments:
 * - canvas: A DIRT_CANVAS_* define.
 * - direction: The direction.
 */
/proc/dirt_canvas_view(canvas, direction)
	RETURN_TYPE(/datum/dirt_canvas_view)
	var/static/alist/views = alist()
	var/key = "[canvas]|[direction]"
	var/datum/dirt_canvas_view/view = views[key]
	if(!view)
		view = new(canvas, direction)
		views[key] = view
	return view

/**
 * One mark of a canvas cause. It gives how thick it lies at a point of mob space, from 0 (nothing) to 1.
 */
/datum/dirt_canvas_feature

/**
 * Returns how thick the mark lies at a point.
 *
 * Arguments:
 * - view: The canvas's view.
 * - mob_x: Pixels across from the tile's middle.
 * - up: Pixels up from the floor.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples), or null for a mark that samples no noise.
 * - index: The pixel's index on the view, which the samples are kept under.
 */
/datum/dirt_canvas_feature/proc/thickness(datum/dirt_canvas_view/view, mob_x, up, alist/samples, index)
	return 0

/**
 * Mud or dust up from the floor. It's solid where it meets the floor, then the body tone up to a jagged line. The line
 * tilts along the body and drags up in one place, its tongue. Film follows under the line, haze lies just over it, and
 * a film window or two break the body tone.
 */
/datum/dirt_canvas_feature/ground_coat
	/// The line's height over the floor at the body's middle.
	var/top
	/// The height up to which it lies solid, from the floor.
	var/solid
	/// How far the line climbs from the body's middle to 16 px along it.
	var/tilt
	/// Where the line drags up the body, list(along, across, how much higher, how wide), or null.
	var/list/tongue
	/// How many pixels of film follow under the line.
	var/film
	/// The film windows, each list(pixels across, pixels up).
	var/list/windows
	/// alist(pixels across = the line's height there), each worked out the first time its column asks. A feature is
	/// made for one level of one field, so the list belongs to one view.
	var/alist/line_at

/**
 * Arguments:
 * - top, solid, tilt, tongue, film, windows: Its vars of the same names.
 */
/datum/dirt_canvas_feature/ground_coat/New(top, solid, tilt, list/tongue, film, list/windows)
	. = ..()
	src.top = top
	src.solid = solid
	src.tilt = tilt
	src.tongue = tongue
	src.film = film
	src.windows = windows

/**
 * Returns the line's height over the floor at a point of the body. Facing south or north, the tilt along the body is
 * the same everywhere, so the line tilts sideways and jags instead. The jag depends only on the point's cell across,
 * so its field samples it once a cell.
 *
 * Arguments:
 * - along: How far along the body, front +.
 * - lateral: How far across it.
 * - samples: Its field's samples (/datum/dirt_canvas_field/var/samples).
 */
/datum/dirt_canvas_feature/ground_coat/proc/line(along, lateral, alist/samples)
	var/height = top + tilt * along / 16
	if(abs(along) == 12)
		height += tilt * lateral / 10
		var/run = floor((lateral + 32) / 2.5)
		height += (dirt_field_noise_hash(samples, "ground line", run, run, 0, 577) - 0.5) * 2.6
	if(tongue)
		var/across = along - tongue[1]
		var/down = lateral - tongue[2]
		var/distance = sqrt(across * across + down * down)
		height += tongue[3] * min(1, max(0, 1 - distance / tongue[4]) * 1.6)
	return height

/// Returns solid up to the solid height, and haze just over the line. Under the line it's film in its first pixels and
/// the windows, and the body tone below.
/datum/dirt_canvas_feature/ground_coat/thickness(datum/dirt_canvas_view/view, mob_x, up, alist/samples, index)
	if(up <= solid)
		return 1
	line_at ||= alist()
	var/height = line_at[mob_x]
	if(isnull(height))
		height = line(view.along(mob_x), view.lateral(mob_x), samples)
		line_at[mob_x] = height
	var/depth = height - up
	if(depth < -1.6)
		return 0
	if(depth < 0)
		return DIRT_HAZE_T
	if(depth < film)
		return DIRT_FILM_T
	for(var/list/window as anything in windows)
		var/across = mob_x - window[1]
		var/down = (up - window[2]) * 0.8
		if(sqrt(across * across + down * down) < 0.75)
			return DIRT_FILM_T
	return DIRT_BODY_T

/**
 * One kick-up speck over a ground coat: a pixel of the body tone, or a 1x2 film drip, placed after the coats. In
 * profile it lies along the body. Facing south only the specks at the front show, and facing north those at the back.
 */
/datum/dirt_canvas_feature/ground_speck
	/// How far along the body, front +.
	var/along
	/// How far across it.
	var/lateral
	/// Its height over the floor.
	var/up_at
	/// Whether it's a drip.
	var/drip

/**
 * Arguments:
 * - along, lateral, up_at, drip: Its vars of the same names.
 */
/datum/dirt_canvas_feature/ground_speck/New(along, lateral, up_at, drip)
	. = ..()
	src.along = along
	src.lateral = lateral
	src.up_at = up_at
	src.drip = drip

/**
 * Returns where across the view the speck lies, in pixels across from the tile's middle, or null where the view
 * doesn't show it.
 *
 * Arguments:
 * - direction: The view's direction.
 */
/datum/dirt_canvas_feature/ground_speck/proc/place(direction)
	switch(direction)
		if(EAST)
			return along
		if(WEST)
			return -along
		if(SOUTH)
			return along < 0 ? null : lateral
	return along > 0 ? null : -lateral

/// Returns, where the view shows the speck, the body tone within 0.6 px of it. A drip draws film instead, a pixel
/// across and down to a pixel under it.
/datum/dirt_canvas_feature/ground_speck/thickness(datum/dirt_canvas_view/view, mob_x, up)
	var/across_at = place(view.direction)
	if(isnull(across_at))
		return 0
	var/across = mob_x - across_at
	var/down = up - up_at
	if(drip)
		return (abs(across) < 0.55 && -1.05 < down && down < 0.55) ? DIRT_FILM_T : 0
	return sqrt(across * across + down * down) < 0.6 ? DIRT_BODY_T : 0

/**
 * Returns the first pixel, in row-major order, where the speck lies thick enough for film, or null. It lies within
 * 0.6 px across and from 1.05 px under to 0.6 px over its height. So only the rows and columns round there are tried.
 *
 * Arguments:
 * - view: The canvas's view.
 */
/datum/dirt_canvas_feature/ground_speck/proc/first_pixel(datum/dirt_canvas_view/view)
	var/across_at = place(view.direction)
	if(isnull(across_at))
		return null
	var/column_at = across_at + 15.5 - view.pixel_w
	var/row_at = view.height - 1 + view.pixel_z - up_at
	for(var/row in max(0, floor(row_at - 2)) to min(view.height - 1, ceil(row_at + 2)))
		var/up = view.up(row)
		for(var/column in max(0, floor(column_at - 1)) to min(view.width - 1, ceil(column_at + 1)))
			if(thickness(view, view.mob_x(column), up) >= DIRT_THRESHOLD_FILM)
				return row * view.width + column + 1
	return null

/**
 * Worn or sooty patches: film where noise passes a threshold set by the density, and the body tone where it's densest.
 * The reference generator's patches keep to a height band that covers every canvas.
 */
/datum/dirt_canvas_feature/patches
	/// How much they cover, from 0 to 1.
	var/density
	/// The noise's seed, a whole number.
	var/seed
	/// The noise's scale, in pixels.
	var/scale

/**
 * Arguments:
 * - density, seed, scale: Its vars of the same names.
 */
/datum/dirt_canvas_feature/patches/New(density, seed, scale = 3)
	. = ..()
	src.density = density
	src.seed = seed
	src.scale = scale

/// Returns film where the noise passes its density, and the body tone where it's densest. The noise doesn't depend on
/// the level, so its field samples it once.
/datum/dirt_canvas_feature/patches/thickness(datum/dirt_canvas_view/view, mob_x, up, alist/samples, index)
	var/noise = dirt_field_spread_noise(samples, "patches", index, mob_x, up, seed, scale)
	if(noise > 1 - density)
		return noise > 1 - density * 0.45 ? DIRT_BODY_T : DIRT_FILM_T
	return 0

/**
 * A plunge's or a blast's coat, head to toe at level 3, from the body's own field. It samples the same random draws in
 * mob space, so the lines meet. A light material clumps where its noise marks a point as facing up.
 */
/datum/dirt_canvas_feature/cover_field
	/// DIRT_CAUSE_PLUNGE or DIRT_CAUSE_BLAST.
	var/cause
	/// Its level, 1 to 3.
	var/level
	/// Its draws, from dirt_cover_draws().
	var/datum/dirt_cover_draws/draws
	/// Whether its material is light (DIRT_MATERIAL_LIGHT), set by the rasteriser.
	var/light = FALSE
	/// Whether its material is glossy (DIRT_MATERIAL_GLOSSY), set by the rasteriser.
	var/glossy = FALSE
	/// For a blast, alist(pixels across = how squarely a point there faces it), each worked out the first time its
	/// column asks. A feature is made for one level of one field, so the list belongs to one view.
	var/alist/facing_at

/**
 * Arguments:
 * - cause, level, draws: Its vars of the same names.
 */
/datum/dirt_canvas_feature/cover_field/New(cause, level, datum/dirt_cover_draws/draws)
	. = ..()
	src.cause = cause
	src.level = level
	src.draws = draws

/// Returns the plunge's or the blast's own thickness at the point, clumped for a light material where its noise marks
/// it as facing up. That noise doesn't depend on the level, so its field samples it once.
/datum/dirt_canvas_feature/cover_field/thickness(datum/dirt_canvas_view/view, mob_x, up, alist/samples, index)
	var/thickness
	if(cause == DIRT_CAUSE_PLUNGE)
		thickness = dirt_plunge_thickness(mob_x, up, level, draws, light, glossy, FALSE, samples, index)
	else
		facing_at ||= alist()
		var/facing = facing_at[mob_x]
		if(isnull(facing))
			facing = dirt_facing_amount(view.theta(mob_x), draws.facing)
			facing_at[mob_x] = facing
		thickness = dirt_blast_thickness(mob_x, up, facing, level, draws, light, samples, index)
	if(light && thickness > 0)
		thickness = dirt_light_cover(thickness, mob_x, up, draws.seed, dirt_field_spread_noise(samples, "light top", index, mob_x, up, draws.seed + 43, 3) > 0.72, samples, index)
	return thickness

/**
 * Patches broken up by noise on whatever faced an impact, densest where it faced it square on: a fall's contact, or
 * a splash's spatter.
 */
/datum/dirt_canvas_feature/facing_patches
	/// The theta of the impact.
	var/facing
	/// How much they cover square on, from 0 to 1.
	var/density
	/// The noise's seed, a whole number.
	var/seed
	/// The noise's scale, in pixels.
	var/scale
	/// alist(pixels across = how much it covers there), each worked out the first time its column asks. A feature is
	/// made for one level of one field, so the list belongs to one view.
	var/alist/faced_at

/**
 * Arguments:
 * - facing, density, seed, scale: Its vars of the same names.
 */
/datum/dirt_canvas_feature/facing_patches/New(facing, density, seed, scale = 3)
	. = ..()
	src.facing = facing
	src.density = density
	src.seed = seed
	src.scale = scale

/// Returns film where the noise passes its density, scaled by how squarely the point faced the impact, and the body
/// tone where it's densest. The noise doesn't depend on the level, so its field samples it once.
/datum/dirt_canvas_feature/facing_patches/thickness(datum/dirt_canvas_view/view, mob_x, up, alist/samples, index)
	faced_at ||= alist()
	var/faced = faced_at[mob_x]
	if(isnull(faced))
		faced = density * dirt_facing_amount(view.theta(mob_x), facing) ** 1.5
		faced_at[mob_x] = faced
	var/noise = dirt_field_spread_noise(samples, "facing patches", index, mob_x, up, seed, scale)
	if(noise > 1 - faced)
		return noise > 1 - faced * 0.55 ? DIRT_BODY_T : DIRT_FILM_T
	return 0

/**
 * Returns a ground coat and the kick-up specks over it, at one level. Every random draw is made at every level, so
 * the levels nest.
 *
 * Arguments:
 * - rng: The cause's random stream.
 * - level: 1 to 3.
 * - heights: The line's height at each level.
 * - solid: How high it lies solid at each level.
 * - speck_counts: How many specks show at each level.
 * - films: How many pixels of film follow the line at each level.
 */
/proc/dirt_canvas_ground(datum/dirt_random/rng, level, list/heights, list/solid, list/speck_counts, list/films = list(1, 2, 2))
	RETURN_TYPE(/list)
	var/tilt_sign = rng.choose(list(-1, 1))
	var/tilt = tilt_sign * rng.uniform(1.6, 2.4)
	var/tongue_along = rng.uniform(-14, 14)
	var/tongue_across = rng.uniform(-8, 8)
	var/tongue_extra = rng.uniform(2, 3)
	var/list/tongue = list(tongue_along, tongue_across, tongue_extra, rng.uniform(2, 3))
	var/list/window_draws = list()
	for(var/window_number in 1 to 3)
		var/across = rng.uniform(-12, 12)
		window_draws += list(list(across, rng.uniform(0.35, 0.7)))
	var/top = heights[level] + rng.uniform(-0.5, 0.5)
	var/list/windows = list()
	if(level >= 2)
		for(var/window_number in 1 to level)
			var/list/window = window_draws[window_number]
			windows += list(list(window[1], window[2] * top))
	var/list/features = list(new /datum/dirt_canvas_feature/ground_coat(top, solid[level], tilt, level >= 2 ? tongue : null, films[level], windows))
	for(var/speck_number in 1 to 10)
		// mostly the back end
		var/along = rng.random() < 0.7 ? rng.uniform(-16, 4) : rng.uniform(-16, 16)
		var/lateral = rng.uniform(-10, 10)
		var/up_at = top + rng.uniform(1.5, 4)
		var/drip = rng.random() < 0.4
		if(speck_number <= speck_counts[level])
			features += new /datum/dirt_canvas_feature/ground_speck(along, lateral, up_at, drip)
	return features

/**
 * Returns a canvas cause's features at one level, or null for a cause the canvas doesn't draw. Crawling draws as
 * walking does, and kneeling and machine work wear as wear does.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - level: 1 to 3, or to 4 for smoke.
 * - rng: Its random stream. A plunge, a blast and a fall use the body's own, so the canvas meets the body.
 * - side: The mob's dirtier side, 1 or -1. A fall onto the side lands on it.
 */
/proc/dirt_canvas_features(cause, level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	switch(cause)
		if(DIRT_CAUSE_WALK, DIRT_CAUSE_CRAWL)
			var/list/heights = list(1.6, rng.uniform(4, 5), rng.uniform(6.5, 9))
			return dirt_canvas_ground(rng, level, heights, list(0, 0.4, 0.8), list(0, 3, 6))
		if(DIRT_CAUSE_DUST)
			var/list/heights = list(2, rng.uniform(4, 5), rng.uniform(6, 8))
			return dirt_canvas_ground(rng, level, heights, list(0.3, 0.6, 0.9), list(0, 0, 0))
		if(DIRT_CAUSE_WEAR, DIRT_CAUSE_KNEEL, DIRT_CAUSE_MACHINE)
			var/static/list/wear_densities = list(0, 0.1, 0.18, 0.26)
			var/static/list/wear_tops = list(0.5, 1, 1.5)
			return list(new /datum/dirt_canvas_feature/patches(wear_densities[level + 1], rng.randrange(65536)), new /datum/dirt_canvas_feature/ground_coat(wear_tops[level], 0, 0, null, 1, list()))
		if(DIRT_CAUSE_SMOKE)
			var/static/list/smoke_densities = list(0, 0.12, 0.22, 0.32, 0.42)
			return list(new /datum/dirt_canvas_feature/patches(smoke_densities[level + 1], rng.randrange(65536), 3.6))
		if(DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST)
			return list(new /datum/dirt_canvas_feature/cover_field(cause, level, dirt_cover_draws(rng)))
		if(DIRT_CAUSE_FALL)
			// the impact's random draw comes first, as in the body's fall
			var/static/list/fall_densities = list(0.35, 0.55, 0.75)
			var/roll = rng.random()
			var/impact = roll < 0.6 ? DIRT_THETA_FRONT : (roll < 0.85 ? DIRT_THETA_BACK : side * 90)
			return list(new /datum/dirt_canvas_feature/facing_patches(impact, fall_densities[level], rng.randrange(65536)))
		if(DIRT_CAUSE_SPLASH)
			var/static/list/splash_densities = list(0.12, 0.2, 0.3)
			var/facing = rng.choose(list(DIRT_THETA_FRONT, 60, -60))
			return list(new /datum/dirt_canvas_feature/facing_patches(facing, splash_densities[level], rng.randrange(65536), 1.4))
	return null

/**
 * Returns a thickness's role: haze for exactly DIRT_HAZE_T, else core or body by their thresholds, and film below.
 *
 * Arguments:
 * - thickness: At least DIRT_THRESHOLD_FILM, or DIRT_HAZE_T.
 */
/proc/dirt_thickness_role(thickness)
	if(thickness == DIRT_HAZE_T)
		return DIRT_ROLE_HAZE
	if(thickness >= DIRT_THRESHOLD_CORE)
		return DIRT_ROLE_CORE
	return thickness >= DIRT_THRESHOLD_BODY ? DIRT_ROLE_BODY : DIRT_ROLE_FILM

/**
 * Returns a speck that doesn't read as a hard pixel, as alist(index = DIRT_ROLE_* define), on the canvas pixels it may
 * draw on. It's a film centre with a haze ring, or a drip that fades from film to haze as it runs down.
 *
 * Arguments:
 * - column, row: Its centre, from the left and from the top, from 0.
 * - drip: Whether it's a drip.
 * - width, height: The canvas's size.
 * - inside: alist(index = TRUE) on the pixels it may draw on, or null for the whole canvas.
 */
/proc/dirt_soft_speck(column, row, drip, width, height, alist/inside = null)
	RETURN_TYPE(/alist)
	// each list(columns right, rows down, DIRT_ROLE_* define)
	var/static/list/drip_shape = list(list(0, 0, DIRT_ROLE_FILM), list(0, 1, DIRT_ROLE_FILM), list(0, 2, DIRT_ROLE_HAZE), list(-1, 0, DIRT_ROLE_HAZE), list(1, 0, DIRT_ROLE_HAZE))
	var/static/list/dot_shape = list(list(0, 0, DIRT_ROLE_FILM), list(1, 0, DIRT_ROLE_HAZE), list(-1, 0, DIRT_ROLE_HAZE), list(0, 1, DIRT_ROLE_HAZE), list(0, -1, DIRT_ROLE_HAZE))
	var/alist/shape = alist()
	for(var/list/spot as anything in drip ? drip_shape : dot_shape)
		var/spot_column = column + spot[1]
		var/spot_row = row + spot[2]
		if(spot_column < 0 || spot_row < 0 || spot_column >= width || spot_row >= height)
			continue
		var/index = spot_row * width + spot_column + 1
		if(!inside || inside[index])
			shape[index] = spot[3]
	return shape

/**
 * Places a speck on a mask, changing it, and returns whether it went. It goes only where no pixel drawn so far touches
 * it outside its own pixels. Its rows and columns also have to be free of earlier specks, and it then takes them.
 *
 * Arguments:
 * - drawn: The mask, which it changes.
 * - shape: The speck, alist(index = DIRT_ROLE_* define), from dirt_soft_speck().
 * - used_rows: TRUE on each row a speck took, indexed by row + 1, which it changes.
 * - used_columns: TRUE on each column a speck took, indexed by column + 1, which it changes.
 */
/proc/dirt_place_speck(datum/dirt_pixels/drawn, alist/shape, list/used_rows, list/used_columns)
	if(!length(shape))
		return FALSE
	var/width = drawn.width
	var/list/roles = drawn.roles
	var/list/table = dirt_neighbour_table(width, drawn.height)
	for(var/index, role in shape)
		var/row = floor((index - 1) / width)
		if(used_rows[row + 1] || used_columns[index - row * width])
			return FALSE
		for(var/neighbour in table[index])
			if(roles[neighbour] && isnull(shape[neighbour]))
				return FALSE
	for(var/index, role in shape)
		drawn.put_index(index, role, 0.5)
		var/row = floor((index - 1) / width)
		used_rows[row + 1] = TRUE
		used_columns[index - row * width] = TRUE
	return TRUE

/**
 * Returns a canvas cause's coats among one level's features: every feature but the kick-up specks. A whole-body coat
 * is told its material's light and glossy flags first.
 *
 * Arguments:
 * - features: The level's features (dirt_canvas_features()).
 * - material: The /datum/dirt_material it's made of.
 */
/proc/dirt_canvas_coats(list/features, datum/dirt_material/material)
	RETURN_TYPE(/list)
	. = list()
	for(var/datum/dirt_canvas_feature/feature as anything in features)
		if(istype(feature, /datum/dirt_canvas_feature/ground_speck))
			continue
		. += feature
		if(istype(feature, /datum/dirt_canvas_feature/cover_field))
			var/datum/dirt_canvas_feature/cover_field/field = feature
			field.light = !!(material.flags & DIRT_MATERIAL_LIGHT)
			field.glossy = !!(material.flags & DIRT_MATERIAL_GLOSSY)

/**
 * Draws some rows of one level of a canvas cause. Each pixel takes the thickest of the coats. If there's only one coat,
 * its thickness is taken directly.
 *
 * Arguments:
 * - drawn: The level's pixels, which it draws on.
 * - coats: Its coats (dirt_canvas_coats()).
 * - view: The canvas's view.
 * - first_row, last_row: The first and last rows to draw, from 0 at the top.
 * - samples: The field's samples (/datum/dirt_canvas_field/var/samples), the noise its levels share.
 */
/proc/dirt_canvas_coat_rows(datum/dirt_pixels/drawn, list/coats, datum/dirt_canvas_view/view, first_row, last_row, alist/samples)
	var/width = view.width
	var/datum/dirt_canvas_feature/only_coat = length(coats) == 1 ? coats[1] : null
	// each column's mob_x, worked out once a call
	var/list/mob_x_of = new /list(width)
	for(var/column in 0 to width - 1)
		mob_x_of[column + 1] = view.mob_x(column)
	for(var/row in first_row to last_row)
		var/up = view.up(row)
		for(var/column in 0 to width - 1)
			var/mob_x = mob_x_of[column + 1]
			var/index = row * width + column + 1
			// a lone coat's taken directly, since a value under 0 draws nothing, like the loop's 0
			var/thickness = only_coat ? only_coat.thickness(view, mob_x, up, samples, index) : 0
			if(!only_coat)
				for(var/datum/dirt_canvas_feature/coat as anything in coats)
					var/value = coat.thickness(view, mob_x, up, samples, index)
					if(value > thickness)
						thickness = value
			if(thickness == DIRT_HAZE_T || thickness >= DIRT_THRESHOLD_FILM)
				drawn.put_index(index, dirt_thickness_role(thickness), thickness)

/**
 * Returns one level of a canvas cause on a whole canvas, once its coats' rows are drawn (dirt_canvas_coat_rows()): lone
 * pixels go (dirt_cleanup()), then the material's edge, halo or tide, and the kick-up specks (dirt_place_speck()). A
 * material's sheen draws nothing on a canvas, as it looks for a leg. Hair takes film unless a whole-body coat covers
 * it, and never core.
 *
 * Arguments:
 * - drawn: The level's pixels.
 * - features: The level's features (dirt_canvas_features()).
 * - material: The /datum/dirt_material it's made of.
 * - view: The canvas's view.
 * - surface_kind: DIRT_SURFACE_FUR, DIRT_SURFACE_CLOTH or DIRT_SURFACE_HAIR.
 */
/proc/dirt_canvas_finish_level(datum/dirt_pixels/drawn, list/features, datum/dirt_material/material, datum/dirt_canvas_view/view, surface_kind)
	RETURN_TYPE(/datum/dirt_pixels)
	var/width = view.width
	var/list/specks = list()
	var/covered = FALSE
	for(var/datum/dirt_canvas_feature/feature as anything in features)
		if(istype(feature, /datum/dirt_canvas_feature/ground_speck))
			specks += feature
		else if(istype(feature, /datum/dirt_canvas_feature/cover_field))
			covered = TRUE
	drawn = dirt_cleanup(drawn)
	switch(material.edge)
		if(DIRT_EDGE_HALO)
			drawn = dirt_halo(drawn, view)
		if(DIRT_EDGE_TIDE)
			drawn = dirt_tide(drawn)
	var/list/used_rows = new /list(view.height)
	var/list/used_columns = new /list(width)
	for(var/datum/dirt_canvas_feature/ground_speck/speck as anything in specks)
		var/start = speck.first_pixel(view)
		if(start)
			var/start_row = floor((start - 1) / width)
			dirt_place_speck(drawn, dirt_soft_speck(start - 1 - start_row * width, start_row, speck.drip, width, view.height), used_rows, used_columns)
	if(surface_kind == DIRT_SURFACE_HAIR)
		var/list/roles = drawn.roles
		for(var/index in 1 to length(roles))
			if(roles[index] == DIRT_ROLE_BODY || roles[index] == DIRT_ROLE_CORE)
				roles[index] = covered ? DIRT_ROLE_BODY : DIRT_ROLE_FILM
	return drawn

/**
 * Calls a drawing proc while drafting, as every general deposit is drawn. SSdirt.drafting is set and the noise lattice
 * emptied for it. Both are let go as the proc ends, well or in a runtime (dirt_end_drafting()). dirt_rasterise() draws
 * a deposit on a body through it. So do the canvas generator's entry procs when asked for outside a deposit's drawing.
 * So a tail, a wing, hair or a taur body draws the same random streams and noise as the body it meets. If it's called
 * while drafting, with neither a keeper nor a holder, it draws on the lattice already in use. A field's band is drawn
 * with the field as its keeper. The lattice its earlier bands sampled is put back as the band begins and taken back as
 * it ends. So a field drawn a band a piece hashes no point that drawing it whole wouldn't. A mask job drawing a deposit
 * is its holder, and keeps the lattice between the deposit's directions. A direction drawn, or a field's first band,
 * goes on from that lattice, and a field gives it back once done. A point's value is its hash's wherever it's kept, so
 * the numbers are the same.
 *
 * Arguments:
 * - proc_path: The entry proc.
 * - arguments: Its arguments.
 * - keeper: The field whose band it draws (dirt_canvas_field_band()), or null.
 * - holder: The mask job whose deposit it draws, or null.
 */
/proc/dirt_drafted(proc_path, list/arguments, datum/dirt_canvas_field/keeper = null, datum/dirt_mask_job/holder = null)
	if(SSdirt.drafting && !keeper && !holder)
		return call(proc_path)(arglist(arguments))
	var/was_drafting = SSdirt.drafting
	SSdirt.drafting = TRUE
	SSdirt.lattice.Cut()
	SSdirt.lattice_points = 0
	if(keeper?.lattice)
		SSdirt.lattice = keeper.lattice
		SSdirt.lattice_points = keeper.lattice_points
	else if(holder?.lattice)
		SSdirt.lattice = holder.lattice
		SSdirt.lattice_points = holder.lattice_points
		holder.lattice = null
		holder.lattice_points = 0
	try
		. = call(proc_path)(arglist(arguments))
	catch(var/exception/error)
		dirt_end_drafting(was_drafting, keeper, holder)
		throw error
	dirt_end_drafting(was_drafting, keeper, holder)

/**
 * Ends drafting a general deposit (dirt_drafted()). SSdirt.drafting goes back to what it was. The lattice the deposit
 * sampled goes back to the field whose band it was, until that field is done. After that it goes to the mask job
 * drawing the deposit. If neither takes it, it's let go.
 *
 * Arguments:
 * - was_drafting: SSdirt.drafting before it began.
 * - keeper: The field whose band it drew, or null.
 * - holder: The mask job whose deposit it drew, or null.
 */
/proc/dirt_end_drafting(was_drafting, datum/dirt_canvas_field/keeper = null, datum/dirt_mask_job/holder = null)
	SSdirt.drafting = was_drafting
	if(keeper && !keeper.done)
		keeper.lattice = SSdirt.lattice
		keeper.lattice_points = SSdirt.lattice_points
		SSdirt.lattice = alist()
	else
		if(keeper)
			keeper.lattice = null
			keeper.lattice_points = 0
		if(holder)
			holder.lattice = SSdirt.lattice
			holder.lattice_points = SSdirt.lattice_points
			SSdirt.lattice = alist()
	SSdirt.lattice.Cut()
	SSdirt.lattice_points = 0

/**
 * Returns a general deposit on a whole canvas in one direction, before a sprite clips it: levels 1 to `level`, each
 * from the cause's same draws, merged by role rank with the later level winning a tie. A plunge, a blast and a fall draw
 * from the body's own stream ("<cause>:<variant>"), so the canvas meets the body; other causes from
 * "canvas:<cause>:<variant>". Hair keeps to its crown (dirt_hair_crown()). Nothing for a cause the canvas doesn't draw.
 * Drawn drafting (dirt_drafted()), a level at a time by /datum/dirt_canvas_field, which a mask job draws a band at a
 * time.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3, smoke to 4; past it, its top level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - canvas: A DIRT_CANVAS_* define.
 * - direction: The direction.
 * - surface_kind: DIRT_SURFACE_FUR, DIRT_SURFACE_CLOTH (a taur suit's) or DIRT_SURFACE_HAIR.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_canvas_rasterise(cause, datum/dirt_material/material, level, variant, canvas, direction, surface_kind = DIRT_SURFACE_FUR, side = 1)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_canvas_rasterise), args.Copy())
#endif
	var/datum/dirt_canvas_field/field = new(cause, material, level, variant, canvas, direction, surface_kind, side)
	// a whole level each call
	for(var/each_level in 1 to field.level)
		if(field.draw_rows(field.view.height))
			break
	return surface_kind == DIRT_SURFACE_HAIR ? dirt_hair_crown(field) : field.merged

/**
 * Keeps a field drawn as hair to the hair's crown, once every level is drawn. At levels 1 and 2 it keeps only pixels
 * over 25 px above the floor, because an even film reads as a new hair colour. From level 3 it breaks them up with
 * noise. It changes the field's levels (/datum/dirt_canvas_field/var/merged) and returns them. Done twice, it changes
 * nothing more. Call it while drafting.
 *
 * Arguments:
 * - field: The field.
 */
/proc/dirt_hair_crown(datum/dirt_canvas_field/field)
	RETURN_TYPE(/datum/dirt_pixels)
	var/datum/dirt_pixels/merged = field.merged
	var/datum/dirt_canvas_view/view = field.view
	var/list/roles = merged.roles
	var/width = view.width
	for(var/index in 1 to length(roles))
		if(!roles[index])
			continue
		var/row = floor((index - 1) / width)
		if(field.level <= 2 ? view.up(row) <= 25 : dirt_spread_noise(index - 1 - row * width, row, 53, 2.5) <= 0.35)
			merged.put_index(index, null, null)
	return merged

/**
 * A general deposit's levels on a whole canvas in one direction, as dirt_canvas_rasterise() draws them before keeping
 * hair to its crown. It's drawn some rows at a time (draw_rows()). A mask job draws a field once, for all the
 * directions it serves (/datum/dirt_mask_job/proc/field_for()), a band a piece (dirt_canvas_field_band()). In each of
 * those directions the field is clipped to its shape, except on a taur body. Every field keeps the noise lattice its
 * bands sample until it's done (dirt_drafted()). A job's field goes on from its job's lattice and gives it back. It
 * also keeps the noise its levels share (samples), one table for a job's deposit in every direction. A field lives no
 * longer than the job drawing it.
 */
/datum/dirt_canvas_field
	/// A DIRT_CAUSE_* define.
	var/cause
	/// The /datum/dirt_material it's made of.
	var/datum/dirt_material/material
	/// Its top level, capped as the cause's.
	var/level
	/// The seed text of the random stream each level's features are drawn from.
	var/seed
	/// The canvas's view in the direction.
	var/datum/dirt_canvas_view/view
	/// DIRT_SURFACE_FUR, DIRT_SURFACE_CLOTH, DIRT_SURFACE_SKIN or DIRT_SURFACE_HAIR.
	var/surface_kind
	/// The mob's dirtier side, 1 or -1.
	var/side
	/// The level being drawn, from 1, or 0 before the first.
	var/drawing_level = 0
	/// That level's features (dirt_canvas_features()).
	var/list/features
	/// That level's coats (dirt_canvas_coats()).
	var/list/coats
	/// That level's pixels so far, or null between levels.
	var/datum/dirt_pixels/drawn
	/// That level's next row, from 0.
	var/next_row = 0
	/// The levels drawn so far, stacked. Once it's done, this is the whole field.
	var/datum/dirt_pixels/merged
	/// Whether every level is drawn.
	var/done = FALSE
	/// How many rows a band draws (dirt_field_band_rows()).
	var/band_rows
	/// The draft's noise lattice its bands sampled, as SSdirt.lattice holds it, DIRT_LATTICE_POINTS at most, or null
	/// before the first band and once it's done. It's put back for each band and taken back after (dirt_drafted()). A
	/// mask job's field takes its job's lattice at its first band, and gives it back once done
	/// (/datum/dirt_mask_job/var/lattice).
	var/alist/lattice
	/// How many points `lattice` holds.
	var/lattice_points = 0
	/// The noise its levels share, as alist(term = alist(position = value)). The first level that asks samples it
	/// (dirt_field_spread_noise()), and the later ones read it. A position is a pixel's index, or the one coordinate
	/// its term takes. A term's other arguments are the same at every level, drawn alike from the same stream or fixed.
	/// Every band of a field is drawn in one drafting state. So a kept value is what sampling again returns. A mask
	/// job's fields for one deposit share one table in every direction (/datum/dirt_mask_job/var/field_samples).
	/// They can share it, because a term's point and seed come from its position and the deposit's random draws,
	/// whichever way the field faces. It holds at most 5 values a pixel of its canvas, 10,240 for a taur's coat
	/// (about 0.7-1.0 MB, estimated). The field drops its reference once it's done.
	var/alist/samples

/**
 * Arguments:
 * - cause, material, level, variant, canvas, direction, surface_kind, side: As in dirt_canvas_rasterise().
 */
/datum/dirt_canvas_field/New(cause, datum/dirt_material/material, level, variant, canvas, direction, surface_kind, side)
	. = ..()
	src.cause = cause
	src.material = material
	// smoke goes to level 4 as on the body, but machine work stops at 3 as on the reference generator's canvas
	src.level = min(level, cause == DIRT_CAUSE_SMOKE ? dirt_cause_max_level(cause) : DIRT_DEPOSIT_MAX_LEVEL)
	var/shared = cause == DIRT_CAUSE_PLUNGE || cause == DIRT_CAUSE_BLAST || cause == DIRT_CAUSE_FALL
	seed = "[shared ? "" : "canvas:"][cause]:[num2text(variant, 12)]"
	view = dirt_canvas_view(canvas, direction)
	src.surface_kind = surface_kind
	src.side = side
	merged = new(view.width, view.height)
	band_rows = dirt_field_band_rows(view.width)
	samples = alist()

/**
 * Draws the field's next rows. As a level begins it makes the level's features and coats, then it draws its rows. Once
 * the last row is drawn, it adds the level's finish (dirt_canvas_finish_level()) and stacks the level on the ones
 * before, the later winning a tie. After the last level, its samples go. A cause the canvas doesn't draw ends the
 * field. Call it while drafting.
 *
 * Arguments:
 * - rows: The most rows to draw.
 *
 * Returns whether every level is drawn.
 */
/datum/dirt_canvas_field/proc/draw_rows(rows)
	if(done)
		return TRUE
	if(!drawn)
		features = dirt_canvas_features(cause, drawing_level + 1, dirt_general_stream(seed), side)
		if(!features)
			done = TRUE
			samples = null
			return TRUE
		drawing_level++
		coats = dirt_canvas_coats(features, material)
		drawn = new(view.width, view.height)
		next_row = 0
	var/last_row = min(next_row + rows, view.height) - 1
	dirt_canvas_coat_rows(drawn, coats, view, next_row, last_row, samples)
	next_row = last_row + 1
	if(next_row < view.height)
		return FALSE
	dirt_stack_level(merged, dirt_canvas_finish_level(drawn, features, material, view, surface_kind))
	drawn = null
	features = null
	coats = null
	done = drawing_level >= level
	if(done)
		samples = null
	return done

/**
 * Draws a band of a field's rows, DIRT_FIELD_BAND_PIXELS pixels' worth, or as many of its shape's pixels for a douse
 * or a taur's coat. It's one piece of a mask job, drawn while drafting. The field keeps the lattice its bands sample
 * (dirt_drafted()).
 *
 * Arguments:
 * - field: The field.
 * - holder: The mask job drawing it, or null. The first band goes on from its lattice, and the last gives it back.
 *
 * Returns whether every level is drawn.
 */
/proc/dirt_canvas_field_band(datum/dirt_canvas_field/field, datum/dirt_mask_job/holder = null)
	return dirt_drafted(GLOBAL_PROC_REF(dirt_draw_field_band), list(field), field, holder)

/**
 * Draws a band of a field's rows inside dirt_canvas_field_band()'s drafting.
 *
 * Arguments:
 * - field: The field.
 *
 * Returns whether every level is drawn.
 */
/proc/dirt_draw_field_band(datum/dirt_canvas_field/field)
	return field.draw_rows(field.band_rows)

/**
 * Returns how many rows of a canvas a band of its field draws (dirt_canvas_field_band()): as many as hold
 * DIRT_FIELD_BAND_PIXELS pixels, and one row at least.
 *
 * Arguments:
 * - width: The canvas's width.
 */
/proc/dirt_field_band_rows(width)
	return max(1, floor(DIRT_FIELD_BAND_PIXELS / width))

/**
 * Returns two octaves of value noise (dirt_spread_noise()) at a position, for one term of the noise a field's levels
 * share. It's sampled the first time it's asked for and kept in the field's samples, then read back. A term takes the
 * same seed and scale, and the same point at a position, wherever it's asked for.
 *
 * Arguments:
 * - samples: The field's samples (/datum/dirt_canvas_field/var/samples).
 * - term: The term's name.
 * - position: The pixel's index, or the one coordinate the term takes.
 * - sample_x, sample_y, seed, scale: As in dirt_spread_noise().
 */
/proc/dirt_field_spread_noise(alist/samples, term, position, sample_x, sample_y, seed, scale)
	var/alist/kept = samples[term]
	if(!kept)
		kept = alist()
		samples[term] = kept
	. = kept[position]
	if(isnull(.))
		. = dirt_spread_noise(sample_x, sample_y, seed, scale)
		kept[position] = .

/**
 * Returns a lattice point's noise value (dirt_noise_hash()) at a position, for one term of the noise a field's levels
 * share. It's kept as dirt_field_spread_noise() keeps its noise.
 *
 * Arguments:
 * - samples: The field's samples (/datum/dirt_canvas_field/var/samples).
 * - term: The term's name.
 * - position: The pixel's index, or the one coordinate the term takes.
 * - cell_x, cell_y, seed: As in dirt_noise_hash().
 */
/proc/dirt_field_noise_hash(alist/samples, term, position, cell_x, cell_y, seed)
	var/alist/kept = samples[term]
	if(!kept)
		kept = alist()
		samples[term] = kept
	. = kept[position]
	if(isnull(.))
		. = dirt_noise_hash(cell_x, cell_y, seed)
		kept[position] = .

/**
 * Returns the most pieces a mask job takes to draw one deposit's canvas fields on a canvas, a band a piece. That's its
 * rows at every level, smoke's four at most, in each direction. A douse takes no more, because each band draws that
 * many of its shape's pixels, level after level. Nor does a plunge, a blast or a douse on a body's template, on the
 * tile, at three levels (/datum/dirt_canvas_field/body). Nor does a taur's coat. Its view takes a piece. Then each
 * of three levels takes bands of its body's pixels, the canvas's at most, and a piece for its finish
 * (/datum/dirt_canvas_field/taur_coat).
 *
 * Arguments:
 * - canvas: A DIRT_CANVAS_* define.
 */
/proc/dirt_field_pieces(canvas)
	var/list/size = dirt_canvases()[canvas]
	return length(dirt_mask_directions()) * dirt_cause_max_level(DIRT_CAUSE_SMOKE) * ceil(size[2] / dirt_field_band_rows(size[1]))

/**
 * Keeps a mask to a shape's pixels, changing it, and returns it.
 *
 * Arguments:
 * - drawn: The mask, which it changes.
 * - mask: alist(index = TRUE) on the shape's pixels.
 */
/proc/dirt_clip_to_shape(datum/dirt_pixels/drawn, alist/mask)
	RETURN_TYPE(/datum/dirt_pixels)
	var/list/roles = drawn.roles
	for(var/index in drawn.drawn_indexes || dirt_index_range(length(roles)))
		if(roles[index] && !mask[index])
			drawn.put_index(index, null, null)
	return drawn

/**
 * Returns each column's top or bottom row of a shape's pixels, indexed by column + 1, null where it has none.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels.
 * - width: The canvas's width.
 * - lowest: Whether to take each column's bottom row rather than its top.
 */
/proc/dirt_shape_edges(alist/mask, width, lowest = FALSE)
	RETURN_TYPE(/list)
	var/list/edges = new /list(width)
	for(var/index in mask)
		var/row = floor((index - 1) / width)
		var/column = index - row * width
		if(isnull(edges[column]) || (lowest ? row > edges[column] : row < edges[column]))
			edges[column] = row
	return edges

/**
 * Returns smoke, wear or machine work on a tail or a wing, or kneeling on a tail. It draws film at a large scale (small
 * blotches read as a pinto pattern), from the "wing:<cause>:<variant>" stream. Smoke at level 3 and up also draws a
 * broken band along the top edge, where soot settles. It's drawn inside a canvas entry's drafting.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels.
 * - cause: A DIRT_CAUSE_* define.
 * - level: 1 to 4.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - top_band: Whether to draw the band along the top edge.
 * - canvas: The shape's DIRT_CANVAS_* define.
 */
/proc/dirt_sparse_film(alist/mask, cause, level, variant, top_band, canvas)
	RETURN_TYPE(/datum/dirt_pixels)
	var/static/list/densities = list(0, 0.1, 0.18, 0.26, 0.34)
	var/list/size = dirt_canvases()[canvas]
	var/width = size[1]
	var/datum/dirt_pixels/drawn = new(width, size[2])
	var/datum/dirt_random/rng = dirt_general_stream("wing:[cause]:[num2text(variant, 12)]")
	var/seed = rng.randrange(65536)
	var/density = densities[min(level, 4) + 1]
	for(var/index in mask)
		var/row = floor((index - 1) / width)
		if(dirt_spread_noise(index - 1 - row * width, row, seed, 6) > 1 - density)
			drawn.put_index(index, DIRT_ROLE_FILM, 0.4)
	if(!top_band)
		return drawn
	var/list/tops = dirt_shape_edges(mask, width)
	for(var/index in mask)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		if(row - tops[column + 1] <= 1 && !drawn.roles[index] && dirt_noise_hash(column, row, seed) < 0.6)
			drawn.put_index(index, DIRT_ROLE_FILM, 0.4)
	return drawn

/**
 * Returns a tail's dirt in one direction, the same in every direction. Ground dirt runs along the tail's own underside,
 * from the "tail:<cause>:<variant>" stream, thickest where the tail comes near the floor and fading up through it.
 * Smoke, wear, machine work and kneeling draw a sparse film (dirt_sparse_film()), and a douse runs along its top edges.
 * Any other field cause comes from the canvas facing north, clipped to the tail, because the tail hangs off the back.
 * It's drawn while drafting.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the tail's pixels on the tile's canvas.
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3, or to 4 for smoke and machine work.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - direction: The direction.
 * - floor_up: How many pixels over the floor the canvas's top row lies, 31 on a tile standing on the floor. A row's
 *   height over the floor is floor_up less the row.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_tail_rasterise(alist/mask, cause, datum/dirt_material/material, level, variant, direction, floor_up = ICON_SIZE_Y - 1, side = 1)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_tail_rasterise), args.Copy())
#endif
	switch(cause)
		if(DIRT_CAUSE_SMOKE, DIRT_CAUSE_WEAR, DIRT_CAUSE_MACHINE, DIRT_CAUSE_KNEEL)
			return dirt_sparse_film(mask, cause, level, variant, cause == DIRT_CAUSE_SMOKE && level >= 3, DIRT_CANVAS_TILE)
		if(DIRT_CAUSE_DOUSE)
			return dirt_douse_rasterise(mask, material, level, variant, DIRT_CANVAS_TILE, direction)
	if(cause != DIRT_CAUSE_WALK && cause != DIRT_CAUSE_DUST && cause != DIRT_CAUSE_CRAWL)
		// the tail hangs off the back, so every view draws the canvas facing north
		return dirt_clip_to_shape(dirt_canvas_rasterise(cause, material, level, variant, DIRT_CANVAS_TILE, NORTH, DIRT_SURFACE_FUR, side), mask)
	var/datum/dirt_random/rng = dirt_general_stream("tail:[cause]:[num2text(variant, 12)]")
	var/seed = rng.randrange(65536)
	var/list/reach = list(1.6, rng.uniform(3, 3.8), rng.uniform(4.5, 5.5))
	var/list/bottoms = dirt_shape_edges(mask, ICON_SIZE_X, TRUE)
	var/list/ranks = dirt_role_ranks()
	var/datum/dirt_pixels/drawn = new(ICON_SIZE_X, ICON_SIZE_Y)
	for(var/each_level in 1 to min(level, DIRT_DEPOSIT_MAX_LEVEL))
		for(var/index in mask)
			var/row = floor((index - 1) / ICON_SIZE_X)
			var/column = index - 1 - row * ICON_SIZE_X
			var/bottom = bottoms[column + 1]
			// pixels up from the column's underside, and how high it's held, because a tail held high catches less
			var/depth = bottom - row
			var/held_up = floor_up - bottom
			var/near = max(0, 1 - held_up / 14)
			var/line = reach[each_level] * (0.35 + 0.65 * near) + (dirt_spread_noise(column, row, seed, 3) - 0.5) * 1.6
			if(depth > line + 1.5)
				continue
			var/share = depth / max(0.8, line)
			var/role = share <= 0.45 ? DIRT_ROLE_BODY : (share <= 0.85 ? DIRT_ROLE_FILM : DIRT_ROLE_HAZE)
			// only a tail that reaches the ground gets the thick tone
			if(held_up > 6 && role == DIRT_ROLE_BODY)
				role = DIRT_ROLE_FILM
			var/held = drawn.roles[index]
			if(!held || ranks[role] > ranks[held])
				drawn.put_index(index, role, 0.6)
	return drawn

/**
 * Returns wings' dirt in one direction. Wings never touch the floor, so walking, crawling, settling dust and kneeling
 * give no ground coat. They give only two drips off the lowest feathers at level 3. Smoke, wear and machine work show
 * as a sparse film (dirt_sparse_film()). A plunge, a blast, a fall or a splash reach them from the canvas field like
 * any surface. A douse runs along their top edges, and slime lands in their own pixels (dirt_splat_rasterise()). Mess
 * never does, because a shot at the back lands on the back. It's drawn while drafting.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the wings' pixels on their canvas (DIRT_CANVAS_WINGS).
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3, or to 4 for smoke and machine work.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - direction: The direction.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_wing_rasterise(alist/mask, cause, datum/dirt_material/material, level, variant, direction, side = 1)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_wing_rasterise), args.Copy())
#endif
	var/list/size = dirt_canvases()[DIRT_CANVAS_WINGS]
	var/width = size[1]
	var/height = size[2]
	if(cause == DIRT_CAUSE_DOUSE)
		return dirt_douse_rasterise(mask, material, level, variant, DIRT_CANVAS_WINGS, direction)
	if(copytext(cause, 1, length(DIRT_CAUSE_SLIMED) + 1) == DIRT_CAUSE_SLIMED)
		return dirt_splat_rasterise(mask, cause, material, level, variant, DIRT_SHAPE_WINGS, direction, side)
	switch(cause)
		if(DIRT_CAUSE_PLUNGE, DIRT_CAUSE_BLAST, DIRT_CAUSE_FALL, DIRT_CAUSE_SPLASH)
			return dirt_clip_to_shape(dirt_canvas_rasterise(cause, material, level, variant, DIRT_CANVAS_WINGS, direction, DIRT_SURFACE_FUR, side), mask)
	if(cause != DIRT_CAUSE_WALK && cause != DIRT_CAUSE_DUST && cause != DIRT_CAUSE_CRAWL && cause != DIRT_CAUSE_KNEEL)
		return dirt_sparse_film(mask, cause, level, variant, cause == DIRT_CAUSE_SMOKE && level >= 3, DIRT_CANVAS_WINGS)
	var/datum/dirt_pixels/drawn = new(width, height)
	if(level < 3)
		return drawn
	// the lowest twelve pixels, the lowest rows first, each left to right
	var/list/lowest = list()
	for(var/row = height - 1, row >= 0 && length(lowest) < 12, row--)
		for(var/column in 0 to width - 1)
			var/index = row * width + column + 1
			if(mask[index])
				lowest += index
				if(length(lowest) >= 12)
					break
	if(!length(lowest))
		return drawn
	for(var/index in list(lowest[1], lowest[floor(length(lowest) / 2) + 1]))
		var/row = floor((index - 1) / width)
		for(var/spot, role in dirt_soft_speck(index - 1 - row * width, row - 2, TRUE, width, height, mask))
			drawn.put_index(spot, role, 0.5)
	return drawn

/**
 * Returns a douse on a shape in one direction. Each column's own top edge takes the cap, and streams run down from it,
 * from the body's random draws ("douse:<variant>", dirt_douse_draws()). So a stream down a rider meets the one down
 * the taur under it. Levels 1 to `level` are merged, each cleaned up on its own. A light material clumps. Hair is
 * soaked first, never core. It's drawn while drafting by /datum/dirt_canvas_field/douse, which a mask job draws a band
 * at a time.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels on its canvas.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - canvas: The shape's DIRT_CANVAS_* define.
 * - direction: The direction.
 * - surface_kind: DIRT_SURFACE_FUR or DIRT_SURFACE_HAIR.
 */
/proc/dirt_douse_rasterise(alist/mask, datum/dirt_material/material, level, variant, canvas, direction, surface_kind = DIRT_SURFACE_FUR)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_douse_rasterise), args.Copy())
#endif
	var/datum/dirt_canvas_field/douse/douse = new(mask, material, level, variant, canvas, direction, surface_kind)
	// at least a whole level each call
	for(var/each_level in 1 to douse.level)
		if(douse.draw_rows(douse.view.height))
			break
	return douse.merged

/**
 * A douse on a shape in one direction, as dirt_douse_rasterise() draws it. It's drawn some of the shape's pixels at a
 * time (draw_rows()), level after level. A mask job draws it a band a piece (dirt_canvas_field_band()), as many pixels
 * as a field's band draws of the canvas. The job keeps it among its fields (/datum/dirt_mask_job/proc/field_for()).
 */
/datum/dirt_canvas_field/douse
	/// alist(index = TRUE) on the shape's pixels, until every level is drawn.
	var/alist/mask
	/// Those pixels in the order `mask` gives them, drawn a band at a time.
	var/list/pixels
	/// The next pixel to draw in the level being drawn, from 1.
	var/next_pixel = 1
	/// Each column's top edge (dirt_shape_edges()).
	var/list/tops
	/// The variant, which names the random stream its draws come from.
	var/variant
	/// Its random draws (dirt_douse_draws()), made as its first band is drawn.
	var/datum/dirt_douse_draws/draws
	/// Whether its material is light, so it clumps.
	var/light = FALSE

/**
 * Arguments:
 * - mask, material, level, variant, canvas, direction, surface_kind: As in dirt_douse_rasterise().
 */
/datum/dirt_canvas_field/douse/New(alist/mask, datum/dirt_material/material, level, variant, canvas, direction, surface_kind)
	. = ..(DIRT_CAUSE_DOUSE, material, level, variant, canvas, direction, surface_kind, 1)
	src.mask = mask
	src.variant = variant
	light = !!(material.flags & DIRT_MATERIAL_LIGHT)
	pixels = list()
	for(var/index in mask)
		pixels += index
	tops = dirt_shape_edges(mask, view.width)

/**
 * Draws the douse's next pixels, as many as `rows` of the canvas hold, level by level. It makes its random draws as it
 * begins. Once a level's last pixel is drawn, it cleans the level up (dirt_cleanup()) and stacks it on the levels
 * before. The next level goes on with what's left. Once the last level is stacked, the hair soaked, never core.
 * Call it while drafting.
 *
 * Arguments:
 * - rows: How many pixels to draw, as a count of the canvas's rows, at least one.
 *
 * Returns whether every level is drawn.
 */
/datum/dirt_canvas_field/douse/draw_rows(rows)
	var/width = view.width
	var/left = rows * width
	// a level each turn, for as long as `left` lasts
	for(var/turn in 1 to level)
		if(done)
			return TRUE
		if(!drawn)
			draws ||= dirt_douse_draws(dirt_general_stream("douse:[num2text(variant, 12)]"))
			drawing_level++
			drawn = new(width, view.height)
			next_pixel = 1
		var/last_pixel = min(next_pixel + left, length(pixels) + 1) - 1
		left -= last_pixel - next_pixel + 1
		for(var/position in next_pixel to last_pixel)
			var/index = pixels[position]
			var/row = floor((index - 1) / width)
			var/column = index - 1 - row * width
			var/mob_x = view.mob_x(column)
			var/up = view.up(row)
			var/thickness = dirt_douse_thickness(mob_x, row - tops[column + 1], up, drawing_level, draws, light, samples, index)
			if(light && thickness > 0)
				thickness = dirt_light_cover(thickness, mob_x, up, draws.seed, dirt_field_spread_noise(samples, "light top", index, mob_x, up, draws.seed + 43, 3) > 0.72, samples, index)
			if(thickness > 0)
				drawn.put_index(index, dirt_thickness_role(thickness), thickness)
		next_pixel = last_pixel + 1
		if(next_pixel <= length(pixels))
			return FALSE
		dirt_stack_level(merged, dirt_cleanup(drawn))
		drawn = null
		done = drawing_level >= level
		if(done)
			break
		if(left <= 0)
			return FALSE
	if(surface_kind == DIRT_SURFACE_HAIR)
		var/list/roles = merged.roles
		for(var/index in 1 to length(roles))
			if(roles[index] == DIRT_ROLE_CORE)
				roles[index] = DIRT_ROLE_BODY
	mask = null
	pixels = null
	tops = null
	samples = null
	return TRUE

/**
 * Returns any field cause on a shape read from its sprite in one direction: ears, horns, hair and other parts. A douse
 * runs along its top edges. Slime latched on, hit or lain in with the head gives a douse's level-1 cap in lumps. A
 * solid cap reads as dyed hair, and a whole mass in the slime's colour as dye or a beanie. Every other cause comes
 * from the canvas field, clipped to the shape. It's drawn while drafting.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels on its canvas.
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to 3, or to 4 for smoke.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - canvas: The shape's DIRT_CANVAS_* define.
 * - direction: The direction.
 * - surface_kind: DIRT_SURFACE_FUR or DIRT_SURFACE_HAIR.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_shape_rasterise(alist/mask, cause, datum/dirt_material/material, level, variant, canvas, direction, surface_kind = DIRT_SURFACE_FUR, side = 1)
	RETURN_TYPE(/datum/dirt_pixels)
#ifdef DIRT_DRAFT_EXACT
	if(!SSdirt.drafting)
		return dirt_drafted(GLOBAL_PROC_REF(dirt_shape_rasterise), args.Copy())
#endif
	switch(cause)
		if(DIRT_CAUSE_DOUSE)
			return dirt_douse_rasterise(mask, material, level, variant, canvas, direction, surface_kind)
		if(DIRT_CAUSE_SLIMED, DIRT_CAUSE_SLIMED_HEAD, DIRT_CAUSE_SLIMED_BACK)
			// the crown only, because a deeper cap covers a whole hair mass from behind
			var/datum/dirt_pixels/cap = dirt_douse_rasterise(mask, material, 1, variant, canvas, direction, surface_kind)
			var/list/roles = cap.roles
			var/width = cap.width
			for(var/index in 1 to length(roles))
				if(!roles[index] || roles[index] == DIRT_ROLE_GLINT)
					continue
				var/row = floor((index - 1) / width)
				if(dirt_spread_noise(index - 1 - row * width, row, variant + 51, 1.6) <= 0.62)
					cap.put_index(index, null, null)
			return cap
	return dirt_clip_to_shape(dirt_canvas_rasterise(cause, material, level, variant, canvas, direction, surface_kind, side), mask)

/**
 * Returns the pixels of a shape slime reaches in one direction, as alist(index = TRUE). On wings or a tail, slime lain
 * on with the back reaches all of them, slime from above their top edges, and other slime none. On a taur body, slime
 * from above or lain on reaches its back, deeper when lain on at level 3. A hit on the chest reaches its front where
 * the view shows it, and slime on the legs its lowest third. Other slime reaches none, because the head and arms stay
 * on the rider.
 *
 * Arguments:
 * - mask: alist(index = TRUE) on the shape's pixels.
 * - cause: A slime DIRT_CAUSE_* define.
 * - kind: A DIRT_SHAPE_* define.
 * - direction: The direction.
 * - level: The splat's level.
 * - width: The canvas's width.
 */
/proc/dirt_splat_region(alist/mask, cause, kind, direction, level, width)
	RETURN_TYPE(/alist)
	var/alist/region = alist()
	if(!length(mask))
		return region
	var/list/tops = dirt_shape_edges(mask, width)
	var/from_above = cause == DIRT_CAUSE_SLIMED
	var/on_back = cause == DIRT_CAUSE_SLIMED_BACK
	var/depth = 0
	if(kind != DIRT_SHAPE_TAUR)
		depth = on_back ? INFINITY : (from_above ? 3 : 0)
	else if(from_above || on_back)
		depth = (on_back && level >= 3) ? 5 : 3
	if(depth)
		for(var/index in mask)
			var/row = floor((index - 1) / width)
			if(row - tops[index - row * width] < depth)
				region[index] = TRUE
		return region
	if(kind != DIRT_SHAPE_TAUR)
		return region
	var/first_column
	var/last_column
	var/first_row
	var/last_row
	for(var/index in mask)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		first_column = isnull(first_column) ? column : min(first_column, column)
		last_column = isnull(last_column) ? column : max(last_column, column)
		first_row = isnull(first_row) ? row : min(first_row, row)
		last_row = isnull(last_row) ? row : max(last_row, row)
	switch(cause)
		if(DIRT_CAUSE_SLIMED_CHEST)
			if(direction == NORTH)
				return region
			var/middle = (first_column + last_column) / 2
			for(var/index in mask)
				var/column = (index - 1) % width
				if(direction == SOUTH || (direction == EAST ? column > middle : column < middle))
					region[index] = TRUE
		if(DIRT_CAUSE_SLIMED_R_LEG, DIRT_CAUSE_SLIMED_L_LEG)
			var/cut = first_row + (last_row - first_row) * 2 / 3
			for(var/index in mask)
				if(floor((index - 1) / width) >= cut)
					region[index] = TRUE
	return region

#undef DIRT_FIELD_BAND_PIXELS
