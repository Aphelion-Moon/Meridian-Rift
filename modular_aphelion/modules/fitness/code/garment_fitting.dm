/// The limbs underclothes are fitted to, in the order a garment's fit lists their levels.
GLOBAL_LIST_INIT(garment_fit_limbs, list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG))

/// Index of a pixel of a 32x32 view in the fitting's pixel lists, from x and y counted from the view's top left from 0, as the
/// templates give them.
#define FIT_INDEX(x, y) ((y) * 32 + (x) + 1)
/// The furthest a top's chest panel moves out over pecs drawn under it, in pixels.
#define PEC_PANEL_MAX_MOVE 2
/// Sleeve modes (garment_sleeve_mode()): fewer sleeve pixels than this over the arms is no sleeve at all.
#define SLEEVE_MIN_PIXELS 6
/// A sleeve colour is lit, and counts, when its brightest channel is at least this; darker ones are outlines and shadows.
#define SLEEVE_LIT_MIN 90
/// A lit colour is grey when its channels spread less than this percentage of its brightest one.
#define SLEEVE_GREY_PERCENT 12
/// The most lit colours, greys or hued ones, plain sleeves have.
#define SLEEVE_MAX_COLOURS 5
/// The widest arc of hues, in degrees, plain sleeves span.
#define SLEEVE_MAX_HUE_SPREAD 20
/// The most greys plain sleeves of a hue have beside it.
#define SLEEVE_MAX_GREYS_WITH_HUE 1

/**
 * Returns the limb templates garments are fitted with, read from fitting/fit_templates.json the first time they're asked for:
 * SSgarment_fitting reads them as the server starts. The file is compiled into the resource file, so a server has it wherever
 * it runs.
 *
 * `limbs` holds, for each limb, fitness level and view ("S", "N", "E" or "W"), the rows its outline grew in as
 * `bands` (y, step back into the limb, new edge, old edge, distance, and whether the row is one an arm grew into above its
 * old top, which only a sleeve is fitted over), its baseline pixels as `core` and its fitted pixels' skin tones as `tones`. The
 * limbs are the arms and legs by zone, and a digitigrade body's legs, "r_leg_digi" and "l_leg_digi". A leg in a side view
 * grows toward both its front and its back.
 */
/proc/garment_fit_templates()
	var/static/list/templates
	if(!templates)
		templates = json_decode(file2text('modular_aphelion/modules/fitness/fitting/fit_templates.json'))
	return templates

/**
 * Returns the templates tops are fitted to pecs with, read from fitting/pec_templates.json the first time they're asked for, as
 * the limb templates are.
 *
 * `centre` is the chest's centre column and `chest` the chest's own outline, per view and row, as its outermost x on each side.
 * `shapes` holds, for each pec shape and view: in front and back views, the pec's outermost x on each side per row as `rows`
 * (null where it has none) and its pixels as `pixels`, also kept by FIT_INDEX() as `mask`; in side views, its bulge past the
 * body's front as `bands`, in the limb templates' form; in the front view, the pixels its smile shades as `smile`, for pecs
 * with and without nipples.
 */
/proc/garment_pec_templates()
	var/static/list/templates
	if(!templates)
		templates = json_decode(file2text('modular_aphelion/modules/fitness/fitting/pec_templates.json'))
		for(var/shape_name, shape_views in templates["shapes"])
			for(var/view_name, view_template in shape_views)
				var/list/mask = new /list(1024)
				for(var/list/pec_pixel as anything in view_template["pixels"])
					mask[FIT_INDEX(pec_pixel[1], pec_pixel[2])] = TRUE
				view_template["mask"] = mask
	return templates

/// Every garment fit, by its key: each is made once and shared (get_garment_fit()), so fitted sprites are cached by it.
GLOBAL_ALIST_EMPTY(garment_fits)

/**
 * What a garment is fitted to: the fitness level of each limb it fits, and pecs drawn under it. Each is made once and shared
 * (get_garment_fit()): a body keeps its own (/mob/living/carbon/human/var/garment_fit), and fitted sprites are cached by it.
 */
/datum/garment_fit
	/// Template limb -> fitness level, for each limb above the baseline, in GLOB.garment_fit_limbs order: "r_arm", "l_arm", and
	/// the legs by zone or, fitted through their digitigrade templates, "r_leg_digi" and "l_leg_digi".
	var/list/levels
	/// The shape of pecs drawn under the garment, as the pec templates name it ("pecs", "pecs_big" or "pecs_biggest"), or null.
	var/pec_shape
	/// Whether those pecs draw nipples. Pecs under underclothes draw their nippleless twin either way; this is the shape's own.
	var/pec_nipples
	/// The fit as text, unique to it.
	var/key
	/// This fit with its legs fitted through their digitigrade templates, for digitigrade art: itself when it fits no legs or
	/// already fits them so.
	var/datum/garment_fit/digitigrade
	/// Pec shapes this fit was asked for under a top -> this fit over them. See over_pecs().
	var/alist/pec_fits

/datum/garment_fit/New(list/levels, pec_shape, pec_nipples, key)
	src.levels = levels
	src.pec_shape = pec_shape
	src.pec_nipples = pec_nipples
	src.key = key

