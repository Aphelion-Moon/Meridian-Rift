/datum/unit_test/grid_inventory_packing/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/obj/item/item = allocate(/obj/item, run_loc_floor_bottom_left)
	item.storage_footprint = list(2, 3)
	TEST_ASSERT(!grid.fits(item, 7, 1), "Rectangle crossed right edge")
	TEST_ASSERT(!grid.fits(item, 1, 2), "Rectangle crossed top edge")
	TEST_ASSERT(!grid.fits(item, 0, 1), "Zero coordinate accepted")
	TEST_ASSERT(!grid.fits(item, 1.5, 1), "Fractional coordinate accepted")
	TEST_ASSERT(grid.fits(item, 5, 2, TRUE), "Rotated 3x2 should fit at top right")
	TEST_ASSERT(grid.attempt_insert(item, messages = FALSE), "Empty grid rejected fitting item")
	var/datum/grid_placement/placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.x, 1, "First-fit column")
	TEST_ASSERT_EQUAL(placement.y, 1, "First-fit row")
	TEST_ASSERT_EQUAL(placement.rotated, FALSE, "Prefer original orientation")
	var/obj/item/other = allocate(/obj/item, run_loc_floor_bottom_left)
	other.storage_footprint = list(1, 1)
	TEST_ASSERT(!grid.fits(other, 2, 3), "Overlap accepted")
	TEST_ASSERT(grid.fits(item, 1, 1), "Move collided with itself")
	// Fill columns 3-6, leaving a 1x3 fragment that only the rotated item can use.
	other.storage_footprint = list(4, 3)
	TEST_ASSERT(grid.attempt_insert(other, messages = FALSE), "Second rectangle failed insertion")
	var/obj/item/last = allocate(/obj/item, run_loc_floor_bottom_left)
	last.storage_footprint = list(3, 1)
	TEST_ASSERT(grid.attempt_insert(last, messages = FALSE), "First fit did not try both orientations")
	placement = grid.placements[last]
	TEST_ASSERT_EQUAL(placement.x, 7, "Fragment column")
	TEST_ASSERT_EQUAL(placement.rotated, TRUE, "Fragment orientation")
	TEST_ASSERT_EQUAL(last.dir, initial(last.dir), "Inventory rotation changed world direction")
	var/obj/item/no_room = allocate(/obj/item, run_loc_floor_bottom_left)
	TEST_ASSERT(!grid.can_insert(no_room, messages = FALSE), "Full grid admitted another item")
	grid.attempt_remove(other, run_loc_floor_bottom_left, silent = TRUE)
	TEST_ASSERT_EQUAL(grid.placements[last], placement, "Removal repacked another item")

/datum/unit_test/grid_inventory_lifecycle/Run()
	var/obj/item/storage/backpack/grid_pilot/sample/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	TEST_ASSERT_EQUAL(length(grid.placements), 4, "Preloaded items were not tracked")
	var/obj/item/crowbar/grid_sample/bar = locate() in bag
	var/datum/grid_placement/original = grid.placements[bar]
	bar.storage_footprint = list(8, 1)
	bar.storage_footprint_changed()
	TEST_ASSERT(bar in grid.overflow, "Unplaceable size change was not retained in overflow")
	TEST_ASSERT_EQUAL(bar.loc, bag, "Resize ejected an item")
	TEST_ASSERT(QDELETED(original), "Old placement leaked")
	var/obj/item/extra = allocate(/obj/item, run_loc_floor_bottom_left)
	TEST_ASSERT(!grid.can_insert(extra, messages = FALSE), "Overflow did not block insertion")
	bar.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT_EQUAL(length(grid.overflow), 0, "Direct removal did not clear overflow")
	TEST_ASSERT(grid.can_insert(extra, messages = FALSE), "Insertion did not recover after overflow cleared")
	extra.forceMove(bag)
	TEST_ASSERT(grid.placements[extra], "Direct movement was not tracked")
	qdel(extra)
	TEST_ASSERT(!(extra in grid.placements), "Deleted item retained a placement")
	TEST_ASSERT(!(extra in grid.occupancy), "Deleted item retained occupied cells")
	var/obj/item/stack/sheet/iron/stack = allocate(__IMPLIED_TYPE__, bag, 5)
	stack.use(1)
	TEST_ASSERT(grid.placements[stack], "Stack change lost placement")
	stack.update_weight_class(WEIGHT_CLASS_GIGANTIC)
	TEST_ASSERT(stack in grid.overflow, "Oversized item was not retained as take-only")
	TEST_ASSERT_EQUAL(stack.loc, bag, "Oversized stack remains accessible")

