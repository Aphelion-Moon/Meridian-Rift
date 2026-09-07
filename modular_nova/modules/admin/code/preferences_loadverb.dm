ADMIN_VERB(import_preferences, R_ADMIN, "Import Preferences", "Upload a character preferences JSON file to the server.", ADMIN_CATEGORY_MAIN)
	var/player_key = tgui_input_text(user, "Enter player CKey to replace their save file", "Import Preferences")
	if(!length(player_key))
		return

	player_key = ckey(player_key)

	// Prevent empty ckey after whitespace was stripped
	if(!length(player_key))
		return

	// Prevent spelling mistakes
	var/confirmation = tgui_alert(user, "Import preferences for \"[player_key]\"?", "Import Preferences", list("Confirm", "Cancel"))
	if(confirmation != "Confirm")
		return

	var/folder_path = "data/player_saves/[player_key[1]]/[player_key]"
	var/savefile_path = "[folder_path]/preferences.json"
	var/save_exists = fexists(savefile_path)

	// Prevent accidental overwriting
	if(save_exists)
		var/overwrite_confirmation = tgui_alert(user, "File already exists for \"[player_key]\". Overwrite existing file?", "Import Preferences", list("Overwrite", "Cancel"))
		if(overwrite_confirmation != "Overwrite")
			return
	// Prevent accidental typos
	else
		var/creation_confirmation = tgui_alert(user, "File not found for \"[player_key]\". Create new file?", "Import Preferences", list("Create", "Cancel"))
		if(creation_confirmation != "Create")
			return

	// Upload the new JSON file
	var/uploaded_file = input(user, "Choose a JSON file to upload", "Import Preferences") as null|file
	// Reject non-files, nulls, or blank files
	if(!isfile(uploaded_file) || !length(uploaded_file))
		return
	if(!user || !check_rights_for(user, R_ADMIN))
		return

	var/list/upload = prefs_import_read_upload(uploaded_file, user.prefs)
	var/problem = upload["error"]
	if(problem)
		to_chat(user, span_warning("Failed to import: [problem]."), confidential = TRUE)
		log_admin("Preferences import by [key_name_admin(user)] rejected: [problem]")
		return
	var/list/json_tree = prefs_import_pass1(upload["tree"])

	if(!user || !check_rights_for(user, R_ADMIN))
		return
	var/backup_error = prefs_import_admin_backup(savefile_path)
	if(backup_error)
		to_chat(user, span_warning("Could not import preferences: [backup_error]. Nothing was changed."), confidential = TRUE)
		return

	var/install_error = prefs_import_replace(savefile_path, json_encode(json_tree))
	if(install_error)
		to_chat(user, span_warning("Could not install the imported preferences: [install_error]."), confidential = TRUE)
		log_admin("Preferences import for [player_key] was not installed: [install_error]")
		return

	prefs_import_invalidate_cache(player_key)

	to_chat(user, span_danger("Successfully imported new preferences for player [player_key]"), confidential = TRUE)
	log_admin("[key_name_admin(user)] has successfully imported new preferences for player [player_key].")
	message_admins("[key_name_admin(user)] has successfully imported new preferences for player [player_key].")

	// Find client of the target ckey so we can disconnect them
	var/client/target_client = GLOB.directory[player_key]
	if(!target_client)
		return

	// Disconnect the affected client to reset any prefs data cached in TGUI
	to_chat(target_client, span_danger("Kicked to finish preference file importing. Please re-connect to the server."), confidential = TRUE)
	log_admin("Kicked [player_key] to complete preference file importing.")
	message_admins("Kicked [player_key] to complete preference file importing.")
	// Delayed kick to give chat messages time to be delivered
	QDEL_IN(target_client, 2)
