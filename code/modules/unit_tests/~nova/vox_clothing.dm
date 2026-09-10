/datum/unit_test/vox_pants_fallback/Run()
	var/datum/species/vox_primalis/species = allocate(/datum/species/vox_primalis)
	var/obj/item/clothing/under/color/uniform = allocate(/obj/item/clothing/under/color)
	// Use real source sprites under a state absent from the dedicated Vox sheet.
	var/icon/source = icon(uniform.worn_icon, "jumpsuit")
	var/icon/source_file = icon()
	source_file.Insert(source, "fallback_test")
	source_file.Insert(source, "fallback_test_d")
	uniform.worn_icon = source_file
	uniform.icon_state = "fallback_test"
	uniform.worn_icon_state = "fallback_test"
	uniform.worn_icon_better_vox = null
	uniform.greyscale_colors = "#AABBCC"
	var/icon/result = species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform)
	TEST_ASSERT_NOTNULL(result, "Missing generated Vox pants")
	TEST_ASSERT(icon_exists(result, "fallback_test_d"), "Rolled-down state was lost")
	var/colored_template = SSgreyscale.GetColoredIconByType(/datum/greyscale_config/vox_primalis_pants, uniform.greyscale_colors)
	for(var/direction in GLOB.cardinals)
		var/icon/original = icon(source_file, "fallback_test", direction)
		var/icon/generated = icon(result, "fallback_test", direction)
		var/icon/template = icon(colored_template, "pants", direction)
		for(var/x in 1 to 32)
			for(var/y in 1 to 32)
				var/expected = y <= 11 ? template.GetPixel(x, y) : original.GetPixel(x, y)
				TEST_ASSERT_EQUAL(generated.GetPixel(x, y), expected, "Vox fallback mismatch at [x],[y] facing [direction]")
	TEST_ASSERT_EQUAL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform), result, "Fallback cache missed")
	uniform.greyscale_colors = "#CC2211"
	TEST_ASSERT_NOTEQUAL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform), result, "Recolor reused stale pants")
	uniform.body_parts_covered &= ~LEGS
	TEST_ASSERT_NULL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform), "Skirts must not gain pants")
	uniform.body_parts_covered |= LEGS
	uniform.worn_icon_better_vox = source_file
	TEST_ASSERT_EQUAL(species.generate_custom_worn_icon(LOADOUT_ITEM_UNIFORM, uniform), source_file, "Dedicated Vox sprite did not take priority")

/datum/unit_test/random_jumpsuit_loadout/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.jumpsuit_style = PREF_SKIRT
	var/datum/loadout_item/under/jumpsuit/random/loadout = GLOB.all_loadout_datums[/obj/item/clothing/under/color/random]
	var/datum/outfit/outfit = allocate(/datum/outfit)
	for(var/iteration in 1 to 30)
		loadout.insert_path_into_outfit(outfit, wearer, override_items = LOADOUT_OVERRIDE_BACKPACK)
		TEST_ASSERT(ispath(outfit.uniform, /obj/item/clothing/under/color), "Random jumpsuit is not a colored uniform")
		TEST_ASSERT(!ispath(outfit.uniform, /obj/item/clothing/under/color/jumpskirt), "Explicit jumpsuit loadout selected a skirt")
		TEST_ASSERT_NOTEQUAL(outfit.uniform, /obj/item/clothing/under/color/random, "Loadout retained the preference-sensitive spawner")

/datum/unit_test/vox_digitigrade_underwear/Run()
	var/mob/living/carbon/human/wearer = allocate(/mob/living/carbon/human/consistent)
	wearer.set_species(/datum/species/vox_primalis)
	var/datum/sprite_accessory/clothing/underwear/male_briefs/underwear = allocate(/datum/sprite_accessory/clothing/underwear/male_briefs)
	var/mutable_appearance/actual = underwear.make_appearance(COLOR_WHITE, MALE, wearer.bodyshape, wearer)
	var/mutable_appearance/expected = underwear.make_appearance(COLOR_WHITE, MALE, BODYSHAPE_DIGITIGRADE)
	TEST_ASSERT_EQUAL(actual.icon_state, expected.icon_state, "Primalis did not select the digi underwear state")
	TEST_ASSERT_EQUAL(actual.icon_state, "[underwear.icon_state]_d", "Expected a dedicated digi underwear sprite")
	TEST_ASSERT(!(wearer.bodyshape & BODYSHAPE_DIGITIGRADE), "Underwear rendering must not change Primalis bodyshape")
