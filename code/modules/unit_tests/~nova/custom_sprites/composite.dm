/// A drawing with the same pixels in every view. Points are list(x, y, "#rrggbb").
/proc/custom_sprite_test_region_drawing(list/points, width = 32, tint = null)
	var/list/palette = list()
	var/list/cells = list()
	for(var/position in 1 to width * 32)
		cells += "0"
	for(var/list/point as anything in points)
		var/index = palette.Find(point[3])
		if(!index)
			palette += point[3]
			index = length(palette)
		cells[point[2] * width + point[1] + 1] = copytext(CUSTOM_SPRITE_INDEX_ALPHABET, index + 1, index + 2)
	var/grid = jointext(cells, "")
	var/list/directions = list()
	for(var/direction in GLOB.custom_style_directions)
		directions[direction] = custom_sprite_encode_grid(grid, length(palette), width * 32)
	return list("version" = custom_sprite_version(width, length(palette)), "palette" = palette, "tint" = tint, "dirs" = directions, "emissive" = custom_sprite_emissive_settings(FALSE))

/// A region map whose first row is `first_row` (padded with "0") in every view; every other row is empty.
/proc/custom_sprite_test_region_rows(first_row, width = 32)
	var/list/rows = list(first_row + repeat_string(width - length(first_row), "0"))
	for(var/y in 2 to 32)
		rows += repeat_string(width, "0")
	. = list()
	for(var/direction in GLOB.custom_style_directions)
		.[direction] = rows.Copy()

/// Chest owns x 0-3, the left arm 4-7 and the left hand 8-9 on the first row.
/proc/custom_sprite_test_region_fixture()
	var/list/zones = list(BODY_ZONE_CHEST, BODY_ZONE_L_ARM, BODY_ZONE_PRECISE_L_HAND)
	var/list/map = custom_sprite_test_region_rows("1111222233")
	var/list/drawings = list(
		BODY_ZONE_CHEST = custom_sprite_test_region_drawing(list(list(0, 0, "#ff0000"), list(5, 0, "#0000ff"), list(20, 0, "#00ffff"))),
		BODY_ZONE_L_ARM = custom_sprite_test_region_drawing(list(list(4, 0, "#00ff00"), list(8, 0, "#ffff00"))),
		BODY_ZONE_PRECISE_L_HAND = custom_sprite_test_region_drawing(list(list(9, 0, "#ffffff"))),
	)
	return list("zones" = zones, "map" = map, "drawings" = drawings)

/datum/unit_test/custom_sprite_compose_regions/Run()
	var/list/fixture = custom_sprite_test_region_fixture()
	var/list/frames = custom_sprite_compose_regions(fixture["drawings"], fixture["map"], fixture["zones"], 32)
	var/list/row = frames["2"][1]
	TEST_ASSERT(row[1] == "#ff0000ff", "A region's own paint shows on the pixels it owns.")
	TEST_ASSERT(row[5] == "#00ff00ff", "The arm's paint shows on arm pixels.")
	TEST_ASSERT(row[6] == "#00000000", "Torso paint under the arm is hidden, as in game.")
	TEST_ASSERT(row[9] == "#ffff00ff", "Arm paint shows on a hand pixel where the hand has none.")
	TEST_ASSERT(row[10] == "#ffffffff", "A hand's own paint shows on its pixels.")
	TEST_ASSERT(row[21] == "#00000000", "Paint outside every region isn't shown.")
	var/list/split = custom_sprite_split_regions(frames, deep_copy_list(frames), fixture["drawings"], fixture["map"], fixture["zones"], 32)
	for(var/zone in fixture["zones"])
		TEST_ASSERT(!(split[zone]["changed"] || split[zone]["drawing"] != fixture["drawings"][zone]), "An unedited canvas must hand back every saved drawing untouched.")

/datum/unit_test/custom_sprite_split_keeps_unedited_paint/Run()
	var/list/fixture = custom_sprite_test_region_fixture()
	var/list/baseline = custom_sprite_compose_regions(fixture["drawings"], fixture["map"], fixture["zones"], 32)
	var/list/frames = deep_copy_list(baseline)
	// Paint over the hidden torso pixel: the arm owns it.
	frames["2"][1][6] = "#ff00ffff"
	var/list/split = custom_sprite_split_regions(frames, baseline, fixture["drawings"], fixture["map"], fixture["zones"], 32)
	TEST_ASSERT(split[BODY_ZONE_L_ARM]["changed"], "The owner of an edited pixel must change.")
	TEST_ASSERT(!split[BODY_ZONE_CHEST]["changed"], "Paint hidden under a different limb must survive an edit covering it.")
	TEST_ASSERT(split[BODY_ZONE_CHEST]["drawing"] == fixture["drawings"][BODY_ZONE_CHEST], "An untouched region must keep its saved drawing byte for byte, stranded paint included.")
	TEST_ASSERT(!split[BODY_ZONE_PRECISE_L_HAND]["changed"], "Regions nobody edited must not change.")
	var/list/arm = custom_sprite_drawing_pixels(split[BODY_ZONE_L_ARM]["drawing"], 32)
	TEST_ASSERT(!(arm["2"][6] != "#ff00ff" || arm["2"][5] != "#00ff00" || arm["2"][9] != "#ffff00"), "The arm must gain the edit and keep its other paint.")
	// Changing a pixel and changing it back isn't an edit.
	frames["2"][1][6] = baseline["2"][1][6]
	split = custom_sprite_split_regions(frames, baseline, fixture["drawings"], fixture["map"], fixture["zones"], 32)
	TEST_ASSERT(!split[BODY_ZONE_L_ARM]["changed"], "A pixel restored to its baseline value is not an edit.")

