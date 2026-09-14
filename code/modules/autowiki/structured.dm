/// Versioned machine-readable game facts. Generated only in the isolated AUTOWIKI world.
/// This contract describes source defaults, not live round state or server policy.
/datum/autowiki_export
	var/list/counts = list()
	var/list/seen = list()
	var/output_path = "data/autowiki-data.jsonl"
	var/icon_directory = "data/autowiki-entity-icons"
	var/failed = FALSE
	var/value_context = ""

/datum/autowiki_export/proc/initial_value(value, context)
	value_context = context
	return src.value(value)

/// BYOND list initializer expressions can require an instance. Do not instantiate arbitrary machinery to evaluate them.
/datum/autowiki_export/proc/initial_list(value, field, list/deferred)
	if(islist(value) || isnull(value))
		return src.value(value)
	deferred += field
	return null

/datum/autowiki_export/proc/write_record(kind, id, list/fields)
	if(!("documentation_visibility" in fields))
		// These domains already have public source references. World availability remains qualified.
		fields["documentation_visibility"] = (kind in list("research_node", "design", "reagent", "reaction", "crafting_recipe", "job", "material", "surgery", "scenario")) ? "public" : "unknown"
	var/key = "[kind]:[id]"
	if(seen[key] || !islist(fields))
		failed = TRUE
		CRASH("Duplicate structured Autowiki record [key]")
	seen[key] = TRUE
	counts[kind] = (counts[kind] || 0) + 1
	text2file(json_encode(list("kind" = kind, "id" = "[id]", "fields" = fields)), output_path)

/// Preserve DM lists as explicit key/value entries; do not silently reinterpret mixed lists as JSON objects.
/datum/autowiki_export/proc/value(value, depth = 0)
	if(depth > 12)
		failed = TRUE
		CRASH("Autowiki value nesting exceeds the schema limit")
	if(isnull(value) || isnum(value) || istext(value))
		return value
	if(ispath(value) || isfile(value))
		return "[value]"
	if(islist(value))
		var/list/result = list()
		var/list/source = value
		for(var/key in source)
			// Numeric array members cannot be safely used as associative indexes.
			var/associated = isnum(key) ? null : source[key]
			result += list(list("key" = src.value(key, depth + 1), "value" = src.value(associated, depth + 1)))
		return result
	if(istype(value, /datum))
		var/datum/reference = value
		return "[reference.type]"
	failed = TRUE
	CRASH("Unsupported structured Autowiki value at [value_context]")

/datum/autowiki_export/proc/fields(datum/source, list/names)
	var/list/result = list()
	for(var/name in names)
		if(!(name in source.vars))
			failed = TRUE
			CRASH("Autowiki field [name] no longer exists on [source.type]")
		result[name] = value(source.vars[name])
	return result

/datum/autowiki_export/proc/generate()
	fdel(output_path)
	text2file(json_encode(list("kind" = "header", "schema_version" = 2, "profile" = "source-defaults", "time_unit" = "decisecond", "appearance_profile" = "initial-south-first-frame", "compiler" = "[DM_VERSION].[DM_BUILD]", "runtime" = "[world.byond_version].[world.byond_build]")), output_path)
	if(!export_entities() || !export_research() || !export_chemistry() || !export_crafting() || !export_cargo() || !export_jobs() || !export_definitions() || failed)
		CRASH("Structured Autowiki export did not complete")
	// Consumers reject incomplete output: this trailer is written only after every exporter returns.
	text2file(json_encode(list("kind" = "complete", "counts" = counts)), output_path)

