/// The species page's static data, its sprites when it asks for them, and the character's own preview.
/datum/preference_middleware/species_page
	// The static data is the families, so that is what the page reads it as.
	key = "species_families"
	action_delegations = list(
		"species_page_sprites" = PROC_REF(send_species_page_sprites),
		"species_page_self" = PROC_REF(send_self_preview),
	)
	/// The preview mob's appearance when it was last drawn. Held, rather than its ref kept, so the ref can't be reused.
	var/self_appearance
	/// That drawing, as the page reads it: its file, frame size and each facing's offset. Null until drawn.
	var/list/self_preview
	/// Set while a drawing is in progress; a second request waits for it.
	var/drawing_self = FALSE

/// The families, in order, with the static preference data.
/datum/preference_middleware/species_page/get_constant_data()
	var/list/families = list()
	for (var/datum/species_family/family_type as anything in sortTim(valid_subtypesof(/datum/species_family), GLOBAL_PROC_REF(cmp_species_family_order)))
		families += list(list(
			"id" = species_family_id(family_type),
			"name" = initial(family_type.name),
			"icon" = initial(family_type.icon),
		))
	return families

/// The character's own preview, once this client has its file.
/datum/preference_middleware/species_page/get_ui_data(mob/user)
	var/file_name = self_preview?["image"]
	var/client/client = user.client
	if (isnull(file_name) || isnull(client) || !client.sent_assets[file_name])
		return list()
	return list("species_page_self" = self_preview)

/**
 * Sends a species page sheet to the preferences window, when the page opens rather than whenever
 * preferences do: the uniform sheet first, and the body sheet once someone turns a specimen to it.
 */
/datum/preference_middleware/species_page/proc/send_species_page_sprites(list/params, mob/user)
	var/datum/tgui/ui = SStgui.get_open_ui(user, preferences)
	if (isnull(ui))
		return FALSE
	var/sheet_type = params["body"] ? /datum/asset/spritesheet_batched/species_full/body : /datum/asset/spritesheet_batched/species_full
	var/datum/asset/sheet = get_asset_datum(sheet_type)
	// The files have to arrive before the page hears of the stylesheet: once it has loaded that, it asks
	// for the image straight away, and an image that isn't there yet stays blank.
	if (sheet.send(user.client))
		user.client?.browse_queue_flush()
	ui.send_asset(sheet)
	return FALSE
