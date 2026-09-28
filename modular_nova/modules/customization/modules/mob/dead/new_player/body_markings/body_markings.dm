//This datum is quite close to the sprite accessory one, containing a bit of copy pasta code
//Those DO NOT have a customizable cases for rendering, or any special stuff, and are meant to be simpler than accessories
//One definition can stand for a whole set of accessories, make sure to set affected bodyparts
/datum/body_marking
	///The icon file the body markign is located in
	var/icon
	///The icon_state of the body marking
	var/icon_state
	///The preview name of the body marking. NEEDS A UNIQUE NAME
	var/name
	/// Where a newly worn marking takes its colour from, one of the MARKING_COLOR_* defines. See seed_color().
	var/color_mode = MARKING_COLOR_FOLLOWS_PRIMARY
	/// The "#rrggbb" a MARKING_COLOR_FIXED_DEFAULT or MARKING_COLOR_LOCKED marking starts in. The following modes ignore it.
	var/default_color
	/// The zones this marking draws on, as bitflags (HEAD, CHEST, ARM_LEFT, ARM_RIGHT, HAND_LEFT, HAND_RIGHT, LEG_RIGHT, LEG_LEFT).
	/// Claim a zone only where the sheet has its art: character setup offers the marking on every zone claimed here.
	var/affected_bodyparts
	/// The leg shapes this marking has art for, MARKING_LEG_* flags. A leg of another shape draws none of it.
	var/leg_shapes = MARKING_LEG_PLANTIGRADE | MARKING_LEG_DIGITIGRADE
	/// The species this marking is meant for, species id -> TRUE, or null for any species. Without mismatched parts character
	/// setup offers and accepts it only for those. A marking in any /datum/body_marking_set has this replaced at init by the
	/// union of those sets' species (derive_body_marking_species()), so a declaration here counts only for a marking in no set.
	var/list/recommended_species = list(SPECIES_MAMMAL = TRUE)
	///Whether the body marking sprite is the same for both sexes or not. Only relevant for chest right now.
	var/gendered = TRUE
	/// Markings sharing a group are alternatives: a zone wears at most one of them. A text token, or null for none. A save
	/// keeps what it held when a group is authored, so a group added after save version 21 needs a migration version of its own.
	var/exclusion_group
	/// Colours character setup suggests beside the colour picker, lowercase "#rrggbb", or null for none. Markings declaring the
	/// same palette share one list.
	var/list/recommended_colors
	/// A limb's request -> the icon state this marking draws for it, or FALSE for nothing, as drawn_state() answered; null
	/// until a limb draws it. Read-only outside this type, where only BODY_MARKING_DRAWN_STATE() reads it.
	var/list/drawn_states

/datum/body_marking/New()
	. = ..()
	if(recommended_species)
		recommended_species = string_assoc_list(recommended_species)
	if(recommended_colors)
		recommended_colors = string_list(recommended_colors)

/**
 * Returns whether a species may wear this marking without mismatched parts: any species when it names none, otherwise only
 * the ones it names. Character setup's choices and actions, and a collection's validate_for_species(), all ask here.
 *
 * Arguments:
 * - species_id: the species' id.
 */
/datum/body_marking/proc/allows_species(species_id)
	return isnull(recommended_species) || !isnull(recommended_species[species_id])

/**
 * Returns the colour this marking starts in when it is added, brought by a preset or reset, by its color_mode: the
 * mutant colour it follows, or its own default_color.
 *
 * Arguments:
 * - features: the character's features, where a following mode reads its mutant colour. May be null.
 * - species: the character's species. No mode reads it yet; a species-dependent mode needs no caller changed.
 *
 * Returns:
 * - string: the colour, as its source holds it. Null when the mutant colour followed is unset, which an entry stores as
 *   black, as it always did.
 */
/datum/body_marking/proc/seed_color(list/features, datum/species/species)
	switch(color_mode)
		if(MARKING_COLOR_FOLLOWS_PRIMARY)
			return features?[FEATURE_MUTANT_COLOR]
		if(MARKING_COLOR_FOLLOWS_SECONDARY)
			return features?[FEATURE_MUTANT_COLOR_TWO]
		if(MARKING_COLOR_FOLLOWS_TERTIARY)
			return features?[FEATURE_MUTANT_COLOR_THREE]
		if(MARKING_COLOR_FIXED_DEFAULT, MARKING_COLOR_LOCKED)
			return default_color
	stack_trace("Body marking [name] ([type]) has an unknown color_mode: [color_mode]")
	return COLOR_WHITE

