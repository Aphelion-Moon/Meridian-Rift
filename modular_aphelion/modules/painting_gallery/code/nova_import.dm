/datum/config_entry/flag/enable_nova_painting_import
	default = FALSE

/datum/persistent_client
	/// Earliest world.time this administrator may issue another prompt; survives reconnects.
	var/next_nova_painting_admin_prompt = 0
	/// Earliest world.time any administrator may prompt this account again.
	var/next_nova_painting_target_prompt = 0
	/// Last visibility-save error, shared across this account's open galleries.
	var/painting_gallery_error

/// One non-yielding claim enforces both cooldowns; persistent clients survive reconnects.
/proc/claim_nova_import_prompt(datum/persistent_client/administrator, datum/persistent_client/target, now = world.time)
	if(!administrator || !target || now < administrator.next_nova_painting_admin_prompt || now < target.next_nova_painting_target_prompt)
		return FALSE
	administrator.next_nova_painting_admin_prompt = now + 1 MINUTES
	target.next_nova_painting_target_prompt = now + 1 MINUTES
	return TRUE

/// Return the account's explicit yes/no answer; a missing or invalid value remains unset.
/datum/preferences/proc/nova_painting_import_answer()
	var/answer = savefile?.get_entry(NOVA_PAINTING_IMPORT_ANSWER)
	return (answer == "yes" || answer == "no") ? answer : null

/// Persist an explicit answer, restoring the in-memory value if the preferences write fails.
/datum/preferences/proc/save_nova_painting_import_answer(answer)
	if(!load_and_save || !savefile || (answer != "yes" && answer != "no"))
		return FALSE
	var/previous_answer = savefile.get_entry(NOVA_PAINTING_IMPORT_ANSWER)
	savefile.set_entry(NOVA_PAINTING_IMPORT_ANSWER, answer)
	if(!flush_nova_import_preferences())
		savefile.set_entry(NOVA_PAINTING_IMPORT_ANSWER, previous_answer)
		return FALSE
	return TRUE

/// Existing preference serialization, with its write result checked before claiming consent was saved.
/datum/preferences/proc/flush_nova_import_preferences()
	if(!savefile?.path || savefile.path == DEV_PREFS_PATH)
		return FALSE
	var/error = rustg_file_write(json_encode(savefile.get_entry(), JSON_PRETTY_PRINT), savefile.path)
	if(error)
		log_game("Unable to save Nova painting import answer: [error]")
		return FALSE
	return TRUE

/// UI entry points share this gate. No UI update tick can spawn another dialog.
/datum/controller/subsystem/persistent_paintings/proc/offer_nova_import(client/player, manual = FALSE, client/admin)
	if(!CONFIG_GET(flag/enable_nova_painting_import) || !player?.prefs?.load_and_save || is_guest_key(player.key))
		return
	var/owner = player.ckey
	var/datum/preferences/preferences = player.prefs
	var/previous_answer = preferences.nova_painting_import_answer()
	if(nova_import_busy?[owner] || (!manual && !isnull(previous_answer)))
		return
	if(manual && !admin && previous_answer != "yes")
		return
	if(admin && (!admin.holder || !check_rights_for(admin, R_ADMIN)))
		return
	LAZYSET(nova_import_busy, owner, TRUE)
	LAZYREMOVE(nova_import_status, owner)
	LAZYREMOVE(nova_painting_ids_by_owner, owner)
	var/admin_name = admin ? key_name(admin) : null
	refresh_gallery_uis()
	try
		perform_nova_import_offer(player, preferences, owner, admin)
	catch(var/exception/error)
		log_game("Nova painting import failed for [owner]: [error]")
		LAZYSET(nova_import_status, owner, "The import could not be completed. Please contact an administrator or retry.")
	if(admin_name)
		log_admin("Nova painting import request by [admin_name] for [owner]: [nova_import_status?[owner] || "closed or disconnected without importing"].")
	LAZYREMOVE(nova_import_busy, owner)
	refresh_gallery_uis()

