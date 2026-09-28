/// Shared setup for the tests of save version 22's marking content: fixtures loaded the way a connection loads a character, and
/// bodies signed the way the appearance harness signs them. Abstract, so the runner never runs it on its own.
/datum/unit_test/body_marking_content
	abstract_type = /datum/unit_test/body_marking_content

/**
 * Returns memory-only preferences with a mock client, which the savefile fixtures load into.
 */
/datum/unit_test/body_marking_content/proc/fixture_preferences()
	RETURN_TYPE(/datum/preferences)
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	return allocate(/datum/preferences/preferences_import_test, mock_client)

/**
 * Loads a character slot holding a savefile tree the way a connection does, then saves it. Returns what was written.
 *
 * Arguments:
 * - preferences: the preferences to load into.
 * - slot: the character's savefile tree. It is stored as given and rewritten by the load and the save.
 */
/datum/unit_test/body_marking_content/proc/load_and_save(datum/preferences/preferences, list/slot)
	RETURN_TYPE(/list)
	preferences.savefile.set_entry("character[preferences.default_slot]", slot)
	preferences.value_cache = list()
	if(!preferences.load_character(preferences.default_slot))
		return null
	preferences.save_character()
	return preferences.savefile.get_entry("character[preferences.default_slot]")

/**
 * Signs a body wearing a collection as the appearance harness signs a case, every pixel of every facing, and adds what a flat
 * icon never shows: what its limbs put on the emissive plane, the glowing appearances drawn over each other per facing.
 *
 * Arguments:
 * - markings: the collection to wear, as it is.
 * - digitigrade: TRUE to stand the body on digitigrade legs.
 *
 * Returns the signature as text, so two compare with one assertion.
 */
/datum/unit_test/body_marking_content/proc/signature(datum/body_marking_collection/markings, digitigrade = FALSE)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.hairstyle = "Bald"
	body.facial_hairstyle = "Shaved"
	body.physique = MALE
	if(digitigrade)
		for(var/zone, leg_type in list(BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/digitigrade, BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/digitigrade))
			// try_attach_limb() stack traces over a limb still in its zone, so the old leg goes first.
			var/obj/item/bodypart/old_leg = body.get_bodypart(zone)
			old_leg.drop_limb(special = TRUE)
			qdel(old_leg)
			var/obj/item/bodypart/leg/new_leg = new leg_type()
			new_leg.try_attach_limb(body, special = TRUE)
	body.dna.body_markings = markings
	body.update_body_parts(update_limb_data = TRUE)
	var/list/record = markings_baseline_signature(get_flat_icon_for_all_directions(body))
	// Every marking glow shares one colour matrix, so the glowing shape is the icons' own pixels.
	var/icon/glow
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		for(var/image/overlay as anything in limb.get_limb_icon(FALSE))
			if(!overlay || PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE || !markings_baseline_is_glowing(overlay))
				continue
			if(glow)
				glow.Blend(icon(overlay.icon, overlay.icon_state), ICON_OVERLAY)
			else
				glow = icon(overlay.icon, overlay.icon_state)
	record["glow"] = glow ? markings_baseline_signature(glow) : null
	return json_encode(record)

/// A save from before version 22 has every Rat Paw renamed Hands Feet before its markings load: the same art, colour, glow and
/// place, on an arm too, which Hands Feet now claims. A zone that wore both keeps one entry: the later one, which drew on top, in
/// its place and colour, glowing if either glowed. Saved again it writes back byte for byte, and a save with nothing to rename
/// keeps every byte but its version. A version 22 save is not renamed again.
/datum/unit_test/body_marking_content/rat_paw_saves

