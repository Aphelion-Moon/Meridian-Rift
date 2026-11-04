/**
 * Empties the graffiti registry and points it at a scratch map file, with its sheets in the scratch directory too.
 *
 * Arguments:
 * - path: The scratch map file, under data/graffiti_test/.
 */
/proc/graffiti_registry_test_begin(path)
	// The test room stays up for a test that starts the registry over partway
	graffiti_registry_test_end(keep_room = TRUE)
	SSgraffiti.frozen = FALSE
	SSgraffiti.sheet_root = "data/graffiti_test/sheets/"
	SSgraffiti.load_file(path)

/**
 * Empties the graffiti registry, takes the test room down (graffiti_test_room()), puts the registry's test settings back
 * and deletes the scratch directory. The registry points at the current map's own file again but stays frozen, so
 * nothing the rest of a test round does is written over it.
 *
 * Arguments:
 * - keep_room: Whether the test room stays up.
 */
/proc/graffiti_registry_test_end(keep_room = FALSE)
	SSgraffiti.wipe_for_test()
	if(!keep_room)
		graffiti_test_room_end()
	SSgraffiti.placement_cap = GRAFFITI_MAP_PLACEMENT_CAP
	SSgraffiti.art_byte_budget = GRAFFITI_MAP_ART_BYTES
	SSgraffiti.sheet_root = GRAFFITI_SHEET_DIRECTORY
	SSgraffiti.map_path = "[GRAFFITI_MAP_DIRECTORY][graffiti_file_key(SSmapping.current_map.map_name)].json"
	SSgraffiti.store = new /datum/json_savefile/custom_sprites/graffiti/map(SSgraffiti.map_path)
	SSgraffiti.frozen = TRUE
	fdel("data/graffiti_test/")

/**
 * Returns a one-tile art with one or two red pixels.
 *
 * Arguments:
 * - pixel: A painted pixel that doesn't glow, counted row by row from the top left.
 * - lit: A painted pixel that glows, or 0 for none.
 *
 * Returns:
 * - list: The art.
 */
/proc/graffiti_test_art(pixel = 1, lit = 0)
	var/list/indices = list()
	var/list/glow = list()
	for(var/position in 1 to GRAFFITI_WIDTH * GRAFFITI_HEIGHT)
		indices += (position == pixel || position == lit ? 1 : 0)
		glow += (position == lit ? 1 : 0)
	return list("w" = GRAFFITI_WIDTH, "pal" = "#ff0000ff", "grid" = graffiti_encode_flat(indices, 1), "glow" = graffiti_encode_flat(glow, 1))

/// The graffiti test room's width and height, its walls included: 96 floors inside, past the caps test's 81
#define GRAFFITI_TEST_ROOM_WIDTH 13
#define GRAFFITI_TEST_ROOM_HEIGHT 11
/// How many walls stand side by side across the test room's floors
#define GRAFFITI_TEST_ROOM_ROW 3
/// Where that row's west end is, in tiles from the room's south-west corner
#define GRAFFITI_TEST_ROOM_ROW_X 2
#define GRAFFITI_TEST_ROOM_ROW_Y 5

/// The graffiti test room's turfs while a test has it up (graffiti_test_room())
GLOBAL_LIST(graffiti_test_room)

/**
 * Returns the room the graffiti tests paint in, built the first time a test asks and taken down by
 * graffiti_registry_test_end(): walls round floors, with a row of GRAFFITI_TEST_ROOM_ROW walls across them, built on empty
 * space of a station level and moved into a station area, so its every tile takes graffiti under a station anchor. No
 * map is relied on to have such walls, as the unit test map, runtimestation_minimal, is all space. The room sits inside
 * one of the 16-tile chunks build_sheets() packs together.
 *
 * Returns:
 * - list: The room's turfs, from the south-west corner, west to east, then row by row north.
 * - null: No station level has empty space for it.
 */
/proc/graffiti_test_room()
	if(GLOB.graffiti_test_room)
		return GLOB.graffiti_test_room
	var/area/station_area
	for(var/area/station/place in GLOB.areas)
		if(!istype(place, /area/station/holodeck))
			station_area = place
			break
	var/z_level = SSmapping.levels_by_trait(ZTRAIT_STATION)[1]
	for(var/chunk_y = 16 to world.maxy - GRAFFITI_TEST_ROOM_HEIGHT - 1 step 16)
		for(var/chunk_x = 16 to world.maxx - GRAFFITI_TEST_ROOM_WIDTH - 1 step 16)
			// The room and a tile round it must be space nothing has touched, so taking it down leaves the level as it was
			var/clear = TRUE
			for(var/turf/tile as anything in block(chunk_x, chunk_y, z_level, chunk_x + GRAFFITI_TEST_ROOM_WIDTH + 1, chunk_y + GRAFFITI_TEST_ROOM_HEIGHT + 1, z_level))
				if(tile.type != world.turf || tile.loc.type != world.area || length(tile.contents))
					clear = FALSE
					break
			if(!clear)
				continue
			var/list/room = block(chunk_x + 1, chunk_y + 1, z_level, chunk_x + GRAFFITI_TEST_ROOM_WIDTH, chunk_y + GRAFFITI_TEST_ROOM_HEIGHT, z_level)
			set_turfs_to_area(room, station_area)
			for(var/turf/tile as anything in room)
				var/across = tile.x - chunk_x - 1
				var/up = tile.y - chunk_y - 1
				var/edge = !across || !up || across == GRAFFITI_TEST_ROOM_WIDTH - 1 || up == GRAFFITI_TEST_ROOM_HEIGHT - 1
				var/row = up == GRAFFITI_TEST_ROOM_ROW_Y && across >= GRAFFITI_TEST_ROOM_ROW_X && across < GRAFFITI_TEST_ROOM_ROW_X + GRAFFITI_TEST_ROOM_ROW
				tile.ChangeTurf((edge || row) ? /turf/closed/wall : /turf/open/floor/iron)
			GLOB.graffiti_test_room = room
			return room
	return null

/**
 * Takes the graffiti test room down, if a test put it up: deletes all a test left in it, then turns it back into the
 * space of the space area it was.
 */
