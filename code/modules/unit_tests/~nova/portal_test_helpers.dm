/// Common ownership and appearance fixtures for portal-device and wall-portal tests.
/datum/unit_test/portal_test
	abstract_type = /datum/unit_test/portal_test

/// Allocates a reciprocal portal pair on adjacent test turfs.
/datum/unit_test/portal_test/proc/make_portal_pair(portal_mode = "wallstuck")
	var/obj/structure/lewd_portal/source_portal = allocate(/obj/structure/lewd_portal, run_loc_floor_bottom_left)
	var/obj/structure/lewd_portal/receiving_portal = allocate(/obj/structure/lewd_portal, get_step(run_loc_floor_bottom_left, EAST))
	source_portal.portal_mode = portal_mode
	receiving_portal.portal_mode = portal_mode
	source_portal.linked_portal = receiving_portal
	receiving_portal.linked_portal = source_portal
	return list(source_portal, receiving_portal)

/// Owns its test preferences so cleanup cannot retain the mock client.
/datum/client_interface/portal_unit_test

/datum/client_interface/portal_unit_test/Destroy(force)
	mob = null
	if(prefs)
		prefs.parent = null
	QDEL_NULL(prefs)
	return ..()

/// Attaches the standard unit-test client abstraction with both canonical portal preferences enabled.
/datum/unit_test/portal_test/proc/attach_portal_preferences(mob/living/carbon/human/participant)
	var/datum/client_interface/portal_unit_test/mock_client = allocate(/datum/client_interface/portal_unit_test)
	mock_client.prefs = new /datum/preferences(mock_client)
	mock_client.mob = participant
	participant.mock_client = mock_client
	if(!mock_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/master_erp_preferences], TRUE))
		TEST_FAIL("Could not enable the master ERP preference for a portal test participant.")
	if(!mock_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp], TRUE))
		TEST_FAIL("Could not enable the ERP preference for a portal test participant.")
	if(!mock_client.prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/erp/sex_toy], TRUE))
		TEST_FAIL("Could not enable the sex-toy preference for a portal test participant.")
	return mock_client

/// Gives a test human a deterministic, exposed penis, optionally with a retractable sheath.
/datum/unit_test/portal_test/proc/configure_test_penis(
	mob/living/carbon/human/participant,
	sheath_name = SPRITE_ACCESSORY_NONE,
)
	participant.dna.features["penis_size"] = 4
	participant.dna.features["penis_girth"] = 3
	participant.dna.features["penis_uses_skincolor"] = FALSE
	participant.dna.features["penis_uses_skintones"] = FALSE
	participant.dna.features["penis_sheath"] = sheath_name
	participant.dna.mutant_bodyparts[ORGAN_SLOT_PENIS] = build_mutant_part("Human", list("#FCCCB3"))

	var/obj/item/organ/genital/penis/test_penis = allocate(/obj/item/organ/genital/penis, participant.loc)
	if(QDELETED(test_penis))
		return null
	test_penis.build_from_dna(participant.dna, ORGAN_SLOT_PENIS)
	var/datum/bodypart_overlay/mutant/genital/penis/penis_overlay = test_penis.bodypart_overlay
	if(!penis_overlay?.set_appearance_from_dna(participant.dna))
		return null
	if(!test_penis.Insert(participant, special = TRUE))
		return null

	participant.underwear = "Nude"
	participant.undershirt = "Nude"
	participant.bra = "Nude"
	participant.underwear_visibility = NONE
	test_penis.visibility_preference = GENITAL_HIDDEN_BY_CLOTHES
	participant.update_body()
	if(participant.get_organ_slot(ORGAN_SLOT_PENIS) != test_penis || !test_penis.is_exposed())
		return null
	return test_penis
