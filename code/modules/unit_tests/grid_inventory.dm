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
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(grid, first)
	var/list/old_art_position = screen_loc_to_offset(display.screen_loc, world.view)
	session.mouse_down(null, first.titlebar, null, null, "button=left;left=1;screen-loc=3:0,3:0")
	session.mouse_drag(null, first.titlebar, null, null, null, null, null, "button=left;left=1;screen-loc=4:0,4:0")
	TEST_ASSERT_EQUAL(first.position_x, 104, "Title drag lost its horizontal grab offset")
	TEST_ASSERT_EQUAL(first.position_y, 96, "Title drag lost its vertical grab offset")
	var/list/new_art_position = screen_loc_to_offset(display.screen_loc, world.view)
	TEST_ASSERT_EQUAL(new_art_position[1] - old_art_position[1], 32, "Title drag separated item artwork from the panel horizontally")
	TEST_ASSERT_EQUAL(new_art_position[2] - old_art_position[2], 32, "Title drag separated item artwork from the panel vertically")
	TEST_ASSERT_EQUAL(length(first.list_ui_elements()), length(elements), "Title drag allocated new HUD objects")
	session.cancel_drag()
	qdel(session)
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

/datum/unit_test/grid_inventory_external_drag/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, user)
	TEST_ASSERT(user.equip_to_slot_if_possible(bag, ITEM_SLOT_BACK), "Could not equip the drag target bag")
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(grid, panel)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/obj/item/crowbar/item = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(user.put_in_hands(item), "External drag fixture could not hold its item")
	var/params = "button=left;left=1;screen-loc=5:16,3:16"
	session.mouse_down(null, item, null, null, params)
	TEST_ASSERT_EQUAL(session.drag_item, item, "Inventory item did not become the drag payload")
	var/atom/movable/screen/grid_inventory/target = panel.grid_cells[12]
	session.mouse_drag(null, item, target, null, null, null, null, params)
	TEST_ASSERT(session.dragging && panel.preview_display.alpha, "Inventory drag did not show a placement preview")
	TEST_ASSERT(session.rotate_drag(1), "Inventory drag could not rotate")
	session.mouse_up(null, target, null, null, params)
	panel.receive_drop(target)
	TEST_ASSERT_EQUAL(item.loc, bag, "Inventory drop did not insert into the bag")
	var/datum/grid_placement/placement = grid.placements[item]
	TEST_ASSERT_EQUAL(placement.x, 5, "Inventory drop ignored the target column")
	TEST_ASSERT_EQUAL(placement.y, 2, "Inventory drop ignored the target row")
	TEST_ASSERT_EQUAL(placement.rotated, 1, "Inventory drop lost the preview rotation")
	session.cancel_drag()
	// A worn item follows the same path and must still obey unequip restrictions.
	var/obj/item/clothing/glasses/regular/glasses = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(user.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES), "Could not equip the drag fixture")
	session.mouse_down(null, glasses, null, null, params)
	session.mouse_drag(null, glasses, panel.grid_cells[1], null, null, null, null, params)
	ADD_TRAIT(glasses, TRAIT_NODROP, TRAIT_GENERIC)
	panel.receive_drop(panel.grid_cells[1])
	TEST_ASSERT_EQUAL(user.get_item_by_slot(ITEM_SLOT_EYES), glasses, "Inventory drag bypassed no-drop")
	REMOVE_TRAIT(glasses, TRAIT_NODROP, TRAIT_GENERIC)
	TEST_ASSERT(session.dragging && session.can_drag_item(), "Worn drag lost its gesture or source access")
	TEST_ASSERT(grid.can_insert(glasses, user, messages = FALSE), "Unlocked glasses failed storage restrictions")
	TEST_ASSERT(grid.fits(glasses, 1, 1, session.drag_rotation), "Glasses do not fit their drop target")
	panel.receive_drop(panel.grid_cells[1])
	TEST_ASSERT_EQUAL(glasses.loc, bag, "Worn inventory item did not transfer")
	TEST_ASSERT_NULL(user.get_item_by_slot(ITEM_SLOT_EYES), "Worn drag left a stale equipment slot")
	session.cancel_drag()
	var/obj/item/crowbar/held = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.put_in_hands(held)
	var/atom/movable/screen/inventory/hand/hand = allocate(__IMPLIED_TYPE__)
	// HUD backgrounds and the real item sprite must resolve to the same payload.
	var/datum/hud/test_hud = allocate(/datum/hud, user)
	hand.hud = test_hud
	hand.held_index = user.active_hand_index
	session.mouse_down(null, hand, null, null, params)
	TEST_ASSERT_EQUAL(session.drag_item, held, "Hand-slot background did not resolve its held item")
	session.mouse_drag(null, hand, panel.grid_cells[21], null, null, null, null, params)
	panel.receive_drop(panel.grid_cells[21])
	TEST_ASSERT(user.is_holding(held), "Out-of-bounds inventory drop lost its item")
	session.mouse_drag(null, hand, bag, null, null, null, null, params)
	TEST_ASSERT(session.receive_inventory_drop(hand, bag), "Open bag inventory icon did not receive the drop")
	TEST_ASSERT_EQUAL(held.loc, bag, "Open bag inventory icon failed to auto-place the item")
	session.cancel_drag()
	hand.hud = null
	qdel(session)
	qdel(panel)
	qdel(test_hud)

