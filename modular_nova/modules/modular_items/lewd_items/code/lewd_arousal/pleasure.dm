/mob/living/carbon/human/proc/adjust_pleasure(pleas = 0)
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/client_interface/player = GET_CLIENT(src)
	if(stat >= DEAD || !player?.prefs?.read_preference(/datum/preference/toggle/erp))
		return

	pleasure = clamp(pleasure + pleas, AROUSAL_MINIMUM, AROUSAL_LIMIT)

	if(pleasure >= AROUSAL_AUTO_CLIMAX_THRESHOLD) // lets cum
		climax(manual = FALSE)
