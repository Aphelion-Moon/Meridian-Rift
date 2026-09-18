/// Sent to a new Hemophage on spawn, because staying alive as one takes deliberate effort.
#define HEMOPHAGE_SPAWN_TEXT "You are a [span_danger("Hemophage")]. You will slowly but constantly lose blood. You may gain more blood by grabbing a live victim and using your drain ability."

/**
 * Makes the holder a Hemophage, whatever their species happens to be.
 *
 * Swaps the holder's heart, liver, stomach and tongue for their tumor-corrupted
 * counterparts, which is where nearly all Hemophage gameplay actually lives. The
 * pulsating tumor then reaches the lungs on its own through [/datum/element/tumor_corruption],
 * so they are only handled here on removal.
 */
/datum/quirk/hemophage
	name = "Hemophagia"
	desc = "A tumorous symbiont has taken root in your body. You no longer eat or breathe, only blood keeps you going."
	icon = FA_ICON_TEETH
	value = 0
	hardcore_value = 0
	quirk_flags = QUIRK_HUMAN_ONLY | QUIRK_HIDE_FROM_SCAN
	medical_record_text = "Patient's chest cavity is dominated by an unidentified tumorous mass, with corruption of the surrounding organ systems."
	mail_goodies = list(/obj/item/reagent_containers/blood/random)
	/// Organ slots the tumor takes over on gain, mapped to the corrupted organ that replaces them.
	var/static/list/corrupted_organs = list(
		ORGAN_SLOT_HEART = /obj/item/organ/heart/hemophage,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver/hemophage,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach/hemophage,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/hemophage,
	)
	/// Organ slots restored from the holder's own species on removal. The lungs are in here but
	/// not in `corrupted_organs`, because the tumor corrupts them itself rather than replacing them.
	var/static/list/restored_organ_slots = list(
		ORGAN_SLOT_HEART,
		ORGAN_SLOT_LIVER,
		ORGAN_SLOT_STOMACH,
		ORGAN_SLOT_TONGUE,
		ORGAN_SLOT_LUNGS,
	)
	/// Species that can never be Hemophages, subtypes included. There is no flesh here for the
	/// tumor to grow into, whatever else the species happens to claim about itself.
	var/static/list/species_blacklist = list(
		/datum/species/synthetic,
		/datum/species/golem,
		/datum/species/jelly,
	)
	/// The holder's own blood type, put back when the quirk is removed.
	var/datum/blood_type/original_blood_type

/datum/quirk/hemophage/add(client/client_source)
	var/mob/living/carbon/human/human_holder = quirk_holder

	human_holder.add_traits(list(
		TRAIT_NOHUNGER,
		TRAIT_NOBREATH,
		TRAIT_OXYIMMUNE,
		TRAIT_VIRUSIMMUNE,
		TRAIT_DRINKS_BLOOD,
	), QUIRK_TRAIT)

	if(client_source?.prefs.read_preference(/datum/preference/toggle/hemophage_masquerade))
		ADD_TRAIT(human_holder, TRAIT_MASQUERADE_FOOD, QUIRK_TRAIT)

	original_blood_type = human_holder.get_bloodtype()
	human_holder.set_blood_type(get_blood_type(/datum/blood_type/universal))
	MODIFY_PHYSIOLOGY(human_holder, PHYS_COEFF_BLEED, HEMOPHAGE_BLEED_MOD)

	for(var/organ_slot in corrupted_organs)
		var/organ_path = corrupted_organs[organ_slot]
		var/obj/item/organ/corrupted_organ = new organ_path()
		corrupted_organ.Insert(human_holder, special = TRUE, movement_flags = DELETE_IF_REPLACED)

/datum/quirk/hemophage/add_unique(client/client_source)
	quirk_holder.set_blood_volume(BLOOD_VOLUME_ROUNDSTART_HEMOPHAGE)

/datum/quirk/hemophage/post_add()
	to_chat(quirk_holder, HEMOPHAGE_SPAWN_TEXT)

/datum/quirk/hemophage/remove()
	if(QDELETED(quirk_holder))
		return

	var/mob/living/carbon/human/human_holder = quirk_holder

	human_holder.remove_traits(list(
		TRAIT_NOHUNGER,
		TRAIT_NOBREATH,
		TRAIT_OXYIMMUNE,
		TRAIT_VIRUSIMMUNE,
		TRAIT_DRINKS_BLOOD,
		TRAIT_MASQUERADE_FOOD,
	), QUIRK_TRAIT)

	human_holder.set_blood_type(original_blood_type)
	original_blood_type = null
	MODIFY_PHYSIOLOGY(human_holder, PHYS_COEFF_BLEED, 1 / HEMOPHAGE_BLEED_MOD)

	// Swapping the tumor out detaches the corruption element, so the replacements come back clean.
	for(var/organ_slot in restored_organ_slots)
		var/organ_path = human_holder.dna.species.get_mutant_organ_type_for_slot(organ_slot)
		// A null path means the holder's species is meant to have nothing in that slot, so the corrupted organ just goes.
		if(isnull(organ_path))
			var/obj/item/organ/unwanted_organ = human_holder.get_organ_slot(organ_slot)
			if(unwanted_organ)
				unwanted_organ.Remove(human_holder, special = TRUE)
				qdel(unwanted_organ)
			continue

		var/obj/item/organ/replacement_organ = new organ_path()
		replacement_organ.Insert(human_holder, special = TRUE, movement_flags = DELETE_IF_REPLACED)

	human_holder.set_blood_volume(BLOOD_VOLUME_NORMAL)

/datum/quirk/hemophage/is_species_appropriate(datum/species/mob_species)
	if(!..())
		return FALSE

	for(var/blacklisted_species in species_blacklist)
		if(ispath(mob_species, blacklisted_species))
			return FALSE

	var/datum/species/species_prototype = GLOB.species_prototypes[mob_species]
	if(!(species_prototype.inherent_biotypes & MOB_ORGANIC))
		return FALSE

	// A species with no blood has nothing for the tumor to live on, and one that already drinks it is a Hemophage in all but name.
	if((TRAIT_NOBLOOD in species_prototype.inherent_traits) || (TRAIT_DRINKS_BLOOD in species_prototype.inherent_traits))
		return FALSE

	// Neither does a species whose veins carry something that isn't blood at all.
	var/datum/blood_type/species_blood = species_prototype.exotic_bloodtype ? get_blood_type(species_prototype.exotic_bloodtype) : null
	if(species_blood && species_blood.reagent_type != /datum/reagent/blood)
		return FALSE

	return TRUE

/datum/quirk_constant_data/hemophage
	associated_typepath = /datum/quirk/hemophage
	customization_options = list(/datum/preference/toggle/hemophage_masquerade)

/datum/preference/toggle/hemophage_masquerade
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_key = "hemophage_masquerade"
	savefile_identifier = PREFERENCE_CHARACTER
	can_randomize = FALSE
	default_value = FALSE

/datum/preference/toggle/hemophage_masquerade/is_accessible(datum/preferences/preferences)
	if(!..(preferences))
		return FALSE

	return /datum/quirk/hemophage::name in preferences.all_quirks

/datum/preference/toggle/hemophage_masquerade/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

#undef HEMOPHAGE_SPAWN_TEXT
