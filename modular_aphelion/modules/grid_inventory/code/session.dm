/// One native inventory workspace per viewer; the real storages still own their contents and viewers.
/mob
	var/datum/grid_inventory_session/grid_inventory

/mob/proc/prepare_grid_inventory(datum/storage/storage)
	if(grid_inventory && !grid_inventory.accepts(storage))
		grid_inventory.close_all()
	if(!grid_inventory && istype(storage, /datum/storage/backpack/grid))
		active_storage?.hide_contents(src)
		grid_inventory = new(src)
	return grid_inventory

/datum/grid_inventory_session
	var/mob/viewer
	var/client/viewer_client
	var/datum/hud/viewer_hud
	var/list/panels = list()
	var/list/enclosing = list()
	var/closing = FALSE
	var/removal_depth = 0
	var/atom/drag_source
	var/datum/storage_interface/grid/drag_panel
	var/obj/item/drag_item
	var/drag_revision
	var/drag_rotation = 0
	var/dragging = FALSE
	var/pointer_dragged = FALSE
	var/mouse_held = FALSE
	var/list/drag_origin
	var/panel_start_x
	var/panel_start_y
	var/atom/movable/screen/grid_inventory/hover_cell
	var/preview_key
	var/gesture_id = 0
	var/datum/weakref/held_preview_ref
	var/held_rotation = 0

/datum/grid_inventory_session/New(mob/user)
	viewer = user
	viewer_client = user.client
	viewer_hud = user.hud_used
	user.grid_inventory = src
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING, SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED)), PROC_REF(close_on_signal))
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(validate_on_signal))
	RegisterSignal(user, COMSIG_VIEWDATA_UPDATE, PROC_REF(view_changed))
	RegisterSignals(user, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM, COMSIG_MOB_DROPPED_ITEM), PROC_REF(hand_changed))
	RegisterSignal(viewer_hud, COMSIG_QDELETING, PROC_REF(close_on_signal))
	RegisterSignal(viewer_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(mouse_down))
	RegisterSignal(viewer_client, COMSIG_CLIENT_MOUSEDRAG, PROC_REF(mouse_drag))
	RegisterSignal(viewer_client, COMSIG_CLIENT_MOUSEUP, PROC_REF(mouse_up))

/datum/grid_inventory_session/Destroy()
	closing = TRUE
	cancel_drag()
	for(var/datum/storage/storage as anything in panels.Copy())
		storage.hide_contents(viewer)
	if(viewer)
		UnregisterSignal(viewer, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING, SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED), COMSIG_MOVABLE_MOVED, COMSIG_VIEWDATA_UPDATE))
		UnregisterSignal(viewer, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM, COMSIG_MOB_DROPPED_ITEM))
		if(viewer.grid_inventory == src)
			viewer.grid_inventory = null
	if(viewer_hud)
		UnregisterSignal(viewer_hud, COMSIG_QDELETING)
	if(viewer_client)
		UnregisterSignal(viewer_client, list(COMSIG_CLIENT_MOUSEDOWN, COMSIG_CLIENT_MOUSEDRAG, COMSIG_CLIENT_MOUSEUP))
	viewer = null
	viewer_client = null
	viewer_hud = null
	enclosing.Cut()
	return ..()

/datum/grid_inventory_session/proc/accepts(datum/storage/storage)
	if(panels[storage] || !length(panels))
		return TRUE
	var/atom/container = storage.parent?.loc
	return container && panels[container.atom_storage]

/datum/grid_inventory_session/proc/add_panel(datum/storage/storage, datum/storage_interface/grid/panel)
	if(panels[storage])
		return
	var/atom/container = storage.parent.loc
	var/datum/storage/parent_storage = container?.atom_storage
	if(panels[parent_storage])
		enclosing[storage] = parent_storage
		var/datum/storage_interface/grid/parent_panel = panels[parent_storage]
		panel.position_x = parent_panel.position_x + parent_panel.panel_width() + 8
		panel.position_y = parent_panel.position_y + 16
		// Siblings from the same parent would share that spot; step down and right past open panels.
		var/occupied = TRUE
		while(occupied)
			occupied = FALSE
			for(var/datum/storage/open as anything in panels)
				var/datum/storage_interface/grid/other = panels[open]
				if(other.position_x == panel.position_x && other.position_y == panel.position_y)
					panel.position_x += 24
					panel.position_y -= 24
					occupied = TRUE
	panels[storage] = panel
	RegisterSignal(storage, COMSIG_QDELETING, PROC_REF(storage_deleted))
	RegisterSignal(storage.parent, COMSIG_MOVABLE_MOVED, PROC_REF(validate_on_signal))
	RegisterSignal(storage.real_location, COMSIG_ATOM_EXITED, PROC_REF(contents_exited))

