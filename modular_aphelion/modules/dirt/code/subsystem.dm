/// The most rounds finish_all() goes: the bodies a round draws again can ask for masks, which the next round makes.
#define DIRT_MAX_FINISH_ROUNDS 10
/// How many templates SSdirt keeps built, besides SSdirt.human_template: about 220 KB each, so about 3.5 MB, and one
/// a queued job holds lives until that job is done. One built again costs about 30 ms, spread over four fires.
#define DIRT_TEMPLATE_CACHE_SIZE 16
/// How many masks SSdirt keeps: 0.4-1.2 KB each with its place here, icons aside (measured; the most a skin set on four
/// limbs), so about 0.3 MB. Masks dropped and made again reuse their cached rasters and icons' resource cache entries.
#define DIRT_MASK_CACHE_SIZE 256
/// How many splats' rasters SSdirt keeps, each one text of under 400 characters under its key: 1.0-1.6 KB each as
/// measured, scratch included, so under 3.3 MB. At about 200 players the live keys (about 6400) outnumber it, so an
/// idle player's old splats are rasterised again when that body's masks are made again.
#define DIRT_RASTER_CACHE_SIZE 2048
/// How many whole sprite directions dirt_sprite_pixels() keeps, the ones read most lately: about 1.1 KB each, so under
/// 300 KB. Only SSdirt's pieces read them: a template up to 40, a body's masks a few dozen.
#define DIRT_SPRITE_READS 256
/// How many sprites' facings dirt_sprite_facings() keeps, about 180 bytes each, so under 400 KB: the genital sheets
/// hold about 1200 states parts are read from.
#define DIRT_SPRITE_FACINGS 2048
/// What a cached raster's directions are joined by: drawn() writes only "0" to "o" (ASCII 48 to 111).
#define DIRT_RASTER_SEPARATOR ","

/**
 * Work SSdirt does a piece at a time (next_piece()), each piece in its own try/catch (make_piece()), so a piece that
 * runtimes drops its job, cached as failed, and can't hold up the jobs after it.
 */
/datum/dirt_job
	/// Whether it can't make what it's for: a piece runtimed, or what it reads is missing.
	var/failed = FALSE
	/// How many pieces it has made, across every fire: past most_pieces() it's dropped.
	var/pieces_made = 0

/**
 * Makes the next piece.
 *
 * Returns:
 * - TRUE: It's done, or failed.
 * - FALSE: Pieces are left.
 */
/datum/dirt_job/proc/next_piece()
	return TRUE

/**
 * Returns the most pieces it can take, across every fire. One that takes more is dropped as failed.
 */
/datum/dirt_job/proc/most_pieces()
	return 1

/**
 * Caches what it made, or that it failed, once it's out of the queue.
 */
/datum/dirt_job/proc/finished()
	return

/**
 * Makes the masks mess is drawn with, a piece at a time, in the tick time other subsystems leave over, and keeps the
 * newest of them.
 *
 * Masks asked for that aren't made yet are queued here (masks_for()), behind the template of the body they're drawn on
 * if that isn't built yet (template_for()), and behind the plain human template, queued at init, which every mark is
 * sized by (dirt_metric()) and underclothes are judged on. Each fire works through the queue in order until the tick
 * runs short. Finished masks go in `masks`, and each body that drew without them meanwhile, if it's still around, is
 * drawn again at the end of the fire (redraw_dirt()). Masks asked for again while they wait are the same job, which
 * only notes another body to draw again. A job that fails is cached as failed, and isn't queued again while that's
 * kept.
 *
 * DIRT_MASKS_DEFERRED turns the queue on: without it every mask is made as it's asked for.
 */
