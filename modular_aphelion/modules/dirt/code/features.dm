/**
 * One mark a cause leaves on a body's surface: how thick it lies at each point of one limb, from 0, nothing, to 1. Only
 * a contact point or a wet coat's underside passes DIRT_CONTACT, so the darkest role lands there and nowhere else.
 *
 * A feature also knows how far it can reach, so it's weighed only on the pixels round it. A few are drawn on pixels
 * each view picks for them instead (bind()).
 */
/datum/dirt_feature
	/// The DIRT_LIMB_* define it lies on, or null for one drawn on pixels a view picks across limbs.
	var/limb
	/// The theta at its middle, or null for a feature with none.
	var/centre_theta
	/// The h at its middle, or null for a feature with none.
	var/centre_along
	/// Its seed, a whole number, or null for a feature drawn from none.
	var/seed
	/// The DIRT_ROLE_* define it always draws in, or null to draw in the role its thickness picks.
	var/role
	/// The DIRT_ROLE_* define it draws in on bare skin instead, or null. Settled soot reaches skin as film only.
	var/skin_role
	/// Whether it's a veil, an even film that may cover the mouth but never an eye. On a face a veil keeps to
	/// dirt_face_zone()'s limits rather than the face's guard, which keeps other dirt off the eyes and mouth.
	var/veil = FALSE
	/// Whether it's drawn on cloth only, as a wipe mark is.
	var/cloth_only = FALSE
	/// Whether it's drawn on bare skin only.
	var/skin_only = FALSE
	/// Whether it's a speck, placed after the coats and kept clear of them (dirt_scatter()), rather than a coat.
	var/scatter = FALSE
	/// Whether a broken film ring runs round what it draws (dirt_rings()). Abrasion marks dark cloth, and its ring
	/// marks light cloth.
	var/ring = FALSE
	/// Whether it's left out facing east or west. In profile only a back's edge shows, and mess on it reads as a strap.
	var/profile_hidden = FALSE
	/// Whether it's drawn facing east or west only. In profile the arm hides the back,
	/// so a back's coat shows down the leg.
	var/profile_only = FALSE
	/// Whether it covers, as the top level does. It fades at the outline and breaks near a profile's outline
	/// (dirt_rasterise_level()), and it's drawn whatever the runs' spacing keeps.
	var/covering = FALSE
	/// A covering feature's seed for the noise that breaks it near a profile's outline.
	var/break_seed = 0
	/// The run or drop it belongs to, which a view may leave out (dirt_runs_apart()): a number, DIRT_RUN_GROUP_EARLY,
	/// or null for one always drawn.
	var/run_group
	/// The only level it's drawn from, for a run carried on past its bulb, or null.
	var/from_level
	/// alist(pixel index = thickness) on the view it's drawn on, where it lies at all (pixels_on()).
	var/alist/drawn_pixels
	/// Degrees round its limb that one pixel spans, from dirt_metric().
	var/degrees_per_pixel
	/// h along its limb that one pixel spans, from dirt_metric().
	var/along_per_pixel
	/// The theta in the middle of where it can reach.
	var/reach_theta = 0
	/// How many degrees either side of reach_theta it can reach.
	var/reach_degrees = 180
	/// The lowest h it can reach.
	var/reach_low = -INFINITY
	/// The highest h it can reach.
	var/reach_high = INFINITY
	/// Its mask job's table of the deposit's noise (/datum/dirt_mask_job/var/deposit_samples), or null to sample afresh
	/// (noise()). It's handed over each time dirt_level_features() hands out the feature's level.
	var/alist/deposit_samples
	/// The part of deposit_samples that noise() read last, for site_seed and site_scale:
	/// alist(sample_y = alist(sample_x = value)). It's kept until unbind().
	var/alist/site_samples
	/// The seed site_samples is for.
	var/site_seed
	/// The scale site_samples is for.
	var/site_scale

/datum/dirt_feature/New(limb, theta, along)
	. = ..()
	src.limb = limb
	centre_theta = theta
	centre_along = along
	if(!limb)
		return
	var/list/metric = dirt_metric(limb)
	degrees_per_pixel = metric[1]
	along_per_pixel = metric[2]

