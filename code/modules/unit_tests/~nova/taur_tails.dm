/// Every taur with a separate tail has still and wagging tail states for each pose it can take.
/datum/unit_test/taur_tail_states

/datum/unit_test/taur_tail_states/Run()
	for(var/taur_name, taur_entry in SSaccessories.sprite_accessories[FEATURE_TAUR])
		var/datum/sprite_accessory/taur/taur = taur_entry
		if(isnull(taur.tail_icon))
			continue
		var/list/tail_states = icon_states(taur.tail_icon)
		var/list/poses = list(taur.icon_state)
		if(taur.can_lay_down)
			poses += "[taur.icon_state]_laying"
		for(var/pose in poses)
			for(var/tail_state in list("tail", "waggingtail"))
				var/prefix = "m_[taur.key]_[pose]_[tail_state]_"
				var/found = FALSE
				for(var/state in tail_states)
					if(findtext(state, prefix) == 1)
						found = TRUE
						break
				TEST_ASSERT(found, "[taur_name] has a tail_icon without any [pose]_[tail_state] states.")

/// A taur tail on a mob with no taur body falls back to its accessory's own state rather than runtiming.
/datum/unit_test/taur_tail_without_body

/datum/unit_test/taur_tail_without_body/Run()
	var/mob/living/carbon/human/consistent/dummy = allocate(__IMPLIED_TYPE__)
	dummy.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part(/datum/sprite_accessory/taur/feline::name)
	var/obj/item/organ/tail/taur/tail = new
	tail.Insert(dummy, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	var/datum/bodypart_overlay/mutant/tail/taur/tail_overlay = tail.bodypart_overlay
	var/pose = /datum/sprite_accessory/taur/feline::icon_state
	TEST_ASSERT_EQUAL(tail_overlay.get_base_icon_state(), "[pose]_tail", "A bodiless taur tail did not fall back to its accessory's state.")
	var/obj/item/bodypart/chest/chest = dummy.get_bodypart(BODY_ZONE_CHEST)
	var/drawn_states = 0
	for(var/mutable_appearance/drawn as anything in tail_overlay.get_all_overlays(chest))
		if(drawn.icon)
			drawn_states++
			TEST_ASSERT(icon_exists(drawn.icon, drawn.icon_state), "The taur tail drew missing state \"[drawn.icon_state]\".")
	TEST_ASSERT(drawn_states, "A bodiless taur tail drew nothing.")

/// A feline taur grows a wag-able tail that follows its pose, and loses it with its body.
/datum/unit_test/taur_tail_lifecycle

/datum/unit_test/taur_tail_lifecycle/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(__IMPLIED_TYPE__)
	var/obj/item/organ/tail/cat/earlier_tail = new
	earlier_tail.Insert(taur, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	var/obj/item/organ/taur_body/body = give_feline_taur(taur)

	var/obj/item/organ/tail/taur/tail = taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT(istype(tail), "The feline taur did not grow its own tail.")
	TEST_ASSERT(QDELETED(earlier_tail), "The tail the taur tail replaced was not deleted.")

	var/obj/item/bodypart/chest/chest = taur.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(chest.bodypart_overlays.Find(tail.bodypart_overlay) > chest.bodypart_overlays.Find(body.bodypart_overlay), "The taur tail draws under its body.")

	var/pose = /datum/sprite_accessory/taur/feline::icon_state
	var/datum/bodypart_overlay/mutant/tail/taur/tail_overlay = tail.bodypart_overlay
	var/datum/bodypart_overlay/mutant/taur_body/body_overlay = body.bodypart_overlay
	TEST_ASSERT_EQUAL(tail_overlay.get_base_icon_state(), "[pose]_tail", "The resting taur tail picked the wrong state.")
	TEST_ASSERT(taur.wag_tail(), "The taur tail refused to wag.")
	TEST_ASSERT_EQUAL(tail_overlay.get_base_icon_state(), "[pose]_waggingtail", "The wagging taur tail picked the wrong state.")
	body_overlay.laying_down = TRUE
	TEST_ASSERT_EQUAL(tail_overlay.get_base_icon_state(), "[pose]_laying_waggingtail", "The taur tail did not lie down with its body.")
	var/drawn_states = 0
	for(var/mutable_appearance/drawn as anything in tail_overlay.get_all_overlays(chest))
		if(drawn.icon)
			drawn_states++
			TEST_ASSERT(icon_exists(drawn.icon, drawn.icon_state), "The taur tail drew missing state \"[drawn.icon_state]\".")
	TEST_ASSERT(drawn_states, "The lying, wagging taur tail drew nothing.")
	body_overlay.laying_down = FALSE
	taur.unwag_tail()

	taur.dna.species.regenerate_organs(taur, replace_current = FALSE)
	TEST_ASSERT(istype(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/taur), "Regenerating organs lost the taur tail.")

	var/datum/mutant_bodypart/taur_part = taur.dna.mutant_bodyparts[FEATURE_TAUR]
	taur_part.name = /datum/sprite_accessory/taur/horse::name
	taur.dna.species.regenerate_organs(taur)
	TEST_ASSERT_NULL(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), "Swapping to a monolith taur left a tail behind.")

/// Choosing a taur that brings its own tail hides the tail preferences and keeps FEATURE_TAIL out of the DNA.
/datum/unit_test/taur_tail_preferences

/datum/unit_test/taur_tail_preferences/Run()
	var/datum/preferences/preferences = new(new /datum/client_interface)
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	preferences.value_cache[/datum/preference/toggle/allow_emissives] = TRUE
	preferences.value_cache[/datum/preference/toggle/mutant_toggle/tail] = TRUE
	preferences.value_cache[/datum/preference/toggle/mutant_toggle/taur] = TRUE
	preferences.value_cache[/datum/preference/choiced/mutant_choice/taur] = /datum/sprite_accessory/taur/feline::name
	var/list/tail_preferences = list(
		/datum/preference/toggle/mutant_toggle/tail,
		/datum/preference/choiced/mutant_choice/tail,
		/datum/preference/tri_color/tail,
		/datum/preference/tri_bool/tail,
	)

	for(var/preference_type in tail_preferences)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		TEST_ASSERT(!preference.is_accessible(preferences), "[preference_type] is offered alongside a taur that has its own tail.")

	var/mob/living/carbon/human/consistent/character = allocate(__IMPLIED_TYPE__)
	character.dna.mutant_bodyparts -= FEATURE_TAIL
	var/datum/preference/choiced/mutant_choice/tail/tail_choice = GLOB.preference_entries[/datum/preference/choiced/mutant_choice/tail]
	tail_choice.apply_to_human(character, /datum/sprite_accessory/tails/felinid/cat::name, preferences)
	TEST_ASSERT_NULL(character.dna.mutant_bodyparts[FEATURE_TAIL], "The tail choice was applied under a taur that has its own tail.")

	preferences.value_cache[/datum/preference/toggle/mutant_toggle/taur] = FALSE
	TEST_ASSERT(!preferences.has_taur_tail(), "A disabled taur still hides the tail preferences.")

	preferences.value_cache[/datum/preference/toggle/mutant_toggle/taur] = TRUE
	preferences.value_cache[/datum/preference/choiced/mutant_choice/taur] = /datum/sprite_accessory/taur/horse::name
	for(var/preference_type in tail_preferences)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		TEST_ASSERT(preference.is_accessible(preferences), "[preference_type] stays hidden under a monolith taur.")

/// Amputation shears and the field medic's bone saw refuse to cut off a taur tail.
/datum/unit_test/taur_tail_cannot_be_cut

/datum/unit_test/taur_tail_cannot_be_cut/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(__IMPLIED_TYPE__)
	give_feline_taur(taur)
	var/mob/living/carbon/human/consistent/surgeon = allocate(__IMPLIED_TYPE__)
	surgeon.zone_selected = BODY_ZONE_PRECISE_GROIN

	var/obj/item/shears/shears = allocate(__IMPLIED_TYPE__)
	shears.attack(taur, surgeon)
	TEST_ASSERT(istype(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/taur), "Amputation shears cut off a taur tail.")

	var/obj/item/circular_saw/field_medic/saw = allocate(__IMPLIED_TYPE__)
	saw.attack(taur, surgeon)
	TEST_ASSERT(istype(taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL), /obj/item/organ/tail/taur), "The field medic bone saw cut off a taur tail.")

