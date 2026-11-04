/// The most pieces a garment fit is made in: its setup, a view for each frame of each direction, and its end.
#define GARMENT_FIT_MAX_PIECES (2 + 4 * GARMENT_FIT_MAX_FRAMES)
/// The most rounds finish_all() goes: the bodies a round draws again can find fits to queue, which the next round makes.
#define GARMENT_FIT_MAX_FINISH_ROUNDS 10

/**
 * Makes the garment fits bodies wait for, a piece at a time, in the tick time other subsystems leave over.
 *
 * A garment drawn on a body fitted in a way no garment like it has been yet is drawn as it is, and its fit queued here
 * (/datum/garment_fit_job/proc/start()). Each fire works through the queue in order, one view of one direction's frame at a
 * time, until the tick runs short. A finished fit goes in the cache it was queued for, and each body that drew the garment
 * meanwhile, if it's still around, has that slot drawn again at the end of the fire, once however many of its fits finished.
 * A fit asked for again while it waits is the same fit, which only notes another body to draw again.
 *
 * GARMENT_FITS_DEFERRED turns the queue off, and a dummy never uses it: every fit is then made as its garment is drawn.
 *
 * It reads the fitting's templates and sheet metadata as the server starts, so no fit in a round pays for reading them.
 */
SUBSYSTEM_DEF(garment_fitting)
	name = "Garment Fitting"
	// Every tick at 20 FPS.
	wait = 0.5
	priority = FIRE_PRIORITY_ASSETS
	ss_flags = SS_BACKGROUND
	runlevels = RUNLEVEL_LOBBY | RUNLEVELS_DEFAULT
	can_fire = FALSE
	/// Fits waiting to be made, oldest first. The first may be part made.
	var/list/queue = list()
	/// Bodies to draw again for finished fits, by weak reference -> GARMENT_FIT_REDRAW_* flags.
	var/list/redraws = list()
	/// The longest a fire has taken this round, in ms: one view of a fit can't be split.
	var/max_fire_cost = 0

/datum/controller/subsystem/garment_fitting/Initialize()
	garment_fit_templates()
	garment_pec_templates()
	garment_metadata()
	return SS_INIT_SUCCESS

// Fits still waiting are dropped: each sits in its cache, which it holds, until it's made.
/datum/controller/subsystem/garment_fitting/Shutdown()
	for(var/datum/garment_fit_job/job as anything in queue)
		job.cache[job.cache_key] = null
	queue.Cut()
	redraws.Cut()

/datum/controller/subsystem/garment_fitting/Recover()
	queue = SSgarment_fitting.queue
	redraws = SSgarment_fitting.redraws
	max_fire_cost = SSgarment_fitting.max_fire_cost

/**
 * Draws again the bodies left waiting by the last fire, then makes queued fits in order while the tick has room, then draws
 * again the bodies waiting for those. Each loop goes round at most once for each entry its list had when it began, so none
 * can go round forever; what is added meanwhile waits for a later fire. Stops firing while there's nothing to do (add()).
 */
/datum/controller/subsystem/garment_fitting/fire(resumed)
	var/started = TICK_USAGE
	if(redraw_waiting())
		note_cost(started)
		return
	for(var/turn in 1 to length(queue))
		var/datum/garment_fit_job/job = queue[1]
		for(var/piece in 1 to GARMENT_FIT_MAX_PIECES)
			if(make_piece(job))
				break
			if(MC_TICK_CHECK)
				note_cost(started)
				return
		queue.Cut(1, 2)
		finished(job)
		if(MC_TICK_CHECK)
			note_cost(started)
			return
	if(redraw_waiting())
		note_cost(started)
		return
	if(!length(queue) && !length(redraws))
		can_fire = FALSE
	note_cost(started)

/// Shows how many fits wait, how many bodies wait to be drawn again, and the longest fire this round.
/datum/controller/subsystem/garment_fitting/stat_entry(msg)
	msg = "Q:[length(queue)]|R:[length(redraws)]|M:[round(max_fire_cost, 0.01)]ms"
	return ..()

/// Notes what a fire that began at `started` took, for max_fire_cost.
/datum/controller/subsystem/garment_fitting/proc/note_cost(started)
	max_fire_cost = max(max_fire_cost, TICK_DELTA_TO_MS(TICK_USAGE - started))

