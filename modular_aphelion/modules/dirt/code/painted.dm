// The hand-painted designs a bare body's skin wears, each a cell of the reference generator's.
/// Oil or soot worked in from the hands: machine work in oil or grease, smoke in soot.
#define DIRT_PAINTED_HANDS "A"
/// Soot from a blast.
#define DIRT_PAINTED_BLAST "B"
/// Mud from a plunge.
#define DIRT_PAINTED_PLUNGE "C"
/// Walking, in any material.
#define DIRT_PAINTED_WALK "W"
/// Kneeling, in any material.
#define DIRT_PAINTED_KNEEL "K"
/// How near a body pixel's place must lie to a painted point to take it, in pixels round and along the limb.
#define DIRT_PAINTED_REACH 0.8

/**
 * Returns the design each deposit wears on bare skin. The designs painted in their materials' own tones are keyed
 * alist("<cause>:<material id>" = DIRT_PAINTED_* define), and grease wears oil's, in its own colour. The designs any
 * material wears are keyed alist(cause = DIRT_PAINTED_* define). You should NEVER modify it.
 */
/proc/dirt_painted_cells()
	RETURN_TYPE(/alist)
	var/static/alist/cells
	if(!cells)
		cells = alist()
		cells["[DIRT_CAUSE_MACHINE]:[DIRT_MATERIAL_OIL]"] = DIRT_PAINTED_HANDS
		cells["[DIRT_CAUSE_MACHINE]:[DIRT_MATERIAL_GREASE]"] = DIRT_PAINTED_HANDS
		cells["[DIRT_CAUSE_SMOKE]:[DIRT_MATERIAL_SOOT]"] = DIRT_PAINTED_HANDS
		cells["[DIRT_CAUSE_BLAST]:[DIRT_MATERIAL_SOOT]"] = DIRT_PAINTED_BLAST
		cells["[DIRT_CAUSE_PLUNGE]:[DIRT_MATERIAL_MUD]"] = DIRT_PAINTED_PLUNGE
		cells[DIRT_CAUSE_WALK] = DIRT_PAINTED_WALK
		cells[DIRT_CAUSE_KNEEL] = DIRT_PAINTED_KNEEL
	return cells

/**
 * Returns the dirtier side of the body a design was painted on: 1 for the right, -1 for the left. A body dirtier on
 * the other side wears it mirrored.
 *
 * Arguments:
 * - cell: A DIRT_PAINTED_* define.
 */
/proc/dirt_painted_side(cell)
	return (cell == DIRT_PAINTED_HANDS || cell == DIRT_PAINTED_PLUNGE) ? 1 : -1

/**
 * Returns a design's points: list(limbs, thetas, heights, materials, roles). Each list has an entry for each point, in
 * the order its pixels were painted, row by row. materials is null for a design any material wears. The points are
 * made once for every design, from the plain human template facing south they were painted on. That's SSdirt's
 * template, or one built on the spot if SSdirt hasn't built that direction yet. You should NEVER modify it.
 *
 * Arguments:
 * - cell: A DIRT_PAINTED_* define.
 * - version: Which of its two versions, 1 or 2.
 */
/proc/dirt_painted_points(cell, version)
	RETURN_TYPE(/list)
	var/static/alist/points
	if(!points)
		var/datum/dirt_surface/human = SSdirt.human_surface(SOUTH)
		if(!human)
			var/datum/dirt_template/built = dirt_build_template_now(dirt_metric_sources(), list(SOUTH))
			human = built.surfaces[SOUTH]
		points = dirt_painted_points_on(human)
	var/list/versions = points[cell]
	return versions[version]

/**
 * Returns every design's points on a surface, as dirt_painted_points() keeps them: alist(DIRT_PAINTED_* define = list
 * of each version's points). A point is a painted pixel where the surface has a limb other than the head, which keeps
 * the deposit's own marks. Each point holds its place on that limb, its material and its role.
 *
 * Arguments:
 * - surface: The plain human template facing south.
 */