/proc/graffiti_test_room_end()
	var/list/room = GLOB.graffiti_test_room
	if(!room)
		return
	GLOB.graffiti_test_room = null
	// All of it first, so nothing hung on a wall falls off onto a floor as the wall goes
	for(var/turf/tile as anything in room)
		for(var/atom/movable/thing as anything in tile)
			qdel(thing)
	for(var/turf/tile as anything in room)
		tile.ChangeTurf(world.turf)
	set_turfs_to_area(room, GLOB.areas_by_type[world.area])

/**
 * Returns walls side by side, west to east, in the test room (graffiti_test_room()), each between two floors so that
 * turning one into a floor opens no room to space, and with nothing wall-mounted on it or around it. The same walls come
 * back every call.
 *
 * Arguments:
 * - count: How many walls, up to GRAFFITI_TEST_ROOM_ROW.
 *
 * Returns:
 * - list: The walls.
 * - null: There aren't that many, or no room.
 */
/proc/graffiti_test_walls(count)
	var/list/room = graffiti_test_room()
	if(!room || count > GRAFFITI_TEST_ROOM_ROW)
		return null
	var/turf/corner = room[1]
	. = list()
	for(var/offset in 0 to count - 1)
		. += locate(corner.x + GRAFFITI_TEST_ROOM_ROW_X + offset, corner.y + GRAFFITI_TEST_ROOM_ROW_Y, corner.z)

/**
 * Whether anything wall-mounted is on a wall or on the turfs beside it, where it may hang from the wall.
 *
 * Arguments:
 * - wall: The wall.
 *
 * Returns:
 * - TRUE/FALSE
 */
/proc/graffiti_test_mounted(turf/wall)
	for(var/direction in list(0, NORTH, SOUTH, EAST, WEST))
		var/turf/place = direction ? get_step(wall, direction) : wall
		for(var/obj/thing in place)
			if(HAS_TRAIT(thing, TRAIT_WALLMOUNTED))
				return TRUE
	return FALSE

/**
 * Counts the cameras on the station levels.
 *
 * Returns:
 * - number: The cameras.
 */
/proc/graffiti_test_cameras()
	. = 0
	for(var/obj/machinery/camera/camera as anything in SScameras.cameras)
		if(is_station_level(camera.z))
			.++

/**
 * Returns floors of the test room (graffiti_test_room()), where graffiti gets a station anchor.
 *
 * Arguments:
 * - count: How many floors.
 *
 * Returns:
 * - list: Up to `count` floors, the same ones every call.
 */
/proc/graffiti_test_floors(count)
	. = list()
	for(var/turf/open/floor/floor in graffiti_test_room())
		if(graffiti_surface_ok(floor) && graffiti_anchor_for(floor)?["kind"] == GRAFFITI_ANCHOR_STATION)
			. += floor
			if(length(.) == count)
				return

/**
 * Finds a placement by its id.
 *
 * Arguments:
 * - pid: The placement's id.
 * - where: Packed placements to look through, such as SSgraffiti.dormant.
 *
 * Returns:
 * - list: The unpacked placement.
 * - null: None of them has that id.
 */
/proc/graffiti_test_placement(pid, list/where)
	for(var/packed in where)
		var/list/placement = SSgraffiti.unpack(packed)
		if(placement["pid"] == pid)
			return placement
	return null

/**
 * Compares the registry's index of each account's placements with a scan of the placements themselves.
 *
 * Returns:
 * - text: What differs.
 * - null: Nothing does: every placement is indexed with the fields admin search, admin deletion and saving read, under
 *   its account with its art counted, and each account's placements are in the order its caps evict them, oldest first,
 *   then as `placements` orders them.
 */
/proc/graffiti_test_index_problem()
	// Ckey -> its placements, and ckey -> art hash -> how many of them use it, from the placements.
	var/list/scanned = list()
	var/list/counts = list()
	for(var/packed in SSgraffiti.placements)
		var/list/placement = SSgraffiti.unpack(packed)
		var/list/info = SSgraffiti.placement_info[packed]
		if(!info)
			return "[placement["pid"]] isn't indexed"
		if(info[GRAFFITI_INFO_CKEY] != placement["ckey"] || info[GRAFFITI_INFO_ART] != placement["art"] || info[GRAFFITI_INFO_AT] != placement["at"] || info[GRAFFITI_INFO_PID] != placement["pid"] || info[GRAFFITI_INFO_WHO] != placement["who"] || info[GRAFFITI_INFO_ROUND_ONLY] != (placement["round_only"] ? TRUE : FALSE))
			return "[placement["pid"]] is indexed as [json_encode(info)]"
		var/ckey = placement["ckey"]
		if(!scanned[ckey])
			scanned[ckey] = list()
			counts[ckey] = list()
		var/list/mine = scanned[ckey]
		mine += packed
		var/list/arts = counts[ckey]
		arts[placement["art"]] += 1
	if(length(SSgraffiti.placement_info) != length(SSgraffiti.placements))
		return "[length(SSgraffiti.placement_info)] placements indexed, [length(SSgraffiti.placements)] held"
	if(length(SSgraffiti.ckey_placements) != length(scanned) || length(SSgraffiti.ckey_arts) != length(scanned))
		return "[length(SSgraffiti.ckey_placements)] accounts indexed, [length(scanned)] own placements"
	for(var/ckey, value in scanned)
		var/list/mine = value
		var/list/indexed = SSgraffiti.ckey_placements[ckey]
		if(length(indexed) != length(mine) || length(indexed & mine) != length(mine))
			return "[ckey]'s indexed placements differ"
		for(var/position in 2 to length(indexed))
			var/list/before = SSgraffiti.unpack(indexed[position - 1])
			var/list/after = SSgraffiti.unpack(indexed[position])
			var/order = sorttext(before["at"], after["at"])
			if(order == -1 || (!order && SSgraffiti.placements.Find(indexed[position - 1]) > SSgraffiti.placements.Find(indexed[position])))
				return "[ckey]'s placements are indexed out of order at [position]"
		var/list/arts = counts[ckey]
		var/list/indexed_arts = SSgraffiti.ckey_arts[ckey]
		if(length(indexed_arts) != length(arts))
			return "[ckey]'s art is counted as [length(indexed_arts)] arts, not [length(arts)]"
		for(var/hash, count in arts)
			if(indexed_arts[hash] != count)
				return "[ckey]'s art [hash] is counted [indexed_arts[hash]] times, not [count]"
	return null

