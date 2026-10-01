/// The bounded cache the sampled colours and the palettes are kept in drops its oldest entry first.
/datum/unit_test/bulge_cache_retention/Run()
	var/datum/bulge_bounded_cache/cache = allocate(/datum/bulge_bounded_cache/samples)
	cache.limit = 3
	cache.store_value("a", "#112233")
	cache.store_value("b", "#223344")
	cache.store_value("c", "#334455")
	TEST_ASSERT_EQUAL(cache.fetch("a"), "#112233", "Warm cache value changed.")
	cache.store_value("d", "#445566")
	TEST_ASSERT_NULL(cache.fetch("a"), "FIFO did not evict the oldest insertion.")
	TEST_ASSERT_EQUAL(length(cache.entries), 3, "Cache exceeded capacity.")
	TEST_ASSERT_EQUAL(length(cache.keys), 3, "FIFO exceeded capacity.")
	TEST_ASSERT_EQUAL(cache.store_value("a", "#112233"), "#112233", "Deterministic recompute changed the value.")
	TEST_ASSERT_EQUAL(length(cache.entries), 3, "Reinsertion exceeded capacity.")
	cache.clear()
	TEST_ASSERT_NULL(cache.entries, "Clear retained entries.")
	TEST_ASSERT_NULL(cache.keys, "Clear retained keys.")

/// The adaptive palette keeps the approved values: the float32 computation where it gives them, bulge_palette_exception()
/// where it is one off (#afafaf, #f4faff, #198019); one list per palette. The last three are garment colours where a
/// change to the arithmetic that looks harmless moves an approved colour (the N4b review's sweep: a reciprocal for a
/// division, a multiplication for a division, the builtin round): bulge_palette_hash checks every one.
/datum/unit_test/bulge_palette

/datum/unit_test/bulge_palette/Run()
	var/list/approved = list(
		"#afafaf|cloth" = list("#afafaf", "#c3c3c3", "#d2d2d2", "#888888", "#656565"),
		"#afafaf|denim" = list("#afafaf", "#bebebe", "#c9c9c9", "#888888", "#656565"),
		"#f4faff|cloth" = list("#f4faff", "#f7fbff", "#fafdff", "#bec3c7", "#8e9194"),
		"#198019|leather" = list("#198019", "#299029", "#359c35", "#146414", "#0f4a0f"),
		"#888888|cloth" = list("#888888", "#9c9c9c", "#ababab", "#6a6a6a", "#4f4f4f"),
		"#224488|denim" = list("#224488", "#405a8d", "#50699c", "#1b356a", "#14274f"),
		"#212729|leather" = list("#212729", "#2c3234", "#343a3c", "#1a1e20", "#131718"),
		"#34334b|denim" = list("#34334b", "#484759", "#555466", "#29283b", "#1e1e2c"),
		"#7f7d80|cloth" = list("#7f7d80", "#939194", "#a2a0a3", "#636264", "#4a484a"),
		"#a57d1f|denim" = list("#a57d1f", "#ab8d47", "#b69852", "#816218", "#604812"),
	)
	for(var/key, palette in approved)
		var/list/parts = splittext(key, "|")
		var/list/found = get_bulge_palette(parts[1], parts[2])
		TEST_ASSERT_EQUAL(length(found), 5, "The [parts[2]] palette of [parts[1]] has five colours")
		TEST_ASSERT_EQUAL(jointext(found, " "), jointext(palette, " "), "The [parts[2]] palette of [parts[1]]")
	var/list/result = get_bulge_palette("#afafaf", BULGE_FINISH_CLOTH)
	TEST_ASSERT(result == get_bulge_palette("#afafaf", BULGE_FINISH_CLOTH), "A palette is kept and shared")

/**
 * Every adaptive palette the approved ones were made for, against the approved values: the 4,096 colours of the grid in
 * steps of 17 and the 760 garment colours in bulge_palette_colours.txt, in every finish, one line each ("#rrggbb finish"
 * and the five colours), hashed and compared with the hash of the approved values. Those were computed outside the game
 * by the preview pipeline's own arithmetic (bulge_v4.adaptive(), in float64); the game computes them in float32 with
 * 38 exceptions (adaptive_colour.dm). A failure means a change moved approved garment colours: sweep the colours
 * against the preview pipeline's values, and keep the approved ones (as exceptions) or have mal approve the new.
 */
/datum/unit_test/bulge_palette_hash

/datum/unit_test/bulge_palette_hash/Run()
	var/list/colours = list()
	for(var/red = 0; red <= 255; red += 17)
		for(var/green = 0; green <= 255; green += 17)
			for(var/blue = 0; blue <= 255; blue += 17)
				colours += rgb(red, green, blue)
	for(var/line in splittext(file2text("code/modules/unit_tests/~nova/bulge_palette_colours.txt"), regex(@"\r?\n")))
		if(length(line))
			colours += line
	TEST_ASSERT_EQUAL(length(colours), 4856, "The grid and the garment colours")
	// Computed in a cache of their own, which drops nothing: the round's palettes are left as they were.
	var/datum/bulge_bounded_cache/kept = GLOB.bulge_palette_cache
	var/datum/bulge_bounded_cache/palettes/cache = allocate(/datum/bulge_bounded_cache/palettes)
	cache.limit = length(colours) * 3
	GLOB.bulge_palette_cache = cache
	var/list/lines = list()
	for(var/colour in colours)
		for(var/finish in list(BULGE_FINISH_CLOTH, BULGE_FINISH_DENIM, BULGE_FINISH_LEATHER))
			lines += "[colour] [finish] [jointext(get_bulge_palette(colour, finish), " ")]"
	GLOB.bulge_palette_cache = kept
	var/text = jointext(lines, "\n")
	var/hash = md5(text)
	if(hash != "a4d167bbf94dd87766cc3b249783dd95")
		rustg_file_write(text, "data/bulge_palette_lines.txt") // To compare, line by line, with the approved values.
		TEST_FAIL("The adaptive palettes of the approved colours hash to [hash], not to the approved values' a4d167bbf94dd87766cc3b249783dd95 \
			(the game's are in data/bulge_palette_lines.txt): a change to the palette's arithmetic moved approved garment colours.")
