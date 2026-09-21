/client
	/// Rotation keys stay claimed until release, even if their drag ends first.
	var/list/grid_inventory_keys_held

/// Claims grid rotation before native movement, bindings and focus handlers run.
/client/proc/grid_inventory_key(key, pressed)
	if(key in grid_inventory_keys_held)
		if(!pressed)
			LAZYREMOVE(grid_inventory_keys_held, key)
		return TRUE
	if(!pressed || (key != "Q" && key != "E") || (key in keys_held))
		return FALSE
	if(!mob?.grid_inventory?.rotate_drag(key == "Q" ? -1 : 1))
		return FALSE
	LAZYADD(grid_inventory_keys_held, key)
	return TRUE

/// Claims vertical scrolling before held tools receive their mode-change signal.
/client/proc/grid_inventory_scroll(delta_y)
	if(!delta_y)
		return FALSE
	return mob?.grid_inventory?.rotate_drag(delta_y > 0 ? 1 : -1)
