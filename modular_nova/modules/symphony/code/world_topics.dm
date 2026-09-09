/// Default address policy; Symphony topics override this with their configured allowlist.
/datum/world_topic/proc/AddressAllowed(addr)
	return TRUE

/// Redact the decoded credential, covering every parameter encoding accepted by authentication.
/proc/world_topic_log_parameters(list/input)
	var/list/log_input = input.Copy()
	if("key" in log_input)
		log_input["key"] = "***"
	return list2params(log_input)

/// TRUE if a topic from this sender is allowed to run.
/proc/symphony_address_allowed(addr)
	var/static/list/local_addresses = list("127.0.0.1", "::1", "localhost")
	if(!CONFIG_GET(flag/symphony_topics_local_only))
		return TRUE
	// Null addr means the sender is on this machine.
	if(!addr)
		return TRUE
	var/sender = LOWER_TEXT(trim(addr))
	if(sender in local_addresses)
		return TRUE
	for(var/allowed in CONFIG_GET(str_list/symphony_topics_allowed_addresses))
		if(LOWER_TEXT(trim(allowed)) == sender)
			return TRUE
	return FALSE

/// All Symphony topics require the comms key and configured address checks.
/datum/world_topic/symphony
	abstract_type = /datum/world_topic/symphony
	require_comms_key = TRUE

/datum/world_topic/symphony/AddressAllowed(addr)
	if(symphony_address_allowed(addr))
		return TRUE
	log_admin("Symphony: refused topic \"[keyword]\" from [addr] - not an allowed address.")
	return FALSE

/datum/world_topic/symphony/TryRun(list/input, addr)
	. = ..()
	// Record panel metadata only after successful comms-key authentication.
	if(key_valid)
		symphony_note_panel(input, addr)

/// Remember who called, so the status verb can compare the two halves.
/proc/symphony_note_panel(list/input, addr)
	// No version means a panel too old to introduce itself, which is still worth knowing about.
	var/list/said = list(
		"version" = input["symphony_version"],
		"needs" = text2num(input["symphony_needs"]),
		"wants" = text2num(input["symphony_wants"]),
		"addr" = addr,
		"at" = REALTIMEOFDAY,
	)
	// Refused callers must not overwrite the accepted panel's diagnostic state.
	if(!symphony_address_allowed(addr))
		SSsymphony.panel_refused = said
		return
	SSsymphony.panel = said

/// How long ago a stamp was. DisplayTimeText already says "right now", and "right now ago" reads wrong.
/proc/symphony_ago(stamp)
	var/text = DisplayTimeText(REALTIMEOFDAY - stamp)
	return text == "right now" ? text : "[text] ago"

/datum/world_topic/symphony/whitelist_revoke
	keyword = "whitelist_revoke"

/datum/world_topic/symphony/whitelist_revoke/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	// Don't claim we did something the master switch stopped.
	if(!CONFIG_GET(flag/symphony_enabled))
		.["success"] = FALSE
		.["message"] = "enforcement is off"
		return
	symphony_revoke(target_ckey)
	.["success"] = TRUE

/datum/world_topic/symphony/whitelist_grant
	keyword = "whitelist_grant"

/datum/world_topic/symphony/whitelist_grant/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	if(!CONFIG_GET(flag/symphony_enabled))
		.["success"] = FALSE
		.["message"] = "enforcement is off"
		return
	symphony_notify_grant(target_ckey)
	.["success"] = TRUE