/// Queues a fit to be made.
/datum/controller/subsystem/garment_fitting/proc/add(datum/garment_fit_job/job)
	queue += job
	can_fire = TRUE

/**
 * Makes the next piece of a queued fit. A fit that runtimes is done, cached as leaving its garment as it is, so it can't hold up
 * the fits queued after it.
 *
 * Returns whether the fit is done.
 */
/datum/controller/subsystem/garment_fitting/proc/make_piece(datum/garment_fit_job/job)
	try
		return job.next_piece()
	catch(var/exception/error)
		job.cache[job.cache_key] = FALSE
		stack_trace("A garment fit failed and its garment is drawn unfitted: [error] at [error.file]:[error.line]")
		return TRUE

/// Notes the bodies a finished fit's garment is drawn again on.
/datum/controller/subsystem/garment_fitting/proc/finished(datum/garment_fit_job/job)
	for(var/datum/weakref/body_ref, redraw in job.waiters)
		redraws[body_ref] |= redraw

/**
 * Draws again the bodies waiting for finished fits, longest waiting first, until the tick runs short.
 *
 * Returns TRUE if the tick ran short.
 */
/datum/controller/subsystem/garment_fitting/proc/redraw_waiting()
	for(var/turn in 1 to length(redraws))
		redraw_next()
		if(MC_TICK_CHECK)
			return TRUE
	return FALSE

/// Draws the slots of the body that has waited longest for its fits again, if it's still around.
/datum/controller/subsystem/garment_fitting/proc/redraw_next()
	var/datum/weakref/body_ref = redraws[1]
	var/redraw = redraws[body_ref]
	redraws.Cut(1, 2)
	var/mob/living/carbon/human/body = body_ref.resolve()
	body?.redraw_fitted_garments(redraw)

/**
 * Makes every queued fit now and draws the bodies waiting for them again, as a fit made as it's drawn would have: for tests,
 * and anything else that has to see bodies fitted at once. In a round the queue's own pace keeps ticks short instead.
 */
/datum/controller/subsystem/garment_fitting/proc/finish_all()
	for(var/round in 1 to GARMENT_FIT_MAX_FINISH_ROUNDS)
		if(!length(queue) && !length(redraws))
			break
		for(var/turn in 1 to length(queue))
			var/datum/garment_fit_job/job = queue[1]
			for(var/piece in 1 to GARMENT_FIT_MAX_PIECES)
				if(make_piece(job))
					break
			queue.Cut(1, 2)
			finished(job)
		for(var/turn in 1 to length(redraws))
			redraw_next()
	can_fire = length(queue) || length(redraws)

/**
 * Draws again a body's slots whose garments' fits have finished.
 *
 * Arguments:
 * - redraw: GARMENT_FIT_REDRAW_* flags, the slots to draw.
 */
/mob/living/carbon/human/proc/redraw_fitted_garments(redraw)
	if(redraw & GARMENT_FIT_REDRAW_UNDERCLOTHES)
		update_body()
	if(redraw & GARMENT_FIT_REDRAW_UNIFORM)
		update_worn_undersuit()
	if(redraw & GARMENT_FIT_REDRAW_SUIT)
		update_worn_oversuit()
	if(redraw & GARMENT_FIT_REDRAW_SHOES)
		update_worn_shoes()
	if(redraw & GARMENT_FIT_REDRAW_GLOVES)
		update_worn_gloves()

/**
 * One garment fit, made a piece at a time (next_piece()): its setup, each view of each direction's frames
 * (fit_garment_view()), and its end, which caches what it made. While it waits, its place in its cache holds the job itself,
 * so a garment drawn meanwhile finds it and waits for it (wait()) rather than queueing it again.
 */
