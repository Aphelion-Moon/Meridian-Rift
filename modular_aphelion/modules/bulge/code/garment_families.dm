// Which bulge each garment draws, as vars on the garment types. Edit by hand: one block per type that differs
// from its parent; subtypes inherit the rest. Generated once from mal's reviewed selections. The bulge_manifest unit
// test pins what every garment resolves to (code/modules/unit_tests/~nova/bulge_manifest.txt): an edit here, or a
// new subtype of a listed garment from a merge, fails it until someone has reviewed the change and updated the file.
//
// To add a garment, give its type a block naming its family (bulge_family, a /datum/bulge_family typepath: for a
// skirt the style mal picked; for a revealing skirt whose hem is not the common one, its hem's subtype) and only
// the other values it needs: bulge_printed when its own print should carry onto the bulge, bulge_cloth_layer when
// its cloth is not the first GAGS layer, bulge_suit_rule for a suit that leaves the crotch clear. A subtype of a
// garment listed here bulges like its parent unless it has a block of its own, so a new subtype of a listed
// garment needs either a review or an explicit "nothing" block (bulge_family = /datum/bulge_family/none). A value
// that looks redundant may undo a parent's: every such reset says so in a comment on its line.

/obj/item/clothing
	/// The family this garment bulges with when it is the cover (/datum/bulge_family/none: never). A suit with a
	/// family is itself the cover in the states its bulge_suit_rule admits.
	var/bulge_family = /datum/bulge_family/none
	/// Worn over the suit slot: the worn states and legs (BULGE_SUIT_*) in which the garment was reviewed and does
	/// not hide the bulge. Only the type's own unmodified appearance counts; every other state, legs or
	/// appearance hides it.
	var/bulge_suit_rule = NONE

/obj/item/clothing/under
	/// Drawn from the garment's own print (mal's printed selections) instead of the adaptive palette, while the
	/// garment keeps its default appearance.
	var/bulge_printed = FALSE
	/// Which greyscale layer of a GAGS garment is the cloth the adaptive colour is sampled from.
	var/bulge_cloth_layer = 1

/datum/sprite_accessory/clothing
	/// The family this underwear or undershirt bulges with when it is the cover (/datum/bulge_family/none: never).
	var/bulge_family = /datum/bulge_family/none
	/// Drawn from the garment's own print instead of the adaptive palette.
	var/bulge_printed = FALSE

// ===== Underwear and undershirts =====================================================================================

// Boxers: boxers, midway and the boyshorts.

/datum/sprite_accessory/clothing/underwear/boyshorts
	bulge_family = /datum/bulge_family/boxers

/datum/sprite_accessory/clothing/underwear/boyshorts_alt
	bulge_family = /datum/bulge_family/boxers

/datum/sprite_accessory/clothing/underwear/male_boxers
	bulge_family = /datum/bulge_family/boxers

/datum/sprite_accessory/clothing/underwear/male_midway
	bulge_family = /datum/bulge_family/boxers

// Loose boxers: striped, hearts, commie, freedom, UK and bee.

/datum/sprite_accessory/clothing/underwear/male_bee
	bulge_family = /datum/bulge_family/loose_boxers
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/male_commie
	bulge_family = /datum/bulge_family/loose_boxers
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/male_hearts
	bulge_family = /datum/bulge_family/loose_boxers/hearts
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/male_stripe
	bulge_family = /datum/bulge_family/loose_boxers

/datum/sprite_accessory/clothing/underwear/male_uk
	bulge_family = /datum/bulge_family/loose_boxers
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/male_usastripe
	bulge_family = /datum/bulge_family/loose_boxers
	bulge_printed = TRUE

// Briefs: a cut that ends at the groin. Briefs, panties, bikinis, swimsuits, leotards, bodysuits and bunny suits.

/datum/sprite_accessory/clothing/undershirt/nova/corset
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/undershirt/nova/leotard
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/cow
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/female_beekini
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/female_commie
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/female_kinky
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/female_usastripe
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/fishnet_lower
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/fishnet_lower/alt
	bulge_printed = FALSE // Not printed, though /datum/sprite_accessory/clothing/underwear/fishnet_lower is.

/datum/sprite_accessory/clothing/underwear/latex
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/lizared
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/male_briefs
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_basic
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_neko
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_slim
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_swimsuit
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_thin
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/panties_uk
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/striped_panties
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/swimsuit
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/swimsuit_onepiece
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/swimsuit_red
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/swimsuit_strapless_onepiece
	bulge_family = /datum/bulge_family/briefs

/datum/sprite_accessory/clothing/underwear/swimsuit_stripe
	bulge_family = /datum/bulge_family/briefs

// Jockstrap: a pouch or thong cut. Jockstraps, thongs, the mankini and the tearaway attire.

/datum/sprite_accessory/clothing/underwear/male_kinky
	bulge_family = /datum/bulge_family/jockstrap

