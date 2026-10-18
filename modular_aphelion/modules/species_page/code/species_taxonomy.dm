/**
 * The /datum/species_family the species page files each species type under. A subtype takes its nearest listed
 * parent's family unless it belongs somewhere else. Holiday species are filed under Holiday while they wait for their
 * holiday, whatever this says. See /datum/species/proc/get_species_family().
 */
GLOBAL_LIST_INIT(species_page_families, list(
	/datum/species/human = /datum/species_family/mammalian,
	/datum/species/dwarf = /datum/species_family/mammalian,
	/datum/species/tajaran = /datum/species_family/mammalian,
	/datum/species/vulpkanin = /datum/species_family/mammalian,
	/datum/species/shadekin = /datum/species_family/mammalian,
	/datum/species/lizard = /datum/species_family/reptilian,
	/datum/species/unathi = /datum/species_family/reptilian,
	/datum/species/monkey/kobold = /datum/species_family/reptilian,
	/datum/species/vox = /datum/species_family/avian,
	/datum/species/vox_primalis = /datum/species_family/avian,
	/datum/species/teshari = /datum/species_family/avian,
	/datum/species/akula = /datum/species_family/aquatic,
	/datum/species/skrell = /datum/species_family/aquatic,
	/datum/species/insectoid = /datum/species_family/insectoid,
	/datum/species/fly = /datum/species_family/insectoid,
	/datum/species/moth = /datum/species_family/insectoid,
	/datum/species/synthetic/holosynth = /datum/species_family/synthetic,
	/datum/species/protean = /datum/species_family/synthetic,
	/datum/species/android = /datum/species_family/synthetic,
	/datum/species/ethereal = /datum/species_family/elemental,
	/datum/species/golem = /datum/species_family/elemental,
	/datum/species/plasmaman = /datum/species_family/elemental,
	/datum/species/pod = /datum/species_family/elemental,
	/datum/species/xeno = /datum/species_family/xenobiological,
	/datum/species/jelly = /datum/species_family/xenobiological,
	/datum/species/snail = /datum/species_family/xenobiological,
	/datum/species/abductor = /datum/species_family/xenobiological,
	/datum/species/dullahan = /datum/species_family/xenobiological,
	/datum/species/ghoul = /datum/species_family/xenobiological,
	/datum/species/skeleton = /datum/species_family/paranormal,
	/datum/species/zombie = /datum/species_family/paranormal,
	/datum/species/mutant = /datum/species_family/paranormal,
	/datum/species/human/vampire = /datum/species_family/paranormal,
	/datum/species/shadow = /datum/species_family/paranormal,
	/datum/species/spirit = /datum/species_family/paranormal,
	/datum/species/monkey = /datum/species_family/paranormal,
	// The template species: bases for players' own creations, which say so or have no lore of their own. Each is filed
	// under the family it is a template for - see GLOB.species_page_templates.
	/datum/species/humanoid = /datum/species_family/mammalian,
	/datum/species/mammal = /datum/species_family/mammalian,
	/datum/species/aquatic = /datum/species_family/aquatic,
	/datum/species/insect = /datum/species_family/insectoid,
	/datum/species/synthetic = /datum/species_family/synthetic,
))

/// The template species, which the page lists after their family's own species, marked custom. Only these types - a
/// subtype is a species of its own.
GLOBAL_LIST_INIT(species_page_templates, list(
	/datum/species/humanoid = TRUE,
	/datum/species/mammal = TRUE,
	/datum/species/aquatic = TRUE,
	/datum/species/insect = TRUE,
	/datum/species/synthetic = TRUE,
))

// Vox Primalis is not a subtype of Vox, but it is one of their kin.
/datum/species/vox_primalis/get_variant_of(list/page_ids)
	return page_ids[SPECIES_VOX] ? SPECIES_VOX : null

// Kobolds are not a subtype of lizards, but they are lizardfolk: one of their kin.
/datum/species/monkey/kobold/get_variant_of(list/page_ids)
	return page_ids[SPECIES_LIZARD] ? SPECIES_LIZARD : null
