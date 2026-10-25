//It's not a proper space suit! Kinda!
//Meant for synths. Credits to Bay12 for the sprite.
//I believe attribution goes to 'AzlanOnPC', for the sprite!
//If I'm mistaken, do correct this.
/obj/item/clothing/suit/space/radiator
	name = "radiator unit"
	desc = "An enormous, backpack mounted radiator! \
	Intended for synthetics working in hostile environments, in the absence of more expensive equipment."
	icon_state = "suitcooler"//Dropped the other sprites.
	icon = 'modular_aphelion/modules/backpack_radiator/icons/backpack_radiator.dmi'
	worn_icon = 'modular_aphelion/modules/backpack_radiator/icons/backpack_radiator_onmob.dmi'
	inhand_icon_state = "bombvest"
	clothing_flags = null//It doesn't really do anything, beyond giving cooling!
	body_parts_covered = null//No coverage.
	slowdown = null//No slowdown!
	armor_type = null//No armour. Sorry.
	flags_inv = null//This goes on your back. Not really a proper suit.
	//Given the nature of this, and that it provides no pressure resist (synths have it innate), we cover everything for temp.
	cold_protection = CHEST|GROIN|LEGS|FEET|ARMS|HANDS|HEAD
	min_cold_protection_temperature = SPACE_SUIT_MIN_TEMP_PROTECT_OFF
	heat_protection = CHEST|GROIN|LEGS|FEET|ARMS|HANDS|HEAD
	max_heat_protection_temperature = SPACE_SUIT_MAX_TEMP_PROTECT
	//Easier to unbuckle, too. Down -3 seconds from parent.
	strip_delay = 3 SECONDS
	equip_delay_other = 3 SECONDS
	//Other misc stuff.
	cell = /obj/item/stock_parts/power_store/cell/super//Better cell, given the nature of it.
	//This is odd. Probably dumb. Revert this and remove storage later maybe.
	slot_flags = ITEM_SLOT_OCLOTHING | ITEM_SLOT_BACK//Otherwise, sitting in the armour slot without the other bonuses of space suits makes it vestigial.
//Do this later. Find a better way to handle cells and make this not a subtype of spacesuits!!!
/*
/obj/item/clothing/suit/space/radiator/Initialize(mapload)
	. = ..()
	create_storage(storage_type = /datum/storage/mod_storage/civilian)
*/
//Cargo order. Bad place for it? Probably.
/datum/supply_pack/emergency/radiators
	name = "Radiator Unit Crate"
	desc = "Contains two backpack radiator units."
	cost = CARGO_CRATE_VALUE * 3
	contains = list(/obj/item/clothing/suit/space/radiator,
					/obj/item/clothing/suit/space/radiator,
				)
	crate_name = "radiator unit crate"
