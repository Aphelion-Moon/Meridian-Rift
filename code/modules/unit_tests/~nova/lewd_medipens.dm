/// The lewd medipen box holds the five SPLURT pens, each pen holds the reagents it lists, one shot spends it and a spent
/// pen still has a sprite, and with lewd items disabled neither the box nor any lewd pen survives being made.
/datum/unit_test/lewd_medipens

/datum/unit_test/lewd_medipens/Run()
	var/lewd_items_disabled = CONFIG_GET(flag/disable_lewd_items)
	CONFIG_SET(flag/disable_lewd_items, TRUE)
	var/list/survivors = list()
	for(var/item_type in valid_subtypesof(/obj/item/reagent_containers/hypospray/medipen/lewd) + /obj/item/storage/box/medipens/lewd)
		var/obj/item/item = allocate(item_type)
		if(!QDELETED(item))
			survivors += item_type
	CONFIG_SET(flag/disable_lewd_items, FALSE)
	var/obj/item/storage/box/medipens/lewd/box = allocate(/obj/item/storage/box/medipens/lewd)
	CONFIG_SET(flag/disable_lewd_items, lewd_items_disabled)
	if(length(survivors))
		TEST_FAIL("With lewd items disabled, [english_list(survivors)] still spawned.")

	var/list/pens_missing = list(
		/obj/item/reagent_containers/hypospray/medipen/lewd/crocin,
		/obj/item/reagent_containers/hypospray/medipen/lewd/crocin/hexacrocin,
		/obj/item/reagent_containers/hypospray/medipen/lewd/succubus_milk,
		/obj/item/reagent_containers/hypospray/medipen/lewd/incubus_draft,
		/obj/item/reagent_containers/hypospray/medipen/lewd/coom_bomb,
	)
	var/mob/living/carbon/human/consistent/patient = allocate(/mob/living/carbon/human/consistent)
	for(var/obj/item/reagent_containers/hypospray/medipen/lewd/pen as anything in box)
		if(!(pen.type in pens_missing))
			TEST_FAIL("The lewd medipen box holds an unexpected [pen.type].")
			continue
		pens_missing -= pen.type
		for(var/reagent_type in pen.list_reagents)
			var/amount = pen.reagents.get_reagent_amount(reagent_type)
			if(amount != pen.list_reagents[reagent_type])
				TEST_FAIL("[pen.type] holds [amount]u of [reagent_type] instead of the [pen.list_reagents[reagent_type]]u it lists.")
		pen.inject(patient, patient)
		if(!pen.used_up)
			TEST_FAIL("[pen.type] still holds [pen.reagents.total_volume]u after one shot.")
		if(!icon_exists(pen.icon, pen.icon_state))
			TEST_FAIL("A spent [pen.type] has no sprite: its icon lacks \"[pen.icon_state]\".")
	if(length(pens_missing))
		TEST_FAIL("The lewd medipen box is missing [english_list(pens_missing)].")
