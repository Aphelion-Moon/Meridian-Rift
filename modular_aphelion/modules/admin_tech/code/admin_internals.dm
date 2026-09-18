//! Debug & Admin Internals Tanks

//code\game\objects\items\tanks\tank_types.dm
// TODO: sprites, fix worn sprite

/// Moles needed to fill a tank of the given volume to 29 atmospheres at room temperature. A tank starts taking
/// pressure damage at TANK_LEAK_PRESSURE (30 atmospheres), so this is as full as one can be filled and still be safe.
/// Mixes scale this by their share, e.g. ADMIN_TANK_MOLES(volume) * 0.25 for a quarter of the tank.
#define ADMIN_TANK_MOLES(tank_volume) ((29 * ONE_ATMOSPHERE) * (tank_volume) / (R_IDEAL_GAS_EQUATION * T20C))

//Base Debug Tank, probably fucks hard when used with ordnance, I haven't tried and you probably shouldn't try on prod either.
/obj/item/tank/internals/admin
	name = "subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. The longer your gaze lingers, the more unsettled you feel. Somewhere, a scientist yearns to print these. "
	icon = 'modular_aphelion/modules/admin_tech/icons/admin_items.dmi'
	icon_state = "sub-tank"
	inhand_icon_state = "emergency_tank"
	worn_icon = 'modular_aphelion/modules/admin_tech/icons/worn_admin_clothing.dmi'
	worn_icon_state = "sub-tank"
	tank_holder_icon_state = "holder_emergency_engi"
	force = 10
	distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE
	volume = 490//default tanks are 70, and this is a multiple for some scaling and mixing formulae
	w_class = WEIGHT_CLASS_TINY
	slot_flags = ITEM_SLOT_ADMIN
	resistance_flags = INDESTRUCTIBLE
	obj_flags = parent_type::obj_flags | ADMIN_OBJ_FLAGS
	obj_flags_nova = parent_type::obj_flags_nova | ADMIN_OBJ_FLAGS_NOVA

/obj/item/tank/internals/admin/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/manufacturer_examine, COMPANY_ADMIN)

/obj/item/tank/internals/admin/populate_gas()
	return//spawns empty

//Normal Internals
//Oxygen - Most things breathe this
/obj/item/tank/internals/admin/oxygen
	name = "oxygen subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a standardized internals information label showing the tank should contain oxygen."
	distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE

/obj/item/tank/internals/admin/oxygen/populate_gas()
	air_contents.set_gas(/datum/gas/oxygen, ADMIN_TANK_MOLES(volume))

//Pluoxium - The cooler oxygen
/obj/item/tank/internals/admin/pluoxium
	name = "pluoxium subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a standardized internals information label showing the tank should contain pluoxium."
	distribute_pressure = 3

/obj/item/tank/internals/admin/pluoxium/populate_gas()
	air_contents.set_gas(/datum/gas/pluoxium, ADMIN_TANK_MOLES(volume))

//Plasma - Plasmama, where have you gone, we miss you
/obj/item/tank/internals/admin/plasma
	name = "plasma subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a standardized internals information label showing the tank should contain plasma."
	distribute_pressure = TANK_PLASMAMAN_RELEASE_PRESSURE

/obj/item/tank/internals/admin/plasma/populate_gas()
	air_contents.set_gas(/datum/gas/plasma, ADMIN_TANK_MOLES(volume))

//Nitrogen - Criminal cats breathe this.
/obj/item/tank/internals/admin/nitrogen
	name = "nitrogen subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a standardized internals information label showing the tank should contain nitrogen."
	distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE

/obj/item/tank/internals/admin/nitrogen/populate_gas()
	air_contents.set_gas(/datum/gas/nitrogen, ADMIN_TANK_MOLES(volume))

//'Ooops, lots of dust. Dont breathe this!'
//Tritium - Just fuckin' straight radiation.
/obj/item/tank/internals/admin/tritium
	name = "tritium subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a warning label indicating the tank should contain tritium."
	distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE

/obj/item/tank/internals/admin/tritium/populate_gas()
	air_contents.set_gas(/datum/gas/tritium, ADMIN_TANK_MOLES(volume))

//Freon - Funny ice-cycle tank
/obj/item/tank/internals/admin/freon
	name = "freon subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There is a warning label indicating the tank should contain freon."
	distribute_pressure = TANK_DEFAULT_RELEASE_PRESSURE

/obj/item/tank/internals/admin/freon/populate_gas()
	air_contents.set_gas(/datum/gas/freon, ADMIN_TANK_MOLES(volume))

//Now we get into some gas mixes
//Mixes containing nitrium can be poisonous. The higher the output pressure of a mix with nitrium, the higher the likelihood or rate of poisoning, but the more impactful the boon.
/obj/item/tank/internals/admin/mix
	abstract_type = /obj/item/tank/internals/admin/mix

//Robust Mix, courtesy of Zul.
//This will kill you if you leave it running, but it's like stims on demand if you mind the toxin cycle.
/obj/item/tank/internals/admin/mix/juggermol
	name = "'JUGGERMOL' subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. There's a cute sticker applied of a red-haired neko warning you about 'Nitrosyl Plasmide Poisoning', whatever that means."
	distribute_pressure = 23

/obj/item/tank/internals/admin/mix/juggermol/populate_gas()
	air_contents.set_gas(/datum/gas/pluoxium, ADMIN_TANK_MOLES(volume) * 0.112)
	air_contents.set_gas(/datum/gas/healium, ADMIN_TANK_MOLES(volume) * 0.333)
	air_contents.set_gas(/datum/gas/nitrium, ADMIN_TANK_MOLES(volume) * 0.555)

//Anti-conflagratory. Good for firebugs. Doesn't save your clothing.
/obj/item/tank/internals/admin/mix/fusionfur
	name = "'Fusion-Fur' subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. A partially-peeled sticker of a grey-furred anthromorph advertises how well this mix keeps her fur from burning."
	distribute_pressure = 8

/obj/item/tank/internals/admin/mix/fusionfur/populate_gas()
	air_contents.set_gas(/datum/gas/pluoxium, ADMIN_TANK_MOLES(volume) * 0.95)
	air_contents.set_gas(/datum/gas/halon, ADMIN_TANK_MOLES(volume) * 0.05)

//Stupid in a tank. Give one to the clown.
//if you say it bee-zed, the name makes slightly more sense. Feel free to rename this one if you're funnier than me, dear reader.
/obj/item/tank/internals/admin/mix/beeshead
	name = "'Bee's Head' subspace tank"
	desc = "A palm-sized gas tank embedded with an ominous purple crystal. It's covered in stickers of butt-bots."
	icon_state = "emergency_clown"
	inhand_icon_state = "emergency_clown"
	tank_holder_icon_state = "holder_emergency_clown"
	distribute_pressure = 23

/obj/item/tank/internals/admin/mix/beeshead/populate_gas()
	air_contents.set_gas(/datum/gas/pluoxium, ADMIN_TANK_MOLES(volume) * 0.75)
	air_contents.set_gas(/datum/gas/nitrous_oxide, ADMIN_TANK_MOLES(volume) * 0.05)
	air_contents.set_gas(/datum/gas/bz, ADMIN_TANK_MOLES(volume) * 0.05)
	air_contents.set_gas(/datum/gas/helium, ADMIN_TANK_MOLES(volume) * 0.15)

#undef ADMIN_TANK_MOLES
