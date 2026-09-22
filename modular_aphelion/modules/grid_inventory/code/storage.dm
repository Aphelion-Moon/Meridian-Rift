/// A placement belongs to its container, never to the item's world appearance.
/datum/grid_placement
	var/x
	var/y
	var/width
	var/height
	/// Clockwise quarter turns, 0 through 3. Parity determines the physical footprint.
	var/rotated

/datum/grid_placement/New(x, y, width, height, rotated = FALSE)
	src.x = x
	src.y = y
	src.width = width
	src.height = height
	src.rotated = rotated

/datum/storage/backpack/grid
	storage_type = /datum/storage_interface/grid
	separate_item_displays = TRUE

/// Packing belongs to the original storage owner, including ordinary nested containers.
/datum/storage
	var/grid_enabled = FALSE
	var/grid_width = 7
	var/grid_height = 3
	var/grid_capacity
	var/list/occupancy
	var/list/placements
	/// Forced/preloaded items which cannot fit stay accessible, but cannot be rearranged.
	var/list/overflow
	var/revision = 0
	var/obj/item/pending_item
	var/datum/grid_placement/pending_placement

/datum/storage/backpack/grid/New()
	..()
	enable_grid(grid_width, grid_height)

/datum/storage/proc/enable_grid(width, height)
	if(grid_enabled)
		return
	grid_enabled = TRUE
	// Keep the compact panel's original capacity; never grow it to fit its contents.
	grid_capacity = isnull(width) ? max(0, min(max_slots, round(max_total_storage / WEIGHT_CLASS_TINY), 21)) : width * height
	grid_width = width || clamp(grid_capacity, 1, 7)
	grid_height = height || max(1, ceil(grid_capacity / grid_width))
	occupancy = new /list(grid_width * grid_height)
	placements = list()
	overflow = list()
	for(var/obj/item/item in real_location)
		track_item(item)

/datum/storage/proc/clear_grid()
	for(var/obj/item/item as anything in placements + overflow)
		untrack_item(item)
	QDEL_NULL(pending_placement)
	pending_item = null

/// Checks only the proposed rectangle; ignoring an item makes moves atomic.
/datum/storage/proc/fits(obj/item/item, x, y, rotated = FALSE)
	var/list/size = item.get_storage_footprint()
	if(rotated != round(rotated) || rotated < 0 || rotated > 3)
		return FALSE
	var/width = size[rotated % 2 ? 2 : 1]
	var/height = size[rotated % 2 ? 1 : 2]
	if(width < 1 || height < 1 || width != round(width) || height != round(height))
		return FALSE
	if(x != round(x) || y != round(y) || x < 1 || y < 1 || x + width - 1 > grid_width || y + height - 1 > grid_height)
		return FALSE
	for(var/cell_y in y to y + height - 1)
		for(var/cell_x in x to x + width - 1)
			var/index = (cell_y - 1) * grid_width + cell_x
			if(index > grid_capacity)
				return FALSE
			var/obj/item/occupant = occupancy[index]
			if(occupant && occupant != item)
				return FALSE
	return TRUE

/datum/storage/proc/first_fit(obj/item/item, rotation = 0)
	for(var/cell_y in 1 to grid_height)
		for(var/cell_x in 1 to grid_width)
			for(var/rotated in list(rotation, (rotation + 1) % 4))
				if(fits(item, cell_x, cell_y, rotated))
					return make_placement(item, cell_x, cell_y, rotated)

/datum/storage/proc/make_placement(obj/item/item, x, y, rotated)
	var/list/size = item.get_storage_footprint()
	return new /datum/grid_placement(x, y, size[rotated % 2 ? 2 : 1], size[rotated % 2 ? 1 : 2], rotated)

/datum/storage/proc/clear_placement(obj/item/item)
	var/datum/grid_placement/old = placements[item]
	if(!old)
		return
	for(var/cell_y in old.y to old.y + old.height - 1)
		for(var/cell_x in old.x to old.x + old.width - 1)
			occupancy[(cell_y - 1) * grid_width + cell_x] = null
	placements -= item
	qdel(old)

/datum/storage/proc/commit_placement(obj/item/item, datum/grid_placement/placement)
	clear_placement(item)
	overflow -= item
	if(placement)
		placements[item] = placement
		for(var/cell_y in placement.y to placement.y + placement.height - 1)
			for(var/cell_x in placement.x to placement.x + placement.width - 1)
				occupancy[(cell_y - 1) * grid_width + cell_x] = item
	else
		overflow |= item
	revision++
	refresh_parent_grid_previews()

/// A closed container can change eligibility without refreshing any panel of its own.
/datum/storage/proc/refresh_parent_grid_previews()
	var/datum/storage/enclosing_storage = parent?.loc?.atom_storage
	for(var/mob/user as anything in enclosing_storage?.storage_interfaces)
		if(user.grid_inventory)
			addtimer(CALLBACK(user.grid_inventory, TYPE_PROC_REF(/datum/grid_inventory_session, refresh_hover)), 0, TIMER_UNIQUE)

