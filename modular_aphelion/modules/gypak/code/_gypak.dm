#define GYPAK_TEMP_OFFSET 40//This is a wild +10 over a few others.
#define GYPAK_HEATMOD 0.80//80% of baseline.
//Birds that require more oxygen and suffocate in bad environments easier.
//They've a built in debt, incapable of engaging with genetics, get diseases easier and they just...
//... overall kinda blow? Beyond their heat resist and lungs, I suppose. And a free pluox tank! Empty though it might be, nearly.
//Canary in a plasma mine. Oh, and they explode upon death. Into dust.
/datum/species/gypak
	name = "Gypak"
	id = SPECIES_GYPAK
	inherent_biotypes = MOB_ORGANIC|MOB_HUMANOID
	inherent_traits = list(
		TRAIT_ADVANCEDTOOLUSER,
		TRAIT_CAN_STRIP,
		TRAIT_LITERATE,
		TRAIT_MUTANT_COLORS,
		//The absolutely dumb stuff, below.
		TRAIT_RDS_SUPPRESSED,
		TRAIT_MADNESS_IMMUNE,
		TRAIT_BADDNA,//You're just awful. Really just awful.
		TRAIT_NO_DNA_SCRAMBLE,
		TRAIT_IMMUNODEFICIENCY,//Just the worst.
	)
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_MAGIC | MIRROR_PRIDE | ERT_SPAWN | RACE_SWAP | SLIME_EXTRACT
	payday_modifier = 0.4//Built in debt. 40% of standard pay.
	heatmod = GYPAK_HEATMOD
	bodytemp_normal = BODYTEMP_NORMAL + GYPAK_TEMP_OFFSET
	bodytemp_heat_damage_limit = (BODYTEMP_HEAT_DAMAGE_LIMIT + GYPAK_TEMP_OFFSET)//Much more resistant against heat!
	species_language_holder = /datum/language_holder/gypak
	meat = /obj/item/food/meat/slab/chicken/human//Not that you'll ever actually see this, I guess. But still!
	digitigrade_customization = DIGITIGRADE_FORCED//They're BIRDS. Of sorts.
	survival_box_overrides = list(
		SURVIVAL_INTERNALS_TYPE = /obj/item/tank/internals/pluox,
	)
	mutantlungs = /obj/item/organ/lungs/gypak//You breath a LOT more oxygen, and suffocate easier / intake alts easier. Suffer.

/datum/species/gypak/get_physical_attributes()
	return "The Gypak, a patron species of the Astraeus Star Federation. \
	Old-Earth avians in appearance, vaguely resembling Vox, though far diverged in all other manners not superficial to both."

/datum/species/gypak/get_species_description()
	return "Gypak are atmospheric-sensitive avians, with weak genetics and a propensity to burst into meat-putty on death."

/datum/species/gypak/get_species_lore()
	return list(
		"Nearly a century ago, the Gypak principalities willingly bid themselves into the service of the ASF. \
		It is said, as per official record, to have been an attempt to save their species. \
		For issues of fertility, sanity and a continual power vacuum among internal forces had brought them close to extinction. \
		If exaggeration is to be believed? Perhaps a dozen times over within the span of a decade, by their own recounting in offical sources. \
		While the matter of a power vacuum had vanished overnight, as the principalities had dissolved in all but name? The other two issues were retained.",
		"",
		"Neither by way of research or force, has the problem of fertility and their degrading faculties seen a resolution. \
		So poor was the situation, in fact, that their species hardly lives upwards of a century. \
		Even with the finest of medical intervention, the species goes through an almost planned obsolescence. \
		For the mind gives out first, slowly, yet with an assured loss of long-term memory. \
		Such is followed by an absence of the self, as their personality radically shifts. Finally, the body, as it becomes atrophic. \
		Undergoing a process easily described as cellular degradation in the final stages. \
		Muscle and keratin sloughing away. To call it horrific would be an understatement. \
		Before such a stage, many opt for voluntary exile. Whether that be pilgrimage or otherwise, the goal is the same - a resting place.",
		"",
		"Their presence aboard a station may be one such pilgrimage, an attempt to find a home, or simply an excursion from their expeditionary fleet. \
		Whether that be militaristic in nature, or a simple broadening of the horizons. \
		For it's the most that many of their species will ever see of the world, beyond the fleets. \
		As their homeworld remains a closely guarded secret, with all itinerant or fleet-bound Gypak incapable of telling anyone exactly /where/ it is.",
	)

/datum/species/gypak/get_default_mutant_bodyparts()
	return list(
		FEATURE_TAIL = MUTPART_BLUEPRINT("Avian (Alt)", is_randomizable = TRUE),
		FEATURE_SNOUT = MUTPART_BLUEPRINT("Corvid Beak", is_randomizable = TRUE),
		FEATURE_LEGS = MUTPART_BLUEPRINT(DIGITIGRADE_LEGS, is_randomizable = FALSE, is_feature = TRUE),
		FEATURE_TAUR = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
		FEATURE_WINGS = MUTPART_BLUEPRINT(SPRITE_ACCESSORY_NONE, is_randomizable = FALSE),
	)

