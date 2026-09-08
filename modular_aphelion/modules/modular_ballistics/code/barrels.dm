// Barrel variants: firing characteristics and barrel-specific suppressor mount coordinates.

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
	desc = "A short, shrouded ballistic accelerator. Compact and quick to handle, with reduced muzzle performance."
	socket = "barrel"
	icon_state = "barrel_short"
	var/shot_delay = 0.3 SECONDS
	var/damage_factor = 0.85
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
	dispersion = 5
	shot_delay = 0.35 SECONDS

/obj/item/ballistic_module/barrel/carbine/assault
	attachment_points = list()
	name = "Parallax assault accelerator"
	desc = "A deep twin-rib accelerator housing with recessed thermal channels. Its heavier assembly reduces recoil at the expense of a longer cycle."
	icon_state = "barrel_assault"
	shot_delay = 0.3 SECONDS
	damage_factor = 1
	kick = 1.6

/obj/item/ballistic_module/barrel/marksman
	attachment_points = list()
	name = "Parallax marksman accelerator"
	desc = "A long, split-shroud accelerator. Its greater muzzle performance requires a slower firing cycle."
	icon_state = "barrel_marksman"
	shot_delay = 0.8 SECONDS
	damage_factor = 1.45
	dispersion = 2
	kick = 2
	is_long = TRUE
	shot_volume = 70

/obj/item/ballistic_module/barrel/shotgun
	attachment_points = list()
	name = "Parallax six-tube shotgun accelerator"
	desc = "A fixed cluster of six short accelerator tubes. Fires six metal shavings in a spread, generating six times the heat per volley."
	icon_state = "barrel_shotgun"
	shot_delay = 1.2 SECONDS
	damage_factor = 10 / 22
	dispersion = 4
	kick = 1.6
	is_long = TRUE
	shot_volume = 70
	projectiles_per_shot = 6
	pellet_spread = 20
