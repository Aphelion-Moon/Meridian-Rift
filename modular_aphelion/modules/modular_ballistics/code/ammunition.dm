// Frangible projectiles, cartridges, six-round shotgun volleys and cassette indicators.

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
