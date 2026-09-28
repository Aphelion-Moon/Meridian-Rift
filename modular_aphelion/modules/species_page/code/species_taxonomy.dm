// Families on the species page. Subtypes inherit their parent's family unless they
// belong somewhere else, like the holiday Vampire under Paranormal.

/datum/species/human/get_species_family()
	return /datum/species_family/mammalian

/datum/species/humanoid/get_species_family()
	return /datum/species_family/mammalian

/datum/species/dwarf/get_species_family()
	return /datum/species_family/mammalian

/datum/species/mammal/get_species_family()
	return /datum/species_family/mammalian

/datum/species/tajaran/get_species_family()
	return /datum/species_family/mammalian

/datum/species/vulpkanin/get_species_family()
	return /datum/species_family/mammalian

/datum/species/shadekin/get_species_family()
	return /datum/species_family/mammalian

/datum/species/lizard/get_species_family()
	return /datum/species_family/reptilian

/datum/species/unathi/get_species_family()
	return /datum/species_family/reptilian

/datum/species/monkey/kobold/get_species_family()
	return /datum/species_family/reptilian

/datum/species/vox/get_species_family()
	return /datum/species_family/avian

/datum/species/vox_primalis/get_species_family()
	return /datum/species_family/avian

/datum/species/teshari/get_species_family()
	return /datum/species_family/avian

/datum/species/aquatic/get_species_family()
	return /datum/species_family/aquatic

/datum/species/akula/get_species_family()
	return /datum/species_family/aquatic

/datum/species/skrell/get_species_family()
	return /datum/species_family/aquatic

/datum/species/insect/get_species_family()
	return /datum/species_family/insectoid

/datum/species/insectoid/get_species_family()
	return /datum/species_family/insectoid

/datum/species/fly/get_species_family()
	return /datum/species_family/insectoid

/datum/species/moth/get_species_family()
	return /datum/species_family/insectoid

/datum/species/synthetic/get_species_family()
	return /datum/species_family/synthetic

/datum/species/protean/get_species_family()
	return /datum/species_family/synthetic

/datum/species/android/get_species_family()
	return /datum/species_family/synthetic

/datum/species/ethereal/get_species_family()
	return /datum/species_family/elemental

/datum/species/golem/get_species_family()
	return /datum/species_family/elemental

/datum/species/plasmaman/get_species_family()
	return /datum/species_family/elemental

/datum/species/pod/get_species_family()
	return /datum/species_family/elemental

/datum/species/xeno/get_species_family()
	return /datum/species_family/xenobiological

/datum/species/jelly/get_species_family()
	return /datum/species_family/xenobiological

/datum/species/snail/get_species_family()
	return /datum/species_family/xenobiological

/datum/species/abductor/get_species_family()
	return /datum/species_family/xenobiological

/datum/species/dullahan/get_species_family()
	return /datum/species_family/paranormal

/datum/species/ghoul/get_species_family()
	return /datum/species_family/paranormal

/datum/species/skeleton/get_species_family()
	return /datum/species_family/paranormal

/datum/species/zombie/get_species_family()
	return /datum/species_family/paranormal

/datum/species/mutant/get_species_family()
	return /datum/species_family/paranormal

/datum/species/human/vampire/get_species_family()
	return /datum/species_family/paranormal

/datum/species/shadow/get_species_family()
	return /datum/species_family/paranormal

/datum/species/spirit/get_species_family()
	return /datum/species_family/paranormal

/datum/species/monkey/get_species_family()
	return /datum/species_family/paranormal

// Vox Primalis is not a subtype of Vox, but it is one of their kin.
/datum/species/vox_primalis/get_variant_of(list/page_ids)
	return page_ids[SPECIES_VOX] ? SPECIES_VOX : null
