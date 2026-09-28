/// Shared setup for the body marking colour mode tests. Abstract, so the runner never runs it on its own.
/datum/unit_test/body_marking_colors
	abstract_type = /datum/unit_test/body_marking_colors

/**
 * Returns the first marking a zone offers with a colour mode, in the zone's list order.
 *
 * Arguments:
 * - color_mode: one of the MARKING_COLOR_* defines.
 * - zone: the zone the marking must be wearable on.
 */
/datum/unit_test/body_marking_colors/proc/marking_with_mode(color_mode, zone = BODY_ZONE_L_ARM)
	RETURN_TYPE(/datum/body_marking)
	for(var/name in GLOB.body_markings_per_limb[zone])
		var/datum/body_marking/marking = GLOB.body_markings[name]
		if(marking.color_mode == color_mode)
			return marking
	return null

/// Three mutant colours, lowercase so a stored colour compares equal, none of them any marking's own colour.
/datum/unit_test/body_marking_colors/proc/seed_features()
	return list(
		FEATURE_MUTANT_COLOR = "#a1b2c3",
		FEATURE_MUTANT_COLOR_TWO = "#d4e5f6",
		FEATURE_MUTANT_COLOR_THREE = "#0a1b2c",
	)

/// A marking's colour mode decides where a newly worn one takes its colour from: one of the mutant colours, or its own.
/datum/unit_test/body_marking_colors/seed_modes