/datum/sprite_accessory/clothing/underwear/male_mankini
	bulge_family = /datum/bulge_family/jockstrap

/datum/sprite_accessory/clothing/underwear/thong
	bulge_family = /datum/bulge_family/jockstrap

/datum/sprite_accessory/clothing/underwear/thong_babydoll
	bulge_family = /datum/bulge_family/jockstrap

/datum/sprite_accessory/clothing/underwear/thong_cheetah
	bulge_family = /datum/bulge_family/jockstrap
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/thong_cow
	bulge_family = /datum/bulge_family/jockstrap
	bulge_printed = TRUE

/datum/sprite_accessory/clothing/underwear/thong_zebra
	bulge_family = /datum/bulge_family/jockstrap
	bulge_printed = TRUE

// Long johns: skin-tight legs. Long johns, wetsuits, skinsuits, catsuits and yoga pants.

/datum/sprite_accessory/clothing/underwear/male_longjohns
	bulge_family = /datum/bulge_family/long_johns

// Colourable loincloths: the flap lifts when hard.

/datum/sprite_accessory/clothing/underwear/loincloth
	bulge_family = /datum/bulge_family/colourable_loincloth

/datum/sprite_accessory/clothing/underwear/loincloth_alt
	bulge_family = /datum/bulge_family/colourable_loincloth/short

// ===== Uniforms ======================================================================================================

// Briefs: a cut that ends at the groin. Briefs, panties, bikinis, swimsuits, leotards, bodysuits and costume
// bunny suits.

/obj/item/clothing/under/bodysuit_koruu
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/bwake
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/costume/bunnylewd
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/costume/nova/christmas/croptop
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/obj/item/clothing/under/costume/playbunny/british
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/obj/item/clothing/under/costume/playbunny/centcom
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/obj/item/clothing/under/costume/playbunny/communist
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/costume/playbunny/custom_playbunny
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/costume/playbunny/greyscale
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE
	bulge_cloth_layer = 4

/obj/item/clothing/under/costume/playbunny/magician
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/obj/item/clothing/under/costume/playbunny/usa
	bulge_family = /datum/bulge_family/briefs
	bulge_printed = TRUE

/obj/item/clothing/under/mikubikini
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/pants/half_leotard_cosmiclaer
	bulge_family = /datum/bulge_family/briefs

/obj/item/clothing/under/syndicate/syndibunny
	bulge_family = /datum/bulge_family/briefs

// Jockstrap: a pouch or thong cut. Jockstraps, thongs, the mankini and the tearaway attire.

/obj/item/clothing/under/tearaway_garments
	bulge_family = /datum/bulge_family/jockstrap
	bulge_cloth_layer = 2

// Jeans: denim trousers and jean shorts (denim finish), and woven trousers worn on their own.

/obj/item/clothing/under/pants/camo
	bulge_family = /datum/bulge_family/jeans
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/pants/jeans
	bulge_family = /datum/bulge_family/jeans
	bulge_cloth_layer = 3

/obj/item/clothing/under/pants/nova/jeans_ripped
	bulge_family = /datum/bulge_family/jeans
	bulge_cloth_layer = 3

/obj/item/clothing/under/pants/nova/vicvest
	bulge_family = /datum/bulge_family/jeans
	bulge_cloth_layer = 2

/obj/item/clothing/under/pants/skyy
	bulge_family = /datum/bulge_family/jeans
	bulge_printed = TRUE

/obj/item/clothing/under/pants/slacks
	bulge_family = /datum/bulge_family/jeans
	bulge_cloth_layer = 3

/obj/item/clothing/under/rank/engineering/engineer/nova/trouser
	bulge_family = /datum/bulge_family/jeans

/obj/item/clothing/under/rank/security/nova/trousers
	bulge_family = /datum/bulge_family/jeans
	bulge_printed = TRUE

/obj/item/clothing/under/shorts/jeanshorts
	bulge_family = /datum/bulge_family/jeans

/obj/item/clothing/under/syndicate/rus_army
	bulge_family = /datum/bulge_family/jeans
	bulge_printed = TRUE

/obj/item/clothing/under/techpants
	bulge_family = /datum/bulge_family/jeans

// Long johns: skin-tight legs. Long johns, wetsuits, skinsuits, catsuits, yoga pants and the job bunny suits
// (mal, 2026-10-08).

/obj/item/clothing/under/akula_wetsuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/misc/latex_catsuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/misc/nova/modskin
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/pants/nova/yoga
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/captain/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/cargo/bitrunner/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/cargo/cargo_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/cargo/mailman_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/cargo/miner/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/cargo/quartermaster_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/bartender_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/chaplain_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/clown/clown_bunnysuit
	bulge_family = /datum/bulge_family/long_johns
	bulge_printed = FALSE // A reset: its parent is printed.

