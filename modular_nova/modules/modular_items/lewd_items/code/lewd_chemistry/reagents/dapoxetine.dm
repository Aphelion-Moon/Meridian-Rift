/// An anaphrodisiac that stops its taker climaxing while it's in their system, if they have aphrodisiacs on.
/datum/reagent/drug/aphrodisiac/dapoxetine
	name = "Dapoxetine"
	description = "Naphthalene and benzene rings linked via a propyl chain which contains a dimethylamine group. Prevents ejaculation by inhibiting the reuptake of serotonin."
	taste_description = "intense bitterness"
	color = "#e5e5e5"
	life_pref_datum = /datum/preference/toggle/erp/aphro

// The base on_mob_delete() clears the "base:[type]" traits.
/datum/reagent/drug/aphrodisiac/dapoxetine/on_mob_add(mob/living/affected_mob, amount)
	. = ..()
	var/datum/client_interface/player = GET_CLIENT(affected_mob)
	if(player?.prefs?.read_preference(life_pref_datum))
		ADD_TRAIT(affected_mob, TRAIT_NO_CLIMAX, "base:[type]")

/datum/chemical_reaction/dapoxetine
	results = list(/datum/reagent/drug/aphrodisiac/dapoxetine = 10)
	required_reagents = list(
		/datum/reagent/diethylamine = 1,
		/datum/reagent/acetone = 1,
		/datum/reagent/phenol = 2,
	)
	required_temp = 379
	mix_message = "The solution bubbles into a white powdery substance..."
	erp_reaction = TRUE
