/// Shared setup for the body marking feature tests: species derived from sets, the species check, exclusion groups, kept-together
/// sets, sorted choices, the version 21 savefile pass and what character setup is sent. Abstract, so it never runs on its own.
/datum/unit_test/body_marking_features
	abstract_type = /datum/unit_test/body_marking_features
	/// marking -> the exclusion group it had before the test gave it one, put back in Destroy().
	var/list/original_groups

/datum/unit_test/body_marking_features/Destroy()
	for(var/datum/body_marking/marking as anything in original_groups)
		marking.exclusion_group = original_groups[marking]
	original_groups = null
	return ..()

/**
 * Puts markings in one exclusion group for the length of the test. No marking ships with a group yet.
 *
 * Arguments:
 * - group: the group token.
 * - markings: the /datum/body_marking singletons to put in it.
 */
/datum/unit_test/body_marking_features/proc/group_markings(group, list/markings)
	for(var/datum/body_marking/marking as anything in markings)
		if(!(marking in original_groups))
			LAZYSET(original_groups, marking, marking.exclusion_group)
		marking.exclusion_group = group

/**
 * Returns character setup's preferences with a preview body, for a species and mismatched parts setting.
 *
 * Arguments:
 * - species_id: the species the character is. Pinned in the cache, as the roundstart config that decides which species
 *   character setup accepts isn't loaded in tests.
 * - mismatched: whether mismatched parts are allowed.
 */
/datum/unit_test/body_marking_features/proc/setup_preferences(species_id, mismatched)
	RETURN_TYPE(/datum/preferences)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.value_cache[/datum/preference/choiced/species] = GLOB.species_list[species_id]
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], mismatched)
	preferences.create_character_preview_view(mock_client.mob)
	return preferences

/// A marking in marking sets may be worn by exactly the species of its sets, a marking in none keeps the species it declares,
/// and so a set's markings allow every species the set does.
/datum/unit_test/body_marking_features/derived_species

/datum/unit_test/body_marking_features/derived_species/Run()
	// The Akula set is for Akula, so its markings are too, where they used to inherit the root type's mammal default.
	var/datum/body_marking/akula = GLOB.body_markings_by_type[/datum/body_marking/akula/secondary]
	TEST_ASSERT(akula.allows_species(SPECIES_AKULA), "The Akula marking must be allowed for Akula, as its set is")
	TEST_ASSERT(!akula.allows_species(SPECIES_MAMMAL), "The Akula marking must follow its set, not the mammal default it declares")
	// Synth Scutes declares any species, but its only set is for synths: the inversion is gone.
	var/datum/body_marking/scutes = GLOB.body_markings_by_type[/datum/body_marking/secondary/synthliz/scutes]
	TEST_ASSERT(scutes.allows_species(SPECIES_SYNTH) && !scutes.allows_species(SPECIES_HUMAN), "Synth Scutes must be for synths only, as its set is")
	// The Xeno markings stay with xenohybrids, whose set they are.
	var/datum/body_marking/xeno = GLOB.body_markings_by_type[/datum/body_marking/secondary/xeno]
	TEST_ASSERT(xeno.allows_species(SPECIES_XENO) && !xeno.allows_species(SPECIES_MAMMAL), "The Xeno marking must be for xenohybrids, as its set is")
	// A marking in no set keeps its declaration: a tattoo is for anyone, a Teshari marking for Teshari.
	var/datum/body_marking/tattoo = GLOB.body_markings_by_type[/datum/body_marking/tattoo/heart]
	TEST_ASSERT_NULL(tattoo.recommended_species, "A marking in no set declared for any species must stay so")
	var/datum/body_marking/teshari = GLOB.body_markings_by_type[/datum/body_marking/secondary/teshari]
	TEST_ASSERT(teshari.allows_species(SPECIES_TESHARI) && !teshari.allows_species(SPECIES_MAMMAL), "A marking in no set must keep the species it declares")

	// Every marking in a set: the union of its sets' species, gathered here the long way, or any species when one set is for any.
	var/list/expected = list()
	var/list/unrestricted = list()
	for(var/set_type, set_datum in GLOB.body_marking_sets_by_type)
		var/datum/body_marking_set/marking_set = set_datum
		for(var/marking_type in marking_set.body_marking_list)
			var/datum/body_marking/marking = GLOB.body_markings_by_type[marking_type]
			if(isnull(marking_set.recommended_species))
				unrestricted[marking] = TRUE
			var/list/species_ids = expected[marking]
			if(!species_ids)
				species_ids = list()
				expected[marking] = species_ids
			for(var/species_id in marking_set.recommended_species)
				species_ids |= species_id
				// A set's markings allow at least its species, so a preset never brings what its wearer couldn't pick.
				TEST_ASSERT(marking.allows_species(species_id), "[marking.name] must be allowed for [species_id], as its set [marking_set.name] is")
	TEST_ASSERT(length(expected), "The fixture needs markings in sets")
	for(var/datum/body_marking/marking as anything in expected)
		if(unrestricted[marking])
			TEST_ASSERT_NULL(marking.recommended_species, "[marking.name] is in a set for any species, so it must be too")
			continue
		TEST_ASSERT_EQUAL(json_encode(sort_list(assoc_to_keys(marking.recommended_species))), json_encode(sort_list(expected[marking])), "[marking.name] must be allowed for exactly the species of its sets")
	// Interned: markings of the same sets hold one list.
	var/datum/body_marking/fox = GLOB.body_markings_by_type[/datum/body_marking/secondary/fox]
	var/datum/body_marking/fox_sock = GLOB.body_markings_by_type[/datum/body_marking/tertiary/fox]
	TEST_ASSERT(fox.recommended_species && fox.recommended_species == fox_sock.recommended_species, "Markings of the same sets must share one species list")

