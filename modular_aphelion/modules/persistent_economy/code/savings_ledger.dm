/** Character savings ledger. Each mutation publishes one validated snapshot, including its audit and earning counters. */
/datum/savings_ledger
	/// Committed JSON-compatible state. Call ledger methods instead of mutating this list.
	var/list/data
	/// Storage path, or null for isolated in-memory tests.
	var/path
	/// Unique round identity, shared by all characters and reconnects this round.
	var/round_token
	/// Fail closed on unreadable data or failed writes.
	var/storage_error
	/// Last rejected operation, suitable for player feedback.
	var/last_error
	/// Explanation of recovered legacy histories, displayed to administrators this session.
	var/history_recovery_notice
	/// Weak references to payroll accounts that display the ledger's cleared regular balance.
	var/list/bound_banks = list()

/datum/savings_ledger/New(path, round_token)
	src.path = path
	src.round_token = round_token
	data = list(
		"version" = SAVINGS_VERSION,
		"settings" = list("enabled" = TRUE, "round_cap" = 2000, "deposit_fee" = 10, "balance_cap" = 100000, "levy_threshold" = 20000, "levy_rate" = 1),
		"owners" = list(),
		"audit" = list(),
	)
	if(!path || (!fexists(path) && !fexists("[path].backup")))
		return
	var/list/loaded = safe_json_decode(file2text(path))
	var/list/backup = safe_json_decode(file2text("[path].backup"))
	var/repaired = repair_histories(loaded, backup)
	if(valid_snapshot(loaded))
		if(repaired)
			if(!fexists("[path].history-recovery") && !fcopy(path, "[path].history-recovery"))
				storage_error = "Could not preserve the original savings file before history recovery."
				return
			commit(loaded)
		else
			data = loaded
		return
	loaded = backup
	repair_histories(loaded)
	if(valid_snapshot(loaded) && fcopy("[path].backup", path))
		data = loaded
		log_econ("Persistent savings recovered from backup: [path]")
		return
	storage_error = "Savings storage is invalid. An administrator must restore a valid backup and restart."
	log_econ(storage_error)

/** Copy the JSON snapshot without deep_copy_list's null associations, which serialize record arrays as /list objects. */
/datum/savings_ledger/proc/copy_snapshot()
	return json_decode(json_encode(data))

/** Validate both the JSON array shape and the fields the interface renders. */
/datum/savings_ledger/proc/valid_records(list/records, administrative = FALSE)
	if(!islist(records) || copytext(json_encode(records), 1, 2) != "\[")
		return FALSE
	for(var/list/entry as anything in records)
		if(!islist(entry) || !istext(entry["time"]) || !istext(entry["reason"]))
			return FALSE
		if(administrative)
			if(!istext(entry["actor"]) || !istext(entry["action"]))
				return FALSE
		else if(!istext(entry["round"]) || !(entry["currency"] in list(SAVINGS_REGULAR, SAVINGS_OFFSHORE)) || !isnum(entry["amount"]))
			return FALSE
	return TRUE

/** Recover malformed legacy history arrays independently of balances, policy, allowances, and receipts. */
/datum/savings_ledger/proc/repair_histories(list/snapshot, list/backup)
	if(!islist(snapshot) || snapshot["version"] != SAVINGS_VERSION || !islist(snapshot["owners"]))
		return FALSE
	var/repaired = FALSE
	if(!valid_records(snapshot["audit"], administrative = TRUE))
		snapshot["audit"] = valid_records(backup?["audit"], administrative = TRUE) ? json_decode(json_encode(backup["audit"])) : list()
		repaired = TRUE
	var/list/owners = snapshot["owners"]
	for(var/owner_key in owners)
		var/list/owner = owners[owner_key]
		if(!islist(owner) || !islist(owner["characters"]))
			continue
		var/list/characters = owner["characters"]
		for(var/character_id in characters)
			var/list/account = characters[character_id]
			if(!islist(account) || valid_records(account["history"]))
				continue
			var/list/old_account
			if(islist(backup) && islist(backup["owners"]))
				old_account = find_account(owner_key, character_id, backup)
			account["history"] = valid_records(old_account?["history"]) ? json_decode(json_encode(old_account["history"])) : list()
			repaired = TRUE
	if(repaired)
		history_recovery_notice = "Legacy history records were malformed. Available backup histories were recovered without changing current balances or policy. Missing entries may still be available in economy logs."
		add_admin_audit(snapshot, "System", "Recovered legacy history arrays", history_recovery_notice)
		log_econ(history_recovery_notice)
	return repaired

/** Accept only bounded whole-credit amounts. Zero is allowed for balances and settings. */
/datum/savings_ledger/proc/valid_amount(amount, allow_zero = FALSE)
	return isnum(amount) && amount >= (allow_zero ? 0 : 1) && amount <= SAVINGS_MAX_AMOUNT && round(amount) == amount

