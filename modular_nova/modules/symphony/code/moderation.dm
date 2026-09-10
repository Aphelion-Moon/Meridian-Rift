/// The game's own ban notice, for a ban SSymphony wrote to the table.
/// The panel supplies the notice for an existing row; this legacy topic targets only its ckey.
/datum/world_topic/symphony/ban_notify
	keyword = "symphony_ban_notify"

/datum/world_topic/symphony/ban_notify/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	var/client/found = GLOB.directory[target_ckey]
	if(!found)
		// The ban row already exists; only the connected-client notice is skipped.
		.["success"] = TRUE
		.["message"] = "not connected"
		return

	var/admin_name = input["admin_name"] || "Discord Admin"
	var/reason = input["reason"] || "no reason given"
	var/role = input["role"] || "Server"
	var/minutes = text2num(input["duration_mins"]) || 0
	var/is_server_ban = (role == "Server")
	var/how_long = minutes ? "temporary, it will be removed in [DisplayTimeText(minutes MINUTES)]." : "permanent."
	var/where = is_server_ban ? "the server" : " Roles: [html_encode(role)]"
	var/appeal = CONFIG_GET(string/banappeals) || "No ban appeal url set!"

	// Refresh cached role bans so the existing session enforces this ban immediately.
	build_ban_cache(found)
	to_chat(found, span_boldannounce("You have been banned by [html_encode(admin_name)] from [where].\nReason: [html_encode(reason)]</span><br>[span_danger("This ban is [how_long] The round ID is [GLOB.round_id].")]<br>[span_danger("To appeal this ban go to [appeal]")]"), confidential = TRUE)
	log_admin("[admin_name] (via Symphony) banned [key_name(found)] from [role]. Reason: [reason]")
	message_admins("[html_encode(admin_name)] (via Symphony) banned [key_name_admin(found)] from [html_encode(role)].")
	if(is_server_ban)
		qdel(found)
	.["success"] = TRUE

/// Kicks a player by ckey for a Discord admin.
/datum/world_topic/symphony/kick
	keyword = "symphony_kick"

/datum/world_topic/symphony/kick/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	var/admin_name = input["admin_name"] || "Discord Admin"
	if(!target_ckey)
		.["success"] = FALSE
		.["message"] = "missing target_ckey"
		return
	var/client/found = GLOB.directory[target_ckey]
	if(!found)
		.["success"] = FALSE
		.["message"] = "not connected"
		return
	// Same shape as the admin panel's kick in topic.dm, plus the reason.
	var/reason = input["reason"]
	var/why = reason ? ": [html_encode(reason)]" : "."
	to_chat(found, span_userdanger("You have been kicked from the server by [html_encode(admin_name)][why]"), confidential = TRUE)
	log_admin("[admin_name] (via Symphony) kicked [key_name(found)].[reason ? " Reason: [reason]" : ""]")
	message_admins("[html_encode(admin_name)] (via Symphony) kicked [key_name(found)].[reason ? " Reason: [html_encode(reason)]" : ""]")
	qdel(found)
	.["success"] = TRUE

/datum/world_topic/symphony/bannable_roles
	keyword = "symphony_bannable_roles"
	log = FALSE

/// Shared by the panel's role list and ban validation.
/proc/symphony_bannable_roles()
	var/list/roles = list("Server", "OOC", "Deadchat", "Emote", "Appearance", "Urgent Adminhelp")
	for(var/datum/job/job_datum as anything in SSjob?.all_occupations)
		if(job_datum.title)
			roles += job_datum.title
	return roles

/// The ban cache is case sensitive, so match the caller's text to the stored title.
/proc/symphony_resolve_role(supplied)
	supplied = trim(supplied)
	if(!supplied)
		return "Server"
	supplied = LOWER_TEXT(supplied)
	for(var/role in symphony_bannable_roles())
		if(LOWER_TEXT(role) == supplied)
			return role
	return null

/datum/world_topic/symphony/bannable_roles/Run(list/input)
	return list("roles" = symphony_bannable_roles())

/// World topics have no usr, which create_ban() requires, so insert the ban directly.
/datum/world_topic/symphony/ban
	keyword = "symphony_ban"