/// Changing species in character setup removes the markings the new species may not wear unless mismatched parts allow any,
/// and every zone stays. Loading a character never removes one.
/datum/unit_test/body_marking_features/species_change

/datum/unit_test/body_marking_features/species_change/Run()
	var/datum/preferences/preferences = setup_preferences(SPECIES_AKULA, FALSE)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	// An Akula wearing its own marking, one of the mammal sets and a tattoo meant for anyone.
	var/list/saved = list(
		BODY_ZONE_CHEST = list("Akula" = list("#112233", 0), "Bovine" = list("#445566", 1), "Tattoo - Heart" = list("#112222", 0)),
		BODY_ZONE_HEAD = list("Akula" = list("#112233", 0)),
	)
	var/saved_text = json_encode(saved)
	preferences.body_markings = body_marking_collection_from_list(saved)
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved_text, "The fixture must load whole")
	TEST_ASSERT_NULL(preferences.body_markings.validate_for_species(SPECIES_AKULA, FALSE), "An Akula may wear all of it")
	var/list/disallowed = preferences.body_markings.validate_for_species(SPECIES_HUMAN, FALSE)
	TEST_ASSERT_EQUAL(length(disallowed), 3, "A human may wear only the tattoo")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved_text, "Asking must remove nothing")
	TEST_ASSERT_NULL(preferences.body_markings.validate_for_species(SPECIES_HUMAN, TRUE), "Mismatched parts allow everything")

	// Another setting changing touches nothing.
	middleware.post_set_preference(null, "feature_mcolor", "#123456")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved_text, "Only a species change may remove markings")
	// To a human without mismatched parts: only the tattoo stays, and both zones do.
	preferences.value_cache[/datum/preference/choiced/species] = GLOB.species_list[SPECIES_HUMAN]
	middleware.post_set_preference(null, "species", SPECIES_HUMAN)
	var/list/pruned = list(
		BODY_ZONE_CHEST = list("Tattoo - Heart" = list("#112222", 0)),
		BODY_ZONE_HEAD = list(),
	)
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), json_encode(pruned), "A new species must lose the markings it may not wear and keep its zones")
	// With mismatched parts, a species change keeps everything.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	preferences.body_markings = body_marking_collection_from_list(saved)
	middleware.post_set_preference(null, "species", SPECIES_HUMAN)
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved_text, "With mismatched parts a species change must keep every marking")

	// A human's saved Akula markings load and save whole.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], FALSE)
	var/list/slot = list("version" = 52, "modular_version" = 21, "tgui_prefs_migration" = TRUE, "species" = SPECIES_HUMAN, "body_markings" = json_decode(saved_text))
	preferences.savefile.set_entry("character[preferences.default_slot]", slot)
	preferences.value_cache = list()
	TEST_ASSERT(preferences.load_character(preferences.default_slot), "The fixture character must load")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved_text, "Loading must keep markings the species may not pick")