/datum/unit_test/grid_inventory_container_drop/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, user)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/obj/item/storage/backpack/grid_pilot/nested = allocate(__IMPLIED_TYPE__, bag)
	nested.w_class = WEIGHT_CLASS_NORMAL
	var/datum/storage/backpack/grid/inner = nested.atom_storage
	inner.grid_height = 1
	inner.occupancy.len = inner.grid_width
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(grid, panel)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory/target = panel.grid_cells[1]
	TEST_ASSERT_EQUAL(target.item, nested, "Container drop fixture has no target")
	var/obj/item/crowbar/grid_sample/item = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.put_in_hands(item)
	var/params = "button=left;left=1;screen-loc=5:16,3:16"
	session.mouse_down(null, item, null, null, params)
	session.mouse_drag(null, item, target, null, null, null, null, params)
	panel.receive_drop(target)
	TEST_ASSERT_EQUAL(item.loc, nested, "Dropping onto a closed nested container did not insert")
	var/datum/grid_placement/placement = inner.placements[item]
	TEST_ASSERT_EQUAL(placement.height, 1, "Automatic insertion did not rotate to fit")
	TEST_ASSERT_EQUAL(placement.width, 3, "Automatic insertion changed the item footprint")
	session.cancel_drag()
	// Repeat from another grid, with no free hand involved.
	var/obj/item/crowbar/grid_sample/second = allocate(__IMPLIED_TYPE__, bag)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory/source_cell
	for(var/atom/movable/screen/grid_inventory/cell as anything in panel.grid_cells)
		if(cell.item == second)
			source_cell = cell
			break
	session.mouse_down(null, source_cell, null, null, params)
	session.mouse_drag(null, source_cell, target, null, null, null, null, params)
	inner.set_locked(STORAGE_FULLY_LOCKED)
	panel.receive_drop(target)
	TEST_ASSERT_EQUAL(second.loc, bag, "Container drop ignored the destination lock")
	inner.set_locked(STORAGE_NOT_LOCKED)
	panel.receive_drop(target)
	TEST_ASSERT_EQUAL(second.loc, nested, "Grid-to-container drop did not transfer")
	TEST_ASSERT_NULL(grid.placements[second], "Grid-to-container drop retained source occupancy")
	session.cancel_drag()
	var/obj/item/crowbar/grid_sample/third = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.put_in_hands(third)
	session.mouse_down(null, third, null, null, params)
	session.mouse_drag(null, third, target, null, null, null, null, params)
	panel.receive_drop(target)
	TEST_ASSERT(user.is_holding(third), "Full destination lost the held item")
	TEST_ASSERT_EQUAL(length(inner.overflow), 0, "Container drop overflowed the grid")
	qdel(session)
	qdel(panel)
	// Ordinary nested storage must reject footprints that cannot fit its fixed cells,
	// even while closed. The slot count alone is not a geometric capacity check.
	var/obj/item/storage/medkit/grid_sample/kit = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/too_wide = allocate(/obj/item, run_loc_floor_bottom_left)
	too_wide.w_class = WEIGHT_CLASS_SMALL
	too_wide.storage_footprint = list(2, 2)
	TEST_ASSERT(!kit.atom_storage.attempt_insert(too_wide, messages = FALSE), "Closed 7x1 medkit accepted a 2x2 item by expanding its grid")
	var/datum/storage/kit_storage = kit.atom_storage
	TEST_ASSERT(kit_storage.grid_enabled, "Closed nested storage did not acquire packing constraints")
	panel = allocate(/datum/storage_interface/grid, 'icons/hud/screen_midnight.dmi', grid, user)
	session = allocate(/datum/grid_inventory_session, user)
	session.add_panel(grid, panel)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	for(var/atom/movable/screen/grid_inventory/cell as anything in panel.grid_cells)
		if(cell.item == kit)
			target = cell
			break
	session.mouse_down(null, third, null, null, params)
	session.mouse_drag(null, third, target, null, null, null, null, params)
	panel.receive_drop(target)
	TEST_ASSERT_EQUAL(third.loc, kit, "Closed ordinary medkit rejected a fitting container drop")
	placement = kit_storage.placements[third]
	TEST_ASSERT_EQUAL(placement.width, 3, "Ordinary medkit did not auto-rotate the incoming crowbar")
	TEST_ASSERT_EQUAL(placement.height, 1, "Ordinary medkit grew instead of rotating")
	var/obj/item/crowbar/grid_sample/fourth = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(kit_storage.attempt_insert(fourth, messages = FALSE), "Ordinary insertion rejected a remaining three-cell gap")
	var/obj/item/lighter/grid_sample/tiny = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(kit_storage.attempt_insert(tiny, messages = FALSE), "Ordinary insertion rejected the last free cell")
	var/obj/item/lighter/grid_sample/no_room = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(!kit_storage.attempt_insert(no_room, messages = FALSE), "Seven occupied cells accepted another item")
	TEST_ASSERT_EQUAL(no_room.loc, run_loc_floor_bottom_left, "Failed ordinary insertion moved its source item")
	TEST_ASSERT_EQUAL(kit_storage.grid_height, 1, "Inserting into ordinary storage expanded its rows")
	TEST_ASSERT_EQUAL(length(kit_storage.overflow), 0, "Normal insertion used forced-content overflow as capacity")
	qdel(session)
	qdel(panel)
	// A partial final row is not extra capacity.
	var/obj/item/storage/medkit/grid_sample/partial = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	partial.atom_storage.max_slots = 8
	partial.atom_storage.enable_grid()
	TEST_ASSERT(partial.atom_storage.fits(no_room, 1, 2), "Eighth cell was unavailable")
	TEST_ASSERT(!partial.atom_storage.fits(no_room, 2, 2), "Partial final row added a ninth cell")

