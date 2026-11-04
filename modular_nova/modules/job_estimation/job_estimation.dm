
/datum/config_entry/flag/show_job_estimation
	default = TRUE

/datum/preference/toggle/ready_job
	savefile_key = "ready_job"
	savefile_identifier = PREFERENCE_PLAYER
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	default_value = TRUE

/datum/preference/toggle/ready_job/apply_to_human(mob/living/carbon/human/target, value, /datum/preferences/preferences)
	return FALSE

/datum/preference/toggle/ready_job/apply_to_client_updated(client/client, value)
	. = ..()
	SSstatpanels.update_job_estimation(ckey = client.ckey)

/datum/controller/subsystem/statpanels
	/// The assoc list of job estimation data keyed to player ref. data format: list(estimation_string, ckey)
	var/list/player_ready_data = list()
	/// The assoc list of job estimation data keyed to player ref (for command players only). data format: list(estimation_string, ckey)
	var/list/command_player_ready_data = list()
	/// The assoc list of job estimation data keyed to player ref (for assistant players only). data format: list(estimation_string, ckey)
	var/list/assistant_player_ready_data = list()

#define INDEX_PLAYER_DATA 1
#define INDEX_PLAYER_CKEY 2
/// Returns the list of job estimation strings that get output to the stat panel. First to ready up get listed first. Command roles get displayed before all the rest.
/datum/controller/subsystem/statpanels/proc/get_job_estimation(mob/dead/recipient)
	var/list/job_estimation = list(
		"",
		"------------------",
		"Job Estimation:",
		"",
	)
	var/is_admin = check_rights_for(recipient.client, R_ADMIN)
	for(var/player_ref, player_data in command_player_ready_data) // Command and silicons first
		job_estimation += "[player_data[INDEX_PLAYER_DATA]][is_admin ? " ([player_data[INDEX_PLAYER_CKEY]])" : ""]"

	for(var/player_ref, player_data in player_ready_data)
		job_estimation += "[player_data[INDEX_PLAYER_DATA]][is_admin ? " ([player_data[INDEX_PLAYER_CKEY]])" : ""]"

	for(var/player_ref, player_data in assistant_player_ready_data) // Assistants last
		job_estimation += "[player_data[INDEX_PLAYER_DATA]][is_admin ? " ([player_data[INDEX_PLAYER_CKEY]])" : ""]"

	return job_estimation
#undef INDEX_PLAYER_DATA
#undef INDEX_PLAYER_CKEY

/// Adds a player to the ready estimation
/datum/controller/subsystem/statpanels/proc/add_job_estimation(mob/dead/new_player/player)
	if(isnull(player.client))
		return
	if(!CONFIG_GET(flag/show_job_estimation))
		return

	var/datum/preferences/prefs = player.client?.prefs
	var/datum/job/player_job = prefs?.get_highest_priority_job()

	// If a player does not have preferences (for some reason), don't add them
	if(!player_job)
		return

	var/title = player_job.title
	var/display
	// people who have opted out of giving their name will show up as 'a mysterious [job title here]', unless they're command or AI
	if(!prefs.read_preference(/datum/preference/toggle/ready_job) && !(player_job.departments_bitflags & (DEPARTMENT_BITFLAG_COMMAND)) && title != JOB_AI)
		display = "a mysterious"
	else
		// If the job the player is selecting has a special name, that name should be displayed in the menu, otherwise it should use the normal name
		switch(title)
			if(JOB_AI)
				display = prefs.read_preference(/datum/preference/name/ai)
			if(JOB_CLOWN)
				display = prefs.read_preference(/datum/preference/name/clown)
			if(JOB_CYBORG)
				display = prefs.read_preference(/datum/preference/name/cyborg)
			if(JOB_MIME)
				display = prefs.read_preference(/datum/preference/name/mime)
			else
				display = prefs.read_preference(/datum/preference/name/real_name)
		display += " as"

	var/player_ref = REF(player)
	if(isnull(display) || isnull(player_ref))
		return

	/// The string as it appears in the stat panel
	var/job_estimation_text = "* [display] [player.client?.prefs?.get_alt_job_title(title) || title]"
	// If our player is a member of Command or a Silicon, we want to sort them to the top of the list. Otherwise, just add them to the end of the list.
	// Assistants show up after everyone else.
	if(player_job.departments_bitflags & (DEPARTMENT_BITFLAG_COMMAND | DEPARTMENT_BITFLAG_SILICON))
		command_player_ready_data[player_ref] = list(job_estimation_text, player.ckey)
	else if(player_job.departments_bitflags & DEPARTMENT_BITFLAG_ASSISTANT)
		assistant_player_ready_data[player_ref] = list(job_estimation_text, player.ckey)
	else
		player_ready_data[player_ref] = list(job_estimation_text, player.ckey)

/// Removes a player from the job estimation.
/datum/controller/subsystem/statpanels/proc/remove_job_estimation(mob/dead/new_player/player)
	if(isnull(player))
		return

	var/player_ref = REF(player)
	player_ready_data -= player_ref

	if(length(command_player_ready_data))
		command_player_ready_data -= player_ref

	if(length(assistant_player_ready_data))
		assistant_player_ready_data -= player_ref

/// Refreshes a player's job estimation by mob or ckey - taken off, then put back while they're readied before the round starts. 'player' and 'ckey' are optional args.
/datum/controller/subsystem/statpanels/proc/update_job_estimation(mob/dead/new_player/player, ckey)
	player ||= get_mob_by_ckey(ckey)
	if(!istype(player))
		return
	remove_job_estimation(player)
	if(player.ready == PLAYER_READY_TO_PLAY && !SSticker.HasRoundStarted())
		add_job_estimation(player)

/// Keeps the job estimation in step with tg's ready report, which runs on every ready toggle, job pref change, character load and logout
/mob/dead/new_player/update_ready_report()
	. = ..()
	SSstatpanels.update_job_estimation(src)
