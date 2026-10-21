/// Of each second, how many ms every painter's composites together may take, freehand sessions' and paint job steps
/// alike. Past it they wait their turn in SSgraffiti's composite line, so with many painters each one's come further
/// apart rather than time dilating. A typical one-tile composite takes 11-15 ms, so about ten painters keep the full
/// spacing. Measured on one build (2026-10-20), it took a hundred freehand painters at the topic limit from
/// 670 to 102 ms/s of composites and +57.2% to +3.0% time dilation, and twenty adversarial ones from +16.0% to +0.8%.
#define GRAFFITI_COMPOSITE_SHARE 100
/// Percent of each tick the background load of the map's graffiti takes at most (load_yield()), so it spreads over the
/// lobby without the server feeling it: a full map of adversarial art took about 22 s of work, about 90 s at this share.
#define GRAFFITI_LOAD_SHARE 20
/// How long a painter waiting in SSgraffiti's composite line keeps its place without asking again, as one no longer due
/// stops asking. SScustom_sprite_work asks for every waiting painter each tick it gets through its queue.
#define GRAFFITI_COMPOSITE_LINE_GRACE (1 SECONDS)
/// How long a map's graffiti file waits after a change before it is written. A full map of dense art takes about 300 ms
/// to write (measured), so a minute; the round-end save and Shutdown() still write the last changes.
#define GRAFFITI_SAVE_DEBOUNCE (1 MINUTES)
/// Tile composites packed into one sprite sheet at load: of the packings whose sheet files stay within 256 KiB, the one
/// with the fewest bytes a state, measured on worst-case art: 32 a sheet takes 1,791 bytes a state, largest sheet
/// 113 KB; 64 takes 1,811, largest 225 KB; 128 reaches 448 KB.
#define GRAFFITI_SHEET_STATES 32
/// Most unique arts one account keeps on one map: a tenth of GRAFFITI_MAP_UNIQUE_CAP.
#define GRAFFITI_CKEY_UNIQUE_CAP 200
/// The map file versions this server reads. Version 1's anchors may record `wall` rather than their `surface`, and its
/// placements the piece's name and description: loading converts the one and drops the other, and the next save writes
/// the file as GRAFFITI_MAP_VERSION.
#define GRAFFITI_MAP_READ_VERSIONS list(1, GRAFFITI_MAP_VERSION)
/// Most bytes, estimated, of decoded art a map's load keeps at once for its merges and sheets: about 400 dense one-tile
/// arts. Art past it is decoded again where it is needed. Freed memory stays with the process, so this bounds what a
/// load adds to the server's high-water mark.
#define GRAFFITI_DECODE_BUDGET (8 * 1024 * 1024)

/// A map's graffiti file, held to GRAFFITI_MAP_MAX_BYTES.
/datum/json_savefile/custom_sprites/graffiti/map
	size_limit = GRAFFITI_MAP_MAX_BYTES

/**
 * Writes the map's JSON as the graffiti stores' save() writes a tree (library.dm), with the revision kept as an md5:
 * staged and checked first, then the backup made to hold the last verified revision, then the primary written and
 * checked, then copied over the backup, so that once a write is done no file keeps what it dropped and an interrupted
 * write of the primary still recovers the revision before. Each file is checked by its md5 against the text in hand, so
 * nothing written is read back into text, and only the text's md5 stays. The backup is copied from the primary on disk.
 * A backup that can't be copied then leaves the write standing, as the primary holds it, and the next write copies the
 * backup again.
 *
 * Trust rule: the primary holds the last verified revision, or the backup does after a failed write or a load from the
 * backup; a revision in neither file means the file changed outside the server.
 *
 * A write that succeeds, as a load from the primary does, leaves the primary holding the revision. So when it no longer
 * does, unless the last write failed or the file was loaded from its backup, or when neither file does, the file
 * changed outside the server: what the primary holds now, or else the backup, is kept as the backup instead until the
 * next write, and the write goes ahead.
 *
 * Arguments:
 * - text: The file's JSON.
 *
 * Returns:
 * - TRUE/FALSE: Whether the file on disk now holds the text. Its backup does too unless the file changed outside the
 *   server or the backup couldn't be copied.
 */
/datum/json_savefile/custom_sprites/graffiti/map/proc/write_text(text)
	// After a failed write or a load from the backup, only the backup is sure to hold the revision.
	var/trusted = !last_save_failed
	last_save_failed = TRUE
	if(!path || isnull(last_good_json))
		return FALSE
	var/new_hash = md5(text)
	if(!write_hashed(text, new_hash, "[path].new"))
		return FALSE
	var/backup_path = "[path].bak"
	var/revision = last_good_json
	var/changed = FALSE
	// A file never written has the parent's "[]" for its revision, which its backup gets as the parent writes it.
	if(revision == "\[]")
		if(rustg_file_read(backup_path) != revision && !write_hashed(revision, md5(revision), backup_path))
			return FALSE
	else
		var/backup_hash = rustg_hash_file(RUSTG_HASH_MD5, backup_path)
		var/current = fexists(path) ? rustg_hash_file(RUSTG_HASH_MD5, path) : null
		changed = current != revision && (trusted || backup_hash != revision)
		if(changed)
			log_game("The graffiti file [path] changed outside the server, so what it holds now is kept as its backup.")
			// The revision is now what the backup keeps, should this write fail.
			last_good_json = current || (fexists(backup_path) ? backup_hash : "\[]")
		if(changed || backup_hash != revision)
			if(current)
				if(backup_hash != current && (!fcopy(path, backup_path) || rustg_hash_file(RUSTG_HASH_MD5, backup_path) != current))
					return FALSE
			else if(!fexists(backup_path) && !write_hashed("\[]", md5("\[]"), backup_path))
				return FALSE
	if(!write_hashed(text, new_hash, path))
		return FALSE
	last_good_json = new_hash
	dirty = FALSE
	fdel("[path].new")
	// The primary holds the revision, so the write stands, and the next one copies the backup again.
	if(!changed && (!fcopy(path, backup_path) || rustg_hash_file(RUSTG_HASH_MD5, backup_path) != new_hash))
		log_game("The graffiti file [path] was saved, but its backup couldn't be written; the next save tries again.")
		return TRUE
	last_save_failed = FALSE
	return TRUE

/**
 * The graffiti on the current map: the art and placements its file keeps, which of them show this round, and the sheet
 * files they show from.
 *
 * Each placement is kept as one JSON string, `json_encode()` of list("anchor", "art" = its art's hash, "ckey", "who",
 * "at", "pid", "half", "miss"), and read with unpack(). A piece's name and description stay in its painter's library. A
 * placement that lasts only this round has a null anchor, "round_only" and its turf's "x", "y" and "z".
 */
