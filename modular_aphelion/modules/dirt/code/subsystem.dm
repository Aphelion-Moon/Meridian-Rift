/// The most rounds finish_all() goes: the bodies a round draws again can ask for masks, which the next round makes.
#define DIRT_MAX_FINISH_ROUNDS 10
/// How many templates SSdirt keeps built, besides SSdirt.human_template: about 220 KB each, so about 3.5 MB, and one
/// a queued job holds lives until that job is done. One built again costs about 30 ms, spread over four fires.
#define DIRT_TEMPLATE_CACHE_SIZE 16
/// How many masks SSdirt keeps: 0.1-2.1 KB each with its place here, icons aside (measured, the most for a skin's set
/// with its parts), so 0.1-0.5 MB. Masks dropped and made again reuse their cached rasters and icons' resource cache
/// entries.
#define DIRT_MASK_CACHE_SIZE 256
/// How many splats' rasters SSdirt keeps. Each is one text under its key, with four characters for each run of pixels
/// in one role and thickness (/datum/dirt_pixels/proc/drawn()). A run averages about 2.1 pixels. So the text is about
/// 37% shorter than at three characters a pixel, where it measures 1.3-2.0 KB with scratch. That makes about
/// 0.85-1.4 KB each, scratch included, so under 2.9 MB in all. At about 200 players the live keys (about 6400)
/// outnumber it. So an idle player's old splats are rasterised again when that body's masks are made again.
#define DIRT_RASTER_CACHE_SIZE 2048
/// How many whole sprite directions dirt_sprite_pixels() keeps, the ones read most lately: about 1.1 KB each, so under
/// 300 KB. Only SSdirt's pieces read them: a template up to 40, a body's masks a few dozen.
#define DIRT_SPRITE_READS 256
/// How many sprites' facings dirt_sprite_facings() keeps, about 180 bytes each, so under 400 KB. The genital sheets
/// hold about 1200 states that parts are read from. SSdirt.sprite_one_way keeps as many sprites.
#define DIRT_SPRITE_FACINGS 2048
/// What a cached raster's directions are joined by: drawn() writes only "0" to "o" (ASCII 48 to 111).
#define DIRT_RASTER_SEPARATOR ","
/// How many seed texts' draft-stream words SSdirt keeps (/datum/dirt_draft_words). A general deposit's stream draws up
/// to about 250 words, three packed in four numbers. That's about 3 KB a text at most and 0.8 KB at the median (67
/// words), so 0.2-0.77 MB. The open text's twister state adds 10 KB. Seeding a text again costs about 1,250 32-bit
/// products (2.8 ms). The general causes use 223 seed texts between them (measured), so at 256 each text is seeded only
/// once.
#define DIRT_DRAFT_TEXTS 256
/// How many sweat multipliers SSdirt keeps (/datum/dirt_mask_request/wet), the ones asked for most lately. Each is one
/// baked icon under its key, one for each garment look and the masks sweat lies on. It's the smallest power of two that
/// holds 80 looks asked for again in turn, so none is made again. A multiplier's set takes 281-434 B and its icon
/// 142-250 B (measured), so about 55-90 KB.
#define DIRT_WET_CACHE_SIZE 128
/// How many wags' sprites SSdirt keeps (/datum/dirt_mask_job/var/sprite_frames), the ones baked most lately. Each holds
/// every frame's pixels and where each pixel takes the still tail's dirt from. A tile tail's take 2.7-14 KB and a taur
/// tail's 34-91 KB (measured), so about 1.5 MB at 16.
#define DIRT_WAG_SPRITE_CACHE_SIZE 16

