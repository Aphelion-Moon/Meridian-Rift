/datum/reagent/space_cleaner/sterilizine/expose_turf(turf/exposed_turf, reac_volume)
	. = ..()
	// sterilize miasma into oxygen in sufficient concentrations
	if(reac_volume < 1)
		return

	if(!istype(exposed_turf, /turf/open))
		return

	var/turf/open/open_exposed_turf = exposed_turf
	var/datum/gas_mixture/turf/air = open_exposed_turf.air
	var/miasma_moles = air.get_moles(/datum/gas/miasma)

	if(!miasma_moles)
		return

	air.adjust_moles(/datum/gas/miasma, -miasma_moles)
	air.adjust_moles(/datum/gas/oxygen, miasma_moles)
	exposed_turf.air_update_turf(FALSE, FALSE)
