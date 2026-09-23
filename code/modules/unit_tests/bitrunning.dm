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

/// Rejected requests and repeated cleanup must leave a usable server.
/datum/unit_test/bitrunner_invalid_domain/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	try
		TEST_ASSERT(!server.cold_boot_map("not_a_domain", FALSE), "Unknown domains must be rejected")
		server.scrub_vdom()
		server.scrub_vdom()
	catch(var/exception/error)
		TEST_FAIL("Empty-domain cleanup raised [error.name]")
	TEST_ASSERT(server.is_ready, "Rejected requests must not lock the server")

/datum/unit_test/bitrunner_test_domain_rejected/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	var/accepted = server.cold_boot_map("test_only", FALSE)
	server.scrub_vdom()
	TEST_ASSERT(!accepted, "Player requests must not load test-only domains")

/// Load the actual test map twice: each server must own its map and objective state.
/datum/unit_test/bitrunner_domain_isolation/Run()
	var/obj/machinery/quantum_server/first = allocate(/obj/machinery/quantum_server)
	var/obj/machinery/quantum_server/second = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(first.load_domain("unit_test_bitrunning"), "First domain should load")
	TEST_ASSERT(second.load_domain("unit_test_bitrunning"), "Second domain should load")
	var/datum/lazy_template/virtual_domain/first_domain = first.generated_domain
	var/datum/lazy_template/virtual_domain/second_domain = second.generated_domain
	if(first_domain == second_domain)
		TEST_FAIL("Servers must not share their live domain")
	first_domain.main_crate_points = 4
	if(second_domain.main_crate_points != 0)
		TEST_FAIL("Objective progress crossed between servers")
	var/datum/turf_reservation/second_reservation = second_domain.reservations[length(second_domain.reservations)]
	first.scrub_vdom()
	if(!length(second_reservation.reserved_turfs))
		TEST_FAIL("Resetting the first server released the second server's map")
	second.scrub_vdom()
	if(length(second_reservation.reserved_turfs))
		TEST_FAIL("Second server did not release its map")
	qdel(second_reservation)

/datum/unit_test/bitrunner_domain_replay/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	for(var/run in 1 to 3)
		TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Replay [run] should load")
		var/list/reservations = server.generated_domain.reservations.Copy()
		server.scrub_vdom()
		for(var/datum/turf_reservation/reservation as anything in reservations)
			if(length(reservation.reserved_turfs))
				TEST_FAIL("Replay [run] retained its map allocation")
			qdel(reservation)

/datum/unit_test/bitrunner_permanent_exit/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Test domain should load")
	var/datum/turf_reservation/reservation = server.generated_domain.reservations[length(server.generated_domain.reservations)]
	var/turf/exit_turf = reservation.reserved_turfs[1]
	new /obj/effect/landmark/bitrunning/permanent_exit(exit_turf)
	TEST_ASSERT(server.load_map_items(), "Domain landmarks should load")
	var/obj/structure/hololadder/ladder = locate() in exit_turf
	var/linked_correctly = ladder?.server_ref?.resolve() == server
	server.scrub_vdom()
	TEST_ASSERT(linked_correctly, "Permanent exit must link to its owning server")

/datum/unit_test/bitrunner_orphan_exit/Run()
	var/obj/structure/hololadder/ladder = allocate(/obj/structure/hololadder)
	var/mob/living/carbon/human/avatar = allocate(/mob/living/carbon/human)
	avatar.mind_initialize()
	try
		ladder.disconnect(avatar)
		ladder.examine(avatar)
	catch(var/exception/error)
		TEST_FAIL("Unlinked ladder raised [error.name]")

/datum/unit_test/bitrunner_blocked_spawn/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server, run_loc_floor_top_right)
	var/turf/blocked = run_loc_floor_bottom_left
	var/old_density = blocked.density
	blocked.density = TRUE
	var/turf/result = server.validate_turf(blocked)
	blocked.density = old_density
	TEST_ASSERT(result && result != blocked, "Blocked spawn must fall back to an open neighbor")

