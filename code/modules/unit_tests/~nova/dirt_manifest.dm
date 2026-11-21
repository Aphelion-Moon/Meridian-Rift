/**
 * A check of the dirt masks the game generates against the reference generator's. dirt_parity_case_block() builds
 * every case of the corpus next to this file (dirt_corpus.json) as text. The MD5 of that text must match the case's
 * line in the manifest beside it (dirt_manifest.txt), which the reference generator writes from the same corpus. A
 * case is the text one corpus entry builds, of a kind dirt_parity_case_block() describes. So a change that moves one
 * draw, one pixel or one value fails here.
 *
 * Whenever a case differs, the text of every case is written to data/dirt_masks.txt, to compare case by case
 * with the reference generator's.
 */
// compiled in, since CI's test world is deployed without code/
#define DIRT_CORPUS 'code/modules/unit_tests/~nova/dirt_corpus.json'
#define DIRT_MANIFEST 'code/modules/unit_tests/~nova/dirt_manifest.txt'
#define DIRT_MASKS_CURRENT "data/dirt_masks.txt"

/datum/unit_test/dirt_manifest
	// every case is generated, and the body cases rasterise mess at every level up to their own
	priority = TEST_LONGER

/datum/unit_test/dirt_manifest/Run()
	var/list/corpus = json_decode(file2text(DIRT_CORPUS) || "{}")
	TEST_ASSERT(length(corpus["cases"]), "[DIRT_CORPUS] has no cases.")
	var/list/digests = list()
	for(var/line in splittext(file2text(DIRT_MANIFEST) || "", regex(@"\r?\n")))
		if(length(line) && copytext(line, 1, 2) != "#")
			var/list/fields = splittext(line, " ")
			digests[fields[1]] = fields[2]
	var/list/blocks = list()
	var/list/changes = list()
	// a template takes about 90 ms to build, and every body case reuses one of four
	var/alist/templates = alist()
	// painted designs are drawn from the plain human template the game keeps, and the corpus's human_m stands in for it
	var/datum/dirt_template/human = dirt_parity_template("human_m", corpus, templates)
	for(var/cell, versions in dirt_painted_points_on(human.surfaces[SOUTH]))
		for(var/version in 1 to length(versions))
			TEST_ASSERT(dirt_parity_same_points(dirt_painted_points(cell, version), versions[version]), "The painted design [cell] [version] has other points on the corpus's human_m than on the plain human template.")
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
	rustg_file_write(jointext(blocks, ""), DIRT_MASKS_CURRENT)
	var/shown = jointext(changes.Copy(1, min(length(changes), 40) + 1), "\n")
	TEST_FAIL("[length(changes)] case\s of the dirt masks differ from [DIRT_MANIFEST]:\n[shown]\n\
		Every case's text is in [DIRT_MASKS_CURRENT], to compare with the reference generator's.")

