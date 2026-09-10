// Barrel variants: firing characteristics and barrel-specific suppressor mount coordinates.

/** Compact sidearm accelerator and shared firing properties for all barrels. */
/obj/item/ballistic_module/barrel
	attachment_points = list(
		"silencer" = list(
			"type" = /obj/item/ballistic_module/silencer,
			"world" = list("default" = list(0, 1)),
			"loose" = list("default" = list(17, 0)),
			"rifle_left" = list("default" = list(0, 1)),
			"rifle_right" = list("default" = list(0, 1)),
			"compact_left" = list("default" = list(0, 1)),
			"compact_right" = list("default" = list(0, 1)),
		),
	)
	name = "Parallax compact accelerator"
	desc = "A compact, heat-efficient sidearm accelerator for close-range fire. Leaves the other hand free on an unstocked standard frame, but offers limited accuracy at range. Pair with a semi-automatic controller for deliberate single shots."
	socket = "barrel"
	icon_state = "barrel_short"
	var/shot_delay = 0.5 SECONDS
	var/damage_factor = 1
	/// Applied to projectile travel speed, independently of the shot cycle.
	var/projectile_velocity_multiplier = 1
	heat_multiplier = 1
	/// Shared by the firing adapter and heat calculation.
	var/projectiles_per_shot = 1
	var/pellet_spread = 0
	dispersion = 6
	kick = 0.5
	/// The accelerator determines the report independently of stocks and optics.
	var/shot_sound = 'modular_nova/modules/modular_weapons/sounds/pulse_shoot.ogg'
	var/shot_volume = 50

/obj/item/ballistic_module/barrel/examine(mob/user)
	. = ..()
	. += span_notice("Base shot cycle: [shot_delay / 10] seconds. Damage multiplier: [damage_factor]x.")
	. += span_notice("Projectile speed: [projectile_velocity_multiplier]x standard.")

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
	desc = "A fast-cycling medium-length accelerator for accurate mid-range fire. Fires lighter, cooler shavings than the assault accelerator at a faster cadence. Accepts a suppressor."
	icon_state = "barrel_carbine"
	shot_delay = 0.3 SECONDS
	damage_factor = 0.6
	heat_multiplier = 0.8
	dispersion = 5
	kick = 0.9
	is_long = TRUE
	shot_volume = 60

/** Compact accelerator trading damage efficiency and precision for rapid fire. */
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
	desc = "A rapid-cycling compact accelerator for close-range machine pistols. Pair with an automatic controller for sustained fire. Very light shavings and wide dispersion trade damage efficiency for compact automatic fire."
	icon_state = "barrel_smg"
	dispersion = 8
	kick = 0.7
	shot_delay = 0.3 SECONDS
	damage_factor = 0.4
	heat_multiplier = 0.6

/** Rifle accelerator trading cadence and thermal efficiency for heavier hits. */
/obj/item/ballistic_module/barrel/carbine/assault
	attachment_points = list()
	name = "Parallax assault accelerator"
	desc = "A hard-hitting rifle accelerator. Fires heavier, hotter shavings than the carbine, with a slower cadence, wider dispersion and stronger recoil. No suppressor mount."
	icon_state = "barrel_assault"
	shot_delay = 0.6 SECONDS
	damage_factor = 1.2
	heat_multiplier = 1.6
	dispersion = 6
	kick = 1.2

/** Two-handed accelerator for powerful ranged shots with high heat expenditure. */
/obj/item/ballistic_module/barrel/marksman
	attachment_points = list()
	name = "Parallax marksman accelerator"
	desc = "A long accelerator for deliberate ranged shots. High damage and faster projectiles, but a slow firing cycle and extreme heat output allow only a few shots before cooling. Best paired with a precision stock and scope; requires both hands."
	icon_state = "barrel_marksman"
	shot_delay = 1.6 SECONDS
	damage_factor = 2.25
	projectile_velocity_multiplier = 1.5
	heat_multiplier = 6
	dispersion = 4
	kick = 2
	is_long = TRUE
	shot_volume = 70

/obj/item/ballistic_module/barrel/shotgun
	attachment_points = list()
	name = "Parallax six-tube shotgun accelerator"
	desc = "A fixed cluster of six low-power accelerator tubes. Delivers a broad close-range volley with a long recovery and heavy heat load. Requires both hands; pellet spread remains even when scoped."
	icon_state = "barrel_shotgun"
	shot_delay = 1.8 SECONDS
	damage_factor = 0.4
	heat_multiplier = 0.8
	dispersion = 4
	kick = 1.6
	is_long = TRUE
	shot_volume = 70
	projectiles_per_shot = 6
	pellet_spread = 20