SUBSYSTEM_DEF(dirt)
	name = "Dirt"
	// Every tick at 20 FPS.
	wait = 0.5
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	can_fire = FALSE
	/// Jobs waiting, oldest first. The first may be part made.
	var/list/queue = list()
	/// Bodies to draw again for finished masks, by weak reference -> DIRT_REDRAW_* flags.
	var/list/redraws = list()
	/// Masks by request key: /datum/dirt_masks, or FALSE when they can't be made. The newest DIRT_MASK_CACHE_SIZE are
	/// kept. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_masks/masks = new
	/// Mask jobs waiting, by request key: kept apart from `masks`, so newer asks can't drop one while it waits. Admins
	/// can't edit it (vv_edit_var()).
	var/alist/mask_jobs = alist()
	/// Built templates by key, or FALSE when one can't be. About 220 KB each, so only the DIRT_TEMPLATE_CACHE_SIZE asked
	/// for most lately are kept; one dropped is built again when masks on it are next asked for. A job holds its own
	/// template, so one dropped while the job waits is still drawn on, and taken back from the job when asked for
	/// meanwhile (held_template()). Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/templates/templates = new
	/// Template jobs waiting, by template key. Admins can't edit it (vv_edit_var()).
	var/alist/template_jobs = alist()
	/// Each splat's rasters on a template and surface, by "template key|surface kind|zone:level:variant": one text of
	/// its /datum/dirt_pixels/proc/drawn() in each direction (fetch_direction()). Masks asked for again with one more
	/// splat rasterise only that one. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_rasters/rasters = new
	/// Whole sprite directions read (dirt_sprite_pixels()), the DIRT_SPRITE_READS read most lately. Admins can't edit it
	/// (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/sprite_reads/sprite_reads = new
	/// The directions sprites have pixels in (dirt_sprite_facings()), the newest DIRT_SPRITE_FACINGS. Admins can't edit it
	/// (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_facings/sprite_facings = new
	/// What dirt_metric() returns, once measured. Admins can't edit it (vv_edit_var()).
	var/alist/metrics
	/// The job building human_template and measuring `metrics`, while it waits.
	var/datum/dirt_template_job/metric/metric_job
	/// The plain human template, kept for the round once built: underclothes coverage is judged on it
	/// (dirt_underclothes_on()). Admins can't edit it (vv_edit_var()).
	var/datum/dirt_template/human_template
	/// The last serial next_serial() gave.
	var/serial = 0
	/// The longest a fire has taken this round, in ms: one piece can't be split.
	var/max_fire_cost = 0

/// Drops the jobs still waiting, so nothing waits on them forever.
/datum/controller/subsystem/dirt/Shutdown()
	mask_jobs.Cut()
	queue.Cut()
	redraws.Cut()
	template_jobs.Cut()
	metric_job = null

/// Takes over the queue, the bodies waiting to be drawn again and the caches from the subsystem it replaces, and fires
/// while any wait.
/datum/controller/subsystem/dirt/Recover()
	queue = SSdirt.queue
	redraws = SSdirt.redraws
	can_fire = length(queue) || length(redraws)
	masks = SSdirt.masks
	mask_jobs = SSdirt.mask_jobs
	templates = SSdirt.templates
	template_jobs = SSdirt.template_jobs
	rasters = SSdirt.rasters
	sprite_reads = SSdirt.sprite_reads
	sprite_facings = SSdirt.sprite_facings
	metrics = SSdirt.metrics
	metric_job = SSdirt.metric_job
	human_template = SSdirt.human_template
	serial = SSdirt.serial
	max_fire_cost = SSdirt.max_fire_cost

/**
 * Refuses admin edits of the caches and the jobs waiting: a mask, template or measure edited by hand would be drawn for
 * the rest of the round, and a list of jobs replaced would break masks_for() for the round.
 *
 * Arguments:
 * - var_name: The var.
 * - var_value: Its new value.
 *
 * Returns:
 * - TRUE/FALSE: Whether the var was edited.
 */
/datum/controller/subsystem/dirt/vv_edit_var(var_name, var_value)
	if(var_name == NAMEOF(src, masks) || var_name == NAMEOF(src, mask_jobs) || var_name == NAMEOF(src, templates) || var_name == NAMEOF(src, template_jobs) || var_name == NAMEOF(src, rasters) || var_name == NAMEOF(src, sprite_reads) || var_name == NAMEOF(src, sprite_facings) || var_name == NAMEOF(src, metrics) || var_name == NAMEOF(src, human_template))
		return FALSE
	return ..()