/**
 * Returns how thick the feature lies at a point of the surface, from 0, nothing, to 1.
 *
 * Arguments:
 * - theta: Degrees round the limb, from -180 up to 180.
 * - along: h along the limb.
 */
/datum/dirt_feature/proc/thickness(theta, along)
	return 0

/**
 * Sets how far the feature can reach: `across_px` either side of `theta` round the limb, and from `down_px` under
 * `along` to `up_px` over it.
 */
/datum/dirt_feature/proc/set_reach(theta, along, across_px, down_px, up_px)
	reach_theta = theta
	reach_degrees = across_px * degrees_per_pixel
	reach_low = along - down_px * along_per_pixel
	reach_high = along + up_px * along_per_pixel

/**
 * Returns how thick the feature lies on each pixel of the view it's drawn on, where it lies at all: alist(pixel index =
 * thickness). It's worked out the first time it's asked for (bind()). A feature is drawn on one view at a time, and
 * unbind() frees it for the next. You should NEVER modify it.
 *
 * Arguments:
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/datum/dirt_feature/proc/pixels_on(datum/dirt_surface/surface, alist/surface_rows)
	RETURN_TYPE(/alist)
	if(!drawn_pixels)
		bind(surface, surface_rows)
	return drawn_pixels

/**
 * Works out the pixels the feature draws on in one view, into drawn_pixels. By default it takes its thickness() on each
 * pixel of its limb it can reach. A few pick their pixels instead. Every pixel's theta lies within 90 degrees of the
 * way the view faces (/datum/dirt_surface/proc/place_pixels()). So if a view faces more than 90 degrees past a
 * feature's reach, it shows none of the feature, and no pixel is weighed.
 *
 * Arguments:
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/datum/dirt_feature/proc/bind(datum/dirt_surface/surface, alist/surface_rows)
	drawn_pixels = alist()
	var/list/rows = surface_rows[limb]
	if(!rows)
		return
	// the facing is the one place_pixels() turns each theta from
	// a gauss-drawn reach_theta can lie past a half turn, so the turn is wrapped in full, and the 0.01 covers rounding
	var/direction = surface.direction
	var/facing = direction == NORTH ? 180 : (direction == EAST ? 90 : (direction == WEST ? -90 : 0))
	if(abs(DIRT_MODULO(reach_theta - facing + 180, 360) - 180) > reach_degrees + 90.01)
		return
	var/list/theta_of = surface.theta_of
	var/list/height_of = surface.height_of
	for(var/list/entry as anything in rows)
		if(entry[3] < reach_low || entry[2] > reach_high)
			continue
		for(var/index in entry[4])
			var/theta = theta_of[index]
			var/turn = theta - reach_theta
			if(abs(DIRT_WRAP_DEGREES(turn)) > reach_degrees)
				continue
			var/thickness = thickness(theta, height_of[index])
			if(thickness)
				drawn_pixels[index] = thickness

/**
 * Frees the feature for another view. It drops what it bound on the last view and the part of its job's noise table
 * it read. It binds again on the next view when asked (pixels_on()). The rest of what it was made with stays,
 * because a mask job draws a deposit's features in each direction in turn (dirt_level_features()).
 */
/datum/dirt_feature/proc/unbind()
	drawn_pixels = null
	site_samples = null

/**
 * Returns two octaves of value noise at a point, as dirt_spread_noise() does. With its mask job's table
 * (deposit_samples), it returns the value kept there for the same four numbers, or samples one now and keeps it. The
 * table keys the four numbers exactly. In one drafting state (SSdirt.drafting) the noise depends on its arguments
 * alone, and a job draws every direction of a deposit while drafting. So a kept value is what sampling again returns.
 *
 * Arguments:
 * - sample_x, sample_y, seed, scale: As dirt_spread_noise()'s.
 */
