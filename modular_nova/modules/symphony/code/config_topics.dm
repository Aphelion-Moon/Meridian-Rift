/// Lets the panel flip the whitelist gate for the running server.
/datum/world_topic/symphony/set_enforcement
	keyword = "symphony_set_enforcement"

/datum/world_topic/symphony/set_enforcement/Run(list/input)
	. = list()
	// This topic must remain reachable while enforcement is disabled so the panel can turn it on.
	var/admin_name = input["admin_name"] || "Discord Admin"
	var/raw = input["enabled"]
	if(isnull(raw))
		.["success"] = FALSE
		.["message"] = "missing enabled"
		return
	var/enabled = (raw == "1" || raw == "true" || raw == 1)

	// Hardcoded on purpose, nobody gets to ask us to set some other entry.
	var/datum/config_entry/entry = global.config.entries["symphony_enabled"]
	if(!entry)
		.["success"] = FALSE
		.["message"] = "symphony_enabled is not a known config entry on this server"
		return

	var/old_value = entry.config_entry_value
	if(!entry.ValidateAndSet(enabled ? "1" : "0"))
		.["success"] = FALSE
		.["message"] = "the game refused the value"
		return
	if(old_value != enabled)
		// Entries and sleeping queries from the previous enforcement state must be checked again.
		SSsymphony.whitelist_cache.Cut()
		SSsymphony.whitelist_cache_expiry.Cut()
		SSsymphony.whitelist_epoch++
		if(enabled)
			INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(symphony_validate_ready_players))

	.["success"] = TRUE
	.["enabled"] = enabled
	log_admin("[admin_name] (via Symphony) set whitelist enforcement to [enabled ? "on" : "off"] (was [old_value]).")
	message_admins("[html_encode(admin_name)] (via Symphony) turned whitelist enforcement [enabled ? "ON" : "OFF"].")
