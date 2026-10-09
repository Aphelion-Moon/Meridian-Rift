/**
 * Native ownership proof for H1. Requires the H1 production candidate.
 * The three globals are replaced only for this test and restored in Destroy(), including an assertion's early return.
 * No Python ownership model substitutes for these native /icon, /image, cache and refcount operations.
 */
/datum/unit_test/bulge_perf_h1_owned_dimensions
	var/list/saved_owner_cache
	var/alist/saved_dimensions
	var/alist/saved_references
	var/isolated_globals = FALSE

/datum/unit_test/bulge_perf_h1_owned_dimensions/Destroy()
	if(isolated_globals)
		// Restore the exact old containers; test icons/lists then lose their isolated global roots.
		GLOB.masked_leg_icons_cache = saved_owner_cache
		GLOB.owned_masked_leg_icon_dimensions = saved_dimensions
		GLOB.owned_masked_leg_icon_references = saved_references
		saved_owner_cache = null
		saved_dimensions = null
		saved_references = null
		isolated_globals = FALSE
	return ..()

/datum/unit_test/bulge_perf_h1_owned_dimensions/proc/sized_icon(width, height)
	var/icon/result = icon('icons/blanks/32x32.dmi', "nothing")
	result.Scale(width, height)
	return result

/datum/unit_test/bulge_perf_h1_owned_dimensions/proc/check_dimensions(icon/owned_icon, width, height, context)
	var/list/dimensions = GLOB.owned_masked_leg_icon_dimensions[owned_icon]
	if(isnull(dimensions))
		TEST_FAIL("[context]: no ownership-scoped dimensions for the exact native icon key")
		return FALSE
	if(dimensions["width"] != width || dimensions["height"] != height)
		TEST_FAIL("[context]: expected [width]x[height], got [dimensions["width"]]x[dimensions["height"]]")
		return FALSE
	return TRUE

