/**
 * Two bodies wearing one finish in different colours, or one of them without glow, draw their own: the limb icon cache is
 * shared by every body, so a key without the colours or the glow would serve one body's arm to the other. A colour change
 * redraws the arm in the new colours.
 */
/datum/unit_test/augment_paint_cache

/datum/unit_test/augment_paint_cache/Run()
	var/datum/robotic_style/recolorable/finish = GLOB.robotic_styles_list[/datum/robotic_style/recolorable/silverhand::name]
	var/mob/living/carbon/human/consistent/first = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/consistent/second = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/first_arm = put_on_finish(first, finish, "#b2202a#cdd2dc#2a282e#8ce8ff")
	var/obj/item/bodypart/second_arm = put_on_finish(second, finish, "#2e3340#9aa4b8#14161c#3dc8ff")
	TEST_ASSERT_NOTEQUAL(first_arm.get_cache_key(), second_arm.get_cache_key(), "Two colour sets share a limb icon key.")
	TEST_ASSERT_EQUAL(paint_drawn(first), "#b2202a", "The first body's arm doesn't draw its own paint.")
	TEST_ASSERT_EQUAL(paint_drawn(second), "#2e3340", "The second body's arm doesn't draw its own paint.")
	second_arm.is_emissive = FALSE
	second_arm.augment_colors = first_arm.augment_colors
	TEST_ASSERT_NOTEQUAL(first_arm.get_cache_key(), second_arm.get_cache_key(), "A finish with and without glow share a limb icon key.")
	first_arm.augment_colors = "#2e3340#9aa4b8#14161c#3dc8ff"
	first.update_body_parts()
	TEST_ASSERT_EQUAL(paint_drawn(first), "#2e3340", "A recoloured arm keeps drawing its old paint.")

/**
 * Gives `body` a cyborg right arm wearing `finish` in `colors`, drawn, and returns it. The arm it replaces is deleted.
 *
 * Arguments:
 * - body: The test human.
 * - finish: The recolourable finish.
 * - colors: The finish's colour string.
 */
/datum/unit_test/augment_paint_cache/proc/put_on_finish(mob/living/carbon/human/body, datum/robotic_style/recolorable/finish, colors)
	var/obj/item/bodypart/arm/right/robot/arm = allocate(/obj/item/bodypart/arm/right/robot)
	var/obj/item/bodypart/old_arm = body.get_bodypart(BODY_ZONE_R_ARM)
	arm.limb_id = finish.limb_id_override
	arm.bodyshape = finish.bodyshape_override
	arm.set_icon_greyscale(finish.icon)
	finish.apply_to(arm, colors, null)
	arm.replace_limb(body)
	qdel(old_arm)
	body.update_body_parts()
	return arm

/**
 * Returns the paint colour `body`'s right arm draws, as "#rrggbb": the red row of its _paint copy's matrix, which BYOND reads
 * back as 20 numbers. Read from the images the body's last draw was served, by its render key.
 *
 * Arguments:
 * - body: The test human.
 */
/datum/unit_test/augment_paint_cache/proc/paint_drawn(mob/living/carbon/human/body)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_R_ARM)
	for(var/image/drawn as anything in body.limb_icon_cache[body.icon_render_keys[BODY_ZONE_R_ARM]])
		if(drawn.icon_state == "[arm.limb_id]_[BODY_ZONE_R_ARM]_paint")
			var/list/matrix = drawn.color
			return rgb(round(matrix[1] * 255, 1), round(matrix[2] * 255, 1), round(matrix[3] * 255, 1))
	TEST_FAIL("The right arm draws no _paint copy.")

/**
 * A recolourable arm fits clothes as a Muscular arm, spawned and in the character setup preview. Spawned, it takes its body's
 * skin: a skin tone, or a mutant colour drawn from the humanoid skin sheet. In the preview, on a Muscular body, a slot moved
 * to a brand finish fits at the size its spawned limb will have, the Normal size, and loses the finish's colours, glow and
 * icon key; and once the slot loses its augment, the arm fits at the body's size again.
 */
/datum/unit_test/augment_paint_fit

