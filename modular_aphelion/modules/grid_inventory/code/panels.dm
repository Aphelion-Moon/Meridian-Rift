/// Compact native panel. Ordinary nested storage keeps its slot capacity and original owner.
/datum/storage_interface/grid
	var/mob/viewer
	var/datum/storage/backpack/grid/grid
	var/ui_style
	var/list/palette
	var/list/grid_cells = list()
	var/list/item_displays = list()
	var/list/slot_placements = list()
	var/list/slot_rotations = list()
	var/slot_page_count = 1
	var/columns = 7
	var/rows = 3
	var/overflow_page = 0
	var/position_x
	var/position_y
	var/z_order = 1
	var/atom/movable/screen/grid_inventory/frame
	var/atom/movable/screen/grid_inventory/titlebar
	var/atom/movable/screen/grid_inventory/close_button
	var/atom/movable/screen/grid_inventory/page_button
	var/atom/movable/screen/grid_inventory_art/preview_display
	var/atom/movable/screen/grid_inventory/hovered_cell
	/// A completed pickup can be reversed by the client's native double-click event.
	var/datum/weakref/clicked_item_ref
	var/datum/grid_placement/clicked_placement
	var/clicked_x
	var/clicked_y
	var/clicked_page
	var/clicked_columns
	var/clicked_rows
	var/click_opened = FALSE
	var/suppress_click = FALSE

/datum/storage_interface/grid/New(new_style, datum/storage/storage, mob/user)
	// This interface supplies its own chrome instead of constructing the legacy storage frame.
	parent_storage = storage
	viewer = user
	if(istype(storage, /datum/storage/backpack/grid))
		grid = storage
	frame = new(null, user.hud_used)
	titlebar = new(null, user.hud_used)
	close_button = new(null, user.hud_used)
	page_button = new(null, user.hud_used)
	for(var/atom/movable/screen/grid_inventory/element as anything in list(frame, titlebar, close_button, page_button))
		element.interface = src
	frame.action = "frame"
	titlebar.action = "title"
	close_button.action = "close"
	close_button.name = "Close container"
	page_button.action = "page"
	page_button.name = "Next page"
	preview_display = new(null, user.hud_used)
	preview_display.alpha = 0
	update_ui_style(new_style)

/datum/storage_interface/grid/uses_item_proxies()
	return TRUE

/datum/storage_interface/grid/list_ui_elements(initializing = FALSE)
	. = list(frame, titlebar, close_button, page_button, preview_display) + grid_cells
	for(var/obj/item/item as anything in item_displays)
		. += item_displays[item]

/datum/storage_interface/grid/Destroy()
	cancel_click()
	hide_tooltip()
	hovered_cell = null
	QDEL_LIST(grid_cells)
	QDEL_LIST_ASSOC_VAL(item_displays)
	QDEL_LIST_ASSOC_VAL(slot_placements)
	QDEL_NULL(frame)
	QDEL_NULL(titlebar)
	QDEL_NULL(close_button)
	QDEL_NULL(page_button)
	QDEL_NULL(preview_display)
	viewer = null
	grid = null
	return ..()

/datum/storage_interface/grid/proc/panel_width()
	return columns * 24 + 8

/datum/storage_interface/grid/proc/panel_height()
	return rows * 24 + 32

/datum/storage_interface/grid/proc/can_interact()
	if(!viewer || QDELETED(parent_storage))
		return FALSE
	if(viewer.grid_inventory)
		return viewer.grid_inventory.can_interact(parent_storage)
	return grid?.can_grid_interact(viewer)

/datum/storage_interface/grid/proc/get_placement(obj/item/item)
	return grid ? grid.placements[item] : slot_placements[item]

/// Ordinary storage retains its capacity rules, but uses the same physical item rectangles.
/datum/storage_interface/grid/proc/slot_fits(obj/item/item, x, y, rotation, page = overflow_page, max_rows = rows)
	var/list/size = item.get_storage_footprint()
	var/width = size[rotation % 2 ? 2 : 1]
	var/height = size[rotation % 2 ? 1 : 2]
	if(rotation != round(rotation) || rotation < 0 || rotation > 3 || width < 1 || height < 1 || width != round(width) || height != round(height))
		return FALSE
	if(x < 1 || y < 1 || x + width - 1 > columns || y + height - 1 > max_rows)
		return FALSE
	for(var/obj/item/other as anything in slot_placements)
		var/datum/grid_placement/placement = slot_placements[other]
		if(other != item && placement.page == page && x < placement.x + placement.width && x + width > placement.x && y < placement.y + placement.height && y + height > placement.y)
			return FALSE
	return TRUE