/// Without mismatched parts character setup refuses a marking or preset meant for other species wherever one is named: adding a
/// marking by name, renaming a row and picking a preset. Mismatched parts allow all three.
/datum/unit_test/body_marking_features/species_actions

/datum/unit_test/body_marking_features/species_actions/Run()
	var/datum/preferences/preferences = setup_preferences(SPECIES_HUMAN, FALSE)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/user = preferences.parent.mob
	var/datum/body_marking/foreign = GLOB.body_markings_by_type[/datum/body_marking/akula/secondary]
	var/datum/body_marking/shared = GLOB.body_markings_by_type[/datum/body_marking/tattoo/heart]
	TEST_ASSERT(!foreign.allows_species(SPECIES_HUMAN) && shared.allows_species(SPECIES_HUMAN), "The fixture needs a left arm marking a human may not wear and one anyone may")
	// Adding by name.
	preferences.body_markings = new /datum/body_marking_collection
	TEST_ASSERT(!middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = foreign.name), user), "Adding another species' marking by name must be refused")
	TEST_ASSERT(!preferences.body_markings.entry_count(), "A refused marking must not be added")
	TEST_ASSERT(middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = shared.name), user), "Adding a marking meant for anyone by name must work")
	TEST_ASSERT(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, shared.name), "The named marking must be the one added")
	TEST_ASSERT(!middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = shared.name), user), "Adding a marking the zone wears must be refused")
	TEST_ASSERT(!middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = "Not A Marking"), user), "Adding a name no marking has must be refused")
	TEST_ASSERT(!middleware.add_marking(list("bodypart_slot" = "tail", "marking_name" = shared.name), user), "Adding to a zone markings don't go on must be refused")
	TEST_ASSERT_EQUAL(preferences.body_markings.entry_count(), 1, "Refused additions must add nothing")
	// Renaming a row.
	TEST_ASSERT(!middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "marking_name" = foreign.name), user), "Renaming a row to another species' marking must be refused")
	TEST_ASSERT(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, shared.name) && !preferences.body_markings.find_entry(BODY_ZONE_L_ARM, foreign.name), "A refused rename must leave the row as it was")
	// A preset.
	var/datum/body_marking_set/akula_set = GLOB.body_marking_sets_by_type[/datum/body_marking_set/akula/akula]
	var/before = json_encode(preferences.body_markings.serialize())
	TEST_ASSERT(!middleware.set_preset(list("preset" = akula_set.name), user), "A preset meant for other species must be refused")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), before, "A refused preset must change nothing")
	// Mismatched parts allow all three.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	TEST_ASSERT(middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "marking_name" = foreign.name), user), "With mismatched parts a row may take another species' marking")
	TEST_ASSERT(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, foreign.name), "The row must wear the new marking")
	TEST_ASSERT(middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = shared.name), user), "With mismatched parts any marking may be added by name")
	TEST_ASSERT(middleware.set_preset(list("preset" = akula_set.name), user), "With mismatched parts any preset applies")
	TEST_ASSERT(preferences.body_markings.find_entry(BODY_ZONE_CHEST, foreign.name), "The preset must put on its markings")

/// Two markings of one exclusion group never share a zone through an edit: add_entry refuses the second, a rename into the group
/// is refused, a zone set from a list keeps the first, the set factory keeps the first, and character setup neither offers
/// nor accepts the second. A save, or a zone taken whole from another collection, keeps both.
/datum/unit_test/body_marking_features/exclusion_groups
	/// The left arm's real marking choices, restored after the test narrows them.
	var/list/original_choices

/datum/unit_test/body_marking_features/exclusion_groups/Destroy()
	if(original_choices)
		GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	return ..()