/// Close before storage Destroy clears the parent and real-location signal owners.
/datum/grid_inventory_session/proc/storage_deleted(datum/storage/source)
	SIGNAL_HANDLER
	source.hide_contents(viewer)

/datum/grid_inventory_session/proc/remove_panel(datum/storage/storage)
	if(!panels[storage])
		return
	removal_depth++
	if(drag_panel == panels[storage])
		cancel_drag()
	else if(hover_cell?.interface == panels[storage])
		update_preview(null)
	UnregisterSignal(storage, COMSIG_QDELETING)
	UnregisterSignal(storage.parent, COMSIG_MOVABLE_MOVED)
	UnregisterSignal(storage.real_location, COMSIG_ATOM_EXITED)
	panels -= storage
	enclosing -= storage
	for(var/datum/storage/child as anything in enclosing.Copy())
		if(enclosing[child] == storage)
			child.hide_contents(viewer)
	if(!viewer.active_storage && length(panels))
		viewer.active_storage = panels[length(panels)]
	removal_depth--
	if(!length(panels) && !closing && !removal_depth)
		qdel(src)

/datum/grid_inventory_session/proc/close_all()
	qdel(src)

/datum/grid_inventory_session/proc/close_on_signal()
	SIGNAL_HANDLER
	close_all()

/datum/grid_inventory_session/proc/contents_exited()
	SIGNAL_HANDLER
	// Exit signals precede the storage owner's refresh and can run during movement.
	addtimer(CALLBACK(src, PROC_REF(validate)), 0, TIMER_UNIQUE)

/datum/grid_inventory_session/proc/validate_on_signal()
	SIGNAL_HANDLER
	validate()

/datum/grid_inventory_session/proc/can_interact(datum/storage/storage)
	if(!panels[storage] || QDELETED(storage) || storage.locked || !storage.display_contents || ismecha(viewer.loc))
		return FALSE
	if(!isliving(viewer))
		return FALSE
	var/mob/living/user = viewer
	if(!(user.mobility_flags & MOBILITY_STORAGE) || !user.can_perform_action(storage.parent, FORBID_TELEKINESIS_REACH))
		return FALSE
	var/datum/storage/parent_storage = enclosing[storage]
	if(parent_storage && (!panels[parent_storage] || storage.parent.loc != parent_storage.real_location))
		return FALSE
	return TRUE

/datum/grid_inventory_session/proc/validate()
	if(closing)
		return
	for(var/datum/storage/storage as anything in panels.Copy())
		if(!can_interact(storage))
			storage.hide_contents(viewer)
			if(QDELETED(src))
				return

/datum/grid_inventory_session/proc/view_changed()
	SIGNAL_HANDLER
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.reposition()
	refresh_hover()

/datum/grid_inventory_session/proc/update_ui_style(ui_style)
	clear_preview()
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.update_ui_style(ui_style)
	refresh_hover()

/// Inventory slots can receive mouse events on either their item or their HUD background.
/datum/grid_inventory_session/proc/inventory_item(atom/object)
	if(isitem(object))
		var/obj/item/item = object
		return item.loc == viewer && viewer.get_slot_by_item(item) ? item : null
	if(!istype(object, /atom/movable/screen/inventory))
		return null
	var/atom/movable/screen/inventory/slot = object
	if(slot.hud?.mymob != viewer)
		return null
	if(istype(slot, /atom/movable/screen/inventory/hand))
		var/atom/movable/screen/inventory/hand/hand = slot
		return viewer.get_item_for_held_index(hand.held_index)
	return viewer.get_item_by_slot(slot.slot_id)

