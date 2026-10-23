/**
 * One mark a cause leaves on a body's surface: how thick it lies at each point of one limb, from 0, nothing, to 1. Only a
 * contact point or a wet coat's underside passes DIRT_CONTACT, so the darkest role lands there and nowhere else.
 *
 * A feature also knows how far it can reach, so a mask weighs it only on the pixels round it. A few are drawn on pixels
 * each view picks for them instead (bind()).
 */
/datum/dirt_feature
	/// The DIRT_LIMB_* define it lies on, or null for one drawn on pixels a view picks across limbs.
	var/limb
	/// The DIRT_ROLE_* define it always draws in, or null to draw in the role its thickness picks.
	var/role
	/// Whether it's left out facing east or west: in profile only a back's edge shows, and semen on it read as a strap.
	var/profile_hidden = FALSE
	/// Whether it's drawn facing east or west only: in profile the arm hides the back, so a back's coat shows down the leg.
	var/profile_only = FALSE
	/// Whether it covers, as the top level does: it fades at the outline and breaks near a profile's (dirt_rasterise_level())
	/// and is drawn whatever the runs' spacing keeps.
	var/covering = FALSE
	/// A covering feature's seed for the noise that breaks it near a profile's outline.
	var/break_seed = 0
	/// The run or drop it belongs to, which a view may leave out (dirt_runs_apart()): a number, DIRT_RUN_GROUP_EARLY, or
	/// null for one always drawn.
	var/run_group
	/// The only level it's drawn from, for a run carried on past its bulb, or null.
	var/from_level
	/// For a feature drawn on pixels a view picks: alist(pixel index = thickness), set by bind(). Null for one weighed by
	/// its thickness round its limb.
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

/**
 * Starts a feature on a limb.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on, or null for one drawn on pixels a view picks across limbs.
 */
/datum/dirt_feature/New(limb)
	. = ..()
	src.limb = limb
	if(!limb)
		return
	var/list/metric = dirt_metric(limb)
	degrees_per_pixel = metric[1]
	along_per_pixel = metric[2]

/**
 * Returns how thick the feature lies at a point of the surface, from 0, nothing, to 1.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define of the limb the point is on.
 * - theta: Degrees round the limb.
 * - along: h along the limb.
 */
/datum/dirt_feature/proc/thickness(limb, theta, along)
	return 0

/**
 * Picks the pixels a feature drawn on pixels draws on in one view, into drawn_pixels. Others draw by thickness() and
 * need nothing.
 *
 * Arguments:
 * - surface: The view's surface.
 * - surface_rows: Its pixels by limb and row, from dirt_surface_rows().
 */
/datum/dirt_feature/proc/bind(datum/dirt_surface/surface, alist/surface_rows)
	return

/**
 * A streak between two surface points, tapering toward its end. A fringe draws a film edge round it; a fluid's drip goes
 * without, since a fringe dithered a 1 px streak.
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
 * - limb: The DIRT_LIMB_* define it lies on.
 * - start: Where it starts, list(theta, h).
 * - finish: Where it ends, list(theta, h).
 * - width: Its width at the start, in pixels.
 * - taper: How much of its width it loses by its end.
 * - fringe: Whether a film edge runs round it.
 */
/datum/dirt_feature/stroke/New(limb, list/start, list/finish, width, taper = 0.5, fringe = TRUE)
	. = ..(limb)
	start_theta = start[1]
	start_along = start[2]
	src.width = width
	src.taper = taper
	src.fringe = fringe
	var/turn = finish[1] - start_theta
	span_across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	span_up = (finish[2] - start_along) / along_per_pixel
	span_squared = span_across * span_across + span_up * span_up
	// its widest edge round the segment, and half a pixel to spare
	var/extent = width / 2 + (fringe ? 0.7 : 0) + 0.5
	reach_theta = start_theta + span_across / 2 * degrees_per_pixel
	reach_degrees = (abs(span_across) / 2 + extent) * degrees_per_pixel
	var/middle = start_along + span_up / 2 * along_per_pixel
	var/reach_along = (abs(span_up) / 2 + extent) * along_per_pixel
	reach_low = middle - reach_along
	reach_high = middle + reach_along

