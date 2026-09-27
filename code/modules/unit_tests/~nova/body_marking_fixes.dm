/// Shared setup for the tests of the body marking bug fixes. Abstract, so the runner never runs it on its own.
/datum/unit_test/body_marking_fixes
	abstract_type = /datum/unit_test/body_marking_fixes

/**
 * Builds a body wearing the given markings and draws it the way a DNA change does.
 *
 * Arguments:
 * - raw: the markings in the nested shape a savefile holds, zone -> (marking name -> list(color, emissive)).
 *
 * Returns the new human.
 */
/datum/unit_test/body_marking_fixes/proc/dressed_body(list/raw)
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	body.dna.body_markings = body_marking_collection_from_list(raw)
	body.update_body_parts(update_limb_data = TRUE)
	return body

/**
 * Returns the icon state a marking draws on a zone other than the chest, on a plantigrade leg.
 *
 * Arguments:
 * - name: the marking's name.
 * - zone: the zone it is drawn on.
 */
/datum/unit_test/body_marking_fixes/proc/marking_state(name, zone)
	var/datum/body_marking/marking = GLOB.body_markings[name]
	return "[marking.icon_state]_[zone]"

/**
 * Returns every pixel of an icon's only state, facings in GLOB.cardinals order, a clear pixel as ".".
 *
 * Arguments:
 * - source: an icon holding one state, as icon(file, state) and the leg masks make them.
 */
/datum/unit_test/body_marking_fixes/proc/pixels_of(icon/source)
	RETURN_TYPE(/list)
	. = list()
	for(var/direction in GLOB.cardinals)
		for(var/y in 1 to source.Height())
			for(var/x in 1 to source.Width())
				var/pixel = source.GetPixel(x, y, "", direction)
				. += isnull(pixel) ? "." : pixel

/// A body dressed from a character owns its markings: recolouring the body never reaches the saved character,
/// and recolouring the character in setup never reaches a body already dressed from it.
/datum/unit_test/body_marking_fixes/dressed_body_owns_markings

/datum/unit_test/body_marking_fixes/dressed_body_owns_markings/Run()
	var/list/names = markings_baseline_marking_names()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	preferences.body_markings = body_marking_collection_from_list(markings_baseline_fill())
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	middleware.apply_to_human(body, preferences)
	var/saved = json_encode(preferences.body_markings.serialize())
	TEST_ASSERT_EQUAL(json_encode(body.dna.body_markings.serialize()), saved, "A dressed body must wear its character's markings, glow included")
	var/datum/body_marking_entry/worn = body.dna.body_markings.find_entry(BODY_ZONE_CHEST, names[1])
	TEST_ASSERT(worn && worn != preferences.body_markings.find_entry(BODY_ZONE_CHEST, names[1]), "A dressed body must hold entries of its own")
	// What the fur dyer and a slime's colour reset do to a live body.
	worn.set_color("#123456")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved, "Recolouring a body must leave its character's saved markings alone")
	var/dressed = json_encode(body.dna.body_markings.serialize())
	preferences.body_markings.find_entry(BODY_ZONE_HEAD, names[2]).set_color("#654321")
	TEST_ASSERT_EQUAL(json_encode(body.dna.body_markings.serialize()), dressed, "Recolouring the character in setup must leave a body already dressed from it alone")

/// The fur dyer recolours the marking the body wears once the painting is done, as its markings are by then.
/datum/unit_test/body_marking_fixes/fur_dyer

/datum/unit_test/body_marking_fixes/fur_dyer/Run()
	var/list/names = markings_baseline_marking_names()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.body_markings = body_marking_collection_from_list(markings_baseline_fill())
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	middleware.apply_to_human(body, preferences)
	var/saved = json_encode(preferences.body_markings.serialize())
	var/obj/item/fur_dyer/dyer = allocate(/obj/item/fur_dyer)
	// The body's markings change while it is being painted: a zone is emptied, which a snapshot taken before would bring back.
	body.dna.body_markings.set_zone_entries(BODY_ZONE_HEAD, null)
	TEST_ASSERT(dyer.finish_marking_dye(body, BODY_ZONE_CHEST, names[1], "#abcdef"), "The dyer must recolour a marking the body still wears")
	TEST_ASSERT_EQUAL(body.dna.body_markings.find_entry(BODY_ZONE_CHEST, names[1])?.get_color(), "#abcdef", "The painted marking must take the new colour")
	TEST_ASSERT(body.dna.body_markings.has_zone(BODY_ZONE_HEAD) && !body.dna.body_markings.zone_length(BODY_ZONE_HEAD), "Painting must keep what happened to the body's markings while it was being painted")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), saved, "Painting a body must leave its player's saved markings alone")
	// A marking lost while it was being painted is left alone.
	body.dna.body_markings.remove_entry(body.dna.body_markings.find_entry(BODY_ZONE_CHEST, names[2]))
	var/before = json_encode(body.dna.body_markings.serialize())
	TEST_ASSERT(!dyer.finish_marking_dye(body, BODY_ZONE_CHEST, names[2], "#fedcba"), "The dyer must not paint a marking the body lost")
	TEST_ASSERT_EQUAL(json_encode(body.dna.body_markings.serialize()), before, "A lost marking must leave the body's markings as they are")

