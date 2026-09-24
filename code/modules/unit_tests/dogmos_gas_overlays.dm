/** Verifies the multiz gas-overlay table consumed by Rust visual updates. */
/datum/unit_test/dogmos_gas_overlays
	/// Borrowed turf and gas restored before fixture allocations are deleted.
	var/turf/open/site
	var/datum/gas_mixture/saved_air

/datum/unit_test/dogmos_gas_overlays/Destroy()
	if(site)
		site.air = saved_air
		site.update_visuals()
	site = null
	saved_air = null
	return ..()

/datum/unit_test/dogmos_gas_overlays/Run()
	TEST_ASSERT(length(GLOB.gas_data.overlays), \
		"GLOB.gas_data.overlays is empty - Rust's set_visuals callback would never resolve any overlay, so no gas would ever render visually once SSAIR_ACTIVETURFS moves to Rust.")

	// Plasma is always visible (moles_visible is set) - a reliable known-good probe.
	var/plasma_id = initial(/datum/gas/plasma::id)
	var/list/plasma_overlays = GLOB.gas_data.overlays[plasma_id]
	TEST_ASSERT_NOTNULL(plasma_overlays, \
		"GLOB.gas_data.overlays has no entry for plasma (id [plasma_id]) despite plasma being a visible gas.")

	TEST_ASSERT(istype(plasma_overlays[1], /list), \
		"plasma's plane-offset-0 entry (index 1) is not a list - expected the per-visibility-state overlay table (the +1 is GET_TURF_PLANE_OFFSET()'s indexing convention, code/__HELPERS/_planes.dm).")
	var/list/state_table = plasma_overlays[1]
	TEST_ASSERT_EQUAL(length(state_table), TOTAL_VISIBLE_STATES, \
		"plasma's plane-offset-0 overlay table has [length(state_table)] entries, expected TOTAL_VISIBLE_STATES ([TOTAL_VISIBLE_STATES]).")
	TEST_ASSERT(istype(state_table[1], /obj/effect/overlay/gas), \
		"plasma's plane-offset-0, visibility-state-1 entry is not a /obj/effect/overlay/gas instance.")

	// Must be the SAME list object GLOB.meta_gas_info already owns, not a copy - otherwise SSmapping
	// growing z_level_to_plane_offset for a new z-level after roundstart (code/controllers/subsystem/mapping.dm)
	// would update meta_gas_info's table but silently leave gas_data's copy stale.
	TEST_ASSERT_EQUAL(plasma_overlays, GLOB.meta_gas_info[META_GAS_OVERLAY][/datum/gas/plasma], \
		"plasma's entry in GLOB.gas_data.overlays is not the same list object as GLOB.meta_gas_info[META_GAS_OVERLAY][/datum/gas/plasma] - a new plane offset added later would desync them.")

	// A gas with no moles_visible (e.g. nitrogen) should have no entry at all, not an empty/garbage one.
	var/nitrogen_id = initial(/datum/gas/nitrogen::id)
	TEST_ASSERT_NULL(GLOB.gas_data.overlays[nitrogen_id], \
		"GLOB.gas_data.overlays has an entry for nitrogen, which has no moles_visible and should never have generated any overlay objects to reference.")

	// APHELION EDIT ADDITION START - DOGMOS
	// Exercise the renderer at and above the old native 20-state cap.
	site = run_loc_floor_bottom_left
	saved_air = site.air
	var/datum/gas_mixture/sample = allocate(/datum/gas_mixture)
	site.air = sample
	var/sample_references = refcount(sample)
	for(var/moles in list(0.25, 0.5, 5, 5.25, 12, 20, 100))
		sample.set_moles(GAS_PLASMA, moles)
		site.update_visuals()
		var/list/expected = sample.return_visuals(site)
		TEST_ASSERT_EQUAL(length(site.atmos_overlay_types), length(expected), "Native renderer has different visibility at [moles] moles.")
		if(length(expected))
			TEST_ASSERT_EQUAL(site.atmos_overlay_types[1], expected[1], "Native renderer selected the wrong opacity at [moles] moles.")
	sample.set_moles(GAS_PLASMA, 0)
	site.update_visuals()
	TEST_ASSERT_EQUAL(length(site.atmos_overlay_types), 0, "Consumed gas left a stale overlay.")
	TEST_ASSERT_EQUAL(refcount(sample), sample_references, "Visual updates retained native gas references.")
	// APHELION EDIT ADDITION END

/** Probe only; the surrounding test verifies cleanup after its expected early failure. */
/datum/unit_test/dogmos_gas_overlays/cleanup_probe
	abstract_type = /datum/unit_test/dogmos_gas_overlays/cleanup_probe

/datum/unit_test/dogmos_gas_overlays/cleanup_probe/Run()
	site = run_loc_floor_bottom_left
	saved_air = site.air
	site.air = allocate(/datum/gas_mixture)
	TEST_ASSERT(site.air == saved_air, "expected fixture early-exit probe")

/** Borrowed turf air is restored even when an assertion skips the test body tail. */
/datum/unit_test/dogmos_gas_overlay_cleanup

/datum/unit_test/dogmos_gas_overlay_cleanup/Run()
	var/turf/open/site = run_loc_floor_bottom_left
	var/datum/gas_mixture/original_air = site.air
	var/datum/unit_test/dogmos_gas_overlays/cleanup_probe/probe = allocate(/datum/unit_test/dogmos_gas_overlays/cleanup_probe)
	probe.Run()
	var/probe_failed = !probe.succeeded
	qdel(probe)
	TEST_ASSERT(probe_failed, "The fixture did not take its expected early-failure path.")
	TEST_ASSERT_EQUAL(site.air, original_air, "An early fixture exit retained borrowed test air.")
	TEST_ASSERT(!QDELETED(site.air), "Fixture cleanup deleted the restored mixture.")