/datum/unit_test/grid_inventory_held_preview/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, user)
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', bag.atom_storage, user)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(bag.atom_storage, panel)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/obj/item/crowbar/grid_sample/held = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.put_in_hands(held)
	var/atom/movable/screen/grid_inventory/cell = panel.grid_cells[1]
	var/old_usr = usr
	usr = user
	cell.MouseEntered()
	usr = old_usr
	TEST_ASSERT(panel.preview_display.alpha > 0, "Hovering with an active-hand item did not show a placement preview")
	TEST_ASSERT(session.rotate_drag(1), "Held-item hover did not support rotation")
	TEST_ASSERT_EQUAL(panel.preview_display.last_width, 3, "Held preview did not rotate its footprint")
	TEST_ASSERT(!session.dragging && !session.mouse_held, "Held preview started a mouse drag")
	var/icon/valid_icon = icon(cell.icon)
	var/valid_fill = valid_icon.GetPixel(12, 12)
	TEST_ASSERT(valid_fill, "Held preview did not fill valid cells")
	var/atom/movable/screen/grid_inventory/edge = panel.grid_cells[7]
	usr = user
	edge.MouseEntered()
	usr = old_usr
	var/icon/invalid_icon = icon(edge.icon)
	TEST_ASSERT(invalid_icon.GetPixel(12, 12) != valid_fill, "Out-of-bounds held preview stayed green")
	usr = user
	edge.Click(null, null, "button=left;left=1")
	usr = old_usr
	TEST_ASSERT_EQUAL(user.get_active_held_item(), held, "Invalid held placement lost the item")
	session.mouse_down(null, cell, null, null, "button=left;left=1")
	session.mouse_up(null, cell, null, null, "button=left;left=1")
	usr = user
	cell.Click(null, null, "button=left;left=1")
	usr = old_usr
	TEST_ASSERT_EQUAL(held.loc, bag, "Click did not insert the held preview")
	var/datum/grid_placement/placement = bag.atom_storage.placements[held]
	TEST_ASSERT_EQUAL(placement.rotated, 1, "Held-item click discarded the preview rotation")
	user.put_in_hands(held)
	var/obj/item/lighter/grid_sample/stored = allocate(__IMPLIED_TYPE__, bag)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory/destination = panel.grid_cells[11]
	session.mouse_down(null, cell, null, null, "button=left;left=1")
	session.mouse_drag(null, cell, destination, null, null, null, null, "button=left;left=1")
	TEST_ASSERT_EQUAL(panel.preview_display.item, stored, "A stored-item drag displayed the active-hand item")
	panel.receive_drop(destination)
	placement = bag.atom_storage.placements[stored]
	TEST_ASSERT_EQUAL(placement.x, 4, "Stored-item drag did not reposition while a hand was occupied")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), held, "Stored-item drag moved the held item")
	session.cancel_drag(destination)
	TEST_ASSERT_EQUAL(panel.preview_display.item, held, "Ending a stored-item drag did not restore the held preview")
	var/obj/item/storage/medkit/grid_sample/kit = allocate(__IMPLIED_TYPE__, bag)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory/container_cell
	for(var/atom/movable/screen/grid_inventory/candidate as anything in panel.grid_cells)
		if(candidate.item == kit)
			container_cell = candidate
			break
	usr = user
	container_cell.MouseEntered()
	usr = old_usr
	TEST_ASSERT(panel.preview_display.alpha > 0, "Container hover hid the held item")
	TEST_ASSERT_EQUAL(panel.preview_display.item, held, "Container hover changed the displayed payload")
	var/icon/green_icon = grid_inventory_cell_icon("#75bf9160", filled = TRUE)
	for(var/atom/movable/screen/grid_inventory/candidate as anything in panel.grid_cells)
		var/icon/cell_icon = icon(candidate.icon)
		TEST_ASSERT_EQUAL(cell_icon.GetPixel(12, 12), candidate.item == kit ? green_icon.GetPixel(12, 12) : null, "Container hover must fill only the destination footprint")
	// Eligible destinations remain visible even when the held item is outside the panel.
	session.update_preview(null)
	var/icon/blue_icon = grid_inventory_cell_icon("#66b8df60", filled = TRUE)
	for(var/atom/movable/screen/grid_inventory/candidate as anything in panel.grid_cells)
		var/icon/cell_icon = icon(candidate.icon)
		TEST_ASSERT_EQUAL(cell_icon.GetPixel(12, 12), candidate.item == kit ? blue_icon.GetPixel(12, 12) : null, "Eligible container did not receive its blue footprint")
	session.mouse_down(null, user.loc, null, null, "button=left;left=1")
	session.mouse_up(null, user.loc, null, null, "button=left;left=1")
	var/icon/after_click_icon = icon(container_cell.icon)
	TEST_ASSERT_EQUAL(after_click_icon.GetPixel(12, 12), blue_icon.GetPixel(12, 12), "Clicking outside the panel erased eligible containers")
	// Drain equipment/layout timers so the lock must announce its own change.
	sleep(1)
	kit.atom_storage.set_locked(STORAGE_FULLY_LOCKED)
	sleep(1)
	var/icon/locked_icon = icon(container_cell.icon)
	TEST_ASSERT_NULL(locked_icon.GetPixel(12, 12), "Locked container remained blue")
	kit.atom_storage.set_locked(STORAGE_NOT_LOCKED)
	sleep(1)
	var/icon/unlocked_icon = icon(container_cell.icon)
	TEST_ASSERT_EQUAL(unlocked_icon.GetPixel(12, 12), blue_icon.GetPixel(12, 12), "Unlocking did not restore the eligible container hint")
	// The dragged payload, not the active hand, decides which containers are eligible.
	session.mouse_down(null, destination, null, null, "button=left;left=1")
	session.mouse_drag(null, destination, container_cell, null, null, null, null, "button=left;left=1")
	TEST_ASSERT_EQUAL(panel.preview_display.item, stored, "Container hover displayed the held item instead of the dragged item")
	session.cancel_drag()
	for(var/index in 1 to 2)
		var/obj/item/crowbar/grid_sample/filler = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
		TEST_ASSERT(kit.atom_storage.attempt_insert(filler, messages = FALSE), "Could not fill the container preview fixture")
	sleep(1)
	var/icon/full_icon = icon(container_cell.icon)
	TEST_ASSERT_NULL(full_icon.GetPixel(12, 12), "Filling a closed container left its blue hint stale")
	usr = user
	container_cell.MouseExited()
	container_cell.MouseEntered()
	container_cell.Click(null, null, "button=left;left=1")
	usr = old_usr
	TEST_ASSERT(panel.preview_display.alpha > 0, "Rejected container hover hid the held item")
	var/icon/red_icon = grid_inventory_cell_icon("#cf777760", filled = TRUE)
	var/icon/container_icon = icon(container_cell.icon)
	TEST_ASSERT_EQUAL(container_icon.GetPixel(12, 12), red_icon.GetPixel(12, 12), "Rejected container did not receive a red background")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), held, "Blocked container click lost the held item")
	user.swap_hand()
	sleep(1)
	TEST_ASSERT_EQUAL(panel.preview_display.alpha, 0, "Swapping to an empty hand retained a held preview")
	TEST_ASSERT(!session.rotate_drag(1), "Rotation was consumed without a held or dragged item")
	// A deliberate rotation must not be undone by the preceding pickup's click record.
	user.next_click = -1
	user.next_move = -1
	usr = user
	container_cell.Click(null, null, "button=left;left=1")
	usr = old_usr
	TEST_ASSERT_EQUAL(user.get_active_held_item(), kit, "Could not pick up the container rotation fixture")
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	session.update_preview(container_cell)
	TEST_ASSERT(session.rotate_drag(1), "Picked-up container could not rotate in hover")
	usr = user
	container_cell.Click(null, null, "button=left;left=1")
	usr = old_usr
	placement = bag.atom_storage.placements[kit]
	TEST_ASSERT(placement && placement.rotated == 1, "Click rollback replaced the chosen held rotation with the old placement")
	qdel(session)
	qdel(panel)

