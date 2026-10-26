/**
 * A paint job places nothing while its steps reveal no paint, then shows layer 1 from the left a few strips a step. A
 * step waits in SScustom_sprite_work's queue while its overrun budget is spent, or every painter's composite share, and
 * steps that came meanwhile land together. The last strip waits for the finish, which charges the can GRAFFITI_COST,
 * half that for a tagger. A slowed painter's steps spread over their slower do_after. The job is driven step by step: a
 * test human's do_after ends at once, so start() would finish it.
 */
/datum/unit_test/graffiti_paint_job_steps/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "Runtime Station must have a wall between two floors to paint.")
	var/turf/wall = turfs[1]
	var/list/held = graffiti_editor_test_painter(src, wall)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	// Layer 1 is painted in columns 10 and 20 of the top row, and the glowing layer 2 in its last strip, column 30 of the second.
	var/list/piece = graffiti_validate_piece(list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = "Steps", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000", "#39ff1480"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("[repeat_string(9, "0")]1[repeat_string(9, "0")]2[repeat_string(1004, "0")]", 2, 1024)),
		list("name" = "Drip", "glow" = TRUE, "grid" = custom_sprite_encode_grid("[repeat_string(61, "0")]2[repeat_string(962, "0")]", 2, 1024)),
	)))
	var/datum/graffiti_paint_job/job = allocate(/datum/graffiti_paint_job, painter, can, wall, piece)
	TEST_ASSERT_EQUAL(job.reveal["per_step"], 2, "A step of this quick piece must reveal two strips.")
	job.advance()
	job.run_deferred_work()
	TEST_ASSERT(!job.placement && !graffiti_tile_decal(wall), "A step that reveals no paint must place nothing.")
	// The subsystem runs only this job, from a spent overrun budget, then a spent composite share, then both full,
	// and is put back before asserting.
	var/list/queued = SScustom_sprite_work.queue
	var/budget = SScustom_sprite_work.overrun_budget
	SScustom_sprite_work.queue = list()
	SScustom_sprite_work.overrun_budget = -1000
	SScustom_sprite_work.overrun_budget_at = world.time
	job.advance()
	SScustom_sprite_work.fire()
	var/waited = !job.placement && (job in SScustom_sprite_work.queue)
	SScustom_sprite_work.overrun_budget = initial(SScustom_sprite_work.overrun_budget)
	SSgraffiti.composite_share = -1000
	SSgraffiti.composite_share_at = world.time
	SScustom_sprite_work.fire()
	var/shared = !job.placement && (job in SScustom_sprite_work.queue)
	SSgraffiti.composite_share = GRAFFITI_COMPOSITE_SHARE_BURST
	SScustom_sprite_work.fire()
	var/landed = job.placement && !(job in SScustom_sprite_work.queue)
	SScustom_sprite_work.queue = queued + SScustom_sprite_work.queue
	SScustom_sprite_work.overrun_budget = budget
	TEST_ASSERT(waited && shared && landed, "With the overrun budget spent, and then every painter's composite share, a step must wait in SScustom_sprite_work's queue and land once both are back: waited [waited] and [shared], landed [landed].")
	var/list/art = SSgraffiti.art[SSgraffiti.unpack(job.placement)["art"]]
	TEST_ASSERT_EQUAL(graffiti_art_hash(art), graffiti_art_hash(graffiti_flatten(piece, 1, 4 * GRAFFITI_REVEAL_STRIP)), "Two steps must show layer 1's first four strips.")
	TEST_ASSERT_EQUAL(graffiti_art_pixels(art), 1, "Two steps must show only layer 1's pixel in column 10.")
	for(var/position in 1 to job.reveal["total"])
		job.advance()
	job.run_deferred_work()
	art = SSgraffiti.art[SSgraffiti.unpack(job.placement)["art"]]
	TEST_ASSERT(job.reveal["progress"] == job.reveal["total"] - 1 && graffiti_art_pixels(art) == 2, "Steps must stop one strip short of the whole piece: [job.reveal["progress"]]")
	job.finish()
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(wall)
	art = SSgraffiti.art[SSgraffiti.unpack(decal.stack[1])["art"]]
	TEST_ASSERT_EQUAL(graffiti_art_hash(art), graffiti_art_hash(graffiti_flatten(piece)), "The finish must show the whole piece.")
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST, "A finished job must charge the can once.")
	ADD_TRAIT(painter, TRAIT_TAGGER, TRAIT_SOURCE_UNIT_TESTS)
	job = allocate(/datum/graffiti_paint_job, painter, can, wall, piece)
	job.finish()
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST * 1.5, "A tagger's job must cost half as much.")
	painter.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 2)
	job = allocate(/datum/graffiti_paint_job, painter, can, wall, piece)
	var/time = CEILING(job.reveal["total"] / job.reveal["per_step"], 1) * job.reveal["delay"]
	TEST_ASSERT(abs(time - job.reveal["duration"] * painter.cached_multiplicative_actions_slowdown) < 0.1, "A slowed painter's steps must spread over their do_after: [time]")

