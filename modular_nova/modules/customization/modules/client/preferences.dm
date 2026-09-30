/// Cleans up any invalid languages. Typically happens on language renames and codedels.
/datum/preferences/proc/sanitize_languages()
	var/species_type = read_preference(/datum/preference/choiced/species)
	var/datum/species/species = GLOB.species_prototypes[species_type]
	var/list/whitelist = species.language_prefs_whitelist

	var/languages_edited = FALSE
	var/list/to_remove = list()

	for (var/lang_path in languages)
		if (!lang_path)
			to_remove += lang_path
			continue

		var/datum/language/language_prototype = GLOB.language_datum_instances[lang_path]
		// Path no longer exists
		if (isnull(language_prototype))
			to_remove += lang_path
			continue

		// If it's a secret language, ensure it's allowed
		if (language_prototype.secret && whitelist && isnull(whitelist[lang_path]))
			to_remove += lang_path
			continue // APHELION EDIT ADDITION

		// APHELION EDIT ADDITION START - Spoken or understood, whatever a file from elsewhere holds: anything but LANGUAGE_SPOKEN was understood only.
		var/knowledge = sanitize_language_knowledge(languages[lang_path])
		if (isnull(knowledge))
			to_remove += lang_path
		else if (knowledge != languages[lang_path])
			languages[lang_path] = knowledge
			languages_edited = TRUE
		// APHELION EDIT ADDITION END

	// Only modify list once
	if (length(to_remove))
		languages -= to_remove
		languages_edited = TRUE

	// APHELION EDIT ADDITION START - A character left with no languages would spawn speaking none; the Languages page only filled them in while drawn.
	if (!length(languages))
		var/datum/language_holder/language_holder = GLOB.prototype_language_holders[species.species_language_holder]
		for (var/language in language_holder.spoken_languages)
			languages[language] = LANGUAGE_SPOKEN
		languages_edited = TRUE
	// APHELION EDIT ADDITION END

	return languages_edited

/// Cleans any quirks that should be hidden, or just simply don't exist from quirk code.
/datum/preferences/proc/sanitize_quirks()
	var/quirks_edited = FALSE
	for(var/datum/quirk/quirk as anything in all_quirks)
		if(!quirk || !(quirk in SSquirks.quirks))
			all_quirks.Remove(quirk)
			quirks_edited = TRUE
			continue

		quirk = SSquirks.quirks[quirk]
		// Explanation for this is above.
		if(!quirk || initial(quirk.hidden_quirk))
			all_quirks.Remove(quirk)
			quirks_edited = TRUE

	return quirks_edited
