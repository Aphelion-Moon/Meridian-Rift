/**
 * Returns the female cut a garment gets on `wearer`, as wear_female_version() takes its flags: `flags` themselves, unless the
 * wearer has pecs, which keep the torso out of it. Then only the lower body is shaped: FEMALE_UNIFORM_LOWER_ONLY where the cut
 * would take in the crotch, or null, no cut at all, where it would shape only the torso. Pecs of any shape count, whether
 * they show or not.
 *
 * Arguments:
 * - wearer: Who the garment is drawn on, if anyone.
 * - flags: The cut's flags as the garment would get them on this body without pecs.
 * - bodyshape: The body shape wear_female_version() is given with them, which keeps a cut other than FEMALE_UNIFORM_FULL off
 *   digitigrade legs.
 */
/proc/female_cut_over_pecs(mob/living/carbon/human/wearer, flags, bodyshape = NONE)
	if(!flags || !ishuman(wearer) || !wearer.has_pecs())
		return flags
	if(flags == FEMALE_UNIFORM_FULL || (!(flags & FEMALE_UNIFORM_TOP_ONLY) && !(bodyshape & BODYSHAPE_DIGITIGRADE)))
		return FEMALE_UNIFORM_LOWER_ONLY
	return null

/**
 * Returns the mask a FEMALE_UNIFORM_LOWER_ONLY cut is drawn through: masking_helpers.dmi's full cut, less the pixels its
 * torso-only cut shares with it, so it shapes the lower body alone. Made with each new cut, which wear_female_version()
 * caches.
 */
/proc/female_lower_cut_mask()
	var/icon/torso = icon('icons/mob/clothing/under/masking_helpers.dmi', "female_top")
	// The torso cut's pixels opaque white, everything else clear.
	torso.MapColors(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 1, 1, 1, 1)
	var/icon/mask = icon('icons/mob/clothing/under/masking_helpers.dmi', "female_full")
	mask.Blend(torso, ICON_UNDERLAY)
	return mask

/obj/item/organ/genital/breasts/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	redraw_female_cut(organ_owner)

/obj/item/organ/genital/breasts/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	redraw_female_cut(organ_owner)

/**
 * Draws again what the female cut shapes on a female body, its uniform and underclothes, after pecs come or go: they keep
 * its torso out of the cut (female_cut_over_pecs()). Inside a render batch, it's left to whoever ends the batch.
 *
 * Arguments:
 * - body: The body the pecs came to or left.
 */
/obj/item/organ/genital/breasts/proc/redraw_female_cut(mob/living/carbon/human/body)
	if(!pecs || !ishuman(body) || QDELETED(body) || body.physique != FEMALE || (body.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		return
	if(body.w_uniform)
		body.update_worn_undersuit()
	body.update_body()