/datum/unit_test/body_marking_colors/seed_modes/Run()
	var/list/features = seed_features()
	var/datum/body_marking/marking = allocate(/datum/body_marking)
	marking.default_color = "#123456"
	var/list/expected = list(
		MARKING_COLOR_FOLLOWS_PRIMARY = features[FEATURE_MUTANT_COLOR],
		MARKING_COLOR_FOLLOWS_SECONDARY = features[FEATURE_MUTANT_COLOR_TWO],
		MARKING_COLOR_FOLLOWS_TERTIARY = features[FEATURE_MUTANT_COLOR_THREE],
		MARKING_COLOR_FIXED_DEFAULT = "#123456",
		MARKING_COLOR_LOCKED = "#123456",
	)
	for(var/mode, color in expected)
		marking.color_mode = mode
		TEST_ASSERT_EQUAL(marking.seed_color(features, null), color, "A [mode] marking must start in [color]")
	// Without features, as for an editor with no body, a following marking has nothing to follow and a fixed one still has its colour.
	marking.color_mode = MARKING_COLOR_FOLLOWS_PRIMARY
	TEST_ASSERT_NULL(marking.seed_color(null, null), "A following marking must seed nothing without features")
	marking.color_mode = MARKING_COLOR_FIXED_DEFAULT
	TEST_ASSERT_EQUAL(marking.seed_color(null, null), "#123456", "A fixed marking must seed its own colour without features")

	// Every marking in the game, wherever it is declared, has a mode seed_color() knows; every fixed or locked one a colour of
	// its own to seed, and no following one a colour nothing would read.
	var/list/modes = list(MARKING_COLOR_FOLLOWS_PRIMARY, MARKING_COLOR_FOLLOWS_SECONDARY, MARKING_COLOR_FOLLOWS_TERTIARY, MARKING_COLOR_FIXED_DEFAULT, MARKING_COLOR_LOCKED)
	for(var/name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/worn = marking_datum
		TEST_ASSERT(worn.color_mode in modes, "[name] has a colour mode seed_color() doesn't know: [worn.color_mode]")
		if(worn.color_mode == MARKING_COLOR_FIXED_DEFAULT || worn.color_mode == MARKING_COLOR_LOCKED)
			TEST_ASSERT(istext(worn.default_color) && sanitize_hexcolor(worn.default_color) == LOWER_TEXT(worn.default_color), "[name] must carry a #rrggbb colour of its own, not [worn.default_color]")
		else
			TEST_ASSERT_NULL(worn.default_color, "[name] follows a mutant colour, so the colour it declares would never be read")

/// A locked marking keeps its colour: its entry refuses a recolour, and neither character setup's colour action, a rename
/// in setup nor the fur dyer can give it another. A colour a save already holds is kept.
/datum/unit_test/body_marking_colors/locked
	/// The left arm's real marking choices, restored after the test narrows them.
	var/list/original_choices

/datum/unit_test/body_marking_colors/locked/Destroy()
	if(original_choices)
		GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	return ..()

/datum/unit_test/body_marking_colors/locked/Run()
	var/datum/body_marking/ink = marking_with_mode(MARKING_COLOR_LOCKED)
	var/datum/body_marking/paint = marking_with_mode(MARKING_COLOR_FOLLOWS_PRIMARY)
	TEST_ASSERT(ink && paint, "The fixture needs a locked and a following left arm marking")
	var/ink_color = LOWER_TEXT(ink.default_color)

	// The entry: a saved custom colour loads and stays, and a recolour is refused without invalidating any icon key.
	var/datum/body_marking_entry/tattoo = new(ink, BODY_ZONE_L_ARM, "#abcdef")
	TEST_ASSERT_EQUAL(tattoo.get_color(), "#abcdef", "A locked marking must load the colour its save holds")
	var/revision = GLOB.body_marking_entry_revision
	TEST_ASSERT(!tattoo.set_color("#123456"), "Recolouring a locked marking must be refused")
	TEST_ASSERT_EQUAL(tattoo.get_color(), "#abcdef", "A refused recolour must keep the colour")
	TEST_ASSERT_EQUAL(GLOB.body_marking_entry_revision, revision, "A refused recolour must not invalidate any icon key")
	var/datum/body_marking_entry/painted = new(paint, BODY_ZONE_L_ARM, "#abcdef")
	TEST_ASSERT(painted.set_color("#123456"), "Recolouring an unlocked marking must work")
	TEST_ASSERT_EQUAL(painted.get_color(), "#123456", "A recoloured marking must take the new colour")

	// Character setup.
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware, "The fixture needs the limbs and markings middleware")
	preferences.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[paint.name]" = list("#abcdef", 0), "[ink.name]" = list("#abcdef", 0))))
	// Without a user the colour picker returns nothing, so an unlocked row's action ends having changed nothing; a locked row's
	// never opens it.
	TEST_ASSERT(middleware.color_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1"), mock_client.mob), "An unlocked row's colour action must run")
	TEST_ASSERT(!middleware.color_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_2"), mock_client.mob), "A locked row's colour action must return without doing anything")
	TEST_ASSERT_EQUAL(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, ink.name).get_color(), "#abcdef", "A locked row must keep its colour")
	// A rename to a locked marking takes that marking's own colour, not the replaced row's; a rename away keeps the colour.
	preferences.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[paint.name]" = list("#abcdef", 1))))
	TEST_ASSERT(middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "marking_name" = ink.name), mock_client.mob), "Renaming a row to a locked marking must work")
	var/datum/body_marking_entry/renamed = preferences.body_markings.find_entry(BODY_ZONE_L_ARM, ink.name)
	TEST_ASSERT_EQUAL(renamed?.get_color(), ink_color, "A row renamed to a locked marking must wear that marking's own colour")
	TEST_ASSERT(renamed?.get_emissive(), "A renamed row must keep its glow")
	middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "marking_name" = paint.name), mock_client.mob)
	TEST_ASSERT_EQUAL(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, paint.name)?.get_color(), ink_color, "A row renamed away from a locked marking must keep its colour")
	// Adding a locked marking seeds its own colour.
	original_choices = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]
	GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = list(ink.name)
	preferences.body_markings = new /datum/body_marking_collection
	TEST_ASSERT(middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM), mock_client.mob), "Adding the locked marking must work")
	TEST_ASSERT_EQUAL(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, ink.name)?.get_color(), ink_color, "An added locked marking must wear its own colour")

	// The fur dyer: the painting finishes, the ink stays.
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[ink.name]" = list("#abcdef", 0))))
	var/obj/item/fur_dyer/dyer = allocate(/obj/item/fur_dyer)
	TEST_ASSERT(!dyer.finish_marking_dye(body, BODY_ZONE_L_ARM, ink.name, "#123456"), "The fur dyer must not paint a locked marking")
	TEST_ASSERT_EQUAL(body.dna.body_markings.find_entry(BODY_ZONE_L_ARM, ink.name).get_color(), "#abcdef", "A locked marking the dyer painted must keep its colour")

/// Reseeding gives an entry the colour its marking starts with again, and a whole-body colour reset (the slime's) reseeds
/// every marking but the locked ones, whose colour, a saved custom one included, stays.
/datum/unit_test/body_marking_colors/reseed

