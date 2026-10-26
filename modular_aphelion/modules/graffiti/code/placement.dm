/// Time a paint job takes before GRAFFITI_REVEAL_PER_PIXEL is added for each painted pixel.
#define GRAFFITI_REVEAL_BASE (8 SECONDS)
/// Time a paint job adds per painted pixel, in deciseconds.
#define GRAFFITI_REVEAL_PER_PIXEL 0.5
/// Shortest time between two paint job steps.
#define GRAFFITI_REVEAL_MIN_STEP (1 SECONDS)

/**
 * Returns how a paint job reveals a piece: in strips GRAFFITI_REVEAL_STRIP pixels wide, left to right across each layer
 * in turn, from the bottom layer up.
 *
 * Arguments:
 * - piece: A canonical piece.
 *
 * Returns:
 * - list: "strips_per_layer", and "total", the strips in the whole piece.
 */
/proc/graffiti_reveal_units(list/piece)
	var/count = piece["width"] / GRAFFITI_REVEAL_STRIP
	return list("strips_per_layer" = count, "total" = length(piece["layers"]) * count)

/**
 * Returns how much of a piece shows once a paint job has revealed some of its strips, as graffiti_flatten() takes it.
 *
 * Arguments:
 * - piece: A canonical piece.
 * - progress: Strips revealed.
 *
 * Returns:
 * - list: The layer being revealed, every layer below it showing whole, then how many of its columns show from the left.
 *   Both are 0 when nothing is revealed, which graffiti_flatten() would take for the whole piece.
 */
/proc/graffiti_reveal_bounds(list/piece, progress)
	if(progress <= 0)
		return list(0, 0)
	var/count = graffiti_reveal_units(piece)["strips_per_layer"]
	var/layer = CEILING(progress / count, 1)
	return list(layer, (progress - (layer - 1) * count) * GRAFFITI_REVEAL_STRIP)

/**
 * Returns the placements a stopped paint job or freehand session left on a surface, to resume them there: those with its
 * placement id on the tile and, for a two-tile piece, on the tile to its right. They resume only on the same map and the
 * same tile, and only while every tile that showed paint still shows it.
 *
 * Arguments:
 * - resume: The Unfinished slot's resume data.
 * - tile: The tile clicked.
 * - arts: The art the piece showed on each of its tiles, left first.
 *
 * Returns:
 * - list: The left tile's placement, packed, or null, then the right tile's, or null. One of them is set.
 * - null: The resume data is for another map, tile or width, or paint it left is gone.
 */
/proc/graffiti_resume_placements(list/resume, turf/tile, list/arts)
	// Read as a map file's anchor is, so a piece stopped before windows took graffiti still resumes.
	if(!islist(resume) || resume["map"] != SSmapping.current_map.map_name || resume["width"] != length(arts) * GRAFFITI_WIDTH || !istext(resume["pid"]) || json_encode(SSgraffiti.check_anchor(resume["anchor"])) != json_encode(graffiti_anchor_for(tile)))
		return null
	var/list/kept = list(null, null)
	for(var/position in 1 to length(arts))
		var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(position == 1 ? tile : get_step(tile, EAST))
		for(var/packed in decal?.stack)
			if(SSgraffiti.unpack(packed)["pid"] == resume["pid"])
				kept[position] = packed
				break
		// Paint that was cleaned off would come back at once.
		var/list/art = arts[position]
		if(length(art?["pal"]) && !kept[position])
			return null
	return (kept[1] || kept[2]) ? kept : null

/**
 * Returns the tile a stopped paint job or freehand session left its paint on, the only one it resumes on: the left tile
 * of the placements with its placement id that still show on this map.
 *
 * Arguments:
 * - resume: The Unfinished slot's resume data, or null.
 * - ckey: The account that painted it.
 *
 * Returns:
 * - turf: The piece's left tile.
 * - null: No paint of it shows here, so it resumes nowhere.
 */
