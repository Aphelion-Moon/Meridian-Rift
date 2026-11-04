/// Size limit of an account's library file.
#define GRAFFITI_LIBRARY_MAX_BYTES (2 * 1024 * 1024)

/// A graffiti JSON file: the custom sprites store's verified writes, loading every top-level entry, held to `size_limit`.
/datum/json_savefile/custom_sprites/graffiti
	/// Size limit of the file in bytes, on reading and on writing, which each kind of graffiti file sets.
	var/size_limit = 0

/// An account's graffiti library file.
/datum/json_savefile/custom_sprites/graffiti/library
	size_limit = GRAFFITI_LIBRARY_MAX_BYTES

/**
 * Writes `contents` to `destination`, refusing contents the size check on loading would refuse.
 *
 * Returns:
 * - text: rust-g's error or the refusal, empty on success.
 */
/datum/json_savefile/custom_sprites/graffiti/write_file(contents, destination)
	if(length(contents) > size_limit)
		return "Larger than [size_limit] bytes."
	return ..()

/**
 * Writes text to a file, held to the size limit, and checks the file by its md5.
 *
 * Arguments:
 * - text: The text.
 * - hash: Its md5.
 * - destination: The file.
 *
 * Returns:
 * - TRUE/FALSE: Whether the file holds the text.
 */
/datum/json_savefile/custom_sprites/graffiti/proc/write_hashed(text, hash, destination)
	return !length(write_file(text, destination)) && rustg_hash_file(RUSTG_HASH_MD5, destination) == hash

/**
 * Reads one file as hostile JSON through graffiti_json_decode(), refusing one over `size_limit` with a log line.
 *
 * Returns:
 * - list("text", "data"): The file and its decoded JSON.
 * - null: The file is missing, too large, unreadable or not a JSON object.
 */
/datum/json_savefile/custom_sprites/graffiti/read_snapshot(snapshot_path)
	if(!snapshot_path || !fexists(snapshot_path))
		return null
	if(length(file(snapshot_path)) > size_limit)
		log_game("The graffiti file [snapshot_path] is larger than [size_limit] bytes and wasn't loaded.")
		return null
	var/contents = rustg_file_read(snapshot_path)
	var/list/decoded = graffiti_json_decode(contents, size_limit)
	return islist(decoded) ? list("text" = contents, "data" = decoded) : null

/**
 * Copies every top-level entry, where the parent copies only character slots.
 *
 * Arguments:
 * - decoded: The file's decoded JSON.
 */
/datum/json_savefile/custom_sprites/graffiti/load_entries(list/decoded)
	for(var/key, value in decoded)
		if(istext(key))
			set_entry(key, value)

/**
 * Loads the file as the parent does, then keeps only the md5 of the text it verified, not the text itself, which
 * save() reads back from disk. A file loaded from its backup waits for a write as one whose last write failed does,
 * since its primary doesn't hold the revision.
 *
 * Returns:
 * - TRUE/FALSE: Whether a file was loaded.
 */
/datum/json_savefile/custom_sprites/graffiti/load()
	. = ..()
	// The parent leaves a file loaded from its backup dirty.
	if(. && dirty)
		last_save_failed = TRUE
	if(last_good_json && last_good_json != "\[]")
		last_good_json = md5(last_good_json)

/**
 * Saves as the parent does, then writes the revision it verified over the backup too, so that once a save is written
 * no file keeps what it dropped. The parent makes the backup hold the last revision before it writes the primary, so an
 * interrupted write still recovers that one. A backup that can't be written then leaves the save standing, as the
 * primary holds it, and the next save writes the backup again.
 *
 * Trust rule: the primary holds the last verified revision, or the backup does after a failed write or a load from the
 * backup; a revision in neither file means the file changed outside the server.
 *
 * Only the md5 of the last verified revision stays in memory between saves, so its text is read back first for the
 * parent's backup step: from the primary, or from the backup after a failed write or a load from the backup. A save
 * that succeeds, as a load from the primary does, leaves the primary holding the revision. So when it no longer does,
 * unless the last write failed or the file was loaded from its backup, or when neither file does, the file changed
 * outside the server: what the primary holds now, or the backup when there is no primary, becomes the backup instead
 * and stays it until the next save, and the save goes ahead.
 *
 * Returns:
 * - TRUE/FALSE: Whether the file on disk now holds the tree. Its backup does too unless the file changed outside the
 *   server or the backup couldn't be written.
 */
