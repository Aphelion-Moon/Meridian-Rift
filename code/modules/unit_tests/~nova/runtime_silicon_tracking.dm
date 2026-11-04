/// Makes the camera visibility boundary deterministic while exercising the real silicon Topic and tracking tool.
/mob/living/carbon/human/consistent/runtime_tracking_target/can_track(mob/living/user)
	return TRUE

/// One tracking link must start tracking once, through the inherited silicon handler.
/datum/unit_test/runtime_silicon_tracking
	/// Number of real tracking-start notifications emitted for the clicked link.
	var/tracking_starts = 0

/datum/unit_test/runtime_silicon_tracking/proc/on_tracking_started(datum/source, mob/living/target)
	SIGNAL_HANDLER
	tracking_starts++

/datum/unit_test/runtime_silicon_tracking/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/mob/living/silicon/ai/ai = allocate(/mob/living/silicon/ai, run_loc_floor_bottom_left, donor, /datum/ai_laws/default/asimov, null, TRUE)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent/runtime_tracking_target)
	target.name = "Runtime tracking target"
	RegisterSignal(ai.ai_tracking_tool, COMSIG_TRACKABLE_TRACKING_STARTED, PROC_REF(on_tracking_started))
	ai.Topic("", list("track" = target.name))
	TEST_ASSERT_EQUAL(ai.ai_tracking_tool.tracked_mob, target, "The tracking link did not select the requested target.")
	TEST_ASSERT_EQUAL(tracking_starts, 1, "The Nova Topic handler dispatched the same tracking request more than once.")