/datum/grid_inventory_session/proc/can_drag_item()
	if(QDELETED(drag_item))
		return FALSE
	if(drag_panel)
		return drag_panel.can_interact() && drag_item.loc == drag_panel.parent_storage.real_location
	return inventory_item(drag_item) && drag_item.can_mob_unequip(viewer) && viewer.can_perform_action(drag_item, FORBID_TELEKINESIS_REACH)

/// A real panel drag owns the preview until it ends, even with an occupied active hand.
/datum/grid_inventory_session/proc/held_preview_item()
	var/obj/item/item = viewer.get_active_held_item()
	if(item != held_preview_ref?.resolve())
		held_preview_ref = item ? WEAKREF(item) : null
		held_rotation = 0
	return item

/datum/grid_inventory_session/proc/can_preview_item(obj/item/item)
	if(dragging)
		return item == drag_item && can_drag_item()
	return item && item == viewer.get_active_held_item() && inventory_item(item) && item.can_mob_unequip(viewer) && viewer.can_perform_action(item, FORBID_TELEKINESIS_REACH)

/datum/grid_inventory_session/proc/hand_changed()
	SIGNAL_HANDLER
	// Equipment signals can precede the final hand/location update.
	addtimer(CALLBACK(src, PROC_REF(refresh_hover)), 0, TIMER_UNIQUE)

/datum/grid_inventory_session/proc/refresh_hover()
	preview_key = null
	update_preview(hover_cell)

/// An open bag's inventory icon is also an automatic destination for this workspace.
/datum/grid_inventory_session/proc/drop_target(atom/object)
	if(istype(object, /atom/movable/screen/grid_inventory))
		return object
	var/obj/item/container = inventory_item(object)
	if(!container)
		return null
	var/datum/storage_interface/grid/panel = panels[container.atom_storage]
	return panel?.titlebar

/datum/grid_inventory_session/proc/receive_inventory_drop(atom/source, atom/over)
	if(source != drag_source || !dragging || istype(over, /atom/movable/screen/grid_inventory))
		return FALSE
	var/atom/movable/screen/grid_inventory/target = drop_target(over)
	if(!target)
		return FALSE
	target.interface.receive_drop(target)
	return TRUE

/datum/grid_inventory_session/proc/mouse_down(datum/source, atom/object, location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.begin_click(object, modifiers)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK)
		return
	cancel_drag()
	if(!istype(object, /atom/movable/screen/grid_inventory))
		drag_item = inventory_item(object)
		if(drag_item)
			drag_source = object
			mouse_held = TRUE
		return
	var/atom/movable/screen/grid_inventory/cell = object
	if(panels[cell.interface?.parent_storage] != cell.interface || !can_interact(cell.interface.parent_storage))
		return
	viewer.active_storage = cell.interface.parent_storage
	cell.interface.raise_panel()
	if(cell.action != "title" && (!cell.item || cell.take_only))
		update_preview(cell)
		return
	drag_source = cell
	drag_panel = cell.interface
	mouse_held = TRUE
	drag_origin = screen_loc_to_offset(LAZYACCESS(modifiers, SCREEN_LOC), viewer_client?.view || world.view)
	panel_start_x = drag_panel.position_x
	panel_start_y = drag_panel.position_y
	if(cell.item)
		drag_item = cell.item
		var/datum/grid_placement/placement = drag_panel.get_placement(drag_item)
		drag_rotation = placement ? placement.rotated : 0
		drag_revision = drag_panel.grid?.revision
	update_preview(cell)

