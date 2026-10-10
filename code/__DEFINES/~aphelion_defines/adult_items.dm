/// Ends an adult-items family's unit test with a notice when lewd items are disabled, as its items then delete
/// themselves - the first line of every family test. `adult_items_kill_switch` tests the switch for every family.
#define TEST_SKIP_IF_LEWD_ITEMS_DISABLED if(CONFIG_GET(flag/disable_lewd_items)) { \
	TEST_NOTICE(src, "Lewd items are disabled, so the adult items this test makes delete themselves."); return; }
