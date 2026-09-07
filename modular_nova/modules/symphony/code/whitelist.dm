/// Query a linked account for an in-game role grant.
/// Returns TRUE/FALSE, or null when the database cannot answer. Unlinked accounts return FALSE.
/proc/symphony_has_ingame_role(target_ckey, role_key)
	target_ckey = ckey(target_ckey)
	if(!target_ckey || !role_key)
		return FALSE
	if(!SSdbcore.Connect())
		return null

	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT 1
		FROM [format_table_name("discord_links")] AS dl
		JOIN [format_table_name("discord_member_roles")] AS mr ON mr.discord_id = dl.discord_id
		JOIN [format_table_name("symphony_role_grants")] AS g ON g.discord_role_id = mr.role_id
		WHERE dl.ckey = :ckey
			AND dl.valid = 1
			AND g.grant_type = 'ingame'
			AND g.grant_key = :role_key
		LIMIT 1
	"}, list("ckey" = target_ckey, "role_key" = role_key))
	if(!query.warn_execute())
		qdel(query)
		return null
	. = query.NextRow()
	qdel(query)

/// Return role holders as ckey -> TRUE, an empty list for no holders, or null on query failure.
/proc/symphony_ingame_role_ckeys(role_key)
	if(!role_key || !SSdbcore.Connect())
		return null

	var/datum/db_query/query = SSdbcore.NewQuery({"
		SELECT DISTINCT dl.ckey
		FROM [format_table_name("discord_links")] AS dl
		JOIN [format_table_name("discord_member_roles")] AS mr ON mr.discord_id = dl.discord_id
		JOIN [format_table_name("symphony_role_grants")] AS g ON g.discord_role_id = mr.role_id
		WHERE dl.valid = 1
			AND g.grant_type = 'ingame'
			AND g.grant_key = :role_key
	"}, list("role_key" = role_key))
	if(!query.warn_execute())
		qdel(query)
		return null
	var/list/holders = list()
	while(query.NextRow())
		holders[ckey(query.item[1])] = TRUE
	qdel(query)
	return holders

#define SYMPHONY_WHITELIST_CACHE_TIME (10 SECONDS)

/// Invalidate one account immediately after a role change.
/proc/symphony_invalidate_whitelist_cache(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	SSsymphony.whitelist_cache -= target_ckey
	SSsymphony.whitelist_cache_expiry -= target_ckey
	SSsymphony.whitelist_epoch++

/// Cache a confirmed TRUE/FALSE result from a notification or bulk query.
/// Advancing the epoch prevents an older in-flight query from overwriting this answer.
/proc/symphony_seed_whitelist_cache(target_ckey, whitelisted)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return
	SSsymphony.whitelist_cache[target_ckey] = whitelisted
	SSsymphony.whitelist_cache_expiry[target_ckey] = world.time + SYMPHONY_WHITELIST_CACHE_TIME
	SSsymphony.whitelist_epoch++

/// Return cached TRUE/FALSE, or null for a miss. Never queries or sleeps.
/proc/symphony_whitelist_cache_peek(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return null
	var/expiry = SSsymphony.whitelist_cache_expiry[target_ckey]
	if(!expiry || world.time >= expiry)
		return null
	return SSsymphony.whitelist_cache[target_ckey]

/// Return a cached whitelist answer, querying on a miss. May sleep.
/// Database failures return null and are never cached; FALSE is a confirmed denial.
/// Use symphony_whitelist_cache_peek() in display and signal handlers that cannot sleep.
/proc/symphony_whitelist_lookup(target_ckey)
	target_ckey = ckey(target_ckey)
	if(!target_ckey)
		return FALSE
	while(TRUE)
		var/cached = symphony_whitelist_cache_peek(target_ckey)
		if(!isnull(cached))
			return cached
		var/epoch = SSsymphony.whitelist_epoch
		var/answer = symphony_has_ingame_role(target_ckey, "whitelist")
		// A notification can overtake even a failed query. Use its answer, or retry if it only invalidated the cache.
		if(epoch != SSsymphony.whitelist_epoch)
			continue
		if(isnull(answer))
			return null
		SSsymphony.whitelist_cache[target_ckey] = answer
		SSsymphony.whitelist_cache_expiry[target_ckey] = world.time + SYMPHONY_WHITELIST_CACHE_TIME
		return answer

/// Admission check: allow access when enforcement is disabled; deny on a database failure.
/// Use symphony_whitelist_lookup() when the caller must distinguish a denial from an outage.
/proc/is_symphony_whitelisted(target_ckey)
	if(!CONFIG_GET(flag/symphony_enabled))
		return TRUE
	return symphony_whitelist_lookup(target_ckey) ? TRUE : FALSE

/// Check a current role entitlement, bypassing the admission cache.
/// Unlike admission, perks and imports require an enabled module and a confirmed grant.
/proc/symphony_holds_whitelist_role(target_ckey)
	while(CONFIG_GET(flag/symphony_enabled))
		var/epoch = SSsymphony.whitelist_epoch
		var/answer = symphony_has_ingame_role(target_ckey, "whitelist")
		if(!CONFIG_GET(flag/symphony_enabled))
			return FALSE
		// Imports and perks need a current entitlement too, while retaining their uncached lookup.
		if(epoch != SSsymphony.whitelist_epoch)
			continue
		return answer ? TRUE : FALSE
	return FALSE

#undef SYMPHONY_WHITELIST_CACHE_TIME
