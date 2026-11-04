/// Lists Bald first in the picker.
/datum/preference/choiced/hairstyle/init_possible_values()
	return list(/datum/sprite_accessory/hair/bald::name) | ..()

/// Lists Shaved first in the picker.
/datum/preference/choiced/facial_hairstyle/init_possible_values()
	return list(/datum/sprite_accessory/facial_hair/shaved::name) | ..()