/**
 * Body within the streak's half width of its line, a film fringe 0.7 px past that.
 */
/datum/dirt_feature/stroke/thickness(limb, theta, along)
	if(limb != src.limb)
		return 0
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
	if(fringe && distance <= half + 0.7)
		return DIRT_FILM_T
	return 0

/**
 * A rounded lump of goo where it landed: thickest underneath, a thin film round it, its outline wobbling a little with
 * noise. Glint adds the highlight on top.
 */
/datum/dirt_feature/glob
	/// The theta at its middle.
	var/centre_theta
	/// The h at its middle.
	var/centre_along
	/// Its radius round the limb, in pixels.
	var/radius_x
	/// Its radius up the limb, in pixels.
	var/radius_y
	/// The seed of the noise its outline wobbles by.
	var/seed
	/// How far its outline wobbles, as a fraction of its radius.
	var/ragged
	/// Whether its lower part is the thickest. A drop has none.
	var/underside

/**
 * Starts a lump.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta at its middle.
 * - along: The h at its middle.
 * - radius_x: Its radius round the limb, in pixels.
 * - radius_y: Its radius up the limb, in pixels.
 * - seed: The seed of the noise its outline wobbles by, a whole number.
 * - ragged: How far its outline wobbles, as a fraction of its radius.
 * - underside: Whether its lower part is the thickest.
 */
/datum/dirt_feature/glob/New(limb, theta, along, radius_x, radius_y, seed, ragged = 0.18, underside = TRUE)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	src.radius_x = radius_x
	src.radius_y = radius_y
	src.seed = seed
	src.ragged = ragged
	src.underside = underside
	// nothing past 1.6 radii, and half a pixel to spare
	reach_theta = theta
	reach_degrees = (1.6 * radius_x + 0.5) * degrees_per_pixel
	var/reach_along = (1.6 * radius_y + 0.5) * along_per_pixel
	reach_low = along - reach_along
	reach_high = along + reach_along

/**
 * Body inside the wobbling outline, the underside's thickest in its lower part, film in a ring 0.2 radii past it.
 */
/datum/dirt_feature/glob/thickness(limb, theta, along)
	if(limb != src.limb)
		return 0
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	var/stretched_across = across / radius_x
	var/stretched_up = up / radius_y
	var/distance = sqrt(stretched_across * stretched_across + stretched_up * stretched_up)
	if(distance > 1.6)
		return 0
	var/wrapped = DIRT_WRAP_DEGREES(theta)
	distance += (dirt_spread_noise(wrapped / degrees_per_pixel, along / along_per_pixel, seed, 1.8) - 0.5) * 2 * ragged
	if(distance >= 1)
		return distance < 1.2 ? DIRT_FILM_T : 0
	if(underside && up < -0.2 * radius_y && distance < 0.85)
		return DIRT_CONTACT + 0.05
	return DIRT_BODY_T

/**
 * One highlight pixel on a lump's upper side, in the glint role.
 */
/datum/dirt_feature/glint
	role = DIRT_ROLE_GLINT
	/// The theta it sits at.
	var/centre_theta
	/// The h it sits at.
	var/centre_along

/**
 * Starts a highlight.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta it sits at.
 * - along: The h it sits at.
 */
/datum/dirt_feature/glint/New(limb, theta, along)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	// half a pixel each way, and half a pixel to spare
	reach_theta = theta
	reach_degrees = degrees_per_pixel
	reach_low = along - along_per_pixel
	reach_high = along + along_per_pixel

/**
 * Full thickness on the one pixel it sits on.
 */
/datum/dirt_feature/glint/thickness(limb, theta, along)
	if(limb != src.limb)
		return 0
	var/turn = theta - centre_theta
	return (abs(DIRT_WRAP_DEGREES(turn)) / degrees_per_pixel < 0.5 && abs(along - centre_along) / along_per_pixel < 0.5) ? 1 : 0