/proc/graffiti_resume_tile(list/resume, ckey)
	if(!islist(resume) || resume["map"] != SSmapping.current_map.map_name || !istext(resume["pid"]))
		return null
	var/turf/right_half
	for(var/packed in SSgraffiti.ckey_placements[ckey])
		var/obj/effect/decal/cleanable/crayon/custom/decal = SSgraffiti.shown[packed]
		if(!decal || SSgraffiti.placement_info[packed][GRAFFITI_INFO_PID] != resume["pid"])
			continue
		if(SSgraffiti.unpack(packed)["half"] != 2)
			return get_turf(decal)
		right_half = get_turf(decal)
	return right_half && get_step(right_half, WEST)

/**
 * Returns the anchor a stopped piece resumes on: its left tile's, with the kind of surface its paint went on, which a
 * window fastened over floor paint since doesn't change.
 *
 * Arguments:
 * - tile: The piece's left tile.
 * - packed: One of the piece's placements, packed as SSgraffiti keeps it: the right one when the left tile has no
 *   paint.
 *
 * Returns:
 * - list: The anchor.
 * - null: Graffiti on the tile lasts this round only, or the tile offers no surface now, as under a loosened pane.
 */
/proc/graffiti_resume_anchor(turf/tile, packed)
	if(!graffiti_surface_kind(tile))
		return null
	var/list/anchor = graffiti_anchor_for(tile)
	if(anchor)
		anchor["surface"] = SSgraffiti.unpack(packed)["anchor"]?["surface"]
	return anchor

/**
 * Lets the decals of a piece's tiles go of their merges once its painter stops painting there (release_merges()).
 *
 * Arguments:
 * - left_tile: The piece's left tile.
 * - width: The piece's width.
 */
/proc/graffiti_release_merges(turf/left_tile, width)
	for(var/turf/tile as anything in (width == GRAFFITI_WIDE_WIDTH ? list(left_tile, get_step(left_tile, EAST)) : list(left_tile)))
		var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(tile)
		decal?.release_merges()

/**
 * Drops for good the paint a stopping piece has placed, both halves of a two-tile one, when a tile of it offers no
 * surface now, as a pane loosened under it leaves one: a loose pane drops the piece in progress whole. Graffiti
 * finished there stays.
 *
 * Arguments:
 * - tile: The piece's left tile.
 * - width: The piece's width.
 * - placements: Its placements, packed, the left one then the right one, either null.
 *
 * Returns:
 * - TRUE/FALSE: Whether a tile of the piece offers no surface, which leaves the piece nothing to resume.
 */
/proc/graffiti_drop_loose_paint(turf/tile, width, list/placements)
	if(graffiti_surface_kind(tile) && (width != GRAFFITI_WIDE_WIDTH || graffiti_surface_kind(get_step(tile, EAST))))
		return FALSE
	for(var/packed in placements)
		if(packed)
			SSgraffiti.remove_placement(packed)
	return TRUE

/**
 * A spray can painting a saved piece onto a wall, a floor or a full-tile window over time: a do_after while each layer
 * appears in turn from the bottom, left to right in strips, the surface recomposited at each step. Finishing charges
 * the can once. Stopping leaves the paint revealed so far, and puts the piece in the painter's Unfinished slot, ready
 * to resume on that surface, unless a pane loosened under it, which drops the piece's paint whole.
 *
 * The steps are costly work that SScustom_sprite_work runs within its overrun budget, as it runs the editors' composites,
 * so under load they come late rather than at their time; the finish shows the whole piece when the do_after ends.
 *
 * Make one, then start() it. A player runs one at a time, kept in SSgraffiti.paint_jobs while it runs.
 */
/datum/graffiti_paint_job
	parent_type = /datum/custom_sprite_work_owner
	/// The painter.
	var/mob/living/user
	/// The spray can painting.
	var/obj/item/toy/crayon/spraycan/can
	/// The wall, floor or window tile painted: the left tile of a two-tile piece.
	var/turf/surface
	/// The canonical piece painted, the job's own copy.
	var/list/piece
	/// The piece's placement on the surface, packed as SSgraffiti keeps it, or null until its art has paint. The left half of a two-tile piece.
	var/placement
	/// The right half's placement of a two-tile piece, packed, or null.
	var/placement2
	/// list("progress" = strips revealed, "due" = strips the step timer has reached, which the next step reveals, "total" = strips in the piece, "per_step" = strips each tick of the step timer adds, "delay" = time between the ticks, "duration" = the do_after's time from where the job starts, before do_after applies the painter's action speed).
	var/list/reveal
	/// The timer whose ticks make the next strips due.
	var/step_timer
	/// The library piece painted, or "unfinished" for the Unfinished slot's piece.
	var/piece_id
	/// Each layer of the piece decoded by graffiti_layer_records(), once, so that the steps only merge them.
	var/list/layer_records
	/// When the last spray sound ends.
	COOLDOWN_DECLARE(spray_cooldown)

