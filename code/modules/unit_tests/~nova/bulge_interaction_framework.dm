/// Neutral fixtures exercise real JSON loaders/save and selection; no live data is read or replaced.
/datum/unit_test/portal_test/bulge_interaction_framework
	var/list/paths = list()
	var/list/saved_registry
	var/list/temporary_registry

/datum/unit_test/portal_test/bulge_interaction_framework/Destroy()
	if(saved_registry)
		GLOB.interaction_instances = saved_registry
		saved_registry = null
	if(temporary_registry)
		for(var/key, interaction in temporary_registry)
			qdel(interaction)
		temporary_registry = null
	for(var/path in paths)
		fdel(path)
	return ..()

/datum/unit_test/portal_test/bulge_interaction_framework/proc/fixture_path(label)
	var/path = "data/wp7_unit_[REF(src)]_[label].json"
	paths += path
	return path

/// Restores the real registry before assertions; Destroy also restores it after an unexpected runtime.
/datum/unit_test/portal_test/bulge_interaction_framework/proc/load_master_fixture(path)
	saved_registry = GLOB.interaction_instances
	temporary_registry = list()
	GLOB.interaction_instances = temporary_registry
	populate_interaction_jsons_master(path)
	GLOB.interaction_instances = saved_registry
	saved_registry = null
	var/list/result = temporary_registry
	for(var/key, interaction in result)
		allocated += interaction
	temporary_registry = null
	return result

