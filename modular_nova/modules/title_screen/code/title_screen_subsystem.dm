/// Boot log lines shown in the lobby's startup terminal, capped to MAX_STARTUP_MESSAGES.
GLOBAL_LIST_EMPTY(startup_messages)

SUBSYSTEM_DEF(title)
	name = "Title Screen"
	ss_flags = SS_NO_FIRE
	init_stage = INITSTAGE_FIRST

	var/icon/startup_splash

	/// The current title screen being displayed, as a file path text.
	/// Set only through set_showing(), never on its own.
	var/current_title_screen
	/// The current notice text, or null.
	var/current_notice
	/// The list of possible title screens to rotate through, as file path texts.
	var/title_screens = list()
	/// Config-directory file names, index-aligned with title_screens. The icons
	/// themselves carry no name, so this is what the admin dropdown selects by.
	var/list/title_screen_names = list()

	/// Admin-pinned title screen file name, or null to rotate/fall back.
	var/selected_title_name
	/// Config file name of the screen actually showing, or null for the neutral master
	/// and admin uploads. Distinct from selected_title_name: a rotation changes what is
	/// displayed without touching the admin pin, and the overlay flag is keyed by the screen actually showing rather than the pinned one.
	var/current_title_name
	/// Whether change_title_screen() is allowed to pick a new screen each round.
	var/rotate_title_screens = FALSE
	/**
	 * Presentation, one record per screen, keyed by config file name. The
	 * neutral Meridian Rift master has no file name and lives under
	 * TITLE_DEFAULT_SCREEN_KEY.
	 *
	 * Each record is list("variant", "bezel", "texture", "wordmark").
	 * Screens with no record fall back to
	 * default_screen_settings(); records for images that are no longer present
	 * are kept rather than pruned, so temporarily removing a file does not lose
	 * how it was set up.
	 */
	var/list/title_screen_settings = list()
	/// Persistence location; focused tests redirect this away from server settings.
	var/title_settings_file = TITLE_SETTINGS_FILE
	/// Cached asset URL for the neutral wordmark used by overlay mode.
	var/title_mark_asset_registered = FALSE

	/// average realtime seconds it takes to load the map we're currently running
	var/average_completion_time = DEFAULT_TITLE_MAP_LOADTIME
	/// a given startup message => average timestamp in realtime seconds
	var/list/startup_message_timings = list()
	/// Raw data to update later
	var/list/progress_json = list()
	/// The reference realtime that we're treating as 0 for this run
	var/progress_reference_time = 0
	/// Name the current title image is registered under in the asset cache. Incremented each
	/// time the image changes, since re-registering the same name with different content logs
	/// an asset cache error (see /datum/asset_transport/proc/register_asset).
	var/current_title_asset_name
	/// Last screen/name pair published with current_title_asset_name. Lobby initialization
	/// reads this snapshot so it cannot combine a staged rotation with the previous image URL.
	var/published_title_screen
	var/published_title_name
	var/list/published_title_payload
	/// Counter used to build a fresh, unique asset name each time the title image changes.
	var/title_asset_generation = 0
	/// Preview asset name => TRUE once registered, so each screen registers once.
	var/list/preview_assets_registered = list()

/datum/controller/subsystem/title/Initialize()
	var/list/provisional_title_screens = flist("[global.config.directory]/title_screens/images/")
	var/list/local_title_screens = list()

	for(var/screen in provisional_title_screens)
		var/list/formatted_list = splittext(screen, "+")
		if((LAZYLEN(formatted_list) == 1 && (formatted_list[1] != "exclude" && formatted_list[1] != "blank.png" && formatted_list[1] != "startup_splash")))
			local_title_screens += screen

		if(LAZYLEN(formatted_list) > 1 && LOWER_TEXT(formatted_list[1]) == "startup_splash")
			var/file_path = "[global.config.directory]/title_screens/images/[screen]"
			ASSERT(fexists(file_path))
			startup_splash = new(fcopy_rsc(file_path))

	// Progress stuff
	check_progress_reference_time()
	load_progress_json()

	if(startup_splash)
		change_title_screen(startup_splash)
	else
		change_title_screen(DEFAULT_TITLE_LOADING_SCREEN)

	if(length(local_title_screens))
		for(var/i in local_title_screens)
			var/file_path = "[global.config.directory]/title_screens/images/[i]"
			ASSERT(fexists(file_path))
			var/icon/title2use = new(fcopy_rsc(file_path))
			title_screens += title2use
			// Keep the config file name index-aligned with its icon so the admin
			// dropdown has a stable key to select and persist by.
			title_screen_names += i

	// Version 1 settings fan their shared presentation out across the screens
	// discovered above, so settings must load after those stable names exist.
	load_title_settings()

	// A screen pinned in a previous round may have been removed from the config
	// directory since; drop the selection rather than pinning to nothing.
	if(!is_title_screen_available(selected_title_name))
		selected_title_name = null

	return SS_INIT_SUCCESS

