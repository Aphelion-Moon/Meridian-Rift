/proc/accessory_list_of_key_for_species(key, datum/species/species, mismatched, ckey)
	var/list/accessory_list = list()
	for(var/name in SSaccessories.sprite_accessories[key])
		var/datum/sprite_accessory/sprite_accessory = SSaccessories.sprite_accessories[key][name]
		if(sprite_accessory.locked)
			continue
		if(!mismatched && sprite_accessory.recommended_species && isnull(sprite_accessory.recommended_species[species.id]))
			continue
		accessory_list += sprite_accessory.name
	return accessory_list


/// The body markings a zone offers a species: all of them with mismatched parts, otherwise those meant for any species or this one.
/proc/body_markings_of_zone_for_species(zone, species_id, mismatched)
	var/list/markings = GLOB.body_markings_per_limb[zone]
	if(mismatched)
		return markings.Copy()
	. = list()
	for(var/marking_name in markings)
		var/datum/body_marking/marking = GLOB.body_markings[marking_name]
		if(marking.allows_species(species_id))
			. += marking_name

/**
 * Returns the body marking sets meant for any species or for this one, the "None" set included.
 *
 * Arguments:
 * - species_id: the species' id.
 *
 * Returns:
 * - list: a new list of /datum/body_marking_set typepaths in GLOB.body_marking_sets_by_type order, or null for none.
 */
/proc/body_marking_set_types_for_species(species_id)
	RETURN_TYPE(/list)
	for(var/set_type, set_datum in GLOB.body_marking_sets_by_type)
		var/datum/body_marking_set/marking_set = set_datum
		if(marking_set.allows_species(species_id))
			LAZYADD(., set_type)

/proc/random_accessory_of_key_for_species(key, datum/species/species, mismatched = FALSE, ckey)
	var/list/accessory_list = accessory_list_of_key_for_species(key, species, mismatched, ckey)
	var/datum/sprite_accessory/sprite_accessory = SSaccessories.sprite_accessories[key][pick(accessory_list)]
	if(isnull(sprite_accessory))
		CRASH("Cant find random accessory of [key] key, for species [species.id]")
	return sprite_accessory

/**
 * Builds a new collection wearing a marking set: each of its markings on every zone the marking claims, in the set's order.
 *
 * A marking's zones come in GLOB.body_markings_per_limb order, as scanning those lists for its name gave them, and each
 * marking starts in the colour its color_mode seeds. A member sharing an exclusion group with an earlier member stays off the
 * zones that one took.
 *
 * Arguments:
 * - marking_set: the set to wear. A member no marking is registered under adds nothing.
 * - features: the character's features, where markings following a mutant colour read it.
 * - species: the character's species.
 *
 * Returns:
 * - /datum/body_marking_collection: always a new collection.
 */
/proc/assemble_body_markings_from_set(datum/body_marking_set/marking_set, list/features, datum/species/species)
	RETURN_TYPE(/datum/body_marking_collection)
	var/datum/body_marking_collection/body_markings = new
	for(var/marking_type in marking_set.body_marking_list)
		var/datum/body_marking/body_marking = GLOB.body_markings_by_type[marking_type]
		if(!body_marking)
			continue
		var/color = body_marking.seed_color(features, species)
		for(var/zone in GLOB.body_markings_per_limb)
			if(body_marking.affected_bodyparts & GLOB.marking_zone_to_bitflag[zone])
				body_markings.add_entry(new /datum/body_marking_entry(body_marking, zone, color))
	return body_markings

/proc/random_bra(gender)
	switch(gender)
		if(MALE)
			return pick(SSaccessories.bra_m)
		if(FEMALE)
			return pick(SSaccessories.bra_f)
		else
			return pick(SSaccessories.bra_list)
