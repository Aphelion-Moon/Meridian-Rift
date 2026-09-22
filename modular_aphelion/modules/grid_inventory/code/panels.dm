/// Compact native panel; every placement belongs to its original storage owner.
/datum/storage_interface/grid
	var/mob/viewer
	var/datum/storage/grid
	var/ui_style
	var/list/palette
	var/list/grid_cells = list()
	var/list/item_displays = list()
	var/columns = 7
	var/rows = 3
	var/header_height = 24
	/// Measure only when the title or available width changes, never during a drag.
	var/title_measurement_key
	var/last_position_x
	var/last_position_y
	var/overflow_page = 0
	var/position_x
	var/position_y
	var/z_order = 1
	var/atom/movable/screen/grid_inventory_holder/holder
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
	/// The clicked container's panel was open, so a double-click closes it instead of opening it.
	var/clicked_panel_open = FALSE
	var/click_opened = FALSE
	var/suppress_click = FALSE

/datum/storage_interface/grid/New(new_style, datum/storage/storage, mob/user)
	// This interface supplies its own chrome instead of constructing the legacy storage frame.
	parent_storage = storage
	viewer = user
	storage.enable_grid()
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
	// Screen objects ignore pixel offsets, but visual contents apply them. The holder stays put
	// on the screen, the frame's offsets place the panel, and everything else is drawn from the frame.
	holder = new(null, user.hud_used)
	holder.vis_contents += frame
	frame.vis_contents += list(titlebar, close_button, page_button, preview_display)
	update_ui_style(new_style)

/datum/storage_interface/grid/uses_item_proxies()
	return TRUE

/// Only the holder joins the client's screen, so a drag updates one object: the frame.
/datum/storage_interface/grid/list_ui_elements(initializing = FALSE)
	return list(holder)

/datum/storage_interface/grid/Destroy()
	cancel_click()
	hide_tooltip()
	hovered_cell = null
	QDEL_LIST(grid_cells)
	QDEL_LIST_ASSOC_VAL(item_displays)
	QDEL_NULL(holder)
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
	return rows * 24 + 8 + header_height

/datum/storage_interface/grid/proc/can_interact()
	if(!viewer || QDELETED(parent_storage))
		return FALSE
	if(viewer.grid_inventory)
		return viewer.grid_inventory.can_interact(parent_storage)
	return grid?.can_grid_interact(viewer)

/datum/storage_interface/grid/proc/get_placement(obj/item/item)
	return grid.placements[item]

/**
 * Sizes the panel to its storage's fixed grid, plus a take-only row when anything overflows.
 */
/datum/storage_interface/grid/proc/fit_grid_size()
	columns = grid.grid_width
	rows = grid.grid_height + !!length(grid.overflow)

