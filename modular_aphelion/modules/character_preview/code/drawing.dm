/// Where iconforge writes a preview drawing. It is read back and deleted at once, and tmp/ is cleared every round.
#define CHARACTER_PREVIEW_DIR "tmp/character_preview/"

/// Drawings some character is showing, by name. The name is the md5 of the recipes, so characters that look the same
/// share one drawing.
GLOBAL_LIST_EMPTY(character_preview_drawings)
/// How many characters are showing each of those drawings. A drawing nobody shows is forgotten, so there is at most one
/// per character with setup open, however often they change.
GLOBAL_LIST_EMPTY(character_preview_drawing_users)
/// The facings a drawing holds, and the species page's sprites, keyed as the page names them.
GLOBAL_LIST_INIT(character_preview_facings, list("south" = SOUTH, "west" = WEST, "north" = NORTH, "east" = EAST))

/// After an answer, how long requests wait to be folded into one, and how quiet a burst of them must go first.
#define CHARACTER_PREVIEW_SETTLE (0.25 SECONDS)
/// The longest a request waits while more keep coming.
#define CHARACTER_PREVIEW_MAX_WAIT (1 SECONDS)
/// How many looks' worth of images iconforge draws before it is told to let go of what it keeps from drawing them.
#define CHARACTER_PREVIEW_CLEANUP_EVERY 100
/// A drawing under way longer than this is given up on, by the proc waiting on it and everything else. They take
/// milliseconds.
#define CHARACTER_PREVIEW_JOB_TIMEOUT (5 SECONDS)

/// The drawings iconforge is making now: job id -> when it started.
GLOBAL_LIST_EMPTY(character_preview_jobs)
/// How many looks' worth iconforge has drawn since it last let go of what it keeps; see iconforge_drawn().
GLOBAL_VAR_INIT(iconforge_drawn_since_cleanup, 0)
/// When new drawings began to wait for iconforge to let go of what it keeps, or null when they needn't.
GLOBAL_VAR(character_preview_cleanup_due)

/datum/preferences
	/// Draws the character preview that every tab of character setup shows.
	var/datum/preference_middleware/character_preview/preview_drawing

/// The preview mob changed: draws it again for the window, if one is open.
/datum/preferences/proc/character_preview_changed()
	preview_drawing?.preview_changed()

/// Whether a character setup window is open to show the preview.
/datum/preferences/proc/character_preview_open()
	return !isnull(preview_drawing?.open_window())

/**
 * The character preview every tab of character setup shows: the preview mob, facing each way, drawn into one image
 * and sent in the window's data. Height and body size, which a flatten leaves out, go with it for the page to draw,
 * as the game draws them.
 *
 * It is drawn again whenever the preview mob changes and a window is open to show it, and the window asks for it when
 * it opens, saying which drawing it holds. A lone change is drawn in SScharacter_preview's next fire, after whatever
 * made it has finished: one action can change the look more than once, like taking one hat off to put another on, and
 * only its last look is drawn, as a map only ever showed what a tick ended with. Changes that come while a drawing is
 * under way, or within CHARACTER_PREVIEW_SETTLE of the last answer, wait in a single slot: each newer one takes its place
 * and pushes the answer back, until they stop for CHARACTER_PREVIEW_SETTLE or CHARACTER_PREVIEW_MAX_WAIT has passed
 * since the first of them. Then the latest look is drawn once. The page shows a loader while one waits.
 *
 * While a window is open, a change doesn't rebuild the preview mob itself: the drawing does, first, once for everything
 * an action changed, and in turn with other characters when many change at once. See rebuilds.dm.
 *
 * Answers reach the page as small updates of their own, so none of them rebuilds the preferences data, and the drawing
 * travels inside the data rather than as a file: BYOND keeps every file a client is sent in its cache for good.
 *
 * While the window has its lights off, a look with something that glows is drawn with its glow beside each facing, for
 * the page to light it as the game does in the dark; see glow.dm. Otherwise no glow is drawn at all.
 *
 * A look with something animated, like a halo or a galaxy suit, carries patches of what moves for the page to play over
 * each facing; see animation.dm. An animated icon state is read once a round, in SScharacter_preview's spare time, and
 * a look drawn still while one waited to be read is drawn again once it has been.
 */