/**
 * Work SSdirt does a piece at a time (next_piece()), each piece in its own try/catch (make_piece()), so a piece that
 * runtimes drops its job and can't hold up the jobs after it. A mask or template job is then cached as failed.
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

/// Returns whether it bakes an animated wag's frames, which SSdirt queues behind other jobs (add()).
/datum/dirt_job/proc/bakes_frames()
	return FALSE

/**
 * Makes the masks dirt is drawn with, a piece at a time, in the tick time other subsystems leave over. It keeps the
 * newest of them.
 *
 * Masks asked for that aren't made yet are queued here (masks_for()). They wait behind the template of the body
 * they're drawn on if that isn't built yet (template_for()). They also wait behind the plain human template, queued at
 * init. Every mark is sized by it (dirt_metric()), and underclothes are judged on it. Each fire works through the queue
 * from the front until the tick runs short. Jobs keep their order, except that an animated wag's job waits behind
 * every other job queued (add()). Finished masks go in `masks`, and sweat's multipliers in `wet_icons`. If a body drew
 * without them meanwhile and it's still around, it's drawn again at the end of the fire (redraw_dirt()). Masks asked
 * for again while they wait are the same job, which only notes another body to draw again. A job that fails is cached
 * as failed, and isn't queued again while that's kept.
 *
 * The same queue lands the general dirt a source defers (/datum/dirt_job/landing). When one event reaches a crowd,
 * their dirt lands over the ticks that have room.
 *
 * DIRT_MASKS_DEFERRED turns the mask queue on. Without it, every mask is made as it's asked for.
 */
