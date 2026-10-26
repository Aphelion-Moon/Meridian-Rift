/**
 * Animation in the drawn character preview.
 *
 * iconforge draws a look's first frame only, so a drawing alone freezes what animates, like a halo's bob, an IPC
 * screen's blink or a galaxy suit's twinkle. Most of an animated look never moves, though: only the pixels its animated
 * icon states change from frame to frame. So beside each facing a drawing carries small patches, the look as it is at
 * each later step of its animation cropped to the box that changes, and the page lays them over the facing in turn.
 *
 * Which pixels an icon state changes, and between which of its frames, comes from reading the state once a round with
 * BYOND's icon procs, in SScharacter_preview's spare time: about a millisecond a frame. A look with a state not read yet
 * is drawn still, and drawn again once it has been.
 *
 * Patches are capped, by count and by pixels, for each drawing: iconforge draws the whole look for each before cropping
 * it. An animation with more steps than fit keeps fewer, evenly, each kept step shown for the time of those dropped
 * after it, so it still runs its whole length, in coarser steps.
 */

/// The most patches a drawing carries over all its facings.
#define CHARACTER_PREVIEW_ANIMATION_MAX_PATCHES 32
/// The most pixels those patches hold in all.
#define CHARACTER_PREVIEW_ANIMATION_MAX_PIXELS 16384
/// The longest an animation's steps run before they start again, in ms. Animations whose loops don't come round
/// together within it restart together at its end.
#define CHARACTER_PREVIEW_ANIMATION_MAX_PERIOD 20000
/// The most frames an icon state may have to be animated. Reading a frame of one takes about a millisecond.
#define CHARACTER_PREVIEW_ANIMATION_MAX_FRAMES 128
/// The most pixels a frame of an icon state may have to be animated.
#define CHARACTER_PREVIEW_ANIMATION_MAX_AREA (96 * 96)
/// The shortest a frame is shown, in ms.
#define CHARACTER_PREVIEW_ANIMATION_MIN_DELAY 10

/// Icon states read for animating this round: "file|state" -> what animating it takes, or FALSE for one drawn still.
/// See /datum/preview_animation_reading/proc/result().
GLOBAL_LIST_EMPTY(character_preview_animations)

/datum/controller/subsystem/character_preview
	/// Icon states waiting to be read for animating, by "file|state", oldest first.
	var/list/readings = list()
	/// Previews drawn still while states they show waited to be read. Each draws again once none waits.
	var/list/reading_waiters = list()

/**
 * What animating an icon state takes, if it has been read. If not, it waits to be read and this returns null. FALSE for
 * one that is drawn still: one that doesn't animate, or changes no pixel, or is too big to read, or animates only a
 * set number of times.
 */
/datum/controller/subsystem/character_preview/proc/animation_of(file, state)
	var/key = "[file]|[state]"
	var/known = GLOB.character_preview_animations[key]
	if(!isnull(known))
		return known
	var/datum/preview_animation_reading/reading = readings[key]
	if(!reading)
		reading = preview_animation_reading(file, state)
		if(!reading)
			GLOB.character_preview_animations[key] = FALSE
			return FALSE
	// While nothing would read it later, during init or while this can't fire, it is read at once.
	if(!can_fire || Master.init_stage_completed < INITSTAGE_MAX)
		readings -= key
		while(!reading.read_next())
			continue
		return (GLOB.character_preview_animations[key] = reading.result())
	readings[key] = reading

/// Reads what waits to be read, a frame at a time, while the tick has room. Once nothing waits, every preview drawn still
/// meanwhile draws again.
/datum/controller/subsystem/character_preview/proc/read_animations()
	while(length(readings))
		var/key = readings[1]
		var/datum/preview_animation_reading/reading = readings[key]
		if(reading.read_next())
			GLOB.character_preview_animations[key] = reading.result()
			readings -= key
		if(MC_TICK_CHECK)
			return
	tell_reading_waiters()

/// Reads everything waiting to be read at once, then has every preview drawn still meanwhile draw again.
/datum/controller/subsystem/character_preview/proc/read_animations_now()
	for(var/key, reading in readings)
		var/datum/preview_animation_reading/state_reading = reading
		while(!state_reading.read_next())
			continue
		GLOB.character_preview_animations[key] = state_reading.result()
	readings.Cut()
	tell_reading_waiters()

