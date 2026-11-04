/// A stomach streak may not start this near the mirror of another's: the pair read as a bra or a U.
#define DIRT_AIM_MIRROR_PX 2.5
/// Stomach drops keep this far apart: nearer, they lined up into a band.
#define DIRT_AIM_DROP_PX 2
/// The level a shot's streaks break into beads at, with skin between them.
#define DIRT_AIM_BEADS_LEVEL 3
/// How far round its limb a shot that hangs a run lands from every other: nearer, the runs filled into a sheet.
#define DIRT_AIM_RUN_PITCH 2.5
/// A hung run's length in pixels, spread 0.55 to 1.45 times by its drip draw so no two end level.
#define DIRT_AIM_RUN_PX 3
/// The top level's draws, made after every other.
#define DIRT_AIM_COVER_DRAWS 7

/**
 * A mess aimed at a zone: one deposit's random draws, made once, and the features each level draws from them, as the
 * reference generator's aimed cause draws them.
 * - Level 1: one streak laid along the shot's direction, ending in a small lump with a glint, and a drop. On the butt a
 *   shot beads and runs down instead: across the buttocks streaks read as a crack or a scrawl.
 * - Levels 2 and 3: level 1, then separate runs straight down instead of fills, each from a bead with a one-pixel
 *   highlight, with skin between them in every view (dirt_runs_apart()); fills read as a bib, a vest or a dressing.
 *   The face keeps its earlier look up to level 3: more streaks with drips, broken into beads at level 3.
 * - Level 4, the top: level 3, then a glaze over it from draws of its own: two translucent tongues hanging past the
 *   zone, three beads with highlights and runs, and two small pools.
 *
 * Every draw happens whatever the level, so the levels nest, each level its own features from the same draws.
 */
/datum/dirt_aim
	/// The DIRT_ZONE_* define it's aimed at.
	var/zone
	/// The areas its shots land in, each list(limb, lowest theta, highest theta, lowest h, highest h).
	var/list/areas
	/// Whether its streaks end inside the zone's heights.
	var/bounded = FALSE
	/// Whether each clamped end takes its own bound.
	var/staggered = FALSE
	/// Whether its shots bead and run down instead of streaking.
	var/beaded = FALSE
	/// The shot's direction, in degrees: up and across.
	var/angle
	// The draws below are shared by every deposit of the same zone and variant: never change them.
	/// The twelve shots drawn, in draw order, each list(limb, theta, h, aim, length, width, drip fraction, seed, area).
	var/list/candidates = list()
	/// The shots kept for streaks, five at most with their starts 3 px apart, in the same form.
	var/list/streaks = list()
	/// The six drops drawn, each list(limb, theta, h, radius, seed).
	var/list/drops = list()
	/// The top level's seven draws, each list(limb, theta, h, size, length, seed, area).
	var/list/covers = list()
	/// The thighs' drips the features being made have so far, each list(limb, top, bottom).
	var/list/runs
	/// Each level's features once made: the levels above share the features they nest, and their pixels on the view.
	var/list/made_levels = new /list(DIRT_MESS_MAX_LEVEL)
	/// Levels 2 and 3's runs and drops once made (hang_runs()), which both draw from.
	var/list/hung_parts

/**
 * Makes a deposit's draws from the "aimed_<zone>:<variant>" stream, or takes those already made for the same zone and
 * variant: they're the same wherever it lands, so each is drawn once a round.
 *
 * Arguments:
 * - zone: A DIRT_ZONE_* define, not DIRT_ZONE_COCK.
 * - variant: 0 to DIRT_MESS_VARIANTS - 1.
 */
