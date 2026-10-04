/// Lets the character setup menu play a preview of the currently selected sound effect
/datum/preference_middleware/vocal_preview
	/// Cooldown on requesting a scream preview.
	COOLDOWN_DECLARE(scream_preview_cooldown)
	/// Cooldown on requesting a laugh preview.
	COOLDOWN_DECLARE(laugh_preview_cooldown)

	action_delegations = list(
		"play_scream_preview" = PROC_REF(play_scream_preview),
		"play_laugh_preview" = PROC_REF(play_laugh_preview),
	)

/// Plays a preview of the user's currently selected scream type.
/datum/preference_middleware/vocal_preview/proc/play_scream_preview(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, scream_preview_cooldown))
		return TRUE

	var/scream_name = preferences.read_preference(/datum/preference/choiced/scream)
	var/datum/scream_type/chosen_scream = GLOB.scream_types_by_name[scream_name]
	if(!chosen_scream)
		return TRUE

	var/list/scream_sounds = chosen_scream.scream_sounds
	if(user.gender == FEMALE && chosen_scream.female_scream_type)
		var/datum/scream_type/female_scream = GLOB.scream_types[chosen_scream.female_scream_type]
		scream_sounds = female_scream.scream_sounds
	if(!length(scream_sounds))
		return TRUE

	user.playsound_local(user, pick(scream_sounds), 50, TRUE)
	COOLDOWN_START(src, scream_preview_cooldown, 2 SECONDS)
	return TRUE

/// Plays a preview of the user's currently selected laugh type.
/datum/preference_middleware/vocal_preview/proc/play_laugh_preview(list/params, mob/user)
	if(!COOLDOWN_FINISHED(src, laugh_preview_cooldown))
		return TRUE

	var/laugh_name = preferences.read_preference(/datum/preference/choiced/laugh)
	var/datum/laugh_type/chosen_laugh = GLOB.laugh_types_by_name[laugh_name]
	if(!chosen_laugh)
		return TRUE

	var/list/laugh_sounds = chosen_laugh.laugh_sounds
	if(user.gender != MALE && chosen_laugh.female_laugh_type)
		var/datum/laugh_type/female_laugh = GLOB.laugh_types[chosen_laugh.female_laugh_type]
		laugh_sounds = female_laugh.laugh_sounds
	if(!length(laugh_sounds))
		return TRUE

	user.playsound_local(user, pick(laugh_sounds), 50, TRUE)
	COOLDOWN_START(src, laugh_preview_cooldown, 2 SECONDS)
	return TRUE