/**
 * Returns the number of remaining latejoin antagonist slots if we are past roundstart,
 * otherwise returns "PRE-ROUND".
 */
/datum/controller/subsystem/title/proc/get_latejoin_queue_count()
	if (SSticker.current_state < GAME_STATE_PLAYING)
		return "PRE-ROUND"

	return max(SSdynamic.rulesets_to_spawn[LATEJOIN], 0)

/**
 * Make sure reference time is set up. If not, this is now time 0.
 */
/datum/controller/subsystem/title/proc/check_progress_reference_time()
	if(!progress_reference_time)
		progress_reference_time = world.timeofday

/**
 * Handle and clean up leaving startup
 */
/datum/controller/subsystem/title/proc/check_finish_progress()
	//It's the first time we're firing out of startup -> pregame
	if(progress_json && SSticker.current_state == GAME_STATE_PREGAME)
		save_progress_json()

/**
 * Load the progress info json and setup that part of the SS.
*/
/datum/controller/subsystem/title/proc/load_progress_json()
	var/json_file = file(TITLE_PROGRESS_CACHE_FILE)
	if(!fexists(json_file))
		return

	// Load map progress cache info
	progress_json = json_decode(file2text(json_file))

	// Different format. Purge everything.
	if(progress_json["_version"] != TITLE_PROGRESS_CACHE_VERSION)
		progress_json.Cut()
		return

	// If there's no info about the current map, use the defaults.
	var/list/map_info = progress_json[SSmapping.current_map.map_name]
	if(!islist(map_info))
		return

	// Get expected total time and subpart time
	average_completion_time = map_info["total"] || DEFAULT_TITLE_MAP_LOADTIME
	startup_message_timings = map_info["messages"] || list()

/datum/controller/subsystem/title/proc/save_progress_json()
	var/json_file = file(TITLE_PROGRESS_CACHE_FILE)
	var/list/map_info = list()

	progress_json["_version"] = TITLE_PROGRESS_CACHE_VERSION

	if(progress_json[SSmapping.current_map.map_name])
		// Save total time and updated message timings. Latest time is worth 1/4 the "average"
		map_info["total"] = 0.75 * average_completion_time + 0.25 * (world.timeofday - progress_reference_time)
	else
		// New. Just save the time it took.
		map_info["total"] = world.timeofday - progress_reference_time
	map_info["messages"] = startup_message_timings
	progress_json[SSmapping.current_map.map_name] = map_info

	fdel(json_file)
	WRITE_FILE(json_file, json_encode(progress_json))

	// We're done, don't touch it again this round.
	progress_json = null

/**
 * Load the server-wide title screen presentation chosen by an admin.
 *
 * Mirrors load_progress_json(): a missing or version-mismatched file simply
 * leaves the compiled defaults in place rather than failing initialization.
 */
/// Presentation used by any screen that has no record of its own yet.
/datum/controller/subsystem/title/proc/default_screen_settings()
	return list(
		"variant" = TITLE_DEFAULT_VARIANT,
		"bezel" = TITLE_DEFAULT_BEZEL,
		"texture" = TITLE_DEFAULT_TEXTURE,
		"wordmark" = FALSE,
	)

/// Bezel choices shared by draft validation, persistence, and lobby payloads.
/datum/controller/subsystem/title/proc/is_title_bezel(bezel)
	var/static/list/valid_bezels = list(TITLE_BEZEL_RUSTY, TITLE_BEZEL_RUSTY_DARK, TITLE_BEZEL_APHELION, TITLE_BEZEL_CLASSIC, TITLE_BEZEL_NONE)
	return istext(bezel) && (bezel in valid_bezels)

/**
 * One screen's presentation, filled in from the defaults.
 *
 * Always returns a complete record, so callers never have to test a field for
 * null. A screen that has never been configured reads as the defaults.
 *
 * Arguments:
 * * screen_name - config file name, or null for the neutral Meridian master.
 */
