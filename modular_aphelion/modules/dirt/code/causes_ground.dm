/**
 * Returns a distance in pixels up a limb as h, the height along it: 0 at its lowest row, 1 at its highest.
 *
 * Arguments:
 * - limb: A DIRT_LIMB_* define.
 * - pixels: How many pixels up.
 */
/proc/dirt_up_h(limb, pixels)
	return pixels * dirt_metric(limb)[2]

/**
 * Returns which side of the body a limb is on: 1 for the right, -1 for the left.
 *
 * Arguments:
 * - limb: A DIRT_LIMB_* define.
 */
/proc/dirt_limb_side(limb)
	return (limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_R_ARM) ? 1 : -1

/**
 * Returns both legs, the one on the dirtier side first.
 *
 * Arguments:
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_legs_by_side(side)
	RETURN_TYPE(/list)
	return side > 0 ? list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG) : list(DIRT_LIMB_L_LEG, DIRT_LIMB_R_LEG)

/**
 * Returns the hands' stamp levels: alist(hand zone = level), 3 at most. The dominant hand, on the dirtier side, is a
 * level ahead of the other until both reach 3.
 *
 * Arguments:
 * - side: The mob's dirtier side, 1 or -1.
 * - level: The dominant hand's level, before `plus`.
 * - plus: Levels both hands go up by.
 */
/proc/dirt_hands_levels(side, level, plus = 0)
	RETURN_TYPE(/alist)
	var/alist/levels = alist()
	levels[side > 0 ? BODY_ZONE_PRECISE_R_HAND : BODY_ZONE_PRECISE_L_HAND] = min(3, level + plus)
	levels[side > 0 ? BODY_ZONE_PRECISE_L_HAND : BODY_ZONE_PRECISE_R_HAND] = min(3, level - 1 + plus)
	return levels

/**
 * Returns a coat up a leg from its sole, and the height its line sits at: list(/datum/dirt_feature/coatline, pixels).
 * The line varies by variant and tilts at least 1.5 px from front to back. On the dirtier leg it rises 0.5, 1.5 and
 * 2 px by level, so level 1 stays contact only. It carries a tongue at levels 2 and 3. It stops 2.5 px under the leg's
 * top, so the belt never cuts it into a level row. The proc makes every random draw whatever the level.
 *
 * Arguments:
 * - rng: The deposit's stream.
 * - limb: The leg.
 * - level: 1 to 3.
 * - heights: The line's height by level, in pixels over the sole.
 * - solid: The contact's height by level, in pixels.
 * - dominant: Whether it's the dirtier leg.
 * - film: The film's depth under the line by level, in pixels.
 */
/proc/dirt_coat(datum/dirt_random/rng, limb, level, list/heights, list/solid, dominant, list/film)
	RETURN_TYPE(/list)
	var/static/list/rises = list(0.5, 1.5, 2)
	var/jitter = rng.uniform(-0.5, 0.5)
	var/tilt_sign = rng.choose(list(-1, 1))
	var/tilt = tilt_sign * rng.uniform(1.6, 2.2)
	var/tongue_theta = rng.uniform(-180, 180)
	var/tongue_height = rng.uniform(2, 3)
	var/tongue_width = rng.uniform(40, 55)
	var/side_sign = rng.choose(list(-1, 1))
	var/first_theta = side_sign * rng.uniform(30, 80)
	var/first_fraction = rng.uniform(0.3, 0.45)
	var/second_theta = -side_sign * rng.uniform(30, 80)
	var/second_fraction = rng.uniform(0.62, 0.8)
	var/cap = 1 / dirt_metric(limb)[2] - 2.5
	var/top = min(cap, heights[level] + jitter + (dominant ? rises[level] : 0))
	var/list/windows = list()
	if(level >= 2)
		windows += list(list(first_theta, first_fraction * top))
	if(level >= 3)
		windows += list(list(second_theta, second_fraction * top))
	var/list/tongue = level >= 2 ? list(tongue_theta, tongue_height, tongue_width) : null
	return list(new /datum/dirt_feature/coatline(limb, top, solid[level], tilt, tongue, film[level], windows), top)