/datum/dirt_aim/New(zone, variant)
	. = ..()
	src.zone = zone
	areas = dirt_aim_zones()[zone]
	bounded = (zone in dirt_aim_bounds())
	// each clamped end takes its own bound: on one row they drew garters or a band
	staggered = bounded && (zone == DIRT_ZONE_STOMACH || zone == DIRT_ZONE_THIGHS)
	beaded = zone == DIRT_ZONE_BUTT
	// at most the aimed zones' DIRT_MESS_VARIANTS each
	var/static/alist/drawn = alist()
	var/key = "[zone]:[variant]"
	var/list/draws = drawn[key]
	if(draws)
		angle = draws[1]
		candidates = draws[2]
		streaks = draws[3]
		drops = draws[4]
		covers = draws[5]
		return
	var/datum/dirt_random/stream = new("aimed_[zone]:[num2text(variant, 12)]")
	// one direction for the whole shot, up and across; across a face, where steep ones lost themselves in the eyes
	angle = zone == DIRT_ZONE_FACE ? stream.uniform(5, 35) : stream.uniform(55, 125)
	angle *= stream.choose(list(-1, 1))
	for(var/attempt in 1 to 12) // five kept, their starts 3 px apart: overlapping streaks merged into an opaque patch
		var/list/area = stream.choose(areas)
		var/limb = area[1]
		var/aim = angle + stream.gauss(0, 14)
		var/start_theta = stream.uniform(area[2], area[3])
		var/start_along = stream.uniform(area[4], area[5])
		var/streak_length = stream.uniform(2.5, 4.5)
		var/streak_width = stream.uniform(0.7, 0.95)
		var/drip_at = stream.uniform(0.2, 0.8)
		var/seed = stream.randrange(65536)
		var/list/candidate = list(limb, start_theta, start_along, aim, streak_length, streak_width, drip_at, seed, area)
		candidates += list(candidate)
		if(length(streaks) >= 5)
			continue
		var/list/metric = dirt_metric(limb)
		var/clear = TRUE
		for(var/list/kept as anything in streaks)
			if(kept[1] != limb)
				continue
			var/turn = kept[2] - start_theta
			var/mirror_turn = -kept[2] - start_theta
			var/across = DIRT_WRAP_DEGREES(turn) / metric[1]
			var/mirror_across = DIRT_WRAP_DEGREES(mirror_turn) / metric[1]
			var/up = (kept[3] - start_along) / metric[2]
			if(sqrt(across * across + up * up) < 3 || (zone == DIRT_ZONE_STOMACH && sqrt(mirror_across * mirror_across + up * up) < DIRT_AIM_MIRROR_PX))
				clear = FALSE
				break
		if(clear)
			streaks += list(candidate)
	for(var/attempt in 1 to 6)
		var/list/area = stream.choose(areas)
		var/drop_theta = stream.uniform(area[2], area[3])
		var/drop_along = stream.uniform(area[4], area[5])
		var/radius = stream.uniform(0.55, 0.8)
		var/seed = stream.randrange(65536)
		drops += list(list(area[1], drop_theta, drop_along, radius, seed))
	for(var/attempt in 1 to DIRT_AIM_COVER_DRAWS) // after every other draw, so the levels below stay as they were
		var/list/area = stream.choose(areas)
		var/cover_theta = stream.uniform(area[2], area[3])
		var/cover_along = stream.uniform(area[4], area[5])
		var/size = stream.random()
		var/cover_length = stream.random()
		var/seed = stream.randrange(65536)
		covers += list(list(area[1], cover_theta, cover_along, size, cover_length, seed, area))
	drawn[key] = list(angle, candidates, streaks, drops, covers)

/**
 * Returns the features of one level, made once. You should NEVER modify the list it returns.
 *
 * Arguments:
 * - level: 1 to DIRT_MESS_MAX_LEVEL.
 */
/datum/dirt_aim/proc/features(level)
	RETURN_TYPE(/list)
	if(made_levels[level])
		return made_levels[level]
	runs = list()
	if(level == DIRT_MESS_MAX_LEVEL)
		. = covered()
	else if(level >= 2 && zone != DIRT_ZONE_FACE)
		. = hung(level)
	else
		. = streaked(level)
	made_levels[level] = .

/**
 * Returns the features of level 1, and of the face's levels 2 and 3: streaks laid along the shot, each ending in a
 * small lump with a glint, drips running down from them from level 2, and drops round them. At level 3 each streak
 * breaks into beads.
 *
 * Arguments:
 * - level: 1 to 3.
 */
