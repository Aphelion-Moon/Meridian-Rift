/**
 * # Salvage wrench
 *
 * A bespoke shipbreaking wrench. A wrench subtype so it satisfies every
 * wrench check in the shipbreaking code. Faster than a standard wrench
 * via a lower toolspeed value.
 */
/obj/item/wrench/salvage_wrench
	name = "salvage wrench"
	desc = "A heavy high-visibility wrench purpose-built for stripping salvaged ships. Faster than a standard wrench on ship fixtures."
	icon = 'modular_aphelion/modules/shipbreaking/icons/tools.dmi'
	icon_state = "salvage_wrench"
	inhand_icon_state = "wrench"
	toolspeed = 0.75
	force = 8
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT,
		/datum/material/aluminum = HALF_SHEET_MATERIAL_AMOUNT,
	)

/obj/item/wrench/salvage_wrench/examine(mob/user)
	. = ..()
	. += span_notice("It strips ship fixtures faster than a standard wrench.")