/// Whether a selection names the neutral master, in either of its two ramps.
/datum/controller/subsystem/title/proc/is_master_screen(screen_name)
	return isnull(screen_name) || screen_name == TITLE_DEFAULT_ALT_SCREEN_KEY

/// Whether a screen can be selected or configured by the title manager.
/datum/controller/subsystem/title/proc/is_title_screen_available(screen_name)
	return is_master_screen(screen_name) || !!get_title_screen_icon(screen_name)

/// Whether the screen showing now corresponds to an option the manager can edit.
/datum/controller/subsystem/title/proc/is_current_title_screen_managed()
	if(is_master_screen(current_title_name))
		return current_title_screen == DEFAULT_TITLE_SCREEN_IMAGE
	return !!get_title_screen_icon(current_title_name)

/datum/controller/subsystem/title/proc/get_screen_settings(screen_name)
	var/key = isnull(screen_name) ? TITLE_DEFAULT_SCREEN_KEY : screen_name
	var/list/stored = title_screen_settings[key]
	var/list/settings = default_screen_settings()
	if(!islist(stored))
		return settings

	for(var/field in settings)
		if(!isnull(stored[field]))
			settings[field] = stored[field]
	if(!is_title_bezel(settings["bezel"]))
		settings["bezel"] = TITLE_DEFAULT_BEZEL
	return settings

/datum/controller/subsystem/title/proc/load_title_settings()
	var/json_file = file(title_settings_file)
	if(!fexists(json_file))
		return

	var/list/settings = json_decode(file2text(json_file))
	if(!islist(settings))
		return

	var/version = settings["_version"]
	if(version != TITLE_SETTINGS_VERSION && version != TITLE_SETTINGS_VERSION_BOOLEAN_BEZEL && version != TITLE_SETTINGS_VERSION_LEGACY)
		return

	selected_title_name = istext(settings["selected"]) ? settings["selected"] : null
	rotate_title_screens = !!settings["rotate"]

	if(version == TITLE_SETTINGS_VERSION_LEGACY)
		migrate_legacy_title_settings(settings)
		return

	var/list/stored = settings["screens"]
	title_screen_settings = islist(stored) ? stored.Copy() : list()
	// Normalize the renamed texture before publishing or editing saved records.
	for(var/screen_name in title_screen_settings)
		var/list/record = title_screen_settings[screen_name]
		if(islist(record) && istext(record["texture"]))
			record["texture"] = migrate_title_texture(record["texture"])
	if(version == TITLE_SETTINGS_VERSION_BOOLEAN_BEZEL)
		migrate_boolean_title_bezels()

/// Rename persisted texture IDs without changing their appearance.
/datum/controller/subsystem/title/proc/migrate_title_texture(texture)
	switch(texture)
		if("original")
			return "scanlines-light"
		if("navarobl")
			return "scanlines-classic"
	return texture

/**
 * Preserves version 2's appearance while replacing its boolean bezel.
 *
 * An absent bezel or record used to default to TRUE, so known screens get an
 * explicit Classic record too. Screens added after migration use the new
 * Dark Brown default. Records for temporarily missing images are retained.
 */
/datum/controller/subsystem/title/proc/migrate_boolean_title_bezels()
	var/list/screen_keys = list(TITLE_DEFAULT_SCREEN_KEY, TITLE_DEFAULT_ALT_SCREEN_KEY)
	screen_keys |= title_screen_names
	for(var/key in title_screen_settings)
		screen_keys |= key
	for(var/key in screen_keys)
		var/list/stored = title_screen_settings[key]
		var/list/record = islist(stored) ? stored.Copy() : list()
		record["bezel"] = isnull(record["bezel"]) || record["bezel"] ? TITLE_BEZEL_CLASSIC : TITLE_BEZEL_NONE
		title_screen_settings[key] = record
	save_title_settings()

/**
 * Fans version 1's four server-wide values out into a record per screen.
 *
 * Version 1 stored one variant/texture/classicAlt for everything plus a map of
 * overlay flags. Every screen it knew about therefore had the same frame, so
 * copying the globals onto each one reproduces exactly what the admin last
 * saw. Overlay flags become the per-screen wordmark.
 */