/**
 * Returns a corpus case as the text the reference generator writes for it: "case <id>", then the case's lines, each
 * ending in a newline, the last one too.
 * - random: one /datum/dirt_random stream per case, and one line per integer call (choices writes the option it picks).
 *   shuffle and sample write the list joined by single spaces. random, uniform and gauss spend their draws and write
 *   nothing.
 * - noise: round(hash * 255) per lattice point, list(x, y, seed).
 * - draft_random: one /datum/dirt_random/draft stream per case, one line per call (dirt_parity_draft_lines()).
 * - draft_noise: the draft's hash per lattice point, list(x, y, seed), as its 16 bits (dirt_draft_hash_bits()).
 * - surface: the case's template built as the game builds a body's, and for each of S, N, E and W, "dir <letter>" and
 *   its three grids (dirt_parity_surface_lines()).
 * - body: mess on the case's template. Each of the case's splats is drawn by dirt_rasterise_aimed() on the case's
 *   "surface" (skin or cloth), packed and unpacked as a cached raster is (/datum/dirt_pixels/proc/drawn(),
 *   dirt_pixels_from_drawn()), then merged by dirt_merge(). For each direction, "dir <letter>" and one grid of roles.
 *   The case's "under_parts" and "over_parts" name parts in the corpus's "parts", lowest drawn first. A "name@N" entry
 *   counts only in the facings it names (dirt_parity_facing_parts()). The parts shape the mess as they shape a
 *   surface's masks. Each splat is drawn at its level where they take a share (dirt_part_body_level()), then merged
 *   with them by dirt_merge_with_parts().
 * - part: one splat's mess on the case's part (dirt_part_field()), on the case's template. It lies on the pixels the
 *   part takes its share on for the case's "surface" (dirt_part_own()). For each direction, "dir <letter>" and one
 *   grid of roles.
 * - taur_surface: a taur kind in the corpus's "taurs", under its rider, which is the case's template. For each
 *   direction, "dir <letter>" and one grid, 64 across, of what each pixel shows (dirt_taur_owners(),
 *   dirt_parity_taur_lines()).
 * - taur: a back shot's pools on a taur kind (dirt_taur_pools()). They keep clear of the shot on the rider's cloth and
 *   skin, and are packed and unpacked as cached pools are. For each direction, "dir <letter>" and one grid of roles,
 *   64 across.
 * - material: a material (dirt_material() of its "material", and its "colour" for slime or blood). One line "role <n>
 *   <#RRGGBB> <alpha>" for each role from DIRT_ROLE_HAZE, the alpha to 4 decimals, then "edge <n> flags <n>".
 * - deposit: a general deposit on the case's template. Its "cause" in its "material" (with its "colour" for slime), at
 *   its "level", "variant" and "side", is drawn by dirt_rasterise() on its "surface", bare where "painted". Then it's
 *   packed and unpacked as a cached raster is. For each direction, "dir <letter>" and one grid of roles. The painted
 *   cases ("painted-...") are bare skin, which wears a cause's hand-painted design.
 * - merge: deposits on one surface of the case's template. Each of its "deposits", list(cause, material, level,
 *   variant), is drawn by dirt_rasterise() at the case's "side" and packed and unpacked. Then dirt_merge() merges them
 *   with their materials. For each direction, "dir <letter>", one grid of roles and one grid of each pixel's material.
 *   A pixel's material is written as the index in "deposits" of the first deposit of that material
 *   (dirt_parity_material_lines()).
 * - wet: sweat's multiplier on a garment, its "garment": list(icon path, state) or list(icon path, state, colour). A
 *   sweat deposit at its "level", "variant" and "side" is drawn by dirt_rasterise() on the template's cloth, packed and
 *   unpacked, and merged. It's kept as cloth masks keep their wet pixels (dirt_wet_drawn()), then made per direction as
 *   a garment's multiplier is (dirt_garment_pixels(), dirt_wet_factors()). For each direction, "dir <letter>" and one
 *   grid of each wet pixel's factors x 255 as "rrggbb", and "......" elsewhere (dirt_parity_wet_lines()).
 * - reach: the limbs a general cause reaches in a material (dirt_cause_reach() of its "cause" and its "material", with
 *   its "colour" for slime). One line "limbs <glyphs>", one glyph per limb in DIRT_LIMB_* order, as the surface grids
 *   write them, or "limbs none".
 * - canvas: a general deposit on a whole canvas (dirt_canvas_rasterise()): its "cause" in its "material" at its
 *   "level", "variant" and "side", on its "canvas" as its "surface". For each direction, "dir <letter>" and one grid of
 *   roles, the canvas's size.
 * - tail, wing, shape, splat: its "cause" in its "material" at its "level", "variant" and "side", on a shape in the
 *   corpus's "shapes" (dirt_parity_shape_mask()). A tail is drawn by dirt_tail_rasterise(), with the floor its "floor"
 *   pixels under the canvas's top row. A wing is drawn by dirt_wing_rasterise(), a shape by dirt_shape_rasterise() on
 *   its "surface", and a splat by dirt_splat_rasterise() as the kind of shape its "on" names. For each direction,
 *   "dir <letter>" and one grid of roles on the shape's canvas.
 * - taur_coat: a contact coat (dirt_taur_coat()) of its "cause" in its "material" at its "level" and "variant" on a taur
 *   kind in the corpus's "taurs". For each direction, "dir <letter>" and one grid of roles, 64 across.
 * - blood_seeds: where a worn blood stain's "state" meets the taur waist crop (dirt_blood_seeds()). For each direction,
 *   "dir <letter>", then "seeds" and each tile column's stain pixel on the crop's last row as "<column>:<alpha>". Then
 *   "near" and the columns the stain reaches in the crop's last two rows. Either list is "none" if it's empty.
 * - blood: blood run down below a taur's waist (dirt_blood_continuation()) from a stain's "state", on a taur kind in
 *   the corpus's "taurs" under its rider, which is the case's template. It runs from the case's "seam" row in its
 *   "variant", hanging from the stain's mass there (dirt_blood_mass()). It lies on what the canvas holds for it
 *   (dirt_blood_carriers()): the taur body's pixels unless "body" is false, and a taur-fitted garment's "cloth",
 *   list(icon path, state), if any. If the case has "rows", the rider and the cloth are drawn at the height they give
 *   (dirt_height_rows()). For each direction, "dir <letter>" and one grid of roles, 64 across.
 * - hair: deposits on a hairstyle, a shape in the corpus's "shapes", as the hair draws them. Each of its "deposits",
 *   list(cause, material, level, variant), that reaches the hair at its level (dirt_hair_levels()) is drawn by
 *   dirt_shape_rasterise() as hair at the case's "side", then packed and unpacked. dirt_hair_dirt() then makes the
 *   hair's dirt from them, on the shape's pixels and their brightness (dirt_hair_layers_brightness()). For each
 *   direction, "dir <letter>", one grid of roles and one of each pixel's material, as in a merge case. Its "states" are
 *   blended in order into one icon, as a hairstyle's icon blends its inner pieces. Its "outer" states, if any, are its
 *   pieces drawn over hats.
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
		if("draft_random")
			lines += dirt_parity_draft_lines(case_data)
		if("draft_noise")
			for(var/list/point as anything in case_data["points"])
				lines += dirt_parity_number_text(dirt_draft_hash_bits(point[1], point[2], point[3]))
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
					// packed and unpacked, as every raster kept in SSdirt.rasters is
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
		if("material")
			var/datum/dirt_material/material = dirt_material(case_data["material"], case_data["colour"])
			if(!material)
				lines += "no material"
			else
				for(var/role in DIRT_ROLE_HAZE to DIRT_ROLE_GLINT)
					var/list/tint = material.tints[role]
					lines += "role [role] [uppertext(tint[1])] [dirt_parity_decimal_text(tint[2], 4)]"
				lines += "edge [material.edge] flags [material.flags]"
		if("deposit")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			var/datum/dirt_material/material = dirt_material(case_data["material"], case_data["colour"])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/datum/dirt_pixels/raster = dirt_rasterise(case_data["cause"], material, case_data["level"], case_data["variant"], case_data["side"], case_data["surface"], template.surfaces[direction], !!case_data["painted"])
				raster = dirt_pixels_from_drawn(raster.drawn(), raster.width, raster.height)
				lines += "dir [letter]"
				lines += raster.grid_text()
		if("merge")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			var/list/deposits = case_data["deposits"]
			var/list/materials = list()
			var/list/keys = list()
			// material key = the index of its first deposit, as text
			var/alist/glyphs = alist()
			for(var/list/entry as anything in deposits)
				var/datum/dirt_material/material = dirt_material(entry[2])
				materials += material
				keys += material.key
				if(isnull(glyphs[material.key]))
					glyphs[material.key] = "[length(keys) - 1]"
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/pixel_maps = list()
				for(var/position in 1 to length(deposits))
					var/list/deposit = deposits[position]
					var/datum/dirt_pixels/raster = dirt_rasterise(deposit[1], materials[position], deposit[3], deposit[4], case_data["side"], case_data["surface"], template.surfaces[direction])
					pixel_maps += dirt_pixels_from_drawn(raster.drawn(), raster.width, raster.height)
				var/datum/dirt_pixels/merged = dirt_merge(pixel_maps, keys)
				lines += "dir [letter]"
				lines += merged.grid_text()
				lines += dirt_parity_material_lines(merged, glyphs)
		if("wet")
			var/datum/dirt_template/template = dirt_parity_template(case_data["template"], corpus, templates)
			var/datum/dirt_material/sweat = dirt_material(DIRT_MATERIAL_SWEAT)
			var/list/garment = case_data["garment"]
			var/sheet = file(garment[1])
			var/colour = length(garment) > 2 ? garment[3] : null
			var/alist/merged = alist()
			for(var/direction in dirt_mask_directions())
				var/datum/dirt_pixels/raster = dirt_rasterise(DIRT_CAUSE_SWEAT, sweat, case_data["level"], case_data["variant"], case_data["side"], DIRT_SURFACE_CLOTH, template.surfaces[direction])
				merged[direction] = dirt_merge(list(dirt_pixels_from_drawn(raster.drawn(), raster.width, raster.height)), list(sweat.key))
			// kept as cloth masks keep their wet pixels, then made into a garment's multiplier as its job makes it
			var/alist/wet = dirt_wet_drawn(merged, null)
			var/list/directions = dirt_mask_directions()
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/alist/alphas = wet ? dirt_wet_alphas(wet, directions.Find(direction)) : alist()
				var/alist/factors = dirt_wet_factors(dirt_garment_pixels(sheet, garment[2], colour, direction, alphas), alphas, ICON_SIZE_X, ICON_SIZE_Y)
				lines += "dir [letter]"
				lines += dirt_parity_wet_lines(factors)
		if("reach")
			var/reach = dirt_cause_reach(case_data["cause"], dirt_material(case_data["material"], case_data["colour"]))
			var/glyphs = ""
			for(var/limb in DIRT_LIMB_HEAD to DIRT_LIMB_L_LEG)
				if(reach & DIRT_LIMB_BIT(limb))
					glyphs += copytext("HTAaLl", limb, limb + 1)
			lines += "limbs [glyphs || "none"]"
		if("canvas")
			var/datum/dirt_material/material = dirt_material(case_data["material"], case_data["colour"])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/datum/dirt_pixels/raster = dirt_canvas_rasterise(case_data["cause"], material, case_data["level"], case_data["variant"], case_data["canvas"], direction, case_data["surface"], case_data["side"])
				lines += "dir [letter]"
				lines += raster.grid_text()
		if("tail", "wing", "shape", "splat")
			var/datum/dirt_material/material = dirt_material(case_data["material"], case_data["colour"])
			var/list/shape = corpus["shapes"][case_data["shape"]]
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/alist/mask = dirt_parity_shape_mask(case_data["shape"], shape, direction)
				var/datum/dirt_pixels/raster
				switch(case_data["kind"])
					if("tail")
						raster = dirt_tail_rasterise(mask, case_data["cause"], material, case_data["level"], case_data["variant"], direction, case_data["floor"], case_data["side"])
					if("wing")
						raster = dirt_wing_rasterise(mask, case_data["cause"], material, case_data["level"], case_data["variant"], direction, case_data["side"])
					if("shape")
						raster = dirt_shape_rasterise(mask, case_data["cause"], material, case_data["level"], case_data["variant"], shape["canvas"], direction, case_data["surface"], case_data["side"])
					else
						raster = dirt_splat_rasterise(mask, case_data["cause"], material, case_data["level"], case_data["variant"], case_data["on"], direction, case_data["side"])
				lines += "dir [letter]"
				lines += raster.grid_text()
		if("blood_seeds")
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/seeds = dirt_blood_seeds(case_data["state"], direction)
				var/list/alphas = seeds[1]
				var/list/near = seeds[2]
				var/list/seed_words = list()
				var/list/near_words = list()
				for(var/column in 0 to ICON_SIZE_X - 1)
					if(alphas[column + 1])
						seed_words += "[column]:[alphas[column + 1]]"
					if(near[column + 1])
						near_words += "[column]"
				lines += "dir [letter]"
				lines += "seeds [length(seed_words) ? jointext(seed_words, " ") : "none"]"
				lines += "near [length(near_words) ? jointext(near_words, " ") : "none"]"
		if("blood")
			var/datum/dirt_template/rider = dirt_parity_template(case_data["rider"], corpus, templates)
			var/datum/dirt_taur_source/taur_source = dirt_parity_taur(corpus["taurs"][case_data["taur"]])
			var/list/cloth = case_data["cloth"]
			var/list/blood = list(list(), cloth && list(file(cloth[1]), cloth[2]), isnull(case_data["body"]) || case_data["body"], case_data["seam"], case_data["rows"])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/list/carriers = dirt_blood_carriers(taur_source, rider.surfaces[direction], direction, blood)
				var/list/mass = dirt_blood_mass(case_data["state"], direction, case_data["seam"], case_data["rows"], case_data["state"] == "uniformblood" ? carriers[5] : null)
				var/datum/dirt_pixels/drawn = dirt_blood_continuation(carriers[2], carriers[3], case_data["state"], direction, case_data["seam"], case_data["variant"], mass, carriers[4])
				lines += "dir [letter]"
				lines += drawn.grid_text()
		if("taur_coat")
			var/datum/dirt_material/material = dirt_material(case_data["material"], case_data["colour"])
			var/datum/dirt_taur_source/taur_source = dirt_parity_taur(corpus["taurs"][case_data["taur"]])
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/datum/dirt_pixels/raster = dirt_taur_coat(taur_source, case_data["cause"], material, case_data["level"], case_data["variant"], direction)
				lines += "dir [letter]"
				lines += raster.grid_text()
		if("hair")
			// shape name = its states blended, kept so no later icon reuses the reference its reads are cached under
			var/static/alist/blended_sheets = alist()
			var/list/shape = corpus["shapes"][case_data["shape"]]
			var/list/size = dirt_canvases()[shape["canvas"]]
			var/sheet = file(shape["icon"])
			var/list/states = shape["states"]
			var/hair_sheet = sheet
			var/hair_state = states[1]
			if(length(states) > 1)
				var/icon/blended = blended_sheets[case_data["shape"]]
				if(!blended)
					// as getCachedIcon() blends a hairstyle's inner pieces
					blended = icon(sheet, states[1])
					for(var/position in 2 to length(states))
						blended.Blend(icon(sheet, states[position]), ICON_OVERLAY)
					blended_sheets[case_data["shape"]] = blended
				hair_sheet = blended
				hair_state = null
			var/list/deposits = case_data["deposits"]
			var/alist/levels = dirt_hair_levels()
			var/list/materials = list()
			// material key = the index of its first deposit, as text
			var/alist/glyphs = alist()
			for(var/position in 1 to length(deposits))
				var/list/entry = deposits[position]
				var/datum/dirt_material/material = dirt_material(entry[2])
				materials += material
				if(isnull(glyphs[material.key]))
					glyphs[material.key] = "[position - 1]"
			for(var/letter, direction in list("S" = SOUTH, "N" = NORTH, "E" = EAST, "W" = WEST))
				var/alist/mask = dirt_parity_shape_mask(case_data["shape"], shape, direction)
				var/list/pixel_maps = list()
				var/list/keys = list()
				for(var/position in 1 to length(deposits))
					var/list/deposit = deposits[position]
					if(deposit[3] < (levels[deposit[1]] || INFINITY))
						continue
					var/datum/dirt_material/material = materials[position]
					var/datum/dirt_pixels/raster = dirt_shape_rasterise(mask, deposit[1], material, deposit[3], deposit[4], shape["canvas"], direction, DIRT_SURFACE_HAIR, case_data["side"])
					pixel_maps += dirt_pixels_from_drawn(raster.drawn(), raster.width, raster.height)
					keys += material.key
				var/datum/dirt_pixels/hair = dirt_hair_dirt(dirt_hair_layers_brightness(hair_sheet, hair_state, sheet, shape["outer"], direction, size[1], size[2]), pixel_maps, keys, size[1], size[2])
				lines += "dir [letter]"
				lines += hair.grid_text()
				lines += dirt_parity_material_lines(hair, glyphs)
		else
			return null
	return jointext(lines, "\n") + "\n"

/**
 * Returns the parts a body case places under or over its surface in one facing. Each entry of its "under_parts" or
 * "over_parts" is a part's name, which counts in every facing, or "name@NE", which counts only in the facings it names.
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
 * Returns a merged mask's materials as one grid, one line per row, one glyph per pixel: its material's glyph, or "."
 * where nothing is drawn.
 *
 * Arguments:
 * - merged: The mask, from dirt_merge() given its masks' materials.
 * - glyphs: alist(material key = its glyph).
 */