/obj/item/clothing/under/rank/civilian/cook_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/curator_bunnysuit_green
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/curator_bunnysuit_red
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/curator_bunnysuit_teal
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/hop_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/hydroponics/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/janitor/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/lawyer_bunnysuit_black
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/lawyer_bunnysuit_blue
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/lawyer_bunnysuit_good
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/lawyer_bunnysuit_red
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/mime_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/civilian/psychologist_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/engineering/atmos_tech_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/engineering/chief_engineer/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/engineering/engineer_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/chemist/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/cmo_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/coroner_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/doctor_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/paramedic_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/medical/pathologist_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/rnd/geneticist/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/rnd/research_director/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/rnd/scientist/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/rnd/scientist/roboticist_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/brig_phys_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/detective_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/head_of_security/bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/nova/modskin
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/prisoner_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/security_assistant_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/security_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/rank/security/warden_bunnysuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/skinsuit
	bulge_family = /datum/bulge_family/long_johns

/obj/item/clothing/under/wetsuit_norm
	bulge_family = /datum/bulge_family/long_johns

// Jumpsuits: one piece with trouser legs, shirt-with-slacks outfits included.

/obj/item/clothing/under/abductor
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/admin
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/bimpcap
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/blastwave
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/camo/gags
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/chameleon
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/colonial
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/color
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/color/rainbow
	bulge_printed = TRUE

/obj/item/clothing/under/costume/buttondown/slacks
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 4

/obj/item/clothing/under/costume/captain
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/cybersleek
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/deckers
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/draculass
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/drfreeze
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/dutch
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/football_suit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/gamberson
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/gi
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/gi/goku
	bulge_printed = TRUE

/obj/item/clothing/under/costume/gladiator/ash_walker/greentrib
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/gladiator/ash_walker/tribal
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/costume/gladiator is.

/obj/item/clothing/under/costume/gondola
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/griffin
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/head_of_personnel
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/henchmen
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/jabroni
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/jackbros
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/joker
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/mech_suit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/nova/cavalry
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/nova/cheongsam
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 3

/obj/item/clothing/under/costume/nova/christmas
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/nri
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nri/captain
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/costume/nri is.

/obj/item/clothing/under/costume/nri/engineer
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/costume/nri is.

/obj/item/clothing/under/costume/nri/medic
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/costume/nri is.

/obj/item/clothing/under/costume/osi
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/owl
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/pirate
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/redcoat
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/referee
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/russian_officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/sailor
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/scarecrow
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/skeleton
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/soviet
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/swagoutfit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/tmc
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/costume/traditional
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/villain
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/costume/yuri
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/doug_dimmadome
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/ecologist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/ethereal_tunic
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/frontier_colonist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/gabeny
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/greyscale/gorkas
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/greyscale/overalls
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/greyscale/playsuit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/greyscale/turtleneck
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/imperial
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/imperial/captain
	bulge_printed = TRUE

/obj/item/clothing/under/imperial/rd
	bulge_printed = TRUE

/obj/item/clothing/under/imperialvest
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/jumpsuit/caligram_fatigues
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/adminsuit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/assistantformal
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/bouncer
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/misc/burial
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/coordinator
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/durathread
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/mailman
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/nova/mechanic
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/nova/taccas
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/nova/utility
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/overalls
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/patriotsuit
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/misc/pj/blue
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/misc/pj/red
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/misc/psyche
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/syndicate_souvenir
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/misc/vice_officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/occult
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/padded
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/pants/merctac_pants
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/pants/nova/shorted_overall
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/pants/tactical
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/pizza
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/plasmaman
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/plasmaman/atmospherics
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/bitrunner
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/black
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/blueshield
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/candlejax2
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/captain
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/centcom_commander
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/centcom_intern
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/centcom_official
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/chaplain
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/chef
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/chemist
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/chief_engineer
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/chief_medical_officer
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/coroner
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/engineering
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/enviroslacks
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/genetics
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/head_of_personnel
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/jax2
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/khaki
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/medical
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/mime
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/mining
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/paramedic
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/robotics
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/science
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/security/detective
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/security/nova
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/security/nova/head_of_security
	bulge_printed = TRUE

/obj/item/clothing/under/plasmaman/security/nova/warden
	bulge_printed = TRUE

/obj/item/clothing/under/plasmaman/viro
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/plasmaman/white
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/plasmaman is.

/obj/item/clothing/under/rank/azulean
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/blueshield
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/bridge_officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/captain
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/captain/suit/skirt
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/cargo/bitrunner
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/cargo/miner
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/cargo/qm
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/cargo/tech
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/commander
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/intern
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/military
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/rank/centcom/nova/lopland
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/nova/naval
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/nova/naval/admiral
	bulge_printed = TRUE