/datum/controller/subsystem/title/proc/migrate_legacy_title_settings(list/settings)
	var/list/legacy_overlays = islist(settings["overlays"]) ? settings["overlays"] : list()
	// Preserve v1's historical fallbacks. New records intentionally default
	// to the Dark Brown bezel/classic treatment, but merely loading an old file must
	// not retrofit settings its admin never chose.
	var/list/base = list(
		"variant" = "convex",
		"bezel" = TITLE_BEZEL_NONE,
		"texture" = "scanlines-light",
		"wordmark" = FALSE,
	)
	if(istext(settings["variant"]))
		base["variant"] = settings["variant"]
	if(istext(settings["texture"]))
		base["texture"] = migrate_title_texture(settings["texture"])
	// v1's classicAlt was a global flag; it now selects the alt master instead,
	// so it is carried on that entry rather than copied onto every screen.
	var/legacy_alt = !!settings["classicAlt"]

	// v1's convex-bezel welded the rim onto the screen effect. Split it back.
	if(base["variant"] == "convex-bezel")
		base["variant"] = "convex"
		base["bezel"] = TITLE_BEZEL_CLASSIC

	title_screen_settings = list()
	// The neutral master is its own screen and was never in the overlay map.
	title_screen_settings[TITLE_DEFAULT_SCREEN_KEY] = base.Copy()
	title_screen_settings[TITLE_DEFAULT_ALT_SCREEN_KEY] = base.Copy()
	// The old ramp flag was independent of a configured picture selection.
	if(legacy_alt && is_master_screen(selected_title_name))
		selected_title_name = TITLE_DEFAULT_ALT_SCREEN_KEY

	// Include temporarily missing images without duplicating configured records.
	var/list/screen_names = title_screen_names.Copy()
	for(var/screen_name in legacy_overlays)
		screen_names |= screen_name
	for(var/screen_name in screen_names)
		if(title_screen_settings[screen_name])
			continue
		var/list/record = base.Copy()
		record["wordmark"] = !!legacy_overlays[screen_name]
		title_screen_settings[screen_name] = record

	save_title_settings()

/// Write the current presentation back out. Called by every setter.
/datum/controller/subsystem/title/proc/save_title_settings()
	var/json_file = file(title_settings_file)
	var/list/settings = list(
		"_version" = TITLE_SETTINGS_VERSION,
		"selected" = selected_title_name,
		"rotate" = rotate_title_screens,
		"screens" = title_screen_settings,
	)

	fdel(json_file)
	WRITE_FILE(json_file, json_encode(settings))

/datum/controller/subsystem/title/Recover()
	startup_splash = SStitle.startup_splash

	set_showing(SStitle.current_title_screen, SStitle.current_title_name)
	current_notice = SStitle.current_notice
	title_screens = SStitle.title_screens
	title_screen_names = SStitle.title_screen_names

	selected_title_name = SStitle.selected_title_name
	rotate_title_screens = SStitle.rotate_title_screens
	title_screen_settings = SStitle.title_screen_settings
	title_settings_file = SStitle.title_settings_file
	title_mark_asset_registered = SStitle.title_mark_asset_registered
	preview_assets_registered = SStitle.preview_assets_registered

	average_completion_time = SStitle.average_completion_time
	startup_message_timings = SStitle.startup_message_timings
	startup_subsystem_name = SStitle.startup_subsystem_name
	startup_completed_subsystems = SStitle.startup_completed_subsystems.Copy()
	progress_json = SStitle.progress_json
	progress_reference_time = SStitle.progress_reference_time
	current_title_asset_name = SStitle.current_title_asset_name
	published_title_screen = SStitle.published_title_screen
	published_title_name = SStitle.published_title_name
	published_title_payload = islist(SStitle.published_title_payload) ? SStitle.published_title_payload.Copy() : null
	title_asset_generation = SStitle.title_asset_generation
	// NEW_SS_GLOBAL assigns SStitle after Recover returns. Republish on the next
	// tick so a staged change or interrupted client loop cannot be stranded on
	// the retired subsystem instance.
	addtimer(CALLBACK(src, PROC_REF(show_title_screen)), 0)

/**
 * Registers the current title screen as the lobby menu's background asset,
 * and pushes the fresh URL to every currently-open lobby menu.
 *
 * The title image changes over time (loading gif -> picked title screen -> admin swaps), and
 * /datum/asset_transport/proc/register_asset logs an error if you re-register the same name
 * with different content, so each call here registers under a fresh, unique name instead of
 * reusing one fixed name.
 */