/proc/dirt_parity_material_lines(datum/dirt_pixels/merged, alist/glyphs)
	RETURN_TYPE(/list)
	. = list()
	var/list/materials = merged.materials
	for(var/row in 0 to merged.height - 1)
		var/list/glyph_row = list()
		for(var/column in 0 to merged.width - 1)
			var/index = row * merged.width + column + 1
			glyph_row += merged.roles[index] ? glyphs[materials[index]] : "."
		. += jointext(glyph_row, "")

/**
 * Returns sweat's multiplier in one direction as one grid, one line per row: each wet pixel's bytes as "rrggbb", in
 * lower case, "......" elsewhere.
 *
 * Arguments:
 * - factors: dirt_wet_factors() in that direction.
 */
/proc/dirt_parity_wet_lines(alist/factors)
	RETURN_TYPE(/list)
	. = list()
	for(var/row in 0 to ICON_SIZE_Y - 1)
		var/list/cells = list()
		for(var/column in 0 to ICON_SIZE_X - 1)
			var/list/bytes = factors[row * ICON_SIZE_X + column + 1]
			cells += bytes ? LOWER_TEXT(copytext(rgb(bytes[1], bytes[2], bytes[3]), 2)) : "......"
		. += jointext(cells, "")

/**
 * Returns whether two sets of a painted design's points (dirt_painted_points()) are the same, entry for entry.
 *
 * Arguments:
 * - kept: One set.
 * - stand_in: The other.
 */
