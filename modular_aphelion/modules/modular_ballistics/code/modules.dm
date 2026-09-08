// Physical module ownership, named-point compatibility, nested installation and removal.

/// Parallax uses real, removable objects for every installed component.
/obj/item/ballistic_module
	name = "Parallax module"
	desc = "A keyed component for the Parallax modular ballistic platform. Install it into an unloaded frame with its service latch open."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi'
	w_class = WEIGHT_CLASS_SMALL
	/// One component per named socket; subtypes may extend the platform without combination sprites.
	var/socket
	/// Named child sockets. Each entry contains an accepted "type" and context offsets.
	var/list/attachment_points = list()
	/// Physical children, keyed by the attachment point they occupy.
	var/list/attachments = list()
	var/dispersion = 0
	var/kick = 0
	var/is_long = FALSE
	/// Added time between shots, separate from the accelerator cycle.
	var/cycle_cost = 0
	var/scoped_accuracy = 0

/// Configuration lists are read-only. Missing coordinates use the authored sprite position.
/proc/parallax_point_offset(list/points, socket, context, facing)
	var/list/point = points?[socket]
	var/list/context_offsets = point?[context]
	var/list/offset = context_offsets?["[facing]"]
	if(isnull(offset))
		offset = context_offsets?["default"]
	return length(offset) >= 2 ? offset : list(0, 0)

/proc/parallax_point_accepts(list/points, obj/item/ballistic_module/part)
	if(QDELETED(part) || !part.socket)
		return FALSE
	var/list/point = points?[part.socket]
	var/accepted_type = point?["type"]
	return ispath(accepted_type, /obj/item/ballistic_module) && istype(part, accepted_type)

/obj/item/ballistic_module/proc/installed_gun()
	var/atom/parent = loc
	while(istype(parent, /obj/item/ballistic_module))
		parent = parent.loc
	return istype(parent, /obj/item/gun/ballistic/parallax) ? parent : null

/obj/item/ballistic_module/proc/all_modules()
	var/list/result = list(src)
	for(var/point in attachments)
		var/obj/item/ballistic_module/child = attachments[point]
		result += child.all_modules()
	return result

/obj/item/ballistic_module/proc/can_attach(obj/item/ballistic_module/part)
	if(!parallax_point_accepts(attachment_points, part) || attachments[part.socket])
		return FALSE
	// An ancestor cannot become its own descendant.
	var/atom/ancestor = src
	while(istype(ancestor, /obj/item/ballistic_module))
		if(ancestor == part)
			return FALSE
		ancestor = ancestor.loc
	return TRUE

/obj/item/ballistic_module/proc/install_attachment(obj/item/ballistic_module/part)
	if(!can_attach(part))
		return FALSE
	part.forceMove(src)
	attachments[part.socket] = part
	RegisterSignal(part, COMSIG_QDELETING, PROC_REF(attachment_deleted))
	attachments_changed()
	return TRUE

/obj/item/ballistic_module/proc/attachments_changed()
	update_appearance()
	var/obj/item/gun/ballistic/parallax/gun = installed_gun()
	if(gun && !QDELETED(gun))
		gun.rebuild_configuration()
	else if(istype(loc, /obj/item/ballistic_module))
		var/obj/item/ballistic_module/parent = loc
		parent.attachments_changed()

/obj/item/ballistic_module/proc/attachment_deleted(obj/item/ballistic_module/part)
	SIGNAL_HANDLER
	forget_attachment(part)

/obj/item/ballistic_module/proc/forget_attachment(obj/item/ballistic_module/part)
	if(attachments[part.socket] != part)
		return
	UnregisterSignal(part, COMSIG_QDELETING)
	attachments -= part.socket
	if(!QDELETED(src))
		attachments_changed()

/obj/item/ballistic_module/Exited(atom/movable/gone, direction)
	. = ..()
	if(istype(gone, /obj/item/ballistic_module))
		forget_attachment(gone)

/obj/item/ballistic_module/Destroy()
	for(var/point in attachments.Copy())
		var/obj/item/ballistic_module/child = attachments[point]
		UnregisterSignal(child, COMSIG_QDELETING)
		qdel(child)
	attachments.Cut()
	return ..()

/obj/item/gun/ballistic/parallax/proc/install_module(obj/item/ballistic_module/part)
	if(!parallax_point_accepts(attachment_points, part) || modules[part.socket])
		return FALSE
	part.forceMove(src)
	modules[part.socket] = part
	RegisterSignal(part, COMSIG_QDELETING, PROC_REF(module_deleted))
	rebuild_configuration()
	return TRUE

/obj/item/gun/ballistic/parallax/proc/module_deleted(obj/item/ballistic_module/part)
	SIGNAL_HANDLER
	forget_module(part)

/obj/item/gun/ballistic/parallax/proc/forget_module(obj/item/ballistic_module/part)
	if(modules[part.socket] != part)
		return
	UnregisterSignal(part, COMSIG_QDELETING)
	modules -= part.socket
	if(!QDELETED(src))
		rebuild_configuration()

/obj/item/gun/ballistic/parallax/Exited(atom/movable/gone, direction)
	// The parent clears magazine, so discard its firing adapter first.
	if(gone == magazine)
		QDEL_NULL(chambered)
	. = ..()
	if(istype(gone, /obj/item/ballistic_module))
		forget_module(gone)

/// Include nested modules for modifiers, service menus and membership checks.
/obj/item/gun/ballistic/parallax/proc/all_modules()
	var/list/result = list()
	for(var/socket in modules)
		var/obj/item/ballistic_module/part = modules[socket]
		result += part.all_modules()
	return result

/obj/item/ballistic_module/examine(mob/user)
	. = ..()
	. += span_notice("Socket: [socket]. Dispersion modifier: [dispersion]. Recoil modifier: [kick]. Added cycle time: [cycle_cost / 10] seconds.")
	if(is_long)
		. += span_notice("Makes the assembled weapon bulky.")