/datum/dirt_feature/proc/noise(sample_x, sample_y, seed, scale)
	if(!deposit_samples)
		return dirt_spread_noise(sample_x, sample_y, seed, scale)
	var/alist/by_y = site_samples
	// a site's pixels all sample one seed and scale, so this runs once a view, but a broken mantle alternates two pairs
	if(!by_y || seed != site_seed || scale != site_scale)
		var/alist/by_scale = (deposit_samples[seed] ||= alist())
		by_y = (by_scale[scale] ||= alist())
		site_samples = by_y
		site_seed = seed
		site_scale = scale
	var/alist/by_x = (by_y[sample_y] ||= alist())
	. = by_x[sample_x]
	if(isnull(.))
		. = dirt_spread_noise(sample_x, sample_y, seed, scale)
		by_x[sample_x] = .

/**
 * A streak between two surface points, tapering toward its end. A fringe draws a film edge round it. A fluid's drip
 * goes without, since a fringe would dither a 1 px streak. A fringe on one side only keeps two streaks from merging
 * into one blob.
 */
/datum/dirt_feature/stroke
	/// The theta it starts at.
	var/start_theta
	/// The h it starts at.
	var/start_along
	/// Its width at the start, in pixels.
	var/width
	/// How much of its width it loses by its end.
	var/taper
	/// Whether a film edge runs round it.
	var/fringe
	/// The side its fringe keeps to, 1 or -1 (which side of the line from its start to its end), or 0 for both.
	var/film_side
	/// Pixels round the limb from its start to its end.
	var/span_across
	/// Pixels up the limb from its start to its end.
	var/span_up
	/// Its length in pixels, squared.
	var/span_squared

/**
 * Starts a streak.
 *
 * Arguments:
 * - start: Where it starts, list(theta, h).
 * - finish: Where it ends, list(theta, h).
 */
/datum/dirt_feature/stroke/New(limb, list/start, list/finish, width, taper = 0.5, fringe = TRUE, film_side = 0)
	. = ..(limb)
	start_theta = start[1]
	start_along = start[2]
	src.width = width
	src.taper = taper
	src.fringe = fringe
	src.film_side = film_side
	var/turn = finish[1] - start_theta
	span_across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	span_up = (finish[2] - start_along) / along_per_pixel
	span_squared = span_across * span_across + span_up * span_up
	// its widest edge round the segment, and half a pixel to spare
	var/extent = width / 2 + (fringe ? 0.7 : 0) + 0.5
	var/middle = start_along + span_up / 2 * along_per_pixel
	var/along_px = abs(span_up) / 2 + extent
	set_reach(start_theta + span_across / 2 * degrees_per_pixel, middle, abs(span_across) / 2 + extent, along_px, along_px)

/**
 * Returns the body tone within the streak's half width of its line, and a film fringe 0.7 px past that. A fringe that
 * keeps to one side draws on that side only.
 */
/datum/dirt_feature/stroke/thickness(theta, along)
	var/turn = theta - start_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - start_along) / along_per_pixel
	var/fraction = span_squared ? clamp((across * span_across + up * span_up) / span_squared, 0, 1) : 0
	var/miss_across = across - span_across * fraction
	var/miss_up = up - span_up * fraction
	var/distance = sqrt(miss_across * miss_across + miss_up * miss_up)
	var/half = width * (1 - taper * fraction) / 2
	if(distance <= half)
		return DIRT_BODY_T
	if(!fringe || distance > half + 0.7)
		return 0
	if(film_side && span_squared && (span_across * miss_up - span_up * miss_across) * film_side <= 0)
		return 0
	return DIRT_FILM_T

/**
 * A rounded lump of goo where it landed: thickest underneath, a thin film round it, its outline wobbling a little with
 * noise. A glint (/datum/dirt_feature/glint) goes on top.
 */
/datum/dirt_feature/glob
	/// Its radius round the limb, in pixels.
	var/radius_x
	/// Its radius up the limb, in pixels.
	var/radius_y
	/// How far its outline wobbles, as a fraction of its radius.
	var/ragged
	/// Whether its lower part is the thickest. A drop has none.
	var/underside

/**
 * Starts a lump.
 *
 * Arguments:
 * - seed: The seed of the noise its outline wobbles by, a whole number.
 */
