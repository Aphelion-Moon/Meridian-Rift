/**
 * Whole-body renders for the species page, facing each way: this sheet in uniform, and
 * /datum/asset/spritesheet_batched/species_full/body without.
 *
 * Nothing is drawn during init. Registering is empty, and the renders are drawn when a sheet is
 * first realized: by SSasset_loading in the lobby, a tick check at a time, or by the first player
 * to open the species page, whichever comes first. Sprites are named `[icon]-[facing]`, where icon is
 * the species' sanitized name, as the species preference's constant data sends it, and facing is a
 * key of GLOB.character_preview_facings.
 */
/datum/asset/spritesheet_batched/species_full
	name = "species_full"
	/// Whether this sheet's renders wear the uniform.
	var/uniform = TRUE

/// Without uniform. Sent only once someone turns a specimen to its body.
/datum/asset/spritesheet_batched/species_full/body
	name = "species_body"
	uniform = FALSE

/// Registers nothing during init; the renders are drawn when the sheet is first realized.
/datum/asset/spritesheet_batched/species_full/create_spritesheets()
	return

/// Takes this sheet's half of the renders before it is first generated.
/datum/asset/spritesheet_batched/species_full/realize_spritesheets(yield)
	if (!length(entries))
		entries = get_species_page_renders()[uniform ? "uniform" : "body"]
	return ..()

/**
 * Draws every species on the species page facing each way, without uniform and then in it, as
 * list("body" = entries, "uniform" = entries) in insert_icon()'s entry format. Both sheets take
 * their half from the one drawing, and later callers wait for the first to finish.
 *
 * This never loads a sheet itself: loading one can realize it, which would call back in here.
 */
/proc/get_species_page_renders()
	var/static/list/renders
	var/static/rendering = FALSE
	UNTIL(!rendering)
	if (renders)
		return renders

	rendering = TRUE
	var/list/body = list()
	var/list/uniform = list()
	try
		for (var/species_id in get_species_page_ids())
			var/datum/species/species_type = GLOB.species_list[species_id]
			var/icon_key = sanitize_css_class_name(initial(species_type.name))

			// One dummy per species. Its renders match two fresh dummies exactly.
			var/mob/living/carbon/human/dummy/consistent/dummy = new
			dummy.set_species(species_type)
			dummy.dna.species.prepare_human_for_preview(dummy)
			render_species_facings(body, dummy, icon_key)
			dummy.equipOutfit(/datum/outfit/job/assistant/consistent, visuals_only = TRUE)
			dummy.dna.species.prepare_human_for_preview(dummy)
			render_species_facings(uniform, dummy, icon_key)
			SSatoms.prepare_deletion(dummy)
			CHECK_TICK
	catch(var/exception/error)
		rendering = FALSE
		throw error

	renders = list("body" = body, "uniform" = uniform)
	rendering = FALSE
	return renders

/// Adds a render of the dummy facing each way to entries, in the page's turning order.
/proc/render_species_facings(list/entries, mob/living/carbon/human/dummy, icon_key)
	// A dummy takes its height as one filter over the whole body, as character setup's does, and only when asked.
	dummy.apply_height(dummy, ENTIRE_BODY)
	var/datum/universal_icon/template = get_flat_uni_icon(dummy, UP)
	dummy.dna.species.preview_icon_after_effects(template, dummy)
	template = species_page_height(template, dummy)
	var/list/recipes = uni_icon_facings_json(template, GLOB.character_preview_facings)
	// What no sprite on the body shows goes on each facing's recipe as one more blend, where it is facing that way.
	var/list/held = dummy.dna.species.species_page_held_icon(dummy)
	var/list/held_recipes = held && uni_icon_facings_json(held[1], GLOB.character_preview_facings)
	for (var/facing, dir in GLOB.character_preview_facings)
		var/list/entry = json_decode(recipes[facing])
		if (held)
			var/list/at = held[2]["[dir]"]
			entry["transform"] += list(list("type" = RUSTG_ICONFORGE_BLEND_ICON, "icon" = json_decode(held_recipes[facing]), "blend_mode" = ICON_OVERLAY, "x" = at[1], "y" = at[2]))
		entries["[icon_key]-[facing]"] = entry

/**
 * Something the species page draws over this species' render, which no sprite on the body shows - a Dullahan's head in
 * its hand. Every facing shares the one render, so this is blended onto each where it goes facing that way.
 *
 * Arguments:
 * - dummy - The dummy the render was flattened from.
 *
 * Returns list(universal icon flattened facing UP, list("[dir]" = list(x, y)) - its lower left on the render, facing each
 * way), or null for nothing.
 */
/datum/species/proc/species_page_held_icon(mob/living/carbon/human/dummy)
	return null

/**
 * A dummy's flat render with the rows its height filters move moved in it, as the game draws them, so a species
 * shorter or taller than average stands as high on the page as in the round. A flatten leaves filters out.
 *
 * Each run of rows the filters move, as character_preview_rows() gives them, is cleared and filled with the band of
 * the flat render's rows it shows, if any. A render that isn't a tile, or whose filters move more than whole rows, is
 * left as it is.
 */
/proc/species_page_height(datum/universal_icon/flat, mob/living/carbon/human/dummy)
	var/list/runs = character_preview_rows(dummy, ICON_SIZE_Y, 0)
	var/list/box = character_preview_flat_box(flat)
	if (!length(runs) || box[3] != ICON_SIZE_X || box[4] != ICON_SIZE_Y)
		return flat
	var/datum/universal_icon/drawn = flat.copy()
	for (var/list/run as anything in runs)
		// Runs count rows down from the top, and an icon counts them up from 1 at the bottom.
		var/bottom = ICON_SIZE_Y - run[1] - run[2] + 1
		drawn.draw_box("#00000000", 1, bottom, ICON_SIZE_X, bottom + run[2] - 1)
		if (run[3] != -1)
			var/datum/universal_icon/band = flat.copy()
			band.crop(1, ICON_SIZE_Y - run[3] - run[2] + 1, ICON_SIZE_X, ICON_SIZE_Y - run[3])
			drawn.blend_icon(band, ICON_OVERLAY, 1, bottom)
	return drawn
