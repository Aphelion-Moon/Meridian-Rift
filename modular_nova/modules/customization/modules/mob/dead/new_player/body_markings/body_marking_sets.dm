/datum/body_marking_set
	///The preview name of the body marking set. HAS to be unique
	var/name
	/// The markings this set puts on, as /datum/body_marking typepaths, in the order they go on.
	var/list/body_marking_list
	/// The species this set is meant for, species id -> TRUE, or null for any species: the ones a random character may draw it
	/// for, and without mismatched parts the only ones character setup offers it to. Each of its markings may be worn by at
	/// least these, as derive_body_marking_species() gives a marking the species of its sets.
	var/list/recommended_species = list(
		SPECIES_MAMMAL = TRUE,
		SPECIES_TAJARAN = TRUE,
		SPECIES_VULP = TRUE,
		SPECIES_AQUATIC = TRUE,
		SPECIES_AKULA = TRUE
	)
	/// Whether picking this set in character setup replaces every marking with the set's, as a unit. Otherwise the set replaces
	/// only the zones it covers and every other zone keeps its markings.
	var/keep_together = FALSE

/datum/body_marking_set/New()
	. = ..()
	if(recommended_species)
		recommended_species = string_assoc_list(recommended_species)

/**
 * Returns whether a species may wear this set without mismatched parts: any species when it names none, otherwise only the
 * ones it names.
 *
 * Arguments:
 * - species_id: the species' id.
 */
/datum/body_marking_set/proc/allows_species(species_id)
	return isnull(recommended_species) || !isnull(recommended_species[species_id])

/datum/body_marking_set/none
	name = SPRITE_ACCESSORY_NONE
	recommended_species = null

/datum/body_marking_set/tajaran
	name = "Tajaran"
	body_marking_list = list(/datum/body_marking/secondary/tajaran)

/datum/body_marking_set/fox
	name = "Fox"
	body_marking_list = list(/datum/body_marking/secondary/fox, /datum/body_marking/tertiary/fox)

/datum/body_marking_set/sergal
	name = "Sergal"
	body_marking_list = list(/datum/body_marking/secondary/sergal)

/datum/body_marking_set/husky
	name = "Husky"
	body_marking_list = list(/datum/body_marking/secondary/husky)

/datum/body_marking_set/fennec
	name = "Fennec"
	body_marking_list = list(/datum/body_marking/secondary/fennec)

/datum/body_marking_set/redpanda
	name = "Red Panda"
	body_marking_list = list(/datum/body_marking/secondary/redpanda, /datum/body_marking/tertiary/redpanda)

/datum/body_marking_set/dalmatian
	name = "Dalmatian"
	body_marking_list = list(/datum/body_marking/secondary/dalmatian)

/datum/body_marking_set/shepherd
	name = "Shepherd"
	body_marking_list = list(/datum/body_marking/secondary/shepherd, /datum/body_marking/tertiary/shepherd)

/datum/body_marking_set/wolf
	name = "Wolf"
	body_marking_list = list(/datum/body_marking/secondary/wolf, /datum/body_marking/tertiary/wolf)

/datum/body_marking_set/raccoon
	name = "Raccoon"
	body_marking_list = list(/datum/body_marking/secondary/raccoon)

/datum/body_marking_set/bovine
	name = "Bovine"
	body_marking_list = list(/datum/body_marking/secondary/bovine, /datum/body_marking/tertiary/bovine)

/datum/body_marking_set/possum
	name = "Possum"
	body_marking_list = list(/datum/body_marking/secondary/possum)

/datum/body_marking_set/corgi
	name = "Corgi"
	body_marking_list = list(/datum/body_marking/secondary/corgi)

/datum/body_marking_set/skunk
	name = "Skunk"
	body_marking_list = list(/datum/body_marking/secondary/skunk)

/datum/body_marking_set/panther
	name = "Panther"
	body_marking_list = list(/datum/body_marking/secondary/panther)

/datum/body_marking_set/tiger
	name = "Tiger"
	body_marking_list = list(/datum/body_marking/secondary/tiger, /datum/body_marking/tertiary/tiger)

/datum/body_marking_set/otter
	name = "Otter"
	body_marking_list = list(/datum/body_marking/secondary/otter, /datum/body_marking/tertiary/otter)

/datum/body_marking_set/otie
	name = "Otie"
	body_marking_list = list(/datum/body_marking/secondary/otie, /datum/body_marking/tertiary/otie)

/datum/body_marking_set/sabresune
	name = "Sabresune"
	body_marking_list = list(/datum/body_marking/secondary/sabresune)

/datum/body_marking_set/orca
	name = "Orca"
	body_marking_list = list(/datum/body_marking/secondary/orca)

