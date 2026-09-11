// Magnetic metal shavings and removable, reusable heatsinks.

/obj/projectile/bullet/parallax
	name = "accelerated metal shaving"
	icon = 'modular_aphelion/modules/modular_ballistics/icons/ammunition.dmi'
	icon_state = "smart_round"
	muzzle_flash_color_override = LIGHT_COLOR_BLUE
	damage = 20
	wound_bonus = -10
	weak_against_armour = TRUE
	demolition_mod = 0.1

/// Internal firing adapter: never stocked in a heatsink or ejected.
/obj/item/ammo_casing/parallax
	name = "metal shaving"
	desc = "A rice-sized sliver sliced from a Parallax's internal metal feedstock."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/ammunition.dmi'
	icon_state = "smart_casing"
	caliber = "parallax_metal"
	projectile_type = /obj/projectile/bullet/parallax
	muzzle_flash_color = LIGHT_COLOR_BLUE
	firing_effect_type = /obj/effect/temp_visual/dir_setting/firing_effect/blue
	custom_materials = null

/obj/item/ammo_casing/parallax/fire_casing(atom/target, mob/living/user, params, distro, quiet, zone_override, spread, atom/fired_from)
	if(!istype(fired_from, /obj/item/gun/ballistic/parallax))
		return FALSE
	var/obj/item/gun/ballistic/parallax/gun = fired_from
	if(!user || !get_turf(target) || !get_turf(gun) || !gun.can_shoot())
		return FALSE
	var/obj/item/ballistic_module/barrel/barrel = gun.modules["barrel"]
	pellets = barrel.projectiles_per_shot
	variance = barrel.pellet_spread
	randomspread = TRUE
	. = ..()
	if(.)
		gun.add_shot_heat(user)
		if(pellets > 1 && !quiet && firing_effect_type)
			new firing_effect_type(user, get_dir(user, target))

/// Legacy path/socket preserved for maps, cargo and artwork.
/obj/item/ammo_box/magazine/parallax
	name = "Parallax heatsink"
	desc = "A detachable finned thermal sink for a magnetic accelerator. Cools passively, installed or loose. Reaching its heat capacity ruins it permanently."
	icon = 'modular_aphelion/modules/modular_ballistics/icons/parts.dmi'
	icon_state = "heatsink_cool"
	ammo_type = /obj/item/ammo_casing/parallax
	caliber = "parallax_metal"
	start_empty = TRUE
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT)
	var/stored_heat = 0
	var/heat_capacity = 100
	/// Heat dissipated per second, installed or loose.
	var/cooling_rate = 0.5
	var/burnt_out = FALSE

/obj/item/ammo_box/magazine/parallax/Destroy(force)
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/ammo_box/magazine/parallax/process(seconds_per_tick)
	stored_heat = max(0, stored_heat - cooling_rate * seconds_per_tick)
	update_appearance()
	if(!stored_heat)
		return PROCESS_KILL

/obj/item/ammo_box/magazine/parallax/proc/absorb_heat(amount)
	if(stored_heat + amount >= heat_capacity)
		burnt_out = TRUE
	stored_heat = min(heat_capacity, stored_heat + amount)
	START_PROCESSING(SSobj, src)
	update_appearance()

// No physical cartridges, even when recharged by an external signal.
/obj/item/ammo_box/magazine/parallax/top_off(load_type, starting = FALSE)
	return

/obj/item/ammo_box/magazine/parallax/give_round(obj/item/ammo_casing/new_round, replace_spent = 0)
	return FALSE

/obj/item/ammo_box/magazine/parallax/add_notes_box()
	return "A reusable heatsink; the gun's internal metal feedstock is effectively inexhaustible."

/obj/item/ammo_box/magazine/parallax/examine(mob/user)
	. = ..()
	. += span_notice("Heat: [round(100 * heat_fraction())]%. Dissipation: [cooling_rate] heat per second.")
	if(burnt_out)
		. += span_danger("Burnt out! Cooling will not repair it. Replace it before firing safely.")

/obj/item/ammo_box/magazine/parallax/update_icon_state()
	. = ..()
	icon_state = heatsink_state()
	if(istype(loc, /obj/item/gun/ballistic/parallax))
		var/obj/item/gun/ballistic/parallax/gun = loc
		if(gun.magazine == src)
			gun.update_appearance()
			SEND_SIGNAL(gun, COMSIG_UPDATE_AMMO_HUD)

/obj/item/ammo_box/magazine/parallax/proc/heatsink_state()
	if(burnt_out)
		return "heatsink_ruined"
	if(stored_heat >= heat_capacity * 2 / 3)
		return "heatsink_hot"
	if(stored_heat >= heat_capacity / 3)
		return "heatsink_warm"
	return "heatsink_cool"

/obj/item/ammo_box/magazine/parallax/proc/heat_fraction()
	return clamp(stored_heat / max(1, heat_capacity), 0, 1)

