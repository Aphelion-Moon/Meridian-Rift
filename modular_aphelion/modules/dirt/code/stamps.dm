/**
 * Marks put on the screen rather than on a limb, because a face and hands are too small to wrap dirt round. On a human
 * head only, the face takes a smudge on its dirtier cheek, and some causes smudge the other cheek a level lighter. At
 * level 4 both cheeks draw level 3, the smudges' top level. The fingertips take dirt. The dominant hand is a level
 * ahead (dirt_hands_levels()) unless both reach the same level. They do in a level 3 fall or machine work from level
 * 3. These marks are drawn over the deposit's other marks (dirt_overlay_stamps()), never on an eye or a mouth.
 */
/datum/dirt_feature/stamps
	/// The mob's dirtier side, 1 or -1. The cheek on that side takes face_level.
	var/side
	/// The dirtier cheek's level, 0 for none.
	var/face_level
	/// alist(hand zone = level): each hand's level, 0 or less for none.
	var/alist/hand_levels
	/// The other cheek's level, 0 for none.
	var/other_face_level
	/// Whether the face is covered, which runs the dirtier cheek's smudge on down to the jaw.
	var/covered

/**
 * Starts the marks.
 *
 * Arguments:
 * - side: The mob's dirtier side, 1 or -1.
 * - face_level: The dirtier cheek's level, 0 for none.
 * - hand_levels: alist(hand zone = level), or null for none.
 * - other_face_level: The other cheek's level, 0 for none.
 * - covered: Whether the face is covered.
 */
/datum/dirt_feature/stamps/New(side, face_level = 0, alist/hand_levels = null, other_face_level = 0, covered = FALSE)
	. = ..(null)
	src.side = side
	src.face_level = face_level
	src.hand_levels = hand_levels
	src.other_face_level = other_face_level
	src.covered = covered

/**
 * Returns the marks in one view: alist(index = DIRT_ROLE_* define, DIRT_STAMP_CLEAN or DIRT_STAMP_LIT). The other
 * cheek's marks never replace the dirtier cheek's body, and a hand's marks replace body only to wipe it clean. Facing
 * north the backs of the hands show, a level lighter, except at level 5 and up.
 *
 * Arguments:
 * - surface: The view's surface.
 */
/datum/dirt_feature/stamps/proc/pixels(datum/dirt_surface/surface)
	RETURN_TYPE(/alist)
	var/alist/marks = alist()
	if(surface.human_head)
		for(var/index, role in dirt_face_stamp(surface.direction, face_level, side))
			marks[index] = role
		for(var/index, role in dirt_face_stamp(surface.direction, other_face_level, -side))
			if(marks[index] != DIRT_ROLE_BODY)
				marks[index] = role
		if(covered)
			for(var/index, role in dirt_cover_face_stamp(surface.direction, side))
				marks[index] = role
	var/backs = surface.direction == NORTH
	for(var/zone, level in hand_levels)
		for(var/index, role in dirt_hand_stamp((backs && level < 5) ? level - 1 : level, surface, zone))
			if(marks[index] != DIRT_ROLE_BODY || role == DIRT_STAMP_CLEAN)
				marks[index] = role
	return marks

/**
 * Returns the face's smudges by direction, for a body whose right side is the dirtier: alist(direction = one list per
 * level, 1 to 3, of list(x, y, DIRT_ROLE_* define)). They keep off the face's edge column (sideburns), the forehead
 * (the hairline) and the mouth. Each body pixel has its film on the nose's side. Film may touch an eye's diagonal, but
 * body never does. You should NEVER modify it.
 */