/datum/storage_interface/grid/proc/place_slot_item(obj/item/item, x, y, rotation, page = overflow_page)
	var/list/size = item.get_storage_footprint()
	var/datum/grid_placement/placement = new(x, y, size[rotation % 2 ? 2 : 1], size[rotation % 2 ? 1 : 2], rotation)
	placement.page = page
	var/datum/grid_placement/old = slot_placements[item]
	slot_placements[item] = placement
	slot_rotations[item] = rotation
	qdel(old)
	return placement

/// Keep existing anchors. Grow or page the display instead of squeezing ordinary contents into 1x1 slots.
/datum/storage_interface/grid/proc/layout_slots(list/contents)
	columns = clamp(parent_storage.max_slots, 1, 7)
	if(clicked_item_ref?.resolve())
		columns = max(columns, clicked_columns)
	var/page_rows = 6
	for(var/obj/item/item as anything in contents)
		var/list/size = item.get_storage_footprint()
		columns = max(columns, min(size[1], size[2]))
		page_rows = max(page_rows, size[1], size[2])
	for(var/obj/item/item as anything in slot_placements.Copy())
		var/datum/grid_placement/placement = slot_placements[item]
		var/list/size = item.get_storage_footprint()
		if(!(item in contents) || placement.x + placement.width - 1 > columns || placement.width != size[placement.rotated % 2 ? 2 : 1] || placement.height != size[placement.rotated % 2 ? 1 : 2])
			slot_placements -= item
			qdel(placement)
	for(var/obj/item/item as anything in slot_rotations.Copy())
		if(!(item in contents))
			slot_rotations -= item
	for(var/obj/item/item as anything in contents)
		if(slot_placements[item])
			continue
		var/rotation = slot_rotations[item] || 0
		for(var/page in 0 to slot_page_count)
			for(var/y in 1 to page_rows)
				for(var/x in 1 to columns)
					for(var/turn in list(rotation, (rotation + 1) % 4))
						if(slot_fits(item, x, y, turn, page, page_rows))
							place_slot_item(item, x, y, turn, page)
							break
					if(slot_placements[item])
						break
				if(slot_placements[item])
					break
			if(slot_placements[item])
				slot_page_count = max(slot_page_count, page + 1)
				break
	slot_page_count = 1
	for(var/obj/item/item as anything in slot_placements)
		var/datum/grid_placement/placement = slot_placements[item]
		slot_page_count = max(slot_page_count, placement.page + 1)
	overflow_page = min(overflow_page, slot_page_count - 1)
	rows = clamp(ceil(min(parent_storage.max_slots, 21) / columns), 1, 6)
	var/list/visible = list()
	for(var/obj/item/item as anything in slot_placements)
		var/datum/grid_placement/placement = slot_placements[item]
		if(placement.page != overflow_page)
			continue
		rows = max(rows, placement.y + placement.height - 1)
		visible[item] = placement
	return visible

/datum/storage_interface/grid/proc/insert_slot_item(obj/item/item, x, y)
	var/page = overflow_page
	if(!can_interact() || item != viewer.get_active_held_item() || !slot_fits(item, x, y, 0))
		return
	if(parent_storage.attempt_insert(item, viewer) && !QDELETED(src) && !QDELETED(item) && item.loc == parent_storage.real_location && slot_fits(item, x, y, 0, page))
		place_slot_item(item, x, y, 0, page)
		parent_storage.refresh_views()