/datum/unit_test/grid_inventory_access/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/first = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/mob/living/carbon/human/consistent/second = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	first.active_storage = grid
	second.active_storage = grid
	var/obj/item/item = allocate(/obj/item, bag)
	item.storage_footprint = list(1, 2)
	item.storage_footprint_changed()
	var/revision = grid.revision
	TEST_ASSERT(grid.move_item(first, item, 3, 1, TRUE, revision), "Valid viewer move failed")
	var/datum/grid_placement/moved = grid.placements[item]
	TEST_ASSERT(!grid.move_item(second, item, 5, 1, FALSE, revision), "Stale concurrent move succeeded")
	TEST_ASSERT(!grid.move_item(first, item, 7, 3, TRUE, grid.revision), "Out-of-bounds move succeeded")
	TEST_ASSERT_EQUAL(grid.placements[item], moved, "Invalid move lost original placement")
	grid.set_locked(STORAGE_FULLY_LOCKED)
	TEST_ASSERT(!grid.move_item(first, item, 1, 1, FALSE, grid.revision), "Locked storage allowed a move")
	grid.set_locked(STORAGE_NOT_LOCKED)
	first.active_storage = null
	TEST_ASSERT(!grid.move_item(first, item, 1, 1, FALSE, grid.revision), "Closed viewer moved an item")
	item.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(!grid.move_item(second, item, 1, 1, FALSE, grid.revision), "Item outside storage was moved")
	second.active_storage = null

/datum/unit_test/grid_inventory_restrictions/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/obj/item/item = allocate(/obj/item, run_loc_floor_bottom_left)
	item.storage_footprint = list(1, 1)
	grid.max_slots = 0
	grid.max_total_storage = 0
	TEST_ASSERT(grid.can_insert(item, messages = FALSE), "Legacy capacity still limits the grid")
	item.update_weight_class(WEIGHT_CLASS_BULKY)
	TEST_ASSERT(!grid.can_insert(item, messages = FALSE), "Individual weight restriction was bypassed")
	grid.set_holdable(exception_hold_list = /obj/item)
	TEST_ASSERT(grid.can_insert(item, messages = FALSE), "Size exception was lost")
	grid.set_holdable(cant_hold_list = /obj/item)
	TEST_ASSERT(!grid.can_insert(item, messages = FALSE), "Deny list was bypassed")
	grid.set_holdable()
	var/obj/item/storage/backpack/nested = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	grid.max_specific_storage = WEIGHT_CLASS_BULKY
	TEST_ASSERT(!grid.can_insert(nested, messages = FALSE), "Equal-size nesting was allowed")
	TEST_ASSERT(!grid.can_insert(bag, messages = FALSE), "Self insertion was allowed")
	var/datum/storage/ordinary = nested.atom_storage
	ordinary.max_slots = 0
	TEST_ASSERT(!ordinary.can_insert(item, messages = FALSE), "Ordinary storage capacity changed")

