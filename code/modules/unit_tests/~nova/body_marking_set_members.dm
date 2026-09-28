/**
 * Every named marking set's members as body_marking_sets.dm named them before it listed typepaths, by set type, or null for a
 * set without markings. Kept here, and nowhere in the game, as the reference the typepath members are checked against. Rat Paw,
 * merged into Hands Feet at save version 22, reads as Hands Feet.
 */
/proc/body_marking_set_members_by_name()
	return list(
		/datum/body_marking_set/none = null,
		/datum/body_marking_set/tajaran = list("Tajaran"),
		/datum/body_marking_set/fox = list("Fox", "Fox Sock"),
		/datum/body_marking_set/sergal = list("Sergal"),
		/datum/body_marking_set/husky = list("Husky"),
		/datum/body_marking_set/fennec = list("Fennec"),
		/datum/body_marking_set/redpanda = list("Red Panda", "Red Panda Head"),
		/datum/body_marking_set/dalmatian = list("Dalmatian"),
		/datum/body_marking_set/shepherd = list("Shepherd", "Shepherd Spot"),
		/datum/body_marking_set/wolf = list("Wolf", "Wolf Spot"),
		/datum/body_marking_set/raccoon = list("Raccoon"),
		/datum/body_marking_set/bovine = list("Bovine", "Bovine Spot"),
		/datum/body_marking_set/possum = list("Possum"),
		/datum/body_marking_set/corgi = list("Corgi"),
		/datum/body_marking_set/skunk = list("Skunk"),
		/datum/body_marking_set/panther = list("Panther"),
		/datum/body_marking_set/tiger = list("Tiger Spot", "Tiger Stripe"),
		/datum/body_marking_set/otter = list("Otter", "Otter Head"),
		/datum/body_marking_set/otie = list("Otie", "Otie Spot"),
		/datum/body_marking_set/sabresune = list("Sabresune"),
		/datum/body_marking_set/orca = list("Orca"),
		/datum/body_marking_set/hawk = list("Hawk", "Hawk Talon"),
		/datum/body_marking_set/corvid = list("Corvid", "Corvid Talon"),
		/datum/body_marking_set/eevee = list("Eevee"),
		/datum/body_marking_set/deer = list("Deer", "Deer Hoof"),
		/datum/body_marking_set/hyena = list("Hyena", "Hyena Side"),
		/datum/body_marking_set/dog = list("Dog", "Dog Spot"),
		/datum/body_marking_set/bat = list("Bat Mark", "Bat"),
		/datum/body_marking_set/goat = list("Goat Hoof"),
		/datum/body_marking_set/floof = list("Floof"),
		/datum/body_marking_set/floofer = list("Floof", "Floofer Sock"),
		/datum/body_marking_set/rat = list("Hands Feet", "Rat Spot"),
		/datum/body_marking_set/sloth = list("Hands Feet", "Sloth Head"),
		/datum/body_marking_set/scolipede = list("Scolipede", "Scolipede Spikes"),
		/datum/body_marking_set/guilmon = list("Guilmon", "Guilmon Mark"),
		/datum/body_marking_set/xeno = list("Xeno", "Xeno Head"),
		/datum/body_marking_set/datashark = list("Datashark"),
		/datum/body_marking_set/shark = list("Shark"),
		/datum/body_marking_set/belly = list("Belly"),
		/datum/body_marking_set/belly_slim = list("Belly Slim"),
		/datum/body_marking_set/hands_feet = list("Hands Feet"),
		/datum/body_marking_set/frog = list("Frog"),
		/datum/body_marking_set/bee = list("Bee"),
		/datum/body_marking_set/gradient = list("Gradient"),
		/datum/body_marking_set/harlequin = list("Harlequin"),
		/datum/body_marking_set/harlequin_reversed = list("Harlequin Reversed"),
		/datum/body_marking_set/plain = list("Plain"),
		/datum/body_marking_set/splotches = list("Splotches"),
		/datum/body_marking_set/chitin = list("Chitin"),
		/datum/body_marking_set/akula/akula = list("Akula", "Akula Highlight"),
		/datum/body_marking_set/vox/vox = list("Vox Talon"),
		/datum/body_marking_set/vox/vox_tiger = list("Vox Talon", "Vox Tiger Tattoo"),
		/datum/body_marking_set/vox/vox_hive = list("Vox Talon", "Vox Hive Tattoo"),
		/datum/body_marking_set/vox/vox_nightling = list("Vox Talon", "Vox Nightling Tattoo"),
		/datum/body_marking_set/vox/vox_heart = list("Vox Talon", "Vox Heart Tattoo"),
		/datum/body_marking_set/synthliz/scutes = list("Synth Scutes"),
		/datum/body_marking_set/synthliz/pecs = list("Synth Pecs"),
		/datum/body_marking_set/synthliz/pecs_light = list("Synth Pecs", "Synth Collar Lights"),
		/datum/body_marking_set/moth/reddish = list("Reddish"),
		/datum/body_marking_set/moth/royal = list("Royal"),
		/datum/body_marking_set/moth/gothic = list("Gothic"),
		/datum/body_marking_set/moth/whitefly = list("Whitefly"),
		/datum/body_marking_set/moth/burnt_off = list("Burnt Off"),
		/datum/body_marking_set/moth/deathhead = list("Deathhead"),
		/datum/body_marking_set/moth/poison = list("Poison"),
		/datum/body_marking_set/moth/ragged = list("Ragged"),
		/datum/body_marking_set/moth/moonfly = list("Moonfly"),
		/datum/body_marking_set/moth/oakworm = list("Oakworm"),
		/datum/body_marking_set/moth/jungle = list("Jungle"),
		/datum/body_marking_set/moth/witchwing = list("Witchwing"),
		/datum/body_marking_set/moth/lovers = list("Lovers"),
		/datum/body_marking_set/moth/lightbearer = list("Lightbearer"),
		/datum/body_marking_set/moth/firewatch = list("Firewatch"),
	)