SUBSYSTEM_DEF(graffiti)
	name = "Graffiti"
	ss_flags = SS_NO_FIRE
	dependencies = list(
		/datum/controller/subsystem/mapping,
		/datum/controller/subsystem/atoms,
	)
	/// Art hash -> the flat art, for every art a placement uses.
	var/list/art = list()
	/// Art hash -> how many placements use it.
	var/list/art_refs = list()
	/// The bytes of every art in `art`, as art_size() counts them.
	var/art_bytes = 0
	/// Most bytes of art the map keeps. Tests lower it.
	var/art_byte_budget = GRAFFITI_MAP_ART_BYTES
	/// Every placement, packed, in the order they were placed, which each tile's stack follows.
	var/list/placements = list()
	/// The packed placements not shown this round.
	var/list/dormant = list()
	/// Packed placement -> the decal showing it, for every placement shown this round.
	var/list/shown = list()
	/// Ckey -> when its owner last connected, as ten-digit unix seconds in text.
	var/list/seen = list()
	/// Stack key -> list(the sheet file's resource, whether it holds the stack's glow mask).
	var/list/sheets = list()
	/// Art hash -> how many shown placements use it, so its length counts the unique arts shown.
	var/list/displayed_unique = list()
	/// Packed placement -> list(ckey, art hash, "at", pid, "who", whether it lasts this round only), read through the
	/// GRAFFITI_INFO_* indices: what placement operations read of a placement without unpacking it.
	var/list/placement_info = list()
	/// Ckey -> its packed placements, in the order its own caps evict them: by "at", then as `placements` orders them.
	var/list/ckey_placements = list()
	/// Ckey -> art hash -> how many of its placements use it.
	var/list/ckey_arts = list()
	/// Sort -> every packed placement in that order, for admin_rows(), until the placements change.
	var/list/admin_orders = list()
	/// Packed placement -> the area admin_rows() shows and sorts it under, until the placements change.
	var/list/admin_areas = list()
	/// Art hash -> graffiti_art_decode() of the arts and stack composites decoded while the map loads, for the load's
	/// merges and sheets, within GRAFFITI_DECODE_BUDGET. Null once build_sheets() has drawn them.
	var/list/decoded
	/// The estimated bytes `decoded` holds.
	var/total_size = 0
	/// Stack signature (stack_signature()) -> list(its key, its graffiti_art_glow_kind()), from the map file, while the
	/// load places its stacks: a stack it lists takes them without merging, as long as merges still give what they gave
	/// when the file was written (graffiti_merge_fingerprint()). Null otherwise.
	var/list/stack_cache
	/// The map's graffiti file.
	var/datum/json_savefile/custom_sprites/graffiti/map/store
	/// Where the map's graffiti file is. Tests point it at a scratch file through load_file().
	var/map_path
	/// The timer that will write the map file, while one is pending.
	var/save_pending
	/// Whether the round-end save has run, after which nothing is written.
	var/frozen = FALSE
	/// Most unique arts shown in a round. Tests lower it.
	var/display_budget = GRAFFITI_DISPLAY_BUDGET
	/// Most placements the map keeps. Tests lower it.
	var/placement_cap = GRAFFITI_MAP_PLACEMENT_CAP
	/// The directory every map's sheet files go under. Tests move it.
	var/sheet_root = GRAFFITI_SHEET_DIRECTORY
	/// How many sheet files the last build_sheets() wrote rather than reused.
	var/sheets_built = 0
	/// Whether the admins were told this round that the map file couldn't be written.
	var/save_failure_told = FALSE
	/// How many ms of composites may still run now, every painter's together. Below zero, they went over, and that is
	/// paid back first.
	var/composite_share = GRAFFITI_COMPOSITE_SHARE_BURST
	/// When composite_share was last topped up.
	var/composite_share_at = 0
	/// Whether the map's graffiti has loaded, which it does in the background once the game reaches the lobby
	/// (load_in_background()): until then nothing is placed, saved or deleted by an admin.
	var/loaded = FALSE
	/// TICK_USAGE when the background load last went on in a tick, which its share of the tick counts from.
	var/load_resumed_at = 0
	/// Percent of each tick the load takes at most: GRAFFITI_LOAD_SHARE, or the whole tick in unit tests and benchmarks,
	/// which time the load's work rather than spread it.
	var/load_share = GRAFFITI_LOAD_SHARE
	/// The editors and paint jobs waiting for composite_share, in the order they first asked, -> when each last asked.
	var/list/composite_line = list()
	/// Ckey -> that player's graffiti editor. A player has one at a time, opened through graffiti_editor_for().
	var/list/editors = list()
	/// Ckey -> that player's running paint job. A player runs one at a time.
	var/list/paint_jobs = list()
	/// Ckey -> the world.time from which that player may start another freehand session or paint job.
	var/list/start_cooldowns = list()
	/// Account ckey -> its loaded graffiti library.
	var/list/libraries = list()
	/// The directory library files go under. Tests point it at a scratch directory; admins can't edit it (vv_edit_var()).
	var/library_root = GRAFFITI_LIBRARY_DIRECTORY
	/// The last revision any graffiti library took. A library loaded again after a purge never repeats one an open window
	/// saw.
	var/library_revision = 0
	/// graffiti_art_hash() -> the icon graffiti_art_icon() drew of that art, up to GRAFFITI_ICON_CACHE of them.
	var/list/art_icons = list()
	/// graffiti_art_hash() -> the glow mask graffiti_glow_icon() drew of that art, up to GRAFFITI_ICON_CACHE of them.
	var/list/glow_icons = list()
	/// Map templates loaded this round on station levels, oldest first: list("id" = the template's map file, "x", "y",
	/// "z" = its low corner, "w", "h"). Recorded from SSmapping's init on, before this subsystem initializes.
	var/list/loaded_templates = list()
	/// Anchor kind -> the /datum/callback a system registered to turn an anchor of that kind into a turf, or null.
	var/list/anchor_resolvers = list()

/**
 * Leaves the map's graffiti for the lobby, so loading it takes none of the server's startup: once every subsystem has
 * initialized and the game reaches the lobby, it loads in the background (load_in_background()). Unit tests load it at
 * once, as they read the registry straight away.
 *
 * Returns:
 * - SS_INIT_SUCCESS
 */
/datum/controller/subsystem/graffiti/Initialize()
#ifdef UNIT_TESTS
	load_share = 100
	load_in_background()
#else
	RegisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME, PROC_REF(on_pregame))
#endif
	return SS_INIT_SUCCESS

/**
 * Starts the background load as the game reaches the lobby.
 *
 * Arguments:
 * - source: SSticker.
 */
/datum/controller/subsystem/graffiti/proc/on_pregame(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(SSticker, COMSIG_TICKER_ENTER_PREGAME)
	INVOKE_ASYNC(src, PROC_REF(load_in_background))

/**
 * Loads the map's graffiti onto its tiles a share of each tick at a time (load_yield()), then starts noting who
 * connects. Decals show their art once their chunk's sheet is drawn.
 */
/datum/controller/subsystem/graffiti/proc/load_in_background()
	load_resumed_at = TICK_USAGE
	load_file()
	// Players already connected as the load began missed the signal.
	var/now = graffiti_unix_time()
	var/list/connected = list()
	for(var/client/player as anything in GLOB.clients)
		seen[player.ckey] = now
		connected[player.ckey] = TRUE
	place_all()
	build_sheets()
	loaded = TRUE
	RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, PROC_REF(on_client_connect))
	// Players who connected while the map's graffiti loaded get what connecting gives them now.
	for(var/client/player as anything in GLOB.clients)
		if(!connected[player.ckey])
			on_client_connect(SSdcs, player)

/**
 * Lets the background load go on in this tick until it has taken `load_share` percent of it, or the tick is full,
 * then waits for the next, so the load spreads evenly over the ticks and the server never feels it. Each wait comes
 * between two pieces of the load, the largest a tile's stack merged or one icon drawn.
 */
/datum/controller/subsystem/graffiti/proc/load_yield()
	if(TICK_USAGE - load_resumed_at < load_share && !TICK_CHECK)
		return
	stoplag()
	load_resumed_at = TICK_USAGE

/**
 * Takes over everything the subsystem being replaced kept, as the Master Controller restarts: the map's graffiti, the
 * libraries and the painting under way.
 */
/datum/controller/subsystem/graffiti/Recover()
	for(var/name in list("art", "art_refs", "art_bytes", "art_byte_budget", "placements", "dormant", "shown", "seen", "sheets", "displayed_unique", "placement_info", "ckey_placements", "ckey_arts", "admin_orders", "admin_areas", "decoded", "total_size", "stack_cache", "store", "map_path", "save_pending", "frozen", "display_budget", "placement_cap", "sheet_root", "sheets_built", "save_failure_told", "loaded", "load_resumed_at", "load_share", "composite_share", "composite_share_at", "composite_line", "editors", "paint_jobs", "start_cooldowns", "libraries", "library_root", "library_revision", "art_icons", "glow_icons", "loaded_templates", "anchor_resolvers"))
		vars[name] = SSgraffiti.vars[name]

/**
 * Refuses admin edits of the library directory, which library files are written under.
 *
 * Arguments:
 * - var_name: The var.
 * - var_value: Its new value.
 *
 * Returns:
 * - TRUE/FALSE: Whether the var was edited.
 */
/datum/controller/subsystem/graffiti/vv_edit_var(var_name, var_value)
	if(var_name == NAMEOF(src, library_root))
		return FALSE
	return ..()

/**
 * Makes the final save when the world stops, for a reboot that skips the round-end save, and writes the library
 * changes the write pacing still holds back. After the round-end save the map file isn't written again.
 */
/datum/controller/subsystem/graffiti/Shutdown()
	save_now(TRUE)
	graffiti_library_flush()

/**
 * Whether it is a painter's turn to composite. Every painter's composites together take at most
 * GRAFFITI_COMPOSITE_SHARE ms a second of game time, so under a dilating server they get less, and those waiting for
 * room take it in the order they first asked (`composite_line`). Asking keeps the owner's place; running its composite
 * gives it up, the owner taking itself out of the line, and so does not asking for GRAFFITI_COMPOSITE_LINE_GRACE, as an
 * owner no longer due doesn't.
 *
 * Arguments:
 * - owner: The editor or paint job that would composite.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/controller/subsystem/graffiti/proc/composite_turn(datum/custom_sprite_work_owner/owner)
	composite_share = min(composite_share + (world.time - composite_share_at) * GRAFFITI_COMPOSITE_SHARE / (1 SECONDS), GRAFFITI_COMPOSITE_SHARE_BURST)
	composite_share_at = world.time
	composite_line[owner] = world.time
	for(var/attempt in 1 to length(composite_line))
		var/first = composite_line[1]
		if(first == owner || composite_line[first] >= world.time - GRAFFITI_COMPOSITE_LINE_GRACE)
			break
		composite_line.Cut(1, 2)
	return composite_share > 0 && composite_line[1] == owner

/**
 * Takes a composite's time out of composite_share, a session's last one and a paint job's finish included, which run
 * whether or not there is room.
 *
 * Arguments:
 * - started: TICK_USAGE_REAL as the composite started.
 */
/datum/controller/subsystem/graffiti/proc/spend_composite(started)
	composite_share -= TICK_DELTA_TO_MS(TICK_USAGE_REAL - started)

/**
 * Reads a packed placement.
 *
 * Arguments:
 * - packed: The placement, as `placements` keeps it.
 *
 * Returns:
 * - list: The placement. Changing it changes nothing in the registry.
 */
/datum/controller/subsystem/graffiti/proc/unpack(packed)
	return json_decode(packed)

/**
 * Loads a map file in place of whatever the registry held, keeping only what is valid and within the caps.
 *
 * Art that isn't valid one-tile art under its own hash, placements whose art is missing or whose fields have the wrong
 * types, and the lowest-ranked placements and arts past the map caps are dropped and counted in one log line. A file
 * that can't be read, or has a version GRAFFITI_MAP_READ_VERSIONS doesn't list, leaves the registry empty and unsaved,
 * so the file stays for an admin. An older version's file is read as this version's, which its next save writes.
 *
 * The current map's own file is named by graffiti_file_key() of its name. An admin-loaded custom map, whose name is
 * whatever the admin typed, has no file: its store has no path, so nothing is read or written.
 *
 * Arguments:
 * - path: The file, or null for the current map's own.
 */