/datum/unit_test/augment_paint_fit/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/prefs = allocate(/datum/preferences/preferences_import_test, mock_client)
	prefs.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	prefs.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	prefs.augments[AUGMENT_SLOT_R_ARM] = /datum/augment_item/limb/r_arm/cyborg
	prefs.augment_limb_styles[AUGMENT_SLOT_R_ARM] = /datum/robotic_style/recolorable/silverhand::name
	var/datum/augment_item/limb/augment = GLOB.augment_items[/datum/augment_item/limb/r_arm/cyborg]

	var/mob/living/carbon/human/consistent/spawned = allocate(/mob/living/carbon/human/consistent)
	spawned.skin_tone = "african2"
	augment.apply(spawned, character_setup = FALSE, prefs = prefs)
	spawned.synchronize_bodyshapes()
	var/obj/item/bodypart/spawned_arm = spawned.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(spawned_arm.draw_color, skintone2hex("african2"), "A spawned recolourable arm doesn't take its body's skin tone.")
	TEST_ASSERT_EQUAL(spawned_arm.muscle_size, MUSCLE_SIZE_MUSCULAR, "A spawned recolourable arm isn't Muscular.")
	TEST_ASSERT_EQUAL(spawned.garment_fit?.sizes?[BODY_ZONE_R_ARM], MUSCLE_SIZE_MUSCULAR, "A spawned recolourable arm doesn't fit clothes as Muscular.")

	var/mob/living/carbon/human/species/lizard/lizard = allocate(/mob/living/carbon/human/species/lizard)
	lizard.dna.features[FEATURE_MUTANT_COLOR] = "#3c9a3c"
	augment.apply(lizard, character_setup = FALSE, prefs = prefs)
	lizard.update_body_parts()
	var/obj/item/bodypart/lizard_arm = lizard.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(lizard_arm.draw_color, "#3c9a3c", "A spawned recolourable arm doesn't take its body's mutant colour.")
	TEST_ASSERT_EQUAL(UNLINT(lizard_arm.icon_greyscale), BULKY_AUGMENTS_SHEET_HUMANOID, "A spawned recolourable arm under a mutant colour doesn't draw from the humanoid skin sheet.")

	// The character setup preview changes the body's own arm in place, through the limbs middleware.
	var/datum/preference_middleware/limbs_and_markings/limbs = allocate(/datum/preference_middleware/limbs_and_markings, prefs)
	var/mob/living/carbon/human/consistent/preview = muscular_body()
	limbs.apply_to_human(preview, prefs, visuals_only = TRUE)
	var/obj/item/bodypart/arm = preview.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(preview.garment_fit?.sizes?[BODY_ZONE_R_ARM], MUSCLE_SIZE_MUSCULAR, "A previewed recolourable arm doesn't fit clothes as Muscular.")
	TEST_ASSERT(arm.is_emissive, "A previewed recolourable arm doesn't glow with emissives allowed.")

	prefs.augment_limb_styles[AUGMENT_SLOT_R_ARM] = /datum/robotic_style/surplus::name
	limbs.apply_to_human(preview, prefs, visuals_only = TRUE)
	TEST_ASSERT(!preview.garment_fit?.sizes?[BODY_ZONE_R_ARM], "A previewed brand finish fits clothes at the body's size, not at its spawned limb's Normal size.")
	TEST_ASSERT_NULL(arm.augment_colors, "A previewed brand finish keeps the recolourable finish's colours.")
	TEST_ASSERT(!arm.is_emissive, "A previewed brand finish keeps the recolourable finish's glow.")
	var/mob/living/carbon/human/consistent/plain = muscular_body()
	limbs.apply_to_human(plain, prefs, visuals_only = TRUE)
	var/obj/item/bodypart/plain_arm = plain.get_bodypart(BODY_ZONE_R_ARM)
	TEST_ASSERT_EQUAL(arm.get_cache_key(), plain_arm.get_cache_key(), "An arm taken off its recolourable finish keys its icons apart from one that never wore it.")

	prefs.augments -= AUGMENT_SLOT_R_ARM
	limbs.apply_to_human(preview, prefs, visuals_only = TRUE)
	TEST_ASSERT_EQUAL(preview.garment_fit?.sizes?[BODY_ZONE_R_ARM], MUSCLE_SIZE_MUSCULAR, "An arm whose augment the preview took off keeps the brand finish's fit.")

/**
 * Returns a test human drawn at the Muscular size.
 */
/datum/unit_test/augment_paint_fit/proc/muscular_body()
	var/mob/living/carbon/human/consistent/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.features[FEATURE_MUSCLE_SIZE] = MUSCLE_SIZE_MUSCULAR
	body.update_fitness_limbs()
	return body

/**
 * A save's augment colours load only for a slot whose finish is recolourable, and only as a valid colour string: a bad,
 * stale or hand-edited entry is dropped, never drawn.
 */
/datum/unit_test/augment_paint_save

