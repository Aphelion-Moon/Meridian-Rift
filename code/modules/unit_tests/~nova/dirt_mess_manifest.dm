/**
 * The dirt masks the game generates, against the reference generator's: every case of the corpus next to this file
 * (dirt_mess_corpus.json) is built as text by dirt_parity_case_block(), and its MD5 must match the case's line in the
 * manifest beside it (dirt_mess_manifest.txt), which the reference generator writes from the same corpus. A case is a
 * stream of random draws, a set of noise lattice points, or a set of masks in every direction, so a change that moves
 * one draw or one pixel fails here.
 *
 * Whenever a case differs, the text of every case is written to data/dirt_mess_masks.txt, to compare case by case
 * with the reference generator's.
 */
#define DIRT_MESS_CORPUS "code/modules/unit_tests/~nova/dirt_mess_corpus.json"
#define DIRT_MESS_MANIFEST "code/modules/unit_tests/~nova/dirt_mess_manifest.txt"
#define DIRT_MESS_MASKS_CURRENT "data/dirt_mess_masks.txt"

/datum/unit_test/dirt_mess_manifest
	// about 10 s: every case is generated, and the body cases rasterise mess on every level up to theirs
	priority = TEST_LONGER

/datum/unit_test/dirt_mess_manifest/Run()
	var/list/corpus = json_decode(file2text(DIRT_MESS_CORPUS) || "{}")
	TEST_ASSERT(length(corpus["cases"]), "[DIRT_MESS_CORPUS] is missing or has no cases.")
	var/list/digests = list()
	for(var/line in splittext(file2text(DIRT_MESS_MANIFEST) || "", regex(@"\r?\n")))
		if(length(line) && copytext(line, 1, 2) != "#")
			var/list/fields = splittext(line, " ")
			digests[fields[1]] = fields[2]
	var/list/blocks = list()
	var/list/changes = list()
	// a template takes about 90 ms to build, and every body case reuses one of four
	var/alist/templates = alist()
	for(var/list/case_data as anything in corpus["cases"])
		var/case_id = case_data["id"]
		var/block = dirt_parity_case_block(case_data, corpus, templates)
		if(isnull(block))
			changes += "unknown kind [case_data["kind"]]: [case_id]"
		else
			blocks += block
			if(isnull(digests[case_id]))
				changes += "new: [case_id]"
			else if(digests[case_id] != md5(block))
				changes += "changed: [case_id]"
		digests -= case_id
	for(var/case_id in digests)
		changes += "gone: [case_id]"
	if(!length(changes))
		return
	rustg_file_write(jointext(blocks, ""), DIRT_MESS_MASKS_CURRENT)
	var/shown = jointext(changes.Copy(1, min(length(changes), 40) + 1), "\n")
	TEST_FAIL("[length(changes)] case\s of the dirt masks differ from [DIRT_MESS_MANIFEST]:\n[shown]\n\
		Every case's text is in [DIRT_MESS_MASKS_CURRENT], to compare with the reference generator's.")

/**
 * Returns a corpus case as the text the reference generator writes for it: "case <id>", then the case's lines, each
 * ending in a newline, the last one too.
 * - random: one /datum/dirt_random stream per case, and one line per integer call. shuffle and sample write the list
 *   joined by single spaces; random, uniform and gauss spend their draws and write nothing.
 * - noise: round(hash * 255) per lattice point, list(x, y, seed).
 * - surface: the case's template built as the game builds a body's, and for each of S, N, E and W, "dir <letter>" and
 *   its three grids (dirt_parity_surface_lines()).
 * - body: mess on the case's template: for each direction, "dir <letter>" and one grid of roles, the case's splats
 *   each drawn by dirt_rasterise_aimed() on its "surface" (skin or cloth), packed and unpacked as a cached raster is
 *   (/datum/dirt_pixels/proc/drawn(), dirt_pixels_from_drawn()), then merged by dirt_merge(). Its
 *   "under_parts" and "over_parts", parts by name in the corpus's "parts", lowest drawn first, "name@N" only in the
 *   facings it names (dirt_parity_facing_parts()), shape it as they shape a surface's masks: each splat drawn at its
 *   level there (dirt_part_body_level()), then merged with them by dirt_merge_with_parts().
 * - part: one splat's mess on the case's part (dirt_part_field()), on its pixels as its "surface" takes it
 *   (dirt_part_own()), on the case's template: for each direction, "dir <letter>" and one grid of roles.
 * - taur_surface: a taur kind in the corpus's "taurs" under its rider, the case's template: for each direction,
 *   "dir <letter>" and one grid, 64 across, of what each pixel shows (dirt_taur_owners(), dirt_parity_taur_lines()).
 * - taur: a back shot's pools on a taur kind (dirt_taur_pools()), keeping clear of the shot on the rider's cloth and
 *   skin, packed and unpacked as cached pools are: for each direction, "dir <letter>" and one grid of roles, 64 across.
 *
 * Arguments:
 * - case_data: One entry of the corpus's "cases".
 * - corpus: The whole corpus, for the templates, parts and taurs a case names.
 * - templates: The templates built so far, by name, shared across cases.
 *
 * Returns:
 * - text: The case's text.
 * - null: The case's kind isn't one built here.
 */