/**
 * Sets a job up, continuing a stopped one where `resume` is for this surface and the paint it left is still there.
 *
 * The job takes GRAFFITI_REVEAL_BASE plus GRAFFITI_REVEAL_PER_PIXEL for each painted pixel, half that for taggers, at the
 * painter's action speed as its do_after does. Its steps come about every GRAFFITI_REVEAL_MIN_STEP at most, a quick piece
 * revealing several strips a step, and spread over the whole job. A resumed job takes what is left of that.
 *
 * Arguments:
 * - user: The painter.
 * - can: The spray can, in the painter's hand.
 * - surface: The wall, floor or window tile, the left tile of a two-tile piece.
 * - piece: A copy of the canonical piece to paint.
 * - resume: The Unfinished slot's resume data, or null.
 * - piece_id: The library piece painted, or "unfinished" for the Unfinished slot's piece.
 */
/datum/graffiti_paint_job/New(mob/living/user, obj/item/toy/crayon/spraycan/can, turf/surface, list/piece, list/resume = null, piece_id = null)
	src.user = user
	src.can = can
	src.surface = surface
	src.piece = piece
	src.piece_id = piece_id
	layer_records = piece_records(piece)
	var/total = graffiti_reveal_units(piece)["total"]
	// The pixels the whole piece paints, as graffiti_art_pixels() counts them in its flattened art: those some layer paints
	// in a colour that shows.
	var/painted = 0
	for(var/position in 1 to piece["width"] * GRAFFITI_HEIGHT)
		for(var/list/record as anything in layer_records)
			var/index = record && record[2][position]
			if(index && copytext(record[1][index], 8) != "00")
				painted++
				break
	var/duration = (GRAFFITI_REVEAL_BASE + painted * GRAFFITI_REVEAL_PER_PIXEL) * (HAS_TRAIT(user, TRAIT_TAGGER) ? 0.5 : 1)
	// A painter whose actions take no time, as a test human's, finishes at once as the do_after does, and the strips keep the plain pace.
	var/slowdown = user.cached_multiplicative_actions_slowdown
	var/time = duration * (slowdown > 0 ? slowdown : 1)
	var/count = 1
	if(time / total < GRAFFITI_REVEAL_MIN_STEP)
		count = CEILING(total * GRAFFITI_REVEAL_MIN_STEP / time, 1)
	var/progress = 0
	if(isnum(resume?["progress"]) && resume["progress"] >= 1)
		progress = min(round(resume["progress"]), total)
		var/list/kept = graffiti_resume_placements(resume, surface, tile_arts(progress))
		if(kept)
			placement = kept[1]
			placement2 = kept[2]
		else
			progress = 0
	reveal = list("progress" = progress, "due" = progress, "total" = total, "per_step" = count, "delay" = time / CEILING(total / count, 1), "duration" = duration * (total - progress) / total)

/datum/graffiti_paint_job/Destroy()
	deltimer(step_timer)
	step_timer = null
	SScustom_sprite_work.queue -= src
	SSgraffiti.composite_line -= src
	for(var/ckey, job in SSgraffiti.paint_jobs)
		if(job == src)
			SSgraffiti.paint_jobs -= ckey
			// A painter who disconnected meanwhile left the library loaded for the job.
			if(!GLOB.directory[ckey])
				graffiti_library_unload(ckey)
			break
	user = null
	can = null
	surface = null
	return ..()

