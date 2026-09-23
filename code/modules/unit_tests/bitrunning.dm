/// Ensures settings on vdoms are correct
/datum/unit_test/bitrunner_vdom_settings

/datum/unit_test/bitrunner_vdom_settings/Run()
	var/obj/structure/closet/crate/secure/bitrunning/decrypted/cache = allocate(/obj/structure/closet/crate/secure/bitrunning/decrypted)

	for(var/path in subtypesof(/datum/lazy_template/virtual_domain))
		var/datum/lazy_template/virtual_domain/vdom = new path
		TEST_ASSERT_NOTNULL(vdom.key, "[path] should have a key")
		TEST_ASSERT_NOTNULL(vdom.map_name, "[path] should have a map name")

		if(!length(vdom.completion_loot))
			continue

		TEST_ASSERT_EQUAL(cache.spawn_loot(vdom.completion_loot), TRUE, "[path] didn't spawn loot. Completion loot should be an associative list")

/// Exercise the real movement signals and disconnect delay, without needing a connected client.
/datum/unit_test/bitrunner_hololadder
	abstract_type = /datum/unit_test/bitrunner_hololadder
	var/avatar_type = /mob/living/carbon/human
	var/click_to_disconnect = FALSE
	var/interrupt_disconnect = FALSE
	var/disconnects = 0

/datum/unit_test/bitrunner_hololadder/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server, run_loc_floor_top_right)
	var/turf/ladder_turf = get_step(run_loc_floor_bottom_left, EAST)
	var/obj/structure/hololadder/ladder = allocate(/obj/structure/hololadder, ladder_turf, server)
	ladder.travel_time = 0.5 SECONDS
	var/mob/living/avatar = allocate(avatar_type)
	QDEL_NULL(avatar.ai_controller)
	avatar.mind_initialize()
	ADD_TRAIT(avatar, TRAIT_TEMPORARY_BODY, TRAIT_SOURCE_UNIT_TESTS)
	RegisterSignal(avatar, COMSIG_BITRUNNER_LADDER_SEVER, PROC_REF(on_disconnect))

	if(click_to_disconnect)
		INVOKE_ASYNC(ladder, TYPE_PROC_REF(/atom, attack_hand), avatar)
	else
		TEST_ASSERT(avatar.Move(ladder_turf, EAST), "Avatar should be able to walk onto the hololadder")

	TEST_ASSERT_EQUAL(disconnects, 0, "Disconnect should still require its delay")
	if(interrupt_disconnect)
		TEST_ASSERT(avatar.Move(run_loc_floor_bottom_left, WEST), "Avatar should be able to walk away during disconnect")

	sleep(ladder.travel_time + 1 SECONDS)
	TEST_ASSERT_EQUAL(disconnects, interrupt_disconnect ? 0 : 1, "Standing on or clicking the ladder should disconnect once; walking away should cancel")

/datum/unit_test/bitrunner_hololadder/proc/on_disconnect(datum/source)
	SIGNAL_HANDLER
	disconnects++

/datum/unit_test/bitrunner_hololadder/walk_human

/datum/unit_test/bitrunner_hololadder/walk_gondola
	avatar_type = /mob/living/basic/pet/gondola/virtual_domain

/datum/unit_test/bitrunner_hololadder/click_human
	click_to_disconnect = TRUE

/datum/unit_test/bitrunner_hololadder/walk_away
	interrupt_disconnect = TRUE
