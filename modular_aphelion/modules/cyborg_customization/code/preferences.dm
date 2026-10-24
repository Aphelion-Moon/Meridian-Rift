/// Character preferences consumed by the cyborg creator and live renderer. Layouts live in the cyborg_customization.json sidecar.
/// The ones only cyborgs have are manually rendered - the editor window shows them, character setup leaves them out.

/datum/preference/choiced/cyborg_sprite
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	should_update_preview = FALSE
	can_randomize = FALSE
	abstract_type = /datum/preference/choiced/cyborg_sprite
	/// The organ slot whose sprite accessories this preference offers
	var/accessory_slot

/datum/preference/choiced/cyborg_sprite/init_possible_values()
	var/list/choices = list(SPRITE_ACCESSORY_NONE)
	var/list/direct = cyborg_direct_accessories(accessory_slot)
	for(var/name in direct)
		choices |= name
	var/list/accessories = SSaccessories.sprite_accessories[accessory_slot]
	if(islist(accessories))
		for(var/name in accessories)
			if(accessory_slot == "anus" && name != SPRITE_ACCESSORY_NONE)
				continue // Meridian's anus accessory has no on-mob art; use authored cyborg choices.
			if(istext(name) && !(name in choices))
				choices += name
	return choices

/datum/preference/choiced/cyborg_sprite/create_default_value()
	return SPRITE_ACCESSORY_NONE

/datum/preference/choiced/cyborg_sprite/is_accessible(datum/preferences/preferences)
	return ..(preferences) && cyborg_visuals_allowed(preferences)

/datum/preference/choiced/cyborg_sprite/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/choiced/cyborg_sprite/penis
	savefile_key = "silicon_penis_sprite"
	accessory_slot = ORGAN_SLOT_PENIS

/datum/preference/choiced/cyborg_sprite/sheath
	savefile_key = "silicon_sheath_sprite"
	accessory_slot = ORGAN_SLOT_SHEATH

/datum/preference/choiced/cyborg_sprite/testicles
	savefile_key = "silicon_testicles_sprite"
	accessory_slot = ORGAN_SLOT_TESTICLES

/datum/preference/choiced/cyborg_sprite/vagina
	savefile_key = "silicon_vagina_sprite"
	accessory_slot = ORGAN_SLOT_VAGINA

/datum/preference/choiced/cyborg_sprite/anus
	savefile_key = "silicon_anus_sprite"
	accessory_slot = ORGAN_SLOT_ANUS

/datum/preference/choiced/cyborg_sprite/breasts
	savefile_key = "silicon_breasts_sprite"
	accessory_slot = ORGAN_SLOT_BREASTS

/datum/preference/choiced/cyborg_size
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "cyborg_size"
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/choiced/cyborg_size/init_possible_values()
	return list(0.75, 1, 1.6, 2, 2.5)

/datum/preference/choiced/cyborg_size/create_default_value()
	return 1

/// TGUI actions carry choiced values as text. Keep the stored preference numeric.
/datum/preference/choiced/cyborg_size/deserialize(input, datum/preferences/preferences)
	if(istext(input))
		input = text2num(input)
	return ..()

/datum/preference/choiced/cyborg_size/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/toggle/see_cyborg_genitalia
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_identifier = PREFERENCE_PLAYER
	savefile_key = "see_cyborg_genitalia"
	default_value = FALSE

/// The six cyborg profile fields retain their existing byte budgets. Native
/// byte-indexed truncation can split UTF-8; find a complete-character prefix.
/datum/preference/text/cyborg_profile
	abstract_type = /datum/preference/text/cyborg_profile

/datum/preference/text/cyborg_profile/deserialize(input, datum/preferences/preferences)
	if(!istext(input))
		return null
	var/byte_limit = maximum_value_length - 1
	// Every codepoint occupies at least one byte. Cap scanning/allocation before
	// searching, even when the supplied text is much larger than the field.
	var/bounded = copytext_char(input, 1, byte_limit + 1)
	if(length(bounded) > byte_limit)
		var/lower = 0
		var/upper = length_char(bounded)
		while(lower < upper)
			var/middle = round((lower + upper + 1) / 2)
			if(length(copytext_char(bounded, 1, middle + 1)) <= byte_limit)
				lower = middle
			else
				upper = middle - 1
		bounded = copytext_char(bounded, 1, lower + 1)
	return should_strip_html ? GLOB.angular_brackets.Replace(bounded, "") : bounded

/datum/preference/text/cyborg_profile/compile_constant_data()
	var/byte_limit = maximum_value_length - 1
	return list("maximum_length" = byte_limit, "maximum_bytes" = byte_limit)

/datum/preference/text/silicon_flavor_text
	parent_type = /datum/preference/text/cyborg_profile

/datum/preference/text/silicon_flavor_text_nsfw
	parent_type = /datum/preference/text/cyborg_profile

/datum/preference/text/custom_species_silicon
	parent_type = /datum/preference/text/cyborg_profile
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_species_silicon"
	maximum_value_length = 100
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/text/custom_species_silicon/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/custom_species_lore_silicon
	parent_type = /datum/preference/text/cyborg_profile
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_species_lore_silicon"
	maximum_value_length = MAX_FLAVOR_LEN
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/text/custom_species_lore_silicon/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/ooc_notes_silicon
	parent_type = /datum/preference/text/cyborg_profile
	category = PREFERENCE_CATEGORY_MANUALLY_RENDERED
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "ooc_notes_silicon"
	maximum_value_length = MAX_FLAVOR_LEN
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/text/ooc_notes_silicon/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/ooc_notes_silicon/nsfw
	savefile_key = "ooc_notes_silicon_nsfw"

/// Reads the silicon-specific text first without copying a human field into it.
/proc/cyborg_identity_text(datum/preferences/preferences, preference_type, fallback_preference_type)
	if(!preferences)
		return ""
	var/value = preferences.read_preference(preference_type)
	if(length(value))
		return value
	return preferences.read_preference(fallback_preference_type)

/** Returns the existing editor owner; preferences own only native persistence. */
/datum/preferences/proc/cyborg_session()
	RETURN_TYPE(/datum/preference_middleware/cyborg_character)
	return locate(/datum/preference_middleware/cyborg_character) in middleware
