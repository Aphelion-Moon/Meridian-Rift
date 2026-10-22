/// A deterministic human the sweat hook reports as sweating, since nothing sets it in game yet.
/mob/living/carbon/human/consistent/sweaty_interaction_fixture/is_visibly_sweaty()
	return TRUE

/// A deterministic human whose bulge reports part of the penis showing, without arranging real organs and covers.
/mob/living/carbon/human/consistent/poking_interaction_fixture/bulge_pokes_out()
	return BULGE_POKES_PAST_CLOTH

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
	var/path = "data/bulge_interaction_unit_[REF(src)]_[label].json"
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
		"name" = "Neutral fixture",
		"description" = "A neutral round-trip fixture.",
		"usage" = INTERACTION_OTHER,
		"category" = "Sex (Armpit)",
		"message" = list("observer base"),
		"user_messages" = list("user base"),
		"target_messages" = list("target base"),
		"message_pit_hair" = list("observer hair"),
		"user_messages_pit_hair" = list("user hair"),
		"target_messages_pit_hair" = list("target hair"),
		"message_sweaty" = list("observer sweat"),
		"user_messages_sweaty" = list("user sweat"),
		"target_messages_sweaty" = list("target sweat"),
		"message_auto_emotes" = list("observer base" = "moan"),
		"message_pokes_out" = list("observer bare"),
		"user_messages_pokes_out" = list("user bare"),
		"target_messages_pokes_out" = list("target bare"),
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
	WRITE_FILE(file(master_path), json_encode(list("Neutral fixture" = fixture)))
	var/list/master = load_master_fixture(master_path)
	TEST_ASSERT_EQUAL(length(master), 1, "Master loader did not produce exactly one fixture.")
	var/datum/interaction/from_master = master["Neutral fixture"]
	TEST_ASSERT_NOTNULL(from_master, "Master fixture was not indexed by its name.")
	TEST_ASSERT_EQUAL(from_master.name, single.name, "Master load lost interaction identity (inherited baseline defect).")
	TEST_ASSERT_EQUAL(from_master.description, single.description, "Master load lost description (inherited baseline defect).")
	for(var/field in list("message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair", "message_sweaty", "user_messages_sweaty", "target_messages_sweaty", "message_auto_emotes", "message_pokes_out", "user_messages_pokes_out", "target_messages_pokes_out", "message_nippleless", "user_messages_nippleless", "target_messages_nippleless"))
		TEST_ASSERT_EQUAL(json_encode(from_master.vars[field]), json_encode(single.vars[field]), "Master/single list mismatch for [field].")
	var/saved_path = fixture_path("saved")
	TEST_ASSERT(from_master.json_save(saved_path), "Real JSON save failed.")
	var/datum/interaction/reloaded = allocate(/datum/interaction)
	TEST_ASSERT(reloaded.load_from_json(saved_path), "Saved master fixture did not reload.")
	for(var/field in list("name", "description", "name_pecs", "name_nippleless", "category", "message_pit_hair", "user_messages_pit_hair", "target_messages_pit_hair", "message_sweaty", "user_messages_sweaty", "target_messages_sweaty", "message_auto_emotes", "message_pokes_out", "user_messages_pokes_out", "target_messages_pokes_out", "message_nippleless", "user_messages_nippleless", "target_messages_nippleless"))
		TEST_ASSERT_EQUAL(json_encode(reloaded.vars[field]), json_encode(single.vars[field]), "Save round trip changed [field].")

	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/target = allocate(/mob/living/carbon/human/consistent)
	target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	var/list/selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "Absent physical hair changed the base pool.")
	target.set_body_hair(FEATURE_PITS, "Natural")
	TEST_ASSERT(istype(target.get_organ_slot(ORGAN_SLOT_EXTERNAL_PITS), /obj/item/organ/body_hair/pits), "Fixture did not grow physical pit hair.")
	// Hair and sweat text is additive: extra options in the pool, never a replacement.
	selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base", "observer hair")), "Physical target hair did not add its text to the pool.")
	TEST_ASSERT_EQUAL(length(single.message), 1, "Adding hair text mutated the base list.")
	selected = single.texts_for(single.user_messages, null, user, target, single.user_messages_pit_hair)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("user base", "user hair")), "User channel built the wrong pool.")
	selected = single.texts_for(single.target_messages, null, user, target, list())
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("target base")), "Empty channel failed to fall back independently.")
	selected = single.texts_for(single.message, null, target, user, single.message_pit_hair)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "User hair incorrectly added target-hair text.")

	// The sweat hook is dormant (is_visibly_sweaty() is FALSE) until the dirt and sweat overlays land.
	target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	selected = single.texts_for(single.message, null, user, target, null, single.message_sweaty)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "A dry target added sweaty text.")
	var/mob/living/carbon/human/consistent/sweaty_target = allocate(/mob/living/carbon/human/consistent/sweaty_interaction_fixture)
	selected = single.texts_for(single.message, null, user, sweaty_target, null, single.message_sweaty)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base", "observer sweat")), "A sweaty target did not add sweaty text.")
	// Sweat and hair stack: both sets of extra options join the pool.
	sweaty_target.set_body_hair(FEATURE_PITS, "Natural")
	selected = single.texts_for(single.message, null, user, sweaty_target, single.message_pit_hair, single.message_sweaty)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base", "observer sweat", "observer hair")), "Sweat and hair extras did not stack.")
	// sweaty_is_user flips whose sweat the text follows (pitjobs, smothering).
	single.sweaty_is_user = TRUE
	selected = single.texts_for(single.message, null, user, target, null, single.message_sweaty)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "A dry user added sweaty text with sweaty_is_user set.")
	selected = single.texts_for(single.message, null, sweaty_target, target, null, single.message_sweaty)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base", "observer sweat")), "A sweaty user did not add sweaty text with sweaty_is_user set.")
	single.sweaty_is_user = FALSE

	// Pokes-out text replaces the pool outright: covered-head lines no longer apply, extras included.
	selected = single.texts_for(single.message, null, user, target, single.message_pit_hair, single.message_sweaty, single.message_pokes_out)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "A covered bulge used bare-skin text.")
	var/mob/living/carbon/human/consistent/poking_target = allocate(/mob/living/carbon/human/consistent/poking_interaction_fixture)
	selected = single.texts_for(single.message, null, user, poking_target, single.message_pit_hair, single.message_sweaty, single.message_pokes_out)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer bare")), "A poking target did not replace the pool with bare-skin text.")
	// With the user's own bulge required, the target's state no longer decides.
	single.interaction_requires = list(INTERACTION_REQUIRE_SELF_BULGE)
	selected = single.texts_for(single.message, null, user, poking_target, null, null, single.message_pokes_out)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer base")), "A poking target decided for a self-bulge interaction.")
	selected = single.texts_for(single.message, null, poking_target, target, null, null, single.message_pokes_out)
	TEST_ASSERT_EQUAL(json_encode(selected), json_encode(list("observer bare")), "A poking user did not decide for a self-bulge interaction.")
	single.interaction_requires = list(INTERACTION_REQUIRE_TARGET_ARM)

	// Hair and sweat read as adjectives through the armpit and bulge tokens.
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, target), "armpit", "A plain armpit gained adjectives.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_BULGE%", user, target), "bulge", "A dry bulge gained adjectives.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, sweaty_target), "sweaty, hairy armpit", "Sweat and hair adjectives did not combine.")
	TEST_ASSERT_EQUAL(single.format_message_for("%USER_ARMPIT%", sweaty_target, target), "sweaty, hairy armpit", "The user role did not expand its armpit token.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_BULGE%", user, sweaty_target), "sweat-damp bulge", "Sweat did not reach the bulge token.")
	sweaty_target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, sweaty_target), "sweaty armpit", "A shaved sweaty armpit kept the hair adjective.")
	target.set_body_hair(FEATURE_PITS, "Natural")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, target), "hairy armpit", "A dry hairy armpit misread its adjectives.")
	target.set_body_hair(FEATURE_PITS, "Untamed")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, target), "bushy armpit", "The hair style did not vary the adjective.")
	target.set_body_hair(FEATURE_PITS, "Trimmed")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_ARMPIT%", user, target), "trimmed armpit", "The trimmed style did not vary the adjective.")

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
		TEST_NOTICE(src, "Chest precedence fixture unavailable while genital config is disabled; run it with the config enabled.")
	target.set_body_hair(FEATURE_PITS, SPRITE_ACCESSORY_NONE)
	target.dna.mutant_bodyparts[FEATURE_PITS] = build_mutant_part("Natural", list(BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR, BODY_HAIR_DEFAULT_COLOR))
	selected = single.texts_for(single.message, null, user, target, single.message_pit_hair)
	TEST_ASSERT_EQUAL(selected[1], "observer base", "DNA-only hair incorrectly selected physical-hair text.")
	single.load_aphelion_text(list("message_pit_hair" = "invalid scalar"))
	TEST_ASSERT_NULL(single.message_pit_hair, "Invalid optional text did not normalize to null.")
	TEST_ASSERT_NULL(single.user_messages_pit_hair, "Reload retained a missing optional channel.")

	// Feature values are literal text, never recursively processed as role/chest/scent templates.
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar %USER% %TARGET_SCENT%"
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target), "cedar %USER% %TARGET_SCENT%", "Scent text was recursively expanded.")
	TEST_ASSERT_EQUAL(single.format_message_for("%target_scent%", user, target), "%target_scent%", "Scent token incorrectly matched different case.")
	TEST_ASSERT_EQUAL(single.format_message_for("neutral", user, target), "neutral", "A token-free message changed.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target, target_anonymous = TRUE), "their scent", "Anonymous target disclosed a custom scent.")
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = null
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target), "[target.p_their()] scent", "Missing scent did not follow the target's pronouns.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target, recipient = target), "your scent", "A recipient's missing scent did not read as your scent.")
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_SCENT%", user, target, target_anonymous = TRUE), "their scent", "An anonymous target's scent fallback leaked pronouns.")
	target.dna.features[ERP_FLAVOR_DNA_SCENT] = "cedar"
	TEST_ASSERT_EQUAL(single.format_message_for("%TARGET_PRONOUN_THEIR% %TARGET_SCENT%", user, target, recipient = target), "your cedar", "Recipient grammar or final scent expansion changed.")