/datum/json_savefile/custom_sprites/graffiti/save()
	if(!dirty && !last_save_failed)
		return TRUE
	var/revision = last_good_json
	var/changed = FALSE
	// A file not written yet has the parent's "[]" for its revision, not an md5.
	if(path && revision && revision != "\[]")
		var/current = fexists(path) ? rustg_file_read(path) : null
		last_good_json = null
		if(current && md5(current) == revision)
			last_good_json = current
		else
			var/backup = fexists("[path].bak") ? rustg_file_read("[path].bak") : null
			if(last_save_failed && backup && md5(backup) == revision)
				last_good_json = backup
			else
				changed = TRUE
				log_game("The graffiti file [path] changed outside the server, so what it holds now is kept as its backup.")
				last_good_json = fexists(path) ? current : (fexists("[path].bak") ? backup : "\[]")
	. = ..()
	if(last_good_json == revision || last_good_json == "\[]")
		return
	var/hash = md5(last_good_json)
	// The primary holds the revision, so the save stands, and the next one writes the backup again.
	if(. && !changed && !write_hashed(last_good_json, hash, "[path].bak"))
		last_save_failed = TRUE
		log_game("The graffiti file [path] was saved, but its backup couldn't be written; the next save tries again.")
	last_good_json = hash

/**
 * Deletes the library's file, its backup and its staged copy, as a library that holds no pieces and no Unfinished piece
 * keeps none. A later save() writes the file again as a new one.
 *
 * Returns:
 * - TRUE/FALSE: Whether none of the three is left. A store that refuses writes deletes nothing.
 */
/datum/json_savefile/custom_sprites/graffiti/library/proc/delete_files()
	last_save_failed = TRUE
	if(!path || isnull(last_good_json))
		return FALSE
	for(var/file_name in list(path, "[path].bak", "[path].new"))
		fdel(file_name)
		if(fexists(file_name))
			return FALSE
	last_good_json = "\[]"
	dirty = FALSE
	last_save_failed = FALSE
	return TRUE

/**
 * One account's graffiti library: up to GRAFFITI_LIBRARY_CAP pieces and the Unfinished slot, kept in one JSON file
 * under SSgraffiti.library_root. Get it with graffiti_library().
 *
 * Every change is written through and undone when the write fails, so the library holds what its file doesn't only
 * while a change the server made waits for the write pacing (save()). A write the file holds stands even when its
 * backup couldn't be refreshed after it, which the next save does. It unloads as its owner disconnects, or, while an
 * editor session, a paint job or a held write still needs it, once they end (graffiti_library_unload()).
 */
/datum/graffiti_library
	/// The account's ckey.
	var/ckey
	/// Piece id -> list("piece" = canonical piece, "created", "updated", "thumb" = its flattened art), oldest first. Entries are replaced, never changed.
	var/list/pieces
	/// The last interrupted or unsaved piece, list("piece", "resume", "created", "thumb"), or null.
	var/list/unfinished
	/// The number in the next new piece's id, "g[next_id]".
	var/next_id = 1
	/// The library's file.
	var/datum/json_savefile/custom_sprites/graffiti/library/store
	/// Its state's number, from SSgraffiti.library_revision and new with each change, so a window that shows it knows to send it again.
	var/revision = 0
	/// What unfinished_entry() last flattened of a stopped paint job: list(piece, progress, the art revealed). The slot's
	/// piece is replaced, never changed, so a piece and a progress always reveal the same art.
	var/list/revealed
	/// The timer that writes the changes held back by the write pacing, while one is pending.
	var/write_timer
	/// snapshot() of the library as its file holds it, while changes wait for write_timer.
	var/list/unwritten

