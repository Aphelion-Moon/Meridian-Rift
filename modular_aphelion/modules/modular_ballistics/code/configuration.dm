// Derive gun performance from its assembly, then enforce firing and aiming rules.

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
	var/long_profile = frame_requires_two_hands
	for(var/obj/item/ballistic_module/part as anything in all_modules())
		spread += part.dispersion
		recoil += part.kick
		fire_delay += part.cycle_cost
		aimed_accuracy += part.scoped_accuracy
		long_profile ||= part.is_long
	spread = max(0, spread)
	recoil = max(0.1, recoil * frame_recoil_multiplier)
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
	lefthand_file = long_profile ? frame_rifle_left_icon : frame_compact_left_icon
	righthand_file = long_profile ? frame_rifle_right_icon : frame_compact_right_icon
	weapon_weight = long_profile ? WEAPON_MEDIUM : WEAPON_LIGHT
	if(frame_requires_two_hands || istype(barrel, /obj/item/ballistic_module/barrel/marksman) || istype(barrel, /obj/item/ballistic_module/barrel/shotgun))
		weapon_weight = WEAPON_HEAVY
	if(!barrel || !controller)
		name = "[frame_name_prefix] incomplete frame"
	else if(istype(barrel, /obj/item/ballistic_module/barrel/marksman))
		name = "[frame_name_prefix] modular marksman weapon"
	else if(istype(barrel, /obj/item/ballistic_module/barrel/shotgun))
		name = "[frame_name_prefix] modular shotgun"
	else if(long_profile)
		name = "[frame_name_prefix] modular carbine"
	else
		name = controller.automatic ? "[frame_name_prefix] modular machine pistol" : "[frame_name_prefix] modular sidearm"
	fire_sound = barrel ? barrel.shot_sound : initial(fire_sound)
	fire_sound_volume = barrel ? barrel.shot_volume : initial(fire_sound_volume)
	if(controller?.automatic && barrel && !service_open)
		controller_autofire = AddComponent(/datum/component/automatic_fire, fire_delay)
	var/obj/item/ballistic_module/optic/optic = modules["optic"]
	if(optic?.scope_range && assembly_ready())
		installed_scope = AddComponent(/datum/component/scope, range_modifier = optic.scope_range)
	update_appearance()

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
