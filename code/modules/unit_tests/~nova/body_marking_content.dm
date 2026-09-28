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

/// A taur body refuses leg augments only while the taur choice is accessible, and is_accessible() answers by the page the player
/// last opened in setup, which is still the page when they spawn: off the character page the choice takes mismatched parts,
/// whatever the species offers. So the check asks on both pages, and a save from before version 22 of an anthromorph taur with a
/// leg augment and a marking of another species' set keeps mismatched parts off, and every byte but its version.
/datum/unit_test/body_marking_content/mismatched_markings_page

/datum/unit_test/body_marking_content/mismatched_markings_page/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/datum/body_marking/lights = GLOB.body_markings_by_type[/datum/body_marking/secondary/synthliz/lights]
	TEST_ASSERT(!lights.allows_species(SPECIES_MAMMAL), "The fixture needs a marking an anthromorph may not pick: Synth Lights is for synths")
	var/list/written = load_and_save(preferences, list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "species" = SPECIES_MAMMAL, "allow_mismatched_parts_toggle" = FALSE, "taur_toggle" = TRUE, "feature_taur" = "Bunny", "augments" = list(AUGMENT_SLOT_L_LEG = "[/datum/augment_item/limb/l_leg/digi_prosthetic]"), "body_markings" = list(BODY_ZONE_CHEST = list("Synth Lights" = list("#aa0000", 0)))))
	TEST_ASSERT(written, "A version 22 anthromorph must load")
	TEST_ASSERT(length(preferences.augments), "The fixture must keep its leg augment")
	var/written_text = json_encode(written)
	var/list/stale = json_decode(written_text)
	stale["modular_version"] = 21
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, stale)), written_text, "A taur with a leg augment must keep every byte but its version")
	TEST_ASSERT(!preferences.mismatched_parts_change_nothing(), "The taur choice must count as a change off the character page")
	// Why: on the character page the species' own taur feature answers either way, on any other page mismatched parts decide.
	var/datum/preference/choiced/mutant_choice/taur/taur_choice = GLOB.preference_entries[/datum/preference/choiced/mutant_choice/taur]
	for(var/allowed in list(FALSE, TRUE))
		preferences.value_cache[/datum/preference/toggle/allow_mismatched_parts] = allowed
		preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES
		TEST_ASSERT(taur_choice.is_accessible(preferences), "On the character page the taur choice must be accessible [allowed ? "with" : "without"] mismatched parts")
		preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
		TEST_ASSERT_EQUAL(!!taur_choice.is_accessible(preferences), allowed, "On any other page the taur choice must be accessible only with mismatched parts")
	preferences.current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES

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

/// The legacy export gives the loaded character as a save from before version 22: modular version 20 and Hands Feet on an arm
/// named Rat Paw again, every other byte as saving would write it, the live save untouched. Read back through this server's
/// loader it is the same character, byte for byte.
/datum/unit_test/body_marking_content/legacy_export

/datum/unit_test/body_marking_content/legacy_export/Run()
	var/datum/preferences/preferences = fixture_preferences()
	var/list/saved = load_and_save(preferences, list("version" = 52, "modular_version" = 22, "tgui_prefs_migration" = TRUE, "species" = SPECIES_MAMMAL, "allow_mismatched_parts_toggle" = TRUE, "body_markings" = list(BODY_ZONE_L_ARM = list("Hands Feet" = list("#aa0000", 1), "Bovine" = list("#111111", 0)), BODY_ZONE_PRECISE_L_HAND = list("Hands Feet" = list("#bb0000", 0)), BODY_ZONE_CHEST = list("Firewatch" = list("#ffffff", 0)))))
	TEST_ASSERT(saved, "The fixture character must load")
	var/saved_text = json_encode(saved)
	var/list/legacy = preferences.legacy_character_save()
	TEST_ASSERT_EQUAL(json_encode(preferences.savefile.get_entry("character[preferences.default_slot]")), saved_text, "Exporting must leave the live save alone")
	TEST_ASSERT_EQUAL(legacy["modular_version"], 20, "The export must be at version 20")
	TEST_ASSERT_EQUAL(json_encode(legacy["body_markings"]), "{\"l_arm\":{\"Rat Paw\":\[\"#aa0000\",1],\"Bovine\":\[\"#111111\",0]},\"l_hand\":{\"Hands Feet\":\[\"#bb0000\",0]},\"chest\":{\"Firewatch\":\[\"#ffffff\",0]}}", "Hands Feet on an arm, and only there, must be Rat Paw again")
	var/list/restored = json_decode(json_encode(legacy))
	restored["modular_version"] = 22
	restored["body_markings"] = saved["body_markings"]
	TEST_ASSERT_EQUAL(json_encode(restored), saved_text, "The export must differ from the save in its version and the arm's name alone")
	TEST_ASSERT_EQUAL(json_encode(load_and_save(preferences, legacy)), saved_text, "The export must load back through this server's loader as the character it came from")