/obj/item/clothing/under/rank/centcom/officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/centcom/official
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/barber
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/chaplain
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/chaplain/divine_archer
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/clown/jester
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/civilian/clown/jesteralt
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/civilian/curator
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/head_of_personnel
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/head_of_personnel/suit/skirt
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/hydroponics
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/janitor
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/beige
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/black
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/blue
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/bluesuit
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 4

/obj/item/clothing/under/rank/civilian/lawyer/galaxy
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/greensuit
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 4

/obj/item/clothing/under/rank/civilian/lawyer/purpsuit
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/lawyer/red
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/mime
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/purple_bartender
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/civilian/viper_suit
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/atmospheric_technician
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/engineering/atmospheric_technician/nova/utility/advanced
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/engineering/chief_engineer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/engineering/engineer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/expeditionary_corps
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/chemist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/chief_medical_officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/coroner
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/doctor
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/paramedic
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/scrubs/blue
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/scrubs/coroner
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/scrubs/green
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/scrubs/nova
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/scrubs/purple
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/medical/virologist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/nanotrasen_consultant
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/prisoner
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/rank/prisoner/classic
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/rank/prisoner is.

/obj/item/clothing/under/rank/prisoner/highsec
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/rank/prisoner is.

/obj/item/clothing/under/rank/prisoner/protcust
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/rank/prisoner is.

/obj/item/clothing/under/rank/prisoner/supermax
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/rank/prisoner is.

/obj/item/clothing/under/rank/prisoner/syndicate
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/rank/prisoner is.

/obj/item/clothing/under/rank/rnd/geneticist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/rnd/research_director
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/rnd/research_director/alt
	bulge_cloth_layer = 4

/obj/item/clothing/under/rank/rnd/roboticist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/rnd/scientist
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/rnd/scientist/nova/hlscience
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/rnd/scientist/nova/utility
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/armadyne
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/constable
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/corrections_officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/detective
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/head_of_security
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/head_of_security/grey
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/depgag_pantsuit
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 4

/obj/item/clothing/under/rank/security/nova/formal
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/nova/turtleneck
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/security/nova/uniform
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/nova/utility
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/officer
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/officer/grey
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/rax
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/warden
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rank/security/warden/grey
	bulge_printed = TRUE

/obj/item/clothing/under/rank/station_trait/human_ai
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/recruiter_uniform
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/rem
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/sol_emt
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/sol_peacekeeper
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/solfed
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/solfed/emergencyfire
	bulge_printed = TRUE

/obj/item/clothing/under/solfed/marines
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/suit/beige
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/black
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/black_really
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/burgundy
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/carpskin
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/suit/charcoal
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/checkered
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/navy
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/nova/black_really_collared
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/nova/inferno
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/nova/recolorable
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/nova/scarface
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/red
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/tan
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/tuxedo
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/waiter
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/suit/white
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/syndicate
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/syndicate/camo
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/floortilecamo
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/rus_army/cin_surplus
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/tachawaiian
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/tactichill
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_printed = TRUE

/obj/item/clothing/under/tarkon
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/texas
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/trek/command
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/trek/engsec
	bulge_family = /datum/bulge_family/jumpsuits
	bulge_cloth_layer = 2

/obj/item/clothing/under/trek/engsec/ent
	bulge_cloth_layer = 1 // Cloth on layer 1, where /obj/item/clothing/under/trek/engsec has layer 2.

/obj/item/clothing/under/trek/engsec/next
	bulge_cloth_layer = 1 // Cloth on layer 1, where /obj/item/clothing/under/trek/engsec has layer 2.

/obj/item/clothing/under/trek/engsec/voy
	bulge_cloth_layer = 1 // Cloth on layer 1, where /obj/item/clothing/under/trek/engsec has layer 2.

/obj/item/clothing/under/trek/medsci
	bulge_family = /datum/bulge_family/jumpsuits

/obj/item/clothing/under/trek/q
	bulge_family = /datum/bulge_family/jumpsuits

// Khaki shorts: stiff shorts.

/obj/item/clothing/under/costume/buttondown/shorts
	bulge_family = /datum/bulge_family/khaki_shorts
	bulge_cloth_layer = 4

/obj/item/clothing/under/rank/cargo/tech/alt
	bulge_family = /datum/bulge_family/khaki_shorts

/obj/item/clothing/under/rank/civilian/cookjorts
	bulge_family = /datum/bulge_family/khaki_shorts

/obj/item/clothing/under/rank/security/nova/shorts
	bulge_family = /datum/bulge_family/khaki_shorts

/obj/item/clothing/under/rank/security/nova/shorts/engineering
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/shorts/science
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/shorts/service
	bulge_printed = TRUE

/obj/item/clothing/under/shorts
	bulge_family = /datum/bulge_family/khaki_shorts
	bulge_cloth_layer = 3

