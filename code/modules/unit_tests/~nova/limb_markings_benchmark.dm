/**
 * Measures what the nested-list marking representation costs, so the datumisation has a number to beat.
 *
 * Writes data/markings_benchmark.json: the whole world.Profile payload for the drive, a wall clock reading
 * per phase, and the counts DM can take directly - marking list lengths, limb icon cache size, and the
 * appearance and height filter counts a fully-marked tall body carries.
 *
 * The fixture lives in limb_markings_appearance.dm, because both baselines have to dress the same
 * character for their numbers to be comparable.
 */

/// Steady-state update_body_parts() passes per loop. Enough for the per-call key rebuild to dominate the
/// reading, small enough that neither loop needs to yield and distort its own wall clock.
#define MARKINGS_BENCHMARK_BODY_PASSES 300
/// How many times the whole limbs_and_markings action set is driven. Every action but the colour change
/// re-renders the preview.
#define MARKINGS_BENCHMARK_ACTION_ROUNDS 5
/// rust-g stopwatch key, reset at the start of a phase and read at the end of it.
#define MARKINGS_BENCHMARK_CLOCK "markings_benchmark"
/// Seeds the preview's randomised character and add_marking's random picks, so every run drives the same content.
/// Kept under a million, so it survives BYOND's float precision and json_encode's six significant digits intact.
#define MARKINGS_BENCHMARK_SEED 260927

/// Records the cost of the pre-datumisation marking representation.
/datum/unit_test/markings_baseline/benchmark
	// Ahead of the appearance baseline, so no fixture transition is served from the renders it caches.
	priority = TEST_LONGER - 1
	/// Where the measurements land.
	var/output_path = "data/markings_benchmark.json"
	/// phase name -> microseconds spent in it, in drive order.
	var/list/timings = list()
	/// Everything countable about the fixture.
	var/list/counters = list()
	/// Anything that could not be driven, so the numbers never have to be guessed at.
	var/list/notes = list()
	/// Whether world.Profile is running for this test.
	var/profiling = FALSE

/datum/unit_test/markings_baseline/benchmark/Destroy()
	// A runtime inside the drive would otherwise leave the profiler running through every later test.
	if(profiling)
		world.Profile(PROFILE_STOP)
	return ..()

/**
 * Times one phase of the drive.
 *
 * Arguments:
 * - phase: the key this phase takes in the output file.
 * - started: the stopwatch reading taken before the phase, in microseconds.
 * - passes: how many units of work the phase did, for a per-call average.
 */
/datum/unit_test/markings_baseline/benchmark/proc/record(phase, started, passes = 1)
	var/elapsed = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK) - started
	timings[phase] = list(
		"microseconds" = elapsed,
		"passes" = passes,
		"microseconds_per_pass" = passes ? (elapsed / passes) : elapsed,
	)

/**
 * Lets the master controller run between two phases without profiling it.
 *
 * world.Profile is global, so the subsystems firing during a yield would otherwise land in the drive's profile.
 */
/datum/unit_test/markings_baseline/benchmark/proc/yield_unprofiled()
	world.Profile(PROFILE_STOP)
	CHECK_TICK
	world.Profile(PROFILE_START)

/**
 * Counts the marking lists a fully-marked body is carrying, per limb and in total.
 *
 * These are the allocations the datumisation removes, so they are the before half of that comparison.
 * update_limb() copies each zone map onto the limb but not the tuples inside it, so a list the DNA also
 * holds is counted as shared rather than as the limb's own.
 *
 * Arguments:
 * - target: the human to count.
 *
 * Returns a list of counters keyed for the output file.
 */