/datum/unit_test/grid_inventory_appearance/Run()
	var/obj/item/storage/backpack/grid_pilot/sample/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	for(var/obj/item/sample in bag)
		var/mutable_appearance/art = sample.get_storage_inventory_appearance()
		TEST_ASSERT_NOTEQUAL(art.icon, sample.icon, "[sample.type] did not use its dedicated art")
		var/atom/movable/screen/grid_inventory_art/sample_display = allocate(__IMPLIED_TYPE__)
		sample_display.bind(sample)
		var/list/footprint = sample.get_storage_footprint()
		var/matrix/quarter_turn
		for(var/rotated in 0 to 3)
			var/width = footprint[rotated % 2 ? 2 : 1]
			var/height = footprint[rotated % 2 ? 1 : 2]
			var/datum/grid_placement/sample_placement = new(1, 1, width, height, rotated)
			sample_display.render(sample_placement)
			var/mutable_appearance/rendered = sample_display.overlays[1]
			var/icon/rendered_icon = icon(rendered.icon)
			TEST_ASSERT_EQUAL(rendered.pixel_x * 2 + rendered_icon.Width(), width * 24, "[sample.type] art is not horizontally centered (rotated=[rotated])")
			TEST_ASSERT_EQUAL(rendered.pixel_y * 2 + rendered_icon.Height(), height * 24, "[sample.type] art is not vertically centered (rotated=[rotated])")
			var/matrix/transform = rendered.transform
			var/fitted_width = abs(transform.a) * rendered_icon.Width() + abs(transform.b) * rendered_icon.Height()
			var/fitted_height = abs(transform.d) * rendered_icon.Width() + abs(transform.e) * rendered_icon.Height()
			TEST_ASSERT(fitted_width <= width * 24 - 3.99 && fitted_height <= height * 24 - 3.99, "[sample.type] art extends outside its footprint")
			TEST_ASSERT(abs(fitted_width - (width * 24 - 4)) < 0.01 || abs(fitted_height - (height * 24 - 4)) < 0.01, "[sample.type] art was shrunk using another icon's dimensions")
			if(rotated == 1)
				quarter_turn = transform
			else if(rotated == 2)
				TEST_ASSERT(transform.a < 0 && transform.e < 0 && abs(transform.b) < 0.01 && abs(transform.d) < 0.01, "[sample.type] half turn did not invert both artwork axes")
			else if(rotated == 3)
				TEST_ASSERT(transform.b * quarter_turn.b < 0 && transform.d * quarter_turn.d < 0, "[sample.type] left and right quarter turns rendered identically")
			qdel(sample_placement)
	var/obj/item/lighter/grid_sample/lighter = locate() in bag
	lighter.lit = TRUE
	lighter.update_appearance()
	var/mutable_appearance/lit_art = lighter.get_storage_inventory_appearance()
	TEST_ASSERT_EQUAL(lit_art.icon, lighter.icon, "Lit lighter did not show its live flame appearance")
	TEST_ASSERT_EQUAL(length(lit_art.overlays), 1, "HUD lost the engraving or retained a world lighting mask")
	var/obj/item/crowbar/grid_sample/item = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	item.color = "#aaccff"
	var/original_appearance = item.appearance
	var/atom/movable/screen/grid_inventory_art/display = allocate(__IMPLIED_TYPE__)
	display.bind(item)
	var/datum/grid_placement/placement = new(1, 1, 3, 1, TRUE)
	display.render(placement)
	TEST_ASSERT_EQUAL(item.appearance, original_appearance, "HUD rendering mutated world appearance")
	TEST_ASSERT_EQUAL(item.screen_loc, null, "World item acquired a HUD location")
	TEST_ASSERT_EQUAL(length(display.overlays), 1, "Inventory display should contain only the item art")
	qdel(placement)

