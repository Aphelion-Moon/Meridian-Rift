/// Shared setup for the body marking merge tests. Abstract, so the runner never runs it on its own.
/datum/unit_test/body_marking_merge
	abstract_type = /datum/unit_test/body_marking_merge

/**
 * Builds a body wearing the given markings and draws it the way a DNA change does.
 *
 * Arguments:
 * - raw: the markings in the nested shape a savefile holds, zone -> (marking name -> list(color, emissive)).
 *
 * Returns the new human.
 */
/datum/unit_test/body_marking_merge/proc/dressed_body(list/raw)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.body_markings = body_marking_collection_from_list(raw)
	body.update_body_parts(update_limb_data = TRUE)
	return body

/**
 * Returns the icon state a marking draws on one of a limb's zones: its body zone, with the limb's leg shape and chest art,
 * or its aux zone.
 *
 * Arguments:
 * - name: the marking's name.
 * - zone: the zone it is drawn on.
 * - limb: the limb drawing it.
 */
/datum/unit_test/body_marking_merge/proc/drawn_state(name, zone, obj/item/bodypart/limb)
	var/datum/body_marking/marking = GLOB.body_markings[name]
	if(zone != limb.body_zone)
		return marking.zone_icon_state(zone)
	return marking.zone_icon_state(zone, limb.bodyshape & BODYSHAPE_DIGITIGRADE, limb.is_dimorphic ? limb.limb_gender : "m")

/**
 * Returns the content key, and so the icon state, a run of markings merges into on one of a limb's zones: each marking's
 * sheet and state in drawing order.
 *
 * Arguments:
 * - names: the markings of the run, in drawing order.
 * - zone: the zone they are drawn on.
 * - limb: the limb drawing them.
 */
/datum/unit_test/body_marking_merge/proc/run_key(list/names, zone, obj/item/bodypart/limb)
	var/list/parts = list()
	for(var/name in names)
		var/datum/body_marking/marking = GLOB.body_markings[name]
		parts += marking.icon
		parts += drawn_state(name, zone, limb)
	return jointext(parts, "|")

/**
 * Returns the appearances of a limb icon that draw one icon state, visible ones or glows.
 *
 * Arguments:
 * - drawn: the limb icon's appearances.
 * - state: the icon state to pick out.
 * - glow: TRUE for the ones on the emissive plane, FALSE for the rest.
 */
/datum/unit_test/body_marking_merge/proc/drawing(list/drawn, state, glow = FALSE)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/overlay as anything in drawn)
		if(overlay?.icon_state == state && (PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE) == glow)
			. += overlay

/**
 * Returns the icon states of a limb icon's visible marking appearances in draw order: everything off the emissive plane
 * but the limb's own images.
 *
 * Arguments:
 * - drawn: the limb icon's appearances.
 * - limb: the limb that drew them.
 */
/datum/unit_test/body_marking_merge/proc/visible_marking_states(list/drawn, obj/item/bodypart/limb)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/overlay as anything in drawn)
		if(overlay && PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE && findtext(overlay.icon_state, "[limb.limb_id]_") != 1)
			. += overlay.icon_state

/**
 * Returns every pixel of appearances flattened together on one 32x32 tile, facings in GLOB.cardinals order, a clear pixel
 * as ".".
 *
 * Arguments:
 * - appearances: 32x32 appearances, drawn in their layer order.
 */
/datum/unit_test/body_marking_merge/proc/flat_pixels(list/appearances)
	RETURN_TYPE(/list)
	var/image/look = image('icons/blanks/32x32.dmi', "nothing")
	for(var/image/appearance as anything in appearances)
		look.overlays += appearance
	. = list()
	for(var/direction in GLOB.cardinals)
		var/icon/flat = getFlatIcon(look, defdir = direction)
		for(var/y in 1 to 32)
			for(var/x in 1 to 32)
				var/pixel = flat.GetPixel(x, y)
				. += isnull(pixel) ? "." : pixel

/**
 * Returns every pixel of an icon's only state, facings in GLOB.cardinals order, a clear pixel as ".".
 *
 * Arguments:
 * - source: an icon holding one state, as icon(file, state) and the leg masks make them.
 */
/datum/unit_test/body_marking_merge/proc/pixels_of(icon/source)
	RETURN_TYPE(/list)
	. = list()
	for(var/direction in GLOB.cardinals)
		for(var/y in 1 to source.Height())
			for(var/x in 1 to source.Width())
				var/pixel = source.GetPixel(x, y, "", direction)
				. += isnull(pixel) ? "." : pixel

