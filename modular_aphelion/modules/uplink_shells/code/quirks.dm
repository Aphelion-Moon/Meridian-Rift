/// Physical quirk setup runs for every body; ordinary supplies belong to the first issuance.
/datum/quirk/proc/uplink_gifts_allowed()
	if(!istype(quirk_holder, /mob/living/carbon/human/uplink))
		return TRUE
	var/mob/living/carbon/human/uplink/body = quirk_holder
	return body.issue_quirk_items
