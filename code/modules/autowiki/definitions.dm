/// Declarative inspection with explicitly labeled, bounded initialized adapters.
GLOBAL_LIST_EMPTY(autowiki_vending_definitions)
GLOBAL_LIST_EMPTY(autowiki_render_profiles)
/atom
	/// Public documentation is opt-in. Internal and inherited variants need an explicit scope.
	var/documentation_visibility = "unknown"
	/// Stable public ID and family can survive a source type move.
	var/documentation_id = null
	var/documentation_family = null

/datum/autowiki_export/proc/export_definitions()
	for(var/path in subtypesof(/datum/outfit))
		// These datums describe equipment; this does not equip a mob or instantiate their item lists.
		var/datum/outfit/outfit = new path
		var/list/data = fields(outfit, list("name", "uniform", "suit", "back", "belt", "gloves", "shoes", "head", "mask", "neck", "ears", "glasses", "l_pocket", "r_pocket", "suit_store", "l_hand", "r_hand", "backpack_contents", "belt_contents", "implants"))
		data["scope"] = "Constructed outfit definition; pre_equip, post_equip, species and player choices can alter equipment"
		write_record("outfit", path, data)
		qdel(outfit)
		CHECK_TICK
	for(var/obj/machinery/vending/definition as anything in subtypesof(/obj/machinery/vending))
		var/list/captured = GLOB.autowiki_vending_definitions[definition]
		if(captured)
			write_record("vending", definition, captured)
			continue
		var/list/deferred = list()
		var/list/data = list(
			"name" = value(initial(definition.name)),
			"desc" = value(initial(definition.desc)),
			"products" = initial_list(initial(definition.products), "products", deferred),
			"product_categories" = initial_list(initial(definition.product_categories), "product_categories", deferred),
			"contraband" = initial_list(initial(definition.contraband), "contraband", deferred),
			"premium" = initial_list(initial(definition.premium), "premium", deferred),
			"default_price" = value(initial(definition.default_price)),
			"extra_price" = value(initial(definition.extra_price)),
			"scope" = "Definition defaults; procedural initialization and overrides can differ",
		)
		data["deferred_fields"] = value(deferred)
		write_record("vending", definition, data)
		CHECK_TICK
	for(var/path in GLOB.species_prototypes)
		var/datum/species/species = GLOB.species_prototypes[path]
		var/list/data = fields(species, list("name", "id", "coldmod", "heatmod", "bodytemp_heat_damage_limit", "bodytemp_cold_damage_limit", "inherent_traits", "mutant_organs"))
		data["scope"] = "Registered species prototype; equipment, organs, traits and runtime modifiers apply"
		write_record("species", path, data)
		CHECK_TICK
	for(var/obj/projectile/definition as anything in subtypesof(/obj/projectile))
		var/list/deferred = list()
		var/list/data = list(
			"name" = value(initial(definition.name)),
			"damage" = value(initial(definition.damage)),
			"damage_type" = value(initial(definition.damage_type)),
			"armor_flag" = value(initial(definition.armor_flag)),
			"range" = value(initial(definition.range)),
			"speed" = value(initial(definition.speed)),
			"stamina" = value(initial(definition.stamina)),
			"scope" = "Definition defaults; procedural initialization and overrides can differ",
		)
		data["deferred_fields"] = value(deferred)
		write_record("projectile", definition, data)
		CHECK_TICK
	for(var/datum/material/definition as anything in subtypesof(/datum/material))
		var/list/deferred = list()
		var/list/data = list(
			"name" = value(initial(definition.name)),
			"desc" = value(initial(definition.desc)),
			"scope" = "Definition defaults; procedural initialization and overrides can differ",
		)
		data["deferred_fields"] = value(deferred)
		write_record("material", definition, data)
		CHECK_TICK
	for(var/path in GLOB.operations.operations_by_typepath)
		var/datum/surgery_operation/operation = GLOB.operations.operations_by_typepath[path]
		if(operation.operation_flags & OPERATION_NO_WIKI)
			continue
		var/list/data = fields(operation, list("name", "desc", "implements", "operation_flags"))
		data["requirements"] = value(operation.get_requirements())
		data["scope"] = "Shared gameplay requirement descriptions; patient state and operation hooks apply"
		write_record("surgery", path, data)
	for(var/path in GLOB.armor_by_type)
		var/datum/armor/armor = GLOB.armor_by_type[path]
		write_record("armor", path, list("ratings" = value(armor.get_rating_list()), "scope" = "Shared armor rating accessor; penetration, damage source and runtime modifiers apply"))
	for(var/access in SSid_access.desc_by_access)
		write_record("dictionary", "/documentation/access/[access]", list("name" = SSid_access.get_access_desc(access), "category" = "access", "value" = access, "documentation_visibility" = "public"))
	// Bounded fixtures exercise the same compatibility predicate used when loading a weapon.
	var/obj/item/gun/ballistic/automatic/pistol/pistol = new
	var/accepts_nine = pistol.accepts_magazine(/obj/item/ammo_box/magazine/m9mm)
	var/rejects_ten = !pistol.accepts_magazine(/obj/item/ammo_box/magazine/m10mm)
	if(!accepts_nine || !rejects_ten)
		CRASH("Documented pistol magazine compatibility changed; review the fixture and reference")
	write_record("scenario", "/documentation/pistol_magazine_compatibility", list("name" = "Makarov Magazine Compatibility", "subject" = "[/obj/item/gun/ballistic/automatic/pistol]", "result" = "passed", "conditions" = "Initialized default pistol. Accepts a 9mm magazine type and rejects a 10mm magazine type. Insertion still requires a held magazine and transfer permission.", "evidence" = "accepts_magazine is used by insert_magazine; positive and negative cases exercised"))
	qdel(pistol)
	export_chemistry_scenarios()
	export_construction_scenarios()
	return TRUE

