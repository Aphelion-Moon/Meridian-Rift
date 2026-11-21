/**
 * Returns machine work's features, in oil or grease. The fingertips take dirt, and below level 3 the dominant hand
 * takes a level more. Parallel wipes run from the hip down the outer thigh, on cloth. From level 2 it adds a belly wipe
 * and a cheek smudge. At level 3 both hands go dark past the wrist, with smears up the forearms. The dirtier thigh
 * takes wider wipes over a worn patch, and the trouser fronts grey over. The belly and chest smears reach bare skin as
 * film. Level 4 turns solid, black past the wrist. Its random draws are made after all the others.
 *
 * Arguments:
 * - level: 1 to 4.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_machine(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/alist/hands = dirt_hands_levels(side, min(level, 3), 1)
	if(level >= 3)
		// a mechanic's hands, and at level 4 solid to the wrist
		var/hand_level = level >= 4 ? 5 : 4
		hands = alist(BODY_ZONE_PRECISE_R_HAND = hand_level, BODY_ZONE_PRECISE_L_HAND = hand_level)
	var/list/features = list(new /datum/dirt_feature/stamps(side, level >= 3 ? level : level - 1, hands, level >= 4 ? 3 : 0, level >= 4))
	var/arm = side > 0 ? DIRT_LIMB_R_ARM : DIRT_LIMB_L_ARM
	var/other_arm = side > 0 ? DIRT_LIMB_L_ARM : DIRT_LIMB_R_ARM
	var/streak_theta = rng.gauss(DIRT_THETA_FRONT, 30)
	var/streak_along = rng.uniform(0.34, 0.4)
	var/second_theta = rng.gauss(DIRT_THETA_FRONT, 40)
	var/second_along = rng.uniform(0.42, 0.48)
	// each list(limb, top px, tilt px, tongue)
	var/list/wrists = list()
	for(var/list/wrist as anything in list(list(arm, 3.6), list(other_arm, 3)))
		var/top = wrist[2] + rng.uniform(-0.3, 0.3)
		var/tilt_sign = rng.choose(list(-1, 1))
		var/tilt = tilt_sign * rng.uniform(1, 1.6)
		var/tongue_theta = rng.uniform(-180, 180)
		var/tongue_height = rng.uniform(1, 1.6)
		wrists += list(list(wrist[1], top, tilt, list(tongue_theta, tongue_height, rng.uniform(40, 60))))
	var/third_theta = rng.gauss(DIRT_THETA_FRONT, 30)
	var/third_along = rng.uniform(0.36, 0.44)
	if(level >= 3)
		features += new /datum/dirt_feature/stroke(arm, list(streak_theta, streak_along), list(streak_theta + 20, streak_along + 0.16), 1.5, 0.3)
		features += new /datum/dirt_feature/stroke(arm, list(second_theta, second_along), list(second_theta - 15, second_along + 0.14), 1.3, 0.4, TRUE, 1)
		features += new /datum/dirt_feature/stroke(other_arm, list(third_theta, third_along), list(third_theta - 18, third_along + 0.12), 1.2, 0.4)
		// haze over the wrist, because a cuff line reads as a glove
		for(var/list/wrist as anything in wrists)
			features += new /datum/dirt_feature/fade(wrist[1], wrist[2] + 0.6, wrist[2] + 2.2)
	var/thigh_theta = side * rng.uniform(35, 55)
	var/thigh_up = rng.uniform(6, 7.2)
	var/thigh_seed = rng.randrange(65536)
	var/other_thigh_theta = -side * rng.uniform(30, 50)
	var/other_thigh_up = rng.uniform(5.8, 7)
	var/other_thigh_seed = rng.randrange(65536)
	// the right leg's, then the left's
	var/list/front_seeds = list()
	front_seeds += rng.randrange(65536)
	front_seeds += rng.randrange(65536)
	var/rag_theta = side * rng.uniform(55, 75)
	var/rag_along = rng.uniform(0.9, 0.95)
	var/list/legs = dirt_legs_by_side(side)
	for(var/leg_number in 1 to 2)
		var/limb = legs[leg_number]
		var/theta = dirt_limb_side(limb) * rng.uniform(45, 70)
		var/start_along = rng.uniform(0.84, 0.95)
		var/wipe_length = rng.uniform(2.6, 3.4)
		var/drift_sign = rng.choose(list(-1, 1))
		var/drift = drift_sign * rng.uniform(18, 26)
		if(leg_number == 2 && level < 3)
			continue
		var/count = level < 3 ? level : (leg_number == 1 ? 4 : 3)
		for(var/wipe_number in 0 to count - 1)
			var/offset = wipe_number * dirt_metric(limb)[1] * 1.5 * -dirt_limb_side(limb)
			var/datum/dirt_feature/stroke/wipe = new(limb, list(theta + offset, start_along - 0.04 * wipe_number), list(theta + offset + drift, start_along - dirt_up_h(limb, wipe_length + (level >= 3 ? 1.4 : 0) - wipe_number * 0.7)), level < 3 ? 0.9 : 1.5, 0.5, TRUE, dirt_limb_side(limb))
			wipe.cloth_only = TRUE
			features += wipe
	if(level >= 3)
		var/leg = legs[1]
		var/other_leg = legs[2]
		var/datum/dirt_feature/patch/thigh = new(leg, thigh_theta, dirt_up_h(leg, thigh_up), 2.3, 2, thigh_seed, 0.9)
		thigh.cloth_only = TRUE
		features += thigh
		var/datum/dirt_feature/patch/other_thigh = new(other_leg, other_thigh_theta, dirt_up_h(other_leg, other_thigh_up), 1.6, 1.4, other_thigh_seed, 0.7)
		other_thigh.cloth_only = TRUE
		features += other_thigh
		// the trouser fronts grey over, broken
		for(var/leg_number in 1 to 2)
			var/limb = leg_number == 1 ? DIRT_LIMB_R_LEG : DIRT_LIMB_L_LEG
			var/datum/dirt_feature/patch/front = new(limb, DIRT_THETA_FRONT, dirt_up_h(limb, 7), 2.6, 2.4, front_seeds[leg_number], 0.65, 0.5, 2)
			front.cloth_only = TRUE
			features += front
		// a rag wiped at the hip pocket
		var/datum/dirt_feature/stroke/rag = new(leg, list(rag_theta, rag_along), list(rag_theta - side * 25, rag_along - 0.02), 1.4, 0.2, TRUE, -1)
		rag.cloth_only = TRUE
		features += rag
	var/belly_theta = side * rng.uniform(15, 30)
	var/belly_along = rng.uniform(0.3, 0.4)
	var/belly_turn = rng.uniform(18, 30)
	var/chest_theta = -side * rng.uniform(20, 40)
	var/chest_along = rng.uniform(0.6, 0.72)
	rng.random() // the chest smear's turn, drawn and never used
	var/second_belly_theta = -side * rng.uniform(10, 25)
	var/second_belly_along = rng.uniform(0.22, 0.3)
	var/second_belly_turn = rng.uniform(15, 25)
	if(level >= 2)
		var/datum/dirt_feature/stroke/belly_wipe = new(DIRT_LIMB_TORSO, list(belly_theta, belly_along), list(belly_theta + side * belly_turn, belly_along + 0.04), level < 3 ? 1 : 1.3, 0.5, TRUE, 1)
		// on skin a smudge, not a dash
		if(level >= 3)
			belly_wipe.skin_role = DIRT_ROLE_FILM
		else
			belly_wipe.cloth_only = TRUE
		features += belly_wipe
	if(level >= 3)
		var/datum/dirt_feature/stroke/second_wipe = new(DIRT_LIMB_TORSO, list(second_belly_theta, second_belly_along), list(second_belly_theta - side * second_belly_turn, second_belly_along + 0.03), 1.2, 0.5, TRUE, -1)
		second_wipe.cloth_only = TRUE
		features += second_wipe
		var/datum/dirt_feature/blob/fleck = new(DIRT_LIMB_TORSO, belly_theta, belly_along, 0.5, 0.5, 7, 0, 0, 0)
		fleck.role = DIRT_ROLE_FLECK
		fleck.cloth_only = TRUE
		features += fleck
		// short and wide with film on one side, because a thin diagonal reads as a scar, a blob as a "+" and a dark 2x2
		// on a bare pec as a bruise
		var/datum/dirt_feature/stroke/chest_smear = new(DIRT_LIMB_TORSO, list(chest_theta, chest_along), list(chest_theta - side * 25, chest_along - 0.02), 1.6, 0.3, TRUE, -side)
		chest_smear.skin_role = DIRT_ROLE_FILM
		features += chest_smear
	// level 4's random draws, after every other
	var/heavy_seed = rng.randrange(65536)
	rng.randrange(65536) // a seed drawn and never used
	var/heavy_rise = rng.uniform(1.4, 2)
	if(level < 4)
		return features
	for(var/list/wrist as anything in wrists)
		features += new /datum/dirt_feature/coatline(wrist[1], wrist[2] + heavy_rise, 0, wrist[3], wrist[4], 1.2)
	features += new /datum/dirt_feature/stroke(DIRT_LIMB_TORSO, list(belly_theta, belly_along), list(belly_theta + side * belly_turn, belly_along + 0.04), 1.7, 0.4, TRUE, 1)
	features += new /datum/dirt_feature/stroke(DIRT_LIMB_TORSO, list(chest_theta, chest_along), list(chest_theta - side * 25, chest_along - 0.02), 1.8, 0.3, TRUE, -side)
	var/datum/dirt_feature/patch/belly_patch = new(DIRT_LIMB_TORSO, belly_theta, belly_along, 2.4, 1.8, heavy_seed, 0.85)
	belly_patch.cloth_only = TRUE
	features += belly_patch
	for(var/leg_number in 1 to 2)
		var/limb = leg_number == 1 ? DIRT_LIMB_R_LEG : DIRT_LIMB_L_LEG
		var/datum/dirt_feature/patch/front = new(limb, DIRT_THETA_FRONT, dirt_up_h(limb, 7), 2.8, 2.6, front_seeds[leg_number] + 3, 0.85, 1, 2)
		front.cloth_only = TRUE
		features += front
	return features

/**
 * Returns smoke's features, in soot or ash: the face and fingertips, and what settles on the shoulder tops, which bare
 * skin takes as film. From level 2 the collar front and back darken, and bare skin there takes it as film. On cloth
 * the cuffs at the sleeve ends also darken from level 2, and a diagonal wipe runs off the placket, two from level 3.
 * At level 3 soot settles from above, down the chest from the collar and shoulders (coal miners, firefighters), the
 * whole head greys, the dirtier shoulder blade and shoulder take patches, and sometimes both cheeks smudge. Level 4 goes
 * harder, from draws made after every other: on bare skin the whole coat from above, unbroken.
 *
 * Arguments:
 * - level: 1 to 4.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_smoke(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/both_cheeks = rng.random() < 0.5
	var/alist/hands = dirt_hands_levels(side, min(level, 3))
	if(level >= 4)
		// the dominant hand goes to 4, its lit back wiped clean, and the other to 3, the fingertips' top level
		var/alist/heavy_hands = alist()
		for(var/zone, hand_level in hands)
			heavy_hands[zone] = hand_level == 3 ? 4 : 3
		hands = heavy_hands
	var/list/features = list(new /datum/dirt_feature/stamps(side, level, hands, level >= 4 ? 3 : ((level >= 3 && both_cheeks) ? 2 : 0), level >= 4))
	if(level >= 3)
		var/datum/dirt_feature/region/head = new(DIRT_LIMB_HEAD)
		head.veil = TRUE
		features += head
	// each list(theta, h, turn)
	var/list/wipes = list()
	for(var/wipe_number in 0 to 1)
		var/theta = side * rng.uniform(25, 45) * (wipe_number ? -0.9 : 1)
		var/along = rng.uniform(0.55, 0.75) - 0.12 * wipe_number
		wipes += list(list(theta, along, side * rng.uniform(25, 35)))
	for(var/wipe_number in 1 to min(level, 3) - 1)
		var/list/wipe = wipes[wipe_number]
		var/datum/dirt_feature/stroke/stroke = new(DIRT_LIMB_TORSO, list(wipe[1], wipe[2]), list(wipe[1] + wipe[3], wipe[2] + 0.1), 1, 0.2, TRUE, 1)
		stroke.cloth_only = TRUE
		features += stroke
	for(var/datum/dirt_feature/cluster as anything in dirt_settled(rng, max(level, 2)))
		cluster.skin_role = DIRT_ROLE_FILM
		features += cluster
	if(level >= 2)
		var/datum/dirt_feature/region/collar/collar = new(DIRT_LIMB_TORSO, 0.92, 30, DIRT_FILM_T, 30)
		collar.skin_role = DIRT_ROLE_FILM
		features += collar
		for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
			var/datum/dirt_feature/region/band/cuff = new(limb, 0.38, 0.52)
			cuff.cloth_only = TRUE
			features += cuff
	var/blade_theta = side * 140 + rng.gauss(0, 10)
	var/blade_along = rng.uniform(0.7, 0.8)
	var/blade_seed = rng.randrange(65536)
	var/shoulder_theta = side * rng.uniform(40, 60)
	var/shoulder_along = rng.uniform(0.78, 0.88)
	var/shoulder_seed = rng.randrange(65536)
	var/mantle_depth = rng.uniform(5.5, 7)
	var/mantle_seed = rng.randrange(65536)
	// each list(limb, theta, seed)
	var/list/sleeves = list()
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/sleeve_theta = rng.gauss(DIRT_THETA_FRONT, 25)
		sleeves += list(list(limb, sleeve_theta, rng.randrange(65536)))
	// each list(theta, h, seed)
	var/list/necks = list()
	for(var/neck_side in list(-1, 1))
		var/neck_theta = neck_side * rng.uniform(30, 45)
		var/neck_along = rng.uniform(0.9, 0.95)
		necks += list(list(neck_theta, neck_along, rng.randrange(65536)))
	if(level >= 3)
		var/datum/dirt_feature/patch/blade = new(DIRT_LIMB_TORSO, blade_theta, blade_along, 1.6, 1.4, blade_seed)
		blade.cloth_only = TRUE
		features += blade
		var/datum/dirt_feature/patch/shoulder = new(DIRT_LIMB_TORSO, shoulder_theta, shoulder_along, 2, 1.5, shoulder_seed, 0.7)
		shoulder.skin_role = DIRT_ROLE_FILM
		features += shoulder
		for(var/list/settling as anything in list(list(DIRT_LIMB_TORSO, mantle_depth, mantle_seed), list(DIRT_LIMB_R_ARM, 3, mantle_seed + 1), list(DIRT_LIMB_L_ARM, 3, mantle_seed + 1)))
			var/datum/dirt_feature/mantle/mantle = new(settling[1], settling[2], DIRT_THETA_FRONT, settling[3], side)
			mantle.cloth_only = TRUE
			features += mantle
			// broken on bare skin, as a whole one reads as a grey crop top
			var/datum/dirt_feature/mantle/broken_mantle = new(settling[1], settling[2], DIRT_THETA_FRONT, settling[3], side, 0.45, 0.4, TRUE)
			broken_mantle.skin_only = TRUE
			features += broken_mantle
		// bare skin keeps a little body tone at the neck, or soot reads as ash
		for(var/list/neck as anything in necks)
			features += new /datum/dirt_feature/blob(DIRT_LIMB_TORSO, neck[1], neck[2], 0.8, 0.6, neck[3], 0.2, 0, 0.4)
		for(var/list/sleeve as anything in sleeves)
			var/datum/dirt_feature/patch/cuff_patch = new(sleeve[1], sleeve[2], 0.42, 2, 2.4, sleeve[3], 0.8, 0.5, 4)
			cuff_patch.skin_role = DIRT_ROLE_FILM
			features += cuff_patch
	// level 4's random draws, after every other
	var/heavy_seed = rng.randrange(65536)
	var/heavy_depth = rng.uniform(1.5, 2.5)
	if(level < 4)
		return features
	var/datum/dirt_feature/mantle/heavy_mantle = new(DIRT_LIMB_TORSO, mantle_depth + heavy_depth, DIRT_THETA_FRONT, mantle_seed, side, 0.45, 0.55)
	heavy_mantle.cloth_only = TRUE
	features += heavy_mantle
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/datum/dirt_feature/mantle/arm_mantle = new(limb, 4.5, DIRT_THETA_FRONT, mantle_seed + 1, side, 0.45, 0.5)
		arm_mantle.cloth_only = TRUE
		features += arm_mantle
	for(var/list/sleeve as anything in sleeves)
		var/datum/dirt_feature/patch/cuff_patch = new(sleeve[1], sleeve[2], 0.42, 2.2, 2.6, sleeve[3], 0.85, 1, 4)
		cuff_patch.cloth_only = TRUE
		features += cuff_patch
	var/datum/dirt_feature/patch/chest_patch = new(DIRT_LIMB_TORSO, DIRT_THETA_FRONT + side * 10, 0.45, 3.5, 2.5, heavy_seed, 0.6, 0.5, 3)
	chest_patch.cloth_only = TRUE
	features += chest_patch
	// bare skin takes the whole coat, unbroken: body on the shoulder tops and collarbones, film down the chest
	var/datum/dirt_feature/mantle/skin_mantle = new(DIRT_LIMB_TORSO, mantle_depth + heavy_depth * 0.6, DIRT_THETA_FRONT, mantle_seed, side, 0.45, 0.3)
	skin_mantle.skin_only = TRUE
	features += skin_mantle
	for(var/limb in list(DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM))
		var/datum/dirt_feature/mantle/arm_mantle = new(limb, 3.5, DIRT_THETA_FRONT, mantle_seed + 1, side, 0.45, 0.3)
		arm_mantle.skin_only = TRUE
		features += arm_mantle
	return features

/**
 * Returns sweat's features, on cloth only, because on bare skin sweat is a sheen, not a stain. Cloth soaks through
 * where it holds sweat, in soft-edged rounded masses that grow with level rather than darken. Level 1 wets the pits.
 * Level 2 makes them bigger, running down the side seams, and adds a patch under the collar and one down the spine.
 * Level 3 wets the back from the shoulder blades to the small of the back. Each variant sweats its own way: down the
 * back or on the chest, tall along the spine or wide between the shoulder blades. One side of the back is wetter, and
 * the dirtier side's pit is heavier.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_sweat(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	// by level
	var/static/list/pit_radii = list(2.6, 3.1, 3.6)
	var/static/list/pit_lengths = list(1.6, 2.2, 2.8)
	var/static/list/arm_radii = list(1.5, 1.8, 2.2)
	var/static/list/chest_widths = list(1.1, 1.7, 2.3)
	var/static/list/chest_depths = list(1.2, 2.2, 3.2)
	var/static/list/tall_widths = list(1.1, 1.9, 2.8)
	var/static/list/tall_lengths = list(2, 5, 8)
	var/static/list/wide_widths = list(1.7, 2.8, 3.8)
	var/static/list/wide_heights = list(1.2, 1.9, 2.7)
	var/static/list/spine_lengths = list(1.5, 4.5, 7.5)
	var/back_width = rng.uniform(0.7, 1.35)
	var/chest_width = rng.uniform(0.6, 1.3)
	var/pit_width = rng.uniform(0.85, 1.25)
	var/back_tall = rng.choose(list("tall", "wide")) == "tall"
	var/back_lean = rng.uniform(-14, 14)
	var/chest_lean = rng.uniform(-12, 12)
	var/list/seeds = list()
	for(var/seed_number in 1 to 8)
		seeds += rng.randrange(65536)
	// one side of the back wetter, because mirrored halves read as a printed butterfly
	var/skew = rng.uniform(-0.35, 0.35)
	var/chest_shape_width = rng.uniform(0.8, 1.2)
	var/chest_shape_depth = rng.uniform(0.8, 1.3)
	var/chest_top = rng.uniform(0.8, 0.86)
	var/back_top = rng.uniform(0.86, 0.94)
	var/wide_offset = rng.uniform(-0.8, 0.8)
	// as wet at every level, while a heavier level spreads further
	var/body = 0.68
	var/list/features = list()
	for(var/arm_number in 1 to 2)
		var/limb = arm_number == 1 ? DIRT_LIMB_R_ARM : DIRT_LIMB_L_ARM
		// the arm's side toward the body: the right arm's left
		var/inner = arm_number == 1 ? -90 : 90
		var/heavy = dirt_limb_side(limb) == side ? 1.12 : 1
		// a drop under the arm, one column into the chest, narrowing down the side seam, because an even band down the
		// seam reads as the arm's shadow in profile
		var/pit_radius = pit_radii[level] * pit_width * heavy
		var/datum/dirt_feature/damp/pit = new(DIRT_LIMB_TORSO, -inner, 0.76, new /datum/dirt_shape/hanging(pit_radius, pit_lengths[level] * pit_width * heavy, 0.6), seeds[arm_number], 0.5)
		pit.cloth_only = TRUE
		features += pit
		// the arm's inner face, which facing south shows only at its edge
		var/arm_radius = arm_radii[level] * pit_width * heavy
		var/datum/dirt_feature/damp/arm_side = new(limb, inner, 0.9, new /datum/dirt_shape/ellipse(arm_radius, arm_radius * 0.8, arm_radius * 1.3), seeds[arm_number] + 1, body)
		arm_side.cloth_only = TRUE
		features += arm_side
	if((level >= 2 && chest_width > 0.8) || chest_width > 1.2)
		// its size and height vary by variant and its top stays clear of the collar, because one shape on every mob
		// reads as a stamped collar band and a narrow one as the sternum
		var/width = chest_widths[level] * chest_width * chest_shape_width
		var/depth = chest_depths[level] * chest_width * chest_shape_depth
		var/datum/dirt_feature/damp/chest = new(DIRT_LIMB_TORSO, DIRT_THETA_FRONT + chest_lean, chest_top, new /datum/dirt_shape/hanging(width, depth, 0.45), seeds[3], body)
		chest.cloth_only = TRUE
		features += chest
	if(level >= 2 || back_width > 1.05)
		var/datum/dirt_shape/back_shape
		if(back_tall)
			// rounded down the spine and staying wide, because a thin end reads as a seam
			back_shape = new /datum/dirt_shape/hanging(tall_widths[level] * back_width, tall_lengths[level] * back_width, 0.15)
		else
			// broad between the shoulder blades and off the middle, the spine wet under it
			back_shape = new /datum/dirt_shape/union(list(new /datum/dirt_shape/ellipse_at(wide_offset, -1.5, wide_widths[level] * back_width, wide_heights[level]), new /datum/dirt_shape/hanging(1.3, spine_lengths[level] * back_width, 0.1)))
		var/datum/dirt_feature/damp/back = new(DIRT_LIMB_TORSO, DIRT_THETA_BACK + back_lean, back_top, new /datum/dirt_shape/skew(back_shape, skew), seeds[4], body)
		back.cloth_only = TRUE
		features += back
	if(level >= 3 && back_width > 0.9)
		// the small of the back, over the waistband
		var/datum/dirt_feature/damp/small_of_back = new(DIRT_LIMB_TORSO, DIRT_THETA_BACK - back_lean, 0.12, new /datum/dirt_shape/ellipse(1.8 * back_width, 1.1), seeds[5], body)
		small_of_back.cloth_only = TRUE
		features += small_of_back
	return features

/**
 * Returns a slime's attack from above. It latches on, so ooze sits where it clung, from the shoulders down. A big lump
 * sits on the side it grabbed from, a narrow one on that arm and one on the upper back, with smaller ones on the other
 * shoulder and the chest. Each is darkest underneath with a highlight on top. Drips run down from them in strands that
 * end in bulbs, and spatter lies round them, with bare cloth between. It's never a coat, because an even one reads as a
 * dyed shirt and a band over both shoulders as a shawl.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_cause_slimed(level, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/static/list/grows = list(0.8, 1, 1.25)
	var/static/list/lump_counts = list(2, 4, 5)
	var/static/list/drip_counts = list(1, 3, 5)
	var/static/list/stretches = list(0.8, 1.2, 1.4)
	var/static/list/spatter_counts = list(2, 5, 8)
	var/list/lumps = list()
	lumps += list(dirt_slime_lump(rng, DIRT_LIMB_TORSO, side * rng.uniform(50, 70), 0.9, 0.97, 1.8, 2.4, 1.2, 1.6))
	// narrow, because one round the arm reads as a sleeve
	lumps += list(dirt_slime_lump(rng, side > 0 ? DIRT_LIMB_R_ARM : DIRT_LIMB_L_ARM, rng.gauss(0, 25), 0.84, 0.92, 0.9, 1.1, 1.3, 1.8))
	// taller than wide, because a wide one under the collar reads as a stripe
	lumps += list(dirt_slime_lump(rng, DIRT_LIMB_TORSO, DIRT_THETA_BACK + side * rng.uniform(10, 35), 0.78, 0.86, 1.2, 1.6, 1.8, 2.4))
	lumps += list(dirt_slime_lump(rng, DIRT_LIMB_TORSO, -side * rng.uniform(55, 75), 0.9, 0.97, 1, 1.4, 0.9, 1.2))
	lumps += list(dirt_slime_lump(rng, DIRT_LIMB_TORSO, DIRT_THETA_FRONT + side * rng.uniform(5, 25), 0.76, 0.86, 1.2, 1.6, 1, 1.3))
	// each list(lump, across, length, width)
	var/list/drips = list()
	for(var/lump_number in list(1, 3, 2, 5, 3, 1))
		var/across = rng.uniform(-0.5, 0.5)
		var/drip_length = rng.uniform(3, 5)
		drips += list(list(lump_number, across, drip_length, rng.uniform(1, 1.3)))
	// each list(limb, theta, h, radius, seed)
	var/list/spatter = list()
	for(var/drop_number in 1 to 9)
		var/limb = rng.choices(list(DIRT_LIMB_TORSO, DIRT_LIMB_R_ARM, DIRT_LIMB_L_ARM, DIRT_LIMB_R_LEG, DIRT_LIMB_L_LEG), list(5, 2, 2, 1, 1))
		var/theta = side * 40 + rng.gauss(0, 70)
		var/along = rng.uniform(0.35, 0.85)
		var/radius = rng.uniform(0.6, 0.85)
		spatter += list(list(limb, theta, along, radius, rng.randrange(65536)))
	var/grow = grows[level]
	var/count = lump_counts[level]
	var/list/features = list()
	for(var/lump_number in 1 to count)
		var/list/lump = lumps[lump_number]
		var/limb = lump[1]
		var/list/metric = dirt_metric(limb)
		features += new /datum/dirt_feature/glob(limb, lump[2], lump[3], lump[4] * grow, lump[5] * grow, lump[6], 0.28)
		features += new /datum/dirt_feature/glint(limb, lump[2] - 0.35 * lump[4] * grow * metric[1], lump[3] + 0.4 * lump[5] * grow * metric[2])
	for(var/drip_number in 1 to drip_counts[level])
		var/list/drip = drips[drip_number]
		if(drip[1] > count)
			continue
		var/list/lump = lumps[drip[1]]
		var/limb = lump[1]
		var/list/metric = dirt_metric(limb)
		var/top = lump[3] - 0.5 * lump[5] * grow * metric[2]
		var/drip_length = drip[3] * stretches[level]
		var/end_theta = lump[2] + drip[2] * metric[1]
		var/end_along = top - drip_length * metric[2]
		// tapering, because an even strand reads as a strap
		features += new /datum/dirt_feature/stroke(limb, list(lump[2], top), list(end_theta, end_along), drip[4], 0.45)
		features += new /datum/dirt_feature/glob(limb, end_theta, end_along, 0.9, 1, lump[6] + 7, 0.05)
	for(var/drop_number in 1 to spatter_counts[level])
		var/list/drop = spatter[drop_number]
		features += new /datum/dirt_feature/glob(drop[1], drop[2], drop[3], drop[4], drop[4], drop[5], 0.1, FALSE)
	return features

/**
 * Returns one of a slime's lumps from above: list(limb, theta, h, radius round, radius up, seed). The caller draws its
 * theta, and this proc draws the rest from the stream, in that order.
 *
 * Arguments:
 * - rng: The deposit's stream.
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: Its theta.
 * - along_low, along_high: The range its h is drawn from.
 * - across_low, across_high: The range its radius round the limb is drawn from, in pixels.
 * - up_low, up_high: The range its radius up the limb is drawn from, in pixels.
 */
