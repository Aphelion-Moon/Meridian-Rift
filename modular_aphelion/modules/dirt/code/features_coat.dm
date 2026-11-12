/**
 * A coat up from a limb's lower end. It's contact at the bottom and body up to a jagged line. The line tilts from front
 * to back, and at levels 2 and 3 it rises in a tongue with a film tip. Film runs along under the line, so the coat's
 * edge follows the line and is never one level row. One or two 1x2 film windows break the body.
 */
/datum/dirt_feature/coatline
	/// The line's height over the limb's lower end, in pixels, before its tilt and tongue.
	var/top_px
	/// Pixels up from the lower end that are contact.
	var/solid_px
	/// How much higher the line sits at the front than at the back, in pixels.
	var/tilt_px
	/// The tongue: list(theta, height in pixels, half width in degrees), or null.
	var/list/tongue
	/// How many pixels of film run under the line.
	var/film_px
	/// Each window: list(theta, pixels up).
	var/list/windows

/**
 * Starts a coat.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - top_px: The line's height over the limb's lower end, in pixels, before its tilt and tongue.
 * - solid_px: Pixels up from the lower end that are contact.
 * - tilt_px: How much higher the line sits at the front than at the back, in pixels.
 * - tongue: list(theta, height in pixels, half width in degrees), or null.
 * - film_px: How many pixels of film run under the line.
 * - windows: Each window, list(theta, pixels up), or null.
 */
/datum/dirt_feature/coatline/New(limb, top_px, solid_px, tilt_px = 0, list/tongue = null, film_px = 1, list/windows = null)
	. = ..(limb)
	src.top_px = top_px
	src.solid_px = solid_px
	src.tilt_px = tilt_px
	src.tongue = tongue
	src.film_px = film_px
	src.windows = windows
	// the line's highest point, and a pixel to spare
	reach_high = (max(solid_px, top_px + abs(tilt_px) / 2 + (tongue ? tongue[2] : 0)) + 1) * along_per_pixel

/**
 * Returns the line's height at a theta, in pixels, with its tilt and with its tongue rising toward the tongue's theta.
 *
 * Arguments:
 * - theta: Degrees round the limb.
 */
/datum/dirt_feature/coatline/proc/line_px(theta)
	var/top = top_px + tilt_px * cos(theta) / 2
	if(tongue)
		var/turn = theta - tongue[1]
		var/closeness = max(0, 1 - abs(DIRT_WRAP_DEGREES(turn)) / tongue[3])
		top += tongue[2] * min(1, closeness * 1.6)
	return top

/**
 * Returns contact up to solid_px, nothing over the line, film just under it and in the windows, and body between.
 */
/datum/dirt_feature/coatline/thickness(theta, along)
	var/up = along / along_per_pixel
	if(up <= solid_px)
		return 1
	var/depth = line_px(theta) - up
	if(depth < 0)
		return 0
	if(depth < film_px)
		return DIRT_FILM_T
	for(var/list/window as anything in windows)
		var/turn = theta - window[1]
		var/window_up = up - window[2]
		if(abs(DIRT_WRAP_DEGREES(turn)) / degrees_per_pixel < 0.5 && window_up > -1 && window_up <= 1)
			return DIRT_FILM_T
	return DIRT_BODY_T

/**
 * An irregular patch whose outline wobbles round it, with a film ring past it. Its middle may be contact (a kneecap).
 *
 * As in the reference generator, a blob whose ring has a width is ringed too (/datum/dirt_feature/var/ring), so a
 * broken film ring also runs round it.
 */
/datum/dirt_feature/blob
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
	/// How far out from its middle it's contact, as a fraction of its radius: 0 for none.
	var/contact
	/// How far its film ring reaches past its outline, as a fraction of its radius: 0 for none.
	var/ring_width

/**
 * Starts a blob.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta at its middle.
 * - along: The h at its middle.
 * - radius_x: Its radius round the limb, in pixels.
 * - radius_y: Its radius up the limb, in pixels.
 * - seed: The seed of the noise its outline wobbles by, a whole number.
 * - ragged: How far its outline wobbles, as a fraction of its radius.
 * - contact: How far out from its middle it's contact, as a fraction of its radius.
 * - ring_width: How far its film ring reaches past its outline, as a fraction of its radius.
 */