/datum/unit_test/custom_sprite_split_shared_surface/Run()
	var/list/fixture = custom_sprite_test_region_fixture()
	var/list/baseline = custom_sprite_compose_regions(fixture["drawings"], fixture["map"], fixture["zones"], 32)
	var/list/frames = deep_copy_list(baseline)
	// The hand owns x 8, where the arm's yellow shows through.
	frames["2"][1][9] = "#00ffffff"
	var/list/split = custom_sprite_split_regions(frames, baseline, fixture["drawings"], fixture["map"], fixture["zones"], 32)
	var/list/hand = custom_sprite_drawing_pixels(split[BODY_ZONE_PRECISE_L_HAND]["drawing"], 32)
	var/list/arm = custom_sprite_drawing_pixels(split[BODY_ZONE_L_ARM]["drawing"], 32)
	TEST_ASSERT(hand["2"][9] == "#00ffff", "An edited hand pixel goes to the hand.")
	TEST_ASSERT(!(arm["2"][9] || !split[BODY_ZONE_L_ARM]["changed"]), "The arm's paint under an edited hand pixel must be cleared so it can't show through.")
	// Erasing every hand pixel in every view empties it.
	for(var/direction in GLOB.custom_style_directions)
		frames[direction][1][9] = "#00000000"
		frames[direction][1][10] = "#00000000"
	split = custom_sprite_split_regions(frames, baseline, fixture["drawings"], fixture["map"], fixture["zones"], 32)
	TEST_ASSERT(!(!split[BODY_ZONE_PRECISE_L_HAND]["changed"] || split[BODY_ZONE_PRECISE_L_HAND]["drawing"]), "Erasing every pixel of a region saves it as unmarked.")

/datum/unit_test/custom_sprite_compose_tint/Run()
	var/list/zones = list(BODY_ZONE_CHEST)
	// x 2 is part of the torso but unpainted, so the edit below lands inside the region.
	var/list/map = custom_sprite_test_region_rows("111")
	var/list/drawings = list(BODY_ZONE_CHEST = custom_sprite_test_region_drawing(list(list(0, 0, "#ffffff"), list(1, 0, "#808080")), tint = "#ff0000"))
	var/list/baseline = custom_sprite_compose_regions(drawings, map, zones, 32)
	TEST_ASSERT(baseline["2"][1][1] == "[custom_sprite_tint_color("#ffffff", "#ff0000")]ff", "The canvas must show a legacy tint baked into the colors.")
	var/list/frames = deep_copy_list(baseline)
	frames["2"][1][3] = "#123456ff"
	var/list/split = custom_sprite_split_regions(frames, baseline, drawings, map, zones, 32)
	var/list/result = split[BODY_ZONE_CHEST]["drawing"]
	var/list/pixels = custom_sprite_drawing_pixels(result, 32)
	TEST_ASSERT(!(result["tint"] || pixels["2"][2] != custom_sprite_tint_color("#808080", "#ff0000")), "Re-encoding a tinted region must bake its tint so untouched pixels look the same.")

/datum/unit_test/custom_sprite_compose_wide/Run()
	var/list/zones = list(BODY_ZONE_CHEST, CUSTOM_MARKING_ZONE_TAUR)
	var/list/map = custom_sprite_test_region_rows(repeat_string(16, "2") + "11", CUSTOM_SPRITE_TAUR_WIDTH)
	var/list/drawings = list(
		BODY_ZONE_CHEST = custom_sprite_test_region_drawing(list(list(0, 0, "#ff0000"))),
		CUSTOM_MARKING_ZONE_TAUR = custom_sprite_test_region_drawing(list(list(0, 0, "#00ff00")), CUSTOM_SPRITE_TAUR_WIDTH),
	)
	var/list/frames = custom_sprite_compose_regions(drawings, map, zones, CUSTOM_SPRITE_TAUR_WIDTH)
	TEST_ASSERT(!(frames["2"][1][17] != "#ff0000ff" || frames["2"][1][1] != "#00ff00ff"), "Ordinary regions sit in the central 32 columns of a wide canvas.")
	var/list/edited = deep_copy_list(frames)
	edited["2"][1][18] = "#0000ffff"
	var/list/split = custom_sprite_split_regions(edited, frames, drawings, map, zones, CUSTOM_SPRITE_TAUR_WIDTH)
	var/list/chest = split[BODY_ZONE_CHEST]["drawing"]
	TEST_ASSERT(!(custom_sprite_width(chest) != 32 || custom_sprite_drawing_pixels(chest, 32)["2"][2] != "#0000ff"), "Ordinary regions save 32-wide from the central columns.")

/datum/unit_test/custom_sprite_split_color_limit/Run()
	var/list/zones = list(BODY_ZONE_CHEST)
	var/list/map = custom_sprite_test_region_rows(repeat_string(32, "1"))
	var/list/points = list()
	for(var/x in 0 to 31)
		points += list(list(x, 0, rgb(x + 1, 0, 0)))
	var/list/drawings = list(BODY_ZONE_CHEST = custom_sprite_test_region_drawing(points))
	var/list/baseline = custom_sprite_compose_regions(drawings, map, zones, 32)
	var/list/frames = deep_copy_list(baseline)
	for(var/direction in GLOB.custom_style_directions)
		for(var/x in 1 to 32)
			frames[direction][1][x] = "[rgb(0, x + 100, direction == "2" ? 0 : 10)]ff"
	var/list/split = custom_sprite_split_regions(frames, baseline, drawings, map, zones, 32)
	TEST_ASSERT(split[BODY_ZONE_CHEST]["error"], "A region needing more than [CUSTOM_SPRITE_MAX_COLORS] colors must report an error instead of a drawing.")