/proc/dirt_painted_points_on(datum/dirt_surface/surface)
	RETURN_TYPE(/alist)
	// glyph = list(material id, DIRT_ROLE_* define): oil in capitals, soot in small letters, mud in letters of its own
	var/alist/coloured = alist(
		"B" = list(DIRT_MATERIAL_OIL, DIRT_ROLE_BODY),
		"F" = list(DIRT_MATERIAL_OIL, DIRT_ROLE_FILM),
		"H" = list(DIRT_MATERIAL_OIL, DIRT_ROLE_HAZE),
		"C" = list(DIRT_MATERIAL_OIL, DIRT_ROLE_CORE),
		"s" = list(DIRT_MATERIAL_SOOT, DIRT_ROLE_BODY),
		"f" = list(DIRT_MATERIAL_SOOT, DIRT_ROLE_FILM),
		"h" = list(DIRT_MATERIAL_SOOT, DIRT_ROLE_HAZE),
		"m" = list(DIRT_MATERIAL_MUD, DIRT_ROLE_BODY),
		"n" = list(DIRT_MATERIAL_MUD, DIRT_ROLE_FILM),
		"o" = list(DIRT_MATERIAL_MUD, DIRT_ROLE_HAZE),
		"c" = list(DIRT_MATERIAL_MUD, DIRT_ROLE_CORE),
	)
	// glyph = DIRT_ROLE_* define, for the designs any material wears
	var/alist/roles_alone = alist(
		"c" = DIRT_ROLE_CORE,
		"m" = DIRT_ROLE_BODY,
		"n" = DIRT_ROLE_FILM,
		"o" = DIRT_ROLE_HAZE,
		"k" = DIRT_ROLE_FLECK,
	)
	var/list/flags_of = surface.flags_of
	var/alist/made = alist()
	for(var/cell, versions in dirt_painted_grids())
		var/any_material = cell == DIRT_PAINTED_WALK || cell == DIRT_PAINTED_KNEEL
		var/list/made_versions = list()
		for(var/list/rows as anything in versions)
			var/list/limbs = list()
			var/list/thetas = list()
			var/list/heights = list()
			var/list/materials = any_material ? null : list()
			var/list/roles = list()
			for(var/row in 0 to length(rows) - 1)
				var/line = rows[row + 1]
				for(var/column in 0 to length(line) - 1)
					var/glyph = copytext(line, column + 1, column + 2)
					var/index = row * surface.width + column + 1
					var/limb = DIRT_PIXEL_LIMB(flags_of[index])
					if(!limb || limb == DIRT_LIMB_HEAD)
						continue
					if(any_material)
						if(!roles_alone[glyph])
							continue
						roles += roles_alone[glyph]
					else
						var/list/painted = coloured[glyph]
						if(!painted)
							continue
						materials += painted[1]
						roles += painted[2]
					limbs += limb
					thetas += surface.theta_of[index]
					heights += surface.height_of[index]
			made_versions += list(list(limbs, thetas, heights, materials, roles))
		made[cell] = made_versions
	return made

/**
 * Returns the hand-painted design a deposit wears on a bare body's skin, a DIRT_PAINTED_* define, or null for a deposit
 * without one. It's its cause's cell in its material, or else its cause's cell in any material (dirt_painted_cells()).
 * A deposit without one draws on a bare body as on a dressed one.
 *
 * Arguments:
 * - cause: A general DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 */
/proc/dirt_painted_design(cause, datum/dirt_material/material)
	var/alist/cells = dirt_painted_cells()
	return cells["[cause]:[material.id]"] || cells[cause]

