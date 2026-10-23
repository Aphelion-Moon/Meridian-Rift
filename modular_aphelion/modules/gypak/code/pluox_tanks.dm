//Tanks for the Gypak We just copy emergency tanks, mostly.
//Intentionally awful. Filter the pluox out.
/obj/item/tank/internals/pluox
	name = "pluoxium tank"
	desc = "A small tank of pluoxium and oxygen. Incredibly valuable, yet intended for crew that require a much more concentrated mix of air. \
	Sadly, it contains very little, with the mix having seemingly become worthless. Perhaps you should filter it."
	icon_state = "emergency"
	inhand_icon_state = "emergency_tank"
	worn_icon_state = "emergency"
	tank_holder_icon_state = "holder_emergency"
	worn_icon = null
	obj_flags = CONDUCTS_ELECTRICITY
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_SMALL
	force = 4
	volume = 2
	distribute_pressure = 24//24kpa is their min. No define slapped here, sorry.

/obj/item/tank/internals/pluox/populate_gas()
	air_contents.set_gas(/datum/gas/oxygen, (3*ONE_ATMOSPHERE)*volume/(R_IDEAL_GAS_EQUATION*T20C) * N2STANDARD)//We recycle volume defines.
	air_contents.set_gas(/datum/gas/pluoxium, (3*ONE_ATMOSPHERE)*volume/(R_IDEAL_GAS_EQUATION*T20C) * N2O_ANESTHETIC)//As above. 0.79 / 0.35, respectively.
