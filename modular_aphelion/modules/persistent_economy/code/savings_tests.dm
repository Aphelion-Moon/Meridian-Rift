#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)

/** Verify character isolation, shared earning limits, fee sinks, and one-way currency conversion. */
/datum/unit_test/savings_limits

/datum/unit_test/savings_limits/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "round-one")
	var/first = ledger.open_account("testplayer", "First Character")
	var/second = ledger.open_account("testplayer", "Second Character")
	var/other_owner = ledger.open_account("otherplayer", "First Character")
	TEST_ASSERT_EQUAL(first, ledger.open_account("Test Player", " FIRST CHARACTER "), "Case and whitespace should not create a new account")
	TEST_ASSERT_NOTEQUAL(ledger.character_key("A-B"), ledger.character_key("AB"), "Punctuation must not collapse character identities")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", first, SAVINGS_REGULAR, 1000, "Test income"), 900, "Regular income must pay the fee")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", second, SAVINGS_OFFSHORE, 1000, "Smuggling test"), 900, "Offshore income must pay the fee")
	TEST_ASSERT_EQUAL(ledger.remaining_allowance("testplayer"), 0, "Both deposits must exhaust the cap")
	TEST_ASSERT(!ledger.earn("testplayer", first, SAVINGS_REGULAR, 2, "Over cap"), "Regular and offshore income must share the cap")
	TEST_ASSERT(ledger.convert_offshore("testplayer", first, 400), "Regular savings should convert at 1:1")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 1800, "Conversion must conserve total money")
	TEST_ASSERT_EQUAL(ledger.remaining_allowance("testplayer"), 0, "Conversion must not replenish allowance")
	var/list/account = ledger.find_account("testplayer", first)
	TEST_ASSERT_EQUAL(account[SAVINGS_REGULAR], 500, "Conversion must debit regular")
	TEST_ASSERT_EQUAL(account[SAVINGS_OFFSHORE], 400, "Conversion must credit offshore")
	account = ledger.find_account("otherplayer", other_owner)
	TEST_ASSERT_EQUAL(account[SAVINGS_REGULAR], 0, "Same-name characters on other ckeys must be isolated")
	TEST_ASSERT(!ledger.convert_offshore("testplayer", first, -100), "Negative conversion must be rejected")
	TEST_ASSERT(!ledger.earn("testplayer", first, SAVINGS_REGULAR, 1.5, "Fractional"), "Fractional income must be rejected")
	TEST_ASSERT(!ledger.earn("testplayer", first, "fake", 10, "Invalid currency"), "Unknown currencies must be rejected")
	ledger.round_token = "round-two"
	TEST_ASSERT_EQUAL(ledger.remaining_allowance("testplayer"), 2000, "New round must reset allowance")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", first, SAVINGS_REGULAR, 100, "Next round"), 90, "New round deposit must succeed")

/** Test ledger that can reject a commit without touching real player data. */
/datum/savings_ledger/failing_test
	/// Simulated persistence failure, enabled after fixture setup.
	var/fail_writes = FALSE

/datum/savings_ledger/failing_test/commit(list/snapshot, list/deferred_banks)
	if(fail_writes)
		return reject("Simulated write failure")
	return ..()

/** Verify deposits debit exactly once, exclude starting wealth, and roll back on persistence failure. */
/datum/unit_test/savings_round_deposits

/datum/unit_test/savings_round_deposits/Run()
	var/datum/savings_ledger/failing_test/ledger = allocate(/datum/savings_ledger/failing_test, null, "round-one")
	var/character_id = ledger.open_account("testplayer", "First Character")
	var/datum/bank_account/bank = allocate(/datum/bank_account, "Test", null, 1, FALSE)
	bank.savings_owner = "testplayer"
	bank.savings_character = character_id
	bank.adjust_money(500)
	bank.savings_starting_balance = 500
	TEST_ASSERT_EQUAL(bank.savings_available(), 0, "Starting grant cannot be saved")
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 100, "Starting grant", bank), "Cannot deposit starting funds")
	bank.adjust_money(1000)
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Deposit", bank), 900, "Deposit must credit net amount")
	TEST_ASSERT_EQUAL(bank.account_balance, 500, "Gross amount must be removed from the round bank")
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Replay", bank), "Cannot deposit the same funds twice")
	bank.adjust_money(500)
	bank.account_debt = 10
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 100, "Debt bypass", bank), "Debt must block deposits")
	bank.account_debt = 0
	bank.savings_owner = "thief"
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 100, "Wrong owner", bank), "Cannot debit another character's bank")
	bank.savings_owner = "testplayer"
	ledger.fail_writes = TRUE
	var/before_json = json_encode(ledger.data)
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 100, "Failed save", bank), "Failed writes must reject deposit")
	TEST_ASSERT_EQUAL(bank.account_balance, 1000, "Failed save must restore round funds")
	TEST_ASSERT_EQUAL(json_encode(ledger.data), before_json, "Failed save must preserve balance, history, and allowance")