/datum/controller/subsystem/character_preview/proc/tell_reading_waiters()
	if(!length(reading_waiters))
		return
	var/list/waiters = reading_waiters
	reading_waiters = list()
	for(var/datum/preference_middleware/character_preview/waiter as anything in waiters)
		waiter.animation_read = TRUE
		waiter.preview_changed()

/// A reading of an animated icon state, or null for one that is drawn still without reading it.
/proc/preview_animation_reading(file, state)
	var/list/metadata = icon_metadata(file)
	if(!islist(metadata))
		return null
	var/width = metadata["width"]
	var/height = metadata["height"]
	if(width * height > CHARACTER_PREVIEW_ANIMATION_MAX_AREA)
		return null
	for(var/list/state_data as anything in metadata["states"])
		if(state_data["name"] != state)
			continue
		var/list/delays = state_data["delay"]
		var/frames = length(delays)
		// A state animated a set number of times is still once it has been, which is how the game shows it later on.
		if(frames < 2 || frames > CHARACTER_PREVIEW_ANIMATION_MAX_FRAMES || state_data["loop_count"])
			return null
		return new /datum/preview_animation_reading(file, state, delays, !!state_data["rewind"], state_data["dirs"], width, height)

/**
 * Reads which pixels of an animated icon state change, and between which frames, a frame at a time: each frame is
 * compared with the one before it, in every direction at once. A pixel that changes between any two frames is one
 * that changes between two that follow each other, so their differences together give the box that changes.
 *
 * BYOND's icon procs have no comparison, so it is made of them: each frame twice over, once as its colours and once as
 * its alpha in grey, both opaque, subtracted from the other frame's both ways and added up, is black where the two
 * frames are the same and not where they differ. Subtracting doesn't work on clear pixels, which only come out clear.
 * Shrinking that averages it, so a shrunk difference is black only if the whole was.
 */
/datum/preview_animation_reading
	var/file
	var/state
	/// How many frames the state has.
	var/frames
	/// How long each frame shows, in ms.
	var/list/delays
	/// Whether the state plays back and forth.
	var/rewind
	/// The directions the state draws: one, or the four the preview turns to.
	var/list/dirs
	var/width
	var/height
	/// The frame read last; past the last frame, the comparison of the last with the first.
	var/frame = 0
	var/icon/first_colours
	var/icon/first_alpha
	var/icon/last_colours
	var/icon/last_alpha
	/// White wherever any frame differs from the one before it.
	var/icon/union
	/// "[dir]" -> whether each frame differs from the one before it, the first from the last.
	var/list/changes = list()

/datum/preview_animation_reading/New(file, state, list/delays, rewind, dir_count, width, height)
	src.file = file
	src.state = state
	frames = length(delays)
	src.delays = list()
	for(var/delay in delays)
		src.delays += max(round(delay * 100), CHARACTER_PREVIEW_ANIMATION_MIN_DELAY)
	src.rewind = rewind
	dirs = dir_count == 1 ? list(SOUTH) : GLOB.cardinals
	src.width = width
	src.height = height
	for(var/dir in dirs)
		changes["[dir]"] = new /list(frames)

/// Reads the next frame. TRUE once every frame has been read and compared.
/datum/preview_animation_reading/proc/read_next()
	if(frame > frames)
		return TRUE
	frame++
	var/list/split
	if(frame <= frames)
		split = preview_animation_split(icon(file, state, null, frame))
	if(frame == 1)
		first_colours = split[1]
		first_alpha = split[2]
		last_colours = first_colours
		last_alpha = first_alpha
		return FALSE
	// Past the last frame: the loop's restart, the first frame again.
	var/icon/colours = split ? split[1] : first_colours
	var/icon/alpha = split ? split[2] : first_alpha
	var/icon/difference = preview_animation_difference(colours, alpha, last_colours, last_alpha)
	var/icon/shrunk = icon(difference)
	shrunk.Scale(width, 1)
	shrunk.MapColors(arglist(GLOB.preview_animation_amplify))
	shrunk.Scale(1, 1)
	var/index = frame <= frames ? frame : 1
	for(var/dir in dirs)
		changes["[dir]"][index] = shrunk.GetPixel(1, 1, null, dir) != "#000000"
	if(union)
		union.Blend(difference, ICON_ADD)
	else
		union = difference
	last_colours = colours
	last_alpha = alpha
	return frame > frames

