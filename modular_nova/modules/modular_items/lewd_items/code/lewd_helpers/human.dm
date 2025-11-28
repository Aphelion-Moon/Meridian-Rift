/mob/living/carbon/human
	var/arousal = 0
	var/pleasure = 0
	var/pain = 0

	var/pain_limit = 0
	var/arousal_status = AROUSAL_NONE

	// Add variables for slots to the human class
	var/obj/item/vagina = null
	var/obj/item/anus = null
	var/obj/item/nipples = null
	var/obj/item/penis = null

/// Gets the item held in one of our `ORGAN_SLOT_*` lewd slots.
/mob/living/carbon/human/proc/get_lewd_slot_item(slot)
	switch(slot)
		if(ORGAN_SLOT_VAGINA)
			return vagina
		if(ORGAN_SLOT_ANUS)
			return anus
		if(ORGAN_SLOT_NIPPLES)
			return nipples
		if(ORGAN_SLOT_PENIS)
			return penis

/// Sets an item in one of our `ORGAN_SLOT_*` lewd slots. Returns FALSE when the slot isn't supported.
/mob/living/carbon/human/proc/set_lewd_slot_item(slot, obj/item/new_item)
	switch(slot)
		if(ORGAN_SLOT_VAGINA)
			vagina = new_item
		if(ORGAN_SLOT_ANUS)
			anus = new_item
		if(ORGAN_SLOT_NIPPLES)
			nipples = new_item
		if(ORGAN_SLOT_PENIS)
			penis = new_item
		else
			return FALSE
	return TRUE

/// Whether a portal can physically reach the selected organ, mouth, active hand, or leg.
/mob/living/carbon/human/proc/portal_target_is_accessible(target_part)
	if(target_part in list(ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS))
		var/obj/item/organ/genital/genital = get_organ_slot(target_part)
		if(!genital || genital.covered_by_clothing(src))
			return FALSE
		if(target_part == ORGAN_SLOT_PENIS)
			var/obj/item/organ/genital/penis/penis = genital
			return !penis.is_sheathed()
		return TRUE
	if(target_part == BODY_ZONE_PRECISE_MOUTH)
		return !!get_bodypart(BODY_ZONE_HEAD) && is_location_accessible(BODY_ZONE_PRECISE_MOUTH)
	if(target_part in list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
		var/obj/item/bodypart/active_hand = has_hand_for_held_index(active_hand_index)
		return active_hand && active_hand.body_zone == target_part
	if(target_part in list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG))
		var/obj/item/bodypart/leg = get_bodypart(target_part)
		return leg && !leg.bodypart_disabled
	return FALSE


/*
*	This code needed to determine if the human is naked in that part of body or not
*	You can use this for your own stuff if you want, haha.
*/

/// Are we wearing something that covers our chest?
/mob/living/carbon/human/proc/is_topless()
	return (!(wear_suit) || !(wear_suit.body_parts_covered & CHEST)) && (!(w_uniform) || !(w_uniform.body_parts_covered & CHEST))

/// Are we wearing something that covers our groin?
/mob/living/carbon/human/proc/is_bottomless()
	return (!(wear_suit) || !(wear_suit.body_parts_covered & GROIN)) && (!(w_uniform) || !(w_uniform.body_parts_covered & GROIN))

/// Are we wearing something that covers our shoes?
/mob/living/carbon/human/proc/is_barefoot()
	return (!(wear_suit) || !(wear_suit.body_parts_covered & GROIN)) && (!(shoes) || !(shoes.body_parts_covered & FEET))

/mob/living/carbon/human/proc/is_hands_uncovered()
	return (gloves?.body_parts_covered & ARMS)

/mob/living/carbon/human/proc/is_head_uncovered()
	return (head?.body_parts_covered & HEAD)

/**
 * Both preferences a portal needs before it will act on, relay, or reveal this mob.
 *
 * Portals put someone's body somewhere they can't see, so the sex-toy pref is required on top of the master ERP one.
 * Silent by design: portal code revalidates this constantly, and `check_erp_prefs()` is the one to reach for when a
 * single deliberate attempt is worth logging.
 */