/** Validate saved policy before loading or changing it. */
/datum/savings_ledger/proc/valid_settings(list/settings)
	if(!islist(settings) || !(settings["enabled"] in list(TRUE, FALSE)))
		return FALSE
	for(var/setting in list("round_cap", "balance_cap", "levy_threshold"))
		if(!valid_amount(settings[setting], allow_zero = TRUE))
			return FALSE
	for(var/setting in list("deposit_fee", "levy_rate"))
		if(!valid_amount(settings[setting], allow_zero = TRUE) || settings[setting] > 100)
			return FALSE
	return TRUE

/** Reject unsupported or malformed snapshots instead of silently resetting player funds. */
/datum/savings_ledger/proc/valid_snapshot(list/snapshot)
	if(!islist(snapshot) || snapshot["version"] != SAVINGS_VERSION || !valid_settings(snapshot["settings"]) || !islist(snapshot["owners"]) || !valid_records(snapshot["audit"], administrative = TRUE))
		return FALSE
	var/list/owners = snapshot["owners"]
	for(var/owner_key in owners)
		var/list/owner = owners[owner_key]
		if(!istext(owner_key) || !length(owner_key) || ckey(owner_key) != owner_key || !islist(owner))
			return FALSE
		if(!islist(owner["characters"]) || !valid_amount(owner["earned"], allow_zero = TRUE) || !istext(owner["round"]) || !istext(owner["levy_round"]))
			return FALSE
		var/list/characters = owner["characters"]
		for(var/character_id in characters)
			var/list/account = characters[character_id]
			if(!istext(character_id) || !islist(account) || !istext(account["name"]) || !length(account["name"]))
				return FALSE
			if(!valid_amount(account[SAVINGS_REGULAR], allow_zero = TRUE) || !valid_amount(account[SAVINGS_OFFSHORE], allow_zero = TRUE))
				return FALSE
			if(!(account["frozen"] in list(TRUE, FALSE)) || !valid_records(account["history"]) || !islist(account["purchases"]))
				return FALSE
			var/list/purchases = account["purchases"]
			for(var/receipt_id in purchases)
				var/list/receipt = purchases[receipt_id]
				if(!istext(receipt_id) || !length(receipt_id) || !islist(receipt) || !valid_amount(receipt["amount"]))
					return FALSE
				if(!(receipt["currency"] in list(SAVINGS_REGULAR, SAVINGS_OFFSHORE)) || !(receipt["refunded"] in list(TRUE, FALSE)))
					return FALSE
	return TRUE

/** Commit without yielding. A failed write leaves in-memory balances untouched and disables further mutations. */
/datum/savings_ledger/proc/commit(list/snapshot, list/deferred_banks)
	if(storage_error || !valid_snapshot(snapshot))
		return reject(storage_error || "Invalid savings transaction.")
	if(path)
		var/encoded = json_encode(snapshot)
		var/pending_path = "[path].pending"
		try
			rustg_file_write(encoded, pending_path)
			if(file2text(pending_path) != encoded)
				throw EXCEPTION("Could not verify pending savings write.")
			if(fexists(path) && !fcopy(path, "[path].backup"))
				throw EXCEPTION("Could not preserve savings backup.")
			if(!fcopy(pending_path, path) || file2text(path) != encoded)
				throw EXCEPTION("Could not publish savings write.")
			fdel(pending_path)
		catch(var/exception/error)
			storage_error = "Savings storage failed. Transactions are disabled until an administrator checks the files and restarts."
			log_econ("[storage_error] [error]")
			return reject(storage_error)
	data = snapshot
	last_error = null
	sync_banks(deferred_banks)
	return TRUE

/** Return FALSE and retain a human-readable rejection reason. */
/datum/savings_ledger/proc/reject(reason)
	last_error = reason
	return FALSE

/** Resolve a stable character key from the saved character name, preserving punctuation and ignoring case. */
/datum/savings_ledger/proc/character_key(character_name)
	if(!istext(character_name) || !length(trim(character_name)))
		return null
	return md5(LOWER_TEXT(trim(character_name)))

/** Open a ckey-owned character account. In-round aliases and ID-card names do not change this identity. */
/datum/savings_ledger/proc/open_account(owner_key, character_name)
	owner_key = ckey(owner_key)
	var/character_id = character_key(character_name)
	if(!owner_key || !character_id || storage_error)
		return null
	if(find_account(owner_key, character_id))
		return character_id
	var/list/snapshot = copy_snapshot()
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	if(!owner)
		owner = list("round" = round_token, "earned" = 0, "levy_round" = "", "characters" = list())
		owners[owner_key] = owner
	var/list/characters = owner["characters"]
	characters[character_id] = list(
		"name" = trim(character_name),
		SAVINGS_REGULAR = 0,
		SAVINGS_OFFSHORE = 0,
		"frozen" = FALSE,
		"history" = list(),
		"purchases" = list(),
	)
	return commit(snapshot) ? character_id : null