/**
 * Loads an account's library from its file.
 *
 * Every stored piece is validated again, and one that fails is dropped with a log line, as are pieces past
 * GRAFFITI_LIBRARY_CAP. When the file can't be read at all, such as one over GRAFFITI_LIBRARY_MAX_BYTES, the library
 * starts empty and its store refuses every write, so the file stays for an admin to look at.
 *
 * Arguments:
 * - ckey: The account's ckey.
 */
/datum/graffiti_library/New(ckey)
	src.ckey = ckey
	revision = ++SSgraffiti.library_revision
	pieces = list()
	store = new(graffiti_library_path(ckey))
	if(isnull(store.last_good_json))
		log_game("[ckey]'s graffiti library file couldn't be read, so the library stays empty and unsaved.")
	var/stored_id = store.get_entry("next_id")
	if(isnum(stored_id) && stored_id >= 1)
		next_id = round(stored_id)
	var/list/piece
	var/list/art
	var/list/stored = store.get_entry("pieces")
	for(var/id, entry in (islist(stored) ? stored : null))
		if(length(pieces) >= GRAFFITI_LIBRARY_CAP)
			log_game("[ckey]'s graffiti library holds more than [GRAFFITI_LIBRARY_CAP] pieces, so the rest weren't loaded.")
			break
		piece = istext(id) ? graffiti_library_check(islist(entry) ? entry["piece"] : null) : "Its id isn't text."
		if(istext(piece))
			log_game("Dropped graffiti piece [id] from [ckey]'s library: [piece]")
			continue
		art = entry["thumb"]
		// A thumb of another width was flattened before validation narrowed the piece.
		pieces[id] = list("piece" = piece, "created" = istext(entry["created"]) ? entry["created"] : "", "updated" = istext(entry["updated"]) ? entry["updated"] : "", "thumb" = islist(art) && art["w"] == piece["width"] ? art : graffiti_flatten(piece))
		// Ids stay unique when next_id is stale.
		next_id = max(next_id, text2num(copytext(id, 2)) + 1)
	var/list/slot = store.get_entry("unfinished")
	if(!islist(slot))
		return
	piece = graffiti_library_check(slot["piece"])
	if(istext(piece))
		log_game("Dropped the Unfinished graffiti piece from [ckey]'s library: [piece]")
		return
	art = slot["thumb"]
	unfinished = list("piece" = piece, "resume" = islist(slot["resume"]) ? slot["resume"] : null, "created" = istext(slot["created"]) ? slot["created"] : "", "thumb" = islist(art) && art["w"] == piece["width"] ? art : graffiti_flatten(piece))

/**
 * Returns the saved pieces as the spraycan's Custom Graffiti tab lists them, newest first.
 *
 * Returns:
 * - list: One entry_data() list per piece, by creation time. Among pieces made in the same second, the one added
 *   last comes first.
 */
/datum/graffiti_library/proc/entries()
	var/list/order = list()
	for(var/position in length(pieces) to 1 step -1)
		var/id = pieces[position]
		order[id] = pieces[id]["created"]
	sortTim(order, GLOBAL_PROC_REF(cmp_text_dsc), associative = TRUE)
	. = list()
	for(var/id in order)
		. += list(entry_data(id, pieces[id]))

/**
 * Returns the Unfinished slot as the Custom Graffiti tab shows it.
 *
 * Returns:
 * - list: entry_data()'s fields with a null `id`, plus `resume`, as set_unfinished() was given it, `progress`, its
 *   "progress" (null without resume data), and `revealed`, the flattened art of what a stopped paint job revealed
 *   (null for anything else).
 * - null: The slot is empty.
 */
