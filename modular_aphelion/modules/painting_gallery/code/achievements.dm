/// Called after original-canvas finalization or a successful manual visibility save.
/datum/painting/proc/award_public_gallery_achievement(mob/user)
	if(!user?.client || creator_ckey != user.client.ckey || show_in_webgallery != TRUE)
		return
	user.client.give_award(/datum/award/achievement/misc/public_painter, user)