/datum/dirt_feature/glob/New(limb, theta, along, radius_x, radius_y, seed, ragged, underside = TRUE)
	. = ..(limb, theta, along)
	src.radius_x = radius_x
	src.radius_y = radius_y
	src.seed = seed
	src.ragged = ragged
	src.underside = underside
	// nothing past 1.6 radii, and half a pixel to spare
	set_reach(theta, along, 1.6 * radius_x + 0.5, 1.6 * radius_y + 0.5, 1.6 * radius_y + 0.5)

/// Returns the body tone in its wobbling outline, contact low in an underside, and film in a ring 0.2 radii past it.
/datum/dirt_feature/glob/thickness(theta, along)
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	var/stretched_across = across / radius_x
	var/stretched_up = up / radius_y
	var/distance = sqrt(stretched_across * stretched_across + stretched_up * stretched_up)
	if(distance > 1.6)
		return 0
	distance += (noise(theta / degrees_per_pixel, along / along_per_pixel, seed, 1.8) - 0.5) * 2 * ragged
	if(distance >= 1)
		return distance < 1.2 ? DIRT_FILM_T : 0
	if(underside && up < -0.2 * radius_y && distance < 0.85)
		return DIRT_CONTACT + 0.05
	return DIRT_BODY_T

/// A lump's glint, one pixel on its upper side.
/datum/dirt_feature/glint
	role = DIRT_ROLE_GLINT

/datum/dirt_feature/glint/New(limb, theta, along)
	. = ..(limb, theta, along)
	// half a pixel each way, and half a pixel to spare
	set_reach(theta, along, 1, 1, 1)

/// Returns full thickness on the one pixel it sits on.
/datum/dirt_feature/glint/thickness(theta, along)
	var/turn = theta - centre_theta
	return (abs(DIRT_WRAP_DEGREES(turn)) / degrees_per_pixel < 0.5 && abs(along - centre_along) / along_per_pixel < 0.5) ? 1 : 0

/**
 * A bead's glint on one pixel only, the nearest to its theta of those a glint lights. On a narrow limb a glint lights
 * two side by side, which reads as a white dash.
 */
/datum/dirt_feature/glint/highlight

/datum/dirt_feature/glint/highlight/bind(datum/dirt_surface/surface, alist/surface_rows)
	drawn_pixels = alist()
	var/list/rows = surface_rows[limb]
	if(!rows)
		return
	var/list/theta_of = surface.theta_of
	var/list/height_of = surface.height_of
	var/nearest
	var/nearest_turn
	for(var/list/entry as anything in rows)
		if(entry[3] < reach_low || entry[2] > reach_high)
			continue
		for(var/index in entry[4])
			var/theta = theta_of[index]
			if(!thickness(theta, height_of[index]))
				continue
			var/turn = theta - centre_theta
			turn = abs(DIRT_WRAP_DEGREES(turn))
			if(isnull(nearest) || turn < nearest_turn)
				nearest = index
				nearest_turn = turn
	if(nearest)
		drawn_pixels[nearest] = 1

/**
 * A run straight down a limb, one pixel a row: in each row, the limb's pixel nearest its theta, where that pixel covers
 * it. It isn't a streak along one theta, because that breaks up wherever the view foreshortens the limb.
 */
/datum/dirt_feature/run
	/// The h it starts at.
	var/top
	/// The h it ends at.
	var/bottom

/**
 * Starts a run.
 *
 * Arguments:
 * - theta: The theta it runs down.
 */
/datum/dirt_feature/run/New(limb, theta, top, bottom)
	. = ..(limb, theta)
	src.top = top
	src.bottom = bottom

/datum/dirt_feature/run/bind(datum/dirt_surface/surface, alist/surface_rows)
	drawn_pixels = alist()
	var/list/rows = surface_rows[limb]
	if(!rows)
		return
	var/half = 0.5 * along_per_pixel
	var/low = bottom - half
	var/high = top + half
	var/list/theta_of = surface.theta_of
	var/list/height_of = surface.height_of
	for(var/list/entry as anything in rows)
		if(entry[3] < low || entry[2] > high)
			continue
		var/list/line = list()
		var/nearest
		var/nearest_turn
		for(var/index in entry[4])
			var/along = height_of[index]
			if(along < low || along > high)
				continue
			line += index
			var/turn = theta_of[index] - centre_theta
			turn = abs(DIRT_WRAP_DEGREES(turn))
			if(isnull(nearest) || turn < nearest_turn)
				nearest = index
				nearest_turn = turn
		if(isnull(nearest))
			continue
		if(nearest_turn <= dirt_pixel_span(line, nearest, theta_of, degrees_per_pixel) * 0.5)
			drawn_pixels[nearest] = DIRT_BODY_T