SUBSYSTEM_DEF(dirt)
	name = "Dirt"
	// Every tick at 20 FPS.
	wait = 0.5
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	can_fire = FALSE
	/// Jobs waiting, oldest first, except that an animated wag's job waits behind every other job (add()). The first
	/// may be part made. Admins can't edit it (vv_edit_var()).
	var/list/queue = list()
	/// How many of the jobs waiting are landings (/datum/dirt_job/landing), DIRT_LANDINGS_WAITING at most. Admins can't
	/// edit it (vv_edit_var()).
	var/landings_waiting = 0
	/// Bodies to draw again for finished masks, by weak reference -> DIRT_REDRAW_* flags. Admins can't edit it
	/// (vv_edit_var()).
	var/list/redraws = list()
	/// The weak reference of the body redraw_next() is drawing again, else null. That body's own carrier ignores the
	/// slot changes the redraw makes (/datum/component/dirtiness/proc/on_overlay_changed()), as nothing worn changed.
	/// Admins can't edit it (vv_edit_var()).
	var/datum/weakref/redrawing
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
	/// Each splat's rasters: one text of its /datum/dirt_pixels/proc/drawn() in each direction (fetch_direction()).
	/// Mess on a body is kept by "template key|surface kind|zone:level:variant". A general deposit, a taur body's
	/// pools, a drawn part's or the hair's deposit, and each stain's blood below a taur's waist have key forms of their
	/// own. Their keys are built where they're rasterised. Masks asked for again with one more splat rasterise only
	/// that one. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_rasters/rasters = new
	/// Whole sprite directions read (dirt_sprite_pixels()), the DIRT_SPRITE_READS read most lately. Admins can't edit it
	/// (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/sprite_reads/sprite_reads = new
	/// The directions sprites show pixels in as they're drawn (dirt_sprite_facings()), the newest DIRT_SPRITE_FACINGS.
	/// Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_facings/sprite_facings = new
	/// Whether sprites have one direction, so they're read as their south view facing every way
	/// (dirt_sprite_read_facing()), the newest DIRT_SPRITE_FACINGS. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_facings/sprite_one_way = new
	/// What dirt_metric() returns, once measured. Admins can't edit it (vv_edit_var()).
	var/alist/metrics
	/// The job building human_template and measuring `metrics`, while it waits.
	var/datum/dirt_template_job/metric/metric_job
	/// The plain human template, kept for the round once built, or FALSE if it couldn't be and won't be built again.
	/// Underclothes coverage is judged on it (dirt_underclothes_on()). Admins can't edit it (vv_edit_var()).
	var/datum/dirt_template/human_template
	/// Every material except slime and blood, by id (dirt_material()), all made together at its first call. Admins
	/// can't edit it (vv_edit_var()).
	var/alist/materials
	/// Slime's materials by "slime#RRGGBB", the newest DIRT_SLIME_COLOURS made. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_slimes/slime_materials = new
	/// Blood's materials by "blood#RRGGBB", the newest DIRT_BLOOD_COLOURS made. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_bloods/blood_materials = new
	/// The last serial next_serial() gave.
	var/serial = 0
	/// The longest a fire has taken this round, in ms: one piece can't be split.
	var/max_fire_cost = 0
	/// Each seed text's draft-stream words (/datum/dirt_draft_words), the DIRT_DRAFT_TEXTS used most lately, so a text is
	/// seeded once while it's kept. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/draft_words/draft_words = new
	/// The one entry of draft_words holding its twister's state, so it makes more words without seeding again. Admins
	/// can't edit it (vv_edit_var()).
	var/datum/dirt_draft_words/draft_open
	/// Whether a general deposit is being drawn under DIRT_DRAFT_EXACT (dirt_rasterise()), so its noise samples the
	/// draft's hash. Admins can't edit it (vv_edit_var()).
	var/drafting = FALSE
	/// The points of the draft's noise lattice that the general deposit being drawn has sampled: alist(seed =
	/// alist(point key = value)). It's emptied as each deposit begins and ends (dirt_drafted()), and once it's past
	/// DIRT_LATTICE_POINTS (dirt_draft_noise()). A field's band swaps in the lattice the field kept from its earlier
	/// bands (/datum/dirt_canvas_field/var/lattice). A mask job's direction swaps in the one the job kept from the
	/// deposit's other directions (/datum/dirt_mask_job/var/lattice). Each takes its lattice back as it ends, and
	/// between pieces this holds an empty one. Admins can't edit it (vv_edit_var()).
	var/alist/lattice = alist()
	/// How many points `lattice` holds.
	var/lattice_points = 0
	/// Sweat's multipliers by key (dirt_wet_key()): /datum/dirt_masks holding the icon, or FALSE when one can't be
	/// made. The DIRT_WET_CACHE_SIZE asked for most lately are kept. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/wet_icons/wet_icons = new
	/// What wags' frames show, keyed by their sprites (/datum/dirt_wag_source/proc/sprite_key()), as a wag's job noted
	/// them (/datum/dirt_mask_job/var/sprite_frames). The DIRT_WAG_SPRITE_CACHE_SIZE baked most lately are kept. A wag
	/// baked again, for other dirt or another body, reads no sprite. Admins can't edit it (vv_edit_var()).
	var/datum/bulge_bounded_cache/dirt_recent/wag_sprites/wag_sprites = new

/// Drops the jobs still waiting, so nothing waits on them forever.
/datum/controller/subsystem/dirt/Shutdown()
	mask_jobs.Cut()
	queue.Cut()
	landings_waiting = 0
	redraws.Cut()
	template_jobs.Cut()
	metric_job = null

/// Takes over the queue, the bodies waiting to be drawn again and the caches from the subsystem it replaces, and fires
/// while any wait.
/datum/controller/subsystem/dirt/Recover()
	queue = SSdirt.queue
	landings_waiting = SSdirt.landings_waiting
	redraws = SSdirt.redraws
	can_fire = length(queue) || length(redraws)
	masks = SSdirt.masks
	mask_jobs = SSdirt.mask_jobs
	templates = SSdirt.templates
	template_jobs = SSdirt.template_jobs
	rasters = SSdirt.rasters
	sprite_reads = SSdirt.sprite_reads
	sprite_facings = SSdirt.sprite_facings
	sprite_one_way = SSdirt.sprite_one_way
	metrics = SSdirt.metrics
	metric_job = SSdirt.metric_job
	human_template = SSdirt.human_template
	materials = SSdirt.materials
	slime_materials = SSdirt.slime_materials
	blood_materials = SSdirt.blood_materials
	serial = SSdirt.serial
	max_fire_cost = SSdirt.max_fire_cost
	draft_words = SSdirt.draft_words
	draft_open = SSdirt.draft_open
	wet_icons = SSdirt.wet_icons
	wag_sprites = SSdirt.wag_sprites