/datum/unit_test/bulge_perf_h1_owned_dimensions/Run()
	saved_owner_cache = GLOB.masked_leg_icons_cache
	saved_dimensions = GLOB.owned_masked_leg_icon_dimensions
	saved_references = GLOB.owned_masked_leg_icon_references
	GLOB.masked_leg_icons_cache = list()
	GLOB.owned_masked_leg_icon_dimensions = alist()
	GLOB.owned_masked_leg_icon_references = alist()
	isolated_globals = TRUE

	var/icon/first = sized_icon(47, 53)
	var/icon/second = sized_icon(67, 41)
	var/icon/third = sized_icon(19, 73)
	set_owned_masked_leg_icons("alias", list(first, first))
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first], 2, "Two slots of the same icon retain twice")
	TEST_ASSERT(check_dimensions(first, 47, 53, "non32 alias"), "Final native dimensions must be exact")
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_dimensions), 2, "One dynamic icon has original and resource alias entries")
	var/list/first_dimensions = GLOB.owned_masked_leg_icon_dimensions[first]
	var/first_file = first_dimensions["canonical_file"]
	TEST_ASSERT(isfile(first_file), "Published canonical alias is an actual native resource file")
	TEST_ASSERT(first_file != first, "Dynamic original and renderer file are distinct native keys")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_dimensions[first_file], first_dimensions, "Both keys share one logical dimensions row")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 2, "Repeated slots retain the resource alias twice")
	for(var/replacement in 1 to 16)
		set_owned_masked_leg_icons("alias", list(first, first))
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first], 2, "Same-key replacement does not leak slot references")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_dimensions[first], first_dimensions, "Same-key replacement retains metadata identity")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_dimensions[first_file], first_dimensions, "Same-key replacement retains the resource row")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 2, "Same-key replacement does not leak resource alias references")

	set_owned_masked_leg_icons("shared", list(first, second))
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first], 3, "Distinct owners share slot references")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[second], 1, "The other icon is retained once")
	var/second_file = GLOB.owned_masked_leg_icon_dimensions[second]["canonical_file"]
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 3, "Distinct owners share resource slot references")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[second_file], 1, "The second resource alias is retained once")

	// Characterize content dedup independently; ownership works whether native resource files share or differ.
	var/icon/equivalent_original = icon(first)
	var/image/equivalent_appearance = image(equivalent_original)
	var/equivalent_file = equivalent_appearance.icon
	set_owned_masked_leg_icons("equivalent", list(equivalent_original, equivalent_original))
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[equivalent_original], 2, "Independent dynamic original retains its two slots")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[equivalent_file], equivalent_file == first_file ? 5 : 2, "Native file alias references include every sharing original")
	TEST_ASSERT(check_dimensions(equivalent_file, 47, 53, "equivalent file alias"), "Equivalent original has exact renderer dimensions")
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_dimensions), equivalent_file == first_file ? 5 : 6, "Physical aliases are bounded by two per distinct original")
	if(equivalent_file == first_file)
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_dimensions[equivalent_original], first_dimensions, "Native shared file reuses its logical dimensions row")
	world.log << "H1 owned dimensions: equivalent originals share a native file=[equivalent_file == first_file]"
	set_owned_masked_leg_icons("equivalent", null)
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[equivalent_original], "Eviction removes only the independent original key")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[equivalent_original], "Eviction removes independent original references")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 3, "Eviction preserves file references owned by the other entries")
	if(equivalent_file != first_file)
		TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[equivalent_file], "Last distinct file alias is released")
		TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[equivalent_file], "Last distinct file references are released")
	set_owned_masked_leg_icons("alias", list(third, first))
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first], 2, "Retain before release preserves a replacement alias")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[third], 1, "Replacement icon is registered")
	TEST_ASSERT(check_dimensions(third, 19, 73, "replacement"), "Replacement keeps non32 dimensions")
	var/third_file = GLOB.owned_masked_leg_icon_dimensions[third]["canonical_file"]
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 2, "Retain-before-release preserves shared resource aliases")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[third_file], 1, "Replacement resource alias is registered")
	set_owned_masked_leg_icons("shared", null)
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first], 1, "Evicting one owner preserves another owner")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[second], "Last second-icon slot is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[second], "Released icon metadata is removed")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[first_file], 1, "Remaining owner retains its resource alias")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[second_file], "Last second resource alias is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[second_file], "Last second resource references are released")
	set_owned_masked_leg_icons("alias", null)
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[first], "Last first-icon owner is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[third], "Last replacement-icon owner is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[first_file], "Last first resource alias is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[third_file], "Last replacement resource alias is released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[first_file], "Last first resource references are released")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[third_file], "Last replacement resource references are released")

	// An externally held runtime icon still works through the unchanged dimensions helper after eviction.
	var/list/fallback = get_icon_dimensions(first)
	TEST_ASSERT_EQUAL(fallback["width"], 47, "Evicted external reference uses native fallback width")
	TEST_ASSERT_EQUAL(fallback["height"], 53, "Evicted external reference uses native fallback height")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[first], "Fallback must not re-own arbitrary icons")
	first.Scale(69, 35) // Mutation is legal only after eviction; never mutate a published owned icon.
	fallback = get_icon_dimensions(first)
	TEST_ASSERT_EQUAL(fallback["width"], 69, "Mutation after eviction is measured afresh")
	TEST_ASSERT_EQUAL(fallback["height"], 35, "Mutation after eviction is measured afresh")
	set_owned_masked_leg_icons("mutated", list(first, second))
	TEST_ASSERT(check_dimensions(first, 69, 35, "mutation republication"), "Republishing registers the finalized new dimensions")
	var/mutated_file = GLOB.owned_masked_leg_icon_dimensions[first]["canonical_file"]
	TEST_ASSERT(mutated_file != first_file, "Post-eviction mutation obtains a new native immutable resource")
	TEST_ASSERT(check_dimensions(mutated_file, 69, 35, "mutated file alias"), "New renderer key has the changed finalized dimensions")
	TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[first_file], "Republishing does not re-own the stale pre-mutation resource")
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[mutated_file], 1, "Mutation republication retains the new resource once")
	set_owned_masked_leg_icons("clear_alias", list(first, first))
	TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[mutated_file], 3, "Clear fixture includes shared resource aliases")
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_dimensions), 4, "Two different-size originals own exactly four physical alias keys")
	clear_owned_masked_leg_icons()
	TEST_ASSERT_EQUAL(length(GLOB.masked_leg_icons_cache), 0, "Clear visits every copied owner key")
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_dimensions), 0, "Clear releases every distinct metadata entry")
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_references), 0, "Clear releases aliased slot references")

	// Critical consumer boundary: an actual leg returns images, whose .icon readbacks must hit H1.
	// One existing leg atom type is owned by allocate(); no atom subtype or extra human is introduced.
	var/obj/item/bodypart/leg/left/leg = allocate(__IMPLIED_TYPE__)
	TEST_ASSERT_NOTNULL(leg, "The actual leg producer fixture must exist")
	var/icon/non32 = sized_icon(47, 53)
	var/image/source = image(non32, "")
	var/list/drawn = call(leg, "handle_masking")(source) // A protected proc: called by name, as only a test calls it.
	TEST_ASSERT_EQUAL(length(drawn), 2, "The real producer returns upper and lower appearances")
	TEST_ASSERT_EQUAL(length(GLOB.masked_leg_icons_cache), 1, "The real producer publishes one owner pair")
	var/producer_key
	var/list/producer_icons
	for(var/cache_key, cache_entry in GLOB.masked_leg_icons_cache)
		producer_key = cache_key
		producer_icons = cache_entry
	TEST_ASSERT_EQUAL(length(producer_icons), 2, "The real owner contains two final icon slots")
	var/list/sizes = list()
	for(var/index in 1 to 2)
		var/image/appearance_entry = drawn[index]
		var/icon/readback = appearance_entry.icon
		TEST_ASSERT_NOTNULL(GLOB.owned_masked_leg_icon_dimensions[readback], "Returned appearance.icon must hit the actual H1 lookup key")
		TEST_ASSERT(isfile(readback), "Real producer readback is the native renderer resource")
		TEST_ASSERT(!isfile(producer_icons[index]), "Producer owner retains the original dynamic icon")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_dimensions[readback], GLOB.owned_masked_leg_icon_dimensions[producer_icons[index]], "Producer original and file share exact metadata")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[readback], 1, "Producer resource is retained by its actual slot")
		var/icon/measured = icon(readback)
		var/width = measured.Width()
		var/height = measured.Height()
		TEST_ASSERT(width != 32 || height != 32, "Actual non32 producer outputs must remain non32")
		TEST_ASSERT(check_dimensions(readback, width, height, "actual producer readback"), "Dimensions are measured after both native blends")
		sizes += list(list(width, height))

	var/list/cached = call(leg, "handle_masking")(source)
	TEST_ASSERT_EQUAL(GLOB.masked_leg_icons_cache[producer_key], producer_icons, "A real cache hit reuses the owner pair")
	for(var/index in 1 to 2)
		var/image/appearance_entry = cached[index]
		TEST_ASSERT_EQUAL(appearance_entry.icon, GLOB.owned_masked_leg_icon_dimensions[producer_icons[index]]["canonical_file"], "A real cache hit returns the registered native file alias")
		TEST_ASSERT(appearance_entry.icon != producer_icons[index], "Cache hit preserves native dynamic-icon to file conversion")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[appearance_entry.icon], 1, "Cache hits do not republish or increment resource ownership")
		TEST_ASSERT_EQUAL(GLOB.owned_masked_leg_icon_references[producer_icons[index]], 1, "Cache hits do not republish or increment ownership")
		var/list/size = sizes[index]
		TEST_ASSERT(check_dimensions(appearance_entry.icon, size[1], size[2], "actual cache hit"), "Image readback remains an H1 hit")
	set_owned_masked_leg_icons(producer_key, null)
	for(var/index in 1 to 2)
		var/image/appearance_entry = drawn[index]
		TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[appearance_entry.icon], "Held image survives eviction without stale metadata")
		TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_dimensions[producer_icons[index]], "Eviction also removes the original producer key")
		TEST_ASSERT_NULL(GLOB.owned_masked_leg_icon_references[appearance_entry.icon], "Eviction removes the held resource metadata ownership")
		var/list/size = sizes[index]
		fallback = get_icon_dimensions(appearance_entry.icon)
		TEST_ASSERT_EQUAL(fallback["width"], size[1], "Held image fallback has the finalized native width")
		TEST_ASSERT_EQUAL(fallback["height"], size[2], "Held image fallback has the finalized native height")
	clear_owned_masked_leg_icons()
	TEST_ASSERT_EQUAL(length(GLOB.owned_masked_leg_icon_dimensions), 0, "Final explicit clear leaves no test metadata")