/datum/unit_test/body_marking_content/rat_paw_saves/Run()
	var/datum/preferences/preferences = fixture_preferences()
	// Saved markings -> what they load as.
	var/list/cases = list(
		// Alone, on a hand and on a leg beside another marking.
		"{\"l_hand\":{\"Rat Paw\":\[\"#aa0000\",1]},\"r_leg\":{\"Bovine\":\[\"#111111\",0],\"Rat Paw\":\[\"#bb0000\",0]}}" = "{\"l_hand\":{\"Hands Feet\":\[\"#aa0000\",1]},\"r_leg\":{\"Bovine\":\[\"#111111\",0],\"Hands Feet\":\[\"#bb0000\",0]}}",
		// Both on one zone, either order: the later stays in its place and colour, glowing where the earlier glowed.
		"{\"l_leg\":{\"Hands Feet\":\[\"#110000\",1],\"Bovine\":\[\"#222222\",0],\"Rat Paw\":\[\"#330000\",0]},\"r_leg\":{\"Rat Paw\":\[\"#440000\",0],\"Hands Feet\":\[\"#550000\",1]},\"r_hand\":{\"Rat Paw\":\[\"#660000\",1],\"Hands Feet\":\[\"#770000\",0]}}" = "{\"l_leg\":{\"Bovine\":\[\"#222222\",0],\"Hands Feet\":\[\"#330000\",1]},\"r_leg\":{\"Hands Feet\":\[\"#550000\",1]},\"r_hand\":{\"Hands Feet\":\[\"#770000\",1]}}",
		// On an arm, which only Rat Paw claimed.
		"{\"l_arm\":{\"Rat Paw\":\[\"#880000\",0]},\"r_arm\":{}}" = "{\"l_arm\":{\"Hands Feet\":\[\"#880000\",0]},\"r_arm\":\[]}",
	)
	for(var/saved, expected in cases)
		// A mammal with mismatched parts allowed, so nothing but the rename touches the markings.
		var/list/written = load_and_save(preferences, list("version" = 52, "modular_version" = 21, "tgui_prefs_migration" = TRUE, "species" = SPECIES_MAMMAL, "allow_mismatched_parts_toggle" = TRUE, "body_markings" = json_decode(saved)))
		TEST_ASSERT(written, "A version 21 character must load")
		TEST_ASSERT_EQUAL(json_encode(written["body_markings"]), expected, "A version 21 save of [saved] must load as expected")
		TEST_ASSERT_EQUAL(written["modular_version"], 22, "A saved character must be at version 22")
		TEST_ASSERT_EQUAL(signature(preferences.body_markings.copy()), signature(body_marking_collection_from_list(json_decode(expected))), "[saved] must render as a body wearing [expected] does")
		var/first = json_encode(written)
		written = load_and_save(preferences, written)
		TEST_ASSERT_EQUAL(json_encode(written), first, "A second load and save of [saved] must change nothing")
		// Nothing to rename: every byte but the version stays.
		var/list/unrenamed = json_decode(first)
		unrenamed["modular_version"] = 21
		TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, unrenamed)), first, "A version 21 save with nothing to rename must keep every byte but its version")
	// Version 22 has had the rename: a Rat Paw an edited save holds is left to the loader, which drops a name it doesn't know.
	var/list/current = load_and_save(preferences, list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "species" = SPECIES_MAMMAL, "allow_mismatched_parts_toggle" = TRUE, "body_markings" = list(BODY_ZONE_PRECISE_L_HAND = list("Rat Paw" = list("#aa0000", 1)))))
	TEST_ASSERT_EQUAL(json_encode(current["body_markings"]), "{\"l_hand\":\[]}", "A version 22 save must not be renamed again")

/// Rat Paw drew Hands Feet's art state for state (the drop proof of its states), so a zone that wore both looked like its top
/// entry: the one entry the rename keeps draws the same pixels, and the same glowing shape, glowing if either entry did.
/datum/unit_test/body_marking_content/rat_paw_render