/datum/unit_test/body_marking_features/exclusion_groups/Run()
	var/datum/body_marking/bovine = GLOB.body_markings_by_type[/datum/body_marking/secondary/bovine]
	var/datum/body_marking/bovine_spot = GLOB.body_markings_by_type[/datum/body_marking/tertiary/bovine]
	var/datum/body_marking/dalmatian = GLOB.body_markings_by_type[/datum/body_marking/secondary/dalmatian]
	var/datum/body_marking/guilmon = GLOB.body_markings_by_type[/datum/body_marking/tertiary/guilmon]
	group_markings("test_coat", list(bovine, bovine_spot, dalmatian))

	// add_entry
	var/datum/body_marking_collection/markings = new
	TEST_ASSERT(markings.add_entry(new /datum/body_marking_entry(bovine, BODY_ZONE_HEAD, "#111111")), "The first marking of a group must go on")
	TEST_ASSERT(!markings.add_entry(new /datum/body_marking_entry(dalmatian, BODY_ZONE_HEAD, "#222222")), "A second marking of the group must be refused on the same zone")
	TEST_ASSERT(markings.add_entry(new /datum/body_marking_entry(dalmatian, BODY_ZONE_CHEST, "#222222")), "Another zone may wear another marking of the group")
	TEST_ASSERT(markings.add_entry(new /datum/body_marking_entry(guilmon, BODY_ZONE_HEAD, "#333333")), "A marking of no group goes on beside one of a group")
	// replace_entry: a row may become another marking of its own group, but not of a group another row wears.
	TEST_ASSERT(!markings.replace_entry(markings.find_entry(BODY_ZONE_HEAD, guilmon.name), new /datum/body_marking_entry(dalmatian, BODY_ZONE_HEAD, "#444444")), "A row renamed into a group another row wears must be refused")
	TEST_ASSERT(markings.replace_entry(markings.find_entry(BODY_ZONE_HEAD, bovine.name), new /datum/body_marking_entry(dalmatian, BODY_ZONE_HEAD, "#444444")), "A row may become another marking of its own group")
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_HEAD)), json_encode(list(dalmatian.name, guilmon.name)), "The renamed row must keep its place")
	// set_zone_entries keeps the first of a group, unless told to keep a group's markings side by side.
	markings.set_zone_entries(BODY_ZONE_L_ARM, list(new /datum/body_marking_entry(bovine, BODY_ZONE_L_ARM, "#111111"), new /datum/body_marking_entry(guilmon, BODY_ZONE_L_ARM, "#333333"), new /datum/body_marking_entry(dalmatian, BODY_ZONE_L_ARM, "#222222")))
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(bovine.name, guilmon.name)), "Setting a zone must keep only the first marking of a group")
	markings.set_zone_entries(BODY_ZONE_L_ARM, list(new /datum/body_marking_entry(bovine, BODY_ZONE_L_ARM, "#111111"), new /datum/body_marking_entry(dalmatian, BODY_ZONE_L_ARM, "#222222")), keep_group_conflicts = TRUE)
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(bovine.name, dalmatian.name)), "A zone set as held must keep a group's markings side by side")
	// A save keeps what it holds, and so does a zone taken whole.
	var/list/saved = list(BODY_ZONE_CHEST = list("[bovine.name]" = list("#111111", 0), "[dalmatian.name]" = list("#222222", 1)))
	var/datum/body_marking_collection/loaded = body_marking_collection_from_list(saved)
	TEST_ASSERT_EQUAL(json_encode(loaded.serialize()), json_encode(saved), "A save holding two markings of a group must load both")
	var/datum/body_marking_collection/overwritten = new
	overwritten.overwrite_zones_from(loaded)
	TEST_ASSERT_EQUAL(json_encode(overwritten.serialize()), json_encode(saved), "A zone taken whole must keep both")
	// The set factory: the Bovine set puts on Bovine, then Bovine Spot, which its group now keeps off every zone Bovine took.
	var/datum/body_marking_set/bovine_set = GLOB.body_marking_sets_by_type[/datum/body_marking_set/bovine]
	var/datum/body_marking_collection/worn = assemble_body_markings_from_set(bovine_set, null, null)
	TEST_ASSERT_EQUAL(worn.zone_count(), length(GLOB.marking_zones), "The fixture set must cover every zone")
	for(var/zone in GLOB.marking_zones)
		TEST_ASSERT_EQUAL(json_encode(worn.marking_names(zone)), json_encode(list(bovine.name)), "The set factory must keep only the first marking of a group on [zone]")

	// Character setup.
	var/datum/preferences/preferences = setup_preferences(SPECIES_MAMMAL, TRUE)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/user = preferences.parent.mob
	preferences.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[bovine.name]" = list("#111111", 0), "[guilmon.name]" = list("#333333", 0))))
	TEST_ASSERT(!middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_2", "marking_name" = dalmatian.name), user), "Renaming a row into a group another row wears must be refused")
	TEST_ASSERT(!middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_name" = dalmatian.name), user), "Adding a marking of a group the zone wears must be refused")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(bovine.name, guilmon.name)), "Refused edits must leave the zone as it was")
	// A random addition never lands on the group: narrowed to it and one free marking, the zone can take only the free one.
	var/list/choices = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]
	var/free
	for(var/name in choices)
		if(!(name in list(bovine.name, guilmon.name, dalmatian.name)))
			free = name
			break
	TEST_ASSERT(free, "The fixture needs a left arm marking outside the group")
	original_choices = choices
	GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = list(dalmatian.name, free)
	var/list/drawn = list()
	for(var/attempt in 1 to 5)
		preferences.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[bovine.name]" = list("#111111", 0))))
		middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM), user)
		drawn |= json_encode(preferences.body_markings.marking_names(BODY_ZONE_L_ARM))
	GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	original_choices = null
	TEST_ASSERT_EQUAL(json_encode(drawn), json_encode(list(json_encode(list(bovine.name, free)))), "A random addition must never pick a marking of a group the zone wears")
	// Character setup is told each marking's group.
	var/list/marking_info = middleware.build_marking_info()
	for(var/datum/body_marking/grouped as anything in list(bovine, bovine_spot, dalmatian))
		TEST_ASSERT_EQUAL(marking_info[grouped.name]["exclusion_group"], "test_coat", "[grouped.name] must be sent with its group")
	TEST_ASSERT_NULL(marking_info[guilmon.name]["exclusion_group"], "[guilmon.name] is in no group, so it must be sent with none")

