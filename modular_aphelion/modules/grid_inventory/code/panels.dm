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
	var/atom/movable/screen/grid_inventory/tooltip
	/// Invalidates a client text measurement when the hover, panel position or theme changes.
	var/tooltip_generation = 0
	var/obj/item/pending_click
	var/click_timer
	var/click_generation = 0
	var/datum/weakref/opened_container_ref
	var/suppress_click_until = 0

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
	tooltip = new(null, user.hud_used)
	for(var/atom/movable/screen/grid_inventory/element as anything in list(frame, titlebar, close_button, page_button, tooltip))
		element.interface = src
	frame.action = "frame"
	titlebar.action = "title"
	close_button.action = "close"
	close_button.name = "Close container"
	page_button.action = "page"
	page_button.name = "Next page"
	tooltip.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	tooltip.alpha = 0
	preview_display = new(null, user.hud_used)
	preview_display.alpha = 0
	update_ui_style(new_style)

/datum/storage_interface/grid/uses_item_proxies()
	return TRUE

/datum/storage_interface/grid/list_ui_elements(initializing = FALSE)
	. = list(frame, titlebar, close_button, page_button, tooltip, preview_display) + grid_cells
	for(var/obj/item/item as anything in item_displays)
		. += item_displays[item]

/datum/storage_interface/grid/Destroy()
	cancel_click()
	QDEL_LIST(grid_cells)
	QDEL_LIST_ASSOC_VAL(item_displays)
	QDEL_LIST_ASSOC_VAL(slot_placements)
	QDEL_NULL(frame)
	QDEL_NULL(titlebar)
	QDEL_NULL(close_button)
	QDEL_NULL(page_button)
	QDEL_NULL(tooltip)
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
		columns = clamp(parent_storage.max_slots, 1, 7)
		rows = clamp(ceil(max(length(contents), min(parent_storage.max_slots, 21)) / columns), 1, 6)
		var/page_size = columns * rows
		overflow_page = min(overflow_page, max(0, ceil(length(contents) / page_size) - 1))
		QDEL_LIST_ASSOC_VAL(slot_placements)
		for(var/index in overflow_page * page_size + 1 to min(length(contents), (overflow_page + 1) * page_size))
			var/cell_index = index - overflow_page * page_size - 1
			var/obj/item/item = contents[index]
			slot_placements[item] = new /datum/grid_placement(cell_index % columns + 1, round(cell_index / columns) + 1, 1, 1, slot_rotations[item] || 0)
			visible_items[item] = slot_placements[item]
		for(var/obj/item/item as anything in slot_rotations.Copy())
			if(item.loc != real_location)
				slot_rotations -= item
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
			var/contents_index = overflow_page * columns * rows + index
			if(contents_index <= length(contents))
				cell.item = contents[contents_index]
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
	page_button.alpha = (grid ? length(grid.overflow) > columns : length(contents) > columns * rows) ? 255 : 0
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
	tooltip.layer = 1000

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
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		cell.color = null
		cell.icon = grid_inventory_cell_icon(cell.take_only ? "#ba8055" : null)

/datum/storage_interface/grid/proc/preview_item(obj/item/item, atom/movable/screen/grid_inventory/target, rotation)
	if(QDELETED(item))
		return
	var/datum/grid_inventory_session/session = viewer.grid_inventory
	var/valid = can_interact() && (!grid || grid.fits(item, target.cell_x, target.cell_y, rotation))
	if(item.loc != parent_storage.real_location)
		valid = valid && parent_storage.can_insert(item, viewer, messages = FALSE)
	else if(grid && session?.drag_panel == src)
		valid = valid && session.drag_revision == grid.revision
	var/list/size = grid ? item.get_storage_footprint() : list(1, 1)
	var/width = size[rotation % 2 ? 2 : 1]
	var/height = size[rotation % 2 ? 1 : 2]
	var/preview_color = valid ? "#75bf91" : "#cf7777"
	for(var/atom/movable/screen/grid_inventory/cell as anything in grid_cells)
		if(!cell.take_only && cell.cell_x >= target.cell_x && cell.cell_y >= target.cell_y && cell.cell_x < target.cell_x + width && cell.cell_y < target.cell_y + height)
			cell.icon = grid_inventory_cell_icon(preview_color)
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
		if(grid)
			grid.move_item(viewer, item, target.cell_x, target.cell_y, session.drag_rotation, session.drag_revision)
		else
			slot_rotations[item] = session.drag_rotation
			var/target_index = (target.cell_y - 1) * columns + target.cell_x + overflow_page * columns * rows
			var/list/contents = parent_storage.real_location.contents
			var/old_index = contents.Find(item)
			if(old_index && target_index <= length(contents))
				contents.Swap(old_index, target_index)
			parent_storage.refresh_views()
		return
	// Cross-container transfers use the existing pickup/removal path and insertion restrictions.
	if(!session.drag_panel.can_interact() || !parent_storage.can_insert(item, viewer, messages = FALSE))
		return
	if(grid && !grid.fits(item, target.cell_x, target.cell_y, session.drag_rotation))
		return
	var/rotation = session.drag_rotation
	var/target_x = target.cell_x
	var/target_y = target.cell_y
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
	if(!QDELETED(user) && !QDELETED(src) && !QDELETED(source_panel) && !QDELETED(target) && source_panel.can_interact() && can_interact() && (!destination_grid || (!destination_grid.pending_item && destination_grid.fits(item, target_x, target_y, rotation))))
		if(destination_grid)
			destination_grid.pending_item = item
			destination_grid.pending_placement = destination_grid.make_placement(item, target_x, target_y, rotation)
		destination.attempt_insert(item, user)
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
	click_generation++
	if(click_timer)
		deltimer(click_timer)
		click_timer = null
	pending_click = null