/datum/storage_interface/grid/update_position(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, unused_columns, unused_rows, mob/user_looking, atom/real_location, list/datum/numbered_display/numbered_contents)
	if(isnull(position_x))
		// Start at the existing storage HUD anchor; later refreshes preserve dragged positions.
		position_x = screen_start_x * 32 + screen_pixel_x
		position_y = screen_start_y * 32 + screen_pixel_y
	fit_grid_size()
	overflow_page =min(overflow_page, max(0, ceil(length(grid.overflow) / columns) - 1))
	var/list/visible_items = grid.placements.Copy()
	for(var/index in overflow_page * columns + 1 to min(length(grid.overflow), (overflow_page + 1) * columns))
		visible_items[grid.overflow[index]] = null
	// Removing the first-clicked item must not destroy or move the second click's target.
	if(clicked_item_ref?.resolve() && clicked_page == overflow_page)
		rows = max(rows, clicked_rows)
	while(length(grid_cells) > columns * rows)
		var/atom/movable/screen/grid_inventory/old_cell = grid_cells[length(grid_cells)]
		grid_cells -= old_cell
		frame.vis_contents -= old_cell
		qdel(old_cell)
	while(length(grid_cells) < columns * rows)
		var/atom/movable/screen/grid_inventory/cell = new(null, viewer.hud_used)
		cell.interface = src
		grid_cells += cell
		frame.vis_contents += cell
	for(var/index in 1 to length(grid_cells))
		var/atom/movable/screen/grid_inventory/cell = grid_cells[index]
		cell.cell_x = (index - 1) % columns + 1
		cell.cell_y = round((index - 1) / columns) + 1
		cell.take_only = cell.cell_y > grid.grid_height || index > grid.grid_capacity
		cell.item = null
		if(cell.cell_y > grid.grid_height)
			var/overflow_index = overflow_page * columns + cell.cell_x
			if(overflow_index <= length(grid.overflow))
				cell.item = grid.overflow[overflow_index]
		else if(!cell.take_only)
			cell.item = grid.occupancy[index]
		cell.name = cell.item ? cell.item.name : "Empty grid cell"
		cell.icon = grid_inventory_cell_icon(cell.take_only ? "#ba8055" : null)
	for(var/obj/item/item as anything in item_displays.Copy())
		if(!(item in visible_items) || QDELETED(item))
			var/atom/movable/screen/grid_inventory_art/old = item_displays[item]
			item_displays -= item
			frame.vis_contents -= old
			qdel(old)
	for(var/obj/item/item as anything in visible_items)
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		if(!display)
			display = new(null, viewer.hud_used)
			display.interface = src
			display.bind(item)
			item_displays[item] = display
			frame.vis_contents += display
		display.render(get_placement(item))
	page_button.alpha = length(grid.overflow) > columns ? 255 : 0
	page_button.mouse_opacity = page_button.alpha ? MOUSE_OPACITY_OPAQUE : MOUSE_OPACITY_TRANSPARENT
	update_title()
	reposition()
	if(viewer.grid_inventory)
		addtimer(CALLBACK(viewer.grid_inventory, TYPE_PROC_REF(/datum/grid_inventory_session, refresh_hover)), 0, TIMER_UNIQUE)

/// BYOND measures the actual HUD font and wrapping. Its client round trip must not block input.
/datum/storage_interface/grid/proc/update_title()
	titlebar.name = parent_storage.parent.name
	titlebar.maptext_width = panel_width() - 30 - (page_button.alpha ? 16 : 0)
	titlebar.maptext = "<span class='maptext' style='-dm-text-outline:0px;color:[palette["text"]]'>[html_encode(capitalize(titlebar.name))]</span>"
	var/key = "[titlebar.name]-[titlebar.maptext_width]"
	if(title_measurement_key == key)
		return
	title_measurement_key = key
	titlebar.maptext_height = 14
	header_height = 24
	if(viewer.client)
		INVOKE_ASYNC(src, PROC_REF(measure_title), key, titlebar.maptext, titlebar.maptext_width)

/datum/storage_interface/grid/proc/measure_title(key, text, width)
	var/text_height
	WXH_TO_HEIGHT(viewer.client?.MeasureText(text, null, width), text_height)
	// A rename, resize or close may have happened while the client was measuring.
	if(QDELETED(src) || title_measurement_key != key || !text_height)
		return
	titlebar.maptext_height = text_height
	header_height = max(24, text_height + 11)
	reposition()
	viewer.grid_inventory?.refresh_hover()

