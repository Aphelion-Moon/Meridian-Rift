/// Only cyborgs use the new fields; AI and other silicon preferences retain their behavior.
/proc/cyborg_identity_model(datum/preferences/preferences, fallback)
	return cyborg_preference_value(preferences, "custom_species_silicon") || fallback

/// Returns the character's silicon model lore, or the fallback when it has none
/proc/cyborg_identity_lore(datum/preferences/preferences, fallback)
	return cyborg_preference_value(preferences, "custom_species_lore_silicon") || fallback

/// GET_CLIENT can resolve to a real /client or the unit-test client interface.
/proc/cyborg_preferences_for(mob/owner)
	if(!owner)
		return null
	return owner.mock_client ? owner.mock_client.prefs : owner.client?.prefs

/datum/preference/text/headshot/silicon_nsfw
	savefile_key = "silicon_headshot_nsfw"
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	should_update_preview = FALSE

/// The headshot is only read on examine, so there is nothing to apply to a body
/datum/preference/text/headshot/silicon_nsfw/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return FALSE

/// These descriptions mirror already-rendered visual layers. They do not imply an organ or interaction capability.
/proc/cyborg_visual_anatomy_examine_lines(mob/living/silicon/robot/robot, viewer_allows)
	. = list()
	if(!viewer_allows || !robot?.cyborg_appearance_allowed || !robot.cyborg_appearance_character_allowed)
		return
	var/list/slot_names = list(
		"penis" = "penile display",
		"sheath" = "sheath display",
		"testicles" = "testicular display",
		"vagina" = "vaginal display",
		"anus" = "anal display",
		"breasts" = "chest display",
	)
	var/list/exposed = list()
	for(var/slot in cyborg_layout_supported_slots())
		var/list/capability = cyborg_part_capability(robot, slot)
		if(capability["enabled"] && capability["exposed"])
			exposed += slot_names[slot]
	if(length(exposed))
		. += span_notice("Its visual-only configured display is exposed: [english_list(exposed)].")

/// Adds which visual-only parts are showing, for viewers who opted in
/mob/living/silicon/robot/examine(mob/user)
	. = ..()
	var/datum/preferences/viewer_preferences = cyborg_preferences_for(user)
	var/viewer_allows = viewer_preferences?.read_preference(/datum/preference/toggle/see_cyborg_genitalia)
	. += cyborg_visual_anatomy_examine_lines(src, viewer_allows)