/// Every marking set lists its members by typepath, and each is the marking the set named before, in the same order.
/datum/unit_test/body_marking_set_members

/datum/unit_test/body_marking_set_members/Run()
	// The typepath map holds every named marking, the same instances the name map holds, in the same order.
	var/list/by_name = list()
	for(var/name, marking_datum in GLOB.body_markings)
		by_name += marking_datum
	var/list/by_type = list()
	for(var/marking_type, marking_datum in GLOB.body_markings_by_type)
		var/datum/body_marking/marking = marking_datum
		TEST_ASSERT_EQUAL(marking.type, marking_type, "The typepath map must key each marking by its own type")
		by_type += marking
	TEST_ASSERT(length(by_type), "The typepath map must hold the markings")
	TEST_ASSERT_EQUAL(length(by_type), length(by_name), "The typepath map must hold every named marking")
	for(var/index in 1 to length(by_name))
		TEST_ASSERT(by_type[index] == by_name[index], "The typepath map must hold the name map's markings in its order, not [by_type[index]] at [index]")

	var/list/reference = body_marking_set_members_by_name()
	TEST_ASSERT_EQUAL(length(GLOB.body_marking_sets_by_type), length(reference), "Every named marking set must have a reference entry")
	for(var/set_type, set_datum in GLOB.body_marking_sets_by_type)
		var/datum/body_marking_set/marking_set = set_datum
		TEST_ASSERT(set_type in reference, "[set_type] has no reference entry")
		var/list/names
		for(var/marking_type in marking_set.body_marking_list)
			var/datum/body_marking/marking = GLOB.body_markings_by_type[marking_type]
			TEST_ASSERT(marking, "[set_type] lists [marking_type], which no marking is registered under")
			LAZYADD(names, marking.name)
		TEST_ASSERT_EQUAL(json_encode(names), json_encode(reference[set_type]), "[set_type] must hold the markings it named before, in the same order")
