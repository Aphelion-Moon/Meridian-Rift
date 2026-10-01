/// A preview body from preferences: lit is a lizard with emissive eyes and a glowing chest marking.
/proc/character_preview_glow_test_body(datum/unit_test/test, lit)
	var/datum/client_interface/mock_client = test.allocate(/datum/client_interface)
	var/datum/preferences/preferences = test.allocate(/datum/preferences/preferences_import_test, mock_client)
	// New preferences randomize appearance, including animated styles such as Lizard Tongue Flick.
	// These tests start with a still body, then add only the glow or animation under test.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], "Bald")
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], "Shaved")
	// A lizard: Bovine has chest art for it, as the marking tests use.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], lit ? SPECIES_LIZARD : SPECIES_HUMAN)
	if(lit)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/eye_emissives], TRUE)
		preferences.body_markings = body_marking_collection_from_list(json_decode("{\"chest\":{\"Bovine\":\[\"#44CCFF\",1]}}"))
	var/atom/movable/screen/map_view/char_preview/view = test.allocate(/atom/movable/screen/map_view/char_preview, null, null, preferences)
	view.update_body()
	return view.body

/// How many of a glow's pixels light what is under them: red (blooming) or green, through any blockers.
/proc/character_preview_glow_test_lit_pixels(datum/universal_icon/glow)
	var/icon/drawn = glow.to_icon()
	. = 0
	for(var/x in 1 to drawn.Width())
		for(var/y in 1 to drawn.Height())
			var/pixel = drawn.GetPixel(x, y)
			if(!pixel)
				continue
			var/list/channels = rgb2num(pixel)
			if(channels[1] || channels[2])
				.++

/// Character setup's preview draws what glows only with the lights off and only for a look that has something to
/// glow, on the drawing's own canvas, and a garment over a glowing marking hides its glow as the game does.

/datum/unit_test/character_preview_glow
	/// Restore the actual configured choices after this test, including an uninitialized cache.
	var/list/original_species_choices

// These fixtures exercise species-specific bodies, independently of the server's enabled species.
/datum/unit_test/character_preview_glow/New()
	. = ..()
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	original_species_choices = species_preference.cached_values
	species_preference.cached_values = list(/datum/species/human, /datum/species/lizard)

/datum/unit_test/character_preview_glow/Destroy()
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	species_preference.cached_values = original_species_choices
	original_species_choices = null
	return ..()

/datum/unit_test/character_preview_glow/Run()
	var/mob/living/carbon/human/dummy/plain = character_preview_glow_test_body(src, FALSE)
	TEST_ASSERT(isnull(character_preview_walk(plain, TRUE)["glow_recipes"]), "A look with nothing that glows must draw no glow, even with the lights off.")

	var/mob/living/carbon/human/dummy/body = character_preview_glow_test_body(src, TRUE)
	TEST_ASSERT(isnull(character_preview_walk(body)["glow_recipes"]), "With the lights on, no glow may be drawn, whatever glows.")
	var/list/walk = character_preview_walk(body, TRUE)
	var/list/glow_recipes = walk["glow_recipes"]
	TEST_ASSERT_EQUAL(length(glow_recipes), length(GLOB.character_preview_facings), "With the lights off, a look that glows must draw every facing's glow.")

	var/datum/preference_middleware/character_preview/drawing = new(null)
	var/list/drawn = drawing.draw_preview(walk)
	TEST_ASSERT(drawn, "A drawing with its glow must come out.")
	var/list/glow_frames = drawn["glow_frames"]
	TEST_ASSERT_EQUAL(length(glow_frames), length(GLOB.character_preview_facings), "The drawing must say where every facing's glow is.")
	var/list/lefts = list()
	for(var/facing, left in drawn["frames"])
		lefts["[left]"] = TRUE
	for(var/facing, left in glow_frames)
		lefts["[left]"] = TRUE
	TEST_ASSERT_EQUAL(length(lefts), 2 * length(GLOB.character_preview_facings), "Each facing and each glow must have a frame of its own in the strip.")
	drawing.release_drawing(drawn["name"])
	qdel(drawing)

	var/list/box = character_preview_flat_box(get_flat_uni_icon(body, UP, grow = TRUE))
	var/bare = character_preview_glow_test_lit_pixels(character_preview_glow(body, SOUTH, box))
	TEST_ASSERT(bare, "Glowing eyes and a glowing chest marking must light pixels.")
	if(body.w_uniform)
		qdel(body.w_uniform)
	TEST_ASSERT(body.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(body), ITEM_SLOT_ICLOTHING), "The fixture must wear a jumpsuit.")
	box = character_preview_flat_box(get_flat_uni_icon(body, UP, grow = TRUE))
	var/dressed = character_preview_glow_test_lit_pixels(character_preview_glow(body, SOUTH, box))
	TEST_ASSERT(dressed > 0 && dressed < bare, "A jumpsuit over the glowing marking must hide its glow and leave the eyes' ([dressed] pixels lit dressed, [bare] bare).")

/// Recycled preview eyes must take the next character's emission setting, including when it is off.
/datum/unit_test/character_preview_recycled_eye_glow/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences_import_test/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/datum/preference/eye_emissives = GLOB.preference_entries[/datum/preference/toggle/eye_emissives]
	var/mob/living/carbon/human/dummy/consistent/body = allocate(/mob/living/carbon/human/dummy/consistent)
	var/obj/item/organ/eyes/eyes = body.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT(istype(eyes), "A human preview must start with eyes.")
	allocated += eyes // Also clean up if a failing assertion leaves the eyes detached.
	eye_emissives.apply_to_human(body, TRUE, preferences)
	TEST_ASSERT(eyes.is_emissive, "The first character must make its eyes emissive.")

	// Exercise the pool callbacks directly so the test does not depend on how much stock SSwardrobe holds.
	for(var/emissive_value in list(FALSE, TRUE, FALSE))
		eyes.Remove(body, special = TRUE)
		eyes.enter_wardrobe()
		TEST_ASSERT_EQUAL(eyes.is_emissive, FALSE, "Returning preview eyes to the wardrobe must clear the previous character's emission.")
		// Preferences apply before species inserts its replacement eyes.
		eye_emissives.apply_to_human(body, emissive_value, preferences)
		eyes.exit_wardrobe()
		eyes.Insert(body, special = TRUE)
		TEST_ASSERT_EQUAL(body.emissive_eyes, emissive_value, "The body must keep the current character's emission setting.")
		TEST_ASSERT_EQUAL(eyes.is_emissive, emissive_value, "Recycled eyes must match the current character after insertion.")
		var/list/glow_recipes = character_preview_walk(body, TRUE)["glow_recipes"]
		TEST_ASSERT_EQUAL(!!length(glow_recipes), emissive_value, "The preview must only draw eye glow for the current character's enabled setting.")