/proc/dirt_slime_lump(datum/dirt_random/rng, limb, theta, along_low, along_high, across_low, across_high, up_low, up_high)
	RETURN_TYPE(/list)
	var/along = rng.uniform(along_low, along_high)
	var/radius_x = rng.uniform(across_low, across_high)
	var/radius_y = rng.uniform(up_low, up_high)
	return list(limb, theta, along, radius_x, radius_y, rng.randrange(65536))

/**
 * Returns where slime touches for a contact on a zone, the struck spot first: each list(limb, theta, h, radius round,
 * radius up), the radii in pixels. The chest takes a whole front, as for a fall on your face, and the back a whole
 * back, as for lying on your back. The head takes the face's sides and the neck. An arm takes its front and its outer
 * side, with the torso beside it. A leg takes its front and back. They never go round a whole arm (a sleeve, a glove)
 * or a whole leg at the boot (socks, gaiters). The chest's and back's never go down the legs (overalls).
 *
 * Arguments:
 * - zone: BODY_ZONE_HEAD, BODY_ZONE_CHEST, DIRT_ZONE_BACK, or an arm's or a leg's BODY_ZONE_* define.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 */
/proc/dirt_slime_areas(zone, datum/dirt_random/rng, side)
	RETURN_TYPE(/list)
	var/list/areas = list()
	var/theta
	if(zone == BODY_ZONE_CHEST || zone == DIRT_ZONE_BACK)
		var/facing = zone == BODY_ZONE_CHEST ? DIRT_THETA_FRONT : DIRT_THETA_BACK
		theta = facing + rng.gauss(0, 15)
		areas += list(list(DIRT_LIMB_TORSO, theta, rng.uniform(0.55, 0.7), 2.4, 2.2))
		theta = facing + side * rng.uniform(15, 35)
		areas += list(list(DIRT_LIMB_TORSO, theta, rng.uniform(0.3, 0.45), 2, 1.8))
		theta = facing + rng.gauss(0, 15)
		areas += list(list(DIRT_LIMB_R_ARM, theta, rng.uniform(0.45, 0.65), 1.3, 2))
		theta = facing + rng.gauss(0, 15)
		areas += list(list(DIRT_LIMB_L_ARM, theta, rng.uniform(0.45, 0.65), 1.3, 2))
		return areas
	if(zone == BODY_ZONE_HEAD)
		var/face_side = rng.choose(list(-1, 1))
		theta = face_side * rng.uniform(60, 75)
		areas += list(list(DIRT_LIMB_HEAD, theta, rng.uniform(0.55, 0.7), 1.1, 1.2))
		theta = face_side * rng.uniform(50, 70)
		areas += list(list(DIRT_LIMB_TORSO, theta, rng.uniform(0.93, 0.98), 1.4, 1))
		theta = -face_side * rng.uniform(60, 75)
		areas += list(list(DIRT_LIMB_HEAD, theta, rng.uniform(0.55, 0.7), 1, 1))
		return areas
	var/right = zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_R_LEG
	// the limb's outer side
	var/outer = right ? 90 : -90
	if(zone == BODY_ZONE_R_ARM || zone == BODY_ZONE_L_ARM)
		var/arm = right ? DIRT_LIMB_R_ARM : DIRT_LIMB_L_ARM
		theta = (DIRT_THETA_FRONT + outer) / 2 + rng.gauss(0, 15)
		areas += list(list(arm, theta, rng.uniform(0.55, 0.75), 1.2, 1.8))
		theta = DIRT_THETA_FRONT + rng.gauss(0, 20)
		areas += list(list(arm, theta, rng.uniform(0.25, 0.4), 1, 1.5))
		theta = outer * rng.uniform(0.7, 0.9)
		areas += list(list(DIRT_LIMB_TORSO, theta, rng.uniform(0.6, 0.8), 1.3, 1.6))
		return areas
	// thinning upward
	var/leg = right ? DIRT_LIMB_R_LEG : DIRT_LIMB_L_LEG
	theta = DIRT_THETA_FRONT + rng.gauss(0, 20)
	areas += list(list(leg, theta, rng.uniform(0.45, 0.62), 1.2, 2))
	theta = DIRT_THETA_FRONT + outer * 0.4 + rng.gauss(0, 15)
	areas += list(list(leg, theta, rng.uniform(0.7, 0.85), 1.1, 1.6))
	theta = DIRT_THETA_BACK + rng.gauss(0, 25)
	areas += list(list(leg, theta, rng.uniform(0.3, 0.45), 1, 1.6))
	return areas