/**
 * Stops the test's paint jobs and puts the registry and the library back.
 */
/datum/unit_test/graffiti_paint_job_steps/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A paint job stopped partway, here by a step whose paint the map has no room for, keeps its piece, progress and
 * placement in the Unfinished slot, its paint showing as far as the map took it. Resumed on the same wall it goes on from
 * that strip and finishes in the same stack entry, which empties the slot; on another wall it starts over.
 */
/datum/unit_test/graffiti_paint_job_resume/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "Runtime Station must have two walls side by side between floors.")
	var/list/held = graffiti_editor_test_painter(src, turfs[1])
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	// One layer of eight strips with paint in the first and the third, slow enough that a step reveals one strip.
	var/list/piece = graffiti_validate_piece(list("format" = GRAFFITI_FORMAT, "version" = GRAFFITI_FORMAT_VERSION, "name" = "Resume", "description" = "", "width" = GRAFFITI_WIDTH, "palette" = list("#ff0000"), "layers" = list(
		list("name" = "Base", "glow" = FALSE, "grid" = custom_sprite_encode_grid("1[repeat_string(8, "0")]1[repeat_string(1014, "0")]", 1, 1024)),
	)))
	var/datum/graffiti_paint_job/job = allocate(/datum/graffiti_paint_job, painter, can, turfs[1], piece)
	TEST_ASSERT_EQUAL(job.reveal["per_step"], 1, "A step of this piece must reveal one strip.")
	job.advance()
	job.advance()
	job.run_deferred_work()
	var/shown_hash = SSgraffiti.art_of(job.placement)
	// The map is full, and the painter's job is all there is to evict.
	SSgraffiti.art_byte_budget = SSgraffiti.art_bytes
	job.advance()
	job.run_deferred_work()
	SSgraffiti.art_byte_budget = GRAFFITI_MAP_ART_BYTES
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(turfs[1])
	TEST_ASSERT(QDELETED(job) && length(decal?.stack) == 1 && SSgraffiti.art_of(decal.stack[1]) == shown_hash, "A step the map has no room for must stop the job, leaving the paint shown so far on the wall.")
	var/datum/graffiti_library/library = graffiti_library(painter.ckey)
	var/list/resume = library.unfinished?["resume"]
	TEST_ASSERT(resume?["progress"] == 3 && resume["pid"] == SSgraffiti.unpack(decal.stack[1])["pid"], "A stopped job must keep its progress and placement in the Unfinished slot: [json_encode(resume)]")
	var/list/slot = graffiti_copy_piece(library.unfinished["piece"])
	job = allocate(/datum/graffiti_paint_job, painter, can, turfs[2], slot, resume, "unfinished")
	TEST_ASSERT(job.reveal["progress"] == 0 && !job.placement, "On another wall the job must start over.")
	job = allocate(/datum/graffiti_paint_job, painter, can, turfs[1], slot, resume, "unfinished")
	TEST_ASSERT(job.reveal["progress"] == 3 && job.placement == decal.stack[1], "Resumed on its wall, the job must go on from its strip with its placement.")
	// A test human's do_after ends at once, so the job finishes as it starts.
	TEST_ASSERT(job.start() && QDELETED(job), "The resumed job must start and finish.")
	TEST_ASSERT(length(decal.stack) == 1 && graffiti_art_pixels(SSgraffiti.art[SSgraffiti.unpack(decal.stack[1])["art"]]) == 2, "The resumed job must finish in the same stack entry.")
	TEST_ASSERT_NULL(library.unfinished, "Finishing the Unfinished slot's piece must empty the slot.")

