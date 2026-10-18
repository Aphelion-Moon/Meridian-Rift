/**
 * EXTRA MOB VV
 */
/mob/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION(VV_HK_SEND_CRYO, "Send to Cryogenic Storage")
	VV_DROPDOWN_OPTION(VV_HK_LOAD_PREFS, "Load Prefs Onto Mob")

/mob/vv_do_topic(list/href_list)
	. = ..()
	if(href_list[VV_HK_SEND_CRYO])
		vv_send_cryo()


	if(href_list[VV_HK_LOAD_PREFS])
		vv_load_prefs()

/**
 * Sends said person to a cryopod.
 */
/mob/proc/vv_send_cryo()
	if(!check_rights(R_SPAWN))
		return

	var/send_notice = tgui_alert(usr, "Add a paper notice about sending [name] into a cryopod?", "Leave a paper?", list("Yes", "No", "Cancel"))
	if(send_notice != "Yes" && send_notice != "No")
		return

	//log/message
	to_chat(usr, "Put [src] in cryopod.")
	log_admin("[key_name(usr)] has put [key_name(src)] into a cryopod.")
	var/msg = span_notice("[key_name_admin(usr)] has put [key_name(src)] into a cryopod from [ADMIN_VERBOSEJMP(src)].")
	message_admins(msg)
	admin_ticket_log(src, msg)

	send_notice = send_notice == "Yes"
	send_to_cryo(send_notice)

/**
 * Overrides someones mob with their loaded prefs.
 */
/mob/proc/vv_load_prefs()
	if(!check_rights(R_ADMIN))
		return

	if(!client)
		to_chat(usr, span_warning("No client found!"))
		return

	if(!ishuman(src))
		to_chat(usr, span_warning("Mob is not human!"))
		return

	var/mob/living/carbon/human/human_mob = src
	var/client/target_client = client
	var/datum/preferences/target_preferences = target_client.prefs
	if(!human_mob.vv_prefs_target_valid(target_client, target_preferences))
		return

	var/notice = tgui_alert(usr, "Are you sure you want to load the clients current prefs onto their mob?", "Load Preferences", list("Yes", "No"))
	if(notice != "Yes" || QDELETED(human_mob) || !human_mob.vv_prefs_target_valid(target_client, target_preferences))
		return
	var/quirks_prompt = tgui_alert(usr, "Reload their quirks too? This will clear any existing quirks on the mob.", "Load Quirks", list("Yes", "No"))

	if((quirks_prompt != "Yes" && quirks_prompt != "No") || QDELETED(human_mob) || !human_mob.vv_prefs_target_valid(target_client, target_preferences))
		return
	human_mob.dna.mutant_bodyparts = list()
	human_mob.dna.species.regenerate_organs(src, replace_current = TRUE)
	target_preferences.apply_prefs_to(src, icon_updates = FALSE)
	human_mob.dna.update_body_size()
	human_mob.update_body(is_creating = TRUE)
	if(quirks_prompt == "Yes")
		human_mob.cleanse_quirk_datums()
		SSquirks.AssignQuirks(src, target_client)
	SEND_SIGNAL(human_mob, COMSIG_HUMAN_CHARACTER_SETUP_FINISHED)
	var/msg = span_notice("[key_name_admin(usr)] has loaded [key_name(src)]'s preferences onto their current mob [ADMIN_VERBOSEJMP(src)].")
	message_admins(msg)
	admin_ticket_log(src, msg)

/**
 * Whether the client/preferences captured before an admin prompt still own this live human.
 * BYOND's client.mob relationship identifies the same connection after a body transfer or disconnect.
 */
/mob/living/carbon/human/proc/vv_prefs_target_valid(client/target_client, datum/preferences/target_preferences)
	return !QDELETED(src) && !QDELETED(dna) && target_client?.mob == src && !QDELETED(target_preferences) && target_client.prefs == target_preferences && target_preferences.parent == target_client
