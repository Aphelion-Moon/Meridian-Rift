/**
 * Focused ownership, equipment-authority, packaging, and configuration tests
 * for the LustWish portal device and receiver.
 */

#define PORTAL_INTERACTION_STATE_TEST_ID "Portal interaction state test"
#define PORTAL_INTERACTION_STATE_TEST_TRAIT "portal_interaction_state_test"

/// Lets public buckle tests reach the portal-specific guards without a real BYOND client.
/mob/living/carbon/human/consistent/portal_unit_test
	var/portal_test_sex_toy_preference = TRUE

/mob/living/carbon/human/consistent/portal_unit_test/check_erp_prefs(
	datum/preference/toggle/pref_to_check,
	mob/living/mechanic_user = null,
	obj/item/used_item = FALSE,
)
	return portal_test_sex_toy_preference

/// Records deferred interaction effects without depending on a real client's arousal preferences.
/mob/living/carbon/human/consistent/portal_interaction_state_test
	var/portal_test_pain_received = 0

/mob/living/carbon/human/consistent/portal_interaction_state_test/adjust_pain(change_amount = 0)
	portal_test_pain_received += change_amount

/// Counts real device rebuilds while retaining the production appearance path.
/obj/item/clothing/sextoy/portal_fleshlight/appearance_unit_test
	var/appearance_updates = 0

/obj/item/clothing/sextoy/portal_fleshlight/appearance_unit_test/update_appearance(updates = ALL)
	appearance_updates++
	return ..()

/datum/unit_test/portal_device
	parent_type = /datum/unit_test/portal_test
	abstract_type = /datum/unit_test/portal_device
	var/appearance_timers_ran = FALSE
	/// Original registry entries replaced by this test's deterministic fixtures.
	var/list/replaced_interactions = list()

/datum/unit_test/portal_device/Destroy()
	for(var/interaction_name in replaced_interactions)
		var/list/previous = replaced_interactions[interaction_name]
		if(previous[1])
			GLOB.interaction_instances[interaction_name] = previous[2]
		else
			GLOB.interaction_instances -= interaction_name
	return ..()

/// Installs a real interaction without depending on the server's optional JSON configuration.
/datum/unit_test/portal_device/proc/install_interaction_fixture(interaction_name = "Tongue kiss", list/user_parts, list/target_parts)
	if(!(interaction_name in replaced_interactions))
		replaced_interactions[interaction_name] = list(interaction_name in GLOB.interaction_instances, GLOB.interaction_instances[interaction_name])
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.name = interaction_name
	interaction.category = "Portal unit test"
	interaction.lewd = TRUE
	interaction.user_required_parts = user_parts ? user_parts.Copy() : list()
	interaction.target_required_parts = target_parts ? target_parts.Copy() : list()
	interaction.message = list("%USER_CAPITAL% wave%USER_VERB_S% to %TARGET_OBJECT%.")
	interaction.user_messages = list("%TARGET_CAPITAL% wave%TARGET_VERB_S% to %USER_OBJECT%.")
	interaction.target_messages = list("%USER_CAPITAL% wave%USER_VERB_S% to %TARGET_OBJECT%.")
	GLOB.interaction_instances[interaction_name] = interaction
	return interaction

/// Establishes the same strong reciprocal association used by normal linking.
/datum/unit_test/portal_device/proc/link_pair(
	obj/item/clothing/sextoy/portal_fleshlight/fleshlight,
	obj/item/clothing/sextoy/portal_panties/panties,
)
	fleshlight.linked_panties = panties
	panties.linked_fleshlight = fleshlight

/// Whether the item displays the requested portal overlay.
/datum/unit_test/portal_device/proc/has_portal_overlay_state(obj/item/device, overlay_state)
	for(var/image/overlay as anything in device.overlays)
		if(overlay:icon == 'modular_nova/modules/modular_items/lewd_items/icons/obj/lewd_items/portal.dmi' \
			&& overlay:icon_state == overlay_state)
			return TRUE
	return FALSE

/// Reads the visible shaft layer on the item, independently of the wearer's body overlay.
/datum/unit_test/portal_device/proc/portal_penis_icon_state(obj/item/device)
	for(var/image/overlay as anything in device.overlays)
		if(findtext(overlay:icon_state, "_penis_") && findtext(overlay:icon_state, "_FRONT_UNDER"))
			return overlay:icon_state
	return null

/// Waits for actual timer dispatch, including when testing that no refresh was queued.
/datum/unit_test/portal_device/proc/wait_for_appearance_timers()
	appearance_timers_ran = FALSE
	addtimer(VARSET_CALLBACK(src, appearance_timers_ran, TRUE), 0.2 SECONDS)
	var/deadline = world.time + 2 SECONDS
	UNTIL(appearance_timers_ran || world.time >= deadline)
	return appearance_timers_ran

/// Restores both participants, then makes one either dead or independently incapacitated.
/datum/unit_test/portal_device/proc/set_interaction_test_state(
	mob/living/carbon/human/consistent/portal_interaction_state_test/actor,
	mob/living/carbon/human/consistent/portal_interaction_state_test/target,
	mob/living/carbon/human/consistent/portal_interaction_state_test/stale_participant = null,
	state = null,
)
	for(var/mob/living/carbon/human/consistent/portal_interaction_state_test/participant in list(actor, target))
		participant.set_stat(STABLE)
		REMOVE_TRAIT(participant, TRAIT_INCAPACITATED, PORTAL_INTERACTION_STATE_TEST_TRAIT)
	if(!stale_participant)
		return
	if(state == "dead")
		stale_participant.set_stat(DEAD)
		if(!IS_UNCONSCIOUS_OR_CRIT(stale_participant))
			TEST_FAIL("The dead-state fixture did not satisfy the current unconscious-or-critical contract.")
	else if(state == "incapacitated")
		ADD_TRAIT(stale_participant, TRAIT_INCAPACITATED, PORTAL_INTERACTION_STATE_TEST_TRAIT)
		if(!stale_participant.incapacitated || IS_UNCONSCIOUS_OR_CRIT(stale_participant))
			TEST_FAIL("The incapacitated fixture was not independently incapacitated while otherwise conscious.")

/// Exercises both the UI boundary and direct act() boundary for every stale participant state.
/datum/unit_test/portal_device/proc/check_action_liveness(
	datum/interaction/interaction,
	datum/component/interactable/target_component,
	datum/tgui/ui,
	mob/living/carbon/human/consistent/portal_interaction_state_test/actor,
	mob/living/carbon/human/consistent/portal_interaction_state_test/target,
	obj/effect/lewd_portal_relay/body_relay = null,
	route_name = "direct",
)
	var/datum/component/interactable/actor_component = actor.GetComponent(/datum/component/interactable)
	for(var/stale_role in list("actor", "target"))
		for(var/stale_state in list("dead", "incapacitated"))
			var/mob/living/carbon/human/consistent/portal_interaction_state_test/stale_participant = stale_role == "actor" ? actor : target
			set_interaction_test_state(actor, target, stale_participant, stale_state)
			target_component.interact_next = world.time - 1
			actor_component.interact_next = world.time - 1
			if(target_component.ui_act("interaction", list("interaction" = interaction.name), ui, null))
				TEST_FAIL("The [route_name] interaction UI accepted a [stale_state] [stale_role].")
			var/datum/interaction_route/route = body_relay ? new /datum/interaction_route/portal_relay(body_relay) : null
			if(interaction.act(actor, target, use_subtler = FALSE, route = route))
				TEST_FAIL("The [route_name] interaction act() boundary accepted a [stale_state] [stale_role].")
	set_interaction_test_state(actor, target)

/// Deferred effects must independently revalidate both participants after the action returns.
/datum/unit_test/portal_device/proc/check_effect_liveness(
	datum/interaction/interaction,
	mob/living/carbon/human/consistent/portal_interaction_state_test/actor,
	mob/living/carbon/human/consistent/portal_interaction_state_test/target,
	obj/effect/lewd_portal_relay/body_relay = null,
	route_name = "direct",
)
	for(var/stale_role in list("actor", "target"))
		for(var/stale_state in list("dead", "incapacitated"))
			var/mob/living/carbon/human/consistent/portal_interaction_state_test/stale_participant = stale_role == "actor" ? actor : target
			set_interaction_test_state(actor, target, stale_participant, stale_state)
			actor.portal_test_pain_received = 0
			target.portal_test_pain_received = 0
			var/datum/interaction_route/route = body_relay ? new /datum/interaction_route/portal_relay(body_relay) : null
			interaction.apply_effects(WEAKREF(actor), WEAKREF(target), route)
			if(actor.portal_test_pain_received || target.portal_test_pain_received)
				TEST_FAIL("The [route_name] deferred-effect boundary applied effects with a [stale_state] [stale_role].")
	set_interaction_test_state(actor, target)

