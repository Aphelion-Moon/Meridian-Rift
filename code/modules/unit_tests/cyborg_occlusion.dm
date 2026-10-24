/// Real admission/queue/cleanup with a yielding, instrumented generation operation.
/datum/asset/cyborg_occlusion/demand_test
	abstract_type = /datum/asset/cyborg_occlusion/demand_test
	/// How many times each model key was generated
	var/list/calls = list()
	/// Every staging file the jobs made, so the test can check they're gone
	var/list/temporary_paths = list()
	/// Model keys whose generation throws
	var/list/fail_keys = list()
	/// How many jobs are running right now
	var/active_jobs = 0
	/// The most jobs that ever ran at once
	var/max_active_jobs = 0
	/// Whether or not a job was ever handed another model's states
	var/foreign_state_seen = FALSE
	/// How many failures reached report_generation_failure()
	var/reported_failures = 0

/// Counts the job and makes a placeholder staging file, then yields so callers overlap. Throws for a key in fail_keys
/datum/asset/cyborg_occlusion/demand_test/generate_model(list/model, prefix, list/temporary_files)
	var/key = "[model["source"]]#[model["base"]]"
	calls[key]++
	active_jobs++
	max_active_jobs = max(max_active_jobs, active_jobs)
	for(var/list/state as anything in model["states"])
		if(state["model"] != model["base"])
			foreign_state_seen = TRUE
	var/path = "[prefix]-demand-test.dmi"
	temporary_files += path
	temporary_paths += path
	fcopy('icons/blanks/32x32.dmi', path)
	sleep(1)
	active_jobs--
	if(fail_keys[key])
		throw EXCEPTION("expected demand-only model failure")
	return 'icons/blanks/32x32.dmi'

/// Counts the report instead of logging it
/datum/asset/cyborg_occlusion/demand_test/report_generation_failure(key, exception/failure)
	reported_failures++

/// A model's mask is generated once, on request, and only that model's
/datum/unit_test/cyborg_occlusion_demand_reuse/Run()
	var/datum/asset/cyborg_occlusion/demand_test/asset = new
	TEST_ASSERT_EQUAL(length(asset.resources), 0, "Metadata construction must not generate unrelated models")
	var/list/first = asset.model_sources[asset.model_sources[1]]
	var/lease_count = SSasset_loading.assets_generating
	var/resource = asset.ensure_model_ready(first["source"], first["base"])
	TEST_ASSERT(isfile(resource), "The requested model returns an immutable file")
	TEST_ASSERT_EQUAL(asset.ensure_model_ready(first["source"], first["base"]), resource, "Repeated requests reuse the round resource")
	TEST_ASSERT_EQUAL(asset.ensure_model_ready(first["source"], "not-an-authored-model"), null, "Unknown keys never enter the generation queue")
	UNTIL(!asset.worker_running)
	TEST_ASSERT_EQUAL(asset.job_serial, 1, "One requested model causes exactly one job")
	TEST_ASSERT_EQUAL(length(asset.resources), 1, "Only the requested model is retained")
	TEST_ASSERT(!asset.foreign_state_seen, "A job must never receive another model's states")
	TEST_ASSERT_EQUAL(SSasset_loading.assets_generating, lease_count, "The generation lease is released")
	for(var/path in asset.temporary_paths)
		TEST_ASSERT(!fexists(path), "Completed jobs remove their staging files")
	GLOB.asset_datums -= asset.type
	qdel(asset)

/datum/unit_test/cyborg_occlusion_demand_concurrency
	/// How many requests finished, with a resource or a failure
	var/completions = 0
	/// How many requests got a resource
	var/successes = 0
	/// How many requests got a failure
	var/failures = 0
	/// The exception the last failed request caught
	var/exception/last_failure

/// One caller asking for a model's mask, counting how it ended
/datum/unit_test/cyborg_occlusion_demand_concurrency/proc/request(datum/asset/cyborg_occlusion/asset, list/model)
	try
		if(isfile(asset.ensure_model_ready(model["source"], model["base"])))
			successes++
	catch(var/exception/error)
		last_failure = error
		failures++
	completions++