/// Only the frame moves. A drag glides it on the client between network updates.
/datum/storage_interface/grid/proc/reposition(moving = FALSE)
	if(isnull(position_x))
		return
	var/list/view_size = view_to_pixels(viewer.client?.view || world.view)
	position_x = clamp(round(position_x), 32, max(32, view_size[1] + 32 - panel_width()))
	position_y = clamp(round(position_y), 32, max(32, view_size[2] + 32 - panel_height()))
	if(moving && position_x == last_position_x && position_y == last_position_y)
		return
	last_position_x = position_x
	last_position_y = position_y
	// Offsets from the holder's fixed 1,1 anchor, which is position 32,32.
	if(moving)
		// The server sends one update per tick; interpolate across it instead of stepping.
		animate(frame, pixel_x = position_x - 32, pixel_y = position_y - 32, time = world.tick_lag)
		return
	frame.pixel_x = position_x - 32
	frame.pixel_y = position_y - 32
	frame.icon = grid_inventory_panel_icon(columns, rows, ui_style, header_height)
	var/header_bottom = rows * 24 + 7
	titlebar.pixel_x = 4
	titlebar.pixel_y = header_bottom
	titlebar.icon = grid_inventory_title_icon(panel_width() - 28, ui_style, header_height - 1)
	titlebar.maptext_x = 2
	titlebar.maptext_y = round((header_height - 1 - titlebar.maptext_height) / 2)
	var/button_y = header_bottom + round((header_height - 1 - 16) / 2)
	close_button.pixel_x = panel_width() - 21
	close_button.pixel_y = button_y
	page_button.pixel_x = panel_width() - 39
	page_button.pixel_y = button_y
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.pixel_x = 4 + (cell.cell_x - 1) * 24
		cell.pixel_y = 4 + (cell.cell_y - 1) * 24
	for(var/obj/item/item as anything in item_displays)
		var/datum/grid_placement/placement = get_placement(item)
		var/cell_x = placement ? placement.x : (grid.overflow.Find(item) - 1) % columns + 1
		var/cell_y = placement ? placement.y : grid.grid_height + 1
		var/atom/movable/screen/grid_inventory_art/display = item_displays[item]
		display.pixel_x = 4 + (cell_x - 1) * 24
		display.pixel_y = 4 + (cell_y - 1) * 24
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
	close_button.icon = grid_inventory_close_icon(ui_style)
	page_button.icon = grid_inventory_tooltip_icon(16, 16, ui_style)
	page_button.maptext = MAPTEXT("<center><span style='color:[palette["text"]]'>&gt;</span></center>")
	update_title()
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
	var/datum/storage/automatic = automatic_destination(target, item)
	var/valid
	if(automatic)
		valid = session?.can_preview_item(item) && can_receive(target, item, rotation, automatic)
	else
		valid = session?.can_preview_item(item) && !target.take_only && can_interact() && grid.fits(item, target.cell_x, target.cell_y, rotation)
		if(item.loc != parent_storage.real_location)
			valid = valid && parent_storage.can_insert(item, viewer, messages = FALSE)
		else if(grid && session?.drag_panel == src)
			valid = valid && session.drag_revision == grid.revision
	var/list/size = item.get_storage_footprint()
	var/width = size[rotation % 2 ? 2 : 1]
	var/height = size[rotation % 2 ? 1 : 2]
	var/preview_color = valid ? "#75bf9160" : "#cf777760"
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		// Over a container, color its footprint and leave the payload's footprint unfilled.
		if(automatic)
			if(target.action ? cell.take_only : cell.item != target.item)
				continue
		else if(cell.cell_x < target.cell_x || cell.cell_y < target.cell_y || cell.cell_x >= target.cell_x + width || cell.cell_y >= target.cell_y + height)
			continue
		cell.icon = grid_inventory_cell_icon(preview_color, filled = TRUE)
	if(preview_display.item != item)
		preview_display.bind(item)
	var/datum/grid_placement/placement = new(1, 1, width, height, rotation)
	preview_display.render(placement)
	qdel(placement)
	// Offsets are relative to the frame, so the frame itself is the origin.
	preview_display.pixel_x = target == frame ? 0 : target.pixel_x
	preview_display.pixel_y = target == frame ? 0 : target.pixel_y
	preview_display.alpha = 130

/// Check each visible container once, even when its artwork spans multiple cells.
/datum/storage_interface/grid/proc/highlight_containers(obj/item/item, rotation)
	var/list/eligible = list()
	var/list/checked = list()
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		var/datum/storage/storage = cell.item?.atom_storage
		if(!storage || cell.item == item || cell.take_only || (storage in checked))
			continue
		checked += storage
		if(can_receive(cell, item, rotation, storage))
			eligible += cell.item
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		if(cell.item in eligible)
			cell.icon = grid_inventory_cell_icon("#66b8df60", filled = TRUE)

/// Container artwork and panel chrome are automatic targets; empty cells retain exact placement.
/datum/storage_interface/grid/proc/automatic_destination(atom/movable/screen/grid_inventory/target, obj/item/item)
	if(target.action == "title" || target.action == "frame")
		return parent_storage
	if(target.item != item)
		return target.item?.atom_storage