/// A set kept together replaces every marking when picked; any other set replaces only the zones it covers.
/datum/unit_test/body_marking_features/keep_together
	/// The set given keep_together for the test.
	var/datum/body_marking_set/kept_set
	/// Its own keep_together, put back in Destroy().
	var/original_keep_together

/datum/unit_test/body_marking_features/keep_together/Destroy()
	if(kept_set)
		kept_set.keep_together = original_keep_together
	kept_set = null
	return ..()

/datum/unit_test/body_marking_features/keep_together/Run()
	var/datum/preferences/preferences = setup_preferences(SPECIES_MAMMAL, FALSE)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/user = preferences.parent.mob
	// The Tajaran set covers the head and chest, so the left arm is a zone it leaves bare.
	var/datum/body_marking_set/tajaran_set = GLOB.body_marking_sets_by_type[/datum/body_marking_set/tajaran]
	var/datum/body_marking/tajaran = GLOB.body_markings_by_type[/datum/body_marking/secondary/tajaran]
	var/list/saved = list(BODY_ZONE_L_ARM = list("Bovine" = list("#112233", 0)), BODY_ZONE_HEAD = list("Dalmatian" = list("#445566", 0)))
	// Merged, the default.
	TEST_ASSERT(!tajaran_set.keep_together, "No set ships kept together")
	preferences.body_markings = body_marking_collection_from_list(saved)
	TEST_ASSERT(middleware.set_preset(list("preset" = tajaran_set.name), user), "The Tajaran preset must apply")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list("Bovine")), "A merged set must leave a zone it doesn't cover alone")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.marking_names(BODY_ZONE_HEAD)), json_encode(list(tajaran.name)), "A merged set must replace a zone it covers")
	// Kept together.
	kept_set = tajaran_set
	original_keep_together = kept_set.keep_together
	kept_set.keep_together = TRUE
	preferences.body_markings = body_marking_collection_from_list(saved)
	TEST_ASSERT(middleware.set_preset(list("preset" = tajaran_set.name), user), "The kept-together preset must apply")
	TEST_ASSERT(!preferences.body_markings.has_zone(BODY_ZONE_L_ARM), "A set kept together must replace every marking, on zones it leaves bare too")
	var/list/expected = assemble_body_markings_from_set(tajaran_set, middleware.marking_seed_features(), middleware.edited_species()).serialize()
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), json_encode(expected), "A set kept together must leave exactly what it puts on")
	var/sent_flag
	for(var/list/preset as anything in middleware.build_marking_presets())
		if(preset["name"] == tajaran_set.name)
			sent_flag = preset["keep_together"]
	TEST_ASSERT(sent_flag, "Character setup must be told the preset is kept together")