/obj/item/clothing/under/shorts/nova/shortershorts
	bulge_family = /datum/bulge_family/khaki_shorts

/obj/item/clothing/under/shorts/nova/shorts_ripped
	bulge_family = /datum/bulge_family/khaki_shorts

// Athletic shorts: knit sports shorts.

/obj/item/clothing/under/shorts/black
	bulge_family = /datum/bulge_family/athletic_shorts

/obj/item/clothing/under/shorts/blue
	bulge_family = /datum/bulge_family/athletic_shorts

/obj/item/clothing/under/shorts/green
	bulge_family = /datum/bulge_family/athletic_shorts

/obj/item/clothing/under/shorts/grey
	bulge_family = /datum/bulge_family/athletic_shorts

/obj/item/clothing/under/shorts/purple
	bulge_family = /datum/bulge_family/athletic_shorts

/obj/item/clothing/under/shorts/red
	bulge_family = /datum/bulge_family/athletic_shorts

// Track pants: track pants, tracksuits, sweatpants and baggy trousers.

/obj/item/clothing/under/misc/bluetracksuit
	bulge_family = /datum/bulge_family/track_pants

/obj/item/clothing/under/pants/nova/big_pants
	bulge_family = /datum/bulge_family/track_pants

/obj/item/clothing/under/pants/nova/loose_pants
	bulge_family = /datum/bulge_family/track_pants

/obj/item/clothing/under/pants/nova/wide_leg
	bulge_family = /datum/bulge_family/track_pants

/obj/item/clothing/under/pants/track
	bulge_family = /datum/bulge_family/track_pants

/obj/item/clothing/under/rank/blueshield/russian
	bulge_family = /datum/bulge_family/track_pants
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/soviet
	bulge_family = /datum/bulge_family/track_pants

// Leather loincloth (leather finish): the flap lifts when hard.

/obj/item/clothing/under/costume/gladiator/ash_walker/chestwrap
	bulge_family = /datum/bulge_family/leather_loincloth
	bulge_printed = FALSE // Not printed, though /obj/item/clothing/under/costume/gladiator is.

/obj/item/clothing/under/costume/loincloth
	bulge_family = /datum/bulge_family/leather_loincloth

// Colourable loincloths: the flap lifts when hard.

/obj/item/clothing/under/dress/skirt/nova/loincloth
	bulge_family = /datum/bulge_family/colourable_loincloth

/obj/item/clothing/under/dress/skirt/nova/loincloth/loincloth_alt
	bulge_family = /datum/bulge_family/colourable_loincloth/short

// Skirts, short hem, closed lift: the hem lifts when hard and the dark inside shows under it.

/obj/item/clothing/under/costume/nova/kimono/sigmar
	bulge_family = /datum/bulge_family/skirt/short_closed_lift

/obj/item/clothing/under/costume/seifuku/tan
	bulge_family = /datum/bulge_family/skirt/short_closed_lift

/obj/item/clothing/under/costume/seifuku/teal
	bulge_family = /datum/bulge_family/skirt/short_closed_lift

/obj/item/clothing/under/costume/singer/blue
	bulge_family = /datum/bulge_family/skirt/short_closed_lift
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/qm/skirt/old
	bulge_family = /datum/bulge_family/skirt/short_closed_lift

/obj/item/clothing/under/rank/civilian/clown/pink_clown_outfit
	bulge_family = /datum/bulge_family/skirt/short_closed_lift

// Skirts, short hem, reveal: the hem lifts when hard and the lifted part is cut away (hard sizes to 8).

/obj/item/clothing/under/colonial/hc_police/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/police_skirt
	bulge_printed = TRUE

/obj/item/clothing/under/color/jumpskirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/costume/buttondown/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE
	bulge_cloth_layer = 4

/obj/item/clothing/under/costume/captain/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/costume/gladiator/ash_walker/legskirt_d
	bulge_family = /datum/bulge_family/skirt/short_reveal/lone_skirt

/obj/item/clothing/under/costume/gladiator/ash_walker/yellow
	bulge_family = /datum/bulge_family/skirt/short_reveal/ash_walker_yellow

/obj/item/clothing/under/costume/head_of_personnel/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/costume/roman
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/costume/seifuku
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/costume/shendyt
	bulge_family = /datum/bulge_family/skirt/short_reveal/shendyt
	bulge_printed = TRUE

