/// Parallax uses real, removable objects for every installed component.
/obj/item/ballistic_module
	name = "Parallax module"
	desc = "A keyed component for the Parallax modular ballistic platform. Install it into an unloaded frame with its service latch open."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi'
	w_class = WEIGHT_CLASS_SMALL
	/// One component per named socket; subtypes may extend the platform without combination sprites.
	var/socket
	/// Overlay state shared by the world and directional in-hand atlases.
	var/overlay_state
	/// Named child sockets. Each entry contains an accepted "type" and context offsets.
	var/list/attachment_points = list()
	/// Physical children, keyed by the attachment point they occupy.
	var/list/attachments = list()
	var/shot_delay = 0
	var/damage_factor = 1
	var/dispersion = 0
	var/kick = 0
	var/is_long = FALSE
	var/automatic = FALSE
	var/shots_per_burst = 1
	/// Added time between shots, separate from the accelerator cycle.
	var/cycle_cost = 0
	var/scope_range = 0
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

/obj/item/ballistic_module/barrel
	attachment_points = list(
		"silencer" = list(
			"type" = /obj/item/ballistic_module/silencer,
			"world" = list("default" = list(0, 0)),
			"loose" = list("default" = list(17, 0)),
			"rifle_left" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"rifle_right" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"compact_left" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"compact_right" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
		),
	)
	name = "Parallax compact accelerator"
	desc = "A short, shrouded ballistic accelerator. Compact and quick to handle, with reduced muzzle performance."
	socket = "barrel"
	icon_state = "barrel_short"
	overlay_state = "barrel_short"
	shot_delay = 0.3 SECONDS
	damage_factor = 0.85
	dispersion = 6
	kick = 0.5
	/// The accelerator determines the report independently of stocks and optics.
	var/shot_sound = 'modular_nova/modules/modular_weapons/sounds/pulse_shoot.ogg'
	var/shot_volume = 50

/obj/item/ballistic_module/barrel/carbine
	attachment_points = list(
		"silencer" = list(
			"type" = /obj/item/ballistic_module/silencer,
			"world" = list("default" = list(8, 0)),
			"loose" = list("default" = list(19, -1)),
			"rifle_left" = list("2" = list(-5, -1), "1" = list(5, 2), "4" = list(5, 0), "8" = list(-5, 0)),
			"rifle_right" = list("2" = list(5, -1), "1" = list(-4, 2), "4" = list(5, 0), "8" = list(-5, 0)),
			"compact_left" = list("2" = list(-2, -2), "1" = list(3, 1), "4" = list(-3, 0), "8" = list(3, 0)),
			"compact_right" = list("2" = list(3, -2), "1" = list(-2, 1), "4" = list(3, 0), "8" = list(-3, 0)),
		),
	)
	name = "Parallax carbine accelerator"
	desc = "A vented medium-length accelerator housing for general-purpose ballistic fire."
	icon_state = "barrel_carbine"
	overlay_state = "barrel_carbine"
	shot_delay = 0.2 SECONDS
	damage_factor = 0.8
	dispersion = 4
	kick = 0.8
	is_long = TRUE
	shot_volume = 60

/obj/item/ballistic_module/barrel/compact_auto
	attachment_points = list(
		"silencer" = list(
			"type" = /obj/item/ballistic_module/silencer,
			"world" = list("default" = list(3, 0)),
			"loose" = list("default" = list(18, 0)),
			"rifle_left" = list("2" = list(-2, -1), "1" = list(2, 1), "4" = list(2, 0), "8" = list(-2, 0)),
			"rifle_right" = list("2" = list(2, -1), "1" = list(-2, 1), "4" = list(2, 0), "8" = list(-2, 0)),
			"compact_left" = list("2" = list(0, -1), "1" = list(1, 1), "4" = list(-1, 0), "8" = list(1, 0)),
			"compact_right" = list("2" = list(1, -1), "1" = list(0, 1), "4" = list(1, 0), "8" = list(-1, 0)),
		),
	)
	name = "Parallax compact heat-sink accelerator"
	desc = "A short accelerator with a stepped lower heat sink. Tighter shot grouping than the compact accelerator, but a slower cycle."
	icon_state = "barrel_smg"
	overlay_state = "barrel_smg"
	dispersion = 5
	shot_delay = 0.35 SECONDS

