/// Ban length in minutes, 0 being permanent.
/proc/symphony_ban_minutes(duration, interval)
	// Minutes per interval; MONTH/YEAR use 30/365 days.
	var/static/list/interval_minutes = list(
		"SECOND" = 1/60,
		"MINUTE" = 1,
		"HOUR" = 60,
		"DAY" = 1440,
		"WEEK" = 10080,
		"MONTH" = 43200,
		"YEAR" = 525600,
	)
	if(isnull(duration) || duration == "")
		return 0
	var/amount = isnum(duration) ? duration : text2num(duration)
	// Only an omitted duration is permanent; invalid or nonpositive input gets one minute.
	if(isnull(amount) || amount <= 0)
		return 1
	var/per = interval_minutes[interval] || 1
	return max(1, round(amount * per))

/// Queue propagation of an existing local ban to the other servers.
/proc/symphony_request_community_ban(target_ckey, list/roles, reason, duration, interval, admin_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return FALSE
	if(!target_ckey || !length(roles) || !SSdbcore.Connect())
		return FALSE
	var/minutes = symphony_ban_minutes(duration, interval)
	var/list/rows = list()
	for(var/role in roles)
		rows += list(list(
			"ckey" = target_ckey,
			"role" = role,
			"reason" = reason,
			"duration_mins" = minutes,
			"admin_ckey" = admin_ckey,
		))
	// Include the earlier local ban in the bridge's time window to avoid a duplicate ban row.
	var/list/special_columns = list("created_at" = "NOW() - INTERVAL 60 SECOND")
	if(!SSdbcore.MassInsert(format_table_name("symphony_ban_intents"), rows, warn = TRUE, special_columns = special_columns))
		return FALSE
	log_admin_private("[admin_ckey] requested a community-wide ban for [target_ckey].")
	message_admins("[admin_ckey] requested a COMMUNITY-WIDE ban for [target_ckey] - SSymphony will apply it to the other servers.")
	return TRUE
