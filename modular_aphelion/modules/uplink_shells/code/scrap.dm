/// Personal shells are disposable; private previews never produce salvage or possessions.
/mob/living/carbon/human/uplink
	/// Prevent death, retirement and destruction from releasing the same contents twice.
	var/scrapping = FALSE

/mob/living/carbon/human/uplink/death(gibbed)
	. = ..()
	if(. && !provisional)
		// Finish the death stack before deleting organs and the body itself.
		addtimer(CALLBACK(src, PROC_REF(scrap_uplink)), 0, TIMER_UNIQUE)

/mob/living/carbon/human/uplink/gib(drop_bitflags = NONE)
	if(provisional)
		return ..()
	death(TRUE)
	return scrap_uplink()

/mob/living/carbon/human/uplink/dust(just_ash, drop_items, give_moodlet = TRUE, force)
	if(provisional)
		return ..()
	death(TRUE)
	return scrap_uplink()

/// End control before dismantling; equipped and stored possessions survive on the body's turf.
/mob/living/carbon/human/uplink/proc/scrap_uplink()
	if(provisional || scrapping || QDELETED(src))
		return FALSE
	var/turf/floor = get_turf(src)
	if(!floor)
		return FALSE
	if(ai_shell_session && !ai_shell_session.finish("Uplink scrapped"))
		// A newly occupied receiving core must never be overwritten, even during destruction.
		ai_shell_session.finish("Uplink destroyed; core unavailable", terminal = TRUE)
	scrapping = TRUE
	retired = TRUE
	stow_uplink_tools()
	update_uplink_camera()
	if(buckled)
		buckled.unbuckle_mob(src, force = TRUE)
	unbuckle_all_mobs(force = TRUE)
	// The quirk owns this helper. Release its occupants before quirk cleanup moves it to nullspace.
	for(var/obj/item/belly_function/belly in contents)
		for(var/mob/living/carbon/human/occupant as anything in LAZYCOPY(belly.nommeds))
			belly.free_target(occupant)
			occupant.forceMove(floor)
	for(var/obj/item/implant/storage/storage_implant in implants)
		for(var/atom/movable/possession as anything in storage_implant.contents.Copy())
			possession.forceMove(floor)
	var/list/gear = get_all_gear(INCLUDE_ACCESSORIES, recursive = FALSE)
	drop_everything(force = TRUE)
	for(var/obj/item/possession as anything in gear)
		if(!QDELETED(possession))
			possession.forceMove(floor)
	for(var/atom/movable/possession as anything in contents.Copy())
		if((possession in organs) || (possession in bodyparts) || (possession in implants) || istype(possession, /obj/item/belly_function))
			continue
		if(isitem(possession) || isliving(possession))
			possession.forceMove(floor)
	new /obj/effect/decal/remains/robot/uplink(floor)
	visible_message(span_notice("[src] collapses into a heap of scrap, leaving its possessions on the floor."))
	qdel(src)
	return TRUE

/// Uses the existing robot debris sprite and cleanup interactions.
/obj/effect/decal/remains/robot/uplink
	name = "Uplink scrap heap"
	desc = "The dismantled remains of a personal AI shell."
