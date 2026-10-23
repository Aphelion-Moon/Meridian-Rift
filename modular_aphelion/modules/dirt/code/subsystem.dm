/// The most rounds finish_all() goes: the bodies a round draws again can ask for masks, which the next round makes.
#define DIRT_MAX_FINISH_ROUNDS 10
/// How many templates SSdirt keeps built: about 4 MB at most. One built again costs about 65 ms, spread over four fires.
#define DIRT_TEMPLATE_CACHE_SIZE 16
/// How many splats' rasters SSdirt keeps: under 3 KB each, so under 0.4 MB, and two bodies' worth at the splat cap.
#define DIRT_RASTER_CACHE_SIZE 128

/**
 * Work SSdirt does a piece at a time (next_piece()), each piece in its own try/catch (make_piece()), so a piece that
 * runtimes drops its job, cached as failed, and can't hold up the jobs after it.
 */
/datum/dirt_job
	/// Whether it can't make what it's for: a piece runtimed, or what it reads is missing.
	var/failed = FALSE

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
 * Returns the most pieces it can take. One that takes more is dropped as failed.
 */
/datum/dirt_job/proc/most_pieces()
	return 1

/**
 * Caches what it made, or that it failed, once it's out of the queue.
 */
/datum/dirt_job/proc/finished()
	return

/**
 * Makes the masks semen is drawn with, a piece at a time, in the tick time other subsystems leave over, and keeps them
 * for the round.
 *
 * Masks asked for that aren't made yet are queued here (masks_for()), behind the template of the body they're drawn on
 * if that isn't built yet (template_for()), and behind the measure every mark is sized by (dirt_metric()) on the first
 * ask. Each fire works through the queue in order until the tick runs short. Finished masks go in `masks`, and each body
 * that drew without them meanwhile, if it's still around, is drawn again at the end of the fire (redraw_dirt()). Masks
 * asked for again while they wait are the same job, which only notes another body to draw again. A job that fails is
 * cached as failed and never queued again.
 *
 * DIRT_MASKS_DEFERRED turns the queue off: every mask is then made as it's asked for.
 */
SUBSYSTEM_DEF(dirt)
	name = "Dirt"
	// Every tick at 20 FPS.
	wait = 0.5
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_NO_INIT | SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	can_fire = FALSE
	/// Jobs waiting, oldest first. The first may be part made.
	var/list/queue = list()
	/// Bodies to draw again for finished masks, by weak reference -> DIRT_REDRAW_* flags.
	var/list/redraws = list()
	/// Masks by request key: /datum/dirt_masks, the job making them while it waits, or FALSE when they can't be made. Kept
	/// for the round: the icons are resources, and a key is a look in play. Admins can't edit it (vv_edit_var()).
	var/alist/masks = alist()
	/// Built templates by key, or FALSE when one can't be. About 240 KB each, so only the newest DIRT_TEMPLATE_CACHE_SIZE
	/// are kept; one dropped is built again when masks on it are next asked for. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_templates/templates = new
	/// Template jobs waiting, by template key.
	var/alist/template_jobs = alist()
	/// Each splat's rasters on a template and surface, by "template key|surface kind|zone:level:variant": alist(direction =
	/// /datum/dirt_pixels/proc/drawn()). Masks asked for again with one more splat rasterise only that one. Admins can't
	/// edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_rasters/rasters = new
	/// What dirt_metric() returns, once measured. Admins can't edit it (vv_edit_var()).
	var/alist/metrics
	/// The job measuring `metrics`, while it waits.
	var/datum/dirt_template_job/metric/metric_job
	/// The last serial next_serial() gave.
	var/serial = 0
	/// The longest a fire has taken this round, in ms: one piece can't be split.
	var/max_fire_cost = 0

/// Drops the jobs still waiting, so nothing waits on them forever.
/datum/controller/subsystem/dirt/Shutdown()
	for(var/datum/dirt_job/job as anything in queue)
		var/datum/dirt_mask_job/mask_job = job
		if(istype(mask_job))
			masks -= mask_job.key
	queue.Cut()
	redraws.Cut()
	template_jobs.Cut()
	metric_job = null

/// Takes over the queue, the bodies waiting to be drawn again and the caches from the subsystem it replaces.
/datum/controller/subsystem/dirt/Recover()
	queue = SSdirt.queue
	redraws = SSdirt.redraws
	masks = SSdirt.masks
	templates = SSdirt.templates
	template_jobs = SSdirt.template_jobs
	rasters = SSdirt.rasters
	metrics = SSdirt.metrics
	metric_job = SSdirt.metric_job
	serial = SSdirt.serial
	max_fire_cost = SSdirt.max_fire_cost