/datum/dirt_feature/blob/New(limb, theta, along, radius_x, radius_y, seed, ragged = 0.25, contact = 0, ring_width = 0.35)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	src.radius_x = radius_x
	src.radius_y = radius_y
	src.seed = seed
	src.ragged = ragged
	src.contact = contact
	src.ring_width = ring_width
	ring = ring_width != 0
	// its widest wobble and ring, and half a pixel to spare
	var/spread = (1 + ring_width) * (1 + ragged)
	reach_theta = theta
	reach_degrees = (spread * radius_x + 0.5) * degrees_per_pixel
	var/reach_along = (spread * radius_y + 0.5) * along_per_pixel
	reach_low = along - reach_along
	reach_high = along + reach_along

/**
 * Returns contact inside `contact`, body inside the wobbling outline, and film in its ring.
 */
/datum/dirt_feature/blob/thickness(theta, along)
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	// the outline wobbles between five points round it, blended smoothly
	var/angle = arctan(across, up)
	if(angle < 0)
		angle += 360
	var/sector = angle / 360 * 5
	var/sector_index = floor(sector)
	var/blend = sector - sector_index
	blend = blend * blend * (3 - 2 * blend)
	var/start = dirt_noise_hash(sector_index % 5, 0, seed)
	var/finish = dirt_noise_hash((sector_index + 1) % 5, 0, seed)
	var/wobble = 1 + ragged * ((start + (finish - start) * blend) * 2 - 1)
	var/stretched_across = across / radius_x
	var/stretched_up = up / radius_y
	var/distance = sqrt(stretched_across * stretched_across + stretched_up * stretched_up) / wobble
	if(distance < contact)
		return 1
	if(distance < 1)
		return DIRT_BODY_T
	if(distance < 1 + ring_width)
		return DIRT_FILM_T
	return 0

/**
 * A worn-in patch that breaks up toward its edge with noise. Below full strength it draws film only.
 */
/datum/dirt_feature/patch
	/// The theta at its middle.
	var/centre_theta
	/// The h at its middle.
	var/centre_along
	/// Its radius round the limb, in pixels.
	var/radius_x
	/// Its radius up the limb, in pixels.
	var/radius_y
	/// The seed of the noise it breaks up by.
	var/seed
	/// How much of it is drawn at its middle, from 0 to 1.
	var/density
	/// 1 to draw body where it's thickest, less for film only.
	var/strength
	/// The noise's lattice spacing, in pixels.
	var/scale

/**
 * Starts a patch.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta at its middle.
 * - along: The h at its middle.
 * - radius_x: Its radius round the limb, in pixels.
 * - radius_y: Its radius up the limb, in pixels.
 * - seed: The seed of the noise it breaks up by, a whole number.
 * - density: How much of it is drawn at its middle, from 0 to 1.
 * - strength: 1 to draw body where it's thickest, less for film only.
 * - scale: The noise's lattice spacing, in pixels.
 */
/datum/dirt_feature/patch/New(limb, theta, along, radius_x, radius_y, seed, density = 1, strength = 1, scale = 2.6)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	src.radius_x = radius_x
	src.radius_y = radius_y
	src.seed = seed
	src.density = density
	src.strength = strength
	src.scale = scale
	// nothing past 1.3 radii, and half a pixel to spare
	reach_theta = theta
	reach_degrees = (1.3 * radius_x + 0.5) * degrees_per_pixel
	var/reach_along = (1.3 * radius_y + 0.5) * along_per_pixel
	reach_low = along - reach_along
	reach_high = along + reach_along

/**
 * Returns film where its noise passes a bar rising toward its edge, or body where the noise is high at full strength.
 */
