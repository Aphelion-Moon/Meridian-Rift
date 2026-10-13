/datum/sprite_accessory/clothing
	/// How this style is redrawn over fitness limbs and pecs drawn under it, a GARMENT_FIT_* define, or null to draw it as it is
	/// on every body.
	var/fit_mode = GARMENT_FIT_SOLID

/**
 * Returns this style's sprite as make_appearance() draws it on `wearer`, fitted to their fitness limbs and to pecs drawn under
 * it: a cached resource. Null to draw it as it is: on a body at the baseline with no pecs under it (its garment_fit is null), a
 * style that isn't fitted, worn by nobody, like a mannequin's, a fit that leaves it as it is, or one still being made by
 * SSgarment_fitting, which draws the body again once it's done (GARMENT_FITS_DEFERRED; a dummy's fits are made as it's drawn).
 *
 * The legs are fitted through their digitigrade templates where the legs drawn are digitigrade art: a "_d" state (a style with
 * has_custom_digi_sprite) or the GAGS digitigrade mask (digi_icon_state). A plantigrade state on a digitigrade body is fitted
 * as the human legs it draws, and a taur body's legs aren't fitted. A style worn over the chest is also fitted to pecs drawn
 * under it (pecs_under_underclothes()).
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
	var/obj/item/organ/genital/breasts/chest = wearer.organs_slot[ORGAN_SLOT_BREASTS]
	if(chest?.pecs && garment_covers_chest() && chest.pecs_under_underclothes())
		var/datum/sprite_accessory/genital/breasts/shape = chest.get_shape()
		if(shape?.garment_fit_shape)
			fit ||= get_garment_fit()
			fit = fit.over_pecs(shape)
	if(!fit)
		return null
	var/static/alist/fitted_sprites = alist()
	cut ||= 0
	var/variant = digitigrade_mask ? (cut | (1<<4)) : cut
	// A list drops a null key, and a fit cached under one would never be found.
	var/state_key = icon_state_to_use || ""
	var/fitted = fitted_sprites[fit]?[src]?[state_key]?[variant]
	if(isfile(fitted))
		return fitted
	if(isnull(fitted))
		var/datum/garment_fit_job/underclothes/job = new(garment_fit_cache_slot(fitted_sprites, fit, src, state_key), variant, fit, src, icon_state_to_use, cut, digitigrade_mask)
		fitted = job.start(wearer, GARMENT_FIT_REDRAW_UNDERCLOTHES)
	else if(istype(fitted, /datum/garment_fit_job))
		var/datum/garment_fit_job/job = fitted
		job.wait(wearer, GARMENT_FIT_REDRAW_UNDERCLOTHES)
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
 * Whether these are pecs drawn under the underclothes worn over them, which are then fitted to them: pecs whose visibility lets
 * them draw, layered under the underclothes. A uniform or suit that hides them isn't asked about: it covers the underclothes'
 * chest too, and this way the fit doesn't change as one comes and goes.
 */
/obj/item/organ/genital/breasts/proc/pecs_under_underclothes()
	if(!pecs || (visibility_preference != GENITAL_HIDDEN_BY_CLOTHES && visibility_preference != GENITAL_CUSTOM))
		return FALSE
	var/layer_mode = get_effective_layer_mode()
	return layer_mode == GENITAL_LAYER_NORMAL || layer_mode == GENITAL_LAYER_BELOW_UNDIES

/datum/sprite_accessory/genital/breasts
	/// The shape tops are fitted to over these pecs, as the pec templates name it, or null for a chest they aren't fitted to.
	var/garment_fit_shape

/datum/sprite_accessory/genital/breasts/pecs
	garment_fit_shape = "pecs"

/datum/sprite_accessory/genital/breasts/pecs/big
	garment_fit_shape = "pecs_big"

/datum/sprite_accessory/genital/breasts/pecs/biggest
	garment_fit_shape = "pecs_biggest"

// Mesh keeps its rhythm.
/datum/sprite_accessory/clothing/bra/fishnet_base
	fit_mode = GARMENT_FIT_PATTERN

/datum/sprite_accessory/clothing/bra/fishnet_sleeves
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
