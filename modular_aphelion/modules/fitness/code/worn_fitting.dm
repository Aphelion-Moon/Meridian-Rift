/// The body shape bits that change a worn item's drawn icon before it's fitted (build_worn_icon()), which its fit is cached by.
#define WORN_FIT_BODYSHAPES (BODYSHAPE_DIGITIGRADE|BODYSHAPE_CERULEAN|BODYSHAPE_TAUR)
/// The GARMENT_FIT_REDRAW_* flag of the slot `wearer` wears `item` in, among those fitted: uniform, suit, shoes and gloves; or 0.
#define WORN_FIT_REDRAW(item, wearer) (item == wearer.w_uniform ? GARMENT_FIT_REDRAW_UNIFORM : item == wearer.wear_suit ? GARMENT_FIT_REDRAW_SUIT : item == wearer.shoes ? GARMENT_FIT_REDRAW_SHOES : item == wearer.gloves ? GARMENT_FIT_REDRAW_GLOVES : 0)

/obj/item/clothing
	/// How this garment is redrawn over its wearer's fitness limbs, a GARMENT_FIT_* define, or null for the mode its own sleeves
	/// pick as it's drawn (garment_sleeve_mode()). Shoes and gloves that don't set one are fitted solid.
	var/fit_mode

/**
 * Returns the icon build_worn_icon() draws this item worn with, fitted to its wearer's fitness limbs: `building_icon`, or the
 * worn state itself when it has none, redrawn as underclothes are (fit_garment_frames()). Each direction is fitted, and each
 * animation frame.
 *
 * Only an item worn as a uniform, suit, shoes or gloves by a human is fitted, and only a 32x32 state with four directions:
 * never one held, on a mannequin or inside another item, nor one drawn from a taur's 64x32 sheet. A taur's legs aren't fitted,
 * its arms are (/mob/living/carbon/human/var/garment_fit). Digitigrade legs are fitted through their own templates where the
 * legs drawn are digitigrade art (worn_digitigrade_art()); a plantigrade sprite on a digitigrade body is fitted as the human
 * legs it draws.
 *
 * Each fit is made once a round and cached by the fit and what draws the icon (its sheet, state, type, female cut, body shape
 * and colours), never by wearer, in nested lists: a draw at the baseline reads the wearer's fit and nothing more, and a fitted
 * draw that's cached looks its sprite up. The first draw of a new fit is drawn as it is while SSgarment_fitting makes it,
 * then drawn again (GARMENT_FITS_DEFERRED), except on a dummy, whose fits are made as they're drawn.
 *
 * Arguments:
 * - building_icon: The icon build_worn_icon() has built, after the female cut and body shape masks, or null to draw the worn
 *   state as it is.
 * - file2use: The worn sheet.
 * - t_state: The worn state in it.
 * - female_uniform: The female cut's flags, when cut.
 * - bodyshape: The body shape it's drawn for.
 * - isinhands: Whether it's drawn held.
 *
 * Returns:
 * - The fitted icon, a cached resource every wearer it fits shares.
 * - `building_icon` as it is, when nothing is fitted, or its fit is still being made.
 */
/obj/item/proc/fit_worn_icon(icon/building_icon, file2use, t_state, female_uniform, bodyshape, isinhands)
	var/mob/living/carbon/human/wearer = loc
	if(isinhands || !ishuman(wearer) || !wearer.garment_fit || !file2use)
		return building_icon
	var/redraw = WORN_FIT_REDRAW(src, wearer)
	if(!redraw)
		return building_icon
	var/datum/garment_fit/fit = wearer.garment_fit
	if((bodyshape & BODYSHAPE_DIGITIGRADE) && worn_digitigrade_art(file2use, bodyshape))
		fit = fit.digitigrade
	var/static/alist/fitted_sprites = alist()
	var/variant = (bodyshape & WORN_FIT_BODYSHAPES) | (female_uniform << 6)
	var/colours = greyscale_colors || ""
	// A list drops a null key, and a fit cached under one would never be found.
	var/state_key = t_state || ""
	var/fitted = fitted_sprites[fit]?[file2use]?[state_key]?[type]?[variant]?[colours]
	if(isfile(fitted))
		return fitted
	if(isnull(fitted))
		var/datum/garment_fit_job/worn/job = new(garment_fit_cache_slot(fitted_sprites, fit, file2use, state_key, type, variant), colours, fit, building_icon, file2use, t_state, worn_fit_mode(redraw))
		fitted = job.start(wearer, redraw)
	else if(istype(fitted, /datum/garment_fit_job))
		var/datum/garment_fit_job/job = fitted
		job.wait(wearer, redraw)
	return isfile(fitted) ? fitted : building_icon