/datum/dirt_aim/proc/streaked(level)
	RETURN_TYPE(/list)
	// by level
	var/static/list/streak_counts = list(1, 3, 4)
	var/static/list/beaded_streak_counts = list(1, 2, 3)
	var/static/list/length_scales = list(0.8, 1, 1.25)
	var/static/list/drip_lengths = list(1.5, 2, 3)
	var/static/list/drop_counts = list(1, 3, 6)
	var/list/features = list()
	var/upright = 0 // upright groin streaks so far
	var/streak_count = min(length(streaks), beaded ? beaded_streak_counts[level] : streak_counts[level])
	for(var/streak_number in 1 to streak_count)
		var/list/streak = streaks[streak_number]
		var/limb = streak[1]
		var/start_theta = streak[2]
		var/aim = streak[4]
		var/streak_length = streak[5]
		var/seed = streak[8]
		var/list/area = streak[9]
		var/along_per_pixel = dirt_metric(limb)[2]
		if(zone == DIRT_ZONE_GROIN && abs(cos(aim)) < sin(35))
			upright++
			// one streak within 35 degrees of upright at most: two up the belly read as bars, the rest turn to 45
			if(upright > 1)
				aim = tilted(aim)
		streak_length *= length_scales[level] * (beaded ? 0.3 : 1)
		var/list/landed = land(limb, start_theta, streak[3], aim, streak_length, seed, area)
		var/start_along = landed[1]
		var/end_theta = landed[2]
		var/end_along = landed[3]
		if(level == DIRT_AIM_BEADS_LEVEL)
			for(var/fraction in list(0, 0.5))
				var/bead_theta = start_theta + (end_theta - start_theta) * fraction
				var/bead_along = start_along + (end_along - start_along) * fraction
				features += new /datum/dirt_feature/glob(limb, bead_theta, bead_along, 0.6, 0.6, seed + 5, 0.1)
		else // an opaque core in a translucent edge: opaque alone read as paint or tape, translucent alone as chalk
			features += new /datum/dirt_feature/stroke(limb, list(start_theta, start_along), list(end_theta, end_along), streak[6] + 0.1, 0.5)
		features += new /datum/dirt_feature/glob(limb, end_theta, end_along, 0.75, 0.75, seed, 0.1)
		features += glint_at(limb, end_theta, end_along)
		// an upright stomach streak doesn't drip: its drip ran down its own line, a bar from the side
		var/steep = zone == DIRT_ZONE_STOMACH && abs(cos(aim)) < sin(35)
		if((level < 2 && !beaded) || steep) // a drip runs down from part of the streak; every bead runs
			continue
		var/drip_at = streak[7]
		var/drip_theta = start_theta + (end_theta - start_theta) * drip_at
		var/drip_top = start_along + (end_along - start_along) * drip_at
		// short and tapering: long even lines down a leg read as seams, beads' drips side by side as tally marks
		var/drip_length = drip_lengths[level] * (beaded ? 0.6 : 1)
		var/bottom = capped(limb, drip_top, max(0, drip_top - drip_length * along_per_pixel), seed, area[4])
		features += new /datum/dirt_feature/stroke(limb, list(drip_theta, drip_top), list(drip_theta, bottom), 1.2, 0.5, FALSE)
		features += new /datum/dirt_feature/glob(limb, drip_theta, bottom, 0.8, 0.9, seed + 3, 0.05) // a 2 px bulb
	var/list/placed = list()
	for(var/drop_number in 1 to drop_counts[level])
		var/list/drop = drops[drop_number]
		var/limb = drop[1]
		var/drop_theta = drop[2]
		var/drop_along = drop[3]
		if(zone == DIRT_ZONE_STOMACH) // drops keep apart: in a row or a column on the belly they drew a band or a U
			var/list/metric = dirt_metric(limb)
			var/crowded = FALSE
			for(var/list/other as anything in placed)
				var/turn = drop_theta - other[2]
				var/across = DIRT_WRAP_DEGREES(turn) / metric[1]
				var/up = (drop_along - other[3]) / metric[2]
				if(other[1] == limb && sqrt(across * across + up * up) < DIRT_AIM_DROP_PX)
					crowded = TRUE
					break
			if(crowded)
				continue
		placed += list(list(limb, drop_theta, drop_along))
		features += new /datum/dirt_feature/glob(limb, drop_theta, drop_along, drop[4], drop[4], drop[5], 0.1, FALSE)
	if(zone == DIRT_ZONE_BACK) // in profile only the back's edge shows, and mess on it read as a strap
		for(var/datum/dirt_feature/feature as anything in features)
			feature.profile_hidden = TRUE
	return features

/**
 * Returns the features of levels 2 and 3 off the face: level 1's exactly, then runs straight down instead of fills.
 * Level 1's streak hangs a run from part of its length (level 2) and level 1's drop one from its middle (level 3).
 * Later shots come from the twelve drawn in draw order, each landing at level 1's length at least DIRT_AIM_RUN_PITCH px
 * round its limb from every shot and from level 1's drop, as a bead with a one-pixel highlight and one run straight
 * down. The other drops follow. A run plan holds level 3's set, so each view keeps the same ones at every level.
 *
 * Where level 2 shows nothing new in the zone's main facing, level 1's drop runs a little to a smaller bead, so every
 * level-up shows (dirt_runs_apart() decides).
 *
 * Arguments:
 * - level: 2 or 3.
 */
/datum/dirt_aim/proc/hung(level)
	RETURN_TYPE(/list)
	var/static/list/drop_counts = list(1, 3, 6)
	var/list/base = features(1)
	hung_parts ||= hang_runs()
	var/list/groups = hung_parts[1]
	var/list/shots = beaded ? list(1, 2, 3) : list(1, 3, 4)
	var/list/features = base.Copy()
	for(var/list/entry as anything in groups)
		if(entry[1] < shots[level] || (entry[1] >= 11 && entry[1] < 10 + drop_counts[level]) || (entry[1] == 10 && level == 3))
			for(var/datum/dirt_feature/feature as anything in entry[2])
				if((feature.from_level || 0) <= level)
					features += feature
	if(level == 2)
		features += hung_parts[2]
	features += new /datum/dirt_feature/run_plan(groups, (zone == DIRT_ZONE_BACK || zone == DIRT_ZONE_BUTT) ? NORTH : SOUTH, hung_parts[3])
	return features

