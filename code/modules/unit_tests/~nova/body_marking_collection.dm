/// Saved marking maps exactly as preferences.json holds them, written out by hand so no loader or serializer
/// change can regenerate them. Every zone wears the markings the markings baselines wear, each of which
/// claims all eight zones, in an order no zone list or marking list sorts into, with glow mixed.
/proc/body_marking_compat_full()
	var/list/zones = list(
		"\"r_hand\":{\"Guilmon Mark\":\[\"#33aa55\",1],\"Bovine\":\[\"#4488cc\",0],\"Dalmatian\":\[\"#cc4422\",0]}",
		"\"head\":{\"Bovine\":\[\"#112233\",1],\"Dalmatian\":\[\"#445566\",0],\"Guilmon Mark\":\[\"#778899\",1]}",
		"\"l_leg\":{\"Dalmatian\":\[\"#aabbcc\",0],\"Guilmon Mark\":\[\"#ddeeff\",0],\"Bovine\":\[\"#000000\",1]}",
		"\"chest\":{\"Bovine\":\[\"#4488cc\",0],\"Dalmatian\":\[\"#cc4422\",1],\"Guilmon Mark\":\[\"#33aa55\",0]}",
		"\"r_arm\":{\"Guilmon Mark\":\[\"#123456\",0],\"Dalmatian\":\[\"#654321\",1],\"Bovine\":\[\"#abcdef\",1]}",
		"\"l_hand\":{\"Dalmatian\":\[\"#fedcba\",1],\"Bovine\":\[\"#0f0f0f\",0],\"Guilmon Mark\":\[\"#f0f0f0\",1]}",
		"\"r_leg\":{\"Bovine\":\[\"#010203\",0],\"Guilmon Mark\":\[\"#040506\",1],\"Dalmatian\":\[\"#070809\",0]}",
		"\"l_arm\":{\"Guilmon Mark\":\[\"#a1b2c3\",1],\"Bovine\":\[\"#d4e5f6\",0],\"Dalmatian\":\[\"#0a0b0c\",1]}",
	)
	return "{[jointext(zones, ",")]}"

/// Loads a saved marking map the way a character load does and writes it back the way a save does.
/proc/body_marking_compat_round_trip(json)
	var/datum/body_marking_collection/loaded = body_marking_collection_from_list(json_decode(json))
	return json_encode(loaded.serialize())

/// Saved markings load and write back byte for byte; legacy and invalid content is repaired the documented way.
/datum/unit_test/body_marking_save_round_trip

