/**
 * A family on the species page.
 *
 * Species name theirs through /datum/species/proc/get_species_family(). The page lists the
 * families in sort_order, with the name and icon they give here.
 */
/datum/species_family
	abstract_type = /datum/species_family
	/// Shown on the family's tab and above each of its species' names.
	var/name
	/// A Font Awesome FA_ICON_* or a tgfont "tg-" icon, as quirks give theirs.
	var/icon
	/// Families are listed lowest first.
	var/sort_order = 0

/datum/species_family/mammalian
	name = "Mammalian"
	icon = FA_ICON_PAW
	sort_order = 1

/datum/species_family/reptilian
	name = "Reptilian"
	icon = FA_ICON_DRAGON
	sort_order = 2

/datum/species_family/avian
	name = "Avian"
	icon = FA_ICON_FEATHER_POINTED
	sort_order = 3

/datum/species_family/aquatic
	name = "Aquatic"
	icon = FA_ICON_FISH
	sort_order = 4

/datum/species_family/insectoid
	name = "Insectoid"
	icon = FA_ICON_BUG
	sort_order = 5

/datum/species_family/synthetic
	name = "Synthetic"
	icon = FA_ICON_ROBOT
	sort_order = 6

/datum/species_family/elemental
	name = "Elemental"
	icon = FA_ICON_GEM
	sort_order = 7

/datum/species_family/xenobiological
	name = "Exotic"
	icon = "tg-zaphelion-alien"
	sort_order = 8

/datum/species_family/paranormal
	name = "Paranormal"
	icon = FA_ICON_GHOST
	sort_order = 9

/// The id the species page knows a family by: the last part of its typepath.
/proc/species_family_id(datum/species_family/family_type)
	var/type_text = "[family_type]"
	return copytext(type_text, findlasttext(type_text, "/") + 1)

/proc/cmp_species_family_order(datum/species_family/a, datum/species_family/b)
	return initial(a.sort_order) - initial(b.sort_order)