/**
 * Refuses admin edits of the caches, the jobs waiting and the bodies waiting or being drawn again. A mask, template,
 * measure, material, draft-stream word, sweat multiplier or wag's sprites edited by hand would be drawn for the rest of
 * the round. A list of jobs replaced would break masks_for() for the round. A queue or list of bodies replaced would
 * lose what waits in it. A body set by hand as the one being drawn again would have its own slot changes ignored.
 *
 * Arguments:
 * - var_name: The var.
 * - var_value: Its new value.
 *
 * Returns:
 * - TRUE/FALSE: Whether the var was edited.
 */
/datum/controller/subsystem/dirt/vv_edit_var(var_name, var_value)
	if(var_name == NAMEOF(src, queue) || var_name == NAMEOF(src, landings_waiting) || var_name == NAMEOF(src, redraws) || var_name == NAMEOF(src, redrawing) || var_name == NAMEOF(src, masks) || var_name == NAMEOF(src, mask_jobs) || var_name == NAMEOF(src, templates) || var_name == NAMEOF(src, template_jobs) || var_name == NAMEOF(src, rasters) || var_name == NAMEOF(src, sprite_reads) || var_name == NAMEOF(src, sprite_facings) || var_name == NAMEOF(src, sprite_one_way) || var_name == NAMEOF(src, metrics) || var_name == NAMEOF(src, human_template) || var_name == NAMEOF(src, materials) || var_name == NAMEOF(src, slime_materials) || var_name == NAMEOF(src, blood_materials) || var_name == NAMEOF(src, draft_words) || var_name == NAMEOF(src, draft_open) || var_name == NAMEOF(src, drafting) || var_name == NAMEOF(src, lattice) || var_name == NAMEOF(src, lattice_points) || var_name == NAMEOF(src, wet_icons) || var_name == NAMEOF(src, wag_sprites))
		return FALSE
	return ..()

/// Builds the plain human template in the background from the start, so the first landing never waits for it.
/datum/controller/subsystem/dirt/Initialize()
	if(isnull(human_template) && !metric_job)
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
 * Returns the plain human template, built now out of its place in the queue if it isn't built yet. It's for what can't
 * wait, because general dirt is judged on it as it lands (dirt_shown_carriers()). It's queued at init, so it's built
 * long before anyone lands dirt. This proc is for a landing in the first moments of the round. Returns null if it
 * can't be built. A build that failed is kept as failed for the round, as a failed job is, so no landing builds it
 * again.
 */
/datum/controller/subsystem/dirt/proc/human_template_now()
	RETURN_TYPE(/datum/dirt_template)
	if(!isnull(human_template))
		return human_template || null
	if(!metric_job)
		queue_human_template()
	queue -= metric_job
	run_now(metric_job)
	return human_template || null

/**
 * Draws again the bodies left waiting by the last fire, then makes queued jobs in order while the tick has room, then
 * draws again the bodies waiting for those. Each loop goes round at most once for each entry its list had when it
 * began, so none can go round forever. The queue's loop ends early if a landing's redraw drops the jobs left. A job
 * queued meanwhile is made in this fire only if a turn is left when it reaches the front. That can happen when jobs
 * ahead of it were dropped, or when it goes ahead of the animated wags waiting (add()). A wag it pushed back can then
 * wait instead. Stops firing while there's nothing to do (add()).
 */
