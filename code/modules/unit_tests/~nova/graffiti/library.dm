/**
 * Points the graffiti library directory at `root`, then forgets the test account's library and its write pacing and
 * deletes the scratch directory, so a test starts and ends with no library files.
 *
 * Arguments:
 * - root: The directory library files go under.
 */
/proc/graffiti_library_test_reset(root)
	SSgraffiti.library_root = root
	SSgraffiti.libraries -= "graffiti_test"
	GLOB.custom_style_transfers -= "graffiti_test"
	fdel("data/graffiti_test/")

/**
 * A library holds GRAFFITI_LIBRARY_CAP pieces and the Unfinished slot through a reload from its file. Each write paces
 * the account's next player write by its cost. At the cap it refuses a new piece and a Keep but still replaces a saved
 * piece, and a stored piece that no longer validates is dropped when the file loads. The library loaded after a purge
 * is empty under a newer revision, so a window still showing the purged one is sent the empty one.
 */
/datum/unit_test/graffiti_library_caps
	priority = TEST_LONGER

/datum/unit_test/graffiti_library_caps/Run()
	graffiti_library_test_reset("data/graffiti_test/library/")
	var/datum/graffiti_library/library = graffiti_library("graffiti_test")
	var/list/piece = graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH))
	var/id
	for(var/position in 1 to GRAFFITI_LIBRARY_CAP)
		id = library.save_piece(piece)
		TEST_ASSERT(id in library.pieces, "Piece [position] must be saved: [id]")
	var/paced = graffiti_library_write_wait("graffiti_test") >= 1 SECONDS
	// A write as slow as fifty adversarial pieces' slowest.
	graffiti_library_paced("graffiti_test", 209)
	var/wait = graffiti_library_write_wait("graffiti_test")
	TEST_ASSERT(paced && !graffiti_library_write_due("graffiti_test") && abs(wait - 209 * GRAFFITI_LIBRARY_WRITE_PACE MILLISECONDS) < 0.1, "Every write must hold the next player write a second at least, and a 209 ms one [GRAFFITI_LIBRARY_WRITE_PACE] times as long: a save paced [paced], [wait] ds left.")
	TEST_ASSERT(!(library.save_piece(piece) in library.pieces), "A piece past the cap must be refused.")
	piece["name"] = "Renamed"
	TEST_ASSERT_EQUAL(library.save_piece(piece, id), id, "A saved piece must still be replaced at the cap.")
	var/list/saved = library.piece(id)
	TEST_ASSERT(length(library.pieces) == GRAFFITI_LIBRARY_CAP && saved["name"] == "Renamed", "Replacing a piece must change it and keep the count.")
	library.set_unfinished(piece)
	piece["name"] = "Second"
	library.set_unfinished(piece, list("progress" = 2))
	var/list/entry = library.unfinished_entry()
	TEST_ASSERT(entry["name"] == "Second" && entry["progress"] == 2, "A second Unfinished piece must replace the first.")
	TEST_ASSERT(!(library.keep_unfinished() in library.pieces) && library.unfinished, "Keep must be refused at the cap and leave the Unfinished piece.")
	TEST_ASSERT(library.delete_piece(id), "A saved piece must be deleted.")
	id = library.keep_unfinished()
	TEST_ASSERT((id in library.pieces) && !library.unfinished, "Keep must move the Unfinished piece into a library under the cap: [id]")
	piece["name"] = "Third"
	library.set_unfinished(piece, list("map" = "Test Map", "pid" = "graffiti_test-1", "progress" = -1, "width" = GRAFFITI_WIDTH))
	var/listed = json_encode(library.entries())
	var/before = json_encode(library.unfinished_entry())
	SSgraffiti.libraries -= "graffiti_test"
	library = graffiti_library("graffiti_test")
	TEST_ASSERT_EQUAL(length(library.pieces), GRAFFITI_LIBRARY_CAP, "Every piece must survive a reload.")
	TEST_ASSERT_EQUAL(json_encode(library.entries()), listed, "Ids, pieces, times and thumbnails must survive a reload.")
	TEST_ASSERT_EQUAL(json_encode(library.unfinished_entry()), before, "The Unfinished piece and its resume data must survive a reload.")
	var/list/data = json_decode(rustg_file_read(library.store.path))
	data["pieces"][id]["piece"]["width"] = 48
	rustg_file_write(json_encode(data), library.store.path)
	SSgraffiti.libraries -= "graffiti_test"
	library = graffiti_library("graffiti_test")
	TEST_ASSERT(length(library.pieces) == GRAFFITI_LIBRARY_CAP - 1 && !(id in library.pieces), "A stored piece that no longer validates must be dropped when the library loads.")
	var/revision = library.revision
	graffiti_library_delete("graffiti_test")
	library = graffiti_library("graffiti_test")
	TEST_ASSERT(!length(library.pieces) && library.revision > revision, "The library loaded after a purge must be empty under a newer revision: [library.revision] after [revision]")

/**
 * Puts the library directory back and deletes the test's files.
 */
/datum/unit_test/graffiti_library_caps/Destroy()
	graffiti_library_test_reset(GRAFFITI_LIBRARY_DIRECTORY)
	return ..()