/**
 * Returns levels 2 and 3's runs and drops, made once for both: list(each run or drop as list(its group, its features),
 * level 2's carry-on from level 1's drop, that drop).
 */
/datum/dirt_aim/proc/hang_runs()
	RETURN_TYPE(/list)
	runs = list()
	var/list/shots = beaded ? list(1, 2, 3) : list(1, 3, 4)
	var/list/first_drop = drops[1]
	var/drop_limb = first_drop[1]
	var/drop_theta = first_drop[2]
	var/drop_along = first_drop[3]
	var/drop_seed = first_drop[5]
	var/knee
	for(var/list/area as anything in areas)
		if(area[1] == drop_limb)
			knee = area[4]
			break
	var/list/groups = list() // each list(group, features)
	// each list(limb, its lowest theta, its highest, where it landed: theta, h)
	var/list/taken = list(list(drop_limb, drop_theta, drop_theta, drop_theta, drop_along))
	var/upright = 0
	for(var/list/candidate as anything in candidates)
		if(length(groups) == shots[3])
			break
		var/limb = candidate[1]
		var/start_theta = candidate[2]
		var/aim = candidate[4]
		var/drip_at = candidate[7]
		var/seed = candidate[8]
		var/list/area = candidate[9]
		var/list/metric = dirt_metric(limb)
		var/degrees_per_pixel = metric[1]
		var/along_per_pixel = metric[2]
		var/straight = zone == DIRT_ZONE_GROIN && abs(cos(aim)) < sin(35)
		if(straight && upright) // one upright streak at most
			aim = tilted(aim)
		var/list/landed = land(limb, start_theta, candidate[3], aim, candidate[5] * 0.8 * (beaded ? 0.3 : 1), seed, area)
		var/start_along = landed[1]
		var/end_theta = landed[2]
		var/end_along = landed[3]
		if(length(groups))
			var/crowded = FALSE
			for(var/list/other as anything in taken)
				if(other[1] != limb)
					continue
				var/low_turn = end_theta - other[2]
				var/high_turn = end_theta - other[3]
				if((other[2] <= end_theta && end_theta <= other[3]) || min(abs(DIRT_WRAP_DEGREES(low_turn)), abs(DIRT_WRAP_DEGREES(high_turn))) < DIRT_AIM_RUN_PITCH * degrees_per_pixel)
					crowded = TRUE
					break
				if(zone == DIRT_ZONE_STOMACH) // a mirrored pair read as a bra or a U
					var/mirror_turn = -other[4] - end_theta
					var/mirror_across = DIRT_WRAP_DEGREES(mirror_turn) / degrees_per_pixel
					var/up = (other[5] - end_along) / along_per_pixel
					if(sqrt(mirror_across * mirror_across + up * up) < DIRT_AIM_MIRROR_PX)
						crowded = TRUE
						break
			if(crowded)
				continue
			for(var/pass in 1 to 2) // a row of landings read as a strap: each steps down off another's row
				for(var/list/other as anything in taken)
					var/low_turn = end_theta - other[2]
					var/high_turn = end_theta - other[3]
					if(other[1] == limb && abs(end_along - other[5]) < along_per_pixel && min(abs(DIRT_WRAP_DEGREES(low_turn)), abs(DIRT_WRAP_DEGREES(high_turn))) < 6 * degrees_per_pixel)
						end_along = other[5] - along_per_pixel
		upright += straight
		var/list/group
		var/span_low
		var/span_high
		if(!length(groups)) // level 1's shot: its run leaves from part of its length
			// not where it would run down its own line, nor from a bead, whose level 1 drip is its run
			var/steep = zone == DIRT_ZONE_STOMACH && abs(cos(aim)) < sin(35)
			var/top_theta = start_theta + (end_theta - start_theta) * drip_at
			var/top_along = start_along + (end_along - start_along) * drip_at
			group = (steep || beaded) ? list() : hanging(limb, top_theta, top_along, drip_at, seed, area[4], TRUE)
			span_low = min(start_theta, end_theta)
			span_high = max(start_theta, end_theta)
		else
			group = list(new /datum/dirt_feature/glob(limb, end_theta, end_along, 0.6, 0.6, seed, 0.1), glint_at(limb, end_theta, end_along, /datum/dirt_feature/glint/highlight))
			group += hanging(limb, end_theta, end_along, drip_at, seed, area[4], length(groups) < shots[2])
			span_low = end_theta
			span_high = end_theta
		groups += list(list(length(groups), group))
		taken += list(list(limb, span_low, span_high, end_theta, end_along))
	var/spread = 0.2 + 0.6 * (drop_seed % 1000) / 999
	groups.Insert(2, list(list(10, hanging(drop_limb, drop_theta, drop_along, spread, drop_seed, knee, FALSE))))
	// level 2's carry-on: level 1's drop runs a little to a smaller bead, down the line level 3's run takes
	var/drop_along_per_pixel = dirt_metric(drop_limb)[2]
	var/below = max(0, drop_along - (1.5 + spread) * drop_along_per_pixel)
	if(zone == DIRT_ZONE_THIGHS)
		below = max(below, knee)
	var/list/early = list()
	if(drop_along - below >= 0.75 * drop_along_per_pixel)
		early += new /datum/dirt_feature/run(drop_limb, drop_theta, drop_along, below)
		early += new /datum/dirt_feature/glob(drop_limb, drop_theta, below, 0.7, 0.8, drop_seed + 7, 0.05)
	else if(drop_limb == DIRT_LIMB_TORSO) // on the torso's last row: a bead just past the waist
		early += new /datum/dirt_feature/spill(drop_theta, 1, drop_seed)
	for(var/datum/dirt_feature/feature as anything in early)
		feature.run_group = DIRT_RUN_GROUP_EARLY
		feature.from_level = 2
	var/datum/dirt_feature/anchor = new /datum/dirt_feature/glob(drop_limb, drop_theta, drop_along, first_drop[4], first_drop[4], drop_seed, 0.1, FALSE)
	for(var/drop_number in 2 to length(drops))
		var/list/drop = drops[drop_number]
		groups += list(list(9 + drop_number, list(new /datum/dirt_feature/glob(drop[1], drop[2], drop[3], drop[4], drop[4], drop[5], 0.1, FALSE))))
	for(var/list/entry as anything in groups)
		for(var/datum/dirt_feature/feature as anything in entry[2])
			feature.run_group = entry[1]
			feature.profile_hidden = zone == DIRT_ZONE_BACK // as level 1's
	return list(groups, early, anchor)

