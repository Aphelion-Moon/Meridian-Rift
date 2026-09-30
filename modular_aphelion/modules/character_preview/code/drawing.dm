/// Where iconforge writes a preview drawing. It is read back and deleted at once, and tmp/ is cleared every round.
#define CHARACTER_PREVIEW_DIR "tmp/character_preview/"

/// Drawings some character is showing, by name. The name is the md5 of the recipes, so characters that look the same
/// share one drawing.
GLOBAL_LIST_EMPTY(character_preview_drawings)
/// How many characters are showing each of those drawings. A drawing nobody shows is forgotten, so there is at most one
/// per character with setup open, however often they change.
GLOBAL_LIST_EMPTY(character_preview_drawing_users)
/// The facings a drawing holds, keyed as the page names them.
GLOBAL_LIST_INIT(character_preview_facings, list("south" = SOUTH, "west" = WEST, "north" = NORTH, "east" = EAST))

/// After an answer, how long requests wait to be folded into one, and how quiet a burst of them must go first.
#define CHARACTER_PREVIEW_SETTLE (0.25 SECONDS)
/// The longest a request waits while more keep coming.
#define CHARACTER_PREVIEW_MAX_WAIT (1 SECONDS)
/// How many looks iconforge draws before it is told to let go of the images it keeps from drawing them.
#define CHARACTER_PREVIEW_CLEANUP_EVERY 100
/// A drawing under way longer than this has lost the proc waiting on it, and is no longer waited for. They take
/// milliseconds.
#define CHARACTER_PREVIEW_JOB_TIMEOUT (5 SECONDS)

/// The drawings iconforge is making now: job id -> when it started.
GLOBAL_LIST_EMPTY(character_preview_jobs)
/// How many looks iconforge has drawn since it last let go of what it keeps.
GLOBAL_VAR_INIT(character_preview_drawn_since_cleanup, 0)
/// When new drawings began to wait for iconforge to let go of what it keeps, or null when they needn't.
GLOBAL_VAR(character_preview_cleanup_due)

/datum/preferences
	/// Draws the character preview that every tab of character setup shows.
	var/datum/preference_middleware/character_preview/preview_drawing

/// The preview mob changed: draws it again for the window, if one is open.
/datum/preferences/proc/character_preview_changed()
	preview_drawing?.preview_changed()

/**
 * The character preview every tab of character setup shows: the preview mob, facing each way, drawn into one image
 * and sent in the window's data. Height and body size, which a flatten leaves out, go with it for the page to draw,
 * as the game draws them.
 *
 * It is drawn again whenever the preview mob changes and a window is open to show it, and the window asks for it when
 * it opens, saying which drawing it holds. A lone change is drawn as soon as whatever made it has finished, in the
 * same tick: one action can change the look more than once, like taking one hat off to put another on, and only its
 * last look is drawn, as a map only ever showed what a tick ended with. Changes that come while a drawing is under
 * way, or within CHARACTER_PREVIEW_SETTLE of the last answer, wait in a single slot: each newer one takes its place
 * and pushes the answer back, until they stop for CHARACTER_PREVIEW_SETTLE or CHARACTER_PREVIEW_MAX_WAIT has passed
 * since the first of them. Then the latest look is drawn once. The page shows a loader while one waits.
 *
 * Answers reach the page as small updates of their own, so none of them rebuilds the preferences data, and the drawing
 * travels inside the data rather than as a file: BYOND keeps every file a client is sent in its cache for good.
 */
/datum/preference_middleware/character_preview
	action_delegations = list(
		"character_preview" = PROC_REF(request_preview),
	)
	/// The look last drawn, held rather than its ref kept, so the ref can't be reused.
	var/drawn_look
	/// The drawing as the page reads it: its image, frame size, each facing's offset, and what the page draws over
	/// them. Null until drawn.
	var/list/preview
	/// Everything that drawing shows, so a new one that changes none of it keeps the one the page has.
	var/preview_key
	/// How many drawings this character has had, which numbers each one.
	var/preview_serial = 0
	/// The number of the drawing the page last said it holds, or was last sent.
	var/preview_on_page
	/// Set while a drawing is in progress; another waits for it.
	var/drawing = FALSE
	/// Set while a lone change's answer waits for what made the change to finish; later changes fold into it.
	var/answer_due = FALSE
	/// An answer just given; changes in its wake wait to be folded into one.
	COOLDOWN_DECLARE(preview_cooldown)
	/// When the oldest change still waiting for its answer came, or null when none is waiting.
	var/waiting_since

/datum/preference_middleware/character_preview/New(datum/preferences/preferences)
	. = ..()
	// The preferences asset makes one of each middleware without any, for its constant data.
	if(preferences)
		preferences.preview_drawing = src