/obj/item/gun/ballistic/parallax/chamber_round(spin_cylinder, replace_new_round)
	if(!chambered && magazine)
		chambered = new /obj/item/ammo_casing/parallax(src)

/obj/item/gun/ballistic/parallax/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = TRUE)
	QDEL_NULL(chambered)
	if(chamber_next_round)
		chamber_round()

/obj/item/gun/ballistic/parallax/proc/shot_heat()
	var/obj/item/ballistic_module/barrel/barrel = modules["barrel"]
	var/heat = heat_per_projectile * (barrel ? barrel.projectiles_per_shot : 1) * frame_heat_multiplier
	for(var/obj/item/ballistic_module/part as anything in all_modules())
		heat *= part.heat_multiplier
	return heat

/obj/item/gun/ballistic/parallax/proc/thermal_ready()
	var/obj/item/ammo_box/magazine/parallax/sink = magazine
	// Heat never interrupts firing; a ruined sink burns the shooter on every shot.
	return istype(sink) && !QDELETED(sink)

/// Only successful discharges add heat, once per shot or shotgun volley.
/obj/item/gun/ballistic/parallax/proc/add_shot_heat(mob/living/user)
	var/obj/item/ammo_box/magazine/parallax/sink = magazine
	if(!istype(sink))
		return
	// The shot that ruins the sink is harmless to the shooter; burns start next shot.
	var/already_ruined = sink.burnt_out
	sink.absorb_heat(shot_heat())
	if(!already_ruined && sink.burnt_out)
		playsound(src, overheat_sound, overheat_sound_volume, FALSE)
	if(already_ruined && user)
		// Burn only the arm holding the receiver, including when the other hand supports it.
		var/holding_index = user.get_held_index_of_item(src)
		if(!holding_index)
			holding_index = user.active_hand_index
		var/burn_zone = IS_RIGHT_INDEX(holding_index) ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
		user.apply_damage(overheat_burn_damage, BURN, burn_zone)
		balloon_alert(user, "overheated gun burns your arm!")

/// Heat is applied before shoot_live_shot calls this, so the ruining shot peaks.
/obj/item/gun/ballistic/parallax/fire_sounds()
	var/obj/item/ammo_box/magazine/parallax/sink = magazine
	var/heat_fraction = 0
	if(istype(sink))
		// A ruined sink retains the warning pitch even after cooling.
		heat_fraction = sink.burnt_out ? 1 : sink.heat_fraction()
	var/shot_frequency = 1 + (hot_fire_pitch - 1) * heat_fraction
	// playsound_local applies frequency only with vary enabled. Supplying an
	// explicit frequency bypasses random variation while enabling pitch changes.
	if(suppressed)
		playsound(src, suppressed_sound, suppressed_volume, TRUE, ignore_walls = FALSE, extrarange = SILENCED_SOUND_EXTRARANGE, falloff_distance = 0, frequency = shot_frequency)
	else
		playsound(src, fire_sound, fire_sound_volume, TRUE, frequency = shot_frequency)

/obj/item/gun/ballistic/parallax/attack_self(mob/living/user)
	if(magazine)
		eject_magazine(user)
	else
		balloon_alert(user, "no heatsink installed!")

/obj/item/gun/ballistic/parallax/rack(mob/user = null)
	return

/obj/item/gun/ballistic/parallax/add_notes_ballistic()
	return "Magnetically accelerates rice-sized metal shavings. Heat capacity replaces ammunition capacity."

/// Compatibility count for ballistic callers, including the ruining shot.
/obj/item/gun/ballistic/parallax/get_ammo(countchambered = TRUE)
	var/obj/item/ammo_box/magazine/parallax/sink = magazine
	if(!istype(sink) || sink.burnt_out)
		return 0
	return CEILING(max(0, sink.heat_capacity - sink.stored_heat) / shot_heat(), 1)

/// Replace the numerical ammo counter with a bottom-up flame warning symbol.
/obj/item/gun/ballistic/parallax/update_custom_ammo_hud(atom/movable/screen/ammo_counter/hud)
	hud.maptext = null
	hud.icon_state = ""
	// Clear cached digit overlays as well as visible ones when changing weapons.
	var/mutable_appearance/coil = mutable_appearance('modular_aphelion/modules/modular_ballistics/icons/heat_hud.dmi', heat_hud_state())
	hud.set_hud(COLOR_WHITE, null, null, null, null, null, coil)
	return TRUE

/// Burnout is permanent: cooling a ruined sink must never lower its warning.
/obj/item/gun/ballistic/parallax/proc/heat_hud_state()
	var/obj/item/ammo_box/magazine/parallax/sink = magazine
	if(!istype(sink))
		return "coil_missing"
	if(sink.burnt_out)
		return "coil_20"
	return "coil_[CEILING(sink.heat_fraction() * 20, 1)]"