/**
 * Returns the garment fit to these levels and pecs, made the first time it's asked for.
 *
 * Arguments:
 * - levels: Template limb -> fitness level, as /datum/garment_fit has them, or null for no limb above the baseline.
 * - pec_shape: The shape of pecs drawn under the garment, as /datum/garment_fit has it, or null.
 * - pec_nipples: Whether those pecs draw nipples.
 */
/proc/get_garment_fit(list/levels, pec_shape, pec_nipples)
	var/static/list/digitigrade_legs = list(BODY_ZONE_R_LEG = "[BODY_ZONE_R_LEG]_digi", BODY_ZONE_L_LEG = "[BODY_ZONE_L_LEG]_digi")
	levels ||= list()
	var/key = ""
	for(var/limb, level in levels)
		key += "[limb][level]"
	if(pec_shape)
		key += "[pec_shape][pec_nipples ? "" : "_nippleless"]"
	var/datum/garment_fit/fit = GLOB.garment_fits[key]
	if(fit)
		return fit
	fit = new(levels, pec_shape, pec_nipples, key)
	GLOB.garment_fits[key] = fit
	var/list/digitigrade_levels = list()
	var/has_legs = FALSE
	for(var/limb, level in levels)
		var/digitigrade_leg = digitigrade_legs[limb]
		has_legs ||= !isnull(digitigrade_leg)
		digitigrade_levels[digitigrade_leg || limb] = level
	fit.digitigrade = has_legs ? get_garment_fit(digitigrade_levels, pec_shape, pec_nipples) : fit
	return fit

/**
 * Returns this fit over pecs drawn under a top, made the first time it's asked for.
 *
 * Arguments:
 * - shape: The pecs' shape, one with a garment_fit_shape.
 */
/datum/garment_fit/proc/over_pecs(datum/sprite_accessory/genital/breasts/shape)
	var/datum/garment_fit/fit = pec_fits?[shape]
	if(!fit)
		fit = get_garment_fit(levels, shape.garment_fit_shape, shape.pecs_nipples)
		pec_fits ||= alist()
		pec_fits[shape] = fit
	return fit

/**
 * Fits a garment's state in place: each direction, and each animation frame, is fitted on its own (fit_garment_view()).
 *
 * Arguments:
 * - garment: The garment's state, a 32x32 /icon with four directions, named "". Changed in place.
 * - mode: How the garment is fitted, a GARMENT_FIT_* define.
 * - fit: What it is fitted to.
 * - delays: An animated state's frame delays, from its sheet, or null for a state of one frame.
 * - view_colours: Each view's colours, as fit_garment_view() takes them, by view, or null to read them from the pixels.
 *
 * Returns:
 * - The /icon passed in, fitted: some view changed.
 * - null: The fit changes no view, and the garment is drawn as it is.
 */
/proc/fit_garment_frames(icon/garment, mode, datum/garment_fit/fit, list/delays, list/view_colours)
	for(var/view in 1 to 4 * max(length(delays), 1))
		if(fit_garment_view(garment, view, mode, fit, delays, view_colours?[view]))
			. = garment

/**
 * Fits one view of a garment's state in place, one direction's animation frame (/datum/garment_fit_view), and draws it back
 * over the state's own when the fit changes it. A state's views are numbered direction by direction (S, N, E, W), and frame by
 * frame within each.
 *
 * Arguments:
 * - garment: The garment's state, a 32x32 /icon with four directions, named "". Changed in place.
 * - view: Which view, from 1 to 4 times the state's frames.
 * - mode: How the garment is fitted, a GARMENT_FIT_* define.
 * - fit: What it is fitted to.
 * - delays: An animated state's frame delays, from its sheet, or null for a state of one frame. Every frame keeps its delay:
 *   without one, Insert() gives a frame of the first direction a neighbouring frame's delay.
 * - colours: The view's colours and how many pixels have each, packed as garment_sheet_metadata() holds them, for a view of
 *   a static sheet's own state; or null, to read them from its pixels.
 *
 * Returns whether the view changed.
 */
/proc/fit_garment_view(icon/garment, view, mode, datum/garment_fit/fit, list/delays, colours)
	var/static/list/view_names = list("S", "N", "E", "W")
	var/static/list/view_dirs = list(SOUTH, NORTH, EAST, WEST)
	var/frames = max(length(delays), 1)
	var/view_index = ceil(view / frames)
	var/frame = view - (view_index - 1) * frames
	var/datum/garment_fit_view/fitting = new(icon(garment, "", view_dirs[view_index], frame), view_names[view_index], fit.levels, colours ? unpack_garment_colours(colours) : null)
	if(!fitting.fit(mode, fit.pec_shape, fit.pec_nipples))
		return FALSE
	garment.Insert(fitting.frame, "", view_dirs[view_index], frame, 0, delays?[frame])
	return TRUE

/**
 * Returns what garment fitting knows of a sheet without reading its pixels, from fitting/garment_metadata.json, which
 * tools/fitness/gen_garment_metadata.py writes: `sleeves`, its states whose own sleeves pick shaded sleeves -> TRUE, and `colours`,
 * for each state whose fits read whole views, those views' colours as fit_garment_view() takes them, or null for a view read
 * from its pixels. Null for a sheet it doesn't know, like a generated icon, or one that changed after the file was written:
 * those are read from their pixels.
 *
 * A sheet is checked against its hash the first time it's asked about each round.
 *
 * Arguments:
 * - sheet: The sheet.
 */