/obj/item/clothing/under/costume/singer/red
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/custom/blutigen_undergarment
	bulge_family = /datum/bulge_family/skirt/short_reveal/blutigen
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/formal_pen_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/formal_pen_skirt
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/giant_scarf
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/nova/pen_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/pen_skirt
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/short_dress
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/nova/shorter_dress
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_23
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/slit_dress
	bulge_family = /datum/bulge_family/skirt/short_reveal/slit_dress
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/virgin_killer_sweater
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_23
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/windowed_dress
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/dress/sailor
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/jean
	bulge_family = /datum/bulge_family/skirt/short_reveal/jean_skirt
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/dress/skirt/nova/lone_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/lone_skirt
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/mini_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/miniskirt
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/dress/skirt/nova/swept
	bulge_family = /datum/bulge_family/skirt/short_reveal/swept_skirt
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/plaid
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/skirt/primitive_catgirl_body_wraps
	bulge_family = /datum/bulge_family/skirt/short_reveal/body_wraps
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/skirt/primitive_catgirl_tunic
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/skirt/turtleskirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/striped
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/dress/sundress
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE
	bulge_cloth_layer = 3

/obj/item/clothing/under/greyscale/overalls/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/greyscale/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/imperialskirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_23
	bulge_printed = TRUE

/obj/item/clothing/under/imperialskirtvest
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_23
	bulge_printed = TRUE

/obj/item/clothing/under/nt_idol_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/pants/nova/double_skirt_dress
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/pants/nova/kilt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/blueshield/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/blueshield/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/bridge_officer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/captain/dress
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/captain/nova/kilt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/rank/captain/nova/pilot/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/captain/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/tech/skirt/alt
	bulge_family = /datum/bulge_family/skirt/short_reveal

/obj/item/clothing/under/rank/centcom/centcom_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/centcom/officer_skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/curator/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/head_of_personnel/nova/parade/female
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/head_of_personnel/nova/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/head_of_personnel/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/janitor/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/beige/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/black/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/blue/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/bluesuit/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/galaxy/red/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/galaxy/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/greensuit/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/purpsuit/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/lawyer/red/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/mime/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/atmospheric_technician/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/chief_engineer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/chief_engineer/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/engineer/nova/utility/telecomm/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/engineering/engineer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/chemist/nova/formal/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/chemist/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/chief_medical_officer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/chief_medical_officer/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/coroner/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/doctor/nurse/seriouser
	bulge_family = /datum/bulge_family/skirt/short_reveal/seriouser
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/doctor/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/paramedic/nova/light/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/paramedic/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/medical/virologist/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/prisoner/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24

/obj/item/clothing/under/rank/rnd/geneticist/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/rnd/research_director/alt/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/rnd/research_director/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/rnd/research_director/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/rnd/roboticist/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/rnd/scientist/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/corrections_officer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/corrections_officer/sweater/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/detective/noir/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/detective/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/hem_24
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/head_of_security/alt/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/head_of_security/nova/alt/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/head_of_security/nova/parade/female
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/head_of_security/parade/female
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/head_of_security/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/miniskirt
	bulge_family = /datum/bulge_family/skirt/short_reveal/miniskirt
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/plainskirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/security/nova/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/rank/security/officer/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/warden/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/suit/black/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/suit/black_really/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/suit/nova/black_really_collared/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/suit/nova/recolorable/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/suit/white/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/nova/overalls/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/nova/overalls/unarmoured/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/nova/tactical/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/nova/tactical/unarmoured/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/tacticool/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/unarmoured/skirt
	bulge_family = /datum/bulge_family/skirt/short_reveal
	bulge_printed = TRUE

// Skirts, short hem, kilt apron: a flat front panel that rises evenly when hard.

/obj/item/clothing/under/costume/gladiator
	bulge_family = /datum/bulge_family/skirt/short_kilt_apron
	bulge_printed = TRUE

/obj/item/clothing/under/costume/kilt
	bulge_family = /datum/bulge_family/skirt/short_kilt_apron
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/chaplain/skirt
	bulge_family = /datum/bulge_family/skirt/short_kilt_apron
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/clown/sexy
	bulge_family = /datum/bulge_family/skirt/short_kilt_apron

// Skirts, long hem, cone: the cloth tents from the tip with folds fanning down to the hem.

/obj/item/clothing/under/bubbly_clown_skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/dragon_maid
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/gladiator/ash_walker/robe
	bulge_family = /datum/bulge_family/skirt/long_cone

/obj/item/clothing/under/costume/gladiator/ash_walker/shaman
	bulge_family = /datum/bulge_family/skirt/long_cone

/obj/item/clothing/under/costume/gladiator/ash_walker/white
	bulge_family = /datum/bulge_family/skirt/long_cone

/obj/item/clothing/under/costume/kimono
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/lobster
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/bathrobe
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/chima_jeogori
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/kamishimo
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/kimono
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/maid_uniform
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/costume/nova/maid_uniform_alt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/costume/nova/qipao
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/shihakusho
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/nova/yukata
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/singer/yellow
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/costume/yukata
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/custom/lannese
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/ambassadordagmar
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/eveninggown
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/heirloomdagmar
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/countess
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/nova/flower
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/pentagram
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/pinktutu
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/redformal
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/strapless
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/skirt/primitive_catgirl_tailored_dress
	bulge_family = /datum/bulge_family/skirt/long_cone