/proc/dirt_parity_case_block(list/case_data, list/corpus, alist/templates)
	var/list/lines = list("case [case_data["id"]]")
	switch(case_data["kind"])
		if("random")
			lines += dirt_parity_random_lines(case_data)
		if("noise")
			for(var/list/point as anything in case_data["points"])
				lines += dirt_parity_number_text(round(dirt_noise_hash(point[1], point[2], point[3]) * 255, 1))
		if("surface")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				lines += "dir [letter]"
				lines += dirt_parity_surface_lines(template.surfaces[direction])
		if("body")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			// each part named once, in the order it's first listed
			var/list/named = list()
			for(var/entry in (case_data["under_parts"] || list()) + (case_data["over_parts"] || list()))
				var/list/fields = splittext(entry, "@")
				named[fields[1]] = TRUE
			var/list/all_sources = dirt_parity_parts(named, corpus)
			var/alist/by_name = alist()
			for(var/position in 1 to length(named))
				by_name[named[position]] = all_sources[position]
			var/list/splats = list()
			for(var/list/splat_data as anything in case_data["splats"])
				splats += new /datum/dirt_splat(splat_data[1], splat_data[2], splat_data[3], 0)
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/under = dirt_parity_facing_parts(case_data["under_parts"], letter, by_name)
				var/list/over = dirt_parity_facing_parts(case_data["over_parts"], letter, by_name)
				var/list/sources = under + over
				var/alist/owns = alist()
				for(var/datum/dirt_part_source/source as anything in sources)
					owns[source] = dirt_part_own(source, direction, template, all_sources, case_data["surface"])
				var/list/pixel_maps = list()
				for(var/datum/dirt_splat/splat as anything in splats)
					var/datum/dirt_pixels/raster = dirt_rasterise_aimed(splat.zone, dirt_part_body_level(splat, sources, owns), splat.variant, case_data["surface"], template.surfaces[direction])
					// packed and unpacked, as every raster SSdirt.rasters keeps is
					pixel_maps += dirt_pixels_from_drawn(raster.drawn(), raster.width, raster.height)
				var/datum/dirt_pixels/merged = length(sources) ? dirt_merge_with_parts(pixel_maps, splats, under, over, owns, direction) : dirt_merge(pixel_maps)
				lines += "dir [letter]"
				lines += merged.grid_text()
		if("part")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			var/list/named = dirt_parity_parts(list(case_data["part"]), corpus)
			var/datum/dirt_part_source/source = named[1]
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/own = dirt_part_own(source, direction, template, list(source), case_data["surface"])
				var/datum/dirt_pixels/field = dirt_part_field(source.kind, own, dirt_part_zone(source.kind), case_data["level"], case_data["variant"], direction)
				lines += "dir [letter]"
				lines += field.grid_text()
		if("taur_surface")
			var/datum/dirt_template/rider = dirt_parity_template(case_data["rider"], corpus, templates)
			var/datum/dirt_taur_source/taur_source = dirt_parity_taur(corpus["taurs"][case_data["taur"]])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				lines += "dir [letter]"
				lines += dirt_parity_taur_lines(dirt_taur_owners(taur_source, rider.surfaces[direction], direction))
		if("taur")
			var/datum/dirt_template/rider = dirt_parity_template(case_data["rider"], corpus, templates)
			var/datum/dirt_taur_source/taur_source = dirt_parity_taur(corpus["taurs"][case_data["taur"]])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/rider_mess = list()
				for(var/surface_kind in list(DIRT_SURFACE_CLOTH, DIRT_SURFACE_SKIN))
					var/datum/dirt_pixels/rider_drawn = dirt_rasterise_aimed(DIRT_ZONE_BACK, case_data["level"], case_data["variant"], surface_kind, rider.surfaces[direction])
					rider_mess += list(rider_drawn.drawn())
				var/datum/dirt_pixels/pools = dirt_taur_pools(dirt_taur_owners(taur_source, rider.surfaces[direction], direction), rider_mess, case_data["level"], case_data["variant"], direction)
				pools = dirt_pixels_from_drawn(pools.drawn(), DIRT_TAUR_WIDTH, ICON_SIZE_Y)
				lines += "dir [letter]"
				lines += pools.grid_text()
		else
			return null
	return jointext(lines, "\n") + "\n"

