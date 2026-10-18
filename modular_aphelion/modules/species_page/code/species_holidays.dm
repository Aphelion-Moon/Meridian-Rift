// Holiday species, matching the check_holidays() gate in each check_roundstart_eligible().

/datum/species/dullahan/get_holiday()
	return HALLOWEEN

/datum/species/human/vampire/get_holiday()
	return HALLOWEEN

/datum/species/mutant/get_holiday()
	return HALLOWEEN

/datum/species/mutant/infectious/get_holiday()
	return null

/datum/species/shadow/get_holiday()
	return HALLOWEEN

/datum/species/shadow/nightmare/get_holiday()
	return null

/datum/species/skeleton/get_holiday()
	return HALLOWEEN

/datum/species/spirit/get_holiday()
	return halloween_exclusive ? HALLOWEEN : null

/datum/species/zombie/get_holiday()
	return HALLOWEEN

/datum/species/monkey/get_holiday()
	return id == SPECIES_MONKEY ? MONKEYDAY : null
