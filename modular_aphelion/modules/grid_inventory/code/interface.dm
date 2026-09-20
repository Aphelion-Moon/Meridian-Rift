/// Per-viewer HUD. Only these proxies are placed on client.screen.
/datum/storage_interface/grid
	var/mob/viewer
	var/datum/storage/backpack/grid/grid
	var/list/grid_cells = list()
	var/list/item_displays = list()
	var/list/overflow_cells = list()
	var/atom/movable/screen/grid_inventory/rotate_button
	var/atom/movable/screen/grid_inventory/next_button
	var/overflow_page = 0
	var/held_rotated = FALSE
	var/obj/item/drag_item
	var/drag_revision
	var/drag_rotated
	var/dragging = FALSE
	var/atom/movable/screen/grid_inventory/hover_cell
	var/preview_key
	var/client/viewer_client

/datum/storage_interface/grid/New(ui_style, datum/storage/parent_storage, mob/user)
	..()
	viewer = user
	viewer_client = user.client
	grid = parent_storage
	for(var/cell_y in 1 to grid.grid_height)
		for(var/cell_x in 1 to grid.grid_width)
			var/atom/movable/screen/grid_inventory/cell = new(null, user.hud_used)
			cell.interface = src
			cell.cell_x = cell_x
			cell.cell_y = cell_y
			cell.icon = ui_style
			grid_cells += cell
	for(var/index in 1 to grid.grid_width)
		var/atom/movable/screen/grid_inventory/cell = new(null, user.hud_used)
		cell.interface = src
		cell.cell_x = index
		cell.cell_y = grid.grid_height + 1
		cell.take_only = TRUE
		cell.icon = ui_style
		overflow_cells += cell
	rotate_button = new(null, user.hud_used)
	rotate_button.interface = src
	rotate_button.name = "Rotate held item"
	rotate_button.action = "rotate"
	rotate_button.icon = ui_style
	rotate_button.maptext = MAPTEXT("<center>R</center>")
	next_button = new(null, user.hud_used)
	next_button.interface = src
	next_button.name = "Next overflow page (take items out to clear)"
	next_button.action = "overflow"
	next_button.icon = ui_style
	next_button.maptext = MAPTEXT("<center>+</center>")
	RegisterSignal(viewer_client, COMSIG_CLIENT_MOUSEDOWN, PROC_REF(mouse_down))
	RegisterSignals(viewer, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM), PROC_REF(hand_changed))

/datum/storage_interface/grid/list_ui_elements(initializing = FALSE)
	. = ..()
	if(!initializing)
		. += grid_cells + overflow_cells + list(rotate_button, next_button)
		for(var/obj/item/item as anything in item_displays)
			. += item_displays[item]

/datum/storage_interface/grid/Destroy()
	if(viewer_client)
		UnregisterSignal(viewer_client, COMSIG_CLIENT_MOUSEDOWN)
	if(viewer)
		UnregisterSignal(viewer, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM))
	QDEL_LIST(grid_cells)
	QDEL_LIST(overflow_cells)
	QDEL_LIST_ASSOC_VAL(item_displays)
	QDEL_NULL(rotate_button)
	QDEL_NULL(next_button)
	viewer = null
	viewer_client = null
	grid = null
	drag_item = null
	hover_cell = null
	return ..()

/datum/storage_interface/grid/update_position(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, columns, rows, mob/user_looking, atom/real_location, list/datum/numbered_display/numbered_contents)
	rows = grid.grid_height + (length(grid.overflow) ? 1 : 0)
	return ..()

/datum/storage_interface/grid/add_items(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, columns, rows, mob/user_looking, atom/real_location, list/datum/numbered_display/numbered_contents)
	var/pages = max(1, ceil(length(grid.overflow) / grid.grid_width))
	overflow_page = min(overflow_page, pages - 1)
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells + overflow_cells)
		cell.screen_loc = "[screen_start_x + cell.cell_x - 1]:[screen_pixel_x],[screen_start_y + cell.cell_y - 1]:[screen_pixel_y]"
		if(cell.take_only)
			var/index = overflow_page * grid.grid_width + cell.cell_x
			cell.item = index <= length(grid.overflow) ? grid.overflow[index] : null
			cell.alpha = length(grid.overflow) ? 255 : 0
			cell.mouse_opacity = length(grid.overflow) ? MOUSE_OPACITY_OPAQUE : MOUSE_OPACITY_TRANSPARENT
		else
			cell.item = grid.occupancy[(cell.cell_y - 1) * grid.grid_width + cell.cell_x]
		cell.name = cell.item ? "[cell.item.name][cell.take_only ? " (overflow: take only)" : ""]" : "Empty grid cell"
		cell.color = cell.take_only ? "#c98c53" : (cell.item ? "#a2bbca" : null)
	rotate_button.screen_loc = "[screen_start_x + columns]:[screen_pixel_x],[screen_start_y + 2]:[screen_pixel_y]"
	next_button.screen_loc = "[screen_start_x + columns]:[screen_pixel_x],[screen_start_y + grid.grid_height]:[screen_pixel_y]"
	next_button.alpha = length(grid.overflow) ? 255 : 0
	next_button.mouse_opacity = length(grid.overflow) ? MOUSE_OPACITY_OPAQUE : MOUSE_OPACITY_TRANSPARENT
	next_button.name = "Overflow [overflow_page + 1]/[pages] - click for next page; take items out to clear"
	var/list/visible_items = grid.placements.Copy()
	for(var/atom/movable/screen/grid_inventory/cell as anything in overflow_cells)
		if(cell.item)
			visible_items[cell.item] = null
	for(var/obj/item/item as anything in item_displays.Copy())
		if(!(item in visible_items) || QDELETED(item))
			var/atom/movable/screen/grid_inventory_art/old = item_displays[item]
			viewer.client?.screen -= old
			item_displays -= item
			qdel(old)
	for(var/obj/item/item as anything in visible_items)
		if(QDELETED(item))
			continue
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		if(!display)
			display = new(null, viewer.hud_used)
			display.bind(item)
			item_displays[item] = display
		var/datum/grid_placement/placement = grid.placements[item]
		var/cell_x = placement ? placement.x : (grid.overflow.Find(item) - 1) % grid.grid_width + 1
		var/cell_y = placement ? placement.y : grid.grid_height + 1
		display.render(placement)
		display.screen_loc = "[screen_start_x + cell_x - 1]:[screen_pixel_x],[screen_start_y + cell_y - 1]:[screen_pixel_y]"
	preview_key = null
	update_preview(hover_cell)

