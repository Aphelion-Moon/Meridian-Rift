/**
 * # Salvage hand-cart
 *
 * A draggable single-tile flatbed for hauling shipbreaking salvage.
 * Carries loose items in a storage bed and several large ship
 * structures (hull plating, tanks, engines, scanners) loaded by
 * drag-drop.
 */
/datum/armor/structure_salvage_cart
	melee = 20
	bullet = 10
	laser = 10
	bomb = 10
	fire = 60
	acid = 60

/**
 * # Salvage hand-cart
 *
 * Draggable flatbed with a storage bed for loose items and slots for
 * large ship parts. Pull it like a janitorial cart. Structures load
 * by drag-drop when adjacent and unanchored, unload by hand or
 * alt-click. Empty hand opens the storage bed.
 */
/obj/structure/salvage_cart
	name = "salvage hand-cart"
	desc = "A sturdy teal flatbed for hauling ship salvage. Drag it where it needs to go, and drag a loose ship structure onto it to load the bed."
	icon = 'modular_aphelion/modules/shipbreaking/icons/salvage_cart.dmi'
	icon_state = "salvage_cart"
	density = TRUE
	max_integrity = 250
	armor_type = /datum/armor/structure_salvage_cart
	custom_materials = list(/datum/material/aluminum = SHEET_MATERIAL_AMOUNT * 8)
	/// Large ship structures currently hauled in the bed, most recently loaded last
	var/list/obj/loaded_structures = list()
	/// How many storage slots one hauled structure counts as for fill level and bed capacity
	var/structure_slot_cost = 2
	/// Structures and machines the bed accepts. Machinery included: engines, scanners, recycler.
	var/static/list/loadable_structures = typecacheof(list(
		/obj/structure/hull_plating,
		/obj/structure/shuttle_decoration/liquid_tank,
		/obj/machinery/power/shuttle_engine,
		/obj/machinery/exoscanner,
		/obj/structure/titanium_structure,
		/obj/structure/door_assembly,
		/obj/machinery/recycler,
	))

/obj/structure/salvage_cart/Initialize(mapload)
	. = ..()
	create_storage(max_slots = 7, max_specific_storage = WEIGHT_CLASS_BULKY, max_total_storage = WEIGHT_CLASS_BULKY * 7)
	atom_storage.click_alt_open = FALSE
	RegisterSignal(atom_storage, COMSIG_STORAGE_STORED_ITEM, PROC_REF(on_storage_changed))
	RegisterSignal(atom_storage, COMSIG_STORAGE_REMOVED_ITEM, PROC_REF(on_storage_changed))
	register_context()

/obj/structure/salvage_cart/Destroy()
	drop_loaded_structures()
	atom_storage?.remove_all()
	return ..()

/**
 * Checks whether a target can be loaded onto the bed.
 *
 * Arguments:
 * * target - The obj to check
 */
/obj/structure/salvage_cart/proc/can_load_structure(obj/target)
	if(QDELETED(target))
		return FALSE
	if(!is_type_in_typecache(target, loadable_structures))
		return FALSE
	if(target.anchored)
		return FALSE
	if(target.has_buckled_mobs())
		return FALSE
	if(!bed_has_room())
		return FALSE
	return TRUE

/**
 * Checks whether the bed has room for one more hauled structure.
 *
 * Compares the current load against the bed capacity, counting
 * structure_slot_cost for the incoming structure.
 */
/obj/structure/salvage_cart/proc/bed_has_room()
	return get_load_units() + structure_slot_cost <= get_bed_capacity()

/**
 * Loads a structure onto the bed.
 *
 * Arguments:
 * * target - The obj to load
 * * user - The mob loading it
 */
/obj/structure/salvage_cart/proc/load_structure(obj/target, mob/user)
	if(!can_load_structure(target))
		if(user)
			if(target.anchored)
				balloon_alert(user, "anchored!")
			else if(!bed_has_room())
				balloon_alert(user, "no room!")
			else
				balloon_alert(user, "cannot load that!")
		return FALSE
	if(!Adjacent(target))
		if(user)
			balloon_alert(user, "too far!")
		return FALSE
	target.forceMove(src)
	loaded_structures += target
	RegisterSignal(target, COMSIG_QDELETING, PROC_REF(on_loaded_qdeleting))
	update_appearance()
	if(user)
		balloon_alert(user, "loaded [target.name]")
		playsound(src, 'sound/items/tools/ratchet.ogg', 50, TRUE)
	return TRUE

