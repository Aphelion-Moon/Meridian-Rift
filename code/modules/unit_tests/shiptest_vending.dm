/// Every Shiptest wardrobe garment is a product of exactly one vending machine, and a recolorable one gets the paint button
/datum/unit_test/shiptest_vending

/datum/unit_test/shiptest_vending/Run()
	// We take the wardrobe from the type tree - every loadout entry whose garment draws from the wardrobe's icon, and every style of its family
	var/wardrobe_icon = 'modular_aphelion/modules/shiptest_clothing/icons/item.dmi'
	// A colour style names its garment; a fixed-colour one draws the garment's own inventory state
	var/list/garments_by_state = list()
	for(var/obj/item/wardrobe_type as anything in valid_subtypesof(/obj/item))
		if(wardrobe_type::icon == wardrobe_icon)
			garments_by_state[wardrobe_type::icon_state] = wardrobe_type
	var/list/garments = list()
	for(var/item_path, entry in GLOB.all_loadout_datums)
		var/datum/loadout_item/loadout = entry
		var/obj/item/garment_type = item_path
		if(garment_type::icon != wardrobe_icon)
			continue
		garments[garment_type] = TRUE
		if(!ispath(loadout.reskin_datum, /datum/atom_skin/shiptest))
			continue
		for(var/datum/atom_skin/shiptest/style as anything in valid_direct_subtypesof(loadout.reskin_datum))
			garments[style::greyscale_item_path || garments_by_state[style::new_icon_state]] = TRUE
	TEST_ASSERT(length(garments), "No loadout entry offers a Shiptest wardrobe garment")
	// A family's members are reparented away from its abstract node, so we look for the node among all abstract types
	var/list/abstract_types = get_abstract_types()

	// Garment type to list(machine type = how many of its records sell it), read from every machine as it builds its stock
	var/list/stockists = list()
	for(var/obj/machinery/vending/vendor_type as anything in subtypesof(/obj/machinery/vending))
		var/obj/machinery/vending/vendor = new vendor_type()
		for(var/datum/data/vending_product/record as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
			var/obj/item/product = record.product_path
			if(!garments[product])
				if(product::icon == wardrobe_icon)
					TEST_FAIL("[vendor_type] sells [product], which no wardrobe loadout entry or style offers (a hood is not a product)")
				else if(abstract_types[product])
					TEST_FAIL("[vendor_type] sells [product], an abstract type")
				continue
			if(product::greyscale_config && !record.colorable)
				TEST_FAIL("[vendor_type] sells the recolorable [product] without the paint button")
			var/list/machines = stockists[product]
			if(!machines)
				machines = list()
				stockists[product] = machines
			machines[vendor_type] += 1
		qdel(vendor)

	for(var/garment_type in garments)
		var/list/machines = stockists[garment_type]
		if(!machines)
			TEST_FAIL("[garment_type] is not sold by any vending machine")
			continue
		// We count a machine that inherits the garment from its parent machine as its parent's shelf
		var/list/own_machines = list()
		for(var/vendor_type in machines)
			var/inherited = FALSE
			for(var/other_type in machines)
				if(other_type != vendor_type && ispath(vendor_type, other_type))
					inherited = TRUE
					break
			if(!inherited)
				own_machines += vendor_type
		if(length(own_machines) != 1)
			TEST_FAIL("[garment_type] must be sold by exactly one vending machine, not [english_list(own_machines)]")
			continue
		if(machines[own_machines[1]] != 1)
			TEST_FAIL("[own_machines[1]] lists [garment_type] [machines[own_machines[1]]] times")