/**
 * Returns the parts a body case places under or over its surface in one facing: each entry of its "under_parts" or
 * "over_parts" is a part's name, placed so in every facing, or "name@NE", placed so in the facings it names.
 *
 * Arguments:
 * - entries: The case's "under_parts" or "over_parts", or null.
 * - letter: The facing: S, N, E or W.
 * - by_name: alist(name = /datum/dirt_part_source).
 */
/proc/dirt_parity_facing_parts(list/entries, letter, alist/by_name)
	RETURN_TYPE(/list)
	. = list()
	for(var/entry in entries)
		var/list/fields = splittext(entry, "@")
		if(length(fields) < 2 || findtext(fields[2], letter))
			. += by_name[fields[1]]

/**
 * Returns corpus parts as the game reads a genital: each a /datum/dirt_part_source of its states, every layer's
 * together, its sheet loaded from its path.
 *
 * Arguments:
 * - names: Names in the corpus's "parts", or null.
 * - corpus: The whole corpus.
 */
/proc/dirt_parity_parts(list/names, list/corpus)
	RETURN_TYPE(/list)
	. = list()
	for(var/name in names)
		var/list/part = corpus["parts"][name]
		. += new /datum/dirt_part_source(part["kind"], file(part["icon"]), part["states"], !!part["guide"])

/**
 * Returns what each pixel of a taur canvas shows as one grid, one line per row, one glyph per pixel: "B" the taur
 * body's behind layer, "A" its adjacent layer, "r" the rider, "U" its front under clothes layer, "F" its front layer,
 * "O" its front over layer, "." none.
 *
 * Arguments:
 * - owners: What each pixel shows, from dirt_taur_owners().
 */
/proc/dirt_parity_taur_lines(list/owners)
	RETURN_TYPE(/list)
	var/static/list/glyphs = list(EXTERNAL_BEHIND = "B", EXTERNAL_ADJACENT = "A", DIRT_TAUR_RIDER = "r", EXTERNAL_FRONT_UNDER_CLOTHES = "U", EXTERNAL_FRONT = "F", EXTERNAL_FRONT_OVER = "O")
	. = list()
	for(var/row in 0 to ICON_SIZE_Y - 1)
		var/list/glyph_row = list()
		for(var/column in 0 to DIRT_TAUR_WIDTH - 1)
			var/shown = owners[row * DIRT_TAUR_WIDTH + column + 1]
			glyph_row += shown ? glyphs[shown] : "."
		. += jointext(glyph_row, "")

/**
 * Returns a corpus taur kind as the game reads a taur body (/datum/dirt_taur_source): each layer's states, its sheet
 * loaded from its path.
 *
 * Arguments:
 * - taur: One entry of the corpus's "taurs".
 */
/proc/dirt_parity_taur(list/taur)
	RETURN_TYPE(/datum/dirt_taur_source)
	var/alist/layer_states = alist()
	for(var/layer_key, states in taur["layers"])
		layer_states[layer_key] = states
	return new /datum/dirt_taur_source(file(taur["icon"]), layer_states)

/**
 * Returns a corpus template, built as the game builds a body's the first time it's asked for and shared after that.
 *
 * Arguments:
 * - name: The template's name in the corpus's "templates".
 * - corpus: The whole corpus.
 * - templates: The templates built so far, by name. A new one is added to it.
 */
/proc/dirt_parity_template(name, list/corpus, alist/templates)
	RETURN_TYPE(/datum/dirt_template)
	var/datum/dirt_template/template = templates[name]
	if(!template)
		template = dirt_build_template_now(dirt_parity_zone_sources(corpus["templates"][name]))
		templates[name] = template
	return template