/// Each zone's same-coloured markings draw as one appearance and its glows as one glow, a leg's split over its two layers.
/// The merged appearance keeps no appearance flags and the merged glow exactly EMISSIVE_APPEARANCE_FLAGS on the emissive
/// plane, unnested, so prepare_bodypart_overlays() still nests the one and shares a boundary with the other.
/datum/unit_test/body_marking_merge/merged_zones

/datum/unit_test/body_marking_merge/merged_zones/Run()
	var/list/names = markings_baseline_marking_names()
	var/mob/living/carbon/human/body = dressed_body(markings_merge_fixture_fill())
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		var/list/drawn = limb.get_limb_icon(FALSE)
		var/leg = limb.body_zone == BODY_ZONE_L_LEG || limb.body_zone == BODY_ZONE_R_LEG
		// A leg draws each marking appearance twice, once per layer.
		var/per_zone = leg ? 2 : 1
		var/list/zones = list(limb.body_zone)
		if(limb.aux_zone)
			zones += limb.aux_zone
		var/list/limb_merged = list()
		for(var/zone in zones)
			var/key = run_key(names, zone, limb)
			var/list/visible = drawing(drawn, key)
			var/list/glows = drawing(drawn, key, TRUE)
			limb_merged += visible + glows
			TEST_ASSERT_EQUAL(length(visible), per_zone, "[zone]'s three same-coloured markings must draw as one appearance per layer")
			TEST_ASSERT_EQUAL(length(glows), per_zone, "[zone]'s three glows must draw as one glow per layer")
			for(var/name in names)
				var/state = drawn_state(name, zone, limb)
				TEST_ASSERT(!length(drawing(drawn, state)) && !length(drawing(drawn, state, TRUE)), "[zone] must not draw [state] apart from its run")
			for(var/image/merged as anything in visible)
				TEST_ASSERT(cmptext(merged.color, markings_merge_fixture_color()) && merged.alpha == 255, "[zone]'s merged markings must keep their colour and alpha")
				TEST_ASSERT_EQUAL(merged.appearance_flags, NONE, "[zone]'s merged markings must carry no appearance flags")
				TEST_ASSERT(is_plain_bodypart_sprite(merged) && !length(merged.overlays), "[zone]'s merged markings must stay a plain sprite prepare_bodypart_overlays() nests")
			for(var/image/merged as anything in glows)
				TEST_ASSERT(markings_baseline_is_glowing(merged), "[zone]'s merged glow must glow")
				TEST_ASSERT_EQUAL(merged.appearance_flags, EMISSIVE_APPEARANCE_FLAGS, "[zone]'s merged glow must carry exactly EMISSIVE_APPEARANCE_FLAGS")
				TEST_ASSERT(is_plain_bodypart_mask(merged) && !length(merged.overlays), "[zone]'s merged glow must stay a plain top-level emissive mask")
		// prepare_bodypart_overlays() takes plain sprites into a holder and plain masks into a boundary, so neither stays on top.
		var/list/prepared = prepare_bodypart_overlays(drawn)
		for(var/image/merged as anything in limb_merged)
			TEST_ASSERT(!(merged in prepared), "[limb.body_zone]'s merged [PLANE_TO_TRUE(merged.plane) == EMISSIVE_PLANE ? "glow" : "markings"] must be nested by prepare_bodypart_overlays()")
		// Everything the merged markings add to the bare limb: one appearance and one glow per zone, per layer.
		var/marked_count = length(drawn)
		var/list/limb_markings = limb.markings
		var/list/hand_markings = limb.aux_zone_markings
		limb.markings = null
		limb.aux_zone_markings = null
		var/bare_count = length(limb.get_limb_icon(FALSE))
		limb.markings = limb_markings
		limb.aux_zone_markings = hand_markings
		TEST_ASSERT_EQUAL(marked_count - bare_count, 2 * per_zone * length(zones), "[limb.body_zone]'s markings must add one appearance and one glow per zone and layer")

/// A merged zone draws exactly the pixels its markings drew one by one, facing every way, husked or not.
/datum/unit_test/body_marking_merge/same_pixels

