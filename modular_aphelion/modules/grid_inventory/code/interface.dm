/// Cached appearance, separate from the full-cell interaction targets beneath it.
/atom/movable/screen/grid_inventory_art
	plane = ABOVE_HUD_PLANE
	layer = 2
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	hud_group_key = HUD_GROUP_STORAGE
	var/obj/item/item
	var/datum/storage_interface/grid/interface
	var/dirty = TRUE
	var/last_width
	var/last_height
	var/last_rotated
	var/last_cell_size = 24

/atom/movable/screen/grid_inventory_art/proc/bind(obj/item/source)
	if(item)
		UnregisterSignal(item, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_COLOR_UPDATED, COMSIG_QDELETING))
	item = source
	dirty = TRUE
	if(item)
		RegisterSignals(item, list(COMSIG_ATOM_UPDATED_ICON, COMSIG_ATOM_COLOR_UPDATED), PROC_REF(appearance_changed))
		RegisterSignal(item, COMSIG_QDELETING, PROC_REF(item_deleted))

/atom/movable/screen/grid_inventory_art/Destroy()
	bind(null)
	interface = null
	return ..()

/atom/movable/screen/grid_inventory_art/proc/item_deleted()
	SIGNAL_HANDLER
	bind(null)
	alpha = 0

/atom/movable/screen/grid_inventory_art/proc/appearance_changed()
	SIGNAL_HANDLER
	dirty = TRUE
	if(interface)
		render(interface.get_placement(item), last_cell_size)
		// Container appearance updates also announce locks and changed insertion rules.
		if(item.atom_storage && interface.viewer.grid_inventory)
			addtimer(CALLBACK(interface.viewer.grid_inventory, TYPE_PROC_REF(/datum/grid_inventory_session, refresh_hover)), 0, TIMER_UNIQUE)
		return
	var/datum/storage/backpack/grid/storage = item.loc?.atom_storage
	if(istype(storage))
		render(storage.placements[item], last_cell_size)

/atom/movable/screen/grid_inventory_art/proc/render(datum/grid_placement/placement, cell_size = 24)
	var/width = placement ? placement.width : 1
	var/height = placement ? placement.height : 1
	var/rotated = placement?.rotated
	if(!dirty && width == last_width && height == last_height && rotated == last_rotated && cell_size == last_cell_size)
		return
	dirty = FALSE
	last_width = width
	last_height = height
	last_rotated = rotated
	last_cell_size = cell_size
	var/mutable_appearance/art = item.get_storage_inventory_appearance()
	// Generated resources have empty text names; they cannot share a string-keyed size cache.
	var/list/dimensions = get_icon_dimensions(art.icon)
	var/list/size = list(max(1, dimensions["width"]), max(1, dimensions["height"]))
	var/art_width = size[rotated % 2 ? 2 : 1]
	var/art_height = size[rotated % 2 ? 1 : 2]
	var/scale = min((width * cell_size - 4) / art_width, (height * cell_size - 4) / art_height)
	var/matrix/fitted = matrix()
	fitted.Scale(scale)
	if(rotated)
		fitted.Turn(90 * rotated)
	art.transform = fitted
	art.pixel_x = (width * cell_size - size[1]) / 2
	art.pixel_y = (height * cell_size - size[2]) / 2
	art.pixel_w = 0
	art.pixel_z = 0
	art.plane = FLOAT_PLANE
	art.layer = FLOAT_LAYER
	art.appearance_flags = APPEARANCE_UI | PIXEL_SCALE
	art.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	icon = null
	cut_overlays()
	add_overlay(art)