/datum/unit_test/markings_baseline/benchmark/proc/count_marking_lists(mob/living/carbon/human/target)
	var/total_entries = 0
	var/total_owned = 0
	var/total_shared = 0
	var/list/per_limb = list()
	for(var/obj/item/bodypart/limb as anything in target.bodyparts)
		var/body_entries = length(limb.markings)
		var/aux_entries = length(limb.aux_zone_markings)
		var/list/held = list()
		held[limb.body_zone] = limb.markings
		if(limb.aux_zone)
			held[limb.aux_zone] = limb.aux_zone_markings
		var/owned = 0
		var/shared = 0
		for(var/zone, worn in held)
			var/list/worn_list = worn
			if(!length(worn_list))
				continue
			var/list/dna_worn = target.dna.body_markings[zone]
			if(worn_list == dna_worn)
				shared++
			else
				owned++
			for(var/marking_name, tuple in worn_list)
				if(tuple == dna_worn?[marking_name])
					shared++
				else
					owned++
		total_entries += body_entries + aux_entries
		total_owned += owned
		total_shared += shared
		per_limb[limb.body_zone] = list(
			"markings" = body_entries,
			"aux_markings" = aux_entries,
			"lists_owned" = owned,
			"lists_shared_with_dna" = shared,
			"markings_alpha" = limb.markings_alpha,
		)
	var/dna_entries = 0
	for(var/zone, worn in target.dna.body_markings)
		var/list/worn_list = worn
		dna_entries += length(worn_list)
	return list(
		"limb_entries" = total_entries,
		"limb_lists_owned" = total_owned,
		"limb_lists_shared_with_dna" = total_shared,
		"dna_zones" = length(target.dna.body_markings),
		"dna_entries" = dna_entries,
		// The outer map, one map per zone, and one tuple per entry.
		"dna_lists" = 1 + length(target.dna.body_markings) + dna_entries,
		"per_limb" = per_limb,
	)

/**
 * Drives the limbs_and_markings action set the prefs menu exposes.
 *
 * color_marking opens a blocking tgui modal, so it is only driven when usr is unset: the picker then
 * returns null, so the action rebuilds its zone map but neither stores it nor re-renders the preview.
 * change_marking renames to a fixture marking, so its target never depends on the order of
 * GLOB.body_markings_per_limb.
 *
 * Arguments:
 * - middleware: the middleware to drive.
 * - preferences: the preferences it is editing.
 * - user: the mob passed through as the acting user.
 *
 * Returns the number of actions that were driven.
 */
/datum/unit_test/markings_baseline/benchmark/proc/drive_actions(datum/preference_middleware/limbs_and_markings/middleware, datum/preferences/preferences, mob/user)
	var/zone = BODY_ZONE_L_ARM
	var/driven = 0
	var/datum/body_marking_set/preset = GLOB.body_marking_sets["Tajaran"]
	for(var/round in 1 to MARKINGS_BENCHMARK_ACTION_ROUNDS)
		if(preset)
			middleware.set_preset(list("preset" = preset.name), user)
			driven++
		// A preset only fills the zones it covers, so make sure this one has a row to edit.
		while(length(preferences.body_markings[zone]) < MAXIMUM_MARKINGS_PER_LIMB)
			if(!middleware.add_marking(list("bodypart_slot" = zone), user))
				break
			driven++
		var/marking_id = "[zone]_1"
		if(!length(preferences.body_markings[zone]))
			continue
		var/replacement
		for(var/candidate in markings_baseline_marking_names())
			if(!(candidate in preferences.body_markings[zone]))
				replacement = candidate
				break
		if(replacement && middleware.change_marking(list("bodypart_slot" = zone, "marking_id" = marking_id, "marking_name" = replacement), user))
			driven++
		if(isnull(usr))
			middleware.color_marking(list("bodypart_slot" = zone, "marking_id" = marking_id), user)
			driven++
		middleware.change_emissive_marking(list("bodypart_slot" = zone, "marking_id" = marking_id, "emissive" = FALSE), user)
		driven++
		middleware.remove_marking(list("bodypart_slot" = zone, "marking_id" = marking_id), user)
		driven++
	return driven