/proc/dirt_face_stamps()
	RETURN_TYPE(/alist)
	var/static/alist/stamps
	if(stamps)
		return stamps
	stamps = alist()
	stamps[SOUTH] = list(
		list(list(12, 7, DIRT_ROLE_FILM), list(13, 7, DIRT_ROLE_FILM), list(13, 8, DIRT_ROLE_FILM)),
		list(list(13, 8, DIRT_ROLE_BODY), list(12, 7, DIRT_ROLE_FILM), list(13, 7, DIRT_ROLE_FILM), list(14, 8, DIRT_ROLE_FILM), list(12, 6, DIRT_ROLE_FILM)),
		list(list(12, 7, DIRT_ROLE_BODY), list(13, 8, DIRT_ROLE_BODY), list(12, 5, DIRT_ROLE_FILM), list(13, 5, DIRT_ROLE_FILM), list(12, 6, DIRT_ROLE_FILM), list(13, 7, DIRT_ROLE_FILM), list(14, 8, DIRT_ROLE_FILM), list(14, 9, DIRT_ROLE_FILM)),
	)
	stamps[EAST] = list(
		list(list(16, 9, DIRT_ROLE_FILM), list(17, 9, DIRT_ROLE_FILM)),
		list(list(16, 9, DIRT_ROLE_BODY), list(17, 9, DIRT_ROLE_FILM), list(16, 8, DIRT_ROLE_FILM), list(16, 10, DIRT_ROLE_FILM)),
		list(list(16, 9, DIRT_ROLE_BODY), list(17, 9, DIRT_ROLE_BODY), list(16, 8, DIRT_ROLE_FILM), list(17, 8, DIRT_ROLE_FILM), list(15, 9, DIRT_ROLE_FILM), list(16, 10, DIRT_ROLE_FILM), list(17, 10, DIRT_ROLE_FILM)),
	)
	stamps[WEST] = list(list(), list(), list())
	stamps[NORTH] = list(list(), list(), list())
	return stamps

/**
 * Returns a covered face's darker parts by direction, for a body whose right side is the dirtier: alist(direction =
 * list of list(x, y, DIRT_ROLE_* define)). The dirtier cheek's smudge runs on down to the jaw, off the eyes' rows and
 * the hair's edge: dark under clean eyes reads as a beard. You should NEVER modify it.
 */
/proc/dirt_cover_face()
	RETURN_TYPE(/alist)
	var/static/alist/faces
	if(faces)
		return faces
	faces = alist()
	faces[SOUTH] = list(list(12, 8, DIRT_ROLE_BODY), list(13, 9, DIRT_ROLE_BODY))
	faces[EAST] = list(list(17, 8, DIRT_ROLE_BODY))
	faces[WEST] = list()
	faces[NORTH] = list()
	return faces

/**
 * Returns a dirty face's smudges in one direction at a level: alist(index = DIRT_ROLE_* define), on a 32x32 canvas.
 *
 * Arguments:
 * - direction: The direction.
 * - level: The level, 0 or less for none. A level past 3 draws as 3.
 * - side: The dirtier side, 1 (the body's right) or -1.
 */
/proc/dirt_face_stamp(direction, level, side)
	RETURN_TYPE(/alist)
	if(level <= 0)
		return alist()
	var/list/by_level = dirt_face_stamps()[side > 0 ? direction : dirt_mirror_direction(direction)]
	return dirt_stamp_marks(by_level[min(level, 3)], side, direction)

/**
 * Returns a covered face's darker parts in one direction: alist(index = DIRT_ROLE_* define), on a 32x32 canvas.
 *
 * Arguments:
 * - direction: The direction.
 * - side: The dirtier side, 1 (the body's right) or -1.
 */
/proc/dirt_cover_face_stamp(direction, side)
	RETURN_TYPE(/alist)
	return dirt_stamp_marks(dirt_cover_face()[side > 0 ? direction : dirt_mirror_direction(direction)], side, direction)

/**
 * Returns the direction a face's marks are mirrored from for the body's left side: east and west swap, south and north
 * mirror themselves.
 *
 * Arguments:
 * - direction: The direction.
 */
/proc/dirt_mirror_direction(direction)
	switch(direction)
		if(EAST)
			return WEST
		if(WEST)
			return EAST
	return direction

/**
 * Returns face marks as alist(index = DIRT_ROLE_* define) on a 32x32 canvas, mirrored for the body's left side. Facing
 * south they're mirrored about the face's middle, and in profile about the canvas's middle.
 *
 * Arguments:
 * - marks: Each list(x, y, DIRT_ROLE_* define), for the body's right side, from the mirrored direction for the left.
 * - side: The dirtier side, 1 (the body's right) or -1.
 * - direction: The direction they're drawn in.
 */
