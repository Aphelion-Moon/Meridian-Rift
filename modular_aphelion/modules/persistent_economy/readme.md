## Persistent character economy

Module ID: PERSISTENT_ECONOMY

### Description

Players use **NT Banking** on their PDA to manage their current and offshore accounts. Standard PDAs include the app, and it is available from the NTNet software downloader. The current account is the actual payroll/card bank account: previously saved regular funds load into its spendable balance, payroll enters it, and card purchases debit it. The app shows only the authenticated character, uses in-world banking terms and dates, and replaces internal transaction reasons with customer statement descriptions. The IC verb has been removed.

Accounts are opened when a human crew member receives their job bank account. Identity uses the authenticated ckey plus a hash of the trimmed, case-insensitive character name. Punctuation remains significant. Two ckeys with the same character name own separate accounts; identical character names within one ckey refer to the same character. Changing save slots does not reset funds. An in-round rename, stolen ID, disguise, or body swap does not change the mind's original bank binding. A lasting character rename in preferences opens a different account; administrators can move the balance with two documented adjustments. Hardware CIDs are not account identities.

Eligible incoming payments settle automatically, subject to the shared gross round cap, settlement fee, wealth ceiling, and levy. The bank balance combines persistent **cleared funds** and temporary **shift credit**. Starting pay is shift credit, and income above the settlement limits remains spendable shift credit. Outstanding debt, CRAB locks, account freezes, and paused settlement prevent new clearing. Purchases use shift credit first, then persist any cleared-fund debit before approving payment. Loading earlier savings is not new income. Ordinary bank transfers settle their debit and credit in one snapshot; a failed save cannot create recipient funds. There is no manual deposit or end-of-round sweep. Department budgets remain round-only.

Defaults, all changeable through the admin panel:

| Setting               |                  Default | Scope                                                      |
| --------------------- | -----------------------: | ---------------------------------------------------------- |
| Gross earning cap     |          2,000 per round | Shared by every character and both currencies on a ckey    |
| Settlement fee        |          10%, rounded up | Removed from circulation on income that clears             |
| Savings ceiling       |                  100,000 | Combined regular/offshore balances across the ckey         |
| Wealth levy exemption |                   20,000 | Combined wealth across the ckey                            |
| Active-round levy     | 1% of excess, rounded up | Once on the first successful income transaction that round |

The levy is distributed across the owner's balances, including frozen characters. Inactive rounds do not incur a levy. Converting or spending does not create new earning allowance. Failed settlement neither charges the levy nor consumes allowance. Lowering a cap preserves existing funds and limits subsequent settlement. Administrators may exceed the gameplay ceiling for repairs; each stored balance remains limited to 1,000,000 whole credits for arithmetic safety. Fees, levies, and spending remove persistent currency. Station vendor and black-market prices are unchanged.

### Administration and storage

The red **Reset everyone's savings** button requires `R_ADMIN`, a reason, the exact phrase `RESET ECONOMY`, and final confirmation. It clears all regular/offshore balances, player transaction histories, purchase receipts, freezes, and earning/levy counters. Character identities remain so players already in the round can continue banking. Cleared funds are also removed from every attached payroll account; temporary shift credit, policy, administrative audit, and department budgets are retained. The reset uses the normal verified save and backup path and records the administrator and reason. Future persistent property systems will need coordinated reset handling.

**Admin.Game → Manage Persistent Economy** requires `R_ADMIN` for opening, reading, and every mutation. It shows currency totals, searchable accounts, both balances, remaining round allowance, and transaction histories. Administrators can add/remove funds, freeze/unfreeze accounts, pause transactions, and change policy. Every change requires a reason and is written to the persistent administrative audit, admin log, admin notices, and economy log. Repairs bypass the gameplay earning cap, economy pause, and account freezes.

The **Round accounts** tab lists current bank accounts and their latest 100 successful transactions, with round timestamps, actual balance changes, resulting balances, reasons, and debt withheld. Selecting a savings account also shows histories for its bound round accounts. **Departments** lists current department budgets and the same transaction details. Administrators can add or remove a whole-credit amount with a reason and confirmation; overdrafts are rejected. Budget changes use normal banking, including debt collection and cargo updates, and remain available while savings are paused or unavailable. Department budgets and their panel audit last for the round; full administrative changes also go to admin and economy logs. The **Admin audit** tab combines persistent savings actions with this round's department adjustments.

`data/character_savings.json` contains a versioned snapshot of accounts, policy, round counters, purchase receipts, and bounded recent histories. Writes use a verified `.pending` snapshot and retain the preceding committed file as `.backup`. Ledger and card balances only change after a required save succeeds. Commit failures reject the operation and disable further writes. Startup recovers a damaged/missing main file from a valid backup. If both are invalid, the service refuses to create fresh accounts over the damaged data. Restore a valid snapshot and restart to recover. Restoring the previous backup can lose the last committed transaction; consult economy logs when repairing balances. This store is intended for one server process, not simultaneous writers from multiple servers.

Cleared funds stay synchronized across attached bank accounts after purchases, offshore conversion, refunds, levies, and administrative changes. Multiple live bindings for one character do not duplicate spendable cleared funds. The app remains authenticated to the user's original character binding. Physical ID cards retain the existing game's authorization rules for ordinary purchases and NT Pay transfers, including the consequences of losing a card. Use `adjust_money` and `transfer_money` for bank changes; direct `account_balance` assignments bypass settlement. The old `earn(..., source_bank)` path is rejected for attached banks because their income already settles automatically.

