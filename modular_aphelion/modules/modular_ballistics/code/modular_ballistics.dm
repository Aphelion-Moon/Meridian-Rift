// Parallax frame definition, initialization, cleanup and ready-made configurations.

/obj/item/gun/ballistic/parallax
	name = "Parallax modular sidearm"
	desc = "A modular ballistic platform with sculpted ceramic housings over an accelerator spine. Fires physical 6mm smart rounds from a removable ammunition cassette."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/modular_ballistics.dmi'
	icon_state = "frame"
	inhand_icon_state = "frame"
	lefthand_file = 'modular_aphelion/modules/modular_ballistics/icons/lefthand.dmi'
	righthand_file = 'modular_aphelion/modules/modular_ballistics/icons/righthand.dmi'
	inhand_x_dimension = 64
	inhand_y_dimension = 64
	SET_BASE_PIXEL(-8, 0)
	slot_flags = NONE
	w_class = WEIGHT_CLASS_NORMAL
	accepted_magazine_type = /obj/item/ammo_box/magazine/parallax
	mag_display = FALSE
	show_bolt_icon = FALSE
	can_suppress = FALSE
	// Modular suppressors are drawn and removed by the attachment tree.
	can_unsuppress = FALSE
	suppressed_volume = 35
	bolt_type = BOLT_TYPE_STANDARD
	fire_sound = 'modular_nova/modules/modular_weapons/sounds/pulse_shoot.ogg'
	/// Installed objects keyed by socket, not a list of predetermined gun combinations.
	var/list/modules = list()
	/// Frame art is independent of the shared attachment states in these atlases.
	var/frame_icon_state = "frame"
	var/frame_world_icon = 'modular_aphelion/modules/modular_ballistics/icons/modular_ballistics.dmi'
	var/frame_loose_icon = 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi'
	var/frame_rifle_left_icon = 'modular_aphelion/modules/modular_ballistics/icons/lefthand.dmi'
	var/frame_rifle_right_icon = 'modular_aphelion/modules/modular_ballistics/icons/righthand.dmi'
	var/frame_compact_left_icon = 'modular_aphelion/modules/modular_ballistics/icons/compact_lefthand.dmi'
	var/frame_compact_right_icon = 'modular_aphelion/modules/modular_ballistics/icons/compact_righthand.dmi'
	var/frame_name_prefix = "Parallax"
	var/frame_recoil_multiplier = 1
	var/frame_requires_two_hands = FALSE
	/// The frame uses the same named-point schema as every detachable module.
	/// Socket -> accepted type and per-context offsets. Omitted offsets are zero.
	var/list/attachment_points = list(
		"barrel" = list("type" = /obj/item/ballistic_module/barrel),
		"controller" = list("type" = /obj/item/ballistic_module/control),
		"stock" = list("type" = /obj/item/ballistic_module/stock),
		"optic" = list("type" = /obj/item/ballistic_module/optic),
		"magazine" = list("type" = /obj/item/ammo_box/magazine/parallax),
	)
	var/attachment_inhand_profile = "compact"
	/// Cached because the direction-change signal runs before the wearer's dir updates.
	var/attachment_inhand_direction = SOUTH
	var/list/starting_modules = list(/obj/item/ballistic_module/barrel, /obj/item/ballistic_module/control)
	var/service_open = FALSE
	var/datum/component/scope/installed_scope
	var/aimed_accuracy = 0
	var/datum/component/automatic_fire/controller_autofire
	/// Wearer whose facing controls whether the assembled in-hand is behind the body.
	var/mob/inhand_wearer

/obj/item/gun/ballistic/parallax/Initialize(mapload)
	var/list/magazine_point = attachment_points?["magazine"]
	var/magazine_type = magazine_point?["type"]
	if(ispath(magazine_type, /obj/item/ammo_box/magazine))
		accepted_magazine_type = magazine_type
	else
		spawnwithmagazine = FALSE
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)
	for(var/module_type in starting_modules)
		var/obj/item/ballistic_module/part = new module_type(src)
		install_module(part)
	rebuild_configuration()

/obj/item/gun/ballistic/parallax/add_bayonet_point()
	return

/obj/item/gun/ballistic/parallax/insert_magazine(mob/user, obj/item/ammo_box/magazine/new_magazine, display_message = TRUE)
	var/list/point = attachment_points?["magazine"]
	var/accepted_type = point?["type"]
	if(!ispath(accepted_type, /obj/item/ammo_box/magazine) || !istype(new_magazine, accepted_type))
		return FALSE
	return ..()

/obj/item/gun/ballistic/parallax/add_seclight_point()
	return

/obj/item/gun/ballistic/parallax/Destroy()
	clear_inhand_wearer()
	QDEL_NULL(installed_scope)
	QDEL_NULL(controller_autofire)
	for(var/socket in modules)
		var/obj/item/ballistic_module/part = modules[socket]
		UnregisterSignal(part, COMSIG_QDELETING)
		qdel(part)
	modules.Cut()
	return ..()

/obj/item/gun/ballistic/parallax/empty
	name = "Parallax incomplete frame"
	starting_modules = list()
	spawnwithmagazine = FALSE

/obj/item/gun/ballistic/parallax/machine_pistol
	starting_modules = list(/obj/item/ballistic_module/barrel/compact_auto, /obj/item/ballistic_module/control/automatic)

/obj/item/gun/ballistic/parallax/carbine
	starting_modules = list(/obj/item/ballistic_module/barrel/carbine, /obj/item/ballistic_module/control/burst, /obj/item/ballistic_module/stock, /obj/item/ballistic_module/optic)

/obj/item/gun/ballistic/parallax/assault
	starting_modules = list(/obj/item/ballistic_module/barrel/carbine/assault, /obj/item/ballistic_module/control/automatic, /obj/item/ballistic_module/stock/precision, /obj/item/ballistic_module/optic)

/obj/item/gun/ballistic/parallax/shotgun
	starting_modules = list(/obj/item/ballistic_module/barrel/shotgun, /obj/item/ballistic_module/control, /obj/item/ballistic_module/stock)

/obj/item/gun/ballistic/parallax/marksman
	starting_modules = list(/obj/item/ballistic_module/barrel/marksman, /obj/item/ballistic_module/control, /obj/item/ballistic_module/stock/precision, /obj/item/ballistic_module/optic/scope)