/datum/unit_test/grid_inventory_highlights/Run()
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/item = allocate(/obj/item, bag)
	item.storage_footprint = list(1, 2)
	item.storage_footprint_changed()
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	session.add_panel(grid, panel)
	var/atom/movable/screen/grid_inventory/lower = panel.grid_cells[1]
	var/atom/movable/screen/grid_inventory/upper = panel.grid_cells[8]
	var/atom/movable/screen/grid_inventory/empty = panel.grid_cells[2]
	var/old_usr = usr
	usr = user
	lower.MouseEntered()
	usr = old_usr
	var/icon/lower_icon = icon(lower.icon)
	var/hover_fill = lower_icon.GetPixel(12, 12)
	TEST_ASSERT(hover_fill, "Hover did not fill the cell behind the item")
	var/icon/upper_icon = icon(upper.icon)
	TEST_ASSERT_EQUAL(upper_icon.GetPixel(12, 12), hover_fill, "Hover did not fill the whole item footprint")
	var/icon/empty_icon = icon(empty.icon)
	TEST_ASSERT_NULL(empty_icon.GetPixel(12, 12), "Hover highlighted an unrelated empty cell")
	usr = user
	upper.MouseEntered()
	lower.MouseExited()
	usr = old_usr
	upper_icon = icon(upper.icon)
	TEST_ASSERT_EQUAL(upper_icon.GetPixel(12, 12), hover_fill, "A late exit cleared the newly hovered item cell")
	usr = user
	upper.MouseExited()
	usr = old_usr
	upper_icon = icon(upper.icon)
	TEST_ASSERT_NULL(upper_icon.GetPixel(12, 12), "Hover fill survived leaving the item")
	session.drag_panel = panel
	session.drag_source = lower
	session.drag_item = item
	session.drag_revision = grid.revision
	session.mouse_held = TRUE
	TEST_ASSERT(session.rotate_drag(1), "Highlight fixture did not start rotating")
	lower_icon = icon(lower.icon)
	var/valid_fill = lower_icon.GetPixel(12, 12)
	TEST_ASSERT(valid_fill && valid_fill != hover_fill, "Valid drag did not replace hover with a filled placement highlight")
	upper_icon = icon(upper.icon)
	TEST_ASSERT_NULL(upper_icon.GetPixel(12, 12), "Rotation left the old footprint highlighted")
	var/atom/movable/screen/grid_inventory/edge = panel.grid_cells[7]
	session.update_preview(edge)
	var/icon/edge_icon = icon(edge.icon)
	var/invalid_fill = edge_icon.GetPixel(12, 12)
	TEST_ASSERT(invalid_fill && invalid_fill != valid_fill, "Out-of-bounds drag did not use the invalid placement fill")
	lower_icon = icon(lower.icon)
	TEST_ASSERT_NULL(lower_icon.GetPixel(12, 12), "Moving the drag left the previous placement highlighted")
	usr = user
	session.pointer_dragged = TRUE
	edge.MouseExited()
	usr = old_usr
	edge_icon = icon(edge.icon)
	TEST_ASSERT_NULL(edge_icon.GetPixel(12, 12), "Leaving the grid retained the drag fill")
	TEST_ASSERT_EQUAL(panel.preview_display.alpha, 0, "Leaving the grid retained the preview sprite")
	TEST_ASSERT(session.rotate_drag(1), "Rotation outside the grid was not consumed")
	TEST_ASSERT_EQUAL(panel.preview_display.alpha, 0, "Rotation outside the grid resurrected the source preview")
	session.update_preview(empty)
	panel.reposition()
	session.update_preview(empty)
	TEST_ASSERT(panel.preview_display.alpha > 0, "Panel refresh left the same-cell drag preview hidden")
	session.cancel_drag()
	for(var/atom/movable/screen/grid_inventory/cell as anything in panel.grid_cells)
		var/icon/cell_icon = icon(cell.icon)
		TEST_ASSERT_NULL(cell_icon.GetPixel(12, 12), "Cancelling a drag retained a placement highlight")
	var/obj/item/storage/backpack/grid_pilot/other_bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage_interface/grid/other_panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', other_bag.atom_storage, user)
	other_panel.update_position(4, 16, 2, 16, 7, 3, user, other_bag)
	session.add_panel(other_bag.atom_storage, other_panel)
	session.drag_panel = panel
	session.drag_item = item
	session.drag_source = lower
	session.dragging = TRUE
	session.mouse_held = TRUE
	session.pointer_dragged = TRUE
	session.update_preview(other_panel.grid_cells[1])
	session.remove_panel(other_bag.atom_storage)
	TEST_ASSERT_NULL(session.hover_cell, "Closing the destination retained its hovered cell")
	qdel(other_panel)
	TEST_ASSERT(session.rotate_drag(1), "Closing the destination incorrectly cancelled the source drag")
	TEST_ASSERT_EQUAL(panel.preview_display.alpha, 0, "Closing the destination redirected its preview to the source")
	session.cancel_drag(lower)
	lower_icon = icon(lower.icon)
	TEST_ASSERT_EQUAL(lower_icon.GetPixel(12, 12), hover_fill, "Ending a drag over an item did not restore ordinary hover")
	TEST_ASSERT(!session.dragging && !session.mouse_held, "Restoring hover retained the completed drag")
	qdel(session)
	qdel(panel)

