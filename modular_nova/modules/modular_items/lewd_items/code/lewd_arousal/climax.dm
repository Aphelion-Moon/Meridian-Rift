#define CLIMAX_VAGINA "Vagina"
#define CLIMAX_PENIS "Penis"
#define CLIMAX_BOTH "Both"

#define CLIMAX_ON_FLOOR "On the floor"
#define CLIMAX_IN_OR_ON "Climax in or on someone"
#define CLIMAX_OPEN_CONTAINER "Fill reagent container"
#define CLIMAX_PORTAL "Through the portal"

/// climax_ask() answers this when the climax can't go on, a number so it never equals a real answer
#define CLIMAX_LOST (-1)
/// A source's climax that ended up in clothes
#define CLIMAX_IN_CLOTHES 2

/// The container took the whole load
#define CLIMAX_FILL_FITS 1
/// The container filled up and the rest spilled
#define CLIMAX_FILL_OVERFLOWED 2
/// The container was already full, so it all spilled
#define CLIMAX_FILL_FULL 3

/mob/living/carbon/human
	/// Used to prevent nightmare scenarios.
	var/refractory_period

/// Whether a climax can go on after a prompt - we still exist and still have ERP on
/mob/living/carbon/human/proc/can_still_climax()
	var/datum/client_interface/climax_client = GET_CLIENT(src)
	return !QDELETED(src) && climax_client?.prefs?.read_preference(/datum/preference/toggle/erp)

/**
 * Resolves a partner offered before a climax prompt, only while they are still in reach and consenting.
 *
 * The reference is either a nearby human, or a wall portal relay standing in for the occupant it projects.
 */
