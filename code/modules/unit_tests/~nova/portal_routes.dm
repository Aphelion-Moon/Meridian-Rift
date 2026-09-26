/// Records the public message produced by the real interaction execution path.
/mob/living/carbon/human/consistent/portal_message_test
	var/last_interaction_message

/mob/living/carbon/human/consistent/portal_message_test/manual_emote(text, log_emote = null)
	last_interaction_message = text
	return ..()

/// A transport which explicitly permits revealing its remote participant.
/datum/interaction_route/portal_message_test/is_still_valid(datum/interaction/interaction, mob/living/carbon/human/user, mob/living/carbon/human/target, ignore_cooldown = FALSE)
	return TRUE

/// An unseen participant never exposes their name when a relay panel loses range or its session.
/datum/unit_test/portal_device/route_ui_anonymity/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal route tests require portal items and preferences to be enabled.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/turf/remote_turf = locate(source_portal.x + 10, source_portal.y, source_portal.z)
	TEST_ASSERT_NOTNULL(remote_turf, "The anonymous panel fixture has no remote turf.")
	receiving_portal.forceMove(remote_turf)
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent, receiving_portal.loc)
	owner.name = "Private Portal Identity"
	attach_portal_preferences(owner)
	attach_portal_preferences(viewer)
	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The anonymous panel fixture could not start its portal session.")
	var/obj/effect/lewd_portal_relay/relay = source_portal.relayed_body
	var/datum/component/interactable/component = owner.GetComponent(/datum/component/interactable)
	TEST_ASSERT_NOTNULL(component, "The anonymous panel fixture has no interaction component.")
	TEST_ASSERT(!can_see(viewer, owner), "The remote panel fixture can see the owner's real body.")
	var/list/data = component.ui_data(viewer)
	TEST_ASSERT_EQUAL(data["self"], relay.name, "The adjacent relay panel did not use the relay's name.")

	viewer.forceMove(get_step(get_step(receiving_portal.loc, WEST), WEST))
	TEST_ASSERT(!viewer.Adjacent(relay) && !can_see(viewer, owner), "The panel fixture did not leave relay range while remaining remote.")
	data = component.ui_data(viewer)
	TEST_ASSERT_NOTEQUAL(data["self"], owner.name, "Leaving relay range revealed the remote participant's real name.")

	source_portal.end_session()
	data = component.ui_data(viewer)
	TEST_ASSERT_EQUAL(data["self"], "Unknown", "An expired relay panel revealed its unseen owner.")

	viewer.forceMove(owner.loc)
	TEST_ASSERT(can_see(viewer, owner), "The direct panel fixture cannot see the owner's body.")
	data = component.ui_data(viewer)
	TEST_ASSERT_EQUAL(data["self"], owner.name, "A visible direct participant lost their ordinary panel name.")
	var/datum/interaction/direct_interaction = allocate(/datum/interaction)
	direct_interaction.usage = INTERACTION_OTHER
	direct_interaction.category = "Portal unit test"
	TEST_ASSERT(component.can_interact(direct_interaction, viewer), "The anonymity fix blocked an ordinary direct interaction.")

/// The transport's preferences apply even when the interaction itself is ordinary.
/datum/unit_test/portal_device/route_ordinary_preferences/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal route tests require portal items and preferences to be enabled.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/mob/living/carbon/human/consistent/viewer = allocate(/mob/living/carbon/human/consistent, receiving_portal.loc)
	var/datum/client_interface/owner_client = attach_portal_preferences(owner)
	var/datum/client_interface/viewer_client = attach_portal_preferences(viewer)
	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The ordinary route fixture could not start its portal session.")
	var/datum/interaction_route/portal_relay/route = allocate(/datum/interaction_route/portal_relay, source_portal.relayed_body)
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.lewd = FALSE
	TEST_ASSERT(interaction.participants_accept_interaction(viewer, owner, route), "A permitted ordinary interaction was rejected through the portal.")

	for(var/datum/client_interface/participant_client as anything in list(owner_client, viewer_client))
		for(var/preference_type in list(/datum/preference/toggle/erp/sex_toy, /datum/preference/toggle/erp))
			TEST_ASSERT(participant_client.prefs.write_preference(GLOB.preference_entries[preference_type], FALSE), "Could not disable a portal participant's preference.")
			TEST_ASSERT(!interaction.participants_accept_interaction(viewer, owner, route), "An ordinary interaction bypassed a portal participant's [preference_type] refusal.")
			TEST_ASSERT(interaction.participants_accept_interaction(viewer, owner, null), "Portal preference refusal blocked an ordinary direct interaction.")
			TEST_ASSERT(participant_client.prefs.write_preference(GLOB.preference_entries[preference_type], TRUE), "Could not restore a portal participant's preference.")