/datum/preference_middleware/character_preview/Destroy()
	if(preferences?.preview_drawing == src)
		preferences.preview_drawing = null
	release_drawing(preview?["name"])
	preview = null
	drawn_look = null
	return ..()

/// The window asks for the preview, saying which drawing it holds.
/datum/preference_middleware/character_preview/proc/request_preview(list/params, mob/user)
	preview_on_page = params["have"]
	preview_changed()
	return FALSE

/// Something to draw: once whatever changed the look has finished, or once a burst of changes settles.
/datum/preference_middleware/character_preview/proc/preview_changed()
	if(isnull(open_window()) || answer_due)
		return
	if(isnull(waiting_since) && !drawing && COOLDOWN_FINISHED(src, preview_cooldown))
		answer_due = TRUE
		INVOKE_ASYNC(src, PROC_REF(answer_when_done))
		return
	if(isnull(waiting_since))
		waiting_since = world.time
		send_preview_update(list("character_preview_pending" = TRUE))
	var/wait = min(CHARACTER_PREVIEW_SETTLE, waiting_since + CHARACTER_PREVIEW_MAX_WAIT - world.time)
	addtimer(CALLBACK(src, PROC_REF(answer_waiting)), max(wait, world.tick_lag), TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_NO_HASH_WAIT)

/// A lone change's answer. It yields until whatever made the change has finished, later this tick, so it draws the
/// look that action left rather than one it passed through.
/datum/preference_middleware/character_preview/proc/answer_when_done()
	sleep(0)
	answer_due = FALSE
	answer()

/// The end of a burst of changes: the latest look, drawn once.
/datum/preference_middleware/character_preview/proc/answer_waiting()
	waiting_since = null
	answer()

/// Draws the preview if it has changed, and tells the page whether a newer drawing is waiting, sending it the latest
/// drawing if it holds another.
/datum/preference_middleware/character_preview/proc/answer()
	update_preview()
	COOLDOWN_START(src, preview_cooldown, CHARACTER_PREVIEW_SETTLE)
	var/list/update = list("character_preview_pending" = !isnull(waiting_since))
	var/id = preview?["id"]
	if(!isnull(id) && id != preview_on_page)
		update["character_preview"] = preview
		preview_on_page = id
	send_preview_update(update)

#undef CHARACTER_PREVIEW_SETTLE
#undef CHARACTER_PREVIEW_MAX_WAIT

/// The open character setup window, or null. A window still loading can't take a drawing yet, and asks for one once
/// it has loaded.
/datum/preference_middleware/character_preview/proc/open_window()
	var/client/client = preferences?.parent
	var/datum/tgui/ui = client && SStgui.get_open_ui(client.mob, preferences)
	return ui?.initialized ? ui : null

/// Sends the page only these keys. tgui merges them into the data it has, which keeps them until they are sent again.
/datum/preference_middleware/character_preview/proc/send_preview_update(list/update)
	var/datum/tgui/ui = open_window()
	ui?.send_update(update)

/**
 * Draws the preview mob if its look has changed since it was last drawn, and makes the page's preview from the drawing.
 * Everything the page is sent is read from the mob in one go, before the drawing is waited on, so it all shows the same
 * look.
 */
/datum/preference_middleware/character_preview/proc/update_preview()
	UNTIL(!drawing)
	var/atom/movable/screen/map_view/char_preview/view = preferences?.character_preview_view
	var/mob/living/carbon/human/dummy/body = view?.body
	// A silicon job's preview shows its image instead of the mob.
	var/image/silicon = view?.silicon_preview
	if(isnull(body) && isnull(silicon))
		return
	var/look_now = silicon ? silicon.appearance : body.appearance
	if(look_now == drawn_look)
		return

	var/list/walk = silicon ? character_preview_walk(silicon) : character_preview_walk(body)
	var/height = walk["height"]
	// What the flatten leaves out and the page draws itself: rows moved by height, and body size.
	var/list/effects = silicon ? list() : character_preview_effects(body, height, walk["y"])
	// Which species it shows, so the species page never shows it for the species that replaced it. A silicon is none.
	var/species = silicon ? null : body.dna.species.id
	drawing = TRUE
	var/list/drawn
	try
		drawn = draw_preview(walk)
	catch(var/exception/error)
		drawing = FALSE
		throw error
	drawing = FALSE
	// Preferences deleted, or a window closed, while it drew have already let their drawing go.
	if(isnull(drawn) || QDELETED(src) || isnull(open_window()))
		forget_unshown(drawn?["name"])
		return
	if(drawn["height"] != height)
		log_asset("Character preview: [drawn["name"]] came out [drawn["height"]] high, not [height]")
		forget_unshown(drawn["name"])
		return
	drawn_look = look_now

	var/name = drawn["name"]
	var/key = "[name] [species] [json_encode(effects)]"
	if(key == preview_key)
		return
	preview_key = key
	var/old_name = preview?["name"]
	if(name != old_name)
		GLOB.character_preview_drawing_users[name] += 1
		release_drawing(old_name)
	preview = drawn.Copy()
	preview["id"] = ++preview_serial
	preview["species"] = species
	for(var/effect, value in effects)
		preview[effect] = value