/datum/controller/subsystem/graffiti/proc/load_file(path = null)
	map_path = path || "[GRAFFITI_MAP_DIRECTORY][graffiti_file_key(SSmapping.current_map.map_name)].json"
	store = new((path || SSmapping.current_map.map_path != CUSTOM_MAP_PATH) ? map_path : null)
	art = list()
	art_refs = list()
	art_bytes = 0
	placements = list()
	dormant = list()
	shown = list()
	displayed_unique = list()
	seen = list()
	placement_info = list()
	ckey_placements = list()
	ckey_arts = list()
	admin_changed()
	drop_decoded()
	if(isnull(store.last_good_json))
		log_game("The graffiti file [map_path] couldn't be read, so this map's graffiti stays empty and unsaved this round.")
		return
	var/list/tree = store.get_entry()
	if(!length(tree))
		return
	if(!(tree["version"] in GRAFFITI_MAP_READ_VERSIONS))
		store.path = null
		store.wipe()
		log_game("The graffiti file [map_path] has an unsupported version, so this map's graffiti stays empty and unsaved this round.")
		return
	var/list/stored = tree["seen"]
	for(var/ckey, time in (islist(stored) ? stored : null))
		if(istext(ckey) && istext(time))
			seen[ckey] = time
	var/list/known = list()
	var/broken = 0
	decoded = list()
	var/list/cached_stacks = tree["stacks"]
	if(islist(cached_stacks) && cached_stacks["print"] == graffiti_merge_fingerprint() && islist(cached_stacks["keys"]))
		stack_cache = cached_stacks["keys"]
	// Should a runtime stop the load before build_sheets(), the decodes still go, once the slowest load would be over.
	addtimer(CALLBACK(src, PROC_REF(drop_decoded)), 10 MINUTES)
	stored = tree["art"]
	for(var/hash, entry in (islist(stored) ? stored : null))
		load_yield()
		var/list/clean = islist(entry) ? list("w" = entry["w"], "pal" = entry["pal"], "grid" = entry["grid"], "glow" = entry["glow"], "k" = entry["k"]) : null
		if(clean?["w"] != GRAFFITI_WIDTH || graffiti_art_hash(clean) != hash)
			broken++
			continue
		// Under its own hash, the art is what the server wrote, so with its glow kind kept it is taken as it is and decoded
		// only should a sheet need drawing.
		if(clean["k"] in list(GRAFFITI_GLOW_NONE, GRAFFITI_GLOW_ALL, GRAFFITI_GLOW_MIXED))
			known[hash] = clean
			continue
		// Decoded once here for the checks, and kept for the load's merges and sheets while the budget allows.
		var/list/record = graffiti_art_decode(clean)
		if(!record)
			broken++
			continue
		clean["k"] = graffiti_art_glow_kind(clean, record)
		known[hash] = clean
		keep_decoded(hash, record, clean)
	var/list/kept = list()
	var/dropped = 0
	stored = tree["placements"]
	for(var/entry in (islist(stored) ? stored : null))
		load_yield()
		var/list/placement = check_placement(entry, known)
		var/packed = placement && json_encode(placement)
		// An exact repeat can't be told from its first, so only the first is kept.
		if(!packed || placement_info[packed])
			dropped++
			continue
		kept += packed
		index_placement(packed, placement)
	// A placement let go of while this waited for a tick stays out.
	for(var/packed in kept.Copy())
		if(!placement_info[packed])
			kept -= packed
	var/list/hashes = list()
	var/bytes = 0
	for(var/packed in kept)
		var/hash = placement_info[packed][GRAFFITI_INFO_ART]
		if(!hashes[hash])
			hashes[hash] = TRUE
			bytes += art_size(known[hash])
	if(length(kept) > placement_cap || length(hashes) > GRAFFITI_MAP_UNIQUE_CAP || bytes > art_byte_budget)
		// The best-ranked keep their place, in file order, while their art fits.
		var/list/keep = list()
		hashes = list()
		bytes = 0
		for(var/packed in rank(kept))
			if(length(keep) >= placement_cap)
				break
			var/hash = placement_info[packed][GRAFFITI_INFO_ART]
			if(!hashes[hash])
				var/size = art_size(known[hash])
				if(length(hashes) >= GRAFFITI_MAP_UNIQUE_CAP || bytes + size > art_byte_budget)
					continue
				bytes += size
			hashes[hash] = TRUE
			keep[packed] = TRUE
		for(var/packed in kept)
			if(!keep[packed])
				unindex_placement(packed)
		dropped += length(kept) - length(keep)
		kept &= keep
	for(var/packed in kept)
		var/hash = placement_info[packed][GRAFFITI_INFO_ART]
		if(!art[hash])
			art[hash] = known[hash]
			art_bytes += art_size(known[hash])
		art_refs[hash] += 1
	placements = kept
	// Only the art kept stays decoded.
	keep_only_decoded(art)
	// The registry keeps its own copies, so the store holds nothing between saves.
	store.wipe()
	if(dropped || broken)
		log_game("The graffiti file [map_path] loaded [length(placements)] placement\s and dropped [dropped] placement\s and [broken] art\s that were invalid or past the map's caps.")

/**
 * Returns a placement read from a map file in the form the registry keeps, with its painter's name cleaned again. Fields
 * the registry doesn't keep, such as the names and descriptions placements once carried, are left out.
 *
 * Arguments:
 * - entry: The placement as the file has it.
 * - known: Art hash -> art, for the file's valid art.
 *
 * Returns:
 * - list: The placement.
 * - null: Its art isn't in `known`, or a field is missing or has the wrong type.
 */
/datum/controller/subsystem/graffiti/proc/check_placement(list/entry, list/known)
	if(!islist(entry) || !istext(entry["art"]) || !known[entry["art"]])
		return null
	var/list/anchor = check_anchor(entry["anchor"])
	if(!anchor)
		return null
	for(var/key in list("ckey", "who", "at", "pid"))
		if(!istext(entry[key]))
			return null
	var/ckey = entry["ckey"]
	if(!length(ckey) || spantext(ckey, "abcdefghijklmnopqrstuvwxyz0123456789_@") != length(ckey) || !(entry["half"] in list(0, 1, 2)) || !isnum(entry["miss"]) || entry["miss"] < 0)
		return null
	return list("anchor" = anchor, "art" = entry["art"], "ckey" = ckey, "who" = graffiti_clean_text(entry["who"], MAX_NAME_LEN), "at" = entry["at"], "pid" = entry["pid"], "half" = entry["half"], "miss" = round(entry["miss"]))

/**
 * Returns an anchor read from a file with only the fields its kind uses, as graffiti_anchor_for() writes them. One
 * saved before windows took graffiti records `wall`, whether its surface is a wall, which is read as a wall or a floor.
 *
 * Arguments:
 * - anchor: The anchor as the file has it.
 *
 * Returns:
 * - list: The anchor. One of a kind this module doesn't place is copied whole, with its `surface`, for its resolver to
 *   check.
 * - null: A field is missing or has the wrong type.
 */
/datum/controller/subsystem/graffiti/proc/check_anchor(list/anchor)
	if(!islist(anchor))
		return null
	var/surface = anchor["surface"]
	if(isnull(surface) && (anchor["wall"] in list(0, 1)))
		surface = anchor["wall"] ? GRAFFITI_KIND_WALL : GRAFFITI_KIND_FLOOR
	if(!(surface in list(GRAFFITI_KIND_WALL, GRAFFITI_KIND_FLOOR, GRAFFITI_KIND_WINDOW)))
		return null
	switch(anchor["kind"])
		if(GRAFFITI_ANCHOR_STATION)
			if(isnum(anchor["x"]) && isnum(anchor["y"]) && isnum(anchor["z"]) && istext(anchor["area"]))
				return list("kind" = GRAFFITI_ANCHOR_STATION, "x" = anchor["x"], "y" = anchor["y"], "z" = anchor["z"], "area" = anchor["area"], "surface" = surface)
			return null
		// Map templates have taken no graffiti since 2026-10-21, so what a file still keeps in one is dropped.
		if("template")
			return null
	if(!istext(anchor["kind"]))
		return null
	var/list/copy = anchor.Copy()
	copy -= "wall"
	copy["surface"] = surface
	return copy

/**
 * Orders placements from the one to keep showing most to the first to evict: an owner who is connected first, then
 * owners seen most recently, then the newest placement, then the one later in `candidates`.
 *
 * Arguments:
 * - candidates: Packed placements the registry has indexed.
 *
 * Returns:
 * - list: The packed placements in that order, each associated with its sort key.
 */
/datum/controller/subsystem/graffiti/proc/rank(list/candidates)
	var/list/sorted = list()
	for(var/position in 1 to length(candidates))
		var/packed = candidates[position]
		var/list/info = placement_info[packed]
		var/ckey = info[GRAFFITI_INFO_CKEY]
		// Times are ten-digit text, so one descending text sort orders every field.
		sorted[packed] = "[GLOB.directory[ckey] ? 1 : 0][seen[ckey] || "0000000000"][info[GRAFFITI_INFO_AT]][position + 100000]"
	return sortTim(sorted, GLOBAL_PROC_REF(cmp_text_dsc), associative = TRUE)

/**
 * Returns the lowest-ranked placement whose owner isn't connected, as rank() orders them: the owner seen longest ago,
 * then that owner's oldest placement, then the one earlier in `placements`. It reads each owner's index instead of
 * ranking every placement.
 *
 * Returns:
 * - text: The packed placement.
 * - null: Every owner is connected.
 */