/datum/graffiti_library/proc/unfinished_entry()
	if(!unfinished)
		return null
	var/list/resume = unfinished["resume"]
	var/progress = resume?["progress"]
	. = entry_data(null, unfinished)
	.["resume"] = resume
	.["progress"] = progress
	.["revealed"] = null
	if(!isnum(progress) || progress <= 0)
		return
	// So the window can ghost what a stopped paint job didn't reach. Every push of the slot shows it again.
	var/list/piece = unfinished["piece"]
	if(revealed?[1] != piece || revealed[2] != progress)
		var/list/bounds = graffiti_reveal_bounds(piece, progress)
		revealed = list(piece, progress, graffiti_flatten(piece, bounds[1], bounds[2]))
	.["revealed"] = revealed[3]

/**
 * Returns a saved piece.
 *
 * Arguments:
 * - id: The piece's id.
 *
 * Returns:
 * - list: The canonical piece. Never change it.
 * - null: No piece has that id.
 */
/datum/graffiti_library/proc/piece(id)
	return (id in pieces) ? pieces[id]["piece"] : null

/**
 * Saves a piece into the library, as a new piece or over one it holds.
 *
 * Arguments:
 * - piece: The piece, such as the editor serializes it. It is validated and cleaned again.
 * - id: The piece to replace. A new piece is made when it is null or no longer in the library.
 *
 * Returns:
 * - text: The piece's id, a key of `pieces`.
 * - text: Why nothing was saved, safe to show the player. It is never a key of `pieces`.
 */
/datum/graffiti_library/proc/save_piece(list/piece, id = null)
	piece = graffiti_library_check(piece)
	if(istext(piece))
		return piece
	if(!(id in pieces))
		if(length(pieces) >= GRAFFITI_LIBRARY_CAP)
			return "Your graffiti library is full ([GRAFFITI_LIBRARY_CAP])."
		id = null
	var/list/previous = snapshot()
	id = put(piece, id)
	return save(previous) ? id : "Your graffiti library couldn't be saved."

/**
 * Deletes a saved piece.
 *
 * Arguments:
 * - id: The piece's id.
 *
 * Returns:
 * - TRUE/FALSE: Whether it was deleted. It isn't when no piece has that id or the file couldn't be written.
 */
/datum/graffiti_library/proc/delete_piece(id)
	if(!(id in pieces))
		return FALSE
	var/list/previous = snapshot()
	pieces -= id
	return save(previous)

/**
 * Renames a saved piece and sets its description, as the Custom Graffiti tab edits them. Its art stays as it is.
 *
 * Arguments:
 * - id: The piece's id.
 * - name: Its new name, cleaned as names are kept, or "Untitled" when nothing is left of it.
 * - description: Its new description, cleaned as descriptions are kept.
 *
 * Returns:
 * - TRUE: The piece has that name and description, written now or already.
 * - text: Why it wasn't renamed, safe to show the player.
 */
/datum/graffiti_library/proc/rename_piece(id, name, description)
	if(!(id in pieces))
		return "That graffiti piece isn't in your library."
	name = graffiti_clean_text(name, GRAFFITI_MAX_NAME) || "Untitled"
	description = graffiti_clean_text(description, GRAFFITI_MAX_DESCRIPTION)
	var/list/entry = pieces[id]
	var/list/piece = entry["piece"]
	if(piece["name"] == name && piece["description"] == description)
		return TRUE
	var/list/previous = snapshot()
	piece = graffiti_copy_piece(piece)
	piece["name"] = name
	piece["description"] = description
	// A new entry, so a failed write puts the old one back.
	pieces[id] = list("piece" = piece, "created" = entry["created"], "updated" = graffiti_unix_time(), "thumb" = entry["thumb"])
	return save(previous) ? TRUE : "Your graffiti library couldn't be saved."

/**
 * Puts a piece in the Unfinished slot, replacing what it held.
 *
 * Arguments:
 * - piece: The piece, such as the editor serializes it. It is validated and cleaned again.
 * - resume: What a stopped paint job or freehand session resumes from, list("map", "anchor", "pid", "progress",
 *   "width"), or null. The library keeps a copy and never reads it.
 * - hold: Whether the server makes the change, as a session or paint job ends, so that save() holds it back while the
 *   write pacing runs rather than writing at once.
 *
 * Returns:
 * - null: The slot holds the piece.
 * - text: Why it doesn't, safe to show the player.
 */
