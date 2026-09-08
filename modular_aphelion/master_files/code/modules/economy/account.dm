/datum/bank_account
	/// Authenticated player key captured during job equipment; never inferred from an ID card.
	var/savings_owner
	/// Stable character account key captured during job equipment.
	var/savings_character
	/// Starting grant excluded from net earnings eligible for persistent deposits.
	var/savings_starting_balance = 0
	/// Ledger attached to this payroll account; weak to avoid retaining a recovered subsystem.
	var/datum/weakref/savings_ledger
	/// Cleared funds already represented in account_balance. The remainder is temporary shift credit.
	var/savings_cleared_balance = 0
	/// Recent successful round transactions, newest first. Separate from persistent savings and NT Pay's abbreviated history.
	var/list/round_economy_history

/datum/mind
	/// Original round bank associated with this character, retained through cloning and body changes without holding it alive.
	var/datum/weakref/savings_bank

/** Bind a station account to its original player's character after issuing the starting grant. */
/datum/bank_account/proc/bind_savings(client/player_client, datum/mind/player_mind)
	if(!player_client || !player_mind || !SSsavings.ledger || savings_owner)
		return
	savings_owner = player_client.ckey
	savings_character = SSsavings.ledger.open_account(savings_owner, account_holder)
	savings_starting_balance = account_balance
	player_mind.savings_bank = WEAKREF(src)
	SSsavings.ledger.attach_bank(src)

/** Apply an already-authorized bank change without initiating another persistence transaction. */
/datum/bank_account/proc/apply_bank_change(amount, reason, debt_collected = 0, fee = 0, levy = 0)
	account_balance += amount
	record_round_transaction(amount + fee + levy, reason, debt_collected, account_balance + fee + levy)
	if(reason)
		add_log_to_history(amount + fee + levy, reason)
	if(fee)
		record_round_transaction(-fee, "Settlement fee", balance_after = account_balance + levy)
		add_log_to_history(-fee, "Settlement fee")
	if(levy)
		record_round_transaction(-levy, "Account maintenance levy")
		add_log_to_history(-levy, "Account maintenance levy")
	if(debt_collected)
		pay_debt(debt_collected, FALSE)

/** Return net round wealth above the starting grant. Debt and CRAB locks block persistent deposits. */
/datum/bank_account/proc/savings_available()
	if(account_debt > 0 || length(being_dumped))
		return 0
	return max(0, round(account_balance - savings_starting_balance))

/** Record the actual round-bank change, including post-transaction balance and withheld debt. */
/datum/bank_account/proc/record_round_transaction(amount, reason, debt_collected = 0, balance_after)
	LAZYINITLIST(round_economy_history)
	round_economy_history.Insert(1, list(list(
		"time" = round_timestamp(),
		"amount" = amount,
		"balance" = isnull(balance_after) ? account_balance : balance_after,
		"reason" = reason || "Unspecified account adjustment",
		"debt_collected" = debt_collected,
		"statement_time" = server_timestamp("YYYY-MM-DD hh:mm:ss", ic_time = TRUE),
	)))
	if(length(round_economy_history) > ROUND_ECONOMY_HISTORY_LIMIT)
		round_economy_history.Cut(ROUND_ECONOMY_HISTORY_LIMIT + 1)

/** Build an admin-only round account view. Its caller must check administrator rights before sending this data. */
/datum/bank_account/proc/round_economy_data()
	return list(
		"id" = "[account_id]",
		"name" = account_holder,
		"owner" = savings_owner,
		"character_id" = savings_character,
		"balance" = account_balance,
		"debt" = account_debt,
		"history" = round_economy_history || list(),
	)

/** Apply a bounded whole-credit budget adjustment through normal banking, preserving debt collection and cargo side effects. */
/datum/bank_account/department/proc/adjust_budget(amount, reason)
	if(!isnum(amount) || amount == 0 || abs(amount) > SAVINGS_MAX_AMOUNT || round(amount) != amount || account_balance + amount < 0)
		return FALSE
	return adjust_money(amount, reason)
