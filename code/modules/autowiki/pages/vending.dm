/datum/autowiki/vending
	page = "Template:Autowiki/Content/VendingMachines"

/datum/autowiki/vending/generate()
	var/output = ""


	// `powered()` checks if its in a null loc to say it's not powered.
	// So we put it inside, something
	var/obj/parent = new
	var/datum/autowiki_export/inspection = new

	for (var/obj/machinery/vending/vending_type as anything in sort_list(subtypesof(/obj/machinery/vending), GLOBAL_PROC_REF(cmp_typepaths_asc)))
		var/obj/machinery/vending/vending_machine = new vending_type(parent)
		var/list/captured = inspection.fields(vending_machine, list("name", "desc", "products", "product_categories", "contraband", "premium", "default_price", "extra_price"))
		for(var/field in vending_machine.documentation_dynamic_fields)
			if(!(field in captured))
				CRASH("Unknown dynamic vending documentation field [field] on [vending_type]")
			captured[field] = null
		captured["dynamic_fields"] = inspection.value(vending_machine.documentation_dynamic_fields)
		captured["scope"] = "Initialized vendor in the documentation fixture; inventory hooks, map settings and prices can differ"
		GLOB.autowiki_vending_definitions[vending_type] = captured
		if(!length(vending_machine.products) && !length(vending_machine.contraband) && !length(vending_machine.premium))
			qdel(vending_machine)
			continue // No fixed inventory to document.
		vending_machine.use_power = FALSE
		vending_machine.update_icon(UPDATE_ICON_STATE)

		// Stable source identity retains variants even when names or inventories overlap.
		var/filename = "vending_[md5("[vending_type]")]"

		output += include_template("Autowiki/VendingMachine", list(
			"icon" = escape_value(filename),
			"name" = escape_text(format_text(vending_machine.name)),
			"products" = format_documented_products(vending_machine, "products"),
			"contraband" = format_documented_products(vending_machine, "contraband"),
			"premium" = format_documented_products(vending_machine, "premium"),
		))

		// It would be cool to make this support gifs someday, but not now
		var/icon/initialized_image = getFlatIcon(vending_machine, no_anim = TRUE)
		upload_icon(initialized_image, filename)
		if(vending_type != initial(vending_type.abstract_type) && initial(vending_type.name))
			// getFlatIcon can retain a cached resource with zero in-memory dimensions. Its serialized PNG is authoritative.
			var/profile_filename = "appearance-[md5("[vending_type]:initialized-vendor-south")].png"
			if(!fcopy("data/autowiki_files/[filename].png", "[inspection.icon_directory]/[profile_filename]"))
				CRASH("Cannot stage initialized vendor appearance [vending_type]")
			GLOB.autowiki_render_profiles[vending_type] = list("initialized-vendor-south" = list("file" = profile_filename, "source" = "[initial(vending_type.icon)]", "state" = vending_machine.icon_state || "", "scope" = "Initialized vendor with power requirement disabled, south-facing first frame. Map and runtime overlays can differ."))

		qdel(vending_machine)

	qdel(parent)

	return output

/datum/autowiki/vending/proc/format_documented_products(obj/machinery/vending/vendor, field)
	if(field in vendor.documentation_dynamic_fields)
		return "Inventory varies by machine; it is generated at runtime."
	return format_product_list(vendor.vars[field])

/datum/autowiki/vending/proc/format_product_list(list/product_list)
	var/output = ""

	for (var/obj/product_path as anything in product_list)
		output += include_template("Autowiki/VendingMachineProduct", list(
			"name" = escape_value(capitalize(format_text(initial(product_path.name)))),
			"amount" = product_list[product_path],
		))

	return output
