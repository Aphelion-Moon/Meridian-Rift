/// The body zones whose limbs come in muscle sizes, in the order a garment's fit lists them (/datum/garment_fit/var/sizes).
GLOBAL_LIST_INIT(fitness_zones, list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG, BODY_ZONE_CHEST))

/**
 * Points a new species' limb types at the body's muscle size and definition before it builds the body, so a species change, a
 * cloning or a changeling's new form comes out at the size and definition in the DNA, and so do limbs the body regrows later.
 */
/datum/species/on_species_gain(mob/living/carbon/human/human_who_gained_species, datum/species/old_species, pref_load, regenerate_icons = TRUE, replace_missing = TRUE)
	update_fitness_limb_types(human_who_gained_species.dna)
	return ..()

/**
 * Points this species' own limb types at the muscle size and definition in `dna`, so the limbs it builds or regrows come in at
 * them. Only its own copy changes: a body's species is its own, never the prototype. A zone whose limb type has no fitness
 * subtypes keeps it.
 *
 * Arguments:
 * - dna: The DNA holding the size and definition.
 */
/datum/species/proc/update_fitness_limb_types(datum/dna/dna)
	var/size = dna.features[FEATURE_MUSCLE_SIZE]
	var/definition = dna.features[FEATURE_MUSCLE_DEFINITION]
	for(var/zone in GLOB.fitness_zones)
		var/fitness_type = FITNESS_LIMB_TYPE(bodypart_overrides[zone], size, definition)
		if(fitness_type)
			bodypart_overrides[zone] = fitness_type

/**
 * Gives this body's limbs the muscle size and definition in its DNA: swaps each limb that has fitness subtypes for its family's
 * type at them, digitigrade legs for digitigrade legs, gives the fitness limbs it keeps the definition, and points its
 * species' limb types at them. A limb exempt from species changes stays, as it does in replace_body().
 *
 * The swap is one render batch. It draws only the worn clothing fitted to the limbs when it ends the batch
 * (refit_worn_clothing()): the preferences that call it are applied before the body is drawn. A new definition alone changes no
 * fit, and is drawn with the body.
 */
/mob/living/carbon/human/proc/update_fitness_limbs()
	dna.species.update_fitness_limb_types(dna)
	var/size = dna.features[FEATURE_MUSCLE_SIZE]
	var/definition = dna.features[FEATURE_MUSCLE_DEFINITION] || 0
	var/already_batched = living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS
	living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	var/swapped = FALSE
	for(var/zone in GLOB.fitness_zones)
		var/obj/item/bodypart/old_limb = get_bodypart(zone)
		if(isnull(old_limb) || (old_limb.change_exempt_flags & BP_BLOCK_CHANGE_SPECIES) || (old_limb.bodypart_flags & BODYPART_IMPLANTED))
			continue
		var/fitness_type = FITNESS_LIMB_TYPE(old_limb.type, size, definition)
		if(isnull(fitness_type))
			continue
		if(fitness_type == old_limb.type)
			// A plain limb holds no definition, so its redraw stays as it was.
			if(fitness_type != GLOB.fitness_limb_families[fitness_type][1] && old_limb.muscle_definition != definition)
				old_limb.muscle_definition = definition
			continue
		var/obj/item/bodypart/new_limb = new fitness_type()
		if(!new_limb.replace_limb(src))
			qdel(new_limb)
			continue
		new_limb.update_limb(is_creating = TRUE)
		new_limb.set_initial_damage(old_limb.brute_dam, old_limb.burn_dam)
		qdel(old_limb)
		swapped = TRUE
	if(!already_batched)
		living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
		if(swapped)
			refit_worn_clothing()

/mob/living/carbon/human
	/// What this body's garments are fitted to: its fitness arms' and legs' muscle sizes, and its chest's where a male chest's
	/// glutes reach past today's, the legs and chest left out on a taur body, which draws none of them; or null when they're
	/// all Normal. Kept up to date with its limbs (update_garment_fit()), so drawing a garment only reads it.
	var/datum/garment_fit/garment_fit

// Every limb a body gains or loses, and every change to its body shape, comes through here.
/mob/living/carbon/human/synchronize_bodyshapes()
	. = ..()
	update_garment_fit()

/**
 * Sets garment_fit from this body's limbs and body shape. A fitness chest also calls it each time it's set up for the body,
 * which sets its male or female art: only a male chest has glutes to fit, and only at the sizes the templates hold
 * ("chest_m").
 */
/mob/living/carbon/human/proc/update_garment_fit()
	var/right_arm = 0
	var/left_arm = 0
	var/right_leg = 0
	var/left_leg = 0
	var/chest = 0
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		switch(limb.body_zone)
			if(BODY_ZONE_R_ARM)
				right_arm = limb.muscle_size
			if(BODY_ZONE_L_ARM)
				left_arm = limb.muscle_size
			if(BODY_ZONE_R_LEG)
				right_leg = limb.muscle_size
			if(BODY_ZONE_L_LEG)
				left_leg = limb.muscle_size
			if(BODY_ZONE_CHEST)
				if(limb.muscle_size && limb.is_dimorphic && limb.limb_gender == "m" && garment_fit_templates()["limbs"]["chest_m"]?["[limb.muscle_size]"])
					chest = limb.muscle_size
	if(bodyshape & BODYSHAPE_TAUR)
		right_leg = 0
		left_leg = 0
		chest = 0
	if(!right_arm && !left_arm && !right_leg && !left_leg && !chest)
		garment_fit = null
		return
	var/list/sizes = list()
	if(right_arm)
		sizes[BODY_ZONE_R_ARM] = right_arm
	if(left_arm)
		sizes[BODY_ZONE_L_ARM] = left_arm
	if(right_leg)
		sizes[BODY_ZONE_R_LEG] = right_leg
	if(left_leg)
		sizes[BODY_ZONE_L_LEG] = left_leg
	if(chest)
		sizes["chest_m"] = chest
	garment_fit = get_garment_fit(sizes)

/**
 * Returns whether a species' own limbs have fitness subtypes, which is when its characters get a muscle size and definition.
 *
 * Arguments:
 * - species_type: The species' type.
 */
/proc/species_has_fitness_limbs(datum/species/species_type)
	var/list/limb_types = GLOB.species_prototypes[species_type].bodypart_overrides
	for(var/zone in GLOB.fitness_zones)
		if(GLOB.fitness_limb_families[limb_types[zone]])
			return TRUE
	return FALSE