/datum/unit_test/grid_inventory_interface/Run()
	var/obj/item/storage/backpack/grid_pilot/sample/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage_interface/grid/first = new('icons/hud/screen_midnight.dmi', grid, user)
	var/datum/storage_interface/grid/second = new('icons/hud/screen_retro.dmi', grid, user)
	first.update_position(4, 16, 2, 16, 7, 3, user, bag)
	second.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/icon/original_frame = icon(first.frame.icon)
	TEST_ASSERT_EQUAL(original_frame.Width(), 176, "Seven-column panel is not compact")
	TEST_ASSERT_EQUAL(original_frame.Height(), 104, "Three-row panel is not compact")
	TEST_ASSERT_EQUAL(length(first.item_displays), 4, "Missing preloaded displays")
	var/obj/item/item = bag.contents[1]
	var/atom/movable/screen/grid_inventory_art/display = first.item_displays[item]
	TEST_ASSERT_NOTEQUAL(display, second.item_displays[item], "Viewer displays are shared")
	var/datum/grid_placement/placement = grid.placements[item]
	var/list/elements = first.list_ui_elements()
	first.update_position(4, 16, 2, 16, 7, 3, user, bag)
	TEST_ASSERT_EQUAL(first.item_displays[item], display, "Refresh replaced a display")
	TEST_ASSERT_EQUAL(length(first.list_ui_elements()), length(elements), "Refresh grew HUD object count")
	first.position_x = 72
	first.position_y = 64
	first.reposition()
	var/frame_location = first.frame.screen_loc
	var/art_location = display.screen_loc
	first.update_ui_style('icons/hud/screen_retro.dmi')
	var/icon/updated_frame = icon(first.frame.icon)
	TEST_ASSERT_NOTEQUAL(updated_frame.GetPixel(10, 10), original_frame.GetPixel(10, 10), "Theme switch did not change the visible panel background")
	TEST_ASSERT_EQUAL(first.frame.screen_loc, frame_location, "Theme switch reset the moved panel position")
	TEST_ASSERT_EQUAL(first.item_displays[item], display, "Theme switch replaced an item display")
	TEST_ASSERT_EQUAL(display.screen_loc, art_location, "Theme switch displaced item artwork")
	TEST_ASSERT_EQUAL(length(first.list_ui_elements()), length(elements), "Theme switch grew HUD object count")
	qdel(first)
	for(var/atom/movable/screen/element as anything in elements)
		TEST_ASSERT(QDELETED(element), "Closing the interface retained a screen object")
	TEST_ASSERT_EQUAL(grid.placements[item], placement, "Closing the interface lost placement")
	TEST_ASSERT(!QDELETED(second.item_displays[item]), "Closing one viewer deleted another viewer's display")
	qdel(second)

/datum/unit_test/grid_inventory_drag_rotation/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/item = allocate(/obj/item, run_loc_floor_bottom_left)
	item.storage_footprint = list(1, 2)
	TEST_ASSERT(grid.attempt_insert(item, messages = FALSE), "Drag fixture did not fit")
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	// A synthetic viewer can exercise the gesture owner without a connected client's screen list.
	session.add_panel(grid, panel)
	session.drag_panel = panel
	session.drag_source = panel.grid_cells[1]
	session.drag_item = item
	session.drag_revision = grid.revision
	TEST_ASSERT(!session.rotate_drag(1), "Rotation consumed input without a held mouse button")
	session.mouse_held = TRUE
	TEST_ASSERT(session.rotate_drag(-1), "Left rotation was not consumed")
	TEST_ASSERT_EQUAL(session.drag_rotation, 3, "Left rotation did not wrap to 270 degrees")
	TEST_ASSERT(session.is_dragging(), "Rotating before pointer movement did not start a drag")
	TEST_ASSERT(panel.preview_display.alpha > 0, "Rotating did not show a placement preview")
	TEST_ASSERT(session.rotate_drag(1), "Right rotation was not consumed")
	TEST_ASSERT_EQUAL(session.drag_rotation, 0, "Opposite rotations did not restore the starting orientation")
	TEST_ASSERT(session.rotate_drag(1), "Second right rotation was not consumed")
	session.pointer_dragged = TRUE
	TEST_ASSERT(session.mouse_up(null, null, null, null, "button=left;left=1") & COMPONENT_CLIENT_MOUSEUP_INTERCEPT, "Drag release did not suppress pickup")
	TEST_ASSERT_EQUAL(panel.preview_display.alpha, 0, "Released drag retained its preview")
	TEST_ASSERT(session.is_dragging() && session.drag_item == item, "MouseUp discarded the pending drop payload")
	TEST_ASSERT(!session.rotate_drag(1), "Released drag still consumed rotation input")
	panel.receive_drop(session.drag_source)
	var/datum/grid_placement/placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.rotated, 1, "Same-cell drop lost its pending quarter turn")
	TEST_ASSERT_EQUAL(placement.width, 2, "Quarter turn did not swap footprint width")
	TEST_ASSERT_EQUAL(placement.height, 1, "Quarter turn did not swap footprint height")
	TEST_ASSERT(grid.move_item(user, item, 1, 1, 2, grid.revision), "Half-turn placement failed")
	placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.width, 1, "Half turn incorrectly swapped footprint width")
	TEST_ASSERT_EQUAL(placement.height, 2, "Half turn incorrectly swapped footprint height")
	session.cancel_drag()
	TEST_ASSERT(!session.is_dragging() && !session.drag_item && !session.drag_panel, "Cancelled drag retained its payload")
	TEST_ASSERT(!session.rotate_drag(-1), "Cancelled drag consumed rotation input")
	// A stationary rotation has no native MouseDrop event to finish its placement.
	session.drag_panel = panel
	session.drag_source = panel.grid_cells[1]
	session.drag_item = item
	session.drag_revision = grid.revision
	session.drag_rotation = placement.rotated
	session.mouse_held = TRUE
	TEST_ASSERT(session.rotate_drag(-1), "Stationary rotation was not consumed")
	TEST_ASSERT(session.mouse_up(null, null, null, null, "button=left;left=1") & COMPONENT_CLIENT_MOUSEUP_INTERCEPT, "Stationary rotation release did not suppress pickup")
	placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.rotated, 1, "Stationary rotation was not committed on MouseUp")
	TEST_ASSERT(!session.is_dragging() && !session.drag_item && !session.drag_panel, "Stationary rotation retained its completed gesture")
	qdel(session)
	TEST_ASSERT_NULL(user.grid_inventory, "Deleted session remained attached to its viewer")
	qdel(panel)