/** Verify combined wealth limits and the once-per-active-round levy, including split character accounts. */
/datum/unit_test/savings_inflation

/datum/unit_test/savings_inflation/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "round-one")
	var/first = ledger.open_account("testplayer", "First Character")
	var/second = ledger.open_account("testplayer", "Second Character")
	var/list/snapshot = ledger.copy_snapshot()
	var/list/account = ledger.find_account("testplayer", first, snapshot)
	account[SAVINGS_REGULAR] = 15000
	account = ledger.find_account("testplayer", second, snapshot)
	account[SAVINGS_OFFSHORE] = 15000
	TEST_ASSERT(ledger.commit(snapshot), "Fixture must be valid")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", first, SAVINGS_REGULAR, 1000, "First deposit"), 900, "First deposit must succeed")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 30800, "Levy should remove 1% of the combined 10000 excess")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", second, SAVINGS_OFFSHORE, 1000, "Second deposit"), 900, "Second deposit must succeed")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 31700, "Second character must not trigger a second levy")
	ledger.round_token = "round-two"
	snapshot = ledger.copy_snapshot()
	var/list/settings = snapshot["settings"]
	settings["balance_cap"] = 31700
	TEST_ASSERT(ledger.commit(snapshot), "Lowered ceiling should preserve existing funds")
	var/before_json = json_encode(ledger.data)
	TEST_ASSERT(!ledger.earn("testplayer", first, SAVINGS_REGULAR, 1000, "Over ceiling"), "Combined ceiling must apply after levy and fee")
	TEST_ASSERT_EQUAL(json_encode(ledger.data), before_json, "Rejected deposits must not levy or consume allowance")
	TEST_ASSERT_EQUAL(ledger.earn("testplayer", first, SAVINGS_REGULAR, 100, "Small deposit"), 90, "Small deposit must fit after levy")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 31673, "Next active round should levy 117 credits once")

/** Verify separate purchase currencies, durable duplicate protection, refunds, and transaction locks. */
/datum/unit_test/savings_purchases

/datum/unit_test/savings_purchases/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "round-one")
	var/character_id = ledger.open_account("testplayer", "First Character")
	TEST_ASSERT(ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Income"), "Fixture income must succeed")
	TEST_ASSERT(!ledger.purchase("testplayer", character_id, SAVINGS_OFFSHORE, 100, "offshore-order", "Contraband"), "Regular money cannot pay for offshore goods")
	TEST_ASSERT(ledger.purchase("testplayer", character_id, SAVINGS_REGULAR, 300, "property-order", "Future property"), "Purchase should debit savings")
	TEST_ASSERT(!ledger.purchase("testplayer", character_id, SAVINGS_REGULAR, 300, "property-order", "Replay"), "Duplicate purchases must not authorize delivery")
	TEST_ASSERT(ledger.refund_purchase("testplayer", character_id, "property-order", "Delivery failed"), "Recorded purchase should refund")
	TEST_ASSERT(!ledger.refund_purchase("testplayer", character_id, "property-order", "Replay"), "Refund must apply once")
	TEST_ASSERT(!ledger.purchase("testplayer", character_id, SAVINGS_REGULAR, 300, "property-order", "Reuse"), "Refunded receipts cannot be reused")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 900, "Refund must restore original wealth")
	TEST_ASSERT_EQUAL(ledger.remaining_allowance("testplayer"), 1000, "Purchases and refunds must not replenish round cap")
	TEST_ASSERT(!ledger.admin_change(null, "adjust", "testplayer", character_id, SAVINGS_REGULAR, 100, "Forged admin"), "Admin calls require rights")
	var/list/snapshot = ledger.copy_snapshot()
	var/list/account = ledger.find_account("testplayer", character_id, snapshot)
	account["frozen"] = TRUE
	TEST_ASSERT(ledger.commit(snapshot), "Fixture freeze must persist")
	TEST_ASSERT(!ledger.convert_offshore("testplayer", character_id, 100), "Frozen accounts cannot convert")
	TEST_ASSERT(!ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 100, "Frozen"), "Frozen accounts cannot earn")
	TEST_ASSERT(!ledger.purchase("testplayer", character_id, SAVINGS_REGULAR, 100, "frozen-order", "Frozen"), "Frozen accounts cannot spend")

/** Verify on-disk reload, receipt persistence, backup recovery, and fail-closed schema validation. */
/datum/unit_test/savings_storage
	/// Test-owned path within this run's log directory.
	var/fixture_path

/datum/unit_test/savings_storage/Destroy()
	if(fixture_path)
		fdel(fixture_path)
		fdel("[fixture_path].backup")
		fdel("[fixture_path].pending")
		fdel("[fixture_path].history-recovery")
	return ..()

