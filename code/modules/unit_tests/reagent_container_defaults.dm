/// Checks if reagent container transfer amount defaults match with actual possible values
/datum/unit_test/reagent_container_defaults

/datum/unit_test/reagent_container_defaults/Run()
	for(var/container_type in subtypesof(/obj/item/reagent_containers))
		var/obj/item/reagent_containers/container = allocate(container_type)
		if(!container.has_variable_transfer_amount)
			continue
		var/initial_value = initial(container.amount_per_transfer_from_this)
		var/index_of_initial_value = container.possible_transfer_amounts.Find(initial_value)
		if(index_of_initial_value == 0)
			TEST_FAIL("Reagent container [container_type]: initial value of amount_per_transfer_from_this value ([initial_value]) not found in possible_transfer_amounts list")

/// Dropping a container after reagent teardown must not dereference its deleted holder.
/datum/unit_test/reagent_container_sound_after_holder_deletion/Run()
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass)
	TEST_ASSERT(glass.reagents && glass.drop_sound, "The sound fixture needs a live holder and an empty-container drop sound.")
	TEST_ASSERT(glass.play_drop_sound(), "An intact empty glass did not play its normal handling sound.")
	QDEL_NULL(glass.reagents)
	TEST_ASSERT(!glass.play_drop_sound(), "A glass without a reagent holder should skip handling sounds during teardown.")
