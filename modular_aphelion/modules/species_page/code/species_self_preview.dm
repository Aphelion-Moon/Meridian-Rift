/// Where characters' own previews are drawn. The first drawing each round clears it.
#define SPECIES_SELF_PREVIEW_DIR "data/species_page/self/"

/// Previews some character is showing, by name. The name is the md5 of the recipes, so characters that look
/// the same share one drawing.
GLOBAL_LIST_EMPTY(species_self_previews)
/// How many characters are showing each of those previews. A preview nobody shows is deleted, so there is at
/// most one per character that has opened the page, however often they change.
GLOBAL_LIST_EMPTY(species_self_preview_users)

/**
 * Sends the species page the character's own preview, facing each way. It is drawn again only when the
 * preview mob has changed since it was last drawn, and each drawing goes to a client once.
 */
/datum/preference_middleware/species_page/proc/send_self_preview(list/params, mob/user)
	var/client/client = user.client
	if (isnull(client))
		return FALSE
	var/drawn = update_self_preview()
	var/list/drawing = self_preview
	var/file_name = drawing?["image"]
	if (isnull(file_name) || client.sent_assets[file_name])
		return drawn
	client << browse_rsc(file("[SPECIES_SELF_PREVIEW_DIR][file_name]"), file_name)
	// The page only hears of a drawing once the client confirms its file has arrived (see get_ui_data()).
	// Any preferences update sent before that would have it ask for an image still on its way, which
	// stays blank: a background image that fails once isn't asked for again.
	if (!client.browse_queue_flush() || QDELETED(client))
		return FALSE
	client.sent_assets[file_name] = drawing["name"]
	return TRUE

/// Draws the preview mob facing each way if it has changed since it was last drawn. Returns whether it drew.
/datum/preference_middleware/species_page/proc/update_self_preview()
	var/mob/living/carbon/human/body = get_preview_body()
	if (isnull(body))
		return FALSE
	UNTIL(!drawing_self)
	var/appearance_now = body.appearance
	if (appearance_now == self_appearance)
		return FALSE

	drawing_self = TRUE
	var/list/drawing
	try
		drawing = draw_self_preview(body)
	catch(var/exception/error)
		drawing_self = FALSE
		throw error
	drawing_self = FALSE
	if (isnull(drawing))
		return FALSE
	self_appearance = appearance_now
	var/old_name = self_preview?["name"]
	if (drawing["name"] != old_name)
		GLOB.species_self_preview_users[drawing["name"]] += 1
		release_self_preview(old_name)
	// Which species it was drawn as, so the page never shows it for the species that replaced it.
	self_preview = drawing.Copy()
	self_preview["species"] = body.dna.species.id
	return TRUE

/// The preferences' preview mob, if it is showing the character.
/datum/preference_middleware/species_page/proc/get_preview_body()
	var/mob/living/carbon/human/body = preferences?.character_preview_view?.body
	if (isnull(body) || !preview_shows_character())
		return null
	return body

/// Whether the preview mob is the character. A silicon job's preview is drawn without it, leaving it wiped.
/datum/preference_middleware/species_page/proc/preview_shows_character()
	if (preferences.preview_pref != PREVIEW_PREF_JOB)
		return TRUE
	var/datum/job/preview_job = preferences.get_highest_priority_job()
	return !istype(preview_job, /datum/job/ai) && !istype(preview_job, /datum/job/cyborg)

/// This character stops showing a drawing. Once no character shows it, it is forgotten and its file deleted.
/datum/preference_middleware/species_page/proc/release_self_preview(name)
	if (isnull(name))
		return
	var/users = GLOB.species_self_preview_users[name] - 1
	if (users > 0)
		GLOB.species_self_preview_users[name] = users
		return
	var/list/drawing = GLOB.species_self_previews[name]
	GLOB.species_self_preview_users -= name
	GLOB.species_self_previews -= name
	if (drawing)
		fdel("[SPECIES_SELF_PREVIEW_DIR][drawing["image"]]")

/datum/preference_middleware/species_page/Destroy()
	release_self_preview(self_preview?["name"])
	self_preview = null
	self_appearance = null
	return ..()

/**
 * Draws the mob facing each way into one strip with iconforge, or finds the same look already drawn.
 * One flatten serves all four facings; see uni_icon_facings_json(). Returns the page's data for the
 * strip, or null if it couldn't be drawn.
 */
/datum/preference_middleware/species_page/proc/draw_self_preview(mob/living/carbon/human/body)
	var/list/recipes = uni_icon_facings_json(get_flat_uni_icon(body, UP), GLOB.species_page_facings)
	var/list/entries = list()
	for (var/facing in recipes)
		entries += "\"[facing]\":[recipes[facing]]"
	var/entries_json = "{[jointext(entries, ",")]}"
	var/name = "species_self_[rustg_hash_string(RUSTG_HASH_MD5, entries_json)]"
	var/list/drawing = GLOB.species_self_previews[name]
	if (drawing && fexists("[SPECIES_SELF_PREVIEW_DIR][drawing["image"]]"))
		return drawing

	var/static/cleared = FALSE
	if (!cleared)
		cleared = TRUE
		fdel(SPECIES_SELF_PREVIEW_DIR)
	var/job = rustg_iconforge_generate_async(SPECIES_SELF_PREVIEW_DIR, name, entries_json, FALSE, FALSE, TRUE)
	var/result
	UNTIL((result = rustg_iconforge_check(job)) != RUSTG_JOB_NO_RESULTS_YET)
	if (result == RUSTG_JOB_ERROR || !findtext(result, "{", 1, 2))
		log_asset("Species page: could not draw [name]: [result]")
		return null
	var/list/output = json_decode(result)
	if (output["error"])
		log_asset("Species page: drawing [name] reported [output["error"]]")

	var/list/sprites = output["sprites"]
	var/size_id = sprites?["south"]?["size_id"]
	if (isnull(size_id) || length(sprites) != length(recipes))
		return null
	var/list/size = splittext(size_id, "x")
	var/width = text2num(size[1])
	var/list/frames = list()
	for (var/facing in sprites)
		var/list/sprite = sprites[facing]
		// The facings of one mob are one size, so they share a strip.
		if (sprite["size_id"] != size_id)
			return null
		frames[facing] = sprite["position"] * width
	drawing = list(
		"name" = name,
		"image" = "[name]_[size_id].png",
		"width" = width,
		"height" = text2num(size[2]),
		"frames" = frames,
	)
	GLOB.species_self_previews[name] = drawing
	return drawing

#undef SPECIES_SELF_PREVIEW_DIR
