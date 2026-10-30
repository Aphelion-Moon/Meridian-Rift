/** Verifies the live callback enqueue-failure telemetry binding. */
/datum/unit_test/dogmos_callback_delivery

/datum/unit_test/dogmos_callback_delivery/Run()
	var/failures = dogmos_callback_enqueue_failures()
	TEST_ASSERT(isnum(failures), "Dogmos callback enqueue telemetry did not return a number.")
	TEST_ASSERT_EQUAL(failures, 0, \
		"Dogmos started with [failures] callback enqueue failures; callbacks were rejected before this test ran.")