/**
 * Returns specks kicked up round a calf, a little more at the back. Each sits 1.5 to 3.5 px over its coat's line,
 * after a clean pixel, and a few of them are drips. Five are drawn from the stream whatever the count.
 *
 * Arguments:
 * - rng: The deposit's stream.
 * - limb: The leg.
 * - line_px: The coat's line, in pixels over the sole.
 * - count: How many to keep, 5 at most.
 */
/proc/dirt_kickup(datum/dirt_random/rng, limb, line_px, count)
	RETURN_TYPE(/list)
	var/list/points = list()
	for(var/kick_number in 1 to 5)
		var/theta = rng.random() < 0.55 ? rng.gauss(DIRT_THETA_BACK, 70) : rng.uniform(-180, 180)
		var/rise = rng.uniform(1.5, 3.5)
		points += list(list(theta, rise, rng.random() < 0.4))
	var/list/specks = list()
	for(var/position in 1 to count)
		var/list/point = points[position]
		specks += new /datum/dirt_feature/speck(limb, point[1], dirt_up_h(limb, line_px + point[2]), point[3])
	return specks

/**
 * Returns what settles from above: film clusters on the shoulder tops, none at level 1, two at level 2, four at 3.
 *
 * Arguments:
 * - rng: The deposit's stream.
 * - level: The level.
 */