/datum/unit_test/savings_storage/Run()
	fixture_path = "[GLOB.log_directory]/savings-fixture.json"
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, fixture_path, "round-one")
	var/character_id = ledger.open_account("testplayer", "First Character")
	TEST_ASSERT(ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Income"), "Saved income must succeed")
	TEST_ASSERT(ledger.purchase("testplayer", character_id, SAVINGS_REGULAR, 200, "saved-order", "Saved purchase"), "Saved purchase must succeed")
	var/datum/savings_ledger/reloaded = allocate(/datum/savings_ledger, fixture_path, "round-one")
	TEST_ASSERT_EQUAL(reloaded.owner_total("testplayer"), 700, "Purchase balance must survive reload")
	TEST_ASSERT_EQUAL(reloaded.remaining_allowance("testplayer"), 1000, "Restart with same round token must preserve cap")
	TEST_ASSERT(!reloaded.purchase("testplayer", character_id, SAVINGS_REGULAR, 200, "saved-order", "Replay"), "Receipt must survive reload")
	TEST_ASSERT(reloaded.refund_purchase("testplayer", character_id, "saved-order", "Failed delivery"), "Refund after reload should work")
	TEST_ASSERT(reloaded.commit(reloaded.copy_snapshot()), "Create matching recovery snapshot")
	rustg_file_write("broken JSON", fixture_path)
	var/datum/savings_ledger/recovered = allocate(/datum/savings_ledger, fixture_path, "round-two")
	TEST_ASSERT(!recovered.storage_error, "Valid backup should recover a corrupt main file")
	TEST_ASSERT_EQUAL(recovered.owner_total("testplayer"), 900, "Recovered balance must match backup")
	TEST_ASSERT(!recovered.refund_purchase("testplayer", character_id, "saved-order", "Replay"), "Refund state must survive reload")
	TEST_ASSERT_EQUAL(recovered.remaining_allowance("testplayer"), 2000, "New round allowance must reset after recovery")
	var/list/malformed = recovered.copy_snapshot()
	var/list/account = recovered.find_account("testplayer", character_id, malformed)
	account[SAVINGS_REGULAR] = -1
	TEST_ASSERT(!recovered.valid_snapshot(malformed), "Negative saved balances must be rejected")
	rustg_file_write("broken JSON", fixture_path)
	rustg_file_write("broken backup", "[fixture_path].backup")
	var/datum/savings_ledger/blocked = allocate(/datum/savings_ledger, fixture_path, "round-two")
	TEST_ASSERT(blocked.storage_error, "Unreadable main and backup must lock the ledger")
	TEST_ASSERT(!blocked.open_account("testplayer", "First Character"), "Corrupt storage must not be overwritten with a fresh account")

/** Verify repeated policy snapshots remain JSON arrays and preserve earlier account/audit records. */
/datum/unit_test/savings_history_arrays

/datum/unit_test/savings_history_arrays/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "history-round")
	var/character_id = ledger.open_account("testplayer", "History Character")
	TEST_ASSERT(ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Original income"), "Income must succeed")
	for(var/iteration in 1 to 3)
		var/list/snapshot = ledger.copy_snapshot()
		var/list/settings = snapshot["settings"]
		settings["levy_threshold"] = 20000 + iteration
		ledger.add_admin_audit(snapshot, "testadmin", "Policy update [iteration]", "Policy regression")
		TEST_ASSERT(ledger.commit(snapshot), "Repeated policy commits must succeed")
		var/list/decoded = json_decode(json_encode(ledger.data))
		TEST_ASSERT(ledger.valid_records(decoded["audit"], administrative = TRUE), "Audit must be a JSON array after every save")
		var/list/audit = decoded["audit"]
		TEST_ASSERT_EQUAL(length(audit), iteration, "Every policy event must survive subsequent saves")
		var/list/account = ledger.find_account("testplayer", character_id, decoded)
		var/list/history = account["history"]
		TEST_ASSERT(ledger.valid_records(history), "Character history must remain an array")
		TEST_ASSERT_EQUAL(history[1]["amount"], 900, "Earlier transactions must keep their amounts")
		TEST_ASSERT_EQUAL(account[SAVINGS_REGULAR], 900, "Policy changes must preserve balances")

/** Verify recovery of the actual legacy /list encoding bug preserves current balances and policy. */
/datum/unit_test/savings_storage/history_recovery

/datum/unit_test/savings_storage/history_recovery/Run()
	fixture_path = "[GLOB.log_directory]/savings-history-fixture.json"
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, fixture_path, "history-round")
	var/character_id = ledger.open_account("testplayer", "History Character")
	TEST_ASSERT(ledger.earn("testplayer", character_id, SAVINGS_REGULAR, 1000, "Original income"), "Income must save")
	var/list/snapshot = ledger.copy_snapshot()
	ledger.add_admin_audit(snapshot, "testadmin", "Original policy", "Original reason")
	TEST_ASSERT(ledger.commit(snapshot), "Original audit must save")
	TEST_ASSERT(fcopy(fixture_path, "[fixture_path].backup"), "Preserve a valid history backup")
	var/list/broken = deep_copy_list(ledger.data)
	var/list/settings = broken["settings"]
	settings["levy_threshold"] = 12345
	var/list/account = ledger.find_account("testplayer", character_id, broken)
	account[SAVINGS_REGULAR] = 1234
	rustg_file_write(json_encode(broken), fixture_path)
	var/datum/savings_ledger/recovered = allocate(/datum/savings_ledger, fixture_path, "next-round")
	TEST_ASSERT(!recovered.storage_error, "Legacy history corruption should be repaired")
	TEST_ASSERT(recovered.history_recovery_notice, "Recovery must be disclosed")
	TEST_ASSERT(fexists("[fixture_path].history-recovery"), "Original corrupted data must be preserved")
	TEST_ASSERT_EQUAL(recovered.owner_total("testplayer"), 1234, "Recovery must not roll balances back to the older backup")
	settings = recovered.data["settings"]
	TEST_ASSERT_EQUAL(settings["levy_threshold"], 12345, "Recovery must preserve the latest policy")
	account = recovered.find_account("testplayer", character_id)
	var/list/history = account["history"]
	TEST_ASSERT_EQUAL(history[1]["amount"], 900, "Valid backup history should be restored")
	var/list/disk_data = json_decode(file2text(fixture_path))
	TEST_ASSERT(recovered.valid_snapshot(disk_data), "Repaired file must be valid on disk")
	var/list/audit = disk_data["audit"]
	TEST_ASSERT_EQUAL(length(audit), 2, "Recovered audit should include a recovery record")