/datum/preference_middleware/character_preview
	action_delegations = list(
		"character_preview" = PROC_REF(request_preview),
		"character_preview_lights" = PROC_REF(set_lights),
	)
	/// The look last drawn, held rather than its ref kept, so the ref can't be reused.
	var/drawn_look
	/// Whether the window has its lights off, so drawings carry what glows.
	var/lights_off = FALSE
	/// Whether the look last drawn was drawn with what glows.
	var/drawn_lights_off = FALSE
	/// Set when animated icon states a drawing drew still have been read since, so the look draws again, moving.
	var/animation_read = FALSE
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
	/// Set while an answer waits for SScharacter_preview to start it; changes until then fold into it.
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
	SScharacter_preview.drawings -= src
	window_closed()
	return ..()

/// The window asks for the preview, saying which drawing it holds.
/datum/preference_middleware/character_preview/proc/request_preview(list/params, mob/user)
	preview_on_page = params["have"]
	preview_changed()
	return FALSE

/// The window turns its lights off, or on again. Off, a drawing made without what glows is drawn again with it; on, the
/// page just stops lighting what it has, and later drawings leave the glow out.
/datum/preference_middleware/character_preview/proc/set_lights(list/params, mob/user)
	var/off = !!params["off"]
	if(off == lights_off)
		return FALSE
	lights_off = off
	if(off && !drawn_lights_off)
		preview_changed()
	return FALSE

/// Something to draw: once whatever changed the look has finished, or once a burst of changes settles.
/datum/preference_middleware/character_preview/proc/preview_changed()
	if(isnull(open_window()) || answer_due)
		return
	if(isnull(waiting_since) && !drawing && COOLDOWN_FINISHED(src, preview_cooldown))
		answer_soon()
		return
	if(isnull(waiting_since))
		waiting_since = world.time
		send_preview_update(list("character_preview_pending" = TRUE))
	var/wait = min(CHARACTER_PREVIEW_SETTLE, waiting_since + CHARACTER_PREVIEW_MAX_WAIT - world.time)
	addtimer(CALLBACK(src, PROC_REF(answer_waiting)), max(wait, world.tick_lag), TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_NO_HASH_WAIT)

/// Asks SScharacter_preview for an answer, which it starts once whatever made the change has finished.
/datum/preference_middleware/character_preview/proc/answer_soon()
	answer_due = TRUE
	SScharacter_preview.draw_soon(src)

/// The end of a burst of changes: the latest look, drawn once.
/datum/preference_middleware/character_preview/proc/answer_waiting()
	waiting_since = null
	answer_soon()

/// SScharacter_preview starts an answer asked for with answer_soon(); changes from here on ask for another. Draws the
/// preview if it has changed, and tells the page whether a newer drawing is waiting, sending it the latest drawing if
/// it holds another.
/datum/preference_middleware/character_preview/proc/start_answer()
	answer_due = FALSE
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

/// Draws the preview mob if its look has changed since it was last drawn. One update at a time; another waits for it.
/datum/preference_middleware/character_preview/proc/update_preview()
	UNTIL(!drawing)
	drawing = TRUE
	try
		draw_changed()
	catch(var/exception/error)
		drawing = FALSE
		throw error
	drawing = FALSE

/**
 * Rebuilds the preview mob if a change left it stale, draws it if its look has changed since it was last drawn, and
 * makes the page's preview from the drawing. Everything the page is sent is read from the mob in one go, before the
 * drawing is waited on, so it all shows the same look.
 */
/datum/preference_middleware/character_preview/proc/draw_changed()
	var/atom/movable/screen/map_view/char_preview/view = preferences?.character_preview_view
	if(isnull(view))
		return
	catch_up(view)
	// The window closed while it waited.
	if(QDELETED(view))
		return
	var/mob/living/carbon/human/dummy/body = view.body
	// A silicon job's preview shows its image instead of the mob.
	var/image/silicon = view.silicon_preview
	if(isnull(body) && isnull(silicon))
		return
	var/look_now = silicon ? silicon.appearance : body.appearance
	// A drawing with what glows serves the lights on too. Another slot's character is drawn even when it looks the
	// same, so the page knows it for another character.
	if(look_now == drawn_look && (drawn_lights_off || !lights_off) && !animation_read && preview?["slot"] == preferences.default_slot)
		return
	var/glow = lights_off
	animation_read = FALSE

	var/list/walk = character_preview_walk(silicon || body, glow, animate = TRUE)
	// Drawn still while what animates waits to be read: told once it has been, even while this waits for iconforge.
	if(walk["animation"]?["pending"])
		SScharacter_preview.reading_waiters |= src
	var/height = walk["height"]
	// What the flatten leaves out and the page draws itself: rows moved by height, and body size.
	var/list/effects = silicon ? list() : character_preview_effects(body, height, walk["y"])
	// Which species it shows, so the species page never shows it for the species that replaced it. A silicon is none.
	var/species = silicon ? null : body.dna.species.id
	var/list/drawn = draw_preview(walk)
	// Preferences deleted, or a window closed, while it drew have already let their drawing go.
	if(isnull(drawn) || QDELETED(src) || isnull(open_window()))
		forget_unshown(drawn?["name"])
		return
	if(drawn["height"] != height)
		log_asset("Character preview: [drawn["name"]] came out [drawn["height"]] high, not [height]")
		forget_unshown(drawn["name"])
		return
	drawn_look = look_now
	drawn_lights_off = glow

	var/name = drawn["name"]
	var/key = "[name] [species] [preferences.default_slot] [json_encode(effects)]"
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
	// Whose drawing it is. The page brings another character in with the theme's arrival, and knows one by its drawings
	// alone, whenever the window's own update with the slot comes.
	preview["slot"] = preferences.default_slot
	for(var/effect, value in effects)
		preview[effect] = value