/**
 * Placements saved to a map file come back onto the same walls in stack order, with repeated art stored once and times
 * kept as text. A placement whose art is missing is dropped, one whose wall became a floor stays dormant with a miss,
 * and one that never resolves is dropped on its GRAFFITI_MISS_LIMIT-th miss in a row. The file is the JSON
 * json_encode() writes, which escapes an accented letter, and an accented character name comes back.
 */
/datum/unit_test/graffiti_registry_roundtrip/Run()
	var/path = "data/graffiti_test/roundtrip.json"
	graffiti_registry_test_begin(path)
	var/cameras = graffiti_test_cameras()
	var/list/turfs = graffiti_test_walls(3)
	TEST_ASSERT_EQUAL(length(turfs), 3, "The test room must have three walls side by side between floors.")
	for(var/turf/place as anything in turfs)
		TEST_ASSERT(!graffiti_test_mounted(place), "The walls picked must have nothing wall-mounted on or beside them: [AREACOORD(place)]")
	var/list/art = graffiti_test_art(1)
	var/list/other = graffiti_test_art(2)
	var/list/added = list(
		SSgraffiti.add_placement(turfs[1], art, "graffiti_test", "Jane Doe", "graffiti_test-bottom"),
		SSgraffiti.add_placement(turfs[1], other, "graffiti_test", "Jane Doe", "graffiti_test-top"),
		SSgraffiti.add_placement(turfs[2], art, "graffiti_test", "Ren[ascii2text(233)]e Doe", "graffiti_test-again"),
		SSgraffiti.add_placement(turfs[3], other, "graffiti_test", "Jane Doe", "graffiti_test-moved"),
	)
	TEST_ASSERT_EQUAL(length(added & SSgraffiti.placements), 4, "Every placement must be added: [json_encode(added)]")
	SSgraffiti.seen["graffiti_test"] = graffiti_unix_time()
	SSgraffiti.save_now()
	var/saved_art = json_encode(SSgraffiti.art)
	var/saved_seen = json_encode(SSgraffiti.seen)
	var/text = rustg_file_read(path)
	TEST_ASSERT(!SSgraffiti.store.last_save_failed, "The map file must be written.")
	// json_encode() writes letters past ASCII as \u escapes, so the file is plain ASCII whatever names it holds.
	TEST_ASSERT(findtext(text, "\\u00e9"), "The map file must hold the accented character name as json_encode() writes it.")
	TEST_ASSERT_EQUAL(json_encode(json_decode(text)), text, "The map file must be the JSON json_encode() writes for it.")
	var/list/data = json_decode(text)
	var/list/entry = data["placements"][1]
	TEST_ASSERT(istext(entry["at"]) && istext(data["seen"]["graffiti_test"]), "Times must be saved as text.")
	entry = entry.Copy()
	entry["art"] = md5("missing")
	entry["pid"] = "graffiti_test-broken"
	data["placements"] += list(entry)
	// Anchored in an area the wall isn't in, so they miss every round.
	for(var/misses in list(GRAFFITI_MISS_LIMIT - 1, GRAFFITI_MISS_LIMIT - 2))
		entry = json_decode(json_encode(data["placements"][1]))
		entry["anchor"]["area"] = "/area/graffiti_test_nowhere"
		entry["miss"] = misses
		entry["pid"] = "graffiti_test-missed-[misses]"
		data["placements"] += list(entry)
	rustg_file_write(json_encode(data), path)
	SSgraffiti.wipe_for_test()
	var/turf/wall = turfs[3]
	var/wall_type = wall.type
	wall.ChangeTurf(/turf/open/floor/plating)
	SSgraffiti.load_file(path)
	SSgraffiti.place_all()
	var/problem = graffiti_test_index_problem()
	// Read before the wall goes back, so that a failure can't leave a floor on the station.
	var/obj/effect/decal/cleanable/crayon/custom/stacked = graffiti_tile_decal(turfs[1])
	var/obj/effect/decal/cleanable/crayon/custom/single = graffiti_tile_decal(turfs[2])
	var/list/pids = list()
	for(var/packed in stacked?.stack)
		var/list/placement = SSgraffiti.unpack(packed)
		pids += placement["pid"]
	var/list/missed = graffiti_test_placement("graffiti_test-moved", SSgraffiti.dormant)
	var/list/fading = graffiti_test_placement("graffiti_test-missed-[GRAFFITI_MISS_LIMIT - 2]", SSgraffiti.dormant)
	var/dropped = !graffiti_test_placement("graffiti_test-missed-[GRAFFITI_MISS_LIMIT - 1]", SSgraffiti.placements)
	wall.ChangeTurf(wall_type)
	TEST_ASSERT_EQUAL(graffiti_test_cameras(), cameras, "Turning a wall into plating and back must not knock down a camera.")
	TEST_ASSERT(stacked && single, "Both walls must show their graffiti again.")
	TEST_ASSERT_EQUAL(jointext(pids, ","), "graffiti_test-bottom,graffiti_test-top", "The stacked wall must keep its stack order.")
	TEST_ASSERT_EQUAL(length(SSgraffiti.art), 2, "Repeated art must be stored once.")
	TEST_ASSERT_EQUAL(json_encode(SSgraffiti.art), saved_art, "The art must load back as it was saved.")
	TEST_ASSERT_EQUAL(json_encode(SSgraffiti.seen), saved_seen, "When the owner was last seen must load back as it was saved.")
	TEST_ASSERT_NULL(graffiti_test_placement("graffiti_test-broken", SSgraffiti.placements), "A placement whose art is missing must be dropped.")
	TEST_ASSERT(missed?["miss"] == 1, "A placement whose wall became a floor must stay dormant with one miss.")
	TEST_ASSERT(dropped && fading?["miss"] == GRAFFITI_MISS_LIMIT - 1, "A placement that never resolves must stay dormant until its [GRAFFITI_MISS_LIMIT]th miss in a row drops it: dropped [dropped], the one before at [fading?["miss"]] misses.")
	TEST_ASSERT_NULL(problem, "After a load, and a miss packed into a placement again, the index must match the placements: [problem]")
	TEST_ASSERT_EQUAL(graffiti_test_placement("graffiti_test-again", SSgraffiti.placements)?["who"], "Ren[ascii2text(233)]e Doe", "An accented character name must load back as it was saved.")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_roundtrip/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * Washing graffiti off a wall, or turning the wall into plating, removes the graffiti for good, from the saved file too.
 * A file changed outside the server between two saves is kept as the backup, and the next save still writes the registry.
 */
