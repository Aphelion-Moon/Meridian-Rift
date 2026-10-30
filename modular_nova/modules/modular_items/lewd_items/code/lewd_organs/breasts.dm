
/obj/item/organ/genital/breasts
	name = "breasts"
	desc = "Female milk producing organs."
	icon_state = "breasts"
	icon = 'modular_nova/master_files/icons/obj/genitals/breasts.dmi'
	genital_type = "pair"
	mutantpart_key = ORGAN_SLOT_BREASTS
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_BREASTS
	genital_location = CHEST
	drop_when_organ_spilling = FALSE
	bodypart_overlay = /datum/bodypart_overlay/mutant/genital/breasts
	internal_fluid_datum = /datum/reagent/consumable/breast_milk
	var/lactates = FALSE
	/// Built from a pec accessory: the chest is muscle, and interactions and examine text say "pecs".
	var/pecs = FALSE
	/// Pecs drawn without nipples, which read an interaction's nippleless text where it has some.
	var/nippleless = FALSE
	/// Cycles still to come in the pecs' current flex.
	var/bounce_cycles_left = 0
	/// Timer for the flex's next cycle.
	var/bounce_timer

/datum/bodypart_overlay/mutant/genital/breasts
	feature_key = ORGAN_SLOT_BREASTS
	layers = list(
		EXTERNAL_FRONT_UNDER_CLOTHES = BREASTS_LAYER,
		// The back of a chest that shows from behind, like bigger pecs: under clothing whatever the chest's layering. Shapes without an ADJ state draw nothing here.
		EXTERNAL_ADJACENT = BODY_ADJ_LAYER,
		EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
	)
	offset_location = ENTIRE_BODY
	genital_stack_rank = 1
	/// The sheet the chest animates from (a jiggle or a pec flex), or null while it's still. See the shape's get_special_icon().
	var/animation_icon
	/// While the back layer is drawn, whether its body takes skin tones; null otherwise. See get_base_icon_state().
	var/back_on_skin_tone
	/// While the chest is drawn or keyed, whether it draws its pecs' nippleless twin (nipples_covered()). See get_base_icon_state().
	var/draws_nippleless = FALSE

/obj/item/organ/genital/breasts/get_description_string(datum/sprite_accessory/genital/breasts/breasts)
	if(pecs)
		return "You see a pair of [(breasts.pecs_flags & PECS_LARGE) ? "big, heavy" : "firm"] pecs."
	var/returned_string = "You see a [LOWER_TEXT(get_genital_descriptor(breasts))] of breasts."
	var/size_description
	var/translation = breasts_size_to_cup(genital_size)
	switch(translation)
		if(BREAST_SIZE_FLATCHESTED)
			size_description = " They are small and flat, however."
		if(BREAST_SIZE_HUGE, BREAST_SIZE_GIGANTIC, BREAST_SIZE_ENORMOUS, BREAST_SIZE_MASSIVE, BREAST_SIZE_IMPOSSIBLE, BREAST_SIZE_BEYOND_MEASUREMENT)
			size_description = " They are beyond the concept of cup-sizes, you estimate they're around [genital_size] inches in diameter."
		else
			size_description = " You estimate they are [translation]-cups."
	returned_string += size_description
	if(aroused == AROUSAL_FULL)
		if(lactates)
			returned_string += " The nipples seem hard, perky and are leaking milk."
		else
			returned_string += " Their nipples look hard and perky."
	return returned_string

/obj/item/organ/genital/breasts/update_genital_icon_state()
	var/max_size = 5
	var/current_size = floor(genital_size)
	if(current_size < 0)
		current_size = 0
	else if (current_size > max_size)
		current_size = max_size
	var/passed_string = "breasts_pair_[current_size]"
	if(uses_skintones)
		passed_string += "_s"
	icon_state = passed_string

/obj/item/organ/genital/breasts/get_sprite_size_string()
	var/current_size = floor(genital_size)
	current_size = clamp(current_size, 0, max_sprite_size_affix)
	var/passed_string = "[genital_type]_[current_size]"
	if(uses_skintones)
		passed_string += "_s"
	return passed_string

/obj/item/organ/genital/breasts/build_from_dna(datum/dna/DNA, associated_key)
	lactates = DNA.features["breasts_lactation"]
	uses_skin_color = DNA.features["breasts_uses_skincolor"]
	genital_size = DNA.features["breasts_size"]
	var/breasts_capacity = 0
	var/size = 0.5
	if(DNA.features["breasts_size"] > 0)
		size = DNA.features["breasts_size"]

	switch(genital_type)
		if("pair")
			breasts_capacity = 2
		if("quad")
			breasts_capacity = 2.5
		if("sextuple")
			breasts_capacity = 3
	internal_fluid_maximum = size * breasts_capacity * 60 // This seems like it could balloon drastically out of proportion with larger breast sizes.

	return ..()

