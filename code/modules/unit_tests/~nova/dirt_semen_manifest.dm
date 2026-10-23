/**
 * The dirt masks the game generates, against the reference generator's: every case of the corpus next to this file
 * (dirt_semen_corpus.json) is built as text by dirt_parity_case_block(), and its MD5 must match the case's line in the
 * manifest beside it (dirt_semen_manifest.txt), which the reference generator writes from the same corpus. A case is a
 * stream of random draws, a set of noise lattice points, or a set of masks in every direction, so a change that moves
 * one draw or one pixel fails here.
 *
 * Whenever a case differs, the text of every case is written to data/dirt_semen_masks.txt, to compare case by case
 * with the reference generator's.
 */
#define DIRT_SEMEN_CORPUS "code/modules/unit_tests/~nova/dirt_semen_corpus.json"
#define DIRT_SEMEN_MANIFEST "code/modules/unit_tests/~nova/dirt_semen_manifest.txt"
#define DIRT_SEMEN_MASKS_CURRENT "data/dirt_semen_masks.txt"

/datum/unit_test/dirt_semen_manifest

/datum/unit_test/dirt_semen_manifest/Run()
	var/list/corpus = json_decode(file2text(DIRT_SEMEN_CORPUS) || "{}")
	TEST_ASSERT(length(corpus["cases"]), "[DIRT_SEMEN_CORPUS] is missing or has no cases.")
	var/list/digests = list()
	for(var/line in splittext(file2text(DIRT_SEMEN_MANIFEST) || "", regex(@"\r?\n")))
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
	rustg_file_write(jointext(blocks, ""), DIRT_SEMEN_MASKS_CURRENT)
	var/shown = jointext(changes.Copy(1, min(length(changes), 40) + 1), "\n")
	TEST_FAIL("[length(changes)] case\s of the dirt masks differ from [DIRT_SEMEN_MANIFEST]:\n[shown]\n\
		Every case's text is in [DIRT_SEMEN_MASKS_CURRENT], to compare with the reference generator's.")

/**
 * Returns a corpus case as the text the reference generator writes for it: "case <id>", then the case's lines, each
 * ending in a newline, the last one too.
 * - random: one /datum/dirt_random stream per case, and one line per integer call. shuffle and sample write the list
 *   joined by single spaces; random, uniform and gauss spend their draws and write nothing.
 * - noise: round(hash * 255) per lattice point, list(x, y, seed).
 * - surface: the case's template built as the game builds a body's, and for each of S, N, E and W, "dir <letter>" and
 *   its three grids (dirt_parity_surface_lines()).
 * - body: semen on the case's template, no parts: for each direction, "dir <letter>" and one grid of roles, the
 *   case's splats each drawn by dirt_rasterise_aimed() on its "surface" (skin or cloth), then merged by dirt_merge().
 *
 * Arguments:
 * - case_data: One entry of the corpus's "cases".
 * - corpus: The whole corpus, for the templates, parts and taurs a case names.
 * - templates: The templates built so far, by name, shared across cases.
 *
 * Returns:
 * - text: The case's text.
 * - null: The case's kind isn't one built here.
 *
 * Crashes:
 * - On a body case with under_parts, which aren't drawn yet.
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
			if(length(case_data["under_parts"]))
				CRASH("Body case [case_data["id"]] in the dirt parity corpus has under_parts, which aren't drawn yet.")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/pixel_maps = list()
				for(var/list/splat as anything in case_data["splats"])
					pixel_maps += dirt_rasterise_aimed(splat[1], splat[2], splat[3], case_data["surface"], template.surfaces[direction])
				var/datum/dirt_pixels/merged = dirt_merge(pixel_maps)
				lines += "dir [letter]"
				lines += merged.grid_text()
		else
			return null
	return jointext(lines, "\n") + "\n"

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
 * Returns a corpus template as the zone sources dirt_zone_sources() gives a body: each zone's sheet, loaded from its path,
 * and state, the eyes' sheet and states, and whether the head is a human's.
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
 * - rim: "#" the rim, "o" the interior, "." neither.
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
				switch(grid)
					if(1)
						var/limb = surface.limb_of[index]
						line += limb ? copytext("HTAaLl", limb, limb + 1) : "."
					if(2)
						line += surface.rim[index] ? "#" : (surface.interior[index] ? "o" : ".")
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

#undef DIRT_SEMEN_CORPUS
#undef DIRT_SEMEN_MANIFEST
#undef DIRT_SEMEN_MASKS_CURRENT
