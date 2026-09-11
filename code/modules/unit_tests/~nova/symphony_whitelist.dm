/// Checks admission caching, stale-query invalidation, outages, and uncached role entitlements.
/// The database fixture snapshots each answer before invoking a callback, reproducing query-completion
/// ordering without actually sleeping or allowing other subsystems to observe the temporary test state.
/datum/unit_test/symphony_whitelist/Run()
	var/datum/controller/subsystem/dbcore/original_db = SSdbcore
	// Save the static cache, expiry, and epoch together so the original state can be restored consistently.
	var/list/original_cache = SSsymphony.whitelist_cache
	var/list/original_expiry = SSsymphony.whitelist_cache_expiry
	var/original_epoch = SSsymphony.whitelist_epoch
	var/original_enforcement = CONFIG_GET(flag/symphony_enabled)
	var/datum/controller/subsystem/dbcore/symphony_test/database = new
	SSdbcore = database
	SSsymphony.whitelist_cache = list()
	SSsymphony.whitelist_cache_expiry = list()

	// A grant or revoke received during a query supersedes its captured answer.
	for(var/authoritative_answer in list(FALSE, TRUE))
		symphony_invalidate_whitelist_cache("symphonytest")
		database.answer = !authoritative_answer
		database.during_query = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_seed_whitelist_cache), "symphonytest", authoritative_answer)
		if(symphony_whitelist_lookup("symphonytest") != authoritative_answer)
			TEST_FAIL("An overtaken whitelist query returned its stale answer instead of the current grant/revoke.")

	// Invalidation without a replacement answer requires one fresh query.
	symphony_invalidate_whitelist_cache("symphonytest")
	database.answer = TRUE
	database.during_query = CALLBACK(src, PROC_REF(invalidate_during_query), database)
	var/previous_queries = database.query_count
	if(symphony_whitelist_lookup("symphonytest") != FALSE || database.query_count != previous_queries + 2)
		TEST_FAIL("Invalidation without a replacement answer must retry before authorizing entry.")

	// A newer grant still wins when the earlier query fails.
	symphony_invalidate_whitelist_cache("symphonytest")
	database.query_succeeds = FALSE
	database.during_query = CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_seed_whitelist_cache), "symphonytest", TRUE)
	if(symphony_whitelist_lookup("symphonytest") != TRUE)
		TEST_FAIL("An authoritative grant must survive an older query failing.")

	// Without a notification, a failed query remains unknown and must not cache a denial.
	symphony_invalidate_whitelist_cache("symphonytest")
	if(!isnull(symphony_whitelist_lookup("symphonytest")) || !isnull(symphony_whitelist_cache_peek("symphonytest")))
		TEST_FAIL("A database outage must remain unknown and must not cache a rejection.")

	// An unchanged successful result serves the second lookup from cache.
	database.query_succeeds = TRUE
	database.answer = TRUE
	previous_queries = database.query_count
	if(!symphony_whitelist_lookup("symphonytest") || !symphony_whitelist_lookup("symphonytest") || database.query_count != previous_queries + 1)
		TEST_FAIL("An unchanged successful query should populate the existing burst cache.")

	// Entitlements bypass the admission cache but still retry when a role change overtakes their query.
	CONFIG_SET(flag/symphony_enabled, TRUE)
	for(var/authoritative_answer in list(FALSE, TRUE))
		database.answer = !authoritative_answer
		database.during_query = CALLBACK(src, PROC_REF(change_role_during_query), database, authoritative_answer)
		if(symphony_holds_whitelist_role("symphonytest") != authoritative_answer)
			TEST_FAIL("An entitlement lookup must retry a query overtaken by a grant/revoke.")
	// The module may be disabled while the entitlement query is pending.
	database.answer = TRUE
	database.during_query = CALLBACK(src, PROC_REF(disable_during_query))
	if(symphony_holds_whitelist_role("symphonytest"))
		TEST_FAIL("Disabling Symphony while the entitlement query sleeps must not grant the entitlement.")
	// A cached admission grant cannot substitute for a current entitlement check.
	CONFIG_SET(flag/symphony_enabled, TRUE)
	database.answer = FALSE
	symphony_seed_whitelist_cache("symphonytest", TRUE)
	if(symphony_holds_whitelist_role("symphonytest"))
		TEST_FAIL("Entitlement checks must retain their fresh-query semantics, bypassing the entry cache.")

	SSdbcore = original_db
	SSsymphony.whitelist_cache = original_cache
	SSsymphony.whitelist_cache_expiry = original_expiry
	SSsymphony.whitelist_epoch = original_epoch
	CONFIG_SET(flag/symphony_enabled, original_enforcement)
	qdel(database)

/datum/unit_test/symphony_whitelist/proc/invalidate_during_query(datum/controller/subsystem/dbcore/symphony_test/database)
	symphony_invalidate_whitelist_cache("symphonytest")
	database.answer = FALSE

/datum/unit_test/symphony_whitelist/proc/change_role_during_query(datum/controller/subsystem/dbcore/symphony_test/database, answer)
	database.answer = answer
	symphony_seed_whitelist_cache("symphonytest", answer)

/datum/unit_test/symphony_whitelist/proc/disable_during_query()
	CONFIG_SET(flag/symphony_enabled, FALSE)

/// Deliberately skips the subsystem constructor: constructing a second DB must not replace/delete SSdbcore.
/datum/controller/subsystem/dbcore/symphony_test/New()
	return

/// Configurable query results and callbacks; query_count distinguishes retries from cache hits.
/datum/controller/subsystem/dbcore/symphony_test
	name = "Symphony whitelist test fixture"
	ss_flags = SS_NO_INIT | SS_NO_FIRE
	var/answer = TRUE
	var/query_succeeds = TRUE
	var/query_count = 0
	var/datum/callback/during_query

/datum/controller/subsystem/dbcore/symphony_test/OnConfigLoad()
	return

/datum/controller/subsystem/dbcore/symphony_test/Shutdown()
	return

/datum/controller/subsystem/dbcore/symphony_test/Connect()
	return TRUE

/// Capture the answer now, so the callback can change subsequent queries without rewriting this result.
/datum/controller/subsystem/dbcore/symphony_test/NewQuery(sql_query, arguments, allow_during_shutdown = FALSE)
	query_count++
	var/datum/db_query/symphony_test/query = new
	query.answer = answer
	query.query_succeeds = query_succeeds
	query.during_query = during_query
	during_query = null
	return query

/// A captured answer plus an optional state change applied before that answer is returned.
/datum/db_query/symphony_test
	var/answer
	var/query_succeeds
	var/datum/callback/during_query

/datum/db_query/symphony_test/New()
	return

/datum/db_query/symphony_test/Destroy()
	during_query = null
	return ..()

/datum/db_query/symphony_test/warn_execute(async = TRUE)
	// Reproduce the ordering at the sleeping query boundary without yielding the global test fixture to other subsystems.
	during_query?.Invoke()
	return query_succeeds

/datum/db_query/symphony_test/NextRow(async = TRUE)
	return answer