/datum/unit_test/body_marking_merge/same_pixels/Run()
	for(var/husked in list(FALSE, TRUE))
		var/mob/living/carbon/human/body = dressed_body(markings_merge_fixture_fill())
		if(husked)
			body.become_husk(BURN)
			body.update_body_parts(update_limb_data = TRUE)
		for(var/obj/item/bodypart/limb as anything in body.bodyparts)
			var/list/merged = limb.append_base_marking_overlays(list(), include_emissive = FALSE)
			// A single-zone request draws the markings one by one.
			var/list/one_by_one = limb.append_base_marking_overlays(list(), limb.body_zone, FALSE)
			if(limb.aux_zone)
				limb.append_base_marking_overlays(one_by_one, limb.aux_zone, FALSE)
			TEST_ASSERT(length(merged) < length(one_by_one), "[limb.body_zone][husked ? ", husked," : ""] must merge its markings")
			var/list/merged_pixels = flat_pixels(merged)
			var/drawn = 0
			for(var/pixel in merged_pixels)
				if(pixel != ".")
					drawn++
			TEST_ASSERT(drawn, "[limb.body_zone][husked ? ", husked," : ""] must draw its merged markings")
			TEST_ASSERT_EQUAL(json_encode(merged_pixels), json_encode(flat_pixels(one_by_one)), "[limb.body_zone][husked ? ", husked," : ""] must draw the same pixels merged as one by one")

/// Only markings of one colour drawn right after one another merge: a marking of another colour between two ends the run.
/datum/unit_test/body_marking_merge/colour_runs

/datum/unit_test/body_marking_merge/colour_runs/Run()
	var/list/names = markings_baseline_marking_names()
	var/red = "#aa2222"
	var/blue = "#2222aa"
	var/mob/living/carbon/human/apart = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(red, 0), "[names[2]]" = list(blue, 0), "[names[3]]" = list(red, 0))))
	var/obj/item/bodypart/apart_arm = apart.get_bodypart(BODY_ZONE_L_ARM)
	var/list/states = list()
	for(var/name in names)
		states += drawn_state(name, BODY_ZONE_L_ARM, apart_arm)
	TEST_ASSERT_EQUAL(json_encode(visible_marking_states(apart_arm.get_limb_icon(FALSE), apart_arm)), json_encode(states), "Two markings of one colour with another colour between them must draw apart")
	var/mob/living/carbon/human/joined = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(red, 0), "[names[2]]" = list(red, 0), "[names[3]]" = list(blue, 0))))
	var/obj/item/bodypart/joined_arm = joined.get_bodypart(BODY_ZONE_L_ARM)
	var/list/joined_drawn = joined_arm.get_limb_icon(FALSE)
	var/list/expected = list(run_key(names.Copy(1, 3), BODY_ZONE_L_ARM, joined_arm), states[3])
	TEST_ASSERT_EQUAL(json_encode(visible_marking_states(joined_drawn, joined_arm)), json_encode(expected), "Two markings of one colour drawn one after the other must merge, and the next colour draw apart")
	var/list/red_run = drawing(joined_drawn, expected[1])
	var/list/blue_single = drawing(joined_drawn, expected[2])
	TEST_ASSERT_EQUAL(length(red_run) + length(blue_single), 2, "The merged run and the marking after it must each draw once")
	for(var/image/overlay as anything in red_run)
		TEST_ASSERT(cmptext(overlay.color, red), "The merged run must draw in its markings' colour")
	for(var/image/overlay as anything in blue_single)
		TEST_ASSERT(cmptext(overlay.color, blue), "The marking after the run must keep its own colour")

/// Markings on sheets of another size never blend: a 45x34 moth marking stays apart from a 32x32 one of the same colour,
/// markings on two 32x32 sheets merge, and two moth markings merge on a 45x34 canvas.
/datum/unit_test/body_marking_merge/canvas_sizes

