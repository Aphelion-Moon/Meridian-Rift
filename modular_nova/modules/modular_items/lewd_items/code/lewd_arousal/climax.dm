#define CLIMAX_VAGINA "Vagina"
#define CLIMAX_PENIS "Penis"
#define CLIMAX_BOTH "Both"

#define CLIMAX_ON_FLOOR "On the floor"
#define CLIMAX_IN_OR_ON "Climax in or on someone"
#define CLIMAX_OPEN_CONTAINER "Fill reagent container"
#define CLIMAX_PORTAL "Through the portal"

/mob/living/carbon/human
	/// Used to prevent nightmare scenarios.
	var/refractory_period

/**
 * The organs one climax is running with.
 *
 * Every prompt a climax opens is a chance for the mob to lose an organ, be deleted, or turn their ERP preference
 * off, so none of it survives a prompt on trust. Call release() before opening one so we hold no hard references
 * across the sleep, then reacquire() after it to re-resolve everything and find out whether we can still continue.
 */
/datum/climax_organs
	var/datum/weakref/penis_ref
	var/datum/weakref/testicles_ref
	var/datum/weakref/vagina_ref
	/// Live organs. Only valid between a successful reacquire() and the next release().
	var/obj/item/organ/genital/penis/penis
	var/obj/item/organ/genital/testicles/testicles
	var/obj/item/organ/genital/vagina/vagina

/datum/climax_organs/Destroy(force)
	release()
	return ..()

/// Starts tracking whichever organs are passed. Anything left null is simply not part of this climax.
/datum/climax_organs/proc/track(obj/item/organ/genital/penis/new_penis, obj/item/organ/genital/testicles/new_testicles, obj/item/organ/genital/vagina/new_vagina)
	if(new_penis)
		penis_ref = WEAKREF(new_penis)
	if(new_testicles)
		testicles_ref = WEAKREF(new_testicles)
	if(new_vagina)
		vagina_ref = WEAKREF(new_vagina)

/// Drops the resolved organs. Always call before a prompt, so a deleted organ isn't held alive by us.
/datum/climax_organs/proc/release()
	penis = null
	testicles = null
	vagina = null

/**
 * Re-resolves every tracked organ against `source` and rechecks that they still consent.
 *
 * Returns FALSE, holding nothing, when `source` itself can no longer climax at all. Which organs a given branch
 * actually needs is the caller's business - check them after this returns.
 */