/// This character stops showing a drawing. Once no character shows it, it is forgotten.
/datum/preference_middleware/character_preview/proc/release_drawing(name)
	if(isnull(name))
		return
	var/users = GLOB.character_preview_drawing_users[name] - 1
	if(users > 0)
		GLOB.character_preview_drawing_users[name] = users
		return
	GLOB.character_preview_drawing_users -= name
	GLOB.character_preview_drawings -= name

/// Forgets a drawing no character shows, like one made for a window that closed while it was drawn.
/datum/preference_middleware/character_preview/proc/forget_unshown(name)
	if(!isnull(name) && !GLOB.character_preview_drawing_users[name])
		GLOB.character_preview_drawings -= name

/// The window closed, and the preview mob went with it. So does its drawing: a window opened later asks for a new one.
/datum/preference_middleware/character_preview/proc/window_closed()
	release_drawing(preview?["name"])
	preview = null
	preview_key = null
	drawn_look = null
	preview_on_page = null

/**
 * Draws a walk's facings into one strip with iconforge, or finds the same look already drawn, and returns the page's
 * data for the strip, or null if it couldn't be drawn.
 */
/datum/preference_middleware/character_preview/proc/draw_preview(list/walk)
	var/list/recipes = walk["recipes"]
	var/list/entries = list()
	for(var/facing, recipe in recipes)
		entries += "\"[facing]\":[recipe]"
	var/entries_json = "{[jointext(entries, ",")]}"
	var/name = "preview_[rustg_hash_string(RUSTG_HASH_MD5, entries_json)]"
	var/list/drawn = GLOB.character_preview_drawings[name]
	if(drawn)
		return drawn

	// A file name of its own, so two characters drawing the same look at once don't share a file.
	var/static/drawings_made = 0
	var/sheet = "preview_[++drawings_made]"
	// While iconforge is to let go of what it keeps, new drawings wait for it; see character_preview_drawn().
	UNTIL(isnull(GLOB.character_preview_cleanup_due) || world.time > GLOB.character_preview_cleanup_due + CHARACTER_PREVIEW_JOB_TIMEOUT)
	GLOB.character_preview_cleanup_due = null
	var/job = rustg_iconforge_generate_async(CHARACTER_PREVIEW_DIR, sheet, entries_json, FALSE, FALSE, TRUE)
	GLOB.character_preview_jobs[job] = world.time
	var/result
	UNTIL((result = rustg_iconforge_check(job)) != RUSTG_JOB_NO_RESULTS_YET)
	GLOB.character_preview_jobs -= job
	character_preview_drawn()
	if(result == RUSTG_JOB_ERROR || !findtext(result, "{", 1, 2))
		log_asset("Character preview: could not draw [name]: [result]")
		return null
	var/list/output = json_decode(result)
	if(output["error"])
		log_asset("Character preview: drawing [name] reported [output["error"]]")

	var/list/sprites = output["sprites"]
	var/list/sizes = output["sizes"]
	var/size_id = sprites?["south"]?["size_id"]
	var/image = isnull(size_id) ? null : rustg_hash_file(RUSTG_HASH_BASE64, "[CHARACTER_PREVIEW_DIR][sheet]_[size_id].png")
	for(var/size in sizes)
		fdel("[CHARACTER_PREVIEW_DIR][sheet]_[size].png")
	// The facings of one mob are one size, so they share a strip.
	if(!image || length(sizes) != 1 || length(sprites) != length(recipes))
		return null
	var/list/size = splittext(size_id, "x")
	var/width = text2num(size[1])
	// iconforge lays the facings out in any order.
	var/list/frames = list()
	for(var/facing, sprite in sprites)
		frames[facing] = sprite["position"] * width
	drawn = list(
		"name" = name,
		"image" = "data:image/png;base64,[image]",
		"width" = width,
		"height" = text2num(size[2]),
		"frames" = frames,
		// How far the canvas reaches left of and below the mob's own tile, so the page can stand the mob where it
		// would stand on the floor.
		"x" = walk["x"],
		"y" = walk["y"],
	)
	GLOB.character_preview_drawings[name] = drawn
	return drawn

#undef CHARACTER_PREVIEW_DIR

/**
 * A drawing is done. iconforge keeps every image it makes until it is told to let them go, and a look is hardly ever
 * drawn twice, so what it keeps only grows, by 80 to 330 KB a look. Every CHARACTER_PREVIEW_CLEANUP_EVERY drawings it
 * lets go, once none is under way: one under way would come out empty. Until then new drawings wait, for a tick or
 * two, and the last drawing under way lets go when it is done. Spritesheets being made let go themselves once they
 * are done, so it waits for them to finish.
 */