/datum/graffiti_library/proc/set_unfinished(list/piece, list/resume = null, hold = FALSE)
	piece = graffiti_library_check(piece)
	if(istext(piece))
		return piece
	var/list/previous = snapshot()
	unfinished = list("piece" = piece, "resume" = islist(resume) ? deep_copy_list(resume) : null, "created" = graffiti_unix_time(), "thumb" = graffiti_flatten(piece))
	return save(previous, hold) ? null : "Your graffiti library couldn't be saved."

/**
 * Moves the Unfinished piece into the library as a new piece.
 *
 * Returns:
 * - text: The new piece's id, a key of `pieces`.
 * - text: Why it wasn't moved, safe to show the player. The slot keeps its piece.
 */
/datum/graffiti_library/proc/keep_unfinished()
	if(!unfinished)
		return "There's no unfinished graffiti to keep."
	if(length(pieces) >= GRAFFITI_LIBRARY_CAP)
		return "Your graffiti library is full ([GRAFFITI_LIBRARY_CAP])."
	var/list/previous = snapshot()
	var/id = put(unfinished["piece"], null, unfinished["thumb"])
	unfinished = null
	return save(previous) ? id : "Your graffiti library couldn't be saved."

/**
 * Empties the Unfinished slot.
 *
 * Arguments:
 * - hold: Whether the server makes the change, as a finished paint job does, so that save() holds it back while the
 *   write pacing runs rather than writing at once.
 *
 * Returns:
 * - TRUE/FALSE: Whether a piece was discarded. None is when the slot is empty or the file couldn't be written.
 */
/datum/graffiti_library/proc/discard_unfinished(hold = FALSE)
	if(!unfinished)
		return FALSE
	var/list/previous = snapshot()
	unfinished = null
	return save(previous, hold)

/**
 * Returns a saved piece as the text Export writes.
 *
 * Arguments:
 * - id: The piece's id.
 *
 * Returns:
 * - text: The piece's JSON, from graffiti_encode_piece().
 * - null: No piece has that id.
 */
/datum/graffiti_library/proc/export_text(id)
	return (id in pieces) ? graffiti_encode_piece(pieces[id]["piece"]) : null

/**
 * Imports a piece as a new piece. It must pass graffiti_validate_piece() as given, its `format` and `version`
 * included.
 *
 * Arguments:
 * - raw: The piece's JSON text, as Export writes it, or that text decoded.
 *
 * Returns:
 * - text: The new piece's id, a key of `pieces`.
 * - text: Why it was refused, safe to show the player. It never repeats the piece's text.
 */
/datum/graffiti_library/proc/import_piece(raw)
	if(istext(raw))
		raw = graffiti_json_decode(raw)
		if(istext(raw))
			return raw
	var/list/piece = graffiti_validate_piece(raw)
	return istext(piece) ? piece : save_piece(piece)

/**
 * Writes the library to its file, or deletes the file once the library holds no pieces and no Unfinished piece, and
 * paces the account's next write by how long this one took (graffiti_library_paced()).
 *
 * A change the server makes is never refused for the pacing: while the account's last write still paces the next, it
 * is held back, and write_timer writes it once the pacing allows, with whatever else changed meanwhile. Any write
 * takes the changes held so far with it.
 *
 * Arguments:
 * - previous: snapshot()'s state from before the change being written, put back when the write fails.
 * - hold: Whether to hold the change back while the pacing runs rather than write it at once.
 *
 * Returns:
 * - TRUE/FALSE: Whether the file holds the library, or will once the change held back is written.
 */