/mob/living/carbon/human/proc/resolve_climax_partner(datum/weakref/partner_ref)
	var/atom/movable/partner = partner_ref?.resolve()
	if(QDELETED(partner) || !(partner in view(1, src)))
		return null
	if(istype(partner, /obj/effect/lewd_portal_relay))
		var/obj/effect/lewd_portal_relay/partner_relay = partner
		return partner_relay.can_reveal_to(src) ? partner_relay.owner : null
	var/mob/living/carbon/human/partner_human = partner
	if(!ishuman(partner_human) || !partner_human.client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return null
	return partner_human

/// Never makes its caller wait - adjust_pleasure() climaxes from Life(), process() and status effects, which must not
/// sleep, and a climax can stop to ask where to finish. Its caller then gets null, and it ends when the player answers.
/mob/living/carbon/human/proc/climax(manual = TRUE)
	set waitfor = FALSE
	if (CONFIG_GET(flag/disable_erp_preferences))
		return

	if(!client?.prefs?.read_preference(/datum/preference/toggle/erp/autocum) && !manual)
		return
	if(refractory_period > REALTIMEOFDAY)
		return
	refractory_period = REALTIMEOFDAY + 30 SECONDS
	if(has_status_effect(/datum/status_effect/climax_cooldown) || !client?.prefs?.read_preference(/datum/preference/toggle/erp))
		return

	if(HAS_TRAIT(src, TRAIT_NEVERBONER) || HAS_TRAIT(src, TRAIT_NO_CLIMAX) || (!has_vagina() && !has_penis()))
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

	if(climax_choice == CLIMAX_PENIS || climax_choice == CLIMAX_BOTH)
		var/penis_climax = climax_from_penis()
		if(!penis_climax)
			return FALSE
		self_orgasm = (penis_climax == CLIMAX_IN_CLOTHES)
		try_lewd_autoemote("moan")

	if(climax_choice == CLIMAX_VAGINA || climax_choice == CLIMAX_BOTH)
		var/vagina_climax = climax_from_vagina()
		// A penis half that already landed still finishes the climax, unless we were deleted
		if(!vagina_climax && (climax_choice == CLIMAX_VAGINA || QDELETED(src)))
			return FALSE
		if(vagina_climax == CLIMAX_IN_CLOTHES)
			self_orgasm = TRUE

	apply_status_effect(/datum/status_effect/climax)
	apply_status_effect(/datum/status_effect/climax_cooldown)
	if(self_orgasm)
		add_mood_event("orgasm", /datum/mood_event/climaxself)
	return TRUE

/**
 * Lands a penis climax, asking where it goes when the penis is exposed.
 *
 * Returns FALSE when the climax can't go on, CLIMAX_IN_CLOTHES when it ends up in our clothes, TRUE otherwise.
 */
/mob/living/carbon/human/proc/climax_from_penis()
	if(!can_still_climax() || !has_penis())
		return FALSE
	if(!has_balls()) //If we have no god damn balls, we can't cum anywhere... GET BALLS!
		visible_message(span_userlove("[src] orgasms, but nothing comes out of [p_their()] penis!"), \
			span_userlove("You orgasm, it feels great, but nothing comes out of your penis!"), pref_to_check = /datum/preference/toggle/erp)
		return TRUE

	if(is_wearing_condom())
		var/obj/item/clothing/sextoy/condom/condom = src.penis
		condom.condom_use()
		visible_message(span_userlove("[src] shoots [p_their()] load into the [condom], filling it up!"), \
			span_userlove("You shoot your thick load into the [condom] and it catches it all!"), pref_to_check = /datum/preference/toggle/erp)
		return TRUE

	if(!has_penis(REQUIRE_GENITAL_EXPOSED))
		visible_message(span_userlove("[src] cums inside [p_their()] clothes!"), \
			span_userlove("You shoot your load, but you weren't naked, so you mess up your clothes!"), pref_to_check = /datum/preference/toggle/erp)
		return CLIMAX_IN_CLOTHES

	var/list/interactable_inrange_humans = climax_partners_in_reach()
	var/list/interactable_inrange_open_containers = climax_containers_in_reach()

	var/list/buttons = list(CLIMAX_ON_FLOOR)
	if(length(interactable_inrange_humans))
		buttons += CLIMAX_IN_OR_ON

	if(length(interactable_inrange_open_containers))
		buttons += CLIMAX_OPEN_CONTAINER

	// Keep the offered session's identity across the destination prompt.
	var/datum/weakref/offered_portal_output_ref = WEAKREF(get_portal_output())
	if(offered_portal_output_ref)
		buttons += CLIMAX_PORTAL

	var/penis_climax_choice = climax_ask(CLIMAX_PENIS, "Choose where to shoot your load.", "Load preference!", buttons)
	if(penis_climax_choice == CLIMAX_LOST)
		return FALSE

	if(isnull(penis_climax_choice) || penis_climax_choice == CLIMAX_ON_FLOOR)
		visible_message(span_userlove("[src] shoots [p_their()] sticky load onto the floor!"), \
			span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(src))

	else if(penis_climax_choice == CLIMAX_OPEN_CONTAINER)
		var/target_choice = climax_ask(CLIMAX_PENIS, "Choose a container to cum into.", "Choose target!", interactable_inrange_open_containers, as_list = TRUE)
		if(target_choice == CLIMAX_LOST)
			return FALSE
		if(isnull(target_choice))
			visible_message(span_userlove("[src] shoots [p_their()] sticky load onto the floor!"), \
				span_userlove("You decide to just go for it, and shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
			add_cum_splatter_floor(get_turf(src))
		else
			var/obj/item/reagent_containers/cup/target_open_container = climax_container_in_reach(interactable_inrange_open_containers[target_choice])
			if(target_open_container)
				var/obj/item/organ/genital/testicles/testicles = get_organ_slot(ORGAN_SLOT_TESTICLES)
				switch(climax_fill(target_open_container, /datum/reagent/consumable/cum, testicles.genital_size * 10))
					if(CLIMAX_FILL_FULL)
						visible_message(span_userlove("[src] tries to cum into the [target_open_container], but it's already full, spilling their hot load onto the floor!"), \
							span_userlove("You try to cum into the [target_open_container], but it's already full, so it all hits the floor instead!"), pref_to_check = /datum/preference/toggle/erp)
					if(CLIMAX_FILL_OVERFLOWED)
						visible_message(span_userlove("[src] shoots [p_their()] sticky load into the [target_open_container], but it's so full that it overflows!"), \
							span_userlove("You shoot string after string of hot cum into the [target_open_container], making it overflow!"), pref_to_check = /datum/preference/toggle/erp)
					else
						visible_message(span_userlove("[src] shoots [p_their()] sticky load into the [target_open_container]!"), \
							span_userlove("You shoot string after string of hot cum into the [target_open_container]!"), pref_to_check = /datum/preference/toggle/erp)
			else
				// somehow the reagents changed while we were deciding where to go
				visible_message(span_userlove("[src] shoots [p_their()] sticky load onto the floor!"), \
					span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
				add_cum_splatter_floor(get_turf(src))

	else if(penis_climax_choice == CLIMAX_PORTAL)
		var/obj/effect/lewd_portal_relay/portal_relay = resolve_portal_output(offered_portal_output_ref)
		if(!portal_relay)
			return FALSE
		to_chat(src, span_userlove("You shoot string after string of hot cum, hitting whatever is on the other side!"))
		portal_relay.visible_message(span_userlove("[portal_relay] shoots its sticky load onto the floor!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(portal_relay))

	else if(!climax_into_partner(interactable_inrange_humans))
		return FALSE

	var/obj/item/organ/genital/testicles/drained_testicles = get_organ_slot(ORGAN_SLOT_TESTICLES)
	drained_testicles.transfer_internal_fluid(null, drained_testicles.internal_fluid_count * 0.6) // yep. we are sending semen to nullspace
	return TRUE

/**
 * Lands a vagina climax, offering the open containers in reach when the vagina is exposed.
 *
 * Returns FALSE when the climax can't go on, CLIMAX_IN_CLOTHES when it ends up in our underwear, TRUE otherwise.
 */
/mob/living/carbon/human/proc/climax_from_vagina()
	// Only the vagina matters here - a CLIMAX_BOTH that lost its penis along the way still finishes this half.
	if(!can_still_climax() || !has_vagina())
		return FALSE
	if(!has_vagina(REQUIRE_GENITAL_EXPOSED))
		visible_message(span_userlove("[src] cums in [p_their()] underwear from [p_their()] vagina!"), \
			span_userlove("You cum in your underwear from your vagina! Eww."), pref_to_check = /datum/preference/toggle/erp)
		return CLIMAX_IN_CLOTHES

	var/list/interactable_inrange_open_containers = climax_containers_in_reach()

	var/obj/item/reagent_containers/cup/target_open_container
	if(length(interactable_inrange_open_containers))
		var/vagina_climax_choice = climax_ask(CLIMAX_VAGINA, "Choose where to climax.", "Climax preference!", list(CLIMAX_ON_FLOOR, CLIMAX_OPEN_CONTAINER))
		if(vagina_climax_choice == CLIMAX_LOST)
			return FALSE
		if(vagina_climax_choice == CLIMAX_OPEN_CONTAINER)
			var/target_choice = climax_ask(CLIMAX_VAGINA, "Choose a container to climax into.", "Choose target!", interactable_inrange_open_containers, as_list = TRUE)
			if(target_choice == CLIMAX_LOST)
				return FALSE
			if(!isnull(target_choice))
				target_open_container = climax_container_in_reach(interactable_inrange_open_containers[target_choice])

	// With no container in reach, a cancelled prompt or a container lost while we chose, we climax as we always have
	if(!target_open_container)
		visible_message(span_userlove("[src] twitches and moans as [p_they()] climax from their vagina!"), span_userlove("You twitch and moan as you climax from your vagina!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(src), female = TRUE)
		return TRUE

	var/obj/item/organ/genital/vagina/vagina = get_organ_slot(ORGAN_SLOT_VAGINA)
	switch(climax_fill(target_open_container, /datum/reagent/consumable/femcum, vagina.genital_size * 10, female = TRUE))
		if(CLIMAX_FILL_FULL)
			visible_message(span_userlove("[src] tries to climax into \the [target_open_container], but it's already full, so it all spills onto the floor!"), \
				span_userlove("You try to climax into \the [target_open_container], but it's already full, so it all hits the floor instead!"), pref_to_check = /datum/preference/toggle/erp)
		if(CLIMAX_FILL_OVERFLOWED)
			visible_message(span_userlove("[src] twitches and moans as [p_they()] climax[p_es()] into \the [target_open_container], filling it until it overflows!"), \
				span_userlove("You twitch and moan as you climax into \the [target_open_container], making it overflow!"), pref_to_check = /datum/preference/toggle/erp)
		else
			visible_message(span_userlove("[src] twitches and moans as [p_they()] climax[p_es()] into \the [target_open_container]!"), \
				span_userlove("You twitch and moan as you climax into \the [target_open_container]!"), pref_to_check = /datum/preference/toggle/erp)
	return TRUE

/**
 * Lands a penis climax in or on a partner in reach, asking who and where.
 *
 * Arguments:
 * * interactable_inrange_humans - the partners offered, names to weakrefs from climax_partners_in_reach()
 *
 * Returns FALSE when the climax can't go on, TRUE otherwise.
 */
/mob/living/carbon/human/proc/climax_into_partner(list/interactable_inrange_humans)
	var/target_choice = climax_ask(CLIMAX_PENIS, "Choose a person to cum in or on.", "Choose target!", interactable_inrange_humans, as_list = TRUE)
	if(target_choice == CLIMAX_LOST)
		return FALSE
	if(!target_choice)
		visible_message(span_userlove("[src] shoots [p_their()] sticky load onto the floor!"), \
			span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(src))
		return TRUE

	var/datum/weakref/target_human_ref = interactable_inrange_humans[target_choice]
	var/mob/living/carbon/human/target_human = resolve_climax_partner(target_human_ref)
	if(!target_human)
		return FALSE
	// A portal occupant stays anonymous, and only the part of them their relay shows is in reach.
	var/obj/effect/lewd_portal_relay/target_relay = target_human_ref.resolve()
	var/through_portal = istype(target_relay)
	var/target_name = through_portal ? "\the [target_relay.name]" : "[target_human]"
	var/target_human_them = through_portal ? "them" : target_human.p_them()
	var/target_human_their = through_portal ? "their" : target_human.p_their()
	var/lower_body_in_reach = !through_portal || target_relay.shows_lower_body()
	var/portal_view = through_portal ? (lower_body_in_reach ? DIRT_PORTAL_LOWER_BODY : DIRT_PORTAL_PENIS) : DIRT_PORTAL_NONE
	target_relay = null

	var/list/target_buttons = list()

	if(!through_portal && !target_human.wear_mask)
		target_buttons += CLIMAX_TARGET_MOUTH
	if(lower_body_in_reach && target_human.has_vagina(REQUIRE_GENITAL_EXPOSED))
		target_buttons += ORGAN_SLOT_VAGINA
	if(lower_body_in_reach && target_human.has_anus(REQUIRE_GENITAL_EXPOSED))
		target_buttons += CLIMAX_TARGET_ASSHOLE
	if(target_human.has_penis(REQUIRE_GENITAL_EXPOSED))
		var/obj/item/organ/genital/penis/other_penis = target_human.get_organ_slot(ORGAN_SLOT_PENIS)
		if(other_penis.has_sheath())
			target_buttons += "sheath"
		// Locals outlive their block, so we let go of their penis before the prompt below
		other_penis = null
	// One entry per region the mess shows on, or "On them" when it shows on none.
	var/list/region_entries = list()
	for(var/zone in dirt_mess_regions(target_human, portal_view))
		if(!dirt_mess_landable(zone))
			continue
		var/entry = dirt_mess_entry(zone, target_human_their)
		region_entries[entry] = zone
		target_buttons += entry
	if(!length(region_entries))
		target_buttons += "On [target_human_them]"

	var/target_prompt = "Where on or in [target_name] do you wish to cum?"
	target_human = null
	var/climax_into_choice = climax_ask(CLIMAX_PENIS, target_prompt, "Final frontier!", target_buttons, as_list = TRUE)
	if(climax_into_choice == CLIMAX_LOST)
		return FALSE
	target_human = resolve_climax_partner(target_human_ref)
	if(!target_human)
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
	var/aimed_zone = climax_into_choice && region_entries[climax_into_choice]
	if(aimed_zone && !(aimed_zone in dirt_mess_regions(target_human, portal_view)))
		return FALSE

	if(!climax_into_choice)
		visible_message(span_userlove("[src] shoots their sticky load onto the floor!"), \
			span_userlove("You shoot string after string of hot cum, hitting the floor!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(src))
	else if(aimed_zone)
		// through a one-part portal the relay is named for the penis already
		var/aimed_at = aimed_zone == DIRT_ZONE_COCK ? target_name : "[target_name]'s [aimed_zone]"
		visible_message(span_userlove("[src] shoots [p_their()] sticky load onto [aimed_at]!"), \
			span_userlove("You shoot string after string of hot cum onto [aimed_at]!"), pref_to_check = /datum/preference/toggle/erp)
		if(through_portal)
			to_chat(target_human, span_userlove("Someone on the other side of the portal shoots their load onto you."))
		// the amount climax_from_penis() drains once we return
		var/obj/item/organ/genital/testicles/testicles = get_organ_slot(ORGAN_SLOT_TESTICLES)
		dirt_mess_land(target_human, aimed_zone, portal_view, dirt_mess_amount_levels(testicles.internal_fluid_count * 0.6))
	else if(climax_into_choice == "On [target_human_them]")
		visible_message(span_userlove("[src] shoots their sticky load onto [target_name]!"), \
			span_userlove("You shoot string after string of hot cum onto [target_name]!"), pref_to_check = /datum/preference/toggle/erp)
		add_cum_splatter_floor(get_turf(src))
		if(through_portal)
			to_chat(target_human, span_userlove("Someone on the other side of the portal shoots their load onto you."))
	else
		visible_message(span_userlove("[src] hilts [p_their()] cock into [target_name]'s [climax_into_choice], shooting cum into [target_human_them]!"), \
			span_userlove("You hilt your cock into [target_name]'s [climax_into_choice], shooting cum into [target_human_them]!"), pref_to_check = /datum/preference/toggle/erp)
		to_chat(target_human, span_userlove("Your [climax_into_choice] fills with warm cum as [through_portal ? "someone" : src] shoots [through_portal ? "their" : p_their()] load into it."))
		// A knot can't lock through a portal, and its messages would name the occupant.
		if(!through_portal)
			try_knot(target_human, climax_into_choice)

	return TRUE

/**
 * Gathers the consenting partners in reach, held weakly for the prompts that follow.
 *
 * We loop over view() itself, which BYOND doesn't keep, so nothing in reach is held once this returns.
 *
 * Returns humans in view order, then portal relays, names to weakrefs, or null when there are none.
 */
/mob/living/carbon/human/proc/climax_partners_in_reach()
	var/list/partners
	// Filter on prefs up front, and hold candidates weakly - the prompts that follow outlive this list.
	// We skip ourselves here rather than loop over view() - src, as BYOND keeps the last evaluated view() and all it saw
	for(var/mob/living/carbon/human/iterating_human in view(1, src))
		if(iterating_human == src || !iterating_human.client?.prefs?.read_preference(/datum/preference/toggle/erp))
			continue
		LAZYSET(partners, iterating_human.name, WEAKREF(iterating_human))

	// Wall portal occupants are reached through their relay, and offered under its name.
	for(var/obj/effect/lewd_portal_relay/iterating_relay in view(1, src))
		if(iterating_relay.owner == src || !iterating_relay.can_reveal_to(src))
			continue
		LAZYSET(partners, "\the [iterating_relay.name]", WEAKREF(iterating_relay))
	return partners

/**
 * Gathers the open containers in reach, held weakly for the prompts that follow.
 *
 * We loop over view() itself, which BYOND doesn't keep, so nothing in reach is held once this returns.
 *
 * Returns names to weakrefs, same names numbered apart, or null when there are none.
 */
/mob/living/carbon/human/proc/climax_containers_in_reach()
	var/list/containers
	var/list/container_names
	// Every open container in reach, to offer as a destination.
	for(var/obj/item/reagent_containers/cup/iterating_open_container in (view(1, src)))
		if(!iterating_open_container.is_refillable() || !iterating_open_container.is_drainable())
			continue
		// avoid_assoc_duplicate_keys() needs a list to count names in
		LAZYINITLIST(container_names)
		LAZYSET(containers, avoid_assoc_duplicate_keys(iterating_open_container.name, container_names), WEAKREF(iterating_open_container))
	return containers

/**
 * Asks the climaxing player a question, then checks the climax can still go on.
 *
 * Arguments:
 * * organ_source - CLIMAX_PENIS or CLIMAX_VAGINA, the source whose organs must still be in their slots
 * * message - the prompt's text
 * * title - the prompt's title
 * * options - the answers offered
 * * as_list - TRUE for a list prompt, FALSE for buttons
 *
 * Returns the answer, null when the prompt was closed, or CLIMAX_LOST when the climax can't go on.
 */
/mob/living/carbon/human/proc/climax_ask(organ_source, message, title, list/options, as_list = FALSE)
	var/answer = as_list ? tgui_input_list(src, message, title, options) : tgui_alert(src, message, title, options)
	if(!can_still_climax())
		return CLIMAX_LOST
	if(organ_source == CLIMAX_PENIS)
		if(!has_penis() || !has_balls())
			return CLIMAX_LOST
	else if(!has_vagina())
		return CLIMAX_LOST
	return answer

/// Resolves a container offered before a prompt, only while it's still in reach and open
/mob/living/carbon/human/proc/climax_container_in_reach(datum/weakref/container_ref)
	var/obj/item/reagent_containers/cup/target_open_container = container_ref?.resolve()
	if(QDELETED(target_open_container) || !(target_open_container in view(1, src)) || !target_open_container.is_refillable() || !target_open_container.is_drainable())
		return null
	return target_open_container

/**
 * Fills an open container with a climax, spilling at its feet whatever doesn't fit.
 *
 * Arguments:
 * * target_open_container - the container, still in reach and open
 * * reagent_type - what the climax is made of
 * * load_volume - how much the climax holds
 * * female - whether a spill leaves the femcum stain
 *
 * Returns CLIMAX_FILL_FITS, CLIMAX_FILL_OVERFLOWED or CLIMAX_FILL_FULL.
 */
/mob/living/carbon/human/proc/climax_fill(obj/item/reagent_containers/cup/target_open_container, datum/reagent/reagent_type, load_volume, female = FALSE)
	playsound_if_pref(get_turf(src), /datum/sound_effect/desecration, 50, TRUE, pref_to_check = /datum/preference/toggle/erp/sounds)
	// We measure before filling, since add_reagent() quietly drops whatever doesn't fit
	var/free_volume = target_open_container.reagents.maximum_volume - target_open_container.reagents.total_volume
	if(free_volume <= 0)
		// reagent container is full
		add_cum_splatter_floor(get_turf(target_open_container), female)
		return CLIMAX_FILL_FULL
	target_open_container.reagents.add_reagent(reagent_type, load_volume)
	if(load_volume > free_volume)
		// the chalice overfloweth
		add_cum_splatter_floor(get_turf(target_open_container), female)
		return CLIMAX_FILL_OVERFLOWED
	return CLIMAX_FILL_FITS

#undef CLIMAX_VAGINA
#undef CLIMAX_PENIS
#undef CLIMAX_BOTH
#undef CLIMAX_ON_FLOOR
#undef CLIMAX_IN_OR_ON
#undef CLIMAX_OPEN_CONTAINER
#undef CLIMAX_PORTAL
#undef CLIMAX_LOST
#undef CLIMAX_IN_CLOTHES
#undef CLIMAX_FILL_FITS
#undef CLIMAX_FILL_OVERFLOWED
#undef CLIMAX_FILL_FULL
