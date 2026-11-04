/// Every concrete type under the families' top types in `adult_items_gated_types()` is removed when made with lewd
/// items disabled and kept when made with them enabled - its stanza in `_erp_disabled_item_enforcement.dm` at work.
/datum/unit_test/adult_items_kill_switch

/datum/unit_test/adult_items_kill_switch/Run()
	var/list/gated_types = list()
	for(var/family_type in adult_items_gated_types())
		gated_types |= valid_typesof(family_type)
	var/list/survivors = surviving_types(gated_types, lewd_items_disabled = TRUE)
	var/list/casualties = gated_types - surviving_types(gated_types, lewd_items_disabled = FALSE)
	if(length(survivors))
		TEST_FAIL("With lewd items disabled, [english_list(survivors)] still spawned.")
	if(length(casualties))
		TEST_FAIL("With lewd items enabled, [english_list(casualties)] did not spawn.")

/// Makes one of each of `item_types` with lewd items disabled or enabled, and returns the types whose item survived.
/datum/unit_test/adult_items_kill_switch/proc/surviving_types(list/item_types, lewd_items_disabled)
	var/configured = CONFIG_GET(flag/disable_lewd_items)
	CONFIG_SET(flag/disable_lewd_items, lewd_items_disabled)
	for(var/item_type in item_types)
		var/atom/movable/item = allocate(item_type)
		if(!QDELETED(item))
			LAZYADD(., item_type)
	CONFIG_SET(flag/disable_lewd_items, configured)