/mob/proc/allows_portal_use()
	var/datum/client_interface/portal_client = GET_CLIENT(src)
	return portal_client?.prefs?.read_preference(/datum/preference/toggle/erp) \
		&& portal_client.prefs.read_preference(/datum/preference/toggle/erp/sex_toy)

/// Returns true if the human has an accessible penis for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_penis(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital/genital = get_organ_slot(ORGAN_SLOT_PENIS)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return genital.visibility_preference == GENITAL_ALWAYS_SHOW || is_bottomless()
		if(REQUIRE_GENITAL_UNEXPOSED)
			return genital.visibility_preference != GENITAL_ALWAYS_SHOW && !is_bottomless()
		else
			return TRUE

/// Returns true if the human has a accessible balls for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_balls(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital/genital = get_organ_slot(ORGAN_SLOT_TESTICLES)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return genital.visibility_preference == GENITAL_ALWAYS_SHOW || is_bottomless()
		if(REQUIRE_GENITAL_UNEXPOSED)
			return genital.visibility_preference != GENITAL_ALWAYS_SHOW && !is_bottomless()
		else
			return TRUE

/// Returns true if the human has an accessible vagina for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_vagina(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital/genital = get_organ_slot(ORGAN_SLOT_VAGINA)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return genital.visibility_preference == GENITAL_ALWAYS_SHOW || is_bottomless()
		if(REQUIRE_GENITAL_UNEXPOSED)
			return genital.visibility_preference != GENITAL_ALWAYS_SHOW && !is_bottomless()
		else
			return TRUE

/// Returns true if the human has a accessible breasts for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_breasts(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital/genital = get_organ_slot(ORGAN_SLOT_BREASTS)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return genital.visibility_preference == GENITAL_ALWAYS_SHOW || is_topless()
		if(REQUIRE_GENITAL_UNEXPOSED)
			return genital.visibility_preference != GENITAL_ALWAYS_SHOW && !is_topless()
		else
			return TRUE

/// Returns true if the human has an accessible anus for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_anus(required_state = REQUIRE_GENITAL_ANY)
	if(issilicon(src))
		return TRUE
	var/obj/item/organ/genital/genital = get_organ_slot(ORGAN_SLOT_ANUS)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return genital.visibility_preference == GENITAL_ALWAYS_SHOW || is_bottomless()
		if(REQUIRE_GENITAL_UNEXPOSED)
			return genital.visibility_preference != GENITAL_ALWAYS_SHOW && !is_bottomless()
		else
			return TRUE

/// Returns true if the human has a accessible feet for the parameter, returning the number of feet the human has if they do. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_arms(required_state = REQUIRE_GENITAL_ANY)
	var/hand_count = 0
	var/covered = 0
	var/is_covered = FALSE
	for(var/obj/item/bodypart/arm/left/left_arm in bodyparts)
		hand_count++
	for(var/obj/item/bodypart/arm/right/right_arm in bodyparts)
		hand_count++
	if(get_item_by_slot(ITEM_SLOT_HANDS))
		var/obj/item/clothing/gloves/worn_gloves = get_item_by_slot(ITEM_SLOT_HANDS)
		covered = worn_gloves.body_parts_covered
	if(covered & HANDS)
		is_covered = TRUE
	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return hand_count
		if(REQUIRE_GENITAL_EXPOSED)
			if(is_covered)
				return FALSE
			else
				return hand_count
		if(REQUIRE_GENITAL_UNEXPOSED)
			if(!is_covered)
				return FALSE
			else
				return hand_count
		else
			return hand_count

/// Returns true if the human has a accessible feet for the parameter, returning the number of feet the human has if they do. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_feet(required_state = REQUIRE_GENITAL_ANY)
	var/feet_count = 0

	for(var/obj/item/bodypart/leg/left/left_leg in bodyparts)
		feet_count++
	for(var/obj/item/bodypart/leg/right/right_leg in bodyparts)
		feet_count++

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return feet_count
		if(REQUIRE_GENITAL_EXPOSED)
			if(!is_barefoot())
				return FALSE
			else
				return feet_count
		if(REQUIRE_GENITAL_UNEXPOSED)
			if(is_barefoot())
				return FALSE
			else
				return feet_count
		else
			return feet_count