/**
 * Import refuses what piece validation refuses, another format, an oversized file and broken JSON, and an exported
 * piece imports as a new piece that exports to the same text.
 */
/datum/unit_test/graffiti_library_import/Run()
	graffiti_library_test_reset("data/graffiti_test/library/")
	var/datum/graffiti_library/library = graffiti_library("graffiti_test")
	var/id = library.save_piece(graffiti_validate_piece(graffiti_test_piece()))
	var/text = library.export_text(id)
	var/imported = library.import_piece(text)
	TEST_ASSERT((imported in library.pieces) && imported != id, "An exported piece must import as a new piece: [imported]")
	TEST_ASSERT_EQUAL(graffiti_encode_piece(library.piece(imported)), text, "An imported piece must export to the text it came from.")
	var/list/cases = list("broken JSON" = copytext(text, 1, -1))
	var/list/raw = graffiti_test_piece()
	// repeat_string() is quadratic, so the long text is built from 64-character blocks.
	raw["description"] = repeat_string(GRAFFITI_PIECE_MAX_BYTES / 64, repeat_string(64, "x"))
	cases["an oversized file"] = json_encode(raw)
	raw = graffiti_test_piece()
	raw["format"] = "aphelion-custom-style"
	cases["another format"] = json_encode(raw)
	raw = graffiti_test_piece()
	raw["author"] = "Jane"
	cases["an unknown field"] = json_encode(raw)
	raw = graffiti_test_piece()
	raw["layers"] = list(raw["layers"][1], raw["layers"][1], raw["layers"][1], raw["layers"][1], raw["layers"][1])
	cases["five layers"] = json_encode(raw)
	cases["a 48-pixel width"] = json_encode(graffiti_test_piece(48))
	raw = graffiti_test_piece()
	raw["palette"] = list("#ff0000", "#39ff14zz")
	cases["a colour with bad hex"] = json_encode(raw)
	raw = graffiti_test_piece()
	raw["layers"][2]["grid"] = custom_sprite_encode_grid(repeat_string(1024, "1"), 2, 1024)
	cases["a grid of the wrong length"] = json_encode(raw)
	raw = graffiti_test_piece()
	for(var/list/layer as anything in raw["layers"])
		layer["grid"] = custom_sprite_encode_grid(repeat_string(2048, "0"), 2, 2048)
	cases["a piece with no paint"] = json_encode(raw)
	for(var/label, variant in cases)
		TEST_ASSERT(!(library.import_piece(variant) in library.pieces), "Imported [label].")
	TEST_ASSERT_EQUAL(length(library.pieces), 2, "A refused import must not add a piece.")

/**
 * Puts the library directory back and deletes the test's files.
 */
/datum/unit_test/graffiti_library_import/Destroy()
	graffiti_library_test_reset(GRAFFITI_LIBRARY_DIRECTORY)
	return ..()

/**
 * A deleted piece leaves the backup at the write that deletes it, not at a later one, and a library left with no pieces
 * and no Unfinished piece, as a paint job's held write leaves it, deletes its file, backup and staged copy. The next
 * save writes them again under the next id.
 */
/datum/unit_test/graffiti_library_delete_scrubs_backup/Run()
	graffiti_library_test_reset("data/graffiti_test/library/")
	var/datum/graffiti_library/library = graffiti_library("graffiti_test")
	var/path = library.store.path
	var/list/piece = graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH))
	var/kept = library.save_piece(piece)
	var/list/raw = graffiti_test_piece(GRAFFITI_WIDTH)
	// Its whole top row painted, so no other piece shares its grid.
	raw["layers"][1]["grid"] = custom_sprite_encode_grid("[repeat_string(GRAFFITI_WIDTH, "1")][repeat_string(GRAFFITI_WIDTH * (GRAFFITI_HEIGHT - 1), "0")]", 2, GRAFFITI_WIDTH * GRAFFITI_HEIGHT)
	var/deleted = library.save_piece(graffiti_validate_piece(raw))
	var/grid = library.piece(deleted)["layers"][1]["grid"]
	TEST_ASSERT(findtext(rustg_file_read(path), grid), "The second piece must be written with its own grid.")
	TEST_ASSERT(library.delete_piece(deleted) && !findtext(rustg_file_read("[path].bak"), grid), "A deleted piece must leave the backup at the write that deletes it.")
	// Kept and then discarded as the server does, held back by the pacing until the flush writes them.
	library.set_unfinished(piece, null, TRUE)
	graffiti_library_flush()
	library.delete_piece(kept)
	library.discard_unfinished(TRUE)
	graffiti_library_flush()
	TEST_ASSERT(!fexists(path) && !fexists("[path].bak") && !fexists("[path].new"), "An empty library must delete its file, its backup and its staged copy.")
	TEST_ASSERT(library.save_piece(piece) == "g3" && rustg_hash_file(RUSTG_HASH_MD5, "[path].bak") == rustg_hash_file(RUSTG_HASH_MD5, path), "The next save must write the file and its backup again, under the next id.")

/**
 * Puts the library directory back and deletes the test's files.
 */
/datum/unit_test/graffiti_library_delete_scrubs_backup/Destroy()
	graffiti_library_test_reset(GRAFFITI_LIBRARY_DIRECTORY)
	return ..()
