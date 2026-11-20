#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Shutdown joins every suspended photograph and rejects later work. */
/datum/unit_test/runtime_ownership_condo_previews/Run()
	var/datum/controller/subsystem/condos/preview_test_copy/owner = allocate(/datum/controller/subsystem/condos/preview_test_copy)
	INVOKE_ASYNC(owner, TYPE_PROC_REF(/datum/controller/subsystem/condos/preview_test_copy, capture_photo))
	INVOKE_ASYNC(owner, TYPE_PROC_REF(/datum/controller/subsystem/condos/preview_test_copy, capture_photo))
	if(owner.render_calls != 2 || owner.completed_calls)
		return Fail("Both photographs must be suspended when shutdown begins.", __FILE__, __LINE__)
	owner.Shutdown()
	if(owner.completed_calls != 2 || owner.published_photos)
		return Fail("Shutdown must join every photograph and suppress its result before publication.", __FILE__, __LINE__)
	owner.photograph_interior(null)
	owner.Shutdown()
	if(owner.render_calls != 2)
		return Fail("Shutdown must permanently reject new photographs.", __FILE__, __LINE__)
	var/datum/controller/subsystem/condos/preview_test_copy/normal_owner = allocate(/datum/controller/subsystem/condos/preview_test_copy)
	if(normal_owner.photograph_interior(null) != 1)
		return Fail("Normal photographs must retain their result.", __FILE__, __LINE__)
	normal_owner.Shutdown()

	var/datum/controller/subsystem/condos/preview_test_copy/failed_owner = allocate(/datum/controller/subsystem/condos/preview_test_copy)
	failed_owner.fail_render = TRUE
	var/caught_failure = FALSE
	try
		failed_owner.photograph_interior(null)
	catch
		caught_failure = TRUE
	if(!caught_failure || failed_owner.active_preview_renders)
		return Fail("A rendering exception must reach its caller without leaving shutdown waiting forever.", __FILE__, __LINE__)
	failed_owner.Shutdown()

	var/datum/controller/subsystem/condos/preview_test_copy/waiting_owner = allocate(/datum/controller/subsystem/condos/preview_test_copy)
	var/was_clearing = SSmapping.clearing_reserved_turfs
	SSmapping.clearing_reserved_turfs = TRUE
	// The async calls return at their first sleep; restore Mapping before this test yields.
	INVOKE_ASYNC(waiting_owner, TYPE_PROC_REF(/datum/controller/subsystem/condos/preview_test_copy, capture_photo))
	INVOKE_ASYNC(waiting_owner, TYPE_PROC_REF(/datum/controller/subsystem/condos/preview_test_copy, capture_shutdown))
	var/shutdown_cancelled_admission = waiting_owner.shutdown_completed
	SSmapping.clearing_reserved_turfs = was_clearing
	sleep(3 * world.tick_lag)
	if(!shutdown_cancelled_admission || waiting_owner.render_calls || waiting_owner.completed_calls != 1 || waiting_owner.published_photos)
		return Fail("Shutdown must cancel reservation admission without waiting for Mapping to resume.", __FILE__, __LINE__)

/** Inert copies exercise the real ownership boundary without changing SScondos or loading maps. */
/datum/controller/subsystem/condos/preview_test_copy
	name = "Condo preview test copy"
	ss_flags = SS_NO_INIT | SS_NO_FIRE
	can_fire = FALSE
	/// Calls admitted through the production ownership wrapper.
	var/render_calls = 0
	/// Async callers that have returned from the production wrapper.
	var/completed_calls = 0
	/// Non-null results that a caller could publish as preview assets.
	var/published_photos = 0
	/// Exercises exceptional accounting without logging an unexpected runtime.
	var/fail_render = FALSE
	/// Records whether shutdown returned while reservation admission was still closed.
	var/shutdown_completed = FALSE

// Master also discovers this subtype; inherited New would replace the global subsystem.
/datum/controller/subsystem/condos/preview_test_copy/New()
	return

/datum/controller/subsystem/condos/preview_test_copy/proc/capture_photo()
	if(!isnull(photograph_interior(null)))
		published_photos++
	completed_calls++

/datum/controller/subsystem/condos/preview_test_copy/proc/capture_shutdown()
	Shutdown()
	shutdown_completed = TRUE

/datum/controller/subsystem/condos/preview_test_copy/render_interior(datum/map_template/condo/chosen)
	render_calls++
	if(fail_render)
		throw EXCEPTION("Expected condo preview test failure")
	sleep(2 * world.tick_lag)
	return 1

#endif