/**
 * Stops the test's paint jobs and puts the registry and the library back.
 */
/datum/unit_test/graffiti_paint_job_resume/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A two-tile paint job puts its halves on the wall and its east neighbour under one placement id and charges the can
 * once, and refuses to start on a wall with a floor to its right.
 */
/datum/unit_test/graffiti_paint_job_wide/Run()
	graffiti_editor_test_begin()
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "Runtime Station must have two walls side by side between floors.")
	var/list/held = graffiti_editor_test_painter(src, turfs[1])
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/obj/item/toy/crayon/spraycan/can = held[2]
	var/charges = can.charges_left
	var/list/piece = graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDE_WIDTH))
	var/datum/graffiti_paint_job/job = allocate(/datum/graffiti_paint_job, painter, can, turfs[1], piece)
	// A test human's do_after ends at once, so the job finishes as it starts.
	TEST_ASSERT(job.start() && QDELETED(job), "The paint job must start and finish.")
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(turfs[1])
	var/obj/effect/decal/cleanable/crayon/custom/other = graffiti_tile_decal(turfs[2])
	TEST_ASSERT(length(decal?.stack) == 1 && length(other?.stack) == 1, "A two-tile piece must go on both walls.")
	var/list/left = SSgraffiti.unpack(decal.stack[1])
	var/list/right = SSgraffiti.unpack(other.stack[1])
	TEST_ASSERT(left["half"] == 1 && right["half"] == 2 && left["pid"] == right["pid"], "The halves must share one placement id: [left["pid"]] [right["pid"]]")
	TEST_ASSERT_EQUAL(can.charges_left, charges - GRAFFITI_COST, "A two-tile job must charge the can once.")
	var/turf/wall
	for(var/turf/closed/wall/start in Z_TURFS(painter.z))
		if(graffiti_surface_ok(start) && !graffiti_tile_decal(start) && isfloorturf(get_step(start, EAST)) && graffiti_surface_ok(get_step(start, EAST)))
			wall = start
			break
	TEST_ASSERT(wall, "Runtime Station must have a wall with a floor to its right.")
	job = allocate(/datum/graffiti_paint_job, painter, can, wall, piece)
	TEST_ASSERT(!job.start() && !job.placement && !job.placement2 && !graffiti_tile_decal(wall) && !graffiti_tile_decal(get_step(wall, EAST)) && !SSgraffiti.paint_jobs[painter.ckey], "A two-tile job must not start on a wall with a floor to its right.")

/**
 * Stops the test's paint jobs and puts the registry and the library back.
 */
/datum/unit_test/graffiti_paint_job_wide/Destroy()
	graffiti_editor_test_end()
	return ..()

/**
 * A full-tile window fastened down takes graffiti on its glass, drawn over the window and under closed shutters, and
 * the graffiti goes for good when the window is deleted or washed. A pane loosened under a paint job drops the job's
 * paint, while finished graffiti stays, and the job keeps nothing to resume; carried off its tile, the pane takes the
 * finished graffiti too. A directional window leaves its floor a floor.
 */
