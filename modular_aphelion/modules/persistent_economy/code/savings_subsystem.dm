/** Loads the savings service before players can deposit. No periodic processing or round-end payout is needed. */
SUBSYSTEM_DEF(savings)
	name = "Persistent Savings"
	ss_flags = SS_NO_FIRE
	/// Authoritative character ledger, separate from the station's round economy.
	var/datum/savings_ledger/ledger

/datum/controller/subsystem/savings/Initialize()
#ifdef UNIT_TESTS
	ledger = new(null, "unit-test-round")
#else
	ledger = new("data/character_savings.json", GLOB.round_id ? "[GLOB.round_id]" : "local-[time2text(world.realtime, "YYYY-MM-DD hh:mm:ss")]-[world.port]")
#endif
	return SS_INIT_SUCCESS

/datum/controller/subsystem/savings/Recover()
	ledger = SSsavings.ledger
