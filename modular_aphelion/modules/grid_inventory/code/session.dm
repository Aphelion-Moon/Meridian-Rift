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
	var/atom/movable/screen/grid_inventory/drag_source
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

/datum/grid_inventory_session/New(mob/user)
	viewer = user
	viewer_client = user.client
	viewer_hud = user.hud_used
	user.grid_inventory = src
	RegisterSignals(user, list(COMSIG_MOB_LOGOUT, COMSIG_QDELETING, SIGNAL_ADDTRAIT(TRAIT_HANDS_BLOCKED)), PROC_REF(close_on_signal))
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(validate_on_signal))
	RegisterSignal(user, COMSIG_VIEWDATA_UPDATE, PROC_REF(view_changed))
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

/datum/grid_inventory_session/proc/update_ui_style(ui_style)
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.update_ui_style(ui_style)

/datum/grid_inventory_session/proc/mouse_down(datum/source, atom/object, location, control, params)
	SIGNAL_HANDLER
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK)
		return
	cancel_drag()
	if(!istype(object, /atom/movable/screen/grid_inventory))
		return
	var/atom/movable/screen/grid_inventory/cell = object
	if(panels[cell.interface?.parent_storage] != cell.interface || !can_interact(cell.interface.parent_storage))
		return
	viewer.active_storage = cell.interface.parent_storage
	cell.interface.raise_panel()
	if(cell.action != "title" && (!cell.item || cell.take_only))
		return
	drag_source = cell
	drag_panel = cell.interface
	mouse_held = TRUE
	drag_origin = screen_loc_to_offset(LAZYACCESS(modifiers, SCREEN_LOC), viewer_client.view)
	panel_start_x = drag_panel.position_x
	panel_start_y = drag_panel.position_y
	if(cell.item)
		drag_item = cell.item
		var/datum/grid_placement/placement = drag_panel.get_placement(drag_item)
		drag_rotation = placement ? placement.rotated : 0
		drag_revision = drag_panel.grid?.revision

/datum/grid_inventory_session/proc/mouse_drag(datum/source, atom/object, atom/over, src_location, over_location, src_control, over_control, params)
	SIGNAL_HANDLER
	if(!mouse_held || object != drag_source || !can_interact(drag_panel.parent_storage))
		return
	dragging = TRUE
	pointer_dragged = TRUE
	drag_panel.cancel_click()
	drag_panel.hide_tooltip()
	var/list/modifiers = params2list(params)
	var/list/offset = screen_loc_to_offset(LAZYACCESS(modifiers, SCREEN_LOC), viewer_client.view)
	if(!drag_item)
		drag_panel.position_x = panel_start_x + offset[1] - drag_origin[1]
		drag_panel.position_y = panel_start_y + offset[2] - drag_origin[2]
		drag_panel.reposition()
		return
	var/atom/movable/screen/grid_inventory/target = over
	update_preview(istype(target) ? target : null)

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
			drag_panel.receive_drop(drag_source)
			cancel_drag()
		return COMPONENT_CLIENT_MOUSEUP_INTERCEPT

/datum/grid_inventory_session/proc/is_dragging()
	return dragging

/datum/grid_inventory_session/proc/rotate_drag(turns)
	if(!mouse_held || !drag_item || !can_interact(drag_panel.parent_storage))
		return FALSE
	dragging = TRUE
	drag_panel.cancel_click()
	drag_rotation = (drag_rotation + turns + 4) % 4
	drag_panel.hide_tooltip()
	update_preview(hover_cell || drag_source)
	return TRUE

/datum/grid_inventory_session/proc/clear_preview()
	preview_key = null
	for(var/datum/storage/storage as anything in panels)
		var/datum/storage_interface/grid/panel = panels[storage]
		panel.clear_preview()

/datum/grid_inventory_session/proc/update_preview(atom/movable/screen/grid_inventory/target)
	var/key = "[REF(target)]-[REF(drag_item)]-[drag_rotation]-[target?.interface?.grid?.revision]"
	if(preview_key == key)
		return
	clear_preview()
	preview_key = key
	hover_cell = target
	if(!target || target.action || target.take_only || panels[target.interface?.parent_storage] != target.interface)
		return
	target.interface.preview_item(drag_item, target, drag_rotation)

/datum/grid_inventory_session/proc/cancel_drag()
	gesture_id++
	clear_preview()
	drag_source = null
	drag_panel = null
	drag_item = null
	hover_cell = null
	drag_origin = null
	dragging = FALSE
	pointer_dragged = FALSE
	mouse_held = FALSE