/// Detached live organs cannot retain authority across a climax prompt.
/datum/unit_test/portal_device/climax_organ_authority/Run()
	var/mob/living/carbon/human/consistent/participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	attach_portal_preferences(participant)
	var/obj/item/organ/genital/penis/original_penis = configure_test_penis(participant)
	TEST_ASSERT_NOTNULL(original_penis, "Could not create the original climax penis fixture.")
	if(!original_penis)
		return

	var/datum/climax_organs/organs = new
	organs.track(new_penis = original_penis)
	organs.reacquire(participant)
	TEST_ASSERT_EQUAL(organs.penis, original_penis, "An installed climax penis did not resolve as current.")
	original_penis.Remove(participant, special = TRUE)
	TEST_ASSERT(!QDELETED(original_penis), "The detached climax penis fixture was deleted instead of remaining live.")
	organs.reacquire(participant)
	TEST_ASSERT_NULL(organs.penis, "A detached live penis retained climax authority.")

	var/obj/item/organ/genital/penis/replacement_penis = configure_test_penis(participant)
	TEST_ASSERT_NOTNULL(replacement_penis, "Could not create the replacement climax penis fixture.")
	organs.reacquire(participant)
	TEST_ASSERT_NULL(organs.penis, "A replaced penis regained climax authority through its old weak reference.")

	var/obj/item/organ/genital/testicles/original_testicles = allocate(/obj/item/organ/genital/testicles, participant.loc)
	TEST_ASSERT(original_testicles.Insert(participant, special = TRUE), "Could not install the climax testicles fixture.")
	organs.track(new_testicles = original_testicles)
	organs.reacquire(participant)
	TEST_ASSERT_EQUAL(organs.testicles, original_testicles, "Installed climax testicles did not resolve as current.")
	original_testicles.Remove(participant, special = TRUE)
	TEST_ASSERT(!QDELETED(original_testicles), "The detached climax testicles fixture was deleted instead of remaining live.")
	organs.reacquire(participant)
	TEST_ASSERT_NULL(organs.testicles, "Detached live testicles retained climax authority.")

	organs.release()
	TEST_ASSERT_NULL(organs.penis, "release() left a hard reference to the penis behind.")
	TEST_ASSERT_NULL(organs.testicles, "release() left a hard reference to the testicles behind.")

/// Explicit cleanup is silent, reciprocal, and safe to repeat from either peer.
/datum/unit_test/portal_device/reciprocal_clear/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device ownership tests require lewd items to be enabled by the test configuration.")
		return

	var/obj/item/clothing/sextoy/portal_fleshlight/fleshlight = allocate(/obj/item/clothing/sextoy/portal_fleshlight)
	var/obj/item/clothing/sextoy/portal_panties/panties = allocate(/obj/item/clothing/sextoy/portal_panties)
	link_pair(fleshlight, panties)

	TEST_ASSERT(fleshlight.is_link_valid(), "A reciprocal device link was not considered valid.")
	TEST_ASSERT(panties.has_reciprocal_link(), "A reciprocal receiver link was not considered valid.")

	fleshlight.clear_link()
	fleshlight.clear_link()
	TEST_ASSERT_NULL(fleshlight.linked_panties, "Repeated fleshlight cleanup retained its receiver peer.")
	TEST_ASSERT_NULL(panties.linked_fleshlight, "Fleshlight cleanup retained the receiver's reciprocal peer.")
	TEST_ASSERT(!QDELETED(fleshlight) && !QDELETED(panties), "Clearing a link deleted one of its non-owned peers.")

	link_pair(fleshlight, panties)
	panties.clear_link()
	panties.clear_link()
	TEST_ASSERT_NULL(fleshlight.linked_panties, "Receiver cleanup retained the fleshlight's reciprocal peer.")
	TEST_ASSERT_NULL(panties.linked_fleshlight, "Repeated receiver cleanup retained its device peer.")
	TEST_ASSERT(!fleshlight.is_link_valid() && !panties.has_reciprocal_link(), "A cleared pair still reported a valid link.")

/// Deleting either peer leaves its survivor alive, unlinked, and safe to clean again.
/datum/unit_test/portal_device/reciprocal_deletion/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device ownership tests require lewd items to be enabled by the test configuration.")
		return

	var/obj/item/clothing/sextoy/portal_fleshlight/first_fleshlight = allocate(/obj/item/clothing/sextoy/portal_fleshlight)
	var/obj/item/clothing/sextoy/portal_panties/first_panties = allocate(/obj/item/clothing/sextoy/portal_panties)
	link_pair(first_fleshlight, first_panties)

	qdel(first_fleshlight)
	TEST_ASSERT(QDELETED(first_fleshlight), "Deleting a linked fleshlight did not delete it.")
	TEST_ASSERT(!QDELETED(first_panties), "Deleting a fleshlight deleted its non-owned receiver.")
	TEST_ASSERT_NULL(first_panties.linked_fleshlight, "Deleting a fleshlight left its survivor linked.")
	first_panties.clear_link()
	TEST_ASSERT_NULL(first_panties.linked_fleshlight, "Repeated survivor cleanup recreated a stale link.")

	var/obj/item/clothing/sextoy/portal_fleshlight/second_fleshlight = allocate(/obj/item/clothing/sextoy/portal_fleshlight)
	var/obj/item/clothing/sextoy/portal_panties/second_panties = allocate(/obj/item/clothing/sextoy/portal_panties)
	link_pair(second_fleshlight, second_panties)

	qdel(second_panties)
	TEST_ASSERT(QDELETED(second_panties), "Deleting a linked receiver did not delete it.")
	TEST_ASSERT(!QDELETED(second_fleshlight), "Deleting a receiver deleted its non-owned fleshlight.")
	TEST_ASSERT_NULL(second_fleshlight.linked_panties, "Deleting a receiver left its survivor linked.")
	TEST_ASSERT(!second_fleshlight.is_link_valid(), "A fleshlight with a deleted receiver still reported a valid link.")
	second_fleshlight.clear_link()
	TEST_ASSERT_NULL(second_fleshlight.linked_panties, "Repeated survivor cleanup recreated a stale link.")

/// Deleting an equipped receiver clears both the wearer slot and its surviving peer.
/datum/unit_test/portal_device/equipped_receiver_deletion/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device ownership tests require lewd items to be enabled by the test configuration.")
		return

	for(var/slot in list(ITEM_SLOT_MASK, ORGAN_SLOT_PENIS, ORGAN_SLOT_VAGINA, ORGAN_SLOT_ANUS))
		var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
		var/obj/item/clothing/sextoy/portal_fleshlight/fleshlight = allocate(/obj/item/clothing/sextoy/portal_fleshlight)
		var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties)
		var/worn_layer
		receiver.forceMove(wearer)
		if(slot == ITEM_SLOT_MASK)
			wearer.wear_mask = receiver
		else
			TEST_ASSERT(wearer.set_lewd_slot_item(slot, receiver), "Could not place the receiver in [slot].")
			switch(slot)
				if(ORGAN_SLOT_PENIS)
					worn_layer = PENIS_CLOTHING_LAYER
				if(ORGAN_SLOT_VAGINA)
					worn_layer = VAGINA_CLOTHING_LAYER
				if(ORGAN_SLOT_ANUS)
					worn_layer = ANUS_CLOTHING_LAYER
		receiver.update_target(wearer, slot)
		link_pair(fleshlight, receiver)
		if(worn_layer)
			wearer.overlays_standing[worn_layer] = mutable_appearance(receiver.icon, receiver.icon_state, worn_layer)
			TEST_ASSERT_NOTNULL(wearer.overlays_standing[worn_layer], "Could not create the stale [slot] overlay fixture.")

		qdel(receiver)
		TEST_ASSERT(QDELETED(receiver), "Deleting a receiver from [slot] did not delete it.")
		if(slot == ITEM_SLOT_MASK)
			TEST_ASSERT_NULL(wearer.wear_mask, "Deleting a mask receiver left its wearer slot occupied.")
		else
			TEST_ASSERT_NULL(wearer.get_lewd_slot_item(slot), "Deleting a receiver from [slot] left its wearer slot occupied.")
			TEST_ASSERT_NULL(wearer.overlays_standing[worn_layer], "Deleting a receiver from [slot] left its worn overlay behind.")
		TEST_ASSERT_NULL(fleshlight.linked_panties, "Deleting a receiver from [slot] left its surviving peer linked.")

/// Being somewhere in a human's contents is insufficient; the claimed slot must own the receiver.
/datum/unit_test/portal_device/receiver_slot_authority/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device equipment tests require lewd items to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties)
	receiver.forceMove(wearer)

	receiver.current_equipped_slot = ITEM_SLOT_MASK
	receiver.current_target = BODY_ZONE_PRECISE_MOUTH
	TEST_ASSERT_NULL(receiver.get_equipped_wearer(), "A receiver loose in inventory was trusted as an equipped mask.")

	wearer.wear_mask = receiver
	TEST_ASSERT_EQUAL(receiver.get_equipped_wearer(), wearer, "The receiver rejected its authoritative mask-slot wearer.")
	wearer.wear_mask = null
	TEST_ASSERT_NULL(receiver.get_equipped_wearer(), "A removed mask receiver retained authority from stale presentation state.")

	receiver.current_equipped_slot = ORGAN_SLOT_PENIS
	receiver.current_target = ORGAN_SLOT_PENIS
	wearer.penis = receiver
	TEST_ASSERT_EQUAL(receiver.get_equipped_wearer(), wearer, "The receiver rejected its authoritative genital-slot wearer.")
	wearer.penis = null
	TEST_ASSERT_NULL(receiver.get_equipped_wearer(), "A removed genital receiver retained authority from stale presentation state.")
	wearer.vagina = receiver
	TEST_ASSERT_NULL(receiver.get_equipped_wearer(), "A receiver in a different genital slot retained authority for its claimed slot.")
	wearer.vagina = null

	receiver.update_target(wearer)
	TEST_ASSERT_NULL(receiver.current_equipped_slot, "Dropping a receiver retained its claimed equipped slot.")
	TEST_ASSERT_NULL(receiver.current_target, "Dropping a receiver retained its claimed anatomy target.")
	TEST_ASSERT_NULL(receiver.get_equipped_wearer(), "A dropped receiver still resolved an equipped wearer.")

