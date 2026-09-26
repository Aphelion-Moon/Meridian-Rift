#define AROUSAL_REMOVAL_AMOUNT -12
#define STAMINA_REMOVAL_AMOUNT_EXTERNAL 15
#define STAMINA_REMOVAL_AMOUNT_SELF 8

// Lowers arousal and pleasure by a bunch to not chain climax.

/datum/status_effect/climax
	id = "climax"
	tick_interval = 1 SECONDS
	duration = 10 SECONDS
	alert_type = null

/datum/status_effect/climax/tick(seconds_between_ticks)
	if(!owner.client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
		return

	var/mob/living/carbon/human/affected_mob = owner

	owner.reagents.add_reagent(/datum/reagent/drug/aphrodisiac/dopamine, 0.5)
	owner.adjust_stamina_loss(STAMINA_REMOVAL_AMOUNT_EXTERNAL)
	affected_mob.adjust_arousal(AROUSAL_REMOVAL_AMOUNT)
	affected_mob.adjust_pleasure(AROUSAL_REMOVAL_AMOUNT)

// Likely ready to be deprecated code that could be removed, due to nymphomaniac not existing anymore.
/datum/status_effect/masturbation_climax
	id = "climax"
	tick_interval = 1 SECONDS
	duration = 5 SECONDS // Multiplayer better than singleplayer mode.
	alert_type = null

// This one should not leave decals on the floor. Used in case if character cumming in beaker.
/datum/status_effect/masturbation_climax/tick(seconds_between_ticks)
	if(!owner.client?.prefs?.read_preference(/datum/preference/toggle/erp/sex_toy))
		return

	var/mob/living/carbon/human/affected_mob = owner

	owner.reagents.add_reagent(/datum/reagent/drug/aphrodisiac/dopamine, 0.3)
	owner.adjust_stamina_loss(STAMINA_REMOVAL_AMOUNT_SELF)
	affected_mob.adjust_arousal(AROUSAL_REMOVAL_AMOUNT)
	affected_mob.adjust_pleasure(AROUSAL_REMOVAL_AMOUNT)

// A second step in preventing chain climax, and also prevents spam.
/datum/status_effect/climax_cooldown
	id = "climax_cooldown"
	tick_interval = 1 SECONDS
	duration = 30 SECONDS
	alert_type = null

/datum/status_effect/climax_cooldown/tick(seconds_between_ticks)
	var/mob/living/carbon/human/affected_mob = owner
	var/list/affected_genitals = list(
		affected_mob.get_organ_slot(ORGAN_SLOT_VAGINA),
		affected_mob.get_organ_slot(ORGAN_SLOT_TESTICLES),
		affected_mob.get_organ_slot(ORGAN_SLOT_PENIS),
		affected_mob.get_organ_slot(ORGAN_SLOT_ANUS),
	)
	var/changed_visuals = FALSE
	for(var/obj/item/organ/genital/genital as anything in affected_genitals)
		if(!genital || genital.aroused == AROUSAL_CANT || genital.aroused == AROUSAL_NONE)
			continue
		genital.aroused = AROUSAL_NONE
		genital.update_sprite_suffix()
		changed_visuals = TRUE
	if(changed_visuals)
		affected_mob.update_body()

#undef AROUSAL_REMOVAL_AMOUNT
#undef STAMINA_REMOVAL_AMOUNT_EXTERNAL
#undef STAMINA_REMOVAL_AMOUNT_SELF