/**
 * What animating the state takes: list("delays" = ms each frame shows, "rewind" = whether it plays back and forth,
 * "single" = whether it draws one direction for every facing, "dirs" = "[dir]" -> list("box" = the box that changes,
 * as x1, y1, x2, y2 from the lower left, "changes" = whether each frame differs from the one before it, the first from
 * the last)). A direction that changes nothing is left out. FALSE if none changes anything.
 */
/datum/preview_animation_reading/proc/result()
	if(!union)
		return FALSE
	var/icon/columns = icon(union)
	columns.Scale(width, 1)
	columns.MapColors(arglist(GLOB.preview_animation_amplify))
	var/icon/rows = union
	rows.Scale(1, height)
	rows.MapColors(arglist(GLOB.preview_animation_amplify))
	var/list/dir_results
	for(var/dir in dirs)
		var/x1 = 0
		var/x2 = 0
		for(var/x in 1 to width)
			if(columns.GetPixel(x, 1, null, dir) != "#000000")
				x1 ||= x
				x2 = x
		if(!x1)
			continue
		var/y1 = 0
		var/y2 = 0
		for(var/y in 1 to height)
			if(rows.GetPixel(1, y, null, dir) != "#000000")
				y1 ||= y
				y2 = y
		LAZYSET(dir_results, "[dir]", list("box" = list(x1, y1, x2, y2), "changes" = changes["[dir]"]))
	if(!dir_results)
		return FALSE
	return list("delays" = delays, "rewind" = rewind, "single" = length(dirs) == 1, "dirs" = dir_results)

/// Turns any colour white, and leaves black black, opaque.
GLOBAL_LIST_INIT(preview_animation_amplify, list(255, 255, 255, 0, 255, 255, 255, 0, 255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 1))

/// An icon as two opaque icons that differ wherever it does: its colours, and its alpha in grey. Uses up `source`.
/proc/preview_animation_split(icon/source)
	var/icon/colours = icon(source)
	colours.MapColors(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1)
	source.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1)
	return list(colours, source)

/// White where two icons, each split by preview_animation_split(), differ, and black where they don't.
/proc/preview_animation_difference(icon/colours, icon/alpha, icon/other_colours, icon/other_alpha)
	var/icon/difference = icon(colours)
	difference.Blend(other_colours, ICON_SUBTRACT)
	var/icon/part = icon(other_colours)
	part.Blend(colours, ICON_SUBTRACT)
	difference.Blend(part, ICON_ADD)
	part = icon(alpha)
	part.Blend(other_alpha, ICON_SUBTRACT)
	difference.Blend(part, ICON_ADD)
	part = icon(other_alpha)
	part.Blend(alpha, ICON_SUBTRACT)
	difference.Blend(part, ICON_ADD)
	difference.MapColors(arglist(GLOB.preview_animation_amplify))
	return difference

/// Whether an icon state has more than one frame, from its file's metadata, remembered by file and state.
/proc/preview_state_animated(file, state)
	var/static/list/animated = list()
	var/list/file_states = animated[file]
	. = file_states?[state]
	if(!isnull(.))
		return
	. = FALSE
	var/list/metadata = length("[file]") ? icon_metadata(file) : null
	for(var/list/state_data as anything in metadata?["states"])
		if(state_data["name"] == state)
			. = length(state_data["delay"]) > 1
			break
	// A single-state file is already cheap to look up in icon_metadata()'s cache. In particular,
	// custom paint revisions must not each leave another permanent flag-cache entry here.
	if(length(metadata?["states"]) > 1)
		if(!file_states)
			file_states = list()
			animated[file] = file_states
		file_states[state] = .

