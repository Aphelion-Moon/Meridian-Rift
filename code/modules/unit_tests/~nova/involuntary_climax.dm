/// Pleasure past the auto-climax threshold climaxes the player, and its caller - Life(), a process() or a status
/// effect - goes on at once, even while the climax waits on the player.
/datum/unit_test/involuntary_climax
	parent_type = /datum/unit_test/portal_test // For attach_portal_preferences(), a mock player's preferences.

/datum/unit_test/involuntary_climax/Run()
	if(CONFIG_GET(flag/disable_erp_preferences))
		TEST_NOTICE(src, "The ERP config removes the preference this test needs.")
		return
	var/mob/living/carbon/human/consistent/waiting_climax/person = allocate(/mob/living/carbon/human/consistent/waiting_climax)
	attach_portal_preferences(person)
	var/start = world.time
	person.adjust_pleasure(AROUSAL_LIMIT)
	if(!person.climaxing)
		TEST_FAIL("Pleasure past the auto-climax threshold did not climax.")
	if(world.time != start)
		TEST_FAIL("adjust_pleasure() waited [world.time - start] ds on a climax that waits on its player.")

/// A human whose climax waits on its player, as one that asks where to finish does - a prompt needs a real client.
/mob/living/carbon/human/consistent/waiting_climax
	/// Whether climax() has begun.
	var/climaxing = FALSE

/mob/living/carbon/human/consistent/waiting_climax/climax(manual = TRUE)
	climaxing = TRUE
	sleep(1 SECONDS)