/datum/body_marking_set/hawk
	name = "Hawk"
	body_marking_list = list(/datum/body_marking/secondary/hawk, /datum/body_marking/tertiary/hawk)

/datum/body_marking_set/corvid
	name = "Corvid"
	body_marking_list = list(/datum/body_marking/secondary/corvid, /datum/body_marking/tertiary/corvid)

/datum/body_marking_set/eevee
	name = "Eevee"
	body_marking_list = list(/datum/body_marking/secondary/eevee)

/datum/body_marking_set/deer
	name = "Deer"
	body_marking_list = list(/datum/body_marking/secondary/deer, /datum/body_marking/tertiary/deer)

/datum/body_marking_set/hyena
	name = "Hyena"
	body_marking_list = list(/datum/body_marking/secondary/hyena, /datum/body_marking/tertiary/hyena)

/datum/body_marking_set/dog
	name = "Dog"
	body_marking_list = list(/datum/body_marking/secondary/dog, /datum/body_marking/tertiary/dog)

/datum/body_marking_set/bat
	name = "Bat"
	body_marking_list = list(/datum/body_marking/tertiary/bat, /datum/body_marking/secondary/bat)

/datum/body_marking_set/goat
	name = "Goat"
	body_marking_list = list(/datum/body_marking/tertiary/goat)

/datum/body_marking_set/floof
	name = "Floof"
	body_marking_list = list(/datum/body_marking/secondary/floof)

/datum/body_marking_set/floofer
	name = "Floofer"
	body_marking_list = list(/datum/body_marking/secondary/floof, /datum/body_marking/tertiary/floofer)

/datum/body_marking_set/rat
	name = "Rat"
	body_marking_list = list(/datum/body_marking/secondary/handsfeet, /datum/body_marking/tertiary/rat)

/datum/body_marking_set/sloth
	name = "Sloth"
	body_marking_list = list(/datum/body_marking/secondary/handsfeet, /datum/body_marking/tertiary/sloth) // The rat's paws.

/datum/body_marking_set/scolipede
	name = "Scolipede"
	body_marking_list = list(/datum/body_marking/secondary/scolipede, /datum/body_marking/tertiary/scolipede)

/datum/body_marking_set/guilmon
	name = "Guilmon"
	body_marking_list = list(/datum/body_marking/secondary/guilmon, /datum/body_marking/tertiary/guilmon)

/datum/body_marking_set/xeno
	name = "Xeno"
	body_marking_list = list(/datum/body_marking/secondary/xeno, /datum/body_marking/tertiary/xeno)
	recommended_species = list(SPECIES_XENO = 1)

/datum/body_marking_set/datashark
	name = "Datashark"
	body_marking_list = list(/datum/body_marking/secondary/datashark)

/datum/body_marking_set/shark
	name = "Shark"
	body_marking_list = list(/datum/body_marking/secondary/shark)

/datum/body_marking_set/belly
	name = "Belly"
	body_marking_list = list(/datum/body_marking/secondary/belly)

/datum/body_marking_set/belly_slim
	name = "Belly Slim"
	body_marking_list = list(/datum/body_marking/secondary/bellyslim)

/datum/body_marking_set/hands_feet
	name = "Hands Feet"
	body_marking_list = list(/datum/body_marking/secondary/handsfeet)

/datum/body_marking_set/frog
	name = "Frog"
	body_marking_list = list(/datum/body_marking/secondary/frog)

/datum/body_marking_set/bee
	name = "Bee"
	body_marking_list = list(/datum/body_marking/secondary/bee)

/datum/body_marking_set/gradient
	name = "Gradient"
	body_marking_list = list(/datum/body_marking/secondary/gradient)

/datum/body_marking_set/harlequin
	name = "Harlequin"
	body_marking_list = list(/datum/body_marking/secondary/harlequin)

/datum/body_marking_set/harlequin_reversed
	name = "Harlequin Reversed"
	body_marking_list = list(/datum/body_marking/secondary/harlequin_reversed)

/datum/body_marking_set/plain
	name = "Plain"
	body_marking_list = list(/datum/body_marking/secondary/plain)

/datum/body_marking_set/splotches
	name = "Splotches"
	body_marking_list = list(/datum/body_marking/other/splotches)

/// The head splotch mirrored, on the other side of the face: a set of its own, so the Splotches preset keeps one.
/datum/body_marking_set/splotches_swapped
	name = "Splotches Swapped"
	body_marking_list = list(/datum/body_marking/other/splotcheswap)

/datum/body_marking_set/chitin
	name = "Chitin"
	body_marking_list = list(/datum/body_marking/other/chitin)

//AKULA MARKINGS
/datum/body_marking_set/akula
	recommended_species = list(SPECIES_AKULA = 1)