/// Each zone offers its markings in name order, and the zones keep the order markings first claimed them in, which the set
/// factory reads (its parity is body_marking_colors/set_factory).
/datum/unit_test/body_marking_features/sorted_choices

/datum/unit_test/body_marking_features/sorted_choices/Run()
	var/list/claimed = list()
	for(var/datum/body_marking/marking_type as anything in subtypesof(/datum/body_marking))
		if(!initial(marking_type.name))
			continue
		for(var/zone in GLOB.marking_zones)
			if(initial(marking_type.affected_bodyparts) & GLOB.marking_zone_to_bitflag[zone])
				claimed |= zone
	TEST_ASSERT_EQUAL(json_encode(assoc_to_keys(GLOB.body_markings_per_limb)), json_encode(claimed), "The zones must keep the order markings first claimed them in")
	for(var/zone, names in GLOB.body_markings_per_limb)
		var/list/zone_names = names
		TEST_ASSERT(length(zone_names), "[zone] must offer markings")
		TEST_ASSERT_EQUAL(json_encode(zone_names), json_encode(sort_list(zone_names)), "[zone]'s markings must be in name order")

/**
 * Loads a character slot holding a savefile tree the way a connection does, then saves it. Returns what was written.
 *
 * Arguments:
 * - preferences: the preferences to load into.
 * - slot: the character's savefile tree. It is stored as given and rewritten by the save.
 */
/datum/unit_test/body_marking_features/proc/load_and_save(datum/preferences/preferences, list/slot)
	RETURN_TYPE(/list)
	preferences.savefile.set_entry("character[preferences.default_slot]", slot)
	preferences.value_cache = list()
	if(!preferences.load_character(preferences.default_slot))
		return null
	preferences.save_character()
	return preferences.savefile.get_entry("character[preferences.default_slot]")

/// A save from before version 21 gets one pass on load: a second marking of an exclusion group and anything past the per-zone
/// cap go, groups first. Saved again, it writes back byte for byte. A save within the limits, or written since, is untouched.
/datum/unit_test/body_marking_features/migration