/datum/unit_test/body_marking_colors/reseed/Run()
	var/list/features = seed_features()
	var/datum/body_marking/ink = marking_with_mode(MARKING_COLOR_LOCKED)
	var/datum/body_marking/primary = marking_with_mode(MARKING_COLOR_FOLLOWS_PRIMARY)
	var/datum/body_marking/fixed = marking_with_mode(MARKING_COLOR_FIXED_DEFAULT, BODY_ZONE_HEAD)
	TEST_ASSERT(ink && primary && fixed, "The fixture needs a locked, a following and a fixed marking")
	var/datum/body_marking_entry/followed = new(primary, BODY_ZONE_L_ARM, "#010101")
	var/revision = GLOB.body_marking_entry_revision
	followed.reseed_color(features, null)
	TEST_ASSERT_EQUAL(followed.get_color(), features[FEATURE_MUTANT_COLOR], "A following marking must reseed from the mutant colour it follows")
	TEST_ASSERT(GLOB.body_marking_entry_revision != revision, "A reseeded colour must invalidate the icon keys that hold the old one")
	var/datum/body_marking_entry/tattoo = new(ink, BODY_ZONE_L_ARM, "#010101")
	tattoo.reseed_color(features, null)
	TEST_ASSERT_EQUAL(tattoo.get_color(), LOWER_TEXT(ink.default_color), "Reseeding one locked marking must give it its own colour back")

	var/datum/body_marking_collection/markings = body_marking_collection_from_list(list(
		BODY_ZONE_L_ARM = list("[primary.name]" = list("#010101", 1), "[ink.name]" = list("#020202", 0)),
		BODY_ZONE_HEAD = list("[fixed.name]" = list("#030303", 0)),
	))
	markings.reseed_colors(features, null)
	TEST_ASSERT_EQUAL(markings.find_entry(BODY_ZONE_L_ARM, primary.name).get_color(), features[FEATURE_MUTANT_COLOR], "A colour reset must give a following marking the mutant colour it follows")
	TEST_ASSERT(markings.find_entry(BODY_ZONE_L_ARM, primary.name).get_emissive(), "A colour reset must keep glow")
	TEST_ASSERT_EQUAL(markings.find_entry(BODY_ZONE_HEAD, fixed.name).get_color(), LOWER_TEXT(fixed.default_color), "A colour reset must give a fixed marking its own colour")
	TEST_ASSERT_EQUAL(markings.find_entry(BODY_ZONE_L_ARM, ink.name).get_color(), "#020202", "A colour reset must leave a locked marking's colour alone")

/// Character setup seeds a new marking's colour from the preview body's mutant colours by the marking's mode, when it
/// is added and when a preset brings it.
/datum/unit_test/body_marking_colors/setup_seeds
	/// The left arm's real marking choices, restored after the test narrows them.
	var/list/original_choices

/datum/unit_test/body_marking_colors/setup_seeds/Destroy()
	if(original_choices)
		GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	return ..()

/datum/unit_test/body_marking_colors/setup_seeds/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	// mode -> the preview feature it follows, or null for a marking's own colour.
	var/list/sources = list(
		MARKING_COLOR_FOLLOWS_PRIMARY = FEATURE_MUTANT_COLOR,
		MARKING_COLOR_FOLLOWS_SECONDARY = FEATURE_MUTANT_COLOR_TWO,
		MARKING_COLOR_FOLLOWS_TERTIARY = FEATURE_MUTANT_COLOR_THREE,
		MARKING_COLOR_FIXED_DEFAULT = null,
		MARKING_COLOR_LOCKED = null,
	)
	var/list/markings = list()
	for(var/mode in sources)
		var/datum/body_marking/marking = marking_with_mode(mode)
		if(marking)
			markings += marking
	TEST_ASSERT(length(markings) >= 3, "The fixture needs left arm markings of at least three colour modes")
	original_choices = GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]
	for(var/datum/body_marking/marking as anything in markings)
		// Every refresh rebuilds the preview, so the colours are read from it as each marking is added.
		var/list/preview_features = preferences.character_preview_view.body.dna.features
		var/feature = sources[marking.color_mode]
		var/expected = sanitize_hexcolor(feature ? preview_features[feature] : marking.default_color)
		GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = list(marking.name)
		preferences.body_markings = new /datum/body_marking_collection
		TEST_ASSERT(middleware.add_marking(list("bodypart_slot" = BODY_ZONE_L_ARM), mock_client.mob), "Adding [marking.name] must work")
		TEST_ASSERT_EQUAL(preferences.body_markings.find_entry(BODY_ZONE_L_ARM, marking.name)?.get_color(), expected, "An added [marking.name] ([marking.color_mode]) must start in the colour its mode seeds")
	GLOB.body_markings_per_limb[BODY_ZONE_L_ARM] = original_choices
	original_choices = null

	// A preset seeds each of its markings the same way.
	var/datum/body_marking_set/marking_set = GLOB.body_marking_sets_by_type[/datum/body_marking_set/akula/akula]
	TEST_ASSERT(marking_set, "The fixture needs the Akula marking set")
	preferences.body_markings = new /datum/body_marking_collection
	var/list/seeded_from = preferences.character_preview_view.body.dna.features
	TEST_ASSERT(middleware.set_preset(list("preset" = marking_set.name), mock_client.mob), "The Akula preset must apply")
	for(var/marking_type in marking_set.body_marking_list)
		var/datum/body_marking/marking = GLOB.body_markings_by_type[marking_type]
		var/name = marking.name
		TEST_ASSERT(sources[marking.color_mode], "The fixture preset's [name] must follow a mutant colour")
		var/list/zones = list()
		for(var/zone in GLOB.marking_zones)
			var/datum/body_marking_entry/entry = preferences.body_markings.find_entry(zone, name)
			if(!entry)
				continue
			zones += zone
			TEST_ASSERT_EQUAL(entry.get_color(), sanitize_hexcolor(seeded_from[sources[marking.color_mode]]), "The preset's [name] on [zone] must start in the mutant colour its mode follows")
		TEST_ASSERT(length(zones), "The preset must put [name] on the zones it claims")