/datum/controller/subsystem/title/proc/show_title_screen()
	set waitfor = FALSE
	if(SStitle != src)
		return
	var/screen_to_publish = current_title_screen
	var/name_to_publish = current_title_name
	title_asset_generation++
	var/publish_generation = title_asset_generation
	var/asset_name = "[LOBBY_TITLE_ASSET_PREFIX]_[publish_generation].png"
	SSassets.transport.register_asset(asset_name, screen_to_publish)
	ensure_title_mark_asset()
	// Asset registration may yield. If another change won meanwhile, its own
	// publication owns the snapshot and this stale task must not overwrite it.
	if(SStitle != src || publish_generation != title_asset_generation || screen_to_publish != current_title_screen || name_to_publish != current_title_name)
		return
	var/list/payload = get_title_payload(asset_name)
	published_title_screen = screen_to_publish
	published_title_name = name_to_publish
	published_title_payload = payload
	// This is also new-client initialization's ready sentinel. Keep it last so
	// every observer sees either the previous complete publication or this one.
	current_title_asset_name = asset_name
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		if(!menu.client)
			continue
		SSassets.transport.send_assets(menu.client, asset_name)
		SSassets.transport.send_assets(menu.client, LOBBY_TITLE_MARK_ASSET_NAME)
		if(SStitle != src || publish_generation != title_asset_generation || screen_to_publish != current_title_screen || name_to_publish != current_title_name)
			return
		// Appearance-only changes may publish while asset delivery yields. Send
		// the latest snapshot for this same image rather than our older local copy.
		menu.send_update(get_published_title_payload())
	update_title_managers()

/**
 * Registers the neutral wordmark used by overlay mode.
 *
 * Unlike the title screen this content never changes, so it keeps one fixed
 * name instead of the generation counter that show_title_screen() needs.
 */
/datum/controller/subsystem/title/proc/ensure_title_mark_asset()
	if(title_mark_asset_registered)
		return
	SSassets.transport.register_asset(LOBBY_TITLE_MARK_ASSET_NAME, DEFAULT_TITLE_SCREEN_IMAGE)
	title_mark_asset_registered = TRUE

/**
 * Asset name a screen's preview image is registered under.
 *
 * Keyed on position rather than the file name so no sanitising is needed: the
 * manager only ever asks about screens that are in the list. Unlike the live
 * title image these never change content within a round, so one stable name
 * each is enough and the generation counter is not involved.
 */
/datum/controller/subsystem/title/proc/get_screen_preview_asset_name(screen_name)
	if(is_master_screen(screen_name))
		return LOBBY_TITLE_MARK_ASSET_NAME
	var/index = title_screen_names.Find(screen_name)
	if(!index)
		return null
	return "[LOBBY_TITLE_ASSET_PREFIX]_option_[index].png"

/// Registers a screen's preview on first use and returns its asset name.
/datum/controller/subsystem/title/proc/ensure_screen_preview_asset(screen_name)
	var/asset_name = get_screen_preview_asset_name(screen_name)
	if(!asset_name)
		return null
	if(is_master_screen(screen_name))
		ensure_title_mark_asset()
		return asset_name
	if(preview_assets_registered[asset_name])
		return asset_name

	var/icon/screen = get_title_screen_icon(screen_name)
	if(!screen)
		return null
	SSassets.transport.register_asset(asset_name, screen)
	preview_assets_registered[asset_name] = TRUE
	return asset_name

/// URL for one screen's preview, or null when it is no longer on disk.
/datum/controller/subsystem/title/proc/get_title_screen_preview_url(screen_name)
	var/asset_name = ensure_screen_preview_asset(screen_name)
	return asset_name ? SSassets.transport.get_asset_url(asset_name) : null

/**
 * Sends every screen preview to one client.
 *
 * The manager shows all of them at once, so they go out together when it opens
 * rather than one at a time as the admin clicks around.
 */
/datum/controller/subsystem/title/proc/send_preview_assets(client/target)
	if(!target)
		return
	for(var/screen_name in title_screen_names)
		var/asset_name = ensure_screen_preview_asset(screen_name)
		if(asset_name)
			SSassets.transport.send_assets(target, asset_name)
	ensure_title_mark_asset()
	SSassets.transport.send_assets(target, LOBBY_TITLE_MARK_ASSET_NAME)

/**
 * How the lobby should render whatever screen is currently showing.
 *
 * The default image is a neutral alpha master, so it is tinted directly. A
 * config screen is a finished picture inside the selected screen treatment,
 * and only gains the themed wordmark when an admin opts that file in.
 *
 * Keyed on the screen actually showing rather than the pinned one, so a rotation
 * carries whatever overlay flag the screen it landed on was given.
 */