/** Exercise round transaction capture, debt, rejected adjustments, and the history retention limit. */
/datum/unit_test/savings_round_history

/datum/unit_test/savings_round_history/Run()
	var/datum/bank_account/bank = allocate(/datum/bank_account, "Round Account", null, 1, FALSE)
	bank.adjust_money(500, "Salary")
	bank.adjust_money(-100, "Vending")
	TEST_ASSERT(!bank.adjust_money(-1000, "Rejected"), "Insufficient funds must reject")
	TEST_ASSERT_EQUAL(length(bank.round_economy_history), 2, "Rejected debits must not appear as successful transactions")
	var/list/entry = bank.round_economy_history[1]
	TEST_ASSERT_EQUAL(entry["amount"], -100, "Latest debit must be negative")
	TEST_ASSERT_EQUAL(entry["balance"], 400, "Transaction should include resulting balance")
	TEST_ASSERT_EQUAL(entry["reason"], "Vending", "Reason must survive")
	bank.account_debt = 10
	bank.adjust_money(100, "Salary with debt")
	entry = bank.round_economy_history[1]
	TEST_ASSERT_EQUAL(entry["amount"], 90, "History records net balance change after withholding")
	TEST_ASSERT_EQUAL(entry["debt_collected"], 10, "Withheld debt must be visible")
	for(var/iteration in 1 to ROUND_ECONOMY_HISTORY_LIMIT)
		bank.adjust_money(1)
	TEST_ASSERT_EQUAL(length(bank.round_economy_history), ROUND_ECONOMY_HISTORY_LIMIT, "History must remain bounded")
	entry = bank.round_economy_history[1]
	TEST_ASSERT_EQUAL(entry["reason"], "Unspecified account adjustment", "Unlabelled transfers must still be recorded")
	var/list/payload = json_decode(json_encode(bank.round_economy_data()))
	TEST_ASSERT_EQUAL(length(payload["history"]), ROUND_ECONOMY_HISTORY_LIMIT, "Round history must serialize as an array")

/** Department fixture that does not register with the real round's budget list. */
/datum/bank_account/department/savings_test
	department_id = ACCOUNT_ENG
	account_holder = "Test Department"

/datum/bank_account/department/savings_test/New()
	return

/** Validate department additions/removals and permissions without modifying real department budgets. */
/datum/unit_test/savings_department_budgets