/datum/garment_fit_job
	/// The cache list the fit goes in, under `cache_key`: the fitted sprite, a resource, or FALSE when the fit leaves the garment
	/// as it is.
	var/alist/cache
	var/cache_key
	/// What the garment is fitted to.
	var/datum/garment_fit/fit
	/// How it's fitted, a GARMENT_FIT_* define. Worn clothing that doesn't set its own reads it from its sleeves in setup().
	var/mode
	/// The sprite being fitted, a 32x32 /icon with four directions, named "", changed in place.
	var/icon/garment
	/// An animated sprite's frame delays.
	var/list/delays
	/// Its views' colours, as fit_garment_view() takes them, by view; or null to read them from its pixels.
	var/list/view_colours
	/// How many views it has, four for each frame, once set up.
	var/views
	/// The next of its views to fit, counted in the order they're fitted (GARMENT_FIT_PIECE_VIEW()).
	var/next_view = 1
	/// Whether a view changed.
	var/changed = FALSE
	/// Weak references to the bodies that drew the garment as it is while this waited -> GARMENT_FIT_REDRAW_* flags.
	var/list/waiters

/datum/garment_fit_job/New(alist/cache, cache_key, datum/garment_fit/fit)
	src.cache = cache
	src.cache_key = cache_key
	src.fit = fit
	cache[cache_key] = src

/**
 * Starts the fit for a garment drawn on `wearer`: queues it, noting `wearer` to draw again once it's made; or, without
 * GARMENT_FITS_DEFERRED or for a dummy, makes it now.
 *
 * Arguments:
 * - wearer: The body the garment is drawn on.
 * - redraw: The GARMENT_FIT_REDRAW_* flag of the slot it's drawn in.
 *
 * Returns what's cached for the garment: the fitted sprite, or FALSE, once made; this job while it waits.
 */
/datum/garment_fit_job/proc/start(mob/living/carbon/human/wearer, redraw)
#ifdef GARMENT_FITS_DEFERRED
	if(!istype(wearer, /mob/living/carbon/human/dummy))
		SSgarment_fitting.add(src)
		wait(wearer, redraw)
		return src
#endif
	run_to_end()
	return cache[cache_key]

/**
 * Notes a body that drew the garment as it is while this waits, to draw that slot again once it's made. A body being deleted
 * isn't drawn again.
 *
 * Arguments:
 * - wearer: The body.
 * - redraw: The GARMENT_FIT_REDRAW_* flag of the slot.
 */
/datum/garment_fit_job/proc/wait(mob/living/carbon/human/wearer, redraw)
	var/datum/weakref/body_ref = WEAKREF(wearer)
	if(!body_ref)
		return
	LAZYINITLIST(waiters)
	waiters[body_ref] |= redraw

/**
 * Makes the next piece of the fit: its setup, one view, or its end, which caches it.
 *
 * Returns whether the fit is done.
 */
/datum/garment_fit_job/proc/next_piece()
	if(isnull(views))
		if(!setup())
			cache[cache_key] = FALSE
			return TRUE
		views = 4 * max(length(delays), 1)
		return FALSE
	if(next_view <= views)
		if(fit_view(GARMENT_FIT_PIECE_VIEW(next_view, views / 4)))
			changed = TRUE
		next_view++
		return FALSE
	cache[cache_key] = changed ? finish() : FALSE
	return TRUE

/**
 * Fits one view of the sprite in place (fit_garment_view()).
 *
 * Arguments:
 * - view: Which view, numbered as fit_garment_view() numbers them.
 *
 * Returns whether the view changed.
 */
/datum/garment_fit_job/proc/fit_view(view)
	return fit_garment_view(garment, view, mode, fit, delays, view_colours?[view], straight_over_pecs(), bares_near_forearm())

/// Whether the garment hangs straight over pecs drawn under it, its chest panel left as drawn (fit_garment_view()).
/datum/garment_fit_job/proc/straight_over_pecs()
	return FALSE

/// Whether the garment leaves the near forearm bare in its side views, shown at the arm's own width (fit_garment_view()).
/datum/garment_fit_job/proc/bares_near_forearm()
	return FALSE

/// Makes the whole fit now.
/datum/garment_fit_job/proc/run_to_end()
	for(var/piece in 1 to GARMENT_FIT_MAX_PIECES)
		if(next_piece())
			return

/**
 * Sets the fit up: the sprite, how it's fitted, its frames and its views' colours.
 *
 * Returns FALSE for a sprite that can't be fitted, which is drawn as it is.
 */
/datum/garment_fit_job/proc/setup()
	return FALSE

/// Returns the fitted sprite to cache, a resource, once a view has changed.
/datum/garment_fit_job/proc/finish()
	return fcopy_rsc(garment)