/// A dropped limb draws its markings and their glow facing south, like the limb itself; an attached one lets them turn with the body.
/datum/unit_test/body_marking_fixes/dropped_limb_facing
	/// The arm dropped off the body, deleted with the test.
	var/obj/item/bodypart/dropped_arm

/datum/unit_test/body_marking_fixes/dropped_limb_facing/Destroy()
	QDEL_NULL(dropped_arm)
	return ..()

/datum/unit_test/body_marking_fixes/dropped_limb_facing/Run()
	var/list/states = list()
	for(var/name in markings_baseline_marking_names())
		states += marking_state(name, BODY_ZONE_L_ARM)
		states += marking_state(name, BODY_ZONE_PRECISE_L_HAND)
	var/mob/living/carbon/human/body = dressed_body(markings_baseline_fill())
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	// Only image() given a dir sets the flag that keeps an overlay's own facing (make_mutable_appearance_directional()),
	// so a marking drawn as a plain mutable appearance turns with whatever it is drawn on.
	var/attached = 0
	for(var/image/overlay as anything in arm.get_limb_icon(FALSE))
		if(!(overlay.icon_state in states))
			continue
		attached++
		TEST_ASSERT(istype(overlay, /mutable_appearance), "An attached arm's [overlay.icon_state] must turn with the body")
	arm.drop_limb(special = TRUE)
	dropped_arm = arm
	var/limb_state = "[arm.limb_id]_[BODY_ZONE_L_ARM]"
	var/limb_faces_south = FALSE
	var/dropped = 0
	for(var/image/overlay as anything in arm.get_limb_icon(TRUE))
		var/glow = PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE
		if(overlay.icon_state == limb_state && !glow)
			limb_faces_south = !istype(overlay, /mutable_appearance) && overlay.dir == SOUTH
		if(!(overlay.icon_state in states))
			continue
		dropped++
		TEST_ASSERT(!istype(overlay, /mutable_appearance) && overlay.dir == SOUTH, "A dropped arm's [overlay.icon_state][glow ? " glow" : ""] must face south like the arm")
	TEST_ASSERT(limb_faces_south, "The fixture's dropped arm must itself be drawn facing south")
	TEST_ASSERT(dropped && dropped == attached, "A dropped arm must draw the markings and glow it drew attached ([dropped] against [attached])")

/// Leg markings and their glow are split over the leg's two layers like the leg: each half carries exactly the
/// marking's pixels that its layer's mask keeps, and a glow's halves stay top-level emissive appearances.
/datum/unit_test/body_marking_fixes/leg_split