/**
 * Starts painting: the can shakes, the strips start appearing and the do_after runs. Nothing is placed before a strip
 * with paint shows, and a resumed job goes on with the placements it left.
 *
 * Returns:
 * - TRUE/FALSE: Whether the job started. It doesn't while the painter has another running, or when a two-tile piece has
 *   no surface to the right.
 */
/datum/graffiti_paint_job/proc/start()
	if(SSgraffiti.paint_jobs[user.ckey])
		can.balloon_alert(user, "already painting!")
		return FALSE
	if(piece["width"] == GRAFFITI_WIDE_WIDTH && !graffiti_wide_ok(surface))
		surface.balloon_alert(user, "no room!")
		return FALSE
	SSgraffiti.paint_jobs[user.ckey] = src
	graffiti_shake(user)
	log_game("[key_name(user)] [reveal["progress"] ? "resumed" : "started"] painting graffiti piece [piece_id] at [AREACOORD(surface)][reveal["progress"] ? " from strip [reveal["progress"]] of [reveal["total"]]" : ""]")
	step_timer = addtimer(CALLBACK(src, PROC_REF(advance)), reveal["delay"], TIMER_STOPPABLE | TIMER_LOOP)
	INVOKE_ASYNC(src, PROC_REF(await))
	return TRUE

/**
 * Waits out the job in a do_after on the surface, then finishes it, or stops it when the painter couldn't keep at it.
 */
/datum/graffiti_paint_job/proc/await()
	var/done = do_after(user, reveal["duration"], surface, extra_checks = CALLBACK(src, PROC_REF(still_valid)), interaction_key = "graffiti")
	// A job that ended while its do_after ran, as when its paint went, has nothing left to do.
	if(QDELETED(src))
		return
	if(done)
		finish()
	else
		interrupt()

/**
 * Whether the painter can keep painting: holding the uncapped can and able to use it, with the surface, both tiles of a
 * two-tile piece and of one kind, still taking graffiti and the paint revealed so far still on it.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/graffiti_paint_job/proc/still_valid()
	if(QDELETED(src) || !user?.is_holding(can) || can.is_capped || user.incapacitated)
		return FALSE
	return surface_valid()

/**
 * Whether the surface still takes the job's paint: both tiles of a two-tile piece and of one kind, still taking
 * graffiti, with the paint revealed so far still on them.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/graffiti_paint_job/proc/surface_valid()
	if(piece["width"] == GRAFFITI_WIDE_WIDTH ? !graffiti_wide_ok(surface) : !graffiti_surface_ok(surface))
		return FALSE
	return ((!placement || SSgraffiti.shown[placement]) && (!placement2 || SSgraffiti.shown[placement2])) ? TRUE : FALSE

/**
 * Returns the piece's layers decoded, once, for the steps to merge.
 *
 * Arguments:
 * - piece: The canonical piece.
 *
 * Returns:
 * - list: graffiti_layer_records() of the piece.
 */
/datum/graffiti_paint_job/proc/piece_records(list/piece)
	return graffiti_layer_records(piece)

/**
 * The step timer's tick: the next strips are due, and the job asks SScustom_sprite_work to reveal them as costly work.
 * Ticks that come while a step waits for the subsystem's overrun budget add their strips to it. The last strip waits for
 * finish(), so a job stopped early never shows the whole piece; the tick that reaches it stops the timer.
 */
/datum/graffiti_paint_job/proc/advance()
	var/last = reveal["total"] - 1
	if(reveal["due"] < last)
		reveal["due"] = min(reveal["due"] + reveal["per_step"], last)
		SScustom_sprite_work.queue |= src
	if(reveal["due"] >= last)
		deltimer(step_timer)
		step_timer = null

/// A step that is due merges the revealed layers and recomposites the surface: costly work, which waits for its turn
/// among every painter's composites (SSgraffiti's composite_turn()).
/datum/graffiti_paint_job/costly_work_due()
	return reveal["due"] > reveal["progress"] && SSgraffiti.composite_turn(src)

/**
 * Reveals the strips that are due on the surface, with the spray sound. A step that has to wait for the overrun budget
 * waits in SScustom_sprite_work's queue before this runs. Each step counts as one of the painter's composites for the
 * round, as a freehand session's do.
 *
 * Returns:
 * - TRUE/FALSE: FALSE while the step waits for its turn among every painter's composites, so it stays queued.
 */