/// Lying down is a pose, not a stun: a wagging taur tail keeps wagging and draws its lying wag.
/datum/unit_test/taur_tail_wags_while_lying

/datum/unit_test/taur_tail_wags_while_lying/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(__IMPLIED_TYPE__)
	give_feline_taur(taur)
	var/obj/item/organ/tail/taur/tail = taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	var/datum/bodypart_overlay/mutant/tail/taur/tail_overlay = tail.bodypart_overlay
	taur.wag_tail()

	taur.__gvb_toggle_laying()
	TEST_ASSERT(tail.wag_flags & WAG_WAGGING, "Lying down stopped the taur tail wagging.")
	var/pose = /datum/sprite_accessory/taur/feline::icon_state
	TEST_ASSERT_EQUAL(tail_overlay.get_base_icon_state(), "[pose]_laying_waggingtail", "The lying taur tail is not drawing its wag.")

/// Becoming a species with its own tail (felinid) leaves the taur's tail in place.
/datum/unit_test/taur_tail_species_change

/datum/unit_test/taur_tail_species_change/Run()
	var/mob/living/carbon/human/consistent/taur = allocate(__IMPLIED_TYPE__)
	give_feline_taur(taur)

	taur.set_species(/datum/species/human/felinid)
	var/obj/item/organ/tail/tail = taur.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAIL)
	TEST_ASSERT(istype(tail, /obj/item/organ/tail/taur), "Becoming a felinid swapped the taur's own tail for [tail?.type].")

/**
 * Makes a human a feline taur, the taur whose tail is drawn separately, and returns its taur body.
 *
 * Arguments:
 * - taur: The human to change. It must not have a taur body yet.
 */
/proc/give_feline_taur(mob/living/carbon/human/taur)
	taur.dna.mutant_bodyparts[FEATURE_TAUR] = build_mutant_part(/datum/sprite_accessory/taur/feline::name)
	var/body_type = /datum/sprite_accessory/taur/feline::organ_type
	var/obj/item/organ/taur_body/body = new body_type
	body.Insert(taur, special = TRUE, movement_flags = DELETE_IF_REPLACED)
	return body