/datum/graffiti_library/proc/save(list/previous = null, hold = FALSE)
	var/wait = graffiti_library_write_wait(ckey)
	if(hold && wait > 0)
		// The first change held back has what the file holds.
		unwritten ||= previous
		write_timer ||= addtimer(CALLBACK(src, PROC_REF(write_held)), wait, TIMER_STOPPABLE)
		revision = ++SSgraffiti.library_revision
		return TRUE
	// A failed write puts back what the file holds, the changes held back so far included.
	if(unwritten)
		previous = unwritten
		unwritten = null
	deltimer(write_timer)
	write_timer = null
	store.set_entry("version", GRAFFITI_FORMAT_VERSION)
	store.set_entry("next_id", next_id)
	store.set_entry("pieces", pieces)
	store.set_entry("unfinished", unfinished)
	var/started = TICK_USAGE_REAL
	var/written = (length(pieces) || unfinished) ? store.save() : store.delete_files()
	graffiti_library_paced(ckey, TICK_DELTA_TO_MS(TICK_USAGE_REAL - started))
	if(written)
		revision = ++SSgraffiti.library_revision
		return TRUE
	log_game("[ckey]'s graffiti library couldn't be written to its file.")
	if(previous)
		pieces = previous["pieces"]
		unfinished = previous["unfinished"]
		next_id = previous["next_id"]
		// A window may have shown changes that were held back.
		revision = ++SSgraffiti.library_revision
	return FALSE

/**
 * Writes the changes the write pacing held back, as write_timer fires, then unloads the library if its owner
 * disconnected meanwhile (graffiti_library_unload()). A library no longer loaded, as after an admin purge, writes
 * nothing.
 */
/datum/graffiti_library/proc/write_held()
	write_timer = null
	if(SSgraffiti.libraries[ckey] != src)
		return
	save()
	if(!GLOB.directory[ckey])
		graffiti_library_unload(ckey)

/**
 * Returns the library's state, for save() to put back when a change can't be written.
 *
 * Returns:
 * - list: A copy of `pieces`, with `unfinished` and `next_id`.
 */
/datum/graffiti_library/proc/snapshot()
	return list("pieces" = pieces.Copy(), "unfinished" = unfinished, "next_id" = next_id)

/**
 * Stores a canonical piece in `pieces` without writing the file.
 *
 * Arguments:
 * - piece: The canonical piece.
 * - id: The piece it replaces, which keeps its id and creation time, or null for a new piece.
 * - art: The piece's flattened art, when the caller has it.
 *
 * Returns:
 * - text: The piece's id.
 */
/datum/graffiti_library/proc/put(list/piece, id, list/art = null)
	var/now = graffiti_unix_time()
	var/list/entry = list("piece" = piece, "created" = now, "updated" = now, "thumb" = art || graffiti_flatten(piece))
	if(id)
		entry["created"] = pieces[id]["created"] || now
	else
		id = "g[next_id]"
		next_id++
	pieces[id] = entry
	return id

/**
 * Returns one piece as the Custom Graffiti tab lists it.
 *
 * Arguments:
 * - id: The piece's id, or null for the Unfinished slot.
 * - entry: Its entry in `pieces`, or `unfinished`.
 *
 * Returns:
 * - list: `id`, `name`, `description`, `width`, `created`, `updated`, `glow` (whether any layer glows), `layers`
 *   (how many) and `thumb`, the flattened art.
 */
/datum/graffiti_library/proc/entry_data(id, list/entry)
	var/list/piece = entry["piece"]
	var/glow = FALSE
	for(var/list/layer as anything in piece["layers"])
		glow ||= layer["glow"]
	return list("id" = id, "name" = piece["name"], "description" = piece["description"], "width" = piece["width"], "created" = entry["created"], "updated" = entry["updated"] || entry["created"], "glow" = glow, "layers" = length(piece["layers"]), "thumb" = entry["thumb"])

/**
 * Returns an account's library, loading it from its file when it isn't loaded, as on first use or after it unloaded.
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - /datum/graffiti_library: The library, kept in SSgraffiti.libraries.
 * - null: The ckey can't name a library file.
 */
/proc/graffiti_library(ckey)
	if(!graffiti_library_path(ckey))
		return null
	var/datum/graffiti_library/library = SSgraffiti.libraries[ckey]
	if(!library)
		library = new(ckey)
		SSgraffiti.libraries[ckey] = library
	return library

