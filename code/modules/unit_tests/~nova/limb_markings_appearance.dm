/**
 * Records a pixel signature for every rendering case the markings datumisation has to keep identical.
 *
 * This file also holds the fixture shared with the markings benchmark, because both baselines have to
 * dress the same character for their numbers to be comparable.
 *
 * Run it on the current representation to write the "before" file, then again after a step to write the
 * "after" file, and diff the two. Only `output_path` changes between the two runs.
 */

/// The markings both baselines wear. Each one claims all eight marking zones and ships art for every one
/// of them plus both leg shapes, so no case falls back to a sheet's default frame and hides a difference.
/// Named explicitly rather than read out of GLOB.body_markings_per_limb, whose order a later step re-sorts.
/proc/markings_baseline_marking_names()
	return list("Bovine", "Dalmatian", "Guilmon Mark")

/// One fixed colour per fixture marking, so no signature ever depends on a mutant colour roll.
/proc/markings_baseline_marking_colors()
	return list("#4488cc", "#cc4422", "#33aa55")

/**
 * Fills a marking map in the pre-datumisation shape: zone -> (marking name -> list(color, emissive)).
 *
 * Every zone in GLOB.marking_zones receives all three fixture markings. Only the second one emits, so a
 * capture covers both the plain and the emissive branch of append_base_marking_overlays().
 *
 * Arguments:
 * - target: the map to fill, either a preferences or a DNA marking list.
 *
 * Returns the same list.
 */
/proc/markings_baseline_fill(list/target)
	var/list/names = markings_baseline_marking_names()
	var/list/colors = markings_baseline_marking_colors()
	// Emptied first, so a species randomiser that already seeded a zone cannot leave a stray entry behind.
	target.Cut()
	for(var/zone in GLOB.marking_zones)
		var/list/worn = list()
		for(var/index in 1 to length(names))
			// An integer 0/1, which is what a savefile holds for the emissive flag.
			worn[names[index]] = list(colors[index], index == 2 ? 1 : 0)
		target[zone] = worn
	return target

/**
 * Reduces a rendered icon to one comparison key.
 *
 * Every pixel of every cardinal folds into a single md5, so a colour-only change is caught where
 * difference().getbbox() would miss it. The canvas size travels with the hash so a later run can never
 * silently compare a differently sized render.
 *
 * Arguments:
 * - canvas: the icon to reduce, normally from get_flat_icon_for_all_directions().
 *
 * Returns a list holding the hash and the canvas shape.
 */
/proc/markings_baseline_signature(icon/canvas)
	var/width = canvas.Width()
	var/height = canvas.Height()
	var/list/pixels = list()
	for(var/direction in GLOB.cardinals)
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/pixel = canvas.GetPixel(x, y, "", direction)
				// A fully transparent pixel has no colour; a placeholder keeps the stream aligned.
				pixels += isnull(pixel) ? "." : pixel
	return list(
		"pixels_md5" = md5(jointext(pixels, "")),
		"width" = width,
		"height" = height,
		"samples" = length(pixels),
	)

/**
 * Tells a glowing emissive appearance from an emissive blocker, which shares its plane.
 *
 * Every emissive colour matrix writes its glow into the constant row, and a blocker leaves that row at
 * zero (see _EMISSIVE_COLOR() and _EM_BLOCK_COLOR()).
 *
 * Arguments:
 * - overlay: an appearance already known to sit on the emissive plane.
 *
 * Returns TRUE when the appearance glows.
 */
/proc/markings_baseline_is_glowing(image/overlay)
	var/list/color_matrix = overlay.color
	if(!islist(color_matrix) || length(color_matrix) < 20)
		return FALSE
	return !!(color_matrix[17] || color_matrix[18] || color_matrix[19])

/// Shared setup for both markings baselines. Abstract, so the runner never tries to run it on its own.
/datum/unit_test/markings_baseline
	abstract_type = /datum/unit_test/markings_baseline
	// Both baselines render a fully-marked body many times over.
	priority = TEST_LONGER

/**
 * Builds a fully-marked human with nothing random left in its appearance.
 *
 * Hair and facial hair are pinned to their empty styles and the physique is pinned to male, so no stray
 * accessory or gender roll can move a pixel between two runs of this test.
 *
 * Returns the new human, already rendered once.
 */
/datum/unit_test/markings_baseline/proc/build_marked_human()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.hairstyle = "Bald"
	human.facial_hairstyle = "Shaved"
	human.physique = MALE
	markings_baseline_fill(human.dna.body_markings)
	human.update_body_parts(update_limb_data = TRUE)
	return human