/proc/garment_sheet_metadata(sheet)
	var/static/alist/checked = alist()
	. = checked[sheet]
	if(!isnull(.))
		return . || null
	var/list/entry = isfile(sheet) ? garment_metadata()["[sheet]"] : null
	if(!entry || md5(sheet) != entry["md5"])
		checked[sheet] = FALSE
		return null
	var/list/sleeves = list()
	for(var/state in entry["sleeves"])
		sleeves[state] = TRUE
	entry["sleeves"] = sleeves
	checked[sheet] = entry
	return entry

/**
 * Returns fitting/garment_metadata.json's sheets, by path, read the first time they're asked for: SSgarment_fitting reads them
 * as the server starts. See garment_sheet_metadata().
 */
/proc/garment_metadata()
	var/static/list/sheets
	sheets ||= json_decode(file2text('modular_aphelion/modules/fitness/fitting/garment_metadata.json'))["sheets"]
	return sheets

/**
 * Returns a view's colours, colour -> how many of its pixels have it, from the "rrggbb:count,..." form
 * garment_sheet_metadata() holds them in.
 *
 * Arguments:
 * - packed: The packed colours.
 */
/proc/unpack_garment_colours(packed)
	. = list()
	for(var/entry in splittext(packed, ","))
		.["#[copytext(entry, 1, 7)]"] = text2num(copytext(entry, 8))

/**
 * Returns how many animation frames a garment's state has, counted from its front view, up to GARMENT_FIT_MAX_FRAMES.
 *
 * Arguments:
 * - garment: The garment's state, an /icon named "".
 */
/proc/garment_frame_count(icon/garment)
	. = 1
	while(. < GARMENT_FIT_MAX_FRAMES && length(icon_states(icon(garment, "", SOUTH, . + 1))))
		.++

/**
 * Returns the mode a worn garment is fitted in when it doesn't set its own, picked from its sleeves in its front view: a port of
 * the fitting spec's sleeve_mode.py, which it must give the same answer as for every garment.
 *
 * The sleeves are the garment's pixels over the baseline arms (both arms' template `core`). Their lit colours count, where the
 * brightest channel is at least SLEEVE_LIT_MIN; darker ones are outlines and shadows. Plain sleeves, fitted with the arms'
 * shading (GARMENT_FIT_SHADED_SLEEVES), are greys only, up to SLEEVE_MAX_COLOURS of them, or one hue: up to SLEEVE_MAX_COLOURS
 * hued colours within SLEEVE_MAX_HUE_SPREAD degrees of each other, and at most SLEEVE_MAX_GREYS_WITH_HUE grey. Anything else,
 * and a garment with no sleeves or only dark ones, is fitted solid.
 *
 * Arguments:
 * - front: The garment's front view, as it's drawn: the first frame's, when it's animated.
 */
