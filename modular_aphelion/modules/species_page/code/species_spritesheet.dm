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
	var/static/list/facings = list("south" = SOUTH, "west" = WEST, "north" = NORTH, "east" = EAST)
	for (var/facing in facings)
		var/datum/universal_icon/render = get_flat_uni_icon(dummy, facings[facing])
		dummy.dna.species.preview_icon_after_effects(render, dummy)
		entries["[icon_key]-[facing]"] = render.to_list()