/datum/unit_test/body_marking_content/rat_paw_render/Run()
	var/datum/body_marking/hands_feet = GLOB.body_markings_by_type[/datum/body_marking/secondary/handsfeet]
	// Rat Paw as it was: its own name on Hands Feet's art, which its states equalled.
	var/datum/body_marking/rat_paw = new
	rat_paw.name = "Rat Paw"
	rat_paw.icon = hands_feet.icon
	rat_paw.icon_state = hands_feet.icon_state
	rat_paw.affected_bodyparts = hands_feet.affected_bodyparts
	// bottom glows, top glows
	for(var/list/glows as anything in list(list(TRUE, FALSE), list(FALSE, TRUE), list(TRUE, TRUE), list(FALSE, FALSE)))
		for(var/digitigrade in list(FALSE, TRUE))
			var/datum/body_marking_collection/pair = new
			var/datum/body_marking_collection/kept = new
			for(var/zone in GLOB.marking_zones)
				if(!(hands_feet.affected_bodyparts & GLOB.marking_zone_to_bitflag[zone]))
					continue
				pair.add_entry(new /datum/body_marking_entry(rat_paw, zone, "#cc3344", glows[1]))
				pair.add_entry(new /datum/body_marking_entry(hands_feet, zone, "#33aa55", glows[2]))
				kept.add_entry(new /datum/body_marking_entry(hands_feet, zone, "#33aa55", glows[1] || glows[2]))
			TEST_ASSERT_EQUAL(signature(kept, digitigrade), signature(pair, digitigrade), "The kept entry must draw what Rat Paw under Hands Feet drew (glows [json_encode(glows)], digitigrade [digitigrade])")

/// A custom-style package names markings too, in the sidecar's restore points and in style files players keep: a record naming
/// Rat Paw validates as Hands Feet, and a package wearing both keeps one record as the save migration keeps one entry. A name
/// repeated in one package is still refused.
/datum/unit_test/body_marking_content/rat_paw_styles

/datum/unit_test/body_marking_content/rat_paw_styles/Run()
	var/list/result = custom_style_validate_markings(list(list("name" = "Rat Paw", "color" = "#aa0000", "emissive" = TRUE)), BODY_ZONE_L_ARM)
	TEST_ASSERT_EQUAL(json_encode(result["markings"]), json_encode(list(list("name" = "Hands Feet", "color" = "#aa0000", "emissive" = TRUE))), "Rat Paw on an arm must validate as Hands Feet: [result["error"]]")
	var/list/both = list(
		list("name" = "Hands Feet", "color" = "#110000", "emissive" = TRUE),
		list("name" = "Bovine", "color" = "#222222", "emissive" = FALSE),
		list("name" = "Rat Paw", "color" = "#330000", "emissive" = FALSE),
	)
	var/list/one = list(
		list("name" = "Bovine", "color" = "#222222", "emissive" = FALSE),
		list("name" = "Hands Feet", "color" = "#330000", "emissive" = TRUE),
	)
	result = custom_style_validate_markings(both, BODY_ZONE_R_LEG)
	TEST_ASSERT_EQUAL(json_encode(result["markings"]), json_encode(one), "Both on a leg must keep the later record, glowing: [result["error"]]")
	result = custom_style_validate_markings(list(list("name" = "Rat Paw", "color" = "#110000", "emissive" = FALSE), list("name" = "Rat Paw", "color" = "#220000", "emissive" = FALSE)), BODY_ZONE_R_LEG)
	TEST_ASSERT(result["error"], "A name repeated in one package must still be refused")
	// A restore point in the sidecar.
	var/list/restored = custom_style_previous_validate(list("markings:[BODY_ZONE_R_LEG]" = custom_style_package("markings", BODY_ZONE_R_LEG, null, null, both)))
	TEST_ASSERT_EQUAL(json_encode(restored?["markings:[BODY_ZONE_R_LEG]"]?["markings"]), json_encode(one), "A restore point holding Rat Paw must keep it as Hands Feet")
	// A style file a player uploads.
	var/list/uploaded = custom_style_parse(custom_style_export_text(custom_style_package("markings", BODY_ZONE_R_LEG, null, null, both)))
	TEST_ASSERT_EQUAL(json_encode(uploaded["package"]?["markings"]), json_encode(one), "An uploaded style holding Rat Paw must import it as Hands Feet: [uploaded["error"]]")