/// The local and receiver validators reject covered mouths, unavailable limbs, and sheathed penises.
/datum/unit_test/portal_device/target_accessibility/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal-device target tests require lewd items to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/local_participant = allocate(/mob/living/carbon/human/consistent)

	TEST_ASSERT(local_participant.portal_target_is_accessible(BODY_ZONE_PRECISE_MOUTH), "An uncovered local mouth was rejected.")
	var/obj/item/clothing/mask/gas/covering_mask = allocate(/obj/item/clothing/mask/gas)
	TEST_ASSERT(local_participant.equip_to_slot_if_possible(covering_mask, ITEM_SLOT_MASK), "The test participant could not equip a mouth-covering mask.")
	TEST_ASSERT(local_participant.is_mouth_covered(), "The test mask did not cover the local mouth.")
	TEST_ASSERT(!local_participant.portal_target_is_accessible(BODY_ZONE_PRECISE_MOUTH), "A covered local mouth was accepted.")
	TEST_ASSERT(local_participant.transferItemToLoc(covering_mask, local_participant.loc, force = TRUE, silent = TRUE), "The test participant could not remove the covering mask.")
	TEST_ASSERT(local_participant.portal_target_is_accessible(BODY_ZONE_PRECISE_MOUTH), "An uncovered local mouth remained rejected after mask removal.")

	var/active_hand_index = local_participant.active_hand_index
	var/obj/item/bodypart/active_hand = local_participant.has_hand_for_held_index(active_hand_index)
	var/active_hand_zone = IS_LEFT_INDEX(active_hand_index) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
	var/inactive_hand_zone = IS_LEFT_INDEX(active_hand_index) ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	TEST_ASSERT_NOTNULL(active_hand, "The test participant did not have a usable active hand.")
	TEST_ASSERT(local_participant.portal_target_is_accessible(active_hand_zone), "The usable active hand was rejected.")
	TEST_ASSERT(!local_participant.portal_target_is_accessible(inactive_hand_zone), "The inactive hand was accepted as the selected local target.")
	if(active_hand)
		active_hand.bodypart_disabled = TRUE
		TEST_ASSERT(!local_participant.portal_target_is_accessible(active_hand_zone), "A disabled active hand was accepted.")
		active_hand.bodypart_disabled = FALSE
	var/inactive_hand_index = local_participant.get_inactive_hand_index()
	var/obj/item/bodypart/inactive_hand = local_participant.has_hand_for_held_index(inactive_hand_index)
	if(inactive_hand)
		local_participant.active_hand_index = inactive_hand_index
		var/switched_hand_zone = IS_LEFT_INDEX(inactive_hand_index) ? BODY_ZONE_L_ARM : BODY_ZONE_R_ARM
		TEST_ASSERT(local_participant.portal_target_is_accessible(switched_hand_zone), "The usable opposite active hand was rejected after switching hands.")
		TEST_ASSERT(!local_participant.portal_target_is_accessible(active_hand_zone), "The former active hand remained accepted after switching hands.")
		local_participant.active_hand_index = active_hand_index

	var/obj/item/bodypart/leg = local_participant.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT_NOTNULL(leg, "The test participant did not have a left leg.")
	if(leg)
		TEST_ASSERT(local_participant.portal_target_is_accessible(BODY_ZONE_L_LEG), "The usable selected leg was rejected.")
		leg.bodypart_disabled = TRUE
		TEST_ASSERT(!local_participant.portal_target_is_accessible(BODY_ZONE_L_LEG), "A disabled selected leg was accepted.")
		leg.bodypart_disabled = FALSE

	var/obj/item/organ/genital/penis/local_penis = configure_test_penis(local_participant)
	TEST_ASSERT_NOTNULL(local_penis, "Could not configure the local test penis.")
	if(!local_penis)
		return
	TEST_ASSERT(local_participant.portal_target_is_accessible(ORGAN_SLOT_PENIS), "An exposed unsheathed local penis was rejected.")
	var/datum/bodypart_overlay/mutant/genital/penis/local_penis_overlay = local_penis.bodypart_overlay
	local_penis_overlay.set_sheath_style(/datum/sprite_accessory/genital/sheath/normal::name)
	local_penis.aroused = AROUSAL_NONE
	local_penis.update_sprite_suffix()
	TEST_ASSERT(local_penis.is_sheathed(), "The local test penis did not enter its configured sheath.")
	TEST_ASSERT(!local_participant.portal_target_is_accessible(ORGAN_SLOT_PENIS), "A sheathed local penis was accepted.")
	local_penis.aroused = AROUSAL_FULL
	local_penis.update_sprite_suffix()
	TEST_ASSERT(!local_penis.is_sheathed(), "The local test penis did not leave its sheath when fully aroused.")
	TEST_ASSERT(local_participant.portal_target_is_accessible(ORGAN_SLOT_PENIS), "An exposed unsheathed local penis remained rejected.")

	var/mob/living/carbon/human/consistent/receiver_wearer = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/sextoy/portal_panties/mouth_receiver = allocate(/obj/item/clothing/sextoy/portal_panties)
	TEST_ASSERT(receiver_wearer.equip_to_slot_if_possible(mouth_receiver, ITEM_SLOT_MASK), "The receiver wearer could not equip the mouth receiver.")
	TEST_ASSERT_EQUAL(mouth_receiver.current_target, BODY_ZONE_PRECISE_MOUTH, "The equipped mask receiver selected the wrong target.")
	TEST_ASSERT(mouth_receiver.receiver_configuration_valid(), "An uncovered receiver mouth was rejected.")
	var/obj/item/clothing/head/utility/bomb_hood/covering_head = allocate(/obj/item/clothing/head/utility/bomb_hood)
	TEST_ASSERT(receiver_wearer.equip_to_slot_if_possible(covering_head, ITEM_SLOT_HEAD), "The receiver wearer could not equip a mouth-covering head item.")
	TEST_ASSERT(receiver_wearer.is_mouth_covered(), "The test head item did not cover the receiver mouth.")
	TEST_ASSERT(!mouth_receiver.receiver_configuration_valid(), "A covered receiver mouth was accepted.")
	TEST_ASSERT(receiver_wearer.transferItemToLoc(covering_head, receiver_wearer.loc, force = TRUE, silent = TRUE), "The receiver wearer could not remove the covering head item.")
	TEST_ASSERT(mouth_receiver.receiver_configuration_valid(), "An uncovered receiver mouth remained rejected after head-item removal.")

	var/obj/item/clothing/sextoy/portal_panties/penis_receiver = allocate(/obj/item/clothing/sextoy/portal_panties)
	var/obj/item/organ/genital/penis/receiver_penis = configure_test_penis(receiver_wearer)
	TEST_ASSERT_NOTNULL(receiver_penis, "Could not configure the receiver test penis.")
	if(!receiver_penis)
		return
	penis_receiver.forceMove(receiver_wearer)
	receiver_wearer.penis = penis_receiver
	penis_receiver.current_equipped_slot = ORGAN_SLOT_PENIS
	penis_receiver.current_target = ORGAN_SLOT_PENIS
	TEST_ASSERT(penis_receiver.receiver_configuration_valid(), "An exposed unsheathed receiver penis was rejected.")
	var/datum/bodypart_overlay/mutant/genital/penis/receiver_penis_overlay = receiver_penis.bodypart_overlay
	receiver_penis_overlay.set_sheath_style(/datum/sprite_accessory/genital/sheath/normal::name)
	receiver_penis.aroused = AROUSAL_NONE
	receiver_penis.update_sprite_suffix()
	TEST_ASSERT(receiver_penis.is_sheathed(), "The receiver test penis did not enter its configured sheath.")
	TEST_ASSERT(!penis_receiver.receiver_configuration_valid(), "A sheathed receiver penis was accepted.")
	receiver_penis.aroused = AROUSAL_FULL
	receiver_penis.update_sprite_suffix()
	TEST_ASSERT(!receiver_penis.is_sheathed(), "The receiver test penis did not leave its sheath when fully aroused.")
	TEST_ASSERT(penis_receiver.receiver_configuration_valid(), "An exposed unsheathed receiver penis remained rejected.")