/proc/dirt_parity_same_points(list/kept, list/stand_in)
	for(var/column in 1 to length(kept))
		var/list/kept_column = kept[column]
		var/list/stand_in_column = stand_in[column]
		if(length(kept_column) != length(stand_in_column))
			return FALSE
		for(var/position in 1 to length(kept_column))
			if(kept_column[position] != stand_in_column[position])
				return FALSE
	return TRUE

/**
 * Returns corpus parts as the game reads a genital. Each is a /datum/dirt_part_source of its states, every layer's
 * together, with its sheet loaded from its path.
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
 * Returns a corpus shape's pixels in one direction on its canvas, as alist(index = TRUE). Its states' pixels count
 * together, a hairstyle's "outer" states' too, at any opacity. They're read once and shared by every case of the shape.
 *
 * Arguments:
 * - name: The shape's name in the corpus's "shapes".
 * - shape: Its entry: its "icon", "states" and "canvas", and a hairstyle's "outer" states, if any.
 * - direction: The direction.
 */
/proc/dirt_parity_shape_mask(name, list/shape, direction)
	RETURN_TYPE(/alist)
	var/static/alist/masks = alist()
	var/key = "[name]|[direction]"
	var/alist/mask = masks[key]
	if(mask)
		return mask
	mask = alist()
	var/list/size = dirt_canvases()[shape["canvas"]]
	var/width = size[1]
	var/height = size[2]
	var/list/states = shape["states"]
	if(shape["outer"])
		states = states + shape["outer"]
	for(var/state in states)
		var/icon/sprite = icon(file(shape["icon"]), state)
		for(var/row in 0 to height - 1)
			for(var/column in 0 to width - 1)
				if(sprite.GetPixel(column + 1, height - row, null, direction))
					mask[row * width + column + 1] = TRUE
	masks[key] = mask
	return mask

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
 * Returns a corpus template as the zone sources dirt_zone_sources() gives a body: each zone's sheet (loaded from its
 * path) and state, the eyes' sheet and states, and whether the head is a human's.
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
			if("choices")
				lines += dirt_parity_number_text(stream.choices(call_data[2], call_data[3]))
			if("shuffle")
				var/list/items = call_data[2]
				lines += dirt_parity_number_text(stream.shuffle(items.Copy()))
			if("sample")
				lines += dirt_parity_number_text(stream.sample(call_data[2], call_data[3]))
			else
				CRASH("Unknown random call in the dirt parity corpus: [call_data[1]]")
	return lines