/**
 * Fits the glows a worn item draws from its own worn sheet, the separate "-emissive" states of hazard vests, labcoats and the
 * like, to its wearer's fitness limbs as its sprite is (fit_worn_icon()), so they stay on the fitted sleeves. The emissive
 * blocker needs nothing: it's drawn from the fitted sprite itself.
 *
 * A glow only shows its shape, so it's fitted solid, or as a pattern for a garment fitted as one; its legs follow the
 * digitigrade templates only when it's drawn from a digitigrade sheet. Cached as sprites are, and drawn as it is while its fit
 * is made. What's drawn from the sprite's own state, like its emissive blocker, is drawn from whatever sprite is drawn,
 * fitted or not, and isn't a glow.
 *
 * Arguments:
 * - worn_overlays: The item's worn overlays, from worn_overlays(). Glows are swapped for their fitted copies in place.
 * - file2use: The worn sheet.
 * - t_state: The sprite's own state in it.
 * - bodyshape: The body shape it's drawn for.
 * - isinhands: Whether it's drawn held.
 */
/obj/item/proc/fit_worn_glows(list/worn_overlays, file2use, t_state, bodyshape, isinhands)
	var/mob/living/carbon/human/wearer = loc
	if(isinhands || !ishuman(wearer) || !wearer.garment_fit)
		return
	var/list/glow_indexes
	for(var/index in 1 to length(worn_overlays))
		var/mutable_appearance/overlay = worn_overlays[index]
		if(isimage(overlay) && overlay.icon == file2use && overlay.icon_state != t_state && PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE)
			LAZYADD(glow_indexes, index)
	var/redraw = WORN_FIT_REDRAW(src, wearer)
	if(!glow_indexes || !redraw)
		return
	var/datum/garment_fit/fit = wearer.garment_fit
	if((bodyshape & BODYSHAPE_DIGITIGRADE) && worn_digitigrade_sheet(file2use))
		fit = fit.digitigrade
	var/obj/item/clothing/garment = src
	var/mode = (istype(garment) && garment.fit_mode == GARMENT_FIT_PATTERN) ? GARMENT_FIT_PATTERN : GARMENT_FIT_SOLID
	var/colours = greyscale_colors || ""
	var/static/alist/fitted_glows = alist()
	for(var/index in glow_indexes)
		var/mutable_appearance/glow = worn_overlays[index]
		var/state_key = glow.icon_state || ""
		var/fitted = fitted_glows[fit]?[file2use]?[state_key]?[type]?[mode]?[colours]
		if(isnull(fitted))
			var/datum/garment_fit_job/worn/job = new(garment_fit_cache_slot(fitted_glows, fit, file2use, state_key, type, mode), colours, fit, null, file2use, glow.icon_state, mode)
			fitted = job.start(wearer, redraw)
		else if(istype(fitted, /datum/garment_fit_job))
			var/datum/garment_fit_job/job = fitted
			job.wait(wearer, redraw)
		if(!isfile(fitted))
			continue
		var/mutable_appearance/fitted_glow = new(glow)
		fitted_glow.icon = fitted
		fitted_glow.icon_state = ""
		worn_overlays[index] = fitted_glow

/**
 * Returns the mode this item is fitted in as it's worn, as far as it's known before its sprite is read: its own `fit_mode` if
 * it sets one, solid for shoes and gloves, and otherwise null, for the mode its sleeves pick (garment_sleeve_mode()).
 *
 * Arguments:
 * - redraw: The GARMENT_FIT_REDRAW_* flag of the slot it's worn in.
 */
/obj/item/proc/worn_fit_mode(redraw)
	var/obj/item/clothing/clothing = src
	if(istype(clothing) && clothing.fit_mode)
		return clothing.fit_mode
	return (redraw & (GARMENT_FIT_REDRAW_SHOES|GARMENT_FIT_REDRAW_GLOVES)) ? GARMENT_FIT_SOLID : null