/**
 * The animated icon states a flat icon draws, and where: list(list(leaf, x, y), ...), with the leaf's lower left pixel
 * at (x, y) of the flat's own canvas. In a walk's recipes only crops move what is already drawn; an animated leaf that
 * anything else would move is left out, and drawn still.
 */
/proc/preview_animated_leaves(datum/universal_icon/node)
	var/list/placed
	if(isnull(node.frame) && preview_state_animated(node.icon_file, node.icon_state))
		placed = list(list(node, 1, 1))
	for(var/list/transform as anything in node.transform?.transforms)
		switch(transform["type"])
			if(RUSTG_ICONFORGE_BLEND_ICON)
				for(var/list/inner as anything in preview_animated_leaves(transform["icon"]))
					inner[2] += transform["x"] - 1
					inner[3] += transform["y"] - 1
					LAZYADD(placed, list(inner))
			if(RUSTG_ICONFORGE_CROP)
				for(var/list/entry as anything in placed)
					entry[2] -= transform["x1"] - 1
					entry[3] -= transform["y1"] - 1
			if(RUSTG_ICONFORGE_SCALE, RUSTG_ICONFORGE_FLIP, RUSTG_ICONFORGE_TURN, RUSTG_ICONFORGE_SHIFT)
				placed = null
	return placed

/**
 * A look's animation, for a walk: its facings' patches, as one iconforge recipe, and the steps the page shows them in.
 * `flats` is each facing's flat icon, `stamped` whether one flat walked facing UP serves them all (see
 * uni_icon_facings_json()), and `width` and `height` the canvas they share.
 *
 * What moves in a facing is split into regions: leaves whose boxes overlap move together, on one timeline, and apart
 * each keeps its own, so a quick flap and a slow flick don't make one long animation between them. Every patch is the
 * whole look at a step, drawn by iconforge and cropped to its region; they go side by side, top aligned, into one
 * image, "moving".
 *
 * Returns null when nothing moves; otherwise list("json" = the "moving" iconforge entry, in pieces that join into
 * "moving":recipe, "facings" = facing -> list(list("box" = list(x, y, width, height) of the region, from the canvas's
 * top left, "steps" = list(list(the patch's left edge in "moving", or -1 for the facing as drawn, ms shown), ...)),
 * ...)). Either way, "pending" = TRUE if a state it shows waits to be read, so it moves only in a later drawing.
 */
