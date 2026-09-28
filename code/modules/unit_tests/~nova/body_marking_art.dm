/// Shared setup for the body marking art tests. Abstract, so the runner never runs it on its own.
/datum/unit_test/body_marking_art
	abstract_type = /datum/unit_test/body_marking_art

/**
 * Builds a body wearing one marking on the given zones and draws it the way a DNA change does.
 *
 * Arguments:
 * - marking: the marking to wear. It need not be registered in GLOB.body_markings.
 * - zones: the marking zones to wear it on.
 * - digitigrade: TRUE to stand the body on digitigrade legs first.
 * - emissive: TRUE for glowing entries, so a marking's glow is drawn or left out with it.
 *
 * Returns the new human.
 */
/datum/unit_test/body_marking_art/proc/dressed_body(datum/body_marking/marking, list/zones, digitigrade = FALSE, emissive = FALSE)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	if(digitigrade)
		for(var/zone, leg_type in list(BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/digitigrade, BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/digitigrade))
			// try_attach_limb() stack traces over a limb still in its zone, so the old leg goes first.
			var/obj/item/bodypart/old_leg = body.get_bodypart(zone)
			old_leg.drop_limb(special = TRUE)
			qdel(old_leg)
			var/obj/item/bodypart/leg/new_leg = new leg_type()
			new_leg.try_attach_limb(body, special = TRUE)
	body.dna.body_markings = new
	for(var/zone in zones)
		body.dna.body_markings.add_entry(new /datum/body_marking_entry(marking, zone, "#cc3344", emissive))
	body.update_body_parts(update_limb_data = TRUE)
	return body

/**
 * Returns how many appearances in a list draw an icon state. A marking, its glow and each half of a split leg count apart.
 *
 * Arguments:
 * - appearances: a limb's appearances, as get_limb_icon() returns them.
 * - icon_state: the state to count.
 */
/datum/unit_test/body_marking_art/proc/count_state(list/appearances, icon_state)
	. = 0
	for(var/image/appearance as anything in appearances)
		if(appearance?.icon_state == icon_state)
			.++

/// Every zone a body marking claims has its art. For each marking in GLOB.body_markings and each zone in its
/// affected_bodyparts, every icon state the limb renderer can ask of zone_icon_state() there must be on the marking's sheet:
/// both physiques of a gendered chest, each leg shape leg_shapes keeps, and the hands, an arm's aux zone. A claimed zone is
/// offered in character setup, so a missing state is a marking players can pick that draws nothing.
/datum/unit_test/body_marking_art/claimed_zones