/datum/storage_interface/grid/update_position(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, unused_columns, unused_rows, mob/user_looking, atom/real_location, list/datum/numbered_display/numbered_contents)
	if(isnull(position_x))
		// Start at the existing storage HUD anchor; later refreshes preserve dragged positions.
		position_x = screen_start_x * 32 + screen_pixel_x
		position_y = screen_start_y * 32 + screen_pixel_y
	var/list/visible_items = list()
	var/list/contents = list()
	if(grid)
		columns = grid.grid_width
		rows = grid.grid_height + !!length(grid.overflow)
		overflow_page = min(overflow_page, max(0, ceil(length(grid.overflow) / columns) - 1))
		visible_items = grid.placements.Copy()
		for(var/index in overflow_page * columns + 1 to min(length(grid.overflow), (overflow_page + 1) * columns))
			visible_items[grid.overflow[index]] = null
	else
		for(var/obj/item/item in real_location)
			contents += item
		visible_items = layout_slots(contents)
	// Removing the first-clicked item must not destroy or move the second click's target.
	if(clicked_item_ref?.resolve() && clicked_page == overflow_page)
		rows = max(rows, clicked_rows)
	var/list/slot_occupancy = list()
	if(!grid)
		slot_occupancy.len = columns * rows
		for(var/obj/item/item as anything in visible_items)
			var/datum/grid_placement/placement = visible_items[item]
			for(var/y in placement.y to placement.y + placement.height - 1)
				for(var/x in placement.x to placement.x + placement.width - 1)
					slot_occupancy[(y - 1) * columns + x] = item
	while(length(grid_cells) > columns * rows)
		var/atom/movable/screen/grid_inventory/old_cell = grid_cells[length(grid_cells)]
		grid_cells -= old_cell
		viewer.client?.screen -= old_cell
		qdel(old_cell)
	while(length(grid_cells) < columns * rows)
		var/atom/movable/screen/grid_inventory/cell = new(null, viewer.hud_used)
		cell.interface = src
		grid_cells += cell
	for(var/index in 1 to length(grid_cells))
		var/atom/movable/screen/grid_inventory/cell = grid_cells[index]
		cell.cell_x = (index - 1) % columns + 1
		cell.cell_y = round((index - 1) / columns) + 1
		cell.take_only = grid && cell.cell_y > grid.grid_height
		cell.item = null
		if(cell.take_only)
			var/overflow_index = overflow_page * columns + cell.cell_x
			if(overflow_index <= length(grid.overflow))
				cell.item = grid.overflow[overflow_index]
		else if(grid)
			cell.item = grid.occupancy[index]
		else
			cell.item = slot_occupancy[index]
		cell.name = cell.item ? cell.item.name : "Empty grid cell"
		cell.icon = grid_inventory_cell_icon(cell.take_only ? "#ba8055" : null)
	for(var/obj/item/item as anything in item_displays.Copy())
		if(!(item in visible_items) || QDELETED(item))
			var/atom/movable/screen/grid_inventory_art/old = item_displays[item]
			item_displays -= item
			viewer.client?.screen -= old
			qdel(old)
	for(var/obj/item/item as anything in visible_items)
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		if(!display)
			display = new(null, viewer.hud_used)
			display.interface = src
			display.bind(item)
			item_displays[item] = display
		display.render(get_placement(item))
	frame.icon = grid_inventory_panel_icon(columns, rows, ui_style)
	page_button.alpha = (grid ? length(grid.overflow) > columns : slot_page_count > 1) ? 255 : 0
	page_button.mouse_opacity = page_button.alpha ? MOUSE_OPACITY_OPAQUE : MOUSE_OPACITY_TRANSPARENT
	titlebar.name = parent_storage.parent.name
	titlebar.maptext_width = panel_width() - 30 - (page_button.alpha ? 16 : 0)
	titlebar.maptext = "<span class='maptext' style='-dm-text-outline:0px;color:[palette["text"]]'>[html_encode(capitalize(parent_storage.parent.name))]</span>"
	reposition()