/**
 * Returns a run hung straight down from a point, ending in a 2 px bulb. One carried on goes past its bulb to a smaller
 * one from level 3: with no room for another run, a level-up showed nothing.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it hangs on.
 * - top_theta, top_along: Where it hangs from.
 * - spread: Its drip draw, 0.2 to 0.8, which sets its length.
 * - seed: The shot's seed.
 * - knee: The lowest h of its area, which a thigh's run stays above.
 * - carry: Whether it carries on past its bulb at level 3.
 */
/datum/dirt_aim/proc/hanging(limb, top_theta, top_along, spread, seed, knee, carry)
	RETURN_TYPE(/list)
	var/along_per_pixel = dirt_metric(limb)[2]
	var/run_length = DIRT_AIM_RUN_PX * (0.55 + 1.5 * (spread - 0.2)) * (beaded ? 0.6 : 1)
	var/bottom = capped(limb, top_along, max(0, top_along - run_length * along_per_pixel), seed, knee)
	var/list/hung = list(new /datum/dirt_feature/run(limb, top_theta, top_along, bottom), new /datum/dirt_feature/glob(limb, top_theta, bottom, 0.8, 0.9, seed + 3, 0.05))
	var/below = max(0, bottom - (1.5 + spread) * along_per_pixel)
	if(zone == DIRT_ZONE_THIGHS) // above the knee, as every thigh drip
		below = max(below, knee)
	if(carry && bottom - below >= 0.75 * along_per_pixel)
		var/list/tail = list(new /datum/dirt_feature/run(limb, top_theta, bottom, below), new /datum/dirt_feature/glob(limb, top_theta, below, 0.7, 0.8, seed + 7, 0.05))
		for(var/datum/dirt_feature/feature as anything in tail)
			feature.from_level = 3
		hung += tail
	return hung

/**
 * Returns the features of the top level, the glaze: level 3's exactly, then on top, from the deposit's own draws:
 * - two translucent tongues hanging from where they landed, running past the zone;
 * - three opaque beads, each with a one-pixel highlight and a run straight down ending in a bulb;
 * - two small pools with their grey underside, a translucent rim and a highlight.
 * A tongue that reaches the torso's last row carries on down the leg under it, never onto the arms. Seen in
 * profile, where the arm hides the back, the back's coat shows as a thin run-off down the back of the near leg. The
 * coat fades at an outline and breaks near a profile's (dirt_rasterise_level()). The opaque runs keep apart from
 * level 3's and each other, as runs do: beside them they fused into panels that read as garments. The beads, the pools
 * and their highlights stay where they land.
 */