/// Builds the plain human template in the background from the start, so the first landing never waits for it.
/datum/controller/subsystem/dirt/Initialize()
	if(!human_template && !metric_job)
		queue_human_template()
	return SS_INIT_SUCCESS

/**
 * Queues the plain human template, which `metrics` is measured from and human_template keeps, in the directions read:
 * south and east for the measure (dirt_metric_directions()), north and south for underclothes (dirt_zone_facing()).
 */
/datum/controller/subsystem/dirt/proc/queue_human_template()
	metric_job = new(dirt_metric_sources(), list(SOUTH, NORTH, EAST))
	add(metric_job)

/**
 * Returns one direction of the plain human template, or null until that direction is built.
 *
 * Arguments:
 * - direction: The direction.
 */
/datum/controller/subsystem/dirt/proc/human_surface(direction)
	RETURN_TYPE(/datum/dirt_surface)
	var/datum/dirt_template/human = human_template || metric_job?.template
	return human?.surfaces[direction]

/**
 * Draws again the bodies left waiting by the last fire, then makes queued jobs in order while the tick has room, then
 * draws again the bodies waiting for those. Each loop goes round at most once for each entry its list had when it
 * began, so none can go round forever; what is added meanwhile waits for a later fire. Stops firing while there's
 * nothing to do (add()).
 */
/datum/controller/subsystem/dirt/fire(resumed)
	var/started = TICK_USAGE
	if(redraw_waiting())
		note_cost(started)
		return
	for(var/turn in 1 to length(queue))
		var/datum/dirt_job/job = queue[1]
		if(!work_on(job, TRUE))
			note_cost(started)
			return
		queue.Cut(1, 2)
		job.finished()
		if(MC_TICK_CHECK)
			note_cost(started)
			return
	if(redraw_waiting())
		note_cost(started)
		return
	if(!length(queue) && !length(redraws))
		can_fire = FALSE
	note_cost(started)

/// Shows how many jobs wait, how many bodies wait to be drawn again, and the longest fire this round.
/datum/controller/subsystem/dirt/stat_entry(msg)
	msg = "Q:[length(queue)]|R:[length(redraws)]|M:[round(max_fire_cost, 0.01)]ms"
	return ..()

/**
 * Notes what a fire took, for max_fire_cost.
 *
 * Arguments:
 * - started: TICK_USAGE when it began.
 */
/datum/controller/subsystem/dirt/proc/note_cost(started)
	max_fire_cost = max(max_fire_cost, TICK_DELTA_TO_MS(TICK_USAGE - started))

/**
 * Queues a job.
 *
 * Arguments:
 * - job: The job.
 */
/datum/controller/subsystem/dirt/proc/add(datum/dirt_job/job)
	queue += job
	can_fire = TRUE

/**
 * Returns the next splat serial: the order splats landed in, across every body and item.
 */
/datum/controller/subsystem/dirt/proc/next_serial()
	return ++serial

/**
 * Draws again on a body at the next fire, once whatever changed it this tick is done: several changes draw it once.
 *
 * Arguments:
 * - body: The body.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/datum/controller/subsystem/dirt/proc/redraw_later(mob/living/carbon/human/body, redraw_flags)
	var/datum/weakref/body_ref = WEAKREF(body)
	if(!body_ref || !redraw_flags)
		return
	redraws[body_ref] |= redraw_flags
	can_fire = TRUE

/**
 * Returns a request's masks, or null while they're made or when they can't be. Masks not made yet are queued, behind
 * their template and the measure if those aren't made either, and `redraw_body` is drawn again once they are; without
 * DIRT_MASKS_DEFERRED they're made now.
 *
 * Arguments:
 * - request: What the masks are made from.
 * - redraw_body: The body drawing them, drawn again once they're made.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again on it.
 */
/datum/controller/subsystem/dirt/proc/masks_for(datum/dirt_mask_request/request, mob/living/carbon/human/redraw_body, redraw_flags)
	RETURN_TYPE(/datum/dirt_masks)
	var/key = request.mask_key()
	var/datum/dirt_mask_job/waiting = mask_jobs[key]
	if(waiting)
		waiting.wait(redraw_body, redraw_flags)
		return null
	var/cached = masks.fetch(key)
	if(!isnull(cached))
		return cached || null
	var/datum/dirt_mask_job/job = new(request, key)
