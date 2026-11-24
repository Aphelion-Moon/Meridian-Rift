#define CLOT_RATE_INTENSITY_MULT 50

/datum/reagent/medicine/coagulant
	/// was_working, but for electrical damage
	var/was_working_synth
	process_flags = REAGENT_ORGANIC | REAGENT_SYNTHETIC

/datum/reagent/medicine/coagulant/on_mob_end_metabolize(mob/living/affected_mob)
	. = ..()

	if (was_working_synth)
		to_chat(affected_mob, span_warning("The chemicals sealing your faulty wires loses its effect!"))

/datum/reagent/medicine/coagulant/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()

	var/datum/wound/electrical_damage/zappiest_wound

	for (var/datum/wound/electrical_damage/electrical_wound in affected_mob.all_wounds)
		if (electrical_wound.processing_shock_power_per_second_max > zappiest_wound?.processing_shock_power_per_second_max)
			zappiest_wound = electrical_wound

	if (zappiest_wound)
		if (!was_working_synth)
			to_chat(affected_mob, span_warning("Your damaged circuitry is encased in a insulative substance!"))
			was_working_synth = TRUE
		zappiest_wound.adjust_intensity(-METABOLIZE_FREE_CONSTANT(CLOT_RATE_INTENSITY_MULT) * clot_rate * metabolization_ratio * seconds_per_tick)
	else
		was_working_synth = FALSE

#undef CLOT_RATE_INTENSITY_MULT

// Coolant slows whoever metabolizes it. Synths can process it here, or the slowdown wouldn't reach them.
/datum/reagent/dinitrogen_plasmide
	description = "A compound of nitrogen and stabilized plasma, this substance is commonly used in industrial cooling due to its extreme thermal conductivity. \
	Being a heavy compound, it slows anything that metabolizes it."
	process_flags = REAGENT_ORGANIC | REAGENT_SYNTHETIC
	overdose_threshold = 60 // spraying soaks some in, so people hit tg's 40 too soon

/datum/reagent/dinitrogen_plasmide/on_mob_metabolize(mob/living/affected_mob)
	. = ..()
	affected_mob.add_movespeed_modifier(/datum/movespeed_modifier/dinitrogen_plasmide)
	to_chat(affected_mob, span_warning("Your joints suddenly feel stiff."))

/datum/reagent/dinitrogen_plasmide/on_mob_end_metabolize(mob/living/affected_mob, metabolization_ratio)
	. = ..()
	affected_mob.remove_movespeed_modifier(/datum/movespeed_modifier/dinitrogen_plasmide)
	affected_mob.remove_movespeed_modifier(/datum/movespeed_modifier/dinitrogen_plasmide_overdose)
	to_chat(affected_mob, span_warning("Your joints no longer feel stiff!"))

/datum/reagent/dinitrogen_plasmide/overdose_start(mob/living/affected_mob, metabolization_ratio)
	. = ..()
	to_chat(affected_mob, span_danger("You feel like your joints are filling with some viscous fluid!"))
	affected_mob.add_movespeed_modifier(/datum/movespeed_modifier/dinitrogen_plasmide_overdose)

/datum/movespeed_modifier/dinitrogen_plasmide
	multiplicative_slowdown = 0.3

/datum/movespeed_modifier/dinitrogen_plasmide_overdose
	multiplicative_slowdown = 1.3
