/datum/sprite_accessory/clothing
	/// How this style is redrawn over fitness limbs and pecs drawn under it, a GARMENT_FIT_* define, or null to draw it as it is
	/// on every body.
	var/fit_mode = GARMENT_FIT_SOLID

/**
 * Returns this style's sprite as make_appearance() draws it on `wearer`, fitted to their fitness limbs and to pecs drawn under
 * it: a cached resource. Null to draw it as it is: on a Normal-sized body with no pecs under it (its garment_fit is null), a
 * style that isn't fitted, worn by nobody, like a mannequin's, a fit that leaves it as it is, or one still being made by
 * SSgarment_fitting, which draws the body again once it's done (GARMENT_FITS_DEFERRED; a dummy's fits are made as it's drawn).
 *
 * The legs are fitted through their digitigrade templates where the legs drawn are digitigrade art: a "_d" state (a style with
 * has_custom_digi_sprite) or the GAGS digitigrade mask (digi_icon_state). A plantigrade state on a digitigrade body is fitted
 * as the human legs it draws, and a taur body's legs aren't fitted. A style worn over the chest is also fitted to pecs drawn
 * under it (pecs_under_underclothes()), and while they flex, animated with them (/datum/garment_fit_job/underclothes/flex). Its
 * fits over those pecs flexing, one for each pec flex sheet, are queued the first time it's drawn over them and made in the
 * background, so it moves from their first flex on; a flex that comes before its fit is made draws the still fit meanwhile.
 * On a dummy, or with GARMENT_FITS_DEFERRED off, nothing is queued ahead: each is made as the flex that first needs it draws.
 *
 * Each fit is made once a round, and cached by the fit and the style's state, cut and mask.
 *
 * Arguments:
 * - wearer: Who wears the style, if anyone.
 * - bodyshape: The body shape it's drawn for, as make_appearance() has it.
 * - icon_state_to_use: The state it's drawn from.
 * - cut: The female cut's flags, or a false value for none.
 * - digitigrade_mask: Whether the GAGS digitigrade mask draws its legs.
 */
/datum/sprite_accessory/clothing/proc/fitted_sprite(mob/living/carbon/human/wearer, bodyshape, icon_state_to_use, cut, digitigrade_mask)
	if(!fit_mode || !ishuman(wearer))
		return null
	var/datum/garment_fit/fit = wearer.garment_fit
	if(fit && (bodyshape & BODYSHAPE_DIGITIGRADE) && (has_custom_digi_sprite || digi_icon_state))
		fit = fit.digitigrade
	var/datum/garment_fit/flex_fit
	var/obj/item/organ/genital/breasts/chest = wearer.organs_slot[ORGAN_SLOT_BREASTS]
	if(chest?.pecs && garment_covers_chest() && chest.pecs_under_underclothes())
		var/datum/sprite_accessory/genital/breasts/shape = chest.get_shape()
		if(shape?.garment_fit_shape)
			fit ||= get_garment_fit()
			fit = fit.over_pecs(shape)
			var/datum/bodypart_overlay/mutant/genital/breasts/overlay = chest.bodypart_overlay
			if(overlay.animation_icon && garment_pec_flex(overlay.animation_icon))
				flex_fit = fit.flexing(overlay.animation_icon)
	if(!fit)
		return null
	var/static/alist/fitted_sprites = alist()
	cut ||= 0
	var/variant = (cut << 1) | !!digitigrade_mask
	// A list drops a null key, and a fit cached under one would never be found.
	var/state_key = icon_state_to_use || ""
	if(flex_fit)
		var/flexed = fitted_sprites[flex_fit]?[src]?[state_key]?[variant]
		if(isnull(flexed))
			var/datum/garment_fit_job/underclothes/flex/job = new(garment_fit_cache_slot(fitted_sprites, flex_fit, src, state_key), variant, flex_fit, src, icon_state_to_use, cut, digitigrade_mask)
			flexed = job.start(wearer, GARMENT_FIT_REDRAW_UNDERCLOTHES)
		if(isfile(flexed))
			return flexed
	var/fitted = fitted_sprites[fit]?[src]?[state_key]?[variant]
	if(isnull(fitted))
		var/datum/garment_fit_job/underclothes/job = new(garment_fit_cache_slot(fitted_sprites, fit, src, state_key), variant, fit, src, icon_state_to_use, cut, digitigrade_mask)
		fitted = job.start(wearer, GARMENT_FIT_REDRAW_UNDERCLOTHES)
	else if(istype(fitted, /datum/garment_fit_job))
		var/datum/garment_fit_job/job = fitted
		job.wait(wearer, GARMENT_FIT_REDRAW_UNDERCLOTHES)