#ifdef DIRT_MASKS_DEFERRED
	if(!metrics && !metric_job)
		queue_human_template()
	if(request.zone_sources)
		job.template_source = template_for(request.zone_sources)
	// noted only once it's queued: a runtime before would leave a job nothing makes holding the key
	mask_jobs[key] = job
	add(job)
	job.wait(redraw_body, redraw_flags)
	return null
#else
	if(request.zone_sources)
		job.template_source = template_for(request.zone_sources)
	mask_jobs[key] = job
	run_now(job)
	return masks.fetch(key) || null
#endif

/**
 * Returns the template built from a body's sprites, queueing it if it isn't built or queued yet; without
 * DIRT_MASKS_DEFERRED it's built now. One the cache dropped that a queued job still holds goes back in the cache rather
 * than being built a second time.
 *
 * Arguments:
 * - zone_sources: The body's sprites, as dirt_zone_sources() returns them.
 *
 * Returns:
 * - /datum/dirt_template: The template.
 * - /datum/dirt_template_job: The job building it, queued.
 * - FALSE: It can't be built.
 */
/datum/controller/subsystem/dirt/proc/template_for(list/zone_sources)
	var/key = dirt_template_key(zone_sources)
	var/datum/dirt_template_job/waiting = template_jobs[key]
	if(waiting)
		return waiting
	var/cached = templates.fetch(key)
	if(!isnull(cached))
		return cached
	var/datum/dirt_template/held = held_template(key)
	if(held)
		return templates.store_value(key, held)
	var/datum/dirt_template_job/job = new(zone_sources)
#ifdef DIRT_MASKS_DEFERRED
	template_jobs[key] = job
	add(job)
	return job
#else
	run_now(job)
	return job.built() || FALSE
#endif

/**
 * Returns a built template a queued mask job holds, or null.
 *
 * Arguments:
 * - key: The template's key.
 */
/datum/controller/subsystem/dirt/proc/held_template(key)
	RETURN_TYPE(/datum/dirt_template)
	for(var/datum/dirt_mask_job/mask_job in queue)
		var/datum/dirt_template/held = mask_job.held_template()
		if(held?.key == key)
			return held
	return null

/**
 * Makes pieces of a job until it's done or, when `yielding`, until the tick runs short. A job that runs past its
 * most_pieces(), counted across every fire, is dropped as failed.
 *
 * Arguments:
 * - job: The job.
 * - yielding: Whether to stop when the tick runs short, as a fire does.
 *
 * Returns whether the job is done.
 */
/datum/controller/subsystem/dirt/proc/work_on(datum/dirt_job/job, yielding)
	var/most = job.most_pieces()
	for(var/piece in job.pieces_made + 1 to most)
		job.pieces_made = piece
		if(make_piece(job))
			return TRUE
		if(yielding && MC_TICK_CHECK)
			return FALSE
	job.failed = TRUE
	stack_trace("A dirt job ran past its [most] pieces and was dropped: [job.type]")
	return TRUE

/**
 * Makes the next piece of a job. A piece that runtimes fails its job, so it can't hold up the jobs queued after it.
 *
 * Arguments:
 * - job: The job.
 *
 * Returns whether the job is done.
 */
/datum/controller/subsystem/dirt/proc/make_piece(datum/dirt_job/job)
	try
		return job.next_piece()
	catch(var/exception/error)
		job.failed = TRUE
		stack_trace("A dirt job failed and its masks are left undrawn: [error] at [error.file]:[error.line]")
		return TRUE

/**
 * Makes a job now, start to end, as finish_all() does.
 *
 * Arguments:
 * - job: The job.
 */
/datum/controller/subsystem/dirt/proc/run_now(datum/dirt_job/job)
	work_on(job, FALSE)
	job.finished()

/**
 * Draws again the bodies waiting for finished masks, longest waiting first, until the tick runs short.
 *
 * Returns TRUE if the tick ran short.
 */
