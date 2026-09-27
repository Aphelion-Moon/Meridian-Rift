/// Shared setup for the limb marking cache tests. Abstract, so the runner never runs it on its own.
/datum/unit_test/limb_marking_cache
	abstract_type = /datum/unit_test/limb_marking_cache

/**
 * Builds a body wearing the given markings and draws it the way a DNA change does.
 *
 * Arguments:
 * - raw: the markings in the nested shape a savefile holds, zone -> (marking name -> list(color, emissive)).
 *
 * Returns the new human.
 */
/datum/unit_test/limb_marking_cache/proc/dressed_body(list/raw)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.body_markings = body_marking_collection_from_list(raw)
	body.update_body_parts(update_limb_data = TRUE)
	return body

/**
 * Returns what a body shows for one limb: the cached appearances its current icon key names.
 *
 * Arguments:
 * - body: the body to look at.
 * - zone: the limb's body zone.
 */
/datum/unit_test/limb_marking_cache/proc/shown_icon(mob/living/carbon/human/body, zone)
	RETURN_TYPE(/list)
	return body.limb_icon_cache[body.icon_render_keys[zone]]

/**
 * Returns the visible appearances of a limb icon that draw one of the given icon states, as their states in draw order.
 *
 * Arguments:
 * - drawn: the limb icon's appearances.
 * - states: the icon states to pick out.
 */
/datum/unit_test/limb_marking_cache/proc/drawn_states(list/drawn, list/states)
	RETURN_TYPE(/list)
	. = list()
	for(var/image/overlay as anything in drawn)
		if(overlay && PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE && (overlay.icon_state in states))
			. += overlay.icon_state

/**
 * Returns the visible appearance of a limb icon that draws one icon state.
 *
 * Arguments:
 * - drawn: the limb icon's appearances.
 * - state: the icon state to find.
 *
 * Returns the first such appearance, or null.
 */
/datum/unit_test/limb_marking_cache/proc/drawn_state(list/drawn, state)
	for(var/image/overlay as anything in drawn)
		if(overlay && PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE && overlay.icon_state == state)
			return overlay
	return null

/**
 * Counts the glowing appearances of a limb icon. On these bodies only markings glow.
 *
 * Arguments:
 * - drawn: the limb icon's appearances.
 */
/datum/unit_test/limb_marking_cache/proc/count_glowing(list/drawn)
	. = 0
	for(var/image/overlay as anything in drawn)
		if(overlay && PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && markings_baseline_is_glowing(overlay))
			.++

/// Limbs hold the DNA's own zone lists instead of copies, and a detached limb keeps drawing the ones it last got.
/datum/unit_test/limb_marking_cache/zone_views
	/// The arm dropped off the body, deleted with the test.
	var/obj/item/bodypart/dropped_arm

/datum/unit_test/limb_marking_cache/zone_views/Destroy()
	QDEL_NULL(dropped_arm)
	return ..()