/datum/dirt_aim/proc/covered()
	RETURN_TYPE(/list)
	var/list/below = features(3)
	runs = list()
	var/list/extra = list()
	var/back = zone == DIRT_ZONE_BACK
	for(var/cover_number in 1 to 2)
		var/list/cover = covers[cover_number]
		var/limb = cover[1]
		var/along = cover[3]
		var/along_per_pixel = dirt_metric(limb)[2]
		var/reach = 4 + 4 * cover[5]
		extra += new /datum/dirt_feature/glaze(limb, cover[2], along, 1.4 + cover[4], reach, cover[6])
		if(back) // in profile the arm hides the back: its coat shows down the back of the near leg, or nothing showed behind
			var/datum/dirt_feature/glaze/flank = new(cover_number == 1 ? DIRT_LIMB_R_LEG : DIRT_LIMB_L_LEG, cover_number == 1 ? 160 : -160, 1, 1.3, 2 + reach * 0.5, cover[6] + 1)
			flank.profile_only = TRUE
			extra += flank
		if(limb == DIRT_LIMB_TORSO && reach - along / along_per_pixel >= 1) // past the waist: on down the leg
			extra += new /datum/dirt_feature/spill(cover[2], min(5, round(reach - along / along_per_pixel, 1)), cover[6], TRUE)
	var/list/groups = list()
	for(var/cover_number in 3 to 5)
		var/list/cover = covers[cover_number]
		var/limb = cover[1]
		var/cover_theta = cover[2]
		var/along = cover[3]
		var/seed = cover[6]
		var/list/area = cover[7]
		var/along_per_pixel = dirt_metric(limb)[2]
		var/reach = 2.5 + 4 * cover[5]
		var/bottom = capped(limb, along, max(0, along - reach * along_per_pixel), seed, area[4])
		extra += new /datum/dirt_feature/glob(limb, cover_theta, along, 0.6, 0.6, seed, 0.1)
		extra += glint_at(limb, cover_theta, along, /datum/dirt_feature/glint/highlight)
		groups += list(list(17 + cover_number, list(new /datum/dirt_feature/run(limb, cover_theta, along, bottom), new /datum/dirt_feature/glob(limb, cover_theta, bottom, 0.8, 0.9, seed + 3, 0.05))))
	for(var/cover_number in 6 to 7)
		var/list/cover = covers[cover_number]
		var/limb = cover[1]
		var/cover_theta = cover[2]
		var/along = cover[3]
		var/list/metric = dirt_metric(limb)
		var/radius = 0.8 + 0.3 * cover[4]
		extra += new /datum/dirt_feature/glob(limb, cover_theta, along, radius, radius, cover[6], 0.25)
		extra += new /datum/dirt_feature/glint/highlight(limb, cover_theta - 0.35 * radius * metric[1], along + 0.45 * radius * metric[2])
	for(var/list/entry as anything in groups)
		for(var/datum/dirt_feature/feature as anything in entry[2])
			feature.run_group = zone == DIRT_ZONE_FACE ? null : entry[1] // the face keeps every one, unspaced, as below it
			extra += feature
	var/datum/dirt_feature/run_plan/plan = locate() in below
	var/list/features = below - plan
	features += new /datum/dirt_feature/run_plan(plan ? plan.groups + groups : groups)
	var/list/first_cover = covers[1]
	for(var/datum/dirt_feature/feature as anything in extra)
		feature.covering = TRUE
		feature.break_seed = first_cover[6]
		// the back's other mess stays hidden in profile, as at every level; its tongues show a thin edge there
		feature.profile_hidden = back && !istype(feature, /datum/dirt_feature/glaze)
	return features + extra

/**
 * Returns where a streak starts and ends: list(its start's h, its end's theta, its end's h). Laid along the shot, then
 * held in its zone's heights where the zone bounds them.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - start_theta, start_along: Where it starts.
 * - aim: The streak's direction, in degrees.
 * - streak_length: Its length in pixels.
 * - seed: The shot's seed.
 * - area: The area it landed in, list(limb, lowest theta, highest theta, lowest h, highest h).
 */