/**
 * Returns a draft_random case's lines: one per call, in order, all from one draft stream.
 * - words: as many 32-bit words as the call asks for, each as its high and low halves.
 * - random, uniform: the float32 exactly (dirt_parity_float_text()).
 * - gauss: round(value * 1024), halves up.
 * - index: draw_index().
 * - randrange, randint, choose, choices, shuffle: as a random case writes them.
 *
 * Arguments:
 * - case_data: One draft_random entry of the corpus's "cases": its "seed", and its "calls", each a list of the call's
 *   name and its arguments.
 *
 * Crashes:
 * - On a call this proc doesn't know.
 */
/proc/dirt_parity_draft_lines(list/case_data)
	var/datum/dirt_random/draft/stream = new(case_data["seed"])
	var/list/lines = list()
	for(var/list/call_data as anything in case_data["calls"])
		switch(call_data[1])
			if("words")
				for(var/word_number in 1 to call_data[2])
					stream.next_word()
					lines += "[dirt_parity_number_text(stream.word_high)] [dirt_parity_number_text(stream.word_low)]"
			if("random")
				lines += dirt_parity_float_text(stream.random())
			if("uniform")
				lines += dirt_parity_float_text(stream.uniform(call_data[2], call_data[3]))
			if("gauss")
				lines += dirt_parity_number_text(floor(stream.gauss(call_data[2], call_data[3]) * 1024 + 0.5))
			if("index")
				lines += dirt_parity_number_text(stream.draw_index(call_data[2]))
			if("randrange")
				lines += dirt_parity_number_text(stream.randrange(call_data[2]))
			if("randint")
				lines += dirt_parity_number_text(stream.randint(call_data[2], call_data[3]))
			if("choose")
				lines += dirt_parity_number_text(stream.choose(call_data[2]))
			if("choices")
				lines += dirt_parity_number_text(stream.choices(call_data[2], call_data[3]))
			if("shuffle")
				var/list/items = call_data[2]
				lines += dirt_parity_number_text(stream.shuffle(items.Copy()))
			else
				CRASH("Unknown draft call in the dirt parity corpus: [call_data[1]]")
	return lines