/datum/dirt_feature/patch/thickness(theta, along)
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel / radius_x
	var/up = (along - centre_along) / along_per_pixel / radius_y
	var/distance = sqrt(across * across + up * up)
	if(distance >= 1.3)
		return 0
	var/drawn = (1 - (distance / 1.3) ** 1.5) * density
	var/noise = noise(theta / degrees_per_pixel, along / along_per_pixel, seed, scale)
	if(noise <= 1 - drawn)
		return 0
	return (strength >= 1 && noise > 1 - drawn * 0.5) ? DIRT_BODY_T : DIRT_FILM_T

/**
 * An even tone over a whole limb. Its subtypes keep to part of it.
 */
/datum/dirt_feature/region
	/// How thick it lies: DIRT_FILM_T or DIRT_BODY_T.
	var/value

/**
 * Starts a tone.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - value: How thick it lies.
 */
/datum/dirt_feature/region/New(limb, value = DIRT_FILM_T)
	. = ..(limb)
	src.value = value

/**
 * Returns its value wherever it lies on its limb (covers()).
 */
/datum/dirt_feature/region/thickness(theta, along)
	return covers(theta, along) ? value : 0

/**
 * Returns whether the tone lies on a point of its limb. A plain tone lies everywhere.
 *
 * Arguments:
 * - theta: Degrees round the limb.
 * - along: h along the limb.
 */
/datum/dirt_feature/region/proc/covers(theta, along)
	return TRUE

/**
 * A tone in a band round a limb, between two heights: a cuff, a hem.
 */
/datum/dirt_feature/region/band
	/// The h it lies over, not on.
	var/low
	/// The h it lies under, not on.
	var/high

/**
 * Starts a band.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - low: The h it lies over, not on.
 * - high: The h it lies under, not on.
 * - value: How thick it lies.
 */
/datum/dirt_feature/region/band/New(limb, low, high, value = DIRT_FILM_T)
	. = ..(limb, value)
	src.low = low
	src.high = high
	reach_low = low
	reach_high = high

/// Returns whether a point lies between its two heights, on neither.
/datum/dirt_feature/region/band/covers(theta, along)
	return along > low && along < high

/**
 * A tone over a limb's top, on its front, and on its back too where it reaches there: a collar.
 */
/datum/dirt_feature/region/collar
	/// The h it lies over, not on.
	var/low
	/// How many degrees either side of the front it reaches, up to but not on that angle.
	var/half_turn
	/// How many degrees either side of the back it reaches, up to but not on that angle, or 0 for none.
	var/back_turn

/**
 * Starts a collar.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - low: The h it lies over, not on.
 * - half_turn: How many degrees either side of the front it reaches, up to but not on that angle.
 * - value: How thick it lies.
 * - back_turn: How many degrees either side of the back it reaches, up to but not on that angle, or 0 for none.
 */
/datum/dirt_feature/region/collar/New(limb, low, half_turn, value = DIRT_FILM_T, back_turn = 0)
	. = ..(limb, value)
	src.low = low
	src.half_turn = half_turn
	src.back_turn = back_turn
	reach_low = low
	if(!back_turn)
		reach_degrees = half_turn

/// Returns whether a point is over `low`, and within half_turn of the front or back_turn of the back.
/datum/dirt_feature/region/collar/covers(theta, along)
	var/turn = abs(DIRT_WRAP_DEGREES(theta))
	return along > low && (turn < half_turn || turn > 180 - back_turn)

/**
 * What settles from above: a coat down from a limb's top. It's deepest on the side it faces, and the back takes `back`
 * of its depth. It reaches a pixel and a half deeper on the dirtier side, and large noise roughens its lower edge. It's
 * body over the top `body_fraction` of it, film under that, then a haze fringe: a gradient, never a bib with a hard
 * hem. Bare skin takes it broken: a step lighter, with about half the skin left clean.
 */
/datum/dirt_feature/mantle
	/// How many pixels down it reaches on the side it faces.
	var/depth_px
	/// The theta it faces.
	var/facing
	/// The seed of the noise its edge wanders by.
	var/seed
	/// The mob's dirtier side, 1 or -1, or 0 for neither.
	var/side
	/// How much of its depth reaches round the back.
	var/back
	/// How much of its depth, from the top, is body.
	var/body_fraction
	/// Whether it's broken and a step lighter, as bare skin takes it.
	var/broken

