/// The dna.features entry holding the fitness level of each body zone's limb.
GLOBAL_LIST_INIT(fitness_zone_features, list(
	BODY_ZONE_CHEST = FEATURE_FITNESS_TORSO,
	BODY_ZONE_L_ARM = FEATURE_FITNESS_ARMS,
	BODY_ZONE_R_ARM = FEATURE_FITNESS_ARMS,
	BODY_ZONE_L_LEG = FEATURE_FITNESS_LEGS,
	BODY_ZONE_R_LEG = FEATURE_FITNESS_LEGS,
))

/**
 * Points a new species' limb types at the body's fitness levels before it builds the body, so a species change, a cloning
 * or a changeling's new form comes out at the levels in the DNA, and so do limbs the body regrows later.
 */
/datum/species/on_species_gain(mob/living/carbon/human/human_who_gained_species, datum/species/old_species, pref_load, regenerate_icons = TRUE, replace_missing = TRUE)
	update_fitness_limb_types(human_who_gained_species.dna, GLOB.fitness_zone_features)
	return ..()

/**
 * Points this species' own limb types in `zones` at the fitness levels in `dna`, so the limbs it builds or regrows there
 * come in at those levels. Only its own copy changes: a body's species is its own, never the prototype. A zone whose limb
 * type has no fitness subtypes keeps it.
 *
 * Arguments:
 * - dna: The DNA holding the levels.
 * - zones: The body zones to point.
 */
/datum/species/proc/update_fitness_limb_types(datum/dna/dna, list/zones)
	for(var/zone in zones)
		var/fitness_type = FITNESS_LIMB_TYPE(bodypart_overrides[zone], dna.features[GLOB.fitness_zone_features[zone]])
		if(fitness_type)
			bodypart_overrides[zone] = fitness_type

/**
 * Gives this body's limbs in `zones` the fitness levels in its DNA, swapping each limb that has fitness subtypes for the one at
 * its level, digitigrade legs for digitigrade legs, and points its species' limb types at them. A limb exempt from species
 * changes stays, as it does in replace_body().
 *
 * The swap is one render batch. It draws only the worn clothing fitted to the limbs when it ends the batch
 * (refit_worn_clothing()): the preferences that call it are applied before the body is drawn.
 *
 * Arguments:
 * - zones: The body zones to give their levels.
 */
/mob/living/carbon/human/proc/update_fitness_limbs(list/zones)
	dna.species.update_fitness_limb_types(dna, zones)
	var/already_batched = living_flags & STOP_OVERLAY_UPDATE_BODY_PARTS
	living_flags |= STOP_OVERLAY_UPDATE_BODY_PARTS
	var/swapped = FALSE
	for(var/zone in zones)
		var/obj/item/bodypart/old_limb = get_bodypart(zone)
		if(isnull(old_limb) || (old_limb.change_exempt_flags & BP_BLOCK_CHANGE_SPECIES) || (old_limb.bodypart_flags & BODYPART_IMPLANTED))
			continue
		var/fitness_type = FITNESS_LIMB_TYPE(old_limb.type, dna.features[GLOB.fitness_zone_features[zone]])
		if(isnull(fitness_type) || fitness_type == old_limb.type)
			continue
		var/obj/item/bodypart/new_limb = new fitness_type()
		if(!new_limb.replace_limb(src))
			qdel(new_limb)
			continue
		new_limb.update_limb(is_creating = TRUE)
		new_limb.set_initial_damage(old_limb.brute_dam, old_limb.burn_dam)
		qdel(old_limb)
		swapped ||= (zone in GLOB.garment_fit_limbs)
	if(!already_batched)
		living_flags &= ~STOP_OVERLAY_UPDATE_BODY_PARTS
		if(swapped)
			refit_worn_clothing()

/mob/living/carbon/human
	/// What this body's garments are fitted to: its fitness arms' and legs' levels, the legs left out on a taur body, which
	/// draws none; or null when they're all at the baseline. Kept up to date with its limbs (update_garment_fit()), so drawing a
	/// garment only reads it.
	var/datum/garment_fit/garment_fit

// Every limb a body gains or loses, and every change to its body shape, comes through here.
/mob/living/carbon/human/synchronize_bodyshapes()
	. = ..()
	update_garment_fit()

/**
 * Sets garment_fit from this body's limbs and body shape.
 */
/mob/living/carbon/human/proc/update_garment_fit()
	var/right_arm = 0
	var/left_arm = 0
	var/right_leg = 0
	var/left_leg = 0
	for(var/obj/item/bodypart/limb as anything in bodyparts)
		switch(limb.body_zone)
			if(BODY_ZONE_R_ARM)
				right_arm = limb.fitness_level
			if(BODY_ZONE_L_ARM)
				left_arm = limb.fitness_level
			if(BODY_ZONE_R_LEG)
				right_leg = limb.fitness_level
			if(BODY_ZONE_L_LEG)
				left_leg = limb.fitness_level
	if(bodyshape & BODYSHAPE_TAUR)
		right_leg = 0
		left_leg = 0
	if(!right_arm && !left_arm && !right_leg && !left_leg)
		garment_fit = null
		return
	var/list/levels = list()
	if(right_arm)
		levels[BODY_ZONE_R_ARM] = right_arm
	if(left_arm)
		levels[BODY_ZONE_L_ARM] = left_arm
	if(right_leg)
		levels[BODY_ZONE_R_LEG] = right_leg
	if(left_leg)
		levels[BODY_ZONE_L_LEG] = left_leg
	garment_fit = get_garment_fit(levels)

/**
 * Returns whether a species' own limbs in any of `zones` have fitness subtypes, which is when its characters get fitness levels.
 *
 * Arguments:
 * - species_type: The species' type.
 * - zones: The body zones to look at.
 */
/proc/species_has_fitness_limbs(datum/species/species_type, list/zones)
	var/list/limb_types = GLOB.species_prototypes[species_type].bodypart_overrides
	for(var/zone in zones)
		if(GLOB.fitness_limb_families[limb_types[zone]])
			return TRUE
	return FALSE