/datum/unit_test/bitrunner_helper_outfit/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Test domain should load")
	var/obj/item/antag_spawner/bitrunning_help/beacon = allocate(/obj/item/antag_spawner/bitrunning_help)
	var/mob/living/carbon/human/helper = allocate(/mob/living/carbon/human)
	beacon.equip_subcontractor(helper, server)
	TEST_ASSERT(locate(/obj/item/storage/medkit/regular) in helper.get_contents(), "Helper must receive the medical kit")
	TEST_ASSERT(locate(/obj/item/flashlight) in helper.get_contents(), "Helper must receive the flashlight")

/datum/unit_test/bitrunner_medical_charge/Run()
	var/obj/machinery/health_station/station = allocate(/obj/machinery/health_station)
	station.charge_amount = 15
	var/mob/living/carbon/human/first = allocate(/mob/living/carbon/human)
	var/mob/living/carbon/human/second = allocate(/mob/living/carbon/human)
	first.adjust_brute_loss(40)
	second.adjust_brute_loss(40)
	INVOKE_ASYNC(station, TYPE_PROC_REF(/obj/machinery/health_station, heal_damage), first)
	INVOKE_ASYNC(station, TYPE_PROC_REF(/obj/machinery/health_station, heal_damage), second)
	sleep(3 SECONDS)
	TEST_ASSERT(station.charge_amount >= 0, "Concurrent treatments must not overspend charge")
	TEST_ASSERT(first.get_brute_loss() + second.get_brute_loss() >= 40, "Only one treatment can use the last charge")

/datum/unit_test/bitrunner_anchor_ownership/Run()
	var/obj/machinery/quantum_server/first = allocate(/obj/machinery/quantum_server)
	var/obj/machinery/quantum_server/second = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(first.load_domain("unit_test_bitrunning"), "First domain should load")
	TEST_ASSERT(second.load_domain("unit_test_bitrunning"), "Second domain should load")
	first.max_anchors = 1
	second.max_anchors = 1
	var/datum/turf_reservation/reservation = first.generated_domain.reservations[length(first.generated_domain.reservations)]
	var/turf/destination = reservation.reserved_turfs[1]
	var/obj/item/domain_anchor/anchor = allocate(/obj/item/domain_anchor, destination)
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human, destination)
	anchor.attack_self(user)
	var/first_changed = (destination in first.exit_turfs)
	var/second_changed = length(second.exit_turfs) || second.current_anchors || second.retries_spent
	first.scrub_vdom()
	second.scrub_vdom()
	TEST_ASSERT(first_changed, "Anchor should add an exit to its own domain")
	TEST_ASSERT(!second_changed, "Anchor must not modify another server")

/datum/unit_test/bitrunner_beacon_ownership/Run()
	var/obj/machinery/quantum_server/first = allocate(/obj/machinery/quantum_server)
	var/obj/machinery/quantum_server/second = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(first.load_domain("unit_test_bitrunning"), "First domain should load")
	TEST_ASSERT(second.load_domain("unit_test_bitrunning"), "Second domain should load")
	var/datum/turf_reservation/first_reservation = first.generated_domain.reservations[length(first.generated_domain.reservations)]
	var/datum/turf_reservation/second_reservation = second.generated_domain.reservations[length(second.generated_domain.reservations)]
	first.exit_turfs += first_reservation.reserved_turfs[1]
	second.exit_turfs += second_reservation.reserved_turfs[1]
	var/obj/item/antag_spawner/bitrunning_help/beacon = allocate(/obj/item/antag_spawner/bitrunning_help, second_reservation.reserved_turfs[1])
	var/selected_correctly = beacon.get_available_server() == second
	beacon.forceMove(run_loc_floor_bottom_left)
	var/selected_outside_domain = beacon.get_available_server()
	first.scrub_vdom()
	second.scrub_vdom()
	TEST_ASSERT(selected_correctly, "Beacon must select the server owning its turf")
	TEST_ASSERT_NULL(selected_outside_domain, "Beacon must reject use outside a running domain")