/obj/item/ballistic_module/barrel/carbine/assault
	attachment_points = list()
	name = "Parallax assault accelerator"
	desc = "A deep twin-rib accelerator housing with recessed thermal channels. Its heavier assembly reduces recoil at the expense of a longer cycle."
	icon_state = "barrel_assault"
	overlay_state = "barrel_assault"
	shot_delay = 0.3 SECONDS
	damage_factor = 1
	kick = 1.6

/obj/item/ballistic_module/barrel/marksman
	attachment_points = list()
	name = "Parallax marksman accelerator"
	desc = "A long, split-shroud accelerator. Its greater muzzle performance requires a slower firing cycle."
	icon_state = "barrel_marksman"
	overlay_state = "barrel_marksman"
	shot_delay = 0.8 SECONDS
	damage_factor = 1.45
	dispersion = 2
	kick = 2
	is_long = TRUE
	shot_volume = 70

/obj/item/ballistic_module/barrel/shotgun
	attachment_points = list()
	name = "Parallax six-tube shotgun accelerator"
	desc = "A fixed cluster of six short accelerator tubes. Fires six cassette rounds together in a spread; requires six live rounds for each volley."
	icon_state = "barrel_shotgun"
	overlay_state = "barrel_shotgun"
	shot_delay = 1.2 SECONDS
	damage_factor = 10 / 22
	dispersion = 4
	kick = 1.6
	is_long = TRUE
	shot_volume = 70

/obj/item/ballistic_module/silencer
	name = "Parallax sound suppressor"
	desc = "A ceramic-sleeved baffle assembly for compact and carbine accelerators. Reduces the firing report while adding bulk. Install or remove it through the unloaded frame's service latch."
	socket = "silencer"
	icon_state = "silencer"
	overlay_state = "silencer"

/obj/item/ballistic_module/control
	name = "Parallax semi-automatic controller"
	desc = "A fire-control cartridge that authorizes one shot per trigger pull."
	socket = "controller"
	icon_state = "control_semi"
	overlay_state = "control_semi"

/obj/item/ballistic_module/control/burst
	name = "Parallax burst controller"
	desc = "A fire-control cartridge that authorizes three rounds per trigger pull."
	icon_state = "control_burst"
	overlay_state = "control_burst"
	shots_per_burst = 3

/obj/item/ballistic_module/control/automatic
	name = "Parallax automatic controller"
	desc = "A fire-control cartridge that sustains fire while the trigger is held. The accelerator still determines cycle speed."
	icon_state = "control_auto"
	overlay_state = "control_auto"
	automatic = TRUE
	dispersion = 2

/obj/item/ballistic_module/stock
	name = "Parallax compact stock"
	desc = "A curved shoulder support that reduces dispersion and recoil, at the cost of a bulkier profile."
	socket = "stock"
	icon_state = "stock_compact"
	overlay_state = "stock_compact"
	dispersion = -2
	kick = -0.3
	is_long = TRUE

/obj/item/ballistic_module/stock/precision
	name = "Parallax precision stock"
	desc = "An extended triangular shoulder support with a recessed stabilizer. Greater stability than the compact stock, but adds 0.1 seconds between shots."
	icon_state = "stock_precision"
	overlay_state = "stock_precision"
	dispersion = -3
	kick = -0.5
	cycle_cost = 0.1 SECONDS

/obj/item/ballistic_module/optic
	name = "Parallax reflex optic"
	desc = "A recessed holographic aiming window that reduces shot dispersion."
	socket = "optic"
	icon_state = "optic_reflex"
	overlay_state = "optic_reflex"
	dispersion = -1

/obj/item/ballistic_module/optic/scope
	name = "Parallax precision optic"
	desc = "An elongated ballistic sight with a cyan objective. Right-click to scope in. Excellent aimed accuracy, but awkward hip fire and a slower firing cycle."
	icon_state = "optic_scope"
	overlay_state = "optic_scope"
	dispersion = 1
	cycle_cost = 0.1 SECONDS
	scope_range = 2
	scoped_accuracy = 4

/obj/projectile/bullet/parallax
	name = "6mm frangible smart round"
	icon = 'modular_aphelion/modules/modular_ballistics/icons/ammunition.dmi'
	icon_state = "smart_round"
	muzzle_flash_color_override = LIGHT_COLOR_BLUE
	damage = 22
	wound_bonus = -10
	weak_against_armour = TRUE
	demolition_mod = 0.1