/**
 * A worn item's sprite or glow fitted (fit_worn_icon(), fit_worn_glows()): the icon build_worn_icon() built, or a state of its
 * worn sheet itself. Only a 32x32 sprite with four directions is fitted; an animated one keeps its frame delays, read from its
 * sheet, and isn't fitted where they can't be read, like a generated icon's.
 */
/datum/garment_fit_job/worn
	/// The worn sheet the sprite is drawn from.
	var/sheet
	/// The state in it.
	var/state
	/// Whether the sprite is that state itself, rather than an icon build_worn_icon() built over it.
	var/sheet_state

/**
 * Arguments:
 * - cache, cache_key, fit: As /datum/garment_fit_job has them.
 * - building_icon: The icon build_worn_icon() built, which is fitted as a copy (the bodyshape icon caches can hand theirs out),
 *   or null to fit the state itself.
 * - sheet, state: The worn sheet and state the sprite is drawn from.
 * - mode: A GARMENT_FIT_* define, or null for the mode its own sleeves pick (garment_sleeve_mode()).
 */
/datum/garment_fit_job/worn/New(alist/cache, cache_key, datum/garment_fit/fit, icon/building_icon, sheet, state, mode)
	. = ..()
	garment = building_icon ? icon(building_icon) : null
	src.sheet = sheet
	src.state = state
	src.mode = mode
	sheet_state = isnull(building_icon)

/datum/garment_fit_job/worn/setup()
	garment ||= icon(sheet, state)
	var/list/states = icon_states(garment)
	if(length(states) != 1 || states[1] != "" || garment.Width() != 32 || garment.Height() != 32 || !length(icon_states(icon(garment, "", EAST))))
		return FALSE
	// The state as its sheet names it: drawn with none, a sheet's one state is its unnamed one.
	var/state_name = state || ""
	// A state of a sheet on disk has its frames counted from the sheet, without reading its pixels.
	if(sheet_state && isfile(sheet) && fexists("[sheet]"))
		delays = worn_frame_delays(sheet, state_name)
		if(length(delays) > GARMENT_FIT_MAX_FRAMES)
			return FALSE
		if(length(delays) < 2)
			delays = null
	else
		var/frames = garment_frame_count(garment)
		if(frames > 1)
			delays = worn_frame_delays(sheet, state_name)
			if(length(delays) != frames)
				return FALSE
	var/list/metadata = sheet_state ? garment_sheet_metadata(sheet) : null
	if(!mode)
		if(metadata)
			mode = metadata["sleeves"][state_name] ? GARMENT_FIT_SHADED_SLEEVES : GARMENT_FIT_SOLID
		else
			mode = garment_sleeve_mode(icon(garment, "", SOUTH, 1))
	view_colours = metadata?["colours"]?[state_name]
	return TRUE

/**
 * An underclothes style's sprite fitted (/datum/sprite_accessory/clothing/proc/fitted_sprite()), as make_appearance() draws
 * it: its state fitted, then cut for a female body. A style whose legs the GAGS digitigrade mask draws is cut and masked
 * first, and the result fitted, legs and all. A state's first frame is fitted.
 */
/datum/garment_fit_job/underclothes
	/// The style.
	var/datum/sprite_accessory/clothing/style
	/// The state it's drawn from.
	var/icon_state_to_use
	/// The female cut's flags, or 0.
	var/cut
	/// Whether the GAGS digitigrade mask draws its legs.
	var/digitigrade_mask

/**
 * Arguments:
 * - cache, cache_key, fit: As /datum/garment_fit_job has them.
 * - style: The style.
 * - icon_state_to_use: The state it's drawn from.
 * - cut: The female cut's flags, or 0.
 * - digitigrade_mask: Whether the GAGS digitigrade mask draws its legs.
 */
/datum/garment_fit_job/underclothes/New(alist/cache, cache_key, datum/garment_fit/fit, datum/sprite_accessory/clothing/style, icon_state_to_use, cut, digitigrade_mask)
	. = ..()
	src.style = style
	src.icon_state_to_use = icon_state_to_use
	src.cut = cut
	src.digitigrade_mask = digitigrade_mask
	mode = style.fit_mode

