// Conversion-kit contents, storage capacity and cargo orders.

/** Replacement and conversion parts for the Parallax lethal armory platform. */
/obj/item/storage/box/parallax_modules
	name = "Parallax conversion kit"
	desc = "A complete set of interchangeable modules for Parallax lethal armory weapons. Receiver, heatsink and servicing screwdriver sold separately."

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

/** Two complete weapons with conversion parts and spare thermal capacity. */
/datum/supply_pack/security/armory/parallax
	name = "Parallax Modular Ballistics Kit"
	desc = "Two lethal Parallax sidearms, two complete conversion kits, four spare reusable heatsinks and a screwdriver."
	cost = CARGO_CRATE_VALUE * 24
	contains = list(/obj/item/gun/ballistic/parallax, /obj/item/gun/ballistic/parallax, /obj/item/storage/box/parallax_modules, /obj/item/storage/box/parallax_modules, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/screwdriver)
	crate_name = "Parallax modular ballistics crate"

/datum/supply_pack/security/armory/parallax_ammo
	name = "Parallax Heatsinks"
	desc = "Four reusable heatsinks for the Parallax magnetic accelerator platform."
	cost = CARGO_CRATE_VALUE * 4
	contains = list(/obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax, /obj/item/ammo_box/magazine/parallax)
	crate_name = "Parallax heatsink crate"

/** One complete set of parts for converting or repairing an existing weapon. */
/datum/supply_pack/security/armory/parallax_conversion
	name = "Parallax Conversion Kit"
	desc = "One complete Parallax conversion kit: six accelerators, three controllers, two stocks, two optics and a suppressor. Receiver, heatsink and screwdriver not included."
	cost = CARGO_CRATE_VALUE * 6
	contains = list(/obj/item/storage/box/parallax_modules)
	crate_name = "Parallax conversion crate"

/** Empty standard receiver for replacing a lost frame or assembling a new weapon. */
/datum/supply_pack/security/armory/parallax_receiver
	name = "Parallax Standard Receiver"
	desc = "One empty standard Parallax receiver for compact sidearms or rifle builds. Modules, heatsink and screwdriver not included."
	cost = CARGO_CRATE_VALUE * 6
	contains = list(/obj/item/gun/ballistic/parallax/empty)
	crate_name = "Parallax standard receiver crate"

/** Stable, cooler receiver supplied without attachments or a heatsink. */
/datum/supply_pack/security/armory/parallax_receiver/heavy
	name = "Parallax Heavy Receiver"
	desc = "One empty heavy Parallax receiver. Trades a slower firing cycle and two-handed bulk for lower recoil, dispersion and heat. Modules, heatsink and screwdriver not included."
	cost = CARGO_CRATE_VALUE * 8
	contains = list(/obj/item/gun/ballistic/parallax/heavy/empty)
	crate_name = "Parallax heavy receiver crate"

/** Faster, hotter receiver with an integrated stock and no loose modules. */
/datum/supply_pack/security/armory/parallax_receiver/bullpup
	name = "Parallax Bullpup Receiver"
	desc = "One empty bullpup Parallax receiver. Cycles faster but generates more heat; requires both hands and has an integrated stock. Modules, heatsink and screwdriver not included."
	cost = CARGO_CRATE_VALUE * 8
	contains = list(/obj/item/gun/ballistic/parallax/bullpup/empty)
	crate_name = "Parallax bullpup receiver crate"