/datum/unit_test/body_marking_merge/canvas_sizes/Run()
	var/list/names = markings_baseline_marking_names()
	var/wide_name = "Reddish"
	var/narrow_name = "Reddish Grayscale"
	var/datum/body_marking/wide = GLOB.body_markings[wide_name]
	var/datum/body_marking/narrow = GLOB.body_markings[narrow_name]
	var/list/wide_size = get_icon_dimensions(wide.icon)
	var/list/narrow_size = get_icon_dimensions(narrow.icon)
	TEST_ASSERT(wide_size["width"] == 45 && wide_size["height"] == 34 && narrow_size["width"] == 32 && narrow_size["height"] == 32, "The fixture needs a 45x34 moth sheet and a 32x32 greyscale one")
	var/fixture_color = markings_merge_fixture_color()
	// A 45x34 marking and a 32x32 one of the same colour, both glowing.
	var/mob/living/carbon/human/mixed = dressed_body(list(BODY_ZONE_L_ARM = list("[wide_name]" = list(fixture_color, 1), "[names[1]]" = list(fixture_color, 1))))
	var/obj/item/bodypart/mixed_arm = mixed.get_bodypart(BODY_ZONE_L_ARM)
	var/list/mixed_drawn = mixed_arm.get_limb_icon(FALSE)
	var/list/apart = list(drawn_state(wide_name, BODY_ZONE_L_ARM, mixed_arm), drawn_state(names[1], BODY_ZONE_L_ARM, mixed_arm))
	TEST_ASSERT_EQUAL(json_encode(visible_marking_states(mixed_drawn, mixed_arm)), json_encode(apart), "A 45x34 marking and a 32x32 one must draw apart")
	for(var/state in apart)
		TEST_ASSERT_EQUAL(length(drawing(mixed_drawn, state, TRUE)), 1, "A glow on a 45x34 sheet and one on a 32x32 sheet must draw apart ([state])")
	// Two 32x32 sheets.
	var/mob/living/carbon/human/narrow_body = dressed_body(list(BODY_ZONE_L_ARM = list("[narrow_name]" = list(fixture_color, 1), "[names[1]]" = list(fixture_color, 1))))
	var/obj/item/bodypart/narrow_arm = narrow_body.get_bodypart(BODY_ZONE_L_ARM)
	var/narrow_key = run_key(list(narrow_name, names[1]), BODY_ZONE_L_ARM, narrow_arm)
	var/list/narrow_drawn = narrow_arm.get_limb_icon(FALSE)
	TEST_ASSERT_EQUAL(json_encode(visible_marking_states(narrow_drawn, narrow_arm)), json_encode(list(narrow_key)), "Two 32x32 markings of one colour on different sheets must merge")
	TEST_ASSERT_EQUAL(length(drawing(narrow_drawn, narrow_key, TRUE)), 1, "Two 32x32 glows on different sheets must merge")
	// Two 45x34 markings.
	var/mob/living/carbon/human/moth = dressed_body(list(BODY_ZONE_L_ARM = list("[wide_name]" = list(fixture_color, 0), "Royal" = list(fixture_color, 0))))
	var/obj/item/bodypart/moth_arm = moth.get_bodypart(BODY_ZONE_L_ARM)
	var/moth_key = run_key(list(wide_name, "Royal"), BODY_ZONE_L_ARM, moth_arm)
	var/list/moth_run = drawing(moth_arm.get_limb_icon(FALSE), moth_key)
	TEST_ASSERT_EQUAL(length(moth_run), 1, "Two 45x34 markings of one colour must merge")
	if(length(moth_run))
		var/image/moth_merged = moth_run[1]
		var/icon/canvas = icon(moth_merged.icon, moth_merged.icon_state)
		TEST_ASSERT(canvas.Width() == 45 && canvas.Height() == 34, "Two 45x34 markings must merge on a 45x34 canvas, not [canvas.Width()]x[canvas.Height()]")

/// A limb drawing its markings translucent, as a roundstartslime's do, draws each marking and glow apart.
/datum/unit_test/body_marking_merge/reduced_alpha

/datum/unit_test/body_marking_merge/reduced_alpha/Run()
	var/list/names = markings_baseline_marking_names()
	var/slime_alpha = /datum/species/jelly/roundstartslime::markings_alpha
	TEST_ASSERT_NOTEQUAL(slime_alpha, 255, "The fixture needs the slime's reduced marking alpha")
	var/mob/living/carbon/human/body = dressed_body(markings_merge_fixture_fill())
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		limb.markings_alpha = slime_alpha
		var/list/drawn = limb.get_limb_icon(FALSE)
		var/per_zone = (limb.body_zone == BODY_ZONE_L_LEG || limb.body_zone == BODY_ZONE_R_LEG) ? 2 : 1
		var/list/zones = list(limb.body_zone)
		if(limb.aux_zone)
			zones += limb.aux_zone
		for(var/zone in zones)
			for(var/name in names)
				var/state = drawn_state(name, zone, limb)
				TEST_ASSERT_EQUAL(length(drawing(drawn, state)), per_zone, "[zone] must draw [state] on its own at alpha [slime_alpha]")
				TEST_ASSERT_EQUAL(length(drawing(drawn, state, TRUE)), per_zone, "[zone] must draw [state]'s glow on its own at alpha [slime_alpha]")