/datum/graffiti_paint_job/run_deferred_work()
	if(reveal["due"] <= reveal["progress"])
		return TRUE
	if(!SSgraffiti.composite_turn(src))
		return FALSE
	SSgraffiti.composite_line -= src
	reveal["progress"] = reveal["due"]
	if(!paint(reveal["progress"]))
		interrupt()
		return TRUE
	var/datum/preferences/preferences = GLOB.preferences_datums[owner_ckey()]
	if(preferences)
		preferences.custom_sprite_pace.graffiti_composites++
	spray_cooldown = graffiti_spray(surface, spray_cooldown)
	return TRUE

/**
 * Completes the job: the whole piece on the surface, the can charged once, never refused, each tile's graffiti counted
 * as the painter's art and the painter given the graffiti achievement. A piece painted from the Unfinished slot leaves it.
 */
/datum/graffiti_paint_job/proc/finish()
	reveal["progress"] = reveal["total"]
	if(!paint(reveal["total"]))
		interrupt()
		return
	can.use_charges(user, GRAFFITI_COST * (HAS_TRAIT(user, TRAIT_TAGGER) ? 0.5 : 1), FALSE)
	log_game("[key_name(user)] painted graffiti piece [piece_id] at [AREACOORD(surface)]")
	credit_surface()
	user.client?.give_award(/datum/award/achievement/misc/custom_graffiti_painted, user)
	if(piece_id == "unfinished")
		var/datum/graffiti_library/library = graffiti_library(owner_ckey())
		// Unless something else took the slot meanwhile.
		if(library && json_encode(library.unfinished?["piece"]) == json_encode(piece))
			library.discard_unfinished(TRUE)
		if(can.graffiti_armed == "unfinished")
			can.graffiti_armed = null
	release_surface()
	qdel(src)

/// Marks each tile the finished piece is on as the painter's work (graffiti_credit_painter()).
/datum/graffiti_paint_job/proc/credit_surface()
	for(var/packed in list(placement, placement2))
		var/obj/effect/decal/cleanable/crayon/custom/decal = SSgraffiti.shown[packed]
		if(decal)
			graffiti_credit_painter(decal, user)

/// Lets go of the surface as the job ends: its tiles' decals let go of their merges.
/datum/graffiti_paint_job/proc/release_surface()
	graffiti_release_merges(surface, piece["width"])

/**
 * Returns where a stopped piece resumes: on its tiles while the paint revealed so far is still there. A pane loosened
 * under the piece drops all of that paint, both halves of a two-tile piece, and it resumes nowhere.
 *
 * Returns:
 * - list: The Unfinished slot's resume data.
 * - null: It resumes nowhere, and starts over wherever it is next painted.
 */
/datum/graffiti_paint_job/proc/stopped_resume()
	var/loose = graffiti_drop_loose_paint(surface, piece["width"], list(placement, placement2))
	var/packed = placement || placement2
	// Paint that went, cleaned, buried or dropped from a loosened pane, leaves nothing to resume.
	if(loose || !packed || (placement && !SSgraffiti.shown[placement]) || (placement2 && !SSgraffiti.shown[placement2]))
		return null
	return list("map" = SSmapping.current_map.map_name, "anchor" = graffiti_resume_anchor(surface, packed), "pid" = SSgraffiti.unpack(packed)["pid"], "progress" = reveal["progress"], "width" = piece["width"])

/**
 * Stops the job, leaving the paint revealed so far. The piece goes in the painter's Unfinished slot, with where to resume
 * it while that paint is still on the surface. A pane loosened under the piece drops all of the paint revealed, both
 * halves of a two-tile piece, and the piece goes in the slot with nowhere to resume.
 *
 * Arguments:
 * - keep: Whether the piece goes in the Unfinished slot. An admin deleting its paint stops the job with nothing kept.
 */