The existing `persistent_economy.json`, `persistent_economy_settings.json`, and piggy-bank files are untouched. There is no automatic migration from their undocumented legacy balances. Back up the new file and its backup together during server maintenance. Database-backed servers use the round ID for allowance identity; local servers without a round database use a unique startup timestamp and port. Reconnects and respawns do not reset the cap. A new local server startup constitutes a new round.

Snapshots are copied through JSON to preserve history arrays. Earlier builds could serialize histories as `{"/list": null}` objects, crashing TGUI after a policy save. Startup repairs these history fields independently of current balances, policy, allowances, and purchase receipts, using valid backup histories when available. Before publishing a repaired main snapshot, it preserves the original as `.history-recovery`. The admin panel displays a recovery notice; entries missing from both snapshots cannot be reconstructed and should be checked against economy logs. The interfaces also tolerate malformed legacy history payloads without crashing.

### Integrations

Future integrations use `SSsavings.ledger`:

- `earn(owner_ckey, character_id, SAVINGS_OFFSHORE, gross_amount, reason)` credits a server-authorized smuggling payout through the same earning cap, fee, and wealth rules. Resolve the identity from the selling character's bound bank; never trust a UI-provided ckey or character ID. Calculate smuggling payout shares before calling. This persistence fee is distinct from the design's exemption from export-price elasticity. The method returns net credits or `FALSE`; reject/retain the shipment on failure rather than discarding unpaid goods.
- `purchase(owner_ckey, character_id, currency, amount, receipt_id, reason)` charges a specific currency and commits a permanent unique receipt. Only `TRUE` authorizes new fulfillment. Duplicate IDs return `FALSE`, including refunded IDs. The shop must own server-side pricing, authorization, order IDs, and persistent fulfillment state. Do not accept client-supplied prices or fulfill a duplicate charge.
- `refund_purchase(owner_ckey, character_id, receipt_id, reason)` restores a recorded purchase to its original currency once. It never creates new earning allowance. A refund can exceed the gameplay wealth ceiling because it returns already-owned money. Refunds respect account freezes and the economy pause; administrators can repair locked accounts explicitly.
- `find_account(owner_ckey, character_id)` provides read-only access to both balances for a future character selection info sheet or market UI. Never mutate returned lists.

Receipt records are permanent to prevent replay; history is limited to 50 entries per character and 200 administrative actions in the panel. Full operation logs use the existing economy logger. An external fulfillment system must reconcile charged-but-undelivered orders after a crash; a money debit alone does not persist an apartment or physical item.

### TG Proc/File Changes

- `code/modules/jobs/job_types/_job.dm`: bind the bank immediately after the starting paycheck in `on_job_equipping`.
- `code/modules/economy/account.dm`: route attached account income, spending, transfers, and variable edits through the ledger; record round transactions and opening department budgets.
- `code/modules/modular_computers/file_system/programs/nt_pay.dm`: report transfer failure before notifying recipients or emitting receipt signals.
- `code/modules/modular_computers/computers/item/pda.dm`: install the savings app alongside the standard PDA programs.
- `modular_nova/master_files/code/modules/cargo/packs/_companies.dm`: credit cargo commissions through `adjust_money` so they appear in round history.
- `code/modules/unit_tests/_unit_tests.dm`: include this module's regression tests while the test assertion macros are available.
- `tgstation.dme`: include module files and shared defines.

### Modular Overrides

- `modular_aphelion/master_files/code/modules/economy/account.dm`: add bank identity fields, the mind's weak bank reference, deposit eligibility helpers, bounded round histories, and department budget adjustment helpers. No existing proc overrides.

### Defines

- `code/__DEFINES/~aphelion_defines/savings.dm`: currency identifiers, schema version, storage amount limit, and history limits.

### Included files outside this module

- `tgui/packages/tgui/interfaces/PersistentSavings.tsx`
- `tgui/packages/tgui/interfaces/PersistentEconomyAdmin.tsx`
- `tgui/packages/tgui/interfaces/PersistentEconomy/RoundAccounts.tsx`
- `tgui/packages/tgui/interfaces/PersistentEconomy/Banking.tsx`
- Shared defines and modular bank file listed above.

### Validation

Tests also cover PDA installation and navigation, reset confirmation and permissions, reset persistence, retained policy/audit, cleared receipts, failed-reset rollback, and deposits through existing character bindings after reset. Run server tests in a separate directory with actual copied assets and test-only data. Never place directory links to source folders under `tmp/`; server maintenance deletes that directory on startup and shutdown.

DM regression tests cover owner/character isolation, starting grants, exact round-bank debits, rollback on failed persistence, caps shared across characters/currencies, conversions, levies, purchase/refund replay, freezes, unauthorized administrative calls, disk reload, corrupt-file recovery, repeated policy snapshots, recovery of malformed histories without reverting financial data, bounded round transactions, debt withholding, and department adjustment validation. TGUI tests cover account selection, payloads, policy fields, legacy history handling, round transaction details, and reason/confirmation requirements for department edits. Test ledgers use memory or test-owned log files; the savings subsystem never opens production savings during unit tests.

### Credits

Implemented for Meridian Rift using the existing bank, verb, TGUI, logging, and unit-test systems. Black-market requirements follow the linked community design document.