/datum/controller/subsystem/dirt/proc/redraw_waiting()
	for(var/turn in 1 to length(redraws))
		redraw_next()
		if(MC_TICK_CHECK)
			return TRUE
	return FALSE

/**
 * Draws again the body that has waited longest for its masks, if it's still around.
 */
/datum/controller/subsystem/dirt/proc/redraw_next()
	var/datum/weakref/body_ref = redraws[1]
	var/redraw_flags = redraws[body_ref]
	redraws.Cut(1, 2)
	var/mob/living/carbon/human/body = body_ref.resolve()
	body?.redraw_dirt(redraw_flags)

/**
 * Makes every queued job now and draws the bodies waiting for them again, as masks made as they're asked for would
 * have: for tests, and anything else that has to see mess drawn at once. In a round the queue's own pace keeps ticks
 * short instead.
 */
/datum/controller/subsystem/dirt/proc/finish_all()
	for(var/finish_round in 1 to DIRT_MAX_FINISH_ROUNDS)
		if(!length(queue) && !length(redraws))
			break
		for(var/turn in 1 to length(queue))
			run_now(queue[1])
			queue.Cut(1, 2)
		for(var/turn in 1 to length(redraws))
			redraw_next()
	can_fire = length(queue) || length(redraws)

/// Caches the template, or FALSE when it failed.
/datum/dirt_template_job/finished()
	SSdirt.template_jobs -= template.key
	SSdirt.templates.store_value(template.key, built() || FALSE)

/**
 * The plain human template dirt_metric() is measured from and underclothes coverage is judged on, built facing south,
 * north and east and kept as SSdirt.human_template.
 */
/datum/dirt_template_job/metric

/// Measures dirt_metric(), unless it failed or something measured it meanwhile, and keeps the template.
/datum/dirt_template_job/metric/finished()
	if(SSdirt.metric_job == src)
		SSdirt.metric_job = null
	var/datum/dirt_template/human = built()
	if(human)
		SSdirt.metrics ||= dirt_measure_metrics(human)
		SSdirt.human_template = human

/// Caches the masks, or FALSE when they failed, and notes the bodies that waited for them to be drawn again.
/datum/dirt_mask_job/finished()
	SSdirt.mask_jobs -= key
	SSdirt.masks.put(key, (failed || !masks) ? FALSE : masks)
	for(var/datum/weakref/body_ref, redraw_flags in waiters)
		SSdirt.redraws[body_ref] |= redraw_flags

/// Keeps the entries asked for most lately: one asked for again goes to the back of the line, so what's most in play
/// stays.
/datum/bulge_bounded_cache/dirt_recent

/datum/bulge_bounded_cache/dirt_recent/fetch(key)
	. = ..()
	if(isnull(.))
		return
	// oldest first from the start of the list, where the cursor is once it's full
	if(cursor > 1)
		keys = keys.Copy(cursor) + keys.Copy(1, cursor)
		cursor = 1
	keys -= key
	keys += key

/// Keeps the DIRT_TEMPLATE_CACHE_SIZE templates asked for most lately, so the bodies most in play keep theirs.
/datum/bulge_bounded_cache/dirt_recent/templates
	limit = DIRT_TEMPLATE_CACHE_SIZE

/// Keeps the DIRT_SPRITE_READS sprite directions read most lately: the sprites of the bodies and clothes most in play.
/datum/bulge_bounded_cache/dirt_recent/sprite_reads
	limit = DIRT_SPRITE_READS

/// Keeps the newest DIRT_SPRITE_FACINGS sprites' facings.
/datum/bulge_bounded_cache/dirt_facings
	limit = DIRT_SPRITE_FACINGS

/// Keeps the newest DIRT_MASK_CACHE_SIZE masks.
/datum/bulge_bounded_cache/dirt_masks
	limit = DIRT_MASK_CACHE_SIZE

/**
 * Puts a value under a key: in its place if the key is kept, else as the newest.
 *
 * Arguments:
 * - key: The key.
 * - value: The masks, or FALSE.
 */
/datum/bulge_bounded_cache/dirt_masks/proc/put(key, value)
	if(isnull(LAZYACCESS(entries, key)))
		return store_value(key, value)
	entries[key] = value
	return value