/**
 * The marking set factory as it was before it read each marking's affected_bodyparts: every member against every zone's
 * marking list, in GLOB.body_markings_per_limb order. Colours come from seed_color(), the only colour source there is now,
 * so comparing the two compares which entries land on which zones, in what order.
 *
 * Arguments:
 * - marking_set: the set to wear.
 * - features: the features its markings seed from.
 * - species: the species wearing it.
 */
/proc/body_marking_colors_scanned_set(datum/body_marking_set/marking_set, list/features, datum/species/species)
	RETURN_TYPE(/datum/body_marking_collection)
	var/datum/body_marking_collection/body_markings = new
	for(var/marking_type in marking_set.body_marking_list)
		var/datum/body_marking/body_marking = GLOB.body_markings_by_type[marking_type]
		for(var/zone, markings in GLOB.body_markings_per_limb)
			var/list/marking_list = markings
			if(body_marking && (body_marking.name in marking_list))
				body_markings.add_entry(new /datum/body_marking_entry(body_marking, zone, body_marking.seed_color(features, species), FALSE))
	return body_markings

/// Every marking set builds exactly the collection the per-limb scan built: the same entries on the same zones, in the same order.
/datum/unit_test/body_marking_colors/set_factory

/datum/unit_test/body_marking_colors/set_factory/Run()
	var/list/features = seed_features()
	var/datum/species/species = GLOB.species_prototypes[/datum/species/mammal]
	var/compared = 0
	for(var/set_name, set_datum in GLOB.body_marking_sets)
		var/datum/body_marking_set/marking_set = set_datum
		var/scanned = json_encode(body_marking_colors_scanned_set(marking_set, features, species).serialize())
		var/built = json_encode(assemble_body_markings_from_set(marking_set, features, species).serialize())
		TEST_ASSERT_EQUAL(built, scanned, "The [set_name] set must build what the per-limb scan built")
		compared++
	TEST_ASSERT_EQUAL(compared, length(GLOB.body_marking_sets), "Every marking set must be compared")
	// A member no marking is registered under, as an abstract family type, adds nothing, as it matched no zone's list.
	var/datum/body_marking_set/odd_set = allocate(/datum/body_marking_set)
	odd_set.body_marking_list = list(/datum/body_marking/secondary, /datum/body_marking/secondary/bovine)
	TEST_ASSERT_NULL(GLOB.body_markings_by_type[/datum/body_marking/secondary], "The fixture needs a marking type no marking is registered under")
	TEST_ASSERT_EQUAL(json_encode(assemble_body_markings_from_set(odd_set, features, species).serialize()), json_encode(body_marking_colors_scanned_set(odd_set, features, species).serialize()), "A set naming no marking must build what the per-limb scan built")

