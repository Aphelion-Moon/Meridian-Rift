/**
 * The deep fried Mars bar's fat. It clears from the blood over several minutes, so bars eaten minutes apart still
 * add up. Pushing it past the overdose threshold strains the heart: a lump when it crosses, then more for every unit
 * that arrives above it, so the damage follows how far over the limit the eater goes, not how long the fat lingers.
 */
/datum/reagent/consumable/nutriment/fat/saturated
	name = "Saturated Fat"
	description = "Fat that settles in. Too much at once is hard on the heart."
	taste_description = "grease"
	chemical_flags = NONE
	randomized_spawns = REAGENT_SPAWN_NO_RANDOM
	// It lingers in the blood, so any nutrition would count many times over toward fullness.
	nutriment_factor = 0
	metabolization_rate = 0.05 * REAGENTS_METABOLISM
	// Food reagents are half pure, which halves this in the blood: the overdose starts at 9u.
	overdose_threshold = 18
	/// The most fat this blood has held since the overdose started
	var/peak_volume = 0

/datum/reagent/consumable/nutriment/fat/saturated/overdose_start(mob/living/affected_mob, metabolization_ratio)
	to_chat(affected_mob, span_warning("Your chest tightens. That last deep fried Mars bar may have been one too many."))
	peak_volume = volume
	if(affected_mob.adjust_organ_loss(ORGAN_SLOT_HEART, 15 + 5 * (volume - overdose_threshold), required_organ_flag = affected_organ_flags))
		return UPDATE_MOB_HEALTH

/datum/reagent/consumable/nutriment/fat/saturated/overdose_process(mob/living/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(volume <= peak_volume)
		return
	var/new_fat = volume - peak_volume
	peak_volume = volume
	if(affected_mob.adjust_organ_loss(ORGAN_SLOT_HEART, 5 * new_fat, required_organ_flag = affected_organ_flags))
		return UPDATE_MOB_HEALTH
