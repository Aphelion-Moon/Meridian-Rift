/// The species page's static data, and its sprites when it asks for them. The character's own preview is the character
/// preview every tab shows; see /datum/preference_middleware/character_preview.
/datum/preference_middleware/species_page
	// The static data is the families, so that is what the page reads it as.
	key = "species_families"
	action_delegations = list(
		"species_page_sprites" = PROC_REF(send_species_page_sprites),
	)

/// The families, in order, with the static preference data.
/datum/preference_middleware/species_page/get_constant_data()
	. = list()
	for (var/datum/species_family/family_type as anything in sortTim(valid_subtypesof(/datum/species_family), GLOBAL_PROC_REF(cmp_species_family_order)))
		. += list(list(
			"id" = species_family_id(family_type),
			"name" = initial(family_type.name),
			"icon" = initial(family_type.icon),
		))

/**
 * Sends a species page sheet to the preferences window, when the page opens rather than whenever
 * preferences do: the uniform sheet first, and the body sheet once someone turns a specimen to it.
 */
/datum/preference_middleware/species_page/proc/send_species_page_sprites(list/params, mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, preferences)
	if (isnull(ui))
		return FALSE
	var/datum/asset/sheet = get_asset_datum(params["body"] ? /datum/asset/spritesheet_batched/species_full/body : /datum/asset/spritesheet_batched/species_full)
	// The files have to arrive before the page hears of the stylesheet: once it has loaded that, it asks
	// for the image straight away, and an image that isn't there yet stays blank.
	if (sheet.send(user.client))
		user.client?.browse_queue_flush()
	ui.send_asset(sheet)
	return FALSE
