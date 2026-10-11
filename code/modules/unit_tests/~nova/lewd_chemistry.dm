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

/// Denbu tincture mixes, and does nothing for a player who refuses butt enlargement. For one who takes it and new
/// genitalia it grows a size-1 butt that the DNA names Pair and that wears the Pair sprite - on a body whose DNA held
/// no butt, in the player's butt colours, and on one whose DNA named it None, as a player's does - then a size every
/// twenty cycles up to the largest a player can pick. Camphor's overdose moves a butt back to its preference size a
/// size a dose, from above and from below. A test human's DNA holds no butt, and without one Nova's organ insertion
/// writes the random sprite it drew, so only the colours tell the tincture's entry from that one.
/datum/unit_test/lewd_chemistry/butt_enlarger

/datum/unit_test/lewd_chemistry/butt_enlarger/Run()
	TEST_SKIP_IF_LEWD_ITEMS_DISABLED
	if(CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "The ERP config removes the reaction, the genitals and the preferences this test needs.")
		return
	if(!mix(/datum/reagent/drug/aphrodisiac/butt_enlarger, list(/datum/reagent/medicine/salglu_solution = 1, /datum/reagent/consumable/sugar = 2, /datum/reagent/silicon = 3, /datum/reagent/drug/aphrodisiac/crocin = 2)))
		TEST_FAIL("Saline-glucose, sugar, silicon and crocin made no denbu tincture.")

	var/datum/reagent/drug/aphrodisiac/butt_enlarger/tincture = allocate(/datum/reagent/drug/aphrodisiac/butt_enlarger)
	var/mob/living/carbon/human/refuser = player_with(list(/datum/preference/toggle/erp/butt_enlargement = FALSE, /datum/preference/toggle/erp/new_genitalia_growth = TRUE))
	TEST_ASSERT_NULL(refuser.get_organ_slot(ORGAN_SLOT_BUTT), "The test human came with a butt.")
	tincture.on_mob_life(refuser, SSMOBS_DT, 1)
	if(refuser.get_organ_slot(ORGAN_SLOT_BUTT))
		TEST_FAIL("A butt grew on a player who refuses butt enlargement.")
	var/mob/living/carbon/human/no_growth = player_with(list(/datum/preference/toggle/erp/butt_enlargement = TRUE, /datum/preference/toggle/erp/new_genitalia_growth = FALSE))
	tincture.on_mob_life(no_growth, SSMOBS_DT, 1)
	if(no_growth.get_organ_slot(ORGAN_SLOT_BUTT))
		TEST_FAIL("A butt grew on a player who takes no new genitalia.")

	var/colour = "#123456"
	var/mob/living/carbon/human/person = player_with(list(/datum/preference/toggle/erp/butt_enlargement = TRUE, /datum/preference/toggle/erp/new_genitalia_growth = TRUE, /datum/preference/tri_color/genital/butt = list(colour, colour, colour)))
	tincture.on_mob_life(person, SSMOBS_DT, 1)
	var/obj/item/organ/genital/butt/butt = grown_butt(person, "on a body whose DNA held no butt")
	var/datum/mutant_bodypart/butt_part = person.dna.mutant_bodyparts[FEATURE_BUTT]
	if(butt_part?.get_primary_color() != colour)
		TEST_FAIL("The DNA colours the butt grown on a body whose DNA held no butt [butt_part?.get_primary_color() || "not at all"], not the player's [colour].")
	qdel(butt)
	person.dna.mutant_bodyparts[FEATURE_BUTT] = build_mutant_part(SPRITE_ACCESSORY_NONE) // As a player's preferences write it.
	tincture.on_mob_life(person, SSMOBS_DT, 1)
	butt = grown_butt(person, "on a body whose DNA named its butt None")
	if(!butt)
		return
	var/largest = /datum/preference/numeric/butt_size::maximum
	for(var/i in 1 to 160)
		tincture.on_mob_life(person, SSMOBS_DT, 1)
	if(butt.genital_size != largest)
		TEST_FAIL("160 cycles left the butt at size [butt.genital_size], not [largest].")

	var/datum/reagent/drug/aphrodisiac/camphor/camphor = allocate(/datum/reagent/drug/aphrodisiac/camphor)
	butt.genital_size = 8
	set_preference(person, /datum/preference/numeric/butt_size, 3)
	for(var/i in 1 to 6)
		camphor.overdose_effects(person)
	if(butt.genital_size != 3)
		TEST_FAIL("Six camphor overdoses left a size-8 butt at size [butt.genital_size], not its preference size 3.")
	butt.genital_size = 3
	set_preference(person, /datum/preference/numeric/butt_size, 5)
	for(var/i in 1 to 3)
		camphor.overdose_effects(person)
	if(butt.genital_size != 5)
		TEST_FAIL("Three camphor overdoses left a size-3 butt at size [butt.genital_size], not its preference size 5.")

/// The butt the tincture grew on `person` `case`, failing the test unless it is size 1 and Pair in the DNA and drawn.
/datum/unit_test/lewd_chemistry/butt_enlarger/proc/grown_butt(mob/living/carbon/human/person, case)
	var/obj/item/organ/genital/butt/butt = person.get_organ_slot(ORGAN_SLOT_BUTT)
	if(!butt)
		TEST_FAIL("No butt grew [case].")
		return
	var/pair = /datum/sprite_accessory/genital/butt/pair::name
	var/datum/mutant_bodypart/butt_part = person.dna.mutant_bodyparts[FEATURE_BUTT]
	if(butt_part?.name != pair)
		TEST_FAIL("The DNA names the butt grown [case] [butt_part?.name || "nothing"], not [pair].")
	var/datum/bodypart_overlay/mutant/genital/butt/overlay = butt.bodypart_overlay
	if(!istype(overlay.sprite_datum, /datum/sprite_accessory/genital/butt/pair))
		TEST_FAIL("The butt grown [case] wears [overlay.sprite_datum?.name || "no sprite"], not [pair].")
	if(butt.genital_size != 1)
		TEST_FAIL("The butt grown [case] is size [butt.genital_size], not 1.")
	return butt