/datum/storage_interface/grid/proc/can_receive(atom/movable/screen/grid_inventory/target, obj/item/item, rotation, datum/storage/automatic)
	if(QDELETED(target) || target.interface != src || !can_interact() || target.take_only)
		return FALSE
	if(automatic)
		if(QDELETED(automatic) || automatic_destination(target, item) != automatic || automatic.locked)
			return FALSE
		if(automatic != parent_storage && (automatic.parent.loc != parent_storage.real_location || !viewer.can_perform_action(automatic.parent, FORBID_TELEKINESIS_REACH)))
			return FALSE
		// Never insert a container into one of its own descendants.
		for(var/atom/ancestor = automatic.parent, ancestor, ancestor = ancestor.loc)
			if(ancestor == item)
				return FALSE
		automatic.enable_grid()
		// The current container already holds the item; can_insert() would count it twice.
		return item.loc == automatic.real_location || automatic.can_insert(item, viewer, messages = FALSE)
	if(target.action || !parent_storage.can_insert(item, viewer, messages = FALSE))
		return FALSE
	return grid.fits(item, target.cell_x, target.cell_y, rotation)

/datum/storage_interface/grid/proc/receive_drop(atom/movable/screen/grid_inventory/target, obj/item/held_item)
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	if(!session || !can_interact() || target.take_only || (held_item ? session.dragging || !session.can_preview_item(held_item) : !session.dragging || !session.can_drag_item()))
		return
	var/obj/item/item = held_item || session.drag_item
	var/rotation = held_item ? session.held_rotation : session.drag_rotation
	var/datum/storage/automatic = automatic_destination(target, item)
	if(!held_item && session.drag_panel == src && !automatic)
		if(target.action)
			return
		if(item.loc != parent_storage.real_location)
			return
		grid.move_item(viewer, item, target.cell_x, target.cell_y, session.drag_rotation, session.drag_revision)
		return
	// Cross-container transfers use the existing pickup/removal path and insertion restrictions.
	if(!can_receive(target, item, rotation, automatic))
		return
	// The current container is a valid target, but there is nothing to transfer.
	if(automatic && item.loc == automatic.real_location)
		return
	var/target_x = target.cell_x
	var/target_y = target.cell_y
	var/target_page = overflow_page
	var/datum/storage_interface/grid/source_panel = held_item ? null : session.drag_panel
	var/datum/storage/source_storage = source_panel?.parent_storage
	var/datum/storage/source_grid = source_panel?.grid
	var/datum/grid_placement/source_placement = source_grid?.placements[item]
	var/source_x = source_placement?.x
	var/source_y = source_placement?.y
	var/source_rotation = source_placement?.rotated
	var/datum/storage/destination = automatic || parent_storage
	var/datum/storage/destination_grid = destination
	var/mob/user = viewer
	var/turf/recovery_turf = get_turf(user)
	if(source_storage && (item.loc != source_storage.real_location || !source_storage.remove_single(user, item, recovery_turf)))
		return
	// Removal hooks can sleep. A closed panel, changed item or destination invalidates the drop.
	if(QDELETED(item) || item.loc != (source_storage ? recovery_turf : user))
		return
	if(!QDELETED(user) && !QDELETED(src) && (source_storage ? !QDELETED(source_panel) && source_panel.can_interact() : session.can_preview_item(item)) && can_receive(target, item, rotation, automatic) && !destination_grid.pending_item && (automatic || overflow_page == target_page))
		if(destination_grid)
			destination_grid.pending_item = item
			destination_grid.pending_placement = automatic ? destination_grid.first_fit(item, rotation) : destination_grid.make_placement(item, target_x, target_y, rotation)
		destination.attempt_insert(item, user)
		if(destination_grid && !QDELETED(destination_grid))
			destination_grid.pending_item = null
			QDEL_NULL(destination_grid.pending_placement)
		// Insertion hooks may delete or redirect the item. Only recover what remains staged here.
		if(QDELETED(item) || item.loc != recovery_turf)
			return
	// A rejected inventory drop stays equipped; it was never staged on the ground.
	if(!source_storage)
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
	clicked_panel_open = FALSE
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
	// Recorded before the pickup, which closes the panel of a container leaving its storage.
	clicked_panel_open = !!viewer.grid_inventory?.panels[item.atom_storage]
	var/datum/grid_placement/placement = get_placement(item)
	if(placement)
		clicked_placement = new(placement.x, placement.y, placement.width, placement.height, placement.rotated)

