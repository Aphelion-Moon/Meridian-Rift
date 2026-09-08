// World and held overlays, cumulative attachment offsets, pose selection and facing layers.

/// Loose subassemblies use their own context; gun overlays use the held/world atlases.
/obj/item/ballistic_module/update_overlays()
	. = ..()
	for(var/point in attachments)
		var/obj/item/ballistic_module/child = attachments[point]
		. += child.attachment_overlays(icon, attachment_points, "loose", SOUTH)

/obj/item/ballistic_module/proc/attachment_overlays(icon_file, list/parent_points, context, facing, parent_x = 0, parent_y = 0)
	var/list/offset = parallax_point_offset(parent_points, socket, context, facing)
	var/x = parent_x + offset[1]
	var/y = parent_y + offset[2]
	var/list/result = list()
	if(overlay_state)
		var/mutable_appearance/appearance = mutable_appearance(icon_file, overlay_state)
		appearance.pixel_x = x
		appearance.pixel_y = y
		result += appearance
	for(var/point in attachments)
		var/obj/item/ballistic_module/child = attachments[point]
		result += child.attachment_overlays(icon_file, attachment_points, context, facing, x, y)
	return result

/obj/item/gun/ballistic/parallax/equipped(mob/user, slot, initial = FALSE)
	clear_inhand_wearer()
	if(slot & ITEM_SLOT_HANDS)
		inhand_wearer = user
		attachment_inhand_direction = user.dir
		RegisterSignal(user, COMSIG_ATOM_DIR_CHANGE, PROC_REF(wearer_turned))
		alternate_worn_layer = user.dir == NORTH ? BODY_BEHIND_LAYER : initial(alternate_worn_layer)
	return ..()

/obj/item/gun/ballistic/parallax/dropped(mob/user, silent = FALSE)
	clear_inhand_wearer()
	return ..()

/obj/item/gun/ballistic/parallax/proc/clear_inhand_wearer()
	if(inhand_wearer)
		UnregisterSignal(inhand_wearer, COMSIG_ATOM_DIR_CHANGE)
		inhand_wearer = null
	alternate_worn_layer = initial(alternate_worn_layer)

/obj/item/gun/ballistic/parallax/proc/wearer_turned(mob/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(!source.is_holding(src))
		clear_inhand_wearer()
		return
	// The direction signal fires before dir changes, so use its new_dir argument.
	// Socket offsets may vary between any two directions, even on the same layer.
	attachment_inhand_direction = new_dir
	var/new_layer = new_dir == NORTH ? BODY_BEHIND_LAYER : initial(alternate_worn_layer)
	alternate_worn_layer = new_layer
	source.update_held_items()

/obj/item/gun/ballistic/parallax/update_icon_state()
	. = ..()
	// A completely stripped receiver is a loose component, so show its larger
	// inspection sprite. Once assembly begins, use the shared overlay anchors.
	var/bare_frame = !length(modules) && !magazine
	icon = bare_frame ? frame_loose_icon : frame_world_icon
	icon_state = frame_icon_state
	inhand_icon_state = frame_icon_state
	base_pixel_x = bare_frame ? 0 : -8
	pixel_x = base_pixel_x

/// Magazine ownership/loading stays with the ballistic gun; its mount uses the same schema.
/obj/item/gun/ballistic/parallax/proc/attachment_appearance(icon_file, state, socket, context = "world", facing = SOUTH)
	var/mutable_appearance/part_appearance = mutable_appearance(icon_file, state)
	var/list/offset = parallax_point_offset(attachment_points, socket, context, facing)
	part_appearance.pixel_x = offset[1]
	part_appearance.pixel_y = offset[2]
	return part_appearance

/obj/item/gun/ballistic/parallax/update_overlays()
	. = ..()
	for(var/socket in modules)
		var/obj/item/ballistic_module/part = modules[socket]
		. += part.attachment_overlays(icon, attachment_points, "world", SOUTH)
	if(magazine)
		var/obj/item/ammo_box/magazine/parallax/sink = magazine
		. += attachment_appearance(icon, sink.heatsink_state(), "magazine")

/obj/item/gun/ballistic/parallax/worn_overlays(mutable_appearance/standing, isinhands, icon_file)
	. = ..()
	if(!isinhands)
		return
	var/hand = icon_file == lefthand_file ? "left" : "right"
	var/context = "[attachment_inhand_profile]_[hand]"
	for(var/socket in modules)
		var/obj/item/ballistic_module/part = modules[socket]
		. += part.attachment_overlays(icon_file, attachment_points, context, attachment_inhand_direction)
	if(magazine)
		var/obj/item/ammo_box/magazine/parallax/sink = magazine
		. += attachment_appearance(icon_file, sink.heatsink_state(), "magazine", context, attachment_inhand_direction)