/datum/autowiki_export/proc/export_entities()
	for(var/atom/entity as anything in valid_subtypesof(/obj))
		if(!(ispath(entity, /obj/item) || ispath(entity, /obj/machinery) || ispath(entity, /obj/structure)))
			continue
		if(!initial(entity.name))
			continue
		var/list/deferred = list()
		var/list/board_profile
		var/list/data = list(
			"name" = initial(entity.name),
			"documentation_visibility" = initial(entity.documentation_visibility),
			"documentation_id" = initial(entity.documentation_id),
			"documentation_family" = initial(entity.documentation_family),
			"armor_type" = initial_value(initial(entity.armor_type), "entity.armor_type for [entity]"),
			"description" = initial(entity.desc),
			"parent" = "[initial(entity.parent_type)]",
			"icon_source" = initial_value(initial(entity.icon), "entity.icon for [entity]"),
			"icon_state" = initial(entity.icon_state),
			"color" = initial_value(initial(entity.color), "entity.color for [entity]"),
			"greyscale_config" = initial_value(initial(entity.greyscale_config), "entity.greyscale_config for [entity]"),
			"greyscale_colors" = initial_value(initial(entity.greyscale_colors), "entity.greyscale_colors for [entity]"),
			"density" = initial(entity.density),
			"appearance_scope" = "initial appearance; initialization, components and runtime overlays can differ",
		)
		if(ispath(entity, /obj/item))
			var/obj/item/item_type = entity
			data["weight_class"] = initial(item_type.w_class)
			data["force"] = initial(item_type.force)
			data["throwforce"] = initial(item_type.throwforce)
			data["tool_behavior"] = initial(item_type.tool_behaviour)
			data["tool_speed"] = initial(item_type.toolspeed)
		if(ispath(entity, /obj/item/ammo_casing))
			var/obj/item/ammo_casing/casing = entity
			data["projectile_type"] = initial_value(initial(casing.projectile_type), "casing.projectile_type for [entity]")
		if(ispath(entity, /obj/item/ammo_box))
			var/obj/item/ammo_box/box = entity
			data["ammo_type"] = initial_value(initial(box.ammo_type), "box.ammo_type for [entity]")
			data["max_ammo"] = initial(box.max_ammo)
		if(ispath(entity, /obj/item/gun/ballistic))
			var/obj/item/gun/ballistic/gun = entity
			data["mag_type"] = initial_value(initial(gun.accepted_magazine_type), "gun.accepted_magazine_type for [entity]")
		if(ispath(entity, /obj/machinery))
			var/obj/machinery/machine = entity
			data["use_power"] = initial(machine.use_power)
			data["idle_power_usage"] = initial(machine.idle_power_usage)
			data["active_power_usage"] = initial(machine.active_power_usage)
			data["req_access"] = initial_list(initial(machine.req_access), "req_access", deferred)
			data["req_one_access"] = initial_list(initial(machine.req_one_access), "req_one_access", deferred)
			data["circuitboard_type"] = initial_value(initial(machine.circuit), "machine.circuit for [entity]")
		var/datum/stock_part/stock_part = GLOB.stock_part_datums_per_object[entity]
		if(stock_part)
			data["stock_part_tier"] = stock_part.tier
			data["stock_part_energy_rating"] = stock_part.energy_rating()
			data["stock_part_base_type"] = value(stock_part.physical_object_base_type)
		if(ispath(entity, /obj/item/circuitboard/machine))
			// Only circuit-board definitions are initialized here, never their machines.
			var/obj/item/circuitboard/machine/board = new entity
			var/list/components = list()
			var/list/alternatives = list()
			for(var/component in board.req_components)
				if(!board.req_components[component])
					continue
				var/item_type = machine_component_item_type(component)
				if(!item_type)
					CRASH("Unknown construction component [component] on [entity]")
				components[item_type] = (components[item_type] || 0) + board.req_components[component]
				var/alternative_type = machine_component_alternative_type(component)
				if(alternative_type)
					alternatives[alternative_type] = (alternatives[alternative_type] || 0) + board.req_components[component]
			data["construction_result"] = value(board.build_path)
			data["construction_components"] = value(components)
			data["construction_alternatives"] = value(alternatives)
			data["construction_needs_anchored"] = board.needs_anchored
			data["construction_specific_parts"] = board.specific_parts
			data["construction_scope"] = "Initialized machine-board defaults. Component item types match manual and RPED construction. Bluespace sheets can replace ore one-for-one. Counts exclude the board, frame and wiring; selected modes, configuration and completion hooks can alter construction."
			board.setDir(SOUTH)
			board_profile = write_render(entity, getFlatIcon(board, no_anim = TRUE), "initialized-machine-board-south", "[board.icon]", board.icon_state, "Initialized machine circuit board, south-facing first frame with greyscale and overlays; configuration and selected board modes can differ.")
			qdel(board)
		var/icon_file = initial(entity.icon)
		var/state = initial(entity.icon_state)
		if(initial(entity.greyscale_config) && initial(entity.greyscale_colors))
			icon_file = SSgreyscale.GetColoredIconByType(initial(entity.greyscale_config), initial(entity.greyscale_colors))
		if(icon_file && (state in icon_states(icon_file)))
			var/icon/rendered = icon(icon_file, state, SOUTH, 1)
			if(islist(initial(entity.color)))
				rendered.MapColors(arglist(initial(entity.color)))
			else if(initial(entity.color))
				rendered.Blend(initial(entity.color), ICON_MULTIPLY)
			// Materialize a complete raster; a bare cached icon may serialize as a DDMI resource reference.
			var/icon/raster = icon('icons/blanks/32x32.dmi', "nothing")
			raster.Scale(rendered.Width(), rendered.Height())
			raster.Blend(rendered, ICON_OVERLAY)
			var/filename = "entity-[md5("[entity]")].png"
			if(!fcopy(raster, "[icon_directory]/[filename]"))
				CRASH("Could not export entity icon [entity]")
			data["icon_file"] = filename
		else
			data["icon_file"] = null
			data["icon_status"] = "missing-initial-icon-state"
		if(failed)
			return FALSE
		data["deferred_fields"] = value(deferred)
		var/list/profiles = GLOB.autowiki_render_profiles[entity] || list()
		if(board_profile)
			profiles["initialized-machine-board-south"] = board_profile
		if(ispath(entity, /obj/item))
			var/obj/item/item_type = entity
			var/list/worn = equipment_render(item_type, initial(item_type.worn_icon), initial(item_type.worn_icon_state) || initial(item_type.icon_state), initial(item_type.greyscale_config_worn), "worn-layer-south")
			var/list/left = equipment_render(item_type, initial(item_type.lefthand_file), initial(item_type.inhand_icon_state), initial(item_type.greyscale_config_inhand_left), "left-hand-layer-south")
			var/list/right = equipment_render(item_type, initial(item_type.righthand_file), initial(item_type.inhand_icon_state), initial(item_type.greyscale_config_inhand_right), "right-hand-layer-south")
			if(worn)
				profiles["worn-layer-south"] = worn
			if(left)
				profiles["left-hand-layer-south"] = left
			if(right)
				profiles["right-hand-layer-south"] = right
		data["render_profiles"] = value(profiles)
		write_record("entity", entity, data)
		CHECK_TICK
	return TRUE