/datum/storage/backpack/grid/has_capacity(obj/item/to_insert)
	return grid_has_capacity(to_insert)

/datum/storage/proc/grid_has_capacity(obj/item/to_insert)
	if(length(overflow))
		return FALSE
	if(to_insert == pending_item && pending_placement)
		return fits(to_insert, pending_placement.x, pending_placement.y, pending_placement.rotated)
	var/datum/grid_placement/free = first_fit(to_insert)
	. = !isnull(free)
	qdel(free)

/datum/storage/proc/track_item(obj/item/item)
	if(QDELETED(item))
		return
	// The after-initialize callback also catches storage created during item initialization.
	item.atom_storage?.enable_grid()
	if(placements[item] || item in overflow)
		return
	RegisterSignal(item, COMSIG_ITEM_WEIGHT_CLASS_CHANGED, PROC_REF(item_resized))
	RegisterSignal(item, COMSIG_QDELETING, PROC_REF(item_deleted))
	var/datum/grid_placement/placement
	if(item == pending_item && pending_placement && fits(item, pending_placement.x, pending_placement.y, pending_placement.rotated))
		placement = make_placement(item, pending_placement.x, pending_placement.y, pending_placement.rotated)
	else
		placement = first_fit(item)
	commit_placement(item, placement)

/datum/storage/proc/untrack_item(obj/item/item)
	UnregisterSignal(item, list(COMSIG_ITEM_WEIGHT_CLASS_CHANGED, COMSIG_QDELETING))
	clear_placement(item)
	overflow -= item
	revision++
	refresh_parent_grid_previews()

/datum/storage/proc/item_deleted(obj/item/source)
	SIGNAL_HANDLER
	untrack_item(source)
	refresh_views()

/datum/storage/proc/item_resized(obj/item/source)
	SIGNAL_HANDLER
	var/datum/grid_placement/old = placements[source]
	// Retain the player's anchor and orientation; never repack unrelated items.
	var/datum/grid_placement/replacement
	if(old && fits(source, old.x, old.y, old.rotated))
		replacement = make_placement(source, old.x, old.y, old.rotated)
	commit_placement(source, replacement)
	refresh_views()

/datum/storage/proc/grid_contents_changed_w_class(obj/item/changed, new_w_class)
	SIGNAL_HANDLER
	// Geometry changes are handled above. Oversized contents remain take-only as well.
	if(new_w_class > max_specific_storage && !is_type_in_typecache(changed, exception_hold))
		commit_placement(changed, null)
		refresh_views()

/// All HUD mutations recheck access and ownership at the time of the action.
/datum/storage/proc/can_grid_interact(mob/user)
	if(user.grid_inventory)
		return user.grid_inventory.can_interact(src)
	if(!isliving(user) || user.active_storage != src || locked || ismecha(user.loc))
		return FALSE
	var/mob/living/living_user = user
	return (living_user.mobility_flags & MOBILITY_STORAGE) && user.can_perform_action(parent, FORBID_TELEKINESIS_REACH)

/datum/storage/proc/move_item(mob/user, obj/item/item, x, y, rotated, expected_revision)
	if(!can_grid_interact(user) || QDELETED(item) || item.loc != real_location || !placements[item])
		return FALSE
	if(expected_revision != revision || !fits(item, x, y, rotated))
		return FALSE
	commit_placement(item, make_placement(item, x, y, rotated))
	refresh_views()
	return TRUE

/datum/storage/proc/insert_at(mob/user, obj/item/item, x, y, rotated)
	if(!can_grid_interact(user) || QDELETED(item) || item != user.get_active_held_item() || pending_item)
		return FALSE
	if(!fits(item, x, y, rotated))
		return FALSE
	pending_item = item
	pending_placement = make_placement(item, x, y, rotated)
	. = attempt_insert(item, user) && item.loc == real_location
	pending_item = null
	QDEL_NULL(pending_placement)

/datum/storage/backpack/grid/refresh_views()
	var/list/viewers = list()
	for(var/mob/user in can_see_contents())
		if(!isobserver(user) && !can_grid_interact(user))
			hide_contents(user)
		else
			viewers += user
	// Orient once per mutation, not once per viewer (which would be quadratic).
	orient_storage()
	for(var/mob/user as anything in viewers)
		var/list/elements = storage_interfaces[user].list_ui_elements()
		LAZYOR(user.hud_used.screen_groups[HUD_GROUP_STORAGE], elements)
		user.client.screen |= elements

/datum/storage/backpack/grid/orient_storage()
	for(var/mob/user as anything in storage_interfaces)
		storage_interfaces[user].update_position(screen_start_x, screen_pixel_x, screen_start_y, screen_pixel_y, grid_width, grid_height, user, real_location)

// Physical items never serve as grid drop targets.
/datum/storage/backpack/grid/mousedrop_receive(atom/dropped_onto, atom/movable/target, mob/user, params)
	return