/**
 * What each of the seven species that had a randomiser of its own could pick, as those get_random_body_markings()
 * overrides were written before get_random_marking_sets() replaced them: a forced set, a fixed list to pick from, or the
 * sets meant for any species or for this one. Kept here, and nowhere in the game, as the reference.
 *
 * Arguments:
 * - species: one of the seven species' prototypes.
 *
 * Returns:
 * - list: set names in the order the override picked from.
 */
/proc/body_marking_colors_old_set_names(datum/species/species)
	switch(species.type)
		if(/datum/species/akula)
			return list("Akula")
		if(/datum/species/aquatic)
			return list("Shark")
		if(/datum/species/tajaran)
			return list("Tajaran", "Floof", "Floofer")
		if(/datum/species/vulpkanin)
			return list("Fox", "Floof", "Floofer")
		if(/datum/species/vox)
			return list("Vox", "Vox Hive", "Vox Nightling", "Vox Heart", "Vox Tiger")
		if(/datum/species/mammal, /datum/species/moth)
			. = list()
			for(var/set_name, set_datum in GLOB.body_marking_sets)
				var/datum/body_marking_set/setter = set_datum
				if(isnull(setter.recommended_species) || !isnull(setter.recommended_species[species.id]))
					. += set_name
			return .
	CRASH("[species.type] had no randomiser of its own")

/// Each species' random markings come from the sets its own randomiser picked from, and a species without one gets none.
/datum/unit_test/body_marking_colors/species_random_sets

/**
 * Returns the names of the sets a species' get_random_marking_sets() gives, in pick order, whatever shape it returns.
 *
 * Arguments:
 * - species: the species to ask.
 */
/datum/unit_test/body_marking_colors/species_random_sets/proc/random_set_names(datum/species/species)
	RETURN_TYPE(/list)
	var/sets = species.get_random_marking_sets()
	var/list/set_types = islist(sets) ? sets : (sets ? list(sets) : null)
	. = list()
	for(var/set_type in set_types)
		var/datum/body_marking_set/marking_set = GLOB.body_marking_sets_by_type[set_type]
		// A typepath no set has shows as itself, so the comparison names it.
		. += marking_set ? marking_set.name : "[set_type]"

/datum/unit_test/body_marking_colors/species_random_sets/Run()
	// The typepath map holds every named set, the same instances the name map holds, in the same order.
	var/list/by_name = list()
	for(var/set_name, set_datum in GLOB.body_marking_sets)
		by_name += set_datum
	var/list/by_type = list()
	for(var/set_type, set_datum in GLOB.body_marking_sets_by_type)
		var/datum/body_marking_set/marking_set = set_datum
		TEST_ASSERT_EQUAL(marking_set.type, set_type, "The typepath map must key each set by its own type")
		by_type += marking_set
	TEST_ASSERT(length(by_type), "The typepath map must hold the marking sets")
	TEST_ASSERT_EQUAL(length(by_type), length(by_name), "The typepath map must hold every named set")
	for(var/index in 1 to length(by_name))
		TEST_ASSERT(by_type[index] == by_name[index], "The typepath map must hold the name map's sets in its order, not [by_type[index]] at [index]")

	var/list/features = seed_features()
	for(var/species_type in list(/datum/species/akula, /datum/species/aquatic, /datum/species/mammal, /datum/species/moth, /datum/species/tajaran, /datum/species/vox, /datum/species/vulpkanin))
		var/datum/species/species = GLOB.species_prototypes[species_type]
		var/list/old_names = body_marking_colors_old_set_names(species)
		TEST_ASSERT_EQUAL(json_encode(random_set_names(species)), json_encode(old_names), "[species.id] must pick from the same marking sets, in the same order")
		// What a random body can wear: one of those sets, seeded from its features.
		var/list/layouts = list()
		for(var/set_name in old_names)
			var/datum/body_marking_set/marking_set = GLOB.body_marking_sets[set_name]
			TEST_ASSERT(marking_set, "[species.id]'s [set_name] marking set must exist")
			layouts[json_encode(assemble_body_markings_from_set(marking_set, features, species).serialize())] = set_name
		for(var/draw in 1 to 20)
			var/drawn = json_encode(species.get_random_body_markings(features).serialize())
			TEST_ASSERT(layouts[drawn], "A random [species.id] must wear one of its marking sets, not [drawn]")
	var/datum/species/human = GLOB.species_prototypes[/datum/species/human]
	TEST_ASSERT_NULL(human.get_random_marking_sets(), "A species without a marking set must have none to pick from")
	TEST_ASSERT(!human.get_random_body_markings(features).entry_count(), "A species without a marking set must start with no markings")