/// Refreshes linked device appearance when receiver exposure changes.
/datum/unit_test/portal_device/receiver_appearance_refresh/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device appearance tests require lewd items to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_fleshlight/device = allocate(/obj/item/clothing/sextoy/portal_fleshlight, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties, run_loc_floor_bottom_left)
	link_pair(device, receiver)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(receiver, ITEM_SLOT_MASK), "The appearance-test wearer could not equip the receiver as a mask.")
	TEST_ASSERT(device.is_portal_open(), "An uncovered equipped mouth did not open the linked portal device.")
	TEST_ASSERT_EQUAL(device.name, "portal fleshlight", "An open mouth receiver selected the wrong device name.")
	TEST_ASSERT(has_portal_overlay_state(device, "portal_mouth"), "An open mouth receiver rendered no portal-device mouth art.")
	TEST_ASSERT(has_portal_overlay_state(device, "portal_mouth_lips"), "An open mouth receiver rendered no portal-device lip art.")

	var/obj/item/clothing/head/utility/bomb_hood/covering_head = allocate(/obj/item/clothing/head/utility/bomb_hood, run_loc_floor_bottom_left)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(covering_head, ITEM_SLOT_HEAD), "The appearance-test wearer could not equip the mouth-covering head item.")
	TEST_ASSERT(receiver.appearance_refresh_queued, "Covering the receiver mouth did not schedule a linked appearance refresh.")
	receiver.flush_linked_appearance_refresh()
	TEST_ASSERT(!device.is_portal_open(), "Covering the receiver mouth left the portal presentation open.")
	TEST_ASSERT_EQUAL(device.name, initial(device.name), "Closing the portal did not restore the device name.")
	TEST_ASSERT(!has_portal_overlay_state(device, "portal_mouth"), "Closing the portal retained stale mouth art.")
	TEST_ASSERT(!has_portal_overlay_state(device, "portal_mouth_lips"), "Closing the portal retained stale lip art.")

	TEST_ASSERT(wearer.transferItemToLoc(covering_head, wearer.loc, force = TRUE, silent = TRUE), "The appearance-test wearer could not remove the mouth-covering head item.")
	receiver.flush_linked_appearance_refresh()
	TEST_ASSERT(device.is_portal_open(), "Uncovering the receiver mouth did not reopen the portal presentation.")
	TEST_ASSERT_EQUAL(device.name, "portal fleshlight", "Reopening the mouth receiver did not restore the device name.")
	TEST_ASSERT(has_portal_overlay_state(device, "portal_mouth"), "Reopening the mouth receiver did not restore portal-device mouth art.")
	TEST_ASSERT(has_portal_overlay_state(device, "portal_mouth_lips"), "Reopening the mouth receiver did not restore portal-device lip art.")

/// Picking up, redrawing, and dropping unrelated held items must not rebuild the linked device.
/datum/unit_test/portal_device/receiver_ignores_held_item_changes/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal-device appearance tests require lewd items to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_fleshlight/appearance_unit_test/device = allocate(/obj/item/clothing/sextoy/portal_fleshlight/appearance_unit_test, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties, run_loc_floor_bottom_left)
	link_pair(device, receiver)
	TEST_ASSERT(wearer.equip_to_slot_if_possible(receiver, ITEM_SLOT_MASK), "The held-item test wearer could not equip the receiver.")
	TEST_ASSERT(device.is_portal_open(), "The held-item test did not start with an open portal.")
	TEST_ASSERT(wait_for_appearance_timers(), "Setup appearance timers did not run before the held-item test.")
	device.appearance_updates = 0

	var/obj/item/crowbar/held_item = allocate(/obj/item/crowbar, run_loc_floor_bottom_left)
	TEST_ASSERT(wearer.put_in_hands(held_item), "The receiver wearer could not pick up the test item.")
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after item pickup.")
	TEST_ASSERT_EQUAL(device.appearance_updates, 0, "Picking up an unrelated item rebuilt the linked portal device.")

	wearer.update_held_items()
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after the held-item redraw.")
	TEST_ASSERT_EQUAL(device.appearance_updates, 0, "Redrawing held items rebuilt the linked portal device.")

	TEST_ASSERT(wearer.dropItemToGround(held_item), "The receiver wearer could not drop the test item.")
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after dropping the held item.")
	TEST_ASSERT_EQUAL(device.appearance_updates, 0, "Dropping an unrelated held item rebuilt the linked portal device.")

/// Body-driven arousal and standalone size changes both refresh the item's shaft through real timers.
/datum/unit_test/portal_device/receiver_genital_appearance_refresh/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal-device genital appearance tests require lewd items and ERP organs to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/wearer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/organ/genital/penis/test_penis = configure_test_penis(wearer)
	TEST_ASSERT_NOTNULL(test_penis, "Could not configure the appearance-test penis.")
	TEST_ASSERT(test_penis.apply_arousal_label("Not aroused"), "The appearance-test penis could not be made flaccid.")
	var/obj/item/clothing/sextoy/portal_fleshlight/device = allocate(/obj/item/clothing/sextoy/portal_fleshlight, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties, run_loc_floor_bottom_left)
	link_pair(device, receiver)
	receiver.forceMove(wearer)
	TEST_ASSERT(wearer.set_lewd_slot_item(ORGAN_SLOT_PENIS, receiver), "The appearance-test receiver could not occupy the penis slot.")
	receiver.lewd_equipped(wearer, ORGAN_SLOT_PENIS)
	TEST_ASSERT(device.is_portal_open(), "The exposed penis receiver did not open the linked portal device.")
	TEST_ASSERT(wait_for_appearance_timers(), "Setup appearance timers did not run before the genital test.")
	TEST_ASSERT_EQUAL(portal_penis_icon_state(device), "m_penis_human_4_0_FRONT_UNDER", "The portal did not initially render its minimum-size flaccid Human shaft.")

	TEST_ASSERT(test_penis.apply_arousal_label("Very aroused"), "The appearance-test penis could not be made erect.")
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after arousal increased.")
	TEST_ASSERT_EQUAL(portal_penis_icon_state(device), "m_penis_human_4_1_FRONT_UNDER", "A body-driven arousal change did not refresh the portal's erect shaft.")

	test_penis.set_size(49)
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after the standalone size change.")
	TEST_ASSERT_EQUAL(portal_penis_icon_state(device), "m_penis_human_5_1_FRONT_UNDER", "A standalone size change did not refresh the portal's larger shaft.")

	TEST_ASSERT(test_penis.apply_arousal_label("Not aroused"), "The enlarged appearance-test penis could not be made flaccid.")
	TEST_ASSERT(wait_for_appearance_timers(), "Appearance timers did not run after arousal decreased.")
	TEST_ASSERT_EQUAL(portal_penis_icon_state(device), "m_penis_human_5_0_FRONT_UNDER", "A body-driven arousal decrease retained the portal's erect shaft.")

/// The public box path uses its dedicated storage datum and contains exactly one complete kit.
/datum/unit_test/portal_device/packaging_and_disabled_enforcement/Run()
	var/obj/item/storage/box/erp/portal_fleshlight/portal_box = allocate(/obj/item/storage/box/erp/portal_fleshlight)
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_ASSERT(QDELETED(portal_box), "The portal-device box survived while lewd items were disabled.")
		return

	TEST_ASSERT(!QDELETED(portal_box), "The portal-device box was deleted while lewd items were enabled.")
	TEST_ASSERT_EQUAL(portal_box.storage_type, /datum/storage/box/erp/portal_fleshlight, "The portal box used the wrong storage datum path.")
	TEST_ASSERT_EQUAL(length(portal_box.contents), 3, "The portal box did not contain exactly three packaged items.")
	TEST_ASSERT_NOTNULL(locate(/obj/item/clothing/sextoy/portal_fleshlight) in portal_box, "The portal box did not contain a portal device.")
	TEST_ASSERT_NOTNULL(locate(/obj/item/clothing/sextoy/portal_panties) in portal_box, "The portal box did not contain a portal receiver.")
	TEST_ASSERT_NOTNULL(locate(/obj/item/paper/fluff/portal_fleshlight) in portal_box, "The portal box did not contain its instructions.")

/// The built-in routing table is an exact allowlist and contains no urethra fallback.
/datum/unit_test/portal_device/interaction_map/Run()
	var/list/actual_map = /obj/item/clothing/sextoy/portal_fleshlight::interaction_map
	var/list/expected_map = list(
		ORGAN_SLOT_VAGINA = list(
			ORGAN_SLOT_PENIS = "Fuck (vagina)",
			ORGAN_SLOT_VAGINA = "Tribadism",
			BODY_ZONE_PRECISE_MOUTH = "Lick vagina",
			BODY_ZONE_R_ARM = "Finger (vagina)",
			BODY_ZONE_L_ARM = "Finger (vagina)",
			BODY_ZONE_R_LEG = "Footjob (vagina)",
			BODY_ZONE_L_LEG = "Footjob (vagina)",
		),
		ORGAN_SLOT_ANUS = list(
			ORGAN_SLOT_PENIS = "Ass fuck",
			BODY_ZONE_PRECISE_MOUTH = "Eat ass",
			BODY_ZONE_R_ARM = "Finger (ass)",
			BODY_ZONE_L_ARM = "Finger (ass)",
		),
		ORGAN_SLOT_PENIS = list(
			ORGAN_SLOT_PENIS = "Frot",
			ORGAN_SLOT_VAGINA = "Ride cock (vagina)",
			ORGAN_SLOT_ANUS = "Ride cock (ass)",
			BODY_ZONE_PRECISE_MOUTH = "Blowjob",
			BODY_ZONE_R_ARM = "Handjob",
			BODY_ZONE_L_ARM = "Handjob",
			BODY_ZONE_R_LEG = "Footjob (cock)",
			BODY_ZONE_L_LEG = "Footjob (cock)",
		),
		BODY_ZONE_PRECISE_MOUTH = list(
			ORGAN_SLOT_PENIS = "Mouth fuck",
			BODY_ZONE_PRECISE_MOUTH = "Tongue kiss",
		),
	)

	TEST_ASSERT(deep_compare_list(actual_map, expected_map), "The portal-device interaction allowlist drifted from the live-config contract.")