/// Gets the number of feet the human has.
/mob/living/carbon/human/proc/get_num_feet()
	return has_feet(REQUIRE_GENITAL_ANY)

/// Returns true if the human has a accessible ears for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_ears(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital = get_organ_slot(ORGAN_SLOT_EARS)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return !get_item_by_slot(ITEM_SLOT_EARS)
		if(REQUIRE_GENITAL_UNEXPOSED)
			return get_item_by_slot(ITEM_SLOT_EARS)
		else
			return TRUE

/// Returns true if the human has accessible eyes for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_eyes(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital = get_organ_slot(ORGAN_SLOT_EYES)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return !get_item_by_slot(ITEM_SLOT_EYES)
		if(REQUIRE_GENITAL_UNEXPOSED)
			return get_item_by_slot(ITEM_SLOT_EYES)
		else
			return TRUE

/// Returns true if the human has accessible tail for the parameter. Accepts any of the `REQUIRE_GENITAL_` defines.
/mob/living/carbon/human/proc/has_tail(required_state = REQUIRE_GENITAL_ANY)
	var/obj/item/organ/genital = get_organ_slot(ORGAN_SLOT_TAIL)
	if(!genital)
		return FALSE

	switch(required_state)
		if(REQUIRE_GENITAL_ANY)
			return TRUE
		if(REQUIRE_GENITAL_EXPOSED)
			return !get_item_by_slot(ORGAN_SLOT_TAIL)
		if(REQUIRE_GENITAL_UNEXPOSED)
			return get_item_by_slot(ORGAN_SLOT_TAIL)
		else
			return TRUE

/*
*	This code needed for changing character's gender by chems
*/

/// Sets the gender of the human, respecting prefs unless it's forced. Do not force in non-admin operations.
/mob/living/carbon/human/proc/set_gender(ngender = NEUTER, silent = FALSE, update_icon = TRUE, forced = FALSE)
	var/bender = gender != ngender
	if((!client?.prefs?.read_preference(/datum/preference/toggle/erp/gender_change) && !forced) || !dna || !bender)
		return FALSE

	if(ngender == MALE || ngender == FEMALE)
		dna.features["body_model"] = ngender
		if(!silent)
			var/adj = ngender == MALE ? "masculine" : "feminine"
			visible_message(span_boldnotice("[src] suddenly looks more [adj]!"), span_boldwarning("You suddenly feel more [adj]!"))
	else if(ngender == NEUTER)
		dna.features["body_model"] = MALE
	gender = ngender
	if(update_icon)
		update_body()

/*
*	ICON UPDATING EXTENTION
*/

/// Updating vagina slot
/mob/living/carbon/human/proc/update_inv_vagina()
	// on_mob stuff
	remove_overlay(VAGINA_CLOTHING_LAYER)

	var/obj/item/clothing/sextoy/sex_toy = vagina

	if(wear_suit && (wear_suit.flags_inv & HIDESEXTOY)) // You can add proper flags here if required
		return

	var/icon_file = vagina?.worn_icon
	var/mutable_appearance/vagina_overlay

	if(!vagina_overlay)
		vagina_overlay = sex_toy?.build_worn_icon(default_layer = VAGINA_CLOTHING_LAYER, default_icon_file = 'icons/mob/clothing/under/default.dmi', isinhands = FALSE, override_file = icon_file)

	var/obj/item/bodypart/chest/chest_part = get_bodypart(BODY_ZONE_CHEST)
	chest_part?.worn_uniform_offset?.apply_offset(vagina_overlay) // every day we stray further and further from god
	overlays_standing[VAGINA_CLOTHING_LAYER] = vagina_overlay

	apply_overlay(VAGINA_CLOTHING_LAYER)
	update_body_parts()