/datum/body_marking_set/akula/akula
	name = "Akula"
	body_marking_list = list(/datum/body_marking/akula/secondary, /datum/body_marking/akula/tertiary)

//VOX MARKINGS
/datum/body_marking_set/vox
	recommended_species = list(SPECIES_VOX = 1)

/datum/body_marking_set/vox/vox
	name = "Vox"
	body_marking_list = list(/datum/body_marking/secondary/vox/vox)

/datum/body_marking_set/vox/vox_tiger
	name = "Vox Tiger"
	body_marking_list = list(/datum/body_marking/secondary/vox/vox, /datum/body_marking/tertiary/vox/tiger)

/datum/body_marking_set/vox/vox_hive
	name = "Vox Hive"
	body_marking_list = list(/datum/body_marking/secondary/vox/vox, /datum/body_marking/tertiary/vox/hive)

/datum/body_marking_set/vox/vox_nightling
	name = "Vox Nightling"
	body_marking_list = list(/datum/body_marking/secondary/vox/vox, /datum/body_marking/tertiary/vox/nightling)

/datum/body_marking_set/vox/vox_heart
	name = "Vox Heart"
	body_marking_list = list(/datum/body_marking/secondary/vox/vox, /datum/body_marking/tertiary/vox/heart)

/datum/body_marking_set/synthliz
	recommended_species = list(SPECIES_SYNTH = 1)

/datum/body_marking_set/synthliz/scutes
	name = "Synth Scutes"
	body_marking_list = list(/datum/body_marking/secondary/synthliz/scutes)

/datum/body_marking_set/synthliz/pecs
	name = "Synth Pecs"
	body_marking_list = list(/datum/body_marking/secondary/synthliz/pecs)

/datum/body_marking_set/synthliz/pecs_light
	name = "Synth Pecs Lights"
	body_marking_list = list(/datum/body_marking/secondary/synthliz/pecs, /datum/body_marking/tertiary/synthliz/collarlights)

/// Three lights at the collar (secondary) and eight down the chest's sides (tertiary): two sheets, two colours, no pixel in common.
/datum/body_marking_set/synthliz/lights
	name = "Synth Lights"
	body_marking_list = list(/datum/body_marking/secondary/synthliz/lights, /datum/body_marking/tertiary/synthliz/chestlights)

/// The plates frame the scutes, drawn over their edge (facing south); from behind only the plates draw.
/datum/body_marking_set/synthliz/plates
	name = "Synth Plates"
	body_marking_list = list(/datum/body_marking/secondary/synthliz/scutes, /datum/body_marking/tertiary/synthliz/plates)

//MOTH

/datum/body_marking_set/moth
	recommended_species = list(SPECIES_MOTH = 1)

/datum/body_marking_set/moth/reddish
	name = "Reddish"
	body_marking_list = list(/datum/body_marking/moth/reddish)

/datum/body_marking_set/moth/royal
	name = "Royal"
	body_marking_list = list(/datum/body_marking/moth/royal)

/datum/body_marking_set/moth/gothic
	name = "Gothic"
	body_marking_list = list(/datum/body_marking/moth/gothic)

/datum/body_marking_set/moth/whitefly
	name = "Whitefly"
	body_marking_list = list(/datum/body_marking/moth/whitefly)

/datum/body_marking_set/moth/burnt_off
	name = "Burnt Off"
	body_marking_list = list(/datum/body_marking/moth/burnt_off)

/datum/body_marking_set/moth/deathhead
	name = "Deathhead"
	body_marking_list = list(/datum/body_marking/moth/deathhead)

/datum/body_marking_set/moth/poison
	name = "Poison"
	body_marking_list = list(/datum/body_marking/moth/poison)

/datum/body_marking_set/moth/ragged
	name = "Ragged"
	body_marking_list = list(/datum/body_marking/moth/ragged)

/datum/body_marking_set/moth/moonfly
	name = "Moonfly"
	body_marking_list = list(/datum/body_marking/moth/moonfly)

/datum/body_marking_set/moth/oakworm
	name = "Oakworm"
	body_marking_list = list(/datum/body_marking/moth/oakworm)

/datum/body_marking_set/moth/jungle
	name = "Jungle"
	body_marking_list = list(/datum/body_marking/moth/jungle)

/datum/body_marking_set/moth/witchwing
	name = "Witchwing"
	body_marking_list = list(/datum/body_marking/moth/witchwing)

/datum/body_marking_set/moth/lovers
	name = "Lovers"
	body_marking_list = list(/datum/body_marking/moth/lovers)

/datum/body_marking_set/moth/lightbearer
	name = "Lightbearer"
	body_marking_list = list(/datum/body_marking/moth/lightbearer)

/datum/body_marking_set/moth/firewatch
	name = "Firewatch"
	body_marking_list = list(/datum/body_marking/moth/firewatch)