/datum/unit_test/body_marking_fixes/leg_split/Run()
	var/mob/living/carbon/human/body = dressed_body(markings_baseline_fill())
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg = body.get_bodypart(zone)
		var/list/drawn = leg.get_limb_icon(FALSE)
		var/mask_state = zone == BODY_ZONE_R_LEG ? "right_leg" : "left_leg"
		var/list/masks = list(
			"[-BODYPARTS_LAYER]" = pixels_of(icon('icons/mob/leg_masks.dmi', mask_state)),
			"[-BODYPARTS_LOW_LAYER]" = pixels_of(icon('icons/mob/leg_masks.dmi', "[mask_state]_lower")),
		)
		for(var/layer_key, mask in masks)
			var/list/mask_pixels = mask
			var/binary = TRUE
			for(var/pixel in mask_pixels)
				if(pixel != "." && pixel != "#ffffff")
					binary = FALSE
			TEST_ASSERT(binary, "The [zone] mask for layer [layer_key] must be opaque white or clear, or masking changes colours")
		TEST_ASSERT(length(leg.markings), "The fixture's [zone] must wear markings")
		for(var/datum/body_marking_entry/entry as anything in leg.markings)
			var/state = marking_state(entry.marking.name, zone)
			var/list/art = pixels_of(icon(entry.marking.icon, state))
			// Per layer, the art's pixels where that layer's mask is opaque and nothing elsewhere.
			var/list/expected = list()
			for(var/layer_key, mask in masks)
				var/list/mask_pixels = mask
				var/list/kept = list()
				for(var/index in 1 to length(art))
					kept += mask_pixels[index] == "." ? "." : art[index]
				expected[layer_key] = kept
			var/lower_pixels = 0
			for(var/pixel in expected["[-BODYPARTS_LOW_LAYER]"])
				if(pixel != ".")
					lower_pixels++
			TEST_ASSERT(lower_pixels, "[state] must have pixels on the leg's lower layer, or this test proves nothing")
			var/list/visible_halves = list()
			var/list/glow_halves = list()
			for(var/image/overlay as anything in drawn)
				if(overlay.icon_state != state)
					continue
				if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE)
					glow_halves += overlay
				else
					visible_halves += overlay
			var/list/halves = visible_halves.Copy()
			if(entry.get_emissive())
				TEST_ASSERT_EQUAL(length(glow_halves), 2, "[state]'s glow must be split over both layers of the leg")
				halves += glow_halves
			else
				TEST_ASSERT(!length(glow_halves), "[state] must not glow")
			TEST_ASSERT_EQUAL(length(visible_halves), 2, "[state] must be drawn on both layers of the leg")
			var/list/layers_seen = list()
			for(var/image/half as anything in halves)
				var/glow = PLANE_TO_TRUE(half.plane) == EMISSIVE_PLANE
				var/layer_key = "[half.layer]"
				TEST_ASSERT(expected[layer_key], "[state][glow ? " glow" : ""] must sit on one of the leg's two layers, not [half.layer]")
				if(!expected[layer_key])
					continue
				layers_seen["[glow]|[layer_key]"] = TRUE
				TEST_ASSERT_EQUAL(json_encode(pixels_of(icon(half.icon))), json_encode(expected[layer_key]), "[state][glow ? " glow" : ""] on layer [layer_key] must carry exactly the marking's pixels that layer's mask keeps")
				TEST_ASSERT(!length(half.overlays) && !length(half.underlays), "[state][glow ? " glow" : ""] on layer [layer_key] must not nest anything")
				if(glow)
					TEST_ASSERT(markings_baseline_is_glowing(half) && half.appearance_flags == EMISSIVE_APPEARANCE_FLAGS, "[state]'s glow on layer [layer_key] must stay a top-level emissive appearance")
			TEST_ASSERT_EQUAL(length(layers_seen), length(halves), "[state] must put one half on each layer of the leg")

/// A marking's glow fades with the marking, as the visible marking does.
/datum/unit_test/body_marking_fixes/emissive_alpha

/datum/unit_test/body_marking_fixes/emissive_alpha/Run()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	var/mob/living/carbon/human/body = dressed_body(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(colors[1], 1))))
	var/obj/item/bodypart/arm = body.get_bodypart(BODY_ZONE_L_ARM)
	var/state = marking_state(names[1], BODY_ZONE_L_ARM)
	// 130 is roundstartslime's marking alpha, the one species that lowers it.
	for(var/marking_alpha in list(255, /datum/species/jelly/roundstartslime::markings_alpha))
		arm.markings_alpha = marking_alpha
		var/image/visible
		var/image/glow
		for(var/image/overlay as anything in arm.get_limb_icon(FALSE))
			if(overlay.icon_state != state)
				continue
			if(PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE)
				glow = overlay
			else
				visible = overlay
		TEST_ASSERT_EQUAL(visible?.alpha, marking_alpha, "The fixture marking must be drawn at alpha [marking_alpha]")
		// An emissive's strength is the constant row of its colour matrix (_EMISSIVE_COLOR()).
		var/list/glow_matrix = glow?.color
		TEST_ASSERT(islist(glow_matrix) && abs(glow_matrix[17] - marking_alpha / 255) < 0.001, "A marking drawn at alpha [marking_alpha] must glow at [marking_alpha]/255, not [islist(glow_matrix) ? glow_matrix[17] : "nothing"]")

/// A limb that never ran a creating update, given markings as the salon gives them, draws them opaque rather than invisible.
/datum/unit_test/body_marking_fixes/default_marking_alpha