/datum/dirt_aim/proc/land(limb, start_theta, start_along, aim, streak_length, seed, list/area)
	RETURN_TYPE(/list)
	var/list/aim_bounds = dirt_aim_bounds()
	var/list/metric = dirt_metric(limb)
	var/along_per_pixel = metric[2]
	var/end_theta = start_theta + cos(aim) * streak_length * metric[1]
	var/end_along = start_along + sin(aim) * streak_length * along_per_pixel
	if(bounded && zone == DIRT_ZONE_BACK) // under the shoulder line: across the shoulder blades it read as a shawl
		var/rise = max(start_along, end_along) - area[5]
		if(rise > 0)
			start_along -= rise
			end_along -= rise
	else if(bounded) // the streak ends inside its zone's heights
		var/low = area[4] - aim_bounds[zone]
		var/high = area[5] + aim_bounds[zone]
		if(staggered && (end_along < low || end_along > high)) // its own bound: clamped onto one row they drew a band
			var/room = (end_along < low ? start_along - low : high - start_along) / along_per_pixel
			var/inset = dirt_aim_inset(seed, odd_side(limb, start_theta), room, zone == DIRT_ZONE_THIGHS && end_along < low) * along_per_pixel
			low += inset
			high -= inset
		var/list/inside = dirt_aim_inside(start_theta, start_along, end_theta, end_along, low, high)
		end_theta = inside[1]
		end_along = inside[2]
	return list(start_along, end_theta, end_along)

/**
 * Returns the glint over a streak's end or a bead: 0.3 px back round the limb and 0.3 px up.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - end_theta, end_along: The streak's end or the bead.
 * - glint_type: The glint's type: a highlight lights one pixel only.
 */
/datum/dirt_aim/proc/glint_at(limb, end_theta, end_along, glint_type = /datum/dirt_feature/glint)
	RETURN_TYPE(/datum/dirt_feature/glint)
	var/list/metric = dirt_metric(limb)
	return new glint_type(limb, end_theta - 0.3 * metric[1], end_along + 0.3 * metric[2])

/**
 * Returns a drip's or a run's bottom: on the thighs it ends above the knee, at its own inset, and a matching run on the
 * other leg is halved; elsewhere it's left as it is.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it runs down.
 * - top: The h it starts at.
 * - bottom: The h it would end at.
 * - seed: The shot's seed.
 * - knee: The lowest h of its area.
 */
/datum/dirt_aim/proc/capped(limb, top, bottom, seed, knee)
	if(zone != DIRT_ZONE_THIGHS)
		return bottom
	var/along_per_pixel = dirt_metric(limb)[2]
	if(staggered && bottom < knee) // its own bound: capped onto one row they read as garters; to the foot, as socks
		knee += dirt_aim_inset(floor(seed / 2), odd_side(limb, null), (top - knee) / along_per_pixel, TRUE) * along_per_pixel
	bottom = max(bottom, knee)
	for(var/list/other_run as anything in runs) // the other leg's matching run halved: pairs read as zebra
		if(other_run[1] == limb || abs(other_run[2] - top) > 1.5 * along_per_pixel)
			continue
		if(abs((other_run[2] - other_run[3]) - (top - bottom)) <= along_per_pixel)
			bottom = top - (top - bottom) / 2
			break
	runs += list(list(limb, top, bottom))
	return bottom

/**
 * Returns whether a streak's or a drip's insets are odd: odd on one side of a pair, even on the other, the shot's
 * direction picking which. On the thighs the sides are the legs, elsewhere either side of the midline.
 *
 * Arguments:
 * - limb: The DIRT_LIMB_* define it lies on.
 * - theta: Where it starts round the limb, which the thighs don't read.
 */
/datum/dirt_aim/proc/odd_side(limb, theta)
	return (zone == DIRT_ZONE_THIGHS ? (limb == DIRT_LIMB_R_LEG) : (theta >= 0)) == (angle > 0)

/**
 * Returns a groin streak's direction turned 45 degrees off upright, on the same side: two side by side up the belly
 * read as bars.
 *
 * Arguments:
 * - aim: Its direction, in degrees.
 */
/datum/dirt_aim/proc/tilted(aim)
	return arctan(cos(aim) < 0 ? -sin(45) : sin(45), sin(aim) < 0 ? -cos(45) : cos(45))

/**
 * Returns each aim zone's areas, where its shots land: list(zone = list(list(limb, lowest theta, highest theta, lowest
 * h, highest h), ...)). You should NEVER modify it.
 */
