/// The legs preference swaps a body's limbs in one render batch and draws the new legs when the batch ends; inside a caller's batch, drawing is left to the caller.
/datum/unit_test/digitigrade_legs_preference

/datum/unit_test/digitigrade_legs_preference/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	var/datum/preference/choiced/digitigrade_legs/legs = GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs]
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(legs.apply_to_human(human, DIGITIGRADE_LEGS, preferences), "Humans should be able to take digitigrade legs")
	var/obj/item/bodypart/leg/left/leg = human.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg.bodyshape & BODYSHAPE_DIGITIGRADE, "The body should get digitigrade legs")
	TEST_ASSERT(!(human.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS), "The swap should end its render batch")
	TEST_ASSERT_EQUAL(human.icon_render_keys[BODY_ZONE_L_LEG], leg.get_cache_key(), "The body should be drawn with its new legs")
	human.living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	TEST_ASSERT(legs.apply_to_human(human, NORMAL_LEGS, preferences), "The legs should change back")
	TEST_ASSERT(human.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS, "A swap inside a caller's batch should leave the batch to the caller")
	human.living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS

/// Applying the preferences again with the legs unchanged keeps the body's limbs; a new leg shape, or a limb the species would
/// not give the body, still has every limb swapped.
/datum/unit_test/digitigrade_legs_preference_refresh

/datum/unit_test/digitigrade_legs_preference_refresh/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/species], SPECIES_HUMAN)
	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs], DIGITIGRADE_LEGS)
	// No personalities: applying some of them to the same body twice registers their signals twice, which this test is not about.
	preferences.write_preference(GLOB.preference_entries[/datum/preference/personality], null)
	var/mob/living/carbon/human/consistent/human = allocate(/mob/living/carbon/human/consistent)
	preferences.apply_prefs_to(human)
	var/obj/item/bodypart/leg/left/leg = human.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(leg.bodyshape & BODYSHAPE_DIGITIGRADE, "The preference must give the body digitigrade legs")

	// Applying resets the features the legs preference compares against, so it used to swap every limb each time.
	preferences.apply_prefs_to(human)
	TEST_ASSERT_EQUAL(human.get_bodypart(BODY_ZONE_L_LEG), leg, "Applying unchanged legs again must keep the body's legs")

	// Another species' arm, which the swap replaces; robotic limbs are exempt from species changes and would stay.
	var/obj/item/bodypart/arm/left/lizard/foreign_arm = new()
	allocated += foreign_arm
	TEST_ASSERT(foreign_arm.replace_limb(human), "The lizard arm must attach")
	preferences.apply_prefs_to(human)
	TEST_ASSERT(!istype(human.get_bodypart(BODY_ZONE_L_ARM), /obj/item/bodypart/arm/left/lizard), "A limb the species would not give the body must still be swapped back")

	preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs], NORMAL_LEGS)
	preferences.apply_prefs_to(human)
	var/obj/item/bodypart/leg/left/normal_leg = human.get_bodypart(BODY_ZONE_L_LEG)
	TEST_ASSERT(!(normal_leg.bodyshape & BODYSHAPE_DIGITIGRADE), "A new leg shape must still swap the legs")

/**
 * The character preview draws every character on one body, so whatever limbs the last character left on it, a refresh must draw
 * what a new body given the same preferences draws. Each step switches species, legs and chassis as loading another character
 * does, and refreshes the preview through its own update_body(): wipe_state(), then render_new_preview_appearance(). A guard for
 * the leg swap the legs preference skips when the body already wears the limbs it would give.
 */
/datum/unit_test/digitigrade_legs_preview_switch
	/// Restore the actual configured choices after this test, including an uninitialized cache.
	var/list/original_species_choices

// These fixtures exercise species-specific bodies, independently of the server's enabled species.
/datum/unit_test/digitigrade_legs_preview_switch/New()
	. = ..()
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	original_species_choices = species_preference.cached_values
	species_preference.cached_values = list(/datum/species/human, /datum/species/lizard, /datum/species/synthetic, /datum/species/mammal)

/datum/unit_test/digitigrade_legs_preview_switch/Destroy()
	var/datum/preference/choiced/species/species_preference = GLOB.preference_entries[/datum/preference/choiced/species]
	species_preference.cached_values = original_species_choices
	original_species_choices = null
	return ..()

/**
 * Checks the preview body against a new body drawn from the same preferences: both legs' types, shapes, icon keys and colour
 * overrides, the render batch, and every pixel of the flattened render. The overrides are compared apart because the limb icon
 * cache, shared by every body, does not key one on a limb drawn from a fixed icon: equal pixels alone could hide one left behind.
 *
 * Arguments:
 * - preferences: the preferences both bodies are drawn from.
 * - step_name: names the switch in failure messages.
 * - digitigrade: whether the preferences ask for digitigrade legs.
 */