/// A dropped limb's merged markings and glow are images facing south, like the limb itself.
/datum/unit_test/body_marking_merge/dropped_limb
	/// The arm dropped off the body, deleted with the test.
	var/obj/item/bodypart/dropped_arm

/datum/unit_test/body_marking_merge/dropped_limb/Destroy()
	QDEL_NULL(dropped_arm)
	return ..()

/datum/unit_test/body_marking_merge/dropped_limb/Run()
	var/list/names = markings_baseline_marking_names()
	var/mob/living/carbon/human/body = dressed_body(markings_merge_fixture_fill())
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(special = TRUE)
	dropped_arm = arm
	var/list/drawn = arm.get_limb_icon(TRUE)
	for(var/zone in list(BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND))
		var/key = run_key(names, zone, arm)
		var/list/merged = drawing(drawn, key) + drawing(drawn, key, TRUE)
		TEST_ASSERT_EQUAL(length(merged), 2, "A dropped arm must draw [zone]'s markings and glows merged, one of each")
		for(var/image/overlay as anything in merged)
			TEST_ASSERT(!istype(overlay, /mutable_appearance) && overlay.dir == SOUTH, "A dropped arm's merged [zone] [PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE ? "glow" : "markings"] must face south like the arm")

/// A husk draws every marking the same grey, so each zone's markings merge whatever colours they wear; their glow stays.
/datum/unit_test/body_marking_merge/husk

/datum/unit_test/body_marking_merge/husk/Run()
	var/list/names = markings_baseline_marking_names()
	var/mob/living/carbon/human/body = dressed_body(markings_baseline_fill())
	body.become_husk(BURN)
	body.update_body_parts(update_limb_data = TRUE)
	for(var/obj/item/bodypart/limb as anything in body.bodyparts)
		TEST_ASSERT(limb.is_husked, "The fixture must husk [limb.body_zone]")
		var/list/drawn = limb.get_limb_icon(FALSE)
		var/per_zone = (limb.body_zone == BODY_ZONE_L_LEG || limb.body_zone == BODY_ZONE_R_LEG) ? 2 : 1
		var/list/zones = list(limb.body_zone)
		if(limb.aux_zone)
			zones += limb.aux_zone
		for(var/zone in zones)
			var/list/merged = drawing(drawn, run_key(names, zone, limb))
			TEST_ASSERT_EQUAL(length(merged), per_zone, "A husked [zone]'s three markings must draw as one appearance per layer")
			for(var/image/overlay as anything in merged)
				TEST_ASSERT(cmptext(overlay.color, "#888888"), "A husked [zone]'s markings must be grey")
			// The standard fixture lights only its second marking, which glows alone.
			TEST_ASSERT_EQUAL(length(drawing(drawn, drawn_state(names[2], zone, limb), TRUE)), per_zone, "A husked [zone] must keep its one glow")

/// Leg runs keep apart through the leg split, whose cache knows a merged icon only by its state: two bodies with different
/// runs on one leg each draw their own run's pixels on each layer, and a run in another colour shares the first one's icon.
/datum/unit_test/body_marking_merge/leg_runs

