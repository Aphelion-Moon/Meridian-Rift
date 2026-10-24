/// Minds with no memories, as cyborgs and AIs join with, are logged to the manifest without a runtime
/datum/unit_test/log_manifest_memoryless_mind

/datum/unit_test/log_manifest_memoryless_mind/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.mind_initialize()
	TEST_ASSERT_EQUAL(length(body.mind.memories), 0, "A new mind should start with no memories")
	log_manifest("log_manifest_test", body.mind, body)