/datum/unit_test/savings_department_budgets/Run()
	var/datum/bank_account/department/budget = allocate(/datum/bank_account/department/savings_test)
	TEST_ASSERT(budget.adjust_budget(500, "Admin grant"), "Budget grant must succeed")
	TEST_ASSERT(budget.adjust_budget(-200, "Admin removal"), "Budget removal must succeed")
	TEST_ASSERT_EQUAL(budget.account_balance, 300, "Budget changes must be exact")
	TEST_ASSERT(!budget.adjust_budget(-301, "Overdraft"), "Cannot overdraw department")
	TEST_ASSERT(!budget.adjust_budget("100", "Invalid input"), "String amounts must be rejected")
	TEST_ASSERT(!budget.adjust_budget(0.5, "Fraction"), "Fractional inputs must be rejected")
	TEST_ASSERT(!budget.adjust_budget(SAVINGS_MAX_AMOUNT + 1, "Overflow"), "Oversized inputs must be rejected")
	TEST_ASSERT_EQUAL(length(budget.round_economy_history), 2, "Only successful changes should enter history")
	var/datum/savings_panel/admin/panel = allocate(/datum/savings_panel/admin)
	var/mob/user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!panel.adjust_department(user, ACCOUNT_ENG, 100, "No rights"), "Budget controls must check admin rights")
	TEST_ASSERT_EQUAL(panel.ui_status(user), UI_CLOSE, "Non-admins cannot read any economy panel data")

/** Verify a full player reset survives reload while preserving policy, audit, and live character bindings. */
/datum/unit_test/savings_storage/reset

/datum/unit_test/savings_storage/reset/Run()
	fixture_path = "[GLOB.log_directory]/savings-reset-fixture.json"
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, fixture_path, "reset-round")
	var/first = ledger.open_account("testplayer", "First Character")
	var/second = ledger.open_account("testplayer", "Second Character")
	var/other = ledger.open_account("otherplayer", "Other Character")
	TEST_ASSERT(ledger.earn("testplayer", first, SAVINGS_REGULAR, 1000, "First income"), "Fixture income")
	TEST_ASSERT(ledger.earn("testplayer", second, SAVINGS_OFFSHORE, 1000, "Offshore income"), "Fixture offshore income")
	TEST_ASSERT(ledger.earn("otherplayer", other, SAVINGS_REGULAR, 1000, "Other income"), "Other owner's income")
	TEST_ASSERT(ledger.purchase("testplayer", first, SAVINGS_REGULAR, 100, "old-order", "Old purchase"), "Fixture receipt")
	var/list/snapshot = ledger.copy_snapshot()
	var/list/settings = snapshot["settings"]
	settings["levy_threshold"] = 12345
	var/list/account = ledger.find_account("testplayer", first, snapshot)
	account["frozen"] = TRUE
	ledger.add_admin_audit(snapshot, "testadmin", "Before reset", "Keep this audit")
	TEST_ASSERT(ledger.commit(snapshot), "Fixture policy and freeze")
	TEST_ASSERT(!ledger.admin_change(null, "reset", reason = "Forged reset", confirmation = "RESET ECONOMY"), "Reset requires administrator rights")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 1700, "Unauthorized reset must preserve funds")
	snapshot = ledger.copy_snapshot()
	TEST_ASSERT_EQUAL(ledger.reset_accounts(snapshot), 3, "Reset must reach every character and owner")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 1700, "Preparing reset must not change committed funds")
	ledger.add_admin_audit(snapshot, "testadmin", "Reset persistent economy", "New season")
	TEST_ASSERT(ledger.commit(snapshot), "Reset must persist through the normal save path")
	var/datum/savings_ledger/reloaded = allocate(/datum/savings_ledger, fixture_path, "reset-round")
	TEST_ASSERT_EQUAL(reloaded.owner_total("testplayer"), 0, "Both currencies and characters must reset")
	TEST_ASSERT_EQUAL(reloaded.owner_total("otherplayer"), 0, "Other owners must reset")
	TEST_ASSERT_EQUAL(reloaded.remaining_allowance("testplayer"), 2000, "Earning allowance must start fresh")
	account = reloaded.find_account("testplayer", first)
	TEST_ASSERT_EQUAL(account["name"], "First Character", "Existing character binding must still resolve")
	TEST_ASSERT(!account["frozen"], "Freeze must reset")
	TEST_ASSERT_EQUAL(length(account["history"]), 0, "Player histories must reset")
	TEST_ASSERT_EQUAL(length(account["purchases"]), 0, "Purchase receipts must reset")
	settings = reloaded.data["settings"]
	TEST_ASSERT_EQUAL(settings["levy_threshold"], 12345, "Reset must retain configured policy")
	TEST_ASSERT_EQUAL(length(reloaded.data["audit"]), 2, "Keep previous administrative audit and reset record")
	TEST_ASSERT(!reloaded.refund_purchase("testplayer", first, "old-order", "Old refund"), "An old receipt cannot recreate wiped savings")
	var/datum/bank_account/bank = allocate(/datum/bank_account, "First Character", null, 1, FALSE)
	bank.savings_owner = "testplayer"
	bank.savings_character = first
	bank.adjust_money(500, "Round funds")
	TEST_ASSERT(reloaded.earn("testplayer", bank.savings_character, SAVINGS_REGULAR, 100, "Post-reset deposit", bank), "Existing round binding must still deposit after reset")
	var/datum/savings_ledger/failing_test/failing = allocate(/datum/savings_ledger/failing_test, null, "reset-round")
	TEST_ASSERT(failing.commit(reloaded.copy_snapshot()), "Seed failure fixture")
	snapshot = failing.copy_snapshot()
	failing.reset_accounts(snapshot)
	failing.fail_writes = TRUE
	TEST_ASSERT(!failing.commit(snapshot), "A failed reset must reject")
	TEST_ASSERT_EQUAL(failing.owner_total("testplayer"), 90, "A failed reset must preserve funds")