/// The central validator rejects stale authority and derives cooldown state from both participants.
/datum/unit_test/portal_device/validator_authority_and_cooldown/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal-device validator tests require lewd items to be enabled by the test configuration.")
		return

	var/datum/interaction/tongue_kiss = install_interaction_fixture()

	var/mob/living/carbon/human/consistent/local_participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/remote_participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/client_interface/local_client = attach_portal_preferences(local_participant)
	var/datum/client_interface/remote_client = attach_portal_preferences(remote_participant)
	var/obj/item/clothing/sextoy/portal_fleshlight/device = allocate(/obj/item/clothing/sextoy/portal_fleshlight, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties, run_loc_floor_bottom_left)
	link_pair(device, receiver)

	TEST_ASSERT(local_participant.put_in_active_hand(device, forced = TRUE), "The local participant could not hold the portal device.")
	TEST_ASSERT(remote_participant.equip_to_slot_if_possible(receiver, ITEM_SLOT_MASK), "The remote participant could not equip the receiver as a mask.")
	TEST_ASSERT_EQUAL(receiver.get_equipped_wearer(), remote_participant, "The receiver did not derive authority from the equipped mask slot.")

	var/datum/component/interactable/local_component = local_participant.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/remote_component = remote_participant.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(local_component, "The local participant lacked an interaction component.")
	TEST_ASSERT_NOTNULL(remote_component, "The remote participant lacked an interaction component.")
	if(!local_component || !remote_component)
		return
	local_component.interact_next = world.time - 1
	remote_component.interact_next = world.time - 1

	TEST_ASSERT_EQUAL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), tongue_kiss, "A fully authoritative mouth-to-mouth device route did not resolve its live interaction.")
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_CHEST, device), "The validator accepted an unsupported local body-part combination.")

	remote_participant.wear_mask = null
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), "A receiver merely retained in inventory was trusted after its authoritative slot was cleared.")
	remote_participant.wear_mask = receiver

	TEST_ASSERT(remote_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not disable the remote sex-toy preference.")
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), "The validator accepted a sex-toy preference refusal.")
	TEST_ASSERT(remote_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE), "Could not restore the remote sex-toy preference.")
	TEST_ASSERT(remote_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp], FALSE), "Could not disable the remote ERP preference.")
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), "The validator accepted an ERP preference refusal.")
	TEST_ASSERT(remote_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp], TRUE), "Could not restore the remote ERP preference.")
	TEST_ASSERT(local_client.prefs.read_preference(/datum/preference/toggle/erp/sex_toy), "The local participant lost its canonical sex-toy preference during validation.")

	GLOB.interaction_instances["Tongue kiss"] = null
	var/datum/interaction/missing_config_result = device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device)
	GLOB.interaction_instances["Tongue kiss"] = tongue_kiss
	TEST_ASSERT_NULL(missing_config_result, "The validator accepted a missing live interaction configuration.")

	local_component.interact_next = world.time + INTERACTION_COOLDOWN
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), "The validator accepted a local participant whose interaction cooldown was active.")
	local_component.interact_next = world.time - 1
	remote_component.interact_next = world.time - 1
	device.apply_interaction_cooldown(local_participant, remote_participant)
	TEST_ASSERT(local_component.interact_next > world.time, "Applying a portal interaction did not start the local cooldown.")
	TEST_ASSERT_EQUAL(remote_component.interact_next, local_component.interact_next, "Portal interaction cooldowns diverged between participants.")
	TEST_ASSERT_NULL(device.validate_interaction(local_participant, local_participant, receiver, BODY_ZONE_PRECISE_MOUTH, device), "The validator ignored the shared cooldown it had just applied.")

/// UI actions bind authority to the actual UI object, never forged reference parameters.
/datum/unit_test/portal_device/ui_authority/Run()
	var/mob/living/carbon/human/consistent/actor = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/decoy = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/component/interactable/actor_component = actor.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/target_component = target.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(actor_component, "The UI actor lacked an interaction component.")
	TEST_ASSERT_NOTNULL(target_component, "The UI target lacked an interaction component.")
	if(!actor_component || !target_component)
		return

	var/datum/tgui/valid_ui = allocate(/datum/tgui, actor, target_component, "InteractionPanel")
	var/initial_subtler = target_component.use_subtler
	var/valid_result = target_component.ui_act(
		"toggle_subtler",
		list("userref" = REF(decoy), "selfref" = REF(decoy)),
		valid_ui,
		null,
	)
	TEST_ASSERT(valid_result, "A UI owned by the component and actor was rejected.")
	TEST_ASSERT_NOTEQUAL(target_component.use_subtler, initial_subtler, "Forged legacy refs displaced the UI's authoritative actor or component parent.")

	var/datum/tgui/foreign_ui = allocate(/datum/tgui, actor, actor_component, "InteractionPanel")
	var/authoritative_subtler = target_component.use_subtler
	var/foreign_result = target_component.ui_act("toggle_subtler", list(), foreign_ui, null)
	TEST_ASSERT(!foreign_result, "A UI owned by a foreign component was accepted.")
	TEST_ASSERT_EQUAL(target_component.use_subtler, authoritative_subtler, "A foreign UI mutated the target component.")

