/proc/bug_report_context_snapshot(mob/incident_mob, incident_ckey, session_id, client_version, client_build)
	var/turf/incident_turf = get_turf(incident_mob)
	var/area/incident_area = get_area(incident_mob)
	var/list/merges = list()
	for(var/datum/tgs_revision_information/test_merge/merge as anything in GLOB.revdata.testmerge)
		merges += list(list("number" = merge.number, "commit" = merge.head_commit))
	// The authenticated host converts this exact wire text to integer milliseconds.
	var/captured_at = "unix-seconds:[rustg_unix_timestamp()]"
	return list(
		"schemaVersion" = 1,
		"source" = "game",
		"serverId" = CONFIG_GET(string/bug_report_server_id),
		"bootId" = GLOB.bug_report_boot_id,
		"sessionId" = session_id,
		"ckey" = incident_ckey,
		"capturedAt" = captured_at,
		"incidentAt" = captured_at,
		"roundId" = GLOB.round_id ? "[GLOB.round_id]" : null,
		"roundUnavailableReason" = GLOB.round_id ? null : "Round database identifier unavailable",
		"worldTimeDs" = world.time,
		"map" = SSmapping.current_map?.map_name,
		"area" = incident_area?.name,
		"coordinates" = incident_turf ? list("x" = incident_turf.x, "y" = incident_turf.y, "z" = incident_turf.z) : null,
		"mob" = incident_mob ? list("name" = incident_mob.name, "realName" = incident_mob.real_name, "type" = "[incident_mob.type]", "ref" = REF(incident_mob), "state" = incident_mob.stat) : null,
		"versions" = list(
			"client" = list("version" = client_version, "build" = client_build),
			"server" = list("version" = world.byond_version, "build" = world.byond_build),
			"compiler" = list("version" = DM_VERSION, "build" = DM_BUILD),
		),
		"build" = list("commit" = GLOB.revdata.commit, "base" = GLOB.revdata.originmastercommit, "testMerges" = merges),
		"performance" = list("tickLag" = world.tick_lag, "tickUsage" = world.tick_usage, "playerCount" = length(GLOB.clients)),
	)
