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

/**
 * Loads a savefile tree into these preferences and draws the character as a spawn does, on a fresh body, and signs it as the
 * appearance harness signs a case. The tree is loaded as given and not saved.
 *
 * Arguments:
 * - preferences: the preferences to load into.
 * - slot: the character's savefile tree.
 */
/datum/unit_test/body_marking_content/proc/character_signature(datum/preferences/preferences, list/slot)
	preferences.savefile.set_entry("character[preferences.default_slot]", slot)
	preferences.value_cache = list()
	if(!preferences.load_character(preferences.default_slot))
		return null
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE)
	return json_encode(markings_baseline_signature(get_flat_icon_for_all_directions(body)))

/// A save from before version 22 whose character wears a marking its species may no longer pick, since sets decide who may
/// wear what, has mismatched parts turned on as it loads, so the marking stays editable, but only where that changes nothing
/// else the character draws: with a mutant part left switched on for a feature the species lacks, which mismatched parts would
/// show, the toggle stays off. A save with the toggle on, or whose markings all fit its species, keeps every byte but its version.
/// The two tests after this one pin what the check asks beyond the parts' values.
/datum/unit_test/body_marking_content/mismatched_markings

/datum/unit_test/body_marking_content/mismatched_markings/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/datum/body_marking/splotches = GLOB.body_markings_by_type[/datum/body_marking/other/splotches]
	TEST_ASSERT(!splotches.allows_species(SPECIES_HUMAN), "The fixture needs a marking a human may not pick: Splotches is for its set's species")
	var/list/off_species = list(BODY_ZONE_HEAD = list("Splotches" = list("#aa0000", 0)))
	var/off_species_text = json_encode(off_species)
	// (a) Nothing else would change: the toggle goes on and persists, and the marking loads, draws and stays editable.
	var/list/written = load_and_save(preferences, list("version" = 52, "modular_version" = 21, "tgui_prefs_migration" = TRUE, "species" = SPECIES_HUMAN, "body_markings" = json_decode(off_species_text)))
	TEST_ASSERT(written, "A version 21 human must load")
	TEST_ASSERT_EQUAL(written["allow_mismatched_parts_toggle"], TRUE, "The save must hold mismatched parts on")
	TEST_ASSERT(preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts), "The loaded character must have mismatched parts on")
	TEST_ASSERT_EQUAL(json_encode(written["body_markings"]), off_species_text, "The markings must load as saved")
	var/list/before_flip = json_decode(json_encode(written))
	before_flip["allow_mismatched_parts_toggle"] = FALSE
	TEST_ASSERT_EQUAL(character_signature(preferences, written), character_signature(preferences, before_flip), "Mismatched parts on must draw the character as it was with them off")
	var/first = json_encode(written)
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, json_decode(first))), first, "A second load and save must change nothing")
	// The marking stays editable: another zone takes it too.
	var/mob/user = preferences.parent.mob
	preferences.create_character_preview_view(user)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware.add_marking(list("bodypart_slot" = BODY_ZONE_CHEST, "marking_name" = splotches.name), user), "The character must be able to add the marking to another zone")
	// (b) A snout left switched on, which a human lacks and mismatched parts would show: the toggle stays off, nothing changes.
	var/list/snouted = json_decode(first)
	snouted["allow_mismatched_parts_toggle"] = FALSE
	snouted["snout_toggle"] = TRUE
	snouted["feature_snout"] = "Beak"
	var/snouted_text = json_encode(snouted)
	var/list/stale = json_decode(snouted_text)
	stale["modular_version"] = 21
	written = load_and_save(preferences, stale)
	TEST_ASSERT_EQUAL(json_encode(written), snouted_text, "With a part mismatched parts would show, the save must keep every byte but its version")
	TEST_ASSERT_EQUAL(character_signature(preferences, written), character_signature(preferences, json_decode(snouted_text)), "The character must draw as it did")
	TEST_ASSERT(!preferences.mismatched_parts_change_nothing(), "The snout must count as a change")
	var/datum/preference/choiced/mutant_choice/snout/snout = GLOB.preference_entries[/datum/preference/choiced/mutant_choice/snout]
	TEST_ASSERT(!snout.is_visible(null, preferences), "The snout must stay hidden")
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	TEST_ASSERT(snout.is_visible(null, preferences), "The player turning mismatched parts on must show the snout")
	// (c) The toggle already on: every byte but the version.
	var/list/switched_on = json_decode(first)
	switched_on["modular_version"] = 21
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, switched_on)), first, "A save with mismatched parts on must keep every byte but its version")
	// (d) Every marking fits the species: every byte but the version.
	var/list/fitting = json_decode(first)
	fitting["allow_mismatched_parts_toggle"] = FALSE
	fitting["body_markings"] = list(BODY_ZONE_CHEST = list("Tattoo - Heart" = list("#112222", 0)))
	var/fitting_text = json_encode(fitting)
	fitting["modular_version"] = 21
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, fitting)), fitting_text, "A save whose markings all fit its species must keep every byte but its version")

