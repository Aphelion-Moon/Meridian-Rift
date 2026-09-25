/** Verifies Kennel pin refresh, expiry, and manual-pin retention. */
/datum/unit_test/dogmos_kennel_structures
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture
/datum/unit_test/dogmos_kennel_structures/Run()
	SSair.diagnostics.structures_of_interest = list()

	var/obj/machinery/fake_machine = allocate(/obj/machinery)
	var/datum/component/gas_leaker/fake_gas_leaker = fake_machine.AddComponent(/datum/component/gas_leaker)
	SSair.start_processing_machine(fake_gas_leaker)
	TEST_ASSERT(fake_gas_leaker in SSair.atmos_machinery, \
		"SSair rejected the real gas-leaker component type from atmosphere processing.")
	SSair.stop_processing_machine(fake_gas_leaker)
	TEST_ASSERT(!(fake_gas_leaker in SSair.atmos_machinery), \
		"SSair did not remove a gas-leaker component from atmosphere processing.")
	var/list/browse_page = GLOB.dogmos_kennel.build_machinery_browse_page(
		list(fake_gas_leaker, fake_machine),
		"",
		1,
	)
	TEST_ASSERT_EQUAL(browse_page["total"], 1, \
		"Kennel machinery browse counted a gas-leaker component as machinery.")
	TEST_ASSERT_EQUAL(length(browse_page["rows"]), 1, \
		"Kennel machinery browse returned an unexpected number of rows for mixed processors.")
	TEST_ASSERT_EQUAL(browse_page["rows"][1]["ref"], REF(fake_machine), \
		"Kennel machinery browse did not retain the actual machinery row.")

	SSair.diagnostics.kennel_pin_structure(fake_machine, "first reason", 10 SECONDS)
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 1, \
		"Pinning a fresh target did not add exactly one entry - got [length(SSair.diagnostics.structures_of_interest)].")

	// Re-pin with a different reason: should update the SAME entry in place, not add a second one.
	SSair.diagnostics.kennel_pin_structure(fake_machine, "second reason", 20 SECONDS)
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 1, \
		"Re-pinning an already-pinned target added a duplicate entry instead of updating in place - got [length(SSair.diagnostics.structures_of_interest)].")
	var/list/entry = SSair.diagnostics.structures_of_interest[1]
	TEST_ASSERT_EQUAL(entry["reason"], "second reason", \
		"Re-pinning did not update the reason field - still [entry["reason"]].")

	// Force the (updated) pin's expiry into the past and confirm pruning actually removes it.
	entry["expires"] = world.time - 1
	SSair.diagnostics.kennel_prune_expired_pins()
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 0, \
		"kennel_prune_expired_pins() did not remove an entry whose expires deadline has already passed - [length(SSair.diagnostics.structures_of_interest)] entries remain.")

	// A manual pin (expires = null) must never be pruned, no matter how far world.time has moved.
	SSair.diagnostics.kennel_pin_structure(fake_machine, "manual pin", null)
	SSair.diagnostics.kennel_pin_structure(fake_machine, "automatic refresh", 1)
	TEST_ASSERT_NULL(SSair.diagnostics.structures_of_interest[1]["expires"], "Automatic refresh downgraded a manual pin.")
	SSair.diagnostics.kennel_unpin_structure(REF(fake_machine))
	SSair.diagnostics.kennel_pin_structure(fake_machine, "automatic", 1)
	SSair.diagnostics.kennel_pin_structure(fake_machine, "manual", null)
	TEST_ASSERT_NULL(SSair.diagnostics.structures_of_interest[1]["expires"], "Manual pin did not replace automatic expiry.")
	SSair.diagnostics.kennel_prune_expired_pins()
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 1, \
		"kennel_prune_expired_pins() removed a manual pin (expires = null) - manual pins must never expire.")

	SSair.diagnostics.kennel_unpin_structure(SSair.diagnostics.structures_of_interest[1]["ref"])
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 0, \
		"kennel_unpin_structure() did not remove the pinned entry by ref.")

	for(var/index in 1 to 250)
		SSair.diagnostics.structures_of_interest += list(list(
			"ref" = "bounded-test-[index]",
			"name" = "Bounded test [index]",
		))
	SSair.diagnostics.kennel_pin_structure(fake_machine, "bounded pin", null)
	TEST_ASSERT_EQUAL(length(SSair.diagnostics.structures_of_interest), 250, \
		"kennel_pin_structure() retained more than 250 structure rows.")
	TEST_ASSERT_EQUAL(SSair.diagnostics.structures_of_interest[250]["ref"], "bounded-test-249", \
		"kennel_pin_structure() did not evict the oldest structure row at the cap.")
	SSair.diagnostics.kennel_unpin_structure(REF(fake_machine))

	qdel(fake_machine)

/** Co-located pins retain one overlay through removal, movement, expiry and deletion. */
/datum/unit_test/dogmos_kennel_colocated_pins
	parent_type = /datum/unit_test/dogmos_diagnostics_fixture

/datum/unit_test/dogmos_kennel_colocated_pins/Run()
	var/turf/first = run_loc_floor_bottom_left
	var/turf/second = get_step(first, EAST)
	var/obj/machinery/one = allocate(/obj/machinery, first)
	var/obj/machinery/two = allocate(/obj/machinery, first)
	var/datum/dogmos_diagnostics/owner = SSair.diagnostics
	owner.kennel_pin_structure(one, "one", null)
	owner.kennel_pin_structure(two, "two", null)
	var/list/slots = GLOB.kennel_overlay_turfs[KENNEL_OVERLAY_STRUCTURE]
	TEST_ASSERT(first.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(first.z) + 1]), "Pinned turf has no overlay.")
	owner.kennel_unpin_structure(REF(one))
	TEST_ASSERT(first.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(first.z) + 1]), "Removing one pin hid the other pin's overlay.")
	owner.kennel_pin_structure(one, "one", null)
	one.forceMove(second)
	owner.kennel_prune_expired_pins()
	TEST_ASSERT(first.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(first.z) + 1]), "Moving one pin hid the stationary pin.")
	TEST_ASSERT(second.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(second.z) + 1]), "Moved pin did not acquire its new overlay.")
	owner.kennel_unpin_structure(REF(two))
	owner.kennel_pin_structure(two, "expires", 1)
	owner.structures_of_interest[1]["expires"] = world.time - 1
	owner.kennel_prune_expired_pins()
	TEST_ASSERT(!(first.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(first.z) + 1])), "Expired final pin left an overlay.")
	TEST_ASSERT(second.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(second.z) + 1]), "Unrelated expiry hid the moved pin.")
	qdel(one)
	owner.kennel_prune_expired_pins()
	TEST_ASSERT(!(second.vis_contents.Find(slots[GET_Z_PLANE_OFFSET(second.z) + 1])), "Deleted final target left an overlay.")
	TEST_ASSERT_EQUAL(length(owner.kennel_pinned_targets), 0, "Deleted targets remained indexed.")