/**
 * Starts a coat from above.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - depth_px: How many pixels down it reaches on the side it faces.
 * - facing: The theta it faces.
 * - seed: The seed of the noise its edge wanders by, a whole number.
 * - side: The mob's dirtier side, 1 or -1, or 0 for neither.
 * - back: How much of its depth reaches round the back.
 * - body_fraction: How much of its depth, from the top, is body.
 * - broken: Whether it's broken and a step lighter.
 */
/datum/dirt_feature/mantle/New(limb, depth_px, facing, seed, side = 0, back = 0.45, body_fraction = 0.4, broken = FALSE)
	. = ..(limb)
	src.depth_px = depth_px
	src.facing = facing
	src.seed = seed
	src.side = side
	src.back = back
	src.body_fraction = body_fraction
	src.broken = broken
	// its depth, then 0.75 px for the dirtier side, 1.5 px of noise, a pixel of haze and half a pixel to spare
	reach_low = 1 - (depth_px + 3.75) * along_per_pixel

/**
 * Returns body down to its body fraction, film to its depth, and haze a pixel past that. A broken mantle is a step
 * lighter and draws only where its own noise leaves it, and the shoulder tops keep a little more of it.
 */
/datum/dirt_feature/mantle/thickness(theta, along)
	var/down = (1 - along) / along_per_pixel
	var/turn = theta - facing
	var/faced = (1 + cos(turn)) / 2
	var/depth = depth_px * (back + (1 - back) * faced)
	depth += side * 0.75 * (1 + sin(theta) * side) - 0.75 * abs(side)
	depth += (noise(theta / degrees_per_pixel, along / along_per_pixel, seed, 4) - 0.5) * 3
	if(down > depth + 1)
		return 0
	var/thickness = down > depth ? DIRT_HAZE_T : (down > depth * body_fraction ? DIRT_FILM_T : DIRT_BODY_T)
	if(!broken)
		return thickness
	var/noise = noise(theta / degrees_per_pixel * 0.8, along / along_per_pixel, seed + 77, 3.5)
	if(noise + (along > 0.88 ? 0.25 : 0) < 0.45)
		return 0
	return thickness >= DIRT_BODY_T ? DIRT_FILM_T : (thickness >= DIRT_FILM_T ? DIRT_HAZE_T : 0)

/**
 * Where cloth soaks through with sweat. It's wettest in the middle with a soft rim, and large noise makes its outline
 * wander, since sweat wicks out unevenly and is never round or level. Its shape (/datum/dirt_shape) gives each point's
 * distance from the middle, 1 at the edge. Sweat has no contact point, so a soaked core, if the patch has one, is the
 * one darkest role in its middle.
 */
/datum/dirt_feature/damp
	/// The theta it's anchored at.
	var/anchor_theta
	/// The h it's anchored at.
	var/anchor_along
	/// Its /datum/dirt_shape, from the anchor.
	var/datum/dirt_shape/shape
	/// The seed of the noise its outline wanders by.
	var/seed
	/// The distance body reaches to.
	var/body
	/// The distance the soaked core reaches to: 0 for none.
	var/core
	/// How far its outline wanders.
	var/ragged

/**
 * Starts a damp patch.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta it's anchored at.
 * - along: The h it's anchored at.
 * - shape: Its /datum/dirt_shape, from the anchor.
 * - seed: The seed of the noise its outline wanders by, a whole number.
 * - body: The distance body reaches to.
 * - core: The distance the soaked core reaches to: 0 for none.
 * - ragged: How far its outline wanders.
 */
/datum/dirt_feature/damp/New(limb, theta, along, datum/dirt_shape/shape, seed, body = 0.6, core = 0, ragged = 0.28)
	. = ..(limb)
	anchor_theta = theta
	anchor_along = along
	src.shape = shape
	src.seed = seed
	src.body = body
	src.core = core
	src.ragged = ragged
	// nothing past 1.6, and half a pixel to spare
	var/list/extent = shape.extent
	reach_theta = theta + (extent[1] + extent[2]) / 2 * degrees_per_pixel
	reach_degrees = ((extent[2] - extent[1]) / 2 + 0.5) * degrees_per_pixel
	reach_low = along + (extent[3] - 0.5) * along_per_pixel
	reach_high = along + (extent[4] + 0.5) * along_per_pixel