/datum/unit_test/markings_baseline/benchmark/Run()
	var/mob/living/carbon/human/human = build_marked_human()
	counters["fixture"] = count_marking_lists(human)

	// A mock client and preview view, so the prefs-menu actions can be driven the way LimbsPage does.
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	// A new character rolls a random appearance and species, so the roll is seeded to come out the same every run.
	rand_seed(MARKINGS_BENCHMARK_SEED)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	// Species and mismatched parts decide which markings add_marking may pick, so neither is left to the roll.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	markings_baseline_fill(preferences.body_markings)

	var/actions_driven = 0
	// Read after the preview's first render, so the delta holds only what the drive itself cached.
	counters["limb_icon_cache_before"] = length(human.limb_icon_cache)
	world.Profile(PROFILE_CLEAR)
	world.Profile(PROFILE_START)
	profiling = TRUE
	// The stopwatch has to exist before it can be read, or every reading below comes back null.
	rustg_time_reset(MARKINGS_BENCHMARK_CLOCK)
	var/drive_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)

	// The hot path: every call rebuilds a cache key per limb even when nothing changed.
	var/phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	for(var/pass in 1 to MARKINGS_BENCHMARK_BODY_PASSES)
		human.update_body_parts()
	record("update_body_parts_cached", phase_started, MARKINGS_BENCHMARK_BODY_PASSES)

	// The churn path: only a creating update re-reads DNA, and that is where the per-limb copy happens.
	phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	for(var/pass in 1 to MARKINGS_BENCHMARK_BODY_PASSES)
		human.update_body_parts(update_limb_data = TRUE)
	record("update_body_parts_creating", phase_started, MARKINGS_BENCHMARK_BODY_PASSES)
	yield_unprofiled()

	// A species change, out to the one species with a reduced marking alpha and back again.
	phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	human.set_species(/datum/species/jelly/roundstartslime)
	markings_baseline_fill(human.dna.body_markings)
	human.update_body_parts(update_limb_data = TRUE)
	var/obj/item/bodypart/slime_chest = human.get_bodypart(BODY_ZONE_CHEST)
	counters["slime_markings_alpha"] = slime_chest?.markings_alpha
	human.set_species(/datum/species/human)
	markings_baseline_fill(human.dna.body_markings)
	human.update_body_parts(update_limb_data = TRUE)
	record("species_change", phase_started, 2)
	yield_unprofiled()

	// Husk and back: every marking collapses to one grey and then returns to its own colour.
	phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	human.become_husk(BURN)
	human.update_body_parts(update_limb_data = TRUE)
	human.cure_husk(BURN)
	human.update_body_parts(update_limb_data = TRUE)
	record("husk_cycle", phase_started, 2)
	yield_unprofiled()

	// Dismember and reattach one limb, which is where a detached marking snapshot is made and discarded.
	phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	var/obj/item/bodypart/arm = human.get_bodypart(BODY_ZONE_L_ARM)
	if(arm)
		arm.drop_limb(special = TRUE)
		human.update_body_parts(update_limb_data = TRUE)
		arm.try_attach_limb(human, special = TRUE)
		human.update_body_parts(update_limb_data = TRUE)
		record("dismember_reattach", phase_started, 2)
	else
		notes += "dismember_reattach: the fixture had no left arm to detach."
	yield_unprofiled()

	// A height change rebuilds every limb icon, because height rides in the cache key.
	phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
	human.set_mob_height(HUMAN_HEIGHT_TALL)
	human.update_body_parts(update_limb_data = TRUE)
	record("height_change", phase_started, 1)
	yield_unprofiled()

	counters["limb_icon_cache_after_fixture"] = length(human.limb_icon_cache)

	// The prefs-menu action set, each action of which rebuilds a zone map and, bar the colour change, re-renders the preview.
	if(middleware)
		// The yields above let other code draw from the generator, so the picks are seeded again here.
		rand_seed(MARKINGS_BENCHMARK_SEED)
		phase_started = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK)
		actions_driven = drive_actions(middleware, preferences, mock_client.mob)
		record("middleware_actions", phase_started, actions_driven)
	else
		notes += "middleware_actions: no limbs_and_markings middleware on the test preferences."
	if(!isnull(usr))
		notes += "color_marking: skipped, usr was set and the colour picker would have blocked."

	var/drive_elapsed = rustg_time_microseconds(MARKINGS_BENCHMARK_CLOCK) - drive_started
	world.Profile(PROFILE_STOP)
	profiling = FALSE
	// Read before the tall body below renders, so the delta covers the drive alone.
	counters["limb_icon_cache_after"] = length(human.limb_icon_cache)
	var/profile_text = world.Profile(PROFILE_REFRESH, format = "json")
	// Nothing after this test should find the drive still sitting in the profiler.
	world.Profile(PROFILE_CLEAR)

	// A tall body is the worst case for the overlay count: every marking appearance takes its own filter.
	var/mob/living/carbon/human/tall = build_marked_human()
	tall.set_mob_height(HUMAN_HEIGHT_TALL)
	tall.update_body_parts(update_limb_data = TRUE)
	counters["tall_overlay_shape"] = measure_overlay_shape(tall)
	counters["tall_marking_lists"] = count_marking_lists(tall)
	counters["tall_mob_height"] = tall.mob_height
	counters["actions_driven"] = actions_driven

	var/profile_payload
	if(length(profile_text))
		try
			profile_payload = json_decode(profile_text)
		catch(var/exception/decode_failure)
			// Keep the raw text rather than losing the only profile of the drive.
			profile_payload = profile_text
			notes += "profile: could not be decoded ([decode_failure.name]), stored as raw text."
	else
		notes += "profile: world.Profile returned nothing, check forbid_all_profiling."

	rustg_file_write(json_encode(list(
		"representation" = "nested_list",
		"fixture" = list(
			"marking_names" = markings_baseline_marking_names(),
			"marking_colors" = markings_baseline_marking_colors(),
			"zones" = GLOB.marking_zones,
			"body_passes" = MARKINGS_BENCHMARK_BODY_PASSES,
			"action_rounds" = MARKINGS_BENCHMARK_ACTION_ROUNDS,
			"seed" = MARKINGS_BENCHMARK_SEED,
		),
		"drive_microseconds" = drive_elapsed,
		"timings" = timings,
		"counters" = counters,
		"notes" = notes,
		"profile" = profile_payload,
	)), output_path)

	// Assert after writing, so a failed expectation still leaves the measurements on disk. Only a phase
	// that did not run is a failure; the notes above also carry things that are merely worth knowing.
	var/list/fixture = counters["fixture"]
	TEST_ASSERT_EQUAL(fixture["dna_zones"], length(GLOB.marking_zones), "The fixture must mark every marking zone.")
	TEST_ASSERT_EQUAL(fixture["dna_entries"], length(GLOB.marking_zones) * MAXIMUM_MARKINGS_PER_LIMB, "The fixture must fill every marking slot on every zone.")
	TEST_ASSERT(fixture["limb_entries"] > 0, "The fixture markings must reach the limbs.")
	var/list/tall_shape = counters["tall_overlay_shape"]
	TEST_ASSERT(tall_shape["appearances"] > 0, "A fully-marked tall body must render some appearances to measure.")
	TEST_ASSERT(tall_shape["filters"] > 0, "A tall body must carry height filters, or the filter count measures nothing.")
	TEST_ASSERT(actions_driven > 0, "The middleware action set must actually have been driven.")
	TEST_ASSERT(length(profile_text), "world.Profile returned no data, so the benchmark has no primary evidence.")
	for(var/phase in list("update_body_parts_cached", "update_body_parts_creating", "species_change", "husk_cycle", "dismember_reattach", "height_change", "middleware_actions"))
		TEST_ASSERT(timings[phase], "The [phase] phase did not run, so its cost was never measured.")

#undef MARKINGS_BENCHMARK_BODY_PASSES
#undef MARKINGS_BENCHMARK_ACTION_ROUNDS
#undef MARKINGS_BENCHMARK_CLOCK
#undef MARKINGS_BENCHMARK_SEED
