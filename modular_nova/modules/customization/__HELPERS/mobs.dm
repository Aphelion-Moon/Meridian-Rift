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
		if(!marking.recommended_species || marking.recommended_species[species_id])
			. += marking_name

/proc/random_accessory_of_key_for_species(key, datum/species/species, mismatched = FALSE, ckey)
	var/list/accessory_list = accessory_list_of_key_for_species(key, species, mismatched, ckey)
	var/datum/sprite_accessory/sprite_accessory = SSaccessories.sprite_accessories[key][pick(accessory_list)]
	if(isnull(sprite_accessory))
		CRASH("Cant find random accessory of [key] key, for species [species.id]")
	return sprite_accessory

/proc/assemble_body_markings_from_set(datum/body_marking_set/marking_set, list/features, datum/species/species)
	var/list/body_markings = list()
	for(var/set_name in marking_set.body_marking_list)
		var/datum/body_marking/body_marking = GLOB.body_markings[set_name]
		for(var/zone, markings in GLOB.body_markings_per_limb)
			var/list/marking_list = markings
			if(set_name in marking_list)
				if(isnull(body_markings[zone]))
					body_markings[zone] = list()
				body_markings[zone][set_name] = list(body_marking.get_default_color(features, species), FALSE)
	return body_markings

/proc/random_bra(gender)
	switch(gender)
		if(MALE)
			return pick(SSaccessories.bra_m)
		if(FEMALE)
			return pick(SSaccessories.bra_f)
		else
			return pick(SSaccessories.bra_list)
