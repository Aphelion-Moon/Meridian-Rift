/** A MOD core that converts its conscious wearer's psionic capacity into power. */
/obj/item/mod/core/psionic
	name = "\improper MOD psionic core"
	desc = "A psionic transducer fitted into a MOD core housing. It powers the suit by building strain in its wearer's mind. \
		It requires a conscious psion and cuts out before causing burnout."
	icon_state = "mod-core-plasma"
	custom_materials = list(
		/datum/material/silver = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 1.05,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT * 1.05,
	)
	/// Power supplied per whole point of strain; basic suit upkeep costs one strain per second.
	var/charge_per_strain = DEFAULT_CHARGE_DRAIN
	/// Unspent power already paid for with a whole strain point, always less than charge_per_strain.
	var/prepaid_charge = 0

/** Discard prepaid power when the wearer leaves, so another wearer cannot inherit it. */
/obj/item/mod/core/psionic/install(obj/item/mod/control/mod_unit)
	. = ..()
	RegisterSignal(mod, COMSIG_MOD_WEARER_UNSET, PROC_REF(on_wearer_unset))

/** Remove the wearer listener and discard prepaid power before detaching. */
/obj/item/mod/core/psionic/uninstall()
	UnregisterSignal(mod, COMSIG_MOD_WEARER_UNSET)
	prepaid_charge = 0
	return ..()

/** Clear the previous wearer's fractional power allowance. */
/obj/item/mod/core/psionic/proc/on_wearer_unset(datum/source, mob/living/wearer)
	SIGNAL_HANDLER
	prepaid_charge = 0

/** Resolve a conscious, unsuppressed psion without retaining their profile. */
/obj/item/mod/core/psionic/charge_source()
	var/mob/living/wearer = mod?.wearer
	if(!wearer || wearer.stat != STABLE || HAS_TRAIT(wearer, TRAIT_KNOCKEDOUT) || !wearer.can_cast_psionics(PSIONIC_THERMAL))
		return null
	var/datum/component/psionic_profile/profile = wearer.get_psionic_profile()
	if(!profile || profile.is_burned_out())
		return null
	return profile

/** Report usable power, leaving one point below the profile's burnout threshold. */
/obj/item/mod/core/psionic/charge_amount()
	var/datum/component/psionic_profile/profile = charge_source()
	if(!profile)
		return 0
	profile.decay_strain()
	var/available_charge = max(0, profile.max_strain - profile.strain - 1) * charge_per_strain + prepaid_charge
	return min(available_charge, max_charge_amount())

/** Express the wearer's strain capacity in the same power units as charge_amount(). */
/obj/item/mod/core/psionic/max_charge_amount()
	var/datum/component/psionic_profile/profile = mod?.wearer?.get_psionic_profile()
	return max(1, (profile ? profile.max_strain - 1 : PSIONIC_DEFAULT_MAX_STRAIN - 1) * charge_per_strain)

/** Check the full cost before a module acts; suppression also blocks zero-cost activation. */
/obj/item/mod/core/psionic/check_charge(amount)
	var/available_charge = charge_amount()
	return amount >= 0 && available_charge > 0 && available_charge >= amount

/**
 * Pay whole strain points in advance and retain the fractional remainder.
 * Oversized passive drains consume the remaining capacity, allowing normal MOD shutdown.
 * External charging deliberately retains the base core's refusal to add charge.
 */
/obj/item/mod/core/psionic/subtract_charge(amount)
	if(amount <= 0)
		return 0
	var/datum/component/psionic_profile/profile = charge_source()
	if(!profile)
		return 0
	amount = min(amount, charge_amount())
	if(amount <= 0)
		return 0
	var/strain_cost = CEILING(max(0, amount - prepaid_charge) / charge_per_strain, 1)
	if(strain_cost && !profile.try_gain_strain(strain_cost))
		return 0
	prepaid_charge = max(0, prepaid_charge + strain_cost * charge_per_strain - amount)
	mod.update_charge_alert()
	return amount

/** Display remaining mental capacity on the existing suit HUD. */
/obj/item/mod/core/psionic/get_charge_icon_state()
	switch(round(charge_amount() / max_charge_amount(), 0.01))
		if(0.75 to INFINITY)
			return SPACESUIT_CELL_HIGH
		if(0.5 to 0.75)
			return SPACESUIT_CELL_MID
		if(0.25 to 0.5)
			return SPACESUIT_CELL_LOW
		if(0.02 to 0.25)
			return SPACESUIT_CELL_VERY_LOW
	return SPACESUIT_CELL_EMPTY

/** Match the purple core, retaining the low-capacity warning color. */
/obj/item/mod/core/psionic/get_chargebar_color()
	return charge_amount() / max_charge_amount() <= 0.33 ? "bad" : "purple"

/** Label the charge bar as mental capacity instead of stored electrical energy. */
/obj/item/mod/core/psionic/get_chargebar_string()
	if(!charge_source())
		return "Requires a conscious, unsuppressed psion without burnout."
	return "[round(100 * charge_amount() / max_charge_amount(), 0.1)]% psionic capacity"

/** Assemble a psionic transducer through the same crafting category as other MOD cores. */
/datum/crafting_recipe/mod_core_psionic
	name = "MOD core (Psionic)"
	result = /obj/item/mod/core/psionic
	tool_behaviors = list(TOOL_SCREWDRIVER)
	time = 10 SECONDS
	reqs = list(
		/obj/item/stack/cable_coil = 5,
		/obj/item/stack/rods = 2,
		/obj/item/stack/sheet/glass = 1,
		/obj/item/assembly/signaler/anomaly/bluespace = 1,
		/obj/item/stack/sheet/mineral/silver = 2,
	)
	category = CAT_ROBOT

/** Sell a single psionic core alongside standard cores at the same cargo price. */
/datum/supply_pack/companies/modsuits/core/psionic
	contains = list(/obj/item/mod/core/psionic)

/** Offer three psionic cores through Science with the standard core crate's price and access. */
/datum/supply_pack/science/mod_core/psionic
	name = "MOD Psionic Core Crate"
	desc = "Three psionic MOD cores that power suits by building strain in their wearers. Requires psionic users."
	contains = list(/obj/item/mod/core/psionic = 3)
	crate_name = "\improper MOD psionic core crate"
