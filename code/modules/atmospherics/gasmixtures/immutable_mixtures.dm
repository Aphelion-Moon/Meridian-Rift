// Immutable mixtures are read-only after construction. Planetary mixtures defer finalization until
// their mapper string has populated the gas contents.

/datum/gas_mixture/immutable
	var/initial_temperature
	/// Whether construction must wait for a parser to populate the mixture.
	var/defer_immutable_finalization = FALSE

/datum/gas_mixture/immutable/New(volume)
	. = ..()
	if(!isnull(initial_temperature))
		set_temperature(initial_temperature)
	if(!defer_immutable_finalization)
		mark_immutable()

/datum/gas_mixture/immutable/space
	initial_temperature = TCMB

/datum/gas_mixture/immutable/space/heat_capacity()
	return HEAT_CAPACITY_VACUUM

/datum/gas_mixture/immutable/planetary
	var/list/initial_gas = list()
	defer_immutable_finalization = TRUE

/datum/gas_mixture/immutable/planetary/proc/parse_string_immutable(gas_string)
	gas_string = SSair.preprocess_gas_string(gas_string)

	var/list/mix = initial_gas
	var/list/gas = params2list(gas_string)
	if(gas["TEMP"])
		initial_temperature = text2num(gas["TEMP"])
		gas -= "TEMP"
	mix.Cut()
	for(var/id, value in gas)
		var/path = id
		if(!ispath(path))
			path = gas_id2path(path) //a lot of these strings can't have embedded expressions (especially for mappers), so support for IDs needs to stick around
		mix[path] = text2num(value)

	set_temperature(initial_temperature)
	for(var/gas_id, value in mix)
		set_moles(gas_id, value)
	mark_immutable()