/// A snout switched on and left at None draws nothing, yet with mismatched parts on the snout preference makes a human's head
/// snouted, so masks and helmets would take their muzzled sprites: the check asks whether each part shows, not only what it
/// would apply, and a save from before version 22 with such a snout keeps mismatched parts off, and every byte but its version.
/datum/unit_test/body_marking_content/mismatched_markings_snout

/datum/unit_test/body_marking_content/mismatched_markings_snout/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/list/written = load_and_save(preferences, list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "species" = SPECIES_HUMAN, "allow_mismatched_parts_toggle" = FALSE, "snout_toggle" = TRUE, "feature_snout" = SPRITE_ACCESSORY_NONE, "body_markings" = list(BODY_ZONE_HEAD = list("Splotches" = list("#aa0000", 0)))))
	TEST_ASSERT(written, "A version 22 human must load")
	var/written_text = json_encode(written)
	var/list/stale = json_decode(written_text)
	stale["modular_version"] = 21
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, stale)), written_text, "With a snout switched on at None, the save must keep every byte but its version")
	TEST_ASSERT(!preferences.mismatched_parts_change_nothing(), "A snout switched on at None must count as a change")
	// Why: a body drawn with mismatched parts on has a snouted head.
	var/mob/living/carbon/human/consistent/as_loaded = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(as_loaded, TRUE)
	var/obj/item/bodypart/head/loaded_head = as_loaded.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!(loaded_head.bodyshape & BODYSHAPE_SNOUTED), "The loaded human's head must not be snouted")
	preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = TRUE
	var/mob/living/carbon/human/consistent/mismatched = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(mismatched, TRUE)
	var/obj/item/bodypart/head/mismatched_head = mismatched.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(mismatched_head.bodyshape & BODYSHAPE_SNOUTED, "With mismatched parts on, the human's head must be snouted")

/**
 * Loads a savefile tree into these preferences and spawns the character on a fresh body, as a job does, and records what the
 * body got that the mismatched parts check asks about: its flattened pixels, mutant parts, limbs (where leg augments go), the DNA
 * features the penis's taur mode and sheath go in, and whether it can knot. The tree is loaded as given and not saved.
 *
 * Arguments:
 * - preferences: the preferences to load into.
 * - slot: the character's savefile tree.
 *
 * Returns the record as text, so two compare with one assertion.
 */
/datum/unit_test/body_marking_content/proc/spawn_record(datum/preferences/preferences, list/slot)
	preferences.savefile.set_entry("character[preferences.default_slot]", slot)
	preferences.value_cache = list()
	if(!preferences.load_character(preferences.default_slot))
		return null
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE)
	var/list/record = markings_baseline_signature(get_flat_icon_for_all_directions(body))
	var/list/parts = list()
	for(var/key, part_datum in body.dna.mutant_bodyparts)
		var/datum/mutant_bodypart/part = part_datum
		parts[key] = part.name
	record["mutant_parts"] = parts
	var/list/limbs = list()
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		limbs[limb.body_zone] = "[limb.type]"
	record["limbs"] = limbs
	record["penis_taur_mode"] = body.dna.features["penis_taur_mode"]
	record["penis_sheath"] = body.dna.features["penis_sheath"]
	record["knot"] = HAS_TRAIT(body, TRAIT_CAN_KNOT) ? TRUE : FALSE
	return json_encode(record)