/**
 * Returns the soaked core, body, film to the edge and haze 0.2 past it. The outline wanders past a distance of 0.45.
 */
/datum/dirt_feature/damp/thickness(theta, along)
	var/turn = theta - anchor_theta
	var/distance = shape.distance(DIRT_WRAP_DEGREES(turn) / degrees_per_pixel, (along - anchor_along) / along_per_pixel)
	if(distance > 1.6)
		return 0
	// the outline wanders but the middle stays one mass, because light islands read as a print
	var/edge = clamp((distance - 0.45) / 0.4, 0, 1)
	distance += (noise(theta / degrees_per_pixel, along / along_per_pixel, seed, 2.4) - 0.5) * 2 * ragged * edge
	if(distance < core)
		return DIRT_CONTACT + 0.05
	if(distance < body)
		return DIRT_BODY_T
	if(distance < 1)
		return DIRT_FILM_T
	if(distance < 1.2)
		return DIRT_HAZE_T
	return 0

/**
 * A damp patch's shape. It gives each point's distance from the shape's middle, 1 at its edge. A point is given in
 * pixels round the limb and up it from where the patch is anchored.
 */
/datum/dirt_shape
	/// Where its distance is 1.6 or less, in pixels from the anchor: list(least across, most across, least up, most up).
	var/list/extent

/**
 * Returns a point's distance from the shape's middle, 1 at its edge.
 *
 * Arguments:
 * - across: Pixels round the limb from the anchor.
 * - up: Pixels up the limb from the anchor.
 */
/datum/dirt_shape/proc/distance(across, up)
	return INFINITY

/**
 * An ellipse about the anchor, longer below it where sweat runs down a side seam.
 */
/datum/dirt_shape/ellipse
	/// Its radius round the limb, in pixels.
	var/radius_x
	/// Its radius up from the anchor, in pixels.
	var/radius_up
	/// Its radius down from the anchor, in pixels.
	var/radius_down

/**
 * Starts an ellipse.
 *
 * Arguments:
 * - radius_x: Its radius round the limb, in pixels.
 * - radius_up: Its radius up from the anchor, in pixels.
 * - radius_down: Its radius down from the anchor, in pixels, or null for radius_up.
 */
/datum/dirt_shape/ellipse/New(radius_x, radius_up, radius_down = null)
	. = ..()
	src.radius_x = radius_x
	src.radius_up = radius_up
	src.radius_down = radius_down || radius_up
	extent = list(-1.6 * radius_x, 1.6 * radius_x, -1.6 * src.radius_down, 1.6 * radius_up)

/// Returns its stretched distance from the anchor, using the radius up or down for the side the point lies on.
/datum/dirt_shape/ellipse/distance(across, up)
	var/stretched_across = across / radius_x
	var/stretched_up = up / (up > 0 ? radius_up : radius_down)
	return sqrt(stretched_across * stretched_across + stretched_up * stretched_up)

/**
 * An ellipse whose middle sits off the anchor: a wing of a butterfly.
 */
/datum/dirt_shape/ellipse_at
	/// Pixels round the limb from the anchor to its middle.
	var/centre_across
	/// Pixels up the limb from the anchor to its middle.
	var/centre_up
	/// Its radius round the limb, in pixels.
	var/radius_x
	/// Its radius up the limb, in pixels.
	var/radius_y

/**
 * Starts an ellipse off the anchor.
 *
 * Arguments:
 * - centre_across: Pixels round the limb from the anchor to its middle.
 * - centre_up: Pixels up the limb from the anchor to its middle.
 * - radius_x: Its radius round the limb, in pixels.
 * - radius_y: Its radius up the limb, in pixels.
 */
