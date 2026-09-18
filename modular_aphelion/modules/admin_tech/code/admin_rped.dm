// Originally from: NOVA MODULE ICSPAWNING https://github.com/Skyrat-SS13/Skyrat-tg/pull/104

/// Ceiling on how many of one type a single manufacture selection may produce.
#define RPED_MAX_BATCH_SIZE 100
/// How many of each type a manufacture selection produces before an admin changes it.
#define RPED_DEFAULT_BATCH_SIZE 30
/// How many of each starting part type the RPED is stocked with when it spawns.
#define RPED_STARTING_STOCK 30

/// Manufacture menu entry that empties the RPED's internal storage.
#define RPED_MENU_CLEAR_ALL "Clear All Items"
/// Manufacture menu entry that flips whether leftovers are destroyed after an upgrade.
#define RPED_MENU_TOGGLE_AUTO_CLEAR "Toggle Auto-Clear"
/// Manufacture menu entry that changes how many items a selection produces.
#define RPED_MENU_SET_BATCH_SIZE "Set Batch Size"

/**
 * # Subspace RPED
 *
 * An admin-only bluespace RPED that manufactures stock parts on the fly.
 *
 * Whenever it is used on a machine or an unbuilt frame it reads the required components off the
 * target's circuit and tops itself up first, so nothing is ever short a part. Admins can also
 * manufacture parts on demand, in bulk or by browsing subtypes, through the Alt-RMB menu.
 */
/obj/item/storage/part_replacer/bluespace/admin
	name = "subspace rped"
	desc = "A specialized bluespace RPED for technicians that can manufacture stock parts on the fly. Fills in whatever \
		a machine or an unbuilt frame is missing before it gets to work, so nothing is ever short a part."
	storage_type = /datum/storage/rped/bluespace/admin
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA
	/// Whether leftovers pulled out of an upgraded machine are destroyed rather than kept.
	var/auto_clear = TRUE
	/// How many of a given type the manufacture menu produces per selection.
	var/batch_size = RPED_DEFAULT_BATCH_SIZE
	/// Roots that pick_stock_part() is allowed to browse. Anything outside this list is rejected.
	var/static/list/valid_stock_part_types = list(
		/obj/item/circuitboard/machine,
		/obj/item/circuitboard/computer,
		/obj/item/stock_parts,
		/obj/item/stack/sheet,
		/obj/item/reagent_containers/cup/beaker,
	)
	/// Manufacture menu entries that batch out a fixed set of types. Add an entry here rather than another else-if.
	var/static/list/bulk_manufacture_options = list(
		"Tier 4 Parts" = list(
			/obj/item/stock_parts/capacitor/quadratic,
			/obj/item/stock_parts/scanning_module/triphasic,
			/obj/item/stock_parts/servo/femto,
			/obj/item/stock_parts/micro_laser/quadultra,
			/obj/item/stock_parts/matter_bin/bluespace,
			/obj/item/stock_parts/power_store/cell/bluespace,
			/obj/item/stock_parts/power_store/battery/bluespace,
		),
		"Cable Coils" = list(/obj/item/stack/cable_coil),
		"Glass Sheets" = list(/obj/item/stack/sheet/glass),
		"Plasteel Sheets" = list(/obj/item/stack/sheet/plasteel),
		"Bluespace Crystals" = list(/obj/item/stack/sheet/bluespace_crystal),
		"Infinite Megacell" = list(/obj/item/stock_parts/power_store/battery/infinite),
		"Infinite Power Cell" = list(/obj/item/stock_parts/power_store/cell/infinite),
	)
	/// Manufacture menu entries that open the subtype browser at the given root. Roots must pass valid_stock_part_types.
	var/static/list/browse_manufacture_options = list(
		"Machine Boards" = /obj/item/circuitboard/machine,
		"Computer Boards" = /obj/item/circuitboard/computer,
		"Stock Parts" = /obj/item/stock_parts,
		"Material Sheets" = /obj/item/stack/sheet,
		"Beakers" = /obj/item/reagent_containers/cup/beaker,
	)

/// Storage for the subspace RPED, sized so an admin can never realistically fill it up.
/datum/storage/rped/bluespace/admin
	max_slots = 1000
	max_total_storage = 20000

/obj/item/storage/part_replacer/bluespace/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)
	// A frame's own item_interaction runs ahead of interact_with_atom on the held item, so this signal is the only
	// hook early enough to stock the RPED before the frame empties it.
	RegisterSignal(src, COMSIG_ITEM_INTERACTING_WITH_ATOM, PROC_REF(on_interacting_with_atom))