/datum/unit_test/grid_inventory_cross_panel_highlights/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, user)
	var/obj/item/storage/medkit/grid_sample/kit = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/storage/medkit/grid_sample/other_kit = allocate(__IMPLIED_TYPE__, bag)
	var/obj/item/crowbar/grid_sample/bar = allocate(__IMPLIED_TYPE__, kit)
	var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
	var/datum/storage_interface/grid/backpack = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', bag.atom_storage, user)
	session.add_panel(bag.atom_storage, backpack)
	backpack.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/datum/storage_interface/grid/nested = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', kit.atom_storage, user)
	session.add_panel(kit.atom_storage, nested)
	nested.update_position(4, 16, 2, 16, 7, 3, user, kit)
	var/atom/movable/screen/grid_inventory/source_cell = nested.grid_cells[1]
	TEST_ASSERT_EQUAL(source_cell.item, bar, "Cross-panel fixture has no source item")
	var/atom/movable/screen/grid_inventory/kit_cell
	var/atom/movable/screen/grid_inventory/other_kit_cell
	for(var/atom/movable/screen/grid_inventory/cell as anything in backpack.grid_cells)
		if(cell.item == kit)
			kit_cell = cell
		else if(cell.item == other_kit)
			other_kit_cell = cell
	// Drag out of the open medkit and across the backpack that holds it.
	var/params = "button=left;left=1;screen-loc=5:16,3:16"
	session.mouse_down(null, source_cell, null, null, params)
	session.mouse_drag(null, source_cell, backpack.grid_cells[19], null, null, null, null, params)
	var/icon/blue_icon = grid_inventory_cell_icon("#66b8df60", filled = TRUE)
	var/icon/kit_icon = icon(kit_cell.icon)
	TEST_ASSERT_EQUAL(kit_icon.GetPixel(12, 12), blue_icon.GetPixel(12, 12), "The container holding the dragged item was not marked eligible")
	var/icon/other_kit_icon = icon(other_kit_cell.icon)
	TEST_ASSERT_EQUAL(other_kit_icon.GetPixel(12, 12), blue_icon.GetPixel(12, 12), "A container outside the source panel was not marked eligible")
	session.mouse_drag(null, source_cell, kit_cell, null, null, null, null, params)
	var/icon/green_icon = grid_inventory_cell_icon("#75bf9160", filled = TRUE)
	kit_icon = icon(kit_cell.icon)
	TEST_ASSERT_EQUAL(kit_icon.GetPixel(12, 12), green_icon.GetPixel(12, 12), "Hovering the container holding the dragged item rejected it")
	var/revision = kit.atom_storage.revision
	backpack.receive_drop(kit_cell)
	TEST_ASSERT_EQUAL(bar.loc, kit, "Dropping onto its current container moved the item")
	TEST_ASSERT_EQUAL(kit.atom_storage.revision, revision, "Dropping onto its current container reinserted the item")
	session.cancel_drag()
	qdel(session)
	qdel(nested)
	qdel(backpack)