/obj/item/clothing/under/dress/tango
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE
	bulge_cloth_layer = 2

/obj/item/clothing/under/dress/wedding_dress
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/pants/nova/hakama
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/plasmaman/clown
	bulge_family = /datum/bulge_family/skirt/long_cone

/obj/item/clothing/under/rank/azulean/old_blood/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/azulean/upstart/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/blueshield/consult/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/blueshield/netra
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/bridge_officer/turtle/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/qm/nova/formal/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/qm/nova/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/qm/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/tech/nova/turtleneck/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/cargo/tech/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/clown
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/civilian/hydroponics/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/rank/nanotrasen_consultant/skirt
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/nova/maid
	bulge_family = /datum/bulge_family/skirt/long_cone
	bulge_printed = TRUE

/obj/item/clothing/under/syndicate/tacticool/skirt/long
	bulge_family = /datum/bulge_family/skirt/long_cone

// Skirts, long hem, curtain: the cloth falls straight down from the tip in pipe folds.

/obj/item/clothing/under/costume/geisha
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/costume/gladiator/ash_walker/ash_robes
	bulge_family = /datum/bulge_family/skirt/long_curtain

/obj/item/clothing/under/costume/gladiator/ash_walker/chiefrags
	bulge_family = /datum/bulge_family/skirt/long_curtain

/obj/item/clothing/under/costume/maid
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/black_skirt
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/long
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/medium
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/red_skirt
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/dress/skirt/nova/striped_skirt
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/maid_costume
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/padded/alt
	bulge_family = /datum/bulge_family/skirt/long_curtain

/obj/item/clothing/under/rank/civilian/janitor/maid
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE

/obj/item/clothing/under/rank/security/nova/dress
	bulge_family = /datum/bulge_family/skirt/long_curtain
	bulge_printed = TRUE
	bulge_cloth_layer = 2

// Skirts, long hem, pressed: no tent; the bulge stretches the cloth.

/obj/item/clothing/under/costume/cybersleek/long
	bulge_family = /datum/bulge_family/skirt/long_pressed

/obj/item/clothing/under/dress/neoflapperdagmar
	bulge_family = /datum/bulge_family/skirt/long_pressed
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/jute
	bulge_family = /datum/bulge_family/skirt/long_pressed
	bulge_printed = TRUE

/obj/item/clothing/under/dress/nova/midnight_gown
	bulge_family = /datum/bulge_family/skirt/long_pressed
	bulge_printed = TRUE

/obj/item/clothing/under/suit/nova/inferno/skirt
	bulge_family = /datum/bulge_family/skirt/long_pressed
	bulge_printed = TRUE

/obj/item/clothing/under/suit/nova/pencil
	bulge_family = /datum/bulge_family/skirt/long_pressed
	bulge_printed = TRUE

/obj/item/clothing/under/suit/nova/pencil/noshirt
	bulge_cloth_layer = 2

// No bulge: subtypes of the garments above that were never reviewed themselves. Explicit values keep them as they are today
// (no bulge); mal may decide later to let them inherit their parent's treatment.

/obj/item/clothing/under/costume/dutch/syndicate
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/dress/skirt/nova
	bulge_family = /datum/bulge_family/none
	bulge_printed = FALSE // Never reviewed: not printed, though /obj/item/clothing/under/dress/skirt is.

/obj/item/clothing/under/pants/nova/chaps
	bulge_cloth_layer = 3 // The surveyed layer, kept; this garment draws no bulge.

/obj/item/clothing/under/rank/captain/suit
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/rank/civilian/head_of_personnel/suit
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/rank/engineering/atmospheric_technician/nova/utility
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/rank/rnd/research_director/nova
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/rank/rnd/roboticist/nova
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/rank/rnd/scientist/nova
	bulge_family = /datum/bulge_family/none

/obj/item/clothing/under/shorts/nova
	bulge_family = /datum/bulge_family/none

// ===== Suits =======================================================================================================

// Suits that leave the crotch clear as worn: the bulge shows through.

/obj/item/clothing/neck/cloak/colonial
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/admin
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/elder_atmosian
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/forging_plate_armor
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/hop_tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/hos/deckofficer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/hos/trenchcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/hos_tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/laserproof
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/security_tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/capcarapace
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/det_suit/runner
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/expeditionary_corps
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/hc_police_jacket
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/hop
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/leather
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/marine
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/nanotrasen_consultant
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/armor/vest/secjacket
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/autumn
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/blackfurrich
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/blastwave
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/british_officer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/brownbattlecoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/brownfurrich
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/caution
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/costume/irs
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/costume/pg
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/costume/pirate
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/costume/tmc
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/hooded/chaplain_hoodie/divine_archer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/hooded/wintercoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/hooded/wintercoat/security/depgag
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/blazer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/bomber
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/bomber_donor
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/capjacket
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/delta
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/det_suit
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/discoblazer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/fancy
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/frontier_colonist
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/gorlex_harness
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/hydrogenrobes
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/leather
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/leather_trenchcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/letterman
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/letterman_nanotrasen
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/letterman_red
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/letterman_syndie
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/miljacket
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/oversized
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/skyy
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/jacket/tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/mothcoat/winter
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/space/officer
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/toggle/jacket/det_trench
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/toggle/jacket/trenchcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/utility/fire/atmos_tech_tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/utility/fire/ce_tailcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/varsity
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/warm_coat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/wizrobe/magician
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/woolcoat
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