/proc/character_preview_animation(list/flats, stamped, width, height)
	var/pending = FALSE
	// Every animated leaf, numbered, and where it is drawn, for each facing.
	var/list/leaves
	var/list/placed_by_facing = list()
	for(var/facing, flat in flats)
		var/list/placed = stamped && length(placed_by_facing) ? placed_by_facing[placed_by_facing[1]] : preview_animated_leaves(flat)
		placed_by_facing[facing] = placed
		for(var/list/entry as anything in placed)
			LAZYOR(leaves, entry[1])
	if(!length(leaves))
		return null

	// Each facing's regions: list("box" = x1, y1, x2, y2 from the lower left, "tracks" = its leaves' tracks).
	var/list/regions_by_facing
	for(var/facing, placed in placed_by_facing)
		var/facing_dir = GLOB.character_preview_facings[facing]
		var/list/regions
		for(var/list/entry as anything in placed)
			var/datum/universal_icon/leaf = entry[1]
			var/list/animation = SScharacter_preview.animation_of(leaf.icon_file, leaf.icon_state)
			if(isnull(animation))
				pending = TRUE
				continue
			if(!animation)
				continue
			var/leaf_dir = animation["single"] ? SOUTH : (leaf.dir == UP || !leaf.dir ? facing_dir : leaf.dir)
			var/list/dir_result = animation["dirs"]["[leaf_dir]"]
			if(!dir_result)
				continue
			var/list/leaf_box = dir_result["box"]
			var/list/box = list(max(entry[2] + leaf_box[1] - 1, 1), max(entry[3] + leaf_box[2] - 1, 1), min(entry[2] + leaf_box[3] - 1, width), min(entry[3] + leaf_box[4] - 1, height))
			if(box[3] < box[1] || box[4] < box[2])
				continue
			var/list/region = list("box" = box, "tracks" = list(preview_animation_track(leaves.Find(leaf), animation, dir_result["changes"])))
			// Into every region it overlaps, until it overlaps none.
			var/merged = TRUE
			while(merged)
				merged = FALSE
				for(var/list/other as anything in regions)
					var/list/other_box = other["box"]
					box = region["box"]
					if(box[3] < other_box[1] || other_box[3] < box[1] || box[4] < other_box[2] || other_box[4] < box[2])
						continue
					region["box"] = list(min(box[1], other_box[1]), min(box[2], other_box[2]), max(box[3], other_box[3]), max(box[4], other_box[4]))
					region["tracks"] += other["tracks"]
					regions -= list(other)
					merged = TRUE
					break
			LAZYADD(regions, list(region))
		if(length(regions))
			LAZYSET(regions_by_facing, facing, regions)
	if(!length(regions_by_facing))
		return pending ? list("pending" = TRUE) : null

	// Each region's steps, as many as the caps leave room for. The room is shared out cheapest region first, each taking
	// what it needs up to an even share of what is left, so a small region keeps all its steps and the costliest give up
	// theirs; see preview_animation_fewer_steps().
	var/list/all_regions = list()
	for(var/facing, regions in regions_by_facing)
		for(var/list/region as anything in regions)
			var/list/steps = preview_animation_steps(region["tracks"])
			region["steps"] = steps
			var/list/box = region["box"]
			region["area"] = (box[3] - box[1] + 1) * (box[4] - box[2] + 1)
			region["cost"] = (length(steps) - 1) * region["area"]
			all_regions += list(region)
	sortTim(all_regions, GLOBAL_PROC_REF(cmp_preview_region_cost))
	var/patches_left = CHARACTER_PREVIEW_ANIMATION_MAX_PATCHES
	var/pixels_left = CHARACTER_PREVIEW_ANIMATION_MAX_PIXELS
	// "moving" is as tall as the tallest region that still moves.
	var/moving_height = 0
	for(var/index in 1 to length(all_regions))
		var/list/region = all_regions[index]
		var/list/steps = region["steps"]
		var/sharing = length(all_regions) - index + 1
		steps = preview_animation_fewer_steps(steps, min(length(steps) - 1, round(patches_left / sharing), round(pixels_left / sharing / region["area"])))
		region["steps"] = steps
		patches_left -= length(steps) - 1
		pixels_left -= (length(steps) - 1) * region["area"]
		if(length(steps) > 1)
			var/list/box = region["box"]
			moving_height = max(moving_height, box[4] - box[2] + 1)
	if(!moving_height)
		return pending ? list("pending" = TRUE) : null

	// The recipes, split where each patch fills in its own numbers. "moving" is joined into the job's JSON only once, in
	// draw_preview(): BYOND takes its time over every long string made, and patches are long and much alike.
	for(var/index in 1 to length(leaves))
		var/datum/universal_icon/leaf = leaves[index]
		leaf.frame = "@F[index]@"
	var/list/flats_marked = list()
	for(var/facing, flat in flats)
		var/datum/universal_icon/facing_flat = flat
		if(facing_flat in flats_marked)
			continue
		flats_marked += facing_flat
		// Not with crop(), which takes only numbers.
		facing_flat.transform.transforms += list(list("type" = RUSTG_ICONFORGE_CROP, "x1" = "@X1@", "y1" = "@Y1@", "x2" = "@X2@", "y2" = "@Y2@"))
	var/list/tokens_by_facing = list()
	if(stamped)
		var/datum/universal_icon/template = flats_marked[1]
		var/list/tokens = preview_animation_tokens(json_encode(template.to_list()))
		for(var/facing in flats)
			tokens_by_facing[facing] = tokens
	else
		for(var/facing, flat in flats)
			var/datum/universal_icon/facing_flat = flat
			tokens_by_facing[facing] = preview_animation_tokens(facing_flat.to_json())
	for(var/datum/universal_icon/facing_flat as anything in flats_marked)
		facing_flat.transform.transforms.len--
	for(var/datum/universal_icon/leaf as anything in leaves)
		leaf.frame = null

	// Each patch, laid into "moving" at its left edge.
	var/list/patch_json = list()
	var/moving_width = 0
	var/list/facings = list()
	for(var/facing, regions in regions_by_facing)
		var/list/page_regions = list()
		for(var/list/region as anything in regions)
			var/list/steps = region["steps"]
			if(length(steps) < 2)
				continue
			var/list/box = region["box"]
			var/region_width = box[3] - box[1] + 1
			var/region_height = box[4] - box[2] + 1
			// The facing's own numbers filled in once, its dir and the region's crop: what is left between leaves' frames
			// is joined, so each patch only fills in those.
			var/list/fills = list("0" = "[GLOB.character_preview_facings[facing]]", "-1" = "[box[1]]", "-2" = "[box[2]]", "-3" = "[box[3]]", "-4" = "[box[4]]")
			var/list/tokens = list()
			var/list/run = list()
			for(var/token in tokens_by_facing[facing])
				if(istext(token) || token <= 0)
					run += istext(token) ? token : fills["[token]"]
					continue
				tokens += jointext(run, "")
				tokens += token
				run.Cut()
			tokens += jointext(run, "")
			var/list/page_steps = list(list(-1, steps[1][2]))
			for(var/step_index in 2 to length(steps))
				var/alist/frames_now = preview_animation_frames_at(region["tracks"], steps[step_index][1])
				patch_json += ",{\"type\":\"[RUSTG_ICONFORGE_BLEND_ICON]\",\"icon\":"
				for(var/token in tokens)
					patch_json += istext(token) ? token : "[frames_now[token] || 1]"
				patch_json += ",\"blend_mode\":[ICON_OVERLAY],\"x\":[moving_width + 1],\"y\":[moving_height - region_height + 1]}"
				page_steps += list(list(moving_width, steps[step_index][2]))
				moving_width += region_width
			page_regions += list(list("box" = list(box[1] - 1, height - box[4], region_width, region_height), "steps" = page_steps))
		if(length(page_regions))
			facings[facing] = page_regions

	// A blank as big as every patch side by side, with each laid on it.
	var/datum/universal_icon/moving = uni_icon('icons/blanks/32x32.dmi', "nothing")
	moving.crop(1, 1, moving_width, moving_height)
	. = list("json" = list("\"moving\":[copytext(moving.to_json(), 1, -2)]") + patch_json + "]}", "facings" = facings)
	if(pending)
		.["pending"] = TRUE