/**
 * Returns the icon state this marking draws on one zone of a limb, or null where it draws nothing there: a leg of a shape
 * leg_shapes leaves out. The limb renderer draws every marking appearance from this, through drawn_state(), and character
 * setup's picker and the custom sprite editor ask it too, so all of them read the same art. The sheet can still lack the
 * state, as it does on a zone a save holds but the marking no longer claims.
 *
 * Arguments:
 * - zone: the marking zone drawn on: a limb's body zone, or an arm's aux zone for its hand.
 * - digitigrade: TRUE for a digitigrade limb.
 * - limb_gender: the chest art a gendered marking draws, "m" or "f": a dimorphic chest's limb_gender, "m" on any other chest.
 *
 * Returns:
 * - string: the icon state, or null.
 */
/datum/body_marking/proc/zone_icon_state(zone, digitigrade = FALSE, limb_gender = "m")
	if((zone == BODY_ZONE_L_LEG || zone == BODY_ZONE_R_LEG) && !(leg_shapes & (digitigrade ? MARKING_LEG_DIGITIGRADE : MARKING_LEG_PLANTIGRADE)))
		return null
	return "[icon_state]_[digitigrade ? "digitigrade_" : ""][zone][zone == BODY_ZONE_CHEST && gendered ? "_[limb_gender]" : ""]"

/**
 * Returns the icon state the limb renderer draws for this marking on one zone of a limb: zone_icon_state()'s state where the
 * sheet has it, else FALSE, so a missing state draws nothing rather than the sheet's default state. It is missing on a zone
 * a save holds but the marking no longer claims, which is no bug, so this stays silent. The answer is kept in drawn_states
 * under the limb's request, where BODY_MARKING_DRAWN_STATE() reads it again with no proc call.
 *
 * Arguments:
 * - request: the key of the limb's zone, leg shape and chest art, which the renderer builds once per limb.
 * - zone, digitigrade, limb_gender: as zone_icon_state() takes them.
 *
 * Returns:
 * - string: the icon state, or FALSE.
 */
/datum/body_marking/proc/drawn_state(request, zone, digitigrade = FALSE, limb_gender = "m")
	var/state = zone_icon_state(zone, digitigrade, limb_gender)
	. = state && icon_exists(icon, state) ? state : FALSE
	LAZYSET(drawn_states, request, .)

/// Markings of no family, on the other_markings sheet unless they name another. Those with a colour of their own start in it
/// (MARKING_COLOR_FIXED_DEFAULT); the rest follow the primary mutant colour.
/datum/body_marking/other
	icon = 'modular_nova/master_files/icons/mob/body_markings/other_markings.dmi'
	recommended_species = null

/datum/body_marking/other/eyebags
	name = "Eye Bags"
	icon = 'icons/mob/human/species/misc/bodypart_overlay_simple.dmi'
	icon_state = "bags"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#484848"
	affected_bodyparts = HEAD

/// Draws tg's own eye bags, the state the All Nighter quirk draws, which is named for no zone.
/datum/body_marking/other/eyebags/zone_icon_state(zone, digitigrade = FALSE, limb_gender = "m")
	return zone == BODY_ZONE_HEAD ? icon_state : ..()

/datum/body_marking/other/drake_bone
	name = "Drake Bone"
	icon_state = "drakebone"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = CHEST | HAND_LEFT | HAND_RIGHT
	gendered = FALSE

/datum/body_marking/other/tonage
	name = "Body Tonage"
	icon_state = "tonage"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#555555"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/other/belly_slim_toned
	name = "Belly Slim (Alt) + Tonage"
	icon_state = "bellyslimtoned"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#555555"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/other/flushed_cheeks
	name = "Flushed Cheeks"
	icon_state = "flushed_cheeks"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/cyclops
	name = "Cyclopean Eye"
	icon_state = "cyclops"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/blank_face
	name = "Blank round face (use with monster mouth)"
	icon_state = "blankface"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/blank_face2
	name = "Blank Round Face, Alt"
	icon_state = "blankface2"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/blank_face3
	name = "Blank Round Face, Flat"
	icon_state = "blankface3"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/monster_mouth
	name = "Monster Mouth"
	icon_state = "monster"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/monster_mouth_white
	name = "Monster Mouth (White)"
	icon_state = "monster_white"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/monster_mouth_white2
	name = "Monster Mouth (White, eye-compatible)"
	icon_state = "monster_white2"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD
