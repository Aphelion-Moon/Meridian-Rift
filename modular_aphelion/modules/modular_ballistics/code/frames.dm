// Alternate receiver prototypes. Shared modules keep their existing behavior.

/obj/item/gun/ballistic/parallax/heavy
	name = "Parallax heavy-frame prototype"
	desc = "An armored Parallax receiver with a reinforced recoil bed. Always bulky and requires two hands, but reduces recoil by 30%. Uses standard Parallax modules."
	frame_name_prefix = "Parallax heavy"
	frame_icon_state = "frame_heavy"
	icon_state = "frame_heavy"
	inhand_icon_state = "frame_heavy"
	frame_recoil_multiplier = 0.7
	frame_requires_two_hands = TRUE
	starting_modules = list(/obj/item/ballistic_module/barrel/carbine/assault, /obj/item/ballistic_module/control/automatic, /obj/item/ballistic_module/stock/precision, /obj/item/ballistic_module/optic)
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
			"compact_left" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"compact_right" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
		),
		"optic" = list(
			"type" = /obj/item/ballistic_module/optic,
			"world" = list("default" = list(0, 0)),
			"rifle_left" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"rifle_right" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"compact_left" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
			"compact_right" = list("2" = list(0, 0), "1" = list(0, 0), "4" = list(0, 0), "8" = list(0, 0)),
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