/datum/storage_interface/grid/proc/mouse_down(datum/source, atom/object)
	SIGNAL_HANDLER
	drag_item = null
	dragging = FALSE
	if(!istype(object, /atom/movable/screen/grid_inventory))
		return
	var/atom/movable/screen/grid_inventory/cell = object
	if(cell.interface != src || cell.take_only || !cell.item)
		return
	drag_item = cell.item
	drag_revision = grid.revision
	var/datum/grid_placement/placement = grid.placements[drag_item]
	drag_rotated = placement?.rotated

/datum/storage_interface/grid/proc/hand_changed()
	SIGNAL_HANDLER
	// Equipment signals can precede the actual hand update.
	addtimer(CALLBACK(src, PROC_REF(refresh_preview)), 0, TIMER_UNIQUE)

/datum/storage_interface/grid/proc/refresh_preview()
	preview_key = null
	update_preview(hover_cell)

/datum/storage_interface/grid/proc/update_preview(atom/movable/screen/grid_inventory/target)
	hover_cell = target
	var/obj/item/item = dragging ? drag_item : viewer.get_active_held_item()
	var/rotated = dragging ? drag_rotated : held_rotated
	var/key = "[REF(target)]-[REF(item)]-[rotated]-[grid.revision]-[dragging]"
	if(preview_key == key)
		return
	preview_key = key
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.color = cell.item ? "#a2bbca" : null
	if(!target || target.interface != src || target.take_only || target.action || QDELETED(item))
		return
	var/valid = grid.can_grid_interact(viewer) && grid.fits(item, target.cell_x, target.cell_y, rotated)
	if(dragging)
		valid = valid && item.loc == grid.real_location && grid.placements[item] && drag_revision == grid.revision
	else
		valid = valid && grid.can_insert(item, viewer, messages = FALSE)
	var/list/size = item.get_storage_footprint()
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		if(cell.cell_x >= target.cell_x && cell.cell_y >= target.cell_y && cell.cell_x < target.cell_x + size[rotated ? 2 : 1] && cell.cell_y < target.cell_y + size[rotated ? 1 : 2])
			cell.color = valid ? "#75df9b" : "#ee7777"

/atom/movable/screen/grid_inventory
	icon_state = "storage_cell"
	plane = ABOVE_HUD_PLANE
	layer = 1
	mouse_opacity = MOUSE_OPACITY_OPAQUE
	hud_group_key = HUD_GROUP_STORAGE
	var/datum/storage_interface/grid/interface
	var/cell_x
	var/cell_y
	var/obj/item/item
	var/take_only = FALSE
	var/action

/atom/movable/screen/grid_inventory/Destroy()
	interface = null
	item = null
	return ..()

/atom/movable/screen/grid_inventory/Click(location, control, params)
	if(usr != interface?.viewer || !interface.grid.can_grid_interact(usr) || world.time <= usr.next_move)
		return
	if(action == "rotate")
		interface.held_rotated = !interface.held_rotated
		color = interface.held_rotated ? "#75df9b" : null
		interface.refresh_preview()
		return
	if(action == "overflow")
		interface.overflow_page = (interface.overflow_page + 1) % max(1, ceil(length(interface.grid.overflow) / interface.grid.grid_width))
		interface.grid.show_contents(usr)
		return
	var/list/modifiers = params2list(params)
	if(item && !QDELETED(item) && item.loc == interface.grid.real_location)
		if(LAZYACCESS(modifiers, CTRL_CLICK))
			var/datum/grid_placement/placement = interface.grid.placements[item]
			if(placement && !take_only)
				interface.grid.move_item(usr, item, placement.x, placement.y, !placement.rotated, interface.grid.revision)
			return
		// Standard clicks preserve pickup, examine and Alt-click nested navigation.
		usr.ClickOn(item, params)
	else if(!take_only)
		interface.grid.insert_at(usr, usr.get_active_held_item(), cell_x, cell_y, interface.held_rotated)

