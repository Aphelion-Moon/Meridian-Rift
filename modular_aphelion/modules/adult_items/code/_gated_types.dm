#if defined(UNIT_TESTS) || defined(SPACEMAN_DMM)
/// The types the adult-items families add, one line per family, for the `adult_items_kill_switch` unit test. List a
/// family's top types only - the test makes every concrete type under them, as a stanza covers its subtypes. A
/// family's own test leaves the switch to it and starts with `TEST_SKIP_IF_LEWD_ITEMS_DISABLED`.
/proc/adult_items_gated_types()
	return list(
		/obj/item/reagent_containers/hypospray/medipen/lewd, /obj/item/storage/box/medipens/lewd,
		/obj/item/storage/box/condoms,
		/obj/item/clothing/sextoy/fleshlight/bluespace,
		/obj/item/clothing/shoes/ballet_heels/pointe_boots,
		/obj/item/clothing/under/misc/latex_halfcatsuit,
	)
#endif