/datum/unit_test/body_marking_save_round_trip/Run()
	TEST_ASSERT(!GLOB.body_markings["Not A Marking"], "The fixture needs a marking name nothing uses")
	var/full = body_marking_compat_full()
	// saved -> what it must write back
	var/list/cases = list(
		"[full]" = full,
		"\[]" = "\[]",
		"{}" = "\[]",
		"{\"chest\":{\"Bovine\":\[\"#4488cc\",0]},\"l_arm\":\[],\"head\":{\"Dalmatian\":\[\"#cc4422\",1]}}" = "{\"chest\":{\"Bovine\":\[\"#4488cc\",0]},\"l_arm\":\[],\"head\":{\"Dalmatian\":\[\"#cc4422\",1]}}",
		"{\"chest\":{\"Bovine\":\"#4488cc\"}}" = "{\"chest\":{\"Bovine\":\[\"#4488cc\",0]}}",
		"{\"chest\":{\"Bovine\":null}}" = "{\"chest\":{\"Bovine\":\[\"#000000\",0]}}",
		"{\"l_arm\":{\"Dalmatian\":\[\"#CC4422\",1],\"Bovine\":\"#4488CC\"}}" = "{\"l_arm\":{\"Dalmatian\":\[\"#cc4422\",1],\"Bovine\":\[\"#4488cc\",0]}}",
		"{\"chest\":{\"Bovine\":\[\"#4488cc\"],\"Dalmatian\":\[\"#cc4422\",1,\"extra\"]}}" = "{\"chest\":{\"Bovine\":\[\"#4488cc\",0],\"Dalmatian\":\[\"#cc4422\",1]}}",
		"{\"head\":{\"Bovine\":\[\"#4488cc\",0],\"Not A Marking\":\[\"#ffffff\",1],\"Dalmatian\":\[\"#cc4422\",1]},\"chest\":{\"Not A Marking\":\[\"#ffffff\",0]}}" = "{\"head\":{\"Bovine\":\[\"#4488cc\",0],\"Dalmatian\":\[\"#cc4422\",1]},\"chest\":\[]}",
		"{\"tail\":{\"Bovine\":\[\"#4488cc\",0]},\"chest\":{\"Bovine\":\[\"#4488cc\",1]},\"l_arm\":\"#ffffff\"}" = "{\"chest\":{\"Bovine\":\[\"#4488cc\",1]}}",
	)
	for(var/saved, expected in cases)
		var/written = body_marking_compat_round_trip(saved)
		TEST_ASSERT_EQUAL(written, expected, "Loading and saving [saved] gave the wrong bytes")
		TEST_ASSERT_EQUAL(body_marking_compat_round_trip(written), written, "A second load and save of [written] must change nothing")
	TEST_ASSERT_EQUAL(json_encode(body_marking_collection_from_list(null).serialize()), "\[]", "A save without markings must load as none")

	// The real save boundary: save_character() writes the collection into the savefile tree.
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.body_markings = body_marking_collection_from_list(json_decode(full))
	preferences.save_character()
	var/list/slot = preferences.savefile.get_entry("character[preferences.default_slot]")
	TEST_ASSERT_EQUAL(json_encode(slot["body_markings"]), full, "save_character() must write the markings byte for byte")
	// The tree holds a snapshot, so a live edit reaches it only through the next save.
	preferences.body_markings.find_entry(BODY_ZONE_HEAD, "Bovine").set_color("#ffffff")
	TEST_ASSERT_EQUAL(json_encode(slot["body_markings"]), full, "The saved tree must not follow the live markings")
	preferences.body_markings = new /datum/body_marking_collection
	preferences.save_character()
	slot = preferences.savefile.get_entry("character[preferences.default_slot]")
	TEST_ASSERT_EQUAL(json_encode(slot["body_markings"]), "\[]", "A character without markings must save them as an empty list")

/// A zone wears each marking once, whatever adds it.
/datum/unit_test/body_marking_unique_per_zone

/datum/unit_test/body_marking_unique_per_zone/Run()
	var/datum/body_marking/bovine = GLOB.body_markings["Bovine"]
	var/datum/body_marking/dalmatian = GLOB.body_markings["Dalmatian"]
	var/datum/body_marking/guilmon = GLOB.body_markings["Guilmon Mark"]
	TEST_ASSERT(bovine && dalmatian && guilmon, "The fixture markings must exist")
	var/datum/body_marking_collection/markings = new
	var/datum/body_marking_entry/first = new(bovine, BODY_ZONE_L_ARM, "#4488cc", FALSE)
	TEST_ASSERT(markings.add_entry(first), "A zone must take a marking it doesn't wear")
	TEST_ASSERT(!markings.add_entry(new /datum/body_marking_entry(bovine, BODY_ZONE_L_ARM, "#cc4422", TRUE)), "A zone must refuse a marking it already wears")
	TEST_ASSERT(!markings.add_entry(first), "An entry must not be added twice")
	TEST_ASSERT(markings.add_entry(new /datum/body_marking_entry(bovine, BODY_ZONE_R_ARM, "#cc4422", TRUE)), "Another zone may wear the same marking")
	TEST_ASSERT(!markings.add_entry(new /datum/body_marking_entry(null, BODY_ZONE_L_ARM, "#cc4422", TRUE)), "An entry without a marking must be refused")
	TEST_ASSERT(!markings.add_entry(new /datum/body_marking_entry(dalmatian, "tail", "#cc4422", TRUE)), "An entry off the marking zones must be refused")
	TEST_ASSERT_EQUAL(json_encode(markings.serialize()), "{\"l_arm\":{\"Bovine\":\[\"#4488cc\",0]},\"r_arm\":{\"Bovine\":\[\"#cc4422\",1]}}", "Refused entries must leave nothing behind")
	var/datum/body_marking_entry/second = new(dalmatian, BODY_ZONE_L_ARM, "#cc4422", TRUE)
	TEST_ASSERT(markings.add_entry(second), "A zone must take a second marking")
	TEST_ASSERT(!markings.replace_entry(second, new /datum/body_marking_entry(bovine, BODY_ZONE_L_ARM, "#ffffff", FALSE)), "Renaming a row to a marking another row wears must be refused")
	TEST_ASSERT(!markings.replace_entry(first, new /datum/body_marking_entry(guilmon, BODY_ZONE_R_ARM, "#ffffff", FALSE)), "A replacement must stay on its zone")
	TEST_ASSERT(markings.replace_entry(second, new /datum/body_marking_entry(dalmatian, BODY_ZONE_L_ARM, "#ffffff", FALSE)), "A row may be replaced by its own marking")
	markings.set_zone_entries(BODY_ZONE_CHEST, list(new /datum/body_marking_entry(guilmon, BODY_ZONE_CHEST, "#111111", FALSE), new /datum/body_marking_entry(guilmon, BODY_ZONE_CHEST, "#222222", TRUE)))
	TEST_ASSERT_EQUAL(json_encode(markings.serialize()[BODY_ZONE_CHEST]), "{\"Guilmon Mark\":\[\"#111111\",0]}", "Setting a zone must keep only the first of a repeated marking")
	TEST_ASSERT_EQUAL(length(body_marking_entries_from_list(BODY_ZONE_CHEST, list("Bovine", "Bovine"))), 1, "A repeated name in a saved zone must load once")