/datum/controller/subsystem/title/proc/get_title_treatment()
	// Runtime/operator uploads have no per-screen record. Leave them raw rather
	// than accidentally borrowing the neutral master's presentation settings.
	if(!is_current_title_screen_managed())
		return TITLE_TREATMENT_NONE
	var/list/settings = get_screen_settings(current_title_name)
	// The neutral master is an alpha shape, not a picture: it *is* the wordmark,
	// so it is always tinted rather than composited over.
	if(current_title_screen == DEFAULT_TITLE_SCREEN_IMAGE)
		return TITLE_TREATMENT_MASK
	return settings["wordmark"] ? TITLE_TREATMENT_OVERLAY : TITLE_TREATMENT_SCREEN


/// The server-wide title state every lobby menu needs, shared by init and updates.
/datum/controller/subsystem/title/proc/get_title_payload(asset_name)
	if(isnull(asset_name))
		asset_name = current_title_asset_name
	ensure_title_mark_asset()
	var/list/showing = get_screen_settings(current_title_name)
	return list(
		"titleImageUrl" = SSassets.transport.get_asset_url(asset_name),
		"titleMarkUrl" = SSassets.transport.get_asset_url(LOBBY_TITLE_MARK_ASSET_NAME),
		"titleImageTreatment" = get_title_treatment(),
		// The showing screen's own presentation, so the lobby renders what was set up
		// for the picture it actually landed on rather than a server-wide style.
		"titleVariant" = showing["variant"],
		"titleBezel" = showing["bezel"],
		"titleTexture" = showing["texture"],
		// Which of the two masters is showing, not a per-screen flag.
		"titleClassicAlt" = current_title_name == TITLE_DEFAULT_ALT_SCREEN_KEY,
	)

/// Last complete image-and-presentation state published to lobby clients.
/datum/controller/subsystem/title/proc/get_published_title_payload()
	if(islist(published_title_payload))
		var/list/payload = published_title_payload.Copy()
		// A CDN toggle or filename-transform change does not change the published
		// image. Resolve its asset names through the transport in use now while
		// retaining the presentation belonging to that complete publication.
		payload["titleImageUrl"] = SSassets.transport.get_asset_url(current_title_asset_name)
		payload["titleMarkUrl"] = SSassets.transport.get_asset_url(LOBBY_TITLE_MARK_ASSET_NAME)
		return payload
	// During first initialization there is no client that can observe this
	// fallback; it keeps recovery and focused tests safe before first publish.
	return get_title_payload()

/**
 * Every selectable screen with its full presentation record.
 *
 * The neutral master leads the list under a null name, matching the selection
 * value that means "no config screen pinned".
 */
/datum/controller/subsystem/title/proc/get_title_screen_options()
	var/list/options = list()
	options += list(get_title_screen_option(null))
	options += list(get_title_screen_option(TITLE_DEFAULT_ALT_SCREEN_KEY))
	for(var/screen_name in title_screen_names)
		options += list(get_title_screen_option(screen_name))
	return options

/datum/controller/subsystem/title/proc/get_title_screen_option(screen_name)
	var/list/settings = get_screen_settings(screen_name)
	return list(
		"name" = screen_name,
		"isDefault" = is_master_screen(screen_name),
		"isAlt" = screen_name == TITLE_DEFAULT_ALT_SCREEN_KEY,
		"url" = get_title_screen_preview_url(screen_name),
		"variant" = settings["variant"],
		"bezel" = settings["bezel"],
		"texture" = settings["texture"],
		"wordmark" = !!settings["wordmark"],
	)

/**
 * Sets which screen is showing, together with the config file name it came from.
 *
 * The overlay flag is looked up by name, so a screen and its name drifting apart
 * means the lobby renders one picture's treatment on top of another's. Assigning
 * the two only ever as a pair is what makes that unrepresentable.
 *
 * Arguments:
 * * screen - the icon or file resource to display.
 * * screen_name - its config file name, or null when it has none: the neutral
 * master, the boot splash, and admin uploads are not config screens.
 */
/datum/controller/subsystem/title/proc/set_showing(screen, screen_name)
	current_title_screen = screen
	current_title_name = screen_name

/**
 * Adds a notice to the main title screen in the form of big red text!
 */