/datum/unit_test/grid_inventory_slot_proxy/Run()
	var/obj/item/storage/medkit/regular/medkit = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/storage = medkit.atom_storage
	var/original_capacity = storage.max_slots
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', storage, user)
	panel.update_position(4, 16, 2, 16, 7, 3, user, medkit)
	TEST_ASSERT(panel.uses_item_proxies() && panel.grid == storage, "Nested medkit did not retain its original storage owner")
	TEST_ASSERT_EQUAL(length(panel.item_displays), length(medkit.contents), "Medkit contents were missing from its panel")
	TEST_ASSERT_EQUAL(storage.max_slots, original_capacity, "Slot proxy changed ordinary storage capacity")
	var/obj/item/item = medkit.contents[1]
	var/datum/grid_placement/placement = panel.get_placement(item)
	var/list/footprint = item.get_storage_footprint()
	TEST_ASSERT_EQUAL(placement.width * placement.height, footprint[1] * footprint[2], "Nested container squeezed an item's footprint into one cell")
	var/list/elements = panel.list_ui_elements()
	TEST_ASSERT(!(item in elements), "Slot proxy exposed the world item as a screen object")
	TEST_ASSERT_NULL(item.screen_loc, "Slot proxy moved the world item onto the HUD")
	qdel(panel)
	for(var/atom/movable/screen/element as anything in elements)
		TEST_ASSERT(QDELETED(element), "Closing medkit proxy retained a screen object")
	TEST_ASSERT(!QDELETED(placement) && storage.placements[item] == placement, "Closing medkit discarded its physical placement")
	TEST_ASSERT_EQUAL(item.loc, medkit, "Closing medkit proxy moved its contents")
	TEST_ASSERT_EQUAL(medkit.atom_storage, storage, "Closing medkit proxy replaced its storage owner")

	// A long item's artwork must retain its scale when it moves into a smaller container.
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/obj/item/crowbar/grid_sample/bar = allocate(__IMPLIED_TYPE__, bag)
	var/datum/storage_interface/grid/backpack = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', bag.atom_storage, user)
	backpack.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory_art/display = backpack.item_displays[bar]
	var/mutable_appearance/before = display.overlays[1]
	var/matrix/before_transform = before.transform
	var/before_scale = abs(before_transform.a * before_transform.e - before_transform.b * before_transform.d)
	var/obj/item/storage/medkit/grid_sample/empty_kit = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	bar.forceMove(empty_kit)
	var/datum/storage_interface/grid/nested = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', empty_kit.atom_storage, user)
	nested.update_position(4, 16, 2, 16, 7, 3, user, empty_kit)
	display = nested.item_displays[bar]
	var/mutable_appearance/after = display.overlays[1]
	var/matrix/after_transform = after.transform
	var/after_scale = abs(after_transform.a * after_transform.e - after_transform.b * after_transform.d)
	TEST_ASSERT(abs(after_scale - before_scale) < 0.001, "Moving a crowbar into a nested medkit changed its artwork scale")
	var/datum/grid_placement/bar_placement = nested.get_placement(bar)
	TEST_ASSERT_EQUAL(bar_placement.width * bar_placement.height, 3, "Nested crowbar did not occupy three cells")
	TEST_ASSERT_EQUAL(bar_placement.height, 1, "Nested crowbar was not rotated to fit the existing row")
	TEST_ASSERT_EQUAL(nested.rows, 1, "Nested medkit grew a row to fit the crowbar")
	var/occupied_cells = 0
	for(var/atom/movable/screen/grid_inventory/cell as anything in nested.grid_cells)
		if(cell.item == bar)
			occupied_cells++
	TEST_ASSERT_EQUAL(occupied_cells, 3, "Nested crowbar artwork and mouse targets disagree")
	nested.preview_item(bar, nested.grid_cells[1], 1)
	TEST_ASSERT_EQUAL(nested.preview_display.last_width, 3, "Nested drag preview shrank a rotated crowbar")
	TEST_ASSERT_EQUAL(nested.preview_display.last_height, 1, "Nested drag preview lost the rotated footprint")
	user.active_storage = empty_kit.atom_storage
	TEST_ASSERT(nested.grid.move_item(user, bar, 3, 1, 1, nested.grid.revision), "Could not reposition the nested crowbar")
	nested.update_position(4, 16, 2, 16, 7, 3, user, empty_kit)
	bar_placement = nested.get_placement(bar)
	TEST_ASSERT_EQUAL(bar_placement.x, 3, "Refreshing nested storage moved a manually placed item")
	TEST_ASSERT_EQUAL(bar_placement.rotated, 1, "Refreshing nested storage lost item rotation")
	var/obj/item/lighter/grid_sample/lighter = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	TEST_ASSERT(!nested.grid.fits(lighter, 4, 1, 0), "Nested placement accepted an overlap")
	TEST_ASSERT(!nested.grid.fits(bar, 6, 1, 1), "Nested placement crossed the panel edge")
	qdel(nested)
	nested = allocate(/datum/storage_interface/grid, 'icons/hud/screen_midnight.dmi', empty_kit.atom_storage, user)
	nested.update_position(4, 16, 2, 16, 7, 3, user, empty_kit)
	TEST_ASSERT_EQUAL(nested.get_placement(bar), bar_placement, "Reopening nested storage repacked its contents")
	nested.grid.set_real_location(empty_kit)
	TEST_ASSERT_EQUAL(nested.get_placement(bar), bar_placement, "Reassigning the same storage location repacked its contents")
	// Forced contents remain recoverable, but cannot add usable capacity.
	for(var/index in 1 to 15)
		allocate(/obj/item/crowbar/grid_sample, empty_kit)
	nested.update_position(4, 16, 2, 16, 7, 3, user, empty_kit)
	TEST_ASSERT_EQUAL(nested.grid.grid_height, 1, "Forced contents expanded usable storage")
	TEST_ASSERT_EQUAL(length(nested.grid.placements), 1, "Forced contents occupied nonexistent cells")
	TEST_ASSERT(!nested.grid.can_insert(lighter, messages = FALSE), "Overflow allowed another insertion")
	var/list/seen = list()
	for(var/page in 0 to ceil(length(nested.grid.overflow) / nested.columns) - 1)
		nested.overflow_page = page
		nested.update_position(4, 16, 2, 16, 7, 3, user, empty_kit)
		for(var/obj/item/visible as anything in nested.item_displays)
			seen |= visible
		for(var/atom/movable/screen/grid_inventory/cell as anything in nested.grid_cells)
			if(cell.item in nested.grid.overflow)
				TEST_ASSERT(cell.take_only, "Forced contents became a placement destination")
	TEST_ASSERT_EQUAL(length(seen), length(empty_kit.contents), "Nested pagination made an item inaccessible")
	user.active_storage = null

