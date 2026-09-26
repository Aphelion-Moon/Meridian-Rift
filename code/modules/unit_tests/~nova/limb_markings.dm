/// Adding or renaming a limb's markings must never give it the same marking twice.
/datum/unit_test/limb_markings_stay_unique
	/// The left arm's real marking choices, restored after the test narrows them.
	var/list/original_choices

/datum/unit_test/limb_markings_stay_unique/Destroy()
	if(original_choices)
		GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	return ..()

/datum/unit_test/limb_markings_stay_unique/Run()
	var/list/choices = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]
	TEST_ASSERT(length(choices) >= MAXIMUM_MARKINGS_PER_LIMB, "The fixture needs enough left arm markings to fill the limb.")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	// With one free choice left, a pick that ignored worn markings would usually land on a worn one.
	original_choices = choices
	var/list/narrowed = choices.Copy(1, MAXIMUM_MARKINGS_PER_LIMB + 1)
	GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = narrowed
	for(var/attempt in 1 to 10)
		var/list/worn = list()
		for(var/marking_name in narrowed.Copy(1, MAXIMUM_MARKINGS_PER_LIMB))
			worn[marking_name] = list("#ffffff", FALSE)
		preferences.body_markings[BODY_ZONE_L_ARM] = worn
		middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM), mock_client.mob)
		TEST_ASSERT(json_encode(assoc_to_keys(preferences.body_markings[BODY_ZONE_L_ARM])) == json_encode(narrowed), "Adding a marking must pick one the limb doesn't already wear.")
	middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM), mock_client.mob)
	TEST_ASSERT(length(preferences.body_markings[BODY_ZONE_L_ARM]) == MAXIMUM_MARKINGS_PER_LIMB, "A full limb must refuse another marking.")
	middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "marking_name" = narrowed[2]), mock_client.mob)
	TEST_ASSERT(json_encode(assoc_to_keys(preferences.body_markings[BODY_ZONE_L_ARM])) == json_encode(narrowed), "Renaming a marking to one another row wears must be refused.")