#ifdef GARMENT_FITS_DEFERRED
	// Its fits over these pecs flexing from each sheet, queued behind the still one and made before a flex asks for them, so
	// the top moves from the first flex on. Nobody waits for them; a dummy would make all four on every draw.
	if(fit.pec_shape && !istype(wearer, /mob/living/carbon/human/dummy))
		for(var/flex_sheet in list(BREASTS_ICON_PEC_BOUNCE, BREASTS_ICON_PEC_BOUNCE_ALTERNATE, BREASTS_ICON_PEC_BOUNCE_SLOW, BREASTS_ICON_PEC_BOUNCE_ALTERNATE_SLOW))
			flex_fit = fit.flexing(flex_sheet)
			if(isnull(fitted_sprites[flex_fit]?[src]?[state_key]?[variant]))
				SSgarment_fitting.add(new /datum/garment_fit_job/underclothes/flex(garment_fit_cache_slot(fitted_sprites, flex_fit, src, state_key), variant, flex_fit, src, icon_state_to_use, cut, digitigrade_mask))
#endif
	return isfile(fitted) ? fitted : null

/**
 * Whether this style is worn over the chest, so pecs drawn under it shape it: an undershirt or a bra always, other underclothes
 * when they hide breasts, as /obj/item/organ/genital/proc/covered_by_underclothes() has it.
 */
/datum/sprite_accessory/clothing/proc/garment_covers_chest()
	return hides_breasts

/datum/sprite_accessory/clothing/undershirt/garment_covers_chest()
	return TRUE

/datum/sprite_accessory/clothing/bra/garment_covers_chest()
	return TRUE

/**
 * Whether this top hangs straight over pecs drawn under it: its front and back panels stay as drawn, and the pecs show where
 * they reach past them, at the armholes. Its front view still shades their lower curve, and its side views still cover their
 * bulge. Otherwise its chest panel moves out over them (/datum/garment_fit_view/proc/fit_pecs()). A proc rather than a var,
 * as garment_covers_chest() is: a style opts in by overriding it.
 */
/datum/sprite_accessory/clothing/proc/hangs_straight_over_pecs()
	return FALSE

/**
 * Whether this top leaves the near forearm bare below its sleeve in its side views, edged by a strip of cloth at the back,
 * as the polo shirts do. Fitted over a bigger arm, the forearm then shows at that arm's own width
 * (/datum/garment_fit_view/proc/bare_near_forearm()); otherwise the strip moves out across it as a sleeve's hem would, and
 * the forearm looks thin. Only the polos opt in (Pol, 2026-10-14): other shirts keep their fit. A proc, as
 * hangs_straight_over_pecs() is.
 */
/datum/sprite_accessory/clothing/proc/bares_near_forearm()
	return FALSE

/**
 * Whether these are pecs drawn under the underclothes worn over them, which are then fitted to them: pecs whose visibility lets
 * them draw, layered under the underclothes. A uniform or suit that hides them isn't asked about: it covers the underclothes'
 * chest too, and this way the fit doesn't change as one comes and goes.
 */
/obj/item/organ/genital/breasts/proc/pecs_under_underclothes()
	if(!pecs || (visibility_preference != GENITAL_HIDDEN_BY_CLOTHES && visibility_preference != GENITAL_CUSTOM))
		return FALSE
	var/layer_mode = get_effective_layer_mode()
	return layer_mode == GENITAL_LAYER_NORMAL || layer_mode == GENITAL_LAYER_BELOW_UNDIES