/datum/unit_test/limb_marking_cache/zone_views/Run()
	var/list/names = markings_baseline_marking_names()
	var/extra
	for(var/name in GLOB.body_markings_per_limb[BODY_ZONE_L_ARM])
		if(!(name in names))
			extra = name
			break
	TEST_ASSERT(extra, "The fixture needs a fourth left arm marking")
	var/mob/living/carbon/human/body = dressed_body(markings_baseline_fill())
	var/datum/body_marking_collection/dna_markings = body.dna.body_markings
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	var/list/arm_view = arm.markings
	var/list/hand_view = arm.aux_zone_markings
	TEST_ASSERT(length(arm_view) == length(names) && arm_view == dna_markings.entries_for_zone(BODY_ZONE_L_ARM), "A limb must hold the DNA's own list of its zone's markings, not a copy")
	TEST_ASSERT(length(hand_view) == length(names) && hand_view == dna_markings.entries_for_zone(BODY_ZONE_PRECISE_L_HAND), "A limb must hold the DNA's own list of its aux zone's markings, not a copy")
	body.update_body_parts()
	body.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT(arm.markings == arm_view && arm.aux_zone_markings == hand_view, "Updates that change no marking must leave a limb holding the same lists")

	// A structural change builds new lists rather than editing the ones limbs hold; a creating update hands them out.
	var/datum/body_marking_entry/added = new(GLOB.body_markings[extra], BODY_ZONE_L_ARM, "#abcdef", FALSE)
	TEST_ASSERT(dna_markings.add_entry(added), "The DNA must take a fourth left arm marking")
	TEST_ASSERT(arm.markings == arm_view && length(arm_view) == length(names), "A limb's list must not change under it before its next creating update")
	body.update_body_parts(update_limb_data = TRUE)
	var/list/new_arm_view = arm.markings
	var/list/new_hand_view = arm.aux_zone_markings
	TEST_ASSERT(new_arm_view != arm_view && new_arm_view == dna_markings.entries_for_zone(BODY_ZONE_L_ARM), "A creating update after a change must hand the limb the DNA's new list")
	TEST_ASSERT(length(new_arm_view) == length(names) + 1 && new_arm_view[length(new_arm_view)] == added, "The new list must hold the added marking last")
	TEST_ASSERT(length(arm_view) == length(names) && !(added in arm_view), "The list handed out before the change must keep what it held")

	// A detached limb goes on drawing the lists it last got, whatever its former owner's markings do next.
	var/arm_snapshot = json_encode(body_marking_entries_to_list(new_arm_view))
	var/hand_snapshot = json_encode(body_marking_entries_to_list(new_hand_view))
	arm.drop_limb(special = TRUE)
	dropped_arm = arm
	TEST_ASSERT(isnull(arm.owner) && arm.markings == new_arm_view && arm.aux_zone_markings == new_hand_view, "Dropping a limb must leave it the lists it held")
	var/detached_key = arm.get_cache_key()
	TEST_ASSERT(findtext(detached_key, "_#abcdef_0;"), "A detached limb's icon key must stand for the markings it holds: [detached_key]")
	TEST_ASSERT(dna_markings.remove_entry(added), "The former owner must lose the added marking")
	dna_markings.set_zone_entries(BODY_ZONE_PRECISE_L_HAND, list())
	body.update_body_parts(update_limb_data = TRUE)
	// A recolour elsewhere on the former owner makes the detached limb rebuild its key, now from its own entries.
	var/datum/body_marking_entry/head_marking = dna_markings.find_entry(BODY_ZONE_HEAD, names[1])
	head_marking.set_color("#010203")
	TEST_ASSERT(arm.markings == new_arm_view && json_encode(body_marking_entries_to_list(arm.markings)) == arm_snapshot, "A detached limb must keep the markings it had")
	TEST_ASSERT(arm.aux_zone_markings == new_hand_view && json_encode(body_marking_entries_to_list(arm.aux_zone_markings)) == hand_snapshot, "A detached limb must keep the aux zone markings it had")
	TEST_ASSERT_EQUAL(arm.get_cache_key(), detached_key, "A detached limb's icon key must go on standing for the markings it kept")

/// A limb's icon key tells apart every marking state that draws differently, so no body shows another's cached limb.
/datum/unit_test/limb_marking_cache/icon_keys