/// Public buckling rejects non-humans, preference refusal, missing pairs, and occupied peers before mutation.
/datum/unit_test/portal_device/public_buckle_guards/Run()
	if(CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Portal buckle tests require lewd items to be enabled by the test configuration.")
		return

	var/mob/living/carbon/human/consistent/portal_unit_test/operator = allocate(/mob/living/carbon/human/consistent/portal_unit_test, run_loc_floor_bottom_left)
	var/obj/structure/lewd_portal/unlinked_portal = allocate(/obj/structure/lewd_portal, run_loc_floor_bottom_left)
	TEST_ASSERT(!unlinked_portal.user_buckle_mob(operator, operator, check_loc = FALSE), "The public buckle path accepted an unlinked portal.")
	TEST_ASSERT_NULL(unlinked_portal.current_mob, "A rejected unlinked buckle mutated portal occupancy.")
	TEST_ASSERT_NULL(unlinked_portal.relayed_body, "A rejected unlinked buckle created a relay.")

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/basic/mouse/nonhuman = allocate(/mob/living/basic/mouse, run_loc_floor_bottom_left)
	TEST_ASSERT(!source_portal.user_buckle_mob(nonhuman, operator, check_loc = FALSE), "The public buckle path accepted a non-human occupant.")

	operator.portal_test_sex_toy_preference = FALSE
	TEST_ASSERT(!source_portal.user_buckle_mob(operator, operator, check_loc = FALSE), "The public buckle path ignored a sex-toy preference refusal.")
	operator.portal_test_sex_toy_preference = TRUE

	var/mob/living/carbon/human/consistent/peer_occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	receiving_portal.current_mob = peer_occupant
	TEST_ASSERT(!source_portal.user_buckle_mob(operator, operator, check_loc = FALSE), "The public buckle path accepted an occupied peer endpoint.")
	TEST_ASSERT_NULL(source_portal.current_mob, "A rejected occupied-pair buckle mutated source occupancy.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "A rejected occupied-pair buckle created a relay.")
	receiving_portal.current_mob = null

	var/mob/living/carbon/human/consistent/consenting_occupant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/datum/client_interface/consenting_client = attach_portal_preferences(consenting_occupant)
	TEST_ASSERT(source_portal.buckle_mob(consenting_occupant, force = FALSE, check_loc = FALSE), "The final public buckle hook rejected a currently consenting occupant.")
	source_portal.end_session()
	TEST_ASSERT(consenting_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not revoke final-hook sex-toy consent.")
	TEST_ASSERT(!source_portal.buckle_mob(consenting_occupant, force = FALSE, check_loc = FALSE), "The final public buckle hook retained stale sex-toy consent.")
	TEST_ASSERT_NULL(source_portal.current_mob, "A stale-consent buckle mutated source occupancy.")
	TEST_ASSERT_NULL(source_portal.relayed_body, "A stale-consent buckle created a relay.")

/// Explicit integration coverage for a deployment supplying the complete portal interaction configuration.
/datum/unit_test/portal_device/live_configuration/Run()
#ifndef TEST_PORTAL_LIVE_CONFIG
	TEST_NOTICE(src, "Optional live portal configuration check; enable TEST_PORTAL_LIVE_CONFIG with the full interaction configuration.")
	return
#endif
	var/list/expected_parts = list(
		"Fuck (vagina)" = list(list(ORGAN_SLOT_PENIS), list(ORGAN_SLOT_VAGINA)),
		"Tribadism" = list(list(ORGAN_SLOT_VAGINA), list(ORGAN_SLOT_VAGINA)),
		"Lick vagina" = list(list(), list(ORGAN_SLOT_VAGINA)),
		"Finger (vagina)" = list(list(), list(ORGAN_SLOT_VAGINA)),
		"Footjob (vagina)" = list(list(), list(ORGAN_SLOT_VAGINA)),
		"Ass fuck" = list(list(ORGAN_SLOT_PENIS), list(ORGAN_SLOT_ANUS)),
		"Eat ass" = list(list(), list(ORGAN_SLOT_ANUS)),
		"Finger (ass)" = list(list(), list(ORGAN_SLOT_ANUS)),
		"Frot" = list(list(ORGAN_SLOT_PENIS), list(ORGAN_SLOT_PENIS)),
		"Ride cock (vagina)" = list(list(ORGAN_SLOT_VAGINA), list(ORGAN_SLOT_PENIS)),
		"Ride cock (ass)" = list(list(ORGAN_SLOT_ANUS), list(ORGAN_SLOT_PENIS)),
		"Blowjob" = list(list(), list(ORGAN_SLOT_PENIS)),
		"Handjob" = list(list(), list(ORGAN_SLOT_PENIS)),
		"Footjob (cock)" = list(list(), list(ORGAN_SLOT_PENIS)),
		"Mouth fuck" = list(list(ORGAN_SLOT_PENIS), list()),
		"Tongue kiss" = list(list(), list()),
	)

	var/mob/living/carbon/human/consistent/recipient = allocate(/mob/living/carbon/human/consistent)
	recipient.name = "Portal Message Recipient"
	for(var/interaction_name in expected_parts)
		var/datum/interaction/interaction = GLOB.interaction_instances[interaction_name]
		TEST_ASSERT_NOTNULL(interaction, "The optional live configuration lacks '[interaction_name]'.")
		var/list/interaction_parts = expected_parts[interaction_name]
		TEST_ASSERT(interaction.lewd, "Portal interaction '[interaction_name]' was not marked lewd.")
		TEST_ASSERT_EQUAL(interaction.usage, INTERACTION_OTHER, "Portal interaction '[interaction_name]' had incompatible usage.")
		TEST_ASSERT_NOTEQUAL(interaction.category, INTERACTION_CAT_HIDE, "Portal interaction '[interaction_name]' was hidden.")
		TEST_ASSERT(deep_compare_list(interaction.user_required_parts, interaction_parts[1]), "Portal interaction '[interaction_name]' had incompatible user body-part requirements.")
		TEST_ASSERT(deep_compare_list(interaction.target_required_parts, interaction_parts[2]), "Portal interaction '[interaction_name]' had incompatible target body-part requirements.")
		for(var/list/private_messages in list(interaction.user_messages, interaction.target_messages))
			for(var/message_template in private_messages)
				var/formatted_message = interaction.format_message_for(message_template, recipient, recipient, recipient = recipient)
				TEST_ASSERT(!findtext(formatted_message, recipient.name), "Self-interaction '[interaction_name]' referred to the recipient by name.")
				TEST_ASSERT(!findtext(formatted_message, "%"), "Interaction '[interaction_name]' left a template token unexpanded.")
				TEST_ASSERT(!findtext(formatted_message, "you's"), "Interaction '[interaction_name]' used an invalid second-person possessive.")

/// Message expansion anonymizes each participant independently while administrative formatting keeps real identities.
/datum/unit_test/portal_device/message_anonymity/Run()
	var/datum/interaction/interaction = allocate(/datum/interaction)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	user.name = "Portal User"
	user.gender = FEMALE
	target.name = "Portal Target"
	target.gender = MALE

	var/message_template = "%USER% greets %TARGET%; %USER_PRONOUN_THEIR% hands move while %TARGET_PRONOUN_THEM% watches and %TARGET_PRONOUN_THEY% nods."
	var/plain_message = interaction.format_message_for(message_template, user, target)
	TEST_ASSERT(findtext(plain_message, user.name), "Nonanonymous formatting omitted the user's real name.")
	TEST_ASSERT(findtext(plain_message, target.name), "Nonanonymous formatting omitted the target's real name.")
	TEST_ASSERT(findtext(plain_message, user.p_their()), "Nonanonymous formatting omitted the user's real pronoun.")
	TEST_ASSERT(findtext(plain_message, target.p_them()), "Nonanonymous formatting omitted the target's real object pronoun.")
	TEST_ASSERT(findtext(plain_message, target.p_they()), "Nonanonymous formatting omitted the target's real subject pronoun.")

	var/user_anonymous_message = interaction.format_message_for(
		message_template,
		user,
		target,
		user_anonymous = TRUE,
	)
	TEST_ASSERT(!findtext(user_anonymous_message, user.name), "User anonymity leaked the user's real name.")
	TEST_ASSERT(findtext(user_anonymous_message, target.name), "User anonymity hid the nonanonymous target name.")
	TEST_ASSERT(findtext(user_anonymous_message, "their"), "User anonymity did not neutralize the user's possessive pronoun.")
	TEST_ASSERT(findtext(user_anonymous_message, target.p_them()), "User anonymity changed the nonanonymous target's object pronoun.")

	var/target_anonymous_message = interaction.format_message_for(
		message_template,
		user,
		target,
		target_anonymous = TRUE,
	)
	TEST_ASSERT(findtext(target_anonymous_message, user.name), "Target anonymity hid the nonanonymous user name.")
	TEST_ASSERT(!findtext(target_anonymous_message, target.name), "Target anonymity leaked the target's real name.")
	TEST_ASSERT(findtext(target_anonymous_message, "them"), "Target anonymity did not neutralize the target's object pronoun.")
	TEST_ASSERT(findtext(target_anonymous_message, "they"), "Target anonymity did not neutralize the target's subject pronoun.")
	TEST_ASSERT(findtext(target_anonymous_message, user.p_their()), "Target anonymity changed the nonanonymous user's possessive pronoun.")

	var/both_anonymous_message = interaction.format_message_for(
		message_template,
		user,
		target,
		user_anonymous = TRUE,
		target_anonymous = TRUE,
	)
	TEST_ASSERT(!findtext(both_anonymous_message, user.name), "Combined anonymity leaked the user's real name.")
	TEST_ASSERT(!findtext(both_anonymous_message, target.name), "Combined anonymity leaked the target's real name.")
	TEST_ASSERT(findtext(both_anonymous_message, "Unknown"), "Combined anonymity did not replace the participant names.")

	var/admin_message = interaction.format_message_for(message_template, user, target, omit_user = TRUE)
	TEST_ASSERT(!findtext(admin_message, user.name), "Administrative formatting unexpectedly exposed the omitted user name.")
	TEST_ASSERT(findtext(admin_message, target.name), "Administrative formatting lost the target's real name.")
	TEST_ASSERT(!findtext(admin_message, "Unknown"), "Administrative formatting substituted an anonymous placeholder.")

/// Private messages address their reader, including when one person supplies both portal participants.
/datum/unit_test/portal_device/message_recipient/Run()
	var/datum/interaction/interaction = allocate(/datum/interaction)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	user.name = "Portal User"
	user.gender = FEMALE
	target.name = "Portal Target"
	target.gender = MALE

	var/ownership_template = "Your sleeve brushes %USER%'s coat and %TARGET%'s scarf."
	TEST_ASSERT_EQUAL(interaction.format_message_for(ownership_template, user, target, recipient = target), "Your sleeve brushes Portal User's coat and your scarf.", "A target-private message attributed their own possession to a third person.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(ownership_template, user, user, recipient = user), "Your sleeve brushes your own coat and your own scarf.", "Self-interaction possessions should address their owner reflexively.")
	TEST_ASSERT_EQUAL(interaction.format_message_for("%TARGET_CAPITAL%'s sleeve brushes yours.", user, user, recipient = user), "Your own sleeve brushes yours.", "Sentence-initial possessives should remain capitalized.")

	var/subject_template = "%USER_CAPITAL% reach%USER_VERB_ES% toward %TARGET_OBJECT% with %USER_PRONOUN_THEIR% hand."
	TEST_ASSERT_EQUAL(interaction.format_message_for(subject_template, user, target, recipient = target), "Portal User reaches toward you with her hand.", "A target-private message changed the other participant's subject or verb.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(subject_template, user, target, recipient = user), "You reach toward Portal Target with your hand.", "A user-private message should address its reader in second person.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(subject_template, user, user, recipient = user), "You reach toward yourself with your hand.", "Self-interactions need second-person verbs and reflexive objects.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(subject_template, user, target), "Portal User reaches toward Portal Target with her hand.", "Observer formatting should retain third-person names and verbs.")

	var/reversed_template = "%TARGET_CAPITAL% wave%TARGET_VERB_S% to %USER_OBJECT%."
	TEST_ASSERT_EQUAL(interaction.format_message_for(reversed_template, user, target, recipient = user), "Portal Target waves to you.", "Reversed participant roles should preserve the other person's subject.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(reversed_template, user, target, recipient = target), "You wave to Portal User.", "Target subjects need second-person verb agreement.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(reversed_template, user, user, recipient = user), "You wave to yourself.", "Reversed self-interactions need reflexive objects.")

	var/pronoun_template = "%USER_PRONOUN_THEIR% / %USER_PRONOUN_THEIRS% / %USER_PRONOUN_THEM% / %USER_PRONOUN_THEY% / %USER_PRONOUN_THEMSELVES%"
	TEST_ASSERT_EQUAL(interaction.format_message_for(pronoun_template, user, target, recipient = user), "your / yours / you / you / yourself", "Private pronouns should address the reader.")
	TEST_ASSERT_EQUAL(interaction.format_message_for(pronoun_template, user, user, recipient = user), "your / yours / yourself / you / yourself", "Known self-interactions need reflexive object pronouns.")

/// Addressing a private recipient must not reveal that an anonymous counterpart belongs to them.
/datum/unit_test/portal_device/message_recipient_anonymity/Run()
	var/datum/interaction/interaction = allocate(/datum/interaction)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	user.name = "Portal User"
	user.gender = FEMALE
	var/message_template = "%USER_CAPITAL% wave%USER_VERB_S% to %TARGET_OBJECT% with %USER_PRONOUN_THEIR% hand; %TARGET%'s sleeve brushes %USER%'s coat."
	TEST_ASSERT_EQUAL(interaction.format_message_for(message_template, user, user, user_anonymous = TRUE, recipient = user), "Unknown waves to you with their hand; your sleeve brushes Unknown's coat.", "A private target message exposed an anonymous self-interaction through identity, pronouns, or reflexivity.")
	var/reversed_template = "%TARGET_CAPITAL% wave%TARGET_VERB_S% to %USER_OBJECT% with %TARGET_PRONOUN_THEIR% hand; %USER%'s sleeve brushes %TARGET%'s coat."
	TEST_ASSERT_EQUAL(interaction.format_message_for(reversed_template, user, user, target_anonymous = TRUE, recipient = user), "Unknown waves to you with their hand; your sleeve brushes Unknown's coat.", "A private user message exposed an anonymous self-interaction through identity, pronouns, or reflexivity.")
	TEST_ASSERT_EQUAL(interaction.format_message_for("%USER_PRONOUN_THEMSELVES%", user, user, user_anonymous = TRUE, recipient = user), "themselves", "An anonymous reflexive pronoun exposed the recipient's identity.")

/// Weakref-backed portal-device contexts revalidate identity, equipment, links, and non-cooldown authority.
/datum/unit_test/portal_device/context_revalidation/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal-device context tests require lewd items and ERP preferences to be enabled by the test configuration.")
		return

	var/datum/interaction/tongue_kiss = install_interaction_fixture()

	var/mob/living/carbon/human/consistent/local_participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/remote_participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/decoy_participant = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	attach_portal_preferences(local_participant)
	attach_portal_preferences(remote_participant)
	attach_portal_preferences(decoy_participant)
	var/obj/item/clothing/sextoy/portal_fleshlight/device = allocate(/obj/item/clothing/sextoy/portal_fleshlight, run_loc_floor_bottom_left)
	var/obj/item/clothing/sextoy/portal_panties/receiver = allocate(/obj/item/clothing/sextoy/portal_panties, run_loc_floor_bottom_left)
	link_pair(device, receiver)

	TEST_ASSERT(local_participant.put_in_active_hand(device, forced = TRUE), "The local participant could not hold the portal device.")
	TEST_ASSERT(remote_participant.equip_to_slot_if_possible(receiver, ITEM_SLOT_MASK), "The remote participant could not equip the receiver as a mask.")
	var/datum/component/interactable/local_component = local_participant.GetComponent(/datum/component/interactable)
	var/datum/component/interactable/remote_component = remote_participant.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(local_component, "The local participant lacked an interaction component.")
	TEST_ASSERT_NOTNULL(remote_component, "The remote participant lacked an interaction component.")
	if(!local_component || !remote_component)
		return
	local_component.interact_next = world.time - 1
	remote_component.interact_next = world.time - 1

	var/datum/interaction_route/portal_device/route = new(device, local_participant, receiver, device, BODY_ZONE_PRECISE_MOUTH)
	TEST_ASSERT(route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
	), "A fully authoritative live portal-device context was rejected.")

	remote_participant.incapacitated = TRUE
	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
	), "A portal-device context with an incapacitated remote participant was accepted.")
	remote_participant.incapacitated = FALSE

	var/obj/item/clothing/sextoy/portal_panties/linked_receiver = device.linked_panties
	device.linked_panties = null
	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
	), "A stale device link was accepted by portal-device context validation.")
	device.linked_panties = linked_receiver

	remote_participant.wear_mask = null
	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
	), "A receiver removed from its authoritative slot was accepted by portal-device context validation.")
	remote_participant.wear_mask = receiver

	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		decoy_participant,
	), "A receiver context was accepted for a forged target participant.")

	local_component.interact_next = world.time + INTERACTION_COOLDOWN
	remote_component.interact_next = world.time + INTERACTION_COOLDOWN
	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
	), "A portal-device context with an active cooldown was accepted without an override.")
	TEST_ASSERT(route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
		ignore_cooldown = TRUE,
	), "Ignoring cooldown rejected an otherwise authoritative portal-device context.")

	remote_participant.wear_mask = null
	TEST_ASSERT(!route.is_still_valid(
		tongue_kiss,
		local_participant,
		remote_participant,
		ignore_cooldown = TRUE,
	), "Ignoring cooldown bypassed receiver equipment authority.")

	receiver.forceMove(local_participant)
	local_participant.wear_mask = receiver
	receiver.update_target(local_participant, ITEM_SLOT_MASK)
	local_component.interact_next = world.time - 1
	var/datum/interaction_route/portal_device/self_route = new(device, local_participant, receiver, device, BODY_ZONE_PRECISE_MOUTH)
	TEST_ASSERT(!tongue_kiss.allow_act(local_participant, local_participant), "An ordinary other-person interaction accepted one mob in both roles.")
	TEST_ASSERT(tongue_kiss.allow_act(local_participant, local_participant, allow_same_participant = TRUE), "A split portal route could not treat its two endpoints as separate roles.")
	TEST_ASSERT(self_route.is_still_valid(
		tongue_kiss,
		local_participant,
		local_participant,
	), "A wearer could not interact with their own receiver through the linked device.")

	local_participant.dropItemToGround(device, force = TRUE)
	TEST_ASSERT(decoy_participant.put_in_active_hand(device, forced = TRUE), "The third-party operator could not hold the portal device.")
	var/datum/interaction_route/portal_device/third_party_self_route = new(device, decoy_participant, receiver, device, BODY_ZONE_PRECISE_MOUTH)
	TEST_ASSERT(!third_party_self_route.is_still_valid(
		tongue_kiss,
		local_participant,
		local_participant,
	), "A third party could make one wearer fill both portal roles.")

