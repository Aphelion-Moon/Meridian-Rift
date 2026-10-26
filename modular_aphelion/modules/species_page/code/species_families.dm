/**
 * A family on the species page.
 *
 * GLOB.species_page_families files each species under one; see /datum/species/proc/get_species_family().
 * The page lists the families in sort_order, with the name and icon they give here.
 */
/datum/species_family
	abstract_type = /datum/species_family
	/// Shown on the family's tab and above each of its species' names.
	var/name
	/// A Font Awesome FA_ICON_* or a tgfont "tg-" icon, as quirks give theirs.
	var/icon
	/// Families are listed lowest first.
	var/sort_order = 0

/// Humans and the other mammals.
/datum/species_family/mammalian
	name = "Mammalian"
	icon = FA_ICON_PAW
	sort_order = 1

/// Lizardfolk and the other scaled species.
/datum/species_family/reptilian
	name = "Reptilian"
	icon = FA_ICON_DRAGON
	sort_order = 2

/// The feathered species.
/datum/species_family/avian
	name = "Avian"
	icon = FA_ICON_FEATHER_POINTED
	sort_order = 3

/// Species from the sea.
/datum/species_family/aquatic
	name = "Aquatic"
	icon = FA_ICON_FISH
	sort_order = 4

/// Insects and their kin.
/datum/species_family/insectoid
	name = "Insectoid"
	icon = FA_ICON_BUG
	sort_order = 5

/// Built bodies: androids, holosynths and proteans.
/datum/species_family/synthetic
	name = "Synthetic"
	icon = FA_ICON_ROBOT
	sort_order = 6

/// Living energy, mineral, plasma and plant.
/datum/species_family/elemental
	name = "Elemental"
	icon = FA_ICON_GEM
	sort_order = 7

/// Shown as Exotic: aliens, slimes and other strange life.
/datum/species_family/xenobiological
	name = "Exotic"
	icon = "tg-zaphelion-alien"
	sort_order = 8

/// The undead and the uncanny.
/datum/species_family/paranormal
	name = "Paranormal"
	icon = FA_ICON_GHOST
	sort_order = 9

/// Every species waiting for its holiday, whatever its own family. See get_holiday().
/datum/species_family/holiday
	name = "Holiday"
	icon = FA_ICON_GIFT
	sort_order = 10

/// The id the species page knows a family by: the last part of its typepath.
/proc/species_family_id(datum/species_family/family_type)
	var/type_text = "[family_type]"
	return copytext(type_text, findlasttext(type_text, "/") + 1)

/// Sorts species family types by sort_order, lowest first.
/proc/cmp_species_family_order(datum/species_family/a, datum/species_family/b)
	return initial(a.sort_order) - initial(b.sort_order)