// Suits that leave the crotch clear both as worn and toggled (open, unzipped, hood up).

/obj/item/clothing/suit/armor/vest/secjacket/depgag
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/ablative
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/cloak/david
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/cloak/goliath
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/cloak/zuliecloak
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/cultrobes/void
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/ethereal_raincoat
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/leather
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/wintercoat/pullover
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/wintercoat/security
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/wintercoat/security/depgag/bomber
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/wintercoat/security/depgag/depgag_vested_jacket
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/hooded/wintercoat/zipup
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/jacket/henchmen_coat
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/chef
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/deckard
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/jacket/nova
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/jacket/nova/sec/old/syndicate
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/jacket/sweater
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

/obj/item/clothing/suit/toggle/labcoat/research_director/tailcoat
	bulge_suit_rule = BULGE_SUIT_EITHER_STATE

// Suits that leave the crotch clear only when toggled.

/obj/item/clothing/suit/armor/centcom_formal
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

/obj/item/clothing/suit/armor/hos/hos_formal
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

/obj/item/clothing/suit/armor/vest/capcarapace/captains_formal
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

/obj/item/clothing/suit/armor/vest/hop/hop_formal
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

/obj/item/clothing/suit/brownbattlecoat/elysiancoat
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

/obj/item/clothing/suit/toggle/labcoat/research_director
	bulge_suit_rule = BULGE_SUIT_TOGGLED_STATE

// Suits that leave the crotch clear only on digitigrade legs.

/obj/item/clothing/suit/apron/waders
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

/obj/item/clothing/suit/armor/riot
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

/obj/item/clothing/suit/clockwork/cloak
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

/obj/item/clothing/suit/costume/cheongsam_blue
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

/obj/item/clothing/suit/costume/cheongsam_red
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

/obj/item/clothing/suit/fallsparka
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI

// Suits that leave the crotch clear only on digitigrade legs, as worn and toggled.

/obj/item/clothing/suit/hooded/bee_costume
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI|BULGE_SUIT_TOGGLED_DIGI

/obj/item/clothing/suit/hooded/explorer/syndicate
	bulge_suit_rule = BULGE_SUIT_DEFAULT_DIGI|BULGE_SUIT_TOGGLED_DIGI

// Suits that leave the crotch clear only on plain legs.

/obj/item/clothing/suit/jacket/tailcoat/miner
	bulge_suit_rule = BULGE_SUIT_DEFAULT_PLAIN

// Overalls: the suit is itself the cover and bulges as denim.

/obj/item/clothing/suit/apron/overalls
	bulge_family = /datum/bulge_family/jeans
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

/obj/item/clothing/suit/atmos_overalls
	bulge_family = /datum/bulge_family/jeans
	bulge_suit_rule = BULGE_SUIT_DEFAULT_STATE

// Subtypes of the suits above that were never reviewed themselves: explicit NONE keeps them hiding the bulge.

/obj/item/clothing/suit/armor/forging_plate_armor/hearthkin
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/armor/forging_plate_armor does not.

/obj/item/clothing/suit/armor/hos/trenchcoat/armadyne
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/armor/hos/trenchcoat does not.

/obj/item/clothing/suit/armor/riot/knight
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/armor/riot does not.

/obj/item/clothing/suit/armor/vest/capcarapace/jacket
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/armor/vest/capcarapace does not.

/obj/item/clothing/suit/armor/vest/capcarapace/syndicate
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/armor/vest/capcarapace does not.

/obj/item/clothing/suit/costume/pirate/captain
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/costume/pirate does not.

/obj/item/clothing/suit/hooded/wintercoat/nova/bartender
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/hooded/wintercoat does not.

/obj/item/clothing/suit/toggle/jacket/nova/corrections_officer
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/toggle/jacket/nova does not.

/obj/item/clothing/suit/toggle/jacket/nova/det_trench
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/toggle/jacket/nova does not.

/obj/item/clothing/suit/toggle/jacket/nova/flannel
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/toggle/jacket/nova does not.

/obj/item/clothing/suit/toggle/jacket/nova/sec
	bulge_suit_rule = NONE // Never reviewed: hides the bulge, where /obj/item/clothing/suit/toggle/jacket/nova does not.