/obj/item/storage/part_replacer/bluespace/admin/PopulateContents()
	for(var/i in 1 to RPED_STARTING_STOCK)
		new /obj/item/stock_parts/capacitor/quadratic(src)
		new /obj/item/stock_parts/scanning_module/triphasic(src)
		new /obj/item/stock_parts/servo/femto(src)
		new /obj/item/stock_parts/micro_laser/quadultra(src)
		new /obj/item/stock_parts/matter_bin/bluespace(src)
		new /obj/item/stock_parts/power_store/cell/bluespace(src)
		new /obj/item/stock_parts/power_store/battery/bluespace(src)
		new /obj/item/reagent_containers/cup/beaker/bluespace(src)
		new /obj/item/stack/cable_coil(src)
		new /obj/item/stack/sheet/glass(src)
		new /obj/item/stack/sheet/plasteel(src)
		new /obj/item/stack/sheet/bluespace_crystal(src)

/obj/item/storage/part_replacer/bluespace/admin/examine(mob/user)
	. = ..()
	. += span_notice("Alt-Right-Click to manufacture parts, set the batch size, or clear its internal storage.")
	. += span_notice("Leftovers pulled out of an upgraded machine are [auto_clear ? "destroyed" : "kept"].")

/**
 * Tops the RPED up with whatever an unbuilt machine frame is still asking for.
 *
 * Returns NONE unconditionally so the frame's own interaction still runs and installs the parts.
 * Arguments:
 * * source - the RPED itself
 * * user - the mob holding the RPED
 * * target - what is being clicked; only machine frames are handled
 * * modifiers - click modifiers, unused
 */
/obj/item/storage/part_replacer/bluespace/admin/proc/on_interacting_with_atom(datum/source, mob/living/user, atom/target, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(target, /obj/structure/frame/machine))
		return NONE
	var/obj/structure/frame/machine/machine_frame = target
	// Prioritize using the circuit's components list first, if present, to maintain consistency.
	var/obj/item/circuitboard/machine/circuit = machine_frame.circuit
	var/list/required = istype(circuit) ? circuit.req_components : machine_frame.req_components
	if(length(required))
		spawn_parts_for_components(user, required)
	return NONE

/// An extension to the default RPED part replacement action - if you don't have the requisite parts in the RPED already, it will spawn T4 versions to use.
/obj/item/storage/part_replacer/bluespace/admin/interact_with_atom(obj/attacked_object, mob/living/user, list/modifiers)
	// Duplicate checks from parent since we need to stock up before the parent actually swaps anything.
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	if(!ismachinery(attacked_object) || istype(attacked_object, /obj/machinery/computer))
		return NONE
	var/obj/machinery/attacked_machinery = attacked_object
	if(!LAZYLEN(attacked_machinery.component_parts))
		return ITEM_INTERACT_FAILURE

	// Auto-clear tells the machine's old parts from ours by comparing against this.
	var/list/old_contents = auto_clear ? atom_storage.return_inv(recursive = FALSE) : null

	// There's no good way to get required components off of an already-built machine, so we go through its circuit.
	var/obj/item/circuitboard/machine/circuit = attacked_machinery.circuit
	if(istype(circuit))
		spawn_parts_for_components(user, circuit.req_components)

	. = ..()

	if(!auto_clear)
		return .
	for(var/obj/item/stored_item in atom_storage.return_inv(recursive = FALSE))
		if(!(stored_item in old_contents))
			qdel(stored_item)
	return .

/**
 * Fills the RPED with whatever a recipe asks for and it is not already holding.
 *
 * req_components lists either item typepaths (materials, beakers) or /datum/stock_part subtypes, so every
 * entry is handed off to whichever helper knows how to count and spawn that flavour of component.
 * Arguments:
 * * user - the mob operating the RPED, credited as the inserter for storage messages
 * * required_components - assoc list of typepath to how many of it the recipe wants
 */
/obj/item/storage/part_replacer/bluespace/admin/proc/spawn_parts_for_components(mob/living/user, list/required_components)
	for(var/req_component, amount_required in required_components)
		if(!amount_required)
			continue

		// Stacks first: they're a special kind of item, matched and spawned by amount.
		if(ispath(req_component, /obj/item/stack))
			restock_stack(user, req_component, amount_required)
			continue

		// Any other physical item: matched and spawned one-for-one.
		if(ispath(req_component, /obj/item))
			restock_items(user, req_component, amount_required)
			continue

		// Stock part datums, which stand in for a physical object (and a tier of it).
		if(ispath(req_component, /datum/stock_part))
			restock_stock_part(user, req_component, amount_required)
			continue

		// Anything else means a malformed recipe - let someone know.
		to_chat(user, span_notice("Something went wrong manufacturing [req_component]. Alert the devs, and let them know what machine it was!"))

