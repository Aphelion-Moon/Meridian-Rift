/** Equal yields from separate invocations log; repeated notification of one list does not. */
/datum/unit_test/dogmos_kennel_reactions_of_interest
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture
	var/list/original_results
	var/list/original_seen
	var/turf/open/site

/datum/unit_test/dogmos_kennel_reactions_of_interest/Run()
	site = run_loc_floor_bottom_left
	original_results = site.air.reaction_results
	original_seen = site.kennel_last_reaction_results
	SSair.diagnostics.kennel_reaction_magnitude_threshold = 100
	for(var/amount in list(50, 500, 500, 700))
		site.air.reaction_results = list("plasmafire" = amount)
		SSair.diagnostics.check_kennel_reaction_of_interest(site)
		SSair.diagnostics.check_kennel_reaction_of_interest(site)
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.recent_reactions_of_interest), 3, "Equal yields in distinct invocations must log once each.")

/datum/unit_test/dogmos_kennel_reactions_of_interest/Destroy()
	if(site)
		site.air.reaction_results = original_results
		site.kennel_last_reaction_results = original_seen
	site = null
	original_results = null
	original_seen = null
	return ..()