/datum/unit_test/body_marking_features/migration/Run()
	var/datum/body_marking/tiger_spot = GLOB.body_markings_by_type[/datum/body_marking/secondary/tiger]
	var/datum/body_marking/tiger_stripe = GLOB.body_markings_by_type[/datum/body_marking/tertiary/tiger]
	group_markings("test_stripes", list(tiger_spot, tiger_stripe))
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	// Over the cap on the left arm; a group's two markings on the chest; both on the head, where the group is resolved
	// first and so leaves the head within the cap.
	var/over = "{\"l_arm\":{\"Bovine\":\[\"#111111\",0],\"Dalmatian\":\[\"#222222\",1],\"Guilmon Mark\":\[\"#333333\",0],\"Tiger Stripe\":\[\"#444444\",0]},\"chest\":{\"Tiger Spot\":\[\"#555555\",0],\"Tiger Stripe\":\[\"#666666\",1],\"Bovine\":\[\"#777777\",0]},\"head\":{\"Tiger Spot\":\[\"#888888\",0],\"Tiger Stripe\":\[\"#999999\",0],\"Bovine\":\[\"#aaaaaa\",0],\"Dalmatian\":\[\"#bbbbbb\",0]}}"
	var/fixed = "{\"l_arm\":{\"Bovine\":\[\"#111111\",0],\"Dalmatian\":\[\"#222222\",1],\"Guilmon Mark\":\[\"#333333\",0]},\"chest\":{\"Tiger Spot\":\[\"#555555\",0],\"Bovine\":\[\"#777777\",0]},\"head\":{\"Tiger Spot\":\[\"#888888\",0],\"Bovine\":\[\"#aaaaaa\",0],\"Dalmatian\":\[\"#bbbbbb\",0]}}"
	var/full = body_marking_compat_full()
	// saved markings -> version -> what the first save must write
	var/list/cases = list(
		list(over, 20, fixed),
		list(full, 20, full),
		list(over, 21, over),
	)
	for(var/list/fixture as anything in cases)
		var/list/written = load_and_save(preferences, list("version" = 52, "modular_version" = fixture[2], "tgui_prefs_migration" = TRUE, "body_markings" = json_decode(fixture[1])))
		TEST_ASSERT(written, "A version [fixture[2]] character must load")
		TEST_ASSERT_EQUAL(json_encode(written["body_markings"]), fixture[3], "A version [fixture[2]] save of [fixture[1]] must write back as expected")
		TEST_ASSERT(written["modular_version"] > 20, "A saved character must be at a version that has had the pass")
		var/first = json_encode(written)
		written = load_and_save(preferences, written)
		TEST_ASSERT_EQUAL(json_encode(written), first, "A second load and save of [fixture[1]] must change nothing")

/// A save from before version 8 has the old skrell hair names renamed as it loads, read from the choice the save holds; the
/// mutant_bodyparts tree such a save also carries is not read.
/datum/unit_test/skrell_hair_name_migration

/datum/unit_test/skrell_hair_name_migration/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	for(var/old_name, new_name in list("Male" = "Short", "Female" = "Long", "Reef" = "Reef"))
		var/list/slot = list(
			"version" = 52,
			"modular_version" = 7,
			"tgui_prefs_migration" = TRUE,
			"feature_skrell_hair" = old_name,
			"mutant_bodyparts" = list(FEATURE_SKRELL_HAIR = list("name" = old_name)),
		)
		preferences.savefile.set_entry("character[preferences.default_slot]", slot)
		preferences.value_cache = list()
		TEST_ASSERT(preferences.load_character(preferences.default_slot), "A version 7 character must load")
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/mutant_choice/skrell_hair), new_name, "Skrell hair saved as [old_name] must load as [new_name]")

/// Character setup's constant data names each zone's choices, unfiltered and in the zone's order, and describes every marking
/// once, by name: its exclusion group, colour mode, whether its chest art is gendered, the leg shapes it has art for and the
/// species it is meant for, with suggested colours only where a marking has some. Each preset carries its markings and whether
/// it is kept together.
/datum/unit_test/body_marking_features/payload
	/// The marking given a palette for the test.
	var/datum/body_marking/palette_marking
	/// Its own palette, put back in Destroy().
	var/list/original_palette

/datum/unit_test/body_marking_features/payload/Destroy()
	if(palette_marking)
		palette_marking.recommended_colors = original_palette
	palette_marking = null
	return ..()