/datum/climax_organs/proc/reacquire(mob/living/carbon/human/source)
	release()
	var/datum/client_interface/source_client = GET_CLIENT(source)
	if(QDELETED(source) || !source_client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return FALSE
	penis = resolve_organ(source, penis_ref, ORGAN_SLOT_PENIS)
	testicles = resolve_organ(source, testicles_ref, ORGAN_SLOT_TESTICLES)
	vagina = resolve_organ(source, vagina_ref, ORGAN_SLOT_VAGINA)
	return TRUE

/// An organ is still ours only while it resolves and sits in the slot we took it from.
/datum/climax_organs/proc/resolve_organ(mob/living/carbon/human/source, datum/weakref/organ_ref, organ_slot)
	var/obj/item/organ/resolved_organ = organ_ref?.resolve()
	if(QDELETED(resolved_organ) || source.get_organ_slot(organ_slot) != resolved_organ)
		return null
	return resolved_organ

/mob/living/carbon/human/proc/climax(manual = TRUE)
	if (CONFIG_GET(flag/disable_erp_preferences))
		return

	if(!client?.prefs?.read_preference(/datum/preference/toggle/erp/autocum) && !manual)
		return
	if(refractory_period > REALTIMEOFDAY)
		return
	refractory_period = REALTIMEOFDAY + 30 SECONDS
	if(has_status_effect(/datum/status_effect/climax_cooldown) || !client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return

	if(HAS_TRAIT(src, TRAIT_NEVERBONER) || has_status_effect(/datum/status_effect/climax_cooldown) || (!has_vagina() && !has_penis()))
		visible_message(span_purple("[src] twitches, trying to cum, but with no result."), \
			span_purple("You can't have an orgasm!"), pref_to_check = /datum/preference/toggle/erp)
		return TRUE

	// Reduce pop-ups and make it slightly more frictionless (lewd).
	var/climax_choice = has_penis() ? CLIMAX_PENIS : CLIMAX_VAGINA

	if(manual)
		var/list/genitals = list()
		if(has_vagina())
			genitals.Add(CLIMAX_VAGINA)
			if(has_penis())
				genitals.Add(CLIMAX_PENIS)
				genitals.Add(CLIMAX_BOTH)
		else if(has_penis())
			genitals.Add(CLIMAX_PENIS)
		climax_choice = tgui_alert(src, "You are climaxing, choose which genitalia to climax with.", "Genitalia Preference!", genitals)
		if(QDELETED(src) || !(climax_choice in genitals))
			return FALSE
		if((climax_choice == CLIMAX_PENIS || climax_choice == CLIMAX_BOTH) && !has_penis())
			return FALSE
		if((climax_choice == CLIMAX_VAGINA || climax_choice == CLIMAX_BOTH) && !has_vagina())
			return FALSE

	var/datum/climax_organs/organs = new
	if(climax_choice == CLIMAX_PENIS || climax_choice == CLIMAX_BOTH)
		var/obj/item/organ/genital/penis/selected_penis = get_organ_slot(ORGAN_SLOT_PENIS)
		if(QDELETED(selected_penis))
			return FALSE
		organs.track(new_penis = selected_penis)
		selected_penis = null

	if(climax_choice == CLIMAX_VAGINA || climax_choice == CLIMAX_BOTH)
		var/obj/item/organ/genital/vagina/selected_vagina = get_organ_slot(ORGAN_SLOT_VAGINA)
		if(QDELETED(selected_vagina))
			return FALSE
		organs.track(new_vagina = selected_vagina)
		selected_vagina = null
	organs.release()

	switch(gender)
		if(MALE)
			playsound_if_pref(get_turf(src), pick('modular_nova/modules/modular_items/lewd_items/sounds/final_m1.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_m2.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_m3.ogg'), 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)
		if(FEMALE)
			playsound_if_pref(get_turf(src), pick('modular_nova/modules/modular_items/lewd_items/sounds/final_f1.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_f2.ogg',
										'modular_nova/modules/modular_items/lewd_items/sounds/final_f3.ogg'), 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)

	var/self_orgasm = FALSE
	var/self_their = p_their()

	if(climax_choice == CLIMAX_PENIS || climax_choice == CLIMAX_BOTH)
		if(!organs.reacquire(src) || !organs.penis)
			return FALSE
		var/obj/item/organ/genital/penis/penis = organs.penis
		var/obj/item/organ/genital/testicles/testicles = get_organ_slot(ORGAN_SLOT_TESTICLES)
		organs.track(new_testicles = testicles)
		if(!testicles) //If we have no god damn balls, we can't cum anywhere... GET BALLS!
			visible_message(span_userlove("[src] orgasms, but nothing comes out of [self_their] penis!"), \
				span_userlove("You orgasm, it feels great, but nothing comes out of your penis!"), pref_to_check = /datum/preference/toggle/erp)

		else if(is_wearing_condom())
			var/obj/item/clothing/sextoy/condom/condom = src.penis
			condom.condom_use()
			visible_message(span_userlove("[src] shoots [self_their] load into the [condom], filling it up!"), \
				span_userlove("You shoot your thick load into the [condom] and it catches it all!"), pref_to_check = /datum/preference/toggle/erp)

		else if(!is_bottomless() && penis.visibility_preference != GENITAL_ALWAYS_SHOW)
			visible_message(span_userlove("[src] cums inside [self_their] clothes!"), \
				span_userlove("You shoot your load, but you weren't naked, so you mess up your clothes!"), pref_to_check = /datum/preference/toggle/erp)
			self_orgasm = TRUE

		else
			var/list/interactable_inrange_humans = list()
			var/list/interactable_inrange_open_containers = list()

			// Filter on prefs up front, and hold candidates weakly - the prompts below outlive this list.
			for(var/mob/living/carbon/human/iterating_human in (view(1, src) - src))
				if(!iterating_human.client?.prefs?.read_preference(/datum/preference/toggle/erp))
					continue
				interactable_inrange_humans[iterating_human.name] = WEAKREF(iterating_human)

			// Every open container in reach, to offer as a destination.
			for(var/obj/item/reagent_containers/cup/iterating_open_container in (view(1, src)))
				if(!iterating_open_container.is_refillable() || !iterating_open_container.is_drainable())
					continue
				interactable_inrange_open_containers[iterating_open_container.name] = WEAKREF(iterating_open_container)

			var/list/buttons = list(CLIMAX_ON_FLOOR)
			if(interactable_inrange_humans.len)
				buttons += CLIMAX_IN_OR_ON

			if(interactable_inrange_open_containers.len)
				buttons += CLIMAX_OPEN_CONTAINER

			// Keep the offered session's identity across the destination prompt.
			var/obj/effect/lewd_portal_relay/offered_portal_output = get_portal_output()
			var/datum/weakref/offered_portal_output_ref
			if(offered_portal_output)
				offered_portal_output_ref = WEAKREF(offered_portal_output)
				buttons += CLIMAX_PORTAL
			offered_portal_output = null

			// These two locals live until the proc returns, so drop them alongside the datum's own references.
			penis = null
			testicles = null
			organs.release()
			var/penis_climax_choice = tgui_alert(src, "Choose where to shoot your load.", "Load preference!", buttons)
			if(!organs.reacquire(src) || !organs.penis || !organs.testicles)
				return FALSE
			if(!isnull(penis_climax_choice) && !(penis_climax_choice in buttons))
				return FALSE

			var/create_cum_decal = FALSE

			if(isnull(penis_climax_choice) || penis_climax_choice == CLIMAX_ON_FLOOR)
				create_cum_decal = TRUE
				visible_message(span_userlove("[src] shoots [self_their] sticky load onto the floor!"), \
					span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)

			else if(penis_climax_choice == CLIMAX_OPEN_CONTAINER)
				organs.release()
				var/target_choice = tgui_input_list(src, "Choose a container to cum into.", "Choose target!", interactable_inrange_open_containers)
				if(!organs.reacquire(src) || !organs.penis || !organs.testicles)
					return FALSE
				if(isnull(target_choice))
					create_cum_decal = TRUE
					visible_message(span_userlove("[src] shoots [self_their] sticky load onto the floor!"), \
						span_userlove("You decide to just go for it, and shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
				else
					var/datum/weakref/target_container_ref = interactable_inrange_open_containers[target_choice]
					var/obj/item/reagent_containers/cup/target_open_container = target_container_ref?.resolve()
					if(!QDELETED(target_open_container) && (target_open_container in view(1, src)) && target_open_container.is_refillable() && target_open_container.is_drainable())
						var/load_volume = organs.testicles.genital_size * 10
						playsound_if_pref(get_turf(src), SFX_DESECRATION, 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)
						if(target_open_container.reagents.holder_full())
							// reagent container is full
							add_cum_splatter_floor(get_turf(target_open_container))
							visible_message(span_userlove("[src] tries to cum into the [target_open_container], but it's already full, spilling their hot load onto the floor!"), \
								span_userlove("You try to cum into the [target_open_container], but it's already full, so it all hits the floor instead!"), pref_to_check = /datum/preference/toggle/erp)
						else
							target_open_container.reagents.add_reagent(/datum/reagent/consumable/cum, load_volume)
							if((load_volume + target_open_container.reagents.total_volume) > target_open_container.volume)
								// the chalice overfloweth
								add_cum_splatter_floor(get_turf(target_open_container))
								visible_message(span_userlove("[src] shoots [self_their] sticky load into the [target_open_container], but it's so full that it overflows!"), \
									span_userlove("You shoot string after string of hot cum into the [target_open_container], making it overflow!"), pref_to_check = /datum/preference/toggle/erp)
							else
								visible_message(span_userlove("[src] shoots [self_their] sticky load into the [target_open_container]!"), \
									span_userlove("You shoot string after string of hot cum into the [target_open_container]!"), pref_to_check = /datum/preference/toggle/erp)
					else
						// somehow the reagents changed while we were deciding where to go
						create_cum_decal = TRUE
						visible_message(span_userlove("[src] shoots [self_their] sticky load onto the floor!"), \
							span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)

			else if(penis_climax_choice == CLIMAX_PORTAL)
				var/obj/effect/lewd_portal_relay/portal_relay = resolve_portal_output(offered_portal_output_ref)
				if(!portal_relay)
					return FALSE
				to_chat(src, span_userlove("You shoot string after string of hot cum, hitting whatever is on the other side!"))
				portal_relay.visible_message(span_userlove("[portal_relay] shoots its sticky load onto the floor!"), pref_to_check = /datum/preference/toggle/erp)
				add_cum_splatter_floor(get_turf(portal_relay))

			else
				organs.release()
				var/target_choice = tgui_input_list(src, "Choose a person to cum in or on.", "Choose target!", interactable_inrange_humans)
				if(!organs.reacquire(src) || !organs.penis || !organs.testicles)
					return FALSE
				if(!target_choice)
					create_cum_decal = TRUE
					visible_message(span_userlove("[src] shoots [self_their] sticky load onto the floor!"), \
						span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
				else
					var/datum/weakref/target_human_ref = interactable_inrange_humans[target_choice]
					var/mob/living/carbon/human/target_human = target_human_ref?.resolve()
					if(QDELETED(target_human) || !(target_human in view(1, src)) || !target_human.client?.prefs?.read_preference(/datum/preference/toggle/erp))
						return FALSE
					var/target_human_them = target_human.p_them()

					var/list/target_buttons = list()

					if(!target_human.wear_mask)
						target_buttons += CLIMAX_TARGET_MOUTH
					if(target_human.has_vagina(REQUIRE_GENITAL_EXPOSED))
						target_buttons += ORGAN_SLOT_VAGINA
					if(target_human.has_anus(REQUIRE_GENITAL_EXPOSED))
						target_buttons += CLIMAX_TARGET_ASSHOLE
					if(target_human.has_penis(REQUIRE_GENITAL_EXPOSED))
						var/obj/item/organ/genital/penis/other_penis = target_human.get_organ_slot(ORGAN_SLOT_PENIS)
						if(other_penis.has_sheath())
							target_buttons += "sheath"
					target_buttons += "On [target_human_them]"

					var/target_prompt = "Where on or in [target_human] do you wish to cum?"
					target_human = null
					organs.release()
					var/climax_into_choice = tgui_input_list(src, target_prompt, "Final frontier!", target_buttons)
					if(!organs.reacquire(src) || !organs.penis || !organs.testicles)
						return FALSE
					target_human = target_human_ref.resolve()
					if(QDELETED(target_human) || !(target_human in view(1, src)) || !target_human.client?.prefs?.read_preference(/datum/preference/toggle/erp))
						return FALSE
					if(!isnull(climax_into_choice) && !(climax_into_choice in target_buttons))
						return FALSE
					if(climax_into_choice == CLIMAX_TARGET_MOUTH && target_human.wear_mask)
						return FALSE
					if(climax_into_choice == ORGAN_SLOT_VAGINA && !target_human.has_vagina(REQUIRE_GENITAL_EXPOSED))
						return FALSE
					if(climax_into_choice == CLIMAX_TARGET_ASSHOLE && !target_human.has_anus(REQUIRE_GENITAL_EXPOSED))
						return FALSE
					if(climax_into_choice == "sheath")
						var/obj/item/organ/genital/penis/target_penis = target_human.get_organ_slot(ORGAN_SLOT_PENIS)
						if(!target_penis?.has_sheath())
							return FALSE

					if(!climax_into_choice)
						create_cum_decal = TRUE
						visible_message(span_userlove("[src] shoots their sticky load onto the floor!"), \
							span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
					else if(climax_into_choice == "On [target_human_them]")
						create_cum_decal = TRUE
						visible_message(span_userlove("[src] shoots their sticky load onto [target_human]!"), \
							span_userlove("You shoot string after string of hot cum onto [target_human]!"), pref_to_check = /datum/preference/toggle/erp)
					else
						visible_message(span_userlove("[src] hilts [self_their] cock into [target_human]'s [climax_into_choice], shooting cum into [target_human_them]!"), \
							span_userlove("You hilt your cock into [target_human]'s [climax_into_choice], shooting cum into [target_human_them]!"), pref_to_check = /datum/preference/toggle/erp)
						to_chat(target_human, span_userlove("Your [climax_into_choice] fills with warm cum as [src] shoots [self_their] load into it."))
						try_knot(target_human, climax_into_choice)

			organs.testicles.transfer_internal_fluid(null, organs.testicles.internal_fluid_count * 0.6) // yep. we are sending semen to nullspace
			if(create_cum_decal)
				add_cum_splatter_floor(get_turf(src))

		try_lewd_autoemote("moan")
		if(climax_choice == CLIMAX_PENIS)
			apply_status_effect(/datum/status_effect/climax)
			apply_status_effect(/datum/status_effect/climax_cooldown)
			if(self_orgasm)
				add_mood_event("orgasm", /datum/mood_event/climaxself)
			return TRUE

	// Only the vagina matters here - a CLIMAX_BOTH that lost its penis along the way still finishes this half.
	if(climax_choice == CLIMAX_VAGINA || climax_choice == CLIMAX_BOTH)
		if(!organs.reacquire(src) || !organs.vagina)
			return FALSE
		var/obj/item/organ/genital/vagina/vagina = organs.vagina
		if(is_bottomless() || vagina.visibility_preference == GENITAL_ALWAYS_SHOW)
			visible_message(span_userlove("[src] twitches and moans as [p_they()] climax from their vagina!"), span_userlove("You twitch and moan as you climax from your vagina!"), pref_to_check = /datum/preference/toggle/erp)
			add_cum_splatter_floor(get_turf(src), female = TRUE)
		else
			visible_message(span_userlove("[src] cums in [self_their] underwear from [self_their] vagina!"), \
						span_userlove("You cum in your underwear from your vagina! Eww."), pref_to_check = /datum/preference/toggle/erp)
			self_orgasm = TRUE

	apply_status_effect(/datum/status_effect/climax)
	apply_status_effect(/datum/status_effect/climax_cooldown)
	if(self_orgasm)
		add_mood_event("orgasm", /datum/mood_event/climaxself)
	return TRUE

#undef CLIMAX_VAGINA
#undef CLIMAX_PENIS
#undef CLIMAX_BOTH
#undef CLIMAX_ON_FLOOR
#undef CLIMAX_IN_OR_ON
#undef CLIMAX_OPEN_CONTAINER
#undef CLIMAX_PORTAL