/**
 * Rebuilds the preview mob if a change left it stale: at once if there's room, and otherwise once its turn comes, while
 * the page shows its loader. A change after its turn waits for the next drawing, which it asked for. See rebuilds.dm.
 */
/datum/preference_middleware/character_preview/proc/catch_up(atom/movable/screen/map_view/char_preview/view)
	if(!view.body_stale || SScharacter_preview.rebuild_or_wait(view))
		return
	// A burst waiting to be drawn has already shown the loader.
	if(isnull(waiting_since))
		send_preview_update(list("character_preview_pending" = TRUE))
	var/turns = view.turns
	// No time limit: with many players in line, the queue can take a while to get here, a turn every
	// CHARACTER_PREVIEW_REBUILD_OVERDUE at worst, and drawings that gave up would rebuild outside it, all at once. The
	// wait sleeps each tick, so it can't hold the server up, and a queue that fires always gets to it.
	UNTIL(QDELETED(view) || view.turns != turns || !SScharacter_preview.can_fire)
	// Its turn would never come.
	if(!QDELETED(view) && view.turns == turns)
		SScharacter_preview.rebuild(view)

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
	// A window opens with its lights on.
	lights_off = FALSE
	drawn_lights_off = FALSE
	animation_read = FALSE
	SScharacter_preview.reading_waiters -= src

/**
 * Draws a walk's facings into one strip with iconforge, or finds the same look already drawn, and returns the page's
 * data for the strip, or null if it couldn't be drawn.
 */
