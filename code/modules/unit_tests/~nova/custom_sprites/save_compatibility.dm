/// Old-format drawings as the branch's own writer stored them, built without any codec proc so a codec change can't regenerate them.
/// v1, two colours: pixel (0,0) is colour 1 and (1,0) colour 2 in the Front view; 1,022 empty pixels follow (68 runs of 15 and one of 2).
/proc/custom_sprite_compat_v1()
	return list("version" = 1, "palette" = list("#ff0000", "#00ff00"), "tint" = null, "dirs" = list("2" = "r1112[repeat_string(68, "f0")]20"))

/// v1 as an even older save wrote it: one emissive flag for every view, an explicit filter, a solid Front view (68 runs of 15 and one of 4).
/proc/custom_sprite_compat_v1_legacy_emissive()
	return list("version" = 1, "palette" = list("#abcdef"), "tint" = "#ff00ff", "dirs" = list("2" = "r[repeat_string(68, "f1")]41"), "emissive" = TRUE)

/// v2, all 63 colours in the Front view's first row, a solid Back view of colour 63, per-view emission.
/proc/custom_sprite_compat_v2()
	var/list/palette = list()
	var/list/front = list("r")
	for(var/index in 1 to CUSTOM_SPRITE_MAX_COLORS)
		palette += rgb(index, 0, 0)
		front += "1[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, index + 1, index + 2)]"
	front += "[repeat_string(64, "f0")]10"
	return list("version" = 2, "palette" = palette, "tint" = null, "dirs" = list("2" = jointext(front, ""), "1" = "r[repeat_string(68, "f_")]4_"), "emissive" = list("2" = TRUE, "1" = FALSE, "4" = FALSE, "8" = FALSE))

/// v3, the 64-wide taur zone, one colour everywhere in the Front view (136 runs of 15 and one of 8).
/proc/custom_sprite_compat_v3()
	return list("version" = 3, "palette" = list("#123456"), "tint" = null, "dirs" = list("2" = "r[repeat_string(136, "f1")]81"))

/// Old drawings of every version load to the same pixels and write back byte for byte, as the current code does.
/datum/unit_test/custom_sprite_save_compat_drawings/Run()
	var/list/v1 = custom_sprite_compat_v1()
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(v1)), json_encode(v1), "A canonical v1 drawing must write back identically")
	TEST_ASSERT_EQUAL(custom_sprite_decode_grid(v1["dirs"]["2"], 2), "12[repeat_string(1022, "0")]", "The v1 Front view must decode to its two painted pixels")
	var/list/pixels = custom_sprite_drawing_pixels(v1)
	TEST_ASSERT(pixels["2"][1] == "#ff0000" && pixels["2"][2] == "#00ff00" && isnull(pixels["2"][3]) && isnull(pixels["1"][1]), "The v1 pixels must read back as their colours")
	var/icon/paint = custom_sprite_paint_icon(v1, FALSE)
	TEST_ASSERT(paint.GetPixel(1, 32, "", SOUTH) == "#ff0000" && paint.GetPixel(2, 32, "", SOUTH) == "#00ff00" && !paint.GetPixel(3, 32, "", SOUTH) && !paint.GetPixel(1, 32, "", NORTH), "The v1 paint icon must put the pixels at the top left of the Front view only")
	TEST_ASSERT_EQUAL(custom_sprite_hash(custom_sprite_validate(v1)), custom_sprite_hash(v1), "Validation must not change a canonical v1 drawing's hash")
	var/list/upper = custom_sprite_compat_v1()
	upper["palette"] = list("#FF0000", "#00FF00")
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(upper)), json_encode(v1), "Uppercase colours must load as the same drawing and write back lowercase")
	var/list/legacy = custom_sprite_compat_v1_legacy_emissive()
	var/list/expected = custom_sprite_compat_v1_legacy_emissive()
	expected["emissive"] = list("2" = TRUE, "1" = TRUE, "4" = TRUE, "8" = TRUE)
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(legacy)), json_encode(expected), "A legacy single emissive flag must load as every view glowing, the pixels and filter untouched")
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_appearance_drawing(legacy, FALSE)["emissive"]), json_encode(list("2" = FALSE, "1" = FALSE, "4" = FALSE, "8" = FALSE)), "The master emissive permission must switch a legacy flag off for rendering without touching the save")
	paint = custom_sprite_paint_icon(legacy, FALSE)
	TEST_ASSERT_EQUAL(paint.GetPixel(16, 16, "", SOUTH), "#abcdef", "The paint icon must hold the raw colour; the filter is applied when rendering")
	var/list/v2 = custom_sprite_compat_v2()
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(v2)), json_encode(v2), "A canonical v2 drawing must write back identically")
	TEST_ASSERT_EQUAL(custom_sprite_decode_grid(v2["dirs"]["2"], CUSTOM_SPRITE_MAX_COLORS), "[copytext(CUSTOM_SPRITE_INDEX_ALPHABET, 2)][repeat_string(961, "0")]", "The v2 Front view must decode to all 63 indexes in order")
	pixels = custom_sprite_drawing_pixels(v2)
	TEST_ASSERT(pixels["2"][63] == "#3f0000" && pixels["1"][1024] == "#3f0000" && isnull(pixels["2"][64]), "The v2 pixels must read back as their colours in both views")
	var/list/v3 = custom_sprite_compat_v3()
	TEST_ASSERT_EQUAL(json_encode(custom_sprite_validate(v3)), json_encode(v3), "A canonical v3 drawing must write back identically")
	TEST_ASSERT(custom_sprite_width(v3) == CUSTOM_SPRITE_TAUR_WIDTH && custom_sprite_height(v3) == 32, "v3 is 64 by 32")
	TEST_ASSERT_EQUAL(custom_sprite_decode_grid(v3["dirs"]["2"], 1, 2048), repeat_string(2048, "1"), "The v3 Front view must decode to 2,048 painted pixels")
	TEST_ASSERT_EQUAL(json_encode(custom_limb_markings_validate(list("taur" = v3, "head" = v1))), json_encode(list("head" = v1, "taur" = v3)), "Stored zone drawings must load in zone order with their bytes unchanged")
	TEST_ASSERT(isnull(custom_limb_markings_validate(list("l_arm" = v3))), "A wide drawing on an ordinary limb is dropped, as today")

