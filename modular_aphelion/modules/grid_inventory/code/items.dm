/// Optional physical footprint, independent of world icons and inventory artwork.
/obj/item
	var/list/storage_footprint
	var/storage_inventory_icon

/obj/item/proc/get_storage_footprint()
	if(storage_footprint)
		return storage_footprint.Copy()
	switch(w_class)
		if(WEIGHT_CLASS_TINY)
			return list(1, 1)
		if(WEIGHT_CLASS_SMALL)
			return list(1, 2)
		if(WEIGHT_CLASS_NORMAL)
			return list(1, 3)
		if(WEIGHT_CLASS_BULKY)
			return list(2, 2)
		if(WEIGHT_CLASS_HUGE)
			return list(2, 3)
	return list(3, 3)

/// Call after changing custom footprint state (weight changes already notify storage).
/obj/item/proc/storage_footprint_changed()
	SEND_SIGNAL(src, COMSIG_ITEM_WEIGHT_CLASS_CHANGED, w_class, w_class)

/// Mutable copy: transforming this must never transform the world item.
/obj/item/proc/get_storage_inventory_appearance()
	// Changed states/overlays use the live appearance until dedicated variants exist.
	if(storage_inventory_icon && can_use_storage_inventory_art())
		var/static/list/sampled_art = list()
		if(!sampled_art[storage_inventory_icon])
			var/icon/art = icon(storage_inventory_icon)
			var/scale = min(1, 96 / max(art.Width(), art.Height()))
			art.Scale(max(1, round(art.Width() * scale)), max(1, round(art.Height() * scale)))
			sampled_art[storage_inventory_icon] = art
		var/mutable_appearance/art = mutable_appearance(sampled_art[storage_inventory_icon])
		art.color = color
		return art
	var/mutable_appearance/live_art = new(appearance)
	live_art.overlays = get_storage_inventory_overlays()
	return live_art

/// World lighting masks are not item artwork and must not enter the HUD planes.
/obj/item/proc/get_storage_inventory_overlays()
	var/list/visible_overlays = list()
	for(var/mutable_appearance/overlay as anything in overlays)
		if(PLANE_TO_TRUE(overlay.plane) != EMISSIVE_PLANE)
			visible_overlays += overlay
	return visible_overlays

/obj/item/proc/can_use_storage_inventory_art()
	return icon_state == initial(icon_state) && !length(get_storage_inventory_overlays())

/obj/item/storage/backpack/grid_pilot
	name = "grid inventory pilot backpack"
	desc = "An experimental backpack with a 7 by 3 packing grid. Rotate held items with R on the panel; Ctrl-click stored items to rotate them."
	storage_type = /datum/storage/backpack/grid

/// Explicitly spawnable showcase. No loadouts, vendors or ordinary backpacks are converted.
/obj/item/storage/backpack/grid_pilot/sample/PopulateContents()
	new /obj/item/lighter/grid_sample(src)
	new /obj/item/reagent_containers/cup/glass/bottle/grid_sample(src)
	new /obj/item/crowbar/grid_sample(src)
	new /obj/item/storage/medkit/grid_sample(src)

/obj/item/lighter/grid_sample
	storage_footprint = list(1, 1)
	storage_inventory_icon = 'modular_aphelion/modules/grid_inventory/icons/lighter.png'

/obj/item/lighter/grid_sample/can_use_storage_inventory_art()
	// The stock engraving is replaced by the dedicated case art, not pasted on it.
	// A flame or additional overlays must still use the live item appearance.
	if(lit)
		return FALSE
	for(var/mutable_appearance/overlay as anything in get_storage_inventory_overlays())
		if(overlay.icon != icon || overlay.icon_state != "lighter_overlay_[overlay_state]")
			return FALSE
	return TRUE

/obj/item/reagent_containers/cup/glass/bottle/grid_sample
	storage_footprint = list(1, 2)
	storage_inventory_icon = 'modular_aphelion/modules/grid_inventory/icons/bottle.png'

/obj/item/crowbar/grid_sample
	storage_footprint = list(1, 3)
	storage_inventory_icon = 'modular_aphelion/modules/grid_inventory/icons/crowbar.png'

/obj/item/storage/medkit/grid_sample
	storage_footprint = list(2, 2)
	storage_inventory_icon = 'modular_aphelion/modules/grid_inventory/icons/firstaid.png'
