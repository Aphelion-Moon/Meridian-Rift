// Receiver tradeoffs: flexible sidearm, stable heavy, fast but hot bullpup.

/obj/item/gun/ballistic/parallax/heavy
	name = "Parallax heavy-frame prototype"
	desc = "An armored Parallax receiver built for steady sustained fire. Reduces dispersion by 2, recoil by 45% and generated heat by 20%, but adds 0.05 seconds between shots. Always bulky and requires two hands. Uses standard Parallax modules."
	frame_name_prefix = "Parallax heavy"
	frame_icon_state = "frame_heavy"
	icon_state = "frame_heavy"
	inhand_icon_state = "frame_heavy"
	frame_recoil_multiplier = 0.55
	frame_dispersion = -2
	frame_cycle_cost = 0.05 SECONDS
	frame_heat_multiplier = 0.8
	frame_requires_two_hands = TRUE
	starting_modules = list(/obj/item/ballistic_module/barrel/carbine/assault, /obj/item/ballistic_module/control/automatic, /obj/item/ballistic_module/stock, /obj/item/ballistic_module/optic)
	attachment_points = list(
		"barrel" = list(
			"type" = /obj/item/ballistic_module/barrel,
			"world" = list("default" = list(5, 0)),
			"rifle_left" = list("2" = list(-3, 0), "1" = list(3, 1), "4" = list(3, 0), "8" = list(-3, 0)),
			"rifle_right" = list("2" = list(3, 0), "1" = list(-3, 1), "4" = list(3, 0), "8" = list(-3, 0)),
			"compact_left" = list("2" = list(-2, -1), "1" = list(1, 1), "4" = list(-2, 0), "8" = list(2, 0)),
			"compact_right" = list("2" = list(1, -1), "1" = list(-2, 1), "4" = list(2, 0), "8" = list(-2, 0)),
		),
		"controller" = list(
			"type" = /obj/item/ballistic_module/control,
			"world" = list("default" = list(3, -1)),
			"rifle_left" = list("2" = list(-2, 0), "1" = list(2, 1), "4" = list(2, 0), "8" = list(-2, 0)),
			"rifle_right" = list("2" = list(2, 0), "1" = list(-2, 1), "4" = list(2, 0), "8" = list(-2, 0)),
			"compact_left" = list("2" = list(-1, 0), "1" = list(1, 1), "4" = list(-1, 0), "8" = list(1, 0)),
			"compact_right" = list("2" = list(1, 0), "1" = list(-1, 1), "4" = list(1, 0), "8" = list(-1, 0)),
		),
		"stock" = list(
			"type" = /obj/item/ballistic_module/stock,
			"world" = list("default" = list(-1, 0)),
			"rifle_left" = list("2" = list(1, 0), "1" = list(-1, 0), "4" = list(-1, 0), "8" = list(1, 0)),
			"rifle_right" = list("2" = list(-1, 0), "1" = list(1, 0), "4" = list(-1, 0), "8" = list(1, 0)),
		),
		"optic" = list(
			"type" = /obj/item/ballistic_module/optic,
		),
		"magazine" = list(
			"type" = /obj/item/ammo_box/magazine/parallax,
			"world" = list("default" = list(2, 0)),
			"rifle_left" = list("2" = list(-1, 0), "1" = list(1, 0), "4" = list(1, 0), "8" = list(-1, 0)),
			"rifle_right" = list("2" = list(1, 0), "1" = list(-1, 0), "4" = list(1, 0), "8" = list(-1, 0)),
			"compact_left" = list("2" = list(-1, 0), "1" = list(1, 1), "4" = list(-1, 0), "8" = list(1, 0)),
			"compact_right" = list("2" = list(1, 0), "1" = list(-1, 1), "4" = list(1, 0), "8" = list(-1, 0)),
		),
	)

/obj/item/gun/ballistic/parallax/heavy/empty
	starting_modules = list()
	spawnwithmagazine = FALSE