/**
 * Counts what a pixel signature cannot see.
 *
 * Appearance and filter counts are the numbers the overlay merging step is supposed to move, and the
 * emissive count is the only visible trace of the emissive branch, which never reaches a flat icon.
 * Every limb also puts emissive blockers on the emissive plane, so those are counted apart.
 *
 * Arguments:
 * - target: the human whose limbs are measured.
 * - dropped: passed to get_limb_icon(), matching how the case itself was rendered.
 *
 * Returns a list of counters keyed for the output file.
 */
/datum/unit_test/markings_baseline/proc/measure_overlay_shape(mob/living/carbon/human/target, dropped = FALSE)
	var/appearances = 0
	var/filters = 0
	var/emissives = 0
	var/blockers = 0
	var/markings = 0
	var/list/per_limb = list()
	for(var/obj/item/bodypart/limb as anything in target.bodyparts)
		var/list/overlays = limb.get_limb_icon(dropped)
		var/limb_filters = 0
		var/limb_emissives = 0
		var/limb_blockers = 0
		for(var/image/overlay as anything in overlays)
			if(isnull(overlay))
				continue
			limb_filters += length(overlay.filters)
			if(PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE)
				continue
			if(markings_baseline_is_glowing(overlay))
				limb_emissives++
			else
				limb_blockers++
		var/limb_markings = length(limb.markings) + length(limb.aux_zone_markings)
		appearances += length(overlays)
		filters += limb_filters
		emissives += limb_emissives
		blockers += limb_blockers
		markings += limb_markings
		per_limb[limb.body_zone] = list(
			"appearances" = length(overlays),
			"filters" = limb_filters,
			"emissive_appearances" = limb_emissives,
			"emissive_blockers" = limb_blockers,
			"markings" = limb_markings,
			"markings_alpha" = limb.markings_alpha,
		)
	return list(
		"appearances" = appearances,
		"filters" = filters,
		"emissive_appearances" = emissives,
		"emissive_blockers" = blockers,
		"markings" = markings,
		"per_limb" = per_limb,
	)

/**
 * Swaps both legs for another leg type, the way a species or a taur organ would.
 *
 * The old leg is dropped first: try_attach_limb() stack traces when it finds a non-stump limb already in
 * the zone, and a stack trace fails the test.
 *
 * Arguments:
 * - target: the human to re-leg.
 * - left_type: the left leg subtype to attach.
 * - right_type: the right leg subtype to attach.
 *
 * Returns TRUE when both legs were replaced.
 */
/datum/unit_test/markings_baseline/proc/replace_legs(mob/living/carbon/human/target, left_type, right_type)
	var/list/replacements = list(
		BODY_ZONE_L_LEG = left_type,
		BODY_ZONE_R_LEG = right_type,
	)
	for(var/zone, replacement in replacements)
		var/obj/item/bodypart/old_leg = target.get_bodypart(zone)
		if(isnull(old_leg))
			return FALSE
		old_leg.drop_limb(special = TRUE)
		qdel(old_leg)
		var/obj/item/bodypart/leg/new_leg = new replacement()
		if(!new_leg.try_attach_limb(target, special = TRUE))
			qdel(new_leg)
			return FALSE
	target.update_body_parts(update_limb_data = TRUE)
	return TRUE

/// Captures the appearance of every marking rendering case the refactor must preserve.
/datum/unit_test/markings_baseline/appearance
	/// Where the signatures land. A later step renders the same matrix into a second path and diffs the
	/// two; point this at "data/markings_appearance_after.json" for that run and change nothing else.
	var/output_path = "data/markings_appearance_before.json"
	/// case name -> signature and counters.
	var/list/cases = list()
	/// Anything that could not be built, so a missing case never has to be guessed at.
	var/list/notes = list()

/**
 * Renders one case and files its signature.
 *
 * Arguments:
 * - case_name: the key this case takes in the output file.
 * - subject: the atom to flatten, either the whole mob or a detached limb.
 * - counters: the overlay shape counters for this case, or null to record pixels only.
 */
/datum/unit_test/markings_baseline/appearance/proc/capture(case_name, atom/subject, list/counters)
	var/list/record = markings_baseline_signature(get_flat_icon_for_all_directions(subject))
	if(counters)
		record += counters
	cases[case_name] = record