/datum/controller/subsystem/graffiti/proc/lowest_unconnected()
	var/lowest
	var/lowest_seen
	var/lowest_at
	for(var/ckey, value in ckey_placements)
		if(GLOB.directory[ckey])
			continue
		var/list/mine = value
		// An account's index starts with its own lowest-ranked placement.
		var/packed = mine[1]
		var/owner_seen = seen[ckey] || "0000000000"
		var/at = placement_info[packed][GRAFFITI_INFO_AT]
		if(lowest)
			var/order = sorttext(owner_seen, lowest_seen) || sorttext(at, lowest_at)
			// Ranked above the lowest so far, or level with it and later in `placements`.
			if(order == -1 || (!order && placements.Find(packed) > placements.Find(lowest)))
				continue
		lowest = packed
		lowest_seen = owner_seen
		lowest_at = at
	return lowest

/**
 * Indexes a placement the registry has just taken: its info, and its place among its account's placements and art.
 *
 * Arguments:
 * - packed: The placement.
 * - placement: It unpacked.
 */
/datum/controller/subsystem/graffiti/proc/index_placement(packed, list/placement)
	var/ckey = placement["ckey"]
	var/at = placement["at"]
	var/hash = placement["art"]
	placement_info[packed] = list(ckey, hash, at, placement["pid"], placement["who"], placement["round_only"] ? TRUE : FALSE)
	var/list/mine = ckey_placements[ckey]
	if(!mine)
		mine = list()
		ckey_placements[ckey] = mine
	// A new placement is the account's newest, so it goes last, and never before another of the same time.
	var/spot = length(mine) + 1
	for(var/position in length(mine) to 1 step -1)
		if(sorttext(placement_info[mine[position]][GRAFFITI_INFO_AT], at) != -1)
			break
		spot = position
	mine.Insert(spot, packed)
	var/list/counts = ckey_arts[ckey]
	if(!counts)
		counts = list()
		ckey_arts[ckey] = counts
	counts[hash] += 1
	admin_changed()

/**
 * Moves a placement's index to its new packing, keeping its place among its account's placements.
 *
 * Arguments:
 * - packed: Its old packing.
 * - replacement: Its new packing.
 * - placement: It unpacked, with its art now.
 */
/datum/controller/subsystem/graffiti/proc/reindex_placement(packed, replacement, list/placement)
	var/list/info = placement_info[packed]
	var/ckey = info[GRAFFITI_INFO_CKEY]
	var/old_hash = info[GRAFFITI_INFO_ART]
	var/hash = placement["art"]
	placement_info -= packed
	placement_info[replacement] = list(ckey, hash, info[GRAFFITI_INFO_AT], info[GRAFFITI_INFO_PID], info[GRAFFITI_INFO_WHO], info[GRAFFITI_INFO_ROUND_ONLY])
	var/list/mine = ckey_placements[ckey]
	mine[mine.Find(packed)] = replacement
	if(hash != old_hash)
		var/list/counts = ckey_arts[ckey]
		counts[old_hash] -= 1
		if(counts[old_hash] <= 0)
			counts -= old_hash
		counts[hash] += 1
	// The orders hold the old packing, but where it shows is the same.
	if(length(admin_orders))
		admin_orders = list()
	var/area_type = admin_areas[packed]
	if(!isnull(area_type))
		admin_areas -= packed
		admin_areas[replacement] = area_type

/**
 * Takes a placement the registry no longer holds out of the index.
 *
 * Arguments:
 * - packed: The placement.
 */
/datum/controller/subsystem/graffiti/proc/unindex_placement(packed)
	var/list/info = placement_info[packed]
	placement_info -= packed
	var/ckey = info[GRAFFITI_INFO_CKEY]
	var/list/mine = ckey_placements[ckey]
	mine -= packed
	if(!length(mine))
		ckey_placements -= ckey
	var/list/counts = ckey_arts[ckey]
	var/hash = info[GRAFFITI_INFO_ART]
	counts[hash] -= 1
	if(counts[hash] <= 0)
		counts -= hash
	if(!length(counts))
		ckey_arts -= ckey
	admin_changed()

/**
 * Returns a placement's art hash without unpacking it.
 *
 * Arguments:
 * - packed: A placement the registry holds.
 *
 * Returns:
 * - text: The hash.
 */
/datum/controller/subsystem/graffiti/proc/art_of(packed)
	return placement_info[packed][GRAFFITI_INFO_ART]

/**
 * Keeps a decode of an art or stack composite for the rest of the map's load, while the decodes kept stay within
 * GRAFFITI_DECODE_BUDGET. Past it, that art is decoded again wherever it is needed, as it is outside the load.
 *
 * Arguments:
 * - hash: The art's hash.
 * - record: Its graffiti_art_decode().
 * - art: The art.
 */
/datum/controller/subsystem/graffiti/proc/keep_decoded(hash, list/record, list/art)
	if(!decoded || decoded[hash])
		return
	var/list/unlit = graffiti_unlit_glow(art["w"])
	// Art that glows nowhere shares one glow list.
	if(art["glow"] == unlit[1])
		record[3] = unlit[2]
	var/size = decoded_size(record)
	if(total_size + size > GRAFFITI_DECODE_BUDGET)
		return
	decoded[hash] = record
	total_size += size

/**
 * Lets the load's decodes go but those it still needs, counting what stays.
 *
 * Arguments:
 * - keep: Art hash -> TRUE for the decodes to keep.
 */
/datum/controller/subsystem/graffiti/proc/keep_only_decoded(list/keep)
	if(!decoded)
		return
	var/list/kept = list()
	total_size = 0
	for(var/hash, record in decoded)
		if(keep[hash])
			kept[hash] = record
			total_size += decoded_size(record)
	decoded = kept

/**
 * Estimates the bytes a decode holds: 8 a pixel for its indices, and for its glow unless it shares
 * graffiti_unlit_glow()'s, and 40 a palette colour.
 *
 * Arguments:
 * - record: A graffiti_art_decode().
 *
 * Returns:
 * - number: The bytes.
 */
/datum/controller/subsystem/graffiti/proc/decoded_size(list/record)
	var/list/indices = record[2]
	var/list/glow = record[3]
	var/list/unlit = graffiti_unlit_glow(length(indices) / GRAFFITI_HEIGHT)
	return 8 * (length(indices) + (glow == unlit[2] ? 0 : length(glow))) + 40 * length(record[1])

/**
 * Lets the map load's decodes go: build_sheets() does once every sheet is drawn, and load_file()'s timer does should a
 * runtime stop the load first.
 */
/datum/controller/subsystem/graffiti/proc/drop_decoded()
	decoded = null
	stack_cache = null
	total_size = 0

/**
 * Shows each placement whose anchor resolves, best-ranked first while the display budget lasts, stacked on its tile in
 * file order. The rest stay dormant: one that doesn't resolve counts a miss unless it is only waiting, and is dropped
 * once it has missed GRAFFITI_MISS_LIMIT rounds in a row. The decals get their icons from build_sheets().
 */
/datum/controller/subsystem/graffiti/proc/place_all()
	// Packed placement -> the turf it shows on.
	var/list/targets = list()
	// Packed placement -> its new packing, or "" when it is dropped.
	var/list/changed = list()
	var/dropped = 0
	for(var/packed in rank(placements))
		load_yield()
		// Let go of while this waited for a tick.
		if(!placement_info[packed])
			continue
		var/list/placement = unpack(packed)
		var/list/anchor = placement["anchor"]
		var/turf/tile = graffiti_anchor_resolve(anchor)
		if(!tile)
			if(graffiti_anchor_waits(anchor))
				dormant += packed
				continue
			placement["miss"] += 1
			if(placement["miss"] >= GRAFFITI_MISS_LIMIT)
				changed[packed] = ""
				release_art(placement["art"])
				dropped++
				continue
			changed[packed] = json_encode(placement)
			dormant += changed[packed]
			continue
		if(placement["miss"])
			placement["miss"] = 0
			changed[packed] = json_encode(placement)
			packed = changed[packed]
		var/hash = placement["art"]
		if(length(displayed_unique) >= display_budget && !displayed_unique[hash])
			dormant += packed
			continue
		count_shown(hash, 1)
		targets[packed] = tile
	if(length(changed))
		var/list/updated = list()
		for(var/packed in placements)
			var/replacement = changed[packed]
			if(isnull(replacement))
				updated += packed
			else if(replacement)
				updated += replacement
				reindex_placement(packed, replacement, unpack(replacement))
			else
				unindex_placement(packed)
		placements = updated
		queue_save()
	if(dropped)
		log_game("Dropped [dropped] graffiti placement\s from [map_path] whose surfaces were missing for [GRAFFITI_MISS_LIMIT] rounds.")
	// Decodes of art nothing shows go, leaving room for the stacks' composites.
	if(decoded)
		var/list/showing = list()
		for(var/packed in targets)
			if(placement_info[packed])
				showing[art_of(packed)] = TRUE
		keep_only_decoded(showing)
	var/list/found = list()
	for(var/packed in placements)
		load_yield()
		var/turf/tile = targets[packed]
		// Let go of while this waited for a tick.
		if(!tile || !placement_info[packed])
			continue
		var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(tile, TRUE)
		if(!decal)
			var/list/placement = unpack(packed)
			count_shown(placement["art"], -1)
			dormant += packed
			continue
		shown[packed] = decal
		decal.add_placement(packed, TRUE)
		found[decal] = TRUE
	for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in found)
		load_yield()
		if(QDELETED(decal))
			continue
		// A stack of several the map file cached is shown without merging it.
		var/list/cached = length(decal.stack) > 1 ? stack_cache?[decal.stack_signature()] : null
		if(!cached || !decal.adopt_stack(cached))
			decal.refresh(TRUE, TRUE)
	stack_cache = null
	// Only what the sheets draw stays decoded: each shown stack's art or composite.
	if(decoded)
		var/list/drawn = list()
		for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in found)
			if(!QDELETED(decal) && decal.stack_key)
				drawn[decal.stack_key] = TRUE
		keep_only_decoded(drawn)