/atom/movable/screen/grid_inventory/MouseEntered(location, control, params)
	if(usr != interface?.viewer)
		return
	interface.update_preview(src)
	openToolTip(usr, src, params, title = name, content = item ? "Shift-click to examine. Alt-click to open storage. Ctrl-click to rotate. Drag to rearrange." : "Click with a held item to place it. R on the panel rotates placement.")

/atom/movable/screen/grid_inventory/MouseExited()
	if(usr == interface?.viewer)
		interface.update_preview(null)
		closeToolTip(usr)

/atom/movable/screen/grid_inventory/MouseDrag(atom/over_object, src_location, over_location, src_control, over_control, params)
	if(usr != interface?.viewer || !interface.drag_item)
		return
	interface.dragging = TRUE
	var/atom/movable/screen/grid_inventory/target = over_object
	interface.update_preview(istype(target) && target.interface == interface ? target : null)

/atom/movable/screen/grid_inventory/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	if(user == interface?.viewer)
		interface.dragging = FALSE
		interface.update_preview(null)

/atom/movable/screen/grid_inventory/mouse_drop_receive(atom/dropped, mob/user, params)
	if(user != interface?.viewer || action || take_only || !istype(dropped, /atom/movable/screen/grid_inventory))
		return
	var/atom/movable/screen/grid_inventory/source = dropped
	if(source.interface != interface || !interface.drag_item)
		return
	interface.grid.move_item(user, interface.drag_item, cell_x, cell_y, interface.drag_rotated, interface.drag_revision)
	interface.drag_item = null

/// Cached appearance, separate from the full-cell interaction targets beneath it.
/atom/movable/screen/grid_inventory_art
	plane = ABOVE_HUD_PLANE
	layer = 2
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	hud_group_key = HUD_GROUP_STORAGE
	var/obj/item/item
	var/dirty = TRUE
	var/last_width
	var/last_height
	var/last_rotated

/atom/movable/screen/grid_inventory_art/proc/bind(obj/item/source)
	item = source
	RegisterSignals(item, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_COLOR_UPDATED), PROC_REF(appearance_changed))

/atom/movable/screen/grid_inventory_art/Destroy()
	if(item)
		UnregisterSignal(item, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_COLOR_UPDATED))
	item = null
	return ..()

/atom/movable/screen/grid_inventory_art/proc/appearance_changed()
	SIGNAL_HANDLER
	dirty = TRUE
	var/datum/storage/backpack/grid/storage = item.loc?.atom_storage
	if(istype(storage))
		render(storage.placements[item])

/atom/movable/screen/grid_inventory_art/proc/render(datum/grid_placement/placement)
	var/width = placement ? placement.width : 1
	var/height = placement ? placement.height : 1
	var/rotated = placement?.rotated
	if(!dirty && width == last_width && height == last_height && rotated == last_rotated)
		return
	dirty = FALSE
	last_width = width
	last_height = height
	last_rotated = rotated
	var/mutable_appearance/art = item.get_storage_inventory_appearance()
	var/static/list/icon_sizes = list()
	var/key = "[art.icon]-[art.icon_state]"
	var/list/size = icon_sizes[key]
	if(!size)
		var/icon/source_icon = icon(art.icon, art.icon_state)
		size = list(max(1, source_icon.Width()), max(1, source_icon.Height()))
		icon_sizes[key] = size
	var/art_width = size[rotated ? 2 : 1]
	var/art_height = size[rotated ? 1 : 2]
	var/scale = min((width * 32 - 4) / art_width, (height * 32 - 4) / art_height)
	var/matrix/fitted = matrix()
	fitted.Scale(scale)
	if(rotated)
		fitted.Turn(90)
	art.transform = fitted
	art.pixel_x = (width * 32 - size[1]) / 2
	art.pixel_y = (height * 32 - size[2]) / 2
	art.pixel_w = 0
	art.pixel_z = 0
	art.plane = FLOAT_PLANE
	art.layer = FLOAT_LAYER
	art.appearance_flags = APPEARANCE_UI | PIXEL_SCALE
	art.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	icon = null
	cut_overlays()
	// One border around the entire footprint distinguishes adjacent packed items.
	var/static/list/borders = list()
	var/border_key = "[width]x[height]"
	if(!borders[border_key])
		var/icon/border = icon('icons/blanks/32x32.dmi', "nothing")
		border.Crop(1, 1, width * 32, height * 32)
		border.DrawBox("#bed3df", 2, 2, width * 32 - 1, height * 32 - 1)
		border.DrawBox(null, 3, 3, width * 32 - 2, height * 32 - 2)
		borders[border_key] = border
	add_overlay(mutable_appearance(borders[border_key]))
	add_overlay(art)