/datum/autowiki_export/proc/export_research()
	for(var/path in SSresearch.techweb_nodes)
		var/datum/techweb_node/node = SSresearch.techweb_nodes[path]
		if(!(node.node_flags & TECHWEB_NODE_WIKI) || !node.display_name)
			continue
		write_record("research_node", path, fields(node, list("display_name", "description", "node_flags", "prerequisite_nodes", "unlocked_designs", "research_costs", "required_experiments", "discount_experiments")))
	for(var/path in SSresearch.techweb_designs)
		var/datum/design/design = SSresearch.techweb_designs[path]
		if(!design.name)
			continue
		write_record("design", path, fields(design, list("name", "desc", "build_path", "make_reagent", "build_type", "materials", "reagents_list", "construction_time", "lathe_time_factor", "departmental_flags", "unlocked_by", "fixed_cost_efficiency")))
	return TRUE

/datum/autowiki_export/proc/export_chemistry()
	for(var/path in GLOB.chemical_reagents_list)
		var/datum/reagent/reagent = GLOB.chemical_reagents_list[path]
		if(!reagent.name)
			continue
		var/list/data = fields(reagent, list("name", "description", "color", "ph", "metabolization_rate", "overdose_threshold", "addiction_types", "chemical_flags", "inverse_chem", "inverse_chem_val"))
		data["color"] = initial(reagent.color)
		data["color_scope"] = "definition default; runtime color can vary"
		write_record("reagent", path, data)
	for(var/path in GLOB.chemical_reactions_list)
		var/datum/chemical_reaction/reaction = GLOB.chemical_reactions_list[path]
		var/list/data = fields(reaction, list("results", "required_reagents", "required_catalysts", "required_container", "required_container_accepts_subtypes", "mob_react", "is_cold_recipe", "required_temp", "optimal_temp", "overheat_temp", "optimal_ph_min", "optimal_ph_max", "determin_ph_range", "purity_min", "rate_up_lim", "reaction_flags"))
		for(var/field in reaction.documentation_dynamic_fields)
			if(!(field in data))
				failed = TRUE
				CRASH("Unrecognized dynamic reaction field [field] on [path]")
			data[field] = null
		data["dynamic_fields"] = value(reaction.documentation_dynamic_fields)
		write_record("reaction", path, data)
	return TRUE