// A pec flex starting or stopping redraws the underclothes with the chest, so a top over the pecs starts and stops moving with
// them, in step (fitted_sprite()).
/obj/item/organ/genital/breasts/set_animation_icon(sheet)
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = bodypart_overlay
	if(!owner || overlay.animation_icon == sheet || !(garment_pec_flex(overlay.animation_icon) || garment_pec_flex(sheet)))
		return ..()
	overlay.animation_icon = sheet
	owner.update_body()

/datum/sprite_accessory/genital/breasts
	/// The shape tops are fitted to over these pecs, as the pec templates name it, or null for a chest they aren't fitted to.
	var/garment_fit_shape

/datum/sprite_accessory/genital/breasts/pecs
	garment_fit_shape = "pecs"

/datum/sprite_accessory/genital/breasts/pecs/big
	garment_fit_shape = "pecs_big"

/datum/sprite_accessory/genital/breasts/pecs/biggest
	garment_fit_shape = "pecs_biggest"

// Mesh keeps its rhythm, and rope its gaps.
/datum/sprite_accessory/clothing/bra/fishnet_base
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/bra/fishnet_sleeves
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/bra/shibari_sleeves
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/socks/fishnet_knee
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/socks/fishnet_thigh
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/socks/fishnet_thigh_sr
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/socks/stockings_fishnet
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/undershirt/nova/fishnet_base
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/undershirt/nova/fishnet_sleeves
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/undershirt/nova/fishnet_crew_base
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/undershirt/nova/fishnet_crew_sleeves
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/underwear/fishnet_lower
	fit_mode = GARMENT_FIT_PATTERN

// Plain long sleeves take the arms' shape.
/datum/sprite_accessory/clothing/undershirt/nova/buttondown
	fit_mode = GARMENT_FIT_SHADED_SLEEVES

/datum/sprite_accessory/clothing/undershirt/nova/buttondown/short_sleeve
	fit_mode = GARMENT_FIT_SOLID

/datum/sprite_accessory/clothing/undershirt/nova/longsleeve
	fit_mode = GARMENT_FIT_SHADED_SLEEVES

/datum/sprite_accessory/clothing/undershirt/nova/striped
	fit_mode = GARMENT_FIT_SHADED_SLEEVES

/datum/sprite_accessory/clothing/undershirt/nova/turtleneck/smooth
	fit_mode = GARMENT_FIT_SHADED_SLEEVES

// Ribbed knit sleeves.
/datum/sprite_accessory/clothing/undershirt/nova/leotard/turtleneck
	fit_mode = GARMENT_FIT_KNIT

/datum/sprite_accessory/clothing/undershirt/nova/leotard/turtleneck/sleeveless
	fit_mode = GARMENT_FIT_SOLID

/datum/sprite_accessory/clothing/undershirt/nova/turtleneck
	fit_mode = GARMENT_FIT_KNIT

/datum/sprite_accessory/clothing/undershirt/nova/turtleneck/sleeveless
	fit_mode = GARMENT_FIT_SOLID

// Tank tops hang straight, the pecs peeking out at the armholes.
/datum/sprite_accessory/clothing/undershirt/tank_black/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tankfire/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tank_grey/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/female_midriff/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tank_red/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tankstripe/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tank_white/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tanktop/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/tanktop_midriff/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/nova/tanktop_midriff_alt/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/nova/tank_top_rainbow/hangs_straight_over_pecs()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/nova/tank_top_sun/hangs_straight_over_pecs()
	return TRUE

// Polos show the forearm below the sleeve at the arm's own width.
/datum/sprite_accessory/clothing/undershirt/bluepolo/bares_near_forearm()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/grayyellowpolo/bares_near_forearm()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/redpolo/bares_near_forearm()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/whitepolo/bares_near_forearm()
	return TRUE

/datum/sprite_accessory/clothing/undershirt/nova/polo/bares_near_forearm()
	return TRUE
