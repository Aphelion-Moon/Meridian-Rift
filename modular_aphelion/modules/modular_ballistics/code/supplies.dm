// Conversion-kit contents, storage capacity and cargo orders.

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
	desc = "Two Parallax sidearms, two complete conversion kits, four spare reusable heatsinks and a screwdriver."
	cost = CARGO_CRATE_VALUE * 24
	contains = list(/obj/item/gun/ballistic/parallax, /obj/item/gun/ballistic/parallax, /obj/item/storage/box/parallax_modules, /obj/item/storage/box/parallax_modules, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/screwdriver)
	crate_name = "Parallax modular ballistics crate"

/datum/supply_pack/security/armory/parallax_ammo
	name = "Parallax Heatsinks"
	desc = "Four reusable heatsinks for the Parallax magnetic accelerator platform."
	cost = CARGO_CRATE_VALUE * 4
	contains = list(/obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax)
	crate_name = "Parallax heatsink crate"