/datum/unit_test/graffiti_registry_cleaned/Run()
	var/path = "data/graffiti_test/cleaned.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "The test room must have two walls side by side between floors.")
	var/first = SSgraffiti.add_placement(turfs[1], graffiti_test_art(1), "graffiti_test", "Jane Doe", "graffiti_test-washed")
	var/second = SSgraffiti.add_placement(turfs[2], graffiti_test_art(2), "graffiti_test", "Jane Doe", "graffiti_test-broken")
	SSgraffiti.save_now()
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(turfs[1])
	TEST_ASSERT(decal, "Graffiti must make a decal on its wall.")
	TEST_ASSERT_EQUAL(SSgraffiti.admin_rows(null, "area", 1)["total"], 2, "The admin panel must list both placements.")
	decal.wash(CLEAN_TYPE_LIGHT_DECAL)
	var/list/listed = SSgraffiti.admin_rows(null, "area", 1)["rows"]
	TEST_ASSERT(length(listed) == 1 && listed[1]["pid"] == "graffiti_test-broken", "The admin panel must stop listing washed graffiti at once: [json_encode(listed)]")
	var/turf/wall = turfs[2]
	var/wall_type = wall.type
	wall.ChangeTurf(/turf/open/floor/plating)
	var/left = graffiti_tile_decal(wall)
	var/kept = (second in SSgraffiti.placements)
	wall.ChangeTurf(wall_type)
	TEST_ASSERT(QDELETED(decal) && !(first in SSgraffiti.placements), "Washed graffiti must leave its wall and the registry.")
	TEST_ASSERT(!left && !kept, "A wall turned into plating must lose its graffiti for good.")
	SSgraffiti.save_now()
	var/list/data = json_decode(rustg_file_read(path))
	TEST_ASSERT_EQUAL(length(data["placements"]), 0, "The saved file must keep neither placement.")
	SSgraffiti.add_placement(turfs[1], graffiti_test_art(3), "graffiti_test", "Jane Doe", "graffiti_test-kept")
	SSgraffiti.save_now()
	rustg_file_write("junk", path)
	SSgraffiti.save_now()
	TEST_ASSERT(!SSgraffiti.store.last_save_failed, "A save must go ahead after the file was changed outside the server.")
	TEST_ASSERT_EQUAL(rustg_file_read("[path].bak"), "junk", "What the file held when it was changed outside the server must become its backup.")
	data = graffiti_json_decode(rustg_file_read(path), GRAFFITI_MAP_MAX_BYTES)
	TEST_ASSERT(islist(data) && length(data["placements"]) == 1 && data["placements"][1]["pid"] == "graffiti_test-kept", "The save after an outside change must write the registry: [islist(data) ? json_encode(data["placements"]) : data]")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_cleaned/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * Deleting a piece in the Graffiti Manager leaves the rest of its tile's stack in order, and discards its painter's
 * Unfinished piece left to resume on it, though the painter is offline.
 */
/datum/unit_test/graffiti_admin_delete/Run()
	graffiti_registry_test_begin("data/graffiti_test/admin.json")
	graffiti_library_test_reset("data/graffiti_test/library/")
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "The test room must have a wall between two floors to paint.")
	var/list/stack = list()
	for(var/position in 1 to 3)
		stack += SSgraffiti.add_placement(turfs[1], graffiti_test_art(position), "graffiti_test", "Jane Doe", "graffiti_test-[position]")
	var/datum/graffiti_library/library = graffiti_library("graffiti_test")
	library.set_unfinished(graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDTH)), list("map" = SSmapping.current_map.map_name, "pid" = "graffiti_test-2", "progress" = -1, "width" = GRAFFITI_WIDTH))
	// Unloaded, as an offline owner's library is, and with no write pacing to hold the discard back.
	SSgraffiti.libraries -= "graffiti_test"
	GLOB.custom_style_transfers -= "graffiti_test"
	TEST_ASSERT_EQUAL(SSgraffiti.admin_delete(list("graffiti_test-2")), 1, "Deleting by id must remove the one placement.")
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(turfs[1])
	TEST_ASSERT(decal?.stack ~= list(stack[1], stack[3]), "The rest of the tile's stack must stay, in its order: [json_encode(decal?.stack)]")
	TEST_ASSERT_EQUAL(graffiti_art_pixels(decal.stack_merge()), 2, "The tile must show the two pieces left.")
	TEST_ASSERT(!SSgraffiti.libraries["graffiti_test"], "An offline owner's library must be unloaded again.")
	library = graffiti_library("graffiti_test")
	TEST_ASSERT_NULL(library.unfinished, "The Unfinished piece left to resume on the deleted piece must be discarded.")

/**
 * Puts the registry and the library directory back and deletes the test's files.
 */
/datum/unit_test/graffiti_admin_delete/Destroy()
	graffiti_registry_test_end()
	graffiti_library_test_reset(GRAFFITI_LIBRARY_DIRECTORY)
	return ..()

/**
 * Cleaned graffiti leaves the map file and its backup at the next save, which still writes the graffiti left, and its
 * icon and glow mask leave the caches at once.
 */
