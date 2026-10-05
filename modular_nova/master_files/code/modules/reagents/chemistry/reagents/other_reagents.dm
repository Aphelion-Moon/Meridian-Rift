/datum/reagent/space_cleaner/sterilizine/expose_turf(turf/exposed_turf, reac_volume)
	. = ..()
	// sterilize miasma into oxygen in sufficient concentrations
	if(reac_volume < 1)
		return

	if(!istype(exposed_turf, /turf/open))
		return

	var/turf/open/open_exposed_turf = exposed_turf
	var/datum/gas_mixture/turf/air = open_exposed_turf.air
	/* // APHELION EDIT REMOVAL START - DOGMOS
	air.assert_gases(/datum/gas/miasma, /datum/gas/oxygen)
	var/list/moles = air.moles
	var/miasma_moles = moles[/datum/gas/miasma]
	*/ // APHELION EDIT REMOVAL END
	var/miasma_moles = air.get_moles(/datum/gas/miasma) // APHELION EDIT ADDITION - DOGMOS

	if(!miasma_moles)
		return

	/* // APHELION EDIT REMOVAL START - DOGMOS
	moles[/datum/gas/miasma] -= miasma_moles
	moles[/datum/gas/oxygen] += miasma_moles
	air.garbage_collect()
	*/ // APHELION EDIT REMOVAL END
	// APHELION EDIT ADDITION START - DOGMOS
	air.adjust_moles(/datum/gas/miasma, -miasma_moles)
	air.adjust_moles(/datum/gas/oxygen, miasma_moles)
	// APHELION EDIT ADDITION END
	exposed_turf.air_update_turf(FALSE, FALSE)
