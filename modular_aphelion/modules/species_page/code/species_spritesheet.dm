/**
 * Whole-body renders for the species page, facing each way: this sheet in uniform, and
 * /datum/asset/spritesheet_batched/species_full/body without.
 *
 * Nothing is drawn during init. Registering is empty, and the renders are drawn when a sheet is
 * first realized: by SSasset_loading in the lobby, a tick check at a time, or by the first player
 * to open the species page, whichever comes first. Sprites are named `[icon]-[dir]`, where icon is
 * the species' sanitized name, as the species preference's constant data sends it.
 */
/datum/asset/spritesheet_batched/species_full
	name = "species_full"
	/// Whether this sheet's renders wear the uniform.
	var/uniform = TRUE

/// Without uniform. Sent only once someone turns a specimen to its body.
/datum/asset/spritesheet_batched/species_full/body
	name = "species_body"
	uniform = FALSE

/datum/asset/spritesheet_batched/species_full/create_spritesheets()
	return

/datum/asset/spritesheet_batched/species_full/realize_spritesheets(yield)
	if (!length(entries))
		var/list/renders = get_species_page_renders()
		entries = uniform ? renders["uniform"] : renders["body"]
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
	var/list/recipes = uni_icon_facings_json(template, GLOB.species_page_facings)
	for (var/facing in recipes)
		entries["[icon_key]-[facing]"] = json_decode(recipes[facing])

/**
 * A dummy's flat render with the rows its height filters move moved in it, as the game draws them, so a species
 * shorter or taller than average stands as high on the page as in the round. A flatten leaves filters out.
 *
 * The render is put together again from bands of itself, each run of rows that shows a run of the flat render's rows
 * cropped from it and set in its place, as character_preview_rows() gives them; rows that show nothing are left out.
 * A render that isn't a tile, or whose filters move more than whole rows, is left as it is.
 */
/proc/species_page_height(datum/universal_icon/flat, mob/living/carbon/human/dummy)
	var/list/runs = character_preview_rows(dummy, ICON_SIZE_Y, 0)
	var/list/size = character_preview_flat_size(flat)
	if (!length(runs) || size[1] != ICON_SIZE_X || size[2] != ICON_SIZE_Y)
		return flat
	// Frame row + 1 -> the flat render's row it shows, or -1 for none, counting rows from the top.
	var/list/sources = new /list(ICON_SIZE_Y)
	for (var/row in 0 to ICON_SIZE_Y - 1)
		sources[row + 1] = row
	for (var/list/run as anything in runs)
		for (var/offset in 0 to run[2] - 1)
			sources[run[1] + offset + 1] = run[3] == -1 ? -1 : run[3] + offset
	var/datum/universal_icon/drawn = uni_icon('icons/blanks/32x32.dmi', "nothing")
	var/row = 0
	while (row < ICON_SIZE_Y)
		var/source = sources[row + 1]
		var/last = row
		while (source != -1 && last + 1 < ICON_SIZE_Y && sources[last + 2] == source + last + 1 - row)
			last++
		if (source != -1)
			// An icon counts its rows up from 1 at the bottom.
			var/count = last - row + 1
			var/datum/universal_icon/band = flat.copy()
			band.crop(1, ICON_SIZE_Y - source - count + 1, ICON_SIZE_X, ICON_SIZE_Y - source)
			drawn.blend_icon(band, ICON_OVERLAY, 1, ICON_SIZE_Y - row - count + 1)
		row = last + 1
	return drawn

/// The facings the species page turns through, in order.
GLOBAL_LIST_INIT(species_page_facings, list("south" = SOUTH, "west" = WEST, "north" = NORTH, "east" = EAST))