/**
 * Returns a deposit's hand-painted design on a bare body's skin below the head, or null for a deposit without one
 * (dirt_painted_design()). A design is painted on the plain human template facing south. Each of its pixels becomes a
 * point on that body's surface (dirt_painted_points()), so the design wraps round any body and turns with it. The
 * deposit's own "painted:" stream (dirt_general_stream()) picks one of the design's two versions, a jitter round and
 * along the limbs, and the seed of its noise. The points are mirrored for a body dirtier on the other side, and copied
 * round the body where dirt goes all round (dirt_painted_around()). A level shows some of them (dirt_painted_shown()),
 * the same ones in every direction (dirt_painted_near()). Each pixel of the body then takes the role of the nearest
 * point on its limb within DIRT_PAINTED_REACH, and the point painted first wins a tie. At level 4 the role is a step
 * darker: haze goes to film and film to body. Every pixel drawn has a thickness of 1.
 *
 * Arguments:
 * - cause: A DIRT_CAUSE_* define.
 * - material: The /datum/dirt_material it's made of.
 * - level: 1 to the cause's top level.
 * - variant: 0 to DIRT_VARIANTS - 1.
 * - side: The mob's dirtier side, 1 or -1.
 * - surface: The direction's surface.
 */
/proc/dirt_painted_rasterise(cause, datum/dirt_material/material, level, variant, side, datum/dirt_surface/surface)
	RETURN_TYPE(/datum/dirt_pixels)
	var/cell = dirt_painted_design(cause, material)
	if(!cell)
		return null
	var/alist/near = dirt_painted_near(cell, cause, material, level, variant, side)
	var/datum/dirt_pixels/drawn = new(surface.width, surface.height)
	var/list/flags_of = surface.flags_of
	var/list/stepped = level >= 4 ? dirt_stepped_up_roles() : null
	for(var/index in 1 to length(flags_of))
		var/flags = flags_of[index]
		var/limb = DIRT_PIXEL_LIMB(flags)
		if(!limb || limb == DIRT_LIMB_HEAD || !DIRT_PIXEL_ZONE(flags))
			continue
		var/list/entry = near[limb]
		if(!entry)
			continue
		var/list/point_thetas = entry[1]
		var/list/point_heights = entry[2]
		var/alist/point_bins = entry[4]
		var/degrees_per_pixel = entry[5]
		var/h_per_pixel = entry[6]
		var/theta = surface.theta_of[index]
		var/along = surface.height_of[index]
		var/rows_up = along / h_per_pixel
		var/reach_degrees = (DIRT_PAINTED_REACH + 0.01) * degrees_per_pixel
		var/nearest
		var/nearest_distance
		// a point further along or round the limb than a little past the reach can't be the nearest within it
		for(var/row in floor(rows_up - DIRT_PAINTED_REACH - 0.01) to floor(rows_up + DIRT_PAINTED_REACH + 0.01))
			for(var/point in point_bins[row])
				var/apart = theta - point_thetas[point]
				apart = DIRT_WRAP_DEGREES(apart)
				if(abs(apart) > reach_degrees)
					continue
				var/across = apart / degrees_per_pixel
				var/up = (along - point_heights[point]) / h_per_pixel
				var/distance = sqrt(across * across + up * up)
				if(isnull(nearest) || distance < nearest_distance || (distance == nearest_distance && point < nearest))
					nearest = point
					nearest_distance = distance
		if(isnull(nearest) || nearest_distance > DIRT_PAINTED_REACH)
			continue
		var/list/point_roles = entry[3]
		var/role = point_roles[nearest]
		drawn.roles[index] = stepped ? stepped[role] : role
		drawn.thicknesses[index] = 1
	return drawn

/**
 * Returns the points of a deposit's design that its level shows, by limb, for dirt_painted_rasterise() to place:
 * alist(limb = list(thetas, heights, roles, alist(row = indexes), degrees per pixel, h per pixel)). Each limb's entry
 * holds the points shown on it, each point's copies in turn, and their indexes by the row up the limb each lies in. A
 * design painted in materials' own tones keeps the points painted in the deposit's material. Grease takes oil's,
 * because the hands' design is lettered in oil and soot alone. No surface comes in. The points lie on the plain human
 * template facing south (dirt_painted_points()), and each is copied and shown by its own limb, theta and h
 * (dirt_painted_around(), dirt_painted_shown()). The limbs are measured once a round (dirt_metric()), so only placing
 * the points on pixels reads a direction. The last deposit's points are kept, so the four directions a mask job draws
 * it in, one after another, build them once. You should NEVER modify it.
 *
 * Arguments:
 * - cell: The deposit's DIRT_PAINTED_* define, from dirt_painted_design().
 * - cause, material, level, variant, side: As dirt_painted_rasterise()'s.
 */