/**
 * A highlight on one pixel only, the nearest to its theta of those a glint lights: on a narrow limb a glint lit two side
 * by side, a white dash.
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
			if(!thickness(limb, theta, height_of[index]))
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
 * it. A streak along one theta broke up wherever the view foreshortens the limb.
 */
/datum/dirt_feature/run
	/// The theta it runs down.
	var/centre_theta
	/// The h it starts at.
	var/top
	/// The h it ends at.
	var/bottom

/**
 * Starts a run.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta it runs down.
 * - top: The h it starts at.
 * - bottom: The h it ends at.
 */
/datum/dirt_feature/run/New(limb, theta, top, bottom)
	. = ..(limb)
	centre_theta = theta
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
 * Returns how many degrees a pixel of a row spans: the turn to the pixels beside it in the row, or a limb's own at least.
 *
 * Arguments:
 * - line: The row's pixel indexes, side by side.
 * - pixel: The pixel's index.
 * - theta_of: The surface's thetas.
 * - least: The limb's degrees per pixel.
 */
/proc/dirt_pixel_span(list/line, pixel, list/theta_of, least)
	. = least
	for(var/index in line)
		if(abs(index - pixel) == 1)
			var/step_turn = theta_of[index] - theta_of[pixel]
			. = max(., abs(DIRT_WRAP_DEGREES(step_turn)))

/**
 * A translucent tongue hanging from where it landed: film in its middle, thinning to broken haze toward its edge, its
 * top and tip moving up and down across it with noise. Even to its edge, a sheet read as a garment.
 */
/datum/dirt_feature/glaze
	/// The theta at the middle of its top.
	var/centre_theta
	/// The h of its top.
	var/centre_along
	/// Its half width at the top, in pixels.
	var/width
	/// How far it hangs, in pixels, before its length varies across it.
	var/hang_length
	/// The seed of the noise its outline and its thinning follow.
	var/seed
	/// How far its outline wobbles past its middle.
	var/ragged = 0.35

/**
 * Starts a tongue.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta at the middle of its top.
 * - along: The h of its top.
 * - width: Its half width at the top, in pixels.
 * - hang_length: How far it hangs, in pixels.
 * - seed: The seed of its noise, a whole number.
 */
/datum/dirt_feature/glaze/New(limb, theta, along, width, hang_length, seed)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	src.width = width
	src.hang_length = hang_length
	src.seed = seed
	// its shape stays inside 1.6: 1.6 widths across, 1.28 px over its top and 2 lengths below it, its top moving 1.3 px
	// either way; half a pixel to spare
	reach_theta = theta
	reach_degrees = (1.6 * width + 0.5) * degrees_per_pixel
	reach_low = along - (2 * hang_length + 1.8) * along_per_pixel
	reach_high = along + 3.1 * along_per_pixel

/**
 * Film inside its ragged outline, broken film and haze toward the edge where its noise is low.
 */
/datum/dirt_feature/glaze/thickness(limb, theta, along)
	if(limb != src.limb)
		return 0
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	var/distance = shape(across, up)
	if(distance > 1.6)
		return 0
	var/wrapped = DIRT_WRAP_DEGREES(theta)
	var/noise = dirt_spread_noise(wrapped / degrees_per_pixel, along / along_per_pixel, seed, 2)
	distance += (noise - 0.5) * 2 * ragged * clamp((distance - 0.35) / 0.5, 0, 1)
	if(distance < 0.65)
		return DIRT_FILM_T
	if(distance < 1.15)
		return noise > 0.55 ? DIRT_FILM_T : (noise > 0.3 ? DIRT_HAZE_T : 0)
	return 0

/**
 * Returns how far a point lies out in the tongue's shape, 1 on its outline: round over its top, hanging below it and
 * narrowing to half its width, its top and its length moving with noise across it.
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
 * A run or a tongue carried on past the torso's last row onto the leg under it, straight down the column it left the
 * torso by: a coat that stopped at the waist read as an apron or a tube top's hem. A run ends in its grey underside, a
 * tongue in haze, with film beside its upper half.
 */