/datum/unit_test/graffiti_deleted_bytes_gone/Run()
	var/path = "data/graffiti_test/gone.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "The test room must have two walls side by side between floors.")
	SSgraffiti.add_placement(turfs[1], graffiti_test_art(1), "graffiti_test", "Jane Doe", "graffiti_test-left")
	// Lit and unlit paint in a colour no other art has, so it draws both caches' icons and is found by its palette.
	var/list/art = graffiti_test_art(2, 3)
	art["pal"] = "#0badc0ff"
	var/hash = graffiti_art_hash(art)
	SSgraffiti.add_placement(turfs[2], art, "graffiti_test", "Jane Doe", "graffiti_test-cleaned")
	TEST_ASSERT(SSgraffiti.art_icons[hash] && SSgraffiti.glow_icons[hash], "Graffiti painted mid-round must show from the art and glow caches.")
	SSgraffiti.save_now()
	qdel(graffiti_tile_decal(turfs[2]))
	SSgraffiti.save_now(TRUE)
	for(var/file_name in list(path, "[path].bak"))
		var/text = rustg_file_read(file_name)
		TEST_ASSERT(findtext(text, "graffiti_test-left") && !findtext(text, art["pal"]) && !findtext(text, hash), "[file_name] must keep the graffiti left and nothing of the cleaned art.")
	TEST_ASSERT(!SSgraffiti.art_icons[hash] && !SSgraffiti.glow_icons[hash], "The cleaned art's icons must leave the caches at once.")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_deleted_bytes_gone/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * The halves of a wide piece live on their own walls: one whose wall became a floor stays dormant while the other still
 * shows. Halves that look alike share one hash, the same as a one-tile art that looks like them.
 */
/datum/unit_test/graffiti_registry_halves/Run()
	var/path = "data/graffiti_test/halves.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "The test room must have two walls side by side between floors.")
	var/list/sides = graffiti_split_wide(graffiti_flatten(graffiti_validate_piece(graffiti_test_piece(GRAFFITI_WIDE_WIDTH))))
	TEST_ASSERT_EQUAL(length(sides), 2, "A wide piece must split into two halves.")
	var/left = SSgraffiti.add_placement(turfs[1], sides[1], "graffiti_test", "Jane Doe", "graffiti_test-wide", 1)
	var/right = SSgraffiti.add_placement(turfs[2], sides[2], "graffiti_test", "Jane Doe", "graffiti_test-wide", 2)
	TEST_ASSERT((left in SSgraffiti.placements) && (right in SSgraffiti.placements), "Both halves must be added: [left] [right]")
	SSgraffiti.save_now()
	SSgraffiti.wipe_for_test()
	var/turf/wall = turfs[1]
	var/wall_type = wall.type
	wall.ChangeTurf(/turf/open/floor/plating)
	SSgraffiti.load_file(path)
	SSgraffiti.place_all()
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(turfs[2])
	var/list/shown = length(decal?.stack) == 1 ? SSgraffiti.unpack(decal.stack[1]) : null
	var/list/sleeping = graffiti_test_placement("graffiti_test-wide", SSgraffiti.dormant)
	wall.ChangeTurf(wall_type)
	TEST_ASSERT(shown?["half"] == 2 && shown["pid"] == "graffiti_test-wide", "The right half must still show on its wall.")
	TEST_ASSERT(sleeping?["half"] == 1, "The left half must stay dormant while its wall is a floor.")
	var/list/indices = list()
	var/list/glow = list()
	for(var/position in 1 to GRAFFITI_WIDE_WIDTH * GRAFFITI_HEIGHT)
		indices += (position == 1 || position == GRAFFITI_WIDTH + 1 ? 1 : 0)
		glow += 0
	sides = graffiti_split_wide(list("w" = GRAFFITI_WIDE_WIDTH, "pal" = "#ff0000ff", "grid" = graffiti_encode_flat(indices, 1), "glow" = graffiti_encode_flat(glow, 1)))
	TEST_ASSERT_EQUAL(graffiti_art_hash(sides[1]), graffiti_art_hash(sides[2]), "Halves that look alike must share one hash.")
	TEST_ASSERT_EQUAL(graffiti_art_hash(sides[1]), graffiti_art_hash(graffiti_test_art(1)), "A half must hash the same as a one-tile art that looks like it.")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_halves/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * An account at its placement cap loses its oldest placement to its next one, a sixth piece on a tile buries the oldest
 * for good, and a map at its placement cap or out of art bytes loses the lowest-ranked placement of an owner who isn't
 * connected. New art for a placement meets the same caps, its own old art going with it, and with nothing else to go it
 * is refused and the placement keeps its old art.
 */
/datum/unit_test/graffiti_registry_caps
	priority = TEST_LONGER