/datum/grid_inventory_session/proc/mouse_drag(datum/source, atom/object, atom/over, src_location, over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(!mouse_held || object != drag_source || (drag_item ? !can_drag_item() : !drag_panel?.can_interact()))
		return
	var/atom/movable/screen/grid_inventory/target = drop_target(over)
	// Ordinary inventory drags retain their normal behavior until they enter this workspace.
	if(!drag_panel && !dragging && !target)
		return
	if(!dragging)
		drag_panel?.cancel_click()
		clear_preview()
	dragging = TRUE
	pointer_dragged = TRUE
	if(!drag_item)
		var/list/modifiers = params2list(params)
		var/list/offset = screen_loc_to_offset(LAZYACCESS(modifiers, SCREEN_LOC), viewer_client?.view || world.view)
		drag_panel.position_x = panel_start_x + offset[1] - drag_origin[1]
		drag_panel.position_y = panel_start_y + offset[2] - drag_origin[2]
		drag_panel.reposition(moving = TRUE)
		return
	update_preview(target)

/datum/grid_inventory_session/proc/mouse_up(datum/source, atom/object, location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK)
		return
	mouse_held = FALSE
	// MouseDrop follows MouseUp. Retain the payload until its receiver has run.
	clear_preview()
	if(dragging)
		if(!pointer_dragged)
			// A stationary press-and-rotate does not generate a native MouseDrop.
			drag_panel?.receive_drop(drag_source)
			cancel_drag(drag_source, params)
		return COMPONENT_CLIENT_MOUSEUP_INTERCEPT
	refresh_hover()

/datum/grid_inventory_session/proc/is_dragging()
	return dragging

/datum/grid_inventory_session/proc/rotate_drag(turns)
	if(!mouse_held && !dragging)
		var/obj/item/held = held_preview_item()
		if(QDELETED(hover_cell) || !can_preview_item(held) || !can_interact(hover_cell.interface?.parent_storage))
			return FALSE
		// Rotating the pickup starts a new action, not the second half of a double-click.
		for(var/datum/storage/storage as anything in panels)
			var/datum/storage_interface/grid/panel = panels[storage]
			panel.cancel_click()
		held_rotation = (held_rotation + turns + 4) % 4
		update_preview(hover_cell)
		return TRUE
	if(!mouse_held || !can_drag_item() || (!drag_panel && !dragging))
		return FALSE
	dragging = TRUE
	drag_panel?.cancel_click()
	drag_rotation = (drag_rotation + turns + 4) % 4
	drag_panel?.hide_tooltip()
	update_preview(hover_cell || (!pointer_dragged ? drag_source : null))
	return TRUE

/datum/grid_inventory_session/proc/clear_preview()
	preview_key = null
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.clear_preview()
		panel.hide_tooltip()

/datum/grid_inventory_session/proc/update_preview(atom/movable/screen/grid_inventory/target)
	var/obj/item/item = dragging ? drag_item : held_preview_item()
	var/rotation = dragging ? drag_rotation : held_rotation
	var/key = "[REF(target)]-[REF(item)]-[rotation]-[dragging]-[target?.interface?.grid?.revision]-[target?.item?.atom_storage?.revision]"
	if(preview_key == key)
		return
	clear_preview()
	preview_key = key
	hover_cell = target
	if(can_preview_item(item))
		for(var/datum/storage/storage as anything in panels)
			var/datum/storage_interface/grid/panel = panels[storage]
			panel.highlight_containers(item, rotation)
	if(QDELETED(target) || (target.action && target.action != "title" && target.action != "frame") || QDELETED(target.interface) || panels[target.interface.parent_storage] != target.interface)
		return
	if(item)
		target.interface.preview_item(item, target, rotation)
	else if(!dragging && !target.action)
		target.interface.show_hover(target)

/datum/grid_inventory_session/proc/cancel_drag(atom/over, params)
	gesture_id++
	clear_preview()
	drag_source = null
	drag_panel = null
	drag_item = null
	drag_rotation = 0
	drag_revision = null
	hover_cell = null
	drag_origin = null
	dragging = FALSE
	pointer_dragged = FALSE
	mouse_held = FALSE
	if(closing)
		return
	// Restore eligible containers for the active hand even when the pointer is outside the UI.
	update_preview(drop_target(over))
	if(!istype(over, /atom/movable/screen/grid_inventory))
		return
	var/atom/movable/screen/grid_inventory/cell = over
	var/datum/storage_interface/grid/panel = cell.interface
	if(QDELETED(panel) || (cell.action && cell.action != "title" && cell.action != "frame") || !can_interact(panel.parent_storage))
		return
	if(!held_preview_item())
		panel.show_tooltip(cell, params)