/// The check asks its questions as a spawn asks them, without the setup page (is_applicable()), so the characters whose answers
/// used to differ only off the character page flip like any other: a taur with a leg augment (its species has the taur, so the
/// taur takes the legs' place and refuses the augment with the toggle off as with it on), a knot owner, and a penis owner in taur
/// mode or with a sheath (its species has the penis, so the penis choice answers yes either way). Each wears a marking of another
/// species' set and has no part the toggle would show: its save from before version 22 turns mismatched parts on and is written
/// as the same save with the toggle on, and it spawns as that character with the toggle off did. The menu still answers by the
/// page: off the character page the taur choice is accessible only with the toggle on, while is_applicable() answers alike on
/// every page.
/datum/unit_test/body_marking_content/mismatched_markings_apply

/datum/unit_test/body_marking_content/mismatched_markings_apply/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/datum/body_marking/lights = GLOB.body_markings_by_type[/datum/body_marking/secondary/synthliz/lights]
	TEST_ASSERT(!lights.allows_species(SPECIES_MAMMAL), "The fixtures need a marking an anthromorph may not pick: Synth Lights is for synths")
	var/datum/body_marking/splotches = GLOB.body_markings_by_type[/datum/body_marking/other/splotches]
	TEST_ASSERT(!splotches.allows_species(SPECIES_HUMAN), "The fixtures need a marking a human may not pick: Splotches is for its set's species")
	var/datum/augment_item/leg_augment = GLOB.augment_items[/datum/augment_item/limb/l_leg/digi_prosthetic]
	// name -> the savefile tree's keys beyond the version's own
	var/list/fixtures = list(
		"a taur with a leg augment" = list("species" = SPECIES_MAMMAL, "taur_toggle" = TRUE, "feature_taur" = "Bunny", "augments" = list(AUGMENT_SLOT_L_LEG = "[/datum/augment_item/limb/l_leg/digi_prosthetic]"), "body_markings" = list(BODY_ZONE_CHEST = list("Synth Lights" = list("#aa0000", 0)))),
		"a knot owner" = list("species" = SPECIES_HUMAN, "feature_penis" = "Knotted", "has_knot" = TRUE, "body_markings" = list(BODY_ZONE_HEAD = list("Splotches" = list("#aa0000", 0)))),
		"a penis in taur mode" = list("species" = SPECIES_HUMAN, "feature_penis" = "Flared", "penis_taur_mode_toggle" = TRUE, "body_markings" = list(BODY_ZONE_HEAD = list("Splotches" = list("#aa0000", 0)))),
		"a penis with a sheath" = list("species" = SPECIES_HUMAN, "feature_penis" = "Nondescript", "penis_sheath" = "Sheath", "body_markings" = list(BODY_ZONE_HEAD = list("Splotches" = list("#aa0000", 0)))),
	)
	var/taur_text
	for(var/fixture_name, fixture_keys in fixtures)
		// The character as a version 22 save with mismatched parts off: loading it fills every default in, once.
		var/list/tree = list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "allow_mismatched_parts_toggle" = FALSE)
		var/list/extra_keys = fixture_keys
		for(var/key, value in extra_keys)
			tree[key] = json_decode(json_encode(value))
		var/base_text = json_encode(load_and_save(preferences, tree))
		if(fixture_name == "a taur with a leg augment")
			taur_text = base_text
		// The same character saved before version 22.
		var/list/stale = json_decode(base_text)
		stale["modular_version"] = 21
		var/list/written = load_and_save(preferences, stale)
		TEST_ASSERT(written, "[fixture_name] must load")
		// Not an assertion: each fixture that stays off is named.
		if(!preferences.read_preference(/datum/preference/toggle/allow_mismatched_parts))
			TEST_FAIL("[fixture_name] must be loaded with mismatched parts on")
			continue
		var/list/expected = json_decode(base_text)
		expected["allow_mismatched_parts_toggle"] = TRUE
		var/written_text = json_encode(written)
		TEST_ASSERT_EQUAL(written_text, json_encode(expected), "[fixture_name] must be saved as it was, with mismatched parts on and at version 22")
		var/flipped = spawn_record(preferences, json_decode(written_text))
		TEST_ASSERT_EQUAL(flipped, spawn_record(preferences, json_decode(base_text)), "[fixture_name] must spawn with mismatched parts on as it did with them off")
		var/list/got = json_decode(flipped)
		var/list/got_parts = got["mutant_parts"]
		var/list/got_limbs = got["limbs"]
		switch(fixture_name)
			if("a taur with a leg augment")
				TEST_ASSERT(got_parts[FEATURE_TAUR], "[fixture_name] must be a taur")
				TEST_ASSERT_NOTEQUAL(got_limbs[BODY_ZONE_L_LEG], "[leg_augment.path]", "[fixture_name] must have its leg augment refused")
			if("a knot owner")
				TEST_ASSERT(got["knot"], "[fixture_name] must be able to knot")
			if("a penis in taur mode")
				TEST_ASSERT_EQUAL(got["penis_taur_mode"], TRUE, "[fixture_name] must have taur mode on")
			if("a penis with a sheath")
				TEST_ASSERT_EQUAL(got["penis_sheath"], "Sheath", "[fixture_name] must have the sheath")
		TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, json_decode(written_text))), written_text, "[fixture_name]: a second load and save must change nothing")
	// The menu keeps answering by the page; what a character gets does not.
	load_and_save(preferences, json_decode(taur_text))
	var/datum/preference/choiced/mutant_choice/taur/taur_choice = GLOB.preference_entries[/datum/preference/choiced/mutant_choice/taur]
	var/window = preferences.current_window
	for(var/allowed in list(FALSE, TRUE))
		preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = allowed
		preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
		TEST_ASSERT(taur_choice.is_accessible(preferences), "On the character page the taur choice must be accessible [allowed ? "with" : "without"] mismatched parts")
		TEST_ASSERT(taur_choice.is_applicable(preferences), "With the character page open the taur choice must apply [allowed ? "with" : "without"] mismatched parts")
		preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
		TEST_ASSERT_EQUAL(!!taur_choice.is_accessible(preferences), allowed, "On any other page the taur choice must be accessible only with mismatched parts")
		TEST_ASSERT(taur_choice.is_applicable(preferences), "With another page open the taur choice must apply [allowed ? "with" : "without"] mismatched parts")
	preferences.current_window = window