/datum/unit_test/grid_inventory_slot_proxy/Run()
	var/obj/item/storage/medkit/regular/medkit = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/storage = medkit.atom_storage
	var/original_capacity = storage.max_slots
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', storage, user)
	panel.update_position(4, 16, 2, 16, 7, 3, user, medkit)
	TEST_ASSERT(panel.uses_item_proxies() && !panel.grid, "Ordinary medkit did not use its slot proxy interface")
	TEST_ASSERT_EQUAL(length(panel.item_displays), length(medkit.contents), "Medkit contents were missing from its panel")
	TEST_ASSERT_EQUAL(storage.max_slots, original_capacity, "Slot proxy changed ordinary storage capacity")
	var/obj/item/item = medkit.contents[1]
	var/datum/grid_placement/placement = panel.get_placement(item)
	TEST_ASSERT_EQUAL(placement.width, 1, "Ordinary slot item acquired a grid footprint")
	TEST_ASSERT_EQUAL(placement.height, 1, "Ordinary slot item acquired a grid footprint")
	var/list/elements = panel.list_ui_elements()
	TEST_ASSERT(!(item in elements), "Slot proxy exposed the world item as a screen object")
	TEST_ASSERT_NULL(item.screen_loc, "Slot proxy moved the world item onto the HUD")
	qdel(panel)
	for(var/atom/movable/screen/element as anything in elements)
		TEST_ASSERT(QDELETED(element), "Closing medkit proxy retained a screen object")
	TEST_ASSERT(QDELETED(placement), "Closing medkit proxy retained a slot placement")
	TEST_ASSERT_EQUAL(item.loc, medkit, "Closing medkit proxy moved its contents")
	TEST_ASSERT_EQUAL(medkit.atom_storage, storage, "Closing medkit proxy replaced its storage owner")

/// Observe open requests without requiring a client; delayed pickup still uses the real item path.
/obj/item/storage/grid_inventory_click_fixture
	storage_type = /datum/storage/grid_inventory_click_fixture
	storage_footprint = list(1, 1)

/datum/storage/grid_inventory_click_fixture
	var/open_requests = 0

/datum/storage/grid_inventory_click_fixture/open_storage(mob/living/to_show, can_reach_target = parent)
	open_requests++
	return TRUE