/obj/item/organ/genital/breasts/build_from_accessory(datum/sprite_accessory/genital/breasts/accessory, datum/dna/DNA)
	uses_skintones = DNA.features["breasts_uses_skintones"] ? accessory.has_skintone_shading : FALSE
	pecs = !!(accessory.pecs_flags & PECS_SHAPE)
	nippleless = pecs && !(accessory.pecs_flags & PECS_NIPPLES)
	return ..()

// Pecs are muscle: underclothes draw over them.
/obj/item/organ/genital/breasts/shapes_body()
	return pecs

/datum/bodypart_overlay/mutant/genital/breasts/get_global_feature_list()
	return SSaccessories.sprite_accessories[ORGAN_SLOT_BREASTS]

/datum/bodypart_overlay/mutant/genital/breasts/get_overlay(obj/item/bodypart/limb, layer_index, layer_real)
	draws_nippleless = nipples_covered(limb)
	if(layer_index == EXTERNAL_ADJACENT)
		back_on_skin_tone = !!limb?.skin_tone
	. = ..()
	back_on_skin_tone = null
	draws_nippleless = FALSE

// The limb icon cache keys the chest by the state it draws.
/datum/bodypart_overlay/mutant/genital/breasts/icon_render_key(obj/item/bodypart/limb)
	draws_nippleless = nipples_covered(limb)
	. = ..()
	draws_nippleless = FALSE

/**
 * Whether the chest draws its pecs' nippleless twin: pecs with nipples, drawn in their normal layers under the underclothes
 * that cover them, which the nipples would show through.
 *
 * Arguments:
 * - limb: The chest drawn on.
 */
/datum/bodypart_overlay/mutant/genital/breasts/proc/nipples_covered(obj/item/bodypart/limb)
	var/datum/sprite_accessory/genital/breasts/shape = sprite_datum
	if(!(shape?.pecs_flags & PECS_SHAPE) || !(shape.pecs_flags & PECS_NIPPLES) || !ishuman(limb?.owner))
		return FALSE
	var/mob/living/carbon/human/owner = limb.owner
	var/obj/item/organ/genital/breasts/chest = owner.organs_slot[ORGAN_SLOT_BREASTS]
	return chest?.bodypart_overlay == src && chest.get_effective_layer_mode() == GENITAL_LAYER_NORMAL && chest.covered_by_underclothes(owner)

// The back is skin, so it shades for its body whatever shading the chest uses: "_s" on a skin-tone body, plain on any other.
// Pecs under underclothes draw their nippleless twin.
/datum/bodypart_overlay/mutant/genital/breasts/get_base_icon_state()
	. = ..()
	if(draws_nippleless)
		var/shape_state = sprite_datum.icon_state
		. = "[shape_state]_nippleless[copytext(., length(shape_state) + 1)]"
	if(isnull(back_on_skin_tone))
		return
	if(copytext(., -2) == "_s")
		. = copytext(., 1, -2)
	if(back_on_skin_tone)
		. += "_s"

// The back is skin: it takes the body's colour, whatever colour the chest itself is drawn in.
/datum/bodypart_overlay/mutant/genital/breasts/color_images(list/image/overlays, obj/item/bodypart/limb, layer_index)
	. = ..()
	if(layer_index != EXTERNAL_ADJACENT || !limb?.draw_color)
		return
	for(var/image/back as anything in overlays)
		back.color = limb.draw_color

/obj/item/organ/genital/breasts/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	stop_bounce()

/// Why the breasts can't jiggle right now, said to their owner, or null if they can.
/obj/item/organ/genital/breasts/proc/bounce_blocker()
	var/mob/living/carbon/human/human_owner = owner
	if(!istype(human_owner))
		return "You have nothing to bounce."
	var/datum/sprite_accessory/genital/breasts/shape = get_shape()
	// A flat chest has nothing to bounce. Pecs always do, whatever size was saved with them.
	if(!shape?.jiggle_icon || (!pecs && floor(genital_size) < 1))
		return "You have nothing there to bounce."
	if(IS_UNCONSCIOUS_OR_CRIT(human_owner) || human_owner.body_position != STANDING_UP)
		return "You need to be on your feet."
	if(human_owner.combat_mode)
		return "Not while you're ready for a fight."
	if(!is_exposed())
		return "Your chest needs to be bare."
	return null

