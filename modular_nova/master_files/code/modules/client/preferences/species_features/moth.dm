/// Moths grow a second pair of arms from the chest; this lets one go without, as moths did before
/datum/preference/toggle/moth_extra_arms
	savefile_key = "moth_extra_arms"
	savefile_identifier = PREFERENCE_CHARACTER
	category = PREFERENCE_CATEGORY_SECONDARY_FEATURES
	priority = PREFERENCE_PRORITY_LATE_BODY_TYPE
	default_value = TRUE
	can_randomize = FALSE

/datum/preference/toggle/moth_extra_arms/has_relevant_feature(datum/preferences/preferences)
	return ispath(preferences.read_preference(/datum/preference/choiced/species), /datum/species/moth)

/datum/preference/toggle/moth_extra_arms/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	target.dna.features[FEATURE_MOTH_TWO_ARMS] = !value // a moth chest asks the DNA as it attaches, so a new body keeps the choice
	var/obj/item/bodypart/chest/moth/chest = target.get_bodypart(BODY_ZONE_CHEST)
	if(istype(chest))
		chest.update_extra_arms()