/obj/item/ammo_casing/parallax
	name = "6mm frangible smart cartridge"
	desc = "A Parallax cartridge with a segmented frangible tip, a cyan identification collar and a copper-toned casing. Its spacecraft-interior designation is marked by a red notch."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/ammunition.dmi'
	icon_state = "smart_casing"
	caliber = "parallax_6mm"
	projectile_type = /obj/projectile/bullet/parallax
	muzzle_flash_color = LIGHT_COLOR_BLUE
	firing_effect_type = /obj/effect/temp_visual/dir_setting/firing_effect/blue

/// Split the volley only after reserving five additional physical cartridges.
/// The chamber supplies the sixth; ordinary gun cycling ejects that casing.
/obj/item/ammo_casing/parallax/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	if(!istype(fired_from, /obj/item/gun/ballistic/parallax))
		return ..()
	var/obj/item/gun/ballistic/parallax/gun = fired_from
	if(!gun.has_shotgun_barrel())
		return ..()
	if(!user || !get_turf(target) || !get_turf(gun) || !loaded_projectile || !gun.has_volley_ammo())
		return FALSE
	var/obj/item/ammo_box/magazine/source_magazine = gun.magazine
	var/list/reserved = list()
	for(var/i in 1 to 5)
		var/obj/item/ammo_casing/extra = source_magazine.get_round()
		if(!extra?.loaded_projectile)
			for(var/obj/item/ammo_casing/refund as anything in reserved)
				source_magazine.give_round(refund)
			source_magazine.update_appearance()
			return FALSE
		extra.forceMove(src)
		reserved += extra
	pellets = 6
	variance = 20
	randomspread = TRUE
	. = ..()
	pellets = initial(pellets)
	variance = initial(variance)
	randomspread = initial(randomspread)
	for(var/obj/item/ammo_casing/extra as anything in reserved)
		if(.)
			QDEL_NULL(extra.loaded_projectile)
			extra.shot_timestamp = world.time
			extra.forceMove(get_turf(gun))
			extra.update_appearance()
			extra.bounce_away(TRUE)
		else
			source_magazine.give_round(extra)
	if(. && !quiet && firing_effect_type)
		new firing_effect_type(user, get_dir(user, target))
	source_magazine.update_appearance()

/obj/item/ammo_box/magazine/parallax
	name = "Parallax ammunition cassette (6mm)"
	desc = "A detachable cassette of 24 smart cartridges, shared by all Parallax configurations."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi'
	icon_state = "magazine"
	ammo_type = /obj/item/ammo_casing/parallax
	caliber = "parallax_6mm"
	max_ammo = 24

/obj/item/ammo_box/magazine/parallax/update_icon_state()
	. = ..()
	icon_state = ammo_indicator_state()
	if(istype(loc, /obj/item/gun/ballistic/parallax))
		var/obj/item/gun/ballistic/parallax/gun = loc
		if(gun.magazine == src)
			gun.update_appearance()

/obj/item/ammo_box/magazine/parallax/proc/ammo_indicator_state()
	var/remaining = ammo_count(countempties = FALSE)
	if(!remaining)
		return "magazine_empty"
	return remaining < max_ammo ? "magazine_partial" : "magazine"

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