/**
 * Returns slime on one part of the body, for a hit or contact there, or a fall or lying down in it. Level 1 leaves a
 * lump where it struck, level 2 a bigger lumpy patch, and level 3 the part's whole contact surface
 * (dirt_slime_areas()). Each area is lumps with gaps between, darkest underneath with a highlight on top. It's never an
 * even coat, which reads as dye. Drips run down off the lumps, and spatter lies round the struck spot. Drips from the
 * head run off the jaw and down the neck.
 *
 * Arguments:
 * - level: 1 to 3.
 * - rng: The deposit's stream.
 * - side: The mob's dirtier side, 1 or -1.
 * - zone: Where it touched, as dirt_slime_areas() takes it.
 */
/proc/dirt_cause_slime_contact(level, datum/dirt_random/rng, side, zone)
	RETURN_TYPE(/list)
	var/static/list/grows = list(0.8, 1.1, 1.3)
	var/static/list/drip_counts = list(1, 2, 4)
	var/static/list/stretches = list(0.8, 1.2, 1.6)
	var/static/list/spatter_counts = list(2, 4, 7)
	var/list/areas = dirt_slime_areas(zone, rng, side)
	// each area's three lumps, each list(across, up, scale, seed), because one even shape reads as dye and a solid one
	// over a whole front or back as camo
	var/list/lumps = list()
	for(var/area_number in 1 to length(areas))
		var/list/parts = list()
		for(var/part_number in 1 to 3)
			var/across = rng.uniform(-0.8, 0.8)
			var/up = rng.uniform(-0.65, 0.65)
			var/scale = rng.uniform(0.5, 0.72)
			parts += list(list(across, up, scale, rng.randrange(65536)))
		lumps += list(parts)
	// each list(across, length, width, seed)
	var/list/drips = list()
	for(var/drip_number in 1 to 4)
		var/across = rng.uniform(-0.6, 0.6)
		var/drip_length = rng.uniform(3, 5)
		var/width = rng.uniform(1, 1.3)
		drips += list(list(across, drip_length, width, rng.randrange(65536)))
	var/list/struck = areas[1]
	// each list(limb, theta, h, radius, seed)
	var/list/spatter = list()
	for(var/drop_number in 1 to 7)
		var/limb = struck[1]
		if(rng.random() >= 0.6)
			var/list/area_limbs = list()
			for(var/list/contact_area as anything in areas)
				area_limbs += contact_area[1]
			limb = rng.choose(area_limbs)
		var/theta = struck[2] + rng.gauss(0, 55)
		var/along = max(0.15, min(0.95, struck[3] + rng.gauss(0, 0.2)))
		var/radius = rng.uniform(0.6, 0.85)
		spatter += list(list(limb, theta, along, radius, rng.randrange(65536)))
	var/count = level >= 3 ? length(areas) : level
	var/grow = grows[level]
	var/list/features = list()
	for(var/area_number in 1 to count)
		var/list/contact_area = areas[area_number]
		var/limb = contact_area[1]
		var/list/metric = dirt_metric(limb)
		var/list/parts = lumps[area_number]
		for(var/part_number in 1 to level)
			var/list/part = parts[part_number]
			var/centre_theta = contact_area[2] + part[1] * contact_area[4] * metric[1]
			var/centre_along = contact_area[3] + part[2] * contact_area[5] * metric[2]
			features += new /datum/dirt_feature/glob(limb, centre_theta, centre_along, contact_area[4] * grow * part[3], contact_area[5] * grow * part[3], part[4], 0.28)
		features += new /datum/dirt_feature/glint(limb, contact_area[2] - 0.3 * contact_area[4] * grow * metric[1], contact_area[3] + 0.35 * contact_area[5] * grow * metric[2])
	for(var/drip_number in 1 to min(count, drip_counts[level]))
		var/list/contact_area = areas[drip_number]
		var/list/drip = drips[drip_number]
		var/limb = contact_area[1]
		var/theta = contact_area[2]
		var/along = contact_area[3]
		var/radius_y = contact_area[5]
		if(limb == DIRT_LIMB_HEAD)
			limb = DIRT_LIMB_TORSO
			along = 1
			theta = theta * 0.6
			radius_y = 0
		var/list/metric = dirt_metric(limb)
		var/top = along - 0.6 * radius_y * grow * metric[2]
		var/end_theta = theta + drip[1] * metric[1]
		var/end_along = max(0.02, top - drip[2] * stretches[level] * metric[2])
		features += new /datum/dirt_feature/stroke(limb, list(theta, top), list(end_theta, end_along), drip[3], 0.45)
		features += new /datum/dirt_feature/glob(limb, end_theta, end_along, 0.9, 1, drip[4], 0.05)
	for(var/drop_number in 1 to spatter_counts[level])
		var/list/drop = spatter[drop_number]
		features += new /datum/dirt_feature/glob(drop[1], drop[2], drop[3], drop[4], drop[4], drop[5], 0.1, FALSE)
	return features