/// Zones and the markings on them keep the order they were added in, which the "[zone]_[n]" row ids depend on.
/datum/unit_test/body_marking_order

/datum/unit_test/body_marking_order/Run()
	var/list/names = markings_baseline_marking_names()
	var/fourth
	for(var/name in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM])
		if(!(name in names))
			fourth = name
			break
	TEST_ASSERT(fourth, "The fixture needs a fourth left arm marking")
	var/datum/body_marking_collection/markings = new
	for(var/name in names)
		markings.add_entry(new /datum/body_marking_entry(GLOB.body_markings[name], BODY_ZONE_L_ARM, "#4488cc", FALSE))
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(names), "Markings must stay in the order they were added")
	markings.remove_entry(markings.find_entry(BODY_ZONE_L_ARM, names[2]))
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(names[1], names[3])), "Removing a marking must keep the rest in order")
	markings.add_entry(new /datum/body_marking_entry(GLOB.body_markings[names[2]], BODY_ZONE_L_ARM, "#4488cc", FALSE))
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(names[1], names[3], names[2])), "A marking added again must go last")
	var/datum/body_marking_entry/renamed = markings.find_entry(BODY_ZONE_L_ARM, names[1])
	markings.replace_entry(renamed, new /datum/body_marking_entry(GLOB.body_markings[fourth], BODY_ZONE_L_ARM, renamed.get_color(), renamed.get_emissive()))
	TEST_ASSERT_EQUAL(json_encode(markings.marking_names(BODY_ZONE_L_ARM)), json_encode(list(fourth, names[3], names[2])), "A renamed marking must keep its place")
	// A zone keeps the place it first took, emptied or not, as a nested map kept its key.
	markings.add_entry(new /datum/body_marking_entry(GLOB.body_markings[names[1]], BODY_ZONE_HEAD, "#112233", TRUE))
	markings.set_zone_entries(BODY_ZONE_L_ARM, null)
	markings.add_entry(new /datum/body_marking_entry(GLOB.body_markings[names[1]], BODY_ZONE_CHEST, "#445566", FALSE))
	markings.add_entry(new /datum/body_marking_entry(GLOB.body_markings[names[2]], BODY_ZONE_L_ARM, "#778899", TRUE))
	var/list/expected_save = list(
		BODY_ZONE_L_ARM = list("[names[2]]" = list("#778899", 1)),
		BODY_ZONE_HEAD = list("[names[1]]" = list("#112233", 1)),
		BODY_ZONE_CHEST = list("[names[1]]" = list("#445566", 0)),
	)
	TEST_ASSERT_EQUAL(json_encode(markings.serialize()), json_encode(expected_save), "Zones must keep the order they first appeared in")
	// A species change's override keeps its own zones' places and takes the current DNA's zone contents.
	var/datum/body_marking_collection/override = body_marking_collection_from_list(json_decode("{\"chest\":{\"Bovine\":\[\"#111111\",0]},\"head\":{\"Dalmatian\":\[\"#222222\",1]}}"))
	var/datum/body_marking_collection/current = body_marking_collection_from_list(json_decode("{\"l_arm\":{\"Bovine\":\[\"#333333\",0]},\"chest\":{\"Guilmon Mark\":\[\"#444444\",1]}}"))
	override.overwrite_zones_from(current)
	TEST_ASSERT_EQUAL(json_encode(override.serialize()), "{\"chest\":{\"Guilmon Mark\":\[\"#444444\",1]},\"head\":{\"Dalmatian\":\[\"#222222\",1]},\"l_arm\":{\"Bovine\":\[\"#333333\",0]}}", "Overwriting zones must keep their places and append new ones, as assigning nested zone maps did")
	TEST_ASSERT(override.find_entry(BODY_ZONE_L_ARM, "Bovine") == current.find_entry(BODY_ZONE_L_ARM, "Bovine"), "Overwritten zones must hold the current entries, as they held the current zone maps")

	// The prefs menu's rows: ids count each zone's markings from 1 in order, and each row action finds its marking by them.
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
	// A row below is lit, which the character's allow_emissives preference gates.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	TEST_ASSERT(middleware, "The fixture needs the limbs and markings middleware")
	preferences.body_markings = body_marking_collection_from_list(json_decode("{\"chest\":{\"Bovine\":\[\"#4488CC\",0]},\"l_leg\":\[],\"l_arm\":{\"Bovine\":\[\"#112233\",0],\"Dalmatian\":\[\"#445566\",1],\"Guilmon Mark\":\[\"#778899\",0]}}"))
	var/list/expected_rows = list(
		BODY_ZONE_CHEST = list(list("name" = "Bovine", "color" = "#4488cc", "marking_id" = "chest_1", "emissive" = 0)),
		BODY_ZONE_L_ARM = list(
			list("name" = "Bovine", "color" = "#112233", "marking_id" = "l_arm_1", "emissive" = 0),
			list("name" = "Dalmatian", "color" = "#445566", "marking_id" = "l_arm_2", "emissive" = 1),
			list("name" = "Guilmon Mark", "color" = "#778899", "marking_id" = "l_arm_3", "emissive" = 0),
		),
	)
	TEST_ASSERT_EQUAL(json_encode(middleware.get_ui_data(mock_client.mob)["markings"]), json_encode(expected_rows), "The prefs menu must list each zone with markings, in order, with positional ids")
	middleware.remove_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "l_arm_2"), mock_client.mob)
	middleware.change_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "l_arm_1", "marking_name" = fourth), mock_client.mob)
	middleware.change_emissive_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "l_arm_2", "emissive" = 0), mock_client.mob)
	expected_rows[BODY_ZONE_L_ARM] = list(
		list("name" = fourth, "color" = "#112233", "marking_id" = "l_arm_1", "emissive" = 0),
		list("name" = "Guilmon Mark", "color" = "#778899", "marking_id" = "l_arm_2", "emissive" = 1),
	)
	TEST_ASSERT_EQUAL(json_encode(middleware.get_ui_data(mock_client.mob)["markings"]), json_encode(expected_rows), "Row actions must act on the row their id names and keep the rest in order")
	middleware.remove_marking(list("bodypart_slot" = BODY_ZONE_CHEST, "marking_id" = "chest_1"), mock_client.mob)
	expected_save = list(
		BODY_ZONE_CHEST = list(),
		BODY_ZONE_L_LEG = list(),
		BODY_ZONE_L_ARM = list("[fourth]" = list("#112233", 0), "Guilmon Mark" = list("#778899", 1)),
	)
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), json_encode(expected_save), "An emptied zone must stay saved in its place")
	preferences.body_markings = new /datum/body_marking_collection
	TEST_ASSERT(isnull(middleware.get_ui_data(mock_client.mob)["markings"]), "A character without zones must send no markings")
	preferences.body_markings.add_zone(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(json_encode(middleware.get_ui_data(mock_client.mob)["markings"]), "\[]", "A character with only emptied zones must send an empty list")

/// copy() owns what it copies, a plain assignment is the same collection, and shallow_copy() shares entries as the nested lists' Copy() shared tuples.
/datum/unit_test/body_marking_copies

/datum/unit_test/body_marking_copies/Run()
	var/full = body_marking_compat_full()
	var/datum/body_marking_collection/original = body_marking_collection_from_list(json_decode(full))
	var/datum/body_marking_collection/deep = original.copy()
	TEST_ASSERT_EQUAL(json_encode(deep.serialize()), full, "A copy must hold the same markings in the same order")
	var/datum/body_marking_entry/original_entry = original.find_entry(BODY_ZONE_CHEST, "Dalmatian")
	var/datum/body_marking_entry/deep_entry = deep.find_entry(BODY_ZONE_CHEST, "Dalmatian")
	TEST_ASSERT(deep_entry && deep_entry != original_entry, "A copy must hold new entries")
	deep_entry.set_color("#ffffff")
	deep_entry.set_emissive(FALSE)
	deep.remove_entry(deep.find_entry(BODY_ZONE_HEAD, "Bovine"))
	TEST_ASSERT_EQUAL(json_encode(original.serialize()), full, "Changing a copy must leave the original alone")

	var/datum/body_marking_collection/alias = original
	alias.remove_entry(alias.find_entry(BODY_ZONE_HEAD, "Bovine"))
	TEST_ASSERT(!original.find_entry(BODY_ZONE_HEAD, "Bovine"), "A plain assignment must be the same collection")

	var/datum/body_marking_collection/shallow = original.shallow_copy()
	TEST_ASSERT_EQUAL(json_encode(shallow.serialize()), json_encode(original.serialize()), "A shallow copy must hold the same markings")
	TEST_ASSERT(shallow != original && shallow.find_entry(BODY_ZONE_CHEST, "Dalmatian") == original_entry, "A shallow copy must be its own collection of the same entries")
	original_entry.set_color("#010101")
	TEST_ASSERT_EQUAL(shallow.find_entry(BODY_ZONE_CHEST, "Dalmatian").get_color(), "#010101", "A recoloured shared entry must change in both, as a shared tuple did")
	shallow.remove_entry(shallow.find_entry(BODY_ZONE_CHEST, "Bovine"))
	TEST_ASSERT(original.find_entry(BODY_ZONE_CHEST, "Bovine"), "Removing a row from a shallow copy must leave the original's rows alone")

	// A body's limbs hold the DNA's own zone lists, which are never edited in place: the snapshot a detached limb goes on drawing.
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.body_markings = body_marking_collection_from_list(json_decode("{\"l_arm\":{\"Bovine\":\[\"#4488cc\",0]},\"chest\":\[]}"))
	body.update_body_parts(update_limb_data = TRUE)
	var/list/dna_view = body.dna.body_markings.entries_for_zone(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(islist(arm.markings) && arm.markings == dna_view && length(arm.markings) == 1, "A limb must hold the DNA's own list of its zone's entries")
	TEST_ASSERT(findtext(arm.get_cache_key(), "l_arm=Bovine_#4488cc_0;;alpha=255"), "The limb icon key must name each marking with its colour and glow, and the markings' alpha")
	var/obj/item/bodypart/chest = body.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT(body.dna.body_markings.has_zone(BODY_ZONE_CHEST) && isnull(chest.markings), "An emptied zone stays present but must give its limb no list")
	var/obj/item/bodypart/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(isnull(head.markings), "A zone the DNA lacks must give its limb no list")
	// Copied DNA gets a collection of its own holding the same entries, as the nested lists' Copy() gave.
	var/datum/dna/copied = allocate(/datum/dna)
	body.dna.copy_dna(copied)
	TEST_ASSERT(copied.body_markings != body.dna.body_markings && copied.body_markings.find_entry(BODY_ZONE_L_ARM, "Bovine") == dna_view[1], "Copied DNA must share entries in a collection of its own")
