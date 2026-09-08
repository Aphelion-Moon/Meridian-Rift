/** Attach cleared funds to the payroll account without treating the opening balance as new income. */
/datum/savings_ledger/proc/attach_bank(datum/bank_account/bank)
	if(bank.savings_ledger?.resolve() || !find_account(bank.savings_owner, bank.savings_character))
		return FALSE
	bank.savings_ledger = WEAKREF(src)
	bound_banks += WEAKREF(bank)
	sync_banks(null, "Balance brought forward")
	return TRUE

/** Refresh every live representation after a committed debit, levy, conversion, refund, admin change, or reset. */
/datum/savings_ledger/proc/sync_banks(list/deferred_banks, reason = "Account adjustment")
	for(var/datum/weakref/bank_ref as anything in bound_banks.Copy())
		var/datum/bank_account/bank = bank_ref.resolve()
		if(!bank)
			bound_banks -= bank_ref
			continue
		if(bank in deferred_banks)
			continue
		var/list/account = find_account(bank.savings_owner, bank.savings_character)
		var/cleared = account ? account[SAVINGS_REGULAR] : 0
		var/change = cleared - bank.savings_cleared_balance
		bank.savings_cleared_balance = cleared
		if(change)
			bank.apply_bank_change(change, reason)

/** Prepare one bank operation in a shared snapshot; balances are untouched until the complete operation commits. */
/datum/savings_ledger/proc/prepare_bank_change(datum/bank_account/bank, amount, reason, list/snapshot)
	if(!isnum(amount) || !amount)
		return null
	var/datum/savings_ledger/attached = bank.savings_ledger?.resolve()
	if(attached && attached != src)
		return null
	var/list/account = attached ? find_account(bank.savings_owner, bank.savings_character, snapshot) : null
	var/cleared = account ? account[SAVINGS_REGULAR] : 0
	var/shift_credit = bank.account_balance - bank.savings_cleared_balance
	if(shift_credit + cleared + amount < 0)
		return null
	var/debt_collected = amount > 0 ? min(ceil(amount * DEBT_COLLECTION_COEFF), bank.account_debt) : 0
	var/net_amount = amount - debt_collected
	var/list/pending = list("gross" = amount, "reason" = reason, "debt" = debt_collected, "transient" = net_amount, "changed" = FALSE, "fee" = 0, "levy" = 0)
	if(!account)
		return pending
	if(net_amount < 0)
		var/remaining = min(cleared, max(0, FLOOR(shift_credit + cleared + net_amount, 1)))
		var/spent = cleared - remaining
		if(spent)
			if(!can_transact(bank.savings_owner, bank.savings_character, SAVINGS_REGULAR, spent))
				return null
			account[SAVINGS_REGULAR] = remaining
			add_history(account, SAVINGS_REGULAR, -spent, reason || "Card payment")
			pending["transient"] += spent
			pending["changed"] = TRUE
		return pending
	var/list/settings = snapshot["settings"]
	if(storage_error || !settings["enabled"] || account["frozen"] || bank.account_debt > 0 || length(bank.being_dumped))
		return pending
	var/list/owners = snapshot["owners"]
	var/list/owner = owners[bank.savings_owner]
	var/wealth = owner_total(bank.savings_owner, snapshot)
	var/levy = owner["levy_round"] == round_token ? 0 : ceil(max(0, wealth - settings["levy_threshold"]) * settings["levy_rate"] / 100)
	var/gross = min(FLOOR(net_amount, 1), remaining_allowance(bank.savings_owner, snapshot), max(0, settings["balance_cap"] - wealth + levy), SAVINGS_MAX_AMOUNT - cleared)
	var/fee = ceil(gross * settings["deposit_fee"] / 100)
	if(gross <= fee)
		return pending
	apply_levy(bank.savings_owner, snapshot)
	pending["levy"] = cleared - account[SAVINGS_REGULAR]
	pending["fee"] = fee
	if(owner["round"] != round_token)
		owner["round"] = round_token
		owner["earned"] = 0
	owner["earned"] += gross
	account[SAVINGS_REGULAR] += gross - fee
	add_history(account, SAVINGS_REGULAR, gross - fee, "Automatic settlement: [reason || "Incoming payment"] (gross [gross], fee [fee])")
	pending["transient"] -= gross
	pending["changed"] = TRUE
	return pending

