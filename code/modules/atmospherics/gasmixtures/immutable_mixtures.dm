/* // APHELION EDIT REMOVAL START - DOGMOS
//"immutable" gas mixture used for immutable calculations
//it can be changed, but any changes will ultimately be undone before they can have any effect
*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START - DOGMOS
// Immutable mixtures are read-only after construction. Planetary mixtures defer finalization until
// their mapper string has populated the gas contents.
// APHELION EDIT ADDITION END

/datum/gas_mixture/immutable
	var/initial_temperature
	/// Whether construction must wait for a parser to populate the mixture. // APHELION EDIT ADDITION - DOGMOS
	var/defer_immutable_finalization = FALSE // APHELION EDIT CHANGE - DOGMOS - ORIGINAL: gc_share = TRUE

/* // APHELION EDIT REMOVAL START - DOGMOS
/datum/gas_mixture/immutable/New()
	..()
	garbage_collect()
*/ // APHELION EDIT REMOVAL END
// APHELION EDIT ADDITION START - DOGMOS
/datum/gas_mixture/immutable/New(volume)
	. = ..()
	if(!isnull(initial_temperature))
		set_temperature(initial_temperature)
	if(!defer_immutable_finalization)
		mark_immutable()
// APHELION EDIT ADDITION END

/* // APHELION EDIT REMOVAL START - DOGMOS
/datum/gas_mixture/immutable/garbage_collect()
	temperature = temperature_archived = initial_temperature
	moles.Cut()
	moles_archive.Cut()

/datum/gas_mixture/immutable/archive()
	return // nothing changes, so we do nothing

/datum/gas_mixture/immutable/merge()
	return FALSE //we're immutable.

/datum/gas_mixture/immutable/share(datum/gas_mixture/sharer, our_coeff, sharer_coeff)
	. = ..()
	sharer.temperature = initial_temperature
	garbage_collect()

/datum/gas_mixture/immutable/react()
	return FALSE //we're immutable.

/datum/gas_mixture/immutable/copy()
	return new type //we're immutable, so we can just return a new instance.

/datum/gas_mixture/immutable/copy_from()
	return FALSE //we're immutable.

/datum/gas_mixture/immutable/copy_from_ratio()
	return FALSE //we're immutable.

/datum/gas_mixture/immutable/temperature_share(datum/gas_mixture/sharer, conduction_coefficient, sharer_temperature, sharer_heat_capacity)
	. = ..()
	temperature = initial_temperature

//used by space tiles
*/ // APHELION EDIT REMOVAL END
/datum/gas_mixture/immutable/space
	initial_temperature = TCMB

/datum/gas_mixture/immutable/space/heat_capacity()
	return HEAT_CAPACITY_VACUUM

/* // APHELION EDIT REMOVAL START - DOGMOS
/datum/gas_mixture/immutable/space/remove()
	return copy() //we're always empty, so we can just return a copy.

/datum/gas_mixture/immutable/space/remove_ratio()
	return copy() //we're always empty, so we can just return a copy.

//planet side stuff
*/ // APHELION EDIT REMOVAL END
/datum/gas_mixture/immutable/planetary
	var/list/initial_gas = list()
	defer_immutable_finalization = TRUE // APHELION EDIT ADDITION - DOGMOS

/* // APHELION EDIT REMOVAL START - DOGMOS
// Intentionally duplicate code to save microseconds on a call to parent
/datum/gas_mixture/immutable/planetary/garbage_collect()
	temperature = temperature_archived = initial_temperature
	moles = initial_gas.Copy()
	moles_archive = initial_gas.Copy()

/datum/gas_mixture/immutable/planetary/proc/parse_string_immutable(gas_string) //I know I know, I need this tho
*/ // APHELION EDIT REMOVAL END
/datum/gas_mixture/immutable/planetary/proc/parse_string_immutable(gas_string) // APHELION EDIT ADDITION - DOGMOS
	gas_string = SSair.preprocess_gas_string(gas_string)

	var/list/mix = initial_gas
	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		initial_temperature = text2num(gas["TEMP"])
		/* // APHELION EDIT REMOVAL START - DOGMOS
		temperature_archived = initial_temperature
		temperature = initial_temperature
		*/ // APHELION EDIT REMOVAL END
		gas -= "TEMP"
	mix.Cut()
	for(var/id, value in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		mix[path] = text2num(value)

	/* // APHELION EDIT REMOVAL START - DOGMOS
	var/list/cached_moles = moles
	var/list/cached_moles_archive = moles_archive
	*/ // APHELION EDIT REMOVAL END
	set_temperature(initial_temperature) // APHELION EDIT ADDITION - DOGMOS
	for(var/gas_id, value in mix)
		/* // APHELION EDIT REMOVAL START - DOGMOS
		cached_moles[gas_id] = cached_moles_archive[gas_id] = value


		*/ // APHELION EDIT REMOVAL END
		// APHELION EDIT ADDITION START - DOGMOS
		set_moles(gas_id, value)
	mark_immutable()
		// APHELION EDIT ADDITION END