/proc/dirt_painted_near(cell, cause, datum/dirt_material/material, level, variant, side)
	RETURN_TYPE(/alist)
	var/static/kept_key
	var/static/alist/kept
	var/shown_level = min(level, 3)
	// all it reads: the cause and material pick the cell, and drafting picks the noise dirt_painted_shown() samples
	var/key = "[cause]:[material.id]:[shown_level]:[variant]:[side]:[SSdirt.drafting]"
	if(key == kept_key)
		return kept
	var/datum/dirt_random/rng = dirt_general_stream("painted:[cause]:[num2text(variant, 12)]")
	var/list/points = dirt_painted_points(cell, rng.randrange(2) + 1)
	var/theta_jitter = rng.uniform(-6, 6)
	var/height_jitter = rng.uniform(-0.02, 0.02)
	var/seed = rng.randrange(65536)
	var/mirror = side != dirt_painted_side(cell)
	var/dirty_leg = side < 0 ? DIRT_LIMB_L_LEG : DIRT_LIMB_R_LEG
	var/list/limbs = points[1]
	var/list/thetas = points[2]
	var/list/heights = points[3]
	var/list/materials = points[4]
	var/list/roles = points[5]
	var/lettered = material.id == DIRT_MATERIAL_GREASE ? DIRT_MATERIAL_OIL : material.id
	var/alist/near = alist()
	for(var/position in 1 to length(limbs))
		if(materials && materials[position] != lettered)
			continue
		var/limb = limbs[position]
		var/theta = thetas[position]
		if(mirror)
			theta = -theta
			switch(limb)
				if(DIRT_LIMB_R_ARM)
					limb = DIRT_LIMB_L_ARM
				if(DIRT_LIMB_L_ARM)
					limb = DIRT_LIMB_R_ARM
				if(DIRT_LIMB_R_LEG)
					limb = DIRT_LIMB_L_LEG
				if(DIRT_LIMB_L_LEG)
					limb = DIRT_LIMB_R_LEG
		theta += theta_jitter
		var/along = heights[position] + height_jitter
		var/role = roles[position]
		for(var/copy in dirt_painted_around(cell, material.id, limb, theta, along, role))
			if(!dirt_painted_shown(cell, limb, copy, along, role, shown_level, seed, dirty_leg))
				continue
			var/list/entry = near[limb]
			if(!entry)
				var/list/metric = dirt_metric(limb)
				entry = list(list(), list(), list(), alist(), metric[1], metric[2])
				near[limb] = entry
			var/list/near_thetas = entry[1]
			var/list/near_heights = entry[2]
			var/list/near_roles = entry[3]
			var/alist/bins = entry[4]
			near_thetas += copy
			near_heights += along
			near_roles += role
			var/row = floor(along / entry[6])
			var/list/bin = bins[row]
			if(!bin)
				bin = list()
				bins[row] = bin
			bin += length(near_thetas)
	kept_key = key
	kept = near
	return near

/**
 * Returns the thetas round its limb that a design's point is copied to. A design painted from the front goes all
 * round where the dirt would. A plunge coats all round, and walking splashes all round the lower legs, so those go to
 * the back and both sides. A knee's film and haze wrap round to its sides. Greasy hands are greasy front and back, and
 * soot settles on the shoulders' tops behind too. Each copy is shown or not where it ends up.
 *
 * Arguments:
 * - cell: A DIRT_PAINTED_* define.
 * - material_id: The deposit's material id.
 * - limb: The point's limb, mirrored.
 * - theta: Its theta, mirrored and jittered.
 * - along: Its h, jittered.
 * - role: Its DIRT_ROLE_* define.
 */