/// Updating anus slot
/mob/living/carbon/human/proc/update_inv_anus()
	// on_mob stuff
	remove_overlay(ANUS_CLOTHING_LAYER)

	var/obj/item/clothing/sextoy/sex_toy = anus

	if(wear_suit && (wear_suit.flags_inv & HIDESEXTOY)) // You can add proper flags here if required
		return

	var/icon_file = anus?.worn_icon
	var/mutable_appearance/anus_overlay

	if(!anus_overlay)
		anus_overlay = sex_toy?.build_worn_icon(default_layer = ANUS_CLOTHING_LAYER, default_icon_file = 'icons/mob/clothing/under/default.dmi', isinhands = FALSE, override_file = icon_file)

	var/obj/item/bodypart/chest/chest_part = get_bodypart(BODY_ZONE_CHEST)

	chest_part?.worn_uniform_offset?.apply_offset(anus_overlay) // and i keep on asking myself... why? why do we do this?
	overlays_standing[ANUS_CLOTHING_LAYER] = anus_overlay

	apply_overlay(ANUS_CLOTHING_LAYER)
	update_body_parts()

/// Updating nipples slot
/mob/living/carbon/human/proc/update_inv_nipples()
	// on_mob stuff
	remove_overlay(NIPPLES_CLOTHING_LAYER)

	var/obj/item/clothing/sextoy/sex_toy = nipples

	if(wear_suit && (wear_suit.flags_inv & HIDESEXTOY)) // You can add proper flags here if required
		return

	var/icon_file = nipples?.worn_icon
	var/mutable_appearance/nipples_overlay

	if(!nipples_overlay)
		nipples_overlay = sex_toy?.build_worn_icon(default_layer = NIPPLES_CLOTHING_LAYER, default_icon_file = 'icons/mob/clothing/under/default.dmi', isinhands = FALSE, override_file = icon_file)

	var/obj/item/bodypart/chest/chest_part = get_bodypart(BODY_ZONE_CHEST)
	chest_part?.worn_uniform_offset?.apply_offset(nipples_overlay) // then i realised something, something horrific

	overlays_standing[NIPPLES_CLOTHING_LAYER] = nipples_overlay

	apply_overlay(NIPPLES_CLOTHING_LAYER)
	update_body_parts()

/// Updating penis slot
/mob/living/carbon/human/proc/update_inv_penis()
	// on_mob stuff
	remove_overlay(PENIS_CLOTHING_LAYER)

	var/obj/item/clothing/sextoy/sex_toy = penis

	if(wear_suit && (wear_suit.flags_inv & HIDESEXTOY)) // You can add proper flags here if required
		return

	var/icon_file = penis?.worn_icon
	var/mutable_appearance/penis_overlay

	if(!penis_overlay)
		penis_overlay = sex_toy?.build_worn_icon(default_layer = PENIS_CLOTHING_LAYER, default_icon_file = 'icons/mob/clothing/under/default.dmi', isinhands = FALSE, override_file = icon_file)

	var/obj/item/bodypart/chest/chest_part = get_bodypart(BODY_ZONE_CHEST)
	chest_part?.worn_uniform_offset?.apply_offset(penis_overlay) // we can never escape, we are forever governed by sex(two)

	overlays_standing[PENIS_CLOTHING_LAYER] = penis_overlay

	apply_overlay(PENIS_CLOTHING_LAYER)
	update_body_parts()

/// Helper proc for calling all the lewd slot update_inv_ procs.
/mob/living/carbon/human/proc/update_inv_lewd()
	update_inv_vagina()
	update_inv_anus()
	update_inv_nipples()
	update_inv_penis()

/*
*	MISC LOGIC
*/

// Handles breaking out of gloves that restrain people.
/mob/living/carbon/human/resist_restraints()
	if(gloves?.breakouttime)
		changeNext_move(gloves.resist_cooldown)
		last_special = world.time + gloves.resist_cooldown
		cuff_resist(gloves)
	else
		return ..()

/// Checks if the human is wearing a condom, and also hasn't broken it.
/mob/living/carbon/human/proc/is_wearing_condom()
	if(!penis || !istype(penis, /obj/item/clothing/sextoy/condom))
		return FALSE

	var/obj/item/clothing/sextoy/condom/condom = penis
	return condom.condom_state != "broken"

// For handling things that don't already have handcuff handlers.
/mob/living/carbon/human/set_handcuffed(new_value)
	if(wear_suit && istype(wear_suit, /obj/item/clothing/suit/straight_jacket/kinky_sleepbag))
		return FALSE
	return ..()

/// Checks if the tail is exposed.
/obj/item/organ/tail/proc/is_exposed()
	return TRUE // your tail is always exposed, dummy! why are you checking this
