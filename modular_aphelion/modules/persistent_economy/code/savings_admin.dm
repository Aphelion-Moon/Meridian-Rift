/** Apply an audited administrator change, with permissions enforced even when called outside TGUI. */
/datum/savings_ledger/proc/admin_change(client/administrator, action, owner_key, character_id, currency, amount, reason, list/new_settings, confirmation)
	if(!check_rights_for(administrator, R_ADMIN) || !istext(reason) || !length(trim(reason)) || storage_error)
		return reject("Administrator rights and a reason are required; storage must be healthy.")
	reason = copytext(trim(reason), 1, MAX_MESSAGE_LEN)
	var/list/snapshot = copy_snapshot()
	var/list/account = find_account(owner_key, character_id, snapshot)
	var/description
	switch(action)
		if("reset")
			if(confirmation != "RESET ECONOMY")
				return reject("Type RESET ECONOMY to confirm clearing everyone's persistent savings.")
			description = "Reset persistent economy for [reset_accounts(snapshot)] character accounts; policy and administrative audit retained"
		if("settings")
			if(!valid_settings(new_settings))
				return reject("Invalid economy settings.")
			description = "Policy changed from [json_encode(snapshot["settings"])] to [json_encode(new_settings)]"
			snapshot["settings"] = new_settings.Copy()
		if("adjust")
			if(!account || !(currency in list(SAVINGS_REGULAR, SAVINGS_OFFSHORE)) || !isnum(amount) || !valid_amount(abs(amount)))
				return reject("Select an account, currency, and nonzero whole-credit adjustment.")
			if(!valid_amount(account[currency] + amount, allow_zero = TRUE))
				return reject("The adjustment would exceed the storage limit or make the balance negative.")
			account[currency] += amount
			add_history(account, currency, amount, "Administrator [administrator.ckey]: [reason]")
			description = "Adjusted [owner_key]/[character_id] [currency] by [amount]"
		if("freeze")
			if(!account)
				return reject("Account not found.")
			account["frozen"] = !account["frozen"]
			description = "[account["frozen"] ? "Froze" : "Unfroze"] [owner_key]/[character_id]"
		else
			return reject("Unknown administrative action.")
	add_admin_audit(snapshot, administrator.ckey, description, reason)
	if(!commit(snapshot))
		return FALSE
	var/message = "[key_name(administrator)] [description]. Reason: [reason]"
	log_admin(message)
	message_admins(message)
	log_econ(message)
	return TRUE

/** Clear player savings in a pending snapshot, retaining identities so already-bound round accounts still work. */
/datum/savings_ledger/proc/reset_accounts(list/snapshot)
	var/list/owners = snapshot["owners"]
	var/accounts_reset = 0
	for(var/owner_key in owners)
		var/list/owner = owners[owner_key]
		owner["round"] = round_token
		owner["earned"] = 0
		owner["levy_round"] = ""
		var/list/characters = owner["characters"]
		for(var/character_id in characters)
			var/list/account = characters[character_id]
			account[SAVINGS_REGULAR] = 0
			account[SAVINGS_OFFSHORE] = 0
			account["frozen"] = FALSE
			account["history"] = list()
			account["purchases"] = list()
			accounts_reset++
	return accounts_reset

/** Add an administrative record to the pending snapshot without changing the committed ledger. */
/datum/savings_ledger/proc/add_admin_audit(list/snapshot, actor, description, reason)
	var/list/audit = snapshot["audit"]
	audit.Insert(1, list(list("time" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"), "actor" = actor, "action" = description, "reason" = reason)))
	if(length(audit) > SAVINGS_AUDIT_LIMIT)
		audit.Cut(SAVINGS_AUDIT_LIMIT + 1)

ADMIN_VERB(persistent_economy, R_ADMIN, "Manage Persistent Economy", "Manage character savings, offshore funds, and monetary policy.", ADMIN_CATEGORY_GAME)
	var/static/datum/savings_panel/admin/panel = new
	panel.ui_interact(user.mob)
