/** Installs one isolated diagnostics owner and restores it after fixture destruction. */
/datum/unit_test/dogmos_diagnostics_fixture
	abstract_type = /datum/unit_test/dogmos_diagnostics_fixture
	var/datum/dogmos_diagnostics/original_diagnostics

/datum/unit_test/dogmos_diagnostics_fixture/New()
	. = ..()
	original_diagnostics = SSair.diagnostics
	SSair.diagnostics = new

/datum/unit_test/dogmos_diagnostics_fixture/Destroy()
	. = ..()
	QDEL_NULL(SSair.diagnostics)
	SSair.diagnostics = original_diagnostics
	original_diagnostics = null

/** Verifies bounded newest-first event history and jump-target resolution. */
/datum/unit_test/dogmos_kennel_record_event
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture

/datum/unit_test/dogmos_kennel_record_event/Run()
	var/list/bucket = list()

	SSair.diagnostics.record_kennel_event(bucket, list("marker" = "first"))
	SSair.diagnostics.record_kennel_event(bucket, list("marker" = "second"))

	TEST_ASSERT_EQUAL(length(bucket), 2, \
		"record_kennel_event() did not append - expected 2 entries, got [length(bucket)].")
	TEST_ASSERT_EQUAL(bucket[1]["marker"], "second", \
		"The most recently recorded entry ([bucket[1]["marker"]]) was not at index 1 - record_kennel_event() is not inserting newest-first.")
	TEST_ASSERT_EQUAL(bucket[2]["marker"], "first", \
		"The oldest entry ([bucket[2]["marker"]]) was not pushed to index 2 - record_kennel_event() is not inserting newest-first.")

	var/turf/target = run_loc_floor_bottom_left
	var/jump_ref = REF(target)
	SSair.diagnostics.record_kennel_event(bucket, list("jump_to" = jump_ref), target)
	TEST_ASSERT_EQUAL(SSair.diagnostics.resolve_kennel_jump_target(jump_ref), target, \
		"A recorded Kennel target could not be resolved from its server-owned reference.")
	TEST_ASSERT_NULL(SSair.diagnostics.resolve_kennel_jump_target("invalid_ref"), \
		"An unrecorded Kennel target reference resolved successfully.")
	var/list/duplicate_bucket = list()
	SSair.diagnostics.record_kennel_event(duplicate_bucket, list("jump_to" = jump_ref), target)
	SSair.diagnostics.record_kennel_event(duplicate_bucket, list("jump_to" = jump_ref), target)
	for(var/i in 1 to 199)
		SSair.diagnostics.record_kennel_event(duplicate_bucket, list("marker" = "fill-[i]"))
	TEST_ASSERT_EQUAL(SSair.diagnostics.resolve_kennel_jump_target(jump_ref), target, \
		"Evicting one of two retained events for the same target removed the target needed by the newer event.")
	SSair.diagnostics.kennel_jump_targets -= jump_ref
	SSair.diagnostics.kennel_jump_target_counts -= jump_ref
	SSair.diagnostics.kennel_pinned_turfs[jump_ref] = WEAKREF(target)
	TEST_ASSERT_EQUAL(SSair.diagnostics.resolve_kennel_jump_target(jump_ref), target, \
		"A pinned Kennel target could not be resolved from its server-owned reference.")
	SSair.diagnostics.kennel_pinned_turfs -= jump_ref

	// KENNEL_EVENT_HISTORY_CAP is #define'd inside dogmos_kennel_events.dm and #undef'd there, so it's
	// not visible here - 200, per that file, is asserted against by literal value rather than re-#define'd
	// locally, which would drift silently if the real one ever changes without this test noticing.
	for(var/i in 1 to 205)
		SSair.diagnostics.record_kennel_event(bucket, list("marker" = "fill-[i]"))

	TEST_ASSERT_EQUAL(length(bucket), 200, \
		"record_kennel_event() did not cap the bucket at 200 entries after 207 total inserts - got [length(bucket)].")
	TEST_ASSERT_EQUAL(bucket[1]["marker"], "fill-205", \
		"After capping, the newest entry (fill-205) was not at index 1 ([bucket[1]["marker"]]) - the cap is dropping from the wrong end.")