/**
 * Returns how many degrees a pixel of a row spans. It's the widest turn to a pixel beside it in the row, but never less
 * than the limb's own.
 *
 * Arguments:
 * - line: The row's pixel indexes, side by side.
 * - pixel: The pixel's index.
 * - least: The limb's degrees per pixel.
 */
/proc/dirt_pixel_span(list/line, pixel, list/theta_of, least)
	. = least
	for(var/index in line)
		if(abs(index - pixel) == 1)
			var/step_turn = theta_of[index] - theta_of[pixel]
			. = max(., abs(DIRT_WRAP_DEGREES(step_turn)))

/**
 * A translucent tongue hanging from where it landed. It's film in its middle, thinning to broken haze toward its edge,
 * because a sheet even to its edge reads as a garment. Its top and tip move up and down across it with noise.
 */
/datum/dirt_feature/glaze
	/// Its half width at the top, in pixels.
	var/width
	/// How far it hangs, in pixels, before its length varies across it.
	var/hang_length
	/// How far its outline wobbles past its middle.
	var/ragged = 0.35

/**
 * Starts a tongue.
 *
 * Arguments:
 * - theta: The theta at the middle of its top.
 * - along: The h of its top.
 * - seed: The seed of its noise, a whole number.
 */
/datum/dirt_feature/glaze/New(limb, theta, along, width, hang_length, seed)
	. = ..(limb, theta, along)
	src.width = width
	src.hang_length = hang_length
	src.seed = seed
	// its shape stays inside 1.6: 1.6 widths across, 1.28 px over its top and 2 lengths below it, its top moving 1.3 px
	// either way, and half a pixel to spare
	set_reach(theta, along, 1.6 * width + 0.5, 2 * hang_length + 1.8, 3.1)

/// Returns film inside its ragged outline, and broken film and haze toward the edge where its noise is low.
/datum/dirt_feature/glaze/thickness(theta, along)
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	var/distance = shape(across, up)
	if(distance > 1.6)
		return 0
	var/noise = dirt_spread_noise(theta / degrees_per_pixel, along / along_per_pixel, seed, 2)
	distance += (noise - 0.5) * 2 * ragged * clamp((distance - 0.35) / 0.5, 0, 1)
	if(distance < 0.65)
		return DIRT_FILM_T
	if(distance < 1.15)
		return noise > 0.55 ? DIRT_FILM_T : (noise > 0.3 ? DIRT_HAZE_T : 0)
	return 0

/**
 * Returns how far a point lies out in the tongue's shape, 1 on its outline. The shape is round over its top, and below
 * it narrows to half its width.
 *
 * Arguments:
 * - across: Pixels round the limb from its middle.
 * - up: Pixels up the limb from its top.
 */
/datum/dirt_feature/glaze/proc/shape(across, up)
	var/drop = -up + (dirt_value_noise(across, 0, seed, 1.3) - 0.5) * 2.6
	if(drop < 0)
		var/stretched_across = across / width
		var/stretched_drop = drop / 0.8
		return sqrt(stretched_across * stretched_across + stretched_drop * stretched_drop)
	var/narrowed = width * (1 - 0.5 * min(1, drop / hang_length))
	var/reach = hang_length * (0.75 + 0.5 * dirt_value_noise(across, 3, seed, 1.3))
	return ((abs(across) / narrowed) ** 3 + (drop / reach) ** 3) ** (1 / 3)

/**
 * A run or a tongue carried on past the torso's last row onto the leg below, straight down the column it left the torso
 * by. A coat that stops at the waist reads as an apron or a tube top's hem. A run ends in its grey underside, a tongue
 * in haze, with film beside its upper half.
 */
/datum/dirt_feature/spill
	/// How many rows it runs down the leg.
	var/rows
	/// Whether it carries a tongue on, rather than a run.
	var/tongue

