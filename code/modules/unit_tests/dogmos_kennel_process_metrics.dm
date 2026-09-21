
/** Verifies Dogmos process snapshots sample the host without retaining snapshots. */
/datum/unit_test/dogmos_kennel_process_metrics
	/// Original Kennel slow-mode setting restored after the test.
	var/original_slow_mode
	/// Original Kennel process-metric sample counter restored after the test.
	var/original_process_metric_samples
	/// Original Kennel machinery-candidate counter restored after the test.
	var/original_machinery_candidates_inspected
	/// Original Kennel browse-page counter restored after the test.
	var/original_browse_pages_built
	/// Original Kennel active-viewer sample restored after the test.
	var/original_active_viewers
	/// Original Kennel UI registry restored after the test.
	var/list/original_open_uis
	/// First test-owned Kennel UI deleted during cleanup.
	var/datum/tgui/dogmos_kennel/first_test_ui
	/// Second test-owned Kennel UI deleted during cleanup.
	var/datum/tgui/dogmos_kennel/second_test_ui

/datum/unit_test/dogmos_kennel_process_metrics/Run()
	original_slow_mode = SSair.kennel_slow_mode
	original_process_metric_samples = GLOB.dogmos_kennel.producer_process_metric_samples
	original_machinery_candidates_inspected = GLOB.dogmos_kennel.producer_machinery_candidates_inspected
	original_browse_pages_built = GLOB.dogmos_kennel.producer_browse_pages_built
	original_active_viewers = GLOB.dogmos_kennel.producer_active_viewers
	original_open_uis = GLOB.dogmos_kennel.open_uis
	GLOB.dogmos_kennel.producer_process_metric_samples = 0
	GLOB.dogmos_kennel.producer_machinery_candidates_inspected = 0
	GLOB.dogmos_kennel.producer_browse_pages_built = 0
	GLOB.dogmos_kennel.open_uis = list()
	SSair.kennel_slow_mode = TRUE
	var/mob/living/carbon/human/observer = allocate(/mob/living/carbon/human/consistent)
	observer.set_hud_used(new observer.hud_type(observer))
	var/list/data = GLOB.dogmos_kennel.ui_data(observer)
	var/list/producer_telemetry = data["producer_telemetry"]
	TEST_ASSERT_EQUAL(producer_telemetry["process_metric_samples"], 1, "Kennel did not count its slow-mode process-metric sample.")
	TEST_ASSERT_EQUAL(producer_telemetry["machinery_candidates_inspected"], 0, "Kennel inspected machinery while slow mode was enabled.")
	TEST_ASSERT_EQUAL(producer_telemetry["browse_pages_built"], 0, "Kennel built a machinery page while slow mode was enabled.")
	TEST_ASSERT_EQUAL(producer_telemetry["active_viewers"], 0, "Kennel reported viewers for an empty UI registry.")
	var/list/payload = data["process_metrics"]
	TEST_ASSERT_NOTNULL(payload, "The Dogmos Kennel omitted process_metrics from its live payload.")
	TEST_ASSERT_EQUAL(length(payload), 1, "The Dogmos Kennel exposed a combined or unexpected process role.")
	TEST_ASSERT("dreamdaemon" in payload, "The Dogmos Kennel omitted the DreamDaemon process role.")
	TEST_ASSERT_NULL(payload["combined"], "The Dogmos Kennel exposed combined process memory.")
	TEST_ASSERT_EQUAL(length(payload["dreamdaemon"]), 4, "The Dogmos Kennel changed the DreamDaemon metric contract.")
	TEST_ASSERT("private_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon private bytes.")
	TEST_ASSERT("virtual_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon virtual bytes.")
	TEST_ASSERT("working_set_bytes" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon working-set bytes.")
	TEST_ASSERT("available" in payload["dreamdaemon"], "The Dogmos Kennel omitted DreamDaemon availability.")
	TEST_ASSERT(!("process_metrics" in GLOB.dogmos_kennel.vars), "The Dogmos Kennel retained the latest process snapshot.")
	TEST_ASSERT(!("process_metrics_history" in GLOB.dogmos_kennel.vars), "The Dogmos Kennel retained process-metrics history.")
	TEST_ASSERT(!("process_metrics" in SSair.vars), "SSair retained the latest process snapshot.")
	TEST_ASSERT(!("process_metrics_history" in SSair.vars), "SSair retained process-metrics history.")

	var/mob/living/carbon/human/second_observer = allocate(/mob/living/carbon/human/consistent)
	second_observer.set_hud_used(new second_observer.hud_type(second_observer))
	first_test_ui = allocate(/datum/tgui/dogmos_kennel, observer, GLOB.dogmos_kennel, "DogmosKennel")
	second_test_ui = allocate(/datum/tgui/dogmos_kennel, second_observer, GLOB.dogmos_kennel, "DogmosKennel")
	GLOB.dogmos_kennel.open_uis = list(first_test_ui, second_test_ui)
	SSair.kennel_slow_mode = FALSE
	var/machinery_count = length(SSair.atmos_machinery)
	var/list/first_viewer_data = GLOB.dogmos_kennel.ui_data(observer)
	var/list/first_viewer_telemetry = first_viewer_data["producer_telemetry"]
	var/first_viewer_inspections = first_viewer_telemetry["machinery_candidates_inspected"]
	TEST_ASSERT(first_viewer_inspections >= machinery_count, "Kennel did not inspect the atmosphere-machinery registry for the first viewer.")
	TEST_ASSERT_EQUAL(first_viewer_telemetry["active_viewers"], 2, "Kennel did not report both active viewers.")
	var/list/second_viewer_data = GLOB.dogmos_kennel.ui_data(second_observer)
	var/list/second_viewer_telemetry = second_viewer_data["producer_telemetry"]
	TEST_ASSERT_EQUAL(second_viewer_telemetry["process_metric_samples"], 3, "Kennel did not sample process metrics once per UI data request.")
	TEST_ASSERT_EQUAL(second_viewer_telemetry["browse_pages_built"], 2, "Kennel did not build one machinery page per ordinary viewer request.")
	TEST_ASSERT_EQUAL(second_viewer_telemetry["machinery_candidates_inspected"], first_viewer_inspections * 2, "Kennel's second viewer did not repeat the first viewer's machinery scan work.")
	TEST_ASSERT_EQUAL(second_viewer_telemetry["active_viewers"], 2, "Kennel's active-viewer telemetry changed between two registered viewers.")

/datum/unit_test/dogmos_kennel_process_metrics/Destroy()
	if(!isnull(original_slow_mode))
		SSair.kennel_slow_mode = original_slow_mode
	if(!isnull(original_process_metric_samples))
		GLOB.dogmos_kennel.producer_process_metric_samples = original_process_metric_samples
	if(!isnull(original_machinery_candidates_inspected))
		GLOB.dogmos_kennel.producer_machinery_candidates_inspected = original_machinery_candidates_inspected
	if(!isnull(original_browse_pages_built))
		GLOB.dogmos_kennel.producer_browse_pages_built = original_browse_pages_built
	if(!isnull(original_active_viewers))
		GLOB.dogmos_kennel.producer_active_viewers = original_active_viewers
	GLOB.dogmos_kennel.open_uis = original_open_uis
	QDEL_NULL(first_test_ui)
	QDEL_NULL(second_test_ui)
	return ..()