/** Find an account inside its owner's namespace. Never accept a client-supplied ckey for player transactions. */
/datum/savings_ledger/proc/find_account(owner_key, character_id, list/snapshot)
	if(!snapshot)
		snapshot = data
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	if(!islist(owner))
		return null
	var/list/characters = owner["characters"]
	return islist(characters) ? characters[character_id] : null

/** Count both currencies across an owner's characters, preventing account splitting from bypassing monetary policy. */
/datum/savings_ledger/proc/owner_total(owner_key, list/snapshot)
	if(!snapshot)
		snapshot = data
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	var/list/characters = owner?["characters"]
	var/total = 0
	for(var/character_id in characters)
		var/list/account = characters[character_id]
		total += account[SAVINGS_REGULAR] + account[SAVINGS_OFFSHORE]
	return total

/** Return the gross earning allowance shared by all of a ckey's characters and both currencies. */
/datum/savings_ledger/proc/remaining_allowance(owner_key, list/snapshot)
	if(!snapshot)
		snapshot = data
	var/list/settings = snapshot["settings"]
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	var/earned = owner?["round"] == round_token ? owner["earned"] : 0
	return max(0, settings["round_cap"] - earned)

/** Check common transaction policy. Administrative repairs explicitly bypass enabled/frozen status. */
/datum/savings_ledger/proc/can_transact(owner_key, character_id, currency, amount)
	if(storage_error)
		return reject(storage_error)
	var/list/settings = data["settings"]
	if(!settings["enabled"])
		return reject("Account settlement is temporarily suspended.")
	if(!(currency in list(SAVINGS_REGULAR, SAVINGS_OFFSHORE)) || !valid_amount(amount))
		return reject("Enter a positive whole-credit amount.")
	var/list/account = find_account(owner_key, character_id)
	if(!account || account["frozen"])
		return reject("This account is unavailable or restricted.")
	return TRUE