/datum/storage_interface/grid/proc/reposition()
	if(isnull(position_x))
		return
	var/list/view_size = view_to_pixels(viewer.client?.view || world.view)
	position_x = clamp(round(position_x), 32, max(32, view_size[1] + 32 - panel_width()))
	position_y = clamp(round(position_y), 32, max(32, view_size[2] + 32 - panel_height()))
	frame.screen_loc = offset_to_screen_loc(position_x, position_y)
	titlebar.screen_loc = offset_to_screen_loc(position_x + 4, position_y + rows * 24 + 10)
	titlebar.icon = grid_inventory_title_icon(panel_width() - 28, ui_style)
	titlebar.maptext_x = 2
	titlebar.maptext_y = 3
	close_button.screen_loc = offset_to_screen_loc(position_x + panel_width() - 21, position_y + panel_height() - 23)
	page_button.screen_loc = offset_to_screen_loc(position_x + panel_width() - 39, position_y + panel_height() - 23)
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.screen_loc = offset_to_screen_loc(position_x + 4 + (cell.cell_x - 1) * 24, position_y + 4 + (cell.cell_y - 1) * 24)
	for(var/obj/item/item as anything in item_displays)
		var/datum/grid_placement/placement = get_placement(item)
		var/cell_x = placement ? placement.x : (grid.overflow.Find(item) - 1) % columns + 1
		var/cell_y = placement ? placement.y : grid.grid_height + 1
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		display.screen_loc = offset_to_screen_loc(position_x + 4 + (cell_x - 1) * 24, position_y + 4 + (cell_y - 1) * 24)
	apply_layers()
	clear_preview()
	hide_tooltip()

/datum/storage_interface/grid/proc/raise_panel()
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	if(!session)
		return
	// Reorder the small panel list and renumber layers; never accumulate an unbounded z index.
	session.panels -= parent_storage
	session.panels[parent_storage] = src
	var/index = 0
	for(var/datum/storage/storage as anything in session.panels)
		var/datum/storage_interface/grid/panel = session.panels[storage]
		panel.z_order = ++index
		panel.apply_layers()

/datum/storage_interface/grid/proc/apply_layers()
	var/base_layer = z_order * 10
	frame.layer = base_layer
	titlebar.layer = base_layer + 1
	close_button.layer = base_layer + 2
	page_button.layer = base_layer + 2
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.layer = base_layer + 1
	for(var/obj/item/item as anything in item_displays)
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		display.layer = base_layer + 2
	preview_display.layer = base_layer + 3

/datum/storage_interface/grid/proc/update_ui_style(new_style)
	ui_style = new_style
	palette = grid_inventory_theme(new_style)
	frame.icon = grid_inventory_panel_icon(columns, rows, ui_style)
	close_button.icon = grid_inventory_close_icon(ui_style)
	page_button.icon = grid_inventory_tooltip_icon(16, 16, ui_style)
	page_button.maptext = MAPTEXT("<center><span style='color:[palette["text"]]'>&gt;</span></center>")
	titlebar.maptext = "<span class='maptext' style='-dm-text-outline:0px;color:[palette["text"]]'>[html_encode(capitalize(parent_storage.parent.name))]</span>"
	reposition()

/datum/storage_interface/grid/proc/clear_preview()
	preview_display.alpha = 0
	hovered_cell = null
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	if(session?.hover_cell?.interface == src)
		session.preview_key = null
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.color = null
		cell.icon = grid_inventory_cell_icon(cell.take_only ? "#ba8055" : null)

/// Hover follows the item's full occupied footprint, including rotated items and ordinary slots.
/datum/storage_interface/grid/proc/show_hover(atom/movable/screen/grid_inventory/target)
	clear_preview()
	if(!target.item)
		return
	hovered_cell = target
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		if(cell.item == target.item)
			cell.icon = grid_inventory_cell_icon("#ffffff30", filled = TRUE)

/datum/storage_interface/grid/proc/preview_item(obj/item/item, atom/movable/screen/grid_inventory/target, rotation)
	if(QDELETED(item))
		return
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	var/valid = !target.take_only && can_interact() && (grid ? grid.fits(item, target.cell_x, target.cell_y, rotation) : slot_fits(item, target.cell_x, target.cell_y, rotation))
	if(item.loc != parent_storage.real_location)
		valid = valid && parent_storage.can_insert(item, viewer, messages = FALSE)
	else if(grid && session?.drag_panel == src)
		valid = valid && session.drag_revision == grid.revision
	var/list/size = item.get_storage_footprint()
	var/width = size[rotation % 2 ? 2 : 1]
	var/height = size[rotation % 2 ? 1 : 2]
	var/preview_color = valid ? "#75bf9160" : "#cf777760"
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		if(cell.cell_x >= target.cell_x && cell.cell_y >= target.cell_y && cell.cell_x < target.cell_x + width && cell.cell_y < target.cell_y + height)
			cell.icon = grid_inventory_cell_icon(preview_color, filled = TRUE)
	if(preview_display.item != item)
		preview_display.bind(item)
	var/datum/grid_placement/placement = new(1, 1, width, height, rotation)
	preview_display.render(placement)
	qdel(placement)
	preview_display.screen_loc = target.screen_loc
	preview_display.alpha = 130