/proc/dirt_painted_around(cell, material_id, limb, theta, along, role)
	RETURN_TYPE(/list)
	var/is_arm = limb == DIRT_LIMB_R_ARM || limb == DIRT_LIMB_L_ARM
	if(cell == DIRT_PAINTED_PLUNGE || cell == DIRT_PAINTED_WALK)
		return list(theta, 180 - theta, theta + 90, theta - 90)
	if(cell == DIRT_PAINTED_KNEEL)
		if(is_arm && along < 0.25)
			return list(theta, 180 - theta)
		// its body keeps the painted ragged edge, because widened it would fill into a strap
		if((limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_L_LEG) && along >= 0.45 && (role == DIRT_ROLE_FILM || role == DIRT_ROLE_HAZE))
			return list(theta, theta + 35, theta - 35)
	else if(cell == DIRT_PAINTED_HANDS && ((material_id == DIRT_MATERIAL_SOOT && limb == DIRT_LIMB_TORSO && along >= 0.8) || (is_arm && along < 0.25)))
		return list(theta, 180 - theta)
	return list(theta)

/**
 * Returns whether a design's point shows at a level. At 3 every point does. Grease and soot build from the hands, and
 * a blast from its core out. Walking climbs the legs from the feet behind a ragged line, because a level line reads as
 * boots. Kneeling dirties the kneeling knee first, then both legs and the hands. Mud comes in patches that grow, a
 * little ahead on the legs, because mud built from the feet reads as boots.
 *
 * Arguments:
 * - cell: A DIRT_PAINTED_* define.
 * - limb: The point's limb.
 * - theta: Its theta, as copied (dirt_painted_around()).
 * - along: Its h.
 * - role: Its DIRT_ROLE_* define.
 * - level: 1 to 3.
 * - seed: The design's noise seed.
 * - dirty_leg: The dirtier side's leg, the kneeling one.
 */
/proc/dirt_painted_shown(cell, limb, theta, along, role, level, seed, dirty_leg)
	if(level >= 3)
		return TRUE
	var/is_arm = limb == DIRT_LIMB_R_ARM || limb == DIRT_LIMB_L_ARM
	var/is_leg = limb == DIRT_LIMB_R_LEG || limb == DIRT_LIMB_L_LEG
	var/dark = role == DIRT_ROLE_BODY || role == DIRT_ROLE_CORE
	if(cell == DIRT_PAINTED_HANDS)
		var/on_hands = is_arm && along < 0.25
		return level == 1 ? on_hands : (on_hands || dark || (is_arm && role == DIRT_ROLE_FILM))
	if(cell == DIRT_PAINTED_BLAST)
		return level == 1 ? dark : role != DIRT_ROLE_HAZE
	if(cell == DIRT_PAINTED_KNEEL)
		if(level == 1)
			return limb == dirty_leg && dark && along >= 0.4
		return (is_leg && role != DIRT_ROLE_HAZE && along >= 0.15) || dark
	if(cell == DIRT_PAINTED_WALK && !is_leg)
		return FALSE
	var/list/metric = dirt_metric(limb)
	if(cell == DIRT_PAINTED_WALK)
		var/rag = (dirt_spread_noise(theta / metric[1], along / metric[2], seed, 2) - 0.5) * 0.2
		return along + rag < (level == 1 ? 0.3 : 0.45)
	var/bias = is_leg ? (along < 0.5 ? 0.15 : 0.08) : 0
	return dirt_spread_noise(theta / metric[1], along / metric[2], seed, 3) + bias > (level == 1 ? 0.7 : 0.46)

/**
 * Returns the designs as painted, on the plain human template facing south: alist(DIRT_PAINTED_* define = list of its
 * two versions, each 32 rows of 32 glyphs from the top, "." for none). It's read once a round, when the points are
 * made (dirt_painted_points()), so it isn't kept.
 */
