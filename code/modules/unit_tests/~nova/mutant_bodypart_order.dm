/// Parts on one layer of one limb draw in the order their organs went in, and regenerate_organs() puts the organs in one fixed
/// order, mutant_bodyparts_in_draw_order(), whatever order the DNA's container holds its keys in: the keys preferences give, in
/// the order apply_prefs_to() first writes each, then any other key in text order.
/datum/unit_test/mutant_bodypart_order

/datum/unit_test/mutant_bodypart_order/Run()
	// The order itself: the preferences' own, the first writer of each key deciding its place.
	var/list/places = list()
	for(var/datum/preference/preference as anything in get_preferences_in_priority_order())
		var/key = preference.relevant_mutant_bodypart
		if(key && !(key in places) && (istype(preference, /datum/preference/choiced/mutant_choice) || istype(preference, /datum/preference/choiced/genital) || istype(preference, /datum/preference/toggle/emissive)))
			places += key
	TEST_ASSERT_EQUAL(json_encode(assoc_to_keys(mutant_bodypart_preference_order())), json_encode(places), "The order must be the preferences' own, the first writer of each key deciding its place")
	var/datum/mutant_bodypart/part = build_mutant_part("Smooth")
	var/list/container = list("zz_unwritten" = part, FEATURE_HORNS = part, "aa_unwritten" = part, FEATURE_TAIL = part, FEATURE_SNOUT = part)
	var/list/expected = list()
	for(var/key in places)
		if(key in container)
			expected += key
	expected += list("aa_unwritten", "zz_unwritten")
	TEST_ASSERT_EQUAL(json_encode(mutant_bodyparts_in_draw_order(container)), json_encode(expected), "Keys no preference writes must come last, in text order")
	TEST_ASSERT_NULL(mutant_bodyparts_in_draw_order(list()), "An empty container must give no order")

	// A lizard's parts entered in either order stack and draw the same: the organs go in, and the overlays stack, in the order.
	var/list/names = list(FEATURE_TAIL = "Smooth", FEATURE_SNOUT = "Sharp + Light", FEATURE_HORNS = "Curled", FEATURE_FRILLS = "Short", FEATURE_SPINES = "Long + Membrane")
	var/list/colours = list(FEATURE_TAIL = "#ff0000", FEATURE_SNOUT = "#00c000", FEATURE_HORNS = "#0000ff", FEATURE_FRILLS = "#e0e000", FEATURE_SPINES = "#ff00ff")
	var/list/forward = assoc_to_keys(names)
	var/list/reversed = reverse_range(forward.Copy())
	var/list/drawn = list()
	for(var/list/entered as anything in list(forward, reversed))
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
		body.set_species(/datum/species/lizard)
		var/list/mutant_bodyparts = list()
		for(var/key in entered)
			mutant_bodyparts[key] = build_mutant_part(names[key], list(colours[key], colours[key], colours[key]))
		body.dna.mutant_bodyparts = mutant_bodyparts
		body.dna.species.regenerate_organs(body, body.dna.species, visual_only = TRUE)
		body.update_body(is_creating = TRUE)
		var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
		var/list/stacked = list()
		for(var/datum/bodypart_overlay/mutant/overlay in head.bodypart_overlays)
			stacked += overlay.feature_key
		var/list/wanted = list()
		for(var/key in mutant_bodyparts_in_draw_order(names))
			if(key in stacked)
				wanted += key
		TEST_ASSERT_EQUAL(json_encode(stacked), json_encode(wanted), "The head's parts must stack in the fixed order, entered as [json_encode(entered)]")
		var/list/signature = markings_baseline_signature(get_flat_icon_for_all_directions(body))
		drawn += signature["pixels_md5"]
	TEST_ASSERT_EQUAL(drawn[1], drawn[2], "A lizard's parts must draw the same whatever order they were entered in")

/// dna.mutant_bodyparts is an /alist on every path that builds or replaces it, so none falls back to a plain list: a new body, a
/// character built from its preferences, the preview's cleared body, a species change, a DNA copy and the species' own parts.
/datum/unit_test/mutant_bodypart_order/containers

/datum/unit_test/mutant_bodypart_order/containers/Run()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(isalist(body.dna.mutant_bodyparts), "A new body's parts must be an /alist")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_LIZARD)
	preferences.apply_prefs_to(body, TRUE)
	TEST_ASSERT(length(body.dna.mutant_bodyparts), "The lizard must have parts")
	TEST_ASSERT(isalist(body.dna.mutant_bodyparts), "A character built from its preferences must keep an /alist")
	var/mob/living/carbon/human/dummy/mannequin = allocate(/mob/living/carbon/human/dummy)
	preferences.render_new_preview_appearance(mannequin, FALSE)
	TEST_ASSERT(isalist(mannequin.dna.mutant_bodyparts), "The preview's cleared body must keep an /alist")
	body.set_species(/datum/species/mammal)
	TEST_ASSERT(isalist(body.dna.mutant_bodyparts), "A species change must keep an /alist")
	var/mob/living/carbon/human/consistent/copy = allocate(/mob/living/carbon/human/consistent)
	body.dna.copy_dna(copy.dna, COPY_DNA_SE|COPY_DNA_SPECIES)
	TEST_ASSERT(isalist(copy.dna.mutant_bodyparts), "A DNA copy must be an /alist")
	var/datum/species/lizard/lizard = GLOB.species_prototypes[/datum/species/lizard]
	TEST_ASSERT(isalist(lizard.get_mutant_bodyparts(body.dna.features)), "A species' own parts must be built as an /alist")
