/obj/item/organ/tail/taur
	name = "taur tail"
	desc = "The tail of a tauric body. It is not meant to come off."
	organ_flags = parent_type::organ_flags | ORGAN_UNREMOVABLE
	restyle_flags = NONE
	sprite_accessory_flags = SPRITE_ACCESSORY_WAG_ABLE
	// Removing an organ strips its key from the DNA, which must never take the taur's entry with it.
	mutantpart_key = null
	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/taur

/obj/item/organ/tail/taur/on_mob_insert(mob/living/carbon/receiver, special, movement_flags)
	. = ..()
	var/obj/item/organ/taur_body/body = receiver.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR)
	var/datum/bodypart_overlay/mutant/tail/taur/tail_overlay = bodypart_overlay
	tail_overlay.body_overlay = body?.bodypart_overlay

/obj/item/organ/tail/taur/on_mob_remove(mob/living/carbon/organ_owner, special, movement_flags)
	. = ..()
	var/datum/bodypart_overlay/mutant/tail/taur/tail_overlay = bodypart_overlay
	tail_overlay.body_overlay = null

/datum/bodypart_overlay/mutant/tail/taur
	feature_key = FEATURE_TAUR
	// The taur body's layers, so tail art can sit on any of them.
	layers = list(
		EXTERNAL_FRONT = BODY_FRONT_LAYER,
		EXTERNAL_ADJACENT = BODY_ADJ_LAYER,
		EXTERNAL_BEHIND = BODY_BEHIND_LAYER,
		EXTERNAL_FRONT_UNDER_CLOTHES = UNDER_UNIFORM_LAYER,
		EXTERNAL_FRONT_OVER = ABOVE_BODY_FRONT_HEAD_LAYER,
	)
	dyable = FALSE
	/// The overlay of the taur body this tail grew from. Its pose picks the tail's states.
	var/datum/bodypart_overlay/mutant/taur_body/body_overlay

/datum/bodypart_overlay/mutant/tail/taur/get_global_feature_list()
	return SSaccessories.sprite_accessories[FEATURE_TAUR]

/datum/bodypart_overlay/mutant/tail/taur/get_feature_key_for_overlay()
	return sprite_datum?.feature_key_override || feature_key

/datum/bodypart_overlay/mutant/tail/taur/get_base_icon_state()
	var/body_state = body_overlay?.get_base_icon_state() || sprite_datum.icon_state
	return "[body_state]_[wagging ? "wagging" : ""]tail"

/datum/bodypart_overlay/mutant/tail/taur/can_draw_on_bodypart(obj/item/bodypart/bodypart_owner, mob/living/carbon/owner)
	var/datum/sprite_accessory/taur/taur = sprite_datum
	return !isnull(taur?.tail_icon) && ..()