/// Relay genital reveals require the active session and both participants' sex-toy preferences.
/datum/unit_test/portal_device/relay_reveal_authority/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Relay reveal tests require lewd items and ERP preferences to be enabled by the test configuration.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent, receiving_portal.loc)
	var/datum/client_interface/owner_client = attach_portal_preferences(owner)
	var/datum/client_interface/viewer_client = attach_portal_preferences(viewer)

	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The portal pair could not establish a relay session for reveal validation.")
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	TEST_ASSERT_NOTNULL(relay, "The portal pair did not create a relay for reveal validation.")
	if(!relay)
		return

	TEST_ASSERT(relay.can_reveal_to(viewer), "An active relay with both participants opted in was not revealable.")

	TEST_ASSERT(viewer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not disable the viewer sex-toy preference.")
	TEST_ASSERT(!relay.can_reveal_to(viewer), "Relay reveal ignored the viewer's sex-toy preference refusal.")
	TEST_ASSERT(viewer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE), "Could not restore the viewer sex-toy preference.")

	TEST_ASSERT(owner_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not disable the owner sex-toy preference.")
	TEST_ASSERT(!relay.can_reveal_to(viewer), "Relay reveal ignored the owner's sex-toy preference refusal.")
	TEST_ASSERT(owner_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE), "Could not restore the owner sex-toy preference.")

	source_portal.unbuckle_mob(owner, force = TRUE, can_fall = FALSE)
	TEST_ASSERT(!relay.can_reveal_to(viewer), "A relay from an ended portal session remained revealable.")