/datum/species/gypak/randomize_features()
	var/list/features = ..()
	var/main_color = "#[random_color()]"
	var/second_color
	var/third_color
	var/random = rand(1,3)
	switch(random)
		if(1)
			second_color = main_color
			third_color = main_color
		if(2)
			second_color = main_color
			third_color = main_color
		if(3)
			second_color = "#[random_color()]"
			third_color = "#[random_color()]"
	features[FEATURE_MUTANT_COLOR] = main_color
	features[FEATURE_MUTANT_COLOR_TWO] = second_color
	features[FEATURE_MUTANT_COLOR_THREE] = third_color
	return features

/datum/species/gypak/prepare_human_for_preview(mob/living/carbon/human/bird, bird_color = "#84776e")
	bird.dna.features[FEATURE_MUTANT_COLOR] = bird_color
	bird.dna.mutant_bodyparts[FEATURE_SNOUT] = build_mutant_part("Corvid Beak", list(bird_color, bird_color, bird_color))
	bird.dna.mutant_bodyparts[FEATURE_TAIL] = build_mutant_part("Avian (Alt)", list(bird_color, bird_color, bird_color))
	bird.dna.features[FEATURE_LEGS] = DIGITIGRADE_LEGS
	regenerate_organs(bird, src, visual_only = TRUE)
	bird.update_body(TRUE)

/datum/species/gypak/create_pref_unique_perks()
	var/list/to_add = list()

	to_add += list(
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_SHIELD_HALVED,
			SPECIES_PERK_NAME = "Heat Warding Feathers",
			SPECIES_PERK_DESC = "Despite their fragile genetics, Gypak are quite resilient against heat. \
			Burns are only 80% as effective against them!",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_BRAIN,
			SPECIES_PERK_NAME = "Stable Mind",
			SPECIES_PERK_DESC = "Gypak are immune to lesser hallucinations and RDS symptoms. Full stop.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = FA_ICON_LUNGS_VIRUS,
			SPECIES_PERK_NAME = "High-Grain Lungs",
			SPECIES_PERK_DESC = "Gypak lungs require an exceptionally large amount of oxygen. \
			They suffocate easier in the presence of carbon dioxide, \
			take in approximately 20% more pressure per-breath and suffer heavily in poor environments.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_EGG,
			SPECIES_PERK_NAME = "Genetically Stunted",
			SPECIES_PERK_DESC = "A Gypak's DNA is absolutely useless to modern science. \
			One can only be thankful that they're immune to the further scrambling of such.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_COINS,
			SPECIES_PERK_NAME = "Fleet Debt",
			SPECIES_PERK_DESC = "As per agreement of signing on with a fleet and abandoning their homeworld, \
			a Gypak only receives approximately 40% of standard pay.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_EXPAND_ALT,
			SPECIES_PERK_NAME = "Immunosuppressed",
			SPECIES_PERK_DESC = "A Gypak's immune system is, seemingly by design, compromised.",
		),
		list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = FA_ICON_EXPLOSION,
			SPECIES_PERK_NAME = "Ephemeral Decomposition",
			SPECIES_PERK_DESC = "Upon death, a Gypak's body undergoes rapid, near explosive decomposition. \
			Their form dissolves into what's commonly described, not so kindly, as meat-putty.",
		),
	)
	return to_add

//Stick with me, Chief. It's about to get gnarly.
/datum/species/gypak/on_species_gain(mob/living/carbon/human/human_who_gained_species, datum/species/old_species, pref_load, regenerate_icons, replace_missing)
	. = ..()
	RegisterSignal(human_who_gained_species, COMSIG_LIVING_DEATH, PROC_REF(unwitting_fool))

/datum/species/gypak/on_species_loss(mob/living/carbon/human/human_who_lost_species, datum/species/new_species, pref_load)
	. = ..()
	UnregisterSignal(human_who_lost_species, list(
		COMSIG_LIVING_DEATH,
	))

//I'll need to change this to nanite goo or something later. Because they're meant to turn into puddles of goo.
//Dust is just easier in the interim, paired with a temp molten mass.
/datum/species/gypak/proc/unwitting_fool(mob/living/carbon/human/source)
	SIGNAL_HANDLER
	source.visible_message(
		span_warning("[source] contorts and writhes violently, before beginning to dissolve!"),
		span_userdanger("Your body shudders, only to melt away. Oh dear."),
		visible_message_flags = ALWAYS_SHOW_SELF_MESSAGE,
	)
	source.investigate_log("dissolved upon death as a gypak", INVESTIGATE_DEATHS)
	var/turf/T = get_turf(source)
	var/obj/effect/decal/cleanable/molten_object/large/goo = new(T)
	goo.name = "[source]"
	goo.desc = "What remains of \an [source]. Eeugh..."
	goo.color = "#e2b6ac"//We really could do with a better colour. Alas...
	source.dust(just_ash = TRUE, drop_items = TRUE, give_moodlet = TRUE, force = TRUE)//Instead of 'meat-dust', it's quite simple.