/datum/unit_test/body_marking_fixes/default_marking_alpha/Run()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	var/obj/item/bodypart/arm/left/arm = allocate(/obj/item/bodypart/arm/left)
	arm.markings = body_marking_entries_from_list(BODY_ZONE_L_ARM, list("[names[1]]" = list(colors[1], 0)))
	var/state = marking_state(names[1], BODY_ZONE_L_ARM)
	var/image/drawn_marking
	for(var/image/overlay as anything in arm.get_limb_icon(TRUE))
		if(overlay.icon_state == state)
			drawn_marking = overlay
	TEST_ASSERT(drawn_marking, "The loose arm must draw the marking it was given")
	TEST_ASSERT_EQUAL(drawn_marking?.alpha, 255, "A limb no body has dressed must draw its markings opaque")

/// A marking preset merges into the zones it covers, the "None" preset clears every zone, and a name no set has changes nothing.
/datum/unit_test/body_marking_fixes/preset

/datum/unit_test/body_marking_fixes/preset/Run()
	// A set with two markings on one zone, so their order shows, and a zone it leaves alone.
	var/datum/body_marking_set/marking_set
	var/list/touched
	for(var/set_name, set_datum in GLOB.body_marking_sets)
		var/datum/body_marking_set/candidate = set_datum
		var/list/candidate_zones = list()
		var/stacked = FALSE
		for(var/zone in GLOB.marking_zones)
			var/list/on_zone = list()
			for(var/name in candidate.body_marking_list)
				if(name in GLOB.body_markings_per_limb[zone])
					on_zone += name
			if(length(on_zone))
				candidate_zones[zone] = on_zone
			stacked ||= length(on_zone) > 1
		if(stacked && length(candidate_zones) < length(GLOB.marking_zones))
			marking_set = candidate
			touched = candidate_zones
			break
	TEST_ASSERT(marking_set, "The fixture needs a marking set with two markings on one zone that leaves another zone alone")
	var/datum/body_marking_set/none_set = GLOB.body_marking_sets[SPRITE_ACCESSORY_NONE]
	TEST_ASSERT(none_set && !length(none_set.body_marking_list), "The fixture needs the None set, which holds no markings")
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	preferences.body_markings = body_marking_collection_from_list(markings_baseline_fill())
	var/list/before = preferences.body_markings.serialize()
	var/before_text = json_encode(before)
	// Names no set has return quietly and change nothing.
	for(var/bad_preset in list("Not A Marking Set", 3, null))
		TEST_ASSERT(!middleware.set_preset(list("preset" = bad_preset), mock_client.mob), "A preset named [bad_preset] must be refused")
		TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), before_text, "A refused preset named [bad_preset] must leave the markings alone")
	TEST_ASSERT(middleware.set_preset(list("preset" = marking_set.name), mock_client.mob), "The [marking_set.name] preset must apply")
	var/list/after = preferences.body_markings.serialize()
	TEST_ASSERT_EQUAL(json_encode(assoc_to_keys(after)), json_encode(assoc_to_keys(before)), "A preset must keep every zone in its place")
	for(var/zone in GLOB.marking_zones)
		if(touched[zone])
			TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.marking_names(zone)), json_encode(touched[zone]), "The [marking_set.name] preset must replace [zone]'s markings with its own, in its order")
		else
			TEST_ASSERT_EQUAL(json_encode(after[zone]), json_encode(before[zone]), "The [marking_set.name] preset must leave [zone], which it does not cover, as it was")
	TEST_ASSERT(middleware.set_preset(list("preset" = SPRITE_ACCESSORY_NONE), mock_client.mob), "The None preset must apply")
	TEST_ASSERT(!preferences.body_markings.zone_count(), "The None preset must clear every zone")
	TEST_ASSERT_EQUAL(json_encode(preferences.body_markings.serialize()), "\[]", "Markings the None preset cleared must save as none")

/// The character's allow_emissives preference gates marking glow: character setup cannot turn one on while it is off,
/// and a body dressed while it is off does not glow, while the saved glow stays saved.
/datum/unit_test/body_marking_fixes/emissive_gate