/**
 * Returns a corpus template as the zone sources dirt_zone_sources() gives a body: each zone's sheet, loaded from its
 * path, and state, the eyes' sheet and states, and whether the head is a human's.
 *
 * Arguments:
 * - template: One entry of the corpus's "templates".
 */
/proc/dirt_parity_zone_sources(list/template)
	var/alist/zone_sources = alist()
	for(var/zone, source in template["zones"])
		zone_sources[zone] = list(file(source[1]), source[2])
	var/list/eyes = template["eyes"]
	if(eyes)
		zone_sources["eyes"] = list(file(eyes[1]), eyes[2], eyes[3])
	zone_sources["human_head"] = !!template["human_head"]
	return zone_sources

/**
 * Returns one direction of a surface as three grids, one line per row, one after the other:
 * - limbs: the limb each pixel maps to, by DIRT_LIMB_* code: H head, T torso, A right arm, a left arm, L right leg,
 *   l left leg, or "." for none.
 * - rim: "#" the rim, "o" the interior (the body's pixels off the rim), "." neither.
 * - guards: "E" an eye or its sides, "m" the mouth, "e" an eye's diagonal, "." none.
 *
 * Arguments:
 * - surface: The surface.
 */
/proc/dirt_parity_surface_lines(datum/dirt_surface/surface)
	var/list/lines = list()
	for(var/grid in 1 to 3)
		for(var/row in 0 to surface.height - 1)
			var/line = ""
			for(var/column in 0 to surface.width - 1)
				var/index = row * surface.width + column + 1
				var/flags = surface.flags_of[index]
				switch(grid)
					if(1)
						var/limb = DIRT_PIXEL_LIMB(flags)
						line += limb ? copytext("HTAaLl", limb, limb + 1) : "."
					if(2)
						line += (flags & DIRT_PIXEL_RIM) ? "#" : (DIRT_PIXEL_ZONE(flags) ? "o" : ".")
					if(3)
						line += surface.face_guard[index] == DIRT_GUARD_EYE ? "E" : (surface.face_guard[index] == DIRT_GUARD_MOUTH ? "m" : (surface.eye_soft[index] ? "e" : "."))
			lines += line
	return lines

/**
 * Returns a random case's lines: one per integer call, in order, all from one stream.
 *
 * Arguments:
 * - case_data: One random entry of the corpus's "cases": its "seed", and its "calls", each a list of the call's name
 *   and its arguments.
 *
 * Crashes:
 * - On a call this proc doesn't know.
 */
/proc/dirt_parity_random_lines(list/case_data)
	var/datum/dirt_random/stream = new(case_data["seed"])
	var/list/lines = list()
	for(var/list/call_data as anything in case_data["calls"])
		switch(call_data[1])
			if("draw")
				lines += dirt_parity_number_text(stream.draw())
			if("random")
				stream.random()
			if("uniform")
				stream.uniform(call_data[2], call_data[3])
			if("gauss")
				stream.gauss(call_data[2], call_data[3])
			if("randrange")
				lines += dirt_parity_number_text(stream.randrange(call_data[2]))
			if("randint")
				lines += dirt_parity_number_text(stream.randint(call_data[2], call_data[3]))
			if("choose")
				lines += dirt_parity_number_text(stream.choose(call_data[2]))
			if("shuffle")
				var/list/items = call_data[2]
				lines += dirt_parity_number_text(stream.shuffle(items.Copy()))
			if("sample")
				lines += dirt_parity_number_text(stream.sample(call_data[2], call_data[3]))
			else
				CRASH("Unknown random call in the dirt parity corpus: [call_data[1]]")
	return lines

/**
 * Returns a number, or a list of numbers joined by single spaces, as the reference writes them: whole numbers in full,
 * never in scientific notation.
 *
 * Arguments:
 * - value: A number, or a list of numbers.
 */
/proc/dirt_parity_number_text(value)
	if(!islist(value))
		return num2text(value, 12)
	var/list/numbers = list()
	for(var/number in value)
		numbers += num2text(number, 12)
	return jointext(numbers, " ")

#undef DIRT_MESS_CORPUS
#undef DIRT_MESS_MANIFEST
#undef DIRT_MESS_MASKS_CURRENT
