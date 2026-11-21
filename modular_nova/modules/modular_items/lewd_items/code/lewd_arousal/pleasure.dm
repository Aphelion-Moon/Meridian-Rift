/**
 * Adds pleasure, and climaxes once it reaches the threshold.
 *
 * Arguments:
 * * pleas - how much pleasure to add, negative to take some away
 * * stimulated_slot - the organ slot the pleasure came from, if known, passed on to climax()
 */
/mob/living/carbon/human/proc/adjust_pleasure(pleas = 0, stimulated_slot)
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/client_interface/player = GET_CLIENT(src)
	if(stat >= DEAD || !player?.prefs?.read_preference(/datum/preference/toggle/erp))
		return

	pleasure = clamp(pleasure + pleas, AROUSAL_MINIMUM, AROUSAL_LIMIT)

	if(pleasure >= AROUSAL_AUTO_CLIMAX_THRESHOLD) // lets cum
		climax(manual = FALSE, stimulated_slot = stimulated_slot)