/// Immediate single-click, with an undo record rather than a delayed pickup timer.
/datum/storage_interface/grid/proc/item_click(obj/item/item, params, atom/movable/screen/grid_inventory/cell)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location)
		return
	var/list/modifiers = params2list(params)
	var/plain = !LAZYACCESS(modifiers, SHIFT_CLICK) && !LAZYACCESS(modifiers, ALT_CLICK) && !LAZYACCESS(modifiers, CTRL_CLICK)
	// Right-click opens a container through its storage; on one that is already open, it closes it.
	if(plain && LAZYACCESS(modifiers, BUTTON) == RIGHT_CLICK && viewer.grid_inventory?.panels[item.atom_storage])
		cancel_click()
		item.atom_storage.hide_contents(viewer)
		return
	if(item.atom_storage && plain && LAZYACCESS(modifiers, BUTTON) == LEFT_CLICK)
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
	var/datum/storage/owner_grid = grid
	if(owner_grid)
		if(owner_grid.pending_item || !clicked_placement || !owner_grid.fits(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated))
			return FALSE
		owner_grid.pending_item = item
		owner_grid.pending_placement = owner_grid.make_placement(item, clicked_placement.x, clicked_placement.y, clicked_placement.rotated)
	var/datum/storage/storage = parent_storage
	var/inserted = storage.attempt_insert(item, viewer, messages = FALSE)
	if(owner_grid && !QDELETED(owner_grid))
		owner_grid.pending_item = null
		QDEL_NULL(owner_grid.pending_placement)
	if(QDELETED(src) || QDELETED(item) || !inserted || item.loc != storage.real_location)
		return FALSE
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
	if(clicked_panel_open)
		item.atom_storage.hide_contents(viewer)
		return TRUE
	return open_container(item)

/datum/storage_interface/grid/proc/open_container(obj/item/item)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location || !item.atom_storage)
		return FALSE
	return item.atom_storage.open_storage(viewer)

/datum/storage_interface/grid/proc/show_tooltip(atom/movable/screen/grid_inventory/cell, params)
	if(!cell.item || !params || !viewer.client?.tooltips || viewer.grid_inventory?.dragging || viewer.get_active_held_item())
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

/// Invisible screen anchor. Screen objects are placed only by screen_loc, so movement happens in its frame.
/atom/movable/screen/grid_inventory_holder
	icon = 'icons/blanks/32x32.dmi'
	icon_state = "nothing"
	screen_loc = "1,1"
	plane = ABOVE_HUD_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	hud_group_key = HUD_GROUP_STORAGE

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
		if(interface.overflow_page * interface.columns >= length(interface.grid.overflow))
			interface.overflow_page = 0
		interface.parent_storage.refresh_views()
		return
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) == LEFT_CLICK && !LAZYACCESS(modifiers, SHIFT_CLICK) && !LAZYACCESS(modifiers, ALT_CLICK) && !LAZYACCESS(modifiers, CTRL_CLICK))
		if(interface.repeat_click(src))
			return
		var/obj/item/held = usr.grid_inventory?.held_preview_item()
		if(held)
			interface.receive_drop(src, held)
			usr.grid_inventory?.refresh_hover()
			return
	else
		interface.cancel_click()
	if(action)
		return
	if(item)
		interface.item_click(item, params, src)
	else if(!take_only)
		var/obj/item/held = usr.get_active_held_item()
		if(held)
			interface.grid.insert_at(usr, held, cell_x, cell_y, FALSE)

/atom/movable/screen/grid_inventory/DblClick(location, control, params)
	if(usr != interface?.viewer || action)
		return
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		return
	interface.double_click(src)

/atom/movable/screen/grid_inventory/MouseEntered(location, control, params)
	if(usr != interface?.viewer || (action && action != "title" && action != "frame"))
		return
	if(usr.grid_inventory)
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