/**
 * Refuses admin edits of the caches: a mask, template or measure edited by hand would be drawn for the rest of the round.
 *
 * Arguments:
 * - var_name: The var.
 * - var_value: Its new value.
 *
 * Returns:
 * - TRUE/FALSE: Whether the var was edited.
 */
/datum/controller/subsystem/dirt/vv_edit_var(var_name, var_value)
	if(var_name == NAMEOF(src, masks) || var_name == NAMEOF(src, templates) || var_name == NAMEOF(src, rasters) || var_name == NAMEOF(src, metrics))
		return FALSE
	return ..()

/**
 * Draws again the bodies left waiting by the last fire, then makes queued jobs in order while the tick has room, then
 * draws again the bodies waiting for those. Each loop goes round at most once for each entry its list had when it began,
 * so none can go round forever; what is added meanwhile waits for a later fire. Stops firing while there's nothing to do
 * (add()).
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
	var/cached = masks[key]
	if(istype(cached, /datum/dirt_mask_job))
		var/datum/dirt_mask_job/waiting = cached
		waiting.wait(redraw_body, redraw_flags)
		return null
	if(!isnull(cached))
		return cached || null
	var/datum/dirt_mask_job/job = new(request, key)
	masks[key] = job
#ifdef DIRT_MASKS_DEFERRED
	if(!metrics && !metric_job)
		metric_job = new(dirt_metric_sources(), dirt_metric_directions())
		add(metric_job)
	job.template_source = template_for(request.zone_sources)
	add(job)
	job.wait(redraw_body, redraw_flags)
	return null
#else
	job.template_source = template_for(request.zone_sources)
	run_now(job)
	return masks[key] || null
#endif

/**
 * Returns the template built from a body's sprites, queueing it if it isn't built or queued yet; without
 * DIRT_MASKS_DEFERRED it's built now.
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
 * Makes pieces of a job until it's done or, when `yielding`, until the tick runs short. A job that runs past its
 * most_pieces() is dropped as failed.
 *
 * Arguments:
 * - job: The job.
 * - yielding: Whether to stop when the tick runs short, as a fire does.
 *
 * Returns whether the job is done.
 */
/datum/controller/subsystem/dirt/proc/work_on(datum/dirt_job/job, yielding)
	var/most = job.most_pieces()
	for(var/piece in 1 to most)
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
 * have: for tests, and anything else that has to see semen drawn at once. In a round the queue's own pace keeps ticks
 * short instead.
 */
/datum/controller/subsystem/dirt/proc/finish_all()
	for(var/finish_round in 1 to DIRT_MAX_FINISH_ROUNDS)
		if(!length(queue) && !length(redraws))
			break
		for(var/turn in 1 to length(queue))
			var/datum/dirt_job/job = queue[1]
			work_on(job, FALSE)
			queue.Cut(1, 2)
			job.finished()
		for(var/turn in 1 to length(redraws))
			redraw_next()
	can_fire = length(queue) || length(redraws)

/// Caches the template, or FALSE when it failed.
/datum/dirt_template_job/finished()
	SSdirt.template_jobs -= template.key
	SSdirt.templates.store_value(template.key, built() || FALSE)

/**
 * The plain human template dirt_metric() is measured from, built facing only the directions it's read in, and dropped
 * once it's measured.
 */
/datum/dirt_template_job/metric

/// Measures dirt_metric(), unless it failed or something measured it meanwhile.
/datum/dirt_template_job/metric/finished()
	if(SSdirt.metric_job == src)
		SSdirt.metric_job = null
	var/datum/dirt_template/human = built()
	if(human)
		SSdirt.metrics ||= dirt_measure_metrics(human)

/// Caches the masks, or FALSE when they failed, and notes the bodies that waited for them to be drawn again.
/datum/dirt_mask_job/finished()
	SSdirt.masks[key] = (failed || !masks) ? FALSE : masks
	for(var/datum/weakref/body_ref, redraw_flags in waiters)
		SSdirt.redraws[body_ref] |= redraw_flags

/// Keeps the newest DIRT_TEMPLATE_CACHE_SIZE templates.
/datum/bulge_bounded_cache/dirt_templates
	limit = DIRT_TEMPLATE_CACHE_SIZE

/// Keeps the newest DIRT_RASTER_CACHE_SIZE splats' rasters.
/datum/bulge_bounded_cache/dirt_rasters
	limit = DIRT_RASTER_CACHE_SIZE

/**
 * Draws again what masks finished for this body would change.
 *
 * Arguments:
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/mob/living/carbon/human/proc/redraw_dirt(redraw_flags)
	if(redraw_flags & DIRT_REDRAW_BODY)
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
#undef DIRT_RASTER_CACHE_SIZE