/// Top a stack up to the required amount.
/// Stacks auto-split on Initialize, so a single spawn covers whatever's short.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_stack(mob/living/user, stack_type, amount_required)
	var/list/valid_types = typesof(stack_type)
	var/found = 0
	for(var/obj/item/stack/stored_stack in contents)
		if(!(stored_stack.type in valid_types))
			continue
		found += stored_stack.amount
		if(found >= amount_required)
			return // Already have enough - nothing to spawn.

	var/obj/item/stack/manufactured_stack = new stack_type(null, amount_required - found)
	if(!atom_storage.attempt_insert(manufactured_stack, user, TRUE))
		qdel(manufactured_stack)

/// Spawn one item per unit still missing after counting what we already hold.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_items(mob/living/user, item_type, amount_required)
	var/found = count_stored(typesof(item_type), amount_required)
	spawn_shortfall(user, item_type, amount_required - found)

/// Stock parts are datums mapped onto physical objects, sometimes at a specific tier.
/obj/item/storage/part_replacer/bluespace/admin/proc/restock_stock_part(mob/living/user, datum/stock_part/part_type, amount_required)
	// A specific tier above the basic one was asked for: match and spawn exactly that item.
	if(initial(part_type.tier) > 1)
		var/exact_type = initial(part_type.physical_object_type)
		var/found = count_stored(list(exact_type), amount_required)
		spawn_shortfall(user, exact_type, amount_required - found)
		return

	// Otherwise any physical object in the base type's family counts.
	var/base_type = initial(part_type.physical_object_base_type)
	var/found = count_stored(typesof(base_type), amount_required)
	if(found >= amount_required)
		return

	// We're short, so spawn the highest tier variant this part has available.
	var/spawn_type = base_type
	var/highest_tier = 0
	for(var/datum/stock_part/variant as anything in typesof(part_type))
		if(initial(variant.tier) <= highest_tier)
			continue
		highest_tier = initial(variant.tier)
		spawn_type = initial(variant.physical_object_type)

	spawn_shortfall(user, spawn_type, amount_required - found)

/// Count stored items whose type is in valid_types, stopping once we've seen enough.
/obj/item/storage/part_replacer/bluespace/admin/proc/count_stored(list/valid_types, threshold)
	var/found = 0
	for(var/obj/stored_item in contents)
		if(!(stored_item.type in valid_types))
			continue
		found += 1
		if(found >= threshold)
			break
	return found

/// Insert `amount` freshly-spawned copies of atom_type. A non-positive amount inserts nothing.
/obj/item/storage/part_replacer/bluespace/admin/proc/spawn_shortfall(mob/living/user, atom_type, amount)
	for(var/i in 1 to amount)
		if(!manufacture_and_insert(user, atom_type))
			break

/** Creates an item outside the RPED and destroys it if storage insertion rejects it. */
/obj/item/storage/part_replacer/bluespace/admin/proc/manufacture_and_insert(mob/living/user, item_type)
	var/obj/item/manufactured_item = new item_type(null)
	if(atom_storage.attempt_insert(manufactured_item, user, override = TRUE))
		return TRUE
	qdel(manufactured_item)
	return FALSE