//you're welcome -- iska

/datum/body_marking/other/monster_mouth2
	name = "Monster Mouth 2"
	icon_state = "monster2"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/nose_blemish
	name = "Nose Blemish"
	icon_state = "nose_blemish"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/brows
	name = "Brows"
	icon_state = "brows"
	affected_bodyparts = HEAD

/datum/body_marking/other/ears
	name = "Ears"
	icon_state = "ears"
	affected_bodyparts = HEAD

/datum/body_marking/other/insect_antennae
	name = "Insect Antennae"
	icon_state = "insect_antennae"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/eyeliner
	name = "Eyeliner"
	icon_state = "eyeliner"
	affected_bodyparts = HEAD

/datum/body_marking/other/clowncross
	name = "Clown Cross"
	icon_state = "clowncross"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FFFF00"
	affected_bodyparts = HEAD

/datum/body_marking/other/clownlips
	name = "Clown Lips"
	icon_state = "clownlips"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0033"
	affected_bodyparts = HEAD

/datum/body_marking/other/topscars
	name = "Top Surgery Scars"
	icon_state = "topscars"
	affected_bodyparts = CHEST

/datum/body_marking/other/weight
	name = "Body Weight"
	icon_state = "weight"
	affected_bodyparts = CHEST

/datum/body_marking/other/weight2
	name = "Body Weight (Greyscale)"
	icon_state = "weight2"
	affected_bodyparts = CHEST

/datum/body_marking/other/pilot
	name = "Pilot"
	icon_state = "pilot"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT

/datum/body_marking/other/pilot_jaw
	name = "Pilot Jaw"
	icon_state = "pilot_jaw"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#CCCCCC"
	affected_bodyparts = HEAD

/datum/body_marking/other/drake_eyes
	name = "Drake Eyes"
	icon_state = "drakeeyes"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/big_ol_eyes
	name = "Large Eyes"
	icon_state = "bigoleyes"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/three_eyes
	name = "Three Eyes"
	icon_state = "3eyes"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/four_eyes
	name = "Four Eyes"
	icon_state = "4eyes"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/sclera
	name = "Sclera"
	icon_state = "sclera"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/anime_inner
	name = "Anime Eyes (Inner)"
	icon_state = "anime_inner"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/anime_outer
	name = "Anime Eyes (Outer)"
	icon_state = "anime_outer"
	color_mode = MARKING_COLOR_FIXED_DEFAULT
	default_color = "#FF0000"
	affected_bodyparts = HEAD

/datum/body_marking/other/claws
	name = "Claw Tips"
	icon_state = "claws"
	affected_bodyparts = HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/other/harpy_upper
	name = "Harpy Upper Legs"
	icon_state = "harpy_upper"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/other/harpy_lower
	name = "Harpy Lower Legs"
	icon_state = "harpy_lower"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/other/harpy_claws
	name = "Harpy Claws"
	icon_state = "harpy_claws"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/other/critter_legs
	name = "Critter Legs"
	icon_state = "critterleg"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	gendered = FALSE


/datum/body_marking/other/splotches
	name = "Splotches"
	icon_state = "splotches"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/other/splotcheswap
	name = "Splotches Swapped"
	icon_state = "splotcheswap"
	affected_bodyparts = HEAD

/datum/body_marking/other/bands
	name = "Color Bands"
	icon_state = "bands"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/other/chitin
	name = "Chitin"
	icon_state = "chitin"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/other/bands_foot
	name = "Color Bands (Foot)"
	icon_state = "bands_foot"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/other/anklet
	name = "Anklet"
	icon_state = "anklet"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/other/legband
	name = "Leg Band"
	icon_state = "legband"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/other/protogenlegs
	name = "Protogen Leg - Digitigrade"
	icon_state = "protogen"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT
	leg_shapes = MARKING_LEG_DIGITIGRADE

/datum/body_marking/other/protogenarms
	name = "Protogen Arm"
	icon_state = "protogen"
	affected_bodyparts = ARM_RIGHT | ARM_LEFT

/datum/body_marking/other/protogenchest
	name = "Protogen Chest"
	icon_state = "protogen"
	affected_bodyparts = CHEST

/datum/body_marking/other/jackal_fur
	name = "Jackal Back Fur"
	icon_state = "jackalfur"
	affected_bodyparts = CHEST | ARM_RIGHT | ARM_LEFT
	gendered = FALSE