/proc/dirt_painted_grids()
	RETURN_TYPE(/alist)
	var/alist/grids = alist()
	// oil (B body, F film, H haze, C core) or soot (s body, f film, h haze) from the hands
	grids[DIRT_PAINTED_HANDS] = list(
		list(
			"................................",
			"................................",
			"................................",
			"..............f.f...............",
			".............f..................",
			"..............ffff..............",
			"...........f.......f............",
			"...........f.fhhhf.f............",
			"............FBh..hh.............",
			".............F..................",
			"...........hfh.h.hfh............",
			"..........ffh.h..h.ff...........",
			".........fh.......HFHf..........",
			"........h........HFBF...........",
			"..................HFH...........",
			"........H.............H.........",
			".......HF..HF.........FH........",
			".......FFH.FBF.......HFF........",
			".......FFHH.FFH.HF..HHFF........",
			".......BF.F....HFFH.F.FB........",
			".......BBFB.........BFBB........",
			"........CB...........BC.........",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		),
		list(
			"................................",
			"................................",
			"................................",
			"..............f.f...............",
			".............f..................",
			"..............ffff..............",
			"...........f.......f............",
			"...........f.fhhhf.f............",
			"............FBh..hh.............",
			".............F..................",
			"...........fffhfhfff............",
			"..........sfffhfhfffs...........",
			".........ffhffhfhfHFHf..........",
			"........hfh.fh.h.HFBFhh.........",
			"........h...f.h..FBF..h.........",
			"........H...h.h.HFH...H.........",
			".......HF..HF..HF.....FH........",
			".......FFH.FBF.H.....HFF........",
			".......FFHH.FFH.HF..HHFF........",
			".......BF.F....HFFH.F.FB........",
			".......BBFB.........BFBB........",
			"........CB...........BC.........",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
		),
	)
	// soot from a blast (s body, f film, h haze)
	grids[DIRT_PAINTED_BLAST] = list(
		list(
			"................................",
			"................................",
			"................................",
			".............ff.................",
			"............ff..................",
			"..............fffh..............",
			"...........f.......h............",
			"...........f.fhhhf.h............",
			"............ssf..fh.............",
			".............fh.................",
			"...........fsfhh.hh.............",
			"..........ssffffhh.hh...........",
			".........sssssfffhh.h...........",
			"........fsssssfffhh.h...........",
			"........fsss.ssffhh.h...........",
			".......ffsf.ssfhh.h...h.........",
			".......sff.fssffh.....h.........",
			".......fsf.hfsfh.h...h..........",
			".......ffsf.hffh.......h........",
			".......sffh..hh.......h.........",
			".......ssff.h.......h.f.........",
			"........sf............f.........",
			"................................",
			"................................",
			"................................",
			"...........hfh..................",
			"...........fh...................",
			"............h...................",
			"................................",
			"..........hf....................",
			".........hffh...................",
			"..........hh....................",
		),
		list(
			"................................",
			"................................",
			"................................",
			".............ff.................",
			"............ff..................",
			"..............fffh..............",
			"...........f.......h............",
			"...........f.fhhhf.h............",
			"............ssf..fh.............",
			".............fh.................",
			"...........fsfhh.hh.............",
			"..........ssffffhh.hh...........",
			".........sssssfffhh.h...........",
			"........fsssssfffhh.h...........",
			"........fsss.ssffhh.h...........",
			".......ffsf.ssfhh.h...h.........",
			".......sff.fssffh.....h.........",
			".......fsf.hfsfhfh...h..........",
			".......ffsf.hffhfh.....h........",
			".......sffh.fhh.h.....h.........",
			".......ssff.hh.h....h.f.........",
			"........sf............f.........",
			"...........hh.h.................",
			"................................",
			"...........h.h....h.............",
			"...........hffh.h.h.............",
			"...........ffhh..hh.............",
			"...........hfh....h.............",
			"............hfh..h..............",
			"..........hhfh...h.h............",
			"..........hffh....hh............",
			"...........hh......h............",
		),
	)
	// mud from a plunge (c core, m body, n film, o haze), the second running down in drips
	grids[DIRT_PAINTED_PLUNGE] = list(
		list(
			"................................",
			"................................",
			"................................",
			".............mmnmm..............",
			"............mnmmnmm.............",
			"...........mmnnnnnmm............",
			"...........mm.....mn............",
			"...........mmnooonmn............",
			"............mmnnnmn.............",
			".............mnnnn..............",
			"...........nmmnnnmnn............",
			"..........mnnmnonnnnm...........",
			".........mnonmmnnonnnm..........",
			"........mmnnnnnnonmmnnm.........",
			"........mnnonnonnnmnnnm.........",
			".......mmnnnmmnnonnnnnmm........",
			".......mmn.nmnnnnnmn.nmm........",
			".......mmm.nnnmnnmmn.mmn........",
			".......mmmmmnmmnmmnmmmmm........",
			".......mcmmmmmnmmmmmmmcm........",
			".......cmcmmmmmcmmmmmcmc........",
			"........cc.mmmmmmcmm.cc.........",
			"...........mmmcmmmmm............",
			"...........mmmmmmcmm............",
			"...........mmmm.mmmm............",
			"...........mmmm.mmmm............",
			"...........mnmm.mmnm............",
			"...........mmmm.mmmm............",
			"...........mmmm.mmmm............",
			"..........mmmmm.mmmmm...........",
			".........mmcmmc.cmmcmm..........",
			".........cccccc.cccccc..........",
		),
		list(
			"................................",
			"................................",
			"................................",
			".............mmnmm..............",
			"............mnmmnmm.............",
			"...........mmnnnnmmm............",
			"...........mm.....mm............",
			"...........mmnooonmn............",
			"............mmnnnmm.............",
			".............mnnnm..............",
			"...........nmnnnnnmn............",
			"..........mnnnnonnnnm...........",
			".........mnnmmnnonnmnm..........",
			"........mnnmmmnnnnnmmnm.........",
			"........mnnnmnnnmmnmmnm.........",
			".......mmnnnmnnmmmnmmnmm........",
			".......mmn.nnmnmmmmm.nmm........",
			".......mmm.mnmmmmmmm.mmn........",
			".......mmmmmmmmmmmmmmmmm........",
			".......mcmmmmmmmmmmmmmcm........",
			".......cmcmmmmmcmmmmmcmc........",
			"........cc.mmmmmmcmm.cc.........",
			"...........mmmcmmmmm............",
			"...........mmmmmmcmm............",
			"...........mmmm.mmmm............",
			"...........mmmm.mmmm............",
			"...........mnmm.mmnm............",
			"...........mmmm.mmmm............",
			"...........mmmm.mmmm............",
			"..........mmmmm.mmmmm...........",
			".........mmcmmc.cmmcmm..........",
			".........cccccc.cccccc..........",
		),
	)
	// walking (c core, m body, n film, o haze, k fleck)
	grids[DIRT_PAINTED_WALK] = list(
		list(
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"............o...................",
			"............o.....n.............",
			".............n...nm.............",
			"............no..nmn.............",
			"............nn..mmnm............",
			"..........nmmnn.mmmmn...........",
			".........nmmmmm.mmmkmm..........",
			".........mccccm.cccccm..........",
		),
		list(
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"............o....o..............",
			".............o...on.............",
			"............on...nmn............",
			"............n.o.nm.n............",
			"...........n.m..mmmn............",
			"..........n.mnm.nm.mn...........",
			".........mmnmmm.mmmm.m..........",
			".........cn.cm...mc.nm..........",
		),
	)
	// kneeling on one knee, then both (m body, n film, o haze)
	grids[DIRT_PAINTED_KNEEL] = list(
		list(
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"......................o.........",
			"........o............nmn........",
			"........nn...........mm.........",
			"................................",
			"................................",
			".................no.............",
			".................nmo............",
			"............nn..mmm.............",
			".............o...mnn............",
			".................nm.............",
			".................on.............",
			"..................no............",
			"..................noo...........",
		),
		list(
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"................................",
			"........o.............o.........",
			"........nn...........nn.........",
			"............o.....n.............",
			"............no...on.............",
			"................................",
			"............nm...n..............",
			"...........nmm...nmn............",
			"............mn..nmmm............",
			"............m.n..mn.............",
			"............n.....m.............",
			"............o.....n.............",
			"................................",
		),
	)
	return grids

#undef DIRT_PAINTED_HANDS
#undef DIRT_PAINTED_BLAST
#undef DIRT_PAINTED_PLUNGE
#undef DIRT_PAINTED_WALK
#undef DIRT_PAINTED_KNEEL
#undef DIRT_PAINTED_REACH