/datum/controller/subsystem/title/proc/set_notice(new_title)
	current_notice = new_title ? sanitize_text(new_title) : null
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.send_update(list("notice" = current_notice))

/**
 * Changes the title screen to a new image.
 */
/datum/controller/subsystem/title/proc/change_title_screen(new_screen)
	if(new_screen)
		// An upload or the boot splash, neither of which is a config screen with a flag.
		set_showing(new_screen, null)
	else
		resolve_unattended_screen()

	check_finish_progress()
	show_title_screen()

/**
 * Picks the screen for an unattended change, i.e. the round-end rotation.
 *
 * Rotation is opt-in; otherwise the pinned selection or neutral master wins.
 * Keeping the choice here lets it persist across rounds without core edits.
 *
 * Applies the pick through set_showing() rather than only returning it, so
 * get_title_treatment() can tell which screen's overlay flag applies to whatever
 * the rotation just landed on. The chosen screen is returned as well, for callers
 * that want to inspect the result.
 */
/datum/controller/subsystem/title/proc/resolve_unattended_screen()
	if(!rotate_title_screens)
		if(is_master_screen(selected_title_name))
			set_showing(DEFAULT_TITLE_SCREEN_IMAGE, selected_title_name)
			return current_title_screen
		var/icon/pinned = get_title_screen_icon(selected_title_name)
		set_showing(pinned || DEFAULT_TITLE_SCREEN_IMAGE, pinned ? selected_title_name : null)
		return current_title_screen

	if(LAZYLEN(title_screens))
		// By index rather than pick(), so the name stays with the icon we landed on.
		var/rolled = rand(1, length(title_screens))
		set_showing(title_screens[rolled], title_screen_names[rolled])
		return current_title_screen

	set_showing(DEFAULT_TITLE_SCREEN_IMAGE, null)
	return current_title_screen

/// Resolve a config file name to its preloaded icon, or null when unknown.
/datum/controller/subsystem/title/proc/get_title_screen_icon(screen_name)
	if(!istext(screen_name))
		return null
	var/index = title_screen_names.Find(screen_name)
	if(!index)
		return null
	return title_screens[index]

/**
 * Push the current settings to every open lobby.
 *
 * Unlike show_title_screen() this does not touch the asset cache, so the
 * toggles that only change presentation cannot churn through generations of
 * identical registered images.
 */
/datum/controller/subsystem/title/proc/broadcast_title_settings()
	if(SStitle != src)
		return
	// A new screen can be staged while its asynchronous asset publication is
	// still pending. Keep serving the previous complete snapshot until that task
	// can publish the new image and presentation together.
	if(islist(published_title_payload) && (published_title_screen != current_title_screen || published_title_name != current_title_name))
		update_title_managers()
		return
	var/list/payload = get_title_payload()
	published_title_screen = current_title_screen
	published_title_name = current_title_name
	published_title_payload = payload
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		if(!menu.client)
			continue
		menu.send_update(payload)
	update_title_managers()

/// Refreshes open admin managers without discarding a locally modified draft.
/datum/controller/subsystem/title/proc/update_title_managers()
	for(var/client/viewer as anything in GLOB.clients)
		var/datum/title_screen_manager/manager = viewer.title_screen_manager
		if(!manager)
			continue
		manager.sync_clean_draft_to_live()
		SStgui.update_uis(manager)

/**
 * Admin-facing setters.
 *
 * Each validates its input, persists, and reuses the existing broadcast path.
 * None of them check rights: callers are responsible for that, so the checks
 * stay next to the transport that can be reached from a client.
 */
/datum/controller/subsystem/title/proc/set_title_selection(screen_name)
	if(isnull(screen_name) || screen_name == "")
		// The empty selection means the neutral Meridian Rift master.
		selected_title_name = null
		set_showing(DEFAULT_TITLE_SCREEN_IMAGE, null)
	else if(screen_name == TITLE_DEFAULT_ALT_SCREEN_KEY)
		// Same master, alternate wordmark ramp. It carries the key as its name
		// so its own presentation record resolves like any other screen's.
		selected_title_name = TITLE_DEFAULT_ALT_SCREEN_KEY
		set_showing(DEFAULT_TITLE_SCREEN_IMAGE, TITLE_DEFAULT_ALT_SCREEN_KEY)
	else
		var/icon/chosen = get_title_screen_icon(screen_name)
		if(!chosen)
			return FALSE
		selected_title_name = screen_name
		set_showing(chosen, screen_name)

	save_title_settings()
	show_title_screen()
	return TRUE