/// A destination offered in one pair cannot dispatch through a different pair after the prompt.
/datum/unit_test/portal_device/route_offered_session/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal route tests require portal items and preferences to be enabled.")
		return

	var/list/first_pair = make_portal_pair()
	var/obj/structure/lewd_portal/first_source = first_pair[1]
	var/list/second_pair = make_portal_pair()
	var/obj/structure/lewd_portal/second_source = second_pair[1]
	var/obj/structure/lewd_portal/second_destination = second_pair[2]
	second_destination.forceMove(run_loc_floor_top_right)
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, first_source.loc)
	var/datum/client_interface/owner_client = attach_portal_preferences(owner)
	TEST_ASSERT(first_source.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The offered-session fixture could not start its first session.")
	var/obj/effect/lewd_portal_relay/first_output = owner.get_portal_output()
	TEST_ASSERT_NOTNULL(first_output, "The first session did not expose its current output.")
	var/datum/weakref/offered_output_ref = WEAKREF(first_output)
	TEST_ASSERT_EQUAL(owner.resolve_portal_output(offered_output_ref), first_output, "The offered output did not resolve while its session remained current.")

	first_source.end_session()
	TEST_ASSERT_NULL(owner.resolve_portal_output(offered_output_ref), "An ended session retained authority over its offered output.")
	TEST_ASSERT(second_source.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The offered-session fixture could not enter its replacement pair.")
	var/obj/effect/lewd_portal_relay/second_output = owner.get_portal_output()
	TEST_ASSERT_EQUAL(second_output, second_source.relayed_body, "The replacement pair did not become the current output.")
	TEST_ASSERT_NULL(owner.resolve_portal_output(offered_output_ref), "An old destination choice resolved through a replacement pair.")
	var/datum/weakref/second_output_ref = WEAKREF(second_output)
	TEST_ASSERT_EQUAL(owner.resolve_portal_output(second_output_ref), second_output, "A fresh destination choice was rejected for the replacement pair.")

	TEST_ASSERT(owner_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], FALSE), "Could not revoke portal permission after offering a destination.")
	TEST_ASSERT_NULL(owner.resolve_portal_output(second_output_ref), "An offered destination ignored permission revoked during its prompt.")

/// A distant ordinary action cannot recover an identity after the relay is gone.
/datum/unit_test/portal_device/route_message_anonymity/Run()
	if(CONFIG_GET(flag/disable_lewd_items) || CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "Portal route tests require portal items and preferences to be enabled.")
		return

	var/list/portal_pair = make_portal_pair()
	var/obj/structure/lewd_portal/source_portal = portal_pair[1]
	var/obj/structure/lewd_portal/receiving_portal = portal_pair[2]
	var/turf/remote_turf = locate(source_portal.x + 10, source_portal.y, source_portal.z)
	TEST_ASSERT_NOTNULL(remote_turf, "The message fixture has no remote turf.")
	receiving_portal.forceMove(remote_turf)
	var/mob/living/carbon/human/consistent/owner = allocate(/mob/living/carbon/human/consistent, source_portal.loc)
	var/mob/living/carbon/human/consistent/portal_message_test/viewer = allocate(/mob/living/carbon/human/consistent/portal_message_test, remote_turf)
	owner.name = "Private Message Identity"
	attach_portal_preferences(owner)
	attach_portal_preferences(viewer)
	TEST_ASSERT(source_portal.buckle_mob(owner, force = TRUE, check_loc = FALSE), "The message fixture could not start its portal session.")
	var/datum/interaction/interaction = allocate(/datum/interaction)
	interaction.category = "Portal unit test"
	interaction.distance_allowed = TRUE
	interaction.message = list("%USER% waves to %TARGET%.")
	var/datum/component/interactable/component = owner.GetComponent(/datum/component/interactable)
	var/datum/interaction_route/route = component.get_interaction_route(interaction, viewer)
	TEST_ASSERT_NOTNULL(route, "The message fixture did not resolve its active relay.")
	TEST_ASSERT(interaction.act(viewer, owner, route = route), "The live relay rejected the message fixture.")
	TEST_ASSERT(!findtext(viewer.last_interaction_message, owner.name), "A relay message exposed its anonymous target.")

	source_portal.end_session()
	route = component.get_interaction_route(interaction, viewer)
	TEST_ASSERT_NULL(route, "The message fixture retained a route after its session ended.")
	TEST_ASSERT(!can_see(viewer, owner), "The message fixture can see the remote body.")
	TEST_ASSERT(interaction.act(viewer, owner, route = route), "Losing a relay prevented an otherwise valid distant ordinary action.")
	TEST_ASSERT_EQUAL(viewer.last_interaction_message, "waves to Unknown.", "A distant ordinary action recovered an unseen target's name after its relay ended.")

	route = allocate(/datum/interaction_route/portal_message_test)
	TEST_ASSERT(interaction.act(viewer, owner, route = route), "An explicit remote transport policy rejected the message fixture.")
	TEST_ASSERT_EQUAL(viewer.last_interaction_message, "waves to [owner.name].", "The direct visibility fallback overrode a transport's explicit identity policy.")

	viewer.forceMove(owner.loc)
	TEST_ASSERT(interaction.act(viewer, owner), "A visible direct interaction was rejected by the anonymity fallback.")
	TEST_ASSERT_EQUAL(viewer.last_interaction_message, "waves to [owner.name].", "The anonymity fallback hid a visible direct participant.")