/datum/controller/subsystem/dirt/fire(resumed)
	var/started = TICK_USAGE
	if(redraw_waiting())
		note_cost(started)
		return
	for(var/turn in 1 to length(queue))
		if(!length(queue))
			break
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
 * Queues a job. An animated wag's frames (/datum/dirt_wag_source) go last. Any other job, a one-frame wag's too, goes
 * ahead of the animated wags waiting, each of which takes up to a second or more. It never goes ahead of the first job,
 * which may be part made. Other jobs keep their order.
 *
 * Arguments:
 * - job: The job.
 */
/datum/controller/subsystem/dirt/proc/add(datum/dirt_job/job)
	var/position = length(queue) + 1
	if(!job.bakes_frames())
		for(var/index in length(queue) to 2 step -1)
			var/datum/dirt_job/queued = queue[index]
			if(!queued.bakes_frames())
				break
			position = index
	queue.Insert(position, job)
	can_fire = TRUE

/**
 * Returns the next serial, which orders every splat landing or raise and every blood landing, on any body or item.
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
 * DIRT_MASKS_DEFERRED they're made now. Sweat's multipliers are kept in wet_icons, every other mask in `masks`.
 *
 * Arguments:
 * - request: What the masks are made from.
 * - redraw_body: The body drawing them, drawn again once they're made.
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again on it.
 * - previous: The masks the caller draws while it waits for these, or null. A skin's job made here holds them for
 *   limb_masks() (/datum/dirt_mask_job/var/previous), which no other job runs. A job already waiting keeps its own.
 * - key: The request's mask_key(), from a caller that has it, or null to work it out.
 */
/datum/controller/subsystem/dirt/proc/masks_for(datum/dirt_mask_request/request, mob/living/carbon/human/redraw_body, redraw_flags, datum/dirt_masks/previous = null, key = null)
	RETURN_TYPE(/datum/dirt_masks)
	key ||= request.mask_key()
	var/datum/dirt_mask_job/waiting = mask_jobs[key]
	if(waiting)
		waiting.wait(redraw_body, redraw_flags)
		return null
	var/datum/bulge_bounded_cache/kept = request.kind == DIRT_MASKS_WET ? wet_icons : masks
	var/cached = kept.fetch(key)
	if(!isnull(cached))
		return cached || null
	var/datum/dirt_mask_job/job = new(request, key)
	if(request.kind == DIRT_MASKS_BODY && request.surface_kind == DIRT_SURFACE_SKIN)
		job.previous = previous
#ifdef DIRT_MASKS_DEFERRED
	// a failed human template is FALSE, not null, so it isn't queued again
	if(!metrics && !metric_job && isnull(human_template))
		queue_human_template()
	if(request.zone_sources)
		job.template_source = template_for(request.zone_sources, request.template_key)
	// noted only once it's queued: a runtime before would leave a job nothing makes holding the key
	mask_jobs[key] = job
	add(job)
	job.wait(redraw_body, redraw_flags)
	return null
#else
	if(request.zone_sources)
		job.template_source = template_for(request.zone_sources, request.template_key)
	mask_jobs[key] = job
	run_now(job)
	return kept.fetch(key) || null
#endif

/**
 * Stops a body waiting for the masks queued under a key. Once no other body still around waits for them, it drops their
 * job, part made or not. So masks that nothing would draw aren't made, such as a wag's frames whose splats changed
 * first. It never drops the job through finished(), which would cache the masks as failed for whoever asks next.
 *
 * Arguments:
 * - key: The masks' key.
 * - body: The body that no longer draws them, or is being deleted.
 * - redraw_flags: The DIRT_REDRAW_* flags of the drawing that no longer draws them, or null for all of the body's.
 *   If the body still waits with other flags, for another drawing with the same masks, it keeps the job.
 */
/datum/controller/subsystem/dirt/proc/drop_mask_job(key, mob/living/carbon/human/body, redraw_flags = null)
	var/datum/dirt_mask_job/job = key && mask_jobs[key]
	if(!job)
		return
	var/datum/weakref/dropping_ref = WEAKREF(body)
	if(redraw_flags && dropping_ref && (LAZYACCESS(job.waiters, dropping_ref) & ~redraw_flags))
		job.waiters[dropping_ref] &= ~redraw_flags
		return
	LAZYREMOVE(job.waiters, dropping_ref)
	// a body being deleted resolves to none, as one gone does
	for(var/datum/weakref/body_ref as anything in job.waiters)
		if(body_ref.resolve())
			return
	queue -= job
	mask_jobs -= key