/datum/unit_test/augment_paint_save/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/prefs = allocate(/datum/preferences/preferences_import_test, mock_client)
	var/finish_name = /datum/robotic_style/recolorable/gorilla::name
	var/list/save_data = list(
		"augment_limb_styles" = list(AUGMENT_SLOT_R_ARM = finish_name, AUGMENT_SLOT_L_ARM = /datum/robotic_style/surplus::name, AUGMENT_SLOT_L_LEG = finish_name),
		"augment_limb_colors" = list(
			AUGMENT_SLOT_R_ARM = "#B2202A#cdd2dc#2a282e#8ce8ff",
			AUGMENT_SLOT_L_ARM = "#b2202a#cdd2dc#2a282e#8ce8ff",
			AUGMENT_SLOT_R_LEG = "#b2202a#cdd2dc#2a282e#8ce8ff",
			AUGMENT_SLOT_L_LEG = "javascript:alert(1)",
		),
	)
	prefs.load_augment_colors(save_data)
	TEST_ASSERT_EQUAL(prefs.augment_limb_colors[AUGMENT_SLOT_R_ARM], "#b2202a#cdd2dc#2a282e#8ce8ff", "A recolourable slot's colours didn't load, lowercased.")
	TEST_ASSERT_EQUAL(length(prefs.augment_limb_colors), 1, "Colours loaded for a brand finish, a slot without a finish, or a bad string.")

/**
 * Every recolourable finish's sheets hold the states its limbs draw: the skin base of each zone in both skin ramps, a packed
 * _paint or _glow state somewhere, and lights masks only where its art lights, plus one on the hand of a lit arm, which tg
 * lights along with the arm. A finish without a lights channel has none; one with a lights channel lights at least one arm
 * or leg; each mask is in both skin ramps; an arm's or leg's has the _glow state that draws its lights, while a hand's may be
 * empty. Its channels, default and presets are ones the editor and the saves take. A missing state draws nothing, which
 * nothing else would notice.
 */
/datum/unit_test/augment_paint_sheets

/datum/unit_test/augment_paint_sheets/Run()
	var/list/hands = list(BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_PRECISE_L_HAND)
	var/list/arm_hands = list(BODY_ZONE_R_ARM = BODY_ZONE_PRECISE_R_HAND, BODY_ZONE_L_ARM = BODY_ZONE_PRECISE_L_HAND)
	var/checked = 0
	for(var/style_name, style in GLOB.robotic_styles_list)
		var/datum/robotic_style/recolorable/finish = style
		if(!istype(finish))
			continue
		var/lights = !!finish.channels["lights"]
		var/lit_zones = 0
		var/has_paint = FALSE
		for(var/zone in BULKY_AUGMENT_ZONES)
			var/state = "[finish.limb_id_override]_[zone]"
			for(var/sheet in list(BULKY_AUGMENTS_SHEET, BULKY_AUGMENTS_SHEET_HUMANOID))
				TEST_ASSERT(icon_exists(sheet, state), "[style_name] has no [state] in [sheet].")
			var/lit = icon_exists(BULKY_AUGMENTS_SHEET, "[state]_e")
			TEST_ASSERT_EQUAL(icon_exists(BULKY_AUGMENTS_SHEET_HUMANOID, "[state]_e"), lit, "[style_name]'s two skin sheets disagree on [state]_e.")
			has_paint ||= icon_exists(BULKY_AUGMENTS_PAINT_SHEET, "[state]_paint") || icon_exists(BULKY_AUGMENTS_PAINT_SHEET, "[state]_glow")
			if(!lit)
				continue
			TEST_ASSERT(lights, "[style_name] has no lights channel, yet its [zone] has a lights mask.")
			if(zone in hands)
				continue
			lit_zones++
			TEST_ASSERT(icon_exists(BULKY_AUGMENTS_PAINT_SHEET, "[state]_glow"), "[style_name] lights its [zone] with no [state]_glow to draw the lights.")
			var/hand = arm_hands[zone]
			if(hand)
				TEST_ASSERT(icon_exists(BULKY_AUGMENTS_SHEET, "[finish.limb_id_override]_[hand]_e"), "[style_name] lights its [zone] with no lights mask on its hand, which tg lights along with the arm.")
		TEST_ASSERT(has_paint, "[style_name] draws no paint or glow anywhere.")
		TEST_ASSERT(!lights || lit_zones, "[style_name] has a lights channel, yet lights no arm or leg.")
		for(var/channel in finish.channels)
			TEST_ASSERT(channel in list("paint", "accent", "frame", "lights"), "[style_name] names an unknown channel, [channel].")
		TEST_ASSERT_EQUAL(sanitize_augment_colors(finish.default_colors), finish.default_colors, "[style_name]'s default colours aren't a lowercase colour string.")
		for(var/preset_name, colors in finish.presets)
			TEST_ASSERT_EQUAL(sanitize_augment_colors(colors), colors, "[style_name]'s [preset_name] preset isn't a lowercase colour string.")
		checked++
	TEST_ASSERT(checked, "No recolourable finish exists.")