/proc/dirt_stamp_marks(list/marks, side, direction)
	RETURN_TYPE(/alist)
	var/alist/placed = alist()
	var/mirror_at = side > 0 ? null : (direction == SOUTH ? 30 : 31)
	for(var/list/mark as anything in marks)
		var/column = isnull(mirror_at) ? mark[1] : mirror_at - mark[1]
		placed[mark[2] * ICON_SIZE_X + column + 1] = mark[3]
	return placed

/**
 * Returns a dirty hand's marks in one view: alist(index = DIRT_ROLE_* define, DIRT_STAMP_CLEAN or DIRT_STAMP_LIT).
 * A hand under 6 px takes none. By level:
 * - 1 to 3: darkest at the fingertips and ragged up the palm edge. The marks sit at offsets from the hand's outer
 *   column and its bottom row, and never fill a full row at the wrist.
 * - 4: a mechanic's hand. Film covers all of it, with body on the outer fingertip and its knuckle, and its lit back
 *   is wiped clean, so it never reads as a glove.
 * - 5 and up: solid to the wrist. The bottom row takes core, and its lit back takes film over whatever is there.
 *
 * Arguments:
 * - level: The level, 0 or less for none.
 * - surface: The view's surface.
 * - zone: BODY_ZONE_PRECISE_R_HAND or BODY_ZONE_PRECISE_L_HAND.
 */
/proc/dirt_hand_stamp(level, datum/dirt_surface/surface, zone)
	RETURN_TYPE(/alist)
	// by level: each list(columns in from the outer side, rows from the bottom, DIRT_ROLE_* define)
	var/static/list/offsets = list(
		list(list(1, 0, DIRT_ROLE_BODY), list(2, 0, DIRT_ROLE_FILM), list(0, -1, DIRT_ROLE_FILM)),
		list(list(1, 0, DIRT_ROLE_BODY), list(2, 0, DIRT_ROLE_BODY), list(0, -1, DIRT_ROLE_FILM), list(3, -1, DIRT_ROLE_FILM), list(2, -1, DIRT_ROLE_FILM)),
		list(list(1, 0, DIRT_ROLE_BODY), list(2, 0, DIRT_ROLE_BODY), list(0, -1, DIRT_ROLE_BODY), list(1, -1, DIRT_ROLE_FILM), list(3, -1, DIRT_ROLE_FILM), list(2, -1, DIRT_ROLE_FILM), list(3, -2, DIRT_ROLE_FILM)),
	)
	var/alist/marks = alist()
	var/list/points = surface.hand_pixels[zone]
	if(level <= 0 || length(points) < 6)
		return marks
	var/width = surface.width
	var/bottom = 0
	var/leftmost = width
	var/rightmost = -1
	for(var/index in points)
		var/row = floor((index - 1) / width)
		var/column = index - 1 - row * width
		bottom = max(bottom, row)
		leftmost = min(leftmost, column)
		rightmost = max(rightmost, column)
	var/lit = surface.hand_lit[zone]
	if(level >= 5)
		for(var/index in points)
			marks[index] = index == lit ? DIRT_STAMP_LIT : (floor((index - 1) / width) == bottom ? DIRT_ROLE_CORE : DIRT_ROLE_BODY)
		return marks
	// a hand on the screen's right has its outer side on the right
	var/right = (leftmost + rightmost) / 2 > 15.5
	if(level >= 4)
		var/tip
		for(var/index in points)
			marks[index] = DIRT_ROLE_FILM
			if(floor((index - 1) / width) == bottom && (isnull(tip) || (right ? index > tip : index < tip)))
				tip = index
		marks[tip] = DIRT_ROLE_BODY
		if((tip - width) in points)
			marks[tip - width] = DIRT_ROLE_BODY
		marks[lit] = DIRT_STAMP_CLEAN
		return marks
	for(var/list/offset as anything in offsets[level])
		var/column = right ? rightmost - offset[1] : leftmost + offset[1]
		var/index = surface.pixel_index(column, bottom + offset[2])
		if(index in points)
			marks[index] = offset[3]
	return marks