/// Orders regions by what all their patches would take, cheapest first.
/proc/cmp_preview_region_cost(list/a, list/b)
	return a["cost"] - b["cost"]

/**
 * A recipe marked for patches, split where each fills in its own numbers: the pieces between, and in place of each
 * number a code for it: 0 for the facing's dir, a leaf's number for its frame, and -1 to -4 for the crop's x1, y1, x2
 * and y2.
 */
/proc/preview_animation_tokens(json)
	var/static/list/crop_codes = list("X1" = -1, "Y1" = -2, "X2" = -3, "Y2" = -4)
	. = list()
	var/list/by_dir = splittext(json, "\"dir\":[UP]")
	for(var/dir_index in 1 to length(by_dir))
		if(dir_index > 1)
			. += "\"dir\":"
			. += 0
		// Each mark is a string: "@F3@" is leaf 3's frame, "@X1@" the crop's x1.
		var/list/pieces = splittext(by_dir[dir_index], "\"@")
		. += pieces[1]
		for(var/piece_index in 2 to length(pieces))
			var/piece = pieces[piece_index]
			var/mark_end = findtext(piece, "@\"")
			var/mark = copytext(piece, 1, mark_end)
			. += crop_codes[mark] || text2num(copytext(mark, 2))
			. += copytext(piece, mark_end + 2)

/**
 * One leaf's frames in a facing, as the steps of preview_animation_steps() read them: list("leaf" = its number, "frames"
 * = each frame it shows in turn, "starts" = when each starts, in ms, "shows" = whether each looks different from the one
 * before it, the first from the last, "cycle" = how long they take in all).
 */