/datum/unit_test/bitrunner_breach_cancel/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Test domain should load")
	var/obj/machinery/byteforge/forge = allocate(/obj/machinery/byteforge)
	var/datum/turf_reservation/reservation = server.generated_domain.reservations[length(server.generated_domain.reservations)]
	var/turf/goal = reservation.reserved_turfs[1]
	var/mob/living/carbon/human/antag = allocate(/mob/living/carbon/human, goal)
	server.spawned_threat_refs += WEAKREF(antag)
	var/starting_health = antag.maxHealth
	INVOKE_ASYNC(server, TYPE_PROC_REF(/obj/machinery/quantum_server, station_spawn), antag, forge, goal)
	sleep(2.3 SECONDS)
	antag.forceMove(run_loc_floor_bottom_left)
	sleep(1 SECONDS)
	var/still_tracked = (WEAKREF(antag) in server.spawned_threat_refs)
	var/health_unchanged = antag.maxHealth == starting_health
	server.scrub_vdom()
	TEST_ASSERT(still_tracked, "Cancelled breach must remain a tracked threat")
	TEST_ASSERT(health_unchanged, "Cancelled breach must not grant a health boost")

/datum/unit_test/bitrunner_glitch_cleanup/Run()
	var/mob/living/carbon/human/antag = allocate(/mob/living/carbon/human)
	var/datum/component/glitch/effect = antag.AddComponent(/datum/component/glitch)
	TEST_ASSERT_NOTNULL(antag.GetComponent(/datum/component/holographic_nature), "Fixture must have holographic effects before removal")
	qdel(effect)
	TEST_ASSERT_NULL(antag.GetComponent(/datum/component/holographic_nature), "Removing glitch must remove its holographic component")

/// Replace only the ghost poll, allowing a deterministic shutdown during that yield.
/obj/machinery/quantum_server/unit_test_shutdown_poll
	var/points_at_poll

/obj/machinery/quantum_server/unit_test_shutdown_poll/setup_glitch(datum/antagonist/bitrunning_glitch/forced_role)
	points_at_poll = points
	scrub_vdom()

/datum/unit_test/bitrunner_startup_shutdown/Run()
	var/obj/machinery/quantum_server/unit_test_shutdown_poll/server = allocate(/obj/machinery/quantum_server/unit_test_shutdown_poll)
	server.points = 10
	server.threat = 1000
	server.threat_prob_max = 100
	var/datum/lazy_template/virtual_domain/catalog
	for(var/datum/lazy_template/virtual_domain/domain as anything in SSbitrunning.all_domains)
		if(domain.key == "unit_test_bitrunning_expensive")
			catalog = domain
	var/old_flags = catalog.domain_flags
	catalog.domain_flags &= ~DOMAIN_TEST_ONLY
	try
		server.cold_boot_map(catalog.key, FALSE)
	catch(var/exception/error)
		TEST_FAIL("Shutdown during startup poll raised [error.name]")
	catalog.domain_flags = old_flags
	TEST_ASSERT_EQUAL(server.points_at_poll, 7, "Startup must charge the loaded domain before the ghost poll")

/datum/unit_test/bitrunner_medical_wound
	var/treatment_finished = FALSE

/datum/unit_test/bitrunner_medical_wound/Run()
	var/obj/machinery/health_station/station = allocate(/obj/machinery/health_station)
	station.charge_amount = 100
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human)
	var/datum/wound/wound = new /datum/wound/blunt/bone/moderate()
	wound.apply_wound(patient.get_bodypart(BODY_ZONE_R_ARM))
	TEST_ASSERT(length(patient.all_wounds), "Fixture should have a wound")
	INVOKE_ASYNC(src, PROC_REF(treat), station, patient)
	sleep(1 SECONDS)
	TEST_ASSERT(!treatment_finished, "Treatment must be waiting when the wound is removed")
	wound.remove_wound()
	sleep(8 SECONDS)
	TEST_ASSERT(treatment_finished, "Wound removal during treatment must complete safely")

/datum/unit_test/bitrunner_medical_wound/proc/treat(obj/machinery/health_station/station, mob/living/carbon/patient)
	try
		station.heal_wound(patient)
		treatment_finished = TRUE
	catch(var/exception/error)
		TEST_FAIL("Concurrent wound removal raised [error.name]")

/// Simulate only client possession; all helper initialization remains production code.
/obj/item/antag_spawner/bitrunning_help/unit_test_possession
	var/mob/living/carbon/human/created_helper

/obj/item/antag_spawner/bitrunning_help/unit_test_possession/create_subcontractor(client/our_client)
	created_helper = new()
	created_helper.mind_initialize()
	our_client.mob = created_helper
	return created_helper