/datum/autowiki_export/proc/export_construction_scenarios()
	var/obj/item/circuitboard/machine/bsa/back/board = new
	var/obj/structure/frame/machine/frame = new
	var/obj/item/storage/part_replacer/replacer = new
	var/mob/living/carbon/human/operator = new
	frame.circuit = board
	frame.circuit_added(board)
	var/required_type = /datum/stock_part/capacitor/tier4
	var/required_count = frame.req_components[required_type]
	var/obj/item/stock_parts/capacitor/basic = new(replacer)
	frame.install_parts_from_part_replacer(operator, replacer, no_sound = TRUE)
	if(frame.req_components[required_type] != required_count || basic.loc != replacer)
		CRASH("RPED bypassed the documented tier-four construction requirement")
	var/obj/item/stock_parts/capacitor/quadratic/advanced = new(replacer)
	frame.install_parts_from_part_replacer(operator, replacer, no_sound = TRUE)
	if(frame.req_components[required_type] != required_count - 1 || advanced in replacer.contents)
		CRASH("RPED failed to install the documented tier-four component")
	if(machine_component_accepts(required_type, basic.type) || !machine_component_accepts(required_type, /obj/item/stock_parts/capacitor/quadratic))
		CRASH("Manual and RPED component type rules disagree")
	if(!machine_component_accepts(/obj/item/stack/ore/bluespace_crystal, /obj/item/stack/sheet/bluespace_crystal) || machine_component_accepts(/obj/item/stack/ore/bluespace_crystal, /obj/item/stack/sheet/iron))
		CRASH("Documented construction alternatives changed")
	// Installed stock-part datums are shared singletons, not fixture-owned objects.
	frame.components = list(board)
	qdel(frame)
	qdel(replacer)
	qdel(operator)
	write_record("scenario", "/documentation/machine_component_compatibility", list("name" = "Machine Construction Component Compatibility", "subject" = "[/obj/item/circuitboard/machine/bsa/back]", "result" = "passed", "conditions" = "The BSA generator board requires tier-four capacitors. An RPED leaves a tier-one capacitor unused and installs a tier-four capacitor. Manual insertion uses the same component type rule. Bluespace sheets can substitute for ore; iron cannot. The machine is not built or operated in this fixture.", "evidence" = "Actual frame.install_parts_from_part_replacer with positive and insufficient-tier cases; shared manual component and alternative type checks"))