/**
 * Shows a placement on top of its tile's stack.
 *
 * Arguments:
 * - packed: The placement.
 * - tile: Its turf.
 *
 * Returns:
 * - TRUE/FALSE: Whether it shows. It doesn't when no decal can be made there.
 */
/datum/controller/subsystem/graffiti/proc/display(packed, turf/tile)
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(tile, TRUE)
	if(!decal)
		return FALSE
	count_shown(art_of(packed), 1)
	shown[packed] = decal
	admin_changed()
	decal.add_placement(packed)
	return TRUE

/**
 * Counts placements of an art in or out of those shown.
 *
 * Arguments:
 * - hash: The art's hash.
 * - change: How many more are shown, below 0 for fewer.
 */
/datum/controller/subsystem/graffiti/proc/count_shown(hash, change)
	displayed_unique[hash] += change
	if(displayed_unique[hash] <= 0)
		displayed_unique -= hash

/**
 * Drops one placement's hold on an art, and the art once nothing uses it, its icon and glow mask leaving the caches.
 *
 * Arguments:
 * - hash: The art's hash.
 */
/datum/controller/subsystem/graffiti/proc/release_art(hash)
	art_refs[hash] -= 1
	if(art_refs[hash] <= 0)
		art_refs -= hash
		art_bytes -= art_size(art[hash])
		art -= hash
		art_icons -= hash
		glow_icons -= hash

/**
 * Returns the bytes an art counts against the map's art_byte_budget: its palette and grids.
 *
 * Arguments:
 * - art: The art.
 *
 * Returns:
 * - number: The bytes.
 */
/datum/controller/subsystem/graffiti/proc/art_size(list/art)
	return length(art?["pal"]) + length(art?["grid"]) + length(art?["glow"])

/**
 * Returns the account's own placements that its caps take for a new placement of an art: its oldest, while it keeps
 * GRAFFITI_CKEY_PLACEMENT_CAP placements, or GRAFFITI_CKEY_UNIQUE_CAP arts and the art is new to it. Nothing is
 * removed.
 *
 * Arguments:
 * - ckey: The account's ckey.
 * - hash: The art's hash.
 *
 * Returns:
 * - list: The packed placements, oldest first, which is how the account's index orders them.
 */
/datum/controller/subsystem/graffiti/proc/own_evictions(ckey, hash)
	. = list()
	var/list/counts = ckey_arts[ckey]
	var/count = length(ckey_placements[ckey])
	var/arts = length(counts)
	// Art hash -> how many of the placements taken use it.
	var/list/taken = list()
	for(var/packed in ckey_placements[ckey])
		if(count < GRAFFITI_CKEY_PLACEMENT_CAP && (counts[hash] > taken[hash] || arts < GRAFFITI_CKEY_UNIQUE_CAP))
			break
		. += packed
		count--
		var/old_hash = placement_info[packed][GRAFFITI_INFO_ART]
		taken[old_hash] += 1
		if(taken[old_hash] == counts[old_hash])
			arts--

/**
 * Whether the map's caps, its art_byte_budget included, leave room for a new placement of an art once the placements
 * the account's own caps take are gone.
 *
 * Arguments:
 * - hash: The art's hash.
 * - size: The art's art_size().
 * - doomed: The placements own_evictions() takes.
 *
 * Returns:
 * - TRUE/FALSE
 */
/datum/controller/subsystem/graffiti/proc/map_fits(hash, size, list/doomed)
	if(length(placements) - length(doomed) >= placement_cap)
		return FALSE
	// Art the map keeps takes no more room, even when only doomed placements use it: the new one takes it over.
	if(art[hash])
		return TRUE
	var/arts = length(art)
	var/bytes = art_bytes
	// Art hash -> how many of the doomed placements use it.
	var/list/taken = list()
	for(var/packed in doomed)
		var/old_hash = placement_info[packed][GRAFFITI_INFO_ART]
		taken[old_hash] += 1
		if(taken[old_hash] == art_refs[old_hash])
			arts--
			bytes -= art_size(art[old_hash])
	return arts < GRAFFITI_MAP_UNIQUE_CAP && bytes + size <= art_byte_budget

/**
 * Places a piece's art on a turf, on top of its stack, and queues the map file's write.
 *
 * The map's caps are met first, counting the account's own placements that its caps take: past them the lowest-ranked
 * placement of an owner who isn't connected goes, and when nothing else can go the new paint is refused with the
 * account's own placements left alone. Only a placement that lands takes the account's own lowest-ranked ones, as many
 * as its caps need. Off the station levels, in shuttles and in the holodeck, the placement lasts this round only.
 *
 * Arguments:
 * - tile: The wall, floor or window tile.
 * - art: The art, GRAFFITI_WIDTH wide. The registry keeps a copy.
 * - ckey: The painter's ckey.
 * - who: The painter's character name.
 * - pid: The placement's id. The two halves of a wide piece share one; null makes a new one.
 * - half: 1 or 2 for the left or right half of a wide piece, else 0.
 * - evicted: When given, filled with the ids of the account's own placements its caps took, for the painter to be told
 *   how many went.
 *
 * Returns:
 * - text: The packed placement, which is in `placements`.
 * - text: Why it wasn't placed, safe to show the player. It is never in `placements`.
 */
/datum/controller/subsystem/graffiti/proc/add_placement(turf/tile, list/art, ckey, who, pid = null, half = 0, list/evicted = null)
	if(!loaded)
		return "the station's graffiti is still loading"
	if(!graffiti_surface_ok(tile) || art?["w"] != GRAFFITI_WIDTH)
		return "can't paint there"
	var/hash = graffiti_art_hash(art)
	var/size = art_size(art)
	var/list/doomed = own_evictions(ckey, hash)
	var/fits = map_fits(hash, size, doomed)
	for(var/attempt in 1 to length(placements))
		if(fits)
			break
		var/lowest = lowest_unconnected()
		if(!lowest)
			break
		remove_placement(lowest, FALSE)
		// The lowest may have been the account's own, as when its owner left mid-job.
		doomed = own_evictions(ckey, hash)
		fits = map_fits(hash, size, doomed)
	if(!fits)
		queue_save()
		return "the walls here are caked in paint"
	for(var/packed in doomed)
		evicted?.Add(placement_info[packed][GRAFFITI_INFO_PID])
		remove_placement(packed, FALSE)
	var/list/anchor = graffiti_anchor_for(tile)
	var/now = graffiti_unix_time()
	if(!pid)
		// A pid only meets its own account's, which begin with the same ckey.
		var/list/pids = list()
		for(var/packed in ckey_placements[ckey])
			pids[placement_info[packed][GRAFFITI_INFO_PID]] = TRUE
		for(var/attempt in 1 to 10)
			pid = "[ckey]-[now]-[rand(1000, 9999)]"
			if(!pids[pid])
				break
			pid = null
	var/list/placement = list("anchor" = anchor, "art" = hash, "ckey" = ckey, "who" = graffiti_clean_text(who, MAX_NAME_LEN), "at" = now, "pid" = pid || "[ckey]-[now]-[rand(1000, 9999)]", "half" = (half in list(1, 2)) ? half : 0, "miss" = 0)
	if(!anchor)
		placement["round_only"] = TRUE
		placement["x"] = tile.x
		placement["y"] = tile.y
		placement["z"] = tile.z
	if(!src.art[hash])
		src.art[hash] = list("w" = art["w"], "pal" = art["pal"], "grid" = art["grid"], "glow" = art["glow"], "k" = graffiti_art_glow_kind(art))
		art_bytes += art_size(art)
	art_refs[hash] += 1
	var/packed = json_encode(placement)
	placements += packed
	index_placement(packed, placement)
	if(!display(packed, tile))
		dormant += packed
	queue_save()
	return packed

/**
 * Gives a placement new art, as a freehand session or a paint job reveals more of its piece, and shows it.
 *
 * Arguments:
 * - packed: The placement.
 * - art: Its new art, GRAFFITI_WIDTH wide. The registry keeps a copy.
 * - decoded: The art's graffiti_art_decode(), when the caller has it, so its tile doesn't decode it again.
 *
 * Returns:
 * - text: The placement packed again, which takes the old packing's place everywhere, or as it was when its art is
 *   unchanged. Keep it for the next update.
 * - null: The placement is gone.
 */
/datum/controller/subsystem/graffiti/proc/update_placement_art(packed, list/art, list/decoded = null)
	var/position = placements.Find(packed)
	if(!position || art?["w"] != GRAFFITI_WIDTH)
		return null
	var/list/placement = unpack(packed)
	var/old_hash = placement["art"]
	var/hash = graffiti_art_hash(art)
	if(hash == old_hash)
		return packed
	if(!src.art[hash])
		src.art[hash] = list("w" = art["w"], "pal" = art["pal"], "grid" = art["grid"], "glow" = art["glow"], "k" = graffiti_art_glow_kind(art, decoded))
		art_bytes += art_size(art)
	art_refs[hash] += 1
	placement["art"] = hash
	var/replacement = json_encode(placement)
	placements[position] = replacement
	reindex_placement(packed, replacement, placement)
	var/sleeping = dormant.Find(packed)
	if(sleeping)
		dormant[sleeping] = replacement
	var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
	if(decal)
		shown -= packed
		shown[replacement] = decal
		count_shown(old_hash, -1)
		count_shown(hash, 1)
		var/spot = decal.stack.Find(packed)
		if(spot)
			decal.stack[spot] = replacement
			decal.refresh(spot < length(decal.stack), FALSE, spot == length(decal.stack) ? decoded : null)
	release_art(old_hash)
	queue_save()
	return replacement

