/// Species id -> the holiday that makes it a roundstart race, filled on first use by get_holiday_races().
GLOBAL_LIST_EMPTY(holiday_races)

/// Stand-in text some species return instead of a description or lore.
GLOBAL_LIST_INIT(species_page_filler_text, list(
	"Make sure you fill out your own custom species lore!",
	"No species description set, file a bug report!",
	"No species lore set, file a bug report!",
	"Nothing yet.",
	"Plant lore!",
	"You're a plant!",
))

/**
 * Species that are roundstart races only during a holiday, as an assoc list of id to holiday.
 *
 * Character setup offers them all year. Joining is still gated by
 * check_roundstart_eligible(), since jobs refuse species missing from the roundstart races.
 */
/proc/get_holiday_races()
	RETURN_TYPE(/list)

	if (!length(GLOB.holiday_races))
		GLOB.holiday_races = generate_holiday_races()

	return GLOB.holiday_races

/// Every species with a holiday of its own that the roundstart races config doesn't already allow: id -> holiday.
/proc/generate_holiday_races()
	var/list/holiday_races = list()
	var/list/configured_races = CONFIG_GET(keyed_list/roundstart_races)

	for (var/species_type in subtypesof(/datum/species))
		var/datum/species/species = GLOB.species_prototypes[species_type]
		var/holiday = species.get_holiday()
		// A species the config always allows has nothing to wait for.
		if (holiday && !(species.id in configured_races))
			holiday_races[species.id] = holiday

	return holiday_races

/// Every species the species page offers, as an assoc list of id to TRUE.
/proc/get_species_page_ids()
	RETURN_TYPE(/list)

	var/list/species_ids = list()
	for (var/species_id in get_selectable_species() + get_customizable_races() + get_holiday_races())
		species_ids[species_id] = TRUE

	return species_ids

/// The holiday that makes this species a roundstart race, if any, mirroring the check_holidays() gate in its
/// check_roundstart_eligible().
/datum/species/proc/get_holiday()
	return null

/// The /datum/species_family the species page files this species under: GLOB.species_page_families' entry for its
/// type, or else for its nearest listed parent. Null files it as unclassified.
/datum/species/proc/get_species_family()
	var/listed
	for(var/path in GLOB.species_page_families)
		if(istype(src, path) && (!listed || ispath(path, listed)))
			listed = path
	return listed ? GLOB.species_page_families[listed] : null

/**
 * The species this one is a variant of on the species page: its parent type, when the
 * page offers that too.
 *
 * Arguments:
 * * page_ids - The species the page offers, from get_species_page_ids().
 */
/datum/species/proc/get_variant_of(list/page_ids)
	var/datum/species/parent = GLOB.species_prototypes[parent_type]
	if (isnull(parent) || parent.id == id || !page_ids[parent.id])
		return null
	return parent.id

/// Whether some description or lore text is worth showing, rather than a placeholder.
/datum/species/proc/is_species_page_text(text)
	if (!istext(text) || !length(trim(text)))
		return FALSE
	if (text == placeholder_description || text == placeholder_lore)
		return FALSE
	return !(text in GLOB.species_page_filler_text)

/// The description for the species page, or null when all the species has is filler.
/datum/species/proc/get_species_page_description()
	var/description = get_species_description()
	return is_species_page_text(description) ? description : null

/// The lore for the species page, or null when all the species has is filler.
/datum/species/proc/get_species_page_lore()
	RETURN_TYPE(/list)

	var/list/kept_lore
	for (var/paragraph in get_species_lore())
		if (is_species_page_text(paragraph))
			LAZYADD(kept_lore, paragraph)

	return kept_lore

/**
 * Adds what the species page needs beyond the preference's species data: the family,
 * the species this is a variant of, whether it is a template, and what keeps it off the
 * station, if anything.
 *
 * Arguments:
 * * entry - The species' entry in the species preference's constant data.
 * * page_ids - The species the page offers, from get_species_page_ids().
 */
/datum/species/proc/add_species_page_data(list/entry, list/page_ids)
	var/holiday = get_holiday_races()[id]
	// A holiday species waits under Holiday, where the page's holiday toggle shows and hides it.
	var/datum/species_family/family = holiday ? /datum/species_family/holiday : get_species_family()
	entry["family"] = family ? species_family_id(family) : null
	entry["variant_of"] = get_variant_of(page_ids)
	entry["template"] = !!GLOB.species_page_templates[type]
	entry["holiday"] = holiday
	entry["holiday_active"] = !!(holiday && check_holidays(holiday))
	entry["off_station"] = !holiday && !get_selectable_species()[id]