/datum/body_marking/other/jackal_back
	name = "Jackal Back Fur Accents"
	icon_state = "jackalback"
	affected_bodyparts = CHEST | ARM_RIGHT | ARM_LEFT
	gendered = FALSE

/datum/body_marking/other/sixnips
	name = "Six Nips"
	icon_state = "nips"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/other/chemlight
	name = "Bands and Stripes"
	icon_state = "chemlight"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/other/back_stripe
	name = "Back Stripe"
	icon_state = "backstripe"
	affected_bodyparts = HEAD | CHEST
	gendered = FALSE

/datum/body_marking/secondary
	icon = 'modular_nova/master_files/icons/mob/body_markings/secondary_markings.dmi'
	color_mode = MARKING_COLOR_FOLLOWS_SECONDARY

/datum/body_marking/secondary/teshari
	name = "Teshari"
	icon_state = "teshari"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT
	gendered = FALSE

/datum/body_marking/secondary/teshari_plain
	name = "Teshari Plain"
	icon_state = "teshari_plain"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No head or hand art.
	gendered = FALSE
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_coat
	name = "Teshari Coat"
	icon_state = "teshari_coat"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No hand art.
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_underfluff
	name = "Teshari Underfluff"
	icon_state = "teshari_underfluff"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_short
	name = "Teshari Short"
	icon_state = "teshari_short"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No head, chest or hand art.
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_feathers_male
	name = "Teshari Feathers (Male)"
	icon_state = "teshari_feathers_male"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No hand art.
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_feathers_female
	name = "Teshari Feathers (Female)"
	icon_state = "teshari_feathers_female"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No hand art.
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/teshari_lashes
	name = "Teshari Lashes"
	icon_state = "teshari_lashes"
	recommended_species = list(SPECIES_TESHARI = 1)
	affected_bodyparts = HEAD

/datum/body_marking/secondary/tajaran
	name = "Tajaran"
	icon_state = "tajaran"
	affected_bodyparts = HEAD | CHEST //The legs were literally one pixel so I removed them

/datum/body_marking/secondary/sergal
	name = "Sergal"
	icon_state = "sergal"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/husky
	name = "Husky"
	icon_state = "husky"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/fennec
	name = "Fennec"
	icon_state = "fennec"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/redpanda
	name = "Red Panda"
	icon_state = "redpanda"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/dalmatian
	name = "Dalmatian"
	icon_state = "dalmation"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/shepherd
	name = "Shepherd"
	icon_state = "shepherd"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No hand art.

/datum/body_marking/secondary/wolf
	name = "Wolf"
	icon_state = "wolf"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/fox
	name = "Fox"
	icon_state = "fox"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/raccoon
	name = "Raccoon"
	icon_state = "raccoon"
	affected_bodyparts = HEAD | CHEST | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/bovine
	name = "Bovine"
	icon_state = "bovine"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/possum
	name = "Possum"
	icon_state = "possum"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/corgi
	name = "Corgi"
	icon_state = "corgi"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/leopard1
	name = "Leopard"
	icon_state = "leopard1"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE
	leg_shapes = MARKING_LEG_DIGITIGRADE

/datum/body_marking/secondary/leopard2
	name = "Leopard (alt)"
	icon_state = "leopard2"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/secondary/skunk
	name = "Skunk"
	icon_state = "skunk"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/panther
	name = "Panther"
	icon_state = "panther"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/tiger
	name = "Tiger Spot"
	icon_state = "tiger"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT
	leg_shapes = MARKING_LEG_PLANTIGRADE

/datum/body_marking/secondary/otter
	name = "Otter"
	icon_state = "otter"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/otie
	name = "Otie"
	icon_state = "otie"
	affected_bodyparts = HEAD | CHEST | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/sabresune
	name = "Sabresune"
	icon_state = "sabresune"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/orca
	name = "Orca"
	icon_state = "orca"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/hawk
	name = "Hawk"
	icon_state = "hawk"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/corvid
	name = "Corvid"
	icon_state = "corvid"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/eevee
	name = "Eevee"
	icon_state = "eevee"
	affected_bodyparts = HEAD | CHEST
	gendered = FALSE

