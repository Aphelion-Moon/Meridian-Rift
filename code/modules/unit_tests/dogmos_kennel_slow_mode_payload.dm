/** Slow mode keeps bounded histories visible; hidden machinery panels remain unbuilt. */
/datum/unit_test/dogmos_kennel_slow_mode_payload
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture
/datum/unit_test/dogmos_kennel_slow_mode_payload/Run()
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	// create_mob_hud() no-ops without a real client (this test mob has none) - build the HUD directly,
	// the same way create_mob_hud() does internally, since ui_data() unconditionally reads
	// user.hud_used.atmos_debug_overlays regardless of what this test is actually checking.
	observer.set_hud_used(new observer.hud_type(observer))

	SSair.diagnostics.recent_fire_groups = list(list(
		"time" = "00:00:00",
		"jump_to" = null,
		"area" = "Test",
		"peak_size" = 99,
	))
	SSair.diagnostics.recent_explosions = list(list(
		"time" = "00:00:00",
		"jump_to" = null,
		"area" = "Test",
		"devastation_range" = 1,
		"heavy_impact_range" = 2,
		"light_impact_range" = 3,
		"cause" = "Test",
		"index" = 1,
	))
	SSair.diagnostics.recent_reactions_of_interest = list(list(
		"time" = "00:00:00",
		"jump_to" = null,
		"area" = "Test",
		"reaction" = "plasmafire",
		"amount" = 99,
	))
	SSair.diagnostics.recent_high_cost_zones = list(list(
		"time" = "00:00:00",
		"jump_to" = null,
		"area" = "Test",
		"reaction" = "plasmafire",
		"cost_ms" = 1,
	))
	SSair.diagnostics.recent_breaches = list(list(
		"time" = "00:00:00",
		"jump_to" = null,
		"area" = "Test",
		"moles_lost" = 99,
	))
	var/obj/machinery/pinned = allocate(/obj/machinery)
	SSair.diagnostics.kennel_pin_structure(pinned, "test", null)

	SSair.diagnostics.kennel_slow_mode = TRUE
	var/list/data_slow = GLOB.dogmos_kennel.ui_data(observer)
	TEST_ASSERT(islist(data_slow["recent_fire_groups"]), \
		"ui_data()'s recent_fire_groups is not a list at all while slow mode is on - the frontend has nothing safe to render.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_fire_groups"]), 1, \
		"ui_data() did not preserve recent_fire_groups while kennel_slow_mode is TRUE - fire-group diagnostics must remain available in slow mode.")
	TEST_ASSERT_EQUAL(data_slow["recent_fire_groups"][1]["peak_size"], 99, \
		"ui_data()'s slow-mode recent_fire_groups entry does not match SSair's real data.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_explosions"]), 1, \
		"ui_data() did not preserve recent_explosions while kennel_slow_mode is TRUE - explosion diagnostics must remain available in slow mode.")
	TEST_ASSERT_EQUAL(data_slow["recent_explosions"][1]["index"], 1, \
		"ui_data()'s slow-mode recent_explosions entry does not match SSair's real data.")
	TEST_ASSERT_EQUAL(data_slow["event_counts"]["reactions_of_interest"], 1, \
		"ui_data() did not expose the stored reaction count while slow mode was on - the frontend cannot distinguish an empty history from a hidden history.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_reactions_of_interest"]), 1, \
		"ui_data() hid stored reaction history while kennel_slow_mode is TRUE - bounded event histories must remain visible.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_high_cost_zones"]), 1, \
		"ui_data() hid stored high-cost history while kennel_slow_mode is TRUE - bounded event histories must remain visible.")
	TEST_ASSERT_EQUAL(length(data_slow["recent_breaches"]), 1, \
		"ui_data() hid stored breach history while kennel_slow_mode is TRUE - bounded event histories must remain visible.")
	TEST_ASSERT_EQUAL(length(data_slow["structures_of_interest"]), 1, \
		"ui_data() hid stored structures of interest while kennel_slow_mode is TRUE - the small stored pin list must remain visible.")
	TEST_ASSERT_NULL(data_slow["atmos_machinery_browse"], \
		"ui_data() sent atmos_machinery_browse while kennel_slow_mode is TRUE - that key should be entirely absent, not just empty, matching its optional frontend type.")

	SSair.diagnostics.kennel_slow_mode = FALSE
	var/list/data_live = GLOB.dogmos_kennel.ui_data(observer)
	TEST_ASSERT_NULL(data_live["equalize_performance_profile"], \
		"ui_data() still exposes the round-static Equalize performance profile - it does not belong on the live Kennel page.")
	TEST_ASSERT_EQUAL(length(data_live["recent_fire_groups"]), 1, \
		"ui_data() did not send the real recent_fire_groups entry while kennel_slow_mode is FALSE - got [length(data_live["recent_fire_groups"])] entries.")
	TEST_ASSERT_EQUAL(data_live["recent_fire_groups"][1]["peak_size"], 99, \
		"ui_data()'s recent_fire_groups entry does not match SSair's real data while slow mode is off.")
	TEST_ASSERT_EQUAL(length(data_live["recent_explosions"]), 1, \
		"ui_data() did not send the real recent_explosions entry while kennel_slow_mode is FALSE.")
	TEST_ASSERT_EQUAL(length(data_live["recent_reactions_of_interest"]), 1, \
		"ui_data() did not send the real reaction history while kennel_slow_mode is FALSE.")
	TEST_ASSERT_EQUAL(data_live["event_counts"]["reactions_of_interest"], 1, \
		"ui_data()'s reaction count does not match the real reaction history while kennel_slow_mode is FALSE.")