/datum/unit_test/body_marking_features/payload/Run()
	var/datum/preferences/preferences = setup_preferences(SPECIES_MAMMAL, FALSE)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	palette_marking = GLOB.body_markings_by_type[/datum/body_marking/secondary/bovine]
	original_palette = palette_marking.recommended_colors
	var/list/palette = list("#aa0000", "#00aa00")
	palette_marking.recommended_colors = palette
	var/list/data = middleware.get_constant_data()
	var/list/marking_info = data["marking_info"]
	// A zone names its choices, and every name it offers is described.
	TEST_ASSERT(length(data["marking_choices"]), "The payload must offer markings")
	TEST_ASSERT_EQUAL(json_encode(data["marking_choices"]), json_encode(GLOB.body_markings_per_limb), "Each zone must offer its markings by name, in its own order")
	for(var/zone, zone_names in data["marking_choices"])
		for(var/name in zone_names)
			TEST_ASSERT(marking_info[name], "[zone] offers [name], which isn't described")
	// Every marking is described once, one a save holds on a zone that no longer offers it included.
	TEST_ASSERT_EQUAL(length(marking_info), length(GLOB.body_markings), "Every marking must be described once")
	for(var/name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/marking = marking_datum
		var/list/info = marking_info[name]
		TEST_ASSERT(info, "[name] must be described")
		TEST_ASSERT(("exclusion_group" in info) && info["exclusion_group"] == marking.exclusion_group, "[name] must be sent with its exclusion group")
		TEST_ASSERT_EQUAL(info["color_mode"], marking.color_mode, "[name] must be sent with its colour mode")
		TEST_ASSERT_EQUAL(info["gendered"], marking.gendered, "[name] must be sent with whether it is gendered")
		TEST_ASSERT_EQUAL(info["leg_shapes"], marking.leg_shapes, "[name] must be sent with the leg shapes it has art for")
		var/list/species_ids = marking.recommended_species ? sort_list(assoc_to_keys(marking.recommended_species)) : null
		var/list/sent_ids = info["recommended_species"] ? sort_list(splittext(info["recommended_species"], ",")) : null
		TEST_ASSERT_EQUAL(json_encode(sent_ids), json_encode(species_ids), "[name] must be sent with the species it is meant for")
		if(marking == palette_marking)
			TEST_ASSERT_EQUAL(json_encode(info["recommended_colors"]), json_encode(palette), "[name] must be sent with its suggested colours")
		else
			TEST_ASSERT(!("recommended_colors" in info), "[name] has no suggested colours, so none may be sent")
	var/list/presets = data["marking_presets"]
	TEST_ASSERT_EQUAL(length(presets), length(GLOB.body_marking_sets), "Every set must be offered as a preset")
	for(var/list/preset as anything in presets)
		var/datum/body_marking_set/marking_set = GLOB.body_marking_sets[preset["name"]]
		TEST_ASSERT(marking_set, "A preset must name a set")
		var/list/names
		for(var/marking_type in marking_set.body_marking_list)
			var/datum/body_marking/marking = GLOB.body_markings_by_type[marking_type]
			LAZYADD(names, marking.name)
		TEST_ASSERT_EQUAL(json_encode(preset["markings"]), json_encode(names), "The [marking_set.name] preset must be sent with its markings in order")
		TEST_ASSERT(("keep_together" in preset) && preset["keep_together"] == marking_set.keep_together, "The [marking_set.name] preset must be sent with whether it is kept together")

/// Suggested colours a marking declares become one shared list per palette, and every palette shipped is lowercase #rrggbb.
/datum/unit_test/body_marking_features/recommended_colors

/// A nameless marking type declaring a palette, so no list of markings holds it.
/datum/body_marking/recommended_colors_test
	recommended_colors = list("#a1b2c3", "#0a1b2c")

/// Another declaring the same palette.
/datum/body_marking/recommended_colors_test/same_palette

/datum/unit_test/body_marking_features/recommended_colors/Run()
	var/datum/body_marking/first = allocate(/datum/body_marking/recommended_colors_test)
	var/datum/body_marking/second = allocate(/datum/body_marking/recommended_colors_test/same_palette)
	TEST_ASSERT_EQUAL(json_encode(first.recommended_colors), json_encode(list("#a1b2c3", "#0a1b2c")), "A marking must keep the palette it declares")
	TEST_ASSERT(first.recommended_colors == second.recommended_colors, "Markings declaring one palette must share one list")
	var/datum/body_marking/plain = allocate(/datum/body_marking)
	TEST_ASSERT_NULL(plain.recommended_colors, "A marking declaring no palette must suggest none")
	for(var/name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/marking = marking_datum
		for(var/color in marking.recommended_colors)
			TEST_ASSERT(istext(color) && sanitize_hexcolor(color) == color, "[name] must suggest lowercase #rrggbb colours, not [color]")