/// A hundred callers for three models share three jobs, run one at a time
/datum/unit_test/cyborg_occlusion_demand_concurrency/Run()
	var/datum/asset/cyborg_occlusion/demand_test/asset = new
	var/lease_count = SSasset_loading.assets_generating
	for(var/index in 1 to 100)
		var/key = asset.model_sources[((index - 1) % 3) + 1]
		INVOKE_ASYNC(src, PROC_REF(request), asset, asset.model_sources[key])
	UNTIL(completions == 100 && !asset.worker_running)
	TEST_ASSERT_EQUAL(successes, 100, "Every concurrent caller receives its shared result")
	TEST_ASSERT_EQUAL(failures, 0, "Successful model joins must not fail")
	TEST_ASSERT_EQUAL(asset.max_active_jobs, 1, "Only one model may generate at a time")
	TEST_ASSERT_EQUAL(asset.job_serial, 3, "One hundred callers for three keys generate exactly three models")
	TEST_ASSERT_EQUAL(length(asset.resources), 3, "Unrequested models remain absent")
	TEST_ASSERT_EQUAL(length(asset.pending), 0, "All admitted requests complete")
	TEST_ASSERT_EQUAL(length(asset.queue), 0, "Completed work leaves no queue entries")
	TEST_ASSERT_EQUAL(SSasset_loading.assets_generating, lease_count, "Concurrent joins cannot leak generation leases")
	TEST_ASSERT(!asset.foreign_state_seen, "Each job receives only its requested model")
	for(var/key in asset.calls)
		TEST_ASSERT_EQUAL(asset.calls[key], 1, "Concurrent requests deduplicate each model")
	for(var/path in asset.temporary_paths)
		TEST_ASSERT(!fexists(path), "Queued jobs clean each model's staging files")
	GLOB.asset_datums -= asset.type
	qdel(asset)

/datum/unit_test/cyborg_occlusion_demand_failure
	parent_type = /datum/unit_test/cyborg_occlusion_demand_concurrency

/// A failed model throws the same exception to every caller, is reported once and doesn't block the next model
/datum/unit_test/cyborg_occlusion_demand_failure/Run()
	var/datum/asset/cyborg_occlusion/demand_test/asset = new
	var/lease_count = SSasset_loading.assets_generating
	var/failed_key = asset.model_sources[1]
	var/successful_key = asset.model_sources[2]
	asset.fail_keys[failed_key] = TRUE
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/cyborg_occlusion_demand_concurrency, request), asset, asset.model_sources[failed_key])
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/cyborg_occlusion_demand_concurrency, request), asset, asset.model_sources[failed_key])
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/cyborg_occlusion_demand_concurrency, request), asset, asset.model_sources[successful_key])
	UNTIL(completions == 3 && !asset.worker_running)
	TEST_ASSERT_EQUAL(failures, 2, "Every failed-key join observes the failure")
	TEST_ASSERT_EQUAL(last_failure, asset.failures[failed_key], "Concurrent joins preserve the original exception")
	TEST_ASSERT_EQUAL(successes, 1, "A failed model must not block the next distinct model")
	TEST_ASSERT_EQUAL(asset.reported_failures, 1, "The worker reports a failure once, not once per waiting editor")
	request(asset, asset.model_sources[failed_key])
	TEST_ASSERT_EQUAL(failures, 3, "A subsequent failed-key request observes the same failure")
	TEST_ASSERT_EQUAL(last_failure, asset.failures[failed_key], "Repeated requests preserve the cached exception identity")
	TEST_ASSERT_EQUAL(asset.reported_failures, 1, "Cached failures are not repeatedly logged")
	TEST_ASSERT_EQUAL(asset.job_serial, 2, "A failed model is not automatically retried by joining clients")
	TEST_ASSERT_EQUAL(length(asset.resources), 1, "Only the successful model is published")
	TEST_ASSERT(asset.resources[successful_key], "The succeeding key owns its result")
	TEST_ASSERT(!asset.resources[failed_key], "A failed key cannot inherit the previous job's result")
	TEST_ASSERT_EQUAL(length(asset.pending), 0, "Failure releases all joins")
	TEST_ASSERT_EQUAL(length(asset.queue), 0, "Failure does not strand the queue")
	TEST_ASSERT_EQUAL(SSasset_loading.assets_generating, lease_count, "Failure releases the generation lease")
	for(var/path in asset.temporary_paths)
		TEST_ASSERT(!fexists(path), "Failed jobs remove their owned staging files")
	GLOB.asset_datums -= asset.type
	qdel(asset)

/// The real generator publishes one resource per model and reuses it
/datum/unit_test/cyborg_occlusion_native_model/Run()
	var/datum/asset/cyborg_occlusion/asset = get_asset_datum(/datum/asset/cyborg_occlusion)
	var/list/model = asset.model_sources[asset.model_sources[1]]
	var/resource = cyborg_occlusion_ensure_model_ready(model["source"], model["base"])
	TEST_ASSERT(isfile(resource), "Production generation publishes an immutable model resource")
	TEST_ASSERT_EQUAL(resource, cyborg_occlusion_cached(model["source"], model["base"]), "Live lookup reuses the completed resource without waiting")
	TEST_ASSERT_EQUAL(resource, cyborg_occlusion_ensure_model_ready(model["source"], model["base"]), "Repeated requests reuse native output")
	for(var/list/state as anything in model["states"])
		var/icon/selected = icon(resource, state["state"], moving = state["moving"])
		TEST_ASSERT_EQUAL(selected.Width(), model["width"], "Native width must match [state["state"]] moving=[state["moving"]] before any export")
		TEST_ASSERT_EQUAL(selected.Height(), model["height"], "Native height must match [state["state"]] moving=[state["moving"]] before any export")
