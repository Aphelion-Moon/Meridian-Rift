/client
	/// Prevent repeated savings actions from flooding synchronous disk writes.
	COOLDOWN_DECLARE(savings_transaction_cooldown)

/** Authenticated savings UI. Players can view their own characters, and transact only as their bound active character. */
/datum/savings_panel
	/// Administrative panel variant; its rights are checked for data and every action.
	var/admin_mode = FALSE
	/// Administrative changes to nonpersistent department budgets during this round.
	var/list/department_audit = list()

/** Restricted overview and management UI for administrators with R_ADMIN. */
/datum/savings_panel/admin
	admin_mode = TRUE

/datum/savings_panel/ui_status(mob/user, datum/ui_state/state)
	if(!user.client || (admin_mode && !check_rights_for(user.client, R_ADMIN)))
		return UI_CLOSE
	return UI_INTERACTIVE

/datum/savings_panel/ui_interact(mob/user, datum/tgui/ui)
	if(!SSsavings.ledger)
		to_chat(user, span_warning("Persistent savings are still loading."))
		return
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, admin_mode ? "PersistentEconomyAdmin" : "PersistentSavings")
		ui.open()

/** Resolve ownership through the original mind binding, never through a held, renamed, or stolen ID. */
/datum/savings_panel/proc/active_bank(mob/user)
	if(!isliving(user) || user.stat != STABLE || IS_UNCONSCIOUS(user) || user.mind?.current != user || SSticker.current_state != GAME_STATE_PLAYING)
		return null
	var/datum/bank_account/bank = user.mind.savings_bank?.resolve()
	if(!bank)
		user.mind.savings_bank = null
		return null
	if(bank.savings_owner != user.ckey || !bank.savings_character)
		return null
	return bank

/datum/savings_panel/ui_data(mob/user)
	if(ui_status(user) != UI_INTERACTIVE)
		return list()
	if(!admin_mode)
		return banking_data(user)
	var/datum/savings_ledger/ledger = SSsavings.ledger
	var/list/result = list("settings" = ledger.data["settings"], "storage_error" = ledger.storage_error)
	var/list/owners = ledger.data["owners"]
	var/list/accounts = list()
	var/regular_total = 0
	var/offshore_total = 0
	for(var/owner_key in owners)
		var/list/owner = owners[owner_key]
		var/list/characters = owner["characters"]
		for(var/character_id in characters)
			var/list/account = characters[character_id]
			accounts += list(list(
				"id" = character_id,
				"owner" = owner_key,
				"name" = account["name"],
				"regular" = account[SAVINGS_REGULAR],
				"offshore" = account[SAVINGS_OFFSHORE],
				"frozen" = account["frozen"],
				"remaining" = ledger.remaining_allowance(owner_key),
				"history" = account["history"],
			))
			regular_total += account[SAVINGS_REGULAR]
			offshore_total += account[SAVINGS_OFFSHORE]
	result["accounts"] = accounts
	result["regular_total"] = regular_total
	result["offshore_total"] = offshore_total
	if(admin_mode)
		result["audit"] = ledger.data["audit"]
		result["history_recovery_notice"] = ledger.history_recovery_notice
		result["round_accounts"] = list()
		for(var/account_id in SSeconomy.bank_accounts_by_id)
			var/datum/bank_account/bank = SSeconomy.bank_accounts_by_id[account_id]
			result["round_accounts"] += list(bank.round_economy_data())
		result["departments"] = list()
		for(var/datum/bank_account/department/budget as anything in SSeconomy.departmental_accounts)
			var/list/budget_data = budget.round_economy_data()
			budget_data["id"] = budget.department_id
			result["departments"] += list(budget_data)
		result["department_audit"] = department_audit
	return result