/datum/unit_test/grid_inventory_double_click/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.active_storage = grid
	var/obj/item/storage/grid_inventory_click_fixture/container = allocate(__IMPLIED_TYPE__, bag)
	var/datum/storage/grid_inventory_click_fixture/storage = container.atom_storage
	var/plain_click = "button=left;left=1"
	for(var/double_before_second in list(TRUE, FALSE))
		var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
		panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
		var/atom/movable/screen/grid_inventory/cell = panel.grid_cells[1]
		var/opens_before = storage.open_requests
		var/old_usr = usr
		usr = user
		cell.Click(null, null, plain_click)
		var/cancelled_generation = panel.click_generation
		if(double_before_second)
			cell.DblClick(null, null, plain_click)
			cell.Click(null, null, plain_click)
		else
			cell.Click(null, null, plain_click)
			cell.DblClick(null, null, plain_click)
		usr = old_usr
		panel.finish_click(container, plain_click, cancelled_generation)
		sleep(0.6 SECONDS)
		TEST_ASSERT_EQUAL(storage.open_requests, opens_before + 1, "Double-click order [double_before_second] did not open exactly once")
		TEST_ASSERT_EQUAL(container.loc, bag, "Double-click order [double_before_second] picked up the container")
		TEST_ASSERT_NULL(panel.pending_click, "Double-click order [double_before_second] left a delayed pickup armed")
		usr = user
		cell.Click(null, null, "button=left;left=1;shift=1")
		cell.DblClick(null, null, "button=left;left=1;shift=1")
		usr = old_usr
		TEST_ASSERT_EQUAL(storage.open_requests, opens_before + 1, "Double-examine opened the container")
		qdel(panel)

	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	panel.item_click(container, plain_click)
	var/cancelled_generation = panel.click_generation
	panel.cancel_click()
	panel.item_click(container, plain_click)
	panel.finish_click(container, plain_click, cancelled_generation)
	TEST_ASSERT_EQUAL(container.loc, bag, "Cancelled callback picked up a newly clicked container")
	user.next_click = -1
	user.next_move = -1
	sleep(0.6 SECONDS)
	TEST_ASSERT_EQUAL(user.get_active_held_item(), container, "Standalone delayed click did not pick up the container")
	qdel(panel)
	user.active_storage = null

/datum/unit_test/grid_inventory_manual_insert/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.active_storage = grid
	var/obj/item/item = allocate(/obj/item, run_loc_floor_bottom_left)
	item.storage_footprint = list(1, 3)
	TEST_ASSERT(!grid.insert_at(user, item, 4, 2, TRUE), "Manual placement accepted an unheld item")
	user.put_in_hands(item)
	TEST_ASSERT(!grid.insert_at(user, item, 7, 3, TRUE), "Invalid held-item placement succeeded")
	TEST_ASSERT_EQUAL(item, user.get_active_held_item(), "Failed insertion removed held item")
	TEST_ASSERT(grid.insert_at(user, item, 4, 2, TRUE), "Manual held-item placement failed")
	var/datum/grid_placement/placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.x, 4, "Manual placement ignored chosen column")
	TEST_ASSERT_EQUAL(placement.y, 2, "Manual placement ignored chosen row")
	TEST_ASSERT_EQUAL(placement.rotated, TRUE, "Manual placement ignored chosen orientation")
	user.forceMove(locate(run_loc_floor_bottom_left.x + 5, run_loc_floor_bottom_left.y, run_loc_floor_bottom_left.z))
	TEST_ASSERT(!grid.move_item(user, item, 1, 1, FALSE, grid.revision), "Out-of-reach viewer moved an item")
	user.active_storage = null

// Opt-in measurements; no timing thresholds or routine CI benchmark load.
#ifdef GRID_INVENTORY_BENCHMARK
/datum/unit_test/grid_inventory_benchmark/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	for(var/bag_type in list(/obj/item/storage/backpack, /obj/item/storage/backpack/grid_pilot))
		var/obj/item/storage/backpack/bag = allocate(bag_type, run_loc_floor_bottom_left)
		var/datum/storage/storage = bag.atom_storage
		storage.animated = FALSE
		storage.do_rustle = FALSE
		var/obj/item/item = allocate(/obj/item, run_loc_floor_bottom_left)
		var/start = REALTIMEOFDAY
		for(var/index in 1 to 1000)
			TEST_ASSERT(storage.attempt_insert(item, messages = FALSE), "Benchmark insertion failed")
			storage.attempt_remove(item, run_loc_floor_bottom_left, silent = TRUE, visual_updates = FALSE)
		log_world("GRID BENCHMARK [bag_type]: 1000 insert/remove pairs, [(REALTIMEOFDAY - start) * 100] ms")
		storage.attempt_insert(item, messages = FALSE)
		var/list/interfaces = list()
		for(var/index in 1 to 20)
			var/datum/storage_interface/interface = new storage.storage_type('icons/hud/screen_midnight.dmi', storage, user)
			interface.update_position(4, 16, 2, 16, 7, 3, user, bag)
			interfaces += interface
		start = REALTIMEOFDAY
		for(var/index in 1 to 100)
			for(var/datum/storage_interface/interface as anything in interfaces)
				interface.update_position(4, 16, 2, 16, 7, 3, user, bag)
		log_world("GRID BENCHMARK [bag_type]: 100 refreshes of 20 synthetic interfaces, [(REALTIMEOFDAY - start) * 100] ms (no clients/network)")
		var/list/elements = list()
		for(var/datum/storage_interface/interface as anything in interfaces)
			elements |= interface.list_ui_elements()
		log_world("GRID BENCHMARK [bag_type]: [length(elements)] HUD objects across 20 synthetic interfaces")
		QDEL_LIST(interfaces)
		var/retained = 0
		for(var/atom/movable/screen/element as anything in elements)
			if(!QDELETED(element))
				retained++
		TEST_ASSERT_EQUAL(retained, 0, "Benchmark close retained HUD objects")