/// Why the pecs can't flex right now, said to their owner, or null if they can. Clothes don't stop a flex.
/obj/item/organ/genital/breasts/proc/flex_blocker()
	var/mob/living/carbon/human/human_owner = owner
	if(!istype(human_owner) || !pecs)
		return "You have no pecs to bounce."
	if(IS_UNCONSCIOUS_OR_CRIT(human_owner) || human_owner.body_position != STANDING_UP)
		return "You need to be on your feet."
	return null

/// Draws the chest jiggling, or back on its still sprites, as a bounce (/datum/status_effect/bouncing) asks. A pec flex
/// playing keeps its own sheet.
/obj/item/organ/genital/breasts/proc/set_jiggling(jiggling)
	var/sheet = get_shape()?.jiggle_icon
	if(!jiggling)
		if(is_playing(sheet))
			set_animation_icon(null)
	else if(!is_bouncing())
		set_animation_icon(sheet)

/// Flexes the pecs for `duration`: together, or taking turns if `alternating`, and held longer if `slow`.
/// Returns FALSE if they can't right now.
/obj/item/organ/genital/breasts/proc/start_flex(alternating = FALSE, slow = FALSE, duration = BREAST_BOUNCE_DEFAULT_DURATION)
	if(flex_blocker())
		return FALSE
	play_animation(flex_sheet(alternating, slow), duration)
	return TRUE

/// Draws the chest from `sheet` for `duration`, in whole cycles.
/obj/item/organ/genital/breasts/proc/play_animation(sheet, duration)
	if(bounce_timer)
		deltimer(bounce_timer)
	bounce_cycles_left = max(1, round(min(duration, BREAST_BOUNCE_MAX_DURATION) / BREAST_BOUNCE_CYCLE, 1))
	set_animation_icon(sheet)
	bounce_cycle()

/// One cycle of the flex, then the next while there's time left and nothing stops it.
/obj/item/organ/genital/breasts/proc/bounce_cycle()
	bounce_timer = null
	if(bounce_cycles_left <= 0 || flex_blocker())
		stop_bounce()
		return
	bounce_cycles_left--
	bounce_timer = addtimer(CALLBACK(src, PROC_REF(bounce_cycle)), BREAST_BOUNCE_CYCLE, TIMER_STOPPABLE)

/// Ends a pec flex, or any animation, settling the chest back onto its still sprites.
/obj/item/organ/genital/breasts/proc/stop_bounce()
	bounce_cycles_left = 0
	if(bounce_timer)
		deltimer(bounce_timer)
		bounce_timer = null
	set_animation_icon(null)

/// Whether the chest is animating right now, from any sheet.
/obj/item/organ/genital/breasts/proc/is_bouncing()
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = bodypart_overlay
	return !isnull(overlay.animation_icon)

/// Whether the chest is animating from `sheet` right now.
/obj/item/organ/genital/breasts/proc/is_playing(sheet)
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = bodypart_overlay
	return sheet && overlay.animation_icon == sheet

/// The sheet a pec flex plays from, which holds every pec shape; null when the chest isn't pecs.
/obj/item/organ/genital/breasts/proc/flex_sheet(alternating, slow)
	if(!pecs)
		return null
	if(alternating)
		return slow ? BREASTS_ICON_PEC_BOUNCE_ALTERNATE_SLOW : BREASTS_ICON_PEC_BOUNCE_ALTERNATE
	return slow ? BREASTS_ICON_PEC_BOUNCE_SLOW : BREASTS_ICON_PEC_BOUNCE

/// The breast shape the chest is drawn with.
/obj/item/organ/genital/breasts/proc/get_shape()
	RETURN_TYPE(/datum/sprite_accessory/genital/breasts)
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = bodypart_overlay
	return overlay.sprite_datum

/// Swaps the sheet the chest draws from, redrawing the chest when it changes.
/obj/item/organ/genital/breasts/proc/set_animation_icon(sheet)
	var/datum/bodypart_overlay/mutant/genital/breasts/overlay = bodypart_overlay
	if(overlay.animation_icon == sheet)
		return
	overlay.animation_icon = sheet
	owner?.update_body_parts()

/obj/item/organ/genital/breasts/proc/breasts_size_to_cup(number)
	if(number < 0)
		number = 0
	var/returned = GLOB.breast_size_translation["[number]"]
	if(!returned)
		returned = BREAST_SIZE_BEYOND_MEASUREMENT
	return returned

/obj/item/organ/genital/breasts/proc/breasts_cup_to_size(cup)
	for(var/key in GLOB.breast_size_translation)
		if(GLOB.breast_size_translation[key] == cup)
			return text2num(key)
	return 0