/** Verify standard PDA installation and the program's shared controller cannot expose administrator actions. */
/datum/unit_test/savings_pda

/datum/unit_test/savings_pda/Run()
	var/obj/item/modular_computer/pda/device = allocate(/obj/item/modular_computer/pda)
	var/datum/computer_file/program/persistent_savings/app = device.find_file_by_name("ntbanking")
	TEST_ASSERT(istype(app), "Standard PDAs must include Persistent Savings")
	TEST_ASSERT(app.program_flags & PROGRAM_ON_NTNET_STORE, "Savings app must be downloadable")
	TEST_ASSERT(!app.savings_controller.admin_mode, "PDA controller must never have administrative access")
	TEST_ASSERT_EQUAL(app.tgui_id, "PersistentSavings", "PDA must open the savings interface")
	var/mob/user = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(!app.savings_controller.handle_action(user, "reset", list("reason" = "Forged", "confirmation" = "RESET ECONOMY")), "Unauthenticated program calls cannot reset savings")

/** Bind an isolated bank to a test ledger without constructing a client or touching production accounts. */
/datum/unit_test/proc/savings_test_bank(datum/savings_ledger/ledger, owner_key, character_name, shift_credit = 0)
	var/datum/bank_account/bank = allocate(/datum/bank_account, character_name, null, 1, FALSE)
	bank.savings_owner = owner_key
	bank.savings_character = ledger.open_account(owner_key, character_name)
	if(shift_credit)
		bank.adjust_money(shift_credit, "Payroll advance")
	ledger.attach_bank(bank)
	return bank

/** Payroll, spending, offshore transfers, purchases, refunds, and reset share the card's actual balance. */
/datum/unit_test/savings_unified_bank

/datum/unit_test/savings_unified_bank/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "bank-round")
	var/id = ledger.open_account("testplayer", "Elena Ward")
	TEST_ASSERT(ledger.earn("testplayer", id, SAVINGS_REGULAR, 1000, "Earlier income"), "Seed cleared funds")
	var/datum/bank_account/bank = savings_test_bank(ledger, "testplayer", "Elena Ward", 500)
	TEST_ASSERT_EQUAL(bank.account_balance, 1400, "Saved funds and payroll advance must be spendable in one account")
	TEST_ASSERT(bank.adjust_money(200, "Nanotrasen: Salary"), "Payroll credit must succeed")
	TEST_ASSERT_EQUAL(bank.account_balance, 1580, "Payroll settlement fee must be charged once")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 1080, "Eligible payroll must persist automatically")
	TEST_ASSERT_EQUAL(bank.round_economy_history[1]["amount"], -20, "Settlement fee must have its own statement entry")
	TEST_ASSERT_EQUAL(bank.round_economy_history[2]["amount"], 200, "Payroll statement must show the payment before fees")
	TEST_ASSERT_EQUAL(bank.round_economy_history[1]["balance"], 1580, "Fee statement must show the final balance")
	TEST_ASSERT(bank.adjust_money(-400, "Vending: Lunch"), "Spend shift credit")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 1080, "Shift credit must be spent first")
	TEST_ASSERT(bank.adjust_money(-200, "Vending: Supplies"), "Spend remaining shift credit and cleared funds")
	TEST_ASSERT_EQUAL(bank.account_balance, 980, "Card balance must include the purchase")
	TEST_ASSERT_EQUAL(ledger.owner_total("testplayer"), 980, "Cleared spending must persist")
	TEST_ASSERT(ledger.convert_offshore("testplayer", id, 80), "Transfer offshore")
	TEST_ASSERT_EQUAL(bank.account_balance, 900, "Offshore transfer must debit the payroll account")
	TEST_ASSERT(ledger.purchase("testplayer", id, SAVINGS_REGULAR, 100, "bank-order", "Purchase"), "Spend cleared funds")
	TEST_ASSERT_EQUAL(bank.account_balance, 800, "Purchase must debit the same card balance")
	TEST_ASSERT(ledger.refund_purchase("testplayer", id, "bank-order", "Refund"), "Refund purchase")
	TEST_ASSERT_EQUAL(bank.account_balance, 900, "Refund must return to the card balance")
	var/datum/bank_account/second_card = savings_test_bank(ledger, "testplayer", "Elena Ward", 100)
	TEST_ASSERT(bank.adjust_money(-900, "Purchase"), "Spend the remaining cleared balance")
	TEST_ASSERT_EQUAL(second_card.account_balance, 100, "A second bank binding cannot duplicate cleared funds")
	TEST_ASSERT(!second_card.has_money(101), "Other cards cannot spend already-used cleared funds")
	TEST_ASSERT(bank.adjust_money(100, "Salary"), "New payroll still settles")
	var/list/snapshot = ledger.copy_snapshot()
	ledger.reset_accounts(snapshot)
	TEST_ASSERT(ledger.commit(snapshot), "Reset balances")
	TEST_ASSERT_EQUAL(bank.account_balance, 0, "Reset removes cleared funds from live cards")
	TEST_ASSERT_EQUAL(second_card.account_balance, 100, "Reset preserves shift credit")