/**
 * Unloads one hauled structure onto a nearby turf.
 *
 * Unloads the most recently loaded structure first.
 *
 * Arguments:
 * * user - The mob unloading it
 */
/obj/structure/salvage_cart/proc/unload_structure(mob/user)
	if(!length(loaded_structures))
		return FALSE
	var/obj/unloaded = loaded_structures[length(loaded_structures)]
	loaded_structures -= unloaded
	UnregisterSignal(unloaded, COMSIG_QDELETING)
	unloaded.forceMove(drop_location())
	update_appearance()
	if(user)
		balloon_alert(user, "unloaded [unloaded.name]")
		playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	return TRUE

/**
 * Clears the bed reference when a loaded structure is deleted.
 */
/obj/structure/salvage_cart/proc/on_loaded_qdeleting(datum/source)
	SIGNAL_HANDLER
	loaded_structures -= source
	update_appearance()

/**
 * Drops all hauled structures onto the cart's turf.
 */
/obj/structure/salvage_cart/proc/drop_loaded_structures()
	for(var/obj/loaded as anything in loaded_structures)
		UnregisterSignal(loaded, COMSIG_QDELETING)
		loaded.forceMove(drop_location())
	loaded_structures.Cut()

/**
 * Refreshes the fill overlay when the storage bed contents change.
 *
 * Handles both stored and removed items.
 *
 * Arguments:
 * * source - The cart storage datum sending the signal
 */
/obj/structure/salvage_cart/proc/on_storage_changed(datum/storage/source)
	SIGNAL_HANDLER
	update_appearance()

/**
 * Returns how many storage slots the bed contents count as.
 *
 * Loose items count one slot each, hauled structures count
 * structure_slot_cost each.
 */
/obj/structure/salvage_cart/proc/get_load_units()
	var/structure_count = length(loaded_structures)
	return length(contents) - structure_count + structure_count * structure_slot_cost

/**
 * Returns the bed capacity in storage slots.
 */
/obj/structure/salvage_cart/proc/get_bed_capacity()
	if(!atom_storage)
		return 0
	return atom_storage.max_slots

/**
 * Returns the storage bed fill level as 0-3.
 *
 * Loose items and hauled structures share the bed capacity:
 * up to a third full reads 1, up to two thirds reads 2,
 * beyond that reads 3.
 */
/obj/structure/salvage_cart/proc/get_load_level()
	var/load_units = get_load_units()
	if(load_units <= 0)
		return 0
	var/bed_capacity = get_bed_capacity()
	if(load_units * 3 <= bed_capacity)
		return 1
	if(load_units * 3 <= bed_capacity * 2)
		return 2
	return 3

/obj/structure/salvage_cart/mouse_drop_receive(atom/dropped, mob/user, params)
	if(isobj(dropped) && can_load_structure(dropped))
		load_structure(dropped, user)
		return TRUE
	return ..()

/obj/structure/salvage_cart/attack_hand(mob/living/user, list/modifiers)
	if(length(loaded_structures))
		unload_structure(user)
		return TRUE
	if(!user.can_perform_action(src, NEED_HANDS))
		return ..()
	atom_storage.open_storage(user)
	return TRUE

/obj/structure/salvage_cart/click_alt(mob/user)
	if(length(loaded_structures))
		unload_structure(user)
		return CLICK_ACTION_SUCCESS
	return NONE

/obj/structure/salvage_cart/attack_hand_secondary(mob/user, list/modifiers)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/**
 * Draws the storage fill level.
 *
 * Hauled structures stay hidden inside the bed; the fill boxes
 * alone show how loaded the cart is.
 */
/obj/structure/salvage_cart/update_overlays()
	. = ..()
	var/load_level = get_load_level()
	if(load_level <= 0)
		return
	. += mutable_appearance(icon, "salvage_cart_load_[load_level]", layer + 0.1)

/obj/structure/salvage_cart/handle_deconstruct(disassembled = TRUE)
	drop_loaded_structures()
	return ..()

/obj/structure/salvage_cart/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(length(loaded_structures) && prob(15))
		playsound(src, 'sound/vehicles/skateboard_roll.ogg', 20, TRUE)

/obj/structure/salvage_cart/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(!isnull(held_item))
		return . || NONE
	if(length(loaded_structures))
		context[SCREENTIP_CONTEXT_LMB] = "Unload structure"
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Unload structure"
	else
		context[SCREENTIP_CONTEXT_LMB] = "Open storage"
	return CONTEXTUAL_SCREENTIP_SET
