/// Unit tests of the lewd reagents ported from S.P.L.U.R.T - how they mix and what they do.
/datum/unit_test/lewd_chemistry
	parent_type = /datum/unit_test/portal_test // For attach_portal_preferences(), a mock player's preferences.
	abstract_type = /datum/unit_test/lewd_chemistry

/// How much `product` a beaker of `ingredients` (reagent type = units) makes at `temperature` kelvin.
/datum/unit_test/lewd_chemistry/proc/mix(product, list/ingredients, temperature = DEFAULT_REAGENT_TEMPERATURE)
	var/obj/item/reagent_containers/cup/beaker/large/beaker = allocate(/obj/item/reagent_containers/cup/beaker/large)
	beaker.reagents.flags |= REAGENT_HOLDER_INSTANT_REACT
	for(var/ingredient, units in ingredients)
		beaker.reagents.add_reagent(ingredient, units, no_react = TRUE)
	beaker.reagents.set_temperature(temperature)
	beaker.reagents.handle_reactions()
	return beaker.reagents.get_reagent_amount(product)

/// A test human whose mock player has the portal tests' preferences, then `preferences` (preference type = value).
/datum/unit_test/lewd_chemistry/proc/player_with(list/preferences)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent)
	attach_portal_preferences(person)
	for(var/preference, value in preferences)
		set_preference(person, preference, value)
	return person

/// Sets `preference` of `person`'s mock player to `value`.
/datum/unit_test/lewd_chemistry/proc/set_preference(mob/living/carbon/human/person, preference, value)
	if(!person.mock_client.prefs.write_preference(GLOB.preference_entries[preference], value))
		TEST_FAIL("Could not set [preference] to [value].")

/// Dopamine mixes from scratch, and R.U.T.T. from it. As anyone can now mix enough dopamine to overdose, its overdose
/// cheers only a player who takes aphrodisiacs.
/datum/unit_test/lewd_chemistry/rutt

/datum/unit_test/lewd_chemistry/rutt/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	if(CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "The ERP config removes the reactions and the preferences this test needs.")
		return
	if(!mix(/datum/reagent/drug/aphrodisiac/dopamine, list(/datum/reagent/diethylamine = 1, /datum/reagent/medicine/ephedrine = 1, /datum/reagent/hydrogen = 2, /datum/reagent/phenol = 3), 373))
		TEST_FAIL("Diethylamine, ephedrine, hydrogen and phenol at 373 K made no dopamine.")
	if(!mix(/datum/reagent/drug/aphrodisiac/rutt, list(/datum/reagent/drug/aphrodisiac/crocin = 3, /datum/reagent/drug/aphrodisiac/dopamine = 1, /datum/reagent/consumable/femcum = 1, /datum/reagent/medicine/epinephrine = 2), 322))
		TEST_FAIL("Crocin, dopamine, femcum and epinephrine at 322 K made no R.U.T.T.")

	var/datum/reagent/drug/aphrodisiac/dopamine/dopamine = allocate(/datum/reagent/drug/aphrodisiac/dopamine)
	var/overdose = "[dopamine.type]_overdose"
	var/mob/living/carbon/human/refuser = player_with(list(/datum/preference/toggle/erp/aphro = FALSE))
	dopamine.overdose_start(refuser)
	if(istype(refuser.mob_mood.get_mood_event(overdose), /datum/mood_event/overgasm))
		TEST_FAIL("A dopamine overdose gave its mood to a player who refuses aphrodisiacs.")
	var/mob/living/carbon/human/taker = player_with(list(/datum/preference/toggle/erp/aphro = TRUE))
	dopamine.overdose_start(taker)
	if(!istype(taker.mob_mood.get_mood_event(overdose), /datum/mood_event/overgasm))
		TEST_FAIL("A dopamine overdose gave no mood to a player who takes aphrodisiacs.")
