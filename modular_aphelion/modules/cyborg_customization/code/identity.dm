/// Only cyborgs use the new fields; AI and other silicon preferences retain their behavior.
/proc/cyborg_identity_model(datum/preferences/preferences, fallback)
	return preferences?.read_preference(/datum/preference/text/custom_species_silicon) || fallback

/// Returns the character's silicon model lore, or the fallback when it has none
/proc/cyborg_identity_lore(datum/preferences/preferences, fallback)
	return preferences?.read_preference(/datum/preference/text/custom_species_lore_silicon) || fallback

/// The examine panel of a cyborg - Nova's silicon fields, then the borg's own model, lore, notes and second headshot
/datum/examine_panel/cyborg

/// Swaps in the cyborg panel for the plain one Nova's silicon Initialize made
/mob/living/silicon/robot/Initialize(mapload)
	. = ..()
	qdel(mob_examine_panel)
	mob_examine_panel = new /datum/examine_panel/cyborg(src)

/// Patches the borg's own fields over Nova's silicon data, so other mobs' panels pay nothing for them
/datum/examine_panel/cyborg/ui_data(mob/user)
	. = ..()
	var/list/data = .
	var/datum/preferences/preferences = holder.client?.prefs
	// tgui keeps an omitted key's last value, so a borg that lost its client still sends an empty headshot
	data["headshot_nsfw"] = preferences ? preferences.read_preference(/datum/preference/text/headshot/silicon_nsfw) : ""
	if(!preferences)
		return
	data["custom_species"] = cyborg_identity_model(preferences, data["custom_species"])
	data["custom_species_lore"] = cyborg_identity_lore(preferences, data["custom_species_lore"])
	var/ooc_notes = preferences.read_preference(/datum/preference/text/ooc_notes_silicon)
	if(length(ooc_notes))
		data["ooc_notes"] = ooc_notes
	var/ooc_notes_nsfw = preferences.read_preference(/datum/preference/text/ooc_notes_silicon/nsfw)
	if(length(ooc_notes_nsfw))
		// Nova put the viewer's ERP block ahead of the human notes, so we swap only the notes after it
		var/nova_notes = data["ooc_notes_nsfw"]
		data["ooc_notes_nsfw"] = copytext(nova_notes, 1, length(nova_notes) - length(preferences.read_preference(/datum/preference/text/ooc_notes_nsfw)) + 1) + ooc_notes_nsfw

/// Swaps Nova's portrait of a wide or tall chassis for one scaled about its centre to fit the panel's one-tile map
/datum/examine_panel/cyborg/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	var/mob/living/silicon/robot/robot = holder
	var/list/features = robot.model?.model_features
	if(!((TRAIT_R_WIDE in features) || (TRAIT_R_TALL in features)))
		return
	var/list/dimensions = get_icon_dimensions(robot.icon)
	var/width = dimensions["width"]
	var/height = dimensions["height"]
	var/scale = min(ICON_SIZE_X / width, ICON_SIZE_Y / height)
	// We face south, upright and unshifted, as Nova's portrait does
	var/mutable_appearance/portrait = new(robot)
	portrait.setDir(SOUTH)
	portrait.pixel_x = 0
	portrait.pixel_y = 0
	// The sprite scales about its centre, so we move that centre onto the tile's
	portrait.transform = matrix(scale, 0, (ICON_SIZE_X - width) / 2, 0, scale, (ICON_SIZE_Y - height) / 2)
	examine_panel_screen.cut_overlays()
	examine_panel_screen.add_overlay(portrait)

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