/// The eight marking preferences step 6 deleted drew nothing on upstream Nova or on any Meridian, so a save from before version
/// 22 loses their keys and nothing takes their place: a moth save with a coloured or a white marking or its toggle off, and a
/// lizard save with a belly marking, come out without the keys, their markings and look as they were. A save without them keeps
/// every byte but its version.
/datum/unit_test/body_marking_content/legacy_keys

/datum/unit_test/body_marking_content/legacy_keys/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/list/legacy_keys = list("feature_body_markings", "body_markings_color", "body_markings_emissive", "body_markings_toggle", "feature_moth_markings", "moth_markings_color", "moth_markings_emissive", "moth_markings_toggle")
	var/markings_text = "{\"chest\":{\"Reddish\":\[\"#ffffff\",0]},\"l_leg\":{\"Bovine\":\[\"#111111\",1]}}"
	var/list/cases = list(
		list("species" = SPECIES_MOTH, "moth_markings_toggle" = TRUE, "feature_moth_markings" = "Reddish", "moth_markings_color" = list("#aa2200", "#00aa22", "#2200aa"), "moth_markings_emissive" = list(0, 0, 0)),
		list("species" = SPECIES_MOTH, "moth_markings_toggle" = TRUE, "feature_moth_markings" = "Moon Fly", "moth_markings_color" = list("#ffffff", "#ffffff", "#ffffff"), "moth_markings_emissive" = list(1, 0, 0)),
		list("species" = SPECIES_MOTH, "moth_markings_toggle" = FALSE, "feature_moth_markings" = "Dipped", "moth_markings_color" = list("#ffffff", "#ffffff", "#ffffff"), "moth_markings_emissive" = list(0, 0, 0)),
		list("species" = SPECIES_LIZARD, "body_markings_toggle" = TRUE, "feature_body_markings" = "Light Belly", "body_markings_color" = list("#aa2200", "#00aa22", "#2200aa"), "body_markings_emissive" = list(0, 1, 0)),
	)
	for(var/list/legacy as anything in cases)
		var/list/slot = list("version" = 52, "modular_version" = 21, "tgui_prefs_migration" = TRUE, "allow_mismatched_parts_toggle" = TRUE, "body_markings" = json_decode(markings_text))
		var/list/legacy_copy = json_decode(json_encode(legacy))
		for(var/key in legacy_copy)
			slot[key] = legacy_copy[key]
		var/list/written = load_and_save(preferences, slot)
		TEST_ASSERT(written, "A version 21 character must load")
		for(var/key in legacy_keys)
			TEST_ASSERT(!(key in written), "[key] must be gone from [json_encode(legacy)]")
		TEST_ASSERT_EQUAL(json_encode(written["body_markings"]), markings_text, "The markings of [json_encode(legacy)] must load as saved")
		// The same character with the keys, as this server reads it without version 22: held, and read by nothing.
		var/list/kept = json_decode(json_encode(written))
		legacy_copy = json_decode(json_encode(legacy))
		for(var/key in legacy_copy)
			if(key in legacy_keys)
				kept[key] = legacy_copy[key]
		TEST_ASSERT_EQUAL(character_signature(preferences, written), character_signature(preferences, kept), "Without the keys, [json_encode(legacy)] must draw as it did with them")
		// Nothing left to drop: every byte but the version.
		var/first = json_encode(written)
		var/list/clean = json_decode(first)
		clean["modular_version"] = 21
		TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, clean)), first, "A save without the keys must keep every byte but its version")