/**
 * Returns the list a garment fit is cached in, under its own last key, by the keys before it, making each level as it goes.
 *
 * Arguments:
 * - cache: The cache.
 * - ...: The keys before the last, outermost first.
 */
/proc/garment_fit_cache_slot(alist/cache, ...)
	for(var/key_index in 2 to length(args))
		var/key = args[key_index]
		var/alist/level = cache[key]
		if(!level)
			level = alist()
			cache[key] = level
		cache = level
	return cache

/**
 * Returns an animated worn state's frame delays, read from its sheet, or null when the sheet isn't a file on disk, like a
 * generated icon, or has no such state.
 *
 * Arguments:
 * - sheet: The worn sheet.
 * - state: The state in it.
 */
/proc/worn_frame_delays(sheet, state)
	if(!isfile(sheet) || !fexists("[sheet]"))
		return null
	for(var/list/state_data as anything in icon_metadata(sheet)?["states"])
		if(state_data["name"] == state)
			return state_data["delay"]
	return null

/**
 * Whether this item's legs are drawn as digitigrade art on a digitigrade body: from a digitigrade sheet, or with the digitigrade
 * legs get_bodyshape_icon() draws over a plantigrade sprite (CLOTHING_DIGITIGRADE_MASK).
 *
 * Arguments:
 * - file2use: The worn sheet.
 * - bodyshape: The body shape it's drawn for.
 */
/obj/item/proc/worn_digitigrade_art(file2use, bodyshape)
	if(!(bodyshape & BODYSHAPE_DIGITIGRADE))
		return FALSE
	if(worn_digitigrade_sheet(file2use))
		return TRUE
	if(!(bodyshapes_with_variations & bodyshape) || !(supports_variations_flags & CLOTHING_DIGITIGRADE_MASK) || (supports_variations_flags & CLOTHING_DIGITIGRADE_VARIATION))
		return FALSE
	// A Cerulean's tail takes the mask's place.
	return !((bodyshape & BODYSHAPE_CERULEAN) && ((bodyshapes_with_variations & BODYSHAPE_CERULEAN) || (supports_variations_flags & CERULEAN_MASKING)))

/**
 * Whether `file2use` is one of the digitigrade sheets this item is drawn from on a digitigrade body: its own, or the default
 * uniform, suit or shoes one.
 *
 * Arguments:
 * - file2use: The worn sheet.
 */
/obj/item/proc/worn_digitigrade_sheet(file2use)
	return file2use == worn_icon_digi || file2use == DIGITIGRADE_UNIFORM_FILE || file2use == DIGITIGRADE_SUIT_FILE || file2use == DIGITIGRADE_SHOES_FILE

/**
 * Redraws the worn clothing fitted to this body's fitness limbs, its uniform, suit, shoes and gloves, after a fitness limb comes
 * or goes. Inside a render batch (STOP_OVERLAY_UPDATE_BODY_PARTS) it's left to whoever ends the batch.
 */
/mob/living/carbon/human/proc/refit_worn_clothing()
	if(living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS)
		return
	if(w_uniform)
		update_worn_undersuit()
	if(wear_suit)
		update_worn_oversuit()
	if(shoes)
		update_worn_shoes()
	if(gloves)
		update_worn_gloves()

/**
 * Refits the worn clothing of a body a fitness arm or leg is attached to: attaching a leg redraws only the uniform and suit, and
 * an arm only the gloves.
 */
/obj/item/bodypart/try_attach_limb(mob/living/carbon/new_limb_owner, special, lazy)
	. = ..()
	if(. && !lazy && fitness_level && ishuman(new_limb_owner) && (body_zone in GLOB.garment_fit_limbs))
		var/mob/living/carbon/human/wearer = new_limb_owner
		wearer.refit_worn_clothing()

/**
 * Refits the worn clothing of a body a fitness arm or leg comes off, whether lost or swapped for another limb.
 */
/obj/item/bodypart/drop_limb(special, dismembered, move_to_floor = TRUE)
	var/mob/living/carbon/human/wearer = owner
	. = ..()
	if(fitness_level && ishuman(wearer) && !QDELETED(wearer) && (body_zone in GLOB.garment_fit_limbs))
		wearer.refit_worn_clothing()

#undef WORN_FIT_BODYSHAPES
#undef WORN_FIT_REDRAW