/// A whole account sidecar as the branch wrote it, one slot with every key, and what loading it must give back.
/proc/custom_sprite_compat_sidecar()
	var/list/hair_look = list("style" = "Bald", "color" = "#583820", "gradient_style" = "None", "gradient_color" = "#000000", "opacity" = null, "emissive" = FALSE)
	var/list/previous = list(
		"hair" = list("target" = "hair", "zone" = null, "drawing" = custom_sprite_compat_v1(), "hair" = hair_look),
		"markings:l_arm" = list("target" = "markings", "zone" = "l_arm", "drawing" = null, "hair" = null, "markings" = list(list("name" = "Tiger Stripe", "color" = "#123456", "emissive" = FALSE))),
	)
	return list("character1" = list("hair" = custom_sprite_compat_v1(), "facial_hair" = custom_sprite_compat_v2(), "limb_markings" = list("l_arm" = custom_sprite_compat_v1(), "taur" = custom_sprite_compat_v3()), "previous_styles" = previous))

/// Every key of an old sidecar loads to the same drawings and writes back unchanged; a previous style without an emissive map gains the default-off one, as today.
/datum/unit_test/custom_sprite_save_compat_sidecar/Run()
	TEST_ASSERT(("Tiger Stripe" in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM]), "The fixture needs Tiger Stripe as a left arm marking")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	var/test_path = "tmp/custom_sprite_save_compat_[REF(src)].json"
	allocate(/datum/custom_sprite_test_files, test_path)
	var/list/tree = custom_sprite_compat_sidecar()
	rustg_file_write(json_encode(tree), test_path)
	var/datum/json_savefile/custom_sprites/store = new(test_path)
	QDEL_NULL(preferences.custom_sprite_savefile)
	preferences.custom_sprite_savefile = store
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	var/list/slot = tree["character1"]
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_hair), json_encode(slot["hair"]), "Hair must load byte for byte")
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_facial_hair), json_encode(slot["facial_hair"]), "Facial hair must load byte for byte")
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_limb_markings), json_encode(slot["limb_markings"]), "Limb markings must load byte for byte, taur included")
	var/list/expected_previous_hair = custom_sprite_compat_v1()
	expected_previous_hair["emissive"] = list("2" = FALSE, "1" = FALSE, "4" = FALSE, "8" = FALSE)
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_style_previous["hair"]["drawing"]), json_encode(expected_previous_hair), "A previous hair style without an emissive map gains the default-off one on load, as today")
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_style_previous["hair"]["hair"]), json_encode(slot["previous_styles"]["hair"]["hair"]), "The previous base look must load unchanged")
	TEST_ASSERT_EQUAL(json_encode(preferences.custom_style_previous["markings:l_arm"]), json_encode(slot["previous_styles"]["markings:l_arm"]), "A previous markings style must load unchanged, native markings included")
	var/list/expected_tree = custom_sprite_compat_sidecar()
	expected_tree["character1"]["previous_styles"]["hair"]["drawing"] = expected_previous_hair
	preferences.store_custom_sprite_slot(1)
	TEST_ASSERT_EQUAL(json_encode(store.get_entry("character1")), json_encode(expected_tree["character1"]), "Writing the loaded slot back must reproduce the file, with only the documented emissive default added")
	// A second load of what was written back changes nothing more.
	rustg_file_write(json_encode(store.get_entry()), test_path)
	var/datum/json_savefile/custom_sprites/again = allocate(/datum/json_savefile/custom_sprites, test_path)
	preferences.custom_sprite_savefile = again
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	preferences.store_custom_sprite_slot(1)
	TEST_ASSERT_EQUAL(json_encode(again.get_entry("character1")), json_encode(expected_tree["character1"]), "Loading and writing again must be stable")
	// The drawings reach the body exactly as saved, with the emissive default applied for rendering.
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
	TEST_ASSERT_EQUAL(json_encode(body.dna.custom_hair), json_encode(expected_previous_hair), "DNA hair must be the saved v1 drawing with the default-off emissive map")
	var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT_EQUAL(json_encode(head.custom_hair), json_encode(expected_previous_hair), "The head snapshot must match DNA")
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/bodypart_overlay/custom_marking/arm_paint = arm.get_custom_marking(/datum/bodypart_overlay/custom_marking/zone)
	TEST_ASSERT_EQUAL(json_encode(arm_paint?.drawing), json_encode(expected_previous_hair), "The arm's overlay must carry the saved zone drawing")
	// An empty account file loads to nothing.
	rustg_file_write("{}", test_path)
	var/datum/json_savefile/custom_sprites/empty = allocate(/datum/json_savefile/custom_sprites, test_path)
	preferences.custom_sprite_savefile = empty
	preferences.custom_sprite_slot = null
	preferences.load_custom_sprites()
	TEST_ASSERT(isnull(preferences.custom_hair) && isnull(preferences.custom_facial_hair) && isnull(preferences.custom_limb_markings) && isnull(preferences.custom_style_previous), "An empty sidecar must load to no drawings")
	store.path = null
	again.path = null
	empty.path = null
	qdel(store)