/** Check capped automatic settlement, repeated income, debt, restrictions, and the active-shift levy. */
/datum/unit_test/savings_banking_policy

/datum/unit_test/savings_banking_policy/Run()
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, null, "bank-round")
	var/datum/bank_account/bank = savings_test_bank(ledger, "testplayer", "Elena Ward")
	var/list/snapshot = ledger.copy_snapshot()
	var/list/settings = snapshot["settings"]
	settings["round_cap"] = 100
	TEST_ASSERT(ledger.commit(snapshot), "Set policy")
	TEST_ASSERT(bank.adjust_money(150, "Salary"), "Income above cap remains usable")
	TEST_ASSERT_EQUAL(bank.account_balance, 140, "Only settled income pays the fee")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 90, "Only capped income persists")
	TEST_ASSERT(bank.adjust_money(200, "Salary"), "Further income becomes shift credit")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 90, "Cap cannot be bypassed by more payments")
	TEST_ASSERT(bank.adjust_money(-300, "Card purchase"), "Both kinds of funds are spendable")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 40, "Only spending beyond shift credit reduces savings")
	TEST_ASSERT_EQUAL(ledger.remaining_allowance("testplayer"), 0, "Spending does not replenish income allowance")
	snapshot = ledger.copy_snapshot()
	var/list/account = ledger.find_account("testplayer", bank.savings_character, snapshot)
	account["frozen"] = TRUE
	TEST_ASSERT(ledger.commit(snapshot), "Freeze funds")
	TEST_ASSERT(!bank.has_money(1), "Restricted cleared funds cannot authorize a purchase")
	TEST_ASSERT(!bank.adjust_money(-1, "Restricted debit"), "Restricted cleared funds cannot be spent")
	TEST_ASSERT(bank.adjust_money(100, "Salary"), "Restricted settlement must not discard incoming shift credit")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 40, "Restricted income does not settle")
	TEST_ASSERT(bank.adjust_money(-100, "Shift credit purchase"), "Shift credit remains spendable")
	snapshot = ledger.copy_snapshot()
	account = ledger.find_account("testplayer", bank.savings_character, snapshot)
	account["frozen"] = FALSE
	account[SAVINGS_REGULAR] = 2000
	settings = snapshot["settings"]
	settings["round_cap"] = 2000
	settings["levy_threshold"] = 1000
	settings["levy_rate"] = 10
	TEST_ASSERT(ledger.commit(snapshot), "Seed levy scenario")
	ledger.round_token = "next-bank-round"
	TEST_ASSERT(bank.adjust_money(100, "Salary"), "First settlement applies maintenance")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 1990, "Apply levy once and credit net payroll")
	TEST_ASSERT_EQUAL(bank.round_economy_history[1]["amount"], -100, "Maintenance must be a separate statement charge")
	TEST_ASSERT_EQUAL(bank.round_economy_history[2]["amount"], -10, "Settlement fee must remain separate from maintenance")
	TEST_ASSERT_EQUAL(bank.round_economy_history[3]["amount"], 100, "Maintenance must not turn payroll into a negative payment")
	TEST_ASSERT(bank.adjust_money(100, "Salary"), "Second settlement")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 2080, "Maintenance must not repeat")
	bank.account_debt = 20
	var/withheld = min(ceil(100 * DEBT_COLLECTION_COEFF), 20)
	var/before = bank.account_balance
	TEST_ASSERT(bank.adjust_money(100, "Salary"), "Debt collection still works")
	TEST_ASSERT_EQUAL(bank.account_balance, before + 100 - withheld, "Debt must be withheld exactly once")
	TEST_ASSERT_EQUAL(bank.account_debt, 20 - withheld, "Debt principal must update")
	TEST_ASSERT_EQUAL(bank.savings_cleared_balance, 2080, "Income with outstanding debt remains unsettled")