/// Validate owned source records and obtain import consent; closing the second prompt keeps imported art private.
/datum/controller/subsystem/persistent_paintings/proc/perform_nova_import_offer(client/player, datum/preferences/preferences, owner, client/admin)
	if(!store_writable)
		LAZYSET(nova_import_status, owner, "Painting storage is unavailable. Please contact an administrator.")
		return
	var/list/source = store_request(list("op" = "snapshot", "source" = "nova"))
	if(!source["ok"])
		log_game("Nova painting catalog could not be loaded: [store_result_message(source)]")
		LAZYSET(nova_import_status, owner, "The Nova artwork backup is unavailable. Your answer has not changed.")
		return
	if(!player || player.prefs != preferences || player.ckey != owner || GLOB.directory[owner] != player || !CONFIG_GET(flag/enable_nova_painting_import))
		return
	source["snapshot"] = prepare_nova_import(source["snapshot"], owner)
	var/matching = length(source["snapshot"]["paintings"])
	if(!matching)
		if(isnull(preferences.nova_painting_import_answer()))
			if(!preferences.save_nova_painting_import_answer("no"))
				LAZYSET(nova_import_status, owner, "No Nova paintings were found, but the answer could not be saved. Please contact an administrator.")
				return
		LAZYSET(nova_import_status, owner, "No Nova paintings were found for your account.")
		if(admin)
			to_chat(admin, span_notice("No Nova paintings were found for [owner]."))
		return
	if(admin)
		if(!admin.holder || !check_rights_for(admin, R_ADMIN))
			return
		if(!claim_nova_import_prompt(admin.persistent_client, player.persistent_client))
			to_chat(admin, span_warning("Please wait one minute between Nova import prompts, both per administrator and per player."))
			return
		log_admin("[key_name(admin)] prompted [owner] to import their Nova paintings.")
	var/answer = tgui_alert(player.mob, "Would you like to import your paintings from Nova Sector? [matching] painting(s) were found for your account. Existing Meridian paintings will be kept.", "Import Nova paintings", list("Yes", "No"))
	if(!player || player.prefs != preferences || player.ckey != owner || GLOB.directory[owner] != player)
		return
	if(answer != "Yes" && answer != "No")
		return
	if(!preferences.save_nova_painting_import_answer(answer == "Yes" ? "yes" : "no"))
		LAZYSET(nova_import_status, owner, "Your answer could not be saved. Please contact an administrator.")
		return
	if(answer == "No")
		LAZYSET(nova_import_status, owner, "Import declined. You can ask an administrator if you change your mind.")
		log_game("Nova painting import declined by [owner].")
		return
	// Capture authorization now. Closing the next dialog (including disconnecting)
	// must not cancel this already-authorized import.
	var/public_answer = tgui_alert(player.mob, "Make these imported paintings public on the web gallery? They will be visible on the website under your BYOND account. This only affects newly imported paintings; you can change each painting later in My Artwork.", "Public web gallery", list("Yes", "Let me choose individually"))
	var/make_public = public_answer == "Yes" && player && player.ckey == owner && player.prefs == preferences && GLOB.directory[owner] == player
	if(!CONFIG_GET(flag/enable_nova_painting_import))
		LAZYSET(nova_import_status, owner, "Nova importing was disabled before this import could start.")
		return
	LAZYSET(nova_import_status, owner, "Importing your paintings...")
	refresh_gallery_uis()
	var/list/result = run_store_operation("import", list("owner" = owner, "snapshot" = source["snapshot"], "sha256" = source["sha256"], "public" = make_public))
	if(!result["ok"])
		var/list/error = result["error"]
		var/message = error?["code"] == "owner_limit" ? error["message"] : "The import failed."
		LAZYSET(nova_import_status, owner, "[message] Your answer was saved; use Retry to try again.")
		log_game("Nova painting import failed for [owner]: [store_result_message(result)]")
	else
		var/imported = result["imported"] || 0
		LAZYSET(nova_import_status, owner, imported ? "Imported [imported] painting(s). Existing paintings were kept." : "All available paintings already exist or conflict with existing artwork. Nothing was changed.")
		log_game("Nova painting import for [owner]: [imported] added; web gallery opt-in [make_public ? "yes" : "no"].")
	if(player)
		to_chat(player, span_notice(nova_import_status?[owner]))

/// Release other owners' records before waiting for input; keep the full-source SHA for native verification.
/datum/controller/subsystem/persistent_paintings/proc/prepare_nova_import(list/snapshot, owner)
	var/list/owned_ids = list()
	var/list/owned_rows = list()
	for(var/list/row as anything in snapshot["paintings"])
		if(row["creator_ckey"] == owner)
			owned_ids += row["md5"]
			owned_rows += list(row)
	LAZYSET(nova_painting_ids_by_owner, owner, owned_ids)
	return list("version" = snapshot["version"], "paintings" = owned_rows)

/// Allow confirmed importers to retry when source availability is unknown or owned records remain absent.
/datum/controller/subsystem/persistent_paintings/proc/can_retry_nova_import(client/player)
	if(!CONFIG_GET(flag/enable_nova_painting_import) || player?.prefs?.nova_painting_import_answer() != "yes")
		return FALSE
	// An account not checked successfully must still be able to retry.
	var/list/owned_ids = nova_painting_ids_by_owner?[player.ckey]
	if(isnull(owned_ids))
		return TRUE
	for(var/id in owned_ids)
		if(!paintings_by_id?[id])
			return TRUE
	return FALSE

/// Let an authorized administrator request fresh player consent through the shared cooldown and import gate.
ADMIN_VERB(prompt_nova_painting_import, R_ADMIN, "Prompt Nova Painting Import", "Ask a player to import their Nova paintings, with their confirmation.", ADMIN_CATEGORY_MAIN)
	if(!CONFIG_GET(flag/enable_nova_painting_import))
		to_chat(user, span_warning("Nova painting importing is disabled in the server configuration."))
		return
	if(world.time < user.persistent_client.next_nova_painting_admin_prompt)
		to_chat(user, span_warning("You can send one Nova import prompt per minute."))
		return
	var/client/target = tgui_input_list(user.mob, "Which player would you like to prompt?", "Nova painting import", GLOB.clients)
	if(!target || !user.holder || !check_rights_for(user, R_ADMIN))
		return
	SSpersistent_paintings.offer_nova_import(target, TRUE, user)