/proc/character_preview_drawn()
	if(++GLOB.character_preview_drawn_since_cleanup < CHARACTER_PREVIEW_CLEANUP_EVERY)
		return
	if(length(SSasset_loading.generate_queue) || SSasset_loading.assets_generating)
		GLOB.character_preview_cleanup_due = null
		return
	for(var/job in GLOB.character_preview_jobs)
		if(world.time > GLOB.character_preview_jobs[job] + CHARACTER_PREVIEW_JOB_TIMEOUT)
			GLOB.character_preview_jobs -= job
	if(length(GLOB.character_preview_jobs))
		GLOB.character_preview_cleanup_due ||= world.time
		return
	// Skipped while something else is putting away what it made; the next drawing asks again.
	if(rustg_iconforge_cleanup() == "Ok")
		GLOB.character_preview_drawn_since_cleanup = 0
	GLOB.character_preview_cleanup_due = null

#undef CHARACTER_PREVIEW_CLEANUP_EVERY
#undef CHARACTER_PREVIEW_JOB_TIMEOUT

/**
 * A look's facings as iconforge recipes, on one canvas that grows to fit parts that reach past the mob's tile, like big
 * ears and wings: list("recipes" = facing -> recipe, "height" = canvas rows, "x" and "y" = how far the canvas reaches
 * left of and below the tile).
 *
 * One walk serves all four facings, stamped with each; see uni_icon_facings_json(). A mob something redraws when it
 * turns, like a head whose worn feature offsets move glasses and hats to the side it faces (golems, Teshari), is turned
 * and walked once per facing instead, each walk cropped to the canvas that fits all four.
 */
/proc/character_preview_walk(atom/look)
	var/mob/living/body = look
	if(!istype(body) || !character_preview_turns_itself(body))
		var/datum/universal_icon/flat = get_flat_uni_icon(look, UP, grow = TRUE)
		return list(
			"recipes" = uni_icon_facings_json(flat, GLOB.character_preview_facings),
			"height" = character_preview_flat_size(flat)[2],
			"x" = isnull(flat.flat_x1) ? 0 : 1 - flat.flat_x1,
			"y" = isnull(flat.flat_y1) ? 0 : 1 - flat.flat_y1,
		)
	var/old_dir = body.dir
	var/list/flats = list()
	for(var/facing, dir in GLOB.character_preview_facings)
		body.setDir(dir)
		flats[facing] = get_flat_uni_icon(body, dir, grow = TRUE)
	body.setDir(old_dir)
	// The canvas that fits every facing, from the look's own lower left pixel.
	var/x1 = INFINITY
	var/y1 = INFINITY
	var/x2 = -INFINITY
	var/y2 = -INFINITY
	for(var/facing, flat_untyped in flats)
		var/datum/universal_icon/flat = flat_untyped
		var/flat_x1 = isnull(flat.flat_x1) ? 1 : flat.flat_x1
		var/flat_y1 = isnull(flat.flat_y1) ? 1 : flat.flat_y1
		var/list/size = character_preview_flat_size(flat)
		x1 = min(x1, flat_x1)
		y1 = min(y1, flat_y1)
		x2 = max(x2, flat_x1 + size[1] - 1)
		y2 = max(y2, flat_y1 + size[2] - 1)
	var/list/recipes = list()
	for(var/facing, flat_untyped in flats)
		var/datum/universal_icon/flat = flat_untyped
		var/flat_x1 = isnull(flat.flat_x1) ? 1 : flat.flat_x1
		var/flat_y1 = isnull(flat.flat_y1) ? 1 : flat.flat_y1
		flat.crop(x1 - flat_x1 + 1, y1 - flat_y1 + 1, x2 - flat_x1 + 1, y2 - flat_y1 + 1)
		recipes[facing] = flat.to_json()
	return list("recipes" = recipes, "height" = y2 - y1 + 1, "x" = 1 - x1, "y" = 1 - y1)

/// A flat icon's canvas, list(width, height): a grown canvas says so itself, and otherwise it is its icon's.
/proc/character_preview_flat_size(datum/universal_icon/flat)
	if(flat.flat_width)
		return list(flat.flat_width, flat.flat_height)
	var/list/dimensions = get_icon_dimensions(flat.icon_file)
	return list(dimensions?["width"] || ICON_SIZE_X, dimensions?["height"] || ICON_SIZE_Y)

/// Whether something redraws a mob when it turns, so each facing of it has to be walked on its own.
/proc/character_preview_turns_itself(mob/living/body)
	return !!(body._listen_lookup?[COMSIG_ATOM_DIR_CHANGE] || body._listen_lookup?[COMSIG_ATOM_POST_DIR_CHANGE])