/// Observe open requests without requiring a client; pickup still uses the real item path.
/obj/item/storage/grid_inventory_click_fixture
	storage_type = /datum/storage/grid_inventory_click_fixture
	storage_footprint = list(2, 1)
	w_class = WEIGHT_CLASS_SMALL

/datum/storage/grid_inventory_click_fixture
	var/open_requests = 0

/datum/storage/grid_inventory_click_fixture/open_storage(mob/living/to_show, can_reach_target = parent)
	open_requests++
	return TRUE

/datum/unit_test/grid_inventory_double_click/Run()
	var/plain_click = "button=left;left=1"
	for(var/use_grid in list(TRUE, FALSE))
		for(var/double_before_second in list(TRUE, FALSE))
			var/obj/item/storage/bag = allocate(use_grid ? /obj/item/storage/backpack/grid_pilot : /obj/item/storage/medkit/grid_sample, run_loc_floor_bottom_left)
			var/datum/storage/owner = bag.atom_storage
			if(!use_grid)
				owner.max_slots = 14 // A fixed two-row container exercises clicks above the first row.
			var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
			user.active_storage = owner
			var/obj/item/storage/grid_inventory_click_fixture/container = allocate(__IMPLIED_TYPE__, bag)
			var/datum/storage/grid_inventory_click_fixture/storage = container.atom_storage
			var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', owner, user)
			var/datum/grid_inventory_session/session = allocate(__IMPLIED_TYPE__, user)
			session.add_panel(owner, panel)
			panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
			TEST_ASSERT(panel.grid.move_item(user, container, 3, 1, 1, panel.grid.revision), "Could not arrange click fixture")
			panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
			var/cell_index = panel.columns + 3
			var/atom/movable/screen/grid_inventory/cell = panel.grid_cells[cell_index]
			var/old_usr = usr
			usr = user
			cell.Click(null, null, plain_click)
			usr = old_usr
			TEST_ASSERT_EQUAL(user.get_active_held_item(), container, "Single-click pickup waited for a double-click timeout")
			// Reproduce the real removal refresh without moving the second click's target.
			panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
			TEST_ASSERT(panel.rows >= 2 && !QDELETED(cell) && panel.grid_cells[cell_index] == cell, "Pickup destroyed the second click's target")
			TEST_ASSERT_NULL(cell.item, "Pickup refresh left the item in its old cell")
			panel.begin_click(cell, params2list(plain_click))
			usr = user
			if(double_before_second)
				cell.DblClick(null, null, plain_click)
				cell.Click(null, null, plain_click)
			else
				cell.Click(null, null, plain_click)
				cell.DblClick(null, null, plain_click)
			usr = old_usr
			TEST_ASSERT_EQUAL(storage.open_requests, 1, "Double-click order [double_before_second] did not open exactly once")
			TEST_ASSERT_EQUAL(container.loc, bag, "Double-click order [double_before_second] left the container in hand")
			var/datum/grid_placement/restored = panel.get_placement(container)
			TEST_ASSERT_EQUAL(restored.x, 3, "Double-click changed the original anchor")
			TEST_ASSERT_EQUAL(restored.y, 1, "Double-click used the clicked cell as the item's anchor")
			TEST_ASSERT_EQUAL(restored.rotated, 1, "Double-click lost the item's rotation")
			panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
			usr = user
			cell.DblClick(null, null, plain_click)
			cell.Click(null, null, "button=left;left=1;shift=1")
			cell.DblClick(null, null, "button=left;left=1;shift=1")
			usr = old_usr
			TEST_ASSERT_EQUAL(storage.open_requests, 1, "Duplicate double-click or double-examine reopened the container")
			// A new physical click is not swallowed by an arbitrary post-double-click timeout.
			panel.begin_click(cell, params2list(plain_click))
			user.next_click = -1
			user.next_move = -1
			usr = user
			cell.Click(null, null, plain_click)
			usr = old_usr
			TEST_ASSERT_EQUAL(user.get_active_held_item(), container, "A new single click after opening was suppressed")
			user.dropItemToGround(container)
			usr = user
			cell.DblClick(null, null, plain_click)
			usr = old_usr
			TEST_ASSERT_EQUAL(container.loc, run_loc_floor_bottom_left, "Stale double-click reclaimed a dropped item")
			TEST_ASSERT_EQUAL(storage.open_requests, 1, "Stale double-click opened a dropped item")
			qdel(session)
			qdel(panel)

	// Another item may occupy the vacated cells before the second event arrives.
	var/obj/item/storage/backpack/grid_pilot/bag = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	var/datum/storage/backpack/grid/grid = bag.atom_storage
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
	user.active_storage = grid
	var/obj/item/storage/grid_inventory_click_fixture/container = allocate(__IMPLIED_TYPE__, bag)
	var/datum/storage_interface/grid/panel = allocate(__IMPLIED_TYPE__, 'icons/hud/screen_midnight.dmi', grid, user)
	panel.update_position(4, 16, 2, 16, 7, 3, user, bag)
	var/atom/movable/screen/grid_inventory/cell = panel.grid_cells[1]
	panel.item_click(container, plain_click, cell)
	TEST_ASSERT_EQUAL(user.get_active_held_item(), container, "Conflict fixture did not pick up immediately")
	var/obj/item/blocker = allocate(/obj/item, bag)
	TEST_ASSERT(!panel.double_click(cell), "Double-click ignored a newly occupied footprint")
	TEST_ASSERT_EQUAL(user.get_active_held_item(), container, "Failed click rollback lost the held item")
	TEST_ASSERT_EQUAL(blocker.loc, bag, "Failed click rollback displaced another item")
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