/**
 * Drops a key and what it holds, so it's made afresh when next asked for. The keys left keep their order.
 *
 * Arguments:
 * - key: The key.
 */
/datum/bulge_bounded_cache/dirt_masks/proc/forget(key)
	if(isnull(LAZYACCESS(entries, key)))
		return
	entries -= key
	// oldest first from the start of the list, so the next key stored goes after the newest
	if(cursor > 1)
		keys = keys.Copy(cursor) + keys.Copy(1, cursor)
		cursor = 1
	keys -= key

/// Keeps the newest DIRT_RASTER_CACHE_SIZE splats' rasters, each one text: its drawn() in each direction, in
/// dirt_mask_directions() order, joined by DIRT_RASTER_SEPARATOR, empty where it isn't rasterised yet.
/datum/bulge_bounded_cache/dirt_rasters
	limit = DIRT_RASTER_CACHE_SIZE

/**
 * Returns a splat's raster in one direction, /datum/dirt_pixels/proc/drawn() of it, or null if it isn't kept there.
 *
 * Arguments:
 * - key: The raster key.
 * - direction: The direction.
 */
/datum/bulge_bounded_cache/dirt_rasters/proc/fetch_direction(key, direction)
	var/packed = LAZYACCESS(entries, key)
	if(!packed)
		return null
	var/list/directions = dirt_mask_directions()
	var/start = 1
	for(var/position in 1 to directions.Find(direction) - 1)
		start = findtextEx(packed, DIRT_RASTER_SEPARATOR, start) + 1
	var/drawn = copytext(packed, start, findtextEx(packed, DIRT_RASTER_SEPARATOR, start))
	return length(drawn) ? drawn : null

/**
 * Keeps a splat's raster in one direction beside the ones kept under its key. A key kept already keeps its place.
 *
 * Arguments:
 * - key: The raster key.
 * - direction: The direction.
 * - drawn: /datum/dirt_pixels/proc/drawn() of the raster.
 *
 * Returns `drawn`.
 */
/datum/bulge_bounded_cache/dirt_rasters/proc/store_direction(key, direction, drawn)
	var/list/drawn_by_direction = list()
	for(var/kept_direction in dirt_mask_directions())
		drawn_by_direction += kept_direction == direction ? drawn : (fetch_direction(key, kept_direction) || "")
	var/packed = jointext(drawn_by_direction, DIRT_RASTER_SEPARATOR)
	if(isnull(LAZYACCESS(entries, key)))
		store_value(key, packed)
	else
		entries[key] = packed
	return drawn

/**
 * Draws again what masks finished for this body would change.
 *
 * Arguments:
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/mob/living/carbon/human/proc/redraw_dirt(redraw_flags)
	if(redraw_flags & (DIRT_REDRAW_COVER|DIRT_REDRAW_PARTS))
		var/datum/component/dirtiness/carrier = GetComponent(/datum/component/dirtiness)
		if(redraw_flags & DIRT_REDRAW_COVER)
			carrier?.check_cover()
		// what's worn may show or hide a part, or draw it under or over something else
		carrier?.check_parts()
	if(redraw_flags & DIRT_REDRAW_SHARE)
		update_body()
	else if(redraw_flags & DIRT_REDRAW_BODY)
		update_body_parts()
	if(redraw_flags & DIRT_REDRAW_UNIFORM)
		update_worn_undersuit()
	if(redraw_flags & DIRT_REDRAW_SUIT)
		update_worn_oversuit()
	if(redraw_flags & DIRT_REDRAW_HEAD)
		update_worn_head()
	if(redraw_flags & DIRT_REDRAW_MASK)
		update_worn_mask()

#undef DIRT_MAX_FINISH_ROUNDS
#undef DIRT_TEMPLATE_CACHE_SIZE
#undef DIRT_MASK_CACHE_SIZE
#undef DIRT_RASTER_CACHE_SIZE
#undef DIRT_SPRITE_READS
#undef DIRT_SPRITE_FACINGS
#undef DIRT_RASTER_SEPARATOR