/datum/unit_test/body_marking_merge/leg_runs/Run()
	var/list/names = markings_baseline_marking_names()
	var/fixture_color = markings_merge_fixture_color()
	var/list/runs = list(list(names[1], names[2]), list(names[2], names[3]))
	var/list/masks = list(
		"[-BODYPARTS_LAYER]" = pixels_of(icon('icons/mob/leg_masks.dmi', "left_leg")),
		"[-BODYPARTS_LOW_LAYER]" = pixels_of(icon('icons/mob/leg_masks.dmi', "left_leg_lower")),
	)
	for(var/list/run_names as anything in runs)
		var/list/worn = list()
		for(var/name in run_names)
			worn[name] = list(fixture_color, 0)
		var/mob/living/carbon/human/body = dressed_body(list(BODY_ZONE_L_LEG = worn))
		var/obj/item/bodypart/leg = body.get_bodypart(BODY_ZONE_L_LEG)
		// The fixture art is opaque, so on each pixel the last marking drawn there shows.
		var/list/art
		for(var/name in run_names)
			var/datum/body_marking/marking = GLOB.body_markings[name]
			var/list/marking_pixels = pixels_of(icon(marking.icon, drawn_state(name, BODY_ZONE_L_LEG, leg)))
			if(!art)
				art = marking_pixels
				continue
			for(var/index in 1 to length(art))
				if(marking_pixels[index] != ".")
					art[index] = marking_pixels[index]
		var/key = run_key(run_names, BODY_ZONE_L_LEG, leg)
		var/list/halves = drawing(leg.get_limb_icon(FALSE), key)
		TEST_ASSERT_EQUAL(length(halves), 2, "[key] must be drawn on both layers of the leg")
		for(var/image/half as anything in halves)
			var/list/mask_pixels = masks["[half.layer]"]
			TEST_ASSERT(mask_pixels, "[key] must sit on one of the leg's two layers, not [half.layer]")
			if(!mask_pixels)
				continue
			var/list/expected = list()
			for(var/index in 1 to length(art))
				expected += mask_pixels[index] == "." ? "." : art[index]
			TEST_ASSERT_EQUAL(json_encode(pixels_of(icon(half.icon))), json_encode(expected), "[key] on layer [half.layer] must carry exactly its own run's pixels that the layer's mask keeps")
	// The same run in another colour draws from the same cached icon: its key holds no colour.
	var/list/first_run = runs[1]
	var/cached = length(GLOB.merged_body_marking_icons)
	var/mob/living/carbon/human/blue = dressed_body(list(BODY_ZONE_L_LEG = list("[first_run[1]]" = list("#2222aa", 0), "[first_run[2]]" = list("#2222aa", 0))))
	var/obj/item/bodypart/blue_leg = blue.get_bodypart(BODY_ZONE_L_LEG)
	var/blue_key = run_key(first_run, BODY_ZONE_L_LEG, blue_leg)
	TEST_ASSERT_EQUAL(length(drawing(blue_leg.get_limb_icon(FALSE), blue_key)), 2, "A run in another colour must merge the same way")
	TEST_ASSERT(GLOB.merged_body_marking_icons[blue_key] && length(GLOB.merged_body_marking_icons) == cached, "A run in another colour must draw from the cached icon, not a new one")

/// The merged icon cache keeps at most 256 runs, dropping the oldest first, and hands a cached run back as it is.
/datum/unit_test/body_marking_merge/cache_bound
	/// The cache as the test found it, restored afterwards so no other test notices.
	var/list/previous_cache

/datum/unit_test/body_marking_merge/cache_bound/Destroy()
	if(previous_cache)
		GLOB.merged_body_marking_icons = previous_cache
	return ..()

/datum/unit_test/body_marking_merge/cache_bound/Run()
	previous_cache = GLOB.merged_body_marking_icons
	GLOB.merged_body_marking_icons = list()
	var/datum/body_marking/marking = GLOB.body_markings[markings_baseline_marking_names()[1]]
	var/list/states = list()
	for(var/state in icon_states(marking.icon))
		if(length(states) >= 20)
			break
		states += state
	TEST_ASSERT_EQUAL(length(states), 20, "The fixture needs twenty states on one marking sheet")
	var/list/keys = list()
	var/list/last_parts
	for(var/first in states)
		for(var/second in states)
			if(first == second || length(keys) >= 300)
				continue
			last_parts = list(marking.icon, first, marking.icon, second)
			var/key = jointext(last_parts, "|")
			merged_body_marking_icon(last_parts, key)
			keys += key
	TEST_ASSERT_EQUAL(length(keys), 300, "The fixture must merge 300 distinct runs")
	TEST_ASSERT_EQUAL(length(GLOB.merged_body_marking_icons), 256, "The merged icon cache must hold at most 256 runs")
	TEST_ASSERT(!GLOB.merged_body_marking_icons[keys[1]] && GLOB.merged_body_marking_icons[keys[300]], "The merged icon cache must drop its oldest runs first")
	var/icon/cached = GLOB.merged_body_marking_icons[keys[300]]
	TEST_ASSERT(merged_body_marking_icon(last_parts, keys[300]) == cached && length(GLOB.merged_body_marking_icons) == 256, "A cached run must come back as it is")