/datum/controller/subsystem/title/proc/set_title_rotation(rotate)
	var/new_rotate = !!rotate
	if(rotate_title_screens && !new_rotate)
		// Rotation may have landed on a different screen than the dormant pin.
		// Disabling it means "keep what I am looking at", not "return to an old
		// invisible choice next round". Do not turn an unmanaged upload into the
		// neutral master merely because both have a null name.
		if(is_current_title_screen_managed())
			selected_title_name = current_title_name
	rotate_title_screens = new_rotate
	save_title_settings()
	broadcast_title_settings()
	return TRUE

/**
 * Applies one screen's presentation record.
 *
 * Every field is optional: only the ones present in `changes` are written, so
 * the manager can send a single control's new value without having to restate
 * the rest of the record.
 *
 * Arguments:
 * * screen_name - config file name, or null for the neutral Meridian master.
 * * changes - any of variant, bezel, texture, wordmark.
 */
/datum/controller/subsystem/title/proc/set_screen_settings(screen_name, list/changes)
	if(!is_title_screen_available(screen_name))
		return FALSE
	var/list/current_settings = get_screen_settings(screen_name)
	var/list/settings = merge_screen_settings(current_settings, changes)
	if(!settings)
		return FALSE
	// Selection-only drafts should not rewrite or broadcast unchanged appearance.
	if(deep_compare_list(settings, current_settings))
		return TRUE

	var/key = isnull(screen_name) ? TITLE_DEFAULT_SCREEN_KEY : screen_name
	title_screen_settings[key] = settings
	save_title_settings()
	broadcast_title_settings()
	return TRUE

/// Returns a validated copy, or null without mutating the original on invalid input.
/datum/controller/subsystem/title/proc/merge_screen_settings(list/settings, list/changes)
	var/static/list/valid_values = list(
		"variant" = list("flat", "edge", "convex"),
		"texture" = list("none", "scanlines-light", "scanlines-classic"),
	)
	if(!islist(changes) || !length(changes))
		return null
	var/list/merged = settings.Copy()
	var/has_supported_change = FALSE
	for(var/field in settings)
		var/value = changes[field]
		if(isnull(value))
			continue
		if(field == "wordmark")
			value = !!value
		else if(field == "bezel" ? !is_title_bezel(value) : !(value in valid_values[field]))
			return null
		merged[field] = value
		has_supported_change = TRUE
	return has_supported_change ? merged : null

/**
 * Update a user's character setup name.
 * Arguments:
 * * user - The user being updated
 * * name - the real name of the current slot.
 */
/datum/controller/subsystem/title/proc/update_character_name(mob/dead/new_player/user, name)
	user.client?.lobby_menu?.send_update(list("characterName" = uppertext(name)))

/**
 * Adds a startup message to the splashscreen.
 *
 * Arguments:
 * * msg - the message to show users.
 * * warning - optional: TRUE to indicate this is an error/warning
 */
/proc/add_startup_message(msg, warning)
	// Remove the # second(s) / #s part of the message.
	var/static/regex/msg_key_regex = new(@"[0-9.]+( second)?s?!", "ig")
	// Key used to cache the timing info
	var/msg_key = msg_key_regex.Replace(msg, "#")

	GLOB.startup_messages += list(list("text" = msg, "warning" = !!warning))
	if(length(GLOB.startup_messages) > MAX_STARTUP_MESSAGES)
		GLOB.startup_messages.Cut(1, length(GLOB.startup_messages) - MAX_STARTUP_MESSAGES + 1)

	// If we ran before SStitle initialized, set the ref time now.
	SStitle.check_progress_reference_time()

	// Add or update message history info.
	var/old_timing = SStitle.startup_message_timings[msg_key]
	var/new_timing
	if(!old_timing)
		// new message
		new_timing = world.timeofday - SStitle.progress_reference_time
	else
		// old message. Latest time is worth 1/4 the "average"
		new_timing = 0.75 * old_timing + 0.25 * (world.timeofday - SStitle.progress_reference_time)
	SStitle.startup_message_timings[msg_key] = new_timing

	var/list/update = SStitle.get_startup_status()
	update += list(
		"startupMessages" = GLOB.startup_messages,
		"progressCurrent" = new_timing,
		"progressTotal" = SStitle.average_completion_time,
	)
	for(var/datum/lobby_menu/menu as anything in GLOB.lobby_menus)
		menu.send_update(update)