/**
 * Starts a carry-on.
 *
 * Arguments:
 * - theta: The theta it leaves the torso at.
 * - seed: Its seed, a whole number. An odd seed puts a tongue's film to its right, an even one to its left.
 */
/datum/dirt_feature/spill/New(theta, rows, seed, tongue = FALSE)
	. = ..(null, theta)
	src.rows = rows
	src.seed = seed
	src.tongue = tongue

/datum/dirt_feature/spill/bind(datum/dirt_surface/surface, alist/surface_rows)
	drawn_pixels = alist()
	var/list/flags_of = surface.flags_of
	var/list/theta_of = surface.theta_of
	var/width = surface.width
	// walk the torso's rows up from the bottom to its last row of body pixels, not the margin's
	var/last = -1
	var/list/torso_rows = surface_rows[DIRT_LIMB_TORSO]
	for(var/position in length(torso_rows) to 1 step -1)
		var/list/entry = torso_rows[position]
		for(var/index in entry[4])
			if(DIRT_PIXEL_ZONE(flags_of[index]))
				last = entry[1]
				break
		if(last >= 0)
			break
	if(last < 0)
		return
	var/list/line = list()
	var/nearest
	var/nearest_turn
	for(var/column in 0 to width - 1)
		var/index = last * width + column + 1
		var/flags = flags_of[index]
		if(DIRT_PIXEL_LIMB(flags) != DIRT_LIMB_TORSO || !DIRT_PIXEL_ZONE(flags))
			continue
		line += index
		var/turn = theta_of[index] - centre_theta
		turn = abs(DIRT_WRAP_DEGREES(turn))
		if(isnull(nearest) || turn < nearest_turn)
			nearest = index
			nearest_turn = turn
	// it left the torso on the side this view doesn't show
	if(nearest_turn > dirt_pixel_span(line, nearest, theta_of, dirt_metric(DIRT_LIMB_TORSO)[1]) * 0.5)
		return
	var/column = DIRT_INDEX_COLUMN(nearest, last, width)
	var/side = seed % 2 ? 1 : -1
	for(var/step_down in 1 to rows)
		var/row = last + step_down
		var/index = surface.pixel_index(column, row)
		var/flags = index && flags_of[index]
		var/pixel_limb = DIRT_PIXEL_LIMB(flags)
		if(!DIRT_PIXEL_ZONE(flags) || (pixel_limb != DIRT_LIMB_R_LEG && pixel_limb != DIRT_LIMB_L_LEG))
			break
		var/next_index = surface.pixel_index(column, row + 1)
		var/at_end = step_down == rows || !next_index || !DIRT_PIXEL_ZONE(flags_of[next_index])
		if(tongue)
			drawn_pixels[index] = at_end ? DIRT_HAZE_T : DIRT_FILM_T
			var/beside = surface.pixel_index(column + side, row)
			var/beside_flags = beside && flags_of[beside]
			var/beside_limb = DIRT_PIXEL_LIMB(beside_flags)
			if(step_down <= floor(rows / 2) && DIRT_PIXEL_ZONE(beside_flags) && (beside_limb == DIRT_LIMB_R_LEG || beside_limb == DIRT_LIMB_L_LEG))
				drawn_pixels[beside] = DIRT_FILM_T
		else
			drawn_pixels[index] = at_end ? DIRT_CONTACT + 0.05 : DIRT_BODY_T
		if(at_end)
			break

/**
 * A mess's runs and drops as its top run level has them, in the order a view keeps them (dirt_runs_apart()). So every
 * level keeps the same ones. It draws nothing itself.
 */
/datum/dirt_feature/run_plan
	/// Each run or drop: list(its group, its features).
	var/list/groups
	/// The direction the zone faces most, the only one level 2's carry-on is weighed in, or null.
	var/main
	/// The first drop, which level 2's carry-on runs from, or null.
	var/datum/dirt_feature/anchor

/datum/dirt_feature/run_plan/New(list/groups, main, datum/dirt_feature/anchor)
	. = ..(null)
	src.groups = groups
	src.main = main
	src.anchor = anchor