/proc/garment_sleeve_mode(icon/front)
	var/list/limbs = garment_fit_templates()["limbs"]
	var/covered = 0
	// Each distinct lit colour -> its channels.
	var/list/lit = list()
	for(var/arm in list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
		for(var/list/core_pixel as anything in limbs[arm]["1"]["S"]["core"])
			var/pixel = front.GetPixel(core_pixel[1] + 1, 32 - core_pixel[2])
			if(!pixel)
				continue
			covered++
			var/colour = copytext(pixel, 1, 8)
			if(lit[colour])
				continue
			var/list/channels = rgb2num(colour)
			if(max(channels[1], channels[2], channels[3]) >= SLEEVE_LIT_MIN)
				lit[colour] = channels
	if(covered < SLEEVE_MIN_PIXELS || !length(lit))
		return GARMENT_FIT_SOLID
	var/greys = 0
	var/hued = 0
	// Whether the sleeves have each hue, by whole degree + 1.
	var/list/hues = new /list(360)
	for(var/colour, colour_channels in lit)
		var/list/channels = colour_channels
		var/red = channels[1]
		var/green = channels[2]
		var/blue = channels[3]
		var/high = max(red, green, blue)
		var/spread = high - min(red, green, blue)
		if(spread * 100 < SLEEVE_GREY_PERCENT * high)
			greys++
			continue
		hued++
		var/hue
		if(high == red)
			hue = floor(60 * (green - blue) / spread)
			if(hue < 0)
				hue += 360
		else if(high == green)
			hue = 120 + floor(60 * (blue - red) / spread)
		else
			hue = 240 + floor(60 * (red - green) / spread)
		hues[hue + 1] = TRUE
	if(!hued)
		return greys <= SLEEVE_MAX_COLOURS ? GARMENT_FIT_SHADED_SLEEVES : GARMENT_FIT_SOLID
	if(hued > SLEEVE_MAX_COLOURS || greys > SLEEVE_MAX_GREYS_WITH_HUE)
		return GARMENT_FIT_SOLID
	// The hues' spread is the circle less the widest gap between neighbouring hues.
	var/first_hue
	var/last_hue
	var/widest_gap = 0
	for(var/degree in 0 to 359)
		if(!hues[degree + 1])
			continue
		if(isnull(first_hue))
			first_hue = degree
		else
			widest_gap = max(widest_gap, degree - last_hue)
		last_hue = degree
	widest_gap = max(widest_gap, first_hue + 360 - last_hue)
	return 360 - widest_gap <= SLEEVE_MAX_HUE_SPREAD ? GARMENT_FIT_SHADED_SLEEVES : GARMENT_FIT_SOLID

/**
 * One view of a garment being fitted: its frame, the pixels read from it, and the pixels the fitting writes over them.
 *
 * The fitting is a port of the fitting spec's reference fitter, and must stay pixel for pixel equal to it: the same reads,
 * writes and order. Pixels are addressed as the templates give them, from the top left from 0. A pixel is a colour as
 * GetPixel() returns it ("#rrggbb", or "#rrggbbaa" when partly transparent), or 0 where it's clear.
 */
/datum/garment_fit_view
	/// One direction of the garment's state, which the fitted pixels are drawn on.
	var/icon/frame
	/// The view's key in the templates: "S", "N", "E" or "W".
	var/view
	/// Template limb -> its fitness level, as /datum/garment_fit has them.
	var/list/levels
	/// The view's pixels as the fitting has them so far, by FIT_INDEX(): a pixel, or null where the frame isn't read yet.
	var/list/pixels
	/// The frame's own pixels, by FIT_INDEX(), wherever read: what the fitted pixels are compared with to draw them.
	var/list/original
	/// The FIT_INDEX() of each pixel the fitting has written, once each.
	var/list/written_indexes = list()
	/// While a pass runs (begin_pass()), its writes as x, y, pixel triples, made as it ends: a pass reads the view as it began.
	var/list/pending
	/// Colour (without alpha) -> how many of the view's pixels have it. Counted when a ramp first needs every colour (ramp()), and
	/// kept up to date from then on.
	var/list/colour_counts
	/// The frame's own colour counts, known without reading its pixels (garment_sheet_metadata()), or null.
	var/list/frame_colours

/datum/garment_fit_view/New(icon/frame, view, list/levels, list/frame_colours)
	src.frame = frame
	src.view = view
	src.levels = levels
	src.frame_colours = frame_colours
	pixels = new /list(1024)
	original = new /list(1024)

/**
 * Fits the view to its limbs in `mode`, then to pecs drawn under it, and draws what changed onto `frame`.
 *
 * Arguments:
 * - mode: A GARMENT_FIT_* define.
 * - pec_shape: The shape of pecs drawn under the garment, as /datum/garment_fit has it, or null.
 * - pec_nipples: Whether those pecs draw nipples.
 *
 * Returns:
 * - TRUE: The frame changed.
 * - FALSE: Nothing in this view changed, and the frame is the state's own.
 */
/datum/garment_fit_view/proc/fit(mode, pec_shape, pec_nipples)
	// A fit has one pair of legs: a digitigrade body's are fitted through their own templates.
	var/static/list/legs = list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, "[BODY_ZONE_R_LEG]_digi", "[BODY_ZONE_L_LEG]_digi")
	var/pattern = mode == GARMENT_FIT_PATTERN
	apply_bands(limb_templates(list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM)), pattern)
	apply_bands(limb_templates(legs), pattern)
	switch(mode)
		if(GARMENT_FIT_SHADED_SLEEVES)
			shade_arm_form()
			darken_moved_edges()
		if(GARMENT_FIT_KNIT)
			knit_sleeves()
	if(pec_shape)
		fit_pecs(pec_shape, pec_nipples, mode)
	. = FALSE
	for(var/index in written_indexes)
		var/pixel = pixels[index]
		if(pixel == original[index])
			continue
		frame.DrawBox(pixel || null, (index - 1) % 32 + 1, 32 - floor((index - 1) / 32))
		. = TRUE

/**
 * Returns the template of `limb` at its level for this view, or null when the limb isn't fitted.
 *
 * Arguments:
 * - limb: A template limb, as /datum/garment_fit names it.
 */
/datum/garment_fit_view/proc/template_for(limb)
	var/level = levels[limb]
	if(!level)
		return null
	return garment_fit_templates()["limbs"][limb]["[level]"][view]

/**
 * Returns the view's pixel at x, y as the fitting has it so far, reading the frame the first time.
 *
 * Arguments:
 * - x, y: From the view's top left, from 0. Off the view, the pixel is clear.
 */
/datum/garment_fit_view/proc/pixel(x, y)
	if(x < 0 || x > 31 || y < 0 || y > 31)
		return 0
	var/index = FIT_INDEX(x, y)
	. = pixels[index]
	if(isnull(.))
		. = frame.GetPixel(x + 1, 32 - y) || 0
		pixels[index] = .
		original[index] = .

/**
 * Starts a pass: until end_pass(), writes wait, and reads see the view as it was when the pass began.
 */
/datum/garment_fit_view/proc/begin_pass()
	pending = list()

/**
 * Ends the pass begin_pass() started, making its writes in order: a later write to a pixel wins.
 */
/datum/garment_fit_view/proc/end_pass()
	var/list/writes = pending
	pending = null
	for(var/write_start in 1 to length(writes) step 3)
		write(writes[write_start], writes[write_start + 1], writes[write_start + 2])

/**
 * Writes a pixel, or queues it while a pass runs.
 *
 * Arguments:
 * - x, y: From the view's top left, from 0.
 * - pixel: The pixel to write.
 */
/datum/garment_fit_view/proc/write(x, y, pixel)
	if(pending)
		pending.Add(x, y, pixel)
		return
	var/old_pixel = pixel(x, y)
	if(colour_counts)
		if(old_pixel)
			colour_counts[copytext(old_pixel, 1, 8)]--
		if(pixel)
			colour_counts[copytext(pixel, 1, 8)]++
	var/index = FIT_INDEX(x, y)
	if(pixel != original[index])
		written_indexes |= index
	pixels[index] = pixel

