/// Character preferences consumed by the cyborg creator and later live renderer.

/datum/preference/cyborg_layout
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "silicon_genital_layout_presets"
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/cyborg_layout/deserialize(input, datum/preferences/preferences)
	return cyborg_layout_normalize(input)

/datum/preference/cyborg_layout/serialize(input)
	return cyborg_layout_normalize(input)

/datum/preference/cyborg_layout/create_default_value()
	return cyborg_layout_default()

/datum/preference/cyborg_layout/is_valid(value, datum/preferences/preferences)
	if(!islist(value))
		return FALSE
	var/list/normalized = cyborg_layout_normalize(value)
	return normalized["schema_version"] == CYBORG_LAYOUT_SCHEMA_VERSION

/datum/preference/cyborg_layout/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/choiced/cyborg_sprite
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	should_update_preview = FALSE
	can_randomize = FALSE
	abstract_type = /datum/preference/choiced/cyborg_sprite
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
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
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

/datum/preference/text/cyborg_identity
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	should_update_preview = FALSE
	can_randomize = FALSE
	abstract_type = /datum/preference/text/cyborg_identity

/datum/preference/text/cyborg_identity/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/custom_species_silicon
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_species_silicon"
	maximum_value_length = 100
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/text/custom_species_silicon/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/custom_species_lore_silicon
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "custom_species_lore_silicon"
	maximum_value_length = MAX_FLAVOR_LEN
	should_update_preview = FALSE
	can_randomize = FALSE

/datum/preference/text/custom_species_lore_silicon/apply_to_human(mob/living/carbon/human/target, value, datum/preferences/preferences)
	return

/datum/preference/text/ooc_notes_silicon
	category = PREFERENCE_CATEGORY_NON_CONTEXTUAL
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

/proc/cyborg_layout_preference_types()
	return list(
		"layout" = /datum/preference/cyborg_layout,
		"sprites" = list(
			"penis" = /datum/preference/choiced/cyborg_sprite/penis,
			"sheath" = /datum/preference/choiced/cyborg_sprite/sheath,
			"testicles" = /datum/preference/choiced/cyborg_sprite/testicles,
			"vagina" = /datum/preference/choiced/cyborg_sprite/vagina,
			"anus" = /datum/preference/choiced/cyborg_sprite/anus,
			"breasts" = /datum/preference/choiced/cyborg_sprite/breasts,
		),
		"size" = /datum/preference/choiced/cyborg_size,
		"viewer" = /datum/preference/toggle/see_cyborg_genitalia,
	)

#define CYBORG_LAYOUT_DRAFT_DELAY 20

/// Starts a draft for the current character slot and returns an isolated copy.
/datum/preferences/proc/cyborg_layout_begin_draft()
	if(cyborg_layout_draft && cyborg_layout_draft_slot == default_slot)
		return cyborg_layout_copy(cyborg_layout_draft)
	var/list/save_data = get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)
	if(cyborg_layout_import_is_future(save_data?["silicon_genital_layout_presets"]))
		return null
	var/list/current = read_preference(/datum/preference/cyborg_layout)
	cyborg_layout_discard_draft("replace_draft")
	cyborg_layout_draft_slot = default_slot
	cyborg_layout_draft = cyborg_layout_copy(current)
	cyborg_layout_draft_revision++
	return cyborg_layout_copy(cyborg_layout_draft)

/// Accepts only a current-schema layout and debounces its durable save.
/datum/preferences/proc/cyborg_layout_update_draft(layout)
	if(!cyborg_layout_draft || cyborg_layout_draft_slot != default_slot || !islist(layout))
		return FALSE
	var/version = layout["schema_version"]
	if(!isnull(version) && (!isnum(version) || version > CYBORG_LAYOUT_SCHEMA_VERSION))
		return FALSE
	cyborg_layout_draft = cyborg_layout_normalize(layout)
	cyborg_layout_draft_revision++
	if(cyborg_layout_draft_timer)
		deltimer(cyborg_layout_draft_timer)
	cyborg_layout_draft_timer = addtimer(CALLBACK(src, PROC_REF(cyborg_layout_flush_timer), cyborg_layout_draft_slot, cyborg_layout_draft_revision), CYBORG_LAYOUT_DRAFT_DELAY, TIMER_STOPPABLE)
	return TRUE

/// Persists the active draft into its bound slot's save data, but never another slot.
/datum/preferences/proc/cyborg_layout_flush_draft(reason)
	if(cyborg_layout_draft_timer)
		deltimer(cyborg_layout_draft_timer)
		cyborg_layout_draft_timer = null
	if(!cyborg_layout_draft)
		return TRUE
	if(cyborg_layout_draft_slot != default_slot)
		cyborg_layout_discard_draft("stale_[reason]")
		return FALSE
	var/list/draft = cyborg_layout_copy(cyborg_layout_draft)
	var/datum/preference/cyborg_layout/preference = GLOB.preference_entries[/datum/preference/cyborg_layout]
	if(isnull(get_save_data_for_savefile_identifier(PREFERENCE_CHARACTER)))
		savefile.set_entry("character[default_slot]", list())
	if(!write_preference(preference, preference.serialize(draft)))
		return FALSE
	recently_updated_keys -= preference.type
	cyborg_layout_discard_draft("flush_[reason]")
	return TRUE

/// Timer callbacks must prove that the slot and revision still own the draft.
/datum/preferences/proc/cyborg_layout_flush_timer(slot, revision)
	if(slot != default_slot || slot != cyborg_layout_draft_slot || revision != cyborg_layout_draft_revision)
		return
	cyborg_layout_draft_timer = null
	if(!cyborg_layout_flush_draft("timer"))
		return
	save_character()
	save_preferences()

/// Drops both data and callback authority. Use before deletion or import replacement.
/datum/preferences/proc/cyborg_layout_discard_draft(reason)
	if(cyborg_layout_draft_timer)
		deltimer(cyborg_layout_draft_timer)
		cyborg_layout_draft_timer = null
	cyborg_layout_draft = null
	cyborg_layout_draft_slot = null
	cyborg_layout_draft_revision++
	return TRUE

#undef CYBORG_LAYOUT_DRAFT_DELAY