/// Assembly changes always derive from the current parts, avoiding stacked bonuses.
/obj/item/gun/ballistic/parallax/proc/rebuild_configuration()
	QDEL_NULL(controller_autofire)
	QDEL_NULL(installed_scope)
	aimed_accuracy = 0
	var/obj/item/ballistic_module/barrel/barrel = modules["barrel"]
	var/obj/item/ballistic_module/control/controller = modules["controller"]
	fire_delay = barrel ? barrel.shot_delay : 0.5 SECONDS
	projectile_damage_multiplier = barrel ? barrel.damage_factor : 1
	spread = 0
	recoil = 0
	var/long_profile = FALSE
	for(var/obj/item/ballistic_module/part as anything in all_modules())
		spread += part.dispersion
		recoil += part.kick
		fire_delay += part.cycle_cost
		aimed_accuracy += part.scoped_accuracy
		long_profile ||= part.is_long
	spread = max(0, spread)
	recoil = max(0.1, recoil)
	burst_size = controller ? controller.shots_per_burst : 1
	burst_delay = fire_delay
	if(burst_size > 1)
		fire_delay *= burst_size
	var/obj/item/ballistic_module/silencer/sound_suppressor = barrel?.attachments["silencer"]
	suppressed = istype(sound_suppressor) ? SUPPRESSED_QUIET : SUPPRESSED_NONE
	update_weight_class((long_profile || suppressed) ? WEIGHT_CLASS_BULKY : WEIGHT_CLASS_NORMAL)
	attachment_inhand_profile = long_profile ? "rifle" : "compact"
	// Compact sidearms use the small angled pose of other pistols. A long barrel
	// or stock switches every component together to the horizontal rifle pose.
	lefthand_file = long_profile ? 'modular_aphelion/modules/modular_ballistics/icons/lefthand.dmi' : 'modular_aphelion/modules/modular_ballistics/icons/compact_lefthand.dmi'
	righthand_file = long_profile ? 'modular_aphelion/modules/modular_ballistics/icons/righthand.dmi' : 'modular_aphelion/modules/modular_ballistics/icons/compact_righthand.dmi'
	weapon_weight = long_profile ? WEAPON_MEDIUM : WEAPON_LIGHT
	if(istype(barrel, /obj/item/ballistic_module/barrel/marksman) || istype(barrel, /obj/item/ballistic_module/barrel/shotgun))
		weapon_weight = WEAPON_HEAVY
	if(!barrel || !controller)
		name = "Parallax incomplete frame"
	else if(istype(barrel, /obj/item/ballistic_module/barrel/marksman))
		name = "Parallax modular marksman weapon"
	else if(istype(barrel, /obj/item/ballistic_module/barrel/shotgun))
		name = "Parallax modular shotgun"
	else if(long_profile)
		name = "Parallax modular carbine"
	else
		name = controller.automatic ? "Parallax modular machine pistol" : "Parallax modular sidearm"
	fire_sound = barrel ? barrel.shot_sound : initial(fire_sound)
	fire_sound_volume = barrel ? barrel.shot_volume : initial(fire_sound_volume)
	if(controller?.automatic && barrel && !service_open)
		controller_autofire = AddComponent(/datum/component/automatic_fire, fire_delay)
	var/obj/item/ballistic_module/optic/optic = modules["optic"]
	if(optic?.scope_range && assembly_ready())
		installed_scope = AddComponent(/datum/component/scope, range_modifier = optic.scope_range)
	update_appearance()

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
	. = ..()
	if(istype(gone, /obj/item/ballistic_module))
		forget_module(gone)

/obj/item/gun/ballistic/parallax/proc/assembly_ready()
	return !service_open && modules["barrel"] && modules["controller"]

/obj/item/gun/ballistic/parallax/proc/has_shotgun_barrel()
	return istype(modules["barrel"], /obj/item/ballistic_module/barrel/shotgun)

/obj/item/gun/ballistic/parallax/proc/has_volley_ammo()
	return chambered?.loaded_projectile && magazine && magazine.ammo_count(countempties = FALSE) >= 5

/obj/item/gun/ballistic/parallax/can_shoot()
	return assembly_ready() && (!has_shotgun_barrel() || has_volley_ammo()) && ..()

/obj/item/gun/ballistic/parallax/can_trigger_gun(mob/living/user, akimbo_usage)
	if(!assembly_ready())
		balloon_alert(user, "frame not ready!")
		return FALSE
	if(has_shotgun_barrel() && !has_volley_ammo())
		balloon_alert(user, "need six live rounds!")
		return FALSE
	return ..()

/obj/item/gun/ballistic/parallax/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(!assembly_ready())
		return NONE
	var/hip_spread = spread
	spread = configuration_spread(user)
	. = ..()
	spread = hip_spread

/// Accuracy benefits belong to this gun's active scope, never another item's zoom.
/obj/item/gun/ballistic/parallax/proc/configuration_spread(mob/living/user)
	return max(0, spread - ((user && installed_scope?.tracker?.owner == user) ? aimed_accuracy : 0))