#endif

/// Exercise invalidation during the real removal callback, including storage-first teardown.
/datum/unit_test/grid_inventory_transfer_lifecycle
	var/datum/storage/invalidated_destination
	var/mob/transfer_user
	var/lock_source = FALSE

/datum/unit_test/grid_inventory_transfer_lifecycle/Destroy()
	invalidated_destination = null
	transfer_user = null
	return ..()

/datum/unit_test/grid_inventory_transfer_lifecycle/proc/invalidate_destination(datum/storage/source)
	SIGNAL_HANDLER
	invalidated_destination.hide_contents(transfer_user)
	if(lock_source)
		source.set_locked(STORAGE_FULLY_LOCKED)

/datum/unit_test/grid_inventory_transfer_lifecycle/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	transfer_user = user
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/obj/item/nested = allocate(/obj/item, bag)
	invalidated_destination = nested.create_storage()
	var/obj/item/item = allocate(/obj/item, bag)
	item.storage_footprint = list(1, 2)
	item.storage_footprint_changed()
	var/datum/storage_interface/grid/source_panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	var/datum/storage_interface/grid/target_panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', invalidated_destination, user)
	source_panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	target_panel.update_position(4, 16, 2, 16, 7, 3, user, nested)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(grid, source_panel)
	session.add_panel(invalidated_destination, target_panel)
	TEST_ASSERT(grid.move_item(user, item, 5, 2, 1, grid.revision), "Transfer fixture could not place its source item")
	RegisterSignal(grid, COMSIG_STORAGE_REMOVED_ITEM, PROC_REF(invalidate_destination))
	for(var/should_lock in 0 to 1)
		lock_source = should_lock
		session.add_panel(invalidated_destination, target_panel)
		session.drag_panel = source_panel
		session.drag_item = item
		session.drag_rotation = 1
		session.drag_revision = grid.revision
		session.dragging = TRUE
		target_panel.receive_drop(target_panel.grid_cells[1])
		if(should_lock)
			TEST_ASSERT_EQUAL(item.loc, user, "Failed rollback stranded the item outside its owner's hands")
			TEST_ASSERT(user.is_holding(item), "Failed rollback left the item in inaccessible mob contents")
		else
			TEST_ASSERT_EQUAL(item.loc, bag, "Closing the destination during removal did not restore the source item")
			var/datum/grid_placement/restored = grid.placements[item]
			TEST_ASSERT(restored, "Rollback lost the source placement")
			TEST_ASSERT_EQUAL(restored.x, 5, "Rollback changed the original column")
			TEST_ASSERT_EQUAL(restored.y, 2, "Rollback changed the original row")
			TEST_ASSERT_EQUAL(restored.rotated, 1, "Rollback changed the original rotation")
	UnregisterSignal(grid, COMSIG_STORAGE_REMOVED_ITEM)
	// The storage owns its signal sources and must detach its session before clearing them.
	TEST_ASSERT(!QDELETED(session) && session.panels[grid], "Fixture closed its session before storage-first teardown")
	qdel(bag)
	TEST_ASSERT(QDELETED(session), "Deleting storage before its session left the session alive")
	TEST_ASSERT_NULL(user.grid_inventory, "Storage-first deletion retained the viewer's session")
	TEST_ASSERT(!length(session.panels), "Storage-first deletion retained a deleted storage key")
