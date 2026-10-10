/obj/item/gun/energy/cell_loaded
	name = "cell-loaded gun"
	desc = "An energy gun that functions by loading cells for ammo types."

	/// List containing what cells are allowed to be installed by the gun. This includes all subtypes.
	var/list/allowed_cells
	/// The maximum amount of cells that a cell loaded gun can hold at once.
	var/max_cells = 3
	/// Lazylist of the currently installed cells, in the order they were installed.
	var/list/installed_cells
	/// Cell types to auto-populate installed_cells with on Initialize. Subtypes just override this list.
	var/list/starting_cells
	/// If TRUE, attack_self shows a radial to pick a specific loaded cell instead of cycling linearly.
	var/radial_select_mode = FALSE
	/// Whether cells can be installed into this gun via item_interaction.
	var/can_install_cells = TRUE
	/// Whether cells can be removed from this gun via click_alt.
	var/can_remove_cells = TRUE

	automatic_charge_overlays = FALSE //This is needed because Cell based guns use their own custom overlay system.

/obj/item/gun/energy/cell_loaded/Initialize(mapload)
	. = ..()
	for(var/cell_type in starting_cells)
		if(length(installed_cells) >= max_cells)
			break
		var/obj/item/weaponcell/cell = new cell_type(src)
		ammo_type += new cell.ammo_type(src)
		LAZYADD(installed_cells, cell)

/obj/item/gun/energy/cell_loaded/Destroy(force)
	QDEL_LAZYLIST(installed_cells)
	return ..()

/obj/item/gun/energy/cell_loaded/give_gun_safeties()
	return

/obj/item/gun/energy/cell_loaded/examine(mob/user)
	. = ..()
	if(!max_cells)
		return
	. += "<b>[length(installed_cells)]</b> out of <b>[max_cells]</b> cell slots are filled."
	. += span_info("You can use Alt Click with an empty hand to remove the most recently inserted cell from the chamber.")
	. += span_notice("Ctrl-Shift-Click to toggle between cycling cells and picking one via radial. Use in hand to [radial_select_mode ? "pick a cell" : "cycle cells"].")

	for(var/cell in installed_cells)
		. += span_notice("There is \a [cell] loaded in the chamber.")

/// Handles insertion of weapon cells
/obj/item/gun/energy/cell_loaded/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!is_type_in_list(tool, allowed_cells))
		return ..()

	if(!can_install_cells)
		to_chat(user, span_warning("[src] does not accept new cells!"))
		return ITEM_INTERACT_BLOCKING

	if(length(installed_cells) >= max_cells)
		to_chat(user, span_warning("[src] is fully chambered. Take a cell out to make room!"))
		return ITEM_INTERACT_BLOCKING

	var/obj/item/weaponcell/cell = tool
	if(!user.transferItemToLoc(cell, src))
		return ITEM_INTERACT_BLOCKING

	playsound(src, 'sound/machines/click.ogg', 50, TRUE)
	to_chat(user, span_notice("You install [cell]."))
	ammo_type += new cell.ammo_type(src)
	LAZYADD(installed_cells, cell)
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/energy/cell_loaded/update_overlays()
	. = ..()
	var/overlay_icon_state = icon_state
	var/obj/item/ammo_casing/energy/shot = ammo_type[select]

	if(modifystate)
		if(single_shot_type_overlay)
			var/mutable_appearance/full_overlay = mutable_appearance(icon, "[icon_state]_full")
			full_overlay.color = shot.select_color
			. += full_overlay
		overlay_icon_state += "_charge"

	var/ratio = get_charge_ratio()
	if(!ratio && display_empty)
		. += "[icon_state]_empty"
		return

	if(!shot.select_color)
		return

	var/mutable_appearance/charge_overlay = mutable_appearance(icon, overlay_icon_state)
	charge_overlay.color = shot.select_color
	for(var/i in 1 to ratio)
		charge_overlay.pixel_w = ammo_x_offset * (i - 1)
		charge_overlay.pixel_z = ammo_y_offset * (i - 1)
		. += new /mutable_appearance(charge_overlay)

/obj/item/gun/energy/cell_loaded/click_alt(mob/user)
	if(!can_remove_cells)
		to_chat(user, span_warning("The [src]'s cells are fixed in place!"))
		return CLICK_ACTION_BLOCKING
	if(!length(installed_cells))
		to_chat(user, span_warning("The [src] has no cells inside!"))
		return CLICK_ACTION_BLOCKING

	to_chat(user, span_notice("You remove a cell."))
	var/obj/item/weaponcell/last_cell = installed_cells[length(installed_cells)]

	if(last_cell)
		last_cell.forceMove(drop_location())
		user.put_in_hands(last_cell)

	LAZYREMOVE(installed_cells, last_cell)
	var/obj/item/ammo_casing/energy/removed_shot = pop(ammo_type)
	select_fire(user)
	qdel(removed_shot)
	return CLICK_ACTION_SUCCESS

/// Toggles attack_self() between cycling cells and picking one from a radial.
/obj/item/gun/energy/cell_loaded/click_ctrl_shift(mob/user)
	radial_select_mode = !radial_select_mode
	balloon_alert(user, "cell select: [radial_select_mode ? "radial" : "cycle"]")
	return CLICK_ACTION_SUCCESS

/obj/item/gun/energy/cell_loaded/attack_self(mob/user, list/modifiers)
	if(radial_select_mode && length(installed_cells) > 1 && isliving(user))
		select_via_radial(user)
		return
	return ..()

/**
 * Shows a radial of the installed cells and switches to the picked cell's firing mode.
 *
 * Installing a cell appends its casing to ammo_type, and click_alt() removes the newest of each,
 * so the last length(installed_cells) entries of ammo_type line up 1:1 with installed_cells.
 *
 * Arguments:
 * - user: The mob picking a cell.
 */
/obj/item/gun/energy/cell_loaded/proc/select_via_radial(mob/living/user)
	var/list/choices = list()
	for(var/obj/item/weaponcell/cell as anything in installed_cells)
		choices[cell] = image(icon = cell.icon, icon_state = cell.icon_state)

	var/obj/item/weaponcell/picked = show_radial_menu(user, src, choices, custom_check = CALLBACK(src, PROC_REF(check_radial_menu), user), require_near = TRUE)
	var/index = LAZYFIND(installed_cells, picked)
	if(!index)
		return
	select = length(ammo_type) - length(installed_cells) + index - 1 // select_fire() advances it by one
	select_fire(user)

/**
 * Returns whether user can keep using the cell radial.
 *
 * Arguments:
 * - user: The mob the radial was opened for.
 */
/obj/item/gun/energy/cell_loaded/proc/check_radial_menu(mob/user)
	return istype(user) && !user.incapacitated && user.get_active_held_item() == src

/// A cellgun used for debug, it is able to use any weaponcell.
/obj/item/gun/energy/cell_loaded/alltypes
	name = "omni gun"
	allowed_cells = list(/obj/item/weaponcell)