/**
 * Returns the view's colours, without alpha, brightest first: the garment's own ramp. Counts them the first time: from the
 * frame's own counts and what has been written over them, when they're known, otherwise by reading the whole view.
 *
 * Brightness is 299 R + 587 G + 114 B, the spec's luminance in whole numbers. Colours as bright as each other keep the order
 * they were counted in, which only a read gives; tools/fitness/gen_garment_metadata.py leaves out the views that have any.
 */
/datum/garment_fit_view/proc/ramp()
	if(!colour_counts && frame_colours)
		colour_counts = frame_colours.Copy()
		for(var/index in written_indexes)
			var/old_pixel = original[index]
			if(old_pixel)
				colour_counts[copytext(old_pixel, 1, 8)]--
			var/pixel = pixels[index]
			if(pixel)
				colour_counts[copytext(pixel, 1, 8)]++
	if(!colour_counts)
		colour_counts = list()
		var/index = 0
		for(var/frame_y in 32 to 1 step -1)
			for(var/frame_x in 1 to 32)
				var/pixel = pixels[++index]
				if(isnull(pixel))
					pixel = frame.GetPixel(frame_x, frame_y) || 0
					pixels[index] = pixel
					original[index] = pixel
				if(pixel)
					colour_counts[copytext(pixel, 1, 8)]++
	var/list/brightness = list()
	for(var/colour, count in colour_counts)
		if(count > 0)
			var/list/channels = rgb2num(colour)
			brightness[colour] = channels[1] * 299 + channels[2] * 587 + channels[3] * 114
	return sortTim(brightness, GLOBAL_PROC_REF(cmp_numeric_dsc), TRUE)

/**
 * Returns `pixel` with its colour swapped for `colour`, keeping its alpha.
 *
 * Arguments:
 * - colour: A colour without alpha, from ramp().
 * - pixel: A pixel that isn't clear.
 */
/datum/garment_fit_view/proc/recolour(colour, pixel)
	return "[colour][copytext(pixel, 8)]"

/**
 * Whether the garment covers at least half of a limb's baseline pixels: a sleeve, which is fitted over the rows the limb grew
 * above its old top. Straps over the shoulder are not.
 *
 * Arguments:
 * - core: The limb template's baseline pixels, as x, y pairs.
 */
/datum/garment_fit_view/proc/covers(list/core)
	if(!length(core))
		return FALSE
	var/covered = 0
	for(var/list/core_pixel as anything in core)
		if(pixel(core_pixel[1], core_pixel[2]))
			covered++
	return covered * 2 >= length(core)

/**
 * One pass of the fitting over the templates' bands. Solid: each row the garment covers at the old edge and the pixel inside it
 * moves its edge pixel out to the new edge and fills the gap with that inside pixel. Pattern: each new pixel copies the pixel 2
 * further in, wherever the garment covers any of the 3 pixels from the old edge in.
 *
 * Arguments:
 * - templates: The templates, fitted in order: a limb's, or another part of the body's in the same form.
 * - pattern: Whether to fit as pattern rather than solid.
 */
/datum/garment_fit_view/proc/apply_bands(list/templates, pattern)
	begin_pass()
	for(var/list/template as anything in templates)
		var/sleeve
		for(var/list/band as anything in template["bands"])
			var/y = band[1]
			var/step = band[2]
			var/new_edge = band[3]
			var/old_edge = band[4]
			if(band[6])
				if(isnull(sleeve))
					sleeve = covers(template["core"])
				if(!sleeve)
					continue
			var/distance = band[5]
			if(pattern)
				if(!pixel(old_edge, y) && !pixel(old_edge + step, y) && !pixel(old_edge + 2 * step, y))
					continue
				for(var/offset in 0 to distance - 1)
					var/x = new_edge + offset * step
					write(x, y, pixel(x + 2 * step, y))
				continue
			var/inside = pixel(old_edge + step, y)
			if(!pixel(old_edge, y) || !inside)
				continue
			write(new_edge, y, pixel(old_edge, y))
			for(var/offset in 1 to distance)
				write(new_edge + offset * step, y, inside)
	end_pass()

/**
 * Shaded sleeves, first step: the garment's brightest colour over an arm takes the arm's muscle tone, mapped into the
 * garment's own ramp (skin tones 0-5 to ramp steps 0, 0, 1, 1, 2, 2).
 */