/**
 * Returns the template built from a body's sprites, queueing it if it isn't built or queued yet; without
 * DIRT_MASKS_DEFERRED it's built now. One the cache dropped that a queued job still holds goes back in the cache rather
 * than being built a second time.
 *
 * Arguments:
 * - zone_sources: The body's sprites, as dirt_zone_sources() returns them.
 * - key: Their dirt_template_key(), from a caller that has it, or null to work it out.
 *
 * Returns:
 * - /datum/dirt_template: The template.
 * - /datum/dirt_template_job: The job building it, queued.
 * - FALSE: It can't be built.
 */
/datum/controller/subsystem/dirt/proc/template_for(list/zone_sources, key = null)
	key ||= dirt_template_key(zone_sources)
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
 * Makes the next piece of a job. A piece that runtimes fails its job, so it can't hold up the jobs queued after it. It
 * also stops drafting, in case the runtime came in the middle of drawing a general deposit.
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
		drafting = FALSE
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
	redrawing = body_ref
	// a runtime mustn't leave the body's own slot changes ignored
	try
		body?.redraw_dirt(redraw_flags)
	catch(var/exception/error)
		redrawing = null
		throw error
	redrawing = null

/**
 * Makes every queued job now and draws the bodies waiting for them again, as masks made as they're asked for would
 * have. It's for whatever has to see dirt drawn at once. In a round the queue's own pace keeps ticks short instead.
 *
 * Arguments:
 * - rounds: The most rounds to go, each making what's queued and drawing again what waited for it. If it stops after
 *   one, what that round's draws asked for stays queued, such as a garment's sweat multiplier.
 */
/datum/controller/subsystem/dirt/proc/finish_all(rounds = DIRT_MAX_FINISH_ROUNDS)
	for(var/finish_round in 1 to min(rounds, DIRT_MAX_FINISH_ROUNDS))
		if(!length(queue) && !length(redraws))
			break
		for(var/turn in 1 to length(queue))
			if(!length(queue))
				break
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

/// Measures dirt_metric() unless the build failed or something measured it meanwhile. Keeps the template, or FALSE if
/// it failed.
/datum/dirt_template_job/metric/finished()
	if(SSdirt.metric_job == src)
		SSdirt.metric_job = null
	var/datum/dirt_template/human = built()
	if(human)
		SSdirt.metrics ||= dirt_measure_metrics(human)
		SSdirt.human_template = human
	else if(isnull(SSdirt.human_template))
		SSdirt.human_template = FALSE

/// Caches the masks, or FALSE if they failed, and notes the bodies that waited for them, to be drawn again. Sweat's
/// multipliers go in SSdirt.wet_icons. A wag's sprites, as its frames were read, go whole in SSdirt.wag_sprites.
/datum/dirt_mask_job/finished()
	SSdirt.mask_jobs -= key
	var/datum/bulge_bounded_cache/kept = request.kind == DIRT_MASKS_WET ? SSdirt.wet_icons : SSdirt.masks
	var/made = (failed || !masks) ? FALSE : masks
	// in its place if the key is kept, else as the newest
	if(isnull(LAZYACCESS(kept.entries, key)))
		kept.store_value(key, made)
	else
		kept.entries[key] = made
	if(masks && !failed && sprite_frames && !sprite_frames_kept)
		var/datum/dirt_wag_source/wag = request.shape_source
		SSdirt.wag_sprites.store_value(wag.sprite_key(), sprite_frames)
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