/datum/unit_test/portal_test/bulge_interaction_framework/Run()
	// File literals make the future UNIT_TESTS build verify each approved new sound resource.
	var/list/sounds = list(
		'sound/effects/rustle/rustle1.ogg',
		'sound/effects/rustle/rustle2.ogg',
		'sound/effects/rustle/rustle3.ogg',
		'modular_nova/modules/modular_items/lewd_items/sounds/bj1.ogg',
		'modular_nova/modules/modular_items/lewd_items/sounds/bj5.ogg',
		'sound/effects/emotes/kiss.ogg',
	)
	for(var/path in sounds)
		TEST_ASSERT(fcopy(path, fixture_path("sound_[length(paths)]")), "Approved compiled sound resource could not be read.")
	var/list/fixture = list(
		"name" = "WP7 neutral fixture",
		"description" = "A neutral round-trip fixture.",
		"usage" = INTERACTION_OTHER,
		"category" = "Sex (Armpit)",
		"message" = list("observer base"),
		"user_messages" = list("user base"),
		"target_messages" = list("target base"),
		"message_pit_hair" = list("observer hair"),
		"user_messages_pit_hair" = list("user hair"),
		"target_messages_pit_hair" = list("target hair"),
		"name_pecs" = "neutral chest",
		"name_nippleless" = "neutral alternate chest",
		"message_nippleless" = list("observer chest"),
		"user_messages_nippleless" = list("user chest"),
		"target_messages_nippleless" = list("target chest"),
		"interaction_requires" = list(INTERACTION_REQUIRE_TARGET_ARM),
		"lewd" = FALSE,
	)
	var/single_path = fixture_path("single")
	WRITE_FILE(file(single_path), json_encode(fixture))
	var/datum/interaction/single = allocate(/datum/interaction)
	TEST_ASSERT(single.load_from_json(single_path), "Real single-file JSON load failed.")
	var/master_path = fixture_path("master")
	WRITE_FILE(file(master_path), json_encode(list("WP7 neutral fixture" = fixture)))
	var/list/master = load_master_fixture(master_path)
	TEST_ASSERT_EQUAL(length(master), 1, "Master loader did not produce exactly one fixture.")
	var/datum/interaction/from_master = master["WP7 neutral fixture"]
	TEST_ASSERT_NOTNULL(from_master, "Master fixture was not indexed by its name.")
	TEST_ASSERT_EQUAL(from_master.name, single.name, "Master load lost interaction identity (inherited baseline defect).")
	TEST_ASSERT_EQUAL(from_master.description, single.description, "Master load lost description (inherited baseline defect).")
	for(var/field in list("message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair", "message_nippleless", "user_messages_nippleless", "target_messages_nippleless"))
		TEST_ASSERT_EQUAL(json_encode(from_master.vars[field]), json_encode(single.vars[field]), "Master/single list mismatch for [field].")
	var/saved_path = fixture_path("saved")
	TEST_ASSERT(from_master.json_save(saved_path), "Real JSON save failed.")
	var/datum/interaction/reloaded = allocate(/datum/interaction)
	TEST_ASSERT(reloaded.load_from_json(saved_path), "Saved master fixture did not reload.")
	for(var/field in list("name", "description", "name_pecs", "name_nippleless", "category", "message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair", "message_nippleless", "user_messages_nippleless", "target_messages_nippleless"))
		TEST_ASSERT_EQUAL(json_encode(reloaded.vars[field]), json_encode(single.vars[field]), "Save round trip changed [field].")

	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	var/list/selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "observer base", "Absent physical hair did not use base text.")
	target.set_body_hair(FEATURE_PITS, "Natural")
	TEST_ASSERT(istype(target.get_organ_slot(ORGAN_SLOT_EXTERNAL_PITS), /obj/item/organ/body_hair/pits), "Fixture did not grow physical pit hair.")
	selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "observer hair", "Physical target hair did not choose optional text.")
	selected = single.texts_for(single.user_messages, null, user, target, single.user_messages_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "user hair", "User channel chose the wrong optional list.")
	selected = single.texts_for(single.target_messages, null, user, target, list())
	TEST_ASSERT_EQUAL(selected[1], "target base", "Empty channel failed to fall back independently.")
	selected = single.texts_for(single.target_messages, null, user, target, single.target_messages_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "target hair", "Target channel chose the wrong optional list.")
	selected = single.texts_for(single.message, null, target, user, single.message_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "observer base", "User hair incorrectly selected target-hair text.")

	if(!CONFIG_GET(flag/disable_erp_preferences) && !CONFIG_GET(flag/disable_lewd_items))
		var/obj/item/organ/genital/breasts/chest = allocate(/obj/item/organ/genital/breasts)
		chest.pecs = TRUE
		chest.nippleless = TRUE
		chest.Insert(target, special = TRUE)
		single.target_required_parts = list(ORGAN_SLOT_BREASTS)
		selected = single.texts_for(single.message, single.message_nippleless, user, target, single.message_pit_hair)
		TEST_ASSERT_EQUAL(selected[1], "observer chest", "Hair overrode existing nippleless precedence.")
		single.target_required_parts = list()
	else
		TEST_NOTICE(src, "Chest precedence fixture unavailable while genital config is disabled; package acceptance requires an enabled run.")
	target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	target.dna.mutant_bodyparts[FEATURE_PITS] = build_mutant_part("Natural", list(BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR))
	selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "observer base", "DNA-only hair incorrectly selected physical-hair text.")
	single.load_pit_hair_text(list("message_pit_hair" = "invalid scalar"))
	TEST_ASSERT_NULL(single.message_pit_hair, "Invalid optional text did not normalize to null.")
	TEST_ASSERT_NULL(single.user_messages_pit_hair, "Reload retained a missing optional channel.")

	// Feature values are literal text, never recursively processed as role/chest/scent templates.
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar %USER% %TARGET_SCENT%"
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target), "cedar %USER% %TARGET_SCENT%", "Scent text was recursively expanded.")
	TEST_ASSERT_EQUAL(single.format_message_for("%target_scent%", user, target), "%target_scent%", "Scent token incorrectly matched different case.")
	TEST_ASSERT_EQUAL(single.format_message_for("neutral", user, target), "neutral", "A token-free message changed.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target, target_anonymous = TRUE), "their scent", "Anonymous target disclosed a custom scent.")
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = null
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target), "their scent", "Missing scent did not use a neutral fallback.")
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar"
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_PRONOUN_THEIR% %TARGET_SCENT%", user, target, recipient = target), "your cedar", "Recipient grammar or final scent expansion changed.")