/datum/unit_test/bitrunner_helper_mind/Run()
	var/mob/living/carbon/human/old_body = allocate(/mob/living/carbon/human)
	old_body.mind_initialize()
	var/mob/dead/observer/ghost = allocate(/mob/dead/observer)
	ghost.mind = old_body.mind
	var/datum/client_interface/client = new()
	client.mob = ghost
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Test domain should load")
	var/obj/item/antag_spawner/bitrunning_help/unit_test_possession/beacon = allocate(/obj/item/antag_spawner/bitrunning_help/unit_test_possession)
	beacon.spawn_antag(client, run_loc_floor_bottom_left, "subrunner", null, server)
	var/mob/living/carbon/human/helper = beacon.created_helper
	var/datum/component/temporary_body/temporary = helper.GetComponent(/datum/component/temporary_body)
	var/captured_old_mind = temporary?.old_mind == old_body.mind
	qdel(temporary)
	client.mob = null
	qdel(client)
	qdel(helper)
	TEST_ASSERT(captured_old_mind, "Helper must retain the ghost's original mind before possession")

/datum/lazy_template/virtual_domain/test_only/unit_test
	key = "unit_test_bitrunning"
	map_dir = "code/modules/unit_tests/fixtures"
	map_name = "bitrunning"

/datum/lazy_template/virtual_domain/test_only/unit_test/expensive
	key = "unit_test_bitrunning_expensive"
	cost = 3

/datum/unit_test/bitrunner_beacon_reservation/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	TEST_ASSERT(server.load_domain("unit_test_bitrunning"), "Test domain should load")
	var/datum/turf_reservation/reservation = server.generated_domain.reservations[1]
	var/turf/destination = reservation.reserved_turfs[1]
	server.exit_turfs += destination
	var/obj/item/antag_spawner/bitrunning_help/first = allocate(/obj/item/antag_spawner/bitrunning_help, destination)
	var/obj/item/antag_spawner/bitrunning_help/second = allocate(/obj/item/antag_spawner/bitrunning_help, destination)
	TEST_ASSERT(first.reserve_bandwidth(server), "First request should reserve the last retry")
	TEST_ASSERT(!second.reserve_bandwidth(server), "Second request must not reserve the same retry")
	TEST_ASSERT_EQUAL(server.available_retries(), 0, "Pending request must also block avatar admission")
	qdel(first)
	TEST_ASSERT_EQUAL(server.available_retries(), 1, "Deleting a pending beacon must refund its reservation")
	TEST_ASSERT(second.reserve_bandwidth(server), "Refunded bandwidth should be reusable")
	server.scrub_vdom()
	second.release_reservation()
	TEST_ASSERT_EQUAL(server.reserved_retries, 0, "Cleanup after shutdown must not leave negative reservations")

/// Fail after a real allocation, rather than only exercising invalid request validation.
/datum/lazy_template/virtual_domain/test_only/unit_test/load_failure
	key = "unit_test_bitrunning_load_failure"
	var/static/datum/turf_reservation/last_reservation

/datum/lazy_template/virtual_domain/test_only/unit_test/load_failure/lazy_load()
	last_reservation = ..()
	throw EXCEPTION("Intentional unit-test map loading failure")

/datum/unit_test/bitrunner_failed_load/Run()
	var/obj/machinery/quantum_server/server = allocate(/obj/machinery/quantum_server)
	var/datum/lazy_template/virtual_domain/test_only/unit_test/load_failure/catalog
	for(var/datum/lazy_template/virtual_domain/available as anything in SSbitrunning.all_domains)
		if(available.key == "unit_test_bitrunning_load_failure")
			catalog = available
	var/old_flags = catalog.domain_flags
	catalog.domain_flags &= ~DOMAIN_TEST_ONLY
	var/accepted = FALSE
	try
		accepted = server.cold_boot_map(catalog.key, FALSE)
	catch(var/exception/error)
		TEST_FAIL("Loading failure escaped cleanup: [error.name]")
	catalog.domain_flags = old_flags
	var/datum/turf_reservation/reservation = catalog.last_reservation
	catalog.last_reservation = null
	TEST_ASSERT_NOTNULL(reservation, "Fixture must fail after allocating its map")
	TEST_ASSERT(!accepted && server.is_ready && !server.generated_domain, "Failed load must leave the server usable")
	TEST_ASSERT(!length(reservation.reserved_turfs), "Failed load must release its allocation")