/// Keeps portal Subtler prompts tied to their offered relay.
/datum/unit_test/portal_device/subtler_portal_session/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal Subtler tests require lewd items and ERP preferences to be enabled by the test configuration.")
		return

	var/datum/emote/living/subtler/subtler_emote = allocate(/datum/emote/living/subtler)
	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	attach_portal_preferences(owner)

	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The first Subtler portal session could not start.")
	var/obj/effect/lewd_portal_relay/first_relay = source_portal.relayed_body
	var/datum/weakref/first_relay_ref = WEAKREF(first_relay)
	TEST_ASSERT_EQUAL(owner.resolve_portal_output(first_relay_ref), first_relay, "Subtler rejected the exact live relay it offered.")
	TEST_ASSERT(!subtler_emote.send_portal_subtler(owner, first_relay, "tests", NONE, " ", sender_message = "marker"), "Subtler delivered a relay message back to its owner.")

	source_portal.end_session()
	TEST_ASSERT(QDELETED(first_relay), "Ending the first Subtler portal session did not delete its relay.")
	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The replacement Subtler portal session could not start.")
	TEST_ASSERT_NOTEQUAL(source_portal.relayed_body, first_relay, "The replacement Subtler session reused its deleted relay.")
	TEST_ASSERT_NULL(owner.resolve_portal_output(first_relay_ref), "A prompt from the first Subtler session resolved through its replacement session.")

/// Ordinary interactions accept direct adjacency or the exact current portal relay, never an unbound or stale relay.
/datum/unit_test/portal_device/ordinary_position_authority/Run()
	var/datum/interaction/interaction = allocate(/datum/interaction)
	var/mob/living/carbon/human/consistent/direct_user = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/direct_target = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	TEST_ASSERT(interaction.interaction_route_is_valid(null, direct_user, direct_target), "Directly adjacent ordinary participants were rejected.")

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	receiving_portal.forceMove(run_loc_floor_top_right)
	var/mob/living/carbon/human/consistent/relay_user = allocate(/mob/living/carbon/human/consistent, receiving_portal.loc)
	var/mob/living/carbon/human/consistent/relay_target = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	TEST_ASSERT(source_portal.buckle_mob(relay_target, force = TRUE, check_loc = FALSE), "The portal pair could not establish the relay session for position validation.")
	var/obj/effect/lewd_portal_relay/current_relay = source_portal.relayed_body
	TEST_ASSERT_NOTNULL(current_relay, "The portal pair did not create a relay for position validation.")
	if(!current_relay)
		return

	TEST_ASSERT(!interaction.interaction_route_is_valid(null, relay_user, relay_target), "A nonadjacent ordinary interaction was accepted without a relay.")

	var/datum/interaction_route/portal_relay/current_route = new(current_relay)
	TEST_ASSERT(interaction.interaction_route_is_valid(current_route, relay_user, relay_target), "The exact active portal relay was rejected for an ordinary interaction.")

	var/mob/living/carbon/human/consistent/unbound_owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/obj/effect/lewd_portal_relay/unbound_relay = allocate(/obj/effect/lewd_portal_relay, receiving_portal.loc, unbound_owner, receiving_portal)
	var/datum/interaction_route/portal_relay/unbound_route = new(unbound_relay)
	TEST_ASSERT(!interaction.interaction_route_is_valid(unbound_route, relay_user, relay_target), "An unbound relay was accepted for an ordinary interaction.")
	TEST_ASSERT(interaction.interaction_route_is_valid(current_route, relay_user, relay_target), "Constructing an unbound relay invalidated the active relay fixture.")

	qdel(current_relay)
	TEST_ASSERT(!interaction.interaction_route_is_valid(current_route, relay_user, relay_target), "A stale relay was accepted after its session ended.")

/// Ordinary and relay interactions reject dead or independently incapacitated participants at every execution boundary.
/datum/unit_test/portal_device/interaction_liveness_boundaries/Run()
	var/datum/interaction/action_interaction = install_interaction_fixture(PORTAL_INTERACTION_STATE_TEST_ID)
	action_interaction.lewd = FALSE
	var/datum/interaction/effect_interaction = allocate(/datum/interaction)
	effect_interaction.name = PORTAL_INTERACTION_STATE_TEST_ID
	effect_interaction.category = "Unit test"
	effect_interaction.usage = INTERACTION_OTHER
	effect_interaction.message = list("%USER% tests %TARGET%.")
	effect_interaction.user_pain = 2
	effect_interaction.target_pain = 3

	var/mob/living/carbon/human/consistent/portal_interaction_state_test/direct_actor = allocate(/mob/living/carbon/human/consistent/portal_interaction_state_test, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/portal_interaction_state_test/direct_target = allocate(/mob/living/carbon/human/consistent/portal_interaction_state_test, run_loc_floor_bottom_left)
	var/datum/component/interactable/direct_target_component = direct_target.GetComponent(/datum/component/interactable)
	var/datum/tgui/direct_ui = allocate(/datum/tgui, direct_actor, direct_target_component, "InteractionPanel")
	if(!direct_target_component || !direct_actor.GetComponent(/datum/component/interactable))
		TEST_FAIL("The direct liveness fixtures did not receive interaction components.")
	else
		check_action_liveness(action_interaction, direct_target_component, direct_ui, direct_actor, direct_target, route_name = "direct")
		check_effect_liveness(effect_interaction, direct_actor, direct_target, route_name = "direct")
	set_interaction_test_state(direct_actor, direct_target)
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Relay liveness coverage requires portal preferences; direct interaction checks ran.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	receiving_portal.forceMove(run_loc_floor_top_right)
	var/mob/living/carbon/human/consistent/portal_interaction_state_test/relay_actor = allocate(/mob/living/carbon/human/consistent/portal_interaction_state_test, receiving_portal.loc)
	var/mob/living/carbon/human/consistent/portal_interaction_state_test/relay_target = allocate(/mob/living/carbon/human/consistent/portal_interaction_state_test, source_portal.loc)
	attach_portal_preferences(relay_actor)
	attach_portal_preferences(relay_target)
	var/datum/component/interactable/relay_target_component = relay_target.GetComponent(/datum/component/interactable)
	var/datum/tgui/relay_ui = allocate(/datum/tgui, relay_actor, relay_target_component, "InteractionPanel")
	if(!source_portal.buckle_mob(relay_target, force = TRUE, check_loc = FALSE))
		TEST_FAIL("The relay liveness fixtures could not establish a portal session.")
	else if(!source_portal.relayed_body || !relay_target_component || !relay_actor.GetComponent(/datum/component/interactable))
		TEST_FAIL("The relay liveness fixtures did not receive a relay and interaction components.")
	else
		var/datum/interaction_route/portal_relay/live_route = allocate(/datum/interaction_route/portal_relay, source_portal.relayed_body)
		TEST_ASSERT(action_interaction.can_execute(relay_actor, relay_target, live_route, ignore_cooldown = TRUE), "The healthy relay fixture could not act before its liveness checks.")
		check_action_liveness(action_interaction, relay_target_component, relay_ui, relay_actor, relay_target, source_portal.relayed_body, "relay")
		check_effect_liveness(effect_interaction, relay_actor, relay_target, source_portal.relayed_body, "relay")

	set_interaction_test_state(relay_actor, relay_target)

/// Flipping a relay reaches neither the mutation nor feedback branch after session or preference authority expires.
/datum/unit_test/portal_device/relay_flip_authority/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Relay flip tests require lewd items and ERP preferences to be enabled by the test configuration.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent, receiving_portal.loc)
	var/datum/client_interface/owner_client = attach_portal_preferences(owner)
	var/datum/client_interface/viewer_client = attach_portal_preferences(viewer)
	if(!source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE))
		TEST_FAIL("The portal pair could not establish a relay session for flip validation.")
		return
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	if(!relay)
		TEST_FAIL("The portal pair did not create a relay for flip validation.")
		return

	var/initial_direction = relay.dir
	relay.attack_hand_secondary(viewer)
	TEST_ASSERT_NOTEQUAL(relay.dir, initial_direction, "A fully authorized relay flip was rejected.")
	relay.dir = initial_direction

	TEST_ASSERT(viewer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not disable the viewer sex-toy preference for flip validation.")
	relay.attack_hand_secondary(viewer)
	if(relay.dir != initial_direction)
		TEST_FAIL("A viewer preference refusal still reached the relay flip and feedback branch.")
	relay.dir = initial_direction
	TEST_ASSERT(viewer_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE), "Could not restore the viewer sex-toy preference after flip validation.")

	TEST_ASSERT(owner_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not disable the owner sex-toy preference for flip validation.")
	relay.attack_hand_secondary(viewer)
	if(relay.dir != initial_direction)
		TEST_FAIL("An owner preference refusal still reached the relay flip and feedback branch.")
	relay.dir = initial_direction
	TEST_ASSERT(owner_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE), "Could not restore the owner sex-toy preference after flip validation.")

	var/datum/component/interactable/owner_component = owner.GetComponent(/datum/component/interactable)
	if(!owner_component)
		TEST_FAIL("The relay owner lost its interaction component during flip validation.")
		return
	owner_component.clear_body_relay(relay)
	relay.attack_hand_secondary(viewer)
	if(relay.dir != initial_direction)
		TEST_FAIL("An invalidated portal session still reached the relay flip and feedback branch.")
	owner_component.set_body_relay(relay)

#undef PORTAL_INTERACTION_STATE_TEST_ID
#undef PORTAL_INTERACTION_STATE_TEST_TRAIT