/datum/graffiti_paint_job/proc/interrupt(keep = TRUE)
	deltimer(step_timer)
	step_timer = null
	if(keep)
		var/datum/graffiti_library/library = graffiti_library(owner_ckey())
		var/error = library ? library.set_unfinished(piece, stopped_resume(), TRUE) : "Your graffiti library isn't available."
		if(error)
			to_chat(user, span_warning("Your unfinished graffiti couldn't be kept: [error]"))
	else
		to_chat(user, span_warning("Your graffiti is gone from the surface."))
	log_game("[key_name(user)] stopped painting graffiti piece [piece_id] at [AREACOORD(surface)], strip [reveal["progress"]] of [reveal["total"]]")
	release_surface()
	qdel(src)

/**
 * Shows the piece on its tiles as far as `progress` reveals it: new art for each tile's placement, or, once a tile's art
 * has paint, a new placement on top of its stack. Its time counts against every painter's composites
 * (SSgraffiti's spend_composite()). The halves of a two-tile piece share one placement id. A step whose
 * paint took the painter's own oldest pieces past their caps says so once, even one that stops the job.
 *
 * Arguments:
 * - progress: Strips revealed, at least 1.
 *
 * Returns:
 * - TRUE/FALSE: FALSE when a placement is gone or the surface refused the paint, which stops the job.
 */
/datum/graffiti_paint_job/proc/paint(progress)
	var/started = TICK_USAGE_REAL
	var/list/records = list()
	var/list/arts = tile_arts(progress, records)
	var/list/evicted = list()
	. = TRUE
	for(var/position in 1 to length(arts))
		var/list/art = arts[position]
		var/packed = position == 1 ? placement : placement2
		if(packed)
			var/result = SSgraffiti.update_placement_art(packed, art, records[position], evicted)
			// Null once the placement is gone: cleaned, buried or evicted. The job keeps the old packing, so interrupt() sees it went.
			if(!result)
				. = FALSE
				break
			packed = result
		else if(length(art["pal"]))
			var/pid = (placement || placement2) && SSgraffiti.unpack(placement || placement2)["pid"]
			packed = SSgraffiti.add_placement(position == 1 ? surface : get_step(surface, EAST), art, owner_ckey(), user.real_name, pid, length(arts) == 2 ? position : 0, evicted)
		else
			continue
		// A refusal leaves the job's placements as they were, so the piece resumes from the paint they show.
		if(!SSgraffiti.placement_info[packed])
			to_chat(user, span_warning("Your graffiti can't go there: [packed]."))
			. = FALSE
			break
		if(position == 1)
			placement = packed
		else
			placement2 = packed
	SSgraffiti.spend_composite(started)
	// The first half's evictions stand even when the second half stops the job.
	if(length(evicted))
		surface.balloon_alert(user, "your oldest graffiti made room!")

/**
 * Returns the art of each of the piece's tiles as far as `progress` reveals it.
 *
 * Arguments:
 * - progress: Strips revealed, at least 1.
 * - decoded_out: When given, filled with each tile's art decoded, in the same order.
 *
 * Returns:
 * - list: The left tile's art, then for a two-tile piece the right tile's.
 */
/datum/graffiti_paint_job/proc/tile_arts(progress, list/decoded_out = null)
	var/list/bounds = graffiti_reveal_bounds(piece, progress)
	var/list/record = list()
	var/list/art = graffiti_flatten_records(layer_records, piece["width"], bounds[1], bounds[2], record)
	if(piece["width"] == GRAFFITI_WIDE_WIDTH)
		return graffiti_split_wide(art, record, decoded_out)
	if(decoded_out)
		decoded_out.Cut()
		decoded_out += list(record)
	return list(art)

/**
 * Returns the account the job paints for, which keeps its placements and its Unfinished piece even when the painter's
 * body loses its player.
 *
 * Returns:
 * - text: The ckey the job runs under in SSgraffiti.paint_jobs, or the painter's before it starts.
 */
/datum/graffiti_paint_job/proc/owner_ckey()
	for(var/ckey, job in SSgraffiti.paint_jobs)
		if(job == src)
			return ckey
	return user?.ckey

#undef GRAFFITI_REVEAL_BASE
#undef GRAFFITI_REVEAL_PER_PIXEL
#undef GRAFFITI_REVEAL_MIN_STEP