/**
 * Removes a placement from the registry, and from its tile when it shows.
 *
 * Arguments:
 * - packed: The placement.
 * - save: Whether to queue the map file's write.
 * - deferred: Whether to leave its tile's merge for the caller, which refreshes the tile once it has removed everything.
 *
 * Returns:
 * - TRUE/FALSE: Whether the registry held it.
 */
/datum/controller/subsystem/graffiti/proc/remove_placement(packed, save = TRUE, deferred = FALSE)
	if(!(packed in placements))
		return FALSE
	placements -= packed
	dormant -= packed
	var/hash = art_of(packed)
	unindex_placement(packed)
	var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
	if(decal)
		shown -= packed
		count_shown(hash, -1)
		decal.remove_placement(packed, deferred)
	release_art(hash)
	if(save)
		queue_save()
	return TRUE

/**
 * Removes placements from the registry at once, as an admin deletes them, ends the painting under way on them
 * (drop_work()), then merges each tile they showed on again once, yielding between tiles: removing them one by one
 * would merge a tile's whole stack for each. What else a tile stacks stays, in its order.
 *
 * Arguments:
 * - doomed: The packed placements.
 *
 * Returns:
 * - number: How many of them the registry held.
 */
/datum/controller/subsystem/graffiti/proc/remove_placements(list/doomed)
	. = 0
	var/list/tiles = list()
	var/list/owners = pids_by_ckey(doomed)
	for(var/packed in doomed)
		var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
		if(!remove_placement(packed, FALSE, TRUE))
			continue
		.++
		if(decal)
			tiles[decal] = TRUE
	if(.)
		queue_save()
	drop_work(owners)
	for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in tiles)
		CHECK_TICK
		// A tile left with nothing goes.
		if(!QDELETED(decal))
			decal.refresh(TRUE)
			decal.release_merges()

/**
 * Returns the placement ids each account owns among some placements, read while the index still holds them.
 *
 * Arguments:
 * - packed_list: The packed placements.
 *
 * Returns:
 * - list: Ckey -> pid -> TRUE.
 */
/datum/controller/subsystem/graffiti/proc/pids_by_ckey(list/packed_list)
	var/list/owners = list()
	for(var/packed in packed_list)
		var/list/info = placement_info[packed]
		if(!info)
			continue
		var/ckey = info[GRAFFITI_INFO_CKEY]
		if(!owners[ckey])
			owners[ckey] = list()
		owners[ckey][info[GRAFFITI_INFO_PID]] = TRUE
	return owners

/**
 * Ends what painters have under way on placements an admin deleted, keeping none of it: a freehand session or paint job
 * painting them stops without an Unfinished piece, and an Unfinished piece left to resume on them is discarded, an
 * offline owner's too, whose library is loaded for it and unloaded again. Yields between offline owners' libraries.
 *
 * Arguments:
 * - owners: pids_by_ckey() of the deleted placements.
 */
/datum/controller/subsystem/graffiti/proc/drop_work(list/owners)
	// Painting stops before anything yields, so nothing it leaves meanwhile can name the deleted paint.
	for(var/ckey, value in owners)
		var/list/pids = value
		var/datum/custom_sprite_editor/graffiti/editor = editors[ckey]
		var/packed = editor?.placement || editor?.placement2
		if(packed && pids[unpack(packed)["pid"]])
			editor.end_session(get_mob_by_ckey(ckey), FALSE)
		var/datum/graffiti_paint_job/job = paint_jobs[ckey]
		packed = job?.placement || job?.placement2
		if(packed && pids[unpack(packed)["pid"]])
			job.interrupt(FALSE)
	for(var/ckey, value in owners)
		var/list/pids = value
		var/datum/graffiti_library/library = libraries[ckey]
		if(!library)
			var/path = graffiti_library_path(ckey)
			if(!path || !(fexists(path) || fexists("[path].bak")))
				continue
			CHECK_TICK
			library = graffiti_library(ckey)
		var/list/resume = library.unfinished?["resume"]
		if(resume?["map"] == SSmapping.current_map.map_name && istext(resume["pid"]) && pids[resume["pid"]])
			library.discard_unfinished(TRUE)
		if(!GLOB.directory[ckey])
			graffiti_library_unload(ckey)

/**
 * Removes for good every placement a decal showed: its surface was cleaned, or is gone.
 *
 * Arguments:
 * - decal: The decal, being deleted.
 */
/datum/controller/subsystem/graffiti/proc/tile_gone(obj/effect/decal/cleanable/crayon/custom/decal)
	var/list/gone = decal.stack
	// Emptied first, so removing each one leaves the deleting decal alone.
	decal.stack = list()
	for(var/packed in gone)
		remove_placement(packed)

/**
 * Takes the placements of one space's anchors off their tiles and keeps them dormant, for graffiti_registry_release().
 *
 * Arguments:
 * - kind: The anchor kind.
 * - key: The anchors' `owner`.
 */
/datum/controller/subsystem/graffiti/proc/release(kind, key)
	for(var/packed in shown.Copy())
		var/list/placement = unpack(packed)
		var/list/anchor = placement["anchor"]
		if(anchor?["kind"] != kind || anchor["owner"] != key)
			continue
		var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
		shown -= packed
		count_shown(placement["art"], -1)
		admin_changed()
		decal.remove_placement(packed)
		dormant += packed

/**
 * Returns the turf a placement's anchor names this round, for admin jumps and anchor checks. A shown placement's decal
 * is in `shown`, which follows it even when its anchor no longer resolves to it.
 *
 * Arguments:
 * - placement: The unpacked placement.
 *
 * Returns:
 * - turf: The turf.
 * - null: Its anchor doesn't resolve.
 */
/datum/controller/subsystem/graffiti/proc/placement_turf(list/placement)
	if(placement?["round_only"])
		return locate(placement["x"], placement["y"], placement["z"])
	return graffiti_anchor_resolve(placement?["anchor"])

/**
 * Writes the map file after GRAFFITI_SAVE_DEBOUNCE, with every change made meanwhile.
 */
/datum/controller/subsystem/graffiti/proc/queue_save()
	if(frozen || save_pending)
		return
	save_pending = addtimer(CALLBACK(src, PROC_REF(save_now)), GRAFFITI_SAVE_DEBOUNCE, TIMER_STOPPABLE)

/**
 * Writes the map file: the art and placements that last past this round, and when their owners were last seen. A map
 * that has never had lasting graffiti gets no file. Nothing is written before the map's graffiti has loaded (`loaded`),
 * while the registry may hold only part of the file, nor after the round-end save.
 *
 * The file is joined from text, as json_encode() would write the same tree: each placement is kept packed already, and
 * each art record is encoded as it is joined, so the registry holds no second copy of its art between saves.
 *
 * Arguments:
 * - final: Whether this is the round-end save.
 */
/datum/controller/subsystem/graffiti/proc/save_now(final = FALSE)
	deltimer(save_pending)
	save_pending = null
	if(frozen || !store || !loaded)
		return
	if(final)
		frozen = TRUE
	var/list/kept = list()
	// Art hash -> TRUE for the art the kept placements use, in the order they first use it.
	var/list/used = list()
	var/list/owners = list()
	for(var/packed in placements)
		var/list/info = placement_info[packed]
		var/hash = info[GRAFFITI_INFO_ART]
		// Art with no paint yet, such as a paint job's first step, has nothing to keep.
		if(info[GRAFFITI_INFO_ROUND_ONLY] || !length(art[hash]?["pal"]))
			continue
		kept += packed
		used[hash] = TRUE
		owners[info[GRAFFITI_INFO_CKEY]] = TRUE
	var/list/times = list()
	for(var/ckey, time in seen)
		if(owners[ckey])
			times[ckey] = time
	if(!store.path || isnull(store.last_good_json) || (!length(kept) && !fexists(store.path) && !fexists("[store.path].bak")))
		return
	var/list/records = list()
	for(var/hash in used)
		records += "[json_encode(hash)]:[json_encode(art[hash])]"
	// As json_encode() writes them, no art is an empty array rather than an empty object.
	var/art_json = length(records) ? "{[jointext(records, ",")]}" : "\[]"
	var/text = "{\"version\":[GRAFFITI_MAP_VERSION],\"art\":[art_json],\"placements\":\[[jointext(kept, ",")]],\"seen\":[json_encode(times)],\"stacks\":[json_encode(stack_keys(kept))]}"
	if(!store.write_text(text))
		log_game("The graffiti file [store.path] couldn't be written.")
		if(!save_failure_told)
			save_failure_told = TRUE
			message_admins("The graffiti file [store.path] couldn't be written, so this map's graffiti changes won't last past the round unless a later save succeeds. The game log has each failure.")

/**
 * Returns what the map file caches of the stacks it keeps, so the next round's load shows them without merging them:
 * each shown stack of several pieces, every piece of it kept, under its signature with its key and glow kind, beside
 * the fingerprint of the merges that made them (graffiti_merge_fingerprint()).
 *
 * Arguments:
 * - kept: The packed placements the file keeps.
 *
 * Returns:
 * - list: list("print" = the fingerprint, "keys" = stack signature -> list(stack key, glow kind)).
 */