/datum/unit_test/body_marking_art/claimed_zones/Run()
	// icon -> state -> TRUE: each sheet's states, read once.
	var/list/sheets = list()
	var/list/missing = list()
	for(var/name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/marking = marking_datum
		if(!marking.icon)
			missing += "[name] ([marking.type]) has no icon"
			continue
		var/list/states = sheets[marking.icon]
		if(!states)
			states = list()
			for(var/state in icon_states(marking.icon))
				states[state] = TRUE
			sheets[marking.icon] = states
		for(var/zone in GLOB.marking_zones)
			if(!(marking.affected_bodyparts & GLOB.marking_zone_to_bitflag[zone]))
				continue
			// Every shape and physique a limb on this zone can have: a leg's two shapes, a chest's two physiques.
			var/list/shapes = (zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG) ? list(FALSE, TRUE) : list(FALSE)
			var/list/physiques = zone == BODY_ZONE_CHEST ? list("m", "f") : list("m")
			var/list/requested = list()
			for(var/digitigrade in shapes)
				for(var/limb_gender in physiques)
					// Null is a leg shape the marking leaves out.
					var/state = marking.zone_icon_state(zone, digitigrade, limb_gender)
					if(state)
						requested |= state
			if(!length(requested))
				missing += "[name] ([marking.type]) claims [zone] but draws nothing there"
			for(var/state in requested)
				if(!states[state])
					missing += "[name] ([marking.type]) claims [zone], which asks for [state], missing from [marking.icon]"
	TEST_ASSERT(!length(missing), "Body markings claim zones their sheets have no art for:\n[jointext(missing, "\n")]")

/// Every state on a body marking sheet is art some marking claims: a state no marking claims is art a marking lost or a
/// duplicate, and must not come back unnoticed. A body marking sheet is one under icons/mob/body_markings/ that a marking in
/// GLOB.body_markings draws from; the states a sheet keeps though no marking claims them are listed here with the reason.
/datum/unit_test/body_marking_art/unclaimed_states

/datum/unit_test/body_marking_art/unclaimed_states/Run()
	// sheet -> state -> TRUE: every state a marking asks of its sheet on a zone it claims, walked as claimed_zones walks them.
	var/list/sheets = list()
	for(var/name, marking_datum in GLOB.body_markings)
		var/datum/body_marking/marking = marking_datum
		if(!findtext("[marking.icon]", "icons/mob/body_markings/"))
			continue
		var/list/states = sheets[marking.icon]
		if(!states)
			states = list()
			sheets[marking.icon] = states
		for(var/zone in GLOB.marking_zones)
			if(!(marking.affected_bodyparts & GLOB.marking_zone_to_bitflag[zone]))
				continue
			var/list/shapes = (zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG) ? list(FALSE, TRUE) : list(FALSE)
			var/list/physiques = zone == BODY_ZONE_CHEST ? list("m", "f") : list("m")
			for(var/digitigrade in shapes)
				for(var/limb_gender in physiques)
					var/state = marking.zone_icon_state(zone, digitigrade, limb_gender)
					if(state)
						states[state] = TRUE
	// sheet path -> the states it keeps though no marking claims them
	var/list/kept = list(
		// Its unnamed default state, blank: a missing state never falls back to it, as the renderer draws nothing instead.
		"modular_nova/master_files/icons/mob/body_markings/akula_markings.dmi" = list(""),
	)
	var/list/unclaimed = list()
	for(var/sheet, states in sheets)
		for(var/state in icon_states(sheet))
			if(!states[state] && !(state in kept["[sheet]"]))
				unclaimed += "[sheet]: \"[state]\""
	TEST_ASSERT_EQUAL(length(sheets), 11, "The walk must reach every body marking sheet")
	TEST_ASSERT(!length(unclaimed), "Body marking sheets hold states no marking claims:\n[jointext(unclaimed, "\n")]")

/// A marking draws nothing where its sheet lacks the state a zone asks for, glow included, rather than the sheet's default
/// state: a zone claimed without art, or one a save holds that the marking no longer claims. A zone it has art for draws.
/datum/unit_test/body_marking_art/missing_state

/datum/unit_test/body_marking_art/missing_state/Run()
	// An opaque default state, which a missing one would fall back to, and art for the left arm but not its hand.
	var/icon/tile = icon('icons/blanks/32x32.dmi', "nothing")
	tile.DrawBox("#ffffff", 1, 1, 32, 32)
	var/icon/art = icon(tile)
	for(var/direction in GLOB.cardinals)
		art.Insert(tile, "", direction)
		art.Insert(tile, "art_test_[BODY_ZONE_L_ARM]", direction)
	var/datum/body_marking/marking = new
	marking.name = "Art test [REF(src)]"
	marking.icon = art
	marking.icon_state = "art_test"
	marking.affected_bodyparts = ARM_LEFT | HAND_LEFT
	var/drawn_state = marking.zone_icon_state(BODY_ZONE_L_ARM)
	var/missing_state = marking.zone_icon_state(BODY_ZONE_PRECISE_L_HAND)
	var/mob/living/carbon/human/body = dressed_body(marking, list(BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND), emissive = TRUE)
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_EQUAL(length(arm.markings) + length(arm.aux_zone_markings), 2, "The arm must wear the marking on itself and on its hand")
	var/list/drawn = arm.get_limb_icon(FALSE)
	TEST_ASSERT_EQUAL(count_state(drawn, drawn_state), 2, "The arm must draw the marking and its glow where the sheet has art")
	TEST_ASSERT_EQUAL(count_state(drawn, missing_state), 0, "The hand must draw neither the marking nor its glow where the sheet has no art")
	// All the marked arm draws beyond the bare arm is the arm's marking and its glow.
	var/marked_count = length(drawn)
	arm.markings = null
	arm.aux_zone_markings = null
	TEST_ASSERT_EQUAL(marked_count, length(arm.get_limb_icon(FALSE)) + 2, "A marking state missing from its sheet must add no appearance")

/// A marking with art for one leg shape draws on legs of that shape and on no other, even where its sheet has art for both.
/datum/unit_test/body_marking_art/leg_shapes

/datum/unit_test/body_marking_art/leg_shapes/Run()
	// A fixture marking's art, which has both leg shapes, so only leg_shapes can keep the plantigrade one off.
	var/datum/body_marking/source = GLOB.body_markings[markings_baseline_marking_names()[1]]
	var/plantigrade_state = source.zone_icon_state(BODY_ZONE_L_LEG, FALSE)
	var/digitigrade_state = source.zone_icon_state(BODY_ZONE_L_LEG, TRUE)
	TEST_ASSERT(icon_exists(source.icon, plantigrade_state) && icon_exists(source.icon, digitigrade_state), "The fixture marking must have art for both leg shapes")
	var/datum/body_marking/marking = new
	marking.name = "Leg shape test [REF(src)]"
	marking.icon = source.icon
	marking.icon_state = source.icon_state
	marking.affected_bodyparts = LEG_LEFT
	marking.leg_shapes = MARKING_LEG_DIGITIGRADE
	TEST_ASSERT_NULL(marking.zone_icon_state(BODY_ZONE_L_LEG, FALSE), "A digitigrade-only marking must ask for nothing on a plantigrade leg")
	TEST_ASSERT_EQUAL(marking.zone_icon_state(BODY_ZONE_L_LEG, TRUE), digitigrade_state, "A digitigrade-only marking must ask for its digitigrade art on a digitigrade leg")
	var/mob/living/carbon/human/plantigrade_body = dressed_body(marking, list(BODY_ZONE_L_LEG))
	var/obj/item/bodypart/plantigrade_leg = plantigrade_body.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(!(plantigrade_leg.bodyshape & BODYSHAPE_DIGITIGRADE) && length(plantigrade_leg.markings), "The plantigrade fixture leg must wear the marking")
	var/list/plantigrade_drawn = plantigrade_leg.get_limb_icon(FALSE)
	TEST_ASSERT_EQUAL(count_state(plantigrade_drawn, plantigrade_state) + count_state(plantigrade_drawn, digitigrade_state), 0, "A digitigrade-only marking must draw nothing on a plantigrade leg")
	var/mob/living/carbon/human/digitigrade_body = dressed_body(marking, list(BODY_ZONE_L_LEG), digitigrade = TRUE)
	var/obj/item/bodypart/digitigrade_leg = digitigrade_body.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT((digitigrade_leg.bodyshape & BODYSHAPE_DIGITIGRADE) && length(digitigrade_leg.markings), "The digitigrade fixture leg must wear the marking")
	// Split over the leg's two layers, like the leg itself.
	TEST_ASSERT_EQUAL(count_state(digitigrade_leg.get_limb_icon(FALSE), digitigrade_state), 2, "A digitigrade-only marking must draw on a digitigrade leg")
