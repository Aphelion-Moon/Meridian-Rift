/// The least of a language one only understood can be set to follow: Common Second Language's lowest setting.
#define LANGUAGE_UNDERSTANDING_MIN 25
/// The steps a level moves in.
#define LANGUAGE_UNDERSTANDING_STEP 5
/// The line the Languages page shows as a character would hear it, at the level they follow.
#define LANGUAGE_UNDERSTANDING_SAMPLE "Could you tell me where the medical bay is? My friend is hurt and we need help right away."

/datum/preferences
	/// How much of each language the character only understands they follow, in percent, where that is less than all of
	/// it: language type -> level. Null while every one of them is followed in full.
	var/list/language_understanding

/// How much of a language the character follows, in percent: all of any they speak, or only understand in full.
/datum/preferences/proc/language_understanding_level(language)
	if(languages?[language] != LANGUAGE_UNDERSTOOD)
		return 100
	return language_understanding?[language] || 100

/// The levels worth saving: understood-only languages set below full, keyed by their type as text. Null if none.
/datum/preferences/proc/saved_language_understanding()
	if(!length(language_understanding))
		return null
	var/list/saved
	for(var/language, level in language_understanding)
		if(languages?[language] == LANGUAGE_UNDERSTOOD && level < 100)
			LAZYSET(saved, "[language]", level)
	return saved

/// Saved levels read back: known language types only, each snapped to a step and kept within range. Null if none.
/proc/sanitize_language_understanding(list/saved)
	if(!islist(saved))
		return null
	var/list/levels
	for(var/key, value in saved)
		var/language = istext(key) ? text2path(key) : key
		if(!ispath(language, /datum/language) || isnull(GLOB.language_datum_instances[language]) || !isnum(value))
			continue
		var/level = snap_language_understanding(value)
		if(level < 100)
			LAZYSET(levels, language, level)
	return levels

/// A level snapped to a whole step, between the least allowed and all of it.
/proc/snap_language_understanding(level)
	return clamp(round(level, LANGUAGE_UNDERSTANDING_STEP), LANGUAGE_UNDERSTANDING_MIN, 100)

/// A sample line in a language, as heard by someone who follows this much of it. Kept, so a level's sample stays put.
/proc/language_understanding_sample(language, level)
	var/static/alist/samples = alist()
	var/key = "[language]-[level]"
	. = samples[key]
	if(isnull(.))
		var/datum/language/prototype = GLOB.language_datum_instances[language]
		. = prototype.scramble_paragraph(LANGUAGE_UNDERSTANDING_SAMPLE, list((language) = level))
		samples[key] = .

/**
 * A language a character only understands can be followed in part, from LANGUAGE_UNDERSTANDING_MIN to all of it; the
 * level is granted as the language holder's partial understanding, which catches that share of words, more of the
 * common ones. See /datum/language_holder/proc/adjust_languages_to_prefs(). Speaking a language means following it.
 */
/datum/preference_middleware/language_understanding
	action_delegations = list(
		"set_language_understanding" = PROC_REF(set_language_understanding),
	)

/// The level and a sample line for every language the character only understands, by the name the page shows.
/datum/preference_middleware/language_understanding/get_ui_data(mob/user)
	var/list/levels = list()
	var/list/samples = list()
	if(!length(preferences.languages))
		return list("language_understanding" = levels, "language_understanding_samples" = samples)
	for(var/language, knowledge in preferences.languages)
		if(knowledge != LANGUAGE_UNDERSTOOD)
			continue
		var/datum/language/prototype = GLOB.language_datum_instances[language]
		if(isnull(prototype))
			continue
		var/level = preferences.language_understanding_level(language)
		levels[prototype.name] = level
		samples[prototype.name] = language_understanding_sample(language, level)
	return list(
		"language_understanding" = levels,
		"language_understanding_samples" = samples,
	)

/// Sets how much of a language the character only understands they follow.
/datum/preference_middleware/language_understanding/proc/set_language_understanding(list/params, mob/user)
	var/language = language_named(params["language_name"])
	var/level = params["level"]
	if(isnull(language) || preferences.languages?[language] != LANGUAGE_UNDERSTOOD || !isnum(level))
		return FALSE
	level = snap_language_understanding(level)
	if(level >= 100)
		LAZYREMOVE(preferences.language_understanding, language)
	else
		LAZYSET(preferences.language_understanding, language, level)
	return TRUE

/// The language type with this name, or null.
/datum/preference_middleware/language_understanding/proc/language_named(name)
	var/static/alist/by_name
	if(isnull(by_name))
		by_name = alist()
		for(var/language, prototype in GLOB.language_datum_instances)
			var/datum/language/instance = prototype
			by_name[instance.name] = language
	return istext(name) ? by_name[name] : null

#undef LANGUAGE_UNDERSTANDING_MIN
#undef LANGUAGE_UNDERSTANDING_STEP
#undef LANGUAGE_UNDERSTANDING_SAMPLE