/datum/controller/subsystem/graffiti/proc/stack_keys(list/kept)
	var/list/keeping = list()
	for(var/packed in kept)
		keeping[packed] = TRUE
	var/list/keys = list()
	var/list/done = list()
	for(var/packed, value in shown)
		var/obj/effect/decal/cleanable/crayon/custom/decal = value
		if(done[decal] || length(decal.stack) < 2 || !decal.stack_key || isnull(decal.render_cache?["kind"]))
			continue
		done[decal] = TRUE
		var/whole = TRUE
		for(var/piece in decal.stack)
			if(!keeping[piece])
				whole = FALSE
				break
		if(whole)
			keys[decal.stack_signature()] = list(decal.stack_key, decal.render_cache["kind"])
	return list("print" = graffiti_merge_fingerprint(), "keys" = keys)

/**
 * Notes when a player connected, and shows those of their dormant placements whose anchors resolve now, within the
 * display budget.
 *
 * Arguments:
 * - source: SSdcs.
 * - player: The client.
 */
/datum/controller/subsystem/graffiti/proc/on_client_connect(datum/source, client/player)
	SIGNAL_HANDLER
	var/ckey = player.ckey
	seen[ckey] = graffiti_unix_time()
	// The file keeps owners' times only.
	if(!ckey_placements[ckey])
		return
	var/list/tiles = list()
	for(var/packed in dormant.Copy())
		if(placement_info[packed][GRAFFITI_INFO_CKEY] != ckey)
			continue
		var/list/placement = unpack(packed)
		var/turf/tile = graffiti_anchor_resolve(placement["anchor"])
		if(!tile || (length(displayed_unique) >= display_budget && !displayed_unique[placement["art"]]))
			continue
		dormant -= packed
		if(!display(packed, tile))
			dormant += packed
			continue
		tiles[shown[packed]] = TRUE
	// Released once all are up, as each placement on a tile merges over the merge of the ones put up before it.
	for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in tiles)
		decal.release_merges()
	queue_save()

/**
 * Returns the sheet a stack shows from.
 *
 * Arguments:
 * - stack_key: The stack's key.
 *
 * Returns:
 * - list: list(the sheet file's resource, whether it holds the stack's glow mask as "[stack_key]_g").
 * - null: No sheet holds the stack, such as one changed this round.
 */
/datum/controller/subsystem/graffiti/proc/sheet_for(stack_key)
	return stack_key ? sheets[stack_key] : null

/**
 * Packs every shown stack into sprite sheet files, chunk by chunk, and shows each decal from its sheet.
 *
 * Decals are sorted by z level, 16-tile chunk and position, and each chunk's stacks are cut into sheets of up to
 * GRAFFITI_SHEET_STATES, each stack in one sheet only. A sheet file is named by the hash of the stacks it holds and the
 * alpha ceiling they are drawn at, so an unchanged chunk reuses the file of an earlier round, which clients have cached.
 * Files no sheet uses are deleted, unless the map's graffiti isn't kept.
 */
/datum/controller/subsystem/graffiti/proc/build_sheets()
	sheets = list()
	sheets_built = 0
	var/map_name = SSmapping.current_map.map_name
	var/list/order = list()
	for(var/packed, value in shown)
		var/obj/effect/decal/cleanable/crayon/custom/decal = value
		if(!order[decal])
			order[decal] = "[decal.z + 1000][round(decal.y / 16) + 1000][round(decal.x / 16) + 1000][decal.y + 1000][decal.x + 1000]"
	sortTim(order, GLOBAL_PROC_REF(cmp_text_asc), associative = TRUE)
	var/list/used = list()
	var/list/pack = list()
	var/chunk
	for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in order)
		load_yield()
		var/key = copytext(order[decal], 1, 13)
		if(key != chunk)
			write_sheet(pack, map_name, used)
			pack = list()
			chunk = key
		if(QDELETED(decal) || !decal.stack_key || sheets[decal.stack_key] || pack[decal.stack_key])
			continue
		pack[decal.stack_key] = decal
		if(length(pack) == GRAFFITI_SHEET_STATES)
			write_sheet(pack, map_name, used)
			pack = list()
	write_sheet(pack, map_name, used)
	// Every sheet is drawn, so the load's decoded art goes.
	drop_decoded()
	var/directory = "[sheet_root][graffiti_file_key(map_name)]/"
	// A map whose graffiti isn't kept, as a custom map's, may share its name's directory with another map's sheets.
	if(store?.path)
		for(var/file_name in flist(directory))
			if(!used[file_name] && copytext(file_name, -1) != "/")
				fdel("[directory][file_name]")
	for(var/obj/effect/decal/cleanable/crayon/custom/decal as anything in order)
		load_yield()
		decal.apply_icon()
		// Shown now, from its sheet or an icon of its own: its merges come again for whoever paints there next.
		decal.release_merges()

/**
 * Points a pack of stacks at their sheet file, writing it first unless an earlier round wrote the same one.
 *
 * Arguments:
 * - pack: Stack key -> the first decal showing it, in sheet order.
 * - map_name: The map's name, which its sheet directory is named for.
 * - used: Sheet file name -> TRUE for the files kept, which this adds to.
 */
/datum/controller/subsystem/graffiti/proc/write_sheet(list/pack, map_name, list/used)
	if(!length(pack))
		return
	var/list/keys = list()
	for(var/stack_key in pack)
		keys += stack_key
	// The ceiling the sheet is drawn at names it too, so a sheet drawn at another is drawn again.
	var/hash = md5("[GRAFFITI_ALPHA_CEILING]|[jointext(keys, "|")]")
	var/path = graffiti_sheet_path(map_name, hash, sheet_root)
	if(!fexists(path))
		var/icon/sheet = graffiti_new_sheet(GRAFFITI_WIDTH)
		for(var/stack_key, value in pack)
			load_yield()
			var/obj/effect/decal/cleanable/crayon/custom/decal = value
			// Deleted or changed while the sheet waited for a tick: the sheet is left unwritten, as a file named for a
			// stack it lacks would be reused by a later round that shows that stack, and its decals draw their own icons.
			if(QDELETED(decal) || decal.stack_key != stack_key)
				return
			var/list/merged = decal.stack_merge()
			// Decoded once for both of its states when the load kept no decode of it.
			var/list/record = decoded?[stack_key] || graffiti_art_decode(merged)
			// Drawn for the sheet alone and let go once in: a sheet holding icons that stay alive elsewhere refuses more.
			graffiti_sheet_add(sheet, graffiti_art_icon(merged, stack_key, FALSE, record), stack_key)
			if(decal.render_cache["kind"] == GRAFFITI_GLOW_MIXED)
				graffiti_sheet_add(sheet, graffiti_glow_icon(merged, stack_key, FALSE, record), "[stack_key]_g")
		fcopy(sheet, path)
		if(!fexists(path))
			return
		sheets_built++
	used["[hash].dmi"] = TRUE
	var/resource = fcopy_rsc(file(path))
	for(var/stack_key, value in pack)
		var/obj/effect/decal/cleanable/crayon/custom/decal = value
		// One deleted or changed since it was packed shows from an icon of its own.
		if(QDELETED(decal) || decal.stack_key != stack_key)
			continue
		sheets[stack_key] = list(resource, decal.render_cache["kind"] == GRAFFITI_GLOW_MIXED)

/**
 * Returns one page of the map's placements, shown and dormant alike, for the admin panel.
 *
 * Arguments:
 * - search: Text to find in a placement's ckey or its painter's character name, ignoring case, or null for every
 *   placement.
 * - sort: "date" for the newest first, "ckey" or "area".
 * - page: The page, from 1, of GRAFFITI_ADMIN_PAGE rows.
 *
 * Returns:
 * - list: "rows", each list("pid", "ckey", "who", "area", "x", "y", "z", "at", "state", "art") with "state" "shown",
 *   "dormant" or "round_only" and "art" the flat art for its thumbnail; and "total", the number of rows that match
 *   `search` on every page.
 */
/datum/controller/subsystem/graffiti/proc/admin_rows(search, sort, page)
	if(sort != "ckey" && sort != "area")
		sort = "date"
	var/list/matched = admin_order(sort)
	if(length(search))
		var/list/every = matched
		matched = list()
		for(var/packed in every)
			var/list/info = placement_info[packed]
			if(findtext(info[GRAFFITI_INFO_CKEY], search) || findtext(info[GRAFFITI_INFO_WHO], search))
				matched += packed
	var/total = length(matched)
	page = clamp(isnum(page) ? round(page) : 1, 1, max(1, CEILING(total / GRAFFITI_ADMIN_PAGE, 1)))
	var/list/rows = list()
	for(var/position in (page - 1) * GRAFFITI_ADMIN_PAGE + 1 to min(page * GRAFFITI_ADMIN_PAGE, total))
		rows += list(admin_row(matched[position]))
	return list("rows" = rows, "total" = total)

/**
 * Returns every placement in one of admin_rows()' orders, sorting them again only after the placements changed.
 *
 * Arguments:
 * - sort: "date" for the newest first, "ckey" or "area".
 *
 * Returns:
 * - list: The packed placements, which admin_orders keeps. Never change it.
 */
