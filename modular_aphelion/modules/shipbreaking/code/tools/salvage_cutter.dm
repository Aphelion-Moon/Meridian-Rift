/**
 * # Salvage cutter
 *
 * A bespoke shipbreaking torch. A welding tool subtype so it satisfies
 * every welder check in the shipbreaking code. Cuts ship structure
 * faster than a standard welder via a lower toolspeed value.
 * Icon states follow the standard welder convention: base, -on flame
 * (animated, 2 frames like stock), and 100/75/50/25/0 fuel gauges
 * (0 blinks, 2 frames like stock).
 */
/obj/item/weldingtool/salvage_cutter
	name = "salvage cutter"
	desc = "A heavy torch purpose-built for cutting apart salvaged ships. Faster than a standard welder on hull work."
	icon = 'modular_aphelion/modules/shipbreaking/icons/tools.dmi'
	icon_state = "salvage_cutter"
	inhand_icon_state = "indwelder"
	max_fuel = 80
	toolspeed = 0.75
	force = 8
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/aluminum = HALF_SHEET_MATERIAL_AMOUNT,
	)

/obj/item/weldingtool/salvage_cutter/examine(mob/user)
	. = ..()
	. += span_notice("It cuts ship hull faster than a standard welder.")

/obj/item/weldingtool/salvage_cutter/flamethrower_screwdriver()
	return
