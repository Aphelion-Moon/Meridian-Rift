/// Spendable persistent savings for future property and item purchases.
#define SAVINGS_REGULAR "regular"
/// Separate balance reserved for the planned black market.
#define SAVINGS_OFFSHORE "offshore"
/// Maximum exact monetary value accepted by the ledger, below DM's integer precision limit.
#define SAVINGS_MAX_AMOUNT 1000000
/// Current on-disk savings schema.
#define SAVINGS_VERSION 1
/// Number of recent transactions retained per character.
#define SAVINGS_HISTORY_LIMIT 50
/// Number of recent administrative changes retained in the panel.
#define SAVINGS_AUDIT_LIMIT 200
/// Recent successful balance changes retained per round bank, including department budgets.
#define ROUND_ECONOMY_HISTORY_LIMIT 100
