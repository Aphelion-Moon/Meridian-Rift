///Checks if spritesheet assets contain icon states with invalid names
/datum/unit_test/spritesheets

/datum/unit_test/spritesheets/Run()
	for(var/datum/asset/spritesheet/sheet as anything in valid_subtypesof(/datum/asset/spritesheet))
		if(!initial(sheet.name)) //Ignore abstract types
			continue
		sheet = get_asset_datum(sheet)
		for(var/sprite_name in sheet.sprites)
			if(!sprite_name)
				TEST_FAIL("Spritesheet [sheet.type] has a nameless icon state.")

	// Test IconForge generated sheets as well
	for(var/datum/asset/spritesheet_batched/sheet as anything in valid_subtypesof(/datum/asset/spritesheet_batched))
		if(!initial(sheet.name)) //Ignore abstract types
			continue
		sheet = get_asset_datum(sheet)
		for(var/sprite_name in sheet.sprites)
			if(!sprite_name)
				TEST_FAIL("Spritesheet [sheet.type] has a nameless icon state.")
// APHELION EDIT ADDITION START - Concurrent batched spritesheet regression.
/// A real sheet with a deterministic yield so queued loading and foreground consumers overlap.
/datum/asset/spritesheet_batched/concurrent_test
	name = "concurrent_test"
	abstract_type = /datum/asset/spritesheet_batched/concurrent_test
	load_immediately = TRUE
	force_cache = TRUE
	/// How many times generate_spritesheets() ran.
	var/generation_calls = 0
	/// Whether generation sleeps, so other callers arrive while it owns the sheet.
	var/pause_generation = FALSE
	/// Whether generation throws, to check that ownership is released on failure.
	var/fail_generation = FALSE

/// Uses a tiny real icon to exercise both generation and the smart cache.
/datum/asset/spritesheet_batched/concurrent_test/create_spritesheets()
	insert_icon("test", uni_icon('icons/effects/effects.dmi', "nothing"))

/// Holds the owner long enough for competing consumers and can inject a retryable failure.
/datum/asset/spritesheet_batched/concurrent_test/generate_spritesheets(yield)
	generation_calls++
	if(pause_generation)
		sleep(1)
	if(fail_generation)
		throw EXCEPTION("Expected spritesheet generation test failure")
	return ..()

/// A queued load and a foreground caller of one batched sheet share one generation, cached or not, and a failed generation lets the next caller retry.
/datum/unit_test/spritesheet_concurrent_loading
	priority = TEST_LONGER
	/// How many independent waiters have received the finished sheet.
	var/consumers_finished = 0

/// Records when an independent waiter receives the completed sheet.
/datum/unit_test/spritesheet_concurrent_loading/proc/await_sheet(datum/asset/spritesheet_batched/sheet)
	sheet.ensure_ready()
	consumers_finished++

/datum/unit_test/spritesheet_concurrent_loading/Run()
	var/datum/asset/spritesheet_batched/concurrent_test/sheet = new
	TEST_ASSERT(sheet.fully_generated, "The fixture must start with a real generated spritesheet.")
	for(var/from_cache in list(FALSE, TRUE))
		sheet.fully_generated = FALSE
		sheet.cache_result = from_cache ? null : TRUE
		sheet.generation_calls = 0
		sheet.pause_generation = TRUE
		consumers_finished = 0
		var/generating_before = SSasset_loading.assets_generating
		sheet.queued_generation()
		TEST_ASSERT(sheet.generation_in_progress, "Queued generation must retain ownership while it yields.")
		INVOKE_ASYNC(src, PROC_REF(await_sheet), sheet)
		TEST_ASSERT(sheet.ensure_ready() == sheet && sheet.fully_generated, "Foreground consumers must wait until the shared sheet is ready.")
		UNTIL(consumers_finished)
		TEST_ASSERT_EQUAL(sheet.generation_calls, 1, "Queued and foreground consumers must run one cache check/generation path.")
		TEST_ASSERT_EQUAL(SSasset_loading.assets_generating, generating_before, "A shared generation job must release its counter exactly once.")
		TEST_ASSERT(!sheet.generation_in_progress && !sheet.job_id && !sheet.cache_job_id, "Completed async job ownership and IDs must be released.")
		TEST_ASSERT((!sheet.cache_result) == from_cache, "The fixture must exercise both real generation and a validated cache hit.")
	// A failed owner must neither swallow the error nor strand every later consumer.
	sheet.fully_generated = FALSE
	sheet.pause_generation = FALSE
	sheet.fail_generation = TRUE
	var/caught = FALSE
	try
		sheet.ensure_ready()
	catch
		caught = TRUE
	TEST_ASSERT(caught && !sheet.generation_in_progress, "An error must propagate after releasing generation ownership.")
	sheet.fail_generation = FALSE
	TEST_ASSERT(sheet.ensure_ready() == sheet && sheet.fully_generated, "A caller after a failed owner must be able to retry.")
	SSassets.transport.unregister_asset("spritesheet_[sheet.name].css")
	fdel("[ASSET_CROSS_ROUND_SMART_CACHE_DIRECTORY]/spritesheet_cache.[sheet.name].json")
	fdel("data/spritesheets/spritesheet_[sheet.name].css")
	for(var/size in sheet.sizes)
		SSassets.transport.unregister_asset("[sheet.name]_[size].png")
		fdel("data/spritesheets/[sheet.name]_[size].png")
// APHELION EDIT ADDITION END