/datum/body_marking/secondary/shark
	name = "Shark"
	icon_state = "shark"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/deer
	name = "Deer"
	icon_state = "deer"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/hyena
	name = "Hyena"
	icon_state = "hyena"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/dog
	name = "Dog"
	icon_state = "dog"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/bat
	name = "Bat"
	icon_state = "bat"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/floof
	name = "Floof"
	icon_state = "floof"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/secondary/rat
	name = "Rat Paw"
	icon_state = "rat"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/scolipede
	name = "Scolipede"
	icon_state = "scolipede"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/secondary/guilmon
	name = "Guilmon"
	icon_state = "guilmon"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE
	leg_shapes = MARKING_LEG_DIGITIGRADE

/datum/body_marking/secondary/xeno
	name = "Xeno"
	icon_state = "xeno"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE
	recommended_species = list(SPECIES_XENO = 1)

/datum/body_marking/secondary/datashark
	name = "Datashark"
	icon_state = "datashark"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/secondary/belly
	name = "Belly"
	icon_state = "belly"
	affected_bodyparts = CHEST

/datum/body_marking/secondary/bellyslim
	name = "Belly Slim"
	icon_state = "bellyslim"
	affected_bodyparts = HEAD | CHEST | LEG_RIGHT | LEG_LEFT
	leg_shapes = MARKING_LEG_DIGITIGRADE

/datum/body_marking/secondary/bellyslimalt
	name = "Belly Slim Alternative"
	icon_state = "bellyslim_alt"
	affected_bodyparts = CHEST

/datum/body_marking/secondary/bellyandbutt
	name = "Belly and Butt"
	icon_state = "bellyandbutt"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/secondary/butt
	name = "Butt"
	icon_state = "butt"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/secondary/handsfeet
	name = "Hands Feet"
	icon_state = "handsfeet"
	affected_bodyparts = HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/frog
	name = "Frog"
	icon_state = "frog"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/bee
	name = "Bee"
	icon_state = "bee"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT // No hand art.
	gendered = FALSE

/datum/body_marking/secondary/gradient
	name = "Gradient"
	icon_state = "gradient"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/harlequin
	name = "Harlequin"
	icon_state = "harlequin"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | HAND_LEFT | LEG_LEFT

/datum/body_marking/secondary/harlequin_reversed
	name = "Harlequin Reversed"
	icon_state = "harlequin_reversed"
	affected_bodyparts = HEAD | CHEST | ARM_RIGHT | HAND_RIGHT | LEG_RIGHT

/datum/body_marking/secondary/plain
	name = "Plain"
	icon_state = "plain"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/upper_limb
	name = "Upper Limb"
	icon_state = "upper_limb"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/lower_limb
	name = "Lower Limb"
	icon_state = "lower_limb"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/secondary/insectoid
	name = "Insectoid"
	icon_state = "insect"
	affected_bodyparts = CHEST

/datum/body_marking/secondary/bellyoutline
	name = "Belly Outline"
	icon_state = "chembelly_trim"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/tertiary
	icon = 'modular_nova/master_files/icons/mob/body_markings/tertiary_markings.dmi'
	color_mode = MARKING_COLOR_FOLLOWS_TERTIARY

/datum/body_marking/tertiary/redpanda
	name = "Red Panda Head"
	icon_state = "redpanda"
	affected_bodyparts = HEAD

/datum/body_marking/tertiary/shepherd
	name = "Shepherd Spot"
	icon_state = "shepherd"
	affected_bodyparts = HEAD | CHEST

/datum/body_marking/tertiary/wolf
	name = "Wolf Spot"
	icon_state = "wolf"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/fox
	name = "Fox Sock"
	icon_state = "fox"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/goat
	name = "Goat Hoof"
	icon_state = "goat"
	affected_bodyparts = HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/raccoon
	name = "Raccoon Spot"
	icon_state = "raccoon"
	affected_bodyparts = HEAD | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/bovine
	name = "Bovine Spot"
	icon_state = "bovine"
	affected_bodyparts = HEAD | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/possum
	name = "Possum Sock"
	icon_state = "possum"
	affected_bodyparts = HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/tiger
	name = "Tiger Stripe"
	icon_state = "tiger"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/otter
	name = "Otter Head"
	icon_state = "otter"
	affected_bodyparts = HEAD

/datum/body_marking/tertiary/otie
	name = "Otie Spot"
	icon_state = "otie"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/hawk
	name = "Hawk Talon"
	icon_state = "hawk"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/corvid
	name = "Corvid Talon"
	icon_state = "corvid"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/deer
	name = "Deer Hoof"
	icon_state = "deer"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT // No hand art.

/datum/body_marking/tertiary/hyena
	name = "Hyena Side"
	icon_state = "hyena"
	affected_bodyparts = HEAD | CHEST
	gendered = FALSE

