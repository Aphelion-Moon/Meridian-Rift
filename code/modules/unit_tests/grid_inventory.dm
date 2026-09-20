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
	TEST_ASSERT_EQUAL(length(display.overlays), 2, "Inventory art and footprint border were not rendered")
	qdel(placement)

/datum/unit_test/grid_inventory_interface/Run()
	var/obj/item/storage/backpack/grid_pilot/sample/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage_interface/grid/first = new('icons/hud/screen_midnight.dmi', grid, user)
	var/datum/storage_interface/grid/second = new('icons/hud/screen_retro.dmi', grid, user)
	first.update_position(4, 16, 2, 16, 7, 3, user, bag)
	second.update_position(4, 16, 2, 16, 7, 3, user, bag)
	TEST_ASSERT_EQUAL(length(first.item_displays), 4, "Missing preloaded displays")
	var/obj/item/item = bag.contents[1]
	var/atom/movable/screen/grid_inventory_art/display = first.item_displays[item]
	TEST_ASSERT_NOTEQUAL(display, second.item_displays[item], "Viewer displays are shared")
	var/datum/grid_placement/placement = grid.placements[item]
	var/list/elements = first.list_ui_elements()
	first.update_position(4, 16, 2, 16, 7, 3, user, bag)
	TEST_ASSERT_EQUAL(first.item_displays[item], display, "Refresh replaced a display")
	TEST_ASSERT_EQUAL(length(first.list_ui_elements()), length(elements), "Refresh grew HUD object count")
	qdel(first)
	for(var/atom/movable/screen/element as anything in elements)
		TEST_ASSERT(QDELETED(element), "Closing the interface retained a screen object")
	TEST_ASSERT_EQUAL(grid.placements[item], placement, "Closing the interface lost placement")
	TEST_ASSERT(!QDELETED(second.item_displays[item]), "Closing one viewer deleted another viewer's display")
	qdel(second)

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