/datum/unit_test/markings_baseline/appearance/Run()
	var/list/names = markings_baseline_marking_names()

	// Standing, all four facings, medium height, male physique. Every other case is a delta on this one.
	var/mob/living/carbon/human/standing = build_marked_human()
	capture("standing", standing, measure_overlay_shape(standing))

	// Husked: every marking collapses to one grey, so this is the case the husk cache key has to separate.
	var/mob/living/carbon/human/husked = build_marked_human()
	husked.become_husk(BURN)
	husked.update_body_parts(update_limb_data = TRUE)
	capture("husked", husked, measure_overlay_shape(husked))

	// A detached limb renders on its own and only ever faces south.
	var/mob/living/carbon/human/dismembered = build_marked_human()
	var/obj/item/bodypart/dropped_arm = dismembered.get_bodypart(BODY_ZONE_L_ARM)
	if(dropped_arm)
		dropped_arm.drop_limb(special = TRUE)
		capture("dropped_limb", dropped_arm, list(
			"appearances" = length(dropped_arm.get_limb_icon(TRUE)),
			"markings" = length(dropped_arm.markings) + length(dropped_arm.aux_zone_markings),
		))
		qdel(dropped_arm)
	else
		notes += "dropped_limb: the fixture had no left arm to detach."

	// The three heights that carry displacement filters, on one body because height is in the cache key.
	var/mob/living/carbon/human/heights = build_marked_human()
	for(var/case_name, height in list("height_tall" = HUMAN_HEIGHT_TALL, "height_tallest" = HUMAN_HEIGHT_TALLEST))
		heights.set_mob_height(height)
		heights.update_body_parts(update_limb_data = TRUE)
		capture(case_name, heights, measure_overlay_shape(heights))
	// Dwarf comes last: set_mob_height() refuses to move a body that already has the trait.
	ADD_TRAIT(heights, TRAIT_DWARF, "markings baseline")
	heights.update_mob_height()
	heights.update_body_parts(update_limb_data = TRUE)
	capture("height_dwarf", heights, measure_overlay_shape(heights))

	// Taur legs never render their markings at all.
	var/mob/living/carbon/human/taur = build_marked_human()
	if(replace_legs(taur, /obj/item/bodypart/leg/left/taur, /obj/item/bodypart/leg/right/taur))
		capture("taur", taur, measure_overlay_shape(taur))
	else
		notes += "taur: could not attach taur legs to the fixture."

	// Digitigrade legs take a different icon state for the same marking.
	var/mob/living/carbon/human/digitigrade = build_marked_human()
	if(replace_legs(digitigrade, /obj/item/bodypart/leg/left/digitigrade, /obj/item/bodypart/leg/right/digitigrade))
		capture("digitigrade", digitigrade, measure_overlay_shape(digitigrade))
	else
		notes += "digitigrade: could not attach digitigrade legs to the fixture."

	// Both physiques of a dimorphic chest, which is what picks a marking's _chest_m or _chest_f art.
	var/mob/living/carbon/human/physiques = build_marked_human()
	var/obj/item/bodypart/chest/chest = physiques.get_bodypart(BODY_ZONE_CHEST)
	if(chest?.is_dimorphic)
		for(var/case_name, physique in list("physique_male" = MALE, "physique_female" = FEMALE))
			physiques.physique = physique
			physiques.update_body_parts(update_limb_data = TRUE)
			capture(case_name, physiques, measure_overlay_shape(physiques))
	else
		notes += "physique_male/physique_female: the fixture chest is not dimorphic."

	// The one species with a reduced marking alpha, wearing three overlapping markings on every zone.
	var/mob/living/carbon/human/slime = build_marked_human()
	slime.set_species(/datum/species/jelly/roundstartslime)
	// A species change can rebuild the marking map, so dress the body again before rendering it.
	markings_baseline_fill(slime.dna.body_markings)
	slime.hairstyle = "Bald"
	slime.facial_hairstyle = "Shaved"
	slime.physique = MALE
	slime.update_body_parts(update_limb_data = TRUE)
	capture("slime_reduced_alpha", slime, measure_overlay_shape(slime))

	// Write before asserting, so a failed expectation still leaves a usable baseline on disk.
	rustg_file_write(json_encode(list(
		"representation" = "nested_list",
		"fixture" = list(
			"marking_names" = names,
			"marking_colors" = markings_baseline_marking_colors(),
			"zones" = GLOB.marking_zones,
			"emissive_index" = 2,
		),
		"cases" = cases,
		"notes" = notes,
	)), output_path)

	TEST_ASSERT(!length(notes), "Every baseline case must be buildable: [jointext(notes, " ")]")
	TEST_ASSERT_EQUAL(length(names), MAXIMUM_MARKINGS_PER_LIMB, "The fixture must fill every marking slot a limb has.")
	var/list/standing_case = cases["standing"]
	var/list/male_case = cases["physique_male"]
	var/list/female_case = cases["physique_female"]
	TEST_ASSERT_EQUAL(standing_case["pixels_md5"], male_case["pixels_md5"], "The capture must be deterministic: two identically dressed male bodies rendered differently.")
	TEST_ASSERT_NOTEQUAL(male_case["pixels_md5"], female_case["pixels_md5"], "A gendered chest marking must render differently on each physique.")
	TEST_ASSERT_NOTEQUAL(standing_case["pixels_md5"], cases["husked"]["pixels_md5"], "A husk must not render the same pixels as an unhusked body.")
	TEST_ASSERT(standing_case["markings"] > 0, "The fixture must actually be wearing markings.")