/datum/autowiki_export/proc/export_chemistry_scenarios()
	var/datum/chemical_reaction/reaction = GLOB.chemical_reactions_list[/datum/chemical_reaction/medicine/synthflesh]
	var/datum/reagents/holder = new(100)
	holder.chem_temp = 310
	holder.ph = 7
	if(!reaction.meets_start_conditions(holder))
		CRASH("Synthflesh no longer accepts the documented 310 K and pH 7 fixture")
	holder.ph = 1
	if(reaction.meets_start_conditions(holder))
		CRASH("Synthflesh start conditions accepted pH below the documented range")
	holder.ph = 14
	if(reaction.meets_start_conditions(holder))
		CRASH("Synthflesh start conditions accepted pH above the documented range")
	holder.ph = 7
	holder.chem_temp = 200
	if(reaction.meets_start_conditions(holder))
		CRASH("Synthflesh start conditions accepted temperature below the documented minimum")
	qdel(holder)
	write_record("scenario", "/documentation/synthflesh_conditions", list("name" = "Synthflesh Start Conditions", "subject" = "[/datum/chemical_reaction/medicine/synthflesh]", "result" = "passed", "conditions" = "310 K and pH 7 accepted. 200 K, pH 1 and pH 14 rejected. This checks start conditions, not reaction yield or clinical effectiveness.", "evidence" = "Shared meets_start_conditions gameplay predicate; positive and three negative cases"))
	var/obj/item/reagent_containers/cup/beaker/large/beaker = new
	var/datum/reagents/mixture = beaker.reagents
	mixture.add_reagent(/datum/reagent/carbon, 1, no_react = TRUE)
	mixture.add_reagent(/datum/reagent/medicine/c2/libital, 1, no_react = TRUE)
	mixture.chem_temp = 310
	mixture.ph = 7
	mixture.handle_reactions()
	if(mixture.has_reagent(/datum/reagent/medicine/c2/synthflesh))
		CRASH("Synthflesh formed without the documented blood ingredient")
	mixture.add_reagent(/datum/reagent/blood, 1, no_react = TRUE)
	mixture.chem_temp = 310
	mixture.ph = 7
	mixture.handle_reactions()
	for(var/attempt in 1 to 30)
		if(mixture.has_reagent(/datum/reagent/medicine/c2/synthflesh) || !mixture.is_reacting)
			break
		sleep(1)
	if(!mixture.has_reagent(/datum/reagent/medicine/c2/synthflesh))
		CRASH("Synthflesh fixture failed: MC [MC_RUNNING()], reacting [mixture.is_reacting], holder flags [mixture.flags], blood [mixture.get_reagent_amount(/datum/reagent/blood)], carbon [mixture.get_reagent_amount(/datum/reagent/carbon)], Libital [mixture.get_reagent_amount(/datum/reagent/medicine/c2/libital)]")
	qdel(beaker)
	write_record("scenario", "/documentation/synthflesh_inputs", list("name" = "Synthflesh Ingredient Fixture", "subject" = "[/datum/chemical_reaction/medicine/synthflesh]", "result" = "passed", "conditions" = "One unit each of blood, carbon and Libital at 310 K and pH 7 begins producing Synthflesh. Without blood it does not. A 100-unit reagent holder is used; final yield, reaction time and treatment effects are not asserted.", "evidence" = "Production handle_reactions with actual reagents; positive and missing-ingredient cases"))