/datum/unit_test/graffiti_window_surface/Run()
	graffiti_editor_test_begin()
	// A station floor, which graffiti needs, clear of structures, with floors south of it for a painter and east of it
	// for the pane to be carried to.
	var/turf/floor
	for(var/turf/open/floor/candidate as anything in graffiti_test_floors(200))
		if(isfloorturf(get_step(candidate, SOUTH)) && isfloorturf(get_step(candidate, EAST)) && !(locate(/obj/structure) in candidate) && !(locate(/obj/machinery) in candidate))
			floor = candidate
			break
	TEST_ASSERT(floor, "Runtime Station must have a station floor clear of structures with floors south and east of it.")
	var/obj/structure/window/fulltile/window = allocate(/obj/structure/window/fulltile, floor)
	TEST_ASSERT(graffiti_surface_ok(floor) && graffiti_surface_kind(floor) == GRAFFITI_KIND_WINDOW && graffiti_window_of(floor) == window, "A full-tile window must make its tile a window surface: [graffiti_surface_kind(floor)]")
	var/packed = SSgraffiti.add_placement(floor, graffiti_test_art(1), "graffiti_test", "Jane Doe")
	var/obj/effect/decal/cleanable/crayon/custom/decal = locate() in floor
	TEST_ASSERT(decal?.kind == GRAFFITI_KIND_WINDOW && (packed in decal.stack), "Graffiti on a window must go on a window's decal: [packed]")
	TEST_ASSERT(decal.plane == window.plane && decal.layer > window.layer && decal.layer < SHUTTER_LAYER, "Graffiti on a window must draw over the glass and under closed shutters: plane [decal.plane], layer [decal.layer].")
	qdel(window)
	TEST_ASSERT(QDELETED(decal) && !(packed in SSgraffiti.placements), "Graffiti must go for good with its window.")
	window = allocate(/obj/structure/window/fulltile, floor)
	packed = SSgraffiti.add_placement(floor, graffiti_test_art(2), "graffiti_test", "Jane Doe")
	decal = graffiti_tile_decal(floor)
	window.wash(CLEAN_WASH)
	TEST_ASSERT(decal && QDELETED(decal) && !(packed in SSgraffiti.placements), "Washing a window must wash its graffiti off for good.")
	var/finished = SSgraffiti.add_placement(floor, graffiti_test_art(3), "graffiti_test", "Jane Doe")
	var/list/held = graffiti_editor_test_painter(src, floor)
	var/mob/living/carbon/human/consistent/painter = held[1]
	var/datum/graffiti_paint_job/job = allocate(/datum/graffiti_paint_job, painter, held[2], floor, graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH)))
	job.advance()
	job.run_deferred_work()
	var/in_progress = job.placement
	window.set_anchored(FALSE)
	job.interrupt()
	var/datum/graffiti_library/library = graffiti_library(painter.ckey)
	TEST_ASSERT(in_progress && !(in_progress in SSgraffiti.placements) && SSgraffiti.shown[finished], "A pane loosened under a paint job must drop the job's paint and keep finished graffiti: [in_progress]")
	TEST_ASSERT(library?.unfinished && isnull(library.unfinished["resume"]), "A paint job stopped by a loosened pane must keep its piece with nowhere to resume: [json_encode(library?.unfinished?["resume"])]")
	// The move's own check waits for the move to be over, as a shuttle carries the decal after its window.
	decal = SSgraffiti.shown[finished]
	window.forceMove(get_step(floor, EAST))
	decal.check_window(window)
	TEST_ASSERT(QDELETED(decal) && !(finished in SSgraffiti.placements), "Graffiti must go for good once its window leaves the tile.")
	qdel(window)
	allocate(/obj/structure/window, floor)
	TEST_ASSERT(!graffiti_window_of(floor) && graffiti_surface_kind(floor) == GRAFFITI_KIND_FLOOR, "A directional window must leave its floor a floor.")

/**
 * Stops the test's paint job and puts the registry and the library back.
 */
/datum/unit_test/graffiti_window_surface/Destroy()
	graffiti_editor_test_end()
	return ..()