/// Also guard queued burst callbacks if a component is externally removed or deleted.
/obj/item/gun/ballistic/parallax/process_burst(mob/living/user, atom/target, message = TRUE, params = null, zone_override = "", random_spread = 0, burst_spread_mult = 0, iteration = 0)
	if(!assembly_ready())
		firing_burst = FALSE
		return FALSE
	return ..()

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

/obj/item/gun/ballistic/parallax/update_icon_state()
	. = ..()
	// A completely stripped receiver is a loose component, so show its larger
	// inspection sprite. Once assembly begins, use the shared overlay anchors.
	var/bare_frame = !length(modules) && !magazine
	icon = bare_frame ? 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi' : 'modular_aphelion/modules/modular_ballistics/icons/modular_ballistics.dmi'
	base_pixel_x = bare_frame ? 0 : -8
	pixel_x = base_pixel_x

/// Include nested modules for modifiers, service menus and membership checks.
/obj/item/gun/ballistic/parallax/proc/all_modules()
	var/list/result = list()
	for(var/socket in modules)
		var/obj/item/ballistic_module/part = modules[socket]
		result += part.all_modules()
	return result

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
		var/obj/item/ammo_box/magazine/parallax/cassette = magazine
		. += attachment_appearance(icon, cassette.ammo_indicator_state(), "magazine")

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
		var/obj/item/ammo_box/magazine/parallax/cassette = magazine
		. += attachment_appearance(icon_file, cassette.ammo_indicator_state(), "magazine", context, attachment_inhand_direction)

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

/obj/item/storage/box/parallax_modules
	name = "Parallax conversion kit"
	desc = "A complete set of interchangeable Parallax modules."

/obj/item/storage/box/parallax_modules/PopulateContents()
	new /obj/item/ballistic_module/barrel(src)
	new /obj/item/ballistic_module/barrel/compact_auto(src)
	new /obj/item/ballistic_module/barrel/carbine(src)
	new /obj/item/ballistic_module/barrel/carbine/assault(src)
	new /obj/item/ballistic_module/barrel/marksman(src)
	new /obj/item/ballistic_module/barrel/shotgun(src)
	new /obj/item/ballistic_module/control(src)
	new /obj/item/ballistic_module/control/burst(src)
	new /obj/item/ballistic_module/control/automatic(src)
	new /obj/item/ballistic_module/stock(src)
	new /obj/item/ballistic_module/stock/precision(src)
	new /obj/item/ballistic_module/optic(src)
	new /obj/item/ballistic_module/optic/scope(src)
	new /obj/item/ballistic_module/silencer(src)

/obj/item/storage/box/parallax_modules/Initialize(mapload)
	. = ..()
	atom_storage.max_slots = 14
	atom_storage.max_total_storage = 28

/datum/supply_pack/security/armory/parallax
	name = "Parallax Modular Ballistics Kit"
	desc = "Two Parallax sidearms, two complete conversion kits, four spare ammunition cassettes and a screwdriver."
	cost = CARGO_CRATE_VALUE * 24
	contains = list(/obj/item/gun/ballistic/parallax, /obj/item/gun/ballistic/parallax, /obj/item/storage/box/parallax_modules, /obj/item/storage/box/parallax_modules, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/screwdriver)
	crate_name = "Parallax modular ballistics crate"

/datum/supply_pack/security/armory/parallax_ammo
	name = "Parallax Ammunition Cassettes"
	desc = "Four 24-round 6mm flechette cassettes for the Parallax platform."
	cost = CARGO_CRATE_VALUE * 4
	contains = list(/obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax)
	crate_name = "Parallax ammunition crate"

/obj/item/ballistic_module/examine(mob/user)
	. = ..()
	. += span_notice("Socket: [socket]. Dispersion modifier: [dispersion]. Recoil modifier: [kick]. Added cycle time: [cycle_cost / 10] seconds.")
	if(socket == "barrel")
		. += span_notice("Base shot cycle: [shot_delay / 10] seconds. Damage multiplier: [damage_factor]x.")
	if(socket == "controller")
		. += span_notice("Fire mode: [automatic ? "automatic" : (shots_per_burst > 1 ? "[shots_per_burst]-round burst" : "semi-automatic")].")
	if(scope_range)
		. += span_notice("Enables right-click aiming. While scoped with this weapon, reduces dispersion by [scoped_accuracy]; hip-fire modifier remains included.")
	if(is_long)
		. += span_notice("Makes the assembled weapon bulky.")
