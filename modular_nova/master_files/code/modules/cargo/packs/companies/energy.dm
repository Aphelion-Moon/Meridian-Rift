/datum/supply_pack/companies/energy
	group = "★ Energy Weapons"
	access = ACCESS_WEAPONS
	access_view = ACCESS_WEAPONS
	express_lock = TRUE
	order_flags = ORDER_GOODY
	discountable = SUPPLY_PACK_STD_DISCOUNTABLE

//Microstar weapons
/datum/supply_pack/companies/energy/microstar

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons
	cost = CARGO_CRATE_VALUE * 1.25
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/disabler
	contains = list(/obj/item/gun/energy/disabler)

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/advtaser
	contains = list(/obj/item/gun/energy/e_gun/advtaser)
	cost = CARGO_CRATE_VALUE * 1.75

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/disabler_smg
	contains = list(/obj/item/gun/energy/disabler/smg)
	cost = CARGO_CRATE_VALUE * 1.75
	access = ACCESS_WEAPONS
	access_view = ACCESS_WEAPONS
	express_lock = TRUE
	order_flags = ORDER_GOODY

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/mini_egun
	contains = list(/obj/item/gun/energy/e_gun/mini)

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/laser_pistol
	contains = list(/obj/item/gun/energy/laser/pistol)

/datum/supply_pack/companies/energy/microstar/basic_energy_weapons/energy_holster
	contains = list(/obj/item/storage/belt/holster/energy/thermal)
	cost = CARGO_CRATE_VALUE * 3

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/laser
	contains = list(/obj/item/gun/energy/laser)
	cost = CARGO_CRATE_VALUE * 1.25
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/laser/soul
	contains = list(/obj/item/gun/energy/laser/soul)

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/laser_carbine
	contains = list(/obj/item/gun/energy/laser/carbine)
	cost = CARGO_CRATE_VALUE * 1.75

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/laser_assault
	contains = list(/obj/item/gun/energy/laser/assault)
	cost = CARGO_CRATE_VALUE * 4

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/egun
	contains = list(/obj/item/gun/energy/e_gun)
	cost = CARGO_CRATE_VALUE * 2
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/mod_laser_small
	contains = list(/obj/item/gun/energy/modular_laser_rifle/carbine)
	cost = CARGO_CRATE_VALUE * 2.5
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/mod_laser_large
	contains = list(/obj/item/gun/energy/modular_laser_rifle)
	cost = CARGO_CRATE_VALUE * 4

/datum/supply_pack/companies/energy/microstar/basic_energy_long_weapons/basic_mcr
	contains = list(/obj/item/gun/microfusion/mcr01)
	cost = CARGO_CRATE_VALUE * 2

// Preset 'loadout' kits built around a barrel attachment
/datum/supply_pack/companies/energy/microstar/mcr_attachments
	cost = CARGO_CRATE_VALUE * 2

/datum/supply_pack/companies/energy/microstar/mcr_attachments/hellfire
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_loadout/hellfire)

/datum/supply_pack/companies/energy/microstar/mcr_attachments/scatter
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_loadout/scatter)

/datum/supply_pack/companies/energy/microstar/mcr_attachments/lance
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_loadout/lance)

/datum/supply_pack/companies/energy/microstar/mcr_attachments/repeater
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_loadout/repeater)

/datum/supply_pack/companies/energy/microstar/mcr_attachments/tacticool
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_loadout/tacticool)

// Improved phase emitters, cells, and cell attachments
/datum/supply_pack/companies/energy/microstar/mcr_upgrades

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/stabilizer
	contains = list(/obj/item/microfusion_cell_attachment/stabiliser)
	cost = CARGO_CRATE_VALUE * 0.5

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/enhanced_part_kit
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_parts/enhanced)
	cost = CARGO_CRATE_VALUE

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/capacity_booster
	contains = list(/obj/item/microfusion_cell_attachment/overcapacity)
	cost = CARGO_CRATE_VALUE * 0.5

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/advanced_part_kit
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_parts/advanced)
	cost = CARGO_CRATE_VALUE

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/selfcharge
	contains = list(/obj/item/microfusion_cell_attachment/selfcharging)
	cost = CARGO_CRATE_VALUE * 2

/datum/supply_pack/companies/energy/microstar/mcr_upgrades/bluespace_part_kit
	contains = list(/obj/item/storage/briefcase/secure/white/mcr_parts/bluespace)
	cost = CARGO_CRATE_VALUE * 3

/datum/supply_pack/companies/energy/microstar/experimental_energy
	cost = CARGO_CRATE_VALUE * 3

/datum/supply_pack/companies/energy/microstar/experimental_energy/ion_carbine
	contains = list(/obj/item/gun/energy/ionrifle/carbine)

// HC Weapons
/datum/supply_pack/companies/energy/hc_surplus

/datum/supply_pack/companies/energy/hc_surplus/plasma_thrower
	contains = list(/obj/item/gun/ballistic/automatic/pistol/plasma_thrower)

/datum/supply_pack/companies/energy/hc_surplus/plasma_marksman
	contains = list(/obj/item/gun/ballistic/automatic/pistol/plasma_marksman)
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/hc_surplus/crank_taser
	contains = list(/obj/item/gun/energy/taser/crank)
	cost = CARGO_CRATE_VALUE * 2
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/hc_surplus/stun_gun //Not a gun but it's only fair to place similar items close to each other
	contains = list(/obj/item/melee/baton/security/stun_gun/loaded)
	cost = CARGO_CRATE_VALUE * 1.5 //Similarly live action roleplay'iy stun baton lite
	access = FALSE
	access_view = FALSE
	express_lock = FALSE
	order_flags = ORDER_COMPANY

/datum/supply_pack/companies/energy/hc_surplus/zaibas
	contains = list(/obj/item/gun/ballistic/automatic/pulse_rifle)
	cost = CARGO_CRATE_VALUE * 6

/datum/supply_pack/companies/energy/hc_surplus/zaibas_a
	contains = list(/obj/item/gun/ballistic/rifle/pulse_sniper)
	cost = CARGO_CRATE_VALUE * 7