/datum/unit_test/body_marking_fixes/emissive_gate/Run()
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.create_character_preview_view(mock_client.mob)
	var/datum/preference_middleware/limbs_and_markings/middleware = locate() in preferences.middleware
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], FALSE)
	preferences.body_markings = body_marking_collection_from_list(list(BODY_ZONE_L_ARM = list("[names[1]]" = list(colors[1], 0), "[names[2]]" = list(colors[2], 1))))
	var/datum/body_marking_entry/unlit = preferences.body_markings.find_entry(BODY_ZONE_L_ARM, names[1])
	var/datum/body_marking_entry/lit = preferences.body_markings.find_entry(BODY_ZONE_L_ARM, names[2])
	// Character setup, with emissives off: a glow cannot be turned on.
	TEST_ASSERT(!middleware.change_emissive_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "emissive" = 0), mock_client.mob), "Turning a glow on must be refused while emissives are off")
	TEST_ASSERT(!unlit.get_emissive(), "A refused glow must leave the marking unlit")
	// A body dressed with emissives off wears the saved glow unlit, and the saved glow stays saved.
	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent)
	middleware.apply_to_human(body, preferences)
	body.update_body_parts(update_limb_data = TRUE)
	TEST_ASSERT(lit.get_emissive(), "Dressing a body must not change the character's saved glow")
	TEST_ASSERT(!body.dna.body_markings.find_entry(BODY_ZONE_L_ARM, names[2]).get_emissive(), "A body dressed while emissives are off must not glow")
	var/state = marking_state(names[2], BODY_ZONE_L_ARM)
	var/body_glows = 0
	var/obj/item/bodypart/body_arm = body.get_bodypart(BODY_ZONE_L_ARM)
	for(var/image/overlay as anything in body_arm.get_limb_icon(FALSE))
		if(overlay.icon_state == state && PLANE_TO_TRUE(overlay.plane) == EMISSIVE_PLANE && markings_baseline_is_glowing(overlay))
			body_glows++
	TEST_ASSERT(!body_glows, "An arm dressed while emissives are off must draw no marking glow")
	// With emissives on, character setup can turn a glow on, and a body dressed then glows.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], TRUE)
	TEST_ASSERT(middleware.change_emissive_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_1", "emissive" = 0), mock_client.mob), "Turning a glow on must work while emissives are on")
	TEST_ASSERT(unlit.get_emissive(), "An allowed glow must light the marking")
	middleware.apply_to_human(body, preferences)
	TEST_ASSERT(body.dna.body_markings.find_entry(BODY_ZONE_L_ARM, names[1]).get_emissive() && body.dna.body_markings.find_entry(BODY_ZONE_L_ARM, names[2]).get_emissive(), "A body dressed while emissives are on must glow as saved")
	// Turning a glow off is always allowed, emissives on or off.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_emissives], FALSE)
	TEST_ASSERT(middleware.change_emissive_marking(list("bodypart_slot" = BODY_ZONE_L_ARM, "marking_id" = "[BODY_ZONE_L_ARM]_2", "emissive" = 1), mock_client.mob), "Turning a glow off must work while emissives are off")
	TEST_ASSERT(!lit.get_emissive(), "A glow turned off must leave the marking unlit")

/// Random markings for a species come only from marking sets meant for any species or for that one.
/datum/unit_test/body_marking_fixes/random_sets

/**
 * Returns a collection's marking names per zone, in zone order, without colours.
 *
 * Arguments:
 * - markings: the collection to describe.
 */
/datum/unit_test/body_marking_fixes/random_sets/proc/layout(datum/body_marking_collection/markings)
	var/list/zones = list()
	for(var/zone in GLOB.marking_zones)
		var/list/names = markings.marking_names(zone)
		if(length(names))
			zones += "[zone]=[jointext(names, ",")]"
	return jointext(zones, ";")

/datum/unit_test/body_marking_fixes/random_sets/Run()
	var/list/features = list(
		FEATURE_MUTANT_COLOR = "#aa3333",
		FEATURE_MUTANT_COLOR_TWO = "#33aa33",
		FEATURE_MUTANT_COLOR_THREE = "#3333aa",
		FEATURE_SKIN_COLOR = "#ffe0d1",
	)
	for(var/species_type in list(/datum/species/mammal, /datum/species/moth))
		var/datum/species/species = GLOB.species_prototypes[species_type]
		var/list/allowed = list()
		var/list/excluded = list()
		for(var/set_name, set_datum in GLOB.body_marking_sets)
			var/datum/body_marking_set/marking_set = set_datum
			var/set_layout = layout(assemble_body_markings_from_set(marking_set, features, species))
			if(isnull(marking_set.recommended_species) || !isnull(marking_set.recommended_species[species.id]))
				allowed[set_layout] = TRUE
			else
				excluded[set_layout] = set_name
		// A layout an allowed set also makes can't tell the two sets apart.
		excluded -= allowed
		TEST_ASSERT(length(excluded), "The fixture needs a marking set [species.id] may not wear")
		var/list/leaked = list()
		for(var/draw in 1 to 200)
			var/drawn_layout = layout(species.get_random_body_markings(features))
			if(!allowed[drawn_layout])
				leaked |= excluded[drawn_layout] || drawn_layout
		TEST_ASSERT(!length(leaked), "Random [species.id] markings must come from sets meant for [species.id], not: [jointext(leaked, ", ")]")