/datum/unit_test/graffiti_registry_caps/Run()
	var/path = "data/graffiti_test/caps.json"
	graffiti_registry_test_begin(path)
	var/tiles = GRAFFITI_CKEY_PLACEMENT_CAP / GRAFFITI_STACK_CAP + 1
	var/list/floors = graffiti_test_floors(tiles)
	TEST_ASSERT_EQUAL(length(floors), tiles, "The test room must have enough floors.")
	var/list/art = graffiti_test_art(1)
	// The account's unique-art cap, GRAFFITI_CKEY_UNIQUE_CAP, which registry.dm keeps to itself.
	var/unique_cap = GRAFFITI_MAP_UNIQUE_CAP / 10
	// Placed in one second, so their ids, made up as they come, must still differ. The account reaches both its caps.
	for(var/position in 1 to GRAFFITI_CKEY_PLACEMENT_CAP)
		SSgraffiti.add_placement(floors[CEILING(position / GRAFFITI_STACK_CAP, 1)], graffiti_test_art(min(position, unique_cap)), "graffiti_test", "Jane Doe")
	TEST_ASSERT_EQUAL(length(SSgraffiti.placements), GRAFFITI_CKEY_PLACEMENT_CAP, "An account must keep placements up to its cap.")
	var/oldest = SSgraffiti.unpack(SSgraffiti.placements[1])["pid"]
	var/next = SSgraffiti.unpack(SSgraffiti.placements[2])["pid"]
	SSgraffiti.add_placement(floors[tiles], art, "graffiti_test", "Jane Doe", "graffiti_test-more")
	SSgraffiti.save_now()
	var/list/data = json_decode(rustg_file_read(path))
	var/list/pids = list()
	for(var/list/placement as anything in data["placements"])
		pids[placement["pid"]] = TRUE
	TEST_ASSERT(length(pids) == GRAFFITI_CKEY_PLACEMENT_CAP && !pids[oldest] && pids[next] && pids["graffiti_test-more"], "A placement past an account's cap must evict its oldest from the file.")
	// The oldest's art goes with the change, so even at both caps it takes nothing.
	var/changed = SSgraffiti.update_placement_art(SSgraffiti.placements[1], graffiti_test_art(unique_cap + 1))
	TEST_ASSERT(SSgraffiti.placement_info[changed] && length(SSgraffiti.placements) == GRAFFITI_CKEY_PLACEMENT_CAP, "A placement must take new art, taking nothing when its old art goes with it.")
	// The next to last shares its art with the newest placements, so its change takes the account's oldest.
	var/list/evicted = list()
	var/arts = length(SSgraffiti.ckey_arts["graffiti_test"])
	var/shared = SSgraffiti.update_placement_art(SSgraffiti.placements[length(SSgraffiti.placements) - 1], graffiti_test_art(unique_cap + 2), evicted = evicted)
	TEST_ASSERT(SSgraffiti.placement_info[shared] && !SSgraffiti.placement_info[changed] && length(evicted) == 1 && length(SSgraffiti.ckey_arts["graffiti_test"]) == arts, "New art past an account's unique-art cap must take its oldest other placement: [length(evicted)] evicted, [length(SSgraffiti.ckey_arts["graffiti_test"])] of [arts] arts.")
	TEST_ASSERT(SSgraffiti.remove_placement(SSgraffiti.placements[2]), "A placement must be removed.")
	var/problem = graffiti_test_index_problem()
	TEST_ASSERT_NULL(problem, "After adding, evicting, changing and removing, the index must match the placements: [problem]")
	SSgraffiti.wipe_for_test()
	SSgraffiti.placement_cap = GRAFFITI_CKEY_PLACEMENT_CAP / 2
	SSgraffiti.load_file(path)
	problem = graffiti_test_index_problem()
	TEST_ASSERT(length(SSgraffiti.placements) == GRAFFITI_CKEY_PLACEMENT_CAP / 2 && isnull(problem), "A file past the placement cap must load up to it, indexed: [length(SSgraffiti.placements)] placements, [problem]")
	graffiti_registry_test_begin(path)
	for(var/position in 1 to GRAFFITI_STACK_CAP + 1)
		SSgraffiti.add_placement(floors[1], graffiti_test_art(position), "graffiti_test", "Jane Doe", "graffiti_test-layer-[position]")
	SSgraffiti.save_now()
	data = json_decode(rustg_file_read(path))
	var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(floors[1])
	TEST_ASSERT(length(decal?.stack) == GRAFFITI_STACK_CAP && graffiti_test_placement("graffiti_test-layer-1", SSgraffiti.placements) && length(data["placements"]) == GRAFFITI_STACK_CAP && data["placements"][1]["pid"] == "graffiti_test-layer-1", "A sixth piece on a tile must be refused, preserving the existing stack and file: [length(decal?.stack)] stacked, [length(data["placements"])] saved.")
	graffiti_registry_test_begin(path)
	SSgraffiti.placement_cap = 2
	SSgraffiti.seen["graffiti_old"] = "1792800000"
	SSgraffiti.seen["graffiti_new"] = "1792886400"
	SSgraffiti.add_placement(floors[1], graffiti_test_art(1), "graffiti_old", "Jane Doe", "graffiti_old-1")
	SSgraffiti.add_placement(floors[2], graffiti_test_art(2), "graffiti_new", "John Doe", "graffiti_new-1")
	var/result = SSgraffiti.add_placement(floors[3], graffiti_test_art(3), "graffiti_third", "Joe Doe", "graffiti_third-1")
	TEST_ASSERT(result in SSgraffiti.placements, "A placement past the map cap must evict rather than be refused: [result]")
	TEST_ASSERT(!graffiti_test_placement("graffiti_old-1", SSgraffiti.placements) && graffiti_test_placement("graffiti_new-1", SSgraffiti.placements), "The map cap must evict the lowest-ranked placement.")
	problem = graffiti_test_index_problem()
	TEST_ASSERT_NULL(problem, "After the map cap evicts, the index must match the placements: [problem]")
	SSgraffiti.placement_cap = GRAFFITI_MAP_PLACEMENT_CAP
	var/list/dense = graffiti_test_dense_art(1)
	// Bytes enough for the dense art only once Third's art goes.
	SSgraffiti.art_byte_budget = SSgraffiti.art_bytes - SSgraffiti.art_size(graffiti_test_art(3)) + SSgraffiti.art_size(dense)
	result = SSgraffiti.add_placement(floors[4], dense, "graffiti_fourth", "Jo Doe", "graffiti_fourth-1")
	TEST_ASSERT((result in SSgraffiti.placements) && !graffiti_test_placement("graffiti_third-1", SSgraffiti.placements) && graffiti_test_placement("graffiti_new-1", SSgraffiti.placements) && SSgraffiti.art_bytes <= SSgraffiti.art_byte_budget, "Art past the map's byte budget must evict the lowest-ranked placement until it fits: [result], [SSgraffiti.art_bytes] of [SSgraffiti.art_byte_budget] bytes.")
	SSgraffiti.save_now()
	SSgraffiti.wipe_for_test()
	// Room for New's art only, which outranks Fourth's: its owner was seen more recently.
	SSgraffiti.art_byte_budget = SSgraffiti.art_size(graffiti_test_art(2))
	SSgraffiti.load_file(path)
	TEST_ASSERT(graffiti_test_placement("graffiti_new-1", SSgraffiti.placements) && !graffiti_test_placement("graffiti_fourth-1", SSgraffiti.placements) && SSgraffiti.art_bytes <= SSgraffiti.art_byte_budget, "A file past the byte budget must load the best-ranked placements whose art fits: [length(SSgraffiti.placements)] placements, [SSgraffiti.art_bytes] of [SSgraffiti.art_byte_budget] bytes.")
	graffiti_registry_test_begin(path)
	SSgraffiti.seen["graffiti_old"] = "1792800000"
	SSgraffiti.seen["graffiti_new"] = "1792886400"
	var/stale = SSgraffiti.add_placement(floors[1], graffiti_test_art(1), "graffiti_old", "Jane Doe", "graffiti_old-1")
	var/growing = SSgraffiti.add_placement(floors[2], graffiti_test_art(2), "graffiti_new", "John Doe", "graffiti_new-1")
	// Bytes enough for the dense art once Old's art goes too, as New's own goes with the change.
	SSgraffiti.art_byte_budget = SSgraffiti.art_size(dense)
	growing = SSgraffiti.update_placement_art(growing, dense)
	TEST_ASSERT(SSgraffiti.placement_info[growing] && !SSgraffiti.placement_info[stale] && SSgraffiti.art_bytes <= SSgraffiti.art_byte_budget, "New art past the map's byte budget must evict the lowest-ranked placement until it fits: [growing], [SSgraffiti.art_bytes] of [SSgraffiti.art_byte_budget] bytes.")
	var/list/denser = graffiti_test_dense_art(2)
	SSgraffiti.art_byte_budget = SSgraffiti.art_size(denser) - 1
	result = SSgraffiti.update_placement_art(growing, denser)
	problem = graffiti_test_index_problem()
	TEST_ASSERT(istext(result) && !SSgraffiti.placement_info[result] && SSgraffiti.art_of(growing) == graffiti_art_hash(dense) && isnull(problem), "New art that can't fit, with nothing else to go, must be refused and the placement keep its art, indexed: [result], [problem]")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_caps/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * Loading packs every shown stack into sheet files that decals show from. A stack of several pieces loads under the key
 * the map file cached for it, without merging, and that key is the one merging gives. Loading the same stacks again
 * builds no sheet and reuses the same files, and a sheet file no stack uses is deleted.
 */