/datum/garment_fit_view/proc/shade_arm_form()
	var/static/list/ramp_step_of_tone = list(0, 0, 1, 1, 2, 2)
	var/list/arm_templates = limb_templates(list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
	if(!length(arm_templates))
		return
	var/list/ramp = ramp()
	if(!length(ramp))
		return
	begin_pass()
	for(var/list/template as anything in arm_templates)
		for(var/list/tone as anything in template["tones"])
			var/pixel = pixel(tone[1], tone[2])
			if(pixel && copytext(pixel, 1, 8) == ramp[1])
				write(tone[1], tone[2], recolour(ramp[min(ramp_step_of_tone[tone[3] + 1] + 1, length(ramp))], pixel))
	end_pass()

/**
 * Shaded sleeves, second step: the pixel at each fitted arm row's new edge goes one step darker in the garment's ramp.
 */
/datum/garment_fit_view/proc/darken_moved_edges()
	var/list/arm_templates = limb_templates(list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
	if(!length(arm_templates))
		return
	var/list/ramp = ramp()
	begin_pass()
	for(var/list/template as anything in arm_templates)
		for(var/list/band as anything in template["bands"])
			var/pixel = pixel(band[3], band[1])
			if(!pixel)
				continue
			var/ramp_step = ramp.Find(copytext(pixel, 1, 8))
			if(ramp_step && ramp_step < length(ramp))
				write(band[3], band[1], recolour(ramp[ramp_step + 1], pixel))
	end_pass()

/**
 * Returns the templates of the fitted ones of `limbs` for this view, in order.
 *
 * Arguments:
 * - limbs: Template limbs, as /datum/garment_fit names them.
 */
/datum/garment_fit_view/proc/limb_templates(list/limbs)
	. = list()
	for(var/limb in limbs)
		var/list/template = template_for(limb)
		if(template)
			. += list(template)

/**
 * Ribbed knit sleeves: each sleeve's ribs laid again from its outer edge, in columns anchored to its widest row, its shadow
 * against the body thinned to one mid pixel, and its first cuff row ribbed light. Works on the view in place, row by row.
 *
 * The ramp's four brightest colours are the knit's: rib, groove, mid and dark. A garment with fewer isn't a knit.
 */
/datum/garment_fit_view/proc/knit_sleeves()
	// Each view's sleeves, and the way each is walked in from its outer edge.
	var/static/list/sleeve_walks = list(
		"S" = list(BODY_ZONE_R_ARM = 1, BODY_ZONE_L_ARM = -1),
		"N" = list(BODY_ZONE_L_ARM = 1, BODY_ZONE_R_ARM = -1),
		"E" = list(BODY_ZONE_R_ARM = 1),
		"W" = list(BODY_ZONE_L_ARM = -1),
	)
	var/list/walks = sleeve_walks[view]
	var/any_sleeve = FALSE
	for(var/limb in walks)
		any_sleeve ||= levels[limb]
	if(!any_sleeve)
		return
	var/list/ramp = ramp()
	if(length(ramp) < 4)
		return
	var/rib = ramp[1]
	var/groove = ramp[2]
	var/mid = ramp[3]
	var/dark = ramp[4]
	var/side_view = view == "E" || view == "W"
	for(var/limb, step in walks)
		var/list/template = template_for(limb)
		if(!template)
			continue
		// The sleeve's pixels, by FIT_INDEX(); in a side view the far arm's count too.
		var/list/arm = new /list(1024)
		var/list/arm_rows = new /list(32)
		var/list/arm_templates = list(template)
		if(side_view)
			for(var/other_limb in list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
				if(other_limb != limb && levels[other_limb])
					arm_templates += list(template_for(other_limb))
		for(var/list/arm_template as anything in arm_templates)
			for(var/list/tone as anything in arm_template["tones"])
				arm[FIT_INDEX(tone[1], tone[2])] = TRUE
				arm_rows[tone[2] + 1] = TRUE
		// Rows are walked from the outer edge: the whole view in a side view, the sleeve's half in front and back views.
		var/first_x = step > 0 ? 0 : 31
		var/last_x = step > 0 ? 31 : 0
		if(!side_view)
			last_x = step > 0 ? 15 : 16
		// First pass: each row's run of rib and groove from its outer edge, ribbed again from the widest run's start.
		var/list/runs = new /list(32)
		var/reference_x
		var/widest_run = 0
		for(var/y in 0 to 31)
			if(!arm_rows[y + 1])
				continue
			var/start = first_pixel(y, first_x, last_x, step)
			if(isnull(start))
				continue
			var/list/run = list()
			for(var/x = start, x >= 0 && x <= 31 && is_one_of(pixel(x, y), rib, groove), x += step)
				run += x
			if(!length(run))
				continue
			runs[y + 1] = run
			if(length(run) > widest_run)
				widest_run = length(run)
				reference_x = run[1]
		if(!widest_run)
			continue
		for(var/y in 0 to 31)
			var/list/run = runs[y + 1]
			for(var/run_index in 1 to length(run))
				var/x = run[run_index]
				write(x, y, recolour((run_index == 1 || (x - reference_x) % 2 == 0) ? groove : rib, pixel(x, y)))
		// Second pass: a row starting dark is a cuff; any other keeps one mid pixel of its shadow against the body, ribbed beyond.
		var/list/cuff_rows = list()
		for(var/y in 0 to 31)
			if(!arm_rows[y + 1])
				continue
			var/start = first_pixel(y, first_x, last_x, step)
			if(isnull(start))
				continue
			if(copytext(pixel(start, y), 1, 8) == dark)
				cuff_rows.Add(y, start)
				continue
			var/x = start
			while(x >= 0 && x <= 31 && is_one_of(pixel(x, y), rib, groove))
				x += step
			var/list/shadow = list()
			while(x >= 0 && x <= 31 && arm[FIT_INDEX(x, y)] && is_one_of(pixel(x, y), mid, dark))
				shadow += x
				x += step
			for(var/shadow_index in 1 to length(shadow))
				var/shadow_x = shadow[shadow_index]
				var/colour = shadow_index == length(shadow) ? mid : ((shadow_x - reference_x) % 2 == 0 ? groove : rib)
				write(shadow_x, y, recolour(colour, pixel(shadow_x, y)))
		for(var/cuff_start in 1 to length(cuff_rows) step 2)
			var/y = cuff_rows[cuff_start]
			var/x = cuff_rows[cuff_start + 1]
			var/cuff_pixel = 0
			while(x >= 0 && x <= 31 && arm[FIT_INDEX(x, y)] && is_one_of(pixel(x, y), mid, dark))
				write(x, y, recolour((cuff_start == 1 && cuff_pixel % 2 == 0) ? groove : mid, pixel(x, y)))
				cuff_pixel++
				x += step

/**
 * Returns the x of the first pixel that isn't clear in row `y`, walking from `first_x` to `last_x` by `step`, or null.
 *
 * Arguments:
 * - y: The row.
 * - first_x, last_x: Where the walk starts and ends, both included.
 * - step: 1 or -1.
 */
/datum/garment_fit_view/proc/first_pixel(y, first_x, last_x, step)
	for(var/x = first_x, step > 0 ? x <= last_x : x >= last_x, x += step)
		if(pixel(x, y))
			return x
	return null

/**
 * Whether `pixel` isn't clear and its colour is `colour` or `other_colour`.
 *
 * Arguments:
 * - pixel: A pixel.
 * - colour, other_colour: Colours without alpha.
 */
/datum/garment_fit_view/proc/is_one_of(pixel, colour, other_colour)
	if(!pixel)
		return FALSE
	var/pixel_colour = copytext(pixel, 1, 8)
	return pixel_colour == colour || pixel_colour == other_colour

/**
 * Fits the view, after its limbs, to pecs drawn under the garment: a port of the fitting spec's pec fitter, which it must stay
 * pixel for pixel equal to.
 *
 * Front and back views: where a pec reaches the chest's own side, the garment's chest panel moves out over it
 * (pec_panel_bands()), then the front view shades the pecs' lower curve, in the modes the GARMENT_FIT_PEC_SMILE_* defines
 * pick (shade_pec_smile()). Side views: the pec's bulge past the body's front is fitted as a limb's bands are.
 *
 * Arguments:
 * - shape: The pecs' shape, as the pec templates name it.
 * - nipples: Whether the pecs draw nipples, which picks the smile's pixels.
 * - mode: A GARMENT_FIT_* define.
 */
/datum/garment_fit_view/proc/fit_pecs(shape, nipples, mode)
	var/static/list/smiles = list(
		GARMENT_FIT_SOLID = GARMENT_FIT_PEC_SMILE_SOLID,
		GARMENT_FIT_SHADED_SLEEVES = GARMENT_FIT_PEC_SMILE_SHADED_SLEEVES,
		GARMENT_FIT_KNIT = GARMENT_FIT_PEC_SMILE_KNIT,
		GARMENT_FIT_PATTERN = GARMENT_FIT_PEC_SMILE_PATTERN,
	)
	var/list/template = garment_pec_templates()["shapes"][shape][view]
	var/pattern = mode == GARMENT_FIT_PATTERN
	if(view == "E" || view == "W")
		apply_bands(list(template), pattern)
		return
	var/list/brightness = ramp()
	if(!length(brightness))
		return
	var/list/bands = pec_panel_bands(template, brightness)
	if(pattern)
		apply_bands(list(list("bands" = bands)), TRUE)
	else
		move_panel_edges(bands, fill_colour(brightness), mode == GARMENT_FIT_KNIT)
	if(view == "S" && smiles[mode])
		shade_pec_smile(template["smile"][nipples ? "nipples" : "nippleless"])

/**
 * Returns the bands a front or back view's chest panel moves out by over pecs drawn under it: y, step back into the body, new
 * edge, old edge, distance, and FALSE for a row that isn't a cap, as apply_bands() takes them.
 *
 * Each row the pec spans moves on each side where the pec's outermost pixel reaches the chest's own side; rows where it stays
 * inside, like the collar's, never move. Over a bare pec pixel, the garment's outline moves out: from its first pixel inward,
 * when it also holds the next two. Under the garment, like a sleeve over it, the panel's own edge moves: its armhole seam,
 * the first pixel walking out from the centre that is no brighter than 3/4 of the fill. Either moves at most PEC_PANEL_MAX_MOVE
 * pixels, every one of them over the pec.
 *
 * Arguments:
 * - template: The pecs' template for this view.
 * - brightness: The view's colours -> their brightness, from ramp().
 */
/datum/garment_fit_view/proc/pec_panel_bands(list/template, list/brightness)
	var/list/pec_templates = garment_pec_templates()
	var/centre = pec_templates["centre"]
	var/list/chest_rows = pec_templates["chest"][view]
	var/list/rows = template["rows"]
	var/list/mask = template["mask"]
	var/seam_brightness = 3 * brightness[fill_colour(brightness)]
	. = list()
	for(var/y in 0 to 31)
		var/list/row = rows["[y]"]
		if(!row)
			continue
		var/list/chest_row = chest_rows["[y]"]
		for(var/side in 1 to 2)
			var/step = side == 1 ? 1 : -1
			var/pec_edge = row[side]
			if(isnull(pec_edge) || (chest_row && (step > 0 ? pec_edge > chest_row[1] : pec_edge < chest_row[2])))
				continue
			var/edge
			if(!pixel(pec_edge, y))
				edge = pec_edge + step
				while((step > 0 ? edge < centre : edge > centre) && !pixel(edge, y))
					edge += step
				if(!pixel(edge, y) || !pixel(edge + step, y) || !pixel(edge + 2 * step, y))
					continue
			else
				edge = centre - step
				while(edge >= 0 && edge <= 31 && (step > 0 ? edge < centre : edge > centre) && pixel(edge, y) && 4 * brightness[copytext(pixel(edge, y), 1, 8)] > seam_brightness)
					edge -= step
				if(edge < 0 || edge > 31 || (step > 0 ? edge >= centre : edge <= centre) || !pixel(edge, y))
					continue
			var/distance = (edge - pec_edge) * step
			if(distance <= 0 || distance > PEC_PANEL_MAX_MOVE)
				continue
			var/over_pec = TRUE
			for(var/x = pec_edge, x != edge, x += step)
				if(!mask[FIT_INDEX(x, y)])
					over_pec = FALSE
					break
			if(over_pec)
				. += list(list(y, step, pec_edge, edge, distance, FALSE))

/**
 * Moves a solid or knit top's chest panel edges out over the pecs, by the bands of pec_panel_bands(): each edge pixel and its own
 * detail, up to the first pixel of the fill and 2 pixels in all, keep their order at the new edge, and the gap behind them
 * takes the pixel after the detail, or on a knit the pixel a whole number of 2 pixel rib periods further in.
 *
 * Arguments:
 * - bands: From pec_panel_bands().
 * - fill: The view's fill colour, from fill_colour().
 * - knit: Whether the top is a ribbed knit.
 */
/datum/garment_fit_view/proc/move_panel_edges(list/bands, fill, knit)
	begin_pass()
	for(var/list/band as anything in bands)
		var/y = band[1]
		var/step = band[2]
		var/new_edge = band[3]
		var/old_edge = band[4]
		var/distance = band[5]
		var/inside = pixel(old_edge + step, y)
		var/detail = (inside && copytext(inside, 1, 8) == fill) ? 1 : 2
		var/gap_pixel = pixel(old_edge + detail * step, y)
		if(!gap_pixel)
			continue
		for(var/offset in 0 to detail - 1)
			write(new_edge + offset * step, y, pixel(old_edge + offset * step, y))
		for(var/offset in detail to detail + distance - 1)
			var/x = new_edge + offset * step
			write(x, y, knit ? pixel(x + 2 * ceil((old_edge + detail * step - x) * step / 2) * step, y) : gap_pixel)
	end_pass()

/**
 * Shades the pecs' lower curve, a "smile" one row above their crease, one shade down in a front view, wherever the top is lit
 * there: brighter than 3/4 of its fill, so never a seam. A top with its own centre line, like a shirt's placket, keeps it off the
 * pixels either side of that line.
 *
 * Arguments:
 * - points: The smile's pixels, as x, y pairs.
 */
/datum/garment_fit_view/proc/shade_pec_smile(list/points)
	var/list/brightness = ramp()
	var/fill = fill_colour(brightness)
	var/lit_brightness = 3 * brightness[fill]
	var/centre = garment_pec_templates()["centre"]
	begin_pass()
	for(var/list/point as anything in points)
		var/x = point[1]
		var/y = point[2]
		if(x == centre - 1 || x == centre + 1)
			var/centre_pixel = pixel(centre, y)
			if(centre_pixel && copytext(centre_pixel, 1, 8) != fill)
				continue
		var/pixel = pixel(x, y)
		if(!pixel)
			continue
		var/pixel_brightness = brightness[copytext(pixel, 1, 8)]
		if(4 * pixel_brightness <= lit_brightness)
			continue
		var/shade = shade_step(pixel_brightness, brightness)
		if(shade)
			write(x, y, recolour(shade, pixel))
	end_pass()

/**
 * Returns the garment's colour one shade below a pixel: of its darker colours, the one whose brightness is nearest 86% of the
 * pixel's, the brighter of two as near. A fixed drop, so a top of many close greys still shades visibly. Null when no colour
 * is darker.
 *
 * Arguments:
 * - pixel_brightness: The pixel's brightness.
 * - brightness: The view's colours -> their brightness, brightest first, from ramp().
 */
/datum/garment_fit_view/proc/shade_step(pixel_brightness, list/brightness)
	var/nearest_gap
	for(var/colour, colour_brightness in brightness)
		if(colour_brightness >= pixel_brightness)
			continue
		// |100 colour - 86 pixel|, halved so the products stay exact in DM's numbers.
		var/gap = abs(50 * colour_brightness - 43 * pixel_brightness)
		if(isnull(nearest_gap) || gap < nearest_gap)
			nearest_gap = gap
			. = colour

/**
 * Returns the view's fill: its brightest colour covering at least 3 pixels, or its brightest colour when none does.
 *
 * Arguments:
 * - brightness: The view's colours -> their brightness, brightest first, from ramp().
 */
/datum/garment_fit_view/proc/fill_colour(list/brightness)
	for(var/colour in brightness)
		if(colour_counts[colour] >= 3)
			return colour
	return length(brightness) ? brightness[1] : null

#undef FIT_INDEX
#undef PEC_PANEL_MAX_MOVE
#undef SLEEVE_MIN_PIXELS
#undef SLEEVE_LIT_MIN
#undef SLEEVE_GREY_PERCENT
#undef SLEEVE_MAX_COLOURS
#undef SLEEVE_MAX_HUE_SPREAD
#undef SLEEVE_MAX_GREYS_WITH_HUE