/datum/dirt_shape/ellipse_at/New(centre_across, centre_up, radius_x, radius_y)
	. = ..()
	src.centre_across = centre_across
	src.centre_up = centre_up
	src.radius_x = radius_x
	src.radius_y = radius_y
	extent = list(centre_across - 1.6 * radius_x, centre_across + 1.6 * radius_x, centre_up - 1.6 * radius_y, centre_up + 1.6 * radius_y)

/// Returns its stretched distance from the middle.
/datum/dirt_shape/ellipse_at/distance(across, up)
	var/stretched_across = (across - centre_across) / radius_x
	var/stretched_up = (up - centre_up) / radius_y
	return sqrt(stretched_across * stretched_across + stretched_up * stretched_up)

/**
 * A shape hanging from its anchor, such as the V under a collar or a sweaty spine. It's `width` px either side at the
 * top, and narrows by `taper` toward its rounded end `hang_length` px down. It's rounded over the anchor too.
 */
/datum/dirt_shape/hanging
	/// Pixels either side at the top.
	var/width
	/// Pixels down to its end.
	var/hang_length
	/// How much of its width it loses by its end.
	var/taper

/**
 * Starts a hanging shape.
 *
 * Arguments:
 * - width: Pixels either side at the top.
 * - hang_length: Pixels down to its end.
 * - taper: How much of its width it loses by its end.
 */
/datum/dirt_shape/hanging/New(width, hang_length, taper = 0.75)
	. = ..()
	src.width = width
	src.hang_length = hang_length
	src.taper = taper
	extent = list(-1.6 * width, 1.6 * width, -1.6 * hang_length, 1.28)

/// Returns a distance rounded over the anchor, and under it a rounded square's as the shape narrows toward its end.
/datum/dirt_shape/hanging/distance(across, up)
	var/drop = -up
	if(drop < 0)
		var/stretched_across = across / width
		var/stretched_up = drop / 0.8
		return sqrt(stretched_across * stretched_across + stretched_up * stretched_up)
	var/narrowed = width * (1 - taper * min(1, drop / hang_length))
	return ((abs(across) / narrowed) ** 3 + (drop / hang_length) ** 3) ** (1 / 3)

/**
 * Several shapes as one. Each point's distance is the least of theirs.
 */
/datum/dirt_shape/union
	/// Its /datum/dirt_shape parts.
	var/list/parts

/**
 * Starts several shapes as one.
 *
 * Arguments:
 * - parts: Its /datum/dirt_shape parts, one at least.
 */
/datum/dirt_shape/union/New(list/parts)
	. = ..()
	src.parts = parts
	var/datum/dirt_shape/first = parts[1]
	extent = first.extent.Copy()
	for(var/datum/dirt_shape/part as anything in parts)
		var/list/part_extent = part.extent
		extent[1] = min(extent[1], part_extent[1])
		extent[2] = max(extent[2], part_extent[2])
		extent[3] = min(extent[3], part_extent[3])
		extent[4] = max(extent[4], part_extent[4])

/// Returns the least of its parts' distances.
/datum/dirt_shape/union/distance(across, up)
	. = INFINITY
	for(var/datum/dirt_shape/part as anything in parts)
		. = min(., part.distance(across, up))

/**
 * A shape widened on one side and narrowed on the other. A positive skew widens it round the limb's way. Mirrored
 * halves of a back read as a printed butterfly, so a back's shape is skewed.
 */
/datum/dirt_shape/skew
	/// The shape it changes.
	var/datum/dirt_shape/inner
	/// How much wider it is round the limb's way, and narrower the other.
	var/skew

/**
 * Starts a skewed shape.
 *
 * Arguments:
 * - inner: The shape it changes.
 * - skew: How much wider it is round the limb's way, and narrower the other, between -1 and 1.
 */
/datum/dirt_shape/skew/New(datum/dirt_shape/inner, skew)
	. = ..()
	src.inner = inner
	src.skew = skew
	var/list/inner_extent = inner.extent
	extent = list(min(0, inner_extent[1] / (1 + skew)), max(0, inner_extent[2] / (1 - skew)), inner_extent[3], inner_extent[4])

/// Returns the inner shape's distance, with `across` scaled down on the skewed side and up on the other.
/datum/dirt_shape/skew/distance(across, up)
	return inner.distance(across > 0 ? across * (1 - skew) : across * (1 + skew), up)