/datum/controller/subsystem/graffiti/proc/admin_order(sort)
	var/list/order = admin_orders[sort]
	if(order)
		return order
	// Sort key -> packed placement. Ties go by place in the file. A space sorts before anything a ckey or area path holds.
	var/list/keyed = list()
	for(var/position in 1 to length(placements))
		var/packed = placements[position]
		var/list/info = placement_info[packed]
		var/value = sort == "date" ? info[GRAFFITI_INFO_AT] : (sort == "ckey" ? info[GRAFFITI_INFO_CKEY] : admin_area(packed))
		keyed["[value] [position + 100000]"] = packed
	sortTim(keyed, sort == "date" ? GLOBAL_PROC_REF(cmp_text_dsc) : GLOBAL_PROC_REF(cmp_text_asc))
	order = list()
	for(var/key in keyed)
		order += keyed[key]
	admin_orders[sort] = order
	return order

/**
 * Returns the area admin_rows() lists a placement under: its tile's, or its anchor's when it has none this round.
 *
 * Arguments:
 * - packed: The placement.
 *
 * Returns:
 * - text: The area's type, or "" when neither has one.
 */
/datum/controller/subsystem/graffiti/proc/admin_area(packed)
	var/area_type = admin_areas[packed]
	if(!isnull(area_type))
		return area_type
	var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
	var/list/placement = decal ? null : unpack(packed)
	var/area/place = get_area(decal ? get_turf(decal) : placement_turf(placement))
	area_type = place ? "[place.type]" : (placement?["anchor"]?["area"] || "")
	admin_areas[packed] = area_type
	return area_type

/**
 * Returns admin_rows()' row for one placement.
 *
 * Arguments:
 * - packed: The placement.
 *
 * Returns:
 * - list: The row, as admin_rows() describes it.
 */
/datum/controller/subsystem/graffiti/proc/admin_row(packed)
	var/list/placement = unpack(packed)
	var/list/anchor = placement["anchor"]
	var/obj/effect/decal/cleanable/crayon/custom/decal = shown[packed]
	var/turf/tile = decal ? get_turf(decal) : placement_turf(placement)
	var/area/place = get_area(tile)
	return list("pid" = placement["pid"], "ckey" = placement["ckey"], "who" = placement["who"], "area" = place ? "[place.type]" : anchor?["area"], "x" = tile ? tile.x : anchor?["x"], "y" = tile ? tile.y : anchor?["y"], "z" = tile ? tile.z : graffiti_station_z(anchor?["z"]), "at" = placement["at"], "state" = placement["round_only"] ? "round_only" : (decal ? "shown" : "dormant"), "art" = art[placement["art"]])

/**
 * Forgets admin_rows()' orders and areas, as the placements or where they show changed.
 */
/datum/controller/subsystem/graffiti/proc/admin_changed()
	if(length(admin_orders))
		admin_orders = list()
	if(length(admin_areas))
		admin_areas = list()

/**
 * Deletes placements by id, both halves of a wide piece alike, through remove_placements(), which may sleep.
 *
 * Arguments:
 * - pids: The ids.
 *
 * Returns:
 * - number: How many placements were deleted.
 */
/datum/controller/subsystem/graffiti/proc/admin_delete(list/pids)
	var/list/wanted = list()
	for(var/pid in pids)
		wanted["[pid]"] = TRUE
	var/list/doomed = list()
	for(var/packed in placements)
		if(wanted[placement_info[packed][GRAFFITI_INFO_PID]])
			doomed += packed
	return remove_placements(doomed)

/**
 * Deletes one account's placements on this map through remove_placements(), which may sleep.
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - number: How many placements were deleted.
 */
/datum/controller/subsystem/graffiti/proc/admin_delete_ckey(ckey)
	var/list/mine = ckey_placements[ckey]
	return remove_placements(mine?.Copy())

/**
 * Deletes every placement on this map, and the painting under way on them (drop_work()), which may sleep.
 *
 * Returns:
 * - number: How many placements were deleted.
 */
/datum/controller/subsystem/graffiti/proc/admin_clear_map()
	. = length(placements)
	var/list/owners = pids_by_ckey(placements)
	for(var/packed, value in shown)
		var/obj/effect/decal/cleanable/crayon/custom/decal = value
		// Emptied first, so the whole stack goes without merging what is left of it.
		decal.stack = list()
		qdel(decal)
	art = list()
	art_refs = list()
	art_bytes = 0
	placements = list()
	dormant = list()
	shown = list()
	displayed_unique = list()
	placement_info = list()
	ckey_placements = list()
	ckey_arts = list()
	admin_changed()
	// No decal is left to show them.
	art_icons.Cut()
	glow_icons.Cut()
	queue_save()
	drop_work(owners)

/**
 * Edits the graffiti file of every other map, beside this map's own in the same directory, and drops the art its
 * placements no longer use, yielding between files. A file that can't be read, or has a version
 * GRAFFITI_MAP_READ_VERSIONS doesn't list, is skipped with a log line. An older version's file keeps its version, as the
 * edit only takes placements and art out.
 *
 * Arguments:
 * - edit: Called with each file's placements and art, both lists it may change.
 *
 * Returns:
 * - number: How many placements the edit took out of the files it wrote.
 */
/datum/controller/subsystem/graffiti/proc/admin_edit_other_maps(datum/callback/edit)
	. = 0
	var/directory = copytext(map_path, 1, findlasttext(map_path, "/") + 1)
	// A custom map keeps no file, so one under its name is another map's.
	var/current = store?.path ? copytext(map_path, length(directory) + 1) : null
	for(var/file_name in flist(directory))
		if(file_name == current || copytext(file_name, -5) != ".json")
			continue
		CHECK_TICK
		var/datum/json_savefile/custom_sprites/graffiti/map/other = new("[directory][file_name]")
		var/list/entries = other.get_entry("placements")
		var/list/arts = other.get_entry("art")
		if(isnull(other.last_good_json) || !(other.get_entry("version") in GRAFFITI_MAP_READ_VERSIONS) || !islist(entries) || !islist(arts))
			log_game("The graffiti file [directory][file_name] couldn't be read, so an admin's edit skipped it.")
			continue
		var/count = length(entries)
		edit.Invoke(entries, arts)
		count -= length(entries)
		var/list/used = list()
		for(var/list/placement in entries)
			if(istext(placement["art"]))
				used[placement["art"]] = TRUE
		// Art kept under anything but a hash, as in a JSON array, can't be used either.
		var/list/kept = list()
		for(var/hash, entry in arts)
			if(istext(hash) && used[hash])
				kept[hash] = entry
		other.set_entry("placements", entries)
		other.set_entry("art", kept)
		if(other.save())
			. += count
		else
			log_game("The graffiti file [directory][file_name] couldn't be written after an admin's edit.")

/**
 * Drops one account's placements from a map file's placements, for admin_edit_other_maps().
 *
 * Arguments:
 * - ckey: The account's ckey.
 * - entries: The file's placements.
 * - arts: The file's art.
 */
/datum/controller/subsystem/graffiti/proc/drop_ckey(ckey, list/entries, list/arts)
	for(var/position in length(entries) to 1 step -1)
		var/list/placement = entries[position]
		if(islist(placement) && placement["ckey"] == ckey)
			entries.Cut(position, position + 1)

/**
 * Empties a map file's placements and art, for admin_edit_other_maps().
 *
 * Arguments:
 * - entries: The file's placements.
 * - arts: The file's art.
 */
/datum/controller/subsystem/graffiti/proc/clear_file(list/entries, list/arts)
	entries.Cut()
	arts.Cut()

/**
 * Deletes one account's graffiti from every map and its graffiti library.
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - number: How many placements were deleted, on every map.
 */
/datum/controller/subsystem/graffiti/proc/admin_delete_ckey_everywhere(ckey)
	. = admin_delete_ckey(ckey) + admin_edit_other_maps(CALLBACK(src, PROC_REF(drop_ckey), ckey))
	graffiti_library_delete(ckey)

/**
 * Deletes every placement on every map.
 *
 * Returns:
 * - number: How many placements were deleted, on every map.
 */
/datum/controller/subsystem/graffiti/proc/admin_clear_all_maps()
	return admin_clear_map() + admin_edit_other_maps(CALLBACK(src, PROC_REF(clear_file)))

/**
 * Empties the registry for a test without writing anything: deletes every custom decal, clears the lists and the
 * pending write, and unfreezes it. The store and the test settings stay.
 */
/datum/controller/subsystem/graffiti/proc/wipe_for_test()
	for(var/obj/effect/decal/cleanable/crayon/custom/decal in world)
		// Emptied first, so deleting it removes nothing from the registry.
		decal.stack = list()
		qdel(decal)
	art = list()
	art_refs = list()
	art_bytes = 0
	placements = list()
	dormant = list()
	shown = list()
	seen = list()
	sheets = list()
	displayed_unique = list()
	placement_info = list()
	ckey_placements = list()
	ckey_arts = list()
	admin_changed()
	drop_decoded()
	deltimer(save_pending)
	save_pending = null
	frozen = FALSE
	sheets_built = 0
	composite_share = GRAFFITI_COMPOSITE_SHARE_BURST
	composite_share_at = world.time
	composite_line = list()

/**
 * Collects every round-end save, then makes the graffiti file's final one and writes the library changes the write
 * pacing still holds back.
 */
/datum/controller/subsystem/persistence/collect_data()
	. = ..()
	SSgraffiti.save_now(TRUE)
	graffiti_library_flush()

#undef GRAFFITI_LOAD_SHARE
#undef GRAFFITI_COMPOSITE_SHARE
#undef GRAFFITI_COMPOSITE_LINE_GRACE
#undef GRAFFITI_SAVE_DEBOUNCE
#undef GRAFFITI_SHEET_STATES
#undef GRAFFITI_CKEY_UNIQUE_CAP
#undef GRAFFITI_MAP_READ_VERSIONS
#undef GRAFFITI_DECODE_BUDGET