/// Saves, character setup and custom styles name markings, and presets name sets, so one name must stand for one marking and
/// one set: the registries file each under its name (make_body_marking_references()), where a second of a name would silently
/// replace the first, for saves too. Nor is a retired name (GLOB.body_marking_renames) given to a marking again: saves and
/// custom styles still carrying it are read as the marking it became.
/datum/unit_test/body_marking_content/unique_names

/datum/unit_test/body_marking_content/unique_names/Run()
	// name -> every type of that name; the registries skip a type without one.
	var/list/markings_by_name = list()
	for(var/datum/body_marking/marking_type as anything in subtypesof(/datum/body_marking))
		var/marking_name = initial(marking_type.name)
		if(marking_name)
			LAZYADD(markings_by_name[marking_name], marking_type)
	report_shared(markings_by_name, "Body markings")
	var/list/sets_by_name = list()
	for(var/datum/body_marking_set/set_type as anything in subtypesof(/datum/body_marking_set))
		var/set_name = initial(set_type.name)
		if(set_name)
			LAZYADD(sets_by_name[set_name], set_type)
	report_shared(sets_by_name, "Body marking sets")
	for(var/retired in GLOB.body_marking_renames)
		var/datum/body_marking/wearer = GLOB.body_markings[retired]
		if(wearer)
			TEST_FAIL("[wearer.type] has the retired marking name \"[retired]\", which saves and custom styles read as [GLOB.body_marking_renames[retired]]")

/// Fails once for every name more than one type has. types_by_name: name -> the types of that name.
/datum/unit_test/body_marking_content/unique_names/proc/report_shared(list/types_by_name, kind)
	for(var/shared_name in types_by_name)
		var/list/named_types = types_by_name[shared_name]
		if(length(named_types) > 1)
			TEST_FAIL("[kind] [jointext(named_types, ", ")] share the name \"[shared_name]\": only the last of them is reachable by it")