/**
 * Returns a float32 exactly, as the reference writes one: "<mantissa> <exponent>", where the value is mantissa *
 * 2^exponent. The mantissa is a whole number from 2^23 up to 2^24, with the value's sign. 0 is written "0".
 *
 * Arguments:
 * - value: The number.
 */
/proc/dirt_parity_float_text(value)
	if(!value)
		return "0"
	var/mantissa = abs(value)
	var/exponent = 0
	// a float32 lies between 2^-149 and 2^128
	for(var/step_number in 1 to 300)
		if(mantissa >= 16777216)
			mantissa /= 2
			exponent++
		else if(mantissa < 8388608)
			mantissa *= 2
			exponent--
		else
			break
	return "[value < 0 ? "-" : ""][num2text(mantissa, 12)] [num2text(exponent, 12)]"

/**
 * Returns a number from 0 up to 10 with `places` decimals, as Python's "%.<places>f" writes it, halves rounded up.
 *
 * Arguments:
 * - value: The number.
 * - places: How many decimals, 1 to 5.
 */
/proc/dirt_parity_decimal_text(value, places)
	var/scale = 10 ** places
	var/scaled = round(value * scale, 1)
	var/whole = floor(scaled / scale)
	// the fraction's digits, leading zeros included, written after a 1 that's then cut off
	return "[whole].[copytext(num2text(scale + scaled - whole * scale, 12), 2)]"

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

#undef DIRT_CORPUS
#undef DIRT_MANIFEST
#undef DIRT_MASKS_CURRENT
