/// random_string() joins one pick() per character, in order: the requested count, only the alphabet's entries (each whole,
/// however long), and nothing at all for no count.
/datum/unit_test/random_string

/datum/unit_test/random_string/Run()
	TEST_ASSERT_EQUAL(random_string(0, GLOB.hex_characters), "", "No characters asked for must give empty text")
	TEST_ASSERT_EQUAL(random_string(5, list("z")), "zzzzz", "A one-entry alphabet must repeat its entry once per character")
	TEST_ASSERT_EQUAL(random_string(3, list("ab")), "ababab", "An entry of several characters must be drawn whole")
	for(var/count in list(1, 3, 21, 32))
		var/drawn = random_string(count, GLOB.hex_characters)
		TEST_ASSERT_EQUAL(length(drawn), count, "random_string([count]) must give [count] characters")
		for(var/index in 1 to count)
			TEST_ASSERT(copytext(drawn, index, index + 1) in GLOB.hex_characters, "random_string([count]) drew [drawn], a character outside its alphabet")