/datum/storage_interface/grid/proc/item_click(obj/item/item, params)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location)
		return
	var/list/modifiers = params2list(params)
	if(!item.atom_storage || LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		viewer.ClickOn(item, params)
		return
	if(world.time <= suppress_click_until && IS_WEAKREF_OF(item, opened_container_ref))
		return
	// Native DblClick can arrive before or after the second ordinary Click.
	if(pending_click == item)
		open_container(item)
		return
	cancel_click()
	pending_click = item
	click_timer = addtimer(CALLBACK(src, PROC_REF(finish_click), item, params, click_generation), 0.5 SECONDS, TIMER_STOPPABLE)

/datum/storage_interface/grid/proc/open_container(obj/item/item)
	if(!can_interact() || QDELETED(item) || item.loc != parent_storage.real_location || !item.atom_storage)
		return FALSE
	if(world.time <= suppress_click_until && IS_WEAKREF_OF(item, opened_container_ref))
		return TRUE
	cancel_click()
	opened_container_ref = WEAKREF(item)
	suppress_click_until = world.time + 0.5 SECONDS
	return item.atom_storage.open_storage(viewer)

/datum/storage_interface/grid/proc/finish_click(obj/item/item, params, generation)
	if(pending_click != item || click_generation != generation)
		return
	click_timer = null
	pending_click = null
	click_generation++
	if(can_interact() && !QDELETED(item) && item.loc == parent_storage.real_location)
		viewer.ClickOn(item, params)

/datum/storage_interface/grid/proc/show_tooltip(atom/movable/screen/grid_inventory/cell)
	if(!cell.item || !viewer.client || viewer.grid_inventory?.dragging)
		return
	var/obj/item/item = cell.item
	var/category = item.atom_storage ? "Storage" : (item.tool_behaviour ? "Tool" : weight_class_to_text(item.w_class))
	var/description = length_char(item.desc) > 220 ? "[copytext_char(item.desc, 1, 218)]..." : item.desc
	var/details = html_encode(description)
	var/hint = item.atom_storage ? "Double-click to open" : "Click to take"
	var/tooltip_text = "<span style='font-family:Verdana;font-size:6pt;line-height:1;color:[palette["text"]]'><b>[html_encode(capitalize(item.name))]</b><br><span style='color:[palette["accent"]]'>\[[html_encode(category)]\]</span><br>[details]<br><span style='color:[palette["accent"]]'>[hint]<br>Drag; Q/E or wheel: rotate</span></span>"
	var/generation = ++tooltip_generation
	var/text_height = tooltip.maptext_height
	// Reuse the last measurement when crossing cells occupied by the same item.
	if(tooltip.maptext != tooltip_text)
		WXH_TO_HEIGHT(viewer.client.MeasureText(tooltip_text, null, 148), text_height)
	// MeasureText waits for the client; leaving or closing the panel cancels this hover.
	if(QDELETED(src) || generation != tooltip_generation || !viewer.client || !text_height)
		return
	var/height = text_height + 8
	tooltip.icon = grid_inventory_tooltip_icon(160, height, ui_style)
	tooltip.maptext_width = 148
	tooltip.maptext_height = text_height
	tooltip.maptext_x = 6
	tooltip.maptext_y = 4
	tooltip.maptext = tooltip_text
	var/list/offset = screen_loc_to_offset(cell.screen_loc, viewer.client?.view || world.view)
	var/list/view_size = view_to_pixels(viewer.client?.view || world.view)
	tooltip.screen_loc = offset_to_screen_loc(clamp(offset[1] + 24, 32, max(32, view_size[1] + 32 - 160)), clamp(offset[2] - height + 24, 32, max(32, view_size[2] + 32 - height)))
	tooltip.alpha = 255

/datum/storage_interface/grid/proc/hide_tooltip()
	tooltip_generation++
	tooltip.alpha = 0

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
		interface.overflow_page++
		var/total = interface.grid ? length(interface.grid.overflow) : length(interface.parent_storage.real_location.contents)
		var/page_size = interface.columns * (interface.grid ? 1 : interface.rows)
		if(interface.overflow_page * page_size >= total)
			interface.overflow_page = 0
		interface.parent_storage.refresh_views()
		return
	if(action)
		return
	if(item)
		interface.item_click(item, params)
	else if(!take_only)
		var/obj/item/held = usr.get_active_held_item()
		if(held)
			if(interface.grid)
				interface.grid.insert_at(usr, held, cell_x, cell_y, FALSE)
			else
				interface.parent_storage.attempt_insert(held, usr)

/atom/movable/screen/grid_inventory/DblClick(location, control, params)
	if(usr != interface?.viewer || !item?.atom_storage)
		return
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, BUTTON) != LEFT_CLICK || LAZYACCESS(modifiers, SHIFT_CLICK) || LAZYACCESS(modifiers, ALT_CLICK) || LAZYACCESS(modifiers, CTRL_CLICK))
		return
	interface.open_container(item)

/atom/movable/screen/grid_inventory/MouseEntered(location, control, params)
	if(usr != interface?.viewer || action)
		return
	if(usr.grid_inventory?.dragging)
		usr.grid_inventory.update_preview(src)
	else
		interface.show_tooltip(src)

/atom/movable/screen/grid_inventory/MouseExited()
	if(usr == interface?.viewer)
		interface.hide_tooltip()

/atom/movable/screen/grid_inventory/mouse_drop_receive(atom/dropped, mob/user, params)
	if(user == interface?.viewer)
		interface.receive_drop(src)