/** A transfer debits and credits in one durable operation; failed saves cannot create free recipient funds. */
/datum/unit_test/savings_banking_transfers

/datum/unit_test/savings_banking_transfers/Run()
	var/datum/savings_ledger/failing_test/ledger = allocate(/datum/savings_ledger/failing_test, null, "bank-round")
	var/id = ledger.open_account("sender", "Elena Ward")
	TEST_ASSERT(ledger.earn("sender", id, SAVINGS_REGULAR, 1000, "Earlier income"), "Seed sender funds")
	var/datum/bank_account/sender = savings_test_bank(ledger, "sender", "Elena Ward", 100)
	var/datum/bank_account/recipient = savings_test_bank(ledger, "recipient", "Mara Vale", 100)
	TEST_ASSERT(recipient.transfer_money(sender, 400), "Bank transfer must succeed")
	TEST_ASSERT_EQUAL(sender.account_balance, 600, "Sender must be debited exactly once")
	TEST_ASSERT_EQUAL(recipient.account_balance, 460, "Recipient receives the transfer less settlement fee")
	TEST_ASSERT_EQUAL(ledger.owner_total("sender"), 600, "Sender cleared spending must persist")
	TEST_ASSERT_EQUAL(ledger.owner_total("recipient"), 360, "Recipient income must settle")
	var/before = json_encode(ledger.data)
	ledger.fail_writes = TRUE
	TEST_ASSERT(!recipient.transfer_money(sender, 200), "Failed save must reject the whole transfer")
	TEST_ASSERT_EQUAL(sender.account_balance, 600, "Failed transfer must leave sender unchanged")
	TEST_ASSERT_EQUAL(recipient.account_balance, 460, "Failed transfer must not mint recipient funds")
	TEST_ASSERT_EQUAL(json_encode(ledger.data), before, "Failed transfer must preserve the entire ledger")
	TEST_ASSERT(!sender.adjust_money(-200, "Failed purchase"), "Failed persistent spending must reject")
	TEST_ASSERT_EQUAL(sender.account_balance, 600, "Failed purchase cannot consume balance")
	TEST_ASSERT(!sender.adjust_money(100, "Failed settlement"), "Failed automatic settlement must reject")
	TEST_ASSERT_EQUAL(sender.account_balance, 600, "Failed settlement cannot publish unsaved funds")

/** The on-disk regular balance reopens as the payroll balance without minting income or saving the starting grant. */
/datum/unit_test/savings_storage/unified_bank

/datum/unit_test/savings_storage/unified_bank/Run()
	fixture_path = "[GLOB.log_directory]/savings-unified-fixture.json"
	var/datum/savings_ledger/ledger = allocate(/datum/savings_ledger, fixture_path, "bank-round")
	var/datum/bank_account/bank = savings_test_bank(ledger, "testplayer", "Elena Ward", 400)
	TEST_ASSERT(bank.adjust_money(1000, "Salary"), "Salary must save automatically")
	TEST_ASSERT(bank.adjust_money(-1000, "Card purchase"), "Spending must save automatically")
	var/datum/savings_ledger/reloaded = allocate(/datum/savings_ledger, fixture_path, "next-bank-round")
	var/datum/bank_account/new_bank = savings_test_bank(reloaded, "testplayer", "Elena Ward", 400)
	TEST_ASSERT_EQUAL(new_bank.account_balance, 700, "Load remaining cleared funds plus the new shift advance")
	TEST_ASSERT_EQUAL(new_bank.savings_cleared_balance, 300, "Spent funds must not reappear")
	TEST_ASSERT_EQUAL(reloaded.remaining_allowance("testplayer"), 2000, "Loading funds must not consume earning allowance")

/** Customer statements must not reveal administrator notes, real-world dates, or private account metadata. */
/datum/unit_test/savings_bank_statements

/datum/unit_test/savings_bank_statements/Run()
	var/list/records = list(list("time" = "2026-09-08", "reason" = "Administrator secretckey: corrupt JSON after round", "amount" = 50, "currency" = SAVINGS_OFFSHORE))
	var/list/statement = savings_public_statement(records, SAVINGS_OFFSHORE)
	TEST_ASSERT_EQUAL(statement[1]["description"], "Account adjustment", "Private reasons must become bank descriptions")
	TEST_ASSERT_EQUAL(statement[1]["time"], "Previous activity", "Legacy real-world dates must not enter customer statements")
	TEST_ASSERT(!findtext(json_encode(statement), "secretckey"), "Statements must not include admin identities")
	TEST_ASSERT_EQUAL(length(savings_public_statement(records, SAVINGS_REGULAR)), 0, "Statements must filter the requested account")
	TEST_ASSERT_EQUAL(savings_statement_description("Nanotrasen: Salary", 100), "Payroll credit", "Payroll must use a bank description")

#endif