/** Publish the prepared bank balance and normal debt/history effects after its durable snapshot has committed. */
/datum/savings_ledger/proc/finish_bank_change(datum/bank_account/bank, list/pending)
	if(bank.savings_ledger?.resolve() != src)
		bank.adjust_money(pending["gross"], pending["reason"])
		return
	var/list/account = find_account(bank.savings_owner, bank.savings_character)
	var/cleared = account ? account[SAVINGS_REGULAR] : 0
	var/change = cleared - bank.savings_cleared_balance + pending["transient"]
	bank.savings_cleared_balance = cleared
	bank.apply_bank_change(change, pending["reason"], pending["debt"], pending["fee"], pending["levy"])

/** Settle eligible income automatically and persist card spending before approving it. Shift credit is spent first. */
/datum/savings_ledger/proc/adjust_bank(datum/bank_account/bank, amount, reason)
	var/list/snapshot = copy_snapshot()
	var/list/pending = prepare_bank_change(bank, amount, reason, snapshot)
	if(!pending)
		return FALSE
	if(pending["changed"] && !commit(snapshot, list(bank)))
		return FALSE
	finish_bank_change(bank, pending)
	if(pending["changed"])
		log_econ("Automatic banking [bank.savings_owner]/[bank.savings_character]: change [amount], cleared balance [bank.savings_cleared_balance], reason [reason]")
	return TRUE

/** Transfer both banks in one ledger commit so a failed persistent debit cannot mint money at the recipient. */
/datum/savings_ledger/proc/transfer_banks(datum/bank_account/recipient, datum/bank_account/sender, amount, transfer_reason)
	if(sender == recipient || !isnum(amount) || amount <= 0)
		return FALSE
	var/reason_to = transfer_reason || (IS_DEPARTMENTAL_ACCOUNT(sender) ? "Nanotrasen: Salary" : "Transfer: From [sender.account_holder]")
	var/reason_from = transfer_reason || (IS_DEPARTMENTAL_ACCOUNT(sender) ? "" : "Transfer: To [recipient.account_holder]")
	var/list/snapshot = copy_snapshot()
	var/list/debit = prepare_bank_change(sender, -amount, reason_from, snapshot)
	if(!debit)
		return FALSE
	var/list/credit = prepare_bank_change(recipient, amount, reason_to, snapshot)
	if(!credit)
		return FALSE
	if((debit["changed"] || credit["changed"]) && !commit(snapshot, list(sender, recipient)))
		return FALSE
	finish_bank_change(sender, debit)
	finish_bank_change(recipient, credit)
	SSblackbox.record_feedback("amount", "credits_transferred", amount)
	log_econ("[amount] [MONEY_NAME] transferred from [sender.account_holder] to [recipient.account_holder]")
	return TRUE

/** Translate internal transaction reasons into customer-facing statement categories without exposing admin notes. */
/proc/savings_statement_description(reason, amount)
	var/description = lowertext(reason || "")
	if(findtext(description, "brought forward"))
		return "Balance brought forward"
	if(description == "settlement fee")
		return "Settlement fee"
	if(findtext(description, "admin") || findtext(description, "moderator") || findtext(description, "adjustment"))
		return "Account adjustment"
	if(findtext(description, "offshore") || findtext(description, "conversion"))
		return "Offshore transfer"
	if(findtext(description, "levy"))
		return "Account maintenance charge"
	if(findtext(description, "salary") || findtext(description, "shift payment") || findtext(description, "payroll"))
		return "Payroll credit"
	if(findtext(description, "debt"))
		return "Debt payment"
	if(findtext(description, "transfer"))
		return amount >= 0 ? "Transfer received" : "Transfer sent"
	return amount >= 0 ? "Credit received" : "Card payment"

/** Build a statement using bank descriptions and in-world dates rather than raw administrative reasons or identifiers. */
/proc/savings_public_statement(list/records, currency, exclude_round)
	var/list/statement = list()
	for(var/list/entry as anything in records)
		if(currency && entry["currency"] != currency)
			continue
		if(exclude_round && entry["round"] == exclude_round)
			continue
		statement += list(list(
			"time" = entry["statement_time"] || "Previous activity",
			"amount" = entry["amount"],
			"description" = savings_statement_description(entry["reason"], entry["amount"]),
		))
	return statement