/datum/body_marking/tertiary/dog
	name = "Dog Spot"
	icon_state = "dog"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/bat
	name = "Bat Mark"
	icon_state = "bat"
	affected_bodyparts = CHEST

/datum/body_marking/tertiary/floofer
	name = "Floofer Sock"
	icon_state = "floofer"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT | HAND_LEFT | HAND_RIGHT

/datum/body_marking/tertiary/rat
	name = "Rat Spot"
	icon_state = "rat"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tertiary/sloth
	name = "Sloth Head"
	icon_state = "sloth"
	affected_bodyparts = HEAD

/datum/body_marking/tertiary/scolipede
	name = "Scolipede Spikes"
	icon_state = "scolipede"
	affected_bodyparts = CHEST
	gendered = FALSE

/datum/body_marking/tertiary/guilmon
	name = "Guilmon Mark"
	icon_state = "guilmon"
	affected_bodyparts = HEAD | CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = FALSE

/datum/body_marking/tertiary/xeno
	name = "Xeno Head"
	icon_state = "xeno"
	affected_bodyparts = HEAD
	recommended_species = list(SPECIES_XENO = 1)

/datum/body_marking/tertiary/dtiger
	name = "Dark Tiger Body"
	icon_state = "dtiger"
	affected_bodyparts = CHEST

/datum/body_marking/tertiary/ltiger
	name = "Light Tiger Body"
	icon_state = "ltiger"
	affected_bodyparts = CHEST

/datum/body_marking/tertiary/lbelly
	name = "Light Belly"
	icon_state = "lbelly"
	affected_bodyparts = CHEST

/datum/body_marking/tertiary/insectoid
	name = "Insectoid Trim"
	icon_state = "insect_trim"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | LEG_LEFT | LEG_RIGHT
	leg_shapes = MARKING_LEG_DIGITIGRADE

/datum/body_marking/tertiary/chemlight
	name = "Bands and Stripes (Alt)"
	icon_state = "chem_light"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT

/// Every marking drawn from the tattoo sheet. Ink is always ink: it starts slightly faded and can't be recoloured.
/datum/body_marking/tattoo
	icon = 'modular_nova/master_files/icons/mob/body_markings/tattoo_markings.dmi'
	recommended_species = null
	color_mode = MARKING_COLOR_LOCKED
	default_color = "#112222" //slightly faded ink.
	gendered = FALSE

/datum/body_marking/tattoo/heart
	name = "Tattoo - Heart"
	icon_state = "tat_heart"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT

/datum/body_marking/tattoo/heart_groin
	name = "Tattoo - Heart (Groin)"
	icon_state = "tat_heart_groin"
	affected_bodyparts = CHEST

/datum/body_marking/tattoo/hive
	name = "Tattoo - Hive"
	icon_state = "tat_hive"
	affected_bodyparts = CHEST
	gendered = TRUE

/datum/body_marking/tattoo/nightling
	name = "Tattoo - Nightling"
	icon_state = "tat_nightling"
	affected_bodyparts = CHEST

/datum/body_marking/tattoo/circuit
	name = "Tattoo - Circuit"
	icon_state = "tat_campbell"
	affected_bodyparts = ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tattoo/silverburgh //dunno what this is.
	name = "Tattoo - Silverburgh"
	icon_state = "tat_silverburgh"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/tattoo/tiger
	name = "Tattoo - Tiger"
	icon_state = "tat_tiger"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | HAND_LEFT | HAND_RIGHT | LEG_RIGHT | LEG_LEFT
	gendered = TRUE

/datum/body_marking/tattoo/tiger_groin
	name = "Tattoo - Tiger (Groin)"
	icon_state = "tat_tiger_groin"
	affected_bodyparts = CHEST

/datum/body_marking/tattoo/tiger_foot
	name = "Tattoo - Tiger (Foot)"
	icon_state = "tat_tiger_foot"
	affected_bodyparts = LEG_RIGHT | LEG_LEFT

/datum/body_marking/tattoo/infinity
	name = "Tattoo - Infinity"
	icon_state = "tat_infinity"
	affected_bodyparts = CHEST | ARM_LEFT | ARM_RIGHT | LEG_RIGHT | LEG_LEFT

/datum/body_marking/tattoo/butterfly
	name = "Tattoo - Butterfly"
	icon_state = "tat_butterfly"
	affected_bodyparts = CHEST