/datum/unit_test/limb_marking_cache/icon_keys/Run()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	var/datum/body_marking/first = GLOB.body_markings[names[1]]
	var/datum/body_marking/second = GLOB.body_markings[names[2]]
	var/first_state = "[first.icon_state]_[BODY_ZONE_L_ARM]"
	var/second_state = "[second.icon_state]_[BODY_ZONE_L_ARM]"
	var/list/both_states = list(first_state, second_state)
	var/list/in_order = list("[names[1]]" = list(colors[1], 0), "[names[2]]" = list(colors[2], 0))
	var/mob/living/carbon/human/opaque = dressed_body(list(BODY_ZONE_L_ARM = in_order))
	var/opaque_key = opaque.icon_render_keys[BODY_ZONE_L_ARM]
	TEST_ASSERT_EQUAL(json_encode(drawn_states(shown_icon(opaque, BODY_ZONE_L_ARM), both_states)), json_encode(both_states), "The fixture arm must draw both markings, in order")

	// Alpha: roundstartslime draws its markings translucent, so it must never be shown an opaque body's cached arm.
	var/slime_alpha = /datum/species/jelly/roundstartslime::markings_alpha
	TEST_ASSERT_NOTEQUAL(slime_alpha, 255, "The fixture needs the slime's reduced marking alpha")
	var/mob/living/carbon/human/translucent = dressed_body(list(BODY_ZONE_L_ARM = in_order))
	TEST_ASSERT_EQUAL(translucent.icon_render_keys[BODY_ZONE_L_ARM], opaque_key, "Two identically dressed arms must share one cached icon")
	var/obj/item/bodypart/translucent_arm = translucent.get_bodypart(BODY_ZONE_L_ARM)
	translucent_arm.markings_alpha = slime_alpha
	translucent.update_body_parts()
	TEST_ASSERT_NOTEQUAL(translucent.icon_render_keys[BODY_ZONE_L_ARM], opaque_key, "Markings at another alpha must not share a cached icon")
	for(var/state in both_states)
		var/image/translucent_marking = drawn_state(shown_icon(translucent, BODY_ZONE_L_ARM), state)
		var/image/opaque_marking = drawn_state(shown_icon(opaque, BODY_ZONE_L_ARM), state)
		TEST_ASSERT(translucent_marking?.alpha == slime_alpha && opaque_marking?.alpha == 255, "Each arm must show [state] at its own marking alpha")

	// Order: markings on one layer overlap in the order they are worn.
	var/mob/living/carbon/human/reordered = dressed_body(list(BODY_ZONE_L_ARM = list("[names[2]]" = list(colors[2], 0), "[names[1]]" = list(colors[1], 0))))
	TEST_ASSERT_NOTEQUAL(reordered.icon_render_keys[BODY_ZONE_L_ARM], opaque_key, "The same markings in another order must not share a cached icon")
	TEST_ASSERT_EQUAL(json_encode(drawn_states(shown_icon(reordered, BODY_ZONE_L_ARM), both_states)), json_encode(list(second_state, first_state)), "A reordered arm must draw its markings in its own order")

	// Glow.
	var/mob/living/carbon/human/lit = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(colors[1], 1), "[names[2]]" = list(colors[2], 0))))
	TEST_ASSERT_NOTEQUAL(lit.icon_render_keys[BODY_ZONE_L_ARM], opaque_key, "A glowing marking must not share a cached icon with an unlit one")
	TEST_ASSERT_EQUAL(count_glowing(shown_icon(lit, BODY_ZONE_L_ARM)), 1, "An arm with a glowing marking must show its glow")
	TEST_ASSERT_EQUAL(count_glowing(shown_icon(opaque, BODY_ZONE_L_ARM)), 0, "An arm without glowing markings must show no glow")

	// A recolour reaches every holder of the entry at once, so the next plain update must key and draw the new colour.
	var/datum/body_marking_entry/recoloured = opaque.dna.body_markings.find_entry(BODY_ZONE_L_ARM, names[1])
	recoloured.set_color("#123456")
	opaque.update_body_parts()
	var/recoloured_key = opaque.icon_render_keys[BODY_ZONE_L_ARM]
	TEST_ASSERT(findtext(recoloured_key, "#123456") && !findtext(recoloured_key, colors[1]), "A recoloured marking must key its limb by its new colour: [recoloured_key]")
	var/image/recoloured_marking = drawn_state(shown_icon(opaque, BODY_ZONE_L_ARM), first_state)
	TEST_ASSERT(cmptext(recoloured_marking?.color, "#123456"), "A recoloured marking must be drawn in its new colour")

/// A husk draws its markings grey but keeps their glow, so husks differing only in glow must not share a cached limb.
/datum/unit_test/limb_marking_cache/husk_keys

/datum/unit_test/limb_marking_cache/husk_keys/Run()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	var/mob/living/carbon/human/dim = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(colors[1], 0))))
	var/mob/living/carbon/human/glowing = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(colors[1], 1))))
	for(var/mob/living/carbon/human/husk as anything in list(dim, glowing))
		husk.become_husk(BURN)
		husk.update_body_parts(update_limb_data = TRUE)
	var/obj/item/bodypart/dim_arm = dim.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(dim_arm.is_husked, "The fixture must husk the arm")
	var/glowing_key = glowing.icon_render_keys[BODY_ZONE_L_ARM]
	TEST_ASSERT_NOTEQUAL(dim.icon_render_keys[BODY_ZONE_L_ARM], glowing_key, "Husks whose markings differ in glow must not share a cached icon")
	TEST_ASSERT_EQUAL(count_glowing(shown_icon(glowing, BODY_ZONE_L_ARM)), 1, "A husk must show its glowing marking's glow")
	TEST_ASSERT_EQUAL(count_glowing(shown_icon(dim, BODY_ZONE_L_ARM)), 0, "A husk without glowing markings must show no glow")
	// A marking that starts glowing reaches the husk on its next plain update, which then draws like the glowing one.
	var/datum/body_marking_entry/relit = dim.dna.body_markings.find_entry(BODY_ZONE_L_ARM, names[1])
	relit.set_emissive(TRUE)
	dim.update_body_parts()
	TEST_ASSERT_EQUAL(dim.icon_render_keys[BODY_ZONE_L_ARM], glowing_key, "A husk whose marking starts glowing must share the glowing husk's cached icon")
	TEST_ASSERT_EQUAL(count_glowing(shown_icon(dim, BODY_ZONE_L_ARM)), 1, "A husk whose marking starts glowing must show the glow")
