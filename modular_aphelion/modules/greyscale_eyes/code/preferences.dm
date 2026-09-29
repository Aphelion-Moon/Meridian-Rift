/// Declares `eyes_type`, the eyes these preferences give a character: their Augments+ pick, or else their species' own.
#define PREFERENCES_EYES_TYPE(preferences) \
	var/datum/augment_item/eye_augment = GLOB.augment_items[preferences.augments?[AUGMENT_SLOT_EYES]]; \
	var/datum/species/species = eye_augment ? null : GLOB.species_prototypes[preferences.read_preference(/datum/preference/choiced/species)]; \
	var/obj/item/organ/eyes/eyes_type = eye_augment ? eye_augment.path : species?.mutanteyes

/datum/preference/toggle/eye_greyscale
	savefile_key = "eye_greyscale"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	default_value = FALSE
	can_randomize = FALSE

/datum/preference/toggle/eye_greyscale/is_accessible(datum/preferences/preferences)
	if(!..())
		return FALSE
	PREFERENCES_EYES_TYPE(preferences)
	return eyes_type && initial(eyes_type.greyscale_icon_state)

/datum/preference/toggle/eye_greyscale/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	var/obj/item/organ/eyes/eyes = target.get_organ_slot(ORGAN_SLOT_EYES)
	if(!eyes?.greyscale_icon_state)
		return
	// An Augments+ pick replaces these eyes right after.
	if(preferences?.augments?[AUGMENT_SLOT_EYES])
		value = FALSE
	if(eyes.greyscale_sprite == value)
		return
	eyes.greyscale_sprite = value
	eyes.eye_icon_state = value ? eyes.greyscale_icon_state : initial(eyes.eye_icon_state)
	var/obj/item/bodypart/head/head = target.get_bodypart(BODY_ZONE_HEAD)
	if(eyes.greyscale_icon)
		eyes.eye_icon = value ? eyes.greyscale_icon : (head?.eyes_icon || initial(eyes.eye_icon))
	// Heads that don't colour eyes, like flies', colour greyscale ones.
	if(head && !(initial(head.head_flags) & HEAD_EYECOLOR))
		if(value)
			head.head_flags |= HEAD_EYECOLOR
		else
			head.head_flags &= ~HEAD_EYECOLOR

/datum/preference/color/eye_color/has_relevant_feature(datum/preferences/preferences)
	PREFERENCES_EYES_TYPE(preferences)
	// Eyes too dark or fixed to take a colour show it once they're greyscale, even on heads that don't colour eyes.
	// Until then it stays hidden, and still tints them as it always has.
	if(eyes_type && initial(eyes_type.greyscale_icon_state))
		return preferences.read_preference(/datum/preference/toggle/eye_greyscale)
	return ..()

#undef PREFERENCES_EYES_TYPE