/// Keeps the newest DIRT_SPRITE_FACINGS sprites' facings, or whether each has one direction (sprite_one_way).
/datum/bulge_bounded_cache/dirt_facings
	limit = DIRT_SPRITE_FACINGS

/// Keeps the newest DIRT_MASK_CACHE_SIZE masks.
/datum/bulge_bounded_cache/dirt_masks
	limit = DIRT_MASK_CACHE_SIZE

/// Keeps the DIRT_WET_CACHE_SIZE sweat multipliers asked for most lately, so the garments most in play keep theirs.
/datum/bulge_bounded_cache/dirt_recent/wet_icons
	limit = DIRT_WET_CACHE_SIZE

/// Keeps the DIRT_DRAFT_TEXTS seed texts' draft-stream words used most lately.
/datum/bulge_bounded_cache/dirt_recent/draft_words
	limit = DIRT_DRAFT_TEXTS

/// Keeps the DIRT_WAG_SPRITE_CACHE_SIZE wags' sprites baked most lately, so the tails most in play keep theirs. One
/// dropped is read again at its next bake.
/datum/bulge_bounded_cache/dirt_recent/wag_sprites
	limit = DIRT_WAG_SPRITE_CACHE_SIZE

/// Keeps the newest DIRT_SLIME_COLOURS slime materials. One dropped is made again from its colour when next asked for.
/datum/bulge_bounded_cache/dirt_slimes
	limit = DIRT_SLIME_COLOURS

/// Keeps the newest DIRT_BLOOD_COLOURS blood materials. One dropped is made again from its colour when next asked for.
/datum/bulge_bounded_cache/dirt_bloods
	limit = DIRT_BLOOD_COLOURS

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
 * Draws again what masks finished for this body would change. A taur noted for its garment's stain while it had no
 * carrier of dirt (dirt_note_taur_stain()) gets one here, outside the render, while the blood below its waist draws.
 *
 * Arguments:
 * - redraw_flags: DIRT_REDRAW_* flags, what to draw again.
 */
/mob/living/carbon/human/proc/redraw_dirt(redraw_flags)
	if(redraw_flags & (DIRT_REDRAW_COVER|DIRT_REDRAW_PARTS))
		var/datum/component/dirtiness/carrier = GetComponent(/datum/component/dirtiness)
		if(!carrier && (redraw_flags & DIRT_REDRAW_COVER) && dirt_taur_blood_inputs(src))
			carrier = LoadComponent(/datum/component/dirtiness)
		if(redraw_flags & DIRT_REDRAW_COVER)
			carrier?.check_cover()
		// a carrier made for blood below a taur's waist alone goes with it (check_taur_blood())
		if(QDELETED(carrier))
			carrier = null
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
	if(redraw_flags & DIRT_REDRAW_SHOES)
		update_worn_shoes()
	if(redraw_flags & DIRT_REDRAW_GLOVES)
		update_worn_gloves()
	if(redraw_flags & DIRT_REDRAW_NECK)
		update_worn_neck()
	if(redraw_flags & DIRT_REDRAW_BELT)
		update_worn_belt()
	if(redraw_flags & DIRT_REDRAW_BACK)
		update_worn_back()
	if(redraw_flags & DIRT_REDRAW_GLASSES)
		update_worn_glasses()
	if(redraw_flags & DIRT_REDRAW_EARS)
		update_worn_ears()
	if(redraw_flags & DIRT_REDRAW_SUIT_STORE)
		update_suit_storage()

#undef DIRT_MAX_FINISH_ROUNDS
#undef DIRT_TEMPLATE_CACHE_SIZE
#undef DIRT_MASK_CACHE_SIZE
#undef DIRT_RASTER_CACHE_SIZE
#undef DIRT_SPRITE_READS
#undef DIRT_SPRITE_FACINGS
#undef DIRT_RASTER_SEPARATOR
#undef DIRT_DRAFT_TEXTS
#undef DIRT_WET_CACHE_SIZE
#undef DIRT_WAG_SPRITE_CACHE_SIZE
