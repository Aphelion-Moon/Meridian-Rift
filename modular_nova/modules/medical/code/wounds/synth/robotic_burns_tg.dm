// Metal scars from the severe and critical tiers.
/datum/wound/burn/robotic
	can_scar = TRUE
	default_scar_file = METAL_SCAR_FILE

/datum/wound/burn/robotic/moderate
	can_scar = FALSE

/datum/wound/burn/robotic/severe
	scar_keyword = "burnsevere"

/datum/wound/burn/robotic/critical
	scar_keyword = "burncritical"

/datum/wound_pregen_data/burnt_metal/generate_scar_priorities()
	return list("[BIO_METAL]")
