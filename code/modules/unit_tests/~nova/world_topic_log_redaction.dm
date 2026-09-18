/// Every concrete bridge topic must reject a missing credential before its handler runs.
/// Uses the normal TryRun() path; successful authentication and address policy are outside this test.
/datum/unit_test/symphony_topic_authentication/Run()
	for(var/datum/world_topic/symphony/topic_type as anything in subtypesof(/datum/world_topic/symphony))
		if(topic_type::abstract_type == topic_type)
			continue
		var/datum/world_topic/symphony/topic = allocate(topic_type)
		TEST_ASSERT(topic.require_comms_key, "[topic_type] does not require the shared comms key.")
		var/list/response = json_decode(topic.TryRun(list("format" = "json"), "127.0.0.1"))
		TEST_ASSERT_EQUAL(response["error"], "Bad Key", "[topic_type] accepted a missing comms key.")

/// Redact decoded credentials across parameter ordering, delimiters, and encoded key names.
/// Other values and the original authentication input must survive; public topics must not gain a key.
/datum/unit_test/world_topic_log_redaction/Run()
	var/list/queries = list(
		"symphony_kick=1&key=audit-test-secret&target_ckey=testplayer",
		"symphony_kick=1;key=audit-test-secret;target_ckey=testplayer",
		"symphony_kick=1&%6bey=audit-test-secret&target_ckey=testplayer",
		"key=audit-test-secret&symphony_kick=1&target_ckey=testplayer",
	)
	for(var/query in queries)
		var/list/input = params2list(query)
		var/logged = world_topic_log_parameters(input)
		var/list/logged_input = params2list(logged)
		TEST_ASSERT(!findtext(logged, "audit-test-secret"), "Topic log exposed a comms key from [query]")
		TEST_ASSERT_EQUAL(logged_input["key"], "***", "The parsed credential must be redacted")
		TEST_ASSERT_EQUAL(logged_input["target_ckey"], "testplayer", "Redaction must preserve the target ckey")
		TEST_ASSERT_EQUAL(logged_input["symphony_kick"], "1", "Redaction must preserve the topic keyword")
		TEST_ASSERT_EQUAL(input["key"], "audit-test-secret", "Logging must leave the authentication input unchanged")

	var/list/public_input = params2list("ping=1&message=hello%20%26%20goodbye")
	var/list/logged_public_input = params2list(world_topic_log_parameters(public_input))
	TEST_ASSERT(!("key" in logged_public_input), "Logging a public topic must not introduce a credential field")
	TEST_ASSERT_EQUAL(logged_public_input["message"], "hello & goodbye", "Logging must preserve decoded parameter values")