/proc/preview_animation_track(leaf_index, list/animation, list/changes)
	var/list/delays = animation["delays"]
	var/frame_count = length(delays)
	var/list/frames = list()
	for(var/frame in 1 to frame_count)
		frames += frame
	if(animation["rewind"])
		for(var/frame in frame_count - 1 to 2 step -1)
			frames += frame
	var/list/starts = list()
	var/list/shows = list()
	var/time = 0
	for(var/index in 1 to length(frames))
		starts += time
		time += delays[frames[index]]
		var/previous = frames[index == 1 ? length(frames) : index - 1]
		var/frame = frames[index]
		// Frames that follow each other: the later one's change from the one before, or the first's from the last.
		if(abs(frame - previous) == 1)
			shows += changes[max(frame, previous)]
		else
			shows += changes[1]
	return list("leaf" = leaf_index, "frames" = frames, "starts" = starts, "shows" = shows, "cycle" = time)

/**
 * A region's animation as steps, list(list(start, ms), ...): from the start, each time any of its leaves shows something
 * new, when, and for how long, in ms. The leaves start together and come round together once all their loops have, or
 * at CHARACTER_PREVIEW_ANIMATION_MAX_PERIOD. The first step is every leaf's first frame, the facing as drawn; see
 * preview_animation_frames_at() for the others.
 */
/proc/preview_animation_steps(list/tracks)
	var/period = 0
	var/longest = 0
	for(var/list/track as anything in tracks)
		var/cycle = track["cycle"]
		longest = max(longest, cycle)
		if(!period)
			period = cycle
			continue
		var/common = cycle
		var/rest = period
		while(rest)
			var/next = common % rest
			common = rest
			rest = next
		if(period / common > CHARACTER_PREVIEW_ANIMATION_MAX_PERIOD / cycle)
			period = longest
			break
		period = period / common * cycle
	var/alist/seen = alist()
	var/list/times = list()
	for(var/list/track as anything in tracks)
		var/list/starts = track["starts"]
		var/list/shows = track["shows"]
		var/cycle = track["cycle"]
		for(var/loop_start = 0; loop_start < period; loop_start += cycle)
			for(var/index in 1 to length(starts))
				var/time = loop_start + starts[index]
				if(time > 0 && time < period && shows[index] && !seen[time])
					seen[time] = TRUE
					times += time
	sortTim(times, GLOBAL_PROC_REF(cmp_numeric_asc))
	var/list/steps = list()
	var/start = 0
	for(var/time in times)
		steps += list(list(start, time - start))
		start = time
	steps += list(list(start, period - start))
	return steps

/// What frame each of a region's leaves shows `time` ms into its animation: leaf number -> frame.
/proc/preview_animation_frames_at(list/tracks, time)
	var/alist/frames = alist()
	for(var/list/track as anything in tracks)
		var/list/starts = track["starts"]
		var/into = time % track["cycle"]
		var/shown = 1
		while(shown < length(starts) && starts[shown + 1] <= into)
			shown++
		frames[track["leaf"]] = track["frames"][shown]
	return frames

/// The same steps, with only `keep` after the first: dropped evenly, each kept one shown for the time of those after it.
/proc/preview_animation_fewer_steps(list/steps, keep)
	var/later = length(steps) - 1
	if(keep >= later)
		return steps
	var/list/fewer = list(steps[1])
	if(keep < 1)
		return fewer
	for(var/group in 1 to keep)
		var/first = 2 + round((group - 1) * later / keep)
		var/last = 1 + round(group * later / keep)
		var/ms = 0
		for(var/index in first to last)
			ms += steps[index][2]
		fewer += list(list(steps[first][1], ms))
	return fewer

#undef CHARACTER_PREVIEW_ANIMATION_MAX_PATCHES
#undef CHARACTER_PREVIEW_ANIMATION_MAX_PIXELS
#undef CHARACTER_PREVIEW_ANIMATION_MAX_PERIOD
#undef CHARACTER_PREVIEW_ANIMATION_MAX_FRAMES
#undef CHARACTER_PREVIEW_ANIMATION_MAX_AREA
#undef CHARACTER_PREVIEW_ANIMATION_MIN_DELAY