/**
 * Returns where an account's library file lives, in a directory named by the ckey's first character.
 *
 * Arguments:
 * - ckey: The account's ckey.
 *
 * Returns:
 * - text: The file's path under SSgraffiti.library_root.
 * - null: The ckey is empty or has a character other than a lowercase letter, digit, underscore or @, so it can't
 *   name a file.
 */
/proc/graffiti_library_path(ckey)
	if(!istext(ckey) || !length(ckey) || spantext(ckey, "abcdefghijklmnopqrstuvwxyz0123456789_@") != length(ckey))
		return null
	return "[SSgraffiti.library_root][copytext(ckey, 1, 2)]/[ckey].json"

/**
 * Deletes an account's library, file and all, as an admin purge does. A library still held elsewhere is emptied and
 * can't write its file back.
 *
 * Arguments:
 * - ckey: The account's ckey.
 */
/proc/graffiti_library_delete(ckey)
	var/path = graffiti_library_path(ckey)
	if(!path)
		return
	var/datum/graffiti_library/library = SSgraffiti.libraries[ckey]
	if(library)
		library.store.path = null
		library.pieces = list()
		library.unfinished = null
		library.revision = ++SSgraffiti.library_revision
		SSgraffiti.libraries -= ckey
	for(var/file_name in list(path, "[path].bak", "[path].new"))
		fdel(file_name)

/**
 * Writes the library changes the write pacing still holds back, as the round ends or the world stops.
 */
/proc/graffiti_library_flush()
	for(var/ckey, value in SSgraffiti.libraries)
		var/datum/graffiti_library/library = value
		if(library.write_timer)
			library.save()

/**
 * Unloads an account's library as its owner disconnects, unless something still holds it: an editor session or a paint
 * job of the account's, a write the pacing holds back, or an import or export under way. An editor or paint job that
 * ends, and a held write once made, ask again while the owner is away; an import or export doesn't, so its library
 * waits for the owner's next disconnect or the reboot. graffiti_library() loads it again when it is next wanted, under
 * a newer revision.
 *
 * Arguments:
 * - ckey: The account's ckey.
 */
/proc/graffiti_library_unload(ckey)
	var/datum/graffiti_library/library = SSgraffiti.libraries[ckey]
	if(!library || library.write_timer || SSgraffiti.editors[ckey] || SSgraffiti.paint_jobs[ckey] || GLOB.custom_style_transfers[ckey]?["busy"])
		return
	SSgraffiti.libraries -= ckey

/**
 * Unloads the disconnecting account's graffiti library unless something still holds it (graffiti_library_unload()).
 */
/client/Destroy()
	graffiti_library_unload(ckey)
	return ..()

/**
 * Returns the current unix time in whole seconds, as the ten-digit text libraries store and sort. BYOND numbers
 * can't hold it exactly.
 *
 * Returns:
 * - text: The seconds.
 */
/proc/graffiti_unix_time()
	var/stamp = rustg_unix_timestamp()
	return copytext(stamp, 1, findtext(stamp, "."))

/**
 * Decodes a graffiti file's JSON, such as a piece's or a map's, as hostile input, without validating what it holds.
 *
 * json_decode() makes lists of JSON arrays and objects alike, so the text itself must open an object.
 *
 * Arguments:
 * - text: The file's text.
 * - limit: Its size limit in bytes.
 *
 * Returns:
 * - list: The decoded JSON object.
 * - text: Why it can't be decoded, safe to show the player.
 */
/proc/graffiti_json_decode(text, limit = GRAFFITI_PIECE_MAX_BYTES)
	if(!istext(text) || !length(text))
		return "The graffiti file is empty."
	if(length(text) > limit)
		return "The graffiti file is larger than [limit / 1024] KiB."
	// rust-g rejects malformed and deeply nested JSON before BYOND's recursive decoder sees it.
	if(!rustg_json_is_valid(text))
		return "The graffiti file isn't valid JSON."
	if(copytext(trimtext(text), 1, 2) != "{")
		return "The graffiti file must be a JSON object."
	var/list/decoded
	try
		decoded = json_decode(text)
	catch
		return "The graffiti file isn't valid JSON."
	return islist(decoded) ? decoded : "The graffiti file must be a JSON object."

