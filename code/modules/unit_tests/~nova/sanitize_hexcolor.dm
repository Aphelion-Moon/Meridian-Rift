/**
 * sanitize_hexcolor() hands canonical lowercase #rrggbb back untouched and sanitises everything else as it always has.
 *
 * Canonical input returns before the character loop, so this pins both sides of that shortcut: input that only looks
 * canonical, and the formats and crunch setting the shortcut must leave to the loop.
 */
/datum/unit_test/sanitize_hexcolor

/datum/unit_test/sanitize_hexcolor/Run()
	for(var/canonical in list("#000000", "#ffffff", "#4488cc", "#0a1b2c"))
		TEST_ASSERT_EQUAL(sanitize_hexcolor(canonical), canonical, "Canonical [canonical] must come back unchanged")
	var/list/sanitised = list(
		"#4488CC" = "#4488cc",
		"#4488Cc" = "#4488cc",
		"4488cc" = "#4488cc",
		"#48c" = "#4488cc",
		"#aabbcc\n" = "#aabbcc",
		"#12345g" = "#000000",
		"" = "#000000",
	)
	for(var/input, expected in sanitised)
		TEST_ASSERT_EQUAL(sanitize_hexcolor(input), expected, "[input] must still be sanitised")
	TEST_ASSERT_EQUAL(sanitize_hexcolor(null), "#000000", "A missing colour must fall back to black")
	TEST_ASSERT_EQUAL(sanitize_hexcolor("#12345g", default = "#010203"), "#010203", "An unreadable colour must fall back to the default given")
	TEST_ASSERT_EQUAL(sanitize_hexcolor("#4488cc", include_crunch = FALSE), "4488cc", "A canonical colour must lose its crunch when none is wanted")
	TEST_ASSERT_EQUAL(sanitize_hexcolor("#4488cc", desired_format = 3), "#48c", "A canonical colour must still shorten to three digits")
	TEST_ASSERT_EQUAL(sanitize_hexcolor("#4488cc", desired_format = 4), "#48cf", "A canonical colour must still gain an alpha digit")