/proc/dirt_aim_zones()
	RETURN_TYPE(/list)
	var/static/list/aim_zones = list(
		// the lower face: across the eyes it read as a mask
		DIRT_ZONE_FACE = list(list(DIRT_LIMB_HEAD, -55, 55, 0.05, 0.38)),
		DIRT_ZONE_CHEST = list(list(DIRT_LIMB_TORSO, -55, 55, 0.55, 0.9)),
		DIRT_ZONE_STOMACH = list(list(DIRT_LIMB_TORSO, -50, 50, 0.12, 0.5)),
		// under the shoulder blades: across them it read as a shawl
		DIRT_ZONE_BACK = list(list(DIRT_LIMB_TORSO, 125, 235, 0.25, 0.6)),
		// the torso's part at the waistband: above it the shot read as bars up the belly
		DIRT_ZONE_GROIN = list(
			list(DIRT_LIMB_TORSO, -40, 40, 0, 0.1),
			list(DIRT_LIMB_R_LEG, -35, 45, 0.82, 1),
			list(DIRT_LIMB_L_LEG, -45, 35, 0.82, 1),
		),
		// from the knee (lower ran to the feet as socks) to under the boxer hems
		DIRT_ZONE_THIGHS = list(
			list(DIRT_LIMB_R_LEG, -40, 50, 0.45, 0.72),
			list(DIRT_LIMB_L_LEG, -50, 40, 0.45, 0.72),
		),
		// the cheeks, not the cleft: beads down the middle read as a crack
		DIRT_ZONE_BUTT = list(
			list(DIRT_LIMB_TORSO, 118, 150, 0, 0.25),
			list(DIRT_LIMB_TORSO, 210, 242, 0, 0.25),
			list(DIRT_LIMB_R_LEG, 150, 210, 0.6, 1),
			list(DIRT_LIMB_L_LEG, 150, 210, 0.6, 1),
		),
	)
	return aim_zones

/**
 * Returns how far past its zone's heights a streak may end, for the zones whose streaks stay in them: list(zone = h).
 * Off target they read as a U, bars or socks. You should NEVER modify it.
 */
/proc/dirt_aim_bounds()
	RETURN_TYPE(/list)
	var/static/list/aim_bounds = list(DIRT_ZONE_BACK = 0, DIRT_ZONE_STOMACH = 0.1, DIRT_ZONE_GROIN = 0, DIRT_ZONE_THIGHS = 0)
	return aim_bounds

/**
 * Returns a streak's end pulled back along the streak until its height lies between two bounds: list(theta, h). The
 * streak keeps its own taper.
 *
 * A pulled-back end sits on its bound exactly. Summed back from the scale, it would miss the bound by a rounding now
 * and then, and the glint 0.3 px over a bound such as 0.02 falls midway between two rows, where a rounding picks one.
 *
 * Arguments:
 * - start_theta, start_along: Where the streak starts.
 * - end_theta, end_along: Where it would end.
 * - low, high: The bounds its end's height must keep inside.
 */
/proc/dirt_aim_inside(start_theta, start_along, end_theta, end_along, low, high)
	RETURN_TYPE(/list)
	var/rise = end_along - start_along
	var/scale = 1
	var/bound
	if(rise > 0 && end_along > high)
		scale = (high - start_along) / rise
		bound = high
	else if(rise < 0 && end_along < low)
		scale = (low - start_along) / rise
		bound = low
	scale = max(0, scale)
	var/along = (!isnull(bound) && scale > 0) ? bound : start_along + rise * scale
	return list(start_theta + (end_theta - start_theta) * scale, along)

/**
 * Returns how many pixels a clamped streak end's or a capped drip's bound moves in: odd on one side of a pair, 0 or 2
 * on the other, so the sides keep to different rows. It stays under the room the streak or drip starts with inside its
 * bound, so a streak never shrinks to nothing and a drip never runs up. Without the room an odd one moves 1 px out
 * where that's allowed (the knee); elsewhere it stays on the bound.
 *
 * Arguments:
 * - seed: The streak's seed, which picks 0 or 2 on the even side.
 * - odd: Whether it's on the odd side.
 * - room: How far inside its bound the streak or drip starts, in pixels.
 * - below: Whether the bound may move out instead.
 */
/proc/dirt_aim_inset(seed, odd, room, below)
	if(odd)
		return room > 1 ? 1 : (below ? -1 : 0)
	return (seed % 2 && room > 2) ? 2 : 0

/**
 * Returns the mess's tints, indexed by DIRT_ROLE_* define, each list(colour, alpha from 0 to 1), as dirt_baked_icon()
 * takes them. Pearl white, translucent where thin and near opaque where thick, a light grey underside that sets drops
 * apart on pale skin, and a white highlight. Haze is the film's colour at half its alpha, drawn as film at half coverage.
 * You should NEVER modify it.
 */
/proc/dirt_mess_role_tints()
	RETURN_TYPE(/list)
	var/static/list/tints = list(
		list("#F1EEE6", 0.21), // haze
		list("#F1EEE6", 0.42), // film
		list("#ECE7DA", 0.9), // body
		list("#CEC9BC", 0.8), // core
		list("#ECE7DA", 0.9), // fleck
		list("#FFFFFF", 1), // glint
	)
	return tints

#undef DIRT_AIM_MIRROR_PX
#undef DIRT_AIM_DROP_PX
#undef DIRT_AIM_BEADS_LEVEL
#undef DIRT_AIM_RUN_PITCH
#undef DIRT_AIM_RUN_PX
#undef DIRT_AIM_COVER_DRAWS