/** Add a bounded, persisted per-character transaction record. The full transaction also goes to the economy log after commit. */
/datum/savings_ledger/proc/add_history(list/account, currency, amount, reason)
	var/list/history = account["history"]
	history.Insert(1, list(list("time" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"), "statement_time" = server_timestamp("YYYY-MM-DD hh:mm:ss", ic_time = TRUE), "round" = round_token, "currency" = currency, "amount" = amount, "reason" = reason)))
	if(length(history) > SAVINGS_HISTORY_LIMIT)
		history.Cut(SAVINGS_HISTORY_LIMIT + 1)

/** Apply the active-round levy once per ckey, across all its characters and currencies. Offline owners are not charged. */
/datum/savings_ledger/proc/apply_levy(owner_key, list/snapshot)
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	if(owner["levy_round"] == round_token)
		return
	owner["levy_round"] = round_token
	var/list/settings = snapshot["settings"]
	var/total = owner_total(owner_key, snapshot)
	var/levy = ceil(max(0, total - settings["levy_threshold"]) * settings["levy_rate"] / 100)
	if(!levy)
		return
	var/list/characters = owner["characters"]
	var/remaining_balance = total
	for(var/character_id in characters)
		var/list/account = characters[character_id]
		for(var/currency in list(SAVINGS_REGULAR, SAVINGS_OFFSHORE))
			var/balance = account[currency]
			var/charge = remaining_balance ? min(balance, ceil(levy * balance / remaining_balance)) : 0
			remaining_balance -= balance
			levy -= charge
			if(charge)
				account[currency] -= charge
				add_history(account, currency, -charge, "Account maintenance levy")

/**
 * Credit newly earned persistent money, returning net credited money or FALSE.
 * Arguments:
 * * owner_key - authenticated ckey captured at character spawn.
 * * character_id - server-bound character account key.
 * * currency - regular or offshore; future smuggling sales must use offshore.
 * * amount - gross income; the whole amount must fit the shared round cap.
 * * reason - server-generated earning description.
 * * source_bank - optional round bank debited by the gross amount, excluding its starting grant.
 */
/datum/savings_ledger/proc/earn(owner_key, character_id, currency, amount, reason, datum/bank_account/source_bank)
	if(source_bank?.savings_ledger?.resolve())
		return reject("This account settles incoming payments automatically.")
	if(!can_transact(owner_key, character_id, currency, amount))
		return FALSE
	if(amount > remaining_allowance(owner_key))
		return reject("This exceeds your remaining shift settlement allowance.")
	if(source_bank && (source_bank.savings_owner != owner_key || source_bank.savings_character != character_id || source_bank.account_debt > 0 || length(source_bank.being_dumped) || amount > source_bank.savings_available()))
		return reject("These funds are not eligible for settlement. Clear any outstanding debt or account restriction first.")
	var/list/snapshot = copy_snapshot()
	apply_levy(owner_key, snapshot)
	var/list/settings = snapshot["settings"]
	var/fee = ceil(amount * settings["deposit_fee"] / 100)
	var/net = amount - fee
	if(net <= 0)
		return reject("The deposit must exceed its fee.")
	if(owner_total(owner_key, snapshot) + net > settings["balance_cap"])
		return reject("This exceeds your cleared-funds limit.")
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[owner_key]
	if(owner["round"] != round_token)
		owner["round"] = round_token
		owner["earned"] = 0
	owner["earned"] += amount
	var/list/account = find_account(owner_key, character_id, snapshot)
	account[currency] += net
	add_history(account, currency, net, "[reason] (gross [amount], fee [fee])")
	if(source_bank && !source_bank.adjust_money(-amount, "Savings: Deposit"))
		return reject("Insufficient available funds.")
	if(!commit(snapshot))
		if(source_bank)
			source_bank.adjust_money(amount, "Savings: Deposit reversed after failed save")
		return FALSE
	log_econ("Savings income [owner_key]/[character_id]: [currency] +[net], gross [amount], fee [fee], reason [reason]")
	return net

/** Convert regular savings to offshore at 1:1. No reverse conversion or withdrawal into round funds is provided. */
/datum/savings_ledger/proc/convert_offshore(owner_key, character_id, amount)
	if(!can_transact(owner_key, character_id, SAVINGS_REGULAR, amount))
		return FALSE
	var/list/snapshot = copy_snapshot()
	var/list/account = find_account(owner_key, character_id, snapshot)
	if(account[SAVINGS_REGULAR] < amount)
		return reject("Insufficient cleared funds in your current account.")
	account[SAVINGS_REGULAR] -= amount
	account[SAVINGS_OFFSHORE] += amount
	add_history(account, SAVINGS_REGULAR, -amount, "Conversion to offshore")
	add_history(account, SAVINGS_OFFSHORE, amount, "Conversion from regular savings")
	if(!commit(snapshot))
		return FALSE
	log_econ("Savings conversion [owner_key]/[character_id]: [amount] regular to offshore")
	return TRUE

/**
 * Debit a future persistent purchase exactly once. Return TRUE only for a newly committed purchase.
 * A duplicate receipt returns FALSE; callers must not deliver items on a failed debit.
 * Arguments:
 * * receipt_id - permanent, server-generated order identifier; never reuse it, including after a refund.
 */
/datum/savings_ledger/proc/purchase(owner_key, character_id, currency, amount, receipt_id, reason)
	if(!can_transact(owner_key, character_id, currency, amount) || !istext(receipt_id) || !length(receipt_id))
		return FALSE
	var/list/snapshot = copy_snapshot()
	var/list/account = find_account(owner_key, character_id, snapshot)
	var/list/purchases = account["purchases"]
	if(purchases[receipt_id])
		return reject("This purchase receipt has already been used.")
	if(account[currency] < amount)
		return reject("Insufficient [currency] savings.")
	account[currency] -= amount
	purchases[receipt_id] = list("currency" = currency, "amount" = amount, "refunded" = FALSE)
	add_history(account, currency, -amount, "Purchase [receipt_id]: [reason]")
	if(!commit(snapshot))
		return FALSE
	log_econ("Savings purchase [owner_key]/[character_id]: [currency] -[amount], receipt [receipt_id], reason [reason]")
	return TRUE

/** Refund a recorded failed purchase once, to its original currency. Refunds do not create fresh earning allowance. */
/datum/savings_ledger/proc/refund_purchase(owner_key, character_id, receipt_id, reason)
	var/list/account = find_account(owner_key, character_id)
	var/list/purchases = account?["purchases"]
	var/list/receipt = purchases?[receipt_id]
	if(!receipt || receipt["refunded"] || !can_transact(owner_key, character_id, receipt["currency"], receipt["amount"]))
		return reject("This purchase cannot be refunded.")
	var/list/snapshot = copy_snapshot()
	account = find_account(owner_key, character_id, snapshot)
	purchases = account["purchases"]
	receipt = purchases[receipt_id]
	var/currency = receipt["currency"]
	var/amount = receipt["amount"]
	account[currency] += amount
	receipt["refunded"] = TRUE
	add_history(account, currency, amount, "Refund [receipt_id]: [reason]")
	if(!commit(snapshot))
		return FALSE
	log_econ("Savings refund [owner_key]/[character_id]: [currency] +[amount], receipt [receipt_id], reason [reason]")
	return TRUE