/// Existing requirement plumbing: a bare part on one participant and a covered part on the other.
/datum/unit_test/portal_test/wp7_mixed_requirements/Run()
	if(CONFIG_GET(flag/disable_erp_preferences) || CONFIG_GET(flag/disable_lewd_items))
		TEST_NOTICE(src, "Mixed coverage needs enabled genital configuration; not acceptance evidence when skipped.")
		return
	var/mob/living/carbon/human/consistent/bare = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/covered = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/genital/penis/bare_part = configure_test_penis(bare)
	var/obj/item/organ/genital/penis/covered_part = configure_test_penis(covered)
	TEST_ASSERT_NOTNULL(bare_part, "Bare fixture missing anatomy.")
	TEST_ASSERT_NOTNULL(covered_part, "Covered fixture missing anatomy.")
	bare_part.apply_arousal_label("Very aroused")
	covered_part.apply_arousal_label("Very aroused")
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	TEST_ASSERT(covered.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING), "Could not equip fixture cover.")
	var/datum/interaction/pair = allocate(/datum/interaction)
	pair.user_required_parts = list(ORGAN_SLOT_PENIS)
	pair.interaction_requires = list(INTERACTION_REQUIRE_TARGET_BULGE)
	TEST_ASSERT(pair.allow_act(bare, covered), "Bare-user/covered-target requirements rejected the valid fixture.")
	TEST_ASSERT(!pair.allow_act(covered, bare), "Mixed requirements checked the wrong participant.")
	pair.user_required_parts = list()
	pair.target_required_parts = list(ORGAN_SLOT_PENIS)
	pair.interaction_requires = list(INTERACTION_REQUIRE_SELF_BULGE)
	TEST_ASSERT(pair.allow_act(covered, bare), "Covered-user/bare-target mirror rejected the valid fixture.")
	var/obj/item/blocker = allocate(/obj/item)
	bare_part.blocked_by = blocker
	TEST_ASSERT(!pair.allow_act(covered, bare), "Blocked anatomy bypassed a bare-part requirement.")
	bare_part.blocked_by = null
	pair.interaction_requires = list(INTERACTION_REQUIRE_SELF_ARM)
	TEST_ASSERT(pair.allow_act(covered, bare), "Existing arm plus exposed target-part combination failed.")

/// Opt-in corpus gate: harness copies only staged/ into this fresh lab runtime directory.
/datum/unit_test/portal_test/bulge_interaction_framework/wp7_staged/Run()
	if(world.params["wp7_json"] != "owned-lab")
		TEST_NOTICE(src, "WP7 staged JSON gate pending: run with wp7_json=owned-lab and reviewed files in data/wp7_candidate_inputs.")
		return
	var/list/files = pathwalk("data/wp7_candidate_inputs/", ".json")
	TEST_ASSERT_EQUAL(length(files), 18, "WP7 staged corpus must contain exactly the eighteen authorized entries.")
	var/list/master_data = list()
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar"
	for(var/path in files)
		var/list/json = json_load(file(path))
		var/datum/interaction/single = allocate(/datum/interaction)
		TEST_ASSERT(single.load_from_json(path), "Staged JSON failed the real single loader: [path].")
		TEST_ASSERT_NULL(master_data[single.name], "Duplicate staged interaction name.")
		master_data[single.name] = json
		for(var/field in list("message", "user_messages", "target_messages", "message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair"))
			var/list/messages = single.vars[field]
			for(var/template in messages)
				var/expanded = single.format_message_for(template, user, target)
				TEST_ASSERT(!findtextEx(expanded, "%USER") && !findtextEx(expanded, "%TARGET"), "Staged message retained an unresolved role token.")
		var/saved_path = fixture_path("staged_[length(master_data)]")
		TEST_ASSERT(single.json_save(saved_path), "Staged JSON did not save.")
		var/datum/interaction/reloaded = allocate(/datum/interaction)
		TEST_ASSERT(reloaded.load_from_json(saved_path), "Saved staged JSON did not reload.")
		for(var/field in list("name", "description", "category", "message", "user_messages", "target_messages", "message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair", "interaction_requires", "user_required_parts", "target_required_parts", "sound_use", "sound_possible", "sound_range", "user_arousal", "user_pleasure", "target_arousal", "target_pleasure"))
			TEST_ASSERT_EQUAL(json_encode(reloaded.vars[field]), json_encode(single.vars[field]), "Staged save round trip changed [field].")
	var/master_path = fixture_path("staged_master")
	WRITE_FILE(file(master_path), json_encode(master_data))
	var/list/loaded_master = load_master_fixture(master_path)
	TEST_ASSERT_EQUAL(length(loaded_master), 18, "Staged master JSON did not load all eighteen entries.")
	for(var/name, source_data in master_data)
		var/list/json = source_data
		var/datum/interaction/loaded = loaded_master[name]
		TEST_ASSERT_EQUAL(loaded.name, name, "Staged master lost interaction identity.")
		TEST_ASSERT_EQUAL(loaded.description, sanitize_text(json["description"]), "Staged master lost its supplied description.")