/// A preferences save with only pre-branch fields gives the same DNA and head as before the branch: no paint, the accessory hair, the default account palette.
/datum/unit_test/custom_sprite_save_compat_prebranch_preferences/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/datum/preference/palette = GLOB.preference_entries[/datum/preference/custom_sprite_palette]
	TEST_ASSERT_EQUAL(json_encode(preferences.savefile.get_entry(palette.savefile_key)), "\[]", "A pre-branch account gains only the default empty palette, as reading any new preference writes its default")
	TEST_ASSERT_EQUAL(json_encode(preferences.read_preference(/datum/preference/custom_sprite_palette)), "\[]", "The account palette defaults to empty")
	preferences.load_custom_sprites()
	TEST_ASSERT(isnull(preferences.custom_sprite_savefile.path) && !length(preferences.custom_sprite_savefile.get_entry()), "A memory-only sidecar with no file holds nothing")
	for(var/style in list("Short Hair", "Bald"))
		// A fresh body each time: applying preferences to one body twice re-registers its personality's signals.
		var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/hairstyle], style)
		preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/facial_hairstyle], "Shaved")
		preferences.apply_prefs_to(body, TRUE, visuals_only = TRUE)
		TEST_ASSERT(isnull(body.dna.custom_hair) && isnull(body.dna.custom_facial_hair) && isnull(body.dna.custom_limb_markings), "Pre-branch preferences must put no paint on DNA ([style])")
		var/obj/item/bodypart/head/head = body.get_bodypart(BODY_ZONE_HEAD)
		TEST_ASSERT(isnull(head.custom_hair) && isnull(head.custom_facial_hair), "Pre-branch preferences must put no paint on the head ([style])")
		TEST_ASSERT(head.custom_sprite_hair_accessory() == SSaccessories.hairstyles_list[style], "The head must use the ordinary accessory, or none for Bald ([style])")
		for(var/obj/item/bodypart/limb as anything in body.bodyparts)
			TEST_ASSERT(!(locate(/datum/bodypart_overlay/custom_marking) in limb.bodypart_overlays), "No limb may carry a paint overlay ([style], [limb.body_zone])")
		if(style == "Bald")
			TEST_ASSERT(!length(head.get_hair_overlays()), "A bald, shaved pre-branch head draws no hair overlays")
	var/datum/preference_middleware/custom_sprites/middleware = locate() in preferences.middleware
	TEST_ASSERT(!length(middleware.get_ui_data(mock_client.mob)["custom_marking_zones"]), "Character setup shows no drawn zones")
	for(var/key in preferences.savefile.get_entry("character[preferences.default_slot]"))
		TEST_ASSERT(!findtext(key, "custom_sprite"), "The character slot gains no custom sprite keys: [key]")