/**
 * Returns a piece in the canonical form a library keeps, or why a library can't keep it.
 *
 * The piece is read back from the text Export would write for it, so it is held to that text's size and validated
 * as an import is, with the `format` and `version` Export writes and without keys Export leaves out.
 *
 * Arguments:
 * - piece: The piece, such as the editor serializes it or a library file holds it.
 *
 * Returns:
 * - list: The canonical piece, as graffiti_validate_piece() returns it.
 * - text: Why it was refused, safe to show the player.
 */
/proc/graffiti_library_check(list/piece)
	if(!islist(piece))
		return "The graffiti piece is malformed."
	var/list/raw = graffiti_json_decode(graffiti_encode_piece(piece))
	return istext(raw) ? raw : graffiti_validate_piece(raw)

/**
 * Asks a player for a graffiti piece file and decodes it. This sleeps while the file dialog is open.
 *
 * The account's transfer slot and import cooldown, which custom styles share, are claimed first and the slot is
 * released on every path. The byte size is checked before the file is read.
 *
 * Arguments:
 * - user: The player.
 *
 * Returns:
 * - list: The decoded JSON, not yet validated.
 * - text: Why there is nothing to import, safe to show the player.
 * - null: The player cancelled.
 */
/proc/graffiti_receive(mob/user)
	var/ckey = user?.ckey
	var/transfer_error = custom_style_transfer_begin(ckey, "import")
	if(transfer_error)
		return transfer_error
	var/result
	try
		var/uploaded = input(user, "Choose a graffiti piece to import.", "Import graffiti") as null|file
		if(!isnull(uploaded))
			var/bytes = isfile(uploaded) ? length(uploaded) : 0
			if(!bytes)
				result = "The file is empty or unreadable."
			else if(bytes > GRAFFITI_PIECE_MAX_BYTES)
				result = "The graffiti piece is larger than [GRAFFITI_PIECE_MAX_BYTES / 1024] KiB."
			else
				result = graffiti_json_decode(file2text(uploaded))
			if(istext(result))
				log_game("[key_name(user)] had a graffiti import rejected ([bytes] bytes): [result]")
	catch
		result = "The file couldn't be read."
	custom_style_transfer_end(ckey)
	return result

/**
 * Lets a player import a graffiti piece file into their library as a new piece. This sleeps while the file dialog
 * is open.
 *
 * Arguments:
 * - user: The player.
 *
 * Returns:
 * - null: The piece was imported, or the player cancelled.
 * - text: Why it wasn't imported, safe to show the player.
 */
/proc/graffiti_import(mob/user)
	var/ckey = user?.ckey
	var/raw = graffiti_receive(user)
	if(!islist(raw))
		return raw
	// Looked up after the dialog, in case an admin deleted the library meanwhile.
	var/datum/graffiti_library/library = graffiti_library(ckey)
	var/result = library.import_piece(raw)
	if(!(result in library.pieces))
		log_game("[key_name(user)] had a graffiti import rejected: [result]")
		return result
	log_game("[key_name(user)] imported graffiti piece [result].")
	return null

/**
 * Sends a saved piece to a player as a downloaded file. custom_style_send_text() claims the account's transfer slot
 * and export cooldown, which custom styles share.
 *
 * Arguments:
 * - user: The player.
 * - id: The piece's id.
 *
 * Returns:
 * - null: The file was sent.
 * - text: Why it wasn't, safe to show the player.
 */
/proc/graffiti_export(mob/user, id)
	var/datum/graffiti_library/library = graffiti_library(user?.ckey)
	var/list/piece = library?.piece(id)
	if(!piece)
		return "That graffiti piece isn't in your library."
	var/label = ckey(html_decode(piece["name"]))
	return custom_style_send_text(user.client, library.export_text(id), length(label) ? "graffiti-[label]" : "graffiti", "graffiti piece")

#undef GRAFFITI_LIBRARY_MAX_BYTES