/datum/storage_interface/grid/proc/receive_drop(atom/movable/screen/grid_inventory/target)
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	if(!session?.dragging || !can_interact() || target.action || target.take_only || QDELETED(session.drag_item))
		return
	var/obj/item/item = session.drag_item
	if(session.drag_panel == src)
		if(item.loc != parent_storage.real_location)
			return
		if(grid)
			grid.move_item(viewer, item, target.cell_x, target.cell_y, session.drag_rotation, session.drag_revision)
		else
			if(!slot_fits(item, target.cell_x, target.cell_y, session.drag_rotation))
				return
			place_slot_item(item, target.cell_x, target.cell_y, session.drag_rotation)
			parent_storage.refresh_views()
		return
	// Cross-container transfers use the existing pickup/removal path and insertion restrictions.
	if(!session.drag_panel.can_interact() || !parent_storage.can_insert(item, viewer, messages = FALSE))
		return
	if(grid ? !grid.fits(item, target.cell_x, target.cell_y, session.drag_rotation) : !slot_fits(item, target.cell_x, target.cell_y, session.drag_rotation))
		return
	var/rotation = session.drag_rotation
	var/target_x = target.cell_x
	var/target_y = target.cell_y
	var/target_page = overflow_page
	var/datum/storage_interface/grid/source_panel = session.drag_panel
	var/datum/storage/source_storage = source_panel.parent_storage
	var/datum/storage/backpack/grid/source_grid = source_panel.grid
	var/datum/grid_placement/source_placement = source_grid?.placements[item]
	var/source_x = source_placement?.x
	var/source_y = source_placement?.y
	var/source_rotation = source_placement?.rotated
	var/datum/storage/destination = parent_storage
	var/datum/storage/backpack/grid/destination_grid = grid
	var/mob/user = viewer
	var/turf/recovery_turf = get_turf(user)
	if(item.loc != source_storage.real_location || !source_storage.remove_single(user, item, recovery_turf))
		return
	// Removal hooks can sleep. A closed panel, changed item or destination invalidates the drop.
	if(QDELETED(item) || item.loc != recovery_turf)
		return
	if(!QDELETED(user) && !QDELETED(src) && !QDELETED(source_panel) && !QDELETED(target) && source_panel.can_interact() && can_interact() && (destination_grid ? (!destination_grid.pending_item && destination_grid.fits(item, target_x, target_y, rotation)) : slot_fits(item, target_x, target_y, rotation, target_page)))
		if(destination_grid)
			destination_grid.pending_item = item
			destination_grid.pending_placement = destination_grid.make_placement(item, target_x, target_y, rotation)
		destination.attempt_insert(item, user)
		if(!destination_grid && !QDELETED(src) && !QDELETED(item) && item.loc == destination.real_location && slot_fits(item, target_x, target_y, rotation, target_page))
			place_slot_item(item, target_x, target_y, rotation, target_page)
			destination.refresh_views()
		if(destination_grid && !QDELETED(destination_grid))
			destination_grid.pending_item = null
			QDEL_NULL(destination_grid.pending_placement)
		// Insertion hooks may delete or redirect the item. Only recover what remains staged here.
		if(QDELETED(item) || item.loc != recovery_turf)
			return
	if(!QDELETED(source_storage) && !QDELETED(user) && source_storage.can_be_reached_by(user) && (!source_grid || !source_grid.pending_item))
		if(source_grid && source_x && source_grid.fits(item, source_x, source_y, source_rotation))
			source_grid.pending_item = item
			source_grid.pending_placement = source_grid.make_placement(item, source_x, source_y, source_rotation)
		source_storage.attempt_insert(item, user, messages = FALSE)
		if(source_grid && !QDELETED(source_grid))
			source_grid.pending_item = null
			QDEL_NULL(source_grid.pending_placement)
		if(QDELETED(item) || item.loc != recovery_turf)
			return
	if(!QDELETED(user) && item.IsReachableBy(user))
		user.put_in_hands(item)

