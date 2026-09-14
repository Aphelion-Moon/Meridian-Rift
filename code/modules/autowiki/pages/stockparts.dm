/// Automtically generated string list of stock part templates and relevant data for the /tg/station wiki
/datum/autowiki/stock_parts
	page = "Template:Autowiki/Content/StockParts"

	var/list/battery_whitelist = list(
		/obj/item/stock_parts/power_store/cell,
		/obj/item/stock_parts/power_store/cell/high,
		/obj/item/stock_parts/power_store/cell/super,
		/obj/item/stock_parts/power_store/cell/hyper,
		/obj/item/stock_parts/power_store/cell/bluespace,
		/obj/item/stock_parts/power_store/battery,
		/obj/item/stock_parts/power_store/battery/high,
		/obj/item/stock_parts/power_store/battery/super,
		/obj/item/stock_parts/power_store/battery/hyper,
		/obj/item/stock_parts/power_store/battery/bluespace,
	)

/datum/autowiki/stock_parts/generate()
	var/output = ""

	for(var/part_type in valid_subtypesof(/obj/item/stock_parts))
		if(!battery_whitelist.Find(part_type) && ispath(part_type, /obj/item/stock_parts/power_store))
			continue

		var/obj/item/stock_parts/stock_part = new part_type()

		var/list/recipes = list()
		for(var/path in SSresearch.techweb_designs)
			var/datum/design/recipe = SSresearch.techweb_designs[path]
			if(recipe.build_path == stock_part.type)
				recipes += recipe
		if(!length(recipes))
			qdel(stock_part)
			continue
		var/list/nodes = list()
		var/list/sources = list()
		var/list/material_options = list()
		for(var/datum/design/recipe as anything in recipes)
			sources |= generate_source_list(recipe)
			material_options |= generate_material_list(recipe)
			for(var/node_path in SSresearch.techweb_nodes)
				var/datum/techweb_node/node = SSresearch.techweb_nodes[node_path]
				if(recipe.type in node.unlocked_designs)
					nodes |= node.display_name
		var/list/entry_contents = list(
			"name" = escape_text(stock_part.name),
			"icon" = create_icon(stock_part),
			"desc" = escape_text(stock_part.desc),
			"tier" = stock_part.rating,
			"sources" = escape_text(sources.Join("; ")),
			"node" = escape_text(length(nodes) ? nodes.Join("; ") : "No research node required or registered"),
			"materials" = material_options.Join("<br>OR<br>"),
		)
		output += include_template("Autowiki/StockPart", entry_contents)
		qdel(stock_part)
	return output

/datum/autowiki/stock_parts/proc/create_icon(obj/item/stock_parts/stock_part)
	var/filename = SANITIZE_FILENAME(escape_value(stock_part.icon_state))
	upload_icon(icon(stock_part.icon, stock_part.icon_state, SOUTH, 1, FALSE), filename)

	return "Autowiki-[filename].png"

/datum/autowiki/stock_parts/proc/generate_source_list(datum/design/recipe)
	var/list/source_list = list()

	if(recipe.build_type & PROTOLATHE)
		source_list.Add("Protolathe")

	if(recipe.build_type & AWAY_LATHE)
		source_list.Add("Ancient Protolathe")

	if(recipe.build_type & AUTOLATHE)
		source_list.Add("Autolathe")

	return source_list.Join(", ")

/datum/autowiki/stock_parts/proc/generate_material_list(datum/design/recipe)
	var/list/materials = list()

	for(var/datum/material/ingredient, amount in recipe.materials)
		materials += "[amount] [ingredient.name]"

	return materials.Join("<br>")