/// BSTs' special Bluespace RPED can manufacture parts on Alt-RMB, either cables, glass, machine boards, or stock parts.
/obj/item/storage/part_replacer/bluespace/admin/click_alt_secondary(mob/user)
	// Every other tool in this module gates its admin-only half the same way, and this one hands out infinite tier 4 parts.
	if(!user.client?.holder || !user.is_holding(src))
		return

	// Ask the user what they want to make, or which of the housekeeping options they want to run.
	var/list/menu = list(RPED_MENU_CLEAR_ALL, RPED_MENU_TOGGLE_AUTO_CLEAR, RPED_MENU_SET_BATCH_SIZE)
	menu += bulk_manufacture_options
	menu += browse_manufacture_options
	var/spawn_selection = tgui_input_list(user, "Pick a part, or clear storage", "RPED Manufacture", menu)
	if(isnull(spawn_selection))
		return
	// Re-check after the input resolves, so the menu can't be left open and cashed in after the holder goes away.
	if(!user.client?.holder || !user.is_holding(src))
		return

	switch(spawn_selection)
		if(RPED_MENU_CLEAR_ALL)
			for(var/obj/item/stored_item in atom_storage.return_inv(recursive = FALSE))
				qdel(stored_item)
		if(RPED_MENU_TOGGLE_AUTO_CLEAR)
			auto_clear = !auto_clear
			to_chat(user, span_notice("The RPED will now [(auto_clear ? "destroy" : "keep")] items left over after upgrades."))
		if(RPED_MENU_SET_BATCH_SIZE)
			var/new_size = tgui_input_number(
				user,
				"How many of each type should a selection produce?",
				"RPED Batch Size",
				default = batch_size,
				max_value = RPED_MAX_BATCH_SIZE,
				min_value = 1,
			)
			if(isnull(new_size))
				return
			if(!user.client?.holder || !user.is_holding(src))
				return
			batch_size = new_size
			to_chat(user, span_notice("The RPED will now produce [batch_size] of each type per selection."))
		else
			// Everything else is either a fixed batch of types, or a root to browse subtypes of.
			var/list/bulk_types = bulk_manufacture_options[spawn_selection]
			if(isnull(bulk_types))
				pick_stock_part(user, recurse = FALSE, subtype = browse_manufacture_options[spawn_selection])
				return
			for(var/part_type in bulk_types)
				for(var/i in 1 to batch_size)
					if(!manufacture_and_insert(user, part_type))
						break

/**
 * Asks the user to pick a subtype to manufacture, one level of the type tree at a time.
 *
 * Only the immediate children of the given root are listed, each labelled with how many subtypes it has of its
 * own. Picking an entry that still has subtypes recurses into it rather than spawning, so an admin can walk down
 * to the exact part they want; picking anything else fills the RPED with a batch of it.
 * Arguments:
 * * user - the mob operating the RPED
 * * recurse - TRUE when this is a nested call, which makes the root itself selectable so it can be spawned directly
 * * subtype - the root typepath to browse. Must pass valid_stock_part_types or nothing is listed
 */
/obj/item/storage/part_replacer/bluespace/admin/proc/pick_stock_part(mob/user, recurse, subtype)
	// Sanity check: make sure it's actually an item, and not an atom, machine, or whatever else someone might try to feed it down the line.
	// This is also what eats newly added stock parts in the subtype check - add their root to valid_stock_part_types.
	if(!is_path_in_list(subtype, valid_stock_part_types))
		return

	// Simplistic check to only list top-level subtypes, since subtypesof() returns the whole tree below the root.
	var/list/paths = list()
	for(var/datum/subtype_path as anything in subtypesof(subtype))
		if(initial(subtype_path.parent_type) != subtype)
			continue
		paths += subtype_path

	// With all sub-subtypes removed, build the label -> path bindings the menu is driven off.
	// If this is a recursion, the root itself is offered too, so the user can spawn the parent they browsed into.
	if(recurse)
		paths += subtype
	var/list/paths_by_label = list()
	for(var/path in paths)
		var/obj/path_as_obj = path
		var/child_count = length(subtypesof(path))
		// Anything with subtypes of its own is flagged as browsable, except the root, which is here to be spawned.
		if(child_count && path != subtype)
			paths_by_label["[initial(path_as_obj.name)] (+[child_count] more): [path]"] = path
			continue
		paths_by_label["[initial(path_as_obj.name)]: [path]"] = path

	var/chosen_label = tgui_input_list(user, "Select Subtype", "RPED Manufacture", sort_list(paths_by_label))
	if(isnull(chosen_label))
		return
	// Re-check after the input resolves, so the menu can't be left open and cashed in after the holder goes away.
	if(!user.client?.holder || !user.is_holding(src))
		return
	var/chosen_path = paths_by_label[chosen_label]
	if(isnull(chosen_path))
		return

	// If it still has subtypes, and isn't the root we were already browsing, drop a level instead of spawning.
	if(length(subtypesof(chosen_path)) && chosen_path != subtype)
		pick_stock_part(user, recurse = TRUE, subtype = chosen_path)
		return

	for(var/i in 1 to batch_size)
		if(!manufacture_and_insert(user, chosen_path))
			break

#undef RPED_DEFAULT_BATCH_SIZE
#undef RPED_MAX_BATCH_SIZE
#undef RPED_MENU_CLEAR_ALL
#undef RPED_MENU_SET_BATCH_SIZE
#undef RPED_MENU_TOGGLE_AUTO_CLEAR
#undef RPED_STARTING_STOCK