/** Return only the authenticated character's banking details; internal notes and other characters never enter the PDA payload. */
/datum/savings_panel/proc/banking_data(mob/user)
	var/datum/savings_ledger/ledger = SSsavings.ledger
	var/datum/bank_account/bank = active_bank(user)
	var/list/account = bank ? ledger.find_account(bank.savings_owner, bank.savings_character) : null
	if(!account)
		return list("holder" = null)
	return list(
		"holder" = account["name"],
		"number" = "[bank.account_id]",
		"balance" = bank.account_balance,
		"cleared" = account[SAVINGS_REGULAR],
		"offshore" = account[SAVINGS_OFFSHORE],
		"shift_credit" = max(0, bank.account_balance - bank.savings_cleared_balance),
		"debt" = bank.account_debt,
		"restricted" = account["frozen"] || length(bank.being_dumped) > 0,
		"unavailable" = !!ledger.storage_error,
		"settings" = ledger.data["settings"],
		"remaining" = ledger.remaining_allowance(user.ckey),
		"activity" = savings_public_statement(bank.round_economy_history) + savings_public_statement(account["history"], SAVINGS_REGULAR, ledger.round_token),
		"offshore_activity" = savings_public_statement(account["history"], SAVINGS_OFFSHORE),
	)

/datum/savings_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	return handle_action(ui.user, action, params)

/** Shared authenticated action handler for the PDA program and administrative interface. */
/datum/savings_panel/proc/handle_action(mob/user, action, list/params)
	if(ui_status(user) != UI_INTERACTIVE)
		return FALSE
	var/datum/savings_ledger/ledger = SSsavings.ledger
	var/success = FALSE
	if(admin_mode)
		if(action == "adjust_department")
			return adjust_department(user, params["id"], params["amount"], params["reason"])
		success = ledger.admin_change(user.client, action, params["owner"], params["id"], params["currency"], params["amount"], params["reason"], params["settings"], params["confirmation"])
	else
		if(!COOLDOWN_FINISHED(user.client, savings_transaction_cooldown))
			to_chat(user, span_warning("Please wait for your previous banking request to complete."))
			return TRUE
		var/datum/bank_account/bank = active_bank(user)
		if(!bank)
			to_chat(user, span_warning("NT Banking could not verify your account. Please try again when account access is available."))
			return TRUE
		var/amount = params["amount"]
		switch(action)
			if("convert")
				if(length(bank.being_dumped))
					to_chat(user, span_warning("Outgoing transfers are restricted on this account."))
					return TRUE
				success = ledger.convert_offshore(user.ckey, bank.savings_character, amount)
			else
				return FALSE
	if(success)
		if(!admin_mode)
			COOLDOWN_START(user.client, savings_transaction_cooldown, 2 SECONDS)
		to_chat(user, span_notice(admin_mode ? "Economy update saved." : "Your transfer has been completed."))
	else
		var/error = !admin_mode && ledger.storage_error ? "NT Banking is temporarily unavailable. Please try again later." : ledger.last_error
		to_chat(user, span_warning(error || "Your request could not be completed."))
	return TRUE

/** Adjust a department resolved from the authoritative department list. Savings outages do not prevent round-budget administration. */
/datum/savings_panel/proc/adjust_department(mob/user, department_id, amount, reason)
	if(!admin_mode || !check_rights_for(user.client, R_ADMIN))
		return FALSE
	if(!istext(department_id) || !istext(reason) || !length(trim(reason)))
		to_chat(user, span_warning("Select a department and provide a reason."))
		return TRUE
	var/datum/bank_account/department/budget = SSeconomy.get_dep_account(department_id)
	if(!budget)
		to_chat(user, span_warning("Department budget not found."))
		return TRUE
	reason = copytext(trim(reason), 1, MAX_MESSAGE_LEN)
	var/before = budget.account_balance
	if(!budget.adjust_budget(amount, "Administrator [user.ckey]: [reason]"))
		to_chat(user, span_warning("Enter a nonzero whole-credit adjustment within one million credits that does not overdraw the budget."))
		return TRUE
	var/description = "Adjusted [budget.account_holder] ([department_id]) by [amount]; balance [before] → [budget.account_balance]"
	department_audit.Insert(1, list(list("time" = time2text(world.realtime, "YYYY-MM-DD hh:mm:ss"), "actor" = user.ckey, "action" = description, "reason" = reason)))
	if(length(department_audit) > SAVINGS_AUDIT_LIMIT)
		department_audit.Cut(SAVINGS_AUDIT_LIMIT + 1)
	var/message = "[key_name(user)] [description]. Reason: [reason]"
	log_admin(message)
	message_admins(message)
	log_econ(message)
	to_chat(user, span_notice("[budget.account_holder] now holds [budget.account_balance] credits."))
	return TRUE
