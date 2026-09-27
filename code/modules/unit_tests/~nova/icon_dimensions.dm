/**
 * get_icon_dimensions() sizes each runtime icon as itself, first time and cached alike, keeps a bounded number of them,
 * and measures an /icon datum afresh every time, since a datum can still change.
 */
/datum/unit_test/runtime_icon_dimensions

/datum/unit_test/runtime_icon_dimensions/Run()
	var/list/sizes = list("32x32" = list(32, 32), "64x32" = list(64, 32), "32x64" = list(32, 64))
	var/list/resources = list()
	for(var/size, dimensions in sizes)
		var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
		canvas.Scale(dimensions[1], dimensions[2])
		resources[size] = fcopy_rsc(canvas)
	// Twice round, so the second pass reads every size back from the cache.
	for(var/pass in 1 to 2)
		for(var/size, resource in resources)
			var/list/measured = get_icon_dimensions(resource)
			TEST_ASSERT_EQUAL("[measured["width"]]x[measured["height"]]", size, "A runtime icon must be sized as itself on pass [pass]")

	var/icon/changing = icon('icons/blanks/32x32.dmi', "nothing")
	changing.Scale(64, 64)
	var/list/before_change = get_icon_dimensions(changing)
	changing.Scale(32, 32)
	var/list/after_change = get_icon_dimensions(changing)
	TEST_ASSERT_EQUAL(before_change["width"], 64, "An /icon datum must be measured as it is")
	TEST_ASSERT_EQUAL(after_change["width"], 32, "An /icon datum must be measured again after it changes")

	// More distinct runtime icons than the cache holds: it must stop growing.
	var/grown_to
	for(var/count in 1 to 600)
		var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
		canvas.DrawBox(rgb(count % 256, round(count / 256), 1), 1, 1)
		get_icon_dimensions(fcopy_rsc(canvas))
		if(count == 300)
			grown_to = length(GLOB.runtime_icon_dimensions)
	TEST_ASSERT(grown_to < 300, "The runtime icon size cache must be bounded, it held [grown_to] after 300 icons")
	TEST_ASSERT_EQUAL(length(GLOB.runtime_icon_dimensions), grown_to, "The runtime icon size cache must stop growing at its bound")