/datum/dirt_feature/spill
	/// The theta it leaves the torso at.
	var/centre_theta
	/// How many rows it runs down the leg.
	var/rows
	/// Its seed: odd puts a tongue's film to its right, even to its left.
	var/seed
	/// Whether it carries a tongue on, rather than a run.
	var/tongue

/**
 * Starts a carry-on.
 *
 * Arguments:
 * - theta: The theta it leaves the torso at.
 * - rows: How many rows it runs down the leg.
 * - seed: Its seed, a whole number.
 * - tongue: Whether it carries a tongue on, rather than a run.
 */
/datum/dirt_feature/spill/New(theta, rows, seed, tongue = FALSE)
	. = ..(null)
	centre_theta = theta
	src.rows = rows
	src.seed = seed
	src.tongue = tongue

/datum/dirt_feature/spill/bind(datum/dirt_surface/surface, alist/surface_rows)
	drawn_pixels = alist()
	var/list/limb_of = surface.limb_of
	var/list/zone_of = surface.zone_of
	var/list/theta_of = surface.theta_of
	var/width = surface.width
	// the torso's last row of body pixels, not the margin's
	var/last = -1
	for(var/index in 1 to length(limb_of))
		if(limb_of[index] == DIRT_LIMB_TORSO && zone_of[index])
			last = max(last, floor((index - 1) / width))
	if(last < 0)
		return
	var/list/line = list()
	var/nearest
	var/nearest_turn
	for(var/column in 0 to width - 1)
		var/index = last * width + column + 1
		if(limb_of[index] != DIRT_LIMB_TORSO || !zone_of[index])
			continue
		line += index
		var/turn = theta_of[index] - centre_theta
		turn = abs(DIRT_WRAP_DEGREES(turn))
		if(isnull(nearest) || turn < nearest_turn)
			nearest = index
			nearest_turn = turn
	if(nearest_turn > dirt_pixel_span(line, nearest, theta_of, dirt_metric(DIRT_LIMB_TORSO)[1]) * 0.5) // it left the torso on the side this view doesn't show
		return
	var/column = nearest - 1 - last * width
	var/side = seed % 2 ? 1 : -1
	for(var/step_down in 1 to rows)
		var/row = last + step_down
		var/index = surface.pixel_index(column, row)
		if(!index || !zone_of[index] || (limb_of[index] != DIRT_LIMB_R_LEG && limb_of[index] != DIRT_LIMB_L_LEG))
			break
		var/next_index = surface.pixel_index(column, row + 1)
		var/at_end = step_down == rows || !next_index || !zone_of[next_index]
		if(tongue)
			drawn_pixels[index] = at_end ? DIRT_HAZE_T : DIRT_FILM_T
			var/beside = surface.pixel_index(column + side, row)
			if(step_down <= floor(rows / 2) && beside && zone_of[beside] && (limb_of[beside] == DIRT_LIMB_R_LEG || limb_of[beside] == DIRT_LIMB_L_LEG))
				drawn_pixels[beside] = DIRT_FILM_T
		else
			drawn_pixels[index] = at_end ? DIRT_CONTACT + 0.05 : DIRT_BODY_T
		if(at_end)
			break

/**
 * Draws nothing: a deposit's runs and drops as its top run level has them, in the order a view keeps them
 * (dirt_runs_apart()), so every level keeps the same ones.
 */
/datum/dirt_feature/run_plan
	/// Each run or drop: list(its group, its features).
	var/list/groups
	/// The direction the zone faces most, the only one level 2's carry-on is weighed in, or null.
	var/main
	/// The first drop, which level 2's carry-on runs from, or null.
	var/datum/dirt_feature/anchor

/**
 * Starts a plan.
 *
 * Arguments:
 * - groups: Each run or drop, list(its group, its features).
 * - main: The direction the zone faces most, or null.
 * - anchor: The first drop, or null.
 */
/datum/dirt_feature/run_plan/New(list/groups, main, datum/dirt_feature/anchor)
	. = ..(null)
	src.groups = groups
	src.main = main
	src.anchor = anchor