/**
 * Haze up a limb from its lower end, over the pixels a stamp leaves (a dark hand), so the stamp fades into the
 * forearm rather than ending at a line.
 */
/datum/dirt_feature/fade
	/// Pixels up the limb where the stamp's film ends. The haze starts a pixel under it.
	var/film_to
	/// Pixels up the limb where the haze ends, not on it.
	var/haze_to

/**
 * Starts a fade.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - film_to: Pixels up the limb where the stamp's film ends.
 * - haze_to: Pixels up the limb where the haze ends.
 */
/datum/dirt_feature/fade/New(limb, film_to, haze_to)
	. = ..(limb)
	src.film_to = film_to
	src.haze_to = haze_to
	reach_low = (film_to - 1) * along_per_pixel
	reach_high = haze_to * along_per_pixel

/**
 * Returns haze from a pixel under where the stamp's film ends, up to where the haze ends.
 */
/datum/dirt_feature/fade/thickness(theta, along)
	var/up = along / along_per_pixel
	return (up >= film_to - 1 && up < haze_to) ? DIRT_HAZE_T : 0

/**
 * A contact point, where the full darkness belongs. It's an upright 1x2 (a kneecap), so the cleanup can't fold it.
 */
/datum/dirt_feature/contact
	/// The theta it sits at.
	var/centre_theta
	/// The h it sits at.
	var/centre_along

/**
 * Starts a contact point.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta it sits at.
 * - along: The h it sits at.
 */
/datum/dirt_feature/contact/New(limb, theta, along)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	// half a pixel across and a pixel up and down, and half a pixel to spare
	reach_theta = theta
	reach_degrees = degrees_per_pixel
	reach_low = along - 1.5 * along_per_pixel
	reach_high = along + 1.5 * along_per_pixel

/**
 * Returns full thickness on its upright 1x2, and nothing elsewhere.
 */
/datum/dirt_feature/contact/thickness(theta, along)
	var/turn = theta - centre_theta
	var/up = (along - centre_along) / along_per_pixel
	return (abs(DIRT_WRAP_DEGREES(turn)) / degrees_per_pixel < 0.5 && up > -1 && up <= 1) ? 1 : 0

/**
 * One speck: a body pixel, or a 1x2 film drip. Specks are drawn after the coats and kept clear of them and of each
 * other (dirt_scatter()). A strict speck (kicked up) never shares a row or a column with another. A loose one
 * (splashed) only keeps a pixel clear.
 */
/datum/dirt_feature/speck
	scatter = TRUE
	/// The theta it sits at.
	var/centre_theta
	/// The h it sits at.
	var/centre_along
	/// Whether it's a drip.
	var/drip
	/// Whether it keeps off the rows and columns of the strict specks before it.
	var/strict

/**
 * Starts a speck.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: The theta it sits at.
 * - along: The h it sits at.
 * - drip: Whether it's a drip.
 * - strict: Whether it keeps off the rows and columns of the strict specks before it.
 */
/datum/dirt_feature/speck/New(limb, theta, along, drip, strict = TRUE)
	. = ..(limb)
	centre_theta = theta
	centre_along = along
	src.drip = drip
	src.strict = strict
	// a drip's pixel and the one under it, and half a pixel to spare
	reach_theta = theta
	reach_degrees = 1.1 * degrees_per_pixel
	reach_low = along - 1.6 * along_per_pixel
	reach_high = along + 1.1 * along_per_pixel

/**
 * Returns a drip's film over the pixel it sits on and the one under it, or a speck's body on the pixel it sits on.
 */
/datum/dirt_feature/speck/thickness(theta, along)
	var/turn = theta - centre_theta
	var/across = DIRT_WRAP_DEGREES(turn) / degrees_per_pixel
	var/up = (along - centre_along) / along_per_pixel
	if(drip)
		return (abs(across) < 0.55 && up > -1.05 && up < 0.55) ? DIRT_FILM_T : 0
	return sqrt(across * across + up * up) < 0.6 ? DIRT_BODY_T : 0