/datum/autowiki_export/proc/export_crafting()
	for(var/datum/crafting_recipe/recipe as anything in GLOB.crafting_recipes)
		if(!recipe.name || !recipe.result || recipe.non_craftable)
			continue
		// Balance changes must not rename records. Dynamic stack recipes need their material/output identity.
		var/id = "[recipe.type]"
		if(istype(recipe, /datum/crafting_recipe/stack))
			id += ":[recipe.result]:[length(recipe.reqs) ? recipe.reqs[1] : "none"]"
		write_record("crafting_recipe", id, fields(recipe, list("name", "desc", "result", "result_amount", "reqs", "tool_behaviors", "tool_paths", "time", "parts", "chem_catalysts", "machinery", "structures", "category", "crafting_flags")))
	return TRUE

/datum/autowiki_export/proc/export_cargo()
	for(var/path in SSshuttle.supply_packs)
		var/datum/supply_pack/pack = SSshuttle.supply_packs[path]
		if(!pack.name)
			continue
		var/list/data = fields(pack, list("name", "desc", "group", "cost", "contains", "crate_type", "access", "access_any", "access_view", "order_flags", "test_ignored"))
		data["documentation_visibility"] = (pack.order_flags & (ORDER_INVISIBLE|ORDER_ADMIN_SPAWNED)) ? "hidden" : "public"
		write_record("supply_pack", path, data)
	return TRUE

/datum/autowiki_export/proc/export_jobs()
	for(var/datum/job/job as anything in SSjob.all_occupations)
		if(!(job.job_flags & JOB_NEW_PLAYER_JOINABLE))
			continue
		// Do not export player counts, assignments, identities, credentials or live-round access decisions.
		write_record("job", job.type, fields(job, list("title", "description", "paycheck", "paycheck_department", "departments_list", "outfit", "exp_requirements", "exp_required_type", "minimal_player_age", "job_flags", "config_tag")))
	return TRUE

/// Reusable raster profiles preserve their source identity and explicitly qualify what was rendered.
/datum/autowiki_export/proc/write_render(entity, icon/rendered, profile, source, state, scope)
	// Cached getFlatIcon resources can report zero in-memory dimensions. The
	// packager validates the serialized PNG, including dimensions and pixels.
	var/icon/raster = rendered
	if(rendered.Width() > 0 && rendered.Height() > 0)
		raster = icon('icons/blanks/32x32.dmi', "nothing")
		raster.Scale(rendered.Width(), rendered.Height())
		raster.Blend(rendered, ICON_OVERLAY)
	var/filename = "appearance-[md5("[entity]:[profile]")].png"
	if(!fcopy(raster, "[icon_directory]/[filename]"))
		CRASH("Could not export appearance profile [entity]:[profile]")
	return list("file" = filename, "source" = source, "state" = state || "", "scope" = scope)

/datum/autowiki_export/proc/equipment_render(obj/item/entity, file, state, greyscale_type, profile)
	var/source = "[file]"
	if(greyscale_type && initial(entity.greyscale_colors))
		file = SSgreyscale.GetColoredIconByType(greyscale_type, initial(entity.greyscale_colors))
		source = "greyscale:[greyscale_type]"
	if(!file || !state || !(state in icon_states(file)))
		return null
	var/icon/rendered = icon(file, state, SOUTH, 1)
	if(islist(initial(entity.color)))
		rendered.MapColors(arglist(initial(entity.color)))
	else if(initial(entity.color))
		rendered.Blend(initial(entity.color), ICON_MULTIPLY)
	return write_render(entity, rendered, profile, source, state, "Configured equipment sprite layer, south-facing first frame and source tint. Excludes the wearer, species fitting, runtime overlays and animation.")