/datum/garment_fit_job/underclothes/setup()
	var/sheet = style.greyscale_config ? SSgreyscale.GetColoredIconByType(style.greyscale_config, style.greyscale_colors) : style.icon
	garment = icon(sheet, icon_state_to_use)
	if(digitigrade_mask)
		if(cut)
			garment = wear_female_version(icon_state_to_use, sheet, style.icon, cut)
		var/icon/digitigrade_legs = icon(SSgreyscale.GetColoredIconByType(/datum/greyscale_config/digitigrade_underwear, style.greyscale_colors), style.digi_icon_state)
		garment = apply_icon_mask(garment, LEGS_MASK, digitigrade_legs)
	else if(!style.greyscale_config)
		view_colours = garment_sheet_metadata(sheet)?["colours"]?[icon_state_to_use]
	return TRUE

/datum/garment_fit_job/underclothes/straight_over_pecs()
	return style.hangs_straight_over_pecs()

/datum/garment_fit_job/underclothes/bares_near_forearm()
	return style.bares_near_forearm()

/datum/garment_fit_job/underclothes/finish()
	if(cut && !digitigrade_mask)
		garment = wear_female_version("", "fitted [fit.key] [style.type] [icon_state_to_use]", garment, cut)
	return fcopy_rsc(garment)

/**
 * An underclothes style's sprite fitted over flexing pecs (its fit's pec_flex), so the top moves with them: animated as the
 * flex is, each frame fitted to the pecs on that frame of it (garment_pec_flex()) over one fit of the limbs a view, then cut
 * for a female body, all as the still fit is. The frames are drawn over a state of the flex's own sheet, so the sprite keeps
 * its delays and loops as the pecs do. A style whose state is animated itself keeps its still fit.
 *
 * Nobody is drawn again for it: a top that starts moving partway through a flex would move out of step with the pecs. A body
 * that drew it unfitted, its still fit in its place, draws it from its next flex on. So fitted_sprite() queues one for each
 * flex sheet as soon as the top is drawn over pecs, ahead of any flex, and nobody waits for those.
 */
/datum/garment_fit_job/underclothes/flex
	/// The direction being fitted, fitted to the limbs alone: each of its frames is a copy, fitted on to that frame's pecs.
	var/datum/garment_fit_view/limb_view

/datum/garment_fit_job/underclothes/flex/wait(mob/living/carbon/human/wearer, redraw)
	return

/datum/garment_fit_job/underclothes/flex/setup()
	if(!..() || garment_frame_count(garment) > 1)
		return FALSE
	delays = garment_pec_flex(fit.pec_flex)["delays"]
	var/icon/still = garment
	garment = icon(fit.pec_flex, icon_states(fit.pec_flex)[1])
	for(var/frame in 1 to length(delays))
		for(var/dir in GLOB.cardinals)
			garment.Insert(icon(still, "", dir), "", dir, frame, 0, delays[frame])
	return TRUE

/datum/garment_fit_job/underclothes/flex/fit_view(view)
	var/static/list/view_names = list("S", "N", "E", "W")
	var/static/list/view_dirs = list(SOUTH, NORTH, EAST, WEST)
	var/frames = length(delays)
	var/view_index = ceil(view / frames)
	var/frame = view - (view_index - 1) * frames
	// A direction's frames are fitted in order, and its first is still the style's own, as are the front's sleeves.
	if(frame == 1)
		limb_view = new(icon(garment, "", view_dirs[view_index], 1), view_names[view_index], fit.sizes, view_colours?[view_index] ? unpack_garment_colours(view_colours[view_index]) : null)
		limb_view.fit_limbs(mode, garment_front_sleeves(garment, 1, fit.sizes), bares_near_forearm())
	var/datum/garment_fit_view/fitting = limb_view.copy()
	fitting.fit_pecs(garment_pec_flex(fit.pec_flex)["shapes"][fit.pec_shape][frame], fit.pec_nipples, mode, straight_over_pecs())
	if(!fitting.draw())
		return FALSE
	garment.Insert(fitting.frame, "", view_dirs[view_index], frame, 0, delays[frame])
	return TRUE

#undef GARMENT_FIT_MAX_PIECES
#undef GARMENT_FIT_MAX_FINISH_ROUNDS