/proc/dirt_settled(datum/dirt_random/rng, level)
	RETURN_TYPE(/list)
	var/static/list/counts = list(0, 2, 4)
	var/list/spots = list()
	for(var/spot_number in 1 to 4)
		var/limb = rng.choose(list(DIRT_LIMB_TORSO, DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/theta = rng.uniform(-180, 180)
		spots += list(list(limb, theta, rng.uniform(0.86, 0.93)))
	var/list/features = list()
	for(var/position in 1 to counts[min(level, 3)])
		var/list/spot = spots[position]
		var/datum/dirt_feature/blob/cluster = new(spot[1], spot[2], spot[3], 0.9, 0.55, rng.randrange(65536), 0.1, 0, 0)
		cluster.role = DIRT_ROLE_FILM
		features += cluster
	return features

/**
 * Returns walking's features: a coat up from the soles with a jagged, tilted top and a tongue, film along its line,
 * and spaced specks kicked up over it. The dirtier leg's line sits higher.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_walk(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/static/list/kicks = list(0, 3, 5)
	var/list/heights = list(1.6)
	heights += rng.uniform(3.8, 4.8)
	heights += rng.uniform(5.5, 7)
	var/list/features = list()
	for(var/limb in list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG))
		var/list/coat = dirt_coat(rng, limb, level, heights, list(0, 0.4, 0.8), dirt_limb_side(limb) == side, list(1, 2, 2))
		features += coat[1]
		features += dirt_kickup(rng, limb, coat[2], kicks[level])
	return features

/**
 * Returns dust's features: a thin coat from the shoes, which a light material lifts (dirt_thin_light()). From level 2
 * dust settles on the knees and the shoulders, and at level 3 on the lap too.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_dust(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/heights = list(2)
	heights += rng.uniform(3.8, 4.8)
	heights += rng.uniform(5.5, 7)
	var/list/features = list()
	for(var/limb in list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG))
		var/list/coat = dirt_coat(rng, limb, level, heights, list(0.3, 0.6, 0.9), dirt_limb_side(limb) == side, list(1, 2, 2))
		features += coat[1]
		var/knee_theta = rng.gauss(DIRT_THETA_FRONT, 12)
		var/knee_seed = rng.randrange(65536)
		var/lap_theta = rng.gauss(DIRT_THETA_FRONT, 20)
		var/lap_seed = rng.randrange(65536)
		if(level >= 2)
			features += new /datum/dirt_feature/patch(limb, knee_theta, dirt_up_h(limb, 5.5), 1.4, 1.2, knee_seed, 1, 0.5)
		if(level >= 3)
			features += new /datum/dirt_feature/patch(limb, lap_theta, dirt_up_h(limb, 9), 1.8, 1, lap_seed, 1, 0.5)
	features += dirt_settled(rng, level)
	return features

/**
 * Returns kneeling's features. The kneeling knee, on the dirtier side, takes a patch from the kneecap down the shin,
 * with a small packed core on the kneecap and film up the thigh. The other knee takes a level less, with film down its
 * shin. The kneeling boot's toe cap and the fingertips take dirt too.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_kneel(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/features = list()
	for(var/limb in dirt_legs_by_side(side))
		var/dominant = dirt_limb_side(limb) == side
		var/leg_level = dominant ? level : level - 1
		var/theta = rng.gauss(DIRT_THETA_FRONT, 8)
		var/knee_up = rng.uniform(5.6, 6.2)
		var/seed = rng.randrange(65536)
		if(leg_level <= 0)
			continue
		var/along = dirt_up_h(limb, knee_up)
		switch(leg_level)
			if(1)
				features += new /datum/dirt_feature/blob(limb, theta, along, 0.6, 0.9, seed, 0.1)
			if(2)
				features += new /datum/dirt_feature/blob(limb, theta, along, 0.9, 1.3, seed, 0.15)
				if(dominant)
					features += new /datum/dirt_feature/contact(limb, theta, along)
			else
				features += new /datum/dirt_feature/stroke(limb, list(theta, along + dirt_up_h(limb, 0.5)), list(theta, dirt_up_h(limb, 1.6)), 2, 0.2)
				features += new /datum/dirt_feature/contact(limb, theta, along)
				features += new /datum/dirt_feature/patch(limb, theta, along + dirt_up_h(limb, 2.5), 1.4, 1.1, seed + 1, 0.5, 0.5)
		if(leg_level < 2)
			continue
		if(dominant)
			var/datum/dirt_feature/blob/toe = new(limb, DIRT_THETA_FRONT, dirt_up_h(limb, 0.5), 1, 0.6, seed + 2, 0.1, 0, 0)
			toe.role = DIRT_ROLE_FILM
			features += toe
		else
			var/datum/dirt_feature/stroke/shin = new(limb, list(theta, along - dirt_up_h(limb, 1)), list(theta, dirt_up_h(limb, 2)), 1, 0.3)
			shin.role = DIRT_ROLE_FILM
			features += shin
	features += new /datum/dirt_feature/stamps(side, 0, dirt_hands_levels(side, level))
	return features

/**
 * Returns crawling's features: kneeling's, then a broad, broken patch on the belly, off its middle because a streak
 * down the middle reads as a necktie. From level 2 the forearms' fronts take patches too.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_crawl(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/features = dirt_cause_kneel(level, rng, side)
	var/belly_theta = side * rng.uniform(15, 30)
	var/belly_along = rng.uniform(0.28, 0.4)
	var/belly_seed = rng.randrange(65536)
	var/list/arms = list()
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/arm_theta = rng.gauss(DIRT_THETA_FRONT, 20)
		arms += list(list(limb, arm_theta, rng.randrange(65536)))
	features += new /datum/dirt_feature/patch(DIRT_LIMB_TORSO, belly_theta, belly_along, 1.8 + 0.6 * level, 1 + 0.4 * level, belly_seed, 0.6 + 0.15 * level)
	if(level >= 2)
		for(var/list/arm as anything in arms)
			features += new /datum/dirt_feature/blob(arm[1], arm[2], 0.48, 0.9, 1.4, arm[3], 0.2)
	return features

/**
 * Returns everyday wear's features, as costume departments age clothes. Soiling darkens the collar, the cuffs, the
 * trouser hems over the boots and the pocket edges, on cloth only. Abrasion lightens the knees, the seat and the elbows
 * in the fleck tone, ringed in film so it marks light cloth too. At level 3 the dirtier thigh's front wears.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_wear(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/features = list()
	var/datum/dirt_feature/region/collar/collar = new(DIRT_LIMB_TORSO, 0.85, 40, DIRT_BODY_T)
	collar.cloth_only = TRUE
	features += collar
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/datum/dirt_feature/region/band/cuff = new(limb, 0.38, 0.48)
		cuff.cloth_only = TRUE
		features += cuff
	var/list/legs = list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG)
	var/list/pockets = list()
	for(var/limb in legs)
		var/pocket_theta = dirt_limb_side(limb) * rng.uniform(30, 50)
		pockets += list(list(pocket_theta, rng.uniform(0.86, 0.92)))
	for(var/leg_number in 1 to length(legs))
		var/limb = legs[leg_number]
		var/list/pocket = pockets[leg_number]
		var/dominant = dirt_limb_side(limb) == side
		var/knee_theta = rng.gauss(DIRT_THETA_FRONT, 10)
		var/knee_seed = rng.randrange(65536)
		var/datum/dirt_feature/region/band/hem = new(limb, dirt_up_h(limb, 4), dirt_up_h(limb, 5))
		hem.cloth_only = TRUE
		features += hem
		var/leg_level = dominant ? level : level - 1
		if(leg_level >= 1)
			var/datum/dirt_feature/patch/knee = new(limb, knee_theta, dirt_up_h(limb, 5.8), 1.1 + 0.3 * leg_level, 1 + 0.3 * leg_level, knee_seed, 1, 0.5)
			knee.role = DIRT_ROLE_FLECK
			knee.ring = TRUE
			features += knee
		if(level >= 2)
			var/datum/dirt_feature/stroke/pocket_edge = new(limb, list(pocket[1], pocket[2]), list(pocket[1] + 15, pocket[2] - 0.03), 0.8, 0)
			pocket_edge.cloth_only = TRUE
			features += pocket_edge
			var/datum/dirt_feature/patch/seat = new(limb, DIRT_THETA_BACK + dirt_limb_side(limb) * 12, dominant ? 0.92 : 0.86, 1.6, 1.1, rng.randrange(65536), 1, 0.5)
			seat.role = DIRT_ROLE_FLECK
			seat.ring = TRUE
			seat.cloth_only = TRUE
			features += seat
		if(level >= 3 && dominant)
			var/datum/dirt_feature/patch/thigh = new(limb, dirt_limb_side(limb) * 20, dirt_up_h(limb, 8), 2, 1.8, rng.randrange(65536), 0.8)
			thigh.cloth_only = TRUE
			features += thigh
	if(level >= 2)
		for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
			var/datum/dirt_feature/patch/elbow = new(limb, DIRT_THETA_BACK, 0.6, 0.8, 1, rng.randrange(65536), 0.7, 0.5)
			elbow.role = DIRT_ROLE_FLECK
			elbow.ring = TRUE
			features += elbow
	return features

/**
 * Returns a fall's features, in mud or dirt. The side that hit the ground, mostly the front, takes broad patches across
 * the torso, the thighs and the knees, and from level 2 the forearms. The hands that broke the fall take dirt too.
 * Drips run down from the torso's patch, with drops thrown round it. A fall forwards smudges the face from level 2.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_fall(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	// the torso patch's radii by level
	var/static/list/torso_radii = list(list(1.6, 1.3), list(2.8, 2.2), list(4, 3.2))
	var/static/list/drop_counts = list(1, 3, 6)
	var/roll = rng.random()
	var/impact = roll < 0.6 ? DIRT_THETA_FRONT : (roll < 0.85 ? DIRT_THETA_BACK : side * 90)
	var/torso_theta = impact + rng.gauss(0, 12)
	var/torso_along = rng.uniform(0.45, 0.6)
	var/torso_seed = rng.randrange(65536)
	var/list/legs = list()
	for(var/limb in list(DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG))
		var/leg_theta = impact + rng.gauss(0, 10)
		var/leg_up = rng.uniform(5.5, 7.5)
		legs += list(list(limb, leg_theta, leg_up, rng.randrange(65536)))
	var/list/arms = list()
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/arm_theta = impact + rng.gauss(0, 15)
		var/arm_along = rng.uniform(0.4, 0.55)
		arms += list(list(limb, arm_theta, arm_along, rng.randrange(65536)))
	var/list/drips = list()
	for(var/drip_number in 1 to 3)
		var/drip_theta = torso_theta + rng.uniform(-40, 40)
		drips += list(list(drip_theta, rng.uniform(0, 1)))
	var/list/drops = list()
	for(var/drop_number in 1 to 6)
		var/drop_limb = rng.choose(list(DIRT_LIMB_TORSO, DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/drop_theta = impact + rng.gauss(0, 55)
		drops += list(list(drop_limb, drop_theta, rng.uniform(0.3, 0.95)))
	var/list/radii = torso_radii[level]
	var/list/features = list(new /datum/dirt_feature/patch(DIRT_LIMB_TORSO, torso_theta, torso_along, radii[1], radii[2], torso_seed, 0.95))
	for(var/list/leg as anything in legs)
		var/limb = leg[1]
		var/leg_level = dirt_limb_side(limb) == side ? level : level - 1
		if(leg_level >= 1)
			features += new /datum/dirt_feature/patch(limb, leg[2], dirt_up_h(limb, leg[3]), 1.3 + 0.4 * leg_level, 1.6 + 0.9 * leg_level, leg[4], 0.9)
	if(level >= 2)
		for(var/list/arm as anything in arms)
			features += new /datum/dirt_feature/patch(arm[1], arm[2], arm[3], 1.2 + 0.3 * level, 1.4 + 0.4 * level, arm[4], 0.9)
	var/torso_along_per_pixel = dirt_metric(DIRT_LIMB_TORSO)[2]
	for(var/position in 1 to level)
		var/list/drip = drips[position]
		var/top = torso_along - radii[2] * torso_along_per_pixel * (0.6 + 0.4 * drip[2])
		features += new /datum/dirt_feature/speck(DIRT_LIMB_TORSO, drip[1], top, TRUE, FALSE)
	for(var/position in 1 to drop_counts[level])
		var/list/drop = drops[position]
		features += new /datum/dirt_feature/speck(drop[1], drop[2], drop[3], FALSE, FALSE)
	features += new /datum/dirt_feature/stamps(side, impact == DIRT_THETA_FRONT ? level - 1 : 0, dirt_hands_levels(side, level, 1))
	return features

/**
 * Returns a splash's features (a kicked puddle, a passing cart, a burst pipe), from the front or from 60 degrees
 * toward the dirtier side. The drops lie on the side facing it, mostly on the upper body and arms and about one in six
 * on the legs. Some run as drips, and level 3 adds two bigger splats.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_splash(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/static/list/drop_counts = list(4, 7, 12)
	var/facing = rng.choose(list(DIRT_THETA_FRONT, side * 60))
	var/list/drops = list()
	for(var/drop_number in 1 to 12)
		var/limb = rng.choices(list(DIRT_LIMB_TORSO, DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM, DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG), list(6, 2, 2, 1, 1))
		var/along = limb == DIRT_LIMB_TORSO ? rng.uniform(0.35, 0.97) : rng.uniform(0.4, 0.95)
		var/drop_theta = facing + rng.gauss(0, 45)
		drops += list(list(limb, drop_theta, along, rng.random() < 0.35))
	var/list/splats = list()
	for(var/splat_number in 1 to 2)
		var/splat_theta = facing + rng.gauss(0, 30)
		var/splat_along = rng.uniform(0.5, 0.85)
		splats += list(list(splat_theta, splat_along, rng.randrange(65536)))
	var/list/features = list()
	for(var/position in 1 to drop_counts[level])
		var/list/drop = drops[position]
		features += new /datum/dirt_feature/speck(drop[1], drop[2], drop[3], drop[4], FALSE)
	if(level >= 3)
		for(var/list/splat as anything in splats)
			features += new /datum/dirt_feature/blob(DIRT_LIMB_TORSO, splat[1], splat[2], 0.9, 0.8, splat[3], 0.3, 0, 0.4)
	return features