/datum/storage_interface/grid/proc/cancel_click()
	clicked_item_ref = null
	QDEL_NULL(clicked_placement)
	clicked_x = null
	clicked_y = null
	clicked_page = null
	clicked_columns = null
	clicked_rows = null
	click_opened = FALSE
	suppress_click = FALSE

/datum/storage_interface/grid/proc/matches_click(atom/movable/screen/grid_inventory/cell)
	if(!istype(cell) || cell.interface != src || cell.action || clicked_page != overflow_page || !clicked_item_ref?.resolve())
		return FALSE
	if(clicked_placement)
		return cell.cell_x >= clicked_placement.x && cell.cell_x < clicked_placement.x + clicked_placement.width && cell.cell_y >= clicked_placement.y && cell.cell_y < clicked_placement.y + clicked_placement.height
	return cell.cell_x == clicked_x && cell.cell_y == clicked_y

/// MouseDown starts a new physical click. A trailing Click after DblClick has no new MouseDown.
/datum/storage_interface/grid/proc/begin_click(atom/object, list/modifiers)
	if(click_opened || !matches_click(object) || LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		cancel_click()

/datum/storage_interface/grid/proc/remember_click(obj/item/item, atom/movable/screen/grid_inventory/cell)
	cancel_click()
	clicked_item_ref = WEAKREF(item)
	clicked_x = cell.cell_x
	clicked_y = cell.cell_y
	clicked_page = overflow_page
	clicked_columns = columns
	clicked_rows = rows
	var/datum/grid_placement/placement = get_placement(item)
	if(placement)
		clicked_placement = new(placement.x, placement.y, placement.width, placement.height, placement.rotated)
		clicked_placement.page = placement.page

/// Immediate single-click, with an undo record rather than a delayed pickup timer.
/datum/storage_interface/grid/proc/item_click(obj/item/item, params, atom/movable/screen/grid_inventory/cell)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location)
		return
	var/list/modifiers = params2list(params)
	if(item.atom_storage && LAZYACCESS(modifiers, BUTTON) == LEFT_CLICK && !LAZYACCESS(modifiers, SHIFT_CLICK) && !LAZYACCESS(modifiers, ALT_CLICK) && !LAZYACCESS(modifiers, CTRL_CLICK))
		remember_click(item, cell)
	else
		cancel_click()
	viewer.ClickOn(item, params)

/// Keep native Click/DblClick ordering from picking up the item again after opening it.
/datum/storage_interface/grid/proc/repeat_click(atom/movable/screen/grid_inventory/cell)
	if(!matches_click(cell))
		cancel_click()
		return FALSE
	if(suppress_click)
		suppress_click = FALSE
		return TRUE
	var/obj/item/item = clicked_item_ref.resolve()
	if(viewer.is_holding(item))
		// If Click precedes DblClick, putting it back is also the ordinary empty-cell action.
		restore_click()
		return TRUE
	return FALSE

/// Undo only our own pickup, through normal insertion checks. Never reclaim an item used elsewhere.
/datum/storage_interface/grid/proc/restore_click()
	var/obj/item/item = clicked_item_ref?.resolve()
	if(!item || !can_interact())
		return FALSE
	if(item.loc == parent_storage.real_location)
		return TRUE
	if(!viewer.is_holding(item))
		return FALSE
	var/datum/storage/backpack/grid/owner_grid = grid
	if(owner_grid)
		if(owner_grid.pending_item || !clicked_placement || !owner_grid.fits(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated))
			return FALSE
		owner_grid.pending_item = item
		owner_grid.pending_placement = owner_grid.make_placement(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated)
	else if(clicked_placement && !slot_fits(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated, clicked_page))
		return FALSE
	var/datum/storage/storage = parent_storage
	var/inserted = storage.attempt_insert(item, viewer, messages = FALSE)
	if(owner_grid && !QDELETED(owner_grid))
		owner_grid.pending_item = null
		QDEL_NULL(owner_grid.pending_placement)
	if(QDELETED(src) || QDELETED(item) || !inserted || item.loc != storage.real_location)
		return FALSE
	if(!owner_grid && clicked_placement)
		place_slot_item(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated, clicked_page)
		storage.refresh_views()
	return TRUE

