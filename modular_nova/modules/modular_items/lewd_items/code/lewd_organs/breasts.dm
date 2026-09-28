
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
	/// Cycles still to come in the chest's current animation.
	var/bounce_cycles_left = 0
	/// Timer for the next cycle.
	var/bounce_timer
	/// The current animation is a jiggle, which hops the owner each cycle and needs a bare chest. Pec flexes do neither.
	var/bounce_hops = FALSE

/datum/bodypart_overlay/mutant/genital/breasts
	feature_key = ORGAN_SLOT_BREASTS
	layers = list(
		EXTERNAL_FRONT_UNDER_CLOTHES = BREASTS_LAYER,
		EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
	)
	offset_location = ENTIRE_BODY
	genital_stack_rank = 1
	/// The sheet the chest animates from (a jiggle or a pec flex), or null while it's still. See the shape's get_special_icon().
	var/animation_icon

/obj/item/organ/genital/breasts/get_description_string(datum/sprite_accessory/genital/breasts/breasts)
	if(pecs)
		return "You see a pair of [breasts.pecs_big ? "big, heavy" : "firm"] pecs."
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
	pecs = accessory.pecs
	nippleless = accessory.pecs && !accessory.pecs_nipples
	return ..()

/datum/bodypart_overlay/mutant/genital/breasts/get_global_feature_list()
	return SSaccessories.sprite_accessories[ORGAN_SLOT_BREASTS]

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
	var/datum/sprite_accessory/genital/breasts/shape = get_shape()
	if(!istype(human_owner) || !pecs || !shape?.pec_bounce_icon)
		return "You have no pecs to bounce."
	if(IS_UNCONSCIOUS_OR_CRIT(human_owner) || human_owner.body_position != STANDING_UP)
		return "You need to be on your feet."
	return null

/// Jiggles on the spot for `duration`, in whole cycles. Returns FALSE if the breasts can't right now.
/obj/item/organ/genital/breasts/proc/start_bounce(duration = BREAST_BOUNCE_DEFAULT_DURATION)
	if(bounce_blocker())
		return FALSE
	play_animation(get_shape().jiggle_icon, duration, hops = TRUE)
	return TRUE

/// Flexes the pecs for `duration`: together, or taking turns if `alternating`. Returns FALSE if they can't right now.
/obj/item/organ/genital/breasts/proc/start_flex(alternating = FALSE, duration = BREAST_BOUNCE_DEFAULT_DURATION)
	if(flex_blocker())
		return FALSE
	play_animation(flex_sheet(alternating), duration, hops = FALSE)
	return TRUE

/// Draws the chest from `sheet` for `duration`, in whole cycles, hopping each cycle if `hops`.
/obj/item/organ/genital/breasts/proc/play_animation(sheet, duration, hops)
	if(bounce_timer)
		deltimer(bounce_timer)
	bounce_hops = hops
	bounce_cycles_left = max(1, round(min(duration, BREAST_BOUNCE_MAX_DURATION) / BREAST_BOUNCE_CYCLE, 1))
	set_animation_icon(sheet)
	bounce_cycle()

/// One cycle (two hops for a jiggle), then the next while there's time left and nothing stops it.
/obj/item/organ/genital/breasts/proc/bounce_cycle()
	bounce_timer = null
	if(bounce_cycles_left <= 0 || (bounce_hops ? bounce_blocker() : flex_blocker()))
		stop_bounce()
		return
	bounce_cycles_left--
	if(bounce_hops)
		animate(owner, pixel_z = BREAST_BOUNCE_HOP_HEIGHT, time = BREAST_BOUNCE_CYCLE / 4, easing = SINE_EASING | EASE_OUT, loop = 2, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
		animate(pixel_z = -BREAST_BOUNCE_HOP_HEIGHT, time = BREAST_BOUNCE_CYCLE / 4, easing = SINE_EASING | EASE_IN, flags = ANIMATION_RELATIVE)
	bounce_timer = addtimer(CALLBACK(src, PROC_REF(bounce_cycle)), BREAST_BOUNCE_CYCLE, TIMER_STOPPABLE)

/// Settles the chest back onto its still sprites.
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

/// The sheet a pec flex plays from, together or alternating; null for shapes that can't flex.
/obj/item/organ/genital/breasts/proc/flex_sheet(alternating)
	var/datum/sprite_accessory/genital/breasts/shape = get_shape()
	return alternating ? shape?.pec_bounce_alternate_icon : shape?.pec_bounce_icon

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