/datum/world_topic/symphony/ban/Run(list/input)
	. = list()
	var/target_ckey = ckey(input["target_ckey"])
	var/reason = input["reason"]
	var/admin_name = input["admin_name"] || "Discord Admin"
	var/role = symphony_resolve_role(input["role"])
	var/duration = text2num(input["duration_mins"]) // null/0 = permanent
	if(!duration || duration <= 0)
		duration = null
	if(!target_ckey || !reason)
		.["success"] = FALSE
		.["message"] = "missing target_ckey or reason"
		return
	if(!role)
		.["success"] = FALSE
		.["message"] = "unknown role - use one of the roles from symphony_bannable_roles"
		return
	// These bans exclude admins, so reject staff targets instead of reporting success.
	if(GLOB.admin_datums[target_ckey] || GLOB.deadmins[target_ckey])
		.["success"] = FALSE
		.["message"] = "target is staff - use the in-game ban panel"
		return
	if(!SSdbcore.Connect())
		.["success"] = FALSE
		.["message"] = "no database"
		return

	// Widening to the last known IP/CID catches shared connections too, so the caller decides. Omitted means widen.
	var/widen = TRUE
	if("match_ip_cid" in input)
		widen = text2num(input["match_ip_cid"]) ? TRUE : FALSE
	var/player_ip = null
	var/player_cid = null
	if(widen)
		var/datum/db_query/lookup = SSdbcore.NewQuery({"
			SELECT INET_NTOA(ip), computerid
			FROM [format_table_name("player")]
			WHERE ckey = :ckey
		"}, list("ckey" = target_ckey))
		if(lookup.warn_execute() && lookup.NextRow())
			player_ip = lookup.item[1]
			player_cid = lookup.item[2]
		qdel(lookup)

	var/list/special_columns = list(
		"bantime" = "NOW()",
		"ip" = "INET_ATON(?)",
		"expiration_time" = "IF(? IS NULL, NULL, NOW() + INTERVAL ? MINUTE)", // one row value fills both '?'
	)
	var/safe_reason = html_encode(reason)
	var/list/row = list(
		"server_ip" = 0,
		"server_port" = world.port,
		"round_id" = GLOB.round_id,
		"role" = role, // 'Server' is a full login ban, anything else is in-round only
		"expiration_time" = duration,
		"applies_to_admins" = 0,
		// Existing ban browsers render this field as HTML; panel input is plain text.
		"reason" = safe_reason,
		"ckey" = target_ckey,
		"ip" = player_ip,
		"computerid" = player_cid,
		// Use a fixed audit identity; the panel supplies a display name, not a staff ckey.
		"a_ckey" = "symphony",
		"a_ip" = 0,
		"a_computerid" = "symphony",
		"who" = "",
		"adminwho" = "",
	)
	if(!SSdbcore.MassInsert(format_table_name("ban"), list(row), warn = TRUE, special_columns = special_columns))
		.["success"] = FALSE
		.["message"] = "insert failed"
		return

	symphony_write_ban_note(target_ckey, admin_name, role, reason)

	var/dur_txt = duration ? "for [duration] minutes" : "permanently"
	var/what = (role == "Server") ? "server-banned" : "role-banned ([role])"
	log_admin("[admin_name] (via Symphony) [what] [target_ckey] [dur_txt]. Reason: [reason]")
	// message_admins renders as HTML, and this is free text from the panel.
	var/safe_admin = html_encode(admin_name)
	var/safe_what = html_encode(what)
	message_admins("[safe_admin] (via Symphony) [safe_what] [target_ckey] [dur_txt]. Reason: [safe_reason]")

	var/player_notice
	if(role == "Server")
		player_notice = span_userdanger("You have been [duration ? "" : "permanently "]banned by [safe_admin].\nReason: [safe_reason]")
	else
		player_notice = span_userdanger("You have been [safe_what] by [safe_admin]. Reason: [safe_reason]")
	var/shared_notice = "[player_notice]<br>This ban matches your IP or CID."
	notify_all_banned_players(target_ckey, player_ip, player_cid, player_notice, shared_notice, role == "Server", applies_to_admins = FALSE)
	.["success"] = TRUE
	.["role"] = role
	.["permanent"] = isnull(duration)

/// World topics have no usr, which create_message() requires, so insert the note directly.
/proc/symphony_write_ban_note(target_ckey, admin_name, role, reason)
	if(!SSdbcore.Connect())
		return FALSE
	var/datum/db_query/query = SSdbcore.NewQuery({"
		INSERT INTO [format_table_name("messages")]
			(type, targetckey, adminckey, text, timestamp, server_ip, server_port, round_id, secret, deleted)
		VALUES
			('note', :target_ckey, :admin_ckey, :text, Now(), 0, 0, :round_id, 0, 0)
	"}, list(
		"target_ckey" = target_ckey,
		"admin_ckey" = "symphony",
		"text" = html_encode("Banned via Symphony by [admin_name] ([role]): [reason]"),
		"round_id" = GLOB.round_id,
	))
	. = query.warn_execute()
	qdel(query)
