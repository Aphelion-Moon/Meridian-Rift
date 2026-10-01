/**
 * What redraws a bulge where the renders that draw it would not (bulge.dm). Every arousal change is followed by a
 * body update at its caller, which resolves the look again; a change of length is not, and an erection can change the
 * cut a cover is drawn with, which only that cover's own render applies (cut_cover.dm). Both are handled here,
 * synchronously, on the penis's genital-updated signal and its size setter.
 */

/obj/item/organ/genital/penis/on_mob_insert(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_HUMAN_GENITAL_UPDATED, PROC_REF(on_bulge_genital_changed), override = TRUE)

/obj/item/organ/genital/penis/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	UnregisterSignal(organ_owner, COMSIG_HUMAN_GENITAL_UPDATED)
	. = ..()
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = bodypart_overlay
	if(!istype(overlay))
		return
	var/redraw_uniform = !!overlay.bulge_uniform_cut
	var/redraw_body = !!overlay.bulge_body_cut
	overlay.bulge_clear()
	overlay.bulge_uniform_cut = null
	overlay.bulge_body_cut = null
	overlay.bulge_uncut_icon = null
	overlay.bulge_uncut_state = null
	overlay.bulge_cut_icon = null
	overlay.bulge_uncut_over = null
	// A cover cut for this penis is drawn whole again.
	if(!ishuman(organ_owner) || QDELETED(organ_owner) || (organ_owner.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		return
	var/mob/living/carbon/human/human_owner = organ_owner
	if(redraw_uniform)
		human_owner.update_worn_undersuit()
	if(redraw_body)
		human_owner.update_body()

/**
 * The penis's sprite suffix changed (an erection, a sheath, a length). A uniform whose cut no longer matches is drawn
 * again here, as only its own render cuts it; underclothes are drawn again by the body update an arousal change ends
 * with, or by the look itself (bulge_resolve()). A new length redraws the body, which its callers do not.
 */
/obj/item/organ/genital/penis/proc/on_bulge_genital_changed(datum/source, obj/item/organ/genital/changed)
	SIGNAL_HANDLER
	if(changed != src || source != owner || !ishuman(owner) || bodypart_owner?.owner != owner)
		return
	if(owner.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS)
		return
	var/datum/bodypart_overlay/mutant/genital/penis/overlay = bodypart_overlay
	if(!istype(overlay))
		return
	var/mob/living/carbon/human/human_owner = owner
	if(overlay.bulge_redraw_cuts(human_owner, overlay.bulge_wanted_cut(human_owner, UNIFORM_LAYER), overlay.bulge_body_cut))
		return // Drawing the uniform again updated the body.
	if(overlay.bulge_key && overlay.bulge_length != genital_size)
		owner.update_body_parts()

/// The bulge size follows thresholds of its own (bulge_size()): a length change the sprite suffix does not show still
/// redraws the body.
/obj/item/organ/genital/penis/set_size(size)
	var/old_size = bulge_size(genital_size)
	var/old_suffix = sprite_suffix
	. = ..()
	if(sprite_suffix != old_suffix || old_size == bulge_size(genital_size))
		return
	if(ishuman(owner) && bodypart_owner?.owner == owner && !(owner.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS))
		owner.update_body_parts()