/datum/preference_middleware/character_preview/proc/draw_preview(list/walk)
	var/list/recipes = walk["recipes"]
	var/list/glow_recipes = walk["glow_recipes"]
	var/list/entries = list()
	for(var/facing, recipe in recipes)
		entries += "\"[facing]\":[recipe]"
	// Each facing's glow, on the facing's canvas, goes into the same strip.
	for(var/facing, recipe in glow_recipes)
		entries += "\"[facing]_glow\":[recipe]"
	// What moves, its patches side by side in one image, "moving", which goes in a strip of its own unless it happens to
	// be the facings' size.
	var/list/animation = walk["animation"]
	var/list/moving_json = animation?["json"]
	if(moving_json)
		entries += jointext(moving_json, "")
	var/entries_json = "{[jointext(entries, ",")]}"
	var/name = "preview_[rustg_hash_string(RUSTG_HASH_MD5, entries_json)]"
	var/list/drawn = GLOB.character_preview_drawings[name]
	if(drawn)
		return drawn

	// A file name of its own, so two characters drawing the same look at once don't share a file.
	var/static/drawings_made = 0
	var/sheet = "preview_[++drawings_made]"
	// While iconforge is to let go of what it keeps, new drawings wait for it; see iconforge_drawn(). Never for longer than
	// CHARACTER_PREVIEW_JOB_TIMEOUT, however often other drawings put the cleanup off meanwhile.
	var/asked = world.time
	UNTIL(isnull(GLOB.character_preview_cleanup_due) || world.time > min(GLOB.character_preview_cleanup_due, asked) + CHARACTER_PREVIEW_JOB_TIMEOUT)
	GLOB.character_preview_cleanup_due = null
	var/job = rustg_iconforge_generate_async(CHARACTER_PREVIEW_DIR, sheet, entries_json, FALSE, FALSE, TRUE)
	var/started = world.time
	GLOB.character_preview_jobs[job] = started
	var/result
	// A job that never answers is given up on, and fails the check below: the preview is never left waiting for good.
	UNTIL((result = rustg_iconforge_check(job)) != RUSTG_JOB_NO_RESULTS_YET || world.time > started + CHARACTER_PREVIEW_JOB_TIMEOUT)
	GLOB.character_preview_jobs -= job
	iconforge_drawn()
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
	var/moving_size_id = moving_json ? sprites?["moving"]?["size_id"] : null
	var/moving_apart = !isnull(moving_size_id) && moving_size_id != size_id
	var/moving_image = moving_apart ? rustg_hash_file(RUSTG_HASH_BASE64, "[CHARACTER_PREVIEW_DIR][sheet]_[moving_size_id].png") : null
	for(var/size in sizes)
		fdel("[CHARACTER_PREVIEW_DIR][sheet]_[size].png")
	// The facings of one mob are one size, and so are their glows, so they share a strip.
	if(!image || length(sizes) != (moving_apart ? 2 : 1) || (moving_apart && !moving_image) || length(sprites) != length(recipes) + length(glow_recipes) + (moving_json ? 1 : 0))
		return null
	var/list/size = splittext(size_id, "x")
	var/width = text2num(size[1])
	// iconforge lays the facings out in any order.
	var/list/frames = list()
	var/list/glow_frames
	for(var/facing, sprite in sprites)
		if(recipes[facing])
			frames[facing] = sprite["position"] * width
		else if(facing != "moving")
			LAZYSET(glow_frames, copytext(facing, 1, -length("_glow")), sprite["position"] * width)
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
	// Each facing's glow, drawn only with the lights off and only for a look that has something to glow.
	if(glow_frames)
		drawn["glow_frames"] = glow_frames
	// What moves: each facing's regions, each its box and its steps, a patch's left edge in "moving" (-1 for the facing
	// as drawn) and how long it shows. "moving" the facings' size shares their strip, at its own place in it.
	if(moving_json)
		var/list/moving = list("left" = moving_apart ? 0 : sprites["moving"]["position"] * width, "facings" = animation["facings"])
		if(moving_apart)
			moving["image"] = "data:image/png;base64,[moving_image]"
		drawn["animation"] = moving
	GLOB.character_preview_drawings[name] = drawn
	return drawn

#undef CHARACTER_PREVIEW_DIR

/**
 * A drawing is done: a character preview's, or `share` of one for a smaller picture, like the custom sprite editors'.
 * iconforge keeps every image it makes until it is told to let them go, and a look is hardly ever drawn twice, so what
 * it keeps only grows, by 80 to 330 KB a look. Every CHARACTER_PREVIEW_CLEANUP_EVERY looks' worth it lets go, once no
 * character preview is under way: one under way would come out empty. Until then new previews wait, for a tick or
 * two, and the last preview under way lets go when it is done. Spritesheets being made let go themselves once they
 * are done, so it waits for them to finish.
 */
/proc/iconforge_drawn(share = 1)
	GLOB.iconforge_drawn_since_cleanup += share
	if(GLOB.iconforge_drawn_since_cleanup < CHARACTER_PREVIEW_CLEANUP_EVERY)
		return
	if(length(SSasset_loading.generate_queue) || SSasset_loading.assets_generating)
		GLOB.character_preview_cleanup_due = null
		return
	if(character_preview_drawing_under_way())
		GLOB.character_preview_cleanup_due ||= world.time
		return
	// Skipped while something else is putting away what it made; the next drawing asks again.
	if(rustg_iconforge_cleanup() == "Ok")
		GLOB.iconforge_drawn_since_cleanup = 0
	GLOB.character_preview_cleanup_due = null

/**
 * Whether iconforge is drawing a character preview now, which letting go of what it keeps would spoil. tg's asset
 * loader asks too, as it lets go on every fire once its queue has emptied. A drawing whose proc was killed stops
 * counting after CHARACTER_PREVIEW_JOB_TIMEOUT.
 */
/proc/character_preview_drawing_under_way()
	for(var/job in GLOB.character_preview_jobs)
		if(world.time > GLOB.character_preview_jobs[job] + CHARACTER_PREVIEW_JOB_TIMEOUT)
			GLOB.character_preview_jobs -= job
	return length(GLOB.character_preview_jobs) > 0

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
 *
 * With `glow`, a look with something that glows also gets "glow_recipes": each facing's glow on the same canvas; see
 * character_preview_glow(). A look with nothing that glows draws no more than it would without.
 *
 * With `animate`, a look with something animated also gets "animation": its patches and their steps; see
 * character_preview_animation().
 */