/datum/storage_interface/grid/proc/double_click(atom/movable/screen/grid_inventory/cell)
	if(!can_interact())
		return FALSE
	if(matches_click(cell))
		if(click_opened)
			return TRUE
		if(!restore_click())
			return FALSE
	else
		if(!cell.item?.atom_storage)
			return FALSE
		remember_click(cell.item, cell)
	var/obj/item/item = clicked_item_ref.resolve()
	click_opened = TRUE
	suppress_click = TRUE
	return open_container(item)

/datum/storage_interface/grid/proc/open_container(obj/item/item)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location || !item.atom_storage)
		return FALSE
	return item.atom_storage.open_storage(viewer)

/datum/storage_interface/grid/proc/show_tooltip(atom/movable/screen/grid_inventory/cell, params)
	if(!cell.item || !params || !viewer.client?.tooltips || viewer.grid_inventory?.dragging)
		return
	var/obj/item/item = cell.item
	var/category = item.atom_storage ? "Storage" : (item.tool_behaviour ? "Tool" : weight_class_to_text(item.w_class))
	var/description = length_char(item.desc) > 220 ? "[copytext_char(item.desc, 1, 218)]..." : item.desc
	var/details = html_encode(description)
	var/hint = item.atom_storage ? "Double-click to open" : "Click to take"
	// The existing HUD browser renders at display resolution instead of enlarging map pixels.
	var/content = "<span class='grid-tooltip' data-background='[palette["background"]]' data-border='[palette["border"]]' data-color='[palette["text"]]' data-accent='[palette["accent"]]'><span class='grid-tooltip-category'>\[[html_encode(category)]\]</span><span class='grid-tooltip-description'>[details]</span><span class='grid-tooltip-hint'>[hint]<br>Drag; Q/E or wheel: rotate</span></span>"
	viewer.client.tooltips.show(cell, params, title = html_encode(capitalize(item.name)), content = content, special = "grid-inventory")

/datum/storage_interface/grid/proc/hide_tooltip()
	var/atom/movable/screen/grid_inventory/target = viewer.client?.tooltips?.last_target
	if(istype(target) && target.interface == src)
		viewer.client.tooltips.hide()

/atom/movable/screen/grid_inventory
	plane = ABOVE_HUD_PLANE
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
	if(usr != interface?.viewer)
		return
	if(action == "close")
		interface.parent_storage.hide_contents(usr)
		return
	if(!interface.can_interact())
		return
	if(action == "page")
		interface.cancel_click()
		interface.overflow_page++
		var/total = interface.grid ? length(interface.grid.overflow) : length(interface.parent_storage.real_location.contents)
		var/page_size = interface.columns * (interface.grid ? 1 : interface.rows)
		if(interface.grid ? interface.overflow_page * page_size >= total : interface.overflow_page >= interface.slot_page_count)
			interface.overflow_page = 0
		interface.parent_storage.refresh_views()
		return
	if(action)
		return
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) == LEFT_CLICK && !LAZYACCESS(modifiers, SHIFT_CLICK) && !LAZYACCESS(modifiers, ALT_CLICK) && !LAZYACCESS(modifiers, CTRL_CLICK))
		if(interface.repeat_click(src))
			return
	else
		interface.cancel_click()
	if(item)
		interface.item_click(item, params, src)
	else if(!take_only)
		var/obj/item/held = usr.get_active_held_item()
		if(held)
			if(interface.grid)
				interface.grid.insert_at(usr, held, cell_x, cell_y, FALSE)
			else
				interface.insert_slot_item(held, cell_x, cell_y)

/atom/movable/screen/grid_inventory/DblClick(location, control, params)
	if(usr != interface?.viewer || action)
		return
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		return
	interface.double_click(src)

/atom/movable/screen/grid_inventory/MouseEntered(location, control, params)
	if(usr != interface?.viewer || action)
		return
	if(usr.grid_inventory?.dragging)
		usr.grid_inventory.update_preview(src)
	else
		interface.show_hover(src)
		interface.show_tooltip(src, params)

/atom/movable/screen/grid_inventory/MouseExited()
	if(usr == interface?.viewer)
		if(interface.hovered_cell == src)
			interface.clear_preview()
			interface.hide_tooltip()
		if(usr.grid_inventory?.hover_cell == src)
			usr.grid_inventory.update_preview(null)

/atom/movable/screen/grid_inventory/mouse_drop_receive(atom/dropped, mob/user, params)
	if(user == interface?.viewer)
		interface.receive_drop(src)