/datum/unit_test/graffiti_registry_sheets/Run()
	var/path = "data/graffiti_test/sheets.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_walls(2)
	TEST_ASSERT_EQUAL(length(turfs), 2, "The test room must have two walls side by side between floors.")
	SSgraffiti.add_placement(turfs[1], graffiti_test_art(1), "graffiti_test", "Jane Doe")
	SSgraffiti.add_placement(turfs[1], graffiti_test_art(2, 3), "graffiti_test", "Jane Doe")
	SSgraffiti.add_placement(turfs[2], graffiti_test_art(4, 4), "graffiti_test", "Jane Doe")
	SSgraffiti.save_now()
	SSgraffiti.wipe_for_test()
	SSgraffiti.load_file(path)
	SSgraffiti.place_all()
	var/obj/effect/decal/cleanable/crayon/custom/stacked = graffiti_tile_decal(turfs[1])
	TEST_ASSERT(stacked?.stack_key && isnull(stacked.render_cache["art"]), "A stack the map file cached must load under its cached key without being merged.")
	SSgraffiti.build_sheets()
	var/directory = "data/graffiti_test/sheets/[graffiti_file_key(SSmapping.current_map.map_name)]/"
	var/list/files = flist(directory)
	TEST_ASSERT(SSgraffiti.sheets_built && length(files) == SSgraffiti.sheets_built, "Each sheet built must be written to a file of its own: [json_encode(files)]")
	var/list/kinds = list()
	for(var/turf/wall as anything in turfs)
		var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(wall)
		var/list/sheet = SSgraffiti.sheet_for(decal?.stack_key)
		TEST_ASSERT(sheet && decal.icon == sheet[1] && decal.icon_state == decal.stack_key, "Each decal must show its stack from a sheet file.")
		var/key = decal.stack_key
		var/kind = decal.render_cache["kind"]
		kinds += kind
		// Merged again from the art itself rather than from the load's decoded art.
		decal.refresh(TRUE)
		TEST_ASSERT(decal.stack_key == key && decal.render_cache["kind"] == kind, "A stack loaded from its decoded art must hash and glow as it does decoded again.")
	TEST_ASSERT_EQUAL(json_encode(kinds), json_encode(list(GRAFFITI_GLOW_MIXED, GRAFFITI_GLOW_ALL)), "A loaded stack of plain and mixed paint must glow mixed, and one of lit paint all lit.")
	rustg_file_write("stale", "[directory]stale.dmi")
	SSgraffiti.wipe_for_test()
	SSgraffiti.load_file(path)
	SSgraffiti.place_all()
	SSgraffiti.build_sheets()
	TEST_ASSERT_EQUAL(SSgraffiti.sheets_built, 0, "Unchanged stacks must reuse their sheet files.")
	TEST_ASSERT_EQUAL(json_encode(flist(directory)), json_encode(files), "The same sheet files must be used, and the stale one deleted.")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_sheets/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * Returns a one-tile art painted on every pixel, no two neighbours alike, from forty colours, every other pixel glowing,
 * so its composite and glow mask take as many runs as a tile's art can. The same index gives the same art.
 *
 * Arguments:
 * - index: Which art.
 *
 * Returns:
 * - list: The art.
 */
/proc/graffiti_test_dense_art(index)
	var/list/palette = list()
	for(var/color_index in 1 to 40)
		palette += graffiti_color(rgb((color_index * 37 + index * 11) % 256, (color_index * 91 + index * 7) % 256, (color_index * 53 + index * 29) % 256))
	var/list/indices = list()
	var/list/glow = list()
	for(var/position in 1 to GRAFFITI_WIDTH * GRAFFITI_HEIGHT)
		indices += 1 + (position * 7 + index) % 40
		glow += (position + index) % 2
	return list("w" = GRAFFITI_WIDTH, "pal" = graffiti_palette_pack(palette), "grid" = graffiti_encode_flat(indices, 40), "glow" = graffiti_encode_flat(glow, 1))

/**
 * Returns tiles of the test room (graffiti_test_room()) that take graffiti under a station anchor, all in one of the
 * 16-tile chunks build_sheets() packs together, the same ones every call.
 *
 * Arguments:
 * - count: How many.
 *
 * Returns:
 * - list: `count` turfs of the first chunk that has that many, or an empty list when none has.
 */