/datum/unit_test/digitigrade_legs_preview_switch/proc/check_preview(datum/preferences/preferences, step_name, digitigrade)
	var/mob/living/carbon/human/dummy/body = preferences.character_preview_view.body
	var/mob/living/carbon/human/dummy/fresh = new()
	allocated += fresh
	preferences.render_new_preview_appearance(fresh, preferences.character_preview_view.show_job_clothes)
	TEST_ASSERT(!(body.living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS), "[step_name]: the refresh must not leave the preview's render batch open")
	for(var/zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/leg/leg = body.get_bodypart(zone)
		var/obj/item/bodypart/leg/fresh_leg = fresh.get_bodypart(zone)
		TEST_ASSERT(leg && fresh_leg, "[step_name]: both bodies must have a [zone]")
		TEST_ASSERT_EQUAL(leg.type, fresh_leg.type, "[step_name]: the preview's [zone] must be the one a new body gets")
		TEST_ASSERT_EQUAL(json_encode(leg.color_overrides), json_encode(fresh_leg.color_overrides), "[step_name]: the preview's [zone] must carry the colour overrides a new body's does")
		TEST_ASSERT_EQUAL(!!(leg.bodyshape & BODYSHAPE_DIGITIGRADE), !!digitigrade, "[step_name]: the preview's [zone] must have the leg shape asked for")
		TEST_ASSERT_EQUAL(body.icon_render_keys[zone], leg.get_cache_key(), "[step_name]: the preview must be drawn with its [zone] as it is now")
	var/list/drawn = markings_baseline_signature(get_flat_icon_for_all_directions(body))
	var/list/expected = markings_baseline_signature(get_flat_icon_for_all_directions(fresh))
	TEST_ASSERT_EQUAL(drawn["pixels_md5"], expected["pixels_md5"], "[step_name]: the preview must draw every pixel a new body given the same preferences draws")

/datum/unit_test/digitigrade_legs_preview_switch/Run()
	var/datum/client_interface/mock_client = allocate(/datum/client_interface)
	var/datum/preferences/preferences = allocate(/datum/preferences/preferences_import_test, mock_client)
	// Naked, so no clothing covers the legs in the render.
	preferences.preview_pref = PREVIEW_PREF_NAKED
	var/datum/preference/species_pref = GLOB.preference_entries[/datum/preference/choiced/species]
	var/datum/preference/legs_pref = GLOB.preference_entries[/datum/preference/choiced/digitigrade_legs]
	var/datum/preference/chassis_pref = GLOB.preference_entries[/datum/preference/choiced/mutant_choice/synth_chassis]
	var/datum/preference/chassis_color_pref = GLOB.preference_entries[/datum/preference/color/mutant/synth_chassis]
	// A vivid chassis colour, so a colour the last chassis left behind shows on the next one.
	preferences.write_preference(chassis_color_pref, "#cc4422")
	preferences.write_preference(species_pref, SPECIES_HUMAN)
	preferences.write_preference(legs_pref, DIGITIGRADE_LEGS)
	preferences.create_character_preview_view(mock_client.mob)
	check_preview(preferences, "human digitigrade, first drawn", TRUE)

	// Each step starts from the body the step before left. The chassis is set for the synthetic steps only; they keep
	// plantigrade legs, which no chassis changes.
	var/list/switches = list(
		list("human digitigrade, drawn again", SPECIES_HUMAN, DIGITIGRADE_LEGS, null),
		list("human digitigrade to human plantigrade", SPECIES_HUMAN, NORMAL_LEGS, null),
		list("human plantigrade to human digitigrade", SPECIES_HUMAN, DIGITIGRADE_LEGS, null),
		list("human digitigrade to lizard digitigrade", SPECIES_LIZARD, DIGITIGRADE_LEGS, null),
		list("lizard digitigrade to human plantigrade", SPECIES_HUMAN, NORMAL_LEGS, null),
		list("human plantigrade to lizard digitigrade", SPECIES_LIZARD, DIGITIGRADE_LEGS, null),
		list("lizard digitigrade to a synthetic in a coloured chassis", SPECIES_SYNTH, NORMAL_LEGS, "Mammal Chassis"),
		list("coloured chassis to an uncoloured one", SPECIES_SYNTH, NORMAL_LEGS, "Dark Chassis"),
		list("a synthetic to a mammal taur", SPECIES_MAMMAL, NORMAL_LEGS, null, TRUE),
		list("a taur to human digitigrade", SPECIES_HUMAN, DIGITIGRADE_LEGS, null, FALSE),
		list("human digitigrade to a mammal taur", SPECIES_MAMMAL, NORMAL_LEGS, null, TRUE),
		list("a taur to human plantigrade", SPECIES_HUMAN, NORMAL_LEGS, null, FALSE),
	)
	for(var/list/switch_step as anything in switches)
		var/step_name = switch_step[1]
		var/species_id = switch_step[2]
		var/chassis = switch_step[4]
		preferences.write_preference(species_pref, species_id)
		TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/species), GLOB.species_list[species_id], "[step_name]: the preferences must take the [species_id] species")
		preferences.write_preference(legs_pref, switch_step[3])
		if(chassis)
			preferences.write_preference(chassis_pref, chassis)
			TEST_ASSERT_EQUAL(preferences.read_preference(/datum/preference/choiced/mutant_choice/synth_chassis), chassis, "[step_name]: the preferences must take the [chassis]")
		if(length(switch_step) >= 5)
			preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/allow_mismatched_parts], TRUE)
			preferences.write_preference(GLOB.preference_entries[/datum/preference/choiced/mutant_choice/taur], "Bunny")
			preferences.write_preference(GLOB.preference_entries[/datum/preference/toggle/mutant_toggle/taur], switch_step[5])
		// What loading another character does: redraw the preview, then forget the last preview mode.
		preferences.character_preview_view.update_body()
		preferences.previous_preview_pref = null
		if(length(switch_step) >= 5)
			TEST_ASSERT_EQUAL(!!preferences.character_preview_view.body.get_organ_slot(ORGAN_SLOT_EXTERNAL_TAUR), switch_step[5], "[step_name]: the preview must apply the selected taur toggle")
		check_preview(preferences, step_name, switch_step[3] == DIGITIGRADE_LEGS)