/proc/character_preview_walk(atom/look, glow = FALSE, animate = FALSE)
	var/mob/living/body = look
	if(!istype(body) || !character_preview_turns_itself(body))
		var/datum/universal_icon/flat = get_flat_uni_icon(look, UP, grow = TRUE)
		var/list/box = character_preview_flat_box(flat)
		. = list("recipes" = uni_icon_facings_json(flat, GLOB.character_preview_facings), "height" = box[4], "x" = 1 - box[1], "y" = 1 - box[2])
		var/datum/universal_icon/glow_flat = glow ? character_preview_glow(look, UP, box) : null
		if(glow_flat)
			.["glow_recipes"] = uni_icon_facings_json(glow_flat, GLOB.character_preview_facings)
		if(animate)
			var/list/same_flat = list()
			for(var/facing in GLOB.character_preview_facings)
				same_flat[facing] = flat
			var/list/animation = character_preview_animation(same_flat, TRUE, box[3], box[4])
			if(animation)
				.["animation"] = animation
		return
	var/old_dir = body.dir
	var/list/flats = list()
	var/list/glows = glow && emissive_branches_lit(emissive_branches(body)) ? list() : null
	for(var/facing, dir in GLOB.character_preview_facings)
		body.setDir(dir)
		var/datum/universal_icon/flat = get_flat_uni_icon(body, dir, grow = TRUE)
		flats[facing] = flat
		// On the facing's own canvas for now; both are cropped to the one that fits all four below. Every facing has
		// one, blank if nothing glows that way.
		if(glows)
			glows[facing] = character_preview_glow(body, dir, character_preview_flat_box(flat), always = TRUE)
	body.setDir(old_dir)
	// The canvas that fits every facing, from the look's own lower left pixel.
	var/x1 = INFINITY
	var/y1 = INFINITY
	var/x2 = -INFINITY
	var/y2 = -INFINITY
	for(var/facing in flats)
		var/list/box = character_preview_flat_box(flats[facing])
		x1 = min(x1, box[1])
		y1 = min(y1, box[2])
		x2 = max(x2, box[1] + box[3] - 1)
		y2 = max(y2, box[2] + box[4] - 1)
	var/list/recipes = list()
	var/list/glow_recipes
	for(var/facing in flats)
		var/datum/universal_icon/flat = flats[facing]
		var/list/box = character_preview_flat_box(flat)
		flat.crop(x1 - box[1] + 1, y1 - box[2] + 1, x2 - box[1] + 1, y2 - box[2] + 1)
		recipes[facing] = flat.to_json()
		// The glow was cropped to the facing's canvas, so it moves as the facing does.
		var/datum/universal_icon/glow_flat = glows?[facing]
		if(glow_flat)
			glow_flat.crop(x1 - box[1] + 1, y1 - box[2] + 1, x2 - box[1] + 1, y2 - box[2] + 1)
			LAZYSET(glow_recipes, facing, glow_flat.to_json())
	. = list("recipes" = recipes, "height" = y2 - y1 + 1, "x" = 1 - x1, "y" = 1 - y1)
	if(glow_recipes)
		.["glow_recipes"] = glow_recipes
	if(animate)
		var/list/animation = character_preview_animation(flats, FALSE, x2 - x1 + 1, y2 - y1 + 1)
		if(animation)
			.["animation"] = animation

/**
 * A flat icon's canvas, list(x1, y1, width, height): where its lower left pixel sits, counted from the flattened look's
 * own (1, 1), and its size. A grown canvas says so itself; any other is its icon's, at (1, 1).
 */
/proc/character_preview_flat_box(datum/universal_icon/flat)
	var/list/size = flat.flat_width ? list("width" = flat.flat_width, "height" = flat.flat_height) : get_icon_dimensions(flat.icon_file)
	return list(isnull(flat.flat_x1) ? 1 : flat.flat_x1, isnull(flat.flat_y1) ? 1 : flat.flat_y1, size?["width"] || ICON_SIZE_X, size?["height"] || ICON_SIZE_Y)

/// Whether something redraws a mob when it turns, so each facing of it has to be walked on its own.
/proc/character_preview_turns_itself(mob/living/body)
	return !!(body._listen_lookup?[COMSIG_ATOM_DIR_CHANGE] || body._listen_lookup?[COMSIG_ATOM_POST_DIR_CHANGE])