/obj/item/gun/ballistic/parallax/bullpup
	name = "Parallax bullpup prototype"
	desc = "A rear-action Parallax receiver for aggressive close-range fire. Its integrated stock reduces dispersion by 1 and recoil by 15%; its shortened action cuts 0.05 seconds off the shot cycle but generates 25% more heat. Requires both hands and cannot accept a separate stock."
	frame_name_prefix = "Parallax bullpup"
	frame_recoil_multiplier = 0.85
	frame_dispersion = -1
	frame_cycle_cost = -0.05 SECONDS
	frame_heat_multiplier = 1.25
	frame_icon_state = "frame_bullpup"
	icon_state = "frame_bullpup"
	inhand_icon_state = "frame_bullpup"
	frame_requires_two_hands = TRUE
	starting_modules = list(/obj/item/ballistic_module/barrel/carbine, /obj/item/ballistic_module/control/automatic, /obj/item/ballistic_module/optic)
	attachment_points = list(
		"barrel" = list(
			"type" = /obj/item/ballistic_module/barrel,
			"world" = list("default" = list(-2, 0)),
			"rifle_left" = list("2" = list(1, 0), "1" = list(-2, 0), "4" = list(-2, 0), "8" = list(1, 0)),
			"rifle_right" = list("2" = list(-2, 0), "1" = list(1, 0), "4" = list(-2, 0), "8" = list(1, 0)),
			"compact_left" = list("2" = list(1, 0), "1" = list(0, 0), "4" = list(1, 0), "8" = list(0, 0)),
			"compact_right" = list("2" = list(0, 0), "1" = list(1, 0), "4" = list(0, 0), "8" = list(1, 0)),
		),
		"controller" = list(
			"type" = /obj/item/ballistic_module/control,
			"world" = list("default" = list(-3, 0)),
			"rifle_left" = list("2" = list(2, 0), "1" = list(-2, 0), "4" = list(-2, 0), "8" = list(2, 0)),
			"rifle_right" = list("2" = list(-2, 0), "1" = list(2, 0), "4" = list(-2, 0), "8" = list(2, 0)),
			"compact_left" = list("2" = list(1, 1), "1" = list(-1, 0), "4" = list(1, 0), "8" = list(-1, 0)),
			"compact_right" = list("2" = list(-1, 1), "1" = list(1, 0), "4" = list(-1, 0), "8" = list(1, 0)),
		),
		"optic" = list(
			"type" = /obj/item/ballistic_module/optic,
			"world" = list("default" = list(-3, 0)),
			"rifle_left" = list("2" = list(2, 0), "1" = list(-2, 0), "4" = list(-2, 0), "8" = list(2, 0)),
			"rifle_right" = list("2" = list(-2, 0), "1" = list(2, 0), "4" = list(-2, 0), "8" = list(2, 0)),
			"compact_left" = list("2" = list(1, 1), "1" = list(-1, 0), "4" = list(1, 0), "8" = list(-1, 0)),
			"compact_right" = list("2" = list(-1, 1), "1" = list(1, 0), "4" = list(-1, 0), "8" = list(1, 0)),
		),
		"magazine" = list(
			"type" = /obj/item/ammo_box/magazine/parallax,
			"world" = list("default" = list(-17, -3)),
			"rifle_left" = list("2" = list(11, 1), "1" = list(-12, -3), "4" = list(-12, -1), "8" = list(11, -1)),
			"rifle_right" = list("2" = list(-12, 1), "1" = list(10, -3), "4" = list(-12, -1), "8" = list(11, -1)),
			"compact_left" = list("2" = list(5, 2), "1" = list(-4, -4), "4" = list(6, -1), "8" = list(-5, -1)),
			"compact_right" = list("2" = list(-5, 2), "1" = list(4, -4), "4" = list(-5, -1), "8" = list(6, -1)),
		),
	)

/obj/item/gun/ballistic/parallax/bullpup/empty
	starting_modules = list()
	spawnwithmagazine = FALSE
