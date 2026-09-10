/**
 * # Magnalock module
 *
 * Coreless weak kinesis variant for salvage work. Needs no anomaly core,
 * so engineers can print it without anomaly research. Uses the base kinesis
 * grab range and throws held objects with weak force at half grab range.
 */

/**
 * Weak kinesis module for handling cargo and salvage.
 *
 * Coreless and prebuilt, so it works straight out of the lathe.
 */
/obj/item/mod/module/anomaly_locked/kinesis/weak
	name = "MOD magnalock module"
	desc = "A modular plug-in to the forearm, an experimental unit used for handling cargo and heavy objects. \
		This piece of technology allows the user to generate precise magnetic fields, \
		letting them move objects at a limited range. \
		Oddly enough, it doesn't seem to work on living creatures."
	coreless = TRUE
	prebuilt = TRUE
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 1.25,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
	)

/**
 * Throws the launched object with weak force.
 *
 * Registers impact handling from the base module, then throws
 * at half grab range with minimal speed.
 * Arguments:
 * * launched_object - The atom to throw.
 */
/obj/item/mod/module/anomaly_locked/kinesis/weak/launch(atom/movable/launched_object)
	playsound(launched_object, 'sound/effects/magic/repulse.ogg', 100, TRUE)
	RegisterSignal(launched_object, COMSIG_MOVABLE_IMPACT, PROC_REF(launch_impact))
	var/turf/target_turf = get_turf_in_angle(get_angle(mod.wearer, launched_object), get_turf(src), 10)
	launched_object.throw_at(target_turf, range = grab_range / 2, speed = 1, thrower = mod.wearer, spin = isitem(launched_object))

/**
 * Research design for the magnalock module.
 *
 * Sits on the engineering node instead of the anomalock node,
 * since the module needs no core.
 */
/datum/design/module/mod_kinesis/weak
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 1.25,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/uranium = SHEET_MATERIAL_AMOUNT,
	)
	name = "Magnalock Module"
	build_path = /obj/item/mod/module/anomaly_locked/kinesis/weak

/datum/techweb_node/mod_engi/New()
	unlocked_designs += list(
		/datum/design/module/mod_kinesis/weak,
	)
	return ..()