/proc/graffiti_test_chunk_turfs(count)
	// Chunk key -> its turfs so far.
	var/list/chunks = list()
	for(var/turf/tile as anything in graffiti_test_room())
		if(!graffiti_surface_ok(tile) || graffiti_anchor_for(tile)?["kind"] != GRAFFITI_ANCHOR_STATION)
			continue
		var/key = "[tile.z]-[round(tile.y / 16)]-[round(tile.x / 16)]"
		var/list/turfs = chunks[key]
		if(!turfs)
			turfs = list()
			chunks[key] = turfs
		turfs += tile
		if(length(turfs) == count)
			return turfs
	return list()

/**
 * A chunk of detailed glowing graffiti loads into its sheets whole: every stack's composite and glow mask becomes a state
 * of its chunk's sheets, freshly drawn as a round's load draws them, and every decal shows from one.
 */
/datum/unit_test/graffiti_registry_sheet_chunk/Run()
	var/path = "data/graffiti_test/chunk.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_chunk_turfs(12)
	TEST_ASSERT_EQUAL(length(turfs), 12, "The test room must have 12 tiles that take graffiti in one 16-tile chunk.")
	// Written as a map file rather than placed, so no icon is drawn before the sheets are.
	var/list/arts = list()
	var/list/entries = list()
	for(var/position in 1 to length(turfs))
		var/list/art = graffiti_test_dense_art(position)
		var/hash = graffiti_art_hash(art)
		arts[hash] = art
		entries += list(list("anchor" = graffiti_anchor_for(turfs[position]), "art" = hash, "ckey" = "graffiti_test", "who" = "Jane Doe", "at" = "1792800000", "pid" = "graffiti_test-[position]", "half" = 0, "miss" = 0))
	rustg_file_write(json_encode(list("version" = GRAFFITI_MAP_VERSION, "art" = arts, "placements" = entries, "seen" = list())), path)
	SSgraffiti.load_file(path)
	SSgraffiti.place_all()
	var/failure
	try
		SSgraffiti.build_sheets()
	catch(var/exception/error)
		failure = "[error]"
	TEST_ASSERT_NULL(failure, "Building the sheets must not fail.")
	for(var/turf/left_tile as anything in turfs)
		var/obj/effect/decal/cleanable/crayon/custom/decal = graffiti_tile_decal(left_tile)
		var/list/sheet = SSgraffiti.sheet_for(decal?.stack_key)
		TEST_ASSERT(sheet && sheet[2], "Each dense glowing stack must be in a sheet with its glow mask: [AREACOORD(left_tile)]")
		var/list/states = icon_states(sheet[1])
		TEST_ASSERT((decal.stack_key in states) && ("[decal.stack_key]_g" in states), "A stack's sheet must hold its composite and its glow mask: [AREACOORD(left_tile)]")
		TEST_ASSERT(decal.icon == sheet[1] && decal.icon_state == decal.stack_key, "Each decal must show its stack from its sheet: [AREACOORD(left_tile)]")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_registry_sheet_chunk/Destroy()
	graffiti_registry_test_end()
	return ..()

/**
 * Graffiti goes only on the station as the map built it: a wall inside a map template loaded this round, such as a random
 * room, and a floor off the station levels take none, and a map file's placement in a map template is dropped as it
 * loads while one on the station stays.
 */
/datum/unit_test/graffiti_static_station_only/Run()
	var/path = "data/graffiti_test/static.json"
	graffiti_registry_test_begin(path)
	var/list/turfs = graffiti_test_walls(1)
	TEST_ASSERT_EQUAL(length(turfs), 1, "The test room must have a wall between two floors to paint.")
	var/turf/wall = turfs[1]
	var/list/station_anchor = graffiti_anchor_for(wall)
	var/list/entry = list("x" = wall.x - 1, "y" = wall.y - 1, "z" = wall.z, "w" = 3, "h" = 3)
	SSgraffiti.loaded_templates += list(entry)
	var/inside_ok = graffiti_surface_ok(wall)
	var/list/inside_anchor = graffiti_anchor_for(wall)
	SSgraffiti.loaded_templates -= list(entry)
	TEST_ASSERT(!inside_ok && isnull(inside_anchor), "A wall inside a loaded map template must take no graffiti.")
	var/list/centcom = SSmapping.levels_by_trait(ZTRAIT_CENTCOM)
	var/turf/open/floor/away = length(centcom) ? (locate(/turf/open/floor) in Z_TURFS(centcom[1])) : null
	TEST_ASSERT(away && graffiti_surface_kind(away) && !graffiti_surface_ok(away), "A floor off the station levels must take no graffiti.")
	var/list/art = graffiti_test_art(1)
	var/hash = graffiti_art_hash(art)
	var/list/arts = list()
	arts[hash] = art
	var/list/kept = list("anchor" = station_anchor, "art" = hash, "ckey" = "graffiti_test", "who" = "Jane Doe", "at" = "1792800000", "pid" = "graffiti_test-station", "half" = 0, "miss" = 0)
	var/list/dropped = kept.Copy()
	dropped["anchor"] = list("kind" = "template", "id" = "_maps/templates/graffiti_test.dmm", "dx" = 1, "dy" = 1, "z" = 1, "surface" = GRAFFITI_KIND_WALL)
	dropped["pid"] = "graffiti_test-template"
	rustg_file_write(json_encode(list("version" = GRAFFITI_MAP_VERSION, "art" = arts, "placements" = list(kept, dropped), "seen" = list())), path)
	SSgraffiti.load_file(path)
	TEST_ASSERT(graffiti_test_placement("graffiti_test-station", SSgraffiti.placements) && !graffiti_test_placement("graffiti_test-template", SSgraffiti.placements), "A map file's placement in a map template must be dropped as it loads, and one on the station kept.")

/**
 * Puts the registry back and deletes the test's files.
 */
/datum/unit_test/graffiti_static_station_only/Destroy()
	graffiti_registry_test_end()
	return ..()

#undef GRAFFITI_TEST_ROOM_WIDTH
#undef GRAFFITI_TEST_ROOM_HEIGHT
#undef GRAFFITI_TEST_ROOM_ROW
#undef GRAFFITI_TEST_ROOM_ROW_X
#undef GRAFFITI_TEST_ROOM_ROW_Y
