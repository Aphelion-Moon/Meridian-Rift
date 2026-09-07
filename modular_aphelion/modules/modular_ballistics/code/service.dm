// Player service-latch interactions, attachment selection and assembled-gun examination.

/obj/item/gun/ballistic/parallax/proc/can_service(mob/living/user)
	return user.is_holding(src) && can_interact(user) && !magazine && !chambered && !firing_burst && !fire_cd

/obj/item/gun/ballistic/parallax/screwdriver_act(mob/living/user, obj/item/tool)
	if(!can_service(user))
		balloon_alert(user, "hold and fully unload first!")
		return ITEM_INTERACT_BLOCKING
	service_open = !service_open
	tool.play_tool_sound(src)
	balloon_alert(user, service_open ? "service latch open" : "service latch closed")
	rebuild_configuration()
	return ITEM_INTERACT_SUCCESS

/obj/item/gun/ballistic/parallax/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/ballistic_module))
		if(!service_open || !can_service(user))
			balloon_alert(user, "open unloaded frame first!")
			return ITEM_INTERACT_BLOCKING
		var/obj/item/ballistic_module/part = tool
		var/list/parents = list()
		if(parallax_point_accepts(attachment_points, part) && !modules[part.socket])
			parents["Frame: [part.socket]"] = src
		for(var/obj/item/ballistic_module/parent as anything in all_modules())
			if(parent.can_attach(part))
				parents["[length(parents) + 1]. [parent.name]: [part.socket]"] = parent
		if(!length(parents))
			balloon_alert(user, "no compatible free socket!")
			return ITEM_INTERACT_BLOCKING
		var/choice = length(parents) == 1 ? parents[1] : tgui_input_list(user, "Choose an attachment point.", name, parents)
		var/obj/item/target = parents[choice]
		if(!target || QDELETED(part) || !service_open || !can_service(user) || !user.is_holding(part))
			return ITEM_INTERACT_BLOCKING
		if(target == src)
			if(!parallax_point_accepts(attachment_points, part) || modules[part.socket])
				return ITEM_INTERACT_BLOCKING
			if(user.transferItemToLoc(part, src))
				install_module(part)
				balloon_alert(user, "module installed")
		else
			var/obj/item/ballistic_module/parent = target
			if(QDELETED(parent) || !(parent in all_modules()) || !parent.can_attach(part))
				return ITEM_INTERACT_BLOCKING
			if(user.transferItemToLoc(part, parent))
				parent.install_attachment(part)
				balloon_alert(user, "module installed")
		return ITEM_INTERACT_SUCCESS
	if(service_open && istype(tool, /obj/item/ammo_box))
		balloon_alert(user, "close service latch first!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/gun/ballistic/parallax/click_alt(mob/living/user)
	if(!service_open || !can_service(user))
		balloon_alert(user, "open unloaded frame first!")
		return CLICK_ACTION_BLOCKING
	var/list/choices = list()
	for(var/obj/item/ballistic_module/part as anything in all_modules())
		choices["[length(choices) + 1]. [part.loc.name] / [part.socket]: [part.name]"] = part
	var/choice = tgui_input_list(user, "Choose a component to remove.", name, choices)
	var/obj/item/ballistic_module/selected = choices[choice]
	if(QDELETED(selected) || !service_open || !can_service(user) || !(selected in all_modules()))
		return CLICK_ACTION_BLOCKING
	selected.forceMove(drop_location())
	user.put_in_hands(selected)
	return CLICK_ACTION_SUCCESS

/obj/item/gun/ballistic/parallax/examine(mob/user)
	. = ..()
	. += span_notice("Remove the cassette and rack out the chambered round before servicing. While holding it, use a screwdriver to open or close the service latch; Alt-click to remove a part, or apply a part to install it.")
	if(has_shotgun_barrel())
		. += span_notice("Six projectiles per volley; consumes six live rounds including the chamber. Fixed 20-degree pellet spread. Fewer than six rounds cannot fire.")
	. += span_notice("Service latch: [service_open ? "open (firing disabled)" : "closed"].")
	if(suppressed)
		. += span_notice("A barrel-mounted sound suppressor reduces the firing report. Remove it through the service latch.")
	var/obj/item/ballistic_module/control/controller = modules["controller"]
	var/fire_mode = !controller ? "unavailable" : (controller.automatic ? "automatic" : (burst_size > 1 ? "[burst_size]-round burst" : "semi-automatic"))
	. += span_notice("Fire mode: [fire_mode]. Cycle: [burst_delay / 10] seconds per shot; [fire_delay / 10] seconds per trigger cycle.")
	. += span_notice("Damage multiplier: [round(projectile_damage_multiplier, 0.01)]x. Dispersion: [spread] hip-fired / [max(0, spread - aimed_accuracy)] scoped (lower is better). Recoil: [round(recoil, 0.01)].")
	. += span_notice("Handling: [weapon_weight == WEAPON_HEAVY ? "requires two hands" : (weapon_weight == WEAPON_MEDIUM ? "medium weapon" : "light weapon")].")
	if(!modules["barrel"] || !controller)
		. += span_warning("Cannot fire: install [!modules["barrel"] ? "an accelerator" : ""][!modules["barrel"] && !controller ? " and " : ""][!controller ? "a controller" : ""].")
	for(var/socket in list("barrel", "controller", "stock", "optic"))
		var/obj/item/ballistic_module/part = modules[socket]
		. += span_notice("[capitalize(socket)]: [part ? part.name : "empty"].")
