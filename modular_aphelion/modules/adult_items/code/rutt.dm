/// An aphrodisiac far stronger than hexacrocin. After ten cycles it arouses, after twenty-five it brings up to 15
/// pleasure a cycle, and from the forty-fifth its taker drools, shivers and twitches, and now and then climaxes.
/datum/reagent/drug/aphrodisiac/rutt
	name = "R.U.T.T."
	description = "Chemically condensed dopamine, sexual proteins, estrogens, and adrenalines. This aphrodisiac is an extremely powerful narcotic which may cause unintended climax."
	taste_description = "potent and floral sexual musk"
	color = "#ffa9a9"
	life_pref_datum = /datum/preference/toggle/erp/aphro

/datum/reagent/drug/aphrodisiac/rutt/on_mob_add(mob/living/affected_mob, amount)
	. = ..()
	if(affected_mob.client?.prefs?.read_preference(life_pref_datum))
		to_chat(affected_mob, span_userlove("You're hit with an intense wave of sexual pleasure!"))

/datum/reagent/drug/aphrodisiac/rutt/life_effects(mob/living/carbon/human/exposed_mob)
	if(exposed_mob.has_status_effect(/datum/status_effect/climax))
		return
	if(current_cycle > 10)
		exposed_mob.adjust_arousal(arousal_adjust_amount)
	if(current_cycle > 25)
		exposed_mob.adjust_pleasure(min(current_cycle * 0.5, 15))
	switch(current_cycle)
		if(10)
			to_chat(exposed_mob, span_userlove("Your groin starts to feel really good..."))
		if(25)
			to_chat(exposed_mob, span_userlove("You feel an orgasm building up..."))
		if(45 to INFINITY)
			if(SPT_PROB(20, SSMOBS_DT))
				exposed_mob.try_lewd_autoemote(pick("drool", "shiver", "twitch"))
			// Only a finished climax says so - climax() returns null when refused or while it asks where to finish, and
			// TRUE without the climax status for a mob that can't.
			if(SPT_PROB(2, SSMOBS_DT) && exposed_mob.climax(manual = FALSE) && exposed_mob.has_status_effect(/datum/status_effect/climax))
				to_chat(exposed_mob, span_userlove("You can't stop cumming!"))

/datum/glass_style/drinking_glass/rutt
	required_drink_type = /datum/reagent/drug/aphrodisiac/rutt
	name = "glass of R.U.T.T."
	desc = "A glass of frothy pink juice. It smells floral and musky."

/obj/item/reagent_containers/cup/bottle/rutt
	name = "\improper R.U.T.T. bottle"
	desc = "A bottle of frothy pink juice. It smells floral and musky."
	list_reagents = list(/datum/reagent/drug/aphrodisiac/rutt = 30)
	obj_flags_nova = ERP_ITEM

/// Wears the dopamine pill's sprite, so the two look alike.
/obj/item/reagent_containers/applicator/pill/rutt
	name = "\improper R.U.T.T. pill (10u)"
	desc = "This aphrodisiac is an extremely powerful narcotic which may cause unintended climax."
	icon = 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/lewd_pills.dmi'
	icon_state = "dopamine"
	list_reagents = list(/datum/reagent/drug/aphrodisiac/rutt = 10)
	obj_flags_nova = ERP_ITEM

/datum/chemical_reaction/rutt
	results = list(/datum/reagent/drug/aphrodisiac/rutt = 20)
	required_reagents = list(
		/datum/reagent/drug/aphrodisiac/crocin = 3,
		/datum/reagent/drug/aphrodisiac/dopamine = 1,
		/datum/reagent/consumable/femcum = 1,
		/datum/reagent/medicine/epinephrine = 2,
	)
	required_temp = 322
	mix_message = "The musky mixture foams into a warm pink froth..."
	erp_reaction = TRUE
	reaction_tags = REACTION_TAG_CHEMICAL | REACTION_TAG_HARD | REACTION_TAG_DRUG

/// Dopamine from scratch - without it, R.U.T.T.'s dopamine only comes from a climax.
/datum/chemical_reaction/dopamine
	results = list(/datum/reagent/drug/aphrodisiac/dopamine = 10)
	required_reagents = list(
		/datum/reagent/diethylamine = 1,
		/datum/reagent/medicine/ephedrine = 1,
		/datum/reagent/hydrogen = 2,
		/datum/reagent/phenol = 3,
	)
	required_temp = 373
	mix_message = "The solution bubbles into a colorless liquid..."
	erp_reaction = TRUE
	reaction_tags = REACTION_TAG_CHEMICAL | REACTION_TAG_EASY | REACTION_TAG_DRUG
